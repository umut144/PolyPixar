class_name MotionSampler
extends RefCounted


static func identity_transform() -> Dictionary:
	return {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE}


static func sample_player(player: MotionPlayer, component_ids: Array[String]) -> Dictionary:
	if player == null or player.current_state_id.is_empty():
		return {}
	var target_samples := sample_state(player.current_state(), player.phase, component_ids)
	if player.blend.is_empty():
		return target_samples
	var source_state := _find_state(player.document, str(player.blend.get("source_state_id", "")))
	var source_samples := sample_state(source_state, float(player.blend.get("source_phase", 0.0)), component_ids)
	return blend_samples(source_samples, target_samples, component_ids, player.blend_weight())


static func sample_state(state: Dictionary, phase: float, component_ids: Array[String]) -> Dictionary:
	var samples := {}
	if state.is_empty():
		return samples
	for motion in state.get("motions", []):
		if not bool(motion.get("enabled", true)) or str(motion.get("domain", MotionWorkspace.OUTER)) != MotionWorkspace.OUTER:
			continue
		if str(motion.get("primitive", "")) != MotionWorkspace.BOB:
			continue
		var parameters: Dictionary = motion.get("parameters", {})
		var distance := float(parameters.get("distance", 0.0))
		var cycles := float(parameters.get("cycles", 1.0))
		var phase_offset := float(motion.get("phase_offset", 0.0))
		var offset := Vector2(0.0, sin(TAU * (phase * cycles + phase_offset)) * distance)
		var targets: Array[String] = []
		if str(motion.get("target_scope", MotionWorkspace.TARGET_COMPONENT)) == MotionWorkspace.TARGET_ASSET:
			targets.assign(component_ids)
		else:
			var component_id := str(motion.get("target_component_id", ""))
			if component_id in component_ids:
				targets.append(component_id)
		for component_id in targets:
			var sample: Dictionary = samples.get(component_id, identity_transform())
			sample["position"] = Vector2(sample.get("position", Vector2.ZERO)) + offset
			samples[component_id] = sample
	return samples


static func blend_samples(source_samples: Dictionary, target_samples: Dictionary, component_ids: Array[String], weight: float) -> Dictionary:
	var result := {}
	var clamped_weight := clampf(weight, 0.0, 1.0)
	for component_id in component_ids:
		var source: Dictionary = source_samples.get(component_id, identity_transform())
		var target: Dictionary = target_samples.get(component_id, identity_transform())
		result[component_id] = {
			"position": Vector2(source.get("position", Vector2.ZERO)).lerp(Vector2(target.get("position", Vector2.ZERO)), clamped_weight),
			"rotation": lerpf(float(source.get("rotation", 0.0)), float(target.get("rotation", 0.0)), clamped_weight),
			"scale": Vector2(source.get("scale", Vector2.ONE)).lerp(Vector2(target.get("scale", Vector2.ONE)), clamped_weight)
		}
	return result


static func _find_state(document: Dictionary, state_id: String) -> Dictionary:
	for state in document.get("states", []):
		if str(state.get("id", "")) == state_id:
			return state
	return {}
