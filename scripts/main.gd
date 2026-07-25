extends Control

const BACKGROUND := Color("#2b2b2b")
const PANEL := Color("#202020")
const PANEL_ALT := Color("#252525")
const PANEL_HOVER := Color("#343434")
const BORDER := Color("#383838")
const TEXT := Color("#d6d6d6")
const MUTED := Color("#8b8b8b")
const ACCENT := Color("#ffcc2d")
const ACCENT_SOFT := Color("#3a3a3a")
const GOOD := Color("#8fc58a")


class WorkspaceCanvas extends Control:
	var mode := "create"

	func _ready() -> void:
		custom_minimum_size = Vector2(320, 240)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
		match mode:
			"transform":
				_draw_transform_preview()
			"effects":
				_draw_effect_preview()
			"style":
				_draw_style_preview()
			_:
				_draw_asset_canvas()

	func _draw_asset_canvas() -> void:
		var edge := maxf(96.0, minf(size.x - 72.0, size.y - 48.0))
		var rect := Rect2(Vector2((size.x - edge) * 0.5, (size.y - edge) * 0.5), Vector2(edge, edge))
		draw_rect(rect, Color("#f6f6f6"))
		for step in range(0, int(edge) + 1, 32):
			var color := Color("#e4e4e4") if step % 64 != 0 else Color("#cfcfcf")
			draw_line(rect.position + Vector2(step, 0), rect.position + Vector2(step, edge), color, 1.0)
			draw_line(rect.position + Vector2(0, step), rect.position + Vector2(edge, step), color, 1.0)

	func _draw_transform_preview() -> void:
		var block := Vector2(maxf(80.0, size.x * 0.24), maxf(80.0, size.y * 0.42))
		var left := Rect2(Vector2(size.x * 0.18 - block.x * 0.5, size.y * 0.5 - block.y * 0.5), block)
		var right := Rect2(Vector2(size.x * 0.82 - block.x * 0.5, size.y * 0.5 - block.y * 0.5), block)
		draw_rect(left, Color("#f1f1f1"))
		draw_rect(right, Color("#e2e2e2"))
		var start := left.get_center() + Vector2(block.x * 0.58, 0)
		var end := right.get_center() - Vector2(block.x * 0.58, 0)
		draw_line(start, end, ACCENT, 2.0)
		draw_circle(end, 5.0, ACCENT)

	func _draw_effect_preview() -> void:
		var origin := Vector2(size.x * 0.5, size.y * 0.7)
		for index in 7:
			var angle := lerpf(-2.75, -0.4, float(index) / 6.0)
			var end := origin + Vector2(cos(angle), sin(angle)) * minf(size.x, size.y) * (0.24 + 0.04 * (index % 3))
			draw_line(origin, end, GOOD, 2.0)
			draw_circle(end, 3.0, GOOD)

	func _draw_style_preview() -> void:
		var block := Vector2(maxf(90.0, size.x * 0.18), maxf(110.0, size.y * 0.5))
		var start_x := size.x * 0.5 - block.x * 1.7
		for index in 3:
			var color: Color = [Color("#d79556"), Color("#7664b7"), Color("#469b91")][index]
			draw_rect(Rect2(Vector2(start_x + index * block.x * 1.2, size.y * 0.5 - block.y * 0.5), block), color)

const MODULES := [
	{
		"id": "create",
		"label": "Create",
		"submodules": ["Shapes", "Layers"],
		"tools": ["Select", "Polyline", "Add Point"],
		"actions": ["Snap: On", "Grid: 16 px", "Close Shape"],
		"title": "Create / Shapes",
		"description": "Create the first visual form of an asset. This is a placeholder canvas; no drawing tools exist yet.",
	},
	{
		"id": "style",
		"label": "Style",
		"submodules": ["Color", "Masks"],
		"tools": ["Select", "Fill", "Sample"],
		"actions": ["Palette: Warm", "Opacity: 100%", "Blend: Normal"],
		"title": "Style / Color",
		"description": "Try visual appearance decisions here. Material and map authoring remain outside the UI skeleton.",
	},
	{
		"id": "motion",
		"label": "Motion",
		"submodules": ["Presets", "Paths", "Timeline"],
		"tools": ["Select", "Sway", "Jitter"],
		"actions": ["Loop: On", "Ease: Smooth", "Add Keyframe"],
		"title": "Motion / Presets",
		"description": "Motion is local to an asset. The lower time area is a contextual placeholder for that asset's motion.",
	},
	{
		"id": "transform",
		"label": "Transform",
		"submodules": ["Mapping", "Shape", "Timing"],
		"tools": ["Select Pair", "Map Shapes", "Add Middle"],
		"actions": ["Duration: 0.5 s", "Ease: Arc", "Preview Morph"],
		"title": "Transform / Mapping",
		"description": "Design a deliberate transition between independent assets. This does not turn either asset into a form state of the other.",
	},
	{
		"id": "effects",
		"label": "Effects",
		"submodules": ["Trails", "Root Growth"],
		"tools": ["Select", "Add Trail", "Set Origin"],
		"actions": ["Seed: 421", "Density: Medium", "Preview Effect"],
		"title": "Effects / Trails",
		"description": "Effects are configured in context. Root Growth exposes a local time control; Trails remain a static placeholder in this prototype.",
	},
	{
		"id": "export",
		"label": "Export",
		"submodules": ["Preview", "Spritesheet"],
		"tools": ["Frame", "Crop", "Check Output"],
		"actions": ["Size: 1024", "Format: PNG", "Export (Dummy)"],
		"title": "Export / Preview",
		"description": "Export is a dedicated final area. The UI skeleton only previews the chosen output intent.",
	},
]

var active_module_id := "create"
var active_submodule := "Shapes"
var active_tool := "Select"
var selected_outline_item := "hat_shape"
var expanded_outline := {
	"hat": true,
	"star": true,
	"morph": true,
	"root": true,
}

var module_rail: VBoxContainer
var outliner_list: VBoxContainer
var toolbar_tools: HBoxContainer
var action_controls: HBoxContainer
var workspace_content: VBoxContainer
var inspector_content: VBoxContainer


func _ready() -> void:
	_build_shell()
	_render_all()


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

	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size = Vector2(0, 28)
	toolbar.add_theme_constant_override("separation", 4)
	root.add_child(toolbar)
	toolbar_tools = HBoxContainer.new()
	toolbar_tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_tools.add_theme_constant_override("separation", 4)
	toolbar.add_child(toolbar_tools)
	var preview_button := _button("Preview", false)
	preview_button.pressed.connect(_noop)
	toolbar.add_child(preview_button)
	var export_button := _button("Export", false)
	export_button.pressed.connect(_activate_module.bind("export"))
	toolbar.add_child(export_button)

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
	var action_row := HBoxContainer.new()
	action_row.custom_minimum_size = Vector2(0, 28)
	action_row.add_theme_constant_override("separation", 4)
	centre.add_child(action_row)
	action_controls = HBoxContainer.new()
	action_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_controls.add_theme_constant_override("separation", 4)
	action_row.add_child(action_controls)
	workspace_content = VBoxContainer.new()
	workspace_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_content.add_theme_constant_override("separation", 4)
	centre.add_child(workspace_content)

	var inspector_panel := _panel(PANEL)
	inspector_panel.custom_minimum_size = Vector2(210, 0)
	workspace_split.add_child(inspector_panel)
	var inspector_margin := _margin(inspector_panel, 8, 8)
	var inspector_scroll := ScrollContainer.new()
	inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector_margin.add_child(inspector_scroll)
	inspector_content = VBoxContainer.new()
	inspector_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_content.add_theme_constant_override("separation", 4)
	inspector_scroll.add_child(inspector_content)

	var status_panel := _panel(PANEL_ALT)
	status_panel.custom_minimum_size = Vector2(0, 18)
	root.add_child(status_panel)


func _render_all() -> void:
	_render_module_rail()
	_render_toolbar()
	_render_actions()
	_render_outliner()
	_render_workspace()
	_render_inspector()


func _render_module_rail() -> void:
	_clear(module_rail)
	for module in MODULES:
		if module.id == "export":
			continue
		var button := _button(module.label, module.id == active_module_id)
		button.custom_minimum_size = Vector2(0, 34)
		button.tooltip_text = module.label
		button.pressed.connect(_activate_module.bind(module.id))
		module_rail.add_child(button)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	module_rail.add_child(spacer)
	var export_module: Dictionary = _module_by_id("export")
	var export_button := _button(export_module.label, active_module_id == "export")
	export_button.custom_minimum_size = Vector2(0, 34)
	export_button.tooltip_text = "Open Export"
	export_button.pressed.connect(_activate_module.bind("export"))
	module_rail.add_child(export_button)


func _render_toolbar() -> void:
	_clear(toolbar_tools)
	var module: Dictionary = _active_module()
	for tool_name in module.tools:
		var button := _button(tool_name, tool_name == active_tool)
		button.pressed.connect(_activate_tool.bind(tool_name))
		toolbar_tools.add_child(button)


func _render_actions() -> void:
	_clear(action_controls)
	var module: Dictionary = _active_module()
	for action_name in module.actions:
		var button := _button(action_name, false)
		button.pressed.connect(_noop)
		action_controls.add_child(button)


func _render_outliner() -> void:
	_clear(outliner_list)
	var module: Dictionary = _active_module()
	for submodule in module.submodules:
		var submodule_button := _button(submodule, submodule == active_submodule)
		submodule_button.custom_minimum_size = Vector2(0, 30)
		submodule_button.pressed.connect(_activate_submodule.bind(submodule))
		outliner_list.add_child(submodule_button)
	var entries := _outline_entries()
	var entries_by_id := {}
	for entry in entries:
		entries_by_id[entry.id] = entry
	for entry in entries:
		if not _is_outline_entry_visible(entry, entries_by_id):
			continue
		var has_children: bool = entry.has("children") and not entry.children.is_empty()
		var row_text: String = str(entry.label)
		var button := _button(row_text, selected_outline_item == entry.id and not has_children)
		button.custom_minimum_size = Vector2(0, 28)
		if has_children:
			button.pressed.connect(_toggle_outline_parent.bind(entry.id))
		else:
			button.pressed.connect(_select_outline_item.bind(entry.id))
		outliner_list.add_child(button)


func _render_workspace() -> void:
	_clear(workspace_content)
	var canvas := WorkspaceCanvas.new()
	canvas.mode = active_module_id
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_content.add_child(canvas)
	if _shows_time_area():
		workspace_content.add_child(_time_area())


func _render_inspector() -> void:
	_clear(inspector_content)
	for index in 4:
		var slider := HSlider.new()
		slider.value = 25 + index * 20
		slider.custom_minimum_size = Vector2(0, 28)
		inspector_content.add_child(slider)


func _activate_module(module_id: String) -> void:
	active_module_id = module_id
	var module: Dictionary = _active_module()
	active_submodule = module.submodules[0]
	active_tool = module.tools[0]
	_render_all()


func _activate_submodule(submodule: String) -> void:
	active_submodule = submodule
	_render_all()


func _activate_tool(tool_name: String) -> void:
	active_tool = tool_name
	_render_all()


func _toggle_outline_parent(parent_id: String) -> void:
	expanded_outline[parent_id] = not expanded_outline.get(parent_id, true)
	_render_outliner()


func _select_outline_item(item_id: String) -> void:
	selected_outline_item = item_id
	_render_outliner()
	_render_inspector()


func _active_module() -> Dictionary:
	return _module_by_id(active_module_id)


func _module_by_id(module_id: String) -> Dictionary:
	for module in MODULES:
		if module.id == module_id:
			return module
	return MODULES[0]


func _outline_entries() -> Array:
	match active_module_id:
		"motion":
			return [
				{"id": "hat", "label": "Wizard Hat", "depth": 0, "children": ["hat_sway", "hat_anchor"]},
				{"id": "hat_sway", "label": "Sway", "depth": 1, "parent_id": "hat"},
				{"id": "hat_anchor", "label": "Hat Tip", "depth": 1, "parent_id": "hat"},
				{"id": "star", "label": "Star", "depth": 0, "children": ["star_jitter"]},
				{"id": "star_jitter", "label": "Jitter", "depth": 1, "parent_id": "star"},
			]
		"transform":
			return [
				{"id": "morph", "label": "Hat to Star", "depth": 0, "children": ["source", "target", "mapping"]},
				{"id": "source", "label": "Source: Wizard Hat", "depth": 1, "parent_id": "morph"},
				{"id": "target", "label": "Target: Star", "depth": 1, "parent_id": "morph"},
				{"id": "mapping", "label": "Shape Mapping", "depth": 1, "parent_id": "morph"},
			]
		"effects":
			return [
				{"id": "root", "label": "Root Growth", "depth": 0, "children": ["origin", "branches", "seed"]},
				{"id": "origin", "label": "Origin", "depth": 1, "parent_id": "root"},
				{"id": "branches", "label": "Branches", "depth": 1, "parent_id": "root"},
				{"id": "seed", "label": "Seed: 421", "depth": 1, "parent_id": "root"},
			]
		"export":
			return [
				{"id": "output", "label": "Hat to Star Preview", "depth": 0, "children": ["resolution", "format"]},
				{"id": "resolution", "label": "1024 × 1024", "depth": 1, "parent_id": "output"},
				{"id": "format", "label": "PNG", "depth": 1, "parent_id": "output"},
			]
		_:
			return [
				{"id": "hat", "label": "Wizard Hat", "depth": 0, "children": ["hat_shape", "hat_anchors"]},
				{"id": "hat_shape", "label": "Shape", "depth": 1, "parent_id": "hat"},
				{"id": "hat_anchors", "label": "Anchors", "depth": 1, "parent_id": "hat"},
				{"id": "star", "label": "Star", "depth": 0, "children": ["star_shape", "star_tips"]},
				{"id": "star_shape", "label": "Shape", "depth": 1, "parent_id": "star"},
				{"id": "star_tips", "label": "Star Tips", "depth": 1, "parent_id": "star"},
			]


func _is_outline_entry_visible(entry: Dictionary, entries_by_id: Dictionary) -> bool:
	var parent_id: String = entry.get("parent_id", "")
	while not parent_id.is_empty():
		if not expanded_outline.get(parent_id, true):
			return false
		var parent: Dictionary = entries_by_id.get(parent_id, {})
		parent_id = parent.get("parent_id", "")
	return true


func _shows_time_area() -> bool:
	return active_module_id == "motion" or active_module_id == "transform" or (active_module_id == "effects" and active_submodule == "Root Growth")


func _time_area() -> PanelContainer:
	var panel := _panel(PANEL_ALT)
	panel.custom_minimum_size = Vector2(0, 110)
	var margin := _margin(panel, 8, 6)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	for index in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		stack.add_child(row)
		var marker := ColorRect.new()
		marker.color = ACCENT if index == 0 else BORDER
		marker.custom_minimum_size = Vector2(42, 16)
		row.add_child(marker)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.value = 42.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.tooltip_text = "Dummy timeline track"
		row.add_child(slider)
		var keyframe := ColorRect.new()
		keyframe.color = ACCENT
		keyframe.custom_minimum_size = Vector2(16, 16)
		row.add_child(keyframe)
	return panel


func _panel(background: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(background, BORDER, 0))
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
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color("#f0f0f0"))
	button.add_theme_stylebox_override("normal", _style(ACCENT if active else PANEL, Color.TRANSPARENT, 0))
	button.add_theme_stylebox_override("hover", _style(PANEL_HOVER, Color.TRANSPARENT, 0))
	button.add_theme_stylebox_override("pressed", _style(ACCENT_SOFT, Color.TRANSPARENT, 0))
	if active:
		button.add_theme_color_override("font_color", Color("#202020"))
	return button


func _style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style


func _noop() -> void:
	pass


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
