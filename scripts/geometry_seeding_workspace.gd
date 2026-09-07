class_name GeometrySeedingWorkspace
extends Control

## A Component Mesh is inspected at the scale it was authored at, and these are
## centimetres: a Stone chip measures a few tool units across, so the previous
## ceiling of 128 pixels per unit left it under a hundred pixels wide at full
## zoom - too small to judge a triangle by. The floor is unchanged; only getting
## closer was ever the problem.
const MIN_CAMERA_ZOOM := 0.05
const MAX_CAMERA_ZOOM := 1280.0
const CAMERA_ZOOM_STEP := 1.12

signal seed_add_requested(position: Vector2)
signal seed_move_started(seed_id: String)
signal seed_move_requested(seed_id: String, position: Vector2)
signal seed_move_finished(seed_id: String)
signal seed_remove_requested(seed_id: String)

const BACKGROUND := Color("#1b1e24")
const GRID_MINOR := Color("#252a33")
const GRID_MAJOR := Color("#303744")
const BOUNDARY_COLOR := Color("#7b8492")
const HOLE_COLOR := Color("#ef6c78")
const CUT_COLOR := Color("#ff7f8d")
const GUIDE_COLOR := Color("#f2c94c")
const GENERATED_COLOR := Color("#68d391")
const MANUAL_COLOR := Color("#ef8354")
const ADJUSTED_COLOR := Color("#63b3ed")

var sampling_bake: Dictionary = {}
var seeding_result: Dictionary = {}
var sampler_spines: Array[Dictionary] = []
var selected_input_id := ""
var status := "Sampling Required"
var editing_enabled := false
var edit_tool := "select"
var selected_seed_id := ""
var dragging_seed := false
var camera_position := Vector2.ZERO
var camera_zoom := 1.0
var fitted := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_unhandled_key_input(true)
	queue_redraw()


func set_context(sampling_data: Dictionary, seeding_data: Dictionary, guide_data: Array[Dictionary], status_value: String, can_edit: bool, tool: String, selected_input := "") -> void:
	var boundary_changed := sampling_bake != sampling_data
	sampling_bake = sampling_data.duplicate(true)
	seeding_result = seeding_data.duplicate(true)
	sampler_spines = guide_data.duplicate(true)
	selected_input_id = selected_input
	status = status_value
	editing_enabled = can_edit
	edit_tool = tool if tool in ["select", "add", "remove"] else "select"
	if _seed_by_id(selected_seed_id).is_empty():
		selected_seed_id = ""
		dragging_seed = false
	if boundary_changed:
		fitted = false
	queue_redraw()


func clear_context() -> void:
	sampling_bake = {}
	seeding_result = {}
	sampler_spines = []
	selected_input_id = ""
	status = "Sampling Required"
	editing_enabled = false
	selected_seed_id = ""
	dragging_seed = false
	fitted = false
	queue_redraw()


func delete_selected_seed() -> bool:
	if not editing_enabled or selected_seed_id.is_empty():
		return false
	seed_remove_requested.emit(selected_seed_id)
	selected_seed_id = ""
	queue_redraw()
	return true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and is_inside_tree():
			grab_focus()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(CAMERA_ZOOM_STEP)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(1.0 / CAMERA_ZOOM_STEP)
			return
		if event.button_index != MOUSE_BUTTON_LEFT or not editing_enabled:
			return
		if not event.pressed:
			if dragging_seed:
				seed_move_finished.emit(selected_seed_id)
			dragging_seed = false
			return
		var local_position := _to_local_position(event.position)
		if edit_tool == "add":
			seed_add_requested.emit(local_position)
		elif edit_tool == "remove":
			var remove_id := _nearest_seed_id(event.position)
			if not remove_id.is_empty():
				seed_remove_requested.emit(remove_id)
		elif edit_tool == "select":
			selected_seed_id = _nearest_seed_id(event.position)
			dragging_seed = not selected_seed_id.is_empty()
			if dragging_seed:
				seed_move_started.emit(selected_seed_id)
		queue_redraw()
	elif event is InputEventMouseMotion and dragging_seed and editing_enabled and edit_tool == "select":
		seed_move_requested.emit(selected_seed_id, _to_local_position(event.position))


func _unhandled_key_input(event: InputEvent) -> void:
	if not has_focus() or not event is InputEventKey or not event.pressed or event.echo or event.meta_pressed or event.ctrl_pressed:
		return
	var pan_step := 24.0 / maxf(camera_zoom, 0.0001)
	match event.keycode:
		KEY_A:
			camera_position.x -= pan_step
		KEY_D:
			camera_position.x += pan_step
		KEY_W:
			camera_position.y += pan_step
		KEY_S:
			camera_position.y -= pan_step
		KEY_Q:
			_zoom_by(1.0 / CAMERA_ZOOM_STEP)
		KEY_E:
			_zoom_by(CAMERA_ZOOM_STEP)
		_:
			return
	fitted = true
	queue_redraw()
	get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	_draw_grid()
	if sampling_bake.is_empty():
		_draw_centered_message("Bake Sampling before Seeding")
		return
	if not fitted:
		_fit_boundary()
	_draw_boundaries()
	_draw_sampler_spine()
	_draw_seeds()
	draw_string(ThemeDB.fallback_font, Vector2(10.0, 20.0), "Mesh → Seeding · %s" % status, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#9aa3b2"))


func _draw_grid() -> void:
	var step := maxf(16.0, 32.0 * camera_zoom)
	var offset := Vector2(fposmod(size.x * 0.5 - camera_position.x * camera_zoom, step), fposmod(size.y * 0.5 + camera_position.y * camera_zoom, step))
	var x := offset.x
	var column := 0
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), GRID_MAJOR if column % 4 == 0 else GRID_MINOR, 1.0)
		x += step
		column += 1
	var y := offset.y
	var row := 0
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), GRID_MAJOR if row % 4 == 0 else GRID_MINOR, 1.0)
		y += step
		row += 1


func _fit_boundary() -> void:
	var positions: Array[Vector2] = []
	for chain_data in sampling_bake.get("chains", []):
		for sample in chain_data.get("samples", []):
			if sample is Dictionary:
				positions.append(Vector2(sample.get("position", Vector2.ZERO)))
	for cut_data in sampling_bake.get("cuts", []):
		for fragment in GeometrySamplingService.cut_fragments(cut_data):
			for sample in fragment.get("samples", []):
				if sample is Dictionary:
					positions.append(Vector2(sample.get("position", Vector2.ZERO)))
	if positions.is_empty():
		camera_position = Vector2.ZERO
		camera_zoom = 1.0
		fitted = true
		return
	var bounds := Rect2(positions[0], Vector2.ZERO)
	for sample_position in positions:
		bounds = bounds.expand(sample_position)
	camera_position = bounds.get_center()
	var available := Vector2(maxf(size.x - 96.0, 1.0), maxf(size.y - 96.0, 1.0))
	var extent := Vector2(maxf(bounds.size.x, 1.0), maxf(bounds.size.y, 1.0))
	camera_zoom = clampf(minf(available.x / extent.x, available.y / extent.y), MIN_CAMERA_ZOOM, MAX_CAMERA_ZOOM)
	fitted = true


func _draw_boundaries() -> void:
	for chain_data in sampling_bake.get("chains", []):
		var samples: Array = chain_data.get("samples", [])
		if samples.size() < 2:
			continue
		var role := WorldDocumentService.topology_role(chain_data)
		var input_id := str(chain_data.get("input_id", ""))
		var color := HOLE_COLOR if role == WorldDocumentService.ROLE_HOLE else BOUNDARY_COLOR
		var width := 3.0 if not input_id.is_empty() and input_id == selected_input_id else 1.5
		for sample_index in range(samples.size()):
			var current := _to_screen(Vector2(samples[sample_index].get("position", Vector2.ZERO)))
			var next_index := sample_index + 1
			if next_index >= samples.size():
				if not bool(chain_data.get("closed", false)):
					continue
				next_index = 0
			var next := _to_screen(Vector2(samples[next_index].get("position", Vector2.ZERO)))
			draw_line(current, next, color, width, true)
	for cut_data in sampling_bake.get("cuts", []):
		if not cut_data is Dictionary or not bool(cut_data.get("valid", false)):
			continue
		var guide_id := str(cut_data.get("guide_id", ""))
		var width := 3.0 if guide_id == selected_input_id else 1.5
		for fragment in GeometrySamplingService.cut_fragments(cut_data):
			var samples: Array = fragment.get("samples", [])
			for sample_index in range(samples.size() - 1):
				draw_dashed_line(_to_screen(Vector2(samples[sample_index].get("position", Vector2.ZERO))), _to_screen(Vector2(samples[sample_index + 1].get("position", Vector2.ZERO))), CUT_COLOR, width, 6.0, true)


func _draw_sampler_spine() -> void:
	for spine_index in range(sampler_spines.size()):
		var sampler_spine := sampler_spines[spine_index]
		if sampler_spine.get("chains", []).is_empty():
			continue
		var resolved := sampler_spine.duplicate(true)
		BezierGeometry.resolve_auto_handles(resolved.get("points", []), resolved.get("chains", []))
		var polyline := BezierGeometry.flatten_chain(resolved, resolved.get("chains", [])[0], 32)
		var color := GUIDE_COLOR.lightened(minf(float(spine_index) * 0.08, 0.28))
		var width := 4.0 if str(sampler_spine.get("id", "")) == selected_input_id else 2.0
		for index in range(polyline.size() - 1):
			draw_line(_to_screen(polyline[index]), _to_screen(polyline[index + 1]), color, width, true)


func _draw_seeds() -> void:
	if not bool(seeding_result.get("valid", false)):
		return
	for seed_data in seeding_result.get("seeds", []):
		if not seed_data is Dictionary:
			continue
		var seed_id := str(seed_data.get("id", ""))
		var origin := str(seed_data.get("origin", "generated"))
		var color := GENERATED_COLOR
		var provenance: Dictionary = seed_data.get("provenance", {})
		if str(provenance.get("placement", "")) == "flow":
			var guide_order := int(provenance.get("guide_order", 0))
			color = GUIDE_COLOR.lightened(minf(float(guide_order) * 0.08, 0.28))
		if origin == "manual":
			color = MANUAL_COLOR
		elif origin == "manual_adjusted":
			color = ADJUSTED_COLOR
		if seed_id == selected_seed_id:
			color = Color.WHITE
		draw_circle(_to_screen(Vector2(seed_data.get("position", Vector2.ZERO))), 5.0 if seed_id == selected_seed_id else 3.5, color)


func _nearest_seed_id(screen_position: Vector2) -> String:
	var nearest_id := ""
	var nearest_distance := 11.0
	for seed_data in seeding_result.get("seeds", []):
		if not seed_data is Dictionary:
			continue
		var distance := screen_position.distance_to(_to_screen(Vector2(seed_data.get("position", Vector2.ZERO))))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = str(seed_data.get("id", ""))
	return nearest_id


func _seed_by_id(seed_id: String) -> Dictionary:
	for seed_data in seeding_result.get("seeds", []):
		if seed_data is Dictionary and str(seed_data.get("id", "")) == seed_id:
			return seed_data
	return {}


func _to_screen(local_position: Vector2) -> Vector2:
	var relative := local_position - camera_position
	return Vector2(size.x * 0.5 + relative.x * camera_zoom, size.y * 0.5 - relative.y * camera_zoom)


func _to_local_position(screen_position: Vector2) -> Vector2:
	return camera_position + Vector2((screen_position.x - size.x * 0.5) / camera_zoom, -(screen_position.y - size.y * 0.5) / camera_zoom)


func _draw_centered_message(message: String) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(0.0, size.y * 0.5), message, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color("#737f91"))


## One place decides how far the camera may come in, so the wheel, the keyboard
## and the initial fit cannot drift apart.
func _zoom_by(factor: float) -> void:
	camera_zoom = clampf(camera_zoom * factor, MIN_CAMERA_ZOOM, MAX_CAMERA_ZOOM)
	fitted = true
	queue_redraw()
