class_name ModuleSection
extends VBoxContainer

signal module_pressed(module_name: String)
signal submodule_pressed(module_name: String, submodule_name: String)

var module_name: String
var header_button: Button
var content_panel: PanelContainer
var content_list: VBoxContainer
var expanded := false


func setup(name: String, submodules: Array, open_by_default := false) -> void:
	module_name = name
	header_button = Button.new()
	header_button.text = module_name
	header_button.custom_minimum_size = Vector2(0, 32)
	header_button.focus_mode = Control.FOCUS_NONE
	header_button.toggle_mode = true
	header_button.pressed.connect(_toggle)
	add_child(header_button)

	content_panel = PanelContainer.new()
	content_panel.visible = false
	content_panel.add_theme_stylebox_override("panel", _create_content_style())
	add_child(content_panel)
	content_list = VBoxContainer.new()
	content_list.add_theme_constant_override("separation", 2)
	content_panel.add_child(content_list)

	for submodule in submodules:
		_add_submodule_button(str(submodule))
	set_expanded(open_by_default)


func set_expanded(value: bool) -> void:
	expanded = value
	if is_instance_valid(content_panel):
		content_panel.visible = expanded
	if is_instance_valid(header_button):
		header_button.button_pressed = expanded


func _toggle() -> void:
	set_expanded(not expanded)
	module_pressed.emit(module_name)


func _add_submodule_button(submodule_name: String) -> void:
	var button := Button.new()
	button.text = submodule_name
	button.custom_minimum_size = Vector2(0, 30)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void:
		submodule_pressed.emit(module_name, submodule_name)
	)
	content_list.add_child(button)


func _create_content_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1b1e24")
	style.border_color = Color("#363d48")
	style.set_border_width_all(1)
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style
