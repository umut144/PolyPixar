class_name RibbonMeshService
extends RefCounted

const METHOD := "ribbon_strip"
const PIXELS_PER_METER := 128.0
const DEFAULT_WIDTH_PX := 8.0
const SAMPLE_SPACING_CM := 1.0
const FEATURE_DETAIL := 0.5
const EPSILON := 0.000001


static func width_cm(component: Dictionary) -> float:
	return maxf(float(component.get("ribbon_width_px", DEFAULT_WIDTH_PX)) * 100.0 / PIXELS_PER_METER, EPSILON)


static func validation_issues(component: Dictionary) -> Array[String]:
	var errors := BezierTopology.mode_validation_issues(component, true)
	if str(component.get("draw_mode", "closed_loop")) != "ribbon":
		errors.append("Ribbon Strip requires a Ribbon Component.")
	if float(component.get("ribbon_width_px", DEFAULT_WIDTH_PX)) <= 0.0:
		errors.append("Ribbon Strip requires a positive width.")
	return errors


static func generate(component: Dictionary) -> Dictionary:
	var source_fingerprint := GeometrySamplingService.source_fingerprint(component)
	var errors := validation_issues(component)
	if not errors.is_empty():
		return _failed_result(source_fingerprint, errors)
	var sampling := GeometrySamplingService.generate(component, {
		"method": GeometrySamplingService.ADAPTIVE,
		"allow_open": true,
		"parameters": {"spacing": SAMPLE_SPACING_CM, "feature_detail": FEATURE_DETAIL}
	})
	if not bool(sampling.get("valid", false)):
		return _failed_result(source_fingerprint, sampling.get("errors", []))
	var chains: Array = sampling.get("chains", [])
	if chains.size() != 1:
		return _failed_result(source_fingerprint, ["Ribbon Strip requires exactly one sampled Chain."])
	var samples: Array[Dictionary] = []
	for sample in chains[0].get("samples", []):
		if not sample is Dictionary:
			continue
		if samples.is_empty() or Vector2(samples.back().get("position", Vector2.ZERO)).distance_squared_to(Vector2(sample.get("position", Vector2.ZERO))) > EPSILON * EPSILON:
			samples.append(sample)
	if samples.size() < 2:
		return _failed_result(source_fingerprint, ["Ribbon Strip requires two distinct sampled Points."])
	var half_width := width_cm(component) * 0.5
	var vertices: Array = []
	var left_ids: Array[String] = []
	var right_ids: Array[String] = []
	for index in range(samples.size()):
		var current: Vector2 = samples[index].get("position", Vector2.ZERO)
		var previous: Vector2 = samples[maxi(index - 1, 0)].get("position", current)
		var next: Vector2 = samples[mini(index + 1, samples.size() - 1)].get("position", current)
		var tangent := (next - current) if index == 0 else (current - previous) if index == samples.size() - 1 else (next - previous)
		if tangent.length_squared() <= EPSILON * EPSILON:
			return _failed_result(source_fingerprint, ["Ribbon Strip contains a degenerate tangent."])
		var normal := Vector2(-tangent.y, tangent.x).normalized() * half_width
		var sample_id := str(samples[index].get("id", index))
		var left_id := "vertex:ribbon:%s:left" % sample_id
		var right_id := "vertex:ribbon:%s:right" % sample_id
		left_ids.append(left_id)
		right_ids.append(right_id)
		vertices.append({"id": left_id, "position": current + normal, "origin": "ribbon_left", "source_id": sample_id, "preserved": bool(samples[index].get("preserved", false))})
		vertices.append({"id": right_id, "position": current - normal, "origin": "ribbon_right", "source_id": sample_id, "preserved": bool(samples[index].get("preserved", false))})
	var triangles: Array = []
	for index in range(samples.size() - 1):
		triangles.append({"vertex_ids": [left_ids[index], right_ids[index], left_ids[index + 1]]})
		triangles.append({"vertex_ids": [right_ids[index], right_ids[index + 1], left_ids[index + 1]]})
	return {
		"valid": true, "errors": [], "method": METHOD, "source_fingerprint": source_fingerprint,
		"parameters": {"width_px": float(component.get("ribbon_width_px", DEFAULT_WIDTH_PX)), "width_cm": width_cm(component), "join": "bevel", "cap": "flat"},
		"vertices": vertices, "triangles": triangles, "boundary_constraints": [],
		"vertex_count": vertices.size(), "triangle_count": triangles.size()
	}


static func matches_source(mesh: Dictionary, component: Dictionary) -> bool:
	return bool(mesh.get("valid", false)) and str(mesh.get("method", "")) == METHOD and str(mesh.get("source_fingerprint", "")) == GeometrySamplingService.source_fingerprint(component)


static func _failed_result(source_fingerprint: String, errors: Array) -> Dictionary:
	return {"valid": false, "errors": errors.duplicate(), "method": METHOD, "source_fingerprint": source_fingerprint, "vertices": [], "triangles": [], "boundary_constraints": [], "vertex_count": 0, "triangle_count": 0}
