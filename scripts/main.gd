extends Control

const CREATE_SUBMODULES := ["Asset", "Texture"]
const GEOMETRY_SUBMODULES := ["Sampling", "Seeding", "Meshing", "UV Mapping"]
const STYLE_SUBMODULES := ["Material"]
const MOTION_SUBMODULES := ["Animation", "Path", "Act", "Sequence"]
const INACTIVE_MODULES := ["Transform", "Effects", "Export"]
const WORKSPACES_ROOT := "res://workspaces"
const IMPORT_TEXTURES_ROOT := "res://imports/textures"
const CONFIG_PATH := "res://configs/app_config.json"
const SCHEMA_VERSION := 19
const MAX_HISTORY_SIZE := 100
const PAPER_SIZES_CM := [Vector2(21.0, 29.7), Vector2(29.7, 42.0), Vector2(42.0, 59.4), Vector2(59.4, 84.1), Vector2(84.1, 118.9)]
const PAPER_LABELS := ["A4", "A3", "A2", "A1", "A0"]
const PAPER_NONE_LEVEL := -1
const PAPER_NONE_LABEL := "Kein Rahmen"
# Kept available for a later Outliner presentation, but processed outputs are
# currently reached through the Import Preview instead of additional rows.
const SHOW_PROCESSED_OUTLINER := false

var active_create_submodule := "Asset"
var active_geometry_submodule := "Sampling"
var active_motion_submodule := "Animation"
var active_module := "Create"
var outliner_list: VBoxContainer
var outliner_search_input: LineEdit
var inspector_content: VBoxContainer
var module_sections: Array[ModuleSection] = []
var assets: Array[Dictionary] = []
var textures: Array[Dictionary] = []
var materials: Array[Dictionary] = []
var motion_paths: Array[Dictionary] = []
var motion_acts: Array[Dictionary] = []
var motion_sequences: Array[Dictionary] = []
var next_motion_path_id := 1
var next_motion_act_id := 1
var next_motion_sequence_id := 1
var selected_motion_path_id := ""
var selected_motion_act_id := ""
var selected_motion_sequence_id := ""
var selected_motion_sequence_entry_id := ""
var motion_sequence_view := MotionSequenceWorkspace.VIEW_COMPOSITION
var motion_sequence_phase := 0.0
var motion_sequence_playing := false
var motion_sequence_preview_loop := true
var motion_sequence_phase_slider: HSlider
var motion_sequence_phase_value_label: Label
var motion_sequence_runtime_sequence_label: Label
var motion_sequence_runtime_path_label: Label
var motion_sequence_runtime_animation_label: Label
var motion_path_preview_asset_id := ""
var motion_path_phase := 0.0
var motion_path_playing := false
var motion_path_tool := "draw"
var motion_path_phase_slider: HSlider
var motion_path_phase_value_label: Label
var motion_act_preview_asset_id := ""
var motion_act_phase := 0.0
var motion_act_playing := false
var motion_act_preview_loop := true
var motion_act_phase_slider: HSlider
var motion_act_phase_value_label: Label
var motion_selection := MotionSelection.new()
var motion_phase := 0.0
var motion_player: MotionPlayer
var motion_player_asset_id := ""
var motion_last_marker := ""
var selected_asset_id := ""
var selected_component_id := ""
var selected_edge_id := ""
var selected_point_id := ""
var selected_point_ids: Array[String] = []
var bezier_point_move_start_positions: Dictionary = {}
var bezier_point_move_component_id := ""
var selected_texture_id := ""
var selected_element_id := ""
var selected_material_id := ""
# Legacy workspace fields are retained for backwards-compatible JSON loading.
# The active Material workflow is now always the Graph workspace.
var material_view_mode := "graph"
var lookdev_target_asset_id := ""
var lookdev_target_component_id := ""
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
var material_dialog: ConfirmationDialog
var material_name_input: LineEdit
var texture_import_dialog: FileDialog
var reference_image_dialog: FileDialog
var reference_image_crop_dialog: ReferenceImageCropDialog
var element_dialog: ConfirmationDialog
var element_name_input: LineEdit
var asset_name_editor: LineEdit
var component_name_editor: LineEdit
var transform_fields: Dictionary = {}
var canvas_context_label: Label
var canvas_view: ComponentCanvas
var texture_canvas: TextureCanvas
var import_preview: ImportPreview
var material_graph: GraphEdit
var material_preview_container: CenterContainer
var material_preview_surface: PanelContainer
var material_preview_content: CenterContainer
var material_preview_texture: TextureRect
var material_preview_label: Label
var material_preview_shader: ShaderMaterial
var export_workspace: VBoxContainer
var motion_workspace: MotionWorkspace
var motion_path_workspace: MotionPathWorkspace
var motion_act_workspace: MotionActWorkspace
var motion_sequence_workspace: MotionSequenceWorkspace
var motion_phase_value_label: Label
var motion_phase_marks: MotionPhaseMarks
var motion_phase_slider: HSlider
var motion_play_button: Button
var motion_runtime_state_label: Label
var motion_asset_preview: MotionAssetPreview
var motion_state_dialog: ConfirmationDialog
var motion_state_name_input: LineEdit
var motion_remove_state_dialog: ConfirmationDialog
var pending_motion_remove_state_id := ""
var motion_remove_motion_dialog: ConfirmationDialog
var pending_motion_remove_motion_state_id := ""
var pending_motion_remove_motion_id := ""
var motion_remove_item_dialog: ConfirmationDialog
var pending_motion_remove_item_kind := ""
var pending_motion_remove_item_state_id := ""
var pending_motion_remove_item_id := ""
var motion_path_dialog: ConfirmationDialog
var motion_path_name_input: LineEdit
var motion_sequence_dialog: ConfirmationDialog
var motion_sequence_name_input: LineEdit
var export_summary_label: Label
var export_validation_label: Label
var texture_context_label: Label
var import_preview_context_label: Label
var context_bar: HBoxContainer
var create_action_button: Button
var info_bar: HBoxContainer
var program_status_label: Label
var active_material_status_label: Label
var status_clear_timer: Timer
var active_draw_tool := ""
var active_draw_point_mode := "linear"
var active_state := ""
var active_import_preview_mode := "original"
var pending_import_threshold := 0.05
var import_threshold_field: SpinBox
var active_edit_mode := "point"
var edit_bezier_handles := false
var edit_point_set_mode := false
var active_transform_mode := "transform"
var snap_enabled := true
var snap_mode := "coarse"
var snap_grid_step := 16.0
var snap_rotation_step := 15.0
var snap_button: Button
var snap_popup: PopupPanel
var snap_mode_buttons: Array[CheckBox] = []
var snap_rotation_slider: HSlider
var snap_rotation_value_label: Label
var paper_menu: MenuButton
var paper_level := 0
var world_scale_menu: Button
var world_scale_popup: PopupPanel
var world_unit_option: OptionButton
var world_grid_size_field: SpinBox
var world_scale_summary_label: Label
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
var world_unit := "cm"
var world_grid_size := 0.5


func _ready() -> void:
	# Native macOS quit requests bypass regular key input. Handle them below so
	# Cmd+Q can be blocked without disabling a normal window close.
	get_tree().auto_accept_quit = false
	motion_player = MotionPlayer.new()
	motion_player.phase_changed.connect(_on_motion_player_phase_changed)
	motion_player.state_changed.connect(_on_motion_player_state_changed)
	motion_player.marker_fired.connect(_on_motion_player_marker_fired)
	motion_player.playback_changed.connect(_on_motion_player_playback_changed)
	_build_ui()
	history_coalesce_timer = Timer.new()
	history_coalesce_timer.one_shot = true
	history_coalesce_timer.wait_time = 0.25
	history_coalesce_timer.timeout.connect(_finish_history_coalescing)
	add_child(history_coalesce_timer)
	_apply_world_scale()
	_render_outliner()
	_render_inspector()
	_render_canvas_context()
	_load_last_workspace()
	call_deferred("_disable_quit_shortcut")
	call_deferred("_focus_active_canvas_after_startup")


func _process(delta: float) -> void:
	if active_module == "Motion" and active_motion_submodule == "Animation" and motion_player != null:
		motion_player.advance(delta)
	elif active_module == "Motion" and active_motion_submodule == "Path" and motion_path_playing:
		_advance_motion_path_preview(delta)
	elif active_module == "Motion" and active_motion_submodule == "Act" and motion_act_playing:
		_advance_motion_act_preview(delta)
	elif active_module == "Motion" and active_motion_submodule == "Sequence" and motion_sequence_view == MotionSequenceWorkspace.VIEW_PLAYER and motion_sequence_playing:
		_advance_motion_sequence_preview(delta)


func _disable_quit_shortcut() -> void:
	# Cmd+Q is handled as a native quit request on macOS. The request is filtered
	# in _notification so regular window controls remain available.
	return


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if Input.is_key_pressed(KEY_META) or Input.is_key_pressed(KEY_CTRL):
		_show_status_message("Cmd+Q is disabled.")
		return
	get_tree().quit()
func _load_last_workspace() -> void:
	var config_data = _read_json(CONFIG_PATH)
	if _has_supported_schema(config_data):
		var last_workspace := str(config_data.get("last_workspace", ""))
		if not last_workspace.is_empty():
			_load_workspace(last_workspace)


func _focus_active_canvas_after_startup() -> void:
	# Let the workspace restore finish creating/focusing its controls first.
	await get_tree().process_frame
	await get_tree().process_frame
	if active_module == "Create" and active_create_submodule == "Texture" and is_instance_valid(texture_canvas) and texture_canvas.visible:
		texture_canvas.grab_focus()
	elif is_instance_valid(canvas_view) and canvas_view.visible:
		canvas_view.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if is_instance_valid(canvas_view) and (event.meta_pressed or event.ctrl_pressed or event.keycode in [KEY_META, KEY_CTRL]):
		canvas_view.set_command_shortcut_active(event.meta_pressed or event.ctrl_pressed)
	if not event.pressed or event.echo:
		return
	var has_command_modifier: bool = event.meta_pressed or event.ctrl_pressed
	if has_command_modifier and event.keycode == KEY_Q:
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE:
		_reset_to_default_state()
		get_viewport().set_input_as_handled()
		return
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
	if has_command_modifier and active_module == "Motion" and active_motion_submodule == "Sequence" and event.keycode in [KEY_1, KEY_2]:
		var focus_owner := get_viewport().gui_get_focus_owner()
		if not (focus_owner is LineEdit or focus_owner is TextEdit):
			_set_motion_sequence_view(MotionSequenceWorkspace.VIEW_COMPOSITION if event.keycode == KEY_1 else MotionSequenceWorkspace.VIEW_PLAYER)
			get_viewport().set_input_as_handled()
		return
	if not has_command_modifier and (event.keycode == KEY_BACKSPACE or event.keycode == KEY_DELETE) and active_state == "edit" and active_edit_mode == "point" and not selected_point_ids.is_empty():
		if selected_point_ids.size() == 1:
			_on_bezier_point_delete_requested(selected_point_ids[0])
		else:
			_on_bezier_points_delete_requested(selected_point_ids.duplicate())
		get_viewport().set_input_as_handled()
		return
	if not has_command_modifier and (event.keycode == KEY_BACKSPACE or event.keycode == KEY_DELETE) and active_state.is_empty():
		_delete_current_outliner_selection()
		get_viewport().set_input_as_handled()
		return
	if not has_command_modifier and active_state == "draw" and active_draw_tool == "point":
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:
			_set_draw_point_mode(_draw_point_mode_from_key(event.keycode))
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
	if has_command_modifier and event.keycode == KEY_1:
		_activate_draw_state()
	elif has_command_modifier and event.keycode == KEY_2:
		_activate_edit_point_state()
	elif has_command_modifier and event.keycode == KEY_3:
		_activate_edit_edge_state()
	elif has_command_modifier and event.keycode == KEY_4:
		_activate_edit_face_state()
	elif not has_command_modifier and active_state == "edit" and active_edit_mode == "point" and event.keycode == KEY_1:
		_activate_edit_point_state(false, false)
		get_viewport().set_input_as_handled()
	elif not has_command_modifier and active_state == "edit" and active_edit_mode == "point" and event.keycode == KEY_2:
		_activate_edit_point_state(true, false)
		get_viewport().set_input_as_handled()
	elif not has_command_modifier and active_state == "edit" and active_edit_mode == "point" and event.keycode == KEY_3:
		_activate_edit_point_state(false, true)
		get_viewport().set_input_as_handled()


func _reset_to_default_state() -> void:
	active_state = ""
	active_draw_tool = ""
	active_edit_mode = "point"
	edit_bezier_handles = false
	edit_point_set_mode = false
	active_transform_mode = "transform"
	selected_edge_id = ""
	selected_point_id = ""
	selected_point_ids.clear()
	active_import_preview_mode = "original"
	if is_instance_valid(canvas_view):
		canvas_view.set_interaction_state("")
		canvas_view.set_tool_mode("")
		canvas_view.set_edit_mode(active_edit_mode)
		canvas_view.set_transform_mode(active_transform_mode)
		canvas_view.set_selected_edge_id("")
	_ensure_default_edit_point_state()
	_render_canvas_context()


func _ensure_default_edit_point_state() -> void:
	if selected_component_id.is_empty() or not active_state.is_empty():
		return
	active_state = "edit"
	active_draw_tool = ""
	active_edit_mode = "point"
	edit_bezier_handles = false
	edit_point_set_mode = false
	active_transform_mode = "transform"
	selected_edge_id = ""
	selected_point_id = ""
	selected_point_ids.clear()
	if is_instance_valid(canvas_view):
		canvas_view.set_edit_handles_enabled(false)
		canvas_view.set_edit_point_set_enabled(false)
		canvas_view.set_edit_mode("point")
		canvas_view.set_transform_mode("transform")


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
	create_action_button = Button.new()
	create_action_button.custom_minimum_size = Vector2(132, 32)
	create_action_button.focus_mode = Control.FOCUS_NONE
	create_action_button.pressed.connect(_on_create_action_pressed)
	toolbar.add_child(create_action_button)
	snap_button = Button.new()
	snap_button.text = "Snap: %s  ▼" % ("On" if snap_enabled else "Off")
	snap_button.custom_minimum_size = Vector2(112, 32)
	snap_button.focus_mode = Control.FOCUS_NONE
	snap_button.pressed.connect(_toggle_snap_popup)
	toolbar.add_child(snap_button)
	toolbar.add_child(_create_paper_menu())
	var toolbar_spacer := Control.new()
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(toolbar_spacer)
	var workspace_menu := MenuButton.new()
	workspace_menu.text = "Workspace  ▼"
	workspace_menu.custom_minimum_size = Vector2(132, 32)
	workspace_menu.focus_mode = Control.FOCUS_NONE
	var workspace_popup := workspace_menu.get_popup()
	_style_popup_menu(workspace_popup)
	workspace_popup.add_item("New")
	workspace_popup.add_item("Save")
	workspace_popup.add_item("Load")
	workspace_popup.id_pressed.connect(_on_workspace_menu_id)
	_create_world_scale_popup()
	toolbar.add_child(world_scale_menu)
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
	_add_module_section(module_rail, "Geometry", GEOMETRY_SUBMODULES, false, false, -1)
	_add_module_section(module_rail, "Style", STYLE_SUBMODULES)
	_add_module_section(module_rail, "Motion", MOTION_SUBMODULES, false, false, 3)
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
	# Canvas drawing can legitimately extend beyond its Control rect while
	# panning/zooming. Clip it at the workspace panel so it never paints over
	# the outliner, toolbar, or inspector.
	canvas_panel.clip_contents = true
	canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_column.add_child(canvas_panel)
	canvas_view = ComponentCanvas.new()
	canvas_view.bezier_point_added.connect(_on_bezier_point_added)
	canvas_view.bezier_chain_closed.connect(_on_bezier_chain_closed)
	canvas_view.edge_selection_changed.connect(_on_edge_selection_changed)
	canvas_view.point_selection_changed.connect(_on_point_selection_changed)
	canvas_view.point_selection_set_changed.connect(_on_point_selection_set_changed)
	canvas_view.bezier_points_move_started.connect(_on_bezier_points_move_started)
	canvas_view.bezier_points_moved.connect(_on_bezier_points_moved)
	canvas_view.bezier_handle_changed.connect(_on_bezier_handle_changed)
	canvas_view.bezier_edge_insert_requested.connect(_on_bezier_edge_insert_requested)
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
	material_graph = GraphEdit.new()
	material_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	material_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	material_graph.show_grid = true
	material_graph.visible = false
	canvas_panel.add_child(material_graph)
	_create_material_graph()
	_create_material_preview()
	_create_export_workspace(canvas_panel)
	_create_motion_workspace(canvas_panel)
	_create_motion_path_workspace(canvas_panel)
	_create_motion_act_workspace(canvas_panel)
	_create_motion_sequence_workspace(canvas_panel)
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
	active_material_status_label = Label.new()
	active_material_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	active_material_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	active_material_status_label.add_theme_font_size_override("font_size", 11)
	active_material_status_label.add_theme_color_override("font_color", Color("#9aa3b2"))
	status_right.add_child(active_material_status_label)
	status_clear_timer = Timer.new()
	status_clear_timer.one_shot = true
	status_clear_timer.wait_time = 2.5
	status_clear_timer.timeout.connect(_clear_status_message)
	add_child(status_clear_timer)

	_create_asset_dialog()
	_create_component_dialog()
	_create_texture_dialog()
	_create_material_dialog()
	_create_texture_import_dialog()
	_create_reference_image_dialog()
	reference_image_crop_dialog = ReferenceImageCropDialog.new()
	reference_image_crop_dialog.image_accepted.connect(_save_reference_image_result)
	reference_image_crop_dialog.image_cropped.connect(_save_reference_image_result)
	add_child(reference_image_crop_dialog)
	_create_element_dialog()
	_create_workspace_dialogs()
	_create_motion_state_dialogs()
	_create_motion_resource_dialogs()


func _create_material_graph() -> void:
	var source_node := GraphNode.new()
	source_node.name = "texture_source"
	source_node.title = "Texture Source"
	source_node.position_offset = Vector2(180, 220)
	source_node.size = Vector2(190, 76)
	var source_label := Label.new()
	source_label.text = "Ready Texture reference"
	source_node.add_child(source_label)
	source_node.set_slot(0, false, 0, Color.WHITE, true, 0, Color("#f2c94c"))
	material_graph.add_child(source_node)

	var output_node := GraphNode.new()
	output_node.name = "material_output"
	output_node.title = "Material Output"
	output_node.position_offset = Vector2(520, 220)
	output_node.size = Vector2(190, 76)
	var output_label := Label.new()
	output_label.text = "Final Material"
	output_node.add_child(output_label)
	output_node.set_slot(0, true, 0, Color("#f2c94c"), false, 0, Color.WHITE)
	material_graph.add_child(output_node)
	material_graph.connect_node("texture_source", 0, "material_output", 0)


func _create_material_preview() -> void:
	material_preview_container = CenterContainer.new()
	material_preview_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	material_preview_container.offset_left = -292.0
	material_preview_container.offset_top = 12.0
	material_preview_container.offset_right = -12.0
	material_preview_container.offset_bottom = 192.0
	material_preview_container.visible = false
	material_graph.get_parent().add_child(material_preview_container)
	material_preview_surface = PanelContainer.new()
	material_preview_surface.custom_minimum_size = Vector2(280, 180)
	var surface_style := StyleBoxFlat.new()
	surface_style.bg_color = Color("#d9dde4")
	surface_style.border_color = Color("#697386")
	surface_style.set_border_width_all(1)
	material_preview_surface.add_theme_stylebox_override("panel", surface_style)
	material_preview_container.add_child(material_preview_surface)
	var preview_stack := VBoxContainer.new()
	preview_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	material_preview_surface.add_child(preview_stack)
	material_preview_content = CenterContainer.new()
	material_preview_content.custom_minimum_size = Vector2(320, 320)
	preview_stack.add_child(material_preview_content)
	material_preview_texture = TextureRect.new()
	material_preview_texture.custom_minimum_size = Vector2(320, 320)
	material_preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	material_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var preview_shader := Shader.new()
	preview_shader.code = """shader_type canvas_item;
uniform vec2 mapping_scale = vec2(1.0);
uniform vec2 mapping_offset = vec2(0.0);
uniform int wrap_mode = 1;
void fragment() {
	vec2 uv = UV;
	if (wrap_mode == 1) {
		uv = clamp(UV / max(mapping_scale, vec2(0.0001)) + mapping_offset, vec2(0.0), vec2(1.0));
	} else if (wrap_mode == 2) {
		uv = fract(UV / max(mapping_scale, vec2(0.0001)) + mapping_offset);
	}
	COLOR = texture(TEXTURE, uv) * COLOR;
}"""
	material_preview_shader = ShaderMaterial.new()
	material_preview_shader.shader = preview_shader
	material_preview_texture.material = material_preview_shader
	material_preview_content.add_child(material_preview_texture)
	material_preview_label = Label.new()
	material_preview_label.text = "No ready Texture"
	material_preview_label.add_theme_color_override("font_color", Color("#5c6675"))
	material_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	material_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_stack.add_child(material_preview_label)


func _create_export_workspace(parent: Control) -> void:
	export_workspace = VBoxContainer.new()
	export_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	export_workspace.add_theme_constant_override("separation", 8)
	export_workspace.visible = false
	parent.add_child(export_workspace)
	var title := Label.new()
	title.text = "Build"
	title.add_theme_font_size_override("font_size", 16)
	export_workspace.add_child(title)
	export_summary_label = Label.new()
	export_summary_label.add_theme_font_size_override("font_size", 12)
	export_workspace.add_child(export_summary_label)
	var pipeline := Label.new()
	pipeline.text = "Source Asset  →  Validate  →  Godot Scene"
	pipeline.add_theme_color_override("font_color", Color("#9aa3b2"))
	export_workspace.add_child(pipeline)
	export_validation_label = Label.new()
	export_validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	export_validation_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	export_workspace.add_child(export_validation_label)


func _create_motion_workspace(parent: Control) -> void:
	motion_workspace = MotionWorkspace.new()
	motion_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	motion_workspace.set_selection_model(motion_selection)
	motion_workspace.selection_changed.connect(_on_motion_selection_changed)
	motion_workspace.document_change_requested.connect(_record_direct_change)
	motion_workspace.add_state_requested.connect(_open_motion_state_dialog)
	motion_workspace.authoring_error.connect(_show_status_message)
	motion_workspace.visible = false
	parent.add_child(motion_workspace)


func _create_motion_path_workspace(parent: Control) -> void:
	motion_path_workspace = MotionPathWorkspace.new()
	motion_path_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	motion_path_workspace.point_add_requested.connect(_on_motion_path_point_add_requested)
	motion_path_workspace.point_move_started.connect(_record_direct_change)
	motion_path_workspace.point_move_requested.connect(_on_motion_path_point_move_requested)
	motion_path_workspace.handle_move_requested.connect(_on_motion_path_handle_move_requested)
	motion_path_workspace.point_delete_requested.connect(_on_motion_path_point_delete_requested)
	motion_path_workspace.visible = false
	parent.add_child(motion_path_workspace)


func _create_motion_sequence_workspace(parent: Control) -> void:
	motion_sequence_workspace = MotionSequenceWorkspace.new()
	motion_sequence_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	motion_sequence_workspace.entry_selected.connect(_select_motion_sequence_entry)
	motion_sequence_workspace.add_entry_requested.connect(_add_motion_sequence_entry)
	motion_sequence_workspace.visible = false
	parent.add_child(motion_sequence_workspace)


func _create_motion_act_workspace(parent: Control) -> void:
	motion_act_workspace = MotionActWorkspace.new()
	motion_act_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	motion_act_workspace.act_selected.connect(_select_motion_act)
	motion_act_workspace.add_primitive_requested.connect(_add_motion_act)
	motion_act_workspace.visible = false
	parent.add_child(motion_act_workspace)


func _create_motion_state_dialogs() -> void:
	motion_state_dialog = ConfirmationDialog.new()
	motion_state_dialog.title = "Add State"
	motion_state_dialog.dialog_text = "Enter a unique State name"
	motion_state_dialog.size = Vector2i(360, 160)
	motion_state_dialog.confirmed.connect(_confirm_motion_state_creation)
	motion_state_name_input = LineEdit.new()
	motion_state_name_input.placeholder_text = "State name"
	motion_state_name_input.custom_minimum_size = Vector2(320, 32)
	motion_state_name_input.text_submitted.connect(func(_text: String) -> void: _confirm_motion_state_creation())
	motion_state_dialog.add_child(motion_state_name_input)
	add_child(motion_state_dialog)
	motion_remove_state_dialog = ConfirmationDialog.new()
	motion_remove_state_dialog.title = "Remove State"
	motion_remove_state_dialog.ok_button_text = "Remove"
	motion_remove_state_dialog.confirmed.connect(_confirm_motion_state_removal)
	add_child(motion_remove_state_dialog)
	motion_remove_motion_dialog = ConfirmationDialog.new()
	motion_remove_motion_dialog.title = "Remove Motion"
	motion_remove_motion_dialog.ok_button_text = "Remove"
	motion_remove_motion_dialog.confirmed.connect(_confirm_motion_removal)
	add_child(motion_remove_motion_dialog)
	motion_remove_item_dialog = ConfirmationDialog.new()
	motion_remove_item_dialog.ok_button_text = "Remove"
	motion_remove_item_dialog.confirmed.connect(_confirm_motion_item_removal)
	add_child(motion_remove_item_dialog)


func _create_motion_resource_dialogs() -> void:
	motion_path_dialog = ConfirmationDialog.new()
	motion_path_dialog.title = "Create Path"
	motion_path_dialog.dialog_text = "Enter a Path name"
	motion_path_dialog.confirmed.connect(_confirm_motion_path_creation)
	motion_path_name_input = LineEdit.new()
	motion_path_name_input.placeholder_text = "Path name"
	motion_path_name_input.custom_minimum_size = Vector2(320, 32)
	motion_path_name_input.text_submitted.connect(func(_text: String) -> void: _confirm_motion_path_creation())
	motion_path_dialog.add_child(motion_path_name_input)
	add_child(motion_path_dialog)
	motion_sequence_dialog = ConfirmationDialog.new()
	motion_sequence_dialog.title = "Create Sequence"
	motion_sequence_dialog.dialog_text = "Enter a Sequence name"
	motion_sequence_dialog.confirmed.connect(_confirm_motion_sequence_creation)
	motion_sequence_name_input = LineEdit.new()
	motion_sequence_name_input.placeholder_text = "Sequence name"
	motion_sequence_name_input.custom_minimum_size = Vector2(320, 32)
	motion_sequence_name_input.text_submitted.connect(func(_text: String) -> void: _confirm_motion_sequence_creation())
	motion_sequence_dialog.add_child(motion_sequence_name_input)
	add_child(motion_sequence_dialog)


func _confirm_motion_path_creation() -> void:
	var path_name := motion_path_name_input.text.strip_edges()
	if path_name.is_empty():
		path_name = "Path %02d" % next_motion_path_id
	_record_direct_change()
	var path_id := "path_%d" % next_motion_path_id
	next_motion_path_id += 1
	motion_paths.append(_default_motion_path(path_id, path_name))
	selected_motion_path_id = path_id
	motion_path_dialog.hide()
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _confirm_motion_sequence_creation() -> void:
	var sequence_name := motion_sequence_name_input.text.strip_edges()
	if sequence_name.is_empty():
		sequence_name = "Sequence %02d" % next_motion_sequence_id
	_record_direct_change()
	var sequence_id := "sequence_%d" % next_motion_sequence_id
	next_motion_sequence_id += 1
	motion_sequences.append(_default_motion_sequence(sequence_id, sequence_name))
	selected_motion_sequence_id = sequence_id
	selected_motion_sequence_entry_id = ""
	motion_sequence_view = MotionSequenceWorkspace.VIEW_COMPOSITION
	motion_sequence_phase = 0.0
	motion_sequence_playing = false
	motion_sequence_preview_loop = true
	motion_sequence_dialog.hide()
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


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
	section.set_meta("inspector_section", true)
	section.add_theme_constant_override("separation", 0)
	var separator := HSeparator.new()
	separator.modulate = Color("#3a424f")
	section.add_child(separator)
	var header := Button.new()
	header.text = "▾  %s" % text
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.custom_minimum_size = Vector2(0, 24)
	header.focus_mode = Control.FOCUS_NONE
	header.toggle_mode = true
	header.button_pressed = true
	header.flat = true
	header.add_theme_font_size_override("font_size", 10)
	header.add_theme_color_override("font_color", Color("#c0c8d5"))
	header.add_theme_color_override("font_hover_color", Color("#ffffff"))
	header.pressed.connect(_on_inspector_section_toggled.bind(section, text, header))
	section.add_child(header)
	return section


func _on_inspector_section_toggled(section: VBoxContainer, text: String, header: Button) -> void:
	var parent := section.get_parent()
	if parent == null:
		return
	var section_index := section.get_index()
	var expanded := header.button_pressed
	header.text = ("▾  " if expanded else "▸  ") + text
	for sibling_index in range(section_index + 1, parent.get_child_count()):
		var sibling := parent.get_child(sibling_index)
		if sibling is Control and sibling.has_meta("inspector_section"):
			break
		if sibling is Control:
			sibling.visible = expanded


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
	snap_popup.size = Vector2i(250, 230)
	snap_popup.add_theme_stylebox_override("panel", _opaque_popup_style())
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	snap_popup.add_child(content)
	var title := Label.new()
	title.text = "Snap Settings"
	content.add_child(title)
	var grid_mode_label := Label.new()
	grid_mode_label.text = "Snap Mode"
	content.add_child(grid_mode_label)
	var grid_mode_group := ButtonGroup.new()
	snap_mode_buttons.clear()
	var grid_modes := [
		["Coarse", "coarse"],
		["Fine", "fine"]
	]
	for grid_mode in grid_modes:
		var mode_button := CheckBox.new()
		mode_button.text = str(grid_mode[0])
		mode_button.button_group = grid_mode_group
		mode_button.pressed.connect(_on_snap_mode_selected.bind(str(grid_mode[1])))
		content.add_child(mode_button)
		snap_mode_buttons.append(mode_button)
	var snap_grid_info := Label.new()
	snap_grid_info.text = "Fine = 1/5 of Coarse."
	snap_grid_info.add_theme_color_override("font_color", Color("#9aa3b2"))
	content.add_child(snap_grid_info)
	snap_rotation_value_label = Label.new()
	content.add_child(snap_rotation_value_label)
	snap_rotation_slider = _create_snap_slider(1.0, 90.0, 1.0, snap_rotation_step)
	snap_rotation_slider.value_changed.connect(_on_snap_rotation_changed)
	content.add_child(snap_rotation_slider)
	_update_snap_popup_labels()
	add_child(snap_popup)


func _create_world_scale_popup() -> void:
	world_scale_menu = Button.new()
	world_scale_menu.text = "World Scale  ▼"
	world_scale_menu.custom_minimum_size = Vector2(144, 32)
	world_scale_menu.focus_mode = Control.FOCUS_NONE
	world_scale_popup = PopupPanel.new()
	world_scale_popup.size = Vector2i(300, 240)
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color("#20242c")
	popup_style.border_color = Color("#363d48")
	popup_style.set_border_width_all(1)
	world_scale_popup.add_theme_stylebox_override("panel", popup_style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	world_scale_popup.add_child(content)
	var world_unit_label := Label.new()
	world_unit_label.text = "Working Unit"
	content.add_child(world_unit_label)
	world_unit_option = OptionButton.new()
	world_unit_option.add_item("Centimeter (cm)")
	world_unit_option.select(0)
	world_unit_option.disabled = true
	content.add_child(world_unit_option)
	var grid_size_label := Label.new()
	grid_size_label.text = "Grid Size per Tile (cm)"
	content.add_child(grid_size_label)
	world_grid_size_field = SpinBox.new()
	world_grid_size_field.min_value = 0.0001
	world_grid_size_field.max_value = 1000.0
	world_grid_size_field.step = 0.001
	world_grid_size_field.value = world_grid_size
	world_grid_size_field.custom_minimum_size = Vector2(260, 26)
	world_grid_size_field.value_changed.connect(_on_world_grid_size_changed)
	content.add_child(world_grid_size_field)
	world_scale_summary_label = Label.new()
	world_scale_summary_label.add_theme_color_override("font_color", Color("#9aa3b2"))
	content.add_child(world_scale_summary_label)
	world_scale_menu.pressed.connect(_toggle_world_scale_popup)
	add_child(world_scale_popup)
	_update_world_scale_popup()


func _toggle_world_scale_popup() -> void:
	if world_scale_popup.visible:
		world_scale_popup.hide()
		return
	var popup_position := world_scale_menu.get_global_rect().position + Vector2(0.0, world_scale_menu.size.y + 2.0)
	world_scale_popup.popup(Rect2(popup_position, world_scale_popup.size))


func _on_world_grid_size_changed(value: float) -> void:
	world_grid_size = maxf(value, 0.0001)
	_apply_world_scale()


func _apply_world_scale() -> void:
	snap_grid_step = _snap_base_step()
	if is_instance_valid(canvas_view):
		canvas_view.set_snap_settings(snap_enabled, snap_grid_step, snap_rotation_step)
		canvas_view.set_world_scale(world_grid_size)
	_update_world_scale_popup()
	_update_snap_popup_labels()
	_render_canvas_context()


func _update_world_scale_popup() -> void:
	if is_instance_valid(world_grid_size_field):
		world_grid_size_field.set_value_no_signal(world_grid_size)
	if is_instance_valid(world_scale_summary_label):
		var tiles_per_meter := 100.0 / world_grid_size
		world_scale_summary_label.text = "1 Tile = %s cm\n10 cm = 1 m\n1 m = %.0f Tiles" % [_format_scale_value(world_grid_size), tiles_per_meter]


func _format_scale_value(value: float) -> String:
	var formatted := "%.2f" % value
	while formatted.ends_with("0"):
		formatted = formatted.substr(0, formatted.length() - 1)
	if formatted.ends_with("."):
		formatted = formatted.substr(0, formatted.length() - 1)
	return formatted


func _editor_units_to_world(value: float) -> float:
	return value


func _world_to_editor_units(value: float) -> float:
	return value


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
	if is_instance_valid(canvas_view):
		canvas_view.set_snap_settings(snap_enabled, snap_grid_step, snap_rotation_step)
	_update_snap_popup_labels()


func _on_snap_mode_selected(mode: String) -> void:
	_set_snap_mode(mode)


func _set_snap_mode(mode: String) -> void:
	if mode not in ["coarse", "fine"]:
		return
	snap_mode = mode
	snap_enabled = true
	snap_grid_step = _snap_base_step()
	if is_instance_valid(canvas_view):
		canvas_view.set_snap_settings(snap_enabled, snap_grid_step, snap_rotation_step)
	_update_snap_popup_labels()
	_update_context_action_button()


func _snap_base_step() -> float:
	return world_grid_size / 5.0 if snap_mode == "fine" else world_grid_size


func _on_snap_rotation_changed(value: float) -> void:
	snap_rotation_step = value
	canvas_view.set_snap_settings(snap_enabled, snap_grid_step, snap_rotation_step)
	_update_snap_popup_labels()


func _update_snap_popup_labels() -> void:
	if is_instance_valid(snap_button):
		snap_button.text = "Snap: %s  ▼" % _snap_mode_label()
	for mode_index in range(snap_mode_buttons.size()):
		var mode_button := snap_mode_buttons[mode_index]
		var mode: String = ["coarse", "fine"][mode_index]
		mode_button.set_pressed_no_signal(mode == snap_mode)
	if is_instance_valid(snap_rotation_slider):
		snap_rotation_slider.set_value_no_signal(snap_rotation_step)
	if is_instance_valid(snap_rotation_value_label):
		snap_rotation_value_label.text = "Rotation Step: %d°" % int(snap_rotation_step)


func _snap_mode_label() -> String:
	return "Fine" if snap_mode == "fine" else "Coarse"


func _opaque_popup_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#20242c")
	style.border_color = Color("#363d48")
	style.set_border_width_all(1)
	return style


func _style_popup_menu(popup: PopupMenu) -> void:
	popup.add_theme_stylebox_override("panel", _opaque_popup_style())


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
	component_dialog.canceled.connect(_on_component_dialog_canceled)
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


func _create_material_dialog() -> void:
	material_dialog = ConfirmationDialog.new()
	material_dialog.title = "New Material"
	material_dialog.dialog_text = "Enter a material name"
	material_dialog.size = Vector2i(360, 160)
	material_dialog.confirmed.connect(_confirm_material_creation)
	material_name_input = LineEdit.new()
	material_name_input.placeholder_text = "Material name"
	material_name_input.custom_minimum_size = Vector2(320, 32)
	material_name_input.focus_mode = Control.FOCUS_ALL
	material_name_input.text_submitted.connect(_submit_material_name)
	material_dialog.add_child(material_name_input)
	add_child(material_dialog)


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


func _create_reference_image_dialog() -> void:
	reference_image_dialog = FileDialog.new()
	reference_image_dialog.title = "Load Reference Image"
	reference_image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	reference_image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	reference_image_dialog.use_native_dialog = true
	reference_image_dialog.filters = PackedStringArray([
		"*.png, *.jpg, *.jpeg, *.webp ; Image files"
	])
	reference_image_dialog.current_dir = _reference_art_directory()
	reference_image_dialog.file_selected.connect(_on_reference_image_file_selected)
	add_child(reference_image_dialog)


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


func _on_create_action_pressed() -> void:
	if active_module == "Create" and active_create_submodule == "Asset":
		_open_new_asset_dialog()
	elif active_module == "Create" and active_create_submodule == "Texture":
		_open_new_texture_dialog()
	elif active_module == "Style":
		_open_new_material_dialog()
	elif active_module == "Motion" and active_motion_submodule == "Path":
		motion_path_name_input.text = "Path %02d" % next_motion_path_id
		motion_path_dialog.popup_centered()
		motion_path_name_input.select_all()
		motion_path_name_input.grab_focus()
	elif active_module == "Motion" and active_motion_submodule == "Sequence":
		motion_sequence_name_input.text = "Sequence %02d" % next_motion_sequence_id
		motion_sequence_dialog.popup_centered()
		motion_sequence_name_input.select_all()
		motion_sequence_name_input.grab_focus()


func _update_context_action_button() -> void:
	if not is_instance_valid(create_action_button):
		return
	create_action_button.visible = (active_module == "Create" and active_create_submodule in ["Asset", "Texture"]) or active_module == "Style" or (active_module == "Motion" and active_motion_submodule in ["Path", "Sequence"])
	var show_asset_create_controls := active_module == "Create" and active_create_submodule == "Asset"
	if is_instance_valid(snap_button):
		snap_button.visible = show_asset_create_controls
	if is_instance_valid(paper_menu):
		paper_menu.visible = show_asset_create_controls
	if not show_asset_create_controls and is_instance_valid(snap_popup):
		snap_popup.hide()
	if active_module == "Create" and active_create_submodule == "Asset":
		create_action_button.text = "Create Asset"
	elif active_module == "Create" and active_create_submodule == "Texture":
		create_action_button.text = "Create Texture"
	elif active_module == "Style":
		create_action_button.text = "Create Material"
	elif active_module == "Motion" and active_motion_submodule == "Path":
		create_action_button.text = "Create Path"
	elif active_module == "Motion" and active_motion_submodule == "Sequence":
		create_action_button.text = "Create Sequence"


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
	motion_paths.clear()
	motion_acts.clear()
	motion_sequences.clear()
	selected_asset_id = ""
	selected_component_id = ""
	expanded_assets.clear()
	next_asset_id = 1
	next_component_id = 1
	next_texture_id = 1
	next_material_id = 1
	next_motion_path_id = 1
	next_motion_act_id = 1
	next_motion_sequence_id = 1
	selected_motion_path_id = ""
	selected_motion_act_id = ""
	selected_motion_sequence_id = ""
	selected_motion_sequence_entry_id = ""
	motion_path_preview_asset_id = ""
	motion_path_phase = 0.0
	motion_path_playing = false
	motion_path_tool = "draw"
	motion_act_preview_asset_id = ""
	motion_act_phase = 0.0
	motion_act_playing = false
	motion_act_preview_loop = true
	motion_sequence_view = MotionSequenceWorkspace.VIEW_COMPOSITION
	motion_sequence_phase = 0.0
	motion_sequence_playing = false
	motion_sequence_preview_loop = true
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/paths" % workspace_root))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/acts" % workspace_root))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/sequences" % workspace_root))
	var asset_ids: Array[String] = []
	var texture_ids: Array[String] = []
	var material_ids: Array[String] = []
	var motion_path_ids: Array[String] = []
	var motion_act_ids: Array[String] = []
	var motion_sequence_ids: Array[String] = []
	for asset in assets:
		var asset_id := str(asset["id"])
		asset_ids.append(asset_id)
		var asset_root := "%s/assets/%s" % [workspace_root, asset_id]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(asset_root))
		var asset_data := {
			"schema_version": SCHEMA_VERSION,
			"id": asset_id,
			"name": str(asset["name"]),
			"visibility": bool(asset.get("visibility", true)),
			"reference_image": _serialize_reference_image(asset.get("reference_image", {})),
			"animation": MotionWorkspace.normalize_animation_document(asset.get("animation", {})).duplicate(true),
			"components": []
		}
		for component in asset["components"]:
			asset_data["components"].append({
				"id": str(component["id"]),
				"name": str(component["name"]),
				"points": _serialize_bezier_points(component.get("points", [])),
				"edges": _serialize_edges(component.get("edges", [])),
				"chains": _serialize_chains(component.get("chains", [])),
				"transform": _serialize_transform(component.get("transform", {})),
				"visibility": bool(component.get("visibility", true)),
				"z_index": int(component.get("z_index", 0)),
				"material_id": str(component.get("material_id", ""))
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
			"visibility": bool(texture.get("visibility", true)),
			"canvas": {
				"width": int(texture.get("canvas_width", 512)),
				"height": int(texture.get("canvas_height", 512))
			},
			"origin_mode": str(texture.get("origin_mode", "bottom_left")),
			"final_output_element_id": str(texture.get("final_output_element_id", "")),
			"elements": texture.get("elements", []).duplicate(true)
		})
	for material_record in materials:
		var material_id := str(material_record["id"])
		material_ids.append(material_id)
		var material_root := "%s/materials/%s" % [workspace_root, material_id]
		_write_json("%s/material.json" % material_root, {
			"schema_version": SCHEMA_VERSION,
			"id": material_id,
			"name": str(material_record.get("name", material_id)),
			"visibility": bool(material_record.get("visibility", true)),
			"texture_id": str(material_record.get("texture_id", "")),
			"tint": _serialize_color(material_record.get("tint", Color.WHITE)),
			"opacity": clampf(float(material_record.get("opacity", 1.0)), 0.0, 1.0),
			"mapping_scale": _serialize_vector(material_record.get("mapping_scale", Vector2.ONE)),
			"mapping_offset": _serialize_vector(material_record.get("mapping_offset", Vector2.ZERO)),
			"mapping_wrap_mode": str(material_record.get("mapping_wrap_mode", "clamp")),
			"mapping_repeat": bool(material_record.get("mapping_repeat", false))
		})
	for path_document in motion_paths:
		var path_id := str(path_document.get("id", ""))
		motion_path_ids.append(path_id)
		_write_json("%s/paths/%s/path.json" % [workspace_root, path_id], {
			"schema_version": SCHEMA_VERSION,
			"id": path_id,
			"name": str(path_document.get("name", path_id)),
			"visibility": bool(path_document.get("visibility", true)),
			"topology": MotionPathTopology.serialize(path_document.get("topology", {})),
			"playback": path_document.get("playback", {}).duplicate(true)
		})
	for sequence_document in motion_sequences:
		var sequence_id := str(sequence_document.get("id", ""))
		motion_sequence_ids.append(sequence_id)
		_write_json("%s/sequences/%s/sequence.json" % [workspace_root, sequence_id], {
			"schema_version": SCHEMA_VERSION,
			"id": sequence_id,
			"name": str(sequence_document.get("name", sequence_id)),
			"visibility": bool(sequence_document.get("visibility", true)),
			"next_entry_index": int(sequence_document.get("next_entry_index", 1)),
			"entries": sequence_document.get("entries", []).duplicate(true)
		})
	for act_document in motion_acts:
		var act_id := str(act_document.get("id", ""))
		motion_act_ids.append(act_id)
		_write_json("%s/acts/%s/act.json" % [workspace_root, act_id], _serialize_motion_act(act_document))
	_write_json("%s/workspace.json" % workspace_root, {
		"schema_version": SCHEMA_VERSION,
		"name": workspace_name,
		"assets": asset_ids,
		"textures": texture_ids,
		"materials": material_ids,
		"paths": motion_path_ids,
		"acts": motion_act_ids,
		"sequences": motion_sequence_ids,
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
		"motion_paths": motion_paths.duplicate(true),
		"next_motion_path_id": next_motion_path_id,
		"motion_acts": motion_acts.duplicate(true),
		"next_motion_act_id": next_motion_act_id,
		"motion_sequences": motion_sequences.duplicate(true),
		"next_motion_sequence_id": next_motion_sequence_id,
		"selected_asset_id": selected_asset_id,
		"selected_component_id": selected_component_id,
		"selected_texture_id": selected_texture_id,
		"selected_element_id": selected_element_id,
		"selected_material_id": selected_material_id,
		"selected_motion_path_id": selected_motion_path_id,
		"selected_motion_act_id": selected_motion_act_id,
		"selected_motion_sequence_id": selected_motion_sequence_id,
		"selected_motion_sequence_entry_id": selected_motion_sequence_entry_id,
		"motion_path_preview_asset_id": motion_path_preview_asset_id,
		"motion_act_preview_asset_id": motion_act_preview_asset_id,
		"active_module": active_module,
		"active_geometry_submodule": active_geometry_submodule,
		"active_motion_submodule": active_motion_submodule,
		"material_view_mode": material_view_mode,
		"lookdev_target_asset_id": lookdev_target_asset_id,
		"lookdev_target_component_id": lookdev_target_component_id,
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
	# Undo/redo restores document data, not the user's currently selected tool.
	# Keep the interaction state when the same component remains selected.
	var retained_module := active_module
	var retained_component_id := selected_component_id
	var retained_active_state := active_state
	var retained_draw_tool := active_draw_tool
	var retained_draw_point_mode := active_draw_point_mode
	var retained_edit_mode := active_edit_mode
	var retained_edit_handles := edit_bezier_handles
	var retained_edit_point_set_mode := edit_point_set_mode
	var retained_transform_mode := active_transform_mode
	assets = snapshot.get("assets", []).duplicate(true)
	textures = snapshot.get("textures", []).duplicate(true)
	materials = snapshot.get("materials", []).duplicate(true)
	motion_paths = snapshot.get("motion_paths", []).duplicate(true)
	motion_acts = snapshot.get("motion_acts", []).duplicate(true)
	motion_sequences = snapshot.get("motion_sequences", []).duplicate(true)
	next_asset_id = int(snapshot.get("next_asset_id", 1))
	next_component_id = int(snapshot.get("next_component_id", 1))
	next_texture_id = int(snapshot.get("next_texture_id", 1))
	next_material_id = int(snapshot.get("next_material_id", 1))
	next_motion_path_id = int(snapshot.get("next_motion_path_id", 1))
	next_motion_act_id = int(snapshot.get("next_motion_act_id", 1))
	next_motion_sequence_id = int(snapshot.get("next_motion_sequence_id", 1))
	selected_asset_id = str(snapshot.get("selected_asset_id", ""))
	selected_component_id = str(snapshot.get("selected_component_id", ""))
	selected_texture_id = str(snapshot.get("selected_texture_id", ""))
	selected_element_id = str(snapshot.get("selected_element_id", ""))
	selected_material_id = str(snapshot.get("selected_material_id", ""))
	selected_motion_path_id = str(snapshot.get("selected_motion_path_id", ""))
	selected_motion_act_id = str(snapshot.get("selected_motion_act_id", ""))
	selected_motion_sequence_id = str(snapshot.get("selected_motion_sequence_id", ""))
	selected_motion_sequence_entry_id = str(snapshot.get("selected_motion_sequence_entry_id", ""))
	motion_path_preview_asset_id = str(snapshot.get("motion_path_preview_asset_id", ""))
	motion_act_preview_asset_id = str(snapshot.get("motion_act_preview_asset_id", ""))
	active_module = str(snapshot.get("active_module", "Create"))
	active_geometry_submodule = str(snapshot.get("active_geometry_submodule", "Sampling"))
	active_motion_submodule = str(snapshot.get("active_motion_submodule", "Animation"))
	material_view_mode = "graph"
	lookdev_target_asset_id = ""
	lookdev_target_component_id = ""
	expanded_assets = snapshot.get("expanded_assets", {}).duplicate(true)
	if _get_asset(selected_asset_id).is_empty():
		selected_asset_id = ""
		selected_component_id = ""
	elif not selected_component_id.is_empty() and _get_component(_get_asset(selected_asset_id), selected_component_id).is_empty():
		selected_component_id = ""
	if _get_motion_path(selected_motion_path_id).is_empty():
		selected_motion_path_id = ""
	if _get_motion_act(selected_motion_act_id).is_empty():
		selected_motion_act_id = ""
	if _get_motion_sequence(selected_motion_sequence_id).is_empty():
		selected_motion_sequence_id = ""
		selected_motion_sequence_entry_id = ""
	elif _get_motion_sequence_entry(_get_motion_sequence(selected_motion_sequence_id), selected_motion_sequence_entry_id).is_empty():
		selected_motion_sequence_entry_id = str(_first_motion_sequence_entry(_get_motion_sequence(selected_motion_sequence_id)).get("id", ""))
	if _get_asset(motion_path_preview_asset_id).is_empty():
		motion_path_preview_asset_id = _default_motion_path_preview_asset_id()
	if _get_asset(motion_act_preview_asset_id).is_empty():
		motion_act_preview_asset_id = _default_motion_path_preview_asset_id()
	if active_module == "Create":
		_set_create_submodule_context("Texture" if not selected_texture_id.is_empty() else "Asset")
	elif active_module == "Geometry":
		active_geometry_submodule = active_geometry_submodule if active_geometry_submodule in GEOMETRY_SUBMODULES else "Sampling"
		var geometry_section := _find_section("Geometry")
		if geometry_section != null:
			geometry_section.set_expanded(true)
			geometry_section.set_active_submodule(active_geometry_submodule)
	elif active_module == "Motion":
		active_motion_submodule = active_motion_submodule if active_motion_submodule in MOTION_SUBMODULES else "Animation"
		var motion_section := _find_section("Motion")
		if motion_section != null:
			motion_section.set_expanded(true)
			motion_section.set_active_submodule(active_motion_submodule)
	var can_retain_component_tool := retained_module == "Create" \
		and active_module == "Create" \
		and not selected_component_id.is_empty() \
		and selected_component_id == retained_component_id
	if can_retain_component_tool:
		active_state = retained_active_state
		active_draw_tool = retained_draw_tool if retained_active_state == "draw" else ""
		active_draw_point_mode = retained_draw_point_mode
		active_edit_mode = retained_edit_mode
		edit_bezier_handles = retained_edit_handles
		edit_point_set_mode = retained_edit_point_set_mode
		active_transform_mode = retained_transform_mode
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
			var topology := _deserialize_component_topology(component_data)
			components.append({
				"id": str(component_data.get("id", "")),
				"name": str(component_data.get("name", "Component")),
				"points": topology["points"],
				"edges": topology["edges"],
				"chains": topology["chains"],
				"transform": _deserialize_transform(component_data.get("transform", {})),
				"visibility": bool(component_data.get("visibility", true)),
				"z_index": int(component_data.get("z_index", 0)),
				"material_id": str(component_data.get("material_id", ""))
			})
		loaded_assets.append({
			"id": str(asset_data.get("id", asset_id)),
			"name": str(asset_data.get("name", asset_id)),
			"visibility": bool(asset_data.get("visibility", true)),
			"reference_image": _normalize_reference_image(asset_data.get("reference_image", {})),
			"animation": MotionWorkspace.normalize_animation_document(asset_data.get("animation", {})),
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
			"visibility": bool(texture_data.get("visibility", true)),
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
	var loaded_motion_paths: Array[Dictionary] = []
	for path_id_variant in workspace_data.get("paths", []):
		var path_id := str(path_id_variant)
		var path_data = _read_json("%s/paths/%s/path.json" % [workspace_root, path_id])
		if _has_supported_schema(path_data):
			loaded_motion_paths.append(_normalize_motion_path(path_data, path_id))
	var loaded_motion_sequences: Array[Dictionary] = []
	for sequence_id_variant in workspace_data.get("sequences", []):
		var sequence_id := str(sequence_id_variant)
		var sequence_data = _read_json("%s/sequences/%s/sequence.json" % [workspace_root, sequence_id])
		if _has_supported_schema(sequence_data):
			loaded_motion_sequences.append(_normalize_motion_sequence(sequence_data, sequence_id))
	var loaded_motion_acts: Array[Dictionary] = []
	for act_id_variant in workspace_data.get("acts", []):
		var act_id := str(act_id_variant)
		var act_data = _read_json("%s/acts/%s/act.json" % [workspace_root, act_id])
		if _has_supported_schema(act_data):
			loaded_motion_acts.append(_normalize_motion_act(act_data, act_id))
	assets = loaded_assets
	textures = loaded_textures
	materials = loaded_materials
	motion_paths = loaded_motion_paths
	motion_acts = loaded_motion_acts
	motion_sequences = loaded_motion_sequences
	var saved_editor_state = workspace_data.get("editor_state", {})
	if saved_editor_state is Dictionary and str(saved_editor_state.get("world_scale", {}).get("unit", "")) == "m":
		_convert_asset_units(assets, 100.0)
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
	var camera_state := {}
	if is_instance_valid(canvas_view):
		var current_camera := canvas_view.get_camera_state()
		camera_state = {
			"position": _serialize_vector(current_camera.get("position", Vector2.ZERO)),
			"zoom": float(current_camera.get("zoom", 1.0))
		}
	return {
		"selected_asset_id": selected_asset_id,
		"selected_component_id": selected_component_id,
		"selected_texture_id": selected_texture_id,
		"selected_element_id": selected_element_id,
		"selected_material_id": selected_material_id,
		"selected_motion_path_id": selected_motion_path_id,
		"selected_motion_act_id": selected_motion_act_id,
		"selected_motion_sequence_id": selected_motion_sequence_id,
		"selected_motion_sequence_entry_id": selected_motion_sequence_entry_id,
		"motion_path_preview_asset_id": motion_path_preview_asset_id,
		"motion_act_preview_asset_id": motion_act_preview_asset_id,
		"motion_act_preview_loop": motion_act_preview_loop,
		"motion_sequence_view": motion_sequence_view,
		"motion_sequence_preview_loop": motion_sequence_preview_loop,
		"active_module": active_module,
		"active_geometry_submodule": active_geometry_submodule,
		"active_motion_submodule": active_motion_submodule,
		"material_view_mode": material_view_mode,
		"lookdev_target_asset_id": lookdev_target_asset_id,
		"lookdev_target_component_id": lookdev_target_component_id,
		"expanded_assets": expanded_state,
		"expanded_textures": expanded_textures.duplicate(true),
		"camera": camera_state,
		"paper_level": paper_level,
		"world_scale": {
			"unit": world_unit,
			"grid_size": world_grid_size
		},
		"snap": {
			"enabled": snap_enabled,
			"mode": snap_mode,
			"grid_step": snap_grid_step,
			"rotation_step": snap_rotation_step
		}
	}


func _restore_editor_state(state) -> void:
	selected_asset_id = ""
	selected_component_id = ""
	selected_texture_id = ""
	selected_element_id = ""
	selected_material_id = ""
	selected_motion_path_id = ""
	selected_motion_act_id = ""
	selected_motion_sequence_id = ""
	selected_motion_sequence_entry_id = ""
	motion_path_preview_asset_id = ""
	motion_act_preview_asset_id = ""
	motion_act_preview_loop = true
	motion_sequence_view = MotionSequenceWorkspace.VIEW_COMPOSITION
	motion_sequence_preview_loop = true
	active_module = "Create"
	active_geometry_submodule = "Sampling"
	active_motion_submodule = "Animation"
	material_view_mode = "graph"
	lookdev_target_asset_id = ""
	lookdev_target_component_id = ""
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
	var requested_material_id := str(state.get("selected_material_id", ""))
	if selected_asset_id.is_empty() and selected_texture_id.is_empty() and not _get_material(requested_material_id).is_empty():
		selected_material_id = requested_material_id
		active_module = "Style"
		var style_section := _find_section("Style")
		if style_section != null:
			style_section.set_expanded(true)
			style_section.set_active_submodule("Material")
	else:
		active_module = "Create"
		_set_create_submodule_context("Texture" if not selected_texture_id.is_empty() else "Asset")
	var requested_motion_submodule := str(state.get("active_motion_submodule", "Animation"))
	var requested_geometry_submodule := str(state.get("active_geometry_submodule", "Sampling"))
	if str(state.get("active_module", "")) == "Geometry" and requested_geometry_submodule in GEOMETRY_SUBMODULES:
		active_module = "Geometry"
		active_geometry_submodule = requested_geometry_submodule
		var geometry_section := _find_section("Geometry")
		if geometry_section != null:
			geometry_section.set_expanded(true)
			geometry_section.set_active_submodule(active_geometry_submodule)
	if str(state.get("active_module", "")) == "Motion" and requested_motion_submodule in MOTION_SUBMODULES:
		active_module = "Motion"
		active_motion_submodule = requested_motion_submodule
		var requested_path_id := str(state.get("selected_motion_path_id", ""))
		var requested_act_id := str(state.get("selected_motion_act_id", ""))
		var requested_sequence_id := str(state.get("selected_motion_sequence_id", ""))
		selected_motion_path_id = requested_path_id if not _get_motion_path(requested_path_id).is_empty() else ""
		selected_motion_act_id = requested_act_id if not _get_motion_act(requested_act_id).is_empty() else ""
		selected_motion_sequence_id = requested_sequence_id if not _get_motion_sequence(requested_sequence_id).is_empty() else ""
		var requested_sequence_entry_id := str(state.get("selected_motion_sequence_entry_id", ""))
		selected_motion_sequence_entry_id = requested_sequence_entry_id if not _get_motion_sequence_entry(_get_motion_sequence(selected_motion_sequence_id), requested_sequence_entry_id).is_empty() else str(_first_motion_sequence_entry(_get_motion_sequence(selected_motion_sequence_id)).get("id", ""))
		motion_sequence_view = str(state.get("motion_sequence_view", MotionSequenceWorkspace.VIEW_COMPOSITION))
		if motion_sequence_view not in [MotionSequenceWorkspace.VIEW_COMPOSITION, MotionSequenceWorkspace.VIEW_PLAYER]:
			motion_sequence_view = MotionSequenceWorkspace.VIEW_COMPOSITION
		motion_sequence_preview_loop = bool(state.get("motion_sequence_preview_loop", true))
		motion_act_preview_loop = bool(state.get("motion_act_preview_loop", true))
		var requested_preview_asset_id := str(state.get("motion_path_preview_asset_id", ""))
		motion_path_preview_asset_id = requested_preview_asset_id if not _get_asset(requested_preview_asset_id).is_empty() else _default_motion_path_preview_asset_id()
		var requested_act_preview_asset_id := str(state.get("motion_act_preview_asset_id", ""))
		motion_act_preview_asset_id = requested_act_preview_asset_id if not _get_asset(requested_act_preview_asset_id).is_empty() else _default_motion_path_preview_asset_id()
		var motion_section := _find_section("Motion")
		if motion_section != null:
			motion_section.set_expanded(true)
			motion_section.set_active_submodule(active_motion_submodule)
	# Older editor_state files may contain View/LookDev fields. They are read
	# only for compatibility; the current workflow always opens the Graph.
	material_view_mode = "graph"
	lookdev_target_asset_id = ""
	lookdev_target_component_id = ""
	var saved_expanded_textures = state.get("expanded_textures", {})
	if saved_expanded_textures is Dictionary:
		for texture in textures:
			var texture_id := str(texture["id"])
			if saved_expanded_textures.has(texture_id):
				expanded_textures[texture_id] = bool(saved_expanded_textures[texture_id])
	_apply_world_scale_settings(state.get("world_scale", {}))
	paper_level = clampi(int(state.get("paper_level", 0)), PAPER_NONE_LEVEL, PAPER_SIZES_CM.size() - 1)
	_apply_snap_settings(state.get("snap", {}))
	var saved_camera = state.get("camera", {})
	if saved_camera is Dictionary and not saved_camera.is_empty() and is_instance_valid(canvas_view):
		var camera_position := _deserialize_vector(saved_camera.get("position", [0.0, 0.0]), Vector2.ZERO)
		var camera_zoom := clampf(float(saved_camera.get("zoom", 1.0)), 0.25, 1024.0)
		canvas_view.set_camera_state(camera_position, camera_zoom)


func _apply_world_scale_settings(settings) -> void:
	if settings is Dictionary:
		var saved_unit := str(settings.get("unit", "cm"))
		if saved_unit == "m":
			world_unit = "cm"
			world_grid_size = 0.5
		else:
			world_unit = "cm"
			world_grid_size = maxf(float(settings.get("grid_size", 0.5)), 0.0001)
	else:
		world_unit = "cm"
		world_grid_size = 0.5
	_apply_world_scale()


func _convert_asset_units(loaded_assets: Array[Dictionary], conversion_factor: float) -> void:
	for asset in loaded_assets:
		var reference_image := _normalize_reference_image(asset.get("reference_image", {}))
		var reference_position: Vector2 = reference_image.get("position", Vector2.ZERO)
		reference_position *= conversion_factor
		reference_image["position"] = reference_position
		reference_image["scale"] = float(reference_image.get("scale", 1.0)) * conversion_factor
		asset["reference_image"] = reference_image
		for component in asset.get("components", []):
			for bezier_point in component.get("points", []):
				if not bezier_point is Dictionary:
					continue
				bezier_point["position"] = Vector2(bezier_point.get("position", Vector2.ZERO)) * conversion_factor
				bezier_point["handle_in"] = Vector2(bezier_point.get("handle_in", Vector2.ZERO)) * conversion_factor
				bezier_point["handle_out"] = Vector2(bezier_point.get("handle_out", Vector2.ZERO)) * conversion_factor
			var transform: Dictionary = component.get("transform", _default_component_transform()).duplicate(true)
			var transform_position: Vector2 = transform.get("position", Vector2.ZERO)
			var transform_pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
			transform["position"] = transform_position * conversion_factor
			transform["pivot"] = transform_pivot * conversion_factor
			component["transform"] = transform


func _apply_snap_settings(settings) -> void:
	if settings is Dictionary:
		snap_enabled = bool(settings.get("enabled", true))
		snap_mode = str(settings.get("mode", "coarse"))
		snap_rotation_step = clampf(float(settings.get("rotation_step", 15.0)), 1.0, 90.0)
	else:
		snap_enabled = true
		snap_mode = "coarse"
		snap_rotation_step = 15.0
	if snap_mode in ["fine_on", "fine_off"]:
		snap_mode = "fine"
	elif snap_mode not in ["coarse", "fine"]:
		snap_mode = "coarse"
	# Coarse/Fine are now the two active snap modes. Restore the mode and the
	# runtime snap state together so the UI cannot show Fine while the canvas
	# still has snapping disabled.
	snap_enabled = true
	snap_grid_step = _snap_base_step()
	if is_instance_valid(canvas_view):
		canvas_view.set_snap_settings(snap_enabled, snap_grid_step, snap_rotation_step)
		canvas_view.set_world_scale(world_grid_size)
	_update_snap_popup_labels()


func _serialize_bezier_points(points: Array) -> Array:
	var serialized: Array = []
	for point_data in points:
		if not point_data is Dictionary:
			continue
		var point: Vector2 = point_data.get("position", Vector2.ZERO)
		var handle_in: Vector2 = point_data.get("handle_in", Vector2.ZERO)
		var handle_out: Vector2 = point_data.get("handle_out", Vector2.ZERO)
		serialized.append({
			"id": str(point_data.get("id", "")),
			"position": _serialize_vector(point),
			"mode": str(point_data.get("mode", "linear")),
			"preserve_point": bool(point_data.get("preserve_point", false)),
			"handle_source": str(point_data.get("handle_source", "auto")),
			"handle_in": _serialize_vector(handle_in),
			"handle_out": _serialize_vector(handle_out)
		})
	return serialized


func _serialize_edges(edges: Array) -> Array:
	var serialized: Array = []
	for edge_data in edges:
		if not edge_data is Dictionary:
			continue
		serialized.append({
			"id": str(edge_data.get("id", "")),
			"start_point_id": str(edge_data.get("start_point_id", "")),
			"end_point_id": str(edge_data.get("end_point_id", "")),
			"render_outline": bool(edge_data.get("render_outline", true))
		})
	return serialized


func _serialize_chains(chains: Array) -> Array:
	var serialized: Array = []
	for chain_data in chains:
		if not chain_data is Dictionary:
			continue
		serialized.append({
			"id": str(chain_data.get("id", "")),
			"point_ids": chain_data.get("point_ids", []).duplicate(),
			"edge_ids": chain_data.get("edge_ids", []).duplicate(),
			"closed": bool(chain_data.get("closed", false)),
			"topology_role": str(chain_data.get("topology_role", "outer"))
		})
	return serialized


func _deserialize_component_topology(component_data: Dictionary) -> Dictionary:
	var raw_points = component_data.get("points", [])
	var raw_edges = component_data.get("edges", [])
	var raw_chains = component_data.get("chains", [])
	if not raw_points is Array or not raw_edges is Array or not raw_chains is Array:
		return {"points": [], "edges": [], "chains": []}
	var points: Array[Dictionary] = []
	var known_point_ids: Dictionary = {}
	for raw_point in raw_points:
		if not raw_point is Dictionary:
			continue
		var point_id := str(raw_point.get("id", ""))
		if point_id.is_empty() or known_point_ids.has(point_id):
			continue
		var point_mode := str(raw_point.get("mode", "linear"))
		if point_mode not in BezierTopology.VALID_POINT_MODES:
			point_mode = "linear"
		points.append({
			"id": point_id,
			"position": _deserialize_vector(raw_point.get("position", [0.0, 0.0]), Vector2.ZERO),
			"mode": point_mode,
			"preserve_point": bool(raw_point.get("preserve_point", point_mode == "corner")),
			"handle_source": "manual" if str(raw_point.get("handle_source", "auto")) == "manual" else "auto",
			"handle_in": _deserialize_vector(raw_point.get("handle_in", [0.0, 0.0]), Vector2.ZERO),
			"handle_out": _deserialize_vector(raw_point.get("handle_out", [0.0, 0.0]), Vector2.ZERO)
		})
		known_point_ids[point_id] = true
	var edges: Array[Dictionary] = []
	var known_edge_ids: Dictionary = {}
	for raw_edge in raw_edges:
		if not raw_edge is Dictionary:
			continue
		var edge_id := str(raw_edge.get("id", ""))
		var start_point_id := str(raw_edge.get("start_point_id", ""))
		var end_point_id := str(raw_edge.get("end_point_id", ""))
		if edge_id.is_empty() or known_edge_ids.has(edge_id) or not known_point_ids.has(start_point_id) or not known_point_ids.has(end_point_id) or start_point_id == end_point_id:
			continue
		edges.append({
			"id": edge_id,
			"start_point_id": start_point_id,
			"end_point_id": end_point_id,
			"render_outline": bool(raw_edge.get("render_outline", true))
		})
		known_edge_ids[edge_id] = true
	var chains: Array[Dictionary] = []
	for raw_chain in raw_chains:
		if not raw_chain is Dictionary:
			continue
		var point_ids: Array = []
		for point_id_value in raw_chain.get("point_ids", []):
			var point_id := str(point_id_value)
			if known_point_ids.has(point_id):
				point_ids.append(point_id)
		if point_ids.is_empty():
			continue
		var edge_ids: Array = []
		for edge_id_value in raw_chain.get("edge_ids", []):
			var edge_id := str(edge_id_value)
			if known_edge_ids.has(edge_id):
				edge_ids.append(edge_id)
		var topology_role := str(raw_chain.get("topology_role", "outer"))
		if topology_role not in BezierTopology.VALID_TOPOLOGY_ROLES:
			topology_role = "outer"
		chains.append({
			"id": str(raw_chain.get("id", "chain_%d" % (chains.size() + 1))),
			"point_ids": point_ids,
			"edge_ids": edge_ids,
			"closed": bool(raw_chain.get("closed", false)) and point_ids.size() >= 3,
			"topology_role": topology_role
		})
	BezierGeometry.resolve_auto_handles(points, chains)
	return {"points": points, "edges": edges, "chains": chains}


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


func _default_reference_image() -> Dictionary:
	return {
		"file": "",
		"visible": true,
		"opacity": 0.5,
		"position": Vector2.ZERO,
		"scale": 1.0,
		"target_height_cm": 13.0,
		"pivot_mode": "bottom_center"
	}


func _normalize_reference_image(raw_reference) -> Dictionary:
	var result := _default_reference_image()
	if not raw_reference is Dictionary:
		return result
	result["file"] = str(raw_reference.get("file", "")).get_file()
	result["visible"] = bool(raw_reference.get("visible", true))
	result["opacity"] = clampf(float(raw_reference.get("opacity", 0.5)), 0.0, 1.0)
	result["position"] = _deserialize_vector(raw_reference.get("position", [0.0, 0.0]), Vector2.ZERO)
	result["scale"] = maxf(float(raw_reference.get("scale", 1.0)), 0.01)
	result["target_height_cm"] = maxf(float(raw_reference.get("target_height_cm", 13.0)), 0.01)
	result["pivot_mode"] = "center" if str(raw_reference.get("pivot_mode", "bottom_center")) == "center" else "bottom_center"
	return result


func _serialize_reference_image(raw_reference) -> Dictionary:
	var normalized := _normalize_reference_image(raw_reference)
	return {
		"file": str(normalized["file"]),
		"visible": bool(normalized["visible"]),
		"opacity": float(normalized["opacity"]),
		"position": _serialize_vector(normalized["position"]),
		"scale": float(normalized["scale"]),
		"target_height_cm": float(normalized["target_height_cm"]),
		"pivot_mode": str(normalized["pivot_mode"])
	}


func _reference_image_path(asset: Dictionary) -> String:
	var reference_image := _normalize_reference_image(asset.get("reference_image", {}))
	var reference_file := str(reference_image.get("file", ""))
	if workspace_name.is_empty() or reference_file.is_empty():
		return ""
	return "%s/%s/assets/%s/%s" % [WORKSPACES_ROOT, workspace_name, str(asset.get("id", "")), reference_file]


func _reference_image_filename(asset: Dictionary) -> String:
	var safe_name := str(asset.get("name", asset.get("id", "asset"))).strip_edges().to_lower().replace(" ", "_")
	for character in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		safe_name = safe_name.replace(character, "_")
	if safe_name.is_empty():
		safe_name = str(asset.get("id", "asset"))
	return "%s_ref.png" % safe_name


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
	next_material_id = 1
	next_motion_path_id = 1
	next_motion_act_id = 1
	next_motion_sequence_id = 1
	for asset in assets:
		next_asset_id = maxi(next_asset_id, _id_suffix_number(str(asset["id"])) + 1)
		for component in asset["components"]:
			next_component_id = maxi(next_component_id, _id_suffix_number(str(component["id"])) + 1)
	for texture in textures:
		next_texture_id = maxi(next_texture_id, _id_suffix_number(str(texture["id"])) + 1)
	for material_record in materials:
		next_material_id = maxi(next_material_id, _id_suffix_number(str(material_record["id"])) + 1)
	for path_document in motion_paths:
		next_motion_path_id = maxi(next_motion_path_id, _id_suffix_number(str(path_document.get("id", ""))) + 1)
	for act_document in motion_acts:
		next_motion_act_id = maxi(next_motion_act_id, _id_suffix_number(str(act_document.get("id", ""))) + 1)
	for sequence_document in motion_sequences:
		next_motion_sequence_id = maxi(next_motion_sequence_id, _id_suffix_number(str(sequence_document.get("id", ""))) + 1)


func _id_suffix_number(identifier: String) -> int:
	var suffix := identifier.get_slice("_", identifier.get_slice_count("_") - 1)
	return suffix.to_int()


func _create_paper_menu() -> MenuButton:
	paper_menu = MenuButton.new()
	paper_menu.text = "Paper: %s  ▼" % _paper_label()
	paper_menu.custom_minimum_size = Vector2(118, 32)
	paper_menu.focus_mode = Control.FOCUS_NONE
	var paper_popup := paper_menu.get_popup()
	_style_popup_menu(paper_popup)
	paper_popup.add_item(PAPER_NONE_LABEL, PAPER_NONE_LEVEL)
	for paper_index in range(PAPER_LABELS.size()):
		paper_popup.add_item(PAPER_LABELS[paper_index], paper_index)
	paper_popup.id_pressed.connect(_on_paper_size_id)
	return paper_menu


func _on_paper_size_id(id: int) -> void:
	if id == PAPER_NONE_LEVEL:
		paper_level = PAPER_NONE_LEVEL
		_render_context_bar()
		_render_canvas_context()
		return
	if id < 0 or id >= PAPER_SIZES_CM.size():
		return
	paper_level = id
	_render_context_bar()
	_render_canvas_context()


func _paper_label() -> String:
	return PAPER_NONE_LABEL if paper_level == PAPER_NONE_LEVEL else PAPER_LABELS[paper_level]


func _paper_frame_size(level: int) -> Vector2:
	var din_size: Vector2 = PAPER_SIZES_CM[level]
	var doubled_short_side := minf(din_size.x, din_size.y) * 2.0
	return Vector2(doubled_short_side, doubled_short_side)


func _render_context_bar() -> void:
	if not is_instance_valid(context_bar):
		return
	_update_context_action_button()
	_clear(context_bar)
	if active_module == "Export":
		var validate_button := Button.new()
		validate_button.text = "Validate"
		validate_button.custom_minimum_size = Vector2(92, 32)
		validate_button.focus_mode = Control.FOCUS_NONE
		validate_button.pressed.connect(_validate_selected_export_asset)
		context_bar.add_child(validate_button)
		var build_button := Button.new()
		build_button.text = "Build Godot Scene"
		build_button.custom_minimum_size = Vector2(144, 32)
		build_button.focus_mode = Control.FOCUS_NONE
		build_button.disabled = not _export_validation_errors(_get_asset(selected_asset_id)).is_empty()
		build_button.pressed.connect(_build_selected_asset_scene)
		context_bar.add_child(build_button)
		_render_info_bar()
		return
	if active_module == "Motion":
		if active_motion_submodule == "Animation":
			_render_motion_context_bar()
		elif active_motion_submodule == "Path":
			_render_motion_path_context_bar()
		elif active_motion_submodule == "Act":
			_render_motion_act_context_bar()
		elif active_motion_submodule == "Sequence":
			_render_motion_sequence_context_bar()
		else:
			var module_label := Label.new()
			module_label.text = "Motion → %s" % active_motion_submodule
			module_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			module_label.add_theme_color_override("font_color", Color("#9aa3b2"))
			context_bar.add_child(module_label)
			var boundary_label := Label.new()
			boundary_label.text = "Drawing tools · Phase 11" if active_motion_submodule == "Path" else "Composition controls · Phase 12"
			boundary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			boundary_label.add_theme_color_override("font_color", Color("#596474"))
			context_bar.add_child(boundary_label)
		_render_info_bar()
		return
	if active_module == "Geometry":
		var geometry_label := Label.new()
		geometry_label.text = "Geometry → %s" % active_geometry_submodule
		geometry_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		geometry_label.add_theme_color_override("font_color", Color("#9aa3b2"))
		context_bar.add_child(geometry_label)
		var geometry_phase_label := Label.new()
		geometry_phase_label.text = "Placeholder · Geometry pipeline"
		geometry_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		geometry_phase_label.add_theme_color_override("font_color", Color("#596474"))
		context_bar.add_child(geometry_phase_label)
		_render_info_bar()
		return
	if active_module == "Style" and not selected_material_id.is_empty():
		_render_material_context_bar()
		_render_info_bar()
		return
	if not selected_texture_id.is_empty():
		_render_texture_context_bar()
		_render_info_bar()
		return
	if active_module == "Create" and active_create_submodule == "Texture":
		_render_info_bar()
		return
	if selected_component_id.is_empty():
		active_draw_tool = ""
		_render_info_bar()
		return
	var draw_menu := MenuButton.new()
	draw_menu.text = "⌘1  Draw Point  ▼"
	draw_menu.custom_minimum_size = Vector2(156, 32)
	draw_menu.focus_mode = Control.FOCUS_NONE
	draw_menu.toggle_mode = true
	draw_menu.button_pressed = active_state == "draw"
	draw_menu.get_popup().add_item("1: Linear", 0)
	draw_menu.get_popup().add_item("2: Aligned", 1)
	draw_menu.get_popup().add_item("3: Free", 2)
	draw_menu.get_popup().add_item("4: Mirrored", 3)
	draw_menu.get_popup().add_item("5: Corner", 4)
	_style_popup_menu(draw_menu.get_popup())
	draw_menu.get_popup().id_pressed.connect(_on_draw_menu_id)
	context_bar.add_child(draw_menu)
	var edit_point_menu := MenuButton.new()
	edit_point_menu.text = "⌘2  Edit Point  ▼"
	edit_point_menu.custom_minimum_size = Vector2(138, 32)
	edit_point_menu.focus_mode = Control.FOCUS_NONE
	edit_point_menu.toggle_mode = true
	edit_point_menu.button_pressed = active_state == "edit" and active_edit_mode == "point"
	edit_point_menu.get_popup().add_item("1: Select", 0)
	edit_point_menu.get_popup().add_item("2: Bezier Handle", 1)
	edit_point_menu.get_popup().add_item("3: Set", 2)
	_style_popup_menu(edit_point_menu.get_popup())
	edit_point_menu.get_popup().id_pressed.connect(_on_edit_menu_id)
	context_bar.add_child(edit_point_menu)
	var edit_edge_menu := MenuButton.new()
	edit_edge_menu.text = "⌘3  Edit Edge  ▼"
	edit_edge_menu.custom_minimum_size = Vector2(136, 32)
	edit_edge_menu.focus_mode = Control.FOCUS_NONE
	edit_edge_menu.toggle_mode = true
	edit_edge_menu.button_pressed = active_state == "edit" and active_edit_mode == "edge"
	edit_edge_menu.get_popup().add_item("Select Edge", 0)
	_style_popup_menu(edit_edge_menu.get_popup())
	edit_edge_menu.get_popup().id_pressed.connect(_on_edit_edge_menu_id)
	context_bar.add_child(edit_edge_menu)
	var edit_face_menu := MenuButton.new()
	edit_face_menu.text = "⌘4  Edit Face  ▼"
	edit_face_menu.custom_minimum_size = Vector2(134, 32)
	edit_face_menu.focus_mode = Control.FOCUS_NONE
	edit_face_menu.toggle_mode = true
	edit_face_menu.button_pressed = active_state == "edit" and active_edit_mode == "face"
	edit_face_menu.get_popup().add_item("Move Face", 0)
	_style_popup_menu(edit_face_menu.get_popup())
	edit_face_menu.get_popup().id_pressed.connect(_on_edit_face_menu_id)
	context_bar.add_child(edit_face_menu)


func _render_motion_context_bar() -> void:
	motion_play_button = Button.new()
	motion_play_button.text = "❚❚" if motion_player != null and motion_player.playing else "▶"
	motion_play_button.custom_minimum_size = Vector2(40, 32)
	motion_play_button.focus_mode = Control.FOCUS_NONE
	motion_play_button.disabled = motion_player == null or motion_player.current_state_id.is_empty()
	motion_play_button.tooltip_text = "Pause Animation Preview" if motion_player != null and motion_player.playing else "Play Animation Preview"
	motion_play_button.pressed.connect(_toggle_motion_playback)
	context_bar.add_child(motion_play_button)
	motion_runtime_state_label = Label.new()
	motion_runtime_state_label.text = motion_player.current_state_name() if motion_player != null else "None"
	motion_runtime_state_label.custom_minimum_size = Vector2(72, 32)
	motion_runtime_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	motion_runtime_state_label.add_theme_font_size_override("font_size", 11)
	motion_runtime_state_label.add_theme_color_override("font_color", Color("#f2c94c"))
	context_bar.add_child(motion_runtime_state_label)
	var phase_label := Label.new()
	phase_label.text = "Phase"
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 11)
	phase_label.add_theme_color_override("font_color", Color("#9aa3b2"))
	context_bar.add_child(phase_label)
	var phase_stack := VBoxContainer.new()
	phase_stack.custom_minimum_size = Vector2(220, 32)
	phase_stack.add_theme_constant_override("separation", 0)
	context_bar.add_child(phase_stack)
	motion_phase_slider = HSlider.new()
	motion_phase_slider.min_value = 0.0
	motion_phase_slider.max_value = 1.0
	motion_phase_slider.step = 0.01
	motion_phase_slider.custom_minimum_size = Vector2(220, 22)
	motion_phase_slider.set_value_no_signal(motion_phase)
	motion_phase_slider.value_changed.connect(_on_motion_phase_changed)
	phase_stack.add_child(motion_phase_slider)
	motion_phase_marks = MotionPhaseMarks.new()
	var marker_state_id := motion_player.current_state_id if motion_player != null else motion_selection.state_id
	motion_phase_marks.set_marker_phases(motion_workspace.marker_phases_for_state(marker_state_id) if is_instance_valid(motion_workspace) else [])
	phase_stack.add_child(motion_phase_marks)
	motion_phase_value_label = Label.new()
	motion_phase_value_label.text = "%.2f" % motion_phase
	motion_phase_value_label.custom_minimum_size = Vector2(42, 32)
	motion_phase_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	motion_phase_value_label.add_theme_font_size_override("font_size", 11)
	context_bar.add_child(motion_phase_value_label)
	var loop_toggle := CheckBox.new()
	loop_toggle.text = "Loop"
	loop_toggle.button_pressed = motion_player.loop if motion_player != null else true
	loop_toggle.disabled = motion_player == null
	loop_toggle.toggled.connect(_on_motion_loop_changed)
	context_bar.add_child(loop_toggle)


func _on_motion_phase_changed(value: float) -> void:
	if motion_player != null:
		motion_player.seek(value)
	else:
		_on_motion_player_phase_changed(value)


func _toggle_motion_playback() -> void:
	if motion_player != null:
		motion_player.toggle_playback()


func _on_motion_loop_changed(enabled: bool) -> void:
	if motion_player != null:
		motion_player.loop = enabled


func _render_motion_path_context_bar() -> void:
	var path_document := _get_motion_path(selected_motion_path_id)
	var draw_button := Button.new()
	draw_button.text = "Draw Path"
	draw_button.toggle_mode = true
	draw_button.button_pressed = motion_path_tool == "draw"
	draw_button.disabled = path_document.is_empty()
	draw_button.pressed.connect(_set_motion_path_tool.bind("draw"))
	context_bar.add_child(draw_button)
	var edit_button := Button.new()
	edit_button.text = "Edit Path"
	edit_button.toggle_mode = true
	edit_button.button_pressed = motion_path_tool == "edit"
	edit_button.disabled = path_document.is_empty()
	edit_button.pressed.connect(_set_motion_path_tool.bind("edit"))
	context_bar.add_child(edit_button)
	var play_button := Button.new()
	play_button.text = "❚❚" if motion_path_playing else "▶"
	play_button.custom_minimum_size = Vector2(40, 32)
	play_button.disabled = not _motion_path_is_previewable(path_document)
	play_button.pressed.connect(_toggle_motion_path_playback)
	context_bar.add_child(play_button)
	var phase_label := Label.new()
	phase_label.text = "Phase"
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	context_bar.add_child(phase_label)
	motion_path_phase_slider = HSlider.new()
	motion_path_phase_slider.min_value = 0.0
	motion_path_phase_slider.max_value = 1.0
	motion_path_phase_slider.step = 0.001
	motion_path_phase_slider.custom_minimum_size = Vector2(240, 28)
	motion_path_phase_slider.set_value_no_signal(motion_path_phase)
	motion_path_phase_slider.value_changed.connect(_on_motion_path_phase_changed)
	context_bar.add_child(motion_path_phase_slider)
	motion_path_phase_value_label = Label.new()
	motion_path_phase_value_label.text = "%.2f" % motion_path_phase
	motion_path_phase_value_label.custom_minimum_size = Vector2(42, 32)
	motion_path_phase_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	context_bar.add_child(motion_path_phase_value_label)


func _set_motion_path_tool(value: String) -> void:
	motion_path_tool = value if value in ["draw", "edit"] else "draw"
	if is_instance_valid(motion_path_workspace):
		motion_path_workspace.set_tool_mode(motion_path_tool)
	_render_context_bar()
	_render_info_bar()


func _toggle_motion_path_playback() -> void:
	var path_document := _get_motion_path(selected_motion_path_id)
	if not _motion_path_is_previewable(path_document):
		return
	if not motion_path_playing and motion_path_phase >= 1.0:
		motion_path_phase = 0.0
	motion_path_playing = not motion_path_playing
	_render_context_bar()
	_render_info_bar()
	_refresh_motion_path_workspace()


func _on_motion_path_phase_changed(value: float) -> void:
	motion_path_phase = clampf(value, 0.0, 1.0)
	_refresh_motion_path_workspace()
	_render_info_bar()


func _advance_motion_path_preview(delta: float) -> void:
	var path_document := _get_motion_path(selected_motion_path_id)
	if not _motion_path_is_previewable(path_document):
		motion_path_playing = false
		return
	var playback: Dictionary = path_document.get("playback", {})
	var duration := maxf(0.01, float(playback.get("duration", 2.0)))
	motion_path_phase += delta / duration
	if motion_path_phase >= 1.0:
		if bool(playback.get("loop", true)):
			motion_path_phase = fmod(motion_path_phase, 1.0)
		else:
			motion_path_phase = 1.0
			motion_path_playing = false
			_render_context_bar()
	_refresh_motion_path_workspace()


func _motion_path_is_previewable(path_document: Dictionary) -> bool:
	if path_document.is_empty() or not MotionPathTopology.validate(path_document.get("topology", {})).is_empty() or _get_asset(motion_path_preview_asset_id).is_empty():
		return false
	return bool(MotionPathSampler.sample(path_document.get("topology", {}), 0.5).get("valid", false))


func _render_motion_act_context_bar() -> void:
	var act := _get_motion_act(selected_motion_act_id)
	var play_button := Button.new()
	play_button.text = "❚❚" if motion_act_playing else "▶"
	play_button.custom_minimum_size = Vector2(40, 32)
	play_button.disabled = not _motion_act_is_previewable(act)
	play_button.pressed.connect(_toggle_motion_act_playback)
	context_bar.add_child(play_button)
	var phase_label := Label.new()
	phase_label.text = "Phase"
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	context_bar.add_child(phase_label)
	motion_act_phase_slider = HSlider.new()
	motion_act_phase_slider.min_value = 0.0
	motion_act_phase_slider.max_value = 1.0
	motion_act_phase_slider.step = 0.001
	motion_act_phase_slider.custom_minimum_size = Vector2(240, 28)
	motion_act_phase_slider.set_value_no_signal(motion_act_phase)
	motion_act_phase_slider.value_changed.connect(_on_motion_act_phase_changed)
	context_bar.add_child(motion_act_phase_slider)
	motion_act_phase_value_label = Label.new()
	motion_act_phase_value_label.text = "%.2f" % motion_act_phase
	motion_act_phase_value_label.custom_minimum_size = Vector2(42, 32)
	motion_act_phase_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	context_bar.add_child(motion_act_phase_value_label)
	var loop_toggle := CheckBox.new()
	loop_toggle.text = "Preview Loop"
	loop_toggle.button_pressed = motion_act_preview_loop
	loop_toggle.toggled.connect(func(enabled: bool) -> void: motion_act_preview_loop = enabled)
	context_bar.add_child(loop_toggle)


func _toggle_motion_act_playback() -> void:
	var act := _get_motion_act(selected_motion_act_id)
	if not _motion_act_is_previewable(act):
		return
	if not motion_act_playing and motion_act_phase >= 1.0:
		motion_act_phase = 0.0
	motion_act_playing = not motion_act_playing
	_render_context_bar()
	_refresh_motion_act_workspace()


func _on_motion_act_phase_changed(value: float) -> void:
	motion_act_phase = clampf(value, 0.0, 1.0)
	_refresh_motion_act_workspace()
	_render_info_bar()


func _advance_motion_act_preview(delta: float) -> void:
	var act := _get_motion_act(selected_motion_act_id)
	if not _motion_act_is_previewable(act):
		motion_act_playing = false
		return
	var duration := maxf(0.01, float(act.get("timing", {}).get("duration", 0.6)))
	motion_act_phase += delta / duration
	if motion_act_phase >= 1.0:
		if motion_act_preview_loop:
			motion_act_phase = fmod(motion_act_phase, 1.0)
		else:
			motion_act_phase = 1.0
			motion_act_playing = false
			_render_context_bar()
	_refresh_motion_act_workspace()


func _motion_act_is_previewable(act: Dictionary) -> bool:
	return not _get_asset(motion_act_preview_asset_id).is_empty() and MotionActEvaluator.validation_issues(act).is_empty()


func _render_motion_sequence_context_bar() -> void:
	var composition_button := Button.new()
	composition_button.text = "⌘1  Composition"
	composition_button.toggle_mode = true
	composition_button.button_pressed = motion_sequence_view == MotionSequenceWorkspace.VIEW_COMPOSITION
	composition_button.pressed.connect(_set_motion_sequence_view.bind(MotionSequenceWorkspace.VIEW_COMPOSITION))
	context_bar.add_child(composition_button)
	var player_button := Button.new()
	player_button.text = "⌘2  Player"
	player_button.toggle_mode = true
	player_button.button_pressed = motion_sequence_view == MotionSequenceWorkspace.VIEW_PLAYER
	player_button.pressed.connect(_set_motion_sequence_view.bind(MotionSequenceWorkspace.VIEW_PLAYER))
	context_bar.add_child(player_button)
	var sequence_document := _get_motion_sequence(selected_motion_sequence_id)
	var entry := _resolved_motion_sequence_entry(sequence_document)
	if motion_sequence_view == MotionSequenceWorkspace.VIEW_COMPOSITION:
		var add_button := Button.new()
		add_button.text = "+ Add Entry"
		add_button.disabled = sequence_document.is_empty() or not sequence_document.get("entries", []).is_empty()
		add_button.pressed.connect(_add_motion_sequence_entry)
		context_bar.add_child(add_button)
		return
	var play_button := Button.new()
	play_button.text = "❚❚" if motion_sequence_playing else "▶"
	play_button.custom_minimum_size = Vector2(40, 32)
	play_button.disabled = not _motion_sequence_is_previewable(entry)
	play_button.pressed.connect(_toggle_motion_sequence_playback)
	context_bar.add_child(play_button)
	var phase_label := Label.new()
	phase_label.text = "Phase"
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	context_bar.add_child(phase_label)
	motion_sequence_phase_slider = HSlider.new()
	motion_sequence_phase_slider.min_value = 0.0
	motion_sequence_phase_slider.max_value = 1.0
	motion_sequence_phase_slider.step = 0.001
	motion_sequence_phase_slider.custom_minimum_size = Vector2(240, 28)
	motion_sequence_phase_slider.set_value_no_signal(motion_sequence_phase)
	motion_sequence_phase_slider.value_changed.connect(_on_motion_sequence_phase_changed)
	context_bar.add_child(motion_sequence_phase_slider)
	motion_sequence_phase_value_label = Label.new()
	motion_sequence_phase_value_label.text = "%.2f" % motion_sequence_phase
	motion_sequence_phase_value_label.custom_minimum_size = Vector2(42, 32)
	motion_sequence_phase_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	context_bar.add_child(motion_sequence_phase_value_label)
	var loop_toggle := CheckBox.new()
	loop_toggle.text = "Preview Loop"
	loop_toggle.button_pressed = motion_sequence_preview_loop
	loop_toggle.toggled.connect(_on_motion_sequence_preview_loop_changed)
	context_bar.add_child(loop_toggle)


func _set_motion_sequence_view(value: String) -> void:
	motion_sequence_view = value if value in [MotionSequenceWorkspace.VIEW_COMPOSITION, MotionSequenceWorkspace.VIEW_PLAYER] else MotionSequenceWorkspace.VIEW_COMPOSITION
	if motion_sequence_view != MotionSequenceWorkspace.VIEW_PLAYER:
		motion_sequence_playing = false
	_render_context_bar()
	_render_inspector()
	_render_info_bar()
	_refresh_motion_sequence_workspace()


func _toggle_motion_sequence_playback() -> void:
	var entry := _resolved_motion_sequence_entry(_get_motion_sequence(selected_motion_sequence_id))
	if not _motion_sequence_is_previewable(entry):
		return
	if not motion_sequence_playing and motion_sequence_phase >= 1.0:
		motion_sequence_phase = 0.0
	motion_sequence_playing = not motion_sequence_playing
	_render_context_bar()
	_render_info_bar()
	_refresh_motion_sequence_workspace()


func _on_motion_sequence_phase_changed(value: float) -> void:
	motion_sequence_phase = clampf(value, 0.0, 1.0)
	_refresh_motion_sequence_workspace()
	_render_info_bar()


func _on_motion_sequence_preview_loop_changed(enabled: bool) -> void:
	motion_sequence_preview_loop = enabled


func _advance_motion_sequence_preview(delta: float) -> void:
	var entry := _resolved_motion_sequence_entry(_get_motion_sequence(selected_motion_sequence_id))
	var context := _motion_sequence_entry_context(entry)
	if not MotionSequenceEvaluator.validation_issues(entry, context.get("asset", {}), context.get("path", {})).is_empty():
		motion_sequence_playing = false
		_render_context_bar()
		return
	var duration := maxf(0.01, float(context.get("path", {}).get("playback", {}).get("duration", 2.0)))
	motion_sequence_phase += delta / duration
	if motion_sequence_phase >= 1.0:
		if motion_sequence_preview_loop:
			motion_sequence_phase = fmod(motion_sequence_phase, 1.0)
		else:
			motion_sequence_phase = 1.0
			motion_sequence_playing = false
			_render_context_bar()
	_refresh_motion_sequence_workspace()


func _resolved_motion_sequence_entry(sequence_document: Dictionary) -> Dictionary:
	var selected := _get_motion_sequence_entry(sequence_document, selected_motion_sequence_entry_id)
	return selected if not selected.is_empty() else _first_motion_sequence_entry(sequence_document)


func _motion_sequence_entry_context(entry: Dictionary) -> Dictionary:
	return {"asset": _get_asset(str(entry.get("asset_id", ""))), "path": _get_motion_path(str(entry.get("path_id", "")))}


func _motion_sequence_is_previewable(entry: Dictionary) -> bool:
	var context := _motion_sequence_entry_context(entry)
	return MotionSequenceEvaluator.validation_issues(entry, context.get("asset", {}), context.get("path", {})).is_empty()


func _render_material_context_bar() -> void:
	# Reserved for future Material Graph node actions. The material workspace
	# opens directly into the graph and has no view-switching menu.
	return


func _on_material_view_menu_id(id: int) -> void:
	if id == 0:
		_set_material_view("graph")
	elif id == 1:
		_set_material_view("preview")
	elif id == 2:
		_set_material_view("lookdev")


func _set_material_view(mode: String) -> void:
	if mode != "graph" and mode != "preview" and mode != "lookdev":
		return
	material_view_mode = mode
	_render_outliner()
	_render_context_bar()
	_render_inspector()
	_render_info_bar()
	_render_canvas_context()


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
		_style_popup_menu(preview_popup)
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
	_style_popup_menu(origin_popup)
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
			element["visibility"] = bool(element.get("visibility", true))
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
			"visibility": true,
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
		"visibility": bool(data.get("visibility", true)),
		"texture_id": str(data.get("texture_id", "")),
		"tint": _deserialize_color(data.get("tint", [1.0, 1.0, 1.0, 1.0]), Color.WHITE),
		"opacity": clampf(float(data.get("opacity", 1.0)), 0.0, 1.0),
		"mapping_scale": _deserialize_vector(data.get("mapping_scale", [1.0, 1.0]), Vector2.ONE),
		"mapping_offset": _deserialize_vector(data.get("mapping_offset", [0.0, 0.0]), Vector2.ZERO),
		"mapping_wrap_mode": str(data.get("mapping_wrap_mode", "repeat" if bool(data.get("mapping_repeat", false)) else "clamp")),
		"mapping_repeat": bool(data.get("mapping_repeat", false))
	}


func _material_wrap_mode(material_data: Dictionary) -> String:
	var mode := str(material_data.get("mapping_wrap_mode", "repeat" if bool(material_data.get("mapping_repeat", false)) else "clamp"))
	return mode if mode == "fit" or mode == "clamp" or mode == "repeat" else "clamp"


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
	if id < 0 or id > 4:
		return
	_activate_draw_state()
	_set_draw_point_mode(_draw_point_mode_from_menu_id(id))


func _on_edit_menu_id(id: int) -> void:
	if id == 0:
		_activate_edit_point_state(false, false)
	elif id == 1:
		_activate_edit_point_state(true, false)
	elif id == 2:
		_activate_edit_point_state(false, true)


func _on_edit_edge_menu_id(id: int) -> void:
	if id == 0:
		_activate_edit_edge_state()


func _on_edit_face_menu_id(id: int) -> void:
	if id == 0:
		_activate_edit_face_state()


func _on_transform_menu_id(id: int) -> void:
	_activate_transform_state()
	if id == 1:
		_set_transform_mode("rotate")
	elif id == 2:
		_set_transform_mode("scale")


func _activate_draw_state() -> void:
	_set_active_state("draw")
	canvas_view.set_draw_point_mode(active_draw_point_mode)


func _draw_point_mode_from_key(keycode: int) -> String:
	return ["linear", "aligned", "free", "mirrored", "corner"][keycode - KEY_1]


func _draw_point_mode_from_menu_id(id: int) -> String:
	return ["linear", "aligned", "free", "mirrored", "corner"][id]


func _set_draw_point_mode(mode: String) -> void:
	if mode not in ["linear", "aligned", "free", "mirrored", "corner"]:
		return
	active_draw_point_mode = mode
	if is_instance_valid(canvas_view):
		canvas_view.set_draw_point_mode(mode)
	_render_context_bar()
	_render_info_bar()


func _set_edit_mode(mode: String) -> void:
	active_edit_mode = mode
	if mode != "edge":
		selected_edge_id = ""
	if mode != "point":
		selected_point_id = ""
		selected_point_ids.clear()
		edit_bezier_handles = false
		edit_point_set_mode = false
	canvas_view.set_edit_mode(active_edit_mode)
	canvas_view.set_edit_handles_enabled(edit_bezier_handles)
	canvas_view.set_edit_point_set_enabled(edit_point_set_mode)
	canvas_view.set_selected_edge_id(selected_edge_id)
	_render_info_bar()


func _activate_edit_state() -> void:
	_activate_edit_point_state()


func _activate_edit_point_state(handle_editing := false, set_mode := false) -> void:
	edit_bezier_handles = handle_editing
	edit_point_set_mode = set_mode
	_set_active_state("edit")
	_set_edit_mode("point")
	canvas_view.set_edit_handles_enabled(edit_bezier_handles)
	canvas_view.set_edit_point_set_enabled(edit_point_set_mode)


func _activate_edit_edge_state() -> void:
	_set_active_state("edit")
	_set_edit_mode("edge")


func _activate_edit_face_state() -> void:
	_set_active_state("edit")
	_set_edit_mode("face")


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
		active_draw_tool = "point"
		active_edit_mode = "point"
		canvas_view.set_interaction_state("draw")
		canvas_view.set_tool_mode(active_draw_tool)
		canvas_view.set_draw_point_mode(active_draw_point_mode)
	else:
		active_draw_tool = ""
		if active_edit_mode not in ["point", "edge", "face"]:
			active_edit_mode = "point"
		active_transform_mode = "transform"
		canvas_view.set_interaction_state(state)
		if state == "edit":
			canvas_view.set_edit_mode(active_edit_mode)
		canvas_view.set_tool_mode("")
	_render_context_bar()
	_render_info_bar()


func _render_info_bar() -> void:
	if not is_instance_valid(info_bar):
		return
	_ensure_default_edit_point_state()
	if is_instance_valid(active_material_status_label):
		if active_module == "Style" and not selected_material_id.is_empty():
			var active_material := _get_material(selected_material_id)
			active_material_status_label.text = "Material: %s" % str(active_material.get("name", "Material")) if not active_material.is_empty() else ""
		else:
			active_material_status_label.text = ""
	_clear(info_bar)
	if active_module == "Motion":
		if active_motion_submodule == "Path":
			var path_document := _get_motion_path(selected_motion_path_id)
			_add_info_option("Motion: Path")
			_add_info_option(str(path_document.get("name", "No Path selected")))
			_add_info_option("Phase %.2f" % motion_path_phase)
			_add_info_option("%d Points" % path_document.get("topology", {}).get("points", []).size() if not path_document.is_empty() else "Independent resource")
			return
		if active_motion_submodule == "Act":
			var act := _get_motion_act(selected_motion_act_id)
			_add_info_option("Motion: Act")
			_add_info_option(str(act.get("name", "No Act selected")))
			_add_info_option("Slide · Phase %.2f" % motion_act_phase)
			_add_info_option("Playing" if motion_act_playing else "Paused")
			return
		if active_motion_submodule == "Sequence":
			var sequence_document := _get_motion_sequence(selected_motion_sequence_id)
			_add_info_option("Motion: Sequence")
			_add_info_option(str(sequence_document.get("name", "No Sequence selected")))
			_add_info_option("Composition" if motion_sequence_view == MotionSequenceWorkspace.VIEW_COMPOSITION else "Player · Phase %.2f" % motion_sequence_phase)
			if motion_sequence_view == MotionSequenceWorkspace.VIEW_PLAYER:
				_add_info_option("Playing" if motion_sequence_playing else "Paused")
			return
		var motion_state_label := Label.new()
		motion_state_label.text = "Motion: %s" % (motion_player.current_state_name() if motion_player != null else "None")
		info_bar.add_child(motion_state_label)
		_add_info_option("Phase %.2f" % motion_phase)
		_add_info_option("Playing" if motion_player != null and motion_player.playing else "Paused")
		if motion_player != null and not motion_player.blend.is_empty():
			_add_info_option("Blend %.0f%%" % (motion_player.blend_weight() * 100.0))
		if not motion_last_marker.is_empty():
			_add_info_option("Marker %s" % motion_last_marker)
		return
	if active_module == "Geometry":
		_add_info_option("Geometry: %s" % active_geometry_submodule)
		_add_info_option("Placeholder")
		return
	if active_module == "Style":
		var material_state_label := Label.new()
		material_state_label.text = "State: Default"
		info_bar.add_child(material_state_label)
		if not selected_material_id.is_empty():
			_add_info_option("Material Graph")
		return
	if active_module == "Export":
		var build_state := Label.new()
		build_state.text = "Build: %s" % (str(_get_asset(selected_asset_id).get("name", "None")))
		info_bar.add_child(build_state)
		_add_info_option("Validate")
		_add_info_option("Build")
		return
	if not selected_texture_id.is_empty():
		var texture := _get_texture(selected_texture_id)
		var selected_element := _get_element(texture, selected_element_id)
		var texture_state_label := Label.new()
		texture_state_label.text = "State: Default"
		info_bar.add_child(texture_state_label)
		if not selected_element.is_empty() and str(selected_element.get("type", "generator")) == "import":
			_add_info_option("1: Original")
			_add_info_option("2: White to Alpha")
		return
	if selected_component_id.is_empty():
		if active_module == "Create":
			var asset_state_label := Label.new()
			asset_state_label.text = "State: Default"
			info_bar.add_child(asset_state_label)
		return
	var state_label := Label.new()
	var state_name := "Default"
	if active_state == "draw":
		state_name = "Draw Point"
	elif active_state == "edit" and active_edit_mode == "point":
		state_name = "Edit Point"
	elif active_state == "edit" and active_edit_mode == "edge":
		state_name = "Edit Edge"
	elif active_state == "edit" and active_edit_mode == "face":
		state_name = "Edit Face"
	state_label.text = "State: %s" % state_name
	info_bar.add_child(state_label)
	if active_state == "draw":
		_add_info_option("Click: Add %s Point" % _draw_point_mode_label(active_draw_point_mode))
		_add_info_option("1: Linear  2: Aligned  3: Free  4: Mirrored  5: Corner")
	elif active_state == "edit" and active_edit_mode == "point":
		if edit_point_set_mode:
			_add_info_option("Click Edge: Set Point")
		elif edit_bezier_handles:
			_add_info_option("Drag: Bezier Handle")
		else:
			_add_info_option("Click: Select")
		_add_info_option("1: Select  2: Bezier Handle  3: Set")
	elif active_state == "edit" and active_edit_mode == "edge":
		_add_info_option("Click: Select Edge")
	elif active_state == "edit" and active_edit_mode == "face":
		_add_info_option("Drag: Move Face")
	else:
		_add_info_option("⌘1: Draw Point")
		_add_info_option("⌘2: Edit Point")
		_add_info_option("⌘3: Edit Edge")
		_add_info_option("⌘4: Edit Face")


func _draw_point_mode_label(mode: String) -> String:
	match mode:
		"aligned":
			return "Aligned"
		"free":
			return "Free"
		"mirrored":
			return "Mirrored"
		"corner":
			return "Corner"
		_:
			return "Linear"


func _validate_selected_export_asset() -> void:
	_render_export_workspace()


func _export_validation_errors(asset: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if asset.is_empty():
		errors.append("Select an Asset source.")
		return errors
	for component in asset.get("components", []):
		var component_name := str(component.get("name", "Component"))
		var points: Array = BezierTopology.outer_control_polygon(component)
		if not BezierTopology.outer_chain_closed(component):
			errors.append("%s: contour is not closed." % component_name)
			continue
		if points.size() < 3:
			errors.append("%s: contour needs at least 3 points." % component_name)
			continue
		var packed_points := PackedVector2Array()
		for point in points:
			if point is Vector2:
				packed_points.append(point)
		if packed_points.size() != points.size() or Geometry2D.triangulate_polygon(packed_points).is_empty():
			errors.append("%s: contour cannot be triangulated." % component_name)
		var material_id := str(component.get("material_id", ""))
		if material_id.is_empty():
			continue
		var material_data := _get_material(material_id)
		if material_data.is_empty():
			errors.append("%s: assigned Material is missing." % component_name)
			continue
		var texture_id := str(material_data.get("texture_id", ""))
		if not texture_id.is_empty() and _texture_output_state(_get_texture(texture_id)) != "ready":
			errors.append("%s: Material Texture is not ready." % component_name)
	return errors


func _render_export_workspace() -> void:
	if not is_instance_valid(export_workspace):
		return
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty():
		export_summary_label.text = "No Source Asset selected"
		export_validation_label.text = "Select an Asset in the Outliner, then validate it before building."
		export_validation_label.add_theme_color_override("font_color", Color("#9aa3b2"))
		return
	export_summary_label.text = "Source Asset: %s" % str(asset.get("name", "Asset"))
	var errors := _export_validation_errors(asset)
	if errors.is_empty():
		export_validation_label.text = "Validation passed. Ready to build Godot Scene."
		export_validation_label.add_theme_color_override("font_color", Color("#75b88a"))
	else:
		export_validation_label.text = "Validation\n• %s" % "\n• ".join(errors)
		export_validation_label.add_theme_color_override("font_color", Color("#e56b6f"))


func _build_selected_asset_scene() -> void:
	var asset := _get_asset(selected_asset_id)
	var errors := _export_validation_errors(asset)
	if not errors.is_empty():
		_show_status_message("Build blocked: validation failed.")
		_render_export_workspace()
		return
	var root := Node2D.new()
	root.name = _tscn_name(str(asset.get("name", "Asset")))
	for component in asset.get("components", []):
		var polygon := Polygon2D.new()
		polygon.name = _tscn_name(str(component.get("name", "Component")))
		var export_points := _godot_export_points(BezierTopology.outer_control_polygon(component))
		polygon.polygon = PackedVector2Array(export_points)
		var transform: Dictionary = component.get("transform", _default_component_transform())
		var export_transform := _godot_export_transform(transform)
		polygon.position = export_transform["position"]
		polygon.rotation = deg_to_rad(float(export_transform["rotation"]))
		polygon.scale = export_transform["scale"]
		polygon.visible = bool(asset.get("visibility", true)) and bool(component.get("visibility", true))
		polygon.z_index = int(component.get("z_index", 0))
		var material_data := _get_material(str(component.get("material_id", "")))
		if not material_data.is_empty():
			var tint: Color = material_data.get("tint", Color.WHITE)
			polygon.color = Color(tint.r, tint.g, tint.b, tint.a * float(material_data.get("opacity", 1.0)))
			var texture := _get_texture(str(material_data.get("texture_id", "")))
			var texture_path := _get_texture_final_path(texture) if not texture.is_empty() else ""
			if not texture_path.is_empty():
				var texture_resource := load(texture_path) as Texture2D
				polygon.texture = texture_resource
				if texture_resource != null:
					polygon.uv = _build_export_uvs(export_points, texture_resource.get_size(), material_data.get("mapping_scale", Vector2.ONE), material_data.get("mapping_offset", Vector2.ZERO), _material_wrap_mode(material_data))
					polygon.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED if _material_wrap_mode(material_data) == "repeat" else CanvasItem.TEXTURE_REPEAT_DISABLED
		root.add_child(polygon)
		polygon.owner = root
	var scene := PackedScene.new()
	var pack_error := scene.pack(root)
	if pack_error != OK:
		root.free()
		_show_status_message("Build failed: could not pack scene.")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports"))
	var safe_name := _tscn_name(str(asset.get("name", "Asset")).to_lower().replace(" ", "_"))
	var scene_path := "res://exports/%s.tscn" % safe_name
	var save_error := ResourceSaver.save(scene, scene_path)
	root.free()
	if save_error != OK:
		_show_status_message("Build failed: could not save scene.")
		return
	_show_status_message("Built Godot Scene: %s" % scene_path)
	_render_export_workspace()


func _build_export_uvs(points: Array, texture_size: Vector2, mapping_scale: Vector2, mapping_offset: Vector2, wrap_mode: String) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	if points.is_empty():
		return uvs
	var min_point: Vector2 = points[0] if points[0] is Vector2 else Vector2.ZERO
	var max_point := min_point
	for point in points:
		if not point is Vector2:
			continue
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	var extent := max_point - min_point
	if is_zero_approx(extent.x):
		extent.x = 1.0
	if is_zero_approx(extent.y):
		extent.y = 1.0
	var safe_scale := Vector2(maxf(mapping_scale.x, 0.01), maxf(mapping_scale.y, 0.01))
	for point in points:
		var local_point: Vector2 = point if point is Vector2 else Vector2.ZERO
		var normalized_uv := Vector2((local_point.x - min_point.x) / extent.x, (local_point.y - min_point.y) / extent.y)
		uvs.append((normalized_uv if wrap_mode == "fit" else normalized_uv / safe_scale + mapping_offset) * texture_size)
	return uvs


func _tscn_name(value: String) -> String:
	return value.replace("\"", "'") if not value.is_empty() else "Component"


func _godot_export_points(points: Array) -> Array[Vector2]:
	const CENTIMETERS_TO_METERS := 0.1
	var converted: Array[Vector2] = []
	for point in points:
		if point is Vector2:
			converted.append(Vector2(point.x * CENTIMETERS_TO_METERS, -point.y * CENTIMETERS_TO_METERS))
	return converted


func _godot_export_transform(transform: Dictionary) -> Dictionary:
	const CENTIMETERS_TO_METERS := 0.1
	var normalized := _deserialize_transform(transform)
	var export_position_value: Vector2 = normalized["position"]
	var export_pivot_value: Vector2 = normalized["pivot"]
	return {
		"position": Vector2(export_position_value.x * CENTIMETERS_TO_METERS, -export_position_value.y * CENTIMETERS_TO_METERS),
		"rotation": -float(normalized["rotation"]),
		"scale": normalized["scale"],
		"pivot": Vector2(export_pivot_value.x * CENTIMETERS_TO_METERS, -export_pivot_value.y * CENTIMETERS_TO_METERS)
	}


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
	assets.append({"id": asset_id, "name": asset_name, "visibility": true, "reference_image": _default_reference_image(), "animation": MotionWorkspace.create_default_animation_document(), "components": []})
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


func _open_reference_image_dialog() -> void:
	if _get_asset(selected_asset_id).is_empty():
		return
	if workspace_name.is_empty():
		_show_status_message("Create or load a Workspace before loading a Reference Image.")
		return
	reference_image_dialog.current_dir = _reference_art_directory()
	reference_image_dialog.popup_centered_ratio()


func _reference_art_directory() -> String:
	var documents_directory := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if documents_directory.is_empty():
		return ProjectSettings.globalize_path(IMPORT_TEXTURES_ROOT)
	var reference_art_directory := documents_directory.path_join("RefArt")
	DirAccess.make_dir_recursive_absolute(reference_art_directory)
	return reference_art_directory


func _on_reference_image_file_selected(source_path: String) -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty() or workspace_name.is_empty():
		return
	var source_image := Image.new()
	if source_image.load(source_path) != OK or source_image.is_empty():
		_show_status_message("Reference Image could not be loaded.")
		return
	reference_image_crop_dialog.open_for_image(source_image)


func _save_reference_image_result(reference_image_result: Image) -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty() or workspace_name.is_empty() or reference_image_result == null or reference_image_result.is_empty():
		return
	var reference_filename := _reference_image_filename(asset)
	var asset_root := "%s/%s/assets/%s" % [WORKSPACES_ROOT, workspace_name, str(asset.get("id", ""))]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(asset_root))
	var destination_path := "%s/%s" % [asset_root, reference_filename]
	if reference_image_result.save_png(ProjectSettings.globalize_path(destination_path)) != OK:
		_show_status_message("Reference Image could not be copied.")
		return
	var reference_image := _normalize_reference_image(asset.get("reference_image", {}))
	reference_image["file"] = reference_filename
	# Every newly loaded reference starts from a neutral transform. The
	# selected target height and pivot remain unchanged.
	reference_image["position"] = Vector2.ZERO
	reference_image["scale"] = 1.0
	_record_direct_change()
	asset["reference_image"] = reference_image
	_render_inspector()
	_render_canvas_context()


func _clear_reference_image() -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty():
		return
	var reference_image := _normalize_reference_image(asset.get("reference_image", {}))
	if str(reference_image.get("file", "")).is_empty():
		return
	_record_direct_change()
	reference_image["file"] = ""
	asset["reference_image"] = reference_image
	_render_inspector()
	_render_canvas_context()


func _on_reference_image_visibility_changed(image_visible: bool) -> void:
	_update_reference_image_property("visible", image_visible)


func _on_reference_image_target_height_changed(value: float) -> void:
	_update_reference_image_property("target_height_cm", maxf(value, 0.01))


func _on_reference_image_pivot_selected(index: int, option: OptionButton) -> void:
	if index < 0 or index >= option.item_count:
		return
	_update_reference_image_property("pivot_mode", str(option.get_item_metadata(index)))


func _on_reference_image_property_changed(value: float, property_name: String) -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty():
		return
	var reference_image := _normalize_reference_image(asset.get("reference_image", {}))
	if property_name == "opacity":
		reference_image["opacity"] = clampf(value, 0.0, 1.0)
	elif property_name == "position_x":
		var reference_position: Vector2 = reference_image["position"]
		reference_position.x = _world_to_editor_units(value)
		reference_image["position"] = reference_position
	elif property_name == "position_y":
		var reference_position: Vector2 = reference_image["position"]
		reference_position.y = _world_to_editor_units(value)
		reference_image["position"] = reference_position
	elif property_name == "scale":
		reference_image["scale"] = maxf(value, 0.01)
	else:
		return
	_record_direct_change()
	asset["reference_image"] = reference_image
	_render_canvas_context()


func _update_reference_image_property(property_name: String, value) -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty():
		return
	var reference_image := _normalize_reference_image(asset.get("reference_image", {}))
	reference_image[property_name] = value
	_record_direct_change()
	asset["reference_image"] = reference_image
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
		"visibility": true,
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


func _open_new_material_dialog() -> void:
	material_name_input.text = ""
	material_dialog.popup_centered()
	material_name_input.grab_focus()


func _submit_material_name(_submitted_text: String) -> void:
	_confirm_material_creation()


func _confirm_material_creation() -> void:
	_record_direct_change()
	var material_name := material_name_input.text.strip_edges()
	if material_name.is_empty():
		material_name = _next_default_material_name()
	var material_id := "material_%d" % next_material_id
	next_material_id += 1
	materials.append({
		"id": material_id,
		"name": material_name,
		"visibility": true,
		"texture_id": "",
		"tint": Color.WHITE,
		"opacity": 1.0,
		"mapping_scale": Vector2.ONE,
		"mapping_offset": Vector2.ZERO,
		"mapping_wrap_mode": "clamp",
		"mapping_repeat": false
	})
	material_dialog.hide()
	_enter_material_context(material_id)


func _next_default_material_name() -> String:
	var index := 1
	while _has_material_name("material%02d" % index):
		index += 1
	return "material%02d" % index


func _has_material_name(material_name: String) -> bool:
	for material_record in materials:
		if str(material_record.get("name", "")).to_lower() == material_name.to_lower():
			return true
	return false


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
		"visibility": true,
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
	_update_context_action_button()
	if active_module == "Motion":
		_render_motion_outliner()
		return
	if active_module == "Style":
		_render_material_outliner()
		return
	if active_module == "Export":
		_render_export_outliner()
		return
	if active_module == "Geometry":
		outliner_list.add_child(_create_outliner_group_label("Geometry · Placeholder"))
		outliner_list.add_child(_create_inspector_field_label("%s authoring will be introduced in a later phase." % active_geometry_submodule))
		return
	var search_text := outliner_search_input.text.strip_edges().to_lower() if is_instance_valid(outliner_search_input) else ""
	var show_assets := active_create_submodule == "Asset"
	var show_textures := active_create_submodule == "Texture"
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


func _render_motion_outliner() -> void:
	var search_text := outliner_search_input.text.strip_edges().to_lower() if is_instance_valid(outliner_search_input) else ""
	if active_motion_submodule == "Path":
		outliner_list.add_child(_create_outliner_group_label("Paths"))
		for path_document in motion_paths:
			if search_text.is_empty() or str(path_document.get("name", "")).to_lower().contains(search_text):
				var path_button := Button.new()
				path_button.text = str(path_document.get("name", "Path"))
				path_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
				path_button.focus_mode = Control.FOCUS_NONE
				_style_outliner_button(path_button, str(path_document.get("id", "")) == selected_motion_path_id)
				path_button.pressed.connect(_select_motion_path.bind(str(path_document.get("id", ""))))
				outliner_list.add_child(path_button)
		if motion_paths.is_empty():
			outliner_list.add_child(_create_inspector_field_label("No Paths"))
		return
	if active_motion_submodule == "Sequence":
		outliner_list.add_child(_create_outliner_group_label("Sequences"))
		for sequence_document in motion_sequences:
			if search_text.is_empty() or str(sequence_document.get("name", "")).to_lower().contains(search_text):
				var sequence_button := Button.new()
				sequence_button.text = str(sequence_document.get("name", "Sequence"))
				sequence_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
				sequence_button.focus_mode = Control.FOCUS_NONE
				_style_outliner_button(sequence_button, str(sequence_document.get("id", "")) == selected_motion_sequence_id)
				sequence_button.pressed.connect(_select_motion_sequence.bind(str(sequence_document.get("id", ""))))
				outliner_list.add_child(sequence_button)
		if motion_sequences.is_empty():
			outliner_list.add_child(_create_inspector_field_label("No Sequences"))
		return
	if active_motion_submodule == "Act":
		outliner_list.add_child(_create_outliner_group_label("Preview Assets"))
		for asset in assets:
			if not search_text.is_empty() and not str(asset.get("name", "")).to_lower().contains(search_text):
				continue
			var asset_id := str(asset.get("id", ""))
			var preview_button := Button.new()
			preview_button.text = str(asset.get("name", "Asset"))
			preview_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			preview_button.focus_mode = Control.FOCUS_NONE
			_style_outliner_button(preview_button, asset_id == motion_act_preview_asset_id)
			preview_button.pressed.connect(_select_motion_act_preview_asset.bind(asset_id))
			outliner_list.add_child(preview_button)
		if assets.is_empty():
			outliner_list.add_child(_create_inspector_field_label("No Assets"))
		return
	var visible_assets: Array[Dictionary] = []
	for asset in assets:
		if search_text.is_empty() or str(asset.get("name", "")).to_lower().contains(search_text):
			visible_assets.append(asset)
	visible_assets.sort_custom(_sort_named_documents)
	outliner_list.add_child(_create_outliner_group_label("Animation Assets"))
	for asset in visible_assets:
		var asset_id := str(asset.get("id", ""))
		var asset_button := Button.new()
		asset_button.text = str(asset.get("name", "Asset"))
		asset_button.custom_minimum_size = Vector2(0, 30)
		asset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		asset_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		asset_button.focus_mode = Control.FOCUS_NONE
		_style_outliner_button(asset_button, asset_id == selected_asset_id)
		asset_button.pressed.connect(_select_motion_asset.bind(asset_id))
		outliner_list.add_child(asset_button)
	if visible_assets.is_empty():
		outliner_list.add_child(_create_inspector_field_label("No Assets"))


func _select_motion_path(path_id: String) -> void:
	selected_motion_path_id = path_id
	motion_path_phase = 0.0
	motion_path_playing = false
	if _get_asset(motion_path_preview_asset_id).is_empty():
		motion_path_preview_asset_id = _default_motion_path_preview_asset_id()
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _select_motion_sequence(sequence_id: String) -> void:
	selected_motion_sequence_id = sequence_id
	var sequence_document := _get_motion_sequence(sequence_id)
	var first_entry := _first_motion_sequence_entry(sequence_document)
	selected_motion_sequence_entry_id = str(first_entry.get("id", ""))
	motion_sequence_phase = 0.0
	motion_sequence_playing = false
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _select_motion_act_preview_asset(asset_id: String) -> void:
	if _get_asset(asset_id).is_empty():
		return
	motion_act_preview_asset_id = asset_id
	motion_act_phase = 0.0
	motion_act_playing = false
	_render_outliner()
	_render_canvas_context()


func _select_motion_sequence_entry(entry_id: String) -> void:
	var sequence_document := _get_motion_sequence(selected_motion_sequence_id)
	if _get_motion_sequence_entry(sequence_document, entry_id).is_empty():
		return
	selected_motion_sequence_entry_id = entry_id
	_render_inspector()
	_refresh_motion_sequence_workspace()


func _add_motion_sequence_entry() -> void:
	var sequence_document := _get_motion_sequence(selected_motion_sequence_id)
	if sequence_document.is_empty():
		return
	if not sequence_document.get("entries", []).is_empty():
		_show_status_message("Phase 12 MVP supports one Composition Entry.")
		return
	_record_direct_change()
	var entry_index := int(sequence_document.get("next_entry_index", 1))
	sequence_document["next_entry_index"] = entry_index + 1
	var asset_id := _default_motion_path_preview_asset_id()
	var asset := _get_asset(asset_id)
	var state_id := _default_sequence_state_id(asset)
	var path_id := selected_motion_path_id if not _get_motion_path(selected_motion_path_id).is_empty() else (str(motion_paths[0].get("id", "")) if not motion_paths.is_empty() else "")
	var entry := {"id": "entry_%d" % entry_index, "name": "Composition Entry", "enabled": true, "asset_id": asset_id, "animation_state_id": state_id, "path_id": path_id}
	sequence_document["entries"].append(entry)
	selected_motion_sequence_entry_id = str(entry["id"])
	motion_sequence_phase = 0.0
	motion_sequence_playing = false
	_render_inspector()
	_render_context_bar()
	_refresh_motion_sequence_workspace()


func _remove_motion_sequence_entry() -> void:
	var sequence_document := _get_motion_sequence(selected_motion_sequence_id)
	var entries: Array = sequence_document.get("entries", [])
	for index in range(entries.size()):
		if str(entries[index].get("id", "")) == selected_motion_sequence_entry_id:
			_record_direct_change()
			entries.remove_at(index)
			selected_motion_sequence_entry_id = ""
			motion_sequence_phase = 0.0
			motion_sequence_playing = false
			_render_inspector()
			_render_context_bar()
			_refresh_motion_sequence_workspace()
			return


func _default_sequence_state_id(asset: Dictionary) -> String:
	var states: Array = asset.get("animation", {}).get("states", [])
	for state in states:
		if str(state.get("name", "")).to_upper() == "WALK":
			return str(state.get("id", ""))
	return str(states[0].get("id", "")) if not states.is_empty() else ""


func _rename_motion_path(new_name: String, path_document: Dictionary, editor: LineEdit) -> void:
	var normalized_name := new_name.strip_edges()
	if normalized_name.is_empty():
		editor.text = str(path_document.get("name", "Path"))
		_show_status_message("Path name cannot be empty.")
		return
	if normalized_name == str(path_document.get("name", "")):
		return
	_record_direct_change()
	path_document["name"] = normalized_name
	_render_outliner()
	if is_instance_valid(motion_path_workspace):
		motion_path_workspace.set_document(path_document)


func _rename_motion_sequence(new_name: String, sequence_document: Dictionary, editor: LineEdit) -> void:
	var normalized_name := new_name.strip_edges()
	if normalized_name.is_empty():
		editor.text = str(sequence_document.get("name", "Sequence"))
		_show_status_message("Sequence name cannot be empty.")
		return
	if normalized_name == str(sequence_document.get("name", "")):
		return
	_record_direct_change()
	sequence_document["name"] = normalized_name
	_render_outliner()
	if is_instance_valid(motion_sequence_workspace):
		motion_sequence_workspace.set_document(sequence_document)


func _on_motion_path_point_add_requested(position: Vector2) -> void:
	var path_document := _get_motion_path(selected_motion_path_id)
	if path_document.is_empty():
		return
	_record_direct_change()
	MotionPathTopology.add_point(path_document["topology"], position)
	motion_path_phase = 0.0
	_refresh_motion_path_workspace()
	_render_inspector()
	_render_context_bar()


func _on_motion_path_point_move_requested(point_id: String, position: Vector2) -> void:
	var path_document := _get_motion_path(selected_motion_path_id)
	if path_document.is_empty() or not MotionPathTopology.move_point(path_document["topology"], point_id, position):
		return
	_refresh_motion_path_workspace()


func _on_motion_path_handle_move_requested(point_id: String, side: String, value: Vector2) -> void:
	var path_document := _get_motion_path(selected_motion_path_id)
	if path_document.is_empty() or not MotionPathTopology.set_handle(path_document["topology"], point_id, side, value):
		return
	_refresh_motion_path_workspace()


func _on_motion_path_point_delete_requested(point_id: String) -> void:
	var path_document := _get_motion_path(selected_motion_path_id)
	if path_document.is_empty():
		return
	_record_direct_change()
	if MotionPathTopology.delete_point(path_document["topology"], point_id):
		motion_path_phase = 0.0
		_refresh_motion_path_workspace()
		_render_inspector()
		_render_context_bar()


func _refresh_motion_path_workspace() -> void:
	if not is_instance_valid(motion_path_workspace):
		return
	motion_path_workspace.set_document(_get_motion_path(selected_motion_path_id))
	motion_path_workspace.set_preview_asset(_get_asset(motion_path_preview_asset_id))
	motion_path_workspace.set_tool_mode(motion_path_tool)
	motion_path_workspace.set_runtime(motion_path_phase, motion_path_playing)
	if is_instance_valid(motion_path_phase_slider):
		motion_path_phase_slider.set_value_no_signal(motion_path_phase)
	if is_instance_valid(motion_path_phase_value_label):
		motion_path_phase_value_label.text = "%.2f" % motion_path_phase


func _refresh_motion_act_workspace() -> void:
	if not is_instance_valid(motion_act_workspace):
		return
	motion_act_workspace.set_context(motion_acts, selected_motion_act_id, _get_asset(motion_act_preview_asset_id))
	motion_act_workspace.set_runtime(motion_act_phase, motion_act_playing)
	if is_instance_valid(motion_act_phase_slider):
		motion_act_phase_slider.set_value_no_signal(motion_act_phase)
	if is_instance_valid(motion_act_phase_value_label):
		motion_act_phase_value_label.text = "%.2f" % motion_act_phase


func _refresh_motion_sequence_workspace() -> void:
	if not is_instance_valid(motion_sequence_workspace):
		return
	var sequence_document := _get_motion_sequence(selected_motion_sequence_id)
	var entry := _resolved_motion_sequence_entry(sequence_document)
	var context := _motion_sequence_entry_context(entry)
	motion_sequence_workspace.set_context(sequence_document, str(entry.get("id", "")), context.get("asset", {}), context.get("path", {}))
	motion_sequence_workspace.set_view_mode(motion_sequence_view)
	motion_sequence_workspace.set_runtime(motion_sequence_phase, motion_sequence_playing)
	if is_instance_valid(motion_sequence_phase_slider):
		motion_sequence_phase_slider.set_value_no_signal(motion_sequence_phase)
	if is_instance_valid(motion_sequence_phase_value_label):
		motion_sequence_phase_value_label.text = "%.2f" % motion_sequence_phase
	var snapshot := MotionSequenceEvaluator.evaluate(entry, context.get("asset", {}), context.get("path", {}), motion_sequence_phase)
	if is_instance_valid(motion_sequence_runtime_sequence_label):
		motion_sequence_runtime_sequence_label.text = "%.2f" % motion_sequence_phase
	if is_instance_valid(motion_sequence_runtime_path_label):
		motion_sequence_runtime_path_label.text = "%.2f" % float(snapshot.get("path_phase", 0.0))
	if is_instance_valid(motion_sequence_runtime_animation_label):
		motion_sequence_runtime_animation_label.text = "%.2f" % float(snapshot.get("animation_phase", 0.0))


func _select_motion_asset(asset_id: String) -> void:
	var asset := _get_asset(asset_id)
	if asset.is_empty():
		return
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_texture_id = ""
	selected_element_id = ""
	selected_material_id = ""
	motion_selection.select_asset(asset_id)
	if is_instance_valid(motion_workspace):
		motion_workspace.set_asset(asset_id, str(asset.get("name", "Asset")), asset.get("components", []), _ensure_asset_animation(asset))
	_sync_motion_player_document(asset)
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _render_material_outliner() -> void:
	var search_text := outliner_search_input.text.strip_edges().to_lower() if is_instance_valid(outliner_search_input) else ""
	var visible_materials: Array[Dictionary] = []
	for material_record in materials:
		if search_text.is_empty() or str(material_record.get("name", "")).to_lower().contains(search_text):
			visible_materials.append(material_record)
	visible_materials.sort_custom(_sort_named_documents)
	outliner_list.add_child(_create_outliner_group_label("Material"))
	for material_record in visible_materials:
		var material_row := HBoxContainer.new()
		material_row.add_theme_constant_override("separation", 2)
		outliner_list.add_child(material_row)
		var material_id := str(material_record.get("id", ""))
		material_row.add_child(_create_visibility_checkbox(bool(material_record.get("visibility", true)), _on_material_visibility_changed.bind(material_id)))
		var material_button := Button.new()
		material_button.text = str(material_record.get("name", "Material"))
		material_button.custom_minimum_size = Vector2(0, 30)
		material_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		material_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		material_button.focus_mode = Control.FOCUS_NONE
		_style_outliner_button(material_button, material_id == selected_material_id)
		material_button.pressed.connect(_select_material.bind(material_id))
		material_row.add_child(material_button)


func _render_export_outliner() -> void:
	var search_text := outliner_search_input.text.strip_edges().to_lower() if is_instance_valid(outliner_search_input) else ""
	var source_assets: Array[Dictionary] = []
	for asset in assets:
		if search_text.is_empty() or str(asset.get("name", "")).to_lower().contains(search_text):
			source_assets.append(asset)
	source_assets.sort_custom(_sort_named_documents)
	outliner_list.add_child(_create_outliner_group_label("Source Assets"))
	for asset in source_assets:
		var asset_id := str(asset.get("id", ""))
		var source_row := HBoxContainer.new()
		source_row.add_theme_constant_override("separation", 2)
		outliner_list.add_child(source_row)
		source_row.add_child(_create_visibility_checkbox(bool(asset.get("visibility", true)), _on_asset_visibility_changed.bind(asset_id)))
		var source_button := Button.new()
		source_button.text = str(asset.get("name", "Asset"))
		source_button.custom_minimum_size = Vector2(0, 30)
		source_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		source_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		source_button.focus_mode = Control.FOCUS_NONE
		_style_outliner_button(source_button, asset_id == selected_asset_id)
		source_button.pressed.connect(_select_export_source_asset.bind(asset_id))
		source_row.add_child(source_button)


func _select_export_source_asset(asset_id: String) -> void:
	if _get_asset(asset_id).is_empty():
		return
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_texture_id = ""
	selected_element_id = ""
	selected_material_id = ""
	active_state = ""
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _render_lookdev_outliner() -> void:
	var search_text := outliner_search_input.text.strip_edges().to_lower() if is_instance_valid(outliner_search_input) else ""
	var visible_assets: Array[Dictionary] = []
	for asset in assets:
		if _asset_matches_search(asset, search_text):
			visible_assets.append(asset)
	visible_assets.sort_custom(_sort_named_documents)
	outliner_list.add_child(_create_outliner_group_label("Assets"))
	for asset in visible_assets:
		_render_asset_outliner_entry(asset, not search_text.is_empty(), true)


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


func _create_visibility_checkbox(visibility_enabled: bool, callback: Callable) -> CheckBox:
	var checkbox := CheckBox.new()
	checkbox.custom_minimum_size = Vector2(26, 30)
	checkbox.focus_mode = Control.FOCUS_NONE
	checkbox.button_pressed = visibility_enabled
	checkbox.tooltip_text = "Visibility"
	checkbox.toggled.connect(callback)
	return checkbox


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


func _render_asset_outliner_entry(asset: Dictionary, force_expand := false, lookdev := false) -> void:
	var asset_id := str(asset["id"])
	var asset_container := VBoxContainer.new()
	asset_container.add_theme_constant_override("separation", 0)
	outliner_list.add_child(asset_container)
	var asset_header := HBoxContainer.new()
	asset_header.add_theme_constant_override("separation", 2)
	asset_container.add_child(asset_header)
	asset_header.add_child(_create_visibility_checkbox(bool(asset.get("visibility", true)), _on_asset_visibility_changed.bind(asset_id)))
	var asset_button := Button.new()
	asset_button.text = str(asset["name"])
	asset_button.custom_minimum_size = Vector2(0, 30)
	asset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asset_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	asset_button.focus_mode = Control.FOCUS_NONE
	var active_asset_id := lookdev_target_asset_id if lookdev else selected_asset_id
	var active_component_id := lookdev_target_component_id if lookdev else selected_component_id
	_style_outliner_button(asset_button, asset_id == active_asset_id and active_component_id.is_empty())
	if lookdev:
		asset_button.pressed.connect(_select_lookdev_asset.bind(asset_id))
	else:
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
		component_row.add_child(_create_visibility_checkbox(bool(component.get("visibility", true)), _on_component_visibility_entry_changed.bind(asset_id, component_id)))
		var component_button := Button.new()
		var component_name := str(component["name"])
		component_button.text = component_name if bool(component.get("visibility", true)) else _strikethrough_text(component_name)
		component_button.custom_minimum_size = Vector2(0, 30)
		component_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		component_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		component_button.focus_mode = Control.FOCUS_NONE
		_style_outliner_button(component_button, component_id == (lookdev_target_component_id if lookdev else selected_component_id) and asset_id == (lookdev_target_asset_id if lookdev else selected_asset_id))
		if lookdev:
			component_button.pressed.connect(_select_lookdev_component.bind(asset_id, component_id))
		else:
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
			guide_row.add_child(_create_visibility_checkbox(bool(guide.get("visibility", true)), _on_component_visibility_entry_changed.bind(asset_id, str(guide.get("id", "")))))
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
	texture_header.add_child(_create_visibility_checkbox(bool(texture.get("visibility", true)), _on_texture_visibility_changed.bind(texture_id)))
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
	element_row.add_child(_create_visibility_checkbox(bool(element.get("visibility", true)), _on_element_visibility_changed.bind(texture_id, str(element.get("id", "")))))
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
	processed_row.add_child(_create_visibility_checkbox(bool(import_element.get("visibility", true)), _on_element_visibility_changed.bind(texture_id, str(import_element.get("id", "")))))
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


func _strikethrough_text(text: String) -> String:
	var result := ""
	var strike_mark := String.chr(0x0336)
	for character in text:
		result += character + strike_mark
	return result


func _select_asset(asset_id: String) -> void:
	var was_selected := selected_asset_id == asset_id and selected_component_id.is_empty()
	active_module = "Create"
	_set_create_submodule_context("Asset")
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_texture_id = ""
	selected_element_id = ""
	selected_material_id = ""
	active_state = ""
	canvas_view.set_interaction_state("")
	if was_selected:
		expanded_assets[asset_id] = not bool(expanded_assets.get(asset_id, false))
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _select_texture(texture_id: String) -> void:
	var was_selected := selected_texture_id == texture_id and selected_element_id.is_empty()
	active_module = "Create"
	_set_create_submodule_context("Texture")
	active_import_preview_mode = "original"
	selected_texture_id = texture_id
	selected_element_id = ""
	selected_asset_id = ""
	selected_component_id = ""
	selected_material_id = ""
	active_state = ""
	if was_selected:
		expanded_textures[texture_id] = not bool(expanded_textures.get(texture_id, false))
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _select_element(texture_id: String, element_id: String) -> void:
	active_import_preview_mode = "original"
	active_module = "Create"
	_set_create_submodule_context("Texture")
	selected_texture_id = texture_id
	selected_element_id = element_id
	selected_asset_id = ""
	selected_component_id = ""
	selected_material_id = ""
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
	canvas_view.set_navigation_locked(true)
	component_dialog.popup_centered()
	component_name_input.grab_focus()


func _submit_component_name(_submitted_text: String) -> void:
	_confirm_component_creation()


func _on_component_dialog_canceled() -> void:
	canvas_view.set_navigation_locked(false)


func _confirm_component_creation() -> void:
	var asset_id := str(component_dialog.get_meta("asset_id", ""))
	var asset := _get_asset(asset_id)
	if asset.is_empty():
		component_dialog.hide()
		canvas_view.set_navigation_locked(false)
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
		"points": [],
		"edges": [],
		"chains": [],
		"transform": _default_component_transform(),
		"visibility": true,
		"z_index": 0,
		"material_id": ""
	})
	selected_asset_id = asset_id
	selected_component_id = component_id
	selected_texture_id = ""
	selected_element_id = ""
	active_state = ""
	expanded_assets[asset_id] = true
	component_dialog.hide()
	canvas_view.set_navigation_locked(false)
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
	active_module = "Create"
	_set_create_submodule_context("Asset")
	selected_asset_id = asset_id
	selected_component_id = component_id
	selected_edge_id = ""
	selected_point_id = ""
	selected_point_ids.clear()
	selected_texture_id = ""
	selected_element_id = ""
	selected_material_id = ""
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


func _delete_current_outliner_selection() -> void:
	if not selected_component_id.is_empty():
		_delete_selected_component()
	elif not selected_element_id.is_empty():
		_delete_selected_element()
	elif not selected_texture_id.is_empty():
		_delete_selected_texture()
	elif not selected_material_id.is_empty():
		_delete_selected_material()
	elif not selected_asset_id.is_empty():
		_delete_selected_asset()


func _delete_selected_element() -> void:
	var texture := _get_texture(selected_texture_id)
	if texture.is_empty() or selected_element_id.is_empty():
		return
	var element_index := -1
	for index in range(texture.get("elements", []).size()):
		if str(texture["elements"][index].get("id", "")) == selected_element_id:
			element_index = index
			break
	if element_index < 0:
		return
	_record_direct_change()
	texture["elements"].remove_at(element_index)
	selected_element_id = ""
	active_import_preview_mode = "original"
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _delete_selected_texture() -> void:
	if selected_texture_id.is_empty():
		return
	var texture_index := -1
	for index in range(textures.size()):
		if str(textures[index].get("id", "")) == selected_texture_id:
			texture_index = index
			break
	if texture_index < 0:
		return
	_record_direct_change()
	for material_record in materials:
		if str(material_record.get("texture_id", "")) == selected_texture_id:
			material_record["texture_id"] = ""
	textures.remove_at(texture_index)
	expanded_textures.erase(selected_texture_id)
	selected_texture_id = ""
	selected_element_id = ""
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _delete_selected_material() -> void:
	if selected_material_id.is_empty():
		return
	var material_index := -1
	for index in range(materials.size()):
		if str(materials[index].get("id", "")) == selected_material_id:
			material_index = index
			break
	if material_index < 0:
		return
	_record_direct_change()
	for asset in assets:
		for component in asset.get("components", []):
			if str(component.get("material_id", "")) == selected_material_id:
				component["material_id"] = ""
	materials.remove_at(material_index)
	selected_material_id = ""
	active_module = "Style"
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _delete_selected_asset() -> void:
	if selected_asset_id.is_empty():
		return
	var asset_index := -1
	for index in range(assets.size()):
		if str(assets[index].get("id", "")) == selected_asset_id:
			asset_index = index
			break
	if asset_index < 0:
		return
	_record_direct_change()
	assets.remove_at(asset_index)
	expanded_assets.erase(selected_asset_id)
	selected_asset_id = ""
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


func _render_material_inspector() -> void:
	var material_data := _get_material(selected_material_id)
	if material_data.is_empty():
		return
	inspector_content.add_child(_create_inspector_field_label("Name"))
	var name_editor := _create_name_editor(str(material_data.get("name", "Material")), "Material name")
	name_editor.text_submitted.connect(_rename_selected_material)
	name_editor.focus_exited.connect(func() -> void: _rename_selected_material(name_editor.text))
	inspector_content.add_child(name_editor)

	inspector_content.add_child(_create_inspector_section("Appearance"))
	inspector_content.add_child(_create_inspector_field_label("Texture"))
	var texture_option := OptionButton.new()
	texture_option.custom_minimum_size = Vector2(0, 26)
	texture_option.add_item("None")
	texture_option.set_item_metadata(0, "")
	var ready_textures: Array[Dictionary] = []
	for texture in textures:
		if _texture_output_state(texture) == "ready":
			ready_textures.append(texture)
	ready_textures.sort_custom(_sort_named_documents)
	for texture in ready_textures:
		texture_option.add_item(str(texture.get("name", "Texture")))
		texture_option.set_item_metadata(texture_option.item_count - 1, str(texture.get("id", "")))
	var material_texture_id := str(material_data.get("texture_id", ""))
	for index in range(texture_option.item_count):
		if str(texture_option.get_item_metadata(index)) == material_texture_id:
			texture_option.select(index)
			break
	texture_option.item_selected.connect(_on_material_texture_selected.bind(texture_option))
	inspector_content.add_child(texture_option)

	inspector_content.add_child(_create_inspector_field_label("Tint"))
	var tint_button := ColorPickerButton.new()
	tint_button.custom_minimum_size = Vector2(0, 26)
	tint_button.color = material_data.get("tint", Color.WHITE)
	tint_button.color_changed.connect(_on_material_tint_changed)
	inspector_content.add_child(tint_button)

	inspector_content.add_child(_create_inspector_field_label("Opacity"))
	var opacity_field := SpinBox.new()
	opacity_field.min_value = 0.0
	opacity_field.max_value = 1.0
	opacity_field.step = 0.01
	opacity_field.custom_arrow_step = 0.1
	opacity_field.custom_minimum_size = Vector2(0, 26)
	opacity_field.set_value_no_signal(clampf(float(material_data.get("opacity", 1.0)), 0.0, 1.0))
	opacity_field.value_changed.connect(_on_material_opacity_changed)
	inspector_content.add_child(opacity_field)

	inspector_content.add_child(_create_inspector_section("Mapping"))
	var mapping_grid := GridContainer.new()
	mapping_grid.columns = 2
	mapping_grid.add_theme_constant_override("h_separation", 8)
	mapping_grid.add_theme_constant_override("v_separation", 4)
	inspector_content.add_child(mapping_grid)
	var mapping_scale: Vector2 = material_data.get("mapping_scale", Vector2.ONE)
	_add_material_mapping_field(mapping_grid, "Scale X", mapping_scale.x, "scale_x")
	_add_material_mapping_field(mapping_grid, "Scale Y", mapping_scale.y, "scale_y")
	var mapping_offset: Vector2 = material_data.get("mapping_offset", Vector2.ZERO)
	_add_material_mapping_field(mapping_grid, "Offset X", mapping_offset.x, "offset_x")
	_add_material_mapping_field(mapping_grid, "Offset Y", mapping_offset.y, "offset_y")
	inspector_content.add_child(_create_inspector_field_label("Wrap Mode"))
	var wrap_option := OptionButton.new()
	wrap_option.custom_minimum_size = Vector2(0, 26)
	wrap_option.add_item("Fit")
	wrap_option.set_item_metadata(0, "fit")
	wrap_option.add_item("Clamp")
	wrap_option.set_item_metadata(1, "clamp")
	wrap_option.add_item("Repeat")
	wrap_option.set_item_metadata(2, "repeat")
	var wrap_mode := _material_wrap_mode(material_data)
	for index in range(wrap_option.item_count):
		if str(wrap_option.get_item_metadata(index)) == wrap_mode:
			wrap_option.select(index)
			break
	wrap_option.item_selected.connect(_on_material_wrap_mode_selected.bind(wrap_option))
	inspector_content.add_child(wrap_option)


func _render_lookdev_material_target_inspector() -> void:
	var material_data := _get_material(selected_material_id)
	var asset := _get_asset(lookdev_target_asset_id)
	var component := _get_component(asset, lookdev_target_component_id)
	if material_data.is_empty() or asset.is_empty() or component.is_empty():
		_render_material_inspector()
		return
	inspector_content.add_child(_create_inspector_field_label("Name"))
	var component_name := _create_inspector_field_label(str(component.get("name", "Component")))
	component_name.add_theme_color_override("font_color", Color("#d7dce5"))
	inspector_content.add_child(component_name)
	inspector_content.add_child(_create_inspector_field_label("Asset"))
	var asset_name := _create_inspector_field_label(str(asset.get("name", "Asset")))
	asset_name.add_theme_color_override("font_color", Color("#9aa3b2"))
	inspector_content.add_child(asset_name)
	inspector_content.add_child(_create_inspector_section("Material Assignment"))
	inspector_content.add_child(_create_inspector_field_label("Selected Material"))
	var selected_name := _create_inspector_field_label(str(material_data.get("name", "Material")))
	selected_name.add_theme_color_override("font_color", Color("#d7dce5"))
	inspector_content.add_child(selected_name)
	var assigned_id := str(component.get("material_id", ""))
	var assigned_name := "None"
	if not assigned_id.is_empty():
		assigned_name = str(_get_material(assigned_id).get("name", assigned_id))
	inspector_content.add_child(_create_inspector_field_label("Assigned: %s" % assigned_name))
	var assign_button := Button.new()
	assign_button.text = "Assign Material"
	assign_button.custom_minimum_size = Vector2(0, 26)
	assign_button.focus_mode = Control.FOCUS_NONE
	assign_button.disabled = assigned_id == selected_material_id
	assign_button.pressed.connect(_assign_selected_material_to_lookdev_target)
	inspector_content.add_child(assign_button)


func _add_material_mapping_field(grid: GridContainer, label_text: String, value: float, property_name: String) -> void:
	grid.add_child(_create_inspector_field_label(label_text))
	var field := SpinBox.new()
	field.min_value = -100.0 if property_name.begins_with("offset") else 0.01
	field.max_value = 100.0
	field.step = 0.01
	field.custom_arrow_step = 0.1
	field.custom_minimum_size = Vector2(96, 26)
	field.set_value_no_signal(value)
	field.value_changed.connect(_on_material_mapping_changed.bind(property_name))
	grid.add_child(field)


func _on_material_mapping_changed(value: float, property_name: String) -> void:
	var material_data := _get_material(selected_material_id)
	if material_data.is_empty():
		return
	_record_direct_change()
	var mapping_scale_value: Vector2 = material_data.get("mapping_scale", Vector2.ONE)
	var mapping_offset_value: Vector2 = material_data.get("mapping_offset", Vector2.ZERO)
	if property_name == "scale_x":
		mapping_scale_value.x = maxf(value, 0.01)
	elif property_name == "scale_y":
		mapping_scale_value.y = maxf(value, 0.01)
	elif property_name == "offset_x":
		mapping_offset_value.x = value
	elif property_name == "offset_y":
		mapping_offset_value.y = value
	material_data["mapping_scale"] = mapping_scale_value
	material_data["mapping_offset"] = mapping_offset_value
	_render_canvas_context()


func _on_material_wrap_mode_selected(index: int, option: OptionButton) -> void:
	var material_data := _get_material(selected_material_id)
	if material_data.is_empty() or index < 0 or index >= option.item_count:
		return
	var wrap_mode := str(option.get_item_metadata(index))
	if _material_wrap_mode(material_data) == wrap_mode:
		return
	_record_direct_change()
	material_data["mapping_wrap_mode"] = wrap_mode
	material_data["mapping_repeat"] = wrap_mode == "repeat"
	_render_canvas_context()


func _render_lookdev_asset_inspector() -> void:
	var asset := _get_asset(lookdev_target_asset_id)
	if asset.is_empty():
		_render_material_inspector()
		return
	inspector_content.add_child(_create_inspector_field_label("Name"))
	var name_editor := _create_name_editor(str(asset.get("name", "Asset")), "Asset name")
	name_editor.text_submitted.connect(_rename_lookdev_asset)
	name_editor.focus_exited.connect(func() -> void: _rename_lookdev_asset(name_editor.text))
	inspector_content.add_child(name_editor)
	inspector_content.add_child(_create_inspector_field_label("Components"))
	var component_count := _create_inspector_field_label(str(asset.get("components", []).size()))
	component_count.add_theme_color_override("font_color", Color("#9aa3b2"))
	inspector_content.add_child(component_count)


func _rename_lookdev_asset(new_name: String) -> void:
	var asset := _get_asset(lookdev_target_asset_id)
	var asset_name := new_name.strip_edges()
	if asset.is_empty() or asset_name.is_empty() or asset_name == str(asset.get("name", "")):
		return
	_record_direct_change()
	asset["name"] = asset_name
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _assign_selected_material_to_lookdev_target() -> void:
	var material_data := _get_material(selected_material_id)
	var asset := _get_asset(lookdev_target_asset_id)
	var component := _get_component(asset, lookdev_target_component_id)
	if material_data.is_empty() or component.is_empty() or str(component.get("material_id", "")) == selected_material_id:
		return
	_record_direct_change()
	component["material_id"] = selected_material_id
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _rename_selected_material(new_name: String) -> void:
	var material_data := _get_material(selected_material_id)
	var material_name := new_name.strip_edges()
	if material_data.is_empty():
		return
	if material_name.is_empty() or material_name == str(material_data.get("name", "")):
		return
	_record_direct_change()
	material_data["name"] = material_name
	_render_outliner()
	_render_inspector()


func _on_material_texture_selected(index: int, option: OptionButton) -> void:
	var material_data := _get_material(selected_material_id)
	if material_data.is_empty():
		return
	if index < 0 or index >= option.item_count:
		return
	_record_direct_change()
	material_data["texture_id"] = str(option.get_item_metadata(index))
	_render_inspector()
	_render_canvas_context()


func _on_material_tint_changed(color: Color) -> void:
	var material_data := _get_material(selected_material_id)
	if material_data.is_empty():
		return
	_record_direct_change()
	material_data["tint"] = color
	_render_canvas_context()


func _on_material_opacity_changed(value: float) -> void:
	var material_data := _get_material(selected_material_id)
	if material_data.is_empty():
		return
	_record_direct_change()
	material_data["opacity"] = clampf(value, 0.0, 1.0)
	_render_canvas_context()


func _render_inspector() -> void:
	_ensure_default_edit_point_state()
	_clear(inspector_content)
	transform_fields.clear()
	if active_module == "Motion":
		if active_motion_submodule == "Path":
			_render_motion_path_inspector()
		elif active_motion_submodule == "Act":
			_render_motion_act_inspector()
		elif active_motion_submodule == "Sequence":
			_render_motion_sequence_inspector()
		else:
			_render_motion_inspector()
		return
	if active_module == "Export":
		inspector_content.add_child(_create_inspector_section("Build"))
		inspector_content.add_child(_create_inspector_field_label("Source Asset"))
		inspector_content.add_child(_create_inspector_field_label(str(_get_asset(selected_asset_id).get("name", "None"))))
		inspector_content.add_child(_create_inspector_field_label("Output Path"))
		inspector_content.add_child(_create_inspector_field_label("res://exports/"))
		inspector_content.add_child(_create_inspector_field_label("Format"))
		inspector_content.add_child(_create_inspector_field_label("Godot Scene (.tscn)"))
		return
	if active_module == "Style":
		_render_material_inspector()
		return
	if active_module == "Geometry":
		inspector_content.add_child(_create_inspector_section(active_geometry_submodule))
		inspector_content.add_child(_create_inspector_field_label("Placeholder module"))
		inspector_content.add_child(_create_inspector_field_label("Geometry pipeline tooling is planned for a later phase."))
		return
	if not selected_texture_id.is_empty():
		var texture := _get_texture(selected_texture_id)
		if texture.is_empty():
			return
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
			threshold_field.custom_arrow_step = 0.1
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
		inspector_content.add_child(_create_inspector_field_label("Name"))
		asset_name_editor = _create_name_editor(str(asset["name"]), "Asset name")
		asset_name_editor.text_submitted.connect(_rename_selected_asset)
		asset_name_editor.focus_exited.connect(func() -> void:
			_rename_selected_asset(asset_name_editor.text)
		)
		inspector_content.add_child(asset_name_editor)
		var reference_image := _normalize_reference_image(asset.get("reference_image", {}))
		inspector_content.add_child(_create_inspector_section("Reference Image"))
		var reference_buttons := HBoxContainer.new()
		var load_reference_button := Button.new()
		load_reference_button.text = "Load Image" if str(reference_image.get("file", "")).is_empty() else "Replace Image"
		load_reference_button.custom_minimum_size = Vector2(0, 26)
		load_reference_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		load_reference_button.focus_mode = Control.FOCUS_NONE
		load_reference_button.pressed.connect(_open_reference_image_dialog)
		reference_buttons.add_child(load_reference_button)
		if not str(reference_image.get("file", "")).is_empty():
			var clear_reference_button := Button.new()
			clear_reference_button.text = "Clear"
			clear_reference_button.custom_minimum_size = Vector2(64, 26)
			clear_reference_button.focus_mode = Control.FOCUS_NONE
			clear_reference_button.pressed.connect(_clear_reference_image)
			reference_buttons.add_child(clear_reference_button)
		inspector_content.add_child(reference_buttons)
		if not str(reference_image.get("file", "")).is_empty():
			var reference_file_label := _create_inspector_field_label(str(reference_image.get("file", "")))
			reference_file_label.add_theme_color_override("font_color", Color("#9aa3b2"))
			inspector_content.add_child(reference_file_label)
		var target_height := SpinBox.new()
		target_height.min_value = 0.01
		target_height.max_value = 100000.0
		target_height.step = 0.01
		target_height.custom_arrow_step = 0.1
		target_height.custom_minimum_size = Vector2(0, 26)
		target_height.value = float(reference_image.get("target_height_cm", 13.0))
		target_height.value_changed.connect(_on_reference_image_target_height_changed)
		inspector_content.add_child(_create_inspector_field_label("Target Height (cm)"))
		inspector_content.add_child(target_height)
		var pivot_label := _create_inspector_field_label("Pivot")
		inspector_content.add_child(pivot_label)
		var pivot_option := OptionButton.new()
		pivot_option.custom_minimum_size = Vector2(0, 26)
		pivot_option.add_item("Center")
		pivot_option.set_item_metadata(0, "center")
		pivot_option.add_item("Bottom Center")
		pivot_option.set_item_metadata(1, "bottom_center")
		var pivot_mode := str(reference_image.get("pivot_mode", "bottom_center"))
		for pivot_index in range(pivot_option.item_count):
			if str(pivot_option.get_item_metadata(pivot_index)) == pivot_mode:
				pivot_option.select(pivot_index)
				break
		pivot_option.item_selected.connect(_on_reference_image_pivot_selected.bind(pivot_option))
		inspector_content.add_child(pivot_option)
		if not str(reference_image.get("file", "")).is_empty():
			inspector_content.add_child(_create_inspector_section("Reference Image Settings"))
			var reference_visibility := CheckBox.new()
			reference_visibility.text = "Visible"
			reference_visibility.focus_mode = Control.FOCUS_NONE
			reference_visibility.button_pressed = bool(reference_image.get("visible", true))
			reference_visibility.toggled.connect(_on_reference_image_visibility_changed)
			inspector_content.add_child(reference_visibility)
			var reference_opacity := SpinBox.new()
			reference_opacity.name = "ReferenceImageOpacity"
			reference_opacity.min_value = 0.0
			reference_opacity.max_value = 1.0
			reference_opacity.step = 0.01
			reference_opacity.custom_arrow_step = 0.1
			reference_opacity.custom_minimum_size = Vector2(0, 26)
			reference_opacity.value = float(reference_image.get("opacity", 0.5))
			reference_opacity.value_changed.connect(_on_reference_image_property_changed.bind("opacity"))
			inspector_content.add_child(_create_inspector_field_label("Opacity"))
			inspector_content.add_child(reference_opacity)
			var reference_transform_grid := GridContainer.new()
			reference_transform_grid.columns = 2
			reference_transform_grid.add_theme_constant_override("h_separation", 8)
			reference_transform_grid.add_theme_constant_override("v_separation", 4)
			var reference_position: Vector2 = reference_image.get("position", Vector2.ZERO)
			_add_reference_image_field(reference_transform_grid, "Position X (cm)", _editor_units_to_world(reference_position.x), "position_x")
			_add_reference_image_field(reference_transform_grid, "Position Y (cm)", _editor_units_to_world(reference_position.y), "position_y")
			_add_reference_image_field(reference_transform_grid, "Scale", float(reference_image.get("scale", 1.0)), "scale")
			inspector_content.add_child(reference_transform_grid)
		return
	var component := _get_component(asset, selected_component_id)
	if component.is_empty():
		return
	if active_state == "edit" and active_edit_mode == "point":
		var point_ids := _valid_selected_point_ids(component)
		if point_ids.is_empty():
			inspector_content.add_child(_create_inspector_field_label("Edit Point"))
			inspector_content.add_child(_create_inspector_section("Point Settings"))
			var selection_hint := _create_inspector_field_label("Select one or more points to edit them.")
			selection_hint.add_theme_color_override("font_color", Color("#9aa3b2"))
			inspector_content.add_child(selection_hint)
			return
		var is_multi_point_selection := point_ids.size() > 1
		inspector_content.add_child(_create_inspector_field_label("%d Points" % point_ids.size() if is_multi_point_selection else "Point"))
		inspector_content.add_child(_create_inspector_section("Transform"))
		var point_transform_grid := GridContainer.new()
		point_transform_grid.columns = 2
		point_transform_grid.add_theme_constant_override("h_separation", 8)
		point_transform_grid.add_theme_constant_override("v_separation", 4)
		if is_multi_point_selection:
			_add_selected_points_delta_field(point_transform_grid, "Delta X (cm)", "position_x")
			_add_selected_points_delta_field(point_transform_grid, "Delta Y (cm)", "position_y")
		else:
			var selected_point := BezierTopology.point_by_id(component.get("points", []), point_ids[0])
			var point_position: Vector2 = selected_point.get("position", Vector2.ZERO)
			_add_point_position_field(point_transform_grid, "Position X (cm)", _editor_units_to_world(point_position.x), "position_x")
			_add_point_position_field(point_transform_grid, "Position Y (cm)", _editor_units_to_world(point_position.y), "position_y")
		inspector_content.add_child(point_transform_grid)
		inspector_content.add_child(_create_inspector_section("Point Settings"))
		_add_selected_point_settings(component, point_ids)
		return
	if not selected_edge_id.is_empty():
		var selected_edge := _get_edge(component, selected_edge_id)
		if not selected_edge.is_empty():
			inspector_content.add_child(_create_inspector_field_label("Edge"))
			inspector_content.add_child(_create_inspector_section("Edge Settings"))
			var render_outline := CheckButton.new()
			render_outline.text = "Render Outline"
			render_outline.custom_minimum_size = Vector2(0, 26)
			render_outline.button_pressed = bool(selected_edge.get("render_outline", true))
			render_outline.toggled.connect(_on_edge_render_outline_changed)
			inspector_content.add_child(render_outline)
			return
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
	_add_transform_field(transform_grid, "Position X (cm)", _editor_units_to_world(transform_position.x), "position_x", 0.01)
	_add_transform_field(transform_grid, "Position Y (cm)", _editor_units_to_world(transform_position.y), "position_y", 0.01)
	_add_transform_field(transform_grid, "Rotation", float(transform.get("rotation", 0.0)), "rotation", 1.0)
	_add_transform_field(transform_grid, "Scale X", transform_scale.x, "scale_x", 0.01)
	_add_transform_field(transform_grid, "Scale Y", transform_scale.y, "scale_y", 0.01)
	_add_transform_field(transform_grid, "Pivot X (cm)", _editor_units_to_world(pivot.x), "pivot_x", 0.01)
	_add_transform_field(transform_grid, "Pivot Y (cm)", _editor_units_to_world(pivot.y), "pivot_y", 0.01)
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
	inspector_content.add_child(_create_inspector_section("Material"))
	var material_option := OptionButton.new()
	material_option.custom_minimum_size = Vector2(0, 26)
	inspector_content.add_child(_create_inspector_field_label("Assigned Material"))
	material_option.add_item("None")
	material_option.set_item_metadata(0, "")
	var sorted_materials: Array[Dictionary] = materials.duplicate(true)
	sorted_materials.sort_custom(_sort_named_documents)
	for material_record in sorted_materials:
		material_option.add_item(str(material_record.get("name", "Material")))
		material_option.set_item_metadata(material_option.item_count - 1, str(material_record.get("id", "")))
	var assigned_material_id := str(component.get("material_id", ""))
	for index in range(material_option.item_count):
		if str(material_option.get_item_metadata(index)) == assigned_material_id:
			material_option.select(index)
			break
	material_option.item_selected.connect(_on_component_material_selected.bind(material_option))
	inspector_content.add_child(material_option)


func _render_motion_inspector() -> void:
	inspector_content.add_child(_create_inspector_section("Animation Preview"))
	var asset := _get_asset(selected_asset_id)
	var preview_panel := _create_panel(Color("#171b22"))
	motion_asset_preview = MotionAssetPreview.new()
	motion_asset_preview.set_asset(asset)
	motion_asset_preview.set_runtime(motion_player.current_state_name() if motion_player != null else "None", motion_phase, motion_player.playing if motion_player != null else false)
	preview_panel.add_child(motion_asset_preview)
	inspector_content.add_child(preview_panel)
	if asset.is_empty():
		inspector_content.add_child(_create_inspector_field_label("Select an Asset in the Motion Outliner."))
		return
	if is_instance_valid(motion_workspace) and motion_workspace.asset_id != selected_asset_id:
		motion_selection.select_asset(selected_asset_id)
		motion_workspace.set_asset(selected_asset_id, str(asset.get("name", "Asset")), asset.get("components", []), _ensure_asset_animation(asset))
	_sync_motion_player_document(asset)
	_refresh_motion_asset_preview()
	var preview := motion_workspace.get_selected_preview() if is_instance_valid(motion_workspace) else {}
	if motion_selection.kind == MotionSelection.ASSET:
		_render_simulation_contract_inspector()
		_render_legacy_path_follow_migration(asset)
		_render_animation_validation_inspector()
		inspector_content.add_child(_create_inspector_field_label("Persisted with the Asset · evaluated beginning in Phase 8."))
		return
	if preview.is_empty():
		inspector_content.add_child(_create_inspector_field_label("Select a State or one of its Preview entries."))
		return
	var kind := str(preview.get("kind", MotionSelection.NONE))
	var state: Dictionary = preview.get("state", {})
	inspector_content.add_child(_create_inspector_section(kind.capitalize()))
	if kind == MotionSelection.STATE:
		var state_id := str(state.get("id", ""))
		inspector_content.add_child(_create_inspector_field_label("Name"))
		var state_name_editor := _create_name_editor(str(state.get("name", "State")), "State name")
		state_name_editor.text_submitted.connect(_rename_motion_state.bind(state_id, state_name_editor))
		state_name_editor.focus_exited.connect(func() -> void: _rename_motion_state(state_name_editor.text, state_id, state_name_editor))
		inspector_content.add_child(state_name_editor)
		inspector_content.add_child(_create_inspector_field_label("Cycle Duration (s)"))
		var cycle_duration := SpinBox.new()
		cycle_duration.min_value = 0.01
		cycle_duration.max_value = 3600.0
		cycle_duration.step = 0.05
		cycle_duration.value = float(state.get("cycle_duration", 1.0))
		cycle_duration.value_changed.connect(_on_motion_state_cycle_duration_changed.bind(state_id))
		inspector_content.add_child(cycle_duration)
		inspector_content.add_child(_create_motion_inspector_value("Motion", "%d Preview entries" % state.get("motions", []).size()))
		inspector_content.add_child(_create_motion_inspector_value("Transitions", "%d Preview entries" % state.get("transitions", []).size()))
		inspector_content.add_child(_create_motion_inspector_value("Markers", "%d Preview entries" % state.get("markers", []).size()))
		var remove_state_button := Button.new()
		remove_state_button.text = "Remove State"
		remove_state_button.custom_minimum_size = Vector2(0, 28)
		remove_state_button.focus_mode = Control.FOCUS_NONE
		remove_state_button.pressed.connect(_request_motion_state_removal.bind(state_id))
		inspector_content.add_child(remove_state_button)
	elif kind == MotionSelection.MOTION:
		var motion: Dictionary = preview.get("item", {})
		_render_motion_authoring_inspector(state, motion)
	elif kind == MotionSelection.TRANSITION:
		var transition: Dictionary = preview.get("item", {})
		_render_transition_authoring_inspector(state, transition)
	elif kind == MotionSelection.MARKER:
		var marker: Dictionary = preview.get("item", {})
		_render_marker_authoring_inspector(state, marker)
	else:
		var item: Dictionary = preview.get("item", {})
		inspector_content.add_child(_create_motion_inspector_value("State", str(state.get("name", "State"))))
		inspector_content.add_child(_create_motion_inspector_value("Name", motion_workspace.item_display_name(kind, item)))
		inspector_content.add_child(_create_motion_inspector_value("Preview", motion_workspace.item_summary(kind, item)))
		if kind == MotionSelection.TRANSITION:
			inspector_content.add_child(_create_motion_inspector_value("Priority", "List order · first eligible wins"))
	inspector_content.add_child(_create_inspector_field_label("Persisted Animation data · runtime evaluation follows in Phase 8."))


func _render_motion_act_inspector() -> void:
	inspector_content.add_child(_create_inspector_section("Act"))
	var act := _get_motion_act(selected_motion_act_id)
	if act.is_empty():
		inspector_content.add_child(_create_inspector_field_label("Add a Slide, Jump, or Blink with the + button in the Act list."))
		return
	var primitive := str(act.get("primitive", MotionActEvaluator.SLIDE))
	var primitive_label := MotionActEvaluator.primitive_label(primitive)
	inspector_content.add_child(_create_inspector_field_label("Name"))
	var name_editor := _create_name_editor(str(act.get("name", primitive_label)), "Act name")
	name_editor.text_submitted.connect(_rename_motion_act.bind(act, name_editor))
	name_editor.focus_exited.connect(func() -> void: _rename_motion_act(name_editor.text, act, name_editor))
	inspector_content.add_child(name_editor)
	inspector_content.add_child(_create_motion_inspector_value("Stable Act ID", str(act.get("id", ""))))
	var enabled_toggle := CheckBox.new()
	enabled_toggle.text = "Enabled"
	enabled_toggle.button_pressed = bool(act.get("enabled", true))
	enabled_toggle.toggled.connect(_on_motion_act_enabled_changed)
	inspector_content.add_child(enabled_toggle)
	inspector_content.add_child(_create_inspector_section("Primitive"))
	inspector_content.add_child(_create_motion_inspector_value("Type", primitive_label))
	var parameters: Dictionary = act.get("parameters", {})
	var direction: Vector2 = parameters.get("direction", Vector2.RIGHT)
	inspector_content.add_child(_create_inspector_field_label("Direction"))
	var direction_grid := GridContainer.new()
	direction_grid.columns = 2
	for axis_data in [["X", direction.x, "x"], ["Y", direction.y, "y"]]:
		direction_grid.add_child(_create_inspector_field_label(str(axis_data[0])))
		var field := SpinBox.new()
		field.min_value = -1000.0
		field.max_value = 1000.0
		field.step = 0.05
		field.value = float(axis_data[1])
		field.value_changed.connect(_on_motion_act_direction_changed.bind(str(axis_data[2])))
		direction_grid.add_child(field)
	inspector_content.add_child(direction_grid)
	inspector_content.add_child(_create_inspector_field_label("Distance (cm)"))
	var distance := SpinBox.new()
	distance.min_value = 0.0
	distance.max_value = 100000.0
	distance.step = 0.1
	distance.value = float(parameters.get("distance", 4.0))
	distance.value_changed.connect(_on_motion_act_number_changed.bind("distance"))
	inspector_content.add_child(distance)
	if primitive == MotionActEvaluator.JUMP:
		inspector_content.add_child(_create_inspector_field_label("Height (cm)"))
		var height := SpinBox.new()
		height.min_value = 0.01
		height.max_value = 100000.0
		height.step = 0.1
		height.value = float(parameters.get("height", 3.0))
		height.value_changed.connect(_on_motion_act_number_changed.bind("height"))
		inspector_content.add_child(height)
		inspector_content.add_child(_create_inspector_field_label("Arc Shape"))
		var arc_option := OptionButton.new()
		var current_arc := str(parameters.get("arc", MotionActEvaluator.JUMP_ARC_SMOOTH))
		for arc in MotionActEvaluator.JUMP_ARC_OPTIONS:
			arc_option.add_item(MotionActEvaluator.jump_arc_label(arc))
			arc_option.set_item_metadata(arc_option.item_count - 1, arc)
			if arc == current_arc:
				arc_option.select(arc_option.item_count - 1)
		arc_option.item_selected.connect(_on_motion_act_jump_arc_selected.bind(arc_option))
		inspector_content.add_child(arc_option)
	elif primitive == MotionActEvaluator.BLINK:
		_add_motion_act_parameter_field("Anticipation Distance (cm)", float(parameters.get("anticipation_distance", 1.0)), "anticipation_distance", 0.0, 100000.0, 0.1)
		var anticipation_share := float(parameters.get("anticipation_share", 0.5))
		var anticipation_field := _add_motion_act_parameter_field("Anticipation Share", anticipation_share, "anticipation_share", 0.01, 0.89, 0.01)
		_add_motion_act_parameter_field("Minimum Scale", float(parameters.get("minimum_scale", 0.05)), "minimum_scale", 0.01, 1.0, 0.01)
		var timing_split := _create_motion_inspector_value("Timing Split", _motion_act_blink_timing_text(anticipation_share))
		inspector_content.add_child(timing_split)
		anticipation_field.value_changed.connect(func(value: float) -> void:
			var timing_value := timing_split.get_child(1) as Label
			if is_instance_valid(timing_value):
				timing_value.text = _motion_act_blink_timing_text(value)
		)
	inspector_content.add_child(_create_inspector_section("Timing"))
	inspector_content.add_child(_create_inspector_field_label("Duration (s)"))
	var duration := SpinBox.new()
	duration.min_value = 0.01
	duration.max_value = 3600.0
	duration.step = 0.05
	duration.value = float(act.get("timing", {}).get("duration", 0.6))
	duration.value_changed.connect(_on_motion_act_number_changed.bind("duration"))
	inspector_content.add_child(duration)
	inspector_content.add_child(_create_inspector_field_label("Easing"))
	var easing_option := OptionButton.new()
	var current_easing := str(act.get("timing", {}).get("easing", MotionActEvaluator.EASE_IN_OUT))
	for easing in MotionActEvaluator.EASING_OPTIONS:
		easing_option.add_item(MotionActEvaluator.easing_label(easing))
		easing_option.set_item_metadata(easing_option.item_count - 1, easing)
		if easing == current_easing:
			easing_option.select(easing_option.item_count - 1)
	easing_option.item_selected.connect(_on_motion_act_easing_selected.bind(easing_option))
	inspector_content.add_child(easing_option)
	var issues := MotionActEvaluator.validation_issues(act)
	var validation := _create_inspector_field_label("Ready for Preview" if issues.is_empty() else str(issues[0]))
	validation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validation.add_theme_color_override("font_color", Color("#75b88a") if issues.is_empty() else Color("#f2c94c"))
	inspector_content.add_child(validation)
	var remove_button := Button.new()
	remove_button.text = "Remove Act"
	remove_button.pressed.connect(_remove_selected_motion_act)
	inspector_content.add_child(remove_button)


func _rename_motion_act(new_name: String, act: Dictionary, editor: LineEdit) -> void:
	var clean_name := new_name.strip_edges()
	if clean_name.is_empty():
		editor.text = str(act.get("name", MotionActEvaluator.primitive_label(str(act.get("primitive", MotionActEvaluator.SLIDE)))))
		return
	if clean_name == str(act.get("name", "")):
		return
	_record_direct_change()
	act["name"] = clean_name
	_refresh_motion_act_workspace()


func _on_motion_act_enabled_changed(enabled: bool) -> void:
	var act := _get_motion_act(selected_motion_act_id)
	if act.is_empty(): return
	_record_direct_change()
	act["enabled"] = enabled
	motion_act_playing = false
	_render_context_bar()
	_refresh_motion_act_workspace()


func _on_motion_act_direction_changed(value: float, axis: String) -> void:
	var act := _get_motion_act(selected_motion_act_id)
	if act.is_empty(): return
	_record_coalesced_change()
	var direction: Vector2 = act["parameters"].get("direction", Vector2.RIGHT)
	if axis == "x": direction.x = value
	else: direction.y = value
	act["parameters"]["direction"] = direction
	_refresh_motion_act_workspace()
	_render_context_bar()


func _on_motion_act_number_changed(value: float, property_name: String) -> void:
	var act := _get_motion_act(selected_motion_act_id)
	if act.is_empty(): return
	_record_coalesced_change()
	if property_name == "distance":
		act["parameters"]["distance"] = maxf(0.0, value)
	elif property_name == "height" and str(act.get("primitive", "")) == MotionActEvaluator.JUMP:
		act["parameters"]["height"] = maxf(0.01, value)
	elif property_name == "anticipation_distance" and str(act.get("primitive", "")) == MotionActEvaluator.BLINK:
		act["parameters"]["anticipation_distance"] = maxf(0.0, value)
	elif property_name == "anticipation_share" and str(act.get("primitive", "")) == MotionActEvaluator.BLINK:
		act["parameters"]["anticipation_share"] = clampf(value, 0.01, 0.89)
	elif property_name == "minimum_scale" and str(act.get("primitive", "")) == MotionActEvaluator.BLINK:
		act["parameters"]["minimum_scale"] = clampf(value, 0.01, 1.0)
	elif property_name == "duration":
		act["timing"]["duration"] = maxf(0.01, value)
	_refresh_motion_act_workspace()


func _add_motion_act_parameter_field(label_text: String, value: float, property_name: String, minimum: float, maximum: float, step: float) -> SpinBox:
	inspector_content.add_child(_create_inspector_field_label(label_text))
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.value = value
	field.value_changed.connect(_on_motion_act_number_changed.bind(property_name))
	inspector_content.add_child(field)
	return field


func _motion_act_blink_timing_text(anticipation_share: float) -> String:
	var clamped_share := clampf(anticipation_share, 0.01, 0.89)
	var ingress_share := (1.0 - clamped_share) * 0.8
	var exit_share := (1.0 - clamped_share) * 0.2
	return "%.0f%% · %.0f%% · %.0f%%" % [clamped_share * 100.0, ingress_share * 100.0, exit_share * 100.0]


func _on_motion_act_jump_arc_selected(index: int, option: OptionButton) -> void:
	var act := _get_motion_act(selected_motion_act_id)
	if act.is_empty() or str(act.get("primitive", "")) != MotionActEvaluator.JUMP or index < 0 or index >= option.item_count:
		return
	var arc := str(option.get_item_metadata(index))
	if arc not in MotionActEvaluator.JUMP_ARC_OPTIONS:
		return
	_record_direct_change()
	act["parameters"]["arc"] = arc
	_refresh_motion_act_workspace()


func _on_motion_act_easing_selected(index: int, option: OptionButton) -> void:
	var act := _get_motion_act(selected_motion_act_id)
	if act.is_empty() or index < 0 or index >= option.item_count: return
	_record_direct_change()
	act["timing"]["easing"] = str(option.get_item_metadata(index))
	_refresh_motion_act_workspace()


func _remove_selected_motion_act() -> void:
	var index := -1
	for candidate_index in range(motion_acts.size()):
		if str(motion_acts[candidate_index].get("id", "")) == selected_motion_act_id:
			index = candidate_index
			break
	if index < 0: return
	_record_direct_change()
	motion_acts.remove_at(index)
	selected_motion_act_id = str(motion_acts[mini(index, motion_acts.size() - 1)].get("id", "")) if not motion_acts.is_empty() else ""
	motion_act_phase = 0.0
	motion_act_playing = false
	_render_inspector()
	_render_canvas_context()


func _render_motion_path_inspector() -> void:
	inspector_content.add_child(_create_inspector_section("Path"))
	var path_document := _get_motion_path(selected_motion_path_id)
	if path_document.is_empty():
		inspector_content.add_child(_create_inspector_field_label("Create or select an independent Path resource."))
		return
	inspector_content.add_child(_create_inspector_field_label("Name"))
	var name_editor := _create_name_editor(str(path_document.get("name", "Path")), "Path name")
	name_editor.text_submitted.connect(_rename_motion_path.bind(path_document, name_editor))
	name_editor.focus_exited.connect(func() -> void: _rename_motion_path(name_editor.text, path_document, name_editor))
	inspector_content.add_child(name_editor)
	inspector_content.add_child(_create_motion_inspector_value("Stable Resource ID", str(path_document.get("id", ""))))
	inspector_content.add_child(_create_inspector_section("Path Preview"))
	inspector_content.add_child(_create_inspector_field_label("Preview Asset · editor-only"))
	var preview_asset_option := OptionButton.new()
	preview_asset_option.custom_minimum_size = Vector2(0, 28)
	preview_asset_option.add_item("No Preview Asset")
	preview_asset_option.set_item_metadata(0, "")
	for asset in assets:
		preview_asset_option.add_item(str(asset.get("name", "Asset")))
		preview_asset_option.set_item_metadata(preview_asset_option.item_count - 1, str(asset.get("id", "")))
		if str(asset.get("id", "")) == motion_path_preview_asset_id:
			preview_asset_option.select(preview_asset_option.item_count - 1)
	preview_asset_option.item_selected.connect(_on_motion_path_preview_asset_selected.bind(preview_asset_option))
	inspector_content.add_child(preview_asset_option)
	var playback: Dictionary = path_document.get("playback", {})
	inspector_content.add_child(_create_inspector_field_label("Duration (s)"))
	var duration_input := SpinBox.new()
	duration_input.min_value = 0.01
	duration_input.max_value = 3600.0
	duration_input.step = 0.05
	duration_input.value = float(playback.get("duration", 2.0))
	duration_input.value_changed.connect(_on_motion_path_duration_changed)
	inspector_content.add_child(duration_input)
	var loop_toggle := CheckBox.new()
	loop_toggle.text = "Loop"
	loop_toggle.button_pressed = bool(playback.get("loop", true))
	loop_toggle.toggled.connect(_on_motion_path_playback_toggle.bind("loop"))
	inspector_content.add_child(loop_toggle)
	var orient_toggle := CheckBox.new()
	orient_toggle.text = "Orient Along Path"
	orient_toggle.button_pressed = bool(playback.get("orient_along_path", false))
	orient_toggle.toggled.connect(_on_motion_path_playback_toggle.bind("orient_along_path"))
	inspector_content.add_child(orient_toggle)
	inspector_content.add_child(_create_inspector_section("Path Geometry"))
	var topology: Dictionary = path_document.get("topology", {})
	inspector_content.add_child(_create_motion_inspector_value("Points", str(topology.get("points", []).size())))
	inspector_content.add_child(_create_motion_inspector_value("Segments", str(topology.get("segments", []).size())))
	inspector_content.add_child(_create_motion_inspector_value("Ownership", "Independent Workspace resource · no Asset reference"))
	var validation := MotionPathTopology.validate(topology)
	var sample := MotionPathSampler.sample(topology, 0.5)
	var validation_text := "Ready for Preview · %.2f cm" % float(sample.get("length", 0.0))
	if topology.get("points", []).size() < 2:
		validation_text = "Add at least two Points."
	elif not validation.is_empty():
		validation_text = "Invalid · %s" % validation[0]
	elif not bool(sample.get("valid", false)):
		validation_text = "Invalid · Path length must be greater than zero."
	elif _get_asset(motion_path_preview_asset_id).is_empty():
		validation_text = "Select a Preview Asset."
	var validation_label := _create_inspector_field_label(validation_text)
	validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validation_label.add_theme_color_override("font_color", Color("#75b88a") if _motion_path_is_previewable(path_document) else Color("#f2c94c"))
	inspector_content.add_child(validation_label)


func _on_motion_path_preview_asset_selected(index: int, option: OptionButton) -> void:
	if index < 0 or index >= option.item_count:
		return
	motion_path_preview_asset_id = str(option.get_item_metadata(index))
	motion_path_playing = false
	_refresh_motion_path_workspace()
	_render_context_bar()
	_render_info_bar()


func _on_motion_path_duration_changed(value: float) -> void:
	var path_document := _get_motion_path(selected_motion_path_id)
	if path_document.is_empty():
		return
	_record_coalesced_change()
	path_document["playback"]["duration"] = maxf(0.01, value)


func _on_motion_path_playback_toggle(enabled: bool, property_name: String) -> void:
	var path_document := _get_motion_path(selected_motion_path_id)
	if path_document.is_empty() or property_name not in ["loop", "orient_along_path"]:
		return
	_record_direct_change()
	path_document["playback"][property_name] = enabled
	_refresh_motion_path_workspace()


func _render_motion_sequence_inspector() -> void:
	inspector_content.add_child(_create_inspector_section("Sequence"))
	var sequence_document := _get_motion_sequence(selected_motion_sequence_id)
	if sequence_document.is_empty():
		inspector_content.add_child(_create_inspector_field_label("Create or select a Sequence resource."))
		return
	var entry := _resolved_motion_sequence_entry(sequence_document)
	if motion_sequence_view == MotionSequenceWorkspace.VIEW_PLAYER:
		inspector_content.add_child(_create_motion_inspector_value("Stable Resource ID", str(sequence_document.get("id", ""))))
		_render_motion_sequence_player_inspector(entry)
		return
	inspector_content.add_child(_create_inspector_field_label("Name"))
	var name_editor := _create_name_editor(str(sequence_document.get("name", "Sequence")), "Sequence name")
	name_editor.text_submitted.connect(_rename_motion_sequence.bind(sequence_document, name_editor))
	name_editor.focus_exited.connect(func() -> void: _rename_motion_sequence(name_editor.text, sequence_document, name_editor))
	inspector_content.add_child(name_editor)
	inspector_content.add_child(_create_motion_inspector_value("Stable Resource ID", str(sequence_document.get("id", ""))))
	inspector_content.add_child(_create_motion_inspector_value("Entries", "%d composition entries" % sequence_document.get("entries", []).size()))
	if entry.is_empty():
		inspector_content.add_child(_create_inspector_field_label("Add one Composition Entry to reference an Asset, Animation State, and Path."))
		return
	inspector_content.add_child(_create_inspector_section("Composition Entry"))
	var entry_name := _create_name_editor(str(entry.get("name", "Composition Entry")), "Entry name")
	entry_name.text_submitted.connect(_rename_motion_sequence_entry.bind(entry, entry_name))
	entry_name.focus_exited.connect(func() -> void: _rename_motion_sequence_entry(entry_name.text, entry, entry_name))
	inspector_content.add_child(entry_name)
	var enabled_toggle := CheckBox.new()
	enabled_toggle.text = "Enabled"
	enabled_toggle.button_pressed = bool(entry.get("enabled", true))
	enabled_toggle.toggled.connect(_on_motion_sequence_entry_enabled_changed)
	inspector_content.add_child(enabled_toggle)
	inspector_content.add_child(_create_inspector_field_label("Asset"))
	var asset_option := OptionButton.new()
	asset_option.add_item("Select Asset")
	asset_option.set_item_metadata(0, "")
	for asset in assets:
		asset_option.add_item(str(asset.get("name", "Asset")))
		asset_option.set_item_metadata(asset_option.item_count - 1, str(asset.get("id", "")))
		if str(asset.get("id", "")) == str(entry.get("asset_id", "")):
			asset_option.select(asset_option.item_count - 1)
	asset_option.item_selected.connect(_on_motion_sequence_asset_selected.bind(asset_option))
	inspector_content.add_child(asset_option)
	inspector_content.add_child(_create_inspector_field_label("Animation State"))
	var state_option := OptionButton.new()
	state_option.add_item("Select State")
	state_option.set_item_metadata(0, "")
	var resolved_asset := _get_asset(str(entry.get("asset_id", "")))
	for state in resolved_asset.get("animation", {}).get("states", []):
		state_option.add_item(str(state.get("name", "State")))
		state_option.set_item_metadata(state_option.item_count - 1, str(state.get("id", "")))
		if str(state.get("id", "")) == str(entry.get("animation_state_id", "")):
			state_option.select(state_option.item_count - 1)
	state_option.item_selected.connect(_on_motion_sequence_state_selected.bind(state_option))
	inspector_content.add_child(state_option)
	inspector_content.add_child(_create_inspector_field_label("Path"))
	var path_option := OptionButton.new()
	path_option.add_item("Select Path")
	path_option.set_item_metadata(0, "")
	for path_document in motion_paths:
		path_option.add_item(str(path_document.get("name", "Path")))
		path_option.set_item_metadata(path_option.item_count - 1, str(path_document.get("id", "")))
		if str(path_document.get("id", "")) == str(entry.get("path_id", "")):
			path_option.select(path_option.item_count - 1)
	path_option.item_selected.connect(_on_motion_sequence_path_selected.bind(path_option))
	inspector_content.add_child(path_option)
	var context := _motion_sequence_entry_context(entry)
	var issues := MotionSequenceEvaluator.validation_issues(entry, context.get("asset", {}), context.get("path", {}))
	var validation_label := _create_inspector_field_label("Ready for Playback" if issues.is_empty() else "Incomplete · %s" % issues[0])
	validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validation_label.add_theme_color_override("font_color", Color("#75b88a") if issues.is_empty() else Color("#f2c94c"))
	inspector_content.add_child(validation_label)
	var remove_button := Button.new()
	remove_button.text = "Remove Entry"
	remove_button.pressed.connect(_remove_motion_sequence_entry)
	inspector_content.add_child(remove_button)


func _render_motion_sequence_player_inspector(entry: Dictionary) -> void:
	inspector_content.add_child(_create_inspector_section("Resolved Entry"))
	var context := _motion_sequence_entry_context(entry)
	var asset: Dictionary = context.get("asset", {})
	var path_document: Dictionary = context.get("path", {})
	var snapshot := MotionSequenceEvaluator.evaluate(entry, asset, path_document, motion_sequence_phase)
	inspector_content.add_child(_create_motion_inspector_value("Asset", str(asset.get("name", "Missing Asset"))))
	inspector_content.add_child(_create_motion_inspector_value("State", str(snapshot.get("state_name", "Missing State"))))
	inspector_content.add_child(_create_motion_inspector_value("Path", str(path_document.get("name", "Missing Path"))))
	inspector_content.add_child(_create_inspector_section("Runtime"))
	var sequence_phase_field := _create_motion_inspector_value("Sequence Phase", "%.2f" % motion_sequence_phase)
	motion_sequence_runtime_sequence_label = sequence_phase_field.get_child(1) as Label
	inspector_content.add_child(sequence_phase_field)
	var path_phase_field := _create_motion_inspector_value("Path Phase", "%.2f" % float(snapshot.get("path_phase", 0.0)))
	motion_sequence_runtime_path_label = path_phase_field.get_child(1) as Label
	inspector_content.add_child(path_phase_field)
	var animation_phase_field := _create_motion_inspector_value("Animation Phase", "%.2f" % float(snapshot.get("animation_phase", 0.0)))
	motion_sequence_runtime_animation_label = animation_phase_field.get_child(1) as Label
	inspector_content.add_child(animation_phase_field)
	inspector_content.add_child(_create_motion_inspector_value("Duration", "%.2f s · inherited from Path" % float(snapshot.get("duration", 0.0))))
	var issues: Array = snapshot.get("issues", [])
	var status := _create_inspector_field_label("Ready for Playback" if issues.is_empty() else "Blocked · %s" % issues[0])
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("#75b88a") if issues.is_empty() else Color("#f2c94c"))
	inspector_content.add_child(status)


func _rename_motion_sequence_entry(new_name: String, entry: Dictionary, editor: LineEdit) -> void:
	var normalized := new_name.strip_edges()
	if normalized.is_empty():
		editor.text = str(entry.get("name", "Composition Entry"))
		return
	if normalized == str(entry.get("name", "")):
		return
	_record_direct_change()
	entry["name"] = normalized
	_refresh_motion_sequence_workspace()


func _on_motion_sequence_entry_enabled_changed(enabled: bool) -> void:
	var entry := _resolved_motion_sequence_entry(_get_motion_sequence(selected_motion_sequence_id))
	if entry.is_empty() or bool(entry.get("enabled", true)) == enabled:
		return
	_record_direct_change()
	entry["enabled"] = enabled
	motion_sequence_playing = false
	_render_inspector()
	_render_context_bar()
	_refresh_motion_sequence_workspace()


func _on_motion_sequence_asset_selected(index: int, option: OptionButton) -> void:
	var entry := _resolved_motion_sequence_entry(_get_motion_sequence(selected_motion_sequence_id))
	if entry.is_empty() or index < 0 or index >= option.item_count:
		return
	_record_direct_change()
	entry["asset_id"] = str(option.get_item_metadata(index))
	entry["animation_state_id"] = _default_sequence_state_id(_get_asset(str(entry["asset_id"])))
	motion_sequence_playing = false
	_render_inspector()
	_render_context_bar()
	_refresh_motion_sequence_workspace()


func _on_motion_sequence_state_selected(index: int, option: OptionButton) -> void:
	var entry := _resolved_motion_sequence_entry(_get_motion_sequence(selected_motion_sequence_id))
	if entry.is_empty() or index < 0 or index >= option.item_count:
		return
	_record_direct_change()
	entry["animation_state_id"] = str(option.get_item_metadata(index))
	motion_sequence_playing = false
	_render_inspector()
	_render_context_bar()
	_refresh_motion_sequence_workspace()


func _on_motion_sequence_path_selected(index: int, option: OptionButton) -> void:
	var entry := _resolved_motion_sequence_entry(_get_motion_sequence(selected_motion_sequence_id))
	if entry.is_empty() or index < 0 or index >= option.item_count:
		return
	_record_direct_change()
	entry["path_id"] = str(option.get_item_metadata(index))
	motion_sequence_phase = 0.0
	motion_sequence_playing = false
	_render_inspector()
	_render_context_bar()
	_refresh_motion_sequence_workspace()


func _render_motion_authoring_inspector(state: Dictionary, motion: Dictionary) -> void:
	var state_id := str(state.get("id", ""))
	var motion_id := str(motion.get("id", ""))
	var domain := str(motion.get("domain", MotionWorkspace.OUTER))
	inspector_content.add_child(_create_motion_inspector_value("State", str(state.get("name", "State"))))
	inspector_content.add_child(_create_inspector_field_label("Name"))
	var name_editor := _create_name_editor(str(motion.get("name", "Motion")), "Motion name")
	name_editor.text_submitted.connect(_rename_motion.bind(state_id, motion_id, name_editor))
	name_editor.focus_exited.connect(func() -> void: _rename_motion(name_editor.text, state_id, motion_id, name_editor))
	inspector_content.add_child(name_editor)
	var enabled_toggle := CheckBox.new()
	enabled_toggle.text = "Enabled"
	enabled_toggle.button_pressed = bool(motion.get("enabled", true))
	enabled_toggle.toggled.connect(_on_motion_enabled_changed.bind(state_id, motion_id))
	inspector_content.add_child(enabled_toggle)
	inspector_content.add_child(_create_inspector_field_label("Domain"))
	var domain_option := OptionButton.new()
	domain_option.custom_minimum_size = Vector2(0, 28)
	for domain_data in [["Outer", MotionWorkspace.OUTER], ["Inner", MotionWorkspace.INNER]]:
		domain_option.add_item(str(domain_data[0]))
		domain_option.set_item_metadata(domain_option.item_count - 1, str(domain_data[1]))
		if str(domain_data[1]) == str(motion.get("domain", MotionWorkspace.OUTER)):
			domain_option.select(domain_option.item_count - 1)
	domain_option.item_selected.connect(_on_motion_domain_selected.bind(domain_option, state_id, motion_id))
	inspector_content.add_child(domain_option)
	inspector_content.add_child(_create_inspector_field_label("Target"))
	var target_option := OptionButton.new()
	target_option.custom_minimum_size = Vector2(0, 28)
	if domain == MotionWorkspace.OUTER:
		target_option.add_item("Entire Asset")
		target_option.set_item_metadata(0, {"scope": MotionWorkspace.TARGET_ASSET, "component_id": ""})
	target_option.add_item("Select Component")
	target_option.set_item_metadata(target_option.item_count - 1, {"scope": MotionWorkspace.TARGET_COMPONENT, "component_id": ""})
	var asset := _get_asset(selected_asset_id)
	for component in asset.get("components", []):
		target_option.add_item(str(component.get("name", "Component")))
		target_option.set_item_metadata(target_option.item_count - 1, {"scope": MotionWorkspace.TARGET_COMPONENT, "component_id": str(component.get("id", ""))})
	var target_scope := str(motion.get("target_scope", MotionWorkspace.TARGET_COMPONENT))
	var target_component_id := str(motion.get("target_component_id", ""))
	for target_index in range(target_option.item_count):
		var target_data: Dictionary = target_option.get_item_metadata(target_index)
		if str(target_data.get("scope", "")) == target_scope and str(target_data.get("component_id", "")) == target_component_id:
			target_option.select(target_index)
			break
	target_option.item_selected.connect(_on_motion_target_selected.bind(target_option, state_id, motion_id))
	inspector_content.add_child(target_option)
	inspector_content.add_child(_create_inspector_field_label("Primitive"))
	var primitive_option := OptionButton.new()
	primitive_option.custom_minimum_size = Vector2(0, 28)
	for primitive in motion_workspace.primitive_options(domain):
		primitive_option.add_item(motion_workspace.primitive_label(primitive))
		primitive_option.set_item_metadata(primitive_option.item_count - 1, primitive)
		if primitive == str(motion.get("primitive", MotionWorkspace.BOB)):
			primitive_option.select(primitive_option.item_count - 1)
	primitive_option.item_selected.connect(_on_motion_primitive_selected.bind(primitive_option, state_id, motion_id))
	inspector_content.add_child(primitive_option)
	var primitive := str(motion.get("primitive", MotionWorkspace.BOB))
	if domain == MotionWorkspace.INNER:
		_add_unavailable_motion_guide_field("Animation Guides", "Animation Spine authoring is not available yet.")
	inspector_content.add_child(_create_inspector_section("Parameters"))
	if primitive == MotionWorkspace.BOB:
		_add_motion_number_parameter("Distance", state_id, motion_id, "distance", float(motion.get("parameters", {}).get("distance", 0.25)), 0.0, 1000.0, 0.05)
	elif primitive == MotionWorkspace.SPINE_SWAY:
		_add_motion_number_parameter("Strength", state_id, motion_id, "strength", float(motion.get("parameters", {}).get("strength", 0.5)), 0.0, 1.0, 0.05)
	_add_motion_number_parameter("Cycles", state_id, motion_id, "cycles", float(motion.get("parameters", {}).get("cycles", 1.0)), 0.01, 100.0, 0.1)
	inspector_content.add_child(_create_inspector_field_label("Phase Offset"))
	var phase_offset := SpinBox.new()
	phase_offset.min_value = -1.0
	phase_offset.max_value = 1.0
	phase_offset.step = 0.01
	phase_offset.value = float(motion.get("phase_offset", 0.0))
	phase_offset.custom_minimum_size = Vector2(0, 28)
	phase_offset.value_changed.connect(_on_motion_phase_offset_changed.bind(state_id, motion_id))
	inspector_content.add_child(phase_offset)
	var validation := _motion_preview_validation(motion)
	var validation_label := Label.new()
	validation_label.text = validation
	validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validation_label.add_theme_font_size_override("font_size", 10)
	validation_label.add_theme_color_override("font_color", Color("#75b88a") if validation == "Ready for Preview" else Color("#f2c94c"))
	inspector_content.add_child(validation_label)
	var remove_button := Button.new()
	remove_button.text = "Remove Motion"
	remove_button.custom_minimum_size = Vector2(0, 28)
	remove_button.focus_mode = Control.FOCUS_NONE
	remove_button.pressed.connect(_request_motion_removal.bind(state_id, motion_id))
	inspector_content.add_child(remove_button)


func _render_transition_authoring_inspector(state: Dictionary, transition: Dictionary) -> void:
	var state_id := str(state.get("id", ""))
	var transition_id := str(transition.get("id", ""))
	inspector_content.add_child(_create_motion_inspector_value("Source State", str(state.get("name", "State"))))
	var priority_index := motion_workspace.transition_index(state_id, transition_id)
	var transition_count: int = state.get("transitions", []).size()
	var priority_row := HBoxContainer.new()
	var priority_label := Label.new()
	priority_label.text = "Priority #%d" % (priority_index + 1)
	priority_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	priority_row.add_child(priority_label)
	var move_up := Button.new()
	move_up.text = "↑"
	move_up.tooltip_text = "Higher priority"
	move_up.disabled = priority_index <= 0
	move_up.pressed.connect(_move_transition.bind(state_id, transition_id, -1))
	priority_row.add_child(move_up)
	var move_down := Button.new()
	move_down.text = "↓"
	move_down.tooltip_text = "Lower priority"
	move_down.disabled = priority_index < 0 or priority_index >= transition_count - 1
	move_down.pressed.connect(_move_transition.bind(state_id, transition_id, 1))
	priority_row.add_child(move_down)
	inspector_content.add_child(priority_row)
	inspector_content.add_child(_create_inspector_field_label("Target State"))
	var target_option := OptionButton.new()
	target_option.custom_minimum_size = Vector2(0, 28)
	var target_state_id := str(transition.get("target_state_id", ""))
	var target_exists := false
	for candidate in motion_workspace.get_states_for_asset(selected_asset_id):
		if str(candidate.get("id", "")) == target_state_id:
			target_exists = true
			break
	if not target_exists and not target_state_id.is_empty():
		target_option.add_item("Missing State")
		target_option.set_item_metadata(0, target_state_id)
		target_option.set_item_disabled(0, true)
	for candidate in motion_workspace.get_states_for_asset(selected_asset_id):
		var candidate_id := str(candidate.get("id", ""))
		if candidate_id == state_id:
			continue
		target_option.add_item(str(candidate.get("name", "State")))
		target_option.set_item_metadata(target_option.item_count - 1, candidate_id)
		if candidate_id == target_state_id:
			target_option.select(target_option.item_count - 1)
	target_option.item_selected.connect(_on_transition_target_selected.bind(target_option, state_id, transition_id))
	inspector_content.add_child(target_option)
	inspector_content.add_child(_create_inspector_field_label("Exit Policy"))
	var exit_option := OptionButton.new()
	for exit_data in [["Any Phase", MotionWorkspace.EXIT_ANY_PHASE], ["After Phase", MotionWorkspace.EXIT_AFTER_PHASE], ["At Loop End", MotionWorkspace.EXIT_LOOP_END]]:
		exit_option.add_item(str(exit_data[0]))
		exit_option.set_item_metadata(exit_option.item_count - 1, str(exit_data[1]))
		if str(exit_data[1]) == str(transition.get("exit_policy", MotionWorkspace.EXIT_ANY_PHASE)):
			exit_option.select(exit_option.item_count - 1)
	exit_option.item_selected.connect(_on_transition_exit_policy_selected.bind(exit_option, state_id, transition_id))
	inspector_content.add_child(exit_option)
	if str(transition.get("exit_policy", MotionWorkspace.EXIT_ANY_PHASE)) == MotionWorkspace.EXIT_AFTER_PHASE:
		inspector_content.add_child(_create_inspector_field_label("Exit After Phase"))
		var exit_phase := SpinBox.new()
		exit_phase.min_value = 0.0
		exit_phase.max_value = 1.0
		exit_phase.step = 0.01
		exit_phase.value = float(transition.get("exit_phase", 0.8))
		exit_phase.value_changed.connect(_on_transition_number_changed.bind(state_id, transition_id, "exit_phase"))
		inspector_content.add_child(exit_phase)
	inspector_content.add_child(_create_inspector_field_label("Entry Mode"))
	var entry_option := OptionButton.new()
	for entry_data in [["Restart", MotionWorkspace.ENTRY_RESTART], ["Preserve Phase", MotionWorkspace.ENTRY_PRESERVE_PHASE]]:
		entry_option.add_item(str(entry_data[0]))
		entry_option.set_item_metadata(entry_option.item_count - 1, str(entry_data[1]))
		if str(entry_data[1]) == str(transition.get("entry_mode", MotionWorkspace.ENTRY_RESTART)):
			entry_option.select(entry_option.item_count - 1)
	entry_option.item_selected.connect(_on_transition_entry_mode_selected.bind(entry_option, state_id, transition_id))
	inspector_content.add_child(entry_option)
	inspector_content.add_child(_create_inspector_field_label("Blend Duration (s)"))
	var blend_duration := SpinBox.new()
	blend_duration.min_value = 0.0
	blend_duration.max_value = 10.0
	blend_duration.step = 0.05
	blend_duration.value = float(transition.get("blend_duration", 0.15))
	blend_duration.value_changed.connect(_on_transition_number_changed.bind(state_id, transition_id, "blend_duration"))
	inspector_content.add_child(blend_duration)
	inspector_content.add_child(_create_inspector_section("Rules · ALL"))
	var rules: Array = transition.get("rules", [])
	if rules.is_empty():
		var no_rules := _create_inspector_field_label("No Rules · phase policy alone controls eligibility")
		no_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inspector_content.add_child(no_rules)
	for rule in rules:
		_render_transition_rule(state_id, transition_id, rule)
	var add_rule_button := Button.new()
	add_rule_button.text = "+ Add Rule"
	add_rule_button.disabled = motion_workspace.get_contract_parameters().is_empty()
	add_rule_button.tooltip_text = "Declare a Simulation Contract parameter first." if add_rule_button.disabled else "All Rules must match."
	add_rule_button.pressed.connect(_add_transition_rule.bind(state_id, transition_id))
	inspector_content.add_child(add_rule_button)
	var rules_valid := motion_workspace.transition_rules_valid(transition)
	var transition_validation := "Ready for future evaluation" if target_exists and rules_valid else ("Incomplete · Target State no longer exists" if not target_exists else "Incomplete · Rule references are invalid")
	var transition_validation_label := _create_inspector_field_label(transition_validation)
	transition_validation_label.add_theme_color_override("font_color", Color("#75b88a") if target_exists and rules_valid else Color("#f2c94c"))
	inspector_content.add_child(transition_validation_label)
	var remove_button := Button.new()
	remove_button.text = "Remove Transition"
	remove_button.pressed.connect(_request_motion_item_removal.bind(MotionSelection.TRANSITION, state_id, transition_id))
	inspector_content.add_child(remove_button)


func _render_simulation_contract_inspector() -> void:
	inspector_content.add_child(_create_inspector_section("Simulation Contract"))
	var explanation := _create_inspector_field_label("Typed inputs exposed by the host Simulation. Transition Rules reference stable parameter IDs.")
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_content.add_child(explanation)
	inspector_content.add_child(_create_motion_inspector_value("Source", "Persisted Asset Contract · future external import boundary"))
	var parameters := motion_workspace.get_contract_parameters()
	if parameters.is_empty():
		inspector_content.add_child(_create_inspector_field_label("No parameters declared."))
	for parameter in parameters:
		_render_contract_parameter(parameter)
	var add_parameter := Button.new()
	add_parameter.text = "+ Add Parameter"
	add_parameter.pressed.connect(_add_contract_parameter)
	inspector_content.add_child(add_parameter)
	_render_simulation_preview_values()


func _render_simulation_preview_values() -> void:
	inspector_content.add_child(_create_inspector_section("Simulation Preview Values"))
	var note := _create_inspector_field_label("Runtime-only values · used by the Phase 8 Transition evaluator")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_content.add_child(note)
	for parameter in motion_workspace.get_contract_parameters():
		var parameter_id := str(parameter.get("id", ""))
		var parameter_name := str(parameter.get("name", "parameter"))
		if str(parameter.get("type", MotionWorkspace.PARAM_NUMBER)) == MotionWorkspace.PARAM_BOOL:
			var bool_input := CheckBox.new()
			bool_input.text = parameter_name
			bool_input.button_pressed = bool(motion_player.parameter_value(parameter_id)) if motion_player != null else false
			bool_input.toggled.connect(_on_motion_runtime_bool_changed.bind(parameter_id))
			inspector_content.add_child(bool_input)
		else:
			inspector_content.add_child(_create_inspector_field_label(parameter_name))
			var number_input := SpinBox.new()
			number_input.min_value = -1000000.0
			number_input.max_value = 1000000.0
			number_input.step = 0.01
			number_input.value = float(motion_player.parameter_value(parameter_id)) if motion_player != null else 0.0
			number_input.value_changed.connect(_on_motion_runtime_number_changed.bind(parameter_id))
			inspector_content.add_child(number_input)


func _render_animation_validation_inspector() -> void:
	inspector_content.add_child(_create_inspector_section("Validation"))
	var issues := motion_workspace.validation_issues()
	if issues.is_empty():
		var ready := _create_inspector_field_label("Animation document is valid.")
		ready.add_theme_color_override("font_color", Color("#75b88a"))
		inspector_content.add_child(ready)
		return
	var summary := _create_inspector_field_label("%d issue%s" % [issues.size(), "" if issues.size() == 1 else "s"])
	summary.add_theme_color_override("font_color", Color("#f2c94c"))
	inspector_content.add_child(summary)
	for issue in issues:
		var issue_label := _create_inspector_field_label("• %s" % issue)
		issue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inspector_content.add_child(issue_label)


func _render_legacy_path_follow_migration(asset: Dictionary) -> void:
	var animation: Dictionary = asset.get("animation", {})
	var archived = animation.get("legacy_path_follow_motions", [])
	if not archived is Array or archived.is_empty():
		return
	inspector_content.add_child(_create_inspector_section("Phase 10 Migration"))
	var summary := _create_inspector_field_label("%d legacy Path Follow Motion%s retained in the Animation archive." % [archived.size(), "" if archived.size() == 1 else "s"])
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_color_override("font_color", Color("#f2c94c"))
	inspector_content.add_child(summary)
	var note := _create_inspector_field_label("They no longer evaluate as Animation primitives. Their original data remains persisted so it can be recreated as an independent Motion → Path resource in Phase 11.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_content.add_child(note)


func _render_contract_parameter(parameter: Dictionary) -> void:
	var parameter_id := str(parameter.get("id", ""))
	var panel := _create_panel(Color("#252b35"))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	var name_editor := _create_name_editor(str(parameter.get("name", "parameter")), "Parameter name")
	name_editor.text_submitted.connect(_rename_contract_parameter.bind(parameter_id, name_editor))
	name_editor.focus_exited.connect(func() -> void: _rename_contract_parameter(name_editor.text, parameter_id, name_editor))
	content.add_child(name_editor)
	var type_option := OptionButton.new()
	for type_data in [["Number", MotionWorkspace.PARAM_NUMBER], ["Bool", MotionWorkspace.PARAM_BOOL]]:
		type_option.add_item(str(type_data[0]))
		type_option.set_item_metadata(type_option.item_count - 1, str(type_data[1]))
		if str(type_data[1]) == str(parameter.get("type", MotionWorkspace.PARAM_NUMBER)):
			type_option.select(type_option.item_count - 1)
	type_option.item_selected.connect(_on_contract_parameter_type_selected.bind(type_option, parameter_id))
	content.add_child(type_option)
	var id_label := _create_inspector_field_label("Stable ID · %s" % parameter_id)
	id_label.add_theme_color_override("font_color", Color("#737f91"))
	content.add_child(id_label)
	var remove_parameter := Button.new()
	remove_parameter.text = "Remove Parameter"
	remove_parameter.pressed.connect(_remove_contract_parameter.bind(parameter_id))
	content.add_child(remove_parameter)
	inspector_content.add_child(panel)


func _render_transition_rule(state_id: String, transition_id: String, rule: Dictionary) -> void:
	var rule_id := str(rule.get("id", ""))
	var panel := _create_panel(Color("#252b35"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	panel.add_child(grid)
	grid.add_child(_create_inspector_field_label("Parameter"))
	var parameter_option := OptionButton.new()
	parameter_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var parameter_id := str(rule.get("parameter_id", ""))
	var parameter := motion_workspace.find_contract_parameter(parameter_id)
	if parameter.is_empty():
		parameter_option.add_item("Missing Parameter")
		parameter_option.set_item_metadata(0, parameter_id)
		parameter_option.set_item_disabled(0, true)
	for candidate in motion_workspace.get_contract_parameters():
		parameter_option.add_item(str(candidate.get("name", "parameter")))
		parameter_option.set_item_metadata(parameter_option.item_count - 1, str(candidate.get("id", "")))
		if str(candidate.get("id", "")) == parameter_id:
			parameter_option.select(parameter_option.item_count - 1)
	parameter_option.item_selected.connect(_on_transition_rule_parameter_selected.bind(parameter_option, state_id, transition_id, rule_id))
	grid.add_child(parameter_option)
	grid.add_child(_create_inspector_field_label("Operator"))
	var operator_option := OptionButton.new()
	var parameter_type := str(parameter.get("type", MotionWorkspace.PARAM_NUMBER))
	for operator in motion_workspace.rule_operators(parameter_type):
		operator_option.add_item(motion_workspace.rule_operator_label(operator))
		operator_option.set_item_metadata(operator_option.item_count - 1, operator)
		if operator == str(rule.get("operator", "")):
			operator_option.select(operator_option.item_count - 1)
	operator_option.disabled = parameter.is_empty()
	operator_option.item_selected.connect(_on_transition_rule_operator_selected.bind(operator_option, state_id, transition_id, rule_id))
	grid.add_child(operator_option)
	if parameter_type == MotionWorkspace.PARAM_NUMBER and not parameter.is_empty():
		grid.add_child(_create_inspector_field_label("Value"))
		var rule_value := SpinBox.new()
		rule_value.min_value = -1000000.0
		rule_value.max_value = 1000000.0
		rule_value.step = 0.01
		rule_value.value = float(rule.get("value", 0.0))
		rule_value.value_changed.connect(_on_transition_rule_value_changed.bind(state_id, transition_id, rule_id))
		grid.add_child(rule_value)
	grid.add_child(_create_inspector_field_label("Rule ID"))
	grid.add_child(_create_inspector_field_label(rule_id))
	var remove_rule := Button.new()
	remove_rule.text = "Remove Rule"
	remove_rule.pressed.connect(_remove_transition_rule.bind(state_id, transition_id, rule_id))
	grid.add_child(remove_rule)
	grid.add_child(Control.new())
	inspector_content.add_child(panel)


func _render_marker_authoring_inspector(state: Dictionary, marker: Dictionary) -> void:
	var state_id := str(state.get("id", ""))
	var marker_id := str(marker.get("id", ""))
	inspector_content.add_child(_create_motion_inspector_value("State", str(state.get("name", "State"))))
	inspector_content.add_child(_create_inspector_field_label("Event ID"))
	var event_editor := _create_name_editor(str(marker.get("event_id", "event")), "Event ID")
	event_editor.text_submitted.connect(_rename_marker_event.bind(state_id, marker_id, event_editor))
	event_editor.focus_exited.connect(func() -> void: _rename_marker_event(event_editor.text, state_id, marker_id, event_editor))
	inspector_content.add_child(event_editor)
	inspector_content.add_child(_create_inspector_field_label("Kind"))
	var kind_option := OptionButton.new()
	for kind_data in [["Event", MotionWorkspace.MARKER_EVENT], ["SFX", MotionWorkspace.MARKER_SFX], ["VFX", MotionWorkspace.MARKER_VFX]]:
		kind_option.add_item(str(kind_data[0]))
		kind_option.set_item_metadata(kind_option.item_count - 1, str(kind_data[1]))
		if str(kind_data[1]) == str(marker.get("kind", MotionWorkspace.MARKER_EVENT)):
			kind_option.select(kind_option.item_count - 1)
	kind_option.item_selected.connect(_on_marker_kind_selected.bind(kind_option, state_id, marker_id))
	inspector_content.add_child(kind_option)
	inspector_content.add_child(_create_inspector_field_label("Normalized Phase"))
	var marker_phase := SpinBox.new()
	marker_phase.min_value = 0.0
	marker_phase.max_value = 1.0
	marker_phase.step = 0.01
	marker_phase.value = float(marker.get("phase", 0.5))
	marker_phase.value_changed.connect(_on_marker_phase_changed.bind(state_id, marker_id))
	inspector_content.add_child(marker_phase)
	var marker_note := _create_inspector_field_label("Marker ticks are shown below the normalized Phase scrubber.")
	marker_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_content.add_child(marker_note)
	var remove_button := Button.new()
	remove_button.text = "Remove Marker"
	remove_button.pressed.connect(_request_motion_item_removal.bind(MotionSelection.MARKER, state_id, marker_id))
	inspector_content.add_child(remove_button)


func _add_unavailable_motion_guide_field(label_text: String, tooltip: String) -> void:
	inspector_content.add_child(_create_inspector_field_label(label_text))
	var guide_option := OptionButton.new()
	guide_option.add_item("Not available")
	guide_option.disabled = true
	guide_option.tooltip_text = tooltip
	guide_option.custom_minimum_size = Vector2(0, 28)
	inspector_content.add_child(guide_option)


func _add_motion_number_parameter(label_text: String, state_id: String, motion_id: String, parameter_name: String, value: float, minimum: float, maximum: float, step: float) -> void:
	inspector_content.add_child(_create_inspector_field_label(label_text))
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.value = value
	field.custom_minimum_size = Vector2(0, 28)
	field.value_changed.connect(_on_motion_parameter_changed.bind(state_id, motion_id, parameter_name))
	inspector_content.add_child(field)


func _motion_preview_validation(motion: Dictionary) -> String:
	if not bool(motion.get("enabled", true)):
		return "Disabled · excluded from Preview"
	var domain := str(motion.get("domain", MotionWorkspace.OUTER))
	var target_scope := str(motion.get("target_scope", MotionWorkspace.TARGET_COMPONENT))
	if not (domain == MotionWorkspace.OUTER and target_scope == MotionWorkspace.TARGET_ASSET) and str(motion.get("target_component_id", "")).is_empty():
		return "Incomplete · Select a target Component"
	if target_scope == MotionWorkspace.TARGET_COMPONENT and _get_component(_get_asset(selected_asset_id), str(motion.get("target_component_id", ""))).is_empty():
		return "Incomplete · Target Component no longer exists"
	if domain == MotionWorkspace.INNER:
		return "Not Previewable · Animation Guides and mesh are not available"
	return "Ready for Preview"


func _create_motion_inspector_value(label_text: String, value_text: String) -> VBoxContainer:
	var field := VBoxContainer.new()
	field.add_theme_constant_override("separation", 1)
	field.add_child(_create_inspector_field_label(label_text))
	var value := Label.new()
	value.text = value_text
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.add_theme_font_size_override("font_size", 11)
	value.add_theme_color_override("font_color", Color("#d6dbe4"))
	field.add_child(value)
	return field


func _on_motion_selection_changed() -> void:
	_sync_motion_player_document(_get_asset(selected_asset_id))
	if motion_player != null and not motion_player.playing and not motion_selection.state_id.is_empty() and motion_player.current_state_id != motion_selection.state_id:
		motion_player.set_state(motion_selection.state_id)
	_render_inspector()
	_render_context_bar()
	_render_info_bar()


func _sync_motion_player_document(asset: Dictionary) -> void:
	if motion_player == null:
		return
	if asset.is_empty():
		motion_player.pause()
		motion_player.set_document({})
		motion_player_asset_id = ""
		return
	var next_asset_id := str(asset.get("id", ""))
	var changed_asset := motion_player_asset_id != next_asset_id
	if changed_asset:
		motion_player.pause()
		motion_player.parameter_values.clear()
	motion_player.set_document(_ensure_asset_animation(asset))
	motion_player_asset_id = next_asset_id
	if changed_asset:
		var states: Array = motion_player.document.get("states", [])
		if not states.is_empty():
			motion_player.set_state(str(states[0].get("id", "")), 0.0)


func _on_motion_player_phase_changed(value: float) -> void:
	motion_phase = clampf(value, 0.0, 1.0)
	if is_instance_valid(motion_phase_slider):
		motion_phase_slider.set_value_no_signal(motion_phase)
	if is_instance_valid(motion_phase_value_label):
		motion_phase_value_label.text = "%.2f" % motion_phase
	if is_instance_valid(motion_workspace):
		motion_workspace.set_phase(motion_phase)
	if is_instance_valid(motion_asset_preview):
		motion_asset_preview.set_runtime(motion_player.current_state_name(), motion_phase, motion_player.playing)
	_refresh_motion_asset_preview()


func _on_motion_player_state_changed(_previous_state_id: String, _state_id: String) -> void:
	if is_instance_valid(motion_runtime_state_label):
		motion_runtime_state_label.text = motion_player.current_state_name()
	if is_instance_valid(motion_phase_marks) and is_instance_valid(motion_workspace):
		motion_phase_marks.set_marker_phases(motion_workspace.marker_phases_for_state(motion_player.current_state_id))
	if is_instance_valid(motion_asset_preview):
		motion_asset_preview.set_runtime(motion_player.current_state_name(), motion_phase, motion_player.playing)
	_refresh_motion_asset_preview()
	_render_info_bar()


func _on_motion_player_marker_fired(_state_id: String, event_id: String, kind: String) -> void:
	motion_last_marker = "%s · %s" % [kind.to_upper(), event_id]
	_show_status_message("Marker: %s" % motion_last_marker)
	_render_info_bar()


func _on_motion_player_playback_changed(_playing: bool) -> void:
	if is_instance_valid(motion_play_button):
		motion_play_button.text = "❚❚" if motion_player.playing else "▶"
		motion_play_button.tooltip_text = "Pause Animation Preview" if motion_player.playing else "Play Animation Preview"
	if is_instance_valid(motion_asset_preview):
		motion_asset_preview.set_runtime(motion_player.current_state_name(), motion_phase, motion_player.playing)
	_refresh_motion_asset_preview()
	_render_info_bar()


func _refresh_motion_asset_preview() -> void:
	if not is_instance_valid(motion_asset_preview) or motion_player == null:
		return
	var asset := _get_asset(selected_asset_id)
	var component_ids: Array[String] = []
	for component in asset.get("components", []):
		if bool(component.get("visibility", true)):
			component_ids.append(str(component.get("id", "")))
	motion_asset_preview.set_component_samples(MotionSampler.sample_player(motion_player, component_ids))


func _on_motion_state_cycle_duration_changed(value: float, state_id: String) -> void:
	if is_instance_valid(motion_workspace):
		motion_workspace.set_state_cycle_duration(state_id, value)


func _on_motion_runtime_number_changed(value: float, parameter_id: String) -> void:
	if motion_player != null:
		motion_player.set_parameter_value(parameter_id, value)


func _on_motion_runtime_bool_changed(value: bool, parameter_id: String) -> void:
	if motion_player != null:
		motion_player.set_parameter_value(parameter_id, value)


func _open_motion_state_dialog() -> void:
	if not is_instance_valid(motion_workspace) or _get_asset(selected_asset_id).is_empty():
		return
	motion_state_name_input.text = motion_workspace.next_default_state_name()
	motion_state_dialog.popup_centered()
	motion_state_name_input.select_all()
	motion_state_name_input.grab_focus()


func _confirm_motion_state_creation() -> void:
	if not is_instance_valid(motion_workspace):
		return
	var error := motion_workspace.add_state(motion_state_name_input.text)
	motion_state_dialog.hide()
	if not error.is_empty():
		_show_status_message(error)
		return
	_show_status_message("State added to the Asset Animation.")


func _rename_motion_state(new_name: String, state_id: String, editor: LineEdit) -> void:
	if not is_instance_valid(motion_workspace):
		return
	if new_name.strip_edges() == motion_workspace.state_name(state_id):
		return
	var error := motion_workspace.rename_state(state_id, new_name)
	if not error.is_empty():
		editor.text = motion_workspace.state_name(state_id)
		_show_status_message(error)
		return
	_show_status_message("State renamed in the Asset Animation.")


func _request_motion_state_removal(state_id: String) -> void:
	if not is_instance_valid(motion_workspace):
		return
	pending_motion_remove_state_id = state_id
	motion_remove_state_dialog.dialog_text = "Remove State '%s' from the Asset Animation?" % motion_workspace.state_name(state_id)
	motion_remove_state_dialog.popup_centered()


func _confirm_motion_state_removal() -> void:
	var state_id := pending_motion_remove_state_id
	pending_motion_remove_state_id = ""
	if state_id.is_empty() or not is_instance_valid(motion_workspace):
		return
	if motion_workspace.remove_state(state_id):
		_show_status_message("State removed from the Asset Animation.")


func _rename_motion(new_name: String, state_id: String, motion_id: String, editor: LineEdit) -> void:
	var motion := motion_workspace.find_motion(state_id, motion_id) if is_instance_valid(motion_workspace) else {}
	if motion.is_empty() or new_name.strip_edges() == str(motion.get("name", "")):
		return
	var error := motion_workspace.rename_motion(state_id, motion_id, new_name)
	if not error.is_empty():
		editor.text = str(motion.get("name", "Motion"))
		_show_status_message(error)
		return
	_show_status_message("Motion renamed in the Asset Animation.")


func _on_motion_enabled_changed(enabled: bool, state_id: String, motion_id: String) -> void:
	motion_workspace.set_motion_property(state_id, motion_id, "enabled", enabled)


func _on_motion_domain_selected(index: int, option: OptionButton, state_id: String, motion_id: String) -> void:
	if index < 0 or index >= option.item_count:
		return
	motion_workspace.set_motion_property(state_id, motion_id, "domain", str(option.get_item_metadata(index)))


func _on_motion_target_selected(index: int, option: OptionButton, state_id: String, motion_id: String) -> void:
	if index < 0 or index >= option.item_count:
		return
	var target_data: Dictionary = option.get_item_metadata(index)
	motion_workspace.set_motion_target(state_id, motion_id, str(target_data.get("scope", MotionWorkspace.TARGET_COMPONENT)), str(target_data.get("component_id", "")))


func _on_motion_primitive_selected(index: int, option: OptionButton, state_id: String, motion_id: String) -> void:
	if index < 0 or index >= option.item_count:
		return
	motion_workspace.set_motion_property(state_id, motion_id, "primitive", str(option.get_item_metadata(index)))


func _on_motion_parameter_changed(value: float, state_id: String, motion_id: String, parameter_name: String) -> void:
	motion_workspace.set_motion_parameter(state_id, motion_id, parameter_name, value)
	_refresh_motion_asset_preview()


func _on_motion_phase_offset_changed(value: float, state_id: String, motion_id: String) -> void:
	motion_workspace.set_motion_property(state_id, motion_id, "phase_offset", value, false)
	_refresh_motion_asset_preview()


func _request_motion_removal(state_id: String, motion_id: String) -> void:
	var motion := motion_workspace.find_motion(state_id, motion_id) if is_instance_valid(motion_workspace) else {}
	if motion.is_empty():
		return
	pending_motion_remove_motion_state_id = state_id
	pending_motion_remove_motion_id = motion_id
	motion_remove_motion_dialog.dialog_text = "Remove Motion '%s' from the Asset Animation?" % str(motion.get("name", "Motion"))
	motion_remove_motion_dialog.popup_centered()


func _confirm_motion_removal() -> void:
	var state_id := pending_motion_remove_motion_state_id
	var motion_id := pending_motion_remove_motion_id
	pending_motion_remove_motion_state_id = ""
	pending_motion_remove_motion_id = ""
	if state_id.is_empty() or motion_id.is_empty() or not is_instance_valid(motion_workspace):
		return
	if motion_workspace.remove_motion(state_id, motion_id):
		_show_status_message("Motion removed from the Asset Animation.")


func _move_transition(state_id: String, transition_id: String, direction: int) -> void:
	if is_instance_valid(motion_workspace) and motion_workspace.move_transition(state_id, transition_id, direction):
		_show_status_message("Transition priority updated in the Asset Animation.")


func _on_transition_target_selected(index: int, option: OptionButton, state_id: String, transition_id: String) -> void:
	if index < 0 or index >= option.item_count:
		return
	motion_workspace.set_transition_property(state_id, transition_id, "target_state_id", str(option.get_item_metadata(index)))


func _on_transition_exit_policy_selected(index: int, option: OptionButton, state_id: String, transition_id: String) -> void:
	if index < 0 or index >= option.item_count:
		return
	motion_workspace.set_transition_property(state_id, transition_id, "exit_policy", str(option.get_item_metadata(index)))


func _on_transition_entry_mode_selected(index: int, option: OptionButton, state_id: String, transition_id: String) -> void:
	if index < 0 or index >= option.item_count:
		return
	motion_workspace.set_transition_property(state_id, transition_id, "entry_mode", str(option.get_item_metadata(index)))


func _on_transition_number_changed(value: float, state_id: String, transition_id: String, property_name: String) -> void:
	if is_instance_valid(motion_workspace):
		motion_workspace.set_transition_property(state_id, transition_id, property_name, value, false)


func _add_contract_parameter() -> void:
	var error := motion_workspace.add_contract_parameter() if is_instance_valid(motion_workspace) else "Motion workspace is not available."
	if not error.is_empty():
		_show_status_message(error)


func _rename_contract_parameter(new_name: String, parameter_id: String, editor: LineEdit) -> void:
	var parameter := motion_workspace.find_contract_parameter(parameter_id) if is_instance_valid(motion_workspace) else {}
	if parameter.is_empty() or new_name.strip_edges() == str(parameter.get("name", "")):
		return
	var error := motion_workspace.set_contract_parameter_property(parameter_id, "name", new_name)
	if not error.is_empty():
		editor.text = str(parameter.get("name", "parameter"))
		_show_status_message(error)


func _on_contract_parameter_type_selected(index: int, option: OptionButton, parameter_id: String) -> void:
	if index < 0 or index >= option.item_count:
		return
	var error := motion_workspace.set_contract_parameter_property(parameter_id, "type", str(option.get_item_metadata(index)))
	if not error.is_empty():
		_show_status_message(error)


func _remove_contract_parameter(parameter_id: String) -> void:
	var error := motion_workspace.remove_contract_parameter(parameter_id) if is_instance_valid(motion_workspace) else "Motion workspace is not available."
	if not error.is_empty():
		_show_status_message(error)


func _add_transition_rule(state_id: String, transition_id: String) -> void:
	var error := motion_workspace.add_transition_rule(state_id, transition_id) if is_instance_valid(motion_workspace) else "Motion workspace is not available."
	if not error.is_empty():
		_show_status_message(error)


func _on_transition_rule_parameter_selected(index: int, option: OptionButton, state_id: String, transition_id: String, rule_id: String) -> void:
	if index < 0 or index >= option.item_count:
		return
	motion_workspace.set_transition_rule_property(state_id, transition_id, rule_id, "parameter_id", str(option.get_item_metadata(index)))


func _on_transition_rule_operator_selected(index: int, option: OptionButton, state_id: String, transition_id: String, rule_id: String) -> void:
	if index < 0 or index >= option.item_count:
		return
	motion_workspace.set_transition_rule_property(state_id, transition_id, rule_id, "operator", str(option.get_item_metadata(index)))


func _on_transition_rule_value_changed(value: float, state_id: String, transition_id: String, rule_id: String) -> void:
	if is_instance_valid(motion_workspace):
		motion_workspace.set_transition_rule_property(state_id, transition_id, rule_id, "value", value, false)


func _remove_transition_rule(state_id: String, transition_id: String, rule_id: String) -> void:
	if is_instance_valid(motion_workspace):
		motion_workspace.remove_transition_rule(state_id, transition_id, rule_id)


func _rename_marker_event(new_event_id: String, state_id: String, marker_id: String, editor: LineEdit) -> void:
	var marker := motion_workspace.find_marker(state_id, marker_id) if is_instance_valid(motion_workspace) else {}
	if marker.is_empty() or new_event_id.strip_edges() == str(marker.get("event_id", "")):
		return
	var error := motion_workspace.set_marker_property(state_id, marker_id, "event_id", new_event_id)
	if not error.is_empty():
		editor.text = str(marker.get("event_id", "event"))
		_show_status_message(error)
		return
	_show_status_message("Marker Event ID updated in the Asset Animation.")


func _on_marker_kind_selected(index: int, option: OptionButton, state_id: String, marker_id: String) -> void:
	if index < 0 or index >= option.item_count:
		return
	motion_workspace.set_marker_property(state_id, marker_id, "kind", str(option.get_item_metadata(index)))


func _on_marker_phase_changed(value: float, state_id: String, marker_id: String) -> void:
	if not is_instance_valid(motion_workspace):
		return
	motion_workspace.set_marker_property(state_id, marker_id, "phase", value, false)
	motion_workspace.refresh_board()
	_render_context_bar()


func _request_motion_item_removal(kind: String, state_id: String, item_id: String) -> void:
	if not is_instance_valid(motion_workspace):
		return
	var item := motion_workspace.find_transition(state_id, item_id) if kind == MotionSelection.TRANSITION else motion_workspace.find_marker(state_id, item_id)
	if item.is_empty():
		return
	pending_motion_remove_item_kind = kind
	pending_motion_remove_item_state_id = state_id
	pending_motion_remove_item_id = item_id
	var type_label := "Transition" if kind == MotionSelection.TRANSITION else "Marker"
	motion_remove_item_dialog.title = "Remove %s" % type_label
	motion_remove_item_dialog.dialog_text = "Remove %s '%s' from the Asset Animation?" % [type_label, motion_workspace.item_display_name(kind, item)]
	motion_remove_item_dialog.popup_centered()


func _confirm_motion_item_removal() -> void:
	var kind := pending_motion_remove_item_kind
	var state_id := pending_motion_remove_item_state_id
	var item_id := pending_motion_remove_item_id
	pending_motion_remove_item_kind = ""
	pending_motion_remove_item_state_id = ""
	pending_motion_remove_item_id = ""
	if state_id.is_empty() or item_id.is_empty() or not is_instance_valid(motion_workspace):
		return
	var removed := motion_workspace.remove_transition(state_id, item_id) if kind == MotionSelection.TRANSITION else motion_workspace.remove_marker(state_id, item_id)
	if removed:
		_show_status_message("%s removed from the Asset Animation." % ("Transition" if kind == MotionSelection.TRANSITION else "Marker"))


func _on_component_material_selected(index: int, option: OptionButton) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or index < 0 or index >= option.item_count:
		return
	var material_id := str(option.get_item_metadata(index))
	if str(component.get("material_id", "")) == material_id:
		return
	_record_direct_change()
	component["material_id"] = material_id
	_render_outliner()


func _on_edge_render_outline_changed(enabled: bool) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var edge := _get_edge(component, selected_edge_id)
	if edge.is_empty():
		return
	_record_direct_change()
	edge["render_outline"] = enabled
	canvas_view.set_bezier_geometry(component.get("points", []), component.get("edges", []), component.get("chains", []))
	_render_inspector()
	_render_canvas_context()


func _valid_selected_point_ids(component: Dictionary) -> Array[String]:
	var valid_ids: Array[String] = []
	for point_id_value in selected_point_ids:
		var point_id := str(point_id_value)
		if point_id not in valid_ids and not BezierTopology.point_by_id(component.get("points", []), point_id).is_empty():
			valid_ids.append(point_id)
	if valid_ids.is_empty() and not selected_point_id.is_empty() and not BezierTopology.point_by_id(component.get("points", []), selected_point_id).is_empty():
		valid_ids.append(selected_point_id)
	return valid_ids


func _add_selected_point_settings(component: Dictionary, point_ids: Array[String]) -> void:
	var shared_mode := ""
	var mode_mixed := false
	var shared_preserve := false
	var preserve_mixed := false
	var shared_handle_source := ""
	var shared_handle_in := Vector2.ZERO
	var shared_handle_out := Vector2.ZERO
	var handles_mixed := false
	for selection_index in range(point_ids.size()):
		var point := BezierTopology.point_by_id(component.get("points", []), point_ids[selection_index])
		if point.is_empty():
			continue
		var point_mode := str(point.get("mode", "linear"))
		var point_preserve := bool(point.get("preserve_point", point_mode == "corner"))
		var handle_source := str(point.get("handle_source", "auto"))
		var handle_in: Vector2 = point.get("handle_in", Vector2.ZERO)
		var handle_out: Vector2 = point.get("handle_out", Vector2.ZERO)
		if selection_index == 0:
			shared_mode = point_mode
			shared_preserve = point_preserve
			shared_handle_source = handle_source
			shared_handle_in = handle_in
			shared_handle_out = handle_out
			continue
		mode_mixed = mode_mixed or point_mode != shared_mode
		preserve_mixed = preserve_mixed or point_preserve != shared_preserve
		handles_mixed = handles_mixed \
			or handle_source != shared_handle_source \
			or not handle_in.is_equal_approx(shared_handle_in) \
			or not handle_out.is_equal_approx(shared_handle_out)
	inspector_content.add_child(_create_inspector_field_label("Handle Mode"))
	var point_mode_option := OptionButton.new()
	point_mode_option.custom_minimum_size = Vector2(0, 26)
	if mode_mixed:
		point_mode_option.add_item("- Mixed -")
		point_mode_option.set_item_metadata(0, "")
		point_mode_option.set_item_disabled(0, true)
	for mode_data in [["Linear", "linear"], ["Aligned", "aligned"], ["Free", "free"], ["Mirrored", "mirrored"], ["Corner", "corner"]]:
		point_mode_option.add_item(str(mode_data[0]))
		point_mode_option.set_item_metadata(point_mode_option.item_count - 1, str(mode_data[1]))
	if mode_mixed:
		point_mode_option.select(0)
	else:
		for mode_index in range(point_mode_option.item_count):
			if str(point_mode_option.get_item_metadata(mode_index)) == shared_mode:
				point_mode_option.select(mode_index)
				break
	point_mode_option.item_selected.connect(_on_selected_points_mode_selected.bind(point_mode_option, point_ids.duplicate()))
	inspector_content.add_child(point_mode_option)
	var preserve_point := CheckBox.new()
	preserve_point.text = "Preserve Point" if not preserve_mixed else "Preserve Point: - Mixed -"
	preserve_point.button_pressed = shared_preserve if not preserve_mixed else false
	preserve_point.toggled.connect(_on_selected_points_preserve_changed.bind(point_ids.duplicate()))
	inspector_content.add_child(preserve_point)
	var handles_label := "Handles: - Mixed -" if handles_mixed else "Handles: %s" % ("Manual" if shared_handle_source == "manual" else "Auto")
	inspector_content.add_child(_create_inspector_field_label(handles_label))


func _on_selected_points_mode_selected(index: int, option: OptionButton, _point_ids: Array) -> void:
	if index < 0 or index >= option.item_count:
		return
	var mode := str(option.get_item_metadata(index))
	if mode.is_empty():
		return
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var valid_ids := _valid_selected_point_ids(component)
	if component.is_empty() or valid_ids.is_empty():
		return
	_record_direct_change()
	for point_id in valid_ids:
		var point := BezierTopology.point_by_id(component.get("points", []), point_id)
		point["mode"] = mode
		if mode == "corner":
			point["preserve_point"] = true
		point["handle_source"] = "auto"
	BezierGeometry.resolve_auto_handles(component.get("points", []), component.get("chains", []))
	_refresh_component_geometry(component)
	_render_inspector()


func _on_selected_points_preserve_changed(enabled: bool, _point_ids: Array) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var valid_ids := _valid_selected_point_ids(component)
	if component.is_empty() or valid_ids.is_empty():
		return
	_record_direct_change()
	for point_id in valid_ids:
		BezierTopology.point_by_id(component.get("points", []), point_id)["preserve_point"] = enabled
	_render_inspector()


func _create_name_editor(value: String, placeholder: String) -> LineEdit:
	var editor := LineEdit.new()
	editor.text = value
	editor.custom_minimum_size = Vector2(0, 26)
	editor.placeholder_text = placeholder
	editor.add_theme_font_size_override("font_size", 12)
	return editor


func _add_reference_image_field(grid: GridContainer, label_text: String, value: float, property_name: String) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#7f8a9b"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(label)
	var field := SpinBox.new()
	field.min_value = 0.01 if property_name == "scale" else -100000.0
	field.max_value = 100000.0
	# Use tenths for the arrow buttons while retaining hundredth precision in
	# the editable text field.
	field.step = 0.01
	field.custom_arrow_step = 0.1
	field.value = value
	field.custom_minimum_size = Vector2(96, 26)
	field.add_theme_font_size_override("font_size", 11)
	field.value_changed.connect(_on_reference_image_property_changed.bind(property_name))
	grid.add_child(field)


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
	# Arrow buttons move in tenths; the embedded LineEdit still accepts
	# hundredths for precise values such as 0.01.
	field.step = 0.01
	field.custom_arrow_step = 0.1
	field.value = value
	field.custom_minimum_size = Vector2(96, 26)
	field.add_theme_font_size_override("font_size", 11)
	field.value_changed.connect(_on_transform_value_changed.bind(property_name))
	transform_fields[property_name] = field
	grid.add_child(field)


func _add_point_position_field(grid: GridContainer, label_text: String, value: float, property_name: String) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#7f8a9b"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(label)
	var field := SpinBox.new()
	field.min_value = -100000.0
	field.max_value = 100000.0
	# The arrows move in tenths while text input still supports hundredths.
	field.step = 0.01
	field.custom_arrow_step = 0.1
	field.set_value_no_signal(value)
	field.custom_minimum_size = Vector2(96, 26)
	field.add_theme_font_size_override("font_size", 11)
	field.value_changed.connect(_on_point_position_changed.bind(property_name))
	grid.add_child(field)


func _add_selected_points_delta_field(grid: GridContainer, label_text: String, property_name: String) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#7f8a9b"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(label)
	var field := SpinBox.new()
	field.min_value = -100000.0
	field.max_value = 100000.0
	field.step = 0.01
	field.custom_arrow_step = 0.1
	field.set_value_no_signal(0.0)
	field.custom_minimum_size = Vector2(96, 26)
	field.add_theme_font_size_override("font_size", 11)
	field.value_changed.connect(_on_selected_points_delta_changed.bind(property_name, field))
	grid.add_child(field)


func _on_selected_points_delta_changed(value: float, property_name: String, field: SpinBox) -> void:
	if is_zero_approx(value) or property_name not in ["position_x", "position_y"]:
		return
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var point_ids := _valid_selected_point_ids(component)
	if component.is_empty() or point_ids.size() < 2:
		return
	var local_delta := _world_to_editor_units(value)
	_record_direct_change()
	for point_id in point_ids:
		var point := BezierTopology.point_by_id(component.get("points", []), point_id)
		var point_position: Vector2 = point.get("position", Vector2.ZERO)
		if property_name == "position_x":
			point_position.x += local_delta
		else:
			point_position.y += local_delta
		point["position"] = point_position
	BezierGeometry.resolve_auto_handles(component.get("points", []), component.get("chains", []))
	_refresh_component_geometry(component)
	field.set_value_no_signal(0.0)


func _on_point_position_changed(value: float, property_name: String) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var point := BezierTopology.point_by_id(component.get("points", []), selected_point_id)
	if component.is_empty() or point.is_empty():
		return
	if property_name != "position_x" and property_name != "position_y":
		return
	_record_direct_change()
	var point_position: Vector2 = point.get("position", Vector2.ZERO)
	value = _world_to_editor_units(value)
	if property_name == "position_x":
		point_position.x = value
	else:
		point_position.y = value
	point["position"] = point_position
	BezierGeometry.resolve_auto_handles(component.get("points", []), component.get("chains", []))
	_refresh_component_geometry(component)
	_render_inspector()


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
	if property_name == "position_x" or property_name == "position_y" or property_name == "pivot_x" or property_name == "pivot_y":
		value = _world_to_editor_units(value)
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


func _on_asset_visibility_changed(visibility_enabled: bool, asset_id: String) -> void:
	var asset := _get_asset(asset_id)
	if asset.is_empty():
		return
	_record_direct_change()
	asset["visibility"] = visibility_enabled
	_render_outliner()
	_render_canvas_context()


func _on_component_visibility_entry_changed(visibility_enabled: bool, asset_id: String, component_id: String) -> void:
	var asset := _get_asset(asset_id)
	if asset.is_empty():
		return
	var child := _get_component(asset, component_id)
	if child.is_empty():
		for guide in asset.get("guides", []):
			if str(guide.get("id", "")) == component_id:
				child = guide
				break
	if child.is_empty():
		return
	_record_direct_change()
	child["visibility"] = visibility_enabled
	_render_outliner()
	_render_canvas_context()


func _on_texture_visibility_changed(visibility_enabled: bool, texture_id: String) -> void:
	var texture := _get_texture(texture_id)
	if texture.is_empty():
		return
	_record_direct_change()
	texture["visibility"] = visibility_enabled
	_render_outliner()
	_render_canvas_context()


func _on_element_visibility_changed(visibility_enabled: bool, texture_id: String, element_id: String) -> void:
	var texture := _get_texture(texture_id)
	var element := _get_element(texture, element_id)
	if element.is_empty():
		return
	_record_direct_change()
	element["visibility"] = visibility_enabled
	_render_outliner()
	_render_canvas_context()


func _on_material_visibility_changed(visibility_enabled: bool, material_id: String) -> void:
	var material_data := _get_material(material_id)
	if material_data.is_empty():
		return
	_record_direct_change()
	material_data["visibility"] = visibility_enabled
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


func _render_material_preview() -> void:
	var material_data := _get_material(selected_material_id)
	if material_data.is_empty():
		return
	var texture := _get_texture(str(material_data.get("texture_id", "")))
	var texture_path := _get_texture_final_path(texture) if not texture.is_empty() else ""
	material_preview_texture.texture = null
	material_preview_texture.modulate = Color(
		Color(material_data.get("tint", Color.WHITE)).r,
		Color(material_data.get("tint", Color.WHITE)).g,
		Color(material_data.get("tint", Color.WHITE)).b,
		clampf(float(material_data.get("opacity", 1.0)), 0.0, 1.0)
	)
	material_preview_label.visible = texture_path.is_empty()
	if texture_path.is_empty():
		material_preview_surface.custom_minimum_size = Vector2(280, 180)
		material_preview_content.custom_minimum_size = Vector2(240, 140)
		material_preview_texture.custom_minimum_size = Vector2(240, 140)
		return
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(texture_path)) != OK or image.is_empty():
		material_preview_label.visible = true
		return
	var image_size := Vector2(image.get_width(), image.get_height())
	var max_preview_size := Vector2(240, 140)
	var fit_scale := minf(max_preview_size.x / maxf(image_size.x, 1.0), max_preview_size.y / maxf(image_size.y, 1.0))
	var fitted_size := image_size * fit_scale
	material_preview_surface.custom_minimum_size = fitted_size + Vector2(40, 64)
	material_preview_content.custom_minimum_size = fitted_size
	material_preview_texture.custom_minimum_size = fitted_size
	material_preview_texture.texture = ImageTexture.create_from_image(image)
	if is_instance_valid(material_preview_shader):
		var wrap_mode := _material_wrap_mode(material_data)
		material_preview_shader.set_shader_parameter("mapping_scale", material_data.get("mapping_scale", Vector2.ONE))
		material_preview_shader.set_shader_parameter("mapping_offset", material_data.get("mapping_offset", Vector2.ZERO))
		material_preview_shader.set_shader_parameter("wrap_mode", 0 if wrap_mode == "fit" else 2 if wrap_mode == "repeat" else 1)
	material_preview_label.visible = false


func _load_material_canvas_texture(material_data: Dictionary) -> Texture2D:
	var texture := _get_texture(str(material_data.get("texture_id", "")))
	if texture.is_empty():
		return null
	var texture_path := _get_texture_final_path(texture)
	if texture_path.is_empty():
		return null
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(texture_path)) != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _render_lookdev_canvas() -> void:
	canvas_view.visible = true
	texture_canvas.visible = false
	import_preview.visible = false
	var asset := _get_asset(lookdev_target_asset_id)
	if asset.is_empty():
		canvas_view.set_component_material(null)
		canvas_context_label.text = "LookDev: Select an Asset"
		canvas_view.set_context("")
		canvas_view.set_interaction_state("")
		canvas_view.set_tool_mode("")
		canvas_view.set_component_transform({})
		canvas_view.set_component_material(null)
		canvas_view.set_reference_shapes([])
		canvas_view.set_display_polygon([])
		return
	var component := _get_component(asset, lookdev_target_component_id)
	if component.is_empty():
		canvas_view.set_component_material(null)
		canvas_context_label.text = "LookDev: %s" % str(asset.get("name", "Asset"))
		canvas_view.set_context(str(asset.get("name", "Asset")))
		canvas_view.set_interaction_state("asset")
		canvas_view.set_tool_mode("")
		canvas_view.set_component_transform({})
		canvas_view.set_component_material(null)
		canvas_view.set_reference_shapes(_build_reference_shapes(asset))
		canvas_view.set_display_polygon([])
		return
	canvas_context_label.text = "LookDev: %s / %s" % [str(asset.get("name", "Asset")), str(component.get("name", "Component"))]
	canvas_view.set_context(str(component.get("name", "Component")))
	canvas_view.set_interaction_state("")
	canvas_view.set_tool_mode("")
	var component_transform: Dictionary = component.get("transform", _default_component_transform()).duplicate(true)
	component_transform["visibility"] = bool(asset.get("visibility", true)) and bool(component.get("visibility", true))
	component_transform["z_index"] = int(component.get("z_index", 0))
	canvas_view.set_component_transform(component_transform)
	var material_data := _get_material(str(component.get("material_id", "")))
	if material_data.is_empty():
		canvas_view.set_component_material(null)
	else:
		canvas_view.set_component_material(_load_material_canvas_texture(material_data), material_data.get("tint", Color.WHITE), float(material_data.get("opacity", 1.0)), material_data.get("mapping_scale", Vector2.ONE), material_data.get("mapping_offset", Vector2.ZERO), _material_wrap_mode(material_data))
	canvas_view.set_reference_shapes(_build_reference_shapes(asset, lookdev_target_component_id))
	_refresh_component_geometry(component)


func _render_canvas_context() -> void:
	_ensure_default_edit_point_state()
	if active_module == "Motion" and active_motion_submodule == "Animation":
		_sync_motion_player_document(_get_asset(selected_asset_id))
	_render_context_bar()
	_render_info_bar()
	if not is_instance_valid(canvas_context_label):
		return
	canvas_view.set_reference_image(null)
	canvas_view.set_paper_frame(Vector2.ZERO, false)
	if active_module == "Motion":
		canvas_view.visible = false
		texture_canvas.visible = false
		import_preview.visible = false
		material_graph.visible = false
		material_preview_container.visible = false
		export_workspace.visible = false
		motion_workspace.visible = active_motion_submodule == "Animation"
		motion_path_workspace.visible = active_motion_submodule == "Path"
		motion_act_workspace.visible = active_motion_submodule == "Act"
		motion_sequence_workspace.visible = active_motion_submodule == "Sequence"
		if active_motion_submodule == "Animation":
			var motion_asset := _get_asset(selected_asset_id)
			motion_workspace.set_asset(selected_asset_id, str(motion_asset.get("name", "")) if not motion_asset.is_empty() else "", motion_asset.get("components", []) if not motion_asset.is_empty() else [], _ensure_asset_animation(motion_asset))
			motion_workspace.set_phase(motion_phase)
		elif active_motion_submodule == "Path":
			_refresh_motion_path_workspace()
		elif active_motion_submodule == "Act":
			_refresh_motion_act_workspace()
		else:
			_refresh_motion_sequence_workspace()
		canvas_context_label.text = ""
		texture_context_label.text = ""
		import_preview_context_label.text = ""
		return
	motion_path_workspace.visible = false
	motion_act_workspace.visible = false
	motion_sequence_workspace.visible = false
	if active_module == "Export":
		motion_workspace.visible = false
		canvas_view.visible = false
		texture_canvas.visible = false
		import_preview.visible = false
		material_graph.visible = false
		material_preview_container.visible = false
		export_workspace.visible = true
		_render_export_workspace()
		canvas_context_label.text = ""
		texture_context_label.text = ""
		import_preview_context_label.text = ""
		return
	export_workspace.visible = false
	if active_module == "Geometry":
		motion_workspace.visible = false
		canvas_view.visible = false
		texture_canvas.visible = false
		import_preview.visible = false
		material_graph.visible = false
		material_preview_container.visible = false
		canvas_context_label.text = "Geometry → %s · Placeholder" % active_geometry_submodule
		texture_context_label.text = ""
		import_preview_context_label.text = ""
		return
	if active_module == "Style":
		motion_workspace.visible = false
		canvas_view.visible = false
		texture_canvas.visible = false
		import_preview.visible = false
		var selected_material := _get_material(selected_material_id)
		var material_is_visible := selected_material.is_empty() or bool(selected_material.get("visibility", true))
		material_graph.visible = not selected_material_id.is_empty() and material_is_visible
		material_preview_container.visible = not selected_material_id.is_empty() and material_is_visible
		if material_preview_container.visible:
			_render_material_preview()
		canvas_context_label.text = "Material: %s" % str(_get_material(selected_material_id).get("name", "")) if not selected_material_id.is_empty() else ""
		texture_context_label.text = ""
		import_preview_context_label.text = ""
		return
	material_graph.visible = false
	material_preview_container.visible = false
	motion_workspace.visible = false
	if not selected_texture_id.is_empty():
		var texture := _get_texture(selected_texture_id)
		if texture.is_empty():
			return
		canvas_view.visible = false
		var selected_element := _get_element(texture, selected_element_id)
		var is_import_element := not selected_element.is_empty() and str(selected_element.get("type", "generator")) == "import"
		var texture_is_visible := bool(texture.get("visibility", true))
		var element_is_visible := selected_element.is_empty() or bool(selected_element.get("visibility", true))
		var effective_texture_visibility := texture_is_visible and element_is_visible
		texture_canvas.visible = not is_import_element and effective_texture_visibility
		import_preview.visible = is_import_element and effective_texture_visibility
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
	if active_module == "Create" and active_create_submodule == "Texture":
		canvas_view.visible = false
		texture_canvas.visible = true
		import_preview.visible = false
		texture_canvas.set_final_texture_path("")
		texture_canvas.set_selected_element("")
		texture_context_label.text = "Texture: Select a Texture"
		import_preview_context_label.text = ""
		texture_canvas.call_deferred("grab_focus")
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
		canvas_view.set_display_polygon([])
		canvas_view.set_bezier_geometry([], [], [])
		return
	_set_reference_image_canvas(asset)
	if selected_component_id.is_empty():
		canvas_context_label.text = "Asset: %s" % str(asset["name"])
		canvas_view.set_context(str(asset["name"]))
		canvas_view.set_interaction_state("asset")
		canvas_view.set_paper_frame(_paper_frame_size(paper_level) if paper_level >= 0 else Vector2.ZERO, paper_level >= 0)
		canvas_view.set_tool_mode("")
		canvas_view.set_component_transform({})
		canvas_view.set_component_material(null)
		canvas_view.set_reference_shapes(_build_reference_shapes(asset))
		canvas_view.set_display_polygon([])
		canvas_view.set_bezier_geometry([], [], [])
		canvas_view.call_deferred("grab_focus")
		return
	var component := _get_component(asset, selected_component_id)
	if component.is_empty():
		canvas_context_label.text = "Asset: %s" % str(asset["name"])
		canvas_view.set_context(str(asset["name"]))
		canvas_view.set_interaction_state("asset")
		canvas_view.set_paper_frame(Vector2.ZERO, false)
		canvas_view.set_tool_mode("")
		canvas_view.set_component_transform({})
		canvas_view.set_reference_shapes(_build_reference_shapes(asset))
		canvas_view.set_display_polygon([])
		canvas_view.set_bezier_geometry([], [], [])
		canvas_view.call_deferred("grab_focus")
		return
	canvas_context_label.text = "Component: %s" % str(component["name"])
	canvas_view.set_context(str(component["name"]))
	canvas_view.set_interaction_state(active_state)
	if active_state == "edit":
		canvas_view.set_edit_mode(active_edit_mode)
		canvas_view.set_edit_handles_enabled(edit_bezier_handles)
		canvas_view.set_edit_point_set_enabled(edit_point_set_mode)
	# Keep the canvas tool synchronized with the restored/editor state. Undo
	# can rebuild the canvas without going through _set_active_state(), so the
	# previous draw tool must not remain active while the UI is already in Edit.
	if active_state == "draw":
		canvas_view.set_tool_mode(active_draw_tool)
		canvas_view.set_draw_point_mode(active_draw_point_mode)
	else:
		canvas_view.set_tool_mode("")
	canvas_view.set_paper_frame(Vector2.ZERO, false)
	var component_transform: Dictionary = component.get("transform", _default_component_transform()).duplicate(true)
	component_transform["visibility"] = bool(asset.get("visibility", true)) and bool(component.get("visibility", true))
	component_transform["z_index"] = int(component.get("z_index", 0))
	canvas_view.set_component_transform(component_transform)
	var component_material := _get_material(str(component.get("material_id", "")))
	if component_material.is_empty():
		canvas_view.set_component_material(null)
	else:
		canvas_view.set_component_material(_load_material_canvas_texture(component_material), component_material.get("tint", Color.WHITE), float(component_material.get("opacity", 1.0)), component_material.get("mapping_scale", Vector2.ONE), component_material.get("mapping_offset", Vector2.ZERO), _material_wrap_mode(component_material))
	canvas_view.set_reference_shapes(_build_reference_shapes(asset, selected_component_id))
	BezierGeometry.resolve_auto_handles(component.get("points", []), component.get("chains", []))
	_refresh_component_geometry(component)
	canvas_view.set_selected_edge_id(selected_edge_id)
	canvas_view.call_deferred("grab_focus")


func _set_reference_image_canvas(asset: Dictionary) -> void:
	var reference_image := _normalize_reference_image(asset.get("reference_image", {}))
	var reference_path := _reference_image_path(asset)
	var reference_texture: Texture2D = null
	if not reference_path.is_empty() and FileAccess.file_exists(ProjectSettings.globalize_path(reference_path)):
		var reference_source := Image.new()
		if reference_source.load(ProjectSettings.globalize_path(reference_path)) == OK and not reference_source.is_empty():
			reference_texture = ImageTexture.create_from_image(reference_source)
	var reference_position: Vector2 = reference_image.get("position", Vector2.ZERO)
	var reference_scale := float(reference_image.get("scale", 1.0))
	if is_instance_valid(reference_texture) and reference_texture.get_height() > 0:
		var target_height := float(reference_image.get("target_height_cm", 13.0))
		reference_scale *= target_height / float(reference_texture.get_height())
		if str(reference_image.get("pivot_mode", "bottom_center")) == "bottom_center":
			reference_position += Vector2(0.0, target_height * 0.5 * reference_image.get("scale", 1.0))
	canvas_view.set_reference_image(
		reference_texture,
		bool(reference_image.get("visible", true)),
		float(reference_image.get("opacity", 0.5)),
		reference_position,
		reference_scale
	)


func _build_reference_shapes(asset: Dictionary, excluded_component_id := "") -> Array:
	var shapes: Array = []
	var asset_is_visible := bool(asset.get("visibility", true))
	for component in asset["components"]:
		if str(component["id"]) == excluded_component_id:
			continue
		shapes.append({
			"id": str(component["id"]),
			"points": BezierTopology.outer_control_polygon(component),
			"bezier_points": component.get("points", []).duplicate(true),
			"edges": component.get("edges", []).duplicate(true),
			"chains": component.get("chains", []).duplicate(true),
			"closed": BezierTopology.outer_chain_closed(component),
			"transform": component.get("transform", _default_component_transform()).duplicate(true),
			"visibility": asset_is_visible and bool(component.get("visibility", true)),
			"z_index": int(component.get("z_index", 0))
		})
	return shapes


func _refresh_component_geometry(component: Dictionary) -> void:
	if component.is_empty() or not is_instance_valid(canvas_view):
		return
	canvas_view.set_display_polygon(BezierTopology.outer_control_polygon(component), BezierTopology.outer_chain_closed(component))
	canvas_view.set_bezier_geometry(component.get("points", []), component.get("edges", []), component.get("chains", []))


func _on_bezier_point_added(position: Vector2, point_mode: String = "linear", drawn_handle_out: Vector2 = Vector2.ZERO) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		return
	_record_direct_change()
	BezierTopology.add_point(component, position, point_mode if point_mode in BezierTopology.VALID_POINT_MODES else active_draw_point_mode, drawn_handle_out)
	_refresh_component_geometry(component)


func _on_bezier_chain_closed() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		return
	var chains: Array = component.get("chains", [])
	if chains.is_empty() or bool(chains.back().get("closed", false)) or chains.back().get("point_ids", []).size() < 3:
		return
	_record_direct_change()
	BezierTopology.close_active_chain(component)
	_refresh_component_geometry(component)


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


func _on_bezier_points_move_started(point_ids: Array) -> void:
	bezier_point_move_start_positions.clear()
	bezier_point_move_component_id = selected_component_id
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		return
	for point_id_value in point_ids:
		var point_id := str(point_id_value)
		var point := BezierTopology.point_by_id(component.get("points", []), point_id)
		if not point.is_empty():
			bezier_point_move_start_positions[point_id] = Vector2(point.get("position", Vector2.ZERO))


func _on_bezier_points_moved(point_ids: Array, world_delta: Vector2) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or point_ids.is_empty():
		return
	if bezier_point_move_component_id != selected_component_id or bezier_point_move_start_positions.is_empty():
		_on_bezier_points_move_started(point_ids)
	var transform: Dictionary = component.get("transform", _default_component_transform())
	var rotation := deg_to_rad(float(transform.get("rotation", 0.0)))
	var scale: Vector2 = transform.get("scale", Vector2.ONE)
	var local_delta := world_delta.rotated(-rotation)
	if not is_zero_approx(scale.x):
		local_delta.x /= scale.x
	if not is_zero_approx(scale.y):
		local_delta.y /= scale.y
	# Snap the group's anchor position once, then apply the resulting delta to
	# every selected point so their relative spacing remains unchanged.
	var anchor_id := str(point_ids[0])
	if bezier_point_move_start_positions.has(anchor_id):
		var anchor_position: Vector2 = bezier_point_move_start_positions[anchor_id]
		local_delta = canvas_view.snap_position(anchor_position + local_delta) - anchor_position
	_record_coalesced_change()
	var points: Array = component.get("points", [])
	for point_id_value in point_ids:
		var point_id := str(point_id_value)
		var point := BezierTopology.point_by_id(points, point_id)
		if not point.is_empty() and bezier_point_move_start_positions.has(point_id):
			point["position"] = Vector2(bezier_point_move_start_positions[point_id]) + local_delta
	BezierGeometry.resolve_auto_handles(points, component.get("chains", []))
	_refresh_component_geometry(component)
	_render_inspector()


func _on_bezier_handle_changed(point_id: String, handle_side: String, value: Vector2) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var point := BezierTopology.point_by_id(component.get("points", []), point_id)
	if point.is_empty() or handle_side not in ["in", "out"]:
		return
	_record_coalesced_change()
	var mode := str(point.get("mode", "linear"))
	if mode == "linear":
		mode = "free"
		point["mode"] = mode
	point["handle_source"] = "manual"
	point["handle_%s" % handle_side] = value
	var opposite_side := "out" if handle_side == "in" else "in"
	var opposite: Vector2 = point.get("handle_%s" % opposite_side, Vector2.ZERO)
	if mode == "mirrored":
		point["handle_%s" % opposite_side] = -value
	elif mode == "aligned" and not is_zero_approx(value.length_squared()):
		var opposite_length := opposite.length()
		if is_zero_approx(opposite_length):
			opposite_length = value.length()
		point["handle_%s" % opposite_side] = -value.normalized() * opposite_length
	BezierGeometry.resolve_auto_handles(component.get("points", []), component.get("chains", []))
	_refresh_component_geometry(component)


func _on_bezier_edge_insert_requested(edge_id: String, t: float) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or BezierTopology.edge_by_id(component.get("edges", []), edge_id).is_empty():
		return
	_record_direct_change()
	var new_point_id := BezierTopology.insert_point_on_edge(component, edge_id, t)
	if new_point_id.is_empty():
		return
	selected_point_id = new_point_id
	selected_point_ids = [new_point_id]
	_refresh_component_geometry(component)
	canvas_view.set_selected_point_id(selected_point_id)
	_render_inspector()


func _on_bezier_point_delete_requested(point_id: String, record_history := true) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var points: Array = component.get("points", [])
	if component.is_empty() or BezierTopology.point_by_id(points, point_id).is_empty():
		return
	var chain := BezierTopology.chain_for_point(component.get("chains", []), point_id)
	if chain.is_empty():
		return
	var point_ids: Array = chain.get("point_ids", [])
	var closed := bool(chain.get("closed", false))
	var deleted_point_index := point_ids.find(point_id)
	if deleted_point_index < 0 or (closed and point_ids.size() <= 3):
		return
	if record_history:
		_record_direct_change()
	if not BezierTopology.delete_point(component, point_id):
		return
	points = component.get("points", [])
	var next_selection_index := mini(deleted_point_index, points.size() - 1)
	selected_point_id = str(points[next_selection_index].get("id", "")) if next_selection_index >= 0 else ""
	selected_point_ids.clear()
	if not selected_point_id.is_empty():
		selected_point_ids.append(selected_point_id)
	_refresh_component_geometry(component)
	canvas_view.set_selected_point_id(selected_point_id)
	_render_inspector()


func _on_bezier_points_delete_requested(point_ids: Array) -> void:
	if point_ids.is_empty():
		return
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		return
	var valid_point_ids := _valid_selected_point_ids(component)
	if valid_point_ids.is_empty():
		return
	_record_direct_change()
	BezierTopology.delete_points(component, valid_point_ids)
	selected_point_id = ""
	selected_point_ids.clear()
	canvas_view.clear_selection()
	_refresh_component_geometry(component)
	_render_inspector()


func _on_point_selection_changed(point_id: String) -> void:
	selected_point_id = point_id
	if active_edit_mode == "point":
		selected_edge_id = ""
		_render_inspector()


func _on_point_selection_set_changed(point_ids: Array) -> void:
	selected_point_ids.clear()
	for point_id_value in point_ids:
		var point_id := str(point_id_value)
		if not point_id.is_empty() and point_id not in selected_point_ids:
			selected_point_ids.append(point_id)
	selected_point_id = selected_point_ids[0] if selected_point_ids.size() == 1 else ""
	if active_edit_mode == "point":
		selected_edge_id = ""
		_render_inspector()


func _on_edge_selection_changed(edge_id: String) -> void:
	selected_edge_id = edge_id
	canvas_view.set_selected_edge_id(edge_id)
	_render_inspector()


func _get_asset(asset_id: String) -> Dictionary:
	for asset in assets:
		if str(asset["id"]) == asset_id:
			return asset
	return {}


func _ensure_asset_animation(asset: Dictionary) -> Dictionary:
	if asset.is_empty():
		return {}
	var animation := MotionWorkspace.normalize_animation_document(asset.get("animation", {}))
	asset["animation"] = animation
	return animation


func _default_motion_path(path_id: String, path_name: String) -> Dictionary:
	return {
		"id": path_id,
		"name": path_name,
		"visibility": true,
		"topology": MotionPathTopology.default_topology(),
		"playback": {"duration": 2.0, "loop": true, "orient_along_path": false}
	}


func _normalize_motion_path(raw_path, fallback_id: String) -> Dictionary:
	var source: Dictionary = raw_path if raw_path is Dictionary else {}
	var result := _default_motion_path(str(source.get("id", fallback_id)), str(source.get("name", fallback_id)))
	result["visibility"] = bool(source.get("visibility", true))
	result["topology"] = MotionPathTopology.normalize(source.get("topology", {}))
	if source.get("playback", {}) is Dictionary:
		result["playback"].merge(source.get("playback", {}), true)
	return result


func _default_motion_act(act_id: String, act_name: String, primitive := MotionActEvaluator.SLIDE) -> Dictionary:
	var resolved_primitive: String = primitive if primitive in MotionActEvaluator.PRIMITIVES else MotionActEvaluator.SLIDE
	return {
		"id": act_id,
		"name": act_name,
		"kind": MotionActEvaluator.KIND_PRIMITIVE,
		"primitive": resolved_primitive,
		"enabled": true,
		"timing": {"duration": MotionActEvaluator.default_duration(resolved_primitive), "easing": MotionActEvaluator.EASE_IN_OUT},
		"parameters": MotionActEvaluator.default_parameters(resolved_primitive)
	}


func _normalize_motion_act(raw_act, fallback_id: String) -> Dictionary:
	var source: Dictionary = raw_act if raw_act is Dictionary else {}
	var primitive := str(source.get("primitive", MotionActEvaluator.SLIDE))
	if primitive not in MotionActEvaluator.PRIMITIVES:
		primitive = MotionActEvaluator.SLIDE
	var result := _default_motion_act(str(source.get("id", fallback_id)), str(source.get("name", MotionActEvaluator.primitive_label(primitive))), primitive)
	result["enabled"] = bool(source.get("enabled", true))
	var timing = source.get("timing", {})
	if timing is Dictionary:
		result["timing"]["duration"] = maxf(0.01, float(timing.get("duration", MotionActEvaluator.default_duration(primitive))))
		var easing := str(timing.get("easing", MotionActEvaluator.EASE_IN_OUT))
		result["timing"]["easing"] = easing if easing in MotionActEvaluator.EASING_OPTIONS else MotionActEvaluator.EASE_IN_OUT
	var parameters = source.get("parameters", {})
	if parameters is Dictionary:
		if parameters.has("direction"):
			result["parameters"]["direction"] = MotionActEvaluator._vector(parameters.get("direction"))
		result["parameters"]["distance"] = maxf(0.0, float(parameters.get("distance", 4.0)))
		if primitive == MotionActEvaluator.JUMP:
			result["parameters"]["height"] = maxf(0.0, float(parameters.get("height", 3.0)))
			var arc := str(parameters.get("arc", MotionActEvaluator.JUMP_ARC_SMOOTH))
			result["parameters"]["arc"] = arc if arc in MotionActEvaluator.JUMP_ARC_OPTIONS else MotionActEvaluator.JUMP_ARC_SMOOTH
		elif primitive == MotionActEvaluator.BLINK:
			result["parameters"]["anticipation_distance"] = maxf(0.0, float(parameters.get("anticipation_distance", 1.0)))
			var anticipation_share := float(parameters.get("anticipation_share", 0.5))
			if int(source.get("schema_version", 0)) in range(1, 19) and is_equal_approx(anticipation_share, 0.18):
				anticipation_share = 0.5
			result["parameters"]["anticipation_share"] = clampf(anticipation_share, 0.01, 0.89)
			result["parameters"]["minimum_scale"] = clampf(float(parameters.get("minimum_scale", 0.05)), 0.01, 1.0)
	return result


func _serialize_motion_act(act: Dictionary) -> Dictionary:
	var normalized := _normalize_motion_act(act, str(act.get("id", "act")))
	return {
		"schema_version": SCHEMA_VERSION,
		"id": str(normalized.get("id", "")),
		"name": str(normalized.get("name", MotionActEvaluator.primitive_label(str(normalized.get("primitive", MotionActEvaluator.SLIDE))))),
		"kind": MotionActEvaluator.KIND_PRIMITIVE,
		"primitive": str(normalized.get("primitive", MotionActEvaluator.SLIDE)),
		"enabled": bool(normalized.get("enabled", true)),
		"timing": normalized.get("timing", {}).duplicate(true),
		"parameters": _serialize_motion_act_parameters(normalized)
	}


func _serialize_motion_act_parameters(act: Dictionary) -> Dictionary:
	var parameters: Dictionary = act.get("parameters", {})
	var serialized := {
		"direction": _serialize_vector(parameters.get("direction", Vector2.RIGHT)),
		"distance": float(parameters.get("distance", 4.0))
	}
	if str(act.get("primitive", MotionActEvaluator.SLIDE)) == MotionActEvaluator.JUMP:
		serialized["height"] = float(parameters.get("height", 3.0))
		serialized["arc"] = str(parameters.get("arc", MotionActEvaluator.JUMP_ARC_SMOOTH))
	elif str(act.get("primitive", MotionActEvaluator.SLIDE)) == MotionActEvaluator.BLINK:
		serialized["anticipation_distance"] = float(parameters.get("anticipation_distance", 1.0))
		serialized["anticipation_share"] = float(parameters.get("anticipation_share", 0.5))
		serialized["minimum_scale"] = float(parameters.get("minimum_scale", 0.05))
	return serialized


func _get_motion_act(act_id: String) -> Dictionary:
	for act in motion_acts:
		if str(act.get("id", "")) == act_id:
			return act
	return {}


func _add_motion_act(primitive: String) -> void:
	if primitive not in MotionActEvaluator.PRIMITIVES:
		return
	_record_direct_change()
	var act_id := "act_%d" % next_motion_act_id
	var act_name := "%s %02d" % [MotionActEvaluator.primitive_label(primitive), next_motion_act_id]
	next_motion_act_id += 1
	motion_acts.append(_default_motion_act(act_id, act_name, primitive))
	selected_motion_act_id = act_id
	motion_act_phase = 0.0
	motion_act_playing = false
	if _get_asset(motion_act_preview_asset_id).is_empty():
		motion_act_preview_asset_id = _default_motion_path_preview_asset_id()
	_render_inspector()
	_render_canvas_context()


func _add_motion_slide() -> void:
	_add_motion_act(MotionActEvaluator.SLIDE)


func _add_motion_jump() -> void:
	_add_motion_act(MotionActEvaluator.JUMP)


func _add_motion_blink() -> void:
	_add_motion_act(MotionActEvaluator.BLINK)


func _select_motion_act(act_id: String) -> void:
	if _get_motion_act(act_id).is_empty():
		return
	selected_motion_act_id = act_id
	motion_act_phase = 0.0
	motion_act_playing = false
	_render_inspector()
	_refresh_motion_act_workspace()
	_render_context_bar()


func _default_motion_sequence(sequence_id: String, sequence_name: String) -> Dictionary:
	return {"id": sequence_id, "name": sequence_name, "visibility": true, "next_entry_index": 1, "entries": []}


func _normalize_motion_sequence(raw_sequence, fallback_id: String) -> Dictionary:
	var source: Dictionary = raw_sequence if raw_sequence is Dictionary else {}
	var result := _default_motion_sequence(str(source.get("id", fallback_id)), str(source.get("name", fallback_id)))
	result["visibility"] = bool(source.get("visibility", true))
	var normalized_entries: Array = []
	var raw_entries = source.get("entries", [])
	if raw_entries is Array:
		for raw_entry in raw_entries:
			if not raw_entry is Dictionary:
				continue
			var entry_id := str(raw_entry.get("id", ""))
			if entry_id.is_empty():
				continue
			normalized_entries.append({
				"id": entry_id,
				"name": str(raw_entry.get("name", "Composition Entry")),
				"enabled": bool(raw_entry.get("enabled", true)),
				"asset_id": str(raw_entry.get("asset_id", "")),
				"animation_state_id": str(raw_entry.get("animation_state_id", "")),
				"path_id": str(raw_entry.get("path_id", ""))
			})
	result["entries"] = normalized_entries
	var inferred_next_entry_index := 1
	for entry in normalized_entries:
		var entry_id := str(entry.get("id", ""))
		if entry_id.begins_with("entry_"):
			inferred_next_entry_index = maxi(inferred_next_entry_index, entry_id.trim_prefix("entry_").to_int() + 1)
	result["next_entry_index"] = maxi(inferred_next_entry_index, int(source.get("next_entry_index", inferred_next_entry_index)))
	return result


func _get_motion_path(path_id: String) -> Dictionary:
	for path_document in motion_paths:
		if str(path_document.get("id", "")) == path_id:
			return path_document
	return {}


func _get_motion_sequence(sequence_id: String) -> Dictionary:
	for sequence_document in motion_sequences:
		if str(sequence_document.get("id", "")) == sequence_id:
			return sequence_document
	return {}


func _get_motion_sequence_entry(sequence_document: Dictionary, entry_id: String) -> Dictionary:
	for entry in sequence_document.get("entries", []):
		if str(entry.get("id", "")) == entry_id:
			return entry
	return {}


func _first_motion_sequence_entry(sequence_document: Dictionary) -> Dictionary:
	var entries: Array = sequence_document.get("entries", [])
	return entries[0] if not entries.is_empty() else {}


func _default_motion_path_preview_asset_id() -> String:
	for asset in assets:
		if str(asset.get("name", "")).to_lower().contains("wizard"):
			return str(asset.get("id", ""))
	return str(assets[0].get("id", "")) if not assets.is_empty() else ""


func _get_component(asset: Dictionary, component_id: String) -> Dictionary:
	if asset.is_empty():
		return {}
	for component in asset["components"]:
		if str(component["id"]) == component_id:
			return component
	return {}


func _get_edge(component: Dictionary, edge_id: String) -> Dictionary:
	if component.is_empty():
		return {}
	for edge in component.get("edges", []):
		if str(edge.get("id", "")) == edge_id:
			return edge
	return {}


func _get_texture(texture_id: String) -> Dictionary:
	for texture in textures:
		if str(texture["id"]) == texture_id:
			return texture
	return {}


func _get_material(material_id: String) -> Dictionary:
	for material_record in materials:
		if str(material_record.get("id", "")) == material_id:
			return material_record
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


func _add_module_section(parent: Container, module_name: String, submodules: Array, open_by_default := false, show_submodule_separators := false, separator_before_submodule_index := -1) -> void:
	var section := ModuleSection.new()
	section.setup(module_name, submodules, open_by_default, show_submodule_separators, separator_before_submodule_index)
	section.module_pressed.connect(_on_category_pressed)
	section.submodule_pressed.connect(_select_submodule.bind(section))
	module_sections.append(section)
	parent.add_child(section)


func _on_category_pressed(_module_name: String) -> void:
	active_module = _module_name
	if active_module != "Motion":
		motion_path_playing = false
		motion_act_playing = false
		motion_sequence_playing = false
	if active_module != "Style":
		selected_material_id = ""
	if active_module == "Motion":
		selected_component_id = ""
		selected_texture_id = ""
		selected_element_id = ""
		active_state = ""
		if active_motion_submodule == "Animation" and not _get_asset(selected_asset_id).is_empty():
			motion_selection.select_asset(selected_asset_id)
	if active_module == "Geometry":
		selected_asset_id = ""
		selected_component_id = ""
		selected_texture_id = ""
		selected_element_id = ""
		active_geometry_submodule = active_geometry_submodule if active_geometry_submodule in GEOMETRY_SUBMODULES else "Sampling"
	if active_module == "Export":
		selected_component_id = ""
		selected_texture_id = ""
		selected_element_id = ""
		active_state = ""
	var pressed_section := _find_section(_module_name)
	for section in module_sections:
		section.set_expanded(section == pressed_section and section.expanded)
	if pressed_section != null and not pressed_section.active_submodule.is_empty():
		if active_module == "Create":
			_set_create_submodule_context(pressed_section.active_submodule)
		elif active_module == "Geometry":
			active_geometry_submodule = pressed_section.active_submodule if pressed_section.active_submodule in GEOMETRY_SUBMODULES else "Sampling"
			pressed_section.set_active_submodule(active_geometry_submodule)
		elif active_module == "Motion":
			active_motion_submodule = pressed_section.active_submodule if pressed_section.active_submodule in MOTION_SUBMODULES else "Animation"
			pressed_section.set_active_submodule(active_motion_submodule)
	elif active_module == "Style":
		selected_asset_id = ""
		selected_component_id = ""
		selected_texture_id = ""
		selected_element_id = ""
		active_state = ""
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _find_section(module_name: String) -> ModuleSection:
	for section in module_sections:
		if section.module_name == module_name:
			return section
	return null


func _select_submodule(module_name: String, submodule: String, section: ModuleSection) -> void:
	section.set_active_submodule(submodule)
	active_module = module_name
	if module_name == "Create":
		_set_create_submodule_context(submodule)
	elif module_name == "Geometry" and submodule in GEOMETRY_SUBMODULES:
		active_geometry_submodule = submodule
		active_module = "Geometry"
		selected_asset_id = ""
		selected_component_id = ""
		selected_texture_id = ""
		selected_element_id = ""
		_render_outliner()
		_render_inspector()
		_render_canvas_context()
	elif module_name == "Style" and submodule == "Material":
		_enter_material_context(selected_material_id)
	elif module_name == "Motion" and submodule in MOTION_SUBMODULES:
		_enter_motion_context(submodule)
	return


func _set_create_submodule_context(submodule: String) -> void:
	active_create_submodule = submodule
	selected_material_id = ""
	active_state = ""
	if submodule == "Asset":
		selected_texture_id = ""
		selected_element_id = ""
	elif submodule == "Texture":
		selected_asset_id = ""
		selected_component_id = ""
	else:
		selected_asset_id = ""
		selected_component_id = ""
		selected_texture_id = ""
		selected_element_id = ""
	var create_section := _find_section("Create")
	if create_section != null:
		create_section.set_active_submodule(submodule)


func _enter_material_context(material_id: String = "") -> void:
	active_module = "Style"
	selected_asset_id = ""
	selected_component_id = ""
	selected_texture_id = ""
	selected_element_id = ""
	selected_material_id = material_id
	material_view_mode = "graph"
	var style_section := _find_section("Style")
	if style_section != null:
		style_section.set_expanded(true)
		style_section.set_active_submodule("Material")
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _enter_motion_context(submodule := "Animation") -> void:
	active_module = "Motion"
	active_motion_submodule = submodule if submodule in MOTION_SUBMODULES else "Animation"
	selected_component_id = ""
	selected_texture_id = ""
	selected_element_id = ""
	selected_material_id = ""
	active_state = ""
	if active_motion_submodule != "Path":
		motion_path_playing = false
	if active_motion_submodule != "Act":
		motion_act_playing = false
	if active_motion_submodule != "Sequence":
		motion_sequence_playing = false
	var motion_section := _find_section("Motion")
	if motion_section != null:
		motion_section.set_expanded(true)
		motion_section.set_active_submodule(active_motion_submodule)
	if active_motion_submodule == "Animation":
		if _get_asset(selected_asset_id).is_empty():
			selected_asset_id = ""
			motion_selection.clear()
		else:
			motion_selection.select_asset(selected_asset_id)
	elif active_motion_submodule == "Path" and _get_asset(motion_path_preview_asset_id).is_empty():
		motion_path_preview_asset_id = _default_motion_path_preview_asset_id()
	elif active_motion_submodule == "Act":
		if _get_asset(motion_act_preview_asset_id).is_empty():
			motion_act_preview_asset_id = _default_motion_path_preview_asset_id()
		if _get_motion_act(selected_motion_act_id).is_empty() and not motion_acts.is_empty():
			selected_motion_act_id = str(motion_acts[0].get("id", ""))
	elif active_motion_submodule == "Sequence":
		var sequence_document := _get_motion_sequence(selected_motion_sequence_id)
		if _get_motion_sequence_entry(sequence_document, selected_motion_sequence_entry_id).is_empty():
			selected_motion_sequence_entry_id = str(_first_motion_sequence_entry(sequence_document).get("id", ""))
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _select_material(material_id: String) -> void:
	if _get_material(material_id).is_empty():
		return
	_enter_material_context(material_id)


func _select_lookdev_asset(asset_id: String) -> void:
	var was_selected := lookdev_target_asset_id == asset_id and lookdev_target_component_id.is_empty()
	lookdev_target_asset_id = asset_id
	lookdev_target_component_id = ""
	if was_selected:
		var expanded := bool(expanded_assets.get(asset_id, false))
		expanded_assets[asset_id] = not expanded
	else:
		expanded_assets[asset_id] = true
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _select_lookdev_component(asset_id: String, component_id: String) -> void:
	if _get_component(_get_asset(asset_id), component_id).is_empty():
		return
	lookdev_target_asset_id = asset_id
	lookdev_target_component_id = component_id
	expanded_assets[asset_id] = true
	_render_outliner()
	_render_inspector()
	_render_canvas_context()
