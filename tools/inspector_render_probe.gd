# Inspector render probe.
#
# Renders the Inspector in 33 fixed states and prints one line per control with
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
# The state list covers Create (Asset, Component, Group, Guide, grouped
# Component, Reference Image, one and two Points, one and two Edges), Mesh
# (Sampling, Seeding and Meshing, each unbaked and against a Geometry document
# with baked results and expanded advanced blocks), Style (Weighting, with and
# without an Axis Gradient) and Motion (Asset contract, State, Motion, inner
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
	var group := {"id": "group_1", "name": "torso", "transform": {"position": Vector2(2, 2), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}, "visibility": true, "parent_component_id": ""}
	var assets: Array[Dictionary] = [{"id": "asset_1", "name": "Wizard", "visibility": true,
		"components": [comp], "groups": [group], "guides": [guide],
		"asset_pivot": Vector2(5, 6), "root_position": Vector2(1, 2), "root_scale": Vector2(1, 1)}]
	app.assets = assets
	app.selected_asset_id = "asset_1"
	app.expanded_assets["asset_1"] = true

	var cases := [
		{"m": "Create", "sub": "Character", "comp": "", "grp": "", "gd": ""},
		{"m": "Create", "sub": "Character", "comp": "component_1", "grp": "", "gd": ""},
		{"m": "Create", "sub": "Character", "comp": "", "grp": "group_1", "gd": ""},
		{"m": "Create", "sub": "Character", "comp": "", "grp": "", "gd": "guide_1"},
		{"m": "Mesh", "sub": "Sampling", "comp": "component_1", "grp": "", "gd": ""},
		{"m": "Mesh", "sub": "Sampling", "comp": "component_1", "grp": "", "gd": "", "baked": true},
		{"m": "Mesh", "sub": "Seeding", "comp": "component_1", "grp": "", "gd": "", "baked": true},
		{"m": "Mesh", "sub": "Meshing", "comp": "component_1", "grp": "", "gd": "", "baked": true},
		{"m": "Mesh", "sub": "Seeding", "comp": "component_1", "grp": "", "gd": ""},
		{"m": "Mesh", "sub": "Meshing", "comp": "component_1", "grp": "", "gd": ""},
		{"m": "Style", "sub": "Weighting", "comp": "component_1", "grp": "", "gd": ""},
		{"m": "Style", "sub": "Weighting", "comp": "component_1", "grp": "", "gd": "", "gradient": true},
		{"m": "Create", "sub": "Character", "comp": "component_1", "grp": "", "gd": "", "grouped": true},
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
		{"m": "Create", "sub": "Character", "comp": "", "grp": "", "gd": "", "ref": true},
		{"m": "Create", "sub": "Character", "comp": "component_1", "grp": "", "gd": "", "pts": 1},
		{"m": "Create", "sub": "Character", "comp": "component_1", "grp": "", "gd": "", "pts": 2},
			{"m": "Create", "sub": "Character", "comp": "component_1", "grp": "", "gd": "", "edges": 2},
		{"m": "Create", "sub": "Character", "comp": "component_1", "grp": "", "gd": "", "edges": 1},
	]
	for c in cases:
		app.active_module = str(c["m"])
		if c["m"] == "Create": app.active_create_submodule = str(c["sub"])
		elif c["m"] == "Mesh": app.active_geometry_submodule = str(c["sub"])
		elif c["m"] == "Motion": app.active_motion_submodule = str(c["sub"])
		else: app.active_style_submodule = str(c["sub"])
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
		var edge_count := int(c.get("edges", 0))
		if edge_count > 0:
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
			var doc: Dictionary = WorldDocumentService.default_geometry_document("asset_1", "component_1")
			doc["sampling"]["recipe"] = {"method": GeometrySamplingService.ADAPTIVE,
				"parameters": {"spacing": 2.0, "feature_detail": 0.4,
					"boundary_refinements": {"guide_1": {"factor": 2.5}}}}
			doc["sampling"]["bakes"][GeometrySamplingService.ADAPTIVE] = {"sample_count": 42,
				"constraint_sample_count": 40, "preserve_count": 3, "hole_count": 2, "cuts": [{}],
				"boundary_stats": [{"input_id": "", "role": "outer", "sample_count": 20},
					{"input_id": "guide_1", "role": "cut", "sample_count": 12},
					{"input_id": "component_2", "role": "hole", "sample_count": 10}]}
			doc["seeding"]["recipe"] = {"method": GeometrySeedingService.SPINE_FLOW,
				"parameters": {"spacing": 2.5, "flow_stretch": 1.5, "fill_gaps": true,
					"boundary_clearance_override": true, "boundary_clearance": 0.8,
					"stagger_override": true, "stagger": 0.25, "seed": 7,
					"spine_inputs": [{"guide_id": "guide_1", "enabled": true}]}}
			doc["seeding"]["bakes"][GeometrySeedingService.SPINE_FLOW] = {"seed_count": 33,
				"method": GeometrySeedingService.SPINE_FLOW, "flow_seed_count": 30, "gap_seed_count": 3}
			doc["meshing"]["recipe"] = {"method": GeometryMeshingService.CONSTRAINED_MESH,
				"parameters": {"seeding_method": GeometrySeedingService.SPINE_FLOW,
					"mesh_character": 0.6, "optimize_mesh": true, "relaxation_override": true,
					"relaxation": 0.4, "passes_override": true, "passes": 3}}
			doc["meshing"]["bakes"][GeometryMeshingService.CONSTRAINED_MESH] = {"vertex_count": 55,
				"triangle_count": 66, "minimum_angle": 24.5, "constraints_valid": true,
				"cut_seam_vertex_count": 4}
			app.geometry_documents["asset_1/component_1"] = doc
			app.selected_sampling_input_id = "guide_1"
			app.selected_sampling_input_kind = "cut"
			app.geometry_seeding_advanced_pattern_expanded = true
			app.geometry_meshing_advanced_relaxation_expanded = true
		else:
			app.geometry_documents.erase("asset_1/component_1")
			app.selected_sampling_input_id = ""
			app.selected_sampling_input_kind = ""
			app.geometry_seeding_advanced_pattern_expanded = false
			app.geometry_meshing_advanced_relaxation_expanded = false
		if bool(c.get("gradient", false)):
			comp["weighting"] = {"method": WeightingService.AXIS_GRADIENT,
				"parameters": {"direction": WeightingService.LEFT_TO_RIGHT,
					"curve": WeightingService.EASE_OUT, "invert": true, "strength": 0.75}}
		else:
			comp.erase("weighting")
		app._render_inspector()
		var out: Array = []
		_collect(app.inspector_content, out)
		print("### %s/%s comp=%s grp=%s guide=%s" % [c["m"], c["sub"], c["comp"], c["grp"], c["gd"]])
		for l in out: print(l)
	app.free()
	quit(0)
