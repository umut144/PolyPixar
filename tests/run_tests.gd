extends SceneTree

var failures := 0


func _init() -> void:
	_test_add_close_and_validate()
	_test_delete_exactly_one_point()
	_test_delete_multiple_points_and_protect_closed_minimum()
	_test_ids_are_not_reused()
	_test_insert_preserves_curve()
	_test_geometry_sampling_service()
	_test_geometry_sampling_ui_shell()
	_test_geometry_seeding_service()
	_test_motion_selection_context()
	_test_motion_player()
	_test_motion_sampler()
	_test_motion_asset_preview_geometry()
	_test_motion_resource_shells()
	_test_motion_path_topology_and_sampler()
	_test_motion_act_evaluator()
	_test_motion_module_separators()
	_test_motion_sequence_evaluator()
	if failures == 0:
		print("All AssetFlow2D tests passed.")
		quit(0)
	else:
		push_error("%d AssetFlow2D test(s) failed." % failures)
		quit(1)


func _component() -> Dictionary:
	return {"points": [], "edges": [], "chains": []}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _test_add_close_and_validate() -> void:
	var component := _component()
	var first_id := BezierTopology.add_point(component, Vector2.ZERO, "corner")
	BezierTopology.add_point(component, Vector2(1.0, 0.0), "aligned")
	var last_id := BezierTopology.add_point(component, Vector2(1.0, 1.0), "free")
	_expect(BezierTopology.close_active_chain(component), "A three-point chain should close.")
	_expect(BezierTopology.validate(component).is_empty(), "A newly closed chain should be valid.")
	_expect(bool(BezierTopology.point_by_id(component["points"], first_id).get("preserve_point", false)), "The first closing endpoint should be preserved.")
	_expect(bool(BezierTopology.point_by_id(component["points"], last_id).get("preserve_point", false)), "The last closing endpoint should be preserved.")


func _test_delete_exactly_one_point() -> void:
	var component := _component()
	var ids: Array[String] = []
	for point_index in range(5):
		ids.append(BezierTopology.add_point(component, Vector2(point_index, 0.0), "aligned"))
	BezierTopology.close_active_chain(component)
	_expect(BezierTopology.delete_point(component, ids[2]), "The selected point should be deleted.")
	_expect(component["points"].size() == 4, "Deleting one point must remove exactly one point.")
	_expect(not BezierTopology.point_by_id(component["points"], ids[3]).is_empty(), "The following point must survive deletion.")
	_expect(str(BezierTopology.point_by_id(component["points"], ids[3]).get("mode", "")) == "aligned", "Surviving handle modes must be retained.")
	_expect(BezierTopology.validate(component).is_empty(), "The bridged chain should remain valid.")


func _test_ids_are_not_reused() -> void:
	var component := _component()
	var first_id := BezierTopology.add_point(component, Vector2.ZERO, "linear")
	var second_id := BezierTopology.add_point(component, Vector2.ONE, "linear")
	BezierTopology.delete_point(component, second_id)
	var replacement_id := BezierTopology.add_point(component, Vector2(2.0, 2.0), "linear")
	_expect(replacement_id != first_id and replacement_id != second_id, "Point IDs must never be reused after deletion.")


func _test_delete_multiple_points_and_protect_closed_minimum() -> void:
	var component := _component()
	var ids: Array[String] = []
	for point_index in range(5):
		ids.append(BezierTopology.add_point(component, Vector2(point_index, point_index % 2), "free"))
	BezierTopology.close_active_chain(component)
	var deleted := BezierTopology.delete_points(component, [ids[1], ids[3], ids[4]])
	_expect(deleted.size() == 2, "A closed chain must stop deleting when three points remain.")
	_expect(component["points"].size() == 3, "A closed chain must retain its minimum three points.")
	_expect(BezierTopology.validate(component).is_empty(), "Multi-delete must retain a valid closed chain.")


func _test_insert_preserves_curve() -> void:
	var component := _component()
	BezierTopology.add_point(component, Vector2.ZERO, "free", Vector2(0.5, 0.0))
	BezierTopology.add_point(component, Vector2(1.0, 1.0), "free", Vector2(0.5, 0.0))
	var original_edge_id := str(component["edges"][0]["id"])
	var inserted_id := BezierTopology.insert_point_on_edge(component, original_edge_id, 0.5)
	_expect(not inserted_id.is_empty(), "Splitting an edge should create a point.")
	_expect(component["points"].size() == 3 and component["edges"].size() == 2, "Splitting should replace one edge with two connected edges.")
	_expect(BezierTopology.validate(component).is_empty(), "A split open chain should remain valid.")


func _test_geometry_sampling_service() -> void:
	var component := _component()
	var first_id := BezierTopology.add_point(component, Vector2(0.0, 0.0), "corner")
	var curve_id := BezierTopology.add_point(component, Vector2(10.0, 0.0), "free")
	var last_id := BezierTopology.add_point(component, Vector2(10.0, 10.0), "linear")
	BezierTopology.add_point(component, Vector2(0.0, 10.0), "linear")
	_expect(BezierTopology.close_active_chain(component), "Sampling fixture should form a closed outer Chain.")
	var curve_point := BezierTopology.point_by_id(component["points"], curve_id)
	curve_point["handle_source"] = "manual"
	curve_point["handle_in"] = Vector2(-5.0, 7.0)
	curve_point["handle_out"] = Vector2(0.0, 5.0)
	var even := GeometrySamplingService.generate(component, {"method": GeometrySamplingService.EVEN_SPACING, "parameters": {"spacing": 2.5}})
	_expect(bool(even.get("valid", false)), "Even Spacing should sample a valid closed Component.")
	_expect(int(even.get("sample_count", 0)) > component["points"].size(), "Even Spacing should add derived Points without replacing authored Points.")
	var even_samples: Array = even.get("chains", [])[0].get("samples", [])
	_expect(str(even_samples.front().get("source_point_id", "")) == first_id, "The first authored Point should remain the first ordered sample.")
	var source_ids: Array[String] = []
	for sample in even_samples:
		var source_id := str(sample.get("source_point_id", ""))
		if not source_id.is_empty():
			source_ids.append(source_id)
	_expect(first_id in source_ids and curve_id in source_ids and last_id in source_ids, "Every authored edge endpoint should survive boundary sampling.")
	_expect(bool(even_samples.front().get("preserved", false)), "A preserve_point source must carry the preserved guarantee into the sample result.")
	_expect(source_ids.count(first_id) == 1, "A closed sampled Chain must not duplicate its first Point at the end.")
	var adaptive_low := GeometrySamplingService.generate(component, {"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 20.0, "feature_detail": 0.0}})
	var adaptive_high := GeometrySamplingService.generate(component, {"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 20.0, "feature_detail": 1.0}})
	_expect(bool(adaptive_high.get("valid", false)) and int(adaptive_high.get("sample_count", 0)) > int(adaptive_low.get("sample_count", 0)), "Higher Adaptive Feature Detail should refine curved regions.")
	var repeated := GeometrySamplingService.generate(component, {"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 20.0, "feature_detail": 1.0}})
	_expect(repeated == adaptive_high, "Sampling must be deterministic for the same topology and recipe.")
	var original_position: Vector2 = BezierTopology.point_by_id(component["points"], first_id)["position"]
	adaptive_high["chains"][0]["samples"][0]["position"] = Vector2(999.0, 999.0)
	_expect(Vector2(BezierTopology.point_by_id(component["points"], first_id)["position"]) == original_position, "Sampling results must not mutate canonical Component topology.")
	var open_component := _component()
	BezierTopology.add_point(open_component, Vector2.ZERO, "linear")
	BezierTopology.add_point(open_component, Vector2.ONE, "linear")
	_expect(not bool(GeometrySamplingService.generate(open_component).get("valid", true)), "An open contour should fail visibly at the mesh-pipeline Sampling boundary.")
	var application_script = load("res://scripts/main.gd")
	var application: Control = application_script.new()
	_expect(application._has_supported_schema({"schema_version": 20}) and not application._has_supported_schema({"schema_version": 22}), "Schema 21 should keep older Workspace documents readable and reject unknown future schemas.")
	var geometry_document: Dictionary = application._default_geometry_document("asset_1", "component_1")
	geometry_document["sampling"]["recipe"] = {"method": GeometrySamplingService.EVEN_SPACING, "parameters": {"spacing": 2.5, "feature_detail": GeometrySamplingService.DEFAULT_FEATURE_DETAIL}}
	var baked_result := even.duplicate(true)
	baked_result["bake_id"] = "bake_test"
	geometry_document["sampling"]["bake"] = baked_result
	var serialized_geometry: Dictionary = application._serialize_geometry_document(geometry_document)
	_expect(int(serialized_geometry.get("schema_version", 0)) == 21 and serialized_geometry.get("sampling", {}).get("bake", {}).get("chains", [])[0].get("samples", [])[0].get("position", null) is Array, "Geometry bakes should serialize derived positions as schema-21 JSON arrays.")
	var normalized_geometry: Dictionary = application._normalize_geometry_document(serialized_geometry, "asset_1", "component_1")
	_expect(normalized_geometry.get("sampling", {}).get("bake", {}).get("chains", [])[0].get("samples", [])[0].get("position", null) is Vector2, "Geometry bake loading should restore local sample positions as Vector2 values.")
	var test_assets: Array[Dictionary] = [{"id": "asset_1", "components": [component]}]
	application.assets = test_assets
	application.geometry_documents["asset_1/component_1"] = normalized_geometry
	_expect(application._geometry_sampling_status("asset_1", "component_1", component) == "Baked", "A bake matching its recipe and source fingerprint should report Baked.")
	BezierTopology.point_by_id(component["points"], curve_id)["position"] += Vector2.ONE
	_expect(application._geometry_sampling_status("asset_1", "component_1", component) == "Stale", "Changing canonical topology should make a persisted bake stale without rewriting it.")
	application.free()


func _test_geometry_sampling_ui_shell() -> void:
	var component := _component()
	BezierTopology.add_point(component, Vector2.ZERO, "corner")
	BezierTopology.add_point(component, Vector2(10.0, 0.0), "linear")
	BezierTopology.add_point(component, Vector2(10.0, 10.0), "linear")
	BezierTopology.add_point(component, Vector2(0.0, 10.0), "linear")
	BezierTopology.close_active_chain(component)
	component.merge({"id": "component_1", "name": "Body", "visibility": true})
	var application_script = load("res://scripts/main.gd")
	var application: Control = application_script.new()
	application._build_ui()
	var test_assets: Array[Dictionary] = [{"id": "asset_1", "name": "Wizard", "visibility": true, "components": [component]}]
	application.assets = test_assets
	application.active_module = "Geometry"
	application.active_geometry_submodule = "Sampling"
	application.selected_asset_id = "asset_1"
	application.selected_component_id = "component_1"
	application.expanded_assets["asset_1"] = true
	application._render_outliner()
	application._render_inspector()
	application._render_canvas_context()
	_expect(application.geometry_sampling_workspace.visible, "Geometry Sampling should own a dedicated visible centre workspace.")
	_expect(application.outliner_list.get_child_count() > 1, "Sampling Outliner should expose the Asset/Component hierarchy.")
	_expect(application.inspector_content.get_child_count() >= 8, "A selected Component should expose Sampling method, parameters, result, Generate, and Bake controls.")
	_expect(application.geometry_sampling_workspace.component.get("points", []).size() == 4, "Sampling Workspace should receive an immutable Component view copy.")
	application.geometry_sampling_workspace.component["points"][0]["position"] = Vector2(999.0, 999.0)
	_expect(Vector2(component["points"][0]["position"]) == Vector2.ZERO, "Sampling Workspace presentation copies must not mutate canonical topology.")
	var spacing_input := SpinBox.new()
	spacing_input.min_value = GeometrySamplingService.MIN_SPACING
	spacing_input.max_value = 10000.0
	application._commit_geometry_spacing_text("1,25", spacing_input)
	_expect(is_equal_approx(float(application._geometry_sampling_recipe("asset_1", "component_1").get("parameters", {}).get("spacing", 0.0)), 1.25), "Sampling Spacing should accept comma-decimal direct input.")
	application._commit_geometry_spacing_text("2.50", spacing_input)
	_expect(is_equal_approx(float(application._geometry_sampling_recipe("asset_1", "component_1").get("parameters", {}).get("spacing", 0.0)), 2.5), "Sampling Spacing should accept dot-decimal direct input.")
	spacing_input.free()
	application.geometry_documents["asset_1/component_1"] = application._default_geometry_document("asset_1", "component_1")
	var history_snapshot: Dictionary = application._capture_history_snapshot()
	application.geometry_documents["asset_1/component_1"]["sampling"]["recipe"]["parameters"]["spacing"] = 42.0
	application._restore_history_snapshot(history_snapshot)
	_expect(is_equal_approx(float(application.geometry_documents["asset_1/component_1"]["sampling"]["recipe"]["parameters"]["spacing"]), GeometrySamplingService.DEFAULT_SPACING), "Geometry recipes and bakes should participate in Workspace Undo/Redo snapshots.")
	application.free()


func _test_geometry_seeding_service() -> void:
	var component := _component()
	component.merge({"id": "component_1", "name": "Body", "visibility": true})
	BezierTopology.add_point(component, Vector2.ZERO, "corner")
	BezierTopology.add_point(component, Vector2(10.0, 0.0), "linear")
	BezierTopology.add_point(component, Vector2(10.0, 10.0), "linear")
	BezierTopology.add_point(component, Vector2(0.0, 10.0), "linear")
	BezierTopology.close_active_chain(component)
	var sampling := GeometrySamplingService.generate(component, {"method": GeometrySamplingService.EVEN_SPACING, "parameters": {"spacing": 1.0}})
	sampling["bake_id"] = "sampling_bake_test"
	var first := GeometrySeedingService.generate(sampling, {"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 2.0, "seed": 17}})
	var repeated := GeometrySeedingService.generate(sampling, {"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 2.0, "seed": 17}})
	_expect(bool(first.get("valid", false)) and int(first.get("seed_count", 0)) > 0, "Poisson Fill should generate interior Seeds from a valid Sampling Bake.")
	_expect(first == repeated, "Poisson Fill must be deterministic for the same Sampling Bake, Spacing, and Seed.")
	var positions: Array[Vector2] = []
	for seed_data in first.get("seeds", []):
		var position := Vector2(seed_data.get("position", Vector2.ZERO))
		_expect(GeometrySeedingService.point_is_inside(sampling, position), "Every generated Seed must remain inside the sampled Component boundary.")
		for previous in positions:
			_expect(position.distance_to(previous) >= 1.999, "Poisson Fill Seeds must respect their requested minimum Spacing.")
		positions.append(position)
	_expect(str(first.get("sampling_bake_id", "")) == "sampling_bake_test", "A Seeding result must retain its exact Sampling Bake dependency.")
	_expect(not bool(GeometrySeedingService.generate({}).get("valid", true)), "Seeding must fail visibly without a valid Sampling Bake.")
	var application_script = load("res://scripts/main.gd")
	var application: Control = application_script.new()
	var geometry_document: Dictionary = application._default_geometry_document("asset_1", "component_1")
	geometry_document["sampling"]["recipe"] = {"method": GeometrySamplingService.EVEN_SPACING, "parameters": {"spacing": 1.0}}
	geometry_document["sampling"]["bake"] = sampling
	first["bake_id"] = "seeding_bake_test"
	first["edited"] = true
	first["seeds"][0]["origin"] = "manual_adjusted"
	geometry_document["seeding"]["recipe"] = {"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 2.0, "seed": 17}}
	geometry_document["seeding"]["bake"] = first
	var serialized: Dictionary = application._serialize_geometry_document(geometry_document)
	_expect(serialized.get("seeding", {}).get("bake", {}).get("seeds", [])[0].get("position", null) is Array, "Seeding Bake positions should serialize as schema JSON arrays.")
	var normalized: Dictionary = application._normalize_geometry_document(serialized, "asset_1", "component_1")
	_expect(normalized.get("seeding", {}).get("bake", {}).get("seeds", [])[0].get("position", null) is Vector2 and bool(normalized.get("seeding", {}).get("bake", {}).get("edited", false)), "Seeding Bake loading should restore editable Seed vectors and edit state.")
	var test_assets: Array[Dictionary] = [{"id": "asset_1", "name": "Asset", "components": [component]}]
	application.assets = test_assets
	application.geometry_documents["asset_1/component_1"] = normalized
	_expect(application._geometry_seeding_status("asset_1", "component_1", component) == "Edited", "A matching manually adjusted Seeding Bake should report Edited.")
	normalized["seeding"]["recipe"]["parameters"]["seed"] = 18
	_expect(application._geometry_seeding_status("asset_1", "component_1", component) == "Stale", "Changing the Seeding recipe should preserve but mark its Bake stale.")
	normalized["seeding"]["recipe"]["parameters"]["seed"] = 17
	application._build_ui()
	application.active_module = "Geometry"
	application.active_geometry_submodule = "Seeding"
	application.selected_asset_id = "asset_1"
	application.selected_component_id = "component_1"
	application.expanded_assets["asset_1"] = true
	application._render_outliner()
	application._render_inspector()
	application._render_canvas_context()
	_expect(application.geometry_seeding_workspace.visible and application.inspector_content.get_child_count() >= 10, "Geometry Seeding should expose its dedicated Workspace and compact Poisson Inspector.")
	normalized["seeding"]["bake"] = {}
	application.geometry_seeding_preview_key = "asset_1/component_1"
	application.geometry_seeding_preview = GeometrySeedingService.generate(sampling, normalized["seeding"]["recipe"])
	_expect(application._geometry_seeding_status("asset_1", "component_1", component) == "Preview", "A valid generated result should be available to Edit Seeds before a separate Bake click.")
	application._toggle_geometry_seeding_edit()
	_expect(application.geometry_seeding_edit_active and application.geometry_seeding_workspace.editing_enabled and not normalized["seeding"]["bake"].is_empty(), "Entering Edit Seeds from Preview should accept that Preview as a persistent Bake and enable mouse editing immediately.")
	var seed_count_before := int(normalized["seeding"]["bake"].get("seed_count", 0))
	application.geometry_seeding_workspace.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	application.geometry_seeding_workspace.size = Vector2(200.0, 200.0)
	application.geometry_seeding_workspace.camera_position = Vector2(5.0, 5.0)
	application.geometry_seeding_workspace.camera_zoom = 10.0
	application.geometry_seeding_workspace.fitted = true
	application._set_geometry_seeding_edit_tool("add")
	var add_event := InputEventMouseButton.new()
	add_event.button_index = MOUSE_BUTTON_LEFT
	add_event.pressed = true
	add_event.position = application.geometry_seeding_workspace._to_screen(Vector2(1.0, 1.0))
	application.geometry_seeding_workspace._gui_input(add_event)
	var edited_seeds: Array = normalized["seeding"]["bake"].get("seeds", [])
	_expect(edited_seeds.size() == seed_count_before + 1 and str(edited_seeds.back().get("origin", "")) == "manual", "Edit Seeds should route an Add click into one persistent manual Seed without changing canonical topology.")
	application._set_geometry_seeding_edit_tool("remove")
	var remove_event := InputEventMouseButton.new()
	remove_event.button_index = MOUSE_BUTTON_LEFT
	remove_event.pressed = true
	remove_event.position = application.geometry_seeding_workspace._to_screen(Vector2(1.0, 1.0))
	application.geometry_seeding_workspace._gui_input(remove_event)
	_expect(normalized["seeding"]["bake"].get("seeds", []).size() == seed_count_before, "Edit Seeds should route a Remove click to only the clicked persistent Seed.")
	var spacing_input := SpinBox.new()
	spacing_input.min_value = GeometrySeedingService.MIN_SPACING
	spacing_input.max_value = 10000.0
	application._commit_geometry_seeding_spacing_text("1,75", spacing_input)
	_expect(is_equal_approx(float(application._geometry_seeding_recipe("asset_1", "component_1").get("parameters", {}).get("spacing", 0.0)), 1.75), "Seeding Spacing should accept comma-decimal direct input and update its Recipe.")
	spacing_input.free()
	application.free()


func _test_motion_selection_context() -> void:
	var selection := MotionSelection.new()
	selection.select_asset("asset_1")
	_expect(selection.kind == MotionSelection.ASSET and selection.asset_id == "asset_1", "Motion Asset selection should clear nested context.")
	selection.select_state("asset_1", "state_idle")
	_expect(selection.matches(MotionSelection.STATE, "state_idle"), "Motion State selection should retain its State context.")
	selection.select_item(MotionSelection.TRANSITION, "asset_1", "state_idle", "transition_idle_01")
	_expect(selection.matches(MotionSelection.TRANSITION, "state_idle", "transition_idle_01"), "Motion item selection should retain State and item IDs.")
	var workspace := MotionWorkspace.new()
	workspace.set_selection_model(selection)
	workspace.set_asset("asset_1", "Asset")
	var preview := workspace.get_selected_preview()
	_expect(str(preview.get("kind", "")) == MotionSelection.TRANSITION and workspace.item_display_name(MotionSelection.TRANSITION, preview.get("item", {})) == "→ WALK", "Motion Preview lookup should resolve the selected Transition by stable IDs.")
	_expect(workspace.get_states_for_asset("asset_1").size() == 3, "A new Motion Preview document should start with IDLE, WALK, and RUN.")
	_expect(workspace.add_state("JUMP").is_empty(), "A unique State should be added to the session Preview.")
	_expect(workspace.get_states_for_asset("asset_1").size() == 4 and selection.state_id == "state_04", "Added States should receive a stable monotonic ID and become selected.")
	_expect(not workspace.add_state("jump").is_empty(), "State names should be unique without regard to letter case.")
	_expect(workspace.rename_state("state_04", "AIRBORNE").is_empty(), "A State should be renameable inside the session Preview.")
	_expect(not workspace.rename_state("state_04", "IDLE").is_empty(), "A State should not be renameable to an existing State name.")
	workspace.set_asset("asset_2", "Other Asset")
	_expect(workspace.get_states_for_asset("asset_2").size() == 3, "Each Asset should receive an independent session Preview document.")
	workspace.set_asset("asset_1", "Asset")
	_expect(workspace.state_name("state_04") == "AIRBORNE", "Switching Assets should retain session-only State edits.")
	_expect(workspace.remove_state("state_04"), "An existing State should be removable from the session Preview.")
	_expect(workspace.add_state("LAND").is_empty() and selection.state_id == "state_05", "Removed State IDs must not be reused during the session.")
	_expect(workspace.add_motion("state_05").is_empty(), "A Motion should be addable to a session State.")
	_expect(selection.matches(MotionSelection.MOTION, "state_05", "motion_05_01"), "A new Motion should receive a stable ID and become selected.")
	var motion := workspace.find_motion("state_05", "motion_05_01")
	_expect(str(motion.get("domain", "")) == MotionWorkspace.OUTER and str(motion.get("primitive", "")) == MotionWorkspace.BOB and str(motion.get("target_scope", "")) == MotionWorkspace.TARGET_ASSET, "A new Motion should start as an Entire Asset Outer Bob.")
	_expect(workspace.set_motion_property("state_05", "motion_05_01", "domain", MotionWorkspace.INNER), "A Motion Domain should be editable.")
	_expect(str(motion.get("primitive", "")) == MotionWorkspace.SPINE_SWAY, "Switching to Inner should select a compatible primitive.")
	_expect(workspace.set_motion_target("state_05", "motion_05_01", MotionWorkspace.TARGET_COMPONENT, "component_1"), "A Motion target Component should be editable.")
	_expect(workspace.set_motion_parameter("state_05", "motion_05_01", "strength", 0.75) and is_equal_approx(float(motion.get("parameters", {}).get("strength", 0.0)), 0.75), "Primitive parameters should remain part of the session Motion.")
	_expect(workspace.primitive_options(MotionWorkspace.OUTER) == [MotionWorkspace.BOB] and workspace.primitive_options(MotionWorkspace.INNER) == [MotionWorkspace.SPINE_SWAY], "Animation Primitive options should exclude Path traversal after the Motion module split.")
	_expect(workspace.set_motion_property("state_05", "motion_05_01", "domain", MotionWorkspace.OUTER), "A Motion should switch back to the Outer Domain.")
	_expect(str(motion.get("primitive", "")) == MotionWorkspace.BOB and str(motion.get("target_scope", "")) == MotionWorkspace.TARGET_ASSET, "Switching back to Outer should install the Animation-local Bob defaults.")
	_expect(workspace.rename_motion("state_05", "motion_05_01", "Landing Sway").is_empty(), "A session Motion should be renameable.")
	_expect(workspace.remove_motion("state_05", "motion_05_01"), "A session Motion should be removable.")
	_expect(workspace.add_motion("state_05").is_empty() and selection.item_id == "motion_05_02", "Removed Motion IDs must not be reused during the session.")
	_expect(workspace.add_transition("state_05").is_empty() and selection.item_id == "transition_05_01", "A Transition should receive a stable ID and become selected.")
	var transition := workspace.find_transition("state_05", "transition_05_01")
	_expect(str(transition.get("target_state_id", "")) != "state_05" and str(transition.get("exit_policy", "")) == MotionWorkspace.EXIT_ANY_PHASE, "A Transition should default to another target State and Any Phase exit.")
	_expect(workspace.set_transition_property("state_05", "transition_05_01", "exit_policy", MotionWorkspace.EXIT_AFTER_PHASE) and workspace.set_transition_property("state_05", "transition_05_01", "entry_mode", MotionWorkspace.ENTRY_PRESERVE_PHASE), "Transition Exit and Entry policies should be editable independently.")
	_expect(workspace.set_transition_property("state_05", "transition_05_01", "exit_phase", 0.75, false) and workspace.set_transition_property("state_05", "transition_05_01", "blend_duration", 0.3, false), "Transition timing values should remain in the session model.")
	_expect(workspace.add_transition("state_05").is_empty() and selection.item_id == "transition_05_02", "Multiple Transitions should be addable to a State.")
	_expect(workspace.move_transition("state_05", "transition_05_02", -1) and workspace.transition_index("state_05", "transition_05_02") == 0, "Transition list order should be editable as evaluation priority.")
	_expect(workspace.remove_transition("state_05", "transition_05_01"), "A session Transition should be removable.")
	_expect(workspace.add_transition("state_05").is_empty() and selection.item_id == "transition_05_03", "Removed Transition IDs must not be reused during the session.")
	_expect(workspace.get_contract_parameters().size() == 2 and not workspace.find_contract_parameter("parameter_speed").is_empty(), "A session Animation should expose the default typed Simulation Contract.")
	_expect(workspace.rule_operators(MotionWorkspace.PARAM_BOOL) == [MotionWorkspace.OP_IS_TRUE, MotionWorkspace.OP_IS_FALSE], "Bool parameters should expose only compatible Rule operators.")
	_expect(workspace.add_contract_parameter().is_empty() and not workspace.find_contract_parameter("parameter_01").is_empty(), "A Simulation Contract parameter should receive a stable ID.")
	_expect(workspace.set_contract_parameter_property("parameter_01", "name", "jump_requested").is_empty() and workspace.set_contract_parameter_property("parameter_01", "type", MotionWorkspace.PARAM_BOOL).is_empty(), "A Contract parameter name and type should be editable.")
	_expect(not workspace.set_contract_parameter_property("parameter_01", "name", "speed").is_empty(), "Simulation Contract parameter names should be unique.")
	_expect(workspace.add_transition_rule("state_05", "transition_05_03").is_empty(), "A typed Rule should be addable to a Transition.")
	var rule := workspace.find_transition_rule("state_05", "transition_05_03", "rule_05_03_01")
	_expect(str(rule.get("parameter_id", "")) == "parameter_speed" and str(rule.get("operator", "")) == MotionWorkspace.OP_EQUAL, "A new Rule should use the first Contract parameter and a compatible operator.")
	_expect(workspace.set_transition_rule_property("state_05", "transition_05_03", "rule_05_03_01", "parameter_id", "parameter_01"), "A Rule should reference a Contract parameter by stable ID.")
	_expect(str(rule.get("operator", "")) == MotionWorkspace.OP_IS_TRUE and workspace.transition_rules_valid(workspace.find_transition("state_05", "transition_05_03")), "Changing Rule parameter type should install a compatible operator.")
	_expect(not workspace.remove_contract_parameter("parameter_01").is_empty(), "A Contract parameter referenced by a Rule should not be removable silently.")
	_expect(workspace.remove_transition_rule("state_05", "transition_05_03", "rule_05_03_01") and workspace.remove_contract_parameter("parameter_01").is_empty(), "A Contract parameter should be removable after its Rules are removed.")
	_expect(workspace.add_contract_parameter().is_empty() and not workspace.find_contract_parameter("parameter_02").is_empty(), "Removed Contract parameter IDs must not be reused during the session.")
	_expect(workspace.add_marker("state_05").is_empty() and selection.item_id == "marker_05_01", "A Marker should receive a stable ID and become selected.")
	var marker := workspace.find_marker("state_05", "marker_05_01")
	_expect(workspace.set_marker_property("state_05", "marker_05_01", "event_id", "footstep").is_empty() and workspace.set_marker_property("state_05", "marker_05_01", "kind", MotionWorkspace.MARKER_SFX).is_empty(), "Marker Event ID and kind should be editable.")
	_expect(workspace.set_marker_property("state_05", "marker_05_01", "phase", 0.75, false).is_empty() and is_equal_approx(float(marker.get("phase", 0.0)), 0.75), "A Marker should retain its normalized phase.")
	_expect(workspace.selected_marker_phases() == [0.75], "The selected State should expose Marker phases for scrubber ticks.")
	_expect(workspace.remove_marker("state_05", "marker_05_01"), "A session Marker should be removable.")
	_expect(workspace.add_marker("state_05").is_empty() and selection.item_id == "marker_05_02", "Removed Marker IDs must not be reused during the session.")
	workspace.free()
	var persisted_selection := MotionSelection.new()
	var persisted_workspace := MotionWorkspace.new()
	persisted_workspace.set_selection_model(persisted_selection)
	var persisted_animation := MotionWorkspace.create_default_animation_document()
	var change_count := [0]
	persisted_workspace.document_change_requested.connect(func() -> void: change_count[0] += 1)
	persisted_workspace.set_asset("asset_persisted", "Persisted", [], persisted_animation)
	_expect(persisted_workspace.add_state("SAVED").is_empty(), "A persisted Animation document should remain authorable through MotionWorkspace.")
	_expect(persisted_animation.get("states", []).size() == 4 and str(persisted_animation.get("states", [])[3].get("name", "")) == "SAVED", "MotionWorkspace edits should mutate the Asset-owned Animation document directly.")
	_expect(change_count[0] == 1, "A document edit should request an Undo snapshot before mutation.")
	var json_round_trip = JSON.parse_string(JSON.stringify(persisted_animation))
	var normalized_round_trip := MotionWorkspace.normalize_animation_document(json_round_trip)
	_expect(normalized_round_trip.get("states", []).size() == 4 and normalized_round_trip.has("simulation_contract"), "Persisted Animation data should survive a JSON round trip and normalization.")
	_expect(MotionWorkspace.normalize_animation_document({}).get("states", []).size() == 3, "An older Asset without Animation data should migrate to the IDLE/WALK/RUN document.")
	_expect(not persisted_workspace.validation_issues().is_empty(), "Animation validation should report unresolved default Motion Component targets.")
	persisted_workspace.free()
	selection.select_item("unsupported", "asset_1", "state_idle", "invalid")
	_expect(selection.kind == MotionSelection.NONE and selection.asset_id.is_empty(), "Unsupported Motion selection kinds should clear the selection safely.")


func _test_motion_player() -> void:
	var document := MotionWorkspace.create_default_animation_document()
	var player := MotionPlayer.new()
	var fired_markers: Array[String] = []
	var state_changes: Array[String] = []
	player.marker_fired.connect(func(_state_id: String, event_id: String, _kind: String) -> void: fired_markers.append(event_id))
	player.state_changed.connect(func(_previous: String, state_id: String) -> void: state_changes.append(state_id))
	player.set_document(document)
	_expect(player.current_state_id == "state_idle" and is_zero_approx(player.phase), "MotionPlayer should initialize at the first State and normalized phase zero.")
	_expect(player.set_parameter_value("parameter_speed", 0.0) and player.play(), "MotionPlayer should accept typed runtime parameters and start playback.")
	player.advance(0.6)
	_expect(player.current_state_id == "state_idle" and is_equal_approx(player.phase, 0.6), "An ineligible Transition should not interrupt State phase progression.")
	_expect(fired_markers == ["rustle"], "MotionPlayer should emit Markers crossed by normalized phase.")
	player.seek(0.0)
	player.set_parameter_value("parameter_speed", 0.2)
	player.advance(0.1)
	_expect(player.current_state_id == "state_walk" and is_zero_approx(player.phase), "A matching Rule should take the first eligible Transition and apply Restart entry.")
	_expect(not player.blend.is_empty() and is_zero_approx(player.blend_weight()), "A Transition should expose its active blend interval.")
	player.set_state("state_walk", 0.4)
	player.set_parameter_value("parameter_speed", 0.8)
	player.advance(0.1)
	_expect(player.current_state_id == "state_run" and is_equal_approx(player.phase, 0.5), "Transition priority and Preserve Phase entry should be deterministic.")
	player.advance(0.075)
	_expect(player.current_state_id == "state_run" and is_equal_approx(player.blend_weight(), 0.5), "Blend progress should advance independently of document data.")
	var idle_transition: Dictionary = document["states"][0]["transitions"][0]
	idle_transition["exit_policy"] = MotionWorkspace.EXIT_LOOP_END
	player.set_state("state_idle", 0.9)
	player.set_parameter_value("parameter_speed", 1.0)
	player.advance(0.05)
	_expect(player.current_state_id == "state_idle", "At Loop End should wait until the normalized phase crosses its boundary.")
	player.advance(0.1)
	_expect(player.current_state_id == "state_walk", "At Loop End should permit a matching Transition on wrap.")
	idle_transition["exit_policy"] = MotionWorkspace.EXIT_AFTER_PHASE
	idle_transition["exit_phase"] = 0.8
	player.set_state("state_idle", 0.7)
	player.advance(0.05)
	_expect(player.current_state_id == "state_idle", "After Phase should block a Transition before its threshold.")
	player.advance(0.1)
	_expect(player.current_state_id == "state_walk", "After Phase should allow a matching Transition after its threshold.")
	idle_transition["exit_policy"] = MotionWorkspace.EXIT_ANY_PHASE
	idle_transition["rules"] = [
		{"id": "rule_speed", "parameter_id": "parameter_speed", "operator": MotionWorkspace.OP_GREATER, "value": 0.1},
		{"id": "rule_grounded", "parameter_id": "parameter_grounded", "operator": MotionWorkspace.OP_IS_TRUE, "value": 0.0}
	]
	player.set_state("state_idle", 0.0)
	player.set_parameter_value("parameter_grounded", false)
	player.advance(0.1)
	_expect(player.current_state_id == "state_idle", "Rules · ALL should reject a Transition when one typed Rule is false.")
	player.set_parameter_value("parameter_grounded", true)
	player.advance(0.1)
	_expect(player.current_state_id == "state_walk", "Rules · ALL should accept a Transition when every typed Rule matches.")
	player.pause()
	var paused_phase := player.phase
	player.advance(1.0)
	_expect(is_equal_approx(player.phase, paused_phase) and state_changes.has("state_walk") and state_changes.has("state_run"), "Paused playback should not advance and State changes should be observable.")


func _test_motion_asset_preview_geometry() -> void:
	var component := _component()
	var point_a := BezierTopology.add_point(component, Vector2(0.0, 0.0), "aligned")
	BezierTopology.add_point(component, Vector2(10.0, 0.0), "aligned")
	BezierTopology.add_point(component, Vector2(5.0, 10.0), "aligned")
	_expect(BezierTopology.close_active_chain(component), "Preview test contour should close successfully.")
	var original_point := BezierTopology.point_by_id(component.get("points", []), point_a)
	var original_handle: Vector2 = original_point.get("handle_out", Vector2.ZERO)
	component["id"] = "component_preview"
	component["name"] = "Wizard Contour"
	component["visibility"] = true
	component["transform"] = {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}
	var preview := MotionAssetPreview.new()
	preview.set_asset({"id": "asset_preview", "components": [component]})
	var paths := preview._asset_paths()
	_expect(paths.size() == 1 and paths[0].get("points", []).size() > 3, "Animation Preview should derive a sampled path from a Wizard Bézier contour.")
	_expect(MotionAssetPreview._world_offset_to_preview(Vector2(2.0, 3.0), 4.0) == Vector2(8.0, -12.0), "Animation Preview should map AssetFlow's Y-up world coordinates to Y-down screen coordinates.")
	_expect(Vector2(original_point.get("handle_out", Vector2.ZERO)) == original_handle, "Animation Preview must resolve handles only on immutable geometry copies.")
	preview.free()


func _test_motion_sampler() -> void:
	var document := MotionWorkspace.create_default_animation_document()
	var idle: Dictionary = document["states"][0]
	var component_ids: Array[String] = ["component_a", "component_b"]
	var quarter_samples := MotionSampler.sample_state(idle, 0.25, component_ids)
	_expect(is_equal_approx(Vector2(quarter_samples["component_a"].get("position", Vector2.ZERO)).y, 0.25), "Bob should reach positive Distance at quarter phase.")
	_expect(is_equal_approx(Vector2(quarter_samples["component_b"].get("position", Vector2.ZERO)).y, 0.25), "Entire Asset Bob should sample every visible Component.")
	var half_samples := MotionSampler.sample_state(idle, 0.5, component_ids)
	_expect(is_zero_approx(Vector2(half_samples["component_a"].get("position", Vector2.ZERO)).y), "Bob should return to its rest position at half phase.")
	idle["motions"].append({
		"id": "motion_additive",
		"name": "Additive Bob",
		"enabled": true,
		"domain": MotionWorkspace.OUTER,
		"primitive": MotionWorkspace.BOB,
		"target_scope": MotionWorkspace.TARGET_ASSET,
		"target_component_id": "",
		"phase_offset": 0.0,
		"parameters": {"distance": 0.5, "cycles": 1.0}
	})
	var additive_samples := MotionSampler.sample_state(idle, 0.25, component_ids)
	_expect(is_equal_approx(Vector2(additive_samples["component_a"].get("position", Vector2.ZERO)).y, 0.75), "Multiple Bob Motions should combine additively.")
	idle["motions"][0]["enabled"] = false
	idle["motions"][1]["target_scope"] = MotionWorkspace.TARGET_COMPONENT
	idle["motions"][1]["target_component_id"] = "component_b"
	var targeted_samples := MotionSampler.sample_state(idle, 0.25, component_ids)
	_expect(not targeted_samples.has("component_a") and is_equal_approx(Vector2(targeted_samples["component_b"].get("position", Vector2.ZERO)).y, 0.5), "Component target and enabled state should bound Bob sampling.")
	var source_samples := {"component_a": {"position": Vector2(0.0, 2.0), "rotation": 0.0, "scale": Vector2.ONE}}
	var target_samples := {"component_a": {"position": Vector2(0.0, 6.0), "rotation": 0.0, "scale": Vector2.ONE}}
	var blended := MotionSampler.blend_samples(source_samples, target_samples, ["component_a"], 0.25)
	_expect(is_equal_approx(Vector2(blended["component_a"].get("position", Vector2.ZERO)).y, 3.0), "Outer transform samples should blend source and target values.")
	var preview_point := MotionAssetPreview._apply_preview_transform(Vector2(1.0, 2.0), Vector2.ZERO, {"position": Vector2(0.0, 3.0), "rotation": 0.0, "scale": Vector2.ONE})
	_expect(preview_point == Vector2(1.0, 5.0), "Preview Bob should be applied after the persisted Component transform.")
	var legacy_document := {"states": [{"id": "legacy", "name": "Legacy", "motions": [{"domain": MotionWorkspace.OUTER, "target_component_id": "component_a"}], "transitions": [], "markers": []}]}
	var normalized_legacy := MotionWorkspace.normalize_animation_document(legacy_document)
	_expect(str(normalized_legacy["states"][0]["motions"][0].get("target_scope", "")) == MotionWorkspace.TARGET_COMPONENT, "Legacy explicit Component targets should migrate without becoming Entire Asset targets.")
	var legacy_path_document := {"states": [{"id": "walk", "name": "WALK", "motions": [{"id": "old_path", "domain": MotionWorkspace.OUTER, "primitive": MotionWorkspace.LEGACY_PATH_FOLLOW}], "transitions": [], "markers": []}]}
	var normalized_legacy_path := MotionWorkspace.normalize_animation_document(legacy_path_document)
	_expect(normalized_legacy_path["states"][0]["motions"].is_empty() and normalized_legacy_path.get("legacy_path_follow_motions", []).size() == 1, "Legacy Path Follow Motions should be archived explicitly instead of remaining Animation primitives or being silently deleted.")


func _test_motion_resource_shells() -> void:
	var application_script = load("res://scripts/main.gd")
	var application: Control = application_script.new()
	var path_document: Dictionary = application._default_motion_path("path_7", "Orbit")
	_expect(str(path_document.get("id", "")) == "path_7" and path_document.get("topology", {}).get("points", []).is_empty(), "A Path shell should own a stable ID and independent empty topology.")
	var normalized_path: Dictionary = application._normalize_motion_path({"id": "path_7", "name": "Orbit", "playback": {"duration": 4.0}}, "fallback")
	_expect(is_equal_approx(float(normalized_path.get("playback", {}).get("duration", 0.0)), 4.0) and bool(normalized_path.get("playback", {}).get("loop", false)), "Path normalization should merge persisted playback fields with stable defaults.")
	var sequence_document: Dictionary = application._normalize_motion_sequence({"id": "sequence_3", "name": "Arrival", "entries": [{"id": "entry_1", "asset_id": "asset_1", "animation_state_id": "idle", "path_id": "path_7"}]}, "fallback")
	_expect(str(sequence_document.get("id", "")) == "sequence_3" and sequence_document.get("entries", []).size() == 1, "A Sequence shell should preserve stable composition references without owning Asset or Path data.")
	application.free()


func _test_motion_path_topology_and_sampler() -> void:
	var topology := MotionPathTopology.default_topology()
	var first_id := MotionPathTopology.add_point(topology, Vector2.ZERO)
	var middle_id := MotionPathTopology.add_point(topology, Vector2(1.0, 0.0))
	var last_id := MotionPathTopology.add_point(topology, Vector2(4.0, 0.0))
	_expect(topology["segments"].size() == 2 and MotionPathTopology.validate(topology).is_empty(), "An authored open Path should maintain exactly one Segment between adjacent Points.")
	var halfway := MotionPathSampler.sample(topology, 0.5)
	_expect(bool(halfway.get("valid", false)) and is_equal_approx(Vector2(halfway.get("position", Vector2.ZERO)).x, 2.0), "Path phase should map to approximate arc length rather than equal time per Segment.")
	_expect(is_equal_approx(Vector2(MotionPathSampler.sample(topology, 0.0).get("position", Vector2.ONE)).x, 0.0) and is_equal_approx(Vector2(MotionPathSampler.sample(topology, 1.0).get("position", Vector2.ZERO)).x, 4.0), "Path sampling should preserve exact endpoints.")
	MotionPathTopology.set_handle(topology, first_id, "out", Vector2(0.5, 1.0))
	_expect(str(MotionPathTopology.point_by_id(topology["points"], first_id).get("mode", "")) == "free", "Editing a Path handle should make that Point an explicit free Bézier Point.")
	var serialized := MotionPathTopology.serialize(topology)
	_expect(serialized["points"][0]["position"] is Array and MotionPathTopology.normalize(serialized)["points"][0]["position"] is Vector2, "Path topology should serialize Vector2 values as JSON arrays and restore them losslessly.")
	_expect(MotionPathTopology.delete_point(topology, middle_id) and topology["segments"].size() == 1 and str(topology["segments"][0].get("end_point_id", "")) == last_id, "Deleting a Path Point should reconnect the remaining ordered Points.")
	var path_document := {"topology": topology}
	var canvas := MotionPathWorkspace.new()
	canvas.set_document(path_document)
	canvas.path_document["topology"]["points"][0]["position"] = Vector2(99.0, 99.0)
	_expect(Vector2(path_document["topology"]["points"][0]["position"]) != Vector2(99.0, 99.0), "MotionPathWorkspace must render an immutable document copy rather than mutating Workspace topology.")
	canvas.free()


func _test_motion_act_evaluator() -> void:
	_expect(MotionActEvaluator.primitive_definitions().size() == 3 and MotionActEvaluator.PRIMITIVES == [MotionActEvaluator.SLIDE, MotionActEvaluator.JUMP, MotionActEvaluator.BLINK], "The bounded Act primitive catalog should expose Slide, Jump, and Blink in stable order.")
	var act := {
		"id": "act_1", "name": "Slide Right", "kind": "primitive", "primitive": "slide", "enabled": true,
		"timing": {"duration": 0.6, "easing": MotionActEvaluator.EASE_IN_OUT},
		"parameters": {"direction": Vector2(3.0, 4.0), "distance": 10.0}
	}
	_expect(MotionActEvaluator.validation_issues(act).is_empty(), "A configured Slide Act should validate independently of Path and Animation resources.")
	var end_sample := MotionActEvaluator.sample(act, 1.0)
	_expect(bool(end_sample.get("valid", false)) and Vector2(end_sample.get("transform", {}).get("position", Vector2.ZERO)).is_equal_approx(Vector2(6.0, 8.0)), "Slide should normalize Direction and reach the exact configured Distance at phase one.")
	var half_sample := MotionActEvaluator.sample(act, 0.5)
	_expect(Vector2(half_sample.get("transform", {}).get("position", Vector2.ZERO)).is_equal_approx(Vector2(3.0, 4.0)), "Ease In Out should remain centered at normalized phase 0.5.")
	var invalid := act.duplicate(true)
	invalid["parameters"]["direction"] = Vector2.ZERO
	_expect(not MotionActEvaluator.validation_issues(invalid).is_empty() and not bool(MotionActEvaluator.sample(invalid, 0.5).get("valid", true)), "A zero Slide Direction should be rejected explicitly.")
	var jump := {
		"id": "act_2", "name": "Jump Right", "kind": "primitive", "primitive": MotionActEvaluator.JUMP, "enabled": true,
		"timing": {"duration": 0.8, "easing": MotionActEvaluator.EASE_IN_OUT},
		"parameters": {"direction": Vector2.RIGHT, "distance": 8.0, "height": 5.0, "arc": MotionActEvaluator.JUMP_ARC_SMOOTH}
	}
	_expect(MotionActEvaluator.validation_issues(jump).is_empty(), "A Jump with Direction, Distance, Height, and Arc should validate.")
	var jump_start := MotionActEvaluator.sample(jump, 0.0)
	var jump_apex := MotionActEvaluator.sample(jump, 0.5)
	var jump_end := MotionActEvaluator.sample(jump, 1.0)
	_expect(Vector2(jump_start.get("transform", {}).get("position", Vector2.ONE)).is_equal_approx(Vector2.ZERO), "Jump should start at the rest position.")
	_expect(Vector2(jump_apex.get("transform", {}).get("position", Vector2.ZERO)).is_equal_approx(Vector2(4.0, 5.0)), "A Smooth Jump should reach its configured Height at the centered apex.")
	_expect(Vector2(jump_end.get("transform", {}).get("position", Vector2.ZERO)).is_equal_approx(Vector2(8.0, 0.0)), "Jump should land at the configured travel endpoint without retaining vertical offset.")
	var floaty_jump := jump.duplicate(true)
	floaty_jump["parameters"]["arc"] = MotionActEvaluator.JUMP_ARC_FLOATY
	_expect(Vector2(MotionActEvaluator.sample(floaty_jump, 0.25).get("transform", {}).get("position", Vector2.ZERO)).y > Vector2(MotionActEvaluator.sample(jump, 0.25).get("transform", {}).get("position", Vector2.ZERO)).y, "Floaty Jump should retain more height away from the apex than Smooth Jump.")
	var blink := {
		"id": "act_3", "name": "Wormhole", "kind": "primitive", "primitive": MotionActEvaluator.BLINK, "enabled": true,
		"timing": {"duration": 0.7, "easing": MotionActEvaluator.EASE_LINEAR},
		"parameters": {"direction": Vector2.RIGHT, "distance": 9.0, "anticipation_distance": 1.0, "anticipation_share": 0.5, "minimum_scale": 0.05}
	}
	_expect(MotionActEvaluator.validation_issues(blink).is_empty(), "A Blink with anticipation and wormhole scaling should validate.")
	var blink_start: Dictionary = MotionActEvaluator.sample(blink, 0.0).get("transform", {})
	var blink_anticipation: Dictionary = MotionActEvaluator.sample(blink, 0.5).get("transform", {})
	var blink_midpoint: Dictionary = MotionActEvaluator.sample(blink, 0.9).get("transform", {})
	var blink_fast_exit: Dictionary = MotionActEvaluator.sample(blink, 0.95).get("transform", {})
	var blink_end: Dictionary = MotionActEvaluator.sample(blink, 1.0).get("transform", {})
	_expect(Vector2(blink_start.get("position", Vector2.ONE)).is_equal_approx(Vector2.ZERO) and Vector2(blink_start.get("scale", Vector2.ZERO)).is_equal_approx(Vector2.ONE), "Blink should begin at rest and full scale.")
	_expect(Vector2(blink_anticipation.get("position", Vector2.ZERO)).is_equal_approx(Vector2(-1.0, 0.0)) and Vector2(blink_anticipation.get("scale", Vector2.ZERO)).is_equal_approx(Vector2.ONE), "Blink should complete its backward anticipation at full scale.")
	_expect(Vector2(blink_midpoint.get("position", Vector2.ZERO)).is_equal_approx(Vector2(4.5, 0.0)) and Vector2(blink_midpoint.get("scale", Vector2.ONE)).is_equal_approx(Vector2(0.05, 0.05)), "Blink Minimum Scale should occur at the spatial midpoint between Start and End.")
	_expect(Vector2(blink_fast_exit.get("position", Vector2.ZERO)).x > 7.5, "Blink should leave the midpoint rapidly with an Ease Out during its final 10%.")
	_expect(Vector2(blink_end.get("position", Vector2.ZERO)).is_equal_approx(Vector2(9.0, 0.0)) and Vector2(blink_end.get("scale", Vector2.ZERO)).is_equal_approx(Vector2.ONE), "Blink should finish at the configured endpoint and full scale.")
	_expect(MotionActPreview.apply_sample_transform(Vector2(3.0, 2.0), Vector2(1.0, 2.0), {"position": Vector2(4.0, 0.0), "scale": Vector2(0.5, 0.5)}).is_equal_approx(Vector2(6.0, 2.0)), "Act Preview should apply Blink scale uniformly around the Asset center before translation.")
	var invalid_blink := blink.duplicate(true)
	invalid_blink["parameters"]["minimum_scale"] = 0.0
	_expect(not MotionActEvaluator.validation_issues(invalid_blink).is_empty(), "Blink should reject a zero Minimum Scale.")
	var application_script = load("res://scripts/main.gd")
	var application: Control = application_script.new()
	var normalized: Dictionary = application._normalize_motion_act({"id": "act_7", "parameters": {"direction": [0.0, 2.0], "distance": 12.0}}, "fallback")
	_expect(Vector2(normalized.get("parameters", {}).get("direction", Vector2.ZERO)) == Vector2(0.0, 2.0), "Persisted Slide direction arrays should normalize back to Vector2 values.")
	var serialized: Dictionary = application._serialize_motion_act(normalized)
	_expect(serialized.get("parameters", {}).get("direction", null) is Array and int(serialized.get("schema_version", 0)) == 21, "Act persistence should serialize vectors as JSON arrays using schema 21.")
	var normalized_jump: Dictionary = application._normalize_motion_act({"id": "act_8", "primitive": "jump", "parameters": {"direction": [1.0, 0.0], "distance": 7.0, "height": 2.5, "arc": "snappy"}}, "fallback")
	var serialized_jump: Dictionary = application._serialize_motion_act(normalized_jump)
	_expect(str(serialized_jump.get("primitive", "")) == MotionActEvaluator.JUMP and is_equal_approx(float(serialized_jump.get("parameters", {}).get("height", 0.0)), 2.5) and str(serialized_jump.get("parameters", {}).get("arc", "")) == MotionActEvaluator.JUMP_ARC_SNAPPY, "Jump-specific parameters should survive normalization and serialization.")
	var normalized_blink: Dictionary = application._normalize_motion_act({"id": "act_9", "primitive": "blink", "parameters": {"direction": [1.0, 0.0], "distance": 11.0, "anticipation_distance": 1.5, "anticipation_share": 0.22, "minimum_scale": 0.08}}, "fallback")
	var serialized_blink: Dictionary = application._serialize_motion_act(normalized_blink)
	_expect(str(serialized_blink.get("primitive", "")) == MotionActEvaluator.BLINK and is_equal_approx(float(serialized_blink.get("parameters", {}).get("anticipation_distance", 0.0)), 1.5) and is_equal_approx(float(serialized_blink.get("parameters", {}).get("minimum_scale", 0.0)), 0.08), "Blink-specific anticipation and scale parameters should survive normalization and serialization.")
	var migrated_blink: Dictionary = application._normalize_motion_act({"schema_version": 18, "id": "act_10", "primitive": "blink", "parameters": {"direction": [1.0, 0.0], "distance": 6.0, "anticipation_distance": 1.0, "anticipation_share": 0.18, "minimum_scale": 0.05}}, "fallback")
	_expect(is_equal_approx(float(migrated_blink.get("parameters", {}).get("anticipation_share", 0.0)), 0.5), "The Phase 15 default Blink timing should migrate from 18% to the accepted 50% anticipation split.")
	application.free()
	var workspace := MotionActWorkspace.new()
	workspace.set_context([act], "act_1", {})
	workspace.acts[0]["name"] = "Mutated"
	_expect(str(act.get("name", "")) == "Slide Right", "MotionActWorkspace must render immutable Act copies and never mutate Workspace documents.")
	workspace.free()


func _test_motion_module_separators() -> void:
	var section := ModuleSection.new()
	section.setup("Motion", ["Animation", "Path", "Act", "Sequence"], false, false, 3)
	var separator_count := 0
	var separator_height := 0
	for child in section.content_list.get_children():
		if child is ColorRect:
			separator_count += 1
			separator_height = int(child.custom_minimum_size.y)
	_expect(separator_count == 1 and separator_height == 6 and section.content_list.get_child_count() == 5, "Motion should use one thick non-interactive separator between its Core and Extended workspace groups.")
	section.free()
	var create_section := ModuleSection.new()
	create_section.setup("Create", ["Asset", "Texture"], false)
	var create_separator_count := 0
	for child in create_section.content_list.get_children():
		if child is ColorRect:
			create_separator_count += 1
	_expect(create_separator_count == 0 and create_section.content_list.get_child_count() == 2, "Create should contain only its two Core authoring modules.")
	create_section.free()
	var geometry_section := ModuleSection.new()
	geometry_section.setup("Geometry", ["Sampling", "Seeding", "Meshing", "UV Mapping"], false)
	_expect(geometry_section.content_list.get_child_count() == 4, "Geometry should expose Sampling, Seeding, Meshing, and UV Mapping module entries.")
	geometry_section.free()


func _test_motion_sequence_evaluator() -> void:
	var topology := MotionPathTopology.default_topology()
	MotionPathTopology.add_point(topology, Vector2.ZERO)
	MotionPathTopology.add_point(topology, Vector2(0.0, 4.0))
	var path_document := {"id": "path_1", "name": "Wizard Path", "topology": topology, "playback": {"duration": 2.0, "loop": true, "orient_along_path": true}}
	var asset := {"id": "asset_1", "name": "Asset Wizard", "components": [{"id": "component_1", "visibility": true}], "animation": MotionWorkspace.create_default_animation_document()}
	var entry := {"id": "entry_1", "name": "Wizard Walk", "enabled": true, "asset_id": "asset_1", "animation_state_id": "state_walk", "path_id": "path_1"}
	_expect(MotionSequenceEvaluator.validation_issues(entry, asset, path_document).is_empty(), "A Sequence Entry with matching stable Asset, State, and Path references should validate.")
	var snapshot := MotionSequenceEvaluator.evaluate(entry, asset, path_document, 0.125)
	_expect(bool(snapshot.get("valid", false)) and is_equal_approx(Vector2(snapshot.get("path_position", Vector2.ZERO)).y, 0.5), "Sequence evaluation should derive spatial position from normalized Path phase.")
	_expect(is_equal_approx(float(snapshot.get("path_rotation", 0.0)), 90.0), "Sequence evaluation should inherit tangent orientation from the referenced Path.")
	_expect(is_equal_approx(float(snapshot.get("animation_phase", 0.0)), 0.25), "Sequence evaluation should derive Animation phase independently from State cycle duration.")
	_expect(is_equal_approx(Vector2(snapshot.get("component_samples", {}).get("component_1", {}).get("position", Vector2.ZERO)).y, 0.5), "Sequence evaluation should preserve the State's asset-local Bob sample before Path composition.")
	var missing_state_entry := entry.duplicate(true)
	missing_state_entry["animation_state_id"] = "missing_state"
	_expect(not MotionSequenceEvaluator.validation_issues(missing_state_entry, asset, path_document).is_empty(), "Sequence validation should report a missing State instead of silently substituting another reference.")
	var sequence_document := {"id": "sequence_1", "name": "Wizard Sequence", "entries": [entry]}
	var workspace := MotionSequenceWorkspace.new()
	workspace.set_context(sequence_document, "entry_1", asset, path_document)
	workspace.sequence_document["entries"][0]["asset_id"] = "mutated"
	_expect(str(sequence_document["entries"][0]["asset_id"]) == "asset_1", "MotionSequenceWorkspace must render immutable copies and never mutate Sequence references.")
	workspace.free()
