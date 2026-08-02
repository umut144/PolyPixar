class_name MotionPhaseMarks
extends Control

var marker_phases: Array[float] = []


func _ready() -> void:
	custom_minimum_size = Vector2(220, 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_marker_phases(values: Array) -> void:
	marker_phases.clear()
	for value in values:
		marker_phases.append(clampf(float(value), 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0:
		return
	draw_line(Vector2(0.0, 1.0), Vector2(size.x, 1.0), Color("#4a5362"), 1.0)
	for phase in marker_phases:
		var x := phase * size.x
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color("#f2c94c"), 2.0)
