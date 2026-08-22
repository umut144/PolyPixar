class_name OutlineCoverageService
extends RefCounted

## Derives editor-only coverage diagnostics for manually disabled Edges.
## It never changes Render Outline visibility or authored topology.

const SAMPLES_PER_EDGE := 32
const DISTANCE_EPSILON := 0.001
const PARALLEL_EPSILON := 0.01
const MIN_OVERLAP_LENGTH := 0.01


static func resolve_asset(asset: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var records: Array[Dictionary] = []
	var components: Array[Dictionary] = []
	for component in asset.get("components", []):
		if component is Dictionary and str(component.get("type", "component")) != "guide":
			components.append(component)
	for component_index in range(components.size()):
		var component: Dictionary = components[component_index]
		if not _component_visible(asset, component):
			continue
		var component_id := str(component.get("id", ""))
		var points_by_id: Dictionary = {}
		for point in component.get("points", []):
			if point is Dictionary:
				points_by_id[str(point.get("id", ""))] = point
		for edge in component.get("edges", []):
			if not edge is Dictionary:
				continue
			var edge_id := str(edge.get("id", ""))
			var start: Dictionary = points_by_id.get(str(edge.get("start_point_id", "")), {})
			var end: Dictionary = points_by_id.get(str(edge.get("end_point_id", "")), {})
			if edge_id.is_empty() or start.is_empty() or end.is_empty():
				continue
			var entry := {"component_id": component_id, "edge_id": edge_id, "edge": edge, "component_index": component_index, "effective_z": _effective_z_index(asset, component), "samples": _edge_samples(start, end, ComponentHierarchy.world_transform(asset, component_id))}
			records.append(entry)
			if not result.has(component_id):
				result[component_id] = {}
			result[component_id][edge_id] = false
	for record in records:
		var edge: Dictionary = record.get("edge", {})
		if bool(edge.get("render_outline", true)):
			continue
		for overlay in records:
			if record == overlay or int(overlay.get("component_index", -1)) <= int(record.get("component_index", -1)):
				continue
			if _edge_is_above(record, overlay):
				var overlay_samples: PackedVector2Array = overlay.get("samples", PackedVector2Array())
				if _has_partial_overlap(record.get("samples", PackedVector2Array()), overlay_samples):
					result[str(record.get("component_id", ""))][str(record.get("edge_id", ""))] = true
					break
	return result


static func _edge_is_above(first: Dictionary, second: Dictionary) -> bool:
	# Higher effective Z is above. Equal-Z Components use document order, which
	# is also the stable fallback used by the editor's Component ordering.
	return int(first.get("effective_z", 0)) <= int(second.get("effective_z", 0))


static func _component_visible(asset: Dictionary, component: Dictionary) -> bool:
	if not bool(asset.get("visibility", true)) or not bool(component.get("visibility", true)):
		return false
	var group_id := str(component.get("group_id", ""))
	if group_id.is_empty():
		return true
	var group := ComponentHierarchy.group_by_id(asset, group_id)
	return group.is_empty() or bool(group.get("visibility", true))


static func _effective_z_index(_asset: Dictionary, component: Dictionary) -> int:
	return int(component.get("z_index", 0))


static func _edge_samples(start: Dictionary, end: Dictionary, transform: Transform2D) -> PackedVector2Array:
	var controls := BezierGeometry.cubic_controls(start, end)
	var samples := PackedVector2Array()
	for index in range(SAMPLES_PER_EDGE + 1):
		samples.append(transform * BezierGeometry.cubic_position(controls, float(index) / float(SAMPLES_PER_EDGE)))
	return samples


static func _has_partial_overlap(first: PackedVector2Array, second: PackedVector2Array) -> bool:
	for first_index in range(first.size() - 1):
		var first_start := first[first_index]
		var first_end := first[first_index + 1]
		var first_vector := first_end - first_start
		var first_length := first_vector.length()
		if first_length <= DISTANCE_EPSILON:
			continue
		var first_direction := first_vector / first_length
		for second_index in range(second.size() - 1):
			var second_start := second[second_index]
			var second_end := second[second_index + 1]
			var second_vector := second_end - second_start
			var second_length := second_vector.length()
			if second_length <= DISTANCE_EPSILON:
				continue
			var second_direction := second_vector / second_length
			if absf(first_direction.cross(second_direction)) > PARALLEL_EPSILON:
				continue
			if _distance_to_line(second_start, first_start, first_end) > DISTANCE_EPSILON or _distance_to_line(second_end, first_start, first_end) > DISTANCE_EPSILON:
				continue
			var overlap := _projected_overlap(first_start, first_end, second_start, second_end, first_direction)
			if overlap >= MIN_OVERLAP_LENGTH:
				return true
	return false


static func _projected_overlap(first_start: Vector2, first_end: Vector2, second_start: Vector2, second_end: Vector2, direction: Vector2) -> float:
	var first_min := 0.0
	var first_max := (first_end - first_start).dot(direction)
	var second_min := (second_start - first_start).dot(direction)
	var second_max := (second_end - first_start).dot(direction)
	if second_min > second_max:
		var swap := second_min
		second_min = second_max
		second_max = swap
	return maxf(0.0, minf(first_max, second_max) - maxf(first_min, second_min))


static func _distance_to_line(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var direction := line_end - line_start
	var length := direction.length()
	return point.distance_to(line_start) if length <= DISTANCE_EPSILON else absf(direction.cross(point - line_start)) / length
