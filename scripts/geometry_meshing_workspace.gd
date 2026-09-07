class_name GeometryMeshingWorkspace
extends Control

## A Component Mesh is inspected at the scale it was authored at, and these are
## centimetres: a Stone chip measures a few tool units across, so the previous
## ceiling of 128 pixels per unit left it under a hundred pixels wide at full
## zoom - too small to judge a triangle by. The floor is unchanged; only getting
## closer was ever the problem.
const MIN_CAMERA_ZOOM := 0.05
const MAX_CAMERA_ZOOM := 1280.0
const CAMERA_ZOOM_STEP := 1.12

const BACKGROUND := Color("#1b1e24")
const GRID_MINOR := Color("#252a33")
const GRID_MAJOR := Color("#303744")
const BOUNDARY_COLOR := Color("#7b8492")
const HOLE_COLOR := Color("#ef6c78")
const CUT_COLOR := Color("#ff7f8d")
const MESH_COLOR := Color("#63b3ed")
const BASELINE_MESH_COLOR := Color("#f2c94c", 0.28)
const MOVEMENT_COLOR := Color("#f6ad55", 0.9)
const OPTIMIZED_POINT_COLOR := Color("#63d5da")
const FLOW_SEED_COLOR := Color("#f2c94c")
const GAP_SEED_COLOR := Color("#68d391")
const FILL_COLOR := Color(0.2, 0.55, 0.75, 0.08)

var sampling_bake: Dictionary = {}
var seeding_bake: Dictionary = {}
var mesh_result: Dictionary = {}
var status := "Seeding Required"
var camera_position := Vector2.ZERO
var camera_zoom := 1.0
var fitted := false
var show_mesh_edges := true
var show_seed_points := false
var show_triangle_fill := false
var show_constraints := true
var show_optimization := false
var show_quality := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_unhandled_key_input(true)
	queue_redraw()


func set_context(sampling_data: Dictionary, seeding_data: Dictionary, mesh_data: Dictionary, status_value: String) -> void:
	var geometry_changed := sampling_bake != sampling_data or mesh_result != mesh_data
	sampling_bake = sampling_data.duplicate(true)
	seeding_bake = seeding_data.duplicate(true)
	mesh_result = mesh_data.duplicate(true)
	status = status_value
	if geometry_changed:
		fitted = false
	queue_redraw()


func clear_context() -> void:
	sampling_bake = {}
	seeding_bake = {}
	mesh_result = {}
	status = "Seeding Required"
	fitted = false
	queue_redraw()


func set_view_option(option: String, enabled: bool) -> void:
	match option:
		"mesh_edges": show_mesh_edges = enabled
		"seed_points": show_seed_points = enabled
		"triangle_fill": show_triangle_fill = enabled
		"constraints": show_constraints = enabled
		"optimization": show_optimization = enabled
		"quality": show_quality = enabled
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		grab_focus()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(CAMERA_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / CAMERA_ZOOM_STEP)


func _unhandled_key_input(event: InputEvent) -> void:
	if not has_focus() or not event is InputEventKey or not event.pressed or event.echo or event.meta_pressed or event.ctrl_pressed:
		return
	var pan_step := 24.0 / maxf(camera_zoom, 0.0001)
	match event.keycode:
		KEY_A: camera_position.x -= pan_step
		KEY_D: camera_position.x += pan_step
		KEY_W: camera_position.y += pan_step
		KEY_S: camera_position.y -= pan_step
		KEY_Q: _zoom_by(1.0 / CAMERA_ZOOM_STEP)
		KEY_E: _zoom_by(CAMERA_ZOOM_STEP)
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
	if show_optimization:
		_draw_optimization()
	if show_constraints:
		_draw_boundaries()
	if show_seed_points:
		_draw_seeds()
	draw_string(ThemeDB.fallback_font, Vector2(10.0, 20.0), "Mesh → Meshing · %s" % status, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#9aa3b2"))
	_draw_view_legend()


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
	for sample_position in positions:
		bounds = bounds.expand(sample_position)
	camera_position = bounds.get_center()
	var available := Vector2(maxf(size.x - 96.0, 1.0), maxf(size.y - 96.0, 1.0))
	var extent := Vector2(maxf(bounds.size.x, 1.0), maxf(bounds.size.y, 1.0))
	camera_zoom = clampf(minf(available.x / extent.x, available.y / extent.y), MIN_CAMERA_ZOOM, MAX_CAMERA_ZOOM)
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
		if show_quality:
			draw_colored_polygon(polygon, _triangle_quality_color(polygon))
		elif show_triangle_fill:
			draw_colored_polygon(polygon, FILL_COLOR)
		if show_mesh_edges:
			for edge_index in range(3):
				draw_line(polygon[edge_index], polygon[(edge_index + 1) % 3], MESH_COLOR, 1.0, true)


func _draw_optimization() -> void:
	var optimization: Dictionary = mesh_result.get("optimization", {})
	if optimization.is_empty():
		return
	var final_positions: Dictionary = {}
	for vertex in mesh_result.get("vertices", []):
		if vertex is Dictionary:
			final_positions[str(vertex.get("id", ""))] = Vector2(vertex.get("position", Vector2.ZERO))
	var baseline_positions := final_positions.duplicate()
	for movement in optimization.get("movements", []):
		if movement is Dictionary:
			baseline_positions[str(movement.get("vertex_id", ""))] = _stored_position(movement.get("from", Vector2.ZERO))
	for triangle in optimization.get("baseline_triangles", []):
		var ids: Array = triangle.get("vertex_ids", [])
		if ids.size() != 3 or not baseline_positions.has(str(ids[0])) or not baseline_positions.has(str(ids[1])) or not baseline_positions.has(str(ids[2])):
			continue
		var polygon := PackedVector2Array([
			_to_screen(baseline_positions[str(ids[0])]),
			_to_screen(baseline_positions[str(ids[1])]),
			_to_screen(baseline_positions[str(ids[2])])
		])
		for edge_index in range(3):
			draw_line(polygon[edge_index], polygon[(edge_index + 1) % 3], BASELINE_MESH_COLOR, 1.0, true)
	for movement in optimization.get("movements", []):
		if not movement is Dictionary:
			continue
		var from_screen := _to_screen(_stored_position(movement.get("from", Vector2.ZERO)))
		var to_screen := _to_screen(_stored_position(movement.get("to", Vector2.ZERO)))
		draw_line(from_screen, to_screen, MOVEMENT_COLOR, 1.5, true)
		draw_circle(from_screen, 2.4, BASELINE_MESH_COLOR)
		draw_circle(to_screen, 2.4, OPTIMIZED_POINT_COLOR)


func _triangle_quality_color(polygon: PackedVector2Array) -> Color:
	var a := polygon[0]
	var b := polygon[1]
	var c := polygon[2]
	var twice_area := absf((b - a).cross(c - a))
	var edge_sum := a.distance_squared_to(b) + b.distance_squared_to(c) + c.distance_squared_to(a)
	var quality := clampf(2.0 * sqrt(3.0) * twice_area / edge_sum, 0.0, 1.0) if edge_sum > 0.000001 else 0.0
	var poor := Color("#ef6c78", 0.48)
	var medium := Color("#f2c94c", 0.38)
	var strong := Color("#68d391", 0.30)
	return poor.lerp(medium, quality * 2.0) if quality < 0.5 else medium.lerp(strong, (quality - 0.5) * 2.0)


func _draw_view_legend() -> void:
	var y := 38.0
	if show_optimization:
		var optimization: Dictionary = mesh_result.get("optimization", {})
		var label := "Optimization · OFF" if not bool(optimization.get("enabled", false)) else "Optimization · %d Seeds moved · %d/%d passes" % [int(optimization.get("moved_seed_count", 0)), int(optimization.get("accepted_passes", 0)), int(optimization.get("attempted_passes", 0))]
		draw_string(ThemeDB.fallback_font, Vector2(10.0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#d5dae3"))
		y += 18.0
	if show_quality:
		draw_string(ThemeDB.fallback_font, Vector2(10.0, y), "Quality · red = poor · yellow = fair · green = strong", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#d5dae3"))


func _stored_position(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _draw_boundaries() -> void:
	for chain_data in sampling_bake.get("chains", []):
		var samples: Array = chain_data.get("samples", [])
		var color := HOLE_COLOR if WorldDocumentService.topology_role(chain_data) == WorldDocumentService.ROLE_HOLE else BOUNDARY_COLOR
		for sample_index in range(samples.size()):
			if sample_index == samples.size() - 1 and not bool(chain_data.get("closed", false)):
				continue
			var next_index := (sample_index + 1) % samples.size()
			draw_line(_to_screen(Vector2(samples[sample_index].get("position", Vector2.ZERO))), _to_screen(Vector2(samples[next_index].get("position", Vector2.ZERO))), color, 2.0, true)
	for cut_data in sampling_bake.get("cuts", []):
		for fragment in GeometrySamplingService.cut_fragments(cut_data):
			var samples: Array = fragment.get("samples", [])
			for sample_index in range(samples.size() - 1):
				draw_dashed_line(_to_screen(Vector2(samples[sample_index].get("position", Vector2.ZERO))), _to_screen(Vector2(samples[sample_index + 1].get("position", Vector2.ZERO))), CUT_COLOR, 6.0, 2.0, true)


func _draw_seeds() -> void:
	for seed_data in seeding_bake.get("seeds", []):
		if seed_data is Dictionary:
			var placement := str(seed_data.get("provenance", {}).get("placement", ""))
			var color := FLOW_SEED_COLOR if placement == "flow" else GAP_SEED_COLOR
			draw_circle(_to_screen(Vector2(seed_data.get("position", Vector2.ZERO))), 2.4, color)


func _to_screen(local_position: Vector2) -> Vector2:
	var relative := local_position - camera_position
	return Vector2(size.x * 0.5 + relative.x * camera_zoom, size.y * 0.5 - relative.y * camera_zoom)


func _draw_centered_message(message: String) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(0.0, size.y * 0.5), message, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color("#737f91"))


## One place decides how far the camera may come in, so the wheel, the keyboard
## and the initial fit cannot drift apart.
func _zoom_by(factor: float) -> void:
	camera_zoom = clampf(camera_zoom * factor, MIN_CAMERA_ZOOM, MAX_CAMERA_ZOOM)
	fitted = true
	queue_redraw()
