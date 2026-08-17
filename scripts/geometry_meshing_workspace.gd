class_name GeometryMeshingWorkspace
extends Control

const BACKGROUND := Color("#1b1e24")
const GRID_MINOR := Color("#252a33")
const GRID_MAJOR := Color("#303744")
const BOUNDARY_COLOR := Color("#7b8492")
const MESH_COLOR := Color("#63b3ed")
const SEED_COLOR := Color("#68d391")
const FILL_COLOR := Color(0.2, 0.55, 0.75, 0.08)

var sampling_bake: Dictionary = {}
var seeding_bake: Dictionary = {}
var mesh_result: Dictionary = {}
var status := "Seeding Required"
var camera_position := Vector2.ZERO
var camera_zoom := 1.0
var fitted := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_unhandled_key_input(true)
	queue_redraw()


func set_context(sampling_data: Dictionary, seeding_data: Dictionary, mesh_data: Dictionary, status_value: String) -> void:
	var boundary_changed := sampling_bake != sampling_data
	sampling_bake = sampling_data.duplicate(true)
	seeding_bake = seeding_data.duplicate(true)
	mesh_result = mesh_data.duplicate(true)
	status = status_value
	if boundary_changed:
		fitted = false
	queue_redraw()


func clear_context() -> void:
	sampling_bake = {}
	seeding_bake = {}
	mesh_result = {}
	status = "Seeding Required"
	fitted = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		grab_focus()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_zoom = clampf(camera_zoom * 1.12, 0.05, 128.0)
			fitted = true
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_zoom = clampf(camera_zoom / 1.12, 0.05, 128.0)
			fitted = true
			queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not has_focus() or not event is InputEventKey or not event.pressed or event.echo or event.meta_pressed or event.ctrl_pressed:
		return
	var pan_step := 24.0 / maxf(camera_zoom, 0.0001)
	match event.keycode:
		KEY_A: camera_position.x -= pan_step
		KEY_D: camera_position.x += pan_step
		KEY_W: camera_position.y += pan_step
		KEY_S: camera_position.y -= pan_step
		KEY_Q: camera_zoom = clampf(camera_zoom / 1.12, 0.05, 128.0)
		KEY_E: camera_zoom = clampf(camera_zoom * 1.12, 0.05, 128.0)
		_: return
	fitted = true
	queue_redraw()
	get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	_draw_grid()
	if sampling_bake.is_empty() and mesh_result.is_empty():
		_draw_centered_message("Bake Seeding before Meshing")
		return
	if not fitted:
		_fit_boundary()
	_draw_mesh()
	_draw_boundaries()
	_draw_seeds()
	draw_string(ThemeDB.fallback_font, Vector2(10.0, 20.0), "Mesh → Meshing · %s" % status, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#9aa3b2"))


func _draw_grid() -> void:
	var step := maxf(16.0, 32.0 * camera_zoom)
	var offset := Vector2(fposmod(size.x * 0.5 - camera_position.x * camera_zoom, step), fposmod(size.y * 0.5 + camera_position.y * camera_zoom, step))
	var x := offset.x
	var column := 0
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), GRID_MAJOR if column % 4 == 0 else GRID_MINOR, 1.0)
		x += step
		column += 1
	var y := offset.y
	var row := 0
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), GRID_MAJOR if row % 4 == 0 else GRID_MINOR, 1.0)
		y += step
		row += 1


func _fit_boundary() -> void:
	var positions: Array[Vector2] = []
	for chain_data in sampling_bake.get("chains", []):
		for sample in chain_data.get("samples", []):
			if sample is Dictionary:
				positions.append(Vector2(sample.get("position", Vector2.ZERO)))
	if positions.is_empty():
		for vertex in mesh_result.get("vertices", []):
			if vertex is Dictionary:
				positions.append(Vector2(vertex.get("position", Vector2.ZERO)))
	if positions.is_empty():
		camera_position = Vector2.ZERO
		camera_zoom = 1.0
		fitted = true
		return
	var bounds := Rect2(positions[0], Vector2.ZERO)
	for position in positions:
		bounds = bounds.expand(position)
	camera_position = bounds.get_center()
	var available := Vector2(maxf(size.x - 96.0, 1.0), maxf(size.y - 96.0, 1.0))
	var extent := Vector2(maxf(bounds.size.x, 1.0), maxf(bounds.size.y, 1.0))
	camera_zoom = clampf(minf(available.x / extent.x, available.y / extent.y), 0.05, 128.0)
	fitted = true


func _draw_mesh() -> void:
	if not bool(mesh_result.get("valid", false)):
		return
	var positions: Dictionary = {}
	for vertex in mesh_result.get("vertices", []):
		if vertex is Dictionary:
			positions[str(vertex.get("id", ""))] = _to_screen(Vector2(vertex.get("position", Vector2.ZERO)))
	for triangle in mesh_result.get("triangles", []):
		var ids: Array = triangle.get("vertex_ids", [])
		if ids.size() != 3 or not positions.has(str(ids[0])) or not positions.has(str(ids[1])) or not positions.has(str(ids[2])):
			continue
		var polygon := PackedVector2Array([positions[str(ids[0])], positions[str(ids[1])], positions[str(ids[2])]])
		draw_colored_polygon(polygon, FILL_COLOR)
		for edge_index in range(3):
			draw_line(polygon[edge_index], polygon[(edge_index + 1) % 3], MESH_COLOR, 1.0, true)


func _draw_boundaries() -> void:
	for chain_data in sampling_bake.get("chains", []):
		var samples: Array = chain_data.get("samples", [])
		for sample_index in range(samples.size()):
			if sample_index == samples.size() - 1 and not bool(chain_data.get("closed", false)):
				continue
			var next_index := (sample_index + 1) % samples.size()
			draw_line(_to_screen(Vector2(samples[sample_index].get("position", Vector2.ZERO))), _to_screen(Vector2(samples[next_index].get("position", Vector2.ZERO))), BOUNDARY_COLOR, 2.0, true)


func _draw_seeds() -> void:
	for seed_data in seeding_bake.get("seeds", []):
		if seed_data is Dictionary:
			draw_circle(_to_screen(Vector2(seed_data.get("position", Vector2.ZERO))), 2.4, SEED_COLOR)


func _to_screen(local_position: Vector2) -> Vector2:
	var relative := local_position - camera_position
	return Vector2(size.x * 0.5 + relative.x * camera_zoom, size.y * 0.5 - relative.y * camera_zoom)


func _draw_centered_message(message: String) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(0.0, size.y * 0.5), message, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color("#737f91"))
