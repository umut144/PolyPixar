class_name SemanticPicker
extends VBoxContainer

signal selection_changed(key: String)

var search_input: LineEdit
var list: ItemList
var prompt_label: Label
var keys: Array[String] = []
var excluded_keys: Dictionary = {}
var selected_key := ""


func _init() -> void:
	add_theme_constant_override("separation", 4)
	prompt_label = Label.new()
	prompt_label.visible = false
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(prompt_label)
	search_input = LineEdit.new()
	search_input.placeholder_text = "Search semantics…"
	search_input.custom_minimum_size = Vector2(0, 28)
	search_input.text_changed.connect(_render_items)
	add_child(search_input)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(0, 150)
	list.select_mode = ItemList.SELECT_SINGLE
	list.item_selected.connect(_on_item_selected)
	add_child(list)


func set_prompt(value: String) -> void:
	prompt_label.text = value
	prompt_label.visible = not value.is_empty()


func configure(available_keys: Array[String], current_key := "", excluded: Array = []) -> void:
	keys = available_keys.duplicate()
	keys.sort()
	excluded_keys.clear()
	for key in excluded:
		excluded_keys[key] = true
	selected_key = current_key if current_key in keys and not excluded_keys.has(current_key) else ""
	search_input.text = ""
	_render_items("")


func focus_search() -> void:
	search_input.grab_focus()


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
	selection_changed.emit(selected_key)
