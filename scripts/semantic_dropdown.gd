class_name SemanticDropdown
extends Button

signal selection_changed(key: String)

var popup_panel: PopupPanel
var search_input: LineEdit
var list: ItemList
var keys: Array[String] = []
var excluded_keys: Dictionary = {}
var selected_key := ""
var empty_text := "Select Semantic Key…"


func _init() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size = Vector2(0, 30)
	pressed.connect(_open_popup)
	popup_panel = PopupPanel.new()
	popup_panel.transparent_bg = false
	add_child(popup_panel)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(280, 220)
	content.add_theme_constant_override("separation", 4)
	popup_panel.add_child(content)
	search_input = LineEdit.new()
	search_input.placeholder_text = "Search semantics…"
	search_input.custom_minimum_size = Vector2(0, 30)
	search_input.text_changed.connect(_render_items)
	content.add_child(search_input)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(0, 180)
	list.select_mode = ItemList.SELECT_SINGLE
	list.item_selected.connect(_on_item_selected)
	content.add_child(list)
	_update_button_text()


func configure(available_keys: Array[String], current_key := "", excluded: Array = []) -> void:
	keys = available_keys.duplicate()
	keys.sort()
	excluded_keys.clear()
	for key in excluded:
		excluded_keys[str(key)] = true
	selected_key = current_key if current_key in keys and not excluded_keys.has(current_key) else ""
	search_input.text = ""
	_render_items("")
	_update_button_text()


func _open_popup() -> void:
	if not is_inside_tree():
		return
	var popup_size := Vector2i(maxi(280, int(size.x)), 230)
	var popup_position := Vector2i(global_position + Vector2(0.0, size.y + 2.0))
	popup_panel.popup(Rect2i(popup_position, popup_size))
	search_input.grab_focus()
	search_input.select_all()


func _render_items(filter_text: String) -> void:
	list.clear()
	var normalized_filter := filter_text.strip_edges().to_lower()
	var selected_index := -1
	for key in keys:
		if excluded_keys.has(key) or not normalized_filter.is_empty() and not key.contains(normalized_filter):
			continue
		list.add_item(key)
		list.set_item_metadata(list.item_count - 1, key)
		if key == selected_key:
			selected_index = list.item_count - 1
	if selected_index >= 0:
		list.select(selected_index)


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= list.item_count:
		return
	selected_key = str(list.get_item_metadata(index))
	_update_button_text()
	popup_panel.hide()
	selection_changed.emit(selected_key)


func _update_button_text() -> void:
	text = "%s  ▾" % (selected_key if not selected_key.is_empty() else empty_text)
