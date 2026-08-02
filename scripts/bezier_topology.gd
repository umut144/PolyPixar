class_name BezierTopology
extends RefCounted

const VALID_POINT_MODES := ["linear", "aligned", "free", "mirrored", "corner"]
const VALID_TOPOLOGY_ROLES := ["outer", "hole", "cut", "seam"]


static func next_id(items: Array, prefix: String) -> String:
	var known_ids: Dictionary = {}
	for item in items:
		if item is Dictionary:
			known_ids[str(item.get("id", ""))] = true
	var candidate := "%s_%d" % [prefix, ResourceUID.create_id()]
	while known_ids.has(candidate):
		candidate = "%s_%d" % [prefix, ResourceUID.create_id()]
	return candidate


static func point_by_id(points: Array, point_id: String) -> Dictionary:
	for point_data in points:
		if point_data is Dictionary and str(point_data.get("id", "")) == point_id:
			return point_data
	return {}


static func edge_by_id(edges: Array, edge_id: String) -> Dictionary:
	for edge_data in edges:
		if edge_data is Dictionary and str(edge_data.get("id", "")) == edge_id:
			return edge_data
	return {}


static func chain_for_point(chains: Array, point_id: String) -> Dictionary:
	for chain_data in chains:
		if chain_data is Dictionary and point_id in chain_data.get("point_ids", []):
			return chain_data
	return {}


static func chain_for_edge(chains: Array, edge_id: String) -> Dictionary:
	for chain_data in chains:
		if chain_data is Dictionary and edge_id in chain_data.get("edge_ids", []):
			return chain_data
	return {}


static func outer_chain(component: Dictionary) -> Dictionary:
	var chains: Array = component.get("chains", [])
	for chain_data in chains:
		if chain_data is Dictionary and str(chain_data.get("topology_role", "outer")) == "outer":
			return chain_data
	return chains[0] if not chains.is_empty() and chains[0] is Dictionary else {}


static func outer_chain_closed(component: Dictionary) -> bool:
	var chain := outer_chain(component)
	return not chain.is_empty() and bool(chain.get("closed", false))


static func outer_control_polygon(component: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var chain := outer_chain(component)
	if chain.is_empty():
		return result
	var points: Array = component.get("points", [])
	for point_id_value in chain.get("point_ids", []):
		var point := point_by_id(points, str(point_id_value))
		if not point.is_empty():
			result.append(Vector2(point.get("position", Vector2.ZERO)))
	return result


static func add_point(component: Dictionary, position: Vector2, requested_mode: String, drawn_handle_out := Vector2.ZERO) -> String:
	var points: Array = component.get("points", [])
	var edges: Array = component.get("edges", [])
	var chains: Array = component.get("chains", [])
	if chains.is_empty() or bool(chains.back().get("closed", false)):
		chains.append({
			"id": next_id(chains, "chain"),
			"point_ids": [],
			"edge_ids": [],
			"closed": false,
			"topology_role": "outer"
		})
	var chain: Dictionary = chains.back()
	var mode := requested_mode if requested_mode in VALID_POINT_MODES else "linear"
	var point_id := next_id(points, "point")
	var new_point := {
		"id": point_id,
		"position": position,
		"mode": mode,
		"preserve_point": mode == "corner",
		"handle_source": "auto",
		"handle_in": Vector2.ZERO,
		"handle_out": Vector2.ZERO
	}
	points.append(new_point)
	var point_ids: Array = chain.get("point_ids", [])
	var edge_ids: Array = chain.get("edge_ids", [])
	if not point_ids.is_empty():
		var edge_id := next_id(edges, "edge")
		edges.append({
			"id": edge_id,
			"start_point_id": str(point_ids.back()),
			"end_point_id": point_id,
			"render_outline": true
		})
		edge_ids.append(edge_id)
	point_ids.append(point_id)
	chain["point_ids"] = point_ids
	chain["edge_ids"] = edge_ids
	component["points"] = points
	component["edges"] = edges
	component["chains"] = chains
	BezierGeometry.resolve_auto_handles(points, chains)
	if mode != "linear" and not is_zero_approx(drawn_handle_out.length_squared()):
		new_point["handle_source"] = "manual"
		new_point["handle_out"] = drawn_handle_out
		var automatic_in: Vector2 = new_point.get("handle_in", Vector2.ZERO)
		if mode == "mirrored":
			new_point["handle_in"] = -drawn_handle_out
		elif mode == "aligned":
			var incoming_length := automatic_in.length()
			if is_zero_approx(incoming_length):
				incoming_length = drawn_handle_out.length()
			new_point["handle_in"] = -drawn_handle_out.normalized() * incoming_length
	return point_id


static func close_active_chain(component: Dictionary) -> bool:
	var chains: Array = component.get("chains", [])
	if chains.is_empty():
		return false
	var chain: Dictionary = chains.back()
	var point_ids: Array = chain.get("point_ids", [])
	if bool(chain.get("closed", false)) or point_ids.size() < 3:
		return false
	var edges: Array = component.get("edges", [])
	var edge_ids: Array = chain.get("edge_ids", [])
	var edge_id := next_id(edges, "edge")
	edges.append({
		"id": edge_id,
		"start_point_id": str(point_ids.back()),
		"end_point_id": str(point_ids.front()),
		"render_outline": true
	})
	edge_ids.append(edge_id)
	chain["edge_ids"] = edge_ids
	chain["closed"] = true
	var points: Array = component.get("points", [])
	var first_point := point_by_id(points, str(point_ids.front()))
	var last_point := point_by_id(points, str(point_ids.back()))
	if not first_point.is_empty():
		first_point["preserve_point"] = true
	if not last_point.is_empty():
		last_point["preserve_point"] = true
	component["edges"] = edges
	component["chains"] = chains
	BezierGeometry.resolve_auto_handles(points, chains)
	return true


static func insert_point_on_edge(component: Dictionary, edge_id: String, t: float) -> String:
	var points: Array = component.get("points", [])
	var edges: Array = component.get("edges", [])
	var chains: Array = component.get("chains", [])
	var edge := edge_by_id(edges, edge_id)
	var chain := chain_for_edge(chains, edge_id)
	if edge.is_empty() or chain.is_empty():
		return ""
	var start_id := str(edge.get("start_point_id", ""))
	var end_id := str(edge.get("end_point_id", ""))
	var start_point := point_by_id(points, start_id)
	var end_point := point_by_id(points, end_id)
	if start_point.is_empty() or end_point.is_empty():
		return ""
	var point_ids: Array = chain.get("point_ids", [])
	var edge_ids: Array = chain.get("edge_ids", [])
	var start_index := point_ids.find(start_id)
	var edge_index := edge_ids.find(edge_id)
	if start_index < 0 or edge_index < 0:
		return ""
	var split := BezierGeometry.split_edge(start_point, end_point, t)
	start_point["handle_out"] = split["start_handle_out"]
	start_point["handle_source"] = "manual"
	end_point["handle_in"] = split["end_handle_in"]
	end_point["handle_source"] = "manual"
	var new_point_id := next_id(points, "point")
	points.append({
		"id": new_point_id,
		"position": split["position"],
		"mode": "free",
		"preserve_point": false,
		"handle_source": "manual",
		"handle_in": split["new_handle_in"],
		"handle_out": split["new_handle_out"]
	})
	edge["end_point_id"] = new_point_id
	var new_edge_id := next_id(edges, "edge")
	edges.append({
		"id": new_edge_id,
		"start_point_id": new_point_id,
		"end_point_id": end_id,
		"render_outline": bool(edge.get("render_outline", true))
	})
	point_ids.insert(start_index + 1, new_point_id)
	edge_ids.insert(edge_index + 1, new_edge_id)
	chain["point_ids"] = point_ids
	chain["edge_ids"] = edge_ids
	component["points"] = points
	component["edges"] = edges
	component["chains"] = chains
	return new_point_id


static func delete_point(component: Dictionary, point_id: String) -> bool:
	var points: Array = component.get("points", [])
	var edges: Array = component.get("edges", [])
	var chains: Array = component.get("chains", [])
	var chain := chain_for_point(chains, point_id)
	if chain.is_empty():
		return false
	var point_ids: Array = chain.get("point_ids", [])
	var chain_index := point_ids.find(point_id)
	var closed := bool(chain.get("closed", false))
	if chain_index < 0 or (closed and point_ids.size() <= 3):
		return false
	var edge_ids: Array = chain.get("edge_ids", [])
	var previous_edge_index := posmod(chain_index - 1, edge_ids.size()) if closed and not edge_ids.is_empty() else chain_index - 1
	var next_edge_index := chain_index
	var removed_edge_ids: Array[String] = []
	if previous_edge_index >= 0 and previous_edge_index < edge_ids.size():
		removed_edge_ids.append(str(edge_ids[previous_edge_index]))
	if next_edge_index >= 0 and next_edge_index < edge_ids.size():
		var next_edge_id := str(edge_ids[next_edge_index])
		if next_edge_id not in removed_edge_ids:
			removed_edge_ids.append(next_edge_id)
	var previous_id := str(point_ids[chain_index - 1]) if chain_index > 0 else (str(point_ids.back()) if closed else "")
	var next_id_value := str(point_ids[chain_index + 1]) if chain_index < point_ids.size() - 1 else (str(point_ids.front()) if closed else "")
	if not previous_id.is_empty() and not next_id_value.is_empty():
		edges.append({
			"id": next_id(edges, "edge"),
			"start_point_id": previous_id,
			"end_point_id": next_id_value,
			"render_outline": _combined_outline_visibility(edges, removed_edge_ids)
		})
	for edge_index in range(edges.size() - 1, -1, -1):
		if str(edges[edge_index].get("id", "")) in removed_edge_ids:
			edges.remove_at(edge_index)
	for point_index in range(points.size() - 1, -1, -1):
		if str(points[point_index].get("id", "")) == point_id:
			points.remove_at(point_index)
			break
	point_ids.remove_at(chain_index)
	chain["point_ids"] = point_ids
	chain["edge_ids"] = _ordered_edge_ids(point_ids, edges, closed)
	component["points"] = points
	component["edges"] = edges
	component["chains"] = chains
	BezierGeometry.resolve_auto_handles(points, chains)
	return true


static func delete_points(component: Dictionary, point_ids_to_delete: Array) -> Array[String]:
	var deleted: Array[String] = []
	for point_id_value in point_ids_to_delete:
		var point_id := str(point_id_value)
		if point_id not in deleted and delete_point(component, point_id):
			deleted.append(point_id)
	return deleted


static func validate(component: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var points: Array = component.get("points", [])
	var edges: Array = component.get("edges", [])
	var chains: Array = component.get("chains", [])
	var point_ids: Dictionary = {}
	for point_data in points:
		if not point_data is Dictionary:
			errors.append("Point entries must be dictionaries.")
			continue
		var point_id := str(point_data.get("id", ""))
		if point_id.is_empty() or point_ids.has(point_id):
			errors.append("Point IDs must be non-empty and unique.")
		point_ids[point_id] = true
		if str(point_data.get("mode", "linear")) not in VALID_POINT_MODES:
			errors.append("Point %s has an invalid mode." % point_id)
	var edge_ids: Dictionary = {}
	for edge_data in edges:
		if not edge_data is Dictionary:
			errors.append("Edge entries must be dictionaries.")
			continue
		var edge_id := str(edge_data.get("id", ""))
		if edge_id.is_empty() or edge_ids.has(edge_id):
			errors.append("Edge IDs must be non-empty and unique.")
		edge_ids[edge_id] = edge_data
		if not point_ids.has(str(edge_data.get("start_point_id", ""))) or not point_ids.has(str(edge_data.get("end_point_id", ""))):
			errors.append("Edge %s references a missing point." % edge_id)
	for chain_data in chains:
		if not chain_data is Dictionary:
			errors.append("Chain entries must be dictionaries.")
			continue
		var chain_point_ids: Array = chain_data.get("point_ids", [])
		var chain_edge_ids: Array = chain_data.get("edge_ids", [])
		var closed := bool(chain_data.get("closed", false))
		if closed and chain_point_ids.size() < 3:
			errors.append("A closed chain needs at least three points.")
		var expected_edge_count := chain_point_ids.size() if closed else maxi(chain_point_ids.size() - 1, 0)
		if chain_edge_ids.size() != expected_edge_count:
			errors.append("Chain edge count does not match its point order.")
		for point_id_value in chain_point_ids:
			if not point_ids.has(str(point_id_value)):
				errors.append("Chain references a missing point.")
		for chain_edge_index in range(mini(chain_edge_ids.size(), expected_edge_count)):
			var edge_id := str(chain_edge_ids[chain_edge_index])
			if not edge_ids.has(edge_id):
				errors.append("Chain references a missing edge.")
				continue
			var edge: Dictionary = edge_ids[edge_id]
			var expected_start := str(chain_point_ids[chain_edge_index])
			var expected_end := str(chain_point_ids[(chain_edge_index + 1) % chain_point_ids.size()])
			if str(edge.get("start_point_id", "")) != expected_start or str(edge.get("end_point_id", "")) != expected_end:
				errors.append("Chain edge order is inconsistent.")
	return errors


static func _combined_outline_visibility(edges: Array, edge_ids: Array[String]) -> bool:
	var visible := true
	for edge_data in edges:
		if edge_data is Dictionary and str(edge_data.get("id", "")) in edge_ids:
			visible = visible and bool(edge_data.get("render_outline", true))
	return visible


static func _ordered_edge_ids(point_ids: Array, edges: Array, closed: bool) -> Array:
	var ordered_ids: Array = []
	var edge_count := point_ids.size() if closed else maxi(point_ids.size() - 1, 0)
	for point_index in range(edge_count):
		var start_id := str(point_ids[point_index])
		var end_id := str(point_ids[(point_index + 1) % point_ids.size()])
		for edge_data in edges:
			if edge_data is Dictionary and str(edge_data.get("start_point_id", "")) == start_id and str(edge_data.get("end_point_id", "")) == end_id:
				ordered_ids.append(str(edge_data.get("id", "")))
				break
	return ordered_ids
