class_name BezierGeometry
extends RefCounted

const VALID_MODES := ["linear", "free", "aligned", "mirrored", "corner"]


static func resolve_auto_handles(points: Array, chains: Array) -> void:
	for chain_data in chains:
		if chain_data is Dictionary:
			resolve_chain_auto_handles(points, chain_data)


static func resolve_chain_auto_handles(points: Array, chain_data: Dictionary) -> void:
	var points_by_id: Dictionary = {}
	for point_data in points:
		if point_data is Dictionary:
			points_by_id[str(point_data.get("id", ""))] = point_data
	var point_ids: Array = chain_data.get("point_ids", [])
	var closed := bool(chain_data.get("closed", false)) and point_ids.size() >= 3
	for chain_index in range(point_ids.size()):
		var point_id := str(point_ids[chain_index])
		if not points_by_id.has(point_id):
			continue
		var point_data: Dictionary = points_by_id[point_id]
		var mode := str(point_data.get("mode", "linear"))
		if mode not in VALID_MODES:
			mode = "linear"
			point_data["mode"] = mode
		var source := str(point_data.get("handle_source", "auto"))
		if source != "manual":
			source = "auto"
			point_data["handle_source"] = source
		if mode == "linear":
			point_data["handle_in"] = Vector2.ZERO
			point_data["handle_out"] = Vector2.ZERO
			continue
		if source == "manual":
			continue
		var previous := _chain_neighbor(points_by_id, point_ids, chain_index, -1, closed)
		var next := _chain_neighbor(points_by_id, point_ids, chain_index, 1, closed)
		_apply_automatic_handles(point_data, previous, next, mode)


static func _chain_neighbor(points_by_id: Dictionary, point_ids: Array, point_index: int, direction: int, closed: bool) -> Dictionary:
	var neighbor_index := point_index + direction
	if closed:
		neighbor_index = posmod(neighbor_index, point_ids.size())
	elif neighbor_index < 0 or neighbor_index >= point_ids.size():
		return {}
	var neighbor_id := str(point_ids[neighbor_index])
	return points_by_id.get(neighbor_id, {})


static func _apply_automatic_handles(point_data: Dictionary, previous: Dictionary, next: Dictionary, mode: String) -> void:
	var position: Vector2 = point_data.get("position", Vector2.ZERO)
	if previous.is_empty() and next.is_empty():
		point_data["handle_in"] = Vector2.ZERO
		point_data["handle_out"] = Vector2.ZERO
		return
	if previous.is_empty():
		var next_position: Vector2 = next.get("position", position)
		point_data["handle_in"] = Vector2.ZERO
		point_data["handle_out"] = (next_position - position) / 3.0
		return
	if next.is_empty():
		var previous_position: Vector2 = previous.get("position", position)
		point_data["handle_in"] = (previous_position - position) / 3.0
		point_data["handle_out"] = Vector2.ZERO
		return
	var previous_position: Vector2 = previous.get("position", position)
	var next_position: Vector2 = next.get("position", position)
	var tangent := next_position - previous_position
	if tangent.length_squared() <= 0.000001:
		tangent = next_position - position
	if tangent.length_squared() <= 0.000001:
		point_data["handle_in"] = Vector2.ZERO
		point_data["handle_out"] = Vector2.ZERO
		return
	var direction := tangent.normalized()
	var incoming_length := position.distance_to(previous_position) / 3.0
	var outgoing_length := position.distance_to(next_position) / 3.0
	# A corner intentionally has no shared tangent. Each handle follows its own
	# neighbouring edge, so both curve segments meet exactly at a sharp cusp.
	if mode == "corner":
		point_data["handle_in"] = (previous_position - position) / 3.0
		point_data["handle_out"] = (next_position - position) / 3.0
		return
	if mode == "mirrored":
		var mirrored_length := minf(incoming_length, outgoing_length)
		point_data["handle_in"] = -direction * mirrored_length
		point_data["handle_out"] = direction * mirrored_length
		return
	point_data["handle_in"] = -direction * incoming_length
	point_data["handle_out"] = direction * outgoing_length


static func split_edge(start_point: Dictionary, end_point: Dictionary, t: float) -> Dictionary:
	var clamped_t := clampf(t, 0.001, 0.999)
	var p0: Vector2 = start_point.get("position", Vector2.ZERO)
	var p1 := p0 + Vector2(start_point.get("handle_out", Vector2.ZERO))
	var p3: Vector2 = end_point.get("position", Vector2.ZERO)
	var p2 := p3 + Vector2(end_point.get("handle_in", Vector2.ZERO))
	var a := p0.lerp(p1, clamped_t)
	var b := p1.lerp(p2, clamped_t)
	var c := p2.lerp(p3, clamped_t)
	var d := a.lerp(b, clamped_t)
	var e := b.lerp(c, clamped_t)
	var point := d.lerp(e, clamped_t)
	return {
		"position": point,
		"start_handle_out": a - p0,
		"new_handle_in": d - point,
		"new_handle_out": e - point,
		"end_handle_in": c - p3
	}


static func cubic_controls(start_point: Dictionary, end_point: Dictionary) -> Array[Vector2]:
	var p0: Vector2 = start_point.get("position", Vector2.ZERO)
	var p3: Vector2 = end_point.get("position", Vector2.ZERO)
	return [
		p0,
		p0 + Vector2(start_point.get("handle_out", Vector2.ZERO)),
		p3 + Vector2(end_point.get("handle_in", Vector2.ZERO)),
		p3
	]


static func cubic_position(controls: Array[Vector2], t: float) -> Vector2:
	if controls.size() != 4:
		return Vector2.ZERO
	var clamped_t := clampf(t, 0.0, 1.0)
	var inverse := 1.0 - clamped_t
	return controls[0] * inverse * inverse * inverse \
		+ controls[1] * 3.0 * inverse * inverse * clamped_t \
		+ controls[2] * 3.0 * inverse * clamped_t * clamped_t \
		+ controls[3] * clamped_t * clamped_t * clamped_t


static func flatten_chain(component: Dictionary, chain_data: Dictionary, subdivisions_per_edge := 32) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var edges: Array = component.get("edges", [])
	var points: Array = component.get("points", [])
	var steps := maxi(subdivisions_per_edge, 1)
	for edge_id_value in chain_data.get("edge_ids", []):
		var edge := BezierTopology.edge_by_id(edges, str(edge_id_value))
		if edge.is_empty():
			continue
		var start_point := BezierTopology.point_by_id(points, str(edge.get("start_point_id", "")))
		var end_point := BezierTopology.point_by_id(points, str(edge.get("end_point_id", "")))
		if start_point.is_empty() or end_point.is_empty():
			continue
		var controls := cubic_controls(start_point, end_point)
		if polygon.is_empty():
			polygon.append(controls[0])
		for sample_index in range(1, steps + 1):
			polygon.append(cubic_position(controls, float(sample_index) / float(steps)))
	if bool(chain_data.get("closed", false)) and polygon.size() > 1 and polygon[0].is_equal_approx(polygon[polygon.size() - 1]):
		polygon.remove_at(polygon.size() - 1)
	return polygon


static func cubic_tangent(controls: Array[Vector2], t: float) -> Vector2:
	if controls.size() != 4:
		return Vector2.ZERO
	var clamped_t := clampf(t, 0.0, 1.0)
	var inverse := 1.0 - clamped_t
	return (controls[1] - controls[0]) * 3.0 * inverse * inverse \
		+ (controls[2] - controls[1]) * 6.0 * inverse * clamped_t \
		+ (controls[3] - controls[2]) * 3.0 * clamped_t * clamped_t


static func split_cubic_controls(controls: Array[Vector2], t := 0.5) -> Array:
	if controls.size() != 4:
		return []
	var clamped_t := clampf(t, 0.0, 1.0)
	var a := controls[0].lerp(controls[1], clamped_t)
	var b := controls[1].lerp(controls[2], clamped_t)
	var c := controls[2].lerp(controls[3], clamped_t)
	var d := a.lerp(b, clamped_t)
	var e := b.lerp(c, clamped_t)
	var point := d.lerp(e, clamped_t)
	var left: Array[Vector2] = [controls[0], a, d, point]
	var right: Array[Vector2] = [point, e, c, controls[3]]
	return [left, right]


static func cubic_flatness(controls: Array[Vector2]) -> float:
	if controls.size() != 4:
		return 0.0
	return maxf(_distance_to_infinite_line(controls[1], controls[0], controls[3]), _distance_to_infinite_line(controls[2], controls[0], controls[3]))


static func cubic_tangent_turn(controls: Array[Vector2]) -> float:
	if controls.size() != 4:
		return 0.0
	var chord := controls[3] - controls[0]
	var start_tangent := controls[1] - controls[0]
	var end_tangent := controls[3] - controls[2]
	if start_tangent.length_squared() <= 0.000001:
		start_tangent = chord
	if end_tangent.length_squared() <= 0.000001:
		end_tangent = chord
	if start_tangent.length_squared() <= 0.000001 or end_tangent.length_squared() <= 0.000001:
		return 0.0
	return absf(start_tangent.angle_to(end_tangent))


static func _distance_to_infinite_line(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var direction := line_end - line_start
	if direction.length_squared() <= 0.000001:
		return point.distance_to(line_start)
	return absf(direction.cross(point - line_start)) / direction.length()
