class_name MotionPathWorkspace
extends Control

signal point_add_requested(position: Vector2)
signal point_move_started()
signal point_move_requested(point_id: String, position: Vector2)
signal handle_move_requested(point_id: String, side: String, value: Vector2)
signal point_delete_requested(point_id: String)

const ZOOM := 32.0
const POINT_RADIUS := 7.0
const HANDLE_RADIUS := 6.0

var path_document: Dictionary = {}
var preview_asset: Dictionary = {}
var tool_mode := "draw"
var phase := 0.0
var playing := false
var selected_point_id := ""
var dragging_point := false
var dragging_handle_side := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	queue_redraw()


func set_document(value: Dictionary) -> void:
	path_document = value.duplicate(true)
	if MotionPathTopology.point_by_id(_points(), selected_point_id).is_empty():
		selected_point_id = ""
	queue_redraw()


func set_preview_asset(value: Dictionary) -> void:
	preview_asset = value.duplicate(true)
	queue_redraw()


func set_tool_mode(value: String) -> void:
	tool_mode = value if value in ["draw", "edit"] else "draw"
	queue_redraw()


func set_runtime(value_phase: float, value_playing: bool) -> void:
	phase = clampf(value_phase, 0.0, 1.0)
	playing = value_playing
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			if path_document.is_empty():
				return
			if tool_mode == "draw":
				point_add_requested.emit(_screen_to_world(event.position))
				return
			var handle_hit := _handle_at(event.position)
			if not handle_hit.is_empty():
				dragging_handle_side = handle_hit
				point_move_started.emit()
				return
			var point_hit := _point_at(event.position)
			selected_point_id = point_hit
			if not point_hit.is_empty():
				dragging_point = true
				point_move_started.emit()
			queue_redraw()
		else:
			dragging_point = false
			dragging_handle_side = ""
		return
	if event is InputEventMouseMotion:
		if dragging_point and not selected_point_id.is_empty():
			point_move_requested.emit(selected_point_id, _screen_to_world(event.position))
		elif not dragging_handle_side.is_empty() and not selected_point_id.is_empty():
			var point := MotionPathTopology.point_by_id(_points(), selected_point_id)
			if not point.is_empty():
				handle_move_requested.emit(selected_point_id, dragging_handle_side, _screen_to_world(event.position) - Vector2(point.get("position", Vector2.ZERO)))
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_BACKSPACE, KEY_DELETE] and not selected_point_id.is_empty():
		point_delete_requested.emit(selected_point_id)
		selected_point_id = ""
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#171b22"), true)
	_draw_grid()
	var title := str(path_document.get("name", "Motion → Path"))
	draw_string(ThemeDB.fallback_font, Vector2(18.0, 28.0), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 36.0, 15, Color("#d6dbe4"))
	if path_document.is_empty():
		_draw_centered_text("Select or create a Path.")
		draw_rect(Rect2(Vector2.ZERO, size), Color("#3a424f"), false, 1.0)
		return
	_draw_path()
	_draw_preview_asset()
	var footer := "%s · %.2f · %s" % ["Draw Path" if tool_mode == "draw" else "Edit Path", phase, "Playing" if playing else "Paused"]
	draw_string(ThemeDB.fallback_font, Vector2(9.0, size.y - 9.0), footer, HORIZONTAL_ALIGNMENT_LEFT, size.x - 18.0, 11, Color("#9aa3b2"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#3a424f"), false, 1.0)


func _draw_grid() -> void:
	var origin := _origin()
	var spacing := ZOOM
	var x := fmod(origin.x, spacing)
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color("#252b35"), 1.0)
		x += spacing
	var y := fmod(origin.y, spacing)
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color("#252b35"), 1.0)
		y += spacing
	draw_line(Vector2(origin.x, 0.0), Vector2(origin.x, size.y), Color("#3b4656"), 1.0)
	draw_line(Vector2(0.0, origin.y), Vector2(size.x, origin.y), Color("#3b4656"), 1.0)


func _draw_path() -> void:
	var points := _points()
	var points_by_id: Dictionary = {}
	for point in points:
		points_by_id[str(point.get("id", ""))] = point
	for segment in _topology().get("segments", []):
		var start: Dictionary = points_by_id.get(str(segment.get("start_point_id", "")), {})
		var end: Dictionary = points_by_id.get(str(segment.get("end_point_id", "")), {})
		if start.is_empty() or end.is_empty():
			continue
		var curve := PackedVector2Array()
		for sample_index in range(33):
			curve.append(_world_to_screen(MotionPathSampler.cubic_point(start, end, float(sample_index) / 32.0)))
		draw_polyline(curve, Color("#f2c94c"), 2.0, true)
	for point in points:
		var point_id := str(point.get("id", ""))
		var screen_position := _world_to_screen(point.get("position", Vector2.ZERO))
		draw_circle(screen_position, POINT_RADIUS, Color("#f2c94c") if point_id == selected_point_id else Color("#d6dbe4"))
		draw_circle(screen_position, POINT_RADIUS, Color("#171b22"), false, 1.0)
	if tool_mode == "edit":
		_draw_selected_handles()


func _draw_selected_handles() -> void:
	var point := MotionPathTopology.point_by_id(_points(), selected_point_id)
	if point.is_empty():
		return
	var position: Vector2 = point.get("position", Vector2.ZERO)
	for side in ["in", "out"]:
		var handle := _display_handle(point, side)
		var point_screen := _world_to_screen(position)
		var handle_screen := _world_to_screen(position + handle)
		draw_line(point_screen, handle_screen, Color("#7c8ba1"), 1.0)
		draw_circle(handle_screen, HANDLE_RADIUS, Color("#75b88a"))


func _draw_preview_asset() -> void:
	if preview_asset.is_empty() or _points().size() < 2:
		return
	var path_sample := MotionPathSampler.sample(_topology(), phase)
	if not bool(path_sample.get("valid", false)):
		return
	var paths := _asset_paths()
	if paths.is_empty():
		return
	var asset_center := _paths_bounds(paths).get_center()
	var rotation := deg_to_rad(float(path_sample.get("rotation", 0.0))) if bool(path_document.get("playback", {}).get("orient_along_path", false)) else 0.0
	var path_position: Vector2 = path_sample.get("position", Vector2.ZERO)
	for path_data in paths:
		var screen_points := PackedVector2Array()
		for asset_point in path_data.get("points", []):
			var placed := path_position + (Vector2(asset_point) - asset_center).rotated(rotation)
			screen_points.append(_world_to_screen(placed))
		if bool(path_data.get("closed", false)) and screen_points.size() >= 3:
			draw_colored_polygon(screen_points, Color("#6f87aa44"))
		if screen_points.size() >= 2:
			draw_polyline(screen_points, Color("#b9c7dc"), 1.5, true)


func _asset_paths() -> Array:
	var paths: Array = []
	for component in preview_asset.get("components", []):
		if not bool(component.get("visibility", true)):
			continue
		var points: Array = component.get("points", []).duplicate(true)
		var chains: Array = component.get("chains", []).duplicate(true)
		BezierGeometry.resolve_auto_handles(points, chains)
		var points_by_id: Dictionary = {}
		for point in points:
			points_by_id[str(point.get("id", ""))] = point
		for chain in chains:
			var sampled := _sample_asset_chain(points_by_id, chain, component.get("transform", {}))
			if not sampled.is_empty():
				paths.append({"points": sampled, "closed": bool(chain.get("closed", false))})
	return paths


func _sample_asset_chain(points_by_id: Dictionary, chain: Dictionary, transform: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	var point_ids: Array = chain.get("point_ids", [])
	if point_ids.size() < 2:
		return result
	var segment_count := point_ids.size() if bool(chain.get("closed", false)) else point_ids.size() - 1
	for segment_index in range(segment_count):
		var start: Dictionary = points_by_id.get(str(point_ids[segment_index]), {})
		var end: Dictionary = points_by_id.get(str(point_ids[(segment_index + 1) % point_ids.size()]), {})
		for sample_index in range(17):
			if segment_index > 0 and sample_index == 0:
				continue
			var local_point := MotionPathSampler.cubic_point(start, end, float(sample_index) / 16.0)
			var pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
			var scale: Vector2 = transform.get("scale", Vector2.ONE)
			var rotation := deg_to_rad(float(transform.get("rotation", 0.0)))
			result.append(Vector2(transform.get("position", Vector2.ZERO)) + ((local_point - pivot) * scale).rotated(rotation))
	return result


func _paths_bounds(paths: Array) -> Rect2:
	var initialized := false
	var minimum := Vector2.ZERO
	var maximum := Vector2.ZERO
	for path_data in paths:
		for raw_point in path_data.get("points", []):
			var point := Vector2(raw_point)
			if not initialized:
				minimum = point
				maximum = point
				initialized = true
			else:
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func _topology() -> Dictionary:
	return path_document.get("topology", {})


func _points() -> Array:
	return _topology().get("points", [])


func _origin() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.5)


func _world_to_screen(value: Vector2) -> Vector2:
	return _origin() + Vector2(value.x, -value.y) * ZOOM


func _screen_to_world(value: Vector2) -> Vector2:
	var offset := (value - _origin()) / ZOOM
	return Vector2(offset.x, -offset.y)


func _point_at(screen_position: Vector2) -> String:
	var nearest_id := ""
	var nearest_distance := POINT_RADIUS * 1.8
	for point in _points():
		var distance := _world_to_screen(point.get("position", Vector2.ZERO)).distance_to(screen_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_id = str(point.get("id", ""))
	return nearest_id


func _handle_at(screen_position: Vector2) -> String:
	var point := MotionPathTopology.point_by_id(_points(), selected_point_id)
	if point.is_empty():
		return ""
	var position: Vector2 = point.get("position", Vector2.ZERO)
	for side in ["in", "out"]:
		var handle_position := position + _display_handle(point, side)
		if _world_to_screen(handle_position).distance_to(screen_position) <= HANDLE_RADIUS * 1.8:
			return side
	return ""


func _display_handle(point: Dictionary, side: String) -> Vector2:
	var stored: Vector2 = point.get("handle_%s" % side, Vector2.ZERO)
	if stored.length_squared() > 0.000001:
		return stored
	var points := _points()
	var point_index := -1
	for index in range(points.size()):
		if str(points[index].get("id", "")) == str(point.get("id", "")):
			point_index = index
			break
	if point_index < 0:
		return Vector2.LEFT if side == "in" else Vector2.RIGHT
	var position: Vector2 = point.get("position", Vector2.ZERO)
	if side == "in":
		if point_index > 0:
			return (Vector2(points[point_index - 1].get("position", position)) - position) / 3.0
		if point_index + 1 < points.size():
			return -(Vector2(points[point_index + 1].get("position", position)) - position) / 3.0
	else:
		if point_index + 1 < points.size():
			return (Vector2(points[point_index + 1].get("position", position)) - position) / 3.0
		if point_index > 0:
			return -(Vector2(points[point_index - 1].get("position", position)) - position) / 3.0
	return Vector2.LEFT if side == "in" else Vector2.RIGHT


func _draw_centered_text(text: String) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(0.0, size.y * 0.5), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color("#737f91"))
