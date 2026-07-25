extends Control

const CREATE_SUBMODULES := ["Shapes", "Layers"]
const INACTIVE_MODULES := ["Style", "Motion", "Transform", "Effects", "Export"]

var active_create_submodule := "Shapes"
var outliner_list: VBoxContainer
var inspector_content: VBoxContainer
var module_sections: Array[ModuleSection] = []
var assets: Array[Dictionary] = []
var selected_asset_id := ""
var selected_component_id := ""
var expanded_assets: Dictionary = {}
var next_asset_id := 1
var next_component_id := 1
var asset_dialog: ConfirmationDialog
var asset_name_input: LineEdit
var component_dialog: ConfirmationDialog
var component_name_input: LineEdit
var asset_name_editor: LineEdit
var component_name_editor: LineEdit
var canvas_context_label: Label
var canvas_view: ComponentCanvas
var context_bar: HBoxContainer
var info_bar: HBoxContainer
var active_draw_tool := ""
var active_state := ""
var active_edit_mode := "select"


func _ready() -> void:
	_build_ui()
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if selected_component_id.is_empty():
		return
	var has_command_modifier: bool = event.meta_pressed or event.ctrl_pressed
	if has_command_modifier and event.keycode == KEY_1:
		_activate_draw_state()
	elif has_command_modifier and event.keycode == KEY_2:
		_activate_edit_state()
	elif not has_command_modifier and active_state == "draw" and event.keycode == KEY_1:
		_activate_draw_line()
	elif not has_command_modifier and active_state == "edit":
		if event.keycode == KEY_1:
			_set_edit_mode("select")
		elif event.keycode == KEY_2:
			_set_edit_mode("add")
		elif event.keycode == KEY_3:
			_set_edit_mode("move")
		elif event.keycode == KEY_4:
			_set_edit_mode("delete")


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#181a1f")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 1)
	root_margin.add_theme_constant_override("margin_top", 1)
	root_margin.add_theme_constant_override("margin_right", 1)
	root_margin.add_theme_constant_override("margin_bottom", 1)
	add_child(root_margin)

	var main_layout := VBoxContainer.new()
	main_layout.add_theme_constant_override("separation", 1)
	root_margin.add_child(main_layout)

	var toolbar_panel := _create_panel()
	main_layout.add_child(toolbar_panel)
	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size = Vector2(0, 32)
	toolbar_panel.add_child(toolbar)
	var new_menu := MenuButton.new()
	new_menu.text = "New  ▼"
	new_menu.custom_minimum_size = Vector2(72, 32)
	new_menu.focus_mode = Control.FOCUS_NONE
	var new_popup := new_menu.get_popup()
	new_popup.add_item("Asset")
	new_popup.add_item("Texture")
	new_popup.id_pressed.connect(_on_new_menu_id)
	toolbar.add_child(new_menu)

	var workspace_row := HBoxContainer.new()
	workspace_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_row.add_theme_constant_override("separation", 1)
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
	workspace_split.add_theme_constant_override("separation", 1)
	workspace_split.add_theme_constant_override("minimum_grab_thickness", 1)
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
	canvas_split.add_theme_constant_override("separation", 1)
	canvas_split.add_theme_constant_override("minimum_grab_thickness", 1)
	canvas_split.split_offset = 820
	workspace_split.add_child(canvas_split)

	var canvas_column := VBoxContainer.new()
	canvas_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_column.add_theme_constant_override("separation", 1)
	canvas_split.add_child(canvas_column)

	var action_bar_panel := _create_panel()
	canvas_column.add_child(action_bar_panel)
	context_bar = HBoxContainer.new()
	context_bar.custom_minimum_size = Vector2(0, 32)
	action_bar_panel.add_child(context_bar)

	var canvas_panel := _create_panel(Color("#1b1e24"))
	canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_column.add_child(canvas_panel)
	canvas_view = ComponentCanvas.new()
	canvas_view.line_completed.connect(_on_line_completed)
	canvas_view.outer_shape_changed.connect(_on_outer_shape_changed)
	canvas_view.reference_component_selected.connect(_on_reference_component_selected)
	var canvas := canvas_view
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_panel.add_child(canvas)
	canvas_context_label = Label.new()
	canvas_context_label.position = Vector2(8, 6)
	canvas_context_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_context_label.add_theme_font_size_override("font_size", 11)
	canvas_context_label.add_theme_color_override("font_color", Color("#9aa3b2"))
	canvas.add_child(canvas_context_label)

	var inspector_panel := _create_panel()
	inspector_panel.custom_minimum_size = Vector2(260, 0)
	canvas_split.add_child(inspector_panel)
	inspector_content = VBoxContainer.new()
	inspector_content.add_theme_constant_override("separation", 4)
	inspector_panel.add_child(inspector_content)

	var status_bar := _create_panel()
	status_bar.custom_minimum_size = Vector2(0, 24)
	main_layout.add_child(status_bar)
	info_bar = HBoxContainer.new()
	info_bar.add_theme_constant_override("separation", 16)
	status_bar.add_child(info_bar)

	_create_asset_dialog()
	_create_component_dialog()


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


func _create_asset_dialog() -> void:
	asset_dialog = ConfirmationDialog.new()
	asset_dialog.title = "New Asset"
	asset_dialog.dialog_text = "Enter an asset name"
	asset_dialog.size = Vector2i(360, 160)
	asset_dialog.confirmed.connect(_confirm_asset_creation)
	asset_name_input = LineEdit.new()
	asset_name_input.placeholder_text = "Asset name"
	asset_name_input.custom_minimum_size = Vector2(320, 32)
	asset_name_input.focus_mode = Control.FOCUS_ALL
	asset_name_input.text_submitted.connect(_submit_asset_name)
	asset_dialog.add_child(asset_name_input)
	add_child(asset_dialog)


func _create_component_dialog() -> void:
	component_dialog = ConfirmationDialog.new()
	component_dialog.title = "Add Component"
	component_dialog.dialog_text = "Enter a component name"
	component_dialog.size = Vector2i(360, 160)
	component_dialog.confirmed.connect(_confirm_component_creation)
	component_name_input = LineEdit.new()
	component_name_input.placeholder_text = "Component name"
	component_name_input.custom_minimum_size = Vector2(320, 32)
	component_name_input.focus_mode = Control.FOCUS_ALL
	component_name_input.text_submitted.connect(_submit_component_name)
	component_dialog.add_child(component_name_input)
	add_child(component_dialog)


func _on_new_menu_id(id: int) -> void:
	if id == 0:
		_open_new_asset_dialog()


func _render_context_bar() -> void:
	if not is_instance_valid(context_bar):
		return
	_clear(context_bar)
	if selected_component_id.is_empty():
		active_draw_tool = ""
		_render_info_bar()
		return
	var draw_menu := MenuButton.new()
	draw_menu.text = "⌘1  Draw  ▼"
	draw_menu.custom_minimum_size = Vector2(88, 32)
	draw_menu.focus_mode = Control.FOCUS_NONE
	draw_menu.toggle_mode = true
	draw_menu.button_pressed = active_state == "draw"
	draw_menu.pressed.connect(_activate_draw_state)
	var draw_popup := draw_menu.get_popup()
	draw_popup.add_item("1: Line", 0)
	draw_popup.id_pressed.connect(_on_draw_menu_id)
	context_bar.add_child(draw_menu)
	var edit_menu := MenuButton.new()
	edit_menu.text = "⌘2  Edit  ▼"
	edit_menu.custom_minimum_size = Vector2(88, 32)
	edit_menu.focus_mode = Control.FOCUS_NONE
	edit_menu.toggle_mode = true
	edit_menu.button_pressed = active_state == "edit"
	edit_menu.pressed.connect(_activate_edit_state)
	var edit_popup := edit_menu.get_popup()
	edit_popup.add_item("1: Select", 0)
	edit_popup.add_item("2: Add", 1)
	edit_popup.add_item("3: Move", 2)
	edit_popup.add_item("4: Delete", 3)
	edit_popup.id_pressed.connect(_on_edit_menu_id)
	context_bar.add_child(edit_menu)


func _on_draw_menu_id(id: int) -> void:
	if id == 0:
		_activate_draw_line()


func _on_edit_menu_id(id: int) -> void:
	_activate_edit_state()
	if id == 1:
		_set_edit_mode("add")
	elif id == 2:
		_set_edit_mode("move")
	elif id == 3:
		_set_edit_mode("delete")


func _activate_draw_state() -> void:
	_set_active_state("draw")


func _activate_draw_line() -> void:
	active_draw_tool = "line"
	canvas_view.set_interaction_state("draw")
	canvas_view.set_tool_mode(active_draw_tool)
	_render_info_bar()


func _set_edit_mode(mode: String) -> void:
	active_edit_mode = mode
	canvas_view.set_edit_mode(active_edit_mode)
	_render_info_bar()


func _activate_edit_state() -> void:
	_set_active_state("edit")


func _set_active_state(state: String) -> void:
	if selected_component_id.is_empty():
		return
	active_state = state
	if state == "draw":
		active_draw_tool = "line"
		active_edit_mode = "select"
		canvas_view.set_interaction_state("draw")
		canvas_view.set_tool_mode(active_draw_tool)
	else:
		active_draw_tool = ""
		active_edit_mode = "select"
		canvas_view.set_interaction_state("edit")
		canvas_view.set_edit_mode(active_edit_mode)
		canvas_view.set_tool_mode("")
	_render_context_bar()
	_render_info_bar()


func _render_info_bar() -> void:
	if not is_instance_valid(info_bar):
		return
	_clear(info_bar)
	if selected_component_id.is_empty():
		return
	var state_label := Label.new()
	state_label.text = "State: %s" % ("Draw" if active_state == "draw" else "Edit" if active_state == "edit" else "—")
	info_bar.add_child(state_label)
	if active_state == "draw":
		_add_info_option("1: Line")
	elif active_state == "edit":
		_add_info_option("1: Select")
		_add_info_option("2: Add")
		_add_info_option("3: Move")
		_add_info_option("4: Delete")
	else:
		_add_info_option("⌘1: Draw")
		_add_info_option("⌘2: Edit")


func _add_info_option(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#aab3c2"))
	info_bar.add_child(label)


func _open_new_asset_dialog() -> void:
	asset_name_input.text = ""
	asset_dialog.popup_centered()
	asset_name_input.grab_focus()


func _submit_asset_name(_submitted_text: String) -> void:
	_confirm_asset_creation()


func _confirm_asset_creation() -> void:
	var asset_name := asset_name_input.text.strip_edges()
	if asset_name.is_empty():
		asset_name = _next_default_asset_name()
	var asset_id := "asset_%d" % next_asset_id
	next_asset_id += 1
	assets.append({"id": asset_id, "name": asset_name, "components": []})
	selected_asset_id = asset_id
	selected_component_id = ""
	active_state = ""
	expanded_assets[asset_id] = true
	asset_dialog.hide()
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _next_default_asset_name() -> String:
	var index := 1
	while _has_asset_name("asset%02d" % index):
		index += 1
	return "asset%02d" % index


func _has_asset_name(asset_name: String) -> bool:
	for asset in assets:
		if str(asset["name"]).to_lower() == asset_name.to_lower():
			return true
	return false


func _render_outliner() -> void:
	_clear(outliner_list)
	for asset in assets:
		var asset_id := str(asset["id"])
		var asset_container := VBoxContainer.new()
		asset_container.add_theme_constant_override("separation", 0)
		outliner_list.add_child(asset_container)
		var asset_header := HBoxContainer.new()
		asset_header.add_theme_constant_override("separation", 2)
		asset_container.add_child(asset_header)
		var asset_button := Button.new()
		asset_button.text = str(asset["name"])
		asset_button.custom_minimum_size = Vector2(0, 30)
		asset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		asset_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		asset_button.focus_mode = Control.FOCUS_NONE
		_style_outliner_button(asset_button, asset_id == selected_asset_id and selected_component_id.is_empty())
		asset_button.pressed.connect(_select_asset.bind(asset_id))
		asset_header.add_child(asset_button)
		var add_button := Button.new()
		add_button.text = "Add"
		add_button.custom_minimum_size = Vector2(48, 30)
		add_button.focus_mode = Control.FOCUS_NONE
		add_button.pressed.connect(_open_component_dialog.bind(asset_id))
		asset_header.add_child(add_button)
		if not bool(expanded_assets.get(asset_id, false)):
			continue
		for component in asset["components"]:
			var component_id := str(component["id"])
			var component_row := HBoxContainer.new()
			component_row.add_theme_constant_override("separation", 0)
			asset_container.add_child(component_row)
			var child_placeholder := Control.new()
			child_placeholder.custom_minimum_size = Vector2(16, 0)
			component_row.add_child(child_placeholder)
			var component_button := Button.new()
			component_button.text = str(component["name"])
			component_button.custom_minimum_size = Vector2(0, 30)
			component_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			component_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			component_button.focus_mode = Control.FOCUS_NONE
			_style_outliner_button(component_button, component_id == selected_component_id)
			component_button.pressed.connect(_select_component.bind(asset_id, component_id))
			component_row.add_child(component_button)


func _select_asset(asset_id: String) -> void:
	var was_selected := selected_asset_id == asset_id and selected_component_id.is_empty()
	selected_asset_id = asset_id
	selected_component_id = ""
	active_state = ""
	canvas_view.set_interaction_state("")
	if was_selected:
		expanded_assets[asset_id] = not bool(expanded_assets.get(asset_id, false))
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _open_component_dialog(asset_id: String) -> void:
	selected_asset_id = asset_id
	selected_component_id = ""
	component_name_input.text = ""
	component_dialog.set_meta("asset_id", asset_id)
	component_dialog.popup_centered()
	component_name_input.grab_focus()


func _submit_component_name(_submitted_text: String) -> void:
	_confirm_component_creation()


func _confirm_component_creation() -> void:
	var asset_id := str(component_dialog.get_meta("asset_id", ""))
	var asset := _get_asset(asset_id)
	if asset.is_empty():
		component_dialog.hide()
		return
	var component_name := component_name_input.text.strip_edges()
	if component_name.is_empty():
		component_name = _next_default_component_name(asset)
	var component_id := "component_%d" % next_component_id
	next_component_id += 1
	asset["components"].append({"id": component_id, "name": component_name, "outer_shape": []})
	selected_asset_id = asset_id
	selected_component_id = component_id
	active_state = ""
	expanded_assets[asset_id] = true
	component_dialog.hide()
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _next_default_component_name(asset: Dictionary) -> String:
	var index := 1
	while _has_component_name(asset, "component%02d" % index):
		index += 1
	return "component%02d" % index


func _has_component_name(asset: Dictionary, component_name: String) -> bool:
	for component in asset["components"]:
		if str(component["name"]).to_lower() == component_name.to_lower():
			return true
	return false


func _select_component(asset_id: String, component_id: String) -> void:
	selected_asset_id = asset_id
	selected_component_id = component_id
	active_state = ""
	canvas_view.set_interaction_state("")
	expanded_assets[asset_id] = true
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _style_outliner_button(button: Button, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#f2c94c") if selected else Color("#252a33")
	normal.border_color = Color("#f2c94c") if selected else Color("#303744")
	normal.set_border_width_all(1)
	var hover := normal.duplicate()
	hover.bg_color = Color("#ffe083") if selected else Color("#303744")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("#e7b936") if selected else Color("#394252")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	var text_color := Color("#16181d") if selected else Color("#d7dce5")
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", Color("#16181d") if selected else Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#16181d"))
	button.add_theme_color_override("font_focus_color", text_color)


func _render_inspector() -> void:
	_clear(inspector_content)
	inspector_content.add_child(_create_panel_label("Inspector"))
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty():
		return
	if selected_component_id.is_empty():
		inspector_content.add_child(_create_panel_label("Name"))
		asset_name_editor = _create_name_editor(str(asset["name"]), "Asset name")
		asset_name_editor.text_submitted.connect(_rename_selected_asset)
		asset_name_editor.focus_exited.connect(func() -> void:
			_rename_selected_asset(asset_name_editor.text)
		)
		inspector_content.add_child(asset_name_editor)
		return
	var component := _get_component(asset, selected_component_id)
	if component.is_empty():
		return
	inspector_content.add_child(_create_panel_label("Name"))
	component_name_editor = _create_name_editor(str(component["name"]), "Component name")
	component_name_editor.text_submitted.connect(_rename_selected_component)
	component_name_editor.focus_exited.connect(func() -> void:
		_rename_selected_component(component_name_editor.text)
	)
	inspector_content.add_child(component_name_editor)


func _create_name_editor(value: String, placeholder: String) -> LineEdit:
	var editor := LineEdit.new()
	editor.text = value
	editor.custom_minimum_size = Vector2(0, 30)
	editor.placeholder_text = placeholder
	return editor


func _rename_selected_asset(new_name: String) -> void:
	var asset_name := new_name.strip_edges()
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty():
		return
	if asset_name.is_empty():
		asset_name_editor.text = str(asset["name"])
		return
	asset["name"] = asset_name
	_render_outliner()
	_render_canvas_context()


func _rename_selected_component(new_name: String) -> void:
	var component_name := new_name.strip_edges()
	var asset := _get_asset(selected_asset_id)
	var component := _get_component(asset, selected_component_id)
	if component.is_empty():
		return
	if component_name.is_empty():
		component_name_editor.text = str(component["name"])
		return
	component["name"] = component_name
	_render_outliner()
	_render_canvas_context()


func _render_canvas_context() -> void:
	_render_context_bar()
	_render_info_bar()
	if not is_instance_valid(canvas_context_label):
		return
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty():
		canvas_context_label.text = ""
		canvas_view.set_context("")
		canvas_view.set_interaction_state("")
		canvas_view.set_reference_shapes([])
		canvas_view.set_outer_shape([])
		return
	if selected_component_id.is_empty():
		canvas_context_label.text = "Asset: %s" % str(asset["name"])
		canvas_view.set_context(str(asset["name"]))
		canvas_view.set_interaction_state("asset")
		canvas_view.set_reference_shapes(_build_reference_shapes(asset))
		canvas_view.set_outer_shape([])
		return
	var component := _get_component(asset, selected_component_id)
	if component.is_empty():
		canvas_context_label.text = "Asset: %s" % str(asset["name"])
		canvas_view.set_context(str(asset["name"]))
		canvas_view.set_interaction_state("asset")
		canvas_view.set_reference_shapes(_build_reference_shapes(asset))
		canvas_view.set_outer_shape([])
		return
	canvas_context_label.text = "Component: %s" % str(component["name"])
	canvas_view.set_context(str(component["name"]))
	canvas_view.set_interaction_state(active_state)
	canvas_view.set_reference_shapes(_build_reference_shapes(asset, selected_component_id))
	canvas_view.set_outer_shape(component["outer_shape"])


func _build_reference_shapes(asset: Dictionary, excluded_component_id := "") -> Array:
	var shapes: Array = []
	for component in asset["components"]:
		if str(component["id"]) == excluded_component_id:
			continue
		shapes.append({
			"id": str(component["id"]),
			"points": component["outer_shape"].duplicate()
		})
	return shapes


func _on_line_completed(points: Array[Vector2]) -> void:
	var asset := _get_asset(selected_asset_id)
	var component := _get_component(asset, selected_component_id)
	if component.is_empty():
		return
	component["outer_shape"] = points
	canvas_view.set_outer_shape(points)


func _on_outer_shape_changed(points: Array[Vector2]) -> void:
	var asset := _get_asset(selected_asset_id)
	var component := _get_component(asset, selected_component_id)
	if component.is_empty():
		return
	component["outer_shape"] = points.duplicate()


func _on_reference_component_selected(component_id: String) -> void:
	if selected_asset_id.is_empty():
		return
	var component := _get_component(_get_asset(selected_asset_id), component_id)
	if component.is_empty():
		return
	_select_component(selected_asset_id, component_id)


func _on_point_selection_changed(_index: int) -> void:
	pass


func _get_asset(asset_id: String) -> Dictionary:
	for asset in assets:
		if str(asset["id"]) == asset_id:
			return asset
	return {}


func _get_component(asset: Dictionary, component_id: String) -> Dictionary:
	if asset.is_empty():
		return {}
	for component in asset["components"]:
		if str(component["id"]) == component_id:
			return component
	return {}


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _add_module_section(parent: Container, module_name: String, submodules: Array, open_by_default := false) -> void:
	var section := ModuleSection.new()
	section.setup(module_name, submodules, open_by_default)
	section.module_pressed.connect(_on_category_pressed)
	section.submodule_pressed.connect(_select_submodule.bind(section))
	module_sections.append(section)
	parent.add_child(section)


func _on_category_pressed(_module_name: String) -> void:
	var pressed_section := _find_section(_module_name)
	for section in module_sections:
		section.set_expanded(section == pressed_section and section.expanded)


func _find_section(module_name: String) -> ModuleSection:
	for section in module_sections:
		if section.module_name == module_name:
			return section
	return null


func _select_submodule(module_name: String, submodule: String, section: ModuleSection) -> void:
	section.set_active_submodule(submodule)
	if module_name == "Create":
		active_create_submodule = submodule
