class_name GeometrySamplingService
extends RefCounted

const ADAPTIVE := "adaptive"
const EVEN_SPACING := "even_spacing"
const VALID_METHODS := [ADAPTIVE]
const ALGORITHM_VERSION := 6
const CORNER_BALANCING_VERSION := 5
const DEFAULT_SPACING := 1.0
const DEFAULT_FEATURE_DETAIL := 0.5
const MIN_SPACING := 0.01
const MIN_REFINEMENT_FACTOR := 0.25
const MAX_REFINEMENT_FACTOR := 16.0
const MAX_SAMPLES_PER_CHAIN := 20000
const MAX_ADAPTIVE_DEPTH := 18
const ARRANGEMENT_EPSILON := 0.000001
const MAX_ADJACENT_CORNER_SEGMENT_RATIO := 3.0
const MAX_CORNER_REFINEMENTS_PER_CHAIN := 64


static func default_recipe() -> Dictionary:
	return {
		"method": ADAPTIVE,
		"parameters": {
			"spacing": DEFAULT_SPACING,
			"feature_detail": DEFAULT_FEATURE_DETAIL,
			"boundary_refinements": {}
		}
	}


static func normalize_recipe(raw_recipe) -> Dictionary:
	var recipe := default_recipe()
	if not raw_recipe is Dictionary:
		return recipe
	recipe["method"] = ADAPTIVE
	var raw_parameters = raw_recipe.get("parameters", {})
	if raw_parameters is Dictionary:
		recipe["parameters"]["spacing"] = maxf(float(raw_parameters.get("spacing", DEFAULT_SPACING)), MIN_SPACING)
		recipe["parameters"]["feature_detail"] = clampf(float(raw_parameters.get("feature_detail", DEFAULT_FEATURE_DETAIL)), 0.0, 1.0)
	var raw_refinements = raw_parameters.get("boundary_refinements", {})
	if raw_refinements is Dictionary:
		for input_id in raw_refinements:
			var raw_refinement = raw_refinements[input_id]
			if raw_refinement is Dictionary:
				var factor := clampf(float(raw_refinement.get("factor", 1.0)), MIN_REFINEMENT_FACTOR, MAX_REFINEMENT_FACTOR)
				recipe["parameters"]["boundary_refinements"][str(input_id)] = {"factor": factor}
	# Schema-28 migration: absolute per-boundary Spacing becomes a factor.
	var raw_overrides = raw_parameters.get("boundary_overrides", {})
	if raw_overrides is Dictionary:
		for input_id in raw_overrides:
			var raw_override = raw_overrides[input_id]
			if raw_override is Dictionary and raw_override.has("spacing"):
				var override_spacing := maxf(float(raw_override.get("spacing", recipe["parameters"]["spacing"])), MIN_SPACING)
				var factor := clampf(float(recipe["parameters"]["spacing"]) / override_spacing, MIN_REFINEMENT_FACTOR, MAX_REFINEMENT_FACTOR)
				if not is_equal_approx(factor, 1.0):
					recipe["parameters"]["boundary_refinements"][str(input_id)] = {"factor": factor}
	return recipe


static func generate(component: Dictionary, raw_recipe = {}, cut_guides: Array = [], hole_components: Array = []) -> Dictionary:
	var recipe := normalize_recipe(raw_recipe)
	var allow_open := bool(raw_recipe.get("allow_open", false)) if raw_recipe is Dictionary else false
	if PrimitiveGeometryService.has_analytic_shape(component):
		var sampled_circle := _sample_analytic_primitive(component, recipe, "", WorldDocumentService.ROLE_OUTER)
		if not bool(sampled_circle.get("valid", false)):
			return _failed_result(recipe, sampled_circle.get("errors", []), source_fingerprint(component, cut_guides, hole_components))
		var samples: Array = sampled_circle.get("samples", [])
		var primitive_result := {
			"valid": true, "errors": [], "method": recipe["method"], "parameters": recipe["parameters"].duplicate(true),
			"algorithm_version": ALGORITHM_VERSION,
			"source_fingerprint": source_fingerprint(component, cut_guides, hole_components), "chains": [{"chain_id": "primitive:%s" % str(component.get("primitive", {}).get("type", "")), "input_id": "", "topology_role": WorldDocumentService.ROLE_OUTER, "closed": true, "effective_spacing": sampled_circle["effective_spacing"], "samples": samples}], "cuts": [],
			"boundary_refinement_count": 0,
			"boundary_refinement_complete": true,
			"boundary_refinement_unresolved_corner_count": 0,
			"boundary_refinement_limit_reached": false,
			"sample_count": samples.size(), "preserve_count": 0
		}
		var primitive_holes := _sample_hole_components(hole_components, recipe)
		if not primitive_holes["errors"].is_empty():
			return _failed_result(recipe, primitive_holes["errors"], source_fingerprint(component, cut_guides, hole_components))
		primitive_result["chains"].append_array(primitive_holes["chains"])
		primitive_result["sample_count"] += int(primitive_holes["sample_count"])
		primitive_result["boundary_refinement_count"] += int(primitive_holes.get("boundary_refinement_count", 0))
		primitive_result["boundary_refinement_complete"] = bool(primitive_holes.get("boundary_refinement_complete", true))
		primitive_result["boundary_refinement_unresolved_corner_count"] = int(primitive_holes.get("boundary_refinement_unresolved_corner_count", 0))
		primitive_result["boundary_refinement_limit_reached"] = bool(primitive_holes.get("boundary_refinement_limit_reached", false))
		primitive_result["preserve_count"] += int(primitive_holes["preserve_count"])
		primitive_result["hole_count"] = primitive_holes["chains"].size()
		var primitive_cuts := _sample_cut_guides(cut_guides, recipe)
		for cut in primitive_cuts:
			if not bool(cut.get("valid", false)):
				return _failed_result(recipe, cut.get("errors", []), source_fingerprint(component, cut_guides, hole_components))
		primitive_result["cuts"] = primitive_cuts
		_arrange_cut_constraints(primitive_result)
		if not bool(primitive_result.get("valid", false)):
			return primitive_result
		_finalize_result_stats(primitive_result)
		return primitive_result
	var working_component := component.duplicate(true)
	BezierGeometry.resolve_auto_handles(working_component.get("points", []), working_component.get("chains", []))
	var errors := _validation_issues(working_component, allow_open)
	if not errors.is_empty():
		return _failed_result(recipe, errors, source_fingerprint(component, cut_guides, hole_components))
	var sampled_chains: Array = []
	var sample_count := 0
	var boundary_refinement_count := 0
	var boundary_refinement_complete := true
	var boundary_refinement_unresolved_corner_count := 0
	var boundary_refinement_limit_reached := false
	var preserved_ids: Dictionary = {}
	for chain_data in working_component.get("chains", []):
		var sampled_chain := _sample_chain(working_component, chain_data, recipe)
		if not bool(sampled_chain.get("valid", false)):
			errors.append_array(sampled_chain.get("errors", []))
			continue
		var samples: Array = sampled_chain.get("samples", [])
		sample_count += samples.size()
		boundary_refinement_count += int(sampled_chain.get("boundary_refinement_count", 0))
		boundary_refinement_complete = boundary_refinement_complete and bool(sampled_chain.get("boundary_refinement_complete", true))
		boundary_refinement_unresolved_corner_count += int(sampled_chain.get("boundary_refinement_unresolved_corner_count", 0))
		boundary_refinement_limit_reached = boundary_refinement_limit_reached or bool(sampled_chain.get("boundary_refinement_limit_reached", false))
		for sample in samples:
			var source_point_id := str(sample.get("source_point_id", ""))
			if bool(sample.get("preserved", false)) and not source_point_id.is_empty():
				preserved_ids[source_point_id] = true
		sampled_chains.append({
			"chain_id": str(chain_data.get("id", "")),
			"input_id": "",
			"topology_role": WorldDocumentService.topology_role(chain_data),
			"closed": bool(chain_data.get("closed", false)),
			"effective_spacing": float(recipe["parameters"]["spacing"]),
			"samples": samples
		})
	if not errors.is_empty():
		return _failed_result(recipe, errors, source_fingerprint(component, cut_guides, hole_components))
	var sampled_holes := _sample_hole_components(hole_components, recipe)
	if not sampled_holes["errors"].is_empty():
		return _failed_result(recipe, sampled_holes["errors"], source_fingerprint(component, cut_guides, hole_components))
	sampled_chains.append_array(sampled_holes["chains"])
	sample_count += int(sampled_holes["sample_count"])
	boundary_refinement_count += int(sampled_holes.get("boundary_refinement_count", 0))
	boundary_refinement_complete = boundary_refinement_complete and bool(sampled_holes.get("boundary_refinement_complete", true))
	boundary_refinement_unresolved_corner_count += int(sampled_holes.get("boundary_refinement_unresolved_corner_count", 0))
	boundary_refinement_limit_reached = boundary_refinement_limit_reached or bool(sampled_holes.get("boundary_refinement_limit_reached", false))
	var hole_preserved_ids: Dictionary = sampled_holes["preserved_ids"]
	for preserved_id in hole_preserved_ids:
		preserved_ids[str(preserved_id)] = true
	var cuts := _sample_cut_guides(cut_guides, recipe)
	for cut in cuts:
		if not bool(cut.get("valid", false)):
			errors.append_array(cut.get("errors", []))
	if not errors.is_empty():
		return _failed_result(recipe, errors, source_fingerprint(component, cut_guides, hole_components))
	var result := {
		"valid": true,
		"errors": [],
		"algorithm_version": ALGORITHM_VERSION,
		"method": recipe["method"],
		"parameters": recipe["parameters"].duplicate(true),
		"source_fingerprint": source_fingerprint(component, cut_guides, hole_components),
		"chains": sampled_chains,
		"cuts": cuts,
		"sample_count": sample_count,
		"boundary_refinement_count": boundary_refinement_count,
		"boundary_refinement_complete": boundary_refinement_complete,
		"boundary_refinement_unresolved_corner_count": boundary_refinement_unresolved_corner_count,
		"boundary_refinement_limit_reached": boundary_refinement_limit_reached,
		"preserve_count": preserved_ids.size(),
		"hole_count": sampled_holes["chains"].size()
	}
	_arrange_cut_constraints(result)
	if not bool(result.get("valid", false)):
		return result
	_finalize_result_stats(result)
	return result


static func validation_issues(component: Dictionary, cut_guides: Array = [], hole_components: Array = []) -> Array[String]:
	var errors: Array[String] = []
	if PrimitiveGeometryService.is_primitive(component):
		errors.append_array(PrimitiveGeometryService.validation_issues(component))
	else:
		errors.append_array(_validation_issues(component, false))
	for hole in hole_components:
		if not hole is Dictionary:
			continue
		var hole_errors: Array = []
		if not str(hole.get("sampling_error", "")).is_empty():
			hole_errors.append(str(hole.get("sampling_error", "")))
		elif PrimitiveGeometryService.is_primitive(hole):
			hole_errors.append_array(PrimitiveGeometryService.validation_issues(hole))
		else:
			hole_errors.append_array(_validation_issues(hole, false, false))
		for hole_error in hole_errors:
			errors.append(_hole_error(hole, str(hole_error)))
	for guide in cut_guides:
		if not guide is Dictionary or str(guide.get("guide_type", "")) != AssetGuide.CUT:
			continue
		var chains: Array = guide.get("chains", [])
		if chains.size() != 1:
			errors.append("A Cut Guide requires exactly one Chain.")
		else:
			errors.append_array(BezierTopology.validate(guide))
	return errors


static func source_fingerprint(component: Dictionary, cut_guides: Array = [], hole_components: Array = []) -> String:
	var parts: PackedStringArray = []
	for point_data in component.get("points", []):
		if not point_data is Dictionary:
			continue
		var position: Vector2 = point_data.get("position", Vector2.ZERO)
		var handle_in: Vector2 = point_data.get("handle_in", Vector2.ZERO)
		var handle_out: Vector2 = point_data.get("handle_out", Vector2.ZERO)
		parts.append("p|%s|%.9f|%.9f|%s|%d|%s|%.9f|%.9f|%.9f|%.9f" % [
			str(point_data.get("id", "")), WorldDocumentService.document_coordinate(position.x), WorldDocumentService.document_coordinate(position.y),
			str(point_data.get("mode", "linear")), int(bool(point_data.get("preserve_point", false))),
			str(point_data.get("handle_source", "auto")),
			WorldDocumentService.document_coordinate(handle_in.x), WorldDocumentService.document_coordinate(handle_in.y),
			WorldDocumentService.document_coordinate(handle_out.x), WorldDocumentService.document_coordinate(handle_out.y)
		])
	for edge_data in component.get("edges", []):
		if edge_data is Dictionary:
			parts.append("e|%s|%s|%s" % [str(edge_data.get("id", "")), str(edge_data.get("start_point_id", "")), str(edge_data.get("end_point_id", ""))])
	for chain_data in component.get("chains", []):
		if chain_data is Dictionary:
			parts.append("c|%s|%s|%s|%d|%s" % [
				str(chain_data.get("id", "")), ",".join(chain_data.get("point_ids", [])),
				",".join(chain_data.get("edge_ids", [])), int(bool(chain_data.get("closed", false))),
				WorldDocumentService.topology_role(chain_data)
			])
	parts.append("draw_mode|%s" % WorldDocumentService.component_draw_mode(component))
	for guide in cut_guides:
		if guide is Dictionary:
			parts.append("cut|%s|%s" % [str(guide.get("id", "")), source_fingerprint(guide)])
	for hole in hole_components:
		if hole is Dictionary:
			parts.append("hole|%s|%s" % [str(hole.get("id", "")), source_fingerprint(hole)])
	if PrimitiveGeometryService.has_analytic_shape(component):
		var primitive_center := PrimitiveGeometryService.center(component)
		var primitive_diameters_tool_units := PrimitiveGeometryService.diameters_tool_units(component)
		var primitive_diameters := Vector2(ToolUnits.to_centimeters(primitive_diameters_tool_units.x), ToolUnits.to_centimeters(primitive_diameters_tool_units.y))
		parts.append("primitive|%s|%.9f|%.9f|%.9f|%.9f" % [
			str(component.get("primitive", {}).get("type", "")),
			WorldDocumentService.document_coordinate(primitive_center.x),
			WorldDocumentService.document_coordinate(primitive_center.y),
			WorldDocumentService.document_coordinate(primitive_diameters.x),
			WorldDocumentService.document_coordinate(primitive_diameters.y)
		])
	# Preserve the pre-schema-40 constant fingerprint slot so unrelated accepted
	# closed meshes do not become stale. Component-local open widths no longer
	# participate in geometry after Ribbon migration.
	parts.append("ribbon_width_px|%.9f" % 8.0)
	var sampling_transform: Transform2D = component.get("sampling_transform", Transform2D.IDENTITY)
	parts.append("sampling_transform|%.9f|%.9f|%.9f|%.9f|%.9f|%.9f" % [
		WorldDocumentService.document_coordinate(sampling_transform.x.x), WorldDocumentService.document_coordinate(sampling_transform.x.y),
		WorldDocumentService.document_coordinate(sampling_transform.y.x), WorldDocumentService.document_coordinate(sampling_transform.y.y),
		WorldDocumentService.document_coordinate(sampling_transform.origin.x), WorldDocumentService.document_coordinate(sampling_transform.origin.y)
	])
	var hashing_context := HashingContext.new()
	hashing_context.start(HashingContext.HASH_SHA256)
	hashing_context.update("\n".join(parts).to_utf8_buffer())
	return hashing_context.finish().hex_encode()


static func _sample_hole_components(hole_components: Array, recipe: Dictionary) -> Dictionary:
	var sampled_chains: Array = []
	var errors: Array[String] = []
	var sample_count := 0
	var boundary_refinement_count := 0
	var boundary_refinement_complete := true
	var boundary_refinement_unresolved_corner_count := 0
	var boundary_refinement_limit_reached := false
	var preserved_ids: Dictionary = {}
	for hole_component in hole_components:
		if not hole_component is Dictionary:
			continue
		var working_hole: Dictionary = hole_component.duplicate(true)
		var input_id := str(hole_component.get("sampling_input_id", hole_component.get("id", "")))
		var hole_recipe := _recipe_for_input(recipe, input_id)
		if not str(working_hole.get("sampling_error", "")).is_empty():
			errors.append(_hole_error(working_hole, str(working_hole.get("sampling_error", ""))))
			continue
		if PrimitiveGeometryService.has_analytic_shape(working_hole):
			var sampled_circle := _sample_analytic_primitive(working_hole, hole_recipe, input_id, WorldDocumentService.ROLE_HOLE, str(hole_component.get("id", input_id)))
			if not bool(sampled_circle.get("valid", false)):
				for sampled_error in sampled_circle.get("errors", []):
					errors.append(_hole_error(working_hole, str(sampled_error)))
				continue
			var circle_samples: Array = sampled_circle.get("samples", [])
			sample_count += circle_samples.size()
			sampled_chains.append({"chain_id": "hole:%s:primitive:%s" % [str(hole_component.get("id", "")), str(working_hole.get("primitive", {}).get("type", ""))], "input_id": input_id, "topology_role": WorldDocumentService.ROLE_HOLE, "closed": true, "effective_spacing": sampled_circle["effective_spacing"], "samples": circle_samples})
			continue
		BezierGeometry.resolve_auto_handles(working_hole.get("points", []), working_hole.get("chains", []))
		var hole_errors := _validation_issues(working_hole, false, false)
		if not hole_errors.is_empty():
			for hole_error in hole_errors:
				errors.append(_hole_error(working_hole, str(hole_error)))
			continue
		for chain_data in working_hole.get("chains", []):
			var sampled_chain := _sample_chain(working_hole, chain_data, hole_recipe)
			if not bool(sampled_chain.get("valid", false)):
				for sampled_error in sampled_chain.get("errors", []):
					errors.append(_hole_error(working_hole, str(sampled_error)))
				continue
			var samples: Array = sampled_chain.get("samples", [])
			sample_count += samples.size()
			boundary_refinement_count += int(sampled_chain.get("boundary_refinement_count", 0))
			boundary_refinement_complete = boundary_refinement_complete and bool(sampled_chain.get("boundary_refinement_complete", true))
			boundary_refinement_unresolved_corner_count += int(sampled_chain.get("boundary_refinement_unresolved_corner_count", 0))
			boundary_refinement_limit_reached = boundary_refinement_limit_reached or bool(sampled_chain.get("boundary_refinement_limit_reached", false))
			for sample in samples:
				var source_point_id := str(sample.get("source_point_id", ""))
				if bool(sample.get("preserved", false)) and not source_point_id.is_empty():
					preserved_ids[source_point_id] = true
			sampled_chains.append({
				"chain_id": "hole:%s:%s" % [str(hole_component.get("id", "")), str(chain_data.get("id", ""))],
				"input_id": input_id,
				"topology_role": WorldDocumentService.ROLE_HOLE,
				"closed": bool(chain_data.get("closed", false)),
				"effective_spacing": float(hole_recipe["parameters"]["spacing"]),
				"samples": samples
			})
	return {"chains": sampled_chains, "errors": errors, "sample_count": sample_count, "preserve_count": preserved_ids.size(), "preserved_ids": preserved_ids, "boundary_refinement_count": boundary_refinement_count, "boundary_refinement_complete": boundary_refinement_complete, "boundary_refinement_unresolved_corner_count": boundary_refinement_unresolved_corner_count, "boundary_refinement_limit_reached": boundary_refinement_limit_reached}


static func _sample_cut_guides(cut_guides: Array, recipe: Dictionary) -> Array:
	var results: Array = []
	for guide in cut_guides:
		if not guide is Dictionary:
			continue
		var chains: Array = guide.get("chains", [])
		if str(guide.get("guide_type", "")) != AssetGuide.CUT or chains.size() != 1:
			continue
		var guide_recipe := _recipe_for_input(recipe, str(guide.get("id", "")))
		var sampled := _sample_chain(guide, chains[0], guide_recipe)
		if not bool(sampled.get("valid", false)):
			results.append({"valid": false, "errors": sampled.get("errors", []), "guide_id": str(guide.get("id", "")), "samples": []})
			continue
		var samples: Array = []
		for sample_index in range(sampled.get("samples", []).size()):
			var source_sample: Dictionary = sampled["samples"][sample_index]
			var cut_sample := source_sample.duplicate(true)
			cut_sample["id"] = "cut:%s:%d" % [str(guide.get("id", "")), sample_index]
			cut_sample["guide_id"] = str(guide.get("id", ""))
			samples.append(cut_sample)
		results.append({"valid": true, "errors": [], "guide_id": str(guide.get("id", "")), "input_id": str(guide.get("id", "")), "effective_spacing": float(guide_recipe["parameters"]["spacing"]), "samples": samples})
	return results


static func cut_fragments(cut_data: Dictionary) -> Array:
	var fragments = cut_data.get("fragments", [])
	if fragments is Array and not fragments.is_empty():
		return fragments
	var samples: Array = cut_data.get("samples", [])
	return [{"id": "cut:%s:fragment:0" % str(cut_data.get("guide_id", "")), "samples": samples}] if samples.size() >= 2 else []


static func _arrange_cut_constraints(result: Dictionary) -> void:
	var chains: Array = result.get("chains", [])
	var cuts: Array = result.get("cuts", [])
	if cuts.is_empty():
		return
	var chain_insertions: Array = []
	for chain_data in chains:
		chain_insertions.append(_empty_segment_insertions(chain_data.get("samples", []).size()))
	var cut_insertions: Array = []
	for cut_data in cuts:
		cut_insertions.append(_empty_segment_insertions(maxi(cut_data.get("samples", []).size() - 1, 0)))

	for cut_index in range(cuts.size()):
		var cut_samples: Array = cuts[cut_index].get("samples", [])
		for cut_segment in range(maxi(cut_samples.size() - 1, 0)):
			var cut_start := Vector2(cut_samples[cut_segment].get("position", Vector2.ZERO))
			var cut_end := Vector2(cut_samples[cut_segment + 1].get("position", Vector2.ZERO))
			for chain_index in range(chains.size()):
				var chain_samples: Array = chains[chain_index].get("samples", [])
				var chain_segments := chain_samples.size() if bool(chains[chain_index].get("closed", false)) else maxi(chain_samples.size() - 1, 0)
				for chain_segment in range(chain_segments):
					var chain_start := Vector2(chain_samples[chain_segment].get("position", Vector2.ZERO))
					var chain_end := Vector2(chain_samples[(chain_segment + 1) % chain_samples.size()].get("position", Vector2.ZERO))
					var intersection := _segment_intersection(cut_start, cut_end, chain_start, chain_end)
					if intersection.is_empty():
						continue
					var junction := _junction_sample(Vector2(intersection["position"]), str(cuts[cut_index].get("guide_id", "")))
					cut_insertions[cut_index][cut_segment].append({"t": float(intersection["first_t"]), "sample": junction.duplicate(true)})
					chain_insertions[chain_index][chain_segment].append({"t": float(intersection["second_t"]), "sample": junction.duplicate(true)})

	for first_cut in range(cuts.size()):
		var first_samples: Array = cuts[first_cut].get("samples", [])
		for second_cut in range(first_cut + 1, cuts.size()):
			var second_samples: Array = cuts[second_cut].get("samples", [])
			for first_segment in range(maxi(first_samples.size() - 1, 0)):
				for second_segment in range(maxi(second_samples.size() - 1, 0)):
					var intersection := _segment_intersection(
						Vector2(first_samples[first_segment].get("position", Vector2.ZERO)),
						Vector2(first_samples[first_segment + 1].get("position", Vector2.ZERO)),
						Vector2(second_samples[second_segment].get("position", Vector2.ZERO)),
						Vector2(second_samples[second_segment + 1].get("position", Vector2.ZERO)))
					if intersection.is_empty():
						continue
					var junction := _junction_sample(Vector2(intersection["position"]), "cut-crossing")
					cut_insertions[first_cut][first_segment].append({"t": float(intersection["first_t"]), "sample": junction.duplicate(true)})
					cut_insertions[second_cut][second_segment].append({"t": float(intersection["second_t"]), "sample": junction.duplicate(true)})

	for chain_index in range(chains.size()):
		chains[chain_index]["samples"] = _rebuild_samples(
			chains[chain_index].get("samples", []), chain_insertions[chain_index], bool(chains[chain_index].get("closed", false)), "")
	for cut_index in range(cuts.size()):
		var guide_id := str(cuts[cut_index].get("guide_id", ""))
		var arranged := _rebuild_samples(cuts[cut_index].get("samples", []), cut_insertions[cut_index], false, guide_id)
		var fragments := _clip_cut_fragments(arranged, chains, guide_id)
		cuts[cut_index]["fragments"] = fragments
		cuts[cut_index]["samples"] = _flatten_fragment_samples(fragments)
		if fragments.is_empty():
			cuts[cut_index]["valid"] = false
			cuts[cut_index]["errors"] = ["Cut %s does not cross the sampled meshing domain." % guide_id]
			result["valid"] = false
			result["errors"].append_array(cuts[cut_index]["errors"])
	result["chains"] = chains
	result["cuts"] = cuts
	result["sample_count"] = _chain_sample_count(chains)


static func _empty_segment_insertions(segment_count: int) -> Array:
	var result: Array = []
	for _index in range(segment_count):
		result.append([])
	return result


static func _segment_intersection(first_start: Vector2, first_end: Vector2, second_start: Vector2, second_end: Vector2) -> Dictionary:
	var first_delta := first_end - first_start
	var second_delta := second_end - second_start
	var denominator := first_delta.cross(second_delta)
	if absf(denominator) <= ARRANGEMENT_EPSILON:
		return {}
	var offset := second_start - first_start
	var first_t := offset.cross(second_delta) / denominator
	var second_t := offset.cross(first_delta) / denominator
	if first_t < -ARRANGEMENT_EPSILON or first_t > 1.0 + ARRANGEMENT_EPSILON \
		or second_t < -ARRANGEMENT_EPSILON or second_t > 1.0 + ARRANGEMENT_EPSILON:
		return {}
	first_t = clampf(first_t, 0.0, 1.0)
	second_t = clampf(second_t, 0.0, 1.0)
	return {"first_t": first_t, "second_t": second_t, "position": first_start + first_delta * first_t}


static func _junction_sample(position: Vector2, guide_id: String) -> Dictionary:
	var junction_id := "junction:%d:%d" % [roundi(position.x / ARRANGEMENT_EPSILON), roundi(position.y / ARRANGEMENT_EPSILON)]
	return {
		"id": junction_id,
		"position": position,
		"edge_id": "",
		"curve_t": 0.0,
		"source_point_id": "",
		"preserved": true,
		"junction": true,
		"guide_id": guide_id
	}


static func _rebuild_samples(samples: Array, insertions: Array, closed: bool, guide_id: String) -> Array:
	if samples.size() < 2:
		return samples.duplicate(true)
	var working := samples.duplicate(true)
	for segment_index in range(insertions.size()):
		for insertion in insertions[segment_index]:
			var t := float(insertion.get("t", 0.0))
			var inserted: Dictionary = insertion.get("sample", {})
			if t <= ARRANGEMENT_EPSILON:
				working[segment_index]["position"] = inserted.get("position", working[segment_index].get("position", Vector2.ZERO))
				working[segment_index]["junction"] = true
			elif t >= 1.0 - ARRANGEMENT_EPSILON:
				var next_index := (segment_index + 1) % working.size()
				working[next_index]["position"] = inserted.get("position", working[next_index].get("position", Vector2.ZERO))
				working[next_index]["junction"] = true
	var rebuilt: Array = []
	for segment_index in range(insertions.size()):
		if rebuilt.is_empty() or not Vector2(rebuilt.back().get("position", Vector2.ZERO)).is_equal_approx(Vector2(working[segment_index].get("position", Vector2.ZERO))):
			rebuilt.append(working[segment_index].duplicate(true))
		var ordered: Array = insertions[segment_index].duplicate(true)
		ordered.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return float(first.get("t", 0.0)) < float(second.get("t", 0.0)))
		for insertion in ordered:
			var t := float(insertion.get("t", 0.0))
			if t <= ARRANGEMENT_EPSILON or t >= 1.0 - ARRANGEMENT_EPSILON:
				continue
			var inserted: Dictionary = insertion.get("sample", {}).duplicate(true)
			if not guide_id.is_empty():
				inserted["guide_id"] = guide_id
			if rebuilt.is_empty() or Vector2(rebuilt.back().get("position", Vector2.ZERO)).distance_squared_to(Vector2(inserted.get("position", Vector2.ZERO))) > ARRANGEMENT_EPSILON * ARRANGEMENT_EPSILON:
				rebuilt.append(inserted)
	if not closed:
		var last: Dictionary = working.back().duplicate(true)
		if rebuilt.is_empty() or Vector2(rebuilt.back().get("position", Vector2.ZERO)).distance_squared_to(Vector2(last.get("position", Vector2.ZERO))) > ARRANGEMENT_EPSILON * ARRANGEMENT_EPSILON:
			rebuilt.append(last)
	for index in range(rebuilt.size()):
		if not guide_id.is_empty():
			rebuilt[index]["guide_id"] = guide_id
			rebuilt[index]["id"] = "cut:%s:%d" % [guide_id, index]
	return rebuilt


static func _clip_cut_fragments(samples: Array, chains: Array, guide_id: String) -> Array:
	var fragments: Array = []
	var current: Array = []
	for segment_index in range(maxi(samples.size() - 1, 0)):
		var first: Dictionary = samples[segment_index]
		var second: Dictionary = samples[segment_index + 1]
		var midpoint := (Vector2(first.get("position", Vector2.ZERO)) + Vector2(second.get("position", Vector2.ZERO))) * 0.5
		if _point_inside_sampled_domain(midpoint, chains):
			if current.is_empty():
				current.append(first.duplicate(true))
			current.append(second.duplicate(true))
		elif current.size() >= 2:
			fragments.append({"id": "cut:%s:fragment:%d" % [guide_id, fragments.size()], "samples": current})
			current = []
	if current.size() >= 2:
		fragments.append({"id": "cut:%s:fragment:%d" % [guide_id, fragments.size()], "samples": current})
	return fragments


static func _point_inside_sampled_domain(position: Vector2, chains: Array) -> bool:
	var inside_outer := false
	for chain_data in chains:
		var polygon := PackedVector2Array()
		for sample in chain_data.get("samples", []):
			polygon.append(Vector2(sample.get("position", Vector2.ZERO)))
		if polygon.size() < 3:
			continue
		var inside := Geometry2D.is_point_in_polygon(position, polygon)
		if WorldDocumentService.topology_role(chain_data) == WorldDocumentService.ROLE_OUTER:
			inside_outer = inside_outer or inside
		elif inside:
			return false
	return inside_outer


static func _flatten_fragment_samples(fragments: Array) -> Array:
	var flattened: Array = []
	for fragment in fragments:
		for sample in fragment.get("samples", []):
			flattened.append(sample.duplicate(true))
	return flattened


static func _chain_sample_count(chains: Array) -> int:
	var count := 0
	for chain_data in chains:
		count += chain_data.get("samples", []).size()
	return count


static func _recipe_for_input(recipe: Dictionary, input_id: String) -> Dictionary:
	var result := {
		"method": ADAPTIVE,
		"parameters": {
			"spacing": float(recipe.get("parameters", {}).get("spacing", DEFAULT_SPACING)),
			"feature_detail": float(recipe.get("parameters", {}).get("feature_detail", DEFAULT_FEATURE_DETAIL)),
			"density_factor": 1.0
		}
	}
	var refinements: Dictionary = recipe.get("parameters", {}).get("boundary_refinements", {})
	if not input_id.is_empty() and refinements.has(input_id) and refinements[input_id] is Dictionary:
		var factor := clampf(float(refinements[input_id].get("factor", 1.0)), MIN_REFINEMENT_FACTOR, MAX_REFINEMENT_FACTOR)
		result["parameters"]["spacing"] = maxf(float(result["parameters"]["spacing"]) / factor, MIN_SPACING)
		result["parameters"]["density_factor"] = factor
	return result


static func _validation_issues(component: Dictionary, allow_open := false, require_outer := true) -> Array[String]:
	var errors: Array[String] = BezierTopology.validate(component)
	var chains: Array = component.get("chains", [])
	if chains.is_empty():
		errors.append("The Component has no Chain to sample.")
		return errors
	var has_valid_outer := false
	for chain_data in chains:
		if not chain_data is Dictionary:
			continue
		if not allow_open and not bool(chain_data.get("closed", false)):
			errors.append("Sampling for the mesh pipeline requires closed Chains.")
		if WorldDocumentService.topology_role(chain_data) == WorldDocumentService.ROLE_OUTER and (bool(chain_data.get("closed", false)) or allow_open):
			has_valid_outer = true
		var chain_point_ids: Array = chain_data.get("point_ids", [])
		var neighbor_count := chain_point_ids.size() if bool(chain_data.get("closed", false)) else maxi(chain_point_ids.size() - 1, 0)
		for point_index in range(neighbor_count):
			var first := BezierTopology.point_by_id(component.get("points", []), str(chain_point_ids[point_index]))
			var second := BezierTopology.point_by_id(component.get("points", []), str(chain_point_ids[(point_index + 1) % chain_point_ids.size()]))
			if bool(first.get("preserve_point", false)) and bool(second.get("preserve_point", false)) \
				and Vector2(first.get("position", Vector2.ZERO)).is_equal_approx(Vector2(second.get("position", Vector2.ZERO))):
				errors.append("Consecutive Preserve Points may not occupy the same position.")
	if require_outer and not has_valid_outer:
		errors.append("The Component needs an outer Chain.")
	if not require_outer and not has_valid_outer:
		for chain_data in chains:
			if WorldDocumentService.topology_role(chain_data) != WorldDocumentService.ROLE_HOLE or not bool(chain_data.get("closed", false)):
				errors.append("A Hole input requires one closed Hole Chain.")
	return errors


static func _sample_chain(component: Dictionary, chain_data: Dictionary, recipe: Dictionary) -> Dictionary:
	var points: Array = component.get("points", [])
	var edges: Array = component.get("edges", [])
	var samples: Array = []
	var point_ids: Array = chain_data.get("point_ids", [])
	var edge_ids: Array = chain_data.get("edge_ids", [])
	if point_ids.is_empty() or edge_ids.is_empty():
		return {"valid": false, "errors": ["A sampled Chain has no ordered Points or Edges."]}
	for edge_index in range(edge_ids.size()):
		var edge_id := str(edge_ids[edge_index])
		var edge := BezierTopology.edge_by_id(edges, edge_id)
		var start_id := str(edge.get("start_point_id", ""))
		var end_id := str(edge.get("end_point_id", ""))
		var start_point := BezierTopology.point_by_id(points, start_id)
		var end_point := BezierTopology.point_by_id(points, end_id)
		if edge.is_empty() or start_point.is_empty() or end_point.is_empty():
			return {"valid": false, "errors": ["Chain %s contains an unresolved Edge." % str(chain_data.get("id", ""))]}
		if samples.is_empty():
			samples.append(_source_sample(edge_id, 0.0, start_point))
		var controls := BezierGeometry.cubic_controls(start_point, end_point)
		var edge_samples := _sample_adaptive_edge(controls, edge_id, end_point, recipe["parameters"])
		samples.append_array(edge_samples)
		if samples.size() > MAX_SAMPLES_PER_CHAIN:
			return {"valid": false, "errors": ["Sampling exceeded the safety limit of %d Points per Chain." % MAX_SAMPLES_PER_CHAIN]}
	if bool(chain_data.get("closed", false)) and samples.size() > 1:
		var first_source := str(samples.front().get("source_point_id", ""))
		var last_source := str(samples.back().get("source_point_id", ""))
		if not first_source.is_empty() and first_source == last_source:
			samples.pop_back()
	var boundary_refinement_count := 0
	var boundary_refinement_complete := true
	var boundary_refinement_unresolved_corner_count := 0
	var boundary_refinement_limit_reached := false
	if bool(chain_data.get("closed", false)):
		var balanced := _balance_corner_segment_lengths(samples, component, chain_data)
		samples = balanced.get("samples", samples)
		boundary_refinement_count = int(balanced.get("added_sample_count", 0))
		boundary_refinement_complete = bool(balanced.get("complete", true))
		boundary_refinement_unresolved_corner_count = int(balanced.get("unresolved_corner_count", 0))
		boundary_refinement_limit_reached = bool(balanced.get("limit_reached", false))
	return {"valid": true, "errors": [], "samples": samples, "boundary_refinement_count": boundary_refinement_count, "boundary_refinement_complete": boundary_refinement_complete, "boundary_refinement_unresolved_corner_count": boundary_refinement_unresolved_corner_count, "boundary_refinement_limit_reached": boundary_refinement_limit_reached}


static func _balance_corner_segment_lengths(source_samples: Array, component: Dictionary, chain_data: Dictionary) -> Dictionary:
	var samples: Array = source_samples.duplicate(true)
	var added_sample_count := 0
	var blocked_segments: Dictionary = {}
	while samples.size() >= 3 and samples.size() < MAX_SAMPLES_PER_CHAIN and added_sample_count < MAX_CORNER_REFINEMENTS_PER_CHAIN:
		var selected_segment := -1
		var selected_ratio := MAX_ADJACENT_CORNER_SEGMENT_RATIO
		for corner_index in range(samples.size()):
			if str(samples[corner_index].get("source_point_id", "")).is_empty():
				continue
			var previous_index := posmod(corner_index - 1, samples.size())
			var next_index := (corner_index + 1) % samples.size()
			var corner_position := Vector2(samples[corner_index].get("position", Vector2.ZERO))
			var previous_length := corner_position.distance_to(Vector2(samples[previous_index].get("position", Vector2.ZERO)))
			var next_length := corner_position.distance_to(Vector2(samples[next_index].get("position", Vector2.ZERO)))
			var shorter := minf(previous_length, next_length)
			if shorter <= ARRANGEMENT_EPSILON:
				continue
			var ratio := maxf(previous_length, next_length) / shorter
			if ratio <= selected_ratio:
				continue
			var candidate_segment := previous_index if previous_length > next_length else corner_index
			var candidate_end := (candidate_segment + 1) % samples.size()
			if blocked_segments.has(_sample_segment_key(samples[candidate_segment], samples[candidate_end])):
				continue
			selected_ratio = ratio
			selected_segment = candidate_segment
		if selected_segment < 0:
			break
		var end_index := (selected_segment + 1) % samples.size()
		var segment_key := _sample_segment_key(samples[selected_segment], samples[end_index])
		var inserted := _curve_midpoint_sample(samples[selected_segment], samples[end_index], component, chain_data)
		if inserted.is_empty():
			blocked_segments[segment_key] = true
			continue
		if end_index == 0:
			samples.append(inserted)
		else:
			samples.insert(end_index, inserted)
		added_sample_count += 1
	var unresolved_corner_count := _unbalanced_corner_count(samples)
	return {
		"samples": samples,
		"added_sample_count": added_sample_count,
		"complete": unresolved_corner_count == 0,
		"unresolved_corner_count": unresolved_corner_count,
		"limit_reached": unresolved_corner_count > 0 and (samples.size() >= MAX_SAMPLES_PER_CHAIN or added_sample_count >= MAX_CORNER_REFINEMENTS_PER_CHAIN)
	}


static func _sample_segment_key(first_sample: Dictionary, second_sample: Dictionary) -> String:
	return "%s>%s" % [str(first_sample.get("id", "")), str(second_sample.get("id", ""))]


static func _unbalanced_corner_count(samples: Array) -> int:
	var count := 0
	for corner_index in range(samples.size()):
		if str(samples[corner_index].get("source_point_id", "")).is_empty():
			continue
		var corner_position := Vector2(samples[corner_index].get("position", Vector2.ZERO))
		var previous_length := corner_position.distance_to(Vector2(samples[posmod(corner_index - 1, samples.size())].get("position", Vector2.ZERO)))
		var next_length := corner_position.distance_to(Vector2(samples[(corner_index + 1) % samples.size()].get("position", Vector2.ZERO)))
		var shorter := minf(previous_length, next_length)
		if shorter > ARRANGEMENT_EPSILON and maxf(previous_length, next_length) / shorter > MAX_ADJACENT_CORNER_SEGMENT_RATIO:
			count += 1
	return count


static func _curve_midpoint_sample(first_sample: Dictionary, second_sample: Dictionary, component: Dictionary, chain_data: Dictionary) -> Dictionary:
	var first_edge_id := str(first_sample.get("edge_id", ""))
	var second_edge_id := str(second_sample.get("edge_id", ""))
	var first_source_id := str(first_sample.get("source_point_id", ""))
	var second_source_id := str(second_sample.get("source_point_id", ""))
	var edge_id := ""
	var first_t := 0.0
	var second_t := 1.0
	if not first_source_id.is_empty() and not second_source_id.is_empty():
		for chain_edge_id in chain_data.get("edge_ids", []):
			var candidate := BezierTopology.edge_by_id(component.get("edges", []), str(chain_edge_id))
			if str(candidate.get("start_point_id", "")) == first_source_id and str(candidate.get("end_point_id", "")) == second_source_id:
				edge_id = str(chain_edge_id)
				break
	elif not first_edge_id.is_empty() and first_edge_id == second_edge_id:
		edge_id = first_edge_id
		first_t = float(first_sample.get("curve_t", 0.0))
		second_t = float(second_sample.get("curve_t", 1.0))
	elif not second_source_id.is_empty() and not first_edge_id.is_empty():
		edge_id = first_edge_id
		first_t = float(first_sample.get("curve_t", 0.0))
		second_t = 1.0
	elif not first_source_id.is_empty() and not second_edge_id.is_empty():
		edge_id = second_edge_id
		first_t = 0.0
		second_t = float(second_sample.get("curve_t", 1.0))
	if edge_id.is_empty() or second_t <= first_t + ARRANGEMENT_EPSILON:
		return {}
	var edge := BezierTopology.edge_by_id(component.get("edges", []), edge_id)
	if edge.is_empty():
		return {}
	var start_point := BezierTopology.point_by_id(component.get("points", []), str(edge.get("start_point_id", "")))
	var end_point := BezierTopology.point_by_id(component.get("points", []), str(edge.get("end_point_id", "")))
	if start_point.is_empty() or end_point.is_empty():
		return {}
	var curve_t := (first_t + second_t) * 0.5
	var position := BezierGeometry.cubic_position(BezierGeometry.cubic_controls(start_point, end_point), curve_t)
	if position.distance_to(Vector2(first_sample.get("position", Vector2.ZERO))) <= ARRANGEMENT_EPSILON \
		or position.distance_to(Vector2(second_sample.get("position", Vector2.ZERO))) <= ARRANGEMENT_EPSILON:
		return {}
	return _curve_sample(edge_id, curve_t, position)


static func _sample_analytic_primitive(component: Dictionary, recipe: Dictionary, input_id: String, role: String, sample_namespace: String = "") -> Dictionary:
	var spacing := float(recipe.get("parameters", {}).get("spacing", DEFAULT_SPACING))
	var detail := float(recipe.get("parameters", {}).get("feature_detail", DEFAULT_FEATURE_DETAIL))
	var density_factor := maxf(float(recipe.get("parameters", {}).get("density_factor", 1.0)), MIN_REFINEMENT_FACTOR)
	var flatness_tolerance := spacing * (0.1 * pow(0.025, detail)) / density_factor
	var turn_tolerance := deg_to_rad(clampf(lerpf(90.0, 15.0, detail) / density_factor, 0.5, 120.0))
	var transform: Transform2D = component.get("sampling_transform", Transform2D.IDENTITY)
	var center := PrimitiveGeometryService.center(component)
	var radii := PrimitiveGeometryService.diameters_tool_units(component) * 0.5
	var primitive_type := str(component.get("primitive", {}).get("type", ""))
	var samples: Array
	var corners := PrimitiveGeometryService.corners(component)
	if not corners.is_empty():
		# A Rectangle and a Triangle are exact polygons: only Target Edge Length
		# subdivides their sides, because a straight side has no curvature that
		# Curve Detail could refine.
		samples = [{"position": transform * corners[0]}]
		for side in range(corners.size()):
			_append_adaptive_straight_edge(samples, transform, corners[side], corners[(side + 1) % corners.size()], spacing, 0)
			if samples.size() > MAX_SAMPLES_PER_CHAIN:
				return {"valid": false, "errors": ["Sampling exceeded the safety limit of %d Points per Chain." % MAX_SAMPLES_PER_CHAIN]}
	else:
		samples = [{"position": transform * (center + Vector2.RIGHT * radii.x)}]
		for quadrant in range(4):
			var angle_start := TAU * float(quadrant) / 4.0
			var angle_end := TAU * float(quadrant + 1) / 4.0
			_append_adaptive_ellipse_segment(samples, transform, center, radii, angle_start, angle_end, spacing, flatness_tolerance, turn_tolerance, 0)
			if samples.size() > MAX_SAMPLES_PER_CHAIN:
				return {"valid": false, "errors": ["Sampling exceeded the safety limit of %d Points per Chain." % MAX_SAMPLES_PER_CHAIN]}
	if samples.size() > 1:
		samples.pop_back()
	# A curve is only ever a closed boundary once it has four samples; a polygon
	# already is one at its own corner count, and a Triangle has three.
	var minimum_samples := corners.size() if not corners.is_empty() else 4
	if samples.size() < minimum_samples:
		return {"valid": false, "errors": ["A sampled analytic Primitive requires at least %d boundary Points." % minimum_samples]}
	var resolved_namespace := sample_namespace if not sample_namespace.is_empty() else (input_id if not input_id.is_empty() else "outer")
	for index in range(samples.size()):
		samples[index] = {
			"id": "sample:%s:%s:%d" % [primitive_type, resolved_namespace, index],
			"position": Vector2(samples[index].get("position", Vector2.ZERO)),
			"edge_id": "primitive:%s" % primitive_type,
			"curve_t": float(index) / float(samples.size()),
			"source_point_id": "",
			"preserved": false
		}
	return {"valid": true, "errors": [], "samples": samples, "role": role, "effective_spacing": spacing}


static func _hole_error(hole: Dictionary, error: String) -> String:
	var label := str(hole.get("sampling_input_label", "")).strip_edges()
	return error if label.is_empty() else "%s: %s" % [label, error]


static func _append_adaptive_straight_edge(result: Array, transform: Transform2D, edge_start: Vector2, edge_end: Vector2, spacing: float, depth: int) -> void:
	var start := transform * edge_start
	var end := transform * edge_end
	if start.distance_to(end) > spacing and depth < MAX_ADAPTIVE_DEPTH and result.size() < MAX_SAMPLES_PER_CHAIN:
		var midpoint := edge_start.lerp(edge_end, 0.5)
		_append_adaptive_straight_edge(result, transform, edge_start, midpoint, spacing, depth + 1)
		_append_adaptive_straight_edge(result, transform, midpoint, edge_end, spacing, depth + 1)
		return
	result.append({"position": end})


static func _append_adaptive_ellipse_segment(result: Array, transform: Transform2D, center: Vector2, radii: Vector2, angle_start: float, angle_end: float, spacing: float, flatness_tolerance: float, turn_tolerance: float, depth: int) -> void:
	var start := transform * (center + Vector2(cos(angle_start) * radii.x, sin(angle_start) * radii.y))
	var end := transform * (center + Vector2(cos(angle_end) * radii.x, sin(angle_end) * radii.y))
	var angle_mid := (angle_start + angle_end) * 0.5
	var midpoint := transform * (center + Vector2(cos(angle_mid) * radii.x, sin(angle_mid) * radii.y))
	var tangent_start := transform.basis_xform(Vector2(-sin(angle_start) * radii.x, cos(angle_start) * radii.y)).normalized()
	var tangent_end := transform.basis_xform(Vector2(-sin(angle_end) * radii.x, cos(angle_end) * radii.y)).normalized()
	var should_split := start.distance_to(end) > spacing \
		or midpoint.distance_to((start + end) * 0.5) > flatness_tolerance \
		or absf(tangent_start.angle_to(tangent_end)) > turn_tolerance
	if should_split and depth < MAX_ADAPTIVE_DEPTH and result.size() < MAX_SAMPLES_PER_CHAIN:
		_append_adaptive_ellipse_segment(result, transform, center, radii, angle_start, angle_mid, spacing, flatness_tolerance, turn_tolerance, depth + 1)
		_append_adaptive_ellipse_segment(result, transform, center, radii, angle_mid, angle_end, spacing, flatness_tolerance, turn_tolerance, depth + 1)
		return
	result.append({"position": end})


static func _finalize_result_stats(result: Dictionary) -> void:
	var stats: Array = []
	var constraint_count := 0
	for chain_data in result.get("chains", []):
		var count: int = chain_data.get("samples", []).size()
		constraint_count += count
		stats.append({
			"input_id": str(chain_data.get("input_id", "")),
			"role": WorldDocumentService.topology_role(chain_data),
			"effective_spacing": float(chain_data.get("effective_spacing", result.get("parameters", {}).get("spacing", DEFAULT_SPACING))),
			"sample_count": count
		})
	for cut in result.get("cuts", []):
		var count: int = cut.get("samples", []).size()
		constraint_count += count
		stats.append({"input_id": str(cut.get("input_id", cut.get("guide_id", ""))), "role": "cut", "effective_spacing": float(cut.get("effective_spacing", result.get("parameters", {}).get("spacing", DEFAULT_SPACING))), "sample_count": count})
	result["boundary_stats"] = stats
	result["constraint_sample_count"] = constraint_count


static func _sample_adaptive_edge(controls: Array[Vector2], edge_id: String, end_point: Dictionary, parameters: Dictionary) -> Array:
	var result: Array = []
	var spacing := float(parameters.get("spacing", DEFAULT_SPACING))
	var detail := float(parameters.get("feature_detail", DEFAULT_FEATURE_DETAIL))
	var density_factor := maxf(float(parameters.get("density_factor", 1.0)), MIN_REFINEMENT_FACTOR)
	var flatness_tolerance := spacing * (0.1 * pow(0.025, detail)) / density_factor
	var turn_tolerance := deg_to_rad(clampf(lerpf(90.0, 15.0, detail) / density_factor, 0.5, 120.0))
	_append_adaptive_segment(result, controls, edge_id, 0.0, 1.0, spacing, flatness_tolerance, turn_tolerance, 0)
	if not result.is_empty():
		result[result.size() - 1] = _source_sample(edge_id, 1.0, end_point)
	return result


static func _append_adaptive_segment(result: Array, controls: Array[Vector2], edge_id: String, t_start: float, t_end: float, spacing: float, flatness_tolerance: float, turn_tolerance: float, depth: int) -> void:
	var chord_length := controls[0].distance_to(controls[3])
	var should_split := chord_length > spacing \
		or BezierGeometry.cubic_flatness(controls) > flatness_tolerance \
		or BezierGeometry.cubic_tangent_turn(controls) > turn_tolerance
	if should_split and depth < MAX_ADAPTIVE_DEPTH and result.size() < MAX_SAMPLES_PER_CHAIN:
		var halves := BezierGeometry.split_cubic_controls(controls)
		var t_mid := (t_start + t_end) * 0.5
		_append_adaptive_segment(result, halves[0], edge_id, t_start, t_mid, spacing, flatness_tolerance, turn_tolerance, depth + 1)
		_append_adaptive_segment(result, halves[1], edge_id, t_mid, t_end, spacing, flatness_tolerance, turn_tolerance, depth + 1)
		return
	result.append(_curve_sample(edge_id, t_end, controls[3]))


static func _source_sample(edge_id: String, t: float, point: Dictionary) -> Dictionary:
	var point_id := str(point.get("id", ""))
	return {
		"id": "sample:%s:%s" % [edge_id, point_id],
		"position": Vector2(point.get("position", Vector2.ZERO)),
		"edge_id": edge_id,
		"curve_t": t,
		"source_point_id": point_id,
		"preserved": bool(point.get("preserve_point", false))
	}


static func _curve_sample(edge_id: String, t: float, position: Vector2) -> Dictionary:
	return {
		"id": "sample:%s:%.9f" % [edge_id, t],
		"position": position,
		"edge_id": edge_id,
		"curve_t": t,
		"source_point_id": "",
		"preserved": false
	}


static func _failed_result(recipe: Dictionary, errors: Array[String], fingerprint: String) -> Dictionary:
	return {
		"valid": false,
		"errors": errors,
		"algorithm_version": ALGORITHM_VERSION,
		"method": recipe["method"],
		"parameters": recipe["parameters"].duplicate(true),
		"source_fingerprint": fingerprint,
		"chains": [],
		"sample_count": 0,
		"boundary_refinement_count": 0,
		"boundary_refinement_complete": false,
		"boundary_refinement_unresolved_corner_count": 0,
		"boundary_refinement_limit_reached": false,
		"preserve_count": 0
	}
