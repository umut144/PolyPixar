# Base class of the PolyTools test suites.
#
# A suite extends this script and declares its tests as `_test_*` functions;
# `run_tests.gd` finds them with `get_method_list()`, so a test is run by being
# declared, not by being listed. Everything more than one suite needs lives
# here: the assertion, the shared fixtures, the Inspector and Outliner control
# helpers, the view signal recorder, and the view wiring driver.
extends RefCounted

# Set by the runner before each test so a failure names the test it belongs to.
var current_test := ""
var failures := 0
var view_signals_emitted: Dictionary = {}
var view_signal_argument_failures: Array[String] = []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL %s: %s" % [current_test, message])


func _component() -> Dictionary:
	return {"points": [], "edges": [], "chains": []}


func _control_text(root: Node) -> String:
	var values: Array[String] = []
	if root is Label or root is Button or root is CheckBox:
		values.append(str(root.get("text")))
	for child in root.get_children():
		values.append(_control_text(child))
	return "\n".join(values)


func _inspector_controls(root: Node, out: Array) -> void:
	if root.is_queued_for_deletion():
		return
	out.append(root)
	for child in root.get_children():
		_inspector_controls(child, out)


func _inspector_option(application: Control, first_item_text: String) -> OptionButton:
	# Inspector dropdowns sit under section headers rather than captions, so they
	# are identified by their first entry, which is unique per dropdown.
	var controls: Array = []
	_inspector_controls(application.inspector_content, controls)
	for control in controls:
		if control is OptionButton and control.item_count > 0 and str(control.get_item_text(0)) == first_item_text:
			return control
	return null


func _choose_option(option: OptionButton, index: int) -> void:
	# A click both moves the selection and emits item_selected; the handlers read
	# the index they are given, so the test drives the signal.
	option.select(index)
	option.item_selected.emit(index)


func _button_starting_with(root: Node, prefix: String) -> Button:
	# Rendering clears the previous rows with queue_free, which only takes effect
	# at the end of a frame. Detached from the tree no frame ever ends, so rows
	# from earlier renders are still children here and must be skipped.
	if root.is_queued_for_deletion():
		return null
	if root is Button and str(root.text).begins_with(prefix):
		return root
	for child in root.get_children():
		var match := _button_starting_with(child, prefix)
		if match != null:
			return match
	return null


func _outliner_test_component(component_id: String, component_name: String) -> Dictionary:
	var component := _component()
	BezierTopology.add_point(component, Vector2.ZERO, "corner")
	BezierTopology.add_point(component, Vector2(10.0, 0.0), "linear")
	BezierTopology.add_point(component, Vector2(10.0, 10.0), "linear")
	BezierTopology.close_active_chain(component)
	component.merge({"id": component_id, "name": component_name, "visibility": true})
	return component


func _record_view_signal(signal_name: String, arguments: Array, values: Array) -> void:
	view_signals_emitted[signal_name] = true
	for index in range(arguments.size()):
		var declared_type: int = int(arguments[index].get("type", TYPE_NIL))
		if declared_type == TYPE_NIL or index >= values.size():
			continue
		var value = values[index]
		if declared_type == TYPE_FLOAT and typeof(value) == TYPE_INT:
			continue
		if typeof(value) != declared_type and value != null:
			view_signal_argument_failures.append("%s argument %d is %d, declared %d" % [
				signal_name, index, typeof(value), declared_type])


func _view_signal_recorder(signal_name: String, arguments: Array) -> Callable:
	# A signal can only be connected to a Callable of its own arity, so one
	# recorder per arity. Six covers every view signal in the editor.
	match arguments.size():
		0:
			return func() -> void: _record_view_signal(signal_name, arguments, [])
		1:
			return func(a) -> void: _record_view_signal(signal_name, arguments, [a])
		2:
			return func(a, b) -> void: _record_view_signal(signal_name, arguments, [a, b])
		3:
			return func(a, b, c) -> void: _record_view_signal(signal_name, arguments, [a, b, c])
		4:
			return func(a, b, c, d) -> void: _record_view_signal(signal_name, arguments, [a, b, c, d])
	return func(a, b, c, d, e) -> void: _record_view_signal(signal_name, arguments, [a, b, c, d, e])


func _exercise_control(control: Node) -> void:
	# Fires what a user would fire on this control. Only the signal the view
	# emits in response matters, so the values are the ones already there.
	if control is OptionButton:
		if control.item_count > 0:
			control.item_selected.emit(0)
	elif control is CheckBox or control is CheckButton:
		control.toggled.emit(not control.button_pressed)
	elif control is Button and control.toggle_mode:
		# A toggle-mode Button reports through toggled, not pressed. The Mesh
		# Inspector builds its advanced blocks that way.
		control.toggled.emit(not control.button_pressed)
		control.pressed.emit()
	elif control is SpinBox:
		control.value_changed.emit(control.value)
		control.get_line_edit().text_submitted.emit(str(control.value))
		control.get_line_edit().focus_exited.emit()
	elif control is Slider:
		control.value_changed.emit(control.value)
	elif control is LineEdit:
		control.text_submitted.emit(str(control.text))
		control.focus_exited.emit()
	elif control is Button:
		control.pressed.emit()


# The view wiring check, in two halves, for every view main.gd pushes a
# snapshot into. The routing half asserts that each signal in `routes` reaches
# exactly the handler it names, that each signal in `adapters` is wired through
# exactly one adapter lambda, that each signal in `unconnected` has no
# connection, and that the view's script declares nothing outside those three
# lists — so a new signal must be entered somewhere before the suite passes.
# The emission half builds one probe per entry in `cases`, fires every control
# the probe builds, and asserts that each routed or adapted signal was reached
# and arrived with its declared argument types; a signal in `undrivable` must
# not be reached, so the list cannot silently outlive its reason.
#
# `spec` keys:
#   label          how the view is named in messages, e.g. "Style Inspector"
#   view           the live view main.gd built, for the routing half
#   routes         [[signal_name, handler_name], ...]
#   cases          probe case names; one probe is built per case
#   build_probe    Callable(case_name) -> Node, returning a view whose
#                  `rebuild()` the driver then calls
#   exercise       Callable(control) that fires one control
#                  (default: _exercise_control)
#   after_rebuild  optional Callable(probe) run after `rebuild()`, before
#                  the walk
#   extra_controls optional Callable(probe) -> Array of controls to exercise
#                  in addition to the probe's own tree
#   release_probe  optional Callable(probe) that frees the probe
#                  (default: probe.free())
#   adapters, unconnected, undrivable   optional signal name lists
func _check_view_wiring(spec: Dictionary) -> void:
	var label := str(spec["label"])
	var view: Node = spec["view"]
	var routes: Array = spec["routes"]
	var cases: Array = spec["cases"]
	var build_probe: Callable = spec["build_probe"]
	var exercise: Callable = spec.get("exercise", _exercise_control)
	var after_rebuild: Callable = spec.get("after_rebuild", Callable())
	var extra_controls: Callable = spec.get("extra_controls", Callable())
	var release_probe: Callable = spec.get("release_probe", Callable())
	var adapters: Array = spec.get("adapters", [])
	var unconnected: Array = spec.get("unconnected", [])
	var undrivable: Array = spec.get("undrivable", [])

	var routed: Array[String] = []
	for route in routes:
		var signal_name := str(route[0])
		var expected_handler := str(route[1])
		routed.append(signal_name)
		var handlers: Array[String] = []
		for connection in view.get_signal_connection_list(signal_name):
			handlers.append(str((connection["callable"] as Callable).get_method()))
		_expect(handlers.size() == 1 and handlers[0] == expected_handler,
			"The %s signal %s should reach %s, not %s." % [label, signal_name, expected_handler, str(handlers)])
	for signal_name in adapters:
		var connections: Array = view.get_signal_connection_list(str(signal_name))
		_expect(connections.size() == 1 and (connections[0]["callable"] as Callable).is_custom(),
			"The %s signal %s should be wired through exactly one adapter lambda." % [label, signal_name])
	for signal_name in unconnected:
		_expect(view.get_signal_connection_list(str(signal_name)).is_empty(),
			"The %s signal %s is documented as unconnected; connecting it should update that list." % [label, signal_name])
	# The script's own signals only. get_signal_list() also reports what Control
	# and Node bring with them, and those carry engine-internal connections.
	var declared_arguments: Dictionary = {}
	for entry in view.get_script().get_script_signal_list():
		var declared := str(entry["name"])
		declared_arguments[declared] = entry["args"]
		if declared in routed or declared in adapters or declared in unconnected:
			continue
		_expect(false, "The %s declares %s, which is in neither the routing table nor the adapter or unconnected lists." % [label, declared])

	var recorded: Array[String] = routed.duplicate()
	for signal_name in adapters:
		recorded.append(str(signal_name))
	view_signals_emitted = {}
	view_signal_argument_failures = [] as Array[String]
	for case_name in cases:
		var probe: Node = build_probe.call(case_name)
		for signal_name in recorded:
			probe.connect(signal_name, _view_signal_recorder(signal_name, declared_arguments.get(signal_name, [])))
		probe.rebuild()
		if after_rebuild.is_valid():
			after_rebuild.call(probe)
		var controls: Array = []
		_inspector_controls(probe, controls)
		if extra_controls.is_valid():
			controls.append_array(extra_controls.call(probe))
		for control in controls:
			exercise.call(control)
		if release_probe.is_valid():
			release_probe.call(probe)
		else:
			probe.free()
	var unreachable: Array[String] = []
	for signal_name in recorded:
		if signal_name in undrivable:
			_expect(not view_signals_emitted.has(signal_name),
				"%s is listed as undrivable but the walk reached it; move it out of that list." % signal_name)
			continue
		if not view_signals_emitted.has(signal_name):
			unreachable.append(signal_name)
	_expect(unreachable.is_empty(),
		"Every connected %s signal should be reachable from a control; unreachable: %s" % [label, str(unreachable)])
	_expect(view_signal_argument_failures.is_empty(),
		"%s signals should arrive with their declared argument types; %s" % [label, str(view_signal_argument_failures)])
