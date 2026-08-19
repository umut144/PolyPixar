class_name GeometrySamplingService
extends RefCounted

const ADAPTIVE := "adaptive"
const EVEN_SPACING := "even_spacing"
const VALID_METHODS := [ADAPTIVE]
const DEFAULT_SPACING := 1.0
const DEFAULT_FEATURE_DETAIL := 0.5
const MIN_SPACING := 0.01
const MIN_REFINEMENT_FACTOR := 0.25
const MAX_REFINEMENT_FACTOR := 16.0
const MAX_SAMPLES_PER_CHAIN := 20000
const MAX_ADAPTIVE_DEPTH := 18


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
	if PrimitiveGeometryService.has_circle(component):
		var sampled_circle := _sample_circle(component, recipe, "", "outer")
		if not bool(sampled_circle.get("valid", false)):
			return _failed_result(recipe, sampled_circle.get("errors", []), source_fingerprint(component, cut_guides, hole_components))
		var samples: Array = sampled_circle.get("samples", [])
		var primitive_result := {
			"valid": true, "errors": [], "method": recipe["method"], "parameters": recipe["parameters"].duplicate(true),
			"source_fingerprint": source_fingerprint(component, cut_guides, hole_components), "chains": [{"chain_id": "primitive:circle", "input_id": "", "topology_role": "outer", "closed": true, "effective_spacing": sampled_circle["effective_spacing"], "samples": samples}], "cuts": [],
			"sample_count": samples.size(), "preserve_count": 0
		}
		var primitive_holes := _sample_hole_components(hole_components, recipe)
		if not primitive_holes["errors"].is_empty():
			return _failed_result(recipe, primitive_holes["errors"], source_fingerprint(component, cut_guides, hole_components))
		primitive_result["chains"].append_array(primitive_holes["chains"])
		primitive_result["sample_count"] += int(primitive_holes["sample_count"])
		primitive_result["preserve_count"] += int(primitive_holes["preserve_count"])
		primitive_result["hole_count"] = primitive_holes["chains"].size()
		var primitive_cuts := _sample_cut_guides(cut_guides, recipe)
		for cut in primitive_cuts:
			if not bool(cut.get("valid", false)):
				return _failed_result(recipe, cut.get("errors", []), source_fingerprint(component, cut_guides, hole_components))
		primitive_result["cuts"] = primitive_cuts
		_finalize_result_stats(primitive_result)
		return primitive_result
	var working_component := component.duplicate(true)
	BezierGeometry.resolve_auto_handles(working_component.get("points", []), working_component.get("chains", []))
	var errors := _validation_issues(working_component, allow_open)
	if not errors.is_empty():
		return _failed_result(recipe, errors, source_fingerprint(component, cut_guides, hole_components))
	var sampled_chains: Array = []
	var sample_count := 0
	var preserved_ids: Dictionary = {}
	for chain_data in working_component.get("chains", []):
		var sampled_chain := _sample_chain(working_component, chain_data, recipe)
		if not bool(sampled_chain.get("valid", false)):
			errors.append_array(sampled_chain.get("errors", []))
			continue
		var samples: Array = sampled_chain.get("samples", [])
		sample_count += samples.size()
		for sample in samples:
			var source_point_id := str(sample.get("source_point_id", ""))
			if bool(sample.get("preserved", false)) and not source_point_id.is_empty():
				preserved_ids[source_point_id] = true
		sampled_chains.append({
			"chain_id": str(chain_data.get("id", "")),
			"input_id": "",
			"topology_role": str(chain_data.get("topology_role", "outer")),
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
		"method": recipe["method"],
		"parameters": recipe["parameters"].duplicate(true),
		"source_fingerprint": source_fingerprint(component, cut_guides, hole_components),
		"chains": sampled_chains,
		"cuts": cuts,
		"sample_count": sample_count,
		"preserve_count": preserved_ids.size(),
		"hole_count": sampled_holes["chains"].size()
	}
	_finalize_result_stats(result)
	return result


static func validation_issues(component: Dictionary, cut_guides: Array = [], hole_components: Array = []) -> Array[String]:
	var errors: Array[String] = []
	if PrimitiveGeometryService.has_circle(component):
		errors.append_array(PrimitiveGeometryService.validation_issues(component))
	else:
		errors.append_array(_validation_issues(component, false))
	for hole in hole_components:
		if not hole is Dictionary:
			continue
		if PrimitiveGeometryService.has_circle(hole):
			errors.append_array(PrimitiveGeometryService.validation_issues(hole))
		else:
			errors.append_array(_validation_issues(hole, false, false))
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
			str(point_data.get("id", "")), position.x, position.y,
			str(point_data.get("mode", "linear")), int(bool(point_data.get("preserve_point", false))),
			str(point_data.get("handle_source", "auto")), handle_in.x, handle_in.y, handle_out.x, handle_out.y
		])
	for edge_data in component.get("edges", []):
		if edge_data is Dictionary:
			parts.append("e|%s|%s|%s" % [str(edge_data.get("id", "")), str(edge_data.get("start_point_id", "")), str(edge_data.get("end_point_id", ""))])
	for chain_data in component.get("chains", []):
		if chain_data is Dictionary:
			parts.append("c|%s|%s|%s|%d|%s" % [
				str(chain_data.get("id", "")), ",".join(chain_data.get("point_ids", [])),
				",".join(chain_data.get("edge_ids", [])), int(bool(chain_data.get("closed", false))),
				str(chain_data.get("topology_role", "outer"))
			])
	parts.append("draw_mode|%s" % str(component.get("draw_mode", "closed_loop")))
	for guide in cut_guides:
		if guide is Dictionary:
			parts.append("cut|%s|%s" % [str(guide.get("id", "")), source_fingerprint(guide)])
	for hole in hole_components:
		if hole is Dictionary:
			parts.append("hole|%s|%s" % [str(hole.get("id", "")), source_fingerprint(hole)])
	if PrimitiveGeometryService.has_circle(component):
		var primitive_center := PrimitiveGeometryService.center(component)
		parts.append("primitive|circle|%.9f|%.9f|%.9f" % [
			primitive_center.x,
			primitive_center.y,
			float(component.get("primitive", {}).get("diameter_cm", 1.0))
		])
	parts.append("ribbon_width_px|%.9f" % float(component.get("ribbon_width_px", 8.0)))
	var sampling_transform: Transform2D = component.get("sampling_transform", Transform2D.IDENTITY)
	parts.append("sampling_transform|%.9f|%.9f|%.9f|%.9f|%.9f|%.9f" % [sampling_transform.x.x, sampling_transform.x.y, sampling_transform.y.x, sampling_transform.y.y, sampling_transform.origin.x, sampling_transform.origin.y])
	var hashing_context := HashingContext.new()
	hashing_context.start(HashingContext.HASH_SHA256)
	hashing_context.update("\n".join(parts).to_utf8_buffer())
	return hashing_context.finish().hex_encode()


static func _sample_hole_components(hole_components: Array, recipe: Dictionary) -> Dictionary:
	var sampled_chains: Array = []
	var errors: Array[String] = []
	var sample_count := 0
	var preserved_ids: Dictionary = {}
	for hole_component in hole_components:
		if not hole_component is Dictionary:
			continue
		var working_hole: Dictionary = hole_component.duplicate(true)
		var input_id := str(hole_component.get("sampling_input_id", hole_component.get("id", "")))
		var hole_recipe := _recipe_for_input(recipe, input_id)
		if PrimitiveGeometryService.has_circle(working_hole):
			var sampled_circle := _sample_circle(working_hole, hole_recipe, input_id, "hole")
			if not bool(sampled_circle.get("valid", false)):
				errors.append_array(sampled_circle.get("errors", []))
				continue
			var circle_samples: Array = sampled_circle.get("samples", [])
			sample_count += circle_samples.size()
			sampled_chains.append({"chain_id": "hole:%s:primitive:circle" % str(hole_component.get("id", "")), "input_id": input_id, "topology_role": "hole", "closed": true, "effective_spacing": sampled_circle["effective_spacing"], "samples": circle_samples})
			continue
		BezierGeometry.resolve_auto_handles(working_hole.get("points", []), working_hole.get("chains", []))
		var hole_errors := _validation_issues(working_hole, false, false)
		if not hole_errors.is_empty():
			errors.append_array(hole_errors)
			continue
		for chain_data in working_hole.get("chains", []):
			var sampled_chain := _sample_chain(working_hole, chain_data, hole_recipe)
			if not bool(sampled_chain.get("valid", false)):
				errors.append_array(sampled_chain.get("errors", []))
				continue
			var samples: Array = sampled_chain.get("samples", [])
			sample_count += samples.size()
			for sample in samples:
				var source_point_id := str(sample.get("source_point_id", ""))
				if bool(sample.get("preserved", false)) and not source_point_id.is_empty():
					preserved_ids[source_point_id] = true
			sampled_chains.append({
				"chain_id": "hole:%s:%s" % [str(hole_component.get("id", "")), str(chain_data.get("id", ""))],
				"input_id": input_id,
				"topology_role": "hole",
				"closed": bool(chain_data.get("closed", false)),
				"effective_spacing": float(hole_recipe["parameters"]["spacing"]),
				"samples": samples
			})
	return {"chains": sampled_chains, "errors": errors, "sample_count": sample_count, "preserve_count": preserved_ids.size(), "preserved_ids": preserved_ids}


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
		if str(chain_data.get("topology_role", "outer")) == "outer" and (bool(chain_data.get("closed", false)) or allow_open):
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
			if str(chain_data.get("topology_role", "outer")) != "hole" or not bool(chain_data.get("closed", false)):
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
	return {"valid": true, "errors": [], "samples": samples}


static func _sample_circle(component: Dictionary, recipe: Dictionary, input_id: String, role: String) -> Dictionary:
	var spacing := float(recipe.get("parameters", {}).get("spacing", DEFAULT_SPACING))
	var detail := float(recipe.get("parameters", {}).get("feature_detail", DEFAULT_FEATURE_DETAIL))
	var density_factor := maxf(float(recipe.get("parameters", {}).get("density_factor", 1.0)), MIN_REFINEMENT_FACTOR)
	var flatness_tolerance := spacing * (0.1 * pow(0.025, detail)) / density_factor
	var turn_tolerance := deg_to_rad(clampf(lerpf(90.0, 15.0, detail) / density_factor, 0.5, 120.0))
	var transform: Transform2D = component.get("sampling_transform", Transform2D.IDENTITY)
	var center := PrimitiveGeometryService.center(component)
	var radius := PrimitiveGeometryService.diameter_tool_units(component) * 0.5
	var samples: Array = [{"position": transform * (center + Vector2.RIGHT * radius)}]
	for quadrant in range(4):
		var angle_start := TAU * float(quadrant) / 4.0
		var angle_end := TAU * float(quadrant + 1) / 4.0
		_append_adaptive_circle_segment(samples, transform, center, radius, angle_start, angle_end, spacing, flatness_tolerance, turn_tolerance, 0)
		if samples.size() > MAX_SAMPLES_PER_CHAIN:
			return {"valid": false, "errors": ["Sampling exceeded the safety limit of %d Points per Chain." % MAX_SAMPLES_PER_CHAIN]}
	if samples.size() > 1:
		samples.pop_back()
	if samples.size() < 4:
		return {"valid": false, "errors": ["A sampled Circle requires at least four boundary Points."]}
	for index in range(samples.size()):
		samples[index] = {
			"id": "sample:circle:%s:%d" % [input_id if not input_id.is_empty() else "outer", index],
			"position": Vector2(samples[index].get("position", Vector2.ZERO)),
			"edge_id": "primitive:circle",
			"curve_t": float(index) / float(samples.size()),
			"source_point_id": "",
			"preserved": false
		}
	return {"valid": true, "errors": [], "samples": samples, "role": role, "effective_spacing": spacing}


static func _append_adaptive_circle_segment(result: Array, transform: Transform2D, center: Vector2, radius: float, angle_start: float, angle_end: float, spacing: float, flatness_tolerance: float, turn_tolerance: float, depth: int) -> void:
	var start := transform * (center + Vector2(cos(angle_start), sin(angle_start)) * radius)
	var end := transform * (center + Vector2(cos(angle_end), sin(angle_end)) * radius)
	var angle_mid := (angle_start + angle_end) * 0.5
	var midpoint := transform * (center + Vector2(cos(angle_mid), sin(angle_mid)) * radius)
	var tangent_start := transform.basis_xform(Vector2(-sin(angle_start), cos(angle_start))).normalized()
	var tangent_end := transform.basis_xform(Vector2(-sin(angle_end), cos(angle_end))).normalized()
	var should_split := start.distance_to(end) > spacing \
		or midpoint.distance_to((start + end) * 0.5) > flatness_tolerance \
		or absf(tangent_start.angle_to(tangent_end)) > turn_tolerance
	if should_split and depth < MAX_ADAPTIVE_DEPTH and result.size() < MAX_SAMPLES_PER_CHAIN:
		_append_adaptive_circle_segment(result, transform, center, radius, angle_start, angle_mid, spacing, flatness_tolerance, turn_tolerance, depth + 1)
		_append_adaptive_circle_segment(result, transform, center, radius, angle_mid, angle_end, spacing, flatness_tolerance, turn_tolerance, depth + 1)
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
			"role": str(chain_data.get("topology_role", "outer")),
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
		"method": recipe["method"],
		"parameters": recipe["parameters"].duplicate(true),
		"source_fingerprint": fingerprint,
		"chains": [],
		"sample_count": 0,
		"preserve_count": 0
	}
