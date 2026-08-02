class_name MotionPathSampler
extends RefCounted

const SAMPLES_PER_SEGMENT := 32


static func sample(raw_topology, phase: float) -> Dictionary:
	var topology := MotionPathTopology.normalize(raw_topology)
	if not MotionPathTopology.validate(topology).is_empty() or topology["points"].size() < 2:
		return {"valid": false, "position": Vector2.ZERO, "rotation": 0.0, "progress": clampf(phase, 0.0, 1.0), "length": 0.0}
	var samples := sampled_points(topology)
	if samples.size() < 2:
		return {"valid": false, "position": Vector2.ZERO, "rotation": 0.0, "progress": clampf(phase, 0.0, 1.0), "length": 0.0}
	var cumulative := PackedFloat32Array([0.0])
	for index in range(1, samples.size()):
		cumulative.append(cumulative[index - 1] + samples[index - 1].distance_to(samples[index]))
	var total_length := cumulative[cumulative.size() - 1]
	if total_length <= 0.00001:
		return {"valid": false, "position": samples[0], "rotation": 0.0, "progress": clampf(phase, 0.0, 1.0), "length": 0.0}
	var progress := clampf(phase, 0.0, 1.0)
	var target_distance := total_length * progress
	for index in range(1, cumulative.size()):
		if cumulative[index] + 0.00001 < target_distance:
			continue
		var span := cumulative[index] - cumulative[index - 1]
		var local_weight := 0.0 if span <= 0.00001 else (target_distance - cumulative[index - 1]) / span
		var direction := samples[index] - samples[index - 1]
		return {
			"valid": true,
			"position": samples[index - 1].lerp(samples[index], local_weight),
			"rotation": rad_to_deg(direction.angle()) if direction.length_squared() > 0.000001 else 0.0,
			"progress": progress,
			"length": total_length
		}
	var final_direction: Vector2 = Vector2(samples.back()) - Vector2(samples[samples.size() - 2])
	return {"valid": true, "position": samples.back(), "rotation": rad_to_deg(final_direction.angle()) if final_direction.length_squared() > 0.000001 else 0.0, "progress": progress, "length": total_length}


static func sampled_points(raw_topology) -> Array[Vector2]:
	var topology := MotionPathTopology.normalize(raw_topology)
	var points_by_id: Dictionary = {}
	for point in topology["points"]:
		points_by_id[str(point.get("id", ""))] = point
	var samples: Array[Vector2] = []
	for segment in topology["segments"]:
		var start: Dictionary = points_by_id.get(str(segment.get("start_point_id", "")), {})
		var end: Dictionary = points_by_id.get(str(segment.get("end_point_id", "")), {})
		for sample_index in range(SAMPLES_PER_SEGMENT + 1):
			if not samples.is_empty() and sample_index == 0:
				continue
			samples.append(cubic_point(start, end, float(sample_index) / SAMPLES_PER_SEGMENT))
	return samples


static func cubic_point(start: Dictionary, end: Dictionary, t: float) -> Vector2:
	var p0: Vector2 = start.get("position", Vector2.ZERO)
	var p1 := p0 + Vector2(start.get("handle_out", Vector2.ZERO))
	var p3: Vector2 = end.get("position", Vector2.ZERO)
	var p2 := p3 + Vector2(end.get("handle_in", Vector2.ZERO))
	var inverse_t := 1.0 - clampf(t, 0.0, 1.0)
	var clamped_t := clampf(t, 0.0, 1.0)
	return inverse_t * inverse_t * inverse_t * p0 + 3.0 * inverse_t * inverse_t * clamped_t * p1 + 3.0 * inverse_t * clamped_t * clamped_t * p2 + clamped_t * clamped_t * clamped_t * p3
