extends Control

const BACKGROUND := Color("#2b2b2b")
const PANEL := Color("#202020")
const PANEL_ALT := Color("#252525")
const PANEL_HOVER := Color("#343434")
const TEXT := Color("#d6d6d6")
const ACCENT := Color("#ffcc2d")

const MODULES := [
	{"id": "create", "label": "Create", "submodules": ["Shapes", "Layers"]},
	{"id": "style", "label": "Style", "submodules": ["Color", "Masks"]},
	{"id": "motion", "label": "Motion", "submodules": ["Presets", "Paths", "Timeline"]},
	{"id": "transform", "label": "Transform", "submodules": ["Mapping", "Shape", "Timing"]},
	{"id": "effects", "label": "Effects", "submodules": ["Trails", "Root Growth"]},
	{"id": "export", "label": "Export", "submodules": ["Preview", "Spritesheet"]},
]

var active_module_id := "create"
var active_submodule := "Shapes"

var module_rail: VBoxContainer
var outliner_list: VBoxContainer


func _ready() -> void:
	_build_shell()
	_render_navigation()


func _build_shell() -> void:
	var frame := _panel(BACKGROUND)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)

	var root_margin := _margin(frame, 4, 4)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 4)
	root_margin.add_child(root)

	var toolbar_strip := _panel(PANEL)
	toolbar_strip.custom_minimum_size = Vector2(0, 28)
	root.add_child(toolbar_strip)

	var main_area := HBoxContainer.new()
	main_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_area.add_theme_constant_override("separation", 4)
	root.add_child(main_area)

	var rail_panel := _panel(PANEL_ALT)
	rail_panel.custom_minimum_size = Vector2(84, 0)
	main_area.add_child(rail_panel)
	var rail_margin := _margin(rail_panel, 4, 4)
	module_rail = VBoxContainer.new()
	module_rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	module_rail.add_theme_constant_override("separation", 2)
	rail_margin.add_child(module_rail)

	var outer_split := HSplitContainer.new()
	outer_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_split.split_offset = 220
	main_area.add_child(outer_split)

	var outliner_panel := _panel(PANEL)
	outliner_panel.custom_minimum_size = Vector2(170, 0)
	outer_split.add_child(outliner_panel)
	var outliner_scroll := ScrollContainer.new()
	outliner_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outliner_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outliner_panel.add_child(outliner_scroll)
	outliner_list = VBoxContainer.new()
	outliner_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outliner_list.add_theme_constant_override("separation", 0)
	outliner_scroll.add_child(outliner_list)

	var workspace_split := HSplitContainer.new()
	workspace_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_split.split_offset = 820
	outer_split.add_child(workspace_split)

	var centre := VBoxContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centre.add_theme_constant_override("separation", 4)
	workspace_split.add_child(centre)
	var action_strip := _panel(PANEL_ALT)
	action_strip.custom_minimum_size = Vector2(0, 28)
	centre.add_child(action_strip)
	var workspace := _panel(BACKGROUND)
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centre.add_child(workspace)

	var inspector := _panel(PANEL)
	inspector.custom_minimum_size = Vector2(210, 0)
	workspace_split.add_child(inspector)

	var status_strip := _panel(PANEL_ALT)
	status_strip.custom_minimum_size = Vector2(0, 18)
	root.add_child(status_strip)


func _render_navigation() -> void:
	_clear(module_rail)
	for module in MODULES:
		if module.id == "export":
			continue
		var button := _button(module.label, module.id == active_module_id)
		button.custom_minimum_size = Vector2(0, 34)
		button.pressed.connect(_activate_module.bind(module.id))
		module_rail.add_child(button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	module_rail.add_child(spacer)
	var export_module: Dictionary = _module_by_id("export")
	var export_button := _button(export_module.label, active_module_id == "export")
	export_button.custom_minimum_size = Vector2(0, 34)
	export_button.pressed.connect(_activate_module.bind("export"))
	module_rail.add_child(export_button)

	_clear(outliner_list)
	var active_module: Dictionary = _active_module()
	for submodule in active_module.submodules:
		var submodule_button := _button(submodule, submodule == active_submodule)
		submodule_button.custom_minimum_size = Vector2(0, 30)
		submodule_button.pressed.connect(_activate_submodule.bind(submodule))
		outliner_list.add_child(submodule_button)


func _activate_module(module_id: String) -> void:
	active_module_id = module_id
	active_submodule = _active_module().submodules[0]
	_render_navigation()


func _activate_submodule(submodule: String) -> void:
	active_submodule = submodule
	_render_navigation()


func _active_module() -> Dictionary:
	return _module_by_id(active_module_id)


func _module_by_id(module_id: String) -> Dictionary:
	for module in MODULES:
		if module.id == module_id:
			return module
	return MODULES[0]


func _panel(background: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(background))
	return panel


func _margin(parent: Control, horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	parent.add_child(margin)
	return margin


func _button(text: String, active: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("#202020") if active else TEXT)
	button.add_theme_color_override("font_hover_color", Color("#f0f0f0"))
	button.add_theme_stylebox_override("normal", _style(ACCENT if active else PANEL))
	button.add_theme_stylebox_override("hover", _style(PANEL_HOVER))
	button.add_theme_stylebox_override("pressed", _style(PANEL_ALT))
	return button


func _style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	return style


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
