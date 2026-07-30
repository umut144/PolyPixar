class_name ReferenceImageCropView
extends Control

var source_image: Image
var source_texture: Texture2D
var crop_rect := Rect2(0.0, 0.0, 1.0, 1.0)
var image_rect := Rect2()
var dragging := false
var drag_start := Vector2.ZERO


func set_image(image: Image) -> void:
	source_image = image.duplicate()
	source_texture = ImageTexture.create_from_image(source_image)
	crop_rect = Rect2(0.0, 0.0, 1.0, 1.0)
	queue_redraw()


func get_cropped_image() -> Image:
	if source_image == null or source_image.is_empty():
		return null
	var crop_position := Vector2i(
		floori(crop_rect.position.x * source_image.get_width()),
		floori(crop_rect.position.y * source_image.get_height())
	)
	var crop_size := Vector2i(
		maxi(1, ceili(crop_rect.size.x * source_image.get_width())),
		maxi(1, ceili(crop_rect.size.y * source_image.get_height()))
	)
	crop_size.x = mini(crop_size.x, source_image.get_width() - crop_position.x)
	crop_size.y = mini(crop_size.y, source_image.get_height() - crop_position.y)
	return source_image.get_region(Rect2i(crop_position, crop_size))


func _gui_input(event: InputEvent) -> void:
	if source_texture == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and image_rect.has_point(event.position):
			dragging = true
			drag_start = _normalized_point(event.position)
			crop_rect = Rect2(drag_start, Vector2.ZERO)
			queue_redraw()
		elif not event.pressed:
			dragging = false
	if event is InputEventMouseMotion and dragging:
		var current_point := _normalized_point(event.position)
		var top_left := Vector2(minf(drag_start.x, current_point.x), minf(drag_start.y, current_point.y))
		var bottom_right := Vector2(maxf(drag_start.x, current_point.x), maxf(drag_start.y, current_point.y))
		crop_rect = Rect2(top_left, bottom_right - top_left)
		queue_redraw()


func _normalized_point(point: Vector2) -> Vector2:
	return Vector2(
		clampf((point.x - image_rect.position.x) / maxf(image_rect.size.x, 1.0), 0.0, 1.0),
		clampf((point.y - image_rect.position.y) / maxf(image_rect.size.y, 1.0), 0.0, 1.0)
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#161a20"), true)
	if source_texture == null or source_image == null or source_image.is_empty():
		return
	var available_size := size - Vector2(32.0, 32.0)
	var fit_scale := minf(available_size.x / maxf(float(source_image.get_width()), 1.0), available_size.y / maxf(float(source_image.get_height()), 1.0))
	var display_size := Vector2(source_image.get_width(), source_image.get_height()) * fit_scale
	image_rect = Rect2((size - display_size) * 0.5, display_size)
	draw_texture_rect(source_texture, image_rect, false)
	var crop_screen_rect := Rect2(
		image_rect.position + crop_rect.position * image_rect.size,
		crop_rect.size * image_rect.size
	)
	var overlay_color := Color(0.0, 0.0, 0.0, 0.48)
	draw_rect(Rect2(image_rect.position, Vector2(image_rect.size.x, crop_screen_rect.position.y - image_rect.position.y)), overlay_color, true)
	draw_rect(Rect2(Vector2(image_rect.position.x, crop_screen_rect.end.y), Vector2(image_rect.size.x, image_rect.end.y - crop_screen_rect.end.y)), overlay_color, true)
	draw_rect(Rect2(Vector2(image_rect.position.x, crop_screen_rect.position.y), Vector2(crop_screen_rect.position.x - image_rect.position.x, crop_screen_rect.size.y)), overlay_color, true)
	draw_rect(Rect2(Vector2(crop_screen_rect.end.x, crop_screen_rect.position.y), Vector2(image_rect.end.x - crop_screen_rect.end.x, crop_screen_rect.size.y)), overlay_color, true)
	draw_rect(crop_screen_rect, Color("#f2c94c"), false, 2.0)
