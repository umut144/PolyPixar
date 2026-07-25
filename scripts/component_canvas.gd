class_name ComponentCanvas
extends Control

const PAN_SPEED := 420.0
const MIN_ZOOM := 0.25
const MAX_ZOOM := 8.0
const ZOOM_RATE := 1.8
const BASE_GRID_STEP := 32.0

var view_center := Vector2.ZERO
var zoom := 1.0
var context_name := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		grab_focus()


func set_context(name: String) -> void:
	context_name = name
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


func _visible_grid_step() -> float:
	var grid_step := BASE_GRID_STEP
	while grid_step * zoom < 16.0:
		grid_step *= 2.0
	while grid_step * zoom > 80.0:
		grid_step *= 0.5
	return grid_step


func _world_to_screen(world_position: Vector2) -> Vector2:
	return size * 0.5 + (world_position - view_center) * zoom
