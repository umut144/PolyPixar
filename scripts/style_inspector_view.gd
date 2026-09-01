class_name StyleInspectorView
extends VBoxContainer

# The Style module's Inspector, under the same contract as OutlinerView,
# CreateInspectorView and GeometryInspectorView. main.gd resolves the selected
# Component, its Weighting Style and everything derived from the Geometry
# document and the preview cache, pushes it in as one Dictionary, and rebuild()
# draws from that alone.
#
# Context keys: component, style, mesh_status, status, result, bake_enabled.
#
# The intent signals still carry the argument lists of the handlers they
# replaced.

signal bake_requested()
signal curve_selected(index: int, option: OptionButton)
signal direction_selected(index: int, option: OptionButton)
signal invert_changed(enabled: bool)
signal method_selected(index: int, option: OptionButton)
signal preview_requested()
signal section_toggled(section: VBoxContainer, text: String, header: Button)
signal strength_changed(value: float)
signal style_delete_requested()
signal style_rename_requested(new_name: String)

var context: Dictionary = {}


func set_context(weighting_context: Dictionary) -> void:
	context = weighting_context


func rebuild() -> void:
	EditorWidgets.clear(self)
	add_child(EditorWidgets.create_inspector_section("Weighting", section_toggled.emit))
	var component: Dictionary = context.get("component", {})
	if component.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("Select a Component to create or inspect Weighting Styles."))
		return
	add_child(EditorWidgets.create_inspector_field_label(str(component.get("name", "Component"))))
	var mesh_status := str(context.get("mesh_status", ""))
	var mesh_label := EditorWidgets.create_inspector_field_label("Component Mesh: %s" % mesh_status)
	mesh_label.add_theme_color_override("font_color", Color("#75b88a") if mesh_status == "Ready" else Color("#ef8354"))
	add_child(mesh_label)
	var style: Dictionary = context.get("style", {})
	if style.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("Create or select a Weighting Style."))
		return
	add_child(EditorWidgets.create_inspector_field_label("Name"))
	var name_editor := EditorWidgets.create_name_editor(str(style.get("name", "Weighting Style")), "Weighting Style name")
	name_editor.text_submitted.connect(style_rename_requested.emit)
	name_editor.focus_exited.connect(func() -> void: style_rename_requested.emit(name_editor.text))
	add_child(name_editor)
	add_child(EditorWidgets.create_inspector_section("Method", section_toggled.emit))
	add_child(EditorWidgets.create_option_field([
		{"label": "Uniform", "metadata": WeightingService.UNIFORM},
		{"label": "Axis Gradient", "metadata": WeightingService.AXIS_GRADIENT},
	], str(style.get("method", "")), method_selected.emit, false))
	add_child(EditorWidgets.create_inspector_section("Parameters", section_toggled.emit))
	if str(style.get("method", "")) == WeightingService.AXIS_GRADIENT:
		add_child(EditorWidgets.create_inspector_field_label("Direction"))
		add_child(EditorWidgets.create_option_field([
			{"label": "Bottom → Top", "metadata": WeightingService.BOTTOM_TO_TOP},
			{"label": "Top → Bottom", "metadata": WeightingService.TOP_TO_BOTTOM},
			{"label": "Left → Right", "metadata": WeightingService.LEFT_TO_RIGHT},
			{"label": "Right → Left", "metadata": WeightingService.RIGHT_TO_LEFT},
		], str(style.get("parameters", {}).get("direction", "")), direction_selected.emit, false))
		add_child(EditorWidgets.create_inspector_field_label("Curve"))
		add_child(EditorWidgets.create_option_field([
			{"label": "Linear", "metadata": WeightingService.LINEAR},
			{"label": "Ease In", "metadata": WeightingService.EASE_IN},
			{"label": "Ease Out", "metadata": WeightingService.EASE_OUT},
			{"label": "Smooth", "metadata": WeightingService.SMOOTH},
		], str(style.get("parameters", {}).get("curve", "")), curve_selected.emit, false))
		var invert := CheckBox.new()
		invert.text = "Invert"
		invert.button_pressed = bool(style.get("parameters", {}).get("invert", false))
		invert.toggled.connect(invert_changed.emit)
		add_child(invert)
	add_child(EditorWidgets.create_inspector_field_label("Strength"))
	var strength := SpinBox.new()
	strength.min_value = 0.0
	strength.max_value = 1.0
	strength.step = 0.01
	strength.set_value_no_signal(float(style.get("parameters", {}).get("strength", 1.0)))
	strength.value_changed.connect(strength_changed.emit)
	add_child(strength)
	var status := str(context.get("status", ""))
	add_child(EditorWidgets.create_inspector_section("Result", section_toggled.emit))
	add_child(EditorWidgets.create_inspector_field_label("Status: %s" % status))
	var result: Dictionary = context.get("result", {})
	if not result.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("Vertices: %d" % int(result.get("weight_count", 0))))
		add_child(EditorWidgets.create_inspector_field_label("Range: %.2f → %.2f" % [float(result.get("minimum_weight", 0.0)), float(result.get("maximum_weight", 0.0))]))
	var actions := HBoxContainer.new()
	var generate_button := Button.new()
	generate_button.text = "Generate"
	generate_button.disabled = mesh_status != "Ready"
	generate_button.pressed.connect(preview_requested.emit)
	actions.add_child(generate_button)
	var bake_button := Button.new()
	bake_button.text = "Bake"
	bake_button.disabled = not bool(context.get("bake_enabled", false))
	bake_button.pressed.connect(bake_requested.emit)
	actions.add_child(bake_button)
	add_child(actions)
	var delete_button := Button.new()
	delete_button.text = "Delete Weighting Style"
	delete_button.pressed.connect(style_delete_requested.emit)
	add_child(delete_button)
