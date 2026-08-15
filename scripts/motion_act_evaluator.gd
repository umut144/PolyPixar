class_name MotionActEvaluator
extends RefCounted

const KIND_PRIMITIVE := "primitive"
const SLIDE := "slide"
const JUMP := "jump"
const BLINK := "blink"
const PRIMITIVES := [SLIDE, JUMP, BLINK]
const EASE_LINEAR := "linear"
const EASE_IN := "ease_in"
const EASE_OUT := "ease_out"
const EASE_IN_OUT := "ease_in_out"
const EASING_OPTIONS := [EASE_LINEAR, EASE_IN, EASE_OUT, EASE_IN_OUT]
const JUMP_ARC_SMOOTH := "smooth"
const JUMP_ARC_FLOATY := "floaty"
const JUMP_ARC_SNAPPY := "snappy"
const JUMP_ARC_OPTIONS := [JUMP_ARC_SMOOTH, JUMP_ARC_FLOATY, JUMP_ARC_SNAPPY]


static func primitive_definitions() -> Array[Dictionary]:
	return [
		{"id": SLIDE, "label": "Slide"},
		{"id": JUMP, "label": "Jump"},
		{"id": BLINK, "label": "Blink"}
	]


static func primitive_label(primitive: String) -> String:
	match primitive:
		JUMP: return "Jump"
		BLINK: return "Blink"
		_: return "Slide"


static func default_duration(primitive: String) -> float:
	match primitive:
		JUMP: return 0.8
		BLINK: return 0.7
		_: return 0.6


static func default_parameters(primitive: String) -> Dictionary:
	var result := {"direction": Vector2.RIGHT, "distance": 4.0}
	if primitive == JUMP:
		result["height"] = 3.0
		result["arc"] = JUMP_ARC_SMOOTH
	elif primitive == BLINK:
		result["distance"] = 6.0
		result["anticipation_distance"] = 1.0
		result["anticipation_share"] = 0.5
		result["minimum_scale"] = 0.05
	return result


static func validation_issues(act: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	if act.is_empty():
		return ["Select or create an Act."]
	if str(act.get("kind", KIND_PRIMITIVE)) != KIND_PRIMITIVE:
		issues.append("Act Groups are not available in this phase.")
	var primitive := str(act.get("primitive", SLIDE))
	if primitive not in PRIMITIVES:
		issues.append("The selected Act primitive is not supported.")
	if not bool(act.get("enabled", true)):
		issues.append("The Act is disabled.")
	var direction := _vector(act.get("parameters", {}).get("direction", Vector2.RIGHT))
	if direction.length_squared() <= 0.000001:
		issues.append("%s Direction must not be zero." % primitive_label(primitive))
	if float(act.get("parameters", {}).get("distance", 0.0)) < 0.0:
		issues.append("%s Distance must not be negative." % primitive_label(primitive))
	if primitive == JUMP:
		if float(act.get("parameters", {}).get("height", 0.0)) <= 0.0:
			issues.append("Jump Height must be greater than zero.")
		if str(act.get("parameters", {}).get("arc", JUMP_ARC_SMOOTH)) not in JUMP_ARC_OPTIONS:
			issues.append("The Jump Arc value is unsupported.")
	elif primitive == BLINK:
		if float(act.get("parameters", {}).get("distance", 0.0)) <= 0.0:
			issues.append("Blink Distance must be greater than zero.")
		if float(act.get("parameters", {}).get("anticipation_distance", 0.0)) < 0.0:
			issues.append("Blink Anticipation Distance must not be negative.")
		var anticipation_share := float(act.get("parameters", {}).get("anticipation_share", 0.0))
		if anticipation_share <= 0.0 or anticipation_share >= 0.9:
			issues.append("Blink Anticipation Share must be between 0 and 0.9.")
		var minimum_scale := float(act.get("parameters", {}).get("minimum_scale", 0.0))
		if minimum_scale <= 0.0 or minimum_scale > 1.0:
			issues.append("Blink Minimum Scale must be greater than 0 and at most 1.")
	if float(act.get("timing", {}).get("duration", 0.0)) <= 0.0:
		issues.append("Act Duration must be greater than zero.")
	if str(act.get("timing", {}).get("easing", EASE_LINEAR)) not in EASING_OPTIONS:
		issues.append("The Act Easing value is unsupported.")
	return issues


static func sample(act: Dictionary, phase: float) -> Dictionary:
	var normalized_phase := clampf(phase, 0.0, 1.0)
	var issues := validation_issues(act)
	if not issues.is_empty():
		return {"valid": false, "issues": issues, "phase": normalized_phase, "eased_phase": 0.0, "transform": MotionSampler.identity_transform()}
	var easing := str(act.get("timing", {}).get("easing", EASE_LINEAR))
	var eased_phase := apply_easing(normalized_phase, easing)
	var parameters: Dictionary = act.get("parameters", {})
	var direction := _vector(parameters.get("direction", Vector2.RIGHT)).normalized()
	var distance := maxf(0.0, float(parameters.get("distance", 0.0)))
	var transform := MotionSampler.identity_transform()
	match str(act.get("primitive", SLIDE)):
		JUMP:
			transform["position"] = direction * distance * eased_phase
			var height := maxf(0.0, float(parameters.get("height", 0.0)))
			var arc_value := maxf(0.0, sin(PI * eased_phase))
			var arc_power := _jump_arc_power(str(parameters.get("arc", JUMP_ARC_SMOOTH)))
			# PolyTools' authoring space is Y-positive-up; screen conversion happens
			# only inside the Preview renderer.
			transform["position"] += Vector2(0.0, 1.0) * height * pow(arc_value, arc_power)
		BLINK:
			transform = _sample_blink(parameters, direction, distance, normalized_phase, easing)
		_:
			transform["position"] = direction * distance * eased_phase
	return {"valid": true, "issues": [], "phase": normalized_phase, "eased_phase": eased_phase, "transform": transform}


static func _sample_blink(parameters: Dictionary, direction: Vector2, distance: float, phase: float, easing: String) -> Dictionary:
	var transform := MotionSampler.identity_transform()
	var anticipation_distance := maxf(0.0, float(parameters.get("anticipation_distance", 1.0)))
	var anticipation_share := clampf(float(parameters.get("anticipation_share", 0.5)), 0.001, 0.899)
	var minimum_scale := clampf(float(parameters.get("minimum_scale", 0.05)), 0.001, 1.0)
	if phase <= anticipation_share:
		var anticipation_phase := phase / anticipation_share
		var anticipation_curve := apply_easing(anticipation_phase, EASE_IN_OUT)
		transform["position"] = -direction * anticipation_distance * anticipation_curve
		return transform
	# The post-anticipation time is intentionally asymmetric: 80% reaches the
	# spatial midpoint and the final 20% exits it. With the default 0.5
	# anticipation this yields the authored 50/40/10 timing split.
	var midpoint_phase := anticipation_share + (1.0 - anticipation_share) * 0.8
	var scalar_position := 0.0
	if phase <= midpoint_phase:
		var ingress_phase := (phase - anticipation_share) / maxf(0.0001, midpoint_phase - anticipation_share)
		scalar_position = lerpf(-anticipation_distance, distance * 0.5, apply_easing(ingress_phase, easing))
	else:
		var exit_phase := (phase - midpoint_phase) / maxf(0.0001, 1.0 - midpoint_phase)
		scalar_position = lerpf(distance * 0.5, distance, apply_easing(exit_phase, EASE_OUT))
	transform["position"] = direction * scalar_position
	# Scale remains one behind the authored start. Once the Asset crosses the
	# start, its spatial progress—not raw time—drives the wormhole contraction.
	var spatial_phase := clampf(scalar_position / distance, 0.0, 1.0)
	var distance_from_middle := absf(spatial_phase * 2.0 - 1.0)
	var scale_curve := smoothstep(0.0, 1.0, distance_from_middle)
	var uniform_scale := lerpf(minimum_scale, 1.0, scale_curve)
	transform["scale"] = Vector2.ONE * uniform_scale
	return transform


static func apply_easing(phase: float, easing: String) -> float:
	var t := clampf(phase, 0.0, 1.0)
	match easing:
		EASE_IN:
			return t * t
		EASE_OUT:
			return 1.0 - (1.0 - t) * (1.0 - t)
		EASE_IN_OUT:
			return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) * 0.5
		_:
			return t


static func easing_label(easing: String) -> String:
	match easing:
		EASE_IN: return "Ease In"
		EASE_OUT: return "Ease Out"
		EASE_IN_OUT: return "Ease In Out"
		_: return "Linear"


static func jump_arc_label(arc: String) -> String:
	match arc:
		JUMP_ARC_FLOATY: return "Floaty"
		JUMP_ARC_SNAPPY: return "Snappy"
		_: return "Smooth"


static func _jump_arc_power(arc: String) -> float:
	match arc:
		JUMP_ARC_FLOATY: return 0.65
		JUMP_ARC_SNAPPY: return 1.6
		_: return 1.0


static func _vector(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
