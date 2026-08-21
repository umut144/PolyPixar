class_name ContourStrokeService
extends RefCounted

## Slice 1 of the authored contour pipeline. The source Bezier boundary is the
## stroke centerline; this service derives a deterministic, centered mesh from
## one closed outer Chain without changing canonical Component topology.

const ALGORITHM_VERSION := 1
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


static func stroke_width_meters(stroke_width_px := DEFAULT_STROKE_WIDTH_PX) -> float:
	return stroke_width_px / REFERENCE_PIXELS_PER_METER


static func generate(component: Dictionary, stroke_width_px := DEFAULT_STROKE_WIDTH_PX) -> Dictionary:
	var errors := validation_issues(component, stroke_width_px)
	if not errors.is_empty():
		return _failed_result(errors, stroke_width_px)
	var working_component := component.duplicate(true)
	BezierGeometry.resolve_auto_handles(working_component.get("points", []), working_component.get("chains", []))
	var chain := BezierTopology.outer_chain(working_component)
	var sampled := _sample_chain(working_component, chain)
	if not bool(sampled.get("valid", false)):
		return _failed_result(sampled.get("errors", []), stroke_width_px)
	var centerline: Array = sampled.get("samples", [])
	var width_meters := stroke_width_meters(stroke_width_px)
	var width_tool_units := width_meters / ToolUnits.TO_METERS
	var mesh := _build_closed_mesh(centerline, width_tool_units * 0.5)
	if not bool(mesh.get("valid", false)):
		return _failed_result(mesh.get("errors", []), stroke_width_px)
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
		"closed": true,
		"chain_id": str(chain.get("id", "")),
		"centerline": centerline,
		"vertices": mesh.get("vertices", []),
		"indices": mesh.get("indices", PackedInt32Array()),
		"triangle_count": int(mesh.get("triangle_count", 0)),
		"miter_join_count": int(mesh.get("miter_join_count", 0)),
		"bevel_join_count": int(mesh.get("bevel_join_count", 0))
	}


static func validation_issues(component: Dictionary, stroke_width_px := DEFAULT_STROKE_WIDTH_PX) -> Array[String]:
	var errors := BezierTopology.validate(component)
	if not is_finite(stroke_width_px) or stroke_width_px <= 0.0:
		errors.append("Contour stroke width must be a finite positive authored pixel value.")
	if str(component.get("draw_mode", "closed_loop")) != "closed_loop":
		errors.append("Contour Stroke Slice 1 requires a Closed Loop Component.")
	var chains: Array = component.get("chains", [])
	if chains.size() != 1:
		errors.append("Contour Stroke Slice 1 requires exactly one Chain.")
		return errors
	var chain: Dictionary = chains[0]
	if str(chain.get("topology_role", "outer")) != "outer":
		errors.append("Contour Stroke Slice 1 requires an outer Chain.")
	if not bool(chain.get("closed", false)) or chain.get("point_ids", []).size() < 3:
		errors.append("Contour Stroke Slice 1 requires one closed Chain with at least three Points.")
	for edge_id_value in chain.get("edge_ids", []):
		var edge := BezierTopology.edge_by_id(component.get("edges", []), str(edge_id_value))
		if not edge.is_empty() and not bool(edge.get("render_outline", true)):
			errors.append("Contour Stroke Slice 1 does not yet support disabled Render Outline edges.")
			break
	return errors


static func _sample_chain(component: Dictionary, chain: Dictionary) -> Dictionary:
	var samples: Array = []
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
		var controls := BezierGeometry.cubic_controls(start_point, end_point)
		if samples.is_empty():
			samples.append(_centerline_sample(controls[0], edge_id, 0.0, str(edge.get("start_point_id", ""))))
		var edge_samples: Array = []
		var edge_stats := {"maximum_flatness": 0.0, "error": ""}
		_sample_cubic(controls, edge_id, 0.0, 1.0, 0, edge_samples, edge_stats)
		if not str(edge_stats.get("error", "")).is_empty():
			errors.append(str(edge_stats["error"]))
			continue
		maximum_flatness = maxf(maximum_flatness, float(edge_stats["maximum_flatness"]))
		samples.append_array(edge_samples)
	if not samples.is_empty() and Vector2(samples.front().get("position", Vector2.ZERO)).is_equal_approx(Vector2(samples.back().get("position", Vector2.ZERO))):
		samples.pop_back()
	if samples.size() < 3:
		errors.append("Contour stroke sampling produced fewer than three distinct centerline samples.")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"samples": samples,
		"certified_max_deviation_tool_units": maximum_flatness
	}


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


static func _build_closed_mesh(centerline: Array, half_width: float) -> Dictionary:
	var vertices: Array = []
	var indices := PackedInt32Array()
	var segment_count := centerline.size()
	var directions: Array[Vector2] = []
	var normals: Array[Vector2] = []
	var errors: Array[String] = []
	for sample_index in range(segment_count):
		var start := Vector2(centerline[sample_index].get("position", Vector2.ZERO))
		var end := Vector2(centerline[(sample_index + 1) % segment_count].get("position", Vector2.ZERO))
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
		var end_sample: Dictionary = centerline[(segment_index + 1) % segment_count]
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
	for join_index in range(segment_count):
		var previous_index := posmod(join_index - 1, segment_count)
		var previous_direction := directions[previous_index]
		var next_direction := directions[join_index]
		var turn := previous_direction.cross(next_direction)
		if absf(turn) <= GEOMETRY_EPSILON:
			continue
		var position := Vector2(centerline[join_index].get("position", Vector2.ZERO))
		var outer_sign := 1.0 if turn > 0.0 else -1.0
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
	return {
		"valid": true,
		"errors": [],
		"vertices": vertices,
		"indices": indices,
		"triangle_count": indices.size() / 3,
		"miter_join_count": miter_join_count,
		"bevel_join_count": bevel_join_count
	}


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
		"vertices": [],
		"indices": PackedInt32Array()
	}
