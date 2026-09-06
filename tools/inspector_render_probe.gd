# Inspector render probe.
#
# Renders the Inspector in 55 fixed states and prints one line per control with
# the properties a reader would notice: values, ranges, item lists, selections,
# pressed state, disabled state, captions, colours and tooltips. It asserts
# nothing on its own. It is run before and after a change that is meant to leave
# the Inspector alone, and the two outputs are diffed:
#
#   godot --headless --path . --script tools/inspector_render_probe.gd > before.txt
#   ...make the change...
#   godot --headless --path . --script tools/inspector_render_probe.gd > after.txt
#   diff before.txt after.txt
#
# Any difference is a rendering change. Watch stderr for SCRIPT ERROR as well:
# a parse error here means the probe rendered nothing and the empty diff means
# nothing.
#
# The state list covers Create (Asset, Set Asset root, Set member Reference with
# its Role, Component, Group, Guide, weapon Guide,
# grouped Component, Contour Component, Circle, valid and invalid Hole, Hole Edge
# modes, and Ellipse Primitive, authored
# and Component-geometry Regions, two
# selected Components, Reference Image, Point mode with none, one and two
# Points, Edge mode with none, one and two Edges, Face mode), Mesh
# (Sampling, Seeding and Meshing, each unbaked and against a Geometry document
# with baked results and expanded advanced blocks, a baked Meshing quality
# warning, the baked Sampling state also with its Hole and with its Cut boundary selected), Style (Weighting
# without a Component, without a Style, Uniform, Axis Gradient, and a
# generated Axis Gradient preview) and Motion (Asset contract, State, Motion, inner
# Motion, Transition, seeded Transition with Rules, Marker, Act empty / Slide /
# Blink, Path empty / authored, Sequence empty / composition / player). Between
# them they reach every Inspector render function. When a render function is
# added, add the state that reaches it.

extends SceneTree
func _collect(n: Node, out: Array) -> void:
	if n.is_queued_for_deletion():
		return
	if n is SpinBox:
		out.append(("S|%.4f|%.4f|%.4f|%.4f|%.4f|%s|%s|%d" % [n.value, n.min_value, n.max_value, n.step,
			n.custom_arrow_step, str(n.suffix), str(n.custom_minimum_size), n.get_theme_font_size("font_size")] ) + "|T:" + str(n.tooltip_text))
	elif n is OptionButton:
		var items: Array = []
		for i in range(n.item_count):
			items.append("%s=%s%s" % [str(n.get_item_text(i)), str(n.get_item_metadata(i)),
				"!" if n.is_item_disabled(i) else ""])
		out.append("O|%d|%s|%s|%s|%d|%s" % [n.selected, ";".join(items), str(n.tooltip_text),
			str(n.custom_minimum_size), n.get_theme_font_size("font_size"), str(n.disabled)])
	elif n is CheckBox or n is CheckButton:
		out.append("C|%s|%s|%s|%s|%s|%d|%d" % [n.get_class(), str(n.text), str(n.button_pressed),
			str(n.tooltip_text), str(n.custom_minimum_size), n.get_theme_font_size("font_size"),
			n.focus_mode])
	elif n is Button:
		out.append("B|%s|%s|%s" % [str(n.text), str(n.tooltip_text), str(n.disabled)])
	elif n is Label:
		out.append("L|%s|%d|%s|T:%s" % [str(n.text), n.get_theme_font_size("font_size"), str(n.get_theme_color("font_color")), str(n.tooltip_text)])
	elif n is LineEdit:
		out.append("E|%s|%s" % [str(n.text), str(n.placeholder_text)])
	for c in n.get_children():
		_collect(c, out)

func _init() -> void:
	var app: Control = load("res://scripts/main.gd").new()
	app._build_ui()
	var comp := {"points": [], "edges": [], "chains": []}
	BezierTopology.add_point(comp, Vector2.ZERO, "corner")
	BezierTopology.add_point(comp, Vector2(12, 0), "linear")
	BezierTopology.add_point(comp, Vector2(12, 9), "linear")
	BezierTopology.close_active_chain(comp)
	comp.merge({"id": "component_1", "name": "body", "visibility": true, "topology_role": "outer",
		"transform": {"position": Vector2(3, 4), "rotation": 15.0, "scale": Vector2(1.5, 2.0), "pivot": Vector2(1, 1)}})
	var guide := {"id": "guide_1", "guide_type": AssetGuide.SAMPLE, "ordinal": 1, "visibility": true,
		"scope": {"kind": "component", "component_id": "component_1"}, "points": [], "edges": [], "chains": []}
	# The Mesh states run on a Component of their own so the Create and Style
	# states keep the Component they had. It carries the two Sampling boundaries
	# the Inspector resolves from different places -- a Hole is a reference
	# Component parented to it, a Cut is an AssetGuide.CUT scoped to it -- plus
	# its own Sampler Spine for the Seeding rows. AssetGuide.SAMPLER_SPINE is
	# AssetGuide.SAMPLE: a Spine is a Seeding input, never a Cut boundary, and
	# the source Asset gives the Hole Reference one valid visible boundary.
	var mesh_body := {"points": [], "edges": [], "chains": []}
	BezierTopology.add_point(mesh_body, Vector2.ZERO, "corner")
	BezierTopology.add_point(mesh_body, Vector2(12, 0), "linear")
	BezierTopology.add_point(mesh_body, Vector2(12, 9), "linear")
	BezierTopology.close_active_chain(mesh_body)
	mesh_body.merge({"id": "component_7", "name": "torso", "visibility": true,
		"topology_role": "outer"})
	var hole_reference := {"points": [], "edges": [], "chains": [], "id": "component_6",
		"name": "eye", "visibility": true, "type": "reference",
		"parent_component_id": "component_7", "topology_role": "hole",
		"source_asset_id": "asset_2"}
	var hole_source := {"points": [], "edges": [], "chains": [], "id": "component_10",
		"name": "orb", "visibility": true, "type": "component", "draw_mode": "primitive",
		"topology_role": "outer", "parent_component_id": "",
		"primitive": {"type": "circle", "center": Vector2.ZERO, "diameter_cm": 4.0},
		"transform": WorldDocumentService.default_component_transform()}
	var cut_guide := {"id": "guide_4", "guide_type": AssetGuide.CUT, "ordinal": 1,
		"visibility": true, "scope": {"kind": "component", "component_id": "component_7"},
		"points": [], "edges": [], "chains": []}
	BezierTopology.add_point(cut_guide, Vector2(2, 2), "corner")
	BezierTopology.add_point(cut_guide, Vector2(10, 7), "linear")
	var spine_guide := {"id": "guide_5", "guide_type": AssetGuide.SAMPLER_SPINE, "ordinal": 1,
		"visibility": true, "scope": {"kind": "component", "component_id": "component_7"},
		"points": [], "edges": [], "chains": []}
	BezierTopology.add_point(spine_guide, Vector2(3, 1), "corner")
	BezierTopology.add_point(spine_guide, Vector2(11, 8), "linear")
	var group := {"id": "group_1", "name": "torso", "transform": {"position": Vector2(2, 2), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}, "visibility": true, "parent_component_id": ""}
	var arm := {"points": [], "edges": [], "chains": [], "id": "component_2", "name": "arm",
		"visibility": true, "parent_component_id": "component_1"}
	var outline := {"points": [], "edges": [], "chains": [], "id": "component_3", "name": "outline",
		"visibility": true, "draw_mode": "contour"}
	var circle := {"points": [], "edges": [], "chains": [], "id": "component_4", "name": "orb",
		"visibility": true, "draw_mode": "primitive", "primitive": {"type": "circle", "diameter_cm": 4.0}}
	var direct_hole := {"points": [], "edges": [], "chains": [], "id": "component_11", "name": "opening",
		"visibility": true, "draw_mode": "primitive", "primitive": {"type": "circle", "diameter_cm": 2.0},
		"parent_component_id": "component_1", "topology_role": "hole"}
	var bezier_hole: Dictionary = comp.duplicate(true)
	bezier_hole.merge({"id": "component_12", "name": "opening_curve", "parent_component_id": "component_1",
		"topology_role": "hole", "transform": WorldDocumentService.default_component_transform()}, true)
	for chain in bezier_hole.get("chains", []):
		chain["topology_role"] = "hole"
	var ellipse := {"points": [], "edges": [], "chains": [], "id": "component_5", "name": "egg",
		"visibility": true, "draw_mode": "primitive",
		"primitive": {"type": PrimitiveGeometryService.ELLIPSE, "diameter_x_cm": 3.0, "diameter_y_cm": 5.0}}
	var weapon_guide := {"id": "guide_3", "guide_type": AssetGuide.WEAPON_TYPES[0], "ordinal": 1,
		"visibility": true, "scope": {"kind": "component", "component_id": "component_1"},
		"points": [], "edges": [], "chains": []}
	var authored_region := comp.duplicate(true)
	authored_region.merge({"id": "component_8", "name": "attack_region", "visibility": true,
		"type": "region", "region_type": "attack", "parent_component_id": "component_1",
		"region_geometry_source": WorldDocumentService.REGION_GEOMETRY_AUTHORED}, true)
	var inherited_region := authored_region.duplicate(true)
	inherited_region.merge({"id": "component_9", "name": "hurt_region", "region_type": "hurt",
		"region_geometry_source": WorldDocumentService.REGION_GEOMETRY_COMPONENT}, true)
	# A Set carries no geometry of its own: its visible Components are
	# References to its members, and each one says what role it plays.
	var set_member := {"points": [], "edges": [], "chains": [], "id": "component_13",
		"name": "post_left", "visibility": true, "type": "reference",
		"parent_component_id": "", "topology_role": "outer", "role": "rope_post",
		"source_asset_id": "asset_2",
		"transform": WorldDocumentService.default_component_transform()}
	var assets: Array[Dictionary] = [{"id": "asset_1", "name": "Wizard", "visibility": true,
		"components": [comp, arm, outline, circle, ellipse, mesh_body, hole_reference, authored_region, inherited_region],
		"groups": [group], "guides": [guide, weapon_guide, cut_guide, spine_guide],
		"asset_pivot": Vector2(5, 6), "root_position": Vector2(1, 2), "root_scale": Vector2(1, 1)},
		{"id": "asset_2", "name": "Orb", "visibility": true,
			"components": [hole_source], "groups": [], "guides": []}]
	var set_asset := {"id": "asset_3", "name": "Bridge", "visibility": true,
		"asset_type": WorldDocumentService.ASSET_TYPE_SET,
		"components": [set_member], "groups": [], "guides": [],
		"asset_pivot": Vector2.ZERO, "root_position": Vector2.ZERO, "root_scale": Vector2.ONE}
	app.assets = assets
	app.selected_asset_id = "asset_1"
	app.expanded_assets["asset_1"] = true

	# The Weighting Inspector only leaves "Component Mesh: Missing" for a Mesh
	# that is really Ready, so the Style states are backed by real service bakes
	# and a component_mesh fingerprint. They are computed once and reused.
	var style_sampling: Dictionary = GeometrySamplingService.generate(comp,
		{"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 2.0}})
	style_sampling["bake_id"] = "sampling_style"
	var style_seeding: Dictionary = GeometrySeedingService.generate(style_sampling,
		{"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 2.5, "seed": 5}})
	style_seeding["bake_id"] = "seeding_style"
	var style_mesh: Dictionary = GeometryMeshingService.generate(style_sampling, style_seeding,
		{"method": GeometryMeshingService.CONSTRAINED_MESH,
			"parameters": {"seeding_method": GeometrySeedingService.POISSON_FILL}})
	style_mesh["bake_id"] = "mesh_style"

	var cases := [
		{"m": "Create", "sub": "Single", "comp": "", "grp": "", "gd": ""},
		{"m": "Create", "sub": "Single", "comp": "component_1", "grp": "", "gd": ""},
		{"m": "Create", "sub": "Single", "comp": "", "grp": "group_1", "gd": ""},
		{"m": "Create", "sub": "Single", "comp": "", "grp": "", "gd": "guide_1"},
		{"m": "Mesh", "sub": "Sampling", "comp": "component_7", "grp": "", "gd": ""},
		{"m": "Mesh", "sub": "Sampling", "comp": "component_7", "grp": "", "gd": "", "baked": true},
		{"m": "Mesh", "sub": "Sampling", "comp": "component_7", "grp": "", "gd": "", "baked": true, "input": "hole"},
		{"m": "Mesh", "sub": "Sampling", "comp": "component_7", "grp": "", "gd": "", "baked": true, "input": "cut"},
		{"m": "Mesh", "sub": "Seeding", "comp": "component_7", "grp": "", "gd": "", "baked": true},
		{"m": "Mesh", "sub": "Meshing", "comp": "component_7", "grp": "", "gd": "", "baked": true},
		{"m": "Mesh", "sub": "Meshing", "comp": "component_7", "grp": "", "gd": "", "baked": true, "quality_warning": true},
		{"m": "Mesh", "sub": "Seeding", "comp": "component_7", "grp": "", "gd": ""},
		{"m": "Mesh", "sub": "Meshing", "comp": "component_7", "grp": "", "gd": ""},
		{"m": "Style", "sub": "Weighting", "comp": "", "grp": "", "gd": ""},
		{"m": "Style", "sub": "Weighting", "comp": "component_1", "grp": "", "gd": ""},
		{"m": "Style", "sub": "Weighting", "comp": "component_1", "grp": "", "gd": "", "style": "uniform"},
		{"m": "Style", "sub": "Weighting", "comp": "component_1", "grp": "", "gd": "", "style": "gradient"},
		{"m": "Style", "sub": "Weighting", "comp": "component_1", "grp": "", "gd": "", "style": "gradient_previewed"},
		{"m": "Create", "sub": "Single", "comp": "component_1", "grp": "", "gd": "", "grouped": true},
		{"m": "Motion", "sub": "Animation", "comp": "", "grp": "", "gd": "", "motion": "asset"},
		{"m": "Motion", "sub": "Animation", "comp": "", "grp": "", "gd": "", "motion": "state"},
		{"m": "Motion", "sub": "Animation", "comp": "", "grp": "", "gd": "", "motion": "motion"},
		{"m": "Motion", "sub": "Animation", "comp": "", "grp": "", "gd": "", "motion": "transition"},
		{"m": "Motion", "sub": "Animation", "comp": "", "grp": "", "gd": "", "motion": "transition_seeded"},
		{"m": "Motion", "sub": "Animation", "comp": "", "grp": "", "gd": "", "motion": "motion_inner"},
		{"m": "Motion", "sub": "Animation", "comp": "", "grp": "", "gd": "", "motion": "marker"},
		{"m": "Motion", "sub": "Act", "comp": "", "grp": "", "gd": "", "motion": "act_empty"},
		{"m": "Motion", "sub": "Act", "comp": "", "grp": "", "gd": "", "motion": "act_slide"},
		{"m": "Motion", "sub": "Act", "comp": "", "grp": "", "gd": "", "motion": "act_blink"},
		{"m": "Motion", "sub": "Path", "comp": "", "grp": "", "gd": "", "motion": "path_empty"},
		{"m": "Motion", "sub": "Path", "comp": "", "grp": "", "gd": "", "motion": "path"},
		{"m": "Motion", "sub": "Sequence", "comp": "", "grp": "", "gd": "", "motion": "sequence_empty"},
		{"m": "Motion", "sub": "Sequence", "comp": "", "grp": "", "gd": "", "motion": "sequence"},
		{"m": "Motion", "sub": "Sequence", "comp": "", "grp": "", "gd": "", "motion": "sequence_player"},
		{"m": "Create", "sub": "Single", "comp": "", "grp": "", "gd": "", "ref": true},
		{"m": "Create", "sub": "Single", "comp": "component_1", "grp": "", "gd": "", "pts": 1},
		{"m": "Create", "sub": "Single", "comp": "component_1", "grp": "", "gd": "", "pts": 2},
			{"m": "Create", "sub": "Single", "comp": "component_1", "grp": "", "gd": "", "edges": 2},
		{"m": "Create", "sub": "Single", "comp": "component_1", "grp": "", "gd": "", "edges": 1},
		{"m": "Create", "sub": "Single", "comp": "component_1", "grp": "", "gd": "", "pts": 0, "point_mode": true},
		{"m": "Create", "sub": "Single", "comp": "component_1", "grp": "", "gd": "", "edges": 0, "edge_mode": true},
		{"m": "Create", "sub": "Single", "comp": "component_1", "grp": "", "gd": "", "face": true},
		{"m": "Create", "sub": "Single", "comp": "component_3", "grp": "", "gd": ""},
		{"m": "Create", "sub": "Single", "comp": "component_4", "grp": "", "gd": ""},
		{"m": "Create", "sub": "Single", "comp": "component_11", "grp": "", "gd": ""},
		{"m": "Create", "sub": "Single", "comp": "component_11", "grp": "", "gd": "", "orphan_hole": true},
		{"m": "Create", "sub": "Single", "comp": "component_12", "grp": "", "gd": "", "edges": 1},
		{"m": "Create", "sub": "Single", "comp": "component_12", "grp": "", "gd": "", "edges": 2},
		{"m": "Create", "sub": "Single", "comp": "component_5", "grp": "", "gd": ""},
		{"m": "Create", "sub": "Single", "comp": "component_8", "grp": "", "gd": ""},
		{"m": "Create", "sub": "Single", "comp": "component_9", "grp": "", "gd": ""},
		{"m": "Create", "sub": "Single", "comp": "", "grp": "", "gd": "guide_3"},
		{"m": "Create", "sub": "Single", "comp": "component_1", "grp": "", "gd": "", "multi": true},
		{"m": "Create", "sub": "Set", "comp": "", "grp": "", "gd": "", "asset": "asset_3"},
		{"m": "Create", "sub": "Set", "comp": "component_13", "grp": "", "gd": "", "asset": "asset_3"},
	]
	for c in cases:
		# Keep the new Hole fixture out of every pre-existing state so this probe
		# still detects unrelated rendering changes byte-for-byte.
		assets[0]["components"].erase(direct_hole)
		assets[0]["components"].erase(bezier_hole)
		# The Set fixture is kept out of every other state for the same reason
		# the Hole fixtures are: an Asset the Motion dropdowns would list moves
		# lines that have nothing to do with the change under test.
		assets.erase(set_asset)
		if str(c.get("asset", "")) == "asset_3":
			assets.append(set_asset)
		direct_hole["parent_component_id"] = "" if bool(c.get("orphan_hole", false)) else "component_1"
		if str(c["comp"]) == "component_11":
			assets[0]["components"].append(direct_hole)
		elif str(c["comp"]) == "component_12":
			assets[0]["components"].append(bezier_hole)
		app.active_module = str(c["m"])
		if c["m"] == "Create": app.active_create_submodule = str(c["sub"])
		elif c["m"] == "Mesh": app.active_geometry_submodule = str(c["sub"])
		elif c["m"] == "Motion": app.active_motion_submodule = str(c["sub"])
		else: app.active_style_submodule = str(c["sub"])
		app.selected_asset_id = str(c.get("asset", "asset_1"))
		app.selected_component_id = str(c["comp"])
		app.selected_group_id = str(c["grp"])
		app.selected_guide_id = str(c["gd"])
		comp["group_id"] = "group_1" if bool(c.get("grouped", false)) else ""
		if bool(c.get("ref", false)):
			assets[0]["reference_image"] = {"file": "res://ref.png", "target_height_cm": 21.5,
				"pivot_mode": "center", "visible": true, "opacity": 0.35,
				"position": Vector2(2.5, -3.5), "scale": 1.25}
		else:
			assets[0].erase("reference_image")
		var point_count := int(c.get("pts", 0))
		app.active_state = "edit" if point_count > 0 else "select"
		app.active_edit_mode = "point" if point_count > 0 else ""
		var all_point_ids: Array[String] = []
		for point in comp["points"]: all_point_ids.append(str(point["id"]))
		var chosen_point_ids: Array[String] = []
		for i in range(point_count): chosen_point_ids.append(all_point_ids[i])
		app.selected_point_ids = chosen_point_ids
		var multi_ids: Array[String] = []
		if bool(c.get("multi", false)):
			multi_ids.append("component_1")
			multi_ids.append("component_2")
		app.selected_component_ids = multi_ids
		if bool(c.get("face", false)):
			app.active_state = "edit"
			app.active_edit_mode = "face"
		elif bool(c.get("point_mode", false)):
			app.active_state = "edit"
			app.active_edit_mode = "point"
		var edge_count := int(c.get("edges", 0))
		if edge_count > 0 or bool(c.get("edge_mode", false)):
			app.active_state = "edit"
			app.active_edit_mode = "edge"
		var all_edge_ids: Array[String] = []
		for edge in comp["edges"]: all_edge_ids.append(str(edge["id"]))
		var chosen_edge_ids: Array[String] = []
		for i in range(edge_count): chosen_edge_ids.append(all_edge_ids[i])
		app.selected_edge_ids = chosen_edge_ids
		var motion_case := str(c.get("motion", ""))
		if not motion_case.is_empty():
			app.motion_selection.select_asset("asset_1")
			app.motion_workspace.set_asset("asset_1", "Wizard", assets[0]["components"], app._ensure_asset_animation(assets[0]))
			var states: Array = app.motion_workspace.get_states_for_asset("asset_1")
			var first_state_id := str(states[0].get("id", "")) if not states.is_empty() else ""
			if motion_case == "state":
				app.motion_selection.select_state("asset_1", first_state_id)
			elif motion_case == "motion":
				app.motion_workspace.add_motion(first_state_id)
			elif motion_case == "motion_inner":
				app.motion_workspace.add_motion(first_state_id)
				app.motion_workspace.set_motion_property(first_state_id, str(app.motion_selection.item_id), "domain", MotionWorkspace.INNER)
			elif motion_case == "transition_seeded":
				app.motion_selection.select_item(MotionSelection.TRANSITION, "asset_1", first_state_id, "transition_idle_01")
			elif motion_case == "transition":
				app.motion_workspace.add_transition(first_state_id)
			elif motion_case == "marker":
				app.motion_workspace.add_marker(first_state_id)
			elif motion_case.begins_with("act"):
				app.motion_acts = [] as Array[Dictionary]
				app.selected_motion_act_id = ""
				if motion_case == "act_slide":
					app.motion_acts.append(WorldDocumentService.default_motion_act("act_1", "Slide", MotionActEvaluator.SLIDE))
					app.selected_motion_act_id = "act_1"
				elif motion_case == "act_blink":
					app.motion_acts.append(WorldDocumentService.default_motion_act("act_2", "Blink", MotionActEvaluator.BLINK))
					app.selected_motion_act_id = "act_2"
			elif motion_case.begins_with("path"):
				app.motion_paths = [] as Array[Dictionary]
				app.selected_motion_path_id = ""
				if motion_case == "path":
					app.motion_paths.append(WorldDocumentService.default_motion_path("path_1", "Walk Path"))
					app.selected_motion_path_id = "path_1"
			elif motion_case.begins_with("sequence"):
				app.motion_paths = [] as Array[Dictionary]
				app.motion_paths.append(WorldDocumentService.default_motion_path("path_1", "Walk Path"))
				app.selected_motion_path_id = "path_1"
				app.motion_sequences = [] as Array[Dictionary]
				app.selected_motion_sequence_id = ""
				app.selected_motion_sequence_entry_id = ""
				app.motion_sequence_view = MotionSequenceWorkspace.VIEW_COMPOSITION
				if motion_case != "sequence_empty":
					app.motion_sequences.append(WorldDocumentService.default_motion_sequence("sequence_1", "Walk Cycle"))
					app.selected_motion_sequence_id = "sequence_1"
					app._add_motion_sequence_entry()
					if motion_case == "sequence_player":
						app.motion_sequence_view = MotionSequenceWorkspace.VIEW_PLAYER
		if bool(c.get("baked", false)):
			var doc: Dictionary = WorldDocumentService.default_geometry_document("asset_1", "component_7")
			# The refinement and the statistics name the Hole reference and the
			# Cut Guide the Inspector actually builds rows for, so the Hole row
			# reads its Density override and the Cut row stays Inherited.
			doc["sampling"]["recipe"] = {"method": GeometrySamplingService.ADAPTIVE,
				"parameters": {"spacing": 2.0, "feature_detail": 0.4,
					"boundary_refinements": {"component_6": {"factor": 2.5}}}}
			doc["sampling"]["bakes"][GeometrySamplingService.ADAPTIVE] = {"sample_count": 42,
				"constraint_sample_count": 40, "preserve_count": 3, "hole_count": 1, "cuts": [{}],
				"boundary_stats": [{"input_id": "", "role": "outer", "sample_count": 20},
					{"input_id": "guide_4", "role": "cut", "sample_count": 12},
					{"input_id": "component_6", "role": "hole", "sample_count": 10}]}
			doc["seeding"]["recipe"] = {"method": GeometrySeedingService.SPINE_FLOW,
				"parameters": {"spacing": 2.5, "flow_stretch": 1.5, "fill_gaps": true,
					"boundary_clearance_override": true, "boundary_clearance": 0.8,
					"stagger_override": true, "stagger": 0.25, "seed": 7,
					"spine_inputs": [{"guide_id": "guide_5", "enabled": true}]}}
			doc["seeding"]["bakes"][GeometrySeedingService.SPINE_FLOW] = {"seed_count": 33,
				"method": GeometrySeedingService.SPINE_FLOW, "flow_seed_count": 30, "gap_seed_count": 3}
			doc["meshing"]["recipe"] = {"method": GeometryMeshingService.CONSTRAINED_MESH,
				"parameters": {"seeding_method": GeometrySeedingService.SPINE_FLOW,
					"mesh_character": 0.6, "optimize_mesh": true, "relaxation_override": true,
					"relaxation": 0.4, "passes_override": true, "passes": 3}}
			doc["meshing"]["bakes"][GeometryMeshingService.CONSTRAINED_MESH] = {"vertex_count": 55,
				"triangle_count": 66, "minimum_angle": 1.0 if bool(c.get("quality_warning", false)) else 24.5,
				"worst_aspect_ratio": 60.0 if bool(c.get("quality_warning", false)) else 3.0, "constraints_valid": true,
				"cut_seam_vertex_count": 4, "boundary_refinement": {"enabled": true,
					"added_vertex_count": 64 if bool(c.get("quality_warning", false)) else 0,
					"complete": not bool(c.get("quality_warning", false)),
					"unresolved_corner_count": 7 if bool(c.get("quality_warning", false)) else 0,
					"limit_reached": bool(c.get("quality_warning", false))}}
			app.geometry_documents["asset_1/component_7"] = doc
			# Only "component" and "guide" are input kinds the Sampling path
			# stores; anything else resolves to nothing and the Boundary Density
			# block silently disappears.
			match str(c.get("input", "")):
				"hole":
					app.selected_sampling_input_id = "component_6"
					app.selected_sampling_input_kind = "component"
				"cut":
					app.selected_sampling_input_id = "guide_4"
					app.selected_sampling_input_kind = "guide"
				_:
					app.selected_sampling_input_id = ""
					app.selected_sampling_input_kind = ""
			app.geometry_seeding_advanced_pattern_expanded = true
			app.geometry_meshing_advanced_relaxation_expanded = true
		else:
			app.geometry_documents.erase("asset_1/component_1")
			app.geometry_documents.erase("asset_1/component_7")
			app.selected_sampling_input_id = ""
			app.selected_sampling_input_kind = ""
			app.geometry_seeding_advanced_pattern_expanded = false
			app.geometry_meshing_advanced_relaxation_expanded = false
		# Weighting Styles live on the Geometry document, not on the Component,
		# so the Style states install a document with a Ready Component Mesh and
		# one Style; "gradient_previewed" additionally runs the real preview so
		# the Result rows and the enabled Bake button are drawn.
		var style_case := str(c.get("style", ""))
		app.selected_weighting_style_id = ""
		app.weighting_preview = {}
		app.weighting_preview_key = ""
		if not style_case.is_empty():
			var style_doc: Dictionary = WorldDocumentService.default_geometry_document("asset_1", "component_1")
			style_doc["sampling"]["recipe"] = {"method": GeometrySamplingService.ADAPTIVE,
				"parameters": {"spacing": 2.0}}
			style_doc["sampling"]["bakes"][GeometrySamplingService.ADAPTIVE] = style_sampling
			style_doc["seeding"]["recipe"] = {"method": GeometrySeedingService.POISSON_FILL,
				"parameters": {"spacing": 2.5, "seed": 5}}
			style_doc["seeding"]["bakes"][GeometrySeedingService.POISSON_FILL] = style_seeding
			style_doc["meshing"]["recipe"] = {"method": GeometryMeshingService.CONSTRAINED_MESH,
				"parameters": {"seeding_method": GeometrySeedingService.POISSON_FILL}}
			style_doc["meshing"]["bakes"][GeometryMeshingService.CONSTRAINED_MESH] = style_mesh
			style_doc["component_mesh"] = {"bake_id": "mesh_style",
				"method": GeometryMeshingService.CONSTRAINED_MESH,
				"mesh_fingerprint": GeometryUVMappingService.mesh_fingerprint(style_mesh)}
			var style: Dictionary = WeightingService.default_style("style_1", "Weighting Style 01", "component_1")
			if style_case != "uniform":
				style["method"] = WeightingService.AXIS_GRADIENT
				style["parameters"] = WeightingService.default_parameters(WeightingService.AXIS_GRADIENT)
			style_doc["weighting"]["styles"].append(style)
			app.geometry_documents["asset_1/component_1"] = style_doc
			app.selected_weighting_style_id = "style_1"
			if style_case == "gradient_previewed":
				app._generate_weighting_preview()
		app._render_inspector()
		var out: Array = []
		_collect(app.inspector_content, out)
		print("### %s/%s comp=%s grp=%s guide=%s%s" % [c["m"], c["sub"], c["comp"], c["grp"], c["gd"],
			"" if not c.has("asset") else " asset=%s" % str(c["asset"])])
		for l in out: print(l)
	app.free()
	quit(0)
