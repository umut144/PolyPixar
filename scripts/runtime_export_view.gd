class_name RuntimeExportView
extends VBoxContainer

# The Runtime Export module's work surface, under the same contract as
# OutlinerView and the four Inspector views: main.gd resolves everything that
# needs the World document, the Geometry documents, the batch candidates or the
# file system, pushes the result in as one Dictionary through set_context(), and
# rebuild() draws from that snapshot alone. Every user action leaves as one of
# three intent signals.
#
# The view holds no editor state, reads no Assets or Geometry documents, counts
# no candidates, checks no files or Catalogs, and never runs an Export, a Mesh
# build, a Save or a Consumer Sync. It knows nothing about main.gd,
# WorldDocumentService or RuntimeExportFileService.
#
# Context keys, all already presentation-ready:
#   summary          String, the line above the log
#   consumer_sync    String, the Consumer Sync hint, or "" to leave it alone
#   stages           Array of {title, candidate_count, pending, attention},
#                    where pending and attention are PackedStringArrays of
#                    finished lines. candidate_count is deliberately separate
#                    from pending.size(): the heading counts candidates, the
#                    list shows the lines the summary produced for them.
#   all_current      bool, whether the closing "everything is current" line is
#                    drawn
#   toolbar          {build_all, export_all_valid, sync_consumers}, each
#                    {text, visible, disabled}
#
# Toolbar ownership: the three action Buttons stay children of main.gd's flat
# toolbar, between the Draw Mode status and the Snap button. Re-parenting them
# under this view would nest an HBoxContainer inside that toolbar and change the
# spacing of neighbours the render probe does not observe, for no gain. main.gd
# therefore hands them over once through set_toolbar_buttons(); from then on
# this view owns what they say and what a press means, and nothing else does.

signal build_all_requested()
signal export_all_valid_requested()
signal sync_consumers_requested()

var context: Dictionary = {}
var summary_label: Label
var consumer_sync_label: Label
var log_label: RichTextLabel
var build_all_button: Button
var export_all_valid_button: Button
var sync_consumers_button: Button


func _init() -> void:
	name = "ExportWorkspace"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 18.0
	offset_top = 18.0
	offset_right = -18.0
	offset_bottom = -18.0
	add_theme_constant_override("separation", 12)
	visible = false

	var title := Label.new()
	title.text = "Export"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#e5e9f0"))
	add_child(title)
	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 12)
	summary_label.add_theme_color_override("font_color", Color("#aeb8c8"))
	add_child(summary_label)
	consumer_sync_label = Label.new()
	consumer_sync_label.text = "Consumer Sync · noch nicht ausgeführt"
	consumer_sync_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consumer_sync_label.add_theme_font_size_override("font_size", 12)
	consumer_sync_label.add_theme_color_override("font_color", Color("#9aa3b2"))
	add_child(consumer_sync_label)
	var separator := HSeparator.new()
	add_child(separator)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.fit_content = false
	log_label.scroll_following = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("normal_font_size", 12)
	log_label.add_theme_color_override("default_color", Color("#c5cedb"))
	add_child(log_label)


func set_toolbar_buttons(build_all: Button, export_all_valid: Button, sync_consumers: Button) -> void:
	# The Buttons live in the shared toolbar, but pressing one is this view's
	# intent to report, so the connection is made here and nowhere else.
	build_all_button = build_all
	export_all_valid_button = export_all_valid
	sync_consumers_button = sync_consumers
	build_all_button.pressed.connect(build_all_requested.emit)
	export_all_valid_button.pressed.connect(export_all_valid_requested.emit)
	sync_consumers_button.pressed.connect(sync_consumers_requested.emit)


func set_context(export_context: Dictionary) -> void:
	# A copy, so nothing the caller mutates afterwards can change what was drawn.
	context = export_context.duplicate(true)


func rebuild() -> void:
	apply_toolbar_state(context.get("toolbar", {}))
	if not is_instance_valid(log_label) or not is_instance_valid(summary_label):
		return
	summary_label.text = str(context.get("summary", ""))
	var consumer_sync := str(context.get("consumer_sync", ""))
	if not consumer_sync.is_empty():
		consumer_sync_label.text = consumer_sync
	log_label.clear()
	log_label.append_text("[b]Preflight[/b]\n")
	for stage in context.get("stages", []):
		if stage is Dictionary:
			_append_stage(stage)
	if bool(context.get("all_current", false)):
		log_label.append_text("\n[color=#75b88a]Alles ist aktuell und exportbereit.[/color]\n")


func apply_toolbar_state(toolbar: Dictionary) -> void:
	_apply_button(build_all_button, toolbar.get("build_all", {}))
	_apply_button(export_all_valid_button, toolbar.get("export_all_valid", {}))
	_apply_button(sync_consumers_button, toolbar.get("sync_consumers", {}))


func set_summary_text(text: String) -> void:
	if is_instance_valid(summary_label):
		summary_label.text = text


func clear_log() -> void:
	if is_instance_valid(log_label):
		log_label.clear()


func append_log_line(bbcode: String) -> void:
	# The batch runs and the Consumer Sync report their progress into the same
	# log while they are running. They stay in main.gd; only the writing is here.
	if is_instance_valid(log_label):
		log_label.append_text(bbcode)


func set_consumer_sync_text(text: String, color: Color) -> void:
	if not is_instance_valid(consumer_sync_label):
		return
	consumer_sync_label.text = text
	consumer_sync_label.add_theme_color_override("font_color", color)


func _apply_button(button: Button, state: Dictionary) -> void:
	if not is_instance_valid(button) or state.is_empty():
		return
	button.visible = bool(state.get("visible", false))
	if not button.visible:
		return
	button.text = str(state.get("text", button.text))
	button.disabled = bool(state.get("disabled", true))


func _append_stage(stage: Dictionary) -> void:
	var pending: PackedStringArray = stage.get("pending", PackedStringArray())
	var attention: PackedStringArray = stage.get("attention", PackedStringArray())
	log_label.append_text("\n[b]%s[/b] · %d ausstehend · %d Auffälligkeiten\n" % [
		str(stage.get("title", "")), int(stage.get("candidate_count", 0)), attention.size()])
	for line in pending:
		log_label.append_text("  [color=#9aa3b2]• %s[/color]\n" % line)
	for line in attention:
		log_label.append_text("  [color=#ef8354]• %s[/color]\n" % line)
