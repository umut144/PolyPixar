class_name GeometrySamplingService
extends RefCounted

const ADAPTIVE := "adaptive"
const EVEN_SPACING := "even_spacing"
const VALID_METHODS := [ADAPTIVE, EVEN_SPACING]
const DEFAULT_SPACING := 1.0
const DEFAULT_FEATURE_DETAIL := 0.5
const MIN_SPACING := 0.01
const MAX_SAMPLES_PER_CHAIN := 20000
const MAX_ADAPTIVE_DEPTH := 18
const ARC_TABLE_STEPS := 32


static func default_recipe() -> Dictionary:
	return {
		"method": ADAPTIVE,
		"parameters": {
			"spacing": DEFAULT_SPACING,
			"feature_detail": DEFAULT_FEATURE_DETAIL
		}
	}


static func normalize_recipe(raw_recipe) -> Dictionary:
	var recipe := default_recipe()
	if not raw_recipe is Dictionary:
		return recipe
	var method := str(raw_recipe.get("method", ADAPTIVE))
	recipe["method"] = method if method in VALID_METHODS else ADAPTIVE
	var raw_parameters = raw_recipe.get("parameters", {})
	if raw_parameters is Dictionary:
		recipe["parameters"]["spacing"] = maxf(float(raw_parameters.get("spacing", DEFAULT_SPACING)), MIN_SPACING)
		recipe["parameters"]["feature_detail"] = clampf(float(raw_parameters.get("feature_detail", DEFAULT_FEATURE_DETAIL)), 0.0, 1.0)
	return recipe


static func generate(component: Dictionary, raw_recipe = {}) -> Dictionary:
	var recipe := normalize_recipe(raw_recipe)
	var allow_open := bool(raw_recipe.get("allow_open", false)) if raw_recipe is Dictionary else false
	var working_component := component.duplicate(true)
	BezierGeometry.resolve_auto_handles(working_component.get("points", []), working_component.get("chains", []))
	var errors := _validation_issues(working_component, allow_open)
	if not errors.is_empty():
		return _failed_result(recipe, errors, source_fingerprint(component))
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
			"topology_role": str(chain_data.get("topology_role", "outer")),
			"closed": bool(chain_data.get("closed", false)),
			"samples": samples
		})
	if not errors.is_empty():
		return _failed_result(recipe, errors, source_fingerprint(component))
	return {
		"valid": true,
		"errors": [],
		"method": recipe["method"],
		"parameters": recipe["parameters"].duplicate(true),
		"source_fingerprint": source_fingerprint(component),
		"chains": sampled_chains,
		"sample_count": sample_count,
		"preserve_count": preserved_ids.size()
	}


static func source_fingerprint(component: Dictionary) -> String:
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
	parts.append("ribbon_width_px|%.9f" % float(component.get("ribbon_width_px", 8.0)))
	var hashing_context := HashingContext.new()
	hashing_context.start(HashingContext.HASH_SHA256)
	hashing_context.update("\n".join(parts).to_utf8_buffer())
	return hashing_context.finish().hex_encode()


static func _validation_issues(component: Dictionary, allow_open := false) -> Array[String]:
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
	if not has_valid_outer:
		errors.append("The Component needs an outer Chain.")
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
		var edge_samples := _sample_even_edge(controls, edge_id, end_point, float(recipe["parameters"]["spacing"])) \
			if str(recipe["method"]) == EVEN_SPACING \
			else _sample_adaptive_edge(controls, edge_id, end_point, recipe["parameters"])
		samples.append_array(edge_samples)
		if samples.size() > MAX_SAMPLES_PER_CHAIN:
			return {"valid": false, "errors": ["Sampling exceeded the safety limit of %d Points per Chain." % MAX_SAMPLES_PER_CHAIN]}
	if bool(chain_data.get("closed", false)) and samples.size() > 1:
		var first_source := str(samples.front().get("source_point_id", ""))
		var last_source := str(samples.back().get("source_point_id", ""))
		if not first_source.is_empty() and first_source == last_source:
			samples.pop_back()
	return {"valid": true, "errors": [], "samples": samples}


static func _sample_even_edge(controls: Array[Vector2], edge_id: String, end_point: Dictionary, spacing: float) -> Array:
	var table: Array = [{"t": 0.0, "length": 0.0}]
	var previous := controls[0]
	var total_length := 0.0
	for table_index in range(1, ARC_TABLE_STEPS + 1):
		var t := float(table_index) / float(ARC_TABLE_STEPS)
		var position := BezierGeometry.cubic_position(controls, t)
		total_length += previous.distance_to(position)
		table.append({"t": t, "length": total_length})
		previous = position
	var interval_count := maxi(1, ceili(total_length / spacing))
	var result: Array = []
	for interval_index in range(1, interval_count + 1):
		var fraction := float(interval_index) / float(interval_count)
		var t := _table_t_at_length(table, total_length * fraction)
		if interval_index == interval_count:
			result.append(_source_sample(edge_id, 1.0, end_point))
		else:
			result.append(_curve_sample(edge_id, t, BezierGeometry.cubic_position(controls, t)))
	return result


static func _sample_adaptive_edge(controls: Array[Vector2], edge_id: String, end_point: Dictionary, parameters: Dictionary) -> Array:
	var result: Array = []
	var spacing := float(parameters.get("spacing", DEFAULT_SPACING))
	var detail := float(parameters.get("feature_detail", DEFAULT_FEATURE_DETAIL))
	var flatness_tolerance := spacing * lerpf(0.5, 0.02, detail)
	var turn_tolerance := deg_to_rad(lerpf(60.0, 6.0, detail))
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


static func _table_t_at_length(table: Array, target_length: float) -> float:
	for table_index in range(1, table.size()):
		var previous: Dictionary = table[table_index - 1]
		var current: Dictionary = table[table_index]
		if float(current["length"]) < target_length:
			continue
		var span := float(current["length"]) - float(previous["length"])
		var weight := 0.0 if is_zero_approx(span) else (target_length - float(previous["length"])) / span
		return lerpf(float(previous["t"]), float(current["t"]), weight)
	return 1.0


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
