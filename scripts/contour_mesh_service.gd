class_name ContourMeshService
extends RefCounted

## Adapts the authored Boundary stroke to the accepted derived Mesh shape.
## It supports closed loops, analytic primitives, and open Contours and never
## derives or replaces Fill geometry.

const METHOD := "contour_stroke"
const ALGORITHM_VERSION := 3


static func validation_issues(component: Dictionary, stroke_width_px := ContourStrokeService.DEFAULT_STROKE_WIDTH_PX) -> Array[String]:
	var errors: Array[String] = []
	if str(component.get("draw_mode", "")) == "primitive":
		errors.append_array(PrimitiveGeometryService.validation_issues(component))
		if not is_finite(stroke_width_px) or stroke_width_px <= 0.0:
			errors.append("Contour stroke width must be a finite positive authored pixel value.")
	else:
		errors.append_array(ContourStrokeService.validation_issues(component, stroke_width_px))
	return errors


static func generate(component: Dictionary, stroke_width_px := ContourStrokeService.DEFAULT_STROKE_WIDTH_PX) -> Dictionary:
	var fingerprint := source_fingerprint(component, stroke_width_px)
	var errors := validation_issues(component, stroke_width_px)
	if not errors.is_empty():
		return _failed_result(fingerprint, errors)
	var stroke_source := component
	if str(component.get("draw_mode", "")) == "primitive":
		var proxy := _primitive_stroke_source(component)
		if not bool(proxy.get("valid", false)):
			return _failed_result(fingerprint, proxy.get("errors", []))
		stroke_source = proxy["component"]
	var stroke := ContourStrokeService.generate(stroke_source, stroke_width_px)
	if not bool(stroke.get("valid", false)):
		return _failed_result(fingerprint, stroke.get("errors", []))
	var vertices: Array = []
	var vertex_ids: Array[String] = []
	for vertex_index in range(stroke.get("vertices", []).size()):
		var stroke_vertex: Dictionary = stroke["vertices"][vertex_index]
		var vertex_id := "vertex:contour:%d" % vertex_index
		vertex_ids.append(vertex_id)
		vertices.append({
			"id": vertex_id,
			"position": Vector2(stroke_vertex.get("position", Vector2.ZERO)),
			"origin": str(stroke_vertex.get("role", "contour")),
			"source_id": "%s@%.9f" % [str(stroke_vertex.get("edge_id", "")), float(stroke_vertex.get("curve_t", 0.0))],
			"edge_id": str(stroke_vertex.get("edge_id", "")),
			"curve_t": float(stroke_vertex.get("curve_t", 0.0)),
			"preserved": false
		})
	var triangles: Array = []
	var indices: PackedInt32Array = stroke.get("indices", PackedInt32Array())
	for triangle_offset in range(0, indices.size(), 3):
		triangles.append({
			"id": "triangle:contour:%d" % int(float(triangle_offset) / 3.0),
			"vertex_ids": [vertex_ids[indices[triangle_offset]], vertex_ids[indices[triangle_offset + 1]], vertex_ids[indices[triangle_offset + 2]]]
		})
	return {
		"valid": true,
		"errors": [],
		"method": METHOD,
		"algorithm_version": ALGORITHM_VERSION,
		"source_fingerprint": fingerprint,
		"parameters": {
			"reference_pixels_per_meter": ContourStrokeService.REFERENCE_PIXELS_PER_METER,
			"stroke_width_px": stroke_width_px,
			"stroke_width_meters": ContourStrokeService.stroke_width_meters(stroke_width_px),
			"join": ContourStrokeService.JOIN_TYPE,
			"miter_limit": ContourStrokeService.MITER_LIMIT,
			"cap": ContourStrokeService.CAP_TYPE
		},
		"has_outline": bool(stroke.get("has_outline", false)),
		"source_draw_mode": str(component.get("draw_mode", "closed_loop")),
		"source_chain_closed": bool(stroke.get("source_chain_closed", false)),
		"topology_role": str(component.get("topology_role", "outer")),
		"runs": stroke.get("runs", []).duplicate(true),
		"geometry_diagnostics": stroke.get("geometry_diagnostics", {}).duplicate(true),
		"vertices": vertices,
		"triangles": triangles,
		"boundary_constraints": [],
		"vertex_count": vertices.size(),
		"triangle_count": triangles.size()
	}


static func _primitive_stroke_source(component: Dictionary) -> Dictionary:
	var radii := PrimitiveGeometryService.diameters_tool_units(component) * 0.5
	var center := PrimitiveGeometryService.center(component)
	var tolerance := (ContourStrokeService.MAX_DEVIATION_PX / ContourStrokeService.REFERENCE_PIXELS_PER_METER) / ToolUnits.TO_METERS
	var positions: Array[Vector2] = [center + Vector2.RIGHT * radii.x]
	var state := {"error": ""}
	for quadrant in range(4):
		_append_primitive_arc(positions, center, radii, TAU * float(quadrant) / 4.0, TAU * float(quadrant + 1) / 4.0, tolerance, 0, state)
		if not str(state.get("error", "")).is_empty():
			return {"valid": false, "errors": [state["error"]]}
	positions.pop_back()
	var points: Array = []
	var edges: Array = []
	var point_ids: Array[String] = []
	var edge_ids: Array[String] = []
	var primitive_type := str(component.get("primitive", {}).get("type", "primitive"))
	for index in range(positions.size()):
		var point_id := "primitive:%s:point:%d" % [primitive_type, index]
		var edge_id := "primitive:%s:edge:%d" % [primitive_type, index]
		point_ids.append(point_id)
		edge_ids.append(edge_id)
		points.append({"id": point_id, "position": positions[index], "mode": "linear", "handle_source": "manual", "handle_in": Vector2.ZERO, "handle_out": Vector2.ZERO, "preserve_point": false})
		edges.append({"id": edge_id, "start_point_id": point_id, "end_point_id": "", "render_outline": OutlineService.ON})
	for index in range(edges.size()):
		edges[index]["end_point_id"] = point_ids[(index + 1) % point_ids.size()]
	return {"valid": true, "errors": [], "component": {
		"draw_mode": "closed_loop",
		"topology_role": "outer",
		"points": points,
		"edges": edges,
		"chains": [{"id": "primitive:%s" % primitive_type, "point_ids": point_ids, "edge_ids": edge_ids, "closed": true, "topology_role": "outer"}]
	}}


static func _append_primitive_arc(positions: Array[Vector2], center: Vector2, radii: Vector2, angle_start: float, angle_end: float, tolerance: float, depth: int, state: Dictionary) -> void:
	if not str(state.get("error", "")).is_empty():
		return
	var start := center + Vector2(cos(angle_start) * radii.x, sin(angle_start) * radii.y)
	var end := center + Vector2(cos(angle_end) * radii.x, sin(angle_end) * radii.y)
	var angle_middle := (angle_start + angle_end) * 0.5
	var middle := center + Vector2(cos(angle_middle) * radii.x, sin(angle_middle) * radii.y)
	var tangent_start := Vector2(-sin(angle_start) * radii.x, cos(angle_start) * radii.y).normalized()
	var tangent_end := Vector2(-sin(angle_end) * radii.x, cos(angle_end) * radii.y).normalized()
	var split_required := middle.distance_to((start + end) * 0.5) > tolerance or absf(tangent_start.angle_to(tangent_end)) > ContourStrokeService.MAX_TANGENT_TURN_RADIANS
	if split_required:
		if depth >= ContourStrokeService.MAX_SAMPLE_DEPTH or positions.size() >= ContourStrokeService.MAX_SAMPLES_PER_EDGE:
			state["error"] = "Analytic primitive contour sampling exceeded its deterministic limit."
			return
		_append_primitive_arc(positions, center, radii, angle_start, angle_middle, tolerance, depth + 1, state)
		_append_primitive_arc(positions, center, radii, angle_middle, angle_end, tolerance, depth + 1, state)
		return
	positions.append(end)


static func matches_source(mesh: Dictionary, component: Dictionary, stroke_width_px := ContourStrokeService.DEFAULT_STROKE_WIDTH_PX) -> bool:
	return bool(mesh.get("valid", false)) \
		and str(mesh.get("method", "")) == METHOD \
		and int(mesh.get("algorithm_version", 0)) == ALGORITHM_VERSION \
		and str(mesh.get("source_fingerprint", "")) == source_fingerprint(component, stroke_width_px)


static func source_fingerprint(component: Dictionary, stroke_width_px := ContourStrokeService.DEFAULT_STROKE_WIDTH_PX) -> String:
	var outline_parts := PackedStringArray()
	for edge in component.get("edges", []):
		if edge is Dictionary:
			outline_parts.append("%s:%d" % [str(edge.get("id", "")), int(OutlineService.is_enabled(edge))])
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(("%s\ncontour_mesh|%d|stroke|%d|width_px|%.9f|outline|%s" % [
		GeometrySamplingService.source_fingerprint(component),
		ALGORITHM_VERSION,
		ContourStrokeService.ALGORITHM_VERSION,
		stroke_width_px,
		",".join(outline_parts)
	]).to_utf8_buffer())
	return context.finish().hex_encode()


static func _failed_result(source_fingerprint_value: String, errors: Array) -> Dictionary:
	return {
		"valid": false,
		"errors": errors.duplicate(),
		"method": METHOD,
		"algorithm_version": ALGORITHM_VERSION,
		"source_fingerprint": source_fingerprint_value,
		"geometry_diagnostics": {"triangle_validation": "failed"},
		"vertices": [],
		"triangles": [],
		"boundary_constraints": [],
		"vertex_count": 0,
		"triangle_count": 0
	}
