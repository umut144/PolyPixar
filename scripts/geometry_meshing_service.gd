class_name GeometryMeshingService
extends RefCounted

const CONSTRAINED_MESH := "constrained_mesh"
const CONSTRAINED_DELAUNAY := "constrained_delaunay" # Legacy schema <= 30.
const ORGANIC_RELAXED := "organic_relaxed" # Legacy schema <= 30.
const RIBBON_STRIP := "ribbon_strip" # Legacy schema <= 39.
const CONTOUR_STROKE := "contour_stroke"
const VALID_METHODS := [CONSTRAINED_MESH, CONTOUR_STROKE]
const ALGORITHM_VERSION := 5
const DEFAULT_MESH_CHARACTER := 0.64
const DEFAULT_OPTIMIZE_MESH := true
const DEFAULT_RELAXATION := 0.35
const DEFAULT_PASSES := 2
const MAX_PASSES := 8
const MAX_VERTICES := 40000
const EPSILON := 0.000001
const QUALITY_WARNING_MINIMUM_ANGLE := 5.0
const QUALITY_WARNING_MAX_ASPECT_RATIO := 25.0


static func default_recipe() -> Dictionary:
	return {
		"method": CONSTRAINED_MESH,
		"parameters": {
			"seeding_method": GeometrySeedingService.POISSON_FILL,
			"mesh_character": DEFAULT_MESH_CHARACTER,
			"optimize_mesh": DEFAULT_OPTIMIZE_MESH,
			"relaxation_override": false,
			"relaxation": 0.0,
			"passes_override": false,
			"passes": 0
		}
	}


static func normalize_recipe(raw_recipe) -> Dictionary:
	var recipe := default_recipe()
	if not raw_recipe is Dictionary:
		return recipe
	var raw_method := str(raw_recipe.get("method", CONSTRAINED_MESH))
	var method := CONSTRAINED_MESH if raw_method in [CONSTRAINED_MESH, CONSTRAINED_DELAUNAY, ORGANIC_RELAXED] else raw_method
	recipe["method"] = method if method in VALID_METHODS else CONSTRAINED_MESH
	if recipe["method"] == CONTOUR_STROKE:
		recipe["parameters"] = raw_recipe.get("parameters", {}).duplicate(true) if raw_recipe.get("parameters", {}) is Dictionary else {}
		return recipe
	var parameters = raw_recipe.get("parameters", {})
	var seeding_method := str(parameters.get("seeding_method", GeometrySeedingService.POISSON_FILL)) if parameters is Dictionary else GeometrySeedingService.POISSON_FILL
	if seeding_method not in GeometrySeedingService.VALID_METHODS:
		seeding_method = GeometrySeedingService.POISSON_FILL
	var character := clampf(float(parameters.get("mesh_character", DEFAULT_MESH_CHARACTER)), 0.0, 1.0)
	var optimize_mesh := bool(parameters.get("optimize_mesh", DEFAULT_OPTIMIZE_MESH))
	var legacy_organic: bool = raw_method == ORGANIC_RELAXED and not parameters.has("mesh_character")
	if legacy_organic:
		character = clampf((float(parameters.get("relaxation", DEFAULT_RELAXATION)) - 0.05) / 0.55, 0.0, 1.0)
	var relaxation_override := bool(parameters.get("relaxation_override", legacy_organic))
	var passes_override := bool(parameters.get("passes_override", legacy_organic))
	var relaxation := clampf(float(parameters.get("relaxation", DEFAULT_RELAXATION)), 0.0, 1.0) if relaxation_override else relaxation_for_character(character)
	var passes := clampi(int(parameters.get("passes", DEFAULT_PASSES)), 1, MAX_PASSES) if passes_override else passes_for_character(character)
	recipe["parameters"] = {
		"seeding_method": seeding_method,
		"mesh_character": character,
		"optimize_mesh": optimize_mesh,
		"relaxation_override": relaxation_override,
		"relaxation": relaxation,
		"passes_override": passes_override,
		"passes": passes
	}
	return recipe


static func relaxation_for_character(character: float) -> float:
	var normalized := clampf(character, 0.0, 1.0)
	return 0.0 if is_zero_approx(normalized) else 0.05 + 0.55 * normalized


static func passes_for_character(character: float) -> int:
	var normalized := clampf(character, 0.0, 1.0)
	return 0 if is_zero_approx(normalized) else 1 + roundi(normalized * 3.0)


static func generate(sampling_bake: Dictionary, seeding_bake: Dictionary, raw_recipe = {}) -> Dictionary:
	var recipe := normalize_recipe(raw_recipe)
	var errors := validation_issues(sampling_bake, seeding_bake, recipe)
	if not errors.is_empty():
		return _failed_result(sampling_bake, seeding_bake, recipe, errors)
	var vertices := _source_vertices(sampling_bake, seeding_bake)
	var constraints := _boundary_constraints(sampling_bake)
	var triangulation := _triangulate(vertices, constraints)
	if not bool(triangulation.get("valid", false)):
		return _failed_result(sampling_bake, seeding_bake, recipe, triangulation.get("errors", []))
	var triangles: Array = triangulation.get("triangles", [])
	var triangulation_diagnostics: Dictionary = triangulation.get("diagnostics", {})
	var baseline_vertices: Array = vertices.duplicate(true)
	var baseline_triangles: Array = triangles.duplicate(true)
	var quality_before := _quality_metrics(baseline_vertices, baseline_triangles)
	var optimize_mesh := bool(recipe["parameters"].get("optimize_mesh", DEFAULT_OPTIMIZE_MESH))
	var relaxation := float(recipe["parameters"]["relaxation"])
	var passes := int(recipe["parameters"]["passes"])
	var accepted_passes := 0
	var attempted_passes := 0
	if optimize_mesh and relaxation > 0.0 and passes > 0:
		for _pass_index in range(passes):
			attempted_passes += 1
			var accepted := false
			var trial_strength := relaxation
			for _attempt in range(4):
				var candidate_vertices: Array = vertices.duplicate(true)
				_relax_interior_vertices(candidate_vertices, triangles, sampling_bake, trial_strength)
				var candidate_triangulation := _triangulate(candidate_vertices, constraints)
				if bool(candidate_triangulation.get("valid", false)):
					var candidate_triangles: Array = candidate_triangulation.get("triangles", [])
					var current_quality := _quality_metrics(vertices, triangles)
					var candidate_quality := _quality_metrics(candidate_vertices, candidate_triangles)
					if _quality_is_improved(current_quality, candidate_quality):
						vertices = candidate_vertices
						triangles = candidate_triangles
						triangulation_diagnostics = candidate_triangulation.get("diagnostics", {})
						accepted_passes += 1
						accepted = true
						break
				trial_strength *= 0.5
			if not accepted:
				break
	var quality_after := _quality_metrics(vertices, triangles)
	var movements := _optimization_movements(baseline_vertices, vertices)
	var optimization := {
		"enabled": optimize_mesh,
		"applied": not movements.is_empty(),
		"attempted_passes": attempted_passes,
		"accepted_passes": accepted_passes,
		"moved_seed_count": movements.size(),
		"removed_seed_count": 0,
		"movements": movements,
		"baseline_triangles": baseline_triangles,
		"quality_before": quality_before,
		"quality_after": quality_after
	}
	_duplicate_cut_seam_vertices(vertices, triangles, constraints)
	var minimum_angle := float(quality_after.get("minimum_angle", 0.0))
	var degenerate_count := _degenerate_triangle_count(vertices, triangles)
	var quality_metrics := quality_after.duplicate(true)
	quality_metrics["triangle_count"] = triangles.size()
	var quality_warning_lines := quality_warnings(quality_metrics)
	return {
		"valid": true,
		"errors": [],
		"algorithm_version": ALGORITHM_VERSION,
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
		"minimum_angle": minimum_angle,
		"worst_aspect_ratio": float(quality_after.get("worst_aspect_ratio", 0.0)),
		"mean_quality": float(quality_after.get("mean_quality", 0.0)),
		"quality_warnings": quality_warning_lines,
		"boundary_refinement": boundary_refinement_summary(sampling_bake),
		"optimization": optimization,
		"constraint_count": constraints.size(),
		"constraints_valid": true,
		"cut_seam_vertex_count": vertices.filter(func(vertex: Dictionary) -> bool: return str(vertex.get("origin", "")) == "cut_seam").size(),
		"degenerate_triangle_count": degenerate_count,
		"triangulation_backend": "artem-ogre/CDT 1.4.5",
		"diagnostics": triangulation_diagnostics
	}


static func quality_warnings(metrics: Dictionary) -> PackedStringArray:
	var warnings := PackedStringArray()
	if not metrics.has("triangle_count") or int(metrics.get("triangle_count", 0)) <= 0:
		return warnings
	var minimum_angle := float(metrics.get("minimum_angle", 0.0))
	var worst_aspect_ratio := float(metrics.get("worst_aspect_ratio", 0.0))
	if minimum_angle < QUALITY_WARNING_MINIMUM_ANGLE:
		warnings.append("Minimum angle %.1f° is below the %.1f° quality target." % [minimum_angle, QUALITY_WARNING_MINIMUM_ANGLE])
	if worst_aspect_ratio > QUALITY_WARNING_MAX_ASPECT_RATIO:
		warnings.append("Worst aspect ratio %.2f exceeds the %.2f quality target." % [worst_aspect_ratio, QUALITY_WARNING_MAX_ASPECT_RATIO])
	return warnings


static func boundary_refinement_summary(sampling_bake: Dictionary) -> Dictionary:
	var enabled := int(sampling_bake.get("algorithm_version", 0)) >= GeometrySamplingService.CORNER_BALANCING_VERSION
	return {
		"enabled": enabled,
		"added_vertex_count": maxi(int(sampling_bake.get("boundary_refinement_count", 0)), 0),
		"complete": bool(sampling_bake.get("boundary_refinement_complete", true)) if enabled else true,
		"unresolved_corner_count": maxi(int(sampling_bake.get("boundary_refinement_unresolved_corner_count", 0)), 0) if enabled else 0,
		"limit_reached": bool(sampling_bake.get("boundary_refinement_limit_reached", false)) if enabled else false
	}


static func boundary_refinement_warning(metrics: Dictionary) -> String:
	var refinement: Dictionary = metrics.get("boundary_refinement", {}) if metrics.get("boundary_refinement", {}) is Dictionary else {}
	if not bool(refinement.get("enabled", false)) or bool(refinement.get("complete", true)):
		return ""
	if int(refinement.get("unresolved_corner_count", 0)) <= 0:
		return ""
	var limit_suffix := " The per-Chain refinement limit was reached." if bool(refinement.get("limit_reached", false)) else ""
	return "%d authored corner transitions remain above the %.1f× target.%s" % [int(refinement.get("unresolved_corner_count", 0)), GeometrySamplingService.MAX_ADJACENT_CORNER_SEGMENT_RATIO, limit_suffix]


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
	for cut in sampling_bake.get("cuts", []):
		if not cut is Dictionary or not bool(cut.get("valid", false)):
			continue
		for fragment in GeometrySamplingService.cut_fragments(cut):
			for sample in fragment.get("samples", []):
				if not sample is Dictionary:
					continue
				var position := Vector2(sample.get("position", Vector2.ZERO))
				var vertex_id := ""
				for existing in vertices:
					if Vector2(existing.get("position", Vector2.ZERO)).distance_squared_to(position) <= EPSILON * EPSILON:
						vertex_id = str(existing.get("id", ""))
						break
				if vertex_id.is_empty():
					vertex_id = "vertex:cut:%s" % str(sample.get("id", ""))
					vertices.append({"id": vertex_id, "position": position, "origin": "cut", "source_id": str(sample.get("id", "")), "preserved": true})
				sample["vertex_id"] = vertex_id
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
				"topology_role": WorldDocumentService.topology_role(chain_data),
				"segment_index": sample_index,
				"vertex_ids": [
					"vertex:boundary:%s" % str(samples[sample_index].get("id", "")),
					"vertex:boundary:%s" % str(samples[(sample_index + 1) % samples.size()].get("id", ""))
				]
			})
	for cut in sampling_bake.get("cuts", []):
		if not cut is Dictionary or not bool(cut.get("valid", false)):
			continue
		var fragment_index := 0
		for fragment in GeometrySamplingService.cut_fragments(cut):
			var samples: Array = fragment.get("samples", [])
			for sample_index in range(samples.size() - 1):
				var first_id := str(samples[sample_index].get("vertex_id", ""))
				var second_id := str(samples[sample_index + 1].get("vertex_id", ""))
				if not first_id.is_empty() and not second_id.is_empty() and first_id != second_id:
					constraints.append({"chain_id": str(fragment.get("id", "cut:%s" % str(cut.get("guide_id", "")))), "topology_role": WorldDocumentService.ROLE_CUT, "fragment_index": fragment_index, "segment_index": sample_index, "vertex_ids": [first_id, second_id]})
			fragment_index += 1
	return constraints


static func _duplicate_cut_seam_vertices(vertices: Array, triangles: Array, constraints: Array) -> void:
	var positions: Dictionary = {}
	for vertex in vertices:
		positions[str(vertex.get("id", ""))] = Vector2(vertex.get("position", Vector2.ZERO))
	var duplicate_by_source: Dictionary = {}
	for constraint in constraints:
		if str(constraint.get("topology_role", "")) != "cut":
			continue
		var ids: Array = constraint.get("vertex_ids", [])
		if ids.size() != 2:
			continue
		var first_id := str(ids[0])
		var second_id := str(ids[1])
		var first: Vector2 = positions.get(first_id, Vector2.ZERO)
		var second: Vector2 = positions.get(second_id, Vector2.ZERO)
		var affected: Array = []
		for triangle in triangles:
			var triangle_ids: Array = triangle.get("vertex_ids", [])
			if first_id not in triangle_ids or second_id not in triangle_ids:
				continue
			var centroid := Vector2.ZERO
			for triangle_id in triangle_ids:
				centroid += positions.get(str(triangle_id), Vector2.ZERO)
			centroid /= float(triangle_ids.size())
			if (second - first).cross(centroid - first) > EPSILON:
				affected.append(triangle)
		for triangle in affected:
			var triangle_ids: Array = triangle.get("vertex_ids", [])
			for vertex_id in [first_id, second_id]:
				if not duplicate_by_source.has(vertex_id):
					var duplicate_id := "%s:seam" % vertex_id
					duplicate_by_source[vertex_id] = duplicate_id
					vertices.append({"id": duplicate_id, "position": positions[vertex_id], "origin": "cut_seam", "source_id": vertex_id, "preserved": true})
				triangle_ids[triangle_ids.find(vertex_id)] = duplicate_by_source[vertex_id]
			triangle["vertex_ids"] = triangle_ids


static func _triangulate(vertices: Array, constraints: Array) -> Dictionary:
	var positions := PackedVector2Array()
	var id_to_index: Dictionary = {}
	for vertex_index in range(vertices.size()):
		var position := Vector2(vertices[vertex_index].get("position", Vector2.ZERO))
		for existing in positions:
			if position.distance_squared_to(existing) <= EPSILON * EPSILON:
				return {"valid": false, "errors": ["Meshing inputs contain coincident Vertices."]}
		positions.append(position)
		id_to_index[str(vertices[vertex_index].get("id", ""))] = vertex_index
	var constraint_indices: Array = []
	for constraint_index in range(constraints.size()):
		var constraint: Dictionary = constraints[constraint_index]
		var ids: Array = constraint.get("vertex_ids", [])
		if ids.size() != 2:
			return {"valid": false, "errors": ["Constraint %d does not contain exactly two endpoint IDs." % (constraint_index + 1)]}
		if not id_to_index.has(str(ids[0])) or not id_to_index.has(str(ids[1])):
			return {"valid": false, "errors": ["Constraint %d references a missing sampled junction." % (constraint_index + 1)]}
		constraint_indices.append([int(id_to_index[str(ids[0])]), int(id_to_index[str(ids[1])])])
	var pslg_errors := _pslg_validation_issues(positions, constraint_indices, constraints)
	if not pslg_errors.is_empty():
		return {"valid": false, "errors": pslg_errors, "diagnostics": {"stage": "pslg_validation"}}
	if not ClassDB.class_exists(&"PolyToolsCDT"):
		return {"valid": false, "errors": ["The PolyTools CDT native extension is unavailable. Rebuild native/polytools_cdt for this platform."], "diagnostics": {"stage": "native_load"}}
	var native_cdt: Object = ClassDB.instantiate(&"PolyToolsCDT")
	var packed_constraints := PackedInt32Array()
	for indices in constraint_indices:
		packed_constraints.append(int(indices[0]))
		packed_constraints.append(int(indices[1]))
	var native_result: Dictionary = native_cdt.triangulate(positions, packed_constraints)
	if not bool(native_result.get("valid", false)):
		var native_errors: Array = native_result.get("errors", [])
		return {"valid": false, "errors": native_errors, "diagnostics": {"stage": "native_cdt", "native": native_result.get("diagnostics", {})}}
	var fixed_edge_keys: Dictionary = {}
	var native_fixed: PackedInt32Array = native_result.get("fixed_edges", PackedInt32Array())
	for fixed_index in range(0, native_fixed.size(), 2):
		fixed_edge_keys[_edge_key(native_fixed[fixed_index], native_fixed[fixed_index + 1])] = true
	for constraint_index in range(constraint_indices.size()):
		var indices: Array = constraint_indices[constraint_index]
		if not fixed_edge_keys.has(_edge_key(int(indices[0]), int(indices[1]))):
			return {"valid": false, "errors": ["CDT did not preserve %s." % _constraint_label(constraints[constraint_index], constraint_index)], "diagnostics": {"stage": "constraint_verification"}}
	var raw_triangles: Array = []
	var native_triangles: PackedInt32Array = native_result.get("triangles", PackedInt32Array())
	for raw_index in range(0, native_triangles.size(), 3):
		raw_triangles.append([int(native_triangles[raw_index]), int(native_triangles[raw_index + 1]), int(native_triangles[raw_index + 2])])
	var domain_result := _select_domain_triangles(raw_triangles, positions, constraint_indices, constraints)
	if not bool(domain_result.get("valid", false)):
		return {
			"valid": false,
			"errors": domain_result.get("errors", []),
			"diagnostics": {
				"stage": "domain_classification",
				"native": native_result.get("diagnostics", {}),
				"domain": domain_result.get("diagnostics", {})
			}
		}
	var triangles: Array = []
	for domain_triangle in domain_result.get("triangles", []):
		var indices: Array = domain_triangle.duplicate()
		var a := positions[indices[0]]
		var b := positions[indices[1]]
		var c := positions[indices[2]]
		if (b - a).cross(c - a) < 0.0:
			var swap: int = indices[1]
			indices[1] = indices[2]
			indices[2] = swap
		triangles.append({"vertex_ids": [str(vertices[indices[0]].get("id", "")), str(vertices[indices[1]].get("id", "")), str(vertices[indices[2]].get("id", ""))]})
	if triangles.is_empty():
		return {"valid": false, "errors": ["No valid Triangles remain inside the sampled boundary."]}
	triangles.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return ",".join(first.get("vertex_ids", [])) < ",".join(second.get("vertex_ids", []))
	)
	return {"valid": true, "errors": [], "triangles": triangles, "diagnostics": {"stage": "complete", "native": native_result.get("diagnostics", {}), "domain": domain_result.get("diagnostics", {}), "input_constraint_count": constraint_indices.size()}}


static func _select_domain_triangles(raw_triangles: Array, positions: PackedVector2Array, constraint_indices: Array, constraints: Array) -> Dictionary:
	var candidates: Array = []
	var edge_to_triangles: Dictionary = {}
	for raw_triangle in raw_triangles:
		if not raw_triangle is Array or raw_triangle.size() != 3:
			continue
		var indices: Array = raw_triangle.duplicate()
		var a := positions[int(indices[0])]
		var b := positions[int(indices[1])]
		var c := positions[int(indices[2])]
		if absf((b - a).cross(c - a)) <= EPSILON:
			continue
		var triangle_index := candidates.size()
		candidates.append(indices)
		for edge_slot in range(3):
			var edge_key := _edge_key(int(indices[edge_slot]), int(indices[(edge_slot + 1) % 3]))
			if not edge_to_triangles.has(edge_key):
				edge_to_triangles[edge_key] = []
			edge_to_triangles[edge_key].append(triangle_index)
	if candidates.is_empty():
		return {"valid": false, "errors": ["No non-degenerate CDT Triangles are available for domain classification."], "triangles": [], "diagnostics": {"raw_triangle_count": raw_triangles.size(), "candidate_triangle_count": 0}}

	var boundary_edge_keys: Dictionary = {}
	var outer_orientation_by_chain: Dictionary = {}
	for constraint_index in range(constraint_indices.size()):
		var role := WorldDocumentService.topology_role(constraints[constraint_index])
		if role not in WorldDocumentService.TOPOLOGY_ROLES:
			continue
		var edge: Array = constraint_indices[constraint_index]
		var first := int(edge[0])
		var second := int(edge[1])
		boundary_edge_keys[_edge_key(first, second)] = true
		if role == WorldDocumentService.ROLE_OUTER:
			var chain_id := str(constraints[constraint_index].get("chain_id", ""))
			outer_orientation_by_chain[chain_id] = float(outer_orientation_by_chain.get(chain_id, 0.0)) + positions[first].cross(positions[second])

	var selected: Dictionary = {}
	var pending: Array[int] = []
	for constraint_index in range(constraint_indices.size()):
		if WorldDocumentService.topology_role(constraints[constraint_index]) != WorldDocumentService.ROLE_OUTER:
			continue
		var edge: Array = constraint_indices[constraint_index]
		var first := int(edge[0])
		var second := int(edge[1])
		var chain_id := str(constraints[constraint_index].get("chain_id", ""))
		var orientation := signf(float(outer_orientation_by_chain.get(chain_id, 0.0)))
		if is_zero_approx(orientation):
			return {"valid": false, "errors": ["Outer Chain %s has no stable winding for domain classification." % chain_id], "triangles": [], "diagnostics": {"raw_triangle_count": raw_triangles.size(), "candidate_triangle_count": candidates.size()}}
		for triangle_index in edge_to_triangles.get(_edge_key(first, second), []):
			var triangle: Array = candidates[int(triangle_index)]
			var third := _triangle_third_vertex(triangle, first, second)
			if third < 0:
				continue
			var side := (positions[second] - positions[first]).cross(positions[third] - positions[first])
			if side * orientation > 0.0 and not selected.has(int(triangle_index)):
				selected[int(triangle_index)] = true
				pending.append(int(triangle_index))
	if pending.is_empty():
		return {"valid": false, "errors": ["No CDT face lies on the interior side of the sampled Outer boundary."], "triangles": [], "diagnostics": {"raw_triangle_count": raw_triangles.size(), "candidate_triangle_count": candidates.size()}}

	var boundary_seed_count := pending.size()
	var pending_index := 0
	while pending_index < pending.size():
		var triangle_index := pending[pending_index]
		pending_index += 1
		var triangle: Array = candidates[triangle_index]
		for edge_slot in range(3):
			var edge_key := _edge_key(int(triangle[edge_slot]), int(triangle[(edge_slot + 1) % 3]))
			if boundary_edge_keys.has(edge_key):
				continue
			for neighbor_index in edge_to_triangles.get(edge_key, []):
				var neighbor := int(neighbor_index)
				if not selected.has(neighbor):
					selected[neighbor] = true
					pending.append(neighbor)

	var selected_indices: Array = selected.keys()
	selected_indices.sort()
	var domain_triangles: Array = []
	for triangle_index in selected_indices:
		domain_triangles.append(candidates[int(triangle_index)].duplicate())
	var constraint_issues := _final_constraint_issues(domain_triangles, constraint_indices, constraints)
	if not constraint_issues.is_empty():
		return {
			"valid": false,
			"errors": constraint_issues,
			"triangles": [],
			"diagnostics": {
				"raw_triangle_count": raw_triangles.size(),
				"candidate_triangle_count": candidates.size(),
				"selected_triangle_count": domain_triangles.size(),
				"boundary_seed_count": boundary_seed_count,
				"final_constraint_issue_count": constraint_issues.size()
			}
		}
	return {
		"valid": true,
		"errors": [],
		"triangles": domain_triangles,
		"diagnostics": {
			"raw_triangle_count": raw_triangles.size(),
			"candidate_triangle_count": candidates.size(),
			"selected_triangle_count": domain_triangles.size(),
			"boundary_seed_count": boundary_seed_count,
			"final_constraint_issue_count": 0
		}
	}


static func _triangle_third_vertex(triangle: Array, first: int, second: int) -> int:
	for vertex_index in triangle:
		var candidate := int(vertex_index)
		if candidate != first and candidate != second:
			return candidate
	return -1


static func _final_constraint_issues(triangles: Array, constraint_indices: Array, constraints: Array) -> Array[String]:
	var edge_use_count: Dictionary = {}
	for triangle in triangles:
		if not triangle is Array or triangle.size() != 3:
			continue
		for edge_slot in range(3):
			var key := _edge_key(int(triangle[edge_slot]), int(triangle[(edge_slot + 1) % 3]))
			edge_use_count[key] = int(edge_use_count.get(key, 0)) + 1
	var errors: Array[String] = []
	for constraint_index in range(constraint_indices.size()):
		var edge: Array = constraint_indices[constraint_index]
		var actual_count := int(edge_use_count.get(_edge_key(int(edge[0]), int(edge[1])), 0))
		var role := WorldDocumentService.topology_role(constraints[constraint_index])
		var expected_count := 2 if role == WorldDocumentService.ROLE_CUT else 1
		if actual_count != expected_count:
			errors.append("Final Mesh uses %s in %d Triangle%s; expected %d." % [
				_constraint_label(constraints[constraint_index], constraint_index),
				actual_count,
				"" if actual_count == 1 else "s",
				expected_count
			])
	return errors


static func _pslg_validation_issues(positions: PackedVector2Array, constraint_indices: Array, constraints: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen_edges: Dictionary = {}
	for constraint_index in range(constraint_indices.size()):
		var edge: Array = constraint_indices[constraint_index]
		var first := int(edge[0])
		var second := int(edge[1])
		var label := _constraint_label(constraints[constraint_index], constraint_index)
		if first == second or positions[first].distance_squared_to(positions[second]) <= EPSILON * EPSILON:
			errors.append("%s has zero length." % label)
			continue
		var key := _edge_key(first, second)
		if seen_edges.has(key):
			errors.append("%s duplicates %s." % [label, str(seen_edges[key])])
		else:
			seen_edges[key] = label
		for vertex_index in range(positions.size()):
			if vertex_index in [first, second]:
				continue
			var closest := Geometry2D.get_closest_point_to_segment(positions[vertex_index], positions[first], positions[second])
			if closest.distance_squared_to(positions[vertex_index]) <= EPSILON * EPSILON:
				errors.append("%s passes through vertex %d without a shared sampled junction." % [label, vertex_index + 1])
				break
	for first_index in range(constraint_indices.size()):
		var first_edge: Array = constraint_indices[first_index]
		for second_index in range(first_index + 1, constraint_indices.size()):
			var second_edge: Array = constraint_indices[second_index]
			if int(first_edge[0]) in second_edge or int(first_edge[1]) in second_edge:
				continue
			if _segments_intersect_including_endpoints(
				positions[int(first_edge[0])], positions[int(first_edge[1])],
				positions[int(second_edge[0])], positions[int(second_edge[1])]):
				errors.append("%s intersects %s without a shared sampled junction." % [
					_constraint_label(constraints[first_index], first_index),
					_constraint_label(constraints[second_index], second_index)])
				return errors
	return errors


static func _constraint_label(constraint: Dictionary, constraint_index: int) -> String:
	var role := str(constraint.get("topology_role", "boundary")).capitalize()
	var chain_id := str(constraint.get("chain_id", ""))
	var segment_number := int(constraint.get("segment_index", constraint_index)) + 1
	var fragment_suffix := " fragment %d," % (int(constraint.get("fragment_index", 0)) + 1) if constraint.has("fragment_index") else ""
	return "%s%s segment %d%s" % [role, fragment_suffix, segment_number, " (%s)" % chain_id if not chain_id.is_empty() else ""]


static func _segments_intersect_including_endpoints(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab := b - a
	var cd := d - c
	var denominator := ab.cross(cd)
	if absf(denominator) <= EPSILON:
		return _point_on_segment(a, c, d) or _point_on_segment(b, c, d) or _point_on_segment(c, a, b) or _point_on_segment(d, a, b)
	var offset := c - a
	var first_t := offset.cross(cd) / denominator
	var second_t := offset.cross(ab) / denominator
	return first_t >= -EPSILON and first_t <= 1.0 + EPSILON and second_t >= -EPSILON and second_t <= 1.0 + EPSILON


static func _point_on_segment(point: Vector2, start: Vector2, end: Vector2) -> bool:
	return Geometry2D.get_closest_point_to_segment(point, start, end).distance_squared_to(point) <= EPSILON * EPSILON


static func _edge_key(first: int, second: int) -> String:
	return "%d:%d" % [mini(first, second), maxi(first, second)]


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


static func _quality_metrics(vertices: Array, triangles: Array) -> Dictionary:
	var by_id: Dictionary = {}
	for vertex in vertices:
		by_id[str(vertex.get("id", ""))] = Vector2(vertex.get("position", Vector2.ZERO))
	var minimum_angle := 180.0
	var worst_aspect_ratio := 0.0
	var quality_sum := 0.0
	var valid_count := 0
	var degenerate_count := 0
	for triangle in triangles:
		var ids: Array = triangle.get("vertex_ids", [])
		if ids.size() != 3 or not by_id.has(str(ids[0])) or not by_id.has(str(ids[1])) or not by_id.has(str(ids[2])):
			degenerate_count += 1
			continue
		var a: Vector2 = by_id[str(ids[0])]
		var b: Vector2 = by_id[str(ids[1])]
		var c: Vector2 = by_id[str(ids[2])]
		var twice_area := absf((b - a).cross(c - a))
		var ab2 := a.distance_squared_to(b)
		var bc2 := b.distance_squared_to(c)
		var ca2 := c.distance_squared_to(a)
		if twice_area <= EPSILON or minf(ab2, minf(bc2, ca2)) <= EPSILON * EPSILON:
			degenerate_count += 1
			continue
		minimum_angle = minf(minimum_angle, _angle_degrees(b - a, c - a))
		minimum_angle = minf(minimum_angle, _angle_degrees(a - b, c - b))
		minimum_angle = minf(minimum_angle, _angle_degrees(a - c, b - c))
		var longest_edge_squared := maxf(ab2, maxf(bc2, ca2))
		worst_aspect_ratio = maxf(worst_aspect_ratio, longest_edge_squared / twice_area)
		quality_sum += clampf(2.0 * sqrt(3.0) * twice_area / (ab2 + bc2 + ca2), 0.0, 1.0)
		valid_count += 1
	return {
		"minimum_angle": 0.0 if minimum_angle == 180.0 else minimum_angle,
		"worst_aspect_ratio": worst_aspect_ratio,
		"mean_quality": quality_sum / float(valid_count) if valid_count > 0 else 0.0,
		"degenerate_triangle_count": degenerate_count
	}


static func _quality_is_improved(before: Dictionary, after: Dictionary) -> bool:
	if int(after.get("degenerate_triangle_count", 0)) > int(before.get("degenerate_triangle_count", 0)):
		return false
	var before_minimum := float(before.get("minimum_angle", 0.0))
	var after_minimum := float(after.get("minimum_angle", 0.0))
	var before_mean := float(before.get("mean_quality", 0.0))
	var after_mean := float(after.get("mean_quality", 0.0))
	var before_aspect := float(before.get("worst_aspect_ratio", INF))
	var after_aspect := float(after.get("worst_aspect_ratio", INF))
	if after_minimum < before_minimum - 0.05:
		return false
	if after_mean > before_mean + 0.000001:
		return true
	if after_minimum > before_minimum + 0.01 and after_mean >= before_mean - 0.000001:
		return true
	return after_aspect < before_aspect - 0.0001 and after_mean >= before_mean - 0.000001


static func _optimization_movements(before_vertices: Array, after_vertices: Array) -> Array:
	var before_by_id: Dictionary = {}
	for vertex in before_vertices:
		if str(vertex.get("origin", "")) == "seed":
			before_by_id[str(vertex.get("id", ""))] = Vector2(vertex.get("position", Vector2.ZERO))
	var movements: Array = []
	for vertex in after_vertices:
		var vertex_id := str(vertex.get("id", ""))
		if str(vertex.get("origin", "")) != "seed" or not before_by_id.has(vertex_id):
			continue
		var from: Vector2 = before_by_id[vertex_id]
		var to := Vector2(vertex.get("position", Vector2.ZERO))
		if from.distance_squared_to(to) <= EPSILON * EPSILON:
			continue
		movements.append({"vertex_id": vertex_id, "from": from, "to": to, "distance": from.distance_to(to)})
	movements.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return str(first.get("vertex_id", "")) < str(second.get("vertex_id", "")))
	return movements


static func _degenerate_triangle_count(vertices: Array, triangles: Array) -> int:
	var by_id: Dictionary = {}
	for vertex in vertices:
		by_id[str(vertex.get("id", ""))] = Vector2(vertex.get("position", Vector2.ZERO))
	var count := 0
	for triangle in triangles:
		var ids: Array = triangle.get("vertex_ids", [])
		if ids.size() != 3:
			count += 1
			continue
		var a: Vector2 = by_id.get(str(ids[0]), Vector2.ZERO)
		var b: Vector2 = by_id.get(str(ids[1]), Vector2.ZERO)
		var c: Vector2 = by_id.get(str(ids[2]), Vector2.ZERO)
		if absf((b - a).cross(c - a)) <= EPSILON:
			count += 1
	return count


static func _angle_degrees(first: Vector2, second: Vector2) -> float:
	if first.length_squared() <= EPSILON or second.length_squared() <= EPSILON:
		return 0.0
	return rad_to_deg(acos(clampf(first.normalized().dot(second.normalized()), -1.0, 1.0)))


static func _failed_result(sampling_bake: Dictionary, seeding_bake: Dictionary, recipe: Dictionary, errors: Array) -> Dictionary:
	return {
		"valid": false,
		"errors": errors,
		"algorithm_version": ALGORITHM_VERSION,
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
		"minimum_angle": 0.0,
		"worst_aspect_ratio": 0.0,
		"mean_quality": 0.0,
		"quality_warnings": PackedStringArray(),
		"boundary_refinement": boundary_refinement_summary(sampling_bake),
		"optimization": {"enabled": bool(recipe.get("parameters", {}).get("optimize_mesh", DEFAULT_OPTIMIZE_MESH)), "applied": false, "attempted_passes": 0, "accepted_passes": 0, "moved_seed_count": 0, "removed_seed_count": 0, "movements": [], "baseline_triangles": [], "quality_before": {}, "quality_after": {}},
		"constraint_count": 0,
		"constraints_valid": false,
		"cut_seam_vertex_count": 0,
		"degenerate_triangle_count": 0
	}
