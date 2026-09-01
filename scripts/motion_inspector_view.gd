class_name MotionInspectorView
extends VBoxContainer

# The Motion module's Inspector. It follows the same shape as the other three
# views — context in, intent signals out, no document writes — with one honest
# difference: it holds references to the Motion models rather than only data.
# `motion_workspace`, `motion_player` and `motion_selection` are session models
# the Inspector queries in about thirty places (selected preview, display names,
# summaries, primitive options, transition order). Translating those into a row
# model is the structural step that was deliberately left for later; until then
# they are handed in through set_models().
#
# The syncing that used to happen halfway through the Animation render —
# selecting the Asset, setting the Workspace Asset, syncing the player document
# and refreshing the preview — now runs in main.gd before rebuild(), in the same
# order, so this file only draws.
#
# Context keys: motion_context {validation}, path_context {previewable,
# has_preview_asset}, sequence_entry_context {asset, path}.

signal act_direction_changed(value: float, axis: String)
signal act_easing_selected(index: int, option: OptionButton)
signal act_enabled_changed(enabled: bool)
signal act_jump_arc_selected(index: int, option: OptionButton)
signal act_number_changed(value: float, property_name: String)
signal act_remove_requested()
signal act_rename_requested(new_name: String, act: Dictionary, editor: LineEdit)
signal contract_parameter_add_requested()
signal contract_parameter_remove_requested(parameter_id: String)
signal contract_parameter_rename_requested(new_name: String, parameter_id: String, editor: LineEdit)
signal contract_parameter_type_selected(index: int, option: OptionButton, parameter_id: String)
signal marker_event_rename_requested(new_event_id: String, state_id: String, marker_id: String, editor: LineEdit)
signal marker_kind_selected(index: int, option: OptionButton, state_id: String, marker_id: String)
signal marker_phase_changed(value: float, state_id: String, marker_id: String)
signal motion_domain_selected(index: int, option: OptionButton, state_id: String, motion_id: String)
signal motion_enabled_changed(enabled: bool, state_id: String, motion_id: String)
signal motion_item_remove_requested(kind: String, state_id: String, item_id: String)
signal motion_parameter_changed(value: float, state_id: String, motion_id: String, parameter_name: String)
signal motion_phase_offset_changed(value: float, state_id: String, motion_id: String)
signal motion_primitive_selected(index: int, option: OptionButton, state_id: String, motion_id: String)
signal motion_remove_requested(state_id: String, motion_id: String)
signal motion_rename_requested(new_name: String, state_id: String, motion_id: String, editor: LineEdit)
signal motion_target_selected(index: int, option: OptionButton, state_id: String, motion_id: String)
signal path_duration_changed(value: float)
signal path_playback_toggled(enabled: bool, property_name: String)
signal path_preview_asset_selected(index: int, option: OptionButton)
signal path_rename_requested(new_name: String, path_document: Dictionary, editor: LineEdit)
signal runtime_bool_changed(value: bool, parameter_id: String)
signal runtime_number_changed(value: float, parameter_id: String)
signal section_toggled(section: VBoxContainer, text: String, header: Button)
signal sequence_asset_selected(index: int, option: OptionButton)
signal sequence_entry_enabled_changed(enabled: bool)
signal sequence_entry_remove_requested()
signal sequence_entry_rename_requested(new_name: String, entry: Dictionary, editor: LineEdit)
signal sequence_path_selected(index: int, option: OptionButton)
signal sequence_rename_requested(new_name: String, sequence_document: Dictionary, editor: LineEdit)
signal sequence_state_selected(index: int, option: OptionButton)
signal state_cycle_duration_changed(value: float, state_id: String)
signal state_remove_requested(state_id: String)
signal state_rename_requested(new_name: String, state_id: String, editor: LineEdit)
signal transition_entry_mode_selected(index: int, option: OptionButton, state_id: String, transition_id: String)
signal transition_exit_policy_selected(index: int, option: OptionButton, state_id: String, transition_id: String)
signal transition_move_requested(state_id: String, transition_id: String, direction: int)
signal transition_number_changed(value: float, state_id: String, transition_id: String, property_name: String)
signal transition_rule_add_requested(state_id: String, transition_id: String)
signal transition_rule_operator_selected(index: int, option: OptionButton, state_id: String, transition_id: String, rule_id: String)
signal transition_rule_parameter_selected(index: int, option: OptionButton, state_id: String, transition_id: String, rule_id: String)
signal transition_rule_remove_requested(state_id: String, transition_id: String, rule_id: String)
signal transition_rule_value_changed(value: float, state_id: String, transition_id: String, rule_id: String)
signal transition_target_selected(index: int, option: OptionButton, state_id: String, transition_id: String)

# Models, handed in rather than resolved.
var motion_workspace: MotionWorkspace
var motion_player: MotionPlayer
var motion_selection: MotionSelection

# Context, pushed in before rebuild().
var active_submodule := ""
var document_asset: Dictionary = {}
var act_document: Dictionary = {}
var path_document_context: Dictionary = {}
var sequence_document_context: Dictionary = {}
var sequence_entry: Dictionary = {}
var sequence_entry_context: Dictionary = {}
var motion_context: Dictionary = {}
var path_context: Dictionary = {}
var motion_phase := 0.0
var motion_sequence_phase := 0.0
var motion_sequence_view := ""
var motion_path_preview_asset_id := ""
var assets: Array[Dictionary] = []
var motion_paths: Array[Dictionary] = []

# Controls the editor updates without a full rebuild.
var motion_asset_preview: MotionAssetPreview
var motion_sequence_runtime_sequence_label: Label
var motion_sequence_runtime_path_label: Label
var motion_sequence_runtime_animation_label: Label


func set_models(workspace: MotionWorkspace, player: MotionPlayer, selection: MotionSelection) -> void:
	motion_workspace = workspace
	motion_player = player
	motion_selection = selection


func set_context(context: Dictionary) -> void:
	active_submodule = str(context.get("submodule", ""))
	document_asset = context.get("asset", {})
	act_document = context.get("act", {})
	path_document_context = context.get("path", {})
	sequence_document_context = context.get("sequence", {})
	sequence_entry = context.get("sequence_entry", {})
	sequence_entry_context = context.get("sequence_entry_context", {})
	motion_context = context.get("motion", {})
	path_context = context.get("path_state", {})
	motion_phase = float(context.get("motion_phase", 0.0))
	motion_sequence_phase = float(context.get("sequence_phase", 0.0))
	motion_sequence_view = str(context.get("sequence_view", ""))
	motion_path_preview_asset_id = str(context.get("path_preview_asset_id", ""))
	assets = context.get("assets", [] as Array[Dictionary])
	motion_paths = context.get("motion_paths", [] as Array[Dictionary])


func rebuild() -> void:
	EditorWidgets.clear(self)
	motion_asset_preview = null
	motion_sequence_runtime_sequence_label = null
	motion_sequence_runtime_path_label = null
	motion_sequence_runtime_animation_label = null
	if active_submodule == "Path":
		_render_path()
	elif active_submodule == "Act":
		_render_act()
	elif active_submodule == "Sequence":
		_render_sequence()
	else:
		_render_animation()


func _motion_act_blink_timing_text(anticipation_share: float) -> String:
	var clamped_share := clampf(anticipation_share, 0.01, 0.89)
	var ingress_share := (1.0 - clamped_share) * 0.8
	var exit_share := (1.0 - clamped_share) * 0.2
	return "%.0f%% · %.0f%% · %.0f%%" % [clamped_share * 100.0, ingress_share * 100.0, exit_share * 100.0]


func _render_animation() -> void:
	# The Asset/Workspace/Player syncing that used to happen in the middle of this
	# render now runs in main.gd before rebuild(), in the same order.
	add_child(EditorWidgets.create_inspector_section("Animation Preview", section_toggled.emit))
	var asset: Dictionary = document_asset
	var preview_panel := EditorWidgets.create_panel(Color("#171b22"))
	motion_asset_preview = MotionAssetPreview.new()
	motion_asset_preview.set_asset(asset)
	motion_asset_preview.set_runtime(motion_player.current_state_name() if motion_player != null else "None", motion_phase, motion_player.playing if motion_player != null else false)
	preview_panel.add_child(motion_asset_preview)
	add_child(preview_panel)
	if asset.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("Select an Asset in the Motion Outliner."))
		return
	var preview := motion_workspace.get_selected_preview() if is_instance_valid(motion_workspace) else {}
	if motion_selection.kind == MotionSelection.ASSET:
		_render_simulation_contract()
		_render_legacy_path_follow_migration(asset)
		_render_animation_validation()
		add_child(EditorWidgets.create_inspector_field_label("Persisted with the Asset · evaluated beginning in Phase 8."))
		return
	if preview.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("Select a State or one of its Preview entries."))
		return
	var kind := str(preview.get("kind", MotionSelection.NONE))
	var state: Dictionary = preview.get("state", {})
	add_child(EditorWidgets.create_inspector_section(kind.capitalize(), section_toggled.emit))
	if kind == MotionSelection.STATE:
		var state_id := str(state.get("id", ""))
		add_child(EditorWidgets.create_inspector_field_label("Name"))
		var state_name_editor := EditorWidgets.create_name_editor(str(state.get("name", "State")), "State name")
		state_name_editor.text_submitted.connect(state_rename_requested.emit.bind(state_id, state_name_editor))
		state_name_editor.focus_exited.connect(func() -> void: state_rename_requested.emit(state_name_editor.text, state_id, state_name_editor))
		add_child(state_name_editor)
		add_child(EditorWidgets.create_inspector_field_label("Cycle Duration (s)"))
		var cycle_duration := SpinBox.new()
		cycle_duration.min_value = 0.01
		cycle_duration.max_value = 3600.0
		cycle_duration.step = 0.05
		cycle_duration.value = float(state.get("cycle_duration", 1.0))
		cycle_duration.value_changed.connect(state_cycle_duration_changed.emit.bind(state_id))
		add_child(cycle_duration)
		add_child(EditorWidgets.create_motion_inspector_value("Motion", "%d Preview entries" % state.get("motions", []).size()))
		add_child(EditorWidgets.create_motion_inspector_value("Transitions", "%d Preview entries" % state.get("transitions", []).size()))
		add_child(EditorWidgets.create_motion_inspector_value("Markers", "%d Preview entries" % state.get("markers", []).size()))
		var remove_state_button := Button.new()
		remove_state_button.text = "Remove State"
		remove_state_button.custom_minimum_size = Vector2(0, 28)
		remove_state_button.focus_mode = Control.FOCUS_NONE
		remove_state_button.pressed.connect(state_remove_requested.emit.bind(state_id))
		add_child(remove_state_button)
	elif kind == MotionSelection.MOTION:
		var motion: Dictionary = preview.get("item", {})
		_render_motion_authoring(state, motion)
	elif kind == MotionSelection.TRANSITION:
		var transition: Dictionary = preview.get("item", {})
		_render_transition_authoring(state, transition)
	elif kind == MotionSelection.MARKER:
		var marker: Dictionary = preview.get("item", {})
		_render_marker_authoring(state, marker)
	else:
		var item: Dictionary = preview.get("item", {})
		add_child(EditorWidgets.create_motion_inspector_value("State", str(state.get("name", "State"))))
		add_child(EditorWidgets.create_motion_inspector_value("Name", motion_workspace.item_display_name(kind, item)))
		add_child(EditorWidgets.create_motion_inspector_value("Preview", motion_workspace.item_summary(kind, item)))
		if kind == MotionSelection.TRANSITION:
			add_child(EditorWidgets.create_motion_inspector_value("Priority", "List order · first eligible wins"))
	add_child(EditorWidgets.create_inspector_field_label("Persisted Animation data · runtime evaluation follows in Phase 8."))


func _render_act() -> void:
	add_child(EditorWidgets.create_inspector_section("Act", section_toggled.emit))
	var act: Dictionary = act_document
	if act.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("Add a Slide, Jump, or Blink with the + button in the Act list."))
		return
	var primitive := str(act.get("primitive", MotionActEvaluator.SLIDE))
	var primitive_label := MotionActEvaluator.primitive_label(primitive)
	add_child(EditorWidgets.create_inspector_field_label("Name"))
	var name_editor := EditorWidgets.create_name_editor(str(act.get("name", primitive_label)), "Act name")
	name_editor.text_submitted.connect(act_rename_requested.emit.bind(act, name_editor))
	name_editor.focus_exited.connect(func() -> void: act_rename_requested.emit(name_editor.text, act, name_editor))
	add_child(name_editor)
	add_child(EditorWidgets.create_motion_inspector_value("Stable Act ID", str(act.get("id", ""))))
	var enabled_toggle := CheckBox.new()
	enabled_toggle.text = "Enabled"
	enabled_toggle.button_pressed = bool(act.get("enabled", true))
	enabled_toggle.toggled.connect(act_enabled_changed.emit)
	add_child(enabled_toggle)
	add_child(EditorWidgets.create_inspector_section("Primitive", section_toggled.emit))
	add_child(EditorWidgets.create_motion_inspector_value("Type", primitive_label))
	var parameters: Dictionary = act.get("parameters", {})
	var direction: Vector2 = parameters.get("direction", Vector2.RIGHT)
	add_child(EditorWidgets.create_inspector_field_label("Direction"))
	var direction_grid := GridContainer.new()
	direction_grid.columns = 2
	for axis_data in [["X", direction.x, "x"], ["Y", direction.y, "y"]]:
		direction_grid.add_child(EditorWidgets.create_inspector_field_label(str(axis_data[0])))
		var field := SpinBox.new()
		field.min_value = -1000.0
		field.max_value = 1000.0
		field.step = 0.05
		field.value = float(axis_data[1])
		field.value_changed.connect(act_direction_changed.emit.bind(str(axis_data[2])))
		direction_grid.add_child(field)
	add_child(direction_grid)
	add_child(EditorWidgets.create_inspector_field_label("Distance (cm)"))
	var distance := SpinBox.new()
	distance.min_value = 0.0
	distance.max_value = 100000.0
	distance.step = 0.1
	distance.value = float(parameters.get("distance", 4.0))
	distance.value_changed.connect(act_number_changed.emit.bind("distance"))
	add_child(distance)
	if primitive == MotionActEvaluator.JUMP:
		add_child(EditorWidgets.create_inspector_field_label("Height (cm)"))
		var height := SpinBox.new()
		height.min_value = 0.01
		height.max_value = 100000.0
		height.step = 0.1
		height.value = float(parameters.get("height", 3.0))
		height.value_changed.connect(act_number_changed.emit.bind("height"))
		add_child(height)
		add_child(EditorWidgets.create_inspector_field_label("Arc Shape"))
		var arc_option := OptionButton.new()
		var current_arc := str(parameters.get("arc", MotionActEvaluator.JUMP_ARC_SMOOTH))
		for arc in MotionActEvaluator.JUMP_ARC_OPTIONS:
			arc_option.add_item(MotionActEvaluator.jump_arc_label(arc))
			arc_option.set_item_metadata(arc_option.item_count - 1, arc)
			if arc == current_arc:
				arc_option.select(arc_option.item_count - 1)
		arc_option.item_selected.connect(act_jump_arc_selected.emit.bind(arc_option))
		add_child(arc_option)
	elif primitive == MotionActEvaluator.BLINK:
		_act_parameter_field("Anticipation Distance (cm)", float(parameters.get("anticipation_distance", 1.0)), "anticipation_distance", 0.0, 100000.0, 0.1)
		var anticipation_share := float(parameters.get("anticipation_share", 0.5))
		var anticipation_field := _act_parameter_field("Anticipation Share", anticipation_share, "anticipation_share", 0.01, 0.89, 0.01)
		_act_parameter_field("Minimum Scale", float(parameters.get("minimum_scale", 0.05)), "minimum_scale", 0.01, 1.0, 0.01)
		var timing_split := EditorWidgets.create_motion_inspector_value("Timing Split", _motion_act_blink_timing_text(anticipation_share))
		add_child(timing_split)
		anticipation_field.value_changed.connect(func(value: float) -> void:
			var timing_value := timing_split.get_child(1) as Label
			if is_instance_valid(timing_value):
				timing_value.text = _motion_act_blink_timing_text(value)
		)
	add_child(EditorWidgets.create_inspector_section("Timing", section_toggled.emit))
	add_child(EditorWidgets.create_inspector_field_label("Duration (s)"))
	var duration := SpinBox.new()
	duration.min_value = 0.01
	duration.max_value = 3600.0
	duration.step = 0.05
	duration.value = float(act.get("timing", {}).get("duration", 0.6))
	duration.value_changed.connect(act_number_changed.emit.bind("duration"))
	add_child(duration)
	add_child(EditorWidgets.create_inspector_field_label("Easing"))
	var easing_option := OptionButton.new()
	var current_easing := str(act.get("timing", {}).get("easing", MotionActEvaluator.EASE_IN_OUT))
	for easing in MotionActEvaluator.EASING_OPTIONS:
		easing_option.add_item(MotionActEvaluator.easing_label(easing))
		easing_option.set_item_metadata(easing_option.item_count - 1, easing)
		if easing == current_easing:
			easing_option.select(easing_option.item_count - 1)
	easing_option.item_selected.connect(act_easing_selected.emit.bind(easing_option))
	add_child(easing_option)
	var issues := MotionActEvaluator.validation_issues(act)
	var validation := EditorWidgets.create_inspector_field_label("Ready for Preview" if issues.is_empty() else str(issues[0]))
	validation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validation.add_theme_color_override("font_color", Color("#75b88a") if issues.is_empty() else Color("#f2c94c"))
	add_child(validation)
	var remove_button := Button.new()
	remove_button.text = "Remove Act"
	remove_button.pressed.connect(act_remove_requested.emit)
	add_child(remove_button)


func _act_parameter_field(label_text: String, value: float, property_name: String, minimum: float, maximum: float, step: float) -> SpinBox:
	add_child(EditorWidgets.create_inspector_field_label(label_text))
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.value = value
	field.value_changed.connect(act_number_changed.emit.bind(property_name))
	add_child(field)
	return field


func _render_path() -> void:
	add_child(EditorWidgets.create_inspector_section("Path", section_toggled.emit))
	var path_document: Dictionary = path_document_context
	if path_document.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("Create or select an independent Path resource."))
		return
	add_child(EditorWidgets.create_inspector_field_label("Name"))
	var name_editor := EditorWidgets.create_name_editor(str(path_document.get("name", "Path")), "Path name")
	name_editor.text_submitted.connect(path_rename_requested.emit.bind(path_document, name_editor))
	name_editor.focus_exited.connect(func() -> void: path_rename_requested.emit(name_editor.text, path_document, name_editor))
	add_child(name_editor)
	add_child(EditorWidgets.create_motion_inspector_value("Stable Resource ID", str(path_document.get("id", ""))))
	add_child(EditorWidgets.create_inspector_section("Path Preview", section_toggled.emit))
	add_child(EditorWidgets.create_inspector_field_label("Preview Asset · editor-only"))
	var preview_asset_option := OptionButton.new()
	preview_asset_option.custom_minimum_size = Vector2(0, 28)
	preview_asset_option.add_item("No Preview Asset")
	preview_asset_option.set_item_metadata(0, "")
	for asset in assets:
		preview_asset_option.add_item(str(asset.get("name", "Asset")))
		preview_asset_option.set_item_metadata(preview_asset_option.item_count - 1, str(asset.get("id", "")))
		if str(asset.get("id", "")) == motion_path_preview_asset_id:
			preview_asset_option.select(preview_asset_option.item_count - 1)
	preview_asset_option.item_selected.connect(path_preview_asset_selected.emit.bind(preview_asset_option))
	add_child(preview_asset_option)
	var playback: Dictionary = path_document.get("playback", {})
	add_child(EditorWidgets.create_inspector_field_label("Duration (s)"))
	var duration_input := SpinBox.new()
	duration_input.min_value = 0.01
	duration_input.max_value = 3600.0
	duration_input.step = 0.05
	duration_input.value = float(playback.get("duration", 2.0))
	duration_input.value_changed.connect(path_duration_changed.emit)
	add_child(duration_input)
	var loop_toggle := CheckBox.new()
	loop_toggle.text = "Loop"
	loop_toggle.button_pressed = bool(playback.get("loop", true))
	loop_toggle.toggled.connect(path_playback_toggled.emit.bind("loop"))
	add_child(loop_toggle)
	var orient_toggle := CheckBox.new()
	orient_toggle.text = "Orient Along Path"
	orient_toggle.button_pressed = bool(playback.get("orient_along_path", false))
	orient_toggle.toggled.connect(path_playback_toggled.emit.bind("orient_along_path"))
	add_child(orient_toggle)
	add_child(EditorWidgets.create_inspector_section("Path Geometry", section_toggled.emit))
	var topology: Dictionary = path_document.get("topology", {})
	add_child(EditorWidgets.create_motion_inspector_value("Points", str(topology.get("points", []).size())))
	add_child(EditorWidgets.create_motion_inspector_value("Segments", str(topology.get("segments", []).size())))
	add_child(EditorWidgets.create_motion_inspector_value("Ownership", "Independent World resource · no Asset reference"))
	var validation := MotionPathTopology.validate(topology)
	var sample := MotionPathSampler.sample(topology, 0.5)
	var validation_text := "Ready for Preview · %.2f cm" % float(sample.get("length", 0.0))
	if topology.get("points", []).size() < 2:
		validation_text = "Add at least two Points."
	elif not validation.is_empty():
		validation_text = "Invalid · %s" % validation[0]
	elif not bool(sample.get("valid", false)):
		validation_text = "Invalid · Path length must be greater than zero."
	elif not bool(path_context.get("has_preview_asset", false)):
		validation_text = "Select a Preview Asset."
	var validation_label := EditorWidgets.create_inspector_field_label(validation_text)
	validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validation_label.add_theme_color_override("font_color", Color("#75b88a") if bool(path_context.get("previewable", false)) else Color("#f2c94c"))
	add_child(validation_label)


func _render_sequence() -> void:
	add_child(EditorWidgets.create_inspector_section("Sequence", section_toggled.emit))
	var sequence_document: Dictionary = sequence_document_context
	if sequence_document.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("Create or select a Sequence resource."))
		return
	var entry: Dictionary = sequence_entry
	if motion_sequence_view == MotionSequenceWorkspace.VIEW_PLAYER:
		add_child(EditorWidgets.create_motion_inspector_value("Stable Resource ID", str(sequence_document.get("id", ""))))
		_render_sequence_player(entry)
		return
	add_child(EditorWidgets.create_inspector_field_label("Name"))
	var name_editor := EditorWidgets.create_name_editor(str(sequence_document.get("name", "Sequence")), "Sequence name")
	name_editor.text_submitted.connect(sequence_rename_requested.emit.bind(sequence_document, name_editor))
	name_editor.focus_exited.connect(func() -> void: sequence_rename_requested.emit(name_editor.text, sequence_document, name_editor))
	add_child(name_editor)
	add_child(EditorWidgets.create_motion_inspector_value("Stable Resource ID", str(sequence_document.get("id", ""))))
	add_child(EditorWidgets.create_motion_inspector_value("Entries", "%d composition entries" % sequence_document.get("entries", []).size()))
	if entry.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("Add one Composition Entry to reference an Asset, Animation State, and Path."))
		return
	add_child(EditorWidgets.create_inspector_section("Composition Entry", section_toggled.emit))
	var entry_name := EditorWidgets.create_name_editor(str(entry.get("name", "Composition Entry")), "Entry name")
	entry_name.text_submitted.connect(sequence_entry_rename_requested.emit.bind(entry, entry_name))
	entry_name.focus_exited.connect(func() -> void: sequence_entry_rename_requested.emit(entry_name.text, entry, entry_name))
	add_child(entry_name)
	var enabled_toggle := CheckBox.new()
	enabled_toggle.text = "Enabled"
	enabled_toggle.button_pressed = bool(entry.get("enabled", true))
	enabled_toggle.toggled.connect(sequence_entry_enabled_changed.emit)
	add_child(enabled_toggle)
	add_child(EditorWidgets.create_inspector_field_label("Asset"))
	var asset_option := OptionButton.new()
	asset_option.add_item("Select Asset")
	asset_option.set_item_metadata(0, "")
	for asset in assets:
		asset_option.add_item(str(asset.get("name", "Asset")))
		asset_option.set_item_metadata(asset_option.item_count - 1, str(asset.get("id", "")))
		if str(asset.get("id", "")) == str(entry.get("asset_id", "")):
			asset_option.select(asset_option.item_count - 1)
	asset_option.item_selected.connect(sequence_asset_selected.emit.bind(asset_option))
	add_child(asset_option)
	add_child(EditorWidgets.create_inspector_field_label("Animation State"))
	var state_option := OptionButton.new()
	state_option.add_item("Select State")
	state_option.set_item_metadata(0, "")
	var resolved_asset: Dictionary = sequence_entry_context.get("asset", {})
	for state in resolved_asset.get("animation", {}).get("states", []):
		state_option.add_item(str(state.get("name", "State")))
		state_option.set_item_metadata(state_option.item_count - 1, str(state.get("id", "")))
		if str(state.get("id", "")) == str(entry.get("animation_state_id", "")):
			state_option.select(state_option.item_count - 1)
	state_option.item_selected.connect(sequence_state_selected.emit.bind(state_option))
	add_child(state_option)
	add_child(EditorWidgets.create_inspector_field_label("Path"))
	var path_option := OptionButton.new()
	path_option.add_item("Select Path")
	path_option.set_item_metadata(0, "")
	for path_document in motion_paths:
		path_option.add_item(str(path_document.get("name", "Path")))
		path_option.set_item_metadata(path_option.item_count - 1, str(path_document.get("id", "")))
		if str(path_document.get("id", "")) == str(entry.get("path_id", "")):
			path_option.select(path_option.item_count - 1)
	path_option.item_selected.connect(sequence_path_selected.emit.bind(path_option))
	add_child(path_option)
	var context: Dictionary = sequence_entry_context
	var issues := MotionSequenceEvaluator.validation_issues(entry, context.get("asset", {}), context.get("path", {}))
	var validation_label := EditorWidgets.create_inspector_field_label("Ready for Playback" if issues.is_empty() else "Incomplete · %s" % issues[0])
	validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validation_label.add_theme_color_override("font_color", Color("#75b88a") if issues.is_empty() else Color("#f2c94c"))
	add_child(validation_label)
	var remove_button := Button.new()
	remove_button.text = "Remove Entry"
	remove_button.pressed.connect(sequence_entry_remove_requested.emit)
	add_child(remove_button)


func _render_sequence_player(entry: Dictionary) -> void:
	add_child(EditorWidgets.create_inspector_section("Resolved Entry", section_toggled.emit))
	var context: Dictionary = sequence_entry_context
	var asset: Dictionary = context.get("asset", {})
	var path_document: Dictionary = context.get("path", {})
	var snapshot := MotionSequenceEvaluator.evaluate(entry, asset, path_document, motion_sequence_phase)
	add_child(EditorWidgets.create_motion_inspector_value("Asset", str(asset.get("name", "Missing Asset"))))
	add_child(EditorWidgets.create_motion_inspector_value("State", str(snapshot.get("state_name", "Missing State"))))
	add_child(EditorWidgets.create_motion_inspector_value("Path", str(path_document.get("name", "Missing Path"))))
	add_child(EditorWidgets.create_inspector_section("Runtime", section_toggled.emit))
	var sequence_phase_field := EditorWidgets.create_motion_inspector_value("Sequence Phase", "%.2f" % motion_sequence_phase)
	motion_sequence_runtime_sequence_label = sequence_phase_field.get_child(1) as Label
	add_child(sequence_phase_field)
	var path_phase_field := EditorWidgets.create_motion_inspector_value("Path Phase", "%.2f" % float(snapshot.get("path_phase", 0.0)))
	motion_sequence_runtime_path_label = path_phase_field.get_child(1) as Label
	add_child(path_phase_field)
	var animation_phase_field := EditorWidgets.create_motion_inspector_value("Animation Phase", "%.2f" % float(snapshot.get("animation_phase", 0.0)))
	motion_sequence_runtime_animation_label = animation_phase_field.get_child(1) as Label
	add_child(animation_phase_field)
	add_child(EditorWidgets.create_motion_inspector_value("Duration", "%.2f s · inherited from Path" % float(snapshot.get("duration", 0.0))))
	var issues: Array = snapshot.get("issues", [])
	var status := EditorWidgets.create_inspector_field_label("Ready for Playback" if issues.is_empty() else "Blocked · %s" % issues[0])
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("#75b88a") if issues.is_empty() else Color("#f2c94c"))
	add_child(status)


func _render_motion_authoring(state: Dictionary, motion: Dictionary) -> void:
	var state_id := str(state.get("id", ""))
	var motion_id := str(motion.get("id", ""))
	var domain := str(motion.get("domain", MotionWorkspace.OUTER))
	add_child(EditorWidgets.create_motion_inspector_value("State", str(state.get("name", "State"))))
	add_child(EditorWidgets.create_inspector_field_label("Name"))
	var name_editor := EditorWidgets.create_name_editor(str(motion.get("name", "Motion")), "Motion name")
	name_editor.text_submitted.connect(motion_rename_requested.emit.bind(state_id, motion_id, name_editor))
	name_editor.focus_exited.connect(func() -> void: motion_rename_requested.emit(name_editor.text, state_id, motion_id, name_editor))
	add_child(name_editor)
	var enabled_toggle := CheckBox.new()
	enabled_toggle.text = "Enabled"
	enabled_toggle.button_pressed = bool(motion.get("enabled", true))
	enabled_toggle.toggled.connect(motion_enabled_changed.emit.bind(state_id, motion_id))
	add_child(enabled_toggle)
	add_child(EditorWidgets.create_inspector_field_label("Domain"))
	var domain_option := OptionButton.new()
	domain_option.custom_minimum_size = Vector2(0, 28)
	for domain_data in [["Outer", MotionWorkspace.OUTER], ["Inner", MotionWorkspace.INNER]]:
		domain_option.add_item(str(domain_data[0]))
		domain_option.set_item_metadata(domain_option.item_count - 1, str(domain_data[1]))
		if str(domain_data[1]) == str(motion.get("domain", MotionWorkspace.OUTER)):
			domain_option.select(domain_option.item_count - 1)
	domain_option.item_selected.connect(motion_domain_selected.emit.bind(domain_option, state_id, motion_id))
	add_child(domain_option)
	add_child(EditorWidgets.create_inspector_field_label("Target"))
	var target_option := OptionButton.new()
	target_option.custom_minimum_size = Vector2(0, 28)
	if domain == MotionWorkspace.OUTER:
		target_option.add_item("Entire Asset")
		target_option.set_item_metadata(0, {"scope": MotionWorkspace.TARGET_ASSET, "component_id": ""})
	target_option.add_item("Select Component")
	target_option.set_item_metadata(target_option.item_count - 1, {"scope": MotionWorkspace.TARGET_COMPONENT, "component_id": ""})
	var asset := document_asset
	for component in asset.get("components", []):
		target_option.add_item(str(component.get("name", "Component")))
		target_option.set_item_metadata(target_option.item_count - 1, {"scope": MotionWorkspace.TARGET_COMPONENT, "component_id": str(component.get("id", ""))})
	var target_scope := str(motion.get("target_scope", MotionWorkspace.TARGET_COMPONENT))
	var target_component_id := str(motion.get("target_component_id", ""))
	for target_index in range(target_option.item_count):
		var target_data: Dictionary = target_option.get_item_metadata(target_index)
		if str(target_data.get("scope", "")) == target_scope and str(target_data.get("component_id", "")) == target_component_id:
			target_option.select(target_index)
			break
	target_option.item_selected.connect(motion_target_selected.emit.bind(target_option, state_id, motion_id))
	add_child(target_option)
	add_child(EditorWidgets.create_inspector_field_label("Primitive"))
	var primitive_option := OptionButton.new()
	primitive_option.custom_minimum_size = Vector2(0, 28)
	for primitive in motion_workspace.primitive_options(domain):
		primitive_option.add_item(motion_workspace.primitive_label(primitive))
		primitive_option.set_item_metadata(primitive_option.item_count - 1, primitive)
		if primitive == str(motion.get("primitive", MotionWorkspace.BOB)):
			primitive_option.select(primitive_option.item_count - 1)
	primitive_option.item_selected.connect(motion_primitive_selected.emit.bind(primitive_option, state_id, motion_id))
	add_child(primitive_option)
	var primitive := str(motion.get("primitive", MotionWorkspace.BOB))
	if domain == MotionWorkspace.INNER:
		_unavailable_motion_guide_field("Motion Guides", "Motion Guide authoring is not available yet.")
	add_child(EditorWidgets.create_inspector_section("Parameters", section_toggled.emit))
	if primitive == MotionWorkspace.BOB:
		_motion_number_parameter("Distance", state_id, motion_id, "distance", float(motion.get("parameters", {}).get("distance", 0.25)), 0.0, 1000.0, 0.05)
	elif primitive == MotionWorkspace.SPINE_SWAY:
		_motion_number_parameter("Strength", state_id, motion_id, "strength", float(motion.get("parameters", {}).get("strength", 0.5)), 0.0, 1.0, 0.05)
	_motion_number_parameter("Cycles", state_id, motion_id, "cycles", float(motion.get("parameters", {}).get("cycles", 1.0)), 0.01, 100.0, 0.1)
	add_child(EditorWidgets.create_inspector_field_label("Phase Offset"))
	var phase_offset := SpinBox.new()
	phase_offset.min_value = -1.0
	phase_offset.max_value = 1.0
	phase_offset.step = 0.01
	phase_offset.value = float(motion.get("phase_offset", 0.0))
	phase_offset.custom_minimum_size = Vector2(0, 28)
	phase_offset.value_changed.connect(motion_phase_offset_changed.emit.bind(state_id, motion_id))
	add_child(phase_offset)
	var validation := str(motion_context.get("validation", ""))
	var validation_label := Label.new()
	validation_label.text = validation
	validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validation_label.add_theme_font_size_override("font_size", 10)
	validation_label.add_theme_color_override("font_color", Color("#75b88a") if validation == "Ready for Preview" else Color("#f2c94c"))
	add_child(validation_label)
	var remove_button := Button.new()
	remove_button.text = "Remove Motion"
	remove_button.custom_minimum_size = Vector2(0, 28)
	remove_button.focus_mode = Control.FOCUS_NONE
	remove_button.pressed.connect(motion_remove_requested.emit.bind(state_id, motion_id))
	add_child(remove_button)


func _render_transition_authoring(state: Dictionary, transition: Dictionary) -> void:
	var state_id := str(state.get("id", ""))
	var transition_id := str(transition.get("id", ""))
	add_child(EditorWidgets.create_motion_inspector_value("Source State", str(state.get("name", "State"))))
	var priority_index := motion_workspace.transition_index(state_id, transition_id)
	var transition_count: int = state.get("transitions", []).size()
	var priority_row := HBoxContainer.new()
	var priority_label := Label.new()
	priority_label.text = "Priority #%d" % (priority_index + 1)
	priority_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	priority_row.add_child(priority_label)
	var move_up := Button.new()
	move_up.text = "↑"
	move_up.tooltip_text = "Higher priority"
	move_up.disabled = priority_index <= 0
	move_up.pressed.connect(transition_move_requested.emit.bind(state_id, transition_id, -1))
	priority_row.add_child(move_up)
	var move_down := Button.new()
	move_down.text = "↓"
	move_down.tooltip_text = "Lower priority"
	move_down.disabled = priority_index < 0 or priority_index >= transition_count - 1
	move_down.pressed.connect(transition_move_requested.emit.bind(state_id, transition_id, 1))
	priority_row.add_child(move_down)
	add_child(priority_row)
	add_child(EditorWidgets.create_inspector_field_label("Target State"))
	var target_option := OptionButton.new()
	target_option.custom_minimum_size = Vector2(0, 28)
	var target_state_id := str(transition.get("target_state_id", ""))
	var target_exists := false
	for candidate in motion_workspace.get_states_for_asset(str(document_asset.get("id", ""))):
		if str(candidate.get("id", "")) == target_state_id:
			target_exists = true
			break
	if not target_exists and not target_state_id.is_empty():
		target_option.add_item("Missing State")
		target_option.set_item_metadata(0, target_state_id)
		target_option.set_item_disabled(0, true)
	for candidate in motion_workspace.get_states_for_asset(str(document_asset.get("id", ""))):
		var candidate_id := str(candidate.get("id", ""))
		if candidate_id == state_id:
			continue
		target_option.add_item(str(candidate.get("name", "State")))
		target_option.set_item_metadata(target_option.item_count - 1, candidate_id)
		if candidate_id == target_state_id:
			target_option.select(target_option.item_count - 1)
	target_option.item_selected.connect(transition_target_selected.emit.bind(target_option, state_id, transition_id))
	add_child(target_option)
	add_child(EditorWidgets.create_inspector_field_label("Exit Policy"))
	var exit_option := OptionButton.new()
	for exit_data in [["Any Phase", MotionWorkspace.EXIT_ANY_PHASE], ["After Phase", MotionWorkspace.EXIT_AFTER_PHASE], ["At Loop End", MotionWorkspace.EXIT_LOOP_END]]:
		exit_option.add_item(str(exit_data[0]))
		exit_option.set_item_metadata(exit_option.item_count - 1, str(exit_data[1]))
		if str(exit_data[1]) == str(transition.get("exit_policy", MotionWorkspace.EXIT_ANY_PHASE)):
			exit_option.select(exit_option.item_count - 1)
	exit_option.item_selected.connect(transition_exit_policy_selected.emit.bind(exit_option, state_id, transition_id))
	add_child(exit_option)
	if str(transition.get("exit_policy", MotionWorkspace.EXIT_ANY_PHASE)) == MotionWorkspace.EXIT_AFTER_PHASE:
		add_child(EditorWidgets.create_inspector_field_label("Exit After Phase"))
		var exit_phase := SpinBox.new()
		exit_phase.min_value = 0.0
		exit_phase.max_value = 1.0
		exit_phase.step = 0.01
		exit_phase.value = float(transition.get("exit_phase", 0.8))
		exit_phase.value_changed.connect(transition_number_changed.emit.bind(state_id, transition_id, "exit_phase"))
		add_child(exit_phase)
	add_child(EditorWidgets.create_inspector_field_label("Entry Mode"))
	var entry_option := OptionButton.new()
	for entry_data in [["Restart", MotionWorkspace.ENTRY_RESTART], ["Preserve Phase", MotionWorkspace.ENTRY_PRESERVE_PHASE]]:
		entry_option.add_item(str(entry_data[0]))
		entry_option.set_item_metadata(entry_option.item_count - 1, str(entry_data[1]))
		if str(entry_data[1]) == str(transition.get("entry_mode", MotionWorkspace.ENTRY_RESTART)):
			entry_option.select(entry_option.item_count - 1)
	entry_option.item_selected.connect(transition_entry_mode_selected.emit.bind(entry_option, state_id, transition_id))
	add_child(entry_option)
	add_child(EditorWidgets.create_inspector_field_label("Blend Duration (s)"))
	var blend_duration := SpinBox.new()
	blend_duration.min_value = 0.0
	blend_duration.max_value = 10.0
	blend_duration.step = 0.05
	blend_duration.value = float(transition.get("blend_duration", 0.15))
	blend_duration.value_changed.connect(transition_number_changed.emit.bind(state_id, transition_id, "blend_duration"))
	add_child(blend_duration)
	add_child(EditorWidgets.create_inspector_section("Rules · ALL", section_toggled.emit))
	var rules: Array = transition.get("rules", [])
	if rules.is_empty():
		var no_rules := EditorWidgets.create_inspector_field_label("No Rules · phase policy alone controls eligibility")
		no_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(no_rules)
	for rule in rules:
		_render_transition_rule(state_id, transition_id, rule)
	var add_rule_button := Button.new()
	add_rule_button.text = "+ Add Rule"
	add_rule_button.disabled = motion_workspace.get_contract_parameters().is_empty()
	add_rule_button.tooltip_text = "Declare a Simulation Contract parameter first." if add_rule_button.disabled else "All Rules must match."
	add_rule_button.pressed.connect(transition_rule_add_requested.emit.bind(state_id, transition_id))
	add_child(add_rule_button)
	var rules_valid := motion_workspace.transition_rules_valid(transition)
	var transition_validation := "Ready for future evaluation" if target_exists and rules_valid else ("Incomplete · Target State no longer exists" if not target_exists else "Incomplete · Rule references are invalid")
	var transition_validation_label := EditorWidgets.create_inspector_field_label(transition_validation)
	transition_validation_label.add_theme_color_override("font_color", Color("#75b88a") if target_exists and rules_valid else Color("#f2c94c"))
	add_child(transition_validation_label)
	var remove_button := Button.new()
	remove_button.text = "Remove Transition"
	remove_button.pressed.connect(motion_item_remove_requested.emit.bind(MotionSelection.TRANSITION, state_id, transition_id))
	add_child(remove_button)


func _render_simulation_contract() -> void:
	add_child(EditorWidgets.create_inspector_section("Simulation Contract", section_toggled.emit))
	var explanation := EditorWidgets.create_inspector_field_label("Typed inputs exposed by the host Simulation. Transition Rules reference stable parameter IDs.")
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(explanation)
	add_child(EditorWidgets.create_motion_inspector_value("Source", "Persisted Asset Contract · future external import boundary"))
	var parameters := motion_workspace.get_contract_parameters()
	if parameters.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("No parameters declared."))
	for parameter in parameters:
		_render_contract_parameter(parameter)
	var add_parameter := Button.new()
	add_parameter.text = "+ Add Parameter"
	add_parameter.pressed.connect(contract_parameter_add_requested.emit)
	add_child(add_parameter)
	_render_simulation_preview_values()


func _render_simulation_preview_values() -> void:
	add_child(EditorWidgets.create_inspector_section("Simulation Preview Values", section_toggled.emit))
	var note := EditorWidgets.create_inspector_field_label("Runtime-only values · used by the Phase 8 Transition evaluator")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	for parameter in motion_workspace.get_contract_parameters():
		var parameter_id := str(parameter.get("id", ""))
		var parameter_name := str(parameter.get("name", "parameter"))
		if str(parameter.get("type", MotionWorkspace.PARAM_NUMBER)) == MotionWorkspace.PARAM_BOOL:
			var bool_input := CheckBox.new()
			bool_input.text = parameter_name
			bool_input.button_pressed = bool(motion_player.parameter_value(parameter_id)) if motion_player != null else false
			bool_input.toggled.connect(runtime_bool_changed.emit.bind(parameter_id))
			add_child(bool_input)
		else:
			add_child(EditorWidgets.create_inspector_field_label(parameter_name))
			var number_input := SpinBox.new()
			number_input.min_value = -1000000.0
			number_input.max_value = 1000000.0
			number_input.step = 0.01
			number_input.value = float(motion_player.parameter_value(parameter_id)) if motion_player != null else 0.0
			number_input.value_changed.connect(runtime_number_changed.emit.bind(parameter_id))
			add_child(number_input)


func _render_animation_validation() -> void:
	add_child(EditorWidgets.create_inspector_section("Validation", section_toggled.emit))
	var issues := motion_workspace.validation_issues()
	if issues.is_empty():
		var valid_label := EditorWidgets.create_inspector_field_label("Animation document is valid.")
		valid_label.add_theme_color_override("font_color", Color("#75b88a"))
		add_child(valid_label)
		return
	var summary := EditorWidgets.create_inspector_field_label("%d issue%s" % [issues.size(), "" if issues.size() == 1 else "s"])
	summary.add_theme_color_override("font_color", Color("#f2c94c"))
	add_child(summary)
	for issue in issues:
		var issue_label := EditorWidgets.create_inspector_field_label("• %s" % issue)
		issue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(issue_label)


func _render_legacy_path_follow_migration(asset: Dictionary) -> void:
	var animation: Dictionary = asset.get("animation", {})
	var archived = animation.get("legacy_path_follow_motions", [])
	if not archived is Array or archived.is_empty():
		return
	add_child(EditorWidgets.create_inspector_section("Phase 10 Migration", section_toggled.emit))
	var summary := EditorWidgets.create_inspector_field_label("%d legacy Path Follow Motion%s retained in the Animation archive." % [archived.size(), "" if archived.size() == 1 else "s"])
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_color_override("font_color", Color("#f2c94c"))
	add_child(summary)
	var note := EditorWidgets.create_inspector_field_label("They no longer evaluate as Animation primitives. Their original data remains persisted so it can be recreated as an independent Motion → Path resource in Phase 11.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)


func _render_contract_parameter(parameter: Dictionary) -> void:
	var parameter_id := str(parameter.get("id", ""))
	var panel := EditorWidgets.create_panel(Color("#252b35"))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	var name_editor := EditorWidgets.create_name_editor(str(parameter.get("name", "parameter")), "Parameter name")
	name_editor.text_submitted.connect(contract_parameter_rename_requested.emit.bind(parameter_id, name_editor))
	name_editor.focus_exited.connect(func() -> void: contract_parameter_rename_requested.emit(name_editor.text, parameter_id, name_editor))
	content.add_child(name_editor)
	var type_option := OptionButton.new()
	for type_data in [["Number", MotionWorkspace.PARAM_NUMBER], ["Bool", MotionWorkspace.PARAM_BOOL]]:
		type_option.add_item(str(type_data[0]))
		type_option.set_item_metadata(type_option.item_count - 1, str(type_data[1]))
		if str(type_data[1]) == str(parameter.get("type", MotionWorkspace.PARAM_NUMBER)):
			type_option.select(type_option.item_count - 1)
	type_option.item_selected.connect(contract_parameter_type_selected.emit.bind(type_option, parameter_id))
	content.add_child(type_option)
	var id_label := EditorWidgets.create_inspector_field_label("Stable ID · %s" % parameter_id)
	id_label.add_theme_color_override("font_color", Color("#737f91"))
	content.add_child(id_label)
	var remove_parameter := Button.new()
	remove_parameter.text = "Remove Parameter"
	remove_parameter.pressed.connect(contract_parameter_remove_requested.emit.bind(parameter_id))
	content.add_child(remove_parameter)
	add_child(panel)


func _render_transition_rule(state_id: String, transition_id: String, rule: Dictionary) -> void:
	var rule_id := str(rule.get("id", ""))
	var panel := EditorWidgets.create_panel(Color("#252b35"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	panel.add_child(grid)
	grid.add_child(EditorWidgets.create_inspector_field_label("Parameter"))
	var parameter_option := OptionButton.new()
	parameter_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var parameter_id := str(rule.get("parameter_id", ""))
	var parameter := motion_workspace.find_contract_parameter(parameter_id)
	if parameter.is_empty():
		parameter_option.add_item("Missing Parameter")
		parameter_option.set_item_metadata(0, parameter_id)
		parameter_option.set_item_disabled(0, true)
	for candidate in motion_workspace.get_contract_parameters():
		parameter_option.add_item(str(candidate.get("name", "parameter")))
		parameter_option.set_item_metadata(parameter_option.item_count - 1, str(candidate.get("id", "")))
		if str(candidate.get("id", "")) == parameter_id:
			parameter_option.select(parameter_option.item_count - 1)
	parameter_option.item_selected.connect(transition_rule_parameter_selected.emit.bind(parameter_option, state_id, transition_id, rule_id))
	grid.add_child(parameter_option)
	grid.add_child(EditorWidgets.create_inspector_field_label("Operator"))
	var operator_option := OptionButton.new()
	var parameter_type := str(parameter.get("type", MotionWorkspace.PARAM_NUMBER))
	for operator in motion_workspace.rule_operators(parameter_type):
		operator_option.add_item(motion_workspace.rule_operator_label(operator))
		operator_option.set_item_metadata(operator_option.item_count - 1, operator)
		if operator == str(rule.get("operator", "")):
			operator_option.select(operator_option.item_count - 1)
	operator_option.disabled = parameter.is_empty()
	operator_option.item_selected.connect(transition_rule_operator_selected.emit.bind(operator_option, state_id, transition_id, rule_id))
	grid.add_child(operator_option)
	if parameter_type == MotionWorkspace.PARAM_NUMBER and not parameter.is_empty():
		grid.add_child(EditorWidgets.create_inspector_field_label("Value"))
		var rule_value := SpinBox.new()
		rule_value.min_value = -1000000.0
		rule_value.max_value = 1000000.0
		rule_value.step = 0.01
		rule_value.value = float(rule.get("value", 0.0))
		rule_value.value_changed.connect(transition_rule_value_changed.emit.bind(state_id, transition_id, rule_id))
		grid.add_child(rule_value)
	grid.add_child(EditorWidgets.create_inspector_field_label("Rule ID"))
	grid.add_child(EditorWidgets.create_inspector_field_label(rule_id))
	var remove_rule := Button.new()
	remove_rule.text = "Remove Rule"
	remove_rule.pressed.connect(transition_rule_remove_requested.emit.bind(state_id, transition_id, rule_id))
	grid.add_child(remove_rule)
	grid.add_child(Control.new())
	add_child(panel)


func _render_marker_authoring(state: Dictionary, marker: Dictionary) -> void:
	var state_id := str(state.get("id", ""))
	var marker_id := str(marker.get("id", ""))
	add_child(EditorWidgets.create_motion_inspector_value("State", str(state.get("name", "State"))))
	add_child(EditorWidgets.create_inspector_field_label("Event ID"))
	var event_editor := EditorWidgets.create_name_editor(str(marker.get("event_id", "event")), "Event ID")
	event_editor.text_submitted.connect(marker_event_rename_requested.emit.bind(state_id, marker_id, event_editor))
	event_editor.focus_exited.connect(func() -> void: marker_event_rename_requested.emit(event_editor.text, state_id, marker_id, event_editor))
	add_child(event_editor)
	add_child(EditorWidgets.create_inspector_field_label("Kind"))
	var kind_option := OptionButton.new()
	for kind_data in [["Event", MotionWorkspace.MARKER_EVENT], ["SFX", MotionWorkspace.MARKER_SFX], ["VFX", MotionWorkspace.MARKER_VFX]]:
		kind_option.add_item(str(kind_data[0]))
		kind_option.set_item_metadata(kind_option.item_count - 1, str(kind_data[1]))
		if str(kind_data[1]) == str(marker.get("kind", MotionWorkspace.MARKER_EVENT)):
			kind_option.select(kind_option.item_count - 1)
	kind_option.item_selected.connect(marker_kind_selected.emit.bind(kind_option, state_id, marker_id))
	add_child(kind_option)
	add_child(EditorWidgets.create_inspector_field_label("Normalized Phase"))
	var marker_phase := SpinBox.new()
	marker_phase.min_value = 0.0
	marker_phase.max_value = 1.0
	marker_phase.step = 0.01
	marker_phase.value = float(marker.get("phase", 0.5))
	marker_phase.value_changed.connect(marker_phase_changed.emit.bind(state_id, marker_id))
	add_child(marker_phase)
	var marker_note := EditorWidgets.create_inspector_field_label("Marker ticks are shown below the normalized Phase scrubber.")
	marker_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(marker_note)
	var remove_button := Button.new()
	remove_button.text = "Remove Marker"
	remove_button.pressed.connect(motion_item_remove_requested.emit.bind(MotionSelection.MARKER, state_id, marker_id))
	add_child(remove_button)


func _unavailable_motion_guide_field(label_text: String, tooltip: String) -> void:
	add_child(EditorWidgets.create_inspector_field_label(label_text))
	var guide_option := OptionButton.new()
	guide_option.add_item("Not available")
	guide_option.disabled = true
	guide_option.tooltip_text = tooltip
	guide_option.custom_minimum_size = Vector2(0, 28)
	add_child(guide_option)


func _motion_number_parameter(label_text: String, state_id: String, motion_id: String, parameter_name: String, value: float, minimum: float, maximum: float, step: float) -> void:
	add_child(EditorWidgets.create_inspector_field_label(label_text))
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.value = value
	field.custom_minimum_size = Vector2(0, 28)
	field.value_changed.connect(motion_parameter_changed.emit.bind(state_id, motion_id, parameter_name))
	add_child(field)
