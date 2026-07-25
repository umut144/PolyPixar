class_name ComponentCanvas
extends Control

signal line_draft_changed(points: Array[Vector2])
signal line_completed(points: Array[Vector2])
signal point_selection_changed(index: int)
signal outer_shape_changed(points: Array[Vector2])

const PAN_SPEED := 420.0
const MIN_ZOOM := 0.25
const MAX_ZOOM := 8.0
const ZOOM_RATE := 1.8
const BASE_GRID_STEP := 32.0
const CLOSE_DISTANCE_PIXELS := 14.0
const GIZMO_AXIS_LENGTH := 42.0
const HANDLE_HIT_RADIUS := 12.0

var view_center := Vector2.ZERO
var zoom := 1.0
var context_name := ""
var active_tool := ""
var interaction_state := ""
var edit_mode := "select"
var line_draft: Array[Vector2] = []
var outer_shape: Array[Vector2] = []
var cursor_world := Vector2.ZERO
var cursor_over_canvas := false
var selected_point_index := -1
var drag_axis := ""


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
		elif event.button_index == MOUSE_BUTTON_LEFT and interaction_state == "edit":
			var gizmo_axis := _gizmo_axis_at(event.position)
			if selected_point_index >= 0 and gizmo_axis != "":
				drag_axis = gizmo_axis
				return
			var nearest_index := _nearest_outer_point(event.position)
			if nearest_index >= 0:
				selected_point_index = nearest_index
				point_selection_changed.emit(selected_point_index)
			else:
				clear_selection()
			queue_redraw()
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		drag_axis = ""
	if event is InputEventMouseMotion:
		cursor_over_canvas = true
		cursor_world = _snap_to_grid(_screen_to_world(event.position))
		if interaction_state == "edit" and selected_point_index >= 0 and drag_axis != "":
			var moved_point := _snap_to_grid(_screen_to_world(event.position))
			var original_point: Vector2 = outer_shape[selected_point_index]
			if drag_axis == "x":
				moved_point.y = original_point.y
			elif drag_axis == "y":
				moved_point.x = original_point.x
			outer_shape[selected_point_index] = moved_point
			outer_shape_changed.emit(outer_shape.duplicate())
		queue_redraw()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_BACKSPACE and interaction_state == "edit" and selected_point_index >= 0 and outer_shape.size() > 3:
			outer_shape.remove_at(selected_point_index)
			selected_point_index = mini(selected_point_index, outer_shape.size() - 1)
			point_selection_changed.emit(selected_point_index)
			outer_shape_changed.emit(outer_shape.duplicate())
			queue_redraw()
		elif event.keycode == KEY_ESCAPE and interaction_state == "edit":
			clear_selection()
		elif event.keycode == KEY_BACKSPACE and active_tool == "line" and not line_draft.is_empty():
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


func set_interaction_state(state: String) -> void:
	interaction_state = state
	if state != "edit":
		clear_selection()
	queue_redraw()


func set_edit_mode(mode: String) -> void:
	edit_mode = mode
	queue_redraw()


func clear_selection() -> void:
	selected_point_index = -1
	drag_axis = ""
	point_selection_changed.emit(selected_point_index)


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
	if interaction_state == "edit" and selected_point_index >= 0 and selected_point_index < outer_shape.size():
		var selected_position := _world_to_screen(outer_shape[selected_point_index])
		draw_circle(selected_position, 7.0, Color("#f2c94c"), false, 2.0)
		_draw_move_gizmo(selected_position)


func _draw_move_gizmo(point: Vector2) -> void:
	var x_end := point + Vector2(GIZMO_AXIS_LENGTH, 0.0)
	var y_end := point + Vector2(0.0, -GIZMO_AXIS_LENGTH)
	draw_line(point, x_end, Color("#e56b6f"), 2.0)
	draw_line(point, y_end, Color("#6bcB77"), 2.0)
	draw_circle(x_end, 7.0, Color("#e56b6f"))
	draw_circle(y_end, 7.0, Color("#6bcB77"))
	draw_circle(point, 5.0, Color("#f2c94c"))


func _gizmo_axis_at(screen_position: Vector2) -> String:
	if selected_point_index < 0 or selected_point_index >= outer_shape.size():
		return ""
	var point := _world_to_screen(outer_shape[selected_point_index])
	if screen_position.distance_to(point + Vector2(GIZMO_AXIS_LENGTH, 0.0)) <= HANDLE_HIT_RADIUS:
		return "x"
	if screen_position.distance_to(point + Vector2(0.0, -GIZMO_AXIS_LENGTH)) <= HANDLE_HIT_RADIUS:
		return "y"
	return ""


func _nearest_outer_point(screen_position: Vector2) -> int:
	var nearest_index := -1
	var nearest_distance := HANDLE_HIT_RADIUS
	for index in range(outer_shape.size()):
		var distance := screen_position.distance_to(_world_to_screen(outer_shape[index]))
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return nearest_index


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
