class_name MotionAssetPreview
extends Control

var asset: Dictionary = {}
var state_name := "None"
var phase := 0.0
var playing := false
var component_samples: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(250, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_asset(value: Dictionary) -> void:
	asset = value.duplicate(true)
	queue_redraw()


func set_runtime(value_state_name: String, value_phase: float, value_playing: bool) -> void:
	state_name = value_state_name
	phase = clampf(value_phase, 0.0, 1.0)
	playing = value_playing
	queue_redraw()


func set_component_samples(value: Dictionary) -> void:
	component_samples = value.duplicate(true)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#171b22"), true)
	_draw_grid()
	var paths := _asset_paths()
	if paths.is_empty():
		_draw_centered_text("No Component contours")
	else:
		var bounds := _paths_bounds(paths)
		var padding := 18.0
		var available := Vector2(maxf(1.0, size.x - padding * 2.0), maxf(1.0, size.y - padding * 2.0 - 22.0))
		var extent := bounds.size
		if extent.x <= 0.0001:
			extent.x = 1.0
		if extent.y <= 0.0001:
			extent.y = 1.0
		var fit_scale := minf(available.x / extent.x, available.y / extent.y)
		var target_center := Vector2(size.x * 0.5, (size.y - 22.0) * 0.5)
		for path_data in paths:
			var screen_points := PackedVector2Array()
			var component_id := str(path_data.get("component_id", ""))
			var sample: Dictionary = component_samples.get(component_id, MotionSampler.identity_transform())
			var component_origin: Vector2 = path_data.get("component_origin", Vector2.ZERO)
			for world_point in path_data.get("points", []):
				var preview_point := _apply_preview_transform(Vector2(world_point), component_origin, sample)
				screen_points.append(target_center + _world_offset_to_preview(preview_point - bounds.get_center(), fit_scale))
			if bool(path_data.get("closed", false)) and screen_points.size() >= 3:
				draw_colored_polygon(screen_points, Color("#6f87aa33"))
			if screen_points.size() >= 2:
				draw_polyline(screen_points, Color("#b9c7dc"), 1.5, true)
	var footer := "%s · %.2f · %s" % [state_name, phase, "Playing" if playing else "Paused"]
	draw_string(ThemeDB.fallback_font, Vector2(9.0, size.y - 7.0), footer, HORIZONTAL_ALIGNMENT_LEFT, size.x - 18.0, 10, Color("#9aa3b2"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#3a424f"), false, 1.0)


static func _world_offset_to_preview(world_offset: Vector2, fit_scale: float) -> Vector2:
	# AssetFlow's canvas uses Y-up world coordinates while Control drawing uses
	# Y-down screen coordinates. Match ComponentCanvas without touching data.
	return Vector2(world_offset.x, -world_offset.y) * fit_scale


static func _apply_preview_transform(world_point: Vector2, origin: Vector2, sample: Dictionary) -> Vector2:
	var position: Vector2 = sample.get("position", Vector2.ZERO)
	var rotation := deg_to_rad(float(sample.get("rotation", 0.0)))
	var scale: Vector2 = sample.get("scale", Vector2.ONE)
	return origin + ((world_point - origin) * scale).rotated(rotation) + position


func _draw_grid() -> void:
	var spacing := 20.0
	var grid_color := Color("#252b35")
	var x := spacing
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), grid_color, 1.0)
		x += spacing
	var y := spacing
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), grid_color, 1.0)
		y += spacing


func _draw_centered_text(text: String) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(0.0, size.y * 0.5), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color("#737f91"))


func _asset_paths() -> Array:
	var paths: Array = []
	for component in asset.get("components", []):
		if not bool(component.get("visibility", true)):
			continue
		var points: Array = component.get("points", []).duplicate(true)
		var chains: Array = component.get("chains", []).duplicate(true)
		BezierGeometry.resolve_auto_handles(points, chains)
		var points_by_id := {}
		for point in points:
			points_by_id[str(point.get("id", ""))] = point
		for chain in chains:
			var path := _sample_chain(points_by_id, chain, component.get("transform", {}))
			if not path.is_empty():
				paths.append({
					"points": path,
					"closed": bool(chain.get("closed", false)),
					"component_id": str(component.get("id", "")),
					"component_origin": Vector2(component.get("transform", {}).get("position", Vector2.ZERO))
				})
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
		if start.is_empty() or end.is_empty():
			continue
		for sample_index in range(17):
			if segment_index > 0 and sample_index == 0:
				continue
			var t := float(sample_index) / 16.0
			result.append(_component_to_world(_cubic_point(start, end, t), transform))
	return result


func _cubic_point(start: Dictionary, end: Dictionary, t: float) -> Vector2:
	var p0: Vector2 = start.get("position", Vector2.ZERO)
	var p1 := p0 + Vector2(start.get("handle_out", Vector2.ZERO))
	var p3: Vector2 = end.get("position", Vector2.ZERO)
	var p2 := p3 + Vector2(end.get("handle_in", Vector2.ZERO))
	var inverse_t := 1.0 - t
	return inverse_t * inverse_t * inverse_t * p0 + 3.0 * inverse_t * inverse_t * t * p1 + 3.0 * inverse_t * t * t * p2 + t * t * t * p3


func _component_to_world(local_point: Vector2, transform: Dictionary) -> Vector2:
	var pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
	var position: Vector2 = transform.get("position", Vector2.ZERO)
	var scale: Vector2 = transform.get("scale", Vector2.ONE)
	var rotation := deg_to_rad(float(transform.get("rotation", 0.0)))
	return position + ((local_point - pivot) * scale).rotated(rotation)


func _paths_bounds(paths: Array) -> Rect2:
	var initialized := false
	var minimum := Vector2.ZERO
	var maximum := Vector2.ZERO
	for path_data in paths:
		for point in path_data.get("points", []):
			var value := Vector2(point)
			if not initialized:
				minimum = value
				maximum = value
				initialized = true
			else:
				minimum.x = minf(minimum.x, value.x)
				minimum.y = minf(minimum.y, value.y)
				maximum.x = maxf(maximum.x, value.x)
				maximum.y = maxf(maximum.y, value.y)
	return Rect2(minimum, maximum - minimum)
