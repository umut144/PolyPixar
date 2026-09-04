class_name SelectionMirrorService
extends RefCounted


## Mirrors one contiguous Point selection from the sole open Chain of a
## Closed Loop Component. When both ends of the mirrored run land on source
## endpoints, the two halves are canonicalized into one closed Chain.
const COINCIDENT_ENDPOINT_EPSILON := 0.0001
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
		"topology_role": WorldDocumentService.ROLE_OUTER
	}
	chains.append(mirrored_chain)
	result["chains"] = chains
	BezierTopology.rebuild_chain_edges(result, mirrored_chain)
	var coincident_pairs := _coincident_pairs(result, source_ids, mirrored_ids)
	var auto_connection := {"count": 0, "removed_mirrored_id": ""}
	if coincident_pairs.size() == 2 and _pairs_are_open_endpoints(result, coincident_pairs):
		auto_connection = _merge_coincident_closed_loop(result, coincident_pairs)
	elif coincident_pairs.size() == 1 and _pair_is_open_endpoint(result, coincident_pairs[0]):
		auto_connection = _merge_coincident_open_endpoints(result, source_ids, mirrored_ids)
	elif not coincident_pairs.is_empty():
		return {
			"valid": false,
			"errors": ["Mirror can connect coincident Points only at open Chain endpoints."],
			"component": {},
			"mirrored_point_ids": []
		}
	var removed_mirrored_id := str(auto_connection.get("removed_mirrored_id", ""))
	if not removed_mirrored_id.is_empty():
		mirrored_ids.erase(removed_mirrored_id)
	if int(auto_connection.get("count", 0)) == 2:
		for pair in coincident_pairs:
			mirrored_ids.erase(str(pair.get("mirrored_id", "")))
	return {
		"valid": BezierTopology.validate(result).is_empty(),
		"errors": BezierTopology.validate(result),
		"component": result,
		"mirrored_point_ids": mirrored_ids,
		"auto_connected_count": int(auto_connection.get("count", 0))
}


static func _coincident_pairs(component: Dictionary, source_ids: Array, mirrored_ids: Array) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	var used_mirrored: Dictionary = {}
	for source_id_value in source_ids:
		var source_id := str(source_id_value)
		var source_point := BezierTopology.point_by_id(component.get("points", []), source_id)
		if source_point.is_empty():
			continue
		var source_position: Vector2 = source_point.get("position", Vector2.ZERO)
		for mirrored_id_value in mirrored_ids:
			var mirrored_id := str(mirrored_id_value)
			if used_mirrored.has(mirrored_id):
				continue
			var mirrored_point := BezierTopology.point_by_id(component.get("points", []), mirrored_id)
			if mirrored_point.is_empty():
				continue
			if source_position.distance_squared_to(Vector2(mirrored_point.get("position", Vector2.ZERO))) <= COINCIDENT_ENDPOINT_EPSILON * COINCIDENT_ENDPOINT_EPSILON:
				pairs.append({"source_id": source_id, "mirrored_id": mirrored_id})
				used_mirrored[mirrored_id] = true
				break
	return pairs


static func _pair_is_open_endpoint(component: Dictionary, pair: Dictionary) -> bool:
	return BezierTopology.is_open_endpoint(component, str(pair.get("source_id", ""))) and BezierTopology.is_open_endpoint(component, str(pair.get("mirrored_id", "")))


static func _pairs_are_open_endpoints(component: Dictionary, pairs: Array) -> bool:
	if pairs.size() != 2:
		return false
	for pair in pairs:
		if not _pair_is_open_endpoint(component, pair):
			return false
	return true


## A half-contour mirrored across its two endpoint axis contacts is already a
## complete loop. Join the first contact, remove both duplicate mirrored
## endpoints, then close the resulting single Chain.
static func _merge_coincident_closed_loop(component: Dictionary, pairs: Array) -> Dictionary:
	var first_pair: Dictionary = pairs[0]
	var first_mirrored_id := str(first_pair.get("mirrored_id", ""))
	_merge_reflected_endpoint_handles(component, first_pair)
	_merge_reflected_endpoint_handles(component, pairs[1])
	if not BezierTopology.join_open_chain_endpoints(component, str(first_pair.get("source_id", "")), first_mirrored_id):
		return {"count": 0, "removed_mirrored_id": ""}
	var merged_chain := BezierTopology.chain_for_point(component.get("chains", []), str(first_pair.get("source_id", "")))
	if merged_chain.is_empty():
		return {"count": 0, "removed_mirrored_id": ""}
	var merged_ids: Array = merged_chain.get("point_ids", []).duplicate()
	merged_ids.erase(first_mirrored_id)
	var second_mirrored_id := str(pairs[1].get("mirrored_id", ""))
	merged_ids.erase(second_mirrored_id)
	merged_chain["point_ids"] = merged_ids
	BezierTopology.rebuild_chain_edges(component, merged_chain)
	if not BezierTopology.close_chain(component, str(merged_chain.get("id", ""))):
		return {"count": 0, "removed_mirrored_id": ""}
	_remove_point(component, first_mirrored_id)
	_remove_point(component, second_mirrored_id)
	return {"count": 2, "removed_mirrored_id": second_mirrored_id}


## Keeps the source Point identity while restoring the Handle contributed by
## the reflected half. The source Chain endpoint has only one active side while
## open; after joining, the coincident reflected endpoint supplies the other.
static func _merge_reflected_endpoint_handles(component: Dictionary, pair: Dictionary) -> void:
	var source := BezierTopology.point_by_id(component.get("points", []), str(pair.get("source_id", "")))
	var mirrored := BezierTopology.point_by_id(component.get("points", []), str(pair.get("mirrored_id", "")))
	if source.is_empty() or mirrored.is_empty():
		return
	var source_chain := BezierTopology.chain_for_point(component.get("chains", []), str(source.get("id", "")))
	if source_chain.is_empty():
		return
	var source_ids: Array = source_chain.get("point_ids", [])
	var source_id := str(source.get("id", ""))
	if source_id == str(source_ids.front()):
		source["handle_in"] = Vector2(mirrored.get("handle_in", Vector2.ZERO))
	elif source_id == str(source_ids.back()):
		source["handle_out"] = Vector2(mirrored.get("handle_out", Vector2.ZERO))


static func _remove_point(component: Dictionary, point_id: String) -> void:
	var points: Array = component.get("points", [])
	for point_index in range(points.size() - 1, -1, -1):
		if str(points[point_index].get("id", "")) == point_id:
			points.remove_at(point_index)
			break
	component["points"] = points
	BezierGeometry.resolve_auto_handles(points, component.get("chains", []))


## Merges coincident endpoints into one shared Point. The original pre-mirror
## Point keeps its identity and settings while the reflected half contributes
## the Handle needed on its newly connected side.
static func _merge_coincident_open_endpoints(component: Dictionary, source_ids: Array, mirrored_ids: Array) -> Dictionary:
	if source_ids.is_empty() or mirrored_ids.is_empty():
		return {"count": 0, "removed_mirrored_id": ""}
	var source_endpoints := [str(source_ids.front()), str(source_ids.back())]
	var mirrored_endpoints := [str(mirrored_ids.front()), str(mirrored_ids.back())]
	for source_endpoint in source_endpoints:
		var source_point := BezierTopology.point_by_id(component.get("points", []), source_endpoint)
		if source_point.is_empty():
			continue
		for mirrored_endpoint in mirrored_endpoints:
			var mirrored_point := BezierTopology.point_by_id(component.get("points", []), mirrored_endpoint)
			if mirrored_point.is_empty():
				continue
			var source_position: Vector2 = source_point.get("position", Vector2.ZERO)
			var mirrored_position: Vector2 = mirrored_point.get("position", Vector2.ZERO)
			if source_position.distance_squared_to(mirrored_position) > COINCIDENT_ENDPOINT_EPSILON * COINCIDENT_ENDPOINT_EPSILON:
				continue
			_merge_reflected_endpoint_handles(component, {"source_id": source_endpoint, "mirrored_id": mirrored_endpoint})
			if BezierTopology.join_open_chain_endpoints(component, source_endpoint, mirrored_endpoint):
				var merged_chain := BezierTopology.chain_for_point(component.get("chains", []), source_endpoint)
				var merged_ids: Array = merged_chain.get("point_ids", []).duplicate()
				merged_ids.erase(mirrored_endpoint)
				merged_chain["point_ids"] = merged_ids
				BezierTopology.rebuild_chain_edges(component, merged_chain)
				var points: Array = component.get("points", [])
				for point_index in range(points.size() - 1, -1, -1):
					if str(points[point_index].get("id", "")) == mirrored_endpoint:
						points.remove_at(point_index)
						break
				component["points"] = points
				BezierGeometry.resolve_auto_handles(points, component.get("chains", []))
				return {"count": 1, "removed_mirrored_id": mirrored_endpoint}
	return {"count": 0, "removed_mirrored_id": ""}


static func validation_issues(component: Dictionary, selected_point_ids: Array, axis_start: Vector2, axis_end: Vector2) -> Array[String]:
	var errors := selection_issues(component, selected_point_ids)
	if axis_start.distance_squared_to(axis_end) <= 0.00000001:
		errors.append("Mirror axis requires two distinct Points.")
	else:
		for point_id in _selected_run(component, selected_point_ids):
			var point := BezierTopology.point_by_id(component.get("points", []), point_id)
			var position: Vector2 = point.get("position", Vector2.ZERO)
			if position.distance_squared_to(_reflect_position(position, axis_start, axis_end)) <= COINCIDENT_ENDPOINT_EPSILON * COINCIDENT_ENDPOINT_EPSILON and not BezierTopology.is_open_endpoint(component, point_id):
				errors.append("Points on the mirror axis must be open Chain endpoints.")
				break
	return errors


## Checks only the source topology and selection. The interactive Mirror command
## uses this before an axis exists; preview and apply add the axis-specific rules.
static func selection_issues(component: Dictionary, selected_point_ids: Array) -> Array[String]:
	var errors := BezierTopology.validate(component)
	if not WorldDocumentService.is_closed_loop(component):
		errors.append("Mirror is available only for Closed Loop Components.")
	var chains: Array = component.get("chains", [])
	if chains.size() != 1 or (not chains.is_empty() and bool(chains[0].get("closed", false))):
		errors.append("Mirror requires one open source Chain.")
	if selected_point_ids.is_empty():
		errors.append("Mirror requires a selected Point run.")
	if _selected_run(component, selected_point_ids).size() != selected_point_ids.size():
		errors.append("Mirror selection must be one contiguous run on the open Chain.")
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
