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
