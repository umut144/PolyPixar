class_name PrimitiveGeometryService
extends RefCounted

const CIRCLE_RENDER_SEGMENTS := 64
const CIRCLE_MESH_SEGMENTS := 48
const CIRCLE := "circle"
const ELLIPSE := "ellipse"
const RECTANGLE := "rectangle"
const TRIANGLE := "triangle"
## The shapes Create Primitive offers, in the order its number keys pick them.
## An Ellipse is not among them: it is what an anisotropic Scale Rebase turns a
## Circle into, never something that is drawn.
const CREATABLE_SHAPES: Array[String] = [CIRCLE, RECTANGLE, TRIANGLE]

static func is_primitive(component: Dictionary) -> bool:
	return WorldDocumentService.is_primitive(component)

static func has_circle(component: Dictionary) -> bool:
	return is_primitive(component) and component.get("primitive", {}) is Dictionary and str(component.get("primitive", {}).get("type", "")) == CIRCLE

static func has_ellipse(component: Dictionary) -> bool:
	return is_primitive(component) and component.get("primitive", {}) is Dictionary and str(component.get("primitive", {}).get("type", "")) == ELLIPSE

static func has_rectangle(component: Dictionary) -> bool:
	return is_primitive(component) and component.get("primitive", {}) is Dictionary and str(component.get("primitive", {}).get("type", "")) == RECTANGLE

static func has_triangle(component: Dictionary) -> bool:
	return is_primitive(component) and component.get("primitive", {}) is Dictionary and str(component.get("primitive", {}).get("type", "")) == TRIANGLE

static func has_analytic_shape(component: Dictionary) -> bool:
	return has_circle(component) or has_ellipse(component) or has_rectangle(component) or has_triangle(component)

## The shape a Component carries, or "" when it carries none. Every branch that
## used to ask three has_* questions in a row asks this instead.
static func shape_type(component: Dictionary) -> String:
	if not has_analytic_shape(component):
		return ""
	return str(component.get("primitive", {}).get("type", ""))

## A Rectangle and a Triangle are polygons with exact corners; a Circle and an
## Ellipse are curves that only ever get sampled. Everything that must treat the
## two families differently - the contour, adaptive Sampling - asks here rather
## than naming the types again.
static func has_straight_edges(component: Dictionary) -> bool:
	return has_rectangle(component) or has_triangle(component)

static func display_name(shape: String) -> String:
	if shape == CIRCLE:
		return "Circle"
	if shape == ELLIPSE:
		return "Ellipse"
	if shape == RECTANGLE:
		return "Rectangle"
	if shape == TRIANGLE:
		return "Triangle"
	return ""

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
	if has_rectangle(component):
		return Vector2(
			maxf(ToolUnits.from_centimeters(float(component.get("primitive", {}).get("width_cm", 1.0))), 0.0001),
			maxf(ToolUnits.from_centimeters(float(component.get("primitive", {}).get("length_cm", 1.0))), 0.0001))
	if has_triangle(component):
		return Vector2(
			maxf(ToolUnits.from_centimeters(float(component.get("primitive", {}).get("width_cm", 1.0))), 0.0001),
			maxf(ToolUnits.from_centimeters(float(component.get("primitive", {}).get("height_cm", 1.0))), 0.0001))
	return Vector2.ZERO

## The authored size of a shape in centimetres, as one bounding box, whatever
## pair of fields the shape happens to store it in. Scale Rebase and the
## placement preview both need the size without caring which shape it belongs
## to; `build` turns such a pair back into a typed record.
static func extents_cm(component: Dictionary) -> Vector2:
	var primitive: Dictionary = component.get("primitive", {}) if component.get("primitive", {}) is Dictionary else {}
	if has_circle(component):
		var diameter := float(primitive.get("diameter_cm", 0.0))
		return Vector2(diameter, diameter)
	if has_ellipse(component):
		return Vector2(float(primitive.get("diameter_x_cm", 0.0)), float(primitive.get("diameter_y_cm", 0.0)))
	if has_rectangle(component):
		return Vector2(float(primitive.get("width_cm", 0.0)), float(primitive.get("length_cm", 0.0)))
	if has_triangle(component):
		return Vector2(float(primitive.get("width_cm", 0.0)), float(primitive.get("height_cm", 0.0)))
	return Vector2.ZERO

## One typed primitive record from a shape, a centre and a bounding box in
## centimetres. Placement, Scale Rebase and the tests all build their records
## here, so a new shape adds its field names once.
static func build(shape: String, shape_center: Vector2, size_cm: Vector2) -> Dictionary:
	var width := maxf(size_cm.x, 0.001)
	var height := maxf(size_cm.y, 0.001)
	if shape == CIRCLE:
		return {"type": CIRCLE, "center": shape_center, "diameter_cm": width}
	if shape == ELLIPSE:
		return {"type": ELLIPSE, "center": shape_center, "diameter_x_cm": width, "diameter_y_cm": height}
	if shape == RECTANGLE:
		return {"type": RECTANGLE, "center": shape_center, "width_cm": width, "length_cm": height}
	if shape == TRIANGLE:
		return {"type": TRIANGLE, "center": shape_center, "width_cm": width, "height_cm": height}
	return {}

## The exact corners of a straight-edged shape, counter-clockwise, or an empty
## array for a curve. A Triangle is isosceles: its apex sits centred above the
## base, so the same width and height a Rectangle uses describe it too.
static func corners(component: Dictionary) -> Array[Vector2]:
	if not has_straight_edges(component):
		return []
	var origin := center(component)
	var half_extents := diameters_tool_units(component) * 0.5
	if has_triangle(component):
		return [
			origin + Vector2(-half_extents.x, -half_extents.y),
			origin + Vector2(half_extents.x, -half_extents.y),
			origin + Vector2(0.0, half_extents.y),
		]
	return [
		origin + Vector2(-half_extents.x, -half_extents.y),
		origin + Vector2(half_extents.x, -half_extents.y),
		origin + Vector2(half_extents.x, half_extents.y),
		origin + Vector2(-half_extents.x, half_extents.y),
	]

static func contour(component: Dictionary, segments := CIRCLE_RENDER_SEGMENTS) -> Array[Vector2]:
	if not has_analytic_shape(component):
		return []
	var straight_corners := corners(component)
	if not straight_corners.is_empty():
		return straight_corners
	var origin := center(component)
	var half_extents := diameters_tool_units(component) * 0.5
	var result: Array[Vector2] = []
	for index in range(maxi(segments, 12)):
		var angle := TAU * float(index) / float(maxi(segments, 12))
		result.append(origin + Vector2(cos(angle) * half_extents.x, sin(angle) * half_extents.y))
	return result

static func validation_issues(component: Dictionary) -> Array[String]:
	if not is_primitive(component):
		return []
	if not has_analytic_shape(component):
		return ["Primitive Component needs a Circle, Ellipse, Rectangle, or Triangle."]
	var authored_extents := extents_cm(component)
	if not authored_extents.is_finite() or authored_extents.x <= 0.0 or authored_extents.y <= 0.0:
		return ["Primitive diameters must be finite and positive."]
	return []
