class_name GeometrySamplingWorkspace
extends Control

const BACKGROUND := Color("#1b1e24")
const GRID_MINOR := Color("#252a33")
const GRID_MAJOR := Color("#303744")
const CURVE_COLOR := Color("#7b8492")
const SAMPLE_LINE_COLOR := Color("#f2c94c")
const SAMPLE_POINT_COLOR := Color("#f6d96b")
const HOLE_LINE_COLOR := Color("#ef6c78")
const HOLE_POINT_COLOR := Color("#ff8993")
const PRESERVE_COLOR := Color("#ef8354")

var component: Dictionary = {}
var preview: Dictionary = {}
var overlays: Dictionary = {}
var status := "Not Generated"
var selected_input_id := ""
var camera_position := Vector2.ZERO
var camera_zoom := 1.0
var fitted := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_unhandled_key_input(true)
	queue_redraw()


func set_context(component_data: Dictionary, preview_data: Dictionary, bake_data: Dictionary, status_value: String, overlay_data: Dictionary = {}, selected_input := "") -> void:
	component = component_data.duplicate(true)
	preview = preview_data.duplicate(true) if not preview_data.is_empty() else bake_data.duplicate(true)
	overlays = overlay_data.duplicate(true)
	status = status_value
	selected_input_id = selected_input
	BezierGeometry.resolve_auto_handles(component.get("points", []), component.get("chains", []))
	fitted = false
	queue_redraw()


func clear_context() -> void:
	component = {}
	preview = {}
	overlays = {}
	status = "Not Generated"
	selected_input_id = ""
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
		KEY_A:
			camera_position.x -= pan_step
		KEY_D:
			camera_position.x += pan_step
		KEY_W:
			camera_position.y += pan_step
		KEY_S:
			camera_position.y -= pan_step
		KEY_Q:
			camera_zoom = clampf(camera_zoom / 1.12, 0.05, 128.0)
		KEY_E:
			camera_zoom = clampf(camera_zoom * 1.12, 0.05, 128.0)
		_:
			return
	fitted = true
	queue_redraw()
	get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	_draw_grid()
	if component.is_empty():
		_draw_centered_message("Select a Component to sample")
		return
	if not fitted:
		_fit_component()
	_draw_authored_curves()
	_draw_hole_overlays()
	_draw_guide_overlays()
	_draw_samples()
	draw_string(ThemeDB.fallback_font, Vector2(10.0, 20.0), "Mesh → Sampling · %s" % status, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#9aa3b2"))


func _draw_grid() -> void:
	var step := maxf(16.0, 32.0 * camera_zoom)
	var offset := Vector2(fposmod(size.x * 0.5 - camera_position.x * camera_zoom, step), fposmod(size.y * 0.5 + camera_position.y * camera_zoom, step))
	var column := 0
	var x := offset.x
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), GRID_MAJOR if column % 4 == 0 else GRID_MINOR, 1.0)
		x += step
		column += 1
	var row := 0
	var y := offset.y
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), GRID_MAJOR if row % 4 == 0 else GRID_MINOR, 1.0)
		y += step
		row += 1


func _fit_component() -> void:
	var positions: Array[Vector2] = []
	for point_data in component.get("points", []):
		if point_data is Dictionary:
			positions.append(Vector2(point_data.get("position", Vector2.ZERO)))
	for chain_data in preview.get("chains", []):
		for sample in chain_data.get("samples", []):
			positions.append(Vector2(sample.get("position", Vector2.ZERO)))
	for cut in preview.get("cuts", []):
		for fragment in GeometrySamplingService.cut_fragments(cut):
			for sample in fragment.get("samples", []):
				positions.append(Vector2(sample.get("position", Vector2.ZERO)))
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


func _draw_authored_curves() -> void:
	var points: Array = component.get("points", [])
	var edges: Array = component.get("edges", [])
	for chain_data in component.get("chains", []):
		if not chain_data is Dictionary:
			continue
		for edge_id_value in chain_data.get("edge_ids", []):
			var edge := BezierTopology.edge_by_id(edges, str(edge_id_value))
			var start_point := BezierTopology.point_by_id(points, str(edge.get("start_point_id", "")))
			var end_point := BezierTopology.point_by_id(points, str(edge.get("end_point_id", "")))
			if start_point.is_empty() or end_point.is_empty():
				continue
			var controls := BezierGeometry.cubic_controls(start_point, end_point)
			var previous := _to_screen(controls[0])
			for sample_index in range(1, 25):
				var current := _to_screen(BezierGeometry.cubic_position(controls, float(sample_index) / 24.0))
				draw_line(previous, current, CURVE_COLOR, 1.5, true)
				previous = current


func _draw_samples() -> void:
	if not bool(preview.get("valid", false)):
		return
	for chain_data in preview.get("chains", []):
		var samples: Array = chain_data.get("samples", [])
		if samples.is_empty():
			continue
		var is_hole := str(chain_data.get("topology_role", "outer")) == "hole"
		var selected := not selected_input_id.is_empty() and str(chain_data.get("input_id", "")) == selected_input_id
		var line_color := HOLE_LINE_COLOR if is_hole else SAMPLE_LINE_COLOR
		var point_color := HOLE_POINT_COLOR if is_hole else SAMPLE_POINT_COLOR
		for sample_index in range(samples.size()):
			var current := _to_screen(Vector2(samples[sample_index].get("position", Vector2.ZERO)))
			if sample_index > 0:
				var previous := _to_screen(Vector2(samples[sample_index - 1].get("position", Vector2.ZERO)))
				draw_line(previous, current, line_color, 2.5 if selected else 1.5, true)
			if sample_index == samples.size() - 1 and bool(chain_data.get("closed", false)) and samples.size() > 1:
				draw_line(current, _to_screen(Vector2(samples[0].get("position", Vector2.ZERO))), line_color, 2.5 if selected else 1.5, true)
		for sample in samples:
			var position := _to_screen(Vector2(sample.get("position", Vector2.ZERO)))
			var preserved := bool(sample.get("preserved", false))
			draw_circle(position, 4.5 if preserved or selected else 3.0, PRESERVE_COLOR if preserved else point_color)
	for cut in preview.get("cuts", []):
		if not cut is Dictionary or not bool(cut.get("valid", false)):
			continue
		var selected := not selected_input_id.is_empty() and str(cut.get("input_id", cut.get("guide_id", ""))) == selected_input_id
		for fragment in GeometrySamplingService.cut_fragments(cut):
			var samples: Array = fragment.get("samples", [])
			for sample_index in range(1, samples.size()):
				draw_dashed_line(_to_screen(Vector2(samples[sample_index - 1].get("position", Vector2.ZERO))), _to_screen(Vector2(samples[sample_index].get("position", Vector2.ZERO))), Color("#ef6c78"), 3.5 if selected else 2.5, 5.0)
			for sample in samples:
				draw_circle(_to_screen(Vector2(sample.get("position", Vector2.ZERO))), 4.0 if selected else 2.5, HOLE_POINT_COLOR)


func _draw_hole_overlays() -> void:
	for hole in overlays.get("holes", []):
		if not hole is Dictionary:
			continue
		var points: Array = hole.get("points", [])
		if points.size() < 2:
			continue
		for point_index in range(points.size()):
			var start := _to_screen(Vector2(points[point_index]))
			var end := _to_screen(Vector2(points[(point_index + 1) % points.size()]))
			draw_line(start, end, Color("#ef6c78"), 2.5, true)


func _draw_guide_overlays() -> void:
	for guide in overlays.get("guides", []):
		if not guide is Dictionary:
			continue
		var points: Array = guide.get("points", [])
		var edges: Array = guide.get("edges", [])
		for edge_data in edges:
			var start_id := str(edge_data.get("start_point_id", ""))
			var end_id := str(edge_data.get("end_point_id", ""))
			var start_point := BezierTopology.point_by_id(points, start_id)
			var end_point := BezierTopology.point_by_id(points, end_id)
			if start_point.is_empty() or end_point.is_empty():
				continue
			draw_dashed_line(_to_screen(Vector2(start_point.get("position", Vector2.ZERO))), _to_screen(Vector2(end_point.get("position", Vector2.ZERO))), Color("#ef6c78"), 2.0, 5.0)


func _to_screen(world_position: Vector2) -> Vector2:
	var local := world_position - camera_position
	return Vector2(size.x * 0.5 + local.x * camera_zoom, size.y * 0.5 - local.y * camera_zoom)


func _draw_centered_message(message: String) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(0.0, size.y * 0.5), message, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color("#737f91"))
