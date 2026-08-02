class_name MotionSequenceWorkspace
extends Control

signal entry_selected(entry_id: String)
signal add_entry_requested()

const VIEW_COMPOSITION := "composition"
const VIEW_PLAYER := "player"

var sequence_document: Dictionary = {}
var selected_entry_id := ""
var view_mode := VIEW_COMPOSITION
var asset: Dictionary = {}
var path_document: Dictionary = {}
var phase := 0.0
var playing := false
var card_rect := Rect2()
var add_rect := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	queue_redraw()


func set_context(sequence_value: Dictionary, entry_id: String, asset_value: Dictionary, path_value: Dictionary) -> void:
	sequence_document = sequence_value.duplicate(true)
	selected_entry_id = entry_id
	asset = asset_value.duplicate(true)
	path_document = path_value.duplicate(true)
	queue_redraw()


func set_view_mode(value: String) -> void:
	view_mode = value if value in [VIEW_COMPOSITION, VIEW_PLAYER] else VIEW_COMPOSITION
	queue_redraw()


func set_runtime(value_phase: float, value_playing: bool) -> void:
	phase = clampf(value_phase, 0.0, 1.0)
	playing = value_playing
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed or view_mode != VIEW_COMPOSITION:
		return
	grab_focus()
	if card_rect.has_point(event.position):
		var entry := _entry()
		if not entry.is_empty():
			entry_selected.emit(str(entry.get("id", "")))
	elif add_rect.has_point(event.position):
		add_entry_requested.emit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#171b22"), true)
	var title := str(sequence_document.get("name", "Motion → Sequence"))
	draw_string(ThemeDB.fallback_font, Vector2(18.0, 28.0), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 36.0, 15, Color("#d6dbe4"))
	if sequence_document.is_empty():
		_draw_centered_text("Select or create a Sequence.")
	elif view_mode == VIEW_PLAYER:
		_draw_player()
	else:
		_draw_composition()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#3a424f"), false, 1.0)


func _draw_composition() -> void:
	card_rect = Rect2(34.0, 76.0, minf(420.0, size.x - 68.0), 116.0)
	add_rect = Rect2(34.0, 214.0, minf(180.0, size.x - 68.0), 38.0)
	var entry := _entry()
	if entry.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(34.0, 102.0), "No Composition Entry", HORIZONTAL_ALIGNMENT_LEFT, card_rect.size.x, 13, Color("#737f91"))
	else:
		var selected := str(entry.get("id", "")) == selected_entry_id
		draw_rect(card_rect, Color("#2c3036") if selected else Color("#202630"), true)
		draw_rect(card_rect, Color("#f2c94c") if selected else Color("#3a424f"), false, 2.0 if selected else 1.0)
		draw_string(ThemeDB.fallback_font, card_rect.position + Vector2(14.0, 25.0), str(entry.get("name", "Entry")), HORIZONTAL_ALIGNMENT_LEFT, card_rect.size.x - 28.0, 14, Color("#f2c94c") if selected else Color("#d6dbe4"))
		draw_string(ThemeDB.fallback_font, card_rect.position + Vector2(14.0, 54.0), "%s · %s · %s" % [_asset_name(), _state_name(), str(path_document.get("name", "Missing Path"))], HORIZONTAL_ALIGNMENT_LEFT, card_rect.size.x - 28.0, 12, Color("#b6becb"))
		var issues := MotionSequenceEvaluator.validation_issues(entry, asset, path_document)
		draw_string(ThemeDB.fallback_font, card_rect.position + Vector2(14.0, 88.0), "Asset ✓   Animation ✓   Path ✓" if issues.is_empty() else "Incomplete · %s" % issues[0], HORIZONTAL_ALIGNMENT_LEFT, card_rect.size.x - 28.0, 11, Color("#75b88a") if issues.is_empty() else Color("#f2c94c"))
	if entry.is_empty():
		draw_rect(add_rect, Color("#252b35"), true)
		draw_rect(add_rect, Color("#4a5362"), false, 1.0)
		draw_string(ThemeDB.fallback_font, add_rect.position + Vector2(0.0, 25.0), "+ Add Entry", HORIZONTAL_ALIGNMENT_CENTER, add_rect.size.x, 12, Color("#d6dbe4"))
	else:
		add_rect = Rect2()
	draw_string(ThemeDB.fallback_font, Vector2(34.0, size.y - 26.0), "Composition references resources by stable ID · no timeline", HORIZONTAL_ALIGNMENT_LEFT, size.x - 68.0, 11, Color("#596474"))


func _draw_player() -> void:
	card_rect = Rect2()
	add_rect = Rect2()
	var entry := _entry()
	var snapshot := MotionSequenceEvaluator.evaluate(entry, asset, path_document, phase)
	if not bool(snapshot.get("valid", false)):
		var issues: Array = snapshot.get("issues", [])
		_draw_centered_text(str(issues[0]) if not issues.is_empty() else "Sequence is not ready for playback.")
		return
	var path_points := MotionPathSampler.sampled_points(path_document.get("topology", {}))
	var asset_paths := _asset_paths()
	if path_points.size() < 2 or asset_paths.is_empty():
		_draw_centered_text("The resolved Entry has no previewable geometry.")
		return
	var asset_bounds := _paths_bounds(asset_paths)
	var path_bounds := _vector_bounds(path_points)
	var half_asset_extent := asset_bounds.size * 0.5
	var framing_bounds := path_bounds.grow(half_asset_extent.length() + 1.0)
	var drawing_rect := Rect2(28.0, 50.0, maxf(1.0, size.x - 56.0), maxf(1.0, size.y - 88.0))
	var fit_scale := minf(drawing_rect.size.x / maxf(1.0, framing_bounds.size.x), drawing_rect.size.y / maxf(1.0, framing_bounds.size.y))
	var target_center := drawing_rect.get_center()
	var path_screen := PackedVector2Array()
	for point in path_points:
		path_screen.append(target_center + _world_offset(Vector2(point) - framing_bounds.get_center(), fit_scale))
	draw_polyline(path_screen, Color("#f2c94c88"), 2.0, true)
	var path_position: Vector2 = snapshot.get("path_position", Vector2.ZERO)
	var path_rotation := deg_to_rad(float(snapshot.get("path_rotation", 0.0)))
	var component_samples: Dictionary = snapshot.get("component_samples", {})
	for path_data in asset_paths:
		var screen_points := PackedVector2Array()
		var component_id := str(path_data.get("component_id", ""))
		var component_origin: Vector2 = path_data.get("component_origin", Vector2.ZERO)
		var component_sample: Dictionary = component_samples.get(component_id, MotionSampler.identity_transform())
		for raw_point in path_data.get("points", []):
			var animated := MotionAssetPreview._apply_preview_transform(Vector2(raw_point), component_origin, component_sample)
			var placed := path_position + (animated - asset_bounds.get_center()).rotated(path_rotation)
			screen_points.append(target_center + _world_offset(placed - framing_bounds.get_center(), fit_scale))
		if bool(path_data.get("closed", false)) and screen_points.size() >= 3:
			draw_colored_polygon(screen_points, Color("#6f87aa44"))
		if screen_points.size() >= 2:
			draw_polyline(screen_points, Color("#c1cee1"), 1.7, true)
	var footer := "%s · Sequence %.2f · Path %.2f · Animation %.2f · %s" % [str(snapshot.get("state_name", "State")), phase, float(snapshot.get("path_phase", 0.0)), float(snapshot.get("animation_phase", 0.0)), "Playing" if playing else "Paused"]
	draw_string(ThemeDB.fallback_font, Vector2(12.0, size.y - 10.0), footer, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 11, Color("#9aa3b2"))


func _entry() -> Dictionary:
	var entries: Array = sequence_document.get("entries", [])
	if entries.is_empty():
		return {}
	if not selected_entry_id.is_empty():
		for entry in entries:
			if str(entry.get("id", "")) == selected_entry_id:
				return entry
	return entries[0]


func _asset_name() -> String:
	return str(asset.get("name", "Missing Asset"))


func _state_name() -> String:
	var state_id := str(_entry().get("animation_state_id", ""))
	for state in asset.get("animation", {}).get("states", []):
		if str(state.get("id", "")) == state_id:
			return str(state.get("name", "State"))
	return "Missing State"


func _asset_paths() -> Array:
	var paths: Array = []
	for component in asset.get("components", []):
		if not bool(component.get("visibility", true)):
			continue
		var points: Array = component.get("points", []).duplicate(true)
		var chains: Array = component.get("chains", []).duplicate(true)
		BezierGeometry.resolve_auto_handles(points, chains)
		var points_by_id: Dictionary = {}
		for point in points:
			points_by_id[str(point.get("id", ""))] = point
		for chain in chains:
			var sampled := _sample_asset_chain(points_by_id, chain, component.get("transform", {}))
			if not sampled.is_empty():
				paths.append({"points": sampled, "closed": bool(chain.get("closed", false)), "component_id": str(component.get("id", "")), "component_origin": Vector2(component.get("transform", {}).get("position", Vector2.ZERO))})
	return paths


func _sample_asset_chain(points_by_id: Dictionary, chain: Dictionary, transform: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	var point_ids: Array = chain.get("point_ids", [])
	if point_ids.size() < 2:
		return result
	var segment_count := point_ids.size() if bool(chain.get("closed", false)) else point_ids.size() - 1
	for segment_index in range(segment_count):
		var start: Dictionary = points_by_id.get(str(point_ids[segment_index]), {})
		var end: Dictionary = points_by_id.get(str(point_ids[(segment_index + 1) % point_ids.size()]), {})
		for sample_index in range(17):
			if segment_index > 0 and sample_index == 0:
				continue
			var local_point := MotionPathSampler.cubic_point(start, end, float(sample_index) / 16.0)
			var pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
			var scale: Vector2 = transform.get("scale", Vector2.ONE)
			var rotation := deg_to_rad(float(transform.get("rotation", 0.0)))
			result.append(Vector2(transform.get("position", Vector2.ZERO)) + ((local_point - pivot) * scale).rotated(rotation))
	return result


func _paths_bounds(paths: Array) -> Rect2:
	var values: Array[Vector2] = []
	for path_data in paths:
		for point in path_data.get("points", []):
			values.append(Vector2(point))
	return _vector_bounds(values)


func _vector_bounds(values: Array) -> Rect2:
	var initialized := false
	var minimum := Vector2.ZERO
	var maximum := Vector2.ZERO
	for raw_value in values:
		var value := Vector2(raw_value)
		if not initialized:
			minimum = value
			maximum = value
			initialized = true
		else:
			minimum = minimum.min(value)
			maximum = maximum.max(value)
	return Rect2(minimum, maximum - minimum)


func _world_offset(value: Vector2, scale: float) -> Vector2:
	return Vector2(value.x, -value.y) * scale


func _draw_centered_text(text: String) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(0.0, size.y * 0.5), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color("#737f91"))
