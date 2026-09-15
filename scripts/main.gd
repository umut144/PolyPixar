extends Control

const SELECTION_MIRROR_SERVICE_SCRIPT = preload("res://scripts/selection_mirror_service.gd")
const CREATE_SUBMODULES := ["Single", "Set", "Palette"]
# The Create module an Asset belongs to is its composition, not its category:
# what a thing is and how it is put together are two questions.
const CREATE_SUBMODULE_BY_ASSET_CATEGORY := {
	WorldDocumentService.ASSET_CATEGORY_SINGLE: "Single",
	WorldDocumentService.ASSET_CATEGORY_SET: "Set",
	WorldDocumentService.ASSET_CATEGORY_PALETTE: "Palette",
}
const ASSET_CATEGORY_BY_CREATE_SUBMODULE := {
	"Single": WorldDocumentService.ASSET_CATEGORY_SINGLE,
	"Set": WorldDocumentService.ASSET_CATEGORY_SET,
	"Palette": WorldDocumentService.ASSET_CATEGORY_PALETTE,
}
const GEOMETRY_SUBMODULES := ["Sampling", "Seeding", "Meshing"]
const STYLE_SUBMODULES := ["Weighting"]
const EXPORT_SUBMODULES: Array[String] = []
const MOTION_SUBMODULES := ["Animation", "Path", "Act", "Sequence"]
const WORLDS_ROOT := "res://worlds"
const CONFIG_PATH := "res://configs/app_config.json"
const CONSUMER_SYNC_SCRIPT := "res://scripts/sync_world01_consumers.sh"
const REGION_TYPES := WorldDocumentService.REGION_TYPES
const MAX_HISTORY_SIZE := 100
# Render targets. Mutations declare what became stale; the flush below decides
# what actually runs, once per frame.
const RENDER_OUTLINER := 1
const RENDER_INSPECTOR := 2
const RENDER_CANVAS_CONTEXT := 4
## The Transform sub-modes in the order the Info Bar numbers them; the values
## are the ones ComponentCanvas.set_transform_mode understands.
const TRANSFORM_MODES: Array[String] = ["transform", "rotate", "scale"]
const RENDER_CONTEXT_BAR := 8
const RENDER_INFO_BAR := 16
# The combination nearly every document mutation needs.
const RENDER_DOCUMENT := RENDER_OUTLINER | RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT
const GRID_BOX_TOOL_UNITS := 0.5
const GAME_TILE_CENTIMETERS := 100.0
const EYE_COMPONENT_NAME_TOKEN := "eye"
# Kept available for a later Outliner presentation, but processed outputs are
# currently reached through the Import Preview instead of additional rows.
const SHOW_PROCESSED_OUTLINER := false

var active_create_submodule := "Single"
var active_geometry_submodule := "Sampling"
var active_style_submodule := "Weighting"
var active_motion_submodule := "Animation"
var active_module := "Create"
var active_context_command := ""
var outliner_view: OutlinerView
var outliner_search_input: LineEdit
var outliner_asset_type_filter_panel: VBoxContainer
var outliner_asset_type_filter_checkboxes: Dictionary = {}
var outliner_asset_type_filter_all_button: Button
var outliner_component_navigation_active := false
var outliner_asset_type_filters: Dictionary = _default_outliner_asset_type_filters()
var inspector_content: VBoxContainer
var create_inspector_view: CreateInspectorView
var geometry_inspector_view: GeometryInspectorView
var style_inspector_view: StyleInspectorView
var motion_inspector_view: MotionInspectorView
var module_sections: Array[ModuleSection] = []
var assets: Array[Dictionary] = []
var motion_paths: Array[Dictionary] = []
var motion_acts: Array[Dictionary] = []
var motion_sequences: Array[Dictionary] = []
var geometry_documents: Dictionary = {}
# Geometry document keys that at least one history snapshot still references.
# Such a document is copied before its first mutation, so snapshots share
# unchanged documents instead of deep-copying the whole derived corpus.
var shared_geometry_document_keys: Dictionary = {}
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
var sdf_images: Dictionary = {}
var sdf_resource_validation_cache: Dictionary = {}
var batch_status_snapshot: Dictionary = {}
var batch_status_revision := 0
var batch_status_snapshot_revision := -1
var batch_status_snapshot_build_count := 0
var batch_status_refresh_timer: Timer
var runtime_export_view: RuntimeExportView
var export_run_button: Button
var export_valid_button: Button
var export_sync_button: Button
var export_preflight: Dictionary = {}
var export_preflight_revision := -1
var export_running := false
var outliner_panel: Control
var inspector_panel: Control
var context_bar_panel: Control
var draw_mode_status: MenuButton
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
var selected_component_ids: Array[String] = []
var component_clipboard: Dictionary = {}
var selected_group_id := ""
var selected_guide_id := ""
var selected_sampling_input_id := ""
var selected_sampling_input_kind := ""
# The row the Seeding tree has selected. Every Seeding input can be selected —
# Outer, Hole, Cut and Spine — while only Holes and Cuts are Sampling
# boundaries, so this is not the same thing as the Sampling input above and the
# two are kept apart rather than one field meaning both.
var selected_seeding_input_id := ""
var geometry_sampling_input_refresh_pending := false
var geometry_sampling_bake_button: Button
var selected_edge_id := ""
var selected_edge_ids: Array[String] = []
var selected_point_id := ""
var selected_point_ids: Array[String] = []
# Asset-root Scale is intentionally stored as two independent fields. Keep
# the singular reference as an X-axis compatibility alias for existing tests
# and extensions that only inspect the former uniform control.
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
var retired_assets: Array = []
var next_component_id := 1
var next_group_id := 1
var next_guide_id := 1
var asset_dialog: ConfirmationDialog
var asset_rename_dialog: ConfirmationDialog
var asset_rename_input: LineEdit
var asset_rename_key_label: Label
var asset_name_input: LineEdit
var asset_role_input: LineEdit
var asset_role_edited := false
var asset_type_input: OptionButton
var new_asset_type := WorldDocumentService.ASSET_TYPE_CHARACTER
var component_dialog: ConfirmationDialog
var component_name_input: LineEdit
var component_name_hint: Label
var component_draw_mode_menu: PopupMenu
var component_add_menu: PopupMenu
var component_add_child_menu: PopupMenu
var component_add_guide_menu: PopupMenu
var component_add_weapon_guide_menu: PopupMenu
var component_add_region_menu: PopupMenu
var component_add_reference_menu: PopupMenu
var set_member_menu: PopupMenu
var palette_variant_menu: PopupMenu
var component_context_menu: PopupMenu
var group_dialog: ConfirmationDialog
var group_name_input: LineEdit
var guide_dialog: ConfirmationDialog
var guide_name_input: LineEdit
var reference_image_dialog: FileDialog
var reference_image_crop_dialog: ReferenceImageCropDialog
var element_dialog: ConfirmationDialog
var element_name_input: LineEdit
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
var weighting_workspace: WeightingWorkspace
var weighting_method_menu: MenuButton
var selected_geometry_bake_method := ""
var geometry_seeding_replace_dialog: ConfirmationDialog
var guide_remove_dialog: ConfirmationDialog
var pending_guide_remove_asset_id := ""
var pending_guide_remove_id := ""
var component_remove_dialog: ConfirmationDialog
var pending_component_remove_asset_id := ""
var pending_component_remove_ids: Array[String] = []
var pending_component_remove_group_id := ""
var motion_phase_value_label: Label
var motion_phase_marks: MotionPhaseMarks
var motion_phase_slider: HSlider
var motion_play_button: Button
var motion_runtime_state_label: Label
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
## Create Primitive is a two-step command: a shape is picked first, and only
## then does anything appear on the Canvas. `primitive_create_shape` stays empty
## until one is picked, and `primitive_create_stage` mirrors the Canvas preview
## so the Info Bar can say what the next click on the Canvas will do.
var primitive_create_shape := ""
var primitive_create_stage := ""
var active_mirror_axis_orientation := ComponentCanvas.MIRROR_AXIS_VERTICAL
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
var frame_visible := false
var frame_half_extent := Vector2(1.0, 1.0) # Tool units; 1 unit = 10 cm.
var frame_offset := Vector2.ZERO # Tool units; frame center relative to origin.
var frame_button: Button
var frame_popup: PopupPanel
var frame_visible_checkbox: CheckBox
var frame_half_extent_fields: Dictionary = {}
var frame_offset_fields: Dictionary = {}
var frame_summary_label: Label
var world_scale_menu: Button
var world_scale_popup: PopupPanel
var world_unit_option: OptionButton
var world_grid_size_field: SpinBox
var world_contour_stroke_width_field: SpinBox
var world_scale_summary_label: Label
var update_meshes_button: BatchStatusButton
var mesh_batch_running := false
var runtime_export_button: BatchStatusButton
var runtime_export_batch_running := false
var world_name := ""
var world_title := ""
var world_menu: MenuButton
var world_name_dialog: ConfirmationDialog
var world_name_input: LineEdit
var load_world_dialog: ConfirmationDialog
var world_list: ItemList
var reload_world_dialog: ConfirmationDialog
var eye_contour_stroke_dialog: ConfirmationDialog
var eye_contour_stroke_width_field: SpinBox
var pending_save_after_new := false
var pending_renders := 0
var rendering := false
var undo_history: Array[Dictionary] = []
var redo_history: Array[Dictionary] = []
var history_coalesce_timer: Timer
var history_coalescing := false
var world_unit := "cm"
var world_grid_size := GRID_BOX_TOOL_UNITS
var world_contour_stroke_width_px := WorldSettingsService.DEFAULT_CONTOUR_STROKE_WIDTH_PX


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
	_invalidate_render(RENDER_DOCUMENT)
	_load_last_world()
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
func _load_last_world() -> void:
	var config_data = WorldDocumentService.read_json(CONFIG_PATH)
	if WorldDocumentService.has_supported_schema(config_data):
		var last_world := str(config_data.get("last_world", ""))
		if not last_world.is_empty():
			_load_world(last_world)


func _focus_active_canvas_after_startup() -> void:
	# Let the World restore finish creating/focusing its controls first.
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
	# Everything below runs ahead of the GUI, so a text field cannot defend
	# itself by consuming the key: while one owns the keyboard, every key
	# belongs to it. Without this, typing a name with the pointer resting over
	# the Canvas places a Pivot and takes the focus away mid-word.
	if _canvas_shortcuts_are_blocked(_keyboard_focus_owner()):
		return
	# Route the pointer-based Pivot shortcut before focused SpinBox controls can
	# consume the printable P key.
	if _is_plain_pivot_shortcut(event) and _try_place_selected_pivot_at_mouse():
		get_viewport().set_input_as_handled()
		return
	if not event.meta_pressed and not event.ctrl_pressed and event.keycode in [KEY_UP, KEY_DOWN] and _outliner_component_navigation_has_focus():
		_navigate_outliner_component(-1 if event.keycode == KEY_UP else 1)
		get_viewport().set_input_as_handled()
		return
	if event.meta_pressed or event.ctrl_pressed or event.keycode not in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] or not _can_nudge_selection():
		return
	var nudge_delta := Vector2.ZERO
	match event.keycode:
		KEY_LEFT: nudge_delta.x = -1.0
		KEY_RIGHT: nudge_delta.x = 1.0
		KEY_UP: nudge_delta.y = 1.0
		KEY_DOWN: nudge_delta.y = -1.0
	_nudge_selection(nudge_delta)
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
	# A field that does not consume the key itself — a read-only one, say —
	# would otherwise let it through to the Canvas.
	if _canvas_shortcuts_are_blocked(_keyboard_focus_owner()):
		return
	if event.echo and not _can_nudge_selection():
		return
	var has_command_modifier: bool = event.meta_pressed or event.ctrl_pressed
	if _is_plain_pivot_shortcut(event) and _try_place_selected_pivot_at_mouse():
		get_viewport().set_input_as_handled()
		return
	if has_command_modifier and event.keycode == KEY_Q:
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE:
		# The Canvas consumes Escape itself while the Ruler runs. Reaching here
		# means focus sat elsewhere, so Measure is left alone instead of being
		# reset out from under a half-placed measurement.
		if is_instance_valid(canvas_view) and canvas_view.is_measure_placing():
			get_viewport().set_input_as_handled()
			return
		_reset_to_default_state()
		get_viewport().set_input_as_handled()
		return
	if not has_command_modifier and event.keycode in [KEY_ENTER, KEY_KP_ENTER] and active_state == "draw" and active_draw_tool == "point":
		if _pause_draw_point():
			get_viewport().set_input_as_handled()
		return
	if has_command_modifier and event.keycode == KEY_S:
		_save_world()
		get_viewport().set_input_as_handled()
		return
	if has_command_modifier and event.keycode == KEY_Z:
		if event.shift_pressed:
			_redo()
		else:
			_undo()
		get_viewport().set_input_as_handled()
		return
	if has_command_modifier and event.keycode in [KEY_C, KEY_V]:
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner is LineEdit or focus_owner is TextEdit or focus_owner is SpinBox:
			return
		if event.keycode == KEY_C:
			_copy_selected_component_subtrees()
		elif selected_asset_id.is_empty():
			return
		else:
			_paste_component_clipboard(selected_asset_id, selected_component_id)
		get_viewport().set_input_as_handled()
		return
	if has_command_modifier and active_module == "Style" and active_style_submodule == "Weighting" and event.keycode == KEY_1:
		_set_active_context_command("style.weighting.method")
		_invalidate_render(RENDER_CONTEXT_BAR)
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
	if not has_command_modifier and (event.keycode == KEY_BACKSPACE or event.keycode == KEY_DELETE) and active_state == "edit" and active_edit_mode == "point" and not selected_point_ids.is_empty():
		if selected_point_ids.size() == 1:
			_on_bezier_point_delete_requested(selected_point_ids[0])
		else:
			_on_bezier_points_delete_requested(selected_point_ids.duplicate())
		get_viewport().set_input_as_handled()
		return
	if not has_command_modifier and (event.keycode == KEY_BACKSPACE or event.keycode == KEY_DELETE) and active_state == "edit" and active_edit_mode == "edge":
		var edge_ids_to_delete := selected_edge_ids.duplicate()
		if edge_ids_to_delete.is_empty() and not selected_edge_id.is_empty():
			edge_ids_to_delete.append(selected_edge_id)
		if not edge_ids_to_delete.is_empty():
			_on_bezier_edges_delete_requested(edge_ids_to_delete)
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
	if WorldDocumentService.is_primitive(selected_component):
		# A Primitive owns neither Points nor Chains, so its Component shortcuts
		# are its own two: pick a shape to create, or transform what is there.
		# The Bezier ladder below must never be reached from here.
		if has_command_modifier and event.keycode == KEY_1:
			_activate_primitive_create_command()
			get_viewport().set_input_as_handled()
			return
		if has_command_modifier and event.keycode == KEY_2:
			_activate_transform_state()
			get_viewport().set_input_as_handled()
			return
		if not has_command_modifier and _context_command_is("asset.create_primitive") and event.keycode in [KEY_1, KEY_2, KEY_3]:
			_set_primitive_create_shape(PrimitiveGeometryService.CREATABLE_SHAPES[event.keycode - KEY_1])
			get_viewport().set_input_as_handled()
			return
		if not has_command_modifier and _context_command_is("asset.transform") and event.keycode in [KEY_1, KEY_2, KEY_3]:
			_set_transform_mode(TRANSFORM_MODES[event.keycode - KEY_1])
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
		if WorldDocumentService.is_closed_loop(selected_component):
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
	elif not has_command_modifier and active_state == "edit" and active_edit_mode == "point" and event.keycode == KEY_4:
		_activate_fuse_point_state()
		get_viewport().set_input_as_handled()


## An arrow key moves the selection by the Grid step, and what the selection is
## depends on the Component: a Bezier Component answers with its Points, a
## Primitive has none and answers with its centre. Without an answer the keys
## fall through to Control focus navigation and the focus leaves the Canvas for
## the Inspector, which is what a Primitive used to do.
func _can_nudge_selection() -> bool:
	return _can_nudge_selected_point() or _can_nudge_selected_primitive()


func _can_nudge_selected_primitive() -> bool:
	if Input.is_key_pressed(KEY_META) or Input.is_key_pressed(KEY_CTRL) or not selected_guide_id.is_empty():
		return false
	if active_state not in ["", "edit", "transform"]:
		return false
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	return not _region_uses_component_geometry(component) and PrimitiveGeometryService.has_analytic_shape(component)


func _nudge_selection(direction: Vector2) -> void:
	if _can_nudge_selected_point():
		_nudge_selected_point(direction)
		return
	_nudge_selected_primitive(direction)


func _nudge_selected_primitive(direction: Vector2) -> void:
	if not _can_nudge_selected_primitive() or direction.is_zero_approx():
		return
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var primitive: Dictionary = component.get("primitive", {})
	if primitive.is_empty():
		return
	var step := maxf(snap_grid_step if snap_enabled else world_grid_size, 0.0001)
	_record_direct_change()
	primitive["center"] = PrimitiveGeometryService.center(component) + direction * step
	component["primitive"] = primitive
	_refresh_component_geometry(component)
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


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
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


func _keyboard_focus_owner() -> Control:
	if not is_inside_tree() or get_viewport() == null:
		return null
	return get_viewport().gui_get_focus_owner()


func _canvas_shortcuts_are_blocked(focus_owner: Control) -> bool:
	# A text field owns the keyboard while it is focused — a SpinBox through the
	# LineEdit it holds — so the Canvas shortcuts stand back rather than reach
	# past it.
	return focus_owner is LineEdit or focus_owner is TextEdit


func _is_plain_pivot_shortcut(event: InputEventKey) -> bool:
	return event.pressed and not event.echo \
		and not event.meta_pressed and not event.ctrl_pressed and not event.alt_pressed and not event.shift_pressed \
		and (event.keycode == KEY_P or event.physical_keycode == KEY_P)


func _try_place_selected_pivot_at_mouse() -> bool:
	if not is_instance_valid(canvas_view) or not canvas_view.is_visible_in_tree() or not canvas_view.is_pointer_over_canvas():
		return false
	if active_state == "draw" or not selected_guide_id.is_empty():
		return false
	var placed := false
	if not selected_group_id.is_empty():
		placed = _place_selected_group_pivot_at_mouse()
	elif not selected_component_id.is_empty():
		placed = canvas_view.place_pivot_at_mouse()
	elif not selected_asset_id.is_empty():
		placed = canvas_view.place_asset_pivot_at_mouse()
	if not placed:
		return false
	outliner_component_navigation_active = false
	canvas_view.grab_focus()
	_show_status_message("Pivot set at pointer.")
	return true


func _reset_to_default_state() -> void:
	_stop_guide_draw_state()
	_stop_primitive_create_command()
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
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


func _set_geometry_command_state(state: String) -> void:
	geometry_sampling_method_choice_active = state == "sampling_method"
	geometry_seeding_method_choice_active = state == "seeding_method"
	geometry_seeding_edit_active = state == "seeding_edit"
	geometry_meshing_method_choice_active = state == "meshing_method"
	if state == "sampling_method":
		_set_active_context_command("geometry.sampling.method")
	elif state == "seeding_method":
		_set_active_context_command("geometry.seeding.method")
	elif state == "seeding_edit":
		_set_active_context_command("geometry.seeding.edit_seeds")
	elif state == "meshing_method":
		_set_active_context_command("geometry.meshing.method")
	elif active_context_command.begins_with("geometry."):
		_set_active_context_command("")
	if not geometry_seeding_edit_active:
		geometry_seeding_edit_tool = "select"


func _set_active_context_command(command: String) -> void:
	active_context_command = command
	# Only Point placement follows the active command. The Ruler toggle and its
	# guides stay on, so a measurement keeps updating while its Points are
	# edited under another command.
	if is_instance_valid(canvas_view):
		canvas_view.set_measure_placing(command == "asset.measure")


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
			_invalidate_render(RENDER_CONTEXT_BAR)
	)


func _complete_context_method_menu(command: String, popup: PopupMenu) -> void:
	if is_instance_valid(popup):
		popup.hide()
	if active_context_command == command:
		_set_active_context_command("")
		_invalidate_render(RENDER_CONTEXT_BAR)


func _stop_guide_draw_state() -> void:
	if active_draw_tool == "spine":
		active_draw_tool = ""


## Leaving Create Primitive takes its preview with it, whether a shape was
## already picked or only the command was active. The preview is Canvas-only
## state, so nothing but the Canvas has to be told.
func _stop_primitive_create_command() -> void:
	primitive_create_shape = ""
	primitive_create_stage = ""
	if is_instance_valid(canvas_view):
		canvas_view.cancel_primitive_preview()


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

	var toolbar_panel := EditorWidgets.create_panel()
	main_layout.add_child(toolbar_panel)
	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size = Vector2(0, 32)
	toolbar_panel.add_child(toolbar)
	create_action_button = Button.new()
	create_action_button.custom_minimum_size = Vector2(132, 32)
	create_action_button.focus_mode = Control.FOCUS_NONE
	create_action_button.pressed.connect(_on_create_action_pressed)
	toolbar.add_child(create_action_button)
	draw_mode_status = MenuButton.new()
	draw_mode_status.name = "DrawModeStatus"
	draw_mode_status.text = "Draw Mode: —  ▾"
	draw_mode_status.flat = true
	draw_mode_status.focus_mode = Control.FOCUS_NONE
	draw_mode_status.disabled = true
	draw_mode_status.tooltip_text = "Select a Component to change how its geometry is authored."
	draw_mode_status.add_theme_font_size_override("font_size", 11)
	draw_mode_status.add_theme_color_override("font_color", Color("#9aa3b2"))
	for draw_mode_index in range(WorldDocumentService.DRAW_MODES.size()):
		draw_mode_status.get_popup().add_radio_check_item(_draw_mode_display_name(WorldDocumentService.DRAW_MODES[draw_mode_index]), draw_mode_index)
	EditorWidgets.style_popup_menu(draw_mode_status.get_popup())
	draw_mode_status.get_popup().id_pressed.connect(_on_draw_mode_status_selected)
	toolbar.add_child(draw_mode_status)
	export_run_button = Button.new()
	export_run_button.text = "Build All (0)"
	export_run_button.custom_minimum_size = Vector2(132, 32)
	export_run_button.focus_mode = Control.FOCUS_NONE
	export_run_button.visible = false
	export_run_button.disabled = true
	toolbar.add_child(export_run_button)
	export_valid_button = Button.new()
	export_valid_button.text = "Export All Valid (0)"
	export_valid_button.custom_minimum_size = Vector2(174, 32)
	export_valid_button.focus_mode = Control.FOCUS_NONE
	export_valid_button.visible = false
	export_valid_button.disabled = true
	toolbar.add_child(export_valid_button)
	export_sync_button = Button.new()
	export_sync_button.text = "Sync Consumers"
	export_sync_button.custom_minimum_size = Vector2(154, 32)
	export_sync_button.focus_mode = Control.FOCUS_NONE
	export_sync_button.visible = false
	export_sync_button.disabled = true
	export_sync_button.tooltip_text = "Sync the published catalog to SceneMaker and world01."
	toolbar.add_child(export_sync_button)
	snap_button = Button.new()
	snap_button.text = "Snap: %s  ▼" % _snap_mode_label()
	snap_button.custom_minimum_size = Vector2(128, 32)
	snap_button.focus_mode = Control.FOCUS_NONE
	snap_button.pressed.connect(_toggle_snap_popup)
	toolbar.add_child(snap_button)
	frame_button = Button.new()
	frame_button.text = "Frame: Off  ▼"
	frame_button.custom_minimum_size = Vector2(122, 32)
	frame_button.focus_mode = Control.FOCUS_NONE
	frame_button.pressed.connect(_toggle_frame_popup)
	toolbar.add_child(frame_button)
	var toolbar_spacer := Control.new()
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(toolbar_spacer)
	world_menu = MenuButton.new()
	world_menu.text = "World  ▼"
	world_menu.custom_minimum_size = Vector2(132, 32)
	world_menu.focus_mode = Control.FOCUS_NONE
	var world_popup := world_menu.get_popup()
	EditorWidgets.style_popup_menu(world_popup)
	world_popup.add_item("New")
	world_popup.add_item("Save")
	world_popup.add_item("Load")
	world_popup.add_item("Reload Current World…")
	world_popup.add_separator()
	world_popup.add_item("Set Eye Contour Width…", 4)
	world_popup.id_pressed.connect(_on_world_menu_id)
	_create_world_scale_popup()
	# Batch commands live in the Export module. Keep these hidden controls owned
	# by the application for the existing command implementations.
	update_meshes_button = BatchStatusButton.new()
	update_meshes_button.text = "Update Meshes (0)"
	update_meshes_button.tooltip_text = "All Meshes current"
	update_meshes_button.custom_minimum_size = Vector2(156, 32)
	update_meshes_button.focus_mode = Control.FOCUS_NONE
	update_meshes_button.disabled = true
	update_meshes_button.pressed.connect(_on_update_meshes_pressed)
	update_meshes_button.hide()
	add_child(update_meshes_button)
	runtime_export_button = BatchStatusButton.new()
	runtime_export_button.text = "Export Runtime (0)"
	runtime_export_button.tooltip_text = "No pending runtime exports"
	runtime_export_button.custom_minimum_size = Vector2(164, 32)
	runtime_export_button.focus_mode = Control.FOCUS_NONE
	runtime_export_button.disabled = true
	runtime_export_button.pressed.connect(_on_runtime_export_pressed)
	runtime_export_button.hide()
	add_child(runtime_export_button)
	toolbar.add_child(world_scale_menu)
	toolbar.add_child(world_menu)

	var workspace_row := HBoxContainer.new()
	workspace_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_row.add_theme_constant_override("separation", 1)
	main_layout.add_child(workspace_row)

	var module_rail_panel := EditorWidgets.create_panel(Color("#20242c"))
	module_rail_panel.custom_minimum_size = Vector2(104, 0)
	workspace_row.add_child(module_rail_panel)
	var module_rail := VBoxContainer.new()
	module_rail.add_theme_constant_override("separation", 4)
	module_rail_panel.add_child(module_rail)
	_add_module_section(module_rail, "Create", CREATE_SUBMODULES, true)
	_add_module_section(module_rail, "Mesh", GEOMETRY_SUBMODULES, true, false, -1)
	_add_module_section(module_rail, "Style", STYLE_SUBMODULES, true)
	_add_module_section(module_rail, "Export", EXPORT_SUBMODULES, true)
	_set_active_module_visual("Create", active_create_submodule)

	var workspace_split := HSplitContainer.new()
	workspace_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_split.add_theme_constant_override("separation", 1)
	workspace_split.add_theme_constant_override("minimum_grab_thickness", 1)
	workspace_split.split_offset = 220
	workspace_row.add_child(workspace_split)

	outliner_panel = EditorWidgets.create_panel()
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
	var filter_label := EditorWidgets.create_panel_label("Asset Filter")
	filter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_header.add_child(filter_label)
	outliner_asset_type_filter_all_button = Button.new()
	outliner_asset_type_filter_all_button.custom_minimum_size = Vector2(40, 22)
	outliner_asset_type_filter_all_button.focus_mode = Control.FOCUS_NONE
	outliner_asset_type_filter_all_button.pressed.connect(_toggle_all_outliner_asset_type_filters)
	filter_header.add_child(outliner_asset_type_filter_all_button)
	outliner_asset_type_filter_panel.add_child(filter_header)
	var filter_grid := GridContainer.new()
	filter_grid.columns = 2
	filter_grid.add_theme_constant_override("h_separation", 4)
	filter_grid.add_theme_constant_override("v_separation", 0)
	for asset_type in WorldDocumentService.ASSET_TYPES:
		var type_checkbox := CheckBox.new()
		type_checkbox.text = asset_type.capitalize()
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
	outliner_view = OutlinerView.new()
	outliner_view.asset_selected.connect(_select_asset)
	outliner_view.component_selected.connect(_on_outliner_component_selected)
	outliner_view.group_selected.connect(_select_group)
	outliner_view.guide_selected.connect(_select_guide)
	outliner_view.region_selected.connect(_on_outliner_component_selected)
	outliner_view.weighting_asset_selected.connect(_select_weighting_asset)
	outliner_view.weighting_component_selected.connect(_select_weighting_component)
	outliner_view.weighting_style_selected.connect(_select_weighting_style)
	outliner_view.weighting_style_add_requested.connect(_create_weighting_style)
	outliner_view.motion_asset_selected.connect(_select_motion_asset)
	outliner_view.motion_path_selected.connect(_select_motion_path)
	outliner_view.motion_sequence_selected.connect(_select_motion_sequence)
	outliner_view.motion_act_preview_asset_selected.connect(_select_motion_act_preview_asset)
	outliner_view.component_add_requested.connect(_open_component_add_menu)
	outliner_view.group_add_requested.connect(_open_group_add_menu)
	outliner_view.component_dialog_requested.connect(_open_component_dialog)
	outliner_view.row_context_menu_requested.connect(_on_outliner_row_context_menu)
	outliner_view.drop_requested.connect(_outliner_drop_data_from_view)
	outliner_view.visibility_toggle_requested.connect(_on_outliner_visibility_toggled)
	outliner_view.geometry_asset_selected.connect(_select_geometry_asset)
	outliner_view.geometry_component_selected.connect(_select_geometry_component)
	outliner_view.geometry_hole_selected.connect(_select_geometry_sampling_hole)
	outliner_view.geometry_input_selected.connect(_select_geometry_seeding_input)
	outliner_view.geometry_pipeline_action.connect(_on_geometry_pipeline_action)
	outliner_scroll.add_child(outliner_view)

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

	context_bar_panel = EditorWidgets.create_panel()
	canvas_column.add_child(context_bar_panel)
	context_bar = HBoxContainer.new()
	context_bar.custom_minimum_size = Vector2(0, 32)
	context_bar_panel.add_child(context_bar)
	_create_snap_popup()
	_create_frame_popup()

	var canvas_panel := EditorWidgets.create_panel(Color("#1b1e24"))
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
	canvas_view.measure_stage_changed.connect(_on_measure_stage_changed)
	canvas_view.pivot_changed.connect(_on_pivot_changed)
	canvas_view.asset_pivot_changed.connect(_on_asset_pivot_changed)
	canvas_view.transform_changed.connect(_on_transform_changed)
	canvas_view.primitive_placed.connect(_on_primitive_placed)
	canvas_view.primitive_center_changed.connect(_on_primitive_center_changed)
	canvas_view.primitive_preview_cancelled.connect(_on_primitive_preview_cancelled)
	canvas_view.primitive_preview_stage_changed.connect(_on_primitive_preview_stage_changed)
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
	_create_weighting_workspace(canvas_panel)
	canvas_context_label = Label.new()
	canvas_context_label.position = Vector2(8, 6)
	canvas_context_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_context_label.add_theme_font_size_override("font_size", 11)
	canvas_context_label.add_theme_color_override("font_color", Color("#9aa3b2"))
	canvas.add_child(canvas_context_label)

	inspector_panel = EditorWidgets.create_panel()
	inspector_panel.custom_minimum_size = Vector2(260, 0)
	canvas_split.add_child(inspector_panel)
	inspector_content = VBoxContainer.new()
	inspector_content.add_theme_constant_override("separation", 2)
	inspector_panel.add_child(inspector_content)
	create_inspector_view = CreateInspectorView.new()
	create_inspector_view.add_theme_constant_override("separation", 2)
	create_inspector_view.asset_authored_facing_selected.connect(_on_asset_authored_facing_selected)
	create_inspector_view.asset_type_selected.connect(_on_asset_type_selected)
	create_inspector_view.palette_variant_remove_requested.connect(_on_palette_variant_remove_requested)
	create_inspector_view.asset_pivot_property_changed.connect(_on_asset_pivot_property_changed)
	create_inspector_view.asset_rename_dialog_requested.connect(_on_asset_rename_dialog_requested)
	create_inspector_view.set_member_rename_dialog_requested.connect(_on_set_member_rename_dialog_requested)
	create_inspector_view.reference_role_requested.connect(_on_reference_role_requested)
	create_inspector_view.asset_root_position_changed.connect(_on_asset_root_position_changed)
	create_inspector_view.asset_root_scale_changed.connect(_on_asset_root_scale_changed)
	create_inspector_view.asset_root_scale_rebase_requested.connect(_on_rebase_asset_root_scale_pressed)
	create_inspector_view.asset_scales_rebase_requested.connect(_on_rebase_asset_scales_pressed)
	create_inspector_view.circle_primitive_diameter_changed.connect(_on_circle_primitive_diameter_changed)
	create_inspector_view.component_catch_parent_selected.connect(_on_component_catch_parent_selected)
	create_inspector_view.component_contour_stroke_width_changed.connect(_on_component_contour_stroke_width_changed)
	create_inspector_view.component_contour_stroke_alignment_selected.connect(_on_component_contour_stroke_alignment_selected)
	create_inspector_view.component_debug_point_numbers_toggled.connect(_on_component_debug_point_numbers_toggled)
	create_inspector_view.component_hierarchy_parent_selected.connect(_on_component_hierarchy_parent_selected)
	create_inspector_view.component_projection_depth_changed.connect(_on_component_projection_depth_changed)
	create_inspector_view.component_rename_requested.connect(_rename_selected_component)
	create_inspector_view.region_geometry_source_selected.connect(_on_region_geometry_source_selected)
	create_inspector_view.component_topology_role_selected.connect(_on_component_topology_role_selected)
	create_inspector_view.component_visibility_changed.connect(_on_component_visibility_changed)
	create_inspector_view.component_z_index_changed.connect(_on_component_z_index_changed)
	create_inspector_view.edge_render_outline_changed.connect(_on_edge_render_outline_changed)
	create_inspector_view.ellipse_primitive_diameter_changed.connect(_on_ellipse_primitive_diameter_changed)
	create_inspector_view.rectangle_primitive_size_changed.connect(_on_rectangle_primitive_size_changed)
	create_inspector_view.triangle_primitive_size_changed.connect(_on_triangle_primitive_size_changed)
	create_inspector_view.global_transform_value_changed.connect(_on_global_transform_value_changed)
	create_inspector_view.group_hierarchy_parent_selected.connect(_on_group_hierarchy_parent_selected)
	create_inspector_view.group_rename_requested.connect(_rename_selected_group)
	create_inspector_view.group_transform_value_changed.connect(_on_group_transform_value_changed)
	create_inspector_view.group_visibility_changed.connect(_on_group_visibility_changed)
	create_inspector_view.guide_delete_requested.connect(_delete_selected_guide)
	create_inspector_view.guide_type_selected.connect(_on_guide_type_selected)
	create_inspector_view.guide_visibility_changed.connect(_on_selected_guide_visibility_changed)
	create_inspector_view.multi_component_field_focus_exited.connect(_on_multi_component_field_focus_exited)
	create_inspector_view.multi_component_field_submitted.connect(_on_multi_component_field_submitted)
	create_inspector_view.multi_component_visibility_selected.connect(_on_multi_component_visibility_selected)
	create_inspector_view.point_position_changed.connect(_on_point_position_changed)
	create_inspector_view.reference_image_clear_requested.connect(_clear_reference_image)
	create_inspector_view.reference_image_load_requested.connect(_open_reference_image_dialog)
	create_inspector_view.reference_image_pivot_selected.connect(_on_reference_image_pivot_selected)
	create_inspector_view.reference_image_property_changed.connect(_on_reference_image_property_changed)
	create_inspector_view.reference_image_target_height_changed.connect(_on_reference_image_target_height_changed)
	create_inspector_view.reference_image_visibility_changed.connect(_on_reference_image_visibility_changed)
	create_inspector_view.section_toggled.connect(_on_inspector_section_toggled)
	create_inspector_view.selected_points_delta_changed.connect(_on_selected_points_delta_changed)
	create_inspector_view.selected_points_mode_selected.connect(_on_selected_points_mode_selected)
	create_inspector_view.selected_points_preserve_changed.connect(_on_selected_points_preserve_changed)
	create_inspector_view.transform_value_changed.connect(_on_transform_value_changed)
	create_inspector_view.weapon_frame_value_changed.connect(_on_weapon_frame_value_changed)
	inspector_content.add_child(create_inspector_view)
	geometry_inspector_view = GeometryInspectorView.new()
	geometry_inspector_view.add_theme_constant_override("separation", 2)
	geometry_inspector_view.meshing_advanced_relaxation_toggled.connect(_on_geometry_meshing_advanced_relaxation_toggled)
	geometry_inspector_view.meshing_bake_requested.connect(_bake_geometry_meshing)
	geometry_inspector_view.meshing_float_focus_exited.connect(_on_geometry_meshing_float_focus_exited)
	geometry_inspector_view.meshing_float_text_submitted.connect(_on_geometry_meshing_float_text_submitted)
	geometry_inspector_view.meshing_override_changed.connect(_on_geometry_meshing_override_changed)
	geometry_inspector_view.meshing_parameter_changed.connect(_on_geometry_meshing_parameter_changed)
	geometry_inspector_view.meshing_seed_source_selected.connect(_on_geometry_meshing_seed_source_selected)
	geometry_inspector_view.meshing_view_option_changed.connect(_on_geometry_meshing_view_option_changed)
	geometry_inspector_view.sampling_bake_requested.connect(_bake_geometry_sampling)
	geometry_inspector_view.sampling_feature_detail_changed.connect(_on_geometry_sampling_feature_detail_changed)
	geometry_inspector_view.sampling_parameter_changed.connect(_on_geometry_sampling_parameter_changed)
	geometry_inspector_view.sampling_refinement_changed.connect(_on_geometry_sampling_refinement_changed)
	geometry_inspector_view.sampling_refinement_toggled.connect(_on_geometry_sampling_refinement_toggled)
	geometry_inspector_view.sampling_spacing_focus_exited.connect(_on_geometry_spacing_focus_exited)
	geometry_inspector_view.sampling_spacing_text_submitted.connect(_on_geometry_spacing_text_submitted)
	geometry_inspector_view.section_toggled.connect(_on_inspector_section_toggled)
	geometry_inspector_view.seeding_advanced_pattern_toggled.connect(_on_geometry_seeding_advanced_pattern_toggled)
	geometry_inspector_view.seeding_bake_requested.connect(_bake_geometry_seeding)
	geometry_inspector_view.seeding_boundary_override_changed.connect(_on_geometry_seeding_boundary_override_changed)
	geometry_inspector_view.seeding_fill_gaps_changed.connect(_on_geometry_seeding_fill_gaps_changed)
	geometry_inspector_view.seeding_float_focus_exited.connect(_on_geometry_seeding_float_focus_exited)
	geometry_inspector_view.seeding_float_text_submitted.connect(_on_geometry_seeding_float_text_submitted)
	geometry_inspector_view.seeding_method_selected.connect(_on_geometry_seeding_method_selected)
	geometry_inspector_view.seeding_parameter_changed.connect(_on_geometry_seeding_parameter_changed)
	geometry_inspector_view.seeding_spine_enabled_changed.connect(_on_geometry_seeding_spine_enabled)
	geometry_inspector_view.seeding_stagger_override_changed.connect(_on_geometry_seeding_stagger_override_changed)
	geometry_inspector_view.sampling_hole_selected.connect(func(hole_id: String) -> void:
		_select_geometry_sampling_hole(selected_asset_id, selected_component_id, hole_id))
	geometry_inspector_view.sampling_cut_selected.connect(func(guide_id: String) -> void:
		_select_guide(selected_asset_id, guide_id))
	inspector_content.add_child(geometry_inspector_view)
	style_inspector_view = StyleInspectorView.new()
	style_inspector_view.add_theme_constant_override("separation", 2)
	style_inspector_view.bake_requested.connect(_bake_weighting_preview)
	style_inspector_view.curve_selected.connect(_on_weighting_curve_selected)
	style_inspector_view.direction_selected.connect(_on_weighting_direction_selected)
	style_inspector_view.invert_changed.connect(_on_weighting_invert_changed)
	style_inspector_view.method_selected.connect(_on_weighting_method_selected)
	style_inspector_view.preview_requested.connect(_generate_weighting_preview)
	style_inspector_view.section_toggled.connect(_on_inspector_section_toggled)
	style_inspector_view.strength_changed.connect(_on_weighting_strength_changed)
	style_inspector_view.style_delete_requested.connect(_delete_selected_weighting_style)
	style_inspector_view.style_rename_requested.connect(_rename_weighting_style)
	inspector_content.add_child(style_inspector_view)
	motion_inspector_view = MotionInspectorView.new()
	motion_inspector_view.add_theme_constant_override("separation", 2)
	motion_inspector_view.act_direction_changed.connect(_on_motion_act_direction_changed)
	motion_inspector_view.act_easing_selected.connect(_on_motion_act_easing_selected)
	motion_inspector_view.act_enabled_changed.connect(_on_motion_act_enabled_changed)
	motion_inspector_view.act_jump_arc_selected.connect(_on_motion_act_jump_arc_selected)
	motion_inspector_view.act_number_changed.connect(_on_motion_act_number_changed)
	motion_inspector_view.act_remove_requested.connect(_remove_selected_motion_act)
	motion_inspector_view.act_rename_requested.connect(_rename_motion_act)
	motion_inspector_view.contract_parameter_add_requested.connect(_add_contract_parameter)
	motion_inspector_view.contract_parameter_remove_requested.connect(_remove_contract_parameter)
	motion_inspector_view.contract_parameter_rename_requested.connect(_rename_contract_parameter)
	motion_inspector_view.contract_parameter_type_selected.connect(_on_contract_parameter_type_selected)
	motion_inspector_view.marker_event_rename_requested.connect(_rename_marker_event)
	motion_inspector_view.marker_kind_selected.connect(_on_marker_kind_selected)
	motion_inspector_view.marker_phase_changed.connect(_on_marker_phase_changed)
	motion_inspector_view.motion_domain_selected.connect(_on_motion_domain_selected)
	motion_inspector_view.motion_enabled_changed.connect(_on_motion_enabled_changed)
	motion_inspector_view.motion_item_remove_requested.connect(_request_motion_item_removal)
	motion_inspector_view.motion_parameter_changed.connect(_on_motion_parameter_changed)
	motion_inspector_view.motion_phase_offset_changed.connect(_on_motion_phase_offset_changed)
	motion_inspector_view.motion_primitive_selected.connect(_on_motion_primitive_selected)
	motion_inspector_view.motion_remove_requested.connect(_request_motion_removal)
	motion_inspector_view.motion_rename_requested.connect(_rename_motion)
	motion_inspector_view.motion_target_selected.connect(_on_motion_target_selected)
	motion_inspector_view.path_duration_changed.connect(_on_motion_path_duration_changed)
	motion_inspector_view.path_playback_toggled.connect(_on_motion_path_playback_toggle)
	motion_inspector_view.path_preview_asset_selected.connect(_on_motion_path_preview_asset_selected)
	motion_inspector_view.path_rename_requested.connect(_rename_motion_path)
	motion_inspector_view.runtime_bool_changed.connect(_on_motion_runtime_bool_changed)
	motion_inspector_view.runtime_number_changed.connect(_on_motion_runtime_number_changed)
	motion_inspector_view.section_toggled.connect(_on_inspector_section_toggled)
	motion_inspector_view.sequence_asset_selected.connect(_on_motion_sequence_asset_selected)
	motion_inspector_view.sequence_entry_enabled_changed.connect(_on_motion_sequence_entry_enabled_changed)
	motion_inspector_view.sequence_entry_remove_requested.connect(_remove_motion_sequence_entry)
	motion_inspector_view.sequence_entry_rename_requested.connect(_rename_motion_sequence_entry)
	motion_inspector_view.sequence_path_selected.connect(_on_motion_sequence_path_selected)
	motion_inspector_view.sequence_rename_requested.connect(_rename_motion_sequence)
	motion_inspector_view.sequence_state_selected.connect(_on_motion_sequence_state_selected)
	motion_inspector_view.state_cycle_duration_changed.connect(_on_motion_state_cycle_duration_changed)
	motion_inspector_view.state_remove_requested.connect(_request_motion_state_removal)
	motion_inspector_view.state_rename_requested.connect(_rename_motion_state)
	motion_inspector_view.transition_entry_mode_selected.connect(_on_transition_entry_mode_selected)
	motion_inspector_view.transition_exit_policy_selected.connect(_on_transition_exit_policy_selected)
	motion_inspector_view.transition_move_requested.connect(_move_transition)
	motion_inspector_view.transition_number_changed.connect(_on_transition_number_changed)
	motion_inspector_view.transition_rule_add_requested.connect(_add_transition_rule)
	motion_inspector_view.transition_rule_operator_selected.connect(_on_transition_rule_operator_selected)
	motion_inspector_view.transition_rule_parameter_selected.connect(_on_transition_rule_parameter_selected)
	motion_inspector_view.transition_rule_remove_requested.connect(_remove_transition_rule)
	motion_inspector_view.transition_rule_value_changed.connect(_on_transition_rule_value_changed)
	motion_inspector_view.transition_target_selected.connect(_on_transition_target_selected)
	inspector_content.add_child(motion_inspector_view)
	_create_export_workspace(canvas_panel)

	var status_bar := EditorWidgets.create_panel()
	status_bar.custom_minimum_size = Vector2(0, 24)
	main_layout.add_child(status_bar)
	var status_layout := HBoxContainer.new()
	status_layout.add_theme_constant_override("separation", 1)
	status_bar.add_child(status_layout)
	var status_left := EditorWidgets.create_status_region()
	status_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_left.size_flags_stretch_ratio = 17.0
	status_layout.add_child(status_left)
	program_status_label = Label.new()
	program_status_label.visible = false
	program_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	program_status_label.add_theme_font_size_override("font_size", 11)
	program_status_label.add_theme_color_override("font_color", Color("#f2c94c"))
	status_left.add_child(program_status_label)
	var status_middle := EditorWidgets.create_status_region()
	status_middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_middle.size_flags_stretch_ratio = 64.0
	status_layout.add_child(status_middle)
	info_bar = HBoxContainer.new()
	info_bar.add_theme_constant_override("separation", 16)
	status_middle.add_child(info_bar)
	var status_right := EditorWidgets.create_status_region()
	status_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_right.size_flags_stretch_ratio = 17.0
	status_layout.add_child(status_right)
	status_clear_timer = Timer.new()
	status_clear_timer.one_shot = true
	status_clear_timer.wait_time = 2.5
	status_clear_timer.timeout.connect(_clear_status_message)
	add_child(status_clear_timer)

	_create_asset_dialog()
	_create_asset_rename_dialog()
	_create_component_dialog()
	_create_group_dialog()
	_create_component_draw_mode_menu()
	_create_component_add_menu()
	_create_component_context_menu()
	_create_guide_dialog()
	_create_reference_image_dialog()
	reference_image_crop_dialog = ReferenceImageCropDialog.new()
	reference_image_crop_dialog.image_accepted.connect(_save_reference_image_result)
	reference_image_crop_dialog.image_cropped.connect(_save_reference_image_result)
	add_child(reference_image_crop_dialog)
	_create_world_dialogs()
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
		pending_component_remove_ids.clear()
		pending_component_remove_group_id = ""
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
	motion_paths.append(WorldDocumentService.default_motion_path(path_id, path_name))
	selected_motion_path_id = path_id
	motion_path_dialog.hide()
	_invalidate_render(RENDER_DOCUMENT)


func _confirm_motion_sequence_creation() -> void:
	var sequence_name := motion_sequence_name_input.text.strip_edges()
	if sequence_name.is_empty():
		sequence_name = "Sequence %02d" % next_motion_sequence_id
	_record_direct_change()
	var sequence_id := "sequence_%d" % next_motion_sequence_id
	next_motion_sequence_id += 1
	motion_sequences.append(WorldDocumentService.default_motion_sequence(sequence_id, sequence_name))
	selected_motion_sequence_id = sequence_id
	selected_motion_sequence_entry_id = ""
	motion_sequence_view = MotionSequenceWorkspace.VIEW_COMPOSITION
	motion_sequence_phase = 0.0
	motion_sequence_playing = false
	motion_sequence_preview_loop = true
	motion_sequence_dialog.hide()
	_invalidate_render(RENDER_DOCUMENT)


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


func _create_snap_popup() -> void:
	snap_popup = PopupPanel.new()
	snap_popup.size = Vector2i(250, 230)
	snap_popup.add_theme_stylebox_override("panel", EditorWidgets.opaque_popup_style())
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
	snap_rotation_slider = EditorWidgets.create_snap_slider(1.0, 90.0, 1.0, snap_rotation_step)
	snap_rotation_slider.value_changed.connect(_on_snap_rotation_changed)
	content.add_child(snap_rotation_slider)
	_update_snap_popup_labels()
	add_child(snap_popup)


func _create_frame_popup() -> void:
	frame_popup = PopupPanel.new()
	frame_popup.size = Vector2i(300, 260)
	frame_popup.add_theme_stylebox_override("panel", EditorWidgets.opaque_popup_style())
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	frame_popup.add_child(content)
	var title := Label.new()
	title.text = "Frame Guide"
	content.add_child(title)
	frame_visible_checkbox = CheckBox.new()
	frame_visible_checkbox.text = "Visible"
	frame_visible_checkbox.focus_mode = Control.FOCUS_NONE
	frame_visible_checkbox.toggled.connect(_on_frame_visible_toggled)
	content.add_child(frame_visible_checkbox)
	var half_extent_label := Label.new()
	half_extent_label.text = "Half Extent (cm)"
	half_extent_label.add_theme_color_override("font_color", Color("#9aa3b2"))
	content.add_child(half_extent_label)
	var half_extent_grid := GridContainer.new()
	half_extent_grid.columns = 2
	half_extent_grid.add_theme_constant_override("h_separation", 8)
	half_extent_grid.add_theme_constant_override("v_separation", 4)
	content.add_child(half_extent_grid)
	_add_frame_field(half_extent_grid, "X", _editor_units_to_world(frame_half_extent.x), "half_extent", "x", 0.0)
	_add_frame_field(half_extent_grid, "Y", _editor_units_to_world(frame_half_extent.y), "half_extent", "y", 0.0)
	var offset_label := Label.new()
	offset_label.text = "Offset / Pivot (cm)"
	offset_label.add_theme_color_override("font_color", Color("#9aa3b2"))
	content.add_child(offset_label)
	var offset_grid := GridContainer.new()
	offset_grid.columns = 2
	offset_grid.add_theme_constant_override("h_separation", 8)
	offset_grid.add_theme_constant_override("v_separation", 4)
	content.add_child(offset_grid)
	_add_frame_field(offset_grid, "X", _editor_units_to_world(frame_offset.x), "offset", "x", -100000.0)
	_add_frame_field(offset_grid, "Y", _editor_units_to_world(frame_offset.y), "offset", "y", -100000.0)
	frame_summary_label = Label.new()
	frame_summary_label.add_theme_color_override("font_color", Color("#9aa3b2"))
	content.add_child(frame_summary_label)
	add_child(frame_popup)
	_update_frame_popup()


func _add_frame_field(grid: GridContainer, axis_label: String, value: float, property_group: String, axis: String, minimum: float) -> void:
	var label := Label.new()
	label.text = axis_label
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#7f8a9b"))
	grid.add_child(label)
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = 100000.0
	field.step = 0.1
	field.custom_arrow_step = 1.0
	field.set_value_no_signal(value)
	field.custom_minimum_size = Vector2(220, 26)
	field.add_theme_font_size_override("font_size", 11)
	field.value_changed.connect(_on_frame_field_changed.bind(property_group, axis))
	if property_group == "half_extent":
		frame_half_extent_fields[axis] = field
	else:
		frame_offset_fields[axis] = field
	grid.add_child(field)


func _toggle_frame_popup() -> void:
	if frame_popup.visible:
		frame_popup.hide()
		return
	var popup_position := frame_button.get_global_rect().position + Vector2(0.0, frame_button.size.y + 2.0)
	frame_popup.popup(Rect2(popup_position, frame_popup.size))


func _on_frame_visible_toggled(frame_enabled: bool) -> void:
	frame_visible = frame_enabled
	_apply_frame_to_canvas()
	_update_frame_popup()


func _on_frame_field_changed(value: float, property_group: String, axis: String) -> void:
	if not is_finite(value):
		return
	var editor_value := _world_to_editor_units(value)
	if property_group == "half_extent":
		if editor_value < 0.0:
			return
		if axis == "x":
			frame_half_extent.x = editor_value
		else:
			frame_half_extent.y = editor_value
	else:
		if axis == "x":
			frame_offset.x = editor_value
		else:
			frame_offset.y = editor_value
	_apply_frame_to_canvas()
	_update_frame_popup()


func _update_frame_popup() -> void:
	if is_instance_valid(frame_button):
		frame_button.text = "Frame: %s  ▼" % ("On" if frame_visible else "Off")
	if is_instance_valid(frame_visible_checkbox):
		frame_visible_checkbox.set_pressed_no_signal(frame_visible)
	for axis in ["x", "y"]:
		var half_field = frame_half_extent_fields.get(axis)
		if is_instance_valid(half_field):
			half_field.set_value_no_signal(_editor_units_to_world(frame_half_extent.x if axis == "x" else frame_half_extent.y))
		var offset_field = frame_offset_fields.get(axis)
		if is_instance_valid(offset_field):
			offset_field.set_value_no_signal(_editor_units_to_world(frame_offset.x if axis == "x" else frame_offset.y))
	if is_instance_valid(frame_summary_label):
		var min_corner := frame_offset - frame_half_extent
		var max_corner := frame_offset + frame_half_extent
		frame_summary_label.text = "Bounds: %s…%s × %s…%s cm" % [
			_format_scale_value(_editor_units_to_world(min_corner.x)),
			_format_scale_value(_editor_units_to_world(max_corner.x)),
			_format_scale_value(_editor_units_to_world(min_corner.y)),
			_format_scale_value(_editor_units_to_world(max_corner.y))
		]


func _apply_frame_to_canvas() -> void:
	if is_instance_valid(canvas_view):
		canvas_view.set_frame_guide(frame_visible, frame_half_extent, frame_offset)


func _create_world_scale_popup() -> void:
	world_scale_menu = Button.new()
	world_scale_menu.text = "World Settings  ▼"
	world_scale_menu.custom_minimum_size = Vector2(144, 32)
	world_scale_menu.focus_mode = Control.FOCUS_NONE
	world_scale_popup = PopupPanel.new()
	world_scale_popup.size = Vector2i(300, 310)
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
	var contour_width_label := Label.new()
	contour_width_label.text = "Contour Stroke Width (authored px)"
	content.add_child(contour_width_label)
	world_contour_stroke_width_field = SpinBox.new()
	world_contour_stroke_width_field.min_value = 0.1
	world_contour_stroke_width_field.max_value = 1024.0
	world_contour_stroke_width_field.step = 0.1
	world_contour_stroke_width_field.value = world_contour_stroke_width_px
	world_contour_stroke_width_field.custom_minimum_size = Vector2(260, 26)
	world_contour_stroke_width_field.value_changed.connect(_on_world_contour_stroke_width_changed)
	content.add_child(world_contour_stroke_width_field)
	var reference_density_label := Label.new()
	reference_density_label.text = "Reference Density: 192 px/m · all Assets"
	reference_density_label.add_theme_color_override("font_color", Color("#9aa3b2"))
	content.add_child(reference_density_label)
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


func _on_world_contour_stroke_width_changed(value: float) -> void:
	if not is_finite(value) or value <= 0.0 or is_equal_approx(value, world_contour_stroke_width_px):
		_update_world_scale_popup()
		return
	_record_direct_change()
	world_contour_stroke_width_px = value
	geometry_meshing_preview = {}
	geometry_meshing_preview_key = ""
	geometry_meshing_preview_state = "idle"
	geometry_meshing_preview_revision += 1
	_update_world_scale_popup()
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


func _apply_world_scale() -> void:
	snap_grid_step = _snap_base_step()
	if is_instance_valid(canvas_view):
		canvas_view.set_snap_settings(snap_enabled, snap_grid_step, snap_rotation_step)
		canvas_view.set_world_scale(world_grid_size)
	_update_world_scale_popup()
	_update_snap_popup_labels()
	_invalidate_render(RENDER_CANVAS_CONTEXT)


func _update_world_scale_popup() -> void:
	if is_instance_valid(world_grid_size_field):
		world_grid_size_field.set_value_no_signal(_editor_units_to_world(world_grid_size))
	if is_instance_valid(world_contour_stroke_width_field):
		world_contour_stroke_width_field.set_value_no_signal(world_contour_stroke_width_px)
	if is_instance_valid(world_scale_summary_label):
		var boxes_per_game_tile := GAME_TILE_CENTIMETERS / _editor_units_to_world(world_grid_size)
		world_scale_summary_label.text = "Contour: %s px = %s m\n1 Grid Box = %s cm\n1 Spiel-Tile = %s cm (%s Grid-Boxen)" % [
			_format_scale_value(world_contour_stroke_width_px),
			_format_meter_value(ContourStrokeService.stroke_width_meters(world_contour_stroke_width_px)),
			_format_scale_value(_editor_units_to_world(world_grid_size)),
			_format_scale_value(GAME_TILE_CENTIMETERS),
			_format_scale_value(boxes_per_game_tile)
		]


func _format_scale_value(value: float) -> String:
	var formatted := "%.2f" % value
	return _trim_decimal_zeros(formatted)


func _format_meter_value(value: float) -> String:
	var formatted := "%.5f" % value
	return _trim_decimal_zeros(formatted)


func _trim_decimal_zeros(formatted: String) -> String:
	while formatted.ends_with("0"):
		formatted = formatted.substr(0, formatted.length() - 1)
	if formatted.ends_with("."):
		formatted = formatted.substr(0, formatted.length() - 1)
	return formatted


func _editor_units_to_world(value: float) -> float:
	return ToolUnits.to_centimeters(value)


func _world_to_editor_units(value: float) -> float:
	return ToolUnits.from_centimeters(value)


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


func _create_asset_dialog() -> void:
	asset_dialog = ConfirmationDialog.new()
	asset_dialog.title = "New Asset"
	asset_dialog.dialog_text = "Enter an asset name"
	asset_dialog.size = Vector2i(360, 200)
	asset_dialog.confirmed.connect(_confirm_asset_creation)
	asset_name_input = LineEdit.new()
	asset_name_input.placeholder_text = "Asset name"
	asset_name_input.custom_minimum_size = Vector2(320, 32)
	asset_name_input.focus_mode = Control.FOCUS_ALL
	asset_name_input.text_submitted.connect(_submit_asset_name)
	asset_name_input.text_changed.connect(_on_new_asset_name_typed)
	# AcceptDialog gives every Control child the same content rect, so the two
	# fields live in one container rather than on top of each other.
	var asset_dialog_fields := VBoxContainer.new()
	asset_dialog_fields.add_theme_constant_override("separation", 6)
	asset_dialog_fields.add_child(asset_name_input)
	# A member of a Set is asked what it stands for while it is made, because
	# nothing derives that later. The suggestion follows the name until it is
	# typed over: suggested and confirmed is an answer, silently substituted is
	# an invention.
	asset_role_input = LineEdit.new()
	asset_role_input.placeholder_text = "Role — the part, not the Asset filling it"
	asset_role_input.custom_minimum_size = Vector2(320, 32)
	asset_role_input.focus_mode = Control.FOCUS_ALL
	asset_role_input.text_changed.connect(_on_new_member_role_typed)
	asset_dialog_fields.add_child(asset_role_input)
	# The one Create view no longer implies a type, so the type is chosen here
	# and stays the offered default for the next Asset.
	asset_type_input = EditorWidgets.create_option_field(_asset_type_option_items(),
		new_asset_type, _on_new_asset_type_selected)
	asset_type_input.name = "NewAssetType"
	asset_dialog_fields.add_child(asset_type_input)
	asset_dialog.add_child(asset_dialog_fields)
	add_child(asset_dialog)


func _create_asset_rename_dialog() -> void:
	# Renaming an Asset is not relabelling it: the name derives the Asset Key
	# the Catalog publishes and the directory its document, Reference Image and
	# Geometry live in. A field that commits on focus loss is the wrong shape
	# for that, so the new name is confirmed and the derived Key is shown while
	# it is typed.
	asset_rename_dialog = ConfirmationDialog.new()
	asset_rename_dialog.title = "Rename Asset"
	asset_rename_dialog.size = Vector2i(360, 200)
	asset_rename_dialog.confirmed.connect(_confirm_asset_rename)
	asset_rename_input = LineEdit.new()
	asset_rename_input.placeholder_text = "Asset name"
	asset_rename_input.custom_minimum_size = Vector2(320, 32)
	asset_rename_input.focus_mode = Control.FOCUS_ALL
	asset_rename_input.text_changed.connect(_update_asset_rename_preview)
	asset_rename_input.text_submitted.connect(_submit_asset_rename)
	asset_rename_key_label = EditorWidgets.create_inspector_field_label("Asset Key: —")
	var rename_fields := VBoxContainer.new()
	rename_fields.add_theme_constant_override("separation", 6)
	rename_fields.add_child(asset_rename_input)
	rename_fields.add_child(asset_rename_key_label)
	asset_rename_dialog.add_child(rename_fields)
	add_child(asset_rename_dialog)


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
	component_name_input.text_changed.connect(_on_component_name_input_changed)
	component_dialog.add_child(component_name_input)
	component_name_hint = Label.new()
	component_name_hint.custom_minimum_size = Vector2(320, 24)
	component_name_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	component_dialog.add_child(component_name_hint)
	add_child(component_dialog)


func _create_group_dialog() -> void:
	group_dialog = ConfirmationDialog.new()
	group_dialog.title = "Create Group"
	group_dialog.dialog_text = "Enter a Group name"
	group_dialog.size = Vector2i(360, 160)
	group_dialog.confirmed.connect(_confirm_group_creation)
	group_name_input = LineEdit.new()
	group_name_input.placeholder_text = "Group name"
	group_name_input.custom_minimum_size = Vector2(320, 32)
	group_name_input.text_submitted.connect(func(_text: String) -> void: _confirm_group_creation())
	group_name_input.text_changed.connect(func(_text: String) -> void:
		var asset := _get_asset(str(group_dialog.get_meta("asset_id", "")))
		group_dialog.get_ok_button().disabled = not _group_name_validation_error(asset, group_name_input.text).is_empty()
	)
	group_dialog.add_child(group_name_input)
	add_child(group_dialog)


func _create_component_draw_mode_menu() -> void:
	component_draw_mode_menu = PopupMenu.new()
	component_draw_mode_menu.add_item("Closed Loop", 0)
	component_draw_mode_menu.add_item("Contour", 1)
	component_draw_mode_menu.add_item("Primitive", 2)
	EditorWidgets.style_popup_menu(component_draw_mode_menu)
	component_draw_mode_menu.id_pressed.connect(_on_component_draw_mode_selected)
	add_child(component_draw_mode_menu)


func _create_component_add_menu() -> void:
	component_add_menu = PopupMenu.new()
	component_add_menu.name = "ComponentAddMenu"
	component_add_child_menu = PopupMenu.new()
	component_add_child_menu.name = "ChildTypes"
	component_add_child_menu.add_item("Closed Loop", 0)
	component_add_child_menu.add_item("Contour", 1)
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
	component_add_weapon_guide_menu = PopupMenu.new()
	component_add_weapon_guide_menu.name = "WeaponGuideTypes"
	component_add_weapon_guide_menu.add_item("weapon_socket_primary", 0)
	component_add_weapon_guide_menu.add_item("grip_primary", 1)
	component_add_weapon_guide_menu.add_item("grip_secondary", 2)
	component_add_weapon_guide_menu.add_item("attack_point_primary", 3)
	component_add_weapon_guide_menu.add_item("reach_limit_primary", 4)
	component_add_weapon_guide_menu.id_pressed.connect(_on_component_add_weapon_guide_selected)
	component_add_guide_menu.add_child(component_add_weapon_guide_menu)
	component_add_guide_menu.add_separator()
	component_add_guide_menu.add_submenu_item("Weapon", "WeaponGuideTypes")
	component_add_region_menu = PopupMenu.new()
	component_add_region_menu.name = "RegionTypes"
	component_add_region_menu.add_item("Attack Region", 0)
	component_add_region_menu.add_item("Hurt Region", 1)
	component_add_region_menu.add_item("Collision Region", 2)
	component_add_region_menu.id_pressed.connect(_on_component_add_region_selected)
	component_add_menu.add_child(component_add_region_menu)
	component_add_reference_menu = PopupMenu.new()
	component_add_reference_menu.name = "ReferenceSources"
	component_add_reference_menu.id_pressed.connect(_on_component_add_reference_selected)
	component_add_menu.add_child(component_add_reference_menu)
	component_add_menu.add_submenu_item("Child", "ChildTypes")
	component_add_menu.add_submenu_item("Guide", "GuideTypes")
	component_add_menu.add_submenu_item("Region", "RegionTypes")
	component_add_menu.add_submenu_item("Reference", "ReferenceSources")
	EditorWidgets.style_popup_menu(component_add_menu)
	EditorWidgets.style_popup_menu(component_add_child_menu)
	EditorWidgets.style_popup_menu(component_add_guide_menu)
	EditorWidgets.style_popup_menu(component_add_weapon_guide_menu)
	EditorWidgets.style_popup_menu(component_add_region_menu)
	EditorWidgets.style_popup_menu(component_add_reference_menu)
	add_child(component_add_menu)
	# A Set is assembled from its members, so its Asset root offers members
	# rather than draw modes.
	# A Set is authored top down: Add makes the member Asset and the Reference
	# that carries it into the assembly in one step.
	set_member_menu = PopupMenu.new()
	set_member_menu.name = "SetMemberMenu"
	set_member_menu.add_item("New Member Asset…", 0)
	set_member_menu.id_pressed.connect(_on_set_add_selected)
	EditorWidgets.style_popup_menu(set_member_menu)
	add_child(set_member_menu)
	palette_variant_menu = PopupMenu.new()
	palette_variant_menu.name = "PaletteVariantMenu"
	palette_variant_menu.add_item("New Variant Asset…", 0)
	palette_variant_menu.id_pressed.connect(_on_palette_add_selected)
	EditorWidgets.style_popup_menu(palette_variant_menu)
	add_child(palette_variant_menu)


func _create_component_context_menu() -> void:
	component_context_menu = PopupMenu.new()
	component_context_menu.name = "ComponentContextMenu"
	component_context_menu.add_separator()
	component_context_menu.add_item("Group", 4)
	component_context_menu.add_item("Remove from Group", 5)
	component_context_menu.add_separator()
	component_context_menu.add_item("Copy Components", 6)
	component_context_menu.add_item("Paste Components", 7)
	component_context_menu.add_separator()
	component_context_menu.add_item("Duplicate", 0)
	component_context_menu.add_separator()
	component_context_menu.add_item("Duplicate & Mirror Y · Keep Orientation", 1)
	component_context_menu.add_item("Duplicate & Mirror Y · Flip Orientation", 2)
	component_context_menu.add_item("Duplicate & Mirror X · Keep Orientation", 8)
	component_context_menu.add_item("Duplicate & Mirror X · Flip Orientation", 9)
	component_context_menu.add_separator()
	component_context_menu.add_item("Detach from Parent", 3)
	EditorWidgets.style_popup_menu(component_context_menu)
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


func _create_world_dialogs() -> void:
	world_name_dialog = ConfirmationDialog.new()
	world_name_dialog.title = "New World"
	world_name_dialog.dialog_text = "Enter a World name"
	world_name_dialog.ok_button_text = "Create"
	world_name_dialog.size = Vector2i(360, 160)
	world_name_dialog.confirmed.connect(_confirm_new_world)
	world_name_input = LineEdit.new()
	world_name_input.placeholder_text = "World name"
	world_name_input.custom_minimum_size = Vector2(320, 32)
	world_name_input.focus_mode = Control.FOCUS_ALL
	world_name_input.text_submitted.connect(_submit_world_name)
	world_name_dialog.add_child(world_name_input)
	add_child(world_name_dialog)

	load_world_dialog = ConfirmationDialog.new()
	load_world_dialog.title = "Load World"
	load_world_dialog.dialog_text = ""
	load_world_dialog.ok_button_text = "Load"
	load_world_dialog.size = Vector2i(420, 320)
	load_world_dialog.confirmed.connect(_load_selected_world)
	world_list = ItemList.new()
	world_list.custom_minimum_size = Vector2(380, 220)
	world_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_list.item_activated.connect(_load_selected_world)
	load_world_dialog.add_child(world_list)
	add_child(load_world_dialog)
	reload_world_dialog = ConfirmationDialog.new()
	reload_world_dialog.title = "Reload Current World"
	reload_world_dialog.ok_button_text = "Reload"
	reload_world_dialog.size = Vector2i(440, 190)
	reload_world_dialog.confirmed.connect(_reload_current_world)
	add_child(reload_world_dialog)

	eye_contour_stroke_dialog = ConfirmationDialog.new()
	eye_contour_stroke_dialog.title = "Set Eye Contour Width"
	eye_contour_stroke_dialog.dialog_text = "Set every Component whose name contains ‘eye’. Reference overrides stay local and apply to all Contour parts of their source Asset."
	eye_contour_stroke_dialog.ok_button_text = "Apply"
	eye_contour_stroke_dialog.size = Vector2i(500, 210)
	eye_contour_stroke_dialog.confirmed.connect(_apply_eye_contour_stroke_width)
	eye_contour_stroke_width_field = SpinBox.new()
	eye_contour_stroke_width_field.min_value = 0.1
	eye_contour_stroke_width_field.max_value = 1024.0
	eye_contour_stroke_width_field.step = 0.1
	eye_contour_stroke_width_field.value = 3.0
	eye_contour_stroke_width_field.custom_minimum_size = Vector2(320, 32)
	eye_contour_stroke_dialog.add_child(eye_contour_stroke_width_field)
	add_child(eye_contour_stroke_dialog)


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
	_update_export_toolbar_buttons()
	if is_instance_valid(draw_mode_status):
		draw_mode_status.visible = active_module != "Export"
	create_action_button.visible = (active_module == "Create" and active_create_submodule in CREATE_SUBMODULES) or (active_module == "Style" and active_style_submodule == "Weighting")
	var selected_component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	create_action_button.disabled = active_module == "Style" and active_style_submodule == "Weighting" \
		and (selected_component_id.is_empty() or _is_hole_component(selected_component))
	var show_asset_create_controls := active_module == "Create" and active_create_submodule in CREATE_SUBMODULES
	if is_instance_valid(snap_button):
		snap_button.visible = show_asset_create_controls
	if not show_asset_create_controls and is_instance_valid(snap_popup):
		snap_popup.hide()
	if is_instance_valid(frame_button):
		frame_button.visible = show_asset_create_controls
	if not show_asset_create_controls and is_instance_valid(frame_popup):
		frame_popup.hide()
	if active_module == "Create" and active_create_submodule in CREATE_SUBMODULES:
		create_action_button.text = ("Create %s" % active_create_submodule) if active_create_submodule in ["Set", "Palette"] else "Create Asset"
	elif active_module == "Style" and active_style_submodule == "Weighting":
		create_action_button.text = "Create Weighting Style"
	elif active_module == "Motion" and active_motion_submodule == "Path":
		create_action_button.text = "Create Path"
	elif active_module == "Motion" and active_motion_submodule == "Sequence":
		create_action_button.text = "Create Sequence"


func _on_world_menu_id(id: int) -> void:
	if id == 0:
		_open_new_world_dialog(false)
	elif id == 1:
		_save_world()
	elif id == 2:
		_open_load_world_dialog()
	elif id == 3 and not world_name.is_empty():
		reload_world_dialog.dialog_text = "Reload '%s' from disk?\n\nUnsaved editor changes will be discarded. Use this after an external script changes World files." % world_name
		reload_world_dialog.popup_centered()
	elif id == 4 and not world_name.is_empty():
		eye_contour_stroke_width_field.grab_focus()
		eye_contour_stroke_dialog.popup_centered()


func _apply_eye_contour_stroke_width() -> void:
	if world_name.is_empty():
		return
	var width := float(eye_contour_stroke_width_field.value)
	if not is_finite(width) or width <= 0.0:
		return
	var matching_components: Array[Dictionary] = []
	for asset in assets:
		if not asset is Dictionary:
			continue
		for component in asset.get("components", []):
			if not component is Dictionary:
				continue
			if EYE_COMPONENT_NAME_TOKEN not in str(component.get("name", "")).to_lower():
				continue
			if is_equal_approx(_effective_contour_stroke_width_px(component), width):
				continue
			matching_components.append(component)
	if matching_components.is_empty():
		_show_status_message("Eye Contour Width already matches %s px." % _format_scale_value(width))
		return
	_record_direct_change()
	for component in matching_components:
		if is_equal_approx(width, world_contour_stroke_width_px):
			component.erase("contour_stroke_width_px")
		else:
			component["contour_stroke_width_px"] = width
	geometry_meshing_preview = {}
	geometry_meshing_preview_key = ""
	geometry_meshing_preview_state = "idle"
	geometry_meshing_preview_revision += 1
	_save_world()
	_refresh_export_preflight(true)
	_show_status_message("Set Eye Contour Width to %s px on %d Component%s." % [
		_format_scale_value(width), matching_components.size(), "" if matching_components.size() == 1 else "s"
	])
	_invalidate_render(RENDER_DOCUMENT)


func _open_new_world_dialog(save_after_creation: bool) -> void:
	pending_save_after_new = save_after_creation
	world_name_input.text = ""
	world_name_dialog.dialog_text = "Enter a World name"
	world_name_dialog.popup_centered()
	world_name_input.grab_focus()


func _submit_world_name(_submitted_text: String) -> void:
	_confirm_new_world()


func _confirm_new_world() -> void:
	var should_save := pending_save_after_new
	var new_name := world_name_input.text.strip_edges()
	if new_name.is_empty():
		new_name = _next_default_world_name()
	new_name = _sanitize_world_name(new_name)
	world_name = new_name
	world_title = new_name
	world_contour_stroke_width_px = WorldSettingsService.DEFAULT_CONTOUR_STROKE_WIDTH_PX
	assets.clear()
	motion_paths.clear()
	motion_acts.clear()
	motion_sequences.clear()
	geometry_documents.clear()
	shared_geometry_document_keys.clear()
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
	retired_assets.clear()
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
	world_name_dialog.hide()
	_invalidate_render(RENDER_DOCUMENT)
	if should_save:
		_save_world()


func _open_load_world_dialog() -> void:
	world_list.clear()
	var names := _list_world_names()
	for world_entry in names:
		world_list.add_item(world_entry)
		world_list.set_item_metadata(world_list.item_count - 1, world_entry)
	if world_list.item_count > 0:
		world_list.select(0)
	load_world_dialog.popup_centered()
	world_list.grab_focus()


func _load_selected_world(_index := -1) -> void:
	var selected_indices := world_list.get_selected_items()
	if selected_indices.is_empty():
		return
	var index := selected_indices[0]
	var world_entry := str(world_list.get_item_metadata(index))
	if _load_world(world_entry):
		load_world_dialog.hide()


func _reload_current_world() -> void:
	if world_name.is_empty():
		return
	if _load_world(world_name):
		_show_status_message("Reloaded World: %s" % world_name)


func _list_world_names() -> Array[String]:
	var names: Array[String] = []
	var directory := DirAccess.open(WORLDS_ROOT)
	if directory == null:
		return names
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if directory.current_is_dir() and not entry.begins_with(".") and FileAccess.file_exists("%s/%s/%s.json" % [WORLDS_ROOT, entry, entry]):
			names.append(entry)
		entry = directory.get_next()
	directory.list_dir_end()
	names.sort()
	return names


func _next_default_world_name() -> String:
	var existing := _list_world_names()
	var index := 1
	while existing.has("world%02d" % index):
		index += 1
	return "world%02d" % index


func _sanitize_world_name(value: String) -> String:
	var sanitized := value.strip_edges()
	for character in ["/", "\\", ":"]:
		sanitized = sanitized.replace(character, "_")
	if sanitized == "." or sanitized == ".." or sanitized.is_empty():
		return _next_default_world_name()
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
	return _asset_storage_name_for(str(asset.get("id", "asset")), str(asset.get("name", "")))


func _asset_storage_name_for(asset_id: String, asset_name: String) -> String:
	# The directory an Asset of this name would use. Taking the name as an
	# argument rather than reading it off the Asset is what lets a rename ask
	# where the files would have to go before it changes anything.
	var base := _sanitize_asset_storage_name(asset_name, asset_id)
	var has_name_collision := false
	for other_asset in assets:
		if str(other_asset.get("id", "")) == asset_id:
			continue
		if _sanitize_asset_storage_name(str(other_asset.get("name", "")), str(other_asset.get("id", "asset"))) == base:
			has_name_collision = true
			break
	return "%s__%s" % [base, asset_id] if has_name_collision else base


func _asset_storage_directory(world_root: String, asset_id: String) -> String:
	return str(_asset_storage_directories(world_root).get(asset_id, ""))


func _asset_storage_directories(world_root: String) -> Dictionary:
	# Where each Asset's document actually lies, by ID. That is not always the
	# directory its current name derives: a rename moves the files at once while
	# the name reaches the document only at the next save, and a World written
	# by an older build kept the directory of the name the Asset was created
	# with. Reading this rather than deriving it is what keeps a rename that was
	# never saved from looking like an Asset whose Geometry disappeared.
	return _asset_storage_scan(world_root).get("directories", {})


func _asset_storage_scan(world_root: String) -> Dictionary:
	# One pass over the Asset directories: which directory each ID was found in,
	# and every ID that was found in more than one. A duplicate is a leftover of
	# a rename made before renames moved their files, and it matters because the
	# first directory found wins — which is alphabetical order deciding which
	# version of an Asset the World loads.
	var directories: Dictionary = {}
	var duplicates: Dictionary = {}
	var directory := DirAccess.open("%s/assets" % world_root)
	if directory == null:
		return {"directories": directories, "duplicates": duplicates}
	for entry in directory.get_directories():
		for file_name in DirAccess.get_files_at(ProjectSettings.globalize_path("%s/assets/%s" % [world_root, entry])):
			if not str(file_name).to_lower().ends_with(".json"):
				continue
			var candidate = WorldDocumentService.read_json("%s/assets/%s/%s" % [world_root, entry, file_name])
			if not candidate is Dictionary or not candidate.has("id"):
				continue
			var candidate_id := str(candidate.get("id", ""))
			if directories.has(candidate_id):
				var seen: Array = duplicates.get(candidate_id, [str(directories[candidate_id])])
				seen.append(str(entry))
				duplicates[candidate_id] = seen
				continue
			directories[candidate_id] = str(entry)
	return {"directories": directories, "duplicates": duplicates}


func _duplicate_asset_storage_message(duplicates: Dictionary, used: Dictionary) -> String:
	# Names one case fully and counts the rest: the point is that the reader
	# learns which copy is being read and that another one exists.
	if duplicates.is_empty():
		return ""
	var first_id := str(duplicates.keys()[0])
	var elsewhere: Array = duplicates.get(first_id, [])
	var message := "%s lies in %d directories · loading assets/%s" % [first_id, elsewhere.size(), str(used.get(first_id, "?"))]
	if duplicates.size() > 1:
		message += " · %d more Assets affected" % (duplicates.size() - 1)
	return message


func _asset_storage_move_plan(world_root: String, current_directory: String, new_directory: String) -> Dictionary:
	# What a rename has to move, decided before anything is touched. An Asset is
	# addressed on disk through its name: the document, the Reference Image
	# beside it and the Geometry documents all live under the derived directory,
	# so a rename that changed only the label would strand all three.
	if current_directory.is_empty() or current_directory == new_directory:
		return {"moves": [], "blocked": ""}
	var asset_source := "%s/assets/%s" % [world_root, current_directory]
	var asset_target := "%s/assets/%s" % [world_root, new_directory]
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(asset_target)):
		return {"moves": [], "blocked": "assets/%s already exists" % new_directory}
	var geometry_source := "%s/geometry/%s" % [world_root, current_directory]
	var geometry_target := "%s/geometry/%s" % [world_root, new_directory]
	var moves: Array = [{"from": asset_source, "to": asset_target}]
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(geometry_source)):
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(geometry_target)):
			return {"moves": [], "blocked": "geometry/%s already exists" % new_directory}
		moves.append({"from": geometry_source, "to": geometry_target})
	# The document is named after its directory, so it travels under the new
	# name; a leftover file under the old one would be read back as a second
	# Asset of the same ID.
	if FileAccess.file_exists(ProjectSettings.globalize_path("%s/%s.json" % [asset_source, current_directory])):
		moves.append({"from": "%s/%s.json" % [asset_target, current_directory],
			"to": "%s/%s.json" % [asset_target, new_directory]})
	return {"moves": moves, "blocked": ""}


func _apply_asset_storage_moves(moves: Array) -> String:
	# A half-moved Asset is worse than one that was not renamed, so a failure
	# puts back what already moved and the rename is refused as a whole.
	var applied: Array = []
	for move in moves:
		var from_path := ProjectSettings.globalize_path(str(move.get("from", "")))
		var to_path := ProjectSettings.globalize_path(str(move.get("to", "")))
		if DirAccess.rename_absolute(from_path, to_path) == OK:
			applied.push_front(move)
			continue
		for undo in applied:
			DirAccess.rename_absolute(ProjectSettings.globalize_path(str(undo.get("to", ""))),
				ProjectSettings.globalize_path(str(undo.get("from", ""))))
		return "could not move %s" % str(move.get("from", "")).get_file()
	return ""


func _asset_storage_root(world_root: String, asset: Dictionary) -> String:
	return "%s/assets/%s" % [world_root, _asset_storage_name(asset)]


func _asset_key(asset: Dictionary) -> String:
	return AssetCatalogService.asset_key(str(asset.get("name", "")))


func _asset_name_validation_error(proposed_name: String, excluded_asset_id := "") -> String:
	var key := AssetCatalogService.asset_key(proposed_name)
	if key.is_empty():
		return "The Asset name must contain at least one ASCII letter or number."
	for other_asset in assets:
		if str(other_asset.get("id", "")) == excluded_asset_id:
			continue
		if _asset_key(other_asset) == key:
			return "Asset Key '%s' is already used by '%s'." % [key, str(other_asset.get("name", "Asset"))]
	# A Key that once meant something must not quietly come to mean something
	# else. A consumer that wrote the Key down and has no ID beside it cannot
	# tell the difference, so the Key a deleted Asset carried last is spent.
	for retired in retired_assets:
		if retired is Dictionary and str(retired.get("last_asset_key", "")) == key:
			return "Asset Key '%s' belonged to a deleted Asset and is not handed out again." % key
	# The same holds for a Key an Asset left behind: it is still published under
	# `previous_keys`, and taking it over would make that trail point at the
	# wrong Asset.
	for other_asset in assets:
		if str(other_asset.get("id", "")) == excluded_asset_id:
			continue
		if WorldDocumentService.previous_asset_keys(other_asset).has(key):
			return "Asset Key '%s' was carried by '%s' before and is still published as its previous Key." % [key, str(other_asset.get("name", "Asset"))]
	return ""


func _asset_catalog_build() -> Dictionary:
	# The Catalog is the closed Runtime export set.  An Asset with invalid or
	# stale Runtime inputs must not prevent its exportable siblings from being
	# published, nor may it remain advertised with a missing package.
	var exportable_assets: Array[Dictionary] = []
	for asset in assets:
		if asset is Dictionary and bool(asset.get("visibility", true)) and bool(_runtime_export_build(asset).get("valid", false)):
			exportable_assets.append(asset)
	# References are Runtime dependencies.  Remove dependants whose source is
	# itself not publishable, repeating for reference chains.
	var exportable_ids: Dictionary = {}
	for asset in exportable_assets:
		exportable_ids[str(asset.get("id", ""))] = true
	var removed_dependency := true
	while removed_dependency:
		removed_dependency = false
		for index in range(exportable_assets.size() - 1, -1, -1):
			var asset := exportable_assets[index]
			var has_unexportable_reference := false
			for component in asset.get("components", []):
				if component is Dictionary and _effective_component_visibility(asset, component) and _is_reference_component(component) and not exportable_ids.has(str(component.get("source_asset_id", ""))):
					has_unexportable_reference = true
					break
			# A Palette depends on its variants the same way: it advertises Keys
			# a consumer must be able to resolve.
			for variant_id in WorldDocumentService.palette_variants(asset):
				if not exportable_ids.has(variant_id):
					has_unexportable_reference = true
					break
			if has_unexportable_reference:
				exportable_ids.erase(str(asset.get("id", "")))
				exportable_assets.remove_at(index)
				removed_dependency = true
	var build := AssetCatalogService.build_catalog(world_name, world_title, exportable_assets, retired_assets)
	var global_errors := AssetCatalogService.validation_errors(assets)
	if not global_errors.is_empty():
		var errors: Array = build.get("errors", [])
		errors.append_array(global_errors)
		build["valid"] = false
		build["errors"] = errors
		build["catalog"] = {}
	return build


func _current_world_root() -> String:
	# The one place the active World's directory is spelled out for the Runtime
	# export file service, which is not allowed to know about world_name.
	return "" if world_name.is_empty() else "%s/%s" % [WORLDS_ROOT, world_name]


func _asset_catalog_path() -> String:
	return RuntimeExportFileService.catalog_path(_current_world_root())


func _asset_catalog_is_stale(build: Dictionary = {}) -> bool:
	var expected := build if not build.is_empty() else _asset_catalog_build()
	if not bool(expected.get("valid", false)):
		return true
	return RuntimeExportFileService.catalog_is_stale(_current_world_root(), expected.get("catalog", {}))


func _write_asset_catalog(build: Dictionary = {}) -> bool:
	var expected := build if not build.is_empty() else _asset_catalog_build()
	if not bool(expected.get("valid", false)):
		return false
	return RuntimeExportFileService.write_catalog(_current_world_root(), expected.get("catalog", {}))


func _read_asset_data(world_root: String, asset_id: String):
	var legacy_data = WorldDocumentService.read_json("%s/assets/%s/asset.json" % [world_root, asset_id])
	var directory := DirAccess.open("%s/assets" % world_root)
	if directory == null:
		return legacy_data if legacy_data is Dictionary else {}
	for entry in directory.get_directories():
		var asset_directory := "%s/assets/%s" % [world_root, entry]
		for file_name in DirAccess.get_files_at(ProjectSettings.globalize_path(asset_directory)):
			if not str(file_name).to_lower().ends_with(".json"):
				continue
			var candidate = WorldDocumentService.read_json("%s/%s" % [asset_directory, file_name])
			if candidate is Dictionary and str(candidate.get("id", "")) == asset_id:
				if str(file_name).to_lower() != "asset.json" or entry != asset_id:
					return candidate
	return legacy_data if legacy_data is Dictionary else {}


func _save_world() -> bool:
	# Reports whether the World reached the disk, because a caller that has
	# already written something itself needs to know: a rename has moved the
	# Asset's directories before it asks for this.
	if world_name.is_empty():
		_open_new_world_dialog(true)
		return false
	var catalog_build := _asset_catalog_build()
	if not bool(catalog_build.get("valid", false)):
		var catalog_errors: Array = catalog_build.get("errors", [])
		_show_status_message("World not saved · %s" % (str(catalog_errors[0]) if not catalog_errors.is_empty() else "Asset Catalog is invalid."))
		return false
	var world_root := "%s/%s" % [WORLDS_ROOT, world_name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/assets" % world_root))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/paths" % world_root))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/acts" % world_root))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/sequences" % world_root))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/geometry" % world_root))
	var asset_ids: Array[String] = []
	var motion_path_ids: Array[String] = []
	var motion_act_ids: Array[String] = []
	var motion_sequence_ids: Array[String] = []
	# Every record is replaced atomically, so a failure leaves that file at its
	# previous content rather than truncated. Writing continues so one bad path
	# cannot cost the remaining records, and the first failure is reported.
	var unwritten: Array[String] = []
	for asset in assets:
		var asset_id := str(asset["id"])
		asset_ids.append(asset_id)
		var asset_storage_name := _asset_storage_name(asset)
		var asset_root := _asset_storage_root(world_root, asset)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(asset_root))
		var asset_data := {
			"schema_version": WorldDocumentService.SCHEMA_VERSION,
			"id": asset_id,
			"name": str(asset["name"]),
			"asset_type": _asset_type(asset),
			"authored_facing": AssetPresentation.serialize_authored_facing(asset.get("authored_facing", AssetPresentation.AuthoredFacing.NEUTRAL)),
			"visibility": bool(asset.get("visibility", true)),
			"asset_pivot": WorldDocumentService.serialize_vector(_asset_pivot(asset)),
			"root_position": WorldDocumentService.serialize_vector(AssetScaleRebaseService.root_position(asset)),
			"root_scale": WorldDocumentService.serialize_vector(AssetScaleRebaseService.root_scale(asset)),
			"reference_image": WorldDocumentService.serialize_reference_image(asset.get("reference_image", {})),
			"animation": MotionWorkspace.normalize_animation_document(asset.get("animation", {})).duplicate(true),
			"components": [],
			"groups": [],
			"guides": [],
			"asset_category": WorldDocumentService.asset_category(asset),
			"palette_variants": WorldDocumentService.palette_variants(asset),
			"previous_asset_keys": WorldDocumentService.previous_asset_keys(asset)
		}
		for group in asset.get("groups", []):
			asset_data["groups"].append({
				"id": str(group.get("id", "")),
				"name": str(group.get("name", "Group")),
				"parent_component_id": str(group.get("parent_component_id", "")),
				"transform": WorldDocumentService.serialize_transform(group.get("transform", WorldDocumentService.default_component_transform())),
				"visibility": bool(group.get("visibility", true))
			})
		for component in asset["components"]:
			var component_topology := WorldDocumentService.serialize_component_topology(component)
			var serialized_component := {
				"id": str(component["id"]),
				"type": str(component.get("type", "component")),
				"name": _normalized_component_name(component),
				"source_asset_id": str(component.get("source_asset_id", "")),
				"parent_component_id": str(component.get("parent_component_id", "")),
				"group_id": str(component.get("group_id", "")),
				"points": component_topology["points"],
				"edges": component_topology["edges"],
				"chains": component_topology["chains"],
				"transform": WorldDocumentService.serialize_transform(component.get("transform", {})),
				"visibility": bool(component.get("visibility", true)),
				"z_index": int(component.get("z_index", 0)),
				"projection_depth_cm": float(component.get("projection_depth_cm", WorldDocumentService.DEFAULT_PROJECTION_DEPTH_CM)),
				"draw_mode": WorldDocumentService.component_draw_mode(component),
				"topology_role": WorldDocumentService.topology_role(component) if WorldDocumentService.topology_role(component) in WorldDocumentService.TOPOLOGY_ROLES else WorldDocumentService.ROLE_OUTER,
				"catch_parent_component_id": str(component.get("catch_parent_component_id", "")),
				"show_point_numbers": bool(component.get("show_point_numbers", false)),
				"primitive": WorldDocumentService.serialize_primitive(component.get("primitive", {}))
			}
			if _is_region(component):
				serialized_component["region_type"] = str(component.get("region_type", "attack"))
				serialized_component["region_geometry_source"] = WorldDocumentService.normalize_region_geometry_source(component.get("region_geometry_source", ""))
			if _is_reference_component(component):
				serialized_component["reference_instance_scale"] = WorldDocumentService.serialize_vector(Vector2(component.get("reference_instance_scale", Vector2.ONE)))
				serialized_component["role"] = WorldDocumentService.reference_role(component)
			if _component_has_contour_stroke_width_override(component):
				serialized_component["contour_stroke_width_px"] = float(component["contour_stroke_width_px"])
			var serialized_alignment := WorldDocumentService.contour_stroke_alignment(component)
			if serialized_alignment != ContourStrokeService.ALIGNMENT_CENTERED:
				serialized_component["contour_stroke_alignment"] = serialized_alignment
			asset_data["components"].append(serialized_component)
		for guide in asset.get("guides", []):
			asset_data["guides"].append(WorldDocumentService.serialize_asset_guide(guide))
		if not WorldDocumentService.write_json("%s/%s.json" % [asset_root, asset_storage_name], asset_data):
			unwritten.append("%s.json" % asset_storage_name)
		for component in asset.get("components", []):
			var geometry_key := _geometry_document_key(asset_id, str(component.get("id", "")))
			if not geometry_documents.has(geometry_key):
				continue
			var geometry_path := "%s/geometry/%s/%s/geometry.json" % [world_root, asset_storage_name, str(component.get("id", ""))]
			if not WorldDocumentService.write_json(geometry_path, WorldDocumentService.serialize_geometry_document(geometry_documents[geometry_key])):
				unwritten.append(geometry_path.get_file())
			if _save_sdf_image(asset, str(component.get("id", ""))) != OK:
				unwritten.append("contour_sdf.png (%s)" % str(component.get("name", component.get("id", ""))))
	for path_document in motion_paths:
		var path_id := str(path_document.get("id", ""))
		motion_path_ids.append(path_id)
		if not WorldDocumentService.write_json("%s/paths/%s/path.json" % [world_root, path_id], {
			"schema_version": WorldDocumentService.SCHEMA_VERSION,
			"id": path_id,
			"name": str(path_document.get("name", path_id)),
			"visibility": bool(path_document.get("visibility", true)),
			"topology": MotionPathTopology.serialize(path_document.get("topology", {})),
			"playback": path_document.get("playback", {}).duplicate(true)
		}):
			unwritten.append("paths/%s/path.json" % path_id)
	for sequence_document in motion_sequences:
		var sequence_id := str(sequence_document.get("id", ""))
		motion_sequence_ids.append(sequence_id)
		if not WorldDocumentService.write_json("%s/sequences/%s/sequence.json" % [world_root, sequence_id], {
			"schema_version": WorldDocumentService.SCHEMA_VERSION,
			"id": sequence_id,
			"name": str(sequence_document.get("name", sequence_id)),
			"visibility": bool(sequence_document.get("visibility", true)),
			"next_entry_index": int(sequence_document.get("next_entry_index", 1)),
			"entries": sequence_document.get("entries", []).duplicate(true)
		}):
			unwritten.append("sequences/%s/sequence.json" % sequence_id)
	for act_document in motion_acts:
		var act_id := str(act_document.get("id", ""))
		motion_act_ids.append(act_id)
		if not WorldDocumentService.write_json("%s/acts/%s/act.json" % [world_root, act_id], WorldDocumentService.serialize_motion_act(act_document)):
			unwritten.append("acts/%s/act.json" % act_id)
	# The World index is written last, so an interrupted save leaves an index
	# that still describes the previous set of records.
	if not WorldDocumentService.write_json("%s/%s.json" % [world_root, world_name], {
		"schema_version": WorldDocumentService.SCHEMA_VERSION,
		"name": world_name,
		"world_name": world_title if not world_title.is_empty() else world_name,
		"world_settings": _serialize_world_settings(),
		"assets": asset_ids,
		"paths": motion_path_ids,
		"acts": motion_act_ids,
		"sequences": motion_sequence_ids,
		# An ID that was handed out once is never handed out again. Derived from
		# what exists, the next ID would drop back as soon as the highest Asset
		# is deleted, and the References still pointing at it would silently
		# attach to whatever is created next.
		"next_ids": _serialize_next_ids(),
		"retired_assets": retired_assets.duplicate(true),
		"editor_state": _serialize_editor_state()
	}):
		unwritten.append("%s.json" % world_name)
	if not WorldDocumentService.write_json(CONFIG_PATH, {"schema_version": WorldDocumentService.SCHEMA_VERSION, "last_world": world_name}):
		unwritten.append(CONFIG_PATH.get_file())
	if not unwritten.is_empty():
		_show_status_message(_incomplete_save_message(unwritten))
		return false
	if not _write_asset_catalog(catalog_build):
		_show_status_message("World saved, but catalog.json could not be updated.")
		return false
	_invalidate_batch_status()
	batch_status_snapshot = {}
	_show_status_message("Saved World: %s!" % world_name)
	return true


func _incomplete_save_message(unwritten: Array[String]) -> String:
	# Names the first failure so the cause is actionable, and the count so the
	# scope is visible. Records that were written are current; the rest kept
	# their previous content.
	if unwritten.size() == 1:
		return "World partly saved · %s could not be written." % unwritten[0]
	return "World partly saved · %s and %d more could not be written." % [unwritten[0], unwritten.size() - 1]


func _invalidate_render(targets: int) -> void:
	# Records what became stale instead of naming the render functions to call,
	# then renders it. Deliberately synchronous: several call sites consume the
	# render output in the statements that follow — a Context Bar menu they open,
	# a Workspace they focus once the render makes it visible, a canvas_view
	# property the render writes as well. Deferring this to the end of the frame
	# inverted that ordering.
	pending_renders |= targets
	_flush_pending_renders()


func _flush_pending_renders() -> void:
	if rendering:
		# Re-entered from inside a render; the loop below picks the target up.
		return
	rendering = true
	# A render may invalidate again. Settle here rather than leaving a stale
	# target behind, but do not spin on a render that never settles.
	var passes := 0
	while pending_renders != 0 and passes < 4:
		passes += 1
		var targets := pending_renders
		pending_renders = 0
		if targets & RENDER_OUTLINER:
			_render_outliner()
		if targets & RENDER_INSPECTOR:
			_render_inspector()
		# _render_canvas_context renders the Context Bar and the Info Bar before it
		# can return, so requesting it covers both. The reverse does not hold:
		# _render_context_bar has exit paths that leave the Info Bar alone.
		if targets & RENDER_CANVAS_CONTEXT:
			_render_canvas_context()
		else:
			if targets & RENDER_CONTEXT_BAR:
				_render_context_bar()
			if targets & RENDER_INFO_BAR:
				_render_info_bar()
	rendering = false


func _capture_history_snapshot() -> Dictionary:
	# Every captured snapshot shares the current geometry documents, so the next
	# mutation of one must copy it first.
	_mark_geometry_documents_shared()
	return {
		"world_contour_stroke_width_px": world_contour_stroke_width_px,
		"assets": assets.duplicate(true),
		"retired_assets": retired_assets.duplicate(true),
		"next_asset_id": next_asset_id,
		"next_component_id": next_component_id,
		"next_group_id": next_group_id,
		"next_guide_id": next_guide_id,
		"motion_paths": motion_paths.duplicate(true),
		"next_motion_path_id": next_motion_path_id,
		"motion_acts": motion_acts.duplicate(true),
		"next_motion_act_id": next_motion_act_id,
		"motion_sequences": motion_sequences.duplicate(true),
		"geometry_documents": geometry_documents.duplicate(false),
		"next_motion_sequence_id": next_motion_sequence_id,
		"selected_asset_id": selected_asset_id,
		"selected_component_id": selected_component_id,
		"selected_group_id": selected_group_id,
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
	world_contour_stroke_width_px = float(snapshot.get("world_contour_stroke_width_px", WorldSettingsService.DEFAULT_CONTOUR_STROKE_WIDTH_PX))
	motion_paths = snapshot.get("motion_paths", []).duplicate(true)
	motion_acts = snapshot.get("motion_acts", []).duplicate(true)
	motion_sequences = snapshot.get("motion_sequences", []).duplicate(true)
	# The snapshot keeps its own reference to these documents for redo, so the
	# restored map shares them until the next mutation copies one.
	geometry_documents = snapshot.get("geometry_documents", {}).duplicate(false)
	_mark_geometry_documents_shared()
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
	retired_assets = snapshot.get("retired_assets", []).duplicate(true)
	next_asset_id = int(snapshot.get("next_asset_id", 1))
	next_component_id = int(snapshot.get("next_component_id", 1))
	next_group_id = int(snapshot.get("next_group_id", 1))
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
	active_create_submodule = _normalized_create_submodule(str(snapshot.get("active_create_submodule", "Single")))
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
		# A Create Primitive preview is transient Canvas state that no snapshot
		# carries. Restoring the command without it would leave a State label
		# with nothing behind it, so that one tool alone drops back to Default.
		var retains_draw_tool := retained_active_state == "draw" and retained_draw_tool != "primitive"
		if retained_active_state == "draw" and not retains_draw_tool:
			retained_active_state = ""
			_set_active_context_command("")
		active_state = retained_active_state
		active_draw_tool = retained_draw_tool if retains_draw_tool else ""
		active_draw_point_mode = retained_draw_point_mode
		active_edit_mode = retained_edit_mode
		edit_bezier_handles = retained_edit_handles
		edit_point_set_mode = retained_edit_point_set_mode
		active_transform_mode = retained_transform_mode
		if active_state == "draw":
			_restore_draw_anchor_selection()
	_update_world_scale_popup()
	_invalidate_render(RENDER_DOCUMENT)


func _undo() -> void:
	if undo_history.is_empty():
		return
	history_coalescing = false
	if is_instance_valid(history_coalesce_timer):
		history_coalesce_timer.stop()
	redo_history.append(_capture_history_snapshot())
	var snapshot: Dictionary = undo_history.pop_back()
	_restore_history_snapshot(snapshot)


func _redo() -> void:
	if redo_history.is_empty():
		return
	history_coalescing = false
	if is_instance_valid(history_coalesce_timer):
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


func _load_world(world_entry: String, persist_as_last := true) -> bool:
	var world_root := "%s/%s" % [WORLDS_ROOT, world_entry]
	var world_data = WorldDocumentService.read_json("%s/%s.json" % [world_root, world_entry])
	if not WorldDocumentService.has_supported_schema(world_data):
		return false
	var world_schema := int(world_data.get("schema_version", 0))
	var decoded_world_settings := WorldSettingsService.decode(world_data.get("world_settings", null), world_schema)
	if not bool(decoded_world_settings.get("valid", false)):
		return false
	var loaded_world_settings: Dictionary = decoded_world_settings.get("settings", {})
	var loaded_assets: Array[Dictionary] = []
	for asset_id_variant in world_data.get("assets", []):
		var asset_id := str(asset_id_variant)
		var asset_data = _read_asset_data(world_root, asset_id)
		if not WorldDocumentService.has_supported_schema(asset_data):
			continue
		loaded_assets.append(WorldDocumentService.deserialize_asset(asset_data, asset_id))
	assets = loaded_assets
	var loaded_geometry_documents: Dictionary = {}
	# Geometry lies beside its Asset's document, so it is read from where that
	# document actually is rather than from where the Asset's name says it
	# should be. The two differ after a rename that has not been saved yet.
	var storage_scan := _asset_storage_scan(world_root)
	var storage_directories: Dictionary = storage_scan.get("directories", {})
	var duplicate_message := _duplicate_asset_storage_message(storage_scan.get("duplicates", {}), storage_directories)
	if not duplicate_message.is_empty():
		_show_status_message("Duplicate Asset document · %s" % duplicate_message)
	for loaded_asset in loaded_assets:
		var loaded_asset_id := str(loaded_asset.get("id", ""))
		var storage_directory := str(storage_directories.get(loaded_asset_id, _asset_storage_name(loaded_asset)))
		for loaded_component in loaded_asset.get("components", []):
			var loaded_component_id := str(loaded_component.get("id", ""))
			var geometry_data = WorldDocumentService.read_json("%s/geometry/%s/%s/geometry.json" % [world_root, storage_directory, loaded_component_id])
			if WorldDocumentService.has_supported_schema(geometry_data):
				loaded_geometry_documents[_geometry_document_key(loaded_asset_id, loaded_component_id)] = WorldDocumentService.normalize_geometry_document(geometry_data, loaded_asset_id, loaded_component_id)
	var loaded_motion_paths: Array[Dictionary] = []
	for path_id_variant in world_data.get("paths", []):
		var path_id := str(path_id_variant)
		var path_data = WorldDocumentService.read_json("%s/paths/%s/path.json" % [world_root, path_id])
		if WorldDocumentService.has_supported_schema(path_data):
			loaded_motion_paths.append(WorldDocumentService.normalize_motion_path(path_data, path_id))
	var loaded_motion_sequences: Array[Dictionary] = []
	for sequence_id_variant in world_data.get("sequences", []):
		var sequence_id := str(sequence_id_variant)
		var sequence_data = WorldDocumentService.read_json("%s/sequences/%s/sequence.json" % [world_root, sequence_id])
		if WorldDocumentService.has_supported_schema(sequence_data):
			loaded_motion_sequences.append(WorldDocumentService.normalize_motion_sequence(sequence_data, sequence_id))
	var loaded_motion_acts: Array[Dictionary] = []
	for act_id_variant in world_data.get("acts", []):
		var act_id := str(act_id_variant)
		var act_data = WorldDocumentService.read_json("%s/acts/%s/act.json" % [world_root, act_id])
		if WorldDocumentService.has_supported_schema(act_data):
			loaded_motion_acts.append(WorldDocumentService.normalize_motion_act(act_data, act_id))
	motion_paths = loaded_motion_paths
	motion_acts = loaded_motion_acts
	motion_sequences = loaded_motion_sequences
	geometry_documents = loaded_geometry_documents
	shared_geometry_document_keys.clear()
	world_contour_stroke_width_px = float(loaded_world_settings.get("contour_stroke_width_px", WorldSettingsService.DEFAULT_CONTOUR_STROKE_WIDTH_PX))
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
	var saved_editor_state = world_data.get("editor_state", {})
	if saved_editor_state is Dictionary and str(saved_editor_state.get("world_scale", {}).get("unit", "")) == "m":
		_convert_asset_units(assets, 100.0)
	world_name = str(world_data.get("name", world_entry))
	world_title = str(world_data.get("world_name", world_name))
	_restore_editor_state(world_data.get("editor_state", {}), int(world_data.get("schema_version", 0)))
	retired_assets = WorldDocumentService.deserialize_retired_assets(world_data.get("retired_assets", []))
	_update_next_ids()
	_restore_next_ids(world_data.get("next_ids", {}))
	active_state = ""
	_invalidate_render(RENDER_DOCUMENT)
	if persist_as_last:
		WorldDocumentService.write_json(CONFIG_PATH, {"schema_version": WorldDocumentService.SCHEMA_VERSION, "last_world": world_name})
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
				"position": WorldDocumentService.serialize_vector(asset_camera.get("position", Vector2.ZERO)),
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
		"world_scale": {
			"unit": world_unit,
			"grid_size": world_grid_size
		},
		"snap": {
			"enabled": snap_enabled,
			"mode": snap_mode,
			"grid_step": snap_grid_step,
			"rotation_step": snap_rotation_step
		},
		"frame": {
			"visible": frame_visible,
			"half_extent": WorldDocumentService.serialize_vector(frame_half_extent),
			"offset": WorldDocumentService.serialize_vector(frame_offset)
		}
	}


func _serialize_world_settings() -> Dictionary:
	return WorldSettingsService.encode(world_contour_stroke_width_px)


func _restore_editor_state(state, source_schema_version := WorldDocumentService.SCHEMA_VERSION) -> void:
	selected_asset_id = ""
	selected_component_id = ""
	selected_guide_id = ""
	selected_group_id = ""
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
	active_create_submodule = "Single"
	active_geometry_submodule = "Sampling"
	active_style_submodule = "Weighting"
	active_motion_submodule = "Animation"
	frame_visible = false
	frame_half_extent = Vector2(1.0, 1.0)
	frame_offset = Vector2.ZERO
	outliner_asset_type_filters = _default_outliner_asset_type_filters()
	_apply_outliner_asset_type_filter_checkboxes()
	expanded_assets.clear()
	asset_camera_states.clear()
	canvas_camera_asset_id = ""
	for asset in assets:
		expanded_assets[str(asset["id"])] = false
	if not state is Dictionary:
		_apply_snap_settings({})
		_apply_frame_settings({})
		return
	var requested_asset_id := str(state.get("selected_asset_id", ""))
	var selected_asset := _get_asset(requested_asset_id)
	if not selected_asset.is_empty():
		selected_asset_id = requested_asset_id
		var requested_component_id := str(state.get("selected_component_id", ""))
		if not _get_component(selected_asset, requested_component_id).is_empty():
			selected_component_id = requested_component_id
		var requested_group_id := str(state.get("selected_group_id", ""))
		if not ComponentHierarchy.group_by_id(selected_asset, requested_group_id).is_empty():
			selected_group_id = requested_group_id
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
					"position": WorldDocumentService.deserialize_vector(saved_asset_camera.get("position", [0.0, 0.0]), Vector2.ZERO),
					"zoom": clampf(float(saved_asset_camera.get("zoom", 1.0)), ComponentCanvas.MIN_ZOOM, ComponentCanvas.MAX_ZOOM)
				}
	if not selected_component_id.is_empty() or not selected_guide_id.is_empty():
		_set_outliner_asset_expanded(selected_asset_id, true)
	active_module = "Create"
	var requested_create_submodule := _normalized_create_submodule(str(state.get("active_create_submodule", "Single")))
	if not selected_asset_id.is_empty():
		# A member Asset opens in the module of the composition that owns it,
		# because that is where it is listed and authored.
		var restored_owner_id := str(_composition_owner_by_member_id().get(selected_asset_id, ""))
		requested_create_submodule = _asset_create_submodule(
			_get_asset(restored_owner_id if not restored_owner_id.is_empty() else selected_asset_id))
	_set_create_submodule_context(requested_create_submodule)
	var requested_geometry_submodule := str(state.get("active_geometry_submodule", "Sampling"))
	var requested_style_submodule := str(state.get("active_style_submodule", "Weighting"))
	# Below schema 63 the Asset filter gated Mesh and Style only, so a World
	# could be saved with every type switched off. From 63 it also gates Create,
	# where that state would read as an empty module. The saved value is
	# therefore ignored exactly once, below the step, and never after it.
	var saved_asset_type_filters = state.get("outliner_asset_type_filters", {})
	if saved_asset_type_filters is Dictionary and source_schema_version >= 63:
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
	_apply_snap_settings(state.get("snap", {}))
	_apply_frame_settings(state.get("frame", {}))
	# Worlds saved before per-asset cameras keep their one legacy view on the
	# active asset, rather than losing it during the migration.
	var saved_camera = state.get("camera", {})
	if saved_camera is Dictionary and not saved_camera.is_empty() and not selected_asset_id.is_empty() and not asset_camera_states.has(selected_asset_id):
		asset_camera_states[selected_asset_id] = {
			"position": WorldDocumentService.deserialize_vector(saved_camera.get("position", [0.0, 0.0]), Vector2.ZERO),
			"zoom": clampf(float(saved_camera.get("zoom", 1.0)), ComponentCanvas.MIN_ZOOM, ComponentCanvas.MAX_ZOOM)
		}


func _store_camera_for_asset(asset_id: String) -> void:
	if asset_id.is_empty() or not is_instance_valid(canvas_view) or _get_asset(asset_id).is_empty():
		return
	var camera_state := canvas_view.get_camera_state()
	asset_camera_states[asset_id] = {
		"position": camera_state.get("position", Vector2.ZERO),
		"zoom": clampf(float(camera_state.get("zoom", 1.0)), ComponentCanvas.MIN_ZOOM, ComponentCanvas.MAX_ZOOM)
	}


func _restore_camera_for_asset(asset_id: String) -> void:
	if asset_id.is_empty() or not is_instance_valid(canvas_view):
		return
	var camera_state = asset_camera_states.get(asset_id, {})
	if not camera_state is Dictionary or camera_state.is_empty():
		return
	canvas_view.set_camera_state(
		camera_state.get("position", Vector2.ZERO),
		clampf(float(camera_state.get("zoom", 1.0)), ComponentCanvas.MIN_ZOOM, ComponentCanvas.MAX_ZOOM)
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
		asset["root_position"] = AssetScaleRebaseService.root_position(asset) * conversion_factor
		var reference_image := WorldDocumentService.normalize_reference_image(asset.get("reference_image", {}))
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
			var transform: Dictionary = component.get("transform", WorldDocumentService.default_component_transform()).duplicate(true)
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


func _apply_frame_settings(settings) -> void:
	frame_visible = false
	frame_half_extent = Vector2(1.0, 1.0)
	frame_offset = Vector2.ZERO
	if settings is Dictionary:
		frame_visible = bool(settings.get("visible", false))
		var saved_half_extent := WorldDocumentService.deserialize_vector(settings.get("half_extent", [1.0, 1.0]), Vector2.ONE)
		var saved_offset := WorldDocumentService.deserialize_vector(settings.get("offset", [0.0, 0.0]), Vector2.ZERO)
		if saved_half_extent.is_finite() and saved_half_extent.x >= 0.0 and saved_half_extent.y >= 0.0:
			frame_half_extent = saved_half_extent
		if saved_offset.is_finite():
			frame_offset = saved_offset
	_apply_frame_to_canvas()
	_update_frame_popup()


func _asset_pivot(asset: Dictionary) -> Vector2:
	return WorldDocumentService.deserialize_vector(asset.get("asset_pivot", [0.0, 0.0]), Vector2.ZERO)


func _reference_image_path(asset: Dictionary) -> String:
	var reference_image := WorldDocumentService.normalize_reference_image(asset.get("reference_image", {}))
	var reference_file := str(reference_image.get("file", ""))
	if world_name.is_empty() or reference_file.is_empty():
		return ""
	return "%s/%s" % [_asset_storage_root("%s/%s" % [WORLDS_ROOT, world_name], asset), reference_file]


func _reference_image_filename(asset: Dictionary) -> String:
	return _reference_image_filename_for(str(asset.get("name", "")), str(asset.get("id", "asset")))


func _reference_image_filename_for(asset_name: String, asset_id: String) -> String:
	# Taken as a name rather than read off the Asset, so a rename can ask what
	# the file would be called before it changes anything.
	var safe_name := asset_name.strip_edges().to_lower().replace(" ", "_")
	for character in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		safe_name = safe_name.replace(character, "_")
	if safe_name.is_empty():
		safe_name = asset_id
	return "%s_ref.png" % safe_name


func _geometry_document_key(asset_id: String, component_id: String) -> String:
	return "%s/%s" % [asset_id, component_id]


func _sdf_image_path(asset: Dictionary, component_id: String) -> String:
	if world_name.is_empty() or asset.is_empty() or component_id.is_empty():
		return ""
	return "%s/%s/geometry/%s/%s/contour_sdf.png" % [WORLDS_ROOT, world_name, _asset_storage_name(asset), component_id]


func _save_sdf_image(asset: Dictionary, component_id: String) -> Error:
	var key := _geometry_document_key(str(asset.get("id", "")), component_id)
	if not sdf_images.has(key) or not sdf_images[key] is Image:
		return OK
	var path := _sdf_image_path(asset, component_id)
	if path.is_empty():
		return ERR_UNCONFIGURED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	# Staged and swapped like the JSON records, so a failed encode cannot leave a
	# truncated image beside a Bake that still references it.
	var staging := "%s/.%s.staging" % [path.get_base_dir(), path.get_file()]
	if FileAccess.file_exists(staging):
		DirAccess.remove_absolute(staging)
	var result := (sdf_images[key] as Image).save_png(staging)
	if result != OK:
		if FileAccess.file_exists(staging):
			DirAccess.remove_absolute(staging)
		return result
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	result = DirAccess.rename_absolute(staging, path)
	if result != OK:
		DirAccess.remove_absolute(staging)
		return result
	sdf_resource_validation_cache.clear()
	return OK


func _get_geometry_document(asset_id: String, component_id: String) -> Dictionary:
	# Read-only view. The returned Dictionary may still be shared with a history
	# snapshot, so callers must not mutate it. Use _mutable_geometry_document
	# instead, after recording the change.
	var key := _geometry_document_key(asset_id, component_id)
	return geometry_documents[key] if geometry_documents.has(key) else {}


func _mutable_geometry_document(asset_id: String, component_id: String) -> Dictionary:
	# Write access. Hands out the live document so the caller may mutate it in
	# place; every history snapshot that still shares it gets its own copy first.
	# The live Dictionary keeps its identity, so references held across a
	# recorded change stay valid.
	var key := _geometry_document_key(asset_id, component_id)
	if not geometry_documents.has(key):
		var document := WorldDocumentService.default_geometry_document(asset_id, component_id)
		shared_geometry_document_keys.erase(key)
		geometry_documents[key] = document
		return document
	var live: Dictionary = geometry_documents[key]
	if shared_geometry_document_keys.has(key):
		_copy_geometry_document_into_snapshots(key, live)
		shared_geometry_document_keys.erase(key)
	return live


func _copy_geometry_document_into_snapshots(key: String, live: Dictionary) -> void:
	# One copy of the current state, handed to every snapshot that still points
	# at the live document. Snapshots that already hold their own copy, and a
	# document no snapshot references, cost nothing.
	var preserved: Dictionary = {}
	var copied := false
	for history in [undo_history, redo_history]:
		for snapshot in history:
			var documents: Dictionary = snapshot.get("geometry_documents", {})
			if not documents.has(key) or not is_same(documents[key], live):
				continue
			if not copied:
				preserved = live.duplicate(true)
				copied = true
			documents[key] = preserved


func _mark_geometry_documents_shared() -> void:
	# Called whenever a snapshot starts referencing the current documents. The
	# flag only avoids the history walk for documents already detached.
	shared_geometry_document_keys = {}
	for key in geometry_documents:
		shared_geometry_document_keys[key] = true


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
			and AssetGuide.scope_component_id(guide) == component_id:
			guides.append(guide)
	guides.sort_custom(_sort_named_documents)
	return guides


func _cut_guides_for_component(asset: Dictionary, component_id: String) -> Array:
	var guides: Array = []
	for guide in asset.get("guides", []):
		if str(guide.get("guide_type", "")) == AssetGuide.CUT \
			and AssetGuide.scope_component_id(guide) == component_id:
			guides.append(guide)
	guides.sort_custom(_sort_named_documents)
	return guides


func _animation_spines_for_component(asset: Dictionary, component_id: String) -> Array:
	var guides: Array = []
	for guide in asset.get("guides", []):
		if str(guide.get("guide_type", "")) == AssetGuide.ANIMATION_SPINE \
			and AssetGuide.scope_component_id(guide) == component_id:
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
			and AssetGuide.scope_component_id(guide) == component_id:
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
	var resolved_method := method if not method.is_empty() else (ContourMeshService.METHOD if WorldDocumentService.is_contour(component) else str(_geometry_meshing_recipe(asset_id, component_id).get("method", "")))
	return _geometry_meshing_bakes(asset_id, component_id).get(resolved_method, {})


func _component_mesh_reference(asset_id: String, component_id: String) -> Dictionary:
	var document := _get_geometry_document(asset_id, component_id)
	return document.get("component_mesh", {}) if not document.is_empty() else {}


func _component_mesh_build_diagnostic_lines(asset_id: String, component_id: String) -> PackedStringArray:
	var lines := PackedStringArray()
	var asset := _get_asset(asset_id)
	var component := _get_component(asset, component_id)
	if component.is_empty() or WorldDocumentService.is_contour(component):
		return lines
	var reference := _component_mesh_reference(asset_id, component_id)
	var provenance: Dictionary = reference.get("build_provenance", {}) if reference.get("build_provenance", {}) is Dictionary else {}
	var provenance_mode := str(provenance.get("recipe_mode", ""))
	var recipes := _geometry_build_recipes(
		asset_id,
		component_id,
		component,
		_cut_guides_for_component(asset, component_id),
		_geometry_sampling_hole_components(asset, component_id)
	)
	var recipes_are_automatic := bool(recipes.get("automatic", false))
	if recipes_are_automatic:
		var model_version := int(recipes.get("auto_recipe_version", GeometryAutoBuildService.AUTO_RECIPE_VERSION))
		var ownership := "Recipe Ownership: Automatic · Model v%d" % model_version
		if provenance_mode.is_empty():
			ownership += " · Migration / first build pending"
		elif model_version < GeometryAutoBuildService.AUTO_RECIPE_VERSION:
			ownership += " → v%d pending" % GeometryAutoBuildService.AUTO_RECIPE_VERSION
		lines.append(ownership)
	else:
		var ownership_detail := "Exact recipe"
		if provenance_mode == "automatic":
			ownership_detail = "Changed after Auto Build"
		elif provenance_mode.is_empty():
			ownership_detail = "Legacy / unclassified recipe"
		lines.append("Recipe Ownership: Manual · %s" % ownership_detail)
	var sampling_recipe: Dictionary = recipes.get("sampling", {})
	var seeding_recipe: Dictionary = recipes.get("seeding", {})
	lines.append("Current Spacing: Boundary %.3f · Seed %.3f" % [
		float(sampling_recipe.get("parameters", {}).get("spacing", 0.0)),
		float(seeding_recipe.get("parameters", {}).get("spacing", 0.0))
	])
	var metrics: Dictionary = recipes.get("metrics", GeometryAutoBuildService.analyze(component))
	lines.append("Geometry: Area %.2f · Perimeter %.2f · Feature %.2f" % [
		float(metrics.get("area", 0.0)),
		float(metrics.get("perimeter", 0.0)),
		float(metrics.get("feature_size", 0.0))
	])
	if not recipes_are_automatic:
		lines.append("Auto Budgets: Not applied")
		return lines
	var diagnostics: Dictionary = provenance.get("automatic_diagnostics", {}) if provenance.get("automatic_diagnostics", {}) is Dictionary else {}
	var limits: Dictionary = diagnostics.get("limits", GeometryAutoBuildService.automatic_complexity_limits())
	lines.append("Auto Budgets: Samples %d · Seeds %d · Triangles %d" % [
		int(limits.get("boundary_samples", GeometryAutoBuildService.MAX_AUTOMATIC_BOUNDARY_SAMPLES)),
		int(limits.get("seeds", GeometryAutoBuildService.MAX_AUTOMATIC_SEEDS)),
		int(limits.get("triangles", GeometryAutoBuildService.MAX_AUTOMATIC_TRIANGLES))
	])
	var attempts: Array = diagnostics.get("attempts", []) if diagnostics.get("attempts", []) is Array else []
	if attempts.is_empty():
		lines.append("Attempts: Available after Update Meshes")
		return lines
	var final_attempt: Dictionary = attempts.back() if attempts.back() is Dictionary else {}
	lines.append("Last Build: Samples %d/%d · Seeds %d/%d · Triangles %d/%d" % [
		int(final_attempt.get("sample_count", 0)), int(limits.get("boundary_samples", GeometryAutoBuildService.MAX_AUTOMATIC_BOUNDARY_SAMPLES)),
		int(final_attempt.get("seed_count", 0)), int(limits.get("seeds", GeometryAutoBuildService.MAX_AUTOMATIC_SEEDS)),
		int(final_attempt.get("triangle_count", 0)), int(limits.get("triangles", GeometryAutoBuildService.MAX_AUTOMATIC_TRIANGLES))
	])
	for attempt_variant in attempts:
		if not attempt_variant is Dictionary:
			continue
		var attempt: Dictionary = attempt_variant
		var scope := str(attempt.get("scope", "initial")).capitalize()
		var outcome := str(attempt.get("outcome", "failed")).capitalize()
		var attempt_line := "Attempt %d: %s · %s" % [int(attempt.get("attempt", 0)), scope, outcome]
		var next_scope := str(attempt.get("next_retry_scope", ""))
		if outcome == "Retry" and not next_scope.is_empty() and next_scope != "none":
			attempt_line += " %s" % next_scope.capitalize()
		lines.append(attempt_line)
		var issues: Array = attempt.get("issues", []) if attempt.get("issues", []) is Array else []
		if not issues.is_empty():
			lines.append("Reason: %s" % str(issues[0]))
	var accepted: Dictionary = diagnostics.get("accepted", {}) if diagnostics.get("accepted", {}) is Dictionary else {}
	if not accepted.is_empty():
		lines.append("Quality: Min %.1f° · Mean %.3f · Aspect %.2f" % [
			float(accepted.get("minimum_angle", 0.0)),
			float(accepted.get("mean_quality", 0.0)),
			float(accepted.get("worst_aspect_ratio", 0.0))
		])
		for warning in GeometryMeshingService.quality_warnings(accepted):
			lines.append("Quality Warning: %s" % warning)
		var refinement_warning := GeometryMeshingService.boundary_refinement_warning(accepted)
		if not refinement_warning.is_empty():
			lines.append("Boundary Refinement Warning: %s" % refinement_warning)
	return lines


func _component_mesh_bake(asset_id: String, component_id: String) -> Dictionary:
	var reference := _component_mesh_reference(asset_id, component_id)
	var method := str(reference.get("method", ""))
	var bake_id := str(reference.get("bake_id", ""))
	if method.is_empty() or bake_id.is_empty():
		return {}
	var bake := _geometry_meshing_bake(asset_id, component_id, method)
	return bake if str(bake.get("bake_id", "")) == bake_id else {}


func _contour_stroke_bake(asset_id: String, component_id: String) -> Dictionary:
	return _geometry_meshing_bake(asset_id, component_id, ContourMeshService.METHOD)


func _serialized_component_contour_stroke_width_is_valid(component: Dictionary) -> bool:
	return WorldDocumentService.serialized_contour_stroke_width_is_valid(component)


func _component_has_contour_stroke_width_override(component: Dictionary) -> bool:
	return _serialized_component_contour_stroke_width_is_valid(component) and not is_equal_approx(float(component["contour_stroke_width_px"]), world_contour_stroke_width_px)


func _effective_contour_stroke_width_px(component: Dictionary) -> float:
	return float(component["contour_stroke_width_px"]) if _component_has_contour_stroke_width_override(component) else world_contour_stroke_width_px

func _component_projection_depth_cm(component: Dictionary) -> float:
	return WorldDocumentService.deserialize_projection_depth_cm(component.get("projection_depth_cm", WorldDocumentService.DEFAULT_PROJECTION_DEPTH_CM))


func _contour_stroke_bake_is_current(asset_id: String, component_id: String, component: Dictionary) -> bool:
	return ContourMeshService.matches_source(_contour_stroke_bake(asset_id, component_id), component, _effective_contour_stroke_width_px(component))


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
		if not component is Dictionary or str(component.get("type", "component")) in ["guide", "region"] or _is_reference_component(component):
			continue
		if not asset_is_visible or not _effective_component_visibility(asset, component):
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
	var stored_recipes := {
		"sampling": _geometry_sampling_recipe(asset_id, component_id),
		"seeding": _geometry_seeding_recipe(asset_id, component_id),
		"meshing": _geometry_meshing_recipe(asset_id, component_id),
		"metrics": GeometryAutoBuildService.analyze(component)
	}
	var document: Dictionary = geometry_documents.get(key, {})
	var component_mesh: Dictionary = document.get("component_mesh", {}) if document.get("component_mesh", {}) is Dictionary else {}
	var provenance: Dictionary = component_mesh.get("build_provenance", {}) if component_mesh.get("build_provenance", {}) is Dictionary else {}
	var recipe_mode := str(provenance.get("recipe_mode", ""))
	var stored_recipe_hash := GeometryAutoBuildService.pipeline_recipe_hash(stored_recipes)
	var provenance_recipe_hash := str(provenance.get("pipeline_recipe_hash", ""))
	if recipe_mode == "automatic" and not provenance_recipe_hash.is_empty() and stored_recipe_hash == provenance_recipe_hash:
		stored_recipes["automatic"] = true
		stored_recipes["auto_recipe_version"] = int(provenance.get("auto_recipe_version", 0))
		return stored_recipes
	var baked_signature = provenance.get("source_signature", {})
	if recipe_mode.is_empty() and baked_signature is Dictionary and not baked_signature.is_empty() \
		and GeometryAutoBuildService.recipes_match_legacy_automatic(component, cut_guides, hole_components, stored_recipes):
		return GeometryAutoBuildService.automatic_recipes(component, cut_guides, hole_components)
	stored_recipes["automatic"] = false
	stored_recipes["auto_recipe_version"] = 0
	return stored_recipes


func _geometry_build_signature(asset_id: String, component_id: String, component: Dictionary, recipes: Dictionary = {}) -> Dictionary:
	var asset := _get_asset(asset_id)
	var cut_guides := _cut_guides_for_component(asset, component_id)
	var hole_components := _geometry_sampling_hole_components(asset, component_id)
	var resolved_recipes := recipes if not recipes.is_empty() else _geometry_build_recipes(asset_id, component_id, component, cut_guides, hole_components)
	var stroke_width_px := _effective_contour_stroke_width_px(component)
	if WorldDocumentService.is_contour(component):
		resolved_recipes = {"contour": {"method": ContourMeshService.METHOD, "algorithm_version": ContourMeshService.ALGORITHM_VERSION, "stroke_width_px": stroke_width_px}}
	else:
		resolved_recipes = resolved_recipes.duplicate(true)
		resolved_recipes["contour_stroke"] = {"method": ContourMeshService.METHOD, "algorithm_version": ContourMeshService.ALGORITHM_VERSION, "stroke_width_px": stroke_width_px}
	return GeometryAutoBuildService.source_signature(component, cut_guides, hole_components, resolved_recipes)


func _component_is_meshable_source(asset: Dictionary, component: Dictionary) -> bool:
	return _component_mesh_source_validation_issues(asset, component).is_empty()


func _component_mesh_source_validation_issues(asset: Dictionary, component: Dictionary) -> Array[String]:
	if component.is_empty():
		return ["Component source is missing."]
	if _is_reference_component(component):
		return ["Reference Components use their source Asset Meshes."]
	if _is_region(component):
		return ["Semantic Regions do not enter the visual Mesh pipeline."]
	var draw_mode := WorldDocumentService.component_draw_mode(component)
	var stroke_width_px := _effective_contour_stroke_width_px(component)
	# A Hole owns the edge it cut and nothing else, so it is validated as the
	# stroke source it is rather than turned away for owning no Fill.
	if WorldDocumentService.is_stroke_only(component):
		var stroke_issues: Array[String] = []
		for issue in ContourMeshService.validation_issues(component, stroke_width_px):
			stroke_issues.append(str(issue))
		return stroke_issues
	if draw_mode not in [WorldDocumentService.DRAW_MODE_CLOSED_LOOP, WorldDocumentService.DRAW_MODE_PRIMITIVE]:
		return ["Draw Mode '%s' cannot be meshed." % draw_mode]
	var component_id := str(component.get("id", ""))
	var sampling_issues: Array[String] = []
	for issue in GeometrySamplingService.validation_issues(
		component,
		_cut_guides_for_component(asset, component_id),
		_geometry_sampling_hole_components(asset, component_id)
	):
		sampling_issues.append(str(issue))
	for issue in ContourMeshService.validation_issues(component, stroke_width_px):
		sampling_issues.append(str(issue))
	return sampling_issues


func _component_mesh_needs_update(asset_id: String, component: Dictionary) -> bool:
	var asset := _get_asset(asset_id)
	if asset.is_empty() or not bool(asset.get("visibility", true)) or not _effective_component_visibility(asset, component):
		return false
	if not _component_is_meshable_source(asset, component):
		return false
	var component_id := str(component.get("id", ""))
	var current_signature := _geometry_build_signature(asset_id, component_id, component)
	var reference := _component_mesh_reference(asset_id, component_id)
	var failure_signature = reference.get("last_failure_signature", {})
	if failure_signature is Dictionary and GeometryAutoBuildService.signatures_match(current_signature, failure_signature):
		return false
	if not _contour_stroke_bake_is_current(asset_id, component_id, component):
		return true
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
		if component is Dictionary and not _is_region(component) and _component_mesh_needs_update(asset_id, component):
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


func _batch_status_snapshot() -> Dictionary:
	if batch_status_snapshot_revision == batch_status_revision and not batch_status_snapshot.is_empty():
		return batch_status_snapshot
	return _rebuild_batch_status_snapshot()


func _rebuild_batch_status_snapshot() -> Dictionary:
	var mesh_candidates := _all_mesh_update_candidates()
	var runtime_candidates := _all_runtime_export_candidates()
	batch_status_snapshot = {
		"mesh": {"candidates": mesh_candidates, "summary": _mesh_batch_summary(mesh_candidates)},
		"uv": {"candidates": [], "summary": {"pending": PackedStringArray(), "attention": PackedStringArray()}},
		"sdf": {"candidates": [], "summary": {"pending": PackedStringArray(), "attention": PackedStringArray()}},
		"runtime": {"candidates": runtime_candidates, "summary": _runtime_export_batch_summary(runtime_candidates)}
	}
	batch_status_snapshot_revision = batch_status_revision
	batch_status_snapshot_build_count += 1
	return batch_status_snapshot


func _refresh_batch_status_snapshot() -> void:
	_rebuild_batch_status_snapshot()


func _update_meshes_button() -> void:
	if not is_instance_valid(update_meshes_button):
		return
	if mesh_batch_running or runtime_export_batch_running:
		return
	var status: Dictionary = _batch_status_snapshot().get("mesh", {})
	var candidates: Array = status.get("candidates", [])
	var summary: Dictionary = status.get("summary", {})
	var count := candidates.size()
	update_meshes_button.text = "Update Meshes (%d)" % count
	update_meshes_button.tooltip_text = _batch_summary_tooltip(summary, "All Meshes current")
	update_meshes_button.set_attention_count(summary.get("attention", PackedStringArray()).size())
	update_meshes_button.disabled = count == 0


func _sdf_recipe(asset_id: String, component_id: String) -> Dictionary:
	var document := _get_geometry_document(asset_id, component_id)
	return GeometrySDFService.normalize_recipe(document.get("sdf", {}).get("recipe", {})) if not document.is_empty() else GeometrySDFService.default_recipe()


func _sdf_bake(asset_id: String, component_id: String) -> Dictionary:
	var document := _get_geometry_document(asset_id, component_id)
	return document.get("sdf", {}).get("bake", {}) if not document.is_empty() else {}


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
	var visible_lines := PackedStringArray()
	for index in range(mini(lines.size(), maximum)):
		visible_lines.append(lines[index])
	if lines.size() > maximum:
			visible_lines.append("… and %d more" % (lines.size() - maximum))
	return "\n".join(visible_lines)


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
			if not component is Dictionary or not _effective_component_visibility(asset, component) or _is_reference_component(component) or _is_region(component):
				continue
			# A Hole answers for the cut it makes on its Parent as well as for the
			# Stroke it owns, and the broken cut is the more urgent of the two.
			var hole_issue := WorldDocumentService.constraint_hole_parent_validation_issue(asset, component) if _is_hole_component(component) else ""
			if not hole_issue.is_empty():
				attention.append("%s / %s — %s" % [str(asset.get("name", "Asset")), str(component.get("name", "Component")), hole_issue])
				continue
			var issues := _component_mesh_source_validation_issues(asset, component)
			var error_message := str(_component_mesh_reference(asset_id, str(component.get("id", ""))).get("last_error", ""))
			var reason := str(issues[0]) if not issues.is_empty() else error_message
			if not reason.is_empty():
				attention.append("%s / %s — %s" % [str(asset.get("name", "Asset")), str(component.get("name", "Component")), reason])
	return {"pending": _candidate_tooltip_lines(candidates), "attention": attention}


func _mesh_update_candidates_tooltip(candidates: Array[Dictionary]) -> String:
	return _batch_summary_tooltip(_mesh_batch_summary(candidates), "All Meshes current")


func _generate_component_mesh_build(asset_id: String, component_id: String) -> Dictionary:
	var asset := _get_asset(asset_id)
	var component := _get_component(asset, component_id)
	if not _component_is_meshable_source(asset, component):
		return {"valid": false, "errors": ["Component source is not meshable."]}
	if WorldDocumentService.is_stroke_only(component):
		var contour_mesh := ContourMeshService.generate(component, _effective_contour_stroke_width_px(component))
		if bool(contour_mesh.get("valid", false)):
			contour_mesh["bake_id"] = "meshing_bake_%d" % ResourceUID.create_id()
		return {
			"valid": bool(contour_mesh.get("valid", false)),
			"errors": contour_mesh.get("errors", []).duplicate(),
			"recipes": {},
			"meshing": contour_mesh,
			"source_signature": _geometry_build_signature(asset_id, component_id, component),
			"recipe_mode": "derived",
			"auto_recipe_version": 0,
			"attempts": 1
		}
	var contour_stroke := ContourMeshService.generate(component, _effective_contour_stroke_width_px(component))
	if not bool(contour_stroke.get("valid", false)):
		return {
			"valid": false,
			"errors": contour_stroke.get("errors", []).duplicate(),
			"recipes": {},
			"source_signature": _geometry_build_signature(asset_id, component_id, component),
			"recipe_mode": "automatic",
			"auto_recipe_version": GeometryAutoBuildService.AUTO_RECIPE_VERSION,
			"attempts": 1
		}
	contour_stroke["bake_id"] = "contour_stroke_bake_%d" % ResourceUID.create_id()
	var cut_guides := _cut_guides_for_component(asset, component_id)
	var hole_components := _geometry_sampling_hole_components(asset, component_id)
	var base_recipes := _geometry_build_recipes(asset_id, component_id, component, cut_guides, hole_components)
	var recipes_are_automatic := bool(base_recipes.get("automatic", false))
	if recipes_are_automatic:
		base_recipes = GeometryAutoBuildService.automatic_recipes(component, cut_guides, hole_components)
	var maximum_attempts := GeometryAutoBuildService.MAX_AUTOMATIC_ATTEMPTS if recipes_are_automatic else 1
	var last_errors: Array = []
	var retry_scope := "seed"
	var retained_boundary_retry_index := 0
	var attempt_history: Array[Dictionary] = []
	for attempt_index in range(maximum_attempts):
		var attempt_scope := "initial" if attempt_index == 0 else retry_scope
		var recipes := base_recipes if attempt_index == 0 else GeometryAutoBuildService.automatic_retry_recipes(base_recipes, attempt_index, retry_scope, retained_boundary_retry_index)
		var attempt_diagnostic := {
			"attempt": attempt_index + 1,
			"scope": attempt_scope,
			"boundary_spacing": float(recipes["sampling"]["parameters"].get("spacing", 0.0)),
			"seed_spacing": float(recipes["seeding"]["parameters"].get("spacing", 0.0)),
			"sample_count": 0,
			"seed_count": 0,
			"triangle_count": 0,
			"outcome": "failed",
			"issues": []
		}
		var sampling := GeometrySamplingService.generate(component, recipes["sampling"], cut_guides, hole_components)
		attempt_diagnostic["sample_count"] = int(sampling.get("sample_count", 0))
		if not bool(sampling.get("valid", false)):
			last_errors = sampling.get("errors", []).duplicate()
			attempt_diagnostic["issues"] = last_errors.duplicate()
			if recipes_are_automatic:
				var sampling_failure := GeometryAutoBuildService.automatic_build_assessment(sampling)
				var next_scope := str(sampling_failure.get("retry_scope", "none"))
				var can_retry := next_scope != "none" and attempt_index + 1 < maximum_attempts
				attempt_diagnostic["outcome"] = "retry" if can_retry else "failed"
				attempt_diagnostic["next_retry_scope"] = next_scope
				attempt_history.append(attempt_diagnostic)
				if can_retry:
					retry_scope = next_scope
					if next_scope == "boundary":
						retained_boundary_retry_index = attempt_index + 1
					continue
			else:
				attempt_history.append(attempt_diagnostic)
			break
		if recipes_are_automatic:
			var sampling_assessment := GeometryAutoBuildService.automatic_build_assessment(sampling)
			if not bool(sampling_assessment.get("accepted", false)):
				last_errors = sampling_assessment.get("issues", []).duplicate()
				var next_scope := str(sampling_assessment.get("retry_scope", "none"))
				var can_retry := next_scope != "none" and attempt_index + 1 < maximum_attempts
				attempt_diagnostic["issues"] = last_errors.duplicate()
				attempt_diagnostic["outcome"] = "retry" if can_retry else "failed"
				attempt_diagnostic["next_retry_scope"] = next_scope
				attempt_history.append(attempt_diagnostic)
				if can_retry:
					retry_scope = next_scope
					if next_scope == "boundary":
						retained_boundary_retry_index = attempt_index + 1
					continue
				break
		sampling["bake_id"] = "bake_%d" % ResourceUID.create_id()
		sampling["semantic_source_signature"] = GeometryAutoBuildService.source_signature(component, cut_guides, hole_components, {"sampling": recipes["sampling"]})
		var seed_guides: Array = []
		if str(recipes["seeding"].get("method", "")) == GeometrySeedingService.SPINE_FLOW:
			seed_guides = _geometry_seeding_sampler_spines(asset_id, component_id, recipes["seeding"])
		var seeding := GeometrySeedingService.generate(sampling, recipes["seeding"], seed_guides)
		attempt_diagnostic["seed_count"] = int(seeding.get("seed_count", 0))
		if not bool(seeding.get("valid", false)):
			last_errors = seeding.get("errors", []).duplicate()
			attempt_diagnostic["issues"] = last_errors.duplicate()
			attempt_history.append(attempt_diagnostic)
			break
		if recipes_are_automatic:
			var seeding_assessment := GeometryAutoBuildService.automatic_build_assessment(sampling, seeding)
			if not bool(seeding_assessment.get("accepted", false)):
				last_errors = seeding_assessment.get("issues", []).duplicate()
				var next_scope := str(seeding_assessment.get("retry_scope", "none"))
				var can_retry := next_scope != "none" and attempt_index + 1 < maximum_attempts
				attempt_diagnostic["issues"] = last_errors.duplicate()
				attempt_diagnostic["outcome"] = "retry" if can_retry else "failed"
				attempt_diagnostic["next_retry_scope"] = next_scope
				attempt_history.append(attempt_diagnostic)
				if can_retry:
					retry_scope = next_scope
					if next_scope == "boundary":
						retained_boundary_retry_index = attempt_index + 1
					continue
				break
		seeding["bake_id"] = "seeding_bake_%d" % ResourceUID.create_id()
		seeding["edited"] = false
		var meshing_recipe: Dictionary = recipes["meshing"].duplicate(true)
		meshing_recipe["parameters"]["seeding_method"] = str(recipes["seeding"].get("method", GeometrySeedingService.POISSON_FILL))
		meshing_recipe = GeometryMeshingService.normalize_recipe(meshing_recipe)
		recipes["meshing"] = meshing_recipe
		var meshing := GeometryMeshingService.generate(sampling, seeding, meshing_recipe)
		attempt_diagnostic["triangle_count"] = int(meshing.get("triangle_count", 0))
		var meshing_is_valid := bool(meshing.get("valid", false)) and int(meshing.get("triangle_count", 0)) > 0 \
			and int(meshing.get("degenerate_triangle_count", 0)) == 0 and bool(meshing.get("constraints_valid", false))
		var final_assessment: Dictionary = GeometryAutoBuildService.automatic_build_assessment(sampling, seeding, meshing) if recipes_are_automatic else {}
		if not meshing_is_valid or (recipes_are_automatic and not bool(final_assessment.get("accepted", false))):
			last_errors = final_assessment.get("issues", []).duplicate() if recipes_are_automatic else meshing.get("errors", ["Final Mesh validation failed."]).duplicate()
			if last_errors.is_empty():
				last_errors = ["Final Mesh validation failed."]
			attempt_diagnostic["issues"] = last_errors.duplicate()
			if recipes_are_automatic:
				var next_scope := str(final_assessment.get("retry_scope", "none"))
				var can_retry := next_scope != "none" and attempt_index + 1 < maximum_attempts
				attempt_diagnostic["outcome"] = "retry" if can_retry else "failed"
				attempt_diagnostic["next_retry_scope"] = next_scope
				attempt_history.append(attempt_diagnostic)
				if can_retry:
					retry_scope = next_scope
					if next_scope == "boundary":
						retained_boundary_retry_index = attempt_index + 1
					continue
			else:
				attempt_history.append(attempt_diagnostic)
			break
		meshing["bake_id"] = "meshing_bake_%d" % ResourceUID.create_id()
		attempt_diagnostic["outcome"] = "accepted"
		attempt_diagnostic["minimum_angle"] = float(meshing.get("minimum_angle", 0.0))
		attempt_diagnostic["mean_quality"] = float(meshing.get("mean_quality", 0.0))
		attempt_history.append(attempt_diagnostic)
		return {
			"valid": true,
			"errors": [],
			"recipes": recipes,
			"sampling": sampling,
			"seeding": seeding,
			"meshing": meshing,
			"contour_stroke": contour_stroke,
			"source_signature": _geometry_build_signature(asset_id, component_id, component, recipes),
			"recipe_mode": "automatic" if recipes_are_automatic else "manual",
			"auto_recipe_version": GeometryAutoBuildService.AUTO_RECIPE_VERSION if recipes_are_automatic else 0,
			"auto_build_diagnostics": {"version": 1, "limits": GeometryAutoBuildService.automatic_complexity_limits(), "attempts": attempt_history, "accepted": final_assessment} if recipes_are_automatic else {},
			"attempts": attempt_index + 1
		}
	return {"valid": false, "errors": last_errors if not last_errors.is_empty() else ["Automatic Mesh generation failed."], "recipes": base_recipes, "source_signature": _geometry_build_signature(asset_id, component_id, component, base_recipes), "recipe_mode": "automatic" if recipes_are_automatic else "manual", "auto_recipe_version": GeometryAutoBuildService.AUTO_RECIPE_VERSION if recipes_are_automatic else 0, "auto_build_diagnostics": {"version": 1, "limits": GeometryAutoBuildService.automatic_complexity_limits(), "attempts": attempt_history} if recipes_are_automatic else {}, "attempts": attempt_history.size()}


func _commit_component_mesh_build(asset_id: String, component_id: String, build: Dictionary) -> void:
	var document := _mutable_geometry_document(asset_id, component_id)
	var mesh: Dictionary = build.get("meshing", {})
	if not build.get("recipes", {}).is_empty():
		var recipes: Dictionary = build["recipes"]
		document["sampling"]["recipe"] = recipes["sampling"].duplicate(true)
		document["seeding"]["recipe"] = recipes["seeding"].duplicate(true)
		document["meshing"]["recipe"] = recipes["meshing"].duplicate(true)
		var sampling: Dictionary = build["sampling"]
		var seeding: Dictionary = build["seeding"]
		document["sampling"]["bakes"][str(sampling.get("method", ""))] = WorldDocumentService.document_safe(sampling)
		document["seeding"]["bakes"][str(seeding.get("method", ""))] = WorldDocumentService.document_safe(seeding)
	document["meshing"]["bakes"][str(mesh.get("method", ""))] = WorldDocumentService.document_safe(mesh)
	var contour_stroke = build.get("contour_stroke", mesh if str(mesh.get("method", "")) == ContourMeshService.METHOD else {})
	if contour_stroke is Dictionary and bool(contour_stroke.get("valid", false)):
		document["meshing"]["bakes"][ContourMeshService.METHOD] = WorldDocumentService.document_safe(contour_stroke)
	document["component_mesh"] = {
		"bake_id": str(mesh.get("bake_id", "")),
		"method": str(mesh.get("method", "")),
		"mesh_fingerprint": GeometryUVMappingService.mesh_fingerprint(mesh),
		"build_provenance": {
			"schema_version": GeometryAutoBuildService.SIGNATURE_VERSION,
			"source_signature": build.get("source_signature", {}).duplicate(true),
			"exact_input_hash": GeometryAutoBuildService.exact_signature_hash(build.get("source_signature", {})),
			"recipe_mode": str(build.get("recipe_mode", "manual")),
			"auto_recipe_version": int(build.get("auto_recipe_version", 0)),
			"pipeline_recipe_hash": GeometryAutoBuildService.pipeline_recipe_hash(build.get("recipes", {})) if not build.get("recipes", {}).is_empty() else "",
			"automatic_diagnostics": build.get("auto_build_diagnostics", {}).duplicate(true),
			"attempts": int(build.get("attempts", 1))
		},
		"last_error": "",
		"last_failure_signature": {}
	}


func _record_component_mesh_failure(asset_id: String, component_id: String, build: Dictionary) -> void:
	var document := _mutable_geometry_document(asset_id, component_id)
	var recipes = build.get("recipes", {})
	if recipes is Dictionary and not recipes.is_empty():
		document["sampling"]["recipe"] = recipes.get("sampling", document["sampling"]["recipe"]).duplicate(true)
		document["seeding"]["recipe"] = recipes.get("seeding", document["seeding"]["recipe"]).duplicate(true)
		document["meshing"]["recipe"] = recipes.get("meshing", document["meshing"]["recipe"]).duplicate(true)
	var reference: Dictionary = document.get("component_mesh", {}).duplicate(true)
	var errors: Array = build.get("errors", [])
	var provenance: Dictionary = reference.get("build_provenance", {}).duplicate(true) if reference.get("build_provenance", {}) is Dictionary else {}
	provenance["recipe_mode"] = str(build.get("recipe_mode", "manual"))
	provenance["auto_recipe_version"] = int(build.get("auto_recipe_version", 0))
	provenance["pipeline_recipe_hash"] = GeometryAutoBuildService.pipeline_recipe_hash(recipes) if recipes is Dictionary and not recipes.is_empty() else ""
	provenance["automatic_diagnostics"] = build.get("auto_build_diagnostics", {}).duplicate(true)
	reference["build_provenance"] = provenance
	reference["last_error"] = str(errors[0]) if not errors.is_empty() else "Automatic Mesh generation failed."
	reference["last_failure_signature"] = build.get("source_signature", {}).duplicate(true)
	document["component_mesh"] = reference


func _on_update_meshes_pressed() -> void:
	if mesh_batch_running or runtime_export_batch_running:
		return
	var candidates := _all_mesh_update_candidates()
	if candidates.is_empty():
		_update_meshes_button()
		return
	mesh_batch_running = true
	update_meshes_button.tooltip_text = _mesh_update_candidates_tooltip(candidates)
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
	_save_world()
	_refresh_export_preflight(true)
	_show_status_message("Updated %d Mesh%s%s" % [succeeded, "" if succeeded == 1 else "es", " · %d need attention" % failed if failed > 0 else ""])
	_invalidate_render(RENDER_DOCUMENT)


func _runtime_export_root() -> String:
	return RuntimeExportFileService.export_root(_current_world_root())


func _palette_variant_export_records(asset: Dictionary) -> Array:
	# What a Palette's Manifest has to know about each variant. Resolved here
	# because it is a question about other Assets, which the export service does
	# not reach into.
	var records: Array = []
	if not WorldDocumentService.is_palette_asset(asset):
		return records
	for variant_asset_id in WorldDocumentService.palette_variants(asset):
		var variant := _get_asset(variant_asset_id)
		var region_count := 0
		for component in variant.get("components", []):
			if component is Dictionary and _is_region(component):
				region_count += 1
		var attachment_frame_count := 0
		for guide in variant.get("guides", []):
			if guide is Dictionary and AssetGuide.is_weapon_frame(str(guide.get("guide_type", ""))):
				attachment_frame_count += 1
		records.append({
			"asset_id": variant_asset_id,
			"display_name": str(variant.get("name", variant_asset_id)),
			"exists": not variant.is_empty(),
			"visible": bool(variant.get("visibility", true)),
			"asset_key": _asset_key(variant) if not variant.is_empty() else "",
			"asset_type": _asset_type(variant) if not variant.is_empty() else "",
			"region_count": region_count,
			"attachment_frame_count": attachment_frame_count,
		})
	return records


func _runtime_export_build(asset: Dictionary) -> Dictionary:
	var sources: Dictionary = {}
	var asset_id := str(asset.get("id", ""))
	for component in asset.get("components", []):
		if not component is Dictionary or not bool(component.get("visibility", true)) or _is_region(component):
			continue
		var component_id := str(component.get("id", ""))
		if _is_reference_component(component):
			var source_asset_id := str(component.get("source_asset_id", ""))
			var source_asset := _get_asset(source_asset_id)
			sources[component_id] = {
				"owner_asset_id": asset_id,
				"source_asset_exists": not source_asset.is_empty(),
				"source_asset_key": _asset_key(source_asset) if not source_asset.is_empty() else "",
				"source_asset_type": _asset_type(source_asset) if not source_asset.is_empty() else ""
			}
			continue
		var contour_stroke := _contour_stroke_bake(asset_id, component_id)
		var stroke_current := _contour_stroke_bake_is_current(asset_id, component_id, component)
		var fill_required := not WorldDocumentService.is_contour(component)
		var mesh := _component_mesh_bake(asset_id, component_id) if fill_required else {}
		var mesh_current := not fill_required or _component_mesh_status(asset_id, component_id, component) == "Ready"
		sources[component_id] = {
			"mesh": mesh if mesh_current else {},
			"contour_stroke": contour_stroke if stroke_current else {}
		}
	var result := RuntimeExportService.build_manifest(asset, sources, _palette_variant_export_records(asset))
	var catalog_errors := AssetCatalogService.validation_errors(assets)
	if not catalog_errors.is_empty():
		var errors: Array = result.get("errors", [])
		errors.append_array(catalog_errors)
		result["valid"] = false
		result["errors"] = errors
		result["manifest"] = {}
	return result


func _runtime_export_is_stale(asset: Dictionary, build: Dictionary = {}) -> bool:
	var expected := build if not build.is_empty() else _runtime_export_build(asset)
	if not bool(expected.get("valid", false)):
		return true
	return RuntimeExportFileService.package_is_stale(
		_runtime_export_root(), _asset_key(asset), expected.get("manifest", {}))


func _all_runtime_package_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for asset in assets:
		if not asset is Dictionary or not bool(asset.get("visibility", true)):
			continue
		var build := _runtime_export_build(asset)
		if not bool(build.get("valid", false)) or _runtime_export_is_stale(asset, build):
			result.append({"kind": "package", "asset_id": str(asset.get("id", "")), "build": build})
	return result


func _all_runtime_export_candidates() -> Array[Dictionary]:
	var result := _all_runtime_package_candidates()
	if world_name.is_empty():
		return result
	var catalog_build := _asset_catalog_build()
	if not bool(catalog_build.get("valid", false)) or _asset_catalog_is_stale(catalog_build):
		result.append({"kind": "catalog", "asset_id": "", "build": catalog_build})
	return result


func _runtime_export_batch_summary(candidates: Array[Dictionary]) -> Dictionary:
	var pending := PackedStringArray()
	var attention := PackedStringArray()
	for candidate in candidates:
		var build: Dictionary = candidate.get("build", {})
		if str(candidate.get("kind", "package")) == "catalog":
			if bool(build.get("valid", false)):
				pending.append("World Catalog — catalog.json missing or stale")
			else:
				var catalog_errors: Array = build.get("errors", [])
				attention.append("World Catalog — %s" % (str(catalog_errors[0]) if not catalog_errors.is_empty() else "invalid"))
			continue
		var asset := _get_asset(str(candidate.get("asset_id", "")))
		if bool(build.get("valid", false)):
			pending.append("%s — package missing or stale" % str(asset.get("name", "Asset")))
		else:
			var errors: Array = build.get("errors", [])
			attention.append("%s — %s" % [str(asset.get("name", "Asset")), str(errors[0]) if not errors.is_empty() else "invalid"])
	return {"pending": pending, "attention": attention}


func _update_runtime_export_button() -> void:
	if not is_instance_valid(runtime_export_button) or mesh_batch_running or runtime_export_batch_running:
		return
	var status: Dictionary = _batch_status_snapshot().get("runtime", {})
	var candidates: Array = status.get("candidates", [])
	var summary: Dictionary = status.get("summary", {})
	runtime_export_button.text = "Export Runtime (%d)" % candidates.size()
	runtime_export_button.disabled = candidates.is_empty()
	runtime_export_button.tooltip_text = _batch_summary_tooltip(summary, "All runtime packages current")
	runtime_export_button.set_attention_count(summary.get("attention", PackedStringArray()).size())


func _on_runtime_export_pressed() -> void:
	if runtime_export_batch_running or mesh_batch_running:
		return
	var candidates := _all_runtime_export_candidates()
	if candidates.is_empty():
		_update_runtime_export_button()
		return
	runtime_export_batch_running = true
	update_meshes_button.disabled = true
	var succeeded := 0
	var failed := 0
	var catalog_requested := false
	for index in range(candidates.size()):
		runtime_export_button.text = "Exporting %d/%d" % [index + 1, candidates.size()]
		runtime_export_button.disabled = true
		await get_tree().process_frame
		if str(candidates[index].get("kind", "package")) == "catalog":
			catalog_requested = true
			continue
		var asset := _get_asset(str(candidates[index].get("asset_id", "")))
		var build := _runtime_export_build(asset)
		if bool(build.get("valid", false)) and _write_runtime_export_package(asset, build):
			succeeded += 1
		else:
			failed += 1
	var catalog_updated := false
	if catalog_requested or succeeded > 0:
		if not _has_pending_valid_runtime_packages() and _write_asset_catalog():
			catalog_updated = true
			_prune_uncataloged_runtime_packages()
		elif catalog_requested:
			failed += 1
	runtime_export_batch_running = false
	_invalidate_batch_status()
	batch_status_snapshot = {}
	_show_status_message("Exported %d Runtime package%s%s%s · %s" % [succeeded, "" if succeeded == 1 else "s", " · catalog updated" if catalog_updated else "", " · %d need attention" % failed if failed > 0 else "", _runtime_export_root()])
	_invalidate_render(RENDER_DOCUMENT)


func _write_runtime_export_package(asset: Dictionary, build: Dictionary) -> bool:
	if str(asset.get("id", "")).is_empty():
		return false
	return RuntimeExportFileService.write_package(
		_runtime_export_root(), _asset_key(asset), build.get("manifest", {}))


func _runtime_manifest_text_matches(expected_text: String, staged_text: String) -> bool:
	return RuntimeExportFileService.manifest_text_matches(expected_text, staged_text)


func _prune_uncataloged_runtime_packages() -> void:
	var catalog_build := _asset_catalog_build()
	if not bool(catalog_build.get("valid", false)):
		return
	var allowed_keys: Dictionary = {}
	for entry in catalog_build.get("catalog", {}).get("assets", []):
		if entry is Dictionary:
			allowed_keys[str(entry.get("asset_key", ""))] = true
	# Invalid visible Assets retain their last known-good package atomically.
	# They are intentionally absent from the Catalog until they validate again.
	for asset in assets:
		if asset is Dictionary and bool(asset.get("visibility", true)):
			allowed_keys[_asset_key(asset)] = true
	RuntimeExportFileService.prune_packages(_runtime_export_root(), allowed_keys)


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
	if component.is_empty() or _is_hole_component(component):
		_show_status_message("Select a Component before creating a Weighting Style.")
		return
	_record_direct_change()
	var document := _mutable_geometry_document(asset_id, component_id)
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
	_invalidate_render(RENDER_DOCUMENT)


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
	_invalidate_render(RENDER_DOCUMENT)


func _refresh_weighting_workspace() -> void:
	if not is_instance_valid(weighting_workspace):
		return
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or _is_hole_component(component):
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
	if WorldDocumentService.is_contour(component):
		return ContourMeshService.matches_source(result, component, _effective_contour_stroke_width_px(component))
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
	if WorldDocumentService.is_contour(component):
		if not ContourMeshService.validation_issues(component, _effective_contour_stroke_width_px(component)).is_empty():
			return "Invalid"
		var contour_key := _geometry_document_key(asset_id, component_id)
		if geometry_meshing_preview_key == contour_key:
			if geometry_meshing_preview_state == "calculating":
				return "Calculating"
			if geometry_meshing_preview_state == "ready" and _geometry_meshing_preview_matches(asset_id, component_id, component):
				return "Preview Ready"
		var contour_bake := _geometry_meshing_bake(asset_id, component_id, ContourMeshService.METHOD)
		return "Ready to Preview" if contour_bake.is_empty() else "Baked" if ContourMeshService.matches_source(contour_bake, component, _effective_contour_stroke_width_px(component)) else "Ready to Preview"
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
	if method == ContourMeshService.METHOD:
		return ContourMeshService.matches_source(bake, component, _effective_contour_stroke_width_px(component))
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


func _serialize_next_ids() -> Dictionary:
	return {"asset": next_asset_id, "component": next_component_id, "group": next_group_id,
		"guide": next_guide_id, "motion_path": next_motion_path_id,
		"motion_act": next_motion_act_id, "motion_sequence": next_motion_sequence_id}


func _restore_next_ids(serialized) -> void:
	# The stored counters only ever raise the derived ones: a World written
	# before schema 69 has none, and a World whose highest Asset was deleted
	# would otherwise hand that ID out a second time.
	if not serialized is Dictionary:
		return
	for retired in retired_assets:
		if retired is Dictionary:
			next_asset_id = maxi(next_asset_id, _id_suffix_number(str(retired.get("id", ""))) + 1)
	next_asset_id = maxi(next_asset_id, int(serialized.get("asset", 0)))
	next_component_id = maxi(next_component_id, int(serialized.get("component", 0)))
	next_group_id = maxi(next_group_id, int(serialized.get("group", 0)))
	next_guide_id = maxi(next_guide_id, int(serialized.get("guide", 0)))
	next_motion_path_id = maxi(next_motion_path_id, int(serialized.get("motion_path", 0)))
	next_motion_act_id = maxi(next_motion_act_id, int(serialized.get("motion_act", 0)))
	next_motion_sequence_id = maxi(next_motion_sequence_id, int(serialized.get("motion_sequence", 0)))


func _update_next_ids() -> void:
	next_asset_id = 1
	next_component_id = 1
	next_group_id = 1
	next_guide_id = 1
	next_motion_path_id = 1
	next_motion_act_id = 1
	next_motion_sequence_id = 1
	for asset in assets:
		next_asset_id = maxi(next_asset_id, _id_suffix_number(str(asset["id"])) + 1)
		for component in asset["components"]:
			next_component_id = maxi(next_component_id, _id_suffix_number(str(component["id"])) + 1)
		for group in asset.get("groups", []):
			next_group_id = maxi(next_group_id, _id_suffix_number(str(group.get("id", ""))) + 1)
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


func _render_context_bar() -> void:
	if not is_instance_valid(context_bar):
		return
	if active_module == "Export":
		_clear_context_bar()
		return
	_update_draw_mode_status()
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
		var selected_guide := _get_guide(_get_asset(selected_asset_id), selected_guide_id)
		if AssetGuide.is_weapon_frame(str(selected_guide.get("guide_type", ""))):
			var move_button := Button.new()
			move_button.text = "⌘1  Move Frame"
			move_button.pressed.connect(func() -> void: _set_transform_mode("transform"))
			context_bar.add_child(move_button)
			var rotate_button := Button.new()
			rotate_button.text = "⌘2  Rotate Frame"
			rotate_button.pressed.connect(func() -> void: _set_transform_mode("rotate"))
			context_bar.add_child(rotate_button)
			_render_info_bar()
			return
		var draw_guide_menu := MenuButton.new()
		draw_guide_menu.text = "⌘1  Draw Guide Point  ▼"
		draw_guide_menu.custom_minimum_size = Vector2(204, 32)
		draw_guide_menu.focus_mode = Control.FOCUS_NONE
		EditorWidgets.style_context_command_button(draw_guide_menu, _context_command_is("guide.draw_point"))
		for point_mode_index in range(5):
			draw_guide_menu.get_popup().add_item(["1: Linear", "2: Aligned", "3: Free", "4: Mirrored", "5: Corner"][point_mode_index], point_mode_index)
		EditorWidgets.style_popup_menu(draw_guide_menu.get_popup())
		draw_guide_menu.get_popup().id_pressed.connect(_on_guide_draw_menu_id)
		context_bar.add_child(draw_guide_menu)
		var edit_guide_menu := MenuButton.new()
		edit_guide_menu.text = "⌘2  Edit Guide Point  ▼"
		edit_guide_menu.custom_minimum_size = Vector2(194, 32)
		edit_guide_menu.focus_mode = Control.FOCUS_NONE
		EditorWidgets.style_context_command_button(edit_guide_menu, _context_command_is("guide.edit_point"))
		edit_guide_menu.get_popup().add_item("1: Select", 0)
		edit_guide_menu.get_popup().add_item("2: Bezier Handle", 1)
		edit_guide_menu.get_popup().add_item("3: Add Point", 2)
		EditorWidgets.style_popup_menu(edit_guide_menu.get_popup())
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
		EditorWidgets.style_context_command_button(transform_reference_button, _context_command_is("asset.transform"))
		transform_reference_button.pressed.connect(_activate_transform_state)
		context_bar.add_child(transform_reference_button)
		_add_context_measure_menu()
		_render_info_bar()
		return
	if WorldDocumentService.is_primitive(primitive_component):
		# A Primitive is specified rather than drawn, so this bar shares nothing
		# with the Bezier one below it: no Point, Edge or Face command applies.
		var already_shaped: bool = not primitive_component.get("primitive", {}).is_empty()
		var create_primitive_menu := MenuButton.new()
		create_primitive_menu.text = "⌘1  Create Primitive  ▼"
		create_primitive_menu.custom_minimum_size = Vector2(198, 32)
		create_primitive_menu.focus_mode = Control.FOCUS_NONE
		EditorWidgets.style_context_command_button(create_primitive_menu, _context_command_is("asset.create_primitive"))
		for shape_index in range(PrimitiveGeometryService.CREATABLE_SHAPES.size()):
			var creatable_shape: String = PrimitiveGeometryService.CREATABLE_SHAPES[shape_index]
			create_primitive_menu.get_popup().add_item("%d: %s" % [shape_index + 1, PrimitiveGeometryService.display_name(creatable_shape)], shape_index)
		EditorWidgets.style_popup_menu(create_primitive_menu.get_popup())
		create_primitive_menu.get_popup().id_pressed.connect(_on_create_primitive_menu_id)
		create_primitive_menu.disabled = already_shaped
		if already_shaped:
			create_primitive_menu.tooltip_text = "Disabled: this Primitive Component already owns a shape. Edit it in the Inspector."
		context_bar.add_child(create_primitive_menu)
		var transform_primitive_menu := MenuButton.new()
		transform_primitive_menu.text = "⌘2  Transform  ▼"
		transform_primitive_menu.custom_minimum_size = Vector2(150, 32)
		transform_primitive_menu.focus_mode = Control.FOCUS_NONE
		EditorWidgets.style_context_command_button(transform_primitive_menu, _context_command_is("asset.transform"))
		transform_primitive_menu.get_popup().add_item("1: Translate", 0)
		transform_primitive_menu.get_popup().add_item("2: Rotate", 1)
		transform_primitive_menu.get_popup().add_item("3: Scale", 2)
		EditorWidgets.style_popup_menu(transform_primitive_menu.get_popup())
		transform_primitive_menu.get_popup().id_pressed.connect(_on_transform_menu_id)
		context_bar.add_child(transform_primitive_menu)
		_add_context_measure_menu()
		_render_info_bar()
		return
	var draw_menu := MenuButton.new()
	draw_menu.text = "⌘1  Draw Point  ▼"
	draw_menu.custom_minimum_size = Vector2(156, 32)
	draw_menu.focus_mode = Control.FOCUS_NONE
	EditorWidgets.style_context_command_button(draw_menu, _context_command_is("asset.draw_point"))
	draw_menu.get_popup().add_item("1: Linear", 0)
	draw_menu.get_popup().add_item("2: Aligned", 1)
	draw_menu.get_popup().add_item("3: Free", 2)
	draw_menu.get_popup().add_item("4: Mirrored", 3)
	draw_menu.get_popup().add_item("5: Corner", 4)
	EditorWidgets.style_popup_menu(draw_menu.get_popup())
	draw_menu.get_popup().id_pressed.connect(_on_draw_menu_id)
	var geometry_locked := _region_uses_component_geometry(primitive_component)
	draw_menu.disabled = geometry_locked
	if geometry_locked:
		draw_menu.tooltip_text = "Disabled: this Region permanently uses its Component Geometry."
	context_bar.add_child(draw_menu)
	var edit_point_menu := MenuButton.new()
	edit_point_menu.text = "⌘2  Edit Point  ▼"
	edit_point_menu.custom_minimum_size = Vector2(138, 32)
	edit_point_menu.focus_mode = Control.FOCUS_NONE
	EditorWidgets.style_context_command_button(edit_point_menu, _context_command_is("asset.edit_point") or _context_command_is("asset.fuse_point"))
	edit_point_menu.get_popup().add_item("1: Select", 0)
	edit_point_menu.get_popup().add_item("2: Bezier Handle", 1)
	edit_point_menu.get_popup().add_item("3: Add Point", 2)
	edit_point_menu.get_popup().add_item("4: Fuse Point", 3)
	EditorWidgets.style_popup_menu(edit_point_menu.get_popup())
	edit_point_menu.get_popup().id_pressed.connect(_on_edit_menu_id)
	edit_point_menu.disabled = geometry_locked
	if geometry_locked:
		edit_point_menu.tooltip_text = draw_menu.tooltip_text
	context_bar.add_child(edit_point_menu)
	var edit_edge_menu := MenuButton.new()
	edit_edge_menu.text = "⌘3  Edit Edge  ▼"
	edit_edge_menu.custom_minimum_size = Vector2(136, 32)
	edit_edge_menu.focus_mode = Control.FOCUS_NONE
	EditorWidgets.style_context_command_button(edit_edge_menu, _context_command_is("asset.edit_edge"))
	edit_edge_menu.get_popup().add_item("Select Edge", 0)
	EditorWidgets.style_popup_menu(edit_edge_menu.get_popup())
	edit_edge_menu.get_popup().id_pressed.connect(_on_edit_edge_menu_id)
	edit_edge_menu.disabled = geometry_locked
	if geometry_locked:
		edit_edge_menu.tooltip_text = draw_menu.tooltip_text
	context_bar.add_child(edit_edge_menu)
	var selected_component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var closed_loop_component := WorldDocumentService.is_closed_loop(selected_component)
	if closed_loop_component:
		var edit_face_menu := MenuButton.new()
		edit_face_menu.text = "⌘4  Edit Face  ▼"
		edit_face_menu.custom_minimum_size = Vector2(134, 32)
		edit_face_menu.focus_mode = Control.FOCUS_NONE
		EditorWidgets.style_context_command_button(edit_face_menu, _context_command_is("asset.edit_face"))
		edit_face_menu.get_popup().add_item("Move Face", 0)
		EditorWidgets.style_popup_menu(edit_face_menu.get_popup())
		edit_face_menu.get_popup().id_pressed.connect(_on_edit_face_menu_id)
		edit_face_menu.disabled = geometry_locked
		if geometry_locked:
			edit_face_menu.tooltip_text = draw_menu.tooltip_text
		context_bar.add_child(edit_face_menu)
	_add_context_measure_menu()
	if closed_loop_component:
		var mirror_menu := MenuButton.new()
		mirror_menu.text = "Mirror  ▼"
		mirror_menu.custom_minimum_size = Vector2(100, 32)
		mirror_menu.tooltip_text = "Mirror a contiguous selection from the open source Chain across a placed vertical or horizontal axis"
		mirror_menu.focus_mode = Control.FOCUS_NONE
		EditorWidgets.style_context_command_button(mirror_menu, _context_command_is("asset.mirror"))
		mirror_menu.get_popup().add_item("Mirror Y", 0)
		mirror_menu.get_popup().add_item("Mirror X", 1)
		EditorWidgets.style_popup_menu(mirror_menu.get_popup())
		mirror_menu.get_popup().id_pressed.connect(_on_mirror_menu_id)
		mirror_menu.disabled = geometry_locked or not _can_activate_selection_mirror(selected_component)
		if geometry_locked:
			mirror_menu.tooltip_text = draw_menu.tooltip_text
		context_bar.add_child(mirror_menu)
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
	EditorWidgets.style_context_command_button(draw_button, motion_path_tool == "draw")
	draw_button.disabled = path_document.is_empty()
	draw_button.pressed.connect(_set_motion_path_tool.bind("draw"))
	context_bar.add_child(draw_button)
	var edit_button := Button.new()
	edit_button.text = "Edit Path"
	EditorWidgets.style_context_command_button(edit_button, motion_path_tool == "edit")
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
	_invalidate_render(RENDER_CONTEXT_BAR | RENDER_INFO_BAR)


func _toggle_motion_path_playback() -> void:
	var path_document := _get_motion_path(selected_motion_path_id)
	if not _motion_path_is_previewable(path_document):
		return
	if not motion_path_playing and motion_path_phase >= 1.0:
		motion_path_phase = 0.0
	motion_path_playing = not motion_path_playing
	_invalidate_render(RENDER_CONTEXT_BAR | RENDER_INFO_BAR)
	_refresh_motion_path_workspace()


func _on_motion_path_phase_changed(value: float) -> void:
	motion_path_phase = clampf(value, 0.0, 1.0)
	_refresh_motion_path_workspace()
	_invalidate_render(RENDER_INFO_BAR)


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
			_invalidate_render(RENDER_CONTEXT_BAR)
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
	_invalidate_render(RENDER_CONTEXT_BAR)
	_refresh_motion_act_workspace()


func _on_motion_act_phase_changed(value: float) -> void:
	motion_act_phase = clampf(value, 0.0, 1.0)
	_refresh_motion_act_workspace()
	_invalidate_render(RENDER_INFO_BAR)


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
			_invalidate_render(RENDER_CONTEXT_BAR)
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
		_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR | RENDER_CONTEXT_BAR)
		_refresh_geometry_sampling_workspace()
		return
	_record_direct_change()
	var document := _mutable_geometry_document(selected_asset_id, selected_component_id)
	var recipe := GeometrySamplingService.normalize_recipe(document.get("sampling", {}).get("recipe", {}))
	recipe["method"] = method
	var matching_bake := _geometry_sampling_bake(selected_asset_id, selected_component_id, method)
	if not matching_bake.is_empty():
		recipe["parameters"] = matching_bake.get("parameters", {}).duplicate(true)
	document["sampling"]["recipe"] = recipe
	_clear_geometry_sampling_preview_for_selection()
	_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR | RENDER_CONTEXT_BAR)
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
	EditorWidgets.style_context_command_button(geometry_seeding_method_menu, _context_command_is("geometry.seeding.method"))
	var popup := geometry_seeding_method_menu.get_popup()
	EditorWidgets.style_popup_menu(popup)
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
	EditorWidgets.style_context_command_button(edit_button, _context_command_is("geometry.seeding.edit_seeds"))
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
		_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR | RENDER_CONTEXT_BAR)
		_refresh_geometry_seeding_workspace()
		if _geometry_seeding_status(selected_asset_id, selected_component_id, _get_component(_get_asset(selected_asset_id), selected_component_id)) == "Ready to Preview":
			_schedule_geometry_seeding_preview()
		return
	_record_direct_change()
	var document := _mutable_geometry_document(selected_asset_id, selected_component_id)
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
	_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR | RENDER_CONTEXT_BAR)
	_refresh_geometry_seeding_workspace()
	if matching_bake.is_empty() or not _geometry_seeding_result_matches(matching_bake, selected_asset_id, selected_component_id, _get_component(_get_asset(selected_asset_id), selected_component_id)):
		call_deferred("_schedule_geometry_seeding_preview")


func _activate_geometry_seeding_method_choice() -> void:
	if selected_asset_id.is_empty() or selected_component_id.is_empty():
		return
	_set_geometry_command_state("seeding_method")
	_invalidate_render(RENDER_CONTEXT_BAR | RENDER_INFO_BAR)
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
	_invalidate_render(RENDER_CONTEXT_BAR)
	_refresh_geometry_seeding_workspace()
	if geometry_seeding_edit_active and is_instance_valid(geometry_seeding_workspace) and geometry_seeding_workspace.is_inside_tree():
		geometry_seeding_workspace.grab_focus()


func _set_geometry_seeding_edit_tool(tool: String) -> void:
	if tool not in ["select", "add", "remove"]:
		return
	geometry_seeding_edit_tool = tool
	_invalidate_render(RENDER_CONTEXT_BAR)
	_refresh_geometry_seeding_workspace()


func _render_geometry_meshing_context_bar() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if WorldDocumentService.is_contour(component):
		var contour_label := Label.new()
		contour_label.text = "Contour Stroke · Automatic"
		contour_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		contour_label.add_theme_color_override("font_color", Color("#9aa3b2"))
		context_bar.add_child(contour_label)
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
		_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR | RENDER_CONTEXT_BAR)
		_refresh_geometry_meshing_workspace()
		if _geometry_meshing_status(selected_asset_id, selected_component_id, _get_component(_get_asset(selected_asset_id), selected_component_id)) == "Ready to Preview":
			_schedule_geometry_meshing_preview()
		return
	_record_direct_change()
	var document := _mutable_geometry_document(selected_asset_id, selected_component_id)
	var next_recipe := GeometryMeshingService.normalize_recipe({"method": GeometryMeshingService.CONSTRAINED_MESH, "parameters": current.get("parameters", {})})
	var matching_bake := _geometry_meshing_bake(selected_asset_id, selected_component_id, GeometryMeshingService.CONSTRAINED_MESH)
	if not matching_bake.is_empty():
		next_recipe["parameters"] = matching_bake.get("parameters", {}).duplicate(true)
	document["meshing"]["recipe"] = next_recipe
	geometry_meshing_preview = {}
	geometry_meshing_preview_key = ""
	geometry_meshing_preview_state = "idle"
	geometry_meshing_preview_revision += 1
	_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR | RENDER_CONTEXT_BAR)
	_refresh_geometry_meshing_workspace()
	if matching_bake.is_empty() or not _geometry_meshing_result_matches(matching_bake, selected_asset_id, selected_component_id, _get_component(_get_asset(selected_asset_id), selected_component_id)):
		call_deferred("_schedule_geometry_meshing_preview")


func _activate_geometry_meshing_method_choice() -> void:
	_set_geometry_meshing_method(GeometryMeshingService.CONSTRAINED_MESH)


func _render_motion_sequence_context_bar() -> void:
	var composition_button := Button.new()
	composition_button.text = "⌘1  Composition"
	EditorWidgets.style_context_command_button(composition_button, motion_sequence_view == MotionSequenceWorkspace.VIEW_COMPOSITION)
	composition_button.pressed.connect(_set_motion_sequence_view.bind(MotionSequenceWorkspace.VIEW_COMPOSITION))
	context_bar.add_child(composition_button)
	var player_button := Button.new()
	player_button.text = "⌘2  Player"
	EditorWidgets.style_context_command_button(player_button, motion_sequence_view == MotionSequenceWorkspace.VIEW_PLAYER)
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
	_invalidate_render(RENDER_INSPECTOR | RENDER_CONTEXT_BAR | RENDER_INFO_BAR)
	_refresh_motion_sequence_workspace()


func _toggle_motion_sequence_playback() -> void:
	var entry := _resolved_motion_sequence_entry(_get_motion_sequence(selected_motion_sequence_id))
	if not _motion_sequence_is_previewable(entry):
		return
	if not motion_sequence_playing and motion_sequence_phase >= 1.0:
		motion_sequence_phase = 0.0
	motion_sequence_playing = not motion_sequence_playing
	_invalidate_render(RENDER_CONTEXT_BAR | RENDER_INFO_BAR)
	_refresh_motion_sequence_workspace()


func _on_motion_sequence_phase_changed(value: float) -> void:
	motion_sequence_phase = clampf(value, 0.0, 1.0)
	_refresh_motion_sequence_workspace()
	_invalidate_render(RENDER_INFO_BAR)


func _on_motion_sequence_preview_loop_changed(enabled: bool) -> void:
	motion_sequence_preview_loop = enabled


func _advance_motion_sequence_preview(delta: float) -> void:
	var entry := _resolved_motion_sequence_entry(_get_motion_sequence(selected_motion_sequence_id))
	var context := _motion_sequence_entry_context(entry)
	if not MotionSequenceEvaluator.validation_issues(entry, context.get("asset", {}), context.get("path", {})).is_empty():
		motion_sequence_playing = false
		_invalidate_render(RENDER_CONTEXT_BAR)
		return
	var duration := maxf(0.01, float(context.get("path", {}).get("playback", {}).get("duration", 2.0)))
	motion_sequence_phase += delta / duration
	if motion_sequence_phase >= 1.0:
		if motion_sequence_preview_loop:
			motion_sequence_phase = fmod(motion_sequence_phase, 1.0)
		else:
			motion_sequence_phase = 1.0
			motion_sequence_playing = false
			_invalidate_render(RENDER_CONTEXT_BAR)
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
	EditorWidgets.style_context_command_button(weighting_method_menu, _context_command_is("style.weighting.method"))
	var popup := weighting_method_menu.get_popup()
	popup.add_item("1  Uniform", 0)
	popup.set_item_metadata(0, WeightingService.UNIFORM)
	popup.add_item("2  Axis Gradient", 1)
	popup.set_item_metadata(1, WeightingService.AXIS_GRADIENT)
	EditorWidgets.style_popup_menu(popup)
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
	_invalidate_render(RENDER_CANVAS_CONTEXT | RENDER_CONTEXT_BAR)


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
	elif id == 3:
		_activate_fuse_point_state()


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
	if id < 0 or id >= TRANSFORM_MODES.size():
		return
	_activate_transform_state()
	_set_transform_mode(TRANSFORM_MODES[id])


func _on_create_primitive_menu_id(id: int) -> void:
	if id < 0 or id >= PrimitiveGeometryService.CREATABLE_SHAPES.size():
		return
	if not _context_command_is("asset.create_primitive"):
		_activate_primitive_create_command()
	_set_primitive_create_shape(PrimitiveGeometryService.CREATABLE_SHAPES[id])


## Create Primitive draws nothing by itself: it claims the Canvas and waits for
## a shape, and the preview appears with the shape rather than with the command.
func _activate_primitive_create_command() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not WorldDocumentService.is_primitive(component):
		return
	if not component.get("primitive", {}).is_empty():
		_show_status_message("This Primitive Component already owns a shape. Edit it in the Inspector.")
		return
	if not _selected_geometry_is_editable():
		_show_status_message("Creating is disabled while the Region uses Component Geometry.")
		return
	_stop_primitive_create_command()
	active_state = "draw"
	active_draw_tool = "primitive"
	canvas_view.set_interaction_state("draw")
	canvas_view.set_tool_mode("primitive")
	_set_active_context_command("asset.create_primitive")
	_invalidate_render(RENDER_CONTEXT_BAR | RENDER_INFO_BAR | RENDER_CANVAS_CONTEXT)


func _set_primitive_create_shape(shape: String) -> void:
	if not _context_command_is("asset.create_primitive") or not shape in PrimitiveGeometryService.CREATABLE_SHAPES:
		return
	primitive_create_shape = shape
	canvas_view.start_primitive_preview(shape)
	_invalidate_render(RENDER_CONTEXT_BAR | RENDER_INFO_BAR | RENDER_CANVAS_CONTEXT)


func _activate_draw_state() -> void:
	if not _selected_geometry_is_editable():
		_show_status_message("Drawing is disabled while the Region uses Component Geometry.")
		return
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
	_invalidate_render(RENDER_CONTEXT_BAR | RENDER_INFO_BAR)


func _set_edit_mode(mode: String) -> void:
	if not _selected_geometry_is_editable():
		return
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
	_invalidate_render(RENDER_CONTEXT_BAR | RENDER_INFO_BAR)


func _activate_edit_state() -> void:
	_activate_edit_point_state()


func _activate_guide_draw_state() -> void:
	var asset := _get_asset(selected_asset_id)
	var guide := _get_guide(asset, selected_guide_id)
	var component := _get_component(asset, AssetGuide.scope_component_id(guide))
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
	_invalidate_render(RENDER_CANVAS_CONTEXT | RENDER_CONTEXT_BAR | RENDER_INFO_BAR)
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
	_invalidate_render(RENDER_CANVAS_CONTEXT | RENDER_CONTEXT_BAR | RENDER_INFO_BAR)


func _activate_edit_point_state(handle_editing := false, set_mode := false) -> void:
	if not _selected_geometry_is_editable():
		_show_status_message("Editing is disabled while the Region uses Component Geometry.")
		return
	_set_active_context_command("asset.edit_point")
	edit_bezier_handles = handle_editing
	edit_point_set_mode = set_mode
	_set_active_state("edit")
	_set_edit_mode("point")
	canvas_view.set_edit_handles_enabled(edit_bezier_handles)
	canvas_view.set_edit_point_set_enabled(edit_point_set_mode)


func _activate_fuse_point_state() -> void:
	_activate_edit_point_state(false, false)
	_set_active_context_command("asset.fuse_point")
	if selected_point_ids.size() == 1:
		_fuse_selected_point(selected_point_ids[0])
	else:
		_show_status_message("Fuse Point · Select a Point to fuse with a nearby Point")
	_invalidate_render(RENDER_CONTEXT_BAR)


func _fuse_selected_point(point_id: String) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		return
	var preview := component.duplicate(true)
	var preview_result := BezierTopology.fuse_point(preview, point_id)
	if not bool(preview_result.get("fused", false)):
		_show_status_message("Fuse Point · %s" % str(preview_result.get("reason", "No nearby Point found")))
		return
	_record_direct_change()
	var result := BezierTopology.fuse_point(component, point_id)
	if not bool(result.get("fused", false)):
		return
	var kept_id := str(result.get("kept_point_id", point_id))
	selected_point_id = kept_id
	selected_point_ids = [kept_id]
	_refresh_component_geometry(component)
	canvas_view.set_selected_point_id(kept_id)
	_invalidate_render(RENDER_INSPECTOR)
	_show_status_message("Fuse Point · Nearby Point fused")


func _activate_edit_edge_state() -> void:
	if not _selected_geometry_is_editable():
		return
	_set_active_context_command("asset.edit_edge")
	_set_active_state("edit")
	_set_edit_mode("edge")


func _activate_edit_face_state() -> void:
	if not _selected_geometry_is_editable():
		return
	_set_active_context_command("asset.edit_face")
	_set_active_state("edit")
	_set_edit_mode("face")


func _can_activate_selection_mirror(component: Dictionary) -> bool:
	if component.is_empty() or _region_uses_component_geometry(component) or not WorldDocumentService.is_closed_loop(component):
		return false
	return SELECTION_MIRROR_SERVICE_SCRIPT.selection_issues(component, selected_point_ids).is_empty()


## Measure changes no geometry, so it belongs in every Create context bar - the
## Primitive and Asset Reference branches return before the Bezier one is built,
## which is the only reason they went without it.
func _add_context_measure_menu() -> void:
	var context_command_spacer := Control.new()
	context_command_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context_bar.add_child(context_command_spacer)
	var measure_menu := MenuButton.new()
	measure_menu.text = "Measure  ▼"
	measure_menu.custom_minimum_size = Vector2(112, 32)
	measure_menu.tooltip_text = "Measure distances on the Canvas · Ruler guides are transient and never change geometry"
	measure_menu.focus_mode = Control.FOCUS_NONE
	# The highlight reports that a Measure tool is on, not that Measure currently
	# owns the Canvas, because the Ruler keeps running underneath other commands.
	var ruler_enabled := is_instance_valid(canvas_view) and canvas_view.is_measure_ruler_enabled()
	EditorWidgets.style_context_command_button(measure_menu, ruler_enabled)
	measure_menu.get_popup().add_check_item("Ruler", 0)
	measure_menu.get_popup().set_item_checked(0, ruler_enabled)
	EditorWidgets.style_popup_menu(measure_menu.get_popup())
	measure_menu.get_popup().id_pressed.connect(_on_measure_menu_id)
	context_bar.add_child(measure_menu)


func _on_measure_menu_id(action_id: int) -> void:
	if action_id == 0:
		_toggle_measure_ruler()


## Picking Ruler while it already owns the Canvas switches it off and clears
## every guide. Picking it from anywhere else resumes placing with the guides
## intact, which is what makes measure · edit · measure again possible.
func _toggle_measure_ruler() -> void:
	if canvas_view.is_measure_ruler_enabled() and _context_command_is("asset.measure"):
		canvas_view.disable_measure_ruler()
		_set_active_context_command("asset.edit_point")
		_invalidate_render(RENDER_CONTEXT_BAR)
		_show_status_message("Ruler off · Measure guides cleared")
		return
	canvas_view.enable_measure_ruler()
	_set_active_context_command("asset.measure")
	_invalidate_render(RENDER_CONTEXT_BAR)


func _on_measure_stage_changed(stage: String) -> void:
	if stage == "second":
		_show_command_prompt("Ruler · Set the second measure Point · Escape takes the last Point back")
	elif stage == "first":
		_show_command_prompt("Ruler · Set the first measure Point · Escape takes the last Point back · Pick Ruler again to switch it off")


func _on_mirror_menu_id(action_id: int) -> void:
	_activate_selection_mirror(ComponentCanvas.MIRROR_AXIS_HORIZONTAL if action_id == 1 else ComponentCanvas.MIRROR_AXIS_VERTICAL)


func _mirror_command_label() -> String:
	return "Mirror X" if active_mirror_axis_orientation == ComponentCanvas.MIRROR_AXIS_HORIZONTAL else "Mirror Y"


func _activate_selection_mirror(axis_orientation := ComponentCanvas.MIRROR_AXIS_VERTICAL) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not _can_activate_selection_mirror(component):
		return
	active_mirror_axis_orientation = axis_orientation
	_set_active_context_command("asset.mirror")
	if not canvas_view.start_mirror_command(axis_orientation):
		_set_active_context_command("asset.edit_point")
		return
	_invalidate_render(RENDER_CONTEXT_BAR)
	_show_command_prompt(_mirror_axis_prompt())


func _mirror_axis_prompt() -> String:
	var axis_name := "horizontal" if active_mirror_axis_orientation == ComponentCanvas.MIRROR_AXIS_HORIZONTAL else "vertical"
	return "%s · Place the %s axis on the snapped grid · Click or Enter to confirm · Escape to cancel" % [_mirror_command_label(), axis_name]


func _on_mirror_axis_stage_changed(stage: String) -> void:
	if stage == "axis":
		_show_command_prompt(_mirror_axis_prompt())


func _on_mirror_axis_confirmed(axis_start: Vector2, axis_end: Vector2) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		_on_mirror_axis_cancelled()
		return
	var result: Dictionary = SELECTION_MIRROR_SERVICE_SCRIPT.apply(component, selected_point_ids, axis_start, axis_end)
	if not bool(result.get("valid", false)):
		var errors: Array = result.get("errors", [])
		_show_status_message(str(errors[0]) if not errors.is_empty() else "%s could not be applied." % _mirror_command_label())
		_set_active_context_command("asset.edit_point")
		_invalidate_render(RENDER_CONTEXT_BAR)
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
	_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR | RENDER_CONTEXT_BAR)
	var auto_connected_count := int(result.get("auto_connected_count", 0))
	if auto_connected_count > 0:
		_show_status_message("%s applied · Overlapping endpoints connected" % _mirror_command_label())
	else:
		_show_status_message("%s applied · The two open Chains remain unconnected" % _mirror_command_label())


func _on_mirror_axis_cancelled() -> void:
	_set_active_context_command("asset.edit_point")
	_invalidate_render(RENDER_CONTEXT_BAR)
	_show_status_message("%s cancelled" % _mirror_command_label())


func _show_command_prompt(message: String) -> void:
	_show_status_message(message)
	if is_instance_valid(status_clear_timer):
		status_clear_timer.stop()


func _activate_transform_state() -> void:
	if selected_component_id.is_empty():
		return
	_set_active_context_command("asset.transform")
	_set_active_state("transform")


func _set_transform_mode(mode: String) -> void:
	active_transform_mode = mode
	canvas_view.set_transform_mode(active_transform_mode)
	_invalidate_render(RENDER_INFO_BAR)


func _set_active_state(state: String) -> void:
	if selected_component_id.is_empty():
		return
	if state in ["draw", "edit"] and not _selected_geometry_is_editable():
		return
	_stop_primitive_create_command()
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
	_invalidate_render(RENDER_CONTEXT_BAR | RENDER_INFO_BAR)


func _render_info_bar() -> void:
	if not is_instance_valid(info_bar):
		return
	EditorWidgets.clear(info_bar)
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
	var info_component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	# A Reference inherits its source Draw Mode, so one can read as a Primitive
	# while owning neither the Create nor the Transform command of its own. The
	# Context Bar asks in this order too.
	if WorldDocumentService.is_primitive(info_component) and not _is_reference_component(info_component):
		_render_primitive_info_bar(info_component)
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
		var active_edit_point_submode := "fuse_point" if active_context_command == "asset.fuse_point" else "set" if edit_point_set_mode else "bezier_handle" if edit_bezier_handles else "select"
		_add_info_mode_group([
			{"label": "1: Select", "id": "select"},
			{"label": "2: Bezier Handle", "id": "bezier_handle"},
			{"label": "3: Set", "id": "set"},
			{"label": "4: Fuse Point", "id": "fuse_point"}
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


## A Primitive is specified, not drawn, so its Info Bar never offers a Bezier
## point mode. It offers the shape to create, or the transform to apply, and it
## says what the next click on the Canvas will do.
func _render_primitive_info_bar(component: Dictionary) -> void:
	var state_label := Label.new()
	if _context_command_is("asset.create_primitive"):
		state_label.text = "State: Create Primitive"
		info_bar.add_child(state_label)
		var shape_modes: Array = []
		for shape_index in range(PrimitiveGeometryService.CREATABLE_SHAPES.size()):
			var creatable_shape: String = PrimitiveGeometryService.CREATABLE_SHAPES[shape_index]
			shape_modes.append({"label": "%d: %s" % [shape_index + 1, PrimitiveGeometryService.display_name(creatable_shape)], "id": creatable_shape})
		_add_info_mode_group(shape_modes, primitive_create_shape)
		if primitive_create_shape.is_empty():
			_add_info_option("Choose a shape · Esc: Leave")
		elif primitive_create_stage == ComponentCanvas.PRIMITIVE_STAGE_SIZE:
			_add_info_option("Move: Size · Click: Confirm · Esc: Set Center again")
		else:
			_add_info_option("Click: Set Center · Esc: Leave")
		return
	if _context_command_is("asset.transform"):
		state_label.text = "State: Transform"
		info_bar.add_child(state_label)
		_add_info_mode_group([
			{"label": "1: Translate", "id": "transform"},
			{"label": "2: Rotate", "id": "rotate"},
			{"label": "3: Scale", "id": "scale"}
		], active_transform_mode)
		_add_info_option("Drag: Gizmo · Esc: Leave")
		return
	state_label.text = "State: Default"
	info_bar.add_child(state_label)
	var shape := PrimitiveGeometryService.shape_type(component)
	_add_info_option("Primitive: %s" % (PrimitiveGeometryService.display_name(shape) if not shape.is_empty() else "None"))
	_add_info_mode_group([
		{"label": "⌘1: Create Primitive", "id": "asset.create_primitive"},
		{"label": "⌘2: Transform", "id": "asset.transform"}
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


func _open_new_asset_dialog(composition_owner_id := "") -> void:
	# One dialog, three intents: a standalone Asset, a Set member, or a Palette
	# variant. The owner says which, because its own type does.
	asset_name_input.text = ""
	asset_dialog.dialog_text = "Enter an asset name"
	asset_dialog.set_meta("composition_owner_id", composition_owner_id)
	asset_dialog.title = _new_asset_dialog_title(composition_owner_id)
	if is_instance_valid(asset_type_input):
		asset_type_input.visible = _new_asset_dialog_offers_a_type(composition_owner_id)
	# Only a Set has roles to fill; a Palette variant and a standalone Asset are
	# not members of anything.
	asset_role_edited = false
	if is_instance_valid(asset_role_input):
		asset_role_input.text = ""
		asset_role_input.visible = WorldDocumentService.is_set_asset(_get_asset(composition_owner_id))
	_sync_new_asset_type_input()
	asset_dialog.popup_centered()
	asset_name_input.grab_focus()


func _new_asset_dialog_title(composition_owner_id: String) -> String:
	var owner := _get_asset(composition_owner_id)
	if WorldDocumentService.is_palette_asset(owner):
		return "New Variant Asset"
	if WorldDocumentService.is_set_asset(owner):
		return "New Member Asset"
	if active_create_submodule in ["Set", "Palette"]:
		return "New %s" % active_create_submodule
	return "New Asset"


func _new_asset_dialog_offers_a_type(composition_owner_id: String) -> bool:
	# A composition declares the type once, where it is named; its members and
	# variants are never asked again.
	return not WorldDocumentService.is_composition_asset(_get_asset(composition_owner_id))


func _new_asset_type(composition_owner_id: String) -> String:
	# A composition and everything it owns are one kind of thing: a Bridge is
	# props, and so are its posts and planks; a Grass Palette is terrain, and so
	# is each blade. Only a standalone Asset is asked.
	var owner := _get_asset(composition_owner_id)
	if WorldDocumentService.is_composition_asset(owner):
		return WorldDocumentService.asset_type(owner)
	return WorldDocumentService.normalize_asset_type(new_asset_type)


func _new_asset_category(composition_owner_id: String) -> String:
	# The module fixes the composition. A member or a variant stands on its own
	# whatever module it was authored from.
	if not composition_owner_id.is_empty():
		return WorldDocumentService.ASSET_CATEGORY_SINGLE
	return str(ASSET_CATEGORY_BY_CREATE_SUBMODULE.get(active_create_submodule, WorldDocumentService.ASSET_CATEGORY_SINGLE))


func _sync_new_asset_type_input() -> void:
	if not is_instance_valid(asset_type_input):
		return
	for index in range(asset_type_input.item_count):
		if str(asset_type_input.get_item_metadata(index)) == new_asset_type:
			asset_type_input.select(index)
			return


func _asset_type_option_items() -> Array:
	var items: Array = []
	for asset_type in WorldDocumentService.ASSET_TYPES:
		items.append({"label": _asset_type_display_name(str(asset_type)), "metadata": str(asset_type)})
	return items


func _asset_type_display_name(asset_type: String) -> String:
	# Every Asset type is a single lower-case word, so capitalize() is exactly
	# "uppercase the first letter": "props" -> "Props".
	return WorldDocumentService.normalize_asset_type(asset_type).capitalize()


func _on_new_asset_type_selected(index: int, option: OptionButton) -> void:
	if index < 0 or index >= option.item_count:
		return
	new_asset_type = WorldDocumentService.normalize_asset_type(option.get_item_metadata(index))


func _on_asset_type_selected(index: int, option: OptionButton) -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty() or index < 0 or index >= option.item_count:
		return
	var asset_type := WorldDocumentService.normalize_asset_type(option.get_item_metadata(index))
	if asset_type == _asset_type(asset):
		return
	_record_direct_change()
	asset["asset_type"] = asset_type
	new_asset_type = asset_type
	# A composition and the Assets it owns are one kind of thing, so the type
	# moves with it rather than leaving the two disagreeing.
	for owned_asset_id in _composition_owned_asset_ids(asset):
		var owned_asset := _get_asset(owned_asset_id)
		if not owned_asset.is_empty():
			owned_asset["asset_type"] = asset_type
	_invalidate_render(RENDER_DOCUMENT)


func _composition_owned_asset_ids(asset: Dictionary) -> Array[String]:
	# The member Assets of a Set, or the variant Assets of a Palette.
	if WorldDocumentService.is_palette_asset(asset):
		return WorldDocumentService.palette_variants(asset)
	var member_ids: Array[String] = []
	if not WorldDocumentService.is_set_asset(asset):
		return member_ids
	for component in asset.get("components", []):
		if component is Dictionary and _is_reference_component(component):
			var member_id := str(component.get("source_asset_id", ""))
			if not member_id.is_empty() and not member_ids.has(member_id):
				member_ids.append(member_id)
	return member_ids


func _on_new_asset_name_typed(new_text: String) -> void:
	if not is_instance_valid(asset_role_input) or not asset_role_input.visible or asset_role_edited:
		return
	asset_role_input.text = AssetCatalogService.asset_key(new_text)


func _on_new_member_role_typed(_new_text: String) -> void:
	asset_role_edited = true


func _submit_asset_name(_submitted_text: String) -> void:
	_confirm_asset_creation()


func _submit_asset_rename(_submitted_text: String) -> void:
	asset_rename_dialog.hide()
	_confirm_asset_rename()


func _on_asset_rename_dialog_requested() -> void:
	_open_rename_asset_dialog(selected_asset_id)


func _on_set_member_rename_dialog_requested() -> void:
	_open_rename_asset_dialog(str(_selected_set_member_asset().get("id", "")))


func _on_reference_role_requested(new_role: String) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or not _is_reference_component(component):
		return
	var role := WorldDocumentService.normalized_reference_role(new_role)
	if role == WorldDocumentService.reference_role(component):
		return
	var role_error := _reference_role_validation_error(role)
	if not role_error.is_empty():
		_show_status_message(role_error)
		_invalidate_render(RENDER_INSPECTOR)
		return
	_record_direct_change()
	component["role"] = role
	_invalidate_render(RENDER_DOCUMENT)


func _reference_role_validation_error(raw_role: String) -> String:
	# Emptying a Role is allowed while authoring — Runtime Export is where a Set
	# without one is refused, so the editor does not force the answer before the
	# member exists.
	var role := raw_role.strip_edges()
	if role.is_empty():
		return ""
	if role.begins_with("_") or role.ends_with("_") or role.contains("__"):
		return "Use lower_snake_case for the Role, e.g. post."
	for character in role:
		var code := character.unicode_at(0)
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			return "Use lower_snake_case for the Role, e.g. post."
	if role.unicode_at(0) >= 48 and role.unicode_at(0) <= 57:
		return "A Role must start with a lowercase letter."
	return ""


func _selected_set_member_asset() -> Dictionary:
	# The Asset behind the selected member Reference. A member row names its
	# Asset, so the Inspector reached from it renames that Asset rather than the
	# Reference that carries it.
	var asset := _get_asset(selected_asset_id)
	if not WorldDocumentService.is_set_asset(asset):
		return {}
	var component := _get_component(asset, selected_component_id)
	if component.is_empty() or not _is_reference_component(component):
		return {}
	return _get_asset(str(component.get("source_asset_id", "")))


func _open_rename_asset_dialog(asset_id: String) -> void:
	var asset := _get_asset(asset_id)
	if asset.is_empty():
		return
	asset_rename_dialog.set_meta("asset_id", asset_id)
	asset_rename_dialog.title = "Rename %s" % str(asset.get("name", "Asset"))
	asset_rename_dialog.dialog_text = "The new name moves the Asset's files and changes the Asset Key the Catalog publishes."
	asset_rename_input.text = str(asset.get("name", ""))
	_update_asset_rename_preview(asset_rename_input.text)
	# The suite and the render probe build the shell without a scene tree, where
	# a Window cannot be shown; the dialog is then prepared and confirmed
	# directly, which is what those tests drive.
	if not is_inside_tree():
		return
	asset_rename_dialog.popup_centered()
	asset_rename_input.grab_focus()
	asset_rename_input.select_all()


func _update_asset_rename_preview(proposed_name: String) -> void:
	var key := AssetCatalogService.asset_key(proposed_name.strip_edges())
	asset_rename_key_label.text = "Asset Key: %s" % (key if not key.is_empty() else "—")


func _confirm_asset_rename() -> void:
	var asset_id := str(asset_rename_dialog.get_meta("asset_id", ""))
	var asset := _get_asset(asset_id)
	var asset_name := asset_rename_input.text.strip_edges()
	if asset.is_empty() or asset_name.is_empty() or asset_name == str(asset.get("name", "")):
		return
	var validation_error := _asset_name_validation_error(asset_name, asset_id)
	if not validation_error.is_empty():
		_show_status_message(validation_error)
		return
	# The files move first: a name that has changed while its directory has not
	# would leave the Reference Image and every Geometry document unreachable.
	var storage_error := _rename_asset_storage(asset, asset_name)
	if not storage_error.is_empty():
		_show_status_message("%s was not renamed: %s." % [str(asset.get("name", "Asset")), storage_error])
		return
	_record_direct_change()
	var previous_name := str(asset.get("name", ""))
	# The Key that is being left behind is kept, so a consumer whose own files
	# name Assets by Key can find its way from the outdated name to this Asset.
	var previous_key := AssetCatalogService.asset_key(previous_name)
	var recorded_keys := WorldDocumentService.previous_asset_keys(asset)
	if not previous_key.is_empty() and previous_key != AssetCatalogService.asset_key(asset_name) and not recorded_keys.has(previous_key):
		recorded_keys.append(previous_key)
	asset["previous_asset_keys"] = recorded_keys
	asset["name"] = asset_name
	_follow_reference_rename(asset_id, previous_name, asset_name)
	# The World is written at once, because the directories have already moved.
	# Leaving it unsaved would let the document say the old name while its
	# directories say the new one. A save that is refused — an invalid Catalog
	# elsewhere in the World will refuse it — says so in its own message, and
	# this one says what that means for the rename.
	if not world_name.is_empty() and not _save_world():
		# The refusal names its own cause, which is the actionable half; this
		# adds what it means here, and keeps the cause rather than replacing it.
		var refusal := str(program_status_label.text) if is_instance_valid(program_status_label) else ""
		_show_status_message("%s is now %s, but %s Save before reloading." % [previous_name, asset_name,
			refusal if not refusal.is_empty() else "the World was not saved."])
	_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


func _rename_asset_storage(asset: Dictionary, new_name: String) -> String:
	# Before the first save there is nothing on disk, and nothing to move.
	if world_name.is_empty():
		return ""
	var world_root := _current_world_root()
	var asset_id := str(asset.get("id", ""))
	var new_directory := _asset_storage_name_for(asset_id, new_name)
	var plan := _asset_storage_move_plan(world_root, _asset_storage_directory(world_root, asset_id), new_directory)
	var blocked := str(plan.get("blocked", ""))
	if not blocked.is_empty():
		return blocked
	var moves: Array = plan.get("moves", [])
	var renamed_reference_file := _append_reference_image_moves(moves,
		"%s/assets/%s" % [world_root, _asset_storage_directory(world_root, asset_id)],
		"%s/assets/%s" % [world_root, new_directory], asset, new_name)
	var move_error := _apply_asset_storage_moves(moves)
	if not move_error.is_empty():
		return move_error
	if not renamed_reference_file.is_empty():
		var stored_reference_image := WorldDocumentService.normalize_reference_image(asset.get("reference_image", {}))
		stored_reference_image["file"] = renamed_reference_file
		asset["reference_image"] = stored_reference_image
	return ""


func _append_reference_image_moves(moves: Array, current_root: String, new_root: String, asset: Dictionary, new_name: String) -> String:
	# The Reference Image is named after the Asset as well, so it follows the
	# rename; a file that carries some other name is the user's and stays. The
	# `.import` sidecar travels with it — PolyTools loads the image from the
	# path itself, but a stale sidecar points at a file that is gone.
	#
	# What exists is asked of the directory the files are in now; where they are
	# moved to is the directory they will be in, because these moves run after
	# the one that renames the directory itself.
	var asset_id := str(asset.get("id", "asset"))
	var reference_file := str(WorldDocumentService.normalize_reference_image(asset.get("reference_image", {})).get("file", ""))
	if reference_file.is_empty() or reference_file != _reference_image_filename_for(str(asset.get("name", "")), asset_id):
		return ""
	var renamed_file := _reference_image_filename_for(new_name, asset_id)
	if renamed_file == reference_file:
		return ""
	if not FileAccess.file_exists(ProjectSettings.globalize_path("%s/%s" % [current_root, reference_file])):
		return ""
	moves.append({"from": "%s/%s" % [new_root, reference_file], "to": "%s/%s" % [new_root, renamed_file]})
	if FileAccess.file_exists(ProjectSettings.globalize_path("%s/%s.import" % [current_root, reference_file])):
		moves.append({"from": "%s/%s.import" % [new_root, reference_file],
			"to": "%s/%s.import" % [new_root, renamed_file]})
	return renamed_file


func _confirm_asset_creation() -> void:
	var asset_name := asset_name_input.text.strip_edges()
	if asset_name.is_empty():
		asset_name = _next_default_asset_name()
	var validation_error := _asset_name_validation_error(asset_name)
	if not validation_error.is_empty():
		asset_dialog.dialog_text = validation_error
		asset_name_input.grab_focus()
		asset_name_input.select_all()
		_show_status_message(validation_error)
		return
	var composition_owner_id := str(asset_dialog.get_meta("composition_owner_id", ""))
	# Single shot: the next Asset is standalone unless the dialog is opened for
	# a composition again.
	asset_dialog.set_meta("composition_owner_id", "")
	var composition_owner := _get_asset(composition_owner_id)
	if not composition_owner_id.is_empty() and not WorldDocumentService.is_composition_asset(composition_owner):
		asset_dialog.hide()
		return
	var created_asset_category := _new_asset_category(composition_owner_id)
	_record_direct_change()
	var asset_id := "asset_%d" % next_asset_id
	next_asset_id += 1
	var created_asset := {"id": asset_id, "name": asset_name, "asset_type": _new_asset_type(composition_owner_id), "asset_category": created_asset_category, "authored_facing": AssetPresentation.AuthoredFacing.NEUTRAL, "visibility": true, "asset_pivot": Vector2.ZERO, "root_position": Vector2.ZERO, "root_scale": Vector2.ONE, "reference_image": WorldDocumentService.default_reference_image(), "animation": MotionWorkspace.create_default_animation_document(), "components": [], "groups": [], "guides": []}
	if created_asset_category == WorldDocumentService.ASSET_CATEGORY_PALETTE:
		created_asset["palette_variants"] = [] as Array[String]
	assets.append(created_asset)
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_component_ids.clear()
	selected_group_id = ""
	selected_guide_id = ""
	active_state = ""
	if WorldDocumentService.is_set_asset(composition_owner):
		# The member exists; the Reference is what puts it into the assembly.
		# Its local name comes from the member's own name, the same derivation
		# the Asset Key uses, so membership is readable without a second one.
		selected_asset_id = composition_owner_id
		selected_component_id = _add_set_member_reference(composition_owner, asset_id,
			WorldDocumentService.normalized_reference_role(asset_role_input.text if is_instance_valid(asset_role_input) else ""))
		_set_outliner_asset_expanded(composition_owner_id, true)
	elif WorldDocumentService.is_palette_asset(composition_owner):
		# A variant is carried by the list alone: no Reference, no transform,
		# no order.
		var variants := WorldDocumentService.palette_variants(composition_owner)
		variants.append(asset_id)
		composition_owner["palette_variants"] = variants
		selected_asset_id = composition_owner_id
		_set_outliner_asset_expanded(composition_owner_id, true)
	else:
		_set_outliner_asset_expanded(asset_id, true)
	asset_dialog.hide()
	_invalidate_render(RENDER_DOCUMENT)


func _on_palette_variant_remove_requested(variant_asset_id: String) -> void:
	var asset := _get_asset(selected_asset_id)
	if not WorldDocumentService.is_palette_asset(asset):
		return
	var variants := WorldDocumentService.palette_variants(asset)
	if not variants.has(variant_asset_id):
		return
	_record_direct_change()
	variants.erase(variant_asset_id)
	asset["palette_variants"] = variants
	_invalidate_render(RENDER_DOCUMENT)


func _palette_variant_rows(asset: Dictionary) -> Array:
	# One row per variant, already labelled: resolving an Asset ID needs every
	# Asset, which the view does not have. A variant that no longer exists stays
	# visible as missing rather than disappearing silently.
	var rows: Array = []
	if not WorldDocumentService.is_palette_asset(asset):
		return rows
	for variant_asset_id in WorldDocumentService.palette_variants(asset):
		var variant := _get_asset(variant_asset_id)
		rows.append({
			"asset_id": variant_asset_id,
			"label": str(variant.get("name", "")) if not variant.is_empty() else "Missing Asset",
			"missing": variant.is_empty(),
		})
	return rows


func _add_set_member_reference(owner_set: Dictionary, member_asset_id: String, member_role: String) -> String:
	var member := _get_asset(member_asset_id)
	var component_id := "component_%d" % next_component_id
	next_component_id += 1
	owner_set["components"].append({
		"id": component_id,
		"type": "reference",
		"role": member_role,
		"name": _unique_component_name(owner_set, AssetCatalogService.asset_key(str(member.get("name", "")))),
		"source_asset_id": member_asset_id,
		"parent_component_id": "",
		"group_id": "",
		"points": [], "edges": [], "chains": [],
		"transform": WorldDocumentService.default_component_transform(),
		"visibility": true,
		"z_index": 0,
		"projection_depth_cm": WorldDocumentService.DEFAULT_PROJECTION_DEPTH_CM,
		"draw_mode": WorldDocumentService.DRAW_MODE_CLOSED_LOOP,
		"topology_role": WorldDocumentService.ROLE_OUTER,
		"geometry_source": "bezier",
		"primitive": {},
		"catch_parent_component_id": "",
		"show_point_numbers": false,
	})
	return component_id


func _unique_component_name(asset: Dictionary, base_name: String, excluded_component_id := "") -> String:
	# The member's own name, made unique where one Asset fills a role twice:
	# rope_post, rope_post_02.
	var candidate := base_name if not base_name.is_empty() else "member"
	if not _has_component_name(asset, candidate, excluded_component_id):
		return candidate
	var index := 2
	while _has_component_name(asset, "%s_%02d" % [candidate, index], excluded_component_id):
		index += 1
	return "%s_%02d" % [candidate, index]


func _is_derived_reference_name(reference_name: String, source_asset_name: String) -> bool:
	# Whether a Reference carries the source Asset's own name rather than a
	# place the user named. `rope_post` and the `rope_post_02` a second
	# Reference to the same Asset gets both count.
	var derived := AssetCatalogService.asset_key(source_asset_name)
	if derived.is_empty():
		return false
	if reference_name == derived:
		return true
	if not reference_name.begins_with("%s_" % derived):
		return false
	var suffix := reference_name.substr(derived.length() + 1)
	return suffix.length() == 2 and suffix.is_valid_int()


func _follow_reference_rename(renamed_asset_id: String, previous_name: String, new_name: String) -> void:
	# A Reference whose name is the source Asset's own name follows a rename of
	# that Asset: leaving it behind would be two names disagreeing about the
	# same thing, and nothing is gained by keeping it, because the Asset Key
	# moved with the name and a consumer has to follow the rename either way.
	# A name that was authored instead answers "which place is this" — Barde's
	# eye_left says nothing about the Symbol it borrows — and is left alone.
	for owner_asset in assets:
		if not owner_asset is Dictionary:
			continue
		for component in owner_asset.get("components", []):
			if not component is Dictionary or not _is_reference_component(component):
				continue
			if str(component.get("source_asset_id", "")) != renamed_asset_id:
				continue
			if not _is_derived_reference_name(WorldDocumentService.normalized_component_name(component), previous_name):
				continue
			component["name"] = _unique_component_name(owner_asset,
				AssetCatalogService.asset_key(new_name), str(component.get("id", "")))


func _open_reference_image_dialog() -> void:
	if _get_asset(selected_asset_id).is_empty():
		return
	if world_name.is_empty():
		_show_status_message("Create or load a World before loading a Reference Image.")
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
	if asset.is_empty() or world_name.is_empty():
		return
	var source_image := Image.new()
	if source_image.load(source_path) != OK or source_image.is_empty():
		_show_status_message("Reference Image could not be loaded.")
		return
	_apply_reference_image_orientation(source_image, source_path)
	reference_image_crop_dialog.open_for_image(source_image)


func _save_reference_image_result(reference_image_result: Image) -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty() or world_name.is_empty() or reference_image_result == null or reference_image_result.is_empty():
		return
	var reference_filename := _reference_image_filename(asset)
	var asset_root := _asset_storage_root("%s/%s" % [WORLDS_ROOT, world_name], asset)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(asset_root))
	var destination_path := "%s/%s" % [asset_root, reference_filename]
	if reference_image_result.save_png(ProjectSettings.globalize_path(destination_path)) != OK:
		_show_status_message("Reference Image could not be copied.")
		return
	var reference_image := WorldDocumentService.normalize_reference_image(asset.get("reference_image", {}))
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
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


func _apply_reference_image_orientation(image: Image, source_path: String) -> void:
	if image == null or image.is_empty() or source_path.get_extension().to_lower() not in ["jpg", "jpeg"]:
		return
	var orientation := _jpeg_exif_orientation(source_path)
	if orientation == 3:
		image.rotate_90(ClockDirection.CLOCKWISE)
		image.rotate_90(ClockDirection.CLOCKWISE)
	elif orientation == 6:
		image.rotate_90(ClockDirection.CLOCKWISE)
	elif orientation == 8:
		image.rotate_90(ClockDirection.COUNTERCLOCKWISE)
	elif orientation == 2:
		image.flip_x()
	elif orientation == 4:
		image.flip_y()
	elif orientation == 5:
		image.flip_x()
		image.rotate_90(ClockDirection.CLOCKWISE)
	elif orientation == 7:
		image.flip_x()
		image.rotate_90(ClockDirection.COUNTERCLOCKWISE)


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
	var reference_image := WorldDocumentService.normalize_reference_image(asset.get("reference_image", {}))
	if str(reference_image.get("file", "")).is_empty():
		return
	_record_direct_change()
	reference_image["file"] = ""
	asset["reference_image"] = reference_image
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


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
	var reference_image := WorldDocumentService.normalize_reference_image(asset.get("reference_image", {}))
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
	elif property_name == "rotation":
		reference_image["rotation"] = WorldDocumentService.normalize_reference_rotation(value)
	elif property_name == "scale":
		reference_image["scale"] = maxf(value, 0.01)
	else:
		return
	_record_direct_change()
	asset["reference_image"] = reference_image
	_invalidate_render(RENDER_CANVAS_CONTEXT)


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
	canvas_view.set_asset_pivot(AssetScaleRebaseService.root_transform(asset) * pivot)


func _on_asset_root_position_changed(value: float, property_name: String) -> void:
	if property_name not in ["position_x", "position_y"]:
		return
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty() or not selected_component_id.is_empty() or not is_finite(value):
		return
	var root_position := AssetScaleRebaseService.root_position(asset)
	var editor_value := _world_to_editor_units(value)
	if property_name == "position_x":
		root_position.x = editor_value
	else:
		root_position.y = editor_value
	if root_position.is_equal_approx(AssetScaleRebaseService.root_position(asset)):
		return
	_record_coalesced_change()
	asset["root_position"] = root_position
	_invalidate_batch_status()
	if is_instance_valid(create_inspector_view.asset_root_scale_rebase_button):
		var analysis := AssetScaleRebaseService.analyze_asset(asset)
		create_inspector_view.asset_root_scale_rebase_button.disabled = not bool(analysis.get("can_rebase", false))
		create_inspector_view.asset_root_scale_rebase_button.tooltip_text = "Bake Root Position and independent X/Y Scale into Components, Groups, References, Guides, and Weapon Frames." if analysis.get("blockers", []).is_empty() else str(analysis.get("blockers", [""])[0])
	_invalidate_render(RENDER_CANVAS_CONTEXT)


func _update_reference_image_property(property_name: String, value) -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty():
		return
	var reference_image := WorldDocumentService.normalize_reference_image(asset.get("reference_image", {}))
	reference_image[property_name] = value
	_record_direct_change()
	asset["reference_image"] = reference_image
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


func _next_default_asset_name() -> String:
	var index := 1
	while not _asset_name_validation_error("asset%02d" % index).is_empty():
		index += 1
	return "asset%02d" % index


func _render_outliner() -> void:
	# Pushes the current context into the view and lets it rebuild. The view
	# owns the rows; this function owns what they are shown from.
	_update_context_action_button()
	_update_outliner_asset_type_filter_visibility()
	if not is_instance_valid(outliner_view):
		return
	outliner_view.set_documents(assets, motion_paths, motion_sequences)
	outliner_view.set_module(active_module, active_create_submodule, active_geometry_submodule, active_motion_submodule)
	outliner_view.set_selection(selected_asset_id, selected_component_id, selected_component_ids, selected_group_id, selected_guide_id, selected_motion_path_id, selected_motion_sequence_id, selected_weighting_style_id, motion_act_preview_asset_id)
	outliner_view.set_filters(outliner_search_input.text.strip_edges().to_lower() if is_instance_valid(outliner_search_input) else "", outliner_asset_type_filters, _composition_owner_by_member_id(), _create_module_asset_category())
	outliner_view.set_expansion(expanded_assets, _outliner_focus_asset_id())
	outliner_view.set_row_status(_outliner_row_status())
	outliner_view.set_geometry_rows(_geometry_outliner_rows())
	outliner_view.rebuild()


func _geometry_outliner_rows() -> Array:
	# The Mesh tree as data. Every derived value the rows show is resolved here,
	# where the geometry documents live, so OutlinerView only has to draw it.
	var rows: Array = []
	if active_module != "Mesh" or not active_geometry_submodule in GEOMETRY_SUBMODULES:
		return rows
	var search_text := outliner_search_input.text.strip_edges().to_lower() if is_instance_valid(outliner_search_input) else ""
	var visible_assets: Array = []
	for asset in assets:
		if outliner_view.asset_is_visible(asset) and outliner_view.asset_type_filter_matches(asset) and outliner_view.asset_matches_search(asset, search_text):
			visible_assets.append(asset)
	visible_assets.sort_custom(_sort_named_documents)
	rows.append({"kind": "section", "label": "%s · Components" % active_geometry_submodule})
	for asset in visible_assets:
		_append_geometry_asset_rows(rows, asset, not search_text.is_empty())
	if visible_assets.is_empty():
		rows.append({"kind": "note", "label": "No Assets match the selected types."})
	return rows


func _append_geometry_asset_rows(rows: Array, asset: Dictionary, force_expand: bool) -> void:
	var asset_id := str(asset.get("id", ""))
	rows.append({
		"kind": "asset",
		"asset_id": asset_id,
		"label": str(asset.get("name", "Asset")),
		"selected": selected_asset_id == asset_id and selected_component_id.is_empty()
	})
	if not force_expand and not bool(expanded_assets.get(asset_id, false)):
		return
	rows.append({"kind": "child_section", "label": "Components"})
	var components: Array = []
	var guides: Array = asset.get("guides", []).duplicate(true)
	for component in asset.get("components", []):
		if str(component.get("type", "component")) == "guide":
			guides.append(component)
		elif _is_region(component):
			continue
		elif _is_reference_component(component) or _is_hole_component(component):
			# The Mesh module is the Fill pipeline's workspace - Sampling,
			# Seeding, Meshing - and a Hole has none of that. Its Stroke Bake
			# rides along with Update Meshes like every other one; it just has no
			# Body row here to hang pipeline steps under.
			continue
		else:
			components.append(component)
	components.sort_custom(_sort_named_documents)
	guides.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return WorldDocumentService.guide_display_name(asset, left).naturalnocasecmp_to(WorldDocumentService.guide_display_name(asset, right)) < 0)
	for component in components:
		var draw_mode := WorldDocumentService.component_draw_mode(component)
		if active_geometry_submodule in ["Sampling", "Seeding"] and draw_mode == WorldDocumentService.DRAW_MODE_CONTOUR:
			continue
		var component_id := str(component.get("id", ""))
		var summary := _geometry_outliner_status_summary(asset_id, component_id, component)
		rows.append({
			"kind": "component",
			"asset_id": asset_id,
			"component_id": component_id,
			"label": str(component.get("name", "Component")),
			"tooltip": str(summary.get("tooltip", "")),
			"selected": selected_asset_id == asset_id and selected_component_id == component_id and selected_geometry_bake_method.is_empty(),
			"badge": WorldDocumentService.topology_role(component),
			"status_color": summary.get("color", Color("#737f91")),
			"status_count": int(summary.get("count", 0))
		})
		match active_geometry_submodule:
			"Sampling":
				_append_geometry_sampling_rows(rows, asset, component_id, guides)
			"Seeding":
				_append_geometry_seeding_rows(rows, asset, component, guides)
			"Meshing":
				_append_geometry_meshing_rows(rows, asset, component)


func _append_geometry_sampling_rows(rows: Array, asset: Dictionary, component_id: String, guides: Array) -> void:
	var asset_id := str(asset.get("id", ""))
	if _geometry_body_accepts_holes(asset, component_id):
		for hole_component in asset.get("components", []):
			if not _is_geometry_hole_candidate(asset, hole_component, component_id):
				continue
			var hole_component_id := str(hole_component.get("id", ""))
			var summary := _geometry_sampling_input_summary(asset_id, component_id, hole_component_id, "hole")
			rows.append({
				"kind": "hole", "asset_id": asset_id, "component_id": component_id, "target_id": hole_component_id,
				"indent": 34,
				"label": "Hole · %s  %s" % [WorldDocumentService.component_outliner_name(assets, hole_component), str(summary.get("label", "↳"))],
				"tooltip": "Sampling constraint · select the parent Component to edit this boundary",
				"selected": selected_sampling_input_id == hole_component_id,
				"style_role": "hole",
				"badge": "hole"
			})
	for guide in guides:
		if AssetGuide.scope_component_id(guide) != component_id or str(guide.get("guide_type", "")) != AssetGuide.CUT:
			continue
		var guide_id := str(guide.get("id", ""))
		var guide_summary := _geometry_sampling_input_summary(asset_id, component_id, guide_id, "cut")
		rows.append({
			"kind": "guide", "asset_id": asset_id, "target_id": guide_id,
			"indent": 34,
			"label": "Cut · %s  %s" % [WorldDocumentService.guide_display_name(asset, guide), str(guide_summary.get("label", "↳"))],
			"tooltip": "Sampling constraint · %s" % AssetGuide.display_name(str(guide.get("guide_type", AssetGuide.SAMPLER_SPINE))),
			"selected": guide_id == selected_guide_id,
			"guide_type": str(guide.get("guide_type", AssetGuide.SAMPLER_SPINE)),
			"badge": "Cut" if str(guide.get("guide_type", "")) == AssetGuide.CUT else "Guide"
		})


func _geometry_seeding_input_row(asset_id: String, component_id: String, input_id: String, role: String, title: String, treatment: String, badge: String) -> Dictionary:
	var count := 0
	for stat in _geometry_sampling_bake(asset_id, component_id).get("boundary_stats", []):
		if str(stat.get("input_id", "")) == input_id and str(stat.get("role", "")) == role:
			count += int(stat.get("sample_count", 0))
	if role == "spine":
		var component := _get_component(_get_asset(asset_id), component_id)
		var seeding_result := geometry_seeding_preview if _geometry_seeding_preview_matches(asset_id, component_id, component) else _geometry_seeding_bake(asset_id, component_id)
		for stat in seeding_result.get("guide_stats", []):
			if str(stat.get("guide_id", "")) == input_id:
				count = int(stat.get("seed_count", 0))
	return {
		"kind": "input", "asset_id": asset_id, "component_id": component_id, "target_id": input_id, "role": role,
		"indent": 34, "height": 26,
		"label": "%s  ·  %s%s" % [title, treatment, "  ·  %d" % count if count > 0 else ""],
		"selected": not input_id.is_empty() and selected_seeding_input_id == input_id,
		"badge": badge
	}


func _append_geometry_seeding_rows(rows: Array, asset: Dictionary, component: Dictionary, guides: Array) -> void:
	var asset_id := str(asset.get("id", ""))
	var component_id := str(component.get("id", ""))
	rows.append({
		"kind": "dependency", "asset_id": asset_id, "component_id": component_id,
		"indent": 34, "height": 26,
		"label": "Sampling · Adaptive  ·  %s" % ("Baked" if _geometry_sampling_bake_is_current(asset_id, component_id, component) else "Required"),
		"action_id": "open_sampling"
	})
	rows.append(_geometry_seeding_input_row(asset_id, component_id, "", "outer", "Outer · %s" % str(component.get("name", "Component")), "Clearance", "Outer"))
	if _geometry_body_accepts_holes(asset, component_id):
		for hole_component in asset.get("components", []):
			if _is_geometry_hole_candidate(asset, hole_component, component_id):
				rows.append(_geometry_seeding_input_row(asset_id, component_id, str(hole_component.get("id", "")), "hole", "Hole · %s" % WorldDocumentService.component_outliner_name(assets, hole_component), "Excluded", "Hole"))
	for guide in guides:
		if AssetGuide.scope_component_id(guide) != component_id:
			continue
		var guide_type := str(guide.get("guide_type", ""))
		var guide_name := WorldDocumentService.guide_display_name(asset, guide)
		if guide_type == AssetGuide.CUT:
			rows.append(_geometry_seeding_input_row(asset_id, component_id, str(guide.get("id", "")), "cut", "Cut · %s" % guide_name, "Barrier", "Cut"))
		elif guide_type == AssetGuide.SAMPLER_SPINE:
			var enabled := _geometry_seeding_spine_enabled(_geometry_seeding_recipe(asset_id, component_id), str(guide.get("id", "")))
			rows.append(_geometry_seeding_input_row(asset_id, component_id, str(guide.get("id", "")), "spine", "Spine · %s" % guide_name, "Enabled" if enabled else "Disabled", "Spine"))


func _append_geometry_meshing_rows(rows: Array, asset: Dictionary, component: Dictionary) -> void:
	var asset_id := str(asset.get("id", ""))
	var component_id := str(component.get("id", ""))
	var sampling := _geometry_sampling_bake(asset_id, component_id)
	var sampling_ready := _geometry_sampling_bake_is_current(asset_id, component_id, component)
	var hole_count := int(sampling.get("hole_count", 0))
	var cut_count := int(sampling.get("cut_count", 0))
	var recipe := _geometry_meshing_recipe(asset_id, component_id)
	var seed_method := str(recipe.get("parameters", {}).get("seeding_method", GeometrySeedingService.POISSON_FILL))
	var seeding := _geometry_seeding_bake(asset_id, component_id, seed_method)
	var seeding_ready := _geometry_meshing_input_is_current(asset_id, component_id, component, recipe)
	var result := geometry_meshing_preview if _geometry_meshing_preview_matches(asset_id, component_id, component) else _geometry_meshing_bake(asset_id, component_id)
	for entry in [
		{"label": "Sampling · Adaptive · %s · %d Points" % ["Baked" if sampling_ready else "Required", int(sampling.get("constraint_sample_count", sampling.get("sample_count", 0)))], "action_id": "open_sampling"},
		{"label": "Seeding · %s · %s · %d Seeds" % [_geometry_bake_method_label(seed_method), "Baked" if seeding_ready else "Required", int(seeding.get("seed_count", 0))], "action_id": "open_seeding"},
		{"label": "Constraints · Outer Preserved · %d Hole%s · %d Cut%s" % [hole_count, "" if hole_count == 1 else "s", cut_count, "" if cut_count == 1 else "s"], "action_id": "open_sampling"},
		{"label": "Mesh · Constrained Mesh · %s%s" % [_geometry_meshing_status(asset_id, component_id, component), " · %d Triangles" % int(result.get("triangle_count", 0)) if not result.is_empty() else ""], "action_id": ""}
	]:
		rows.append({
			"kind": "pipeline", "asset_id": asset_id, "component_id": component_id,
			"indent": 34, "height": 26,
			"label": str(entry["label"]), "action_id": str(entry["action_id"])
		})


func _on_geometry_pipeline_action(action_id: String, asset_id: String, component_id: String) -> void:
	match action_id:
		"open_sampling":
			_open_sampling_dependency(asset_id, component_id)
		"open_seeding":
			_open_seeding_dependency(asset_id, component_id)


func _outliner_row_status() -> Dictionary:
	# Derived state the rows display, resolved here so the view never reaches
	# into the geometry documents. Only the Style tree needs it today.
	var status: Dictionary = {}
	if active_module != "Style":
		return status
	for asset in assets:
		var asset_id := str(asset.get("id", ""))
		for component in asset.get("components", []):
			if _is_hole_component(component):
				continue
			var component_id := str(component.get("id", ""))
			var styles: Array = _weighting_styles(asset_id, component_id)
			var by_style: Dictionary = {}
			for style in styles:
				by_style[str(style.get("id", ""))] = _weighting_status(asset_id, component_id, component, style)
			status["%s/%s" % [asset_id, component_id]] = {
				"mesh_status": _component_mesh_status(asset_id, component_id, component),
				"weighting_styles": styles,
				"weighting_status": by_style
			}
	return status


func _on_outliner_component_selected(asset_id: String, component_id: String) -> void:
	_select_component(asset_id, component_id, true)


func _on_outliner_visibility_toggled(kind: String, asset_id: String, target_id: String, visible: bool) -> void:
	match kind:
		"asset":
			_on_asset_visibility_changed(visible, asset_id)
		"group":
			_on_group_visibility_entry_changed(visible, asset_id, target_id)
		"guide":
			_on_guide_visibility_entry_changed(visible, asset_id, target_id)
		"component":
			_on_component_visibility_entry_changed(visible, asset_id, target_id)


func _on_outliner_row_context_menu(kind: String, asset_id: String, target_id: String, event: InputEvent, anchor: Button) -> void:
	match kind:
		"asset":
			_on_asset_outliner_gui_input(event, asset_id, anchor)
		"group":
			_on_group_outliner_gui_input(event, asset_id, target_id, anchor)
		"component":
			_on_component_outliner_gui_input(event, asset_id, target_id, anchor)


func _outliner_drop_data_from_view(asset_id: String, target_id: String, payload: Variant) -> void:
	_outliner_drop_data(Vector2.ZERO, payload, asset_id, target_id)


func _create_module_asset_category() -> String:
	# Which composition the active Create module lists. The seven-type filter is
	# a separate question and applies inside Single only, which is also the one
	# module that shows it.
	return str(ASSET_CATEGORY_BY_CREATE_SUBMODULE.get(active_create_submodule, WorldDocumentService.ASSET_CATEGORY_SINGLE))


func _update_outliner_asset_type_filter_visibility() -> void:
	if not is_instance_valid(outliner_asset_type_filter_panel):
		return
	outliner_asset_type_filter_panel.visible = (active_module == "Create" and active_create_submodule == "Single") or active_module in ["Mesh", "Style"]


static func _default_outliner_asset_type_filters() -> Dictionary:
	var filters: Dictionary = {}
	for asset_type in WorldDocumentService.ASSET_TYPES:
		filters[asset_type] = true
	return filters


func _on_outliner_asset_type_filter_toggled(enabled: bool, asset_type: String) -> void:
	outliner_asset_type_filters[asset_type] = enabled
	_update_outliner_asset_type_filter_all_button()
	_invalidate_render(RENDER_OUTLINER)


func _toggle_all_outliner_asset_type_filters() -> void:
	# One button for both moves. Everything shown is the state where "show all"
	# has nothing left to do, so there it clears instead: picking a single type
	# is then two clicks rather than six unticks.
	var enable_all := not _every_outliner_asset_type_filter_enabled()
	for asset_type in outliner_asset_type_filters.keys():
		outliner_asset_type_filters[asset_type] = enable_all
	_apply_outliner_asset_type_filter_checkboxes()
	_invalidate_render(RENDER_OUTLINER)


func _every_outliner_asset_type_filter_enabled() -> bool:
	for asset_type in outliner_asset_type_filters.keys():
		if not bool(outliner_asset_type_filters[asset_type]):
			return false
	return true


func _update_outliner_asset_type_filter_all_button() -> void:
	if not is_instance_valid(outliner_asset_type_filter_all_button):
		return
	var shows_everything := _every_outliner_asset_type_filter_enabled()
	# The button says what pressing it does, so its own state is never a guess.
	outliner_asset_type_filter_all_button.text = "None" if shows_everything else "All"
	outliner_asset_type_filter_all_button.tooltip_text = "Hide every Asset type" if shows_everything else "Show every Asset type"


func _apply_outliner_asset_type_filter_checkboxes() -> void:
	for asset_type in outliner_asset_type_filter_checkboxes.keys():
		var checkbox := outliner_asset_type_filter_checkboxes[asset_type] as CheckBox
		if checkbox != null:
			checkbox.set_pressed_no_signal(bool(outliner_asset_type_filters.get(asset_type, true)))
	_update_outliner_asset_type_filter_all_button()


func _outliner_focus_asset_id() -> String:
	for asset in assets:
		var asset_id := str(asset.get("id", ""))
		if _outliner_expansion_scope_matches(asset) and bool(expanded_assets.get(asset_id, false)):
			return asset_id
	return ""


func _outliner_expansion_scope_matches(asset: Dictionary) -> bool:
	if active_module != "Create":
		return true
	return _asset_matches_create_submodule(asset)


func _set_outliner_asset_expanded(requested_asset_id: String, expanded: bool) -> void:
	var asset_id := _outliner_expansion_anchor_asset_id(requested_asset_id)
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


func _select_motion_path(path_id: String) -> void:
	selected_motion_path_id = path_id
	motion_path_phase = 0.0
	motion_path_playing = false
	if _get_asset(motion_path_preview_asset_id).is_empty():
		motion_path_preview_asset_id = _default_motion_path_preview_asset_id()
	_invalidate_render(RENDER_DOCUMENT)


func _select_motion_sequence(sequence_id: String) -> void:
	selected_motion_sequence_id = sequence_id
	var sequence_document := _get_motion_sequence(sequence_id)
	var first_entry := _first_motion_sequence_entry(sequence_document)
	selected_motion_sequence_entry_id = str(first_entry.get("id", ""))
	motion_sequence_phase = 0.0
	motion_sequence_playing = false
	_invalidate_render(RENDER_DOCUMENT)


func _select_motion_act_preview_asset(asset_id: String) -> void:
	if _get_asset(asset_id).is_empty():
		return
	motion_act_preview_asset_id = asset_id
	motion_act_phase = 0.0
	motion_act_playing = false
	_invalidate_render(RENDER_OUTLINER | RENDER_CANVAS_CONTEXT)


func _select_motion_sequence_entry(entry_id: String) -> void:
	var sequence_document := _get_motion_sequence(selected_motion_sequence_id)
	if _get_motion_sequence_entry(sequence_document, entry_id).is_empty():
		return
	selected_motion_sequence_entry_id = entry_id
	_invalidate_render(RENDER_INSPECTOR)
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
	_invalidate_render(RENDER_INSPECTOR | RENDER_CONTEXT_BAR)
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
			_invalidate_render(RENDER_INSPECTOR | RENDER_CONTEXT_BAR)
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
	_invalidate_render(RENDER_OUTLINER)
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
	_invalidate_render(RENDER_OUTLINER)
	if is_instance_valid(motion_sequence_workspace):
		motion_sequence_workspace.set_document(sequence_document)


func _on_motion_path_point_add_requested(world_position: Vector2) -> void:
	var path_document := _get_motion_path(selected_motion_path_id)
	if path_document.is_empty():
		return
	_record_direct_change()
	MotionPathTopology.add_point(path_document["topology"], world_position)
	motion_path_phase = 0.0
	_refresh_motion_path_workspace()
	_invalidate_render(RENDER_INSPECTOR | RENDER_CONTEXT_BAR)


func _on_motion_path_point_move_requested(point_id: String, world_position: Vector2) -> void:
	var path_document := _get_motion_path(selected_motion_path_id)
	if path_document.is_empty() or not MotionPathTopology.move_point(path_document["topology"], point_id, world_position):
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
		_invalidate_render(RENDER_INSPECTOR | RENDER_CONTEXT_BAR)


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
	if is_instance_valid(motion_inspector_view.motion_sequence_runtime_sequence_label):
		motion_inspector_view.motion_sequence_runtime_sequence_label.text = "%.2f" % motion_sequence_phase
	if is_instance_valid(motion_inspector_view.motion_sequence_runtime_path_label):
		motion_inspector_view.motion_sequence_runtime_path_label.text = "%.2f" % float(snapshot.get("path_phase", 0.0))
	if is_instance_valid(motion_inspector_view.motion_sequence_runtime_animation_label):
		motion_inspector_view.motion_sequence_runtime_animation_label.text = "%.2f" % float(snapshot.get("animation_phase", 0.0))


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
	_invalidate_render(RENDER_DOCUMENT)


func _sort_named_documents(a: Dictionary, b: Dictionary) -> bool:
	return WorldDocumentService.sort_named_documents(a, b)


func _open_sampling_dependency(asset_id: String, component_id: String) -> void:
	active_geometry_submodule = "Sampling"
	_set_active_module_visual("Mesh", "Sampling")
	_select_geometry_component(asset_id, component_id)


func _open_seeding_dependency(asset_id: String, component_id: String) -> void:
	active_geometry_submodule = "Seeding"
	_set_active_module_visual("Mesh", "Seeding")
	_select_geometry_component(asset_id, component_id)


func _set_sampling_input(asset_id: String, input_id: String, kind: String) -> void:
	# The only writer of the Sampling input pair. A Sampling boundary is a Hole
	# Component or a Cut Guide; anything else stores nothing at all, so the two
	# fields are either a resolvable pair or both empty. Without this an id can
	# survive with a kind that does not describe it — a Spine reached through
	# _select_guide used to be stored as a Guide, and the Boundary Density block
	# then rendered for something that is not a Sampling boundary.
	var asset := _get_asset(asset_id)
	if kind == "component":
		var hole_component := _get_component(asset, input_id)
		if _is_geometry_hole_input(asset, hole_component, selected_component_id):
			selected_sampling_input_id = input_id
			selected_sampling_input_kind = "component"
			return
	elif kind == "guide":
		var guide := _get_guide(asset, input_id)
		if not guide.is_empty() and str(guide.get("guide_type", "")) == AssetGuide.CUT \
			and not AssetGuide.is_group_scoped(guide) \
			and AssetGuide.scope_component_id(guide) == selected_component_id:
			selected_sampling_input_id = input_id
			selected_sampling_input_kind = "guide"
			return
	selected_sampling_input_id = ""
	selected_sampling_input_kind = ""


func _sampling_input_kind_for_seeding_role(role: String) -> String:
	# The Seeding tree names its rows by treatment — outer, hole, cut, spine —
	# while a Sampling boundary input is identified by what the document holds:
	# a Component or a Guide. Only Holes and Cuts are Sampling
	# boundaries at all; the Outer contour has no input record of its own and a
	# Spine is a Seeding input, so both map to no Sampling input rather than to a
	# kind the lookup would then fail on silently.
	if role == WorldDocumentService.ROLE_HOLE:
		return "component"
	if role == WorldDocumentService.ROLE_CUT:
		return "guide"
	return ""


func _select_geometry_seeding_input(asset_id: String, component_id: String, input_id: String, role: String) -> void:
	if selected_asset_id != asset_id or selected_component_id != component_id:
		_select_geometry_component(asset_id, component_id)
	selected_seeding_input_id = input_id
	_set_sampling_input(asset_id, input_id, _sampling_input_kind_for_seeding_role(role))
	selected_guide_id = input_id if role in ["cut", "spine"] else ""
	_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR)
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


func _geometry_bake_methods_for_active_module(bakes: Dictionary) -> Array[String]:
	var order: Array[String] = []
	if active_geometry_submodule == "Sampling":
		order.append(GeometrySamplingService.ADAPTIVE)
	elif active_geometry_submodule == "Seeding":
		order.append(GeometrySeedingService.POISSON_FILL)
		order.append(GeometrySeedingService.SPINE_FLOW)
	else:
		order.append(GeometryMeshingService.CONSTRAINED_MESH)
		order.append(ContourMeshService.METHOD)
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
	if method == ContourMeshService.METHOD:
		return "Contour Stroke"
	return "Poisson Fill"


func _geometry_bake_status(method: String, bake: Dictionary, asset_id: String, component_id: String, component: Dictionary) -> String:
	if active_geometry_submodule == "Sampling":
		return "Baked" if _geometry_sampling_bake_is_current(asset_id, component_id, component) else "Ready to Preview"
	if active_geometry_submodule == "Meshing":
		if method == ContourMeshService.METHOD:
			return "Baked" if ContourMeshService.matches_source(bake, component, _effective_contour_stroke_width_px(component)) else "Ready to Bake"
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
			else _geometry_meshing_status(asset_id, component_id, component)
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
	_invalidate_render(RENDER_DOCUMENT)


func _select_geometry_component(asset_id: String, component_id: String) -> void:
	geometry_sampling_preview_revision += 1
	geometry_seeding_preview_revision += 1
	selected_asset_id = asset_id
	selected_component_id = component_id
	selected_guide_id = ""
	selected_seeding_input_id = ""
	_set_sampling_input(asset_id, "", "")
	active_module = "Mesh"
	active_state = ""
	selected_geometry_bake_method = ""
	_set_geometry_command_state("")
	_set_outliner_asset_expanded(asset_id, true)
	_invalidate_render(RENDER_DOCUMENT)
	if active_geometry_submodule == "Sampling" and is_instance_valid(geometry_sampling_workspace):
		if geometry_sampling_workspace.is_inside_tree():
			geometry_sampling_workspace.grab_focus()
		if not _geometry_sampling_bake_is_current(asset_id, component_id, _get_component(_get_asset(asset_id), component_id)):
			_schedule_geometry_sampling_preview()
	elif active_geometry_submodule == "Seeding" and is_instance_valid(geometry_seeding_workspace):
		if geometry_seeding_workspace.is_inside_tree():
			geometry_seeding_workspace.grab_focus()
		if _geometry_seeding_status(asset_id, component_id, _get_component(_get_asset(asset_id), component_id)) == "Ready to Preview":
			_schedule_geometry_seeding_preview()
	elif active_geometry_submodule == "Meshing" and is_instance_valid(geometry_meshing_workspace):
		if geometry_meshing_workspace.is_inside_tree():
			geometry_meshing_workspace.grab_focus()


func _select_geometry_sampling_hole(asset_id: String, parent_component_id: String, hole_id := "") -> void:
	if parent_component_id.is_empty():
		_select_geometry_asset(asset_id)
		return
	if selected_asset_id != asset_id or selected_component_id != parent_component_id or active_module != "Mesh" or active_geometry_submodule != "Sampling":
		_select_geometry_component(asset_id, parent_component_id)
	else:
		selected_guide_id = ""
	if not hole_id.is_empty():
		selected_seeding_input_id = hole_id
		_set_sampling_input(asset_id, hole_id, "component")
		_invalidate_render(RENDER_DOCUMENT)
		return
	for hole_component in _get_asset(asset_id).get("components", []):
		if _is_geometry_hole_input(_get_asset(asset_id), hole_component, parent_component_id):
			selected_seeding_input_id = str(hole_component.get("id", ""))
			_set_sampling_input(asset_id, str(hole_component.get("id", "")), "component")
			_invalidate_render(RENDER_DOCUMENT)
			return


func _select_geometry_bake(asset_id: String, component_id: String, method: String) -> void:
	_select_geometry_component(asset_id, component_id)
	if active_geometry_submodule == "Sampling":
		_set_geometry_sampling_method(method)
	elif active_geometry_submodule == "Seeding":
		_set_geometry_seeding_method(method)
	else:
		_set_geometry_meshing_method(method)


func _select_group(asset_id: String, group_id: String) -> void:
	var asset := _get_asset(asset_id)
	if asset.is_empty() or ComponentHierarchy.group_by_id(asset, group_id).is_empty():
		return
	selected_asset_id = asset_id
	selected_group_id = group_id
	selected_component_id = ""
	selected_component_ids.clear()
	selected_guide_id = ""
	active_state = ""
	_invalidate_render(RENDER_DOCUMENT)


func _on_group_outliner_gui_input(event: InputEvent, asset_id: String, group_id: String, button: Button) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
		return
	_select_group(asset_id, group_id)
	component_context_menu.set_meta("asset_id", asset_id)
	component_context_menu.set_meta("component_id", "")
	component_context_menu.set_meta("group_id", group_id)
	# One popup serves the Asset, Group and Component rows, so every entry has to
	# be set here rather than left at whatever the last row wanted. A Group row
	# that only switched its own entries off inherited the Asset row's disabled
	# Duplicate, which read as the action being unavailable for Groups.
	for action_id in [0, 1, 2, 8, 9]:
		component_context_menu.set_item_disabled(component_context_menu.get_item_index(action_id), false)
	for action_id in [3, 4, 5, 6, 7]:
		component_context_menu.set_item_disabled(component_context_menu.get_item_index(action_id), true)
	component_context_menu.position = Vector2i(button.global_position + event.position)
	component_context_menu.popup()
	get_viewport().set_input_as_handled()


func _on_asset_outliner_gui_input(event: InputEvent, asset_id: String, button: Button) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed or not is_instance_valid(component_context_menu):
		return
	_select_asset(asset_id)
	component_context_menu.set_meta("asset_id", asset_id)
	component_context_menu.set_meta("component_id", "")
	component_context_menu.set_meta("group_id", "")
	for action_id in [0, 1, 2, 3, 4, 5, 8, 9]:
		component_context_menu.set_item_disabled(component_context_menu.get_item_index(action_id), true)
	component_context_menu.set_item_disabled(component_context_menu.get_item_index(6), true)
	component_context_menu.set_item_disabled(component_context_menu.get_item_index(7), component_clipboard.is_empty())
	component_context_menu.position = Vector2i(button.global_position + event.position)
	component_context_menu.popup()
	get_viewport().set_input_as_handled()


func _outliner_drop_data(_at_position: Vector2, data, asset_id: String, target_id: String) -> void:
	if not outliner_view.can_drop_data(Vector2.ZERO, data, asset_id, target_id):
		return
	var asset := _get_asset(asset_id)
	if str(data.get("kind", "")) == "group":
		var group_id := str(data.get("group_id", ""))
		_record_direct_change()
		_move_group_under_component_preserving_world(asset, group_id, "" if target_id == "root" else target_id)
		selected_asset_id = asset_id
		selected_group_id = group_id
		selected_component_id = ""
		selected_component_ids.clear()
		_invalidate_render(RENDER_DOCUMENT)
		_show_status_message("Removed Group from Parent." if target_id == "root" else "Parented Group under %s." % str(_get_component(asset, target_id).get("name", "Component")))
		return
	var component_ids: Array = data.get("component_ids", [])
	_record_direct_change()
	if target_id == "root":
		for component_id in component_ids:
			_set_component_group_preserving_world(asset, str(component_id), "")
		_show_status_message("Removed %d Component%s from Group." % [component_ids.size(), "" if component_ids.size() == 1 else "s"])
	elif not ComponentHierarchy.group_by_id(asset, target_id).is_empty():
		for component_id in component_ids:
			_set_component_group_preserving_world(asset, str(component_id), target_id)
		_show_status_message("Moved %d Component%s into Group." % [component_ids.size(), "" if component_ids.size() == 1 else "s"])
	else:
		for component_id in component_ids:
			_set_component_parent_preserving_world(asset, str(component_id), target_id)
		_show_status_message("Parented %d Component%s." % [component_ids.size(), "" if component_ids.size() == 1 else "s"])
	selected_asset_id = asset_id
	selected_component_id = str(component_ids.back())
	selected_component_ids = component_ids.duplicate()
	selected_group_id = ""
	_invalidate_render(RENDER_DOCUMENT)


func _set_component_group_preserving_world(asset: Dictionary, component_id: String, group_id: String) -> void:
	var component := _get_component(asset, component_id)
	if component.is_empty():
		return
	var world_record := ComponentHierarchy.world_transform_record(asset, component_id)
	component["group_id"] = group_id
	component["transform"] = ComponentHierarchy.local_transform_from_world_record(asset, component_id, world_record)
	ComponentHierarchy.canonicalize_redundant_group_membership(asset)


func _set_component_parent_preserving_world(asset: Dictionary, component_id: String, parent_id: String) -> void:
	var component := _get_component(asset, component_id)
	if component.is_empty() or not ComponentHierarchy.can_parent(asset, component_id, parent_id):
		return
	var world_record := ComponentHierarchy.world_transform_record(asset, component_id)
	component["parent_component_id"] = parent_id
	component["transform"] = ComponentHierarchy.local_transform_from_world_record(asset, component_id, world_record)
	ComponentHierarchy.canonicalize_redundant_group_membership(asset)


func _set_group_parent_preserving_world(asset: Dictionary, group_id: String, parent_id: String) -> void:
	var group := ComponentHierarchy.group_by_id(asset, group_id)
	if group.is_empty() or not ComponentHierarchy.can_parent_group(asset, group_id, parent_id):
		return
	var member_world_records: Dictionary = {}
	for member in asset.get("components", []):
		if member is Dictionary and ComponentHierarchy.membership_group_id(asset, str(member.get("id", ""))) == group_id:
			member_world_records[str(member.get("id", ""))] = ComponentHierarchy.world_transform_record(asset, str(member.get("id", "")))
	var group_world_record := ComponentHierarchy.group_world_transform_record(asset, group_id)
	group["parent_component_id"] = parent_id
	group["transform"] = ComponentHierarchy.group_local_transform_from_world_record(asset, group_id, group_world_record)
	for component_id in member_world_records:
		var component := _get_component(asset, str(component_id))
		if not component.is_empty():
			component["transform"] = ComponentHierarchy.local_transform_from_world_record(asset, str(component_id), member_world_records[component_id])


func _move_group_under_component_preserving_world(asset: Dictionary, group_id: String, parent_id: String) -> void:
	var group := ComponentHierarchy.group_by_id(asset, group_id)
	if group.is_empty() or not ComponentHierarchy.can_move_group_to_component(asset, group_id, parent_id):
		return
	var member_world_records: Dictionary = {}
	for member in asset.get("components", []):
		var member_id := str(member.get("id", "")) if member is Dictionary else ""
		if not member_id.is_empty() and ComponentHierarchy.membership_group_id(asset, member_id) == group_id:
			member_world_records[member_id] = ComponentHierarchy.world_transform_record(asset, member_id)
	var group_world_record := ComponentHierarchy.group_world_transform_record(asset, group_id)
	for member in ComponentHierarchy.direct_group_members(asset, group_id):
		member["parent_component_id"] = parent_id
	group["parent_component_id"] = parent_id
	group["transform"] = ComponentHierarchy.group_local_transform_from_world_record(asset, group_id, group_world_record)
	var member_ids: Array = member_world_records.keys()
	member_ids.sort_custom(func(left, right) -> bool:
		return ComponentHierarchy.component_depth(asset, str(left)) < ComponentHierarchy.component_depth(asset, str(right))
	)
	for member_id in member_ids:
		var member := _get_component(asset, str(member_id))
		if not member.is_empty():
			member["transform"] = ComponentHierarchy.local_transform_from_world_record(asset, str(member_id), member_world_records[member_id])


func _on_component_outliner_gui_input(event: InputEvent, asset_id: String, component_id: String, button: Button) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
		return
	if not is_instance_valid(component_context_menu):
		return
	if not selected_component_ids.has(component_id):
		_select_component(asset_id, component_id)
	else:
		selected_component_id = component_id
	component_context_menu.set_meta("asset_id", asset_id)
	component_context_menu.set_meta("component_id", component_id)
	component_context_menu.set_meta("group_id", "")
	for action_id in [0, 1, 2, 8, 9]:
		component_context_menu.set_item_disabled(component_context_menu.get_item_index(action_id), false)
	component_context_menu.set_item_disabled(component_context_menu.get_item_index(4), false)
	var component := _get_component(_get_asset(asset_id), component_id)
	var effective_group_id := ComponentHierarchy.membership_group_id(_get_asset(asset_id), component_id)
	component_context_menu.set_item_disabled(component_context_menu.get_item_index(5), effective_group_id.is_empty())
	var detach_index := component_context_menu.get_item_index(3)
	component_context_menu.set_item_disabled(detach_index, str(component.get("parent_component_id", "")).is_empty())
	component_context_menu.set_item_disabled(component_context_menu.get_item_index(6), _selected_component_ids_for_clipboard(_get_asset(asset_id)).is_empty())
	component_context_menu.set_item_disabled(component_context_menu.get_item_index(7), component_clipboard.is_empty())
	component_context_menu.position = Vector2i(button.global_position + event.position)
	component_context_menu.popup()
	get_viewport().set_input_as_handled()


func _select_asset(asset_id: String) -> void:
	_stop_guide_draw_state()
	_set_active_context_command("")
	var was_selected := selected_asset_id == asset_id and selected_component_id.is_empty() and selected_guide_id.is_empty()
	active_module = "Create"
	_set_create_submodule_context(_create_submodule_for_asset(asset_id))
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_component_ids.clear()
	selected_group_id = ""
	selected_guide_id = ""
	active_state = ""
	canvas_view.set_interaction_state("")
	if was_selected and _outliner_expansion_anchor_asset_id(asset_id) == asset_id:
		# Clicking the selected row again folds it. A variant row is not that
		# row: its expansion belongs to the Palette that lists it, so clicking
		# it selects and nothing more.
		_set_outliner_asset_expanded(asset_id, not bool(expanded_assets.get(asset_id, false)))
	else:
		_set_outliner_asset_expanded(asset_id, true)
	_invalidate_render(RENDER_DOCUMENT)


func _open_component_dialog(asset_id: String, anchor: Control) -> void:
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_component_ids.clear()
	selected_guide_id = ""
	var add_menu_asset := _get_asset(asset_id)
	if WorldDocumentService.is_set_asset(add_menu_asset):
		_open_composition_add_menu(set_member_menu, asset_id, anchor)
		return
	if WorldDocumentService.is_palette_asset(add_menu_asset):
		_open_composition_add_menu(palette_variant_menu, asset_id, anchor)
		return
	component_draw_mode_menu.set_meta("asset_id", asset_id)
	component_draw_mode_menu.set_meta("parent_component_id", "")
	component_draw_mode_menu.position = Vector2i(anchor.global_position + Vector2(0.0, anchor.size.y))
	component_draw_mode_menu.popup()


func _open_composition_add_menu(menu: PopupMenu, asset_id: String, anchor: Control) -> void:
	menu.set_meta("asset_id", asset_id)
	menu.position = Vector2i(anchor.global_position + Vector2(0.0, anchor.size.y))
	menu.popup()


func _on_set_add_selected(id: int) -> void:
	if id != 0:
		return
	var asset_id := str(set_member_menu.get_meta("asset_id", ""))
	if WorldDocumentService.is_set_asset(_get_asset(asset_id)):
		_open_new_asset_dialog(asset_id)


func _on_palette_add_selected(id: int) -> void:
	if id != 0:
		return
	var asset_id := str(palette_variant_menu.get_meta("asset_id", ""))
	if WorldDocumentService.is_palette_asset(_get_asset(asset_id)):
		_open_new_asset_dialog(asset_id)


func _reference_source_candidates(owner_asset_id: String) -> Array[Dictionary]:
	# What a Component's `+ -> Reference` offers: Symbols, and only Symbols.
	# A Reference under a Component places a Symbol inside that Component's
	# frame and follows whatever the Component does. Assembling ordinary Assets
	# is what a Set is for, and offering it here as well would be two ways to
	# the same result, one of them without a Set's guarantees.
	#
	# A Palette variant is excluded even when it is a Symbol: it is presentation
	# the client chooses on its own and carries no gameplay data by contract.
	# Instancing one would make an authoritative placement depend on a choice
	# nobody has to agree on. A composition is excluded because it is assembled
	# rather than placed, and the cycle check keeps every remaining choice
	# resolvable through the Catalog.
	var owner_by_member := _composition_owner_by_member_id()
	var candidates: Array[Dictionary] = []
	for source_asset in assets:
		if not source_asset is Dictionary or WorldDocumentService.is_composition_asset(source_asset):
			continue
		if WorldDocumentService.asset_type(source_asset) != WorldDocumentService.ASSET_TYPE_SYMBOLS:
			continue
		var source_asset_id := str(source_asset.get("id", ""))
		if WorldDocumentService.is_palette_asset(_get_asset(str(owner_by_member.get(source_asset_id, "")))):
			continue
		if not _reference_cycle_issue(owner_asset_id, source_asset_id).is_empty():
			continue
		candidates.append(source_asset)
	candidates.sort_custom(WorldDocumentService.sort_named_documents)
	return candidates


func _reference_cycle_issue(owner_asset_id: String, source_asset_id: String) -> String:
	# A Reference is resolved through the Catalog at Runtime, so a cycle is a
	# consumer's infinite recursion. It is rejected where it would be authored
	# rather than exported and left to the consumer to notice.
	if owner_asset_id.is_empty() or source_asset_id.is_empty():
		return "The referenced Asset is missing."
	if owner_asset_id == source_asset_id:
		return "An Asset cannot reference itself."
	var visited: Dictionary = {}
	var pending: Array[String] = [source_asset_id]
	while not pending.is_empty():
		var current_id: String = pending.pop_back()
		if visited.has(current_id):
			continue
		visited[current_id] = true
		if current_id == owner_asset_id:
			return "That Asset already reaches this one through its own References."
		for component in _get_asset(current_id).get("components", []):
			if component is Dictionary and _is_reference_component(component):
				pending.append(str(component.get("source_asset_id", "")))
	return ""


func _open_component_add_menu(asset_id: String, parent_component_id: String, anchor: Control) -> void:
	var parent := _get_component(_get_asset(asset_id), parent_component_id)
	if parent.is_empty():
		return
	if _is_hole_component(parent):
		component_add_menu.hide()
		_show_status_message("Hole Components cannot own children, Guides, or Regions.")
		return
	var parent_is_reference := _is_reference_component(parent)
	if parent_is_reference and WorldDocumentService.topology_role(parent) == WorldDocumentService.ROLE_HOLE:
		component_add_menu.hide()
		_show_status_message("A Reference authored as a Hole is a constraint and owns nothing.")
		return
	component_add_menu.set_meta("asset_id", asset_id)
	component_add_menu.set_meta("parent_component_id", parent_component_id)
	component_add_menu.set_meta("scope_kind", "component")
	component_add_menu.set_meta("scope_id", parent_component_id)
	# A Reference draws its own Asset, so it owns no Child, Guide or nested
	# Reference of its own. What it can own is a Region: it stands in the
	# hierarchy exactly where a Component would.
	component_add_menu.set_item_disabled(component_add_menu.get_item_index(0), parent_is_reference)
	component_add_menu.set_item_disabled(component_add_menu.get_item_index(1), parent_is_reference)
	component_add_menu.set_item_disabled(component_add_menu.get_item_index(2), false)
	component_add_menu.set_item_disabled(component_add_menu.get_item_index(3), parent_is_reference)
	component_add_reference_menu.clear()
	for source_asset in _reference_source_candidates(asset_id):
		component_add_reference_menu.add_item(str(source_asset.get("name", "Asset")), component_add_reference_menu.item_count)
		component_add_reference_menu.set_item_metadata(component_add_reference_menu.item_count - 1, str(source_asset.get("id", "")))
	component_add_menu.position = Vector2i(anchor.global_position + Vector2(0.0, anchor.size.y))
	component_add_menu.popup()


func _open_group_add_menu(asset_id: String, group_id: String, anchor: Control) -> void:
	if ComponentHierarchy.group_by_id(_get_asset(asset_id), group_id).is_empty():
		return
	component_add_menu.set_meta("asset_id", asset_id)
	component_add_menu.set_meta("parent_component_id", "")
	component_add_menu.set_meta("scope_kind", "group")
	component_add_menu.set_meta("scope_id", group_id)
	component_add_menu.set_item_disabled(component_add_menu.get_item_index(0), false)
	component_add_menu.set_item_disabled(component_add_menu.get_item_index(1), false)
	component_add_menu.set_item_disabled(component_add_menu.get_item_index(2), true)
	component_add_menu.set_item_disabled(component_add_menu.get_item_index(3), false)
	component_add_reference_menu.clear()
	component_add_menu.position = Vector2i(anchor.global_position + Vector2(0.0, anchor.size.y))
	component_add_menu.popup()


func _on_component_add_child_selected(index: int) -> void:
	if index < 0 or index >= WorldDocumentService.DRAW_MODES.size():
		return
	_open_component_name_dialog(str(component_add_menu.get_meta("asset_id", "")), str(component_add_menu.get_meta("parent_component_id", "")), WorldDocumentService.DRAW_MODES[index], "", str(component_add_menu.get_meta("scope_id", "")) if str(component_add_menu.get_meta("scope_kind", "component")) == "group" else "")


func _on_component_add_guide_selected(index: int) -> void:
	var guide_types := [AssetGuide.SAMPLE, AssetGuide.MOTION, AssetGuide.FLOW, AssetGuide.CUT]
	if index < 0 or index >= guide_types.size():
		return
	_create_guide(str(component_add_menu.get_meta("asset_id", "")), str(component_add_menu.get_meta("parent_component_id", "")), str(guide_types[index]))


func _on_component_add_weapon_guide_selected(index: int) -> void:
	var guide_types := [AssetGuide.WEAPON_SOCKET_PRIMARY, AssetGuide.GRIP_PRIMARY, AssetGuide.GRIP_SECONDARY, AssetGuide.ATTACK_POINT_PRIMARY, AssetGuide.REACH_LIMIT_PRIMARY]
	if index < 0 or index >= guide_types.size():
		return
	_create_weapon_guide(
		str(component_add_menu.get_meta("asset_id", "")),
		str(component_add_menu.get_meta("scope_kind", "component")),
		str(component_add_menu.get_meta("scope_id", "")),
		str(guide_types[index])
	)


func _on_component_add_region_selected(index: int) -> void:
	if index < 0 or index >= REGION_TYPES.size() or str(component_add_menu.get_meta("scope_kind", "component")) != "component":
		return
	_create_region(
		str(component_add_menu.get_meta("asset_id", "")),
		str(component_add_menu.get_meta("scope_kind", "component")),
		str(component_add_menu.get_meta("scope_id", "")),
		REGION_TYPES[index]
	)


func _on_component_add_reference_selected(index: int) -> void:
	var item_index := component_add_reference_menu.get_item_index(index)
	var source_asset := _get_asset(str(component_add_reference_menu.get_item_metadata(item_index)))
	var asset := _get_asset(str(component_add_menu.get_meta("asset_id", "")))
	if source_asset.is_empty() or asset.is_empty():
		return
	var cycle_issue := _reference_cycle_issue(str(asset.get("id", "")), str(source_asset.get("id", "")))
	if not cycle_issue.is_empty():
		_show_status_message(cycle_issue)
		return
	_open_component_name_dialog(str(asset.get("id", "")), str(component_add_menu.get_meta("parent_component_id", "")), "reference", str(source_asset.get("id", "")))


func _on_component_draw_mode_selected(index: int) -> void:
	if index < 0 or index >= WorldDocumentService.DRAW_MODES.size():
		return
	_open_component_name_dialog(str(component_draw_mode_menu.get_meta("asset_id", "")), str(component_draw_mode_menu.get_meta("parent_component_id", "")), WorldDocumentService.DRAW_MODES[index])


func _draw_mode_display_name(draw_mode: String) -> String:
	if draw_mode == WorldDocumentService.DRAW_MODE_CONTOUR:
		return "Contour"
	if draw_mode == WorldDocumentService.DRAW_MODE_PRIMITIVE:
		return "Primitive"
	return "Closed Loop"


func _draw_mode_change_issue(component: Dictionary, target_mode: String) -> String:
	if component.is_empty() or target_mode not in WorldDocumentService.DRAW_MODES:
		return "Select a Component first."
	if _is_reference_component(component):
		return "References inherit their source geometry and cannot change Draw Mode."
	var current_mode := WorldDocumentService.component_draw_mode(component)
	if current_mode == target_mode:
		return ""
	var crosses_geometry_source := (current_mode == WorldDocumentService.DRAW_MODE_PRIMITIVE) != (target_mode == WorldDocumentService.DRAW_MODE_PRIMITIVE)
	if not crosses_geometry_source:
		return ""
	var primitive = component.get("primitive", {})
	var has_primitive: bool = primitive is Dictionary and not primitive.is_empty()
	var has_bezier_topology: bool = not component.get("points", []).is_empty() or not component.get("edges", []).is_empty() or not component.get("chains", []).is_empty()
	if has_primitive or has_bezier_topology:
		return "Primitive uses a different geometry source. Clear or create a new empty Component instead of converting authored geometry."
	return ""


func _apply_component_draw_mode(component: Dictionary, target_mode: String) -> bool:
	if not _draw_mode_change_issue(component, target_mode).is_empty():
		return false
	var current_mode := WorldDocumentService.component_draw_mode(component)
	if current_mode == target_mode:
		return false
	component["draw_mode"] = target_mode
	if target_mode == WorldDocumentService.DRAW_MODE_PRIMITIVE:
		component["geometry_source"] = "primitive"
		component["primitive"] = {}
		component["points"] = []
		component["edges"] = []
		component["chains"] = []
	else:
		component["geometry_source"] = "bezier"
		component.erase("primitive")
		if not component.get("points", null) is Array:
			component["points"] = []
		if not component.get("edges", null) is Array:
			component["edges"] = []
		if not component.get("chains", null) is Array:
			component["chains"] = []
	return true


func _update_draw_mode_status() -> void:
	if not is_instance_valid(draw_mode_status):
		return
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var has_editable_component := active_module == "Create" and not component.is_empty() and not _is_reference_component(component) and not _is_region(component)
	var current_mode := WorldDocumentService.component_draw_mode(component) if not component.is_empty() else ""
	draw_mode_status.text = "Draw Mode: %s  ▾" % _draw_mode_display_name(current_mode) if not current_mode.is_empty() else "Draw Mode: —  ▾"
	draw_mode_status.disabled = not has_editable_component
	draw_mode_status.tooltip_text = "Closed Loop and Contour preserve Bezier topology. Primitive is available only while the Component is empty." if has_editable_component else ("References inherit their source Draw Mode." if _is_reference_component(component) else "Select a Component in Create to change Draw Mode.")
	var popup := draw_mode_status.get_popup()
	for draw_mode_index in range(WorldDocumentService.DRAW_MODES.size()):
		var target_mode: String = WorldDocumentService.DRAW_MODES[draw_mode_index]
		popup.set_item_checked(draw_mode_index, target_mode == current_mode)
		popup.set_item_disabled(draw_mode_index, not has_editable_component or not _draw_mode_change_issue(component, target_mode).is_empty())


func _on_draw_mode_status_selected(index: int) -> void:
	if index < 0 or index >= WorldDocumentService.DRAW_MODES.size():
		return
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var target_mode: String = WorldDocumentService.DRAW_MODES[index]
	var issue := _draw_mode_change_issue(component, target_mode)
	if not issue.is_empty():
		_show_status_message(issue)
		_update_draw_mode_status()
		return
	if WorldDocumentService.component_draw_mode(component) == target_mode:
		return
	_record_direct_change()
	if not _apply_component_draw_mode(component, target_mode):
		return
	active_state = ""
	active_draw_tool = ""
	active_context_command = ""
	_stop_primitive_create_command()
	canvas_view.set_interaction_state("")
	selected_point_id = ""
	selected_point_ids.clear()
	selected_edge_id = ""
	selected_edge_ids.clear()
	canvas_view.clear_selection()
	_invalidate_render(RENDER_DOCUMENT)
	_show_status_message("Draw Mode changed to %s." % _draw_mode_display_name(target_mode))


func _open_component_name_dialog(asset_id: String, parent_component_id: String, draw_mode: String, source_asset_id := "", group_id := "") -> void:
	var asset := _get_asset(asset_id)
	if asset.is_empty():
		return
	component_dialog.set_meta("asset_id", asset_id)
	component_dialog.set_meta("parent_component_id", parent_component_id)
	component_dialog.set_meta("draw_mode", draw_mode)
	component_dialog.set_meta("source_asset_id", source_asset_id)
	component_dialog.set_meta("group_id", group_id)
	component_dialog.title = "Add %s" % ("Reference" if draw_mode == "reference" else "%s Component" % _draw_mode_display_name(draw_mode))
	component_name_input.text = ""
	_update_component_name_dialog_validation()
	canvas_view.set_navigation_locked(true)
	component_dialog.popup_centered()
	component_name_input.call_deferred("grab_focus")


func _submit_component_name(_name: String) -> void:
	_confirm_component_creation()


func _on_component_name_input_changed(_name: String) -> void:
	_update_component_name_dialog_validation()


func _update_component_name_dialog_validation() -> void:
	if not is_instance_valid(component_name_input) or not is_instance_valid(component_dialog):
		return
	var asset := _get_asset(str(component_dialog.get_meta("asset_id", "")))
	var error := _component_name_validation_error(component_name_input.text, asset)
	component_dialog.get_ok_button().disabled = not error.is_empty()
	if is_instance_valid(component_name_hint):
		component_name_hint.text = "" if error.is_empty() else error
		component_name_hint.add_theme_color_override("font_color", Color("#ef6c78"))


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
	_show_status_message("Created %s." % WorldDocumentService.guide_display_name(asset, guide))
	_invalidate_render(RENDER_DOCUMENT)


func _create_weapon_guide(asset_id: String, scope_kind: String, scope_id: String, guide_type: String) -> void:
	var asset := _get_asset(asset_id)
	var valid_scope := not ComponentHierarchy.group_by_id(asset, scope_id).is_empty() if scope_kind == "group" else not _get_component(asset, scope_id).is_empty()
	if asset.is_empty() or not valid_scope or not AssetGuide.is_weapon_frame(guide_type):
		return
	for existing in asset.get("guides", []):
		if str(existing.get("guide_type", "")) == guide_type:
			_show_status_message("%s already exists on this Asset." % guide_type)
			return
	_record_direct_change()
	var guide_id := "guide_%d" % next_guide_id
	next_guide_id += 1
	asset["guides"].append(AssetGuide.create_weapon_frame(guide_id, guide_type, scope_kind, scope_id))
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_component_ids.clear()
	selected_group_id = ""
	selected_guide_id = guide_id
	active_state = "transform"
	active_draw_tool = ""
	_set_outliner_asset_expanded(asset_id, true)
	_show_status_message("Created %s." % guide_type)
	_invalidate_render(RENDER_DOCUMENT)


func _create_region(asset_id: String, scope_kind: String, scope_id: String, region_type: String) -> void:
	var asset := _get_asset(asset_id)
	var source_component := _get_component(asset, scope_id)
	if asset.is_empty() or scope_kind != "component" or source_component.is_empty() or _is_region(source_component) or region_type not in REGION_TYPES:
		return
	if _is_hole_component(source_component) \
		or (_is_reference_component(source_component) and WorldDocumentService.topology_role(source_component) == WorldDocumentService.ROLE_HOLE):
		_show_status_message("Hole Components cannot own Regions.")
		return
	_record_direct_change()
	var component_id := "component_%d" % next_component_id
	next_component_id += 1
	var base_name := "%s_region" % region_type
	var region_name := base_name
	var suffix := 2
	while _has_component_name(asset, region_name):
		region_name = "%s_%d" % [base_name, suffix]
		suffix += 1
	asset["components"].append({
		"id": component_id, "type": "region", "region_type": region_type, "name": region_name,
		"region_geometry_source": WorldDocumentService.REGION_GEOMETRY_COMPONENT,
		"source_asset_id": "", "parent_component_id": scope_id,
		"group_id": "", "points": [], "edges": [], "chains": [],
		"transform": WorldDocumentService.default_component_transform(), "visibility": true, "z_index": 0,
		"projection_depth_cm": WorldDocumentService.DEFAULT_PROJECTION_DEPTH_CM, "draw_mode": WorldDocumentService.DRAW_MODE_CLOSED_LOOP,
		"topology_role": WorldDocumentService.ROLE_OUTER, "geometry_source": "bezier", "primitive": {},
		"catch_parent_component_id": "", "show_point_numbers": false
	})
	selected_asset_id = asset_id
	selected_component_id = component_id
	selected_component_ids = [component_id]
	selected_group_id = ""
	selected_guide_id = ""
	active_state = ""
	active_draw_tool = ""
	_set_outliner_asset_expanded(asset_id, true)
	_show_status_message("Created %s Region · using Component Geometry." % region_type.capitalize())
	_invalidate_render(RENDER_DOCUMENT)


func _is_region(component: Dictionary) -> bool:
	return WorldDocumentService.is_region(component)


func _region_uses_component_geometry(component: Dictionary) -> bool:
	return WorldDocumentService.region_uses_component_geometry(component)


func _selected_geometry_is_editable() -> bool:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	return not component.is_empty() and not _region_uses_component_geometry(component)


func _component_local_visual_center(component: Dictionary) -> Vector2:
	if PrimitiveGeometryService.has_analytic_shape(component):
		return PrimitiveGeometryService.center(component)
	var polygon := BezierTopology.outer_control_polygon(component)
	if polygon.is_empty():
		return Vector2.ZERO
	var center := Vector2.ZERO
	for point in polygon:
		center += point
	return center / float(polygon.size())


func _duplicate_selected_guide() -> void:
	var asset := _get_asset(selected_asset_id)
	var source := _get_guide(asset, selected_guide_id)
	if asset.is_empty() or source.is_empty():
		return
	_record_direct_change()
	var guide_copy := _duplicate_guide_record(source, asset)
	asset["guides"].append(guide_copy)
	selected_guide_id = str(guide_copy.get("id", ""))
	selected_component_id = ""
	active_state = ""
	_set_outliner_asset_expanded(selected_asset_id, true)
	_show_status_message("Duplicated %s." % WorldDocumentService.guide_display_name(asset, guide_copy))
	_invalidate_render(RENDER_DOCUMENT)


func _open_group_dialog(asset_id: String) -> void:
	var asset := _get_asset(asset_id)
	if asset.is_empty():
		return
	var component_ids := _selected_component_ids_for_group(asset)
	if component_ids.is_empty():
		_show_status_message("Select at least one Component to group.")
		return
	group_dialog.set_meta("asset_id", asset_id)
	group_dialog.set_meta("component_ids", component_ids)
	group_name_input.text = ""
	group_dialog.title = "Group Components"
	group_dialog.dialog_text = "Enter a Group name"
	group_dialog.popup_centered()
	group_dialog.get_ok_button().disabled = true
	group_name_input.call_deferred("grab_focus")


func _selected_component_ids_for_group(asset: Dictionary) -> Array[String]:
	var selected: Array[String] = []
	var candidates: Array[String] = selected_component_ids.duplicate()
	if candidates.is_empty() and not selected_component_id.is_empty():
		candidates.append(selected_component_id)
	for component_id in candidates:
		if _get_component(asset, component_id).is_empty():
			continue
		var parent_id := str(_get_component(asset, component_id).get("parent_component_id", ""))
		if not parent_id.is_empty() and candidates.has(parent_id):
			continue
		selected.append(component_id)
	return selected


func _group_name_validation_error(asset: Dictionary, raw_name: String, excluded_group_id := "") -> String:
	var group_name := raw_name.strip_edges()
	if group_name.is_empty():
		return "Enter a Group name."
	if not _component_name_validation_error(group_name, {"components": []}).is_empty():
		return "Use lower_snake_case for the Group name."
	for group in asset.get("groups", []):
		if str(group.get("id", "")) == excluded_group_id:
			continue
		if str(group.get("name", "")).to_lower() == group_name.to_lower():
			return "Group name must be unique within the Asset."
	return ""


func _confirm_group_creation() -> void:
	var asset_id := str(group_dialog.get_meta("asset_id", ""))
	var asset := _get_asset(asset_id)
	var component_ids: Array = group_dialog.get_meta("component_ids", [])
	var group_name := group_name_input.text.strip_edges()
	var name_error := _group_name_validation_error(asset, group_name)
	if asset.is_empty() or component_ids.is_empty() or not name_error.is_empty():
		if not name_error.is_empty():
			_show_status_message(name_error)
		return
	_record_direct_change()
	var group_id := "group_%d" % next_group_id
	next_group_id += 1
	var center := _group_world_center(asset, component_ids)
	if not asset.has("groups") or not asset.get("groups") is Array:
		asset["groups"] = []
	asset["groups"].append({
		"id": group_id,
		"name": group_name,
		"transform": {"position": center, "rotation": 0.0, "scale": Vector2.ONE, "pivot": center},
		"visibility": true
	})
	for component_id in component_ids:
		var component := _get_component(asset, component_id)
		if not component.is_empty():
			component["group_id"] = group_id
	ComponentHierarchy.canonicalize_redundant_group_membership(asset)
	group_dialog.hide()
	selected_component_ids = component_ids.duplicate()
	selected_component_id = str(component_ids.back())
	_set_outliner_asset_expanded(asset_id, true)
	_invalidate_render(RENDER_DOCUMENT)


func _group_world_center(asset: Dictionary, component_ids: Array) -> Vector2:
	if component_ids.is_empty():
		return Vector2.ZERO
	var center := Vector2.ZERO
	for component_id in component_ids:
		var component := _get_component(asset, str(component_id))
		center += ComponentHierarchy.world_transform(asset, str(component_id)) * _component_local_visual_center(component)
	return center / float(component_ids.size())


func _effective_component_visibility(asset: Dictionary, component: Dictionary) -> bool:
	return WorldDocumentService.component_effectively_visible(asset, component)


func _effective_component_z_index(_asset: Dictionary, component: Dictionary) -> int:
	return int(component.get("z_index", 0))

func _place_selected_group_pivot_at_mouse() -> bool:
	var asset := _get_asset(selected_asset_id)
	var group := ComponentHierarchy.group_by_id(asset, selected_group_id)
	if asset.is_empty() or group.is_empty():
		return false
	_record_coalesced_change()
	var transform: Dictionary = group.get("transform", WorldDocumentService.default_component_transform())
	var old_pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
	var new_pivot := canvas_view.mouse_local_position()
	var transform_scale: Vector2 = transform.get("scale", Vector2.ONE)
	var transform_rotation := deg_to_rad(float(transform.get("rotation", 0.0)))
	var transform_position: Vector2 = transform.get("position", Vector2.ZERO)
	transform_position += ((new_pivot - old_pivot) * transform_scale).rotated(transform_rotation)
	transform["pivot"] = new_pivot
	transform["position"] = transform_position
	group["transform"] = transform
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)
	return true


## The duplicating entries of the Component context menu, as the mode and the
## mirror axis each one stands for. One table answers for both duplicate paths,
## so an axis cannot reach the Component one and miss the Group one - and an id
## that is not a duplicate action returns nothing rather than falling through
## into one, which the old chain of ternaries did.
func _duplicate_mirror_action(action_id: int) -> Dictionary:
	match action_id:
		0:
			return {"mode": "none", "axis": ComponentCanvas.MIRROR_AXIS_VERTICAL}
		1:
			return {"mode": "keep_orientation", "axis": ComponentCanvas.MIRROR_AXIS_VERTICAL}
		2:
			return {"mode": "flip_orientation", "axis": ComponentCanvas.MIRROR_AXIS_VERTICAL}
		8:
			return {"mode": "keep_orientation", "axis": ComponentCanvas.MIRROR_AXIS_HORIZONTAL}
		9:
			return {"mode": "flip_orientation", "axis": ComponentCanvas.MIRROR_AXIS_HORIZONTAL}
	return {}


## Which coordinate a mirror reflects: across the vertical axis - the menu's
## Mirror Y - it is X, and across the horizontal axis it is Y. The transform, the
## Group scale normalization and the visual centre all ask here, so they cannot
## disagree about which axis they are working on.
func _mirror_reflects_x(mirror_axis: String) -> bool:
	return mirror_axis != ComponentCanvas.MIRROR_AXIS_HORIZONTAL


func _on_component_context_menu_selected(action_id: int) -> void:
	if not is_instance_valid(component_context_menu):
		return
	var asset_id := str(component_context_menu.get_meta("asset_id", ""))
	var component_id := str(component_context_menu.get_meta("component_id", ""))
	var group_id := str(component_context_menu.get_meta("group_id", ""))
	if action_id == 6:
		_copy_selected_component_subtrees(asset_id)
		return
	if action_id == 7:
		if group_id.is_empty():
			_paste_component_clipboard(asset_id, component_id)
		return
	if action_id == 4:
		_open_group_dialog(asset_id)
		return
	if action_id == 5:
		var selected_ids := _selected_component_ids_for_group(_get_asset(asset_id))
		if selected_ids.is_empty() and not component_id.is_empty():
			selected_ids = [component_id]
		if selected_ids.is_empty():
			return
		_record_direct_change()
		var asset := _get_asset(asset_id)
		for selected_id in selected_ids:
			_set_component_group_preserving_world(asset, str(selected_id), "")
		selected_asset_id = asset_id
		selected_group_id = ""
		selected_component_ids = selected_ids.duplicate()
		selected_component_id = str(selected_ids.back())
		_invalidate_render(RENDER_DOCUMENT)
		_show_status_message("Removed %d Component%s from Group." % [selected_ids.size(), "" if selected_ids.size() == 1 else "s"])
		return
	var mirror_action := _duplicate_mirror_action(action_id)
	if not group_id.is_empty() and not mirror_action.is_empty():
		_duplicate_group(asset_id, group_id, str(mirror_action["mode"]), str(mirror_action["axis"]))
		return
	if action_id == 3:
		_detach_component(asset_id, component_id)
		return
	if not mirror_action.is_empty():
		_duplicate_component(asset_id, component_id, str(mirror_action["mode"]), str(mirror_action["axis"]))


func _selected_component_ids_for_clipboard(asset: Dictionary) -> Array[String]:
	if asset.is_empty() or selected_asset_id != str(asset.get("id", "")):
		return []
	var selected_ids: Array[String] = []
	for component_id_value in selected_component_ids:
		var component_id := str(component_id_value)
		if not component_id.is_empty() and not _get_component(asset, component_id).is_empty() and not selected_ids.has(component_id):
			selected_ids.append(component_id)
	if selected_ids.is_empty() and not selected_component_id.is_empty() and not _get_component(asset, selected_component_id).is_empty():
		selected_ids.append(selected_component_id)
	return selected_ids


func _copy_selected_component_subtrees(source_asset_id := "") -> void:
	var asset_id := source_asset_id if not source_asset_id.is_empty() else selected_asset_id
	var asset := _get_asset(asset_id)
	var selected_ids := _selected_component_ids_for_clipboard(asset)
	if selected_ids.is_empty():
		_show_status_message("Select one or more Components to copy.")
		return
	var selected_id_set: Dictionary = {}
	for component_id in selected_ids:
		selected_id_set[component_id] = true
	var root_ids: Array[String] = []
	for component_id in selected_ids:
		var parent_id := str(_get_component(asset, component_id).get("parent_component_id", ""))
		if not selected_id_set.has(parent_id):
			root_ids.append(component_id)
	var copied_components: Array[Dictionary] = []
	var copied_id_set: Dictionary = {}
	for root_id in root_ids:
		var root := _get_component(asset, root_id)
		copied_components.append(root.duplicate(true))
		copied_id_set[root_id] = true
		for descendant in ComponentHierarchy.descendants(asset, root_id):
			var descendant_id := str(descendant.get("id", ""))
			if not copied_id_set.has(descendant_id):
				copied_components.append(descendant.duplicate(true))
				copied_id_set[descendant_id] = true
	var copied_guides: Array[Dictionary] = []
	for guide in asset.get("guides", []):
		if guide is Dictionary and copied_id_set.has(AssetGuide.scope_component_id(guide)):
			copied_guides.append(guide.duplicate(true))
	component_clipboard = {
		"source_asset_id": asset_id,
		"root_ids": root_ids,
		"components": copied_components,
		"guides": copied_guides
	}
	_show_status_message("Copied %d Component%s." % [root_ids.size(), "" if root_ids.size() == 1 else "s"])


func _paste_component_clipboard(target_asset_id: String, target_parent_id := "") -> void:
	var target_asset := _get_asset(target_asset_id)
	if target_asset.is_empty() or component_clipboard.is_empty():
		return
	if not target_parent_id.is_empty():
		var target_parent := _get_component(target_asset, target_parent_id)
		if target_parent.is_empty():
			_show_status_message("Paste target is no longer available.")
			return
		if _is_hole_component(target_parent):
			_show_status_message("Cannot paste Components beneath a Hole constraint.")
			return
	var source_components: Array = component_clipboard.get("components", [])
	var source_root_ids: Array = component_clipboard.get("root_ids", [])
	if source_components.is_empty() or source_root_ids.is_empty():
		return
	var source_id_set: Dictionary = {}
	for source_component in source_components:
		if source_component is Dictionary:
			source_id_set[str(source_component.get("id", ""))] = true
	var id_map: Dictionary = {}
	_record_direct_change()
	for source_component in source_components:
		if not source_component is Dictionary:
			continue
		var new_id := "component_%d" % next_component_id
		next_component_id += 1
		id_map[str(source_component.get("id", ""))] = new_id
	var pasted_root_ids: Array[String] = []
	for source_component in source_components:
		if not source_component is Dictionary:
			continue
		var source_id := str(source_component.get("id", ""))
		var component_copy := _duplicate_component_record(source_component, target_asset, str(id_map[source_id]))
		component_copy["name"] = _next_pasted_component_name(target_asset, str(source_component.get("name", "Component")))
		component_copy["group_id"] = ""
		var source_parent_id := str(source_component.get("parent_component_id", ""))
		component_copy["parent_component_id"] = str(id_map.get(source_parent_id, target_parent_id)) if source_id_set.has(source_parent_id) else target_parent_id
		target_asset["components"].append(component_copy)
		if source_root_ids.has(source_id):
			pasted_root_ids.append(str(component_copy.get("id", "")))
	for source_guide in component_clipboard.get("guides", []):
		if not source_guide is Dictionary:
			continue
		var source_component_id := AssetGuide.scope_component_id(source_guide)
		if not id_map.has(source_component_id):
			continue
		var guide_copy := _duplicate_guide_record(source_guide, target_asset)
		var scope: Dictionary = guide_copy.get("scope", {}).duplicate(true)
		scope["component_id"] = str(id_map[source_component_id])
		guide_copy["scope"] = scope
		guide_copy["ordinal"] = ComponentHierarchy.next_guide_ordinal(target_asset, str(id_map[source_component_id]), str(guide_copy.get("guide_type", AssetGuide.SAMPLE)))
		target_asset["guides"].append(guide_copy)
	selected_asset_id = target_asset_id
	selected_component_ids = pasted_root_ids.duplicate()
	selected_component_id = str(pasted_root_ids.back())
	selected_group_id = ""
	selected_guide_id = ""
	active_state = ""
	_set_outliner_asset_expanded(target_asset_id, true)
	_show_status_message("Pasted %d Component%s." % [pasted_root_ids.size(), "" if pasted_root_ids.size() == 1 else "s"])
	_invalidate_render(RENDER_DOCUMENT)


func _next_pasted_component_name(asset: Dictionary, source_name: String) -> String:
	var candidate := source_name.strip_edges()
	if candidate.is_empty():
		candidate = "component"
	return candidate if not _has_component_name(asset, candidate) else _next_duplicate_component_name(asset, candidate)


func _duplicate_group(asset_id: String, group_id: String, mirror_mode := "none", mirror_axis := ComponentCanvas.MIRROR_AXIS_VERTICAL) -> void:
	var asset := _get_asset(asset_id)
	var source_group := ComponentHierarchy.group_by_id(asset, group_id)
	if asset.is_empty() or source_group.is_empty():
		return
	var roots: Array[Dictionary] = []
	for component in asset.get("components", []):
		if str(component.get("group_id", "")) != group_id:
			continue
		var parent_id := str(component.get("parent_component_id", ""))
		if parent_id.is_empty() or ComponentHierarchy.membership_group_id(asset, parent_id) != group_id:
			roots.append(component)
	var source_tree: Array[Dictionary] = []
	for root in roots:
		source_tree.append(root)
		for descendant in ComponentHierarchy.descendants(asset, str(root.get("id", ""))):
			if ComponentHierarchy.membership_group_id(asset, str(descendant.get("id", ""))) == group_id:
				source_tree.append(descendant)
	if source_tree.is_empty():
		return
	_record_direct_change()
	var new_group_id := "group_%d" % next_group_id
	next_group_id += 1
	var group_copy := source_group.duplicate(true)
	group_copy["id"] = new_group_id
	group_copy["name"] = _next_duplicate_group_name(asset, str(source_group.get("name", "Group")))
	asset["groups"].append(group_copy)
	if mirror_mode != "none":
		# The copy still carries the source's transform, so its world frame is
		# the source's - the one the origin's axis has to reflect.
		group_copy["transform"] = _mirrored_group_transform(asset, new_group_id, mirror_mode, mirror_axis)
	var id_map: Dictionary = {}
	var duplicated_component_ids: Array[String] = []
	for source_node in source_tree:
		var new_id := "component_%d" % next_component_id
		next_component_id += 1
		id_map[str(source_node.get("id", ""))] = new_id
	for source_node in source_tree:
		var source_id := str(source_node.get("id", ""))
		var component_copy := _duplicate_component_record(source_node, asset, str(id_map[source_id]))
		component_copy["name"] = _next_duplicate_component_name(asset, str(source_node.get("name", "Component")))
		component_copy["group_id"] = new_group_id if str(source_node.get("group_id", "")) == group_id else ""
		component_copy["parent_component_id"] = str(id_map.get(str(source_node.get("parent_component_id", "")), source_node.get("parent_component_id", "")))
		asset["components"].append(component_copy)
		duplicated_component_ids.append(str(component_copy.get("id", "")))
	if mirror_mode == "flip_orientation":
		var mirrored_world_records: Dictionary = {}
		for duplicated_id in duplicated_component_ids:
			mirrored_world_records[duplicated_id] = ComponentHierarchy.world_transform_record(asset, duplicated_id)
		var normalized_group_transform: Dictionary = group_copy.get("transform", WorldDocumentService.default_component_transform()).duplicate(true)
		var normalized_group_scale: Vector2 = normalized_group_transform.get("scale", Vector2.ONE)
		if _mirror_reflects_x(mirror_axis):
			normalized_group_scale.x = absf(normalized_group_scale.x)
		else:
			normalized_group_scale.y = absf(normalized_group_scale.y)
		normalized_group_transform["scale"] = normalized_group_scale
		group_copy["transform"] = normalized_group_transform
		for duplicated_id in duplicated_component_ids:
			var duplicated_component := ComponentHierarchy.component_by_id(asset, duplicated_id)
			var duplicated_parent_id := str(duplicated_component.get("parent_component_id", ""))
			if not duplicated_parent_id.is_empty() and duplicated_component_ids.has(duplicated_parent_id):
				continue
			duplicated_component["transform"] = ComponentHierarchy.local_transform_from_world_record(asset, duplicated_id, mirrored_world_records[duplicated_id])
		var rebase_result := ComponentScaleRebaseService.rebase_components(asset, duplicated_component_ids)
		if not bool(rebase_result.get("valid", false)):
			for duplicated_id in duplicated_component_ids:
				asset["components"].erase(ComponentHierarchy.component_by_id(asset, duplicated_id))
			asset["groups"].erase(group_copy)
			_show_status_message("Mirrored Group was not created: %s" % str(rebase_result.get("errors", ["Unknown error"])[0]))
			_invalidate_render(RENDER_DOCUMENT)
			return
	selected_asset_id = asset_id
	selected_group_id = new_group_id
	selected_component_id = ""
	selected_component_ids.clear()
	selected_guide_id = ""
	_set_outliner_asset_expanded(asset_id, true)
	_show_status_message("Duplicated Group %s." % str(group_copy.get("name", "Group")))
	_invalidate_render(RENDER_DOCUMENT)


func _next_duplicate_group_name(asset: Dictionary, source_name: String) -> String:
	var base_name := source_name.strip_edges() + "_copy"
	if base_name.is_empty():
		base_name = "group_copy"
	var candidate := base_name
	var suffix := 2
	while not _group_name_validation_error(asset, candidate).is_empty():
		candidate = "%s_%d" % [base_name, suffix]
		suffix += 1
	return candidate


## The reflection about an origin axis, expressed in Asset space.
##
## The axis the Canvas draws belongs to the previewed Asset - the one its root
## Position and Scale place it at - while Component transforms live in Asset
## space, which the root transform still has to be applied to. Reflecting in
## Asset space therefore mirrors about an axis nobody can see: with a root
## Position of -6.4 the copy came out 12.8 below where the drawn axis says,
## twice the offset, because a reflection doubles whatever the axis is off by.
## Conjugating the reflection with the root transform makes the drawn axis the
## axis.
func _mirror_reflection(asset: Dictionary, mirror_axis: String) -> Transform2D:
	var axis_reflection := Transform2D(Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2.ZERO)
	if _mirror_reflects_x(mirror_axis):
		axis_reflection = Transform2D(Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2.ZERO)
	var root := AssetScaleRebaseService.root_transform(asset)
	return root.affine_inverse() * axis_reflection * root


## Where a mirrored copy stands in world space.
##
## The axis is the Asset origin's, never the Parent's. Reflecting a Parent-local
## position mirrors about whatever the Parent, the Group or a moved Asset root
## happens to sit at, so a Component nested under any of them landed at the
## wrong distance - the further its Parent was from the origin, the further off
## the copy. Reflecting the world frame and converting it back under the
## unchanged Parent puts the copy where the origin's axis says, whatever sits
## above it in the hierarchy.
##
## Flip reflects the whole frame; Keep leaves it alone and only carries the
## drawing's centre across the axis, which is what keeps the copy upright.
func _mirrored_world_affine(asset: Dictionary, component: Dictionary, component_id: String, mirror_mode: String, mirror_axis: String) -> Transform2D:
	var reflection := _mirror_reflection(asset, mirror_axis)
	var world_affine := ComponentHierarchy.world_transform(asset, component_id)
	if mirror_mode == "flip_orientation":
		return reflection * world_affine
	var world_center := world_affine * _component_local_bounds_center(component)
	var moved := world_affine
	moved.origin += (reflection * world_center) - world_center
	return moved


## Same frame, read with the minus sign on the axis that was actually reflected.
##
## Decomposing a reflected frame is ambiguous: the sign can sit on either scale
## axis, and the two readings differ by a half turn. ComponentHierarchy always
## puts it on Y, which would report a Component mirrored across the Y axis as
## rotated 160 degrees with a flipped Y rather than -20 with a flipped X - the
## same picture, an Inspector nobody can read.
func _readable_mirrored_record(record: Dictionary, mirror_axis: String) -> Dictionary:
	if not _mirror_reflects_x(mirror_axis) or Vector2(record.get("scale", Vector2.ONE)).y >= 0.0:
		return record
	var readable := record.duplicate(true)
	readable["scale"] = -Vector2(record.get("scale", Vector2.ONE))
	readable["rotation"] = wrapf(float(record.get("rotation", 0.0)) + 180.0, -180.0, 180.0)
	return readable


## A Group mirrors about the same origin axis a Component does. Keep carries the
## Group's own Position across it and leaves the members where they sit relative
## to each other; Flip reflects the whole frame with them.
func _mirrored_group_transform(asset: Dictionary, group_id: String, mirror_mode: String, mirror_axis: String) -> Dictionary:
	var reflection := _mirror_reflection(asset, mirror_axis)
	var world_affine := ComponentHierarchy.group_world_transform(asset, group_id)
	var pivot := Vector2(ComponentHierarchy.group_by_id(asset, group_id).get("transform", {}).get("pivot", Vector2.ZERO))
	var mirrored_world := world_affine
	if mirror_mode == "flip_orientation":
		mirrored_world = reflection * world_affine
	else:
		var world_position := world_affine * pivot
		mirrored_world.origin += (reflection * world_position) - world_position
	var mirrored_record := ComponentHierarchy.transform_record_from_affine(mirrored_world, pivot)
	return _readable_mirrored_record(
		ComponentHierarchy.group_local_transform_from_world_record(asset, group_id, mirrored_record), mirror_axis)


func _duplicate_component(asset_id: String, component_id: String, mirror_mode := "none", mirror_axis := ComponentCanvas.MIRROR_AXIS_VERTICAL) -> void:
	var asset := _get_asset(asset_id)
	var source := _get_component(asset, component_id)
	if asset.is_empty() or source.is_empty():
		return
	var source_tree: Array[Dictionary] = [source]
	for descendant in ComponentHierarchy.descendants(asset, component_id):
		source_tree.append(descendant)
	_record_direct_change()
	var id_map: Dictionary = {}
	var duplicated_component_ids: Array[String] = []
	for source_node in source_tree:
		var new_id := "component_%d" % next_component_id
		next_component_id += 1
		id_map[str(source_node.get("id", ""))] = new_id
	var duplicate_root: Dictionary = {}
	for source_node in source_tree:
		var source_node_id := str(source_node.get("id", ""))
		var component_copy := _duplicate_component_record(source_node, asset, str(id_map[source_node_id]))
		component_copy["name"] = _next_duplicate_component_name(asset, str(source_node.get("name", "Component")))
		var source_parent_id := str(source_node.get("parent_component_id", ""))
		component_copy["parent_component_id"] = str(id_map.get(source_parent_id, source_parent_id))
		asset["components"].append(component_copy)
		duplicated_component_ids.append(str(component_copy.get("id", "")))
		if source_node_id == component_id:
			duplicate_root = component_copy
	if mirror_mode != "none":
		# Only the subtree root moves; the Children follow it through their own
		# unchanged local transforms, which is what mirrors the whole subtree.
		var duplicate_root_id := str(duplicate_root.get("id", ""))
		var mirrored_world := _mirrored_world_affine(asset, duplicate_root, duplicate_root_id, mirror_mode, mirror_axis)
		var root_pivot := Vector2(duplicate_root.get("transform", {}).get("pivot", Vector2.ZERO))
		var mirrored_record := ComponentHierarchy.transform_record_from_affine(mirrored_world, root_pivot)
		duplicate_root["transform"] = _readable_mirrored_record(
			ComponentHierarchy.local_transform_from_world_record(asset, duplicate_root_id, mirrored_record), mirror_axis)
	if mirror_mode == "flip_orientation":
		var rebase_result := ComponentScaleRebaseService.rebase_components(asset, duplicated_component_ids)
		if not bool(rebase_result.get("valid", false)):
			for duplicated_id in duplicated_component_ids:
				asset["components"].erase(ComponentHierarchy.component_by_id(asset, duplicated_id))
			_show_status_message("Mirrored Component was not created: %s" % str(rebase_result.get("errors", ["Unknown error"])[0]))
			_invalidate_render(RENDER_DOCUMENT)
			return
	selected_asset_id = asset_id
	selected_component_id = str(duplicate_root.get("id", ""))
	selected_guide_id = ""
	selected_point_id = ""
	selected_point_ids.clear()
	selected_edge_id = ""
	active_state = ""
	_set_outliner_asset_expanded(asset_id, true)
	_show_status_message("Duplicated %s subtree." % str(duplicate_root.get("name", "Component")) if source_tree.size() > 1 else "Duplicated %s." % str(duplicate_root.get("name", "Component")))
	_invalidate_render(RENDER_DOCUMENT)


func _next_duplicate_component_name(asset: Dictionary, source_name: String) -> String:
	var base_name := source_name.strip_edges() + " Copy"
	if base_name.strip_edges().is_empty():
		base_name = "Component Copy"
	var candidate := base_name
	var suffix := 2
	while _has_component_name(asset, candidate):
		candidate = "%s %d" % [base_name, suffix]
		suffix += 1
	return candidate


func _duplicate_component_record(source: Dictionary, _asset: Dictionary, forced_id := "") -> Dictionary:
	var component_copy := source.duplicate(true)
	component_copy["id"] = forced_id if not forced_id.is_empty() else "component_%d" % next_component_id
	if forced_id.is_empty():
		next_component_id += 1
	component_copy["name"] = str(source.get("name", "Component"))
	# The duplicated Component stays beside its source: same Parent, no copied
	# descendants, and no copied Guides.
	component_copy["parent_component_id"] = str(source.get("parent_component_id", ""))
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
	component_copy["points"] = new_points
	component_copy["edges"] = new_edges
	component_copy["chains"] = new_chains
	BezierGeometry.resolve_auto_handles(new_points, new_chains)
	return component_copy


## The middle of the box a Component's own drawing spans, in the Component's own
## space. Parent space and world space are this one point carried through a
## transform, so everything that mirrors, measures or places from "the middle of
## the shape" means the same point.
func _component_local_bounds_center(component: Dictionary) -> Vector2:
	var points: Array = component.get("points", [])
	if points.is_empty() and PrimitiveGeometryService.has_analytic_shape(component):
		var primitive_contour := PrimitiveGeometryService.contour(component)
		if not primitive_contour.is_empty():
			var primitive_minimum := Vector2(INF, INF)
			var primitive_maximum := Vector2(-INF, -INF)
			for primitive_point in primitive_contour:
				primitive_minimum.x = minf(primitive_minimum.x, primitive_point.x)
				primitive_minimum.y = minf(primitive_minimum.y, primitive_point.y)
				primitive_maximum.x = maxf(primitive_maximum.x, primitive_point.x)
				primitive_maximum.y = maxf(primitive_maximum.y, primitive_point.y)
			return (primitive_minimum + primitive_maximum) * 0.5
	if points.is_empty():
		# Without geometry there is no box, and the Pivot is the one point the
		# Component still stands for - it is what the local transform carries to
		# the Component's Position.
		return Vector2(component.get("transform", {}).get("pivot", Vector2.ZERO))
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point in points:
		var point_position: Vector2 = point.get("position", Vector2.ZERO)
		minimum.x = minf(minimum.x, point_position.x)
		minimum.y = minf(minimum.y, point_position.y)
		maximum.x = maxf(maximum.x, point_position.x)
		maximum.y = maxf(maximum.y, point_position.y)
	return (minimum + maximum) * 0.5


func _component_visual_center_in_parent_space(component: Dictionary) -> Vector2:
	return ComponentHierarchy.local_transform(component.get("transform", {})) * _component_local_bounds_center(component)


func _duplicate_guide_record(source: Dictionary, asset: Dictionary) -> Dictionary:
	var guide_copy := source.duplicate(true)
	var guide_id := "guide_%d" % next_guide_id
	next_guide_id += 1
	guide_copy["id"] = guide_id
	guide_copy["ordinal"] = ComponentHierarchy.next_guide_ordinal(asset, AssetGuide.scope_component_id(source), str(source.get("guide_type", AssetGuide.SAMPLE)))
	var base_name := str(source.get("name", AssetGuide.display_name(str(source.get("guide_type", AssetGuide.SAMPLER_SPINE))))) + " Copy"
	var candidate := base_name
	var suffix := 2
	var existing_names: Dictionary = {}
	for guide in asset.get("guides", []):
		existing_names[str(guide.get("name", "")).to_lower()] = true
	while existing_names.has(candidate.to_lower()):
		candidate = "%s %d" % [base_name, suffix]
		suffix += 1
	guide_copy["name"] = candidate
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
	guide_copy["points"] = new_points
	guide_copy["edges"] = new_edges
	guide_copy["chains"] = new_chains
	return AssetGuide.normalize(guide_copy)


func _confirm_component_creation() -> void:
	var asset_id := str(component_dialog.get_meta("asset_id", ""))
	var asset := _get_asset(asset_id)
	if asset.is_empty():
		component_dialog.hide()
		canvas_view.set_navigation_locked(false)
		return
	var component_name := component_name_input.text.strip_edges()
	if component_name.is_empty():
		component_name = _next_default_component_name(asset)
	var name_error := _component_name_validation_error(component_name, asset)
	if not name_error.is_empty():
		_update_component_name_dialog_validation()
		_show_status_message(name_error)
		return
	var draw_mode := str(component_dialog.get_meta("draw_mode", WorldDocumentService.DRAW_MODE_CLOSED_LOOP))
	var is_reference := draw_mode == "reference"
	var parent_component_id := str(component_dialog.get_meta("parent_component_id", ""))
	var target_group_id := str(component_dialog.get_meta("group_id", ""))
	if not target_group_id.is_empty() and ComponentHierarchy.group_by_id(asset, target_group_id).is_empty():
		target_group_id = ""
	if not parent_component_id.is_empty():
		var parent_component := _get_component(asset, parent_component_id)
		if parent_component.is_empty():
			parent_component_id = ""
		elif _is_hole_component(parent_component):
			component_dialog.hide()
			canvas_view.set_navigation_locked(false)
			_show_status_message("Cannot create a Component beneath a Hole constraint.")
			return
	_record_direct_change()
	var component_id := "component_%d" % next_component_id
	next_component_id += 1
	var component_transform := WorldDocumentService.default_component_transform()
	if not parent_component_id.is_empty():
		var parent_component := _get_component(asset, parent_component_id)
		var parent_transform := WorldDocumentService.deserialize_transform(parent_component.get("transform", {}))
		var inherited_pivot: Vector2 = parent_transform.get("pivot", Vector2.ZERO)
		# Local child position is the Parent-local point that maps to the Parent pivot.
		component_transform["position"] = inherited_pivot
		component_transform["pivot"] = inherited_pivot
	var component := {
		"id": component_id,
		"type": "reference" if is_reference else "component",
		"name": component_name,
		"source_asset_id": str(component_dialog.get_meta("source_asset_id", "")) if is_reference else "",
		"parent_component_id": parent_component_id,
		"group_id": target_group_id,
		"points": [],
		"edges": [],
		"chains": [],
		"transform": component_transform,
		"visibility": true,
		"z_index": 0,
		"projection_depth_cm": WorldDocumentService.DEFAULT_PROJECTION_DEPTH_CM,
		"draw_mode": draw_mode if draw_mode in WorldDocumentService.DRAW_MODES else WorldDocumentService.DRAW_MODE_CLOSED_LOOP,
		"topology_role": WorldDocumentService.ROLE_OUTER,
		"geometry_source": "primitive" if draw_mode == WorldDocumentService.DRAW_MODE_PRIMITIVE else "bezier",
		"primitive": {},
		"catch_parent_component_id": "",
		"show_point_numbers": false
	}
	asset["components"].append(component)
	selected_asset_id = asset_id
	selected_component_id = component_id
	selected_guide_id = ""
	active_state = ""
	_set_outliner_asset_expanded(asset_id, true)
	component_dialog.hide()
	canvas_view.set_navigation_locked(false)
	_invalidate_render(RENDER_DOCUMENT)


func _next_default_component_name(asset: Dictionary) -> String:
	var index := 1
	while _has_component_name(asset, "component%02d" % index):
		index += 1
	return "component%02d" % index


func _has_component_name(asset: Dictionary, component_name: String, excluded_component_id := "") -> bool:
	for component in asset.get("components", []):
		if str(component.get("id", "")) == excluded_component_id:
			continue
		if str(component.get("name", "")).strip_edges().to_lower() == component_name.to_lower():
			return true
	return false


func _component_name_validation_error(raw_name: String, asset: Dictionary, excluded_component_id := "") -> String:
	var component_name := raw_name.strip_edges()
	if component_name.is_empty():
		return "Enter a Component name."
	if component_name.begins_with("_") or component_name.ends_with("_") or component_name.contains("__"):
		return "Use lower_snake_case, e.g. weapon_head_left."
	for character in component_name:
		var code := character.unicode_at(0)
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			return "Use lower_snake_case, e.g. weapon_head_left."
	if component_name.unicode_at(0) >= 48 and component_name.unicode_at(0) <= 57:
		return "Component names must start with a lowercase letter."
	for component in asset.get("components", []):
		if str(component.get("id", "")) == excluded_component_id:
			continue
		if str(component.get("name", "")).strip_edges().to_lower() == component_name.to_lower():
			return "Component name must be unique within the Asset."
	return ""


func _select_component(asset_id: String, component_id: String, focus_outliner := false) -> void:
	_stop_guide_draw_state()
	_set_active_context_command("")
	active_module = "Create"
	# Keep the asset's Create database view when selecting a component.  Passing
	# the generic "Asset" label here normalizes to Character and hides Symbols
	# (and the other non-character asset types) from the Outliner.
	_set_create_submodule_context(_create_submodule_for_asset(asset_id))
	var additive_selection := focus_outliner and (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META))
	if additive_selection:
		if selected_asset_id != asset_id:
			selected_component_ids.clear()
		if selected_component_ids.is_empty() and not selected_component_id.is_empty():
			selected_component_ids.append(selected_component_id)
		if selected_component_ids.has(component_id):
			selected_component_ids.erase(component_id)
		else:
			selected_component_ids.append(component_id)
		if selected_component_ids.is_empty():
			selected_component_id = ""
		else:
			selected_component_id = selected_component_ids.back()
	else:
		selected_component_ids = [component_id]
		selected_component_id = component_id
	selected_asset_id = asset_id
	selected_group_id = ""
	selected_guide_id = ""
	selected_edge_id = ""
	selected_point_id = ""
	selected_point_ids.clear()
	outliner_component_navigation_active = focus_outliner
	active_state = ""
	canvas_view.set_interaction_state("")
	_set_outliner_asset_expanded(asset_id, true)
	_invalidate_render(RENDER_DOCUMENT)
	if is_instance_valid(canvas_view) and canvas_view.is_inside_tree():
		canvas_view.grab_focus()


func _select_guide(asset_id: String, guide_id: String) -> void:
	_stop_guide_draw_state()
	_set_active_context_command("")
	var guide := _get_guide(_get_asset(asset_id), guide_id)
	if guide.is_empty():
		return
	if active_module == "Mesh" and active_geometry_submodule == "Sampling":
		var parent_component_id := AssetGuide.scope_component_id(guide)
		if not _get_component(_get_asset(asset_id), parent_component_id).is_empty():
			selected_asset_id = asset_id
			selected_component_id = parent_component_id
			selected_guide_id = guide_id
			selected_seeding_input_id = guide_id
			_set_sampling_input(asset_id, guide_id, "guide")
			selected_edge_id = ""
			selected_point_id = ""
			selected_point_ids.clear()
			active_state = ""
			_set_outliner_asset_expanded(asset_id, true)
			_invalidate_render(RENDER_DOCUMENT)
			return
	active_module = "Create"
	_set_create_submodule_context(_create_submodule_for_asset(asset_id))
	selected_asset_id = asset_id
	selected_component_id = ""
	selected_component_ids.clear()
	selected_group_id = ""
	selected_guide_id = guide_id
	selected_seeding_input_id = ""
	_set_sampling_input(asset_id, "", "")
	selected_edge_id = ""
	selected_point_id = ""
	selected_point_ids.clear()
	active_state = ""
	_set_outliner_asset_expanded(asset_id, true)
	_invalidate_render(RENDER_DOCUMENT)


func _delete_selected_component() -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty():
		return
	var root_component_ids := _selected_component_ids_for_group(asset)
	if root_component_ids.is_empty():
		return
	pending_component_remove_asset_id = selected_asset_id
	pending_component_remove_ids = root_component_ids.duplicate()
	pending_component_remove_group_id = ""
	var removed_component_ids := _component_deletion_set(asset, root_component_ids)
	var removed_guide_count := 0
	for guide in asset.get("guides", []):
		if removed_component_ids.has(AssetGuide.scope_component_id(guide)):
			removed_guide_count += 1
	var component_count := removed_component_ids.size()
	var description := ""
	if root_component_ids.size() == 1:
		var component := _get_component(asset, root_component_ids[0])
		description = "Delete Component ‘%s’" % str(component.get("name", "Component"))
		if component_count > 1:
			description += " and %d Child Components" % (component_count - 1)
	else:
		description = "Delete %d Components" % component_count
	if removed_guide_count > 0:
		description += " plus %d Guide%s" % [removed_guide_count, "s" if removed_guide_count != 1 else ""]
	description += "? This cannot be undone except through Undo."
	if is_instance_valid(component_remove_dialog):
		component_remove_dialog.title = "Delete Component" if root_component_ids.size() == 1 else "Delete Components"
		component_remove_dialog.dialog_text = description
		component_remove_dialog.popup_centered()
	else:
		_confirm_component_deletion()


func _component_deletion_set(asset: Dictionary, root_component_ids: Array[String]) -> Dictionary:
	var removed_component_ids: Dictionary = {}
	for component_id in root_component_ids:
		if _get_component(asset, component_id).is_empty():
			continue
		removed_component_ids[component_id] = true
		for descendant in ComponentHierarchy.descendants(asset, component_id):
			removed_component_ids[str(descendant.get("id", ""))] = true
	return removed_component_ids


func _confirm_component_deletion() -> void:
	var asset := _get_asset(pending_component_remove_asset_id)
	var root_component_ids := pending_component_remove_ids.duplicate()
	var removed_group_id := pending_component_remove_group_id
	pending_component_remove_asset_id = ""
	pending_component_remove_ids.clear()
	pending_component_remove_group_id = ""
	if asset.is_empty():
		return
	var removed_component_ids := _component_deletion_set(asset, root_component_ids)
	# An empty Group still has itself to delete, so only a deletion that would
	# remove nothing at all stops here.
	if removed_component_ids.is_empty() and removed_group_id.is_empty():
		return
	_record_direct_change()
	if not removed_group_id.is_empty():
		var removed_group := ComponentHierarchy.group_by_id(asset, removed_group_id)
		if not removed_group.is_empty():
			asset["groups"].erase(removed_group)
		var kept_guides: Array = []
		for guide in asset.get("guides", []):
			if guide is Dictionary and AssetGuide.is_group_scoped(guide) and AssetGuide.scope_group_id(guide) == removed_group_id:
				continue
			kept_guides.append(guide)
		asset["guides"] = kept_guides
		selected_group_id = ""
	var surviving_components: Array = []
	for existing_component in asset.get("components", []):
		if not removed_component_ids.has(str(existing_component.get("id", ""))):
			surviving_components.append(existing_component)
	asset["components"] = surviving_components
	var surviving_guides: Array = []
	for guide in asset.get("guides", []):
		if not removed_component_ids.has(AssetGuide.scope_component_id(guide)):
			surviving_guides.append(guide)
	asset["guides"] = surviving_guides
	for surviving_component in surviving_components:
		if removed_component_ids.has(str(surviving_component.get("catch_parent_component_id", ""))):
			surviving_component["catch_parent_component_id"] = ""
	selected_component_id = ""
	selected_component_ids.clear()
	selected_guide_id = ""
	active_state = ""
	_invalidate_render(RENDER_DOCUMENT)


func _delete_current_outliner_selection() -> void:
	if active_module == "Style" and active_style_submodule == "Weighting":
		if not selected_weighting_style_id.is_empty():
			_delete_selected_weighting_style()
		return
	if not selected_group_id.is_empty():
		_delete_selected_group()
	elif not selected_guide_id.is_empty():
		_delete_selected_guide()
	elif not selected_component_id.is_empty():
		_delete_selected_component()
	elif not selected_asset_id.is_empty():
		_delete_selected_asset()


# Deleting a Group deletes the Group: the record, its Guides and every
# Component inside it, Children included. Releasing the members instead is a
# separate action - "Remove from Group" keeps each one exactly where it is -
# so the destructive reading is the one the delete command carries, and it
# asks first, through the same confirmation the Component delete uses.
func _delete_selected_group() -> void:
	var asset := _get_asset(selected_asset_id)
	var group := ComponentHierarchy.group_by_id(asset, selected_group_id)
	if asset.is_empty() or group.is_empty():
		return
	var member_roots: Array[String] = []
	for member in ComponentHierarchy.direct_group_members(asset, selected_group_id):
		var member_id := str(member.get("id", ""))
		if not member_id.is_empty():
			member_roots.append(member_id)
	pending_component_remove_asset_id = selected_asset_id
	pending_component_remove_ids = member_roots.duplicate()
	pending_component_remove_group_id = selected_group_id
	var removed_component_ids := _component_deletion_set(asset, member_roots)
	var removed_guide_count := 0
	for guide in asset.get("guides", []):
		if not guide is Dictionary:
			continue
		if AssetGuide.is_group_scoped(guide):
			if AssetGuide.scope_group_id(guide) == selected_group_id:
				removed_guide_count += 1
		elif removed_component_ids.has(AssetGuide.scope_component_id(guide)):
			removed_guide_count += 1
	var description := "Delete Group ‘%s’" % str(group.get("name", "Group"))
	if removed_component_ids.size() > 0:
		description += " and %d Component%s" % [removed_component_ids.size(), "s" if removed_component_ids.size() != 1 else ""]
	if removed_guide_count > 0:
		description += " plus %d Guide%s" % [removed_guide_count, "s" if removed_guide_count != 1 else ""]
	description += "? This cannot be undone except through Undo."
	if is_instance_valid(component_remove_dialog):
		component_remove_dialog.title = "Delete Group"
		component_remove_dialog.dialog_text = description
		component_remove_dialog.popup_centered()
	else:
		_confirm_component_deletion()

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
	# The ID is retired rather than freed. References to it stay where they are
	# and show as missing; removing them silently would hide the deletion, and
	# Runtime Export refuses them anyway.
	retired_assets.append({"id": selected_asset_id,
		"last_asset_key": AssetCatalogService.asset_key(str(assets[asset_index].get("name", "")))})
	assets.remove_at(asset_index)
	expanded_assets.erase(selected_asset_id)
	asset_camera_states.erase(selected_asset_id)
	if canvas_camera_asset_id == selected_asset_id:
		canvas_camera_asset_id = ""
	selected_asset_id = ""
	selected_component_id = ""
	active_state = ""
	_invalidate_render(RENDER_DOCUMENT)


func _rename_selected_group(new_name: String) -> void:
	var asset := _get_asset(selected_asset_id)
	var group := ComponentHierarchy.group_by_id(asset, selected_group_id)
	var group_name := new_name.strip_edges()
	var name_error := _group_name_validation_error(asset, group_name, selected_group_id)
	if group.is_empty() or not name_error.is_empty():
		_show_status_message(name_error)
		return
	if group_name == str(group.get("name", "")):
		return
	_record_direct_change()
	group["name"] = group_name
	_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR)


func _on_group_transform_value_changed(value: float, property_name: String) -> void:
	var asset := _get_asset(selected_asset_id)
	var group := ComponentHierarchy.group_by_id(asset, selected_group_id)
	if group.is_empty():
		return
	_record_direct_change()
	var transform: Dictionary = group.get("transform", WorldDocumentService.default_component_transform())
	var transform_position: Vector2 = transform.get("position", Vector2.ZERO)
	var transform_scale: Vector2 = transform.get("scale", Vector2.ONE)
	var pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
	var previous_pivot := pivot
	if property_name in ["position_x", "position_y", "pivot_x", "pivot_y"]:
		value = _world_to_editor_units(value)
	match property_name:
		"position_x": transform_position.x = value
		"position_y": transform_position.y = value
		"rotation": transform["rotation"] = value
		"scale_x": transform_scale.x = value
		"scale_y": transform_scale.y = value
		"pivot_x": pivot.x = value
		"pivot_y": pivot.y = value
	if property_name in ["pivot_x", "pivot_y"]:
		var pivot_rotation := deg_to_rad(float(transform.get("rotation", 0.0)))
		transform_position += ((pivot - previous_pivot) * transform_scale).rotated(pivot_rotation)
	transform["position"] = transform_position
	transform["scale"] = transform_scale
	transform["pivot"] = pivot
	group["transform"] = transform
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


func _on_group_visibility_entry_changed(visibility_enabled: bool, asset_id: String, group_id: String) -> void:
	var asset := _get_asset(asset_id)
	var group := ComponentHierarchy.group_by_id(asset, group_id)
	if group.is_empty():
		return
	_record_direct_change()
	group["visibility"] = visibility_enabled
	_invalidate_render(RENDER_DOCUMENT)


func _on_group_visibility_changed(visibility_enabled: bool) -> void:
	var asset := _get_asset(selected_asset_id)
	var group := ComponentHierarchy.group_by_id(asset, selected_group_id)
	if group.is_empty():
		return
	_record_direct_change()
	group["visibility"] = visibility_enabled
	_invalidate_render(RENDER_OUTLINER | RENDER_CANVAS_CONTEXT)


func _on_group_hierarchy_parent_selected(index: int, option: OptionButton) -> void:
	var asset := _get_asset(selected_asset_id)
	var group := ComponentHierarchy.group_by_id(asset, selected_group_id)
	if group.is_empty() or index < 0:
		return
	var parent_id := str(option.get_item_metadata(index))
	if ComponentHierarchy.group_parent_id(group) == parent_id:
		return
	if parent_id.is_empty():
		# Root also moves the Group's direct Parts, matching Outliner
		# drag-and-drop; the anchor-only path below would leave them
		# literally parented to their old Component.
		if not ComponentHierarchy.can_move_group_to_component(asset, selected_group_id, ""):
			return
		_record_direct_change()
		_move_group_under_component_preserving_world(asset, selected_group_id, "")
	else:
		if not ComponentHierarchy.can_parent_group(asset, selected_group_id, parent_id):
			return
		_record_direct_change()
		_set_group_parent_preserving_world(asset, selected_group_id, parent_id)
	_invalidate_render(RENDER_DOCUMENT)


func _on_weapon_frame_value_changed(value: float, property_name: String) -> void:
	var guide := _get_guide(_get_asset(selected_asset_id), selected_guide_id)
	if guide.is_empty() or not AssetGuide.is_weapon_frame(str(guide.get("guide_type", ""))):
		return
	_record_coalesced_change()
	var transform: Dictionary = guide.get("transform", WorldDocumentService.default_component_transform())
	var frame_position := Vector2(transform.get("position", Vector2.ZERO))
	if property_name == "position_x":
		frame_position.x = _world_to_editor_units(value)
	elif property_name == "position_y":
		frame_position.y = _world_to_editor_units(value)
	elif property_name == "rotation":
		transform["rotation"] = value
	transform["position"] = frame_position
	transform["scale"] = Vector2.ONE
	transform["pivot"] = Vector2.ZERO
	guide["transform"] = transform
	_invalidate_render(RENDER_CANVAS_CONTEXT)


func _rename_weighting_style(new_name: String) -> void:
	var style := _weighting_style(selected_asset_id, selected_component_id, selected_weighting_style_id)
	var style_name := new_name.strip_edges()
	if style.is_empty() or style_name.is_empty() or style_name == str(style.get("name", "")):
		return
	_record_direct_change()
	style["name"] = style_name
	_invalidate_render(RENDER_OUTLINER)


func _weighting_style_index(document: Dictionary, style_id: String) -> int:
	var styles: Array = document.get("weighting", {}).get("styles", [])
	for style_index in range(styles.size()):
		if str(styles[style_index].get("id", "")) == style_id:
			return style_index
	return -1


func _delete_selected_weighting_style() -> void:
	if selected_weighting_style_id.is_empty():
		return
	var existing := _get_geometry_document(selected_asset_id, selected_component_id)
	if existing.is_empty() or _weighting_style_index(existing, selected_weighting_style_id) < 0:
		return
	_record_direct_change()
	var document := _mutable_geometry_document(selected_asset_id, selected_component_id)
	var styles: Array = document.get("weighting", {}).get("styles", [])
	for style_index in range(styles.size()):
		if str(styles[style_index].get("id", "")) == selected_weighting_style_id:
			styles.remove_at(style_index)
			selected_weighting_style_id = ""
			weighting_preview = {}
			weighting_preview_key = ""
			_invalidate_render(RENDER_DOCUMENT)
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
	var guide_ordinal := ComponentHierarchy.next_guide_ordinal(asset, AssetGuide.scope_component_id(guide), guide_type)
	guide["guide_type"] = guide_type
	guide["ordinal"] = guide_ordinal
	_invalidate_render(RENDER_DOCUMENT)


func _on_guide_target_selected(index: int, option: OptionButton) -> void:
	var asset := _get_asset(selected_asset_id)
	var guide := _get_guide(asset, selected_guide_id)
	if guide.is_empty() or not guide.get("points", []).is_empty() or index < 0 or index >= option.item_count:
		return
	var component_id := str(option.get_item_metadata(index))
	if AssetGuide.scope_component_id(guide) == component_id:
		return
	_record_direct_change()
	var guide_ordinal := ComponentHierarchy.next_guide_ordinal(asset, component_id, str(guide.get("guide_type", AssetGuide.SAMPLE)))
	guide["scope"] = {"kind": "component", "component_id": component_id}
	guide["ordinal"] = guide_ordinal
	_invalidate_render(RENDER_DOCUMENT)


func _on_selected_guide_visibility_changed(enabled: bool) -> void:
	var guide := _get_guide(_get_asset(selected_asset_id), selected_guide_id)
	if guide.is_empty() or bool(guide.get("visibility", true)) == enabled:
		return
	_record_direct_change()
	guide["visibility"] = enabled
	_invalidate_render(RENDER_OUTLINER | RENDER_CANVAS_CONTEXT)


func _on_guide_visibility_entry_changed(enabled: bool, asset_id: String, guide_id: String) -> void:
	var guide := _get_guide(_get_asset(asset_id), guide_id)
	if guide.is_empty() or bool(guide.get("visibility", true)) == enabled:
		return
	_record_direct_change()
	guide["visibility"] = enabled
	_invalidate_render(RENDER_OUTLINER | RENDER_CANVAS_CONTEXT)


func _delete_selected_guide() -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty() or selected_guide_id.is_empty():
		return
	pending_guide_remove_asset_id = selected_asset_id
	pending_guide_remove_id = selected_guide_id
	var guide := _get_guide(asset, selected_guide_id)
	if is_instance_valid(guide_remove_dialog):
		guide_remove_dialog.dialog_text = "Delete Guide ‘%s’?" % WorldDocumentService.guide_display_name(asset, guide)
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
			_invalidate_render(RENDER_DOCUMENT)
			return


func _get_sampling_input(asset: Dictionary, parent_component_id: String, input_id: String, input_kind: String) -> Dictionary:
	if input_kind == "guide":
		var guide := _get_guide(asset, input_id)
		return guide if str(guide.get("guide_type", "")) == AssetGuide.CUT \
			and not AssetGuide.is_group_scoped(guide) \
			and AssetGuide.scope_component_id(guide) == parent_component_id else {}
	if input_kind == "component":
		for component in asset.get("components", []):
			if str(component.get("id", "")) == input_id and _is_geometry_hole_input(asset, component, parent_component_id):
				return component
	return {}


func _sampling_input_display_name(asset: Dictionary, _parent: Dictionary, input: Dictionary, input_kind: String) -> String:
	if input_kind == "guide":
		return WorldDocumentService.guide_display_name(asset, input)
	return WorldDocumentService.component_outliner_name(assets, input)


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
	var document := _mutable_geometry_document(selected_asset_id, selected_component_id)
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
	var document := _mutable_geometry_document(selected_asset_id, selected_component_id)
	recipe = GeometrySamplingService.normalize_recipe(document.get("sampling", {}).get("recipe", {}))
	var refinements: Dictionary = recipe["parameters"].get("boundary_refinements", {}).duplicate(true)
	refinements.erase(input_id)
	recipe["parameters"]["boundary_refinements"] = refinements
	document["sampling"]["recipe"] = recipe
	_schedule_geometry_sampling_input_refresh()


func _on_geometry_sampling_refinement_changed(value: float, input_id: String) -> void:
	_set_geometry_sampling_refinement(input_id, value)


func _on_geometry_sampling_parameter_changed(value: float, parameter_name: String) -> void:
	if selected_asset_id.is_empty() or selected_component_id.is_empty():
		return
	var current_recipe := _geometry_sampling_recipe(selected_asset_id, selected_component_id)
	var normalized_value := maxf(value, GeometrySamplingService.MIN_SPACING) if parameter_name == "spacing" else clampf(value, 0.0, 1.0)
	if is_equal_approx(float(current_recipe.get("parameters", {}).get(parameter_name, normalized_value)), normalized_value):
		return
	_record_coalesced_change()
	var document := _mutable_geometry_document(selected_asset_id, selected_component_id)
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
	_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR)
	_refresh_geometry_sampling_workspace()


func _bake_geometry_sampling() -> void:
	_bake_geometry_sampling_preview()


func _bake_geometry_sampling_preview() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not _geometry_sampling_preview_matches(selected_asset_id, selected_component_id, component):
		return
	_record_direct_change()
	var document := _mutable_geometry_document(selected_asset_id, selected_component_id)
	var bake := geometry_sampling_preview.duplicate(true)
	bake["bake_id"] = "bake_%d" % ResourceUID.create_id()
	var asset := _get_asset(selected_asset_id)
	var cut_guides := _cut_guides_for_component(asset, selected_component_id)
	var hole_components := _geometry_sampling_hole_components(asset, selected_component_id)
	bake["semantic_source_signature"] = GeometryAutoBuildService.source_signature(component, cut_guides, hole_components, {"sampling": _geometry_sampling_recipe(selected_asset_id, selected_component_id)})
	document["sampling"]["bakes"][str(bake.get("method", ""))] = WorldDocumentService.document_safe(bake)
	selected_geometry_bake_method = str(bake.get("method", ""))
	geometry_sampling_preview = {}
	geometry_sampling_preview_key = ""
	geometry_sampling_preview_state = "idle"
	_show_status_message("Sampling baked for %s." % str(component.get("name", "Component")))
	_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR)
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
	_invalidate_render(RENDER_OUTLINER)
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
	var workspace_input_id := selected_sampling_input_id
	if _get_sampling_input(asset, selected_component_id, workspace_input_id, selected_sampling_input_kind).is_empty():
		workspace_input_id = ""
	geometry_sampling_workspace.set_context(component, preview, bake, _geometry_sampling_status(selected_asset_id, selected_component_id, component), overlays, workspace_input_id)


func _geometry_sampling_hole_components(asset: Dictionary, component_id: String) -> Array:
	var result: Array = []
	if not _geometry_body_accepts_holes(asset, component_id):
		return result
	var parent_inverse := ComponentHierarchy.world_transform(asset, component_id).affine_inverse()
	for hole_input in asset.get("components", []):
		if not _is_geometry_hole_candidate(asset, hole_input, component_id):
			continue
		var input_id := str(hole_input.get("id", ""))
		var input_label := WorldDocumentService.component_outliner_name(assets, hole_input)
		if not _is_reference_component(hole_input):
			var hole_transform := parent_inverse * ComponentHierarchy.world_transform(asset, input_id)
			var direct_hole := _geometry_sampling_hole_source(hole_input, input_id, input_id, input_label, hole_transform)
			if not direct_hole.is_empty():
				result.append(direct_hole)
			continue
		var source_asset := _get_asset(str(hole_input.get("source_asset_id", "")))
		if source_asset.is_empty():
			result.append(_geometry_sampling_invalid_hole(input_id, input_label, "Referenced source Asset is missing."))
			continue
		var reference_world := ComponentHierarchy.world_transform(asset, input_id)
		var source_boundary_count := 0
		for source_component in source_asset.get("components", []):
			if not source_component is Dictionary or _is_reference_component(source_component) or _is_hole_component(source_component) or not _effective_component_visibility(source_asset, source_component) or WorldDocumentService.component_draw_mode(source_component) not in [WorldDocumentService.DRAW_MODE_CLOSED_LOOP, WorldDocumentService.DRAW_MODE_PRIMITIVE]:
				continue
			source_boundary_count += 1
			var hole_id := "%s:%s" % [input_id, str(source_component.get("id", ""))]
			var source_world := ComponentHierarchy.world_transform(source_asset, str(source_component.get("id", "")))
			var transform := parent_inverse * reference_world * source_world
			var source_label := "%s / %s" % [input_label, str(source_component.get("name", "Component"))]
			var referenced_hole := _geometry_sampling_hole_source(source_component, hole_id, input_id, source_label, transform)
			if not referenced_hole.is_empty():
				result.append(referenced_hole)
		if source_boundary_count == 0:
			result.append(_geometry_sampling_invalid_hole(input_id, input_label, "Referenced Asset has no visible Closed Loop or Primitive boundary."))
	return result


func _is_hole_component(component: Variant) -> bool:
	return component is Dictionary and WorldDocumentService.is_hole_component(component)


func _geometry_body_accepts_holes(asset: Dictionary, component_id: String) -> bool:
	var component := _get_component(asset, component_id)
	return WorldDocumentService.is_outer_body(component) and _effective_component_visibility(asset, component)


func _is_geometry_hole_input(asset: Dictionary, component: Variant, parent_component_id: String) -> bool:
	return _geometry_body_accepts_holes(asset, parent_component_id) \
		and _is_geometry_hole_candidate(asset, component, parent_component_id)


func _is_geometry_hole_candidate(asset: Dictionary, component: Variant, parent_component_id: String) -> bool:
	if not component is Dictionary or _is_region(component):
		return false
	if str(component.get("parent_component_id", "")) != parent_component_id or WorldDocumentService.topology_role(component) != WorldDocumentService.ROLE_HOLE or not _effective_component_visibility(asset, component):
		return false
	return _is_reference_component(component) or WorldDocumentService.component_draw_mode(component) in [WorldDocumentService.DRAW_MODE_CLOSED_LOOP, WorldDocumentService.DRAW_MODE_PRIMITIVE]


func _geometry_sampling_invalid_hole(input_id: String, input_label: String, error: String) -> Dictionary:
	return {"id": input_id, "sampling_input_id": input_id, "sampling_input_label": input_label,
		"sampling_error": error, "draw_mode": WorldDocumentService.DRAW_MODE_CLOSED_LOOP, "topology_role": WorldDocumentService.ROLE_HOLE,
		"transform": WorldDocumentService.default_component_transform(),
		"sampling_transform": Transform2D.IDENTITY, "points": [], "edges": [], "chains": []}


func _geometry_sampling_hole_source(source_component: Dictionary, hole_id: String, input_id: String, input_label: String, transform: Transform2D) -> Dictionary:
	if PrimitiveGeometryService.has_analytic_shape(source_component):
		var primitive_hole: Dictionary = source_component.duplicate(true)
		primitive_hole["id"] = hole_id
		primitive_hole["sampling_input_id"] = input_id
		primitive_hole["sampling_input_label"] = input_label
		primitive_hole["topology_role"] = WorldDocumentService.ROLE_HOLE
		primitive_hole["sampling_transform"] = transform
		return primitive_hole
	if WorldDocumentService.is_primitive(source_component):
		var invalid_primitive: Dictionary = source_component.duplicate(true)
		invalid_primitive["id"] = hole_id
		invalid_primitive["sampling_input_id"] = input_id
		invalid_primitive["sampling_input_label"] = input_label
		invalid_primitive["topology_role"] = WorldDocumentService.ROLE_HOLE
		invalid_primitive["sampling_transform"] = transform
		var primitive_issues := PrimitiveGeometryService.validation_issues(invalid_primitive)
		invalid_primitive["sampling_error"] = str(primitive_issues[0]) if not primitive_issues.is_empty() else "Primitive boundary is invalid."
		return invalid_primitive
	if not WorldDocumentService.is_closed_loop(source_component):
		return {}
	var hole_component: Dictionary = source_component.duplicate(true)
	hole_component["id"] = hole_id
	hole_component["sampling_input_id"] = input_id
	hole_component["sampling_input_label"] = input_label
	hole_component["topology_role"] = WorldDocumentService.ROLE_HOLE
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
		chain["topology_role"] = WorldDocumentService.ROLE_HOLE
	return hole_component


func _geometry_sampling_overlays(asset: Dictionary, component_id: String) -> Dictionary:
	var overlays := {"holes": [], "guides": []}
	for hole_component in _geometry_sampling_hole_components(asset, component_id):
		var local_points: Array[Vector2] = []
		if PrimitiveGeometryService.has_analytic_shape(hole_component):
			var transform: Transform2D = hole_component.get("sampling_transform", Transform2D.IDENTITY)
			for point in PrimitiveGeometryService.contour(hole_component):
				local_points.append(transform * point)
		else:
			var working_hole: Dictionary = hole_component.duplicate(true)
			BezierGeometry.resolve_auto_handles(working_hole.get("points", []), working_hole.get("chains", []))
			for chain in working_hole.get("chains", []):
				if chain is Dictionary and bool(chain.get("closed", false)):
					local_points.assign(BezierGeometry.flatten_chain(working_hole, chain))
					break
		if local_points.size() >= 3:
			overlays["holes"].append({"points": local_points, "closed": true})
	for guide in _cut_guides_for_component(asset, component_id):
		if not guide is Dictionary:
			continue
		var local_guide: Dictionary = guide.duplicate(true)
		local_guide["points"] = guide.get("points", []).duplicate(true)
		overlays["guides"].append(local_guide)
	return overlays


func _geometry_seeding_spine_enabled(recipe: Dictionary, guide_id: String) -> bool:
	for input in recipe.get("parameters", {}).get("spine_inputs", []):
		if input is Dictionary and str(input.get("guide_id", "")) == guide_id:
			return bool(input.get("enabled", true))
	return false


func _on_geometry_seeding_spine_enabled(enabled: bool, guide_id: String) -> void:
	var recipe := _geometry_seeding_recipe(selected_asset_id, selected_component_id)
	_record_direct_change()
	var document := _mutable_geometry_document(selected_asset_id, selected_component_id)
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
	var recipe := _geometry_seeding_recipe(selected_asset_id, selected_component_id)
	if bool(recipe.get("parameters", {}).get("fill_gaps", true)) == enabled:
		return
	_record_direct_change()
	var document := _mutable_geometry_document(selected_asset_id, selected_component_id)
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
	var recipe := _geometry_seeding_recipe(selected_asset_id, selected_component_id)
	if bool(recipe.get("parameters", {}).get(parameter_name, false)) == enabled:
		return
	_record_direct_change()
	var document := _mutable_geometry_document(selected_asset_id, selected_component_id)
	recipe["parameters"][parameter_name] = enabled
	document["seeding"]["recipe"] = GeometrySeedingService.normalize_recipe(recipe)
	call_deferred("_refresh_geometry_after_recipe_change")


func _on_geometry_seeding_advanced_pattern_toggled(expanded: bool) -> void:
	geometry_seeding_advanced_pattern_expanded = expanded
	_invalidate_render(RENDER_INSPECTOR)


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
	var document := _mutable_geometry_document(selected_asset_id, selected_component_id)
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
	_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR)
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
	_invalidate_render(RENDER_OUTLINER)
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
	var document := _mutable_geometry_document(selected_asset_id, selected_component_id)
	var bake := geometry_seeding_preview.duplicate(true)
	bake["bake_id"] = "seeding_bake_%d" % ResourceUID.create_id()
	bake["edited"] = false
	document["seeding"]["bakes"][str(bake.get("method", ""))] = WorldDocumentService.document_safe(bake)
	selected_geometry_bake_method = str(bake.get("method", ""))
	geometry_seeding_preview = {}
	geometry_seeding_preview_key = ""
	geometry_seeding_preview_state = "idle"
	geometry_seeding_preview_revision += 1
	_set_geometry_command_state("seeding_edit" if geometry_seeding_enter_edit_after_bake else "")
	geometry_seeding_enter_edit_after_bake = false
	_show_status_message("Seeding baked for %s." % str(component.get("name", "Component")))
	_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR | RENDER_CONTEXT_BAR)
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
	geometry_seeding_workspace.set_context(_geometry_sampling_bake(selected_asset_id, selected_component_id), result, guides, status, geometry_seeding_edit_active and status in ["Baked", "Edited"], geometry_seeding_edit_tool, selected_seeding_input_id)


func _editable_geometry_seeding_bake() -> Dictionary:
	# Read-only view of the Bake that manual seed editing may edit. Callers that
	# actually change it must record the change first and then take write access
	# through _mutable_geometry_seeding_bake.
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if _geometry_seeding_status(selected_asset_id, selected_component_id, component) not in ["Baked", "Edited"]:
		return {}
	return _geometry_seeding_bake(selected_asset_id, selected_component_id)


func _mutable_geometry_seeding_bake() -> Dictionary:
	# Write access to the editable Seeding Bake. Detaches the owning geometry
	# document from every history snapshot before the Bake is mutated in place.
	if _editable_geometry_seeding_bake().is_empty():
		return {}
	_mutable_geometry_document(selected_asset_id, selected_component_id)
	return _geometry_seeding_bake(selected_asset_id, selected_component_id)


func _on_geometry_seed_add_requested(world_position: Vector2) -> void:
	var bake := _editable_geometry_seeding_bake()
	var sampling_bake := _geometry_sampling_bake(selected_asset_id, selected_component_id)
	var recipe := _geometry_seeding_recipe(selected_asset_id, selected_component_id)
	if bake.is_empty() or not GeometrySeedingService.point_is_valid(sampling_bake, world_position, _geometry_seeding_constraint_clearance(recipe)):
		_show_status_message("Seeds must respect Outer, Hole, Cut, and constraint clearance.")
		return
	for seed_data in bake.get("seeds", []):
		if world_position.distance_to(Vector2(seed_data.get("position", Vector2.ZERO))) < _geometry_seeding_manual_minimum_distance(recipe):
			_show_status_message("Seeds must respect the current minimum spacing.")
			return
	_record_direct_change()
	var editable := _mutable_geometry_seeding_bake()
	if editable.is_empty():
		return
	editable["seeds"].append({"id": "seed:manual:%d" % ResourceUID.create_id(), "position": world_position, "origin": "manual", "method": "manual", "provenance": {}})
	_mark_geometry_seeding_bake_edited(editable)


func _on_geometry_seed_move_started(_seed_id: String) -> void:
	if not _editable_geometry_seeding_bake().is_empty():
		_record_direct_change()


func _on_geometry_seed_move_requested(seed_id: String, world_position: Vector2) -> void:
	# _on_geometry_seed_move_started already recorded the snapshot for this drag.
	var bake := _mutable_geometry_seeding_bake()
	var recipe := _geometry_seeding_recipe(selected_asset_id, selected_component_id)
	if bake.is_empty() or not GeometrySeedingService.point_is_valid(_geometry_sampling_bake(selected_asset_id, selected_component_id), world_position, _geometry_seeding_constraint_clearance(recipe)):
		return
	for other_seed in bake.get("seeds", []):
		if str(other_seed.get("id", "")) != seed_id and world_position.distance_to(Vector2(other_seed.get("position", Vector2.ZERO))) < _geometry_seeding_manual_minimum_distance(recipe):
			return
	for seed_data in bake.get("seeds", []):
		if str(seed_data.get("id", "")) == seed_id:
			seed_data["position"] = world_position
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
	var bake := _mutable_geometry_seeding_bake()
	if bake.is_empty():
		return
	bake["seed_count"] = bake.get("seeds", []).size()
	_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR | RENDER_CONTEXT_BAR)
	_refresh_geometry_seeding_workspace()


func _on_geometry_seed_remove_requested(seed_id: String) -> void:
	var bake := _editable_geometry_seeding_bake()
	if bake.is_empty():
		return
	var seeds: Array = bake.get("seeds", [])
	for seed_index in range(seeds.size()):
		if str(seeds[seed_index].get("id", "")) == seed_id:
			_record_direct_change()
			var editable := _mutable_geometry_seeding_bake()
			if editable.is_empty():
				return
			editable.get("seeds", []).remove_at(seed_index)
			_mark_geometry_seeding_bake_edited(editable)
			return


func _mark_geometry_seeding_bake_edited(bake: Dictionary) -> void:
	bake["seed_count"] = bake.get("seeds", []).size()
	bake["edited"] = true
	_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR | RENDER_CONTEXT_BAR)
	_refresh_geometry_seeding_workspace()


func _on_geometry_seeding_method_selected(index: int, option: OptionButton) -> void:
	_set_geometry_seeding_method(str(option.get_item_metadata(index)))


func _on_geometry_meshing_seed_source_selected(index: int, option: OptionButton) -> void:
	if index < 0 or index >= option.item_count:
		return
	var seeding_method := str(option.get_item_metadata(index))
	var current := _geometry_meshing_recipe(selected_asset_id, selected_component_id)
	if str(current.get("parameters", {}).get("seeding_method", "")) == seeding_method:
		return
	_record_direct_change()
	var document := _mutable_geometry_document(selected_asset_id, selected_component_id)
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
	var document := _mutable_geometry_document(selected_asset_id, selected_component_id)
	current["parameters"][parameter_name] = normalized
	document["meshing"]["recipe"] = GeometryMeshingService.normalize_recipe(current)
	call_deferred("_refresh_geometry_after_recipe_change")


func _on_geometry_meshing_override_changed(enabled: bool, parameter_name: String) -> void:
	var current := _geometry_meshing_recipe(selected_asset_id, selected_component_id)
	if bool(current.get("parameters", {}).get(parameter_name, false)) == enabled:
		return
	_record_direct_change()
	var document := _mutable_geometry_document(selected_asset_id, selected_component_id)
	current["parameters"][parameter_name] = enabled
	document["meshing"]["recipe"] = GeometryMeshingService.normalize_recipe(current)
	call_deferred("_refresh_geometry_after_recipe_change")


func _on_geometry_meshing_advanced_relaxation_toggled(expanded: bool) -> void:
	geometry_meshing_advanced_relaxation_expanded = expanded
	_invalidate_render(RENDER_INSPECTOR)


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
	_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR)
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
	if WorldDocumentService.is_contour(component):
		geometry_meshing_preview_key = _geometry_document_key(selected_asset_id, selected_component_id)
		geometry_meshing_preview = ContourMeshService.generate(component, _effective_contour_stroke_width_px(component))
		geometry_meshing_preview_state = "ready" if bool(geometry_meshing_preview.get("valid", false)) else "invalid"
		_show_status_message("Generated %d Contour Triangles." % int(geometry_meshing_preview.get("triangle_count", 0)) if bool(geometry_meshing_preview.get("valid", false)) else str(geometry_meshing_preview.get("errors", ["Contour Mesh could not be generated."])[0]))
		_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR)
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
	_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR)
	_refresh_geometry_meshing_workspace()


func _bake_geometry_meshing() -> void:
	_bake_geometry_meshing_preview()


func _bake_geometry_meshing_preview() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not _geometry_meshing_preview_matches(selected_asset_id, selected_component_id, component):
		return
	_record_direct_change()
	var document := _mutable_geometry_document(selected_asset_id, selected_component_id)
	var bake := geometry_meshing_preview.duplicate(true)
	bake["bake_id"] = "meshing_bake_%d" % ResourceUID.create_id()
	document["meshing"]["bakes"][str(bake.get("method", ""))] = WorldDocumentService.document_safe(bake)
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
			"recipe_mode": "manual",
			"auto_recipe_version": 0,
			"pipeline_recipe_hash": GeometryAutoBuildService.pipeline_recipe_hash(recipes),
			"attempts": 1
		},
		"last_error": "",
		"last_failure_signature": {}
	}
	geometry_meshing_preview = {}
	geometry_meshing_preview_key = ""
	geometry_meshing_preview_state = "idle"
	_show_status_message("Mesh baked for %s." % str(component.get("name", "Component")))
	_invalidate_render(RENDER_OUTLINER | RENDER_INSPECTOR)
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
	if WorldDocumentService.is_contour(component):
		var contour_result := geometry_meshing_preview if _geometry_meshing_preview_matches(selected_asset_id, selected_component_id, component) else _geometry_meshing_bake(selected_asset_id, selected_component_id, ContourMeshService.METHOD)
		geometry_meshing_workspace.set_context({}, {}, contour_result, _geometry_meshing_status(selected_asset_id, selected_component_id, component))
		return
	var recipe := _geometry_meshing_recipe(selected_asset_id, selected_component_id)
	var input := _geometry_meshing_input(selected_asset_id, selected_component_id, recipe)
	var result := geometry_meshing_preview if _geometry_meshing_preview_matches(selected_asset_id, selected_component_id, component) else _geometry_meshing_bake(selected_asset_id, selected_component_id)
	geometry_meshing_workspace.set_context(input.get("sampling", {}), input.get("seeding", {}), result, _geometry_meshing_status(selected_asset_id, selected_component_id, component))


func _weighting_inspector_context() -> Dictionary:
	# The Weighting Inspector shows one Style of one Component plus the state of
	# its Mesh and preview; all of that is resolved here.
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or _is_hole_component(component):
		return {}
	var style := _weighting_style(selected_asset_id, selected_component_id, selected_weighting_style_id)
	var result: Dictionary = weighting_preview if weighting_preview_key == _weighting_preview_id(selected_asset_id, selected_component_id, selected_weighting_style_id) else style.get("bake", {})
	return {
		"component": component,
		"style": style,
		"mesh_status": _component_mesh_status(selected_asset_id, selected_component_id, component),
		"status": _weighting_status(selected_asset_id, selected_component_id, component, style),
		"result": result,
		"bake_enabled": WeightingService.result_matches(weighting_preview, _component_mesh_bake(selected_asset_id, selected_component_id), style),
	}


func _sync_motion_models() -> void:
	# Ran halfway through the Animation render before the view was extracted; the
	# order is unchanged, it just happens before the view draws instead of during.
	if active_motion_submodule in ["Path", "Act", "Sequence"]:
		return
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty():
		return
	if is_instance_valid(motion_workspace) and motion_workspace.asset_id != selected_asset_id:
		motion_selection.select_asset(selected_asset_id)
		motion_workspace.set_asset(selected_asset_id, str(asset.get("name", "Asset")), asset.get("components", []), _ensure_asset_animation(asset))
	_sync_motion_player_document(asset)


func _motion_inspector_context() -> Dictionary:
	# Everything the Motion Inspector needs that is a document lookup rather than
	# a Workspace query.
	var sequence_document := _get_motion_sequence(selected_motion_sequence_id)
	var entry := _resolved_motion_sequence_entry(sequence_document) if not sequence_document.is_empty() else {}
	var path_document := _get_motion_path(selected_motion_path_id)
	var selected_motion: Dictionary = {}
	if is_instance_valid(motion_workspace):
		var preview := motion_workspace.get_selected_preview()
		if str(preview.get("kind", "")) == MotionSelection.MOTION:
			selected_motion = preview.get("item", {})
	return {
		"submodule": active_motion_submodule,
		"asset": _get_asset(selected_asset_id),
		"act": _get_motion_act(selected_motion_act_id),
		"path": path_document,
		"sequence": sequence_document,
		"sequence_entry": entry,
		"sequence_entry_context": _motion_sequence_entry_context(entry),
		"motion": {"validation": _motion_preview_validation(selected_motion) if not selected_motion.is_empty() else ""},
		"path_state": {
			"previewable": _motion_path_is_previewable(path_document),
			"has_preview_asset": not _get_asset(motion_path_preview_asset_id).is_empty(),
		},
		"motion_phase": motion_phase,
		"sequence_phase": motion_sequence_phase,
		"sequence_view": motion_sequence_view,
		"path_preview_asset_id": motion_path_preview_asset_id,
		"assets": assets,
		"motion_paths": motion_paths,
	}


func _clear_inspector_content() -> void:
	# The two extracted views live inside inspector_content and outlive a render;
	# everything the not-yet-extracted modules draw does not.
	for child in inspector_content.get_children():
		if child != create_inspector_view and child != geometry_inspector_view and child != style_inspector_view and child != motion_inspector_view:
			child.queue_free()


func _geometry_sampling_inspector_context(component: Dictionary) -> Dictionary:
	# Everything the Sampling Inspector shows, resolved against the Geometry
	# document and the preview cache here so the view holds no document access.
	if component.is_empty():
		return {}
	var asset := _get_asset(selected_asset_id)
	var display_result := geometry_sampling_preview if _geometry_sampling_preview_matches(selected_asset_id, selected_component_id, component) else _geometry_sampling_bake(selected_asset_id, selected_component_id)
	var boundary_rows: Array = []
	if _geometry_body_accepts_holes(asset, selected_component_id):
		for hole_component in asset.get("components", []):
			if _is_geometry_hole_candidate(asset, hole_component, selected_component_id):
				boundary_rows.append({"title": "Hole · %s" % WorldDocumentService.component_outliner_name(assets, hole_component),
					"input_id": str(hole_component.get("id", "")), "role": "hole", "kind": "hole"})
	for guide in asset.get("guides", []):
		if AssetGuide.scope_component_id(guide) != selected_component_id or str(guide.get("guide_type", "")) != AssetGuide.CUT:
			continue
		boundary_rows.append({"title": "Cut · %s" % WorldDocumentService.guide_display_name(asset, guide),
			"input_id": str(guide.get("id", "")), "role": "cut", "kind": "cut"})
	var selected_input_title := ""
	if not selected_sampling_input_id.is_empty():
		var input := _get_sampling_input(asset, selected_component_id, selected_sampling_input_id, selected_sampling_input_kind)
		if not input.is_empty():
			selected_input_title = _sampling_input_display_name(asset, component, input, selected_sampling_input_kind)
	return {
		"component": component,
		"recipe": _geometry_sampling_recipe(selected_asset_id, selected_component_id),
		"display_result": display_result,
		"status": _geometry_sampling_status(selected_asset_id, selected_component_id, component),
		"boundary_rows": boundary_rows,
		"selected_input_id": selected_sampling_input_id,
		"selected_input_title": selected_input_title,
	}


func _geometry_seeding_inspector_context(component: Dictionary) -> Dictionary:
	if component.is_empty():
		return {}
	var asset := _get_asset(selected_asset_id)
	var recipe := _geometry_seeding_recipe(selected_asset_id, selected_component_id)
	var spine_rows: Array = []
	for guide in _sampler_spines_for_component(asset, selected_component_id):
		spine_rows.append({"guide_id": str(guide.get("id", "")),
			"label": WorldDocumentService.guide_display_name(asset, guide)})
	return {
		"component": component,
		"recipe": recipe,
		"sampling_bake": _geometry_sampling_bake(selected_asset_id, selected_component_id),
		"sampling_bake_is_current": _geometry_sampling_bake_is_current(selected_asset_id, selected_component_id, component),
		"status": _geometry_seeding_status(selected_asset_id, selected_component_id, component),
		"result": geometry_seeding_preview if _geometry_seeding_preview_matches(selected_asset_id, selected_component_id, component) else _geometry_seeding_bake(selected_asset_id, selected_component_id),
		"spine_rows": spine_rows,
		"advanced_pattern_expanded": geometry_seeding_advanced_pattern_expanded,
	}


func _geometry_meshing_inspector_context(component: Dictionary) -> Dictionary:
	if component.is_empty():
		return {}
	var recipe := _geometry_meshing_recipe(selected_asset_id, selected_component_id)
	var view_options: Array = []
	if is_instance_valid(geometry_meshing_workspace):
		view_options = [
			{"key": "mesh_edges", "label": "Mesh Edges", "value": geometry_meshing_workspace.show_mesh_edges},
			{"key": "seed_points", "label": "Seed Points", "value": geometry_meshing_workspace.show_seed_points},
			{"key": "triangle_fill", "label": "Triangle Fill", "value": geometry_meshing_workspace.show_triangle_fill},
			{"key": "constraints", "label": "Constraints", "value": geometry_meshing_workspace.show_constraints},
			{"key": "optimization", "label": "Optimization", "value": geometry_meshing_workspace.show_optimization},
			{"key": "quality", "label": "Quality", "value": geometry_meshing_workspace.show_quality},
		]
	var preview_matches := _geometry_meshing_preview_matches(selected_asset_id, selected_component_id, component)
	return {
		"component": component,
		"recipe": recipe,
		"source_issues": _component_mesh_source_validation_issues(_get_asset(selected_asset_id), component),
		"sampling_bake_is_current": _geometry_sampling_bake_is_current(selected_asset_id, selected_component_id, component),
		"seeding_bakes": _geometry_seeding_bakes(selected_asset_id, selected_component_id),
		"input_is_current": _geometry_meshing_input_is_current(selected_asset_id, selected_component_id, component, recipe),
		"meshing_input": _geometry_meshing_input(selected_asset_id, selected_component_id, recipe),
		"view_options": view_options,
		"build_diagnostic_lines": _component_mesh_build_diagnostic_lines(selected_asset_id, selected_component_id),
		"status": _geometry_meshing_status(selected_asset_id, selected_component_id, component),
		"contour_status": _geometry_meshing_status(selected_asset_id, selected_component_id, component),
		"auto_build_error": str(_component_mesh_reference(selected_asset_id, selected_component_id).get("last_error", "")),
		"result": geometry_meshing_preview if preview_matches else _geometry_meshing_bake(selected_asset_id, selected_component_id),
		"contour_result": geometry_meshing_preview if preview_matches else _geometry_meshing_bake(selected_asset_id, selected_component_id, ContourMeshService.METHOD),
		"advanced_relaxation_expanded": geometry_meshing_advanced_relaxation_expanded,
	}


func _render_inspector() -> void:
	_clear_inspector_content()
	EditorWidgets.clear(create_inspector_view)
	EditorWidgets.clear(geometry_inspector_view)
	EditorWidgets.clear(style_inspector_view)
	EditorWidgets.clear(motion_inspector_view)
	create_inspector_view.visible = false
	geometry_inspector_view.visible = false
	style_inspector_view.visible = false
	motion_inspector_view.visible = false
	if active_module == "Export":
		return
	if active_module == "Motion":
		motion_inspector_view.visible = true
		_sync_motion_models()
		motion_inspector_view.set_models(motion_workspace, motion_player, motion_selection)
		motion_inspector_view.set_context(_motion_inspector_context())
		motion_inspector_view.rebuild()
		if active_motion_submodule not in ["Path", "Act", "Sequence"]:
			_refresh_motion_asset_preview()
		return
	if active_module == "Style":
		style_inspector_view.visible = true
		style_inspector_view.set_context(_weighting_inspector_context())
		style_inspector_view.rebuild()
		return
	if active_module == "Mesh":
		geometry_inspector_view.visible = true
		geometry_inspector_view.set_submodule(active_geometry_submodule, world_contour_stroke_width_px)
		var mesh_component := _get_component(_get_asset(selected_asset_id), selected_component_id)
		if active_geometry_submodule == "Sampling":
			geometry_inspector_view.set_sampling_context(_geometry_sampling_inspector_context(mesh_component))
		elif active_geometry_submodule == "Seeding":
			geometry_inspector_view.set_seeding_context(_geometry_seeding_inspector_context(mesh_component))
		elif active_geometry_submodule == "Meshing":
			geometry_inspector_view.set_meshing_context(_geometry_meshing_inspector_context(mesh_component))
		geometry_inspector_view.rebuild()
		return
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty():
		return
	# Everything the Create Inspector draws from, resolved here so the view never
	# has to reach back into the editor.
	create_inspector_view.visible = true
	create_inspector_view.set_document(asset, world_contour_stroke_width_px)
	create_inspector_view.set_selection(selected_component_id, selected_group_id, selected_guide_id,
		selected_edge_id, selected_edge_ids.duplicate())
	create_inspector_view.set_resolved_selection(_selected_components_for_inspector(asset),
		_valid_selected_point_ids(_get_component(asset, selected_component_id)))
	create_inspector_view.set_member_asset_name(str(_selected_set_member_asset().get("name", "")))
	create_inspector_view.set_palette_variants(_palette_variant_rows(asset))
	create_inspector_view.set_mode(active_state, active_edit_mode, canvas_view.face_selected)
	create_inspector_view.rebuild()

func _selected_components_for_inspector(asset: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var candidates: Array[String] = selected_component_ids.duplicate()
	if candidates.is_empty() and not selected_component_id.is_empty():
		candidates.append(selected_component_id)
	if not selected_component_id.is_empty() and not candidates.has(selected_component_id):
		candidates.append(selected_component_id)
	var seen := {}
	for component_id in candidates:
		if seen.has(component_id):
			continue
		var component := _get_component(asset, component_id)
		if component.is_empty():
			continue
		seen[component_id] = true
		result.append(component)
	return result


func _on_multi_component_field_submitted(raw_value: String, _field: LineEdit, property_name: String, integer_only: bool) -> void:
	var value_text := raw_value.strip_edges()
	if value_text.is_empty():
		_invalidate_render(RENDER_INSPECTOR)
		return
	var value := value_text.to_float()
	if integer_only and not is_equal_approx(value, round(value)):
		_invalidate_render(RENDER_INSPECTOR)
		return
	if not is_finite(value):
		_invalidate_render(RENDER_INSPECTOR)
		return
	if property_name == "position_x" or property_name == "position_y":
		_on_multi_component_position_changed(value, property_name)
	elif property_name == "z_index":
		_on_multi_component_z_index_changed(value)
	elif property_name == "contour_width":
		_on_multi_component_contour_width_changed(value)
	elif property_name == "projection_depth":
		_on_multi_component_projection_depth_changed(value)


func _on_multi_component_field_focus_exited(field: LineEdit, property_name: String, integer_only: bool) -> void:
	_on_multi_component_field_submitted(field.text, field, property_name, integer_only)


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
	_invalidate_render(RENDER_CONTEXT_BAR)
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
	_invalidate_render(RENDER_CONTEXT_BAR)


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
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


func _on_motion_path_preview_asset_selected(index: int, option: OptionButton) -> void:
	if index < 0 or index >= option.item_count:
		return
	motion_path_preview_asset_id = str(option.get_item_metadata(index))
	motion_path_playing = false
	_refresh_motion_path_workspace()
	_invalidate_render(RENDER_CONTEXT_BAR | RENDER_INFO_BAR)


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
	_invalidate_render(RENDER_INSPECTOR | RENDER_CONTEXT_BAR)
	_refresh_motion_sequence_workspace()


func _on_motion_sequence_asset_selected(index: int, option: OptionButton) -> void:
	var entry := _resolved_motion_sequence_entry(_get_motion_sequence(selected_motion_sequence_id))
	if entry.is_empty() or index < 0 or index >= option.item_count:
		return
	_record_direct_change()
	entry["asset_id"] = str(option.get_item_metadata(index))
	entry["animation_state_id"] = _default_sequence_state_id(_get_asset(str(entry["asset_id"])))
	motion_sequence_playing = false
	_invalidate_render(RENDER_INSPECTOR | RENDER_CONTEXT_BAR)
	_refresh_motion_sequence_workspace()


func _on_motion_sequence_state_selected(index: int, option: OptionButton) -> void:
	var entry := _resolved_motion_sequence_entry(_get_motion_sequence(selected_motion_sequence_id))
	if entry.is_empty() or index < 0 or index >= option.item_count:
		return
	_record_direct_change()
	entry["animation_state_id"] = str(option.get_item_metadata(index))
	motion_sequence_playing = false
	_invalidate_render(RENDER_INSPECTOR | RENDER_CONTEXT_BAR)
	_refresh_motion_sequence_workspace()


func _on_motion_sequence_path_selected(index: int, option: OptionButton) -> void:
	var entry := _resolved_motion_sequence_entry(_get_motion_sequence(selected_motion_sequence_id))
	if entry.is_empty() or index < 0 or index >= option.item_count:
		return
	_record_direct_change()
	entry["path_id"] = str(option.get_item_metadata(index))
	motion_sequence_phase = 0.0
	motion_sequence_playing = false
	_invalidate_render(RENDER_INSPECTOR | RENDER_CONTEXT_BAR)
	_refresh_motion_sequence_workspace()


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


func _on_motion_selection_changed() -> void:
	_sync_motion_player_document(_get_asset(selected_asset_id))
	if motion_player != null and not motion_player.playing and not motion_selection.state_id.is_empty() and motion_player.current_state_id != motion_selection.state_id:
		motion_player.set_state(motion_selection.state_id)
	_invalidate_render(RENDER_INSPECTOR | RENDER_CONTEXT_BAR | RENDER_INFO_BAR)


func _sync_motion_player_document(asset: Dictionary) -> void:
	if motion_player == null:
		return
	if asset.is_empty():
		motion_player.pause()
		motion_player.set_document({})
		motion_player_asset_id = ""
		return
	var incoming_asset_id := str(asset.get("id", ""))
	var changed_asset := motion_player_asset_id != incoming_asset_id
	if changed_asset:
		motion_player.pause()
		motion_player.parameter_values.clear()
	motion_player.set_document(_ensure_asset_animation(asset))
	motion_player_asset_id = incoming_asset_id
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
	if is_instance_valid(motion_inspector_view.motion_asset_preview):
		motion_inspector_view.motion_asset_preview.set_runtime(motion_player.current_state_name(), motion_phase, motion_player.playing)
	_refresh_motion_asset_preview()


func _on_motion_player_state_changed(_previous_state_id: String, _state_id: String) -> void:
	if is_instance_valid(motion_runtime_state_label):
		motion_runtime_state_label.text = motion_player.current_state_name()
	if is_instance_valid(motion_phase_marks) and is_instance_valid(motion_workspace):
		motion_phase_marks.set_marker_phases(motion_workspace.marker_phases_for_state(motion_player.current_state_id))
	if is_instance_valid(motion_inspector_view.motion_asset_preview):
		motion_inspector_view.motion_asset_preview.set_runtime(motion_player.current_state_name(), motion_phase, motion_player.playing)
	_refresh_motion_asset_preview()
	_invalidate_render(RENDER_INFO_BAR)


func _on_motion_player_marker_fired(_state_id: String, event_id: String, kind: String) -> void:
	motion_last_marker = "%s · %s" % [kind.to_upper(), event_id]
	_show_status_message("Marker: %s" % motion_last_marker)
	_invalidate_render(RENDER_INFO_BAR)


func _on_motion_player_playback_changed(_playing: bool) -> void:
	if is_instance_valid(motion_play_button):
		motion_play_button.text = "❚❚" if motion_player.playing else "▶"
		motion_play_button.tooltip_text = "Pause Animation Preview" if motion_player.playing else "Play Animation Preview"
	if is_instance_valid(motion_inspector_view.motion_asset_preview):
		motion_inspector_view.motion_asset_preview.set_runtime(motion_player.current_state_name(), motion_phase, motion_player.playing)
	_refresh_motion_asset_preview()
	_invalidate_render(RENDER_INFO_BAR)


func _refresh_motion_asset_preview() -> void:
	if not is_instance_valid(motion_inspector_view.motion_asset_preview) or motion_player == null:
		return
	var asset := _get_asset(selected_asset_id)
	var component_ids: Array[String] = []
	for component in asset.get("components", []):
		if bool(component.get("visibility", true)):
			component_ids.append(str(component.get("id", "")))
	motion_inspector_view.motion_asset_preview.set_component_samples(MotionSampler.sample_player(motion_player, component_ids))


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
	_invalidate_render(RENDER_CONTEXT_BAR)


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
	_invalidate_render(RENDER_CANVAS_CONTEXT)


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
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)
	selected_edge_ids = restored_edge_ids.duplicate()
	selected_edge_id = selected_edge_ids[0]
	canvas_view.selected_edge_ids = restored_edge_ids.duplicate()
	canvas_view.selected_edge_id = canvas_view.selected_edge_ids[0]
	canvas_view.queue_redraw()


func _on_component_debug_point_numbers_toggled(enabled: bool) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		return
	_record_direct_change()
	component["show_point_numbers"] = enabled
	canvas_view.set_point_numbers_visible(enabled)
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


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
	_invalidate_render(RENDER_INSPECTOR)


func _on_selected_points_preserve_changed(enabled: bool, _point_ids: Array) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	var valid_ids := _valid_selected_point_ids(component)
	if component.is_empty() or valid_ids.is_empty():
		return
	_record_direct_change()
	for point_id in valid_ids:
		BezierTopology.point_by_id(component.get("points", []), point_id)["preserve_point"] = enabled
	_invalidate_render(RENDER_INSPECTOR)


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
	_invalidate_render(RENDER_INSPECTOR)


func _on_transform_value_changed(value: float, property_name: String) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty():
		return
	_record_direct_change()
	var transform: Dictionary = component.get("transform", WorldDocumentService.default_component_transform())
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
	_invalidate_render(RENDER_CANVAS_CONTEXT)


func _on_global_transform_value_changed(value: float, property_name: String) -> void:
	var asset := _get_asset(selected_asset_id)
	var component := _get_component(asset, selected_component_id)
	if component.is_empty() or property_name not in ["position_x", "position_y", "rotation", "scale_x", "scale_y"]:
		return
	_record_direct_change()
	var world_record := ComponentHierarchy.world_transform_record(asset, selected_component_id)
	if property_name in ["position_x", "position_y"]:
		value = _world_to_editor_units(value)
	var world_position: Vector2 = world_record.get("position", Vector2.ZERO)
	var world_scale: Vector2 = world_record.get("scale", Vector2.ONE)
	match property_name:
		"position_x": world_position.x = value
		"position_y": world_position.y = value
		"rotation": world_record["rotation"] = value
		"scale_x": world_scale.x = value
		"scale_y": world_scale.y = value
	world_record["position"] = world_position
	world_record["scale"] = world_scale
	component["transform"] = ComponentHierarchy.local_transform_from_world_record(asset, selected_component_id, world_record)
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


func _on_component_visibility_changed(visibility_enabled: bool) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not component.is_empty():
		_record_direct_change()
		component["visibility"] = visibility_enabled
		_invalidate_render(RENDER_OUTLINER | RENDER_CANVAS_CONTEXT)


func _on_region_geometry_source_selected(index: int, option: OptionButton) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not _is_region(component) or index < 0 or index >= option.item_count:
		return
	var source := WorldDocumentService.normalize_region_geometry_source(option.get_item_metadata(index))
	if source == WorldDocumentService.normalize_region_geometry_source(component.get("region_geometry_source", "")):
		return
	_record_direct_change()
	component["region_geometry_source"] = source
	active_state = ""
	active_draw_tool = ""
	active_context_command = ""
	selected_point_id = ""
	selected_point_ids.clear()
	selected_edge_id = ""
	selected_edge_ids.clear()
	canvas_view.clear_selection()
	_show_status_message("Region Geometry: %s" % ("Component Geometry" if source == WorldDocumentService.REGION_GEOMETRY_COMPONENT else "Free Draw"))
	_invalidate_render(RENDER_DOCUMENT)


func _on_multi_component_visibility_selected(index: int) -> void:
	if index < 0 or index > 1:
		return
	var asset := _get_asset(selected_asset_id)
	var components := _selected_components_for_inspector(asset)
	if asset.is_empty() or components.size() < 2:
		return
	var visibility_enabled := index == 0
	var changed := false
	for component in components:
		if bool(component.get("visibility", true)) != visibility_enabled:
			changed = true
			break
	if not changed:
		return
	_record_direct_change()
	for component in components:
		component["visibility"] = visibility_enabled
	_invalidate_render(RENDER_DOCUMENT)


func _on_circle_primitive_diameter_changed(value: float) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not PrimitiveGeometryService.has_circle(component):
		return
	_record_direct_change()
	component["primitive"]["diameter_cm"] = maxf(value, 0.1)
	_refresh_component_geometry(component)
	_invalidate_render(RENDER_CANVAS_CONTEXT)


func _on_ellipse_primitive_diameter_changed(value: float, property_name: String) -> void:
	_set_primitive_extent(PrimitiveGeometryService.ELLIPSE, value, property_name, ["diameter_x_cm", "diameter_y_cm"])


func _on_rectangle_primitive_size_changed(value: float, property_name: String) -> void:
	_set_primitive_extent(PrimitiveGeometryService.RECTANGLE, value, property_name, ["width_cm", "length_cm"])


func _on_triangle_primitive_size_changed(value: float, property_name: String) -> void:
	_set_primitive_extent(PrimitiveGeometryService.TRIANGLE, value, property_name, ["width_cm", "height_cm"])


## One authored extent of one shape. The shape and the field names are passed in
## so a field can never write a dimension that its shape does not own - an
## Ellipse diameter on a Rectangle would persist and then be ignored forever.
func _set_primitive_extent(shape: String, value: float, property_name: String, allowed_properties: Array) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if PrimitiveGeometryService.shape_type(component) != shape or property_name not in allowed_properties:
		return
	_record_direct_change()
	component["primitive"][property_name] = maxf(value, 0.1)
	_refresh_component_geometry(component)
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


func _on_rebase_asset_scales_pressed() -> void:
	var asset := _get_asset(selected_asset_id)
	var analysis := ComponentScaleRebaseService.analyze_asset(asset)
	if asset.is_empty() or not bool(analysis.get("can_rebase", false)):
		return
	_record_direct_change()
	var result := ComponentScaleRebaseService.rebase_asset(asset)
	if not bool(result.get("valid", false)):
		_show_status_message(str(result.get("errors", ["Scale Rebase failed."])[0]))
		return
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
	_show_status_message("Rebased %d Component and %d Group scale(s) in %s." % [result.get("rebased_component_ids", []).size(), result.get("rebased_group_ids", []).size(), str(asset.get("name", "Asset"))])
	_invalidate_render(RENDER_DOCUMENT)


func _on_asset_root_scale_changed(value: float, property_name: String) -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty() or property_name not in ["scale_x", "scale_y"] or not is_finite(value) or value <= AssetScaleRebaseService.SCALE_EPSILON:
		return
	var root_scale_value := AssetScaleRebaseService.root_scale(asset)
	var previous_scale := root_scale_value
	if property_name == "scale_x":
		root_scale_value.x = value
	else:
		root_scale_value.y = value
	if root_scale_value.is_equal_approx(previous_scale):
		return
	_record_coalesced_change()
	asset["root_scale"] = root_scale_value
	_invalidate_batch_status()
	if is_instance_valid(create_inspector_view.asset_root_scale_rebase_button):
		var analysis := AssetScaleRebaseService.analyze_asset(asset)
		create_inspector_view.asset_root_scale_rebase_button.disabled = not bool(analysis.get("can_rebase", false))
		create_inspector_view.asset_root_scale_rebase_button.tooltip_text = "Bake Root Position and independent X/Y Scale into Components, Groups, References, Guides, and Weapon Frames." if analysis.get("blockers", []).is_empty() else str(analysis.get("blockers", [""])[0])
	_invalidate_render(RENDER_CANVAS_CONTEXT)


func _on_rebase_asset_root_scale_pressed() -> void:
	var asset := _get_asset(selected_asset_id)
	var analysis := AssetScaleRebaseService.analyze_asset(asset)
	if asset.is_empty() or not bool(analysis.get("can_rebase", false)):
		return
	_record_direct_change()
	var result := AssetScaleRebaseService.rebase_asset(asset)
	if not bool(result.get("valid", false)):
		_show_status_message(str(result.get("errors", ["Asset Transform Rebase failed."])[0]))
		return
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
	_invalidate_batch_status()
	_show_status_message("Rebased Asset Root Transform in %s." % str(asset.get("name", "Asset")))
	_invalidate_render(RENDER_DOCUMENT)


func _on_asset_visibility_changed(visibility_enabled: bool, asset_id: String) -> void:
	var asset := _get_asset(asset_id)
	if asset.is_empty():
		return
	_record_direct_change()
	asset["visibility"] = visibility_enabled
	_invalidate_render(RENDER_OUTLINER | RENDER_CANVAS_CONTEXT)


func _on_asset_authored_facing_selected(index: int, option: OptionButton) -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty() or index < 0 or index >= option.item_count:
		return
	var selected_facing := AssetPresentation.deserialize_authored_facing(option.get_item_metadata(index))
	if AssetPresentation.authored_facing(asset) == selected_facing:
		return
	_record_direct_change()
	asset["authored_facing"] = selected_facing
	_invalidate_render(RENDER_INSPECTOR)


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
	_invalidate_render(RENDER_OUTLINER | RENDER_CANVAS_CONTEXT)


func _on_component_z_index_changed(value: float) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not component.is_empty():
		_record_direct_change()
		component["z_index"] = int(value)
		_invalidate_render(RENDER_CANVAS_CONTEXT)

func _on_component_projection_depth_changed(value: float) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or not is_finite(value) or value < 0.0:
		return
	var depth := snappedf(value, 0.1)
	if is_equal_approx(_component_projection_depth_cm(component), depth):
		return
	_record_direct_change()
	component["projection_depth_cm"] = depth
	_invalidate_render(RENDER_CANVAS_CONTEXT)


func _on_multi_component_position_changed(value: float, property_name: String) -> void:
	var asset := _get_asset(selected_asset_id)
	var components := _selected_components_for_inspector(asset)
	if asset.is_empty() or components.size() < 2 or property_name not in ["position_x", "position_y"]:
		return
	var desired_axis := _world_to_editor_units(value)
	var asset_pivot := _asset_pivot(asset)
	var targets: Array[Dictionary] = []
	for component in components:
		var component_id := str(component.get("id", ""))
		var world_record := ComponentHierarchy.world_transform_record(asset, component_id)
		var world_position: Vector2 = world_record.get("position", Vector2.ZERO)
		var relative := world_position - asset_pivot
		if property_name == "position_x":
			relative.x = desired_axis
		else:
			relative.y = desired_axis
		world_record["position"] = asset_pivot + relative
		targets.append({"id": component_id, "world": world_record})
	var ordered_targets := targets.duplicate()
	ordered_targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _component_hierarchy_depth(asset, str(a.get("id", ""))) < _component_hierarchy_depth(asset, str(b.get("id", "")))
	)
	var changed := false
	for target in ordered_targets:
		var current_world := ComponentHierarchy.world_transform_record(asset, str(target.get("id", "")))
		if not Vector2(current_world.get("position", Vector2.ZERO)).is_equal_approx(Vector2(target.get("world", {}).get("position", Vector2.ZERO))):
			changed = true
			break
	if not changed:
		return
	_record_direct_change()
	for target in ordered_targets:
		var component := _get_component(asset, str(target.get("id", "")))
		var next_transform: Dictionary = ComponentHierarchy.local_transform_from_world_record(asset, str(target.get("id", "")), target.get("world", {}))
		component["transform"] = next_transform
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


func _component_hierarchy_depth(asset: Dictionary, component_id: String) -> int:
	var depth := 0
	var current_id := component_id
	var visited := {}
	while not current_id.is_empty() and not visited.has(current_id):
		visited[current_id] = true
		var component := _get_component(asset, current_id)
		if component.is_empty():
			break
		current_id = str(component.get("parent_component_id", ""))
		if not current_id.is_empty():
			depth += 1
	return depth


func _on_component_contour_stroke_width_changed(value: float) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or not is_finite(value) or value <= 0.0:
		return
	if is_equal_approx(value, world_contour_stroke_width_px):
		if not component.has("contour_stroke_width_px"):
			return
		_record_direct_change()
		component.erase("contour_stroke_width_px")
	elif _component_has_contour_stroke_width_override(component) and is_equal_approx(float(component["contour_stroke_width_px"]), value):
		return
	else:
		_record_direct_change()
		component["contour_stroke_width_px"] = value
	geometry_meshing_preview = {}
	geometry_meshing_preview_key = ""
	geometry_meshing_preview_state = "idle"
	geometry_meshing_preview_revision += 1
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


## Centered is the absence of a decision rather than one of three stored
## values, so choosing it erases the key. A Component that never had one and a
## Component set back to centered are then the same document.
func _on_component_contour_stroke_alignment_selected(index: int, option: OptionButton) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or index < 0 or index >= option.item_count:
		return
	var alignment := str(option.get_item_metadata(index))
	if not alignment in ContourStrokeService.ALIGNMENTS or alignment == WorldDocumentService.contour_stroke_alignment(component):
		return
	_record_direct_change()
	if alignment == ContourStrokeService.ALIGNMENT_CENTERED:
		component.erase("contour_stroke_alignment")
	else:
		component["contour_stroke_alignment"] = alignment
	geometry_meshing_preview = {}
	geometry_meshing_preview_key = ""
	geometry_meshing_preview_state = "idle"
	geometry_meshing_preview_revision += 1
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


func _on_multi_component_z_index_changed(value: float) -> void:
	var asset := _get_asset(selected_asset_id)
	var components := _selected_components_for_inspector(asset)
	if asset.is_empty() or components.size() < 2 or not is_finite(value):
		return
	var layer_z_index := int(value)
	var changed := false
	for component in components:
		if int(component.get("z_index", 0)) != layer_z_index:
			changed = true
			break
	if not changed:
		return
	_record_direct_change()
	for component in components:
		component["z_index"] = layer_z_index
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


func _on_multi_component_contour_width_changed(value: float) -> void:
	var asset := _get_asset(selected_asset_id)
	var components := _selected_components_for_inspector(asset)
	if asset.is_empty() or components.size() < 2 or not is_finite(value) or value <= 0.0:
		return
	var use_default := is_equal_approx(value, world_contour_stroke_width_px)
	var changed := false
	for component in components:
		if use_default:
			if component.has("contour_stroke_width_px"):
				changed = true
				break
		elif not _component_has_contour_stroke_width_override(component) or not is_equal_approx(float(component.get("contour_stroke_width_px", 0.0)), value):
			changed = true
			break
	if not changed:
		return
	_record_direct_change()
	for component in components:
		if use_default:
			component.erase("contour_stroke_width_px")
		else:
			component["contour_stroke_width_px"] = value
	geometry_meshing_preview = {}
	geometry_meshing_preview_key = ""
	geometry_meshing_preview_state = "idle"
	geometry_meshing_preview_revision += 1
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


func _on_multi_component_projection_depth_changed(value: float) -> void:
	var asset := _get_asset(selected_asset_id)
	var components := _selected_components_for_inspector(asset)
	if asset.is_empty() or components.size() < 2 or not is_finite(value) or value < 0.0:
		return
	var depth := snappedf(value, 0.1)
	var changed := false
	for component in components:
		if not is_equal_approx(_component_projection_depth_cm(component), depth):
			changed = true
			break
	if not changed:
		return
	_record_direct_change()
	for component in components:
		component["projection_depth_cm"] = depth
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


func _rename_selected_component(new_name: String) -> void:
	var asset := _get_asset(selected_asset_id)
	var component := _get_component(asset, selected_component_id)
	var component_name := new_name.strip_edges()
	if component.is_empty():
		return
	var name_error := _component_name_validation_error(component_name, asset, selected_component_id)
	if not name_error.is_empty():
		if is_instance_valid(create_inspector_view.component_name_editor):
			create_inspector_view.component_name_editor.text = _normalized_component_name(component)
		_show_status_message(name_error)
		return
	if component_name == str(component.get("name", "")):
		return
	_record_direct_change()
	component["name"] = component_name
	_invalidate_render(RENDER_DOCUMENT)


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


func _create_export_workspace(parent: Control) -> void:
	# The Export work surface is a view: it owns its controls and the three
	# toolbar actions, and it is fed a finished context. Everything the context
	# is made of stays here.
	runtime_export_view = RuntimeExportView.new()
	parent.add_child(runtime_export_view)
	runtime_export_view.set_toolbar_buttons(export_run_button, export_valid_button, export_sync_button)
	runtime_export_view.build_all_requested.connect(_on_build_all_pressed)
	runtime_export_view.export_all_valid_requested.connect(_on_export_all_valid_pressed)
	runtime_export_view.sync_consumers_requested.connect(_on_sync_consumers_pressed)


func _refresh_export_preflight(force := false) -> void:
	if not is_instance_valid(runtime_export_view) or active_module != "Export" or export_running:
		return
	if not force and export_preflight_revision == batch_status_revision:
		return
	export_preflight = _rebuild_batch_status_snapshot()
	export_preflight_revision = batch_status_revision
	_render_export_preflight()


func _render_export_preflight() -> void:
	if not is_instance_valid(runtime_export_view):
		return
	runtime_export_view.set_context(_runtime_export_context())
	runtime_export_view.rebuild()


func _runtime_export_context() -> Dictionary:
	# Everything the Export view draws, already decided: it counts nothing,
	# resolves nothing and looks nothing up.
	var mesh: Dictionary = export_preflight.get("mesh", {})
	var runtime: Dictionary = export_preflight.get("runtime", {})
	var pending := (mesh.get("candidates", []) as Array).size() + (runtime.get("candidates", []) as Array).size()
	var issues := _export_attention_count(mesh) + _export_attention_count(runtime)
	return {
		"summary": "Preflight abgeschlossen · %d ausstehende Arbeitsschritte · %d Auffälligkeiten" % [pending, issues],
		"consumer_sync": "",
		"stages": [_runtime_export_stage_context("Mesh", mesh),
			_runtime_export_stage_context("Runtime Export", runtime)],
		"all_current": pending == 0 and issues == 0,
		"toolbar": _runtime_export_toolbar_context(),
	}


func _runtime_export_stage_context(title: String, status: Dictionary) -> Dictionary:
	# The heading counts candidates while the list shows the lines the batch
	# summary produced; the two are not the same number and never were.
	var summary: Dictionary = status.get("summary", {})
	return {
		"title": title,
		"candidate_count": (status.get("candidates", []) as Array).size(),
		"pending": summary.get("pending", PackedStringArray()),
		"attention": summary.get("attention", PackedStringArray()),
	}


func _runtime_export_toolbar_context() -> Dictionary:
	var export_active := active_module == "Export"
	if not export_active:
		return {"build_all": {"visible": false}, "export_all_valid": {"visible": false},
			"sync_consumers": {"visible": false}}
	var preflight_current := export_preflight_revision == batch_status_revision
	var build_count := _export_build_count() if preflight_current else 0
	var valid_export_count := _export_valid_count() if preflight_current else 0
	return {
		"build_all": {"visible": true, "text": "Build All (%d)" % build_count,
			"disabled": export_running or not preflight_current or build_count == 0},
		"export_all_valid": {"visible": true, "text": "Export All Valid (%d)" % valid_export_count,
			"disabled": export_running or not preflight_current or valid_export_count == 0},
		"sync_consumers": {"visible": true, "text": "Sync Consumers",
			"disabled": export_running or not _consumer_sync_available()},
	}


func _export_attention_count(status: Dictionary) -> int:
	var summary: Dictionary = status.get("summary", {})
	return (summary.get("attention", PackedStringArray()) as PackedStringArray).size()


func _update_export_toolbar_buttons() -> void:
	if is_instance_valid(runtime_export_view):
		runtime_export_view.apply_toolbar_state(_runtime_export_toolbar_context())


func _export_build_count() -> int:
	var unique_components := {}
	for stage in ["mesh"]:
		var status: Dictionary = export_preflight.get(stage, {})
		for candidate in status.get("candidates", []):
			unique_components["%s/%s" % [str(candidate.get("asset_id", "")), str(candidate.get("component_id", ""))]] = true
	return unique_components.size()


func _export_valid_count() -> int:
	var runtime: Dictionary = export_preflight.get("runtime", {})
	var count := 0
	for candidate in runtime.get("candidates", []):
		var build: Dictionary = candidate.get("build", {})
		if bool(build.get("valid", false)):
			count += 1
	return count


func _on_build_all_pressed() -> void:
	if export_running:
		return
	export_running = true
	mesh_batch_running = true
	export_run_button.disabled = true
	export_valid_button.disabled = true
	export_sync_button.disabled = true
	runtime_export_view.clear_log()
	runtime_export_view.append_log_line("[b]Build All[/b]\n")
	runtime_export_view.append_log_line("[color=#9aa3b2]Verarbeite alle validen Einträge. Fehlerhafte Einträge werden übersprungen; Export wird nicht gestartet.[/color]\n")
	var mesh_candidates := _all_mesh_update_candidates()
	var history_recorded := not mesh_candidates.is_empty()
	if history_recorded:
		_record_direct_change()
	var mesh_result := await _run_export_mesh_stage(mesh_candidates)
	mesh_batch_running = false
	_save_world()
	batch_status_snapshot = {}
	export_preflight = _rebuild_batch_status_snapshot()
	export_preflight_revision = batch_status_revision
	var succeeded := int(mesh_result.get("succeeded", 0))
	var failed := int(mesh_result.get("failed", 0))
	var remaining_issues := _export_attention_count(export_preflight.get("mesh", {})) + _export_attention_count(export_preflight.get("runtime", {}))
	runtime_export_view.set_summary_text("Build abgeschlossen · %d erfolgreiche Schritte · %d Probleme" % [succeeded, failed + remaining_issues])
	runtime_export_view.append_log_line("\n[b]Ergebnis[/b]\n")
	runtime_export_view.append_log_line("[color=#75b88a]• %d Schritte erfolgreich abgeschlossen[/color]\n" % succeeded)
	if failed + remaining_issues > 0:
		runtime_export_view.append_log_line("[color=#ef8354]• %d Einträge konnten nicht verarbeitet werden oder brauchen Aufmerksamkeit[/color]\n" % [failed + remaining_issues])
	else:
		runtime_export_view.append_log_line("[color=#75b88a]• Keine Fehler festgestellt[/color]\n")
	if remaining_issues > 0:
		runtime_export_view.append_log_line("\n[b]Verbleibende Auffälligkeiten[/b]\n")
		_append_export_attention("Mesh", export_preflight.get("mesh", {}))
		_append_export_attention("Runtime Export", export_preflight.get("runtime", {}))
	export_running = false
	_update_export_toolbar_buttons()
	_invalidate_render(RENDER_DOCUMENT)


func _on_export_all_valid_pressed() -> void:
	if export_running:
		return
	export_running = true
	runtime_export_batch_running = true
	export_run_button.disabled = true
	export_valid_button.disabled = true
	export_sync_button.disabled = true
	runtime_export_view.clear_log()
	runtime_export_view.append_log_line("[b]Export All Valid[/b]\n")
	runtime_export_view.append_log_line("[color=#9aa3b2]Exportiere nur aktuell valide Runtime-Pakete. Auffällige Einträge bleiben ausgeschlossen.[/color]\n")
	var result := await _run_export_runtime_stage(true)
	runtime_export_batch_running = false
	_invalidate_batch_status()
	batch_status_snapshot = {}
	export_preflight = _rebuild_batch_status_snapshot()
	export_preflight_revision = batch_status_revision
	var succeeded := int(result.get("succeeded", 0))
	var failed := int(result.get("failed", 0))
	var remaining_issues := _export_attention_count(export_preflight.get("runtime", {}))
	runtime_export_view.set_summary_text("Export abgeschlossen · %d Runtime-Pakete exportiert · %d Probleme" % [succeeded, failed + remaining_issues])
	runtime_export_view.append_log_line("\n[b]Ergebnis[/b]\n")
	runtime_export_view.append_log_line("[color=#75b88a]• %d Runtime-Pakete exportiert[/color]\n" % succeeded)
	if failed + remaining_issues > 0:
		runtime_export_view.append_log_line("[color=#ef8354]• %d Einträge wurden nicht exportiert oder brauchen Aufmerksamkeit[/color]\n" % [failed + remaining_issues])
		_append_export_attention("Runtime Export", export_preflight.get("runtime", {}))
	export_running = false
	_update_export_toolbar_buttons()
	_invalidate_render(RENDER_DOCUMENT)


func _run_export_mesh_stage(candidates: Array[Dictionary]) -> Dictionary:
	var succeeded := 0
	var failed := 0
	runtime_export_view.append_log_line("\n[b]Mesh[/b] · %d Kandidaten\n" % candidates.size())
	for candidate in candidates:
		await get_tree().process_frame
		var asset_id := str(candidate.get("asset_id", ""))
		var component_id := str(candidate.get("component_id", ""))
		var build := _generate_component_mesh_build(asset_id, component_id)
		var label := _export_component_label(asset_id, component_id)
		if bool(build.get("valid", false)):
			var component := _get_component(_get_asset(asset_id), component_id)
			var signature := _geometry_build_signature(asset_id, component_id, component, build.get("recipes", {}))
			if GeometryAutoBuildService.signatures_match(signature, build.get("source_signature", {})):
				_commit_component_mesh_build(asset_id, component_id, build)
				succeeded += 1
				runtime_export_view.append_log_line("  [color=#75b88a]✓ %s[/color]\n" % label)
			else:
				build["errors"] = ["Component changed while its Mesh was being generated."]
				_record_component_mesh_failure(asset_id, component_id, build)
				failed += 1
				runtime_export_view.append_log_line("  [color=#ef8354]✕ %s — %s[/color]\n" % [label, build["errors"][0]])
		else:
			_record_component_mesh_failure(asset_id, component_id, build)
			failed += 1
			var errors: Array = build.get("errors", [])
			runtime_export_view.append_log_line("  [color=#ef8354]✕ %s — %s[/color]\n" % [label, str(errors[0]) if not errors.is_empty() else "Mesh generation failed."])
	return {"succeeded": succeeded, "failed": failed}


func _run_export_runtime_stage(valid_only := false) -> Dictionary:
	var succeeded := 0
	var failed := 0
	var candidates := _all_valid_runtime_export_candidates() if valid_only else _all_runtime_export_candidates()
	var catalog_requested := false
	runtime_export_view.append_log_line("\n[b]Runtime Export[/b] · %d Kandidaten\n" % candidates.size())
	for candidate in candidates:
		await get_tree().process_frame
		if str(candidate.get("kind", "package")) == "catalog":
			catalog_requested = true
			continue
		var asset := _get_asset(str(candidate.get("asset_id", "")))
		var build := _runtime_export_build(asset)
		var label := str(asset.get("name", "Asset"))
		if bool(build.get("valid", false)) and _write_runtime_export_package(asset, build):
			succeeded += 1
			runtime_export_view.append_log_line("  [color=#75b88a]✓ %s[/color]\n" % label)
		else:
			failed += 1
			var errors: Array = build.get("errors", [])
			runtime_export_view.append_log_line("  [color=#ef8354]✕ %s — %s[/color]\n" % [label, str(errors[0]) if not errors.is_empty() else "Runtime export failed."])
	if catalog_requested or succeeded > 0:
		if not _has_pending_valid_runtime_packages() and _write_asset_catalog():
			_prune_uncataloged_runtime_packages()
			runtime_export_view.append_log_line("  [color=#75b88a]✓ World Catalog[/color]\n")
		else:
			failed += 1
			runtime_export_view.append_log_line("  [color=#ef8354]✕ World Catalog — catalog.json could not be updated.[/color]\n")
	return {"succeeded": succeeded, "failed": failed}


func _consumer_sync_script_path() -> String:
	return ProjectSettings.globalize_path(CONSUMER_SYNC_SCRIPT)


func _consumer_sync_available() -> bool:
	var catalog_path := _asset_catalog_path()
	return not catalog_path.is_empty() and FileAccess.file_exists(catalog_path) and FileAccess.file_exists(_consumer_sync_script_path())


func _on_sync_consumers_pressed() -> void:
	if export_running or not _consumer_sync_available():
		return
	export_running = true
	_update_export_toolbar_buttons()
	runtime_export_view.clear_log()
	var result := await _run_consumer_sync()
	var success := bool(result.get("success", false))
	runtime_export_view.set_summary_text("Consumer Sync: Success" if success else "Consumer Sync: FAILED")
	_show_status_message("Consumer Sync erfolgreich" if success else "Consumer Sync fehlgeschlagen · Details im Export-Arbeitsbereich")
	export_running = false
	_update_export_toolbar_buttons()


func _run_consumer_sync() -> Dictionary:
	var script_path := _consumer_sync_script_path()
	if not FileAccess.file_exists(script_path):
		var missing_result := {"success": false, "exit_code": -1, "output": "Sync script not found: %s" % script_path}
		_present_consumer_sync_result(missing_result)
		return missing_result
	runtime_export_view.set_consumer_sync_text("Consumer Sync · läuft …", Color("#e3b341"))
	_show_status_message("Consumer Sync läuft …")
	await get_tree().process_frame
	var output: Array = []
	var exit_code := OS.execute("/bin/bash", [script_path], output, true)
	var output_lines := PackedStringArray()
	for line in output:
		output_lines.append(str(line))
	var result := {
		"success": exit_code == 0,
		"exit_code": exit_code,
		"output": "\n".join(output_lines).strip_edges(),
		"steps": _parse_consumer_sync_steps(output_lines)
	}
	_present_consumer_sync_result(result)
	return result


func _parse_consumer_sync_steps(lines: PackedStringArray) -> Array:
	# Turns the "STEP|index|total|status|title|reason" lines
	# sync_world01_consumers.sh prints once per run into one Dictionary per
	# step, so the Export log can draw a plain Success/FAILED/WARNING line per
	# step instead of the "N/4" text the script also prints for anyone reading
	# its output by hand. maxsplit 5 keeps a stray "|" inside reason intact.
	var steps: Array = []
	for line in lines:
		if not line.begins_with("STEP|"):
			continue
		var parts := line.split("|", true, 5)
		if parts.size() < 6:
			continue
		steps.append({"index": int(parts[1]), "total": int(parts[2]), "status": parts[3], "title": parts[4], "reason": parts[5]})
	return steps


func _present_consumer_sync_result(result: Dictionary) -> void:
	var success := bool(result.get("success", false))
	runtime_export_view.set_consumer_sync_text(
		"Consumer Sync · erfolgreich · SceneMaker und world01 sind aktuell" if success else "Consumer Sync · fehlgeschlagen · Details im Export-Protokoll",
		Color("#75b88a") if success else Color("#ef8354"))
	if not is_instance_valid(runtime_export_view):
		return
	var steps: Array = result.get("steps", [])
	runtime_export_view.append_log_line(_consumer_sync_steps_bbcode(steps) if not steps.is_empty() else _consumer_sync_fallback_bbcode(result))


func _consumer_sync_steps_bbcode(steps: Array) -> String:
	# One line per Consumer Sync step. Colour is the only signal that matters:
	# green Success, red FAILED with its short reason, orange WARNING for a step
	# skipped because something it needed failed. No counts, no raw command
	# output - a result should be readable by its colour alone.
	var bbcode := ""
	for step in steps:
		if not (step is Dictionary):
			continue
		var title := str(step.get("title", ""))
		var suffix := _consumer_sync_reason_suffix(str(step.get("reason", "")))
		match str(step.get("status", "")):
			"applied":
				bbcode += "[color=#75b88a]%s: Success[/color]\n" % title
			"failed":
				bbcode += "[color=#ef8354]%s: FAILED%s[/color]\n" % [title, suffix]
			"blocked":
				bbcode += "[color=#e3b341]%s: WARNING%s[/color]\n" % [title, suffix]
			_:
				bbcode += "[color=#9aa3b2]%s: %s[/color]\n" % [title, str(step.get("status", ""))]
	return bbcode


func _consumer_sync_reason_suffix(reason: String) -> String:
	return "" if reason.is_empty() else " — %s" % reason


func _consumer_sync_fallback_bbcode(result: Dictionary) -> String:
	# Steps are only missing when the script could not even start (e.g. the
	# script file itself is absent) - still exactly one coloured line, never
	# silence.
	if bool(result.get("success", false)):
		return "[color=#75b88a]Consumer Sync: Success[/color]\n"
	var output_text := str(result.get("output", "")).strip_edges()
	var reason := output_text.split("\n")[0] if not output_text.is_empty() else "Exit %d" % int(result.get("exit_code", -1))
	return "[color=#ef8354]Consumer Sync: FAILED — %s[/color]\n" % reason


func _all_valid_runtime_export_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate in _all_runtime_export_candidates():
		var build: Dictionary = candidate.get("build", {})
		if bool(build.get("valid", false)):
			result.append(candidate)
	return result


func _has_pending_valid_runtime_packages() -> bool:
	for candidate in _all_runtime_package_candidates():
		if bool(candidate.get("build", {}).get("valid", false)):
			return true
	return false


func _export_component_label(asset_id: String, component_id: String) -> String:
	var asset := _get_asset(asset_id)
	var component := _get_component(asset, component_id)
	return "%s / %s" % [str(asset.get("name", "Asset")), str(component.get("name", "Component"))]


func _append_export_attention(stage: String, status: Dictionary) -> void:
	var summary: Dictionary = status.get("summary", {})
	var attention: PackedStringArray = summary.get("attention", PackedStringArray())
	for line in attention:
		runtime_export_view.append_log_line("  [color=#ef8354]• %s · %s[/color]\n" % [stage, line])


func _render_canvas_context() -> void:
	canvas_view.set_transform_axes_local(false)
	_sync_asset_camera(selected_asset_id if active_module == "Create" else "")
	if active_module == "Motion" and active_motion_submodule == "Animation":
		_sync_motion_player_document(_get_asset(selected_asset_id))
	_render_context_bar()
	_render_info_bar()
	if not is_instance_valid(canvas_context_label):
		return
	canvas_view.set_reference_image(null)
	canvas_view.set_guide_style(false)
	canvas_view.set_bezier_color_override(Color.TRANSPARENT)
	canvas_view.set_point_numbers_visible(false)
	canvas_view.set_catch_parent_component("")
	canvas_view.set_component_draw_mode(WorldDocumentService.DRAW_MODE_CLOSED_LOOP)
	canvas_view.clear_draw_constraint()
	geometry_sampling_workspace.visible = false
	geometry_seeding_workspace.visible = false
	geometry_meshing_workspace.visible = false
	weighting_workspace.visible = false
	if is_instance_valid(runtime_export_view):
		runtime_export_view.visible = active_module == "Export"
	if is_instance_valid(outliner_panel):
		outliner_panel.visible = active_module != "Export"
	if is_instance_valid(inspector_panel):
		inspector_panel.visible = active_module != "Export"
	if is_instance_valid(context_bar_panel):
		context_bar_panel.visible = active_module != "Export"
	if active_module == "Export":
		canvas_view.visible = false
		motion_workspace.visible = false
		motion_path_workspace.visible = false
		motion_act_workspace.visible = false
		motion_sequence_workspace.visible = false
		canvas_context_label.text = ""
		_refresh_export_preflight()
		return
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
	if is_instance_valid(outliner_panel):
		outliner_panel.visible = true
	if is_instance_valid(inspector_panel):
		inspector_panel.visible = true
	if active_module == "Mesh":
		motion_workspace.visible = false
		canvas_view.visible = false
		geometry_sampling_workspace.visible = active_geometry_submodule == "Sampling"
		geometry_seeding_workspace.visible = active_geometry_submodule == "Seeding"
		geometry_meshing_workspace.visible = active_geometry_submodule == "Meshing"
		if active_geometry_submodule == "Sampling":
			_refresh_geometry_sampling_workspace()
		elif active_geometry_submodule == "Seeding":
			_refresh_geometry_seeding_workspace()
		elif active_geometry_submodule == "Meshing":
			_refresh_geometry_meshing_workspace()
		canvas_context_label.text = "" if active_geometry_submodule in ["Sampling", "Seeding", "Meshing"] else "Mesh → %s · Placeholder" % active_geometry_submodule
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
			if AssetGuide.is_weapon_frame(str(selected_guide.get("guide_type", ""))):
				_render_weapon_guide_canvas(asset, selected_guide)
				return
			_render_spine_canvas(asset, selected_guide, active_state == "draw" and active_draw_tool == "spine")
			return
	if not selected_group_id.is_empty():
		var selected_group := ComponentHierarchy.group_by_id(asset, selected_group_id)
		if not selected_group.is_empty():
			canvas_context_label.text = "Group: %s" % str(selected_group.get("name", "Group"))
			canvas_view.set_context(str(selected_group.get("name", "Group")))
			canvas_view.set_interaction_state("")
			canvas_view.set_tool_mode("")
			canvas_view.set_component_transform(_asset_preview_world_record(asset, ComponentHierarchy.group_world_transform_record(asset, selected_group_id)))
			canvas_view.set_reference_shapes(_build_reference_shapes(asset))
			canvas_view.set_display_polygon([])
			canvas_view.set_bezier_geometry([], [], [])
			canvas_view.call_deferred("grab_focus")
			return
	if selected_component_id.is_empty():
		canvas_context_label.text = "Asset: %s" % str(asset["name"])
		canvas_view.set_context(str(asset["name"]))
		canvas_view.set_interaction_state("asset")
		canvas_view.set_asset_pivot(AssetScaleRebaseService.root_transform(asset) * _asset_pivot(asset))
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
		canvas_view.set_tool_mode("")
		canvas_view.set_component_transform({})
		canvas_view.set_reference_shapes(_build_reference_shapes(asset, "", selected_component_id))
		canvas_view.set_display_polygon([])
		canvas_view.set_bezier_geometry([], [], [])
		canvas_view.call_deferred("grab_focus")
		return
	if _is_reference_component(component):
		# In a Set the Reference is how a member hangs in the assembly, so the
		# Canvas names the member Asset and leaves the derived Reference name
		# to the Inspector.
		var reference_context := str(component.get("name", "Reference"))
		if WorldDocumentService.is_set_asset(asset) and str(component.get("parent_component_id", "")).is_empty():
			reference_context = str(_get_asset(str(component.get("source_asset_id", ""))).get("name", reference_context))
			canvas_context_label.text = "Member: %s" % reference_context
		else:
			canvas_context_label.text = "Reference: %s" % reference_context
		canvas_view.set_context(reference_context)
		canvas_view.set_interaction_state("transform")
		canvas_view.set_tool_mode("")
		canvas_view.set_component_transform(_asset_preview_world_record(asset, ComponentHierarchy.world_transform_record(asset, selected_component_id)))
		canvas_view.set_reference_shapes(_build_reference_shapes(asset))
		canvas_view.set_display_polygon([])
		canvas_view.set_bezier_geometry([], [], [])
		return
	var inherited_region_geometry := _region_uses_component_geometry(component)
	var display_component := _get_component(asset, str(component.get("parent_component_id", ""))) if inherited_region_geometry else component
	if display_component.is_empty():
		display_component = component
	canvas_context_label.text = "%s Region: %s%s" % [str(component.get("region_type", "attack")).capitalize(), str(component["name"]), " · Component Geometry" if inherited_region_geometry else ""] if _is_region(component) else "Component: %s" % str(component["name"])
	canvas_view.set_context(str(component["name"]))
	if inherited_region_geometry:
		active_state = ""
		active_draw_tool = ""
		active_context_command = ""
		selected_point_id = ""
		selected_point_ids.clear()
		selected_edge_id = ""
		selected_edge_ids.clear()
		canvas_view.clear_selection()
	canvas_view.set_interaction_state("" if inherited_region_geometry else active_state)
	if active_state == "edit" and not inherited_region_geometry:
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
	var display_component_id := str(display_component.get("id", selected_component_id))
	var component_transform := _asset_preview_world_record(asset, ComponentHierarchy.world_transform_record(asset, display_component_id))
	component_transform["visibility"] = bool(asset.get("visibility", true)) and _effective_component_visibility(asset, component)
	component_transform["z_index"] = _effective_component_z_index(asset, component)
	canvas_view.set_component_transform(component_transform)
	canvas_view.set_reference_shapes(_build_reference_shapes(asset, display_component_id))
	if _is_region(component):
		canvas_view.set_bezier_color_override(EditorWidgets.REGION_COLORS.get(str(component.get("region_type", "attack")), EditorWidgets.REGION_COLORS["attack"]))
	canvas_view.set_component_draw_mode(WorldDocumentService.component_draw_mode(display_component))
	canvas_view.set_point_numbers_visible(bool(component.get("show_point_numbers", false)))
	var catch_parent_id := str(display_component.get("parent_component_id", ""))
	if catch_parent_id.is_empty() and WorldDocumentService.is_contour(display_component):
		catch_parent_id = str(display_component.get("catch_parent_component_id", ""))
	canvas_view.set_catch_parent_component(catch_parent_id)
	BezierGeometry.resolve_auto_handles(display_component.get("points", []), display_component.get("chains", []))
	_refresh_component_geometry(display_component)
	canvas_view.set_selected_point_ids(selected_point_ids)
	canvas_view.set_selected_edge_id(selected_edge_id)
	canvas_view.call_deferred("grab_focus")


func _render_spine_canvas(asset: Dictionary, guide: Dictionary, drawing: bool) -> void:
	var target_component_id := AssetGuide.scope_component_id(guide)
	var target_component := _get_component(asset, target_component_id)
	var type_name := AssetGuide.display_name(str(guide.get("guide_type", AssetGuide.SAMPLER_SPINE)))
	var guide_name := WorldDocumentService.guide_display_name(asset, guide)
	canvas_context_label.text = "%s: %s%s" % [type_name, guide_name, " · Draft" if drawing else ""]
	canvas_view.set_context(guide_name)
	canvas_view.set_guide_style(true)
	canvas_view.set_guide_color(AssetGuide.color(str(guide.get("guide_type", AssetGuide.SAMPLER_SPINE))))
	canvas_view.set_reference_shapes(_build_reference_shapes(asset, "", target_component_id))
	canvas_view.set_display_polygon([])
	BezierGeometry.resolve_auto_handles(guide.get("points", []), guide.get("chains", []))
	canvas_view.set_bezier_geometry(guide.get("points", []), guide.get("edges", []), guide.get("chains", []))
	canvas_view.set_selected_point_ids(selected_point_ids)
	if target_component.is_empty():
		canvas_view.set_component_transform(WorldDocumentService.default_component_transform())
	else:
		var target_transform := _asset_preview_world_record(asset, ComponentHierarchy.world_transform_record(asset, target_component_id))
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


func _weapon_guide_world_transform_record(asset: Dictionary, guide: Dictionary) -> Dictionary:
	var affine := ComponentHierarchy.guide_world_transform(asset, guide) * ComponentHierarchy.local_transform(guide.get("transform", {}))
	return _asset_preview_world_record(asset, ComponentHierarchy.transform_record_from_affine(affine, Vector2.ZERO))


func _asset_preview_world_record(asset: Dictionary, record: Dictionary) -> Dictionary:
	var pivot := Vector2(record.get("pivot", Vector2.ZERO))
	var affine := AssetScaleRebaseService.root_transform(asset) * ComponentHierarchy.local_transform(record)
	return ComponentHierarchy.transform_record_from_affine(affine, pivot)


func _asset_unpreview_world_record(asset: Dictionary, record: Dictionary) -> Dictionary:
	var pivot := Vector2(record.get("pivot", Vector2.ZERO))
	var affine := AssetScaleRebaseService.root_transform(asset).affine_inverse() * ComponentHierarchy.local_transform(record)
	return ComponentHierarchy.transform_record_from_affine(affine, pivot)


func _render_weapon_guide_canvas(asset: Dictionary, guide: Dictionary) -> void:
	var guide_type := str(guide.get("guide_type", ""))
	canvas_context_label.text = "Weapon Guide: %s" % guide_type
	canvas_view.set_context(guide_type)
	canvas_view.set_guide_style(true)
	canvas_view.set_guide_color(AssetGuide.color(guide_type))
	canvas_view.set_reference_shapes(_build_reference_shapes(asset))
	canvas_view.set_display_polygon([])
	canvas_view.set_bezier_geometry([], [], [])
	canvas_view.set_component_transform(_weapon_guide_world_transform_record(asset, guide))
	# A Weapon Guide has no geometry, so the gizmo is the only thing that
	# can show the authored frame rotation. Its axes therefore turn with
	# the frame, unlike the world-parallel axes of a Component or Group.
	canvas_view.set_transform_axes_local(true)
	canvas_view.set_interaction_state("transform")
	canvas_view.set_transform_mode(active_transform_mode if active_transform_mode in ["transform", "rotate"] else "transform")
	canvas_view.set_tool_mode("")
	canvas_view.call_deferred("grab_focus")


func _set_reference_image_canvas(asset: Dictionary) -> void:
	var reference_image := WorldDocumentService.normalize_reference_image(asset.get("reference_image", {}))
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
	# The image turns around the Asset Pivot as the Canvas shows it, so the
	# rotation center is the same point the Pivot marker is drawn at rather than
	# the authored pivot before the root transform.
	canvas_view.set_reference_image(
		reference_texture,
		bool(reference_image.get("visible", true)),
		float(reference_image.get("opacity", 0.5)),
		reference_position,
		reference_scale,
		float(reference_image.get("rotation", 0.0)),
		AssetScaleRebaseService.root_transform(asset) * _asset_pivot(asset)
	)


func _build_reference_shapes(asset: Dictionary, excluded_component_id := "", emphasized_component_id := "") -> Array:
	var shapes: Array = []
	var asset_is_visible := bool(asset.get("visibility", true))
	for component in asset["components"]:
		if str(component.get("type", "component")) == "guide" or _is_region(component):
			continue
		if str(component["id"]) == excluded_component_id:
			continue
		if _is_reference_component(component):
			shapes.append_array(_reference_asset_shapes(asset, component, emphasized_component_id))
			continue
		var primitive_component := PrimitiveGeometryService.has_analytic_shape(component)
		shapes.append({
			"id": str(component["id"]),
			"points": PrimitiveGeometryService.contour(component) if primitive_component else BezierTopology.outer_control_polygon(component),
			"bezier_points": component.get("points", []).duplicate(true),
			"edges": component.get("edges", []).duplicate(true),
			"chains": component.get("chains", []).duplicate(true),
			"closed": primitive_component or BezierTopology.outer_chain_closed(component),
			"primitive": primitive_component,
			"transform": _asset_preview_world_record(asset, ComponentHierarchy.world_transform_record(asset, str(component.get("id", "")))),
			"visibility": asset_is_visible and _effective_component_visibility(asset, component),
			"z_index": _effective_component_z_index(asset, component),
			"emphasized": str(component["id"]) == emphasized_component_id,
			"topology_role": WorldDocumentService.topology_role(component)
		})
	return shapes


func _is_reference_component(component: Dictionary) -> bool:
	return WorldDocumentService.is_reference_component(component)


func _normalized_component_name(component: Dictionary) -> String:
	return WorldDocumentService.normalized_component_name(component)


func _reference_asset_shapes(target_asset: Dictionary, reference: Dictionary, emphasized_component_id: String) -> Array:
	var result: Array = []
	var source_asset := _get_asset(str(reference.get("source_asset_id", "")))
	if source_asset.is_empty() or source_asset == target_asset:
		return result
	var reference_transform := _asset_preview_world_record(target_asset, ComponentHierarchy.world_transform_record(target_asset, str(reference.get("id", ""))))
	for source_component in source_asset.get("components", []):
		if _is_reference_component(source_component) or not bool(source_component.get("visibility", true)):
			continue
		var points: Array[Vector2] = []
		var source_transform := _asset_preview_world_record(source_asset, ComponentHierarchy.world_transform_record(source_asset, str(source_component.get("id", ""))))
		var contour := PrimitiveGeometryService.contour(source_component) if PrimitiveGeometryService.has_analytic_shape(source_component) else BezierTopology.outer_control_polygon(source_component)
		for point in contour:
			points.append(_transform_point(_transform_point(Vector2(point), source_transform), reference_transform))
		var authored_points: Array = []
		for source_point in source_component.get("points", []):
			if source_point is Dictionary:
				authored_points.append({"id": str(source_point.get("id", "")), "position": _transform_point(_transform_point(Vector2(source_point.get("position", Vector2.ZERO)), source_transform), reference_transform)})
		result.append({"id": str(reference.get("id", "")), "points": points, "bezier_points": authored_points, "closed": PrimitiveGeometryService.has_analytic_shape(source_component) or BezierTopology.outer_chain_closed(source_component), "primitive": PrimitiveGeometryService.has_analytic_shape(source_component), "transform": WorldDocumentService.default_component_transform(), "visibility": bool(target_asset.get("visibility", true)) and bool(reference.get("visibility", true)), "z_index": int(reference.get("z_index", 0)), "emphasized": str(reference.get("id", "")) == emphasized_component_id, "topology_role": WorldDocumentService.topology_role(reference)})
	return result


func _transform_point(point: Vector2, transform: Dictionary) -> Vector2:
	var pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
	return Vector2(transform.get("position", Vector2.ZERO)) + ((point - pivot) * Vector2(transform.get("scale", Vector2.ONE))).rotated(deg_to_rad(float(transform.get("rotation", 0.0))))


func _component_guide_boundaries(component: Dictionary) -> Dictionary:
	var outer := PackedVector2Array()
	var holes: Array = []
	if component.is_empty():
		return {"outer": outer, "holes": holes}
	if PrimitiveGeometryService.has_analytic_shape(component):
		return {"outer": PackedVector2Array(PrimitiveGeometryService.contour(component)), "holes": holes}
	var resolved_component := component.duplicate(true)
	BezierGeometry.resolve_auto_handles(resolved_component.get("points", []), resolved_component.get("chains", []))
	for chain_data in resolved_component.get("chains", []):
		if not chain_data is Dictionary or not bool(chain_data.get("closed", false)):
			continue
		var polygon := BezierGeometry.flatten_chain(resolved_component, chain_data)
		if polygon.size() < 3:
			continue
		var role := WorldDocumentService.topology_role(chain_data)
		if role == WorldDocumentService.ROLE_OUTER and outer.is_empty():
			outer = polygon
		elif role == WorldDocumentService.ROLE_HOLE:
			holes.append(polygon)
	return {"outer": outer, "holes": holes}


func _refresh_component_geometry(component: Dictionary) -> void:
	if component.is_empty() or not is_instance_valid(canvas_view):
		return
	var contour := PrimitiveGeometryService.contour(component) if PrimitiveGeometryService.has_analytic_shape(component) else BezierTopology.outer_control_polygon(component)
	canvas_view.set_display_polygon(contour, PrimitiveGeometryService.has_analytic_shape(component) or BezierTopology.outer_chain_closed(component))
	canvas_view.set_bezier_geometry(component.get("points", []), component.get("edges", []), component.get("chains", []))


func _on_primitive_placed(shape: String, shape_center: Vector2, size_cm: Vector2) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or not WorldDocumentService.is_primitive(component) or not component.get("primitive", {}).is_empty():
		return
	var primitive := PrimitiveGeometryService.build(shape, shape_center, size_cm)
	if primitive.is_empty():
		return
	_record_direct_change()
	component["geometry_source"] = "primitive"
	component["primitive"] = primitive
	_set_active_state("")
	_set_active_context_command("")
	_refresh_component_geometry(component)
	_invalidate_render(RENDER_DOCUMENT)


func _on_primitive_center_changed(center: Vector2) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if not PrimitiveGeometryService.has_analytic_shape(component):
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
	if not WorldDocumentService.is_primitive(component) or not component.get("primitive", {}).is_empty():
		return
	_set_active_state("")
	_set_active_context_command("")
	_invalidate_render(RENDER_CANVAS_CONTEXT)


## The Canvas owns the two placement steps; the Info Bar only reports which of
## them the next click belongs to.
func _on_primitive_preview_stage_changed(stage: String) -> void:
	primitive_create_stage = stage
	_invalidate_render(RENDER_INFO_BAR)


func _on_bezier_point_added(world_position: Vector2, point_mode: String = "linear", drawn_handle_out: Vector2 = Vector2.ZERO) -> void:
	if active_draw_tool == "spine" and not selected_guide_id.is_empty():
		var guide := _get_guide(_get_asset(selected_asset_id), selected_guide_id)
		if guide.is_empty():
			return
		_record_direct_change()
		BezierTopology.add_point(guide, canvas_view.constrain_draw_position(world_position), "aligned", Vector2.ZERO)
		BezierGeometry.resolve_auto_handles(guide.get("points", []), guide.get("chains", []))
		canvas_view.set_bezier_geometry(guide.get("points", []), guide.get("edges", []), guide.get("chains", []))
		_invalidate_render(RENDER_INSPECTOR)
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
	var point_id := BezierTopology.add_point_from(component, anchor_id, world_position, resolved_mode, drawn_handle_out) if not anchor_id.is_empty() else BezierTopology.start_chain(component, world_position, resolved_mode, drawn_handle_out)
	if point_id.is_empty():
		return
	selected_point_id = point_id
	selected_point_ids = [point_id]
	_refresh_component_geometry(component)
	canvas_view.set_selected_point_id(point_id)


func _on_bezier_endpoint_connection_requested(anchor_point_id: String, target_point_id: String) -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or WorldDocumentService.component_draw_mode(component) not in [WorldDocumentService.DRAW_MODE_CLOSED_LOOP, WorldDocumentService.DRAW_MODE_CONTOUR]:
		return
	var anchor_chain := BezierTopology.chain_for_point(component.get("chains", []), anchor_point_id)
	var target_chain := BezierTopology.chain_for_point(component.get("chains", []), target_point_id)
	if anchor_chain.is_empty() or target_chain.is_empty() or anchor_point_id == target_point_id:
		return
	if str(anchor_chain.get("id", "")) == str(target_chain.get("id", "")):
		var close_preview := component.duplicate(true)
		if not BezierTopology.close_chain(close_preview, str(anchor_chain.get("id", ""))):
			_show_status_message("The open Chain could not be closed safely")
			return
		_record_direct_change()
		if BezierTopology.close_chain(component, str(anchor_chain.get("id", ""))):
			_refresh_component_geometry(component)
		return
	var join_preview := component.duplicate(true)
	if not BezierTopology.join_open_chain_endpoints(join_preview, anchor_point_id, target_point_id):
		_show_status_message("The open Chains could not be connected safely")
		return
	_record_direct_change()
	if BezierTopology.join_open_chain_endpoints(component, anchor_point_id, target_point_id):
		_refresh_component_geometry(component)
		_show_status_message("Open Chains connected · Close the remaining endpoints to finish the Loop")


func _on_bezier_chain_closed() -> void:
	var component := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if component.is_empty() or WorldDocumentService.component_draw_mode(component) not in [WorldDocumentService.DRAW_MODE_CLOSED_LOOP, WorldDocumentService.DRAW_MODE_CONTOUR]:
		return
	var chains: Array = component.get("chains", [])
	if chains.is_empty() or bool(chains.back().get("closed", false)) or chains.back().get("point_ids", []).size() < 3:
		return
	_record_direct_change()
	BezierTopology.close_active_chain(component)
	_refresh_component_geometry(component)


func _on_pivot_changed(pivot: Vector2) -> void:
	var asset := _get_asset(selected_asset_id)
	if not selected_group_id.is_empty():
		var group := ComponentHierarchy.group_by_id(asset, selected_group_id)
		if group.is_empty():
			return
		_record_coalesced_change()
		var group_transform: Dictionary = group.get("transform", WorldDocumentService.default_component_transform())
		group_transform["pivot"] = pivot
		group["transform"] = group_transform
		return
	var component := _get_component(asset, selected_component_id)
	if component.is_empty():
		return
	_record_coalesced_change()
	var transform: Dictionary = component.get("transform", WorldDocumentService.default_component_transform())
	transform["pivot"] = pivot
	component["transform"] = transform


func _on_asset_pivot_changed(pivot: Vector2) -> void:
	var asset := _get_asset(selected_asset_id)
	if asset.is_empty() or not selected_component_id.is_empty():
		return
	_record_coalesced_change()
	var authored_pivot := pivot - AssetScaleRebaseService.root_position(asset)
	asset["asset_pivot"] = authored_pivot
	for property_name in ["pivot_x", "pivot_y"]:
		var field = create_inspector_view.asset_pivot_fields.get(property_name)
		if not is_instance_valid(field):
			continue
		var value := _editor_units_to_world(authored_pivot.x if property_name == "pivot_x" else authored_pivot.y)
		field.set_value_no_signal(value)


func _on_transform_changed(transform: Dictionary) -> void:
	var asset := _get_asset(selected_asset_id)
	var authored_world_transform := _asset_unpreview_world_record(asset, transform)
	if not selected_guide_id.is_empty():
		var guide := _get_guide(asset, selected_guide_id)
		if guide.is_empty() or not AssetGuide.is_weapon_frame(str(guide.get("guide_type", ""))):
			return
		_record_coalesced_change()
		var local_affine := ComponentHierarchy.guide_world_transform(asset, guide).affine_inverse() * ComponentHierarchy.local_transform(authored_world_transform)
		var local_record := ComponentHierarchy.transform_record_from_affine(local_affine, Vector2.ZERO)
		local_record["scale"] = Vector2.ONE
		local_record["pivot"] = Vector2.ZERO
		guide["transform"] = local_record
		_invalidate_render(RENDER_INSPECTOR)
		return
	if not selected_group_id.is_empty():
		var group := ComponentHierarchy.group_by_id(asset, selected_group_id)
		if group.is_empty():
			return
		_record_coalesced_change()
		group["transform"] = ComponentHierarchy.group_local_transform_from_world_record(asset, selected_group_id, authored_world_transform)
		_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)
		return
	var component := _get_component(asset, selected_component_id)
	if not component.is_empty():
		_record_coalesced_change()
		var local_transform := ComponentHierarchy.local_transform_from_world_record(asset, selected_component_id, authored_world_transform)
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
			var field = create_inspector_view.transform_fields.get(property_name)
			if is_instance_valid(field):
				field.set_value_no_signal(float(values[property_name]))
		var selected_reference_id := selected_component_id if _is_reference_component(component) else ""
		var excluded_reference_id := "" if _is_reference_component(component) else selected_component_id
		canvas_view.set_reference_shapes(_build_reference_shapes(asset, excluded_reference_id, selected_reference_id))


func _on_component_hierarchy_parent_selected(index: int, option: OptionButton) -> void:
	var asset := _get_asset(selected_asset_id)
	var component := _get_component(asset, selected_component_id)
	if asset.is_empty() or component.is_empty() or index < 0 or index >= option.item_count:
		return
	var new_parent_id := str(option.get_item_metadata(index))
	if str(component.get("parent_component_id", "")) == new_parent_id:
		return
	if not ComponentHierarchy.can_parent(asset, selected_component_id, new_parent_id):
		_show_status_message("The selected Parent is not valid for this Component.")
		_invalidate_render(RENDER_INSPECTOR)
		return
	var world_transform := ComponentHierarchy.world_transform_record(asset, selected_component_id)
	_record_direct_change()
	component["parent_component_id"] = new_parent_id
	component["transform"] = ComponentHierarchy.local_transform_from_world_record(asset, selected_component_id, world_transform)
	_invalidate_render(RENDER_DOCUMENT)


func _on_component_topology_role_selected(index: int, option: OptionButton) -> void:
	var asset := _get_asset(selected_asset_id)
	var component := _get_component(asset, selected_component_id)
	if component.is_empty() or index < 0 or index >= option.item_count:
		return
	var role := str(option.get_item_metadata(index))
	if role not in WorldDocumentService.TOPOLOGY_ROLES or role == WorldDocumentService.topology_role(component):
		return
	if role == WorldDocumentService.ROLE_HOLE and not _is_reference_component(component):
		var proposed_hole := component.duplicate(false)
		proposed_hole["topology_role"] = WorldDocumentService.ROLE_HOLE
		var hole_issue := WorldDocumentService.constraint_hole_parent_validation_issue(asset, proposed_hole)
		if hole_issue.is_empty() and not ComponentHierarchy.children(asset, selected_component_id).is_empty():
			hole_issue = "Detach child Components before changing this Component to Hole."
		if not hole_issue.is_empty():
			_show_status_message(hole_issue)
			_invalidate_render(RENDER_INSPECTOR)
			return
	_record_direct_change()
	component["topology_role"] = role
	for chain in component.get("chains", []):
		if chain is Dictionary and WorldDocumentService.topology_role(chain) in WorldDocumentService.TOPOLOGY_ROLES:
			chain["topology_role"] = role
	_invalidate_render(RENDER_DOCUMENT)


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
	if not ComponentHierarchy.can_parent(asset, component_id, new_parent_id):
		_show_status_message("Cannot detach this Hole from its required direct Parent Body.")
		return
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
	_invalidate_render(RENDER_DOCUMENT)


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
	var transform_component_id := AssetGuide.scope_component_id(guide) if not guide.is_empty() else selected_component_id
	var transform := _asset_preview_world_record(asset, ComponentHierarchy.world_transform_record(asset, transform_component_id))
	var transform_rotation := deg_to_rad(float(transform.get("rotation", 0.0)))
	var transform_scale: Vector2 = transform.get("scale", Vector2.ONE)
	var local_delta := world_delta.rotated(-transform_rotation)
	if not is_zero_approx(transform_scale.x):
		local_delta.x /= transform_scale.x
	if not is_zero_approx(transform_scale.y):
		local_delta.y /= transform_scale.y
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
	_invalidate_render(RENDER_INSPECTOR)


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
		_invalidate_render(RENDER_INSPECTOR)
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
	_invalidate_render(RENDER_INSPECTOR)


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
	_invalidate_render(RENDER_INSPECTOR)


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
	_invalidate_render(RENDER_INSPECTOR)


func _on_bezier_edges_delete_requested(edge_ids: Array) -> void:
	if edge_ids.is_empty():
		return
	var subject := _get_component(_get_asset(selected_asset_id), selected_component_id)
	if subject.is_empty() or WorldDocumentService.is_primitive(subject):
		return
	var valid_edge_ids: Array[String] = []
	for edge_id_value in edge_ids:
		var edge_id := str(edge_id_value)
		if not edge_id.is_empty() and not BezierTopology.edge_by_id(subject.get("edges", []), edge_id).is_empty() and edge_id not in valid_edge_ids:
			valid_edge_ids.append(edge_id)
	if valid_edge_ids.is_empty():
		return
	var can_delete := false
	for edge_id in valid_edge_ids:
		var edge_chain := BezierTopology.chain_for_edge(subject.get("chains", []), edge_id)
		if not edge_chain.is_empty() and bool(edge_chain.get("closed", false)):
			can_delete = true
			break
	if not can_delete:
		return
	_record_direct_change()
	var deleted_edge_ids := BezierTopology.delete_edges(subject, valid_edge_ids)
	if deleted_edge_ids.is_empty():
		return
	selected_edge_id = ""
	selected_edge_ids.clear()
	selected_point_id = ""
	selected_point_ids.clear()
	_refresh_component_geometry(subject)
	canvas_view.clear_selection()
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


func _on_point_selection_changed(point_id: String) -> void:
	selected_point_id = point_id
	if active_context_command == "asset.fuse_point" and not point_id.is_empty():
		_fuse_selected_point(point_id)
	if active_edit_mode == "point":
		selected_edge_id = ""
		selected_edge_ids.clear()
		_invalidate_render(RENDER_INSPECTOR)


func _on_point_selection_set_changed(point_ids: Array) -> void:
	selected_point_ids.clear()
	for point_id_value in point_ids:
		var point_id := str(point_id_value)
		if not point_id.is_empty() and point_id not in selected_point_ids:
			selected_point_ids.append(point_id)
	selected_point_id = selected_point_ids[0] if selected_point_ids.size() == 1 else ""
	if active_context_command == "asset.fuse_point" and selected_point_ids.size() == 1:
		_fuse_selected_point(selected_point_ids[0])
	if active_edit_mode == "point":
		selected_edge_id = ""
		selected_edge_ids.clear()
		_invalidate_render(RENDER_INSPECTOR | RENDER_CONTEXT_BAR)


func _on_edge_selection_changed(edge_id: String) -> void:
	selected_edge_id = edge_id
	if edge_id.is_empty():
		selected_edge_ids.clear()
	elif edge_id not in selected_edge_ids:
		selected_edge_ids = [edge_id]
	_invalidate_render(RENDER_INSPECTOR | RENDER_CONTEXT_BAR)


func _on_edge_selection_set_changed(edge_ids: Array) -> void:
	selected_edge_ids.clear()
	for edge_id_value in edge_ids:
		var edge_id := str(edge_id_value)
		if not edge_id.is_empty() and edge_id not in selected_edge_ids:
			selected_edge_ids.append(edge_id)
	selected_edge_id = selected_edge_ids[0] if not selected_edge_ids.is_empty() else ""
	_invalidate_render(RENDER_INSPECTOR | RENDER_CONTEXT_BAR)


func _on_face_selection_changed(_selected: bool) -> void:
	_invalidate_render(RENDER_INSPECTOR)


func _get_asset(asset_id: String) -> Dictionary:
	return WorldDocumentService.asset_by_id(assets, asset_id)


func _asset_type(asset: Dictionary) -> String:
	return WorldDocumentService.asset_type(asset)


func _asset_create_submodule(asset: Dictionary) -> String:
	# The Create module an Asset belongs to, which is its composition. Its
	# category is a separate question that only Single asks, through search and
	# the Outliner Asset filter.
	return str(CREATE_SUBMODULE_BY_ASSET_CATEGORY.get(WorldDocumentService.asset_category(asset), "Single"))


func _normalized_create_submodule(submodule: String) -> String:
	# Worlds below schema 63 stored one of the seven Asset-type names here.
	# Every one of them, and every unknown value, is the Single view.
	return submodule if submodule in CREATE_SUBMODULES else "Single"


## What the module lists and what it may keep selected are two questions. A
## composition member is not listed on its own — it is reached one row below its
## owner — but authoring it is exactly what that module is for, so it stays a
## valid selection there. Without this an undo or a session restore inside a
## Palette variant re-anchors to the Palette root and drops the user out of the
## Asset they were drawing in.
func _create_submodule_can_select(asset: Dictionary) -> bool:
	if _asset_matches_create_submodule(asset):
		return true
	var owner_id := str(_composition_owner_by_member_id().get(str(asset.get("id", "")), ""))
	return not owner_id.is_empty() and _asset_matches_create_submodule(_get_asset(owner_id))


func _asset_matches_create_submodule(asset: Dictionary) -> bool:
	if _asset_create_submodule(asset) != active_create_submodule:
		return false
	# Single lists what is placed on its own. An Asset a composition already
	# owns is reached through that composition instead, so it is not offered
	# twice.
	return active_create_submodule != "Single" or not _composition_owner_by_member_id().has(str(asset.get("id", "")))


func _composition_owner_by_member_id() -> Dictionary:
	# Every Asset some composition owns, mapped to its owner. A Set owns what
	# its member References point at; a Reference inside an ordinary Asset is a
	# Symbol instance rather than membership.
	var owner_by_member: Dictionary = {}
	for asset in assets:
		if not asset is Dictionary:
			continue
		var owner_id := str(asset.get("id", ""))
		if WorldDocumentService.is_set_asset(asset):
			for component in asset.get("components", []):
				if component is Dictionary and _is_reference_component(component):
					var member_id := str(component.get("source_asset_id", ""))
					if not member_id.is_empty() and not owner_by_member.has(member_id):
						owner_by_member[member_id] = owner_id
		elif WorldDocumentService.is_palette_asset(asset):
			for variant_id in WorldDocumentService.palette_variants(asset):
				if not owner_by_member.has(variant_id):
					owner_by_member[variant_id] = owner_id
	return owner_by_member


func _create_submodule_for_asset(asset_id: String) -> String:
	# A member Asset is authored inside the composition that owns it, so
	# selecting one of its Components must not leave that module.
	if active_module == "Create" and active_create_submodule != "Single" \
		and _composition_owner_by_member_id().has(asset_id):
		return active_create_submodule
	return _asset_create_submodule(_get_asset(asset_id))


func _outliner_expansion_anchor_asset_id(asset_id: String) -> String:
	# Expanding is a statement about a row the module lists. Inside a
	# composition module that row is the composition, even when the Asset being
	# touched is one of its members.
	if active_module != "Create" or active_create_submodule == "Single":
		return asset_id
	var owner_id := str(_composition_owner_by_member_id().get(asset_id, ""))
	return owner_id if not owner_id.is_empty() else asset_id


func _ensure_asset_animation(asset: Dictionary) -> Dictionary:
	if asset.is_empty():
		return {}
	var animation := MotionWorkspace.normalize_animation_document(asset.get("animation", {}))
	asset["animation"] = animation
	return animation


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
	motion_acts.append(WorldDocumentService.default_motion_act(act_id, act_name, primitive))
	selected_motion_act_id = act_id
	motion_act_phase = 0.0
	motion_act_playing = false
	if _get_asset(motion_act_preview_asset_id).is_empty():
		motion_act_preview_asset_id = _default_motion_path_preview_asset_id()
	_invalidate_render(RENDER_INSPECTOR | RENDER_CANVAS_CONTEXT)


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
	_invalidate_render(RENDER_INSPECTOR)
	_refresh_motion_act_workspace()
	_invalidate_render(RENDER_CONTEXT_BAR)


func _get_motion_path(path_id: String) -> Dictionary:
	return WorldDocumentService.motion_path_by_id(motion_paths, path_id)


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
	return WorldDocumentService.component_by_id(asset, component_id)


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


func _clear_context_bar() -> void:
	for child in context_bar.get_children():
		context_bar.remove_child(child)
		if child is CanvasItem:
			child.hide()
		add_child(child)
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
	_invalidate_render(RENDER_DOCUMENT)


func _find_section(module_name: String) -> ModuleSection:
	for section in module_sections:
		if section.module_name == module_name:
			return section
	return null


func _set_active_module_visual(module_name: String, submodule: String) -> void:
	for module_section in module_sections:
		module_section.set_expanded(true)
		module_section.set_active_submodule(submodule if module_section.module_name == module_name else "")


func _select_submodule(module_name: String, submodule: String, _section: ModuleSection) -> void:
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
		_invalidate_render(RENDER_DOCUMENT | RENDER_CONTEXT_BAR)
	elif module_name == "Mesh" and submodule in GEOMETRY_SUBMODULES:
		active_geometry_submodule = submodule
		active_module = "Mesh"
		_set_geometry_command_state("")
		selected_geometry_bake_method = ""
		active_state = ""
		_invalidate_render(RENDER_DOCUMENT)
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
	active_create_submodule = _normalized_create_submodule(submodule)
	active_state = ""
	var selected_asset := _get_asset(selected_asset_id)
	if selected_asset.is_empty() or not _create_submodule_can_select(selected_asset):
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
		if _asset_matches_create_submodule(asset):
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
	_invalidate_render(RENDER_DOCUMENT)


func _enter_weighting_context() -> void:
	active_module = "Style"
	active_style_submodule = "Weighting"
	var style_section := _find_section("Style")
	if style_section != null:
		_set_active_module_visual("Style", "Weighting")
	_invalidate_render(RENDER_DOCUMENT)


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
	if _is_hole_component(_get_component(_get_asset(asset_id), component_id)):
		return
	selected_asset_id = asset_id
	selected_component_id = component_id
	selected_weighting_style_id = ""
	_set_outliner_asset_expanded(asset_id, true)
	_enter_weighting_context()


func _select_weighting_style(asset_id: String, component_id: String, style_id: String) -> void:
	if _is_hole_component(_get_component(_get_asset(asset_id), component_id)) \
		or _weighting_style(asset_id, component_id, style_id).is_empty():
		return
	selected_asset_id = asset_id
	selected_component_id = component_id
	selected_weighting_style_id = style_id
	_set_outliner_asset_expanded(asset_id, true)
	_enter_weighting_context()
