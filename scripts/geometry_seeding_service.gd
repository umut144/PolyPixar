class_name GeometrySeedingService
extends RefCounted

const POISSON_FILL := "poisson_fill"
const VALID_METHODS := [POISSON_FILL]
const DEFAULT_SPACING := 2.0
const DEFAULT_SEED := 1
const MIN_SPACING := 0.01
const MAX_SEEDS := 20000
const CANDIDATES_PER_ACTIVE_POINT := 30


static func default_recipe() -> Dictionary:
	return {
		"method": POISSON_FILL,
		"parameters": {
			"spacing": DEFAULT_SPACING,
			"seed": DEFAULT_SEED
		}
	}


static func normalize_recipe(raw_recipe) -> Dictionary:
	var recipe := default_recipe()
	if not raw_recipe is Dictionary:
		return recipe
	var method := str(raw_recipe.get("method", POISSON_FILL))
	recipe["method"] = method if method in VALID_METHODS else POISSON_FILL
	var parameters = raw_recipe.get("parameters", {})
	if parameters is Dictionary:
		recipe["parameters"]["spacing"] = maxf(float(parameters.get("spacing", DEFAULT_SPACING)), MIN_SPACING)
		recipe["parameters"]["seed"] = maxi(0, int(parameters.get("seed", DEFAULT_SEED)))
	return recipe


static func generate(sampling_bake: Dictionary, raw_recipe = {}) -> Dictionary:
	var recipe := normalize_recipe(raw_recipe)
	var errors := validation_issues(sampling_bake)
	if not errors.is_empty():
		return _failed_result(recipe, sampling_bake, errors)
	var boundaries := boundary_polygons(sampling_bake)
	var outer: PackedVector2Array = boundaries.get("outer", PackedVector2Array())
	var holes: Array = boundaries.get("holes", [])
	var spacing := float(recipe["parameters"]["spacing"])
	var clearance := spacing * 0.5
	var positions := _poisson_positions(outer, holes, spacing, clearance, int(recipe["parameters"]["seed"]))
	var seeds: Array = []
	for seed_index in range(positions.size()):
		seeds.append({
			"id": "seed:auto:%06d" % (seed_index + 1),
			"position": positions[seed_index],
			"origin": "generated",
			"method": POISSON_FILL,
			"provenance": {"generation_index": seed_index}
		})
	return {
		"valid": true,
		"errors": [],
		"method": recipe["method"],
		"parameters": recipe["parameters"].duplicate(true),
		"sampling_bake_id": str(sampling_bake.get("bake_id", "")),
		"sampling_fingerprint": sampling_fingerprint(sampling_bake),
		"seeds": seeds,
		"seed_count": seeds.size(),
		"edited": false
	}


static func validation_issues(sampling_bake: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if sampling_bake.is_empty() or not bool(sampling_bake.get("valid", false)):
		errors.append("Seeding requires a valid Sampling Bake.")
		return errors
	if str(sampling_bake.get("bake_id", "")).is_empty():
		errors.append("The Sampling Bake has no stable Bake ID.")
	var boundaries := boundary_polygons(sampling_bake)
	var outer: PackedVector2Array = boundaries.get("outer", PackedVector2Array())
	if outer.size() < 3:
		errors.append("Seeding requires one sampled outer boundary with at least three Points.")
	return errors


static func boundary_polygons(sampling_bake: Dictionary) -> Dictionary:
	var outer := PackedVector2Array()
	var holes: Array = []
	for chain_data in sampling_bake.get("chains", []):
		if not chain_data is Dictionary or not bool(chain_data.get("closed", false)):
			continue
		var polygon := PackedVector2Array()
		for sample in chain_data.get("samples", []):
			if sample is Dictionary:
				polygon.append(Vector2(sample.get("position", Vector2.ZERO)))
		var role := str(chain_data.get("topology_role", "outer"))
		if role == "outer" and outer.is_empty():
			outer = polygon
		elif role == "hole" and polygon.size() >= 3:
			holes.append(polygon)
	return {"outer": outer, "holes": holes}


static func point_is_inside(sampling_bake: Dictionary, position: Vector2) -> bool:
	var boundaries := boundary_polygons(sampling_bake)
	return _point_is_inside_polygons(position, boundaries.get("outer", PackedVector2Array()), boundaries.get("holes", []))


static func point_is_valid(sampling_bake: Dictionary, position: Vector2, clearance := 0.0001) -> bool:
	var boundaries := boundary_polygons(sampling_bake)
	var outer: PackedVector2Array = boundaries.get("outer", PackedVector2Array())
	var holes: Array = boundaries.get("holes", [])
	return _point_is_inside_polygons(position, outer, holes) and _distance_to_boundaries(position, outer, holes) >= maxf(clearance, 0.0)


static func sampling_fingerprint(sampling_bake: Dictionary) -> String:
	var parts: PackedStringArray = [str(sampling_bake.get("bake_id", ""))]
	for chain_data in sampling_bake.get("chains", []):
		if not chain_data is Dictionary:
			continue
		parts.append("c|%s|%s|%d" % [str(chain_data.get("chain_id", "")), str(chain_data.get("topology_role", "outer")), int(bool(chain_data.get("closed", false)))])
		for sample in chain_data.get("samples", []):
			if sample is Dictionary:
				var position: Vector2 = sample.get("position", Vector2.ZERO)
				parts.append("s|%s|%.9f|%.9f" % [str(sample.get("id", "")), position.x, position.y])
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	var payload := "\n".join(parts)
	context.update((payload if not payload.is_empty() else "empty").to_utf8_buffer())
	return context.finish().hex_encode()


static func _poisson_positions(outer: PackedVector2Array, holes: Array, spacing: float, clearance: float, random_seed: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if outer.size() < 3:
		return result
	var bounds := _polygon_bounds(outer)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var first := bounds.get_center()
	if not _point_is_inside_polygons(first, outer, holes) or _distance_to_boundaries(first, outer, holes) < clearance:
		var found_first := false
		for _attempt in range(512):
			var candidate := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
			if _point_is_inside_polygons(candidate, outer, holes) and _distance_to_boundaries(candidate, outer, holes) >= clearance:
				first = candidate
				found_first = true
				break
		if not found_first:
			return result
	result.append(first)
	var active: Array[int] = [0]
	var cell_size := spacing / sqrt(2.0)
	var grid: Dictionary = {_grid_key(first, bounds.position, cell_size): 0}
	while not active.is_empty() and result.size() < MAX_SEEDS:
		var active_list_index := rng.randi_range(0, active.size() - 1)
		var source_index := active[active_list_index]
		var source := result[source_index]
		var accepted := false
		for _candidate_index in range(CANDIDATES_PER_ACTIVE_POINT):
			var angle := rng.randf_range(0.0, TAU)
			var distance := spacing * rng.randf_range(1.0, 2.0)
			var candidate := source + Vector2.from_angle(angle) * distance
			if not bounds.has_point(candidate):
				continue
			if not _point_is_inside_polygons(candidate, outer, holes) or _distance_to_boundaries(candidate, outer, holes) < clearance:
				continue
			if not _has_poisson_clearance(candidate, result, grid, bounds.position, cell_size, spacing):
				continue
			var result_index := result.size()
			result.append(candidate)
			active.append(result_index)
			grid[_grid_key(candidate, bounds.position, cell_size)] = result_index
			accepted = true
			break
		if not accepted:
			active.remove_at(active_list_index)
	return result


static func _has_poisson_clearance(candidate: Vector2, positions: Array[Vector2], grid: Dictionary, origin: Vector2, cell_size: float, spacing: float) -> bool:
	var key := _grid_key(candidate, origin, cell_size)
	for y_offset in range(-2, 3):
		for x_offset in range(-2, 3):
			var neighbor_key := key + Vector2i(x_offset, y_offset)
			if not grid.has(neighbor_key):
				continue
			if candidate.distance_squared_to(positions[int(grid[neighbor_key])]) < spacing * spacing:
				return false
	return true


static func _grid_key(position: Vector2, origin: Vector2, cell_size: float) -> Vector2i:
	return Vector2i(floori((position.x - origin.x) / cell_size), floori((position.y - origin.y) / cell_size))


static func _point_is_inside_polygons(position: Vector2, outer: PackedVector2Array, holes: Array) -> bool:
	if outer.size() < 3 or not Geometry2D.is_point_in_polygon(position, outer):
		return false
	for hole in holes:
		if hole is PackedVector2Array and Geometry2D.is_point_in_polygon(position, hole):
			return false
	return true


static func _distance_to_boundaries(position: Vector2, outer: PackedVector2Array, holes: Array) -> float:
	var distance := _distance_to_polygon(position, outer)
	for hole in holes:
		if hole is PackedVector2Array:
			distance = minf(distance, _distance_to_polygon(position, hole))
	return distance


static func _distance_to_polygon(position: Vector2, polygon: PackedVector2Array) -> float:
	if polygon.size() < 2:
		return INF
	var distance := INF
	for point_index in range(polygon.size()):
		var closest := Geometry2D.get_closest_point_to_segment(position, polygon[point_index], polygon[(point_index + 1) % polygon.size()])
		distance = minf(distance, position.distance_to(closest))
	return distance


static func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for position in polygon:
		bounds = bounds.expand(position)
	return bounds


static func _failed_result(recipe: Dictionary, sampling_bake: Dictionary, errors: Array[String]) -> Dictionary:
	return {
		"valid": false,
		"errors": errors,
		"method": recipe["method"],
		"parameters": recipe["parameters"].duplicate(true),
		"sampling_bake_id": str(sampling_bake.get("bake_id", "")),
		"sampling_fingerprint": sampling_fingerprint(sampling_bake),
		"seeds": [],
		"seed_count": 0,
		"edited": false
	}
