class_name SelectionMirrorService
extends RefCounted


## Mirrors one contiguous Point selection from the sole open Chain of a
## Closed Loop Component. The result deliberately stays a separate open Chain:
## joining the two endpoints remains an explicit authoring action.
static func preview(component: Dictionary, selected_point_ids: Array, axis_start: Vector2, axis_end: Vector2) -> Dictionary:
	var validation := validation_issues(component, selected_point_ids, axis_start, axis_end)
	if not validation.is_empty():
		return {"valid": false, "errors": validation, "points": [], "edges": []}
	var source_ids := _selected_run(component, selected_point_ids)
	var preview_points: Array = []
	var preview_by_source: Dictionary = {}
	for source_id in source_ids:
		var source := BezierTopology.point_by_id(component.get("points", []), source_id)
		var reflected := _reflected_point(source, axis_start, axis_end, "preview:%s" % source_id)
		preview_points.append(reflected)
		preview_by_source[source_id] = reflected
	var preview_edges: Array = []
	for index in range(source_ids.size() - 1, 0, -1):
		var start: Dictionary = preview_by_source[source_ids[index]]
		var end: Dictionary = preview_by_source[source_ids[index - 1]]
		preview_edges.append({
			"id": "preview:edge:%d" % index,
			"start_point_id": str(start.get("id", "")),
			"end_point_id": str(end.get("id", "")),
			"render_outline": true
		})
	return {"valid": true, "errors": [], "points": preview_points, "edges": preview_edges}


static func apply(component: Dictionary, selected_point_ids: Array, axis_start: Vector2, axis_end: Vector2) -> Dictionary:
	var validation := validation_issues(component, selected_point_ids, axis_start, axis_end)
	if not validation.is_empty():
		return {"valid": false, "errors": validation, "component": {}, "mirrored_point_ids": []}
	var result := component.duplicate(true)
	var source_ids := _selected_run(component, selected_point_ids)
	var points: Array = result.get("points", [])
	var mirrored_ids: Array[String] = []
	for source_index in range(source_ids.size() - 1, -1, -1):
		var source := BezierTopology.point_by_id(component.get("points", []), source_ids[source_index])
		var mirrored_id := BezierTopology.next_id(points, "mirror_point")
		points.append(_reflected_point(source, axis_start, axis_end, mirrored_id))
		mirrored_ids.append(mirrored_id)
	result["points"] = points
	var chains: Array = result.get("chains", [])
	var mirrored_chain := {
		"id": BezierTopology.next_id(chains, "mirror_chain"),
		"point_ids": mirrored_ids,
		"edge_ids": [],
		"closed": false,
		"topology_role": "outer"
	}
	chains.append(mirrored_chain)
	result["chains"] = chains
	BezierTopology.rebuild_chain_edges(result, mirrored_chain)
	return {
		"valid": BezierTopology.validate(result).is_empty(),
		"errors": BezierTopology.validate(result),
		"component": result,
		"mirrored_point_ids": mirrored_ids
	}


static func validation_issues(component: Dictionary, selected_point_ids: Array, axis_start: Vector2, axis_end: Vector2) -> Array[String]:
	var errors := BezierTopology.validate(component)
	if str(component.get("draw_mode", "closed_loop")) != "closed_loop":
		errors.append("Mirror is available only for Closed Loop Components.")
	var chains: Array = component.get("chains", [])
	if chains.size() != 1 or (not chains.is_empty() and bool(chains[0].get("closed", false))):
		errors.append("Mirror requires one open source Chain.")
	if selected_point_ids.is_empty():
		errors.append("Mirror requires a selected Point run.")
	if _selected_run(component, selected_point_ids).size() != selected_point_ids.size():
		errors.append("Mirror selection must be one contiguous run on the open Chain.")
	if axis_start.distance_squared_to(axis_end) <= 0.00000001:
		errors.append("Mirror axis requires two distinct Points.")
	return errors


static func _selected_run(component: Dictionary, selected_point_ids: Array) -> Array[String]:
	if component.get("chains", []).size() != 1:
		return []
	var source_ids: Array = component.get("chains", [])[0].get("point_ids", [])
	var selected: Dictionary = {}
	for point_id_value in selected_point_ids:
		selected[str(point_id_value)] = true
	var run: Array[String] = []
	var started := false
	for point_id_value in source_ids:
		var point_id := str(point_id_value)
		if selected.has(point_id):
			run.append(point_id)
			started = true
		elif started:
			break
	return run


static func _reflected_point(source: Dictionary, axis_start: Vector2, axis_end: Vector2, point_id: String) -> Dictionary:
	var result: Dictionary = source.duplicate(true)
	result["id"] = point_id
	result["position"] = _reflect_position(Vector2(source.get("position", Vector2.ZERO)), axis_start, axis_end)
	result["handle_in"] = _reflect_vector(Vector2(source.get("handle_out", Vector2.ZERO)), axis_start, axis_end)
	result["handle_out"] = _reflect_vector(Vector2(source.get("handle_in", Vector2.ZERO)), axis_start, axis_end)
	return result


static func _reflect_position(position: Vector2, axis_start: Vector2, axis_end: Vector2) -> Vector2:
	var direction := (axis_end - axis_start).normalized()
	var projection := axis_start + direction * (position - axis_start).dot(direction)
	return projection * 2.0 - position


static func _reflect_vector(value: Vector2, axis_start: Vector2, axis_end: Vector2) -> Vector2:
	var direction := (axis_end - axis_start).normalized()
	return direction * (2.0 * value.dot(direction)) - value
