extends Control

const SELECTION_MIRROR_SERVICE_SCRIPT = preload("res://scripts/selection_mirror_service.gd")
const CREATE_SUBMODULES := ["Character", "Props", "Terrain", "Icon", "Symbols"]
const GEOMETRY_SUBMODULES := ["Sampling", "Seeding", "Meshing"]
const STYLE_SUBMODULES := ["Weighting"]
const MOTION_SUBMODULES := ["Animation", "Path", "Act", "Sequence"]
const WORKSPACES_ROOT := "res://workspaces"
const CONFIG_PATH := "res://configs/app_config.json"
const SCHEMA_VERSION := 39
const MAX_HISTORY_SIZE := 100
const PAPER_SIZES_CM := [Vector2(21.0, 29.7), Vector2(29.7, 42.0), Vector2(42.0, 59.4), Vector2(59.4, 84.1), Vector2(84.1, 118.9)]
const PAPER_LABELS := ["A4", "A3", "A2", "A1", "A0"]
const PAPER_NONE_LEVEL := -1
const PAPER_NONE_LABEL := "Kein Rahmen"
const DRAW_MODES := ["closed_loop", "ribbon", "primitive"]
const DEFAULT_CONTOUR_WIDTH_PX := 8.0
const DEFAULT_RIBBON_WIDTH_PX := 8.0
const GRID_BOX_TOOL_UNITS := 0.5
const GAME_TILE_CENTIMETERS := 50.0
# Kept available for a later Outliner presentation, but processed outputs are
# currently reached through the Import Preview instead of additional rows.
const SHOW_PROCESSED_OUTLINER := false

var active_create_submodule := "Character"
var active_geometry_submodule := "Sampling"
var active_style_submodule := "Weighting"
var active_motion_submodule := "Animation"
var active_module := "Create"
var active_context_command := ""
var outliner_list: VBoxContainer
var outliner_search_input: LineEdit
var outliner_asset_type_filter_panel: VBoxContainer
var outliner_asset_type_filter_checkboxes: Dictionary = {}
var outliner_component_navigation_active := false
var outliner_asset_type_filters: Dictionary = {
	"character": true,
	"props": true,
	"terrain": true,
	"icon": true,
	"symbols": true
}
var inspector_content: VBoxContainer
var module_sections: Array[ModuleSection] = []
var assets: Array[Dictionary] = []
var motion_paths: Array[Dictionary] = []
var motion_acts: Array[Dictionary] = []
var motion_sequences: Array[Dictionary] = []
var geometry_documents: Dictionary = {}
var geometry_sampling_preview: Dictionary = {}
var geometry_sampling_preview_key := ""
var geometry_sampling_preview_state := "idle"
var geometry_sampling_preview_revision := 0
var geometry_seeding_preview: Dictionary = {}
var geometry_seeding_preview_key := ""
var geometry_seeding_preview_state := "idle"
var geometry_seeding_preview_revision := 0
var geometry_seeding_bake_button: Button
var geometry_seeding_advanced_pattern_expanded := false
var geometry_meshing_preview: Dictionary = {}
var geometry_meshing_preview_key := ""
var geometry_meshing_preview_state := "idle"
var geometry_meshing_preview_revision := 0
var geometry_meshing_bake_button: Button
var geometry_meshing_advanced_relaxation_expanded := false
var geometry_uv_mapping_preview: Dictionary = {}
var geometry_uv_mapping_preview_key := ""
var geometry_uv_mapping_checker_overlay := true
var sdf_images: Dictionary = {}
var sdf_resource_validation_cache: Dictionary = {}
var batch_status_snapshot: Dictionary = {}
var batch_status_revision := 0
var batch_status_snapshot_revision := -1
var batch_status_snapshot_build_count := 0
var batch_status_refresh_timer: Timer
var weighting_preview: Dictionary = {}
var weighting_preview_key := ""
var geometry_seeding_edit_active := false
var geometry_seeding_edit_tool := "select"
var geometry_seeding_enter_edit_after_bake := false
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
var selected_guide_id := ""
var selected_sampling_input_id := ""
var selected_sampling_input_kind := ""
var geometry_sampling_input_refresh_pending := false
var geometry_sampling_bake_button: Button
var selected_edge_id := ""
var selected_edge_ids: Array[String] = []
var selected_point_id := ""
var selected_point_ids: Array[String] = []
var asset_pivot_fields: Dictionary = {}
var bezier_point_move_start_positions: Dictionary = {}
var bezier_point_move_component_id := ""
var bezier_point_move_guide_id := ""
var selected_weighting_style_id := ""
var expanded_assets: Dictionary = {}
# Per-asset editor-view state. Geometry remains document-independent; this is
# only persistent workspace UI state for the Create canvas.
var asset_camera_states: Dictionary = {}
var canvas_camera_asset_id := ""
var next_asset_id := 1
var next_component_id := 1
var next_guide_id := 1
var asset_dialog: ConfirmationDialog
var asset_name_input: LineEdit
var component_dialog: ConfirmationDialog
var component_semantic_picker: SemanticPicker
var duplicate_semantic_dialog: ConfirmationDialog
var duplicate_semantic_picker: SemanticPicker
var pending_component_duplicate: Dictionary = {}
var component_draw_mode_menu: PopupMenu
var component_add_menu: PopupMenu
var component_add_child_menu: PopupMenu
var component_add_guide_menu: PopupMenu
var component_add_reference_menu: PopupMenu
var component_context_menu: PopupMenu
var guide_dialog: ConfirmationDialog
var guide_name_input: LineEdit
var reference_image_dialog: FileDialog
var reference_image_crop_dialog: ReferenceImageCropDialog
var element_dialog: ConfirmationDialog
var element_name_input: LineEdit
var asset_name_editor: LineEdit
var inspector_semantic_dropdown: SemanticDropdown
var transform_fields: Dictionary = {}
var canvas_context_label: Label
var canvas_view: ComponentCanvas
var motion_workspace: MotionWorkspace
var motion_path_workspace: MotionPathWorkspace
var motion_act_workspace: MotionActWorkspace
var motion_sequence_workspace: MotionSequenceWorkspace
var geometry_sampling_workspace: GeometrySamplingWorkspace
var geometry_method_menu: MenuButton
var geometry_sampling_method_choice_active := false
var geometry_seeding_workspace: GeometrySeedingWorkspace
var geometry_seeding_method_menu: MenuButton
var geometry_seeding_method_choice_active := false
var geometry_meshing_workspace: GeometryMeshingWorkspace
var geometry_meshing_method_menu: MenuButton
var geometry_meshing_method_choice_active := false
var geometry_uv_mapping_workspace: GeometryUVMappingWorkspace
var weighting_workspace: WeightingWorkspace
var weighting_method_menu: MenuButton
var geometry_uv_mapping_method_menu: MenuButton
var geometry_uv_mapping_method_choice_active := false
var selected_geometry_bake_method := ""
var geometry_seeding_replace_dialog: ConfirmationDialog
var guide_remove_dialog: ConfirmationDialog
var pending_guide_remove_asset_id := ""
var pending_guide_remove_id := ""
var component_remove_dialog: ConfirmationDialog
var pending_component_remove_asset_id := ""
var pending_component_remove_id := ""
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
var context_bar: HBoxContainer
var create_action_button: Button
var info_bar: HBoxContainer
var program_status_label: Label
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
var snap_grid_info_label: Label
var snap_rotation_slider: HSlider
var snap_rotation_value_label: Label
var paper_menu: MenuButton
var paper_level := 0
var world_scale_menu: Button
var world_scale_popup: PopupPanel
var world_unit_option: OptionButton
var world_grid_size_field: SpinBox
var world_scale_summary_label: Label
var update_meshes_button: BatchStatusButton
var mesh_batch_running := false
var update_uvs_button: BatchStatusButton
var uv_batch_running := false
var update_sdfs_button: BatchStatusButton
var sdf_batch_running := false
var runtime_export_button: BatchStatusButton
var runtime_export_batch_running := false
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
var world_grid_size := GRID_BOX_TOOL_UNITS
var semantic_registry := SemanticRegistry.load_registry()


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
	batch_status_refresh_timer = Timer.new()
	batch_status_refresh_timer.one_shot = true
	batch_status_refresh_timer.wait_time = 0.15
	batch_status_refresh_timer.timeout.connect(_refresh_batch_status_snapshot)
	add_child(batch_status_refresh_timer)
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
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		sdf_resource_validation_cache.clear()
		_invalidate_batch_status()
		return
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
	if is_instance_valid(canvas_view) and canvas_view.visible:
		canvas_view.grab_focus()


func _input(event: InputEvent) -> void:
	# Control focus navigation consumes arrow keys before _unhandled_key_input.
	# The focused Outliner and a selected Point in Edit → Select own those keys,
	# so intercept them before Godot moves focus to an unrelated control.
	if not event is InputEventKey or not event.pressed:
		return
	if not event.meta_pressed and not event.ctrl_pressed and event.keycode in [KEY_UP, KEY_DOWN] and _outliner_component_navigation_has_focus():
		_navigate_outliner_component(-1 if event.keycode == KEY_UP else 1)
		get_viewport().set_input_as_handled()
		return
	if event.meta_pressed or event.ctrl_pressed or event.keycode not in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] or not _can_nudge_selected_point():
		return
	var nudge_delta := Vector2.ZERO
	match event.keycode:
		KEY_LEFT: nudge_delta.x = -1.0
		KEY_RIGHT: nudge_delta.x = 1.0
		KEY_UP: nudge_delta.y = 1.0
		KEY_DOWN: nudge_delta.y = -1.0
	_nudge_selected_point(nudge_delta)
	if is_instance_valid(canvas_view):
		canvas_view.grab_focus()
	get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if is_instance_valid(canvas_view) and (event.meta_pressed or event.ctrl_pressed or event.keycode in [KEY_META, KEY_CTRL]):
		canvas_view.set_command_shortcut_active(event.meta_pressed or event.ctrl_pressed)
	if not event.pressed:
		return
	if event.echo and not _can_nudge_selected_point():
		return
	var has_command_modifier: bool = event.meta_pressed or event.ctrl_pressed
	if not has_command_modifier and event.keycode == KEY_P and active_state.is_empty() and not selected_component_id.is_empty() and is_instance_valid(canvas_view):
		if canvas_view.place_pivot_at_mouse():
			outliner_component_navigation_active = false
			canvas_view.grab_focus()
			get_viewport().set_input_as_handled()
		return
	if has_command_modifier and event.keycode == KEY_Q:
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE:
		_reset_to_default_state()
		get_viewport().set_input_as_handled()
		return
	if not has_command_modifier and event.keycode in [KEY_ENTER, KEY_KP_ENTER] and active_state == "draw" and active_draw_tool == "point":
		if _pause_draw_point():
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
	if has_command_modifier and active_module == "Style" and active_style_submodule == "Weighting" and event.keycode == KEY_1:
		_set_active_context_command("style.weighting.method")
		_render_context_bar()
		if is_instance_valid(weighting_method_menu):
			weighting_method_menu.show_popup()
		get_viewport().set_input_as_handled()
		return
	if active_module == "Style" and active_style_submodule == "Weighting" and not has_command_modifier and active_context_command == "style.weighting.method" and event.keycode in [KEY_1, KEY_2]:
		_set_weighting_method(WeightingService.UNIFORM if event.keycode == KEY_1 else WeightingService.AXIS_GRADIENT)
		get_viewport().set_input_as_handled()
		return
	if has_command_modifier and active_module == "Motion" and active_motion_submodule == "Sequence" and event.keycode in [KEY_1, KEY_2]:
		var focus_owner := get_viewport().gui_get_focus_owner()
		if not (focus_owner is LineEdit or focus_owner is TextEdit):
			_set_motion_sequence_view(MotionSequenceWorkspace.VIEW_COMPOSITION if event.keycode == KEY_1 else MotionSequenceWorkspace.VIEW_PLAYER)
			get_viewport().set_input_as_handled()
		return
	if active_module == "Mesh" and active_geometry_submodule == "Seeding":
		var seeding_focus_owner := get_viewport().gui_get_focus_owner()
		if not (seeding_focus_owner is LineEdit or seeding_focus_owner is TextEdit or seeding_focus_owner is SpinBox):
			if has_command_modifier and event.keycode == KEY_1:
				_activate_geometry_seeding_method_choice()
				get_viewport().set_input_as_handled()
				return
			if not has_command_modifier and geometry_seeding_method_choice_active and event.keycode in [KEY_1, KEY_2]:
				_set_geometry_seeding_method(GeometrySeedingService.POISSON_FILL if event.keycode == KEY_1 else GeometrySeedingService.SPINE_FLOW)
				get_viewport().set_input_as_handled()
				return
			if has_command_modifier and event.keycode == KEY_2:
				_toggle_geometry_seeding_edit()
				get_viewport().set_input_as_handled()
				return
			if not has_command_modifier and geometry_seeding_edit_active and event.keycode in [KEY_1, KEY_2, KEY_3]:
				_set_geometry_seeding_edit_tool(["select", "add", "remove"][event.keycode - KEY_1])
				get_viewport().set_input_as_handled()
				return
			if not has_command_modifier and geometry_seeding_edit_active and event.keycode in [KEY_BACKSPACE, KEY_DELETE]:
				if is_instance_valid(geometry_seeding_workspace):
					geometry_seeding_workspace.delete_selected_seed()
				get_viewport().set_input_as_handled()
				return
	if active_module == "Mesh" and active_geometry_submodule == "UV Mapping" and event.keycode == KEY_1:
		var uv_focus_owner := get_viewport().gui_get_focus_owner()
		if uv_focus_owner is LineEdit or uv_focus_owner is TextEdit or uv_focus_owner is SpinBox:
			return
		if has_command_modifier:
			_activate_geometry_uv_mapping_method_choice()
			get_viewport().set_input_as_handled()
			return
		if geometry_uv_mapping_method_choice_active:
			_set_geometry_uv_mapping_method(GeometryUVMappingService.BOUNDS_PLANAR)
			get_viewport().set_input_as_handled()
			return
	if not has_command_modifier and (event.keycode == KEY_BACKSPACE or event.keycode == KEY_DELETE) and active_state == "edit" and active_edit_mode == "point" and not selected_point_ids.is_empty():
		if selected_point_ids.size() == 1:
			_on_bezier_point_delete_requested(selected_point_ids[0])
		else:
			_on_bezier_points_delete_requested(selected_point_ids.duplicate())
		get_viewport().set_input_as_handled()
		return
	if not has_command_modifier and _can_nudge_selected_point() and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		var nudge_delta := Vector2.ZERO
		match event.keycode:
			KEY_LEFT: nudge_delta.x = -1.0
			KEY_RIGHT: nudge_delta.x = 1.0
			KEY_UP: nudge_delta.y = 1.0
			KEY_DOWN: nudge_delta.y = -1.0
		_nudge_selected_point(nudge_delta)
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
	if not selected_guide_id.is_empty():
		if has_command_modifier and event.keycode == KEY_D:
			_duplicate_selected_guide()
			get_viewport().set_input_as_handled()
			return
		if has_command_modifier and event.keycode == KEY_1:
			_activate_guide_draw_state()
			get_viewport().set_input_as_handled()
			return
		if has_command_modifier and event.keycode == KEY_2:
			_activate_guide_edit_state()
			get_viewport().set_input_as_handled()
			return
		return
	if selected_component_id.is_empty():
		return
	var selected_component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if str(selected_component.get("draw_mode", "")) == "primitive":
		if has_command_modifier and event.keycode == KEY_1 and selected_component.get("primitive", {}).is_empty():
			_set_active_state("draw")
			_set_active_context_command("asset.create_primitive")
			canvas_view.start_circle_primitive_preview()
			_render_context_bar()
			get_viewport().set_input_as_handled()
			return
		if has_command_modifier and event.keycode == KEY_2:
			_activate_transform_state()
			get_viewport().set_input_as_handled()
			return
		return
	if has_command_modifier and event.keycode == KEY_1:
		_activate_draw_state()
		get_viewport().set_input_as_handled()
		return
	elif has_command_modifier and event.keycode == KEY_2:
		_activate_edit_point_state()
		get_viewport().set_input_as_handled()
		return
	elif has_command_modifier and event.keycode == KEY_3:
		_activate_edit_edge_state()
		get_viewport().set_input_as_handled()
		return
	elif has_command_modifier and event.keycode == KEY_4:
		if str(selected_component.get("draw_mode", "closed_loop")) == "closed_loop":
			_activate_edit_face_state()
		get_viewport().set_input_as_handled()
		return
	elif not has_command_modifier and active_state == "edit" and active_edit_mode == "point" and event.keycode == KEY_1:
		_activate_edit_point_state(false, false)
		get_viewport().set_input_as_handled()
	elif not has_command_modifier and active_state == "edit" and active_edit_mode == "point" and event.keycode == KEY_2:
		_activate_edit_point_state(true, false)
		get_viewport().set_input_as_handled()
	elif not has_command_modifier and active_state == "edit" and active_edit_mode == "point" and event.keycode == KEY_3:
		_activate_edit_point_state(false, true)
		get_viewport().set_input_as_handled()


func _can_nudge_selected_point() -> bool:
	return not Input.is_key_pressed(KEY_META) and not Input.is_key_pressed(KEY_CTRL) \
		and selected_guide_id.is_empty() \
		and active_state == "edit" \
		and active_edit_mode == "point" \
		and not edit_bezier_handles \
		and not edit_point_set_mode \
		and not selected_point_ids.is_empty()


func _nudge_selected_point(direction: Vector2) -> void:
	if not _can_nudge_selected_point():
		return
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or direction.is_zero_approx():
		return
	var points_to_move: Array[Dictionary] = []
	for point_id in selected_point_ids:
		var point := BezierTopology.point_by_id(component.get("points", []), str(point_id))
		if not point.is_empty():
			points_to_move.append(point)
	if points_to_move.is_empty():
		return
	var step := snap_grid_step if snap_enabled else world_grid_size
	step = maxf(step, 0.0001)
	_record_direct_change()
	for point in points_to_move:
		point["position"] = Vector2(point.get("position", Vector2.ZERO)) + direction * step
	BezierGeometry.resolve_auto_handles(component.get("points", []), component.get("chains", []))
	_refresh_component_geometry(component)
	_render_inspector()
	_render_canvas_context()


func _reset_to_default_state() -> void:
	_stop_guide_draw_state()
	if is_instance_valid(canvas_view):
		canvas_view.cancel_mirror_command(false)
	_set_active_context_command("")
	_set_geometry_command_state("")
	selected_geometry_bake_method = ""
	active_state = ""
	active_draw_tool = ""
	active_edit_mode = "point"
	edit_bezier_handles = false
	edit_point_set_mode = false
	active_transform_mode = "transform"
	selected_edge_id = ""
	selected_edge_ids.clear()
	selected_point_id = ""
	selected_point_ids.clear()
	active_import_preview_mode = "original"
	if is_instance_valid(canvas_view):
		canvas_view.set_interaction_state("")
		canvas_view.set_tool_mode("")
		canvas_view.set_edit_mode(active_edit_mode)
		canvas_view.set_transform_mode(active_transform_mode)
		canvas_view.set_selected_edge_ids([])
	_render_inspector()
	_render_canvas_context()


func _set_geometry_command_state(state: String) -> void:
	geometry_sampling_method_choice_active = state == "sampling_method"
	geometry_seeding_method_choice_active = state == "seeding_method"
	geometry_seeding_edit_active = state == "seeding_edit"
	geometry_meshing_method_choice_active = state == "meshing_method"
	geometry_uv_mapping_method_choice_active = state == "uv_mapping_method"
	if state == "sampling_method":
		_set_active_context_command("geometry.sampling.method")
	elif state == "seeding_method":
		_set_active_context_command("geometry.seeding.method")
	elif state == "seeding_edit":
		_set_active_context_command("geometry.seeding.edit_seeds")
	elif state == "meshing_method":
		_set_active_context_command("geometry.meshing.method")
	elif state == "uv_mapping_method":
		_set_active_context_command("geometry.uv_mapping.method")
	elif active_context_command.begins_with("geometry."):
		_set_active_context_command("")
	if not geometry_seeding_edit_active:
		geometry_seeding_edit_tool = "select"


func _set_active_context_command(command: String) -> void:
	active_context_command = command


func _context_command_is(command: String) -> bool:
	return active_context_command == command


## Context-menu contract: every transient MenuButton choice must resolve its
## metadata, apply the value, and leave the command state when the popup
## closes (including Escape/cancel). Plain-number shortcuts may keep their
## command active until another command replaces them.
func _connect_context_method_menu(popup: PopupMenu, command: String, selection_handler: Callable) -> void:
	popup.id_pressed.connect(func(id: int) -> void:
		var index := popup.get_item_index(id)
		if index < 0:
			return
		selection_handler.call(popup.get_item_metadata(index))
		_complete_context_method_menu(command, popup)
	)
	popup.popup_hide.connect(func() -> void:
		if active_context_command == command:
			_set_active_context_command("")
			_render_context_bar()
	)


func _complete_context_method_menu(command: String, popup: PopupMenu) -> void:
	if is_instance_valid(popup):
		popup.hide()
	if active_context_command == command:
		_set_active_context_command("")
		_render_context_bar()


func _stop_guide_draw_state() -> void:
	if active_draw_tool == "spine":
		active_draw_tool = ""


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
	var draw_mode_status := Label.new()
	draw_mode_status.name = "DrawModeStatus"
	draw_mode_status.text = "Draw Mode: —"
	draw_mode_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	draw_mode_status.add_theme_font_size_override("font_size", 11)
	draw_mode_status.add_theme_color_override("font_color", Color("#9aa3b2"))
	toolbar.add_child(draw_mode_status)
	snap_button = Button.new()
	snap_button.text = "Snap: %s  ▼" % _snap_mode_label()
	snap_button.custom_minimum_size = Vector2(128, 32)
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
	update_meshes_button = BatchStatusButton.new()
	update_meshes_button.text = "Update Meshes (0)"
	update_meshes_button.tooltip_text = "All Meshes current"
	update_meshes_button.custom_minimum_size = Vector2(156, 32)
	update_meshes_button.focus_mode = Control.FOCUS_NONE
	update_meshes_button.disabled = true
	update_meshes_button.pressed.connect(_on_update_meshes_pressed)
	toolbar.add_child(update_meshes_button)
	update_uvs_button = BatchStatusButton.new()
	update_uvs_button.text = "Update UVs (0)"
	update_uvs_button.tooltip_text = "All UVs current"
	update_uvs_button.custom_minimum_size = Vector2(132, 32)
	update_uvs_button.focus_mode = Control.FOCUS_NONE
	update_uvs_button.disabled = true
	update_uvs_button.pressed.connect(_on_update_uvs_pressed)
	toolbar.add_child(update_uvs_button)
	update_sdfs_button = BatchStatusButton.new()
	update_sdfs_button.text = "Update SDFs (0)"
	update_sdfs_button.tooltip_text = "All SDFs current"
	update_sdfs_button.custom_minimum_size = Vector2(140, 32)
	update_sdfs_button.focus_mode = Control.FOCUS_NONE
	update_sdfs_button.disabled = true
	update_sdfs_button.pressed.connect(_on_update_sdfs_pressed)
	toolbar.add_child(update_sdfs_button)
	runtime_export_button = BatchStatusButton.new()
	runtime_export_button.text = "Export Runtime (0)"
	runtime_export_button.tooltip_text = "No pending runtime exports"
	runtime_export_button.custom_minimum_size = Vector2(164, 32)
	runtime_export_button.focus_mode = Control.FOCUS_NONE
	runtime_export_button.disabled = true
	runtime_export_button.pressed.connect(_on_runtime_export_pressed)
	toolbar.add_child(runtime_export_button)
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
	_add_module_section(module_rail, "Mesh", GEOMETRY_SUBMODULES, true, false, -1)
	_add_module_section(module_rail, "Style", STYLE_SUBMODULES, true)
	_set_active_module_visual("Create", active_create_submodule)

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
	outliner_asset_type_filter_panel = VBoxContainer.new()
	outliner_asset_type_filter_panel.name = "AssetTypeFilter"
	outliner_asset_type_filter_panel.add_theme_constant_override("separation", 2)
	outliner_content.add_child(outliner_asset_type_filter_panel)
	var filter_header := HBoxContainer.new()
	filter_header.add_theme_constant_override("separation", 4)
	var filter_label := _create_panel_label("Asset Filter")
	filter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_header.add_child(filter_label)
	var filter_reset := Button.new()
	filter_reset.text = "All"
	filter_reset.custom_minimum_size = Vector2(34, 22)
	filter_reset.focus_mode = Control.FOCUS_NONE
	filter_reset.tooltip_text = "Show all Asset types"
	filter_reset.pressed.connect(_set_all_outliner_asset_type_filters)
	filter_header.add_child(filter_reset)
	outliner_asset_type_filter_panel.add_child(filter_header)
	var filter_grid := GridContainer.new()
	filter_grid.columns = 2
	filter_grid.add_theme_constant_override("h_separation", 4)
	filter_grid.add_theme_constant_override("v_separation", 0)
	var asset_type_labels := {"character": "Character", "props": "Props", "terrain": "Terrain", "icon": "Icon", "symbols": "Symbols"}
	for asset_type in ["character", "props", "terrain", "icon", "symbols"]:
		var type_checkbox := CheckBox.new()
		type_checkbox.text = asset_type_labels[asset_type]
		type_checkbox.button_pressed = bool(outliner_asset_type_filters.get(asset_type, true))
		type_checkbox.focus_mode = Control.FOCUS_NONE
		type_checkbox.custom_minimum_size = Vector2(0, 24)
		type_checkbox.toggled.connect(_on_outliner_asset_type_filter_toggled.bind(asset_type))
		outliner_asset_type_filter_checkboxes[asset_type] = type_checkbox
		filter_grid.add_child(type_checkbox)
	outliner_asset_type_filter_panel.add_child(filter_grid)
	outliner_asset_type_filter_panel.visible = false
	var outliner_scroll := ScrollContainer.new()
	outliner_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outliner_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outliner_content.add_child(outliner_scroll)
	outliner_list = VBoxContainer.new()
	outliner_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outliner_list.add_theme_constant_override("separation", 0)
	outliner_list.focus_mode = Control.FOCUS_ALL
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
	canvas_view.edge_selection_set_changed.connect(_on_edge_selection_set_changed)
	canvas_view.face_selection_changed.connect(_on_face_selection_changed)
	canvas_view.point_selection_changed.connect(_on_point_selection_changed)
	canvas_view.point_selection_set_changed.connect(_on_point_selection_set_changed)
	canvas_view.bezier_points_move_started.connect(_on_bezier_points_move_started)
	canvas_view.bezier_points_moved.connect(_on_bezier_points_moved)
	canvas_view.bezier_handle_changed.connect(_on_bezier_handle_changed)
	canvas_view.bezier_edge_insert_requested.connect(_on_bezier_edge_insert_requested)
	canvas_view.bezier_endpoint_connection_requested.connect(_on_bezier_endpoint_connection_requested)
	canvas_view.reference_component_selected.connect(_on_reference_component_selected)
	canvas_view.mirror_axis_stage_changed.connect(_on_mirror_axis_stage_changed)
	canvas_view.mirror_axis_confirmed.connect(_on_mirror_axis_confirmed)
	canvas_view.mirror_axis_cancelled.connect(_on_mirror_axis_cancelled)
	canvas_view.pivot_changed.connect(_on_pivot_changed)
	canvas_view.asset_pivot_changed.connect(_on_asset_pivot_changed)
	canvas_view.transform_changed.connect(_on_transform_changed)
	canvas_view.primitive_placed.connect(_on_primitive_placed)
	canvas_view.primitive_center_changed.connect(_on_primitive_center_changed)
	canvas_view.primitive_preview_cancelled.connect(_on_primitive_preview_cancelled)
	var canvas := canvas_view
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_panel.add_child(canvas)
	_create_motion_workspace(canvas_panel)
	_create_motion_path_workspace(canvas_panel)
	_create_motion_act_workspace(canvas_panel)
	_create_motion_sequence_workspace(canvas_panel)
	_create_geometry_sampling_workspace(canvas_panel)
	_create_geometry_seeding_workspace(canvas_panel)
	_create_geometry_meshing_workspace(canvas_panel)
	_create_geometry_uv_mapping_workspace(canvas_panel)
	_create_weighting_workspace(canvas_panel)
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
	_create_duplicate_semantic_dialog()
	_create_component_draw_mode_menu()
	_create_component_add_menu()
	_create_component_context_menu()
	_create_guide_dialog()
	_create_reference_image_dialog()
	reference_image_crop_dialog = ReferenceImageCropDialog.new()
	reference_image_crop_dialog.image_accepted.connect(_save_reference_image_result)
	reference_image_crop_dialog.image_cropped.connect(_save_reference_image_result)
	add_child(reference_image_crop_dialog)
	_create_workspace_dialogs()
	_create_motion_state_dialogs()
	_create_motion_resource_dialogs()
	_create_geometry_seeding_dialogs()
	_create_guide_dialogs()
	_create_component_remove_dialog()


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


func _create_geometry_sampling_workspace(parent: Control) -> void:
	geometry_sampling_workspace = GeometrySamplingWorkspace.new()
	geometry_sampling_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	geometry_sampling_workspace.visible = false
	parent.add_child(geometry_sampling_workspace)


func _create_geometry_seeding_workspace(parent: Control) -> void:
	geometry_seeding_workspace = GeometrySeedingWorkspace.new()
	geometry_seeding_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	geometry_seeding_workspace.seed_add_requested.connect(_on_geometry_seed_add_requested)
	geometry_seeding_workspace.seed_move_started.connect(_on_geometry_seed_move_started)
	geometry_seeding_workspace.seed_move_requested.connect(_on_geometry_seed_move_requested)
	geometry_seeding_workspace.seed_move_finished.connect(_on_geometry_seed_move_finished)
	geometry_seeding_workspace.seed_remove_requested.connect(_on_geometry_seed_remove_requested)
	geometry_seeding_workspace.visible = false
	parent.add_child(geometry_seeding_workspace)


func _create_geometry_meshing_workspace(parent: Control) -> void:
	geometry_meshing_workspace = GeometryMeshingWorkspace.new()
	geometry_meshing_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	geometry_meshing_workspace.visible = false
	parent.add_child(geometry_meshing_workspace)


func _create_geometry_uv_mapping_workspace(parent: Control) -> void:
	geometry_uv_mapping_workspace = GeometryUVMappingWorkspace.new()
	geometry_uv_mapping_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	geometry_uv_mapping_workspace.visible = false
	parent.add_child(geometry_uv_mapping_workspace)


func _create_weighting_workspace(parent: Control) -> void:
	weighting_workspace = WeightingWorkspace.new()
	weighting_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weighting_workspace.visible = false
	parent.add_child(weighting_workspace)


func _create_geometry_seeding_dialogs() -> void:
	geometry_seeding_replace_dialog = ConfirmationDialog.new()
	geometry_seeding_replace_dialog.title = "Replace Edited Seeding Bake"
	geometry_seeding_replace_dialog.dialog_text = "This Component contains manually edited Seeds. Replace them with the generated Preview?"
	geometry_seeding_replace_dialog.ok_button_text = "Replace"
	geometry_seeding_replace_dialog.confirmed.connect(_confirm_bake_geometry_seeding_preview)
	geometry_seeding_replace_dialog.canceled.connect(_cancel_geometry_seeding_preview_replacement)
	add_child(geometry_seeding_replace_dialog)


func _create_guide_dialogs() -> void:
	guide_remove_dialog = ConfirmationDialog.new()
	guide_remove_dialog.title = "Delete Guide"
	guide_remove_dialog.ok_button_text = "Delete"
	guide_remove_dialog.confirmed.connect(_confirm_guide_deletion)
	guide_remove_dialog.canceled.connect(func() -> void:
		pending_guide_remove_asset_id = ""
		pending_guide_remove_id = ""
	)
	add_child(guide_remove_dialog)


func _create_component_remove_dialog() -> void:
	component_remove_dialog = ConfirmationDialog.new()
	component_remove_dialog.title = "Delete Component"
	component_remove_dialog.ok_button_text = "Delete"
	component_remove_dialog.confirmed.connect(_confirm_component_deletion)
	component_remove_dialog.canceled.connect(func() -> void:
		pending_component_remove_asset_id = ""
		pending_component_remove_id = ""
	)
	add_child(component_remove_dialog)


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
		["Fine", "fine"],
		["Finer", "finer"],
		["Ultra Fine", "ultra_fine"],
		["No Snap", "none"]
	]
	for grid_mode in grid_modes:
		var mode_button := CheckBox.new()
		mode_button.text = str(grid_mode[0])
		mode_button.button_group = grid_mode_group
		mode_button.pressed.connect(_on_snap_mode_selected.bind(str(grid_mode[1])))
		content.add_child(mode_button)
		snap_mode_buttons.append(mode_button)
	snap_grid_info_label = Label.new()
	snap_grid_info_label.add_theme_color_override("font_color", Color("#9aa3b2"))
	content.add_child(snap_grid_info_label)
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
	grid_size_label.text = "Grid Box Size (cm)"
	content.add_child(grid_size_label)
	world_grid_size_field = SpinBox.new()
	world_grid_size_field.min_value = 0.0001
	world_grid_size_field.max_value = 1000.0
	world_grid_size_field.step = 0.001
	world_grid_size_field.value = _editor_units_to_world(world_grid_size)
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
	world_grid_size = maxf(_world_to_editor_units(value), 0.0001)
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
		world_grid_size_field.set_value_no_signal(_editor_units_to_world(world_grid_size))
	if is_instance_valid(world_scale_summary_label):
		var boxes_per_game_tile := GAME_TILE_CENTIMETERS / _editor_units_to_world(world_grid_size)
		world_scale_summary_label.text = "1 Grid Box = %s cm\n1 Spiel-Tile = %s cm (%s Grid-Boxen)" % [
			_format_scale_value(_editor_units_to_world(world_grid_size)),
			_format_scale_value(GAME_TILE_CENTIMETERS),
			_format_scale_value(boxes_per_game_tile)
		]


func _format_scale_value(value: float) -> String:
	var formatted := "%.2f" % value
	while formatted.ends_with("0"):
		formatted = formatted.substr(0, formatted.length() - 1)
	if formatted.ends_with("."):
		formatted = formatted.substr(0, formatted.length() - 1)
	return formatted


func _editor_units_to_world(value: float) -> float:
	return ToolUnits.to_centimeters(value)


func _world_to_editor_units(value: float) -> float:
	return ToolUnits.from_centimeters(value)


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
	if is_instance_valid(snap_popup):
		snap_popup.hide()


func _set_snap_mode(mode: String) -> void:
	if mode not in ["coarse", "fine", "finer", "ultra_fine", "none"]:
		return
	snap_mode = mode
	snap_enabled = mode != "none"
	snap_grid_step = _snap_base_step()
	if is_instance_valid(canvas_view):
		canvas_view.set_snap_settings(snap_enabled, snap_grid_step, snap_rotation_step)
	_update_snap_popup_labels()
	_update_context_action_button()


func _snap_base_step() -> float:
	match snap_mode:
		"fine": return world_grid_size / 5.0
		"finer": return world_grid_size / 10.0
		"ultra_fine": return world_grid_size / 50.0
		_: return world_grid_size


func _on_snap_rotation_changed(value: float) -> void:
	snap_rotation_step = value
	canvas_view.set_snap_settings(snap_enabled, snap_grid_step, snap_rotation_step)
	_update_snap_popup_labels()


func _update_snap_popup_labels() -> void:
	if is_instance_valid(snap_button):
		snap_button.text = "Snap: %s  ▼" % _snap_mode_label()
	for mode_index in range(snap_mode_buttons.size()):
		var mode_button := snap_mode_buttons[mode_index]
		var mode: String = ["coarse", "fine", "finer", "ultra_fine", "none"][mode_index]
		mode_button.set_pressed_no_signal(mode == snap_mode)
	if is_instance_valid(snap_rotation_slider):
		snap_rotation_slider.set_value_no_signal(snap_rotation_step)
	if is_instance_valid(snap_grid_info_label):
		snap_grid_info_label.text = "Coarse %s cm · Fine %s cm · Finer %s cm · Ultra Fine %s cm" % [
			_format_scale_value(_editor_units_to_world(world_grid_size)),
			_format_scale_value(_editor_units_to_world(world_grid_size / 5.0)),
			_format_scale_value(_editor_units_to_world(world_grid_size / 10.0)),
			_format_scale_value(_editor_units_to_world(world_grid_size / 50.0))
		]
	if is_instance_valid(snap_rotation_value_label):
		snap_rotation_value_label.text = "Rotation Step: %d°" % int(snap_rotation_step)


func _snap_mode_label() -> String:
	match snap_mode:
		"fine": return "Fine"
		"finer": return "Finer"
		"ultra_fine": return "Ultra Fine"
		"none": return "No Snap"
		_: return "Coarse"


func _opaque_popup_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#20242c")
	style.border_color = Color("#363d48")
	style.set_border_width_all(1)
	return style


func _style_popup_menu(popup: PopupMenu) -> void:
	popup.add_theme_stylebox_override("panel", _opaque_popup_style())


func _style_context_command_button(button: BaseButton, active: bool) -> void:
	button.toggle_mode = true
	button.set_pressed_no_signal(active)
	if button is MenuButton:
		(button as MenuButton).flat = not active
	elif button is Button:
		(button as Button).flat = not active
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = Color("#8fd8f5")
	active_style.border_color = Color("#c5efff")
	active_style.set_border_width_all(1)
	active_style.corner_radius_top_left = 3
	active_style.corner_radius_top_right = 3
	active_style.corner_radius_bottom_left = 3
	active_style.corner_radius_bottom_right = 3
	var active_text := Color("#10202a")
	if active:
		for style_name in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			button.add_theme_stylebox_override(style_name, active_style)
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(color_name, active_text)
	else:
		button.add_theme_stylebox_override("pressed", active_style)
		button.add_theme_stylebox_override("hover_pressed", active_style)
		button.add_theme_color_override("font_pressed_color", active_text)
		button.add_theme_color_override("font_hover_pressed_color", active_text)


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
	component_dialog.dialog_text = ""
	component_dialog.size = Vector2i(420, 360)
	component_dialog.confirmed.connect(_confirm_component_creation)
	component_dialog.canceled.connect(_on_component_dialog_canceled)
	component_semantic_picker = SemanticPicker.new()
	component_semantic_picker.custom_minimum_size = Vector2(380, 210)
	component_semantic_picker.selection_changed.connect(_on_component_dialog_semantic_selected)
	component_dialog.add_child(component_semantic_picker)
	add_child(component_dialog)


func _create_duplicate_semantic_dialog() -> void:
	duplicate_semantic_dialog = ConfirmationDialog.new()
	duplicate_semantic_dialog.title = "Duplicate Component"
	duplicate_semantic_dialog.dialog_text = ""
	duplicate_semantic_dialog.size = Vector2i(420, 360)
	duplicate_semantic_dialog.confirmed.connect(_confirm_duplicate_semantic)
	duplicate_semantic_dialog.canceled.connect(func() -> void: pending_component_duplicate.clear())
	duplicate_semantic_picker = SemanticPicker.new()
	duplicate_semantic_picker.custom_minimum_size = Vector2(380, 210)
	duplicate_semantic_picker.selection_changed.connect(func(_key: String) -> void:
		duplicate_semantic_dialog.get_ok_button().disabled = duplicate_semantic_picker.selected_key.is_empty()
	)
	duplicate_semantic_dialog.add_child(duplicate_semantic_picker)
	add_child(duplicate_semantic_dialog)


func _create_component_draw_mode_menu() -> void:
	component_draw_mode_menu = PopupMenu.new()
	component_draw_mode_menu.add_item("Closed Loop", 0)
	component_draw_mode_menu.add_item("Ribbon", 1)
	component_draw_mode_menu.add_item("Primitive", 2)
	_style_popup_menu(component_draw_mode_menu)
	component_draw_mode_menu.id_pressed.connect(_on_component_draw_mode_selected)
	add_child(component_draw_mode_menu)


func _create_component_add_menu() -> void:
	component_add_menu = PopupMenu.new()
	component_add_menu.name = "ComponentAddMenu"
	component_add_child_menu = PopupMenu.new()
	component_add_child_menu.name = "ChildTypes"
	component_add_child_menu.add_item("Closed Loop", 0)
	component_add_child_menu.add_item("Ribbon", 1)
	component_add_child_menu.add_item("Primitive", 2)
	component_add_child_menu.id_pressed.connect(_on_component_add_child_selected)
	component_add_menu.add_child(component_add_child_menu)
	component_add_guide_menu = PopupMenu.new()
	component_add_guide_menu.name = "GuideTypes"
	component_add_guide_menu.add_item("Sample", 0)
	component_add_guide_menu.add_item("Motion", 1)
	component_add_guide_menu.add_item("Flow", 2)
	component_add_guide_menu.add_item("Cut", 3)
	component_add_guide_menu.id_pressed.connect(_on_component_add_guide_selected)
	component_add_menu.add_child(component_add_guide_menu)
	component_add_reference_menu = PopupMenu.new()
	component_add_reference_menu.name = "ReferenceSymbols"
	component_add_reference_menu.id_pressed.connect(_on_component_add_reference_selected)
	component_add_menu.add_child(component_add_reference_menu)
	component_add_menu.add_submenu_item("Child", "ChildTypes")
	component_add_menu.add_submenu_item("Guide", "GuideTypes")
	component_add_menu.add_submenu_item("Reference", "ReferenceSymbols")
	_style_popup_menu(component_add_menu)
	_style_popup_menu(component_add_child_menu)
	_style_popup_menu(component_add_guide_menu)
	_style_popup_menu(component_add_reference_menu)
	add_child(component_add_menu)


func _create_component_context_menu() -> void:
	component_context_menu = PopupMenu.new()
	component_context_menu.name = "ComponentContextMenu"
	component_context_menu.add_item("Duplicate", 0)
	component_context_menu.add_separator()
	component_context_menu.add_item("Duplicate & Mirror Y · Keep Orientation", 1)
	component_context_menu.add_item("Duplicate & Mirror Y · Flip Orientation", 2)
	component_context_menu.add_separator()
	component_context_menu.add_item("Detach from Parent", 3)
	_style_popup_menu(component_context_menu)
	component_context_menu.id_pressed.connect(_on_component_context_menu_selected)
	add_child(component_context_menu)


func _create_guide_dialog() -> void:
	guide_dialog = ConfirmationDialog.new()
	guide_dialog.title = "Add Guide"
	guide_dialog.dialog_text = "Enter a guide name"
	guide_dialog.size = Vector2i(360, 160)
	guide_dialog.confirmed.connect(_confirm_guide_creation)
	guide_dialog.canceled.connect(_on_guide_dialog_canceled)
	guide_name_input = LineEdit.new()
	guide_name_input.placeholder_text = "Guide name"
	guide_name_input.custom_minimum_size = Vector2(320, 32)
	guide_name_input.focus_mode = Control.FOCUS_ALL
	guide_name_input.text_submitted.connect(_submit_guide_name)
	guide_dialog.add_child(guide_name_input)
	add_child(guide_dialog)


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
	if active_module == "Create" and active_create_submodule in CREATE_SUBMODULES:
		_open_new_asset_dialog()
	elif active_module == "Style" and active_style_submodule == "Weighting":
		_create_weighting_style(selected_asset_id, selected_component_id)
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
	create_action_button.visible = (active_module == "Create" and active_create_submodule in CREATE_SUBMODULES) or (active_module == "Style" and active_style_submodule == "Weighting")
	create_action_button.disabled = active_module == "Style" and active_style_submodule == "Weighting" and selected_component_id.is_empty()
	var show_asset_create_controls := active_module == "Create" and active_create_submodule in CREATE_SUBMODULES
	if is_instance_valid(snap_button):
		snap_button.visible = show_asset_create_controls
	if is_instance_valid(paper_menu):
		paper_menu.visible = show_asset_create_controls
	if not show_asset_create_controls and is_instance_valid(snap_popup):
		snap_popup.hide()
	if active_module == "Create" and active_create_submodule in CREATE_SUBMODULES:
		create_action_button.text = "Create Symbol" if active_create_submodule == "Symbols" else "Create %s" % active_create_submodule
	elif active_module == "Style" and active_style_submodule == "Weighting":
		create_action_button.text = "Create Weighting Style"
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
	motion_paths.clear()
	motion_acts.clear()
	motion_sequences.clear()
	geometry_documents.clear()
	sdf_images.clear()
	sdf_resource_validation_cache.clear()
	geometry_sampling_preview = {}
	geometry_sampling_preview_key = ""
	geometry_sampling_preview_state = "idle"
	geometry_sampling_preview_revision += 1
	geometry_seeding_preview = {}
	geometry_seeding_preview_key = ""
	geometry_seeding_preview_state = "idle"
	geometry_seeding_preview_revision += 1
	geometry_meshing_preview = {}
	geometry_meshing_preview_key = ""
	geometry_meshing_preview_state = "idle"
	geometry_meshing_preview_revision += 1
	_set_geometry_command_state("")
	geometry_seeding_enter_edit_after_bake = false
	_stop_guide_draw_state()
	selected_asset_id = ""
	selected_component_id = ""
	selected_guide_id = ""
	expanded_assets.clear()
	next_asset_id = 1
	next_component_id = 1
	next_guide_id = 1
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


func _sanitize_asset_storage_name(value: String, fallback: String = "asset") -> String:
	var sanitized := value.strip_edges()
	for character in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		sanitized = sanitized.replace(character, "_")
	sanitized = sanitized.replace(".", "_")
	while sanitized.contains("  "):
		sanitized = sanitized.replace("  ", " ")
	sanitized = sanitized.replace(" ", "_")
	if sanitized.is_empty() or sanitized == "." or sanitized == "..":
		return fallback
	return sanitized


func _asset_storage_name(asset: Dictionary) -> String:
	var base := _sanitize_asset_storage_name(str(asset.get("name", "")), str(asset.get("id", "asset")))
	var duplicate := false
	for other_asset in assets:
		if other_asset == asset:
			continue
		if _sanitize_asset_storage_name(str(other_asset.get("name", "")), str(other_asset.get("id", "asset"))) == base:
			duplicate = true
			break
	return "%s__%s" % [base, str(asset.get("id", "asset"))] if duplicate else base


func _asset_storage_root(workspace_root: String, asset: Dictionary) -> String:
	return "%s/assets/%s" % [workspace_root, _asset_storage_name(asset)]


func _read_asset_data(workspace_root: String, asset_id: String):
	var legacy_data = _read_json("%s/assets/%s/asset.json" % [workspace_root, asset_id])
	var directory := DirAccess.open("%s/assets" % workspace_root)
	if directory == null:
		return legacy_data if legacy_data is Dictionary else {}
	for entry in directory.get_directories():
		var asset_directory := "%s/assets/%s" % [workspace_root, entry]
		for file_name in DirAccess.get_files_at(ProjectSettings.globalize_path(asset_directory)):
			if not str(file_name).to_lower().ends_with(".json"):
				continue
			var candidate = _read_json("%s/%s" % [asset_directory, file_name])
			if candidate is Dictionary and str(candidate.get("id", "")) == asset_id:
				if str(file_name).to_lower() != "asset.json" or entry != asset_id:
					return candidate
	return legacy_data if legacy_data is Dictionary else {}


func _save_workspace() -> void:
	if workspace_name.is_empty():
		_open_new_workspace_dialog(true)
		return
	var workspace_root := "%s/%s" % [WORKSPACES_ROOT, workspace_name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/assets" % workspace_root))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/paths" % workspace_root))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/acts" % workspace_root))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/sequences" % workspace_root))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/geometry" % workspace_root))
	var asset_ids: Array[String] = []
	var motion_path_ids: Array[String] = []
	var motion_act_ids: Array[String] = []
	var motion_sequence_ids: Array[String] = []
	for asset in assets:
		var asset_id := str(asset["id"])
		asset_ids.append(asset_id)
		var asset_storage_name := _asset_storage_name(asset)
		var asset_root := _asset_storage_root(workspace_root, asset)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(asset_root))
		var asset_data := {
			"schema_version": SCHEMA_VERSION,
			"id": asset_id,
			"name": str(asset["name"]),
			"asset_type": _asset_type(asset),
			"visibility": bool(asset.get("visibility", true)),
			"asset_pivot": _serialize_vector(_asset_pivot(asset)),
			"reference_image": _serialize_reference_image(asset.get("reference_image", {})),
			"animation": MotionWorkspace.normalize_animation_document(asset.get("animation", {})).duplicate(true),
			"components": [],
			"guides": []
		}
		for component in asset["components"]:
			asset_data["components"].append({
				"id": str(component["id"]),
				"type": str(component.get("type", "component")),
				"semantic_key": str(component.get("semantic_key", "")),
				"missing_semantic_source": str(component.get("missing_semantic_source", "")),
				"source_asset_id": str(component.get("source_asset_id", "")),
				"parent_component_id": str(component.get("parent_component_id", "")),
				"points": _serialize_bezier_points(component.get("points", [])),
				"edges": _serialize_edges(component.get("edges", [])),
				"chains": _serialize_chains(component.get("chains", [])),
				"transform": _serialize_transform(component.get("transform", {})),
				"visibility": bool(component.get("visibility", true)),
				"z_index": int(component.get("z_index", 0)),
				"draw_mode": str(component.get("draw_mode", "closed_loop")),
				"topology_role": str(component.get("topology_role", "outer")) if str(component.get("topology_role", "outer")) in ["outer", "hole"] else "outer",
				"contour_width_px": maxf(DEFAULT_CONTOUR_WIDTH_PX, float(component.get("contour_width_px", DEFAULT_CONTOUR_WIDTH_PX))),
				"ribbon_width_px": maxf(RibbonMeshService.MIN_WIDTH_PX, float(component.get("ribbon_width_px", DEFAULT_RIBBON_WIDTH_PX))),
				"catch_parent_component_id": str(component.get("catch_parent_component_id", "")),
				"show_point_numbers": bool(component.get("show_point_numbers", false)),
				"primitive": _serialize_primitive(component.get("primitive", {}))
			})
		for guide in asset.get("guides", []):
			asset_data["guides"].append(_serialize_asset_guide(guide))
		_write_json("%s/%s.json" % [asset_root, asset_storage_name], asset_data)
		for component in asset.get("components", []):
			var geometry_key := _geometry_document_key(asset_id, str(component.get("id", "")))
			if not geometry_documents.has(geometry_key):
				continue
			var geometry_path := "%s/geometry/%s/%s/geometry.json" % [workspace_root, asset_storage_name, str(component.get("id", ""))]
			_write_json(geometry_path, _serialize_geometry_document(geometry_documents[geometry_key]))
			_save_sdf_image(asset, str(component.get("id", "")))
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
		"next_guide_id": next_guide_id,
		"motion_paths": motion_paths.duplicate(true),
		"next_motion_path_id": next_motion_path_id,
		"motion_acts": motion_acts.duplicate(true),
		"next_motion_act_id": next_motion_act_id,
		"motion_sequences": motion_sequences.duplicate(true),
		"geometry_documents": geometry_documents.duplicate(true),
		"next_motion_sequence_id": next_motion_sequence_id,
		"selected_asset_id": selected_asset_id,
		"selected_component_id": selected_component_id,
		"selected_guide_id": selected_guide_id,
		"selected_edge_id": selected_edge_id,
		"selected_edge_ids": selected_edge_ids.duplicate(),
		"selected_point_id": selected_point_id,
		"selected_point_ids": selected_point_ids.duplicate(),
		"selected_weighting_style_id": selected_weighting_style_id,
		"selected_motion_path_id": selected_motion_path_id,
		"selected_motion_act_id": selected_motion_act_id,
		"selected_motion_sequence_id": selected_motion_sequence_id,
		"selected_motion_sequence_entry_id": selected_motion_sequence_entry_id,
		"motion_path_preview_asset_id": motion_path_preview_asset_id,
		"motion_act_preview_asset_id": motion_act_preview_asset_id,
		"active_module": active_module,
		"active_create_submodule": active_create_submodule,
		"active_geometry_submodule": active_geometry_submodule,
		"active_style_submodule": active_style_submodule,
		"active_motion_submodule": active_motion_submodule,
		"expanded_assets": expanded_assets.duplicate(true)
	}


func _push_undo_snapshot() -> void:
	undo_history.append(_capture_history_snapshot())
	if undo_history.size() > MAX_HISTORY_SIZE:
		undo_history.pop_front()
	redo_history.clear()


func _record_direct_change() -> void:
	_invalidate_batch_status()
	history_coalescing = false
	if is_instance_valid(history_coalesce_timer):
		history_coalesce_timer.stop()
	_push_undo_snapshot()


func _record_coalesced_change() -> void:
	_invalidate_batch_status()
	if not history_coalescing:
		_push_undo_snapshot()
		history_coalescing = true
	if is_instance_valid(history_coalesce_timer):
		history_coalesce_timer.start()


func _finish_history_coalescing() -> void:
	history_coalescing = false


func _restore_history_snapshot(snapshot: Dictionary) -> void:
	_invalidate_batch_status()
	# Undo/redo restores document data, not the user's currently selected tool.
	# Keep the interaction state when the same component remains selected.
	var retained_module := active_module
	var retained_component_id := selected_component_id
	var retained_guide_id := selected_guide_id
	var retained_active_state := active_state
	var retained_draw_tool := active_draw_tool
	var retained_draw_point_mode := active_draw_point_mode
	var retained_edit_mode := active_edit_mode
	var retained_edit_handles := edit_bezier_handles
	var retained_edit_point_set_mode := edit_point_set_mode
	var retained_transform_mode := active_transform_mode
	assets = snapshot.get("assets", []).duplicate(true)
	motion_paths = snapshot.get("motion_paths", []).duplicate(true)
	motion_acts = snapshot.get("motion_acts", []).duplicate(true)
	motion_sequences = snapshot.get("motion_sequences", []).duplicate(true)
	geometry_documents = snapshot.get("geometry_documents", {}).duplicate(true)
	geometry_sampling_preview = {}
	geometry_sampling_preview_key = ""
	geometry_sampling_preview_state = "idle"
	geometry_sampling_preview_revision += 1
	geometry_seeding_preview = {}
	geometry_seeding_preview_key = ""
	geometry_seeding_preview_state = "idle"
	geometry_seeding_preview_revision += 1
	geometry_meshing_preview = {}
	geometry_meshing_preview_key = ""
	geometry_meshing_preview_state = "idle"
	geometry_meshing_preview_revision += 1
	weighting_preview = {}
	weighting_preview_key = ""
	_set_geometry_command_state("")
	geometry_seeding_enter_edit_after_bake = false
	_stop_guide_draw_state()
	next_asset_id = int(snapshot.get("next_asset_id", 1))
	next_component_id = int(snapshot.get("next_component_id", 1))
	next_guide_id = int(snapshot.get("next_guide_id", 1))
	next_motion_path_id = int(snapshot.get("next_motion_path_id", 1))
	next_motion_act_id = int(snapshot.get("next_motion_act_id", 1))
	next_motion_sequence_id = int(snapshot.get("next_motion_sequence_id", 1))
	selected_asset_id = str(snapshot.get("selected_asset_id", ""))
	selected_component_id = str(snapshot.get("selected_component_id", ""))
	selected_guide_id = str(snapshot.get("selected_guide_id", ""))
	selected_edge_id = str(snapshot.get("selected_edge_id", ""))
	selected_edge_ids.clear()
	for edge_id_value in snapshot.get("selected_edge_ids", []):
		selected_edge_ids.append(str(edge_id_value))
	selected_point_id = str(snapshot.get("selected_point_id", ""))
	selected_point_ids = snapshot.get("selected_point_ids", []).duplicate()
	selected_weighting_style_id = str(snapshot.get("selected_weighting_style_id", ""))
	selected_motion_path_id = str(snapshot.get("selected_motion_path_id", ""))
	selected_motion_act_id = str(snapshot.get("selected_motion_act_id", ""))
	selected_motion_sequence_id = str(snapshot.get("selected_motion_sequence_id", ""))
	selected_motion_sequence_entry_id = str(snapshot.get("selected_motion_sequence_entry_id", ""))
	motion_path_preview_asset_id = str(snapshot.get("motion_path_preview_asset_id", ""))
	motion_act_preview_asset_id = str(snapshot.get("motion_act_preview_asset_id", ""))
	active_module = str(snapshot.get("active_module", "Create"))
	active_geometry_submodule = str(snapshot.get("active_geometry_submodule", "Sampling"))
	active_create_submodule = str(snapshot.get("active_create_submodule", "Character"))
	active_style_submodule = str(snapshot.get("active_style_submodule", "Weighting"))
	active_motion_submodule = str(snapshot.get("active_motion_submodule", "Animation"))
	expanded_assets = snapshot.get("expanded_assets", {}).duplicate(true)
	if _get_asset(selected_asset_id).is_empty():
		selected_asset_id = ""
		selected_component_id = ""
		selected_guide_id = ""
	elif not selected_component_id.is_empty() and _get_component(_get_asset(selected_asset_id), selected_component_id).is_empty():
		selected_component_id = ""
	if not selected_guide_id.is_empty() and _get_guide(_get_asset(selected_asset_id), selected_guide_id).is_empty():
		selected_guide_id = ""
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
		_set_create_submodule_context(active_create_submodule)
	elif active_module == "Mesh":
		active_geometry_submodule = active_geometry_submodule if active_geometry_submodule in GEOMETRY_SUBMODULES else "Sampling"
		var geometry_section := _find_section("Mesh")
		if geometry_section != null:
			_set_active_module_visual("Mesh", active_geometry_submodule)
	elif active_module == "Style":
		active_style_submodule = active_style_submodule if active_style_submodule in STYLE_SUBMODULES else "Weighting"
		if active_style_submodule == "Weighting" and _weighting_style(selected_asset_id, selected_component_id, selected_weighting_style_id).is_empty():
			selected_weighting_style_id = ""
		var style_section := _find_section("Style")
		if style_section != null:
			_set_active_module_visual("Style", active_style_submodule)
	elif active_module == "Motion":
		active_motion_submodule = active_motion_submodule if active_motion_submodule in MOTION_SUBMODULES else "Animation"
		var motion_section := _find_section("Motion")
		if motion_section != null:
			motion_section.set_expanded(true)
			motion_section.set_active_submodule(active_motion_submodule)
	var can_retain_authoring_tool := retained_module == "Create" \
		and active_module == "Create" \
		and ((not selected_component_id.is_empty() and selected_component_id == retained_component_id) \
			or (not selected_guide_id.is_empty() and selected_guide_id == retained_guide_id))
	if can_retain_authoring_tool:
		active_state = retained_active_state
		active_draw_tool = retained_draw_tool if retained_active_state == "draw" else ""
		active_draw_point_mode = retained_draw_point_mode
		active_edit_mode = retained_edit_mode
		edit_bezier_handles = retained_edit_handles
		edit_point_set_mode = retained_edit_point_set_mode
		active_transform_mode = retained_transform_mode
		if active_state == "draw":
			_restore_draw_anchor_selection()
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
	if is_instance_valid(status_clear_timer) and status_clear_timer.is_inside_tree():
		status_clear_timer.start()
	if is_inside_tree():
		var tween := create_tween()
		tween.tween_property(program_status_label, "modulate", Color("#f2c94c"), 0.15)


func _clear_status_message() -> void:
	if is_instance_valid(program_status_label):
		program_status_label.visible = false
		program_status_label.text = ""


func _load_workspace(workspace_entry: String, persist_as_last := true) -> bool:
	var workspace_root := "%s/%s" % [WORKSPACES_ROOT, workspace_entry]
	var workspace_data = _read_json("%s/workspace.json" % workspace_root)
	if not _has_supported_schema(workspace_data):
		return false
	var loaded_assets: Array[Dictionary] = []
	for asset_id_variant in workspace_data.get("assets", []):
		var asset_id := str(asset_id_variant)
		var asset_data = _read_asset_data(workspace_root, asset_id)
		if not _has_supported_schema(asset_data):
			continue
		var components: Array[Dictionary] = []
		var guides: Array[Dictionary] = []
		for component_data in asset_data.get("components", []):
			if not component_data is Dictionary:
				continue
			var topology := _deserialize_component_topology(component_data)
			if str(component_data.get("type", "component")) == "guide":
				var legacy_guide: Dictionary = component_data.duplicate(true)
				legacy_guide["points"] = topology["points"]
				legacy_guide["edges"] = topology["edges"]
				legacy_guide["chains"] = topology["chains"]
				guides.append(AssetGuide.normalize(legacy_guide))
				continue
			var component_type := str(component_data.get("type", "component"))
			var persisted_semantic_key := str(component_data.get("semantic_key", "")).strip_edges()
			var semantic_key := persisted_semantic_key if SemanticRegistry.contains(semantic_registry, persisted_semantic_key) else ""
			if semantic_key.is_empty() and int(asset_data.get("schema_version", 0)) < 39:
				semantic_key = SemanticRegistry.migrate_legacy_key(str(asset_data.get("name", asset_id)), component_data, semantic_registry)
			var missing_semantic_source := str(component_data.get("missing_semantic_source", ""))
			if semantic_key.is_empty() and missing_semantic_source.is_empty():
				missing_semantic_source = persisted_semantic_key if not persisted_semantic_key.is_empty() else str(component_data.get("semantic_role", component_data.get("name", "unassigned")))
			var semantic_component := {"semantic_key": semantic_key, "missing_semantic_source": missing_semantic_source}
			components.append({
				"id": str(component_data.get("id", "")),
				"type": component_type,
				"name": SemanticRegistry.component_display_name(semantic_component, semantic_registry),
				"semantic_key": semantic_key,
				"missing_semantic_source": missing_semantic_source,
				"source_asset_id": str(component_data.get("source_asset_id", "")),
				"parent_component_id": str(component_data.get("parent_component_id", "")),
				"points": topology["points"],
				"edges": topology["edges"],
				"chains": topology["chains"],
				"transform": _deserialize_transform(component_data.get("transform", {})),
				"visibility": bool(component_data.get("visibility", true)),
				"z_index": int(component_data.get("z_index", 0)),
				"draw_mode": str(component_data.get("draw_mode", "closed_loop")) if str(component_data.get("draw_mode", "closed_loop")) in DRAW_MODES else "closed_loop",
				"topology_role": str(component_data.get("topology_role", "outer")) if str(component_data.get("topology_role", "outer")) in ["outer", "hole"] else "outer",
				"contour_width_px": maxf(DEFAULT_CONTOUR_WIDTH_PX, float(component_data.get("contour_width_px", DEFAULT_CONTOUR_WIDTH_PX))),
				"ribbon_width_px": maxf(RibbonMeshService.MIN_WIDTH_PX, float(component_data.get("ribbon_width_px", DEFAULT_RIBBON_WIDTH_PX))),
				"catch_parent_component_id": str(component_data.get("catch_parent_component_id", "")),
				"show_point_numbers": bool(component_data.get("show_point_numbers", false)),
				"primitive": _deserialize_primitive(component_data.get("primitive", {}))
			})
		for guide_data in asset_data.get("guides", []):
			if not guide_data is Dictionary:
				continue
			guides.append(_deserialize_asset_guide(guide_data))
		var loaded_asset := {
			"id": str(asset_data.get("id", asset_id)),
			"name": str(asset_data.get("name", asset_id)),
			"asset_type": _normalize_asset_type(asset_data.get("asset_type", "character")),
			"visibility": bool(asset_data.get("visibility", true)),
			"asset_pivot": _deserialize_vector(asset_data.get("asset_pivot", [0.0, 0.0]), Vector2.ZERO),
			"reference_image": _normalize_reference_image(asset_data.get("reference_image", {})),
			"animation": MotionWorkspace.normalize_animation_document(asset_data.get("animation", {})),
			"components": components,
			"guides": guides
		}
		ComponentHierarchy.normalize_asset(loaded_asset)
		loaded_assets.append(loaded_asset)
	assets = loaded_assets
	var loaded_geometry_documents: Dictionary = {}
	for loaded_asset in loaded_assets:
		var loaded_asset_id := str(loaded_asset.get("id", ""))
		for loaded_component in loaded_asset.get("components", []):
			var loaded_component_id := str(loaded_component.get("id", ""))
			var geometry_data = _read_json("%s/geometry/%s/%s/geometry.json" % [workspace_root, _asset_storage_name(loaded_asset), loaded_component_id])
			if _has_supported_schema(geometry_data):
				loaded_geometry_documents[_geometry_document_key(loaded_asset_id, loaded_component_id)] = _normalize_geometry_document(geometry_data, loaded_asset_id, loaded_component_id)
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
	motion_paths = loaded_motion_paths
	motion_acts = loaded_motion_acts
	motion_sequences = loaded_motion_sequences
	geometry_documents = loaded_geometry_documents
	sdf_images.clear()
	sdf_resource_validation_cache.clear()
	_invalidate_batch_status()
	geometry_sampling_preview = {}
	geometry_sampling_preview_key = ""
	geometry_sampling_preview_state = "idle"
	geometry_sampling_preview_revision += 1
	geometry_seeding_preview = {}
	geometry_seeding_preview_key = ""
	geometry_seeding_preview_state = "idle"
	geometry_seeding_preview_revision += 1
	geometry_meshing_preview = {}
	geometry_meshing_preview_key = ""
	geometry_meshing_preview_state = "idle"
	geometry_meshing_preview_revision += 1
	_set_geometry_command_state("")
	geometry_seeding_enter_edit_after_bake = false
	_stop_guide_draw_state()
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
	if persist_as_last:
		_write_json(CONFIG_PATH, {"schema_version": SCHEMA_VERSION, "last_workspace": workspace_name})
	return true


func _serialize_editor_state() -> Dictionary:
	_store_camera_for_asset(canvas_camera_asset_id)
	var expanded_state := {}
	for asset in assets:
		var asset_id := str(asset["id"])
		expanded_state[asset_id] = bool(expanded_assets.get(asset_id, false))
	var serialized_asset_cameras := {}
	for asset in assets:
		var asset_id := str(asset["id"])
		var asset_camera = asset_camera_states.get(asset_id, {})
		if asset_camera is Dictionary and not asset_camera.is_empty():
			serialized_asset_cameras[asset_id] = {
				"position": _serialize_vector(asset_camera.get("position", Vector2.ZERO)),
				"zoom": float(asset_camera.get("zoom", 1.0))
			}
	return {
		"selected_asset_id": selected_asset_id,
		"selected_component_id": selected_component_id,
		"selected_guide_id": selected_guide_id,
		"selected_edge_ids": selected_edge_ids.duplicate(),
		"selected_weighting_style_id": selected_weighting_style_id,
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
		"active_create_submodule": active_create_submodule,
		"active_geometry_submodule": active_geometry_submodule,
		"active_style_submodule": active_style_submodule,
		"active_motion_submodule": active_motion_submodule,
		"outliner_asset_type_filters": outliner_asset_type_filters.duplicate(true),
		"expanded_assets": expanded_state,
		"asset_cameras": serialized_asset_cameras,
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
	selected_guide_id = ""
	selected_edge_id = ""
	selected_edge_ids.clear()
	selected_weighting_style_id = ""
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
	active_create_submodule = "Character"
	active_geometry_submodule = "Sampling"
	active_style_submodule = "Weighting"
	active_motion_submodule = "Animation"
	outliner_asset_type_filters = {"character": true, "props": true, "terrain": true, "icon": true, "symbols": true}
	_apply_outliner_asset_type_filter_checkboxes()
	expanded_assets.clear()
	asset_camera_states.clear()
	canvas_camera_asset_id = ""
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
		var requested_guide_id := str(state.get("selected_guide_id", ""))
		if not _get_guide(selected_asset, requested_guide_id).is_empty():
			selected_guide_id = requested_guide_id
			selected_component_id = ""
	selected_edge_ids.clear()
	for edge_id_value in state.get("selected_edge_ids", []):
		selected_edge_ids.append(str(edge_id_value))
	selected_edge_id = selected_edge_ids[0] if not selected_edge_ids.is_empty() else ""
	var saved_expanded = state.get("expanded_assets", {})
	if saved_expanded is Dictionary:
		for asset in assets:
			var asset_id := str(asset["id"])
			if saved_expanded.has(asset_id):
				expanded_assets[asset_id] = bool(saved_expanded[asset_id])
	var saved_asset_cameras = state.get("asset_cameras", {})
	if saved_asset_cameras is Dictionary:
		for asset in assets:
			var asset_id := str(asset["id"])
			var saved_asset_camera = saved_asset_cameras.get(asset_id, {})
			if saved_asset_camera is Dictionary and not saved_asset_camera.is_empty():
				asset_camera_states[asset_id] = {
					"position": _deserialize_vector(saved_asset_camera.get("position", [0.0, 0.0]), Vector2.ZERO),
					"zoom": clampf(float(saved_asset_camera.get("zoom", 1.0)), 0.25, 4096.0)
				}
	if not selected_component_id.is_empty() or not selected_guide_id.is_empty():
		_set_outliner_asset_expanded(selected_asset_id, true)
	active_module = "Create"
	var requested_create_submodule := str(state.get("active_create_submodule", "Character"))
	if not selected_asset_id.is_empty():
		requested_create_submodule = _asset_type_create_submodule(_asset_type(_get_asset(selected_asset_id)))
	_set_create_submodule_context(requested_create_submodule)
	var requested_geometry_submodule := str(state.get("active_geometry_submodule", "Sampling"))
	var requested_style_submodule := str(state.get("active_style_submodule", "Weighting"))
	var saved_asset_type_filters = state.get("outliner_asset_type_filters", {})
	if saved_asset_type_filters is Dictionary:
		for asset_type in outliner_asset_type_filters.keys():
			if saved_asset_type_filters.has(asset_type):
				outliner_asset_type_filters[asset_type] = bool(saved_asset_type_filters[asset_type])
	_apply_outliner_asset_type_filter_checkboxes()
	if str(state.get("active_module", "")) == "Style" and requested_style_submodule == "Weighting" and not selected_component_id.is_empty():
		active_module = "Style"
		active_style_submodule = "Weighting"
		var requested_weighting_style_id := str(state.get("selected_weighting_style_id", ""))
		selected_weighting_style_id = requested_weighting_style_id if not _weighting_style(selected_asset_id, selected_component_id, requested_weighting_style_id).is_empty() else ""
		var weighting_style_section := _find_section("Style")
		if weighting_style_section != null:
			_set_active_module_visual("Style", "Weighting")
	if str(state.get("active_module", "")) == "Mesh" and requested_geometry_submodule in GEOMETRY_SUBMODULES:
		active_module = "Mesh"
		active_geometry_submodule = requested_geometry_submodule
		var geometry_section := _find_section("Mesh")
		if geometry_section != null:
			_set_active_module_visual("Mesh", active_geometry_submodule)
	_apply_world_scale_settings(state.get("world_scale", {}))
	paper_level = clampi(int(state.get("paper_level", 0)), PAPER_NONE_LEVEL, PAPER_SIZES_CM.size() - 1)
	_apply_snap_settings(state.get("snap", {}))
	# Workspaces saved before per-asset cameras keep their one legacy view on the
	# active asset, rather than losing it during the migration.
	var saved_camera = state.get("camera", {})
	if saved_camera is Dictionary and not saved_camera.is_empty() and not selected_asset_id.is_empty() and not asset_camera_states.has(selected_asset_id):
		asset_camera_states[selected_asset_id] = {
			"position": _deserialize_vector(saved_camera.get("position", [0.0, 0.0]), Vector2.ZERO),
			"zoom": clampf(float(saved_camera.get("zoom", 1.0)), 0.25, 4096.0)
		}


func _store_camera_for_asset(asset_id: String) -> void:
	if asset_id.is_empty() or not is_instance_valid(canvas_view) or _get_asset(asset_id).is_empty():
		return
	var camera_state := canvas_view.get_camera_state()
	asset_camera_states[asset_id] = {
		"position": camera_state.get("position", Vector2.ZERO),
		"zoom": clampf(float(camera_state.get("zoom", 1.0)), 0.25, 4096.0)
	}


func _restore_camera_for_asset(asset_id: String) -> void:
	if asset_id.is_empty() or not is_instance_valid(canvas_view):
		return
	var camera_state = asset_camera_states.get(asset_id, {})
	if not camera_state is Dictionary or camera_state.is_empty():
		return
	canvas_view.set_camera_state(
		camera_state.get("position", Vector2.ZERO),
		clampf(float(camera_state.get("zoom", 1.0)), 0.25, 4096.0)
	)


func _sync_asset_camera(asset_id: String) -> void:
	if asset_id == canvas_camera_asset_id:
		return
	_store_camera_for_asset(canvas_camera_asset_id)
	_restore_camera_for_asset(asset_id)
	canvas_camera_asset_id = asset_id


func _apply_world_scale_settings(settings) -> void:
	if settings is Dictionary:
		var saved_unit := str(settings.get("unit", "cm"))
		if saved_unit == "m":
			world_unit = "cm"
			world_grid_size = GRID_BOX_TOOL_UNITS
		else:
			world_unit = "cm"
			world_grid_size = maxf(float(settings.get("grid_size", GRID_BOX_TOOL_UNITS)), 0.0001)
	else:
		world_unit = "cm"
		world_grid_size = GRID_BOX_TOOL_UNITS
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
	elif snap_mode == "none":
		snap_enabled = false
	elif snap_mode not in ["coarse", "fine", "finer", "ultra_fine"]:
		snap_mode = "coarse"
	if not snap_enabled:
		snap_mode = "none"
	# Keep the persisted mode and runtime state synchronized so No Snap really
	# disables grid and rotation snapping after workspace restore.
	snap_enabled = snap_mode != "none"
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


func _asset_pivot(asset: Dictionary) -> Vector2:
	return _deserialize_vector(asset.get("asset_pivot", [0.0, 0.0]), Vector2.ZERO)


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
	return "%s/%s" % [_asset_storage_root("%s/%s" % [WORKSPACES_ROOT, workspace_name], asset), reference_file]


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


func _serialize_primitive(raw_primitive) -> Dictionary:
	if not raw_primitive is Dictionary or str(raw_primitive.get("type", "")) != "circle":
		return {}
	return {
		"type": "circle",
		"diameter_cm": maxf(float(raw_primitive.get("diameter_cm", 1.0)), 0.001),
		"center": _serialize_vector(PrimitiveGeometryService.center({"draw_mode": "primitive", "primitive": raw_primitive}))
	}


func _deserialize_primitive(raw_primitive) -> Dictionary:
	if not raw_primitive is Dictionary or str(raw_primitive.get("type", "")) != "circle":
		return {}
	return {
		"type": "circle",
		"diameter_cm": maxf(float(raw_primitive.get("diameter_cm", 1.0)), 0.001),
		"center": _deserialize_vector(raw_primitive.get("center", [0.0, 0.0]), Vector2.ZERO)
	}


func _serialize_asset_guide(raw_guide: Dictionary) -> Dictionary:
	var guide := AssetGuide.normalize(raw_guide)
	return {
		"id": str(guide.get("id", "")),
		"type": "guide",
		"guide_type": str(guide.get("guide_type", AssetGuide.SAMPLER_SPINE)),
		"name": str(guide.get("name", "Guide")),
		"ordinal": int(guide.get("ordinal", 1)),
		"visibility": bool(guide.get("visibility", true)),
		"scope": guide.get("scope", {}).duplicate(true),
		"points": _serialize_bezier_points(guide.get("points", [])),
		"edges": _serialize_edges(guide.get("edges", [])),
		"chains": _serialize_chains(guide.get("chains", []))
	}


func _deserialize_asset_guide(raw_guide: Dictionary) -> Dictionary:
	var topology := _deserialize_component_topology(raw_guide)
	var guide: Dictionary = raw_guide.duplicate(true)
	guide["points"] = topology["points"]
	guide["edges"] = topology["edges"]
	guide["chains"] = topology["chains"]
	return AssetGuide.normalize(guide)


func _geometry_document_key(asset_id: String, component_id: String) -> String:
	return "%s/%s" % [asset_id, component_id]


func _sdf_image_path(asset: Dictionary, component_id: String) -> String:
	if workspace_name.is_empty() or asset.is_empty() or component_id.is_empty():
		return ""
	return "%s/%s/geometry/%s/%s/contour_sdf.png" % [WORKSPACES_ROOT, workspace_name, _asset_storage_name(asset), component_id]


func _sdf_resource_available(asset_id: String, component_id: String) -> bool:
	var key := _geometry_document_key(asset_id, component_id)
	var bake := _sdf_bake(asset_id, component_id)
	var resolution: Array = bake.get("resolution", [])
	var expected_width := int(resolution[0]) if resolution.size() == 2 else 0
	var expected_height := int(resolution[1]) if resolution.size() == 2 else 0
	var expected_hash := str(bake.get("pixel_hash", ""))
	if sdf_images.has(key) and sdf_images[key] is Image:
		var transient_image: Image = sdf_images[key]
		return not transient_image.is_empty() and transient_image.get_format() == Image.FORMAT_L8 \
			and transient_image.get_width() == expected_width and transient_image.get_height() == expected_height \
			and GeometrySDFService.image_pixel_hash(transient_image) == expected_hash
	var path := _sdf_image_path(_get_asset(asset_id), component_id)
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var modified_time := FileAccess.get_modified_time(path)
	var cache_key := "%s|%d|%d|%d|%s" % [path, modified_time, expected_width, expected_height, expected_hash]
	if sdf_resource_validation_cache.has(cache_key):
		return bool(sdf_resource_validation_cache[cache_key])
	var image := Image.load_from_file(path)
	var valid := image != null and not image.is_empty() and image.get_format() == Image.FORMAT_L8 \
		and image.get_width() == expected_width and image.get_height() == expected_height \
		and GeometrySDFService.image_pixel_hash(image) == expected_hash
	sdf_resource_validation_cache[cache_key] = valid
	return valid


func _save_sdf_image(asset: Dictionary, component_id: String) -> Error:
	var key := _geometry_document_key(str(asset.get("id", "")), component_id)
	if not sdf_images.has(key) or not sdf_images[key] is Image:
		return OK
	var path := _sdf_image_path(asset, component_id)
	if path.is_empty():
		return ERR_UNCONFIGURED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var result := (sdf_images[key] as Image).save_png(path)
	sdf_resource_validation_cache.clear()
	return result


func _default_geometry_document(asset_id: String, component_id: String) -> Dictionary:
	return {
		"asset_id": asset_id,
		"component_id": component_id,
		"component_mesh": {
			"bake_id": "",
			"method": "",
			"mesh_fingerprint": "",
			"build_provenance": {},
			"last_error": "",
			"last_failure_signature": {}
		},
		"sampling": {
			"recipe": GeometrySamplingService.default_recipe(),
			"bakes": {}
		},
		"seeding": {
			"recipe": GeometrySeedingService.default_recipe(),
			"bakes": {}
		},
		"meshing": {
			"recipe": GeometryMeshingService.default_recipe(),
			"bakes": {}
		},
		"uv_mapping": {
			"recipe": GeometryUVMappingService.default_recipe(),
			"bakes": {},
			"last_error": "",
			"last_failure_fingerprint": ""
		},
		"sdf": {
			"recipe": GeometrySDFService.default_recipe(),
			"bake": {},
			"last_error": "",
			"last_failure_fingerprint": ""
		},
		"weighting": {
			"next_style_index": 1,
			"styles": []
		}
	}


func _get_geometry_document(asset_id: String, component_id: String, create_if_missing := false) -> Dictionary:
	var key := _geometry_document_key(asset_id, component_id)
	if geometry_documents.has(key):
		return geometry_documents[key]
	if not create_if_missing:
		return {}
	var document := _default_geometry_document(asset_id, component_id)
	geometry_documents[key] = document
	return document


func _geometry_sampling_recipe(asset_id: String, component_id: String) -> Dictionary:
	var document := _get_geometry_document(asset_id, component_id)
	if document.is_empty():
		return GeometrySamplingService.default_recipe()
	return GeometrySamplingService.normalize_recipe(document.get("sampling", {}).get("recipe", {}))


func _geometry_seeding_recipe(asset_id: String, component_id: String) -> Dictionary:
	var document := _get_geometry_document(asset_id, component_id)
	if document.is_empty():
		return GeometrySeedingService.default_recipe()
	return GeometrySeedingService.normalize_recipe(document.get("seeding", {}).get("recipe", {}))


func _geometry_meshing_recipe(asset_id: String, component_id: String) -> Dictionary:
	var document := _get_geometry_document(asset_id, component_id)
	if document.is_empty():
		return GeometryMeshingService.default_recipe()
	return GeometryMeshingService.normalize_recipe(document.get("meshing", {}).get("recipe", {}))


func _geometry_uv_mapping_recipe(asset_id: String, component_id: String) -> Dictionary:
	var document := _get_geometry_document(asset_id, component_id)
	if document.is_empty():
		return GeometryUVMappingService.default_recipe()
	return GeometryUVMappingService.normalize_recipe(document.get("uv_mapping", {}).get("recipe", {}))


func _normalize_geometry_document(raw_document, asset_id: String, component_id: String) -> Dictionary:
	var source: Dictionary = raw_document if raw_document is Dictionary else {}
	var sampling_source = source.get("sampling", {})
	if not sampling_source is Dictionary:
		sampling_source = {}
	var document := _default_geometry_document(asset_id, component_id)
	var component_mesh_source = source.get("component_mesh", {})
	if component_mesh_source is Dictionary:
		document["component_mesh"] = {
			"bake_id": str(component_mesh_source.get("bake_id", "")),
			"method": str(component_mesh_source.get("method", "")),
			"mesh_fingerprint": str(component_mesh_source.get("mesh_fingerprint", "")),
			"build_provenance": component_mesh_source.get("build_provenance", {}).duplicate(true) if component_mesh_source.get("build_provenance", {}) is Dictionary else {},
			"last_error": str(component_mesh_source.get("last_error", "")),
			"last_failure_signature": component_mesh_source.get("last_failure_signature", {}).duplicate(true) if component_mesh_source.get("last_failure_signature", {}) is Dictionary else {}
		}
	document["sampling"]["recipe"] = GeometrySamplingService.normalize_recipe(sampling_source.get("recipe", {}))
	var raw_sampling_bakes: Dictionary = sampling_source.get("bakes", {}) if sampling_source.get("bakes", {}) is Dictionary else {}
	if raw_sampling_bakes.is_empty() and sampling_source.get("bake", {}) is Dictionary:
		var legacy_sampling_bake: Dictionary = sampling_source.get("bake", {})
		if bool(legacy_sampling_bake.get("valid", false)):
			raw_sampling_bakes[str(legacy_sampling_bake.get("method", GeometrySamplingService.ADAPTIVE))] = legacy_sampling_bake
	for raw_method in raw_sampling_bakes:
		var raw_sampling_bake = raw_sampling_bakes[raw_method]
		if str(raw_method) == GeometrySamplingService.EVEN_SPACING or (raw_sampling_bake is Dictionary and str(raw_sampling_bake.get("method", "")) == GeometrySamplingService.EVEN_SPACING):
			continue
		var sampling_bake := _normalize_sampling_bake(raw_sampling_bake)
		if not sampling_bake.is_empty():
			document["sampling"]["bakes"][str(sampling_bake.get("method", raw_method))] = sampling_bake
	var seeding_source = source.get("seeding", {})
	if not seeding_source is Dictionary:
		seeding_source = {}
	document["seeding"]["recipe"] = GeometrySeedingService.normalize_recipe(seeding_source.get("recipe", {}))
	var raw_seeding_bakes: Dictionary = seeding_source.get("bakes", {}) if seeding_source.get("bakes", {}) is Dictionary else {}
	if raw_seeding_bakes.is_empty() and seeding_source.get("bake", {}) is Dictionary:
		var legacy_seeding_bake: Dictionary = seeding_source.get("bake", {})
		if bool(legacy_seeding_bake.get("valid", false)):
			raw_seeding_bakes[str(legacy_seeding_bake.get("method", GeometrySeedingService.POISSON_FILL))] = legacy_seeding_bake
	for raw_method in raw_seeding_bakes:
		var seeding_bake := _normalize_seeding_bake(raw_seeding_bakes[raw_method])
		if not seeding_bake.is_empty():
			document["seeding"]["bakes"][str(seeding_bake.get("method", raw_method))] = seeding_bake
	var meshing_source = source.get("meshing", {})
	if not meshing_source is Dictionary:
		meshing_source = {}
	var raw_meshing_recipe: Dictionary = meshing_source.get("recipe", {}) if meshing_source.get("recipe", {}) is Dictionary else {}
	document["meshing"]["recipe"] = GeometryMeshingService.normalize_recipe(raw_meshing_recipe)
	var raw_meshing_bakes: Dictionary = meshing_source.get("bakes", {}) if meshing_source.get("bakes", {}) is Dictionary else {}
	var preferred_mesh_method := str(component_mesh_source.get("method", raw_meshing_recipe.get("method", GeometryMeshingService.CONSTRAINED_MESH))) if component_mesh_source is Dictionary else str(raw_meshing_recipe.get("method", GeometryMeshingService.CONSTRAINED_MESH))
	var chosen_raw_bake: Dictionary = {}
	if raw_meshing_bakes.get(preferred_mesh_method, {}) is Dictionary:
		chosen_raw_bake = raw_meshing_bakes.get(preferred_mesh_method, {})
	if chosen_raw_bake.is_empty():
		for fallback_method in [GeometryMeshingService.CONSTRAINED_MESH, GeometryMeshingService.ORGANIC_RELAXED, GeometryMeshingService.CONSTRAINED_DELAUNAY, RibbonMeshService.METHOD]:
			if raw_meshing_bakes.get(fallback_method, {}) is Dictionary and not raw_meshing_bakes.get(fallback_method, {}).is_empty():
				chosen_raw_bake = raw_meshing_bakes[fallback_method]
				break
	if not chosen_raw_bake.is_empty():
		var meshing_bake := _normalize_meshing_bake(chosen_raw_bake)
		if not meshing_bake.is_empty():
			document["meshing"]["bakes"][str(meshing_bake.get("method", GeometryMeshingService.CONSTRAINED_MESH))] = meshing_bake
			if preferred_mesh_method in [GeometryMeshingService.CONSTRAINED_DELAUNAY, GeometryMeshingService.ORGANIC_RELAXED]:
				document["meshing"]["recipe"] = GeometryMeshingService.normalize_recipe({"method": preferred_mesh_method, "parameters": chosen_raw_bake.get("parameters", {})})
			if str(document["component_mesh"].get("bake_id", "")) == str(meshing_bake.get("bake_id", "")):
				document["component_mesh"]["method"] = str(meshing_bake.get("method", GeometryMeshingService.CONSTRAINED_MESH))
	var uv_mapping_source = source.get("uv_mapping", {})
	if not uv_mapping_source is Dictionary:
		uv_mapping_source = {}
	document["uv_mapping"]["recipe"] = GeometryUVMappingService.normalize_recipe(uv_mapping_source.get("recipe", {}))
	document["uv_mapping"]["last_error"] = str(uv_mapping_source.get("last_error", ""))
	document["uv_mapping"]["last_failure_fingerprint"] = str(uv_mapping_source.get("last_failure_fingerprint", ""))
	var raw_uv_bakes: Dictionary = uv_mapping_source.get("bakes", {}) if uv_mapping_source.get("bakes", {}) is Dictionary else {}
	var uv_bake_scores: Dictionary = {}
	var chosen_mesh_bake_id := str(chosen_raw_bake.get("bake_id", ""))
	for raw_key in raw_uv_bakes:
		var uv_bake := _normalize_uv_mapping_bake(raw_uv_bakes[raw_key])
		if not uv_bake.is_empty():
			var bake_key := GeometryUVMappingService.bake_key(str(uv_bake.get("mesh_method", "")), str(uv_bake.get("method", "")))
			var raw_uv_bake: Dictionary = raw_uv_bakes[raw_key]
			var score := 0
			if not chosen_mesh_bake_id.is_empty() and str(raw_uv_bake.get("mesh_bake_id", "")) == chosen_mesh_bake_id:
				score = 2
			elif str(raw_uv_bake.get("mesh_method", "")) == preferred_mesh_method:
				score = 1
			if not document["uv_mapping"]["bakes"].has(bake_key) or score > int(uv_bake_scores.get(bake_key, -1)):
				document["uv_mapping"]["bakes"][bake_key] = uv_bake
				uv_bake_scores[bake_key] = score
	var sdf_source = source.get("sdf", {})
	if sdf_source is Dictionary:
		document["sdf"]["recipe"] = GeometrySDFService.normalize_recipe(sdf_source.get("recipe", {}))
		document["sdf"]["bake"] = _normalize_sdf_bake(sdf_source.get("bake", {}))
		document["sdf"]["last_error"] = str(sdf_source.get("last_error", ""))
		document["sdf"]["last_failure_fingerprint"] = str(sdf_source.get("last_failure_fingerprint", ""))
	var weighting_source = source.get("weighting", {})
	if weighting_source is Dictionary:
		document["weighting"]["next_style_index"] = maxi(1, int(weighting_source.get("next_style_index", 1)))
		for raw_style in weighting_source.get("styles", []):
			var style := WeightingService.normalize_style(raw_style)
			if not str(style.get("id", "")).is_empty():
				document["weighting"]["styles"].append(style)
	return document


func _normalize_sampling_bake(raw_bake) -> Dictionary:
	if not raw_bake is Dictionary or not bool(raw_bake.get("valid", false)):
		return {}
	var bake: Dictionary = raw_bake.duplicate(true)
	var normalized_chains: Array = []
	for raw_chain in raw_bake.get("chains", []):
		if not raw_chain is Dictionary:
			continue
		var samples: Array = []
		for raw_sample in raw_chain.get("samples", []):
			if raw_sample is Dictionary:
				samples.append({"id": str(raw_sample.get("id", "")), "position": _deserialize_vector(raw_sample.get("position", [0.0, 0.0]), Vector2.ZERO), "edge_id": str(raw_sample.get("edge_id", "")), "curve_t": clampf(float(raw_sample.get("curve_t", 0.0)), 0.0, 1.0), "source_point_id": str(raw_sample.get("source_point_id", "")), "preserved": bool(raw_sample.get("preserved", false))})
		normalized_chains.append({"chain_id": str(raw_chain.get("chain_id", "")), "input_id": str(raw_chain.get("input_id", "")), "topology_role": str(raw_chain.get("topology_role", "outer")), "closed": bool(raw_chain.get("closed", false)), "effective_spacing": maxf(float(raw_chain.get("effective_spacing", raw_bake.get("parameters", {}).get("spacing", GeometrySamplingService.DEFAULT_SPACING))), GeometrySamplingService.MIN_SPACING), "samples": samples})
	bake["method"] = GeometrySamplingService.ADAPTIVE
	bake["algorithm_version"] = int(raw_bake.get("algorithm_version", 0))
	bake["parameters"] = GeometrySamplingService.normalize_recipe({"method": bake["method"], "parameters": raw_bake.get("parameters", {})})["parameters"]
	bake["chains"] = normalized_chains
	var normalized_cuts: Array = []
	for raw_cut in raw_bake.get("cuts", []):
		if not raw_cut is Dictionary:
			continue
		var cut_samples: Array = []
		for raw_sample in raw_cut.get("samples", []):
			if raw_sample is Dictionary:
				cut_samples.append({"id": str(raw_sample.get("id", "")), "position": _deserialize_vector(raw_sample.get("position", [0.0, 0.0]), Vector2.ZERO), "edge_id": str(raw_sample.get("edge_id", "")), "curve_t": clampf(float(raw_sample.get("curve_t", 0.0)), 0.0, 1.0), "source_point_id": str(raw_sample.get("source_point_id", "")), "preserved": bool(raw_sample.get("preserved", false)), "guide_id": str(raw_sample.get("guide_id", raw_cut.get("guide_id", "")))})
		var normalized_fragments: Array = []
		for raw_fragment in raw_cut.get("fragments", []):
			if not raw_fragment is Dictionary:
				continue
			var fragment_samples: Array = []
			for raw_sample in raw_fragment.get("samples", []):
				if raw_sample is Dictionary:
					fragment_samples.append({"id": str(raw_sample.get("id", "")), "position": _deserialize_vector(raw_sample.get("position", [0.0, 0.0]), Vector2.ZERO), "edge_id": str(raw_sample.get("edge_id", "")), "curve_t": clampf(float(raw_sample.get("curve_t", 0.0)), 0.0, 1.0), "source_point_id": str(raw_sample.get("source_point_id", "")), "preserved": bool(raw_sample.get("preserved", false)), "guide_id": str(raw_sample.get("guide_id", raw_cut.get("guide_id", "")))})
			if fragment_samples.size() >= 2:
				normalized_fragments.append({"id": str(raw_fragment.get("id", "cut:%s:fragment:%d" % [str(raw_cut.get("guide_id", "")), normalized_fragments.size()])), "samples": fragment_samples})
		if normalized_fragments.is_empty() and cut_samples.size() >= 2:
			normalized_fragments.append({"id": "cut:%s:fragment:0" % str(raw_cut.get("guide_id", "")), "samples": cut_samples.duplicate(true)})
		normalized_cuts.append({"valid": bool(raw_cut.get("valid", true)), "errors": raw_cut.get("errors", []).duplicate(), "guide_id": str(raw_cut.get("guide_id", "")), "input_id": str(raw_cut.get("input_id", raw_cut.get("guide_id", ""))), "effective_spacing": maxf(float(raw_cut.get("effective_spacing", raw_bake.get("parameters", {}).get("spacing", GeometrySamplingService.DEFAULT_SPACING))), GeometrySamplingService.MIN_SPACING), "samples": cut_samples, "fragments": normalized_fragments})
	bake["cuts"] = normalized_cuts
	bake["sample_count"] = int(raw_bake.get("sample_count", 0))
	bake["preserve_count"] = int(raw_bake.get("preserve_count", 0))
	bake["hole_count"] = normalized_chains.filter(func(chain: Dictionary) -> bool: return str(chain.get("topology_role", "outer")) == "hole").size()
	var constraint_count := 0
	for chain_data in normalized_chains:
		constraint_count += chain_data.get("samples", []).size()
	for cut_data in normalized_cuts:
		constraint_count += cut_data.get("samples", []).size()
	bake["constraint_sample_count"] = constraint_count
	var boundary_stats: Array = []
	for chain_data in normalized_chains:
		boundary_stats.append({"input_id": str(chain_data.get("input_id", "")), "role": str(chain_data.get("topology_role", "outer")), "effective_spacing": float(chain_data.get("effective_spacing", GeometrySamplingService.DEFAULT_SPACING)), "sample_count": chain_data.get("samples", []).size()})
	for cut_data in normalized_cuts:
		boundary_stats.append({"input_id": str(cut_data.get("input_id", cut_data.get("guide_id", ""))), "role": "cut", "effective_spacing": float(cut_data.get("effective_spacing", GeometrySamplingService.DEFAULT_SPACING)), "sample_count": cut_data.get("samples", []).size()})
	bake["boundary_stats"] = boundary_stats
	return bake


func _normalize_seeding_bake(raw_bake) -> Dictionary:
	if not raw_bake is Dictionary or not bool(raw_bake.get("valid", false)):
		return {}
	var bake: Dictionary = raw_bake.duplicate(true)
	var normalized_seeds: Array = []
	for raw_seed in raw_bake.get("seeds", []):
		if raw_seed is Dictionary:
			normalized_seeds.append({"id": str(raw_seed.get("id", "")), "position": _deserialize_vector(raw_seed.get("position", [0.0, 0.0]), Vector2.ZERO), "origin": str(raw_seed.get("origin", "generated")), "method": str(raw_seed.get("method", GeometrySeedingService.POISSON_FILL)), "provenance": raw_seed.get("provenance", {}).duplicate(true) if raw_seed.get("provenance", {}) is Dictionary else {}})
	bake["method"] = str(raw_bake.get("method", GeometrySeedingService.POISSON_FILL))
	bake["parameters"] = GeometrySeedingService.normalize_recipe({"method": bake["method"], "parameters": raw_bake.get("parameters", {})})["parameters"]
	bake["seeds"] = normalized_seeds
	bake["seed_count"] = normalized_seeds.size()
	bake["edited"] = bool(raw_bake.get("edited", false))
	return bake


func _normalize_meshing_bake(raw_bake) -> Dictionary:
	if not raw_bake is Dictionary or not bool(raw_bake.get("valid", false)):
		return {}
	var bake: Dictionary = raw_bake.duplicate(true)
	var normalized_vertices: Array = []
	for raw_vertex in raw_bake.get("vertices", []):
		if raw_vertex is Dictionary:
			normalized_vertices.append({
				"id": str(raw_vertex.get("id", "")),
				"position": _deserialize_vector(raw_vertex.get("position", [0.0, 0.0]), Vector2.ZERO),
				"origin": str(raw_vertex.get("origin", "seed")),
				"source_id": str(raw_vertex.get("source_id", "")),
				"preserved": bool(raw_vertex.get("preserved", false))
			})
	var normalized_triangles: Array = []
	for raw_triangle in raw_bake.get("triangles", []):
		if raw_triangle is Dictionary and raw_triangle.get("vertex_ids", []) is Array:
			normalized_triangles.append({"vertex_ids": raw_triangle.get("vertex_ids", []).duplicate()})
	var normalized_recipe := GeometryMeshingService.normalize_recipe({"method": str(raw_bake.get("method", GeometryMeshingService.CONSTRAINED_MESH)), "parameters": raw_bake.get("parameters", {})})
	bake["method"] = str(normalized_recipe.get("method", GeometryMeshingService.CONSTRAINED_MESH))
	bake["parameters"] = normalized_recipe["parameters"]
	bake["algorithm_version"] = int(raw_bake.get("algorithm_version", 0))
	bake["vertices"] = normalized_vertices
	bake["triangles"] = normalized_triangles
	bake["boundary_constraints"] = raw_bake.get("boundary_constraints", []).duplicate(true)
	bake["vertex_count"] = normalized_vertices.size()
	bake["triangle_count"] = normalized_triangles.size()
	bake["minimum_angle"] = maxf(float(raw_bake.get("minimum_angle", 0.0)), 0.0)
	bake["worst_aspect_ratio"] = maxf(float(raw_bake.get("worst_aspect_ratio", 0.0)), 0.0)
	bake["mean_quality"] = clampf(float(raw_bake.get("mean_quality", 0.0)), 0.0, 1.0)
	var raw_optimization = raw_bake.get("optimization", {})
	var optimization: Dictionary = raw_optimization.duplicate(true) if raw_optimization is Dictionary else {}
	var normalized_movements: Array = []
	for raw_movement in optimization.get("movements", []):
		if raw_movement is Dictionary:
			normalized_movements.append({
				"vertex_id": str(raw_movement.get("vertex_id", "")),
				"from": _deserialize_vector(raw_movement.get("from", [0.0, 0.0]), Vector2.ZERO),
				"to": _deserialize_vector(raw_movement.get("to", [0.0, 0.0]), Vector2.ZERO),
				"distance": maxf(float(raw_movement.get("distance", 0.0)), 0.0)
			})
	optimization["movements"] = normalized_movements
	var normalized_baseline_triangles: Array = []
	for raw_triangle in optimization.get("baseline_triangles", []):
		if raw_triangle is Dictionary and raw_triangle.get("vertex_ids", []) is Array:
			normalized_baseline_triangles.append({"vertex_ids": raw_triangle.get("vertex_ids", []).duplicate()})
	optimization["baseline_triangles"] = normalized_baseline_triangles
	bake["optimization"] = optimization
	return bake


func _normalize_uv_mapping_bake(raw_bake) -> Dictionary:
	if not raw_bake is Dictionary or not bool(raw_bake.get("valid", false)):
		return {}
	var bake: Dictionary = raw_bake.duplicate(true)
	var normalized_uvs: Array = []
	for raw_entry in raw_bake.get("uvs", []):
		if raw_entry is Dictionary:
			normalized_uvs.append({
				"vertex_id": str(raw_entry.get("vertex_id", "")),
				"uv": _deserialize_vector(raw_entry.get("uv", [0.0, 0.0]), Vector2.ZERO)
			})
	bake["method"] = str(raw_bake.get("method", GeometryUVMappingService.BOUNDS_PLANAR))
	var raw_mesh_method := str(raw_bake.get("mesh_method", GeometryMeshingService.CONSTRAINED_MESH))
	bake["mesh_method"] = GeometryMeshingService.CONSTRAINED_MESH if raw_mesh_method in [GeometryMeshingService.CONSTRAINED_DELAUNAY, GeometryMeshingService.ORGANIC_RELAXED] else raw_mesh_method
	var raw_parameters: Dictionary = raw_bake.get("parameters", {}).duplicate(true) if raw_bake.get("parameters", {}) is Dictionary else {}
	# Pre-schema-36 UVs touched the normalized bounds. Preserve that exact
	# meaning so the new padded default marks them stale instead of relabeling
	# their old coordinates as padded.
	if not raw_parameters.has("padding"):
		raw_parameters["padding"] = 0.0
	bake["parameters"] = GeometryUVMappingService.normalize_recipe({"method": bake["method"], "parameters": raw_parameters})["parameters"]
	bake["uvs"] = normalized_uvs
	bake["uv_count"] = normalized_uvs.size()
	return bake


func _serialize_sampling_bake(bake: Dictionary) -> Dictionary:
	var serialized_bake := bake.duplicate(true)
	var serialized_chains: Array = []
	for chain_data in bake.get("chains", []):
		var serialized_samples: Array = []
		for sample in chain_data.get("samples", []):
			serialized_samples.append({"id": str(sample.get("id", "")), "position": _serialize_vector(Vector2(sample.get("position", Vector2.ZERO))), "edge_id": str(sample.get("edge_id", "")), "curve_t": float(sample.get("curve_t", 0.0)), "source_point_id": str(sample.get("source_point_id", "")), "preserved": bool(sample.get("preserved", false))})
		serialized_chains.append({"chain_id": str(chain_data.get("chain_id", "")), "input_id": str(chain_data.get("input_id", "")), "topology_role": str(chain_data.get("topology_role", "outer")), "closed": bool(chain_data.get("closed", false)), "effective_spacing": float(chain_data.get("effective_spacing", GeometrySamplingService.DEFAULT_SPACING)), "samples": serialized_samples})
	serialized_bake["chains"] = serialized_chains
	var serialized_cuts: Array = []
	for cut_data in bake.get("cuts", []):
		var serialized_samples: Array = []
		for sample in cut_data.get("samples", []):
			serialized_samples.append({"id": str(sample.get("id", "")), "position": _serialize_vector(Vector2(sample.get("position", Vector2.ZERO))), "edge_id": str(sample.get("edge_id", "")), "curve_t": float(sample.get("curve_t", 0.0)), "source_point_id": str(sample.get("source_point_id", "")), "preserved": bool(sample.get("preserved", false)), "guide_id": str(sample.get("guide_id", cut_data.get("guide_id", "")))})
		var serialized_fragments: Array = []
		for fragment in GeometrySamplingService.cut_fragments(cut_data):
			var fragment_samples: Array = []
			for sample in fragment.get("samples", []):
				fragment_samples.append({"id": str(sample.get("id", "")), "position": _serialize_vector(Vector2(sample.get("position", Vector2.ZERO))), "edge_id": str(sample.get("edge_id", "")), "curve_t": float(sample.get("curve_t", 0.0)), "source_point_id": str(sample.get("source_point_id", "")), "preserved": bool(sample.get("preserved", false)), "guide_id": str(sample.get("guide_id", cut_data.get("guide_id", "")))})
			serialized_fragments.append({"id": str(fragment.get("id", "")), "samples": fragment_samples})
		serialized_cuts.append({"valid": bool(cut_data.get("valid", true)), "errors": cut_data.get("errors", []).duplicate(), "guide_id": str(cut_data.get("guide_id", "")), "input_id": str(cut_data.get("input_id", cut_data.get("guide_id", ""))), "effective_spacing": float(cut_data.get("effective_spacing", GeometrySamplingService.DEFAULT_SPACING)), "samples": serialized_samples, "fragments": serialized_fragments})
	serialized_bake["cuts"] = serialized_cuts
	serialized_bake["hole_count"] = serialized_chains.filter(func(chain: Dictionary) -> bool: return str(chain.get("topology_role", "outer")) == "hole").size()
	return serialized_bake


func _serialize_seeding_bake(bake: Dictionary) -> Dictionary:
	var serialized_bake := bake.duplicate(true)
	var serialized_seeds: Array = []
	for seed_data in bake.get("seeds", []):
		serialized_seeds.append({"id": str(seed_data.get("id", "")), "position": _serialize_vector(Vector2(seed_data.get("position", Vector2.ZERO))), "origin": str(seed_data.get("origin", "generated")), "method": str(seed_data.get("method", GeometrySeedingService.POISSON_FILL)), "provenance": seed_data.get("provenance", {}).duplicate(true) if seed_data.get("provenance", {}) is Dictionary else {}})
	serialized_bake["seeds"] = serialized_seeds
	return serialized_bake


func _serialize_meshing_bake(bake: Dictionary) -> Dictionary:
	var serialized_bake := bake.duplicate(true)
	var serialized_vertices: Array = []
	for vertex in bake.get("vertices", []):
		serialized_vertices.append({
			"id": str(vertex.get("id", "")),
			"position": _serialize_vector(Vector2(vertex.get("position", Vector2.ZERO))),
			"origin": str(vertex.get("origin", "seed")),
			"source_id": str(vertex.get("source_id", "")),
			"preserved": bool(vertex.get("preserved", false))
		})
	serialized_bake["vertices"] = serialized_vertices
	var raw_optimization = bake.get("optimization", {})
	if raw_optimization is Dictionary:
		var optimization: Dictionary = raw_optimization.duplicate(true)
		var serialized_movements: Array = []
		for movement in optimization.get("movements", []):
			if movement is Dictionary:
				serialized_movements.append({
					"vertex_id": str(movement.get("vertex_id", "")),
					"from": _serialize_vector(_deserialize_vector(movement.get("from", Vector2.ZERO), Vector2.ZERO)),
					"to": _serialize_vector(_deserialize_vector(movement.get("to", Vector2.ZERO), Vector2.ZERO)),
					"distance": maxf(float(movement.get("distance", 0.0)), 0.0)
				})
		optimization["movements"] = serialized_movements
		serialized_bake["optimization"] = optimization
	return serialized_bake


func _serialize_uv_mapping_bake(bake: Dictionary) -> Dictionary:
	var serialized_bake := bake.duplicate(true)
	var serialized_uvs: Array = []
	for entry in bake.get("uvs", []):
		serialized_uvs.append({
			"vertex_id": str(entry.get("vertex_id", "")),
			"uv": _serialize_vector(Vector2(entry.get("uv", Vector2.ZERO)))
		})
	serialized_bake["uvs"] = serialized_uvs
	return serialized_bake


func _normalize_sdf_bake(raw_bake) -> Dictionary:
	if not raw_bake is Dictionary or not bool(raw_bake.get("valid", false)):
		return {}
	var bake: Dictionary = raw_bake.duplicate(true)
	bake.erase("image")
	bake["method"] = str(raw_bake.get("method", GeometrySDFService.SINGLE_CHANNEL_SDF))
	bake["algorithm_version"] = int(raw_bake.get("algorithm_version", 0))
	bake["parameters"] = GeometrySDFService.normalize_recipe({"method": bake["method"], "parameters": raw_bake.get("parameters", {})})["parameters"]
	bake["resolution"] = raw_bake.get("resolution", [GeometrySDFService.DEFAULT_RESOLUTION, GeometrySDFService.DEFAULT_RESOLUTION]).duplicate()
	bake["image_path"] = str(raw_bake.get("image_path", "contour_sdf.png"))
	return bake


func _serialize_sdf_bake(bake: Dictionary) -> Dictionary:
	var serialized := bake.duplicate(true)
	serialized.erase("image")
	return serialized


func _serialize_geometry_document(document: Dictionary) -> Dictionary:
	var normalized := _normalize_geometry_document(document, str(document.get("asset_id", "")), str(document.get("component_id", "")))
	var serialized_sampling_bakes: Dictionary = {}
	for method in normalized.get("sampling", {}).get("bakes", {}):
		serialized_sampling_bakes[str(method)] = _serialize_sampling_bake(normalized["sampling"]["bakes"][method])
	var serialized_seeding_bakes: Dictionary = {}
	for method in normalized.get("seeding", {}).get("bakes", {}):
		serialized_seeding_bakes[str(method)] = _serialize_seeding_bake(normalized["seeding"]["bakes"][method])
	var serialized_meshing_bakes: Dictionary = {}
	for method in normalized.get("meshing", {}).get("bakes", {}):
		serialized_meshing_bakes[str(method)] = _serialize_meshing_bake(normalized["meshing"]["bakes"][method])
	var serialized_uv_mapping_bakes: Dictionary = {}
	for bake_key in normalized.get("uv_mapping", {}).get("bakes", {}):
		serialized_uv_mapping_bakes[str(bake_key)] = _serialize_uv_mapping_bake(normalized["uv_mapping"]["bakes"][bake_key])
	return {
		"schema_version": SCHEMA_VERSION,
		"asset_id": str(normalized.get("asset_id", "")),
		"component_id": str(normalized.get("component_id", "")),
		"component_mesh": normalized.get("component_mesh", {}).duplicate(true),
		"sampling": {
			"recipe": normalized.get("sampling", {}).get("recipe", {}).duplicate(true),
			"bakes": serialized_sampling_bakes
		},
		"seeding": {
			"recipe": normalized.get("seeding", {}).get("recipe", {}).duplicate(true),
			"bakes": serialized_seeding_bakes
		},
		"meshing": {
			"recipe": normalized.get("meshing", {}).get("recipe", {}).duplicate(true),
			"bakes": serialized_meshing_bakes
		},
		"uv_mapping": {
			"recipe": normalized.get("uv_mapping", {}).get("recipe", {}).duplicate(true),
			"bakes": serialized_uv_mapping_bakes,
			"last_error": str(normalized.get("uv_mapping", {}).get("last_error", "")),
			"last_failure_fingerprint": str(normalized.get("uv_mapping", {}).get("last_failure_fingerprint", ""))
		},
		"sdf": {
			"recipe": normalized.get("sdf", {}).get("recipe", {}).duplicate(true),
			"bake": _serialize_sdf_bake(normalized.get("sdf", {}).get("bake", {})),
			"last_error": str(normalized.get("sdf", {}).get("last_error", "")),
			"last_failure_fingerprint": str(normalized.get("sdf", {}).get("last_failure_fingerprint", ""))
		},
		"weighting": {
			"next_style_index": int(normalized.get("weighting", {}).get("next_style_index", 1)),
			"styles": normalized.get("weighting", {}).get("styles", []).duplicate(true)
		}
	}


func _geometry_sampling_bakes(asset_id: String, component_id: String) -> Dictionary:
	var document := _get_geometry_document(asset_id, component_id)
	return document.get("sampling", {}).get("bakes", {}) if not document.is_empty() else {}


func _geometry_sampling_bake(asset_id: String, component_id: String, method := "") -> Dictionary:
	var resolved_method := method if not method.is_empty() else str(_geometry_sampling_recipe(asset_id, component_id).get("method", ""))
	return _geometry_sampling_bakes(asset_id, component_id).get(resolved_method, {})


func _geometry_sampling_bake_by_id(asset_id: String, component_id: String, bake_id: String) -> Dictionary:
	for bake in _geometry_sampling_bakes(asset_id, component_id).values():
		if bake is Dictionary and str(bake.get("bake_id", "")) == bake_id:
			return bake
	return {}


func _geometry_sampling_bake_is_current(asset_id: String, component_id: String, component: Dictionary) -> bool:
	var bake := _geometry_sampling_bake(asset_id, component_id)
	if component.is_empty() or bake.is_empty() or not bool(bake.get("valid", false)):
		return false
	var recipe := _geometry_sampling_recipe(asset_id, component_id)
	var cut_guides := _cut_guides_for_component(_get_asset(asset_id), component_id)
	var hole_components := _geometry_sampling_hole_components(_get_asset(asset_id), component_id)
	var semantic_signature = bake.get("semantic_source_signature", {})
	if semantic_signature is Dictionary and not semantic_signature.is_empty():
		var current_signature := GeometryAutoBuildService.source_signature(component, cut_guides, hole_components, {"sampling": recipe})
		return GeometryAutoBuildService.signatures_match(current_signature, semantic_signature)
	return str(bake.get("source_fingerprint", "")) == GeometrySamplingService.source_fingerprint(component, cut_guides, hole_components) \
		and int(bake.get("algorithm_version", 0)) == GeometrySamplingService.ALGORITHM_VERSION \
		and str(bake.get("method", "")) == str(recipe.get("method", "")) \
		and bake.get("parameters", {}) == recipe.get("parameters", {})


func _geometry_sampling_status(asset_id: String, component_id: String, component: Dictionary) -> String:
	if component.is_empty():
		return "Invalid"
	var asset := _get_asset(asset_id)
	var cut_guides := _cut_guides_for_component(asset, component_id)
	var hole_components := _geometry_sampling_hole_components(asset, component_id)
	if not GeometrySamplingService.validation_issues(component, cut_guides, hole_components).is_empty():
		return "Invalid"
	var document_key := _geometry_document_key(asset_id, component_id)
	if geometry_sampling_preview_key == document_key:
		if geometry_sampling_preview_state == "calculating":
			return "Calculating"
		if geometry_sampling_preview_state == "invalid":
			return "Invalid"
		if geometry_sampling_preview_state == "ready" and _geometry_sampling_preview_matches(asset_id, component_id, component):
			return "Preview Ready"
	var bake := _geometry_sampling_bake(asset_id, component_id)
	return "Baked" if not bake.is_empty() and _geometry_sampling_bake_is_current(asset_id, component_id, component) else "Ready to Preview"


func _geometry_sampling_preview_matches(asset_id: String, component_id: String, component: Dictionary) -> bool:
	if geometry_sampling_preview_key != _geometry_document_key(asset_id, component_id) or not bool(geometry_sampling_preview.get("valid", false)):
		return false
	var recipe := _geometry_sampling_recipe(asset_id, component_id)
	var asset := _get_asset(asset_id)
	var cut_guides := _cut_guides_for_component(asset, component_id)
	var hole_components := _geometry_sampling_hole_components(asset, component_id)
	return str(geometry_sampling_preview.get("source_fingerprint", "")) == GeometrySamplingService.source_fingerprint(component, cut_guides, hole_components) \
		and int(geometry_sampling_preview.get("algorithm_version", 0)) == GeometrySamplingService.ALGORITHM_VERSION \
		and str(geometry_sampling_preview.get("method", "")) == str(recipe.get("method", "")) \
		and geometry_sampling_preview.get("parameters", {}) == recipe.get("parameters", {})


func _geometry_seeding_bakes(asset_id: String, component_id: String) -> Dictionary:
	var document := _get_geometry_document(asset_id, component_id)
	return document.get("seeding", {}).get("bakes", {}) if not document.is_empty() else {}


func _geometry_seeding_bake(asset_id: String, component_id: String, method := "") -> Dictionary:
	var resolved_method := method if not method.is_empty() else str(_geometry_seeding_recipe(asset_id, component_id).get("method", ""))
	return _geometry_seeding_bakes(asset_id, component_id).get(resolved_method, {})


func _sampler_spines_for_component(asset: Dictionary, component_id: String) -> Array:
	var guides: Array = []
	for guide in asset.get("guides", []):
		if str(guide.get("guide_type", "")) == AssetGuide.SAMPLER_SPINE \
			and str(guide.get("scope", {}).get("component_id", "")) == component_id:
			guides.append(guide)
	guides.sort_custom(_sort_named_documents)
	return guides


func _cut_guides_for_component(asset: Dictionary, component_id: String) -> Array:
	var guides: Array = []
	for guide in asset.get("guides", []):
		if str(guide.get("guide_type", "")) == AssetGuide.CUT \
			and str(guide.get("scope", {}).get("component_id", "")) == component_id:
			guides.append(guide)
	guides.sort_custom(_sort_named_documents)
	return guides


func _animation_spines_for_component(asset: Dictionary, component_id: String) -> Array:
	var guides: Array = []
	for guide in asset.get("guides", []):
		if str(guide.get("guide_type", "")) == AssetGuide.ANIMATION_SPINE \
			and str(guide.get("scope", {}).get("component_id", "")) == component_id:
			guides.append(guide)
	guides.sort_custom(_sort_named_documents)
	return guides


func _geometry_seeding_sampler_spine(asset_id: String, component_id: String, recipe: Dictionary = {}) -> Dictionary:
	var guides := _geometry_seeding_sampler_spines(asset_id, component_id, recipe)
	return guides[0] if not guides.is_empty() else {}


func _geometry_seeding_sampler_spines(asset_id: String, component_id: String, recipe: Dictionary = {}) -> Array[Dictionary]:
	var resolved_recipe := recipe if not recipe.is_empty() else _geometry_seeding_recipe(asset_id, component_id)
	if str(resolved_recipe.get("method", "")) != GeometrySeedingService.SPINE_FLOW:
		return []
	var result: Array[Dictionary] = []
	var asset := _get_asset(asset_id)
	for input in resolved_recipe.get("parameters", {}).get("spine_inputs", []):
		if not input is Dictionary or not bool(input.get("enabled", true)):
			continue
		var guide := _get_guide(asset, str(input.get("guide_id", "")))
		if not guide.is_empty() and str(guide.get("guide_type", "")) == AssetGuide.SAMPLER_SPINE \
			and str(guide.get("scope", {}).get("component_id", "")) == component_id:
			result.append(guide)
	return result


func _geometry_seeding_result_matches(result: Dictionary, asset_id: String, component_id: String, component: Dictionary) -> bool:
	if result.is_empty() or not bool(result.get("valid", false)) or not _geometry_sampling_bake_is_current(asset_id, component_id, component):
		return false
	var sampling_bake := _geometry_sampling_bake(asset_id, component_id)
	var recipe := _geometry_seeding_recipe(asset_id, component_id)
	var matches: bool = int(result.get("algorithm_version", 0)) == GeometrySeedingService.ALGORITHM_VERSION \
		and str(result.get("sampling_bake_id", "")) == str(sampling_bake.get("bake_id", "")) \
		and str(result.get("sampling_fingerprint", "")) == GeometrySeedingService.sampling_fingerprint(sampling_bake) \
		and str(result.get("method", "")) == str(recipe.get("method", "")) \
		and result.get("parameters", {}) == recipe.get("parameters", {})
	if not matches:
		return false
	if str(recipe.get("method", "")) == GeometrySeedingService.SPINE_FLOW:
		var guides := _geometry_seeding_sampler_spines(asset_id, component_id, recipe)
		var guide_ids: Array[String] = []
		for guide in guides:
			guide_ids.append(str(guide.get("id", "")))
		return result.get("guide_ids", []) == guide_ids \
			and str(result.get("guides_fingerprint", "")) == GeometrySeedingService.guides_fingerprint(guides)
	return true


func _geometry_seeding_preview_matches(asset_id: String, component_id: String, component: Dictionary) -> bool:
	return geometry_seeding_preview_key == _geometry_document_key(asset_id, component_id) \
		and _geometry_seeding_result_matches(geometry_seeding_preview, asset_id, component_id, component)


func _geometry_seeding_status(asset_id: String, component_id: String, component: Dictionary) -> String:
	if component.is_empty() or _geometry_sampling_bake(asset_id, component_id).is_empty():
		return "Sampling Required"
	if not _geometry_sampling_bake_is_current(asset_id, component_id, component):
		return "Sampling Required"
	var recipe := _geometry_seeding_recipe(asset_id, component_id)
	var guides := _geometry_seeding_sampler_spines(asset_id, component_id, recipe)
	if not GeometrySeedingService.validation_issues(_geometry_sampling_bake(asset_id, component_id), recipe, guides).is_empty():
		return "Invalid"
	var document_key := _geometry_document_key(asset_id, component_id)
	if geometry_seeding_preview_key == document_key:
		if geometry_seeding_preview_state == "calculating":
			return "Calculating"
		if geometry_seeding_preview_state == "invalid":
			return "Invalid"
		if geometry_seeding_preview_state == "ready" and _geometry_seeding_preview_matches(asset_id, component_id, component):
			return "Preview Ready"
	var bake := _geometry_seeding_bake(asset_id, component_id)
	if bake.is_empty():
		return "Ready to Preview"
	if not _geometry_seeding_result_matches(bake, asset_id, component_id, component):
		return "Ready to Preview"
	return "Edited" if bool(bake.get("edited", false)) else "Baked"


func _geometry_meshing_bakes(asset_id: String, component_id: String) -> Dictionary:
	var document := _get_geometry_document(asset_id, component_id)
	return document.get("meshing", {}).get("bakes", {}) if not document.is_empty() else {}


func _geometry_meshing_bake(asset_id: String, component_id: String, method := "") -> Dictionary:
	var component := _get_component(_get_asset(asset_id), component_id)
	var resolved_method := method if not method.is_empty() else (RibbonMeshService.METHOD if str(component.get("draw_mode", "")) == "ribbon" else str(_geometry_meshing_recipe(asset_id, component_id).get("method", "")))
	return _geometry_meshing_bakes(asset_id, component_id).get(resolved_method, {})


func _component_mesh_reference(asset_id: String, component_id: String) -> Dictionary:
	var document := _get_geometry_document(asset_id, component_id)
	return document.get("component_mesh", {}) if not document.is_empty() else {}


func _component_mesh_bake(asset_id: String, component_id: String) -> Dictionary:
	var reference := _component_mesh_reference(asset_id, component_id)
	var method := str(reference.get("method", ""))
	var bake_id := str(reference.get("bake_id", ""))
	if method.is_empty() or bake_id.is_empty():
		return {}
	var bake := _geometry_meshing_bake(asset_id, component_id, method)
	return bake if str(bake.get("bake_id", "")) == bake_id else {}


func _component_mesh_status(asset_id: String, component_id: String, component: Dictionary) -> String:
	var reference := _component_mesh_reference(asset_id, component_id)
	if str(reference.get("bake_id", "")).is_empty():
		return "Missing"
	var method := str(reference.get("method", ""))
	var bake := _component_mesh_bake(asset_id, component_id)
	if bake.is_empty() or method not in GeometryMeshingService.VALID_METHODS:
		return "Stale"
	if str(reference.get("mesh_fingerprint", "")) != GeometryUVMappingService.mesh_fingerprint(bake):
		return "Stale"
	return "Ready" if _geometry_meshing_bake_is_current(asset_id, component_id, component, method) else "Stale"


func _geometry_asset_mesh_overview(asset_id: String) -> Dictionary:
	var asset := _get_asset(asset_id)
	if asset.is_empty():
		return {}
	var vertices: Array = []
	var triangles: Array = []
	var visible_component_count := 0
	var mesh_component_count := 0
	var asset_is_visible := bool(asset.get("visibility", true))
	for component in asset.get("components", []):
		if not component is Dictionary or str(component.get("type", "component")) == "guide" or _is_reference_component(component):
			continue
		if not asset_is_visible or not bool(component.get("visibility", true)):
			continue
		visible_component_count += 1
		var component_id := str(component.get("id", ""))
		if component_id.is_empty() or _component_mesh_status(asset_id, component_id, component) != "Ready":
			continue
		var mesh := _component_mesh_bake(asset_id, component_id)
		if not bool(mesh.get("valid", false)) or mesh.get("vertices", []).is_empty() or mesh.get("triangles", []).is_empty():
			continue
		var transform := ComponentHierarchy.world_transform(asset, component_id)
		var vertex_ids: Dictionary = {}
		for vertex in mesh.get("vertices", []):
			if not vertex is Dictionary:
				continue
			var local_id := str(vertex.get("id", ""))
			var overview_id := "%s/%s" % [component_id, local_id]
			vertex_ids[local_id] = overview_id
			var overview_vertex: Dictionary = vertex.duplicate(true)
			overview_vertex["id"] = overview_id
			overview_vertex["component_id"] = component_id
			overview_vertex["position"] = transform * Vector2(vertex.get("position", Vector2.ZERO))
			vertices.append(overview_vertex)
		for triangle in mesh.get("triangles", []):
			if not triangle is Dictionary:
				continue
			var local_ids: Array = triangle.get("vertex_ids", [])
			if local_ids.size() != 3 or not vertex_ids.has(str(local_ids[0])) or not vertex_ids.has(str(local_ids[1])) or not vertex_ids.has(str(local_ids[2])):
				continue
			var overview_triangle: Dictionary = triangle.duplicate(true)
			overview_triangle["id"] = "%s/%s" % [component_id, str(triangle.get("id", triangles.size()))]
			overview_triangle["component_id"] = component_id
			overview_triangle["vertex_ids"] = [vertex_ids[str(local_ids[0])], vertex_ids[str(local_ids[1])], vertex_ids[str(local_ids[2])]]
			triangles.append(overview_triangle)
		mesh_component_count += 1
	return {
		"valid": not vertices.is_empty() and not triangles.is_empty(),
		"method": "asset_mesh_overview",
		"vertices": vertices,
		"triangles": triangles,
		"vertex_count": vertices.size(),
		"triangle_count": triangles.size(),
		"mesh_component_count": mesh_component_count,
		"visible_component_count": visible_component_count
	}


func _geometry_build_recipes(asset_id: String, component_id: String, component: Dictionary, cut_guides: Array, hole_components: Array) -> Dictionary:
	var key := _geometry_document_key(asset_id, component_id)
	if not geometry_documents.has(key):
		return GeometryAutoBuildService.automatic_recipes(component, cut_guides, hole_components)
	return {
		"sampling": _geometry_sampling_recipe(asset_id, component_id),
		"seeding": _geometry_seeding_recipe(asset_id, component_id),
		"meshing": _geometry_meshing_recipe(asset_id, component_id),
		"metrics": GeometryAutoBuildService.analyze(component)
	}


func _geometry_build_signature(asset_id: String, component_id: String, component: Dictionary, recipes: Dictionary = {}) -> Dictionary:
	var asset := _get_asset(asset_id)
	var cut_guides := _cut_guides_for_component(asset, component_id)
	var hole_components := _geometry_sampling_hole_components(asset, component_id)
	var resolved_recipes := recipes if not recipes.is_empty() else _geometry_build_recipes(asset_id, component_id, component, cut_guides, hole_components)
	if str(component.get("draw_mode", "")) == "ribbon":
		resolved_recipes = {"ribbon": {"method": RibbonMeshService.METHOD, "width_px": float(component.get("ribbon_width_px", DEFAULT_RIBBON_WIDTH_PX))}}
	return GeometryAutoBuildService.source_signature(component, cut_guides, hole_components, resolved_recipes)


func _component_is_meshable_source(asset: Dictionary, component: Dictionary) -> bool:
	return _component_mesh_source_validation_issues(asset, component).is_empty()


func _component_mesh_source_validation_issues(asset: Dictionary, component: Dictionary) -> Array[String]:
	if component.is_empty():
		return ["Component source is missing."]
	if _is_reference_component(component):
		return ["Reference Components do not own a Component Mesh."]
	var draw_mode := str(component.get("draw_mode", "closed_loop"))
	if draw_mode == "ribbon":
		var ribbon_issues: Array[String] = []
		for issue in RibbonMeshService.validation_issues(component):
			ribbon_issues.append(str(issue))
		return ribbon_issues
	if draw_mode not in ["closed_loop", "primitive"]:
		return ["Draw Mode '%s' cannot be meshed." % draw_mode]
	var component_id := str(component.get("id", ""))
	var sampling_issues: Array[String] = []
	for issue in GeometrySamplingService.validation_issues(
		component,
		_cut_guides_for_component(asset, component_id),
		_geometry_sampling_hole_components(asset, component_id)
	):
		sampling_issues.append(str(issue))
	return sampling_issues


func _component_mesh_needs_update(asset_id: String, component: Dictionary) -> bool:
	var asset := _get_asset(asset_id)
	if asset.is_empty() or not bool(asset.get("visibility", true)) or not bool(component.get("visibility", true)):
		return false
	if not _component_is_meshable_source(asset, component):
		return false
	var component_id := str(component.get("id", ""))
	var current_signature := _geometry_build_signature(asset_id, component_id, component)
	var reference := _component_mesh_reference(asset_id, component_id)
	var failure_signature = reference.get("last_failure_signature", {})
	if failure_signature is Dictionary and GeometryAutoBuildService.signatures_match(current_signature, failure_signature):
		return false
	var provenance = reference.get("build_provenance", {})
	if not provenance is Dictionary:
		return true
	var baked_signature = provenance.get("source_signature", {})
	if not baked_signature is Dictionary or not GeometryAutoBuildService.signatures_match(current_signature, baked_signature):
		return true
	return _component_mesh_status(asset_id, component_id, component) != "Ready"


func _mesh_update_candidates(asset_id: String) -> Array[String]:
	var result: Array[String] = []
	var asset := _get_asset(asset_id)
	if asset.is_empty():
		return result
	for component in asset.get("components", []):
		if component is Dictionary and _component_mesh_needs_update(asset_id, component):
			result.append(str(component.get("id", "")))
	return result


func _all_mesh_update_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for asset in assets:
		if not asset is Dictionary:
			continue
		var asset_id := str(asset.get("id", ""))
		if asset_id.is_empty():
			continue
		for component_id in _mesh_update_candidates(asset_id):
			result.append({"asset_id": asset_id, "component_id": component_id})
	return result


func _invalidate_batch_status() -> void:
	batch_status_revision += 1
	if is_instance_valid(batch_status_refresh_timer) and batch_status_refresh_timer.is_inside_tree():
		batch_status_refresh_timer.start()


func _batch_status_snapshot() -> Dictionary:
	if batch_status_snapshot_revision == batch_status_revision and not batch_status_snapshot.is_empty():
		return batch_status_snapshot
	# Keep the prior UI-only snapshot during a short edit burst. Batch commands
	# never consume this cache and always rebuild their authoritative candidates.
	if not batch_status_snapshot.is_empty() and is_instance_valid(batch_status_refresh_timer) and not batch_status_refresh_timer.is_stopped():
		return batch_status_snapshot
	return _rebuild_batch_status_snapshot()


func _rebuild_batch_status_snapshot() -> Dictionary:
	var mesh_candidates := _all_mesh_update_candidates()
	var uv_candidates := _all_uv_update_candidates()
	var sdf_candidates := _all_sdf_update_candidates()
	var runtime_candidates := _all_runtime_export_candidates()
	batch_status_snapshot = {
		"mesh": {"candidates": mesh_candidates, "summary": _mesh_batch_summary(mesh_candidates)},
		"uv": {"candidates": uv_candidates, "summary": _uv_batch_summary(uv_candidates)},
		"sdf": {"candidates": sdf_candidates, "summary": _sdf_batch_summary(sdf_candidates)},
		"runtime": {"candidates": runtime_candidates, "summary": _runtime_export_batch_summary(runtime_candidates)}
	}
	batch_status_snapshot_revision = batch_status_revision
	batch_status_snapshot_build_count += 1
	return batch_status_snapshot


func _refresh_batch_status_snapshot() -> void:
	if mesh_batch_running or uv_batch_running or sdf_batch_running or runtime_export_batch_running:
		batch_status_refresh_timer.start()
		return
	_rebuild_batch_status_snapshot()
	_update_meshes_button()
	_update_uvs_button()
	_update_sdfs_button()
	_update_runtime_export_button()


func _update_meshes_button() -> void:
	if not is_instance_valid(update_meshes_button):
		return
	if mesh_batch_running or uv_batch_running or sdf_batch_running or runtime_export_batch_running:
		return
	var status: Dictionary = _batch_status_snapshot().get("mesh", {})
	var candidates: Array = status.get("candidates", [])
	var summary: Dictionary = status.get("summary", {})
	var count := candidates.size()
	update_meshes_button.text = "Update Meshes (%d)" % count
	update_meshes_button.tooltip_text = _batch_summary_tooltip(summary, "All Meshes current")
	update_meshes_button.set_attention_count(summary.get("attention", PackedStringArray()).size())
	update_meshes_button.disabled = count == 0


func _component_uv_needs_update(asset_id: String, component: Dictionary) -> bool:
	var asset := _get_asset(asset_id)
	if asset.is_empty() or not bool(asset.get("visibility", true)) or not bool(component.get("visibility", true)):
		return false
	var component_id := str(component.get("id", ""))
	if component_id.is_empty() or _component_mesh_status(asset_id, component_id, component) != "Ready":
		return false
	var mesh := _component_mesh_bake(asset_id, component_id)
	var recipe := _resolved_geometry_uv_mapping_recipe(asset_id, component_id)
	var fingerprint := GeometryUVMappingService.source_fingerprint(mesh, recipe)
	var document := _get_geometry_document(asset_id, component_id)
	if str(document.get("uv_mapping", {}).get("last_failure_fingerprint", "")) == fingerprint:
		return false
	return not GeometryUVMappingService.result_matches(_geometry_uv_mapping_bake(asset_id, component_id), mesh, recipe)


func _all_uv_update_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for asset in assets:
		if not asset is Dictionary:
			continue
		var asset_id := str(asset.get("id", ""))
		for component in asset.get("components", []):
			if component is Dictionary and _component_uv_needs_update(asset_id, component):
				result.append({"asset_id": asset_id, "component_id": str(component.get("id", ""))})
	return result


func _update_uvs_button() -> void:
	if not is_instance_valid(update_uvs_button) or mesh_batch_running or uv_batch_running or sdf_batch_running or runtime_export_batch_running:
		return
	var status: Dictionary = _batch_status_snapshot().get("uv", {})
	var candidates: Array = status.get("candidates", [])
	var summary: Dictionary = status.get("summary", {})
	update_uvs_button.text = "Update UVs (%d)" % candidates.size()
	update_uvs_button.tooltip_text = _batch_summary_tooltip(summary, "All UVs current")
	update_uvs_button.set_attention_count(summary.get("attention", PackedStringArray()).size())
	update_uvs_button.disabled = candidates.is_empty()


func _sdf_recipe(asset_id: String, component_id: String) -> Dictionary:
	var document := _get_geometry_document(asset_id, component_id)
	return GeometrySDFService.normalize_recipe(document.get("sdf", {}).get("recipe", {})) if not document.is_empty() else GeometrySDFService.default_recipe()


func _sdf_bake(asset_id: String, component_id: String) -> Dictionary:
	var document := _get_geometry_document(asset_id, component_id)
	return document.get("sdf", {}).get("bake", {}) if not document.is_empty() else {}


func _sdf_inputs(asset_id: String, component_id: String) -> Dictionary:
	return {
		"mesh": _component_mesh_bake(asset_id, component_id),
		"uv": _geometry_uv_mapping_bake(asset_id, component_id)
	}


func _sdf_status(asset_id: String, component_id: String, component: Dictionary) -> String:
	if component.is_empty() or _component_mesh_status(asset_id, component_id, component) != "Ready":
		return "Component Mesh Required / Stale"
	var uv := _geometry_uv_mapping_bake(asset_id, component_id)
	if not _geometry_uv_mapping_bake_is_current(asset_id, component_id, component, uv):
		return "UV Bake Required / Stale"
	var inputs := _sdf_inputs(asset_id, component_id)
	var bake := _sdf_bake(asset_id, component_id)
	if bake.is_empty():
		return "Not Generated"
	if not GeometrySDFService.result_matches(bake, inputs["mesh"], inputs["uv"], _sdf_recipe(asset_id, component_id)):
		return "Stale"
	return "Baked" if _sdf_resource_available(asset_id, component_id) else "Resource Missing"


func _component_sdf_needs_update(asset_id: String, component: Dictionary) -> bool:
	var asset := _get_asset(asset_id)
	if asset.is_empty() or not bool(asset.get("visibility", true)) or not bool(component.get("visibility", true)):
		return false
	var component_id := str(component.get("id", ""))
	if component_id.is_empty() or _component_mesh_status(asset_id, component_id, component) != "Ready":
		return false
	var uv := _geometry_uv_mapping_bake(asset_id, component_id)
	if not _geometry_uv_mapping_bake_is_current(asset_id, component_id, component, uv):
		return false
	var mesh := _component_mesh_bake(asset_id, component_id)
	var recipe := _sdf_recipe(asset_id, component_id)
	var fingerprint := GeometrySDFService.failure_fingerprint(mesh, uv, recipe)
	var document := _get_geometry_document(asset_id, component_id)
	if str(document.get("sdf", {}).get("last_failure_fingerprint", "")) == fingerprint:
		return false
	return not GeometrySDFService.result_matches(_sdf_bake(asset_id, component_id), mesh, uv, recipe) \
		or not _sdf_resource_available(asset_id, component_id)


func _all_sdf_update_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for asset in assets:
		if not asset is Dictionary:
			continue
		var asset_id := str(asset.get("id", ""))
		for component in asset.get("components", []):
			if component is Dictionary and _component_sdf_needs_update(asset_id, component):
				result.append({"asset_id": asset_id, "component_id": str(component.get("id", ""))})
	return result


func _update_sdfs_button() -> void:
	if not is_instance_valid(update_sdfs_button) or mesh_batch_running or uv_batch_running or sdf_batch_running or runtime_export_batch_running:
		return
	var status: Dictionary = _batch_status_snapshot().get("sdf", {})
	var candidates: Array = status.get("candidates", [])
	var summary: Dictionary = status.get("summary", {})
	update_sdfs_button.text = "Update SDFs (%d)" % candidates.size()
	update_sdfs_button.tooltip_text = _batch_summary_tooltip(summary, "All SDFs current")
	update_sdfs_button.set_attention_count(summary.get("attention", PackedStringArray()).size())
	update_sdfs_button.disabled = candidates.is_empty()




func _batch_tooltip(pending: PackedStringArray, attention: PackedStringArray, current_message: String) -> String:
	var sections := PackedStringArray()
	if not pending.is_empty():
		sections.append("Pending (%d):\n%s" % [pending.size(), _summarize_tooltip_lines(pending)])
	if not attention.is_empty():
		sections.append("Needs attention (%d):\n%s" % [attention.size(), _summarize_tooltip_lines(attention)])
	return "\n\n".join(sections) if not sections.is_empty() else current_message


func _batch_summary_tooltip(summary: Dictionary, current_message: String) -> String:
	return _batch_tooltip(summary.get("pending", PackedStringArray()), summary.get("attention", PackedStringArray()), current_message)


func _summarize_tooltip_lines(lines: PackedStringArray, maximum := 6) -> String:
	var visible := PackedStringArray()
	for index in range(mini(lines.size(), maximum)):
		visible.append(lines[index])
	if lines.size() > maximum:
		visible.append("… and %d more" % (lines.size() - maximum))
	return "\n".join(visible)


func _candidate_tooltip_lines(candidates: Array[Dictionary]) -> PackedStringArray:
	var lines := PackedStringArray()
	for candidate in candidates:
		var asset := _get_asset(str(candidate.get("asset_id", "")))
		var component := _get_component(asset, str(candidate.get("component_id", "")))
		lines.append("%s / %s" % [str(asset.get("name", "Asset")), str(component.get("name", "Component"))])
	return lines


func _mesh_batch_summary(candidates: Array[Dictionary]) -> Dictionary:
	var attention := PackedStringArray()
	for asset in assets:
		if not asset is Dictionary or not bool(asset.get("visibility", true)):
			continue
		var asset_id := str(asset.get("id", ""))
		for component in asset.get("components", []):
			if not component is Dictionary or not bool(component.get("visibility", true)) or _is_reference_component(component):
				continue
			var issues := _component_mesh_source_validation_issues(asset, component)
			var error_message := str(_component_mesh_reference(asset_id, str(component.get("id", ""))).get("last_error", ""))
			var reason := str(issues[0]) if not issues.is_empty() else error_message
			if not reason.is_empty():
				attention.append("%s / %s — %s" % [str(asset.get("name", "Asset")), str(component.get("name", "Component")), reason])
	return {"pending": _candidate_tooltip_lines(candidates), "attention": attention}


func _mesh_update_candidates_tooltip(candidates: Array[Dictionary]) -> String:
	return _batch_summary_tooltip(_mesh_batch_summary(candidates), "All Meshes current")


func _uv_batch_summary(candidates: Array[Dictionary]) -> Dictionary:
	var attention := PackedStringArray()
	for asset in assets:
		if not asset is Dictionary or not bool(asset.get("visibility", true)):
			continue
		var asset_id := str(asset.get("id", ""))
		for component in asset.get("components", []):
			if not component is Dictionary or not bool(component.get("visibility", true)) or _is_reference_component(component):
				continue
			var component_id := str(component.get("id", ""))
			var reason := ""
			if _component_mesh_status(asset_id, component_id, component) != "Ready":
				reason = "Current Component Mesh required"
			else:
				reason = str(_get_geometry_document(asset_id, component_id).get("uv_mapping", {}).get("last_error", ""))
			if not reason.is_empty():
				attention.append("%s / %s — %s" % [str(asset.get("name", "Asset")), str(component.get("name", "Component")), reason])
	return {"pending": _candidate_tooltip_lines(candidates), "attention": attention}


func _uv_update_candidates_tooltip(candidates: Array[Dictionary]) -> String:
	return _batch_summary_tooltip(_uv_batch_summary(candidates), "All UVs current")


func _sdf_batch_summary(candidates: Array[Dictionary]) -> Dictionary:
	var attention := PackedStringArray()
	for asset in assets:
		if not asset is Dictionary or not bool(asset.get("visibility", true)):
			continue
		var asset_id := str(asset.get("id", ""))
		for component in asset.get("components", []):
			if not component is Dictionary or not bool(component.get("visibility", true)) or _is_reference_component(component):
				continue
			var component_id := str(component.get("id", ""))
			var reason := ""
			if _component_mesh_status(asset_id, component_id, component) != "Ready":
				reason = "Current Component Mesh required"
			elif not _geometry_uv_mapping_bake_is_current(asset_id, component_id, component, _geometry_uv_mapping_bake(asset_id, component_id)):
				reason = "Current UV Bake required"
			else:
				var sdf_document: Dictionary = _get_geometry_document(asset_id, component_id).get("sdf", {})
				var current_failure_fingerprint := GeometrySDFService.failure_fingerprint(_component_mesh_bake(asset_id, component_id), _geometry_uv_mapping_bake(asset_id, component_id), _sdf_recipe(asset_id, component_id))
				if str(sdf_document.get("last_failure_fingerprint", "")) == current_failure_fingerprint:
					reason = str(sdf_document.get("last_error", ""))
			if not reason.is_empty():
				attention.append("%s / %s — %s" % [str(asset.get("name", "Asset")), str(component.get("name", "Component")), reason])
	return {"pending": _candidate_tooltip_lines(candidates), "attention": attention}


func _sdf_update_candidates_tooltip(candidates: Array[Dictionary]) -> String:
	return _batch_summary_tooltip(_sdf_batch_summary(candidates), "All SDFs current")


func _scaled_automatic_recipes(base: Dictionary, factor: float) -> Dictionary:
	var result := base.duplicate(true)
	result["sampling"]["parameters"]["spacing"] = float(result["sampling"]["parameters"].get("spacing", GeometrySamplingService.DEFAULT_SPACING)) * factor
	result["seeding"]["parameters"]["spacing"] = float(result["seeding"]["parameters"].get("spacing", GeometrySeedingService.DEFAULT_SPACING)) * factor
	result["sampling"] = GeometrySamplingService.normalize_recipe(result["sampling"])
	result["seeding"] = GeometrySeedingService.normalize_recipe(result["seeding"])
	result["meshing"] = GeometryMeshingService.normalize_recipe(result["meshing"])
	return result


func _generate_component_mesh_build(asset_id: String, component_id: String) -> Dictionary:
	var asset := _get_asset(asset_id)
	var component := _get_component(asset, component_id)
	if not _component_is_meshable_source(asset, component):
		return {"valid": false, "errors": ["Component source is not meshable."]}
	if str(component.get("draw_mode", "")) == "ribbon":
		var ribbon_mesh := RibbonMeshService.generate(component)
		if bool(ribbon_mesh.get("valid", false)):
			ribbon_mesh["bake_id"] = "meshing_bake_%d" % ResourceUID.create_id()
		return {
			"valid": bool(ribbon_mesh.get("valid", false)),
			"errors": ribbon_mesh.get("errors", []).duplicate(),
			"recipes": {},
			"meshing": ribbon_mesh,
			"source_signature": _geometry_build_signature(asset_id, component_id, component),
			"attempts": 1
		}
	var cut_guides := _cut_guides_for_component(asset, component_id)
	var hole_components := _geometry_sampling_hole_components(asset, component_id)
	var has_existing_recipe := geometry_documents.has(_geometry_document_key(asset_id, component_id))
	var base_recipes := _geometry_build_recipes(asset_id, component_id, component, cut_guides, hole_components)
	var maximum_attempts := 1 if has_existing_recipe else 4
	var last_errors: Array = []
	for attempt_index in range(maximum_attempts):
		var recipes := base_recipes if attempt_index == 0 else _scaled_automatic_recipes(base_recipes, pow(1.25, attempt_index))
		var sampling := GeometrySamplingService.generate(component, recipes["sampling"], cut_guides, hole_components)
		if not bool(sampling.get("valid", false)):
			last_errors = sampling.get("errors", []).duplicate()
			continue
		sampling["bake_id"] = "bake_%d" % ResourceUID.create_id()
		sampling["semantic_source_signature"] = GeometryAutoBuildService.source_signature(component, cut_guides, hole_components, {"sampling": recipes["sampling"]})
		var seed_guides: Array = []
		if str(recipes["seeding"].get("method", "")) == GeometrySeedingService.SPINE_FLOW:
			seed_guides = _geometry_seeding_sampler_spines(asset_id, component_id, recipes["seeding"])
		var seeding := GeometrySeedingService.generate(sampling, recipes["seeding"], seed_guides)
		if not bool(seeding.get("valid", false)):
			last_errors = seeding.get("errors", []).duplicate()
			continue
		seeding["bake_id"] = "seeding_bake_%d" % ResourceUID.create_id()
		seeding["edited"] = false
		var meshing_recipe: Dictionary = recipes["meshing"].duplicate(true)
		meshing_recipe["parameters"]["seeding_method"] = str(recipes["seeding"].get("method", GeometrySeedingService.POISSON_FILL))
		meshing_recipe = GeometryMeshingService.normalize_recipe(meshing_recipe)
		recipes["meshing"] = meshing_recipe
		var meshing := GeometryMeshingService.generate(sampling, seeding, meshing_recipe)
		if not bool(meshing.get("valid", false)) or int(meshing.get("triangle_count", 0)) <= 0 \
			or int(meshing.get("degenerate_triangle_count", 0)) > 0 or not bool(meshing.get("constraints_valid", false)):
			last_errors = meshing.get("errors", ["Final Mesh validation failed."]).duplicate()
			continue
		meshing["bake_id"] = "meshing_bake_%d" % ResourceUID.create_id()
		return {
			"valid": true,
			"errors": [],
			"recipes": recipes,
			"sampling": sampling,
			"seeding": seeding,
			"meshing": meshing,
			"source_signature": GeometryAutoBuildService.source_signature(component, cut_guides, hole_components, recipes),
			"attempts": attempt_index + 1
		}
	return {"valid": false, "errors": last_errors if not last_errors.is_empty() else ["Automatic Mesh generation failed."], "recipes": base_recipes, "source_signature": GeometryAutoBuildService.source_signature(component, cut_guides, hole_components, base_recipes), "attempts": maximum_attempts}


func _commit_component_mesh_build(asset_id: String, component_id: String, build: Dictionary) -> void:
	var document := _get_geometry_document(asset_id, component_id, true)
	var mesh: Dictionary = build.get("meshing", {})
	if not build.get("recipes", {}).is_empty():
		var recipes: Dictionary = build["recipes"]
		document["sampling"]["recipe"] = recipes["sampling"].duplicate(true)
		document["seeding"]["recipe"] = recipes["seeding"].duplicate(true)
		document["meshing"]["recipe"] = recipes["meshing"].duplicate(true)
		var sampling: Dictionary = build["sampling"]
		var seeding: Dictionary = build["seeding"]
		document["sampling"]["bakes"][str(sampling.get("method", ""))] = sampling
		document["seeding"]["bakes"][str(seeding.get("method", ""))] = seeding
	document["meshing"]["bakes"][str(mesh.get("method", ""))] = mesh
	document["component_mesh"] = {
		"bake_id": str(mesh.get("bake_id", "")),
		"method": str(mesh.get("method", "")),
		"mesh_fingerprint": GeometryUVMappingService.mesh_fingerprint(mesh),
		"build_provenance": {
			"schema_version": GeometryAutoBuildService.SIGNATURE_VERSION,
			"source_signature": build.get("source_signature", {}).duplicate(true),
			"exact_input_hash": GeometryAutoBuildService.exact_signature_hash(build.get("source_signature", {})),
			"attempts": int(build.get("attempts", 1))
		},
		"last_error": "",
		"last_failure_signature": {}
	}


func _record_component_mesh_failure(asset_id: String, component_id: String, build: Dictionary) -> void:
	var document := _get_geometry_document(asset_id, component_id, true)
	var recipes = build.get("recipes", {})
	if recipes is Dictionary and not recipes.is_empty():
		document["sampling"]["recipe"] = recipes.get("sampling", document["sampling"]["recipe"]).duplicate(true)
		document["seeding"]["recipe"] = recipes.get("seeding", document["seeding"]["recipe"]).duplicate(true)
		document["meshing"]["recipe"] = recipes.get("meshing", document["meshing"]["recipe"]).duplicate(true)
	var reference: Dictionary = document.get("component_mesh", {}).duplicate(true)
	var errors: Array = build.get("errors", [])
	reference["last_error"] = str(errors[0]) if not errors.is_empty() else "Automatic Mesh generation failed."
	reference["last_failure_signature"] = build.get("source_signature", {}).duplicate(true)
	document["component_mesh"] = reference


func _on_update_meshes_pressed() -> void:
	if mesh_batch_running or uv_batch_running or sdf_batch_running or runtime_export_batch_running:
		return
	var candidates := _all_mesh_update_candidates()
	if candidates.is_empty():
		_update_meshes_button()
		return
	mesh_batch_running = true
	update_meshes_button.tooltip_text = _mesh_update_candidates_tooltip(candidates)
	update_uvs_button.disabled = true
	update_sdfs_button.disabled = true
	var succeeded := 0
	var failed := 0
	var history_recorded := false
	for index in range(candidates.size()):
		update_meshes_button.text = "Updating %d/%d" % [index + 1, candidates.size()]
		update_meshes_button.disabled = true
		await get_tree().process_frame
		var candidate: Dictionary = candidates[index]
		var asset_id := str(candidate.get("asset_id", ""))
		var component_id := str(candidate.get("component_id", ""))
		var build := _generate_component_mesh_build(asset_id, component_id)
		if not history_recorded:
			_record_direct_change()
			history_recorded = true
		if bool(build.get("valid", false)):
			var current_component := _get_component(_get_asset(asset_id), component_id)
			var current_signature := _geometry_build_signature(asset_id, component_id, current_component, build.get("recipes", {}))
			if GeometryAutoBuildService.signatures_match(current_signature, build.get("source_signature", {})):
				_commit_component_mesh_build(asset_id, component_id, build)
				succeeded += 1
			else:
				build["errors"] = ["Component changed while its Mesh was being generated."]
				_record_component_mesh_failure(asset_id, component_id, build)
				failed += 1
		else:
			_record_component_mesh_failure(asset_id, component_id, build)
			failed += 1
	mesh_batch_running = false
	_show_status_message("Updated %d Mesh%s%s" % [succeeded, "" if succeeded == 1 else "es", " · %d need attention" % failed if failed > 0 else ""])
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _generate_component_uv_build(asset_id: String, component_id: String) -> Dictionary:
	var component := _get_component(_get_asset(asset_id), component_id)
	if component.is_empty() or _component_mesh_status(asset_id, component_id, component) != "Ready":
		return {"valid": false, "errors": ["UV Mapping requires a current accepted Component Mesh."]}
	var mesh := _component_mesh_bake(asset_id, component_id)
	var recipe := _resolved_geometry_uv_mapping_recipe(asset_id, component_id)
	var result := GeometryUVMappingService.generate(mesh, recipe)
	return {
		"valid": bool(result.get("valid", false)),
		"errors": result.get("errors", []).duplicate(),
		"recipe": recipe,
		"result": result,
		"source_fingerprint": GeometryUVMappingService.source_fingerprint(mesh, recipe)
	}


func _commit_component_uv_build(asset_id: String, component_id: String, build: Dictionary) -> void:
	var document := _get_geometry_document(asset_id, component_id, true)
	var result: Dictionary = build.get("result", {}).duplicate(true)
	result["bake_id"] = "uv_bake_%d" % ResourceUID.create_id()
	var recipe := GeometryUVMappingService.normalize_recipe(build.get("recipe", {}))
	var key := GeometryUVMappingService.bake_key(str(result.get("mesh_method", "")), str(result.get("method", "")))
	document["uv_mapping"]["recipe"] = recipe
	document["uv_mapping"]["bakes"][key] = result
	document["uv_mapping"]["last_error"] = ""
	document["uv_mapping"]["last_failure_fingerprint"] = ""


func _record_component_uv_failure(asset_id: String, component_id: String, build: Dictionary) -> void:
	var document := _get_geometry_document(asset_id, component_id, true)
	var errors: Array = build.get("errors", [])
	document["uv_mapping"]["last_error"] = str(errors[0]) if not errors.is_empty() else "Automatic UV generation failed."
	document["uv_mapping"]["last_failure_fingerprint"] = str(build.get("source_fingerprint", ""))


func _on_update_uvs_pressed() -> void:
	if uv_batch_running or mesh_batch_running or sdf_batch_running or runtime_export_batch_running:
		return
	var candidates := _all_uv_update_candidates()
	if candidates.is_empty():
		_update_uvs_button()
		return
	uv_batch_running = true
	update_uvs_button.tooltip_text = _uv_update_candidates_tooltip(candidates)
	update_meshes_button.disabled = true
	update_sdfs_button.disabled = true
	var succeeded := 0
	var failed := 0
	var history_recorded := false
	for index in range(candidates.size()):
		update_uvs_button.text = "Updating %d/%d" % [index + 1, candidates.size()]
		update_uvs_button.disabled = true
		await get_tree().process_frame
		var candidate: Dictionary = candidates[index]
		var asset_id := str(candidate.get("asset_id", ""))
		var component_id := str(candidate.get("component_id", ""))
		var build := _generate_component_uv_build(asset_id, component_id)
		if not history_recorded:
			_record_direct_change()
			history_recorded = true
		if bool(build.get("valid", false)):
			var component := _get_component(_get_asset(asset_id), component_id)
			var mesh := _component_mesh_bake(asset_id, component_id)
			var recipe := _resolved_geometry_uv_mapping_recipe(asset_id, component_id, build.get("recipe", {}))
			if _component_mesh_status(asset_id, component_id, component) == "Ready" \
				and GeometryUVMappingService.source_fingerprint(mesh, recipe) == str(build.get("source_fingerprint", "")):
				_commit_component_uv_build(asset_id, component_id, build)
				succeeded += 1
			else:
				build["errors"] = ["Component Mesh changed while its UVs were being generated."]
				_record_component_uv_failure(asset_id, component_id, build)
				failed += 1
		else:
			_record_component_uv_failure(asset_id, component_id, build)
			failed += 1
	uv_batch_running = false
	_show_status_message("Updated %d UV Bake%s%s" % [succeeded, "" if succeeded == 1 else "s", " · %d need attention" % failed if failed > 0 else ""])
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _generate_component_sdf_build(asset_id: String, component_id: String) -> Dictionary:
	var component := _get_component(_get_asset(asset_id), component_id)
	var status := _sdf_status(asset_id, component_id, component)
	if status in ["Component Mesh Required / Stale", "UV Bake Required / Stale"]:
		return {"valid": false, "errors": [status]}
	var inputs := _sdf_inputs(asset_id, component_id)
	var recipe := _sdf_recipe(asset_id, component_id)
	var result := GeometrySDFService.generate(inputs["mesh"], inputs["uv"], recipe)
	return {
		"valid": bool(result.get("valid", false)),
		"errors": result.get("errors", []).duplicate(),
		"recipe": recipe,
		"result": result,
		"source_fingerprint": GeometrySDFService.source_fingerprint(inputs["mesh"], inputs["uv"], recipe),
		"failure_fingerprint": GeometrySDFService.failure_fingerprint(inputs["mesh"], inputs["uv"], recipe)
	}


func _commit_component_sdf_build(asset_id: String, component_id: String, build: Dictionary) -> bool:
	var result: Dictionary = build.get("result", {})
	var image = result.get("image", null)
	if not image is Image or image.is_empty():
		return false
	var key := _geometry_document_key(asset_id, component_id)
	sdf_images[key] = image
	var asset := _get_asset(asset_id)
	if not workspace_name.is_empty() and _save_sdf_image(asset, component_id) != OK:
		sdf_images.erase(key)
		return false
	var bake := result.duplicate(true)
	bake.erase("image")
	bake["bake_id"] = "sdf_bake_%d" % ResourceUID.create_id()
	var document := _get_geometry_document(asset_id, component_id, true)
	document["sdf"]["recipe"] = GeometrySDFService.normalize_recipe(build.get("recipe", {}))
	document["sdf"]["bake"] = bake
	document["sdf"]["last_error"] = ""
	document["sdf"]["last_failure_fingerprint"] = ""
	return true


func _record_component_sdf_failure(asset_id: String, component_id: String, build: Dictionary) -> void:
	var document := _get_geometry_document(asset_id, component_id, true)
	var errors: Array = build.get("errors", [])
	document["sdf"]["last_error"] = str(errors[0]) if not errors.is_empty() else "Automatic SDF generation failed."
	document["sdf"]["last_failure_fingerprint"] = str(build.get("failure_fingerprint", build.get("source_fingerprint", "")))


func _on_update_sdfs_pressed() -> void:
	if sdf_batch_running or mesh_batch_running or uv_batch_running or runtime_export_batch_running:
		return
	var candidates := _all_sdf_update_candidates()
	if candidates.is_empty():
		_update_sdfs_button()
		return
	sdf_batch_running = true
	update_sdfs_button.tooltip_text = _sdf_update_candidates_tooltip(candidates)
	update_meshes_button.disabled = true
	update_uvs_button.disabled = true
	var succeeded := 0
	var failed := 0
	var history_recorded := false
	for index in range(candidates.size()):
		update_sdfs_button.text = "Updating %d/%d" % [index + 1, candidates.size()]
		update_sdfs_button.disabled = true
		await get_tree().process_frame
		var candidate: Dictionary = candidates[index]
		var asset_id := str(candidate.get("asset_id", ""))
		var component_id := str(candidate.get("component_id", ""))
		var build := _generate_component_sdf_build(asset_id, component_id)
		if not history_recorded:
			_record_direct_change()
			history_recorded = true
		if bool(build.get("valid", false)):
			var inputs := _sdf_inputs(asset_id, component_id)
			var recipe := _sdf_recipe(asset_id, component_id)
			if GeometrySDFService.source_fingerprint(inputs["mesh"], inputs["uv"], recipe) == str(build.get("source_fingerprint", "")) \
				and _commit_component_sdf_build(asset_id, component_id, build):
				succeeded += 1
			else:
				build["errors"] = ["SDF inputs changed or the contour image could not be written."]
				_record_component_sdf_failure(asset_id, component_id, build)
				failed += 1
		else:
			_record_component_sdf_failure(asset_id, component_id, build)
			failed += 1
	sdf_batch_running = false
	_show_status_message("Updated %d SDF Bake%s%s" % [succeeded, "" if succeeded == 1 else "s", " · %d need attention" % failed if failed > 0 else ""])
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _runtime_export_root() -> String:
	return ProjectSettings.globalize_path("res://PolyToolsRuntimeExports")


func _runtime_export_build(asset: Dictionary) -> Dictionary:
	var sources: Dictionary = {}
	var asset_id := str(asset.get("id", ""))
	for component in asset.get("components", []):
		if not component is Dictionary or not bool(component.get("visibility", true)):
			continue
		var component_id := str(component.get("id", ""))
		if _is_reference_component(component):
			var source_asset_id := str(component.get("source_asset_id", ""))
			sources[component_id] = {
				"owner_asset_id": asset_id,
				"source_asset_exists": not _get_asset(source_asset_id).is_empty()
			}
			continue
		var mesh := _component_mesh_bake(asset_id, component_id)
		var uv := _geometry_uv_mapping_bake(asset_id, component_id)
		var sdf := _sdf_bake(asset_id, component_id)
		var mesh_current := _component_mesh_status(asset_id, component_id, component) == "Ready"
		var uv_current := mesh_current and _geometry_uv_mapping_bake_is_current(asset_id, component_id, component, uv)
		var sdf_current := uv_current and GeometrySDFService.result_matches(sdf, mesh, uv, _sdf_recipe(asset_id, component_id))
		var sdf_path := _sdf_image_path(asset, component_id)
		sources[component_id] = {
			"mesh": mesh if mesh_current else {},
			"uv": uv if uv_current else {},
			"sdf": sdf if sdf_current else {},
			"sdf_resource_valid": sdf_current and _sdf_resource_available(asset_id, component_id) and not sdf_path.is_empty() and FileAccess.file_exists(sdf_path),
			"sdf_source_path": ProjectSettings.globalize_path(sdf_path) if not sdf_path.is_empty() else ""
		}
	return RuntimeExportService.build_manifest(asset, sources)


func _runtime_export_is_stale(asset: Dictionary, build: Dictionary = {}) -> bool:
	var expected := build if not build.is_empty() else _runtime_export_build(asset)
	if not bool(expected.get("valid", false)):
		return true
	var target := _runtime_export_root().path_join(str(asset.get("id", "")))
	var manifest_path := target.path_join("manifest.json")
	var expected_manifest_text := JSON.stringify(expected.get("manifest", {}), "\t")
	if not FileAccess.file_exists(manifest_path) or not _runtime_manifest_text_matches(expected_manifest_text, FileAccess.get_file_as_string(manifest_path)):
		return true
	for mask in expected.get("masks", []):
		var mask_path := target.path_join(str(mask.get("relative_path", "")))
		if not FileAccess.file_exists(mask_path):
			return true
		var image := Image.load_from_file(mask_path)
		if image == null or image.is_empty() or GeometrySDFService.image_pixel_hash(image) != str(mask.get("pixel_hash", "")):
			return true
	return false


func _all_runtime_export_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for asset in assets:
		if not asset is Dictionary or not bool(asset.get("visibility", true)):
			continue
		var build := _runtime_export_build(asset)
		if not bool(build.get("valid", false)) or _runtime_export_is_stale(asset, build):
			result.append({"asset_id": str(asset.get("id", "")), "build": build})
	return result


func _runtime_export_batch_summary(candidates: Array[Dictionary]) -> Dictionary:
	var pending := PackedStringArray()
	var attention := PackedStringArray()
	for candidate in candidates:
		var asset := _get_asset(str(candidate.get("asset_id", "")))
		var build: Dictionary = candidate.get("build", {})
		if bool(build.get("valid", false)):
			pending.append("%s — package missing or stale" % str(asset.get("name", "Asset")))
		else:
			var errors: Array = build.get("errors", [])
			attention.append("%s — %s" % [str(asset.get("name", "Asset")), str(errors[0]) if not errors.is_empty() else "invalid"])
	return {"pending": pending, "attention": attention}


func _update_runtime_export_button() -> void:
	if not is_instance_valid(runtime_export_button) or mesh_batch_running or uv_batch_running or sdf_batch_running or runtime_export_batch_running:
		return
	var status: Dictionary = _batch_status_snapshot().get("runtime", {})
	var candidates: Array = status.get("candidates", [])
	var summary: Dictionary = status.get("summary", {})
	runtime_export_button.text = "Export Runtime (%d)" % candidates.size()
	runtime_export_button.disabled = candidates.is_empty()
	runtime_export_button.tooltip_text = _batch_summary_tooltip(summary, "All runtime packages current")
	runtime_export_button.set_attention_count(summary.get("attention", PackedStringArray()).size())


func _on_runtime_export_pressed() -> void:
	if runtime_export_batch_running or mesh_batch_running or uv_batch_running or sdf_batch_running:
		return
	var candidates := _all_runtime_export_candidates()
	if candidates.is_empty():
		_update_runtime_export_button()
		return
	runtime_export_batch_running = true
	update_meshes_button.disabled = true
	update_uvs_button.disabled = true
	update_sdfs_button.disabled = true
	var succeeded := 0
	var failed := 0
	for index in range(candidates.size()):
		runtime_export_button.text = "Exporting %d/%d" % [index + 1, candidates.size()]
		runtime_export_button.disabled = true
		await get_tree().process_frame
		var asset := _get_asset(str(candidates[index].get("asset_id", "")))
		var build := _runtime_export_build(asset)
		if bool(build.get("valid", false)) and _write_runtime_export_package(asset, build):
			succeeded += 1
		else:
			failed += 1
	runtime_export_batch_running = false
	_show_status_message("Exported %d Runtime package%s%s · %s" % [succeeded, "" if succeeded == 1 else "s", " · %d need attention" % failed if failed > 0 else "", _runtime_export_root()])
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _write_runtime_export_package(asset: Dictionary, build: Dictionary) -> bool:
	var export_root := _runtime_export_root()
	var asset_id := str(asset.get("id", ""))
	if asset_id.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(export_root)
	var target := export_root.path_join(asset_id)
	var staging := export_root.path_join(".%s.staging" % asset_id)
	var backup := export_root.path_join(".%s.backup" % asset_id)
	_remove_runtime_export_tree(staging)
	_remove_runtime_export_tree(backup)
	if DirAccess.make_dir_recursive_absolute(staging.path_join("masks")) != OK:
		return false
	var manifest_text := JSON.stringify(build.get("manifest", {}), "\t")
	var manifest_file := FileAccess.open(staging.path_join("manifest.json"), FileAccess.WRITE)
	if manifest_file == null:
		_remove_runtime_export_tree(staging)
		return false
	manifest_file.store_string(manifest_text)
	manifest_file.close()
	for mask in build.get("masks", []):
		var source_path := str(mask.get("source_path", ""))
		var destination := staging.path_join(str(mask.get("relative_path", "")))
		if not FileAccess.file_exists(source_path) or DirAccess.copy_absolute(source_path, destination) != OK:
			_remove_runtime_export_tree(staging)
			return false
	if not _runtime_manifest_text_matches(manifest_text, FileAccess.get_file_as_string(staging.path_join("manifest.json"))):
		_remove_runtime_export_tree(staging)
		return false
	for mask in build.get("masks", []):
		var staged_image := Image.load_from_file(staging.path_join(str(mask.get("relative_path", ""))))
		if staged_image == null or staged_image.is_empty() or GeometrySDFService.image_pixel_hash(staged_image) != str(mask.get("pixel_hash", "")):
			_remove_runtime_export_tree(staging)
			return false
	if DirAccess.dir_exists_absolute(target) and DirAccess.rename_absolute(target, backup) != OK:
		_remove_runtime_export_tree(staging)
		return false
	if DirAccess.rename_absolute(staging, target) != OK:
		if DirAccess.dir_exists_absolute(backup):
			DirAccess.rename_absolute(backup, target)
		_remove_runtime_export_tree(staging)
		return false
	_remove_runtime_export_tree(backup)
	return true


func _runtime_manifest_text_matches(expected_text: String, staged_text: String) -> bool:
	return not staged_text.is_empty() and JSON.parse_string(staged_text) is Dictionary and staged_text == expected_text


func _remove_runtime_export_tree(path: String) -> void:
	var export_root := _runtime_export_root().trim_suffix("/")
	if path.is_empty() or not path.begins_with(export_root + "/") or not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name in directory.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	for directory_name in directory.get_directories():
		_remove_runtime_export_tree(path.path_join(directory_name))
	DirAccess.remove_absolute(path)


func _weighting_styles(asset_id: String, component_id: String) -> Array:
	var document := _get_geometry_document(asset_id, component_id)
	return document.get("weighting", {}).get("styles", []) if not document.is_empty() else []


func _weighting_style(asset_id: String, component_id: String, style_id: String) -> Dictionary:
	for style in _weighting_styles(asset_id, component_id):
		if str(style.get("id", "")) == style_id:
			return style
	return {}


func _weighting_preview_id(asset_id: String, component_id: String, style_id: String) -> String:
	return "%s/%s" % [_geometry_document_key(asset_id, component_id), style_id]


func _weighting_status(asset_id: String, component_id: String, component: Dictionary, style: Dictionary) -> String:
	var component_mesh_status := _component_mesh_status(asset_id, component_id, component)
	if component_mesh_status == "Missing":
		return "Missing Component Mesh"
	if component_mesh_status != "Ready":
		return "Component Mesh Stale"
	if style.is_empty():
		return "Create or select a Weighting Style"
	var mesh_bake := _component_mesh_bake(asset_id, component_id)
	if weighting_preview_key == _weighting_preview_id(asset_id, component_id, str(style.get("id", ""))) and WeightingService.result_matches(weighting_preview, mesh_bake, style):
		return "Preview"
	var bake: Dictionary = style.get("bake", {})
	return "Baked" if WeightingService.result_matches(bake, mesh_bake, style) else "Not Generated" if bake.is_empty() else "Stale"


func _create_weighting_style(asset_id: String, component_id: String) -> void:
	var component := _get_component(_get_asset(asset_id), component_id)
	if component.is_empty():
		_show_status_message("Select a Component before creating a Weighting Style.")
		return
	_record_direct_change()
	var document := _get_geometry_document(asset_id, component_id, true)
	var index := int(document["weighting"].get("next_style_index", 1))
	document["weighting"]["next_style_index"] = index + 1
	var style_id := "weighting_%d" % ResourceUID.create_id()
	var style := WeightingService.default_style(style_id, "Weighting Style %02d" % index, component_id)
	document["weighting"]["styles"].append(style)
	selected_asset_id = asset_id
	selected_component_id = component_id
	selected_weighting_style_id = style_id
	active_module = "Style"
	active_style_submodule = "Weighting"
	_set_outliner_asset_expanded(asset_id, true)
	_generate_weighting_preview()


func _generate_weighting_preview() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var style := _weighting_style(selected_asset_id, selected_component_id, selected_weighting_style_id)
	var mesh_bake := _component_mesh_bake(selected_asset_id, selected_component_id) if _component_mesh_status(selected_asset_id, selected_component_id, component) == "Ready" else {}
	weighting_preview_key = _weighting_preview_id(selected_asset_id, selected_component_id, selected_weighting_style_id)
	weighting_preview = WeightingService.generate(mesh_bake, style)
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _bake_weighting_preview() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var style := _weighting_style(selected_asset_id, selected_component_id, selected_weighting_style_id)
	var mesh_bake := _component_mesh_bake(selected_asset_id, selected_component_id)
	if component.is_empty() or style.is_empty() or not WeightingService.result_matches(weighting_preview, mesh_bake, style):
		return
	_record_direct_change()
	var bake := weighting_preview.duplicate(true)
	bake["bake_id"] = "weighting_bake_%d" % ResourceUID.create_id()
	style["bake"] = bake
	weighting_preview = {}
	weighting_preview_key = ""
	_show_status_message("Weighting baked for %s." % str(style.get("name", "Weighting Style")))
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _refresh_weighting_workspace() -> void:
	if not is_instance_valid(weighting_workspace):
		return
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		weighting_workspace.clear_context()
		return
	var style := _weighting_style(selected_asset_id, selected_component_id, selected_weighting_style_id)
	var mesh_bake := _component_mesh_bake(selected_asset_id, selected_component_id)
	var result: Dictionary = {}
	if weighting_preview_key == _weighting_preview_id(selected_asset_id, selected_component_id, selected_weighting_style_id):
		result = weighting_preview
	elif not style.is_empty():
		result = style.get("bake", {})
	weighting_workspace.set_context(mesh_bake, result, _weighting_status(selected_asset_id, selected_component_id, component, style))


func _geometry_meshing_input(asset_id: String, component_id: String, recipe: Dictionary = {}) -> Dictionary:
	var resolved_recipe := recipe if not recipe.is_empty() else _geometry_meshing_recipe(asset_id, component_id)
	var seeding_method := str(resolved_recipe.get("parameters", {}).get("seeding_method", ""))
	var seeding_bake := _geometry_seeding_bake(asset_id, component_id, seeding_method)
	var sampling_bake := _geometry_sampling_bake_by_id(asset_id, component_id, str(seeding_bake.get("sampling_bake_id", "")))
	return {"sampling": sampling_bake, "seeding": seeding_bake}


func _geometry_meshing_input_is_current(asset_id: String, component_id: String, component: Dictionary, recipe: Dictionary = {}) -> bool:
	var resolved_recipe := recipe if not recipe.is_empty() else _geometry_meshing_recipe(asset_id, component_id)
	var input := _geometry_meshing_input(asset_id, component_id, resolved_recipe)
	var sampling_bake: Dictionary = input.get("sampling", {})
	var seeding_bake: Dictionary = input.get("seeding", {})
	if component.is_empty() or sampling_bake.is_empty() or seeding_bake.is_empty():
		return false
	var asset := _get_asset(asset_id)
	if not _geometry_sampling_bake_is_current(asset_id, component_id, component):
		return false
	if str(seeding_bake.get("sampling_bake_id", "")) != str(sampling_bake.get("bake_id", "")) \
		or str(seeding_bake.get("sampling_fingerprint", "")) != GeometrySeedingService.sampling_fingerprint(sampling_bake):
		return false
	if int(seeding_bake.get("algorithm_version", 0)) != GeometrySeedingService.ALGORITHM_VERSION:
		return false
	if str(seeding_bake.get("method", "")) != str(resolved_recipe.get("parameters", {}).get("seeding_method", "")):
		return false
	if str(seeding_bake.get("method", "")) == GeometrySeedingService.SPINE_FLOW:
		var seed_recipe := GeometrySeedingService.normalize_recipe({"method": GeometrySeedingService.SPINE_FLOW, "parameters": seeding_bake.get("parameters", {})})
		var guides := _geometry_seeding_sampler_spines(asset_id, component_id, seed_recipe)
		var guide_ids: Array[String] = []
		for guide in guides:
			guide_ids.append(str(guide.get("id", "")))
		if seeding_bake.get("guide_ids", []) != guide_ids or str(seeding_bake.get("guides_fingerprint", "")) != GeometrySeedingService.guides_fingerprint(guides):
			return false
	return true


func _geometry_meshing_result_matches(result: Dictionary, asset_id: String, component_id: String, component: Dictionary) -> bool:
	if result.is_empty() or not bool(result.get("valid", false)):
		return false
	if str(component.get("draw_mode", "")) == "ribbon":
		return RibbonMeshService.matches_source(result, component)
	var recipe := _geometry_meshing_recipe(asset_id, component_id)
	if not _geometry_meshing_input_is_current(asset_id, component_id, component, recipe):
		return false
	var input := _geometry_meshing_input(asset_id, component_id, recipe)
	var sampling_bake: Dictionary = input.get("sampling", {})
	var seeding_bake: Dictionary = input.get("seeding", {})
	return str(result.get("method", "")) == str(recipe.get("method", "")) \
		and int(result.get("algorithm_version", 0)) == GeometryMeshingService.ALGORITHM_VERSION \
		and result.get("parameters", {}) == recipe.get("parameters", {}) \
		and str(result.get("sampling_bake_id", "")) == str(sampling_bake.get("bake_id", "")) \
		and str(result.get("sampling_fingerprint", "")) == GeometrySeedingService.sampling_fingerprint(sampling_bake) \
		and str(result.get("seeding_bake_id", "")) == str(seeding_bake.get("bake_id", "")) \
		and str(result.get("seeding_fingerprint", "")) == GeometryMeshingService.seeding_fingerprint(seeding_bake)


func _geometry_meshing_preview_matches(asset_id: String, component_id: String, component: Dictionary) -> bool:
	return geometry_meshing_preview_key == _geometry_document_key(asset_id, component_id) \
		and _geometry_meshing_result_matches(geometry_meshing_preview, asset_id, component_id, component)


func _geometry_meshing_status(asset_id: String, component_id: String, component: Dictionary) -> String:
	if component.is_empty():
		return "Invalid"
	if str(component.get("draw_mode", "")) == "ribbon":
		if not RibbonMeshService.validation_issues(component).is_empty():
			return "Invalid"
		var ribbon_key := _geometry_document_key(asset_id, component_id)
		if geometry_meshing_preview_key == ribbon_key:
			if geometry_meshing_preview_state == "calculating":
				return "Calculating"
			if geometry_meshing_preview_state == "ready" and _geometry_meshing_preview_matches(asset_id, component_id, component):
				return "Preview Ready"
		var ribbon_bake := _geometry_meshing_bake(asset_id, component_id, RibbonMeshService.METHOD)
		return "Ready to Preview" if ribbon_bake.is_empty() else "Baked" if RibbonMeshService.matches_source(ribbon_bake, component) else "Ready to Preview"
	if not _geometry_sampling_bake_is_current(asset_id, component_id, component):
		return "Sampling Required"
	if not _geometry_meshing_input_is_current(asset_id, component_id, component):
		return "Seeding Required"
	var recipe := _geometry_meshing_recipe(asset_id, component_id)
	var input := _geometry_meshing_input(asset_id, component_id, recipe)
	if not GeometryMeshingService.validation_issues(input.get("sampling", {}), input.get("seeding", {}), recipe).is_empty():
		return "Invalid"
	var document_key := _geometry_document_key(asset_id, component_id)
	if geometry_meshing_preview_key == document_key:
		if geometry_meshing_preview_state == "calculating":
			return "Calculating"
		if geometry_meshing_preview_state == "invalid":
			return "Invalid"
		if geometry_meshing_preview_state == "ready" and _geometry_meshing_preview_matches(asset_id, component_id, component):
			return "Preview Ready"
	var bake := _geometry_meshing_bake(asset_id, component_id)
	if bake.is_empty():
		return "Ready to Preview"
	if not _geometry_meshing_result_matches(bake, asset_id, component_id, component):
		return "Ready to Preview"
	return "Baked"


func _geometry_meshing_bake_is_current(asset_id: String, component_id: String, component: Dictionary, method: String) -> bool:
	var bake := _geometry_meshing_bake(asset_id, component_id, method)
	if bake.is_empty():
		return false
	if method == RibbonMeshService.METHOD:
		return RibbonMeshService.matches_source(bake, component)
	if method != GeometryMeshingService.CONSTRAINED_MESH or int(bake.get("algorithm_version", 0)) != GeometryMeshingService.ALGORITHM_VERSION:
		return false
	var recipe := GeometryMeshingService.normalize_recipe({"method": method, "parameters": bake.get("parameters", {})})
	if not _geometry_meshing_input_is_current(asset_id, component_id, component, recipe):
		return false
	var input := _geometry_meshing_input(asset_id, component_id, recipe)
	var sampling_bake: Dictionary = input.get("sampling", {})
	var seeding_bake: Dictionary = input.get("seeding", {})
	return str(bake.get("sampling_bake_id", "")) == str(sampling_bake.get("bake_id", "")) \
		and str(bake.get("sampling_fingerprint", "")) == GeometrySeedingService.sampling_fingerprint(sampling_bake) \
		and str(bake.get("seeding_bake_id", "")) == str(seeding_bake.get("bake_id", "")) \
		and str(bake.get("seeding_fingerprint", "")) == GeometryMeshingService.seeding_fingerprint(seeding_bake)


func _geometry_uv_mapping_bakes(asset_id: String, component_id: String) -> Dictionary:
	var document := _get_geometry_document(asset_id, component_id)
	return document.get("uv_mapping", {}).get("bakes", {}) if not document.is_empty() else {}


func _geometry_uv_mapping_bake(asset_id: String, component_id: String, mesh_method := "", uv_method := "") -> Dictionary:
	var recipe := _geometry_uv_mapping_recipe(asset_id, component_id)
	var component_mesh := _component_mesh_bake(asset_id, component_id)
	var resolved_mesh_method := mesh_method if not mesh_method.is_empty() else str(component_mesh.get("method", recipe.get("parameters", {}).get("mesh_method", "")))
	var resolved_uv_method := uv_method if not uv_method.is_empty() else str(recipe.get("method", ""))
	return _geometry_uv_mapping_bakes(asset_id, component_id).get(GeometryUVMappingService.bake_key(resolved_mesh_method, resolved_uv_method), {})


func _geometry_uv_mapping_input(asset_id: String, component_id: String, recipe: Dictionary = {}) -> Dictionary:
	return _component_mesh_bake(asset_id, component_id)


func _resolved_geometry_uv_mapping_recipe(asset_id: String, component_id: String, recipe: Dictionary = {}) -> Dictionary:
	var resolved := GeometryUVMappingService.normalize_recipe(recipe if not recipe.is_empty() else _geometry_uv_mapping_recipe(asset_id, component_id))
	var component_mesh := _component_mesh_bake(asset_id, component_id)
	if not component_mesh.is_empty():
		resolved["parameters"]["mesh_method"] = str(component_mesh.get("method", ""))
	return resolved


func _geometry_uv_mapping_input_is_current(asset_id: String, component_id: String, component: Dictionary, recipe: Dictionary = {}) -> bool:
	return not component.is_empty() and _component_mesh_status(asset_id, component_id, component) == "Ready"


func _geometry_uv_mapping_result_matches(result: Dictionary, asset_id: String, component_id: String, component: Dictionary) -> bool:
	if result.is_empty() or not bool(result.get("valid", false)):
		return false
	var recipe := _resolved_geometry_uv_mapping_recipe(asset_id, component_id)
	if not _geometry_uv_mapping_input_is_current(asset_id, component_id, component, recipe):
		return false
	var mesh_bake := _geometry_uv_mapping_input(asset_id, component_id, recipe)
	return GeometryUVMappingService.result_matches(result, mesh_bake, recipe)


func _geometry_uv_mapping_preview_matches(asset_id: String, component_id: String, component: Dictionary) -> bool:
	return geometry_uv_mapping_preview_key == _geometry_document_key(asset_id, component_id) \
		and _geometry_uv_mapping_result_matches(geometry_uv_mapping_preview, asset_id, component_id, component)


func _geometry_uv_mapping_bake_is_current(asset_id: String, component_id: String, component: Dictionary, bake: Dictionary) -> bool:
	if bake.is_empty() or not _geometry_uv_mapping_input_is_current(asset_id, component_id, component):
		return false
	return GeometryUVMappingService.result_matches(
		bake,
		_geometry_uv_mapping_input(asset_id, component_id),
		_resolved_geometry_uv_mapping_recipe(asset_id, component_id)
	)


func _geometry_uv_mapping_status(asset_id: String, component_id: String, component: Dictionary) -> String:
	if component.is_empty() or not _geometry_uv_mapping_input_is_current(asset_id, component_id, component):
		return "Mesh Required / Stale"
	if geometry_uv_mapping_preview_key == _geometry_document_key(asset_id, component_id) and not bool(geometry_uv_mapping_preview.get("valid", true)):
		return "Invalid"
	if _geometry_uv_mapping_preview_matches(asset_id, component_id, component):
		return "Preview"
	var bake := _geometry_uv_mapping_bake(asset_id, component_id)
	if bake.is_empty():
		return "Not Generated"
	return "Baked" if _geometry_uv_mapping_bake_is_current(asset_id, component_id, component, bake) else "Stale"


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
	next_guide_id = 1
	next_motion_path_id = 1
	next_motion_act_id = 1
	next_motion_sequence_id = 1
	for asset in assets:
		next_asset_id = maxi(next_asset_id, _id_suffix_number(str(asset["id"])) + 1)
		for component in asset["components"]:
			next_component_id = maxi(next_component_id, _id_suffix_number(str(component["id"])) + 1)
		for guide in asset.get("guides", []):
			next_guide_id = maxi(next_guide_id, _id_suffix_number(str(guide.get("id", ""))) + 1)
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
	var draw_mode_status := find_child("DrawModeStatus", true, false) as Label
	if draw_mode_status != null:
		var selected_component := _get_component(_get_asset(selected_asset_id), selected_component_id)
		draw_mode_status.text = "Draw Mode: %s" % _draw_mode_display_name(str(selected_component.get("draw_mode", "closed_loop"))) if not selected_component.is_empty() else "Draw Mode: —"
	_update_context_action_button()
	_clear_context_bar()
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
	if active_module == "Mesh":
		if active_geometry_submodule == "Sampling":
			_render_geometry_sampling_context_bar()
		elif active_geometry_submodule == "Seeding":
			_render_geometry_seeding_context_bar()
		elif active_geometry_submodule == "Meshing":
			_render_geometry_meshing_context_bar()
		elif active_geometry_submodule == "UV Mapping":
			_render_geometry_uv_mapping_context_bar()
		else:
			var geometry_label := Label.new()
			geometry_label.text = "Mesh → %s" % active_geometry_submodule
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
	if active_module == "Style":
		_render_weighting_context_bar()
		_render_info_bar()
		return
	if not selected_guide_id.is_empty():
		var draw_guide_menu := MenuButton.new()
		draw_guide_menu.text = "⌘1  Draw Guide Point  ▼"
		draw_guide_menu.custom_minimum_size = Vector2(204, 32)
		draw_guide_menu.focus_mode = Control.FOCUS_NONE
		_style_context_command_button(draw_guide_menu, _context_command_is("guide.draw_point"))
		for point_mode_index in range(5):
			draw_guide_menu.get_popup().add_item(["1: Linear", "2: Aligned", "3: Free", "4: Mirrored", "5: Corner"][point_mode_index], point_mode_index)
		_style_popup_menu(draw_guide_menu.get_popup())
		draw_guide_menu.get_popup().id_pressed.connect(_on_guide_draw_menu_id)
		context_bar.add_child(draw_guide_menu)
		var edit_guide_menu := MenuButton.new()
		edit_guide_menu.text = "⌘2  Edit Guide Point  ▼"
		edit_guide_menu.custom_minimum_size = Vector2(194, 32)
		edit_guide_menu.focus_mode = Control.FOCUS_NONE
		_style_context_command_button(edit_guide_menu, _context_command_is("guide.edit_point"))
		edit_guide_menu.get_popup().add_item("1: Select", 0)
		edit_guide_menu.get_popup().add_item("2: Bezier Handle", 1)
		edit_guide_menu.get_popup().add_item("3: Add Point", 2)
		_style_popup_menu(edit_guide_menu.get_popup())
		edit_guide_menu.get_popup().id_pressed.connect(_on_guide_edit_menu_id)
		context_bar.add_child(edit_guide_menu)
		_render_info_bar()
		return
	if selected_component_id.is_empty():
		active_draw_tool = ""
		_render_info_bar()
		return
	var primitive_component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if _is_reference_component(primitive_component):
		var transform_reference_button := Button.new()
		transform_reference_button.text = "⌘1  Transform"
		transform_reference_button.custom_minimum_size = Vector2(132, 32)
		transform_reference_button.focus_mode = Control.FOCUS_NONE
		transform_reference_button.pressed.connect(_activate_transform_state)
		context_bar.add_child(transform_reference_button)
		_render_info_bar()
		return
	if str(primitive_component.get("draw_mode", "")) == "primitive":
		var create_primitive_button := Button.new()
		create_primitive_button.text = "⌘1  Create Primitive"
		create_primitive_button.disabled = not primitive_component.get("primitive", {}).is_empty()
		create_primitive_button.pressed.connect(func() -> void:
			_set_active_state("draw")
			_set_active_context_command("asset.create_primitive")
			canvas_view.start_circle_primitive_preview()
			_render_context_bar()
		)
		context_bar.add_child(create_primitive_button)
		var transform_primitive_button := Button.new()
		transform_primitive_button.text = "⌘2  Transform"
		transform_primitive_button.pressed.connect(_activate_transform_state)
		context_bar.add_child(transform_primitive_button)
		_render_info_bar()
		return
	var draw_menu := MenuButton.new()
	draw_menu.text = "⌘1  Draw Point  ▼"
	draw_menu.custom_minimum_size = Vector2(156, 32)
	draw_menu.focus_mode = Control.FOCUS_NONE
	_style_context_command_button(draw_menu, _context_command_is("asset.draw_point"))
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
	_style_context_command_button(edit_point_menu, _context_command_is("asset.edit_point"))
	edit_point_menu.get_popup().add_item("1: Select", 0)
	edit_point_menu.get_popup().add_item("2: Bezier Handle", 1)
	edit_point_menu.get_popup().add_item("3: Add Point", 2)
	_style_popup_menu(edit_point_menu.get_popup())
	edit_point_menu.get_popup().id_pressed.connect(_on_edit_menu_id)
	context_bar.add_child(edit_point_menu)
	var edit_edge_menu := MenuButton.new()
	edit_edge_menu.text = "⌘3  Edit Edge  ▼"
	edit_edge_menu.custom_minimum_size = Vector2(136, 32)
	edit_edge_menu.focus_mode = Control.FOCUS_NONE
	_style_context_command_button(edit_edge_menu, _context_command_is("asset.edit_edge"))
	edit_edge_menu.get_popup().add_item("Select Edge", 0)
	_style_popup_menu(edit_edge_menu.get_popup())
	edit_edge_menu.get_popup().id_pressed.connect(_on_edit_edge_menu_id)
	context_bar.add_child(edit_edge_menu)
	var selected_component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if str(selected_component.get("draw_mode", "closed_loop")) == "closed_loop":
		var edit_face_menu := MenuButton.new()
		edit_face_menu.text = "⌘4  Edit Face  ▼"
		edit_face_menu.custom_minimum_size = Vector2(134, 32)
		edit_face_menu.focus_mode = Control.FOCUS_NONE
		_style_context_command_button(edit_face_menu, _context_command_is("asset.edit_face"))
		edit_face_menu.get_popup().add_item("Move Face", 0)
		_style_popup_menu(edit_face_menu.get_popup())
		edit_face_menu.get_popup().id_pressed.connect(_on_edit_face_menu_id)
		context_bar.add_child(edit_face_menu)
		var mirror_spacer := Control.new()
		mirror_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		context_bar.add_child(mirror_spacer)
		var flip_x_button := Button.new()
		flip_x_button.text = "Flip X"
		flip_x_button.tooltip_text = "Flip the complete Closed Loop around the Component Pivot's vertical axis"
		flip_x_button.focus_mode = Control.FOCUS_NONE
		_style_context_command_button(flip_x_button, false)
		flip_x_button.pressed.connect(_flip_selected_component_geometry_x)
		context_bar.add_child(flip_x_button)
		var mirror_button := Button.new()
		mirror_button.text = "Mirror Y"
		mirror_button.tooltip_text = "Mirror a contiguous selection from the open source Chain across an interactively defined axis"
		mirror_button.focus_mode = Control.FOCUS_NONE
		mirror_button.disabled = not _can_activate_selection_mirror(selected_component)
		_style_context_command_button(mirror_button, _context_command_is("asset.mirror"))
		mirror_button.pressed.connect(_activate_selection_mirror)
		context_bar.add_child(mirror_button)
func _next_default_guide_name(asset: Dictionary, guide_type: String) -> String:
	var base := AssetGuide.display_name(guide_type)
	var index := 1
	var candidate := "%s %02d" % [base, index]
	var names: Array[String] = []
	for guide in asset.get("guides", []):
		names.append(str(guide.get("name", "")).to_lower())
	while candidate.to_lower() in names:
		index += 1
		candidate = "%s %02d" % [base, index]
	return candidate


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
	_style_context_command_button(draw_button, motion_path_tool == "draw")
	draw_button.disabled = path_document.is_empty()
	draw_button.pressed.connect(_set_motion_path_tool.bind("draw"))
	context_bar.add_child(draw_button)
	var edit_button := Button.new()
	edit_button.text = "Edit Path"
	_style_context_command_button(edit_button, motion_path_tool == "edit")
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


func _render_geometry_sampling_context_bar() -> void:
	var method_label := Label.new()
	method_label.text = "Adaptive Sampling"
	method_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	method_label.add_theme_color_override("font_color", Color("#9aa3b2"))
	context_bar.add_child(method_label)


func _on_geometry_sampling_method_menu_selected(id: int, popup: PopupMenu) -> void:
	_set_geometry_sampling_method(str(popup.get_item_metadata(popup.get_item_index(id))))


func _set_geometry_sampling_method(method: String) -> void:
	if selected_asset_id.is_empty() or selected_component_id.is_empty() or method not in GeometrySamplingService.VALID_METHODS:
		return
	_set_geometry_command_state("sampling_method")
	selected_geometry_bake_method = method
	var current := _geometry_sampling_recipe(selected_asset_id, selected_component_id)
	if str(current.get("method", "")) == method:
		_render_outliner()
		_render_inspector()
		_render_context_bar()
		_refresh_geometry_sampling_workspace()
		return
	_record_direct_change()
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	var recipe := GeometrySamplingService.normalize_recipe(document.get("sampling", {}).get("recipe", {}))
	recipe["method"] = method
	var matching_bake := _geometry_sampling_bake(selected_asset_id, selected_component_id, method)
	if not matching_bake.is_empty():
		recipe["parameters"] = matching_bake.get("parameters", {}).duplicate(true)
	document["sampling"]["recipe"] = recipe
	_clear_geometry_sampling_preview_for_selection()
	_render_outliner()
	_render_inspector()
	_render_context_bar()
	_refresh_geometry_sampling_workspace()
	if matching_bake.is_empty():
		call_deferred("_refresh_geometry_after_recipe_change")


func _activate_geometry_sampling_method_choice() -> void:
	_show_status_message("Sampling uses one adaptive method.")


func _render_geometry_seeding_context_bar() -> void:
	geometry_seeding_method_menu = MenuButton.new()
	geometry_seeding_method_menu.text = "⌘1  Method"
	geometry_seeding_method_menu.custom_minimum_size = Vector2(118, 32)
	geometry_seeding_method_menu.focus_mode = Control.FOCUS_NONE
	_style_context_command_button(geometry_seeding_method_menu, _context_command_is("geometry.seeding.method"))
	var popup := geometry_seeding_method_menu.get_popup()
	_style_popup_menu(popup)
	popup.add_item("1  Poisson Fill", 0)
	popup.set_item_metadata(0, GeometrySeedingService.POISSON_FILL)
	popup.add_item("2  Spine Flow", 1)
	popup.set_item_metadata(1, GeometrySeedingService.SPINE_FLOW)
	_connect_context_method_menu(popup, "geometry.seeding.method", _set_geometry_seeding_method)
	context_bar.add_child(geometry_seeding_method_menu)
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var status := _geometry_seeding_status(selected_asset_id, selected_component_id, component)
	var edit_button := Button.new()
	edit_button.text = "⌘2  Edit Seeds"
	_style_context_command_button(edit_button, _context_command_is("geometry.seeding.edit_seeds"))
	edit_button.disabled = status not in ["Preview Ready", "Baked", "Edited"]
	edit_button.tooltip_text = "Bake the current Preview and edit it" if status == "Preview Ready" else "Edit the current Seeding Bake"
	edit_button.focus_mode = Control.FOCUS_NONE
	edit_button.pressed.connect(_toggle_geometry_seeding_edit)
	context_bar.add_child(edit_button)
func _set_geometry_seeding_method(method: String) -> void:
	if selected_asset_id.is_empty() or selected_component_id.is_empty() or method not in GeometrySeedingService.VALID_METHODS:
		return
	_set_geometry_command_state("seeding_method")
	selected_geometry_bake_method = method
	var current := _geometry_seeding_recipe(selected_asset_id, selected_component_id)
	if str(current.get("method", "")) == method:
		_render_outliner()
		_render_inspector()
		_render_context_bar()
		_refresh_geometry_seeding_workspace()
		if _geometry_seeding_status(selected_asset_id, selected_component_id, _get_component(_get_asset(selected_asset_id), selected_component_id)) == "Ready to Preview":
			_schedule_geometry_seeding_preview()
		return
	_record_direct_change()
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	var next_recipe := GeometrySeedingService.normalize_recipe({"method": method, "parameters": current.get("parameters", {})})
	var matching_bake := _geometry_seeding_bake(selected_asset_id, selected_component_id, method)
	if not matching_bake.is_empty():
		next_recipe["parameters"] = matching_bake.get("parameters", {}).duplicate(true)
	if method == GeometrySeedingService.SPINE_FLOW and next_recipe.get("parameters", {}).get("spine_inputs", []).is_empty():
		var guides := _sampler_spines_for_component(_get_asset(selected_asset_id), selected_component_id)
		for guide in guides:
			next_recipe["parameters"]["spine_inputs"].append({"guide_id": str(guide.get("id", "")), "enabled": true})
	document["seeding"]["recipe"] = next_recipe
	geometry_seeding_preview = {}
	geometry_seeding_preview_key = ""
	geometry_seeding_preview_state = "idle"
	geometry_seeding_preview_revision += 1
	_render_outliner()
	_render_inspector()
	_render_context_bar()
	_refresh_geometry_seeding_workspace()
	if matching_bake.is_empty() or not _geometry_seeding_result_matches(matching_bake, selected_asset_id, selected_component_id, _get_component(_get_asset(selected_asset_id), selected_component_id)):
		call_deferred("_schedule_geometry_seeding_preview")


func _activate_geometry_seeding_method_choice() -> void:
	if selected_asset_id.is_empty() or selected_component_id.is_empty():
		return
	_set_geometry_command_state("seeding_method")
	_render_context_bar()
	_render_info_bar()
	_show_status_message("Seeding Method: 1 Poisson Fill · 2 Spine Flow")


func _toggle_geometry_seeding_edit() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var status := _geometry_seeding_status(selected_asset_id, selected_component_id, component)
	if geometry_seeding_edit_active:
		_set_geometry_command_state("")
	elif status == "Preview Ready":
		_set_geometry_command_state("")
		_bake_geometry_seeding_preview(true)
		return
	elif status in ["Baked", "Edited"]:
		_set_geometry_command_state("seeding_edit")
	else:
		_set_geometry_command_state("")
		_show_status_message("Generate a valid Seeding Preview before editing Seeds.")
	_render_context_bar()
	_refresh_geometry_seeding_workspace()
	if geometry_seeding_edit_active and is_instance_valid(geometry_seeding_workspace) and geometry_seeding_workspace.is_inside_tree():
		geometry_seeding_workspace.grab_focus()


func _set_geometry_seeding_edit_tool(tool: String) -> void:
	if tool not in ["select", "add", "remove"]:
		return
	geometry_seeding_edit_tool = tool
	_render_context_bar()
	_refresh_geometry_seeding_workspace()


func _render_geometry_meshing_context_bar() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if str(component.get("draw_mode", "")) == "ribbon":
		var ribbon_label := Label.new()
		ribbon_label.text = "Ribbon Strip · Automatic"
		ribbon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ribbon_label.add_theme_color_override("font_color", Color("#9aa3b2"))
		context_bar.add_child(ribbon_label)
		return
	var method_label := Label.new()
	method_label.text = "Constrained Mesh · Automatic"
	method_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	method_label.add_theme_color_override("font_color", Color("#9aa3b2"))
	context_bar.add_child(method_label)


func _set_geometry_meshing_method(_method: String = GeometryMeshingService.CONSTRAINED_MESH) -> void:
	if selected_asset_id.is_empty() or selected_component_id.is_empty():
		return
	_set_geometry_command_state("")
	selected_geometry_bake_method = GeometryMeshingService.CONSTRAINED_MESH
	var current := _geometry_meshing_recipe(selected_asset_id, selected_component_id)
	if str(current.get("method", "")) == GeometryMeshingService.CONSTRAINED_MESH:
		_render_outliner()
		_render_inspector()
		_render_context_bar()
		_refresh_geometry_meshing_workspace()
		if _geometry_meshing_status(selected_asset_id, selected_component_id, _get_component(_get_asset(selected_asset_id), selected_component_id)) == "Ready to Preview":
			_schedule_geometry_meshing_preview()
		return
	_record_direct_change()
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	var next_recipe := GeometryMeshingService.normalize_recipe({"method": GeometryMeshingService.CONSTRAINED_MESH, "parameters": current.get("parameters", {})})
	var matching_bake := _geometry_meshing_bake(selected_asset_id, selected_component_id, GeometryMeshingService.CONSTRAINED_MESH)
	if not matching_bake.is_empty():
		next_recipe["parameters"] = matching_bake.get("parameters", {}).duplicate(true)
	document["meshing"]["recipe"] = next_recipe
	geometry_meshing_preview = {}
	geometry_meshing_preview_key = ""
	geometry_meshing_preview_state = "idle"
	geometry_meshing_preview_revision += 1
	_render_outliner()
	_render_inspector()
	_render_context_bar()
	_refresh_geometry_meshing_workspace()
	if matching_bake.is_empty() or not _geometry_meshing_result_matches(matching_bake, selected_asset_id, selected_component_id, _get_component(_get_asset(selected_asset_id), selected_component_id)):
		call_deferred("_schedule_geometry_meshing_preview")


func _activate_geometry_meshing_method_choice() -> void:
	_set_geometry_meshing_method(GeometryMeshingService.CONSTRAINED_MESH)


func _render_geometry_uv_mapping_context_bar() -> void:
	geometry_uv_mapping_method_menu = MenuButton.new()
	geometry_uv_mapping_method_menu.text = "⌘1  Method"
	geometry_uv_mapping_method_menu.custom_minimum_size = Vector2(118, 32)
	geometry_uv_mapping_method_menu.focus_mode = Control.FOCUS_NONE
	_style_context_command_button(geometry_uv_mapping_method_menu, _context_command_is("geometry.uv_mapping.method"))
	var popup := geometry_uv_mapping_method_menu.get_popup()
	_style_popup_menu(popup)
	popup.add_item("1  Bounds / Planar", 0)
	popup.set_item_metadata(0, GeometryUVMappingService.BOUNDS_PLANAR)
	_connect_context_method_menu(popup, "geometry.uv_mapping.method", _set_geometry_uv_mapping_method)
	context_bar.add_child(geometry_uv_mapping_method_menu)
	var method_label := Label.new()
	method_label.text = "Bounds / Planar"
	method_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	method_label.add_theme_color_override("font_color", Color("#9aa3b2"))
	context_bar.add_child(method_label)


func _set_geometry_uv_mapping_method(method: String) -> void:
	if selected_asset_id.is_empty() or selected_component_id.is_empty() or method not in GeometryUVMappingService.VALID_METHODS:
		return
	_set_geometry_command_state("uv_mapping_method")
	var recipe := _resolved_geometry_uv_mapping_recipe(selected_asset_id, selected_component_id)
	var mesh_method := str(recipe.get("parameters", {}).get("mesh_method", ""))
	var matching_bake := _geometry_uv_mapping_bake(selected_asset_id, selected_component_id, mesh_method, method)
	selected_geometry_bake_method = GeometryUVMappingService.bake_key(mesh_method, method) if not matching_bake.is_empty() else ""
	if not matching_bake.is_empty():
		var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
		document["uv_mapping"]["recipe"] = GeometryUVMappingService.normalize_recipe({"method": method, "parameters": matching_bake.get("parameters", {})})
	_render_outliner()
	_render_inspector()
	_render_context_bar()
	_refresh_geometry_uv_mapping_workspace()
	if matching_bake.is_empty():
		call_deferred("_generate_geometry_uv_mapping_preview")


func _activate_geometry_uv_mapping_method_choice() -> void:
	if selected_asset_id.is_empty() or selected_component_id.is_empty():
		return
	_set_geometry_command_state("uv_mapping_method")
	_render_context_bar()
	_render_info_bar()
	_show_status_message("UV Mapping Method: 1 Bounds / Planar")


func _render_motion_sequence_context_bar() -> void:
	var composition_button := Button.new()
	composition_button.text = "⌘1  Composition"
	_style_context_command_button(composition_button, motion_sequence_view == MotionSequenceWorkspace.VIEW_COMPOSITION)
	composition_button.pressed.connect(_set_motion_sequence_view.bind(MotionSequenceWorkspace.VIEW_COMPOSITION))
	context_bar.add_child(composition_button)
	var player_button := Button.new()
	player_button.text = "⌘2  Player"
	_style_context_command_button(player_button, motion_sequence_view == MotionSequenceWorkspace.VIEW_PLAYER)
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


func _render_weighting_context_bar() -> void:
	weighting_method_menu = MenuButton.new()
	weighting_method_menu.text = "⌘1  Method  ▼"
	weighting_method_menu.custom_minimum_size = Vector2(132, 32)
	weighting_method_menu.focus_mode = Control.FOCUS_NONE
	_style_context_command_button(weighting_method_menu, _context_command_is("style.weighting.method"))
	var popup := weighting_method_menu.get_popup()
	popup.add_item("1  Uniform", 0)
	popup.set_item_metadata(0, WeightingService.UNIFORM)
	popup.add_item("2  Axis Gradient", 1)
	popup.set_item_metadata(1, WeightingService.AXIS_GRADIENT)
	_style_popup_menu(popup)
	_connect_context_method_menu(popup, "style.weighting.method", _set_weighting_method)
	context_bar.add_child(weighting_method_menu)


func _set_weighting_method(method_value: Variant) -> void:
	var method := str(method_value)
	if method not in WeightingService.VALID_METHODS:
		return
	var style := _weighting_style(selected_asset_id, selected_component_id, selected_weighting_style_id)
	if style.is_empty():
		return
	_set_active_context_command("style.weighting.method")
	if method == str(style.get("method", "")):
		return
	_record_direct_change()
	style["method"] = method
	style["parameters"] = WeightingService.default_parameters(method)
	_generate_weighting_preview()


func _origin_mode_label(mode: String) -> String:
	return {
		"bottom_left": "Bottom Left",
		"top_left": "Top Left",
		"center": "Center"
	}.get(mode, "Bottom Left")


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


func _on_draw_menu_id(id: int) -> void:
	if id < 0 or id > 4:
		return
	_activate_draw_state()
	_set_draw_point_mode(_draw_point_mode_from_menu_id(id))


func _on_guide_draw_menu_id(id: int) -> void:
	if id < 0 or id > 4:
		return
	_activate_guide_draw_state()
	_set_draw_point_mode(_draw_point_mode_from_menu_id(id))


func _on_edit_menu_id(id: int) -> void:
	if id == 0:
		_activate_edit_point_state(false, false)
	elif id == 1:
		_activate_edit_point_state(true, false)
	elif id == 2:
		_activate_edit_point_state(false, true)


func _on_guide_edit_menu_id(id: int) -> void:
	if id == 0:
		_activate_guide_edit_state(false, false)
	elif id == 1:
		_activate_guide_edit_state(true, false)
	elif id == 2:
		_activate_guide_edit_state(false, true)


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
	_set_active_context_command("asset.draw_point")
	_set_active_state("draw")
	canvas_view.set_draw_point_mode(active_draw_point_mode)


func _pause_draw_point() -> bool:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		return false
	var chains: Array = component.get("chains", [])
	if chains.is_empty() or bool(chains[0].get("closed", false)) or chains[0].get("point_ids", []).is_empty():
		_show_status_message("Draw Point · No open contour to pause")
		return false
	_activate_edit_point_state(false, false)
	_show_status_message("Drawing paused · Select an endpoint to continue")
	return true


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
		selected_edge_ids.clear()
	if mode != "point":
		selected_point_id = ""
		selected_point_ids.clear()
		edit_bezier_handles = false
		edit_point_set_mode = false
	canvas_view.set_face_selected(false)
	canvas_view.set_edit_mode(active_edit_mode)
	canvas_view.set_edit_handles_enabled(edit_bezier_handles)
	canvas_view.set_edit_point_set_enabled(edit_point_set_mode)
	canvas_view.set_selected_edge_ids(selected_edge_ids)
	_render_context_bar()
	_render_info_bar()


func _activate_edit_state() -> void:
	_activate_edit_point_state()


func _activate_guide_draw_state() -> void:
	var asset := _get_asset(selected_asset_id)
	var guide := _get_guide(asset, selected_guide_id)
	var component := _get_component(asset, str(guide.get("scope", {}).get("component_id", "")))
	if guide.is_empty() or component.is_empty():
		_show_status_message("Select a Guide with a valid parent Component.")
		return
	var is_cut_guide := str(guide.get("guide_type", "")) == AssetGuide.CUT
	if not is_cut_guide and _component_guide_boundaries(component).get("outer", PackedVector2Array()).size() < 3:
		_show_status_message("Draw Guide Point requires a closed parent Component contour.")
		return
	active_state = "draw"
	_set_active_context_command("guide.draw_point")
	active_draw_tool = "spine"
	edit_bezier_handles = false
	edit_point_set_mode = false
	canvas_view.set_interaction_state("draw")
	canvas_view.set_tool_mode("spine")
	canvas_view.set_draw_point_mode(active_draw_point_mode)
	_render_context_bar()
	_render_info_bar()
	_render_canvas_context()
	_show_status_message("Draw Guide Point · Escape to stop")


func _activate_guide_edit_state(handle_editing := false, set_mode := false) -> void:
	var guide := _get_guide(_get_asset(selected_asset_id), selected_guide_id)
	if guide.is_empty():
		return
	active_state = "edit"
	_set_active_context_command("guide.edit_point")
	active_draw_tool = ""
	active_edit_mode = "point"
	edit_bezier_handles = handle_editing
	edit_point_set_mode = set_mode
	canvas_view.set_interaction_state("edit")
	canvas_view.set_tool_mode("")
	canvas_view.set_edit_mode("point")
	canvas_view.set_edit_handles_enabled(edit_bezier_handles)
	canvas_view.set_edit_point_set_enabled(edit_point_set_mode)
	_render_context_bar()
	_render_info_bar()
	_render_canvas_context()


func _activate_edit_point_state(handle_editing := false, set_mode := false) -> void:
	_set_active_context_command("asset.edit_point")
	edit_bezier_handles = handle_editing
	edit_point_set_mode = set_mode
	_set_active_state("edit")
	_set_edit_mode("point")
	canvas_view.set_edit_handles_enabled(edit_bezier_handles)
	canvas_view.set_edit_point_set_enabled(edit_point_set_mode)


func _activate_edit_edge_state() -> void:
	_set_active_context_command("asset.edit_edge")
	_set_active_state("edit")
	_set_edit_mode("edge")


func _activate_edit_face_state() -> void:
	_set_active_context_command("asset.edit_face")
	_set_active_state("edit")
	_set_edit_mode("face")


func _can_activate_selection_mirror(component: Dictionary) -> bool:
	if component.is_empty() or str(component.get("draw_mode", "closed_loop")) != "closed_loop":
		return false
	return SELECTION_MIRROR_SERVICE_SCRIPT.validation_issues(component, selected_point_ids, Vector2.ZERO, Vector2.RIGHT).is_empty()


func _flip_selected_component_geometry_x() -> void:
	_flip_component_geometry_x(selected_asset_id, selected_component_id)


func _flip_component_geometry_x(asset_id: String, component_id: String) -> void:
	var asset := _get_asset(asset_id)
	var component := _get_component(asset, component_id)
	if asset.is_empty() or component.is_empty() or str(component.get("draw_mode", "")) != "closed_loop":
		return
	var points: Array = component.get("points", [])
	if points.is_empty():
		return
	var transform: Dictionary = component.get("transform", {})
	var pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
	_record_direct_change()
	for point_data in points:
		if not point_data is Dictionary:
			continue
		var position: Vector2 = point_data.get("position", Vector2.ZERO)
		position.x = 2.0 * pivot.x - position.x
		point_data["position"] = position
		var handle_in: Vector2 = point_data.get("handle_in", Vector2.ZERO)
		handle_in.x = -handle_in.x
		point_data["handle_in"] = handle_in
		var handle_out: Vector2 = point_data.get("handle_out", Vector2.ZERO)
		handle_out.x = -handle_out.x
		point_data["handle_out"] = handle_out
	BezierGeometry.resolve_auto_handles(points, component.get("chains", []))
	if asset_id == selected_asset_id and component_id == selected_component_id:
		_refresh_component_geometry(component)
		_render_inspector()
		_render_canvas_context()
	_show_status_message("Flipped Closed Loop across the Pivot's vertical axis.")


func _activate_selection_mirror() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not _can_activate_selection_mirror(component):
		return
	_set_active_context_command("asset.mirror")
	if not canvas_view.start_mirror_command():
		_set_active_context_command("asset.edit_point")
		return
	_render_context_bar()
	_show_mirror_prompt("Mirror Y · Set the first axis Point on the snapped grid")


func _on_mirror_axis_stage_changed(stage: String) -> void:
	if stage == "second":
		_show_mirror_prompt("Mirror Y · Move the second axis Point · Click or Enter to confirm · Escape to cancel")


func _on_mirror_axis_confirmed(axis_start: Vector2, axis_end: Vector2) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		_on_mirror_axis_cancelled()
		return
	var result: Dictionary = SELECTION_MIRROR_SERVICE_SCRIPT.apply(component, selected_point_ids, axis_start, axis_end)
	if not bool(result.get("valid", false)):
		var errors: Array = result.get("errors", [])
		_show_status_message(str(errors[0]) if not errors.is_empty() else "Mirror Y could not be applied.")
		_set_active_context_command("asset.edit_point")
		_render_context_bar()
		return
	_record_direct_change()
	var resolved: Dictionary = result.get("component", {})
	component.clear()
	component.merge(resolved, true)
	selected_point_ids.clear()
	for point_id_value in result.get("mirrored_point_ids", []):
		selected_point_ids.append(str(point_id_value))
	selected_point_id = selected_point_ids[0] if selected_point_ids.size() == 1 else ""
	_activate_edit_point_state(false, false)
	_refresh_component_geometry(component)
	canvas_view.set_selected_point_ids(selected_point_ids)
	_render_outliner()
	_render_inspector()
	_render_context_bar()
	var auto_connected_count := int(result.get("auto_connected_count", 0))
	if auto_connected_count > 0:
		_show_status_message("Mirror Y applied · Overlapping endpoints connected")
	else:
		_show_status_message("Mirror Y applied · The two open Chains remain unconnected")


func _on_mirror_axis_cancelled() -> void:
	_set_active_context_command("asset.edit_point")
	_render_context_bar()
	_show_status_message("Mirror Y cancelled")


func _show_mirror_prompt(message: String) -> void:
	_show_status_message(message)
	if is_instance_valid(status_clear_timer):
		status_clear_timer.stop()


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
			_add_info_mode_group([
				{"label": "⌘1: Composition", "id": MotionSequenceWorkspace.VIEW_COMPOSITION},
				{"label": "⌘2: Player", "id": MotionSequenceWorkspace.VIEW_PLAYER}
			], motion_sequence_view)
			if motion_sequence_view == MotionSequenceWorkspace.VIEW_PLAYER:
				_add_info_option("Phase %.2f" % motion_sequence_phase)
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
	if active_module == "Mesh":
		var geometry_state_label := Label.new()
		if active_geometry_submodule == "Sampling" and geometry_sampling_method_choice_active:
			geometry_state_label.text = "State: Adaptive Sampling"
			info_bar.add_child(geometry_state_label)
			_add_info_mode_group([
				{"label": "Adaptive", "id": GeometrySamplingService.ADAPTIVE}
			], str(_geometry_sampling_recipe(selected_asset_id, selected_component_id).get("method", GeometrySamplingService.ADAPTIVE)))
		elif active_geometry_submodule == "Seeding" and geometry_seeding_method_choice_active:
			geometry_state_label.text = "State: Seeding Method"
			info_bar.add_child(geometry_state_label)
			_add_info_mode_group([
				{"label": "1: Poisson Fill", "id": GeometrySeedingService.POISSON_FILL},
				{"label": "2: Spine Flow", "id": GeometrySeedingService.SPINE_FLOW}
			], str(_geometry_seeding_recipe(selected_asset_id, selected_component_id).get("method", GeometrySeedingService.POISSON_FILL)))
		elif active_geometry_submodule == "Seeding" and geometry_seeding_edit_active:
			geometry_state_label.text = "State: Edit Seeds"
			info_bar.add_child(geometry_state_label)
			_add_info_mode_group([
				{"label": "1: Select / Move", "id": "select"},
				{"label": "2: Add", "id": "add"},
				{"label": "3: Remove", "id": "remove"}
			], geometry_seeding_edit_tool)
			_add_info_option("Delete: Remove selected")
		elif active_geometry_submodule == "UV Mapping" and geometry_uv_mapping_method_choice_active:
			geometry_state_label.text = "State: UV Mapping Method"
			info_bar.add_child(geometry_state_label)
			_add_info_mode_group([
				{"label": "1: Bounds / Planar", "id": GeometryUVMappingService.BOUNDS_PLANAR}
			], GeometryUVMappingService.BOUNDS_PLANAR)
		else:
			geometry_state_label.text = "State: Default"
			info_bar.add_child(geometry_state_label)
			_add_info_option("Mesh: %s" % active_geometry_submodule)
			_add_info_mode_group([
				{"label": "⌘1: Method", "id": "geometry.%s.method" % active_geometry_submodule.to_lower().replace(" ", "_")}
			], active_context_command)
			if active_geometry_submodule == "Seeding":
				_add_info_mode_group([
					{"label": "⌘2: Edit Seeds", "id": "geometry.seeding.edit_seeds"}
				], active_context_command)
		return
	if active_module == "Style":
		var style_state_label := Label.new()
		style_state_label.text = "State: Default"
		info_bar.add_child(style_state_label)
		if active_style_submodule == "Weighting":
			_add_info_option("Weighting")
			_add_info_mode_group([
				{"label": "⌘1: Method", "id": "style.weighting.method"}
			], active_context_command)
			var style := _weighting_style(selected_asset_id, selected_component_id, selected_weighting_style_id)
			if not style.is_empty():
				_add_info_option(str(style.get("name", "Weighting Style")))
		return
	if not selected_guide_id.is_empty():
		var selected_guide := _get_guide(_get_asset(selected_asset_id), selected_guide_id)
		var guide_state_label := Label.new()
		guide_state_label.text = "State: Draw Guide Point" if active_state == "draw" else "State: Edit Guide Point" if active_state == "edit" else "State: Default"
		info_bar.add_child(guide_state_label)
		_add_info_option("Guide: %s" % AssetGuide.display_name(str(selected_guide.get("guide_type", AssetGuide.SAMPLER_SPINE))))
		if active_state == "draw":
			_add_info_mode_group([
				{"label": "1: Linear", "id": "linear"},
				{"label": "2: Aligned", "id": "aligned"},
				{"label": "3: Free", "id": "free"},
				{"label": "4: Mirrored", "id": "mirrored"},
				{"label": "5: Corner", "id": "corner"}
			], active_draw_point_mode)
			_add_info_option("Click: Add Point · Esc: Stop")
		elif active_state == "edit":
			_add_info_mode_group([
				{"label": "1: Select", "id": "select"},
				{"label": "2: Bezier Handle", "id": "handles"},
				{"label": "3: Add Point", "id": "add_point"}
			], "add_point" if edit_point_set_mode else "handles" if edit_bezier_handles else "select")
			_add_info_option("Click: Select · Drag: Move · Delete: Remove")
		else:
			_add_info_mode_group([
				{"label": "⌘1: Draw Guide Point", "id": "guide.draw_point"},
				{"label": "⌘2: Edit Guide Point", "id": "guide.edit_point"}
			], active_context_command)
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
		_add_info_mode_group([
			{"label": "1: Linear", "id": "linear"},
			{"label": "2: Aligned", "id": "aligned"},
			{"label": "3: Free", "id": "free"},
			{"label": "4: Mirrored", "id": "mirrored"},
			{"label": "5: Corner", "id": "corner"}
		], active_draw_point_mode)
		_add_info_option("Enter: Pause open Chain · Esc: Leave")
	elif active_state == "edit" and active_edit_mode == "point":
		var active_edit_point_submode := "set" if edit_point_set_mode else "bezier_handle" if edit_bezier_handles else "select"
		_add_info_mode_group([
			{"label": "1: Select", "id": "select"},
			{"label": "2: Bezier Handle", "id": "bezier_handle"},
			{"label": "3: Set", "id": "set"}
		], active_edit_point_submode)
	elif active_state == "edit" and active_edit_mode == "edge":
		_add_info_option("Click: Select Edge")
	elif active_state == "edit" and active_edit_mode == "face":
		_add_info_option("Drag: Move Face")
	else:
		_add_info_mode_group([
			{"label": "⌘1: Draw Point", "id": "asset.draw_point"},
			{"label": "⌘2: Edit Point", "id": "asset.edit_point"},
			{"label": "⌘3: Edit Edge", "id": "asset.edit_edge"},
			{"label": "⌘4: Edit Face", "id": "asset.edit_face"}
		], active_context_command)


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


func _add_info_option(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#aab3c2"))
	info_bar.add_child(label)


func _add_info_mode_group(modes: Array, active_id: String) -> void:
	for mode in modes:
		if mode is Dictionary:
			_add_info_mode_option(str(mode.get("label", "")), str(mode.get("id", "")) == active_id)


func _add_info_mode_option(text: String, active: bool) -> void:
	var option := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#783943") if active else Color("#20242c")
	style.border_color = Color("#c45b68") if active else Color("#363d48")
	style.set_border_width_all(1)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	option.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#fff1f2") if active else Color("#aab3c2"))
	option.add_child(label)
	info_bar.add_child(option)


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
	assets.append({"id": asset_id, "name": asset_name, "asset_type": _create_submodule_asset_type(active_create_submodule), "visibility": true, "asset_pivot": Vector2.ZERO, "reference_image": _default_reference_image(), "animation": MotionWorkspace.create_default_animation_document(), "components": [], "guides": []})
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_guide_id = ""
	active_state = ""
	_set_outliner_asset_expanded(asset_id, true)
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
		return ProjectSettings.globalize_path("res://imports")
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
	_apply_reference_image_orientation(source_image, source_path)
	reference_image_crop_dialog.open_for_image(source_image)


func _save_reference_image_result(reference_image_result: Image) -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty() or workspace_name.is_empty() or reference_image_result == null or reference_image_result.is_empty():
		return
	var reference_filename := _reference_image_filename(asset)
	var asset_root := _asset_storage_root("%s/%s" % [WORKSPACES_ROOT, workspace_name], asset)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(asset_root))
	var destination_path := "%s/%s" % [asset_root, reference_filename]
	if reference_image_result.save_png(ProjectSettings.globalize_path(destination_path)) != OK:
		_show_status_message("Reference Image could not be copied.")
		return
	var reference_image := _normalize_reference_image(asset.get("reference_image", {}))
	reference_image["file"] = reference_filename
	# A newly imported reference must always be visible, even if the image it
	# replaces had been hidden in the Inspector.
	reference_image["visible"] = true
	# Every newly loaded reference starts from a neutral transform. The
	# selected target height and pivot remain unchanged.
	reference_image["position"] = Vector2.ZERO
	reference_image["scale"] = 1.0
	_record_direct_change()
	asset["reference_image"] = reference_image
	_render_inspector()
	_render_canvas_context()


func _apply_reference_image_orientation(image: Image, source_path: String) -> void:
	if image == null or image.is_empty() or source_path.get_extension().to_lower() not in ["jpg", "jpeg"]:
		return
	var orientation := _jpeg_exif_orientation(source_path)
	if orientation == 3:
		image.rotate_90(0)
		image.rotate_90(0)
	elif orientation == 6:
		image.rotate_90(0)
	elif orientation == 8:
		image.rotate_90(1)
	elif orientation == 2:
		image.flip_x()
	elif orientation == 4:
		image.flip_y()
	elif orientation == 5:
		image.flip_x()
		image.rotate_90(0)
	elif orientation == 7:
		image.flip_x()
		image.rotate_90(1)


func _jpeg_exif_orientation(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 1
	var data := file.get_buffer(file.get_length())
	if data.size() < 12 or data[0] != 0xff or data[1] != 0xd8:
		return 1
	var offset := 2
	while offset + 4 <= data.size():
		if data[offset] != 0xff:
			offset += 1
			continue
		while offset < data.size() and data[offset] == 0xff:
			offset += 1
		if offset >= data.size():
			break
		var marker := int(data[offset])
		offset += 1
		if marker in [0xd8, 0xd9] or marker >= 0xd0 and marker <= 0xd7:
			continue
		if offset + 2 > data.size():
			break
		var segment_length := _read_u16_big_endian(data, offset)
		if segment_length < 2 or offset + segment_length > data.size():
			break
		if marker == 0xe1 and segment_length >= 16 \
			and data[offset + 2] == 0x45 and data[offset + 3] == 0x78 and data[offset + 4] == 0x69 and data[offset + 5] == 0x66 \
			and data[offset + 6] == 0x00 and data[offset + 7] == 0x00:
			var tiff_offset := offset + 8
			var little_endian := data[tiff_offset] == 0x49 and data[tiff_offset + 1] == 0x49
			var big_endian := data[tiff_offset] == 0x4d and data[tiff_offset + 1] == 0x4d
			if not little_endian and not big_endian:
				return 1
			var ifd_offset := tiff_offset + _read_u32(data, tiff_offset + 4, little_endian)
			if ifd_offset + 2 > data.size():
				return 1
			var entry_count := _read_u16(data, ifd_offset, little_endian)
			for entry_index in range(entry_count):
				var entry_offset := ifd_offset + 2 + entry_index * 12
				if entry_offset + 12 > data.size():
					return 1
				if _read_u16(data, entry_offset, little_endian) == 0x0112:
					var orientation := _read_u16(data, entry_offset + 8, little_endian)
					return orientation if orientation >= 1 and orientation <= 8 else 1
		offset += segment_length
	return 1


func _read_u16_big_endian(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 8) | int(data[offset + 1])


func _read_u16(data: PackedByteArray, offset: int, little_endian: bool) -> int:
	return int(data[offset]) | (int(data[offset + 1]) << 8) if little_endian else _read_u16_big_endian(data, offset)


func _read_u32(data: PackedByteArray, offset: int, little_endian: bool) -> int:
	if little_endian:
		return int(data[offset]) | (int(data[offset + 1]) << 8) | (int(data[offset + 2]) << 16) | (int(data[offset + 3]) << 24)
	return (int(data[offset]) << 24) | (int(data[offset + 1]) << 16) | (int(data[offset + 2]) << 8) | int(data[offset + 3])


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


func _on_asset_pivot_property_changed(value: float, property_name: String) -> void:
	if property_name not in ["pivot_x", "pivot_y"]:
		return
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty() or not selected_component_id.is_empty():
		return
	var pivot := _asset_pivot(asset)
	var editor_value := _world_to_editor_units(value)
	if property_name == "pivot_x":
		pivot.x = editor_value
	else:
		pivot.y = editor_value
	_record_direct_change()
	asset["asset_pivot"] = pivot
	canvas_view.set_asset_pivot(pivot)


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
	_update_meshes_button()
	_update_uvs_button()
	_update_sdfs_button()
	_update_runtime_export_button()
	_update_outliner_asset_type_filter_visibility()
	if active_module == "Motion":
		_render_motion_outliner()
		return
	if active_module == "Style":
		_render_weighting_outliner()
		return
	if active_module == "Mesh":
		if active_geometry_submodule in GEOMETRY_SUBMODULES:
			_render_geometry_component_outliner()
		else:
			outliner_list.add_child(_create_outliner_group_label("Mesh · Placeholder"))
			outliner_list.add_child(_create_inspector_field_label("%s authoring will be introduced in a later phase." % active_geometry_submodule))
		return
	var search_text := outliner_search_input.text.strip_edges().to_lower() if is_instance_valid(outliner_search_input) else ""
	if active_module == "Create" and active_create_submodule in CREATE_SUBMODULES:
		var visible_assets: Array = []
		for asset in assets:
			if _outliner_asset_is_visible(asset) and _asset_type(asset) == _create_submodule_asset_type(active_create_submodule) and _asset_matches_search(asset, search_text):
				visible_assets.append(asset)
		visible_assets.sort_custom(_sort_named_documents)
		outliner_list.add_child(_create_outliner_group_label(active_create_submodule))
		for asset in visible_assets:
			_render_asset_outliner_entry(asset, not search_text.is_empty())


func _update_outliner_asset_type_filter_visibility() -> void:
	if not is_instance_valid(outliner_asset_type_filter_panel):
		return
	outliner_asset_type_filter_panel.visible = active_module in ["Mesh", "Style"]


func _on_outliner_asset_type_filter_toggled(enabled: bool, asset_type: String) -> void:
	outliner_asset_type_filters[asset_type] = enabled
	_render_outliner()


func _set_all_outliner_asset_type_filters() -> void:
	for asset_type in outliner_asset_type_filters.keys():
		outliner_asset_type_filters[asset_type] = true
	for asset_type in outliner_asset_type_filter_checkboxes.keys():
		var checkbox := outliner_asset_type_filter_checkboxes[asset_type] as CheckBox
		if checkbox != null:
			checkbox.set_pressed_no_signal(true)
	_render_outliner()


func _apply_outliner_asset_type_filter_checkboxes() -> void:
	for asset_type in outliner_asset_type_filter_checkboxes.keys():
		var checkbox := outliner_asset_type_filter_checkboxes[asset_type] as CheckBox
		if checkbox != null:
			checkbox.set_pressed_no_signal(bool(outliner_asset_type_filters.get(asset_type, true)))


func _asset_type_filter_matches(asset: Dictionary) -> bool:
	return bool(outliner_asset_type_filters.get(_asset_type(asset), false))


func _outliner_focus_asset_id() -> String:
	for asset in assets:
		var asset_id := str(asset.get("id", ""))
		if _outliner_expansion_scope_matches(asset) and bool(expanded_assets.get(asset_id, false)):
			return asset_id
	return ""


func _outliner_expansion_scope_matches(asset: Dictionary) -> bool:
	if active_module != "Create":
		return true
	return _asset_type(asset) == _create_submodule_asset_type(active_create_submodule)


func _outliner_asset_is_visible(asset: Dictionary) -> bool:
	var focused_asset_id := _outliner_focus_asset_id()
	return focused_asset_id.is_empty() or focused_asset_id == str(asset.get("id", ""))


func _set_outliner_asset_expanded(asset_id: String, expanded: bool) -> void:
	if expanded:
		for asset in assets:
			if _outliner_expansion_scope_matches(asset):
				expanded_assets[str(asset.get("id", ""))] = false
		expanded_assets[asset_id] = true
	else:
		expanded_assets[asset_id] = false


func _outliner_component_navigation_has_focus() -> bool:
	if not outliner_component_navigation_active or not active_state.is_empty() or selected_component_id.is_empty():
		return false
	var focus_owner := get_viewport().gui_get_focus_owner()
	return not (focus_owner is LineEdit or focus_owner is TextEdit or focus_owner is SpinBox)


func _visible_outliner_component_ids(asset: Dictionary) -> Array[String]:
	var component_ids: Array[String] = []
	var components: Array = []
	for component in asset.get("components", []):
		if str(component.get("type", "component")) != "guide":
			components.append(component)
	components.sort_custom(_sort_named_documents)
	var rendered_ids: Dictionary = {}
	for component in components:
		if str(component.get("parent_component_id", "")).is_empty():
			_append_outliner_component_ids(asset, component, rendered_ids, component_ids)
	for component in components:
		if not rendered_ids.has(str(component.get("id", ""))):
			_append_outliner_component_ids(asset, component, rendered_ids, component_ids)
	return component_ids


func _append_outliner_component_ids(asset: Dictionary, component: Dictionary, rendered_ids: Dictionary, component_ids: Array[String]) -> void:
	var component_id := str(component.get("id", ""))
	if component_id.is_empty() or rendered_ids.has(component_id):
		return
	rendered_ids[component_id] = true
	component_ids.append(component_id)
	var children := ComponentHierarchy.children(asset, component_id)
	children.sort_custom(_sort_named_documents)
	for child in children:
		_append_outliner_component_ids(asset, child, rendered_ids, component_ids)


func _navigate_outliner_component(direction: int) -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty() or direction == 0:
		return
	var component_ids := _visible_outliner_component_ids(asset)
	var current_index := component_ids.find(selected_component_id)
	if current_index < 0:
		return
	var next_index := clampi(current_index + direction, 0, component_ids.size() - 1)
	if next_index != current_index:
		_select_component(selected_asset_id, component_ids[next_index], true)


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
	motion_selection.select_asset(asset_id)
	if is_instance_valid(motion_workspace):
		motion_workspace.set_asset(asset_id, str(asset.get("name", "Asset")), asset.get("components", []), _ensure_asset_animation(asset))
	_sync_motion_player_document(asset)
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _render_weighting_outliner() -> void:
	var search_text := outliner_search_input.text.strip_edges().to_lower() if is_instance_valid(outliner_search_input) else ""
	outliner_list.add_child(_create_outliner_group_label("Weighting"))
	var visible_asset_count := 0
	for asset in assets:
		if not _outliner_asset_is_visible(asset) or not _asset_type_filter_matches(asset):
			continue
		var asset_id := str(asset.get("id", ""))
		var asset_matches := search_text.is_empty() or str(asset.get("name", "")).to_lower().contains(search_text)
		var component_matches := false
		for component in asset.get("components", []):
			if str(component.get("name", "")).to_lower().contains(search_text):
				component_matches = true
				break
			for style in _weighting_styles(asset_id, str(component.get("id", ""))):
				if str(style.get("name", "")).to_lower().contains(search_text):
					component_matches = true
		if not asset_matches and not component_matches:
			continue
		visible_asset_count += 1
		var asset_button := Button.new()
		asset_button.text = str(asset.get("name", "Asset"))
		asset_button.custom_minimum_size = Vector2(0, 30)
		asset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		asset_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		asset_button.focus_mode = Control.FOCUS_NONE
		_style_outliner_button(asset_button, selected_asset_id == asset_id and selected_component_id.is_empty())
		asset_button.pressed.connect(_select_weighting_asset.bind(asset_id))
		outliner_list.add_child(asset_button)
		if not bool(expanded_assets.get(asset_id, false)) and search_text.is_empty():
			continue
		for component in asset.get("components", []):
			var component_id := str(component.get("id", ""))
			var component_row := HBoxContainer.new()
			var indent := Control.new()
			indent.custom_minimum_size = Vector2(16, 0)
			component_row.add_child(indent)
			var component_button := Button.new()
			var mesh_status := _component_mesh_status(asset_id, component_id, component)
			component_button.text = "%s · %s" % [str(component.get("name", "Component")), "Mesh Ready" if mesh_status == "Ready" else "Missing Mesh" if mesh_status == "Missing" else "Mesh Stale"]
			component_button.custom_minimum_size = Vector2(0, 30)
			component_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			component_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			component_button.focus_mode = Control.FOCUS_NONE
			_style_outliner_button(component_button, selected_asset_id == asset_id and selected_component_id == component_id and selected_weighting_style_id.is_empty())
			component_button.pressed.connect(_select_weighting_component.bind(asset_id, component_id))
			component_row.add_child(component_button)
			var add_button := Button.new()
			add_button.text = "+"
			add_button.custom_minimum_size = Vector2(28, 30)
			add_button.focus_mode = Control.FOCUS_NONE
			add_button.tooltip_text = "Add Weighting Style"
			add_button.pressed.connect(_create_weighting_style.bind(asset_id, component_id))
			component_row.add_child(add_button)
			outliner_list.add_child(component_row)
			for style in _weighting_styles(asset_id, component_id):
				var style_row := HBoxContainer.new()
				var style_indent := Control.new()
				style_indent.custom_minimum_size = Vector2(34, 0)
				style_row.add_child(style_indent)
				var style_button := Button.new()
				style_button.text = "%s · %s" % [str(style.get("name", "Weighting Style")), _weighting_status(asset_id, component_id, component, style)]
				style_button.custom_minimum_size = Vector2(0, 26)
				style_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				style_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
				style_button.focus_mode = Control.FOCUS_NONE
				_style_outliner_button(style_button, selected_weighting_style_id == str(style.get("id", "")))
				style_button.pressed.connect(_select_weighting_style.bind(asset_id, component_id, str(style.get("id", ""))))
				style_row.add_child(style_button)
				outliner_list.add_child(style_row)
	if visible_asset_count == 0:
		outliner_list.add_child(_create_inspector_field_label("No Assets match the selected types."))


func _asset_matches_search(asset: Dictionary, search_text: String) -> bool:
	if search_text.is_empty() or str(asset.get("name", "")).to_lower().contains(search_text):
		return true
	for component in asset.get("components", []):
		if str(component.get("name", "")).to_lower().contains(search_text):
			return true
	for guide in asset.get("guides", []):
		if _guide_display_name(asset, guide).to_lower().contains(search_text):
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


func _render_geometry_component_outliner() -> void:
	var search_text := outliner_search_input.text.strip_edges().to_lower() if is_instance_valid(outliner_search_input) else ""
	var visible_assets: Array = []
	for asset in assets:
		if _outliner_asset_is_visible(asset) and _asset_type_filter_matches(asset) and _asset_matches_search(asset, search_text):
			visible_assets.append(asset)
	visible_assets.sort_custom(_sort_named_documents)
	outliner_list.add_child(_create_outliner_group_label("%s · Components" % active_geometry_submodule))
	for asset in visible_assets:
		_render_geometry_component_asset_entry(asset, not search_text.is_empty())
	if visible_assets.is_empty():
		outliner_list.add_child(_create_inspector_field_label("No Assets match the selected types."))


func _render_geometry_component_asset_entry(asset: Dictionary, force_expand := false) -> void:
	var asset_id := str(asset.get("id", ""))
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 0)
	outliner_list.add_child(container)
	var asset_button := Button.new()
	asset_button.text = str(asset.get("name", "Asset"))
	asset_button.custom_minimum_size = Vector2(0, 30)
	asset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asset_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	asset_button.focus_mode = Control.FOCUS_NONE
	_style_outliner_button(asset_button, selected_asset_id == asset_id and selected_component_id.is_empty())
	asset_button.pressed.connect(_select_geometry_asset.bind(asset_id))
	container.add_child(asset_button)
	if not force_expand and not bool(expanded_assets.get(asset_id, false)):
		return
	container.add_child(_create_outliner_child_group_label("Components"))
	var components: Array = asset.get("components", []).duplicate()
	var references: Array = []
	var guides: Array = asset.get("guides", []).duplicate(true) if active_geometry_submodule in ["Sampling", "Seeding", "Meshing"] else []
	if active_geometry_submodule in ["Sampling", "Seeding", "Meshing"]:
		components.clear()
		for component in asset.get("components", []):
			if str(component.get("type", "component")) == "guide":
				guides.append(component)
			elif _is_reference_component(component):
				references.append(component)
			else:
				components.append(component)
	components.sort_custom(_sort_named_documents)
	references.sort_custom(_sort_named_documents)
	guides.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return _guide_display_name(asset, left).naturalnocasecmp_to(_guide_display_name(asset, right)) < 0)
	for component in components:
		if str(component.get("type", "component")) == "guide":
			continue
		var draw_mode := str(component.get("draw_mode", "closed_loop"))
		if active_geometry_submodule in ["Sampling", "Seeding"] and draw_mode == "ribbon":
			continue
		var component_id := str(component.get("id", ""))
		var row := HBoxContainer.new()
		var indent := Control.new()
		indent.custom_minimum_size = Vector2(16, 0)
		row.add_child(indent)
		var summary := _geometry_outliner_status_summary(asset_id, component_id, component)
		var button := Button.new()
		button.text = str(component.get("name", "Component"))
		button.tooltip_text = str(summary.get("tooltip", ""))
		button.custom_minimum_size = Vector2(0, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		_style_outliner_button(button, selected_asset_id == asset_id and selected_component_id == component_id and selected_geometry_bake_method.is_empty())
		button.pressed.connect(_select_geometry_component.bind(asset_id, component_id))
		row.add_child(button)
		row.add_child(_create_geometry_role_badge(str(component.get("topology_role", "outer"))))
		var status_dot := Label.new()
		status_dot.text = "●"
		status_dot.custom_minimum_size = Vector2(28, 30)
		status_dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_dot.add_theme_font_size_override("font_size", 23)
		status_dot.add_theme_color_override("font_color", summary.get("color", Color("#737f91")))
		status_dot.tooltip_text = str(summary.get("tooltip", ""))
		row.add_child(status_dot)
		var result_count := int(summary.get("count", 0))
		if result_count >= 2:
			var count_label := Label.new()
			count_label.text = str(result_count)
			count_label.custom_minimum_size = Vector2(20, 30)
			count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			count_label.add_theme_font_size_override("font_size", 12)
			count_label.add_theme_color_override("font_color", Color("#9aa3b2"))
			count_label.tooltip_text = str(summary.get("tooltip", ""))
			row.add_child(count_label)
		container.add_child(row)
		if active_geometry_submodule == "Sampling":
			for reference in references:
				if str(reference.get("parent_component_id", "")) == component_id and str(reference.get("topology_role", "outer")) == "hole":
					_render_geometry_reference_row(container, asset, reference)
			for guide in guides:
				if str(guide.get("scope", {}).get("component_id", "")) == component_id and str(guide.get("guide_type", "")) == AssetGuide.CUT:
					_render_geometry_sampling_guide_row(container, asset, guide)
		elif active_geometry_submodule == "Seeding":
			_render_geometry_seeding_dependency_row(container, asset_id, component_id, component)
			_render_geometry_seeding_input_row(container, asset_id, component_id, "", "outer", "Outer · %s" % str(component.get("name", "Component")), "Clearance", "Outer")
			for reference in references:
				if str(reference.get("parent_component_id", "")) == component_id and str(reference.get("topology_role", "outer")) == "hole":
					_render_geometry_seeding_input_row(container, asset_id, component_id, str(reference.get("id", "")), "hole", "Hole · %s" % _component_outliner_name(asset, reference), "Excluded", "Hole")
			for guide in guides:
				if str(guide.get("scope", {}).get("component_id", "")) != component_id:
					continue
				var guide_type := str(guide.get("guide_type", ""))
				if guide_type == AssetGuide.CUT:
					_render_geometry_seeding_input_row(container, asset_id, component_id, str(guide.get("id", "")), "cut", "Cut · %s" % _guide_display_name(asset, guide), "Barrier", "Cut")
				elif guide_type == AssetGuide.SAMPLER_SPINE:
					var enabled := _geometry_seeding_spine_enabled(_geometry_seeding_recipe(asset_id, component_id), str(guide.get("id", "")))
					_render_geometry_seeding_input_row(container, asset_id, component_id, str(guide.get("id", "")), "spine", "Spine · %s" % _guide_display_name(asset, guide), "Enabled" if enabled else "Disabled", "Spine")
		elif active_geometry_submodule == "Meshing":
			_render_geometry_meshing_pipeline_rows(container, asset, component)
	if active_geometry_submodule != "Sampling":
		return


func _render_geometry_reference_row(container: VBoxContainer, asset: Dictionary, reference: Dictionary) -> void:
	var asset_id := str(asset.get("id", ""))
	var reference_id := str(reference.get("id", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(34, 0)
	row.add_child(indent)
	var button := Button.new()
	var summary := _geometry_sampling_input_summary(asset_id, str(reference.get("parent_component_id", "")), reference_id, "hole")
	button.text = "Hole · %s  %s" % [_component_outliner_name(asset, reference), str(summary.get("label", "↳"))]
	button.tooltip_text = "Sampling dependency · select the parent Component to edit this contour"
	button.custom_minimum_size = Vector2(0, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	_style_outliner_button(button, selected_sampling_input_id == reference_id, str(reference.get("topology_role", "outer")))
	button.pressed.connect(_select_geometry_sampling_reference.bind(asset_id, str(reference.get("parent_component_id", "")), reference_id))
	row.add_child(button)
	row.add_child(_create_geometry_role_badge(str(reference.get("topology_role", "outer"))))
	container.add_child(row)


func _render_geometry_sampling_guide_row(container: VBoxContainer, asset: Dictionary, guide: Dictionary) -> void:
	var asset_id := str(asset.get("id", ""))
	var guide_id := str(guide.get("id", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(34, 0)
	row.add_child(indent)
	var button := Button.new()
	var guide_name := _guide_display_name(asset, guide)
	var parent_component_id := str(guide.get("scope", {}).get("component_id", ""))
	var summary := _geometry_sampling_input_summary(asset_id, parent_component_id, guide_id, "cut")
	button.text = "Cut · %s  %s" % [guide_name, str(summary.get("label", "↳"))]
	button.tooltip_text = "Sampling constraint · %s" % AssetGuide.display_name(str(guide.get("guide_type", AssetGuide.SAMPLER_SPINE)))
	button.custom_minimum_size = Vector2(0, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	_style_guide_outliner_button(button, str(guide.get("id", "")) == selected_guide_id, str(guide.get("guide_type", AssetGuide.SAMPLER_SPINE)))
	button.pressed.connect(_select_guide.bind(asset_id, guide_id))
	row.add_child(button)
	row.add_child(_create_geometry_role_badge("Cut" if str(guide.get("guide_type", "")) == AssetGuide.CUT else "Guide"))
	container.add_child(row)


func _render_geometry_seeding_dependency_row(container: VBoxContainer, asset_id: String, component_id: String, component: Dictionary) -> void:
	var row := HBoxContainer.new()
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(34, 0)
	row.add_child(indent)
	var button := Button.new()
	var ready := _geometry_sampling_bake_is_current(asset_id, component_id, component)
	button.text = "Sampling · Adaptive  ·  %s" % ("Baked" if ready else "Required")
	button.custom_minimum_size = Vector2(0, 26)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_open_sampling_dependency.bind(asset_id, component_id))
	row.add_child(button)
	container.add_child(row)


func _open_sampling_dependency(asset_id: String, component_id: String) -> void:
	active_geometry_submodule = "Sampling"
	_set_active_module_visual("Mesh", "Sampling")
	_select_geometry_component(asset_id, component_id)


func _open_seeding_dependency(asset_id: String, component_id: String) -> void:
	active_geometry_submodule = "Seeding"
	_set_active_module_visual("Mesh", "Seeding")
	_select_geometry_component(asset_id, component_id)


func _render_geometry_meshing_pipeline_rows(container: VBoxContainer, asset: Dictionary, component: Dictionary) -> void:
	var asset_id := str(asset.get("id", ""))
	var component_id := str(component.get("id", ""))
	var sampling := _geometry_sampling_bake(asset_id, component_id)
	var sampling_ready := _geometry_sampling_bake_is_current(asset_id, component_id, component)
	_render_geometry_meshing_pipeline_row(container, "Sampling · Adaptive · %s · %d Points" % ["Baked" if sampling_ready else "Required", int(sampling.get("constraint_sample_count", sampling.get("sample_count", 0)))], _open_sampling_dependency.bind(asset_id, component_id))
	var recipe := _geometry_meshing_recipe(asset_id, component_id)
	var seed_method := str(recipe.get("parameters", {}).get("seeding_method", GeometrySeedingService.POISSON_FILL))
	var seeding := _geometry_seeding_bake(asset_id, component_id, seed_method)
	var seeding_ready := _geometry_meshing_input_is_current(asset_id, component_id, component, recipe)
	_render_geometry_meshing_pipeline_row(container, "Seeding · %s · %s · %d Seeds" % [_geometry_bake_method_label(seed_method), "Baked" if seeding_ready else "Required", int(seeding.get("seed_count", 0))], _open_seeding_dependency.bind(asset_id, component_id))
	_render_geometry_meshing_pipeline_row(container, "Constraints · Outer Preserved · %d Hole%s · %d Cut%s" % [int(sampling.get("hole_count", 0)), "" if int(sampling.get("hole_count", 0)) == 1 else "s", sampling.get("cuts", []).size(), "" if sampling.get("cuts", []).size() == 1 else "s"], _open_sampling_dependency.bind(asset_id, component_id))
	var result := geometry_meshing_preview if _geometry_meshing_preview_matches(asset_id, component_id, component) else _geometry_meshing_bake(asset_id, component_id)
	_render_geometry_meshing_pipeline_row(container, "Mesh · Constrained Mesh · %s%s" % [_geometry_meshing_status(asset_id, component_id, component), " · %d Triangles" % int(result.get("triangle_count", 0)) if not result.is_empty() else ""], Callable())


func _render_geometry_meshing_pipeline_row(container: VBoxContainer, title: String, action: Callable) -> void:
	var row := HBoxContainer.new()
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(34, 0)
	row.add_child(indent)
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(0, 26)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not action.is_valid()
	if action.is_valid():
		button.pressed.connect(action)
	row.add_child(button)
	container.add_child(row)


func _render_geometry_seeding_input_row(container: VBoxContainer, asset_id: String, component_id: String, input_id: String, role: String, title: String, treatment: String, badge: String) -> void:
	var count := 0
	var sampling_bake := _geometry_sampling_bake(asset_id, component_id)
	for stat in sampling_bake.get("boundary_stats", []):
		if str(stat.get("input_id", "")) == input_id and str(stat.get("role", "")) == role:
			count += int(stat.get("sample_count", 0))
	if role == "spine":
		var component := _get_component(_get_asset(asset_id), component_id)
		var seeding_result := geometry_seeding_preview if _geometry_seeding_preview_matches(asset_id, component_id, component) else _geometry_seeding_bake(asset_id, component_id)
		for stat in seeding_result.get("guide_stats", []):
			if str(stat.get("guide_id", "")) == input_id:
				count = int(stat.get("seed_count", 0))
	var row := HBoxContainer.new()
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(34, 0)
	row.add_child(indent)
	var button := Button.new()
	button.text = "%s  ·  %s%s" % [title, treatment, "  ·  %d" % count if count > 0 else ""]
	button.custom_minimum_size = Vector2(0, 26)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	_style_outliner_button(button, not input_id.is_empty() and selected_sampling_input_id == input_id)
	button.pressed.connect(_select_geometry_seeding_input.bind(asset_id, component_id, input_id, role))
	row.add_child(button)
	row.add_child(_create_geometry_role_badge(badge))
	container.add_child(row)


func _select_geometry_seeding_input(asset_id: String, component_id: String, input_id: String, role: String) -> void:
	if selected_asset_id != asset_id or selected_component_id != component_id:
		_select_geometry_component(asset_id, component_id)
	selected_sampling_input_id = input_id
	selected_sampling_input_kind = role
	selected_guide_id = input_id if role in ["cut", "spine"] else ""
	_render_outliner()
	_render_inspector()
	_refresh_geometry_seeding_workspace()


func _geometry_sampling_input_summary(asset_id: String, component_id: String, input_id: String, role: String) -> Dictionary:
	var component := _get_component(_get_asset(asset_id), component_id)
	var result := geometry_sampling_preview if _geometry_sampling_preview_matches(asset_id, component_id, component) else _geometry_sampling_bake(asset_id, component_id)
	var count := 0
	for stat in result.get("boundary_stats", []):
		if str(stat.get("input_id", "")) == input_id and str(stat.get("role", "")) == role:
			count += int(stat.get("sample_count", 0))
	var recipe := _geometry_sampling_recipe(asset_id, component_id)
	var has_adjustment := _geometry_sampling_input_has_override(recipe, input_id)
	var factor := float(recipe.get("parameters", {}).get("boundary_refinements", {}).get(input_id, {}).get("factor", 1.0))
	var state_label := "%s×" % _format_scale_value(factor) if has_adjustment else "↳"
	if count > 0:
		state_label += "  %d" % count
	return {"label": state_label, "count": count, "factor": factor}


func _create_geometry_role_badge(role: String) -> Label:
	var badge := Label.new()
	badge.text = role.capitalize()
	badge.custom_minimum_size = Vector2(42, 24)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 9)
	var normalized_role := role.to_lower()
	var badge_color := Color("#ef6c78") if normalized_role in ["hole", "cut"] else Color("#f2c94c") if normalized_role == "spine" else Color("#737f91")
	badge.add_theme_color_override("font_color", badge_color.lightened(0.35))
	return badge


func _render_geometry_uv_mapping_bake_rows(container: VBoxContainer, asset_id: String, component_id: String, component: Dictionary) -> void:
	var mesh_bakes := _geometry_meshing_bakes(asset_id, component_id)
	var uv_bakes := _geometry_uv_mapping_bakes(asset_id, component_id)
	var recipe := _geometry_uv_mapping_recipe(asset_id, component_id)
	for mesh_method in GeometryMeshingService.VALID_METHODS:
		if not mesh_bakes.has(mesh_method):
			continue
		var mesh_row := HBoxContainer.new()
		var mesh_indent := Control.new()
		mesh_indent.custom_minimum_size = Vector2(34, 0)
		mesh_row.add_child(mesh_indent)
		var mesh_button := Button.new()
		mesh_button.text = "%s Mesh  ·  %s" % [_geometry_bake_method_label(mesh_method), "Baked" if _geometry_meshing_bake_is_current(asset_id, component_id, component, mesh_method) else "Stale"]
		mesh_button.custom_minimum_size = Vector2(0, 26)
		mesh_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mesh_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		mesh_button.focus_mode = Control.FOCUS_NONE
		_style_outliner_button(mesh_button, str(recipe.get("parameters", {}).get("mesh_method", "")) == mesh_method and selected_geometry_bake_method.is_empty())
		mesh_button.pressed.connect(_set_geometry_uv_mapping_mesh_source.bind(mesh_method))
		mesh_row.add_child(mesh_button)
		container.add_child(mesh_row)
		var key := GeometryUVMappingService.bake_key(mesh_method, GeometryUVMappingService.BOUNDS_PLANAR)
		if not uv_bakes.has(key):
			continue
		var uv_bake: Dictionary = uv_bakes[key]
		var uv_row := HBoxContainer.new()
		var uv_indent := Control.new()
		uv_indent.custom_minimum_size = Vector2(52, 0)
		uv_row.add_child(uv_indent)
		var uv_button := Button.new()
		uv_button.text = "Bounds / Planar UV  ·  %s" % ("Baked" if _geometry_uv_mapping_bake_is_current(asset_id, component_id, component, uv_bake) else "Stale")
		uv_button.custom_minimum_size = Vector2(0, 24)
		uv_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		uv_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		uv_button.focus_mode = Control.FOCUS_NONE
		_style_outliner_button(uv_button, selected_asset_id == asset_id and selected_component_id == component_id and selected_geometry_bake_method == key)
		uv_button.pressed.connect(_select_geometry_uv_mapping_bake.bind(asset_id, component_id, mesh_method, GeometryUVMappingService.BOUNDS_PLANAR))
		uv_row.add_child(uv_button)
		container.add_child(uv_row)


func _select_geometry_uv_mapping_bake(asset_id: String, component_id: String, mesh_method: String, uv_method: String) -> void:
	_select_geometry_component(asset_id, component_id)
	_set_geometry_uv_mapping_mesh_source(mesh_method)
	_set_geometry_uv_mapping_method(uv_method)


func _geometry_bake_methods_for_active_module(bakes: Dictionary) -> Array[String]:
	var order: Array[String] = []
	if active_geometry_submodule == "Sampling":
		order.append(GeometrySamplingService.ADAPTIVE)
	elif active_geometry_submodule == "Seeding":
		order.append(GeometrySeedingService.POISSON_FILL)
		order.append(GeometrySeedingService.SPINE_FLOW)
	else:
		order.append(GeometryMeshingService.CONSTRAINED_MESH)
		order.append(RibbonMeshService.METHOD)
	var methods: Array[String] = []
	for method in order:
		if bakes.has(method):
			methods.append(method)
	return methods


func _geometry_bake_method_label(method: String) -> String:
	if method == GeometrySamplingService.ADAPTIVE:
		return "Adaptive"
	if method == GeometrySamplingService.EVEN_SPACING:
		return "Even Spacing"
	if method == GeometrySeedingService.SPINE_FLOW:
		return "Spine Flow"
	if method in [GeometryMeshingService.CONSTRAINED_MESH, GeometryMeshingService.CONSTRAINED_DELAUNAY, GeometryMeshingService.ORGANIC_RELAXED]:
		return "Constrained Mesh"
	if method == RibbonMeshService.METHOD:
		return "Ribbon Strip"
	return "Poisson Fill"


func _geometry_bake_status(method: String, bake: Dictionary, asset_id: String, component_id: String, component: Dictionary) -> String:
	if active_geometry_submodule == "Sampling":
		return "Baked" if _geometry_sampling_bake_is_current(asset_id, component_id, component) else "Ready to Preview"
	if active_geometry_submodule == "Meshing":
		if method == RibbonMeshService.METHOD:
			return "Baked" if RibbonMeshService.matches_source(bake, component) else "Ready to Bake"
		return _geometry_meshing_status(asset_id, component_id, component)
	var sampling_bake := _geometry_sampling_bake(asset_id, component_id)
	if sampling_bake.is_empty() or not _geometry_sampling_bake_is_current(asset_id, component_id, component):
		return "Blocked"
	var recipe := GeometrySeedingService.normalize_recipe({"method": method, "parameters": bake.get("parameters", {})})
	var matches := int(bake.get("algorithm_version", 0)) == GeometrySeedingService.ALGORITHM_VERSION \
		and str(bake.get("sampling_bake_id", "")) == str(sampling_bake.get("bake_id", "")) \
		and str(bake.get("sampling_fingerprint", "")) == GeometrySeedingService.sampling_fingerprint(sampling_bake)
	if method == GeometrySeedingService.SPINE_FLOW:
		var guides := _geometry_seeding_sampler_spines(asset_id, component_id, recipe)
		var guide_ids: Array[String] = []
		for guide in guides:
			guide_ids.append(str(guide.get("id", "")))
		matches = matches and bake.get("guide_ids", []) == guide_ids and str(bake.get("guides_fingerprint", "")) == GeometrySeedingService.guides_fingerprint(guides)
	if not matches:
		return "Ready to Preview"
	return "Edited" if bool(bake.get("edited", false)) else "Baked"


func _geometry_outliner_status_summary(asset_id: String, component_id: String, component: Dictionary) -> Dictionary:
	if active_geometry_submodule == "Sampling":
		var sampling_status := _geometry_sampling_status(asset_id, component_id, component)
		var bake_count := 1 if not _geometry_sampling_bake(asset_id, component_id).is_empty() else 0
		return {"color": _geometry_status_color(sampling_status), "count": bake_count, "tooltip": "%s\n%s Adaptive Sampling — %s" % [str(component.get("name", "Component")), _geometry_status_symbol(sampling_status), sampling_status]}
	var entries_by_key: Dictionary = {}
	var order: Array[String] = []
	if active_geometry_submodule == "UV Mapping":
		var uv_bakes := _geometry_uv_mapping_bakes(asset_id, component_id)
		var keys: Array[String] = []
		for bake_key in uv_bakes:
			keys.append(str(bake_key))
		keys.sort()
		for bake_key in keys:
			var uv_bake: Dictionary = uv_bakes[bake_key]
			var uv_method := str(uv_bake.get("method", GeometryUVMappingService.BOUNDS_PLANAR))
			var mesh_method := str(uv_bake.get("mesh_method", ""))
			entries_by_key[bake_key] = {
				"label": _geometry_method_number_label(uv_method) + ": " + _geometry_bake_method_label(uv_method) + " · " + _geometry_bake_method_label(mesh_method) + " Mesh",
				"status": "Baked" if _geometry_uv_mapping_bake_is_current(asset_id, component_id, component, uv_bake) else "Stale"
			}
			order.append(bake_key)
	else:
		var bakes := _geometry_sampling_bakes(asset_id, component_id) if active_geometry_submodule == "Sampling" \
			else _geometry_seeding_bakes(asset_id, component_id) if active_geometry_submodule == "Seeding" \
			else _geometry_meshing_bakes(asset_id, component_id)
		for method in _geometry_bake_methods_for_active_module(bakes):
			entries_by_key[method] = {
				"label": _geometry_method_number_label(method) + ": " + _geometry_bake_method_label(method),
				"status": _geometry_bake_status(method, bakes[method], asset_id, component_id, component)
			}
			order.append(method)

	if order.is_empty():
		var empty_status := _geometry_sampling_status(asset_id, component_id, component) if active_geometry_submodule == "Sampling" \
			else _geometry_seeding_status(asset_id, component_id, component) if active_geometry_submodule == "Seeding" \
			else _geometry_meshing_status(asset_id, component_id, component) if active_geometry_submodule == "Meshing" \
			else _geometry_uv_mapping_status(asset_id, component_id, component)
		entries_by_key["state"] = {"label": "Current state", "status": empty_status}
		order.append("state")

	var best_rank := -1
	var best_status := "Not Generated"
	var tooltip_lines: Array[String] = []
	for entry_key in order:
		var entry: Dictionary = entries_by_key[entry_key]
		var status := str(entry.get("status", "Not Generated"))
		var rank := _geometry_status_rank(status)
		if rank > best_rank:
			best_rank = rank
			best_status = status
		tooltip_lines.append("%s %s — %s" % [_geometry_status_symbol(status), str(entry.get("label", "Result")), status])
	var result_count := order.size() if not (order.size() == 1 and str(order[0]) == "state") else 0
	var heading := "%s · %d result%s" % [str(component.get("name", "Component")), result_count, "" if result_count == 1 else "s"]
	if result_count == 0:
		heading = "%s · No results" % str(component.get("name", "Component"))
	return {
		"color": _geometry_status_color(best_status),
		"count": result_count,
		"tooltip": heading + "\n" + "\n".join(tooltip_lines)
	}


func _geometry_outliner_active_preview(asset_id: String, component_id: String, component: Dictionary) -> Dictionary:
	var document_key := _geometry_document_key(asset_id, component_id)
	if active_geometry_submodule == "Sampling" and geometry_sampling_preview_key == document_key:
		var method := str(geometry_sampling_preview.get("method", ""))
		if not method.is_empty():
			return {"key": method, "label": _geometry_method_number_label(method) + ": " + _geometry_bake_method_label(method), "status": "Preview" if _geometry_sampling_preview_matches(asset_id, component_id, component) else "Invalid"}
	if active_geometry_submodule == "Seeding" and geometry_seeding_preview_key == document_key:
		var method := str(geometry_seeding_preview.get("method", ""))
		if not method.is_empty():
			return {"key": method, "label": _geometry_method_number_label(method) + ": " + _geometry_bake_method_label(method), "status": "Preview Ready" if _geometry_seeding_preview_matches(asset_id, component_id, component) else "Calculating" if geometry_seeding_preview_state == "calculating" else "Invalid"}
	if active_geometry_submodule == "Meshing" and geometry_meshing_preview_key == document_key:
		var method := str(geometry_meshing_preview.get("method", ""))
		if not method.is_empty() or geometry_meshing_preview_state == "calculating":
			return {"key": GeometryMeshingService.CONSTRAINED_MESH, "label": "Constrained Mesh", "status": "Preview Ready" if _geometry_meshing_preview_matches(asset_id, component_id, component) else "Calculating" if geometry_meshing_preview_state == "calculating" else "Invalid"}
	if active_geometry_submodule == "UV Mapping" and geometry_uv_mapping_preview_key == document_key:
		var method := str(geometry_uv_mapping_preview.get("method", ""))
		var mesh_method := str(geometry_uv_mapping_preview.get("mesh_method", ""))
		if not method.is_empty():
			var preview_key := GeometryUVMappingService.bake_key(mesh_method, method)
			return {"key": preview_key, "label": _geometry_method_number_label(method) + ": " + _geometry_bake_method_label(method) + " · " + _geometry_bake_method_label(mesh_method) + " Mesh", "status": "Preview" if _geometry_uv_mapping_preview_matches(asset_id, component_id, component) else "Invalid"}
	return {}


func _geometry_method_number_label(method: String) -> String:
	var methods: Array[String] = []
	if active_geometry_submodule == "Sampling":
		methods = [GeometrySamplingService.ADAPTIVE]
	elif active_geometry_submodule == "Seeding":
		methods = [GeometrySeedingService.POISSON_FILL, GeometrySeedingService.SPINE_FLOW]
	elif active_geometry_submodule == "Meshing":
		methods = [GeometryMeshingService.CONSTRAINED_MESH]
	else:
		methods = [GeometryUVMappingService.BOUNDS_PLANAR]
	var index := methods.find(method)
	return "Automatic" if index < 0 else str(index + 1)


func _geometry_status_rank(status: String) -> int:
	if status in ["Baked", "Edited", "Ready"]:
		return 5
	if status in ["Ready to Bake", "Preview Ready"]:
		return 4
	if status in ["Calculating", "Ready to Preview"]:
		return 3
	if status in ["Blocked", "Sampling Required"]:
		return 2
	if status == "Invalid":
		return 1
	return 2


func _geometry_status_color(status: String) -> Color:
	if status in ["Baked", "Edited", "Ready"]:
		return Color("#75b88a")
	if status in ["Ready to Bake", "Preview Ready"]:
		return Color("#f2c94c")
	if status in ["Calculating", "Ready to Preview"]:
		return Color("#8fd8f5")
	if status in ["Blocked", "Sampling Required"]:
		return Color("#e56b6f")
	if status == "Invalid":
		return Color("#737f91")
	return Color("#737f91")


func _geometry_status_symbol(status: String) -> String:
	if status in ["Baked", "Edited", "Ready"]:
		return "🟢"
	if status in ["Ready to Bake", "Preview Ready"]:
		return "🟡"
	if status in ["Calculating", "Ready to Preview"]:
		return "🔵"
	if status in ["Blocked", "Sampling Required"]:
		return "🔴"
	if status == "Invalid":
		return "⚪"
	return "⚪"


func _select_geometry_asset(asset_id: String) -> void:
	geometry_sampling_preview_revision += 1
	geometry_sampling_input_refresh_pending = false
	geometry_seeding_preview_revision += 1
	var was_selected := selected_asset_id == asset_id and selected_component_id.is_empty()
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_geometry_bake_method = ""
	active_module = "Mesh"
	active_state = ""
	_set_geometry_command_state("")
	if was_selected:
		_set_outliner_asset_expanded(asset_id, not bool(expanded_assets.get(asset_id, false)))
	else:
		_set_outliner_asset_expanded(asset_id, true)
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _select_geometry_component(asset_id: String, component_id: String) -> void:
	geometry_sampling_preview_revision += 1
	geometry_seeding_preview_revision += 1
	selected_asset_id = asset_id
	selected_component_id = component_id
	selected_guide_id = ""
	selected_sampling_input_id = ""
	selected_sampling_input_kind = ""
	active_module = "Mesh"
	active_state = ""
	selected_geometry_bake_method = ""
	_set_geometry_command_state("")
	_set_outliner_asset_expanded(asset_id, true)
	_render_outliner()
	_render_inspector()
	_render_canvas_context()
	if active_geometry_submodule == "Sampling" and is_instance_valid(geometry_sampling_workspace):
		geometry_sampling_workspace.grab_focus()
		if not _geometry_sampling_bake_is_current(asset_id, component_id, _get_component(_get_asset(asset_id), component_id)):
			_schedule_geometry_sampling_preview()
	elif active_geometry_submodule == "Seeding" and is_instance_valid(geometry_seeding_workspace):
		geometry_seeding_workspace.grab_focus()
		if _geometry_seeding_status(asset_id, component_id, _get_component(_get_asset(asset_id), component_id)) == "Ready to Preview":
			_schedule_geometry_seeding_preview()
	elif active_geometry_submodule == "Meshing" and is_instance_valid(geometry_meshing_workspace):
		geometry_meshing_workspace.grab_focus()
	elif active_geometry_submodule == "UV Mapping" and is_instance_valid(geometry_uv_mapping_workspace):
		geometry_uv_mapping_workspace.grab_focus()


func _select_geometry_sampling_reference(asset_id: String, parent_component_id: String, reference_id := "") -> void:
	if parent_component_id.is_empty():
		_select_geometry_asset(asset_id)
		return
	if selected_asset_id != asset_id or selected_component_id != parent_component_id or active_module != "Mesh" or active_geometry_submodule != "Sampling":
		_select_geometry_component(asset_id, parent_component_id)
	else:
		selected_guide_id = ""
	if not reference_id.is_empty():
		selected_sampling_input_id = reference_id
		selected_sampling_input_kind = "reference"
		_render_outliner()
		_render_inspector()
		_render_canvas_context()
		return
	for reference in _get_asset(asset_id).get("components", []):
		if _is_reference_component(reference) and str(reference.get("parent_component_id", "")) == parent_component_id:
			selected_sampling_input_id = str(reference.get("id", ""))
			selected_sampling_input_kind = "reference"
			_render_outliner()
			_render_inspector()
			_render_canvas_context()
			return


func _select_geometry_bake(asset_id: String, component_id: String, method: String) -> void:
	_select_geometry_component(asset_id, component_id)
	if active_geometry_submodule == "Sampling":
		_set_geometry_sampling_method(method)
	elif active_geometry_submodule == "Seeding":
		_set_geometry_seeding_method(method)
	else:
		_set_geometry_meshing_method(method)


func _render_asset_outliner_entry(asset: Dictionary, force_expand := false) -> void:
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
	_style_outliner_button(asset_button, asset_id == selected_asset_id and selected_component_id.is_empty() and selected_guide_id.is_empty())
	asset_button.pressed.connect(_select_asset.bind(asset_id))
	asset_header.add_child(asset_button)
	var add_button := Button.new()
	add_button.text = "Add"
	add_button.custom_minimum_size = Vector2(48, 30)
	add_button.focus_mode = Control.FOCUS_NONE
	add_button.pressed.connect(_open_component_dialog.bind(asset_id, add_button))
	asset_header.add_child(add_button)
	if not force_expand and not bool(expanded_assets.get(asset_id, false)):
		return
	var components: Array = []
	var references: Array = []
	var guides: Array = asset.get("guides", []).duplicate(true)
	for component in asset.get("components", []):
		if str(component.get("type", "component")) == "guide":
			guides.append(component)
		elif _is_reference_component(component):
			references.append(component)
		else:
			components.append(component)
	components.sort_custom(_sort_named_documents)
	guides.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return _guide_display_name(asset, left).naturalnocasecmp_to(_guide_display_name(asset, right)) < 0)
	asset_container.add_child(_create_outliner_child_group_label("Components"))
	var rendered_component_ids: Dictionary = {}
	for component in components:
		if str(component.get("parent_component_id", "")).is_empty():
			_render_component_outliner_tree(asset_container, asset, component, 16, rendered_component_ids)
	# A malformed in-memory document should remain editable even before its next load migration.
	for component in components:
		if not rendered_component_ids.has(str(component.get("id", ""))):
			_render_component_outliner_tree(asset_container, asset, component, 16, rendered_component_ids)
	asset_container.add_child(_create_outliner_child_group_label("References"))
	references.sort_custom(_sort_named_documents)
	for reference in references:
		_render_component_outliner_tree(asset_container, asset, reference, 16, rendered_component_ids)
	asset_container.add_child(_create_outliner_child_group_label("Guides"))
	for guide in guides:
		_render_component_guide_row(asset_container, asset, guide)


func _render_component_outliner_tree(container: VBoxContainer, asset: Dictionary, component: Dictionary, indent: int, rendered_component_ids: Dictionary) -> void:
	var asset_id := str(asset.get("id", ""))
	var component_id := str(component.get("id", ""))
	if component_id.is_empty() or rendered_component_ids.has(component_id):
		return
	rendered_component_ids[component_id] = true
	var component_row := HBoxContainer.new()
	component_row.add_theme_constant_override("separation", 0)
	container.add_child(component_row)
	var child_placeholder := Control.new()
	child_placeholder.custom_minimum_size = Vector2(indent, 0)
	component_row.add_child(child_placeholder)
	component_row.add_child(_create_visibility_checkbox(bool(component.get("visibility", true)), _on_component_visibility_entry_changed.bind(asset_id, component_id)))
	var component_button := Button.new()
	var component_name := _component_outliner_name(asset, component)
	component_button.text = component_name if bool(component.get("visibility", true)) else _strikethrough_text(component_name)
	component_button.custom_minimum_size = Vector2(0, 30)
	component_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	component_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	component_button.focus_mode = Control.FOCUS_NONE
	_style_outliner_button(component_button, component_id == selected_component_id and asset_id == selected_asset_id, str(component.get("topology_role", "outer")))
	component_button.pressed.connect(_select_component.bind(asset_id, component_id, true))
	component_button.gui_input.connect(_on_component_outliner_gui_input.bind(asset_id, component_id, component_button))
	component_row.add_child(component_button)
	if _is_reference_component(component):
		return
	var add_button := Button.new()
	add_button.text = "+"
	add_button.custom_minimum_size = Vector2(28, 30)
	add_button.focus_mode = Control.FOCUS_NONE
	add_button.tooltip_text = "Add Child or Guide"
	add_button.pressed.connect(_open_component_add_menu.bind(asset_id, component_id, add_button))
	component_row.add_child(add_button)
	var children := ComponentHierarchy.children(asset, component_id)
	children.sort_custom(_sort_named_documents)
	for child in children:
		_render_component_outliner_tree(container, asset, child, indent + 16, rendered_component_ids)


func _on_component_outliner_gui_input(event: InputEvent, asset_id: String, component_id: String, button: Button) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
		return
	if not is_instance_valid(component_context_menu):
		return
	_select_component(asset_id, component_id)
	component_context_menu.set_meta("asset_id", asset_id)
	component_context_menu.set_meta("component_id", component_id)
	var component := _get_component(_get_asset(asset_id), component_id)
	var detach_index := component_context_menu.get_item_index(3)
	component_context_menu.set_item_disabled(detach_index, str(component.get("parent_component_id", "")).is_empty())
	component_context_menu.position = Vector2i(button.global_position + event.position)
	component_context_menu.popup()
	get_viewport().set_input_as_handled()


func _render_component_guide_row(container: VBoxContainer, asset: Dictionary, guide: Dictionary) -> void:
	var asset_id := str(asset.get("id", ""))
	var guide_row := HBoxContainer.new()
	guide_row.add_theme_constant_override("separation", 0)
	container.add_child(guide_row)
	var component_indent := Control.new()
	component_indent.custom_minimum_size = Vector2(16, 0)
	guide_row.add_child(component_indent)
	guide_row.add_child(_create_visibility_checkbox(bool(guide.get("visibility", true)), _on_guide_visibility_entry_changed.bind(asset_id, str(guide.get("id", "")))))
	var guide_button := Button.new()
	var guide_name := _guide_display_name(asset, guide)
	guide_button.text = guide_name if bool(guide.get("visibility", true)) else _strikethrough_text(guide_name)
	guide_button.tooltip_text = AssetGuide.display_name(str(guide.get("guide_type", AssetGuide.SAMPLER_SPINE)))
	guide_button.custom_minimum_size = Vector2(0, 30)
	guide_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	guide_button.focus_mode = Control.FOCUS_NONE
	_style_guide_outliner_button(guide_button, str(guide.get("id", "")) == selected_guide_id, str(guide.get("guide_type", AssetGuide.SAMPLER_SPINE)))
	guide_button.pressed.connect(_select_guide.bind(asset_id, str(guide.get("id", ""))))
	guide_row.add_child(guide_button)


func _guide_display_name(asset: Dictionary, guide: Dictionary) -> String:
	var target_component := _get_component(asset, str(guide.get("scope", {}).get("component_id", "")))
	var component_name := str(target_component.get("name", "Unassigned"))
	return AssetGuide.outliner_name(guide, component_name)


func _strikethrough_text(text: String) -> String:
	var result := ""
	var strike_mark := String.chr(0x0336)
	for character in text:
		result += character + strike_mark
	return result


func _select_asset(asset_id: String) -> void:
	_stop_guide_draw_state()
	_set_active_context_command("")
	var was_selected := selected_asset_id == asset_id and selected_component_id.is_empty() and selected_guide_id.is_empty()
	active_module = "Create"
	var selected_asset := _get_asset(asset_id)
	_set_create_submodule_context(_asset_type_create_submodule(_asset_type(selected_asset)))
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_guide_id = ""
	active_state = ""
	canvas_view.set_interaction_state("")
	if was_selected:
		_set_outliner_asset_expanded(asset_id, not bool(expanded_assets.get(asset_id, false)))
	else:
		_set_outliner_asset_expanded(asset_id, true)
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _open_component_dialog(asset_id: String, anchor: Control) -> void:
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_guide_id = ""
	component_draw_mode_menu.set_meta("asset_id", asset_id)
	component_draw_mode_menu.set_meta("parent_component_id", "")
	component_draw_mode_menu.position = Vector2i(anchor.global_position + Vector2(0.0, anchor.size.y))
	component_draw_mode_menu.popup()


func _open_component_add_menu(asset_id: String, parent_component_id: String, anchor: Control) -> void:
	if _get_component(_get_asset(asset_id), parent_component_id).is_empty():
		return
	component_add_menu.set_meta("asset_id", asset_id)
	component_add_menu.set_meta("parent_component_id", parent_component_id)
	component_add_reference_menu.clear()
	for source_asset in assets:
		if _asset_type(source_asset) != "symbols" or str(source_asset.get("id", "")) == asset_id:
			continue
		component_add_reference_menu.add_item(str(source_asset.get("name", "Symbol")), component_add_reference_menu.item_count)
		component_add_reference_menu.set_item_metadata(component_add_reference_menu.item_count - 1, str(source_asset.get("id", "")))
	component_add_menu.position = Vector2i(anchor.global_position + Vector2(0.0, anchor.size.y))
	component_add_menu.popup()


func _on_component_add_child_selected(index: int) -> void:
	if index < 0 or index >= DRAW_MODES.size():
		return
	_open_component_semantic_dialog(str(component_add_menu.get_meta("asset_id", "")), str(component_add_menu.get_meta("parent_component_id", "")), DRAW_MODES[index])


func _on_component_add_guide_selected(index: int) -> void:
	var guide_types := [AssetGuide.SAMPLE, AssetGuide.MOTION, AssetGuide.FLOW, AssetGuide.CUT]
	if index < 0 or index >= guide_types.size():
		return
	_create_guide(str(component_add_menu.get_meta("asset_id", "")), str(component_add_menu.get_meta("parent_component_id", "")), str(guide_types[index]))


func _on_component_add_reference_selected(index: int) -> void:
	var item_index := component_add_reference_menu.get_item_index(index)
	var source_asset := _get_asset(str(component_add_reference_menu.get_item_metadata(item_index)))
	var asset := _get_asset(str(component_add_menu.get_meta("asset_id", "")))
	if source_asset.is_empty() or asset.is_empty():
		return
	_open_component_semantic_dialog(str(asset.get("id", "")), str(component_add_menu.get_meta("parent_component_id", "")), "reference", str(source_asset.get("id", "")))


func _on_component_draw_mode_selected(index: int) -> void:
	if index < 0 or index >= DRAW_MODES.size():
		return
	_open_component_semantic_dialog(str(component_draw_mode_menu.get_meta("asset_id", "")), str(component_draw_mode_menu.get_meta("parent_component_id", "")), DRAW_MODES[index])


func _draw_mode_display_name(draw_mode: String) -> String:
	if draw_mode == "ribbon":
		return "Ribbon"
	if draw_mode == "primitive":
		return "Primitive"
	return "Closed Loop"


func _open_component_semantic_dialog(asset_id: String, parent_component_id: String, draw_mode: String, source_asset_id := "") -> void:
	var asset := _get_asset(asset_id)
	if asset.is_empty() or not bool(semantic_registry.get("valid", false)):
		_show_status_message("Semantic Registry is unavailable.")
		return
	var used_keys: Array[String] = []
	for component in asset.get("components", []):
		var key := str(component.get("semantic_key", ""))
		if not key.is_empty():
			used_keys.append(key)
	component_dialog.set_meta("asset_id", asset_id)
	component_dialog.set_meta("parent_component_id", parent_component_id)
	component_dialog.set_meta("draw_mode", draw_mode)
	component_dialog.set_meta("source_asset_id", source_asset_id)
	component_dialog.title = "Add %s" % ("Symbol Reference" if draw_mode == "reference" else "%s Component" % _draw_mode_display_name(draw_mode))
	component_semantic_picker.set_prompt("Select a Semantic Key")
	component_semantic_picker.configure(semantic_registry.get("semantics", []), "", used_keys)
	component_dialog.get_ok_button().disabled = true
	canvas_view.set_navigation_locked(true)
	component_dialog.popup_centered()
	component_semantic_picker.call_deferred("focus_search")


func _on_component_dialog_semantic_selected(_key: String) -> void:
	component_dialog.get_ok_button().disabled = component_semantic_picker.selected_key.is_empty()


func _on_component_dialog_canceled() -> void:
	canvas_view.set_navigation_locked(false)


func _open_guide_dialog(asset_id: String, component_id: String) -> void:
	var component := _get_component(_get_asset(asset_id), component_id)
	if component.is_empty():
		return
	selected_asset_id = asset_id
	selected_component_id = component_id
	selected_guide_id = ""
	guide_name_input.text = ""
	guide_dialog.set_meta("asset_id", asset_id)
	guide_dialog.set_meta("component_id", component_id)
	_create_guide(asset_id, component_id, AssetGuide.FLOW)


func _submit_guide_name(_submitted_text: String) -> void:
	_confirm_guide_creation()


func _on_guide_dialog_canceled() -> void:
	canvas_view.set_navigation_locked(false)


func _confirm_guide_creation() -> void:
	_create_guide(str(guide_dialog.get_meta("asset_id", "")), str(guide_dialog.get_meta("component_id", "")), AssetGuide.FLOW, guide_name_input.text.strip_edges())


func _create_guide(asset_id: String, component_id: String, guide_type: String, legacy_name := "") -> void:
	var asset := _get_asset(asset_id)
	if asset.is_empty() or _get_component(asset, component_id).is_empty():
		guide_dialog.hide()
		canvas_view.set_navigation_locked(false)
		return
	_record_direct_change()
	var guide_name := legacy_name.strip_edges()
	if guide_name.is_empty():
		guide_name = _next_default_guide_name(asset, guide_type)
	var guide_id := "guide_%d" % next_guide_id
	next_guide_id += 1
	var guide_ordinal := ComponentHierarchy.next_guide_ordinal(asset, component_id, guide_type)
	var guide := AssetGuide.create(guide_id, guide_name, guide_type, component_id, guide_ordinal)
	if not asset.get("guides", []) is Array:
		asset["guides"] = []
	asset["guides"].append(guide)
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_guide_id = guide_id
	active_state = ""
	active_draw_tool = ""
	_set_outliner_asset_expanded(asset_id, true)
	guide_dialog.hide()
	canvas_view.set_navigation_locked(false)
	_show_status_message("Created %s." % _guide_display_name(asset, guide))
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _duplicate_selected_guide() -> void:
	var asset := _get_asset(selected_asset_id)
	var source := _get_guide(asset, selected_guide_id)
	if asset.is_empty() or source.is_empty():
		return
	_record_direct_change()
	var duplicate := _duplicate_guide_record(source, asset)
	asset["guides"].append(duplicate)
	selected_guide_id = str(duplicate.get("id", ""))
	selected_component_id = ""
	active_state = ""
	_set_outliner_asset_expanded(selected_asset_id, true)
	_show_status_message("Duplicated %s." % _guide_display_name(asset, duplicate))
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _on_component_context_menu_selected(action_id: int) -> void:
	if not is_instance_valid(component_context_menu):
		return
	var asset_id := str(component_context_menu.get_meta("asset_id", ""))
	var component_id := str(component_context_menu.get_meta("component_id", ""))
	if action_id == 3:
		_detach_component(asset_id, component_id)
		return
	var mirror_mode := "none" if action_id == 0 else "keep_orientation" if action_id == 1 else "flip_orientation"
	if mirror_mode == "none" or mirror_mode == "keep_orientation" or mirror_mode == "flip_orientation":
		_duplicate_component(asset_id, component_id, mirror_mode)




func _duplicate_component(asset_id: String, component_id: String, mirror_mode := "none") -> void:
	var asset := _get_asset(asset_id)
	var source := _get_component(asset, component_id)
	if asset.is_empty() or source.is_empty():
		return
	var source_tree: Array[Dictionary] = [source]
	for descendant in ComponentHierarchy.descendants(asset, component_id):
		source_tree.append(descendant)
	var semantic_map: Dictionary = {}
	var unresolved: Array[String] = []
	var reserved: Dictionary = {}
	for source_node in source_tree:
		var source_id := str(source_node.get("id", ""))
		var mirrored_key := SemanticRegistry.mirror_key(str(source_node.get("semantic_key", "")))
		if not mirrored_key.is_empty() and not SemanticRegistry.key_used_by_other(asset, mirrored_key) and not reserved.has(mirrored_key):
			semantic_map[source_id] = mirrored_key
			reserved[mirrored_key] = true
		else:
			unresolved.append(source_id)
	pending_component_duplicate = {
		"asset_id": asset_id,
		"component_id": component_id,
		"mirror_mode": mirror_mode,
		"source_ids": source_tree.map(func(component: Dictionary): return str(component.get("id", ""))),
		"semantic_map": semantic_map,
		"unresolved": unresolved
	}
	if unresolved.is_empty():
		_commit_pending_component_duplicate()
	else:
		_open_next_duplicate_semantic_picker()


func _open_next_duplicate_semantic_picker() -> void:
	var asset := _get_asset(str(pending_component_duplicate.get("asset_id", "")))
	var unresolved: Array = pending_component_duplicate.get("unresolved", [])
	if asset.is_empty() or unresolved.is_empty():
		return
	var source := _get_component(asset, str(unresolved[0]))
	var excluded: Array[String] = []
	for component in asset.get("components", []):
		var key := str(component.get("semantic_key", ""))
		if not key.is_empty():
			excluded.append(key)
	for key in pending_component_duplicate.get("semantic_map", {}).values():
		excluded.append(str(key))
	duplicate_semantic_dialog.title = "Duplicate %s" % _normalized_component_name(source)
	duplicate_semantic_picker.set_prompt("Select a Semantic Key for the duplicate")
	duplicate_semantic_picker.configure(semantic_registry.get("semantics", []), "", excluded)
	duplicate_semantic_dialog.get_ok_button().disabled = true
	if duplicate_semantic_dialog.is_inside_tree():
		duplicate_semantic_dialog.popup_centered()
		duplicate_semantic_picker.call_deferred("focus_search")


func _confirm_duplicate_semantic() -> void:
	var unresolved: Array = pending_component_duplicate.get("unresolved", [])
	var key := duplicate_semantic_picker.selected_key
	if unresolved.is_empty() or key.is_empty():
		return
	pending_component_duplicate["semantic_map"][str(unresolved.pop_front())] = key
	pending_component_duplicate["unresolved"] = unresolved
	if unresolved.is_empty():
		_commit_pending_component_duplicate()
	else:
		call_deferred("_open_next_duplicate_semantic_picker")


func _commit_pending_component_duplicate() -> void:
	var asset_id := str(pending_component_duplicate.get("asset_id", ""))
	var component_id := str(pending_component_duplicate.get("component_id", ""))
	var mirror_mode := str(pending_component_duplicate.get("mirror_mode", "none"))
	var asset := _get_asset(asset_id)
	var semantic_map: Dictionary = pending_component_duplicate.get("semantic_map", {})
	var source_tree: Array[Dictionary] = []
	for source_id in pending_component_duplicate.get("source_ids", []):
		var source_node := _get_component(asset, str(source_id))
		if source_node.is_empty() or not semantic_map.has(str(source_id)):
			pending_component_duplicate.clear()
			return
		source_tree.append(source_node)
	_record_direct_change()
	var id_map: Dictionary = {}
	for source_node in source_tree:
		var new_id := "component_%d" % next_component_id
		next_component_id += 1
		id_map[str(source_node.get("id", ""))] = new_id
	var duplicate_root: Dictionary = {}
	for source_node in source_tree:
		var source_node_id := str(source_node.get("id", ""))
		var duplicate := _duplicate_component_record(source_node, asset, str(id_map[source_node_id]))
		var semantic_key := str(semantic_map[source_node_id])
		duplicate["semantic_key"] = semantic_key
		duplicate["missing_semantic_source"] = ""
		duplicate["name"] = semantic_key
		var source_parent_id := str(source_node.get("parent_component_id", ""))
		duplicate["parent_component_id"] = str(id_map.get(source_parent_id, source_parent_id))
		if mirror_mode != "none" and source_node_id == component_id:
			duplicate["transform"] = _mirrored_duplicate_transform(duplicate, mirror_mode)
		asset["components"].append(duplicate)
		if source_node_id == component_id:
			duplicate_root = duplicate
	pending_component_duplicate.clear()
	selected_asset_id = asset_id
	selected_component_id = str(duplicate_root.get("id", ""))
	selected_guide_id = ""
	selected_point_id = ""
	selected_point_ids.clear()
	selected_edge_id = ""
	active_state = ""
	_set_outliner_asset_expanded(asset_id, true)
	_show_status_message("Duplicated %s subtree." % str(duplicate_root.get("name", "Component")) if source_tree.size() > 1 else "Duplicated %s." % str(duplicate_root.get("name", "Component")))
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _mirrored_duplicate_transform(component: Dictionary, mirror_mode: String) -> Dictionary:
	var transform: Dictionary = component.get("transform", _default_component_transform()).duplicate(true)
	if mirror_mode == "flip_orientation":
		var position: Vector2 = transform.get("position", Vector2.ZERO)
		position.x = -position.x
		transform["position"] = position
		transform["rotation"] = -float(transform.get("rotation", 0.0))
		var scale: Vector2 = transform.get("scale", Vector2.ONE)
		scale.x = -scale.x
		transform["scale"] = scale
	else:
		# Keep the component orientation while reflecting its visible placement.
		# Applying this to every local level mirrors the complete subtree.
		var visual_center := _component_visual_center_in_parent_space(component)
		var position: Vector2 = transform.get("position", Vector2.ZERO)
		position.x -= visual_center.x * 2.0
		transform["position"] = position
	return transform
func _duplicate_component_record(source: Dictionary, asset: Dictionary, forced_id := "") -> Dictionary:
	var duplicate := source.duplicate(true)
	duplicate["id"] = forced_id if not forced_id.is_empty() else "component_%d" % next_component_id
	if forced_id.is_empty():
		next_component_id += 1
	duplicate["name"] = str(source.get("name", "Component"))
	# The duplicated Component stays beside its source: same Parent, no copied
	# descendants, and no copied Guides.
	duplicate["parent_component_id"] = str(source.get("parent_component_id", ""))
	var point_id_map: Dictionary = {}
	var new_points: Array = []
	for point in source.get("points", []):
		var point_copy: Dictionary = point.duplicate(true)
		var new_point_id := BezierTopology.next_id(new_points, "point")
		point_id_map[str(point.get("id", ""))] = new_point_id
		point_copy["id"] = new_point_id
		new_points.append(point_copy)
	var edge_id_map: Dictionary = {}
	var new_edges: Array = []
	for edge in source.get("edges", []):
		var edge_copy: Dictionary = edge.duplicate(true)
		var new_edge_id := BezierTopology.next_id(new_edges, "edge")
		edge_id_map[str(edge.get("id", ""))] = new_edge_id
		edge_copy["id"] = new_edge_id
		edge_copy["start_point_id"] = str(point_id_map.get(str(edge.get("start_point_id", "")), ""))
		edge_copy["end_point_id"] = str(point_id_map.get(str(edge.get("end_point_id", "")), ""))
		new_edges.append(edge_copy)
	var new_chains: Array = []
	for chain in source.get("chains", []):
		var chain_copy: Dictionary = chain.duplicate(true)
		chain_copy["id"] = BezierTopology.next_id(new_chains, "chain")
		var remapped_points: Array = []
		for point_id in chain.get("point_ids", []):
			remapped_points.append(str(point_id_map.get(str(point_id), "")))
		var remapped_edges: Array = []
		for edge_id in chain.get("edge_ids", []):
			remapped_edges.append(str(edge_id_map.get(str(edge_id), "")))
		chain_copy["point_ids"] = remapped_points
		chain_copy["edge_ids"] = remapped_edges
		new_chains.append(chain_copy)
	duplicate["points"] = new_points
	duplicate["edges"] = new_edges
	duplicate["chains"] = new_chains
	BezierGeometry.resolve_auto_handles(new_points, new_chains)
	return duplicate




func _component_visual_center_in_parent_space(component: Dictionary) -> Vector2:
	var points: Array = component.get("points", [])
	if points.is_empty() and PrimitiveGeometryService.has_circle(component):
		var primitive_contour := PrimitiveGeometryService.contour(component)
		if not primitive_contour.is_empty():
			var primitive_minimum := Vector2(INF, INF)
			var primitive_maximum := Vector2(-INF, -INF)
			for primitive_point in primitive_contour:
				primitive_minimum.x = minf(primitive_minimum.x, primitive_point.x)
				primitive_minimum.y = minf(primitive_minimum.y, primitive_point.y)
				primitive_maximum.x = maxf(primitive_maximum.x, primitive_point.x)
				primitive_maximum.y = maxf(primitive_maximum.y, primitive_point.y)
			return ComponentHierarchy.local_transform(component.get("transform", {})) * ((primitive_minimum + primitive_maximum) * 0.5)
	if points.is_empty():
		return Vector2(component.get("transform", {}).get("position", Vector2.ZERO))
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point in points:
		var position: Vector2 = point.get("position", Vector2.ZERO)
		minimum.x = minf(minimum.x, position.x)
		minimum.y = minf(minimum.y, position.y)
		maximum.x = maxf(maximum.x, position.x)
		maximum.y = maxf(maximum.y, position.y)
	var local_center := (minimum + maximum) * 0.5
	return ComponentHierarchy.local_transform(component.get("transform", {})) * local_center


func _duplicate_guide_record(source: Dictionary, asset: Dictionary) -> Dictionary:
	var duplicate := source.duplicate(true)
	var source_id := str(source.get("id", ""))
	var guide_id := "guide_%d" % next_guide_id
	next_guide_id += 1
	duplicate["id"] = guide_id
	duplicate["ordinal"] = ComponentHierarchy.next_guide_ordinal(asset, str(source.get("scope", {}).get("component_id", "")), str(source.get("guide_type", AssetGuide.SAMPLE)))
	var base_name := str(source.get("name", AssetGuide.display_name(str(source.get("guide_type", AssetGuide.SAMPLER_SPINE))))) + " Copy"
	var candidate := base_name
	var suffix := 2
	var existing_names: Dictionary = {}
	for guide in asset.get("guides", []):
		existing_names[str(guide.get("name", "")).to_lower()] = true
	while existing_names.has(candidate.to_lower()):
		candidate = "%s %d" % [base_name, suffix]
		suffix += 1
	duplicate["name"] = candidate
	var point_id_map: Dictionary = {}
	var new_points: Array = []
	for point in source.get("points", []):
		var point_copy: Dictionary = point.duplicate(true)
		var old_point_id := str(point.get("id", ""))
		var new_point_id := BezierTopology.next_id(new_points, "point")
		point_id_map[old_point_id] = new_point_id
		point_copy["id"] = new_point_id
		new_points.append(point_copy)
	var edge_id_map: Dictionary = {}
	var new_edges: Array = []
	for edge in source.get("edges", []):
		var edge_copy: Dictionary = edge.duplicate(true)
		var old_edge_id := str(edge.get("id", ""))
		var new_edge_id := BezierTopology.next_id(new_edges, "edge")
		edge_id_map[old_edge_id] = new_edge_id
		edge_copy["id"] = new_edge_id
		edge_copy["start_point_id"] = str(point_id_map.get(str(edge.get("start_point_id", "")), ""))
		edge_copy["end_point_id"] = str(point_id_map.get(str(edge.get("end_point_id", "")), ""))
		new_edges.append(edge_copy)
	var new_chains: Array = []
	for chain in source.get("chains", []):
		var chain_copy: Dictionary = chain.duplicate(true)
		chain_copy["id"] = BezierTopology.next_id(new_chains, "chain")
		var remapped_points: Array = []
		for point_id in chain.get("point_ids", []):
			remapped_points.append(str(point_id_map.get(str(point_id), "")))
		var remapped_edges: Array = []
		for edge_id in chain.get("edge_ids", []):
			remapped_edges.append(str(edge_id_map.get(str(edge_id), "")))
		chain_copy["point_ids"] = remapped_points
		chain_copy["edge_ids"] = remapped_edges
		new_chains.append(chain_copy)
	duplicate["points"] = new_points
	duplicate["edges"] = new_edges
	duplicate["chains"] = new_chains
	return AssetGuide.normalize(duplicate)


func _confirm_component_creation() -> void:
	var asset_id := str(component_dialog.get_meta("asset_id", ""))
	var asset := _get_asset(asset_id)
	if asset.is_empty():
		component_dialog.hide()
		canvas_view.set_navigation_locked(false)
		return
	var semantic_key := component_semantic_picker.selected_key
	if not SemanticRegistry.contains(semantic_registry, semantic_key) or SemanticRegistry.key_used_by_other(asset, semantic_key):
		_show_status_message("Select one unused Semantic Key.")
		return
	_record_direct_change()
	var component_id := "component_%d" % next_component_id
	next_component_id += 1
	var draw_mode := str(component_dialog.get_meta("draw_mode", "closed_loop"))
	var is_reference := draw_mode == "reference"
	var parent_component_id := str(component_dialog.get_meta("parent_component_id", ""))
	if not parent_component_id.is_empty() and _get_component(asset, parent_component_id).is_empty():
		parent_component_id = ""
	var component_transform := _default_component_transform()
	if not parent_component_id.is_empty():
		var parent_component := _get_component(asset, parent_component_id)
		var parent_transform := _deserialize_transform(parent_component.get("transform", {}))
		var inherited_pivot: Vector2 = parent_transform.get("pivot", Vector2.ZERO)
		# Local child position is the Parent-local point that maps to the Parent pivot.
		component_transform["position"] = inherited_pivot
		component_transform["pivot"] = inherited_pivot
	asset["components"].append({
		"id": component_id,
		"type": "reference" if is_reference else "component",
		"name": semantic_key,
		"semantic_key": semantic_key,
		"source_asset_id": str(component_dialog.get_meta("source_asset_id", "")) if is_reference else "",
		"parent_component_id": parent_component_id,
		"points": [],
		"edges": [],
		"chains": [],
		"transform": component_transform,
		"visibility": true,
		"z_index": 0,
		"draw_mode": draw_mode if draw_mode in DRAW_MODES else "closed_loop",
		"topology_role": "outer",
		"geometry_source": "primitive" if draw_mode == "primitive" else "bezier",
		"primitive": {},
		"contour_width_px": DEFAULT_CONTOUR_WIDTH_PX,
		"ribbon_width_px": DEFAULT_RIBBON_WIDTH_PX,
		"catch_parent_component_id": "",
		"show_point_numbers": false
	})
	selected_asset_id = asset_id
	selected_component_id = component_id
	selected_guide_id = ""
	active_state = ""
	_set_outliner_asset_expanded(asset_id, true)
	component_dialog.hide()
	canvas_view.set_navigation_locked(false)
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _select_component(asset_id: String, component_id: String, focus_outliner := false) -> void:
	_stop_guide_draw_state()
	_set_active_context_command("")
	active_module = "Create"
	# Keep the asset's Create database view when selecting a component.  Passing
	# the generic "Asset" label here normalizes to Character and hides Symbols
	# (and the other non-character asset types) from the Outliner.
	_set_create_submodule_context(_asset_type_create_submodule(_asset_type(_get_asset(asset_id))))
	selected_asset_id = asset_id
	selected_component_id = component_id
	selected_guide_id = ""
	selected_edge_id = ""
	selected_point_id = ""
	selected_point_ids.clear()
	outliner_component_navigation_active = focus_outliner
	active_state = ""
	canvas_view.set_interaction_state("")
	_set_outliner_asset_expanded(asset_id, true)
	_render_outliner()
	_render_inspector()
	_render_canvas_context()
	if is_instance_valid(canvas_view):
		canvas_view.grab_focus()


func _select_guide(asset_id: String, guide_id: String) -> void:
	_stop_guide_draw_state()
	_set_active_context_command("")
	var guide := _get_guide(_get_asset(asset_id), guide_id)
	if guide.is_empty():
		return
	if active_module == "Mesh" and active_geometry_submodule == "Sampling":
		var parent_component_id := str(guide.get("scope", {}).get("component_id", ""))
		if not _get_component(_get_asset(asset_id), parent_component_id).is_empty():
			selected_asset_id = asset_id
			selected_component_id = parent_component_id
			selected_guide_id = guide_id
			selected_sampling_input_id = guide_id
			selected_sampling_input_kind = "guide"
			selected_edge_id = ""
			selected_point_id = ""
			selected_point_ids.clear()
			active_state = ""
			_set_outliner_asset_expanded(asset_id, true)
			_render_outliner()
			_render_inspector()
			_render_canvas_context()
			return
	active_module = "Create"
	_set_create_submodule_context(_asset_type_create_submodule(_asset_type(_get_asset(asset_id))))
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_guide_id = guide_id
	selected_sampling_input_id = ""
	selected_sampling_input_kind = ""
	selected_edge_id = ""
	selected_point_id = ""
	selected_point_ids.clear()
	active_state = ""
	_set_outliner_asset_expanded(asset_id, true)
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _delete_selected_component() -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty() or selected_component_id.is_empty():
		return
	var component := _get_component(asset, selected_component_id)
	if component.is_empty():
		return
	pending_component_remove_asset_id = selected_asset_id
	pending_component_remove_id = selected_component_id
	var removed_component_ids: Dictionary = {selected_component_id: true}
	for descendant in ComponentHierarchy.descendants(asset, selected_component_id):
		removed_component_ids[str(descendant.get("id", ""))] = true
	var removed_guide_count := 0
	for guide in asset.get("guides", []):
		if removed_component_ids.has(str(guide.get("scope", {}).get("component_id", ""))):
			removed_guide_count += 1
	var component_count := removed_component_ids.size()
	var description := "Delete Component ‘%s’" % str(component.get("name", "Component"))
	if component_count > 1:
		description += " and %d Child Components" % (component_count - 1)
	if removed_guide_count > 0:
		description += " plus %d Guide%s" % [removed_guide_count, "s" if removed_guide_count != 1 else ""]
	description += "? This cannot be undone except through Undo."
	if is_instance_valid(component_remove_dialog):
		component_remove_dialog.dialog_text = description
		component_remove_dialog.popup_centered()
	else:
		_confirm_component_deletion()


func _confirm_component_deletion() -> void:
	var asset := _get_asset(pending_component_remove_asset_id)
	var component_id := pending_component_remove_id
	pending_component_remove_asset_id = ""
	pending_component_remove_id = ""
	if asset.is_empty() or component_id.is_empty() or _get_component(asset, component_id).is_empty():
		return
	var removed_component_ids: Dictionary = {component_id: true}
	for descendant in ComponentHierarchy.descendants(asset, component_id):
		removed_component_ids[str(descendant.get("id", ""))] = true
	_record_direct_change()
	var surviving_components: Array = []
	for existing_component in asset.get("components", []):
		if not removed_component_ids.has(str(existing_component.get("id", ""))):
			surviving_components.append(existing_component)
	asset["components"] = surviving_components
	var surviving_guides: Array = []
	for guide in asset.get("guides", []):
		if not removed_component_ids.has(str(guide.get("scope", {}).get("component_id", ""))):
			surviving_guides.append(guide)
	asset["guides"] = surviving_guides
	for surviving_component in surviving_components:
		if removed_component_ids.has(str(surviving_component.get("catch_parent_component_id", ""))):
			surviving_component["catch_parent_component_id"] = ""
	selected_component_id = ""
	selected_guide_id = ""
	active_state = ""
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _delete_current_outliner_selection() -> void:
	if active_module == "Style" and active_style_submodule == "Weighting":
		if not selected_weighting_style_id.is_empty():
			_delete_selected_weighting_style()
		return
	if not selected_guide_id.is_empty():
		_delete_selected_guide()
	elif not selected_component_id.is_empty():
		_delete_selected_component()
	elif not selected_asset_id.is_empty():
		_delete_selected_asset()


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
	asset_camera_states.erase(selected_asset_id)
	if canvas_camera_asset_id == selected_asset_id:
		canvas_camera_asset_id = ""
	selected_asset_id = ""
	selected_component_id = ""
	active_state = ""
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _style_outliner_button(button: Button, selected: bool, topology_role := "outer") -> void:
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
	var text_color := Color("#ef6c78") if topology_role == "hole" else Color("#16181d") if selected else Color("#ffffff")
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", Color("#ef6c78") if topology_role == "hole" else Color("#16181d") if selected else Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ef6c78") if topology_role == "hole" else Color("#16181d"))
	button.add_theme_color_override("font_focus_color", text_color)


func _style_guide_outliner_button(button: Button, selected: bool, guide_type := AssetGuide.SAMPLER_SPINE) -> void:
	var guide_color := AssetGuide.color(guide_type)
	var normal := StyleBoxFlat.new()
	normal.bg_color = guide_color if selected else guide_color.darkened(0.55)
	normal.border_color = guide_color.lightened(0.2) if selected else guide_color.darkened(0.35)
	normal.set_border_width_all(1)
	var hover := normal.duplicate()
	hover.bg_color = guide_color.lightened(0.15) if selected else guide_color.darkened(0.4)
	var pressed := normal.duplicate()
	pressed.bg_color = guide_color.darkened(0.1) if selected else guide_color.darkened(0.3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	var selected_text_color := Color("#16181d") if guide_color.get_luminance() > 0.55 else Color("#f4f7ff")
	button.add_theme_color_override("font_color", selected_text_color if selected else guide_color.lightened(0.35))
	button.add_theme_color_override("font_hover_color", selected_text_color if selected else guide_color.lightened(0.55))
	button.add_theme_color_override("font_pressed_color", selected_text_color)
	button.add_theme_color_override("font_focus_color", selected_text_color if selected else guide_color.lightened(0.35))


func _render_guide_inspector(asset: Dictionary, guide: Dictionary) -> void:
	inspector_content.add_child(_create_inspector_section("Guide"))
	if guide.is_empty():
		inspector_content.add_child(_create_inspector_field_label("Guide not found."))
		return
	inspector_content.add_child(_create_inspector_field_label("Name"))
	inspector_content.add_child(_create_inspector_field_label(_guide_display_name(asset, guide)))
	inspector_content.add_child(_create_inspector_field_label("Type"))
	var type_option := OptionButton.new()
	type_option.add_item("Flow")
	type_option.set_item_metadata(0, AssetGuide.BODY_FLOW)
	type_option.add_item("Sample")
	type_option.set_item_metadata(1, AssetGuide.SAMPLER_SPINE)
	type_option.add_item("Motion")
	type_option.set_item_metadata(2, AssetGuide.ANIMATION_SPINE)
	var guide_type := str(guide.get("guide_type", AssetGuide.BODY_FLOW))
	for type_index in range(type_option.item_count):
		if str(type_option.get_item_metadata(type_index)) == guide_type:
			type_option.select(type_index)
			break
	type_option.item_selected.connect(_on_guide_type_selected.bind(type_option))
	inspector_content.add_child(type_option)
	inspector_content.add_child(_create_inspector_field_label("Parent Component"))
	var target_id := str(guide.get("scope", {}).get("component_id", ""))
	var target_name := "Missing Component"
	for component in asset.get("components", []):
		if str(component.get("type", "component")) == "guide":
			continue
		if str(component.get("id", "")) == target_id:
			target_name = str(component.get("name", "Component"))
	inspector_content.add_child(_create_inspector_field_label(target_name))
	var visible_toggle := CheckBox.new()
	visible_toggle.text = "Visible"
	visible_toggle.button_pressed = bool(guide.get("visibility", true))
	visible_toggle.toggled.connect(_on_selected_guide_visibility_changed)
	inspector_content.add_child(visible_toggle)
	inspector_content.add_child(_create_inspector_section("Topology"))
	inspector_content.add_child(_create_inspector_field_label("Open Spine · %d Points" % guide.get("points", []).size()))
	var status := "Ready" if AssetGuide.validation_issues(guide).is_empty() else "Ready to draw" if guide.get("points", []).is_empty() else "Invalid"
	if _get_component(asset, target_id).is_empty():
		status = "Unassigned"
	inspector_content.add_child(_create_inspector_field_label("Status: %s" % status))
	var delete_button := Button.new()
	delete_button.text = "Delete Guide"
	delete_button.focus_mode = Control.FOCUS_NONE
	delete_button.pressed.connect(_delete_selected_guide)
	inspector_content.add_child(delete_button)


func _render_weighting_inspector() -> void:
	inspector_content.add_child(_create_inspector_section("Weighting"))
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		inspector_content.add_child(_create_inspector_field_label("Select a Component to create or inspect Weighting Styles."))
		return
	inspector_content.add_child(_create_inspector_field_label(str(component.get("name", "Component"))))
	var mesh_status := _component_mesh_status(selected_asset_id, selected_component_id, component)
	var mesh_label := _create_inspector_field_label("Component Mesh: %s" % mesh_status)
	mesh_label.add_theme_color_override("font_color", Color("#75b88a") if mesh_status == "Ready" else Color("#ef8354"))
	inspector_content.add_child(mesh_label)
	var style := _weighting_style(selected_asset_id, selected_component_id, selected_weighting_style_id)
	if style.is_empty():
		inspector_content.add_child(_create_inspector_field_label("Create or select a Weighting Style."))
		return
	inspector_content.add_child(_create_inspector_field_label("Name"))
	var name_editor := _create_name_editor(str(style.get("name", "Weighting Style")), "Weighting Style name")
	name_editor.text_submitted.connect(_rename_weighting_style)
	name_editor.focus_exited.connect(func() -> void: _rename_weighting_style(name_editor.text))
	inspector_content.add_child(name_editor)
	inspector_content.add_child(_create_inspector_section("Method"))
	var method_option := OptionButton.new()
	for method_data in [["Uniform", WeightingService.UNIFORM], ["Axis Gradient", WeightingService.AXIS_GRADIENT]]:
		method_option.add_item(str(method_data[0]))
		method_option.set_item_metadata(method_option.item_count - 1, str(method_data[1]))
		if str(style.get("method", "")) == str(method_data[1]):
			method_option.select(method_option.item_count - 1)
	method_option.item_selected.connect(_on_weighting_method_selected.bind(method_option))
	inspector_content.add_child(method_option)
	inspector_content.add_child(_create_inspector_section("Parameters"))
	if str(style.get("method", "")) == WeightingService.AXIS_GRADIENT:
		inspector_content.add_child(_create_inspector_field_label("Direction"))
		var direction_option := OptionButton.new()
		for direction_data in [["Bottom → Top", WeightingService.BOTTOM_TO_TOP], ["Top → Bottom", WeightingService.TOP_TO_BOTTOM], ["Left → Right", WeightingService.LEFT_TO_RIGHT], ["Right → Left", WeightingService.RIGHT_TO_LEFT]]:
			direction_option.add_item(str(direction_data[0]))
			direction_option.set_item_metadata(direction_option.item_count - 1, str(direction_data[1]))
			if str(style.get("parameters", {}).get("direction", "")) == str(direction_data[1]):
				direction_option.select(direction_option.item_count - 1)
		direction_option.item_selected.connect(_on_weighting_direction_selected.bind(direction_option))
		inspector_content.add_child(direction_option)
		inspector_content.add_child(_create_inspector_field_label("Curve"))
		var curve_option := OptionButton.new()
		for curve_data in [["Linear", WeightingService.LINEAR], ["Ease In", WeightingService.EASE_IN], ["Ease Out", WeightingService.EASE_OUT], ["Smooth", WeightingService.SMOOTH]]:
			curve_option.add_item(str(curve_data[0]))
			curve_option.set_item_metadata(curve_option.item_count - 1, str(curve_data[1]))
			if str(style.get("parameters", {}).get("curve", "")) == str(curve_data[1]):
				curve_option.select(curve_option.item_count - 1)
		curve_option.item_selected.connect(_on_weighting_curve_selected.bind(curve_option))
		inspector_content.add_child(curve_option)
		var invert := CheckBox.new()
		invert.text = "Invert"
		invert.button_pressed = bool(style.get("parameters", {}).get("invert", false))
		invert.toggled.connect(_on_weighting_invert_changed)
		inspector_content.add_child(invert)
	inspector_content.add_child(_create_inspector_field_label("Strength"))
	var strength := SpinBox.new()
	strength.min_value = 0.0
	strength.max_value = 1.0
	strength.step = 0.01
	strength.set_value_no_signal(float(style.get("parameters", {}).get("strength", 1.0)))
	strength.value_changed.connect(_on_weighting_strength_changed)
	inspector_content.add_child(strength)
	var status := _weighting_status(selected_asset_id, selected_component_id, component, style)
	inspector_content.add_child(_create_inspector_section("Result"))
	inspector_content.add_child(_create_inspector_field_label("Status: %s" % status))
	var result: Dictionary = weighting_preview if weighting_preview_key == _weighting_preview_id(selected_asset_id, selected_component_id, selected_weighting_style_id) else style.get("bake", {})
	if not result.is_empty():
		inspector_content.add_child(_create_inspector_field_label("Vertices: %d" % int(result.get("weight_count", 0))))
		inspector_content.add_child(_create_inspector_field_label("Range: %.2f → %.2f" % [float(result.get("minimum_weight", 0.0)), float(result.get("maximum_weight", 0.0))]))
	var actions := HBoxContainer.new()
	var generate_button := Button.new()
	generate_button.text = "Generate"
	generate_button.disabled = mesh_status != "Ready"
	generate_button.pressed.connect(_generate_weighting_preview)
	actions.add_child(generate_button)
	var bake_button := Button.new()
	bake_button.text = "Bake"
	bake_button.disabled = not WeightingService.result_matches(weighting_preview, _component_mesh_bake(selected_asset_id, selected_component_id), style)
	bake_button.pressed.connect(_bake_weighting_preview)
	actions.add_child(bake_button)
	inspector_content.add_child(actions)
	var delete_button := Button.new()
	delete_button.text = "Delete Weighting Style"
	delete_button.pressed.connect(_delete_selected_weighting_style)
	inspector_content.add_child(delete_button)


func _rename_weighting_style(new_name: String) -> void:
	var style := _weighting_style(selected_asset_id, selected_component_id, selected_weighting_style_id)
	var name := new_name.strip_edges()
	if style.is_empty() or name.is_empty() or name == str(style.get("name", "")):
		return
	_record_direct_change()
	style["name"] = name
	_render_outliner()


func _delete_selected_weighting_style() -> void:
	var document := _get_geometry_document(selected_asset_id, selected_component_id)
	if document.is_empty() or selected_weighting_style_id.is_empty():
		return
	var styles: Array = document.get("weighting", {}).get("styles", [])
	for style_index in range(styles.size()):
		if str(styles[style_index].get("id", "")) == selected_weighting_style_id:
			_record_direct_change()
			styles.remove_at(style_index)
			selected_weighting_style_id = ""
			weighting_preview = {}
			weighting_preview_key = ""
			_render_outliner()
			_render_inspector()
			_render_canvas_context()
			return


func _on_weighting_method_selected(index: int, option: OptionButton) -> void:
	if index < 0 or index >= option.item_count:
		return
	var style := _weighting_style(selected_asset_id, selected_component_id, selected_weighting_style_id)
	var method := str(option.get_item_metadata(index))
	if style.is_empty() or method == str(style.get("method", "")):
		return
	_record_direct_change()
	style["method"] = method
	style["parameters"] = WeightingService.default_parameters(method)
	_generate_weighting_preview()


func _on_weighting_direction_selected(index: int, option: OptionButton) -> void:
	_update_weighting_parameter("direction", str(option.get_item_metadata(index)))


func _on_weighting_curve_selected(index: int, option: OptionButton) -> void:
	_update_weighting_parameter("curve", str(option.get_item_metadata(index)))


func _on_weighting_invert_changed(enabled: bool) -> void:
	_update_weighting_parameter("invert", enabled)


func _on_weighting_strength_changed(value: float) -> void:
	_update_weighting_parameter("strength", clampf(value, 0.0, 1.0), true)


func _update_weighting_parameter(parameter_name: String, value, coalesced := false) -> void:
	var style := _weighting_style(selected_asset_id, selected_component_id, selected_weighting_style_id)
	if style.is_empty() or style.get("parameters", {}).get(parameter_name) == value:
		return
	if coalesced:
		_record_coalesced_change()
	else:
		_record_direct_change()
	style["parameters"][parameter_name] = value
	_generate_weighting_preview()


func _on_guide_type_selected(index: int, option: OptionButton) -> void:
	var asset := _get_asset(selected_asset_id)
	var guide := _get_guide(asset, selected_guide_id)
	if guide.is_empty() or index < 0 or index >= option.item_count:
		return
	var guide_type := str(option.get_item_metadata(index))
	if guide_type not in AssetGuide.VALID_TYPES or guide_type == str(guide.get("guide_type", "")):
		return
	_record_direct_change()
	var guide_ordinal := ComponentHierarchy.next_guide_ordinal(asset, str(guide.get("scope", {}).get("component_id", "")), guide_type)
	guide["guide_type"] = guide_type
	guide["ordinal"] = guide_ordinal
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _on_guide_target_selected(index: int, option: OptionButton) -> void:
	var asset := _get_asset(selected_asset_id)
	var guide := _get_guide(asset, selected_guide_id)
	if guide.is_empty() or not guide.get("points", []).is_empty() or index < 0 or index >= option.item_count:
		return
	var component_id := str(option.get_item_metadata(index))
	if str(guide.get("scope", {}).get("component_id", "")) == component_id:
		return
	_record_direct_change()
	var guide_ordinal := ComponentHierarchy.next_guide_ordinal(asset, component_id, str(guide.get("guide_type", AssetGuide.SAMPLE)))
	guide["scope"] = {"kind": "component", "component_id": component_id}
	guide["ordinal"] = guide_ordinal
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _on_selected_guide_visibility_changed(enabled: bool) -> void:
	var guide := _get_guide(_get_asset(selected_asset_id), selected_guide_id)
	if guide.is_empty() or bool(guide.get("visibility", true)) == enabled:
		return
	_record_direct_change()
	guide["visibility"] = enabled
	_render_outliner()
	_render_canvas_context()


func _on_guide_visibility_entry_changed(enabled: bool, asset_id: String, guide_id: String) -> void:
	var guide := _get_guide(_get_asset(asset_id), guide_id)
	if guide.is_empty() or bool(guide.get("visibility", true)) == enabled:
		return
	_record_direct_change()
	guide["visibility"] = enabled
	_render_outliner()
	_render_canvas_context()


func _delete_selected_guide() -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty() or selected_guide_id.is_empty():
		return
	pending_guide_remove_asset_id = selected_asset_id
	pending_guide_remove_id = selected_guide_id
	var guide := _get_guide(asset, selected_guide_id)
	if is_instance_valid(guide_remove_dialog):
		guide_remove_dialog.dialog_text = "Delete Guide ‘%s’?" % _guide_display_name(asset, guide)
		guide_remove_dialog.popup_centered()
	else:
		_confirm_guide_deletion()


func _confirm_guide_deletion() -> void:
	var asset := _get_asset(pending_guide_remove_asset_id)
	var guide_id := pending_guide_remove_id
	pending_guide_remove_asset_id = ""
	pending_guide_remove_id = ""
	if asset.is_empty() or guide_id.is_empty():
		return
	var guides: Array = asset.get("guides", [])
	for guide_index in range(guides.size()):
		if str(guides[guide_index].get("id", "")) == guide_id:
			_record_direct_change()
			guides.remove_at(guide_index)
			if selected_guide_id == guide_id:
				selected_guide_id = ""
			_render_outliner()
			_render_inspector()
			_render_canvas_context()
			return


func _get_sampling_input(asset: Dictionary, input_id: String, input_kind: String) -> Dictionary:
	if input_kind == "guide":
		return _get_guide(asset, input_id)
	if input_kind == "reference":
		for component in asset.get("components", []):
			if _is_reference_component(component) and str(component.get("id", "")) == input_id:
				return component
	return {}


func _sampling_input_display_name(asset: Dictionary, parent: Dictionary, input: Dictionary, input_kind: String) -> String:
	if input_kind == "guide":
		return _guide_display_name(asset, input)
	return _component_outliner_name(asset, input)


func _geometry_sampling_input_has_override(recipe: Dictionary, input_id: String) -> bool:
	return not input_id.is_empty() and recipe.get("parameters", {}).get("boundary_refinements", {}).has(input_id)


func _geometry_sampling_input_recipe(asset_id: String, component_id: String) -> Dictionary:
	return _geometry_sampling_input_recipe_for(asset_id, component_id, selected_sampling_input_id)


func _geometry_sampling_input_recipe_for(asset_id: String, component_id: String, input_id: String) -> Dictionary:
	var recipe := _geometry_sampling_recipe(asset_id, component_id)
	var result: Dictionary = recipe.duplicate(true)
	var refinement: Dictionary = recipe.get("parameters", {}).get("boundary_refinements", {}).get(input_id, {})
	var factor := clampf(float(refinement.get("factor", 1.0)), GeometrySamplingService.MIN_REFINEMENT_FACTOR, GeometrySamplingService.MAX_REFINEMENT_FACTOR)
	result["parameters"]["spacing"] = maxf(float(result["parameters"]["spacing"]) / factor, GeometrySamplingService.MIN_SPACING)
	result["parameters"]["density_factor"] = factor
	return result


func _set_geometry_sampling_refinement(input_id: String, factor: float) -> void:
	if selected_asset_id.is_empty() or selected_component_id.is_empty() or input_id.is_empty():
		return
	var normalized_factor := clampf(factor, GeometrySamplingService.MIN_REFINEMENT_FACTOR, GeometrySamplingService.MAX_REFINEMENT_FACTOR)
	var recipe := _geometry_sampling_recipe(selected_asset_id, selected_component_id)
	var current_factor := float(recipe.get("parameters", {}).get("boundary_refinements", {}).get(input_id, {}).get("factor", 1.0))
	var had_refinement := _geometry_sampling_input_has_override(recipe, input_id)
	if had_refinement and is_equal_approx(current_factor, normalized_factor):
		return
	_record_coalesced_change()
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	recipe = GeometrySamplingService.normalize_recipe(document.get("sampling", {}).get("recipe", {}))
	var refinements: Dictionary = recipe["parameters"].get("boundary_refinements", {}).duplicate(true)
	refinements[input_id] = {"factor": normalized_factor}
	recipe["parameters"]["boundary_refinements"] = refinements
	document["sampling"]["recipe"] = recipe
	_schedule_geometry_sampling_input_refresh()


func _on_geometry_sampling_refinement_toggled(enabled: bool, input_id: String) -> void:
	if enabled:
		_set_geometry_sampling_refinement(input_id, 2.0)
		return
	if selected_asset_id.is_empty() or selected_component_id.is_empty() or input_id.is_empty():
		return
	var recipe := _geometry_sampling_recipe(selected_asset_id, selected_component_id)
	if not _geometry_sampling_input_has_override(recipe, input_id):
		return
	_record_coalesced_change()
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	recipe = GeometrySamplingService.normalize_recipe(document.get("sampling", {}).get("recipe", {}))
	var refinements: Dictionary = recipe["parameters"].get("boundary_refinements", {}).duplicate(true)
	refinements.erase(input_id)
	recipe["parameters"]["boundary_refinements"] = refinements
	document["sampling"]["recipe"] = recipe
	_schedule_geometry_sampling_input_refresh()


func _on_geometry_sampling_refinement_changed(value: float, input_id: String) -> void:
	_set_geometry_sampling_refinement(input_id, value)


func _render_geometry_sampling_inspector() -> void:
	var asset := _get_asset(selected_asset_id)
	var component := _get_component(asset, selected_component_id)
	if component.is_empty():
		inspector_content.add_child(_create_inspector_section("Sampling"))
		inspector_content.add_child(_create_inspector_field_label("Select one Component to configure its boundary sampling."))
		return
	inspector_content.add_child(_create_inspector_section("Boundary Sampling · %s" % str(component.get("name", "Component"))))
	inspector_content.add_child(_create_inspector_field_label("One adaptive Body recipe shared by Outer, Holes, and Cuts."))
	var base_recipe := _geometry_sampling_recipe(selected_asset_id, selected_component_id)
	inspector_content.add_child(_create_inspector_field_label("Target Edge Length (Body units)"))
	var spacing := SpinBox.new()
	spacing.min_value = GeometrySamplingService.MIN_SPACING
	spacing.max_value = 10000.0
	spacing.step = 0.01
	spacing.custom_arrow_step = 0.01
	spacing.set_value_no_signal(float(base_recipe.get("parameters", {}).get("spacing", GeometrySamplingService.DEFAULT_SPACING)))
	spacing.value_changed.connect(_on_geometry_sampling_parameter_changed.bind("spacing"))
	spacing.get_line_edit().text_submitted.connect(_on_geometry_spacing_text_submitted.bind(spacing))
	spacing.get_line_edit().focus_exited.connect(_on_geometry_spacing_focus_exited.bind(spacing))
	inspector_content.add_child(spacing)
	inspector_content.add_child(_create_inspector_field_label("Curve Detail"))
	var feature_detail := SpinBox.new()
	feature_detail.min_value = 0.0
	feature_detail.max_value = 100.0
	feature_detail.step = 5.0
	feature_detail.suffix = "%"
	feature_detail.set_value_no_signal(float(base_recipe.get("parameters", {}).get("feature_detail", GeometrySamplingService.DEFAULT_FEATURE_DETAIL)) * 100.0)
	feature_detail.value_changed.connect(_on_geometry_sampling_feature_detail_changed)
	inspector_content.add_child(feature_detail)

	var display_result := geometry_sampling_preview if _geometry_sampling_preview_matches(selected_asset_id, selected_component_id, component) else _geometry_sampling_bake(selected_asset_id, selected_component_id)
	inspector_content.add_child(_create_inspector_section("Boundary Inputs"))
	_render_geometry_sampling_boundary_row("Outer · %s" % str(component.get("name", "Component")), "", "outer", display_result, Callable())

	var references: Array = []
	for reference in asset.get("components", []):
		if _is_reference_component(reference) and str(reference.get("parent_component_id", "")) == selected_component_id and str(reference.get("topology_role", "outer")) == "hole":
			references.append(reference)
	for reference in references:
		var reference_id := str(reference.get("id", ""))
		var reference_name := _component_outliner_name(asset, reference)
		_render_geometry_sampling_boundary_row("Hole · %s" % reference_name, reference_id, "hole", display_result, _select_geometry_sampling_reference.bind(selected_asset_id, selected_component_id, reference_id))

	for guide in asset.get("guides", []):
		if str(guide.get("scope", {}).get("component_id", "")) != selected_component_id or str(guide.get("guide_type", "")) != AssetGuide.CUT:
			continue
		var guide_id := str(guide.get("id", ""))
		_render_geometry_sampling_boundary_row("Cut · %s" % _guide_display_name(asset, guide), guide_id, "cut", display_result, _select_guide.bind(selected_asset_id, guide_id))

	if not selected_sampling_input_id.is_empty():
		_render_geometry_sampling_refinement_controls(base_recipe)

	var status := _geometry_sampling_status(selected_asset_id, selected_component_id, component)
	inspector_content.add_child(_create_inspector_section("Result"))
	inspector_content.add_child(_create_inspector_field_label("Status: %s" % status))
	if not display_result.is_empty():
		inspector_content.add_child(_create_inspector_field_label("Constraint Samples: %d" % int(display_result.get("constraint_sample_count", display_result.get("sample_count", 0)))))
		inspector_content.add_child(_create_inspector_field_label("Preserved Points: %d" % int(display_result.get("preserve_count", 0))))
	var actions := HBoxContainer.new()
	var bake_button := Button.new()
	bake_button.text = "Calculating…" if status == "Calculating" else "Baked" if status == "Baked" else "Bake Preview"
	bake_button.custom_minimum_size = Vector2(96, 28)
	bake_button.focus_mode = Control.FOCUS_NONE
	bake_button.disabled = status != "Preview Ready"
	bake_button.pressed.connect(_bake_geometry_sampling)
	geometry_sampling_bake_button = bake_button
	actions.add_child(bake_button)
	inspector_content.add_child(actions)


func _render_geometry_sampling_boundary_row(title: String, input_id: String, role: String, result: Dictionary, select_action: Callable) -> void:
	var count := 0
	for stat in result.get("boundary_stats", []):
		if str(stat.get("input_id", "")) == input_id and str(stat.get("role", "")) == role:
			count += int(stat.get("sample_count", 0))
	var recipe := _geometry_sampling_recipe(selected_asset_id, selected_component_id)
	var refinement: Dictionary = recipe.get("parameters", {}).get("boundary_refinements", {}).get(input_id, {})
	var factor := float(refinement.get("factor", 1.0))
	var has_adjustment := _geometry_sampling_input_has_override(recipe, input_id)
	var button := Button.new()
	button.text = "%s  ·  %s%s" % [title, "Density %s×" % _format_scale_value(factor) if has_adjustment else "Inherited", "  ·  %d" % count if count > 0 else ""]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not select_action.is_valid()
	if select_action.is_valid():
		button.pressed.connect(select_action)
	inspector_content.add_child(button)


func _render_geometry_sampling_refinement_controls(recipe: Dictionary) -> void:
	var input := _get_sampling_input(_get_asset(selected_asset_id), selected_sampling_input_id, selected_sampling_input_kind)
	if input.is_empty():
		return
	inspector_content.add_child(_create_inspector_section("Boundary Density · %s" % _sampling_input_display_name(_get_asset(selected_asset_id), _get_component(_get_asset(selected_asset_id), selected_component_id), input, selected_sampling_input_kind)))
	var refinement: Dictionary = recipe.get("parameters", {}).get("boundary_refinements", {}).get(selected_sampling_input_id, {})
	var factor := float(refinement.get("factor", 1.0))
	var has_adjustment := _geometry_sampling_input_has_override(recipe, selected_sampling_input_id)
	var toggle := CheckBox.new()
	toggle.text = "Adjust this Boundary"
	toggle.button_pressed = has_adjustment
	toggle.toggled.connect(_on_geometry_sampling_refinement_toggled.bind(selected_sampling_input_id))
	inspector_content.add_child(toggle)
	var effective_spacing := float(recipe.get("parameters", {}).get("spacing", GeometrySamplingService.DEFAULT_SPACING)) / factor
	inspector_content.add_child(_create_inspector_field_label("Effective Edge Length: %.2f" % effective_spacing))
	if has_adjustment:
		inspector_content.add_child(_create_inspector_field_label("Density Factor · below 1× is coarser"))
		var factor_input := SpinBox.new()
		factor_input.min_value = GeometrySamplingService.MIN_REFINEMENT_FACTOR
		factor_input.max_value = GeometrySamplingService.MAX_REFINEMENT_FACTOR
		factor_input.step = 0.25
		factor_input.suffix = "×"
		factor_input.set_value_no_signal(factor)
		factor_input.value_changed.connect(_on_geometry_sampling_refinement_changed.bind(selected_sampling_input_id))
		inspector_content.add_child(factor_input)


func _on_geometry_sampling_parameter_changed(value: float, parameter_name: String) -> void:
	if selected_asset_id.is_empty() or selected_component_id.is_empty():
		return
	var current_recipe := _geometry_sampling_recipe(selected_asset_id, selected_component_id)
	var normalized_value := maxf(value, GeometrySamplingService.MIN_SPACING) if parameter_name == "spacing" else clampf(value, 0.0, 1.0)
	if is_equal_approx(float(current_recipe.get("parameters", {}).get(parameter_name, normalized_value)), normalized_value):
		return
	_record_coalesced_change()
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	var recipe := GeometrySamplingService.normalize_recipe(document.get("sampling", {}).get("recipe", {}))
	recipe["parameters"][parameter_name] = normalized_value
	document["sampling"]["recipe"] = recipe
	_schedule_geometry_sampling_input_refresh()


func _on_geometry_sampling_feature_detail_changed(percent: float) -> void:
	_on_geometry_sampling_parameter_changed(clampf(percent / 100.0, 0.0, 1.0), "feature_detail")


func _on_geometry_sampling_parameter_focus_exited() -> void:
	call_deferred("_refresh_geometry_after_recipe_change")


func _on_geometry_spacing_text_submitted(text: String, spacing: SpinBox) -> void:
	_commit_geometry_spacing_text(text, spacing)


func _on_geometry_spacing_focus_exited(spacing: SpinBox) -> void:
	_commit_geometry_spacing_text(spacing.get_line_edit().text, spacing)
	call_deferred("_refresh_geometry_after_recipe_change")


func _commit_geometry_spacing_text(raw_text: String, spacing: SpinBox) -> void:
	var normalized_text := raw_text.strip_edges().replace(",", ".")
	if not normalized_text.is_valid_float():
		spacing.get_line_edit().text = String.num(spacing.value, 2)
		return
	var value := maxf(float(normalized_text), GeometrySamplingService.MIN_SPACING)
	value = minf(value, spacing.max_value)
	spacing.set_value_no_signal(value)
	spacing.get_line_edit().text = String.num(value, 2)
	_on_geometry_sampling_parameter_changed(value, "spacing")


func _generate_geometry_sampling_preview() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		return
	geometry_sampling_preview_key = _geometry_document_key(selected_asset_id, selected_component_id)
	geometry_sampling_preview_state = "calculating"
	var asset := _get_asset(selected_asset_id)
	var cut_guides := _cut_guides_for_component(asset, selected_component_id)
	var hole_components := _geometry_sampling_hole_components(asset, selected_component_id)
	geometry_sampling_preview = GeometrySamplingService.generate(component, _geometry_sampling_recipe(selected_asset_id, selected_component_id), cut_guides, hole_components)
	if not bool(geometry_sampling_preview.get("valid", false)):
		geometry_sampling_preview_state = "invalid"
		var errors: Array = geometry_sampling_preview.get("errors", [])
		_show_status_message(str(errors[0]) if not errors.is_empty() else "Sampling could not be generated.")
	else:
		geometry_sampling_preview_state = "ready"
		_show_status_message("Generated %d Sample Points." % int(geometry_sampling_preview.get("sample_count", 0)))
	_render_outliner()
	_render_inspector()
	_refresh_geometry_sampling_workspace()


func _bake_geometry_sampling() -> void:
	_bake_geometry_sampling_preview()


func _bake_geometry_sampling_preview() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not _geometry_sampling_preview_matches(selected_asset_id, selected_component_id, component):
		return
	_record_direct_change()
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	var bake := geometry_sampling_preview.duplicate(true)
	bake["bake_id"] = "bake_%d" % ResourceUID.create_id()
	var asset := _get_asset(selected_asset_id)
	var cut_guides := _cut_guides_for_component(asset, selected_component_id)
	var hole_components := _geometry_sampling_hole_components(asset, selected_component_id)
	bake["semantic_source_signature"] = GeometryAutoBuildService.source_signature(component, cut_guides, hole_components, {"sampling": _geometry_sampling_recipe(selected_asset_id, selected_component_id)})
	document["sampling"]["bakes"][str(bake.get("method", ""))] = bake
	selected_geometry_bake_method = str(bake.get("method", ""))
	geometry_sampling_preview = {}
	geometry_sampling_preview_key = ""
	geometry_sampling_preview_state = "idle"
	_show_status_message("Sampling baked for %s." % str(component.get("name", "Component")))
	_render_outliner()
	_render_inspector()
	_refresh_geometry_sampling_workspace()


func _clear_geometry_sampling_preview_for_selection() -> void:
	if geometry_sampling_preview_key == _geometry_document_key(selected_asset_id, selected_component_id):
		geometry_sampling_preview = {}
		geometry_sampling_preview_key = ""
		geometry_sampling_preview_state = "idle"


func _refresh_geometry_after_recipe_change() -> void:
	if active_geometry_submodule == "Sampling":
		_schedule_geometry_sampling_preview()
		geometry_seeding_preview = {}
		geometry_seeding_preview_key = ""
		geometry_seeding_preview_state = "idle"
		geometry_seeding_preview_revision += 1
		geometry_meshing_preview = {}
		geometry_meshing_preview_key = ""
		geometry_meshing_preview_state = "idle"
		geometry_meshing_preview_revision += 1
	elif active_geometry_submodule == "Seeding":
		_schedule_geometry_seeding_preview()
		geometry_meshing_preview = {}
		geometry_meshing_preview_key = ""
		geometry_meshing_preview_state = "idle"
		geometry_meshing_preview_revision += 1
	elif active_geometry_submodule == "Meshing":
		_schedule_geometry_meshing_preview()


func _schedule_geometry_sampling_input_refresh() -> void:
	_schedule_geometry_sampling_preview()


func _refresh_geometry_sampling_input_after_change() -> void:
	_schedule_geometry_sampling_preview()


func _schedule_geometry_sampling_preview() -> void:
	if selected_asset_id.is_empty() or selected_component_id.is_empty():
		return
	geometry_sampling_preview_revision += 1
	var revision := geometry_sampling_preview_revision
	geometry_sampling_preview = {}
	geometry_sampling_preview_key = _geometry_document_key(selected_asset_id, selected_component_id)
	geometry_sampling_preview_state = "calculating"
	geometry_sampling_input_refresh_pending = true
	_render_outliner()
	_update_geometry_sampling_bake_button()
	_refresh_geometry_sampling_workspace()
	_generate_geometry_sampling_preview_after_delay(revision)


func _generate_geometry_sampling_preview_after_delay(revision: int) -> void:
	if is_inside_tree():
		await get_tree().create_timer(0.15).timeout
	if revision != geometry_sampling_preview_revision:
		return
	geometry_sampling_input_refresh_pending = false
	_generate_geometry_sampling_preview()


func _update_geometry_sampling_bake_button() -> void:
	if not is_instance_valid(geometry_sampling_bake_button):
		return
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var status := _geometry_sampling_status(selected_asset_id, selected_component_id, component)
	geometry_sampling_bake_button.text = "Calculating…" if status == "Calculating" else "Baked" if status == "Baked" else "Bake Preview"
	geometry_sampling_bake_button.disabled = status != "Preview Ready"


func _refresh_geometry_sampling_workspace() -> void:
	if not is_instance_valid(geometry_sampling_workspace):
		return
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		geometry_sampling_workspace.clear_context()
		return
	var asset := _get_asset(selected_asset_id)
	var cut_guides := _cut_guides_for_component(asset, selected_component_id)
	var hole_components := _geometry_sampling_hole_components(asset, selected_component_id)
	var preview := geometry_sampling_preview if geometry_sampling_preview_key == _geometry_document_key(selected_asset_id, selected_component_id) \
		and str(geometry_sampling_preview.get("source_fingerprint", "")) == GeometrySamplingService.source_fingerprint(component, cut_guides, hole_components) else {}
	var bake := _geometry_sampling_bake(selected_asset_id, selected_component_id)
	var overlays := _geometry_sampling_overlays(asset, selected_component_id)
	geometry_sampling_workspace.set_context(component, preview, bake, _geometry_sampling_status(selected_asset_id, selected_component_id, component), overlays, selected_sampling_input_id)


func _geometry_sampling_hole_components(asset: Dictionary, component_id: String) -> Array:
	var result: Array = []
	var parent_inverse := ComponentHierarchy.world_transform(asset, component_id).affine_inverse()
	for reference in asset.get("components", []):
		if not reference is Dictionary or not _is_reference_component(reference):
			continue
		if str(reference.get("parent_component_id", "")) != component_id or str(reference.get("topology_role", "outer")) != "hole":
			continue
		var source_asset := _get_asset(str(reference.get("source_asset_id", "")))
		if source_asset.is_empty():
			continue
		var reference_world := ComponentHierarchy.world_transform(asset, str(reference.get("id", "")))
		for source_component in source_asset.get("components", []):
			if not source_component is Dictionary or _is_reference_component(source_component) or str(source_component.get("draw_mode", "closed_loop")) not in ["closed_loop", "primitive"]:
				continue
			var hole_id := "%s:%s" % [str(reference.get("id", "")), str(source_component.get("id", ""))]
			var source_world := ComponentHierarchy.world_transform(source_asset, str(source_component.get("id", "")))
			var transform := parent_inverse * reference_world * source_world
			if PrimitiveGeometryService.has_circle(source_component):
				var primitive_hole: Dictionary = source_component.duplicate(true)
				primitive_hole["id"] = hole_id
				primitive_hole["sampling_input_id"] = str(reference.get("id", hole_id))
				primitive_hole["topology_role"] = "hole"
				primitive_hole["sampling_transform"] = transform
				result.append(primitive_hole)
				continue
			var hole_component: Dictionary = source_component.duplicate(true)
			hole_component["id"] = hole_id
			hole_component["sampling_input_id"] = str(reference.get("id", hole_id))
			hole_component["topology_role"] = "hole"
			var point_id_map: Dictionary = {}
			for point in hole_component.get("points", []):
				var old_point_id := str(point.get("id", ""))
				var new_point_id := "%s:%s" % [hole_id, old_point_id]
				point_id_map[old_point_id] = new_point_id
				point["id"] = new_point_id
				point["position"] = transform * Vector2(point.get("position", Vector2.ZERO))
				point["handle_in"] = transform.basis_xform(Vector2(point.get("handle_in", Vector2.ZERO)))
				point["handle_out"] = transform.basis_xform(Vector2(point.get("handle_out", Vector2.ZERO)))
			for edge in hole_component.get("edges", []):
				edge["id"] = "%s:%s" % [hole_id, str(edge.get("id", ""))]
				edge["start_point_id"] = str(point_id_map.get(str(edge.get("start_point_id", "")), ""))
				edge["end_point_id"] = str(point_id_map.get(str(edge.get("end_point_id", "")), ""))
			for chain in hole_component.get("chains", []):
				chain["id"] = "%s:%s" % [hole_id, str(chain.get("id", ""))]
				chain["point_ids"] = chain.get("point_ids", []).map(func(point_id: String) -> String: return str(point_id_map.get(point_id, "")))
				chain["edge_ids"] = chain.get("edge_ids", []).map(func(edge_id: String) -> String: return "%s:%s" % [hole_id, edge_id])
				chain["topology_role"] = "hole"
			result.append(hole_component)
	return result


func _geometry_sampling_overlays(asset: Dictionary, component_id: String) -> Dictionary:
	var overlays := {"holes": [], "guides": []}
	var parent_world := ComponentHierarchy.world_transform(asset, component_id)
	var parent_inverse := parent_world.affine_inverse()
	for reference in asset.get("components", []):
		if not reference is Dictionary or not _is_reference_component(reference):
			continue
		if str(reference.get("parent_component_id", "")) != component_id or str(reference.get("topology_role", "outer")) != "hole":
			continue
		for shape in _reference_asset_shapes(asset, reference, ""):
			var local_points: Array[Vector2] = []
			for point in shape.get("points", []):
				local_points.append(parent_inverse * Vector2(point))
			if local_points.size() >= 3:
				overlays["holes"].append({"points": local_points, "closed": true})
	for guide in _cut_guides_for_component(asset, component_id):
		if not guide is Dictionary:
			continue
		var local_guide: Dictionary = guide.duplicate(true)
		local_guide["points"] = guide.get("points", []).duplicate(true)
		overlays["guides"].append(local_guide)
	return overlays


func _render_geometry_seeding_inspector() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		inspector_content.add_child(_create_inspector_section("Seeding"))
		inspector_content.add_child(_create_inspector_field_label("Select one Component to configure its interior seeding."))
		return
	inspector_content.add_child(_create_inspector_section("Seeding · %s" % str(component.get("name", "Component"))))
	inspector_content.add_child(_create_inspector_field_label("One derived Seed set from the accepted Sampling constraints."))
	var upstream_current := _geometry_sampling_bake_is_current(selected_asset_id, selected_component_id, component)
	inspector_content.add_child(_create_inspector_section("Input"))
	var input_label := _create_inspector_field_label("Sampling · Adaptive: %s" % ("Baked" if upstream_current else "Required / Stale"))
	input_label.add_theme_color_override("font_color", Color("#75b88a") if upstream_current else Color("#ef8354"))
	inspector_content.add_child(input_label)
	var recipe := _geometry_seeding_recipe(selected_asset_id, selected_component_id)
	var sampling_bake := _geometry_sampling_bake(selected_asset_id, selected_component_id)
	inspector_content.add_child(_create_inspector_field_label("Method"))
	var method_option := OptionButton.new()
	method_option.add_item("Poisson Fill")
	method_option.set_item_metadata(0, GeometrySeedingService.POISSON_FILL)
	method_option.add_item("Spine Flow")
	method_option.set_item_metadata(1, GeometrySeedingService.SPINE_FLOW)
	method_option.select(0 if str(recipe.get("method", "")) == GeometrySeedingService.POISSON_FILL else 1)
	method_option.item_selected.connect(func(index: int) -> void: _set_geometry_seeding_method(str(method_option.get_item_metadata(index))))
	inspector_content.add_child(method_option)
	inspector_content.add_child(_create_inspector_section("Parameters"))
	if str(recipe.get("method", "")) == GeometrySeedingService.SPINE_FLOW:
		var sampler_guides := _sampler_spines_for_component(_get_asset(selected_asset_id), selected_component_id)
		inspector_content.add_child(_create_inspector_field_label("Active Sampler Spines"))
		for guide in sampler_guides:
			var guide_id := str(guide.get("id", ""))
			var enabled := _geometry_seeding_spine_enabled(recipe, guide_id)
			var toggle := CheckBox.new()
			toggle.text = _guide_display_name(_get_asset(selected_asset_id), guide)
			toggle.button_pressed = enabled
			toggle.toggled.connect(_on_geometry_seeding_spine_enabled.bind(guide_id))
			inspector_content.add_child(toggle)
		if sampler_guides.is_empty():
			var missing_guide := _create_inspector_field_label("Create and author a Sampler Spine on this Component.")
			missing_guide.add_theme_color_override("font_color", Color("#ef8354"))
			inspector_content.add_child(missing_guide)
		_add_geometry_seeding_float_parameter("Seed Spacing (Body units)", recipe, "spacing", GeometrySeedingService.MIN_SPACING, 10000.0)
		_add_geometry_seeding_float_parameter("Flow Stretch", recipe, "flow_stretch", GeometrySeedingService.MIN_FLOW_STRETCH, GeometrySeedingService.MAX_FLOW_STRETCH, "×")
		var fill_gaps := CheckBox.new()
		fill_gaps.text = "Fill Gaps"
		fill_gaps.button_pressed = bool(recipe.get("parameters", {}).get("fill_gaps", GeometrySeedingService.DEFAULT_FILL_GAPS))
		fill_gaps.toggled.connect(_on_geometry_seeding_fill_gaps_changed)
		inspector_content.add_child(fill_gaps)
		var parameters: Dictionary = recipe.get("parameters", {})
		var boundary_override := bool(parameters.get("boundary_clearance_override", false))
		var boundary_clearance := float(parameters.get("boundary_clearance", GeometrySeedingService.DEFAULT_BOUNDARY_CLEARANCE))
		inspector_content.add_child(_create_inspector_field_label("Boundary Margin: %s · %s" % ["Refined" if boundary_override else "Auto", _format_scale_value(boundary_clearance)]))
		var refine_boundary := CheckBox.new()
		refine_boundary.text = "Refine Boundary Margin"
		refine_boundary.button_pressed = boundary_override
		refine_boundary.toggled.connect(_on_geometry_seeding_boundary_override_changed)
		inspector_content.add_child(refine_boundary)
		if boundary_override:
			_add_geometry_seeding_float_parameter("Boundary Margin Override", recipe, "boundary_clearance", 0.0, 10000.0)
		var advanced_pattern := Button.new()
		advanced_pattern.text = "%s Advanced Pattern" % ("▾" if geometry_seeding_advanced_pattern_expanded else "▸")
		advanced_pattern.toggle_mode = true
		advanced_pattern.button_pressed = geometry_seeding_advanced_pattern_expanded
		advanced_pattern.alignment = HORIZONTAL_ALIGNMENT_LEFT
		advanced_pattern.focus_mode = Control.FOCUS_NONE
		advanced_pattern.toggled.connect(_on_geometry_seeding_advanced_pattern_toggled)
		inspector_content.add_child(advanced_pattern)
		if geometry_seeding_advanced_pattern_expanded:
			inspector_content.add_child(_create_inspector_field_label("Along Spacing: Derived · %s" % _format_scale_value(float(parameters.get("along_spacing", GeometrySeedingService.DEFAULT_ALONG_SPACING)))))
			inspector_content.add_child(_create_inspector_field_label("Across Spacing: Derived · %s" % _format_scale_value(float(parameters.get("across_spacing", GeometrySeedingService.DEFAULT_ACROSS_SPACING)))))
			var stagger_override := bool(parameters.get("stagger_override", false))
			var stagger := float(parameters.get("stagger", GeometrySeedingService.DEFAULT_ARTISTIC_STAGGER))
			inspector_content.add_child(_create_inspector_field_label("Stagger: %s · %s" % ["Refined" if stagger_override else "Auto", _format_scale_value(stagger)]))
			var refine_stagger := CheckBox.new()
			refine_stagger.text = "Refine Stagger"
			refine_stagger.button_pressed = stagger_override
			refine_stagger.toggled.connect(_on_geometry_seeding_stagger_override_changed)
			inspector_content.add_child(refine_stagger)
			if stagger_override:
				_add_geometry_seeding_float_parameter("Stagger Override", recipe, "stagger", 0.0, 1.0)
	else:
		_add_geometry_seeding_float_parameter("Seed Spacing (Body units)", recipe, "spacing", GeometrySeedingService.MIN_SPACING, 10000.0)
		var clearance := float(recipe.get("parameters", {}).get("spacing", GeometrySeedingService.DEFAULT_SPACING)) * float(recipe.get("parameters", {}).get("constraint_clearance_factor", GeometrySeedingService.DEFAULT_CONSTRAINT_CLEARANCE_FACTOR))
		inspector_content.add_child(_create_inspector_field_label("Constraint Clearance: Auto · %.2f" % clearance))
	if str(recipe.get("method", "")) == GeometrySeedingService.POISSON_FILL or (geometry_seeding_advanced_pattern_expanded and bool(recipe.get("parameters", {}).get("fill_gaps", false))):
		inspector_content.add_child(_create_inspector_field_label("Random Seed"))
		var random_seed := SpinBox.new()
		random_seed.min_value = 0.0
		random_seed.max_value = 2147483647.0
		random_seed.step = 1.0
		random_seed.set_value_no_signal(float(recipe.get("parameters", {}).get("seed", GeometrySeedingService.DEFAULT_SEED)))
		random_seed.value_changed.connect(_on_geometry_seeding_parameter_changed.bind("seed"))
		inspector_content.add_child(random_seed)
	inspector_content.add_child(_create_inspector_section("Constraints"))
	var outer_count := 0
	var hole_count := 0
	var cut_count := 0
	for stat in sampling_bake.get("boundary_stats", []):
		var role := str(stat.get("role", ""))
		if role == "outer":
			outer_count += int(stat.get("sample_count", 0))
		elif role == "hole":
			hole_count += int(stat.get("sample_count", 0))
		elif role == "cut":
			cut_count += int(stat.get("sample_count", 0))
	inspector_content.add_child(_create_inspector_field_label("Outer · inward clearance · %d points" % outer_count))
	inspector_content.add_child(_create_inspector_field_label("Holes · excluded + clearance · %d points" % hole_count))
	inspector_content.add_child(_create_inspector_field_label("Cuts · barrier + clearance · %d points" % cut_count))
	var status := _geometry_seeding_status(selected_asset_id, selected_component_id, component)
	inspector_content.add_child(_create_inspector_section("Result"))
	inspector_content.add_child(_create_inspector_field_label("Status: %s" % status))
	var result := geometry_seeding_preview if _geometry_seeding_preview_matches(selected_asset_id, selected_component_id, component) else _geometry_seeding_bake(selected_asset_id, selected_component_id)
	if not result.is_empty():
		inspector_content.add_child(_create_inspector_field_label("Seeds: %d" % int(result.get("seed_count", result.get("seeds", []).size()))))
		if str(result.get("method", "")) == GeometrySeedingService.SPINE_FLOW:
			inspector_content.add_child(_create_inspector_field_label("Flow: %d · Gap Fill: %d" % [int(result.get("flow_seed_count", 0)), int(result.get("gap_seed_count", 0))]))
	var actions := HBoxContainer.new()
	var bake_button := Button.new()
	bake_button.text = "Calculating…" if status == "Calculating" else "Baked" if status in ["Baked", "Edited"] else "Bake Preview"
	bake_button.custom_minimum_size = Vector2(96, 28)
	bake_button.focus_mode = Control.FOCUS_NONE
	bake_button.disabled = status != "Preview Ready"
	bake_button.pressed.connect(_bake_geometry_seeding)
	geometry_seeding_bake_button = bake_button
	actions.add_child(bake_button)
	inspector_content.add_child(actions)


func _add_geometry_seeding_float_parameter(label_text: String, recipe: Dictionary, parameter_name: String, minimum: float, maximum: float, suffix := "") -> void:
	inspector_content.add_child(_create_inspector_field_label(label_text))
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = 0.01
	field.custom_arrow_step = 0.01
	field.suffix = suffix
	field.set_value_no_signal(float(recipe.get("parameters", {}).get(parameter_name, minimum)))
	field.value_changed.connect(_on_geometry_seeding_parameter_changed.bind(parameter_name))
	field.get_line_edit().text_submitted.connect(_on_geometry_seeding_float_text_submitted.bind(field, parameter_name))
	field.get_line_edit().focus_exited.connect(_on_geometry_seeding_float_focus_exited.bind(field, parameter_name))
	inspector_content.add_child(field)


func _geometry_seeding_spine_enabled(recipe: Dictionary, guide_id: String) -> bool:
	for input in recipe.get("parameters", {}).get("spine_inputs", []):
		if input is Dictionary and str(input.get("guide_id", "")) == guide_id:
			return bool(input.get("enabled", true))
	return false


func _on_geometry_seeding_spine_enabled(enabled: bool, guide_id: String) -> void:
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	var recipe := _geometry_seeding_recipe(selected_asset_id, selected_component_id)
	_record_direct_change()
	var inputs: Array = recipe.get("parameters", {}).get("spine_inputs", []).duplicate(true)
	var found := false
	for input in inputs:
		if input is Dictionary and str(input.get("guide_id", "")) == guide_id:
			input["enabled"] = enabled
			found = true
			break
	if not found:
		inputs.append({"guide_id": guide_id, "enabled": enabled})
	recipe["parameters"]["spine_inputs"] = inputs
	document["seeding"]["recipe"] = GeometrySeedingService.normalize_recipe(recipe)
	call_deferred("_schedule_geometry_seeding_preview")


func _on_geometry_seeding_fill_gaps_changed(enabled: bool) -> void:
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	var recipe := _geometry_seeding_recipe(selected_asset_id, selected_component_id)
	if bool(recipe.get("parameters", {}).get("fill_gaps", true)) == enabled:
		return
	_record_direct_change()
	recipe["parameters"]["fill_gaps"] = enabled
	document["seeding"]["recipe"] = GeometrySeedingService.normalize_recipe(recipe)
	call_deferred("_refresh_geometry_after_recipe_change")


func _on_geometry_seeding_boundary_override_changed(enabled: bool) -> void:
	_on_geometry_seeding_override_changed("boundary_clearance_override", enabled)


func _on_geometry_seeding_stagger_override_changed(enabled: bool) -> void:
	_on_geometry_seeding_override_changed("stagger_override", enabled)


func _on_geometry_seeding_override_changed(parameter_name: String, enabled: bool) -> void:
	if selected_asset_id.is_empty() or selected_component_id.is_empty():
		return
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	var recipe := _geometry_seeding_recipe(selected_asset_id, selected_component_id)
	if bool(recipe.get("parameters", {}).get(parameter_name, false)) == enabled:
		return
	_record_direct_change()
	recipe["parameters"][parameter_name] = enabled
	document["seeding"]["recipe"] = GeometrySeedingService.normalize_recipe(recipe)
	call_deferred("_refresh_geometry_after_recipe_change")


func _on_geometry_seeding_advanced_pattern_toggled(expanded: bool) -> void:
	geometry_seeding_advanced_pattern_expanded = expanded
	_render_inspector()


func _on_geometry_seeding_parameter_changed(value: float, parameter_name: String) -> void:
	if selected_asset_id.is_empty() or selected_component_id.is_empty():
		return
	var current := _geometry_seeding_recipe(selected_asset_id, selected_component_id)
	var normalized_value: Variant = value
	if parameter_name in ["spacing", "along_spacing", "across_spacing"]:
		normalized_value = maxf(value, GeometrySeedingService.MIN_SPACING)
	elif parameter_name == "flow_stretch":
		normalized_value = clampf(value, GeometrySeedingService.MIN_FLOW_STRETCH, GeometrySeedingService.MAX_FLOW_STRETCH)
	elif parameter_name == "boundary_clearance":
		normalized_value = maxf(value, 0.0)
	elif parameter_name == "stagger":
		normalized_value = clampf(value, 0.0, 1.0)
	elif parameter_name == "seed":
		normalized_value = maxi(0, int(round(value)))
	if current.get("parameters", {}).get(parameter_name) == normalized_value:
		return
	_record_coalesced_change()
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	var recipe := GeometrySeedingService.normalize_recipe(document.get("seeding", {}).get("recipe", {}))
	recipe["parameters"][parameter_name] = normalized_value
	document["seeding"]["recipe"] = GeometrySeedingService.normalize_recipe(recipe)
	call_deferred("_refresh_geometry_after_recipe_change")


func _on_geometry_seeding_spacing_text_submitted(text: String, spacing: SpinBox) -> void:
	_commit_geometry_seeding_spacing_text(text, spacing)


func _on_geometry_seeding_spacing_focus_exited(spacing: SpinBox) -> void:
	_commit_geometry_seeding_spacing_text(spacing.get_line_edit().text, spacing)


func _on_geometry_seeding_float_text_submitted(text: String, field: SpinBox, parameter_name: String) -> void:
	_commit_geometry_seeding_spacing_text(text, field, parameter_name)


func _on_geometry_seeding_float_focus_exited(field: SpinBox, parameter_name: String) -> void:
	_commit_geometry_seeding_spacing_text(field.get_line_edit().text, field, parameter_name)


func _commit_geometry_seeding_spacing_text(raw_text: String, spacing: SpinBox, parameter_name := "spacing") -> void:
	var normalized_text := raw_text.strip_edges().replace(",", ".")
	if not normalized_text.is_valid_float():
		spacing.get_line_edit().text = String.num(spacing.value, 2)
		return
	var value := clampf(float(normalized_text), spacing.min_value, spacing.max_value)
	spacing.set_value_no_signal(value)
	spacing.get_line_edit().text = String.num(value, 2)
	_on_geometry_seeding_parameter_changed(value, parameter_name)


func _generate_geometry_seeding_preview() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or not _geometry_sampling_bake_is_current(selected_asset_id, selected_component_id, component):
		geometry_seeding_preview_state = "invalid"
		_show_status_message("Bake current Sampling before generating Seeds.")
		return
	var recipe := _geometry_seeding_recipe(selected_asset_id, selected_component_id)
	var guides := _geometry_seeding_sampler_spines(selected_asset_id, selected_component_id, recipe)
	geometry_seeding_preview_key = _geometry_document_key(selected_asset_id, selected_component_id)
	geometry_seeding_preview_state = "calculating"
	geometry_seeding_preview = GeometrySeedingService.generate(_geometry_sampling_bake(selected_asset_id, selected_component_id), recipe, guides)
	if bool(geometry_seeding_preview.get("valid", false)):
		geometry_seeding_preview_state = "ready"
		_show_status_message("Generated %d Seeds." % int(geometry_seeding_preview.get("seed_count", 0)))
	else:
		geometry_seeding_preview_state = "invalid"
		var errors: Array = geometry_seeding_preview.get("errors", [])
		_show_status_message(str(errors[0]) if not errors.is_empty() else "Seeding could not be generated.")
	_render_outliner()
	_render_inspector()
	_refresh_geometry_seeding_workspace()


func _bake_geometry_seeding() -> void:
	_bake_geometry_seeding_preview()


func _schedule_geometry_seeding_preview() -> void:
	if selected_asset_id.is_empty() or selected_component_id.is_empty():
		return
	geometry_seeding_preview_revision += 1
	var revision := geometry_seeding_preview_revision
	geometry_seeding_preview = {}
	geometry_seeding_preview_key = _geometry_document_key(selected_asset_id, selected_component_id)
	geometry_seeding_preview_state = "calculating"
	_render_outliner()
	_update_geometry_seeding_bake_button()
	_refresh_geometry_seeding_workspace()
	_generate_geometry_seeding_preview_after_delay(revision)


func _generate_geometry_seeding_preview_after_delay(revision: int) -> void:
	if is_inside_tree():
		await get_tree().create_timer(0.15).timeout
	if revision != geometry_seeding_preview_revision:
		return
	_generate_geometry_seeding_preview()


func _update_geometry_seeding_bake_button() -> void:
	if not is_instance_valid(geometry_seeding_bake_button):
		return
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var status := _geometry_seeding_status(selected_asset_id, selected_component_id, component)
	geometry_seeding_bake_button.text = "Calculating…" if status == "Calculating" else "Baked" if status in ["Baked", "Edited"] else "Bake Preview"
	geometry_seeding_bake_button.disabled = status != "Preview Ready"


func _bake_geometry_seeding_preview(enter_edit_after_bake := false) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not _geometry_seeding_preview_matches(selected_asset_id, selected_component_id, component):
		return
	geometry_seeding_enter_edit_after_bake = enter_edit_after_bake
	var existing := _geometry_seeding_bake(selected_asset_id, selected_component_id)
	if bool(existing.get("edited", false)) and is_instance_valid(geometry_seeding_replace_dialog):
		geometry_seeding_replace_dialog.popup_centered()
		return
	_confirm_bake_geometry_seeding_preview()


func _confirm_bake_geometry_seeding_preview() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not _geometry_seeding_preview_matches(selected_asset_id, selected_component_id, component):
		geometry_seeding_enter_edit_after_bake = false
		return
	_record_direct_change()
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	var bake := geometry_seeding_preview.duplicate(true)
	bake["bake_id"] = "seeding_bake_%d" % ResourceUID.create_id()
	bake["edited"] = false
	document["seeding"]["bakes"][str(bake.get("method", ""))] = bake
	selected_geometry_bake_method = str(bake.get("method", ""))
	geometry_seeding_preview = {}
	geometry_seeding_preview_key = ""
	geometry_seeding_preview_state = "idle"
	geometry_seeding_preview_revision += 1
	_set_geometry_command_state("seeding_edit" if geometry_seeding_enter_edit_after_bake else "")
	geometry_seeding_enter_edit_after_bake = false
	_show_status_message("Seeding baked for %s." % str(component.get("name", "Component")))
	_render_outliner()
	_render_inspector()
	_render_context_bar()
	_refresh_geometry_seeding_workspace()
	if geometry_seeding_edit_active and is_instance_valid(geometry_seeding_workspace) and geometry_seeding_workspace.is_inside_tree():
		geometry_seeding_workspace.grab_focus()


func _cancel_geometry_seeding_preview_replacement() -> void:
	geometry_seeding_enter_edit_after_bake = false


func _refresh_geometry_seeding_workspace() -> void:
	if not is_instance_valid(geometry_seeding_workspace):
		return
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		geometry_seeding_workspace.clear_context()
		return
	var status := _geometry_seeding_status(selected_asset_id, selected_component_id, component)
	var result := geometry_seeding_preview if _geometry_seeding_preview_matches(selected_asset_id, selected_component_id, component) else _geometry_seeding_bake(selected_asset_id, selected_component_id)
	var guides := _geometry_seeding_sampler_spines(selected_asset_id, selected_component_id)
	geometry_seeding_workspace.set_context(_geometry_sampling_bake(selected_asset_id, selected_component_id), result, guides, status, geometry_seeding_edit_active and status in ["Baked", "Edited"], geometry_seeding_edit_tool, selected_sampling_input_id)


func _editable_geometry_seeding_bake() -> Dictionary:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if _geometry_seeding_status(selected_asset_id, selected_component_id, component) not in ["Baked", "Edited"]:
		return {}
	return _geometry_seeding_bake(selected_asset_id, selected_component_id)


func _on_geometry_seed_add_requested(position: Vector2) -> void:
	var bake := _editable_geometry_seeding_bake()
	var sampling_bake := _geometry_sampling_bake(selected_asset_id, selected_component_id)
	var recipe := _geometry_seeding_recipe(selected_asset_id, selected_component_id)
	if bake.is_empty() or not GeometrySeedingService.point_is_valid(sampling_bake, position, _geometry_seeding_constraint_clearance(recipe)):
		_show_status_message("Seeds must respect Outer, Hole, Cut, and constraint clearance.")
		return
	for seed_data in bake.get("seeds", []):
		if position.distance_to(Vector2(seed_data.get("position", Vector2.ZERO))) < _geometry_seeding_manual_minimum_distance(recipe):
			_show_status_message("Seeds must respect the current minimum spacing.")
			return
	_record_direct_change()
	bake["seeds"].append({"id": "seed:manual:%d" % ResourceUID.create_id(), "position": position, "origin": "manual", "method": "manual", "provenance": {}})
	_mark_geometry_seeding_bake_edited(bake)


func _on_geometry_seed_move_started(_seed_id: String) -> void:
	if not _editable_geometry_seeding_bake().is_empty():
		_record_direct_change()


func _on_geometry_seed_move_requested(seed_id: String, position: Vector2) -> void:
	var bake := _editable_geometry_seeding_bake()
	var recipe := _geometry_seeding_recipe(selected_asset_id, selected_component_id)
	if bake.is_empty() or not GeometrySeedingService.point_is_valid(_geometry_sampling_bake(selected_asset_id, selected_component_id), position, _geometry_seeding_constraint_clearance(recipe)):
		return
	for other_seed in bake.get("seeds", []):
		if str(other_seed.get("id", "")) != seed_id and position.distance_to(Vector2(other_seed.get("position", Vector2.ZERO))) < _geometry_seeding_manual_minimum_distance(recipe):
			return
	for seed_data in bake.get("seeds", []):
		if str(seed_data.get("id", "")) == seed_id:
			seed_data["position"] = position
			if str(seed_data.get("origin", "generated")) == "generated":
				seed_data["origin"] = "manual_adjusted"
			bake["edited"] = true
			if is_instance_valid(geometry_seeding_workspace):
				geometry_seeding_workspace.seeding_result = bake.duplicate(true)
				geometry_seeding_workspace.status = "Edited"
				geometry_seeding_workspace.queue_redraw()
			return


func _geometry_seeding_constraint_clearance(recipe: Dictionary) -> float:
	if str(recipe.get("method", "")) == GeometrySeedingService.SPINE_FLOW:
		return maxf(float(recipe.get("parameters", {}).get("boundary_clearance", GeometrySeedingService.DEFAULT_BOUNDARY_CLEARANCE)), 0.0)
	return maxf(float(recipe.get("parameters", {}).get("spacing", GeometrySeedingService.DEFAULT_SPACING)), GeometrySeedingService.MIN_SPACING) \
		* maxf(float(recipe.get("parameters", {}).get("constraint_clearance_factor", GeometrySeedingService.DEFAULT_CONSTRAINT_CLEARANCE_FACTOR)), 0.0)


func _geometry_seeding_manual_minimum_distance(recipe: Dictionary) -> float:
	if str(recipe.get("method", "")) == GeometrySeedingService.SPINE_FLOW:
		return minf(float(recipe.get("parameters", {}).get("along_spacing", GeometrySeedingService.DEFAULT_ALONG_SPACING)), float(recipe.get("parameters", {}).get("across_spacing", GeometrySeedingService.DEFAULT_ACROSS_SPACING)))
	return float(recipe.get("parameters", {}).get("spacing", GeometrySeedingService.DEFAULT_SPACING))


func _on_geometry_seed_move_finished(_seed_id: String) -> void:
	var bake := _editable_geometry_seeding_bake()
	if bake.is_empty():
		return
	bake["seed_count"] = bake.get("seeds", []).size()
	_render_outliner()
	_render_inspector()
	_render_context_bar()
	_refresh_geometry_seeding_workspace()


func _on_geometry_seed_remove_requested(seed_id: String) -> void:
	var bake := _editable_geometry_seeding_bake()
	if bake.is_empty():
		return
	var seeds: Array = bake.get("seeds", [])
	for seed_index in range(seeds.size()):
		if str(seeds[seed_index].get("id", "")) == seed_id:
			_record_direct_change()
			seeds.remove_at(seed_index)
			_mark_geometry_seeding_bake_edited(bake)
			return


func _mark_geometry_seeding_bake_edited(bake: Dictionary) -> void:
	bake["seed_count"] = bake.get("seeds", []).size()
	bake["edited"] = true
	_render_outliner()
	_render_inspector()
	_render_context_bar()
	_refresh_geometry_seeding_workspace()


func _render_geometry_meshing_inspector() -> void:
	inspector_content.add_child(_create_inspector_section("Meshing"))
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		inspector_content.add_child(_create_inspector_field_label("Select one Component to generate its derived Mesh."))
		return
	if str(component.get("draw_mode", "")) == "ribbon":
		_render_ribbon_meshing_inspector(component)
		return
	inspector_content.add_child(_create_inspector_field_label(str(component.get("name", "Component"))))
	var source_issues := _component_mesh_source_validation_issues(_get_asset(selected_asset_id), component)
	if not source_issues.is_empty():
		inspector_content.add_child(_create_inspector_section("Source Validation"))
		var source_status := _create_inspector_field_label("Invalid source topology")
		source_status.add_theme_color_override("font_color", Color("#ef8354"))
		inspector_content.add_child(source_status)
		for issue in source_issues:
			var issue_label := _create_inspector_field_label(str(issue))
			issue_label.add_theme_color_override("font_color", Color("#ef8354"))
			inspector_content.add_child(issue_label)
	var recipe := _geometry_meshing_recipe(selected_asset_id, selected_component_id)
	inspector_content.add_child(_create_inspector_section("Input"))
	var sampling_current := _geometry_sampling_bake_is_current(selected_asset_id, selected_component_id, component)
	var sampling_label := _create_inspector_field_label("Sampling · Adaptive: %s" % ("Baked" if sampling_current else "Required / Stale"))
	sampling_label.add_theme_color_override("font_color", Color("#75b88a") if sampling_current else Color("#ef8354"))
	inspector_content.add_child(sampling_label)
	inspector_content.add_child(_create_inspector_field_label("Seeding Source"))
	var seed_option := OptionButton.new()
	var seeding_bakes := _geometry_seeding_bakes(selected_asset_id, selected_component_id)
	for method in GeometrySeedingService.VALID_METHODS:
		var available := seeding_bakes.has(method)
		seed_option.add_item(_geometry_bake_method_label(method) if available else "%s · Required" % _geometry_bake_method_label(method))
		seed_option.set_item_metadata(seed_option.item_count - 1, method)
		seed_option.set_item_disabled(seed_option.item_count - 1, not available)
		if method == str(recipe.get("parameters", {}).get("seeding_method", "")):
			seed_option.select(seed_option.item_count - 1)
	seed_option.disabled = seeding_bakes.is_empty()
	seed_option.item_selected.connect(_on_geometry_meshing_seed_source_selected.bind(seed_option))
	inspector_content.add_child(seed_option)
	if seed_option.item_count == 0:
		var missing_seed := _create_inspector_field_label("Bake at least one Seeding method first.")
		missing_seed.add_theme_color_override("font_color", Color("#ef8354"))
		inspector_content.add_child(missing_seed)
	var input_current := _geometry_meshing_input_is_current(selected_asset_id, selected_component_id, component, recipe)
	var input_label := _create_inspector_field_label("Input Status: %s" % ("Ready" if input_current else "Required / Stale"))
	input_label.add_theme_color_override("font_color", Color("#75b88a") if input_current else Color("#ef8354"))
	inspector_content.add_child(input_label)
	inspector_content.add_child(_create_inspector_section("Method"))
	inspector_content.add_child(_create_inspector_field_label("Constrained Mesh · Automatic"))
	inspector_content.add_child(_create_inspector_section("Parameters"))
	inspector_content.add_child(_create_inspector_field_label("Mesh Character"))
	var character_row := HBoxContainer.new()
	character_row.add_child(_create_inspector_field_label("Structured"))
	var character := HSlider.new()
	character.min_value = 0.0
	character.max_value = 100.0
	character.step = 1.0
	character.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character.set_value_no_signal(float(recipe.get("parameters", {}).get("mesh_character", GeometryMeshingService.DEFAULT_MESH_CHARACTER)) * 100.0)
	character.value_changed.connect(func(value: float) -> void: _on_geometry_meshing_parameter_changed(value / 100.0, "mesh_character"))
	character_row.add_child(character)
	character_row.add_child(_create_inspector_field_label("Organic"))
	inspector_content.add_child(character_row)
	inspector_content.add_child(_create_inspector_field_label("Character: %d%%" % roundi(character.value)))
	inspector_content.add_child(_create_inspector_section("Optimization"))
	var optimize_mesh := CheckBox.new()
	optimize_mesh.text = "Optimize Mesh"
	optimize_mesh.button_pressed = bool(recipe.get("parameters", {}).get("optimize_mesh", GeometryMeshingService.DEFAULT_OPTIMIZE_MESH))
	optimize_mesh.tooltip_text = "Move only free Interior Seeds and accept a pass only when measured Mesh quality improves."
	optimize_mesh.toggled.connect(_on_geometry_meshing_override_changed.bind("optimize_mesh"))
	inspector_content.add_child(optimize_mesh)
	var advanced := Button.new()
	advanced.text = "%s Advanced Optimization" % ("▾" if geometry_meshing_advanced_relaxation_expanded else "▸")
	advanced.toggle_mode = true
	advanced.button_pressed = geometry_meshing_advanced_relaxation_expanded
	advanced.alignment = HORIZONTAL_ALIGNMENT_LEFT
	advanced.focus_mode = Control.FOCUS_NONE
	advanced.toggled.connect(_on_geometry_meshing_advanced_relaxation_toggled)
	inspector_content.add_child(advanced)
	if geometry_meshing_advanced_relaxation_expanded:
		var parameters: Dictionary = recipe.get("parameters", {})
		var relaxation_override := bool(parameters.get("relaxation_override", false))
		inspector_content.add_child(_create_inspector_field_label("Relaxation Strength: %s · %s" % ["Refined" if relaxation_override else "Derived", _format_scale_value(float(parameters.get("relaxation", 0.0)))]))
		var refine_relaxation := CheckBox.new()
		refine_relaxation.text = "Refine Relaxation Strength"
		refine_relaxation.button_pressed = relaxation_override
		refine_relaxation.toggled.connect(_on_geometry_meshing_override_changed.bind("relaxation_override"))
		inspector_content.add_child(refine_relaxation)
		if relaxation_override:
			var relaxation := SpinBox.new()
			relaxation.min_value = 0.0
			relaxation.max_value = 1.0
			relaxation.step = 0.01
			relaxation.custom_arrow_step = 0.01
			relaxation.set_value_no_signal(float(parameters.get("relaxation", GeometryMeshingService.DEFAULT_RELAXATION)))
			relaxation.value_changed.connect(_on_geometry_meshing_parameter_changed.bind("relaxation"))
			relaxation.get_line_edit().text_submitted.connect(_on_geometry_meshing_float_text_submitted.bind(relaxation, "relaxation"))
			relaxation.get_line_edit().focus_exited.connect(_on_geometry_meshing_float_focus_exited.bind(relaxation, "relaxation"))
			inspector_content.add_child(relaxation)
		var passes_override := bool(parameters.get("passes_override", false))
		inspector_content.add_child(_create_inspector_field_label("Relaxation Passes: %s · %d" % ["Refined" if passes_override else "Derived", int(parameters.get("passes", 0))]))
		var refine_passes := CheckBox.new()
		refine_passes.text = "Refine Relaxation Passes"
		refine_passes.button_pressed = passes_override
		refine_passes.toggled.connect(_on_geometry_meshing_override_changed.bind("passes_override"))
		inspector_content.add_child(refine_passes)
		if passes_override:
			var passes := SpinBox.new()
			passes.min_value = 1.0
			passes.max_value = GeometryMeshingService.MAX_PASSES
			passes.step = 1.0
			passes.set_value_no_signal(float(parameters.get("passes", GeometryMeshingService.DEFAULT_PASSES)))
			passes.value_changed.connect(_on_geometry_meshing_parameter_changed.bind("passes"))
			inspector_content.add_child(passes)
	inspector_content.add_child(_create_inspector_section("Constraints"))
	var input := _geometry_meshing_input(selected_asset_id, selected_component_id, recipe)
	var sampling_bake: Dictionary = input.get("sampling", {})
	inspector_content.add_child(_create_inspector_field_label("Outer · Preserved"))
	inspector_content.add_child(_create_inspector_field_label("Holes · Preserved · %d" % int(sampling_bake.get("hole_count", 0))))
	inspector_content.add_child(_create_inspector_field_label("Cuts · Seam · %d" % sampling_bake.get("cuts", []).size()))
	inspector_content.add_child(_create_inspector_section("View"))
	if is_instance_valid(geometry_meshing_workspace):
		for view_option in [
			{"key": "mesh_edges", "label": "Mesh Edges", "value": geometry_meshing_workspace.show_mesh_edges},
			{"key": "seed_points", "label": "Seed Points", "value": geometry_meshing_workspace.show_seed_points},
			{"key": "triangle_fill", "label": "Triangle Fill", "value": geometry_meshing_workspace.show_triangle_fill},
			{"key": "constraints", "label": "Constraints", "value": geometry_meshing_workspace.show_constraints},
			{"key": "optimization", "label": "Optimization", "value": geometry_meshing_workspace.show_optimization},
			{"key": "quality", "label": "Quality", "value": geometry_meshing_workspace.show_quality}
		]:
			var view_toggle := CheckBox.new()
			view_toggle.text = str(view_option["label"])
			view_toggle.button_pressed = bool(view_option["value"])
			view_toggle.toggled.connect(_on_geometry_meshing_view_option_changed.bind(str(view_option["key"])))
			inspector_content.add_child(view_toggle)
	var status := _geometry_meshing_status(selected_asset_id, selected_component_id, component)
	inspector_content.add_child(_create_inspector_section("Result"))
	inspector_content.add_child(_create_inspector_field_label("Status: %s" % status))
	var auto_build_error := str(_component_mesh_reference(selected_asset_id, selected_component_id).get("last_error", ""))
	if not auto_build_error.is_empty():
		var error_label := _create_inspector_field_label("Update Meshes: %s" % auto_build_error)
		error_label.add_theme_color_override("font_color", Color("#ef8354"))
		inspector_content.add_child(error_label)
	var result := geometry_meshing_preview if _geometry_meshing_preview_matches(selected_asset_id, selected_component_id, component) else _geometry_meshing_bake(selected_asset_id, selected_component_id)
	if not result.is_empty():
		inspector_content.add_child(_create_inspector_field_label("Vertices: %d" % int(result.get("vertex_count", 0))))
		inspector_content.add_child(_create_inspector_field_label("Triangles: %d" % int(result.get("triangle_count", 0))))
		var optimization: Dictionary = result.get("optimization", {})
		var quality_before: Dictionary = optimization.get("quality_before", {})
		var quality_after: Dictionary = optimization.get("quality_after", {})
		if not quality_before.is_empty() and not quality_after.is_empty():
			inspector_content.add_child(_create_inspector_field_label("Minimum Angle: %.1f° → %.1f°" % [float(quality_before.get("minimum_angle", 0.0)), float(quality_after.get("minimum_angle", 0.0))]))
			inspector_content.add_child(_create_inspector_field_label("Worst Aspect Ratio: %.2f → %.2f" % [float(quality_before.get("worst_aspect_ratio", 0.0)), float(quality_after.get("worst_aspect_ratio", 0.0))]))
			inspector_content.add_child(_create_inspector_field_label("Moved Seeds: %d · Removed: %d" % [int(optimization.get("moved_seed_count", 0)), int(optimization.get("removed_seed_count", 0))]))
		else:
			inspector_content.add_child(_create_inspector_field_label("Minimum Angle: %.1f°" % float(result.get("minimum_angle", 0.0))))
		inspector_content.add_child(_create_inspector_field_label("Constraints: %s" % ("Valid" if bool(result.get("constraints_valid", false)) else "Invalid")))
		inspector_content.add_child(_create_inspector_field_label("Cut Seam Vertices: %d" % int(result.get("cut_seam_vertex_count", 0))))
	var actions := HBoxContainer.new()
	var bake_button := Button.new()
	bake_button.text = "Calculating…" if status == "Calculating" else "Baked · Component Mesh" if status == "Baked" else "Bake Preview"
	bake_button.custom_minimum_size = Vector2(96, 28)
	bake_button.focus_mode = Control.FOCUS_NONE
	bake_button.disabled = status != "Preview Ready"
	bake_button.pressed.connect(_bake_geometry_meshing)
	geometry_meshing_bake_button = bake_button
	actions.add_child(bake_button)
	inspector_content.add_child(actions)


func _render_ribbon_meshing_inspector(component: Dictionary) -> void:
	inspector_content.add_child(_create_inspector_field_label(str(component.get("name", "Ribbon"))))
	inspector_content.add_child(_create_inspector_section("Ribbon Strip · Automatic"))
	inspector_content.add_child(_create_inspector_field_label("Width: %.1f px (%.2f cm)" % [float(component.get("ribbon_width_px", DEFAULT_RIBBON_WIDTH_PX)), _editor_units_to_world(RibbonMeshService.width_cm(component))]))
	var issues := RibbonMeshService.validation_issues(component)
	var input_status := _create_inspector_field_label("Input: Ready" if issues.is_empty() else "Input: Draft · %s" % issues[0])
	input_status.add_theme_color_override("font_color", Color("#75b88a") if issues.is_empty() else Color("#ef8354"))
	inspector_content.add_child(input_status)
	var status := _geometry_meshing_status(selected_asset_id, selected_component_id, component)
	inspector_content.add_child(_create_inspector_section("Result"))
	inspector_content.add_child(_create_inspector_field_label("Status: %s" % status))
	var auto_build_error := str(_component_mesh_reference(selected_asset_id, selected_component_id).get("last_error", ""))
	if not auto_build_error.is_empty():
		var error_label := _create_inspector_field_label("Update Meshes: %s" % auto_build_error)
		error_label.add_theme_color_override("font_color", Color("#ef8354"))
		inspector_content.add_child(error_label)
	var result := geometry_meshing_preview if _geometry_meshing_preview_matches(selected_asset_id, selected_component_id, component) else _geometry_meshing_bake(selected_asset_id, selected_component_id, RibbonMeshService.METHOD)
	if not result.is_empty():
		inspector_content.add_child(_create_inspector_field_label("Vertices: %d" % int(result.get("vertex_count", 0))))
		inspector_content.add_child(_create_inspector_field_label("Triangles: %d" % int(result.get("triangle_count", 0))))
	var actions := HBoxContainer.new()
	var bake_button := Button.new()
	bake_button.text = "Calculating…" if status == "Calculating" else "Baked · Component Mesh" if status == "Baked" else "Bake Preview"
	bake_button.disabled = status != "Preview Ready"
	bake_button.pressed.connect(_bake_geometry_meshing)
	geometry_meshing_bake_button = bake_button
	actions.add_child(bake_button)
	inspector_content.add_child(actions)


func _on_geometry_meshing_seed_source_selected(index: int, option: OptionButton) -> void:
	if index < 0 or index >= option.item_count:
		return
	var seeding_method := str(option.get_item_metadata(index))
	var current := _geometry_meshing_recipe(selected_asset_id, selected_component_id)
	if str(current.get("parameters", {}).get("seeding_method", "")) == seeding_method:
		return
	_record_direct_change()
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	current["parameters"]["seeding_method"] = seeding_method
	document["meshing"]["recipe"] = GeometryMeshingService.normalize_recipe(current)
	call_deferred("_refresh_geometry_after_recipe_change")


func _on_geometry_meshing_parameter_changed(value: float, parameter_name: String) -> void:
	var current := _geometry_meshing_recipe(selected_asset_id, selected_component_id)
	var normalized: Variant = value
	if parameter_name in ["mesh_character", "relaxation"]:
		normalized = clampf(value, 0.0, 1.0)
	elif parameter_name == "passes":
		normalized = clampi(int(round(value)), 1, GeometryMeshingService.MAX_PASSES)
	if current.get("parameters", {}).get(parameter_name) == normalized:
		return
	_record_coalesced_change()
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	current["parameters"][parameter_name] = normalized
	document["meshing"]["recipe"] = GeometryMeshingService.normalize_recipe(current)
	call_deferred("_refresh_geometry_after_recipe_change")


func _on_geometry_meshing_override_changed(enabled: bool, parameter_name: String) -> void:
	var current := _geometry_meshing_recipe(selected_asset_id, selected_component_id)
	if bool(current.get("parameters", {}).get(parameter_name, false)) == enabled:
		return
	_record_direct_change()
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	current["parameters"][parameter_name] = enabled
	document["meshing"]["recipe"] = GeometryMeshingService.normalize_recipe(current)
	call_deferred("_refresh_geometry_after_recipe_change")


func _on_geometry_meshing_advanced_relaxation_toggled(expanded: bool) -> void:
	geometry_meshing_advanced_relaxation_expanded = expanded
	_render_inspector()


func _on_geometry_meshing_view_option_changed(enabled: bool, option: String) -> void:
	if is_instance_valid(geometry_meshing_workspace):
		geometry_meshing_workspace.set_view_option(option, enabled)


func _on_geometry_meshing_float_text_submitted(text: String, field: SpinBox, parameter_name: String) -> void:
	_commit_geometry_meshing_float_text(text, field, parameter_name)


func _on_geometry_meshing_float_focus_exited(field: SpinBox, parameter_name: String) -> void:
	_commit_geometry_meshing_float_text(field.get_line_edit().text, field, parameter_name)


func _commit_geometry_meshing_float_text(raw_text: String, field: SpinBox, parameter_name: String) -> void:
	var normalized_text := raw_text.strip_edges().replace(",", ".")
	if not normalized_text.is_valid_float():
		field.get_line_edit().text = String.num(field.value, 2)
		return
	var value := clampf(float(normalized_text), field.min_value, field.max_value)
	field.set_value_no_signal(value)
	field.get_line_edit().text = String.num(value, 2)
	_on_geometry_meshing_parameter_changed(value, parameter_name)


func _schedule_geometry_meshing_preview() -> void:
	if selected_asset_id.is_empty() or selected_component_id.is_empty():
		return
	geometry_meshing_preview_revision += 1
	var revision := geometry_meshing_preview_revision
	geometry_meshing_preview = {}
	geometry_meshing_preview_key = _geometry_document_key(selected_asset_id, selected_component_id)
	geometry_meshing_preview_state = "calculating"
	_render_outliner()
	_render_inspector()
	_refresh_geometry_meshing_workspace()
	_generate_geometry_meshing_preview_after_delay(revision)


func _generate_geometry_meshing_preview_after_delay(revision: int) -> void:
	if is_inside_tree():
		await get_tree().create_timer(0.15).timeout
	if revision != geometry_meshing_preview_revision:
		return
	_generate_geometry_meshing_preview()


func _generate_geometry_meshing_preview() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if str(component.get("draw_mode", "")) == "ribbon":
		geometry_meshing_preview_key = _geometry_document_key(selected_asset_id, selected_component_id)
		geometry_meshing_preview = RibbonMeshService.generate(component)
		geometry_meshing_preview_state = "ready" if bool(geometry_meshing_preview.get("valid", false)) else "invalid"
		_show_status_message("Generated %d Ribbon Triangles." % int(geometry_meshing_preview.get("triangle_count", 0)) if bool(geometry_meshing_preview.get("valid", false)) else str(geometry_meshing_preview.get("errors", ["Ribbon Mesh could not be generated."])[0]))
		_render_outliner()
		_render_inspector()
		_refresh_geometry_meshing_workspace()
		return
	var recipe := _geometry_meshing_recipe(selected_asset_id, selected_component_id)
	if not _geometry_meshing_input_is_current(selected_asset_id, selected_component_id, component, recipe):
		geometry_meshing_preview_key = _geometry_document_key(selected_asset_id, selected_component_id)
		geometry_meshing_preview = GeometryMeshingService.generate({}, {}, recipe)
		geometry_meshing_preview_state = "invalid"
		_show_status_message("Bake a current Seeding input before generating a Mesh.")
	else:
		var input := _geometry_meshing_input(selected_asset_id, selected_component_id, recipe)
		geometry_meshing_preview_key = _geometry_document_key(selected_asset_id, selected_component_id)
		geometry_meshing_preview = GeometryMeshingService.generate(input.get("sampling", {}), input.get("seeding", {}), recipe)
		if bool(geometry_meshing_preview.get("valid", false)):
			geometry_meshing_preview_state = "ready"
			_show_status_message("Generated %d Triangles." % int(geometry_meshing_preview.get("triangle_count", 0)))
		else:
			geometry_meshing_preview_state = "invalid"
			var errors: Array = geometry_meshing_preview.get("errors", [])
			_show_status_message(str(errors[0]) if not errors.is_empty() else "Meshing could not be generated.")
	_render_outliner()
	_render_inspector()
	_refresh_geometry_meshing_workspace()


func _bake_geometry_meshing() -> void:
	_bake_geometry_meshing_preview()


func _bake_geometry_meshing_preview() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not _geometry_meshing_preview_matches(selected_asset_id, selected_component_id, component):
		return
	_record_direct_change()
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	var bake := geometry_meshing_preview.duplicate(true)
	bake["bake_id"] = "meshing_bake_%d" % ResourceUID.create_id()
	document["meshing"]["bakes"][str(bake.get("method", ""))] = bake
	selected_geometry_bake_method = str(bake.get("method", ""))
	var asset := _get_asset(selected_asset_id)
	var recipes := _geometry_build_recipes(
		selected_asset_id,
		selected_component_id,
		component,
		_cut_guides_for_component(asset, selected_component_id),
		_geometry_sampling_hole_components(asset, selected_component_id)
	)
	var source_signature := _geometry_build_signature(selected_asset_id, selected_component_id, component, recipes)
	document["component_mesh"] = {
		"bake_id": str(bake.get("bake_id", "")),
		"method": str(bake.get("method", "")),
		"mesh_fingerprint": GeometryUVMappingService.mesh_fingerprint(bake),
		"build_provenance": {
			"schema_version": GeometryAutoBuildService.SIGNATURE_VERSION,
			"source_signature": source_signature,
			"exact_input_hash": GeometryAutoBuildService.exact_signature_hash(source_signature),
			"attempts": 1
		},
		"last_error": "",
		"last_failure_signature": {}
	}
	geometry_meshing_preview = {}
	geometry_meshing_preview_key = ""
	geometry_meshing_preview_state = "idle"
	_show_status_message("Mesh baked for %s." % str(component.get("name", "Component")))
	_render_outliner()
	_render_inspector()
	_refresh_geometry_meshing_workspace()


func _refresh_geometry_meshing_workspace() -> void:
	if not is_instance_valid(geometry_meshing_workspace):
		return
	var asset := _get_asset(selected_asset_id)
	if selected_component_id.is_empty() and not asset.is_empty():
		var overview := _geometry_asset_mesh_overview(selected_asset_id)
		geometry_meshing_workspace.set_context(
			{},
			{},
			overview,
			"Asset Overview · %d/%d Component Meshes" % [int(overview.get("mesh_component_count", 0)), int(overview.get("visible_component_count", 0))]
		)
		return
	var component := _get_component(asset, selected_component_id)
	if component.is_empty():
		geometry_meshing_workspace.clear_context()
		return
	if str(component.get("draw_mode", "")) == "ribbon":
		var ribbon_result := geometry_meshing_preview if _geometry_meshing_preview_matches(selected_asset_id, selected_component_id, component) else _geometry_meshing_bake(selected_asset_id, selected_component_id, RibbonMeshService.METHOD)
		geometry_meshing_workspace.set_context({}, {}, ribbon_result, _geometry_meshing_status(selected_asset_id, selected_component_id, component))
		return
	var recipe := _geometry_meshing_recipe(selected_asset_id, selected_component_id)
	var input := _geometry_meshing_input(selected_asset_id, selected_component_id, recipe)
	var result := geometry_meshing_preview if _geometry_meshing_preview_matches(selected_asset_id, selected_component_id, component) else _geometry_meshing_bake(selected_asset_id, selected_component_id)
	geometry_meshing_workspace.set_context(input.get("sampling", {}), input.get("seeding", {}), result, _geometry_meshing_status(selected_asset_id, selected_component_id, component))


func _render_geometry_uv_mapping_inspector() -> void:
	inspector_content.add_child(_create_inspector_section("UV Mapping"))
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		inspector_content.add_child(_create_inspector_field_label("Select one Component to map its Mesh into UV space."))
		return
	inspector_content.add_child(_create_inspector_field_label(str(component.get("name", "Component"))))
	var recipe := _geometry_uv_mapping_recipe(selected_asset_id, selected_component_id)
	inspector_content.add_child(_create_inspector_field_label("Method"))
	var method_option := OptionButton.new()
	method_option.add_item("Bounds / Planar")
	method_option.set_item_metadata(0, GeometryUVMappingService.BOUNDS_PLANAR)
	method_option.select(0)
	method_option.item_selected.connect(func(_index: int) -> void: _set_geometry_uv_mapping_method(GeometryUVMappingService.BOUNDS_PLANAR))
	inspector_content.add_child(method_option)
	inspector_content.add_child(_create_inspector_section("Input"))
	var component_mesh := _component_mesh_bake(selected_asset_id, selected_component_id)
	inspector_content.add_child(_create_inspector_field_label("Component Mesh: %s" % (_geometry_bake_method_label(str(component_mesh.get("method", ""))) if not component_mesh.is_empty() else "Required / Stale")))
	var input_current := _geometry_uv_mapping_input_is_current(selected_asset_id, selected_component_id, component, recipe)
	var input_label := _create_inspector_field_label("Input Status: %s" % ("Ready" if input_current else "Required / Stale"))
	input_label.add_theme_color_override("font_color", Color("#75b88a") if input_current else Color("#ef8354"))
	inspector_content.add_child(input_label)
	inspector_content.add_child(_create_inspector_section("Parameters"))
	_add_geometry_uv_mapping_float_parameter("Scale", recipe, "scale", GeometryUVMappingService.MIN_SCALE, 100.0)
	_add_geometry_uv_mapping_float_parameter("Rotation", recipe, "rotation", -180.0, 180.0, "°")
	_add_geometry_uv_mapping_float_parameter("Offset U", recipe, "offset_u", -100.0, 100.0)
	_add_geometry_uv_mapping_float_parameter("Offset V", recipe, "offset_v", -100.0, 100.0)
	_add_geometry_uv_mapping_float_parameter("Padding", recipe, "padding", 0.0, GeometryUVMappingService.MAX_PADDING, "", 0.001)
	var preserve_aspect := CheckBox.new()
	preserve_aspect.text = "Preserve Aspect"
	preserve_aspect.button_pressed = bool(recipe.get("parameters", {}).get("preserve_aspect", GeometryUVMappingService.DEFAULT_PRESERVE_ASPECT))
	preserve_aspect.toggled.connect(_on_geometry_uv_mapping_preserve_aspect_changed)
	inspector_content.add_child(preserve_aspect)
	inspector_content.add_child(_create_inspector_section("Preview"))
	var checker_overlay := CheckBox.new()
	checker_overlay.text = "UV Checker Overlay"
	checker_overlay.button_pressed = geometry_uv_mapping_checker_overlay
	checker_overlay.toggled.connect(_on_geometry_uv_mapping_checker_overlay_changed)
	inspector_content.add_child(checker_overlay)
	var status := _geometry_uv_mapping_status(selected_asset_id, selected_component_id, component)
	inspector_content.add_child(_create_inspector_section("Result"))
	inspector_content.add_child(_create_inspector_field_label("Status: %s" % status))
	var result := geometry_uv_mapping_preview if _geometry_uv_mapping_preview_matches(selected_asset_id, selected_component_id, component) else _geometry_uv_mapping_bake(selected_asset_id, selected_component_id)
	if not result.is_empty():
		inspector_content.add_child(_create_inspector_field_label("UV Vertices: %d" % int(result.get("uv_count", 0))))
		inspector_content.add_child(_create_inspector_field_label("Mesh: %s" % _geometry_bake_method_label(str(result.get("mesh_method", "")))))
	if geometry_uv_mapping_preview_key == _geometry_document_key(selected_asset_id, selected_component_id) and not bool(geometry_uv_mapping_preview.get("valid", true)):
		for error_message in geometry_uv_mapping_preview.get("errors", []):
			var error_label := _create_inspector_field_label(str(error_message))
			error_label.add_theme_color_override("font_color", Color("#ef8354"))
			inspector_content.add_child(error_label)
	var persisted_error := str(_get_geometry_document(selected_asset_id, selected_component_id).get("uv_mapping", {}).get("last_error", ""))
	if not persisted_error.is_empty():
		var persisted_error_label := _create_inspector_field_label("Batch: %s" % persisted_error)
		persisted_error_label.add_theme_color_override("font_color", Color("#ef8354"))
		inspector_content.add_child(persisted_error_label)
	var actions := HBoxContainer.new()
	var generate_button := Button.new()
	generate_button.text = "Generate"
	generate_button.custom_minimum_size = Vector2(96, 28)
	generate_button.focus_mode = Control.FOCUS_NONE
	generate_button.disabled = not input_current
	generate_button.pressed.connect(_generate_geometry_uv_mapping_preview)
	actions.add_child(generate_button)
	var bake_button := Button.new()
	bake_button.text = "Bake"
	bake_button.custom_minimum_size = Vector2(76, 28)
	bake_button.focus_mode = Control.FOCUS_NONE
	bake_button.disabled = not _geometry_uv_mapping_preview_matches(selected_asset_id, selected_component_id, component)
	bake_button.pressed.connect(_bake_geometry_uv_mapping_preview)
	actions.add_child(bake_button)
	inspector_content.add_child(actions)


func _add_geometry_uv_mapping_float_parameter(label_text: String, recipe: Dictionary, parameter_name: String, minimum: float, maximum: float, suffix := "", step := 0.01) -> void:
	inspector_content.add_child(_create_inspector_field_label(label_text))
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.custom_arrow_step = step
	field.suffix = suffix
	field.set_value_no_signal(float(recipe.get("parameters", {}).get(parameter_name, minimum)))
	field.value_changed.connect(_on_geometry_uv_mapping_parameter_changed.bind(parameter_name))
	field.get_line_edit().text_submitted.connect(_on_geometry_uv_mapping_float_text_submitted.bind(field, parameter_name))
	field.get_line_edit().focus_exited.connect(_on_geometry_uv_mapping_float_focus_exited.bind(field, parameter_name))
	inspector_content.add_child(field)


func _on_geometry_uv_mapping_mesh_source_selected(index: int, option: OptionButton) -> void:
	if index < 0 or index >= option.item_count:
		return
	_set_geometry_uv_mapping_mesh_source(str(option.get_item_metadata(index)))


func _set_geometry_uv_mapping_mesh_source(mesh_method: String) -> void:
	var component_mesh := _component_mesh_bake(selected_asset_id, selected_component_id)
	if component_mesh.is_empty() or mesh_method != str(component_mesh.get("method", "")):
		return
	var current := _geometry_uv_mapping_recipe(selected_asset_id, selected_component_id)
	var changed := str(current.get("parameters", {}).get("mesh_method", "")) != mesh_method
	var matching_bake := _geometry_uv_mapping_bake(selected_asset_id, selected_component_id, mesh_method, str(current.get("method", "")))
	if changed:
		_record_direct_change()
	current["parameters"]["mesh_method"] = mesh_method
	if not matching_bake.is_empty():
		current["parameters"] = matching_bake.get("parameters", {}).duplicate(true)
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	document["uv_mapping"]["recipe"] = GeometryUVMappingService.normalize_recipe(current)
	selected_geometry_bake_method = GeometryUVMappingService.bake_key(mesh_method, str(current.get("method", ""))) if not matching_bake.is_empty() else ""
	geometry_uv_mapping_preview = {}
	geometry_uv_mapping_preview_key = ""
	_render_outliner()
	_render_inspector()
	_render_context_bar()
	_refresh_geometry_uv_mapping_workspace()
	if matching_bake.is_empty():
		call_deferred("_generate_geometry_uv_mapping_preview")


func _on_geometry_uv_mapping_parameter_changed(value: float, parameter_name: String) -> void:
	var current := _geometry_uv_mapping_recipe(selected_asset_id, selected_component_id)
	var normalized := maxf(value, GeometryUVMappingService.MIN_SCALE) if parameter_name == "scale" else value
	if is_equal_approx(float(current.get("parameters", {}).get(parameter_name, normalized)), normalized):
		return
	_record_coalesced_change()
	current["parameters"][parameter_name] = normalized
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	document["uv_mapping"]["recipe"] = GeometryUVMappingService.normalize_recipe(current)
	call_deferred("_generate_geometry_uv_mapping_preview")


func _on_geometry_uv_mapping_preserve_aspect_changed(enabled: bool) -> void:
	var current := _geometry_uv_mapping_recipe(selected_asset_id, selected_component_id)
	if bool(current.get("parameters", {}).get("preserve_aspect", true)) == enabled:
		return
	_record_direct_change()
	current["parameters"]["preserve_aspect"] = enabled
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	document["uv_mapping"]["recipe"] = GeometryUVMappingService.normalize_recipe(current)
	call_deferred("_generate_geometry_uv_mapping_preview")


func _on_geometry_uv_mapping_checker_overlay_changed(enabled: bool) -> void:
	geometry_uv_mapping_checker_overlay = enabled
	_refresh_geometry_uv_mapping_workspace()


func _on_geometry_uv_mapping_float_text_submitted(text: String, field: SpinBox, parameter_name: String) -> void:
	_commit_geometry_uv_mapping_float_text(text, field, parameter_name)


func _on_geometry_uv_mapping_float_focus_exited(field: SpinBox, parameter_name: String) -> void:
	_commit_geometry_uv_mapping_float_text(field.get_line_edit().text, field, parameter_name)


func _commit_geometry_uv_mapping_float_text(raw_text: String, field: SpinBox, parameter_name: String) -> void:
	var normalized_text := raw_text.strip_edges().replace(",", ".")
	if not normalized_text.is_valid_float():
		field.get_line_edit().text = String.num(field.value, 2)
		return
	var value := clampf(float(normalized_text), field.min_value, field.max_value)
	field.set_value_no_signal(value)
	field.get_line_edit().text = String.num(value, 2)
	_on_geometry_uv_mapping_parameter_changed(value, parameter_name)


func _generate_geometry_uv_mapping_preview() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var recipe := _resolved_geometry_uv_mapping_recipe(selected_asset_id, selected_component_id)
	geometry_uv_mapping_preview_key = _geometry_document_key(selected_asset_id, selected_component_id)
	if not _geometry_uv_mapping_input_is_current(selected_asset_id, selected_component_id, component, recipe):
		geometry_uv_mapping_preview = GeometryUVMappingService.generate({}, recipe)
		_show_status_message("Bake a current Mesh before generating UVs.")
	else:
		geometry_uv_mapping_preview = GeometryUVMappingService.generate(_geometry_uv_mapping_input(selected_asset_id, selected_component_id, recipe), recipe)
		if bool(geometry_uv_mapping_preview.get("valid", false)):
			_show_status_message("Generated %d UV Vertices." % int(geometry_uv_mapping_preview.get("uv_count", 0)))
		else:
			var errors: Array = geometry_uv_mapping_preview.get("errors", [])
			_show_status_message(str(errors[0]) if not errors.is_empty() else "UV Mapping could not be generated.")
	_render_outliner()
	_render_inspector()
	_refresh_geometry_uv_mapping_workspace()


func _bake_geometry_uv_mapping_preview() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not _geometry_uv_mapping_preview_matches(selected_asset_id, selected_component_id, component):
		return
	_record_direct_change()
	var document := _get_geometry_document(selected_asset_id, selected_component_id, true)
	var bake := geometry_uv_mapping_preview.duplicate(true)
	bake["bake_id"] = "uv_bake_%d" % ResourceUID.create_id()
	var key := GeometryUVMappingService.bake_key(str(bake.get("mesh_method", "")), str(bake.get("method", "")))
	document["uv_mapping"]["recipe"] = GeometryUVMappingService.normalize_recipe({"method": bake.get("method", ""), "parameters": bake.get("parameters", {})})
	document["uv_mapping"]["bakes"][key] = bake
	document["uv_mapping"]["last_error"] = ""
	document["uv_mapping"]["last_failure_fingerprint"] = ""
	selected_geometry_bake_method = key
	geometry_uv_mapping_preview = {}
	geometry_uv_mapping_preview_key = ""
	_show_status_message("UV Mapping baked for %s." % str(component.get("name", "Component")))
	_render_outliner()
	_render_inspector()
	_refresh_geometry_uv_mapping_workspace()


func _refresh_geometry_uv_mapping_workspace() -> void:
	if not is_instance_valid(geometry_uv_mapping_workspace):
		return
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		geometry_uv_mapping_workspace.clear_context()
		return
	var mesh_bake := _geometry_uv_mapping_input(selected_asset_id, selected_component_id)
	var result := geometry_uv_mapping_preview if _geometry_uv_mapping_preview_matches(selected_asset_id, selected_component_id, component) else _geometry_uv_mapping_bake(selected_asset_id, selected_component_id)
	geometry_uv_mapping_workspace.set_context(mesh_bake, result, _geometry_uv_mapping_status(selected_asset_id, selected_component_id, component), geometry_uv_mapping_checker_overlay)


func _render_inspector() -> void:
	_clear(inspector_content)
	transform_fields.clear()
	asset_pivot_fields.clear()
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
	if active_module == "Style":
		_render_weighting_inspector()
		return
	if active_module == "Mesh":
		if active_geometry_submodule == "Sampling":
			_render_geometry_sampling_inspector()
		elif active_geometry_submodule == "Seeding":
			_render_geometry_seeding_inspector()
		elif active_geometry_submodule == "Meshing":
			_render_geometry_meshing_inspector()
		elif active_geometry_submodule == "UV Mapping":
			_render_geometry_uv_mapping_inspector()
		else:
			inspector_content.add_child(_create_inspector_section(active_geometry_submodule))
			inspector_content.add_child(_create_inspector_field_label("Placeholder module"))
			inspector_content.add_child(_create_inspector_field_label("Mesh pipeline tooling is planned for a later phase."))
		return
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty():
		return
	if not selected_guide_id.is_empty():
		_render_guide_inspector(asset, _get_guide(asset, selected_guide_id))
		return
	if selected_component_id.is_empty():
		inspector_content.add_child(_create_inspector_field_label("Name"))
		asset_name_editor = _create_name_editor(str(asset["name"]), "Asset name")
		asset_name_editor.text_submitted.connect(_rename_selected_asset)
		asset_name_editor.focus_exited.connect(func() -> void:
			_rename_selected_asset(asset_name_editor.text)
		)
		inspector_content.add_child(asset_name_editor)
		inspector_content.add_child(_create_inspector_section("Asset Transform"))
		var asset_transform_grid := GridContainer.new()
		asset_transform_grid.columns = 2
		asset_transform_grid.add_theme_constant_override("h_separation", 8)
		asset_transform_grid.add_theme_constant_override("v_separation", 4)
		var asset_pivot := _asset_pivot(asset)
		_add_asset_pivot_field(asset_transform_grid, "Pivot X (cm)", _editor_units_to_world(asset_pivot.x), "pivot_x")
		_add_asset_pivot_field(asset_transform_grid, "Pivot Y (cm)", _editor_units_to_world(asset_pivot.y), "pivot_y")
		inspector_content.add_child(asset_transform_grid)
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
			_add_component_debug_inspector(component)
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
		_add_component_debug_inspector(component)
		return
	if active_state == "edit" and active_edit_mode == "edge":
		var selected_edges: Array[Dictionary] = []
		for edge_id in selected_edge_ids:
			var candidate := _get_edge(component, edge_id)
			if not candidate.is_empty():
				selected_edges.append(candidate)
		if selected_edges.is_empty() and not selected_edge_id.is_empty():
			var fallback_edge := _get_edge(component, selected_edge_id)
			if not fallback_edge.is_empty():
				selected_edges.append(fallback_edge)
		inspector_content.add_child(_create_inspector_field_label("%d Edges" % selected_edges.size() if selected_edges.size() > 1 else "Edge"))
		inspector_content.add_child(_create_inspector_section("Edge Settings"))
		if selected_edges.is_empty():
			var edge_hint := _create_inspector_field_label("Select an edge to edit it.")
			edge_hint.add_theme_color_override("font_color", Color("#9aa3b2"))
			inspector_content.add_child(edge_hint)
		else:
			var render_outline := CheckButton.new()
			render_outline.text = "Render Outline"
			render_outline.custom_minimum_size = Vector2(0, 26)
			var all_rendered := true
			for edge in selected_edges:
				all_rendered = all_rendered and bool(edge.get("render_outline", true))
			render_outline.button_pressed = all_rendered
			render_outline.toggled.connect(_on_edge_render_outline_changed)
			inspector_content.add_child(render_outline)
		return
	if active_state == "edit" and active_edit_mode == "face":
		inspector_content.add_child(_create_inspector_field_label("Face"))
		inspector_content.add_child(_create_inspector_section("Face Settings"))
		var face_hint := _create_inspector_field_label("Face selected." if canvas_view.face_selected else "Select the face to edit it.")
		face_hint.add_theme_color_override("font_color", Color("#8fd8f8") if canvas_view.face_selected else Color("#9aa3b2"))
		inspector_content.add_child(face_hint)
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
	inspector_content.add_child(_create_inspector_section("Semantic Key"))
	inspector_content.add_child(_create_inspector_field_label(SemanticRegistry.component_display_name(component, semantic_registry)))
	var excluded_semantics: Array[String] = []
	for other_component in asset.get("components", []):
		if other_component is Dictionary and str(other_component.get("id", "")) != selected_component_id:
			var other_key := str(other_component.get("semantic_key", ""))
			if not other_key.is_empty():
				excluded_semantics.append(other_key)
	inspector_semantic_dropdown = SemanticDropdown.new()
	inspector_semantic_dropdown.configure(semantic_registry.get("semantics", []), str(component.get("semantic_key", "")), excluded_semantics)
	inspector_semantic_dropdown.selection_changed.connect(_set_selected_component_semantic_key)
	inspector_content.add_child(inspector_semantic_dropdown)
	inspector_content.add_child(_create_inspector_section("Hierarchy"))
	inspector_content.add_child(_create_inspector_field_label("Parent Component"))
	var hierarchy_parent_option := OptionButton.new()
	hierarchy_parent_option.custom_minimum_size = Vector2(0, 26)
	hierarchy_parent_option.add_item("Root")
	hierarchy_parent_option.set_item_metadata(0, "")
	for candidate in asset.get("components", []):
		var candidate_id := str(candidate.get("id", ""))
		if candidate_id == selected_component_id or not ComponentHierarchy.can_parent(asset, selected_component_id, candidate_id):
			continue
		hierarchy_parent_option.add_item(str(candidate.get("name", "Component")))
		hierarchy_parent_option.set_item_metadata(hierarchy_parent_option.item_count - 1, candidate_id)
	var hierarchy_parent_id := str(component.get("parent_component_id", ""))
	for option_index in range(hierarchy_parent_option.item_count):
		if str(hierarchy_parent_option.get_item_metadata(option_index)) == hierarchy_parent_id:
			hierarchy_parent_option.select(option_index)
			break
	hierarchy_parent_option.item_selected.connect(_on_component_hierarchy_parent_selected.bind(hierarchy_parent_option))
	inspector_content.add_child(hierarchy_parent_option)
	var draw_mode := str(component.get("draw_mode", "closed_loop"))
	inspector_content.add_child(_create_inspector_field_label("Draw Mode: %s" % _draw_mode_display_name(draw_mode)))
	if _is_reference_component(component) or draw_mode == "closed_loop":
		inspector_content.add_child(_create_inspector_section("Topology"))
		var topology_role_option := OptionButton.new()
		topology_role_option.custom_minimum_size = Vector2(0, 26)
		topology_role_option.add_item("Outer")
		topology_role_option.set_item_metadata(0, "outer")
		topology_role_option.add_item("Hole")
		topology_role_option.set_item_metadata(1, "hole")
		var topology_role := str(component.get("topology_role", "outer"))
		for role_index in range(topology_role_option.item_count):
			if str(topology_role_option.get_item_metadata(role_index)) == topology_role:
				topology_role_option.select(role_index)
				break
		topology_role_option.item_selected.connect(_on_component_topology_role_selected.bind(topology_role_option))
		inspector_content.add_child(topology_role_option)
	var primitive = component.get("primitive", {})
	if primitive is Dictionary and str(primitive.get("type", "")) == "circle":
		inspector_content.add_child(_create_inspector_section("Geometry"))
		inspector_content.add_child(_create_inspector_field_label("Type: Circle"))
		inspector_content.add_child(_create_inspector_field_label("Diameter (cm)"))
		var diameter_field := SpinBox.new()
		diameter_field.min_value = 0.1
		diameter_field.max_value = 100000.0
		diameter_field.step = 0.1
		diameter_field.value = float(primitive.get("diameter_cm", 1.0))
		diameter_field.value_changed.connect(_on_circle_primitive_diameter_changed)
		inspector_content.add_child(diameter_field)
	var mode_issues := PrimitiveGeometryService.validation_issues(component) if draw_mode == "primitive" else BezierTopology.mode_validation_issues(component, true)
	var configured_catch_parent_id := str(component.get("catch_parent_component_id", ""))
	if not configured_catch_parent_id.is_empty() and (configured_catch_parent_id == selected_component_id or _get_component(asset, configured_catch_parent_id).is_empty()):
		mode_issues.append("Catch Parent references a missing Component.")
	inspector_content.add_child(_create_inspector_section("Validation"))
	var mode_status := _create_inspector_field_label("Geometry: Valid" if mode_issues.is_empty() else "Geometry: Draft · %s" % mode_issues[0])
	mode_status.add_theme_color_override("font_color", Color("#75b88a") if mode_issues.is_empty() else Color("#f2c94c"))
	inspector_content.add_child(mode_status)
	if draw_mode == "ribbon":
		inspector_content.add_child(_create_inspector_section("Drawing Reference"))
		inspector_content.add_child(_create_inspector_field_label("Catch Parent"))
		var catch_parent_option := OptionButton.new()
		catch_parent_option.custom_minimum_size = Vector2(0, 26)
		catch_parent_option.add_item("None")
		catch_parent_option.set_item_metadata(0, "")
		for candidate in asset.get("components", []):
			var candidate_id := str(candidate.get("id", ""))
			if candidate_id == selected_component_id:
				continue
			catch_parent_option.add_item(str(candidate.get("name", "Component")))
			catch_parent_option.set_item_metadata(catch_parent_option.item_count - 1, candidate_id)
		var catch_parent_id := str(component.get("catch_parent_component_id", ""))
		for option_index in range(catch_parent_option.item_count):
			if str(catch_parent_option.get_item_metadata(option_index)) == catch_parent_id:
				catch_parent_option.select(option_index)
				break
		catch_parent_option.item_selected.connect(_on_component_catch_parent_selected.bind(catch_parent_option))
		inspector_content.add_child(catch_parent_option)
	if draw_mode == "ribbon":
		inspector_content.add_child(_create_inspector_section("Ribbon"))
		inspector_content.add_child(_create_inspector_field_label("Width (px)"))
		var ribbon_width := SpinBox.new()
		ribbon_width.min_value = RibbonMeshService.MIN_WIDTH_PX
		ribbon_width.max_value = 4096.0
		ribbon_width.step = 0.5
		ribbon_width.custom_arrow_step = 1.0
		ribbon_width.value = float(component.get("ribbon_width_px", DEFAULT_RIBBON_WIDTH_PX))
		ribbon_width.value_changed.connect(_on_component_ribbon_width_changed)
		inspector_content.add_child(ribbon_width)
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
	_add_transform_field(transform_grid, "Pivot X (cm)", _editor_units_to_world(pivot.x), "pivot_x", 0.001)
	_add_transform_field(transform_grid, "Pivot Y (cm)", _editor_units_to_world(pivot.y), "pivot_y", 0.001)
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
		_add_unavailable_motion_guide_field("Motion Guides", "Motion Guide authoring is not available yet.")
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


func _on_component_catch_parent_selected(index: int, option: OptionButton) -> void:
	var asset := _get_asset(selected_asset_id)
	var component := _get_component(asset, selected_component_id)
	if component.is_empty() or index < 0 or index >= option.item_count:
		return
	var parent_id := str(option.get_item_metadata(index))
	if parent_id == selected_component_id or (not parent_id.is_empty() and _get_component(asset, parent_id).is_empty()):
		return
	if str(component.get("catch_parent_component_id", "")) == parent_id:
		return
	_record_direct_change()
	component["catch_parent_component_id"] = parent_id
	_render_canvas_context()


func _on_component_ribbon_width_changed(value: float) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or str(component.get("draw_mode", "")) != "ribbon":
		return
	var width := maxf(value, RibbonMeshService.MIN_WIDTH_PX)
	if is_equal_approx(float(component.get("ribbon_width_px", DEFAULT_RIBBON_WIDTH_PX)), width):
		return
	_record_coalesced_change()
	component["ribbon_width_px"] = width
	_render_outliner()
	if active_module == "Mesh" and active_geometry_submodule == "Meshing":
		_render_inspector()
		_refresh_geometry_meshing_workspace()


func _on_edge_render_outline_changed(enabled: bool) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var edge_ids := selected_edge_ids.duplicate()
	if edge_ids.is_empty() and not selected_edge_id.is_empty():
		edge_ids.append(selected_edge_id)
	var valid_edge_ids: Array[String] = []
	for edge_id_value in edge_ids:
		var edge_id := str(edge_id_value)
		if not _get_edge(component, edge_id).is_empty():
			valid_edge_ids.append(edge_id)
	if valid_edge_ids.is_empty():
		return
	var restored_edge_ids: Array[String] = valid_edge_ids.duplicate()
	_record_direct_change()
	for edge in component.get("edges", []):
		if str(edge.get("id", "")) in valid_edge_ids:
			edge["render_outline"] = enabled
	canvas_view.set_bezier_geometry(component.get("points", []), component.get("edges", []), component.get("chains", []))
	canvas_view.selected_edge_ids = restored_edge_ids.duplicate()
	canvas_view.selected_edge_id = canvas_view.selected_edge_ids[0] if not canvas_view.selected_edge_ids.is_empty() else ""
	canvas_view.queue_redraw()
	_render_inspector()
	_render_canvas_context()
	selected_edge_ids = restored_edge_ids.duplicate()
	selected_edge_id = selected_edge_ids[0]
	canvas_view.selected_edge_ids = restored_edge_ids.duplicate()
	canvas_view.selected_edge_id = canvas_view.selected_edge_ids[0]
	canvas_view.queue_redraw()


func _add_component_debug_inspector(component: Dictionary) -> void:
	inspector_content.add_child(_create_inspector_section("Debug"))
	var show_numbers := CheckButton.new()
	show_numbers.text = "Show Point Numbers"
	show_numbers.focus_mode = Control.FOCUS_NONE
	show_numbers.button_pressed = bool(component.get("show_point_numbers", false))
	show_numbers.toggled.connect(_on_component_debug_point_numbers_toggled)
	inspector_content.add_child(show_numbers)


func _on_component_debug_point_numbers_toggled(enabled: bool) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		return
	_record_direct_change()
	component["show_point_numbers"] = enabled
	canvas_view.set_point_numbers_visible(enabled)
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


func _restore_draw_anchor_selection() -> void:
	var asset := _get_asset(selected_asset_id)
	var subject := _get_guide(asset, selected_guide_id) if not selected_guide_id.is_empty() else _get_component(asset, selected_component_id)
	if subject.is_empty():
		return
	var valid_ids := _valid_selected_point_ids(subject)
	if valid_ids.size() == 1 and BezierTopology.is_open_endpoint(subject, valid_ids[0]):
		selected_point_ids = valid_ids
		selected_point_id = valid_ids[0]
		return
	# Snapshots made before selection state was persisted, or a deleted point,
	# fall back to the end of the most recently authored open Chain.
	var chains: Array = subject.get("chains", [])
	for chain_index in range(chains.size() - 1, -1, -1):
		var chain: Dictionary = chains[chain_index]
		if bool(chain.get("closed", false)):
			continue
		var point_ids: Array = chain.get("point_ids", [])
		if point_ids.is_empty():
			continue
		var endpoint_id := str(point_ids.back())
		if BezierTopology.is_open_endpoint(subject, endpoint_id):
			selected_point_id = endpoint_id
			selected_point_ids = [endpoint_id]
			return
	selected_point_id = ""
	selected_point_ids.clear()


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


func _add_asset_pivot_field(grid: GridContainer, label_text: String, value: float, property_name: String) -> void:
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
	field.set_value_no_signal(value)
	field.custom_minimum_size = Vector2(96, 26)
	field.add_theme_font_size_override("font_size", 11)
	field.value_changed.connect(_on_asset_pivot_property_changed.bind(property_name))
	asset_pivot_fields[property_name] = field
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
	# Arrow buttons move in tenths; the embedded LineEdit accepts the field's
	# configured precision, including thousandths for Component pivots.
	field.step = step
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


func _on_circle_primitive_diameter_changed(value: float) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not PrimitiveGeometryService.has_circle(component):
		return
	_record_direct_change()
	component["primitive"]["diameter_cm"] = maxf(value, 0.1)
	_refresh_component_geometry(component)
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


func _set_selected_component_semantic_key(key: String) -> void:
	var asset := _get_asset(selected_asset_id)
	var component := _get_component(asset, selected_component_id)
	if component.is_empty() or not SemanticRegistry.contains(semantic_registry, key) or SemanticRegistry.key_used_by_other(asset, key, selected_component_id):
		return
	if key == str(component.get("semantic_key", "")):
		return
	_record_direct_change()
	component["semantic_key"] = key
	component["missing_semantic_source"] = ""
	component["name"] = key
	_render_outliner()
	_render_inspector()
	_render_canvas_context()
	_update_runtime_export_button()


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
	_sync_asset_camera(selected_asset_id if active_module == "Create" else "")
	if active_module == "Motion" and active_motion_submodule == "Animation":
		_sync_motion_player_document(_get_asset(selected_asset_id))
	_render_context_bar()
	_render_info_bar()
	if not is_instance_valid(canvas_context_label):
		return
	canvas_view.set_reference_image(null)
	canvas_view.set_paper_frame(Vector2.ZERO, false)
	canvas_view.set_guide_style(false)
	canvas_view.set_point_numbers_visible(false)
	canvas_view.set_catch_parent_component("")
	canvas_view.set_component_draw_mode("closed_loop")
	canvas_view.clear_draw_constraint()
	geometry_sampling_workspace.visible = false
	geometry_seeding_workspace.visible = false
	geometry_meshing_workspace.visible = false
	geometry_uv_mapping_workspace.visible = false
	weighting_workspace.visible = false
	if active_module == "Motion":
		canvas_view.visible = false
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
		return
	motion_path_workspace.visible = false
	motion_act_workspace.visible = false
	motion_sequence_workspace.visible = false
	if active_module == "Mesh":
		motion_workspace.visible = false
		canvas_view.visible = false
		geometry_sampling_workspace.visible = active_geometry_submodule == "Sampling"
		geometry_seeding_workspace.visible = active_geometry_submodule == "Seeding"
		geometry_meshing_workspace.visible = active_geometry_submodule == "Meshing"
		geometry_uv_mapping_workspace.visible = active_geometry_submodule == "UV Mapping"
		if active_geometry_submodule == "Sampling":
			_refresh_geometry_sampling_workspace()
		elif active_geometry_submodule == "Seeding":
			_refresh_geometry_seeding_workspace()
		elif active_geometry_submodule == "Meshing":
			_refresh_geometry_meshing_workspace()
		elif active_geometry_submodule == "UV Mapping":
			_refresh_geometry_uv_mapping_workspace()
		canvas_context_label.text = "" if active_geometry_submodule in ["Sampling", "Seeding", "Meshing", "UV Mapping"] else "Mesh → %s · Placeholder" % active_geometry_submodule
		return
	if active_module == "Style":
		motion_workspace.visible = false
		canvas_view.visible = false
		weighting_workspace.visible = true
		_refresh_weighting_workspace()
		canvas_context_label.text = ""
		return
	motion_workspace.visible = false
	canvas_view.visible = true
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
	if not selected_guide_id.is_empty():
		var selected_guide := _get_guide(asset, selected_guide_id)
		if not selected_guide.is_empty():
			_render_spine_canvas(asset, selected_guide, active_state == "draw" and active_draw_tool == "spine")
			return
	if selected_component_id.is_empty():
		canvas_context_label.text = "Asset: %s" % str(asset["name"])
		canvas_view.set_context(str(asset["name"]))
		canvas_view.set_interaction_state("asset")
		canvas_view.set_asset_pivot(_asset_pivot(asset))
		canvas_view.set_paper_frame(_paper_frame_size(paper_level) if paper_level >= 0 else Vector2.ZERO, paper_level >= 0)
		canvas_view.set_tool_mode("")
		canvas_view.set_component_transform({})
		canvas_view.set_reference_shapes(_build_reference_shapes(asset, "", selected_component_id))
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
		canvas_view.set_reference_shapes(_build_reference_shapes(asset, "", selected_component_id))
		canvas_view.set_display_polygon([])
		canvas_view.set_bezier_geometry([], [], [])
		canvas_view.call_deferred("grab_focus")
		return
	if _is_reference_component(component):
		canvas_context_label.text = "Reference: %s" % str(component.get("name", "Reference"))
		canvas_view.set_context(str(component.get("name", "Reference")))
		canvas_view.set_interaction_state("transform")
		canvas_view.set_tool_mode("")
		canvas_view.set_component_transform(ComponentHierarchy.world_transform_record(asset, selected_component_id))
		canvas_view.set_reference_shapes(_build_reference_shapes(asset))
		canvas_view.set_display_polygon([])
		canvas_view.set_bezier_geometry([], [], [])
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
	var component_transform := ComponentHierarchy.world_transform_record(asset, selected_component_id)
	component_transform["visibility"] = bool(asset.get("visibility", true)) and bool(component.get("visibility", true))
	component_transform["z_index"] = int(component.get("z_index", 0))
	canvas_view.set_component_transform(component_transform)
	canvas_view.set_reference_shapes(_build_reference_shapes(asset, selected_component_id))
	canvas_view.set_component_draw_mode(str(component.get("draw_mode", "closed_loop")))
	canvas_view.set_point_numbers_visible(bool(component.get("show_point_numbers", false)))
	var catch_parent_id := str(component.get("parent_component_id", ""))
	if catch_parent_id.is_empty() and str(component.get("draw_mode", "closed_loop")) == "ribbon":
		catch_parent_id = str(component.get("catch_parent_component_id", ""))
	canvas_view.set_catch_parent_component(catch_parent_id)
	BezierGeometry.resolve_auto_handles(component.get("points", []), component.get("chains", []))
	_refresh_component_geometry(component)
	canvas_view.set_selected_point_ids(selected_point_ids)
	canvas_view.set_selected_edge_id(selected_edge_id)
	canvas_view.call_deferred("grab_focus")


func _render_spine_canvas(asset: Dictionary, guide: Dictionary, drawing: bool) -> void:
	var target_component_id := str(guide.get("scope", {}).get("component_id", ""))
	var target_component := _get_component(asset, target_component_id)
	var type_name := AssetGuide.display_name(str(guide.get("guide_type", AssetGuide.SAMPLER_SPINE)))
	var guide_name := _guide_display_name(asset, guide)
	canvas_context_label.text = "%s: %s%s" % [type_name, guide_name, " · Draft" if drawing else ""]
	canvas_view.set_context(guide_name)
	canvas_view.set_paper_frame(Vector2.ZERO, false)
	canvas_view.set_guide_style(true)
	canvas_view.set_guide_color(AssetGuide.color(str(guide.get("guide_type", AssetGuide.SAMPLER_SPINE))))
	canvas_view.set_reference_shapes(_build_reference_shapes(asset, "", target_component_id))
	canvas_view.set_display_polygon([])
	BezierGeometry.resolve_auto_handles(guide.get("points", []), guide.get("chains", []))
	canvas_view.set_bezier_geometry(guide.get("points", []), guide.get("edges", []), guide.get("chains", []))
	canvas_view.set_selected_point_ids(selected_point_ids)
	if target_component.is_empty():
		canvas_view.set_component_transform(_default_component_transform())
	else:
		var target_transform := ComponentHierarchy.world_transform_record(asset, target_component_id)
		target_transform["visibility"] = bool(asset.get("visibility", true)) and bool(guide.get("visibility", true))
		canvas_view.set_component_transform(target_transform)
	if drawing:
		var boundaries := _component_guide_boundaries(target_component)
		canvas_view.set_draw_constraint(boundaries.get("outer", PackedVector2Array()), boundaries.get("holes", []))
		canvas_view.set_interaction_state("draw")
		canvas_view.set_tool_mode("spine")
		canvas_view.set_draw_point_mode(active_draw_point_mode)
	elif active_state == "edit" and not selected_guide_id.is_empty():
		canvas_view.set_interaction_state("edit")
		canvas_view.set_tool_mode("")
		canvas_view.set_edit_mode("point")
		canvas_view.set_edit_handles_enabled(edit_bezier_handles)
		canvas_view.set_edit_point_set_enabled(false)
	else:
		canvas_view.set_interaction_state("")
		canvas_view.set_tool_mode("")
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
		var target_height := ToolUnits.from_centimeters(float(reference_image.get("target_height_cm", 13.0)))
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


func _build_reference_shapes(asset: Dictionary, excluded_component_id := "", emphasized_component_id := "") -> Array:
	var shapes: Array = []
	var asset_is_visible := bool(asset.get("visibility", true))
	for component in asset["components"]:
		if str(component.get("type", "component")) == "guide":
			continue
		if str(component["id"]) == excluded_component_id:
			continue
		if _is_reference_component(component):
			shapes.append_array(_reference_asset_shapes(asset, component, emphasized_component_id))
			continue
		var primitive_component := PrimitiveGeometryService.has_circle(component)
		shapes.append({
			"id": str(component["id"]),
			"points": PrimitiveGeometryService.contour(component) if primitive_component else BezierTopology.outer_control_polygon(component),
			"bezier_points": component.get("points", []).duplicate(true),
			"edges": component.get("edges", []).duplicate(true),
			"chains": component.get("chains", []).duplicate(true),
			"closed": primitive_component or BezierTopology.outer_chain_closed(component),
			"transform": ComponentHierarchy.world_transform_record(asset, str(component.get("id", ""))),
			"visibility": asset_is_visible and bool(component.get("visibility", true)),
			"z_index": int(component.get("z_index", 0)),
			"emphasized": str(component["id"]) == emphasized_component_id,
			"topology_role": str(component.get("topology_role", "outer"))
		})
	return shapes


func _is_reference_component(component: Dictionary) -> bool:
	return str(component.get("type", "component")) == "reference"


func _normalized_component_name(component: Dictionary) -> String:
	return SemanticRegistry.component_display_name(component, semantic_registry)


func _component_outliner_name(asset: Dictionary, component: Dictionary) -> String:
	var name := _normalized_component_name(component)
	if not _is_reference_component(component):
		return name
	var parent := _get_component(asset, str(component.get("parent_component_id", "")))
	if not parent.is_empty():
		return "%s → %s" % [str(parent.get("name", "Component")), name]
	return name


func _reference_asset_shapes(target_asset: Dictionary, reference: Dictionary, emphasized_component_id: String) -> Array:
	var result: Array = []
	var source_asset := _get_asset(str(reference.get("source_asset_id", "")))
	if source_asset.is_empty() or source_asset == target_asset:
		return result
	var reference_transform := ComponentHierarchy.world_transform_record(target_asset, str(reference.get("id", "")))
	for source_component in source_asset.get("components", []):
		if _is_reference_component(source_component) or not bool(source_component.get("visibility", true)):
			continue
		var points: Array[Vector2] = []
		var source_transform := ComponentHierarchy.world_transform_record(source_asset, str(source_component.get("id", "")))
		var contour := PrimitiveGeometryService.contour(source_component) if PrimitiveGeometryService.has_circle(source_component) else BezierTopology.outer_control_polygon(source_component)
		for point in contour:
			points.append(_transform_point(_transform_point(Vector2(point), source_transform), reference_transform))
		result.append({"id": str(reference.get("id", "")), "points": points, "closed": PrimitiveGeometryService.has_circle(source_component) or BezierTopology.outer_chain_closed(source_component), "transform": _default_component_transform(), "visibility": bool(target_asset.get("visibility", true)) and bool(reference.get("visibility", true)), "z_index": int(reference.get("z_index", 0)), "emphasized": str(reference.get("id", "")) == emphasized_component_id, "topology_role": str(reference.get("topology_role", "outer"))})
	return result


func _transform_point(point: Vector2, transform: Dictionary) -> Vector2:
	var pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
	return Vector2(transform.get("position", Vector2.ZERO)) + ((point - pivot) * Vector2(transform.get("scale", Vector2.ONE))).rotated(deg_to_rad(float(transform.get("rotation", 0.0))))


func _component_guide_boundaries(component: Dictionary) -> Dictionary:
	var outer := PackedVector2Array()
	var holes: Array = []
	if component.is_empty():
		return {"outer": outer, "holes": holes}
	if PrimitiveGeometryService.has_circle(component):
		return {"outer": PackedVector2Array(PrimitiveGeometryService.contour(component)), "holes": holes}
	var resolved_component := component.duplicate(true)
	BezierGeometry.resolve_auto_handles(resolved_component.get("points", []), resolved_component.get("chains", []))
	for chain_data in resolved_component.get("chains", []):
		if not chain_data is Dictionary or not bool(chain_data.get("closed", false)):
			continue
		var polygon := BezierGeometry.flatten_chain(resolved_component, chain_data)
		if polygon.size() < 3:
			continue
		var role := str(chain_data.get("topology_role", "outer"))
		if role == "outer" and outer.is_empty():
			outer = polygon
		elif role == "hole":
			holes.append(polygon)
	return {"outer": outer, "holes": holes}


func _refresh_component_geometry(component: Dictionary) -> void:
	if component.is_empty() or not is_instance_valid(canvas_view):
		return
	var contour := PrimitiveGeometryService.contour(component) if PrimitiveGeometryService.has_circle(component) else BezierTopology.outer_control_polygon(component)
	canvas_view.set_display_polygon(contour, PrimitiveGeometryService.has_circle(component) or BezierTopology.outer_chain_closed(component))
	canvas_view.set_bezier_geometry(component.get("points", []), component.get("edges", []), component.get("chains", []))


func _on_primitive_placed(center: Vector2, diameter_cm: float) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or str(component.get("draw_mode", "")) != "primitive" or not component.get("primitive", {}).is_empty():
		return
	_record_direct_change()
	component["geometry_source"] = "primitive"
	component["primitive"] = {"type": "circle", "diameter_cm": maxf(diameter_cm, 0.1), "center": center}
	_set_active_state("")
	_set_active_context_command("")
	_refresh_component_geometry(component)
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _on_primitive_center_changed(center: Vector2) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not PrimitiveGeometryService.has_circle(component):
		return
	var primitive: Dictionary = component["primitive"]
	if PrimitiveGeometryService.center(component).is_equal_approx(center):
		return
	_record_direct_change()
	primitive["center"] = center
	component["primitive"] = primitive
	_refresh_component_geometry(component)


func _on_primitive_preview_cancelled() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if str(component.get("draw_mode", "")) != "primitive" or not component.get("primitive", {}).is_empty():
		return
	_set_active_state("")
	_set_active_context_command("")
	_render_canvas_context()


func _on_bezier_point_added(position: Vector2, point_mode: String = "linear", drawn_handle_out: Vector2 = Vector2.ZERO) -> void:
	if active_draw_tool == "spine" and not selected_guide_id.is_empty():
		var guide := _get_guide(_get_asset(selected_asset_id), selected_guide_id)
		if guide.is_empty():
			return
		_record_direct_change()
		BezierTopology.add_point(guide, canvas_view.constrain_draw_position(position), "aligned", Vector2.ZERO)
		BezierGeometry.resolve_auto_handles(guide.get("points", []), guide.get("chains", []))
		canvas_view.set_bezier_geometry(guide.get("points", []), guide.get("edges", []), guide.get("chains", []))
		_render_inspector()
		return
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		return
	var anchor_id := ""
	if selected_point_ids.size() == 1 and BezierTopology.is_open_endpoint(component, str(selected_point_ids[0])):
		anchor_id = str(selected_point_ids[0])
	if anchor_id.is_empty() and not component.get("chains", []).is_empty():
		_show_status_message("A Component may contain only one Chain · select an endpoint to continue")
		return
	_record_direct_change()
	var resolved_mode := point_mode if point_mode in BezierTopology.VALID_POINT_MODES else active_draw_point_mode
	var point_id := BezierTopology.add_point_from(component, anchor_id, position, resolved_mode, drawn_handle_out) if not anchor_id.is_empty() else BezierTopology.start_chain(component, position, resolved_mode, drawn_handle_out)
	if point_id.is_empty():
		return
	selected_point_id = point_id
	selected_point_ids = [point_id]
	_refresh_component_geometry(component)
	canvas_view.set_selected_point_id(point_id)


func _on_bezier_endpoint_connection_requested(anchor_point_id: String, target_point_id: String) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or str(component.get("draw_mode", "closed_loop")) != "closed_loop":
		return
	var anchor_chain := BezierTopology.chain_for_point(component.get("chains", []), anchor_point_id)
	var target_chain := BezierTopology.chain_for_point(component.get("chains", []), target_point_id)
	if anchor_chain.is_empty() or target_chain.is_empty() or anchor_point_id == target_point_id:
		return
	if str(anchor_chain.get("id", "")) == str(target_chain.get("id", "")):
		_record_direct_change()
		if BezierTopology.close_chain(component, str(anchor_chain.get("id", ""))):
			_refresh_component_geometry(component)
		return
	_record_direct_change()
	if BezierTopology.join_open_chain_endpoints(component, anchor_point_id, target_point_id):
		_refresh_component_geometry(component)
		_show_status_message("Open Chains connected · Close the remaining endpoints to finish the Loop")


func _on_bezier_chain_closed() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or str(component.get("draw_mode", "closed_loop")) != "closed_loop":
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


func _on_asset_pivot_changed(pivot: Vector2) -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty() or not selected_component_id.is_empty():
		return
	_record_coalesced_change()
	asset["asset_pivot"] = pivot
	for property_name in ["pivot_x", "pivot_y"]:
		var field = asset_pivot_fields.get(property_name)
		if not is_instance_valid(field):
			continue
		var value := _editor_units_to_world(pivot.x if property_name == "pivot_x" else pivot.y)
		field.set_value_no_signal(value)


func _on_transform_changed(transform: Dictionary) -> void:
	var asset := _get_asset(selected_asset_id)
	var component := _get_component(asset, selected_component_id)
	if not component.is_empty():
		_record_coalesced_change()
		var local_transform := ComponentHierarchy.local_transform_from_world_record(asset, selected_component_id, transform)
		component["transform"] = local_transform
		var transform_position: Vector2 = local_transform.get("position", Vector2.ZERO)
		var transform_scale: Vector2 = local_transform.get("scale", Vector2.ONE)
		var pivot: Vector2 = local_transform.get("pivot", Vector2.ZERO)
		var values := {
			"position_x": _editor_units_to_world(transform_position.x),
			"position_y": _editor_units_to_world(transform_position.y),
			"rotation": float(local_transform.get("rotation", 0.0)),
			"scale_x": transform_scale.x,
			"scale_y": transform_scale.y,
			"pivot_x": _editor_units_to_world(pivot.x),
			"pivot_y": _editor_units_to_world(pivot.y)
		}
		for property_name in values:
			var field = transform_fields.get(property_name)
			if is_instance_valid(field):
				field.set_value_no_signal(float(values[property_name]))
		# A moved Parent also changes every visible Child reference immediately.
		# A selected Symbol Reference must remain visible while it is being dragged;
		# excluding its own ID would remove exactly the shape being transformed.
		var selected_reference_id := selected_component_id if _is_reference_component(component) else ""
		var excluded_reference_id := "" if _is_reference_component(component) else selected_component_id
		canvas_view.set_reference_shapes(_build_reference_shapes(asset, excluded_reference_id, selected_reference_id))


func _on_component_hierarchy_parent_selected(index: int, option: OptionButton) -> void:
	var asset := _get_asset(selected_asset_id)
	var component := _get_component(asset, selected_component_id)
	if asset.is_empty() or component.is_empty() or index < 0:
		return
	var new_parent_id := str(option.get_item_metadata(index))
	if str(component.get("parent_component_id", "")) == new_parent_id or not ComponentHierarchy.can_parent(asset, selected_component_id, new_parent_id):
		return
	var world_transform := ComponentHierarchy.world_transform_record(asset, selected_component_id)
	_record_direct_change()
	component["parent_component_id"] = new_parent_id
	component["transform"] = ComponentHierarchy.local_transform_from_world_record(asset, selected_component_id, world_transform)
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _on_component_topology_role_selected(index: int, option: OptionButton) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or index < 0 or index >= option.item_count:
		return
	var role := str(option.get_item_metadata(index))
	if role not in ["outer", "hole"] or role == str(component.get("topology_role", "outer")):
		return
	_record_direct_change()
	component["topology_role"] = role
	for chain in component.get("chains", []):
		if chain is Dictionary and str(chain.get("topology_role", "outer")) in ["outer", "hole"]:
			chain["topology_role"] = role
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _detach_component(asset_id: String, component_id: String) -> void:
	var asset := _get_asset(asset_id)
	var component := _get_component(asset, component_id)
	if asset.is_empty() or component.is_empty():
		return
	var old_parent_id := str(component.get("parent_component_id", ""))
	if old_parent_id.is_empty():
		return
	var old_parent := _get_component(asset, old_parent_id)
	var new_parent_id := str(old_parent.get("parent_component_id", ""))
	var world_transform := ComponentHierarchy.world_transform_record(asset, component_id)
	_record_direct_change()
	component["parent_component_id"] = new_parent_id
	component["transform"] = ComponentHierarchy.local_transform_from_world_record(asset, component_id, world_transform)
	if str(component.get("catch_parent_component_id", "")) == old_parent_id:
		component["catch_parent_component_id"] = ""
	selected_asset_id = asset_id
	selected_component_id = component_id
	selected_guide_id = ""
	_show_status_message("Detached %s from Parent." % str(component.get("name", "Component")))
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


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
	bezier_point_move_guide_id = selected_guide_id
	var subject := _get_guide(_get_asset(selected_asset_id), selected_guide_id) if not selected_guide_id.is_empty() else _get_component(_get_asset(selected_asset_id), selected_component_id)
	if subject.is_empty():
		return
	for point_id_value in point_ids:
		var point_id := str(point_id_value)
		var point := BezierTopology.point_by_id(subject.get("points", []), point_id)
		if not point.is_empty():
			bezier_point_move_start_positions[point_id] = Vector2(point.get("position", Vector2.ZERO))


func _on_bezier_points_moved(point_ids: Array, world_delta: Vector2) -> void:
	var asset := _get_asset(selected_asset_id)
	var guide := _get_guide(asset, selected_guide_id) if not selected_guide_id.is_empty() else {}
	var subject := guide if not guide.is_empty() else _get_component(asset, selected_component_id)
	if subject.is_empty() or point_ids.is_empty():
		return
	if bezier_point_move_component_id != selected_component_id or bezier_point_move_guide_id != selected_guide_id or bezier_point_move_start_positions.is_empty():
		_on_bezier_points_move_started(point_ids)
	var transform_component_id := str(guide.get("scope", {}).get("component_id", "")) if not guide.is_empty() else selected_component_id
	var transform := ComponentHierarchy.world_transform_record(asset, transform_component_id)
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
	var points: Array = subject.get("points", [])
	for point_id_value in point_ids:
		var point_id := str(point_id_value)
		var point := BezierTopology.point_by_id(points, point_id)
		if not point.is_empty() and bezier_point_move_start_positions.has(point_id):
			point["position"] = Vector2(bezier_point_move_start_positions[point_id]) + local_delta
	BezierGeometry.resolve_auto_handles(points, subject.get("chains", []))
	if guide.is_empty():
		_refresh_component_geometry(subject)
	else:
		canvas_view.set_bezier_geometry(subject.get("points", []), subject.get("edges", []), subject.get("chains", []))
	_render_inspector()


func _on_bezier_handle_changed(point_id: String, handle_side: String, value: Vector2) -> void:
	var guide := _get_guide(_get_asset(selected_asset_id), selected_guide_id) if not selected_guide_id.is_empty() else {}
	var subject := guide if not guide.is_empty() else _get_component(_get_asset(selected_asset_id), selected_component_id)
	var point := BezierTopology.point_by_id(subject.get("points", []), point_id)
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
	BezierGeometry.resolve_auto_handles(subject.get("points", []), subject.get("chains", []))
	if guide.is_empty():
		_refresh_component_geometry(subject)
	else:
		canvas_view.set_bezier_geometry(subject.get("points", []), subject.get("edges", []), subject.get("chains", []))


func _on_bezier_edge_insert_requested(edge_id: String, t: float) -> void:
	var guide := _get_guide(_get_asset(selected_asset_id), selected_guide_id) if not selected_guide_id.is_empty() else {}
	if not guide.is_empty():
		if BezierTopology.edge_by_id(guide.get("edges", []), edge_id).is_empty():
			return
		_record_direct_change()
		var guide_point_id := BezierTopology.insert_point_on_edge(guide, edge_id, t)
		if guide_point_id.is_empty():
			return
		selected_point_id = guide_point_id
		selected_point_ids = [guide_point_id]
		canvas_view.set_bezier_geometry(guide.get("points", []), guide.get("edges", []), guide.get("chains", []))
		canvas_view.set_selected_point_id(guide_point_id)
		_render_inspector()
		return
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
	var guide := _get_guide(_get_asset(selected_asset_id), selected_guide_id) if not selected_guide_id.is_empty() else {}
	var subject := guide if not guide.is_empty() else _get_component(_get_asset(selected_asset_id), selected_component_id)
	var points: Array = subject.get("points", [])
	if subject.is_empty() or BezierTopology.point_by_id(points, point_id).is_empty():
		return
	var chain := BezierTopology.chain_for_point(subject.get("chains", []), point_id)
	if chain.is_empty():
		return
	var point_ids: Array = chain.get("point_ids", [])
	var closed := bool(chain.get("closed", false))
	var deleted_point_index := point_ids.find(point_id)
	if deleted_point_index < 0 or (closed and point_ids.size() <= 3):
		return
	if record_history:
		_record_direct_change()
	if not BezierTopology.delete_point(subject, point_id):
		return
	points = subject.get("points", [])
	var next_selection_index := mini(deleted_point_index, points.size() - 1)
	selected_point_id = str(points[next_selection_index].get("id", "")) if next_selection_index >= 0 else ""
	selected_point_ids.clear()
	if not selected_point_id.is_empty():
		selected_point_ids.append(selected_point_id)
	if guide.is_empty():
		_refresh_component_geometry(subject)
	else:
		canvas_view.set_bezier_geometry(subject.get("points", []), subject.get("edges", []), subject.get("chains", []))
	canvas_view.set_selected_point_id(selected_point_id)
	_render_inspector()


func _on_bezier_points_delete_requested(point_ids: Array) -> void:
	if point_ids.is_empty():
		return
	var guide := _get_guide(_get_asset(selected_asset_id), selected_guide_id) if not selected_guide_id.is_empty() else {}
	var subject := guide if not guide.is_empty() else _get_component(_get_asset(selected_asset_id), selected_component_id)
	if subject.is_empty():
		return
	var valid_point_ids := _valid_selected_point_ids(subject)
	if valid_point_ids.is_empty():
		return
	_record_direct_change()
	BezierTopology.delete_points(subject, valid_point_ids)
	selected_point_id = ""
	selected_point_ids.clear()
	canvas_view.clear_selection()
	if guide.is_empty():
		_refresh_component_geometry(subject)
	else:
		canvas_view.set_bezier_geometry(subject.get("points", []), subject.get("edges", []), subject.get("chains", []))
	_render_inspector()


func _on_point_selection_changed(point_id: String) -> void:
	selected_point_id = point_id
	if active_edit_mode == "point":
		selected_edge_id = ""
		selected_edge_ids.clear()
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
		selected_edge_ids.clear()
		_render_inspector()
		_render_context_bar()


func _on_edge_selection_changed(edge_id: String) -> void:
	selected_edge_id = edge_id
	if edge_id.is_empty():
		selected_edge_ids.clear()
	elif edge_id not in selected_edge_ids:
		selected_edge_ids = [edge_id]
	_render_inspector()
	_render_context_bar()


func _on_edge_selection_set_changed(edge_ids: Array) -> void:
	selected_edge_ids.clear()
	for edge_id_value in edge_ids:
		var edge_id := str(edge_id_value)
		if not edge_id.is_empty() and edge_id not in selected_edge_ids:
			selected_edge_ids.append(edge_id)
	selected_edge_id = selected_edge_ids[0] if not selected_edge_ids.is_empty() else ""
	_render_inspector()
	_render_context_bar()


func _on_face_selection_changed(selected: bool) -> void:
	_render_inspector()


func _get_asset(asset_id: String) -> Dictionary:
	for asset in assets:
		if str(asset["id"]) == asset_id:
			return asset
	return {}


func _normalize_asset_type(value) -> String:
	var normalized := str(value).strip_edges().to_lower()
	return normalized if normalized in ["character", "props", "terrain", "icon", "symbols"] else "character"


func _asset_type(asset: Dictionary) -> String:
	return _normalize_asset_type(asset.get("asset_type", "character"))


func _create_submodule_asset_type(submodule: String) -> String:
	return _normalize_asset_type(submodule)


func _asset_type_create_submodule(asset_type: String) -> String:
	match _normalize_asset_type(asset_type):
		"props":
			return "Props"
		"terrain":
			return "Terrain"
		"icon":
			return "Icon"
		"symbols":
			return "Symbols"
		_:
			return "Character"


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
		if str(component.get("type", "component")) != "guide" and str(component["id"]) == component_id:
			return component
	return {}


func _get_guide(asset: Dictionary, guide_id: String) -> Dictionary:
	if asset.is_empty():
		return {}
	for guide in asset.get("guides", []):
		if str(guide.get("id", "")) == guide_id:
			return guide
	return {}


func _get_edge(component: Dictionary, edge_id: String) -> Dictionary:
	if component.is_empty():
		return {}
	for edge in component.get("edges", []):
		if str(edge.get("id", "")) == edge_id:
			return edge
	return {}


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _clear_context_bar() -> void:
	for child in context_bar.get_children():
		context_bar.remove_child(child)
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
	if active_module == "Motion":
		selected_component_id = ""
		active_state = ""
		selected_geometry_bake_method = ""
		if active_motion_submodule == "Animation" and not _get_asset(selected_asset_id).is_empty():
			motion_selection.select_asset(selected_asset_id)
	if active_module == "Mesh":
		active_state = ""
		active_geometry_submodule = active_geometry_submodule if active_geometry_submodule in GEOMETRY_SUBMODULES else "Sampling"
	var pressed_section := _find_section(_module_name)
	for section in module_sections:
		section.set_expanded(true)
		if section != pressed_section:
			section.set_active_submodule("")
	if pressed_section != null and not pressed_section.active_submodule.is_empty():
		if active_module == "Create":
			_set_create_submodule_context(pressed_section.active_submodule)
		elif active_module == "Mesh":
			active_geometry_submodule = pressed_section.active_submodule if pressed_section.active_submodule in GEOMETRY_SUBMODULES else "Sampling"
			pressed_section.set_active_submodule(active_geometry_submodule)
		elif active_module == "Style":
			active_style_submodule = pressed_section.active_submodule if pressed_section.active_submodule in STYLE_SUBMODULES else "Weighting"
			pressed_section.set_active_submodule(active_style_submodule)
	elif active_module == "Create":
		_set_create_submodule_context(active_create_submodule)
	elif active_module == "Mesh":
		_set_active_module_visual("Mesh", active_geometry_submodule)
	elif active_module == "Style":
		_set_active_module_visual("Style", active_style_submodule)
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _find_section(module_name: String) -> ModuleSection:
	for section in module_sections:
		if section.module_name == module_name:
			return section
	return null


func _set_active_module_visual(module_name: String, submodule: String) -> void:
	for module_section in module_sections:
		module_section.set_expanded(true)
		module_section.set_active_submodule(submodule if module_section.module_name == module_name else "")


func _select_submodule(module_name: String, submodule: String, section: ModuleSection) -> void:
	if active_draw_tool == "spine":
		_stop_guide_draw_state()
	if module_name != "Mesh" or submodule != "Sampling":
		geometry_sampling_preview_revision += 1
		geometry_sampling_input_refresh_pending = false
	if module_name != "Mesh" or submodule != "Seeding":
		geometry_seeding_preview_revision += 1
	if module_name != "Mesh" or submodule != "Meshing":
		geometry_meshing_preview_revision += 1
	_set_active_module_visual(module_name, submodule)
	active_module = module_name
	if module_name == "Create":
		_set_create_submodule_context(submodule)
		_render_outliner()
		_render_inspector()
		_render_context_bar()
		_render_canvas_context()
	elif module_name == "Mesh" and submodule in GEOMETRY_SUBMODULES:
		active_geometry_submodule = submodule
		active_module = "Mesh"
		_set_geometry_command_state("")
		selected_geometry_bake_method = ""
		active_state = ""
		_render_outliner()
		_render_inspector()
		_render_canvas_context()
		if submodule == "Sampling" and not selected_component_id.is_empty():
			var selected_component := _get_component(_get_asset(selected_asset_id), selected_component_id)
			if not _geometry_sampling_bake_is_current(selected_asset_id, selected_component_id, selected_component):
				_schedule_geometry_sampling_preview()
		elif submodule == "Seeding" and not selected_component_id.is_empty():
			var selected_component := _get_component(_get_asset(selected_asset_id), selected_component_id)
			if _geometry_seeding_status(selected_asset_id, selected_component_id, selected_component) == "Ready to Preview":
				_schedule_geometry_seeding_preview()
		elif submodule == "Meshing" and not selected_component_id.is_empty():
			var selected_component := _get_component(_get_asset(selected_asset_id), selected_component_id)
			if _geometry_meshing_status(selected_asset_id, selected_component_id, selected_component) == "Ready to Preview":
				_schedule_geometry_meshing_preview()
	elif module_name == "Style" and submodule in STYLE_SUBMODULES:
		active_style_submodule = submodule
		_enter_weighting_context()
	return


func _set_create_submodule_context(submodule: String) -> void:
	active_create_submodule = submodule if submodule in CREATE_SUBMODULES else "Character"
	active_state = ""
	var selected_asset := _get_asset(selected_asset_id)
	if selected_asset.is_empty() or _asset_type(selected_asset) != _create_submodule_asset_type(active_create_submodule):
		selected_asset_id = _create_submodule_active_asset_id()
		selected_component_id = ""
		selected_guide_id = ""
	var create_section := _find_section("Create")
	if create_section != null:
		_set_active_module_visual("Create", active_create_submodule)


func _create_submodule_active_asset_id() -> String:
	var expanded_asset_id := _outliner_focus_asset_id()
	if not expanded_asset_id.is_empty():
		return expanded_asset_id
	for asset in assets:
		if _asset_type(asset) == _create_submodule_asset_type(active_create_submodule):
			var asset_id := str(asset.get("id", ""))
			_set_outliner_asset_expanded(asset_id, true)
			return asset_id
	return ""


func _enter_motion_context(submodule := "Animation") -> void:
	active_module = "Motion"
	active_motion_submodule = submodule if submodule in MOTION_SUBMODULES else "Animation"
	selected_component_id = ""
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


func _enter_weighting_context() -> void:
	active_module = "Style"
	active_style_submodule = "Weighting"
	var style_section := _find_section("Style")
	if style_section != null:
		_set_active_module_visual("Style", "Weighting")
	_render_outliner()
	_render_inspector()
	_render_canvas_context()


func _select_weighting_asset(asset_id: String) -> void:
	var was_selected := selected_asset_id == asset_id and selected_component_id.is_empty()
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_weighting_style_id = ""
	if was_selected:
		_set_outliner_asset_expanded(asset_id, not bool(expanded_assets.get(asset_id, false)))
	else:
		_set_outliner_asset_expanded(asset_id, true)
	_enter_weighting_context()


func _select_weighting_component(asset_id: String, component_id: String) -> void:
	selected_asset_id = asset_id
	selected_component_id = component_id
	selected_weighting_style_id = ""
	_set_outliner_asset_expanded(asset_id, true)
	_enter_weighting_context()


func _select_weighting_style(asset_id: String, component_id: String, style_id: String) -> void:
	if _weighting_style(asset_id, component_id, style_id).is_empty():
		return
	selected_asset_id = asset_id
	selected_component_id = component_id
	selected_weighting_style_id = style_id
	_set_outliner_asset_expanded(asset_id, true)
	_enter_weighting_context()
