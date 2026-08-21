class_name PrimitiveGeometryService
extends RefCounted

const CIRCLE_RENDER_SEGMENTS := 64
const CIRCLE_MESH_SEGMENTS := 48
const ELLIPSE := "ellipse"

static func is_primitive(component: Dictionary) -> bool:
	return str(component.get("draw_mode", "")) == "primitive"

static func has_circle(component: Dictionary) -> bool:
	return is_primitive(component) and component.get("primitive", {}) is Dictionary and str(component.get("primitive", {}).get("type", "")) == "circle"

static func has_ellipse(component: Dictionary) -> bool:
	return is_primitive(component) and component.get("primitive", {}) is Dictionary and str(component.get("primitive", {}).get("type", "")) == ELLIPSE

static func has_analytic_shape(component: Dictionary) -> bool:
	return has_circle(component) or has_ellipse(component)

static func center(component: Dictionary) -> Vector2:
	var primitive = component.get("primitive", {})
	if primitive is Dictionary:
		var raw_center = primitive.get("center", Vector2.ZERO)
		if raw_center is Vector2:
			return raw_center
		if raw_center is Array and raw_center.size() >= 2:
			return Vector2(float(raw_center[0]), float(raw_center[1]))
	return Vector2.ZERO

static func diameter_tool_units(component: Dictionary) -> float:
	return maxf(ToolUnits.from_centimeters(float(component.get("primitive", {}).get("diameter_cm", 1.0))), 0.0001)

static func diameters_tool_units(component: Dictionary) -> Vector2:
	if has_circle(component):
		var diameter := diameter_tool_units(component)
		return Vector2(diameter, diameter)
	if has_ellipse(component):
		return Vector2(
			maxf(ToolUnits.from_centimeters(float(component.get("primitive", {}).get("diameter_x_cm", 1.0))), 0.0001),
			maxf(ToolUnits.from_centimeters(float(component.get("primitive", {}).get("diameter_y_cm", 1.0))), 0.0001))
	return Vector2.ZERO

static func contour(component: Dictionary, segments := CIRCLE_RENDER_SEGMENTS) -> Array[Vector2]:
	if not has_analytic_shape(component):
		return []
	var result: Array[Vector2] = []
	var radii := diameters_tool_units(component) * 0.5
	var origin := center(component)
	for index in range(maxi(segments, 12)):
		var angle := TAU * float(index) / float(maxi(segments, 12))
		result.append(origin + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return result

static func validation_issues(component: Dictionary) -> Array[String]:
	if not is_primitive(component):
		return []
	if not has_analytic_shape(component):
		return ["Primitive Component needs a Circle or Ellipse."]
	var primitive: Dictionary = component.get("primitive", {})
	var diameters_cm := Vector2(float(primitive.get("diameter_cm", 0.0)), float(primitive.get("diameter_cm", 0.0))) if has_circle(component) else Vector2(float(primitive.get("diameter_x_cm", 0.0)), float(primitive.get("diameter_y_cm", 0.0)))
	if not diameters_cm.is_finite() or diameters_cm.x <= 0.0 or diameters_cm.y <= 0.0:
		return ["Primitive diameters must be finite and positive."]
	return []
