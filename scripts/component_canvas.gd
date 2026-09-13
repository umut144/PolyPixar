class_name ComponentCanvas
extends Control

const SELECTION_MIRROR_SERVICE_SCRIPT = preload("res://scripts/selection_mirror_service.gd")

signal point_selection_changed(point_id: String)
signal point_selection_set_changed(point_ids: Array)
signal bezier_point_added(position: Vector2, point_mode: String, handle_out: Vector2)
signal bezier_chain_closed()
signal edge_selection_changed(edge_id: String)
signal edge_selection_set_changed(edge_ids: Array)
signal face_selection_changed(selected: bool)
signal bezier_points_move_started(point_ids: Array)
signal bezier_points_moved(point_ids: Array, delta: Vector2)
signal bezier_handle_changed(point_id: String, handle_side: String, value: Vector2)
signal bezier_edge_insert_requested(edge_id: String, t: float)
signal bezier_endpoint_connection_requested(anchor_point_id: String, target_point_id: String)
signal reference_component_selected(component_id: String)
signal mirror_axis_stage_changed(stage: String)
signal mirror_axis_confirmed(axis_start: Vector2, axis_end: Vector2)
signal mirror_axis_cancelled()
signal measure_stage_changed(stage: String)
signal pivot_changed(pivot: Vector2)
signal asset_pivot_changed(pivot: Vector2)
signal transform_changed(transform: Dictionary)
signal primitive_placed(shape: String, shape_center: Vector2, size_cm: Vector2)
signal primitive_center_changed(center: Vector2)
signal primitive_preview_cancelled()
signal primitive_preview_stage_changed(stage: String)

const RULER_COLOR := Color("#f2994a")
const RULER_X_COLOR := Color("#eb5757")
const RULER_Y_COLOR := Color("#6fcf97")
const RULER_CROSS_RADIUS := 7.0
const RULER_LEG_MIN_PIXELS := 6.0
const PRIMITIVE_FILL_ALPHA := 0.133
## Placing a Primitive takes two clicks: the first pins the centre, the second
## fixes the size. Until the centre is pinned the preview follows the cursor at
## this size, so there is something to see before there is anything to measure.
const PRIMITIVE_STAGE_CENTER := "center"
const PRIMITIVE_STAGE_SIZE := "size"
const PRIMITIVE_PREVIEW_DEFAULT_CM := 1.0
const PRIMITIVE_MINIMUM_EXTENT_CM := 0.1
const MIRROR_AXIS_VERTICAL := "vertical"
const MIRROR_AXIS_HORIZONTAL := "horizontal"
const PAN_SPEED := 420.0
const MIN_ZOOM := 0.25
# Allows detailed sub-millimeter editing while keeping the existing zoom
# progression and grid package logic unchanged. At 16384 one Tool unit of 10 cm
# fills 16384 pixels, so a millimetre is about 164 of them and a pixel about six
# micrometres - the depth the thousandth-and-finer Scale fields are authored at.
# Whoever raises it further must raise it here alone: main.gd clamps every
# stored camera against these two, so a second copy of the number would snap a
# deeper view back on the next asset switch.
const MAX_ZOOM := 16384.0
const DEFAULT_ZOOM := 1.0
const ZOOM_RATE := 1.8
const CLOSE_DISTANCE_PIXELS := 14.0
const GIZMO_AXIS_LENGTH := 42.0
const HANDLE_HIT_RADIUS := 12.0
const FREE_HANDLE_RADIUS := 10.0
const DRAW_HANDLE_DRAG_THRESHOLD_PIXELS := 6.0
const MEASUREMENT_DASH_LENGTH := 7.0
const MEASUREMENT_GAP_LENGTH := 5.0
const MEASUREMENT_FONT_SIZE := 14
const GRID_PACKAGE_MIN_PIXELS := 12.0

var view_center := Vector2.ZERO
var zoom := DEFAULT_ZOOM
var camera_state_restored := false
var context_name := ""
var active_tool := ""
var interaction_state := ""
var edit_mode := "select"
var edit_handles_enabled := false
var edit_point_set_enabled := false
var point_numbers_visible := false
var transform_mode := "transform"
var display_polygon: Array[Vector2] = []
var display_polygon_closed := false
var bezier_points: Array[Dictionary] = []
var bezier_edges: Array[Dictionary] = []
var bezier_chains: Array[Dictionary] = []
var mirror_command_stage := ""
var mirror_axis_orientation := MIRROR_AXIS_VERTICAL
var mirror_axis_start := Vector2.ZERO
var mirror_axis_end := Vector2.ZERO
var mirror_axis_candidate_visible := false
var selection_mirror_preview_points: Array[Dictionary] = []
var selection_mirror_preview_edges: Array[Dictionary] = []
var measure_ruler_enabled := false
var measure_placing := false
var measure_stage := ""
var measure_first_anchor: Dictionary = {}
var measure_cursor_anchor: Dictionary = {}
var measure_cursor_visible := false
var measure_segments: Array[Dictionary] = []
var guide_style := false
var guide_color := Color("#f2c94c")
var bezier_color_override := Color.TRANSPARENT
var draw_point_mode := "linear"
var reference_shapes: Array[Dictionary] = []
var catch_parent_component_id := ""
var component_draw_mode := WorldDocumentService.DRAW_MODE_CLOSED_LOOP
var draw_constraint_outer := PackedVector2Array()
var draw_constraint_holes: Array = []
var cursor_world := Vector2.ZERO
var cursor_over_canvas := false
var selected_point_id := ""
var selected_point_ids: Array[String] = []
var selected_edge_id := ""
var selected_edge_ids: Array[String] = []
var face_selected := false
var bezier_handle_drag_side := ""
var point_marquee_dragging := false
var point_marquee_moved := false
var point_marquee_start := Vector2.ZERO
var point_marquee_current := Vector2.ZERO
var point_press_edge_hit: Dictionary = {}
var edge_marquee_dragging := false
var edge_marquee_moved := false
var edge_marquee_start := Vector2.ZERO
var edge_marquee_current := Vector2.ZERO
var edge_marquee_additive := false
var selection_gizmo_dragging := false
var selection_gizmo_drag_axis := ""
var selection_gizmo_drag_start_world := Vector2.ZERO
var draw_pointer_down := false
var pending_draw_position := Vector2.ZERO
var pending_draw_pointer_screen_position := Vector2.ZERO
var pending_draw_connection_target_id := ""
var pending_draw_handle_out := Vector2.ZERO
var pending_draw_has_handle := false
var snap_enabled := true
var grid_step := 16.0
var rotation_step := 15.0
var frame_visible := false
var frame_half_extent := Vector2.ONE
var frame_offset := Vector2.ZERO
var world_grid_size := 0.5
var component_transform: Dictionary = {
	"position": Vector2.ZERO,
	"rotation": 0.0,
	"scale": Vector2.ONE,
	"pivot": Vector2.ZERO
}
var asset_pivot := Vector2.ZERO
var reference_image: Texture2D
var reference_image_visible := true
var reference_image_opacity := 0.5
var reference_image_position := Vector2.ZERO
var reference_image_rotation := 0.0
var reference_image_rotation_pivot := Vector2.ZERO
var reference_image_scale := 1.0
var navigation_locked := false
var command_shortcut_active := false
var navigation_keys_pressed: Dictionary = {}
var pivot_dragging := false
var asset_pivot_dragging := false
## Whether the Transform gizmo's X/Y axes follow the authored rotation of
## `component_transform` instead of staying parallel to the world axes.
## Only a transform-based Weapon Guide turns this on: it carries no
## geometry, so its gizmo is the only thing that can show its orientation.
var transform_axes_local := false
var transform_drag_axis := ""
var transform_drag_start_world := Vector2.ZERO
var transform_drag_start_position := Vector2.ZERO
var transform_drag_start_angle := 0.0
var transform_drag_start_rotation := 0.0
var transform_drag_start_scale := Vector2.ONE
var face_dragging := false
var face_drag_start_world := Vector2.ZERO
var primitive_preview_shape := ""
var primitive_preview_stage := ""
var primitive_preview_center := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_exited.connect(_clear_navigation_input)
	queue_redraw()


func get_camera_state() -> Dictionary:
	return {
		"position": view_center,
		"zoom": zoom
	}


func set_camera_state(camera_position: Vector2, saved_zoom: float) -> void:
	view_center = camera_position
	zoom = clampf(saved_zoom, MIN_ZOOM, MAX_ZOOM)
	camera_state_restored = true
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_update_navigation_input(event)
		if event.meta_pressed or event.ctrl_pressed:
			command_shortcut_active = true
			_clear_navigation_input()
		elif not event.pressed and event.keycode in [KEY_META, KEY_CTRL]:
			command_shortcut_active = false
	if event is InputEventMouseButton and event.pressed:
		grab_focus()
		if event.button_index == MOUSE_BUTTON_LEFT and primitive_preview_is_active():
			_place_primitive_preview_point(event.position)
			return
		if event.button_index == MOUSE_BUTTON_LEFT and not mirror_command_stage.is_empty():
			_set_mirror_axis_from_screen(event.position)
			_confirm_mirror_axis()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and measure_placing:
			_place_measure_point(event.position)
			return
		if event.button_index == MOUSE_BUTTON_LEFT and interaction_state == "draw" and active_tool == "point" and _draw_anchor_point_id().is_empty():
			var endpoint_id := _open_endpoint_at(event.position)
			if not endpoint_id.is_empty():
				_set_selected_point_ids([endpoint_id])
				queue_redraw()
				return
		if event.button_index == MOUSE_BUTTON_LEFT and interaction_state == "draw" and active_tool in ["point", "spine"]:
			_begin_draw_pointer(event.position)
			queue_redraw()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and interaction_state == "asset" and _is_near_asset_pivot(event.position):
			asset_pivot_dragging = true
			return
		if event.button_index == MOUSE_BUTTON_LEFT and interaction_state.is_empty() and _is_near_pivot(event.position):
			pivot_dragging = true
			return
		if event.button_index == MOUSE_BUTTON_LEFT and interaction_state == "edit":
			if edit_mode == "point" and not edit_handles_enabled and not edit_point_set_enabled:
				var gizmo_axis := _selection_gizmo_at(event.position)
				if not gizmo_axis.is_empty():
					selection_gizmo_dragging = true
					selection_gizmo_drag_axis = gizmo_axis
					selection_gizmo_drag_start_world = _screen_to_world(event.position)
					bezier_points_move_started.emit(_selected_point_ids())
					return
			if _is_near_pivot(event.position):
				pivot_dragging = true
				return
			if edit_mode == "edge":
				var edge_hit := _nearest_bezier_edge(event.position)
				if not edge_hit.is_empty():
					_select_edge_by_click(edge_hit, event.shift_pressed)
				else:
					edge_marquee_dragging = true
					edge_marquee_moved = false
					edge_marquee_start = event.position
					edge_marquee_current = event.position
					edge_marquee_additive = event.shift_pressed
					if not event.shift_pressed:
						_set_selected_edge_ids([])
				queue_redraw()
				return
			if edit_mode == "face":
				var face_local := _world_to_local(_screen_to_world(event.position))
				if display_polygon_closed and display_polygon.size() >= 3 and Geometry2D.is_point_in_polygon(face_local, PackedVector2Array(display_polygon)):
					face_selected = true
					face_selection_changed.emit(true)
					face_dragging = true
					face_drag_start_world = _screen_to_world(event.position)
					bezier_points_move_started.emit(_all_bezier_point_ids())
				else:
					face_selected = false
					face_selection_changed.emit(false)
				queue_redraw()
				return
			if edit_mode == "point" and not bezier_points.is_empty():
				if edit_point_set_enabled:
					var edge_to_insert := _bezier_edge_hit(event.position)
					if not edge_to_insert.is_empty():
						bezier_edge_insert_requested.emit(str(edge_to_insert["id"]), float(edge_to_insert["t"]))
					else:
						clear_selection()
					queue_redraw()
					return
				if not edit_handles_enabled:
					var gizmo_axis := _selection_gizmo_at(event.position)
					if not gizmo_axis.is_empty():
						selection_gizmo_dragging = true
						selection_gizmo_drag_axis = gizmo_axis
						selection_gizmo_drag_start_world = _screen_to_world(event.position)
						bezier_points_move_started.emit(_selected_point_ids())
						return
				var handle_side := _bezier_handle_at(event.position) if edit_handles_enabled else ""
				if not handle_side.is_empty():
					bezier_handle_drag_side = handle_side
					return
				var bezier_point_index := _nearest_bezier_point(event.position)
				if bezier_point_index >= 0:
					_set_selected_point_ids([str(bezier_points[bezier_point_index].get("id", ""))])
				else:
					point_marquee_dragging = true
					point_marquee_moved = false
					point_marquee_start = event.position
					point_marquee_current = event.position
					point_press_edge_hit = _bezier_edge_hit(event.position)
				queue_redraw()
				return
		elif event.button_index == MOUSE_BUTTON_LEFT and interaction_state == "transform":
			# The centre handle is a Translate handle. While Rotate or Scale owns
			# the gizmo it stays inert, so a click near the middle cannot quietly
			# move a shape the user meant to turn or resize.
			if transform_mode == "transform" and _is_near_primitive_center(event.position):
				transform_drag_axis = "primitive_move"
				return
			var handle_axis := _transform_handle_at(event.position)
			if handle_axis != "":
				transform_drag_axis = handle_axis
				transform_drag_start_world = _screen_to_world(event.position)
				transform_drag_start_position = component_transform.get("position", Vector2.ZERO)
				transform_drag_start_angle = _angle_from_transform_center(event.position)
				transform_drag_start_rotation = float(component_transform.get("rotation", 0.0))
				transform_drag_start_scale = component_transform.get("scale", Vector2.ONE)
				return
		elif event.button_index == MOUSE_BUTTON_LEFT and interaction_state == "asset":
			var component_id := _reference_component_at(_screen_to_world(event.position))
			if not component_id.is_empty():
				reference_component_selected.emit(component_id)
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if draw_pointer_down and interaction_state == "draw" and active_tool in ["point", "spine"]:
			_update_pending_draw_handle(event.position)
			_commit_draw_pointer()
			queue_redraw()
			return
		if selection_gizmo_dragging:
			selection_gizmo_dragging = false
			selection_gizmo_drag_axis = ""
			queue_redraw()
			return
		if point_marquee_dragging:
			if point_marquee_moved:
				_select_points_in_marquee()
			else:
				clear_selection()
			point_marquee_dragging = false
			point_marquee_moved = false
			point_press_edge_hit = {}
			queue_redraw()
			return
		if edge_marquee_dragging:
			if edge_marquee_moved:
				_select_edges_in_marquee(edge_marquee_additive)
			elif not edge_marquee_additive:
				_set_selected_edge_ids([])
			edge_marquee_dragging = false
			edge_marquee_moved = false
			edge_marquee_additive = false
			queue_redraw()
			return
		bezier_handle_drag_side = ""
		pivot_dragging = false
		asset_pivot_dragging = false
		transform_drag_axis = ""
		face_dragging = false
	if event is InputEventMouseMotion:
		cursor_over_canvas = true
		cursor_world = constrain_draw_position(_snap_to_canvas_position(_world_to_local(_screen_to_world(event.position))))
		if not mirror_command_stage.is_empty():
			_set_mirror_axis_from_screen(event.position)
			_update_selection_mirror_preview()
			queue_redraw()
			return
		if measure_placing:
			measure_cursor_anchor = _measure_anchor_at(event.position)
			measure_cursor_visible = true
			queue_redraw()
			return
		if point_marquee_dragging:
			point_marquee_current = event.position
			if point_marquee_start.distance_to(point_marquee_current) >= 4.0:
				point_marquee_moved = true
			queue_redraw()
			return
		if edge_marquee_dragging:
			edge_marquee_current = event.position
			if edge_marquee_start.distance_to(edge_marquee_current) >= 4.0:
				edge_marquee_moved = true
			queue_redraw()
			return
		if selection_gizmo_dragging:
			var current_world := _screen_to_world(event.position)
			var move_delta := current_world - selection_gizmo_drag_start_world
			if selection_gizmo_drag_axis == "x":
				move_delta.y = 0.0
			elif selection_gizmo_drag_axis == "y":
				move_delta.x = 0.0
			if not is_zero_approx(move_delta.length_squared()):
				bezier_points_moved.emit(_selected_point_ids(), move_delta)
			queue_redraw()
			return
		if draw_pointer_down and interaction_state == "draw" and active_tool == "point" and draw_point_mode != "linear":
			_update_pending_draw_handle(event.position)
			queue_redraw()
			return
		if pivot_dragging:
			var old_pivot: Vector2 = component_transform.get("pivot", Vector2.ZERO)
			var new_pivot := _snap_pivot_position(_world_to_local(_screen_to_world(event.position)))
			var transform_scale: Vector2 = component_transform.get("scale", Vector2.ONE)
			var transform_rotation := deg_to_rad(float(component_transform.get("rotation", 0.0)))
			var transform_position: Vector2 = component_transform.get("position", Vector2.ZERO)
			transform_position += ((new_pivot - old_pivot) * transform_scale).rotated(transform_rotation)
			component_transform["pivot"] = new_pivot
			component_transform["position"] = transform_position
			pivot_changed.emit(new_pivot)
			transform_changed.emit(component_transform.duplicate(true))
			queue_redraw()
			return
		if asset_pivot_dragging:
			asset_pivot = _snap_to_grid(_screen_to_world(event.position))
			asset_pivot_changed.emit(asset_pivot)
			queue_redraw()
			return
		if interaction_state == "transform" and transform_drag_axis != "":
			if transform_drag_axis == "primitive_move":
				primitive_center_changed.emit(_snap_to_grid(_world_to_local(_screen_to_world(event.position))))
				queue_redraw()
				return
			var current_world := _screen_to_world(event.position)
			if transform_drag_axis == "rotate":
				var angle_delta := rad_to_deg(_angle_from_transform_center(event.position) - transform_drag_start_angle)
				var new_rotation := transform_drag_start_rotation + angle_delta
				if snap_enabled:
					new_rotation = round(new_rotation / rotation_step) * rotation_step
				component_transform["rotation"] = new_rotation
				transform_changed.emit(component_transform.duplicate(true))
				queue_redraw()
				return
			if transform_drag_axis.begins_with("scale"):
				var start_rotation := deg_to_rad(transform_drag_start_rotation)
				var start_offset := (transform_drag_start_world - transform_drag_start_position).rotated(-start_rotation)
				var current_offset := (current_world - transform_drag_start_position).rotated(-start_rotation)
				var new_scale := transform_drag_start_scale
				if transform_drag_axis == "scale_uniform" and not is_zero_approx(start_offset.length()):
					var ratio: float = current_offset.length() / start_offset.length()
					new_scale = transform_drag_start_scale * maxf(0.01, ratio)
				component_transform["scale"] = new_scale
				transform_changed.emit(component_transform.duplicate(true))
				queue_redraw()
				return
			var delta := current_world - transform_drag_start_world
			var drag_axis := _transform_axis_direction(transform_drag_axis) if transform_axes_local else Vector2.ZERO
			var new_position := Vector2.ZERO
			if drag_axis == Vector2.ZERO:
				if transform_drag_axis == "x":
					delta.y = 0.0
				elif transform_drag_axis == "y":
					delta.x = 0.0
				new_position = _snap_to_grid(transform_drag_start_position + delta)
			else:
				# Snapping stays on the rotated axis rather than on the world
				# raster, so a turned frame cannot drift sideways off its own
				# axis while Snap is on.
				var snapped := _snap_to_grid(transform_drag_start_position + drag_axis * delta.dot(drag_axis))
				new_position = transform_drag_start_position + drag_axis * drag_axis.dot(snapped - transform_drag_start_position)
			component_transform["position"] = new_position
			transform_changed.emit(component_transform.duplicate(true))
			queue_redraw()
			return
		if interaction_state == "edit" and edit_mode == "face" and face_dragging:
			var face_delta := _screen_to_world(event.position) - face_drag_start_world
			bezier_points_moved.emit(_all_bezier_point_ids(), face_delta)
			queue_redraw()
			return
		if interaction_state == "edit" and edit_mode == "point" and not selected_point_id.is_empty() and not bezier_points.is_empty():
			if bezier_handle_drag_side != "":
				var bezier_point := _point_by_id(selected_point_id)
				if bezier_point.is_empty():
					return
				var point_position: Vector2 = bezier_point.get("position", Vector2.ZERO)
				# Handles are continuous curve controls, not geometric vertices. They
				# must follow the pointer exactly, independently from point snapping.
				var handle_position := _world_to_local(_screen_to_world(event.position)) - point_position
				bezier_handle_changed.emit(str(bezier_point.get("id", "")), bezier_handle_drag_side, handle_position)
				queue_redraw()
				return
		queue_redraw()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and primitive_preview_is_active():
			# Escape walks the placement back one step rather than throwing it
			# away: from the size back to the centre, and only from there out of
			# the command.
			if primitive_preview_stage == PRIMITIVE_STAGE_SIZE:
				primitive_preview_stage = PRIMITIVE_STAGE_CENTER
				primitive_preview_stage_changed.emit(primitive_preview_stage)
				queue_redraw()
				return
			_clear_primitive_preview()
			primitive_preview_cancelled.emit()
			return
		if not mirror_command_stage.is_empty():
			if event.keycode == KEY_ESCAPE:
				cancel_mirror_command()
			elif event.keycode in [KEY_ENTER, KEY_KP_ENTER] and mirror_axis_candidate_visible:
				_confirm_mirror_axis()
			return
		if measure_placing and event.keycode == KEY_ESCAPE:
			_undo_last_measure_point()
			_consume_input_event()
			return
		if event.keycode == KEY_ESCAPE and interaction_state == "edit":
			clear_selection()


func _begin_draw_pointer(screen_position: Vector2) -> void:
	draw_pointer_down = true
	pending_draw_pointer_screen_position = screen_position
	pending_draw_connection_target_id = _draw_connection_target_id(screen_position) if active_tool == "point" else ""
	pending_draw_position = constrain_draw_position(_snap_to_canvas_position(_world_to_local(_screen_to_world(screen_position))))
	pending_draw_handle_out = Vector2.ZERO
	pending_draw_has_handle = false


func _update_pending_draw_handle(screen_position: Vector2) -> void:
	if not draw_pointer_down or active_tool != "point" or draw_point_mode == "linear":
		pending_draw_handle_out = Vector2.ZERO
		pending_draw_has_handle = false
		return
	pending_draw_has_handle = screen_position.distance_to(pending_draw_pointer_screen_position) >= DRAW_HANDLE_DRAG_THRESHOLD_PIXELS
	pending_draw_handle_out = _world_to_local(_screen_to_world(screen_position)) - pending_draw_position if pending_draw_has_handle else Vector2.ZERO


func _commit_draw_pointer() -> void:
	var target_id := pending_draw_connection_target_id
	var anchor_id := _draw_anchor_point_id()
	if not target_id.is_empty() and not anchor_id.is_empty() and target_id != anchor_id:
		bezier_endpoint_connection_requested.emit(anchor_id, target_id)
	elif target_id == anchor_id and not target_id.is_empty():
		pass
	elif active_tool == "point" and component_draw_mode in [WorldDocumentService.DRAW_MODE_CLOSED_LOOP, WorldDocumentService.DRAW_MODE_CONTOUR] and _is_near_first_chain_point(pending_draw_position):
		bezier_chain_closed.emit()
	else:
		bezier_point_added.emit(pending_draw_position, draw_point_mode, pending_draw_handle_out if pending_draw_has_handle else Vector2.ZERO)
	draw_pointer_down = false
	pending_draw_pointer_screen_position = Vector2.ZERO
	pending_draw_connection_target_id = ""
	pending_draw_has_handle = false


func set_context(context_label: String) -> void:
	# Guides are expressed in the active Component's local space, so they cannot
	# survive a move to a different one.
	if context_label != context_name:
		measure_segments.clear()
		measure_first_anchor = {}
		if measure_placing:
			measure_stage = "first"
	context_name = context_label
	queue_redraw()


func _on_mouse_entered() -> void:
	cursor_over_canvas = true
	queue_redraw()


func _on_mouse_exited() -> void:
	cursor_over_canvas = false
	measure_cursor_visible = false
	queue_redraw()


func is_pointer_over_canvas() -> bool:
	return cursor_over_canvas and Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())


func set_tool_mode(tool_name: String) -> void:
	active_tool = tool_name
	if tool_name not in ["point", "spine"]:
		draw_pointer_down = false
		pending_draw_has_handle = false
		pending_draw_handle_out = Vector2.ZERO
	queue_redraw()


func start_primitive_preview(shape: String) -> void:
	if not shape in PrimitiveGeometryService.CREATABLE_SHAPES:
		return
	primitive_preview_shape = shape
	primitive_preview_stage = PRIMITIVE_STAGE_CENTER
	primitive_preview_center = Vector2.ZERO
	primitive_preview_stage_changed.emit(primitive_preview_stage)
	queue_redraw()


func cancel_primitive_preview() -> void:
	if not primitive_preview_is_active():
		return
	_clear_primitive_preview()


func primitive_preview_is_active() -> bool:
	return not primitive_preview_shape.is_empty()


## One click of the two-step placement: the first pins the centre, the second
## commits the shape. Split out from the input handler so the placement can be
## driven without a live mouse, the way the Ruler is.
func _place_primitive_preview_point(screen_position: Vector2) -> void:
	var local_position := _snap_to_canvas_position(_world_to_local(_screen_to_world(screen_position)))
	if primitive_preview_stage == PRIMITIVE_STAGE_CENTER:
		primitive_preview_center = local_position
		primitive_preview_stage = PRIMITIVE_STAGE_SIZE
		primitive_preview_stage_changed.emit(primitive_preview_stage)
		queue_redraw()
		return
	var placed_shape := primitive_preview_shape
	var placed_center := primitive_preview_center
	var placed_size := primitive_preview_size_cm(local_position)
	_clear_primitive_preview()
	primitive_placed.emit(placed_shape, placed_center, placed_size)


## The size the preview stands for while its rim, or the corner of its bounding
## box, sits at `local_position`. Before the centre is pinned there is nothing to
## measure yet, so it is the default; afterwards a Circle measures its diameter
## outward from the centre, and a Rectangle or Triangle takes the position as one
## corner of its box, which is why both extents count double.
func primitive_preview_size_cm(local_position: Vector2) -> Vector2:
	if primitive_preview_stage != PRIMITIVE_STAGE_SIZE:
		return Vector2(PRIMITIVE_PREVIEW_DEFAULT_CM, PRIMITIVE_PREVIEW_DEFAULT_CM)
	var offset := local_position - primitive_preview_center
	if primitive_preview_shape == PrimitiveGeometryService.CIRCLE:
		var diameter := maxf(ToolUnits.to_centimeters(offset.length()) * 2.0, PRIMITIVE_MINIMUM_EXTENT_CM)
		return Vector2(diameter, diameter)
	return Vector2(
		maxf(ToolUnits.to_centimeters(absf(offset.x)) * 2.0, PRIMITIVE_MINIMUM_EXTENT_CM),
		maxf(ToolUnits.to_centimeters(absf(offset.y)) * 2.0, PRIMITIVE_MINIMUM_EXTENT_CM))


func _clear_primitive_preview() -> void:
	primitive_preview_shape = ""
	primitive_preview_stage = ""
	primitive_preview_center = Vector2.ZERO
	queue_redraw()


func set_draw_point_mode(mode: String) -> void:
	if mode not in ["linear", "aligned", "free", "mirrored", "corner"]:
		return
	draw_point_mode = mode
	queue_redraw()


func set_interaction_state(state: String) -> void:
	interaction_state = state
	if state != "draw":
		active_tool = ""
		draw_pointer_down = false
		pending_draw_connection_target_id = ""
		pending_draw_has_handle = false
		pending_draw_handle_out = Vector2.ZERO
	if state not in ["edit", "draw"]:
		clear_selection()
		_set_selected_edge_ids([])
	queue_redraw()


func set_reference_shapes(shapes: Array) -> void:
	reference_shapes.clear()
	for shape in shapes:
		if shape is Dictionary:
			reference_shapes.append(shape.duplicate(true))
	queue_redraw()


func set_catch_parent_component(component_id: String) -> void:
	catch_parent_component_id = component_id
	queue_redraw()


func set_component_draw_mode(draw_mode: String) -> void:
	component_draw_mode = draw_mode if draw_mode in [WorldDocumentService.DRAW_MODE_CLOSED_LOOP, WorldDocumentService.DRAW_MODE_CONTOUR, WorldDocumentService.DRAW_MODE_PRIMITIVE] else WorldDocumentService.DRAW_MODE_CLOSED_LOOP
	queue_redraw()


func set_draw_constraint(outer: PackedVector2Array, holes: Array = []) -> void:
	draw_constraint_outer = outer.duplicate()
	draw_constraint_holes.clear()
	for hole in holes:
		if hole is PackedVector2Array:
			draw_constraint_holes.append(hole.duplicate())
	queue_redraw()


func clear_draw_constraint() -> void:
	draw_constraint_outer = PackedVector2Array()
	draw_constraint_holes.clear()
	queue_redraw()


func constrain_draw_position(world_position: Vector2) -> Vector2:
	if draw_constraint_outer.size() < 3:
		return world_position
	if not _point_on_polygon_boundary(world_position, draw_constraint_outer) and not Geometry2D.is_point_in_polygon(world_position, draw_constraint_outer):
		return _closest_point_on_polygon(world_position, draw_constraint_outer)
	for hole in draw_constraint_holes:
		if hole is PackedVector2Array and hole.size() >= 3 and Geometry2D.is_point_in_polygon(world_position, hole) and not _point_on_polygon_boundary(world_position, hole):
			return _closest_point_on_polygon(world_position, hole)
	return world_position


func _closest_point_on_polygon(world_position: Vector2, polygon: PackedVector2Array) -> Vector2:
	var closest := polygon[0]
	var closest_distance_squared := INF
	for index in range(polygon.size()):
		var candidate := Geometry2D.get_closest_point_to_segment(world_position, polygon[index], polygon[(index + 1) % polygon.size()])
		var distance_squared := world_position.distance_squared_to(candidate)
		if distance_squared < closest_distance_squared:
			closest = candidate
			closest_distance_squared = distance_squared
	return closest


func _point_on_polygon_boundary(world_position: Vector2, polygon: PackedVector2Array) -> bool:
	return world_position.distance_squared_to(_closest_point_on_polygon(world_position, polygon)) <= 0.000001


func set_edit_mode(mode: String) -> void:
	var mode_changed := edit_mode != mode
	edit_mode = mode
	if mode_changed and edit_mode != "point":
		clear_selection()
	if mode_changed and edit_mode != "edge":
		_set_selected_edge_ids([])
	if mode_changed and edit_mode != "face":
		face_selected = false
	queue_redraw()


func set_edit_handles_enabled(enabled: bool) -> void:
	edit_handles_enabled = enabled
	queue_redraw()


func set_edit_point_set_enabled(enabled: bool) -> void:
	edit_point_set_enabled = enabled
	queue_redraw()


func set_point_numbers_visible(point_numbers_enabled: bool) -> void:
	point_numbers_visible = point_numbers_enabled
	queue_redraw()


func set_selected_edge_id(edge_id: String) -> void:
	_set_selected_edge_ids([edge_id] if not edge_id.is_empty() else [])


func set_selected_edge_ids(edge_ids: Array) -> void:
	_set_selected_edge_ids(edge_ids)


func _set_selected_edge_ids(edge_ids: Array) -> void:
	selected_edge_ids.clear()
	for edge_id_value in edge_ids:
		var edge_id := str(edge_id_value)
		if not edge_id.is_empty() and not _edge_by_id(edge_id).is_empty() and edge_id not in selected_edge_ids:
			selected_edge_ids.append(edge_id)
	selected_edge_id = selected_edge_ids[0] if not selected_edge_ids.is_empty() else ""
	edge_selection_changed.emit(selected_edge_id)
	edge_selection_set_changed.emit(selected_edge_ids.duplicate())
	queue_redraw()


func set_face_selected(selected: bool) -> void:
	face_selected = selected
	face_selection_changed.emit(face_selected)
	queue_redraw()


func set_selected_point_id(point_id: String) -> void:
	_set_selected_point_ids([point_id])


func _set_selected_point_ids(point_ids: Array) -> void:
	selected_point_ids.clear()
	for point_id_value in point_ids:
		var point_id := str(point_id_value)
		if not point_id.is_empty() and _point_index_by_id(point_id) >= 0 and point_id not in selected_point_ids:
			selected_point_ids.append(point_id)
	selected_point_id = selected_point_ids[0] if selected_point_ids.size() == 1 else ""
	point_selection_changed.emit(selected_point_id)
	point_selection_set_changed.emit(selected_point_ids.duplicate())
	queue_redraw()


func set_transform_mode(mode: String) -> void:
	transform_mode = mode
	queue_redraw()


func set_snap_settings(enabled: bool, new_grid_step: float, new_rotation_step: float) -> void:
	snap_enabled = enabled
	grid_step = maxf(new_grid_step, 0.0001)
	rotation_step = maxf(new_rotation_step, 1.0)
	queue_redraw()


func set_frame_guide(frame_enabled: bool, half_extent: Vector2, offset: Vector2) -> void:
	frame_visible = frame_enabled
	frame_half_extent = Vector2(maxf(half_extent.x, 0.0), maxf(half_extent.y, 0.0))
	frame_offset = offset
	queue_redraw()


func snap_position(world_position: Vector2) -> Vector2:
	return _snap_to_canvas_position(world_position)


func set_world_scale(new_grid_size: float) -> void:
	world_grid_size = maxf(new_grid_size, 0.0001)
	queue_redraw()


func set_component_transform(transform: Dictionary) -> void:
	component_transform = transform.duplicate(true)
	if not component_transform.has("pivot") or not component_transform["pivot"] is Vector2:
		component_transform["pivot"] = Vector2.ZERO
	queue_redraw()


func set_asset_pivot(pivot: Vector2) -> void:
	asset_pivot = pivot
	queue_redraw()


func set_reference_image(texture: Texture2D, image_visible := true, image_opacity := 0.5, image_position := Vector2.ZERO, image_scale := 1.0, image_rotation := 0.0, image_rotation_pivot := Vector2.ZERO) -> void:
	reference_image = texture
	reference_image_visible = image_visible
	reference_image_opacity = clampf(float(image_opacity), 0.0, 1.0)
	reference_image_position = image_position
	# Degrees, and the world point they turn around; the caller decides which
	# point that is, so the Canvas never has to guess an Asset Pivot of its own.
	reference_image_rotation = image_rotation if is_finite(image_rotation) else 0.0
	reference_image_rotation_pivot = image_rotation_pivot if image_rotation_pivot.is_finite() else Vector2.ZERO
	# Normalized reference images can require scales below 0.01 when their
	# source resolution is large. Keep the positive guard, but do not impose a
	# centimeter-scale minimum that changes the requested target height.
	reference_image_scale = maxf(float(image_scale), 0.000001)
	queue_redraw()


func set_navigation_locked(locked: bool) -> void:
	navigation_locked = locked
	if navigation_locked:
		_clear_navigation_input()


func set_command_shortcut_active(active: bool) -> void:
	command_shortcut_active = active
	if command_shortcut_active:
		_clear_navigation_input()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_navigation_input()


func _update_navigation_input(event: InputEventKey) -> void:
	if event.keycode not in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E]:
		return
	if not event.pressed:
		navigation_keys_pressed.erase(event.keycode)
		return
	if event.meta_pressed or event.ctrl_pressed or event.alt_pressed:
		_clear_navigation_input()
		return
	navigation_keys_pressed[event.keycode] = true


func _clear_navigation_input() -> void:
	navigation_keys_pressed.clear()


func _navigation_input_vector() -> Vector3:
	return Vector3(
		float(navigation_keys_pressed.has(KEY_D)) - float(navigation_keys_pressed.has(KEY_A)),
		float(navigation_keys_pressed.has(KEY_W)) - float(navigation_keys_pressed.has(KEY_S)),
		float(navigation_keys_pressed.has(KEY_E)) - float(navigation_keys_pressed.has(KEY_Q))
	)


func _local_to_world(local_point: Vector2) -> Vector2:
	return _local_to_world_with_transform(local_point, component_transform)


func _local_to_world_with_transform(local_point: Vector2, transform: Dictionary) -> Vector2:
	var pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
	var transform_position: Vector2 = transform.get("position", Vector2.ZERO)
	var transform_scale: Vector2 = transform.get("scale", Vector2.ONE)
	var transform_rotation := deg_to_rad(float(transform.get("rotation", 0.0)))
	return transform_position + ((local_point - pivot) * transform_scale).rotated(transform_rotation)


func _world_to_local(world_point: Vector2) -> Vector2:
	var pivot: Vector2 = component_transform.get("pivot", Vector2.ZERO)
	var transform_position: Vector2 = component_transform.get("position", Vector2.ZERO)
	var transform_scale: Vector2 = component_transform.get("scale", Vector2.ONE)
	var transform_rotation := deg_to_rad(float(component_transform.get("rotation", 0.0)))
	var local_offset := (world_point - transform_position).rotated(-transform_rotation)
	if not is_zero_approx(transform_scale.x):
		local_offset.x /= transform_scale.x
	if not is_zero_approx(transform_scale.y):
		local_offset.y /= transform_scale.y
	return pivot + local_offset


func clear_selection() -> void:
	selected_point_id = ""
	selected_point_ids.clear()
	point_selection_changed.emit(selected_point_id)
	point_selection_set_changed.emit([])
	_set_selected_edge_ids([])
	face_selected = false
	face_selection_changed.emit(false)


func set_display_polygon(points: Array, closed := true) -> void:
	display_polygon.clear()
	for point in points:
		display_polygon.append(point)
	display_polygon_closed = closed
	queue_redraw()


func set_bezier_geometry(points: Array, edges: Array, chains: Array) -> void:
	bezier_points.clear()
	bezier_edges.clear()
	bezier_chains.clear()
	for point_data in points:
		if point_data is Dictionary:
			bezier_points.append(point_data.duplicate(true))
	for edge_data in edges:
		if edge_data is Dictionary:
			bezier_edges.append(edge_data.duplicate(true))
	for chain_data in chains:
		if chain_data is Dictionary:
			bezier_chains.append(chain_data.duplicate(true))
	var valid_selection: Array[String] = []
	for point_id in selected_point_ids:
		if _point_index_by_id(point_id) >= 0:
			valid_selection.append(point_id)
	selected_point_ids = valid_selection
	selected_point_id = selected_point_ids[0] if selected_point_ids.size() == 1 else ""
	var valid_edge_selection: Array[String] = []
	for edge_id in selected_edge_ids:
		if not _edge_by_id(edge_id).is_empty():
			valid_edge_selection.append(edge_id)
	_set_selected_edge_ids(valid_edge_selection)
	_drop_stale_measure_guides()
	queue_redraw()


## The axis orientation is fixed by the invoking command. Mirror Y reflects
## across a vertical axis, Mirror X across a horizontal one, so the user only
## places the axis line itself.
func start_mirror_command(axis_orientation := MIRROR_AXIS_VERTICAL) -> bool:
	if selected_point_ids.is_empty() or axis_orientation not in [MIRROR_AXIS_VERTICAL, MIRROR_AXIS_HORIZONTAL]:
		return false
	mirror_command_stage = "axis"
	mirror_axis_orientation = axis_orientation
	mirror_axis_start = Vector2.ZERO
	mirror_axis_end = Vector2.ZERO
	mirror_axis_candidate_visible = false
	selection_mirror_preview_points.clear()
	selection_mirror_preview_edges.clear()
	mirror_axis_stage_changed.emit("axis")
	queue_redraw()
	return true


## The Ruler is a toggle rather than a command: once on, its guides stay drawn
## and keep resolving live while any other context command owns the Canvas, so
## a measurement can be watched while the Points it spans are edited. Only
## switching it off clears them.
func enable_measure_ruler() -> void:
	measure_ruler_enabled = true
	queue_redraw()


func disable_measure_ruler() -> void:
	measure_ruler_enabled = false
	measure_placing = false
	measure_stage = ""
	measure_cursor_visible = false
	measure_first_anchor = {}
	measure_segments.clear()
	queue_redraw()


func is_measure_ruler_enabled() -> bool:
	return measure_ruler_enabled


func is_measure_placing() -> bool:
	return measure_placing


## Placing is the half of the Ruler that claims Canvas clicks, so it follows the
## active context command while the guides themselves outlive it.
func set_measure_placing(placing: bool) -> void:
	var next_placing := placing and measure_ruler_enabled
	if next_placing == measure_placing:
		return
	measure_placing = next_placing
	measure_cursor_visible = false
	if measure_placing:
		measure_stage = "first"
		if cursor_over_canvas:
			measure_cursor_anchor = _measure_anchor_at(get_local_mouse_position())
			measure_cursor_visible = true
		measure_stage_changed.emit(measure_stage)
	else:
		measure_stage = ""
	queue_redraw()


func _place_measure_point(screen_position: Vector2) -> void:
	var measure_anchor := _measure_anchor_at(screen_position)
	measure_cursor_anchor = measure_anchor
	measure_cursor_visible = true
	if measure_stage == "second":
		measure_segments.append({"start": measure_first_anchor, "end": measure_anchor})
		measure_stage = "first"
	else:
		measure_first_anchor = measure_anchor
		measure_stage = "second"
	measure_stage_changed.emit(measure_stage)
	queue_redraw()


## Escape belongs to the Ruler while it runs, so the Canvas has to consume it.
## An unconsumed key reaches the editor's global Escape reset, which would end
## the very command the Ruler just stepped back inside.
func _consume_input_event() -> void:
	var current_viewport := get_viewport()
	if current_viewport != null:
		current_viewport.set_input_as_handled()


## Escape steps back over the placed Ruler Points and never ends the command.
## Taking the second Point of a finished guide back reopens its first Point as
## the live anchor, so several distances can be measured from one Point without
## stacking a guide for each of them.
func _undo_last_measure_point() -> void:
	if measure_stage == "second":
		measure_stage = "first"
	elif not measure_segments.is_empty():
		var reopened_guide: Dictionary = measure_segments.pop_back()
		measure_first_anchor = reopened_guide.get("start", {})
		measure_stage = "second"
	else:
		return
	measure_stage_changed.emit(measure_stage)
	queue_redraw()


## A Ruler Point prefers an authored Point within the pick radius and then keeps
## its identity rather than its coordinates, so moving that Point in Edit Point
## updates the measurement instead of leaving a stale number behind. Everything
## else falls back to the snapped raster position.
func _measure_anchor_at(screen_position: Vector2) -> Dictionary:
	var nearest_index := _nearest_bezier_point(screen_position)
	if nearest_index >= 0:
		return {
			"point_id": str(bezier_points[nearest_index].get("id", "")),
			"position": Vector2(bezier_points[nearest_index].get("position", Vector2.ZERO))
		}
	return {"point_id": "", "position": _snap_to_grid(_world_to_local(_screen_to_world(screen_position)))}


func _measure_anchor_position(measure_anchor: Dictionary) -> Vector2:
	var point_id := str(measure_anchor.get("point_id", ""))
	if not point_id.is_empty():
		var anchored_point := _point_by_id(point_id)
		if not anchored_point.is_empty():
			return Vector2(anchored_point.get("position", Vector2.ZERO))
	return Vector2(measure_anchor.get("position", Vector2.ZERO))


func _measure_anchor_is_live(measure_anchor: Dictionary) -> bool:
	var point_id := str(measure_anchor.get("point_id", ""))
	return point_id.is_empty() or _point_index_by_id(point_id) >= 0


## A guide that lost the Point it was anchored to has nothing left to report, so
## it goes rather than freezing at a coordinate the Point no longer occupies.
func _drop_stale_measure_guides() -> void:
	for guide_index in range(measure_segments.size() - 1, -1, -1):
		var guide: Dictionary = measure_segments[guide_index]
		if not _measure_anchor_is_live(guide.get("start", {})) or not _measure_anchor_is_live(guide.get("end", {})):
			measure_segments.remove_at(guide_index)
	if measure_stage == "second" and not _measure_anchor_is_live(measure_first_anchor):
		measure_first_anchor = {}
		measure_stage = "first"
		measure_stage_changed.emit(measure_stage)


func cancel_mirror_command(should_emit_signal := true) -> void:
	if mirror_command_stage.is_empty():
		return
	mirror_command_stage = ""
	mirror_axis_candidate_visible = false
	selection_mirror_preview_points.clear()
	selection_mirror_preview_edges.clear()
	queue_redraw()
	if should_emit_signal:
		mirror_axis_cancelled.emit()


func set_selected_point_ids(point_ids: Array) -> void:
	_set_selected_point_ids(point_ids)


func place_pivot_at_mouse() -> bool:
	return _place_pivot_at_screen_position(get_local_mouse_position())


func _place_pivot_at_screen_position(screen_position: Vector2) -> bool:
	if context_name.is_empty() or interaction_state not in ["", "edit", "transform"]:
		return false
	var old_pivot: Vector2 = component_transform.get("pivot", Vector2.ZERO)
	var new_pivot := _snap_pivot_position(_world_to_local(_screen_to_world(screen_position)))
	var transform_scale: Vector2 = component_transform.get("scale", Vector2.ONE)
	var transform_rotation := deg_to_rad(float(component_transform.get("rotation", 0.0)))
	var transform_position: Vector2 = component_transform.get("position", Vector2.ZERO)
	transform_position += ((new_pivot - old_pivot) * transform_scale).rotated(transform_rotation)
	component_transform["pivot"] = new_pivot
	component_transform["position"] = transform_position
	pivot_changed.emit(new_pivot)
	transform_changed.emit(component_transform.duplicate(true))
	queue_redraw()
	return true


func place_asset_pivot_at_mouse() -> bool:
	return _place_asset_pivot_at_screen_position(get_local_mouse_position())


func _place_asset_pivot_at_screen_position(screen_position: Vector2) -> bool:
	if context_name.is_empty() or interaction_state != "asset":
		return false
	asset_pivot = _snap_asset_pivot_position(_screen_to_world(screen_position))
	asset_pivot_changed.emit(asset_pivot)
	queue_redraw()
	return true


func mouse_world_position() -> Vector2:
	return _screen_to_world(get_local_mouse_position())


func mouse_local_position() -> Vector2:
	return _snap_pivot_position(_world_to_local(_screen_to_world(get_local_mouse_position())))


func _confirm_mirror_axis() -> void:
	if not mirror_axis_candidate_visible:
		return
	var confirmed_start := mirror_axis_start
	var confirmed_end := mirror_axis_end
	cancel_mirror_command(false)
	mirror_axis_confirmed.emit(confirmed_start, confirmed_end)


func _set_mirror_axis_from_screen(screen_position: Vector2) -> void:
	mirror_axis_start = _snap_to_grid(_world_to_local(_screen_to_world(screen_position)))
	mirror_axis_end = mirror_axis_start + _mirror_axis_direction()
	mirror_axis_candidate_visible = true


func _mirror_axis_direction() -> Vector2:
	return Vector2(1.0, 0.0) if mirror_axis_orientation == MIRROR_AXIS_HORIZONTAL else Vector2(0.0, 1.0)


## The fixed axis is conceptually infinite, so it is drawn across the visible
## Canvas rather than between two placed Points.
func _mirror_axis_screen_endpoints() -> PackedVector2Array:
	var min_local := _world_to_local(_screen_to_world(Vector2.ZERO))
	var max_local := min_local
	var screen_corners: Array[Vector2] = [Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]
	for screen_corner in screen_corners:
		var local_corner := _world_to_local(_screen_to_world(screen_corner))
		min_local = Vector2(minf(min_local.x, local_corner.x), minf(min_local.y, local_corner.y))
		max_local = Vector2(maxf(max_local.x, local_corner.x), maxf(max_local.y, local_corner.y))
	var margin := maxf(max_local.x - min_local.x, max_local.y - min_local.y) * 0.1 + 1.0
	var first_local := Vector2(mirror_axis_start.x, min_local.y - margin)
	var second_local := Vector2(mirror_axis_start.x, max_local.y + margin)
	if mirror_axis_orientation == MIRROR_AXIS_HORIZONTAL:
		first_local = Vector2(min_local.x - margin, mirror_axis_start.y)
		second_local = Vector2(max_local.x + margin, mirror_axis_start.y)
	return PackedVector2Array([
		_world_to_screen(_local_to_world(first_local)),
		_world_to_screen(_local_to_world(second_local))
	])


func _update_selection_mirror_preview() -> void:
	selection_mirror_preview_points.clear()
	selection_mirror_preview_edges.clear()
	if mirror_axis_start.distance_squared_to(mirror_axis_end) <= 0.00000001:
		return
	var component := {"points": bezier_points, "edges": bezier_edges, "chains": bezier_chains, "draw_mode": component_draw_mode}
	var result: Dictionary = SELECTION_MIRROR_SERVICE_SCRIPT.preview(component, selected_point_ids, mirror_axis_start, mirror_axis_end)
	if bool(result.get("valid", false)):
		for point in result.get("points", []):
			selection_mirror_preview_points.append(point)
		for edge in result.get("edges", []):
			selection_mirror_preview_edges.append(edge)


func set_transform_axes_local(enabled: bool) -> void:
	transform_axes_local = enabled
	queue_redraw()


func set_guide_style(enabled: bool) -> void:
	guide_style = enabled
	queue_redraw()


func set_guide_color(color: Color) -> void:
	guide_color = color
	queue_redraw()


func set_bezier_color_override(color: Color) -> void:
	bezier_color_override = color
	queue_redraw()


func _process(delta: float) -> void:
	if navigation_locked or command_shortcut_active or not has_focus():
		return
	var navigation_input := _navigation_input_vector()
	var pan_input := Vector2(navigation_input.x, navigation_input.y)
	if pan_input.length_squared() > 0.0:
		view_center += pan_input.normalized() * PAN_SPEED / zoom * delta
	var zoom_input := navigation_input.z
	if not is_zero_approx(zoom_input):
		zoom = clampf(zoom * pow(ZOOM_RATE, zoom_input * delta), MIN_ZOOM, MAX_ZOOM)
	queue_redraw()


func _draw() -> void:
	_draw_fixed_grid()
	var half_view := size / (2.0 * zoom)
	var min_world := view_center - half_view
	var max_world := view_center + half_view
	var x_axis_color := Color("#6a4d58")
	var y_axis_color := Color("#4c6a5b")
	draw_line(_world_to_screen(Vector2(min_world.x, 0.0)), _world_to_screen(Vector2(max_world.x, 0.0)), x_axis_color, 2.0)
	draw_line(_world_to_screen(Vector2(0.0, min_world.y)), _world_to_screen(Vector2(0.0, max_world.y)), y_axis_color, 2.0)
	_draw_frame_guide()
	_draw_reference_image()
	_draw_reference_shapes()
	_draw_selection_mirror_command()
	if not bezier_points.is_empty() and not bezier_chains.is_empty():
		_draw_bezier_geometry()
	elif display_polygon_closed and display_polygon.size() >= 3:
		_draw_primitive_geometry()
	_draw_pivot()
	_draw_transform_gizmo()
	_draw_selection_gizmo()
	_draw_point_selection_marquee()
	_draw_edge_selection_marquee()
	_draw_draw_preview()
	_draw_primitive_preview()
	_draw_ruler_command()
	_draw_measurement_guides()


func _draw_frame_guide() -> void:
	if not frame_visible:
		return
	var top_left_world := frame_offset + Vector2(-frame_half_extent.x, frame_half_extent.y)
	var frame_size := Vector2(frame_half_extent.x * 2.0, frame_half_extent.y * 2.0) * zoom
	var top_left_screen := _world_to_screen(top_left_world)
	draw_rect(Rect2(top_left_screen, frame_size), Color("#8fd8f8b0"), false, 2.0)


func _draw_fixed_grid() -> void:
	var main_grid_step := maxf(world_grid_size, 0.0001)
	var fine_grid_step := main_grid_step / 5.0
	var main_pixel_step := main_grid_step * zoom
	var fine_pixel_step := fine_grid_step * zoom
	if fine_pixel_step >= 1.0:
		_draw_grid_lines(fine_grid_step, Color("#20262f"), 1.0)
	if main_pixel_step >= 0.25:
		_draw_grid_lines(main_grid_step, Color("#303844"), 1.0)
	var package_level := _active_grid_package_level()
	var package_step := main_grid_step * pow(5.0, package_level)
	if package_level > 0:
		_draw_grid_lines(package_step, Color("#465263"), 1.5)


func _active_grid_package_level() -> int:
	var package_level := 0
	var package_step := maxf(world_grid_size, 0.0001)
	while package_step * zoom < GRID_PACKAGE_MIN_PIXELS:
		package_step *= 5.0
		package_level += 1
	return package_level


func _draw_selection_mirror_command() -> void:
	if not mirror_command_stage.is_empty() and mirror_axis_candidate_visible:
		var axis_endpoints := _mirror_axis_screen_endpoints()
		_draw_dashed_line(axis_endpoints[0], axis_endpoints[1], Color("#f2c94c"))
		var axis_marker := _world_to_screen(_local_to_world(mirror_axis_start))
		draw_circle(axis_marker, 6.0, Color("#f2c94c"), false, 2.5)
		draw_circle(axis_marker, 2.0, Color("#f2c94c"))
	var points_by_id: Dictionary = {}
	for point in selection_mirror_preview_points:
		points_by_id[str(point.get("id", ""))] = point
	for edge in selection_mirror_preview_edges:
		var start: Dictionary = points_by_id.get(str(edge.get("start_point_id", "")), {})
		var end: Dictionary = points_by_id.get(str(edge.get("end_point_id", "")), {})
		if not start.is_empty() and not end.is_empty():
			draw_polyline(_bezier_edge_screen_points(start, end), Color("#f2c94cbb"), 2.5, true)
	for point in selection_mirror_preview_points:
		draw_circle(_world_to_screen(_local_to_world(Vector2(point.get("position", Vector2.ZERO)))), 4.0, Color("#f2c94c"))


func _draw_grid_lines(step: float, line_color: Color, line_width: float) -> void:
	var half_view := size / (2.0 * zoom)
	var min_world := view_center - half_view
	var max_world := view_center + half_view
	var first_x := floori(min_world.x / step)
	var last_x := ceili(max_world.x / step)
	var first_y := floori(min_world.y / step)
	var last_y := ceili(max_world.y / step)
	for grid_index in range(first_x, last_x + 1):
		var world_x := grid_index * step
		draw_line(_world_to_screen(Vector2(world_x, min_world.y)), _world_to_screen(Vector2(world_x, max_world.y)), line_color, line_width)
	for grid_index in range(first_y, last_y + 1):
		var world_y := grid_index * step
		draw_line(_world_to_screen(Vector2(min_world.x, world_y)), _world_to_screen(Vector2(max_world.x, world_y)), line_color, line_width)


func _draw_ruler_command() -> void:
	if not measure_ruler_enabled:
		return
	for segment in measure_segments:
		var guide_start := _measure_anchor_position(segment.get("start", {}))
		var guide_end := _measure_anchor_position(segment.get("end", {}))
		_draw_ruler_guide(guide_start, guide_end)
		_draw_ruler_cross(guide_start)
		_draw_ruler_cross(guide_end)
	if not measure_placing:
		return
	var cursor_point := _measure_anchor_position(measure_cursor_anchor)
	if measure_stage == "second":
		var pending_start := _measure_anchor_position(measure_first_anchor)
		if measure_cursor_visible:
			_draw_ruler_guide(pending_start, cursor_point)
		_draw_ruler_cross(pending_start)
	# The cursor carries its own faint cross so the snapped target is visible
	# before a Point is placed, which the coordinate readout alone cannot show.
	if measure_cursor_visible:
		_draw_ruler_cross(cursor_point, true)


func _draw_ruler_guide(guide_start: Vector2, guide_end: Vector2) -> void:
	var start_world := _local_to_world(guide_start)
	var end_world := _local_to_world(guide_end)
	var start_screen := _world_to_screen(start_world)
	var end_screen := _world_to_screen(end_world)
	# The two legs close a right triangle over the measured span. They are World
	# axis aligned rather than Component local, so they stay horizontal and
	# vertical on screen even when the Component itself is rotated.
	var corner_screen := _world_to_screen(Vector2(end_world.x, start_world.y))
	var x_label_offset := Vector2(0.0, 16.0 if end_screen.y < start_screen.y else -16.0)
	var y_label_offset := Vector2(34.0 if corner_screen.x >= start_screen.x else -34.0, 0.0)
	_draw_ruler_leg(start_screen, corner_screen, RULER_X_COLOR, absf(end_world.x - start_world.x), x_label_offset)
	_draw_ruler_leg(corner_screen, end_screen, RULER_Y_COLOR, absf(end_world.y - start_world.y), y_label_offset)
	_draw_dashed_line(start_screen, end_screen, RULER_COLOR)
	var distance_label := "%.2f cm" % ToolUnits.to_centimeters(start_world.distance_to(end_world))
	_draw_measurement_label(distance_label, (start_screen + end_screen) * 0.5 + Vector2(0.0, -14.0), RULER_COLOR)


## A leg that collapses to a few pixels carries no readable distance, so a purely
## horizontal or vertical measurement shows one leg rather than a stray zero.
func _draw_ruler_leg(leg_start: Vector2, leg_end: Vector2, leg_color: Color, leg_distance: float, label_offset: Vector2) -> void:
	if leg_start.distance_to(leg_end) < RULER_LEG_MIN_PIXELS:
		return
	_draw_dashed_line(leg_start, leg_end, leg_color)
	_draw_measurement_label("%.2f cm" % ToolUnits.to_centimeters(leg_distance), (leg_start + leg_end) * 0.5 + label_offset, leg_color)


func _draw_ruler_cross(guide_point: Vector2, pending := false) -> void:
	var center := _world_to_screen(_local_to_world(guide_point))
	var cross_color := Color(RULER_COLOR, 0.55) if pending else RULER_COLOR
	var cross_width := 1.5 if pending else 2.0
	draw_line(center - Vector2(RULER_CROSS_RADIUS, 0.0), center + Vector2(RULER_CROSS_RADIUS, 0.0), cross_color, cross_width)
	draw_line(center - Vector2(0.0, RULER_CROSS_RADIUS), center + Vector2(0.0, RULER_CROSS_RADIUS), cross_color, cross_width)


func _draw_measurement_guides() -> void:
	if not cursor_over_canvas or context_name.is_empty():
		return
	var origin_world := Vector2.ZERO
	var cursor_position_world := cursor_world
	if interaction_state.is_empty():
		origin_world = component_transform.get("position", Vector2.ZERO)
		cursor_position_world = _local_to_world(cursor_world)
	var cursor_screen := _world_to_screen(cursor_position_world)
	var measurement_guide_color := Color("#f2c94c")
	var coordinate_lines: Array[String] = []
	coordinate_lines.append("x: %.2f cm" % ToolUnits.to_centimeters(cursor_position_world.x - origin_world.x))
	coordinate_lines.append("y: %.2f cm" % ToolUnits.to_centimeters(cursor_position_world.y - origin_world.y))
	_draw_coordinate_readout(coordinate_lines, cursor_screen, measurement_guide_color, interaction_state == "edit")


func _draw_dashed_line(line_start: Vector2, line_end: Vector2, line_color: Color) -> void:
	var line_vector := line_end - line_start
	var line_length := line_vector.length()
	if line_length <= 0.5:
		return
	var direction := line_vector / line_length
	var distance := 0.0
	while distance < line_length:
		var dash_end := minf(distance + MEASUREMENT_DASH_LENGTH, line_length)
		draw_line(line_start + direction * distance, line_start + direction * dash_end, line_color, 1.0)
		distance = dash_end + MEASUREMENT_GAP_LENGTH


func _draw_measurement_label(label_text: String, label_center: Vector2, label_color: Color) -> void:
	var label_font := ThemeDB.fallback_font
	var text_size := label_font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, MEASUREMENT_FONT_SIZE)
	var label_rect := Rect2(label_center - text_size * 0.5 - Vector2(4.0, 2.0), text_size + Vector2(8.0, 4.0))
	draw_rect(label_rect, Color("#181a1fcc"))
	draw_string(label_font, label_rect.position + Vector2(4.0, text_size.y), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, MEASUREMENT_FONT_SIZE, label_color)


func _draw_coordinate_readout(lines: Array[String], cursor_screen: Vector2, label_color: Color, prefer_bottom_right := false) -> void:
	var label_font := ThemeDB.fallback_font
	var line_height := float(MEASUREMENT_FONT_SIZE + 4)
	var max_width := 0.0
	for line in lines:
		max_width = maxf(max_width, label_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, MEASUREMENT_FONT_SIZE).x)
	var label_size := Vector2(max_width + 12.0, line_height * lines.size() + 8.0)
	var label_position := cursor_screen + (Vector2(label_size.x + 14.0, label_size.y + 14.0) if prefer_bottom_right else Vector2(14.0, -label_size.y - 14.0))
	label_position.x = clampf(label_position.x, 4.0, maxf(4.0, size.x - label_size.x - 4.0))
	label_position.y = clampf(label_position.y, 4.0, maxf(4.0, size.y - label_size.y - 4.0))
	var label_rect := Rect2(label_position, label_size)
	draw_rect(label_rect, Color("#181a1f"))
	for line_index in range(lines.size()):
		var baseline := label_position + Vector2(6.0, 4.0 + line_height * float(line_index + 1) - 2.0)
		draw_string(label_font, baseline, lines[line_index], HORIZONTAL_ALIGNMENT_LEFT, -1, MEASUREMENT_FONT_SIZE, label_color)


func _draw_reference_image() -> void:
	if not is_instance_valid(reference_image) or not reference_image_visible:
		return
	var image_size := Vector2(reference_image.get_width(), reference_image.get_height()) * reference_image_scale * zoom
	if image_size.x <= 0.0 or image_size.y <= 0.0:
		return
	var image_center := _world_to_screen(reference_image_position)
	var image_rect := Rect2(image_center - image_size * 0.5, image_size)
	var image_modulate := Color(1.0, 1.0, 1.0, reference_image_opacity)
	if is_zero_approx(reference_image_rotation):
		draw_texture_rect(reference_image, image_rect, false, image_modulate)
		return
	# The draw transform turns around the pivot in screen space, so the rect is
	# expressed relative to that point and the transform is reset afterwards —
	# everything drawn after this belongs to the unrotated Canvas. The screen Y
	# axis points the other way than the world one, so the authored angle is
	# negated to turn counter-clockwise on screen like every other rotation.
	var pivot_screen := _world_to_screen(reference_image_rotation_pivot)
	draw_set_transform(pivot_screen, deg_to_rad(-reference_image_rotation), Vector2.ONE)
	draw_texture_rect(reference_image, Rect2(image_rect.position - pivot_screen, image_size), false, image_modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pivot() -> void:
	if context_name.is_empty():
		return
	if interaction_state == "asset":
		var asset_pivot_screen := _world_to_screen(asset_pivot)
		var asset_pivot_color := Color("#d98cff")
		draw_circle(asset_pivot_screen, 8.0, asset_pivot_color, false, 2.0)
		draw_line(asset_pivot_screen - Vector2(13.0, 0.0), asset_pivot_screen + Vector2(13.0, 0.0), asset_pivot_color, 1.5)
		draw_line(asset_pivot_screen - Vector2(0.0, 13.0), asset_pivot_screen + Vector2(0.0, 13.0), asset_pivot_color, 1.5)
		return
	var pivot_screen := _world_to_screen(component_transform.get("position", Vector2.ZERO))
	var pivot_color := Color("#d98cff")
	if interaction_state.is_empty():
		draw_circle(pivot_screen, 10.0, Color("#d98cff44"))
		draw_circle(pivot_screen, 8.0, pivot_color, false, 2.0)
	else:
		draw_circle(pivot_screen, 7.0, pivot_color, false, 2.0)
	draw_line(pivot_screen - Vector2(11.0, 0.0), pivot_screen + Vector2(11.0, 0.0), pivot_color, 1.0)
	draw_line(pivot_screen - Vector2(0.0, 11.0), pivot_screen + Vector2(0.0, 11.0), pivot_color, 1.0)


## The world direction of one Transform gizmo axis. Without
## `transform_axes_local` this is the world axis the handle has always
## constrained to; with it, the same axis turned by the authored rotation.
## Any other handle name — the free centre, rotate, scale — has no axis.
func _transform_axis_direction(axis_name: String) -> Vector2:
	if axis_name != "x" and axis_name != "y":
		return Vector2.ZERO
	var axis := Vector2(1.0, 0.0) if axis_name == "x" else Vector2(0.0, 1.0)
	if not transform_axes_local:
		return axis
	return axis.rotated(deg_to_rad(float(component_transform.get("rotation", 0.0))))


## The screen offset of an axis handle from the gizmo centre. Screen Y
## grows downwards while world Y grows upwards, so the world direction is
## flipped once here rather than at every call site.
func _transform_axis_screen_offset(axis_name: String, length: float) -> Vector2:
	var axis := _transform_axis_direction(axis_name)
	return Vector2(axis.x, -axis.y) * length


func _draw_transform_gizmo() -> void:
	if interaction_state != "transform" or context_name.is_empty():
		return
	var center := _world_to_screen(component_transform.get("position", Vector2.ZERO))
	if transform_mode == "rotate":
		draw_arc(center, 34.0, 0.0, TAU, 48, Color("#f2c94c"), 2.0)
		draw_circle(center + _transform_axis_screen_offset("y", 34.0), 7.0, Color("#f2c94c"))
	elif transform_mode == "scale":
		var box := Rect2(center - Vector2(30.0, 30.0), Vector2(60.0, 60.0))
		draw_rect(box, Color("#8ab4f8"), false, 2.0)
		for corner in [box.position, box.position + Vector2(box.size.x, 0.0), box.position + Vector2(0.0, box.size.y), box.end]:
			draw_circle(corner, 6.0, Color("#8ab4f8"))
	else:
		var x_handle := center + _transform_axis_screen_offset("x", 44.0)
		var y_handle := center + _transform_axis_screen_offset("y", 44.0)
		draw_line(center, x_handle, Color("#e56b6f"), 2.0)
		draw_line(center, y_handle, Color("#6bcB77"), 2.0)
		draw_circle(x_handle, 7.0, Color("#e56b6f"))
		draw_circle(y_handle, 7.0, Color("#6bcB77"))
		draw_rect(Rect2(center - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), Color("#f2c94c"), false, 2.0)


func _transform_handle_at(screen_position: Vector2) -> String:
	var center := _world_to_screen(component_transform.get("position", Vector2.ZERO))
	if transform_mode == "rotate":
		var distance_to_center := screen_position.distance_to(center)
		if distance_to_center >= 24.0 and distance_to_center <= 46.0:
			return "rotate"
		return ""
	if transform_mode == "scale":
		for corner in [Vector2(30.0, -30.0), Vector2(-30.0, -30.0), Vector2(30.0, 30.0), Vector2(-30.0, 30.0)]:
			if screen_position.distance_to(center + corner) <= 12.0:
				return "scale_uniform"
		return ""
	if screen_position.distance_to(center) <= 12.0:
		return "free"
	if screen_position.distance_to(center + _transform_axis_screen_offset("x", 44.0)) <= 12.0:
		return "x"
	if screen_position.distance_to(center + _transform_axis_screen_offset("y", 44.0)) <= 12.0:
		return "y"
	return ""


func _angle_from_transform_center(screen_position: Vector2) -> float:
	var center := _world_to_screen(component_transform.get("position", Vector2.ZERO))
	var screen_offset := screen_position - center
	return Vector2(screen_offset.x, -screen_offset.y).angle()


func _is_near_pivot(screen_position: Vector2) -> bool:
	if context_name.is_empty() or interaction_state == "asset":
		return false
	var pivot_position: Vector2 = component_transform.get("position", Vector2.ZERO)
	return screen_position.distance_to(_world_to_screen(pivot_position)) <= 12.0


func _is_near_asset_pivot(screen_position: Vector2) -> bool:
	return interaction_state == "asset" and screen_position.distance_to(_world_to_screen(asset_pivot)) <= 14.0


func _draw_reference_shapes() -> void:
	var ordered_shapes := reference_shapes.duplicate()
	ordered_shapes.sort_custom(_sort_reference_shapes)
	for shape in ordered_shapes:
		if not bool(shape.get("visibility", true)):
			continue
		var bezier_shape_points: Array = shape.get("bezier_points", [])
		var bezier_shape_edges: Array = shape.get("edges", [])
		var bezier_shape_chains: Array = shape.get("chains", [])
		if not bezier_shape_points.is_empty() and not bezier_shape_edges.is_empty() and not bezier_shape_chains.is_empty():
			_draw_reference_bezier_shape(shape, bezier_shape_points, bezier_shape_edges, bezier_shape_chains)
			continue
		var points: Array = shape.get("points", [])
		if points.is_empty():
			continue
		var transform: Dictionary = shape.get("transform", {})
		var closed := bool(shape.get("closed", points.size() >= 3))
		var emphasized := bool(shape.get("emphasized", false))
		var is_hole := WorldDocumentService.topology_role(shape) == WorldDocumentService.ROLE_HOLE
		var role_color := Color("#ef6c78") if is_hole else Color("#55c7d9")
		var reference_color := role_color if emphasized else Color(role_color.r, role_color.g, role_color.b, 0.4)
		var reference_width := 3.5 if emphasized else 2.0
		var edge_count := points.size() if closed and points.size() >= 3 else maxi(points.size() - 1, 0)
		for index in range(edge_count):
			var next_index := (index + 1) % points.size()
			draw_line(_world_to_screen(_local_to_world_with_transform(points[index], transform)), _world_to_screen(_local_to_world_with_transform(points[next_index], transform)), reference_color, reference_width)
		for point in points:
			draw_circle(_world_to_screen(_local_to_world_with_transform(point, transform)), 3.0, reference_color)


func _draw_reference_bezier_shape(shape: Dictionary, points: Array, edges: Array, chains: Array) -> void:
	var transform: Dictionary = shape.get("transform", {})
	var points_by_id: Dictionary = {}
	for point_data in points:
		if point_data is Dictionary:
			points_by_id[str(point_data.get("id", ""))] = point_data
	var edges_by_id: Dictionary = {}
	for edge_data in edges:
		if edge_data is Dictionary:
			edges_by_id[str(edge_data.get("id", ""))] = edge_data
	var emphasized := bool(shape.get("emphasized", false))
	var is_hole := WorldDocumentService.topology_role(shape) == WorldDocumentService.ROLE_HOLE
	var role_color := Color("#ef6c78") if is_hole else Color("#55c7d9")
	var reference_color := role_color if emphasized else Color(role_color.r, role_color.g, role_color.b, 0.4)
	var reference_width := 3.5 if emphasized else 2.0
	for chain_data in chains:
		if not chain_data is Dictionary:
			continue
		for edge_id_value in chain_data.get("edge_ids", []):
			var edge_id := str(edge_id_value)
			if not edges_by_id.has(edge_id):
				continue
			var edge_data: Dictionary = edges_by_id[edge_id]
			var start_id := str(edge_data.get("start_point_id", ""))
			var end_id := str(edge_data.get("end_point_id", ""))
			if not points_by_id.has(start_id) or not points_by_id.has(end_id):
				continue
			var start_point: Dictionary = points_by_id[start_id]
			var end_point: Dictionary = points_by_id[end_id]
			var curve_points := _bezier_edge_screen_points_with_transform(start_point, end_point, transform)
			if curve_points.size() >= 2:
				if bool(edge_data.get("render_outline", true)):
					draw_polyline(curve_points, reference_color, reference_width, true)
				else:
					_draw_dashed_polyline(curve_points, reference_color, reference_width)
	for point_data in points:
		if point_data is Dictionary:
			draw_circle(_world_to_screen(_local_to_world_with_transform(point_data.get("position", Vector2.ZERO), transform)), 3.0, reference_color)


func _sort_reference_shapes(a: Dictionary, b: Dictionary) -> bool:
	if bool(a.get("emphasized", false)) != bool(b.get("emphasized", false)):
		return not bool(a.get("emphasized", false))
	return int(a.get("z_index", 0)) < int(b.get("z_index", 0))


func _reference_component_at(world_position: Vector2) -> String:
	var nearest_id := ""
	var nearest_distance := 14.0
	var ordered_shapes := reference_shapes.duplicate()
	ordered_shapes.sort_custom(_sort_reference_shapes)
	ordered_shapes.reverse()
	for shape in ordered_shapes:
		if not bool(shape.get("visibility", true)):
			continue
		var points: Array = shape.get("points", [])
		if points.size() < 2:
			continue
		var transform: Dictionary = shape.get("transform", {})
		var world_points: Array[Vector2] = []
		for point in points:
			world_points.append(_local_to_world_with_transform(point, transform))
		if bool(shape.get("closed", points.size() >= 3)) and Geometry2D.is_point_in_polygon(world_position, PackedVector2Array(world_points)):
			return str(shape.get("id", ""))
		for index in range(world_points.size()):
			var next_index := (index + 1) % world_points.size()
			var closest := Geometry2D.get_closest_point_to_segment(world_position, world_points[index], world_points[next_index])
			var distance := world_position.distance_to(closest)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_id = str(shape.get("id", ""))
	return nearest_id


## The preview is drawn from the very record the placement will commit, so what
## is on the Canvas and what lands in the document cannot drift apart.
func _draw_primitive_preview() -> void:
	if not primitive_preview_is_active() or not cursor_over_canvas:
		return
	var preview_center := primitive_preview_center if primitive_preview_stage == PRIMITIVE_STAGE_SIZE else cursor_world
	var size_cm := primitive_preview_size_cm(cursor_world)
	var outline := PrimitiveGeometryService.contour({
		"draw_mode": WorldDocumentService.DRAW_MODE_PRIMITIVE,
		"primitive": PrimitiveGeometryService.build(primitive_preview_shape, preview_center, size_cm)})
	if outline.is_empty():
		return
	var screen_points := PackedVector2Array()
	for point in outline:
		screen_points.append(_world_to_screen(_local_to_world(point)))
	screen_points.append(screen_points[0])
	draw_polyline(screen_points, Color("#f2c94c"), 2.0, true)
	var screen_center := _world_to_screen(_local_to_world(preview_center))
	draw_circle(screen_center, 5.0, Color("#f2c94c"))
	var half_height := ToolUnits.from_centimeters(size_cm.y) * 0.5 * zoom
	var shape_name := PrimitiveGeometryService.display_name(primitive_preview_shape)
	var label := "%s · %.1f cm" % [shape_name, size_cm.x]
	if primitive_preview_shape != PrimitiveGeometryService.CIRCLE:
		label = "%s · %.1f × %.1f cm" % [shape_name, size_cm.x, size_cm.y]
	_draw_measurement_label(label, screen_center + Vector2(0.0, -half_height - 16.0), Color("#f2c94c"))


## The colour the Component's own geometry is drawn in: a Region paints it in the
## Region colour, a Guide in its Guide colour, everything else in the ordinary
## Component blue. Bezier and Primitive geometry have to answer the same way -
## while only the Bezier side asked, a Region drawn from a Primitive stayed blue
## while the identical Region on a Closed Loop turned red.
func _shape_color() -> Color:
	if bezier_color_override.a > 0.0:
		return bezier_color_override
	return guide_color if guide_style else Color("#55c7d9")


func _draw_primitive_geometry() -> void:
	if not bool(component_transform.get("visibility", true)):
		return
	var screen_points := PackedVector2Array()
	for point in display_polygon:
		screen_points.append(_world_to_screen(_local_to_world(point)))
	var shape_color := _shape_color()
	draw_colored_polygon(screen_points, Color(shape_color, PRIMITIVE_FILL_ALPHA))
	var outline := screen_points.duplicate()
	outline.append(screen_points[0])
	draw_polyline(outline, shape_color, 2.0, true)
	draw_circle(_world_to_screen(_local_to_world(_primitive_center())), 6.0, Color("#f2c94c"))


func _is_near_primitive_center(screen_position: Vector2) -> bool:
	if display_polygon.is_empty():
		return false
	return screen_position.distance_to(_world_to_screen(_local_to_world(_primitive_center()))) <= 12.0


## The Primitive's centre as the Canvas knows it: the centroid of the sampled
## outline. Drawing the handle, hitting it and snapping the Pivot to it must all
## mean the same point, so they all ask here.
func _primitive_center() -> Vector2:
	if display_polygon.is_empty():
		return Vector2.ZERO
	var center := Vector2.ZERO
	for point in display_polygon:
		center += point
	return center / float(display_polygon.size())


func _draw_bezier_geometry() -> void:
	if not bool(component_transform.get("visibility", true)):
		return
	var points_by_id: Dictionary = {}
	for point_data in bezier_points:
		points_by_id[str(point_data.get("id", ""))] = point_data
	var edges_by_id: Dictionary = {}
	for edge_data in bezier_edges:
		edges_by_id[str(edge_data.get("id", ""))] = edge_data
	var has_color_override := bezier_color_override.a > 0.0
	var shape_color := _shape_color()
	var edit_highlight := shape_color.lightened(0.18) if has_color_override else Color("#f2c94c")
	var point_mode_highlight := edit_highlight if interaction_state == "edit" and edit_mode in ["point", "face"] else shape_color
	var edge_mode_highlight := edit_highlight if interaction_state == "edit" and edit_mode in ["edge", "face"] else shape_color
	var selection_color := shape_color.lightened(0.28) if has_color_override else guide_color if guide_style else Color("#8fd8f8")
	if interaction_state == "edit" and edit_mode == "face" and face_selected and display_polygon_closed and display_polygon.size() >= 3:
		var face_color := Color(shape_color, 0.2) if has_color_override else Color("#8fd8f833")
		draw_colored_polygon(PackedVector2Array(display_polygon.map(func(point: Vector2) -> Vector2: return _world_to_screen(_local_to_world(point)))), face_color)
	for chain_data in bezier_chains:
		for edge_id_value in chain_data.get("edge_ids", []):
			var edge_id := str(edge_id_value)
			if not edges_by_id.has(edge_id):
				continue
			var edge_data: Dictionary = edges_by_id[edge_id]
			var start_id := str(edge_data.get("start_point_id", ""))
			var end_id := str(edge_data.get("end_point_id", ""))
			if not points_by_id.has(start_id) or not points_by_id.has(end_id):
				continue
			var start_point: Dictionary = points_by_id[start_id]
			var end_point: Dictionary = points_by_id[end_id]
			var curve_points := _bezier_edge_screen_points(start_point, end_point)
			if curve_points.size() >= 2:
				var edge_color := selection_color if edge_id in selected_edge_ids or (edit_mode == "face" and face_selected) else edge_mode_highlight
				if guide_style or not bool(edge_data.get("render_outline", true)):
					_draw_dashed_polyline(curve_points, edge_color, 2.0)
				else:
					draw_polyline(curve_points, edge_color, 2.0, true)
	if interaction_state != "transform":
		for point_data in bezier_points:
			var point_position: Vector2 = point_data.get("position", Vector2.ZERO)
			var point_id := str(point_data.get("id", ""))
			var point_color := selection_color if point_id in selected_point_ids or (edit_mode == "face" and face_selected) else point_mode_highlight
			draw_circle(_world_to_screen(_local_to_world(point_position)), 4.0, point_color)
	if interaction_state == "edit" and edit_mode == "point" and point_numbers_visible:
		var next_point_number := 1
		var numbered_ids: Dictionary = {}
		for chain_data in bezier_chains:
			var chain_point_ids: Array = chain_data.get("point_ids", [])
			for point_id_value in chain_point_ids:
				var point_id := str(point_id_value)
				if numbered_ids.has(point_id):
					continue
				var numbered_point := _point_by_id(point_id)
				if numbered_point.is_empty():
					continue
				numbered_ids[point_id] = true
				var numbered_position: Vector2 = numbered_point.get("position", Vector2.ZERO)
				draw_string(ThemeDB.fallback_font, _world_to_screen(_local_to_world(numbered_position)) + Vector2(8.0, -8.0), str(next_point_number), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f2c94c"))
				next_point_number += 1
	if interaction_state == "edit" and edit_mode == "point" and edit_point_set_enabled and cursor_over_canvas:
		var add_point_hit := _bezier_edge_hit(_world_to_screen(_local_to_world(cursor_world)))
		if not add_point_hit.is_empty():
			var preview_edge := _edge_by_id(str(add_point_hit.get("id", "")))
			var preview_start := _point_by_id(str(preview_edge.get("start_point_id", "")))
			var preview_end := _point_by_id(str(preview_edge.get("end_point_id", "")))
			if not preview_start.is_empty() and not preview_end.is_empty():
				var preview_position := BezierGeometry.cubic_position(BezierGeometry.cubic_controls(preview_start, preview_end), float(add_point_hit.get("t", 0.5)))
				var preview_screen := _world_to_screen(_local_to_world(preview_position))
				draw_circle(preview_screen, 8.0, Color("#f2c94c"), false, 2.5)
				draw_circle(preview_screen, 3.0, Color("#f2c94c"))
	var selected_point := _point_by_id(selected_point_id)
	if interaction_state == "edit" and not selected_point.is_empty():
		var selected_position: Vector2 = selected_point.get("position", Vector2.ZERO)
		var selected_screen := _world_to_screen(_local_to_world(selected_position))
		draw_circle(selected_screen, 7.0, selection_color, false, 2.0)
		if edit_handles_enabled:
			_draw_bezier_handle_preview(selected_point)
	if interaction_state == "edit" and edit_mode == "point" and not edit_handles_enabled and not edit_point_set_enabled:
		for point_id in selected_point_ids:
			var selected_point_data := _point_by_id(point_id)
			if selected_point_data.is_empty():
				continue
			var selected_position: Vector2 = selected_point_data.get("position", Vector2.ZERO)
			draw_circle(_world_to_screen(_local_to_world(selected_position)), 7.0, selection_color, false, 2.0)


func _selected_points_center() -> Vector2:
	if selected_point_ids.is_empty():
		return Vector2.ZERO
	var center := Vector2.ZERO
	var valid_count := 0
	for point_id in selected_point_ids:
		var point_data := _point_by_id(point_id)
		if point_data.is_empty():
			continue
		center += Vector2(point_data.get("position", Vector2.ZERO))
		valid_count += 1
	return center / float(valid_count) if valid_count > 0 else Vector2.ZERO


func _selection_gizmo_at(screen_position: Vector2) -> String:
	if selected_point_ids.is_empty():
		return ""
	var center := _world_to_screen(_local_to_world(_selected_points_center()))
	if screen_position.distance_to(center) <= 12.0:
		return "move"
	if screen_position.distance_to(center + Vector2(GIZMO_AXIS_LENGTH, 0.0)) <= 12.0:
		return "x"
	if screen_position.distance_to(center + Vector2(0.0, -GIZMO_AXIS_LENGTH)) <= 12.0:
		return "y"
	return ""


func _draw_selection_gizmo() -> void:
	if interaction_state != "edit":
		return
	if edit_mode == "face":
		if not face_selected or not display_polygon_closed or display_polygon.size() < 3:
			return
		var face_center := _face_center_screen()
		draw_line(face_center, face_center + Vector2(GIZMO_AXIS_LENGTH, 0.0), Color("#e56b6f"), 2.0)
		draw_line(face_center, face_center + Vector2(0.0, -GIZMO_AXIS_LENGTH), Color("#6bcb77"), 2.0)
		draw_circle(face_center + Vector2(GIZMO_AXIS_LENGTH, 0.0), 7.0, Color("#e56b6f"))
		draw_circle(face_center + Vector2(0.0, -GIZMO_AXIS_LENGTH), 7.0, Color("#6bcb77"))
		draw_rect(Rect2(face_center - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), Color("#8fd8f8"), false, 2.0)
		return
	if edit_mode != "point" or edit_handles_enabled or edit_point_set_enabled or selected_point_ids.is_empty():
		return
	var center := _world_to_screen(_local_to_world(_selected_points_center()))
	draw_line(center, center + Vector2(GIZMO_AXIS_LENGTH, 0.0), Color("#e56b6f"), 2.0)
	draw_line(center, center + Vector2(0.0, -GIZMO_AXIS_LENGTH), Color("#6bcb77"), 2.0)
	draw_circle(center + Vector2(GIZMO_AXIS_LENGTH, 0.0), 7.0, Color("#e56b6f"))
	draw_circle(center + Vector2(0.0, -GIZMO_AXIS_LENGTH), 7.0, Color("#6bcb77"))
	draw_rect(Rect2(center - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), Color("#8fd8f8"), false, 2.0)


func _face_center_screen() -> Vector2:
	if display_polygon.is_empty():
		return Vector2.ZERO
	var center := Vector2.ZERO
	for point in display_polygon:
		center += _world_to_screen(_local_to_world(point))
	return center / float(display_polygon.size())


func _select_points_in_marquee() -> void:
	var selection_rect := Rect2(point_marquee_start, point_marquee_current - point_marquee_start).abs()
	var selected_ids: Array = []
	for point_index in range(bezier_points.size()):
		var point_position: Vector2 = bezier_points[point_index].get("position", Vector2.ZERO)
		var point_screen := _world_to_screen(_local_to_world(point_position))
		if selection_rect.has_point(point_screen):
			selected_ids.append(str(bezier_points[point_index].get("id", "")))
	_set_selected_point_ids(selected_ids)


func _select_edge_by_click(edge_id: String, additive: bool) -> void:
	var next_selection := selected_edge_ids.duplicate()
	if additive:
		if edge_id in next_selection:
			next_selection.erase(edge_id)
		else:
			next_selection.append(edge_id)
	else:
		next_selection = [edge_id]
	_set_selected_edge_ids(next_selection)


func _select_edges_in_marquee(additive: bool) -> void:
	var selection_rect := Rect2(edge_marquee_start, edge_marquee_current - edge_marquee_start).abs()
	var marquee_ids: Array = []
	var points_by_id: Dictionary = {}
	for point_data in bezier_points:
		points_by_id[str(point_data.get("id", ""))] = point_data
	for edge_data in bezier_edges:
		var start_point: Dictionary = points_by_id.get(str(edge_data.get("start_point_id", "")), {})
		var end_point: Dictionary = points_by_id.get(str(edge_data.get("end_point_id", "")), {})
		if start_point.is_empty() or end_point.is_empty():
			continue
		for screen_point in _bezier_edge_screen_points(start_point, end_point):
			if selection_rect.has_point(screen_point):
				marquee_ids.append(str(edge_data.get("id", "")))
				break
	var next_selection := selected_edge_ids.duplicate() if additive else []
	for edge_id in marquee_ids:
		if edge_id not in next_selection:
			next_selection.append(edge_id)
	_set_selected_edge_ids(next_selection)


func _draw_point_selection_marquee() -> void:
	if not point_marquee_dragging or not point_marquee_moved:
		return
	var selection_rect := Rect2(point_marquee_start, point_marquee_current - point_marquee_start).abs()
	draw_rect(selection_rect, Color("#f2c94c22"), true)
	draw_rect(selection_rect, Color("#f2c94c"), false, 1.0)


func _draw_edge_selection_marquee() -> void:
	if not edge_marquee_dragging or not edge_marquee_moved:
		return
	var selection_rect := Rect2(edge_marquee_start, edge_marquee_current - edge_marquee_start).abs()
	draw_rect(selection_rect, Color("#8fd8f822"), true)
	draw_rect(selection_rect, Color("#8fd8f8"), false, 1.0)


func _bezier_edge_screen_points(start_point: Dictionary, end_point: Dictionary) -> PackedVector2Array:
	# The component's visible control points already use component_transform.
	# Render the sampled curve through the same transform so both remain locked
	# together while translating, rotating, or scaling the component.
	return _bezier_edge_screen_points_with_transform(start_point, end_point, component_transform)


func _bezier_edge_screen_points_with_transform(start_point: Dictionary, end_point: Dictionary, transform: Dictionary) -> PackedVector2Array:
	var start_position: Vector2 = start_point.get("position", Vector2.ZERO)
	var end_position: Vector2 = end_point.get("position", Vector2.ZERO)
	var start_handle: Vector2 = start_point.get("handle_out", Vector2.ZERO)
	var end_handle: Vector2 = end_point.get("handle_in", Vector2.ZERO)
	var points := PackedVector2Array()
	var sample_count := 24
	for sample_index in range(sample_count + 1):
		var t := float(sample_index) / float(sample_count)
		var inverse_t := 1.0 - t
		var local_point := inverse_t * inverse_t * inverse_t * start_position
		local_point += 3.0 * inverse_t * inverse_t * t * (start_position + start_handle)
		local_point += 3.0 * inverse_t * t * t * (end_position + end_handle)
		local_point += t * t * t * end_position
		points.append(_world_to_screen(_local_to_world_with_transform(local_point, transform)))
	return points


func _bezier_curve_screen_points(start_point: Dictionary, end_point: Dictionary) -> PackedVector2Array:
	var start_position: Vector2 = start_point.get("position", Vector2.ZERO)
	var end_position: Vector2 = end_point.get("position", Vector2.ZERO)
	var start_handle: Vector2 = start_point.get("handle_out", Vector2.ZERO)
	var end_handle: Vector2 = end_point.get("handle_in", Vector2.ZERO)
	var points := PackedVector2Array()
	for sample_index in range(25):
		var t := float(sample_index) / 24.0
		var inverse_t := 1.0 - t
		var local_point := inverse_t * inverse_t * inverse_t * start_position
		local_point += 3.0 * inverse_t * inverse_t * t * (start_position + start_handle)
		local_point += 3.0 * inverse_t * t * t * (end_position + end_handle)
		local_point += t * t * t * end_position
		points.append(_world_to_screen(_local_to_world(local_point)))
	return points


func _draw_bezier_handle_preview(point_data: Dictionary) -> void:
	var point_position: Vector2 = point_data.get("position", Vector2.ZERO)
	var handle_in: Vector2 = point_data.get("handle_in", Vector2.ZERO)
	var handle_out: Vector2 = point_data.get("handle_out", Vector2.ZERO)
	var point_screen := _world_to_screen(_local_to_world(point_position))
	if not is_zero_approx(handle_in.length_squared()):
		var handle_in_screen := _world_to_screen(_local_to_world(point_position + handle_in))
		var handle_in_color := bezier_color_override.darkened(0.12) if bezier_color_override.a > 0.0 else Color("#c084fc")
		draw_line(point_screen, handle_in_screen, handle_in_color, 1.5)
		draw_circle(handle_in_screen, 5.0, handle_in_color, false, 1.5)
		draw_string(ThemeDB.fallback_font, handle_in_screen + Vector2(7.0, -6.0), "In", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, handle_in_color)
	if not is_zero_approx(handle_out.length_squared()):
		var handle_out_screen := _world_to_screen(_local_to_world(point_position + handle_out))
		var handle_out_color := bezier_color_override.lightened(0.2) if bezier_color_override.a > 0.0 else Color("#38bdf8")
		draw_line(point_screen, handle_out_screen, handle_out_color, 1.5)
		draw_circle(handle_out_screen, 5.0, handle_out_color, false, 1.5)
		draw_string(ThemeDB.fallback_font, handle_out_screen + Vector2(7.0, -6.0), "Out", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, handle_out_color)


func _nearest_bezier_point(screen_position: Vector2) -> int:
	var nearest_index := -1
	var nearest_distance := HANDLE_HIT_RADIUS
	for point_index in range(bezier_points.size()):
		var point_position: Vector2 = bezier_points[point_index].get("position", Vector2.ZERO)
		var distance := screen_position.distance_to(_world_to_screen(_local_to_world(point_position)))
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_index = point_index
	return nearest_index


func _bezier_handle_at(screen_position: Vector2) -> String:
	var point_data := _point_by_id(selected_point_id)
	if point_data.is_empty():
		return ""
	var point_position: Vector2 = point_data.get("position", Vector2.ZERO)
	var handle_in: Vector2 = point_data.get("handle_in", Vector2.ZERO)
	var handle_out: Vector2 = point_data.get("handle_out", Vector2.ZERO)
	if not is_zero_approx(handle_out.length_squared()):
		var handle_out_screen := _world_to_screen(_local_to_world(point_position + handle_out))
		if screen_position.distance_to(handle_out_screen) <= HANDLE_HIT_RADIUS:
			return "out"
	if not is_zero_approx(handle_in.length_squared()):
		var handle_in_screen := _world_to_screen(_local_to_world(point_position + handle_in))
		if screen_position.distance_to(handle_in_screen) <= HANDLE_HIT_RADIUS:
			return "in"
	return ""


func _draw_draw_preview() -> void:
	if interaction_state != "draw" or active_tool not in ["point", "spine"] or not cursor_over_canvas:
		return
	_draw_draw_point_preview()
	var preview_position := _world_to_screen(_local_to_world(cursor_world))
	var close_to_first := active_tool == "point" and component_draw_mode in [WorldDocumentService.DRAW_MODE_CLOSED_LOOP, WorldDocumentService.DRAW_MODE_CONTOUR] and _is_near_first_chain_point(cursor_world)
	var preview_color := Color("#76e0a5") if close_to_first else bezier_color_override.lightened(0.18) if bezier_color_override.a > 0.0 else guide_color if guide_style else Color("#f2c94c")
	draw_circle(preview_position, 5.0, preview_color, false, 2.0)
	if close_to_first:
		draw_circle(preview_position, 8.0, preview_color, false, 2.0)


func _draw_draw_point_preview() -> void:
	var anchor_id := _draw_anchor_point_id()
	if not anchor_id.is_empty():
		_draw_anchored_point_preview(anchor_id)
		return
	if active_tool == "point":
		return
	if bezier_chains.is_empty():
		return
	var chain: Dictionary = bezier_chains.back()
	if bool(chain.get("closed", false)):
		return
	var point_ids: Array = chain.get("point_ids", [])
	if point_ids.is_empty():
		return
	var preview_points: Array = bezier_points.duplicate(true)
	var preview_chain: Dictionary = chain.duplicate(true)
	var preview_point_ids: Array = preview_chain.get("point_ids", []).duplicate()
	var candidate_position := pending_draw_position if draw_pointer_down else cursor_world
	var closing_preview := active_tool == "point" and component_draw_mode in [WorldDocumentService.DRAW_MODE_CLOSED_LOOP, WorldDocumentService.DRAW_MODE_CONTOUR] and not draw_pointer_down and _is_near_first_chain_point(cursor_world)
	var preview_end_id := ""
	if closing_preview and point_ids.size() >= 3:
		preview_chain["closed"] = true
		preview_end_id = str(preview_point_ids.front())
	else:
		preview_end_id = "preview_point"
		preview_points.append({
			"id": preview_end_id,
			"position": candidate_position,
			"mode": draw_point_mode,
			"preserve_point": draw_point_mode == "corner",
			"handle_source": "auto",
			"handle_in": Vector2.ZERO,
			"handle_out": Vector2.ZERO
		})
		preview_point_ids.append(preview_end_id)
		preview_chain["point_ids"] = preview_point_ids
	BezierGeometry.resolve_chain_auto_handles(preview_points, preview_chain)
	if active_tool == "point" and draw_pointer_down and pending_draw_has_handle:
		for point_data in preview_points:
			if str(point_data.get("id", "")) != preview_end_id:
				continue
			point_data["handle_source"] = "manual"
			point_data["handle_out"] = pending_draw_handle_out
			if draw_point_mode == "mirrored":
				point_data["handle_in"] = -pending_draw_handle_out
			elif draw_point_mode == "aligned" and not is_zero_approx(pending_draw_handle_out.length_squared()):
				var automatic_in: Vector2 = point_data.get("handle_in", Vector2.ZERO)
				var incoming_length := automatic_in.length()
				if is_zero_approx(incoming_length):
					incoming_length = pending_draw_handle_out.length()
				point_data["handle_in"] = -pending_draw_handle_out.normalized() * incoming_length
			break
	var points_by_id: Dictionary = {}
	for point_data in preview_points:
		points_by_id[str(point_data.get("id", ""))] = point_data
	# Automatic handles use both neighbours. Appending a point therefore also
	# changes the incoming handle of the previous endpoint and with it the
	# already existing segment before the new one. Closing a chain additionally
	# changes the first point, so the first segment must be previewed as well.
	var affected_segments: Array = []
	if closing_preview:
		var closing_count := preview_point_ids.size()
		affected_segments.append([preview_point_ids[closing_count - 2], preview_point_ids[closing_count - 1]])
		affected_segments.append([preview_point_ids[closing_count - 1], preview_point_ids[0]])
		affected_segments.append([preview_point_ids[0], preview_point_ids[1]])
	else:
		var preview_count := preview_point_ids.size()
		if preview_count >= 3:
			affected_segments.append([preview_point_ids[preview_count - 3], preview_point_ids[preview_count - 2]])
		affected_segments.append([preview_point_ids[preview_count - 2], preview_point_ids[preview_count - 1]])
	var drawn_segments: Dictionary = {}
	for segment_data in affected_segments:
		var segment_start_id := str(segment_data[0])
		var segment_end_id := str(segment_data[1])
		var segment_key := "%s>%s" % [segment_start_id, segment_end_id]
		if drawn_segments.has(segment_key):
			continue
		drawn_segments[segment_key] = true
		if not points_by_id.has(segment_start_id) or not points_by_id.has(segment_end_id):
			continue
		_draw_dashed_polyline(
			_bezier_curve_screen_points(points_by_id[segment_start_id], points_by_id[segment_end_id]),
			Color(bezier_color_override.lightened(0.18), 0.8) if bezier_color_override.a > 0.0 else Color("#f2c94caa"),
			1.5
		)


func _draw_anchored_point_preview(anchor_id: String) -> void:
	var anchor := _point_by_id(anchor_id).duplicate(true)
	if anchor.is_empty():
		return
	var chain := BezierTopology.chain_for_point(bezier_chains, anchor_id)
	var point_ids: Array = chain.get("point_ids", [])
	if not point_ids.is_empty() and anchor_id == str(point_ids.front()):
		var old_in: Vector2 = anchor.get("handle_in", Vector2.ZERO)
		anchor["handle_in"] = anchor.get("handle_out", Vector2.ZERO)
		anchor["handle_out"] = old_in
	var target := {
		"id": "preview_point", "position": pending_draw_position if draw_pointer_down else cursor_world,
		"mode": draw_point_mode, "handle_in": Vector2.ZERO,
		"handle_out": pending_draw_handle_out if draw_pointer_down and pending_draw_has_handle else Vector2.ZERO
	}
	var preview_color := Color(bezier_color_override.lightened(0.18), 0.8) if bezier_color_override.a > 0.0 else Color("#f2c94caa")
	_draw_dashed_polyline(_bezier_curve_screen_points(anchor, target), preview_color, 1.5)


func _draw_dashed_polyline(points: PackedVector2Array, line_color: Color, line_width: float) -> void:
	if points.size() < 2:
		return
	var dash_length := 7.0
	var gap_length := 5.0
	var dash_remaining := dash_length
	var gap_remaining := 0.0
	var drawing_dash := true
	for index in range(points.size() - 1):
		var segment_start := points[index]
		var segment_end := points[index + 1]
		var segment := segment_end - segment_start
		var segment_length := segment.length()
		if segment_length <= 0.001:
			continue
		var distance := 0.0
		while distance < segment_length:
			var remaining_pattern := dash_remaining if drawing_dash else gap_remaining
			var step := minf(remaining_pattern, segment_length - distance)
			if drawing_dash:
				draw_line(segment_start + segment * (distance / segment_length), segment_start + segment * ((distance + step) / segment_length), line_color, line_width)
			distance += step
			if drawing_dash:
				dash_remaining -= step
				if dash_remaining <= 0.001:
					drawing_dash = false
					gap_remaining = gap_length
			else:
				gap_remaining -= step
				if gap_remaining <= 0.001:
					drawing_dash = true
					dash_remaining = dash_length


func _world_to_screen(world_position: Vector2) -> Vector2:
	return size * 0.5 + Vector2(world_position.x - view_center.x, -(world_position.y - view_center.y)) * zoom


func _screen_to_world(screen_position: Vector2) -> Vector2:
	var screen_offset := (screen_position - size * 0.5) / zoom
	return view_center + Vector2(screen_offset.x, -screen_offset.y)


func _snap_to_grid(world_position: Vector2) -> Vector2:
	if not snap_enabled:
		return world_position
	var package_level := _active_grid_package_level()
	# Fine mode is one raster level below the active coarse package. Without
	# this correction a zoomed-out view could multiply the fine step back to
	# the coarse step while the UI still reported Fine.
	if grid_step < world_grid_size:
		package_level = maxi(package_level - 1, 0)
	var snap_step := maxf(grid_step, 0.0001) * pow(5.0, package_level)
	return Vector2(
		round(world_position.x / snap_step) * snap_step,
		round(world_position.y / snap_step) * snap_step
	)


func _snap_to_canvas_position(local_position: Vector2) -> Vector2:
	# Reference-point snapping is independent from the grid toggle. This lets
	# No Snap remain a true no-grid mode while still aligning the active
	# Component to authored points visible in the background.
	var reference_snap := _nearest_reference_point(local_position)
	if bool(reference_snap.get("found", false)):
		return reference_snap.get("position", local_position)
	return _snap_to_grid(_snap_to_catch_parent(local_position))


## The Asset Pivot is placed in World space over the whole Asset, so it takes its
## targets from the reference shapes rather than from one Component: the authored
## Points of everything visible, and for a Primitive its centre instead of the
## rim samples its outline is made of. Same pick radius and same grid fallback as
## the Component Pivot, so both behave alike.
func _snap_asset_pivot_position(world_position: Vector2) -> Vector2:
	var cursor_screen := _world_to_screen(world_position)
	var best_position := world_position
	var best_distance := HANDLE_HIT_RADIUS
	var found := false
	for shape in reference_shapes:
		if not bool(shape.get("visibility", true)):
			continue
		var shape_transform: Dictionary = shape.get("transform", {})
		for candidate in _asset_pivot_candidates(shape):
			var candidate_world := _local_to_world_with_transform(candidate, shape_transform)
			var candidate_distance := cursor_screen.distance_to(_world_to_screen(candidate_world))
			if candidate_distance <= best_distance:
				best_distance = candidate_distance
				best_position = candidate_world
				found = true
	return best_position if found else _snap_to_grid(world_position)


func _asset_pivot_candidates(shape: Dictionary) -> Array[Vector2]:
	var candidates: Array[Vector2] = []
	if bool(shape.get("primitive", false)):
		var contour: Array = shape.get("points", [])
		var centroid := Vector2.ZERO
		var contour_size := 0
		for point in contour:
			if point is Vector2:
				centroid += point
				contour_size += 1
		if contour_size > 0:
			candidates.append(centroid / float(contour_size))
		return candidates
	for point in shape.get("bezier_points", []):
		if point is Dictionary:
			candidates.append(Vector2(point.get("position", Vector2.ZERO)))
	return candidates


func _snap_pivot_position(local_position: Vector2) -> Vector2:
	# The selected Component is omitted from reference_shapes, but its authored
	# points are still the most useful targets while positioning its Pivot.
	var cursor_screen := _world_to_screen(_local_to_world(local_position))
	var best_position := local_position
	var best_distance := HANDLE_HIT_RADIUS
	var found := false
	# A Primitive owns no authored Points, so without this its own centre - the
	# one place a Pivot usually belongs - would be the only target on screen the
	# Pivot could not reach.
	if not display_polygon.is_empty():
		var primitive_center := _primitive_center()
		var primitive_distance := cursor_screen.distance_to(_world_to_screen(_local_to_world(primitive_center)))
		if primitive_distance <= best_distance:
			best_distance = primitive_distance
			best_position = primitive_center
			found = true
	for point in bezier_points:
		var point_position: Vector2 = point.get("position", Vector2.ZERO)
		var point_distance := cursor_screen.distance_to(_world_to_screen(_local_to_world(point_position)))
		if point_distance <= best_distance:
			best_distance = point_distance
			best_position = point_position
			found = true
	var reference_snap := _nearest_reference_point(local_position)
	if bool(reference_snap.get("found", false)):
		var reference_position: Vector2 = reference_snap.get("position", local_position)
		var reference_distance := cursor_screen.distance_to(_world_to_screen(_local_to_world(reference_position)))
		if not found or reference_distance <= best_distance:
			return reference_position
	if found:
		return best_position
	return _snap_to_grid(local_position)


func _nearest_reference_point(local_position: Vector2) -> Dictionary:
	var cursor_screen := _world_to_screen(_local_to_world(local_position))
	var best_screen := Vector2.ZERO
	var best_distance := HANDLE_HIT_RADIUS
	var found := false
	for shape in reference_shapes:
		if not bool(shape.get("visibility", true)):
			continue
		var transform: Dictionary = shape.get("transform", {})
		var points: Array = shape.get("bezier_points", [])
		# Referenced assets expose their transformed authored points through the
		# same field; the fallback keeps older/reference shapes usable too.
		if points.is_empty():
			points = shape.get("points", [])
		for point in points:
			var point_position := Vector2.ZERO
			if point is Dictionary:
				point_position = point.get("position", Vector2.ZERO)
			elif point is Vector2:
				point_position = point
			else:
				continue
			var point_screen := _world_to_screen(_local_to_world_with_transform(point_position, transform))
			var point_distance := cursor_screen.distance_to(point_screen)
			if point_distance <= best_distance:
				best_distance = point_distance
				best_screen = point_screen
				found = true
		if found and best_distance <= 0.001:
			break
	if not found:
		return {"found": false}
	return {"found": true, "position": _world_to_local(_screen_to_world(best_screen))}


func _snap_to_catch_parent(local_position: Vector2) -> Vector2:
	if catch_parent_component_id.is_empty():
		return local_position
	var cursor_screen := _world_to_screen(_local_to_world(local_position))
	var best_screen := Vector2.ZERO
	var best_distance := HANDLE_HIT_RADIUS
	for shape in reference_shapes:
		if str(shape.get("id", "")) != catch_parent_component_id:
			continue
		var transform: Dictionary = shape.get("transform", {})
		var points: Array = shape.get("bezier_points", [])
		var points_by_id: Dictionary = {}
		for point in points:
			points_by_id[str(point.get("id", ""))] = point
			var point_screen := _world_to_screen(_local_to_world_with_transform(point.get("position", Vector2.ZERO), transform))
			var point_distance := cursor_screen.distance_to(point_screen)
			if point_distance <= best_distance:
				best_distance = point_distance
				best_screen = point_screen
		for edge in shape.get("edges", []):
			var start_id := str(edge.get("start_point_id", ""))
			var end_id := str(edge.get("end_point_id", ""))
			if not points_by_id.has(start_id) or not points_by_id.has(end_id):
				continue
			var curve := _bezier_edge_screen_points_with_transform(points_by_id[start_id], points_by_id[end_id], transform)
			for index in range(curve.size() - 1):
				var closest := Geometry2D.get_closest_point_to_segment(cursor_screen, curve[index], curve[index + 1])
				var distance := cursor_screen.distance_to(closest)
				if distance <= best_distance:
					best_distance = distance
					best_screen = closest
	if best_distance < HANDLE_HIT_RADIUS:
		return _world_to_local(_screen_to_world(best_screen))
	return local_position


func _is_near_first_chain_point(local_position: Vector2) -> bool:
	if bezier_chains.is_empty():
		return false
	var chain: Dictionary = bezier_chains.back()
	if bool(chain.get("closed", false)):
		return false
	var point_ids: Array = chain.get("point_ids", [])
	if point_ids.size() < 3:
		return false
	var first_id := str(point_ids[0])
	for point_data in bezier_points:
		if str(point_data.get("id", "")) == first_id:
			var first_position: Vector2 = point_data.get("position", Vector2.ZERO)
			return _world_to_screen(_local_to_world(local_position)).distance_to(_world_to_screen(_local_to_world(first_position))) <= CLOSE_DISTANCE_PIXELS
	return false


func _draw_anchor_point_id() -> String:
	if selected_point_ids.size() != 1:
		return ""
	var point_id := str(selected_point_ids[0])
	var component := {"points": bezier_points, "edges": bezier_edges, "chains": bezier_chains}
	return point_id if BezierTopology.is_open_endpoint(component, point_id) else ""


func _draw_connection_target_id(screen_position: Vector2) -> String:
	var anchor_id := _draw_anchor_point_id()
	if anchor_id.is_empty():
		return ""
	var nearest_index := _nearest_bezier_point(screen_position)
	if nearest_index < 0:
		return ""
	var target_id := str(bezier_points[nearest_index].get("id", ""))
	var component := {"points": bezier_points, "edges": bezier_edges, "chains": bezier_chains}
	return target_id if target_id == anchor_id or BezierTopology.is_open_endpoint(component, target_id) else ""


func _open_endpoint_at(screen_position: Vector2) -> String:
	var nearest_index := _nearest_bezier_point(screen_position)
	if nearest_index < 0:
		return ""
	var point_id := str(bezier_points[nearest_index].get("id", ""))
	var component := {"points": bezier_points, "edges": bezier_edges, "chains": bezier_chains}
	return point_id if BezierTopology.is_open_endpoint(component, point_id) else ""


func _selected_point_ids() -> Array:
	return selected_point_ids.duplicate()


func _all_bezier_point_ids() -> Array:
	var point_ids: Array = []
	for point_data in bezier_points:
		point_ids.append(str(point_data.get("id", "")))
	return point_ids


func _point_index_by_id(point_id: String) -> int:
	for point_index in range(bezier_points.size()):
		if str(bezier_points[point_index].get("id", "")) == point_id:
			return point_index
	return -1


func _point_by_id(point_id: String) -> Dictionary:
	var point_index := _point_index_by_id(point_id)
	return bezier_points[point_index] if point_index >= 0 else {}


func _edge_by_id(edge_id: String) -> Dictionary:
	for edge_data in bezier_edges:
		if str(edge_data.get("id", "")) == edge_id:
			return edge_data
	return {}


func _nearest_bezier_edge(screen_position: Vector2) -> String:
	return str(_bezier_edge_hit(screen_position).get("id", ""))


func _bezier_edge_hit(screen_position: Vector2) -> Dictionary:
	var points_by_id: Dictionary = {}
	for point_data in bezier_points:
		points_by_id[str(point_data.get("id", ""))] = point_data
	var result := {}
	var nearest_distance := 14.0
	for edge_data in bezier_edges:
		var start_id := str(edge_data.get("start_point_id", ""))
		var end_id := str(edge_data.get("end_point_id", ""))
		if not points_by_id.has(start_id) or not points_by_id.has(end_id):
			continue
		var curve_points := _bezier_edge_screen_points(points_by_id[start_id], points_by_id[end_id])
		for index in range(curve_points.size() - 1):
			var closest := Geometry2D.get_closest_point_to_segment(screen_position, curve_points[index], curve_points[index + 1])
			var distance := screen_position.distance_to(closest)
			if distance < nearest_distance:
				nearest_distance = distance
				var segment := curve_points[index + 1] - curve_points[index]
				var factor := clampf((screen_position - curve_points[index]).dot(segment) / maxf(segment.length_squared(), 0.000001), 0.0, 1.0)
				result = {
					"id": str(edge_data.get("id", "")),
					"t": (float(index) + factor) / float(curve_points.size() - 1)
				}
	return result
