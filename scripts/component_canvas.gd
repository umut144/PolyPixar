class_name ComponentCanvas
extends Control

signal line_draft_changed(points: Array[Vector2])
signal line_completed(points: Array[Vector2])

const PAN_SPEED := 420.0
const MIN_ZOOM := 0.25
const MAX_ZOOM := 8.0
const ZOOM_RATE := 1.8
const BASE_GRID_STEP := 32.0
const CLOSE_DISTANCE_PIXELS := 14.0

var view_center := Vector2.ZERO
var zoom := 1.0
var context_name := ""
var active_tool := ""
var line_draft: Array[Vector2] = []
var outer_shape: Array[Vector2] = []
var cursor_world := Vector2.ZERO
var cursor_over_canvas := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		grab_focus()
		if event.button_index == MOUSE_BUTTON_LEFT and active_tool == "line":
			var snapped_point := _snap_to_grid(_screen_to_world(event.position))
			if line_draft.size() >= 3 and _is_near_first_point(snapped_point):
				line_completed.emit(line_draft.duplicate())
				line_draft.clear()
				line_draft_changed.emit(line_draft)
				queue_redraw()
				return
			line_draft.append(snapped_point)
			line_draft_changed.emit(line_draft)
			queue_redraw()
	if event is InputEventMouseMotion:
		cursor_over_canvas = true
		cursor_world = _snap_to_grid(_screen_to_world(event.position))
		queue_redraw()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_BACKSPACE and active_tool == "line" and not line_draft.is_empty():
			line_draft.pop_back()
			line_draft_changed.emit(line_draft)
			queue_redraw()
		elif event.keycode == KEY_ESCAPE and active_tool == "line":
			line_draft.clear()
			line_draft_changed.emit(line_draft)
			queue_redraw()


func set_context(name: String) -> void:
	context_name = name
	queue_redraw()


func _on_mouse_entered() -> void:
	cursor_over_canvas = true
	queue_redraw()


func _on_mouse_exited() -> void:
	cursor_over_canvas = false
	queue_redraw()


func set_tool_mode(tool_name: String) -> void:
	active_tool = tool_name
	line_draft.clear()
	line_draft_changed.emit(line_draft)
	queue_redraw()


func set_outer_shape(points: Array) -> void:
	outer_shape.clear()
	for point in points:
		outer_shape.append(point)
	queue_redraw()


func _process(delta: float) -> void:
	if not has_focus():
		return
	var pan_input := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	if pan_input.length_squared() > 0.0:
		view_center += pan_input.normalized() * PAN_SPEED / zoom * delta
	var zoom_input := float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))
	if not is_zero_approx(zoom_input):
		zoom = clampf(zoom * pow(ZOOM_RATE, zoom_input * delta), MIN_ZOOM, MAX_ZOOM)
	queue_redraw()


func _draw() -> void:
	var grid_step := _visible_grid_step()
	var half_view := size / (2.0 * zoom)
	var min_world := view_center - half_view
	var max_world := view_center + half_view
	var first_x := floori(min_world.x / grid_step)
	var last_x := ceili(max_world.x / grid_step)
	var first_y := floori(min_world.y / grid_step)
	var last_y := ceili(max_world.y / grid_step)
	for grid_index in range(first_x, last_x + 1):
		var world_x := grid_index * grid_step
		var color := Color("#2a303a") if posmod(grid_index, 4) == 0 else Color("#222730")
		draw_line(_world_to_screen(Vector2(world_x, min_world.y)), _world_to_screen(Vector2(world_x, max_world.y)), color, 1.0)
	for grid_index in range(first_y, last_y + 1):
		var world_y := grid_index * grid_step
		var color := Color("#2a303a") if posmod(grid_index, 4) == 0 else Color("#222730")
		draw_line(_world_to_screen(Vector2(min_world.x, world_y)), _world_to_screen(Vector2(max_world.x, world_y)), color, 1.0)
	var axis_color := Color("#46505e")
	draw_line(_world_to_screen(Vector2(min_world.x, 0.0)), _world_to_screen(Vector2(max_world.x, 0.0)), axis_color, 1.0)
	draw_line(_world_to_screen(Vector2(0.0, min_world.y)), _world_to_screen(Vector2(0.0, max_world.y)), axis_color, 1.0)
	_draw_outer_shape()
	_draw_line_draft()


func _draw_outer_shape() -> void:
	if outer_shape.size() < 3:
		return
	var shape_color := Color("#55c7d9")
	for index in range(outer_shape.size()):
		var next_index := (index + 1) % outer_shape.size()
		draw_line(_world_to_screen(outer_shape[index]), _world_to_screen(outer_shape[next_index]), shape_color, 2.0)
	for point in outer_shape:
		draw_circle(_world_to_screen(point), 4.0, shape_color)


func _draw_line_draft() -> void:
	if active_tool != "line" or not cursor_over_canvas:
		return
	var draft_color := Color("#f2c94c")
	for index in range(line_draft.size() - 1):
		draw_line(_world_to_screen(line_draft[index]), _world_to_screen(line_draft[index + 1]), draft_color, 2.0)
	for point in line_draft:
		draw_circle(_world_to_screen(point), 5.0, draft_color)
	if line_draft.is_empty():
		draw_circle(_world_to_screen(cursor_world), 5.0, draft_color)
	elif has_focus():
		var preview_target := line_draft[0] if line_draft.size() >= 3 and _is_near_first_point(cursor_world) else cursor_world
		var preview_color := Color("#76e0a5") if preview_target == line_draft[0] and line_draft.size() >= 3 else Color("#f2c94c88")
		draw_line(_world_to_screen(line_draft.back()), _world_to_screen(preview_target), preview_color, 1.0)
		draw_circle(_world_to_screen(cursor_world), 4.0, Color("#f2c94c88"))
		if preview_target == line_draft[0] and line_draft.size() >= 3:
			draw_circle(_world_to_screen(line_draft[0]), 7.0, Color("#76e0a5"), false, 2.0)


func _visible_grid_step() -> float:
	var grid_step := BASE_GRID_STEP
	while grid_step * zoom < 16.0:
		grid_step *= 2.0
	while grid_step * zoom > 80.0:
		grid_step *= 0.5
	return grid_step


func _world_to_screen(world_position: Vector2) -> Vector2:
	return size * 0.5 + (world_position - view_center) * zoom


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return view_center + (screen_position - size * 0.5) / zoom


func _snap_to_grid(world_position: Vector2) -> Vector2:
	var grid_step := _visible_grid_step()
	return Vector2(
		round(world_position.x / grid_step) * grid_step,
		round(world_position.y / grid_step) * grid_step
	)


func _is_near_first_point(world_position: Vector2) -> bool:
	if line_draft.is_empty():
		return false
	return _world_to_screen(world_position).distance_to(_world_to_screen(line_draft[0])) <= CLOSE_DISTANCE_PIXELS
