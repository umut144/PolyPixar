class_name OutlinerView
extends VBoxContainer

# The Outliner list. It renders the Create, Style and Motion trees from a
# context that main.gd pushes in, and emits what the user did. It never reads
# editor state directly and never mutates a document, the same contract
# ComponentCanvas follows.
#
# The Mesh tree arrives as data rather than as code. It reads the whole derived
# geometry state — bakes, recipes, statuses and previews across all three stages
# — so main.gd resolves that into a flat list of rows and this view renders it.

signal asset_selected(asset_id: String)
signal component_selected(asset_id: String, component_id: String)
signal group_selected(asset_id: String, group_id: String)
signal guide_selected(asset_id: String, guide_id: String)
signal region_selected(asset_id: String, component_id: String)
signal weighting_asset_selected(asset_id: String)
signal weighting_component_selected(asset_id: String, component_id: String)
signal weighting_style_selected(asset_id: String, component_id: String, style_id: String)
signal weighting_style_add_requested(asset_id: String, component_id: String)
signal motion_asset_selected(asset_id: String)
signal motion_path_selected(path_id: String)
signal motion_sequence_selected(sequence_id: String)
signal motion_act_preview_asset_selected(asset_id: String)
signal component_add_requested(asset_id: String, component_id: String, anchor: Control)
signal group_add_requested(asset_id: String, group_id: String, anchor: Control)
signal component_dialog_requested(asset_id: String, anchor: Control)
signal row_context_menu_requested(kind: String, asset_id: String, target_id: String, event: InputEvent, anchor: Button)
signal drop_requested(asset_id: String, target_id: String, payload: Variant)
signal visibility_toggle_requested(kind: String, asset_id: String, target_id: String, visible: bool)
signal geometry_asset_selected(asset_id: String)
signal geometry_component_selected(asset_id: String, component_id: String)
signal geometry_hole_selected(asset_id: String, component_id: String, hole_id: String)
signal geometry_input_selected(asset_id: String, component_id: String, input_id: String, role: String)
signal geometry_pipeline_action(action_id: String, asset_id: String, component_id: String)

# Context, pushed in before each rebuild. The names match main.gd's so the
# moved render code reads the same way it did there.
var assets: Array = []
var motion_paths: Array = []
var motion_sequences: Array = []
var active_module := "Create"
var active_create_submodule := "Single"
var active_geometry_submodule := "Sampling"
var active_motion_submodule := "Animation"
var selected_asset_id := ""
var selected_component_id := ""
var selected_component_ids: Array = []
var selected_group_id := ""
var selected_guide_id := ""
var selected_motion_path_id := ""
var selected_motion_sequence_id := ""
var selected_weighting_style_id := ""
var motion_act_preview_asset_id := ""
var expanded_assets: Dictionary = {}
var outliner_asset_type_filters: Dictionary = {}
var search_text := ""
var focus_asset_id := ""
# Derived state the rows display, computed by main.gd so this view never has to
# reach into the geometry documents itself.
var row_status: Dictionary = {}
# The Mesh tree as a flat list of rows, built by main.gd. Its shape is
# documented at _render_geometry_rows below.
var geometry_rows: Array = []

const CREATE_SUBMODULES := ["Single"]
const GEOMETRY_SUBMODULES := ["Sampling", "Seeding", "Meshing"]


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)
	focus_mode = Control.FOCUS_ALL


func set_documents(world_assets: Array, paths: Array, sequences: Array) -> void:
	assets = world_assets
	motion_paths = paths
	motion_sequences = sequences


func set_module(module: String, create_submodule: String, geometry_submodule: String, motion_submodule: String) -> void:
	active_module = module
	active_create_submodule = create_submodule
	active_geometry_submodule = geometry_submodule
	active_motion_submodule = motion_submodule


func set_selection(asset_id: String, component_id: String, component_ids: Array, group_id: String, guide_id: String, path_id: String, sequence_id: String, style_id: String, act_preview_asset_id: String) -> void:
	selected_asset_id = asset_id
	selected_component_id = component_id
	selected_component_ids = component_ids
	selected_group_id = group_id
	selected_guide_id = guide_id
	selected_motion_path_id = path_id
	selected_motion_sequence_id = sequence_id
	selected_weighting_style_id = style_id
	motion_act_preview_asset_id = act_preview_asset_id


func set_filters(text: String, asset_type_filters: Dictionary) -> void:
	search_text = text
	outliner_asset_type_filters = asset_type_filters


func set_expansion(expansion: Dictionary, focused_asset_id: String) -> void:
	# main.gd owns the focus rule, because it also writes the expansion state.
	expanded_assets = expansion
	focus_asset_id = focused_asset_id


func set_row_status(status: Dictionary) -> void:
	row_status = status


func set_geometry_rows(rows: Array) -> void:
	geometry_rows = rows


func _emit_visibility(visible: bool, kind: String, asset_id: String, target_id: String) -> void:
	visibility_toggle_requested.emit(kind, asset_id, target_id, visible)


func _emit_drop(_at_position: Vector2, payload: Variant, asset_id: String, target_id: String) -> void:
	# Reparenting is a document change, so the view only reports the intent.
	drop_requested.emit(asset_id, target_id, payload)


func _emit_row_context_menu(event: InputEvent, kind: String, asset_id: String, target_id: String, anchor: Button) -> void:
	# The anchor travels with the intent: the menu is positioned against the row
	# that was clicked, and only the view knows which Button that is.
	row_context_menu_requested.emit(kind, asset_id, target_id, event, anchor)


func _row_status(asset_id: String, component_id: String) -> Dictionary:
	var entry = row_status.get("%s/%s" % [asset_id, component_id], {})
	return entry if entry is Dictionary else {}


func _component_mesh_status(asset_id: String, component_id: String) -> String:
	return str(_row_status(asset_id, component_id).get("mesh_status", "Missing"))


func _component_weighting_styles(asset_id: String, component_id: String) -> Array:
	var styles = _row_status(asset_id, component_id).get("weighting_styles", [])
	return styles if styles is Array else []


func _style_weighting_status(asset_id: String, component_id: String, style_id: String) -> String:
	var by_style = _row_status(asset_id, component_id).get("weighting_status", {})
	return str(by_style.get(style_id, "")) if by_style is Dictionary else ""


func rebuild() -> void:
	EditorWidgets.clear(self)
	if active_module == "Export":
		return
	if active_module == "Motion":
		_render_motion_outliner()
		return
	if active_module == "Style":
		_render_weighting_outliner()
		return
	if active_module == "Mesh":
		if active_geometry_submodule in GEOMETRY_SUBMODULES:
			_render_geometry_rows()
		else:
			self.add_child(EditorWidgets.create_outliner_group_label("Mesh · Placeholder"))
			self.add_child(EditorWidgets.create_inspector_field_label("%s authoring will be introduced in a later phase." % active_geometry_submodule))
		return
	if active_module == "Create" and active_create_submodule in CREATE_SUBMODULES:
		# The seven Asset types share one view. The Asset filter and the search
		# select among them; the view itself tests only what main.gd pushed in.
		var visible_assets: Array = []
		for asset in assets:
			if asset_is_visible(asset) and asset_type_filter_matches(asset) and asset_matches_search(asset, search_text):
				visible_assets.append(asset)
		visible_assets.sort_custom(WorldDocumentService.sort_named_documents)
		self.add_child(EditorWidgets.create_outliner_group_label("Assets"))
		for asset in visible_assets:
			_render_asset_outliner_entry(asset, not search_text.is_empty())

func _render_geometry_rows() -> void:
	# Renders the Mesh tree from the row list main.gd built. Every row is an
	# indent plus a button, optionally followed by a role badge, a status dot and
	# a count. The view decides nothing about what a row says.
	for row_data in geometry_rows:
		if not row_data is Dictionary:
			continue
		var kind := str(row_data.get("kind", ""))
		match kind:
			"section":
				add_child(EditorWidgets.create_outliner_group_label(str(row_data.get("label", ""))))
			"child_section":
				add_child(EditorWidgets.create_outliner_child_group_label(str(row_data.get("label", ""))))
			"note":
				add_child(EditorWidgets.create_inspector_field_label(str(row_data.get("label", ""))))
			"asset":
				add_child(_geometry_asset_button(row_data))
			_:
				add_child(_geometry_row(kind, row_data))


func _geometry_asset_button(row_data: Dictionary) -> Button:
	var asset_id := str(row_data.get("asset_id", ""))
	var button := Button.new()
	button.text = str(row_data.get("label", ""))
	button.custom_minimum_size = Vector2(0, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	EditorWidgets.style_outliner_button(button, bool(row_data.get("selected", false)))
	button.pressed.connect(geometry_asset_selected.emit.bind(asset_id))
	return button


func _geometry_row(kind: String, row_data: Dictionary) -> HBoxContainer:
	var asset_id := str(row_data.get("asset_id", ""))
	var component_id := str(row_data.get("component_id", ""))
	var target_id := str(row_data.get("target_id", ""))
	var selected := bool(row_data.get("selected", false))
	var row := HBoxContainer.new()
	if kind in ["hole", "guide"]:
		row.add_theme_constant_override("separation", 2)
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(int(row_data.get("indent", 16)), 0)
	row.add_child(indent)
	var button := Button.new()
	button.text = str(row_data.get("label", ""))
	button.tooltip_text = str(row_data.get("tooltip", ""))
	button.custom_minimum_size = Vector2(0, int(row_data.get("height", 30)))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	match kind:
		"component":
			EditorWidgets.style_outliner_button(button, selected)
			button.pressed.connect(geometry_component_selected.emit.bind(asset_id, component_id))
		"hole":
			EditorWidgets.style_outliner_button(button, selected, str(row_data.get("style_role", "outer")))
			button.pressed.connect(geometry_hole_selected.emit.bind(asset_id, component_id, target_id))
		"guide":
			EditorWidgets.style_guide_outliner_button(button, selected, str(row_data.get("guide_type", "")))
			button.pressed.connect(guide_selected.emit.bind(asset_id, target_id))
		"input":
			EditorWidgets.style_outliner_button(button, selected)
			button.pressed.connect(geometry_input_selected.emit.bind(asset_id, component_id, target_id, str(row_data.get("role", ""))))
		"pipeline", "dependency":
			var action_id := str(row_data.get("action_id", ""))
			button.disabled = action_id.is_empty()
			if not action_id.is_empty():
				button.pressed.connect(geometry_pipeline_action.emit.bind(action_id, asset_id, component_id))
	row.add_child(button)
	if row_data.has("badge"):
		row.add_child(EditorWidgets.create_geometry_role_badge(str(row_data["badge"])))
	if row_data.has("status_color"):
		var status_dot := Label.new()
		status_dot.text = "●"
		status_dot.custom_minimum_size = Vector2(28, 30)
		status_dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_dot.add_theme_font_size_override("font_size", 23)
		status_dot.add_theme_color_override("font_color", row_data["status_color"])
		status_dot.tooltip_text = str(row_data.get("tooltip", ""))
		row.add_child(status_dot)
	if int(row_data.get("status_count", 0)) >= 2:
		var count_label := Label.new()
		count_label.text = str(int(row_data["status_count"]))
		count_label.custom_minimum_size = Vector2(20, 30)
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_label.add_theme_font_size_override("font_size", 12)
		count_label.add_theme_color_override("font_color", Color("#9aa3b2"))
		count_label.tooltip_text = str(row_data.get("tooltip", ""))
		row.add_child(count_label)
	return row


func asset_type_filter_matches(asset: Dictionary) -> bool:
	return bool(outliner_asset_type_filters.get(WorldDocumentService.asset_type(asset), false))

func asset_is_visible(asset: Dictionary) -> bool:
	return focus_asset_id.is_empty() or focus_asset_id == str(asset.get("id", ""))

func _render_motion_outliner() -> void:
	if active_motion_submodule == "Path":
		self.add_child(EditorWidgets.create_outliner_group_label("Paths"))
		for path_document in motion_paths:
			if search_text.is_empty() or str(path_document.get("name", "")).to_lower().contains(search_text):
				var path_button := Button.new()
				path_button.text = str(path_document.get("name", "Path"))
				path_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
				path_button.focus_mode = Control.FOCUS_NONE
				EditorWidgets.style_outliner_button(path_button, str(path_document.get("id", "")) == selected_motion_path_id)
				path_button.pressed.connect(motion_path_selected.emit.bind(str(path_document.get("id", ""))))
				self.add_child(path_button)
		if motion_paths.is_empty():
			self.add_child(EditorWidgets.create_inspector_field_label("No Paths"))
		return
	if active_motion_submodule == "Sequence":
		self.add_child(EditorWidgets.create_outliner_group_label("Sequences"))
		for sequence_document in motion_sequences:
			if search_text.is_empty() or str(sequence_document.get("name", "")).to_lower().contains(search_text):
				var sequence_button := Button.new()
				sequence_button.text = str(sequence_document.get("name", "Sequence"))
				sequence_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
				sequence_button.focus_mode = Control.FOCUS_NONE
				EditorWidgets.style_outliner_button(sequence_button, str(sequence_document.get("id", "")) == selected_motion_sequence_id)
				sequence_button.pressed.connect(motion_sequence_selected.emit.bind(str(sequence_document.get("id", ""))))
				self.add_child(sequence_button)
		if motion_sequences.is_empty():
			self.add_child(EditorWidgets.create_inspector_field_label("No Sequences"))
		return
	if active_motion_submodule == "Act":
		self.add_child(EditorWidgets.create_outliner_group_label("Preview Assets"))
		for asset in assets:
			if not search_text.is_empty() and not str(asset.get("name", "")).to_lower().contains(search_text):
				continue
			var asset_id := str(asset.get("id", ""))
			var preview_button := Button.new()
			preview_button.text = str(asset.get("name", "Asset"))
			preview_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			preview_button.focus_mode = Control.FOCUS_NONE
			EditorWidgets.style_outliner_button(preview_button, asset_id == motion_act_preview_asset_id)
			preview_button.pressed.connect(motion_act_preview_asset_selected.emit.bind(asset_id))
			self.add_child(preview_button)
		if assets.is_empty():
			self.add_child(EditorWidgets.create_inspector_field_label("No Assets"))
		return
	var visible_assets: Array[Dictionary] = []
	for asset in assets:
		if search_text.is_empty() or str(asset.get("name", "")).to_lower().contains(search_text):
			visible_assets.append(asset)
	visible_assets.sort_custom(WorldDocumentService.sort_named_documents)
	self.add_child(EditorWidgets.create_outliner_group_label("Animation Assets"))
	for asset in visible_assets:
		var asset_id := str(asset.get("id", ""))
		var asset_button := Button.new()
		asset_button.text = str(asset.get("name", "Asset"))
		asset_button.custom_minimum_size = Vector2(0, 30)
		asset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		asset_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		asset_button.focus_mode = Control.FOCUS_NONE
		EditorWidgets.style_outliner_button(asset_button, asset_id == selected_asset_id)
		asset_button.pressed.connect(motion_asset_selected.emit.bind(asset_id))
		self.add_child(asset_button)
	if visible_assets.is_empty():
		self.add_child(EditorWidgets.create_inspector_field_label("No Assets"))

func _render_weighting_outliner() -> void:
	self.add_child(EditorWidgets.create_outliner_group_label("Weighting"))
	var visible_asset_count := 0
	for asset in assets:
		if not asset_is_visible(asset) or not asset_type_filter_matches(asset):
			continue
		var asset_id := str(asset.get("id", ""))
		var asset_matches := search_text.is_empty() or str(asset.get("name", "")).to_lower().contains(search_text)
		var component_matches := false
		for component in asset.get("components", []):
			if WorldDocumentService.is_constraint_only_hole(component):
				continue
			if str(component.get("name", "")).to_lower().contains(search_text):
				component_matches = true
				break
			for style in _component_weighting_styles(asset_id, str(component.get("id", ""))):
				if str(style.get("name", "")).to_lower().contains(search_text):
					component_matches = true
		if not asset_matches and not component_matches:
			continue
		visible_asset_count += 1
		var asset_button := Button.new()
		asset_button.text = str(asset.get("name", "Asset"))
		asset_button.custom_minimum_size = Vector2(0, 30)
		asset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		asset_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		asset_button.focus_mode = Control.FOCUS_NONE
		EditorWidgets.style_outliner_button(asset_button, selected_asset_id == asset_id and selected_component_id.is_empty())
		asset_button.pressed.connect(weighting_asset_selected.emit.bind(asset_id))
		self.add_child(asset_button)
		if not bool(expanded_assets.get(asset_id, false)) and search_text.is_empty():
			continue
		for component in asset.get("components", []):
			if WorldDocumentService.is_constraint_only_hole(component):
				continue
			var component_id := str(component.get("id", ""))
			var component_row := HBoxContainer.new()
			var indent := Control.new()
			indent.custom_minimum_size = Vector2(16, 0)
			component_row.add_child(indent)
			var component_button := Button.new()
			var mesh_status := _component_mesh_status(asset_id, component_id)
			component_button.text = "%s · %s" % [str(component.get("name", "Component")), "Mesh Ready" if mesh_status == "Ready" else "Missing Mesh" if mesh_status == "Missing" else "Mesh Stale"]
			component_button.custom_minimum_size = Vector2(0, 30)
			component_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			component_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			component_button.focus_mode = Control.FOCUS_NONE
			EditorWidgets.style_outliner_button(component_button, selected_asset_id == asset_id and selected_component_id == component_id and selected_weighting_style_id.is_empty())
			component_button.pressed.connect(weighting_component_selected.emit.bind(asset_id, component_id))
			component_row.add_child(component_button)
			var add_button := Button.new()
			add_button.text = "+"
			add_button.custom_minimum_size = Vector2(28, 30)
			add_button.focus_mode = Control.FOCUS_NONE
			add_button.tooltip_text = "Add Weighting Style"
			add_button.pressed.connect(weighting_style_add_requested.emit.bind(asset_id, component_id))
			component_row.add_child(add_button)
			self.add_child(component_row)
			for style in _component_weighting_styles(asset_id, component_id):
				var style_row := HBoxContainer.new()
				var style_indent := Control.new()
				style_indent.custom_minimum_size = Vector2(34, 0)
				style_row.add_child(style_indent)
				var style_button := Button.new()
				style_button.text = "%s · %s" % [str(style.get("name", "Weighting Style")), _style_weighting_status(asset_id, component_id, str(style.get("id", "")))]
				style_button.custom_minimum_size = Vector2(0, 26)
				style_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				style_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
				style_button.focus_mode = Control.FOCUS_NONE
				EditorWidgets.style_outliner_button(style_button, selected_weighting_style_id == str(style.get("id", "")))
				style_button.pressed.connect(weighting_style_selected.emit.bind(asset_id, component_id, str(style.get("id", ""))))
				style_row.add_child(style_button)
				self.add_child(style_row)
	if visible_asset_count == 0:
		self.add_child(EditorWidgets.create_inspector_field_label("No Assets match the selected types."))

func asset_matches_search(asset: Dictionary, text: String) -> bool:
	if text.is_empty() or str(asset.get("name", "")).to_lower().contains(text):
		return true
	for component in asset.get("components", []):
		if str(component.get("name", "")).to_lower().contains(text):
			return true
	for guide in asset.get("guides", []):
		if WorldDocumentService.guide_display_name(asset, guide).to_lower().contains(text):
			return true
	return false

func _render_asset_outliner_entry(asset: Dictionary, force_expand := false) -> void:
	var asset_id := str(asset["id"])
	var asset_container := VBoxContainer.new()
	asset_container.add_theme_constant_override("separation", 0)
	self.add_child(asset_container)
	var asset_header := HBoxContainer.new()
	asset_header.add_theme_constant_override("separation", 2)
	asset_container.add_child(asset_header)
	asset_header.add_child(EditorWidgets.create_visibility_checkbox(bool(asset.get("visibility", true)), _emit_visibility.bind("asset", asset_id, asset_id)))
	var asset_button := Button.new()
	asset_button.text = str(asset["name"])
	asset_button.custom_minimum_size = Vector2(0, 30)
	asset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asset_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	asset_button.focus_mode = Control.FOCUS_NONE
	EditorWidgets.style_outliner_button(asset_button, asset_id == selected_asset_id and selected_component_id.is_empty() and selected_guide_id.is_empty())
	asset_button.pressed.connect(asset_selected.emit.bind(asset_id))
	asset_button.gui_input.connect(_emit_row_context_menu.bind("asset", asset_id, asset_id, asset_button))
	asset_header.add_child(asset_button)
	var add_button := Button.new()
	add_button.text = "Add"
	add_button.custom_minimum_size = Vector2(48, 30)
	add_button.focus_mode = Control.FOCUS_NONE
	add_button.pressed.connect(component_dialog_requested.emit.bind(asset_id, add_button))
	asset_header.add_child(add_button)
	if not force_expand and not bool(expanded_assets.get(asset_id, false)):
		return
	var components: Array = []
	var references: Array = []
	var regions: Array = []
	var guides: Array = asset.get("guides", []).duplicate(true)
	for component in asset.get("components", []):
		if str(component.get("type", "component")) == "guide":
			guides.append(component)
		elif WorldDocumentService.is_region(component):
			regions.append(component)
		elif WorldDocumentService.is_reference_component(component):
			references.append(component)
		else:
			components.append(component)
	components.sort_custom(WorldDocumentService.sort_named_documents)
	guides.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return WorldDocumentService.guide_display_name(asset, left).naturalnocasecmp_to(WorldDocumentService.guide_display_name(asset, right)) < 0)
	var components_label := EditorWidgets.create_outliner_child_group_label("Components")
	components_label.set_drag_forwarding(_outliner_get_drag_data.bind(str(asset.get("id", "")), "root"), can_drop_data.bind(str(asset.get("id", "")), "root"), _emit_drop.bind(str(asset.get("id", "")), "root"))
	asset_container.add_child(components_label)
	var rendered_component_ids: Dictionary = {}
	var rendered_group_ids: Dictionary = {}
	var groups: Array = asset.get("groups", []).duplicate(true)
	groups.sort_custom(WorldDocumentService.sort_named_documents)
	for group in groups:
		if str(group.get("parent_component_id", "")).is_empty():
			_render_group_outliner_tree(asset_container, asset, group, 16, rendered_component_ids, rendered_group_ids)
	for component in components:
		if str(component.get("parent_component_id", "")).is_empty() and ComponentHierarchy.membership_group_id(asset, str(component.get("id", ""))).is_empty():
			_render_component_outliner_tree(asset_container, asset, component, 16, rendered_component_ids, false, rendered_group_ids)
	# A malformed in-memory document should remain editable even before its next load migration.
	for component in components:
		if not rendered_component_ids.has(str(component.get("id", ""))):
			_render_component_outliner_tree(asset_container, asset, component, 16, rendered_component_ids, false, rendered_group_ids)
	asset_container.add_child(EditorWidgets.create_outliner_child_group_label("References"))
	references.sort_custom(WorldDocumentService.sort_named_documents)
	for reference in references:
		_render_component_outliner_tree(asset_container, asset, reference, 16, rendered_component_ids, true, {})
	asset_container.add_child(EditorWidgets.create_outliner_child_group_label("Guides"))
	for guide in guides:
		_render_component_guide_row(asset_container, asset, guide)
	asset_container.add_child(EditorWidgets.create_outliner_child_group_label("Regions"))
	regions.sort_custom(WorldDocumentService.sort_named_documents)
	for region in regions:
		_render_region_outliner_row(asset_container, asset, region)

func _render_group_outliner_tree(container: VBoxContainer, asset: Dictionary, group: Dictionary, indent: int, rendered_component_ids: Dictionary, rendered_group_ids: Dictionary) -> void:
	var group_id := str(group.get("id", ""))
	if group_id.is_empty() or rendered_group_ids.has(group_id):
		return
	rendered_group_ids[group_id] = true
	var group_row := HBoxContainer.new()
	group_row.add_theme_constant_override("separation", 0)
	container.add_child(group_row)
	var placeholder := Control.new()
	placeholder.custom_minimum_size = Vector2(indent, 0)
	group_row.add_child(placeholder)
	group_row.add_child(EditorWidgets.create_visibility_checkbox(bool(group.get("visibility", true)), _emit_visibility.bind("group", str(asset.get("id", "")), group_id)))
	var group_button := Button.new()
	group_button.text = "G: %s" % str(group.get("name", "Group"))
	group_button.custom_minimum_size = Vector2(0, 30)
	group_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	group_button.focus_mode = Control.FOCUS_NONE
	group_button.tooltip_text = "Component Group"
	EditorWidgets.style_outliner_button(group_button, group_id == selected_group_id and str(asset.get("id", "")) == selected_asset_id)
	group_button.pressed.connect(group_selected.emit.bind(str(asset.get("id", "")), group_id))
	group_button.gui_input.connect(_emit_row_context_menu.bind("group", str(asset.get("id", "")), group_id, group_button))
	group_button.set_drag_forwarding(_outliner_get_drag_data.bind(str(asset.get("id", "")), group_id), can_drop_data.bind(str(asset.get("id", "")), group_id), _emit_drop.bind(str(asset.get("id", "")), group_id))
	group_row.add_child(group_button)
	var add_button := Button.new()
	add_button.text = "+"
	add_button.custom_minimum_size = Vector2(28, 30)
	add_button.focus_mode = Control.FOCUS_NONE
	add_button.tooltip_text = "Add Child or Guide to Group"
	add_button.pressed.connect(group_add_requested.emit.bind(str(asset.get("id", "")), group_id, add_button))
	group_row.add_child(add_button)
	var group_components: Array = []
	for component in asset.get("components", []):
		if WorldDocumentService.is_region(component):
			continue
		if str(component.get("group_id", "")) != group_id:
			continue
		var parent_id := str(component.get("parent_component_id", ""))
		if parent_id.is_empty() or ComponentHierarchy.membership_group_id(asset, parent_id) != group_id:
			group_components.append(component)
	group_components.sort_custom(WorldDocumentService.sort_named_documents)
	for component in group_components:
		_render_component_outliner_tree(container, asset, component, indent + 16, rendered_component_ids, false, rendered_group_ids, true)

func _outliner_get_drag_data(_at_position: Vector2, asset_id: String, target_id: String):
	if target_id == "root":
		return null
	var asset := WorldDocumentService.asset_by_id(assets, asset_id)
	var group := ComponentHierarchy.group_by_id(asset, target_id)
	if not group.is_empty():
		var group_preview := Label.new()
		group_preview.text = "G: %s" % str(group.get("name", "Group"))
		set_drag_preview(group_preview)
		return {"kind": "group", "asset_id": asset_id, "group_id": target_id}
	var component := WorldDocumentService.component_by_id(asset, target_id)
	if component.is_empty():
		return null
	var component_ids: Array[String] = []
	if selected_component_ids.has(target_id):
		component_ids = selected_component_ids.duplicate()
	else:
		component_ids = [target_id]
	var preview := Label.new()
	preview.text = str(component.get("name", "Component")) if component_ids.size() == 1 else "%d Components" % component_ids.size()
	set_drag_preview(preview)
	return {"kind": "components", "asset_id": asset_id, "component_ids": component_ids}

func can_drop_data(_at_position: Vector2, data, asset_id: String, target_id: String) -> bool:
	if not data is Dictionary or str(data.get("asset_id", "")) != asset_id:
		return false
	var asset := WorldDocumentService.asset_by_id(assets, asset_id)
	if str(data.get("kind", "")) == "group":
		var group_id := str(data.get("group_id", ""))
		if target_id == "root":
			return ComponentHierarchy.can_parent_group(asset, group_id, "")
		return ComponentHierarchy.can_move_group_to_component(asset, group_id, target_id)
	if str(data.get("kind", "")) != "components":
		return false
	var component_ids: Array = data.get("component_ids", [])
	if component_ids.is_empty():
		return false
	if target_id == "root":
		return true
	if not ComponentHierarchy.group_by_id(asset, target_id).is_empty():
		return true
	if WorldDocumentService.component_by_id(asset, target_id).is_empty():
		return false
	for component_id in component_ids:
		if not ComponentHierarchy.can_parent(asset, str(component_id), target_id):
			return false
	return true

func _render_component_outliner_tree(container: VBoxContainer, asset: Dictionary, component: Dictionary, indent: int, rendered_component_ids: Dictionary, reference_summary := false, rendered_group_ids: Dictionary = {}, render_group_members := false) -> void:
	var asset_id := str(asset.get("id", ""))
	var component_id := str(component.get("id", ""))
	if component_id.is_empty() or (not reference_summary and rendered_component_ids.has(component_id)):
		return
	if not reference_summary:
		rendered_component_ids[component_id] = true
	var component_row := HBoxContainer.new()
	component_row.add_theme_constant_override("separation", 0)
	container.add_child(component_row)
	var child_placeholder := Control.new()
	child_placeholder.custom_minimum_size = Vector2(indent, 0)
	component_row.add_child(child_placeholder)
	component_row.add_child(EditorWidgets.create_visibility_checkbox(bool(component.get("visibility", true)), _emit_visibility.bind("component", asset_id, component_id)))
	var component_button := Button.new()
	var component_name := WorldDocumentService.component_outliner_name(assets, component) if reference_summary else _component_tree_name(component)
	component_button.text = component_name if bool(component.get("visibility", true)) else EditorWidgets.strikethrough_text(component_name)
	component_button.custom_minimum_size = Vector2(0, 30)
	component_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	component_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	component_button.focus_mode = Control.FOCUS_NONE
	if WorldDocumentService.is_reference_component(component):
		component_button.tooltip_text = _reference_outliner_tooltip(asset, component)
	EditorWidgets.style_outliner_button(component_button, (component_id == selected_component_id or selected_component_ids.has(component_id)) and asset_id == selected_asset_id, WorldDocumentService.topology_role(component))
	component_button.pressed.connect(component_selected.emit.bind(asset_id, component_id))
	component_button.gui_input.connect(_emit_row_context_menu.bind("component", asset_id, component_id, component_button))
	component_button.set_drag_forwarding(_outliner_get_drag_data.bind(asset_id, component_id), can_drop_data.bind(asset_id, component_id), _emit_drop.bind(asset_id, component_id))
	component_row.add_child(component_button)
	if WorldDocumentService.is_reference_component(component):
		return
	if not WorldDocumentService.is_constraint_only_hole(component):
		var add_button := Button.new()
		add_button.text = "+"
		add_button.custom_minimum_size = Vector2(28, 30)
		add_button.focus_mode = Control.FOCUS_NONE
		add_button.tooltip_text = "Add Child or Guide"
		add_button.pressed.connect(component_add_requested.emit.bind(asset_id, component_id, add_button))
		component_row.add_child(add_button)
	var children := ComponentHierarchy.children(asset, component_id)
	children.sort_custom(WorldDocumentService.sort_named_documents)
	for child in children:
		if WorldDocumentService.is_region(child):
			continue
		if not render_group_members and not ComponentHierarchy.membership_group_id(asset, str(child.get("id", ""))).is_empty():
			continue
		_render_component_outliner_tree(container, asset, child, indent + 16, rendered_component_ids, false, rendered_group_ids, render_group_members)
	if not render_group_members:
		var child_groups: Array = asset.get("groups", []).duplicate(true)
		child_groups.sort_custom(WorldDocumentService.sort_named_documents)
		for group in child_groups:
			if str(group.get("parent_component_id", "")) == component_id:
				_render_group_outliner_tree(container, asset, group, indent + 16, rendered_component_ids, rendered_group_ids)

func _render_component_guide_row(container: VBoxContainer, asset: Dictionary, guide: Dictionary) -> void:
	var asset_id := str(asset.get("id", ""))
	var guide_row := HBoxContainer.new()
	guide_row.add_theme_constant_override("separation", 0)
	container.add_child(guide_row)
	var component_indent := Control.new()
	component_indent.custom_minimum_size = Vector2(16, 0)
	guide_row.add_child(component_indent)
	guide_row.add_child(EditorWidgets.create_visibility_checkbox(bool(guide.get("visibility", true)), _emit_visibility.bind("guide", asset_id, str(guide.get("id", "")))))
	var guide_button := Button.new()
	var guide_name := WorldDocumentService.guide_display_name(asset, guide)
	guide_button.text = guide_name if bool(guide.get("visibility", true)) else EditorWidgets.strikethrough_text(guide_name)
	guide_button.tooltip_text = AssetGuide.display_name(str(guide.get("guide_type", AssetGuide.SAMPLER_SPINE)))
	guide_button.custom_minimum_size = Vector2(0, 30)
	guide_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	guide_button.focus_mode = Control.FOCUS_NONE
	EditorWidgets.style_guide_outliner_button(guide_button, str(guide.get("id", "")) == selected_guide_id, str(guide.get("guide_type", AssetGuide.SAMPLER_SPINE)))
	guide_button.pressed.connect(guide_selected.emit.bind(asset_id, str(guide.get("id", ""))))
	guide_row.add_child(guide_button)

func _render_region_outliner_row(container: VBoxContainer, asset: Dictionary, region: Dictionary) -> void:
	var region_row := HBoxContainer.new()
	region_row.add_theme_constant_override("separation", 0)
	container.add_child(region_row)
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(16, 0)
	region_row.add_child(indent)
	var region_id := str(region.get("id", ""))
	region_row.add_child(EditorWidgets.create_visibility_checkbox(bool(region.get("visibility", true)), _emit_visibility.bind("component", str(asset.get("id", "")), region_id)))
	var button := Button.new()
	var group_id := str(region.get("group_id", ""))
	var parent_id := str(region.get("parent_component_id", ""))
	var scope := ComponentHierarchy.group_by_id(asset, group_id) if not group_id.is_empty() else WorldDocumentService.component_by_id(asset, parent_id)
	button.text = "%s → %s" % [str(scope.get("name", "Asset")), WorldDocumentService.normalized_component_name(region)]
	button.tooltip_text = "%s gameplay region" % str(region.get("region_type", "attack")).capitalize()
	button.custom_minimum_size = Vector2(0, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	EditorWidgets.style_region_outliner_button(button, selected_component_id == region_id and selected_asset_id == str(asset.get("id", "")), str(region.get("region_type", "attack")))
	button.pressed.connect(region_selected.emit.bind(str(asset.get("id", "")), region_id))
	region_row.add_child(button)

func _component_tree_name(component: Dictionary) -> String:
	var component_name := WorldDocumentService.normalized_component_name(component)
	return "R: %s" % component_name if WorldDocumentService.is_reference_component(component) else component_name

func _reference_outliner_tooltip(asset: Dictionary, reference: Dictionary) -> String:
	var source_asset := WorldDocumentService.asset_by_id(assets, str(reference.get("source_asset_id", "")))
	var source_name := str(source_asset.get("name", "Missing asset"))
	var tooltip := "Referenced asset: %s" % source_name
	var parent := WorldDocumentService.component_by_id(asset, str(reference.get("parent_component_id", "")))
	if not parent.is_empty():
		tooltip += "\nAttached to: %s" % WorldDocumentService.normalized_component_name(parent)
	return tooltip
