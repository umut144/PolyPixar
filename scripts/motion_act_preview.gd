class_name MotionActPreview
extends Control

var act: Dictionary = {}
var preview_asset: Dictionary = {}
var phase := 0.0
var playing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_context(act_value: Dictionary, asset_value: Dictionary) -> void:
	act = act_value.duplicate(true)
	preview_asset = asset_value.duplicate(true)
	queue_redraw()


func set_runtime(value_phase: float, value_playing: bool) -> void:
	phase = clampf(value_phase, 0.0, 1.0)
	playing = value_playing
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#171b22"), true)
	_draw_grid()
	if act.is_empty():
		_draw_centered_text("Select or create an Act.")
		_draw_frame()
		return
	if preview_asset.is_empty():
		_draw_centered_text("Select a Preview Asset in the Outliner.")
		_draw_frame()
		return
	var current_sample := MotionActEvaluator.sample(act, phase)
	if not bool(current_sample.get("valid", false)):
		var issues: Array = current_sample.get("issues", [])
		_draw_centered_text(str(issues[0]) if not issues.is_empty() else "Act is not ready for Preview.")
		_draw_frame()
		return
	var paths := _asset_paths()
	if paths.is_empty():
		_draw_centered_text("The Preview Asset has no visible contours.")
		_draw_frame()
		return
	var rest_bounds := _paths_bounds(paths)
	var current_transform: Dictionary = current_sample.get("transform", {})
	var current_offset: Vector2 = current_transform.get("position", Vector2.ZERO)
	var current_scale: Vector2 = current_transform.get("scale", Vector2.ONE)
	var trajectory := _trajectory_offsets()
	var combined_bounds := rest_bounds
	for offset in trajectory:
		combined_bounds = combined_bounds.merge(Rect2(rest_bounds.position + Vector2(offset), rest_bounds.size))
	combined_bounds = combined_bounds.grow(1.0)
	var drawing_rect := Rect2(26.0, 48.0, maxf(1.0, size.x - 52.0), maxf(1.0, size.y - 86.0))
	var fit_scale := minf(drawing_rect.size.x / maxf(combined_bounds.size.x, 1.0), drawing_rect.size.y / maxf(combined_bounds.size.y, 1.0))
	var target_center := drawing_rect.get_center()
	var rest_center := rest_bounds.get_center()
	_draw_motion_path(rest_center, trajectory, combined_bounds, target_center, fit_scale)
	_draw_asset_paths(paths, Vector2.ZERO, Vector2.ONE, rest_center, combined_bounds, target_center, fit_scale, Color("#7f8a9b33"), Color("#9aa3b255"), 1.0)
	_draw_asset_paths(paths, Vector2(trajectory.back()) if not trajectory.is_empty() else Vector2.ZERO, Vector2.ONE, rest_center, combined_bounds, target_center, fit_scale, Color("#7f8a9b22"), Color("#9aa3b244"), 1.0)
	_draw_asset_paths(paths, current_offset, current_scale, rest_center, combined_bounds, target_center, fit_scale, Color("#6f87aa55"), Color("#c8d5e8"), 1.8)
	var footer := "%s · %.2f · %s" % [str(act.get("name", MotionActEvaluator.primitive_label(str(act.get("primitive", MotionActEvaluator.SLIDE))))), phase, "Playing" if playing else "Paused"]
	draw_string(ThemeDB.fallback_font, Vector2(10.0, size.y - 9.0), footer, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20.0, 11, Color("#9aa3b2"))
	_draw_frame()


func _trajectory_offsets() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for sample_index in range(33):
		var sample := MotionActEvaluator.sample(act, float(sample_index) / 32.0)
		if bool(sample.get("valid", false)):
			result.append(Vector2(sample.get("transform", {}).get("position", Vector2.ZERO)))
	return result


func _draw_motion_path(rest_center: Vector2, offsets: Array[Vector2], bounds: Rect2, target_center: Vector2, fit_scale: float) -> void:
	if offsets.is_empty():
		return
	var screen_points := PackedVector2Array()
	for offset in offsets:
		screen_points.append(target_center + _world_offset(rest_center + offset - bounds.get_center(), fit_scale))
	if screen_points.size() >= 2:
		draw_polyline(screen_points, Color("#f2c94c88"), 2.0, true)
	draw_circle(screen_points[0], 4.0, Color("#f2c94c88"))
	draw_circle(screen_points[screen_points.size() - 1], 4.0, Color("#f2c94c"))


func _draw_asset_paths(paths: Array, offset: Vector2, sample_scale: Vector2, scale_pivot: Vector2, bounds: Rect2, target_center: Vector2, fit_scale: float, fill_color: Color, line_color: Color, width: float) -> void:
	for path_data in paths:
		var screen_points := PackedVector2Array()
		for raw_point in path_data.get("points", []):
			var transformed_point := apply_sample_transform(Vector2(raw_point), scale_pivot, {"position": offset, "scale": sample_scale})
			screen_points.append(target_center + _world_offset(transformed_point - bounds.get_center(), fit_scale))
		if bool(path_data.get("closed", false)) and screen_points.size() >= 3:
			draw_colored_polygon(screen_points, fill_color)
		if screen_points.size() >= 2:
			draw_polyline(screen_points, line_color, width, true)


static func apply_sample_transform(point: Vector2, scale_pivot: Vector2, transform: Dictionary) -> Vector2:
	var sample_scale: Vector2 = transform.get("scale", Vector2.ONE)
	var sample_position: Vector2 = transform.get("position", Vector2.ZERO)
	return scale_pivot + (point - scale_pivot) * sample_scale + sample_position


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
			var sampled := _sample_chain(points_by_id, chain, component.get("transform", {}))
			if not sampled.is_empty():
				paths.append({"points": sampled, "closed": bool(chain.get("closed", false))})
	return paths


func _sample_chain(points_by_id: Dictionary, chain: Dictionary, transform: Dictionary) -> PackedVector2Array:
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
			var value := Vector2(raw_point)
			if not initialized:
				minimum = value
				maximum = value
				initialized = true
			else:
				minimum = minimum.min(value)
				maximum = maximum.max(value)
	return Rect2(minimum, maximum - minimum)


func _draw_grid() -> void:
	var spacing := 24.0
	var x := spacing
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color("#252b35"), 1.0)
		x += spacing
	var y := spacing
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color("#252b35"), 1.0)
		y += spacing


func _world_offset(value: Vector2, scale: float) -> Vector2:
	return Vector2(value.x, -value.y) * scale


func _draw_centered_text(text: String) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(0.0, size.y * 0.5), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color("#737f91"))


func _draw_frame() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#3a424f"), false, 1.0)
