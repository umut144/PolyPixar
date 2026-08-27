class_name ClosedRegionMeshService
extends RefCounted

## Derives an engine-neutral triangulation of a closed Contour's complete
## authored Boundary. This data has no material, color, alpha, UV, rendering,
## or visible-fill semantics.

const ALGORITHM_VERSION := 2
const GEOMETRY_EPSILON := ContourStrokeService.GEOMETRY_EPSILON
const AREA_RELATIVE_TOLERANCE := 0.00001


static func validation_issues(component: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for issue in _derive(component, false).get("errors", []):
		errors.append(str(issue))
	return errors


static func generate(component: Dictionary) -> Dictionary:
	return _derive(component, true)


static func _derive(component: Dictionary, include_mesh: bool) -> Dictionary:
	var errors: Array[String] = []
	if str(component.get("draw_mode", "")) != "contour":
		errors.append("Closed contour region geometry requires draw_mode 'contour'.")
	var chains: Array = component.get("chains", [])
	if chains.size() != 1 or not bool(chains[0].get("closed", false)):
		errors.append("Closed contour region geometry requires exactly one closed Chain.")
	for raw_point in component.get("points", []):
		if not raw_point is Dictionary:
			errors.append("Closed contour region Boundary contains an invalid Point record.")
			continue
		var position := Vector2(raw_point.get("position", Vector2.INF))
		var handle_in := Vector2(raw_point.get("handle_in", Vector2.ZERO))
		var handle_out := Vector2(raw_point.get("handle_out", Vector2.ZERO))
		if not position.is_finite() or not handle_in.is_finite() or not handle_out.is_finite():
			errors.append("Closed contour region Boundary contains non-finite Point or Bezier-handle coordinates.")
	if not errors.is_empty():
		return _failed(errors)
	var sampled := ContourStrokeService.sample_complete_boundary(component)
	if not bool(sampled.get("valid", false)):
		return _failed(sampled.get("errors", []))
	var samples: Array = sampled.get("samples", [])
	var positions := PackedVector2Array()
	var practically_unique: Array[Vector2] = []
	for sample in samples:
		if not sample is Dictionary:
			errors.append("Closed contour region Boundary contains an invalid sample record.")
			continue
		var position := Vector2(sample.get("position", Vector2.INF))
		if not position.is_finite():
			errors.append("Closed contour region Boundary contains a non-finite coordinate.")
			continue
		positions.append(position)
		if practically_unique.size() < 3:
			var is_unique := true
			for existing in practically_unique:
				if position.distance_squared_to(existing) <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
					is_unique = false
					break
			if is_unique:
				practically_unique.append(position)
	if positions.size() != samples.size():
		return _failed(errors)
	if practically_unique.size() < 3:
		errors.append("Closed contour region Boundary requires at least three unique points.")
	if not errors.is_empty():
		return _failed(errors)
	errors.append_array(ContourStrokeService.closed_boundary_validation_issues(samples))
	var signed_area_twice := _signed_area_twice(positions)
	if not is_finite(signed_area_twice):
		errors.append("Closed contour region Boundary area is not finite.")
	elif absf(signed_area_twice) <= GEOMETRY_EPSILON:
		errors.append("Closed contour region Boundary is degenerate or practically area-less.")
	if not errors.is_empty():
		return _failed(errors)
	var raw_indices := Geometry2D.triangulate_polygon(positions)
	if raw_indices.is_empty() or raw_indices.size() % 3 != 0:
		return _failed(["Closed contour region triangulation failed or returned an incomplete triangle index list."])
	var canonical_triangles: Array[Array] = []
	var triangulated_area_twice := 0.0
	for offset in range(0, raw_indices.size(), 3):
		var first := int(raw_indices[offset])
		var second := int(raw_indices[offset + 1])
		var third := int(raw_indices[offset + 2])
		if first < 0 or second < 0 or third < 0 or first >= positions.size() or second >= positions.size() or third >= positions.size():
			errors.append("Closed contour region triangulation produced an out-of-range triangle index.")
			continue
		if first == second or second == third or first == third:
			errors.append("Closed contour region triangulation produced degenerate triangle indices.")
			continue
		var triangle_area_twice := (positions[second] - positions[first]).cross(positions[third] - positions[first])
		if not is_finite(triangle_area_twice) or absf(triangle_area_twice) <= GEOMETRY_EPSILON:
			errors.append("Closed contour region triangulation produced a non-finite or degenerate triangle.")
			continue
		triangulated_area_twice += absf(triangle_area_twice)
		if triangle_area_twice < 0.0:
			var swap := second
			second = third
			third = swap
		canonical_triangles.append(_rotate_triangle_to_smallest(first, second, third))
	if not errors.is_empty():
		return _failed(errors)
	var area_tolerance := _area_tolerance(signed_area_twice, positions.size())
	if absf(triangulated_area_twice - absf(signed_area_twice)) > area_tolerance:
		return _failed(["Closed contour region triangulation is incomplete; triangle area does not cover the authored Boundary."])
	canonical_triangles.sort_custom(_triangle_less)
	if not include_mesh:
		return {"valid": true, "errors": []}
	var vertices: Array = []
	for vertex_index in range(samples.size()):
		var sample: Dictionary = samples[vertex_index]
		vertices.append({
			"id": "vertex:closed_region:%d" % vertex_index,
			"position": Vector2(sample.get("position", Vector2.ZERO)),
			"edge_id": str(sample.get("edge_id", "")),
			"curve_t": float(sample.get("curve_t", 0.0))
		})
	var triangles: Array = []
	for triangle_index in range(canonical_triangles.size()):
		var indices: Array = canonical_triangles[triangle_index]
		triangles.append({
			"id": "triangle:closed_region:%d" % triangle_index,
			"vertex_ids": [vertices[indices[0]]["id"], vertices[indices[1]]["id"], vertices[indices[2]]["id"]]
		})
	return {
		"valid": true,
		"errors": [],
		"algorithm_version": ALGORITHM_VERSION,
		"vertices": vertices,
		"triangles": triangles,
		"vertex_count": vertices.size(),
		"triangle_count": triangles.size(),
		"boundary_area_tool_units_squared": absf(signed_area_twice) * 0.5,
		"certified_max_deviation_meters": float(sampled.get("certified_max_deviation_tool_units", 0.0)) * ToolUnits.TO_METERS
	}


static func _signed_area_twice(positions: PackedVector2Array) -> float:
	var result := 0.0
	for index in range(positions.size()):
		result += positions[index].cross(positions[(index + 1) % positions.size()])
	return result


static func _area_tolerance(signed_area_twice: float, boundary_sample_count: int) -> float:
	# Polygon and triangle areas sum the same coordinates in different orders.
	# Allow one geometry epsilon per sampled Boundary vertex, plus a small
	# relative budget, while structural and self-intersection checks stay exact.
	return maxf(
		GEOMETRY_EPSILON * maxi(boundary_sample_count, 1),
		absf(signed_area_twice) * AREA_RELATIVE_TOLERANCE
	)


static func _rotate_triangle_to_smallest(first: int, second: int, third: int) -> Array:
	if second < first and second < third:
		return [second, third, first]
	if third < first and third < second:
		return [third, first, second]
	return [first, second, third]


static func _triangle_less(first: Array, second: Array) -> bool:
	for index in range(3):
		if int(first[index]) != int(second[index]):
			return int(first[index]) < int(second[index])
	return false


static func _failed(errors: Array) -> Dictionary:
	return {
		"valid": false,
		"errors": errors.duplicate(),
		"algorithm_version": ALGORITHM_VERSION,
		"vertices": [],
		"triangles": [],
		"vertex_count": 0,
		"triangle_count": 0
	}
