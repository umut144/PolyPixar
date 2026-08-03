class_name GeometryUVMappingWorkspace
extends Control

const BACKGROUND := Color("#1b1e24")
const PANEL_BACKGROUND := Color("#1e232b")
const GRID_MINOR := Color("#2a303a")
const GRID_MAJOR := Color("#3a4350")
const MESH_COLOR := Color("#63b3ed")
const UV_COLOR := Color("#f2c94c")
const VERTEX_COLOR := Color("#68d391")
const SEPARATOR_COLOR := Color("#11151a")

var mesh_bake: Dictionary = {}
var uv_result: Dictionary = {}
var status := "Mesh Required"


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func set_context(mesh_data: Dictionary, uv_data: Dictionary, status_value: String) -> void:
	mesh_bake = mesh_data.duplicate(true)
	uv_result = uv_data.duplicate(true)
	status = status_value
	queue_redraw()


func clear_context() -> void:
	mesh_bake = {}
	uv_result = {}
	status = "Mesh Required"
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		grab_focus()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	var gap := 12.0
	var margin := 28.0
	var panel_width := maxf((size.x - margin * 2.0 - gap) * 0.5, 1.0)
	var left_rect := Rect2(Vector2(margin, 42.0), Vector2(panel_width, maxf(size.y - 70.0, 1.0)))
	var right_rect := Rect2(Vector2(margin + panel_width + gap, 42.0), left_rect.size)
	draw_rect(left_rect, PANEL_BACKGROUND)
	draw_rect(right_rect, PANEL_BACKGROUND)
	draw_line(Vector2(size.x * 0.5, 32.0), Vector2(size.x * 0.5, size.y - 16.0), SEPARATOR_COLOR, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(left_rect.position.x, 28.0), "Source Mesh", HORIZONTAL_ALIGNMENT_LEFT, left_rect.size.x, 12, Color("#9aa3b2"))
	draw_string(ThemeDB.fallback_font, Vector2(right_rect.position.x, 28.0), "UV Space", HORIZONTAL_ALIGNMENT_LEFT, right_rect.size.x, 12, Color("#9aa3b2"))
	if mesh_bake.is_empty():
		_draw_message(left_rect, "Bake a Mesh before UV Mapping")
		_draw_message(right_rect, "No UV result")
		return
	_draw_source_mesh(left_rect)
	_draw_uv_space(right_rect)
	draw_string(ThemeDB.fallback_font, Vector2(10.0, size.y - 10.0), "Geometry → UV Mapping · %s" % status, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#9aa3b2"))


func _draw_source_mesh(rect: Rect2) -> void:
	var positions: Dictionary = {}
	var world_positions: Array[Vector2] = []
	for vertex in mesh_bake.get("vertices", []):
		if vertex is Dictionary:
			world_positions.append(Vector2(vertex.get("position", Vector2.ZERO)))
	if world_positions.is_empty():
		return
	var bounds := Rect2(world_positions[0], Vector2.ZERO)
	for position in world_positions:
		bounds = bounds.expand(position)
	var available := rect.size - Vector2(40.0, 40.0)
	var extent := Vector2(maxf(bounds.size.x, 1.0), maxf(bounds.size.y, 1.0))
	var zoom := minf(available.x / extent.x, available.y / extent.y)
	for vertex in mesh_bake.get("vertices", []):
		var position := Vector2(vertex.get("position", Vector2.ZERO))
		positions[str(vertex.get("id", ""))] = rect.get_center() + Vector2((position.x - bounds.get_center().x) * zoom, -(position.y - bounds.get_center().y) * zoom)
	_draw_triangles(mesh_bake.get("triangles", []), positions, MESH_COLOR)
	for screen_position in positions.values():
		draw_circle(screen_position, 2.2, VERTEX_COLOR)


func _draw_uv_space(rect: Rect2) -> void:
	var square_size := minf(rect.size.x, rect.size.y) - 48.0
	var uv_rect := Rect2(rect.get_center() - Vector2(square_size, square_size) * 0.5, Vector2(square_size, square_size))
	for row in range(8):
		for column in range(8):
			var cell := Rect2(uv_rect.position + Vector2(column, row) * square_size / 8.0, Vector2.ONE * square_size / 8.0)
			draw_rect(cell, Color("#252b34") if (row + column) % 2 == 0 else Color("#20262e"))
	for grid_index in range(9):
		var position := float(grid_index) / 8.0
		var color := GRID_MAJOR if grid_index in [0, 4, 8] else GRID_MINOR
		draw_line(Vector2(uv_rect.position.x + position * square_size, uv_rect.position.y), Vector2(uv_rect.position.x + position * square_size, uv_rect.end.y), color, 1.0)
		draw_line(Vector2(uv_rect.position.x, uv_rect.position.y + position * square_size), Vector2(uv_rect.end.x, uv_rect.position.y + position * square_size), color, 1.0)
	if not bool(uv_result.get("valid", false)):
		return
	var positions: Dictionary = {}
	for entry in uv_result.get("uvs", []):
		if entry is Dictionary:
			var uv := Vector2(entry.get("uv", Vector2.ZERO))
			positions[str(entry.get("vertex_id", ""))] = Vector2(uv_rect.position.x + uv.x * square_size, uv_rect.end.y - uv.y * square_size)
	_draw_triangles(mesh_bake.get("triangles", []), positions, UV_COLOR)
	for screen_position in positions.values():
		draw_circle(screen_position, 2.2, UV_COLOR)


func _draw_triangles(triangles: Array, positions: Dictionary, color: Color) -> void:
	for triangle in triangles:
		var ids: Array = triangle.get("vertex_ids", [])
		if ids.size() != 3:
			continue
		for edge_index in range(3):
			var first := str(ids[edge_index])
			var second := str(ids[(edge_index + 1) % 3])
			if positions.has(first) and positions.has(second):
				draw_line(positions[first], positions[second], color, 1.0, true)


func _draw_message(rect: Rect2, message: String) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.get_center().y), message, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, Color("#737f91"))
