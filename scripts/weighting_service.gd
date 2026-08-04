class_name WeightingService
extends RefCounted

const UNIFORM := "uniform"
const AXIS_GRADIENT := "axis_gradient"
const VALID_METHODS := [UNIFORM, AXIS_GRADIENT]

const BOTTOM_TO_TOP := "bottom_to_top"
const TOP_TO_BOTTOM := "top_to_bottom"
const LEFT_TO_RIGHT := "left_to_right"
const RIGHT_TO_LEFT := "right_to_left"
const VALID_DIRECTIONS := [BOTTOM_TO_TOP, TOP_TO_BOTTOM, LEFT_TO_RIGHT, RIGHT_TO_LEFT]

const LINEAR := "linear"
const EASE_IN := "ease_in"
const EASE_OUT := "ease_out"
const SMOOTH := "smooth"
const VALID_CURVES := [LINEAR, EASE_IN, EASE_OUT, SMOOTH]


static func default_style(style_id: String, style_name: String, component_id: String) -> Dictionary:
	return {
		"id": style_id,
		"name": style_name,
		"component_id": component_id,
		"method": UNIFORM,
		"parameters": default_parameters(UNIFORM),
		"bake": {}
	}


static func default_parameters(method: String) -> Dictionary:
	if method == AXIS_GRADIENT:
		return {"direction": BOTTOM_TO_TOP, "curve": LINEAR, "strength": 1.0, "invert": false}
	return {"strength": 1.0}


static func normalize_style(raw_style) -> Dictionary:
	var source: Dictionary = raw_style if raw_style is Dictionary else {}
	var method := str(source.get("method", UNIFORM))
	if method not in VALID_METHODS:
		method = UNIFORM
	var parameters := default_parameters(method)
	var raw_parameters = source.get("parameters", {})
	if raw_parameters is Dictionary:
		parameters["strength"] = clampf(float(raw_parameters.get("strength", 1.0)), 0.0, 1.0)
		if method == AXIS_GRADIENT:
			var direction := str(raw_parameters.get("direction", BOTTOM_TO_TOP))
			var curve := str(raw_parameters.get("curve", LINEAR))
			parameters["direction"] = direction if direction in VALID_DIRECTIONS else BOTTOM_TO_TOP
			parameters["curve"] = curve if curve in VALID_CURVES else LINEAR
			parameters["invert"] = bool(raw_parameters.get("invert", false))
	return {
		"id": str(source.get("id", "")),
		"name": str(source.get("name", "Weighting Style")),
		"component_id": str(source.get("component_id", "")),
		"method": method,
		"parameters": parameters,
		"bake": normalize_bake(source.get("bake", {}))
	}


static func normalize_bake(raw_bake) -> Dictionary:
	if not raw_bake is Dictionary or not bool(raw_bake.get("valid", false)):
		return {}
	var bake: Dictionary = raw_bake.duplicate(true)
	var weights: Array = []
	for entry in raw_bake.get("weights", []):
		if entry is Dictionary:
			weights.append({"vertex_id": str(entry.get("vertex_id", "")), "weight": clampf(float(entry.get("weight", 0.0)), 0.0, 1.0)})
	bake["weights"] = weights
	bake["weight_count"] = weights.size()
	return bake


static func generate(mesh_bake: Dictionary, raw_style) -> Dictionary:
	var style := normalize_style(raw_style)
	var errors: Array[String] = []
	if mesh_bake.is_empty() or not bool(mesh_bake.get("valid", false)):
		errors.append("Weighting requires a current Component Mesh.")
	if mesh_bake.get("vertices", []).is_empty():
		errors.append("The Component Mesh has no Vertices.")
	if not errors.is_empty():
		return _failed_result(mesh_bake, style, errors)
	var vertices: Array = mesh_bake.get("vertices", [])
	var min_position := Vector2(INF, INF)
	var max_position := Vector2(-INF, -INF)
	for vertex in vertices:
		var position := Vector2(vertex.get("position", Vector2.ZERO))
		min_position = min_position.min(position)
		max_position = max_position.max(position)
	var parameters: Dictionary = style.get("parameters", {})
	var strength := float(parameters.get("strength", 1.0))
	var weights: Array = []
	var minimum_weight := INF
	var maximum_weight := -INF
	for vertex in vertices:
		var weight := strength
		if str(style.get("method", UNIFORM)) == AXIS_GRADIENT:
			var position := Vector2(vertex.get("position", Vector2.ZERO))
			var direction := str(parameters.get("direction", BOTTOM_TO_TOP))
			var t := 0.0
			if direction in [BOTTOM_TO_TOP, TOP_TO_BOTTOM]:
				t = inverse_lerp(min_position.y, max_position.y, position.y) if not is_equal_approx(min_position.y, max_position.y) else 1.0
				if direction == TOP_TO_BOTTOM:
					t = 1.0 - t
			else:
				t = inverse_lerp(min_position.x, max_position.x, position.x) if not is_equal_approx(min_position.x, max_position.x) else 1.0
				if direction == RIGHT_TO_LEFT:
					t = 1.0 - t
			t = _curve_value(clampf(t, 0.0, 1.0), str(parameters.get("curve", LINEAR)))
			if bool(parameters.get("invert", false)):
				t = 1.0 - t
			weight = clampf(t * strength, 0.0, 1.0)
		weights.append({"vertex_id": str(vertex.get("id", "")), "weight": weight})
		minimum_weight = minf(minimum_weight, weight)
		maximum_weight = maxf(maximum_weight, weight)
	return {
		"valid": true,
		"errors": [],
		"style_id": str(style.get("id", "")),
		"method": str(style.get("method", UNIFORM)),
		"parameters": parameters.duplicate(true),
		"mesh_bake_id": str(mesh_bake.get("bake_id", "")),
		"mesh_method": str(mesh_bake.get("method", "")),
		"mesh_fingerprint": GeometryUVMappingService.mesh_fingerprint(mesh_bake),
		"weights": weights,
		"weight_count": weights.size(),
		"minimum_weight": minimum_weight if not weights.is_empty() else 0.0,
		"maximum_weight": maximum_weight if not weights.is_empty() else 0.0
	}


static func result_matches(result: Dictionary, mesh_bake: Dictionary, raw_style) -> bool:
	if result.is_empty() or not bool(result.get("valid", false)) or mesh_bake.is_empty():
		return false
	var style := normalize_style(raw_style)
	return str(result.get("style_id", "")) == str(style.get("id", "")) \
		and str(result.get("method", "")) == str(style.get("method", "")) \
		and result.get("parameters", {}) == style.get("parameters", {}) \
		and str(result.get("mesh_bake_id", "")) == str(mesh_bake.get("bake_id", "")) \
		and str(result.get("mesh_fingerprint", "")) == GeometryUVMappingService.mesh_fingerprint(mesh_bake)


static func _curve_value(t: float, curve: String) -> float:
	if curve == EASE_IN:
		return t * t
	if curve == EASE_OUT:
		return 1.0 - (1.0 - t) * (1.0 - t)
	if curve == SMOOTH:
		return t * t * (3.0 - 2.0 * t)
	return t


static func _failed_result(mesh_bake: Dictionary, style: Dictionary, errors: Array[String]) -> Dictionary:
	return {
		"valid": false,
		"errors": errors,
		"style_id": str(style.get("id", "")),
		"method": str(style.get("method", UNIFORM)),
		"parameters": style.get("parameters", {}).duplicate(true),
		"mesh_bake_id": str(mesh_bake.get("bake_id", "")),
		"mesh_method": str(mesh_bake.get("method", "")),
		"mesh_fingerprint": GeometryUVMappingService.mesh_fingerprint(mesh_bake),
		"weights": [],
		"weight_count": 0,
		"minimum_weight": 0.0,
		"maximum_weight": 0.0
	}
