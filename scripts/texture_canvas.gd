class_name TextureCanvas
extends Control

signal origin_changed(mode: String)

const ORIGIN_MODES := ["bottom_left", "top_left", "center"]

var origin_mode := "bottom_left"
var selected_element_name := ""
var view_offset := Vector2.ZERO
var zoom := 1.0
var final_texture: Texture2D
var final_texture_path := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		grab_focus()


func set_origin_mode(mode: String) -> void:
	if not ORIGIN_MODES.has(mode):
		mode = "bottom_left"
	origin_mode = mode
	origin_changed.emit(origin_mode)
	queue_redraw()


func set_selected_element(element_name: String) -> void:
	selected_element_name = element_name
	queue_redraw()


func set_final_texture_path(path: String) -> void:
	if path == final_texture_path:
		return
	final_texture_path = path
	final_texture = null
	if not path.is_empty() and FileAccess.file_exists(path):
		var image := Image.new()
		var load_error := image.load(path)
		if load_error == OK and not image.is_empty():
			final_texture = ImageTexture.create_from_image(image)
	queue_redraw()


func _process(delta: float) -> void:
	if not has_focus():
		return
	if Input.is_key_pressed(KEY_META) or Input.is_key_pressed(KEY_CTRL):
		queue_redraw()
		return
	var pan_input := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	if pan_input.length_squared() > 0.0:
		view_offset -= pan_input.normalized() * 420.0 * delta / zoom
	var zoom_input := float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))
	if not is_zero_approx(zoom_input):
		zoom = clampf(zoom * pow(1.8, zoom_input * delta), 0.25, 8.0)
	queue_redraw()


func _draw() -> void:
	var canvas_size := minf(size.x, size.y) * 0.72 * zoom
	var canvas_origin := size * 0.5 + view_offset - Vector2(canvas_size, canvas_size) * 0.5
	var canvas_rect := Rect2(canvas_origin, Vector2(canvas_size, canvas_size))
	draw_rect(canvas_rect, Color("#f5f6f8"), true)
	if final_texture != null:
		draw_texture_rect(final_texture, canvas_rect, false)
	draw_rect(canvas_rect, Color("#697383"), false, 2.0)
	for index in range(1, 4):
		var fraction := float(index) / 4.0
		var x := canvas_rect.position.x + canvas_size * fraction
		var y := canvas_rect.position.y + canvas_size * fraction
		draw_line(Vector2(x, canvas_rect.position.y), Vector2(x, canvas_rect.end.y), Color("#d8dde5"), 1.0)
		draw_line(Vector2(canvas_rect.position.x, y), Vector2(canvas_rect.end.x, y), Color("#d8dde5"), 1.0)
	var horizontal_y := canvas_rect.end.y if origin_mode == "bottom_left" else canvas_rect.position.y if origin_mode == "top_left" else canvas_rect.get_center().y
	var vertical_x := canvas_rect.position.x if origin_mode != "center" else canvas_rect.get_center().x
	var origin := Vector2(vertical_x, horizontal_y)
	var u_color := Color("#d9828b")
	var v_color := Color("#75b88a")
	var u_direction := Vector2.RIGHT
	var v_direction := Vector2.UP if origin_mode != "top_left" else Vector2.DOWN
	draw_line(origin, origin + u_direction * 28.0, u_color, 3.0)
	draw_line(origin, origin + v_direction * 28.0, v_color, 3.0)
	draw_circle(origin, 4.0, Color("#d8dde5"))
	draw_string(ThemeDB.fallback_font, origin + u_direction * 32.0 + Vector2(-2, 4), "U", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, u_color)
	draw_string(ThemeDB.fallback_font, origin + v_direction * 32.0 + Vector2(-3, 4), "V", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, v_color)
	draw_string(ThemeDB.fallback_font, canvas_rect.position + Vector2(8, 20), "UV 0..1", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#697482"))
	draw_string(ThemeDB.fallback_font, Vector2(canvas_rect.position.x, canvas_rect.end.y + 20), "Origin: %s" % origin_mode.replace("_", " ").capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#707985"))
