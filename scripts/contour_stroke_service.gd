class_name ContourStrokeService
extends RefCounted

## The source Bezier boundary is the stroke centerline. The service derives a
## deterministic centered mesh for the visible runs of one closed outer/hole
## Chain or one open Contour Chain without changing canonical topology.

const ALGORITHM_VERSION := 3
const REFERENCE_PIXELS_PER_METER := 128.0
const DEFAULT_STROKE_WIDTH_PX := 4.0
const MAX_DEVIATION_PX := 0.25
const MITER_LIMIT := 4.0
const JOIN_TYPE := "miter"
const CAP_TYPE := "butt"
const MAX_SAMPLE_DEPTH := 18
const MAX_SAMPLES_PER_EDGE := 20000
const MAX_TANGENT_TURN_RADIANS := PI / 12.0
const GEOMETRY_EPSILON := 0.000001
const MAX_SEGMENT_PAIR_CHECKS := 500000


static func stroke_width_meters(stroke_width_px := DEFAULT_STROKE_WIDTH_PX) -> float:
	return stroke_width_px / REFERENCE_PIXELS_PER_METER


static func generate(component: Dictionary, stroke_width_px := DEFAULT_STROKE_WIDTH_PX) -> Dictionary:
	var errors := validation_issues(component, stroke_width_px)
	if not errors.is_empty():
		return _failed_result(errors, stroke_width_px)
	var working_component := component.duplicate(true)
	BezierGeometry.resolve_auto_handles(working_component.get("points", []), working_component.get("chains", []))
	var chain: Dictionary = working_component.get("chains", [])[0]
	var source_closed := bool(chain.get("closed", false))
	var sampled := _sample_chain(working_component, chain, source_closed)
	if not bool(sampled.get("valid", false)):
		return _failed_result(sampled.get("errors", []), stroke_width_px)
	var width_meters := stroke_width_meters(stroke_width_px)
	var width_tool_units := width_meters / ToolUnits.TO_METERS
	var vertices: Array = []
	var indices := PackedInt32Array()
	var output_runs: Array = []
	var combined_centerline: Array = []
	var triangle_count := 0
	var miter_join_count := 0
	var bevel_join_count := 0
	var self_intersection_count := 0
	var narrow_overlap_pair_count := 0
	var minimum_nonadjacent_clearance := INF
	for run_data in sampled.get("runs", []):
		var run_centerline: Array = run_data.get("samples", [])
		var mesh := _build_stroke_mesh(run_centerline, width_tool_units * 0.5, bool(run_data.get("closed", false)))
		if not bool(mesh.get("valid", false)):
			return _failed_result(mesh.get("errors", []), stroke_width_px)
		var vertex_offset := vertices.size()
		var index_offset := indices.size()
		vertices.append_array(mesh.get("vertices", []))
		for mesh_index in mesh.get("indices", PackedInt32Array()):
			indices.append(vertex_offset + int(mesh_index))
		combined_centerline.append_array(run_centerline)
		var run_result := {
			"run_id": str(run_data.get("run_id", "")),
			"closed": bool(run_data.get("closed", false)),
			"start_cap": "none" if bool(run_data.get("closed", false)) else CAP_TYPE,
			"end_cap": "none" if bool(run_data.get("closed", false)) else CAP_TYPE,
			"edge_ids": run_data.get("edge_ids", []).duplicate(),
			"centerline": run_centerline,
			"vertex_offset": vertex_offset,
			"vertex_count": mesh.get("vertices", []).size(),
			"index_offset": index_offset,
			"index_count": mesh.get("indices", PackedInt32Array()).size(),
			"triangle_count": int(mesh.get("triangle_count", 0)),
			"miter_join_count": int(mesh.get("miter_join_count", 0)),
			"bevel_join_count": int(mesh.get("bevel_join_count", 0)),
			"geometry_diagnostics": mesh.get("geometry_diagnostics", {}).duplicate(true)
		}
		output_runs.append(run_result)
		triangle_count += int(mesh.get("triangle_count", 0))
		miter_join_count += int(mesh.get("miter_join_count", 0))
		bevel_join_count += int(mesh.get("bevel_join_count", 0))
		var run_diagnostics: Dictionary = mesh.get("geometry_diagnostics", {})
		self_intersection_count += int(run_diagnostics.get("self_intersection_count", 0))
		narrow_overlap_pair_count += int(run_diagnostics.get("narrow_overlap_pair_count", 0))
		minimum_nonadjacent_clearance = minf(minimum_nonadjacent_clearance, float(run_diagnostics.get("minimum_nonadjacent_clearance_tool_units", INF)))
	var minimum_clearance_meters = null
	if is_finite(minimum_nonadjacent_clearance):
		minimum_clearance_meters = minimum_nonadjacent_clearance * ToolUnits.TO_METERS
	return {
		"valid": true,
		"errors": [],
		"algorithm_version": ALGORITHM_VERSION,
		"reference_pixels_per_meter": REFERENCE_PIXELS_PER_METER,
		"stroke_width_px": stroke_width_px,
		"stroke_width_meters": width_meters,
		"stroke_width_tool_units": width_tool_units,
		"centerline_offset_meters": width_meters * 0.5,
		"sampling_max_deviation_px": MAX_DEVIATION_PX,
		"sampling_max_deviation_meters": MAX_DEVIATION_PX / REFERENCE_PIXELS_PER_METER,
		"certified_max_deviation_meters": float(sampled.get("certified_max_deviation_tool_units", 0.0)) * ToolUnits.TO_METERS,
		"join": JOIN_TYPE,
		"miter_limit": MITER_LIMIT,
		"cap": CAP_TYPE,
		"source_chain_closed": source_closed,
		"chain_id": str(chain.get("id", "")),
		"topology_role": str(chain.get("topology_role", "outer")),
		"has_outline": not output_runs.is_empty(),
		"outline_run_count": output_runs.size(),
		"runs": output_runs,
		"centerline": combined_centerline,
		"vertices": vertices,
		"indices": indices,
		"triangle_count": triangle_count,
		"miter_join_count": miter_join_count,
		"bevel_join_count": bevel_join_count,
		"geometry_diagnostics": {
			"self_intersection_count": self_intersection_count,
			"narrow_overlap_pair_count": narrow_overlap_pair_count,
			"minimum_nonadjacent_clearance_meters": minimum_clearance_meters,
			"triangle_validation": "complete"
		}
	}


static func validation_issues(component: Dictionary, stroke_width_px := DEFAULT_STROKE_WIDTH_PX) -> Array[String]:
	var errors := BezierTopology.validate(component)
	if not is_finite(stroke_width_px) or stroke_width_px <= 0.0:
		errors.append("Contour stroke width must be a finite positive authored pixel value.")
	var draw_mode := str(component.get("draw_mode", "closed_loop"))
	if draw_mode not in ["closed_loop", "contour"]:
		errors.append("Contour Stroke requires a Closed Loop or Contour Component.")
	var chains: Array = component.get("chains", [])
	if chains.size() != 1:
		errors.append("Contour Stroke requires exactly one Chain.")
		return errors
	var chain: Dictionary = chains[0]
	var component_role := str(component.get("topology_role", "outer"))
	var chain_role := str(chain.get("topology_role", "outer"))
	if draw_mode == "closed_loop":
		if component_role not in ["outer", "hole"] or chain_role not in ["outer", "hole"]:
			errors.append("A closed Contour Stroke requires an outer or hole Chain.")
		elif component_role != chain_role:
			errors.append("Contour Stroke Component and Chain topology roles must match.")
		if not bool(chain.get("closed", false)) or chain.get("point_ids", []).size() < 3:
			errors.append("A closed Contour Stroke requires at least three Points.")
	else:
		if bool(chain.get("closed", false)) or chain.get("point_ids", []).size() < 2:
			errors.append("An open Contour Stroke requires one open Chain with at least two Points.")
		if component_role != "outer" or chain_role != "outer":
			errors.append("An open Contour Component must use the outer topology role.")
	return errors


static func _sample_chain(component: Dictionary, chain: Dictionary, source_closed: bool) -> Dictionary:
	var sampled_edges: Array = []
	var maximum_flatness := 0.0
	var errors: Array[String] = []
	for edge_id_value in chain.get("edge_ids", []):
		var edge_id := str(edge_id_value)
		var edge := BezierTopology.edge_by_id(component.get("edges", []), edge_id)
		var start_point := BezierTopology.point_by_id(component.get("points", []), str(edge.get("start_point_id", "")))
		var end_point := BezierTopology.point_by_id(component.get("points", []), str(edge.get("end_point_id", "")))
		if edge.is_empty() or start_point.is_empty() or end_point.is_empty():
			errors.append("Contour stroke Chain contains an unresolved Edge.")
			continue
		var visible := bool(edge.get("render_outline", true))
		if not visible:
			sampled_edges.append({"edge_id": edge_id, "visible": false, "samples": []})
			continue
		var controls := BezierGeometry.cubic_controls(start_point, end_point)
		var edge_samples: Array = [_centerline_sample(controls[0], edge_id, 0.0, str(edge.get("start_point_id", "")))]
		var edge_stats := {"maximum_flatness": 0.0, "error": ""}
		_sample_cubic(controls, edge_id, 0.0, 1.0, 0, edge_samples, edge_stats)
		if not str(edge_stats.get("error", "")).is_empty():
			errors.append(str(edge_stats["error"]))
			continue
		maximum_flatness = maxf(maximum_flatness, float(edge_stats["maximum_flatness"]))
		sampled_edges.append({"edge_id": edge_id, "visible": true, "samples": edge_samples})
	var runs: Array = []
	if errors.is_empty():
		runs = _build_outline_runs(sampled_edges, str(chain.get("id", "")), source_closed)
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"runs": runs,
		"certified_max_deviation_tool_units": maximum_flatness
	}


static func _build_outline_runs(sampled_edges: Array, chain_id: String, source_closed: bool) -> Array:
	var runs: Array = []
	var visible_count := 0
	for sampled_edge in sampled_edges:
		if bool(sampled_edge.get("visible", false)):
			visible_count += 1
	if visible_count == 0:
		return runs
	if source_closed and visible_count == sampled_edges.size():
		var closed_samples: Array = []
		var closed_edge_ids: Array[String] = []
		for sampled_edge in sampled_edges:
			closed_edge_ids.append(str(sampled_edge.get("edge_id", "")))
			_append_edge_samples(closed_samples, sampled_edge.get("samples", []))
		if closed_samples.size() > 1 and Vector2(closed_samples.front().get("position", Vector2.ZERO)).is_equal_approx(Vector2(closed_samples.back().get("position", Vector2.ZERO))):
			closed_samples.pop_back()
		runs.append({"run_id": "%s:run:0" % chain_id, "closed": true, "edge_ids": closed_edge_ids, "samples": closed_samples})
		return runs
	if not source_closed:
		var open_samples: Array = []
		var open_edge_ids: Array[String] = []
		for sampled_edge in sampled_edges:
			if bool(sampled_edge.get("visible", false)):
				open_edge_ids.append(str(sampled_edge.get("edge_id", "")))
				_append_edge_samples(open_samples, sampled_edge.get("samples", []))
			elif not open_edge_ids.is_empty():
				runs.append({"run_id": "%s:run:%d" % [chain_id, runs.size()], "closed": false, "edge_ids": open_edge_ids, "samples": open_samples})
				open_samples = []
				open_edge_ids = []
		if not open_edge_ids.is_empty():
			runs.append({"run_id": "%s:run:%d" % [chain_id, runs.size()], "closed": false, "edge_ids": open_edge_ids, "samples": open_samples})
		return runs
	var first_hidden_index := 0
	while first_hidden_index < sampled_edges.size() and bool(sampled_edges[first_hidden_index].get("visible", false)):
		first_hidden_index += 1
	var current_samples: Array = []
	var current_edge_ids: Array[String] = []
	for offset in range(1, sampled_edges.size() + 1):
		var edge_index := (first_hidden_index + offset) % sampled_edges.size()
		var sampled_edge: Dictionary = sampled_edges[edge_index]
		if bool(sampled_edge.get("visible", false)):
			current_edge_ids.append(str(sampled_edge.get("edge_id", "")))
			_append_edge_samples(current_samples, sampled_edge.get("samples", []))
		elif not current_edge_ids.is_empty():
			runs.append({"run_id": "%s:run:%d" % [chain_id, runs.size()], "closed": false, "edge_ids": current_edge_ids, "samples": current_samples})
			current_samples = []
			current_edge_ids = []
	if not current_edge_ids.is_empty():
		runs.append({"run_id": "%s:run:%d" % [chain_id, runs.size()], "closed": false, "edge_ids": current_edge_ids, "samples": current_samples})
	return runs


static func _append_edge_samples(target: Array, edge_samples: Array) -> void:
	for sample_index in range(edge_samples.size()):
		if not target.is_empty() and sample_index == 0 and Vector2(target.back().get("position", Vector2.ZERO)).is_equal_approx(Vector2(edge_samples[sample_index].get("position", Vector2.ZERO))):
			continue
		target.append(edge_samples[sample_index])


static func _sample_cubic(controls: Array[Vector2], edge_id: String, t_start: float, t_end: float, depth: int, output: Array, stats: Dictionary) -> void:
	var flatness := BezierGeometry.cubic_flatness(controls)
	var tolerance_tool_units := (MAX_DEVIATION_PX / REFERENCE_PIXELS_PER_METER) / ToolUnits.TO_METERS
	var tangent_turn := BezierGeometry.cubic_tangent_turn(controls)
	if flatness <= tolerance_tool_units and tangent_turn <= MAX_TANGENT_TURN_RADIANS:
		stats["maximum_flatness"] = maxf(float(stats["maximum_flatness"]), flatness)
		if output.size() >= MAX_SAMPLES_PER_EDGE:
			stats["error"] = "Contour stroke sampling exceeded its deterministic per-Edge sample limit."
			return
		output.append(_centerline_sample(controls[3], edge_id, t_end, ""))
		return
	if depth >= MAX_SAMPLE_DEPTH:
		stats["error"] = "Contour stroke sampling could not satisfy its deviation bound within the deterministic depth limit."
		return
	var split := BezierGeometry.split_cubic_controls(controls, 0.5)
	var t_middle := (t_start + t_end) * 0.5
	_sample_cubic(split[0], edge_id, t_start, t_middle, depth + 1, output, stats)
	if not str(stats.get("error", "")).is_empty():
		return
	_sample_cubic(split[1], edge_id, t_middle, t_end, depth + 1, output, stats)


static func _centerline_sample(position: Vector2, edge_id: String, curve_t: float, source_point_id: String) -> Dictionary:
	return {
		"position": position,
		"edge_id": edge_id,
		"curve_t": curve_t,
		"source_point_id": source_point_id
	}


static func _build_stroke_mesh(centerline: Array, half_width: float, closed: bool) -> Dictionary:
	var vertices: Array = []
	var indices := PackedInt32Array()
	var minimum_samples := 3 if closed else 2
	if centerline.size() < minimum_samples:
		return {"valid": false, "errors": ["Contour stroke run contains too few centerline samples."]}
	var analysis := _analyze_centerline(centerline, half_width, closed)
	if not bool(analysis.get("valid", false)):
		return {"valid": false, "errors": analysis.get("errors", [])}
	var segment_count := centerline.size() if closed else centerline.size() - 1
	var directions: Array[Vector2] = []
	var normals: Array[Vector2] = []
	var errors: Array[String] = []
	for sample_index in range(segment_count):
		var start := Vector2(centerline[sample_index].get("position", Vector2.ZERO))
		var end := Vector2(centerline[(sample_index + 1) % centerline.size()].get("position", Vector2.ZERO))
		var delta := end - start
		if delta.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
			errors.append("Contour stroke sampling produced a degenerate segment.")
			continue
		var direction := delta.normalized()
		directions.append(direction)
		normals.append(Vector2(-direction.y, direction.x))
	if not errors.is_empty():
		return {"valid": false, "errors": errors}
	for segment_index in range(segment_count):
		var start_sample: Dictionary = centerline[segment_index]
		var end_sample: Dictionary = centerline[(segment_index + 1) % centerline.size()]
		var start := Vector2(start_sample.get("position", Vector2.ZERO))
		var end := Vector2(end_sample.get("position", Vector2.ZERO))
		var normal := normals[segment_index]
		var base := vertices.size()
		vertices.append(_mesh_vertex(start + normal * half_width, "segment_left", start_sample))
		vertices.append(_mesh_vertex(start - normal * half_width, "segment_right", start_sample))
		vertices.append(_mesh_vertex(end + normal * half_width, "segment_left", end_sample))
		vertices.append(_mesh_vertex(end - normal * half_width, "segment_right", end_sample))
		_append_triangle(vertices, indices, base, base + 1, base + 2)
		_append_triangle(vertices, indices, base + 2, base + 1, base + 3)
	var miter_join_count := 0
	var bevel_join_count := 0
	var join_start := 0 if closed else 1
	var join_end := centerline.size() if closed else centerline.size() - 1
	for join_index in range(join_start, join_end):
		var previous_index := posmod(join_index - 1, segment_count)
		var previous_direction := directions[previous_index]
		var next_direction := directions[join_index]
		var turn := previous_direction.cross(next_direction)
		if absf(turn) <= GEOMETRY_EPSILON:
			continue
		var position := Vector2(centerline[join_index].get("position", Vector2.ZERO))
		# A positive turn bends toward the left normal, therefore its exposed
		# outer corner is on the right. The inverse applies to a negative turn.
		var outer_sign := -1.0 if turn > 0.0 else 1.0
		var outer_previous := position + normals[previous_index] * half_width * outer_sign
		var outer_next := position + normals[join_index] * half_width * outer_sign
		var intersection := _line_intersection(outer_previous, previous_direction, outer_next, next_direction)
		var use_miter := bool(intersection.get("valid", false)) and position.distance_to(Vector2(intersection.get("position", position))) <= half_width * MITER_LIMIT + GEOMETRY_EPSILON
		var base := vertices.size()
		var provenance: Dictionary = centerline[join_index]
		vertices.append(_mesh_vertex(position, "join_center", provenance))
		vertices.append(_mesh_vertex(outer_previous, "join_outer_previous", provenance))
		if use_miter:
			vertices.append(_mesh_vertex(Vector2(intersection["position"]), "join_miter", provenance))
			vertices.append(_mesh_vertex(outer_next, "join_outer_next", provenance))
			_append_triangle(vertices, indices, base, base + 1, base + 2)
			_append_triangle(vertices, indices, base, base + 2, base + 3)
			miter_join_count += 1
		else:
			vertices.append(_mesh_vertex(outer_next, "join_outer_next", provenance))
			_append_triangle(vertices, indices, base, base + 1, base + 2)
			bevel_join_count += 1
	var mesh_errors := _mesh_validation_issues(vertices, indices)
	if not mesh_errors.is_empty():
		return {"valid": false, "errors": mesh_errors}
	return {
		"valid": true,
		"errors": [],
		"vertices": vertices,
		"indices": indices,
		"triangle_count": int(float(indices.size()) / 3.0),
		"miter_join_count": miter_join_count,
		"bevel_join_count": bevel_join_count,
		"geometry_diagnostics": analysis.get("diagnostics", {}).duplicate(true)
	}


static func _analyze_centerline(centerline: Array, half_width: float, closed: bool) -> Dictionary:
	var errors: Array[String] = []
	var segment_count := centerline.size() if closed else centerline.size() - 1
	var segments: Array = []
	for segment_index in range(segment_count):
		var start := Vector2(centerline[segment_index].get("position", Vector2.ZERO))
		var end := Vector2(centerline[(segment_index + 1) % centerline.size()].get("position", Vector2.ZERO))
		if not start.is_finite() or not end.is_finite():
			errors.append("Contour stroke centerline contains a non-finite position.")
			continue
		if start.distance_squared_to(end) <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
			errors.append("Contour stroke sampling produced a degenerate segment.")
			continue
		segments.append({"start": start, "end": end, "index": segment_index})
	if not errors.is_empty():
		return {"valid": false, "errors": errors}
	for join_index in range(1, segment_count):
		var previous_direction := (Vector2(segments[join_index - 1]["end"]) - Vector2(segments[join_index - 1]["start"])).normalized()
		var next_direction := (Vector2(segments[join_index]["end"]) - Vector2(segments[join_index]["start"])).normalized()
		if previous_direction.dot(next_direction) <= -1.0 + GEOMETRY_EPSILON and absf(previous_direction.cross(next_direction)) <= GEOMETRY_EPSILON:
			errors.append("Contour stroke centerline reverses direction by 180 degrees at sample %d; author an explicit non-overlapping turn." % (join_index + 1))
	if closed:
		var last_direction := (Vector2(segments.back()["end"]) - Vector2(segments.back()["start"])).normalized()
		var first_direction := (Vector2(segments.front()["end"]) - Vector2(segments.front()["start"])).normalized()
		if last_direction.dot(first_direction) <= -1.0 + GEOMETRY_EPSILON and absf(last_direction.cross(first_direction)) <= GEOMETRY_EPSILON:
			errors.append("Contour stroke centerline reverses direction by 180 degrees at its closing sample; author an explicit non-overlapping turn.")
	var self_intersection_count := 0
	var narrow_overlap_pair_count := 0
	var minimum_clearance := INF
	var pair_count := int(float(segment_count * (segment_count - 1)) / 2.0) - (segment_count if closed else maxi(0, segment_count - 1))
	if pair_count > MAX_SEGMENT_PAIR_CHECKS:
		return {"valid": false, "errors": ["Contour stroke robustness validation exceeded its deterministic segment-pair limit."]}
	for first_index in range(segment_count):
		for second_index in range(first_index + 1, segment_count):
			if _segments_are_adjacent(first_index, second_index, segment_count, closed):
				continue
			var first: Dictionary = segments[first_index]
			var second: Dictionary = segments[second_index]
			var relation := _segment_relation(first["start"], first["end"], second["start"], second["end"])
			if relation == "overlap":
				errors.append("Contour stroke centerline segments %d and %d overlap collinearly; overlapping authored paths are ambiguous." % [first_index + 1, second_index + 1])
				continue
			if relation in ["cross", "touch"]:
				self_intersection_count += 1
				minimum_clearance = 0.0
				narrow_overlap_pair_count += 1
				if closed:
					errors.append("Closed Contour stroke centerline segments %d and %d intersect; closed outer and Hole boundaries must remain simple loops." % [first_index + 1, second_index + 1])
				continue
			var clearance := _segment_clearance(first["start"], first["end"], second["start"], second["end"])
			minimum_clearance = minf(minimum_clearance, clearance)
			if clearance < half_width * 2.0 - GEOMETRY_EPSILON:
				narrow_overlap_pair_count += 1
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"diagnostics": {
			"self_intersection_count": self_intersection_count,
			"narrow_overlap_pair_count": narrow_overlap_pair_count,
			"minimum_nonadjacent_clearance_tool_units": minimum_clearance,
			"centerline_segment_count": segment_count
		}
	}


static func _segments_are_adjacent(first: int, second: int, segment_count: int, closed: bool) -> bool:
	return second == first + 1 or (closed and first == 0 and second == segment_count - 1)


static func _segment_relation(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> String:
	var ab := b - a
	var cd := d - c
	var denominator := ab.cross(cd)
	if absf(denominator) <= GEOMETRY_EPSILON:
		if absf(ab.cross(c - a)) > GEOMETRY_EPSILON:
			return "none"
		var axis := 0 if absf(ab.x) >= absf(ab.y) else 1
		var a_value := a.x if axis == 0 else a.y
		var b_value := b.x if axis == 0 else b.y
		var c_value := c.x if axis == 0 else c.y
		var d_value := d.x if axis == 0 else d.y
		var overlap := minf(maxf(a_value, b_value), maxf(c_value, d_value)) - maxf(minf(a_value, b_value), minf(c_value, d_value))
		if overlap > GEOMETRY_EPSILON:
			return "overlap"
		return "touch" if overlap >= -GEOMETRY_EPSILON else "none"
	var offset := c - a
	var first_t := offset.cross(cd) / denominator
	var second_t := offset.cross(ab) / denominator
	if first_t < -GEOMETRY_EPSILON or first_t > 1.0 + GEOMETRY_EPSILON or second_t < -GEOMETRY_EPSILON or second_t > 1.0 + GEOMETRY_EPSILON:
		return "none"
	var proper := first_t > GEOMETRY_EPSILON and first_t < 1.0 - GEOMETRY_EPSILON and second_t > GEOMETRY_EPSILON and second_t < 1.0 - GEOMETRY_EPSILON
	return "cross" if proper else "touch"


static func _segment_clearance(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	return minf(
		minf(_point_segment_distance(a, c, d), _point_segment_distance(b, c, d)),
		minf(_point_segment_distance(c, a, b), _point_segment_distance(d, a, b)))


static func _point_segment_distance(point: Vector2, start: Vector2, end: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, end))


static func _mesh_validation_issues(vertices: Array, indices: PackedInt32Array) -> Array[String]:
	var errors: Array[String] = []
	if indices.size() % 3 != 0:
		errors.append("Contour stroke tessellation produced an incomplete triangle index list.")
		return errors
	for triangle_offset in range(0, indices.size(), 3):
		var first := int(indices[triangle_offset])
		var second := int(indices[triangle_offset + 1])
		var third := int(indices[triangle_offset + 2])
		if first < 0 or second < 0 or third < 0 or first >= vertices.size() or second >= vertices.size() or third >= vertices.size():
			errors.append("Contour stroke tessellation produced an out-of-range triangle index.")
			continue
		var a := Vector2(vertices[first].get("position", Vector2.ZERO))
		var b := Vector2(vertices[second].get("position", Vector2.ZERO))
		var c := Vector2(vertices[third].get("position", Vector2.ZERO))
		if not a.is_finite() or not b.is_finite() or not c.is_finite():
			errors.append("Contour stroke tessellation produced a non-finite triangle.")
		elif (b - a).cross(c - a) <= GEOMETRY_EPSILON:
			errors.append("Contour stroke tessellation produced a degenerate or inconsistently wound triangle.")
	return errors


static func _mesh_vertex(position: Vector2, role: String, provenance: Dictionary) -> Dictionary:
	return {
		"position": position,
		"role": role,
		"edge_id": str(provenance.get("edge_id", "")),
		"curve_t": float(provenance.get("curve_t", 0.0))
	}


static func _append_triangle(vertices: Array, indices: PackedInt32Array, first: int, second: int, third: int) -> void:
	var a := Vector2(vertices[first].get("position", Vector2.ZERO))
	var b := Vector2(vertices[second].get("position", Vector2.ZERO))
	var c := Vector2(vertices[third].get("position", Vector2.ZERO))
	if absf((b - a).cross(c - a)) <= GEOMETRY_EPSILON:
		return
	indices.append(first)
	if (b - a).cross(c - a) > 0.0:
		indices.append(second)
		indices.append(third)
	else:
		indices.append(third)
		indices.append(second)


static func _line_intersection(first_origin: Vector2, first_direction: Vector2, second_origin: Vector2, second_direction: Vector2) -> Dictionary:
	var denominator := first_direction.cross(second_direction)
	if absf(denominator) <= GEOMETRY_EPSILON:
		return {"valid": false}
	var distance := (second_origin - first_origin).cross(second_direction) / denominator
	return {"valid": true, "position": first_origin + first_direction * distance}


static func _failed_result(errors: Array, stroke_width_px: float) -> Dictionary:
	return {
		"valid": false,
		"errors": errors.duplicate(),
		"algorithm_version": ALGORITHM_VERSION,
		"reference_pixels_per_meter": REFERENCE_PIXELS_PER_METER,
		"stroke_width_px": stroke_width_px,
		"stroke_width_meters": stroke_width_meters(stroke_width_px) if is_finite(stroke_width_px) else 0.0,
		"has_outline": false,
		"outline_run_count": 0,
		"runs": [],
		"centerline": [],
		"vertices": [],
		"indices": PackedInt32Array(),
		"geometry_diagnostics": {"triangle_validation": "failed"}
	}
