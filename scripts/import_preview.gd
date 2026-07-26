class_name ImportPreview
extends Control

var preview_texture: Texture2D
var preview_path := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func set_preview_path(path: String) -> void:
	if path == preview_path:
		return
	preview_path = path
	preview_texture = null
	if not path.is_empty() and FileAccess.file_exists(path):
		var image := Image.new()
		var load_error := image.load(path)
		if load_error == OK and not image.is_empty():
			preview_texture = ImageTexture.create_from_image(image)
	queue_redraw()


func set_preview_image(image: Image) -> void:
	preview_path = ""
	preview_texture = null
	if image != null and not image.is_empty():
		preview_texture = ImageTexture.create_from_image(image)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#161a20"), true)
	if preview_texture == null:
		return
	var source_size := preview_texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var available_size := size - Vector2(48.0, 48.0)
	var fit_scale := minf(available_size.x / source_size.x, available_size.y / source_size.y)
	fit_scale = maxf(fit_scale, 0.01)
	var preview_size := source_size * fit_scale
	var preview_rect := Rect2((size - preview_size) * 0.5, preview_size)
	draw_rect(preview_rect.grow(1.0), Color("#697383"), false, 2.0)
	draw_texture_rect(preview_texture, preview_rect, false)
