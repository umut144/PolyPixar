extends Control

const CREATE_SUBMODULES := ["Shapes", "Layers"]
const INACTIVE_MODULES := ["Style", "Motion", "Transform", "Effects", "Export"]

var active_create_submodule := "Shapes"
var create_button: Button
var outliner_list: VBoxContainer


func _ready() -> void:
	_build_ui()
	_render_create_outliner()


func _build_ui() -> void:
	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 12)
	root_margin.add_theme_constant_override("margin_top", 12)
	root_margin.add_theme_constant_override("margin_right", 12)
	root_margin.add_theme_constant_override("margin_bottom", 12)
	add_child(root_margin)

	var main_layout := VBoxContainer.new()
	main_layout.add_theme_constant_override("separation", 8)
	root_margin.add_child(main_layout)

	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size = Vector2(0, 32)
	main_layout.add_child(toolbar)

	var workspace_row := HBoxContainer.new()
	workspace_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_row.add_theme_constant_override("separation", 8)
	main_layout.add_child(workspace_row)

	var module_rail := VBoxContainer.new()
	module_rail.custom_minimum_size = Vector2(104, 0)
	module_rail.add_theme_constant_override("separation", 4)
	workspace_row.add_child(module_rail)
	create_button = _add_module_button(module_rail, "Create", true)
	for module_name in INACTIVE_MODULES:
		_add_module_button(module_rail, module_name, false)

	var workspace_split := HSplitContainer.new()
	workspace_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_split.split_offset = 220
	workspace_row.add_child(workspace_split)

	var outliner_panel := PanelContainer.new()
	outliner_panel.custom_minimum_size = Vector2(180, 0)
	workspace_split.add_child(outliner_panel)
	var outliner_scroll := ScrollContainer.new()
	outliner_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outliner_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outliner_panel.add_child(outliner_scroll)
	outliner_list = VBoxContainer.new()
	outliner_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outliner_list.add_theme_constant_override("separation", 0)
	outliner_scroll.add_child(outliner_list)

	var canvas_split := HSplitContainer.new()
	canvas_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_split.split_offset = 820
	workspace_split.add_child(canvas_split)

	var canvas_column := VBoxContainer.new()
	canvas_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_column.add_theme_constant_override("separation", 8)
	canvas_split.add_child(canvas_column)

	var action_bar := HBoxContainer.new()
	action_bar.custom_minimum_size = Vector2(0, 32)
	canvas_column.add_child(action_bar)

	var canvas := Control.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_column.add_child(canvas)

	var inspector_panel := PanelContainer.new()
	inspector_panel.custom_minimum_size = Vector2(260, 0)
	canvas_split.add_child(inspector_panel)

	var status_bar := PanelContainer.new()
	status_bar.custom_minimum_size = Vector2(0, 24)
	main_layout.add_child(status_bar)


func _add_module_button(parent: Container, text: String, is_active: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 32)
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = is_active
	button.button_pressed = is_active
	if is_active:
		button.pressed.connect(_activate_create)
	parent.add_child(button)
	return button


func _activate_create() -> void:
	create_button.button_pressed = true
	_render_create_outliner()


func _render_create_outliner() -> void:
	_clear(outliner_list)
	for submodule in CREATE_SUBMODULES:
		var button := Button.new()
		button.text = submodule
		button.custom_minimum_size = Vector2(0, 30)
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.button_pressed = submodule == active_create_submodule
		button.pressed.connect(_select_create_submodule.bind(submodule))
		outliner_list.add_child(button)


func _select_create_submodule(submodule: String) -> void:
	active_create_submodule = submodule
	_render_create_outliner()


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
