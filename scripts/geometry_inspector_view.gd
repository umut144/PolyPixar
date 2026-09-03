class_name GeometryInspectorView
extends VBoxContainer

# The Mesh module's Inspector, under the same contract as OutlinerView and
# CreateInspectorView: main.gd resolves everything against the Geometry
# documents and the preview caches, pushes the result in as one Dictionary per
# submodule, and rebuild() draws from that alone.
#
# Sampling context keys: component, recipe, display_result, status,
#   boundary_rows ({title, input_id, role, kind}), selected_input_id,
#   selected_input_title.
# Seeding context keys: component, recipe, sampling_bake,
#   sampling_bake_is_current, status, result, spine_rows ({guide_id, label}),
#   advanced_pattern_expanded.
# Meshing context keys: component, recipe, source_issues, sampling_bake_is_current,
#   seeding_bakes, input_is_current, meshing_input, view_options
#   ({key, label, value}), build_diagnostic_lines, status, auto_build_error,
#   result, advanced_relaxation_expanded, and for a Contour Component
#   contour_status and contour_result.
#
# As with the Create view the intent signals still carry the argument lists of
# the handlers they replaced.

signal meshing_advanced_relaxation_toggled(expanded: bool)
signal meshing_bake_requested()
signal meshing_float_focus_exited(field: SpinBox, parameter_name: String)
signal meshing_float_text_submitted(text: String, field: SpinBox, parameter_name: String)
signal meshing_override_changed(enabled: bool, parameter_name: String)
signal meshing_parameter_changed(value: float, parameter_name: String)
signal meshing_seed_source_selected(index: int, option: OptionButton)
signal meshing_view_option_changed(enabled: bool, option: String)
signal sampling_bake_requested()
signal sampling_feature_detail_changed(percent: float)
signal sampling_parameter_changed(value: float, parameter_name: String)
signal sampling_refinement_changed(value: float, input_id: String)
signal sampling_refinement_toggled(enabled: bool, input_id: String)
signal sampling_spacing_focus_exited(spacing: SpinBox)
signal sampling_spacing_text_submitted(text: String, spacing: SpinBox)
signal section_toggled(section: VBoxContainer, text: String, header: Button)
signal seeding_advanced_pattern_toggled(expanded: bool)
signal seeding_bake_requested()
signal seeding_boundary_override_changed(enabled: bool)
signal seeding_fill_gaps_changed(enabled: bool)
signal seeding_float_focus_exited(field: SpinBox, parameter_name: String)
signal seeding_float_text_submitted(text: String, field: SpinBox, parameter_name: String)
signal seeding_method_selected(index: int, option: OptionButton)
signal seeding_parameter_changed(value: float, parameter_name: String)
signal seeding_spine_enabled_changed(enabled: bool, guide_id: String)
signal seeding_stagger_override_changed(enabled: bool)
signal sampling_hole_selected(hole_id: String)
signal sampling_cut_selected(guide_id: String)

var active_submodule := ""
var world_contour_stroke_width_px := 2.0
var sampling_context: Dictionary = {}
var seeding_context: Dictionary = {}
var meshing_context: Dictionary = {}
var advanced_pattern_expanded := false
var advanced_relaxation_expanded := false

var sampling_bake_button: Button
var seeding_bake_button: Button
var meshing_bake_button: Button


func set_submodule(submodule: String, contour_stroke_width_px: float) -> void:
	active_submodule = submodule
	world_contour_stroke_width_px = contour_stroke_width_px


func set_sampling_context(context: Dictionary) -> void:
	sampling_context = context


func set_seeding_context(context: Dictionary) -> void:
	seeding_context = context
	advanced_pattern_expanded = bool(context.get("advanced_pattern_expanded", false))


func set_meshing_context(context: Dictionary) -> void:
	meshing_context = context
	advanced_relaxation_expanded = bool(context.get("advanced_relaxation_expanded", false))


func rebuild() -> void:
	EditorWidgets.clear(self)
	sampling_bake_button = null
	seeding_bake_button = null
	meshing_bake_button = null
	if active_submodule == "Sampling":
		_render_sampling()
	elif active_submodule == "Seeding":
		_render_seeding()
	elif active_submodule == "Meshing":
		_render_meshing()
	else:
		add_child(EditorWidgets.create_inspector_section(active_submodule, section_toggled.emit))
		add_child(EditorWidgets.create_inspector_field_label("Placeholder module"))
		add_child(EditorWidgets.create_inspector_field_label("Mesh pipeline tooling is planned for a later phase."))


func _seeding_spine_enabled(recipe: Dictionary, guide_id: String) -> bool:
	for input in recipe.get("parameters", {}).get("spine_inputs", []):
		if input is Dictionary and str(input.get("guide_id", "")) == guide_id:
			return bool(input.get("enabled", true))
	return false


func _sampling_input_has_override(recipe: Dictionary, input_id: String) -> bool:
	return not input_id.is_empty() and recipe.get("parameters", {}).get("boundary_refinements", {}).has(input_id)


func _bake_method_label(method: String) -> String:
	if method == GeometrySamplingService.ADAPTIVE:
		return "Adaptive"
	if method == GeometrySamplingService.EVEN_SPACING:
		return "Even Spacing"
	if method == GeometrySeedingService.SPINE_FLOW:
		return "Spine Flow"
	if method in [GeometryMeshingService.CONSTRAINED_MESH, GeometryMeshingService.CONSTRAINED_DELAUNAY, GeometryMeshingService.ORGANIC_RELAXED]:
		return "Constrained Mesh"
	if method == ContourMeshService.METHOD:
		return "Contour Stroke"
	return "Poisson Fill"


func _render_sampling() -> void:
	var component: Dictionary = sampling_context.get("component", {})
	if component.is_empty():
		add_child(EditorWidgets.create_inspector_section("Sampling", section_toggled.emit))
		add_child(EditorWidgets.create_inspector_field_label("Select one Component to configure its boundary sampling."))
		return
	add_child(EditorWidgets.create_inspector_section("Boundary Sampling · %s" % str(component.get("name", "Component")), section_toggled.emit))
	add_child(EditorWidgets.create_inspector_field_label("One adaptive Body recipe shared by Outer, Holes, and Cuts."))
	var base_recipe: Dictionary = sampling_context.get("recipe", {})
	add_child(EditorWidgets.create_inspector_field_label("Target Edge Length (Body units)"))
	var spacing := SpinBox.new()
	spacing.min_value = GeometrySamplingService.MIN_SPACING
	spacing.max_value = 10000.0
	spacing.step = 0.01
	spacing.custom_arrow_step = 0.01
	spacing.set_value_no_signal(float(base_recipe.get("parameters", {}).get("spacing", GeometrySamplingService.DEFAULT_SPACING)))
	spacing.value_changed.connect(sampling_parameter_changed.emit.bind("spacing"))
	spacing.get_line_edit().text_submitted.connect(sampling_spacing_text_submitted.emit.bind(spacing))
	spacing.get_line_edit().focus_exited.connect(sampling_spacing_focus_exited.emit.bind(spacing))
	add_child(spacing)
	add_child(EditorWidgets.create_inspector_field_label("Curve Detail"))
	var feature_detail := SpinBox.new()
	feature_detail.min_value = 0.0
	feature_detail.max_value = 100.0
	feature_detail.step = 5.0
	feature_detail.suffix = "%"
	feature_detail.set_value_no_signal(float(base_recipe.get("parameters", {}).get("feature_detail", GeometrySamplingService.DEFAULT_FEATURE_DETAIL)) * 100.0)
	feature_detail.value_changed.connect(sampling_feature_detail_changed.emit)
	add_child(feature_detail)

	var display_result: Dictionary = sampling_context.get("display_result", {})
	add_child(EditorWidgets.create_inspector_section("Boundary Inputs", section_toggled.emit))
	_boundary_row("Outer · %s" % str(component.get("name", "Component")), "", "outer", base_recipe, display_result, "")
	for row in sampling_context.get("boundary_rows", []):
		_boundary_row(str(row.get("title", "")), str(row.get("input_id", "")), str(row.get("role", "")),
			base_recipe, display_result, str(row.get("kind", "")))

	if not str(sampling_context.get("selected_input_id", "")).is_empty():
		_render_sampling_refinement(base_recipe)

	var status := str(sampling_context.get("status", ""))
	add_child(EditorWidgets.create_inspector_section("Result", section_toggled.emit))
	add_child(EditorWidgets.create_inspector_field_label("Status: %s" % status))
	if not display_result.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("Constraint Samples: %d" % int(display_result.get("constraint_sample_count", display_result.get("sample_count", 0)))))
		add_child(EditorWidgets.create_inspector_field_label("Preserved Points: %d" % int(display_result.get("preserve_count", 0))))
	var actions := HBoxContainer.new()
	var bake_button := Button.new()
	bake_button.text = "Calculating…" if status == "Calculating" else "Baked" if status == "Baked" else "Bake Preview"
	bake_button.custom_minimum_size = Vector2(96, 28)
	bake_button.focus_mode = Control.FOCUS_NONE
	bake_button.disabled = status != "Preview Ready"
	bake_button.pressed.connect(sampling_bake_requested.emit)
	sampling_bake_button = bake_button
	actions.add_child(bake_button)
	add_child(actions)


func _boundary_row(title: String, input_id: String, role: String, recipe: Dictionary, result: Dictionary, kind: String) -> void:
	var count := 0
	for stat in result.get("boundary_stats", []):
		if str(stat.get("input_id", "")) == input_id and str(stat.get("role", "")) == role:
			count += int(stat.get("sample_count", 0))
	var refinement: Dictionary = recipe.get("parameters", {}).get("boundary_refinements", {}).get(input_id, {})
	var factor := float(refinement.get("factor", 1.0))
	var has_adjustment := _sampling_input_has_override(recipe, input_id)
	var button := Button.new()
	button.text = "%s  ·  %s%s" % [title, "Density %s×" % EditorWidgets.format_scale_value(factor) if has_adjustment else "Inherited", "  ·  %d" % count if count > 0 else ""]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	# An Outer row has no kind and stays inert; the other two carry the id their
	# intent needs.
	button.disabled = kind.is_empty()
	if kind == "hole":
		button.pressed.connect(sampling_hole_selected.emit.bind(input_id))
	elif kind == "cut":
		button.pressed.connect(sampling_cut_selected.emit.bind(input_id))
	add_child(button)


func _render_sampling_refinement(recipe: Dictionary) -> void:
	var selected_input_id := str(sampling_context.get("selected_input_id", ""))
	var input_title := str(sampling_context.get("selected_input_title", ""))
	if input_title.is_empty():
		return
	add_child(EditorWidgets.create_inspector_section("Boundary Density · %s" % input_title, section_toggled.emit))
	var refinement: Dictionary = recipe.get("parameters", {}).get("boundary_refinements", {}).get(selected_input_id, {})
	var factor := float(refinement.get("factor", 1.0))
	var has_adjustment := _sampling_input_has_override(recipe, selected_input_id)
	var toggle := CheckBox.new()
	toggle.text = "Adjust this Boundary"
	toggle.button_pressed = has_adjustment
	toggle.toggled.connect(sampling_refinement_toggled.emit.bind(selected_input_id))
	add_child(toggle)
	var effective_spacing := float(recipe.get("parameters", {}).get("spacing", GeometrySamplingService.DEFAULT_SPACING)) / factor
	add_child(EditorWidgets.create_inspector_field_label("Effective Edge Length: %.2f" % effective_spacing))
	if has_adjustment:
		add_child(EditorWidgets.create_inspector_field_label("Density Factor · below 1× is coarser"))
		var factor_input := SpinBox.new()
		factor_input.min_value = GeometrySamplingService.MIN_REFINEMENT_FACTOR
		factor_input.max_value = GeometrySamplingService.MAX_REFINEMENT_FACTOR
		factor_input.step = 0.25
		factor_input.suffix = "×"
		factor_input.set_value_no_signal(factor)
		factor_input.value_changed.connect(sampling_refinement_changed.emit.bind(selected_input_id))
		add_child(factor_input)


func _render_seeding() -> void:
	var component: Dictionary = seeding_context.get("component", {})
	if component.is_empty():
		add_child(EditorWidgets.create_inspector_section("Seeding", section_toggled.emit))
		add_child(EditorWidgets.create_inspector_field_label("Select one Component to configure its interior seeding."))
		return
	add_child(EditorWidgets.create_inspector_section("Seeding · %s" % str(component.get("name", "Component")), section_toggled.emit))
	add_child(EditorWidgets.create_inspector_field_label("One derived Seed set from the accepted Sampling constraints."))
	var upstream_current := bool(seeding_context.get("sampling_bake_is_current", false))
	add_child(EditorWidgets.create_inspector_section("Input", section_toggled.emit))
	var input_label := EditorWidgets.create_inspector_field_label("Sampling · Adaptive: %s" % ("Baked" if upstream_current else "Required / Stale"))
	input_label.add_theme_color_override("font_color", Color("#75b88a") if upstream_current else Color("#ef8354"))
	add_child(input_label)
	var recipe: Dictionary = seeding_context.get("recipe", {})
	var sampling_bake: Dictionary = seeding_context.get("sampling_bake", {})
	add_child(EditorWidgets.create_inspector_field_label("Method"))
	# Anything that is not Poisson Fill is shown as Spine Flow, which is what the
	# original index arithmetic did.
	var seeding_method := GeometrySeedingService.POISSON_FILL if str(recipe.get("method", "")) == GeometrySeedingService.POISSON_FILL else GeometrySeedingService.SPINE_FLOW
	add_child(EditorWidgets.create_option_field([
		{"label": "Poisson Fill", "metadata": GeometrySeedingService.POISSON_FILL},
		{"label": "Spine Flow", "metadata": GeometrySeedingService.SPINE_FLOW},
	], seeding_method, seeding_method_selected.emit, false))
	add_child(EditorWidgets.create_inspector_section("Parameters", section_toggled.emit))
	if str(recipe.get("method", "")) == GeometrySeedingService.SPINE_FLOW:
		var sampler_guides: Array = seeding_context.get("spine_rows", [])
		add_child(EditorWidgets.create_inspector_field_label("Active Sampler Spines"))
		for guide in sampler_guides:
			var guide_id := str(guide.get("guide_id", ""))
			var enabled := _seeding_spine_enabled(recipe, guide_id)
			var toggle := CheckBox.new()
			toggle.text = str(guide.get("label", ""))
			toggle.button_pressed = enabled
			toggle.toggled.connect(seeding_spine_enabled_changed.emit.bind(guide_id))
			add_child(toggle)
		if sampler_guides.is_empty():
			var missing_guide := EditorWidgets.create_inspector_field_label("Create and author a Sampler Spine on this Component.")
			missing_guide.add_theme_color_override("font_color", Color("#ef8354"))
			add_child(missing_guide)
		_seeding_float_parameter("Seed Spacing (Body units)", recipe, "spacing", GeometrySeedingService.MIN_SPACING, 10000.0)
		_seeding_float_parameter("Flow Stretch", recipe, "flow_stretch", GeometrySeedingService.MIN_FLOW_STRETCH, GeometrySeedingService.MAX_FLOW_STRETCH, "×")
		var fill_gaps := CheckBox.new()
		fill_gaps.text = "Fill Gaps"
		fill_gaps.button_pressed = bool(recipe.get("parameters", {}).get("fill_gaps", GeometrySeedingService.DEFAULT_FILL_GAPS))
		fill_gaps.toggled.connect(seeding_fill_gaps_changed.emit)
		add_child(fill_gaps)
		var parameters: Dictionary = recipe.get("parameters", {})
		var boundary_override := bool(parameters.get("boundary_clearance_override", false))
		var boundary_clearance := float(parameters.get("boundary_clearance", GeometrySeedingService.DEFAULT_BOUNDARY_CLEARANCE))
		add_child(EditorWidgets.create_inspector_field_label("Boundary Margin: %s · %s" % ["Refined" if boundary_override else "Auto", EditorWidgets.format_scale_value(boundary_clearance)]))
		var refine_boundary := CheckBox.new()
		refine_boundary.text = "Refine Boundary Margin"
		refine_boundary.button_pressed = boundary_override
		refine_boundary.toggled.connect(seeding_boundary_override_changed.emit)
		add_child(refine_boundary)
		if boundary_override:
			_seeding_float_parameter("Boundary Margin Override", recipe, "boundary_clearance", 0.0, 10000.0)
		var advanced_pattern := Button.new()
		advanced_pattern.text = "%s Advanced Pattern" % ("▾" if advanced_pattern_expanded else "▸")
		advanced_pattern.toggle_mode = true
		advanced_pattern.button_pressed = advanced_pattern_expanded
		advanced_pattern.alignment = HORIZONTAL_ALIGNMENT_LEFT
		advanced_pattern.focus_mode = Control.FOCUS_NONE
		advanced_pattern.toggled.connect(seeding_advanced_pattern_toggled.emit)
		add_child(advanced_pattern)
		if advanced_pattern_expanded:
			add_child(EditorWidgets.create_inspector_field_label("Along Spacing: Derived · %s" % EditorWidgets.format_scale_value(float(parameters.get("along_spacing", GeometrySeedingService.DEFAULT_ALONG_SPACING)))))
			add_child(EditorWidgets.create_inspector_field_label("Across Spacing: Derived · %s" % EditorWidgets.format_scale_value(float(parameters.get("across_spacing", GeometrySeedingService.DEFAULT_ACROSS_SPACING)))))
			var stagger_override := bool(parameters.get("stagger_override", false))
			var stagger := float(parameters.get("stagger", GeometrySeedingService.DEFAULT_ARTISTIC_STAGGER))
			add_child(EditorWidgets.create_inspector_field_label("Stagger: %s · %s" % ["Refined" if stagger_override else "Auto", EditorWidgets.format_scale_value(stagger)]))
			var refine_stagger := CheckBox.new()
			refine_stagger.text = "Refine Stagger"
			refine_stagger.button_pressed = stagger_override
			refine_stagger.toggled.connect(seeding_stagger_override_changed.emit)
			add_child(refine_stagger)
			if stagger_override:
				_seeding_float_parameter("Stagger Override", recipe, "stagger", 0.0, 1.0)
	else:
		_seeding_float_parameter("Seed Spacing (Body units)", recipe, "spacing", GeometrySeedingService.MIN_SPACING, 10000.0)
		var clearance := float(recipe.get("parameters", {}).get("spacing", GeometrySeedingService.DEFAULT_SPACING)) * float(recipe.get("parameters", {}).get("constraint_clearance_factor", GeometrySeedingService.DEFAULT_CONSTRAINT_CLEARANCE_FACTOR))
		add_child(EditorWidgets.create_inspector_field_label("Constraint Clearance: Auto · %.2f" % clearance))
	if str(recipe.get("method", "")) == GeometrySeedingService.POISSON_FILL or (advanced_pattern_expanded and bool(recipe.get("parameters", {}).get("fill_gaps", false))):
		add_child(EditorWidgets.create_inspector_field_label("Random Seed"))
		var random_seed := SpinBox.new()
		random_seed.min_value = 0.0
		random_seed.max_value = 2147483647.0
		random_seed.step = 1.0
		random_seed.set_value_no_signal(float(recipe.get("parameters", {}).get("seed", GeometrySeedingService.DEFAULT_SEED)))
		random_seed.value_changed.connect(seeding_parameter_changed.emit.bind("seed"))
		add_child(random_seed)
	add_child(EditorWidgets.create_inspector_section("Constraints", section_toggled.emit))
	var outer_count := 0
	var hole_count := 0
	var cut_count := 0
	for stat in sampling_bake.get("boundary_stats", []):
		var role := str(stat.get("role", ""))
		if role == "outer":
			outer_count += int(stat.get("sample_count", 0))
		elif role == "hole":
			hole_count += int(stat.get("sample_count", 0))
		elif role == "cut":
			cut_count += int(stat.get("sample_count", 0))
	add_child(EditorWidgets.create_inspector_field_label("Outer · inward clearance · %d points" % outer_count))
	add_child(EditorWidgets.create_inspector_field_label("Holes · excluded + clearance · %d points" % hole_count))
	add_child(EditorWidgets.create_inspector_field_label("Cuts · barrier + clearance · %d points" % cut_count))
	var status := str(seeding_context.get("status", ""))
	add_child(EditorWidgets.create_inspector_section("Result", section_toggled.emit))
	add_child(EditorWidgets.create_inspector_field_label("Status: %s" % status))
	var result: Dictionary = seeding_context.get("result", {})
	if not result.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("Seeds: %d" % int(result.get("seed_count", result.get("seeds", []).size()))))
		if str(result.get("method", "")) == GeometrySeedingService.SPINE_FLOW:
			add_child(EditorWidgets.create_inspector_field_label("Flow: %d · Gap Fill: %d" % [int(result.get("flow_seed_count", 0)), int(result.get("gap_seed_count", 0))]))
	var actions := HBoxContainer.new()
	var bake_button := Button.new()
	bake_button.text = "Calculating…" if status == "Calculating" else "Baked" if status in ["Baked", "Edited"] else "Bake Preview"
	bake_button.custom_minimum_size = Vector2(96, 28)
	bake_button.focus_mode = Control.FOCUS_NONE
	bake_button.disabled = status != "Preview Ready"
	bake_button.pressed.connect(seeding_bake_requested.emit)
	seeding_bake_button = bake_button
	actions.add_child(bake_button)
	add_child(actions)


func _seeding_float_parameter(label_text: String, recipe: Dictionary, parameter_name: String, minimum: float, maximum: float, suffix := "") -> void:
	add_child(EditorWidgets.create_inspector_field_label(label_text))
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = 0.01
	field.custom_arrow_step = 0.01
	field.suffix = suffix
	field.set_value_no_signal(float(recipe.get("parameters", {}).get(parameter_name, minimum)))
	field.value_changed.connect(seeding_parameter_changed.emit.bind(parameter_name))
	field.get_line_edit().text_submitted.connect(seeding_float_text_submitted.emit.bind(field, parameter_name))
	field.get_line_edit().focus_exited.connect(seeding_float_focus_exited.emit.bind(field, parameter_name))
	add_child(field)


func _render_meshing() -> void:
	add_child(EditorWidgets.create_inspector_section("Meshing", section_toggled.emit))
	var component: Dictionary = meshing_context.get("component", {})
	if component.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("Select one Component to generate its derived Mesh."))
		return
	if str(component.get("draw_mode", "")) == "contour":
		_render_contour_meshing(component)
		return
	add_child(EditorWidgets.create_inspector_field_label(str(component.get("name", "Component"))))
	var source_issues: Array = meshing_context.get("source_issues", [])
	if not source_issues.is_empty():
		add_child(EditorWidgets.create_inspector_section("Source Validation", section_toggled.emit))
		var source_status := EditorWidgets.create_inspector_field_label("Invalid source topology")
		source_status.add_theme_color_override("font_color", Color("#ef8354"))
		add_child(source_status)
		for issue in source_issues:
			var issue_label := EditorWidgets.create_inspector_field_label(str(issue))
			issue_label.add_theme_color_override("font_color", Color("#ef8354"))
			add_child(issue_label)
	var recipe: Dictionary = meshing_context.get("recipe", {})
	add_child(EditorWidgets.create_inspector_section("Input", section_toggled.emit))
	var sampling_current := bool(meshing_context.get("sampling_bake_is_current", false))
	var sampling_label := EditorWidgets.create_inspector_field_label("Sampling · Adaptive: %s" % ("Baked" if sampling_current else "Required / Stale"))
	sampling_label.add_theme_color_override("font_color", Color("#75b88a") if sampling_current else Color("#ef8354"))
	add_child(sampling_label)
	add_child(EditorWidgets.create_inspector_field_label("Seeding Source"))
	var seeding_bakes: Dictionary = meshing_context.get("seeding_bakes", {})
	var seed_items: Array = []
	for method in GeometrySeedingService.VALID_METHODS:
		var available := seeding_bakes.has(method)
		seed_items.append({
			"label": _bake_method_label(method) if available else "%s · Required" % _bake_method_label(method),
			"metadata": method, "disabled": not available})
	var seed_option := EditorWidgets.create_option_field(seed_items,
		str(recipe.get("parameters", {}).get("seeding_method", "")),
		meshing_seed_source_selected.emit, false)
	seed_option.disabled = seeding_bakes.is_empty()
	add_child(seed_option)
	if seed_option.item_count == 0:
		var missing_seed := EditorWidgets.create_inspector_field_label("Bake at least one Seeding method first.")
		missing_seed.add_theme_color_override("font_color", Color("#ef8354"))
		add_child(missing_seed)
	var input_current := bool(meshing_context.get("input_is_current", false))
	var input_label := EditorWidgets.create_inspector_field_label("Input Status: %s" % ("Ready" if input_current else "Required / Stale"))
	input_label.add_theme_color_override("font_color", Color("#75b88a") if input_current else Color("#ef8354"))
	add_child(input_label)
	add_child(EditorWidgets.create_inspector_section("Method", section_toggled.emit))
	add_child(EditorWidgets.create_inspector_field_label("Constrained Mesh · Automatic"))
	add_child(EditorWidgets.create_inspector_section("Parameters", section_toggled.emit))
	add_child(EditorWidgets.create_inspector_field_label("Mesh Character"))
	var character_row := HBoxContainer.new()
	character_row.add_child(EditorWidgets.create_inspector_field_label("Structured"))
	var character := HSlider.new()
	character.min_value = 0.0
	character.max_value = 100.0
	character.step = 1.0
	character.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character.set_value_no_signal(float(recipe.get("parameters", {}).get("mesh_character", GeometryMeshingService.DEFAULT_MESH_CHARACTER)) * 100.0)
	character.value_changed.connect(func(value: float) -> void: meshing_parameter_changed.emit(value / 100.0, "mesh_character"))
	character_row.add_child(character)
	character_row.add_child(EditorWidgets.create_inspector_field_label("Organic"))
	add_child(character_row)
	add_child(EditorWidgets.create_inspector_field_label("Character: %d%%" % roundi(character.value)))
	add_child(EditorWidgets.create_inspector_section("Optimization", section_toggled.emit))
	var optimize_mesh := CheckBox.new()
	optimize_mesh.text = "Optimize Mesh"
	optimize_mesh.button_pressed = bool(recipe.get("parameters", {}).get("optimize_mesh", GeometryMeshingService.DEFAULT_OPTIMIZE_MESH))
	optimize_mesh.tooltip_text = "Move only free Interior Seeds and accept a pass only when measured Mesh quality improves."
	optimize_mesh.toggled.connect(meshing_override_changed.emit.bind("optimize_mesh"))
	add_child(optimize_mesh)
	var advanced := Button.new()
	advanced.text = "%s Advanced Optimization" % ("▾" if advanced_relaxation_expanded else "▸")
	advanced.toggle_mode = true
	advanced.button_pressed = advanced_relaxation_expanded
	advanced.alignment = HORIZONTAL_ALIGNMENT_LEFT
	advanced.focus_mode = Control.FOCUS_NONE
	advanced.toggled.connect(meshing_advanced_relaxation_toggled.emit)
	add_child(advanced)
	if advanced_relaxation_expanded:
		var parameters: Dictionary = recipe.get("parameters", {})
		var relaxation_override := bool(parameters.get("relaxation_override", false))
		add_child(EditorWidgets.create_inspector_field_label("Relaxation Strength: %s · %s" % ["Refined" if relaxation_override else "Derived", EditorWidgets.format_scale_value(float(parameters.get("relaxation", 0.0)))]))
		var refine_relaxation := CheckBox.new()
		refine_relaxation.text = "Refine Relaxation Strength"
		refine_relaxation.button_pressed = relaxation_override
		refine_relaxation.toggled.connect(meshing_override_changed.emit.bind("relaxation_override"))
		add_child(refine_relaxation)
		if relaxation_override:
			var relaxation := SpinBox.new()
			relaxation.min_value = 0.0
			relaxation.max_value = 1.0
			relaxation.step = 0.01
			relaxation.custom_arrow_step = 0.01
			relaxation.set_value_no_signal(float(parameters.get("relaxation", GeometryMeshingService.DEFAULT_RELAXATION)))
			relaxation.value_changed.connect(meshing_parameter_changed.emit.bind("relaxation"))
			relaxation.get_line_edit().text_submitted.connect(meshing_float_text_submitted.emit.bind(relaxation, "relaxation"))
			relaxation.get_line_edit().focus_exited.connect(meshing_float_focus_exited.emit.bind(relaxation, "relaxation"))
			add_child(relaxation)
		var passes_override := bool(parameters.get("passes_override", false))
		add_child(EditorWidgets.create_inspector_field_label("Relaxation Passes: %s · %d" % ["Refined" if passes_override else "Derived", int(parameters.get("passes", 0))]))
		var refine_passes := CheckBox.new()
		refine_passes.text = "Refine Relaxation Passes"
		refine_passes.button_pressed = passes_override
		refine_passes.toggled.connect(meshing_override_changed.emit.bind("passes_override"))
		add_child(refine_passes)
		if passes_override:
			var passes := SpinBox.new()
			passes.min_value = 1.0
			passes.max_value = GeometryMeshingService.MAX_PASSES
			passes.step = 1.0
			passes.set_value_no_signal(float(parameters.get("passes", GeometryMeshingService.DEFAULT_PASSES)))
			passes.value_changed.connect(meshing_parameter_changed.emit.bind("passes"))
			add_child(passes)
	add_child(EditorWidgets.create_inspector_section("Constraints", section_toggled.emit))
	var sampling_bake: Dictionary = meshing_context.get("meshing_input", {}).get("sampling", {})
	add_child(EditorWidgets.create_inspector_field_label("Outer · Preserved"))
	add_child(EditorWidgets.create_inspector_field_label("Holes · Preserved · %d" % int(sampling_bake.get("hole_count", 0))))
	add_child(EditorWidgets.create_inspector_field_label("Cuts · Seam · %d" % sampling_bake.get("cuts", []).size()))
	add_child(EditorWidgets.create_inspector_section("View", section_toggled.emit))
	# main.gd reads the workspace flags; an empty list is what an absent
	# workspace used to produce.
	for view_option in meshing_context.get("view_options", []):
		var view_toggle := CheckBox.new()
		view_toggle.text = str(view_option["label"])
		view_toggle.button_pressed = bool(view_option["value"])
		view_toggle.toggled.connect(meshing_view_option_changed.emit.bind(str(view_option["key"])))
		add_child(view_toggle)
	var build_diagnostic_lines: Array = meshing_context.get("build_diagnostic_lines", [])
	if not build_diagnostic_lines.is_empty():
		add_child(EditorWidgets.create_inspector_section("Auto Build Diagnostics", section_toggled.emit))
		for diagnostic_line in build_diagnostic_lines:
			var diagnostic_label := EditorWidgets.create_inspector_field_label(diagnostic_line)
			if str(diagnostic_line).begins_with("Quality Warning:") or str(diagnostic_line).begins_with("Boundary Refinement Warning:"):
				diagnostic_label.add_theme_color_override("font_color", Color("#ef8354"))
			add_child(diagnostic_label)
	var status := str(meshing_context.get("status", ""))
	add_child(EditorWidgets.create_inspector_section("Result", section_toggled.emit))
	add_child(EditorWidgets.create_inspector_field_label("Status: %s" % status))
	var auto_build_error := str(meshing_context.get("auto_build_error", ""))
	if not auto_build_error.is_empty():
		var error_label := EditorWidgets.create_inspector_field_label("Update Meshes: %s" % auto_build_error)
		error_label.add_theme_color_override("font_color", Color("#ef8354"))
		add_child(error_label)
	var result: Dictionary = meshing_context.get("result", {})
	if not result.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("Vertices: %d" % int(result.get("vertex_count", 0))))
		add_child(EditorWidgets.create_inspector_field_label("Triangles: %d" % int(result.get("triangle_count", 0))))
		var optimization: Dictionary = result.get("optimization", {})
		var quality_before: Dictionary = optimization.get("quality_before", {})
		var quality_after: Dictionary = optimization.get("quality_after", {})
		if not quality_before.is_empty() and not quality_after.is_empty():
			add_child(EditorWidgets.create_inspector_field_label("Minimum Angle: %.1f° → %.1f°" % [float(quality_before.get("minimum_angle", 0.0)), float(quality_after.get("minimum_angle", 0.0))]))
			add_child(EditorWidgets.create_inspector_field_label("Worst Aspect Ratio: %.2f → %.2f" % [float(quality_before.get("worst_aspect_ratio", 0.0)), float(quality_after.get("worst_aspect_ratio", 0.0))]))
			add_child(EditorWidgets.create_inspector_field_label("Moved Seeds: %d · Removed: %d" % [int(optimization.get("moved_seed_count", 0)), int(optimization.get("removed_seed_count", 0))]))
		else:
			add_child(EditorWidgets.create_inspector_field_label("Minimum Angle: %.1f°" % float(result.get("minimum_angle", 0.0))))
		for warning in GeometryMeshingService.quality_warnings(result):
			var warning_line := "Quality Warning: %s" % warning
			if build_diagnostic_lines.has(warning_line):
				continue
			var warning_label := EditorWidgets.create_inspector_field_label(warning_line)
			warning_label.add_theme_color_override("font_color", Color("#ef8354"))
			add_child(warning_label)
		var boundary_refinement: Dictionary = result.get("boundary_refinement", {}) if result.get("boundary_refinement", {}) is Dictionary else {}
		if int(boundary_refinement.get("added_vertex_count", 0)) > 0:
			add_child(EditorWidgets.create_inspector_field_label("Boundary Refinement: %d local Vertices" % int(boundary_refinement.get("added_vertex_count", 0))))
		var refinement_warning := GeometryMeshingService.boundary_refinement_warning(result)
		var refinement_warning_line := "Boundary Refinement Warning: %s" % refinement_warning
		if not refinement_warning.is_empty() and not build_diagnostic_lines.has(refinement_warning_line):
			var refinement_warning_label := EditorWidgets.create_inspector_field_label(refinement_warning_line)
			refinement_warning_label.add_theme_color_override("font_color", Color("#ef8354"))
			add_child(refinement_warning_label)
		add_child(EditorWidgets.create_inspector_field_label("Constraints: %s" % ("Valid" if bool(result.get("constraints_valid", false)) else "Invalid")))
		add_child(EditorWidgets.create_inspector_field_label("Cut Seam Vertices: %d" % int(result.get("cut_seam_vertex_count", 0))))
	var actions := HBoxContainer.new()
	var bake_button := Button.new()
	bake_button.text = "Calculating…" if status == "Calculating" else "Baked · Component Mesh" if status == "Baked" else "Bake Preview"
	bake_button.custom_minimum_size = Vector2(96, 28)
	bake_button.focus_mode = Control.FOCUS_NONE
	bake_button.disabled = status != "Preview Ready"
	bake_button.pressed.connect(meshing_bake_requested.emit)
	meshing_bake_button = bake_button
	actions.add_child(bake_button)
	add_child(actions)


func _render_contour_meshing(component: Dictionary) -> void:
	add_child(EditorWidgets.create_inspector_field_label(str(component.get("name", "Contour"))))
	add_child(EditorWidgets.create_inspector_section("Contour Stroke · Automatic", section_toggled.emit))
	var stroke_width_px := WorldDocumentService.effective_contour_stroke_width_px(component, world_contour_stroke_width_px)
	var source_label := "Component override" if WorldDocumentService.has_contour_stroke_width_override(component, world_contour_stroke_width_px) else "World Settings"
	add_child(EditorWidgets.create_inspector_field_label("Width: %.1f px (%.5f m) · %s" % [stroke_width_px, ContourStrokeService.stroke_width_meters(stroke_width_px), source_label]))
	var issues := ContourMeshService.validation_issues(component, stroke_width_px)
	var input_status := EditorWidgets.create_inspector_field_label("Input: Ready" if issues.is_empty() else "Input: Draft · %s" % issues[0])
	input_status.add_theme_color_override("font_color", Color("#75b88a") if issues.is_empty() else Color("#ef8354"))
	add_child(input_status)
	var status := str(meshing_context.get("contour_status", ""))
	add_child(EditorWidgets.create_inspector_section("Result", section_toggled.emit))
	add_child(EditorWidgets.create_inspector_field_label("Status: %s" % status))
	var auto_build_error := str(meshing_context.get("auto_build_error", ""))
	if not auto_build_error.is_empty():
		var error_label := EditorWidgets.create_inspector_field_label("Update Meshes: %s" % auto_build_error)
		error_label.add_theme_color_override("font_color", Color("#ef8354"))
		add_child(error_label)
	var result: Dictionary = meshing_context.get("contour_result", {})
	if not result.is_empty():
		add_child(EditorWidgets.create_inspector_field_label("Vertices: %d" % int(result.get("vertex_count", 0))))
		add_child(EditorWidgets.create_inspector_field_label("Triangles: %d" % int(result.get("triangle_count", 0))))
	var actions := HBoxContainer.new()
	var bake_button := Button.new()
	bake_button.text = "Calculating…" if status == "Calculating" else "Baked · Component Mesh" if status == "Baked" else "Bake Preview"
	bake_button.disabled = status != "Preview Ready"
	bake_button.pressed.connect(meshing_bake_requested.emit)
	meshing_bake_button = bake_button
	actions.add_child(bake_button)
	add_child(actions)
