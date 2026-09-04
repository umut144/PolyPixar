class_name GeometrySeedingService
extends RefCounted

const POISSON_FILL := "poisson_fill"
const SPINE_FLOW := "spine_flow"
const VALID_METHODS := [POISSON_FILL, SPINE_FLOW]
const ALGORITHM_VERSION := 2
const DEFAULT_SPACING := 2.0
const DEFAULT_SEED := 1
const DEFAULT_CONSTRAINT_CLEARANCE_FACTOR := 0.5
const DEFAULT_ALONG_SPACING := 2.0
const DEFAULT_ACROSS_SPACING := 2.0
const DEFAULT_BOUNDARY_CLEARANCE := 0.5
const DEFAULT_STAGGER := 0.5
const DEFAULT_FLOW_STRETCH := 1.0
const DEFAULT_ARTISTIC_STAGGER := 0.1
const DEFAULT_FILL_GAPS := true
const MIN_SPACING := 0.01
const MIN_FLOW_STRETCH := 0.25
const MAX_FLOW_STRETCH := 16.0
const MAX_SEEDS := 20000
const CANDIDATES_PER_ACTIVE_POINT := 30


static func default_recipe() -> Dictionary:
	return {"method": POISSON_FILL, "parameters": {"spacing": DEFAULT_SPACING, "constraint_clearance_factor": DEFAULT_CONSTRAINT_CLEARANCE_FACTOR, "seed": DEFAULT_SEED}}


static func normalize_recipe(raw_recipe) -> Dictionary:
	var recipe := default_recipe()
	if not raw_recipe is Dictionary:
		return recipe
	var method := str(raw_recipe.get("method", POISSON_FILL))
	recipe["method"] = method if method in VALID_METHODS else POISSON_FILL
	var parameters = raw_recipe.get("parameters", {})
	if not parameters is Dictionary:
		parameters = {}
	if recipe["method"] == SPINE_FLOW:
		var spine_inputs: Array = []
		var raw_inputs = parameters.get("spine_inputs", [])
		if raw_inputs is Array:
			for raw_input in raw_inputs:
				if not raw_input is Dictionary:
					continue
				var guide_id := str(raw_input.get("guide_id", ""))
				if guide_id.is_empty() or _spine_input_index(spine_inputs, guide_id) >= 0:
					continue
				spine_inputs.append({"guide_id": guide_id, "enabled": bool(raw_input.get("enabled", true))})
		# Schema-29 migration: one guide_id becomes one enabled spine input.
		var legacy_guide_id := str(parameters.get("guide_id", ""))
		if spine_inputs.is_empty() and not legacy_guide_id.is_empty():
			spine_inputs.append({"guide_id": legacy_guide_id, "enabled": true})
		# Artistic controls derive the exact lattice values. Recipes written before
		# these controls preserve their explicit clearance and stagger as overrides.
		var legacy_across := maxf(float(parameters.get("across_spacing", DEFAULT_ACROSS_SPACING)), MIN_SPACING)
		var legacy_along := maxf(float(parameters.get("along_spacing", DEFAULT_ALONG_SPACING)), MIN_SPACING)
		var spacing := maxf(float(parameters.get("spacing", legacy_across)), MIN_SPACING)
		var flow_stretch := clampf(float(parameters.get("flow_stretch", legacy_along / legacy_across)), MIN_FLOW_STRETCH, MAX_FLOW_STRETCH)
		var boundary_override := bool(parameters.get("boundary_clearance_override", parameters.has("boundary_clearance")))
		var stagger_override := bool(parameters.get("stagger_override", parameters.has("stagger")))
		var boundary_clearance := maxf(float(parameters.get("boundary_clearance", DEFAULT_BOUNDARY_CLEARANCE)), 0.0) if boundary_override else spacing * DEFAULT_CONSTRAINT_CLEARANCE_FACTOR
		var stagger := clampf(float(parameters.get("stagger", DEFAULT_STAGGER)), 0.0, 1.0) if stagger_override else DEFAULT_ARTISTIC_STAGGER
		recipe["parameters"] = {
			"spine_inputs": spine_inputs,
			"spacing": spacing,
			"flow_stretch": flow_stretch,
			"along_spacing": spacing * flow_stretch,
			"across_spacing": spacing,
			"boundary_clearance_override": boundary_override,
			"boundary_clearance": boundary_clearance,
			"stagger_override": stagger_override,
			"stagger": stagger,
			"fill_gaps": bool(parameters.get("fill_gaps", DEFAULT_FILL_GAPS)),
			"seed": maxi(0, int(parameters.get("seed", DEFAULT_SEED)))
		}
	else:
		recipe["parameters"]["spacing"] = maxf(float(parameters.get("spacing", DEFAULT_SPACING)), MIN_SPACING)
		recipe["parameters"]["constraint_clearance_factor"] = maxf(float(parameters.get("constraint_clearance_factor", DEFAULT_CONSTRAINT_CLEARANCE_FACTOR)), 0.0)
		recipe["parameters"]["seed"] = maxi(0, int(parameters.get("seed", DEFAULT_SEED)))
	return recipe


static func generate(sampling_bake: Dictionary, raw_recipe = {}, raw_guides = []) -> Dictionary:
	var recipe := normalize_recipe(raw_recipe)
	var guides := _guide_array(raw_guides)
	var errors := validation_issues(sampling_bake, recipe, guides)
	if not errors.is_empty():
		return _failed_result(recipe, sampling_bake, guides, errors)
	var domain := constraint_domain(sampling_bake)
	var placements: Array[Dictionary] = []
	var guide_stats: Array = []
	var flow_count := 0
	var gap_count := 0
	if str(recipe["method"]) == SPINE_FLOW:
		var flow_result := _combined_spine_flow(domain, guides, recipe["parameters"])
		placements = flow_result.get("placements", [])
		guide_stats = flow_result.get("guide_stats", [])
		flow_count = placements.size()
		if bool(recipe["parameters"]["fill_gaps"]):
			var gap_spacing := float(recipe["parameters"]["spacing"])
			var initial_positions: Array[Vector2] = []
			for placement in placements:
				initial_positions.append(Vector2(placement.get("position", Vector2.ZERO)))
			var filled := _poisson_positions(domain, gap_spacing, float(recipe["parameters"]["boundary_clearance"]), int(recipe["parameters"]["seed"]), initial_positions)
			for filled_index in range(initial_positions.size(), filled.size()):
				placements.append({"position": filled[filled_index], "placement": "gap_fill"})
			gap_count = maxi(placements.size() - flow_count, 0)
	else:
		var spacing := float(recipe["parameters"]["spacing"])
		var clearance := spacing * float(recipe["parameters"]["constraint_clearance_factor"])
		for position in _poisson_positions(domain, spacing, clearance, int(recipe["parameters"]["seed"])):
			placements.append({"position": position, "placement": "poisson"})
	var seeds: Array = []
	for seed_index in range(placements.size()):
		var placement: Dictionary = placements[seed_index]
		var provenance := placement.duplicate(true)
		provenance.erase("position")
		provenance["generation_index"] = seed_index
		seeds.append({"id": "seed:auto:%06d" % (seed_index + 1), "position": Vector2(placement.get("position", Vector2.ZERO)), "origin": "generated", "method": recipe["method"], "provenance": provenance})
	var guide_ids := _active_guide_ids(recipe)
	return {
		"valid": true, "errors": [], "algorithm_version": ALGORITHM_VERSION,
		"method": recipe["method"], "parameters": recipe["parameters"].duplicate(true),
		"sampling_bake_id": str(sampling_bake.get("bake_id", "")), "sampling_fingerprint": sampling_fingerprint(sampling_bake),
		"guide_ids": guide_ids, "guides_fingerprint": guides_fingerprint(guides),
		"guide_id": str(guide_ids[0]) if guide_ids.size() == 1 else "", "guide_fingerprint": guide_fingerprint(guides[0]) if guides.size() == 1 else "",
		"guide_stats": guide_stats, "flow_seed_count": flow_count, "gap_seed_count": gap_count,
		"seeds": seeds, "seed_count": seeds.size(), "edited": false
	}


static func validation_issues(sampling_bake: Dictionary, recipe: Dictionary = {}, raw_guides = []) -> Array[String]:
	var errors: Array[String] = []
	if sampling_bake.is_empty() or not bool(sampling_bake.get("valid", false)):
		errors.append("Seeding requires a valid Sampling Bake.")
		return errors
	if str(sampling_bake.get("bake_id", "")).is_empty():
		errors.append("The Sampling Bake has no stable Bake ID.")
	var domain := constraint_domain(sampling_bake)
	var outer: PackedVector2Array = domain.get("outer", PackedVector2Array())
	if outer.size() < 3:
		errors.append("Seeding requires one sampled outer boundary with at least three Points.")
	var normalized := normalize_recipe(recipe)
	if str(normalized.get("method", POISSON_FILL)) != SPINE_FLOW:
		return errors
	var guides := _guide_array(raw_guides)
	var active_ids := _active_guide_ids(normalized)
	if active_ids.is_empty():
		errors.append("Spine Flow requires at least one enabled Sampler Spine.")
		return errors
	var guides_by_id: Dictionary = {}
	for guide in guides:
		guides_by_id[str(guide.get("id", ""))] = guide
	for guide_id in active_ids:
		if not guides_by_id.has(guide_id):
			errors.append("Sampler Spine %s is unavailable." % guide_id)
			continue
		var guide: Dictionary = guides_by_id[guide_id]
		if str(guide.get("guide_type", "")) != AssetGuide.SAMPLER_SPINE:
			errors.append("Spine Flow inputs must be Sampler Spine Guides.")
			continue
		if guide.get("points", []).size() < 2 or guide.get("chains", []).size() != 1:
			errors.append("Spine Flow requires one authored open Sampler Spine with at least two Points.")
			continue
		var boundary_tolerance := maxf(0.0001, float(sampling_bake.get("parameters", {}).get("spacing", 1.0)) * 0.25)
		for position in _guide_polyline(guide):
			if not _point_is_inside_or_on_boundary(position, outer, domain.get("holes", []), boundary_tolerance):
				errors.append("Sampler Spine %s must remain inside the sampled Component boundary." % str(guide.get("name", guide_id)))
				break
	return errors


static func guide_fingerprint(guide: Dictionary) -> String:
	if guide.is_empty():
		return ""
	return _hash_parts(PackedStringArray([str(guide.get("id", "")), str(guide.get("guide_type", "")), AssetGuide.scope_component_id(guide), GeometrySamplingService.source_fingerprint(guide)]))


static func guides_fingerprint(raw_guides) -> String:
	var parts := PackedStringArray()
	for guide in _guide_array(raw_guides):
		parts.append("%s|%s" % [str(guide.get("id", "")), guide_fingerprint(guide)])
	return _hash_parts(parts)


static func boundary_polygons(sampling_bake: Dictionary) -> Dictionary:
	var domain := constraint_domain(sampling_bake)
	return {"outer": domain.get("outer", PackedVector2Array()), "holes": domain.get("holes", [])}


static func constraint_domain(sampling_bake: Dictionary) -> Dictionary:
	var outer := PackedVector2Array()
	var holes: Array = []
	var cuts: Array = []
	for chain_data in sampling_bake.get("chains", []):
		if not chain_data is Dictionary or not bool(chain_data.get("closed", false)):
			continue
		var polygon := PackedVector2Array()
		for sample in chain_data.get("samples", []):
			if sample is Dictionary:
				polygon.append(Vector2(sample.get("position", Vector2.ZERO)))
		var role := WorldDocumentService.topology_role(chain_data)
		if role == WorldDocumentService.ROLE_OUTER and outer.is_empty():
			outer = polygon
		elif role == WorldDocumentService.ROLE_HOLE and polygon.size() >= 3:
			holes.append(polygon)
	for cut_data in sampling_bake.get("cuts", []):
		if not cut_data is Dictionary or not bool(cut_data.get("valid", false)):
			continue
		for fragment in GeometrySamplingService.cut_fragments(cut_data):
			var polyline := PackedVector2Array()
			for sample in fragment.get("samples", []):
				if sample is Dictionary:
					polyline.append(Vector2(sample.get("position", Vector2.ZERO)))
			if polyline.size() >= 2:
				cuts.append({"guide_id": str(cut_data.get("guide_id", "")), "fragment_id": str(fragment.get("id", "")), "points": polyline})
	return {"outer": outer, "holes": holes, "cuts": cuts}


static func point_is_inside(sampling_bake: Dictionary, position: Vector2) -> bool:
	var domain := constraint_domain(sampling_bake)
	return _point_is_inside_polygons(position, domain.get("outer", PackedVector2Array()), domain.get("holes", []))


static func point_is_valid(sampling_bake: Dictionary, position: Vector2, clearance := 0.0001) -> bool:
	var domain := constraint_domain(sampling_bake)
	return _point_is_valid_in_domain(position, domain, clearance)


static func sampling_fingerprint(sampling_bake: Dictionary) -> String:
	var parts: PackedStringArray = [str(sampling_bake.get("bake_id", "")), "algorithm|%d" % int(sampling_bake.get("algorithm_version", 0))]
	for chain_data in sampling_bake.get("chains", []):
		if not chain_data is Dictionary:
			continue
		parts.append("c|%s|%s|%d" % [str(chain_data.get("chain_id", "")), WorldDocumentService.topology_role(chain_data), int(bool(chain_data.get("closed", false)))])
		for sample in chain_data.get("samples", []):
			if sample is Dictionary:
				var position: Vector2 = sample.get("position", Vector2.ZERO)
				parts.append("s|%s|%.9f|%.9f" % [str(sample.get("id", "")), position.x, position.y])
	for cut_data in sampling_bake.get("cuts", []):
		if not cut_data is Dictionary:
			continue
		parts.append("cut|%s|%d" % [str(cut_data.get("guide_id", "")), int(bool(cut_data.get("valid", false)))])
		# Keep the public flattened preview representation in the dependency hash
		# as well as the connectivity-preserving fragments.
		for sample in cut_data.get("samples", []):
			if sample is Dictionary:
				var flat_position: Vector2 = sample.get("position", Vector2.ZERO)
				parts.append("flat|%s|%.9f|%.9f" % [str(sample.get("id", "")), flat_position.x, flat_position.y])
		for fragment in GeometrySamplingService.cut_fragments(cut_data):
			parts.append("fragment|%s" % str(fragment.get("id", "")))
			for sample in fragment.get("samples", []):
				if sample is Dictionary:
					var position: Vector2 = sample.get("position", Vector2.ZERO)
					parts.append("cs|%s|%.9f|%.9f" % [str(sample.get("id", "")), position.x, position.y])
	return _hash_parts(parts)


static func _combined_spine_flow(domain: Dictionary, guides: Array[Dictionary], parameters: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for guide_order in range(guides.size()):
		candidates.append_array(_spine_candidates(domain, guides[guide_order], guide_order, parameters))
	candidates.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_offset := float(first.get("offset", 0.0))
		var second_offset := float(second.get("offset", 0.0))
		if not is_equal_approx(first_offset, second_offset):
			return first_offset < second_offset
		var first_order := int(first.get("guide_order", 0))
		var second_order := int(second.get("guide_order", 0))
		if first_order != second_order:
			return first_order < second_order
		var first_station := int(first.get("station_index", 0))
		var second_station := int(second.get("station_index", 0))
		if first_station != second_station:
			return first_station < second_station
		return int(first.get("side", 0)) < int(second.get("side", 0))
	)
	var minimum_distance := minf(float(parameters["along_spacing"]), float(parameters["across_spacing"]))
	if not bool(parameters.get("fill_gaps", true)):
		minimum_distance *= 0.32
	var placements: Array[Dictionary] = []
	var positions: Array[Vector2] = []
	var counts: Dictionary = {}
	for candidate in candidates:
		var position := Vector2(candidate.get("position", Vector2.ZERO))
		if positions.size() >= MAX_SEEDS or not _append_spaced_position(positions, position, minimum_distance):
			continue
		var placement := candidate.duplicate(true)
		placement["placement"] = "flow"
		placements.append(placement)
		var guide_id := str(candidate.get("guide_id", ""))
		counts[guide_id] = int(counts.get(guide_id, 0)) + 1
	var stats: Array = []
	for guide in guides:
		var guide_id := str(guide.get("id", ""))
		stats.append({"guide_id": guide_id, "seed_count": int(counts.get(guide_id, 0))})
	return {"placements": placements, "guide_stats": stats}


static func _spine_candidates(domain: Dictionary, guide: Dictionary, guide_order: int, parameters: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stations := _resample_polyline(_guide_polyline(guide), float(parameters["along_spacing"]))
	var across_spacing := float(parameters["across_spacing"])
	var clearance := float(parameters["boundary_clearance"])
	var stagger := float(parameters["stagger"])
	for station_index in range(stations.size()):
		var station: Dictionary = stations[station_index]
		var position: Vector2 = station["position"]
		var tangent: Vector2 = station["tangent"]
		if tangent.length_squared() <= 0.000001:
			continue
		var normal := Vector2(-tangent.y, tangent.x).normalized()
		var phase := 0.0 if station_index % 2 == 0 else stagger
		if is_zero_approx(phase) and _point_is_valid_in_domain(position, domain, clearance):
			result.append(_flow_candidate(position, guide, guide_order, station_index, 0, 0.0))
		for side: int in [-1, 1]:
			var direction := normal * float(side)
			var available := _ray_constraint_distance(position, direction, domain) - clearance
			if available <= 0.0:
				continue
			var offset := across_spacing * (phase if phase > 0.0 else 1.0)
			while offset <= available + 0.000001 and result.size() < MAX_SEEDS:
				var candidate_position := position + direction * offset
				if _point_is_valid_in_domain(candidate_position, domain, clearance):
					result.append(_flow_candidate(candidate_position, guide, guide_order, station_index, side, offset))
				offset += across_spacing
	return result


static func _flow_candidate(position: Vector2, guide: Dictionary, guide_order: int, station_index: int, side: int, offset: float) -> Dictionary:
	return {"position": position, "guide_id": str(guide.get("id", "")), "guide_order": guide_order, "station_index": station_index, "side": side, "offset": offset}


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


static func _ray_constraint_distance(origin: Vector2, direction: Vector2, domain: Dictionary) -> float:
	var distance := _ray_polyline_distance(origin, direction, domain.get("outer", PackedVector2Array()), true)
	for hole in domain.get("holes", []):
		if hole is PackedVector2Array:
			distance = minf(distance, _ray_polyline_distance(origin, direction, hole, true))
	for cut in domain.get("cuts", []):
		if cut is Dictionary:
			distance = minf(distance, _ray_polyline_distance(origin, direction, cut.get("points", PackedVector2Array()), false))
	return distance


static func _ray_polyline_distance(origin: Vector2, direction: Vector2, polyline: PackedVector2Array, closed: bool) -> float:
	var nearest := INF
	var segment_count := polyline.size() if closed else maxi(polyline.size() - 1, 0)
	for index in range(segment_count):
		var start := polyline[index]
		var segment := polyline[(index + 1) % polyline.size()] - start
		var denominator := direction.cross(segment)
		if is_zero_approx(denominator):
			continue
		var offset := start - origin
		var ray_t := offset.cross(segment) / denominator
		var segment_t := offset.cross(direction) / denominator
		if ray_t >= -0.000001 and segment_t >= -0.000001 and segment_t <= 1.000001:
			nearest = minf(nearest, maxf(ray_t, 0.0))
	return nearest


static func _poisson_positions(domain: Dictionary, spacing: float, clearance: float, random_seed: int, initial_positions: Array[Vector2] = []) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var outer: PackedVector2Array = domain.get("outer", PackedVector2Array())
	if outer.size() < 3:
		return result
	var bounds := _polygon_bounds(outer)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	for initial_position in initial_positions:
		if _point_is_valid_in_domain(initial_position, domain, clearance):
			_append_spaced_position(result, initial_position, spacing)
	var first := bounds.get_center()
	if result.is_empty() and not _point_is_valid_in_domain(first, domain, clearance):
		var found_first := false
		for _attempt in range(512):
			var candidate := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
			if _point_is_valid_in_domain(candidate, domain, clearance):
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
			if not bounds.has_point(candidate) or not _point_is_valid_in_domain(candidate, domain, clearance):
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


static func _append_spaced_position(positions: Array[Vector2], candidate: Vector2, minimum_distance: float) -> bool:
	for existing in positions:
		if candidate.distance_squared_to(existing) < minimum_distance * minimum_distance:
			return false
	positions.append(candidate)
	return true


static func _has_poisson_clearance(candidate: Vector2, positions: Array[Vector2], grid: Dictionary, origin: Vector2, cell_size: float, spacing: float) -> bool:
	var key := _grid_key(candidate, origin, cell_size)
	for y_offset in range(-2, 3):
		for x_offset in range(-2, 3):
			var neighbor_key := key + Vector2i(x_offset, y_offset)
			if grid.has(neighbor_key) and candidate.distance_squared_to(positions[int(grid[neighbor_key])]) < spacing * spacing:
				return false
	return true


static func _grid_key(position: Vector2, origin: Vector2, cell_size: float) -> Vector2i:
	return Vector2i(floori((position.x - origin.x) / cell_size), floori((position.y - origin.y) / cell_size))


static func _point_is_valid_in_domain(position: Vector2, domain: Dictionary, clearance: float) -> bool:
	return _point_is_inside_polygons(position, domain.get("outer", PackedVector2Array()), domain.get("holes", [])) and _distance_to_constraints(position, domain) >= maxf(clearance, 0.0)


static func _point_is_inside_polygons(position: Vector2, outer: PackedVector2Array, holes: Array) -> bool:
	if outer.size() < 3 or not Geometry2D.is_point_in_polygon(position, outer):
		return false
	for hole in holes:
		if hole is PackedVector2Array and Geometry2D.is_point_in_polygon(position, hole):
			return false
	return true


static func _point_is_inside_or_on_boundary(position: Vector2, outer: PackedVector2Array, holes: Array, tolerance := 0.0001) -> bool:
	if _distance_to_polyline(position, outer, true) <= tolerance:
		return true
	if not _point_is_inside_polygons(position, outer, holes):
		return false
	for hole in holes:
		if hole is PackedVector2Array and _distance_to_polyline(position, hole, true) <= tolerance:
			return false
	return true


static func _distance_to_constraints(position: Vector2, domain: Dictionary) -> float:
	var distance := _distance_to_polyline(position, domain.get("outer", PackedVector2Array()), true)
	for hole in domain.get("holes", []):
		if hole is PackedVector2Array:
			distance = minf(distance, _distance_to_polyline(position, hole, true))
	for cut in domain.get("cuts", []):
		if cut is Dictionary:
			distance = minf(distance, _distance_to_polyline(position, cut.get("points", PackedVector2Array()), false))
	return distance


static func _distance_to_polyline(position: Vector2, polyline: PackedVector2Array, closed: bool) -> float:
	if polyline.size() < 2:
		return INF
	var distance := INF
	var segment_count := polyline.size() if closed else polyline.size() - 1
	for point_index in range(segment_count):
		var closest := Geometry2D.get_closest_point_to_segment(position, polyline[point_index], polyline[(point_index + 1) % polyline.size()])
		distance = minf(distance, position.distance_to(closest))
	return distance


static func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for position in polygon:
		bounds = bounds.expand(position)
	return bounds


static func _active_guide_ids(recipe: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if str(recipe.get("method", "")) != SPINE_FLOW:
		return result
	for input in recipe.get("parameters", {}).get("spine_inputs", []):
		if input is Dictionary and bool(input.get("enabled", true)) and not str(input.get("guide_id", "")).is_empty():
			result.append(str(input.get("guide_id", "")))
	return result


static func _guide_array(raw_guides) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw_guides is Dictionary:
		if not raw_guides.is_empty():
			result.append(raw_guides)
	elif raw_guides is Array:
		for guide in raw_guides:
			if guide is Dictionary and not guide.is_empty():
				result.append(guide)
	return result


static func _spine_input_index(inputs: Array, guide_id: String) -> int:
	for index in range(inputs.size()):
		if inputs[index] is Dictionary and str(inputs[index].get("guide_id", "")) == guide_id:
			return index
	return -1


static func _hash_parts(parts: PackedStringArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	var payload := "\n".join(parts)
	context.update((payload if not payload.is_empty() else "empty").to_utf8_buffer())
	return context.finish().hex_encode()


static func _failed_result(recipe: Dictionary, sampling_bake: Dictionary, guides: Array[Dictionary], errors: Array[String]) -> Dictionary:
	return {
		"valid": false, "errors": errors, "algorithm_version": ALGORITHM_VERSION,
		"method": recipe["method"], "parameters": recipe["parameters"].duplicate(true),
		"sampling_bake_id": str(sampling_bake.get("bake_id", "")), "sampling_fingerprint": sampling_fingerprint(sampling_bake),
		"guide_ids": _active_guide_ids(recipe), "guides_fingerprint": guides_fingerprint(guides),
		"guide_stats": [], "flow_seed_count": 0, "gap_seed_count": 0,
		"seeds": [], "seed_count": 0, "edited": false
	}
