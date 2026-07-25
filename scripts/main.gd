extends Control

const CREATE_SUBMODULES := ["Shapes", "Layers"]
const INACTIVE_MODULES := ["Style", "Motion", "Transform", "Effects", "Export"]
const WORKSPACES_ROOT := "res://workspaces"
const CONFIG_PATH := "res://configs/app_config.json"
const SCHEMA_VERSION := 2

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
var program_status_label: Label
var status_clear_timer: Timer
var active_draw_tool := ""
var active_state := ""
var active_edit_mode := "select"
var snap_enabled := true
var snap_grid_step := 16.0
var snap_rotation_step := 15.0
var snap_button: Button
var snap_popup: PopupPanel
var snap_toggle: CheckButton
var snap_grid_slider: HSlider
var snap_rotation_slider: HSlider
var snap_grid_value_label: Label
var snap_rotation_value_label: Label
var workspace_name := ""
var workspace_name_dialog: ConfirmationDialog
var workspace_name_input: LineEdit
var load_workspace_dialog: ConfirmationDialog
var workspace_list: ItemList
var pending_save_after_new := false


func _ready() -> void:
	_build_ui()
	_render_outliner()
	_render_inspector()
	_render_canvas_context()
	_load_last_workspace()


func _load_last_workspace() -> void:
	var config_data = _read_json(CONFIG_PATH)
	if _has_supported_schema(config_data):
		var last_workspace := str(config_data.get("last_workspace", ""))
		if not last_workspace.is_empty():
			_load_workspace(last_workspace)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var has_command_modifier: bool = event.meta_pressed or event.ctrl_pressed
	if has_command_modifier and event.keycode == KEY_S:
		_save_workspace()
		get_viewport().set_input_as_handled()
		return
	if selected_component_id.is_empty():
		return
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
	var toolbar_spacer := Control.new()
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(toolbar_spacer)
	var workspace_menu := MenuButton.new()
	workspace_menu.text = "Workspace  ▼"
	workspace_menu.custom_minimum_size = Vector2(132, 32)
	workspace_menu.focus_mode = Control.FOCUS_NONE
	var workspace_popup := workspace_menu.get_popup()
	workspace_popup.add_item("New")
	workspace_popup.add_item("Save")
	workspace_popup.add_item("Load")
	workspace_popup.id_pressed.connect(_on_workspace_menu_id)
	toolbar.add_child(workspace_menu)

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
	_create_snap_popup()

	var canvas_panel := _create_panel(Color("#1b1e24"))
	canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_column.add_child(canvas_panel)
	canvas_view = ComponentCanvas.new()
	canvas_view.line_completed.connect(_on_line_completed)
	canvas_view.outer_shape_changed.connect(_on_outer_shape_changed)
	canvas_view.reference_component_selected.connect(_on_reference_component_selected)
	canvas_view.pivot_changed.connect(_on_pivot_changed)
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
	var status_layout := HBoxContainer.new()
	status_layout.add_theme_constant_override("separation", 1)
	status_bar.add_child(status_layout)
	var status_left := _create_status_region()
	status_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_left.size_flags_stretch_ratio = 17.0
	status_layout.add_child(status_left)
	program_status_label = Label.new()
	program_status_label.visible = false
	program_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	program_status_label.add_theme_font_size_override("font_size", 11)
	program_status_label.add_theme_color_override("font_color", Color("#f2c94c"))
	status_left.add_child(program_status_label)
	var status_middle := _create_status_region()
	status_middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_middle.size_flags_stretch_ratio = 64.0
	status_layout.add_child(status_middle)
	info_bar = HBoxContainer.new()
	info_bar.add_theme_constant_override("separation", 16)
	status_middle.add_child(info_bar)
	var status_right := _create_status_region()
	status_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_right.size_flags_stretch_ratio = 17.0
	status_layout.add_child(status_right)
	status_clear_timer = Timer.new()
	status_clear_timer.one_shot = true
	status_clear_timer.wait_time = 2.5
	status_clear_timer.timeout.connect(_clear_status_message)
	add_child(status_clear_timer)

	_create_asset_dialog()
	_create_component_dialog()
	_create_workspace_dialogs()


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


func _create_status_region() -> PanelContainer:
	var region := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#20242c")
	style.border_color = Color("#363d48")
	style.set_border_width_all(1)
	region.add_theme_stylebox_override("panel", style)
	return region


func _create_snap_popup() -> void:
	snap_popup = PopupPanel.new()
	snap_popup.size = Vector2i(250, 170)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	snap_popup.add_child(content)
	var title := Label.new()
	title.text = "Snap Settings"
	content.add_child(title)
	snap_toggle = CheckButton.new()
	snap_toggle.text = "Snap On"
	snap_toggle.button_pressed = snap_enabled
	snap_toggle.toggled.connect(_on_snap_enabled_toggled)
	content.add_child(snap_toggle)
	snap_grid_value_label = Label.new()
	content.add_child(snap_grid_value_label)
	snap_grid_slider = _create_snap_slider(1.0, 64.0, 1.0, snap_grid_step)
	snap_grid_slider.value_changed.connect(_on_snap_grid_changed)
	content.add_child(snap_grid_slider)
	snap_rotation_value_label = Label.new()
	content.add_child(snap_rotation_value_label)
	snap_rotation_slider = _create_snap_slider(1.0, 90.0, 1.0, snap_rotation_step)
	snap_rotation_slider.value_changed.connect(_on_snap_rotation_changed)
	content.add_child(snap_rotation_slider)
	_update_snap_popup_labels()
	add_child(snap_popup)


func _create_snap_slider(minimum: float, maximum: float, step: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(220, 20)
	return slider


func _toggle_snap_popup() -> void:
	if snap_popup.visible:
		snap_popup.hide()
		return
	var popup_position := snap_button.get_global_rect().position + Vector2(0.0, snap_button.size.y + 2.0)
	snap_popup.popup(Rect2(popup_position, snap_popup.size))


func _on_snap_enabled_toggled(enabled: bool) -> void:
	snap_enabled = enabled
	canvas_view.set_snap_settings(snap_enabled, snap_grid_step, snap_rotation_step)
	_update_snap_popup_labels()


func _on_snap_grid_changed(value: float) -> void:
	snap_grid_step = value
	canvas_view.set_snap_settings(snap_enabled, snap_grid_step, snap_rotation_step)
	_update_snap_popup_labels()


func _on_snap_rotation_changed(value: float) -> void:
	snap_rotation_step = value
	canvas_view.set_snap_settings(snap_enabled, snap_grid_step, snap_rotation_step)
	_update_snap_popup_labels()


func _update_snap_popup_labels() -> void:
	if is_instance_valid(snap_toggle):
		snap_toggle.button_pressed = snap_enabled
	if is_instance_valid(snap_grid_slider):
		snap_grid_slider.value = snap_grid_step
	if is_instance_valid(snap_rotation_slider):
		snap_rotation_slider.value = snap_rotation_step
	if is_instance_valid(snap_grid_value_label):
		snap_grid_value_label.text = "Grid Step: %d px" % int(snap_grid_step)
	if is_instance_valid(snap_rotation_value_label):
		snap_rotation_value_label.text = "Rotation Step: %d°" % int(snap_rotation_step)


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


func _create_workspace_dialogs() -> void:
	workspace_name_dialog = ConfirmationDialog.new()
	workspace_name_dialog.title = "New Workspace"
	workspace_name_dialog.dialog_text = "Enter a workspace name"
	workspace_name_dialog.ok_button_text = "Create"
	workspace_name_dialog.size = Vector2i(360, 160)
	workspace_name_dialog.confirmed.connect(_confirm_new_workspace)
	workspace_name_input = LineEdit.new()
	workspace_name_input.placeholder_text = "Workspace name"
	workspace_name_input.custom_minimum_size = Vector2(320, 32)
	workspace_name_input.focus_mode = Control.FOCUS_ALL
	workspace_name_input.text_submitted.connect(_submit_workspace_name)
	workspace_name_dialog.add_child(workspace_name_input)
	add_child(workspace_name_dialog)

	load_workspace_dialog = ConfirmationDialog.new()
	load_workspace_dialog.title = "Load Workspace"
	load_workspace_dialog.dialog_text = ""
	load_workspace_dialog.ok_button_text = "Load"
	load_workspace_dialog.size = Vector2i(420, 320)
	load_workspace_dialog.confirmed.connect(_load_selected_workspace)
	workspace_list = ItemList.new()
	workspace_list.custom_minimum_size = Vector2(380, 220)
	workspace_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_list.item_activated.connect(_load_selected_workspace)
	load_workspace_dialog.add_child(workspace_list)
	add_child(load_workspace_dialog)


func _on_new_menu_id(id: int) -> void:
	if id == 0:
		_open_new_asset_dialog()


func _on_workspace_menu_id(id: int) -> void:
	if id == 0:
		_open_new_workspace_dialog(false)
	elif id == 1:
		_save_workspace()
	elif id == 2:
		_open_load_workspace_dialog()


func _open_new_workspace_dialog(save_after_creation: bool) -> void:
	pending_save_after_new = save_after_creation
	workspace_name_input.text = ""
	workspace_name_dialog.dialog_text = "Enter a workspace name"
	workspace_name_dialog.popup_centered()
	workspace_name_input.grab_focus()


func _submit_workspace_name(_submitted_text: String) -> void:
	_confirm_new_workspace()


func _confirm_new_workspace() -> void:
	var should_save := pending_save_after_new
	var new_name := workspace_name_input.text.strip_edges()
	if new_name.is_empty():
		new_name = _next_default_workspace_name()
	new_name = _sanitize_workspace_name(new_name)
	workspace_name = new_name
	assets.clear()
	selected_asset_id = ""
	selected_component_id = ""
	expanded_assets.clear()
	next_asset_id = 1
	next_component_id = 1
	active_state = ""
	_apply_snap_settings({})
	pending_save_after_new = false
	workspace_name_dialog.hide()
	_render_outliner()
	_render_inspector()
	_render_canvas_context()
	if should_save:
		_save_workspace()


func _open_load_workspace_dialog() -> void:
	workspace_list.clear()
	var names := _list_workspace_names()
	for workspace_entry in names:
		workspace_list.add_item(workspace_entry)
		workspace_list.set_item_metadata(workspace_list.item_count - 1, workspace_entry)
	if workspace_list.item_count > 0:
		workspace_list.select(0)
	load_workspace_dialog.popup_centered()
	workspace_list.grab_focus()


func _load_selected_workspace(_index := -1) -> void:
	var selected_indices := workspace_list.get_selected_items()
	if selected_indices.is_empty():
		return
	var index := selected_indices[0]
	var workspace_entry := str(workspace_list.get_item_metadata(index))
	if _load_workspace(workspace_entry):
		load_workspace_dialog.hide()


func _list_workspace_names() -> Array[String]:
	var names: Array[String] = []
	var directory := DirAccess.open(WORKSPACES_ROOT)
	if directory == null:
		return names
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if directory.current_is_dir() and not entry.begins_with(".") and FileAccess.file_exists("%s/%s/workspace.json" % [WORKSPACES_ROOT, entry]):
			names.append(entry)
		entry = directory.get_next()
	directory.list_dir_end()
	names.sort()
	return names


func _next_default_workspace_name() -> String:
	var existing := _list_workspace_names()
	var index := 1
	while existing.has("workspace%02d" % index):
		index += 1
	return "workspace%02d" % index


func _sanitize_workspace_name(value: String) -> String:
	var sanitized := value.strip_edges()
	for character in ["/", "\\", ":"]:
		sanitized = sanitized.replace(character, "_")
	if sanitized == "." or sanitized == ".." or sanitized.is_empty():
		return _next_default_workspace_name()
	return sanitized


func _save_workspace() -> void:
	if workspace_name.is_empty():
		_open_new_workspace_dialog(true)
		return
	var workspace_root := "%s/%s" % [WORKSPACES_ROOT, workspace_name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/assets" % workspace_root))
	var asset_ids: Array[String] = []
	for asset in assets:
		var asset_id := str(asset["id"])
		asset_ids.append(asset_id)
		var asset_root := "%s/assets/%s" % [workspace_root, asset_id]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(asset_root))
		var asset_data := {
			"schema_version": SCHEMA_VERSION,
			"id": asset_id,
			"name": str(asset["name"]),
			"components": []
		}
		for component in asset["components"]:
			asset_data["components"].append({
				"id": str(component["id"]),
				"name": str(component["name"]),
				"outer_shape": _serialize_points(component["outer_shape"]),
				"transform": _serialize_transform(component.get("transform", {})),
				"visibility": bool(component.get("visibility", true)),
				"z_index": int(component.get("z_index", 0))
			})
		_write_json("%s/asset.json" % asset_root, asset_data)
	_write_json("%s/workspace.json" % workspace_root, {
		"schema_version": SCHEMA_VERSION,
		"name": workspace_name,
		"assets": asset_ids,
		"editor_state": _serialize_editor_state()
	})
	_write_json(CONFIG_PATH, {"schema_version": SCHEMA_VERSION, "last_workspace": workspace_name})
	_show_status_message("Saved Workspace: %s!" % workspace_name)


func _show_status_message(message: String) -> void:
	if not is_instance_valid(program_status_label):
		return
	program_status_label.text = message
	program_status_label.visible = true
	program_status_label.modulate = Color.WHITE
	status_clear_timer.start()
	var tween := create_tween()
	tween.tween_property(program_status_label, "modulate", Color("#f2c94c"), 0.15)


func _clear_status_message() -> void:
	if is_instance_valid(program_status_label):
		program_status_label.visible = false
		program_status_label.text = ""


func _load_workspace(workspace_entry: String) -> bool:
	var workspace_root := "%s/%s" % [WORKSPACES_ROOT, workspace_entry]
	var workspace_data = _read_json("%s/workspace.json" % workspace_root)
	if not _has_supported_schema(workspace_data):
		return false
	var loaded_assets: Array[Dictionary] = []
	for asset_id_variant in workspace_data.get("assets", []):
		var asset_id := str(asset_id_variant)
		var asset_data = _read_json("%s/assets/%s/asset.json" % [workspace_root, asset_id])
		if not _has_supported_schema(asset_data):
			continue
		var components: Array[Dictionary] = []
		for component_data in asset_data.get("components", []):
			if not component_data is Dictionary:
				continue
			components.append({
				"id": str(component_data.get("id", "")),
				"name": str(component_data.get("name", "Component")),
				"outer_shape": _deserialize_points(component_data.get("outer_shape", [])),
				"transform": _deserialize_transform(component_data.get("transform", {})),
				"visibility": bool(component_data.get("visibility", true)),
				"z_index": int(component_data.get("z_index", 0))
			})
		loaded_assets.append({
			"id": str(asset_data.get("id", asset_id)),
			"name": str(asset_data.get("name", asset_id)),
			"components": components
		})
	assets = loaded_assets
	workspace_name = str(workspace_data.get("name", workspace_entry))
	_restore_editor_state(workspace_data.get("editor_state", {}))
	_update_next_ids()
	active_state = ""
	_render_outliner()
	_render_inspector()
	_render_canvas_context()
	_write_json(CONFIG_PATH, {"schema_version": SCHEMA_VERSION, "last_workspace": workspace_name})
	return true


func _serialize_editor_state() -> Dictionary:
	var expanded_state := {}
	for asset in assets:
		var asset_id := str(asset["id"])
		expanded_state[asset_id] = bool(expanded_assets.get(asset_id, false))
	return {
		"selected_asset_id": selected_asset_id,
		"selected_component_id": selected_component_id,
		"expanded_assets": expanded_state,
		"snap": {
			"enabled": snap_enabled,
			"grid_step": snap_grid_step,
			"rotation_step": snap_rotation_step
		}
	}


func _restore_editor_state(state) -> void:
	selected_asset_id = ""
	selected_component_id = ""
	expanded_assets.clear()
	for asset in assets:
		expanded_assets[str(asset["id"])] = false
	if not state is Dictionary:
		_apply_snap_settings({})
		return
	var requested_asset_id := str(state.get("selected_asset_id", ""))
	var selected_asset := _get_asset(requested_asset_id)
	if not selected_asset.is_empty():
		selected_asset_id = requested_asset_id
		var requested_component_id := str(state.get("selected_component_id", ""))
		if not _get_component(selected_asset, requested_component_id).is_empty():
			selected_component_id = requested_component_id
	var saved_expanded = state.get("expanded_assets", {})
	if saved_expanded is Dictionary:
		for asset in assets:
			var asset_id := str(asset["id"])
			if saved_expanded.has(asset_id):
				expanded_assets[asset_id] = bool(saved_expanded[asset_id])
	if not selected_component_id.is_empty():
		expanded_assets[selected_asset_id] = true
	_apply_snap_settings(state.get("snap", {}))


func _apply_snap_settings(settings) -> void:
	if settings is Dictionary:
		snap_enabled = bool(settings.get("enabled", true))
		snap_grid_step = clampf(float(settings.get("grid_step", 16.0)), 1.0, 64.0)
		snap_rotation_step = clampf(float(settings.get("rotation_step", 15.0)), 1.0, 90.0)
	else:
		snap_enabled = true
		snap_grid_step = 16.0
		snap_rotation_step = 15.0
	if is_instance_valid(canvas_view):
		canvas_view.set_snap_settings(snap_enabled, snap_grid_step, snap_rotation_step)
	_update_snap_popup_labels()


func _serialize_points(points: Array) -> Array:
	var serialized: Array = []
	for point in points:
		serialized.append([point.x, point.y])
	return serialized


func _default_component_transform() -> Dictionary:
	return {
		"position": Vector2.ZERO,
		"rotation": 0.0,
		"scale": Vector2.ONE,
		"pivot": Vector2.ZERO
	}


func _serialize_transform(transform: Dictionary) -> Dictionary:
	var normalized := _deserialize_transform(transform)
	return {
		"position": _serialize_vector(normalized["position"]),
		"rotation": float(normalized["rotation"]),
		"scale": _serialize_vector(normalized["scale"]),
		"pivot": _serialize_vector(normalized["pivot"])
	}


func _deserialize_transform(transform) -> Dictionary:
	var result := _default_component_transform()
	if not transform is Dictionary:
		return result
	result["position"] = _deserialize_vector(transform.get("position", [0.0, 0.0]), Vector2.ZERO)
	result["rotation"] = float(transform.get("rotation", 0.0))
	result["scale"] = _deserialize_vector(transform.get("scale", [1.0, 1.0]), Vector2.ONE)
	result["pivot"] = _deserialize_vector(transform.get("pivot", [0.0, 0.0]), Vector2.ZERO)
	return result


func _serialize_vector(value: Vector2) -> Array:
	return [value.x, value.y]


func _deserialize_vector(value, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


func _deserialize_points(points: Array) -> Array[Vector2]:
	var deserialized: Array[Vector2] = []
	for point in points:
		if point is Array and point.size() >= 2:
			deserialized.append(Vector2(float(point[0]), float(point[1])))
	return deserialized


func _write_json(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _has_supported_schema(data) -> bool:
	if not data is Dictionary:
		return false
	var version := int(data.get("schema_version", data.get("format_version", 0)))
	return version > 0 and version <= SCHEMA_VERSION


func _update_next_ids() -> void:
	next_asset_id = 1
	next_component_id = 1
	for asset in assets:
		next_asset_id = maxi(next_asset_id, _id_suffix_number(str(asset["id"])) + 1)
		for component in asset["components"]:
			next_component_id = maxi(next_component_id, _id_suffix_number(str(component["id"])) + 1)


func _id_suffix_number(identifier: String) -> int:
	var suffix := identifier.get_slice("_", identifier.get_slice_count("_") - 1)
	return suffix.to_int()


func _render_context_bar() -> void:
	if not is_instance_valid(context_bar):
		return
	_clear(context_bar)
	snap_button = Button.new()
	snap_button.text = "Snap: %s  ▼" % ("On" if snap_enabled else "Off")
	snap_button.custom_minimum_size = Vector2(112, 32)
	snap_button.focus_mode = Control.FOCUS_NONE
	snap_button.pressed.connect(_toggle_snap_popup)
	context_bar.add_child(snap_button)
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
	asset["components"].append({
		"id": component_id,
		"name": component_name,
		"outer_shape": [],
		"transform": _default_component_transform(),
		"visibility": true,
		"z_index": 0
	})
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
	inspector_content.add_child(_create_panel_label("Transform"))
	var transform_grid := GridContainer.new()
	transform_grid.columns = 2
	transform_grid.add_theme_constant_override("h_separation", 8)
	transform_grid.add_theme_constant_override("v_separation", 4)
	inspector_content.add_child(transform_grid)
	var transform: Dictionary = component.get("transform", _default_component_transform())
	var position: Vector2 = transform.get("position", Vector2.ZERO)
	var scale: Vector2 = transform.get("scale", Vector2.ONE)
	var pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
	_add_transform_field(transform_grid, "Position X", position.x, "position_x", 1.0)
	_add_transform_field(transform_grid, "Position Y", position.y, "position_y", 1.0)
	_add_transform_field(transform_grid, "Rotation", float(transform.get("rotation", 0.0)), "rotation", 1.0)
	_add_transform_field(transform_grid, "Scale X", scale.x, "scale_x", 0.01)
	_add_transform_field(transform_grid, "Scale Y", scale.y, "scale_y", 0.01)
	_add_transform_field(transform_grid, "Pivot X", pivot.x, "pivot_x", 1.0)
	_add_transform_field(transform_grid, "Pivot Y", pivot.y, "pivot_y", 1.0)
	inspector_content.add_child(_create_panel_label("Visibility / Layer"))
	var visibility := CheckButton.new()
	visibility.text = "Visible"
	visibility.button_pressed = bool(component.get("visibility", true))
	visibility.toggled.connect(_on_component_visibility_changed)
	inspector_content.add_child(visibility)
	var z_index_label := _create_panel_label("Z Index")
	inspector_content.add_child(z_index_label)
	var z_index := SpinBox.new()
	z_index.min_value = -10000
	z_index.max_value = 10000
	z_index.step = 1
	z_index.value = int(component.get("z_index", 0))
	z_index.custom_minimum_size = Vector2(0, 30)
	z_index.value_changed.connect(_on_component_z_index_changed)
	inspector_content.add_child(z_index)


func _create_name_editor(value: String, placeholder: String) -> LineEdit:
	var editor := LineEdit.new()
	editor.text = value
	editor.custom_minimum_size = Vector2(0, 30)
	editor.placeholder_text = placeholder
	return editor


func _add_transform_field(grid: GridContainer, label_text: String, value: float, property_name: String, step: float) -> void:
	var label := Label.new()
	label.text = label_text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(label)
	var field := SpinBox.new()
	field.min_value = -100000.0
	field.max_value = 100000.0
	field.step = step
	field.value = value
	field.custom_minimum_size = Vector2(96, 28)
	field.value_changed.connect(_on_transform_value_changed.bind(property_name))
	grid.add_child(field)


func _on_transform_value_changed(value: float, property_name: String) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		return
	var transform: Dictionary = component.get("transform", _default_component_transform())
	var position: Vector2 = transform.get("position", Vector2.ZERO)
	var scale: Vector2 = transform.get("scale", Vector2.ONE)
	var pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
	match property_name:
		"position_x": position.x = value
		"position_y": position.y = value
		"rotation": transform["rotation"] = value
		"scale_x": scale.x = value
		"scale_y": scale.y = value
		"pivot_x": pivot.x = value
		"pivot_y": pivot.y = value
	transform["position"] = position
	transform["scale"] = scale
	transform["pivot"] = pivot
	component["transform"] = transform


func _on_component_visibility_changed(visible: bool) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not component.is_empty():
		component["visibility"] = visible


func _on_component_z_index_changed(value: float) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not component.is_empty():
		component["z_index"] = int(value)


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
		canvas_view.set_tool_mode("")
		canvas_view.set_component_transform({})
		canvas_view.set_reference_shapes([])
		canvas_view.set_outer_shape([])
		return
	if selected_component_id.is_empty():
		canvas_context_label.text = "Asset: %s" % str(asset["name"])
		canvas_view.set_context(str(asset["name"]))
		canvas_view.set_interaction_state("asset")
		canvas_view.set_tool_mode("")
		canvas_view.set_component_transform({})
		canvas_view.set_reference_shapes(_build_reference_shapes(asset))
		canvas_view.set_outer_shape([])
		return
	var component := _get_component(asset, selected_component_id)
	if component.is_empty():
		canvas_context_label.text = "Asset: %s" % str(asset["name"])
		canvas_view.set_context(str(asset["name"]))
		canvas_view.set_interaction_state("asset")
		canvas_view.set_tool_mode("")
		canvas_view.set_component_transform({})
		canvas_view.set_reference_shapes(_build_reference_shapes(asset))
		canvas_view.set_outer_shape([])
		return
	canvas_context_label.text = "Component: %s" % str(component["name"])
	canvas_view.set_context(str(component["name"]))
	canvas_view.set_interaction_state(active_state)
	canvas_view.set_component_transform(component.get("transform", _default_component_transform()))
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


func _on_pivot_changed(pivot: Vector2) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		return
	var transform: Dictionary = component.get("transform", _default_component_transform())
	transform["pivot"] = pivot
	component["transform"] = transform


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
