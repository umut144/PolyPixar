class_name CreateInspectorView
extends VBoxContainer

# The Create module's Inspector. Like OutlinerView it is told what to draw and
# says what the user asked for; it never touches a document. Everything it needs
# arrives through the set_* calls below, including the two lists main.gd has to
# resolve against the selection (the Components of a multi selection and the
# Point ids that still exist), and rebuild() draws from that snapshot alone.
#
# The intent signals still carry the argument lists of the handlers they
# replaced, control references included. That keeps this a move rather than a
# redesign; giving them plain values is a separate step.

signal asset_authored_facing_selected(index: int, option: OptionButton)
signal asset_pivot_property_changed(value: float, property_name: String)
signal asset_rename_requested(new_name: String)
signal asset_root_position_changed(value: float, property_name: String)
signal asset_root_scale_changed(value: float, property_name: String)
signal asset_root_scale_rebase_requested()
signal asset_scales_rebase_requested()
signal circle_primitive_diameter_changed(value: float)
signal component_catch_parent_selected(index: int, option: OptionButton)
signal component_contour_stroke_width_changed(value: float)
signal component_debug_point_numbers_toggled(enabled: bool)
signal component_hierarchy_parent_selected(index: int, option: OptionButton)
signal component_projection_depth_changed(value: float)
signal component_rename_requested(new_name: String)
signal region_geometry_source_selected(index: int, option: OptionButton)
signal component_topology_role_selected(index: int, option: OptionButton)
signal component_visibility_changed(visibility_enabled: bool)
signal component_z_index_changed(value: float)
signal edge_render_outline_changed(enabled: bool)
signal ellipse_primitive_diameter_changed(value: float, property_name: String)
signal global_transform_value_changed(value: float, property_name: String)
signal group_hierarchy_parent_selected(index: int, option: OptionButton)
signal group_rename_requested(new_name: String)
signal group_transform_value_changed(value: float, property_name: String)
signal group_visibility_changed(visibility_enabled: bool)
signal guide_delete_requested()
signal guide_type_selected(index: int, option: OptionButton)
signal guide_visibility_changed(enabled: bool)
signal multi_component_field_focus_exited(field: LineEdit, property_name: String, integer_only: bool)
signal multi_component_field_submitted(raw_value: String, field: LineEdit, property_name: String, integer_only: bool)
signal multi_component_visibility_selected(index: int)
signal point_position_changed(value: float, property_name: String)
signal reference_image_clear_requested()
signal reference_image_load_requested()
signal reference_image_pivot_selected(index: int, option: OptionButton)
signal reference_image_property_changed(value: float, property_name: String)
signal reference_image_target_height_changed(value: float)
signal reference_image_visibility_changed(image_visible: bool)
signal section_toggled(section: VBoxContainer, text: String, header: Button)
signal selected_points_delta_changed(value: float, property_name: String, field: SpinBox)
signal selected_points_mode_selected(index: int, option: OptionButton, point_ids: Array)
signal selected_points_preserve_changed(enabled: bool, point_ids: Array)
signal transform_value_changed(value: float, property_name: String)
signal weapon_frame_value_changed(value: float, property_name: String)

const ASSET_ROOT_POSITION_TOOLTIP := "Preview translation for the complete Asset. Rebase before Runtime Export."
const ASSET_ROOT_SCALE_TOOLTIP := "Positive preview Scale on the %s axis around the Asset Pivot. Rebase before Runtime Export."
const CONTOUR_STROKE_WIDTH_OVERRIDE_TOOLTIP := "Overrides every Contour part of the referenced source Asset without changing that Asset."
const PROJECTION_DEPTH_TOOLTIP := "Visible component depth used by runtime presentation; independent of Scale, Z Order, and Contour Stroke Width."
const Z_ORDER_TOOLTIP := "Orders Components only inside this Asset; Runtime consumers choose the Asset's contextual game layer."


# Context, pushed in before rebuild().
var document_asset: Dictionary = {}
var inspector_components: Array[Dictionary] = []
var valid_point_ids: Array[String] = []
var selected_component_id := ""
var selected_group_id := ""
var selected_guide_id := ""
var selected_edge_id := ""
var selected_edge_ids: Array[String] = []
var active_state := ""
var active_edit_mode := ""
var face_selected := false
var world_contour_stroke_width_px := 2.0

# Controls the editor updates without a full rebuild. They belong to whatever
# rebuild() last drew, so they are cleared at the start of every rebuild.
var transform_fields: Dictionary = {}
var asset_pivot_fields: Dictionary = {}
var asset_root_position_fields: Dictionary = {}
var asset_root_scale_fields: Dictionary = {}
var asset_root_scale_field: SpinBox
var asset_root_scale_rebase_button: Button
var asset_scale_rebase_button: Button
var asset_authored_facing_option: OptionButton
var asset_name_editor: LineEdit
var component_name_editor: LineEdit


func set_document(asset: Dictionary, contour_stroke_width_px: float) -> void:
	document_asset = asset
	world_contour_stroke_width_px = contour_stroke_width_px


func set_selection(component_id: String, group_id: String, guide_id: String,
		edge_id: String, edge_ids: Array[String]) -> void:
	selected_component_id = component_id
	selected_group_id = group_id
	selected_guide_id = guide_id
	selected_edge_id = edge_id
	selected_edge_ids = edge_ids


func set_resolved_selection(components: Array[Dictionary], point_ids: Array[String]) -> void:
	# main.gd resolves these against the document, so the view never has to know
	# how a stale id is dropped.
	inspector_components = components
	valid_point_ids = point_ids


func set_mode(state: String, edit_mode: String, canvas_face_selected: bool) -> void:
	active_state = state
	active_edit_mode = edit_mode
	face_selected = canvas_face_selected


func _reset_field_cache() -> void:
	transform_fields.clear()
	asset_pivot_fields.clear()
	asset_root_position_fields.clear()
	asset_root_scale_fields.clear()
	asset_root_scale_field = null
	asset_root_scale_rebase_button = null
	asset_scale_rebase_button = null
	asset_authored_facing_option = null
	asset_name_editor = null
	component_name_editor = null


func rebuild() -> void:
	EditorWidgets.clear(self)
	_reset_field_cache()
	var asset := document_asset
	if asset.is_empty():
		return
	if not selected_guide_id.is_empty():
		_render_guide_inspector(asset, WorldDocumentService.guide_by_id(asset, selected_guide_id))
		return
	if not selected_group_id.is_empty():
		_render_group_inspector(asset, ComponentHierarchy.group_by_id(asset, selected_group_id))
		return
	if inspector_components.size() > 1:
		_render_multi_component_inspector(asset, inspector_components)
		return
	if selected_component_id.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("Name"))
		asset_name_editor = EditorWidgets.create_name_editor(str(asset["name"]), "Asset name")
		asset_name_editor.text_submitted.connect(asset_rename_requested.emit)
		asset_name_editor.focus_exited.connect(func() -> void:
			asset_rename_requested.emit(asset_name_editor.text)
		)
		add_child(asset_name_editor)
		add_child(EditorWidgets.create_inspector_section("Initial Pose", section_toggled.emit))
		add_child(EditorWidgets.create_inspector_field_label("Authored Facing"))
		var facing_items: Array = []
		for facing in AssetPresentation.SERIALIZED_VALUES:
			facing_items.append({"label": AssetPresentation.display_name(facing), "metadata": facing})
		asset_authored_facing_option = EditorWidgets.create_option_field(facing_items,
			AssetPresentation.serialize_authored_facing(asset.get("authored_facing", AssetPresentation.AuthoredFacing.NEUTRAL)),
			asset_authored_facing_selected.emit)
		add_child(asset_authored_facing_option)
		add_child(EditorWidgets.create_inspector_section("Asset Transform", section_toggled.emit))
		var asset_transform_grid := GridContainer.new()
		asset_transform_grid.columns = 2
		asset_transform_grid.add_theme_constant_override("h_separation", 8)
		asset_transform_grid.add_theme_constant_override("v_separation", 4)
		var asset_pivot := WorldDocumentService.asset_pivot(asset)
		var root_position := AssetScaleRebaseService.root_position(asset)
		var asset_root_scale := AssetScaleRebaseService.root_scale(asset)
		asset_root_position_fields = EditorWidgets.build_number_grid(asset_transform_grid, [
			{"caption": "Position X (cm)", "property": "position_x", "value": ToolUnits.to_centimeters(root_position.x),
				"tooltip": ASSET_ROOT_POSITION_TOOLTIP},
			{"caption": "Position Y (cm)", "property": "position_y", "value": ToolUnits.to_centimeters(root_position.y),
				"tooltip": ASSET_ROOT_POSITION_TOOLTIP},
		], asset_root_position_changed.emit)
		asset_pivot_fields = EditorWidgets.build_number_grid(asset_transform_grid, [
			{"caption": "Pivot X (cm)", "property": "pivot_x", "value": ToolUnits.to_centimeters(asset_pivot.x)},
			{"caption": "Pivot Y (cm)", "property": "pivot_y", "value": ToolUnits.to_centimeters(asset_pivot.y)},
		], asset_pivot_property_changed.emit)
		asset_root_scale_fields = EditorWidgets.build_number_grid(asset_transform_grid, [
			{"caption": "Scale X", "property": "scale_x", "value": asset_root_scale.x, "min": 0.01, "max": 100.0,
				"tooltip": ASSET_ROOT_SCALE_TOOLTIP % "X"},
			{"caption": "Scale Y", "property": "scale_y", "value": asset_root_scale.y, "min": 0.01, "max": 100.0,
				"tooltip": ASSET_ROOT_SCALE_TOOLTIP % "Y"},
		], asset_root_scale_changed.emit)
		asset_root_scale_field = asset_root_scale_fields.get("scale_x")
		add_child(asset_transform_grid)
		_render_asset_root_scale_rebase_inspector(asset)
		_render_asset_scale_rebase_inspector(asset)
		var reference_image := WorldDocumentService.normalize_reference_image(asset.get("reference_image", {}))
		add_child(EditorWidgets.create_inspector_section("Reference Image", section_toggled.emit))
		var reference_buttons := HBoxContainer.new()
		var load_reference_button := Button.new()
		load_reference_button.text = "Load Image" if str(reference_image.get("file", "")).is_empty() else "Replace Image"
		load_reference_button.custom_minimum_size = Vector2(0, 26)
		load_reference_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		load_reference_button.focus_mode = Control.FOCUS_NONE
		load_reference_button.pressed.connect(reference_image_load_requested.emit)
		reference_buttons.add_child(load_reference_button)
		if not str(reference_image.get("file", "")).is_empty():
			var clear_reference_button := Button.new()
			clear_reference_button.text = "Clear"
			clear_reference_button.custom_minimum_size = Vector2(64, 26)
			clear_reference_button.focus_mode = Control.FOCUS_NONE
			clear_reference_button.pressed.connect(reference_image_clear_requested.emit)
			reference_buttons.add_child(clear_reference_button)
		add_child(reference_buttons)
		if not str(reference_image.get("file", "")).is_empty():
			var reference_file_label := EditorWidgets.create_inspector_field_label(str(reference_image.get("file", "")))
			reference_file_label.add_theme_color_override("font_color", Color("#9aa3b2"))
			add_child(reference_file_label)
		EditorWidgets.add_stacked_number_field(self, {
			"caption": "Target Height (cm)", "value": float(reference_image.get("target_height_cm", 13.0)),
			"min": 0.01, "max": 100000.0, "arrow_step": 0.1,
		}, reference_image_target_height_changed.emit)
		var pivot_label := EditorWidgets.create_inspector_field_label("Pivot")
		add_child(pivot_label)
		add_child(EditorWidgets.create_option_field([
			{"label": "Center", "metadata": "center"},
			{"label": "Bottom Center", "metadata": "bottom_center"},
		], str(reference_image.get("pivot_mode", "bottom_center")), reference_image_pivot_selected.emit))
		if not str(reference_image.get("file", "")).is_empty():
			var reference_visibility := CheckBox.new()
			reference_visibility.text = "Visible"
			reference_visibility.focus_mode = Control.FOCUS_NONE
			reference_visibility.button_pressed = bool(reference_image.get("visible", true))
			reference_visibility.toggled.connect(reference_image_visibility_changed.emit)
			add_child(reference_visibility)
			# The node name is carried over from the original field; nothing reads
			# it back, so it stays only to keep the scene tree identical.
			EditorWidgets.add_stacked_number_field(self, {
				"caption": "Opacity", "value": float(reference_image.get("opacity", 0.5)),
				"min": 0.0, "max": 1.0, "arrow_step": 0.1, "node_name": "ReferenceImageOpacity",
			}, reference_image_property_changed.emit.bind("opacity"))
			var reference_transform_grid := GridContainer.new()
			reference_transform_grid.columns = 2
			reference_transform_grid.add_theme_constant_override("h_separation", 8)
			reference_transform_grid.add_theme_constant_override("v_separation", 4)
			var reference_position: Vector2 = reference_image.get("position", Vector2.ZERO)
			# Arrows move in tenths while the text field keeps hundredth precision.
			# Scale is clamped positive; the offsets are free.
			EditorWidgets.build_number_grid(reference_transform_grid, [
				{"caption": "Position X (cm)", "property": "position_x",
					"value": ToolUnits.to_centimeters(reference_position.x), "silent": false},
				{"caption": "Position Y (cm)", "property": "position_y",
					"value": ToolUnits.to_centimeters(reference_position.y), "silent": false},
				{"caption": "Scale", "property": "scale",
					"value": float(reference_image.get("scale", 1.0)), "min": 0.01, "silent": false},
			], reference_image_property_changed.emit)
			add_child(reference_transform_grid)
		return
	var component := WorldDocumentService.component_by_id(asset, selected_component_id)
	if component.is_empty():
		return
	var inherited_region_geometry := WorldDocumentService.region_uses_component_geometry(component)
	var constraint_only_hole := WorldDocumentService.is_constraint_only_hole(component)
	if not inherited_region_geometry and active_state == "edit" and active_edit_mode == "point":
		var point_ids := valid_point_ids
		if point_ids.is_empty():
			add_child(EditorWidgets.create_inspector_field_label("Edit Point"))
			add_child(EditorWidgets.create_inspector_section("Point Settings", section_toggled.emit))
			var selection_hint := EditorWidgets.create_inspector_field_label("Select one or more points to edit them.")
			selection_hint.add_theme_color_override("font_color", Color("#9aa3b2"))
			add_child(selection_hint)
			_add_component_debug_inspector(component)
			return
		var is_multi_point_selection := point_ids.size() > 1
		add_child(EditorWidgets.create_inspector_field_label("%d Points" % point_ids.size() if is_multi_point_selection else "Point"))
		add_child(EditorWidgets.create_inspector_section("Transform", section_toggled.emit))
		var point_transform_grid := GridContainer.new()
		point_transform_grid.columns = 2
		point_transform_grid.add_theme_constant_override("h_separation", 8)
		point_transform_grid.add_theme_constant_override("v_separation", 4)
		if is_multi_point_selection:
			# The delta handler needs the field it belongs to, so the fields are
			# built unconnected and wired from the returned map.
			var delta_fields := EditorWidgets.build_number_grid(point_transform_grid, [
				{"caption": "Delta X (cm)", "property": "position_x", "value": 0.0},
				{"caption": "Delta Y (cm)", "property": "position_y", "value": 0.0},
			], Callable())
			for delta_property in delta_fields:
				var delta_field: SpinBox = delta_fields[delta_property]
				delta_field.value_changed.connect(
					selected_points_delta_changed.emit.bind(str(delta_property), delta_field))
		else:
			var selected_point := BezierTopology.point_by_id(component.get("points", []), point_ids[0])
			var point_position: Vector2 = selected_point.get("position", Vector2.ZERO)
			EditorWidgets.build_number_grid(point_transform_grid, [
				{"caption": "Position X (cm)", "property": "position_x",
					"value": ToolUnits.to_centimeters(point_position.x)},
				{"caption": "Position Y (cm)", "property": "position_y",
					"value": ToolUnits.to_centimeters(point_position.y)},
			], point_position_changed.emit)
		add_child(point_transform_grid)
		add_child(EditorWidgets.create_inspector_section("Point Settings", section_toggled.emit))
		_add_selected_point_settings(component, point_ids)
		_add_component_debug_inspector(component)
		return
	if not inherited_region_geometry and active_state == "edit" and active_edit_mode == "edge":
		var selected_edges: Array[Dictionary] = []
		for edge_id in selected_edge_ids:
			var candidate := WorldDocumentService.edge_by_id(component, edge_id)
			if not candidate.is_empty():
				selected_edges.append(candidate)
		if selected_edges.is_empty() and not selected_edge_id.is_empty():
			var fallback_edge := WorldDocumentService.edge_by_id(component, selected_edge_id)
			if not fallback_edge.is_empty():
				selected_edges.append(fallback_edge)
		add_child(EditorWidgets.create_inspector_field_label("%d Edges" % selected_edges.size() if selected_edges.size() > 1 else "Edge"))
		add_child(EditorWidgets.create_inspector_section("Edge Settings", section_toggled.emit))
		if selected_edges.is_empty():
			var edge_hint := EditorWidgets.create_inspector_field_label("Select an edge to edit it.")
			edge_hint.add_theme_color_override("font_color", Color("#9aa3b2"))
			add_child(edge_hint)
		elif constraint_only_hole:
			var hole_edge_hint := EditorWidgets.create_inspector_field_label("Hole boundaries do not render their own outline.")
			hole_edge_hint.add_theme_color_override("font_color", Color("#9aa3b2"))
			add_child(hole_edge_hint)
		else:
			var all_rendered := true
			for edge in selected_edges:
				all_rendered = all_rendered and bool(edge.get("render_outline", true))
			add_child(EditorWidgets.create_toggle_field(
				"Render Outline", all_rendered, edge_render_outline_changed.emit))
		return
	if not inherited_region_geometry and active_state == "edit" and active_edit_mode == "face":
		add_child(EditorWidgets.create_inspector_field_label("Face"))
		add_child(EditorWidgets.create_inspector_section("Face Settings", section_toggled.emit))
		var face_hint := EditorWidgets.create_inspector_field_label("Face selected." if face_selected else "Select the face to edit it.")
		face_hint.add_theme_color_override("font_color", Color("#8fd8f8") if face_selected else Color("#9aa3b2"))
		add_child(face_hint)
		return
	if not inherited_region_geometry and not selected_edge_id.is_empty():
		var selected_edge := WorldDocumentService.edge_by_id(component, selected_edge_id)
		if not selected_edge.is_empty():
			add_child(EditorWidgets.create_inspector_field_label("Edge"))
			add_child(EditorWidgets.create_inspector_section("Edge Settings", section_toggled.emit))
			if constraint_only_hole:
				var hole_edge_hint := EditorWidgets.create_inspector_field_label("Hole boundaries do not render their own outline.")
				hole_edge_hint.add_theme_color_override("font_color", Color("#9aa3b2"))
				add_child(hole_edge_hint)
			else:
				add_child(EditorWidgets.create_toggle_field(
					"Render Outline", bool(selected_edge.get("render_outline", true)),
					edge_render_outline_changed.emit))
			return
	add_child(EditorWidgets.create_inspector_section("Component", section_toggled.emit))
	component_name_editor = EditorWidgets.create_name_editor(WorldDocumentService.normalized_component_name(component), "Component name")
	component_name_editor.text_submitted.connect(component_rename_requested.emit)
	component_name_editor.focus_exited.connect(func() -> void: component_rename_requested.emit(component_name_editor.text))
	add_child(component_name_editor)
	if WorldDocumentService.is_region(component):
		add_child(EditorWidgets.create_inspector_section("Geometry", section_toggled.emit))
		add_child(EditorWidgets.create_inspector_field_label("Geometry Source"))
		var geometry_source_option := EditorWidgets.create_option_field([
			{"label": "Free Draw", "metadata": WorldDocumentService.REGION_GEOMETRY_AUTHORED},
			{"label": "Component Geometry", "metadata": WorldDocumentService.REGION_GEOMETRY_COMPONENT},
		], WorldDocumentService.normalize_region_geometry_source(component.get("region_geometry_source", "")), region_geometry_source_selected.emit)
		geometry_source_option.tooltip_text = "Component Geometry follows the attached Component permanently; the retained Free Draw topology is inactive."
		add_child(geometry_source_option)
		var source_component := WorldDocumentService.component_by_id(asset, str(component.get("parent_component_id", "")))
		add_child(EditorWidgets.create_inspector_field_label("Attached Component: %s" % str(source_component.get("name", "Missing Component"))))
	else:
		add_child(EditorWidgets.create_inspector_section("Hierarchy", section_toggled.emit))
		add_child(EditorWidgets.create_inspector_field_label("Parent Component"))
		var hierarchy_parent_items: Array = []
		if ComponentHierarchy.can_parent(asset, selected_component_id, ""):
			hierarchy_parent_items.append({"label": "Root", "metadata": ""})
		for candidate in asset.get("components", []):
			var candidate_id := str(candidate.get("id", ""))
			if candidate_id == selected_component_id or not ComponentHierarchy.can_parent(asset, selected_component_id, candidate_id):
				continue
			hierarchy_parent_items.append({"label": str(candidate.get("name", "Component")), "metadata": candidate_id})
		add_child(EditorWidgets.create_option_field(hierarchy_parent_items,
			str(component.get("parent_component_id", "")), component_hierarchy_parent_selected.emit))
	var draw_mode := str(component.get("draw_mode", "closed_loop"))
	add_child(EditorWidgets.create_inspector_field_label("Draw Mode: %s" % WorldDocumentService.draw_mode_display_name(draw_mode)))
	if not WorldDocumentService.is_region(component) and (WorldDocumentService.is_reference_component(component) or draw_mode in ["closed_loop", "primitive"]):
		add_child(EditorWidgets.create_inspector_section("Topology", section_toggled.emit))
		add_child(EditorWidgets.create_option_field([
			{"label": "Outer", "metadata": "outer"},
			{"label": "Hole", "metadata": "hole"},
		], str(component.get("topology_role", "outer")), component_topology_role_selected.emit))
	var primitive = component.get("primitive", {})
	if primitive is Dictionary and str(primitive.get("type", "")) in ["circle", PrimitiveGeometryService.ELLIPSE]:
		add_child(EditorWidgets.create_inspector_section("Geometry", section_toggled.emit))
		var primitive_type := str(primitive.get("type", ""))
		add_child(EditorWidgets.create_inspector_field_label("Type: %s" % primitive_type.capitalize()))
		if primitive_type == "circle":
			add_child(EditorWidgets.create_inspector_field_label("Diameter (cm)"))
			var diameter_field := SpinBox.new()
			diameter_field.min_value = 0.1
			diameter_field.max_value = 100000.0
			diameter_field.step = 0.1
			diameter_field.value = float(primitive.get("diameter_cm", 1.0))
			diameter_field.value_changed.connect(circle_primitive_diameter_changed.emit)
			add_child(diameter_field)
		else:
			_add_ellipse_diameter_field("Diameter X (cm)", float(primitive.get("diameter_x_cm", 1.0)), "diameter_x_cm")
			_add_ellipse_diameter_field("Diameter Y (cm)", float(primitive.get("diameter_y_cm", 1.0)), "diameter_y_cm")
	var validation_component := component
	if inherited_region_geometry:
		validation_component = WorldDocumentService.component_by_id(asset, str(component.get("parent_component_id", "")))
	var validation_draw_mode := str(validation_component.get("draw_mode", "closed_loop"))
	var mode_issues := ["Attached Component is missing."] if validation_component.is_empty() else PrimitiveGeometryService.validation_issues(validation_component) if validation_draw_mode == "primitive" else BezierTopology.mode_validation_issues(validation_component, true)
	if inherited_region_geometry and validation_draw_mode == "contour" and (validation_component.get("chains", []).size() != 1 or not bool(validation_component.get("chains", [])[0].get("closed", false))):
		mode_issues.append("Component Geometry requires a closed Component boundary.")
	var configured_catch_parent_id := str(component.get("catch_parent_component_id", ""))
	if not configured_catch_parent_id.is_empty() and (configured_catch_parent_id == selected_component_id or WorldDocumentService.component_by_id(asset, configured_catch_parent_id).is_empty()):
		mode_issues.append("Catch Parent references a missing Component.")
	add_child(EditorWidgets.create_inspector_section("Validation", section_toggled.emit))
	var mode_status := EditorWidgets.create_inspector_field_label("Geometry: Valid" if mode_issues.is_empty() else "Geometry: Draft · %s" % mode_issues[0])
	mode_status.add_theme_color_override("font_color", Color("#75b88a") if mode_issues.is_empty() else Color("#f2c94c"))
	add_child(mode_status)
	if draw_mode == "contour":
		add_child(EditorWidgets.create_inspector_section("Drawing Reference", section_toggled.emit))
		add_child(EditorWidgets.create_inspector_field_label("Catch Parent"))
		var catch_parent_items: Array = [{"label": "None", "metadata": ""}]
		for candidate in asset.get("components", []):
			var candidate_id := str(candidate.get("id", ""))
			if candidate_id == selected_component_id:
				continue
			catch_parent_items.append({"label": str(candidate.get("name", "Component")), "metadata": candidate_id})
		add_child(EditorWidgets.create_option_field(catch_parent_items,
			str(component.get("catch_parent_component_id", "")), component_catch_parent_selected.emit))
	var component_group_id := ComponentHierarchy.membership_group_id(asset, selected_component_id)
	var show_global_transform := not component_group_id.is_empty()
	if inherited_region_geometry:
		# A Region that follows its Component owns no transform, so nothing is
		# built here. A grid created for this case would never get a parent, and
		# nothing in the editor would ever free it again.
		add_child(EditorWidgets.create_inspector_section("Transform", section_toggled.emit))
		add_child(EditorWidgets.create_inspector_field_label("Inherited 1:1 from the attached Component"))
	else:
		add_child(EditorWidgets.create_inspector_section("Global Transform" if show_global_transform else "Transform", section_toggled.emit))
		var transform_grid := GridContainer.new()
		transform_grid.columns = 2
		transform_grid.add_theme_constant_override("h_separation", 8)
		transform_grid.add_theme_constant_override("v_separation", 4)
		add_child(transform_grid)
		var transform: Dictionary = component.get("transform", WorldDocumentService.default_component_transform())
		var transform_position: Vector2 = transform.get("position", Vector2.ZERO)
		var transform_scale: Vector2 = transform.get("scale", Vector2.ONE)
		var pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
		if show_global_transform:
			var displayed_transform: Dictionary = ComponentHierarchy.world_transform_record(asset, selected_component_id)
			var displayed_position: Vector2 = displayed_transform.get("position", Vector2.ZERO)
			var global_scale: Vector2 = displayed_transform.get("scale", Vector2.ONE)
			# Global values are read-only echoes of the hierarchy, so the returned
			# fields are not kept: only local transform fields get live updates.
			EditorWidgets.build_number_grid(transform_grid,
				_component_transform_descriptors(ToolUnits.to_centimeters(displayed_position.x),
					ToolUnits.to_centimeters(displayed_position.y),
					float(displayed_transform.get("rotation", 0.0)), global_scale),
				global_transform_value_changed.emit)
		else:
			transform_fields = EditorWidgets.build_number_grid(transform_grid,
				_component_transform_descriptors(ToolUnits.to_centimeters(transform_position.x),
					ToolUnits.to_centimeters(transform_position.y),
					float(transform.get("rotation", 0.0)), transform_scale),
				transform_value_changed.emit)
		transform_fields.merge(EditorWidgets.build_number_grid(transform_grid, [
			{"caption": "Pivot X (cm)", "property": "pivot_x", "value": ToolUnits.to_centimeters(pivot.x),
				"step": 0.001, "silent": false},
			{"caption": "Pivot Y (cm)", "property": "pivot_y", "value": ToolUnits.to_centimeters(pivot.y),
				"step": 0.001, "silent": false},
		], transform_value_changed.emit), true)
	add_child(EditorWidgets.create_inspector_section("Constraint" if constraint_only_hole else "Visibility / Layer", section_toggled.emit))
	add_child(EditorWidgets.create_toggle_field(
		"Visible", bool(component.get("visibility", true)), component_visibility_changed.emit, 11))
	if constraint_only_hole:
		var hole_issue := WorldDocumentService.constraint_hole_parent_validation_issue(asset, component)
		var hole_hint := EditorWidgets.create_inspector_field_label(hole_issue if not hole_issue.is_empty() else "Cuts only its direct Parent · no Fill, Contour Stroke, or Runtime body")
		hole_hint.add_theme_color_override("font_color", Color("#ef8354") if not hole_issue.is_empty() else Color("#9aa3b2"))
		add_child(hole_hint)
		return
	EditorWidgets.add_stacked_number_field(self, {
		"caption": "Contour Stroke Width (px)", "value": WorldDocumentService.effective_contour_stroke_width_px(component, world_contour_stroke_width_px),
		"min": 0.1, "max": 1024.0, "step": 0.1, "font_size": 11,
		"tooltip": CONTOUR_STROKE_WIDTH_OVERRIDE_TOOLTIP if WorldDocumentService.is_reference_component(component) else "",
	}, component_contour_stroke_width_changed.emit)
	EditorWidgets.add_stacked_number_field(self, {
		"caption": "Projection Depth (cm)", "value": WorldDocumentService.projection_depth_cm(component),
		"min": 0.0, "max": 1000.0, "step": 0.1, "font_size": 11,
		"tooltip": PROJECTION_DEPTH_TOOLTIP,
	}, component_projection_depth_changed.emit)
	EditorWidgets.add_stacked_number_field(self, {
		"caption": "Z Order (Asset-local)", "value": int(component.get("z_index", 0)),
		"min": -10000.0, "max": 10000.0, "step": 1.0, "font_size": 11,
		"caption_tooltip": Z_ORDER_TOOLTIP, "tooltip": Z_ORDER_TOOLTIP,
	}, component_z_index_changed.emit)


func _component_transform_descriptors(position_x: float, position_y: float, rotation: float, scale: Vector2) -> Array:
	# One shape for the local and the global transform block. Rotation steps and
	# arrows in whole degrees; the other fields keep hundredth text precision with
	# tenth-unit arrows. None of them is silent: a few callers rely on the initial
	# value_changed.
	return [
		{"caption": "Position X (cm)", "property": "position_x", "value": position_x, "silent": false},
		{"caption": "Position Y (cm)", "property": "position_y", "value": position_y, "silent": false},
		{"caption": "Rotation", "property": "rotation", "value": rotation,
			"step": 1.0, "arrow_step": 1.0, "silent": false},
		{"caption": "Scale X", "property": "scale_x", "value": scale.x, "silent": false},
		{"caption": "Scale Y", "property": "scale_y", "value": scale.y, "silent": false},
	]


func _render_group_inspector(_asset: Dictionary, group: Dictionary) -> void:
	add_child(EditorWidgets.create_inspector_section("Group", section_toggled.emit))
	if group.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("Group not found."))
		return
	add_child(EditorWidgets.create_inspector_field_label("Name"))
	var name_editor := EditorWidgets.create_name_editor(str(group.get("name", "Group")), "Group name")
	name_editor.text_submitted.connect(group_rename_requested.emit)
	name_editor.focus_exited.connect(func() -> void: group_rename_requested.emit(name_editor.text))
	add_child(name_editor)
	add_child(EditorWidgets.create_inspector_section("Hierarchy", section_toggled.emit))
	add_child(EditorWidgets.create_inspector_field_label("Parent Component"))
	var group_parent_items: Array = [{"label": "Root", "metadata": ""}]
	for candidate in _asset.get("components", []):
		var candidate_id := str(candidate.get("id", ""))
		if not ComponentHierarchy.can_parent_group(_asset, str(group.get("id", "")), candidate_id):
			continue
		group_parent_items.append({"label": str(candidate.get("name", "Component")), "metadata": candidate_id})
	add_child(EditorWidgets.create_option_field(group_parent_items,
		ComponentHierarchy.group_parent_id(group), group_hierarchy_parent_selected.emit))
	add_child(EditorWidgets.create_inspector_section("Group Transform", section_toggled.emit))
	var transform_grid := GridContainer.new()
	transform_grid.columns = 2
	transform_grid.add_theme_constant_override("h_separation", 8)
	transform_grid.add_theme_constant_override("v_separation", 4)
	var transform: Dictionary = group.get("transform", WorldDocumentService.default_component_transform())
	var transform_position: Vector2 = transform.get("position", Vector2.ZERO)
	var transform_scale: Vector2 = transform.get("scale", Vector2.ONE)
	var pivot: Vector2 = transform.get("pivot", Vector2.ZERO)
	_add_group_transform_field(transform_grid, "Position X (cm)", ToolUnits.to_centimeters(transform_position.x), "position_x", 0.01)
	_add_group_transform_field(transform_grid, "Position Y (cm)", ToolUnits.to_centimeters(transform_position.y), "position_y", 0.01)
	_add_group_transform_field(transform_grid, "Rotation", float(transform.get("rotation", 0.0)), "rotation", 1.0)
	_add_group_transform_field(transform_grid, "Scale X", transform_scale.x, "scale_x", 0.01)
	_add_group_transform_field(transform_grid, "Scale Y", transform_scale.y, "scale_y", 0.01)
	_add_group_transform_field(transform_grid, "Pivot X (cm)", ToolUnits.to_centimeters(pivot.x), "pivot_x", 0.001)
	_add_group_transform_field(transform_grid, "Pivot Y (cm)", ToolUnits.to_centimeters(pivot.y), "pivot_y", 0.001)
	add_child(transform_grid)
	add_child(EditorWidgets.create_inspector_section("Group Visibility", section_toggled.emit))
	var visibility_toggle := CheckButton.new()
	visibility_toggle.text = "Visible"
	visibility_toggle.custom_minimum_size = Vector2(0, 26)
	visibility_toggle.button_pressed = bool(group.get("visibility", true))
	visibility_toggle.toggled.connect(group_visibility_changed.emit)
	add_child(visibility_toggle)


func _add_group_transform_field(grid: GridContainer, label_text: String, value: float, property_name: String, step: float) -> void:
	var label := EditorWidgets.create_inspector_field_label(label_text)
	grid.add_child(label)
	var field := SpinBox.new()
	field.min_value = -100000.0
	field.max_value = 100000.0
	field.step = step
	field.custom_arrow_step = step
	field.value = value
	field.custom_minimum_size = Vector2(96, 26)
	field.add_theme_font_size_override("font_size", 11)
	field.value_changed.connect(group_transform_value_changed.emit.bind(property_name))
	grid.add_child(field)


func _render_guide_inspector(asset: Dictionary, guide: Dictionary) -> void:
	add_child(EditorWidgets.create_inspector_section("Guide", section_toggled.emit))
	if guide.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("Guide not found."))
		return
	if AssetGuide.is_weapon_frame(str(guide.get("guide_type", ""))):
		_render_weapon_guide_inspector(asset, guide)
		return
	add_child(EditorWidgets.create_inspector_field_label("Name"))
	add_child(EditorWidgets.create_inspector_field_label(WorldDocumentService.guide_display_name(asset, guide)))
	add_child(EditorWidgets.create_inspector_field_label("Type"))
	add_child(EditorWidgets.create_option_field([
		{"label": "Flow", "metadata": AssetGuide.BODY_FLOW},
		{"label": "Sample", "metadata": AssetGuide.SAMPLER_SPINE},
		{"label": "Motion", "metadata": AssetGuide.ANIMATION_SPINE},
	], str(guide.get("guide_type", AssetGuide.BODY_FLOW)), guide_type_selected.emit, false))
	add_child(EditorWidgets.create_inspector_field_label("Parent Component"))
	var target_id := str(guide.get("scope", {}).get("component_id", ""))
	var target_name := "Missing Component"
	for component in asset.get("components", []):
		if str(component.get("type", "component")) == "guide":
			continue
		if str(component.get("id", "")) == target_id:
			target_name = str(component.get("name", "Component"))
	add_child(EditorWidgets.create_inspector_field_label(target_name))
	var visible_toggle := CheckBox.new()
	visible_toggle.text = "Visible"
	visible_toggle.button_pressed = bool(guide.get("visibility", true))
	visible_toggle.toggled.connect(guide_visibility_changed.emit)
	add_child(visible_toggle)
	add_child(EditorWidgets.create_inspector_section("Topology", section_toggled.emit))
	add_child(EditorWidgets.create_inspector_field_label("Open Spine · %d Points" % guide.get("points", []).size()))
	var status := "Ready" if AssetGuide.validation_issues(guide).is_empty() else "Ready to draw" if guide.get("points", []).is_empty() else "Invalid"
	if WorldDocumentService.component_by_id(asset, target_id).is_empty():
		status = "Unassigned"
	add_child(EditorWidgets.create_inspector_field_label("Status: %s" % status))
	var delete_button := Button.new()
	delete_button.text = "Delete Guide"
	delete_button.focus_mode = Control.FOCUS_NONE
	delete_button.pressed.connect(guide_delete_requested.emit)
	add_child(delete_button)


func _render_weapon_guide_inspector(asset: Dictionary, guide: Dictionary) -> void:
	add_child(EditorWidgets.create_inspector_field_label(str(guide.get("guide_type", ""))))
	var scope: Dictionary = guide.get("scope", {})
	var scope_kind := str(scope.get("kind", "component"))
	var scope_id := str(scope.get("group_id", "")) if scope_kind == "group" else str(scope.get("component_id", ""))
	var scope_record := ComponentHierarchy.group_by_id(asset, scope_id) if scope_kind == "group" else WorldDocumentService.component_by_id(asset, scope_id)
	add_child(EditorWidgets.create_inspector_field_label("Parent %s: %s" % [scope_kind.capitalize(), str(scope_record.get("name", "Missing"))]))
	add_child(EditorWidgets.create_inspector_section("Local Frame", section_toggled.emit))
	var transform: Dictionary = guide.get("transform", WorldDocumentService.default_component_transform())
	var grid := GridContainer.new()
	grid.columns = 2
	_add_weapon_frame_field(grid, "Position X (cm)", ToolUnits.to_centimeters(Vector2(transform.get("position", Vector2.ZERO)).x), "position_x")
	_add_weapon_frame_field(grid, "Position Y (cm)", ToolUnits.to_centimeters(Vector2(transform.get("position", Vector2.ZERO)).y), "position_y")
	_add_weapon_frame_field(grid, "Rotation (deg)", float(transform.get("rotation", 0.0)), "rotation")
	add_child(grid)
	var status := EditorWidgets.create_inspector_field_label("Frame: Valid" if AssetGuide.validation_issues(guide).is_empty() and not scope_record.is_empty() else "Frame: Invalid or unassigned")
	status.add_theme_color_override("font_color", Color("#75b88a") if AssetGuide.validation_issues(guide).is_empty() and not scope_record.is_empty() else Color("#ef6c78"))
	add_child(status)
	var delete_button := Button.new()
	delete_button.text = "Delete Weapon Guide"
	delete_button.pressed.connect(guide_delete_requested.emit)
	add_child(delete_button)


func _add_weapon_frame_field(grid: GridContainer, label_text: String, value: float, property_name: String) -> void:
	grid.add_child(EditorWidgets.create_inspector_field_label(label_text))
	var field := SpinBox.new()
	field.min_value = -100000.0
	field.max_value = 100000.0
	field.step = 0.1
	field.set_value_no_signal(value)
	field.value_changed.connect(weapon_frame_value_changed.emit.bind(property_name))
	grid.add_child(field)


func _render_multi_component_inspector(asset: Dictionary, components: Array[Dictionary]) -> void:
	add_child(EditorWidgets.create_inspector_field_label("%d Components" % components.size()))
	add_child(EditorWidgets.create_inspector_section("Multi-Edit", section_toggled.emit))
	var positions: Array[Vector2] = []
	for component in components:
		var component_id := str(component.get("id", ""))
		var world_record := ComponentHierarchy.world_transform_record(asset, component_id)
		positions.append(Vector2(world_record.get("position", Vector2.ZERO)) - WorldDocumentService.asset_pivot(asset))
	var position_grid := GridContainer.new()
	position_grid.columns = 2
	position_grid.add_theme_constant_override("h_separation", 8)
	position_grid.add_theme_constant_override("v_separation", 4)
	var position_x := ToolUnits.to_centimeters(positions[0].x)
	var position_y := ToolUnits.to_centimeters(positions[0].y)
	var x_mixed := false
	var y_mixed := false
	for candidate_position in positions.slice(1):
		x_mixed = x_mixed or not is_equal_approx(candidate_position.x, positions[0].x)
		y_mixed = y_mixed or not is_equal_approx(candidate_position.y, positions[0].y)
	_add_multi_component_position_field(position_grid, "Position X (cm) · Asset", position_x, x_mixed, "position_x")
	_add_multi_component_position_field(position_grid, "Position Y (cm) · Asset", position_y, y_mixed, "position_y")
	add_child(position_grid)

	var visibility_values: Array[bool] = []
	var z_values: Array[int] = []
	var width_values: Array[float] = []
	var projection_depth_values: Array[float] = []
	for component in components:
		visibility_values.append(bool(component.get("visibility", true)))
		z_values.append(int(component.get("z_index", 0)))
		width_values.append(WorldDocumentService.effective_contour_stroke_width_px(component, world_contour_stroke_width_px))
		projection_depth_values.append(WorldDocumentService.projection_depth_cm(component))
	var visibility_option := OptionButton.new()
	visibility_option.name = "MultiVisibility"
	visibility_option.custom_minimum_size = Vector2(0, 26)
	visibility_option.add_item("Visible")
	visibility_option.set_item_metadata(0, true)
	visibility_option.add_item("Hidden")
	visibility_option.set_item_metadata(1, false)
	visibility_option.add_item("Mixed")
	visibility_option.set_item_metadata(2, null)
	var visibility_mixed := false
	for value in visibility_values.slice(1):
		visibility_mixed = visibility_mixed or value != visibility_values[0]
	visibility_option.select(2 if visibility_mixed else (0 if visibility_values[0] else 1))
	visibility_option.item_selected.connect(multi_component_visibility_selected.emit)
	add_child(EditorWidgets.create_inspector_field_label("Visibility"))
	add_child(visibility_option)

	var z_mixed := false
	for value in z_values.slice(1):
		z_mixed = z_mixed or value != z_values[0]
	_multi_component_line_edit("Z Order (Asset-local)", str(z_values[0]), z_mixed, "MultiZIndex", "z_index", true)
	var width_mixed := false
	for value in width_values.slice(1):
		width_mixed = width_mixed or not is_equal_approx(value, width_values[0])
	_multi_component_line_edit("Contour Stroke Width (px)", str(width_values[0]), width_mixed, "MultiContourWidth", "contour_width", false)
	var projection_depth_mixed := false
	for value in projection_depth_values.slice(1):
		projection_depth_mixed = projection_depth_mixed or not is_equal_approx(value, projection_depth_values[0])
	_multi_component_line_edit("Projection Depth (cm)", str(projection_depth_values[0]), projection_depth_mixed, "MultiProjectionDepth", "projection_depth", false)


func _add_multi_component_position_field(grid: GridContainer, label_text: String, value: float, mixed: bool, axis: String) -> void:
	grid.add_child(EditorWidgets.create_inspector_field_label(label_text))
	var field := LineEdit.new()
	field.name = "MultiPositionX" if axis == "position_x" else "MultiPositionY"
	field.custom_minimum_size = Vector2(0, 26)
	field.text = "" if mixed else str(value)
	field.placeholder_text = "Mixed" if mixed else ""
	field.tooltip_text = "Asset-relative position from the Asset pivot (0, 0)."
	field.add_theme_font_size_override("font_size", 11)
	field.text_submitted.connect(multi_component_field_submitted.emit.bind(field, axis, false))
	field.focus_exited.connect(multi_component_field_focus_exited.emit.bind(field, axis, false))
	grid.add_child(field)


func _multi_component_line_edit(label_text: String, value_text: String, is_mixed: bool, field_name: String, axis: String, integer_only := false) -> LineEdit:
	add_child(EditorWidgets.create_inspector_field_label(label_text))
	var field := LineEdit.new()
	field.name = field_name
	field.custom_minimum_size = Vector2(0, 26)
	field.text = "" if is_mixed else value_text
	field.placeholder_text = "Mixed" if is_mixed else ""
	field.tooltip_text = "Leave unchanged for mixed values; enter a value to apply it to all selected Components."
	field.add_theme_font_size_override("font_size", 11)
	field.text_submitted.connect(multi_component_field_submitted.emit.bind(field, axis, integer_only))
	field.focus_exited.connect(multi_component_field_focus_exited.emit.bind(field, axis, integer_only))
	add_child(field)
	return field


func _render_asset_root_scale_rebase_inspector(asset: Dictionary) -> void:
	add_child(EditorWidgets.create_inspector_section("Asset Transform Rebase", section_toggled.emit))
	var analysis := AssetScaleRebaseService.analyze_asset(asset)
	var blockers: Array = analysis.get("blockers", [])
	if bool(analysis.get("required", false)):
		var root_position := Vector2(analysis.get("position", Vector2.ZERO))
		add_child(EditorWidgets.create_inspector_field_label("Position %s × %s cm → 0 × 0 cm" % [EditorWidgets.format_scale_value(ToolUnits.to_centimeters(root_position.x)), EditorWidgets.format_scale_value(ToolUnits.to_centimeters(root_position.y))]))
		var root_scale := Vector2(analysis.get("scale", Vector2.ONE))
		add_child(EditorWidgets.create_inspector_field_label("Scale %s × %s → 1 × 1" % [EditorWidgets.format_scale_value(root_scale.x), EditorWidgets.format_scale_value(root_scale.y)]))
	else:
		add_child(EditorWidgets.create_inspector_field_label("Root Position and Scale are normalized."))
	for blocker in blockers:
		var blocker_label := EditorWidgets.create_inspector_field_label("• Blocked: %s" % str(blocker))
		blocker_label.add_theme_color_override("font_color", Color("#ef8354"))
		add_child(blocker_label)
	asset_root_scale_rebase_button = Button.new()
	asset_root_scale_rebase_button.text = "Rebase Asset Transform"
	asset_root_scale_rebase_button.custom_minimum_size = Vector2(0, 28)
	asset_root_scale_rebase_button.focus_mode = Control.FOCUS_NONE
	asset_root_scale_rebase_button.disabled = not bool(analysis.get("can_rebase", false))
	asset_root_scale_rebase_button.tooltip_text = "Bake Root Position and independent X/Y Scale into Components, Groups, References, Guides, and Weapon Frames." if blockers.is_empty() else str(blockers[0])
	asset_root_scale_rebase_button.pressed.connect(asset_root_scale_rebase_requested.emit)
	add_child(asset_root_scale_rebase_button)


func _render_asset_scale_rebase_inspector(asset: Dictionary) -> void:
	add_child(EditorWidgets.create_inspector_section("Component Scale Rebase", section_toggled.emit))
	var analysis := ComponentScaleRebaseService.analyze_asset(asset)
	var candidates: Array = analysis.get("candidates", [])
	var blockers: Array = analysis.get("blockers", [])
	if candidates.is_empty() and blockers.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("All Component scales are normalized (1 × 1)."))
	for candidate in candidates:
		var component_scale := Vector2(candidate.get("scale", Vector2.ONE))
		var suffix := " · Circle → Ellipse" if str(candidate.get("result_primitive_type", "")) == PrimitiveGeometryService.ELLIPSE else ""
		add_child(EditorWidgets.create_inspector_field_label("• %s · %s × %s → 1 × 1%s" % [
			str(candidate.get("name", "Component")),
			EditorWidgets.format_scale_value(component_scale.x),
			EditorWidgets.format_scale_value(component_scale.y),
			suffix
		]))
	for blocker in blockers:
		var blocker_label := EditorWidgets.create_inspector_field_label("• %s · Blocked: %s" % [str(blocker.get("name", "Component")), str(blocker.get("reason", "Scale cannot be rebased."))])
		blocker_label.add_theme_color_override("font_color", Color("#ef8354"))
		add_child(blocker_label)
	asset_scale_rebase_button = Button.new()
	asset_scale_rebase_button.text = "Rebase Scales (%d)" % candidates.size()
	asset_scale_rebase_button.custom_minimum_size = Vector2(0, 28)
	asset_scale_rebase_button.focus_mode = Control.FOCUS_NONE
	asset_scale_rebase_button.disabled = not bool(analysis.get("can_rebase", false))
	asset_scale_rebase_button.tooltip_text = "Bake finite, non-zero Component and Group Scale, including Mirror signs, into canonical geometry while preserving visible transforms." if blockers.is_empty() else "Resolve every listed blocker before rebasing this Asset atomically."
	asset_scale_rebase_button.pressed.connect(asset_scales_rebase_requested.emit)
	add_child(asset_scale_rebase_button)


func _add_selected_point_settings(component: Dictionary, point_ids: Array[String]) -> void:
	var shared_mode := ""
	var mode_mixed := false
	var shared_preserve := false
	var preserve_mixed := false
	var shared_handle_source := ""
	var shared_handle_in := Vector2.ZERO
	var shared_handle_out := Vector2.ZERO
	var handles_mixed := false
	for selection_index in range(point_ids.size()):
		var point := BezierTopology.point_by_id(component.get("points", []), point_ids[selection_index])
		if point.is_empty():
			continue
		var point_mode := str(point.get("mode", "linear"))
		var point_preserve := bool(point.get("preserve_point", point_mode == "corner"))
		var handle_source := str(point.get("handle_source", "auto"))
		var handle_in: Vector2 = point.get("handle_in", Vector2.ZERO)
		var handle_out: Vector2 = point.get("handle_out", Vector2.ZERO)
		if selection_index == 0:
			shared_mode = point_mode
			shared_preserve = point_preserve
			shared_handle_source = handle_source
			shared_handle_in = handle_in
			shared_handle_out = handle_out
			continue
		mode_mixed = mode_mixed or point_mode != shared_mode
		preserve_mixed = preserve_mixed or point_preserve != shared_preserve
		handles_mixed = handles_mixed \
			or handle_source != shared_handle_source \
			or not handle_in.is_equal_approx(shared_handle_in) \
			or not handle_out.is_equal_approx(shared_handle_out)
	add_child(EditorWidgets.create_inspector_field_label("Handle Mode"))
	var point_mode_option := OptionButton.new()
	point_mode_option.custom_minimum_size = Vector2(0, 26)
	if mode_mixed:
		point_mode_option.add_item("- Mixed -")
		point_mode_option.set_item_metadata(0, "")
		point_mode_option.set_item_disabled(0, true)
	for mode_data in [["Linear", "linear"], ["Aligned", "aligned"], ["Free", "free"], ["Mirrored", "mirrored"], ["Corner", "corner"]]:
		point_mode_option.add_item(str(mode_data[0]))
		point_mode_option.set_item_metadata(point_mode_option.item_count - 1, str(mode_data[1]))
	if mode_mixed:
		point_mode_option.select(0)
	else:
		for mode_index in range(point_mode_option.item_count):
			if str(point_mode_option.get_item_metadata(mode_index)) == shared_mode:
				point_mode_option.select(mode_index)
				break
	point_mode_option.item_selected.connect(selected_points_mode_selected.emit.bind(point_mode_option, point_ids.duplicate()))
	add_child(point_mode_option)
	var preserve_point := CheckBox.new()
	preserve_point.text = "Preserve Point" if not preserve_mixed else "Preserve Point: - Mixed -"
	preserve_point.button_pressed = shared_preserve if not preserve_mixed else false
	preserve_point.toggled.connect(selected_points_preserve_changed.emit.bind(point_ids.duplicate()))
	add_child(preserve_point)
	var handles_label := "Handles: - Mixed -" if handles_mixed else "Handles: %s" % ("Manual" if shared_handle_source == "manual" else "Auto")
	add_child(EditorWidgets.create_inspector_field_label(handles_label))


func _add_ellipse_diameter_field(label_text: String, value: float, property_name: String) -> void:
	add_child(EditorWidgets.create_inspector_field_label(label_text))
	var field := SpinBox.new()
	field.min_value = 0.1
	field.max_value = 100000.0
	field.step = 0.1
	field.value = value
	field.value_changed.connect(ellipse_primitive_diameter_changed.emit.bind(property_name))
	add_child(field)


func _add_component_debug_inspector(component: Dictionary) -> void:
	add_child(EditorWidgets.create_inspector_section("Debug", section_toggled.emit))
	var show_numbers := CheckButton.new()
	show_numbers.text = "Show Point Numbers"
	show_numbers.focus_mode = Control.FOCUS_NONE
	show_numbers.button_pressed = bool(component.get("show_point_numbers", false))
	show_numbers.toggled.connect(component_debug_point_numbers_toggled.emit)
	add_child(show_numbers)
