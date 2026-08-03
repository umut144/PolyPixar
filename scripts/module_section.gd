class_name ModuleSection
extends VBoxContainer

signal module_pressed(module_name: String)
signal submodule_pressed(module_name: String, submodule_name: String)

var module_name: String
var header_button: Button
var content_panel: PanelContainer
var content_list: VBoxContainer
var expanded := false
var active_submodule := ""


func setup(section_name: String, submodules: Array, open_by_default := false, show_submodule_separators := false, separator_before_submodule_index := -1) -> void:
	module_name = section_name
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

	for submodule_index in range(submodules.size()):
		if show_submodule_separators and submodule_index > 0:
			_add_submodule_separator()
		elif submodule_index == separator_before_submodule_index:
			_add_submodule_separator(6)
		_add_submodule_button(str(submodules[submodule_index]))
	if not submodules.is_empty():
		set_active_submodule(str(submodules[0]))
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


func _add_submodule_separator(thickness := 1) -> void:
	var separator := ColorRect.new()
	separator.color = Color("#697386") if thickness > 1 else Color("#4a5260")
	separator.custom_minimum_size = Vector2(0, thickness)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_list.add_child(separator)


func set_active_submodule(submodule_name: String) -> void:
	active_submodule = submodule_name
	if not is_instance_valid(content_list):
		return
	for child in content_list.get_children():
		var button := child as Button
		if button == null:
			continue
		var is_active := button.text == active_submodule
		button.add_theme_stylebox_override("normal", _create_submodule_style(is_active, false))
		button.add_theme_stylebox_override("hover", _create_submodule_style(is_active, true))
		button.add_theme_stylebox_override("pressed", _create_submodule_style(is_active, true))
		button.add_theme_stylebox_override("focus", _create_submodule_style(is_active, false))
		button.add_theme_color_override("font_color", Color("#0b0d10") if is_active else Color("#d6dbe4"))
		button.add_theme_color_override("font_hover_color", Color("#0b0d10") if is_active else Color("#ffffff"))
		button.add_theme_color_override("font_pressed_color", Color("#0b0d10") if is_active else Color("#ffffff"))


func _create_submodule_style(is_active: bool, is_hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f2c94c") if is_active else Color("#282d36")
	if is_hovered and not is_active:
		style.bg_color = Color("#343b47")
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style


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
