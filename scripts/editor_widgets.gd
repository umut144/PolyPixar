class_name EditorWidgets
extends RefCounted

# The editor's shared widget vocabulary: panels, labels, section headers,
# buttons and their styling. Every panel builds its controls from these, so
# they live apart from main.gd rather than inside it.
#
# Purely constructive. Nothing here reads editor state or knows what a World,
# an Asset or a Component is; callers pass in the text and the flags.


const REGION_COLORS := {
	"attack": Color("#ef6c78"),
	"hurt": Color("#68d391"),
	"collision": Color("#f2994a")
}


static func create_panel(background_color := Color("#20242c")) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = Color("#363d48")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	panel.add_theme_stylebox_override("panel", style)
	return panel

static func create_panel_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(0, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#9aa3b2"))
	return label

static func create_inspector_section(text: String, on_toggled: Callable) -> VBoxContainer:
	# The collapse handler is a parameter, not a hidden reference back into the
	# editor: these factories stay purely constructive.
	var section := VBoxContainer.new()
	section.set_meta("inspector_section", true)
	section.add_theme_constant_override("separation", 0)
	var separator := HSeparator.new()
	separator.modulate = Color("#3a424f")
	section.add_child(separator)
	var header := Button.new()
	header.text = "▾  %s" % text
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.custom_minimum_size = Vector2(0, 24)
	header.focus_mode = Control.FOCUS_NONE
	header.toggle_mode = true
	header.button_pressed = true
	header.flat = true
	header.add_theme_font_size_override("font_size", 10)
	header.add_theme_color_override("font_color", Color("#c0c8d5"))
	header.add_theme_color_override("font_hover_color", Color("#ffffff"))
	header.pressed.connect(on_toggled.bind(section, text, header))
	section.add_child(header)
	return section

static func create_inspector_field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(0, 18)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#7f8a9b"))
	return label

static func create_status_region() -> PanelContainer:
	var region := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#20242c")
	style.border_color = Color("#363d48")
	style.set_border_width_all(1)
	region.add_theme_stylebox_override("panel", style)
	return region

static func create_snap_slider(minimum: float, maximum: float, step: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(220, 20)
	return slider

static func opaque_popup_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#20242c")
	style.border_color = Color("#363d48")
	style.set_border_width_all(1)
	return style

static func style_popup_menu(popup: PopupMenu) -> void:
	popup.add_theme_stylebox_override("panel", opaque_popup_style())

static func style_context_command_button(button: BaseButton, active: bool) -> void:
	button.toggle_mode = true
	button.set_pressed_no_signal(active)
	if button is MenuButton:
		(button as MenuButton).flat = not active
	elif button is Button:
		(button as Button).flat = not active
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = Color("#8fd8f5")
	active_style.border_color = Color("#c5efff")
	active_style.set_border_width_all(1)
	active_style.corner_radius_top_left = 3
	active_style.corner_radius_top_right = 3
	active_style.corner_radius_bottom_left = 3
	active_style.corner_radius_bottom_right = 3
	var active_text := Color("#10202a")
	if active:
		for style_name in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			button.add_theme_stylebox_override(style_name, active_style)
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(color_name, active_text)
	else:
		button.add_theme_stylebox_override("pressed", active_style)
		button.add_theme_stylebox_override("hover_pressed", active_style)
		button.add_theme_color_override("font_pressed_color", active_text)
		button.add_theme_color_override("font_hover_pressed_color", active_text)

static func create_outliner_group_label(text: String) -> Label:
	var label := create_panel_label(text)
	label.add_theme_color_override("font_color", Color("#737f91"))
	label.add_theme_font_size_override("font_size", 10)
	return label

static func create_visibility_checkbox(visibility_enabled: bool, callback: Callable) -> CheckBox:
	var checkbox := CheckBox.new()
	checkbox.custom_minimum_size = Vector2(26, 30)
	checkbox.focus_mode = Control.FOCUS_NONE
	checkbox.button_pressed = visibility_enabled
	checkbox.tooltip_text = "Visibility"
	checkbox.toggled.connect(callback)
	return checkbox

static func create_outliner_child_group_label(text: String, indent := 16) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var placeholder := Control.new()
	placeholder.custom_minimum_size = Vector2(indent, 0)
	row.add_child(placeholder)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(0, 24)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#737f91"))
	row.add_child(label)
	return row

static func create_geometry_role_badge(role: String) -> Label:
	var badge := Label.new()
	badge.text = role.capitalize()
	badge.custom_minimum_size = Vector2(42, 24)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 9)
	var normalized_role := role.to_lower()
	var badge_color := Color("#ef6c78") if normalized_role in ["hole", "cut"] else Color("#f2c94c") if normalized_role == "spine" else Color("#737f91")
	badge.add_theme_color_override("font_color", badge_color.lightened(0.35))
	return badge

static func style_region_outliner_button(button: Button, selected: bool, region_type := "attack") -> void:
	var color: Color = REGION_COLORS.get(region_type, REGION_COLORS["attack"])
	var normal := StyleBoxFlat.new()
	normal.bg_color = color if selected else color.darkened(0.68)
	normal.border_color = color.lightened(0.18) if selected else color.darkened(0.42)
	normal.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_color_override("font_color", Color("#f4f7ff") if selected else color.lightened(0.38))

static func style_outliner_button(button: Button, selected: bool, topology_role := WorldDocumentService.ROLE_OUTER) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#f2c94c") if selected else Color("#252a33")
	normal.border_color = Color("#f2c94c") if selected else Color("#303744")
	normal.set_border_width_all(1)
	var hover := normal.duplicate()
	hover.bg_color = Color("#ffe083") if selected else Color("#303744")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("#e7b936") if selected else Color("#394252")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	var text_color := Color("#ef6c78") if topology_role == WorldDocumentService.ROLE_HOLE else Color("#16181d") if selected else Color("#ffffff")
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", Color("#ef6c78") if topology_role == WorldDocumentService.ROLE_HOLE else Color("#16181d") if selected else Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ef6c78") if topology_role == WorldDocumentService.ROLE_HOLE else Color("#16181d"))
	button.add_theme_color_override("font_focus_color", text_color)

static func style_guide_outliner_button(button: Button, selected: bool, guide_type := AssetGuide.SAMPLER_SPINE) -> void:
	var guide_color := AssetGuide.color(guide_type)
	var normal := StyleBoxFlat.new()
	normal.bg_color = guide_color if selected else guide_color.darkened(0.55)
	normal.border_color = guide_color.lightened(0.2) if selected else guide_color.darkened(0.35)
	normal.set_border_width_all(1)
	var hover := normal.duplicate()
	hover.bg_color = guide_color.lightened(0.15) if selected else guide_color.darkened(0.4)
	var pressed := normal.duplicate()
	pressed.bg_color = guide_color.darkened(0.1) if selected else guide_color.darkened(0.3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	var selected_text_color := Color("#16181d") if guide_color.get_luminance() > 0.55 else Color("#f4f7ff")
	button.add_theme_color_override("font_color", selected_text_color if selected else guide_color.lightened(0.35))
	button.add_theme_color_override("font_hover_color", selected_text_color if selected else guide_color.lightened(0.55))
	button.add_theme_color_override("font_pressed_color", selected_text_color)
	button.add_theme_color_override("font_focus_color", selected_text_color if selected else guide_color.lightened(0.35))

static func create_motion_inspector_value(label_text: String, value_text: String) -> VBoxContainer:
	var field := VBoxContainer.new()
	field.add_theme_constant_override("separation", 1)
	field.add_child(create_inspector_field_label(label_text))
	var value := Label.new()
	value.text = value_text
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.add_theme_font_size_override("font_size", 11)
	value.add_theme_color_override("font_color", Color("#d6dbe4"))
	field.add_child(value)
	return field

static func create_name_editor(value: String, placeholder: String) -> LineEdit:
	var editor := LineEdit.new()
	editor.text = value
	editor.custom_minimum_size = Vector2(0, 26)
	editor.placeholder_text = placeholder
	editor.add_theme_font_size_override("font_size", 12)
	return editor

static func clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


static func clear_except(container: Node, kept: Node) -> void:
	# Used where a container holds one long-lived view next to content that is
	# rebuilt on every render.
	for child in container.get_children():
		if child != kept:
			child.queue_free()


static func strikethrough_text(text: String) -> String:
	var result := ""
	var strike_mark := String.chr(0x0336)
	for character in text:
		result += character + strike_mark
	return result

static func create_field_caption(text: String) -> Label:
	# The small grey caption that sits beside a numeric field in a grid.
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#7f8a9b"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


static func create_number_field(value: float, minimum: float, maximum: float, step: float, arrow_step: float, on_changed: Callable, suffix := "", silent := true, sized := true) -> SpinBox:
	# One numeric field for the whole Inspector. `silent` decides whether setting
	# the initial value fires value_changed, which a few callers rely on.
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.custom_arrow_step = arrow_step
	if not suffix.is_empty():
		field.suffix = suffix
	if silent:
		field.set_value_no_signal(value)
	else:
		field.value = value
	if sized:
		field.custom_minimum_size = Vector2(96, 26)
		field.add_theme_font_size_override("font_size", 11)
	if on_changed.is_valid():
		field.value_changed.connect(on_changed)
	return field

static func format_scale_value(value: float) -> String:
	# Four decimals with the trailing zeros trimmed, so 1.5000 reads as 1.5 and
	# 2.0000 as 2. It matches what a Scale field accepts: a Rebase preview that
	# rounded shorter would name a factor other than the one it bakes.
	var formatted := "%.4f" % value
	while formatted.ends_with("0"):
		formatted = formatted.substr(0, formatted.length() - 1)
	if formatted.ends_with("."):
		formatted = formatted.substr(0, formatted.length() - 1)
	return formatted


static func create_option_field(items: Array, selected_metadata: String, on_selected: Callable, sized := true) -> OptionButton:
	# The Inspector's dropdown: a list of {label, metadata} entries, optionally
	# with "disabled", and the entry whose metadata matches selected_metadata
	# preselected. Nothing is selected when none matches, which is what an
	# unresolvable reference should look like.
	#
	# The handler is bound to the button because every caller reads the choice
	# back through get_item_metadata(index).
	var option := OptionButton.new()
	var chosen := -1
	if sized:
		option.custom_minimum_size = Vector2(0, 26)
	for item in items:
		if not item is Dictionary:
			continue
		option.add_item(str(item.get("label", "")))
		var index := option.item_count - 1
		option.set_item_metadata(index, str(item.get("metadata", "")))
		if bool(item.get("disabled", false)):
			option.set_item_disabled(index, true)
		if chosen < 0 and str(item.get("metadata", "")) == selected_metadata:
			chosen = index
			option.select(index)
	if on_selected.is_valid():
		option.item_selected.connect(on_selected.bind(option))
	return option


static func add_stacked_number_field(container: Node, descriptor: Dictionary, on_changed: Callable) -> SpinBox:
	# The Inspector's other numeric shape: a caption line above a full-width
	# field, rather than the caption/field pairs a grid holds.
	#
	# Descriptor keys: caption, value, and optionally min, max, step, arrow_step
	# (0.0 lets the arrows follow step), tooltip, caption_tooltip, font_size
	# (0 keeps the inherited size) and node_name.
	var caption := create_inspector_field_label(str(descriptor.get("caption", "")))
	var caption_tooltip := str(descriptor.get("caption_tooltip", ""))
	if not caption_tooltip.is_empty():
		caption.tooltip_text = caption_tooltip
	container.add_child(caption)
	var field := create_number_field(
		float(descriptor.get("value", 0.0)),
		float(descriptor.get("min", -100000.0)),
		float(descriptor.get("max", 100000.0)),
		float(descriptor.get("step", 0.01)),
		float(descriptor.get("arrow_step", 0.0)),
		on_changed,
		"",
		false,
		false)
	var node_name := str(descriptor.get("node_name", ""))
	if not node_name.is_empty():
		field.name = node_name
	field.custom_minimum_size = Vector2(0, 26)
	var font_size := int(descriptor.get("font_size", 0))
	if font_size > 0:
		field.add_theme_font_size_override("font_size", font_size)
	field.tooltip_text = str(descriptor.get("tooltip", ""))
	container.add_child(field)
	return field


static func create_toggle_field(text: String, pressed: bool, on_toggled: Callable, font_size := 0) -> CheckButton:
	# The Inspector's boolean row: a full-width CheckButton on the standard line
	# height. The initial state is set before connecting, so it fires nothing.
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.custom_minimum_size = Vector2(0, 26)
	if font_size > 0:
		toggle.add_theme_font_size_override("font_size", font_size)
	toggle.button_pressed = pressed
	if on_toggled.is_valid():
		toggle.toggled.connect(on_toggled)
	return toggle


static func build_number_grid(grid: GridContainer, descriptors: Array, on_changed: Callable) -> Dictionary:
	# Builds a caption/field row per descriptor and returns the fields by
	# property name. The caller keeps that map rather than the builder writing
	# into one behind its back.
	#
	# Descriptor keys: caption, value, property, and optionally min, max, step,
	# arrow_step, tooltip and silent (whether setting the initial value fires
	# value_changed).
	var fields: Dictionary = {}
	for descriptor in descriptors:
		if not descriptor is Dictionary:
			continue
		var property_name := str(descriptor.get("property", ""))
		grid.add_child(create_field_caption(str(descriptor.get("caption", ""))))
		var field := create_number_field(
			float(descriptor.get("value", 0.0)),
			float(descriptor.get("min", -100000.0)),
			float(descriptor.get("max", 100000.0)),
			float(descriptor.get("step", 0.01)),
			float(descriptor.get("arrow_step", 0.1)),
			on_changed.bind(property_name) if on_changed.is_valid() else Callable(),
			"",
			bool(descriptor.get("silent", true)))
		var tooltip := str(descriptor.get("tooltip", ""))
		if not tooltip.is_empty():
			field.tooltip_text = tooltip
		grid.add_child(field)
		fields[property_name] = field
	return fields
