class_name ComponentCanvas
extends Control

signal line_draft_changed(points: Array[Vector2])
signal line_shape_changed(points: Array[Vector2], closed: bool)
signal point_selection_changed(index: int)
signal outer_shape_changed(points: Array[Vector2])
signal reference_component_selected(component_id: String)
signal pivot_changed(pivot: Vector2)
signal transform_changed(transform: Dictionary)

const PAN_SPEED := 420.0
const MIN_ZOOM := 0.25
const MAX_ZOOM := 256.0
const DEFAULT_ZOOM := 1.0
const DEFAULT_PAPER_SIZE_CM := Vector2(14.8, 21.0) # DIN A5, portrait
const DEFAULT_PAPER_MARGIN := 0.9
const ZOOM_RATE := 1.8
const CLOSE_DISTANCE_PIXELS := 14.0
const GIZMO_AXIS_LENGTH := 42.0
const HANDLE_HIT_RADIUS := 12.0
const FREE_HANDLE_RADIUS := 10.0
const MEASUREMENT_DASH_LENGTH := 7.0
const MEASUREMENT_GAP_LENGTH := 5.0
const MEASUREMENT_FONT_SIZE := 14
const GRID_PACKAGE_MIN_PIXELS := 12.0

var view_center := Vector2.ZERO
var zoom := DEFAULT_ZOOM
var context_name := ""
var active_tool := ""
var interaction_state := ""
var edit_mode := "select"
var transform_mode := "transform"
var line_draft: Array[Vector2] = []
var outer_shape: Array[Vector2] = []
var outer_shape_closed := false
var reference_shapes: Array[Dictionary] = []
var cursor_world := Vector2.ZERO
var cursor_over_canvas := false
var selected_point_index := -1
var drag_axis := ""
var add_segment_index := -1
var add_preview_point := Vector2.ZERO
var add_preview_visible := false
var snap_enabled := true
var grid_step := 16.0
var rotation_step := 15.0
var world_grid_size := 0.5
var component_transform: Dictionary = {
	"position": Vector2.ZERO,
	"rotation": 0.0,
	"scale": Vector2.ONE,
	"pivot": Vector2.ZERO
}
var material_texture: Texture2D
var material_modulate := Color.WHITE
var material_mapping_scale := Vector2.ONE
var material_mapping_offset := Vector2.ZERO
var material_wrap_mode := "clamp"
var reference_image: Texture2D
var reference_image_visible := true
var reference_image_opacity := 0.5
var reference_image_position := Vector2.ZERO
var reference_image_scale := 1.0
var paper_frame_visible := false
var paper_frame_size := Vector2.ZERO
var pivot_dragging := false
var transform_drag_axis := ""
var transform_drag_start_world := Vector2.ZERO
var transform_drag_start_position := Vector2.ZERO
var transform_drag_start_angle := 0.0
var transform_drag_start_rotation := 0.0
var transform_drag_start_scale := Vector2.ONE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	call_deferred("_apply_default_zoom")
	queue_redraw()


func _apply_default_zoom() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var fit_zoom := minf(
		size.x / DEFAULT_PAPER_SIZE_CM.x,
		size.y / DEFAULT_PAPER_SIZE_CM.y
	) * DEFAULT_PAPER_MARGIN
	zoom = clampf(fit_zoom, MIN_ZOOM, MAX_ZOOM)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		grab_focus()
		if event.button_index == MOUSE_BUTTON_LEFT and active_tool == "line":
			var snapped_point := _snap_to_grid(_world_to_local(_screen_to_world(event.position)))
			if line_draft.size() >= 3 and _is_near_first_point(snapped_point):
				line_shape_changed.emit(line_draft.duplicate(), true)
				line_draft.clear()
				line_draft_changed.emit(line_draft)
				queue_redraw()
				return
			line_draft.append(snapped_point)
			line_shape_changed.emit(line_draft.duplicate(), false)
			line_draft_changed.emit(line_draft)
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_LEFT and interaction_state == "edit":
			if _is_near_pivot(event.position):
				pivot_dragging = true
				return
			if edit_mode == "add":
				return
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
		elif event.button_index == MOUSE_BUTTON_LEFT and interaction_state == "transform":
			var handle_axis := _transform_handle_at(event.position)
			if handle_axis != "":
				transform_drag_axis = handle_axis
				transform_drag_start_world = _screen_to_world(event.position)
				transform_drag_start_position = component_transform.get("position", Vector2.ZERO)
				transform_drag_start_angle = _angle_from_transform_center(event.position)
				transform_drag_start_rotation = float(component_transform.get("rotation", 0.0))
				transform_drag_start_scale = component_transform.get("scale", Vector2.ONE)
				return
		elif event.button_index == MOUSE_BUTTON_LEFT and interaction_state == "asset":
			var component_id := _reference_component_at(_screen_to_world(event.position))
			if not component_id.is_empty():
				reference_component_selected.emit(component_id)
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		drag_axis = ""
		pivot_dragging = false
		transform_drag_axis = ""
	if event is InputEventMouseMotion:
		cursor_over_canvas = true
		cursor_world = _snap_to_grid(_world_to_local(_screen_to_world(event.position)))
		if pivot_dragging:
			var old_pivot: Vector2 = component_transform.get("pivot", Vector2.ZERO)
			var new_pivot := _snap_to_grid(_world_to_local(_screen_to_world(event.position)))
			var transform_scale: Vector2 = component_transform.get("scale", Vector2.ONE)
			var transform_rotation := deg_to_rad(float(component_transform.get("rotation", 0.0)))
			var transform_position: Vector2 = component_transform.get("position", Vector2.ZERO)
			transform_position += ((new_pivot - old_pivot) * transform_scale).rotated(transform_rotation)
			component_transform["pivot"] = new_pivot
			component_transform["position"] = transform_position
			pivot_changed.emit(new_pivot)
			transform_changed.emit(component_transform.duplicate(true))
			queue_redraw()
			return
		if interaction_state == "transform" and transform_drag_axis != "":
			var current_world := _screen_to_world(event.position)
			if transform_drag_axis == "rotate":
				var angle_delta := rad_to_deg(_angle_from_transform_center(event.position) - transform_drag_start_angle)
				var new_rotation := transform_drag_start_rotation + angle_delta
				if snap_enabled:
					new_rotation = round(new_rotation / rotation_step) * rotation_step
				component_transform["rotation"] = new_rotation
				transform_changed.emit(component_transform.duplicate(true))
				queue_redraw()
				return
			if transform_drag_axis.begins_with("scale"):
				var start_rotation := deg_to_rad(transform_drag_start_rotation)
				var start_offset := (transform_drag_start_world - transform_drag_start_position).rotated(-start_rotation)
				var current_offset := (current_world - transform_drag_start_position).rotated(-start_rotation)
				var new_scale := transform_drag_start_scale
				if transform_drag_axis == "scale_uniform" and not is_zero_approx(start_offset.length()):
					var ratio: float = current_offset.length() / start_offset.length()
					new_scale = transform_drag_start_scale * maxf(0.01, ratio)
				component_transform["scale"] = new_scale
				transform_changed.emit(component_transform.duplicate(true))
				queue_redraw()
				return
			var delta := current_world - transform_drag_start_world
			if transform_drag_axis == "x":
				delta.y = 0.0
			elif transform_drag_axis == "y":
				delta.x = 0.0
			var new_position := _snap_to_grid(transform_drag_start_position + delta)
			component_transform["position"] = new_position
			transform_changed.emit(component_transform.duplicate(true))
			queue_redraw()
			return
		if interaction_state == "edit" and edit_mode == "add":
			_update_add_preview(event.position)
		if interaction_state == "edit" and selected_point_index >= 0 and drag_axis != "":
			var moved_point := _snap_to_grid(_world_to_local(_screen_to_world(event.position)))
			var original_point: Vector2 = outer_shape[selected_point_index]
			if drag_axis == "x":
				moved_point.y = original_point.y
			elif drag_axis == "y":
				moved_point.x = original_point.x
			outer_shape[selected_point_index] = moved_point
			outer_shape_changed.emit(outer_shape.duplicate())
		queue_redraw()
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.keycode == KEY_BACKSPACE or event.keycode == KEY_DELETE) and interaction_state == "edit" and selected_point_index >= 0 and outer_shape.size() > 3:
			outer_shape.remove_at(selected_point_index)
			selected_point_index = mini(selected_point_index, outer_shape.size() - 1)
			point_selection_changed.emit(selected_point_index)
			outer_shape_changed.emit(outer_shape.duplicate())
			queue_redraw()
		elif event.keycode == KEY_SPACE and interaction_state == "edit" and edit_mode == "add":
			_confirm_add_point()
		elif event.keycode == KEY_ESCAPE and interaction_state == "edit":
			clear_selection()
		elif event.keycode == KEY_ENTER and active_tool == "line" and not line_draft.is_empty():
			line_draft.clear()
			line_draft_changed.emit(line_draft)
			queue_redraw()
		elif event.keycode == KEY_BACKSPACE and active_tool == "line" and not line_draft.is_empty():
			line_draft.pop_back()
			line_shape_changed.emit(line_draft.duplicate(), false)
			line_draft_changed.emit(line_draft)
			queue_redraw()
		elif event.keycode == KEY_ESCAPE and active_tool == "line":
			line_draft.clear()
			line_shape_changed.emit(line_draft.duplicate(), false)
			line_draft_changed.emit(line_draft)
			queue_redraw()


func set_context(context_label: String) -> void:
	context_name = context_label
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


func set_line_draft(points: Array) -> void:
	line_draft.clear()
	for point in points:
		line_draft.append(point)
	queue_redraw()


func set_interaction_state(state: String) -> void:
	interaction_state = state
	if state != "edit":
		clear_selection()
	queue_redraw()


func set_reference_shapes(shapes: Array) -> void:
	reference_shapes.clear()
	for shape in shapes:
		if shape is Dictionary:
			reference_shapes.append(shape.duplicate(true))
	queue_redraw()


func set_edit_mode(mode: String) -> void:
	edit_mode = mode
	if edit_mode != "add":
		_clear_add_preview()
	queue_redraw()


func set_transform_mode(mode: String) -> void:
	transform_mode = mode
	queue_redraw()


func set_snap_settings(enabled: bool, new_grid_step: float, new_rotation_step: float) -> void:
	snap_enabled = enabled
	grid_step = maxf(new_grid_step, 0.0001)
	rotation_step = maxf(new_rotation_step, 1.0)
	queue_redraw()


func set_world_scale(new_grid_size: float) -> void:
	world_grid_size = maxf(new_grid_size, 0.0001)
	grid_step = world_grid_size
	queue_redraw()


func set_component_transform(transform: Dictionary) -> void:
	component_transform = transform.duplicate(true)
	if not component_transform.has("pivot") or not component_transform["pivot"] is Vector2:
		component_transform["pivot"] = Vector2.ZERO
	queue_redraw()


func set_component_material(texture: Texture2D, tint := Color.WHITE, opacity := 1.0, mapping_scale := Vector2.ONE, mapping_offset := Vector2.ZERO, wrap_mode := "clamp") -> void:
	material_texture = texture
	material_modulate = Color(tint.r, tint.g, tint.b, clampf(float(opacity), 0.0, 1.0))
	material_mapping_scale = Vector2(maxf(mapping_scale.x, 0.01), maxf(mapping_scale.y, 0.01))
	material_mapping_offset = mapping_offset
	material_wrap_mode = wrap_mode
	queue_redraw()


func set_reference_image(texture: Texture2D, image_visible := true, image_opacity := 0.5, image_position := Vector2.ZERO, image_scale := 1.0) -> void:
	reference_image = texture
	reference_image_visible = image_visible
	reference_image_opacity = clampf(float(image_opacity), 0.0, 1.0)
	reference_image_position = image_position
	# Normalized reference images can require scales below 0.01 when their
	# source resolution is large. Keep the positive guard, but do not impose a
	# centimeter-scale minimum that changes the requested target height.
	reference_image_scale = maxf(float(image_scale), 0.000001)
	queue_redraw()


func set_paper_frame(frame_size: Vector2, frame_visible: bool) -> void:
	paper_frame_size = frame_size
	paper_frame_visible = frame_visible and frame_size.x > 0.0 and frame_size.y > 0.0
	queue_redraw()


func _local_to_world(local_point: Vector2) -> Vector2:
	return _local_to_world_with_transform(local_point, component_transform)


func _local_to_world_with_transform(local_point: Vector2, transform: Dictionary) -> Vector2:
	var pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
	var transform_position: Vector2 = transform.get("position", Vector2.ZERO)
	var transform_scale: Vector2 = transform.get("scale", Vector2.ONE)
	var transform_rotation := deg_to_rad(float(transform.get("rotation", 0.0)))
	return transform_position + ((local_point - pivot) * transform_scale).rotated(transform_rotation)


func _world_to_local(world_point: Vector2) -> Vector2:
	var pivot: Vector2 = component_transform.get("pivot", Vector2.ZERO)
	var transform_position: Vector2 = component_transform.get("position", Vector2.ZERO)
	var transform_scale: Vector2 = component_transform.get("scale", Vector2.ONE)
	var transform_rotation := deg_to_rad(float(component_transform.get("rotation", 0.0)))
	var local_offset := (world_point - transform_position).rotated(-transform_rotation)
	if not is_zero_approx(transform_scale.x):
		local_offset.x /= transform_scale.x
	if not is_zero_approx(transform_scale.y):
		local_offset.y /= transform_scale.y
	return pivot + local_offset


func clear_selection() -> void:
	selected_point_index = -1
	drag_axis = ""
	point_selection_changed.emit(selected_point_index)


func _clear_add_preview() -> void:
	add_segment_index = -1
	add_preview_visible = false


func _update_add_preview(screen_position: Vector2) -> void:
	add_segment_index = -1
	add_preview_visible = false
	if outer_shape.size() < 3:
		return
	var nearest_distance := 16.0
	for index in range(outer_shape.size()):
		var next_index := (index + 1) % outer_shape.size()
		var start := _world_to_screen(_local_to_world(outer_shape[index]))
		var end := _world_to_screen(_local_to_world(outer_shape[next_index]))
		var segment := end - start
		if segment.length_squared() <= 0.001:
			continue
		var factor := clampf((screen_position - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
		var candidate := start + segment * factor
		var distance := screen_position.distance_to(candidate)
		if distance < nearest_distance:
			nearest_distance = distance
			add_segment_index = index
			add_preview_point = _world_to_local(_screen_to_world(candidate))
			add_preview_visible = true
	queue_redraw()


func _confirm_add_point() -> void:
	if not add_preview_visible or add_segment_index < 0:
		return
	outer_shape.insert(add_segment_index + 1, add_preview_point)
	selected_point_index = add_segment_index + 1
	point_selection_changed.emit(selected_point_index)
	outer_shape_changed.emit(outer_shape.duplicate())
	_clear_add_preview()
	queue_redraw()


func set_outer_shape(points: Array, closed := true) -> void:
	outer_shape.clear()
	for point in points:
		outer_shape.append(point)
	outer_shape_closed = closed
	queue_redraw()


func _process(delta: float) -> void:
	if not has_focus():
		return
	var command_modifier: bool = Input.is_key_pressed(KEY_META) or Input.is_key_pressed(KEY_CTRL)
	var pan_input := Vector2.ZERO if command_modifier else Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	)
	if pan_input.length_squared() > 0.0:
		view_center += pan_input.normalized() * PAN_SPEED / zoom * delta
	var zoom_input := float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))
	if not is_zero_approx(zoom_input):
		zoom = clampf(zoom * pow(ZOOM_RATE, zoom_input * delta), MIN_ZOOM, MAX_ZOOM)
	queue_redraw()


func _draw() -> void:
	_draw_fixed_grid()
	var half_view := size / (2.0 * zoom)
	var min_world := view_center - half_view
	var max_world := view_center + half_view
	_draw_paper_frame()
	var x_axis_color := Color("#6a4d58")
	var y_axis_color := Color("#4c6a5b")
	draw_line(_world_to_screen(Vector2(min_world.x, 0.0)), _world_to_screen(Vector2(max_world.x, 0.0)), x_axis_color, 2.0)
	draw_line(_world_to_screen(Vector2(0.0, min_world.y)), _world_to_screen(Vector2(0.0, max_world.y)), y_axis_color, 2.0)
	_draw_reference_image()
	_draw_reference_shapes()
	_draw_outer_shape()
	_draw_pivot()
	_draw_transform_gizmo()
	_draw_line_draft()
	_draw_measurement_guides()


func _draw_fixed_grid() -> void:
	var main_grid_step := maxf(world_grid_size, 0.0001)
	var fine_grid_step := main_grid_step / 5.0
	var main_pixel_step := main_grid_step * zoom
	var fine_pixel_step := fine_grid_step * zoom
	if fine_pixel_step >= 1.0:
		_draw_grid_lines(fine_grid_step, Color("#20262f"), 1.0)
	if main_pixel_step >= 0.25:
		_draw_grid_lines(main_grid_step, Color("#303844"), 1.0)
	var package_level := _active_grid_package_level()
	var package_step := main_grid_step * pow(5.0, package_level)
	if package_level > 0:
		_draw_grid_lines(package_step, Color("#465263"), 1.5)


func _active_grid_package_level() -> int:
	var package_level := 0
	var package_step := maxf(world_grid_size, 0.0001)
	while package_step * zoom < GRID_PACKAGE_MIN_PIXELS:
		package_step *= 5.0
		package_level += 1
	return package_level


func _draw_grid_lines(step: float, line_color: Color, line_width: float) -> void:
	var half_view := size / (2.0 * zoom)
	var min_world := view_center - half_view
	var max_world := view_center + half_view
	var first_x := floori(min_world.x / step)
	var last_x := ceili(max_world.x / step)
	var first_y := floori(min_world.y / step)
	var last_y := ceili(max_world.y / step)
	for grid_index in range(first_x, last_x + 1):
		var world_x := grid_index * step
		draw_line(_world_to_screen(Vector2(world_x, min_world.y)), _world_to_screen(Vector2(world_x, max_world.y)), line_color, line_width)
	for grid_index in range(first_y, last_y + 1):
		var world_y := grid_index * step
		draw_line(_world_to_screen(Vector2(min_world.x, world_y)), _world_to_screen(Vector2(max_world.x, world_y)), line_color, line_width)


func _draw_paper_frame() -> void:
	if not paper_frame_visible:
		return
	var half_width := paper_frame_size.x * 0.5
	var half_height := paper_frame_size.y * 0.5
	var bottom_left := _world_to_screen(Vector2(-half_width, -half_height))
	var bottom_right := _world_to_screen(Vector2(half_width, -half_height))
	var top_right := _world_to_screen(Vector2(half_width, half_height))
	var top_left := _world_to_screen(Vector2(-half_width, half_height))
	var frame_color := Color("#f2c94caa")
	draw_line(bottom_left, bottom_right, frame_color, 2.0)
	draw_line(bottom_right, top_right, frame_color, 2.0)
	draw_line(top_right, top_left, frame_color, 2.0)
	draw_line(top_left, bottom_left, frame_color, 2.0)


func _draw_measurement_guides() -> void:
	if not cursor_over_canvas or context_name.is_empty():
		return
	if interaction_state != "asset" and not interaction_state.is_empty():
		return
	var origin_world := Vector2.ZERO
	var cursor_position_world := cursor_world
	if interaction_state.is_empty():
		origin_world = component_transform.get("position", Vector2.ZERO)
		cursor_position_world = _local_to_world(cursor_world)
	var origin_screen := _world_to_screen(origin_world)
	var cursor_screen := _world_to_screen(cursor_position_world)
	var guide_color := Color("#f2c94c")
	var x_guide_start := Vector2(origin_screen.x, cursor_screen.y)
	var y_guide_start := Vector2(cursor_screen.x, origin_screen.y)
	_draw_dashed_line(origin_screen, x_guide_start, guide_color)
	_draw_dashed_line(origin_screen, y_guide_start, guide_color)
	_draw_dashed_line(x_guide_start, cursor_screen, guide_color)
	_draw_dashed_line(y_guide_start, cursor_screen, guide_color)
	draw_circle(cursor_screen, 3.0, guide_color)
	_draw_measurement_label("x: %.2f cm" % (cursor_position_world.x - origin_world.x), (y_guide_start + cursor_screen) * 0.5 + Vector2(0.0, -8.0), guide_color)
	_draw_measurement_label("y: %.2f cm" % (cursor_position_world.y - origin_world.y), (x_guide_start + cursor_screen) * 0.5 + Vector2(8.0, 0.0), guide_color)


func _draw_dashed_line(line_start: Vector2, line_end: Vector2, line_color: Color) -> void:
	var line_vector := line_end - line_start
	var line_length := line_vector.length()
	if line_length <= 0.5:
		return
	var direction := line_vector / line_length
	var distance := 0.0
	while distance < line_length:
		var dash_end := minf(distance + MEASUREMENT_DASH_LENGTH, line_length)
		draw_line(line_start + direction * distance, line_start + direction * dash_end, line_color, 1.0)
		distance = dash_end + MEASUREMENT_GAP_LENGTH


func _draw_measurement_label(label_text: String, label_center: Vector2, label_color: Color) -> void:
	var label_font := ThemeDB.fallback_font
	var text_size := label_font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, MEASUREMENT_FONT_SIZE)
	var label_rect := Rect2(label_center - text_size * 0.5 - Vector2(4.0, 2.0), text_size + Vector2(8.0, 4.0))
	draw_rect(label_rect, Color("#181a1fcc"))
	draw_string(label_font, label_rect.position + Vector2(4.0, text_size.y), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, MEASUREMENT_FONT_SIZE, label_color)


func _draw_reference_image() -> void:
	if not is_instance_valid(reference_image) or not reference_image_visible:
		return
	var image_size := Vector2(reference_image.get_width(), reference_image.get_height()) * reference_image_scale * zoom
	if image_size.x <= 0.0 or image_size.y <= 0.0:
		return
	var image_center := _world_to_screen(reference_image_position)
	var image_rect := Rect2(image_center - image_size * 0.5, image_size)
	draw_texture_rect(reference_image, image_rect, false, Color(1.0, 1.0, 1.0, reference_image_opacity))


func _draw_pivot() -> void:
	if context_name.is_empty() or interaction_state == "asset":
		return
	var pivot_screen := _world_to_screen(component_transform.get("position", Vector2.ZERO))
	var pivot_color := Color("#d98cff")
	draw_circle(pivot_screen, 7.0, pivot_color, false, 2.0)
	draw_line(pivot_screen - Vector2(11.0, 0.0), pivot_screen + Vector2(11.0, 0.0), pivot_color, 1.0)
	draw_line(pivot_screen - Vector2(0.0, 11.0), pivot_screen + Vector2(0.0, 11.0), pivot_color, 1.0)


func _draw_transform_gizmo() -> void:
	if interaction_state != "transform" or context_name.is_empty():
		return
	var center := _world_to_screen(component_transform.get("position", Vector2.ZERO))
	if transform_mode == "rotate":
		draw_arc(center, 34.0, 0.0, TAU, 48, Color("#f2c94c"), 2.0)
		draw_circle(center + Vector2(0.0, -34.0), 7.0, Color("#f2c94c"))
	elif transform_mode == "scale":
		var box := Rect2(center - Vector2(30.0, 30.0), Vector2(60.0, 60.0))
		draw_rect(box, Color("#8ab4f8"), false, 2.0)
		for corner in [box.position, box.position + Vector2(box.size.x, 0.0), box.position + Vector2(0.0, box.size.y), box.end]:
			draw_circle(corner, 6.0, Color("#8ab4f8"))
	else:
		draw_line(center, center + Vector2(44.0, 0.0), Color("#e56b6f"), 2.0)
		draw_line(center, center + Vector2(0.0, -44.0), Color("#6bcB77"), 2.0)
		draw_circle(center + Vector2(44.0, 0.0), 7.0, Color("#e56b6f"))
		draw_circle(center + Vector2(0.0, -44.0), 7.0, Color("#6bcB77"))
		draw_rect(Rect2(center - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), Color("#f2c94c"), false, 2.0)


func _transform_handle_at(screen_position: Vector2) -> String:
	var center := _world_to_screen(component_transform.get("position", Vector2.ZERO))
	if transform_mode == "rotate":
		var distance_to_center := screen_position.distance_to(center)
		if distance_to_center >= 24.0 and distance_to_center <= 46.0:
			return "rotate"
		return ""
	if transform_mode == "scale":
		for corner in [Vector2(30.0, -30.0), Vector2(-30.0, -30.0), Vector2(30.0, 30.0), Vector2(-30.0, 30.0)]:
			if screen_position.distance_to(center + corner) <= 12.0:
				return "scale_uniform"
		return ""
	if screen_position.distance_to(center) <= 12.0:
		return "free"
	if screen_position.distance_to(center + Vector2(44.0, 0.0)) <= 12.0:
		return "x"
	if screen_position.distance_to(center + Vector2(0.0, -44.0)) <= 12.0:
		return "y"
	return ""


func _angle_from_transform_center(screen_position: Vector2) -> float:
	var center := _world_to_screen(component_transform.get("position", Vector2.ZERO))
	var screen_offset := screen_position - center
	return Vector2(screen_offset.x, -screen_offset.y).angle()


func _is_near_pivot(screen_position: Vector2) -> bool:
	if context_name.is_empty() or interaction_state == "asset":
		return false
	var pivot_position: Vector2 = component_transform.get("position", Vector2.ZERO)
	return screen_position.distance_to(_world_to_screen(pivot_position)) <= 12.0


func _draw_reference_shapes() -> void:
	var ordered_shapes := reference_shapes.duplicate()
	ordered_shapes.sort_custom(_sort_reference_shapes)
	for shape in ordered_shapes:
		if not bool(shape.get("visibility", true)):
			continue
		var points: Array = shape.get("points", [])
		if points.is_empty():
			continue
		var transform: Dictionary = shape.get("transform", {})
		var closed := bool(shape.get("closed", points.size() >= 3))
		var reference_color := Color("#55c7d966")
		var edge_count := points.size() if closed and points.size() >= 3 else maxi(points.size() - 1, 0)
		for index in range(edge_count):
			var next_index := (index + 1) % points.size()
			draw_line(_world_to_screen(_local_to_world_with_transform(points[index], transform)), _world_to_screen(_local_to_world_with_transform(points[next_index], transform)), reference_color, 2.0)
		for point in points:
			draw_circle(_world_to_screen(_local_to_world_with_transform(point, transform)), 3.0, reference_color)


func _sort_reference_shapes(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("z_index", 0)) < int(b.get("z_index", 0))


func _reference_component_at(world_position: Vector2) -> String:
	var nearest_id := ""
	var nearest_distance := 14.0
	var ordered_shapes := reference_shapes.duplicate()
	ordered_shapes.sort_custom(_sort_reference_shapes)
	ordered_shapes.reverse()
	for shape in ordered_shapes:
		if not bool(shape.get("visibility", true)):
			continue
		var points: Array = shape.get("points", [])
		if points.size() < 2:
			continue
		var transform: Dictionary = shape.get("transform", {})
		var world_points: Array[Vector2] = []
		for point in points:
			world_points.append(_local_to_world_with_transform(point, transform))
		if bool(shape.get("closed", points.size() >= 3)) and Geometry2D.is_point_in_polygon(world_position, PackedVector2Array(world_points)):
			return str(shape.get("id", ""))
		for index in range(world_points.size()):
			var next_index := (index + 1) % world_points.size()
			var closest := Geometry2D.get_closest_point_to_segment(world_position, world_points[index], world_points[next_index])
			var distance := world_position.distance_to(closest)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_id = str(shape.get("id", ""))
	return nearest_id


func _draw_outer_shape() -> void:
	if not bool(component_transform.get("visibility", true)):
		return
	if outer_shape.is_empty():
		return
	if outer_shape_closed and outer_shape.size() >= 3 and is_instance_valid(material_texture):
		_draw_material_polygon()
	var shape_color := Color("#55c7d9")
	var edge_count := outer_shape.size() if outer_shape_closed and outer_shape.size() >= 3 else maxi(outer_shape.size() - 1, 0)
	for index in range(edge_count):
		var next_index := (index + 1) % outer_shape.size()
		draw_line(_world_to_screen(_local_to_world(outer_shape[index])), _world_to_screen(_local_to_world(outer_shape[next_index])), shape_color, 2.0)
	for point in outer_shape:
		draw_circle(_world_to_screen(_local_to_world(point)), 4.0, shape_color)
	if interaction_state == "edit" and selected_point_index >= 0 and selected_point_index < outer_shape.size():
		var selected_position := _world_to_screen(_local_to_world(outer_shape[selected_point_index]))
		draw_circle(selected_position, 7.0, Color("#f2c94c"), false, 2.0)
		_draw_move_gizmo(selected_position)
	if interaction_state == "edit" and edit_mode == "add" and add_preview_visible:
		draw_circle(_world_to_screen(_local_to_world(add_preview_point)), 8.0, Color("#f2c94c"), false, 2.0)
		draw_circle(_world_to_screen(_local_to_world(add_preview_point)), 3.0, Color("#f2c94c"))


func _draw_material_polygon() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED if material_wrap_mode == "repeat" else CanvasItem.TEXTURE_REPEAT_DISABLED
	var min_point := outer_shape[0]
	var max_point := outer_shape[0]
	for point in outer_shape:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	var extent := max_point - min_point
	if is_zero_approx(extent.x):
		extent.x = 1.0
	if is_zero_approx(extent.y):
		extent.y = 1.0
	var screen_points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for point in outer_shape:
		screen_points.append(_world_to_screen(_local_to_world(point)))
		var base_uv := Vector2((point.x - min_point.x) / extent.x, (point.y - min_point.y) / extent.y)
		uvs.append(base_uv if material_wrap_mode == "fit" else base_uv / material_mapping_scale + material_mapping_offset)
		colors.append(material_modulate)
	draw_polygon(screen_points, colors, uvs, material_texture)


func _draw_move_gizmo(point: Vector2) -> void:
	var x_end := point + Vector2(GIZMO_AXIS_LENGTH, 0.0)
	var y_end := point + Vector2(0.0, -GIZMO_AXIS_LENGTH)
	draw_line(point, x_end, Color("#e56b6f"), 2.0)
	draw_line(point, y_end, Color("#6bcB77"), 2.0)
	draw_circle(x_end, 7.0, Color("#e56b6f"))
	draw_circle(y_end, 7.0, Color("#6bcB77"))
	draw_rect(Rect2(point - Vector2(FREE_HANDLE_RADIUS, FREE_HANDLE_RADIUS), Vector2(FREE_HANDLE_RADIUS * 2.0, FREE_HANDLE_RADIUS * 2.0)), Color("#f2c94c"), false, 2.0)
	draw_circle(point, 5.0, Color("#f2c94c"))


func _gizmo_axis_at(screen_position: Vector2) -> String:
	if selected_point_index < 0 or selected_point_index >= outer_shape.size():
		return ""
	var point := _world_to_screen(_local_to_world(outer_shape[selected_point_index]))
	if screen_position.distance_to(point) <= FREE_HANDLE_RADIUS:
		return "free"
	if screen_position.distance_to(point + Vector2(GIZMO_AXIS_LENGTH, 0.0)) <= HANDLE_HIT_RADIUS:
		return "x"
	if screen_position.distance_to(point + Vector2(0.0, -GIZMO_AXIS_LENGTH)) <= HANDLE_HIT_RADIUS:
		return "y"
	return ""


func _nearest_outer_point(screen_position: Vector2) -> int:
	var nearest_index := -1
	var nearest_distance := HANDLE_HIT_RADIUS
	for index in range(outer_shape.size()):
		var distance := screen_position.distance_to(_world_to_screen(_local_to_world(outer_shape[index])))
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return nearest_index


func _draw_line_draft() -> void:
	if active_tool != "line" or not cursor_over_canvas:
		return
	var draft_color := Color("#f2c94c")
	for index in range(line_draft.size() - 1):
		draw_line(_world_to_screen(_local_to_world(line_draft[index])), _world_to_screen(_local_to_world(line_draft[index + 1])), draft_color, 2.0)
	for point in line_draft:
		draw_circle(_world_to_screen(_local_to_world(point)), 5.0, draft_color)
	if line_draft.is_empty():
		draw_circle(_world_to_screen(_local_to_world(cursor_world)), 5.0, draft_color)
	elif has_focus():
		var preview_target := line_draft[0] if line_draft.size() >= 3 and _is_near_first_point(cursor_world) else cursor_world
		var preview_color := Color("#76e0a5") if preview_target == line_draft[0] and line_draft.size() >= 3 else Color("#f2c94c88")
		draw_line(_world_to_screen(_local_to_world(line_draft.back())), _world_to_screen(_local_to_world(preview_target)), preview_color, 1.0)
		draw_circle(_world_to_screen(_local_to_world(cursor_world)), 4.0, Color("#f2c94c88"))
		if preview_target == line_draft[0] and line_draft.size() >= 3:
			draw_circle(_world_to_screen(_local_to_world(line_draft[0])), 7.0, Color("#76e0a5"), false, 2.0)


func _world_to_screen(world_position: Vector2) -> Vector2:
	return size * 0.5 + Vector2(world_position.x - view_center.x, -(world_position.y - view_center.y)) * zoom


func _screen_to_world(screen_position: Vector2) -> Vector2:
	var screen_offset := (screen_position - size * 0.5) / zoom
	return view_center + Vector2(screen_offset.x, -screen_offset.y)


func _snap_to_grid(world_position: Vector2) -> Vector2:
	if not snap_enabled:
		return world_position
	var snap_step := maxf(world_grid_size, 0.0001) * pow(5.0, _active_grid_package_level())
	return Vector2(
		round(world_position.x / snap_step) * snap_step,
		round(world_position.y / snap_step) * snap_step
	)


func _is_near_first_point(world_position: Vector2) -> bool:
	if line_draft.is_empty():
		return false
	return _world_to_screen(_local_to_world(world_position)).distance_to(_world_to_screen(_local_to_world(line_draft[0]))) <= CLOSE_DISTANCE_PIXELS
