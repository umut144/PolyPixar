class_name BatchStatusButton
extends Button

const ATTENTION_COLOR := Color("#f2994a")
const ATTENTION_BORDER_COLOR := Color("#3a3420")
const DOT_CENTER_OFFSET := Vector2(9.0, 8.0)
const DOT_BORDER_RADIUS := 5.0
const DOT_RADIUS := 3.5

var attention_count := 0


func set_attention_count(value: int) -> void:
	var normalized := maxi(value, 0)
	if attention_count == normalized:
		return
	attention_count = normalized
	queue_redraw()


func _draw() -> void:
	if attention_count <= 0:
		return
	var center := Vector2(size.x - DOT_CENTER_OFFSET.x, DOT_CENTER_OFFSET.y)
	draw_circle(center, DOT_BORDER_RADIUS, ATTENTION_BORDER_COLOR)
	draw_circle(center, DOT_RADIUS, ATTENTION_COLOR)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()
