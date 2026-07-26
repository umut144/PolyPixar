extends Control

const CREATE_SUBMODULES := ["Shapes", "Layers"]
const INACTIVE_MODULES := ["Style", "Motion", "Transform", "Effects", "Export"]
const WORKSPACES_ROOT := "res://workspaces"
const IMPORT_TEXTURES_ROOT := "res://imports/textures"
const CONFIG_PATH := "res://configs/app_config.json"
const SCHEMA_VERSION := 8
const MAX_HISTORY_SIZE := 100
# Kept available for a later Outliner presentation, but processed outputs are
# currently reached through the Import Preview instead of additional rows.
const SHOW_PROCESSED_OUTLINER := false

var active_create_submodule := "Shapes"
var outliner_list: VBoxContainer
var outliner_search_input: LineEdit
var outliner_filter_option: OptionButton
var outliner_filter := "all"
var inspector_content: VBoxContainer
var module_sections: Array[ModuleSection] = []
var assets: Array[Dictionary] = []
var textures: Array[Dictionary] = []
var materials: Array[Dictionary] = []
var selected_asset_id := ""
var selected_component_id := ""
var selected_texture_id := ""
var selected_element_id := ""
var expanded_assets: Dictionary = {}
var expanded_textures: Dictionary = {}
var next_asset_id := 1
var next_component_id := 1
var next_texture_id := 1
var next_material_id := 1
var asset_dialog: ConfirmationDialog
var asset_name_input: LineEdit
var component_dialog: ConfirmationDialog
var component_name_input: LineEdit
var texture_dialog: ConfirmationDialog
var texture_name_input: LineEdit
var texture_import_dialog: FileDialog
var element_dialog: ConfirmationDialog
var element_name_input: LineEdit
var asset_name_editor: LineEdit
var component_name_editor: LineEdit
var transform_fields: Dictionary = {}
var canvas_context_label: Label
var canvas_view: ComponentCanvas
var texture_canvas: TextureCanvas
var import_preview: ImportPreview
var texture_context_label: Label
var import_preview_context_label: Label
var context_bar: HBoxContainer
var info_bar: HBoxContainer
var program_status_label: Label
var status_clear_timer: Timer
var active_draw_tool := ""
var active_state := ""
var active_import_preview_mode := "original"
var pending_import_threshold := 0.05
var import_threshold_field: SpinBox
var active_edit_mode := "select"
var active_transform_mode := "transform"
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
var undo_history: Array[Dictionary] = []
var redo_history: Array[Dictionary] = []
var history_coalesce_timer: Timer
var history_coalescing := false


func _ready() -> void:
	_build_ui()
	history_coalesce_timer = Timer.new()
	history_coalesce_timer.one_shot = true
	history_coalesce_timer.wait_time = 0.25
	history_coalesce_timer.timeout.connect(_finish_history_coalescing)
	add_child(history_coalesce_timer)
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
	if has_command_modifier and event.keycode == KEY_Z:
		if event.shift_pressed:
			_redo()
		else:
			_undo()
		get_viewport().set_input_as_handled()
		return
	if selected_component_id.is_empty():
		if not selected_texture_id.is_empty() and not selected_element_id.is_empty():
			var selected_texture := _get_texture(selected_texture_id)
			var selected_element := _get_element(selected_texture, selected_element_id)
			if not selected_element.is_empty() and str(selected_element.get("type", "generator")) == "import":
				if has_command_modifier and event.keycode == KEY_1:
					_render_context_bar()
					get_viewport().set_input_as_handled()
					return
				if not has_command_modifier and event.keycode == KEY_1:
					_set_import_preview_mode("original")
					get_viewport().set_input_as_handled()
					return
				if not has_command_modifier and event.keycode == KEY_2:
					_set_import_preview_mode("white_to_alpha")
					get_viewport().set_input_as_handled()
					return
		return
	if not has_command_modifier and event.keycode == KEY_BACKSPACE and active_state.is_empty():
		_delete_selected_component()
		get_viewport().set_input_as_handled()
		return
	if has_command_modifier and event.keycode == KEY_1:
		_activate_draw_state()
	elif has_command_modifier and event.keycode == KEY_2:
		_activate_edit_state()
	elif has_command_modifier and event.keycode == KEY_3:
		_activate_transform_state()
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
	elif not has_command_modifier and active_state == "transform":
		if event.keycode == KEY_1:
			_set_transform_mode("transform")
		elif event.keycode == KEY_2:
			_set_transform_mode("rotate")
		elif event.keycode == KEY_3:
			_set_transform_mode("scale")


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
	var outliner_tools := HBoxContainer.new()
	outliner_tools.add_theme_constant_override("separation", 2)
	outliner_content.add_child(outliner_tools)
	outliner_search_input = LineEdit.new()
	outliner_search_input.placeholder_text = "Search"
	outliner_search_input.custom_minimum_size = Vector2(0, 26)
	outliner_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outliner_search_input.text_changed.connect(func(_text: String) -> void: _render_outliner())
	outliner_tools.add_child(outliner_search_input)
	outliner_filter_option = OptionButton.new()
	outliner_filter_option.custom_minimum_size = Vector2(72, 26)
	outliner_filter_option.add_item("All", 0)
	outliner_filter_option.add_item("Assets", 1)
	outliner_filter_option.add_item("Textures", 2)
	outliner_filter_option.item_selected.connect(_on_outliner_filter_selected)
	outliner_tools.add_child(outliner_filter_option)
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
	canvas_view.line_shape_changed.connect(_on_line_shape_changed)
	canvas_view.outer_shape_changed.connect(_on_outer_shape_changed)
	canvas_view.reference_component_selected.connect(_on_reference_component_selected)
	canvas_view.pivot_changed.connect(_on_pivot_changed)
	canvas_view.transform_changed.connect(_on_transform_changed)
	var canvas := canvas_view
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_panel.add_child(canvas)
	texture_canvas = TextureCanvas.new()
	texture_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texture_canvas.visible = false
	texture_canvas.origin_changed.connect(_on_texture_origin_changed)
	canvas_panel.add_child(texture_canvas)
	import_preview = ImportPreview.new()
	import_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	import_preview.visible = false
	canvas_panel.add_child(import_preview)
	import_preview_context_label = Label.new()
	import_preview_context_label.position = Vector2(8, 6)
	import_preview_context_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	import_preview_context_label.add_theme_font_size_override("font_size", 11)
	import_preview_context_label.add_theme_color_override("font_color", Color("#9aa3b2"))
	import_preview.add_child(import_preview_context_label)
	texture_context_label = Label.new()
	texture_context_label.position = Vector2(8, 6)
	texture_context_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_context_label.add_theme_font_size_override("font_size", 11)
	texture_context_label.add_theme_color_override("font_color", Color("#9aa3b2"))
	texture_canvas.add_child(texture_context_label)
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
	inspector_content.add_theme_constant_override("separation", 2)
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
	_create_texture_dialog()
	_create_texture_import_dialog()
	_create_element_dialog()
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


func _create_inspector_section(text: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 0)
	var separator := HSeparator.new()
	separator.modulate = Color("#3a424f")
	section.add_child(separator)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(0, 20)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#c0c8d5"))
	section.add_child(label)
	return section


func _create_inspector_field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(0, 18)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#7f8a9b"))
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


func _create_texture_dialog() -> void:
	texture_dialog = ConfirmationDialog.new()
	texture_dialog.title = "New Texture"
	texture_dialog.dialog_text = "Enter a texture name"
	texture_dialog.size = Vector2i(360, 160)
	texture_dialog.confirmed.connect(_confirm_texture_creation)
	texture_name_input = LineEdit.new()
	texture_name_input.placeholder_text = "Texture name"
	texture_name_input.custom_minimum_size = Vector2(320, 32)
	texture_name_input.focus_mode = Control.FOCUS_ALL
	texture_name_input.text_submitted.connect(_submit_texture_name)
	texture_dialog.add_child(texture_name_input)
	add_child(texture_dialog)


func _create_texture_import_dialog() -> void:
	texture_import_dialog = FileDialog.new()
	texture_import_dialog.title = "Import Texture"
	texture_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	texture_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	texture_import_dialog.use_native_dialog = true
	texture_import_dialog.filters = PackedStringArray([
		"*.png, *.jpg, *.jpeg, *.webp ; Image files"
	])
	texture_import_dialog.current_dir = ProjectSettings.globalize_path(IMPORT_TEXTURES_ROOT)
	texture_import_dialog.file_selected.connect(_on_texture_import_file_selected)
	add_child(texture_import_dialog)


func _create_element_dialog() -> void:
	element_dialog = ConfirmationDialog.new()
	element_dialog.title = "Add Element"
	element_dialog.dialog_text = "Enter an element name"
	element_dialog.size = Vector2i(360, 160)
	element_dialog.confirmed.connect(_confirm_element_creation)
	element_name_input = LineEdit.new()
	element_name_input.placeholder_text = "Element name"
	element_name_input.custom_minimum_size = Vector2(320, 32)
	element_name_input.focus_mode = Control.FOCUS_ALL
	element_name_input.text_submitted.connect(_submit_element_name)
	element_dialog.add_child(element_name_input)
	add_child(element_dialog)


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
	elif id == 1:
		_open_new_texture_dialog()


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
	textures.clear()
	materials.clear()
	selected_asset_id = ""
	selected_component_id = ""
	expanded_assets.clear()
	next_asset_id = 1
	next_component_id = 1
	next_texture_id = 1
	next_material_id = 1
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/textures" % workspace_root))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/materials" % workspace_root))
	var asset_ids: Array[String] = []
	var texture_ids: Array[String] = []
	var material_ids: Array[String] = []
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
				"closed": bool(component.get("closed", component["outer_shape"].size() >= 3)),
				"transform": _serialize_transform(component.get("transform", {})),
				"visibility": bool(component.get("visibility", true)),
				"z_index": int(component.get("z_index", 0))
			})
		_write_json("%s/asset.json" % asset_root, asset_data)
	for texture in textures:
		var texture_id := str(texture["id"])
		texture_ids.append(texture_id)
		var texture_root := "%s/textures/%s" % [workspace_root, texture_id]
		_write_json("%s/texture.json" % texture_root, {
			"schema_version": SCHEMA_VERSION,
			"id": texture_id,
			"name": str(texture["name"]),
			"canvas": {
				"width": int(texture.get("canvas_width", 512)),
				"height": int(texture.get("canvas_height", 512))
			},
			"origin_mode": str(texture.get("origin_mode", "bottom_left")),
			"final_output_element_id": str(texture.get("final_output_element_id", "")),
			"elements": texture.get("elements", []).duplicate(true)
		})
	for material in materials:
		var material_id := str(material["id"])
		material_ids.append(material_id)
		var material_root := "%s/materials/%s" % [workspace_root, material_id]
		_write_json("%s/material.json" % material_root, {
			"schema_version": SCHEMA_VERSION,
			"id": material_id,
			"name": str(material.get("name", material_id)),
			"texture_id": str(material.get("texture_id", "")),
			"tint": _serialize_color(material.get("tint", Color.WHITE)),
			"opacity": clampf(float(material.get("opacity", 1.0)), 0.0, 1.0)
		})
	_write_json("%s/workspace.json" % workspace_root, {
		"schema_version": SCHEMA_VERSION,
		"name": workspace_name,
		"assets": asset_ids,
		"textures": texture_ids,
		"materials": material_ids,
		"editor_state": _serialize_editor_state()
	})
	_write_json(CONFIG_PATH, {"schema_version": SCHEMA_VERSION, "last_workspace": workspace_name})
	_show_status_message("Saved Workspace: %s!" % workspace_name)


func _capture_history_snapshot() -> Dictionary:
	return {
		"assets": assets.duplicate(true),
		"next_asset_id": next_asset_id,
		"next_component_id": next_component_id,
		"textures": textures.duplicate(true),
		"next_texture_id": next_texture_id,
		"materials": materials.duplicate(true),
		"next_material_id": next_material_id,
		"selected_asset_id": selected_asset_id,
		"selected_component_id": selected_component_id,
		"selected_texture_id": selected_texture_id,
		"selected_element_id": selected_element_id,
		"expanded_assets": expanded_assets.duplicate(true)
	}


func _push_undo_snapshot() -> void:
	undo_history.append(_capture_history_snapshot())
	if undo_history.size() > MAX_HISTORY_SIZE:
		undo_history.pop_front()
	redo_history.clear()


func _record_direct_change() -> void:
	history_coalescing = false
	history_coalesce_timer.stop()
	_push_undo_snapshot()


func _record_coalesced_change() -> void:
	if not history_coalescing:
		_push_undo_snapshot()
		history_coalescing = true
	history_coalesce_timer.start()


func _finish_history_coalescing() -> void:
	history_coalescing = false


func _restore_history_snapshot(snapshot: Dictionary) -> void:
	assets = snapshot.get("assets", []).duplicate(true)
	textures = snapshot.get("textures", []).duplicate(true)
	materials = snapshot.get("materials", []).duplicate(true)
	next_asset_id = int(snapshot.get("next_asset_id", 1))
	next_component_id = int(snapshot.get("next_component_id", 1))
	next_texture_id = int(snapshot.get("next_texture_id", 1))
	next_material_id = int(snapshot.get("next_material_id", 1))
	selected_asset_id = str(snapshot.get("selected_asset_id", ""))
	selected_component_id = str(snapshot.get("selected_component_id", ""))
	selected_texture_id = str(snapshot.get("selected_texture_id", ""))
	selected_element_id = str(snapshot.get("selected_element_id", ""))
	expanded_assets = snapshot.get("expanded_assets", {}).duplicate(true)
	if _get_asset(selected_asset_id).is_empty():
		selected_asset_id = ""
		selected_component_id = ""
	elif not selected_component_id.is_empty() and _get_component(_get_asset(selected_asset_id), selected_component_id).is_empty():
		selected_component_id = ""
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _undo() -> void:
	if undo_history.is_empty():
		return
	history_coalescing = false
	history_coalesce_timer.stop()
	redo_history.append(_capture_history_snapshot())
	var snapshot: Dictionary = undo_history.pop_back()
	_restore_history_snapshot(snapshot)


func _redo() -> void:
	if redo_history.is_empty():
		return
	history_coalescing = false
	history_coalesce_timer.stop()
	undo_history.append(_capture_history_snapshot())
	var snapshot: Dictionary = redo_history.pop_back()
	_restore_history_snapshot(snapshot)


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
	var loaded_textures: Array[Dictionary] = []
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
				"closed": bool(component_data.get("closed", component_data.get("outer_shape", []).size() >= 3)),
				"transform": _deserialize_transform(component_data.get("transform", {})),
				"visibility": bool(component_data.get("visibility", true)),
				"z_index": int(component_data.get("z_index", 0))
			})
		loaded_assets.append({
			"id": str(asset_data.get("id", asset_id)),
			"name": str(asset_data.get("name", asset_id)),
			"components": components
		})
	for texture_id_variant in workspace_data.get("textures", []):
		var texture_id := str(texture_id_variant)
		var texture_data = _read_json("%s/textures/%s/texture.json" % [workspace_root, texture_id])
		if not _has_supported_schema(texture_data):
			continue
		var canvas_data = texture_data.get("canvas", {})
		var legacy_import_source = texture_data.get("import_source", {})
		var normalized_elements := _normalize_texture_elements(texture_data.get("elements", []), legacy_import_source)
		loaded_textures.append({
			"id": str(texture_data.get("id", texture_id)),
			"name": str(texture_data.get("name", texture_id)),
			"canvas_width": int(canvas_data.get("width", 512)) if canvas_data is Dictionary else 512,
			"canvas_height": int(canvas_data.get("height", 512)) if canvas_data is Dictionary else 512,
			"origin_mode": str(texture_data.get("origin_mode", "bottom_left")),
			"elements": normalized_elements,
			"final_output_element_id": _normalize_final_output_element_id(normalized_elements, str(texture_data.get("final_output_element_id", "")))
		})
	var loaded_materials: Array[Dictionary] = []
	for material_id_variant in workspace_data.get("materials", []):
		var material_id := str(material_id_variant)
		var material_data = _read_json("%s/materials/%s/material.json" % [workspace_root, material_id])
		if not _has_supported_schema(material_data):
			continue
		loaded_materials.append(_normalize_material(material_data, material_id))
	assets = loaded_assets
	textures = loaded_textures
	materials = loaded_materials
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
		"selected_texture_id": selected_texture_id,
		"selected_element_id": selected_element_id,
		"expanded_assets": expanded_state,
		"expanded_textures": expanded_textures.duplicate(true),
		"snap": {
			"enabled": snap_enabled,
			"grid_step": snap_grid_step,
			"rotation_step": snap_rotation_step
		}
	}


func _restore_editor_state(state) -> void:
	selected_asset_id = ""
	selected_component_id = ""
	selected_texture_id = ""
	selected_element_id = ""
	expanded_assets.clear()
	expanded_textures.clear()
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
	var requested_texture_id := str(state.get("selected_texture_id", ""))
	var selected_texture := _get_texture(requested_texture_id)
	if not selected_texture.is_empty() and selected_asset_id.is_empty():
		selected_texture_id = requested_texture_id
		var requested_element_id := str(state.get("selected_element_id", ""))
		if not _get_element(selected_texture, requested_element_id).is_empty():
			selected_element_id = requested_element_id
		else:
			selected_element_id = ""
		expanded_textures[selected_texture_id] = true
	var saved_expanded_textures = state.get("expanded_textures", {})
	if saved_expanded_textures is Dictionary:
		for texture in textures:
			var texture_id := str(texture["id"])
			if saved_expanded_textures.has(texture_id):
				expanded_textures[texture_id] = bool(saved_expanded_textures[texture_id])
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


func _serialize_color(value) -> Array:
	var color := Color.WHITE
	if value is Color:
		color = value
	return [color.r, color.g, color.b, color.a]


func _deserialize_color(value, fallback: Color) -> Color:
	if value is Array and value.size() >= 3:
		return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]) if value.size() >= 4 else 1.0)
	return fallback


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
	next_texture_id = 1
	for asset in assets:
		next_asset_id = maxi(next_asset_id, _id_suffix_number(str(asset["id"])) + 1)
		for component in asset["components"]:
			next_component_id = maxi(next_component_id, _id_suffix_number(str(component["id"])) + 1)
	for texture in textures:
		next_texture_id = maxi(next_texture_id, _id_suffix_number(str(texture["id"])) + 1)
	for material in materials:
		next_material_id = maxi(next_material_id, _id_suffix_number(str(material["id"])) + 1)


func _id_suffix_number(identifier: String) -> int:
	var suffix := identifier.get_slice("_", identifier.get_slice_count("_") - 1)
	return suffix.to_int()


func _render_context_bar() -> void:
	if not is_instance_valid(context_bar):
		return
	_clear(context_bar)
	if not selected_texture_id.is_empty():
		_render_texture_context_bar()
		_render_info_bar()
		return
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
	var transform_menu := MenuButton.new()
	transform_menu.text = "⌘3  Transform  ▼"
	transform_menu.custom_minimum_size = Vector2(118, 32)
	transform_menu.focus_mode = Control.FOCUS_NONE
	transform_menu.toggle_mode = true
	transform_menu.button_pressed = active_state == "transform"
	transform_menu.pressed.connect(_activate_transform_state)
	var transform_popup := transform_menu.get_popup()
	transform_popup.add_item("1: Translate", 0)
	transform_popup.add_item("2: Rotate", 1)
	transform_popup.add_item("3: Scale", 2)
	transform_popup.id_pressed.connect(_on_transform_menu_id)
	context_bar.add_child(transform_menu)


func _render_texture_context_bar() -> void:
	var texture := _get_texture(selected_texture_id)
	if texture.is_empty():
		return
	var selected_element := _get_element(texture, selected_element_id)
	if not selected_element.is_empty() and str(selected_element.get("type", "generator")) == "import":
		var preview_menu := MenuButton.new()
		preview_menu.text = "⌘1  Previews  ▼"
		preview_menu.custom_minimum_size = Vector2(132, 32)
		preview_menu.focus_mode = Control.FOCUS_NONE
		var preview_popup := preview_menu.get_popup()
		preview_popup.add_item("1: Original", 0)
		preview_popup.add_item("2: White to Alpha", 1)
		preview_popup.id_pressed.connect(_on_import_preview_menu_id)
		context_bar.add_child(preview_menu)
		return
	var import_button := Button.new()
	import_button.text = "Import Texture"
	import_button.custom_minimum_size = Vector2(116, 32)
	import_button.focus_mode = Control.FOCUS_NONE
	import_button.pressed.connect(_open_texture_import_dialog)
	context_bar.add_child(import_button)
	var origin_menu := MenuButton.new()
	origin_menu.text = "Origin: %s  ▼" % _origin_mode_label(str(texture.get("origin_mode", "bottom_left")))
	origin_menu.custom_minimum_size = Vector2(150, 32)
	origin_menu.focus_mode = Control.FOCUS_NONE
	var origin_popup := origin_menu.get_popup()
	origin_popup.add_item("Bottom Left", 0)
	origin_popup.add_item("Top Left", 1)
	origin_popup.add_item("Center", 2)
	origin_popup.id_pressed.connect(_on_texture_origin_menu_id)
	context_bar.add_child(origin_menu)


func _origin_mode_label(mode: String) -> String:
	return {
		"bottom_left": "Bottom Left",
		"top_left": "Top Left",
		"center": "Center"
	}.get(mode, "Bottom Left")


func _on_texture_origin_menu_id(id: int) -> void:
	var modes := ["bottom_left", "top_left", "center"]
	if id < 0 or id >= modes.size():
		return
	_on_texture_origin_changed(modes[id])


func _on_texture_origin_changed(mode: String) -> void:
	var texture := _get_texture(selected_texture_id)
	if texture.is_empty():
		return
	if texture.get("origin_mode", "bottom_left") == mode:
		return
	_record_direct_change()
	texture["origin_mode"] = mode
	texture_canvas.set_origin_mode(mode)
	_render_context_bar()
	_render_info_bar()


func _on_import_preview_menu_id(id: int) -> void:
	if id == 0:
		_set_import_preview_mode("original")
	elif id == 1:
		_set_import_preview_mode("white_to_alpha")


func _set_import_preview_mode(mode: String) -> void:
	if mode != "original" and mode != "white_to_alpha":
		mode = "original"
	active_import_preview_mode = mode
	_render_context_bar()
	_render_canvas_context()


func _open_texture_import_dialog() -> void:
	if selected_texture_id.is_empty() or _get_texture(selected_texture_id).is_empty():
		return
	if workspace_name.is_empty():
		_show_status_message("Create or load a Workspace before importing.")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(IMPORT_TEXTURES_ROOT))
	texture_import_dialog.current_dir = ProjectSettings.globalize_path(IMPORT_TEXTURES_ROOT)
	texture_import_dialog.popup_centered_ratio(0.75)


func _on_texture_import_file_selected(source_path: String) -> void:
	var texture := _get_texture(selected_texture_id)
	if texture.is_empty() or workspace_name.is_empty():
		return
	var source_extension := source_path.get_extension().to_lower()
	if not ["png", "jpg", "jpeg", "webp"].has(source_extension):
		_show_status_message("Unsupported texture format.")
		return
	var texture_root := "%s/%s/textures/%s" % [WORKSPACES_ROOT, workspace_name, str(texture["id"])]
	var destination_filename := _next_texture_source_filename(texture_root, source_extension)
	var destination_path := "%s/%s" % [texture_root, destination_filename]
	if not _copy_external_file(source_path, destination_path):
		_show_status_message("Texture import failed.")
		return
	_record_direct_change()
	var import_element := _find_import_element(texture)
	if import_element.is_empty():
		var import_name := source_path.get_file().get_basename()
		import_element = {
			"id": "element_%d" % _next_element_id(texture),
			"name": import_name if not import_name.is_empty() else "Import Element",
			"type": "import",
			"source": {},
			"pipeline": {"mode": "white_to_alpha", "threshold": 0.05},
			"output": {"state": "not_ready", "file": ""}
		}
		texture["elements"].append(import_element)
	import_element["type"] = "import"
	import_element["source"] = {
		"file": destination_filename,
		"original_name": source_path.get_file()
	}
	import_element["pipeline"] = {"mode": "white_to_alpha", "threshold": 0.05}
	import_element["output"] = {"state": "not_ready", "file": ""}
	_show_status_message("Imported Texture: %s" % source_path.get_file())
	_render_inspector()
	_render_canvas_context()


func _next_texture_source_filename(texture_root: String, extension: String) -> String:
	var index := 1
	while FileAccess.file_exists("%s/source_%03d.%s" % [texture_root, index, extension]):
		index += 1
	return "source_%03d.%s" % [index, extension]


func _copy_external_file(source_path: String, destination_path: String) -> bool:
	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return false
	var contents := source_file.get_buffer(source_file.get_length())
	source_file.close()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination_path.get_base_dir()))
	var destination_file := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination_file == null:
		return false
	destination_file.store_buffer(contents)
	destination_file.close()
	return true


func _process_selected_import_element() -> void:
	var texture := _get_texture(selected_texture_id)
	var element := _get_element(texture, selected_element_id)
	if texture.is_empty() or element.is_empty() or str(element.get("type", "")) != "import":
		return
	var source_path := _get_texture_source_path(texture, element)
	if source_path.is_empty() or not FileAccess.file_exists(source_path):
		_show_status_message("Import source is missing.")
		return
	var source_image := Image.new()
	if source_image.load(source_path) != OK or source_image.is_empty():
		_show_status_message("Import source could not be read.")
		return
	var pipeline = element.get("pipeline", {})
	if not pipeline is Dictionary:
		pipeline = {}
	var threshold := _read_import_threshold()
	var output_image = _create_white_to_alpha_image(source_image, threshold)
	if output_image == null or output_image.is_empty():
		_show_status_message("Texture processing failed.")
		return
	var texture_root := "%s/%s/textures/%s" % [WORKSPACES_ROOT, workspace_name, str(texture["id"])]
	var output_filename := _next_texture_output_filename(texture_root)
	var output_path := "%s/%s" % [texture_root, output_filename]
	if output_image.save_png(ProjectSettings.globalize_path(output_path)) != OK:
		_show_status_message("Texture processing failed.")
		return
	_record_direct_change()
	element["pipeline"] = {"mode": "white_to_alpha", "threshold": threshold}
	element["output"] = {"state": "ready", "file": output_filename}
	texture["final_output_element_id"] = str(element.get("id", ""))
	_show_status_message("Processed Texture: White to Alpha")
	active_import_preview_mode = "white_to_alpha"
	_render_inspector()
	_render_canvas_context()


func _next_texture_output_filename(texture_root: String) -> String:
	var index := 1
	while FileAccess.file_exists("%s/output_%03d.png" % [texture_root, index]):
		index += 1
	return "output_%03d.png" % index


func _create_white_to_alpha_image(source_image: Image, threshold: float):
	if source_image == null or source_image.is_empty():
		return null
	var output_image := Image.create(source_image.get_width(), source_image.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(source_image.get_height()):
		for x in range(source_image.get_width()):
			var source_color := source_image.get_pixel(x, y)
			var darkness := 1.0 - (source_color.r + source_color.g + source_color.b) / 3.0
			var alpha := clampf((darkness - threshold) / maxf(1.0 - threshold, 0.001), 0.0, 1.0)
			output_image.set_pixel(x, y, Color(source_color.r, source_color.g, source_color.b, alpha))
	return output_image


func _normalize_texture_elements(raw_elements, legacy_import_source) -> Array:
	var normalized: Array = []
	var has_import_element := false
	if raw_elements is Array:
		for element_variant in raw_elements:
			if not element_variant is Dictionary:
				continue
			var element: Dictionary = element_variant.duplicate(true)
			var element_type := str(element.get("type", "generator"))
			if element_type != "import" and element_type != "generator":
				element_type = "generator"
			element["type"] = element_type
			if element_type == "import":
				has_import_element = true
				if not element.get("source", {}) is Dictionary:
					element["source"] = {}
				var pipeline = element.get("pipeline", {})
				if not pipeline is Dictionary:
					pipeline = {}
				pipeline["mode"] = "white_to_alpha"
				pipeline["threshold"] = clampf(float(pipeline.get("threshold", 0.05)), 0.0, 1.0)
				element["pipeline"] = pipeline
			var output = element.get("output", {})
			if not output is Dictionary:
				output = {}
			var output_state := str(output.get("state", "not_ready"))
			if output_state != "ready" or str(output.get("file", "")).get_file().is_empty():
				output_state = "not_ready"
			output["state"] = output_state
			if output_state != "ready":
				output["file"] = ""
			element["output"] = output
			normalized.append(element)
	if legacy_import_source is Dictionary and not legacy_import_source.is_empty() and not has_import_element:
		var original_name := str(legacy_import_source.get("original_name", "Imported Texture"))
		var import_name := original_name.get_basename()
		if import_name.is_empty():
			import_name = "Import Element"
		normalized.append({
			"id": "element_%d" % _next_element_id_from_list(normalized),
			"name": import_name,
			"type": "import",
			"source": legacy_import_source.duplicate(true),
			"pipeline": {"mode": "white_to_alpha", "threshold": 0.05},
			"output": {"state": "not_ready", "file": ""}
		})
	return normalized


func _normalize_material(raw_material, fallback_id: String) -> Dictionary:
	var data: Dictionary = raw_material if raw_material is Dictionary else {}
	return {
		"id": str(data.get("id", fallback_id)),
		"name": str(data.get("name", fallback_id)),
		"texture_id": str(data.get("texture_id", "")),
		"tint": _deserialize_color(data.get("tint", [1.0, 1.0, 1.0, 1.0]), Color.WHITE),
		"opacity": clampf(float(data.get("opacity", 1.0)), 0.0, 1.0)
	}


func _find_import_element(texture: Dictionary) -> Dictionary:
	for element in texture.get("elements", []):
		if str(element.get("type", "generator")) == "import":
			return element
	return {}


func _normalize_final_output_element_id(elements: Array, requested_id: String) -> String:
	for element in elements:
		if str(element.get("id", "")) == requested_id and _element_output_state(element) == "ready":
			return requested_id
	for element in elements:
		if _element_output_state(element) == "ready":
			return str(element.get("id", ""))
	return ""


func _get_texture_final_output_element(texture: Dictionary) -> Dictionary:
	var requested_id := str(texture.get("final_output_element_id", ""))
	var requested_element := _get_element(texture, requested_id)
	if not requested_element.is_empty() and _element_output_state(requested_element) == "ready":
		return requested_element
	for element in texture.get("elements", []):
		if _element_output_state(element) == "ready":
			return element
	return {}


func _get_texture_final_path(texture: Dictionary) -> String:
	if workspace_name.is_empty():
		return ""
	var final_output_element := _get_texture_final_output_element(texture)
	if final_output_element.is_empty():
		return ""
	var output = final_output_element.get("output", {})
	var output_file := str(output.get("file", "")).get_file() if output is Dictionary else ""
	if output_file.is_empty():
		return ""
	return "%s/%s/textures/%s/%s" % [WORKSPACES_ROOT, workspace_name, str(texture.get("id", "")), output_file]


func _get_texture_source_path(texture: Dictionary, element: Dictionary) -> String:
	if workspace_name.is_empty() or texture.is_empty() or element.is_empty():
		return ""
	var source = element.get("source", {})
	if not source is Dictionary:
		return ""
	var source_file := str(source.get("file", "")).get_file()
	if source_file.is_empty():
		return ""
	return "%s/%s/textures/%s/%s" % [WORKSPACES_ROOT, workspace_name, str(texture.get("id", "")), source_file]


func _get_texture_preview_path(texture: Dictionary, element: Dictionary) -> String:
	if element.is_empty():
		return ""
	var output = element.get("output", {})
	if output is Dictionary and str(output.get("state", "not_ready")) == "ready":
		var output_file := str(output.get("file", "")).get_file()
		var output_path := "%s/%s/textures/%s/%s" % [WORKSPACES_ROOT, workspace_name, str(texture.get("id", "")), output_file]
		if not output_file.is_empty() and FileAccess.file_exists(output_path):
			return output_path
	return _get_texture_source_path(texture, element)


func _element_output_state(element: Dictionary) -> String:
	var output = element.get("output", {})
	if output is Dictionary and str(output.get("state", "not_ready")) == "ready" and not str(output.get("file", "")).get_file().is_empty():
		return "ready"
	return "not_ready"


func _texture_output_state(texture: Dictionary) -> String:
	for element in texture.get("elements", []):
		if _element_output_state(element) == "ready":
			return "ready"
	return "not_ready"


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


func _on_transform_menu_id(id: int) -> void:
	_activate_transform_state()
	if id == 1:
		_set_transform_mode("rotate")
	elif id == 2:
		_set_transform_mode("scale")


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


func _activate_transform_state() -> void:
	_set_active_state("transform")


func _set_transform_mode(mode: String) -> void:
	active_transform_mode = mode
	canvas_view.set_transform_mode(active_transform_mode)
	_render_info_bar()


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
		active_transform_mode = "transform"
		canvas_view.set_interaction_state("edit" if state == "edit" else "transform")
		if state == "edit":
			canvas_view.set_edit_mode(active_edit_mode)
		else:
			canvas_view.set_transform_mode(active_transform_mode)
		canvas_view.set_tool_mode("")
	_render_context_bar()
	_render_info_bar()


func _render_info_bar() -> void:
	if not is_instance_valid(info_bar):
		return
	_clear(info_bar)
	if not selected_texture_id.is_empty():
		var texture := _get_texture(selected_texture_id)
		var selected_element := _get_element(texture, selected_element_id)
		if not selected_element.is_empty() and str(selected_element.get("type", "generator")) == "import":
			var state_label := Label.new()
			state_label.text = "State: Preview"
			info_bar.add_child(state_label)
			_add_info_option("1: Original")
			_add_info_option("2: White to Alpha")
		return
	if selected_component_id.is_empty():
		return
	var state_label := Label.new()
	state_label.text = "State: %s" % ("Draw" if active_state == "draw" else "Edit" if active_state == "edit" else "Transform" if active_state == "transform" else "—")
	info_bar.add_child(state_label)
	if active_state == "draw":
		_add_info_option("1: Line")
	elif active_state == "edit":
		_add_info_option("1: Select")
		_add_info_option("2: Add")
		_add_info_option("3: Move")
		_add_info_option("4: Delete")
	elif active_state == "transform":
		_add_info_option("1: Translate")
		_add_info_option("2: Rotate")
		_add_info_option("3: Scale")
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
	_record_direct_change()
	var asset_name := asset_name_input.text.strip_edges()
	if asset_name.is_empty():
		asset_name = _next_default_asset_name()
	var asset_id := "asset_%d" % next_asset_id
	next_asset_id += 1
	assets.append({"id": asset_id, "name": asset_name, "components": []})
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_texture_id = ""
	selected_element_id = ""
	active_state = ""
	expanded_assets[asset_id] = true
	asset_dialog.hide()
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _open_new_texture_dialog() -> void:
	texture_name_input.text = ""
	texture_dialog.popup_centered()
	texture_name_input.grab_focus()


func _submit_texture_name(_submitted_text: String) -> void:
	_confirm_texture_creation()


func _confirm_texture_creation() -> void:
	_record_direct_change()
	var texture_name := texture_name_input.text.strip_edges()
	if texture_name.is_empty():
		texture_name = _next_default_texture_name()
	var texture_id := "texture_%d" % next_texture_id
	next_texture_id += 1
	textures.append({
		"id": texture_id,
		"name": texture_name,
		"canvas_width": 512,
		"canvas_height": 512,
		"origin_mode": "bottom_left",
		"final_output_element_id": "",
		"elements": []
	})
	selected_texture_id = texture_id
	selected_element_id = ""
	selected_asset_id = ""
	selected_component_id = ""
	active_state = ""
	expanded_textures[texture_id] = true
	texture_dialog.hide()
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _next_default_texture_name() -> String:
	var index := 1
	while _has_texture_name("texture%02d" % index):
		index += 1
	return "texture%02d" % index


func _has_texture_name(texture_name: String) -> bool:
	for texture in textures:
		if str(texture["name"]).to_lower() == texture_name.to_lower():
			return true
	return false


func _open_element_dialog(texture_id: String) -> void:
	selected_texture_id = texture_id
	selected_element_id = ""
	selected_asset_id = ""
	selected_component_id = ""
	element_name_input.text = ""
	element_dialog.set_meta("texture_id", texture_id)
	element_dialog.popup_centered()
	element_name_input.grab_focus()


func _submit_element_name(_submitted_text: String) -> void:
	_confirm_element_creation()


func _confirm_element_creation() -> void:
	var texture_id := str(element_dialog.get_meta("texture_id", ""))
	var texture := _get_texture(texture_id)
	if texture.is_empty():
		element_dialog.hide()
		return
	_record_direct_change()
	var element_name := element_name_input.text.strip_edges()
	if element_name.is_empty():
		element_name = _next_default_element_name(texture)
	var element_id := "element_%d" % _next_element_id(texture)
	texture["elements"].append({
		"id": element_id,
		"name": element_name,
		"type": "generator",
		"output": {"state": "not_ready", "file": ""}
	})
	selected_texture_id = texture_id
	selected_element_id = element_id
	expanded_textures[texture_id] = true
	element_dialog.hide()
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _next_element_id(texture: Dictionary) -> int:
	return _next_element_id_from_list(texture.get("elements", []))


func _next_element_id_from_list(elements: Array) -> int:
	var next_id := 1
	for element in elements:
		if element is Dictionary:
			next_id = maxi(next_id, _id_suffix_number(str(element.get("id", ""))) + 1)
	return next_id


func _next_default_element_name(texture: Dictionary) -> String:
	var index := 1
	while _has_element_name(texture, "element%02d" % index):
		index += 1
	return "element%02d" % index


func _has_element_name(texture: Dictionary, element_name: String) -> bool:
	for element in texture.get("elements", []):
		if str(element.get("name", "")).to_lower() == element_name.to_lower():
			return true
	return false


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
	var search_text := outliner_search_input.text.strip_edges().to_lower() if is_instance_valid(outliner_search_input) else ""
	var show_assets := outliner_filter == "all" or outliner_filter == "assets"
	var show_textures := outliner_filter == "all" or outliner_filter == "textures"
	if show_assets:
		var visible_assets: Array = []
		for asset in assets:
			if _asset_matches_search(asset, search_text):
				visible_assets.append(asset)
		visible_assets.sort_custom(_sort_named_documents)
		outliner_list.add_child(_create_outliner_group_label("Assets"))
		for asset in visible_assets:
			_render_asset_outliner_entry(asset, not search_text.is_empty())
	if show_textures:
		var visible_textures: Array = []
		for texture in textures:
			if _texture_matches_search(texture, search_text):
				visible_textures.append(texture)
		visible_textures.sort_custom(_sort_named_documents)
		outliner_list.add_child(_create_outliner_group_label("Textures"))
		for texture in visible_textures:
			_render_texture_outliner_entry(texture, not search_text.is_empty())


func _asset_matches_search(asset: Dictionary, search_text: String) -> bool:
	if search_text.is_empty() or str(asset.get("name", "")).to_lower().contains(search_text):
		return true
	for component in asset.get("components", []):
		if str(component.get("name", "")).to_lower().contains(search_text):
			return true
	for guide in asset.get("guides", []):
		if str(guide.get("name", "")).to_lower().contains(search_text):
			return true
	return false


func _texture_matches_search(texture: Dictionary, search_text: String) -> bool:
	if search_text.is_empty() or str(texture.get("name", "")).to_lower().contains(search_text):
		return true
	for element in texture.get("elements", []):
		if str(element.get("name", "")).to_lower().contains(search_text):
			return true
		if str(element.get("type", "generator")) == "import":
			# Processed outputs are derived children of an Import Element, but
			# remain searchable so a pipeline stage can be found directly.
			if "processed elements".contains(search_text) or "white to alpha".contains(search_text):
				return true
	return false


func _sort_named_documents(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()


func _create_outliner_group_label(text: String) -> Label:
	var label := _create_panel_label(text)
	label.add_theme_color_override("font_color", Color("#737f91"))
	label.add_theme_font_size_override("font_size", 10)
	return label


func _create_outliner_child_group_label(text: String, indent := 16) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var placeholder := Control.new()
	placeholder.custom_minimum_size = Vector2(indent, 0)
	row.add_child(placeholder)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(0, 24)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#737f91"))
	row.add_child(label)
	return row


func _render_asset_outliner_entry(asset: Dictionary, force_expand := false) -> void:
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
	if not force_expand and not bool(expanded_assets.get(asset_id, false)):
		return
	var components: Array = []
	var guides: Array = asset.get("guides", []).duplicate(true)
	for component in asset.get("components", []):
		if str(component.get("type", "component")) == "guide":
			guides.append(component)
		else:
			components.append(component)
	components.sort_custom(_sort_named_documents)
	guides.sort_custom(_sort_named_documents)
	asset_container.add_child(_create_outliner_child_group_label("Components"))
	for component in components:
		var component_id := str(component["id"])
		var component_row := HBoxContainer.new()
		component_row.add_theme_constant_override("separation", 0)
		asset_container.add_child(component_row)
		var child_placeholder := Control.new()
		child_placeholder.custom_minimum_size = Vector2(16, 0)
		component_row.add_child(child_placeholder)
		var component_button := Button.new()
		var component_name := str(component["name"])
		component_button.text = component_name if bool(component.get("visibility", true)) else _strikethrough_text(component_name)
		component_button.custom_minimum_size = Vector2(0, 30)
		component_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		component_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		component_button.focus_mode = Control.FOCUS_NONE
		_style_outliner_button(component_button, component_id == selected_component_id)
		component_button.pressed.connect(_select_component.bind(asset_id, component_id))
		component_row.add_child(component_button)
	if not guides.is_empty():
		asset_container.add_child(_create_outliner_child_group_label("Guides"))
		for guide in guides:
			var guide_row := HBoxContainer.new()
			guide_row.add_theme_constant_override("separation", 0)
			var guide_placeholder := Control.new()
			guide_placeholder.custom_minimum_size = Vector2(16, 0)
			guide_row.add_child(guide_placeholder)
			var guide_button := Button.new()
			guide_button.text = str(guide.get("name", "Guide"))
			guide_button.custom_minimum_size = Vector2(0, 30)
			guide_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			guide_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			guide_button.focus_mode = Control.FOCUS_NONE
			_style_outliner_button(guide_button, str(guide.get("id", "")) == selected_component_id)
			guide_row.add_child(guide_button)
			asset_container.add_child(guide_row)


func _render_texture_outliner_entry(texture: Dictionary, force_expand := false) -> void:
	var texture_id := str(texture["id"])
	var texture_container := VBoxContainer.new()
	texture_container.add_theme_constant_override("separation", 0)
	outliner_list.add_child(texture_container)
	var texture_header := HBoxContainer.new()
	texture_header.add_theme_constant_override("separation", 2)
	texture_container.add_child(texture_header)
	var texture_button := Button.new()
	texture_button.text = str(texture["name"])
	texture_button.custom_minimum_size = Vector2(0, 30)
	texture_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	texture_button.focus_mode = Control.FOCUS_NONE
	_style_outliner_button(texture_button, texture_id == selected_texture_id and selected_element_id.is_empty())
	texture_button.pressed.connect(_select_texture.bind(texture_id))
	texture_header.add_child(texture_button)
	var add_button := Button.new()
	add_button.text = "Add"
	add_button.custom_minimum_size = Vector2(48, 30)
	add_button.focus_mode = Control.FOCUS_NONE
	add_button.pressed.connect(_open_element_dialog.bind(texture_id))
	texture_header.add_child(add_button)
	if not force_expand and not bool(expanded_textures.get(texture_id, false)):
		return
	var import_elements: Array = []
	var generator_elements: Array = []
	for element in texture.get("elements", []):
		if str(element.get("type", "generator")) == "import":
			import_elements.append(element)
		else:
			generator_elements.append(element)
	import_elements.sort_custom(_sort_named_documents)
	generator_elements.sort_custom(_sort_named_documents)
	texture_container.add_child(_create_outliner_child_group_label("Import Elements"))
	for element in import_elements:
		_render_texture_element_row(texture_container, texture_id, element)
	texture_container.add_child(_create_outliner_child_group_label("Generator Elements"))
	for element in generator_elements:
		_render_texture_element_row(texture_container, texture_id, element)


func _render_texture_element_row(texture_container: VBoxContainer, texture_id: String, element: Dictionary) -> void:
	var element_row := HBoxContainer.new()
	element_row.add_theme_constant_override("separation", 0)
	texture_container.add_child(element_row)
	var child_placeholder := Control.new()
	child_placeholder.custom_minimum_size = Vector2(16, 0)
	element_row.add_child(child_placeholder)
	var element_button := Button.new()
	element_button.text = str(element.get("name", "Element"))
	element_button.custom_minimum_size = Vector2(0, 30)
	element_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	element_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	element_button.focus_mode = Control.FOCUS_NONE
	_style_outliner_button(element_button, texture_id == selected_texture_id and str(element.get("id", "")) == selected_element_id)
	element_button.pressed.connect(_select_element.bind(texture_id, str(element.get("id", ""))))
	element_row.add_child(element_button)
	if SHOW_PROCESSED_OUTLINER and str(element.get("type", "generator")) == "import":
		# Processing results are derived from the import and therefore shown as
		# nested rows instead of independent texture elements.
		texture_container.add_child(_create_outliner_child_group_label("Processed Elements", 32))
		_render_processed_element_row(texture_container, texture_id, element)


func _render_processed_element_row(texture_container: VBoxContainer, texture_id: String, import_element: Dictionary) -> void:
	var processed_row := HBoxContainer.new()
	processed_row.add_theme_constant_override("separation", 0)
	texture_container.add_child(processed_row)
	var processed_placeholder := Control.new()
	processed_placeholder.custom_minimum_size = Vector2(32, 0)
	processed_row.add_child(processed_placeholder)
	var processed_button := Button.new()
	processed_button.text = "White to Alpha"
	processed_button.custom_minimum_size = Vector2(0, 28)
	processed_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	processed_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	processed_button.focus_mode = Control.FOCUS_NONE
	var is_selected := texture_id == selected_texture_id \
		and str(import_element.get("id", "")) == selected_element_id \
		and active_import_preview_mode == "white_to_alpha"
	_style_outliner_button(processed_button, is_selected)
	processed_button.pressed.connect(_select_processed_preview.bind(texture_id, str(import_element.get("id", ""))))
	if _element_output_state(import_element) != "ready":
		processed_button.add_theme_color_override("font_color", Color("#737f91"))
		processed_button.add_theme_color_override("font_hover_color", Color("#aab3c2"))
		processed_button.tooltip_text = "Not ready — process the Import Element first"
	processed_row.add_child(processed_button)


func _select_processed_preview(texture_id: String, element_id: String) -> void:
	selected_texture_id = texture_id
	selected_element_id = element_id
	selected_asset_id = ""
	selected_component_id = ""
	active_state = ""
	active_import_preview_mode = "white_to_alpha"
	expanded_textures[texture_id] = true
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _on_outliner_filter_selected(index: int) -> void:
	outliner_filter = ["all", "assets", "textures"][index]
	_render_outliner()


func _strikethrough_text(text: String) -> String:
	var result := ""
	var strike_mark := String.chr(0x0336)
	for character in text:
		result += character + strike_mark
	return result


func _select_asset(asset_id: String) -> void:
	var was_selected := selected_asset_id == asset_id and selected_component_id.is_empty()
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_texture_id = ""
	selected_element_id = ""
	active_state = ""
	canvas_view.set_interaction_state("")
	if was_selected:
		expanded_assets[asset_id] = not bool(expanded_assets.get(asset_id, false))
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _select_texture(texture_id: String) -> void:
	var was_selected := selected_texture_id == texture_id and selected_element_id.is_empty()
	active_import_preview_mode = "original"
	selected_texture_id = texture_id
	selected_element_id = ""
	selected_asset_id = ""
	selected_component_id = ""
	active_state = ""
	if was_selected:
		expanded_textures[texture_id] = not bool(expanded_textures.get(texture_id, false))
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _select_element(texture_id: String, element_id: String) -> void:
	active_import_preview_mode = "original"
	selected_texture_id = texture_id
	selected_element_id = element_id
	selected_asset_id = ""
	selected_component_id = ""
	active_state = ""
	expanded_textures[texture_id] = true
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _open_component_dialog(asset_id: String) -> void:
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_texture_id = ""
	selected_element_id = ""
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
	_record_direct_change()
	var component_name := component_name_input.text.strip_edges()
	if component_name.is_empty():
		component_name = _next_default_component_name(asset)
	var component_id := "component_%d" % next_component_id
	next_component_id += 1
	asset["components"].append({
		"id": component_id,
		"name": component_name,
		"outer_shape": [],
		"closed": false,
		"transform": _default_component_transform(),
		"visibility": true,
		"z_index": 0
	})
	selected_asset_id = asset_id
	selected_component_id = component_id
	selected_texture_id = ""
	selected_element_id = ""
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
	selected_texture_id = ""
	selected_element_id = ""
	active_state = ""
	canvas_view.set_interaction_state("")
	expanded_assets[asset_id] = true
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _delete_selected_component() -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty() or selected_component_id.is_empty():
		return
	var component_index := -1
	for index in range(asset["components"].size()):
		if str(asset["components"][index]["id"]) == selected_component_id:
			component_index = index
			break
	if component_index < 0:
		return
	_record_direct_change()
	asset["components"].remove_at(component_index)
	selected_component_id = ""
	active_state = ""
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
	transform_fields.clear()
	inspector_content.add_child(_create_panel_label("Inspector"))
	if not selected_texture_id.is_empty():
		var texture := _get_texture(selected_texture_id)
		if texture.is_empty():
			return
		inspector_content.add_child(_create_inspector_section("Texture" if selected_element_id.is_empty() else "Element"))
		inspector_content.add_child(_create_inspector_field_label("Name"))
		var texture_name_editor := _create_name_editor(str(texture["name"] if selected_element_id.is_empty() else _get_element(texture, selected_element_id).get("name", "Element")), "Texture name")
		if selected_element_id.is_empty():
			texture_name_editor.text_submitted.connect(_rename_selected_texture)
			texture_name_editor.focus_exited.connect(func() -> void: _rename_selected_texture(texture_name_editor.text))
		else:
			texture_name_editor.text_submitted.connect(_rename_selected_element)
			texture_name_editor.focus_exited.connect(func() -> void: _rename_selected_element(texture_name_editor.text))
		inspector_content.add_child(texture_name_editor)
		var output_element := _get_element(texture, selected_element_id) if not selected_element_id.is_empty() else _get_texture_final_output_element(texture)
		inspector_content.add_child(_create_inspector_section("Output"))
		var output_state_label := Label.new()
		output_state_label.text = _element_output_state(output_element) if not output_element.is_empty() else _texture_output_state(texture)
		output_state_label.custom_minimum_size = Vector2(0, 20)
		output_state_label.add_theme_font_size_override("font_size", 11)
		output_state_label.add_theme_color_override("font_color", Color("#f2c94c") if output_state_label.text == "not_ready" else Color("#75b88a"))
		inspector_content.add_child(output_state_label)
		if selected_element_id.is_empty():
			if not output_element.is_empty():
				inspector_content.add_child(_create_inspector_field_label("Final Output"))
				var final_output_label := Label.new()
				final_output_label.text = str(output_element.get("name", "Element"))
				final_output_label.add_theme_font_size_override("font_size", 11)
				final_output_label.add_theme_color_override("font_color", Color("#9aa3b2"))
				inspector_content.add_child(final_output_label)
			var import_element := _find_import_element(texture)
			var import_source = import_element.get("source", {}) if not import_element.is_empty() else {}
			if import_source is Dictionary and not import_source.is_empty():
				inspector_content.add_child(_create_inspector_field_label("Source"))
				var source_label := Label.new()
				source_label.text = str(import_source.get("original_name", import_source.get("file", "")))
				source_label.add_theme_font_size_override("font_size", 11)
				source_label.add_theme_color_override("font_color", Color("#9aa3b2"))
				inspector_content.add_child(source_label)
		elif not output_element.is_empty() and str(output_element.get("type", "generator")) == "import":
			inspector_content.add_child(_create_inspector_section("Processing"))
			var pipeline = output_element.get("pipeline", {})
			if not pipeline is Dictionary:
				pipeline = {}
			var processing_label := _create_inspector_field_label("White to Alpha")
			inspector_content.add_child(processing_label)
			var threshold_label := _create_inspector_field_label("Threshold")
			inspector_content.add_child(threshold_label)
			var threshold_field := SpinBox.new()
			import_threshold_field = threshold_field
			threshold_field.min_value = 0.0
			threshold_field.max_value = 1.0
			threshold_field.step = 0.01
			threshold_field.custom_minimum_size = Vector2(0, 26)
			threshold_field.add_theme_font_size_override("font_size", 11)
			pending_import_threshold = clampf(float(pipeline.get("threshold", 0.05)), 0.0, 1.0)
			# Rebuilding the Inspector must not emit value_changed and overwrite
			# the user's current threshold with the default value.
			threshold_field.set_value_no_signal(pending_import_threshold)
			# SpinBox text entry can commit without a reliable value_changed event;
			# listen to the embedded LineEdit as the source of truth as well.
			threshold_field.get_line_edit().text_changed.connect(_on_import_threshold_text_changed)
			inspector_content.add_child(threshold_field)
			var process_button := Button.new()
			process_button.text = "Process"
			process_button.custom_minimum_size = Vector2(0, 26)
			process_button.add_theme_font_size_override("font_size", 11)
			process_button.focus_mode = Control.FOCUS_NONE
			process_button.pressed.connect(_process_selected_import_element)
			inspector_content.add_child(process_button)
		return
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty():
		return
	if selected_component_id.is_empty():
		inspector_content.add_child(_create_inspector_section("Asset"))
		inspector_content.add_child(_create_inspector_field_label("Name"))
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
	inspector_content.add_child(_create_inspector_section("Component"))
	inspector_content.add_child(_create_inspector_field_label("Name"))
	component_name_editor = _create_name_editor(str(component["name"]), "Component name")
	component_name_editor.text_submitted.connect(_rename_selected_component)
	component_name_editor.focus_exited.connect(func() -> void:
		_rename_selected_component(component_name_editor.text)
	)
	inspector_content.add_child(component_name_editor)
	inspector_content.add_child(_create_inspector_section("Transform"))
	var transform_grid := GridContainer.new()
	transform_grid.columns = 2
	transform_grid.add_theme_constant_override("h_separation", 8)
	transform_grid.add_theme_constant_override("v_separation", 4)
	inspector_content.add_child(transform_grid)
	var transform: Dictionary = component.get("transform", _default_component_transform())
	var transform_position: Vector2 = transform.get("position", Vector2.ZERO)
	var transform_scale: Vector2 = transform.get("scale", Vector2.ONE)
	var pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
	_add_transform_field(transform_grid, "Position X", transform_position.x, "position_x", 1.0)
	_add_transform_field(transform_grid, "Position Y", transform_position.y, "position_y", 1.0)
	_add_transform_field(transform_grid, "Rotation", float(transform.get("rotation", 0.0)), "rotation", 1.0)
	_add_transform_field(transform_grid, "Scale X", transform_scale.x, "scale_x", 0.01)
	_add_transform_field(transform_grid, "Scale Y", transform_scale.y, "scale_y", 0.01)
	_add_transform_field(transform_grid, "Pivot X", pivot.x, "pivot_x", 1.0)
	_add_transform_field(transform_grid, "Pivot Y", pivot.y, "pivot_y", 1.0)
	inspector_content.add_child(_create_inspector_section("Visibility / Layer"))
	var visibility_toggle := CheckButton.new()
	visibility_toggle.text = "Visible"
	visibility_toggle.custom_minimum_size = Vector2(0, 26)
	visibility_toggle.add_theme_font_size_override("font_size", 11)
	visibility_toggle.button_pressed = bool(component.get("visibility", true))
	visibility_toggle.toggled.connect(_on_component_visibility_changed)
	inspector_content.add_child(visibility_toggle)
	var z_index_label := _create_inspector_field_label("Z Index")
	inspector_content.add_child(z_index_label)
	var z_index_field := SpinBox.new()
	z_index_field.min_value = -10000
	z_index_field.max_value = 10000
	z_index_field.step = 1
	z_index_field.value = int(component.get("z_index", 0))
	z_index_field.custom_minimum_size = Vector2(0, 26)
	z_index_field.add_theme_font_size_override("font_size", 11)
	z_index_field.value_changed.connect(_on_component_z_index_changed)
	inspector_content.add_child(z_index_field)


func _create_name_editor(value: String, placeholder: String) -> LineEdit:
	var editor := LineEdit.new()
	editor.text = value
	editor.custom_minimum_size = Vector2(0, 26)
	editor.placeholder_text = placeholder
	editor.add_theme_font_size_override("font_size", 12)
	return editor


func _add_transform_field(grid: GridContainer, label_text: String, value: float, property_name: String, step: float) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#7f8a9b"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(label)
	var field := SpinBox.new()
	field.min_value = -100000.0
	field.max_value = 100000.0
	field.step = step
	field.value = value
	field.custom_minimum_size = Vector2(96, 26)
	field.add_theme_font_size_override("font_size", 11)
	field.value_changed.connect(_on_transform_value_changed.bind(property_name))
	transform_fields[property_name] = field
	grid.add_child(field)


func _on_transform_value_changed(value: float, property_name: String) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		return
	_record_direct_change()
	var transform: Dictionary = component.get("transform", _default_component_transform())
	var transform_position: Vector2 = transform.get("position", Vector2.ZERO)
	var transform_scale: Vector2 = transform.get("scale", Vector2.ONE)
	var pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
	var previous_pivot := pivot
	match property_name:
		"position_x": transform_position.x = value
		"position_y": transform_position.y = value
		"rotation": transform["rotation"] = value
		"scale_x": transform_scale.x = value
		"scale_y": transform_scale.y = value
		"pivot_x": pivot.x = value
		"pivot_y": pivot.y = value
	if property_name == "pivot_x" or property_name == "pivot_y":
		var pivot_rotation := deg_to_rad(float(transform.get("rotation", 0.0)))
		transform_position += ((pivot - previous_pivot) * transform_scale).rotated(pivot_rotation)
	transform["position"] = transform_position
	transform["scale"] = transform_scale
	transform["pivot"] = pivot
	component["transform"] = transform
	_render_canvas_context()


func _on_component_visibility_changed(visibility_enabled: bool) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not component.is_empty():
		_record_direct_change()
		component["visibility"] = visibility_enabled
		_render_outliner()
		_render_canvas_context()


func _on_component_z_index_changed(value: float) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not component.is_empty():
		_record_direct_change()
		component["z_index"] = int(value)
		_render_canvas_context()


func _rename_selected_asset(new_name: String) -> void:
	var asset_name := new_name.strip_edges()
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty():
		return
	if asset_name.is_empty():
		asset_name_editor.text = str(asset["name"])
		return
	if asset_name == str(asset["name"]):
		return
	_record_direct_change()
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
	if component_name == str(component["name"]):
		return
	_record_direct_change()
	component["name"] = component_name
	_render_outliner()
	_render_canvas_context()


func _rename_selected_texture(new_name: String) -> void:
	var texture_name := new_name.strip_edges()
	var texture := _get_texture(selected_texture_id)
	if texture.is_empty() or texture_name.is_empty() or texture_name == str(texture["name"]):
		return
	_record_direct_change()
	texture["name"] = texture_name
	_render_outliner()
	_render_inspector()


func _rename_selected_element(new_name: String) -> void:
	var element_name := new_name.strip_edges()
	var texture := _get_texture(selected_texture_id)
	var element := _get_element(texture, selected_element_id)
	if element.is_empty() or element_name.is_empty() or element_name == str(element.get("name", "")):
		return
	_record_direct_change()
	element["name"] = element_name
	_render_outliner()
	_render_inspector()


func _on_import_threshold_changed(value: float) -> void:
	pending_import_threshold = clampf(value, 0.0, 1.0)


func _on_import_threshold_text_changed(text: String) -> void:
	if text.is_valid_float():
		pending_import_threshold = clampf(float(text), 0.0, 1.0)


func _read_import_threshold() -> float:
	if is_instance_valid(import_threshold_field):
		var entered_text := import_threshold_field.get_line_edit().text.strip_edges().replace(",", ".")
		if entered_text.is_valid_float():
			return clampf(float(entered_text), 0.0, 1.0)
	return clampf(pending_import_threshold, 0.0, 1.0)


func _render_canvas_context() -> void:
	_render_context_bar()
	_render_info_bar()
	if not is_instance_valid(canvas_context_label):
		return
	if not selected_texture_id.is_empty():
		var texture := _get_texture(selected_texture_id)
		if texture.is_empty():
			return
		canvas_view.visible = false
		var selected_element := _get_element(texture, selected_element_id)
		var is_import_element := not selected_element.is_empty() and str(selected_element.get("type", "generator")) == "import"
		texture_canvas.visible = not is_import_element
		import_preview.visible = is_import_element
		texture_context_label.text = "Texture: %s" % str(texture["name"]) if selected_element_id.is_empty() else "Element: %s" % str(selected_element.get("name", "Element"))
		import_preview_context_label.text = "Import Element: %s" % str(selected_element.get("name", "Element")) if is_import_element else ""
		texture_canvas.set_origin_mode(str(texture.get("origin_mode", "bottom_left")))
		texture_canvas.set_final_texture_path(_get_texture_final_path(texture) if selected_element_id.is_empty() else "")
		texture_canvas.set_selected_element(str(selected_element.get("name", "")) if not selected_element.is_empty() else "")
		if is_import_element:
			# Processing is an explicit action. Until Process is pressed, the
			# White to Alpha preview must not change live with the threshold field.
			# Show the source until a ready processed output exists.
			if active_import_preview_mode == "white_to_alpha" and _element_output_state(selected_element) == "ready":
				import_preview.set_preview_path(_get_texture_preview_path(texture, selected_element))
			else:
				import_preview.set_preview_path(_get_texture_source_path(texture, selected_element))
		else:
			import_preview.set_preview_path("")
		return
	canvas_view.visible = true
	texture_canvas.visible = false
	import_preview.visible = false
	texture_context_label.text = ""
	import_preview_context_label.text = ""
	import_preview.set_preview_path("")
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
	var component_transform: Dictionary = component.get("transform", _default_component_transform()).duplicate(true)
	component_transform["visibility"] = bool(component.get("visibility", true))
	component_transform["z_index"] = int(component.get("z_index", 0))
	canvas_view.set_component_transform(component_transform)
	canvas_view.set_reference_shapes(_build_reference_shapes(asset, selected_component_id))
	var component_closed := bool(component.get("closed", component["outer_shape"].size() >= 3))
	canvas_view.set_outer_shape(component["outer_shape"], component_closed)
	if active_state == "draw" and not component_closed:
		canvas_view.set_line_draft(component["outer_shape"])


func _build_reference_shapes(asset: Dictionary, excluded_component_id := "") -> Array:
	var shapes: Array = []
	for component in asset["components"]:
		if str(component["id"]) == excluded_component_id:
			continue
		shapes.append({
			"id": str(component["id"]),
			"points": component["outer_shape"].duplicate(),
			"closed": bool(component.get("closed", component["outer_shape"].size() >= 3)),
			"transform": component.get("transform", _default_component_transform()).duplicate(true),
			"visibility": bool(component.get("visibility", true)),
			"z_index": int(component.get("z_index", 0))
		})
	return shapes


func _on_line_shape_changed(points: Array[Vector2], closed: bool) -> void:
	var asset := _get_asset(selected_asset_id)
	var component := _get_component(asset, selected_component_id)
	if component.is_empty():
		return
	_record_direct_change()
	component["outer_shape"] = points.duplicate()
	component["closed"] = closed
	canvas_view.set_outer_shape(points, closed)


func _on_outer_shape_changed(points: Array[Vector2]) -> void:
	var asset := _get_asset(selected_asset_id)
	var component := _get_component(asset, selected_component_id)
	if component.is_empty():
		return
	_record_coalesced_change()
	component["outer_shape"] = points.duplicate()


func _on_pivot_changed(pivot: Vector2) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		return
	_record_coalesced_change()
	var transform: Dictionary = component.get("transform", _default_component_transform())
	transform["pivot"] = pivot
	component["transform"] = transform


func _on_transform_changed(transform: Dictionary) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not component.is_empty():
		_record_coalesced_change()
		component["transform"] = transform.duplicate(true)
		var transform_position: Vector2 = transform.get("position", Vector2.ZERO)
		var transform_scale: Vector2 = transform.get("scale", Vector2.ONE)
		var pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
		var values := {
			"position_x": transform_position.x,
			"position_y": transform_position.y,
			"rotation": float(transform.get("rotation", 0.0)),
			"scale_x": transform_scale.x,
			"scale_y": transform_scale.y,
			"pivot_x": pivot.x,
			"pivot_y": pivot.y
		}
		for property_name in values:
			var field = transform_fields.get(property_name)
			if is_instance_valid(field):
				field.set_value_no_signal(float(values[property_name]))


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


func _get_texture(texture_id: String) -> Dictionary:
	for texture in textures:
		if str(texture["id"]) == texture_id:
			return texture
	return {}


func _get_element(texture: Dictionary, element_id: String) -> Dictionary:
	if texture.is_empty():
		return {}
	for element in texture.get("elements", []):
		if str(element.get("id", "")) == element_id:
			return element
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
