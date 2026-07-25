extends Control

const CREATE_SUBMODULES := ["Shapes", "Layers"]
const INACTIVE_MODULES := ["Style", "Motion", "Transform", "Effects", "Export"]

var active_create_submodule := "Shapes"
var outliner_list: VBoxContainer


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#181a1f")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

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

	var toolbar_panel := _create_panel()
	main_layout.add_child(toolbar_panel)
	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size = Vector2(0, 32)
	toolbar_panel.add_child(toolbar)

	var workspace_row := HBoxContainer.new()
	workspace_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_row.add_theme_constant_override("separation", 8)
	main_layout.add_child(workspace_row)

	var module_rail_panel := _create_panel(Color("#20242c"))
	module_rail_panel.custom_minimum_size = Vector2(104, 0)
	workspace_row.add_child(module_rail_panel)
	var module_rail := VBoxContainer.new()
	module_rail.add_theme_constant_override("separation", 4)
	module_rail_panel.add_child(module_rail)
	_add_module_section(module_rail, "Create", CREATE_SUBMODULES, true)
	for module_name in INACTIVE_MODULES:
		_add_module_section(module_rail, module_name, [])

	var workspace_split := HSplitContainer.new()
	workspace_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_split.split_offset = 220
	workspace_row.add_child(workspace_split)

	var outliner_panel := _create_panel()
	outliner_panel.custom_minimum_size = Vector2(180, 0)
	workspace_split.add_child(outliner_panel)
	var outliner_content := VBoxContainer.new()
	outliner_content.add_theme_constant_override("separation", 4)
	outliner_panel.add_child(outliner_content)
	outliner_content.add_child(_create_panel_label("Outliner"))
	var outliner_scroll := ScrollContainer.new()
	outliner_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outliner_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outliner_content.add_child(outliner_scroll)
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

	var action_bar_panel := _create_panel()
	canvas_column.add_child(action_bar_panel)
	var action_bar := HBoxContainer.new()
	action_bar.custom_minimum_size = Vector2(0, 32)
	action_bar_panel.add_child(action_bar)

	var canvas_panel := _create_panel(Color("#1b1e24"))
	canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_column.add_child(canvas_panel)
	var canvas := Control.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_panel.add_child(canvas)

	var inspector_panel := _create_panel()
	inspector_panel.custom_minimum_size = Vector2(260, 0)
	canvas_split.add_child(inspector_panel)
	var inspector_content := VBoxContainer.new()
	inspector_content.add_theme_constant_override("separation", 4)
	inspector_panel.add_child(inspector_content)
	inspector_content.add_child(_create_panel_label("Inspector"))

	var status_bar := _create_panel()
	status_bar.custom_minimum_size = Vector2(0, 24)
	main_layout.add_child(status_bar)


func _create_panel(background_color := Color("#20242c")) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = Color("#363d48")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _create_panel_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(0, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#9aa3b2"))
	return label


func _add_module_section(parent: Container, module_name: String, submodules: Array, open_by_default := false) -> void:
	var section := ModuleSection.new()
	section.setup(module_name, submodules, open_by_default)
	section.submodule_pressed.connect(_select_create_submodule)
	parent.add_child(section)


func _select_create_submodule(_module_name: String, submodule: String) -> void:
	active_create_submodule = submodule
