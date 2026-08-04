class_name WeightingWorkspace
extends Control

var mesh_bake: Dictionary = {}
var weighting_result: Dictionary = {}
var status := "Missing Component Mesh"


func set_context(mesh_data: Dictionary, result_data: Dictionary, status_value: String) -> void:
	mesh_bake = mesh_data.duplicate(true)
	weighting_result = result_data.duplicate(true)
	status = status_value
	queue_redraw()


func clear_context() -> void:
	mesh_bake = {}
	weighting_result = {}
	status = "Select a Component"
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#171a20"))
	_draw_grid()
	if mesh_bake.is_empty():
		_draw_message(status)
		return
	var vertices_by_id: Dictionary = {}
	var bounds := Rect2()
	var first := true
	for vertex in mesh_bake.get("vertices", []):
		var position := Vector2(vertex.get("position", Vector2.ZERO))
		vertices_by_id[str(vertex.get("id", ""))] = position
		if first:
			bounds = Rect2(position, Vector2.ZERO)
			first = false
		else:
			bounds = bounds.expand(position)
	if first:
		_draw_message("Component Mesh has no Vertices")
		return
	var weights_by_id: Dictionary = {}
	for entry in weighting_result.get("weights", []):
		weights_by_id[str(entry.get("vertex_id", ""))] = float(entry.get("weight", 0.0))
	var padding := 54.0
	var extent := Vector2(maxf(bounds.size.x, 0.001), maxf(bounds.size.y, 0.001))
	var scale := minf((size.x - padding * 2.0) / extent.x, (size.y - padding * 2.0) / extent.y)
	var center := bounds.position + bounds.size * 0.5
	var screen_center := size * 0.5
	for triangle in mesh_bake.get("triangles", []):
		var ids: Array = triangle.get("vertex_ids", [])
		if ids.size() != 3:
			continue
		var polygon := PackedVector2Array()
		var colors := PackedColorArray()
		for id_value in ids:
			var vertex_id := str(id_value)
			if not vertices_by_id.has(vertex_id):
				continue
			var local := Vector2(vertices_by_id[vertex_id])
			polygon.append(screen_center + Vector2(local.x - center.x, -(local.y - center.y)) * scale)
			colors.append(_weight_color(float(weights_by_id.get(vertex_id, 0.0))))
		if polygon.size() == 3:
			draw_polygon(polygon, colors)
			draw_polyline(PackedVector2Array([polygon[0], polygon[1], polygon[2], polygon[0]]), Color("#333a46"), 1.0)
	_draw_legend()
	var label := "%s · %d Vertices" % [status, int(mesh_bake.get("vertex_count", 0))]
	draw_string(ThemeDB.fallback_font, Vector2(16, 24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#cbd2dc"))


func _draw_grid() -> void:
	for x in range(0, int(size.x) + 1, 40):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color("#20252d"))
	for y in range(0, int(size.y) + 1, 40):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("#20252d"))


func _draw_message(message: String) -> void:
	var text_size := ThemeDB.fallback_font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(ThemeDB.fallback_font, size * 0.5 - text_size * 0.5, message, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#8e99a9"))


func _draw_legend() -> void:
	var origin := Vector2(size.x - 150.0, size.y - 34.0)
	for index in range(101):
		var t := float(index) / 100.0
		draw_rect(Rect2(origin + Vector2(t * 120.0, 0), Vector2(2.0, 10.0)), _weight_color(t))
	draw_string(ThemeDB.fallback_font, origin + Vector2(0, 24), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#a8b1bf"))
	draw_string(ThemeDB.fallback_font, origin + Vector2(112, 24), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#a8b1bf"))


func _weight_color(weight: float) -> Color:
	var t := clampf(weight, 0.0, 1.0)
	if t < 0.5:
		return Color("#234c9f").lerp(Color("#8b5cf6"), t * 2.0)
	return Color("#8b5cf6").lerp(Color("#fff3a3"), (t - 0.5) * 2.0)
