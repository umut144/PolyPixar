class_name MotionPlayer
extends RefCounted

signal phase_changed(phase: float)
signal state_changed(previous_state_id: String, state_id: String)
signal marker_fired(state_id: String, event_id: String, kind: String)
signal playback_changed(playing: bool)

var document: Dictionary = {}
var current_state_id := ""
var phase := 0.0
var playing := false
var loop := true
var parameter_values: Dictionary = {}
var blend: Dictionary = {}


func set_document(value: Dictionary) -> void:
	document = value
	_sync_parameter_values()
	if _find_state(current_state_id).is_empty():
		var states: Array = document.get("states", [])
		current_state_id = str(states[0].get("id", "")) if not states.is_empty() else ""
		phase = 0.0
		blend.clear()
		phase_changed.emit(phase)


func set_state(state_id: String, entry_phase := 0.0) -> bool:
	if _find_state(state_id).is_empty():
		return false
	var previous_state_id := current_state_id
	current_state_id = state_id
	phase = clampf(entry_phase, 0.0, 1.0)
	blend.clear()
	if previous_state_id != current_state_id:
		state_changed.emit(previous_state_id, current_state_id)
	phase_changed.emit(phase)
	return true


func play() -> bool:
	if current_state_id.is_empty():
		return false
	if not playing:
		playing = true
		playback_changed.emit(true)
	return true


func pause() -> void:
	if playing:
		playing = false
		playback_changed.emit(false)


func toggle_playback() -> void:
	if playing:
		pause()
	else:
		play()


func seek(value: float) -> void:
	phase = clampf(value, 0.0, 1.0)
	blend.clear()
	phase_changed.emit(phase)


func set_parameter_value(parameter_id: String, value) -> bool:
	var parameter := _find_parameter(parameter_id)
	if parameter.is_empty():
		return false
	if str(parameter.get("type", MotionWorkspace.PARAM_NUMBER)) == MotionWorkspace.PARAM_BOOL:
		parameter_values[parameter_id] = bool(value)
	else:
		parameter_values[parameter_id] = float(value)
	return true


func parameter_value(parameter_id: String):
	return parameter_values.get(parameter_id)


func advance(delta: float) -> void:
	if not playing or delta <= 0.0:
		return
	var state := _find_state(current_state_id)
	if state.is_empty():
		pause()
		return
	var previous_phase := phase
	var duration := maxf(0.01, float(state.get("cycle_duration", 1.0)))
	var raw_phase := phase + delta / duration
	var crossed_loop := raw_phase >= 1.0
	phase = fposmod(raw_phase, 1.0) if loop else minf(raw_phase, 1.0)
	_emit_crossed_markers(state, previous_phase, phase, crossed_loop)
	_advance_blend(delta)
	var transition := _first_eligible_transition(state, crossed_loop)
	if not transition.is_empty():
		_take_transition(state, transition)
	phase_changed.emit(phase)


func blend_weight() -> float:
	if blend.is_empty():
		return 1.0
	var duration := float(blend.get("duration", 0.0))
	return 1.0 if duration <= 0.0 else clampf(float(blend.get("elapsed", 0.0)) / duration, 0.0, 1.0)


func current_state() -> Dictionary:
	return _find_state(current_state_id)


func current_state_name() -> String:
	return str(current_state().get("name", "None"))


func _sync_parameter_values() -> void:
	var retained_values := parameter_values.duplicate(true)
	parameter_values.clear()
	for parameter in document.get("simulation_contract", {}).get("parameters", []):
		var parameter_id := str(parameter.get("id", ""))
		var parameter_type := str(parameter.get("type", MotionWorkspace.PARAM_NUMBER))
		var fallback: Variant = 0.0
		if parameter_type == MotionWorkspace.PARAM_BOOL:
			fallback = false
		var retained: Variant = retained_values.get(parameter_id, fallback)
		if parameter_type == MotionWorkspace.PARAM_BOOL:
			parameter_values[parameter_id] = bool(retained)
		else:
			parameter_values[parameter_id] = float(retained)


func _find_state(state_id: String) -> Dictionary:
	for state in document.get("states", []):
		if str(state.get("id", "")) == state_id:
			return state
	return {}


func _find_parameter(parameter_id: String) -> Dictionary:
	for parameter in document.get("simulation_contract", {}).get("parameters", []):
		if str(parameter.get("id", "")) == parameter_id:
			return parameter
	return {}


func _first_eligible_transition(state: Dictionary, crossed_loop: bool) -> Dictionary:
	for transition in state.get("transitions", []):
		if _exit_policy_allows(transition, crossed_loop) and _rules_match(transition.get("rules", [])):
			if not _find_state(str(transition.get("target_state_id", ""))).is_empty():
				return transition
	return {}


func _exit_policy_allows(transition: Dictionary, crossed_loop: bool) -> bool:
	match str(transition.get("exit_policy", MotionWorkspace.EXIT_ANY_PHASE)):
		MotionWorkspace.EXIT_AFTER_PHASE:
			return phase >= float(transition.get("exit_phase", 0.0))
		MotionWorkspace.EXIT_LOOP_END:
			return crossed_loop
		_:
			return true


func _rules_match(rules: Array) -> bool:
	for rule in rules:
		var parameter := _find_parameter(str(rule.get("parameter_id", "")))
		if parameter.is_empty() or not _rule_matches(parameter, rule):
			return false
	return true


func _rule_matches(parameter: Dictionary, rule: Dictionary) -> bool:
	var parameter_id := str(parameter.get("id", ""))
	if not parameter_values.has(parameter_id):
		return false
	var operator := str(rule.get("operator", ""))
	if str(parameter.get("type", MotionWorkspace.PARAM_NUMBER)) == MotionWorkspace.PARAM_BOOL:
		var bool_value := bool(parameter_values[parameter_id])
		return bool_value if operator == MotionWorkspace.OP_IS_TRUE else (not bool_value if operator == MotionWorkspace.OP_IS_FALSE else false)
	var left := float(parameter_values[parameter_id])
	var right := float(rule.get("value", 0.0))
	match operator:
		MotionWorkspace.OP_EQUAL: return is_equal_approx(left, right)
		MotionWorkspace.OP_NOT_EQUAL: return not is_equal_approx(left, right)
		MotionWorkspace.OP_GREATER: return left > right
		MotionWorkspace.OP_GREATER_EQUAL: return left >= right
		MotionWorkspace.OP_LESS: return left < right
		MotionWorkspace.OP_LESS_EQUAL: return left <= right
		_: return false


func _take_transition(source_state: Dictionary, transition: Dictionary) -> void:
	var target_state_id := str(transition.get("target_state_id", ""))
	var previous_state_id := current_state_id
	var source_phase := phase
	var blend_duration := maxf(0.0, float(transition.get("blend_duration", 0.0)))
	blend = {
		"source_state_id": previous_state_id,
		"source_phase": source_phase,
		"source_cycle_duration": maxf(0.01, float(source_state.get("cycle_duration", 1.0))),
		"target_state_id": target_state_id,
		"elapsed": 0.0,
		"duration": blend_duration
	}
	current_state_id = target_state_id
	if str(transition.get("entry_mode", MotionWorkspace.ENTRY_RESTART)) == MotionWorkspace.ENTRY_RESTART:
		phase = 0.0
	if blend_duration <= 0.0:
		blend.clear()
	state_changed.emit(previous_state_id, current_state_id)


func _advance_blend(delta: float) -> void:
	if blend.is_empty():
		return
	blend["elapsed"] = float(blend.get("elapsed", 0.0)) + delta
	var source_duration := maxf(0.01, float(blend.get("source_cycle_duration", 1.0)))
	blend["source_phase"] = fposmod(float(blend.get("source_phase", 0.0)) + delta / source_duration, 1.0)
	if float(blend.get("elapsed", 0.0)) >= float(blend.get("duration", 0.0)):
		blend.clear()


func _emit_crossed_markers(state: Dictionary, previous_phase: float, current_phase_value: float, crossed_loop: bool) -> void:
	for marker in state.get("markers", []):
		var marker_phase := float(marker.get("phase", 0.0))
		var crossed := marker_phase > previous_phase and marker_phase <= current_phase_value
		if crossed_loop and loop:
			crossed = marker_phase > previous_phase or marker_phase <= current_phase_value
		if crossed:
			marker_fired.emit(str(state.get("id", "")), str(marker.get("event_id", "")), str(marker.get("kind", MotionWorkspace.MARKER_EVENT)))
