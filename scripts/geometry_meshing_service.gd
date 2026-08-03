class_name GeometryMeshingService
extends RefCounted

const CONSTRAINED_DELAUNAY := "constrained_delaunay"
const ORGANIC_RELAXED := "organic_relaxed"
const VALID_METHODS := [CONSTRAINED_DELAUNAY, ORGANIC_RELAXED]
const DEFAULT_RELAXATION := 0.35
const DEFAULT_PASSES := 2
const MAX_PASSES := 8
const MAX_VERTICES := 40000
const EPSILON := 0.000001


static func default_recipe() -> Dictionary:
	return {
		"method": CONSTRAINED_DELAUNAY,
		"parameters": {
			"seeding_method": GeometrySeedingService.POISSON_FILL
		}
	}


static func normalize_recipe(raw_recipe) -> Dictionary:
	var recipe := default_recipe()
	if not raw_recipe is Dictionary:
		return recipe
	var method := str(raw_recipe.get("method", CONSTRAINED_DELAUNAY))
	recipe["method"] = method if method in VALID_METHODS else CONSTRAINED_DELAUNAY
	var parameters = raw_recipe.get("parameters", {})
	var seeding_method := str(parameters.get("seeding_method", GeometrySeedingService.POISSON_FILL)) if parameters is Dictionary else GeometrySeedingService.POISSON_FILL
	if seeding_method not in GeometrySeedingService.VALID_METHODS:
		seeding_method = GeometrySeedingService.POISSON_FILL
	recipe["parameters"] = {"seeding_method": seeding_method}
	if recipe["method"] == ORGANIC_RELAXED:
		recipe["parameters"]["relaxation"] = clampf(float(parameters.get("relaxation", DEFAULT_RELAXATION)), 0.0, 1.0) if parameters is Dictionary else DEFAULT_RELAXATION
		recipe["parameters"]["passes"] = clampi(int(parameters.get("passes", DEFAULT_PASSES)), 1, MAX_PASSES) if parameters is Dictionary else DEFAULT_PASSES
	return recipe


static func generate(sampling_bake: Dictionary, seeding_bake: Dictionary, raw_recipe = {}) -> Dictionary:
	var recipe := normalize_recipe(raw_recipe)
	var errors := validation_issues(sampling_bake, seeding_bake, recipe)
	if not errors.is_empty():
		return _failed_result(sampling_bake, seeding_bake, recipe, errors)
	var vertices := _source_vertices(sampling_bake, seeding_bake)
	var constraints := _boundary_constraints(sampling_bake)
	var triangulation := _triangulate(vertices, constraints, sampling_bake)
	if not bool(triangulation.get("valid", false)):
		return _failed_result(sampling_bake, seeding_bake, recipe, triangulation.get("errors", []))
	var triangles: Array = triangulation.get("triangles", [])
	if str(recipe["method"]) == ORGANIC_RELAXED:
		for _pass_index in range(int(recipe["parameters"]["passes"])):
			_relax_interior_vertices(vertices, triangles, sampling_bake, float(recipe["parameters"]["relaxation"]))
			triangulation = _triangulate(vertices, constraints, sampling_bake)
			if not bool(triangulation.get("valid", false)):
				return _failed_result(sampling_bake, seeding_bake, recipe, triangulation.get("errors", []))
			triangles = triangulation.get("triangles", [])
	var minimum_angle := _minimum_triangle_angle(vertices, triangles)
	return {
		"valid": true,
		"errors": [],
		"method": recipe["method"],
		"parameters": recipe["parameters"].duplicate(true),
		"sampling_bake_id": str(sampling_bake.get("bake_id", "")),
		"sampling_fingerprint": GeometrySeedingService.sampling_fingerprint(sampling_bake),
		"seeding_bake_id": str(seeding_bake.get("bake_id", "")),
		"seeding_fingerprint": seeding_fingerprint(seeding_bake),
		"vertices": vertices,
		"triangles": triangles,
		"boundary_constraints": constraints,
		"vertex_count": vertices.size(),
		"triangle_count": triangles.size(),
		"minimum_angle": minimum_angle
	}


static func validation_issues(sampling_bake: Dictionary, seeding_bake: Dictionary, recipe: Dictionary = {}) -> Array[String]:
	var errors: Array[String] = []
	if sampling_bake.is_empty() or not bool(sampling_bake.get("valid", false)):
		errors.append("Meshing requires the Sampling Bake referenced by Seeding.")
		return errors
	if seeding_bake.is_empty() or not bool(seeding_bake.get("valid", false)):
		errors.append("Meshing requires a valid Seeding Bake.")
		return errors
	if str(sampling_bake.get("bake_id", "")).is_empty() or str(seeding_bake.get("bake_id", "")).is_empty():
		errors.append("Meshing inputs need stable Bake IDs.")
	if str(seeding_bake.get("sampling_bake_id", "")) != str(sampling_bake.get("bake_id", "")) \
		or str(seeding_bake.get("sampling_fingerprint", "")) != GeometrySeedingService.sampling_fingerprint(sampling_bake):
		errors.append("The Seeding Bake no longer matches its Sampling Bake.")
	var normalized := normalize_recipe(recipe)
	if str(seeding_bake.get("method", "")) != str(normalized.get("parameters", {}).get("seeding_method", "")):
		errors.append("The selected Seeding source is unavailable.")
	var boundaries := GeometrySeedingService.boundary_polygons(sampling_bake)
	if PackedVector2Array(boundaries.get("outer", PackedVector2Array())).size() < 3:
		errors.append("Meshing requires one sampled outer boundary.")
	var source_count := int(sampling_bake.get("sample_count", 0)) + int(seeding_bake.get("seed_count", 0))
	if source_count > MAX_VERTICES:
		errors.append("Meshing exceeded the safety limit of %d Vertices." % MAX_VERTICES)
	return errors


static func seeding_fingerprint(seeding_bake: Dictionary) -> String:
	var parts := PackedStringArray([
		str(seeding_bake.get("bake_id", "")),
		str(seeding_bake.get("method", "")),
		str(seeding_bake.get("sampling_bake_id", "")),
		str(seeding_bake.get("sampling_fingerprint", ""))
	])
	for seed_data in seeding_bake.get("seeds", []):
		if seed_data is Dictionary:
			var position := Vector2(seed_data.get("position", Vector2.ZERO))
			parts.append("%s|%.9f|%.9f|%s" % [str(seed_data.get("id", "")), position.x, position.y, str(seed_data.get("origin", "generated"))])
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update("\n".join(parts).to_utf8_buffer())
	return context.finish().hex_encode()


static func _source_vertices(sampling_bake: Dictionary, seeding_bake: Dictionary) -> Array:
	var vertices: Array = []
	for chain_data in sampling_bake.get("chains", []):
		if not chain_data is Dictionary:
			continue
		for sample in chain_data.get("samples", []):
			if sample is Dictionary:
				vertices.append({
					"id": "vertex:boundary:%s" % str(sample.get("id", "")),
					"position": Vector2(sample.get("position", Vector2.ZERO)),
					"origin": "boundary",
					"source_id": str(sample.get("id", "")),
					"preserved": bool(sample.get("preserved", false))
				})
	for seed_data in seeding_bake.get("seeds", []):
		if seed_data is Dictionary:
			vertices.append({
				"id": "vertex:seed:%s" % str(seed_data.get("id", "")),
				"position": Vector2(seed_data.get("position", Vector2.ZERO)),
				"origin": "seed",
				"source_id": str(seed_data.get("id", "")),
				"preserved": false
			})
	return vertices


static func _boundary_constraints(sampling_bake: Dictionary) -> Array:
	var constraints: Array = []
	for chain_data in sampling_bake.get("chains", []):
		if not chain_data is Dictionary or not bool(chain_data.get("closed", false)):
			continue
		var samples: Array = chain_data.get("samples", [])
		for sample_index in range(samples.size()):
			constraints.append({
				"chain_id": str(chain_data.get("chain_id", "")),
				"topology_role": str(chain_data.get("topology_role", "outer")),
				"vertex_ids": [
					"vertex:boundary:%s" % str(samples[sample_index].get("id", "")),
					"vertex:boundary:%s" % str(samples[(sample_index + 1) % samples.size()].get("id", ""))
				]
			})
	return constraints


static func _triangulate(vertices: Array, constraints: Array, sampling_bake: Dictionary) -> Dictionary:
	var positions := PackedVector2Array()
	var id_to_index: Dictionary = {}
	for vertex_index in range(vertices.size()):
		var position := Vector2(vertices[vertex_index].get("position", Vector2.ZERO))
		for existing in positions:
			if position.distance_squared_to(existing) <= EPSILON * EPSILON:
				return {"valid": false, "errors": ["Meshing inputs contain coincident Vertices."]}
		positions.append(position)
		id_to_index[str(vertices[vertex_index].get("id", ""))] = vertex_index
	var raw_indices := Geometry2D.triangulate_delaunay(positions)
	if raw_indices.is_empty():
		return {"valid": false, "errors": ["The selected inputs could not be triangulated."]}
	var raw_triangles: Array = []
	for raw_index in range(0, raw_indices.size(), 3):
		raw_triangles.append([int(raw_indices[raw_index]), int(raw_indices[raw_index + 1]), int(raw_indices[raw_index + 2])])
	var constraint_indices: Array = []
	for constraint in constraints:
		var ids: Array = constraint.get("vertex_ids", [])
		if ids.size() == 2 and id_to_index.has(str(ids[0])) and id_to_index.has(str(ids[1])):
			constraint_indices.append([int(id_to_index[str(ids[0])]), int(id_to_index[str(ids[1])])])
	var recovery := _recover_constraints(raw_triangles, constraint_indices, positions)
	if not bool(recovery.get("valid", false)):
		return recovery
	raw_triangles = recovery.get("triangles", [])
	var triangles: Array = []
	for raw_triangle in raw_triangles:
		var indices: Array = raw_triangle.duplicate()
		var a := positions[indices[0]]
		var b := positions[indices[1]]
		var c := positions[indices[2]]
		if absf((b - a).cross(c - a)) <= EPSILON:
			continue
		var centroid := (a + b + c) / 3.0
		if not GeometrySeedingService.point_is_inside(sampling_bake, centroid):
			continue
		if not _triangle_respects_boundary(indices, positions, constraint_indices, sampling_bake):
			continue
		if (b - a).cross(c - a) < 0.0:
			var swap: int = indices[1]
			indices[1] = indices[2]
			indices[2] = swap
		triangles.append({"vertex_ids": [str(vertices[indices[0]].get("id", "")), str(vertices[indices[1]].get("id", "")), str(vertices[indices[2]].get("id", ""))]})
	if triangles.is_empty():
		return {"valid": false, "errors": ["No valid Triangles remain inside the sampled boundary."]}
	return {"valid": true, "errors": [], "triangles": triangles}


static func _recover_constraints(raw_triangles: Array, constraints: Array, positions: PackedVector2Array) -> Dictionary:
	var triangles := raw_triangles.duplicate(true)
	var fixed_edges: Dictionary = {}
	for constraint in constraints:
		var first := int(constraint[0])
		var second := int(constraint[1])
		var constraint_key := _edge_key(first, second)
		var attempts := 0
		while not _triangles_have_edge(triangles, first, second):
			attempts += 1
			if attempts > triangles.size() * 4 + 16:
				return {"valid": false, "errors": ["A sampled Boundary constraint could not be recovered."]}
			var edge_map := _triangle_edge_map(triangles)
			var flipped := false
			for edge_key in edge_map:
				if fixed_edges.has(edge_key):
					continue
				var edge_data: Dictionary = edge_map[edge_key]
				var edge_vertices: Array = edge_data.get("vertices", [])
				var owners: Array = edge_data.get("triangles", [])
				if edge_vertices.size() != 2 or owners.size() != 2:
					continue
				var edge_first := int(edge_vertices[0])
				var edge_second := int(edge_vertices[1])
				if edge_first in [first, second] or edge_second in [first, second]:
					continue
				if not _segments_properly_intersect(positions[first], positions[second], positions[edge_first], positions[edge_second]):
					continue
				var first_owner := int(owners[0])
				var second_owner := int(owners[1])
				var opposite_first := _triangle_opposite_vertex(triangles[first_owner], edge_first, edge_second)
				var opposite_second := _triangle_opposite_vertex(triangles[second_owner], edge_first, edge_second)
				if opposite_first < 0 or opposite_second < 0 \
					or not _segments_properly_intersect(positions[edge_first], positions[edge_second], positions[opposite_first], positions[opposite_second]):
					continue
				var replacement_key := _edge_key(opposite_first, opposite_second)
				if fixed_edges.has(replacement_key) or _edge_crosses_fixed_constraints(opposite_first, opposite_second, fixed_edges, positions):
					continue
				triangles[first_owner] = [opposite_first, opposite_second, edge_first]
				triangles[second_owner] = [opposite_second, opposite_first, edge_second]
				flipped = true
				break
			if not flipped:
				return {"valid": false, "errors": ["A sampled Boundary constraint could not be recovered."]}
		fixed_edges[constraint_key] = [first, second]
	return {"valid": true, "errors": [], "triangles": triangles}


static func _triangle_edge_map(triangles: Array) -> Dictionary:
	var edge_map: Dictionary = {}
	for triangle_index in range(triangles.size()):
		var triangle: Array = triangles[triangle_index]
		for slot in range(3):
			var first := int(triangle[slot])
			var second := int(triangle[(slot + 1) % 3])
			var key := _edge_key(first, second)
			if not edge_map.has(key):
				edge_map[key] = {"vertices": [first, second], "triangles": []}
			edge_map[key]["triangles"].append(triangle_index)
	return edge_map


static func _triangles_have_edge(triangles: Array, first: int, second: int) -> bool:
	var key := _edge_key(first, second)
	for triangle in triangles:
		for slot in range(3):
			if _edge_key(int(triangle[slot]), int(triangle[(slot + 1) % 3])) == key:
				return true
	return false


static func _triangle_opposite_vertex(triangle: Array, first: int, second: int) -> int:
	for vertex in triangle:
		if int(vertex) != first and int(vertex) != second:
			return int(vertex)
	return -1


static func _edge_crosses_fixed_constraints(first: int, second: int, fixed_edges: Dictionary, positions: PackedVector2Array) -> bool:
	for constraint in fixed_edges.values():
		var c_first := int(constraint[0])
		var c_second := int(constraint[1])
		if first in [c_first, c_second] or second in [c_first, c_second]:
			continue
		if _segments_properly_intersect(positions[first], positions[second], positions[c_first], positions[c_second]):
			return true
	return false


static func _edge_key(first: int, second: int) -> String:
	return "%d:%d" % [mini(first, second), maxi(first, second)]


static func _triangle_respects_boundary(indices: Array, positions: PackedVector2Array, constraints: Array, sampling_bake: Dictionary) -> bool:
	for edge_slot in range(3):
		var first := int(indices[edge_slot])
		var second := int(indices[(edge_slot + 1) % 3])
		var midpoint := (positions[first] + positions[second]) * 0.5
		if not GeometrySeedingService.point_is_inside(sampling_bake, midpoint) and not _point_on_any_constraint(midpoint, positions, constraints):
			return false
		for constraint in constraints:
			var c_first := int(constraint[0])
			var c_second := int(constraint[1])
			if first in [c_first, c_second] or second in [c_first, c_second]:
				continue
			if _segments_properly_intersect(positions[first], positions[second], positions[c_first], positions[c_second]):
				return false
	return true


static func _point_on_any_constraint(position: Vector2, positions: PackedVector2Array, constraints: Array) -> bool:
	for constraint in constraints:
		var closest := Geometry2D.get_closest_point_to_segment(position, positions[int(constraint[0])], positions[int(constraint[1])])
		if closest.distance_squared_to(position) <= EPSILON * EPSILON:
			return true
	return false


static func _segments_properly_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab_c := (b - a).cross(c - a)
	var ab_d := (b - a).cross(d - a)
	var cd_a := (d - c).cross(a - c)
	var cd_b := (d - c).cross(b - c)
	return ab_c * ab_d < -EPSILON and cd_a * cd_b < -EPSILON


static func _relax_interior_vertices(vertices: Array, triangles: Array, sampling_bake: Dictionary, strength: float) -> void:
	if strength <= 0.0:
		return
	var by_id: Dictionary = {}
	var neighbors: Dictionary = {}
	for vertex_index in range(vertices.size()):
		var vertex_id := str(vertices[vertex_index].get("id", ""))
		by_id[vertex_id] = vertex_index
		neighbors[vertex_id] = {}
	for triangle in triangles:
		var ids: Array = triangle.get("vertex_ids", [])
		for slot in range(ids.size()):
			neighbors[str(ids[slot])][str(ids[(slot + 1) % ids.size()])] = true
			neighbors[str(ids[slot])][str(ids[(slot + 2) % ids.size()])] = true
	var next_positions: Dictionary = {}
	for vertex in vertices:
		if str(vertex.get("origin", "")) != "seed":
			continue
		var vertex_id := str(vertex.get("id", ""))
		var adjacent: Dictionary = neighbors.get(vertex_id, {})
		if adjacent.is_empty():
			continue
		var centroid := Vector2.ZERO
		for neighbor_id in adjacent:
			centroid += Vector2(vertices[int(by_id[neighbor_id])].get("position", Vector2.ZERO))
		centroid /= float(adjacent.size())
		var candidate := Vector2(vertex.get("position", Vector2.ZERO)).lerp(centroid, strength)
		if GeometrySeedingService.point_is_valid(sampling_bake, candidate, EPSILON):
			next_positions[vertex_id] = candidate
	for vertex in vertices:
		var vertex_id := str(vertex.get("id", ""))
		if next_positions.has(vertex_id):
			vertex["position"] = next_positions[vertex_id]


static func _minimum_triangle_angle(vertices: Array, triangles: Array) -> float:
	var by_id: Dictionary = {}
	for vertex in vertices:
		by_id[str(vertex.get("id", ""))] = Vector2(vertex.get("position", Vector2.ZERO))
	var minimum := 180.0
	for triangle in triangles:
		var ids: Array = triangle.get("vertex_ids", [])
		if ids.size() != 3:
			continue
		var a: Vector2 = by_id.get(str(ids[0]), Vector2.ZERO)
		var b: Vector2 = by_id.get(str(ids[1]), Vector2.ZERO)
		var c: Vector2 = by_id.get(str(ids[2]), Vector2.ZERO)
		minimum = minf(minimum, _angle_degrees(b - a, c - a))
		minimum = minf(minimum, _angle_degrees(a - b, c - b))
		minimum = minf(minimum, _angle_degrees(a - c, b - c))
	return 0.0 if minimum == 180.0 else minimum


static func _angle_degrees(first: Vector2, second: Vector2) -> float:
	if first.length_squared() <= EPSILON or second.length_squared() <= EPSILON:
		return 0.0
	return rad_to_deg(acos(clampf(first.normalized().dot(second.normalized()), -1.0, 1.0)))


static func _failed_result(sampling_bake: Dictionary, seeding_bake: Dictionary, recipe: Dictionary, errors: Array) -> Dictionary:
	return {
		"valid": false,
		"errors": errors,
		"method": recipe["method"],
		"parameters": recipe["parameters"].duplicate(true),
		"sampling_bake_id": str(sampling_bake.get("bake_id", "")),
		"sampling_fingerprint": GeometrySeedingService.sampling_fingerprint(sampling_bake),
		"seeding_bake_id": str(seeding_bake.get("bake_id", "")),
		"seeding_fingerprint": seeding_fingerprint(seeding_bake),
		"vertices": [],
		"triangles": [],
		"boundary_constraints": [],
		"vertex_count": 0,
		"triangle_count": 0,
		"minimum_angle": 0.0
	}
