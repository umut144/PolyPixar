class_name GeometrySeedingService
extends RefCounted

const POISSON_FILL := "poisson_fill"
const SPINE_FLOW := "spine_flow"
const VALID_METHODS := [POISSON_FILL, SPINE_FLOW]
const DEFAULT_SPACING := 2.0
const DEFAULT_SEED := 1
const DEFAULT_ALONG_SPACING := 2.0
const DEFAULT_ACROSS_SPACING := 2.0
const DEFAULT_BOUNDARY_CLEARANCE := 0.5
const DEFAULT_STAGGER := 0.5
const DEFAULT_FILL_GAPS := true
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
	if recipe["method"] == SPINE_FLOW:
		recipe["parameters"] = {
			"guide_id": str(parameters.get("guide_id", "")) if parameters is Dictionary else "",
			"along_spacing": maxf(float(parameters.get("along_spacing", DEFAULT_ALONG_SPACING)), MIN_SPACING) if parameters is Dictionary else DEFAULT_ALONG_SPACING,
			"across_spacing": maxf(float(parameters.get("across_spacing", DEFAULT_ACROSS_SPACING)), MIN_SPACING) if parameters is Dictionary else DEFAULT_ACROSS_SPACING,
			"boundary_clearance": maxf(float(parameters.get("boundary_clearance", DEFAULT_BOUNDARY_CLEARANCE)), 0.0) if parameters is Dictionary else DEFAULT_BOUNDARY_CLEARANCE,
			"stagger": clampf(float(parameters.get("stagger", DEFAULT_STAGGER)), 0.0, 1.0) if parameters is Dictionary else DEFAULT_STAGGER,
			"fill_gaps": bool(parameters.get("fill_gaps", DEFAULT_FILL_GAPS)) if parameters is Dictionary else DEFAULT_FILL_GAPS,
			"seed": maxi(0, int(parameters.get("seed", DEFAULT_SEED))) if parameters is Dictionary else DEFAULT_SEED
		}
	elif parameters is Dictionary:
		recipe["parameters"]["spacing"] = maxf(float(parameters.get("spacing", DEFAULT_SPACING)), MIN_SPACING)
		recipe["parameters"]["seed"] = maxi(0, int(parameters.get("seed", DEFAULT_SEED)))
	return recipe


static func generate(sampling_bake: Dictionary, raw_recipe = {}, guide: Dictionary = {}) -> Dictionary:
	var recipe := normalize_recipe(raw_recipe)
	var errors := validation_issues(sampling_bake, recipe, guide)
	if not errors.is_empty():
		return _failed_result(recipe, sampling_bake, guide, errors)
	var boundaries := boundary_polygons(sampling_bake)
	var outer: PackedVector2Array = boundaries.get("outer", PackedVector2Array())
	var holes: Array = boundaries.get("holes", [])
	var positions: Array[Vector2] = []
	var flow_count := 0
	if str(recipe["method"]) == SPINE_FLOW:
		positions = _spine_flow_positions(outer, holes, guide, recipe["parameters"])
		flow_count = positions.size()
		if bool(recipe["parameters"]["fill_gaps"]):
			var gap_spacing := minf(float(recipe["parameters"]["along_spacing"]), float(recipe["parameters"]["across_spacing"]))
			positions = _poisson_positions(outer, holes, gap_spacing, float(recipe["parameters"]["boundary_clearance"]), int(recipe["parameters"]["seed"]), positions)
	else:
		var spacing := float(recipe["parameters"]["spacing"])
		positions = _poisson_positions(outer, holes, spacing, spacing * 0.5, int(recipe["parameters"]["seed"]))
	var seeds: Array = []
	for seed_index in range(positions.size()):
		var placement := "poisson" if str(recipe["method"]) == POISSON_FILL else "flow" if seed_index < flow_count else "gap_fill"
		seeds.append({
			"id": "seed:auto:%06d" % (seed_index + 1),
			"position": positions[seed_index],
			"origin": "generated",
			"method": recipe["method"],
			"provenance": {"generation_index": seed_index, "placement": placement}
		})
	return {
		"valid": true,
		"errors": [],
		"method": recipe["method"],
		"parameters": recipe["parameters"].duplicate(true),
		"sampling_bake_id": str(sampling_bake.get("bake_id", "")),
		"sampling_fingerprint": sampling_fingerprint(sampling_bake),
		"guide_id": str(guide.get("id", "")) if str(recipe["method"]) == SPINE_FLOW else "",
		"guide_fingerprint": guide_fingerprint(guide) if str(recipe["method"]) == SPINE_FLOW else "",
		"seeds": seeds,
		"seed_count": seeds.size(),
		"edited": false
	}


static func validation_issues(sampling_bake: Dictionary, recipe: Dictionary = {}, guide: Dictionary = {}) -> Array[String]:
	var errors: Array[String] = []
	if sampling_bake.is_empty() or not bool(sampling_bake.get("valid", false)):
		errors.append("Seeding requires a valid Sampling Bake.")
		return errors
	if str(sampling_bake.get("bake_id", "")).is_empty():
		errors.append("The Sampling Bake has no stable Bake ID.")
	var boundaries := boundary_polygons(sampling_bake)
	var outer: PackedVector2Array = boundaries.get("outer", PackedVector2Array())
	var holes: Array = boundaries.get("holes", [])
	if outer.size() < 3:
		errors.append("Seeding requires one sampled outer boundary with at least three Points.")
	if str(recipe.get("method", POISSON_FILL)) == SPINE_FLOW:
		if guide.is_empty() or str(guide.get("guide_type", "")) != AssetGuide.SAMPLER_SPINE:
			errors.append("Spine Flow requires a Sampler Spine from this Component.")
		elif str(recipe.get("parameters", {}).get("guide_id", "")) != str(guide.get("id", "")):
			errors.append("The selected Sampler Spine is unavailable.")
		elif guide.get("points", []).size() < 2 or guide.get("chains", []).size() != 1:
			errors.append("Spine Flow requires one authored open Sampler Spine with at least two Points.")
		else:
			var guide_polyline := _guide_polyline(guide)
			var boundary_tolerance := maxf(0.0001, float(sampling_bake.get("parameters", {}).get("spacing", 1.0)) * 0.25)
			for position in guide_polyline:
				if not _point_is_inside_or_on_boundary(position, outer, holes, boundary_tolerance):
					errors.append("The Sampler Spine curve must remain inside the sampled Component boundary.")
					break
	return errors


static func guide_fingerprint(guide: Dictionary) -> String:
	if guide.is_empty():
		return ""
	var parts := PackedStringArray([str(guide.get("id", "")), str(guide.get("guide_type", "")), str(guide.get("scope", {}).get("component_id", "")), GeometrySamplingService.source_fingerprint(guide)])
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update("\n".join(parts).to_utf8_buffer())
	return context.finish().hex_encode()


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


static func _spine_flow_positions(outer: PackedVector2Array, holes: Array, guide: Dictionary, parameters: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var polyline := _guide_polyline(guide)
	var stations := _resample_polyline(polyline, float(parameters["along_spacing"]))
	var across_spacing := float(parameters["across_spacing"])
	var boundary_clearance := float(parameters["boundary_clearance"])
	var stagger := float(parameters["stagger"])
	var minimum_distance := minf(float(parameters["along_spacing"]), across_spacing) * 0.32
	for station_index in range(stations.size()):
		var station: Dictionary = stations[station_index]
		var position: Vector2 = station["position"]
		var tangent: Vector2 = station["tangent"]
		if tangent.length_squared() <= 0.000001:
			continue
		var normal := Vector2(-tangent.y, tangent.x).normalized()
		var phase := 0.0 if station_index % 2 == 0 else stagger
		if is_zero_approx(phase) and _distance_to_boundaries(position, outer, holes) >= boundary_clearance:
			_append_spaced_position(result, position, minimum_distance)
		for direction_sign: float in [-1.0, 1.0]:
			var direction: Vector2 = normal * direction_sign
			var available := _ray_boundary_distance(position, direction, outer, holes) - boundary_clearance
			if available <= 0.0:
				continue
			var offset := across_spacing * (phase if phase > 0.0 else 1.0)
			while offset <= available + 0.000001 and result.size() < MAX_SEEDS:
				_append_spaced_position(result, position + direction * offset, minimum_distance)
				offset += across_spacing
	return result


static func _guide_polyline(guide: Dictionary) -> PackedVector2Array:
	if guide.get("chains", []).is_empty():
		return PackedVector2Array()
	var resolved := guide.duplicate(true)
	BezierGeometry.resolve_auto_handles(resolved.get("points", []), resolved.get("chains", []))
	return BezierGeometry.flatten_chain(resolved, resolved.get("chains", [])[0], 32)


static func _resample_polyline(polyline: PackedVector2Array, spacing: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if polyline.size() < 2:
		return result
	var cumulative: Array[float] = [0.0]
	for index in range(1, polyline.size()):
		cumulative.append(cumulative.back() + polyline[index - 1].distance_to(polyline[index]))
	var total_length: float = cumulative.back()
	if total_length <= 0.000001:
		return result
	var station_count := maxi(1, floori(total_length / spacing))
	for station_index in range(station_count + 1):
		var target_distance := minf(float(station_index) * spacing, total_length)
		if station_index == station_count:
			target_distance = total_length
		var segment_index := 0
		while segment_index + 1 < cumulative.size() and cumulative[segment_index + 1] < target_distance:
			segment_index += 1
		var segment_length := cumulative[segment_index + 1] - cumulative[segment_index]
		var t := 0.0 if segment_length <= 0.000001 else (target_distance - cumulative[segment_index]) / segment_length
		var tangent := polyline[segment_index + 1] - polyline[segment_index]
		result.append({"position": polyline[segment_index].lerp(polyline[segment_index + 1], t), "tangent": tangent.normalized()})
	return result


static func _ray_boundary_distance(origin: Vector2, direction: Vector2, outer: PackedVector2Array, holes: Array) -> float:
	var distance := _ray_polygon_distance(origin, direction, outer)
	for hole in holes:
		if hole is PackedVector2Array:
			distance = minf(distance, _ray_polygon_distance(origin, direction, hole))
	return distance


static func _ray_polygon_distance(origin: Vector2, direction: Vector2, polygon: PackedVector2Array) -> float:
	var nearest := INF
	for index in range(polygon.size()):
		var start := polygon[index]
		var segment := polygon[(index + 1) % polygon.size()] - start
		var denominator := direction.cross(segment)
		if is_zero_approx(denominator):
			continue
		var offset := start - origin
		var ray_t := offset.cross(segment) / denominator
		var segment_t := offset.cross(direction) / denominator
		if ray_t >= -0.000001 and segment_t >= -0.000001 and segment_t <= 1.000001:
			nearest = minf(nearest, maxf(ray_t, 0.0))
	return nearest


static func _append_spaced_position(positions: Array[Vector2], candidate: Vector2, minimum_distance: float) -> void:
	for existing in positions:
		if candidate.distance_squared_to(existing) < minimum_distance * minimum_distance:
			return
	positions.append(candidate)


static func _poisson_positions(outer: PackedVector2Array, holes: Array, spacing: float, clearance: float, random_seed: int, initial_positions: Array[Vector2] = []) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if outer.size() < 3:
		return result
	var bounds := _polygon_bounds(outer)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	for initial_position in initial_positions:
		if _point_is_inside_polygons(initial_position, outer, holes) and _distance_to_boundaries(initial_position, outer, holes) >= clearance:
			_append_spaced_position(result, initial_position, spacing)
	var first := bounds.get_center()
	if result.is_empty() and (not _point_is_inside_polygons(first, outer, holes) or _distance_to_boundaries(first, outer, holes) < clearance):
		var found_first := false
		for _attempt in range(512):
			var candidate := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
			if _point_is_inside_polygons(candidate, outer, holes) and _distance_to_boundaries(candidate, outer, holes) >= clearance:
				first = candidate
				found_first = true
				break
		if not found_first:
			return result
	if result.is_empty():
		result.append(first)
	var active: Array[int] = []
	var cell_size := spacing / sqrt(2.0)
	var grid: Dictionary = {}
	for result_index in range(result.size()):
		active.append(result_index)
		grid[_grid_key(result[result_index], bounds.position, cell_size)] = result_index
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


static func _point_is_inside_or_on_boundary(position: Vector2, outer: PackedVector2Array, holes: Array, tolerance := 0.0001) -> bool:
	if _distance_to_polygon(position, outer) <= tolerance:
		return true
	if not _point_is_inside_polygons(position, outer, holes):
		return false
	for hole in holes:
		if hole is PackedVector2Array and _distance_to_polygon(position, hole) <= 0.0001:
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


static func _failed_result(recipe: Dictionary, sampling_bake: Dictionary, guide: Dictionary, errors: Array[String]) -> Dictionary:
	return {
		"valid": false,
		"errors": errors,
		"method": recipe["method"],
		"parameters": recipe["parameters"].duplicate(true),
		"sampling_bake_id": str(sampling_bake.get("bake_id", "")),
		"sampling_fingerprint": sampling_fingerprint(sampling_bake),
		"guide_id": str(guide.get("id", "")) if str(recipe["method"]) == SPINE_FLOW else "",
		"guide_fingerprint": guide_fingerprint(guide) if str(recipe["method"]) == SPINE_FLOW else "",
		"seeds": [],
		"seed_count": 0,
		"edited": false
	}
