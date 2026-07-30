class_name ReferenceImageCropDialog
extends Window

signal image_accepted(image: Image)
signal image_cropped(image: Image)

var crop_view: ReferenceImageCropView


func _ready() -> void:
	hide()
	close_requested.connect(_on_cancel_pressed)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 8)
	layout.add_theme_constant_override("margin_left", 12)
	layout.add_theme_constant_override("margin_top", 12)
	layout.add_theme_constant_override("margin_right", 12)
	layout.add_theme_constant_override("margin_bottom", 12)
	add_child(layout)
	var hint := Label.new()
	hint.text = "Optional: drag a rectangle around the part you want to use."
	hint.add_theme_color_override("font_color", Color("#aab3c2"))
	layout.add_child(hint)
	crop_view = ReferenceImageCropView.new()
	crop_view.custom_minimum_size = Vector2(640, 420)
	crop_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crop_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(crop_view)
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 8)
	layout.add_child(button_row)
	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_row.add_child(cancel_button)
	var continue_button := Button.new()
	continue_button.text = "Continue"
	continue_button.focus_mode = Control.FOCUS_NONE
	continue_button.pressed.connect(_on_continue_pressed)
	button_row.add_child(continue_button)
	var crop_button := Button.new()
	crop_button.text = "Apply Crop"
	crop_button.focus_mode = Control.FOCUS_NONE
	crop_button.pressed.connect(_on_crop_pressed)
	button_row.add_child(crop_button)


func open_for_image(image: Image) -> void:
	if not is_node_ready():
		await ready
	crop_view.set_image(image)
	popup_centered(Vector2i(720, 560))


func _on_continue_pressed() -> void:
	if crop_view.source_image == null:
		return
	image_accepted.emit(crop_view.source_image.duplicate())
	hide()


func _on_crop_pressed() -> void:
	var cropped_image := crop_view.get_cropped_image()
	if cropped_image == null:
		return
	image_cropped.emit(cropped_image)
	hide()


func _on_cancel_pressed() -> void:
	hide()
