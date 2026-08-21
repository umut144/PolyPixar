class_name GeometryAutoBuildService
extends RefCounted

const SIGNATURE_VERSION := 1
const RECIPE_VERSION := 1
const GEOMETRY_TOLERANCE_FACTOR := 0.001
const MIN_BOUNDARY_SAMPLES := 8
const MAX_BOUNDARY_SAMPLES := 512
const CALIBRATED_SPACING := 0.55
const CALIBRATED_FEATURE_DETAIL := 0.55
const MAX_AUTOMATIC_AREA_CELLS := 1000.0
const HOLE_DENSITY_FACTOR := 0.75
const CUT_DENSITY_FACTOR := 1.25


static func automatic_recipes(component: Dictionary, cut_guides: Array = [], hole_components: Array = []) -> Dictionary:
	var metrics := analyze(component)
	var perimeter := float(metrics.get("perimeter", 0.0))
	var area := float(metrics.get("area", 0.0))
	var spacing := CALIBRATED_SPACING
	if perimeter > 0.0:
		spacing = minf(spacing, perimeter / float(MIN_BOUNDARY_SAMPLES))
		spacing = maxf(spacing, perimeter / float(MAX_BOUNDARY_SAMPLES))
	if area > 0.0:
		# Keep automatic interior density bounded for physically large Components.
		# Manual recipes remain exact and are never rewritten by this calibration.
		spacing = maxf(spacing, sqrt(area / MAX_AUTOMATIC_AREA_CELLS))
	spacing = maxf(spacing, GeometrySamplingService.MIN_SPACING)
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
		"metrics": metrics,
		"sampling": GeometrySamplingService.normalize_recipe({
			"method": GeometrySamplingService.ADAPTIVE,
			"parameters": {
				"spacing": spacing,
				"feature_detail": CALIBRATED_FEATURE_DETAIL,
				"boundary_refinements": refinements
			}
		}),
		"seeding": GeometrySeedingService.normalize_recipe({
			"method": GeometrySeedingService.POISSON_FILL,
			"parameters": {
				"spacing": spacing,
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
		"recipe_hash": _hash_text(_canonical_text(recipes)),
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
