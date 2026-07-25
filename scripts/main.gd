extends Control

const BACKGROUND := Color("#101319")
const PANEL := Color("#171c25")
const PANEL_ALT := Color("#1d2430")
const PANEL_HOVER := Color("#273243")
const BORDER := Color("#303b4c")
const TEXT := Color("#e5edf7")
const MUTED := Color("#93a2b7")
const ACCENT := Color("#75b6ff")
const ACCENT_SOFT := Color("#233d5b")
const GOOD := Color("#79d2a6")

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
var status_message := "Ready for UX review"
var expanded_outline := {
	"hat": true,
	"star": true,
	"morph": true,
	"root": true,
}

var module_rail: VBoxContainer
var submodule_list: VBoxContainer
var outliner_list: VBoxContainer
var toolbar_tools: HBoxContainer
var action_controls: HBoxContainer
var workspace_content: VBoxContainer
var inspector_content: VBoxContainer
var status_document: Label
var status_info: Label
var status_coordinates: Label
var toolbar_context: Label
var action_context: Label


func _ready() -> void:
	_build_shell()
	_render_all()


func _build_shell() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var toolbar_panel := _panel(PANEL)
	toolbar_panel.custom_minimum_size = Vector2(0, 58)
	root.add_child(toolbar_panel)
	var toolbar_margin := _margin(toolbar_panel, 12, 8)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 10)
	toolbar_margin.add_child(toolbar)

	var app_name := _label("AssetFlow2D", TEXT, 18)
	app_name.custom_minimum_size = Vector2(138, 0)
	toolbar.add_child(app_name)
	var divider := VSeparator.new()
	toolbar.add_child(divider)
	toolbar_context = _label("Asset / Wizard Hat", MUTED, 14)
	toolbar_context.custom_minimum_size = Vector2(190, 0)
	toolbar.add_child(toolbar_context)
	var second_divider := VSeparator.new()
	toolbar.add_child(second_divider)
	toolbar_tools = HBoxContainer.new()
	toolbar_tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_tools.add_theme_constant_override("separation", 6)
	toolbar.add_child(toolbar_tools)
	var preview_button := _button("▶ Preview", false)
	preview_button.tooltip_text = "Placeholder preview action"
	preview_button.pressed.connect(_set_status.bind("Preview is a UI placeholder."))
	toolbar.add_child(preview_button)
	var export_button := _button("Export", false)
	export_button.pressed.connect(_activate_module.bind("export"))
	toolbar.add_child(export_button)

	var main_area := HBoxContainer.new()
	main_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_area.add_theme_constant_override("separation", 0)
	root.add_child(main_area)

	var rail_panel := _panel(PANEL_ALT)
	rail_panel.custom_minimum_size = Vector2(92, 0)
	main_area.add_child(rail_panel)
	var rail_margin := _margin(rail_panel, 8, 10)
	module_rail = VBoxContainer.new()
	module_rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	module_rail.add_theme_constant_override("separation", 6)
	rail_margin.add_child(module_rail)

	var context_panel := _panel(PANEL)
	context_panel.custom_minimum_size = Vector2(230, 0)
	main_area.add_child(context_panel)
	var context_margin := _margin(context_panel, 12, 12)
	var context_stack := VBoxContainer.new()
	context_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	context_stack.add_theme_constant_override("separation", 8)
	context_margin.add_child(context_stack)
	context_stack.add_child(_section_heading("WORKSPACE"))
	submodule_list = VBoxContainer.new()
	submodule_list.add_theme_constant_override("separation", 4)
	context_stack.add_child(submodule_list)
	context_stack.add_child(HSeparator.new())
	context_stack.add_child(_section_heading("OUTLINER"))
	var outliner_scroll := ScrollContainer.new()
	outliner_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outliner_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	context_stack.add_child(outliner_scroll)
	outliner_list = VBoxContainer.new()
	outliner_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outliner_list.add_theme_constant_override("separation", 2)
	outliner_scroll.add_child(outliner_list)

	var centre := VBoxContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centre.add_theme_constant_override("separation", 0)
	main_area.add_child(centre)
	var action_panel := _panel(PANEL_ALT)
	action_panel.custom_minimum_size = Vector2(0, 48)
	centre.add_child(action_panel)
	var action_margin := _margin(action_panel, 12, 6)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	action_margin.add_child(action_row)
	action_context = _label("Tool settings", MUTED, 13)
	action_context.custom_minimum_size = Vector2(130, 0)
	action_row.add_child(action_context)
	action_controls = HBoxContainer.new()
	action_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_controls.add_theme_constant_override("separation", 6)
	action_row.add_child(action_controls)
	var workspace_panel := _panel(BACKGROUND)
	workspace_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centre.add_child(workspace_panel)
	var workspace_margin := _margin(workspace_panel, 22, 18)
	workspace_content = VBoxContainer.new()
	workspace_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_content.add_theme_constant_override("separation", 12)
	workspace_margin.add_child(workspace_content)

	var inspector_panel := _panel(PANEL)
	inspector_panel.custom_minimum_size = Vector2(270, 0)
	main_area.add_child(inspector_panel)
	var inspector_margin := _margin(inspector_panel, 12, 12)
	var inspector_stack := VBoxContainer.new()
	inspector_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_margin.add_child(inspector_stack)
	inspector_stack.add_child(_section_heading("INSPECTOR"))
	var inspector_scroll := ScrollContainer.new()
	inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector_stack.add_child(inspector_scroll)
	inspector_content = VBoxContainer.new()
	inspector_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_content.add_theme_constant_override("separation", 8)
	inspector_scroll.add_child(inspector_content)

	var status_panel := _panel(PANEL_ALT)
	status_panel.custom_minimum_size = Vector2(0, 34)
	root.add_child(status_panel)
	var status_row := HBoxContainer.new()
	status_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status_row.add_theme_constant_override("separation", 1)
	status_panel.add_child(status_row)
	status_document = _status_cell("Document  •  Hat to Star Prototype", 280)
	status_info = _status_cell("Ready", 0)
	status_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_coordinates = _status_cell("Zoom 100%   X: 248   Y: 126", 270)
	status_row.add_child(status_document)
	status_row.add_child(status_info)
	status_row.add_child(status_coordinates)


func _render_all() -> void:
	_render_module_rail()
	_render_submodules()
	_render_toolbar()
	_render_actions()
	_render_outliner()
	_render_workspace()
	_render_inspector()
	_render_status()


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


func _render_submodules() -> void:
	_clear(submodule_list)
	var module: Dictionary = _active_module()
	for submodule in module.submodules:
		var button := _button(submodule, submodule == active_submodule)
		button.custom_minimum_size = Vector2(0, 30)
		button.pressed.connect(_activate_submodule.bind(submodule))
		submodule_list.add_child(button)


func _render_toolbar() -> void:
	_clear(toolbar_tools)
	var module: Dictionary = _active_module()
	toolbar_context.text = "%s / %s" % [module.label, active_submodule]
	for tool_name in module.tools:
		var button := _button(tool_name, tool_name == active_tool)
		button.pressed.connect(_activate_tool.bind(tool_name))
		toolbar_tools.add_child(button)


func _render_actions() -> void:
	_clear(action_controls)
	action_context.text = "%s settings" % active_tool
	var module: Dictionary = _active_module()
	for action_name in module.actions:
		var button := _button(action_name, false)
		button.pressed.connect(_set_status.bind("%s is a placeholder action." % action_name))
		action_controls.add_child(button)


func _render_outliner() -> void:
	_clear(outliner_list)
	var entries := _outline_entries()
	var entries_by_id := {}
	for entry in entries:
		entries_by_id[entry.id] = entry
	for entry in entries:
		if not _is_outline_entry_visible(entry, entries_by_id):
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 28)
		row.add_theme_constant_override("separation", 3)
		var depth := int(entry.get("depth", 0))
		if depth > 0:
			var indent := Control.new()
			indent.custom_minimum_size = Vector2(depth * 12, 0)
			row.add_child(indent)
			var marker := Label.new()
			marker.text = "·"
			marker.add_theme_color_override("font_color", MUTED)
			marker.custom_minimum_size = Vector2(10, 0)
			row.add_child(marker)
		var has_children: bool = entry.has("children") and not entry.children.is_empty()
		var row_text: String = str(entry.label)
		if has_children:
			row_text = ("▾  " if expanded_outline.get(entry.id, true) else "▸  ") + row_text
		var button := _button(row_text, selected_outline_item == entry.id and not has_children)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if has_children:
			button.tooltip_text = "Toggle child entries"
			button.pressed.connect(_toggle_outline_parent.bind(entry.id))
		else:
			button.pressed.connect(_select_outline_item.bind(entry.id))
		row.add_child(button)
		outliner_list.add_child(row)


func _render_workspace() -> void:
	_clear(workspace_content)
	var module: Dictionary = _active_module()
	var heading := _label(module.title.replace(module.submodules[0], active_submodule), TEXT, 22)
	workspace_content.add_child(heading)
	var description := _label(module.description, MUTED, 14)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workspace_content.add_child(description)
	var preview := _panel(PANEL)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_content.add_child(preview)
	var preview_margin := _margin(preview, 26, 24)
	var preview_stack := VBoxContainer.new()
	preview_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_stack.add_theme_constant_override("separation", 12)
	preview_margin.add_child(preview_stack)
	_match_workspace_preview(preview_stack)
	if _shows_time_area():
		workspace_content.add_child(_time_area())


func _match_workspace_preview(container: VBoxContainer) -> void:
	match active_module_id:
		"create":
			container.add_child(_preview_label("POLYLINE PLACEHOLDER", ACCENT))
			container.add_child(_preview_label("Wizard Hat  •  8 points", TEXT))
			container.add_child(_preview_label("Select Polyline to begin a future edit.", MUTED))
		"style":
			container.add_child(_preview_label("STYLE PREVIEW", ACCENT))
			container.add_child(_preview_label("Warm amber / cool violet", TEXT))
			container.add_child(_preview_label("Color and masks are visual placeholders.", MUTED))
		"motion":
			container.add_child(_preview_label("MOTION PREVIEW", ACCENT))
			container.add_child(_preview_label("Wizard Hat  ↝  Sway", TEXT))
			container.add_child(_preview_label("Local asset motion, not a global sequence.", MUTED))
		"transform":
			var pair := HBoxContainer.new()
			pair.alignment = BoxContainer.ALIGNMENT_CENTER
			pair.add_theme_constant_override("separation", 22)
			pair.add_child(_preview_label("Wizard Hat", TEXT))
			pair.add_child(_preview_label("→", ACCENT))
			pair.add_child(_preview_label("Star", TEXT))
			container.add_child(pair)
			container.add_child(_preview_label("Independent assets linked by a designed morph.", MUTED))
		"effects":
			container.add_child(_preview_label("EFFECT PREVIEW", ACCENT))
			container.add_child(_preview_label("%s placeholder" % active_submodule, TEXT))
			container.add_child(_preview_label("Choose Root Growth to reveal a local growth control.", MUTED))
		"export":
			container.add_child(_preview_label("OUTPUT PREVIEW", ACCENT))
			container.add_child(_preview_label("1024 × 1024  •  PNG", TEXT))
			container.add_child(_preview_label("No files are exported by this skeleton.", MUTED))


func _render_inspector() -> void:
	_clear(inspector_content)
	inspector_content.add_child(_label(_selected_outline_label(), TEXT, 18))
	inspector_content.add_child(_label("Placeholder properties", MUTED, 13))
	inspector_content.add_child(HSeparator.new())
	for property in _inspector_properties():
		var row := _panel(PANEL_ALT)
		row.custom_minimum_size = Vector2(0, 38)
		inspector_content.add_child(row)
		var margin := _margin(row, 9, 6)
		var columns := HBoxContainer.new()
		margin.add_child(columns)
		var name := _label(property[0], MUTED, 13)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(name)
		columns.add_child(_label(property[1], TEXT, 13))


func _render_status() -> void:
	status_document.text = "Document  •  %s" % _selected_outline_label()
	status_info.text = "%s  •  %s / %s" % [status_message, _active_module().label, active_submodule]
	status_coordinates.text = "Zoom 100%%   X: 248   Y: 126"


func _activate_module(module_id: String) -> void:
	active_module_id = module_id
	var module: Dictionary = _active_module()
	active_submodule = module.submodules[0]
	active_tool = module.tools[0]
	status_message = "%s workspace selected" % module.label
	_render_all()


func _activate_submodule(submodule: String) -> void:
	active_submodule = submodule
	status_message = "%s selected" % submodule
	_render_all()


func _activate_tool(tool_name: String) -> void:
	active_tool = tool_name
	status_message = "%s tool active" % tool_name
	_render_all()


func _toggle_outline_parent(parent_id: String) -> void:
	expanded_outline[parent_id] = not expanded_outline.get(parent_id, true)
	status_message = "%s children %s" % [parent_id.capitalize(), "shown" if expanded_outline[parent_id] else "hidden"]
	_render_outliner()
	_render_status()


func _select_outline_item(item_id: String) -> void:
	selected_outline_item = item_id
	status_message = "%s selected" % _selected_outline_label()
	_render_outliner()
	_render_inspector()
	_render_status()


func _set_status(message: String) -> void:
	status_message = message
	_render_status()


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


func _selected_outline_label() -> String:
	for entry in _outline_entries():
		if entry.id == selected_outline_item:
			return entry.label
	return "No selection"


func _inspector_properties() -> Array:
	var module_label: String = _active_module().label
	return [
		["Context", "%s / %s" % [module_label, active_submodule]],
		["Selection", _selected_outline_label()],
		["State", "Dummy"],
		["Visible", "Yes"],
		["Notes", "No persistent data yet"],
	]


func _shows_time_area() -> bool:
	return active_module_id == "motion" or active_module_id == "transform" or (active_module_id == "effects" and active_submodule == "Root Growth")


func _time_area() -> PanelContainer:
	var panel := _panel(PANEL_ALT)
	panel.custom_minimum_size = Vector2(0, 150)
	var margin := _margin(panel, 14, 10)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	var title := "Asset Time / Wizard Hat Sway"
	if active_module_id == "transform":
		title = "Transition Time / Hat → Star"
	if active_module_id == "effects":
		title = "Effect Time / Root Growth"
	stack.add_child(_label(title, TEXT, 14))
	for track in _timeline_tracks():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		stack.add_child(row)
		var label := _label(track, MUTED, 13)
		label.custom_minimum_size = Vector2(130, 0)
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.value = 42.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.tooltip_text = "Dummy timeline track"
		row.add_child(slider)
		row.add_child(_label("◇", ACCENT, 16))
	return panel


func _timeline_tracks() -> Array:
	if active_module_id == "transform":
		return ["Morph Progress", "Sway Out", "Jitter In"]
	if active_module_id == "effects":
		return ["Growth Progress", "Branch Fade"]
	return ["Sway Strength", "Rotation", "Offset"]


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
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_stylebox_override("normal", _style(ACCENT_SOFT if active else PANEL, ACCENT if active else BORDER, 6))
	button.add_theme_stylebox_override("hover", _style(PANEL_HOVER, ACCENT if active else BORDER, 6))
	button.add_theme_stylebox_override("pressed", _style(ACCENT_SOFT, ACCENT, 6))
	return button


func _style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style


func _label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _section_heading(text: String) -> Label:
	var label := _label(text, MUTED, 11)
	label.add_theme_constant_override("outline_size", 0)
	return label


func _preview_label(text: String, color: Color) -> Label:
	var label := _label(text, color, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _status_cell(text: String, minimum_width: int) -> Label:
	var label := _label(text, MUTED, 12)
	label.custom_minimum_size = Vector2(minimum_width, 0)
	label.add_theme_stylebox_override("normal", _style(PANEL_ALT, BORDER, 0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
