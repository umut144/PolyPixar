class_name MotionSequenceEvaluator
extends RefCounted


static func validation_issues(entry: Dictionary, asset: Dictionary, path_document: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	if entry.is_empty():
		return ["Add a Composition Entry."]
	if not bool(entry.get("enabled", true)):
		issues.append("The Composition Entry is disabled.")
	if asset.is_empty() or str(asset.get("id", "")) != str(entry.get("asset_id", "")):
		issues.append("The referenced Asset is missing.")
	var state := _state_by_id(asset, str(entry.get("animation_state_id", "")))
	if state.is_empty():
		issues.append("The referenced Animation State is missing from the Asset.")
	if path_document.is_empty() or str(path_document.get("id", "")) != str(entry.get("path_id", "")):
		issues.append("The referenced Path is missing.")
	elif not bool(MotionPathSampler.sample(path_document.get("topology", {}), 0.5).get("valid", false)):
		issues.append("The referenced Path needs at least two distinct Points.")
	return issues


static func evaluate(entry: Dictionary, asset: Dictionary, path_document: Dictionary, sequence_phase: float) -> Dictionary:
	var issues := validation_issues(entry, asset, path_document)
	var phase := clampf(sequence_phase, 0.0, 1.0)
	if not issues.is_empty():
		return {"valid": false, "issues": issues, "sequence_phase": phase}
	var playback: Dictionary = path_document.get("playback", {})
	var duration := maxf(0.01, float(playback.get("duration", 2.0)))
	var elapsed := phase * duration
	var state := _state_by_id(asset, str(entry.get("animation_state_id", "")))
	var cycle_duration := maxf(0.01, float(state.get("cycle_duration", 1.0)))
	var animation_phase := fmod(elapsed / cycle_duration, 1.0)
	var component_ids: Array[String] = []
	for component in asset.get("components", []):
		if bool(component.get("visibility", true)):
			component_ids.append(str(component.get("id", "")))
	var path_sample := MotionPathSampler.sample(path_document.get("topology", {}), phase)
	return {
		"valid": true,
		"issues": [],
		"sequence_phase": phase,
		"path_phase": phase,
		"animation_phase": animation_phase,
		"elapsed": elapsed,
		"duration": duration,
		"path_position": path_sample.get("position", Vector2.ZERO),
		"path_rotation": float(path_sample.get("rotation", 0.0)) if bool(playback.get("orient_along_path", false)) else 0.0,
		"component_samples": MotionSampler.sample_state(state, animation_phase, component_ids),
		"state_name": str(state.get("name", "State"))
	}


static func _state_by_id(asset: Dictionary, state_id: String) -> Dictionary:
	var animation = asset.get("animation", {})
	if not animation is Dictionary:
		return {}
	for state in animation.get("states", []):
		if state is Dictionary and str(state.get("id", "")) == state_id:
			return state
	return {}
