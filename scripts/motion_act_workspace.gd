class_name MotionActWorkspace
extends HSplitContainer

signal act_selected(act_id: String)
signal add_primitive_requested(primitive: String)

var acts: Array[Dictionary] = []
var selected_act_id := ""
var preview_asset: Dictionary = {}
var list_content: VBoxContainer
var preview: MotionActPreview


func _ready() -> void:
	add_theme_constant_override("separation", 1)
	_build_ui()
	preview.set_context(_selected_act(), preview_asset)
	call_deferred("_apply_split")


func set_context(act_values: Array[Dictionary], selected_id: String, asset_value: Dictionary) -> void:
	acts = act_values.duplicate(true)
	selected_act_id = selected_id
	preview_asset = asset_value.duplicate(true)
	_rebuild_list()
	if is_instance_valid(preview):
		preview.set_context(_selected_act(), preview_asset)


func set_runtime(phase: float, playing: bool) -> void:
	if is_instance_valid(preview):
		preview.set_runtime(phase, playing)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_split()


func _build_ui() -> void:
	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(180.0, 0.0)
	add_child(list_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_child(scroll)
	list_content = VBoxContainer.new()
	list_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_content.add_theme_constant_override("separation", 4)
	scroll.add_child(list_content)
	preview = MotionActPreview.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(preview)
	_rebuild_list()


func _rebuild_list() -> void:
	if not is_instance_valid(list_content):
		return
	for child in list_content.get_children():
		child.queue_free()
	var heading := Label.new()
	heading.text = "Acts"
	heading.custom_minimum_size = Vector2(0.0, 30.0)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color("#d6dbe4"))
	list_content.add_child(heading)
	for act in acts:
		var button := Button.new()
		button.text = str(act.get("name", "Slide"))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0.0, 44.0)
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.button_pressed = str(act.get("id", "")) == selected_act_id
		button.pressed.connect(act_selected.emit.bind(str(act.get("id", ""))))
		list_content.add_child(button)
	var add_menu := MenuButton.new()
	add_menu.text = "+"
	add_menu.tooltip_text = "Add Act"
	add_menu.custom_minimum_size = Vector2(0.0, 38.0)
	add_menu.focus_mode = Control.FOCUS_NONE
	for primitive in MotionActEvaluator.primitive_definitions():
		add_menu.get_popup().add_item(str(primitive.get("label", "Act")))
		add_menu.get_popup().set_item_metadata(add_menu.get_popup().item_count - 1, str(primitive.get("id", "")))
	add_menu.get_popup().index_pressed.connect(func(index: int) -> void:
		add_primitive_requested.emit(str(add_menu.get_popup().get_item_metadata(index)))
	)
	list_content.add_child(add_menu)


func _selected_act() -> Dictionary:
	for act in acts:
		if str(act.get("id", "")) == selected_act_id:
			return act
	return {}


func _apply_split() -> void:
	var desired := maxi(180, int(size.x * 0.25))
	if split_offset != desired:
		split_offset = desired
