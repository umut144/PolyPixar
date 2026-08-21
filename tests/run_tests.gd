extends SceneTree

var failures := 0


func _init() -> void:
	_test_add_close_and_validate()
	_test_delete_exactly_one_point()
	_test_delete_multiple_points_and_protect_closed_minimum()
	_test_ids_are_not_reused()
	_test_insert_preserves_curve()
	_test_component_draw_modes_and_continuation()
	_test_closed_loop_selection_mirror()
	_test_ribbon_strip_mesh()
	_test_catch_parent_snapping()
	_test_geometry_sampling_service()
	_test_geometry_auto_build_service()
	_test_create_outliner_expansion_scope()
	_test_geometry_sampling_ui_shell()
	_test_geometry_seeding_service()
	_test_geometry_meshing_service_and_ui()
	_test_geometry_uv_mapping_service_and_ui()
	_test_geometry_sdf_service_and_batch()
	_test_semantic_registry_and_picker()
	_test_asset_catalog_service()
	_test_runtime_export_service()
	_test_weighting_service_and_ui()
	_test_component_hierarchy_model()
	_test_asset_guides()
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
		print("All PolyTools tests passed.")
		quit(0)
	else:
		push_error("%d PolyTools test(s) failed." % failures)
		quit(1)


func _component() -> Dictionary:
	return {"points": [], "edges": [], "chains": []}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _runtime_export_world_transform(components_by_id: Dictionary, component_id: String) -> Transform2D:
	var component: Dictionary = components_by_id.get(component_id, {})
	var transform: Dictionary = component.get("local_transform", {})
	var position_data: Array = transform.get("position", [])
	var pivot_data: Array = component.get("local_pivot", [])
	var scale_data: Array = transform.get("scale", [])
	var position := Vector2(float(position_data[0]), float(position_data[1]))
	var pivot := Vector2(float(pivot_data[0]), float(pivot_data[1]))
	var scale := Vector2(float(scale_data[0]), float(scale_data[1]))
	var local := Transform2D(float(transform.get("rotation_radians", 0.0)), scale, 0.0, Vector2.ZERO)
	local.origin = position - local.basis_xform(pivot)
	var parent_id = component.get("parent_component_id", null)
	return local if parent_id == null else _runtime_export_world_transform(components_by_id, str(parent_id)) * local


func _context_menu(application: Control, prefix: String) -> MenuButton:
	for child in application.context_bar.get_children():
		if child is MenuButton and str(child.text).begins_with(prefix):
			return child
	return null


func _control_text(root: Node) -> String:
	var values: Array[String] = []
	if root is Label or root is Button or root is CheckBox:
		values.append(str(root.get("text")))
	for child in root.get_children():
		values.append(_control_text(child))
	return "\n".join(values)


func _test_add_close_and_validate() -> void:
	var component := _component()
	var first_id := BezierTopology.add_point(component, Vector2.ZERO, "corner")
	BezierTopology.add_point(component, Vector2(1.0, 0.0), "aligned")
	var last_id := BezierTopology.add_point(component, Vector2(1.0, 1.0), "free")
	_expect(BezierTopology.close_active_chain(component), "A three-point chain should close.")
	_expect(BezierTopology.validate(component).is_empty(), "A newly closed chain should be valid.")
	_expect(bool(BezierTopology.point_by_id(component["points"], first_id).get("preserve_point", false)), "The first closing endpoint should be preserved.")
	_expect(bool(BezierTopology.point_by_id(component["points"], last_id).get("preserve_point", false)), "The last closing endpoint should be preserved.")
	var duplicate_point_chain := component.duplicate(true)
	duplicate_point_chain["chains"][0]["point_ids"][1] = duplicate_point_chain["chains"][0]["point_ids"][0]
	_expect(not BezierTopology.validate(duplicate_point_chain).is_empty(), "A Chain with a duplicate Point ID must be invalid.")


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
	var empty_open_component := _component()
	var empty_first_id := BezierTopology.add_point(empty_open_component, Vector2.ZERO, "linear")
	var empty_second_id := BezierTopology.add_point(empty_open_component, Vector2.ONE, "linear")
	BezierTopology.delete_point(empty_open_component, empty_first_id)
	BezierTopology.delete_point(empty_open_component, empty_second_id)
	_expect(empty_open_component.get("chains", []).is_empty(), "Deleting every Point from an open Chain should remove the empty Chain.")
	var restarted_id := BezierTopology.add_point(empty_open_component, Vector2(2.0, 2.0), "linear")
	_expect(not restarted_id.is_empty() and empty_open_component.get("chains", []).size() == 1, "An open Bézier chain should be drawable again after all of its Points were deleted.")


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
	var reset_component := _component()
	var reset_ids: Array[String] = []
	for point_index in range(3):
		reset_ids.append(BezierTopology.add_point(reset_component, Vector2(point_index, 0.0), "linear"))
	BezierTopology.close_active_chain(reset_component)
	var reset_deleted := BezierTopology.delete_points(reset_component, reset_ids)
	_expect(reset_deleted.size() == 3 and reset_component.get("points", []).is_empty() and reset_component.get("chains", []).is_empty(), "Deleting all points of a Closed Loop should remove the contour completely.")
	var reset_new_id := BezierTopology.add_point(reset_component, Vector2(4.0, 0.0), "linear")
	_expect(not reset_new_id.is_empty() and reset_component.get("chains", []).size() == 1, "A Closed Loop should be drawable again after its full contour was deleted.")
	var mirrored_reset := _component()
	var mirrored_ids: Array[String] = []
	for point_index in range(4):
		mirrored_ids.append(BezierTopology.add_point(mirrored_reset, Vector2(point_index, 0.0), "linear"))
	BezierTopology.close_active_chain(mirrored_reset)
	BezierTopology.add_point(mirrored_reset, Vector2(10.0, 0.0), "linear")
	BezierTopology.add_point(mirrored_reset, Vector2(11.0, 0.0), "linear")
	var mirrored_reset_deleted := BezierTopology.delete_points(mirrored_reset, mirrored_ids)
	_expect(mirrored_reset_deleted.size() == 6 and mirrored_reset.get("points", []).is_empty() and mirrored_reset.get("chains", []).is_empty(), "Resetting a mirrored Closed Loop should also remove stale mirror chains.")
	var ribbon_reset := _component()
	ribbon_reset["draw_mode"] = "ribbon"
	var ribbon_ids: Array[String] = [BezierTopology.add_point(ribbon_reset, Vector2.ZERO, "linear"), BezierTopology.add_point(ribbon_reset, Vector2.ONE, "linear")]
	BezierTopology.delete_points(ribbon_reset, ribbon_ids)
	_expect(ribbon_reset.get("chains", []).is_empty() and not BezierTopology.add_point(ribbon_reset, Vector2(2.0, 0.0), "linear").is_empty(), "A Ribbon should be drawable again after its full open Chain was deleted.")


func _test_insert_preserves_curve() -> void:
	var component := _component()
	BezierTopology.add_point(component, Vector2.ZERO, "free", Vector2(0.5, 0.0))
	BezierTopology.add_point(component, Vector2(1.0, 1.0), "free", Vector2(0.5, 0.0))
	var original_edge_id := str(component["edges"][0]["id"])
	var inserted_id := BezierTopology.insert_point_on_edge(component, original_edge_id, 0.5)
	_expect(not inserted_id.is_empty(), "Splitting an edge should create a point.")
	_expect(component["points"].size() == 3 and component["edges"].size() == 2, "Splitting should replace one edge with two connected edges.")
	_expect(BezierTopology.validate(component).is_empty(), "A split open chain should remain valid.")


func _test_component_draw_modes_and_continuation() -> void:
	var ribbon := _component()
	ribbon["draw_mode"] = "ribbon"
	var first_id := BezierTopology.start_chain(ribbon, Vector2.ZERO, "linear")
	var second_id := BezierTopology.add_point_from(ribbon, first_id, Vector2(2.0, 0.0), "linear")
	var prepended_id := BezierTopology.add_point_from(ribbon, first_id, Vector2(-1.0, 0.0), "linear")
	_expect(not second_id.is_empty() and not prepended_id.is_empty(), "Ribbon drawing should continue from either selected endpoint.")
	_expect(ribbon.get("chains", []).size() == 1 and BezierTopology.mode_validation_issues(ribbon, true).is_empty(), "Ribbon must validate as exactly one open Chain with at least two Points.")
	_expect(BezierTopology.start_chain(ribbon, Vector2(20.0, 20.0), "linear").is_empty(), "A Ribbon must reject a second Chain.")
	var closed := ribbon.duplicate(true)
	closed["draw_mode"] = "closed_loop"
	_expect(not BezierTopology.mode_validation_issues(closed, true).is_empty(), "Closed Loop must reject open topology.")
	_expect(BezierTopology.mode_validation_issues(ribbon, true).is_empty(), "Ribbon must accept one complete open Chain.")


func _test_closed_loop_selection_mirror() -> void:
	var component := _component()
	component["draw_mode"] = "closed_loop"
	var source_ids: Array[String] = []
	for point_position in [Vector2(0.0, 0.0), Vector2(-1.0, 1.0), Vector2(0.0, 4.0)]:
		source_ids.append(BezierTopology.add_point(component, point_position, "linear"))
	var mirror_axis_start := Vector2.ZERO
	var mirror_axis_end := Vector2(0.0, 4.0)
	var result := SelectionMirrorService.apply(component, source_ids, mirror_axis_start, mirror_axis_end)
	_expect(bool(result.get("valid", false)), "Mirror should preserve structural topology for an open Closed Loop draft.")
	var mirrored_component: Dictionary = result.get("component", {})
	var mirrored_ids: Array = result.get("mirrored_point_ids", [])
	_expect(mirrored_component.get("chains", []).size() == 1 and bool(mirrored_component["chains"][0].get("closed", false)), "Mirroring a half-contour with two coincident axis endpoints should produce one closed Chain.")
	_expect(mirrored_ids.size() == 1, "Only the mirrored interior point should remain selected after automatic loop closure.")
	_expect(BezierTopology.mode_validation_issues(mirrored_component, true).is_empty(), "A mirrored half-contour should validate immediately as a Closed Loop.")
	_expect(not SelectionMirrorService.validation_issues(mirrored_component, source_ids, mirror_axis_start, mirror_axis_end).is_empty(), "Mirror must reject an already closed Chain.")
	var coincident_component := _component()
	coincident_component["draw_mode"] = "closed_loop"
	var coincident_source_ids: Array[String] = []
	for point_position in [Vector2(0.0, 0.0), Vector2(-1.0, 1.0), Vector2(-1.0, 3.0)]:
		coincident_source_ids.append(BezierTopology.add_point(coincident_component, point_position, "linear"))
	var coincident_result := SelectionMirrorService.apply(coincident_component, coincident_source_ids, mirror_axis_start, mirror_axis_end)
	var coincident_mirror: Dictionary = coincident_result.get("component", {})
	_expect(int(coincident_result.get("auto_connected_count", 0)) == 1, "Mirror should merge an endpoint that lands exactly on its source endpoint.")
	_expect(coincident_mirror.get("points", []).size() == 5, "A coincident mirrored endpoint must be removed instead of leaving two overlapping Points.")
	_expect(coincident_mirror.get("chains", []).size() == 1 and not bool(coincident_mirror["chains"][0].get("closed", false)), "A single coincident endpoint pair should join the two mirror Chains but leave the remaining endpoints open.")
	var multi_coincident_component := _component()
	multi_coincident_component["draw_mode"] = "closed_loop"
	var multi_source_ids: Array[String] = []
	for point_position in [Vector2(0.0, 0.0), Vector2(-1.0, 1.0), Vector2(-1.0, 3.0), Vector2(0.0, 4.0)]:
		multi_source_ids.append(BezierTopology.add_point(multi_coincident_component, point_position, "linear"))
	var multi_result := SelectionMirrorService.apply(multi_coincident_component, multi_source_ids, mirror_axis_start, mirror_axis_end)
	var multi_mirror: Dictionary = multi_result.get("component", {})
	_expect(int(multi_result.get("auto_connected_count", 0)) == 2 and multi_mirror.get("points", []).size() == 6, "Mirror should fuse both coincident axis endpoints and remove their duplicate Points.")
	_expect(multi_mirror.get("chains", []).size() == 1 and bool(multi_mirror["chains"][0].get("closed", false)) and BezierTopology.mode_validation_issues(multi_mirror, true).is_empty(), "Multiple coincident axis endpoints should produce one valid closed Mirror Chain.")


func _test_ribbon_strip_mesh() -> void:
	var ribbon := _component()
	ribbon["draw_mode"] = "ribbon"
	ribbon["ribbon_width_px"] = 8.0
	_expect(is_equal_approx(RibbonMeshService.width_cm(ribbon), 0.625), "At 128 px/m and 10 Tool-cm/m, an 8 px Ribbon must be 0.625 Tool-cm wide.")
	BezierTopology.add_point(ribbon, Vector2.ZERO, "linear")
	BezierTopology.add_point(ribbon, Vector2(4.0, 0.0), "linear")
	BezierTopology.add_point(ribbon, Vector2(8.0, 3.0), "linear")
	var first := RibbonMeshService.generate(ribbon)
	var second := RibbonMeshService.generate(ribbon)
	_expect(bool(first.get("valid", false)), "A complete Ribbon Component should generate a Ribbon Strip Mesh.")
	_expect(int(first.get("vertex_count", 0)) >= 6 and int(first.get("triangle_count", 0)) >= 4, "Ribbon Strip should create paired vertices and triangle quads.")
	_expect(str(first.get("method", "")) == RibbonMeshService.METHOD and JSON.stringify(first) == JSON.stringify(second), "Ribbon Strip output must be deterministic.")
	_expect(RibbonMeshService.matches_source(first, ribbon), "Ribbon Strip Mesh should match its source Component.")
	ribbon["ribbon_width_px"] = 12.0
	_expect(not RibbonMeshService.matches_source(first, ribbon), "Changing Ribbon width must make the previous Mesh stale.")


func _test_catch_parent_snapping() -> void:
	var canvas := ComponentCanvas.new()
	canvas.size = Vector2(400.0, 400.0)
	canvas.set_camera_state(Vector2.ZERO, 20.0)
	canvas.set_component_transform({"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO})
	canvas.set_reference_shapes([{
		"id": "parent", "transform": {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO},
		"bezier_points": [
			{"id": "a", "position": Vector2.ZERO, "handle_in": Vector2.ZERO, "handle_out": Vector2.ZERO},
			{"id": "b", "position": Vector2(10.0, 0.0), "handle_in": Vector2.ZERO, "handle_out": Vector2.ZERO}
		],
		"edges": [{"id": "edge", "start_point_id": "a", "end_point_id": "b"}]
	}])
	canvas.set_catch_parent_component("parent")
	_expect(canvas._snap_to_catch_parent(Vector2(5.0, 0.2)).distance_to(Vector2(5.0, 0.0)) < 0.01, "Catch Parent should snap drawing to a referenced Bézier segment.")
	canvas.free()


func _test_create_outliner_expansion_scope() -> void:
	var application_script = load("res://scripts/main.gd")
	var application = application_script.new()
	application._build_ui()
	application.active_module = "Create"
	application.active_create_submodule = "Character"
	var test_assets: Array[Dictionary] = [
		{"id": "character_a", "name": "Character A", "asset_type": "character", "visibility": true, "components": [], "guides": []},
		{"id": "character_b", "name": "Character B", "asset_type": "character", "visibility": true, "components": [], "guides": []},
		{"id": "symbol_a", "name": "Symbol A", "asset_type": "symbols", "visibility": true, "components": [], "guides": []}
	]
	application.assets = test_assets
	application._set_outliner_asset_expanded("character_a", true)
	application._set_outliner_asset_expanded("character_b", true)
	_expect(not bool(application.expanded_assets.get("character_a", false)) and bool(application.expanded_assets.get("character_b", false)), "Expanding a Character should collapse only the other Character Assets.")
	application.active_create_submodule = "Symbols"
	application._set_outliner_asset_expanded("symbol_a", true)
	_expect(bool(application.expanded_assets.get("character_b", false)) and bool(application.expanded_assets.get("symbol_a", false)), "Expanding a Symbol should preserve the Character module's expanded Asset.")
	_expect(application._outliner_focus_asset_id() == "symbol_a" and application._outliner_asset_is_visible(application.assets[2]), "The Symbols Outliner should retain its own visible expanded Asset.")
	application.active_create_submodule = "Character"
	_expect(application._outliner_focus_asset_id() == "character_b" and application._outliner_asset_is_visible(application.assets[1]), "Returning to Characters should restore that module's expanded Asset.")
	application.selected_asset_id = "character_b"
	application.selected_component_id = "component_stale"
	application.selected_guide_id = "guide_stale"
	application.active_create_submodule = "Character"
	application._set_create_submodule_context("Symbols")
	_expect(application.selected_asset_id == "symbol_a" and application.selected_component_id.is_empty() and application.selected_guide_id.is_empty(), "Switching Create modules should select the target module's expanded Asset at asset level.")
	application.canvas_view.set_camera_state(Vector2(12.0, -3.0), 13.0)
	var camera_before: Dictionary = application.canvas_view.get_camera_state()
	application._set_create_submodule_context("Character")
	application._render_canvas_context()
	_expect(application.canvas_view.get_camera_state() == camera_before, "Restoring a Create module's active Asset must not reset canvas pan or zoom.")
	application.selected_asset_id = "character_b"
	application._render_canvas_context()
	application.canvas_view.set_camera_state(Vector2(42.0, -17.0), 7.0)
	application.selected_asset_id = "symbol_a"
	application._render_canvas_context()
	application.canvas_view.set_camera_state(Vector2(-8.0, 31.0), 3.0)
	application.selected_asset_id = "character_b"
	application._render_canvas_context()
	_expect(application.canvas_view.get_camera_state() == {"position": Vector2(42.0, -17.0), "zoom": 7.0}, "Each Create Asset should restore its own saved canvas pan and zoom.")
	var saved_editor_state: Dictionary = application._serialize_editor_state()
	_expect(saved_editor_state.get("asset_cameras", {}).has("character_b") and saved_editor_state.get("asset_cameras", {}).has("symbol_a"), "Per-Asset canvas cameras should be stored in persistent editor state.")
	application._restore_editor_state(saved_editor_state)
	application._render_canvas_context()
	_expect(application.canvas_view.get_camera_state() == {"position": Vector2(42.0, -17.0), "zoom": 7.0}, "Reloading editor state should restore the selected Asset's saved canvas camera.")
	application.free()


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
	var adaptive := GeometrySamplingService.generate(component, {"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 2.5}})
	_expect(int(adaptive.get("algorithm_version", 0)) == GeometrySamplingService.ALGORITHM_VERSION, "Sampling results should identify the junction-aware algorithm version.")
	_expect(bool(adaptive.get("valid", false)), "Adaptive Sampling should sample a valid closed Component.")
	var hole_component := _component()
	hole_component["id"] = "hole_component"
	hole_component["sampling_input_id"] = "ref_orb"
	for hole_position in [Vector2(2.0, 2.0), Vector2(2.0, 4.0), Vector2(4.0, 4.0), Vector2(4.0, 2.0)]:
		BezierTopology.add_point(hole_component, hole_position, "linear")
	BezierTopology.close_active_chain(hole_component)
	hole_component["chains"][0]["topology_role"] = "hole"
	var sampled_hole_result := GeometrySamplingService.generate(component, {"parameters": {"spacing": 2.5}}, [], [hole_component])
	_expect(bool(sampled_hole_result.get("valid", false)) and sampled_hole_result.get("chains", []).size() == 2, "Sampling should include a referenced Hole as a second sampled Chain.")
	_expect(str(sampled_hole_result["chains"][1].get("topology_role", "")) == "hole" and int(sampled_hole_result.get("hole_count", 0)) == 1, "Referenced Hole sampling must preserve its topology role and count.")
	_expect(str(sampled_hole_result.get("source_fingerprint", "")) != str(adaptive.get("source_fingerprint", "")), "Sampling fingerprints must include Hole inputs.")
	var arranged_cut := AssetGuide.create("cut_arranged", "Arranged Seam", AssetGuide.CUT, "component_1")
	BezierTopology.add_point(arranged_cut, Vector2(3.0, -1.0), "linear")
	BezierTopology.add_point(arranged_cut, Vector2(3.0, 11.0), "linear")
	var arranged_body := _component()
	for arranged_position in [Vector2.ZERO, Vector2(10.0, 0.0), Vector2(10.0, 10.0), Vector2(0.0, 10.0)]:
		BezierTopology.add_point(arranged_body, arranged_position, "linear")
	BezierTopology.close_active_chain(arranged_body)
	var arranged_result := GeometrySamplingService.generate(arranged_body, {"parameters": {"spacing": 2.5}}, [arranged_cut], [hole_component])
	var arranged_fragments: Array = arranged_result.get("cuts", [])[0].get("fragments", [])
	var cut_has_hole_interior_sample := false
	for fragment in arranged_fragments:
		for sample in fragment.get("samples", []):
			var position := Vector2(sample.get("position", Vector2.ZERO))
			cut_has_hole_interior_sample = cut_has_hole_interior_sample or (position.y > 2.0 and position.y < 4.0)
	var boundary_junction_count := 0
	for chain_data in arranged_result.get("chains", []):
		for sample in chain_data.get("samples", []):
			var position := Vector2(sample.get("position", Vector2.ZERO))
			if is_equal_approx(position.x, 3.0) and (is_equal_approx(position.y, 0.0) or is_equal_approx(position.y, 2.0) or is_equal_approx(position.y, 4.0) or is_equal_approx(position.y, 10.0)):
				boundary_junction_count += 1
	_expect(bool(arranged_result.get("valid", false)) and arranged_fragments.size() == 2 and not cut_has_hole_interior_sample and boundary_junction_count == 4, "Sampling should split Cut/Boundary intersections into shared PSLG junctions and remove the Cut span inside a Hole.")
	var refined_hole_result := GeometrySamplingService.generate(component, {"parameters": {"spacing": 2.5, "boundary_refinements": {"ref_orb": {"factor": 5.0}}}}, [], [hole_component])
	_expect(bool(refined_hole_result.get("valid", false)) and int(refined_hole_result["chains"][1].get("samples", []).size()) > int(sampled_hole_result["chains"][1].get("samples", []).size()) and int(refined_hole_result["chains"][0].get("samples", []).size()) == int(sampled_hole_result["chains"][0].get("samples", []).size()), "A Hole refinement should increase only that Hole's sample density.")
	var primitive_hole := {"id": "primitive_hole", "sampling_input_id": "ref_circle", "draw_mode": "primitive", "topology_role": "hole", "primitive": {"type": "circle", "center": Vector2.ZERO, "diameter_cm": 20.0}, "sampling_transform": Transform2D(Vector2(2.0, 0.0), Vector2(0.0, 0.5), Vector2(3.0, 4.0))}
	var unit_circle_hole := primitive_hole.duplicate(true)
	unit_circle_hole["sampling_transform"] = Transform2D.IDENTITY
	var scaled_circle_hole := primitive_hole.duplicate(true)
	scaled_circle_hole["sampling_transform"] = Transform2D(Vector2(2.0, 0.0), Vector2(0.0, 2.0), Vector2.ZERO)
	var unit_circle_result := GeometrySamplingService.generate(component, {"parameters": {"spacing": 2.0, "feature_detail": 0.5}}, [], [unit_circle_hole])
	var scaled_circle_result := GeometrySamplingService.generate(component, {"parameters": {"spacing": 2.0, "feature_detail": 0.5}}, [], [scaled_circle_hole])
	_expect(int(scaled_circle_result["chains"][1].get("samples", []).size()) > int(unit_circle_result["chains"][1].get("samples", []).size()), "Absolute chord-error sampling should increase a Circle Hole's density when its Body-local scale doubles.")
	var dense_circle_result := GeometrySamplingService.generate(component, {"parameters": {"spacing": 2.0, "feature_detail": 1.0}}, [], [primitive_hole])
	var coarse_circle_result := GeometrySamplingService.generate(component, {"parameters": {"spacing": 2.0, "feature_detail": 1.0, "boundary_refinements": {"ref_circle": {"factor": 0.25}}}}, [], [primitive_hole])
	_expect(int(coarse_circle_result["chains"][1].get("samples", []).size()) < int(dense_circle_result["chains"][1].get("samples", []).size()) and int(coarse_circle_result["chains"][0].get("samples", []).size()) == int(dense_circle_result["chains"][0].get("samples", []).size()), "A Boundary Density below 1x should coarsen all adaptive criteria only for the selected Hole.")
	var transformed_circle_result := GeometrySamplingService.generate(component, {"parameters": {"spacing": 0.5, "feature_detail": 0.5}}, [], [primitive_hole])
	var transformed_samples: Array = transformed_circle_result.get("chains", [])[1].get("samples", [])
	var transformed_bounds := Rect2(Vector2(transformed_samples[0].get("position", Vector2.ZERO)), Vector2.ZERO)
	for sample in transformed_samples:
		transformed_bounds = transformed_bounds.expand(Vector2(sample.get("position", Vector2.ZERO)))
	_expect(bool(transformed_circle_result.get("valid", false)) and transformed_bounds.size.x > transformed_bounds.size.y * 3.5, "Referenced Circle Primitives should remain analytic through non-uniform Body-local transforms.")
	var migrated_recipe := GeometrySamplingService.normalize_recipe({"method": GeometrySamplingService.EVEN_SPACING, "parameters": {"spacing": 2.5, "boundary_overrides": {"ref_orb": {"spacing": 0.5}}}})
	_expect(str(migrated_recipe.get("method", "")) == GeometrySamplingService.ADAPTIVE and is_equal_approx(float(migrated_recipe.get("parameters", {}).get("boundary_refinements", {}).get("ref_orb", {}).get("factor", 0.0)), 5.0), "Schema-28 Even Spacing and absolute overrides should migrate to Adaptive refinement factors.")
	var neutral_adjustment := GeometrySamplingService.normalize_recipe({"parameters": {"boundary_refinements": {"ref_orb": {"factor": 1.0}}}})
	_expect(neutral_adjustment.get("parameters", {}).get("boundary_refinements", {}).has("ref_orb"), "An active 1x Boundary Density adjustment should remain stable until the user disables it.")
	_expect(int(adaptive.get("sample_count", 0)) > component["points"].size(), "Adaptive Sampling should add derived Points without replacing authored Points.")
	var adaptive_samples: Array = adaptive.get("chains", [])[0].get("samples", [])
	_expect(str(adaptive_samples.front().get("source_point_id", "")) == first_id, "The first authored Point should remain the first ordered sample.")
	var source_ids: Array[String] = []
	for sample in adaptive_samples:
		var source_id := str(sample.get("source_point_id", ""))
		if not source_id.is_empty():
			source_ids.append(source_id)
	_expect(first_id in source_ids and curve_id in source_ids and last_id in source_ids, "Every authored edge endpoint should survive boundary sampling.")
	_expect(bool(adaptive_samples.front().get("preserved", false)), "A preserve_point source must carry the preserved guarantee into the sample result.")
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
	_expect(application._has_supported_schema({"schema_version": 39}) and application._has_supported_schema({"schema_version": 38}) and not application._has_supported_schema({"schema_version": 40}), "Schema 39 should keep current and older World documents readable and reject unknown future schemas.")
	var arranged_round_trip: Dictionary = application._normalize_sampling_bake(application._serialize_sampling_bake(arranged_result))
	_expect(arranged_round_trip.get("cuts", [])[0].get("fragments", []).size() == 2 and arranged_round_trip.get("cuts", [])[0].get("fragments", [])[0].get("samples", [])[0].get("position", null) is Vector2, "Schema 32 should preserve Cut fragment connectivity and restore fragment positions as Vector2 values.")
	var geometry_document: Dictionary = application._default_geometry_document("asset_1", "component_1")
	geometry_document["sampling"]["recipe"] = {"method": GeometrySamplingService.EVEN_SPACING, "parameters": {"spacing": 2.5, "feature_detail": GeometrySamplingService.DEFAULT_FEATURE_DETAIL}}
	var baked_result := adaptive.duplicate(true)
	baked_result["bake_id"] = "bake_test"
	geometry_document["sampling"]["bakes"][GeometrySamplingService.ADAPTIVE] = baked_result
	var serialized_geometry: Dictionary = application._serialize_geometry_document(geometry_document)
	_expect(int(serialized_geometry.get("schema_version", 0)) == 39 and serialized_geometry.get("sampling", {}).get("bakes", {}).get(GeometrySamplingService.ADAPTIVE, {}).get("chains", [])[0].get("samples", [])[0].get("position", null) is Array, "Sampling bakes should serialize derived positions as schema-39 JSON arrays.")
	var normalized_geometry: Dictionary = application._normalize_geometry_document(serialized_geometry, "asset_1", "component_1")
	_expect(normalized_geometry.get("sampling", {}).get("bakes", {}).get(GeometrySamplingService.ADAPTIVE, {}).get("chains", [])[0].get("samples", [])[0].get("position", null) is Vector2, "Sampling bake loading should restore local sample positions as Vector2 values.")
	_expect(normalized_geometry["sampling"]["bakes"].size() == 1, "Sampling should retain one Adaptive Bake.")
	var test_assets: Array[Dictionary] = [{"id": "asset_1", "components": [component]}]
	application.assets = test_assets
	application.geometry_documents["asset_1/component_1"] = normalized_geometry
	_expect(application._geometry_sampling_status("asset_1", "component_1", component) == "Baked", "A bake matching its recipe and source fingerprint should report Baked.")
	BezierTopology.point_by_id(component["points"], curve_id)["position"] += Vector2.ONE
	_expect(application._geometry_sampling_status("asset_1", "component_1", component) == "Ready to Preview", "Changing canonical topology should request a new Preview without rewriting its persisted result.")
	application.free()


func _test_geometry_auto_build_service() -> void:
	var component := _component()
	component.merge({"id": "auto_body", "name": "Body", "draw_mode": "closed_loop", "transform": {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}})
	for position in [Vector2.ZERO, Vector2(10.0, 0.0), Vector2(10.0, 10.0), Vector2(0.0, 10.0)]:
		BezierTopology.add_point(component, position, "linear")
	BezierTopology.close_active_chain(component)
	var recipes := GeometryAutoBuildService.automatic_recipes(component)
	_expect(is_equal_approx(float(recipes.get("sampling", {}).get("parameters", {}).get("spacing", 0.0)), 0.55) and is_equal_approx(float(recipes.get("seeding", {}).get("parameters", {}).get("spacing", 0.0)), 0.55), "Automatic Mesh recipes should start from the accepted shared 0.55 density for normal Character contours.")
	_expect(is_equal_approx(float(recipes.get("meshing", {}).get("parameters", {}).get("mesh_character", 0.0)), 0.64) and int(recipes.get("meshing", {}).get("parameters", {}).get("passes", 0)) == 3, "Automatic Mesh recipes should retain the accepted optimized Artistic profile.")
	var large_component := component.duplicate(true)
	for point in large_component.get("points", []):
		point["position"] = Vector2(point.get("position", Vector2.ZERO)) * Vector2(2.0, 5.0)
	var large_recipes := GeometryAutoBuildService.automatic_recipes(large_component)
	_expect(is_equal_approx(float(large_recipes.get("sampling", {}).get("parameters", {}).get("spacing", 0.0)), 1.0) and is_equal_approx(float(large_recipes.get("seeding", {}).get("parameters", {}).get("spacing", 0.0)), 1.0), "Automatic Mesh recipes should bound interior density for a 20x50 Component instead of generating thousands of avoidable Seeds.")
	var baked_signature := GeometryAutoBuildService.source_signature(component, [], [], recipes)
	var jittered := component.duplicate(true)
	jittered["points"][0]["position"] += Vector2(0.0003, 0.0)
	_expect(GeometryAutoBuildService.signatures_match(GeometryAutoBuildService.source_signature(jittered, [], [], recipes), baked_signature), "Sub-tolerance point jitter should not request the long Mesh pipeline again.")
	var moved := component.duplicate(true)
	moved["points"][0]["position"] += Vector2(0.01, 0.0)
	_expect(not GeometryAutoBuildService.signatures_match(GeometryAutoBuildService.source_signature(moved, [], [], recipes), baked_signature), "A meaningful point movement should request a Mesh update.")
	var topology_changed := component.duplicate(true)
	BezierTopology.insert_point_on_edge(topology_changed, str(topology_changed["edges"][0]["id"]), 0.5)
	_expect(not GeometryAutoBuildService.signatures_match(GeometryAutoBuildService.source_signature(topology_changed, [], [], recipes), baked_signature), "Topology changes must always request a Mesh update.")
	var changed_recipes := recipes.duplicate(true)
	changed_recipes["sampling"]["parameters"]["feature_detail"] = 0.8
	_expect(not GeometryAutoBuildService.signatures_match(GeometryAutoBuildService.source_signature(component, [], [], changed_recipes), baked_signature), "Pipeline recipe changes must always request a Mesh update.")
	var application_script = load("res://scripts/main.gd")
	var application: Control = application_script.new()
	var other_component: Dictionary = component.duplicate(true)
	other_component["id"] = "auto_symbol_body"
	other_component["name"] = "Symbol Body"
	var test_assets: Array[Dictionary] = [
		{"id": "auto_asset", "name": "Auto Asset", "asset_type": "character", "visibility": true, "components": [component], "guides": []},
		{"id": "auto_symbol", "name": "Auto Symbol", "asset_type": "symbols", "visibility": true, "components": [other_component], "guides": []}
	]
	application.assets = test_assets
	application.selected_asset_id = "auto_asset"
	_expect(application._mesh_update_candidates("auto_asset") == ["auto_body"], "A valid unmeshed Component should appear exactly once in Update Meshes.")
	_expect(application._all_mesh_update_candidates() == [{"asset_id": "auto_asset", "component_id": "auto_body"}, {"asset_id": "auto_symbol", "component_id": "auto_symbol_body"}], "Update Meshes should collect stable candidates globally across every Create Asset type, independent of the selected Asset.")
	var build: Dictionary = application._generate_component_mesh_build("auto_asset", "auto_body")
	_expect(bool(build.get("valid", false)) and int(build.get("meshing", {}).get("triangle_count", 0)) > 0, "The automatic batch runner should complete Sampling, Seeding, CDT, Optimization, and final validation.")
	application._commit_component_mesh_build("auto_asset", "auto_body", build)
	_expect(application._mesh_update_candidates("auto_asset").is_empty(), "A successfully committed automatic Mesh should become clean without a mutable dirty flag.")
	_expect(application._all_mesh_update_candidates() == [{"asset_id": "auto_symbol", "component_id": "auto_symbol_body"}], "A committed Mesh should leave only dirty Components from other Assets in the global batch.")
	var round_trip: Dictionary = application._normalize_geometry_document(application._serialize_geometry_document(application.geometry_documents["auto_asset/auto_body"]), "auto_asset", "auto_body")
	_expect(not round_trip.get("component_mesh", {}).get("build_provenance", {}).get("source_signature", {}).is_empty(), "Semantic Mesh build provenance should survive Geometry JSON persistence.")
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
	_expect(application.world_menu.text == "World  ▼" and application.world_name_dialog.title == "New World" and application.load_world_dialog.title == "Load World", "The persisted top-level document should be presented consistently as a World in the toolbar and dialogs.")
	var visible_categories: Array[String] = []
	var every_category_expanded := true
	for module_section in application.module_sections:
		visible_categories.append(module_section.module_name)
		every_category_expanded = every_category_expanded and module_section.expanded
	_expect(visible_categories == ["Create", "Mesh", "Style", "Export"], "The module rail should provide the dedicated Export workspace while omitting deferred categories.")
	_expect(every_category_expanded, "Every visible category should remain expanded.")
	var test_assets: Array[Dictionary] = [{"id": "asset_1", "name": "Wizard", "visibility": true, "components": [component]}]
	application.assets = test_assets
	application.active_module = "Mesh"
	application.active_geometry_submodule = "Sampling"
	application.selected_asset_id = "asset_1"
	application.selected_component_id = "component_1"
	application.expanded_assets["asset_1"] = true
	application._render_outliner()
	application._render_inspector()
	application._render_canvas_context()
	_expect(application.batch_status_snapshot_build_count == 0, "Editing workspaces must not calculate Batch status for detached toolbar controls.")
	application._on_category_pressed("Export")
	_expect(application.export_workspace.visible and application.export_summary_label.text.contains("Preflight abgeschlossen") and application.export_log.get_parsed_text().contains("Wizard / Body"), "Export should run one preflight on entry and list affected Asset / Component data in its read-only log.")
	_expect(application.export_run_button.visible and application.export_run_button.text == "Build All (1)" and application.export_valid_button.visible and application.context_bar_panel.visible == false and application.draw_mode_status.visible == false, "Export should replace Create context controls with Build and valid-only Export actions in the top toolbar.")
	var batch_snapshot_builds: int = application.batch_status_snapshot_build_count
	application._record_direct_change()
	_expect(application.batch_status_snapshot_build_count == batch_snapshot_builds, "A document mutation must only mark Batch status dirty until Export is opened again.")
	application.active_module = "Mesh"
	application._render_canvas_context()
	_expect(application.geometry_sampling_workspace.visible, "Geometry Sampling should own a dedicated visible centre workspace.")
	_expect(application.outliner_list.get_child_count() > 1, "Sampling Outliner should expose the Asset/Component hierarchy.")
	_expect(application.inspector_content.get_child_count() >= 8, "A selected Component should expose Adaptive parameters, boundary inputs, result, and Bake controls.")
	_expect(application.geometry_sampling_workspace.component.get("points", []).size() == 4, "Sampling Workspace should receive an immutable Component view copy.")
	application.geometry_sampling_workspace.component["points"][0]["position"] = Vector2(999.0, 999.0)
	_expect(Vector2(component["points"][0]["position"]) == Vector2.ZERO, "Sampling Workspace presentation copies must not mutate canonical topology.")
	_expect(GeometrySamplingService.VALID_METHODS == [GeometrySamplingService.ADAPTIVE] and str(application._geometry_sampling_recipe("asset_1", "component_1").get("method", "")) == GeometrySamplingService.ADAPTIVE, "Sampling should expose one Adaptive method.")
	var spacing_input := SpinBox.new()
	spacing_input.min_value = GeometrySamplingService.MIN_SPACING
	spacing_input.max_value = 10000.0
	application._commit_geometry_spacing_text("1,25", spacing_input)
	_expect(is_equal_approx(float(application._geometry_sampling_recipe("asset_1", "component_1").get("parameters", {}).get("spacing", 0.0)), 1.25), "Sampling Spacing should accept comma-decimal direct input.")
	application._commit_geometry_spacing_text("2.50", spacing_input)
	_expect(is_equal_approx(float(application._geometry_sampling_recipe("asset_1", "component_1").get("parameters", {}).get("spacing", 0.0)), 2.5), "Sampling Spacing should accept dot-decimal direct input.")
	application._set_geometry_sampling_refinement("hole_test", 0.5)
	_expect(is_equal_approx(float(application._geometry_sampling_recipe("asset_1", "component_1").get("parameters", {}).get("boundary_refinements", {}).get("hole_test", {}).get("factor", 0.0)), 0.5), "Boundary Density should support coarsening below 1x.")
	application._set_geometry_sampling_refinement("hole_test", 1.0)
	_expect(application._geometry_sampling_recipe("asset_1", "component_1").get("parameters", {}).get("boundary_refinements", {}).has("hole_test"), "Stepping through 1x should not collapse an active Boundary Density control.")
	application._on_geometry_sampling_refinement_toggled(false, "hole_test")
	_expect(not application._geometry_sampling_recipe("asset_1", "component_1").get("parameters", {}).get("boundary_refinements", {}).has("hole_test"), "Disabling Boundary Density should explicitly restore inheritance.")
	application.geometry_sampling_preview["accepted_preview_marker"] = true
	application._bake_geometry_sampling()
	_expect(bool(application._geometry_sampling_bake("asset_1", "component_1").get("accepted_preview_marker", false)), "Bake Preview should copy the current matching Preview without regenerating it.")
	spacing_input.free()
	application.geometry_documents["asset_1/component_1"] = application._default_geometry_document("asset_1", "component_1")
	var history_snapshot: Dictionary = application._capture_history_snapshot()
	application.geometry_documents["asset_1/component_1"]["sampling"]["recipe"]["parameters"]["spacing"] = 42.0
	application._restore_history_snapshot(history_snapshot)
	_expect(is_equal_approx(float(application.geometry_documents["asset_1/component_1"]["sampling"]["recipe"]["parameters"]["spacing"]), GeometrySamplingService.DEFAULT_SPACING), "Geometry recipes and bakes should participate in World Undo/Redo snapshots.")
	var create_section: ModuleSection = application._find_section("Create")
	application._select_submodule("Create", "Props", create_section)
	_expect(application.active_module == "Create" and application.active_create_submodule == "Props" and application.canvas_view.visible and not application.geometry_sampling_workspace.visible, "Selecting Create Props should immediately render the shared asset workspace.")
	_expect(application._find_section("Mesh").active_submodule.is_empty() and application._find_section("Style").active_submodule.is_empty(), "Only the selected module should remain highlighted across always-expanded categories.")
	application.asset_name_input.text = "Shield"
	application._confirm_asset_creation()
	_expect(str(application.assets[-1].get("asset_type", "")) == "props", "Create Props should persist the stable props Asset type.")
	_expect(application._normalize_asset_type("") == "character" and application._asset_type_create_submodule("icon") == "Icon", "Missing Asset types should normalize to Character while valid types map back to their Create module.")
	application._on_outliner_asset_type_filter_toggled(false, "character")
	_expect(not application.outliner_asset_type_filters["character"] and application.outliner_asset_type_filters["props"], "Mesh and Style filters should support independent Asset type checkboxes.")
	application.active_module = "Style"
	application._render_outliner()
	application._set_all_outliner_asset_type_filters()
	_expect(application.outliner_asset_type_filters["character"] and application.outliner_asset_type_filter_panel.visible, "Style should show the shared Asset filter and restore all types with All.")
	application._select_submodule("Create", "Character", create_section)
	_expect(application.active_create_submodule == "Character" and application.canvas_view.visible, "Selecting Create Character should immediately render the shared asset workspace.")
	application.selected_asset_id = "asset_1"
	application.selected_component_id = "component_1"
	application._render_context_bar()
	application._activate_edit_edge_state()
	application._refresh_component_geometry(component)
	var edge_ids: Array[String] = []
	for edge_data in component.get("edges", []):
		edge_ids.append(str(edge_data.get("id", "")))
	_expect(edge_ids.size() >= 2, "Edit Edge test component should expose at least two edges.")
	application.canvas_view._select_edge_by_click(edge_ids[0], false)
	application.canvas_view._select_edge_by_click(edge_ids[1], true)
	_expect(application.selected_edge_ids.size() == 2, "Shift-click should preserve a multi-edge selection.")
	application._on_edge_render_outline_changed(false)
	var selected_component_after_outline: Dictionary = application._get_component(application._get_asset("asset_1"), "component_1")
	_expect(not bool(selected_component_after_outline.get("edges", [])[0].get("render_outline", true)) and not bool(selected_component_after_outline.get("edges", [])[1].get("render_outline", true)), "Render Outline should apply to every selected edge.")
	application.canvas_view._select_edge_by_click(edge_ids[0], true)
	_expect(application.selected_edge_ids.size() == 1 and application.selected_edge_ids[0] == edge_ids[1], "Shift-clicking a selected edge should remove it from the selection.")
	var edge_command := _context_menu(application, "⌘3")
	_expect(application.active_context_command == "asset.edit_edge" and application.active_edit_mode == "edge" and edge_command != null and edge_command.button_pressed and not edge_command.flat, "Asset Edit Edge should update its central command and highlight on the first CMD+3 state change.")
	application._activate_edit_face_state()
	var face_command := _context_menu(application, "⌘4")
	_expect(application.active_context_command == "asset.edit_face" and application.active_edit_mode == "face" and face_command != null and face_command.button_pressed and not face_command.flat, "Asset Edit Face should update its central command and highlight on the first CMD+4 state change.")
	application._activate_edit_point_state()
	var point_command := _context_menu(application, "⌘2")
	_expect(application.active_context_command == "asset.edit_point" and application.active_edit_mode == "point" and point_command != null and point_command.button_pressed and not point_command.flat, "Returning to Asset Edit Point should update its central command and highlight immediately.")
	var nudge_component: Dictionary = application._get_component(application._get_asset("asset_1"), "component_1")
	var nudge_ids: Array = [str(nudge_component.get("points", [])[0].get("id", "")), str(nudge_component.get("points", [])[1].get("id", ""))]
	var nudge_before: Array[Vector2] = [Vector2(nudge_component.get("points", [])[0].get("position", Vector2.ZERO)), Vector2(nudge_component.get("points", [])[1].get("position", Vector2.ZERO))]
	application.canvas_view.set_selected_point_ids(nudge_ids)
	application._nudge_selected_point(Vector2.RIGHT)
	var nudge_after: Array[Vector2] = [Vector2(nudge_component.get("points", [])[0].get("position", Vector2.ZERO)), Vector2(nudge_component.get("points", [])[1].get("position", Vector2.ZERO))]
	var nudge_step: float = application.snap_grid_step if application.snap_enabled else application.world_grid_size
	_expect(nudge_after[0].x == nudge_before[0].x + nudge_step and nudge_after[1].x == nudge_before[1].x + nudge_step, "Arrow nudging should move every selected point by one snap step.")
	application.free()


func _test_geometry_seeding_service() -> void:
	var component := _component()
	component.merge({"id": "component_1", "name": "Body", "visibility": true})
	BezierTopology.add_point(component, Vector2.ZERO, "corner")
	BezierTopology.add_point(component, Vector2(10.0, 0.0), "linear")
	BezierTopology.add_point(component, Vector2(10.0, 10.0), "linear")
	BezierTopology.add_point(component, Vector2(0.0, 10.0), "linear")
	BezierTopology.close_active_chain(component)
	var cut := AssetGuide.create("cut_seed", "Seam", AssetGuide.CUT, "component_1")
	BezierTopology.add_point(cut, Vector2(7.0, 0.0), "linear")
	BezierTopology.add_point(cut, Vector2(7.0, 10.0), "linear")
	var sampling := GeometrySamplingService.generate(component, {"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 1.0}}, [cut])
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
	var hole_component := _component()
	hole_component["id"] = "hole"
	hole_component["sampling_input_id"] = "hole_ref"
	for position in [Vector2(3.0, 3.0), Vector2(3.0, 5.0), Vector2(5.0, 5.0), Vector2(5.0, 3.0)]:
		BezierTopology.add_point(hole_component, position, "linear")
	BezierTopology.close_active_chain(hole_component)
	hole_component["chains"][0]["topology_role"] = "hole"
	var constrained_sampling := GeometrySamplingService.generate(component, {"parameters": {"spacing": 1.0}}, [cut], [hole_component])
	constrained_sampling["bake_id"] = "sampling_constraints"
	var constrained_fill := GeometrySeedingService.generate(constrained_sampling, {"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 1.0, "constraint_clearance_factor": 0.5, "seed": 23}})
	var has_left_of_cut := false
	var has_right_of_cut := false
	for seed_data in constrained_fill.get("seeds", []):
		var position := Vector2(seed_data.get("position", Vector2.ZERO))
		_expect(not Rect2(Vector2(3.0, 3.0), Vector2(2.0, 2.0)).has_point(position), "Poisson Fill must exclude Hole interiors.")
		_expect(absf(position.x - 7.0) >= 0.499, "Poisson Fill must preserve automatic clearance on both sides of a Cut.")
		has_left_of_cut = has_left_of_cut or position.x < 6.5
		has_right_of_cut = has_right_of_cut or position.x > 7.5
	_expect(has_left_of_cut and has_right_of_cut, "A Cut should remain an internal barrier rather than excluding either side from Seeding.")
	var original_constraint_fingerprint := GeometrySeedingService.sampling_fingerprint(constrained_sampling)
	constrained_sampling["cuts"][0]["samples"][0]["position"] += Vector2(0.1, 0.0)
	_expect(GeometrySeedingService.sampling_fingerprint(constrained_sampling) != original_constraint_fingerprint, "Seeding fingerprints must include sampled Cut geometry.")
	var sampler_spine := AssetGuide.create("guide_sampler", "Main Flow", AssetGuide.SAMPLER_SPINE, "component_1")
	BezierTopology.add_point(sampler_spine, Vector2(1.0, 5.0), "aligned")
	BezierTopology.add_point(sampler_spine, Vector2(5.0, 5.0), "aligned")
	BezierTopology.add_point(sampler_spine, Vector2(9.0, 5.0), "aligned")
	var flow_recipe := {"method": GeometrySeedingService.SPINE_FLOW, "parameters": {"guide_id": "guide_sampler", "along_spacing": 2.0, "across_spacing": 2.0, "boundary_clearance": 0.5, "stagger": 0.5, "fill_gaps": false, "seed": 7}}
	var legacy_flow_recipe := GeometrySeedingService.normalize_recipe(flow_recipe)
	_expect(is_equal_approx(float(legacy_flow_recipe.get("parameters", {}).get("spacing", 0.0)), 2.0) and is_equal_approx(float(legacy_flow_recipe.get("parameters", {}).get("flow_stretch", 0.0)), 1.0) and bool(legacy_flow_recipe.get("parameters", {}).get("boundary_clearance_override", false)) and bool(legacy_flow_recipe.get("parameters", {}).get("stagger_override", false)), "Legacy Spine Flow recipes should retain their exact technical values as Artistic overrides.")
	var artistic_flow_recipe := GeometrySeedingService.normalize_recipe({"method": GeometrySeedingService.SPINE_FLOW, "parameters": {"spacing": 0.1, "flow_stretch": 4.0}})
	_expect(is_equal_approx(float(artistic_flow_recipe.get("parameters", {}).get("across_spacing", 0.0)), 0.1) and is_equal_approx(float(artistic_flow_recipe.get("parameters", {}).get("along_spacing", 0.0)), 0.4), "Artistic Spine Flow controls should derive Across from Seed Spacing and Along from Seed Spacing times Flow Stretch.")
	_expect(is_equal_approx(float(artistic_flow_recipe.get("parameters", {}).get("boundary_clearance", 0.0)), 0.05) and is_equal_approx(float(artistic_flow_recipe.get("parameters", {}).get("stagger", 0.0)), 0.1) and not bool(artistic_flow_recipe.get("parameters", {}).get("boundary_clearance_override", true)) and not bool(artistic_flow_recipe.get("parameters", {}).get("stagger_override", true)), "New Artistic Spine Flow recipes should derive Boundary Margin and Stagger automatically.")
	var flow := GeometrySeedingService.generate(sampling, flow_recipe, sampler_spine)
	var repeated_flow := GeometrySeedingService.generate(sampling, flow_recipe, sampler_spine)
	_expect(bool(flow.get("valid", false)) and int(flow.get("seed_count", 0)) > 0 and flow == repeated_flow, "Spine Flow should deterministically generate Seeds from a valid Sampler Spine.")
	var has_left_side := false
	var has_right_side := false
	for seed_data in flow.get("seeds", []):
		var position := Vector2(seed_data.get("position", Vector2.ZERO))
		has_left_side = has_left_side or position.y < 4.9
		has_right_side = has_right_side or position.y > 5.1
		_expect(GeometrySeedingService.point_is_inside(sampling, position), "Every Spine Flow Seed must remain inside the sampled Component boundary.")
	_expect(has_left_side and has_right_side, "Spine Flow should seed bidirectionally between the Sampler Spine and Component contour.")
	_expect(str(flow.get("guide_id", "")) == "guide_sampler" and not str(flow.get("guide_fingerprint", "")).is_empty(), "Spine Flow results must retain their exact Sampler Spine dependency.")
	_expect(str(GeometrySeedingService.normalize_recipe(flow_recipe).get("parameters", {}).get("spine_inputs", [])[0].get("guide_id", "")) == "guide_sampler", "Schema-29 single-Spine recipes should migrate to one enabled Spine input.")
	_expect(not bool(GeometrySeedingService.generate(sampling, flow_recipe).get("valid", true)), "Spine Flow should fail visibly when its Sampler Spine dependency is missing.")
	var crossing_spine := AssetGuide.create("guide_crossing", "Crossing Flow", AssetGuide.SAMPLER_SPINE, "component_1")
	BezierTopology.add_point(crossing_spine, Vector2(5.0, 1.0), "aligned")
	BezierTopology.add_point(crossing_spine, Vector2(5.0, 9.0), "aligned")
	var multi_flow_recipe := {"method": GeometrySeedingService.SPINE_FLOW, "parameters": {"spine_inputs": [{"guide_id": "guide_sampler", "enabled": true}, {"guide_id": "guide_crossing", "enabled": true}], "along_spacing": 2.0, "across_spacing": 2.0, "boundary_clearance": 0.5, "stagger": 0.5, "fill_gaps": false, "seed": 7}}
	var multi_flow := GeometrySeedingService.generate(sampling, multi_flow_recipe, [sampler_spine, crossing_spine])
	var multi_positions: Array[Vector2] = []
	var represented_guides: Dictionary = {}
	for seed_data in multi_flow.get("seeds", []):
		var position := Vector2(seed_data.get("position", Vector2.ZERO))
		for previous in multi_positions:
			_expect(position.distance_to(previous) >= 0.639, "Combined Spine Flow inputs must enforce one global minimum distance.")
		multi_positions.append(position)
		represented_guides[str(seed_data.get("provenance", {}).get("guide_id", ""))] = true
	_expect(bool(multi_flow.get("valid", false)) and represented_guides.has("guide_sampler") and represented_guides.has("guide_crossing") and multi_flow.get("guide_stats", []).size() == 2, "Multiple enabled Sampler Spines should contribute to one deterministic shared Seed set.")
	var application_script = load("res://scripts/main.gd")
	var application: Control = application_script.new()
	var geometry_document: Dictionary = application._default_geometry_document("asset_1", "component_1")
	geometry_document["sampling"]["recipe"] = {"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 1.0}}
	geometry_document["sampling"]["bakes"][GeometrySamplingService.ADAPTIVE] = sampling
	first["bake_id"] = "seeding_bake_test"
	first["edited"] = true
	first["seeds"][0]["origin"] = "manual_adjusted"
	geometry_document["seeding"]["recipe"] = {"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 2.0, "seed": 17}}
	geometry_document["seeding"]["bakes"][GeometrySeedingService.POISSON_FILL] = first
	var serialized: Dictionary = application._serialize_geometry_document(geometry_document)
	_expect(serialized.get("seeding", {}).get("bakes", {}).get(GeometrySeedingService.POISSON_FILL, {}).get("seeds", [])[0].get("position", null) is Array, "Seeding method Bake positions should serialize as schema JSON arrays.")
	var normalized: Dictionary = application._normalize_geometry_document(serialized, "asset_1", "component_1")
	_expect(normalized.get("seeding", {}).get("bakes", {}).get(GeometrySeedingService.POISSON_FILL, {}).get("seeds", [])[0].get("position", null) is Vector2 and bool(normalized.get("seeding", {}).get("bakes", {}).get(GeometrySeedingService.POISSON_FILL, {}).get("edited", false)), "Seeding method Bake loading should restore editable Seed vectors and edit state.")
	var test_assets: Array[Dictionary] = [{"id": "asset_1", "name": "Asset", "components": [component], "guides": [sampler_spine, crossing_spine, cut]}]
	application.assets = test_assets
	application.geometry_documents["asset_1/component_1"] = normalized
	_expect(application._geometry_seeding_status("asset_1", "component_1", component) == "Edited", "A matching manually adjusted Seeding Bake should report Edited.")
	normalized["seeding"]["recipe"]["parameters"]["seed"] = 18
	_expect(application._geometry_seeding_status("asset_1", "component_1", component) == "Ready to Preview", "Changing the Seeding recipe should preserve its Bake and request a new Preview.")
	normalized["seeding"]["recipe"]["parameters"]["seed"] = 17
	application._build_ui()
	application.active_module = "Mesh"
	application.active_geometry_submodule = "Seeding"
	application.selected_asset_id = "asset_1"
	application.selected_component_id = "component_1"
	application.expanded_assets["asset_1"] = true
	application._render_outliner()
	application._render_inspector()
	application._render_canvas_context()
	_expect(application.geometry_seeding_workspace.visible and application.inspector_content.get_child_count() >= 10, "Geometry Seeding should expose its dedicated Workspace and compact Poisson Inspector.")
	var seeding_outliner_text := _control_text(application.outliner_list)
	var seeding_inspector_text := _control_text(application.inspector_content)
	_expect(seeding_outliner_text.contains("Sampling · Adaptive") and seeding_outliner_text.contains("Cut · Body → Cut01") and seeding_outliner_text.contains("Spine · Body → Sample01"), "The Seeding Outliner should nest its Sampling dependency, Cut barriers, and Sampler Spine inputs below the Body.")
	_expect(seeding_inspector_text.contains("Holes · excluded + clearance") and seeding_inspector_text.contains("Cuts · barrier + clearance") and seeding_inspector_text.contains("Constraint Clearance: Auto"), "The Seeding Inspector should explain automatic Outer, Hole, and Cut constraint treatment.")
	application._activate_geometry_seeding_method_choice()
	_expect(application.geometry_seeding_method_choice_active and not application.geometry_seeding_method_menu.get_popup().visible, "Seeding CMD+1 should enter a keyboard Method choice state without opening the mouse dropdown.")
	var seeding_active_style := application.geometry_seeding_method_menu.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(seeding_active_style != null and seeding_active_style.bg_color == Color("#8fd8f5") and not application.geometry_seeding_method_menu.flat, "An active Seeding Method MenuButton should render the shared light-blue background in its normal state.")
	application._set_geometry_seeding_method(GeometrySeedingService.SPINE_FLOW)
	_expect(application.geometry_seeding_method_choice_active and not application.geometry_seeding_edit_active and str(application._geometry_seeding_recipe("asset_1", "component_1").get("method", "")) == GeometrySeedingService.SPINE_FLOW, "Seeding Method state should remain active and exclude Edit Seeds after its plain-number selection.")
	var artistic_inspector_text := _control_text(application.inspector_content)
	_expect(artistic_inspector_text.contains("Seed Spacing (Body units)") and artistic_inspector_text.contains("Flow Stretch") and artistic_inspector_text.contains("Boundary Margin:") and artistic_inspector_text.contains("Advanced Pattern") and not artistic_inspector_text.contains("Along Spacing: Derived"), "The primary Spine Flow Inspector should expose the compact Artistic controls and keep technical lattice values collapsed.")
	application._on_geometry_seeding_advanced_pattern_toggled(true)
	artistic_inspector_text = _control_text(application.inspector_content)
	_expect(artistic_inspector_text.contains("Along Spacing: Derived") and artistic_inspector_text.contains("Across Spacing: Derived") and artistic_inspector_text.contains("Stagger:"), "Advanced Pattern should disclose derived lattice values and optional Stagger refinement.")
	application._on_geometry_seeding_advanced_pattern_toggled(false)
	application._set_geometry_seeding_method(GeometrySeedingService.POISSON_FILL)
	normalized["seeding"]["bakes"][GeometrySeedingService.POISSON_FILL] = {}
	application.geometry_seeding_preview = GeometrySeedingService.generate(sampling, application._geometry_seeding_recipe("asset_1", "component_1"))
	application.geometry_seeding_preview["accepted_preview_marker"] = true
	application.geometry_seeding_preview_key = "asset_1/component_1"
	application.geometry_seeding_preview_state = "ready"
	application._bake_geometry_seeding()
	_expect(application._geometry_seeding_status("asset_1", "component_1", component) == "Baked" and bool(application._geometry_seeding_bake("asset_1", "component_1").get("accepted_preview_marker", false)), "Bake Preview should copy the exact current Seeding Preview without regenerating it.")
	application._toggle_geometry_seeding_edit()
	_expect(application.geometry_seeding_edit_active and application.geometry_seeding_workspace.editing_enabled and not normalized["seeding"]["bakes"][GeometrySeedingService.POISSON_FILL].is_empty(), "Entering Edit Seeds from a baked result should enable mouse editing immediately.")
	application._activate_geometry_seeding_method_choice()
	_expect(application.active_context_command == "geometry.seeding.method" and application.geometry_seeding_method_choice_active and not application.geometry_seeding_edit_active, "Entering Seeding Method must atomically select its central command and deactivate Edit Seeds.")
	application._toggle_geometry_seeding_edit()
	_expect(application.active_context_command == "geometry.seeding.edit_seeds" and application.geometry_seeding_edit_active and not application.geometry_seeding_method_choice_active, "Entering Edit Seeds must atomically select its central command and deactivate Seeding Method.")
	normalized["seeding"]["bakes"][GeometrySeedingService.POISSON_FILL]["seeds"] = []
	normalized["seeding"]["bakes"][GeometrySeedingService.POISSON_FILL]["seed_count"] = 0
	var seed_count_before := 0
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
	var edited_seeds: Array = normalized["seeding"]["bakes"][GeometrySeedingService.POISSON_FILL].get("seeds", [])
	_expect(edited_seeds.size() == seed_count_before + 1 and str(edited_seeds.back().get("origin", "")) == "manual", "Edit Seeds should route an Add click into one persistent manual Seed without changing canonical topology.")
	application._set_geometry_seeding_edit_tool("remove")
	var remove_event := InputEventMouseButton.new()
	remove_event.button_index = MOUSE_BUTTON_LEFT
	remove_event.pressed = true
	remove_event.position = application.geometry_seeding_workspace._to_screen(Vector2(1.0, 1.0))
	application.geometry_seeding_workspace._gui_input(remove_event)
	_expect(normalized["seeding"]["bakes"][GeometrySeedingService.POISSON_FILL].get("seeds", []).size() == seed_count_before, "Edit Seeds should route a Remove click to only the clicked persistent Seed.")
	var spacing_input := SpinBox.new()
	spacing_input.min_value = GeometrySeedingService.MIN_SPACING
	spacing_input.max_value = 10000.0
	application._commit_geometry_seeding_spacing_text("1,75", spacing_input)
	_expect(is_equal_approx(float(application._geometry_seeding_recipe("asset_1", "component_1").get("parameters", {}).get("spacing", 0.0)), 1.75), "Seeding Spacing should accept comma-decimal direct input and update its Recipe.")
	normalized["seeding"]["recipe"] = GeometrySeedingService.normalize_recipe(flow_recipe)
	flow["bake_id"] = "seeding_flow_bake"
	normalized["seeding"]["bakes"][GeometrySeedingService.SPINE_FLOW] = flow
	_expect(application._geometry_seeding_status("asset_1", "component_1", component) == "Baked", "A Spine Flow Bake should remain current while both Sampling and Sampler Spine fingerprints match.")
	_expect(normalized["seeding"]["bakes"].size() == 2, "Poisson Fill and Spine Flow Bakes should persist side by side on one Component.")
	application._set_geometry_seeding_method(GeometrySeedingService.POISSON_FILL)
	_expect(application.selected_geometry_bake_method == GeometrySeedingService.POISSON_FILL and not application._geometry_seeding_bake("asset_1", "component_1").is_empty(), "Selecting a Seeding Method should select its matching persistent Bake.")
	application._set_geometry_seeding_method(GeometrySeedingService.SPINE_FLOW)
	_expect(application.selected_geometry_bake_method == GeometrySeedingService.SPINE_FLOW and not application._geometry_seeding_bake("asset_1", "component_1").is_empty(), "Switching back to Spine Flow should select its existing Bake without replacing Poisson Fill.")
	sampler_spine["points"][1]["position"] = Vector2(5.0, 5.5)
	_expect(application._geometry_seeding_status("asset_1", "component_1", component) == "Ready to Preview", "Editing a referenced Sampler Spine should preserve its Bake and request a new Preview.")
	spacing_input.free()
	application.free()


func _test_geometry_meshing_service_and_ui() -> void:
	var default_meshing_recipe := GeometryMeshingService.default_recipe()
	_expect(is_equal_approx(float(default_meshing_recipe.get("parameters", {}).get("mesh_character", 0.0)), 0.64) and bool(default_meshing_recipe.get("parameters", {}).get("optimize_mesh", false)) and is_equal_approx(GeometryMeshingService.relaxation_for_character(0.64), 0.402) and GeometryMeshingService.passes_for_character(0.64) == 3, "New Meshing recipes should default to the accepted 64% Artistic profile with derived Strength 0.40 and three quality-checked passes.")
	var component := _component()
	component.merge({"id": "component_1", "name": "Body", "visibility": true})
	BezierTopology.add_point(component, Vector2.ZERO, "corner")
	BezierTopology.add_point(component, Vector2(10.0, 0.0), "linear")
	BezierTopology.add_point(component, Vector2(10.0, 10.0), "linear")
	BezierTopology.add_point(component, Vector2(0.0, 10.0), "linear")
	BezierTopology.close_active_chain(component)
	var sampling := GeometrySamplingService.generate(component, {"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 2.0}})
	sampling["bake_id"] = "sampling_mesh_test"
	var seeding := GeometrySeedingService.generate(sampling, {"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 2.5, "seed": 9}})
	seeding["bake_id"] = "seeding_mesh_test"
	var cdt_recipe := {"method": GeometryMeshingService.CONSTRAINED_MESH, "parameters": {"seeding_method": GeometrySeedingService.POISSON_FILL, "mesh_character": 0.0}}
	var cdt := GeometryMeshingService.generate(sampling, seeding, cdt_recipe)
	var repeated := GeometryMeshingService.generate(sampling, seeding, cdt_recipe)
	_expect(bool(cdt.get("valid", false)) and int(cdt.get("vertex_count", 0)) > int(seeding.get("seed_count", 0)) and int(cdt.get("triangle_count", 0)) > 0, "Structured Constrained Mesh should generate a derived Mesh from sampled boundaries and Seeds.")
	_expect(cdt == repeated, "Meshing must be deterministic for identical Sampling, Seeding, and recipe inputs.")
	var pslg_diagnostics := GeometryMeshingService._pslg_validation_issues(PackedVector2Array([Vector2.ZERO, Vector2(2.0, 0.0), Vector2(1.0, 0.0)]), [[0, 1]], [{"topology_role": "cut", "chain_id": "cut:test", "fragment_index": 0, "segment_index": 10}])
	_expect(not pslg_diagnostics.is_empty() and str(pslg_diagnostics[0]).contains("Cut fragment 1, segment 11") and str(pslg_diagnostics[0]).contains("shared sampled junction"), "PSLG diagnostics should identify the exact Cut fragment and local segment that passes through an unsplit vertex.")
	_expect(str(cdt.get("sampling_bake_id", "")) == "sampling_mesh_test" and str(cdt.get("seeding_bake_id", "")) == "seeding_mesh_test", "A Mesh result must retain both exact upstream Bake dependencies.")
	var holed_component := _component()
	for position in [Vector2.ZERO, Vector2(12.0, 0.0), Vector2(12.0, 12.0), Vector2(0.0, 12.0)]:
		BezierTopology.add_point(holed_component, position, "linear")
	BezierTopology.close_active_chain(holed_component)
	for position in [Vector2(4.0, 4.0), Vector2(4.0, 8.0), Vector2(8.0, 8.0), Vector2(8.0, 4.0)]:
		BezierTopology.add_point(holed_component, position, "linear")
	BezierTopology.close_active_chain(holed_component)
	holed_component["chains"][1]["topology_role"] = "hole"
	var holed_sampling := GeometrySamplingService.generate(holed_component, {"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 2.0}})
	holed_sampling["bake_id"] = "sampling_hole_test"
	var holed_seeding := GeometrySeedingService.generate(holed_sampling, {"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 2.5, "seed": 3}})
	holed_seeding["bake_id"] = "seeding_hole_test"
	var holed_mesh := GeometryMeshingService.generate(holed_sampling, holed_seeding, cdt_recipe)
	_expect(bool(holed_mesh.get("valid", false)) and int(holed_mesh.get("triangle_count", 0)) > 0, "Constrained Delaunay should recover sampled constraints around holes.")
	var holed_positions: Dictionary = {}
	for vertex in holed_mesh.get("vertices", []):
		holed_positions[str(vertex.get("id", ""))] = Vector2(vertex.get("position", Vector2.ZERO))
	for triangle in holed_mesh.get("triangles", []):
		var ids: Array = triangle.get("vertex_ids", [])
		var centroid: Vector2 = (holed_positions[str(ids[0])] + holed_positions[str(ids[1])] + holed_positions[str(ids[2])]) / 3.0
		_expect(not Rect2(4.0, 4.0, 4.0, 4.0).has_point(centroid), "Meshing must not emit Triangles inside a sampled hole.")
	var boundary_positions: Dictionary = {}
	for vertex in cdt.get("vertices", []):
		if str(vertex.get("origin", "")) == "boundary":
			boundary_positions[str(vertex.get("id", ""))] = Vector2(vertex.get("position", Vector2.ZERO))
	var organic_recipe := {"method": GeometryMeshingService.CONSTRAINED_MESH, "parameters": {"seeding_method": GeometrySeedingService.POISSON_FILL, "mesh_character": 0.55}}
	var unoptimized_recipe := {"method": GeometryMeshingService.CONSTRAINED_MESH, "parameters": {"seeding_method": GeometrySeedingService.POISSON_FILL, "mesh_character": 0.55, "optimize_mesh": false}}
	var unoptimized := GeometryMeshingService.generate(sampling, seeding, unoptimized_recipe)
	_expect(bool(unoptimized.get("valid", false)) and not bool(unoptimized.get("optimization", {}).get("enabled", true)) and int(unoptimized.get("optimization", {}).get("moved_seed_count", -1)) == 0, "Optimize Mesh off should expose the deterministic raw CDT result without moving Seeds.")
	_expect(unoptimized.get("vertices", []) == cdt.get("vertices", []) and unoptimized.get("triangles", []) == cdt.get("triangles", []), "Disabling optimization must restore the exact raw CDT vertices and triangles regardless of Mesh Character.")
	var organic := GeometryMeshingService.generate(sampling, seeding, organic_recipe)
	var organic_optimization: Dictionary = organic.get("optimization", {})
	var quality_before: Dictionary = organic_optimization.get("quality_before", {})
	var quality_after: Dictionary = organic_optimization.get("quality_after", {})
	_expect(bool(organic.get("valid", false)) and int(organic.get("triangle_count", 0)) > 0 and bool(organic_optimization.get("enabled", false)) and float(organic.get("parameters", {}).get("relaxation", 0.0)) > 0.0, "Organic Mesh Character should produce a valid quality-checked optimized constrained Mesh.")
	_expect(not quality_before.is_empty() and not quality_after.is_empty() and int(organic_optimization.get("moved_seed_count", 0)) > 0 and float(quality_after.get("minimum_angle", 0.0)) >= float(quality_before.get("minimum_angle", 0.0)) - 0.051 and int(organic.get("vertex_count", 0)) == int(unoptimized.get("vertex_count", -1)), "Existing-point optimization must move free Seeds, report before/after quality, reject material minimum-angle regressions, and keep the Vertex count unchanged.")
	for vertex in organic.get("vertices", []):
		if str(vertex.get("origin", "")) == "boundary":
			_expect(Vector2(vertex.get("position", Vector2.ZERO)).is_equal_approx(boundary_positions.get(str(vertex.get("id", "")), Vector2.INF)), "Organic relaxation must keep every sampled Boundary Vertex fixed.")
	var cut := AssetGuide.create("cut_mesh", "Seam", AssetGuide.CUT, "component_1")
	BezierTopology.add_point(cut, Vector2(5.0, 0.0), "linear")
	BezierTopology.add_point(cut, Vector2(5.0, 10.0), "linear")
	var cut_sampling := GeometrySamplingService.generate(component, {"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 1.0}}, [cut])
	cut_sampling["bake_id"] = "sampling_cut_mesh_test"
	var cut_seeding := GeometrySeedingService.generate(cut_sampling, {"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 1.5, "seed": 31}})
	cut_seeding["bake_id"] = "seeding_cut_mesh_test"
	var cut_organic := GeometryMeshingService.generate(cut_sampling, cut_seeding, organic_recipe)
	_expect(bool(cut_organic.get("valid", false)) and bool(cut_organic.get("constraints_valid", false)) and int(cut_organic.get("cut_seam_vertex_count", 0)) > 0 and int(cut_organic.get("degenerate_triangle_count", -1)) == 0, "Organic Character must relax and retriangulate before duplicating a valid, non-degenerate Cut seam.")
	_expect(str(cut_organic.get("triangulation_backend", "")).contains("CDT 1.4.5") and str(cut_organic.get("diagnostics", {}).get("stage", "")) == "complete", "Constrained Mesh should report the qualified native CDT backend and successful diagnostic stage.")
	_expect(not bool(GeometryMeshingService.generate({}, seeding, cdt_recipe).get("valid", true)), "Meshing should fail visibly without its referenced Sampling Bake.")
	var application_script = load("res://scripts/main.gd")
	var application: Control = application_script.new()
	var serialized_organic: Dictionary = application._serialize_meshing_bake(organic)
	var normalized_organic: Dictionary = application._normalize_meshing_bake(serialized_organic)
	_expect(serialized_organic.get("optimization", {}).get("movements", [])[0].get("from", null) is Array and normalized_organic.get("optimization", {}).get("movements", [])[0].get("from", null) is Vector2, "Meshing persistence should serialize and restore Optimization movement diagnostics for before/after views.")
	var document: Dictionary = application._default_geometry_document("asset_1", "component_1")
	document["sampling"]["recipe"] = {"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 2.0}}
	document["sampling"]["bakes"][GeometrySamplingService.ADAPTIVE] = sampling
	document["seeding"]["recipe"] = {"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 2.5, "seed": 9}}
	document["seeding"]["bakes"][GeometrySeedingService.POISSON_FILL] = seeding
	document["meshing"]["recipe"] = cdt_recipe
	cdt["bake_id"] = "mesh_cdt_test"
	document["meshing"]["bakes"][GeometryMeshingService.CONSTRAINED_MESH] = cdt
	var serialized: Dictionary = application._serialize_geometry_document(document)
	_expect(serialized.get("meshing", {}).get("bakes", {}).get(GeometryMeshingService.CONSTRAINED_MESH, {}).get("vertices", [])[0].get("position", null) is Array, "Mesh Bake positions should serialize as JSON arrays.")
	var normalized: Dictionary = application._normalize_geometry_document(serialized, "asset_1", "component_1")
	_expect(normalized.get("meshing", {}).get("bakes", {}).get(GeometryMeshingService.CONSTRAINED_MESH, {}).get("vertices", [])[0].get("position", null) is Vector2, "Mesh Bake loading should restore Component-local Vertex positions.")
	var legacy_cdt := cdt.duplicate(true)
	legacy_cdt["method"] = GeometryMeshingService.CONSTRAINED_DELAUNAY
	legacy_cdt["bake_id"] = "legacy_cdt"
	legacy_cdt.erase("algorithm_version")
	var legacy_organic := organic.duplicate(true)
	legacy_organic["method"] = GeometryMeshingService.ORGANIC_RELAXED
	legacy_organic["bake_id"] = "legacy_organic"
	legacy_organic["parameters"].erase("mesh_character")
	legacy_organic["parameters"].erase("relaxation_override")
	legacy_organic["parameters"].erase("passes_override")
	legacy_organic.erase("algorithm_version")
	var legacy_document := serialized.duplicate(true)
	legacy_document["schema_version"] = 30
	legacy_document["meshing"]["recipe"] = {"method": GeometryMeshingService.ORGANIC_RELAXED, "parameters": legacy_organic["parameters"].duplicate(true)}
	legacy_document["meshing"]["bakes"] = {GeometryMeshingService.CONSTRAINED_DELAUNAY: legacy_cdt, GeometryMeshingService.ORGANIC_RELAXED: legacy_organic}
	legacy_document["component_mesh"] = {"bake_id": "legacy_organic", "method": GeometryMeshingService.ORGANIC_RELAXED, "mesh_fingerprint": "legacy"}
	legacy_document["uv_mapping"]["bakes"] = {
		"legacy_cdt_uv": {"valid": true, "method": GeometryUVMappingService.BOUNDS_PLANAR, "mesh_method": GeometryMeshingService.CONSTRAINED_DELAUNAY, "mesh_bake_id": "legacy_cdt", "uvs": [{"vertex_id": "cdt", "uv": [0.0, 0.0]}]},
		"legacy_organic_uv": {"valid": true, "method": GeometryUVMappingService.BOUNDS_PLANAR, "mesh_method": GeometryMeshingService.ORGANIC_RELAXED, "mesh_bake_id": "legacy_organic", "uvs": [{"vertex_id": "organic", "uv": [1.0, 1.0]}]}
	}
	var migrated_legacy: Dictionary = application._normalize_geometry_document(legacy_document, "asset_1", "component_1")
	_expect(migrated_legacy["meshing"]["bakes"].size() == 1 and migrated_legacy["meshing"]["bakes"].has(GeometryMeshingService.CONSTRAINED_MESH) and str(migrated_legacy["meshing"]["bakes"][GeometryMeshingService.CONSTRAINED_MESH].get("bake_id", "")) == "legacy_organic", "Schema-30 dual Meshing bakes should deterministically migrate the accepted Component Mesh into one Constrained Mesh bake.")
	_expect(str(migrated_legacy["component_mesh"].get("method", "")) == GeometryMeshingService.CONSTRAINED_MESH and float(migrated_legacy["meshing"]["recipe"]["parameters"].get("mesh_character", 0.0)) > 0.0, "Legacy Organic Relaxed selection should migrate to Constrained Mesh with an Organic Character and keep its Component Mesh reference.")
	var migrated_uv: Dictionary = migrated_legacy["uv_mapping"]["bakes"].values()[0]
	_expect(migrated_legacy["uv_mapping"]["bakes"].size() == 1 and str(migrated_uv.get("mesh_bake_id", "")) == "legacy_organic", "Legacy UV variants should retain the UV Bake belonging to the deterministically accepted Mesh.")
	var test_assets: Array[Dictionary] = [{"id": "asset_1", "name": "Asset", "visibility": true, "components": [component], "guides": []}]
	application.assets = test_assets
	application.geometry_documents["asset_1/component_1"] = normalized
	application._build_ui()
	application.active_module = "Mesh"
	application.active_geometry_submodule = "Meshing"
	application.selected_asset_id = "asset_1"
	application.selected_component_id = "component_1"
	application.expanded_assets["asset_1"] = true
	application._render_outliner()
	application._render_inspector()
	application._render_canvas_context()
	_expect(application.geometry_meshing_workspace.visible and application.inspector_content.get_child_count() >= 10, "Geometry Meshing should expose its dedicated Workspace and compact Inspector.")
	var meshing_inspector_text := _control_text(application.inspector_content)
	var meshing_outliner_text := _control_text(application.outliner_list)
	_expect(meshing_inspector_text.contains("Constrained Mesh · Automatic") and meshing_inspector_text.contains("Mesh Character") and meshing_inspector_text.contains("Optimize Mesh") and meshing_inspector_text.contains("Advanced Optimization") and meshing_inspector_text.contains("Optimization") and meshing_inspector_text.contains("Quality") and not meshing_inspector_text.contains("Use as Component Mesh"), "Meshing should expose one Artistic Constrained Mesh workflow, explicit optimization control, and both diagnostic views without a separate Component Mesh action.")
	_expect(meshing_outliner_text.contains("Sampling · Adaptive") and meshing_outliner_text.contains("Seeding · Poisson Fill") and meshing_outliner_text.contains("Constraints · Outer Preserved") and meshing_outliner_text.contains("Mesh · Constrained Mesh"), "Meshing Outliner should expose its complete nested pipeline dependencies.")
	var current_sampling_bake: Dictionary = normalized["sampling"]["bakes"][GeometrySamplingService.ADAPTIVE]
	var current_sampling_version := int(current_sampling_bake.get("algorithm_version", 0))
	current_sampling_bake.erase("algorithm_version")
	_expect(not application._geometry_sampling_bake_is_current("asset_1", "component_1", component) and application._geometry_meshing_status("asset_1", "component_1", component) == "Sampling Required", "A pre-junction Sampling Bake must become stale upstream instead of surfacing as an invalid Meshing PSLG.")
	current_sampling_bake["algorithm_version"] = current_sampling_version
	normalized["meshing"]["bakes"].clear()
	application.geometry_meshing_preview = cdt.duplicate(true)
	application.geometry_meshing_preview["accepted_preview_marker"] = true
	application.geometry_meshing_preview_key = "asset_1/component_1"
	application.geometry_meshing_preview_state = "ready"
	application._bake_geometry_meshing_preview()
	var accepted_mesh: Dictionary = application._geometry_meshing_bake("asset_1", "component_1")
	_expect(bool(accepted_mesh.get("accepted_preview_marker", false)) and application._component_mesh_status("asset_1", "component_1", component) == "Ready" and str(application._component_mesh_bake("asset_1", "component_1").get("bake_id", "")) == str(accepted_mesh.get("bake_id", "")), "Bake Preview should copy the exact Preview and automatically make it the Component Mesh.")
	component["transform"] = application._default_component_transform()
	component["transform"]["position"] = Vector2(17.0, -6.0)
	application.selected_component_id = ""
	application._refresh_geometry_meshing_workspace()
	var asset_overview: Dictionary = application.geometry_meshing_workspace.mesh_result
	var local_mesh_position := Vector2(accepted_mesh.get("vertices", [])[0].get("position", Vector2.ZERO))
	var overview_position := Vector2(asset_overview.get("vertices", [])[0].get("position", Vector2.ZERO))
	_expect(bool(asset_overview.get("valid", false)) and int(asset_overview.get("mesh_component_count", 0)) == 1 and str(asset_overview.get("vertices", [])[0].get("id", "")).begins_with("component_1/") and overview_position.is_equal_approx(local_mesh_position + Vector2(17.0, -6.0)), "Selecting a Meshing root Asset should compose current Component Meshes in the same transformed Asset coordinate space as Create.")
	var component_mesh_round_trip: Dictionary = application._normalize_geometry_document(application._serialize_geometry_document(normalized), "asset_1", "component_1")
	_expect(str(component_mesh_round_trip.get("component_mesh", {}).get("bake_id", "")) == str(accepted_mesh.get("bake_id", "")), "Automatic Component Mesh selection should survive Geometry document persistence.")
	normalized["seeding"]["bakes"][GeometrySeedingService.POISSON_FILL]["seeds"][0]["position"] += Vector2(0.1, 0.0)
	_expect(application._geometry_meshing_status("asset_1", "component_1", component) == "Ready to Preview", "Editing an upstream Seeding Bake should request a new Mesh Preview without reverse synchronization.")
	_expect(application._component_mesh_status("asset_1", "component_1", component) == "Stale", "A selected Component Mesh should become stale without losing its persistent Bake reference when upstream inputs change.")
	var stale_overview: Dictionary = application._geometry_asset_mesh_overview("asset_1")
	_expect(int(stale_overview.get("mesh_component_count", -1)) == 0 and stale_overview.get("vertices", []).is_empty(), "Asset Meshing overview should omit stale or missing Component Meshes without invalidating the remaining Asset view.")
	component["points"][1]["position"] = component["points"][0]["position"]
	component["points"][0]["preserve_point"] = true
	component["points"][1]["preserve_point"] = true
	application.selected_component_id = "component_1"
	application._render_inspector()
	var invalid_inspector_text := _control_text(application.inspector_content)
	_expect(invalid_inspector_text.contains("Source Validation") and invalid_inspector_text.contains("Consecutive Preserve Points may not occupy the same position."), "Meshing Inspector should expose the concrete source-topology reason for an invalid Component that the global batch skips.")
	application.free()


func _test_geometry_uv_mapping_service_and_ui() -> void:
	var component := _component()
	component.merge({"id": "component_1", "name": "Body", "visibility": true})
	for position in [Vector2.ZERO, Vector2(12.0, 0.0), Vector2(12.0, 8.0), Vector2(0.0, 8.0)]:
		BezierTopology.add_point(component, position, "linear")
	BezierTopology.close_active_chain(component)
	var sampling := GeometrySamplingService.generate(component, {"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 2.0}})
	sampling["bake_id"] = "sampling_uv_test"
	var seeding := GeometrySeedingService.generate(sampling, {"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 2.5, "seed": 4}})
	seeding["bake_id"] = "seeding_uv_test"
	var mesh := GeometryMeshingService.generate(sampling, seeding, {"method": GeometryMeshingService.CONSTRAINED_MESH, "parameters": {"seeding_method": GeometrySeedingService.POISSON_FILL}})
	mesh["bake_id"] = "mesh_uv_test"
	var recipe := GeometryUVMappingService.default_recipe()
	var uv_result := GeometryUVMappingService.generate(mesh, recipe)
	var repeated := GeometryUVMappingService.generate(mesh, recipe)
	_expect(bool(uv_result.get("valid", false)) and int(uv_result.get("uv_count", 0)) == int(mesh.get("vertex_count", 0)), "Bounds / Planar should map every stable Mesh Vertex ID to one UV coordinate.")
	_expect(uv_result == repeated, "UV Mapping must be deterministic for an identical Mesh Bake and recipe.")
	for entry in uv_result.get("uvs", []):
		var uv := Vector2(entry.get("uv", Vector2.ZERO))
		_expect(uv.x >= GeometryUVMappingService.DEFAULT_PADDING - 0.0001 and uv.x <= 1.0 - GeometryUVMappingService.DEFAULT_PADDING + 0.0001 and uv.y >= GeometryUVMappingService.DEFAULT_PADDING - 0.0001 and uv.y <= 1.0 - GeometryUVMappingService.DEFAULT_PADDING + 0.0001, "Default Bounds / Planar UVs should preserve the calibrated contour-mask padding inside normalized UV space.")
	var transformed_recipe := {"method": GeometryUVMappingService.BOUNDS_PLANAR, "parameters": {"mesh_method": GeometryMeshingService.CONSTRAINED_MESH, "scale": 0.75, "rotation": 15.0, "offset_u": 0.1, "offset_v": -0.05, "preserve_aspect": false}}
	var transformed := GeometryUVMappingService.generate(mesh, transformed_recipe)
	_expect(bool(transformed.get("valid", false)) and transformed.get("uvs", []) != uv_result.get("uvs", []), "UV Scale, Rotation, Offset, and Preserve Aspect should affect only the derived UV result.")
	_expect(not bool(GeometryUVMappingService.generate({}, recipe).get("valid", true)), "UV Mapping should fail visibly without a valid Mesh Bake.")
	var application_script = load("res://scripts/main.gd")
	var application: Control = application_script.new()
	var document: Dictionary = application._default_geometry_document("asset_1", "component_1")
	document["sampling"]["recipe"] = {"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 2.0}}
	document["sampling"]["bakes"][GeometrySamplingService.ADAPTIVE] = sampling
	document["seeding"]["recipe"] = {"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 2.5, "seed": 4}}
	document["seeding"]["bakes"][GeometrySeedingService.POISSON_FILL] = seeding
	document["meshing"]["recipe"] = {"method": GeometryMeshingService.CONSTRAINED_MESH, "parameters": {"seeding_method": GeometrySeedingService.POISSON_FILL}}
	document["meshing"]["bakes"][GeometryMeshingService.CONSTRAINED_MESH] = mesh
	document["component_mesh"] = {"bake_id": "mesh_uv_test", "method": GeometryMeshingService.CONSTRAINED_MESH, "mesh_fingerprint": GeometryUVMappingService.mesh_fingerprint(mesh)}
	uv_result["bake_id"] = "uv_bounds_test"
	var uv_key := GeometryUVMappingService.bake_key(GeometryMeshingService.CONSTRAINED_MESH, GeometryUVMappingService.BOUNDS_PLANAR)
	document["uv_mapping"]["recipe"] = recipe
	document["uv_mapping"]["bakes"][uv_key] = uv_result
	var serialized: Dictionary = application._serialize_geometry_document(document)
	_expect(serialized.get("uv_mapping", {}).get("bakes", {}).get(uv_key, {}).get("uvs", [])[0].get("uv", null) is Array, "UV Bake coordinates should serialize as JSON arrays.")
	var normalized: Dictionary = application._normalize_geometry_document(serialized, "asset_1", "component_1")
	_expect(normalized.get("uv_mapping", {}).get("bakes", {}).get(uv_key, {}).get("uvs", [])[0].get("uv", null) is Vector2, "UV Bake loading should restore normalized coordinates as Vector2 values.")
	var test_assets: Array[Dictionary] = [{"id": "asset_1", "name": "Asset", "visibility": true, "components": [component], "guides": []}]
	application.assets = test_assets
	application.geometry_documents["asset_1/component_1"] = normalized
	application._build_ui()
	application.active_module = "Mesh"
	application.active_geometry_submodule = "UV Mapping"
	application.selected_asset_id = "asset_1"
	application.selected_component_id = "component_1"
	application.expanded_assets["asset_1"] = true
	application._render_outliner()
	application._render_inspector()
	application._render_canvas_context()
	_expect(application.geometry_uv_mapping_workspace.visible and application.inspector_content.get_child_count() >= 14, "UV Mapping should expose its dedicated split Workspace and compact Bounds / Planar Inspector.")
	_expect(application._all_uv_update_candidates().is_empty(), "A current accepted UV Bake should leave the global UV batch empty.")
	_expect(application._all_sdf_update_candidates().size() == 1, "A visible Component with current Mesh and UV Bakes should become an actionable SDF batch candidate.")
	application._activate_geometry_uv_mapping_method_choice()
	var active_style := application.geometry_uv_mapping_method_menu.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(application.active_context_command == "geometry.uv_mapping.method" and application.geometry_uv_mapping_method_choice_active and active_style != null and active_style.bg_color == Color("#8fd8f5"), "UV Mapping CMD+1 should use the shared exclusive Method state and highlight.")
	application._set_geometry_uv_mapping_method(GeometryUVMappingService.BOUNDS_PLANAR)
	_expect(application.selected_geometry_bake_method == uv_key and application._geometry_uv_mapping_status("asset_1", "component_1", component) == "Baked", "Selecting Bounds / Planar should select the matching Mesh-specific UV Bake.")
	application._on_geometry_uv_mapping_checker_overlay_changed(false)
	_expect(not application.geometry_uv_mapping_checker_overlay and not application.geometry_uv_mapping_workspace.checker_overlay_enabled, "UV Checker Overlay should be a live editor-only preview toggle without changing the UV Bake.")
	application._on_geometry_uv_mapping_checker_overlay_changed(true)
	_expect(application.geometry_uv_mapping_checker_overlay and application.geometry_uv_mapping_workspace.checker_overlay_enabled, "UV Checker Overlay should default back to the active mapped-Mesh debug preview.")
	application._set_geometry_uv_mapping_mesh_source(GeometryMeshingService.CONSTRAINED_MESH)
	var scale_input := SpinBox.new()
	scale_input.min_value = GeometryUVMappingService.MIN_SCALE
	scale_input.max_value = 100.0
	application._commit_geometry_uv_mapping_float_text("1,25", scale_input, "scale")
	_expect(is_equal_approx(float(application._geometry_uv_mapping_recipe("asset_1", "component_1").get("parameters", {}).get("scale", 0.0)), 1.25), "UV numeric fields should accept comma-decimal direct input and update the Recipe.")
	_expect(application._geometry_uv_mapping_status("asset_1", "component_1", component) == "Stale" and application._all_uv_update_candidates().size() == 1, "Changing a UV recipe should make its accepted Bake stale and actionable without changing the Component Mesh.")
	normalized["uv_mapping"]["recipe"] = GeometryUVMappingService.normalize_recipe(recipe)
	normalized["meshing"]["bakes"][GeometryMeshingService.CONSTRAINED_MESH]["vertices"][0]["position"] += Vector2(0.1, 0.0)
	_expect(application._geometry_uv_mapping_status("asset_1", "component_1", component) == "Mesh Required / Stale", "Changing the accepted Component Mesh should block UV use without changing Component topology.")
	scale_input.free()
	application.free()
	var ribbon := _component()
	ribbon.merge({"id": "component_ribbon", "name": "ArmLine", "draw_mode": "ribbon", "ribbon_width_px": 8.0, "visibility": true})
	BezierTopology.add_point(ribbon, Vector2.ZERO, "linear")
	BezierTopology.add_point(ribbon, Vector2(0.0, 8.0), "linear")
	var ribbon_mesh := RibbonMeshService.generate(ribbon)
	ribbon_mesh["bake_id"] = "mesh_ribbon_uv_test"
	var ribbon_application: Control = application_script.new()
	var ribbon_document: Dictionary = ribbon_application._default_geometry_document("asset_ribbon", "component_ribbon")
	ribbon_document["meshing"]["bakes"][RibbonMeshService.METHOD] = ribbon_mesh
	ribbon_document["component_mesh"] = {"bake_id": "mesh_ribbon_uv_test", "method": RibbonMeshService.METHOD, "mesh_fingerprint": GeometryUVMappingService.mesh_fingerprint(ribbon_mesh)}
	var ribbon_assets: Array[Dictionary] = [{"id": "asset_ribbon", "name": "Wizard", "visibility": true, "components": [ribbon], "guides": []}]
	ribbon_application.assets = ribbon_assets
	ribbon_application.geometry_documents["asset_ribbon/component_ribbon"] = ribbon_document
	_expect(ribbon_application._all_uv_update_candidates() == [{"asset_id": "asset_ribbon", "component_id": "component_ribbon"}], "The UV batch should include a visible Ribbon with a current accepted Component Mesh.")
	var ribbon_build: Dictionary = ribbon_application._generate_component_uv_build("asset_ribbon", "component_ribbon")
	_expect(bool(ribbon_build.get("valid", false)) and str(ribbon_build.get("result", {}).get("mesh_method", "")) == RibbonMeshService.METHOD, "Automatic UV generation should consume the accepted Ribbon Strip Component Mesh without a manual source choice.")
	ribbon_application._commit_component_uv_build("asset_ribbon", "component_ribbon", ribbon_build)
	_expect(ribbon_application._all_uv_update_candidates().is_empty() and ribbon_application._geometry_uv_mapping_status("asset_ribbon", "component_ribbon", ribbon) == "Baked", "Committing an automatic Ribbon UV Bake should clear its actionable batch state.")
	ribbon["visibility"] = false
	ribbon_document["uv_mapping"]["bakes"].clear()
	_expect(ribbon_application._all_uv_update_candidates().is_empty(), "The UV batch should not mutate hidden Components.")
	ribbon_application.free()


func _test_geometry_sdf_service_and_batch() -> void:
	var mesh := {
		"valid": true,
		"bake_id": "mesh_sdf_test",
		"method": GeometryMeshingService.CONSTRAINED_MESH,
		"vertices": [
			{"id": "v0", "position": Vector2.ZERO},
			{"id": "v1", "position": Vector2(10.0, 0.0)},
			{"id": "v2", "position": Vector2(10.0, 10.0)},
			{"id": "v3", "position": Vector2(0.0, 10.0)}
		],
		"triangles": [
			{"vertex_ids": ["v0", "v1", "v2"]},
			{"vertex_ids": ["v0", "v2", "v3"]}
		]
	}
	var uv_recipe := GeometryUVMappingService.default_recipe()
	var uv := GeometryUVMappingService.generate(mesh, uv_recipe)
	uv["bake_id"] = "uv_sdf_test"
	var sdf := GeometrySDFService.generate(mesh, uv)
	var repeated := GeometrySDFService.generate(mesh, uv)
	var sdf_image: Image = sdf.get("image", null)
	_expect(bool(sdf.get("valid", false)) and sdf_image != null and sdf_image.get_format() == Image.FORMAT_L8 and sdf_image.get_width() == 256 and sdf_image.get_height() == 256, "SDF generation should produce the accepted 256x256 single-channel linear image.")
	_expect(str(sdf.get("pixel_hash", "")) == str(repeated.get("pixel_hash", "")) and str(sdf.get("source_fingerprint", "")) == str(repeated.get("source_fingerprint", "")), "Identical Mesh, UV, and SDF recipes should produce deterministic semantic content and pixels.")
	_expect(sdf_image.get_pixel(128, 128).r > 0.5 and sdf_image.get_pixel(0, 0).r < 0.5 and is_equal_approx(float(sdf.get("boundary_value", 0.0)), 0.5) and bool(sdf.get("inside_is_greater", false)), "The SDF should encode the filled silhouette above 0.5 and exterior texels below 0.5.")
	var invalid_uv := uv.duplicate(true)
	invalid_uv["uvs"][0]["uv"] = Vector2(-0.1, 0.0)
	_expect(not bool(GeometrySDFService.generate(mesh, invalid_uv).get("valid", true)), "SDF generation should reject UV geometry outside normalized texture space instead of clipping it.")
	var single_triangle_mesh := mesh.duplicate(true)
	single_triangle_mesh["vertices"] = single_triangle_mesh["vertices"].slice(0, 3)
	single_triangle_mesh["triangles"] = [single_triangle_mesh["triangles"][0]]
	single_triangle_mesh["bake_id"] = "mesh_sdf_tiny_triangle"
	var tiny_uv := GeometryUVMappingService.generate(single_triangle_mesh, uv_recipe)
	tiny_uv["bake_id"] = "uv_sdf_tiny_triangle"
	tiny_uv["uvs"][0]["uv"] = Vector2(0.5, 0.5)
	tiny_uv["uvs"][1]["uv"] = Vector2(0.50001, 0.5)
	tiny_uv["uvs"][2]["uv"] = Vector2(0.5, 0.50001)
	_expect(GeometrySDFService.validation_issues(single_triangle_mesh, tiny_uv).is_empty(), "SDF validation should retain a tiny but well-shaped UV Triangle independently of its absolute normalized area.")
	var collapsed_uv := tiny_uv.duplicate(true)
	collapsed_uv["uvs"][2]["uv"] = Vector2(0.50002, 0.5)
	_expect(not GeometrySDFService.validation_issues(single_triangle_mesh, collapsed_uv).is_empty(), "SDF validation should still reject a truly collinear UV Triangle through its scale-relative orientation test.")
	var ribbon := _component()
	ribbon.merge({"id": "component_sdf", "name": "ArmLine", "draw_mode": "ribbon", "ribbon_width_px": 8.0, "visibility": true})
	BezierTopology.add_point(ribbon, Vector2.ZERO, "linear")
	BezierTopology.add_point(ribbon, Vector2(0.0, 8.0), "linear")
	var ribbon_mesh := RibbonMeshService.generate(ribbon)
	ribbon_mesh["bake_id"] = "mesh_ribbon_sdf_test"
	var ribbon_uv_recipe := GeometryUVMappingService.default_recipe()
	ribbon_uv_recipe["parameters"]["mesh_method"] = RibbonMeshService.METHOD
	var ribbon_uv := GeometryUVMappingService.generate(ribbon_mesh, ribbon_uv_recipe)
	ribbon_uv["bake_id"] = "uv_ribbon_sdf_test"
	var application_script = load("res://scripts/main.gd")
	var application: Control = application_script.new()
	var document: Dictionary = application._default_geometry_document("asset_sdf", "component_sdf")
	document["meshing"]["bakes"][RibbonMeshService.METHOD] = ribbon_mesh
	document["component_mesh"] = {"bake_id": "mesh_ribbon_sdf_test", "method": RibbonMeshService.METHOD, "mesh_fingerprint": GeometryUVMappingService.mesh_fingerprint(ribbon_mesh)}
	document["uv_mapping"]["recipe"] = ribbon_uv_recipe
	document["uv_mapping"]["bakes"][GeometryUVMappingService.bake_key(RibbonMeshService.METHOD, GeometryUVMappingService.BOUNDS_PLANAR)] = ribbon_uv
	document["sdf"]["last_error"] = "Legacy validation failure"
	document["sdf"]["last_failure_fingerprint"] = GeometrySDFService.source_fingerprint(ribbon_mesh, ribbon_uv, document["sdf"]["recipe"])
	var assets: Array[Dictionary] = [{"id": "asset_sdf", "name": "Wizard", "visibility": true, "components": [ribbon], "guides": []}]
	application.assets = assets
	application.geometry_documents["asset_sdf/component_sdf"] = document
	_expect(application._all_sdf_update_candidates() == [{"asset_id": "asset_sdf", "component_id": "component_sdf"}] and application._sdf_batch_summary(application._all_sdf_update_candidates()).get("attention", []).is_empty(), "A superseded validation failure should become actionable again without leaving a stale attention warning.")
	var build: Dictionary = application._generate_component_sdf_build("asset_sdf", "component_sdf")
	_expect(bool(build.get("valid", false)) and application._commit_component_sdf_build("asset_sdf", "component_sdf", build), "The SDF batch should generate and atomically accept a Ribbon contour image.")
	_expect(application._sdf_status("asset_sdf", "component_sdf", ribbon) == "Baked" and application._all_sdf_update_candidates().is_empty(), "A current accepted SDF resource should clear the actionable batch state.")
	var round_trip: Dictionary = application._normalize_geometry_document(application._serialize_geometry_document(document), "asset_sdf", "component_sdf")
	_expect(str(round_trip.get("sdf", {}).get("bake", {}).get("pixel_hash", "")) == str(document.get("sdf", {}).get("bake", {}).get("pixel_hash", "")) and not round_trip.get("sdf", {}).get("bake", {}).has("image"), "SDF metadata should survive Geometry persistence without embedding image pixels into JSON.")
	document["uv_mapping"]["bakes"][GeometryUVMappingService.bake_key(RibbonMeshService.METHOD, GeometryUVMappingService.BOUNDS_PLANAR)]["uvs"][0]["uv"] += Vector2(0.001, 0.0)
	_expect(application._sdf_status("asset_sdf", "component_sdf", ribbon) == "Stale" and application._all_sdf_update_candidates().size() == 1, "Changing accepted UV coordinates should make the dependent SDF stale without mutating Mesh or Component topology.")
	application.free()


func _test_semantic_registry_and_picker() -> void:
	var registry := SemanticRegistry.load_registry()
	_expect(bool(registry.get("valid", false)) and int(registry.get("schema_version", SemanticRegistry.REGISTRY_SCHEMA_VERSION)) == SemanticRegistry.REGISTRY_SCHEMA_VERSION, "The read-only Semantic Registry should load its independently versioned contract.")
	_expect(registry.get("semantics", []) == ["arm_line", "belly", "body", "cloak", "eye_left", "eye_right", "eyebrow_left", "eyebrow_right", "feet", "hat", "hat_back", "hat_tip", "head", "head_tip"], "Semantic Keys should remain canonical, unique, and alphabetically sorted.")
	_expect(SemanticRegistry.migrate_legacy_key("Barde", {"name": "Orb"}, registry) == "belly" and SemanticRegistry.migrate_legacy_key("Orb", {"name": "orb"}, registry) == "body" and SemanticRegistry.migrate_legacy_key("Tree", {"name": "Trunk"}, registry) == "body" and SemanticRegistry.migrate_legacy_key("Hammerer", {"name": "Trapez"}, registry) == "feet", "Legacy migration should apply the explicitly approved asset-specific semantic mappings.")
	_expect(SemanticRegistry.migrate_legacy_key("Glavier", {"name": "HeadTip"}, registry) == "head_tip" and SemanticRegistry.migrate_legacy_key("Mage", {"name": "HatTip"}, registry) == "hat_tip" and SemanticRegistry.migrate_legacy_key("Glavier", {"name": "Belly"}, registry) == "belly", "Legacy migration should preserve Head Tip, Hat Tip, and Belly as distinct approved meanings.")
	_expect(SemanticRegistry.mirror_key("eye_left") == "eye_right" and SemanticRegistry.mirror_key("eyebrow_right") == "eyebrow_left", "Known left/right Semantic pairs should expose deterministic duplicate mappings.")
	_expect(SemanticRegistry.component_display_name({"semantic_key": "removed_key"}, registry) == "missing_semantic (removed_key)", "A missing Registry link should remain visible without inventing a replacement Semantic Key.")
	var picker := SemanticPicker.new()
	picker.configure(registry.get("semantics", []), "body", ["hat"])
	_expect(picker.list.item_count == registry.get("semantics", []).size() - 1 and picker.selected_key == "body", "The Semantic Picker should list available keys alphabetically, exclude already-used keys, and retain its current selection.")
	picker.search_input.text = "eye"
	picker._render_items("eye")
	_expect(picker.list.item_count == 4 and str(picker.list.get_item_metadata(0)).begins_with("eye"), "The Semantic Picker should filter keys immediately through its integrated search field.")
	picker.free()
	var dropdown := SemanticDropdown.new()
	dropdown.configure(registry.get("semantics", []), "body", ["hat"])
	_expect(dropdown.selected_key == "body" and dropdown.text.begins_with("body") and dropdown.list.item_count == registry.get("semantics", []).size() - 1, "The Inspector Semantic control should stay compact while its dropdown retains the searchable filtered list.")
	dropdown.search_input.text = "tip"
	dropdown._render_items("tip")
	_expect(dropdown.list.item_count == 2, "The Semantic dropdown should provide its search field inside the opened menu.")
	dropdown.free()
	var application_script = load("res://scripts/main.gd")
	var application: Control = application_script.new()
	var source_component := _component()
	source_component.merge({"id": "component_1", "name": "body", "semantic_key": "body", "visibility": true})
	var semantic_asset := {"id": "character", "name": "Character", "asset_type": "character", "visibility": true, "components": [source_component], "guides": []}
	var symbol_asset := {"id": "orb", "name": "Orb", "asset_type": "symbols", "visibility": true, "components": [], "guides": []}
	var semantic_assets: Array[Dictionary] = [semantic_asset, symbol_asset]
	application.assets = semantic_assets
	application._build_ui()
	_expect(application.component_dialog.dialog_text.is_empty() and application.duplicate_semantic_dialog.dialog_text.is_empty(), "Semantic dialogs should keep AcceptDialog's built-in text empty so it cannot overlap the custom search field.")
	application._duplicate_component("character", "component_1")
	_expect(semantic_asset.get("components", []).size() == 1 and application.pending_component_duplicate.get("unresolved", []).size() == 1, "Duplicating a Component without a known mirror pair should pause before mutation and require an explicit Semantic Key.")
	application.duplicate_semantic_picker.configure(registry.get("semantics", []), "belly", ["body"])
	application._confirm_duplicate_semantic()
	_expect(semantic_asset.get("components", []).size() == 2 and str(semantic_asset.get("components", [])[1].get("semantic_key", "")) == "belly", "Choosing an available Semantic Key should commit the previously unresolved duplicate.")
	application.component_dialog.set_meta("asset_id", "character")
	application.component_dialog.set_meta("parent_component_id", "")
	application.component_dialog.set_meta("draw_mode", "reference")
	application.component_dialog.set_meta("source_asset_id", "orb")
	application.component_semantic_picker.configure(registry.get("semantics", []), "feet", ["body", "belly"])
	application._confirm_component_creation()
	var created_reference: Dictionary = semantic_asset.get("components", [])[2]
	_expect(str(created_reference.get("type", "")) == "reference" and str(created_reference.get("semantic_key", "")) == "feet" and str(created_reference.get("source_asset_id", "")) == "orb", "Reference creation should require a local Semantic Key while retaining the actual source Asset ID.")
	application.free()


func _test_asset_catalog_service() -> void:
	_expect(AssetCatalogService.asset_key("Magic Orb") == "magic_orb" and AssetCatalogService.asset_key("Ancient Orb") == "ancient_orb" and AssetCatalogService.asset_key("Orb") == "orb", "Asset Keys should derive deterministically from the complete display name.")
	_expect(AssetCatalogService.asset_key("  Mage's Hat-Tip  ") == "mage_s_hat_tip", "Asset Key derivation should collapse punctuation and whitespace into lower_snake_case separators.")
	var assets: Array[Dictionary] = [
		{"id": "internal_3", "name": "Orb", "asset_type": "symbols", "visibility": true},
		{"id": "internal_1", "name": "Magic Orb", "asset_type": "props", "visibility": true},
		{"id": "internal_2", "name": "Ancient Orb", "asset_type": "props", "visibility": true}
	]
	var build := AssetCatalogService.build_catalog("world01", "Secrets, Room's & Travels'", assets)
	var catalog: Dictionary = build.get("catalog", {})
	var entries: Array = catalog.get("assets", [])
	_expect(bool(build.get("valid", false)) and int(catalog.get("schema_version", 0)) == 1 and str(catalog.get("world_key", "")) == "world01", "Every World should derive an independently versioned Asset Catalog.")
	_expect(entries.size() == 3 and str(entries[0].get("asset_key", "")) == "ancient_orb" and str(entries[2].get("asset_key", "")) == "orb", "Catalog entries should be sorted alphabetically by Asset Key.")
	_expect(not JSON.stringify(catalog).contains("asset_id") and str(entries[1].get("runtime_package", "")) == "PolyToolsRuntimeExports/magic_orb/manifest.json", "The public Asset Catalog should expose key-based package paths without internal Asset IDs.")
	var collision_assets: Array[Dictionary] = assets.duplicate(true)
	collision_assets.append({"id": "internal_4", "name": "Magic-Orb", "asset_type": "props", "visibility": false})
	_expect(not bool(AssetCatalogService.build_catalog("world01", "World", collision_assets).get("valid", true)), "Asset Key collisions should be rejected even when one conflicting Asset is hidden.")
	var application = load("res://scripts/main.gd").new()
	application.assets = assets
	_expect(application._asset_name_validation_error("Magic-Orb") == "Asset Key 'magic_orb' is already used by 'Magic Orb'.", "Asset creation and rename validation should explain the exact derived-key collision.")
	application.free()


func _test_runtime_export_service() -> void:
	var application = load("res://scripts/main.gd").new()
	application.world_name = "world01"
	application.world_title = "Secrets, Room's & Travels'"
	_expect(application._runtime_export_root() == ProjectSettings.globalize_path("res://worlds/world01/PolyToolsRuntimeExports"), "Runtime packages should be written to the ignored PolyToolsRuntimeExports directory owned by the active World.")
	var numeric_manifest := {"schema_version": 1, "values": [0, 1.0, 0.25]}
	var numeric_manifest_text := JSON.stringify(numeric_manifest, "\t")
	_expect(application._runtime_manifest_text_matches(numeric_manifest_text, numeric_manifest_text), "Runtime staging should verify the exact valid JSON bytes without rejecting Godot's numeric JSON round-trip types.")
	_expect(not application._runtime_manifest_text_matches(numeric_manifest_text, numeric_manifest_text + " "), "Runtime staging should reject Manifest bytes that differ from the expected package.")
	application.free()
	var mesh := {
		"valid": true,
		"vertices": [
			{"id": "v0", "position": Vector2(0.0, 0.0)},
			{"id": "v1", "position": Vector2(10.0, 0.0)},
			{"id": "v2", "position": Vector2(0.0, 10.0)}
		],
		"triangles": [{"vertex_ids": ["v0", "v1", "v2"]}]
	}
	var uv := {"valid": true, "uvs": [
		{"vertex_id": "v2", "uv": Vector2(0.0, 1.0)},
		{"vertex_id": "v0", "uv": Vector2(0.0, 0.0)},
		{"vertex_id": "v1", "uv": Vector2(1.0, 0.0)}
	]}
	var sdf := {"valid": true, "resolution": [256, 256], "spread_px": 16.0, "boundary_value": 0.5, "inside_is_greater": true, "pixel_hash": "stable_pixels"}
	var body := {"id": "component_b", "name": "body", "semantic_key": "body", "visibility": true, "z_index": 2, "parent_component_id": "", "transform": {"position": Vector2(10.0, 20.0), "pivot": Vector2(2.0, 3.0), "rotation": 90.0, "scale": Vector2(2.0, 1.0)}}
	var eye := {"id": "component_a", "name": "eye_left", "semantic_key": "eye_left", "visibility": true, "z_index": 2, "parent_component_id": "component_b", "transform": {"position": Vector2.ZERO, "pivot": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE}}
	var asset := {"id": "wizard", "name": "Wizard", "asset_type": "character", "visibility": true, "asset_pivot": Vector2(5.0, 6.0), "components": [body, eye]}
	var source := {"mesh": mesh, "uv": uv, "sdf": sdf, "sdf_resource_valid": true, "sdf_source_path": "/tmp/contour_sdf.png"}
	var result := RuntimeExportService.build_manifest(asset, {"component_a": source, "component_b": source})
	var manifest: Dictionary = result.get("manifest", {})
	var components: Array = manifest.get("components", [])
	_expect(bool(result.get("valid", false)) and int(manifest.get("schema_version", 0)) == 2 and str(manifest.get("asset_key", "")) == "wizard" and not manifest.has("asset_id"), "Runtime export schema 2 should identify packages only by the Asset Key derived from their display name.")
	_expect(components.size() == 2 and str(components[0].get("component_id", "")) == "component_a" and str(components[1].get("component_id", "")) == "component_b", "Runtime Components should sort globally by ascending z_index and lexicographic Component ID.")
	_expect(components[1].get("mesh", {}).get("vertices", []) == [[-0.2, -0.30000000000000004], [0.8, -0.30000000000000004], [-0.2, 0.7000000000000001]] and components[1].get("mesh", {}).get("indices", []) == [0, 1, 2], "Runtime Meshes should preserve accepted Vertex order, convert Tool units to meters, compact Triangle IDs, and be local to their Component pivot.")
	_expect(components[1].get("mesh", {}).get("uvs", []) == [[0.0, 0.0], [1.0, 0.0], [0.0, 1.0]], "Runtime UVs should be reordered only through stable Vertex IDs.")
	_expect(components[1].get("local_transform", {}).get("position", []) == [1.0, 2.0] and is_equal_approx(float(components[1].get("local_transform", {}).get("rotation_radians", 0.0)), PI / 2.0), "Runtime transforms should preserve Y-up coordinates and publish positions in meters and CCW radians.")
	_expect(not components[1].has("display_name") and str(components[1].get("semantic_key", "")) == "body", "Runtime Components should expose their Semantic Key as the sole authored designation without a redundant display label.")
	var wizard_head := {"id": "head", "semantic_key": "head", "visibility": true, "parent_component_id": "", "transform": {"position": Vector2(0.0, 8.5), "pivot": Vector2(0.0, 8.5), "rotation": 0.0, "scale": Vector2.ONE}}
	var wizard_eye := {"id": "eye", "semantic_key": "eye_left", "visibility": true, "parent_component_id": "head", "transform": {"position": Vector2(-0.3, 8.5), "pivot": Vector2(-0.3, 8.5), "rotation": 0.0, "scale": Vector2.ONE}}
	var head_mesh: Dictionary = mesh.duplicate(true)
	head_mesh["vertices"] = [{"id": "v0", "position": Vector2(0.0, 8.5)}, {"id": "v1", "position": Vector2(1.0, 8.5)}, {"id": "v2", "position": Vector2(0.0, 9.5)}]
	var eye_mesh: Dictionary = mesh.duplicate(true)
	eye_mesh["vertices"] = [{"id": "v0", "position": Vector2(-0.25, 8.5)}, {"id": "v1", "position": Vector2(-0.15, 8.5)}, {"id": "v2", "position": Vector2(-0.25, 8.6)}]
	var nested_asset := {"id": "nested_wizard", "name": "Nested Wizard", "asset_type": "character", "visibility": true, "asset_pivot": Vector2.ZERO, "components": [wizard_head, wizard_eye]}
	var nested_result := RuntimeExportService.build_manifest(nested_asset, {"head": {"mesh": head_mesh, "uv": uv, "sdf": sdf, "sdf_resource_valid": true, "sdf_source_path": "/tmp/head_sdf.png"}, "eye": {"mesh": eye_mesh, "uv": uv, "sdf": sdf, "sdf_resource_valid": true, "sdf_source_path": "/tmp/eye_sdf.png"}})
	var nested_by_id: Dictionary = {}
	for exported_component in nested_result.get("manifest", {}).get("components", []):
		nested_by_id[str(exported_component.get("component_id", ""))] = exported_component
	var exported_eye: Dictionary = nested_by_id.get("eye", {})
	var eye_vertex: Array = exported_eye.get("mesh", {}).get("vertices", [])[0]
	var reconstructed_eye := _runtime_export_world_transform(nested_by_id, "eye") * Vector2(float(eye_vertex[0]), float(eye_vertex[1]))
	var eye_local_position: Array = exported_eye.get("local_transform", {}).get("position", [])
	_expect(bool(nested_result.get("valid", false)) and exported_eye.get("local_pivot", []) == [0.0, 0.0] and is_equal_approx(float(eye_local_position[0]), -0.03) and is_zero_approx(float(eye_local_position[1])) and reconstructed_eye.is_equal_approx(Vector2(-0.025, 0.85)), "Nested Wizard Head → Eye export should use child-local mesh/pivot data and reconstruct its intended asset-space world position exactly.")
	var reference := {"id": "component_orb", "type": "reference", "semantic_key": "belly", "source_asset_id": "orb", "visibility": true, "z_index": 3, "parent_component_id": "component_b", "transform": {"position": Vector2(3.0, 4.0), "pivot": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE}}
	var referenced_asset: Dictionary = asset.duplicate(true)
	referenced_asset["components"].append(reference)
	var reference_source := {"owner_asset_id": "wizard", "source_asset_exists": true, "source_asset_key": "orb"}
	var referenced_result := RuntimeExportService.build_manifest(referenced_asset, {"component_a": source, "component_b": source, "component_orb": reference_source})
	var referenced_components: Array = referenced_result.get("manifest", {}).get("components", [])
	var exported_reference: Dictionary = referenced_components[2] if referenced_components.size() == 3 else {}
	_expect(bool(referenced_result.get("valid", false)) and str(exported_reference.get("kind", "")) == "asset_reference" and str(exported_reference.get("source_asset_key", "")) == "orb" and not exported_reference.has("source_asset_id") and str(exported_reference.get("semantic_key", "")) == "belly" and not exported_reference.has("mesh"), "A local Semantic Key should classify a Reference while source_asset_key preserves the referenced runtime Asset identity.")
	reference_source["source_asset_exists"] = false
	_expect(not bool(RuntimeExportService.build_manifest(referenced_asset, {"component_a": source, "component_b": source, "component_orb": reference_source}).get("valid", true)), "Runtime export should reject a Reference whose actual source Asset cannot be resolved.")
	var duplicate_role_asset: Dictionary = asset.duplicate(true)
	duplicate_role_asset["components"][1]["semantic_key"] = "body"
	_expect(not bool(RuntimeExportService.build_manifest(duplicate_role_asset, {"component_a": source, "component_b": source}).get("valid", true)), "Runtime export should reject duplicate Semantic Keys.")
	var missing_resource: Dictionary = source.duplicate(true)
	missing_resource["sdf_resource_valid"] = false
	_expect(not bool(RuntimeExportService.build_manifest(asset, {"component_a": missing_resource, "component_b": source}).get("valid", true)), "Runtime export should reject a missing or corrupt SDF resource without fallback.")


func _test_weighting_service_and_ui() -> void:
	var component := _component()
	component.merge({"id": "component_weighting", "name": "Body", "visibility": true})
	for position in [Vector2.ZERO, Vector2(10.0, 0.0), Vector2(10.0, 10.0), Vector2(0.0, 10.0)]:
		BezierTopology.add_point(component, position, "linear")
	BezierTopology.close_active_chain(component)
	var sampling := GeometrySamplingService.generate(component, {"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 2.0}})
	sampling["bake_id"] = "sampling_weighting"
	var seeding := GeometrySeedingService.generate(sampling, {"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 2.5, "seed": 5}})
	seeding["bake_id"] = "seeding_weighting"
	var mesh := GeometryMeshingService.generate(sampling, seeding, {"method": GeometryMeshingService.CONSTRAINED_MESH, "parameters": {"seeding_method": GeometrySeedingService.POISSON_FILL}})
	mesh["bake_id"] = "mesh_weighting"
	var uniform_style := WeightingService.default_style("weight_uniform", "Uniform", "component_weighting")
	uniform_style["parameters"]["strength"] = 0.6
	var uniform := WeightingService.generate(mesh, uniform_style)
	_expect(bool(uniform.get("valid", false)) and int(uniform.get("weight_count", 0)) == int(mesh.get("vertex_count", 0)) and is_equal_approx(float(uniform.get("minimum_weight", 0.0)), 0.6) and uniform == WeightingService.generate(mesh, uniform_style), "Uniform Weighting should deterministically assign the same strength to every stable Mesh Vertex ID.")
	var gradient_style := WeightingService.default_style("weight_gradient", "Bottom to Top", "component_weighting")
	gradient_style["method"] = WeightingService.AXIS_GRADIENT
	gradient_style["parameters"] = WeightingService.default_parameters(WeightingService.AXIS_GRADIENT)
	var gradient := WeightingService.generate(mesh, gradient_style)
	_expect(bool(gradient.get("valid", false)) and is_zero_approx(float(gradient.get("minimum_weight", 1.0))) and is_equal_approx(float(gradient.get("maximum_weight", 0.0)), 1.0), "Axis Gradient should map Component-local Mesh bounds into a normalized zero-to-one Weight range.")
	var application_script = load("res://scripts/main.gd")
	var application: Control = application_script.new()
	var document: Dictionary = application._default_geometry_document("asset_weighting", "component_weighting")
	document["sampling"]["recipe"] = {"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 2.0}}
	document["sampling"]["bakes"][GeometrySamplingService.ADAPTIVE] = sampling
	document["seeding"]["recipe"] = {"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 2.5, "seed": 5}}
	document["seeding"]["bakes"][GeometrySeedingService.POISSON_FILL] = seeding
	document["meshing"]["recipe"] = {"method": GeometryMeshingService.CONSTRAINED_MESH, "parameters": {"seeding_method": GeometrySeedingService.POISSON_FILL}}
	document["meshing"]["bakes"][GeometryMeshingService.CONSTRAINED_MESH] = mesh
	document["component_mesh"] = {"bake_id": "mesh_weighting", "method": GeometryMeshingService.CONSTRAINED_MESH, "mesh_fingerprint": GeometryUVMappingService.mesh_fingerprint(mesh)}
	document["weighting"]["styles"].append(gradient_style)
	var weighting_assets: Array[Dictionary] = [{"id": "asset_weighting", "name": "Asset", "visibility": true, "components": [component], "guides": []}]
	application.assets = weighting_assets
	application.geometry_documents["asset_weighting/component_weighting"] = document
	application._build_ui()
	application.selected_asset_id = "asset_weighting"
	application.selected_component_id = "component_weighting"
	application.selected_weighting_style_id = "weight_gradient"
	application.active_module = "Style"
	application.active_style_submodule = "Weighting"
	application._generate_weighting_preview()
	_expect(application.weighting_workspace.visible and WeightingService.result_matches(application.weighting_preview, mesh, gradient_style), "Style Weighting should show a generated Mesh heatmap from the explicit Component Mesh and selected Style.")
	application._set_active_context_command("style.weighting.method")
	application._render_context_bar()
	var weighting_popup: PopupMenu = application.weighting_method_menu.get_popup()
	weighting_popup.emit_signal("id_pressed", 0)
	_expect(str(gradient_style.get("method", "")) == WeightingService.UNIFORM and application.active_context_command.is_empty(), "Selecting a Weighting Method from CMD+1 must apply the method and clear the transient Context command instead of leaving the menu stuck.")
	application._bake_weighting_preview()
	_expect(application._weighting_status("asset_weighting", "component_weighting", component, gradient_style) == "Baked" and not gradient_style.get("bake", {}).is_empty(), "Weighting Bake should persist one derived result on its Style.")
	var round_trip: Dictionary = application._normalize_geometry_document(application._serialize_geometry_document(document), "asset_weighting", "component_weighting")
	_expect(round_trip.get("weighting", {}).get("styles", []).size() == 1 and int(round_trip.get("weighting", {}).get("styles", [])[0].get("bake", {}).get("weight_count", 0)) == int(mesh.get("vertex_count", 0)), "Weighting Styles and per-Vertex Bakes should survive Geometry persistence.")
	application.free()


func _test_component_hierarchy_model() -> void:
	var parent := {
		"id": "component_parent",
		"name": "Head",
		"parent_component_id": "",
		"transform": {"position": Vector2(10.0, 0.0), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}
	}
	var child := {
		"id": "component_child",
		"name": "Eyes",
		"parent_component_id": "component_parent",
		"transform": {"position": Vector2(2.0, 0.0), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}
	}
	var flow_1 := AssetGuide.create("guide_1", "Legacy Flow", "body_flow", "component_parent", 1)
	var flow_2 := AssetGuide.create("guide_2", "Legacy Flow 2", "body_flow", "component_parent", 1)
	var sample_1 := AssetGuide.create("guide_3", "Legacy Sample", "sampler_spine", "component_parent", 1)
	var child_sample := AssetGuide.create("guide_4", "Child Sample", "sampler_spine", "component_child", 1)
	var asset := {"components": [parent, child], "guides": [flow_1, flow_2, sample_1, child_sample]}
	ComponentHierarchy.normalize_asset(asset)
	_expect(ComponentHierarchy.children(asset, "component_parent").size() == 1 and ComponentHierarchy.descendants(asset, "component_parent").size() == 1, "The internal Component model should expose explicit recursive Parent-Child relationships.")
	_expect(ComponentHierarchy.world_transform(asset, "component_child").origin.is_equal_approx(Vector2(12.0, 0.0)), "Child Component transforms should compose locally through their Parent.")
	var child_world_record := ComponentHierarchy.world_transform_record(asset, "component_child")
	_expect(Vector2(child_world_record.get("position", Vector2.ZERO)).is_equal_approx(Vector2(12.0, 0.0)), "The Canvas-facing transform record should expose a Child Component at its composed world position.")
	child["parent_component_id"] = ""
	child["transform"] = ComponentHierarchy.local_transform_from_world_record(asset, "component_child", child_world_record)
	_expect(ComponentHierarchy.world_transform(asset, "component_child").origin.is_equal_approx(Vector2(12.0, 0.0)), "Reparenting a Component to Root should preserve its visible world transform.")
	child["parent_component_id"] = "component_parent"
	child["transform"] = ComponentHierarchy.local_transform_from_world_record(asset, "component_child", child_world_record)
	_expect(ComponentHierarchy.world_transform(asset, "component_child").origin.is_equal_approx(Vector2(12.0, 0.0)), "Reparenting a Component under another Parent should preserve its visible world transform.")
	_expect(ComponentHierarchy.can_parent(asset, "component_parent", "component_child") == false, "Component hierarchy validation should reject cycles.")
	_expect(str(flow_1.get("guide_type", "")) == AssetGuide.FLOW and int(flow_1.get("ordinal", 0)) == 1 and int(flow_2.get("ordinal", 0)) == 2, "Legacy Flow Guides should migrate to canonical types with stable per-Component ordinals.")
	_expect(int(sample_1.get("ordinal", 0)) == 1 and int(child_sample.get("ordinal", 0)) == 1, "Guide numbering should be independent for every Component and Guide type.")
	_expect(ComponentHierarchy.next_guide_ordinal(asset, "component_parent", AssetGuide.FLOW) == 3 and AssetGuide.outliner_name(child_sample, "Eyes") == "Eyes → Sample01", "Guide naming data should support stable dynamic Component-based labels.")
	parent["name"] = "Face"
	_expect(AssetGuide.outliner_name(flow_1, str(parent.get("name", ""))) == "Face → Flow01", "Guide labels should immediately follow Component renames without mutating Guide data.")
	_expect(AssetGuide.color(AssetGuide.FLOW) == Color("#4267b2") and AssetGuide.color(AssetGuide.FLOW) != AssetGuide.color(AssetGuide.SAMPLE) and AssetGuide.color(AssetGuide.SAMPLE) != AssetGuide.color(AssetGuide.MOTION), "Flow, Sample, and Motion Guides should retain three distinct semantic colors.")
	parent["parent_component_id"] = "component_child"
	ComponentHierarchy.normalize_asset(asset)
	_expect(str(parent.get("parent_component_id", "")).is_empty(), "Loading cyclic Component data should safely promote one participant to the Asset root.")


func _test_asset_guides() -> void:
	var component := _component()
	component.merge({"id": "component_1", "name": "body", "semantic_key": "body", "visibility": true, "transform": {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}})
	BezierTopology.add_point(component, Vector2.ZERO, "linear")
	BezierTopology.add_point(component, Vector2(10.0, 0.0), "linear")
	BezierTopology.add_point(component, Vector2(10.0, 10.0), "linear")
	BezierTopology.add_point(component, Vector2(0.0, 10.0), "linear")
	BezierTopology.close_active_chain(component)
	var component_point_count: int = component.get("points", []).size()
	var guide := AssetGuide.create("guide_1", "Body Flow 01", AssetGuide.BODY_FLOW, "component_1")
	BezierTopology.add_point(guide, Vector2(1.0, 2.0), "aligned")
	BezierTopology.add_point(guide, Vector2(4.0, 6.0), "aligned")
	BezierTopology.add_point(guide, Vector2(8.0, 3.0), "aligned", Vector2(10.0, 10.0))
	var smoothed_guide: Dictionary = AssetGuide.normalize(guide)
	var smooth_point: Dictionary = smoothed_guide.get("points", [])[1]
	var smooth_in: Vector2 = smooth_point.get("handle_in", Vector2.ZERO)
	var smooth_out: Vector2 = smooth_point.get("handle_out", Vector2.ZERO)
	_expect(str(smooth_point.get("mode", "")) == "aligned" and str(smooth_point.get("handle_source", "")) == "auto" and absf(smooth_in.normalized().dot(smooth_out.normalized()) + 1.0) < 0.001, "Spine Guides should normalize to automatic Smooth/Aligned handles without local kinks or loops.")
	_expect(AssetGuide.validation_issues(guide).is_empty(), "A Guide should validate as one open Spine without becoming Component geometry.")
	var application_script = load("res://scripts/main.gd")
	var application: Control = application_script.new()
	var serialized: Dictionary = application._serialize_asset_guide(guide)
	_expect(serialized.get("points", [])[0].get("position", null) is Array, "Guide persistence should serialize authored Spine positions as JSON arrays.")
	var restored: Dictionary = application._deserialize_asset_guide(serialized)
	_expect(restored.get("points", [])[0].get("position", null) is Vector2 and str(restored.get("guide_type", "")) == AssetGuide.BODY_FLOW, "Guide loading should restore Vector2 topology and retain its semantic type.")
	var animation_guide := AssetGuide.create("guide_animation", "Deform Spine", AssetGuide.ANIMATION_SPINE, "component_1")
	BezierTopology.add_point(animation_guide, Vector2(1.0, 2.0), "aligned")
	BezierTopology.add_point(animation_guide, Vector2(4.0, 6.0), "aligned")
	var animation_round_trip: Dictionary = application._deserialize_asset_guide(application._serialize_asset_guide(animation_guide))
	_expect(str(animation_round_trip.get("guide_type", "")) == AssetGuide.MOTION and AssetGuide.display_name(AssetGuide.MOTION) == "Motion", "Motion Guides should persist as an independent Guide type.")
	_expect(AssetGuide.validation_issues(animation_guide).is_empty(), "Animation Spines should use the same valid open Spine topology contract.")
	var legacy_guide := guide.duplicate(true)
	legacy_guide["type"] = "guide"
	var test_asset := {"id": "asset_1", "name": "Asset", "visibility": true, "components": [component, legacy_guide], "guides": []}
	_expect(application._get_component(test_asset, "guide_1").is_empty(), "Component lookup must never return a typed Guide.")
	var test_assets: Array[Dictionary] = [test_asset]
	application.assets = test_assets
	application._build_ui()
	application.active_module = "Create"
	application.active_create_submodule = "Character"
	application.selected_asset_id = "asset_1"
	application.selected_component_id = "component_1"
	application.guide_dialog.set_meta("asset_id", "asset_1")
	application.guide_dialog.set_meta("component_id", "component_1")
	application.guide_name_input.text = "Sampler Guide"
	application._confirm_guide_creation()
	_expect(test_asset.get("guides", []).size() == 1 and str(test_asset.get("guides", [])[0].get("scope", {}).get("component_id", "")) == "component_1", "A Component Add Guide action should create one persistent Component-scoped Guide.")
	var created_guide: Dictionary = test_asset.get("guides", [])[0]
	created_guide["guide_type"] = AssetGuide.SAMPLER_SPINE
	application._activate_guide_draw_state()
	_expect(application.active_state == "draw" and application.active_draw_tool == "spine" and application.canvas_view.guide_style, "Selected Guides should enter their own Draw Guide Point context through CMD+1.")
	_expect(application.canvas_view.draw_constraint_outer.size() >= 4 and bool(application.canvas_view.reference_shapes[0].get("emphasized", false)), "Spine drawing should keep its target Component emphasized and derive a closed draw constraint from its contour.")
	application._on_bezier_point_added(Vector2(15.0, 5.0), "aligned", Vector2.ZERO)
	_expect(Vector2(created_guide.get("points", [])[0].get("position", Vector2.ZERO)).is_equal_approx(Vector2(10.0, 5.0)), "A Guide Point outside the target Component should be caught by its contour.")
	var first_drawn_guide_point_id := str(created_guide.get("points", [])[0].get("id", ""))
	var draw_undo_snapshot: Dictionary = application._capture_history_snapshot()
	application._on_bezier_point_added(Vector2(5.0, 7.0), "aligned", Vector2.ZERO)
	application._restore_history_snapshot(draw_undo_snapshot)
	_expect(application.active_state == "draw" and application.active_draw_tool == "spine" and application.selected_point_ids == [first_drawn_guide_point_id] and application.canvas_view.selected_point_ids == [first_drawn_guide_point_id], "Undo during Draw Point should restore the prior open endpoint as the active draw anchor.")
	test_asset = application._get_asset("asset_1")
	created_guide = application._get_guide(test_asset, application.selected_guide_id)
	application._reset_to_default_state()
	application._activate_guide_edit_state()
	_expect(application.active_state == "edit" and application.active_edit_mode == "point", "Selected Guides should enter their own Edit Guide Point context through CMD+2.")
	_expect(test_asset.get("guides", []).size() == 1 and str(test_asset.get("guides", [])[0].get("guide_type", "")) == AssetGuide.SAMPLER_SPINE, "Guide authoring should retain the persistent typed Guide.")
	created_guide["guide_type"] = AssetGuide.ANIMATION_SPINE
	_expect(str(created_guide.get("guide_type", "")) == AssetGuide.ANIMATION_SPINE and application._sampler_spines_for_component(test_asset, "component_1").is_empty(), "A populated Guide should be able to change type, while Sampler Spine queries exclude Animation Spines.")
	created_guide["guide_type"] = AssetGuide.SAMPLER_SPINE
	application._duplicate_selected_guide()
	_expect(test_asset.get("guides", []).size() == 2 and str(application.selected_guide_id) != "guide_1", "CMD+D Guide duplication should create a new independent Guide ID.")
	var duplicate_guide: Dictionary = application._get_guide(test_asset, application.selected_guide_id)
	_expect(duplicate_guide.get("points", []).size() == created_guide.get("points", []).size() and str(duplicate_guide.get("points", [])[0].get("id", "")) != str(created_guide.get("points", [])[0].get("id", "")), "Guide duplication should deep-copy Spine topology with independent stable point IDs.")
	duplicate_guide["guide_type"] = AssetGuide.ANIMATION_SPINE
	_expect(application._sampler_spines_for_component(test_asset, "component_1").size() == 1 and application._animation_spines_for_component(test_asset, "component_1").size() == 1, "Sampler and Animation Spine queries should remain semantically separated after duplication.")
	_expect(component.get("points", []).size() == component_point_count and application.selected_component_id.is_empty() and not application.selected_guide_id.is_empty(), "Spine authoring must not mutate Component topology and should select the new Guide.")
	var snapshot: Dictionary = application._capture_history_snapshot()
	test_asset["guides"][0]["name"] = "Changed"
	application._restore_history_snapshot(snapshot)
	_expect(str(application._get_guide(application._get_asset("asset_1"), application.selected_guide_id).get("name", "")) == "Sampler Guide Copy", "Guides and their selection should participate in Undo/Redo snapshots.")
	var parent_component: Dictionary = application._get_component(application._get_asset("asset_1"), "component_1")
	application.selected_component_id = "component_1"
	application.selected_guide_id = ""
	application.selected_point_ids.clear()
	application.selected_point_ids.append(str(parent_component.get("points", [])[0].get("id", "")))
	application.selected_point_id = application.selected_point_ids[0]
	application.snap_enabled = true
	application.snap_grid_step = 0.5
	application._activate_edit_point_state(false, false)
	var point_before_nudge := Vector2(parent_component.get("points", [])[0].get("position", Vector2.ZERO))
	application._nudge_selected_point(Vector2.RIGHT)
	var point_after_nudge := Vector2(parent_component.get("points", [])[0].get("position", Vector2.ZERO))
	_expect(is_equal_approx(point_after_nudge.x, point_before_nudge.x + 0.5) and is_equal_approx(point_after_nudge.y, point_before_nudge.y), "Arrow keys in Edit Point Select mode should move the selected point by the configured Snap step.")
	application._nudge_selected_point(Vector2.LEFT)
	application.next_component_id = 2
	application.component_dialog.set_meta("asset_id", "asset_1")
	application.component_dialog.set_meta("parent_component_id", "component_1")
	application.component_dialog.set_meta("draw_mode", "ribbon")
	application.component_dialog.set_meta("source_asset_id", "")
	application.component_semantic_picker.configure(application.semantic_registry.get("semantics", []), "arm_line", ["body"])
	application._confirm_component_creation()
	var child_component: Dictionary = application._get_component(application._get_asset("asset_1"), application.selected_component_id)
	_expect(str(child_component.get("parent_component_id", "")) == "component_1" and Vector2(child_component.get("transform", {}).get("pivot", Vector2.ZERO)).is_equal_approx(Vector2(parent_component.get("transform", {}).get("pivot", Vector2.ZERO))), "Child creation should persist a real Parent relationship and inherit the Parent pivot initially.")
	_expect(application.canvas_view.catch_parent_component_id == "component_1", "A Child Component should automatically use its hierarchy Parent as the Catch Parent while drawing.")
	application._create_guide("asset_1", "component_1", AssetGuide.MOTION)
	var motion_guide: Dictionary = application._get_guide(application._get_asset("asset_1"), application.selected_guide_id)
	_expect(str(motion_guide.get("guide_type", "")) == AssetGuide.MOTION and int(motion_guide.get("ordinal", 0)) > 0, "The Component add flow should create typed Motion Guides without requesting a manual name.")
	application._activate_guide_draw_state()
	_expect(application.active_state == "draw" and application.active_draw_tool == "spine" and application.canvas_view.guide_style, "Motion Guides should use the same constrained Draw Guide Point workflow as Sample Guides.")
	application._on_bezier_point_added(Vector2(15.0, 5.0), "aligned", Vector2.ZERO)
	_expect(Vector2(motion_guide.get("points", [])[0].get("position", Vector2.ZERO)).is_equal_approx(Vector2(10.0, 5.0)), "Motion Guides should catch Draw Guide Points on their parent Component contour just like Sample Guides.")
	application._create_guide("asset_1", "component_1", AssetGuide.FLOW)
	var flow_guide: Dictionary = application._get_guide(application._get_asset("asset_1"), application.selected_guide_id)
	application._activate_guide_draw_state()
	application._on_bezier_point_added(Vector2(15.0, 5.0), "aligned", Vector2.ZERO)
	_expect(application.active_state == "draw" and Vector2(flow_guide.get("points", [])[0].get("position", Vector2.ZERO)).is_equal_approx(Vector2(10.0, 5.0)), "Flow Guides should catch Draw Guide Points on their parent Component contour just like Sample Guides.")
	_expect(application.component_add_child_menu.item_count == 3 and application.component_add_guide_menu.item_count == 4, "Every Component add menu should expose all three Child draw modes and all four Guide types.")
	parent_component["transform"] = {"position": Vector2(-3.0, 2.0), "rotation": 20.0, "scale": Vector2(1.0, 1.5), "pivot": Vector2.ZERO}
	parent_component["name"] = "eyebrow_left"
	parent_component["semantic_key"] = "eyebrow_left"
	child_component["name"] = "eye_left"
	child_component["semantic_key"] = "eye_left"
	var duplicate_asset: Dictionary = application._get_asset("asset_1")
	var component_count_before_duplicate: int = duplicate_asset.get("components", []).size()
	var guide_count_before_duplicate: int = duplicate_asset.get("guides", []).size()
	var descendant_count_before_duplicate: int = ComponentHierarchy.descendants(duplicate_asset, "component_1").size()
	application._duplicate_component("asset_1", "component_1")
	var plain_duplicate: Dictionary = application._get_component(application._get_asset("asset_1"), application.selected_component_id)
	var plain_duplicate_children := ComponentHierarchy.children(application._get_asset("asset_1"), str(plain_duplicate.get("id", "")))
	_expect(application._get_asset("asset_1").get("components", []).size() == component_count_before_duplicate + 1 + descendant_count_before_duplicate and application._get_asset("asset_1").get("guides", []).size() == guide_count_before_duplicate and str(plain_duplicate.get("parent_component_id", "")) == str(parent_component.get("parent_component_id", "")) and str(plain_duplicate.get("semantic_key", "")) == "eyebrow_right" and plain_duplicate_children.size() == descendant_count_before_duplicate and str(plain_duplicate_children[0].get("semantic_key", "")) == "eye_right", "Component Duplicate should copy the complete Component subtree and map known left/right Semantic Keys automatically.")
	_expect(str(plain_duplicate.get("id", "")) != "component_1" and str(plain_duplicate.get("points", [])[0].get("id", "")) != str(parent_component.get("points", [])[0].get("id", "")), "Component Duplicate should remap the Component and topology IDs independently.")
	for duplicate_child in plain_duplicate_children:
		application._get_asset("asset_1")["components"].erase(duplicate_child)
	application._get_asset("asset_1")["components"].erase(plain_duplicate)
	application._duplicate_component("asset_1", "component_1", "keep_orientation")
	var kept_duplicate: Dictionary = application._get_component(application._get_asset("asset_1"), application.selected_component_id)
	var kept_children := ComponentHierarchy.children(application._get_asset("asset_1"), str(kept_duplicate.get("id", "")))
	_expect(kept_children.size() == descendant_count_before_duplicate and kept_children[0].get("transform", {}) == child_component.get("transform", {}), "Keep Orientation should mirror only the subtree root; Child-local transforms must be inherited through the mirrored Parent.")
	var source_visual_center: Vector2 = application._component_visual_center_in_parent_space(parent_component)
	var kept_visual_center: Vector2 = application._component_visual_center_in_parent_space(kept_duplicate)
	_expect(is_equal_approx(kept_visual_center.x, -source_visual_center.x) and is_equal_approx(kept_visual_center.y, source_visual_center.y) and is_equal_approx(float(kept_duplicate.get("transform", {}).get("rotation", 0.0)), 20.0), "Keep Orientation should mirror the visible Component placement across the Parent Y axis without rotating it.")
	for duplicate_child in kept_children:
		application._get_asset("asset_1")["components"].erase(duplicate_child)
	application._get_asset("asset_1")["components"].erase(kept_duplicate)
	application._duplicate_component("asset_1", "component_1", "flip_orientation")
	var flipped_duplicate: Dictionary = application._get_component(application._get_asset("asset_1"), application.selected_component_id)
	_expect(is_equal_approx(float(flipped_duplicate.get("transform", {}).get("rotation", 0.0)), -20.0) and is_equal_approx(Vector2(flipped_duplicate.get("transform", {}).get("scale", Vector2.ONE)).x, -1.0), "Flip Orientation should mirror the Component geometry orientation as well as its Y-axis position.")
	var original_flip_position := Vector2(parent_component.get("points", [])[0].get("position", Vector2.ZERO))
	var flip_pivot := Vector2(parent_component.get("transform", {}).get("pivot", Vector2.ZERO))
	application._flip_component_geometry_x("asset_1", "component_1")
	var flipped_position := Vector2(parent_component.get("points", [])[0].get("position", Vector2.ZERO))
	_expect(is_equal_approx(flipped_position.x, 2.0 * flip_pivot.x - original_flip_position.x) and is_equal_approx(flipped_position.y, original_flip_position.y), "Flip X should reflect every Closed Loop point around the Component Pivot's vertical axis.")
	var child_world_before_detach := ComponentHierarchy.world_transform_record(application._get_asset("asset_1"), str(child_component.get("id", "")))
	application._detach_component("asset_1", str(child_component.get("id", "")))
	var detached_child: Dictionary = application._get_component(application._get_asset("asset_1"), str(child_component.get("id", "")))
	var child_world_after_detach := ComponentHierarchy.world_transform_record(application._get_asset("asset_1"), str(child_component.get("id", "")))
	_expect(str(detached_child.get("parent_component_id", "")).is_empty() and child_world_before_detach["position"].is_equal_approx(child_world_after_detach["position"]) and is_equal_approx(float(child_world_before_detach["rotation"]), float(child_world_after_detach["rotation"])), "Detach from Parent should promote a Child to the Parent's level without changing its world transform.")
	application.component_dialog.set_meta("asset_id", "asset_1")
	application.component_dialog.set_meta("parent_component_id", "component_1")
	application.component_dialog.set_meta("draw_mode", "primitive")
	application.component_dialog.set_meta("source_asset_id", "")
	application.component_semantic_picker.configure(application.semantic_registry.get("semantics", []), "cloak", ["eyebrow_left", "eye_left", "eyebrow_right", "eye_right"])
	application._confirm_component_creation()
	var pupil_component: Dictionary = application._get_component(application._get_asset("asset_1"), application.selected_component_id)
	_expect(str(pupil_component.get("parent_component_id", "")) == "component_1" and str(pupil_component.get("draw_mode", "")) == "primitive" and pupil_component.get("points", []).is_empty() and pupil_component.get("edges", []).is_empty() and pupil_component.get("chains", []).is_empty() and pupil_component.get("primitive", {}).is_empty(), "Primitive Child creation should create an empty Primitive Component without generated Bézier topology.")
	application._on_primitive_placed(Vector2(0.25, -0.5), 2.5)
	_expect(PrimitiveGeometryService.has_circle(pupil_component) and is_equal_approx(float(pupil_component.get("primitive", {}).get("diameter_cm", 0.0)), 2.5) and PrimitiveGeometryService.center(pupil_component).is_equal_approx(Vector2(0.25, -0.5)), "Circle placement should persist only its parametric center and diameter.")
	_expect(application.DRAW_MODES == ["closed_loop", "ribbon", "primitive"], "Components should expose only Closed Loop, Ribbon, and Primitive draw modes.")
	var primitive_sampling := GeometrySamplingService.generate(pupil_component)
	var refined_primitive_sampling := GeometrySamplingService.generate(pupil_component, {"parameters": {"spacing": 0.01, "feature_detail": 0.5}})
	_expect(bool(primitive_sampling.get("valid", false)) and int(primitive_sampling.get("sample_count", 0)) >= 4 and int(primitive_sampling.get("sample_count", 0)) != PrimitiveGeometryService.CIRCLE_MESH_SEGMENTS and int(refined_primitive_sampling.get("sample_count", 0)) > int(primitive_sampling.get("sample_count", 0)) and pupil_component.get("points", []).is_empty(), "Primitive sampling should adapt analytically to the recipe without storing Bézier topology or using a fixed mesh segment count.")
	application._on_primitive_center_changed(Vector2(0.5, -0.25))
	_expect(PrimitiveGeometryService.center(pupil_component).is_equal_approx(Vector2(0.5, -0.25)), "The Primitive center handle should move the parametric center without changing its Component pivot.")
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
	_expect(MotionAssetPreview._world_offset_to_preview(Vector2(2.0, 3.0), 4.0) == Vector2(8.0, -12.0), "Animation Preview should map PolyTools' Y-up world coordinates to Y-down screen coordinates.")
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
	_expect(Vector2(path_document["topology"]["points"][0]["position"]) != Vector2(99.0, 99.0), "MotionPathWorkspace must render an immutable document copy rather than mutating World topology.")
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
	_expect(serialized.get("parameters", {}).get("direction", null) is Array and int(serialized.get("schema_version", 0)) == 39, "Act persistence should serialize vectors as JSON arrays using schema 39.")
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
	_expect(str(act.get("name", "")) == "Slide Right", "MotionActWorkspace must render immutable Act copies and never mutate World documents.")
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
	create_section.setup("Create", ["Character", "Props", "Terrain", "Icon", "Symbols"], true)
	var create_separator_count := 0
	for child in create_section.content_list.get_children():
		if child is ColorRect:
			create_separator_count += 1
	_expect(create_separator_count == 0 and create_section.content_list.get_child_count() == 5, "Create should contain Character, Props, Terrain, Icon, and Symbols.")
	create_section._toggle()
	_expect(create_section.expanded, "Product categories should remain expanded when their headers are pressed.")
	create_section.free()
	var geometry_section := ModuleSection.new()
	geometry_section.setup("Mesh", ["Sampling", "Seeding", "Meshing"], true)
	_expect(geometry_section.content_list.get_child_count() == 3, "Mesh should expose Sampling, Seeding, and Meshing module entries.")
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
