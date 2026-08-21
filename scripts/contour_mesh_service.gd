class_name ContourMeshService
extends RefCounted

## Adapts the authored open Contour stroke to the accepted Component Mesh
## shape used by PolyTools' derived-geometry pipeline. It never derives a fill.

const METHOD := "contour_stroke"
const ALGORITHM_VERSION := 1


static func validation_issues(component: Dictionary) -> Array[String]:
	var errors := ContourStrokeService.validation_issues(component, ContourStrokeService.DEFAULT_STROKE_WIDTH_PX)
	if str(component.get("draw_mode", "")) != "contour":
		errors.append("Contour Stroke Mesh requires an open Contour Component.")
	return errors


static func generate(component: Dictionary) -> Dictionary:
	var fingerprint := source_fingerprint(component)
	var errors := validation_issues(component)
	if not errors.is_empty():
		return _failed_result(fingerprint, errors)
	var stroke := ContourStrokeService.generate(component, ContourStrokeService.DEFAULT_STROKE_WIDTH_PX)
	if not bool(stroke.get("valid", false)):
		return _failed_result(fingerprint, stroke.get("errors", []))
	if not bool(stroke.get("has_outline", false)):
		return _failed_result(fingerprint, ["An open Contour with no visible outline Edges has no renderable geometry."])
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
			"id": "triangle:contour:%d" % (triangle_offset / 3),
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
			"stroke_width_px": ContourStrokeService.DEFAULT_STROKE_WIDTH_PX,
			"stroke_width_meters": ContourStrokeService.stroke_width_meters(),
			"join": ContourStrokeService.JOIN_TYPE,
			"miter_limit": ContourStrokeService.MITER_LIMIT,
			"cap": ContourStrokeService.CAP_TYPE
		},
		"runs": stroke.get("runs", []).duplicate(true),
		"vertices": vertices,
		"triangles": triangles,
		"boundary_constraints": [],
		"vertex_count": vertices.size(),
		"triangle_count": triangles.size()
	}


static func matches_source(mesh: Dictionary, component: Dictionary) -> bool:
	return bool(mesh.get("valid", false)) \
		and str(mesh.get("method", "")) == METHOD \
		and int(mesh.get("algorithm_version", 0)) == ALGORITHM_VERSION \
		and str(mesh.get("source_fingerprint", "")) == source_fingerprint(component)


static func source_fingerprint(component: Dictionary) -> String:
	var outline_parts := PackedStringArray()
	for edge in component.get("edges", []):
		if edge is Dictionary:
			outline_parts.append("%s:%d" % [str(edge.get("id", "")), int(bool(edge.get("render_outline", true)))])
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(("%s\ncontour_mesh|%d|stroke|%d|width_px|%.9f|outline|%s" % [
		GeometrySamplingService.source_fingerprint(component),
		ALGORITHM_VERSION,
		ContourStrokeService.ALGORITHM_VERSION,
		ContourStrokeService.DEFAULT_STROKE_WIDTH_PX,
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
		"vertices": [],
		"triangles": [],
		"boundary_constraints": [],
		"vertex_count": 0,
		"triangle_count": 0
	}
