class_name OutlineResolutionService
extends RefCounted

## Resolves automatic outline ownership for exact shared edges inside Groups.
## The result is derived and never written back into authored topology.

const SAMPLE_COUNT := 17
const POSITION_EPSILON := 0.0005
const BOUNDS_EPSILON := 0.001


static func resolve_group(asset: Dictionary, group_id: String) -> Dictionary:
	var result: Dictionary = {}
	var members: Array[Dictionary] = []
	for component in asset.get("components", []):
		if not component is Dictionary or ComponentHierarchy.membership_group_id(asset, str(component.get("id", ""))) != group_id:
			continue
		members.append(component)
	members.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("id", "")).naturalnocasecmp_to(str(right.get("id", ""))) < 0
	)
	var edge_records: Array[Dictionary] = []
	for component in members:
		var component_id := str(component.get("id", ""))
		var world_transform := ComponentHierarchy.world_transform(asset, component_id)
		var points_by_id: Dictionary = {}
		for point in component.get("points", []):
			if point is Dictionary:
				points_by_id[str(point.get("id", ""))] = point
		for edge in component.get("edges", []):
			if not edge is Dictionary:
				continue
			var start: Dictionary = points_by_id.get(str(edge.get("start_point_id", "")), {})
			var end: Dictionary = points_by_id.get(str(edge.get("end_point_id", "")), {})
			if start.is_empty() or end.is_empty():
				continue
			var samples := _edge_samples(start, end, world_transform)
			edge_records.append({
				"component_id": component_id,
				"edge_id": str(edge.get("id", "")),
				"edge": edge,
				"samples": samples,
				"center": _sample_center(samples)
			})
			result[component_id] = result.get(component_id, {})
			var edge_mode := OutlineService.normalize_mode(edge.get("render_outline", OutlineService.AUTO))
			result[component_id][str(edge.get("id", ""))] = {
				"enabled": edge_mode != OutlineService.OFF,
				"diagnostic": "hidden" if edge_mode == OutlineService.OFF else "visible"
			}
	for first_index in range(edge_records.size()):
		var first: Dictionary = edge_records[first_index]
		for second_index in range(first_index + 1, edge_records.size()):
			var second: Dictionary = edge_records[second_index]
			if first.get("component_id", "") == second.get("component_id", "") or not _edges_overlap(first, second):
				continue
			_resolve_pair(result, first, second)
	return result


static func _resolve_pair(result: Dictionary, first: Dictionary, second: Dictionary) -> void:
	var first_edge: Dictionary = first.get("edge", {})
	var second_edge: Dictionary = second.get("edge", {})
	var first_mode := OutlineService.normalize_mode(first_edge.get("render_outline", OutlineService.AUTO))
	var second_mode := OutlineService.normalize_mode(second_edge.get("render_outline", OutlineService.AUTO))
	if first_mode == OutlineService.OFF and second_mode == OutlineService.OFF:
		_set_result(result, first, false, "hidden")
		_set_result(result, second, false, "hidden")
		return
	if first_mode == OutlineService.ON and second_mode != OutlineService.ON:
		_set_result(result, first, true, "visible")
		_set_result(result, second, false, "covered")
		return
	if second_mode == OutlineService.ON and first_mode != OutlineService.ON:
		_set_result(result, first, false, "covered")
		_set_result(result, second, true, "visible")
		return
	if first_mode != OutlineService.AUTO or second_mode != OutlineService.AUTO:
		return
	var first_center: Vector2 = first.get("center", Vector2.ZERO)
	var second_center: Vector2 = second.get("center", Vector2.ZERO)
	var first_wins := first_center.y > second_center.y + POSITION_EPSILON or (is_equal_approx(first_center.y, second_center.y) and first_center.x > second_center.x + POSITION_EPSILON)
	var winner: Dictionary = first if first_wins else second
	var loser: Dictionary = second if first_wins else first
	_set_result(result, winner, true, "visible")
	_set_result(result, loser, false, "covered")


static func _set_result(result: Dictionary, record: Dictionary, enabled: bool, diagnostic: String) -> void:
	var component_id := str(record.get("component_id", ""))
	var edge_id := str(record.get("edge_id", ""))
	if not result.has(component_id):
		result[component_id] = {}
	result[component_id][edge_id] = {"enabled": enabled, "diagnostic": diagnostic}


static func _edges_overlap(first: Dictionary, second: Dictionary) -> bool:
	var first_samples: PackedVector2Array = first.get("samples", PackedVector2Array())
	var second_samples: PackedVector2Array = second.get("samples", PackedVector2Array())
	if first_samples.size() < 2 or second_samples.size() < 2:
		return false
	var first_bounds := _bounds(first_samples)
	var second_bounds := _bounds(second_samples)
	if not first_bounds.grow(BOUNDS_EPSILON).intersects(second_bounds.grow(BOUNDS_EPSILON)):
		return false
	var same_direction := _samples_match(first_samples, second_samples)
	var reversed_direction := _samples_match(first_samples, _reverse_samples(second_samples))
	return same_direction or reversed_direction


static func _reverse_samples(samples: PackedVector2Array) -> PackedVector2Array:
	var reversed := PackedVector2Array()
	for index in range(samples.size() - 1, -1, -1):
		reversed.append(samples[index])
	return reversed


static func _samples_match(first: PackedVector2Array, second: PackedVector2Array) -> bool:
	if first.size() != second.size():
		return false
	for index in range(first.size()):
		if first[index].distance_squared_to(second[index]) > POSITION_EPSILON * POSITION_EPSILON:
			return false
	return true


static func _edge_samples(start: Dictionary, end: Dictionary, world_transform: Transform2D) -> PackedVector2Array:
	var controls := BezierGeometry.cubic_controls(start, end)
	var samples := PackedVector2Array()
	for index in range(SAMPLE_COUNT):
		var t := float(index) / float(SAMPLE_COUNT - 1)
		samples.append(world_transform * BezierGeometry.cubic_position(controls, t))
	return samples


static func _sample_center(samples: PackedVector2Array) -> Vector2:
	if samples.is_empty():
		return Vector2.ZERO
	var center := Vector2.ZERO
	for point in samples:
		center += point
	return center / float(samples.size())


static func _bounds(points: PackedVector2Array) -> Rect2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds
