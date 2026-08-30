class_name GeometryAutoBuildService
extends RefCounted

const SIGNATURE_VERSION := 1
const RECIPE_VERSION := 2
const AUTO_RECIPE_VERSION := 3
const GEOMETRY_TOLERANCE_FACTOR := 0.001
const MIN_BOUNDARY_SAMPLES := 8
const MAX_BOUNDARY_SAMPLES := 512
const CALIBRATED_SPACING := 0.55
const CALIBRATED_FEATURE_DETAIL := 0.55
const REFERENCE_MAX_BOUNDARY_PERIMETER := 60.0
const BOUNDARY_SCALE_EXPONENT := 0.5
const MAX_BOUNDARY_SCALE := 4.0
const MAX_AUTOMATIC_AREA_CELLS := 750.0
const MIN_INTERIOR_SPANS_ACROSS := 3.0
const LEGACY_DEFAULT_MIGRATION_MIN_PERIMETER := 75.0
const LEGACY_DEFAULT_MIGRATION_MIN_AREA := 250.0
const MAX_AUTOMATIC_ATTEMPTS := 4
const AUTOMATIC_RETRY_FACTOR := 1.25
const MAX_AUTOMATIC_BOUNDARY_SAMPLES := 4096
const MAX_AUTOMATIC_SEEDS := 2500
const MAX_AUTOMATIC_TRIANGLES := 12000
const HOLE_DENSITY_FACTOR := 0.75
const CUT_DENSITY_FACTOR := 1.25


static func automatic_recipes(component: Dictionary, cut_guides: Array = [], hole_components: Array = []) -> Dictionary:
	var metrics := analyze(component)
	var perimeter := float(metrics.get("perimeter", 0.0))
	var area := float(metrics.get("area", 0.0))
	var feature_size := float(metrics.get("feature_size", 0.0))
	var boundary_spacing := CALIBRATED_SPACING
	if perimeter > REFERENCE_MAX_BOUNDARY_PERIMETER:
		var boundary_scale := pow(perimeter / REFERENCE_MAX_BOUNDARY_PERIMETER, BOUNDARY_SCALE_EXPONENT)
		boundary_spacing *= clampf(boundary_scale, 1.0, MAX_BOUNDARY_SCALE)
	if perimeter > 0.0:
		boundary_spacing = minf(boundary_spacing, perimeter / float(MIN_BOUNDARY_SAMPLES))
		boundary_spacing = maxf(boundary_spacing, perimeter / float(MAX_BOUNDARY_SAMPLES))
	boundary_spacing = maxf(boundary_spacing, GeometrySamplingService.MIN_SPACING)
	var seed_spacing := boundary_spacing
	if area > 0.0:
		var area_spacing := sqrt(area / MAX_AUTOMATIC_AREA_CELLS)
		if feature_size > 0.0:
			area_spacing = minf(area_spacing, feature_size / MIN_INTERIOR_SPANS_ACROSS)
		seed_spacing = maxf(seed_spacing, area_spacing)
	seed_spacing = maxf(seed_spacing, GeometrySeedingService.MIN_SPACING)
	var recipes := _recipes_for_spacings(component, cut_guides, hole_components, boundary_spacing, seed_spacing)
	recipes["automatic"] = true
	recipes["auto_recipe_version"] = AUTO_RECIPE_VERSION
	recipes["calibration"] = {
		"reference_spacing": CALIBRATED_SPACING,
		"reference_max_boundary_perimeter": REFERENCE_MAX_BOUNDARY_PERIMETER,
		"max_interior_cells": MAX_AUTOMATIC_AREA_CELLS
	}
	return recipes


static func pipeline_recipe_hash(recipes: Dictionary) -> String:
	var normalized: Dictionary = {}
	if recipes.has("sampling"):
		normalized["sampling"] = GeometrySamplingService.normalize_recipe(recipes.get("sampling", {}))
	if recipes.has("seeding"):
		normalized["seeding"] = GeometrySeedingService.normalize_recipe(recipes.get("seeding", {}))
	if recipes.has("meshing"):
		normalized["meshing"] = GeometryMeshingService.normalize_recipe(recipes.get("meshing", {}))
	return _hash_text(_canonical_text(normalized))


static func automatic_retry_recipes(base: Dictionary, retry_index: int, retry_scope: String, retained_boundary_retry_index := 0) -> Dictionary:
	var result := base.duplicate(true)
	var factor := pow(AUTOMATIC_RETRY_FACTOR, maxi(retry_index, 1))
	var boundary_retry_index := retry_index if retry_scope == "boundary" else maxi(int(retained_boundary_retry_index), 0)
	var boundary_factor := pow(AUTOMATIC_RETRY_FACTOR, boundary_retry_index)
	if boundary_retry_index > 0:
		result["sampling"]["parameters"]["spacing"] = float(result["sampling"]["parameters"].get("spacing", GeometrySamplingService.DEFAULT_SPACING)) * boundary_factor
		result["sampling"]["parameters"]["feature_detail"] = float(result["sampling"]["parameters"].get("feature_detail", GeometrySamplingService.DEFAULT_FEATURE_DETAIL)) * boundary_factor
	result["seeding"]["parameters"]["spacing"] = float(result["seeding"]["parameters"].get("spacing", GeometrySeedingService.DEFAULT_SPACING)) * factor
	if boundary_retry_index > 0:
		result["seeding"]["parameters"]["spacing"] = maxf(
			float(result["seeding"]["parameters"]["spacing"]),
			float(result["sampling"]["parameters"]["spacing"])
		)
	result["sampling"] = GeometrySamplingService.normalize_recipe(result["sampling"])
	result["seeding"] = GeometrySeedingService.normalize_recipe(result["seeding"])
	result["meshing"] = GeometryMeshingService.normalize_recipe(result["meshing"])
	result["retry"] = {"index": retry_index, "scope": retry_scope, "seed_factor": factor, "boundary_factor": boundary_factor}
	return result


static func automatic_build_assessment(sampling: Dictionary, seeding: Dictionary = {}, meshing: Dictionary = {}) -> Dictionary:
	var issues: Array[String] = []
	var retry_scope := "none"
	var sample_count := int(sampling.get("sample_count", 0))
	var seed_count := int(seeding.get("seed_count", 0))
	var triangle_count := int(meshing.get("triangle_count", 0))
	if not bool(sampling.get("valid", false)):
		var issue_count_before := issues.size()
		for issue in sampling.get("errors", []):
			issues.append(str(issue))
		if issues.size() == issue_count_before:
			issues.append("Automatic Sampling failed without a diagnostic.")
		if _errors_contain(sampling.get("errors", []), "Sampling exceeded the safety limit"):
			retry_scope = "boundary"
	elif sample_count > MAX_AUTOMATIC_BOUNDARY_SAMPLES:
		issues.append("Automatic Boundary complexity exceeded %d Samples (%d)." % [MAX_AUTOMATIC_BOUNDARY_SAMPLES, sample_count])
		retry_scope = "boundary"
	if not seeding.is_empty():
		if not bool(seeding.get("valid", false)):
			var issue_count_before := issues.size()
			for issue in seeding.get("errors", []):
				issues.append(str(issue))
			if issues.size() == issue_count_before:
				issues.append("Automatic Seeding failed without a diagnostic.")
		elif seed_count > MAX_AUTOMATIC_SEEDS:
			issues.append("Automatic interior complexity exceeded %d Seeds (%d)." % [MAX_AUTOMATIC_SEEDS, seed_count])
			if retry_scope == "none":
				retry_scope = "seed"
	if not meshing.is_empty():
		if not bool(meshing.get("valid", false)):
			var issue_count_before := issues.size()
			for issue in meshing.get("errors", []):
				issues.append(str(issue))
			if issues.size() == issue_count_before:
				issues.append("Automatic Meshing failed without a diagnostic.")
			if retry_scope == "none":
				retry_scope = "seed"
		elif triangle_count <= 0:
			issues.append("Automatic Meshing produced no Triangles.")
			if retry_scope == "none":
				retry_scope = "seed"
		elif triangle_count > MAX_AUTOMATIC_TRIANGLES:
			issues.append("Automatic Mesh complexity exceeded %d Triangles (%d)." % [MAX_AUTOMATIC_TRIANGLES, triangle_count])
			if retry_scope == "none":
				retry_scope = "seed"
		if int(meshing.get("degenerate_triangle_count", 0)) > 0:
			issues.append("Automatic Mesh contains degenerate Triangles.")
			if retry_scope == "none":
				retry_scope = "seed"
		if not bool(meshing.get("constraints_valid", false)):
			issues.append("Automatic Mesh does not preserve every sampled Constraint.")
			if retry_scope == "none":
				retry_scope = "seed"
	return {
		"accepted": issues.is_empty(),
		"retry_scope": retry_scope,
		"issues": issues,
		"sample_count": sample_count,
		"seed_count": seed_count,
		"triangle_count": triangle_count,
		"minimum_angle": float(meshing.get("minimum_angle", 0.0)),
		"mean_quality": float(meshing.get("mean_quality", 0.0)),
		"worst_aspect_ratio": float(meshing.get("worst_aspect_ratio", 0.0)),
		"limits": automatic_complexity_limits()
	}


static func automatic_complexity_limits() -> Dictionary:
	return {
		"boundary_samples": MAX_AUTOMATIC_BOUNDARY_SAMPLES,
		"seeds": MAX_AUTOMATIC_SEEDS,
		"triangles": MAX_AUTOMATIC_TRIANGLES
	}


static func _errors_contain(errors: Array, fragment: String) -> bool:
	for error in errors:
		if str(error).contains(fragment):
			return true
	return false


static func recipes_match_legacy_automatic(component: Dictionary, cut_guides: Array, hole_components: Array, recipes: Dictionary) -> bool:
	if recipes.is_empty():
		return false
	var recipe_hash := pipeline_recipe_hash(recipes)
	if recipe_hash == pipeline_recipe_hash(_legacy_automatic_recipes(component, cut_guides, hole_components, false)) \
		or recipe_hash == pipeline_recipe_hash(_legacy_automatic_recipes(component, cut_guides, hole_components, true)):
		return true
	var metrics := analyze(component)
	if float(metrics.get("perimeter", 0.0)) < LEGACY_DEFAULT_MIGRATION_MIN_PERIMETER \
		or float(metrics.get("area", 0.0)) < LEGACY_DEFAULT_MIGRATION_MIN_AREA:
		return false
	return recipe_hash == pipeline_recipe_hash({
		"sampling": GeometrySamplingService.default_recipe(),
		"seeding": GeometrySeedingService.default_recipe(),
		"meshing": GeometryMeshingService.default_recipe()
	})


static func _legacy_automatic_recipes(component: Dictionary, cut_guides: Array, hole_components: Array, include_area_cap: bool) -> Dictionary:
	var metrics := analyze(component)
	var perimeter := float(metrics.get("perimeter", 0.0))
	var area := float(metrics.get("area", 0.0))
	var spacing := CALIBRATED_SPACING
	if perimeter > 0.0:
		spacing = minf(spacing, perimeter / float(MIN_BOUNDARY_SAMPLES))
		spacing = maxf(spacing, perimeter / float(MAX_BOUNDARY_SAMPLES))
	if include_area_cap and area > 0.0:
		spacing = maxf(spacing, sqrt(area / 1000.0))
	spacing = maxf(spacing, GeometrySamplingService.MIN_SPACING)
	return _recipes_for_spacings(component, cut_guides, hole_components, spacing, spacing)


static func _recipes_for_spacings(component: Dictionary, cut_guides: Array, hole_components: Array, boundary_spacing: float, seed_spacing: float) -> Dictionary:
	var refinements: Dictionary = {}
	for hole in hole_components:
		if hole is Dictionary:
			var input_id := str(hole.get("sampling_input_id", hole.get("id", "")))
			if not input_id.is_empty():
				refinements[input_id] = {"factor": HOLE_DENSITY_FACTOR}
	for guide in cut_guides:
		if guide is Dictionary:
			var guide_id := str(guide.get("id", ""))
			if not guide_id.is_empty():
				refinements[guide_id] = {"factor": CUT_DENSITY_FACTOR}
	return {
		"metrics": analyze(component),
		"sampling": GeometrySamplingService.normalize_recipe({
			"method": GeometrySamplingService.ADAPTIVE,
			"parameters": {
				"spacing": boundary_spacing,
				"feature_detail": CALIBRATED_FEATURE_DETAIL,
				"boundary_refinements": refinements
			}
		}),
		"seeding": GeometrySeedingService.normalize_recipe({
			"method": GeometrySeedingService.POISSON_FILL,
			"parameters": {
				"spacing": seed_spacing,
				"constraint_clearance_factor": GeometrySeedingService.DEFAULT_CONSTRAINT_CLEARANCE_FACTOR,
				"seed": GeometrySeedingService.DEFAULT_SEED
			}
		}),
		"meshing": GeometryMeshingService.normalize_recipe({
			"method": GeometryMeshingService.CONSTRAINED_MESH,
			"parameters": {
				"seeding_method": GeometrySeedingService.POISSON_FILL,
				"mesh_character": GeometryMeshingService.DEFAULT_MESH_CHARACTER,
				"optimize_mesh": true
			}
		})
	}


static func analyze(component: Dictionary) -> Dictionary:
	var contour := _outer_contour(component)
	if contour.is_empty():
		return {"area": 0.0, "perimeter": 0.0, "bounds": [0.0, 0.0, 0.0, 0.0], "feature_size": 0.0}
	var minimum := contour[0]
	var maximum := contour[0]
	var perimeter := 0.0
	var signed_area := 0.0
	for index in range(contour.size()):
		var current := contour[index]
		var next := contour[(index + 1) % contour.size()]
		minimum = minimum.min(current)
		maximum = maximum.max(current)
		perimeter += current.distance_to(next)
		signed_area += current.cross(next)
	var size := maximum - minimum
	return {
		"area": absf(signed_area) * 0.5,
		"perimeter": perimeter,
		"bounds": [minimum.x, minimum.y, maximum.x, maximum.y],
		"feature_size": minf(size.x, size.y),
		"diagonal": size.length()
	}


static func source_signature(component: Dictionary, cut_guides: Array, hole_components: Array, recipes: Dictionary) -> Dictionary:
	var spacing := float(recipes.get("sampling", {}).get("parameters", {}).get("spacing", CALIBRATED_SPACING))
	var vectors: Array = []
	var scalars: Array = []
	var topology_parts := PackedStringArray()
	_append_source_signature("outer", component, topology_parts, vectors, scalars)
	for hole in hole_components:
		if hole is Dictionary:
			_append_source_signature("hole:%s" % str(hole.get("sampling_input_id", hole.get("id", ""))), hole, topology_parts, vectors, scalars)
	for guide in cut_guides:
		if guide is Dictionary:
			_append_source_signature("cut:%s" % str(guide.get("id", "")), guide, topology_parts, vectors, scalars)
	var transform: Dictionary = component.get("transform", {}) if component.get("transform", {}) is Dictionary else {}
	var scale := Vector2(transform.get("scale", Vector2.ONE))
	scalars.append(scale.x)
	scalars.append(scale.y)
	return {
		"version": SIGNATURE_VERSION,
		"recipe_version": RECIPE_VERSION,
		"topology_hash": _hash_text("\n".join(topology_parts)),
		"recipe_hash": _hash_text(_canonical_text(_signature_recipes(recipes))),
		"geometry_tolerance": maxf(spacing * GEOMETRY_TOLERANCE_FACTOR, 0.000001),
		"vectors": vectors,
		"scalars": scalars,
		"sampling_algorithm": GeometrySamplingService.ALGORITHM_VERSION,
		"seeding_algorithm": GeometrySeedingService.ALGORITHM_VERSION,
		"meshing_algorithm": GeometryMeshingService.ALGORITHM_VERSION
	}


static func signatures_match(current: Dictionary, baked: Dictionary) -> bool:
	if current.is_empty() or baked.is_empty():
		return false
	for key in ["version", "recipe_version", "topology_hash", "recipe_hash", "sampling_algorithm", "seeding_algorithm", "meshing_algorithm"]:
		if current.get(key) != baked.get(key):
			return false
	var tolerance := maxf(float(current.get("geometry_tolerance", 0.000001)), float(baked.get("geometry_tolerance", 0.000001)))
	var current_vectors: Array = current.get("vectors", [])
	var baked_vectors: Array = baked.get("vectors", [])
	if current_vectors.size() != baked_vectors.size():
		return false
	for index in range(current_vectors.size()):
		var current_value := _array_vector(current_vectors[index])
		var baked_value := _array_vector(baked_vectors[index])
		if current_value.distance_to(baked_value) > tolerance:
			return false
	var current_scalars: Array = current.get("scalars", [])
	var baked_scalars: Array = baked.get("scalars", [])
	if current_scalars.size() != baked_scalars.size():
		return false
	for index in range(current_scalars.size()):
		if absf(float(current_scalars[index]) - float(baked_scalars[index])) > tolerance:
			return false
	return true


static func exact_signature_hash(signature: Dictionary) -> String:
	return _hash_text(_canonical_text(signature))


static func _signature_recipes(recipes: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if bool(recipes.get("automatic", false)):
		result["auto_recipe_version"] = int(recipes.get("auto_recipe_version", AUTO_RECIPE_VERSION))
	if recipes.has("sampling"):
		result["sampling"] = GeometrySamplingService.normalize_recipe(recipes.get("sampling", {}))
	if recipes.has("seeding"):
		result["seeding"] = GeometrySeedingService.normalize_recipe(recipes.get("seeding", {}))
	if recipes.has("meshing"):
		result["meshing"] = GeometryMeshingService.normalize_recipe(recipes.get("meshing", {}))
	for key in ["contour", "contour_stroke"]:
		if recipes.has(key):
			result[key] = recipes[key]
	return result


static func _outer_contour(component: Dictionary) -> PackedVector2Array:
	if PrimitiveGeometryService.has_analytic_shape(component):
		return PackedVector2Array(PrimitiveGeometryService.contour(component))
	var working := component.duplicate(true)
	BezierGeometry.resolve_auto_handles(working.get("points", []), working.get("chains", []))
	for chain in working.get("chains", []):
		if chain is Dictionary and bool(chain.get("closed", false)):
			return BezierGeometry.flatten_chain(working, chain, 32)
	return PackedVector2Array()


static func _append_source_signature(prefix: String, source: Dictionary, topology_parts: PackedStringArray, vectors: Array, scalars: Array) -> void:
	var working := source.duplicate(true)
	BezierGeometry.resolve_auto_handles(working.get("points", []), working.get("chains", []))
	topology_parts.append("source|%s|%s|%s" % [prefix, str(working.get("draw_mode", "closed_loop")), str(working.get("topology_role", "outer"))])
	for point in working.get("points", []):
		if not point is Dictionary:
			continue
		topology_parts.append("point|%s|%s|%d" % [prefix, str(point.get("id", "")), int(bool(point.get("preserve_point", false)))])
		_append_vector(vectors, Vector2(point.get("position", Vector2.ZERO)))
		_append_vector(vectors, Vector2(point.get("handle_in", Vector2.ZERO)))
		_append_vector(vectors, Vector2(point.get("handle_out", Vector2.ZERO)))
	for edge in working.get("edges", []):
		if edge is Dictionary:
			topology_parts.append("edge|%s|%s|%s|%s" % [prefix, str(edge.get("id", "")), str(edge.get("start_point_id", "")), str(edge.get("end_point_id", ""))])
	for chain in working.get("chains", []):
		if chain is Dictionary:
			topology_parts.append("chain|%s|%s|%s|%s|%d|%s" % [prefix, str(chain.get("id", "")), ",".join(chain.get("point_ids", [])), ",".join(chain.get("edge_ids", [])), int(bool(chain.get("closed", false))), str(chain.get("topology_role", "outer"))])
	if PrimitiveGeometryService.has_analytic_shape(working):
		topology_parts.append("primitive|%s|%s" % [prefix, str(working.get("primitive", {}).get("type", ""))])
		_append_vector(vectors, PrimitiveGeometryService.center(working))
		var primitive_diameters := PrimitiveGeometryService.diameters_tool_units(working)
		scalars.append(primitive_diameters.x)
		scalars.append(primitive_diameters.y)
	if str(working.get("draw_mode", "")) == "contour":
		scalars.append(float(ContourStrokeService.DEFAULT_STROKE_WIDTH_PX))
		scalars.append(float(ContourMeshService.ALGORITHM_VERSION))
		for edge in working.get("edges", []):
			if edge is Dictionary:
				topology_parts.append("contour_outline|%s|%d" % [str(edge.get("id", "")), int(bool(edge.get("render_outline", true)))])
	var sampling_transform: Transform2D = working.get("sampling_transform", Transform2D.IDENTITY)
	_append_vector(vectors, sampling_transform.x)
	_append_vector(vectors, sampling_transform.y)
	_append_vector(vectors, sampling_transform.origin)


static func _append_vector(values: Array, value: Vector2) -> void:
	values.append([value.x, value.y])


static func _array_vector(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


static func _canonical_text(value) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(first, second) -> bool: return str(first) < str(second))
		var entries := PackedStringArray()
		for key in keys:
			entries.append("%s:%s" % [JSON.stringify(str(key)), _canonical_text(value[key])])
		return "{%s}" % ",".join(entries)
	if value is Array:
		var entries := PackedStringArray()
		for item in value:
			entries.append(_canonical_text(item))
		return "[%s]" % ",".join(entries)
	if value is float:
		return String.num(value, 12)
	return JSON.stringify(value)


static func _hash_text(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()
