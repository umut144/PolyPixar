extends SceneTree

var failures := 0
var view_signals_emitted: Dictionary = {}
var view_signal_argument_failures: Array[String] = []


func _init() -> void:
	_test_add_close_and_validate()
	_test_delete_edge_opens_closed_loop_draft()
	_test_delete_exactly_one_point()
	_test_fuse_point()
	_test_endpoint_connection_history()
	_test_delete_multiple_points_and_protect_closed_minimum()
	_test_ids_are_not_reused()
	_test_insert_preserves_curve()
	_test_component_draw_modes_and_continuation()
	_test_drawn_handle_direction_and_dead_zone()
	_test_closed_loop_selection_mirror()
	_test_contour_stroke_mesh()
	_test_closed_contour_region_mesh()
	_test_catch_parent_snapping()
	_test_background_point_snapping_without_grid()
	_test_parent_point_snapping_to_child()
	_test_parent_point_snapping_to_primitive_child()
	_test_pivot_point_snapping_without_grid()
	_test_canvas_navigation_key_reset()
	_test_pivot_shortcut_robustness()
	_test_contour_rotation_spinbox()
	_test_contour_stroke_service()
	_test_contour_stroke_robust_geometry()
	_test_world_contour_settings()
	_test_frame_guide_ui()
	_test_component_scale_rebase()
	_test_asset_scale_rebase()
	_test_asset_authored_facing()
	_test_multi_component_inspector()
	_test_multi_component_deletion()
	_test_outliner_selection_wiring()
	_test_inspector_field_wiring()
	_test_geometry_outliner_rows()
	_test_render_invalidation()
	_test_atomic_document_writes()
	_test_geometry_document_history_isolation()
	_test_geometry_sampling_service()
	_test_geometry_sampling_corner_balancing()
	_test_geometry_auto_build_service()
	_test_geometry_auto_build_regression_corpus()
	_test_create_outliner_expansion_scope()
	_test_geometry_sampling_ui_shell()
	_test_geometry_seeding_service()
	_test_geometry_meshing_service_and_ui()
	_test_geometry_uv_mapping_service_and_legacy_records()
	_test_geometry_sdf_service_and_legacy_records()
	_test_component_names()
	_test_component_clipboard()
	_test_asset_catalog_service()
	_test_runtime_export_service()
	_test_runtime_export_file_service()
	_test_runtime_export_surface()
	_test_runtime_export_view_wiring()
	_test_weighting_service_and_ui()
	_test_component_hierarchy_model()
	_test_group_outliner_workflows()
	_test_asset_guides()
	_test_motion_selection_context()
	_test_motion_player()
	_test_motion_sampler()
	_test_motion_asset_preview_geometry()
	_test_motion_resource_shells()
	_test_motion_path_topology_and_sampler()
	_test_outliner_wiring()
	_test_geometry_inspector_wiring()
	_test_create_inspector_wiring()
	_test_style_inspector_wiring()
	_test_sampling_input_kind_from_seeding_selection()
	_test_motion_inspector_wiring()
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


func _cross_chain_fuse_fixture(selected_at_start: bool, nearest_at_start: bool, selected_mode := "free") -> Dictionary:
	var selected := {"id": "selected", "position": Vector2.ZERO, "mode": selected_mode, "preserve_point": false, "handle_source": "manual", "handle_in": Vector2(-0.8, 0.2), "handle_out": Vector2(0.6, -0.3)}
	var selected_neighbor := {"id": "selected_neighbor", "position": Vector2(-2.0, 0.0), "mode": "linear", "preserve_point": false, "handle_source": "auto", "handle_in": Vector2.ZERO, "handle_out": Vector2.ZERO}
	var nearest := {"id": "nearest", "position": Vector2(0.0, 0.00005), "mode": "free", "preserve_point": false, "handle_source": "manual", "handle_in": Vector2(-0.2, 0.4), "handle_out": Vector2(0.3, 0.5)}
	var nearest_neighbor := {"id": "nearest_neighbor", "position": Vector2(2.0, 0.0), "mode": "linear", "preserve_point": false, "handle_source": "auto", "handle_in": Vector2.ZERO, "handle_out": Vector2.ZERO}
	var selected_ids := ["selected", "selected_neighbor"] if selected_at_start else ["selected_neighbor", "selected"]
	var nearest_ids := ["nearest", "nearest_neighbor"] if nearest_at_start else ["nearest_neighbor", "nearest"]
	var component := {
		"points": [selected, selected_neighbor, nearest, nearest_neighbor],
		"edges": [],
		"chains": [
			{"id": "selected_chain", "point_ids": selected_ids, "edge_ids": [], "closed": false},
			{"id": "nearest_chain", "point_ids": nearest_ids, "edge_ids": [], "closed": false}
		]
	}
	BezierTopology.rebuild_chain_edges(component, component["chains"][0])
	BezierTopology.rebuild_chain_edges(component, component["chains"][1])
	return component


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _runtime_export_world_transform(components_by_id: Dictionary, component_id: String) -> Transform2D:
	var component: Dictionary = components_by_id.get(component_id, {})
	var transform: Dictionary = component.get("local_transform", {})
	var position_data: Array = transform.get("position", [])
	var pivot_data: Array = [0.0, 0.0]
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


func _inspector_controls(root: Node, out: Array) -> void:
	if root.is_queued_for_deletion():
		return
	out.append(root)
	for child in root.get_children():
		_inspector_controls(child, out)


func _inspector_control_after(application: Control, label_text: String, type_name: String) -> Node:
	# Finds the control that belongs to a caption, whether the two sit side by
	# side in a grid or stacked in the Inspector column.
	var controls: Array = []
	_inspector_controls(application.inspector_content, controls)
	var seen_label := false
	for control in controls:
		if not seen_label:
			if control is Label and str(control.text) == label_text:
				seen_label = true
			continue
		if control.get_class() == type_name or control.is_class(type_name):
			return control
	return null


func _edit_inspector_value(field: SpinBox, value: float) -> void:
	# Setting SpinBox.value programmatically does not emit value_changed in
	# Godot 4 — only real input does — so an edit is simulated by doing both.
	field.set_value_no_signal(value)
	field.value_changed.emit(value)


func _inspector_label_starting_with(application: Control, prefix: String) -> Label:
	var controls: Array = []
	_inspector_controls(application.inspector_content, controls)
	for control in controls:
		if control is Label and str(control.text).begins_with(prefix):
			return control
	return null


func _inspector_option(application: Control, first_item_text: String) -> OptionButton:
	# Inspector dropdowns sit under section headers rather than captions, so they
	# are identified by their first entry, which is unique per dropdown.
	var controls: Array = []
	_inspector_controls(application.inspector_content, controls)
	for control in controls:
		if control is OptionButton and control.item_count > 0 and str(control.get_item_text(0)) == first_item_text:
			return control
	return null


func _choose_option(option: OptionButton, index: int) -> void:
	# A click both moves the selection and emits item_selected; the handlers read
	# the index they are given, so the test drives the signal.
	option.select(index)
	option.item_selected.emit(index)


func _inspector_toggle(application: Control, text: String) -> Button:
	var controls: Array = []
	_inspector_controls(application.inspector_content, controls)
	for control in controls:
		if (control is CheckButton or control is CheckBox) and str(control.text) == text:
			return control
	return null


func _press_inspector_toggle(toggle: Button, pressed: bool) -> void:
	# The boolean counterpart of _edit_inspector_value: set the state without a
	# signal and emit it, so the test drives exactly what a click drives.
	toggle.set_pressed_no_signal(pressed)
	toggle.toggled.emit(pressed)


func _inspector_spin(application: Control, label_text: String) -> SpinBox:
	var control := _inspector_control_after(application, label_text, "SpinBox")
	return control as SpinBox


func _outliner_button(application: Control, prefix: String) -> Button:
	return _button_starting_with(application.outliner_view, prefix)


func _button_starting_with(root: Node, prefix: String) -> Button:
	# Rendering clears the previous rows with queue_free, which only takes effect
	# at the end of a frame. Detached from the tree no frame ever ends, so rows
	# from earlier renders are still children here and must be skipped.
	if root.is_queued_for_deletion():
		return null
	if root is Button and str(root.text).begins_with(prefix):
		return root
	for child in root.get_children():
		var match := _button_starting_with(child, prefix)
		if match != null:
			return match
	return null


func _press_outliner_button(application: Control, prefix: String) -> bool:
	# Presses the row the Outliner actually built, so the test covers the
	# wiring between the row and its handler, not just the handler.
	var button := _outliner_button(application, prefix)
	if button == null:
		return false
	button.pressed.emit()
	return true


func _button_with_text(root: Node, expected_text: String) -> Button:
	if root is Button and str(root.text) == expected_text:
		return root
	for child in root.get_children():
		var match := _button_with_text(child, expected_text)
		if match != null:
			return match
	return null


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


func _test_delete_edge_opens_closed_loop_draft() -> void:
	var component := _component()
	component["draw_mode"] = "closed_loop"
	for position in [Vector2.ZERO, Vector2(4.0, 0.0), Vector2(4.0, 4.0), Vector2(0.0, 4.0)]:
		BezierTopology.add_point(component, position, "corner")
	BezierTopology.close_active_chain(component)
	var chain: Dictionary = component["chains"][0]
	var removed_edge_id := str(chain["edge_ids"][2])
	var point_ids_before: Array = chain["point_ids"].duplicate()
	var deleted := BezierTopology.delete_edges(component, [removed_edge_id])
	var opened_chain: Dictionary = component["chains"][0]
	var expected_open_order := [point_ids_before[3], point_ids_before[0], point_ids_before[1], point_ids_before[2]]
	_expect(deleted == [removed_edge_id], "Deleting a selected closed-chain Edge should report that Edge as deleted.")
	_expect(not bool(opened_chain.get("closed", true)) and opened_chain.get("point_ids", []).size() == point_ids_before.size(), "Deleting a closed-chain Edge should open the Chain without deleting Points.")
	_expect(opened_chain.get("point_ids", []) == expected_open_order, "The opened Chain should start after the deleted Edge and retain the direction of every surviving Edge.")
	_expect(component.get("edges", []).size() == point_ids_before.size() - 1 and opened_chain.get("edge_ids", []).size() == point_ids_before.size() - 1, "An opened Chain should retain every non-deleted Edge.")
	_expect(str(component.get("draw_mode", "")) == "closed_loop", "Opening a Closed Loop by deleting an Edge must retain its authoring mode.")
	_expect(BezierTopology.validate(component).is_empty(), "An opened Closed Loop draft should retain valid structural topology.")


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


func _test_fuse_point() -> void:
	var component := _component()
	component["draw_mode"] = "closed_loop"
	var first_id := BezierTopology.add_point(component, Vector2(-2.5, 15.0), "corner")
	BezierTopology.add_point(component, Vector2(0.0, 13.5), "corner")
	BezierTopology.add_point(component, Vector2(2.5, 15.0), "corner")
	var duplicate_id := BezierTopology.add_point(component, Vector2(-2.5, 15.00005), "corner")
	var first_point := BezierTopology.point_by_id(component.get("points", []), first_id)
	var duplicate_point := BezierTopology.point_by_id(component.get("points", []), duplicate_id)
	first_point.merge({"mode": "free", "handle_source": "manual", "handle_in": Vector2.ZERO, "handle_out": Vector2(0.4, -0.2)}, true)
	duplicate_point.merge({"mode": "free", "handle_source": "manual", "handle_in": Vector2(-0.3, 0.25), "handle_out": Vector2.ZERO}, true)
	var result := BezierTopology.fuse_point(component, first_id)
	_expect(bool(result.get("fused", false)) and str(result.get("removed_point_id", "")) == duplicate_id, "Fuse Point should remove the nearest coincident Point.")
	_expect(component.get("points", []).size() == 3 and component.get("chains", []).size() == 1 and bool(component["chains"][0].get("closed", false)), "Fusing coincident open endpoints should close the Chain.")
	_expect(Vector2(first_point.get("handle_in", Vector2.ZERO)).is_equal_approx(Vector2(-0.3, 0.25005)) and Vector2(first_point.get("handle_out", Vector2.ZERO)).is_equal_approx(Vector2(0.4, -0.2)), "Same-Chain Fuse should rebase the removed Point's absolute control while retaining both manual curve sides at the closed seam.")
	_expect(BezierTopology.mode_validation_issues(component, true).is_empty(), "A fused Closed Loop should remain valid.")
	var distant := _component()
	var distant_id := BezierTopology.add_point(distant, Vector2.ZERO, "linear")
	BezierTopology.add_point(distant, Vector2(0.001, 0.0), "linear")
	_expect(not bool(BezierTopology.fuse_point(distant, distant_id).get("fused", false)), "Fuse Point must reject points outside its safe tolerance.")

	var mirrored_source := _component()
	mirrored_source["draw_mode"] = "closed_loop"
	var mirrored_source_ids: Array[String] = []
	for point_position in [Vector2(-0.1, 2.0), Vector2(-1.0, 1.0), Vector2(-0.1, 0.0)]:
		mirrored_source_ids.append(BezierTopology.add_point(mirrored_source, point_position, "linear"))
	var mirrored_result := SelectionMirrorService.apply(mirrored_source, mirrored_source_ids, Vector2(0.0, -1.0), Vector2(0.0, 3.0))
	var mirrored_component: Dictionary = mirrored_result.get("component", {})
	var mirrored_ids: Array = mirrored_result.get("mirrored_point_ids", [])
	_expect(bool(mirrored_result.get("valid", false)) and mirrored_component.get("chains", []).size() == 2, "A non-coincident Mirror should provide two valid open Chains for the cross-Chain Fuse regression.")
	var source_top_id := str(mirrored_source_ids[0])
	var mirrored_top_id := str(mirrored_ids.back())
	var interior_rejection := mirrored_component.duplicate(true)
	var interior_id := str(mirrored_ids[1])
	BezierTopology.point_by_id(interior_rejection.get("points", []), interior_id)["position"] = BezierTopology.point_by_id(interior_rejection.get("points", []), source_top_id).get("position", Vector2.ZERO)
	var interior_result := BezierTopology.fuse_point(interior_rejection, source_top_id)
	_expect(not bool(interior_result.get("fused", false)) and str(interior_result.get("reason", "")) == "Points in different Chains must both be open endpoints." and interior_rejection.get("chains", []).size() == 2, "Cross-Chain Fuse must reject an endpoint-to-interior match without changing either Chain.")
	var source_top := BezierTopology.point_by_id(mirrored_component.get("points", []), source_top_id)
	var mirrored_top := BezierTopology.point_by_id(mirrored_component.get("points", []), mirrored_top_id)
	mirrored_top["position"] = source_top.get("position", Vector2.ZERO)
	source_top.merge({"mode": "free", "handle_source": "manual", "handle_in": Vector2.ZERO, "handle_out": Vector2(0.25, -0.1)}, true)
	mirrored_top.merge({"mode": "free", "handle_source": "manual", "handle_in": Vector2(-0.2, 0.3), "handle_out": Vector2.ZERO}, true)
	var cross_chain_result := BezierTopology.fuse_point(mirrored_component, source_top_id)
	_expect(bool(cross_chain_result.get("fused", false)) and mirrored_component.get("chains", []).size() == 1 and not bool(mirrored_component["chains"][0].get("closed", true)), "Fusing coincident endpoints from separate Mirror Chains should join them into one open Chain.")
	var joined_point_ids: Array = mirrored_component["chains"][0].get("point_ids", [])
	_expect(joined_point_ids.size() == 5 and joined_point_ids.count(source_top_id) == 1 and BezierTopology.validate(mirrored_component).is_empty(), "Cross-Chain Fuse must keep one canonical Point identity without duplicating it in the joined Chain.")
	_expect(Vector2(source_top.get("handle_in", Vector2.ZERO)).is_equal_approx(Vector2(0.25, -0.1)) and Vector2(source_top.get("handle_out", Vector2.ZERO)).is_equal_approx(Vector2(-0.2, 0.3)), "Cross-Chain Fuse should preserve the active manual controls from both endpoint orientations at the joined seam.")
	_expect(BezierTopology.close_chain(mirrored_component, str(mirrored_component["chains"][0].get("id", ""))) and BezierTopology.mode_validation_issues(mirrored_component, true).is_empty(), "The remaining Mirror endpoints should close normally after a cross-Chain Fuse.")

	for selected_at_start in [false, true]:
		for nearest_at_start in [false, true]:
			var orientation_component := _cross_chain_fuse_fixture(selected_at_start, nearest_at_start)
			var orientation_selected := BezierTopology.point_by_id(orientation_component.get("points", []), "selected")
			var orientation_nearest := BezierTopology.point_by_id(orientation_component.get("points", []), "nearest")
			var expected_in: Vector2 = orientation_selected.get("handle_out" if selected_at_start else "handle_in", Vector2.ZERO)
			var nearest_handle_key := "handle_out" if nearest_at_start else "handle_in"
			var expected_out := Vector2(orientation_nearest.get("position", Vector2.ZERO)) + Vector2(orientation_nearest.get(nearest_handle_key, Vector2.ZERO)) - Vector2(orientation_selected.get("position", Vector2.ZERO))
			var orientation_result := BezierTopology.fuse_point(orientation_component, "selected")
			_expect(bool(orientation_result.get("fused", false)) and orientation_component.get("chains", []).size() == 1 and BezierTopology.validate(orientation_component).is_empty(), "Cross-Chain Fuse should preserve valid topology for selected-start=%s and nearest-start=%s." % [selected_at_start, nearest_at_start])
			_expect(Vector2(orientation_selected.get("handle_in", Vector2.ZERO)).is_equal_approx(expected_in) and Vector2(orientation_selected.get("handle_out", Vector2.ZERO)).is_equal_approx(expected_out), "Cross-Chain Fuse should preserve and rebase the correct directed controls for selected-start=%s and nearest-start=%s." % [selected_at_start, nearest_at_start])

	for selected_mode in ["linear", "free", "mirrored", "aligned"]:
		var mode_component := _cross_chain_fuse_fixture(false, true, selected_mode)
		var mode_selected := BezierTopology.point_by_id(mode_component.get("points", []), "selected")
		var original_in_length := Vector2(mode_selected.get("handle_in", Vector2.ZERO)).length()
		var mode_result := BezierTopology.fuse_point(mode_component, "selected")
		var fused_in: Vector2 = mode_selected.get("handle_in", Vector2.ZERO)
		var fused_out: Vector2 = mode_selected.get("handle_out", Vector2.ZERO)
		_expect(bool(mode_result.get("fused", false)) and BezierTopology.validate(mode_component).is_empty(), "Cross-Chain Fuse should remain structurally valid for %s Points." % selected_mode)
		if selected_mode == "linear":
			_expect(fused_in == Vector2.ZERO and fused_out == Vector2.ZERO, "Linear Fuse Points must retain zero Handles.")
		elif selected_mode == "free":
			_expect(fused_in.is_equal_approx(Vector2(-0.8, 0.2)) and fused_out.is_equal_approx(Vector2(0.3, 0.50005)), "Free Fuse Points should preserve both independent authored controls.")
		elif selected_mode == "mirrored":
			_expect(fused_in.is_equal_approx(-fused_out), "Mirrored Fuse Points must retain equal and opposite Handles.")
		else:
			_expect(is_equal_approx(fused_in.length(), original_in_length) and absf(fused_in.normalized().dot(fused_out.normalized()) + 1.0) < 0.000001, "Aligned Fuse Points must retain the existing opposite length on one shared tangent.")

	var non_adjacent := _component()
	var non_adjacent_ids: Array[String] = []
	for point_position in [Vector2(-2.0, 0.0), Vector2.ZERO, Vector2(2.0, 0.0), Vector2(0.0, 0.00005), Vector2(4.0, 0.0)]:
		non_adjacent_ids.append(BezierTopology.add_point(non_adjacent, point_position, "linear"))
	var non_adjacent_original := non_adjacent.duplicate(true)
	var non_adjacent_result := BezierTopology.fuse_point(non_adjacent, non_adjacent_ids[1])
	_expect(not bool(non_adjacent_result.get("fused", true)) and str(non_adjacent_result.get("reason", "")).contains("same Chain") and non_adjacent == non_adjacent_original, "Same-Chain Fuse must reject spatially coincident non-neighbours without changing topology.")

	var adjacent := _component()
	var adjacent_ids: Array[String] = []
	for point_position in [Vector2(-2.0, 0.0), Vector2.ZERO, Vector2(0.0, 0.00005), Vector2(2.0, 0.0)]:
		adjacent_ids.append(BezierTopology.add_point(adjacent, point_position, "linear"))
	var adjacent_result := BezierTopology.fuse_point(adjacent, adjacent_ids[1])
	_expect(bool(adjacent_result.get("fused", false)) and adjacent.get("points", []).size() == 3 and not bool(adjacent.get("chains", [])[0].get("closed", true)) and BezierTopology.validate(adjacent).is_empty(), "Adjacent Same-Chain Points should still collapse into one Point on a valid open Chain.")

	var closed_wrap := _component()
	var closed_wrap_ids: Array[String] = []
	for point_position in [Vector2.ZERO, Vector2(2.0, 0.0), Vector2(2.0, 2.0), Vector2(0.0, 0.00005)]:
		closed_wrap_ids.append(BezierTopology.add_point(closed_wrap, point_position, "linear"))
	BezierTopology.close_active_chain(closed_wrap)
	var closed_wrap_result := BezierTopology.fuse_point(closed_wrap, closed_wrap_ids[0])
	_expect(bool(closed_wrap_result.get("fused", false)) and closed_wrap.get("points", []).size() == 3 and bool(closed_wrap.get("chains", [])[0].get("closed", false)) and BezierTopology.validate(closed_wrap).is_empty(), "The last and first Points of a closed Chain should remain cyclic neighbours that can be fused safely.")

	var minimum_closed := _component()
	var minimum_closed_ids: Array[String] = []
	for point_position in [Vector2.ZERO, Vector2(2.0, 0.0), Vector2(0.0, 0.00005)]:
		minimum_closed_ids.append(BezierTopology.add_point(minimum_closed, point_position, "linear"))
	BezierTopology.close_active_chain(minimum_closed)
	var minimum_closed_original := minimum_closed.duplicate(true)
	var minimum_closed_result := BezierTopology.fuse_point(minimum_closed, minimum_closed_ids[0])
	_expect(not bool(minimum_closed_result.get("fused", true)) and minimum_closed == minimum_closed_original, "Same-Chain Fuse must not reduce a closed Chain below its three-Point structural minimum.")

	var two_point_open := _component()
	var two_point_open_ids := [BezierTopology.add_point(two_point_open, Vector2.ZERO, "linear"), BezierTopology.add_point(two_point_open, Vector2(0.0, 0.00005), "linear")]
	var two_point_open_original := two_point_open.duplicate(true)
	var two_point_open_result := BezierTopology.fuse_point(two_point_open, two_point_open_ids[0])
	_expect(not bool(two_point_open_result.get("fused", true)) and two_point_open == two_point_open_original, "Same-Chain Fuse must not collapse a two-Point open Chain into an unusable single-Point Chain.")

	var overlapping_chains := _component()
	overlapping_chains["points"] = [{"id": "shared", "position": Vector2.ZERO}, {"id": "left", "position": Vector2.LEFT}, {"id": "right", "position": Vector2.RIGHT}]
	overlapping_chains["chains"] = [{"id": "left_chain", "point_ids": ["left", "shared"], "edge_ids": [], "closed": false}, {"id": "right_chain", "point_ids": ["shared", "right"], "edge_ids": [], "closed": false}]
	BezierTopology.rebuild_chain_edges(overlapping_chains, overlapping_chains["chains"][0])
	BezierTopology.rebuild_chain_edges(overlapping_chains, overlapping_chains["chains"][1])
	_expect(not BezierTopology.join_open_chain_endpoints(overlapping_chains, "left", "right") and overlapping_chains.get("chains", []).size() == 2 and not BezierTopology.validate(overlapping_chains).is_empty(), "Joining Chains that already share a Point ID must be rejected and structural validation must expose the cross-Chain ownership violation.")


func _test_endpoint_connection_history() -> void:
	var application: Control = load("res://scripts/main.gd").new()
	var status_label := Label.new()
	application.program_status_label = status_label
	var overlapping := _component()
	overlapping.merge({"id": "overlapping", "name": "overlapping", "draw_mode": "closed_loop"}, true)
	overlapping["points"] = [{"id": "shared", "position": Vector2.ZERO}, {"id": "left", "position": Vector2.LEFT}, {"id": "right", "position": Vector2.RIGHT}]
	overlapping["chains"] = [{"id": "left_chain", "point_ids": ["left", "shared"], "edge_ids": [], "closed": false}, {"id": "right_chain", "point_ids": ["shared", "right"], "edge_ids": [], "closed": false}]
	BezierTopology.rebuild_chain_edges(overlapping, overlapping["chains"][0])
	BezierTopology.rebuild_chain_edges(overlapping, overlapping["chains"][1])
	application.assets = [{"id": "endpoint_asset", "name": "Endpoint Asset", "components": [overlapping], "guides": []}] as Array[Dictionary]
	application.selected_asset_id = "endpoint_asset"
	application.selected_component_id = "overlapping"
	application._on_bezier_endpoint_connection_requested("left", "right")
	_expect(application.undo_history.is_empty() and overlapping.get("chains", []).size() == 2 and status_label.text.contains("could not be connected"), "A rejected Canvas endpoint connection should explain the failure without adding an empty Undo snapshot.")

	var joinable := _component()
	joinable.merge({"id": "joinable", "name": "joinable", "draw_mode": "closed_loop"}, true)
	joinable["points"] = [{"id": "a0", "position": Vector2.LEFT}, {"id": "a1", "position": Vector2.ZERO}, {"id": "b0", "position": Vector2.ZERO}, {"id": "b1", "position": Vector2.RIGHT}]
	joinable["chains"] = [{"id": "a_chain", "point_ids": ["a0", "a1"], "edge_ids": [], "closed": false}, {"id": "b_chain", "point_ids": ["b0", "b1"], "edge_ids": [], "closed": false}]
	BezierTopology.rebuild_chain_edges(joinable, joinable["chains"][0])
	BezierTopology.rebuild_chain_edges(joinable, joinable["chains"][1])
	application.assets = [{"id": "endpoint_asset", "name": "Endpoint Asset", "components": [joinable], "guides": []}] as Array[Dictionary]
	application.selected_component_id = "joinable"
	application._on_bezier_endpoint_connection_requested("a1", "b0")
	var snapshot_component: Dictionary = {}
	if not application.undo_history.is_empty():
		snapshot_component = application.undo_history[0].get("assets", [])[0].get("components", [])[0]
	_expect(application.undo_history.size() == 1 and joinable.get("chains", []).size() == 1 and snapshot_component.get("chains", []).size() == 2, "A successful Canvas endpoint connection should record exactly one pre-mutation Undo snapshot.")
	status_label.free()
	application.free()


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
	var contour_reset := _component()
	contour_reset["draw_mode"] = "contour"
	var contour_ids: Array[String] = [BezierTopology.add_point(contour_reset, Vector2.ZERO, "linear"), BezierTopology.add_point(contour_reset, Vector2.ONE, "linear")]
	BezierTopology.delete_points(contour_reset, contour_ids)
	_expect(contour_reset.get("chains", []).is_empty() and not BezierTopology.add_point(contour_reset, Vector2(2.0, 0.0), "linear").is_empty(), "A Contour should be drawable again after its full open Chain was deleted.")


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
	ribbon["draw_mode"] = "contour"
	var first_id := BezierTopology.start_chain(ribbon, Vector2.ZERO, "linear")
	var second_id := BezierTopology.add_point_from(ribbon, first_id, Vector2(2.0, 0.0), "linear")
	var prepended_id := BezierTopology.add_point_from(ribbon, first_id, Vector2(-1.0, 0.0), "linear")
	_expect(not second_id.is_empty() and not prepended_id.is_empty(), "Contour drawing should continue from either selected endpoint.")
	_expect(ribbon.get("chains", []).size() == 1 and BezierTopology.mode_validation_issues(ribbon, true).is_empty(), "Contour must validate as exactly one open Chain with at least two Points.")
	_expect(BezierTopology.start_chain(ribbon, Vector2(20.0, 20.0), "linear").is_empty(), "A Contour must reject a second Chain.")
	var closed_contour := ribbon.duplicate(true)
	BezierTopology.add_point_from(closed_contour, second_id, Vector2(2.0, 2.0), "linear")
	BezierTopology.close_active_chain(closed_contour)
	_expect(BezierTopology.mode_validation_issues(closed_contour, true).is_empty(), "Contour must also accept one closed Chain with at least three Points.")
	var closed := ribbon.duplicate(true)
	closed["draw_mode"] = "closed_loop"
	_expect(not BezierTopology.mode_validation_issues(closed, true).is_empty(), "Closed Loop must reject open topology.")
	_expect(BezierTopology.mode_validation_issues(ribbon, true).is_empty(), "Contour must accept one complete open Chain.")
	var application = load("res://scripts/main.gd").new()
	var preserved_topology := closed_contour.duplicate(true)
	var original_points: Array = preserved_topology.get("points", []).duplicate(true)
	var original_edges: Array = preserved_topology.get("edges", []).duplicate(true)
	var original_chains: Array = preserved_topology.get("chains", []).duplicate(true)
	_expect(application._apply_component_draw_mode(preserved_topology, "closed_loop") and preserved_topology.get("points", []) == original_points and preserved_topology.get("edges", []) == original_edges and preserved_topology.get("chains", []) == original_chains, "The Draw Mode menu should switch Contour and Closed Loop without rewriting Bezier topology.")
	_expect(not application._apply_component_draw_mode(preserved_topology, "primitive") and str(preserved_topology.get("draw_mode", "")) == "closed_loop", "The Draw Mode menu must reject implicit conversion of authored Bezier topology to a Primitive.")
	var empty_component := _component()
	empty_component["draw_mode"] = "contour"
	_expect(application._apply_component_draw_mode(empty_component, "primitive") and str(empty_component.get("geometry_source", "")) == "primitive" and empty_component.get("primitive", null) is Dictionary, "An empty Bezier Component should switch safely to an empty Primitive source.")
	_expect(application._apply_component_draw_mode(empty_component, "contour") and str(empty_component.get("geometry_source", "")) == "bezier" and not empty_component.has("primitive"), "An empty Primitive Component should switch safely back to a Bezier source.")
	var authored_primitive := {"draw_mode": "primitive", "geometry_source": "primitive", "primitive": {"type": "circle", "center": Vector2.ZERO, "diameter_cm": 5.0}, "points": [], "edges": [], "chains": []}
	_expect(not application._apply_component_draw_mode(authored_primitive, "contour") and str(authored_primitive.get("draw_mode", "")) == "primitive", "The Draw Mode menu must preserve authored analytic Primitive geometry instead of silently discarding it.")
	application.free()


func _test_drawn_handle_direction_and_dead_zone() -> void:
	var contour := _component()
	contour["draw_mode"] = "contour"
	BezierTopology.add_point(contour, Vector2(-15.2, 41.65), "aligned")
	var first_id := BezierTopology.add_point(contour, Vector2(-14.2, 42.8), "aligned")
	var second_id := BezierTopology.add_point_from(contour, first_id, Vector2(-13.1, 43.6), "aligned", Vector2(-0.035749, -0.021011))
	var second := BezierTopology.point_by_id(contour.get("points", []), second_id)
	_expect(str(second.get("handle_source", "")) == "manual" and Vector2(second.get("handle_in", Vector2.ZERO)).dot(Vector2(-14.2, 42.8) - Vector2(-13.1, 43.6)) > 0.0 and Vector2(second.get("handle_out", Vector2.ZERO)).dot(Vector2(-13.1, 43.6) - Vector2(-14.2, 42.8)) > 0.0, "Drawing an Aligned Point must orient its incoming and outgoing Handles with the authored Chain direction instead of creating a local reversal.")
	BezierTopology.add_point_from(contour, second_id, Vector2(-11.9, 43.9), "aligned")
	var stroke := ContourStrokeService.generate(contour)
	_expect(bool(stroke.get("valid", false)), "The Crown-like reversed placement gesture must be normalized before it can create overlapping Contour Stroke centerline segments.")

	var prepended := _component()
	prepended["draw_mode"] = "contour"
	BezierTopology.add_point(prepended, Vector2.ZERO, "aligned")
	BezierTopology.add_point(prepended, Vector2(10.0, 0.0), "aligned")
	var prepended_id := BezierTopology.add_point_from(prepended, str(prepended.get("chains", [])[0].get("point_ids", [])[0]), Vector2(-10.0, 0.0), "mirrored", Vector2(-2.0, 0.0))
	var prepended_point := BezierTopology.point_by_id(prepended.get("points", []), prepended_id)
	_expect(Vector2(prepended_point.get("handle_out", Vector2.ZERO)).x > 0.0 and Vector2(prepended_point.get("handle_in", Vector2.ZERO)).x < 0.0, "Prepending a drawn Mirrored Point must orient its outgoing Handle toward the existing Chain.")
	var free_contour := _component()
	BezierTopology.add_point(free_contour, Vector2.ZERO, "free")
	var free_id := BezierTopology.add_point(free_contour, Vector2(10.0, 0.0), "free", Vector2(-2.0, 1.0))
	var free_point := BezierTopology.point_by_id(free_contour.get("points", []), free_id)
	_expect(Vector2(free_point.get("handle_out", Vector2.ZERO)) == Vector2(-2.0, 1.0), "Intentional Free Handle placement must retain its exact authored direction instead of applying Smooth-point normalization.")

	var canvas := ComponentCanvas.new()
	canvas.size = Vector2(400.0, 400.0)
	canvas.set_camera_state(Vector2.ZERO, 20.0)
	canvas.set_component_transform({"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO})
	canvas.active_tool = "point"
	canvas.draw_point_mode = "aligned"
	canvas._begin_draw_pointer(Vector2(100.0, 100.0))
	canvas._update_pending_draw_handle(Vector2(107.0, 100.0))
	_expect(canvas.pending_draw_has_handle, "An intentional Point drag beyond the release dead zone should author manual Handles.")
	canvas._update_pending_draw_handle(Vector2(102.0, 100.0))
	_expect(not canvas.pending_draw_has_handle and canvas.pending_draw_handle_out == Vector2.ZERO, "Returning inside the release dead zone must cancel a briefly crossed Handle drag instead of latching an accidental manual Handle.")
	canvas.free()


func _test_closed_loop_selection_mirror() -> void:
	var activation_component := _component()
	activation_component["draw_mode"] = "closed_loop"
	var activation_ids: Array[String] = []
	for point_position in [Vector2(-2.0, 1.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0)]:
		activation_ids.append(BezierTopology.add_point(activation_component, point_position, "linear"))
	var activation_application: Control = load("res://scripts/main.gd").new()
	activation_application.selected_point_ids = activation_ids
	_expect(activation_application._can_activate_selection_mirror(activation_component), "Mirror activation should validate only selection topology before the user has chosen an axis.")
	_expect(not SelectionMirrorService.validation_issues(activation_component, activation_ids, Vector2.ZERO, Vector2.RIGHT).is_empty(), "Mirror preview should still reject an interior Point after the chosen axis makes it coincident.")
	activation_application.free()

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
	var inner_axis_component := _component()
	inner_axis_component["draw_mode"] = "closed_loop"
	var inner_axis_ids: Array[String] = []
	for point_position in [Vector2(-1.0, 0.0), Vector2(0.0, 2.0), Vector2(-1.0, 4.0)]:
		inner_axis_ids.append(BezierTopology.add_point(inner_axis_component, point_position, "linear"))
	var inner_axis_original := inner_axis_component.duplicate(true)
	var inner_axis_preview := SelectionMirrorService.preview(inner_axis_component, inner_axis_ids, mirror_axis_start, mirror_axis_end)
	var inner_axis_result := SelectionMirrorService.apply(inner_axis_component, inner_axis_ids, mirror_axis_start, mirror_axis_end)
	_expect(not bool(inner_axis_preview.get("valid", true)) and "Points on the mirror axis must be open Chain endpoints." in inner_axis_preview.get("errors", []), "Mirror preview should explain why an interior source Point cannot lie on the mirror axis.")
	_expect(not bool(inner_axis_result.get("valid", true)) and inner_axis_result.get("component", {}).is_empty(), "Mirror apply should reject an interior axis Point instead of sharing its ID across source and mirrored Chains.")
	_expect(inner_axis_component == inner_axis_original, "Rejecting an interior mirror-axis Point must leave the authored Component unchanged.")
	var multi_coincident_component := _component()
	multi_coincident_component["draw_mode"] = "closed_loop"
	var multi_source_ids: Array[String] = []
	for point_position in [Vector2(0.0, 0.0), Vector2(-1.0, 1.0), Vector2(-1.0, 3.0), Vector2(0.0, 4.0)]:
		multi_source_ids.append(BezierTopology.add_point(multi_coincident_component, point_position, "linear"))
	var multi_result := SelectionMirrorService.apply(multi_coincident_component, multi_source_ids, mirror_axis_start, mirror_axis_end)
	var multi_mirror: Dictionary = multi_result.get("component", {})
	_expect(int(multi_result.get("auto_connected_count", 0)) == 2 and multi_mirror.get("points", []).size() == 6, "Mirror should fuse both coincident axis endpoints and remove their duplicate Points.")
	_expect(multi_mirror.get("chains", []).size() == 1 and bool(multi_mirror["chains"][0].get("closed", false)) and BezierTopology.mode_validation_issues(multi_mirror, true).is_empty(), "Multiple coincident axis endpoints should produce one valid closed Mirror Chain.")
	var curved_component := _component()
	curved_component["draw_mode"] = "closed_loop"
	var curved_ids: Array[String] = []
	for point_position in [Vector2(0.0, 0.0), Vector2(-2.0, 1.0), Vector2(-2.0, 3.0), Vector2(0.0, 4.0)]:
		curved_ids.append(BezierTopology.add_point(curved_component, point_position, "aligned"))
	var curved_points: Array = curved_component.get("points", [])
	for point_data in curved_points:
		point_data["handle_source"] = "manual"
	BezierTopology.point_by_id(curved_points, curved_ids[0])["handle_out"] = Vector2(-0.8, 0.2)
	BezierTopology.point_by_id(curved_points, curved_ids[1])["handle_in"] = Vector2(0.6, -0.2)
	BezierTopology.point_by_id(curved_points, curved_ids[1])["handle_out"] = Vector2(-0.3, 0.7)
	BezierTopology.point_by_id(curved_points, curved_ids[2])["handle_in"] = Vector2(-0.2, -0.5)
	BezierTopology.point_by_id(curved_points, curved_ids[2])["handle_out"] = Vector2(0.5, 0.4)
	BezierTopology.point_by_id(curved_points, curved_ids[3])["handle_in"] = Vector2(-0.7, -0.1)
	var curved_result := SelectionMirrorService.apply(curved_component, curved_ids, mirror_axis_start, mirror_axis_end)
	var curved_mirror: Dictionary = curved_result.get("component", {})
	var top_axis_point := BezierTopology.point_by_id(curved_mirror.get("points", []), curved_ids[0])
	var bottom_axis_point := BezierTopology.point_by_id(curved_mirror.get("points", []), curved_ids[3])
	var reversed_source_point := BezierTopology.point_by_id(curved_mirror.get("points", []), curved_ids[1])
	var reflected_source_position := Vector2(2.0, 1.0)
	var reflected_source_point: Dictionary = {}
	for point_data in curved_mirror.get("points", []):
		if Vector2(point_data.get("position", Vector2.ZERO)).is_equal_approx(reflected_source_position):
			reflected_source_point = point_data
			break
	_expect(Vector2(top_axis_point.get("handle_in", Vector2.ZERO)).is_equal_approx(Vector2(-0.8, 0.2)) and Vector2(top_axis_point.get("handle_out", Vector2.ZERO)).is_equal_approx(Vector2(0.8, 0.2)), "Mirror closure should preserve both directed Handles at the first axis endpoint.")
	_expect(Vector2(bottom_axis_point.get("handle_in", Vector2.ZERO)).is_equal_approx(Vector2(0.7, -0.1)) and Vector2(bottom_axis_point.get("handle_out", Vector2.ZERO)).is_equal_approx(Vector2(-0.7, -0.1)), "Mirror closure should preserve both directed Handles at the last axis endpoint.")
	_expect(Vector2(reversed_source_point.get("handle_in", Vector2.ZERO)).is_equal_approx(Vector2(-0.3, 0.7)) and Vector2(reversed_source_point.get("handle_out", Vector2.ZERO)).is_equal_approx(Vector2(0.6, -0.2)), "Reversing the source Chain during Mirror should swap every Point's incoming and outgoing Handles.")
	_expect(not reflected_source_point.is_empty() and Vector2(reflected_source_point.get("handle_in", Vector2.ZERO)).is_equal_approx(Vector2(-0.6, -0.2)) and Vector2(reflected_source_point.get("handle_out", Vector2.ZERO)).is_equal_approx(Vector2(0.3, 0.7)), "Reversing the reflected Chain during Mirror should retain its directed cubic controls.")


func _test_contour_stroke_mesh() -> void:
	var contour := _component()
	contour["draw_mode"] = "contour"
	BezierTopology.add_point(contour, Vector2.ZERO, "linear")
	BezierTopology.add_point(contour, Vector2(4.0, 0.0), "linear")
	BezierTopology.add_point(contour, Vector2(8.0, 3.0), "linear")
	BezierTopology.add_point(contour, Vector2(11.0, 5.0), "linear")
	var first := ContourMeshService.generate(contour)
	var second := ContourMeshService.generate(contour)
	_expect(bool(first.get("valid", false)), "A complete Contour Component should generate a Contour Stroke Mesh.")
	_expect(int(first.get("vertex_count", 0)) >= 8 and int(first.get("triangle_count", 0)) >= 4, "Contour Stroke should create centered segment quads and explicit joins.")
	_expect(str(first.get("method", "")) == ContourMeshService.METHOD and JSON.stringify(first) == JSON.stringify(second), "Contour Stroke output must be deterministic.")
	_expect(ContourMeshService.matches_source(first, contour), "Contour Stroke Mesh should match its source Component.")
	_expect(is_equal_approx(float(first.get("parameters", {}).get("stroke_width_px", 0.0)), 4.0) and is_equal_approx(float(first.get("parameters", {}).get("stroke_width_meters", 0.0)), 0.020833333333333332), "Open Contours should use the fixed 4 px World default without a Component-local width.")
	_expect(str(first.get("parameters", {}).get("join", "")) == "miter" and str(first.get("parameters", {}).get("cap", "")) == "butt", "Open Contours should use the same Miter/Butt art-stroke semantics as closed contours.")
	var interrupted_contour := contour.duplicate(true)
	interrupted_contour["edges"][1]["render_outline"] = false
	var interrupted_stroke := ContourStrokeService.generate(interrupted_contour)
	_expect(bool(interrupted_stroke.get("valid", false)) and int(interrupted_stroke.get("outline_run_count", 0)) == 2 and interrupted_stroke.get("runs", [])[0].get("edge_ids", []).size() == 1 and interrupted_stroke.get("runs", [])[1].get("edge_ids", []).size() == 1, "A hidden middle Edge must split an open Contour into two ordered Butt-capped runs without wrapping its endpoints.")
	contour["points"][1]["position"] += Vector2(0.25, 0.0)
	_expect(not ContourMeshService.matches_source(first, contour), "Changing the authored Contour centerline must make the previous Mesh stale.")
	var hidden_contour := contour.duplicate(true)
	for edge in hidden_contour["edges"]:
		edge["render_outline"] = false
	var hidden_result := ContourMeshService.generate(hidden_contour)
	_expect(bool(hidden_result.get("valid", false)) and not bool(hidden_result.get("has_outline", true)) and hidden_result.get("vertices", []).is_empty() and hidden_result.get("triangles", []).is_empty(), "A permanently disabled Render Outline must remain an explicit valid no-outline Bake without fallback geometry.")
	_expect(not ContourMeshService.matches_source(first, hidden_contour), "Changing Render Outline flags must invalidate an accepted Contour Stroke Mesh.")
	var closed := _component()
	closed["draw_mode"] = "closed_loop"
	for position in [Vector2.ZERO, Vector2(4.0, 0.0), Vector2(4.0, 3.0), Vector2(0.0, 3.0)]:
		BezierTopology.add_point(closed, position, "linear")
	BezierTopology.close_active_chain(closed)
	var closed_stroke := ContourMeshService.generate(closed)
	_expect(bool(closed_stroke.get("valid", false)) and bool(closed_stroke.get("source_chain_closed", false)) and bool(closed_stroke.get("has_outline", false)), "Closed Fill Components must derive a separate centered Contour Stroke Bake from their authored Boundary.")
	var closed_contour := closed.duplicate(true)
	closed_contour["draw_mode"] = "contour"
	var closed_contour_stroke := ContourMeshService.generate(closed_contour)
	_expect(bool(closed_contour_stroke.get("valid", false)) and bool(closed_contour_stroke.get("source_chain_closed", false)) and bool(closed_contour_stroke.get("has_outline", false)), "Closed Contours must produce a closed Stroke without requiring Fill geometry.")
	var ellipse := {"draw_mode": "primitive", "primitive": {"type": PrimitiveGeometryService.ELLIPSE, "center": Vector2(1.0, 2.0), "diameter_x_cm": 20.0, "diameter_y_cm": 5.0}, "points": [], "edges": [], "chains": []}
	var ellipse_stroke := ContourMeshService.generate(ellipse)
	_expect(bool(ellipse_stroke.get("valid", false)) and str(ellipse_stroke.get("source_draw_mode", "")) == "primitive" and int(ellipse_stroke.get("triangle_count", 0)) > 0 and ellipse_stroke == ContourMeshService.generate(ellipse), "Analytic Circles and Ellipses must derive deterministic centered Stroke Bakes without persisted polygon topology.")
	var application = load("res://scripts/main.gd").new()
	var legacy_document: Dictionary = WorldDocumentService.default_geometry_document("asset_legacy", "component_legacy")
	var legacy_bake: Dictionary = first.duplicate(true)
	legacy_bake["method"] = GeometryMeshingService.RIBBON_STRIP
	legacy_bake["algorithm_version"] = 0
	legacy_bake["bake_id"] = "legacy_ribbon_bake"
	legacy_document["component_mesh"] = {"bake_id": "legacy_ribbon_bake", "method": GeometryMeshingService.RIBBON_STRIP, "mesh_fingerprint": "legacy"}
	legacy_document["meshing"]["bakes"] = {GeometryMeshingService.RIBBON_STRIP: legacy_bake}
	var normalized_legacy: Dictionary = WorldDocumentService.normalize_geometry_document(legacy_document, "asset_legacy", "component_legacy")
	_expect(normalized_legacy.get("meshing", {}).get("bakes", {}).has(GeometryMeshingService.RIBBON_STRIP) and str(normalized_legacy.get("component_mesh", {}).get("method", "")) == GeometryMeshingService.RIBBON_STRIP, "Legacy Ribbon Strip Bakes should remain readable records without being relabeled as current Contour Stroke Bakes.")
	var contour_document: Dictionary = WorldDocumentService.default_geometry_document("asset_contour", "component_contour")
	var persisted_contour: Dictionary = first.duplicate(true)
	persisted_contour["bake_id"] = "contour_bake"
	contour_document["component_mesh"] = {"bake_id": "contour_bake", "method": ContourMeshService.METHOD, "mesh_fingerprint": GeometryUVMappingService.mesh_fingerprint(persisted_contour)}
	contour_document["meshing"]["bakes"] = {ContourMeshService.METHOD: persisted_contour}
	var contour_round_trip: Dictionary = WorldDocumentService.normalize_geometry_document(WorldDocumentService.serialize_geometry_document(contour_document), "asset_contour", "component_contour")
	var restored_contour: Dictionary = contour_round_trip.get("meshing", {}).get("bakes", {}).get(ContourMeshService.METHOD, {})
	_expect(restored_contour.get("vertices", [])[0].has("edge_id") and restored_contour.get("runs", [])[0].get("centerline", [])[0].get("position", null) is Vector2, "Contour Mesh JSON persistence must retain typed Edge/curve provenance and restore Run centerlines as vectors.")
	_expect(str(restored_contour.get("geometry_diagnostics", {}).get("triangle_validation", "")) == "complete", "Contour Mesh persistence must retain robust geometry diagnostics as typed engine-neutral data.")
	application.free()


func _test_closed_contour_region_mesh() -> void:
	var convex := _component()
	convex.merge({"id": "convex_contour", "name": "convex_contour", "type": "component", "draw_mode": "contour", "visibility": true, "z_index": 0, "parent_component_id": "", "transform": {"position": Vector2.ZERO, "pivot": Vector2(2.0, 3.0), "rotation": 0.0, "scale": Vector2.ONE}})
	for position in [Vector2.ZERO, Vector2(10.0, 0.0), Vector2(10.0, 10.0), Vector2(0.0, 10.0)]:
		BezierTopology.add_point(convex, position, "linear")
	BezierTopology.close_active_chain(convex)
	var convex_bake := ContourMeshService.generate(convex)
	var repeated_bake := ContourMeshService.generate(convex)
	var convex_region: Dictionary = convex_bake.get("closed_region", {})
	_expect(bool(convex_bake.get("valid", false)) and bool(convex_region.get("valid", false)) and int(convex_region.get("vertex_count", 0)) == 4 and int(convex_region.get("triangle_count", 0)) == 2, "A convex closed Contour should derive a non-empty two-triangle geometric region.")
	_expect(convex_region == repeated_bake.get("closed_region", {}), "Closed Contour region triangulation must be deterministic for identical authored topology.")
	var direct_stroke := ContourStrokeService.generate(convex)
	_expect(convex_bake.get("vertices", []).size() == direct_stroke.get("vertices", []).size() and convex_bake.get("triangles", []).size() == int(direct_stroke.get("triangle_count", 0)), "The closed region must remain separate from and must not replace the visible Contour Stroke Mesh.")

	var concave := _component()
	concave["draw_mode"] = "contour"
	for position in [Vector2.ZERO, Vector2(10.0, 0.0), Vector2(10.0, 10.0), Vector2(5.0, 4.0), Vector2(0.0, 10.0)]:
		BezierTopology.add_point(concave, position, "linear")
	BezierTopology.close_active_chain(concave)
	var concave_region: Dictionary = ClosedRegionMeshService.generate(concave)
	_expect(bool(concave_region.get("valid", false)) and int(concave_region.get("triangle_count", 0)) == 3 and is_equal_approx(float(concave_region.get("boundary_area_tool_units_squared", 0.0)), 70.0), "A concave simple closed Contour should triangulate completely without a convex fallback.")
	var monk_eye_area_twice := 0.999040603637696
	var monk_eye_rounding_difference_twice := 0.000001915614120662212
	var monk_eye_tolerance := ClosedRegionMeshService._area_tolerance(monk_eye_area_twice, 22)
	_expect(monk_eye_tolerance >= monk_eye_rounding_difference_twice and monk_eye_tolerance < 0.0001, "Closed-region area certification should accept the measured Monk-eye triangulation rounding error while retaining a tightly bounded tolerance.")

	var hidden := convex.duplicate(true)
	hidden["edges"][1]["render_outline"] = false
	var hidden_bake := ContourMeshService.generate(hidden)
	var fully_hidden := convex.duplicate(true)
	for edge in fully_hidden["edges"]:
		edge["render_outline"] = false
	var fully_hidden_bake := ContourMeshService.generate(fully_hidden)
	_expect(bool(hidden_bake.get("valid", false)) and hidden_bake.get("closed_region", {}) == convex_region and fully_hidden_bake.get("closed_region", {}) == convex_region, "Hidden Stroke sections must not alter the complete authored closed region.")
	_expect(not bool(fully_hidden_bake.get("has_outline", true)) and fully_hidden_bake.get("vertices", []).is_empty(), "A fully hidden Stroke must stay visibly empty while its independent closed region remains available for Runtime export.")

	var open_contour := _component()
	open_contour["draw_mode"] = "contour"
	for position in [Vector2.ZERO, Vector2(10.0, 0.0), Vector2(10.0, 10.0), Vector2(0.0, 10.0)]:
		BezierTopology.add_point(open_contour, position, "linear")
	var open_bake := ContourMeshService.generate(open_contour)
	_expect(bool(open_bake.get("valid", false)) and not open_bake.has("closed_region"), "An open Contour must not derive a closed region.")

	var crossing := _component()
	crossing["draw_mode"] = "contour"
	for position in [Vector2.ZERO, Vector2(10.0, 10.0), Vector2(0.0, 10.0), Vector2(10.0, 0.0)]:
		BezierTopology.add_point(crossing, position, "linear")
	BezierTopology.close_active_chain(crossing)
	var crossing_bake := ContourMeshService.generate(crossing)
	_expect(not bool(crossing_bake.get("valid", true)) and "simple loops" in " ".join(crossing_bake.get("errors", [])), "A self-intersecting closed Contour must block region and Stroke baking with a concrete validation error.")
	var repeated_points := _component()
	repeated_points["draw_mode"] = "contour"
	for position in [Vector2.ZERO, Vector2.ZERO, Vector2(10.0, 0.0)]:
		BezierTopology.add_point(repeated_points, position, "linear")
	BezierTopology.close_active_chain(repeated_points)
	_expect("at least three unique points" in " ".join(ClosedRegionMeshService.generate(repeated_points).get("errors", [])), "A closed region with fewer than three unique Boundary points must fail explicitly.")
	var area_less := _component()
	area_less["draw_mode"] = "contour"
	for position in [Vector2.ZERO, Vector2(10.0, 0.0), Vector2(20.0, 0.0)]:
		BezierTopology.add_point(area_less, position, "linear")
	BezierTopology.close_active_chain(area_less)
	_expect("area-less" in " ".join(ClosedRegionMeshService.generate(area_less).get("errors", [])), "A practically area-less closed Boundary must fail explicitly.")
	var non_finite := convex.duplicate(true)
	non_finite["points"][0]["position"] = Vector2(INF, 0.0)
	_expect("non-finite" in " ".join(ClosedRegionMeshService.generate(non_finite).get("errors", [])), "Non-finite closed Boundary coordinates must fail before adaptive sampling or triangulation.")

	var stale_source := convex_bake.duplicate(true)
	convex["points"][0]["handle_source"] = "manual"
	convex["points"][0]["handle_out"] = Vector2(1.0, 0.5)
	_expect(not ContourMeshService.matches_source(stale_source, convex), "Point and Bezier-handle changes must stale the accepted closed region through Contour build provenance.")

	var export_component := convex.duplicate(true)
	export_component["points"][0]["handle_source"] = "auto"
	export_component["points"][0]["handle_out"] = Vector2.ZERO
	var export_bake := ContourMeshService.generate(export_component)
	var export_asset := {"id": "region_asset", "name": "Region Asset", "asset_type": "character", "visibility": true, "asset_pivot": Vector2.ZERO, "components": [export_component], "guides": []}
	var export_result := RuntimeExportService.build_manifest(export_asset, {"convex_contour": {"contour_stroke": export_bake}})
	var exported_component: Dictionary = export_result.get("manifest", {}).get("components", [])[0] if bool(export_result.get("valid", false)) else {}
	var exported_region: Dictionary = exported_component.get("closed_region_mesh", {})
	_expect(bool(export_result.get("valid", false)) and int(export_result.get("manifest", {}).get("schema_version", 0)) == 16 and str(exported_region.get("role", "")) == "closed_contour_region" and not exported_region.get("indices", []).is_empty(), "Schema 16 must export a non-empty closed_region_mesh for a valid closed Contour.")
	_expect(exported_region.keys().size() == 3 and exported_region.has("role") and exported_region.has("vertices") and exported_region.has("indices") and not exported_region.has("material") and not exported_component.has("mesh"), "closed_region_mesh must contain only engine-neutral geometry and must not introduce a Contour Fill Mesh.")
	_expect(exported_region.get("vertices", [])[0] == [-0.2, -0.30000000000000004], "Closed region vertices must subtract the authored Component pivot and convert Tool units to meters.")
	_expect(RuntimeExportService.manifest_validation_issues(export_result.get("manifest", {})).is_empty(), "A generated schema-16 Runtime Manifest must pass strict validation.")
	var old_schema_manifest: Dictionary = export_result.get("manifest", {}).duplicate(true)
	old_schema_manifest["schema_version"] = 10
	_expect(not RuntimeExportService.manifest_validation_issues(old_schema_manifest).is_empty(), "Runtime validation must strictly reject an older Runtime Manifest schema.")
	var styled_manifest: Dictionary = export_result.get("manifest", {}).duplicate(true)
	styled_manifest["components"][0]["closed_region_mesh"]["material"] = "forbidden"
	_expect(not RuntimeExportService.manifest_validation_issues(styled_manifest).is_empty(), "Runtime validation must reject render or material fields in closed_region_mesh.")
	var degenerate_manifest: Dictionary = export_result.get("manifest", {}).duplicate(true)
	degenerate_manifest["components"][0]["closed_region_mesh"]["indices"] = [0, 0, 1]
	_expect("degenerate triangle indices" in " ".join(RuntimeExportService.manifest_validation_issues(degenerate_manifest)), "Runtime validation must reject degenerate closed-region triangle indices.")
	var missing_region_bake: Dictionary = export_bake.duplicate(true)
	missing_region_bake.erase("closed_region")
	var missing_region_export := RuntimeExportService.build_manifest(export_asset, {"convex_contour": {"contour_stroke": missing_region_bake}})
	_expect(not bool(missing_region_export.get("valid", true)) and "Closed Contour Region Mesh is required" in " ".join(missing_region_export.get("errors", [])), "A closed Contour with missing derived region geometry must explicitly block Runtime export.")

	var rebased := _component()
	rebased.merge({"id": "rebased_contour", "name": "rebased_contour", "type": "component", "draw_mode": "contour", "visibility": true, "z_index": 0, "parent_component_id": "", "transform": {"position": Vector2.ZERO, "pivot": Vector2.ZERO, "rotation": 0.0, "scale": Vector2(2.0, 0.5)}})
	for position in [Vector2.ZERO, Vector2(10.0, 0.0), Vector2(10.0, 10.0), Vector2(0.0, 10.0)]:
		BezierTopology.add_point(rebased, position, "linear")
	BezierTopology.close_active_chain(rebased)
	var rebased_asset := {"id": "rebased_region_asset", "name": "Rebased Region Asset", "asset_type": "character", "visibility": true, "asset_pivot": Vector2.ZERO, "components": [rebased], "guides": []}
	var rebase_result := ComponentScaleRebaseService.rebase_asset(rebased_asset)
	var normalized_rebased := ComponentHierarchy.component_by_id(rebased_asset, "rebased_contour")
	var rebased_bake := ContourMeshService.generate(normalized_rebased)
	var rebased_export := RuntimeExportService.build_manifest(rebased_asset, {"rebased_contour": {"contour_stroke": rebased_bake}})
	var rebased_vertices: Array = rebased_export.get("manifest", {}).get("components", [])[0].get("closed_region_mesh", {}).get("vertices", []) if bool(rebased_export.get("valid", false)) else []
	var rebased_max := Vector2.ZERO
	for vertex in rebased_vertices:
		rebased_max.x = maxf(rebased_max.x, float(vertex[0]))
		rebased_max.y = maxf(rebased_max.y, float(vertex[1]))
	_expect(bool(rebase_result.get("valid", false)) and bool(rebased_export.get("valid", false)) and rebased_max.is_equal_approx(Vector2(2.0, 0.5)), "Scale Rebase must be reflected exactly in the exported closed region while normalized Component Scale stays one.")

	var application = load("res://scripts/main.gd").new()
	var runtime_manifest_text := JSON.stringify(export_result.get("manifest", {}), "\t")
	_expect(application._runtime_manifest_text_matches(runtime_manifest_text, runtime_manifest_text), "Runtime package staging must strictly accept the generated schema-16 closed-region payload after JSON round-trip.")
	var document: Dictionary = WorldDocumentService.default_geometry_document("region_asset", "convex_contour")
	export_bake["bake_id"] = "closed_region_bake"
	document["meshing"]["bakes"] = {ContourMeshService.METHOD: export_bake}
	var restored: Dictionary = WorldDocumentService.normalize_geometry_document(WorldDocumentService.serialize_geometry_document(document), "region_asset", "convex_contour").get("meshing", {}).get("bakes", {}).get(ContourMeshService.METHOD, {})
	_expect(restored.get("closed_region", {}).get("vertices", [])[0].get("position", null) is Vector2 and restored.get("closed_region", {}).get("triangles", []).size() == export_bake.get("closed_region", {}).get("triangles", []).size(), "Closed region Bake geometry and provenance must survive Geometry document persistence.")
	application.free()


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


func _test_background_point_snapping_without_grid() -> void:
	var canvas := ComponentCanvas.new()
	canvas.size = Vector2(400.0, 400.0)
	canvas.set_camera_state(Vector2.ZERO, 20.0)
	canvas.set_component_transform({"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO})
	canvas.set_snap_settings(false, 16.0, 15.0)
	canvas.set_reference_shapes([{
		"id": "background", "transform": {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO},
		"bezier_points": [{"id": "target", "position": Vector2(10.0, 5.0)}], "visibility": true
	}])
	var snapped := canvas.snap_position(Vector2(10.15, 5.1))
	_expect(snapped.distance_to(Vector2(10.0, 5.0)) < 0.01, "No Snap should still align the active Component to a visible background point.")
	_expect(canvas.snap_position(Vector2(10.8, 5.8)).distance_to(Vector2(10.8, 5.8)) < 0.01, "No Snap should leave positions outside the point hit radius untouched.")
	canvas.free()


func _test_parent_point_snapping_to_child() -> void:
	var parent := _component()
	parent.merge({"id": "parent", "name": "parent", "type": "component", "parent_component_id": "", "visibility": true, "transform": {"position": Vector2(10.0, -4.0), "rotation": 90.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}})
	parent["points"] = [{"id": "parent_point", "position": Vector2.ZERO, "mode": "linear", "handle_in": Vector2.ZERO, "handle_out": Vector2.ZERO}]
	var child := _component()
	child.merge({"id": "child", "name": "child", "type": "component", "parent_component_id": "parent", "visibility": true, "transform": {"position": Vector2(5.0, 0.0), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}})
	child["points"] = [{"id": "child_point", "position": Vector2(2.0, 0.0), "mode": "linear", "handle_in": Vector2.ZERO, "handle_out": Vector2.ZERO}]
	var asset := {"id": "asset", "name": "Asset", "asset_type": "character", "visibility": true, "asset_pivot": Vector2.ZERO, "components": [parent, child], "groups": [], "guides": []}
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	application.assets = [asset] as Array[Dictionary]
	application.selected_asset_id = "asset"
	application.selected_component_id = "parent"
	application.active_module = "Create"
	application.active_state = "edit"
	application.active_edit_mode = "point"
	application._render_canvas_context()
	application.canvas_view.set_snap_settings(false, 16.0, 15.0)
	application._on_bezier_points_move_started(["parent_point"])
	var near_child_delta := ComponentHierarchy.world_transform(asset, "parent").basis_xform(Vector2(7.2, 0.1))
	application._on_bezier_points_moved(["parent_point"], near_child_delta)
	_expect(Vector2(parent["points"][0].get("position", Vector2.ZERO)).distance_to(Vector2(7.0, 0.0)) < 0.01, "An existing Parent point should snap to a visible Child point through the composed hierarchy transform even when Grid Snap is disabled.")
	application.free()


func _test_parent_point_snapping_to_primitive_child() -> void:
	var parent := _component()
	parent.merge({"id": "parent", "name": "parent", "type": "component", "parent_component_id": "", "visibility": true, "transform": {"position": Vector2(10.0, -4.0), "rotation": 90.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}})
	parent["points"] = [{"id": "parent_point", "position": Vector2.ZERO, "mode": "linear", "handle_in": Vector2.ZERO, "handle_out": Vector2.ZERO}]
	var child := _component()
	child.merge({"id": "child", "name": "child", "type": "component", "parent_component_id": "parent", "visibility": true, "draw_mode": "primitive", "primitive": {"type": "circle", "center": Vector2(2.0, 0.0), "diameter_cm": 20.0}, "points": [], "edges": [], "chains": [], "transform": {"position": Vector2(5.0, 0.0), "rotation": 0.0, "scale": Vector2(2.0, 0.5), "pivot": Vector2(2.0, 0.0)}})
	var asset := {"id": "asset", "name": "Asset", "asset_type": "character", "visibility": true, "asset_pivot": Vector2.ZERO, "components": [parent, child], "groups": [], "guides": []}
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	application.assets = [asset] as Array[Dictionary]
	application.selected_asset_id = "asset"
	application.selected_component_id = "parent"
	application.active_module = "Create"
	application.active_state = "edit"
	application.active_edit_mode = "point"
	application._render_canvas_context()
	application.canvas_view.set_snap_settings(false, 16.0, 15.0)
	application._on_bezier_points_move_started(["parent_point"])
	var near_child_delta := ComponentHierarchy.world_transform(asset, "parent").basis_xform(Vector2(7.05, 0.01))
	application._on_bezier_points_moved(["parent_point"], near_child_delta)
	var snapped_position: Vector2 = parent["points"][0].get("position", Vector2.ZERO)
	_expect(snapped_position.distance_to(Vector2(7.0, 0.0)) < 0.01, "An existing Parent point should snap to a visible derived Primitive Child contour point even when Grid Snap is disabled (actual: %s)." % snapped_position)
	application.free()


func _test_pivot_point_snapping_without_grid() -> void:
	var canvas := ComponentCanvas.new()
	canvas.size = Vector2(400.0, 400.0)
	canvas.set_camera_state(Vector2.ZERO, 20.0)
	canvas.set_context("Contour")
	canvas.set_interaction_state("transform")
	canvas.set_component_transform({"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO})
	canvas.set_bezier_geometry([{"id": "drawn", "position": Vector2(3.0, 2.0)}], [], [])
	canvas.set_snap_settings(false, 16.0, 15.0)
	var near_point_screen := canvas._world_to_screen(Vector2(3.2, 2.1))
	_expect(canvas._place_pivot_at_screen_position(near_point_screen), "A selected Contour Pivot should be placeable in Transform state.")
	_expect(Vector2(canvas.component_transform.get("pivot", Vector2.ZERO)).is_equal_approx(Vector2(3.0, 2.0)), "No Snap should still align a Component Pivot to one of its authored points.")
	_expect(Vector2(canvas.component_transform.get("position", Vector2.ZERO)).is_equal_approx(Vector2(3.0, 2.0)), "Snapping the Pivot must compensate Component Position so the authored geometry stays visually fixed.")
	canvas.free()


func _test_contour_rotation_spinbox() -> void:
	var contour := _component()
	contour.merge({"id": "contour", "name": "Contour", "type": "component", "draw_mode": "contour", "visibility": true, "z_index": 0, "parent_component_id": "", "transform": {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}})
	var asset := {"id": "asset", "name": "Asset", "asset_type": "character", "visibility": true, "asset_pivot": Vector2.ZERO, "components": [contour], "groups": [], "guides": []}
	var application = load("res://scripts/main.gd").new()
	application._build_ui()
	var contour_assets: Array[Dictionary] = [asset]
	application.assets = contour_assets
	application.selected_asset_id = "asset"
	application.selected_component_id = "contour"
	application.active_module = "Create"
	application.active_create_submodule = "Character"
	application._render_inspector()
	var rotation_field: SpinBox = application.create_inspector_view.transform_fields.get("rotation")
	_expect(is_instance_valid(rotation_field) and is_equal_approx(rotation_field.step, 1.0) and is_equal_approx(rotation_field.custom_arrow_step, 1.0), "Component Rotation arrows should always count in exact one-degree steps.")
	if is_instance_valid(rotation_field):
		rotation_field.value += rotation_field.custom_arrow_step
		rotation_field.value_changed.emit(rotation_field.value)
	var updated_contour: Dictionary = application._get_component(application._get_asset("asset"), "contour")
	_expect(is_equal_approx(float(updated_contour.get("transform", {}).get("rotation", 0.0)), 1.0), "Changing the Contour Rotation SpinBox should update its authored transform.")
	_expect(is_equal_approx(float(application.canvas_view.component_transform.get("rotation", 0.0)), 1.0), "Changing the Contour Rotation SpinBox should immediately rotate the Canvas geometry around its Pivot.")
	application.free()


func _test_canvas_navigation_key_reset() -> void:
	var canvas := ComponentCanvas.new()
	var press_s := InputEventKey.new()
	press_s.keycode = KEY_S
	press_s.pressed = true
	canvas._update_navigation_input(press_s)
	_expect(canvas._navigation_input_vector() == Vector3(0.0, -1.0, 0.0), "Holding S should pan downward through the Canvas-owned navigation state.")
	canvas._clear_navigation_input()
	_expect(canvas._navigation_input_vector() == Vector3.ZERO, "Losing Canvas focus must clear a held navigation key so panning cannot continue automatically.")
	var press_w := InputEventKey.new()
	press_w.keycode = KEY_W
	press_w.pressed = true
	canvas._update_navigation_input(press_w)
	var release_w := InputEventKey.new()
	release_w.keycode = KEY_W
	release_w.pressed = false
	canvas._update_navigation_input(release_w)
	_expect(canvas._navigation_input_vector() == Vector3.ZERO, "A navigation Key-Up event must stop Canvas movement immediately.")
	canvas._update_navigation_input(press_s)
	canvas.set_navigation_locked(true)
	_expect(canvas._navigation_input_vector() == Vector3.ZERO, "Locking Canvas navigation must discard any held navigation keys.")
	canvas.free()


func _test_pivot_shortcut_robustness() -> void:
	var canvas := ComponentCanvas.new()
	canvas.size = Vector2(400.0, 400.0)
	canvas.set_context("Body")
	canvas.set_component_transform({"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2(50.0, 50.0)})
	canvas.set_interaction_state("transform")
	_expect(canvas._place_pivot_at_screen_position(Vector2(200.0, 200.0)), "P should set a selected Component Pivot while the Transform state is active.")
	canvas.set_interaction_state("edit")
	_expect(canvas._place_pivot_at_screen_position(Vector2(220.0, 180.0)), "P should set a selected Component Pivot while Bézier Edit is active.")
	canvas.set_interaction_state("draw")
	_expect(not canvas._place_pivot_at_screen_position(Vector2(200.0, 200.0)), "P must not interrupt an active drawing gesture.")
	canvas.set_interaction_state("asset")
	_expect(canvas._place_asset_pivot_at_screen_position(Vector2(240.0, 160.0)), "P should set the Asset Root Pivot when no Component or Group is selected.")
	canvas.free()

	var application = load("res://scripts/main.gd").new()
	var key_p := InputEventKey.new()
	key_p.keycode = KEY_P
	key_p.pressed = true
	_expect(application._is_plain_pivot_shortcut(key_p), "The Pivot shortcut should recognize a non-repeating plain P before focused GUI fields consume it.")
	key_p.echo = true
	_expect(not application._is_plain_pivot_shortcut(key_p), "Key repeat must not create multiple Pivot history changes from one held P key.")
	key_p.echo = false
	key_p.ctrl_pressed = true
	_expect(not application._is_plain_pivot_shortcut(key_p), "Command-modified P must remain available to other editor commands.")
	application.free()


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
	_expect(application._outliner_focus_asset_id() == "symbol_a" and application.outliner_view.asset_is_visible(application.assets[2]), "The Symbols Outliner should retain its own visible expanded Asset.")
	application.active_create_submodule = "Character"
	_expect(application._outliner_focus_asset_id() == "character_b" and application.outliner_view.asset_is_visible(application.assets[1]), "Returning to Characters should restore that module's expanded Asset.")
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


func _test_contour_stroke_service() -> void:
	var component := {
		"id": "wizard_reference",
		"draw_mode": "closed_loop",
		"points": [
			{"id": "tip", "position": Vector2(0.0, -6.0), "mode": "free", "handle_source": "manual", "handle_in": Vector2(-0.8, 1.2), "handle_out": Vector2(0.8, 1.2)},
			{"id": "right", "position": Vector2(5.0, 2.0), "mode": "free", "handle_source": "manual", "handle_in": Vector2(-1.4, -0.4), "handle_out": Vector2(0.2, 1.0)},
			{"id": "brim_right", "position": Vector2(3.5, 4.0), "mode": "corner", "handle_source": "manual", "handle_in": Vector2.ZERO, "handle_out": Vector2.ZERO},
			{"id": "brim_left", "position": Vector2(-3.5, 4.0), "mode": "corner", "handle_source": "manual", "handle_in": Vector2.ZERO, "handle_out": Vector2.ZERO},
			{"id": "left", "position": Vector2(-5.0, 2.0), "mode": "free", "handle_source": "manual", "handle_in": Vector2(-0.2, 1.0), "handle_out": Vector2(1.4, -0.4)}
		],
		"edges": [
			{"id": "edge_tip_right", "start_point_id": "tip", "end_point_id": "right", "render_outline": true},
			{"id": "edge_right_brim", "start_point_id": "right", "end_point_id": "brim_right", "render_outline": true},
			{"id": "edge_brim", "start_point_id": "brim_right", "end_point_id": "brim_left", "render_outline": true},
			{"id": "edge_left_brim", "start_point_id": "brim_left", "end_point_id": "left", "render_outline": true},
			{"id": "edge_left_tip", "start_point_id": "left", "end_point_id": "tip", "render_outline": true}
		],
		"chains": [{"id": "outer", "point_ids": ["tip", "right", "brim_right", "brim_left", "left"], "edge_ids": ["edge_tip_right", "edge_right_brim", "edge_brim", "edge_left_brim", "edge_left_tip"], "closed": true, "topology_role": "outer"}]
	}
	var source_snapshot := component.duplicate(true)
	var stroke := ContourStrokeService.generate(component)
	var repeated := ContourStrokeService.generate(component)
	_expect(bool(stroke.get("valid", false)), "A closed Wizard-like Boundary should generate a centered Contour Stroke mesh.")
	_expect(stroke == repeated, "Contour Stroke generation must be deterministic for identical authored topology.")
	_expect(component == source_snapshot, "Contour Stroke generation must not mutate canonical Component topology.")
	_expect(int(stroke.get("algorithm_version", 0)) == ContourStrokeService.ALGORITHM_VERSION, "Contour Stroke results should expose their algorithm version.")
	_expect(is_equal_approx(float(stroke.get("reference_pixels_per_meter", 0.0)), 192.0), "Contour Stroke should use the fixed authored reference density of 192 px/m.")
	_expect(is_equal_approx(float(stroke.get("stroke_width_px", 0.0)), 4.0) and is_equal_approx(float(stroke.get("stroke_width_meters", 0.0)), 0.020833333333333332), "The 192 px/m default should derive an exact 4 px / 0.0208333 m stroke width.")
	_expect(is_equal_approx(float(stroke.get("centerline_offset_meters", 0.0)), 0.010416666666666666), "The stroke mesh should extend exactly half its width to either side of the authored Boundary.")
	_expect(str(stroke.get("join", "")) == "miter" and is_equal_approx(float(stroke.get("miter_limit", 0.0)), 4.0) and str(stroke.get("cap", "")) == "butt", "Contour Stroke output should state the approved join, fallback limit, and cap semantics.")
	var vertices: Array = stroke.get("vertices", [])
	var indices: PackedInt32Array = stroke.get("indices", PackedInt32Array())
	_expect(not vertices.is_empty() and indices.size() >= 3 and indices.size() % 3 == 0, "Contour Stroke should emit indexed triangle geometry.")
	if vertices.size() >= 2:
		var first_left := Vector2(vertices[0].get("position", Vector2.ZERO))
		var first_right := Vector2(vertices[1].get("position", Vector2.ZERO))
		_expect(is_equal_approx(first_left.distance_to(first_right) * ToolUnits.TO_METERS, 0.020833333333333332), "Each segment quad should remain centered at the exact authored width.")
	var centerline: Array = stroke.get("centerline", [])
	var analytic_maximum_distance := 0.0
	for edge_data in component.get("edges", []):
		var start_point := BezierTopology.point_by_id(component["points"], str(edge_data.get("start_point_id", "")))
		var end_point := BezierTopology.point_by_id(component["points"], str(edge_data.get("end_point_id", "")))
		var controls := BezierGeometry.cubic_controls(start_point, end_point)
		for dense_index in range(129):
			var analytic_position := BezierGeometry.cubic_position(controls, float(dense_index) / 128.0)
			var nearest := INF
			for centerline_index in range(centerline.size()):
				var segment_start := Vector2(centerline[centerline_index].get("position", Vector2.ZERO))
				var segment_end := Vector2(centerline[(centerline_index + 1) % centerline.size()].get("position", Vector2.ZERO))
				nearest = minf(nearest, _distance_to_segment(analytic_position, segment_start, segment_end))
			analytic_maximum_distance = maxf(analytic_maximum_distance, nearest)
	_expect(analytic_maximum_distance * ToolUnits.TO_METERS <= ContourStrokeService.MAX_DEVIATION_PX / ContourStrokeService.REFERENCE_PIXELS_PER_METER + 0.000001, "The sampled centerline must stay within 0.25 reference px of the analytic authored Boundary.")
	_expect(float(stroke.get("certified_max_deviation_meters", INF)) <= ContourStrokeService.MAX_DEVIATION_PX / ContourStrokeService.REFERENCE_PIXELS_PER_METER + 0.000001, "Contour Stroke should report a sampling deviation bound no larger than the approved tolerance.")
	for sample in centerline:
		var edge := BezierTopology.edge_by_id(component["edges"], str(sample.get("edge_id", "")))
		var start_point := BezierTopology.point_by_id(component["points"], str(edge.get("start_point_id", "")))
		var end_point := BezierTopology.point_by_id(component["points"], str(edge.get("end_point_id", "")))
		var analytic := BezierGeometry.cubic_position(BezierGeometry.cubic_controls(start_point, end_point), float(sample.get("curve_t", -1.0)))
		_expect(analytic.distance_to(Vector2(sample.get("position", Vector2.ZERO))) <= 0.000001, "Every centerline sample must retain exact Edge/curve_t provenance on the original Bezier.")
	var hidden_outline := component.duplicate(true)
	hidden_outline["edges"][0]["render_outline"] = false
	var hidden_result := ContourStrokeService.generate(hidden_outline)
	_expect(bool(hidden_result.get("valid", false)) and int(hidden_result.get("outline_run_count", 0)) == 1, "One disabled Edge in a closed Boundary should split the remaining visible Edges into one open outline run.")
	var hidden_run: Dictionary = hidden_result.get("runs", [])[0]
	_expect(not bool(hidden_run.get("closed", true)) and str(hidden_run.get("start_cap", "")) == "butt" and str(hidden_run.get("end_cap", "")) == "butt", "A Render Outline interruption should terminate both ends at explicit butt caps.")
	_expect(hidden_run.get("edge_ids", []) == ["edge_right_brim", "edge_brim", "edge_left_brim", "edge_left_tip"], "A wrapped visible run should retain deterministic canonical Edge ordering after its hidden Edge.")
	var hidden_centerline: Array = hidden_run.get("centerline", [])
	_expect(Vector2(hidden_centerline.front().get("position", Vector2.ZERO)).is_equal_approx(Vector2(component["points"][1].get("position", Vector2.ZERO))) and Vector2(hidden_centerline.back().get("position", Vector2.ZERO)).is_equal_approx(Vector2(component["points"][0].get("position", Vector2.ZERO))), "Butt cap centerlines must stop exactly at the original authored Edge endpoints.")
	var split_outline := component.duplicate(true)
	for split_edge_index in range(split_outline["edges"].size()):
		split_outline["edges"][split_edge_index]["render_outline"] = split_edge_index in [0, 2]
	var split_result := ContourStrokeService.generate(split_outline)
	_expect(bool(split_result.get("valid", false)) and int(split_result.get("outline_run_count", 0)) == 2 and not bool(split_result.get("runs", [])[0].get("closed", true)) and not bool(split_result.get("runs", [])[1].get("closed", true)), "Separated visible Edges should produce two independent open Contour Stroke runs without bridging hidden Boundaries.")
	var single_outline := component.duplicate(true)
	for single_edge in single_outline["edges"]:
		single_edge["render_outline"] = str(single_edge.get("id", "")) == "edge_brim"
	var single_result := ContourStrokeService.generate(single_outline)
	var single_run: Dictionary = single_result.get("runs", [])[0]
	_expect(bool(single_result.get("valid", false)) and int(single_result.get("outline_run_count", 0)) == 1 and int(single_run.get("triangle_count", 0)) == 2 and int(single_run.get("miter_join_count", -1)) == 0 and int(single_run.get("bevel_join_count", -1)) == 0, "One visible straight Edge should produce exactly one centered quad and no joins across its hidden neighbours.")
	var no_outline := component.duplicate(true)
	for hidden_edge in no_outline["edges"]:
		hidden_edge["render_outline"] = false
	var no_outline_result := ContourStrokeService.generate(no_outline)
	_expect(bool(no_outline_result.get("valid", false)) and not bool(no_outline_result.get("has_outline", true)) and no_outline_result.get("vertices", []).is_empty() and no_outline_result.get("indices", PackedInt32Array()).is_empty(), "A fully disabled Render Outline must be a valid permanent no-outline result with no derived geometry.")
	var hole_component := component.duplicate(true)
	hole_component["topology_role"] = "hole"
	hole_component["chains"][0]["topology_role"] = "hole"
	var hole_result := ContourStrokeService.generate(hole_component)
	_expect(bool(hole_result.get("valid", false)) and str(hole_result.get("topology_role", "")) == "hole" and bool(hole_result.get("runs", [])[0].get("closed", false)), "A closed Hole Boundary should generate its own centered closed Contour Stroke with explicit Hole semantics.")
	_expect(hole_result.get("vertices", []).size() == stroke.get("vertices", []).size() and hole_result.get("indices", PackedInt32Array()).size() == stroke.get("indices", PackedInt32Array()).size(), "Outer and Hole roles should not change the centered geometric stroke construction.")
	var sharp_component := _component()
	for sharp_position in [Vector2.ZERO, Vector2(10.0, 0.0), Vector2(0.01, 0.01), Vector2(0.0, 10.0)]:
		BezierTopology.add_point(sharp_component, sharp_position, "linear")
	BezierTopology.close_active_chain(sharp_component)
	var sharp_stroke := ContourStrokeService.generate(sharp_component)
	_expect(bool(sharp_stroke.get("valid", false)) and int(sharp_stroke.get("bevel_join_count", 0)) > 0, "A miter longer than four half-widths should deterministically fall back to a bevel join.")


func _test_contour_stroke_robust_geometry() -> void:
	var concave_contour := _component()
	concave_contour["draw_mode"] = "contour"
	for position in [Vector2.ZERO, Vector2(10.0, 0.0), Vector2(10.0, 10.0)]:
		BezierTopology.add_point(concave_contour, position, "linear")
	var concave_stroke := ContourStrokeService.generate(concave_contour)
	_expect(bool(concave_stroke.get("valid", false)), "A concave open turn should produce a robust centered stroke.")
	_expect(int(concave_stroke.get("miter_join_count", 0)) == 1 and int(concave_stroke.get("bevel_join_count", -1)) == 0, "A regular 90-degree corner should retain its compact miter join.")
	var found_outer_previous := false
	var found_outer_next := false
	for vertex in concave_stroke.get("vertices", []):
		var role := str(vertex.get("role", ""))
		var position := Vector2(vertex.get("position", Vector2.ZERO))
		found_outer_previous = found_outer_previous or (role == "join_outer_previous" and position.is_equal_approx(Vector2(10.0, -0.10416666666666667)))
		found_outer_next = found_outer_next or (role == "join_outer_next" and position.is_equal_approx(Vector2(10.104166666666666, 0.0)))
	_expect(found_outer_previous and found_outer_next, "A positive turn must tessellate its exposed right-side corner, not add hidden overlap on the inner side.")
	var concave_vertices: Array = concave_stroke.get("vertices", [])
	var concave_indices: PackedInt32Array = concave_stroke.get("indices", PackedInt32Array())
	var triangles_are_stable := concave_indices.size() % 3 == 0
	for offset in range(0, concave_indices.size(), 3):
		var a := Vector2(concave_vertices[concave_indices[offset]].get("position", Vector2.ZERO))
		var b := Vector2(concave_vertices[concave_indices[offset + 1]].get("position", Vector2.ZERO))
		var c := Vector2(concave_vertices[concave_indices[offset + 2]].get("position", Vector2.ZERO))
		triangles_are_stable = triangles_are_stable and a.is_finite() and b.is_finite() and c.is_finite() and (b - a).cross(c - a) > ContourStrokeService.GEOMETRY_EPSILON
	_expect(triangles_are_stable and str(concave_stroke.get("geometry_diagnostics", {}).get("triangle_validation", "")) == "complete", "Every emitted Contour Stroke triangle must be finite, non-degenerate, in range, and consistently wound.")

	var shoulder_contour := _component()
	shoulder_contour["draw_mode"] = "contour"
	for position in [Vector2.ZERO, Vector2(-2.95, 9.5), Vector2(0.45, 9.5)]:
		BezierTopology.add_point(shoulder_contour, position, "linear")
	var shoulder_stroke := ContourStrokeService.generate(shoulder_contour)
	_expect(bool(shoulder_stroke.get("valid", false)) and int(shoulder_stroke.get("miter_join_count", -1)) == 0 and int(shoulder_stroke.get("bevel_join_count", 0)) == 1, "A Warrior-shoulder-like acute corner should use the angle-aware bevel fallback before it forms a visible miter spike.")

	var crossing_contour := _component()
	crossing_contour["draw_mode"] = "contour"
	for position in [Vector2(0.0, 0.0), Vector2(10.0, 10.0), Vector2(0.0, 10.0), Vector2(10.0, 0.0)]:
		BezierTopology.add_point(crossing_contour, position, "linear")
	var crossing_stroke := ContourStrokeService.generate(crossing_contour)
	_expect(bool(crossing_stroke.get("valid", false)) and int(crossing_stroke.get("geometry_diagnostics", {}).get("self_intersection_count", 0)) == 1, "An authored open-Contour crossing should remain renderable while reporting its exact self-intersection explicitly.")
	_expect(crossing_stroke == ContourStrokeService.generate(crossing_contour), "Self-intersecting authored Contours must retain deterministic tessellation and diagnostics.")
	var crossing_loop := crossing_contour.duplicate(true)
	crossing_loop["draw_mode"] = "closed_loop"
	BezierTopology.close_active_chain(crossing_loop)
	var crossing_loop_stroke := ContourStrokeService.generate(crossing_loop)
	_expect(not bool(crossing_loop_stroke.get("valid", true)) and "must remain simple loops" in " ".join(crossing_loop_stroke.get("errors", [])), "A self-intersecting closed outer or Hole Boundary must fail explicitly because its fill-side topology is ambiguous.")

	var narrow_contour := _component()
	narrow_contour["draw_mode"] = "contour"
	for position in [Vector2(0.0, 0.0), Vector2(10.0, 0.0), Vector2(10.0, 0.1), Vector2(0.0, 0.1)]:
		BezierTopology.add_point(narrow_contour, position, "linear")
	var narrow_stroke := ContourStrokeService.generate(narrow_contour)
	var narrow_diagnostics: Dictionary = narrow_stroke.get("geometry_diagnostics", {})
	_expect(bool(narrow_stroke.get("valid", false)) and int(narrow_diagnostics.get("self_intersection_count", -1)) == 0 and int(narrow_diagnostics.get("narrow_overlap_pair_count", 0)) > 0, "Wizard-eye-scale narrow features should remain valid and explicitly report stroke-coverage overlap without being mistaken for a Boundary crossing.")
	_expect(is_equal_approx(float(narrow_diagnostics.get("minimum_nonadjacent_clearance_meters", -1.0)), 0.01), "Narrow-feature diagnostics should report deterministic local clearance in meters.")

	var nearby_contour := _component()
	nearby_contour["draw_mode"] = "contour"
	for position in [Vector2(0.0, 0.0), Vector2(10.0, 0.0), Vector2(10.0, 5.0), Vector2(0.0, 5.0)]:
		BezierTopology.add_point(nearby_contour, position, "linear")
	var nearby_stroke := ContourStrokeService.generate(nearby_contour)
	_expect(bool(nearby_stroke.get("valid", false)) and int(nearby_stroke.get("geometry_diagnostics", {}).get("narrow_overlap_pair_count", -1)) == 0, "Nearby authored lines farther apart than one stroke width must stay independent and must not be merged by epsilon proximity.")

	var retraced_contour := _component()
	retraced_contour["draw_mode"] = "contour"
	for position in [Vector2.ZERO, Vector2(10.0, 0.0), Vector2.ZERO]:
		BezierTopology.add_point(retraced_contour, position, "linear")
	var retraced_stroke := ContourStrokeService.generate(retraced_contour)
	_expect(not bool(retraced_stroke.get("valid", true)) and str(retraced_stroke.get("errors", [""])[0]).contains("reverses direction by 180 degrees"), "A collapsing 180-degree return must fail explicitly instead of silently emitting ambiguous overlapping offset geometry.")

	var overlapping_contour := _component()
	overlapping_contour["draw_mode"] = "contour"
	for position in [Vector2.ZERO, Vector2(10.0, 0.0), Vector2(3.0, 4.0), Vector2(8.0, 0.0), Vector2(2.0, 0.0)]:
		BezierTopology.add_point(overlapping_contour, position, "linear")
	var overlapping_stroke := ContourStrokeService.generate(overlapping_contour)
	_expect(not bool(overlapping_stroke.get("valid", true)) and "overlap collinearly" in " ".join(overlapping_stroke.get("errors", [])), "Non-adjacent collinear Boundary overlap must be rejected with a stable validation error, never repaired by an implicit fallback.")


func _test_world_contour_settings() -> void:
	var defaults := WorldSettingsService.default_settings()
	_expect(is_equal_approx(float(defaults.get("reference_pixels_per_meter", 0.0)), 192.0) and is_equal_approx(float(defaults.get("contour_stroke_width_px", 0.0)), 4.0), "New Worlds should start with the approved 192 px/m reference density and one 4 px Contour width for every Asset.")
	var migrated := WorldSettingsService.decode(null, 40)
	_expect(bool(migrated.get("valid", false)) and bool(migrated.get("migrated", false)) and is_equal_approx(float(migrated.get("settings", {}).get("contour_stroke_width_px", 0.0)), 4.0), "Schema 40 and older Worlds must migrate explicitly to the 4 px World Contour default.")
	_expect(not bool(WorldSettingsService.decode(null, 41).get("valid", true)), "Schema 41 must reject a missing world_settings record instead of silently applying a fallback.")
	_expect(not bool(WorldSettingsService.decode({"reference_pixels_per_meter": "192", "contour_stroke_width_px": 4.0}, 46).get("valid", true)), "Schema-46 World Settings must reject stringly typed numeric fields.")
	var migrated_density := WorldSettingsService.decode({"reference_pixels_per_meter": 128.0, "contour_stroke_width_px": 4.0}, 45)
	_expect(bool(migrated_density.get("valid", false)) and bool(migrated_density.get("migrated", false)) and is_equal_approx(float(migrated_density.get("settings", {}).get("reference_pixels_per_meter", 0.0)), 192.0) and is_equal_approx(float(migrated_density.get("settings", {}).get("contour_stroke_width_px", 0.0)), 4.0), "Schema-45 Worlds must migrate to 192 px/m while retaining their authored Contour width.")
	_expect(not bool(WorldSettingsService.decode({"reference_pixels_per_meter": 192.0, "contour_stroke_width_px": 0.0}, 46).get("valid", true)), "World Settings must reject a non-positive authored Contour width.")
	var decoded := WorldSettingsService.decode({"reference_pixels_per_meter": 192.0, "contour_stroke_width_px": 6.0}, 46)
	_expect(bool(decoded.get("valid", false)) and not bool(decoded.get("migrated", true)) and WorldSettingsService.encode(6.0) == decoded.get("settings", {}), "Schema-46 World Settings should round-trip a typed authored pixel width without migration.")

	var contour := _component()
	contour["id"] = "arm_line"
	contour["draw_mode"] = "contour"
	BezierTopology.add_point(contour, Vector2.ZERO, "linear")
	BezierTopology.add_point(contour, Vector2(8.0, 0.0), "linear")
	var four_px_mesh := ContourMeshService.generate(contour, 4.0)
	var six_px_mesh := ContourMeshService.generate(contour, 6.0)
	_expect(bool(four_px_mesh.get("valid", false)) and bool(six_px_mesh.get("valid", false)) and is_equal_approx(float(six_px_mesh.get("parameters", {}).get("stroke_width_meters", 0.0)), 0.03125), "Contour Mesh generation must derive the selected World width through the fixed 192 px/m density.")
	_expect(not ContourMeshService.matches_source(four_px_mesh, contour, 6.0) and ContourMeshService.matches_source(six_px_mesh, contour, 6.0), "Changing the World Contour width must invalidate every Mesh baked at the previous width.")
	var four_vertices: Array = four_px_mesh.get("vertices", [])
	var six_vertices: Array = six_px_mesh.get("vertices", [])
	_expect(Vector2(six_vertices[0].get("position", Vector2.ZERO)).distance_to(Vector2(six_vertices[1].get("position", Vector2.ZERO))) > Vector2(four_vertices[0].get("position", Vector2.ZERO)).distance_to(Vector2(four_vertices[1].get("position", Vector2.ZERO))), "The authored World width must change actual centered stroke geometry, not only metadata.")

	var application = load("res://scripts/main.gd").new()
	application._build_ui()
	_expect(int(WorldDocumentService.SCHEMA_VERSION) >= 41 and application.world_scale_menu.text.begins_with("World Settings"), "Slice 5 should expose World Settings in the top toolbar and retain its schema-41 persisted contract.")
	_expect(is_equal_approx(float(application.world_contour_stroke_width_field.value), 4.0), "World Settings should show the 4 px default in its authored Contour width field.")
	application.world_contour_stroke_width_px = 4.1
	application._update_world_scale_popup()
	_expect("Contour: 4.1 px = 0.02135 m" in application.world_scale_summary_label.text, "World Settings should show enough meter precision to distinguish fractional authored pixel widths.")
	_expect("1 Spiel-Tile = 100 cm (20 Grid-Boxen)" in application.world_scale_summary_label.text, "World Settings should expose the shared 1 m game Tile as twenty default 5 cm Grid Boxes.")
	application.world_contour_stroke_width_px = 4.0
	var four_px_signature: Dictionary = application._geometry_build_signature("", "", contour)
	application.world_contour_stroke_width_px = 6.0
	var six_px_signature: Dictionary = application._geometry_build_signature("", "", contour)
	_expect(not GeometryAutoBuildService.signatures_match(four_px_signature, six_px_signature), "The World width must participate in the automatic build signature used by batch invalidation.")
	var overridden_contour := contour.duplicate(true)
	overridden_contour["contour_stroke_width_px"] = 9.5
	var overridden_mesh := ContourMeshService.generate(overridden_contour, application._effective_contour_stroke_width_px(overridden_contour))
	_expect(is_equal_approx(application._effective_contour_stroke_width_px(overridden_contour), 9.5) and bool(overridden_mesh.get("valid", false)) and is_equal_approx(float(overridden_mesh.get("parameters", {}).get("stroke_width_px", 0.0)), 9.5), "A Component-local Contour width override must resolve to its authored positive pixel value.")
	var override_signature_before: Dictionary = application._geometry_build_signature("", "", overridden_contour)
	application.world_contour_stroke_width_px = 10.0
	var override_signature_after: Dictionary = application._geometry_build_signature("", "", overridden_contour)
	_expect(GeometryAutoBuildService.signatures_match(override_signature_before, override_signature_after), "Changing the World width must not invalidate a Component with its own Contour width override.")
	var inherited_explicit_width := contour.duplicate(true)
	inherited_explicit_width["contour_stroke_width_px"] = application.world_contour_stroke_width_px
	_expect(not application._component_has_contour_stroke_width_override(inherited_explicit_width) and is_equal_approx(application._effective_contour_stroke_width_px(inherited_explicit_width), application.world_contour_stroke_width_px), "A Component width equal to the World value must inherit it without requiring an explicit Override toggle.")
	_expect(not application._component_has_contour_stroke_width_override({"contour_stroke_width_px": 0.0}) and not application._component_has_contour_stroke_width_override({"contour_stroke_width_px": "9.5"}), "Component Contour width overrides must be finite, positive numeric values.")
	application.world_contour_stroke_width_px = 4.0
	var history_snapshot: Dictionary = application._capture_history_snapshot()
	application._on_world_contour_stroke_width_changed(6.0)
	_expect(is_equal_approx(application.world_contour_stroke_width_px, 6.0) and is_equal_approx(float(application._serialize_world_settings().get("contour_stroke_width_px", 0.0)), 6.0), "Editing World Settings should update the single persisted width shared by all Assets.")
	application._restore_history_snapshot(history_snapshot)
	_expect(is_equal_approx(application.world_contour_stroke_width_px, 4.0) and is_equal_approx(float(application.world_contour_stroke_width_field.value), 4.0), "The authored World Contour width should participate in Undo/Redo snapshots.")
	application.free()


func _test_frame_guide_ui() -> void:
	var application = load("res://scripts/main.gd").new()
	application._build_ui()
	_expect(is_instance_valid(application.frame_button) and application.frame_button.text == "Frame: Off  ▼" and not application.frame_visible, "Frame should be available beside Snap and default to hidden.")
	_expect(is_equal_approx(float(application.frame_half_extent_fields["x"].value), 10.0) and is_equal_approx(float(application.frame_half_extent_fields["y"].value), 10.0), "Frame Half Extent fields should default to 10 cm on both axes.")
	_expect(is_equal_approx(float(application.frame_offset_fields["x"].value), 0.0) and is_equal_approx(float(application.frame_offset_fields["y"].value), 0.0), "Frame Offset / Pivot fields should default to zero.")
	application._on_frame_field_changed(25.0, "half_extent", "x")
	application._on_frame_field_changed(-5.0, "offset", "y")
	_expect(application.frame_half_extent.is_equal_approx(Vector2(2.5, 1.0)) and application.frame_offset.is_equal_approx(Vector2(0.0, -0.5)), "Frame fields should convert authored centimetres into canvas units independently per axis.")
	application._on_frame_visible_toggled(true)
	_expect(application.frame_visible and application.canvas_view.frame_visible and application.canvas_view.frame_half_extent.is_equal_approx(Vector2(2.5, 1.0)) and application.canvas_view.frame_offset.is_equal_approx(Vector2(0.0, -0.5)), "Enabling Frame should forward the guide state to the canvas without changing document geometry.")
	var state: Dictionary = application._serialize_editor_state()
	var frame_state: Dictionary = state.get("frame", {})
	_expect(bool(frame_state.get("visible", false)) and Array(frame_state.get("half_extent", [])).size() == 2 and is_equal_approx(float(frame_state["half_extent"][0]), 2.5) and is_equal_approx(float(frame_state["offset"][1]), -0.5), "Frame settings should round-trip through the editor-state snapshot.")
	application._apply_frame_settings({})
	_expect(not application.frame_visible and application.frame_half_extent.is_equal_approx(Vector2.ONE) and application.frame_offset.is_equal_approx(Vector2.ZERO), "Missing Frame editor state should restore the hidden defaults.")
	application._apply_frame_settings(frame_state)
	_expect(application.frame_visible and application.frame_half_extent.is_equal_approx(Vector2(2.5, 1.0)) and application.frame_offset.is_equal_approx(Vector2(0.0, -0.5)), "Persisted Frame editor state should restore visibility and both offsets.")
	application.free()


func _test_component_scale_rebase() -> void:
	var curved := _component()
	curved.merge({"id": "scaled_body", "name": "Body", "draw_mode": "closed_loop", "type": "component", "parent_component_id": "", "transform": {"position": Vector2(3.0, -2.0), "rotation": 27.0, "scale": Vector2(2.0, 0.5), "pivot": Vector2(1.0, 1.0)}})
	for position in [Vector2(0.0, 0.0), Vector2(4.0, -1.0), Vector2(6.0, 3.0), Vector2(1.0, 5.0)]:
		BezierTopology.add_point(curved, position, "free")
	BezierTopology.close_active_chain(curved)
	var circle := {"id": "scaled_eye", "name": "Eye", "draw_mode": "primitive", "type": "component", "parent_component_id": "", "points": [], "edges": [], "chains": [], "primitive": {"type": "circle", "center": Vector2(2.0, 3.0), "diameter_cm": 10.0}, "transform": {"position": Vector2(-4.0, 5.0), "rotation": -15.0, "scale": Vector2(2.0, 0.5), "pivot": Vector2(1.0, 1.0)}}
	var guide := _component()
	guide.merge({"id": "guide_body", "name": "Body Guide", "type": "guide", "guide_type": AssetGuide.SAMPLER_SPINE, "scope": {"component_id": "scaled_body"}})
	BezierTopology.add_point(guide, Vector2(0.5, 0.5), "free")
	BezierTopology.add_point(guide, Vector2(3.0, 2.0), "free")
	var animation := {"states": [{"id": "state_test", "motions": [{"id": "motion_scale", "parameters": {"strength": 0.75}}]}]}
	var asset := {"id": "wizard_rebase", "name": "Wizard", "components": [curved, circle], "guides": [guide], "animation": animation.duplicate(true)}
	var animation_before: Dictionary = asset["animation"].duplicate(true)
	var curved_transform_before: Dictionary = curved["transform"].duplicate(true)
	var curved_source := curved.duplicate(true)
	BezierGeometry.resolve_auto_handles(curved_source.get("points", []), curved_source.get("chains", []))
	var curved_edge: Dictionary = curved_source.get("edges", [])[0]
	var curved_start := BezierTopology.point_by_id(curved_source["points"], str(curved_edge.get("start_point_id", "")))
	var curved_end := BezierTopology.point_by_id(curved_source["points"], str(curved_edge.get("end_point_id", "")))
	var curved_controls := BezierGeometry.cubic_controls(curved_start, curved_end)
	var curved_world_before: Array[Vector2] = []
	var curved_world_transform_before := ComponentHierarchy.world_transform(asset, "scaled_body")
	for sample_index in range(17):
		curved_world_before.append(curved_world_transform_before * BezierGeometry.cubic_position(curved_controls, float(sample_index) / 16.0))
	var guide_world_before := curved_world_transform_before * Vector2(guide.get("points", [])[0].get("position", Vector2.ZERO))
	var circle_world_before: Array[Vector2] = []
	var circle_world_transform_before := ComponentHierarchy.world_transform(asset, "scaled_eye")
	for point in PrimitiveGeometryService.contour(circle, 64):
		circle_world_before.append(circle_world_transform_before * point)

	var analysis := ComponentScaleRebaseService.analyze_asset(asset)
	_expect(bool(analysis.get("can_rebase", false)) and analysis.get("candidates", []).size() == 2 and analysis.get("blockers", []).is_empty(), "An Asset with positive scaled leaf geometry should expose every affected Component as one atomic Rebase candidate set.")
	var result := ComponentScaleRebaseService.rebase_asset(asset)
	_expect(bool(result.get("valid", false)) and result.get("rebased_component_ids", []).size() == 2, "Scale Rebase should atomically normalize every eligible Component in the Asset.")
	var rebased_curved := ComponentHierarchy.component_by_id(asset, "scaled_body")
	var rebased_circle := ComponentHierarchy.component_by_id(asset, "scaled_eye")
	_expect(Vector2(rebased_curved.get("transform", {}).get("scale", Vector2.ZERO)) == Vector2.ONE and Vector2(rebased_circle.get("transform", {}).get("scale", Vector2.ZERO)) == Vector2.ONE, "Successful Rebase must set both Component scale axes exactly to one.")
	_expect(Vector2(rebased_curved.get("transform", {}).get("position", Vector2.ZERO)) == curved_transform_before["position"] and is_equal_approx(float(rebased_curved.get("transform", {}).get("rotation", 0.0)), float(curved_transform_before["rotation"])) and Vector2(rebased_curved.get("transform", {}).get("pivot", Vector2.ZERO)) == curved_transform_before["pivot"], "Rebase must not change Component Position, Rotation, or Pivot.")
	var rebased_edge: Dictionary = rebased_curved.get("edges", [])[0]
	var rebased_start := BezierTopology.point_by_id(rebased_curved["points"], str(rebased_edge.get("start_point_id", "")))
	var rebased_end := BezierTopology.point_by_id(rebased_curved["points"], str(rebased_edge.get("end_point_id", "")))
	var rebased_controls := BezierGeometry.cubic_controls(rebased_start, rebased_end)
	var rebased_world_transform := ComponentHierarchy.world_transform(asset, "scaled_body")
	var curve_preserved := true
	for sample_index in range(17):
		var after := rebased_world_transform * BezierGeometry.cubic_position(rebased_controls, float(sample_index) / 16.0)
		curve_preserved = curve_preserved and after.distance_to(curved_world_before[sample_index]) <= 0.000001
	_expect(curve_preserved and str(rebased_start.get("handle_source", "")) == "manual", "Anisotropic Rebase must preserve the complete authored Bézier curve by retaining its affinely transformed resolved handles.")
	var rebased_guide: Dictionary = asset.get("guides", [])[0]
	var guide_world_after := rebased_world_transform * Vector2(rebased_guide.get("points", [])[0].get("position", Vector2.ZERO))
	_expect(guide_world_after.distance_to(guide_world_before) <= 0.000001 and str(rebased_guide.get("points", [])[0].get("handle_source", "")) == "manual", "Component-scoped Guides must retain their world-space curve when their target Component is rebased.")
	_expect(PrimitiveGeometryService.has_ellipse(rebased_circle) and is_equal_approx(float(rebased_circle.get("primitive", {}).get("diameter_x_cm", 0.0)), 20.0) and is_equal_approx(float(rebased_circle.get("primitive", {}).get("diameter_y_cm", 0.0)), 5.0) and PrimitiveGeometryService.center(rebased_circle).is_equal_approx(Vector2(3.0, 2.0)), "A non-uniformly scaled Circle must rebase to an analytic Ellipse with scaled center and axis diameters.")
	var circle_world_after: Array[Vector2] = []
	var circle_world_transform_after := ComponentHierarchy.world_transform(asset, "scaled_eye")
	for point in PrimitiveGeometryService.contour(rebased_circle, 64):
		circle_world_after.append(circle_world_transform_after * point)
	var ellipse_preserved := circle_world_after.size() == circle_world_before.size()
	for point_index in range(circle_world_after.size()):
		ellipse_preserved = ellipse_preserved and circle_world_after[point_index].distance_to(circle_world_before[point_index]) <= 0.000001
	_expect(ellipse_preserved, "Circle-to-Ellipse Rebase must preserve the exact transformed analytic contour.")
	var ellipse_sampling := GeometrySamplingService.generate(rebased_circle, {"parameters": {"spacing": 0.2, "feature_detail": 0.7}})
	var ellipse_metrics := GeometryAutoBuildService.analyze(rebased_circle)
	_expect(bool(ellipse_sampling.get("valid", false)) and str(ellipse_sampling.get("chains", [])[0].get("chain_id", "")) == "primitive:ellipse" and float(ellipse_metrics.get("area", 0.0)) > 0.0, "The sampling and automatic geometry analyzers must consume rebased Ellipses analytically.")
	_expect(asset.get("animation", {}) == animation_before, "Scale Rebase must leave authored animation data unchanged so later simulation Scale remains relative to the normalized reference drawing.")

	var mirrored_eye := curved_source.duplicate(true)
	mirrored_eye["id"] = "mirrored_eye"
	mirrored_eye["name"] = "Mirrored Eye"
	mirrored_eye["parent_component_id"] = ""
	mirrored_eye["transform"] = {"position": Vector2(-0.75, 11.4), "rotation": 180.0, "scale": Vector2(1.0, -1.0), "pivot": Vector2(0.75, 11.4)}
	var mirrored_asset := {"id": "mirrored_rebase", "name": "Mirrored Rebase", "components": [mirrored_eye], "guides": []}
	var mirrored_transform_before: Dictionary = mirrored_eye["transform"].duplicate(true)
	var mirrored_edge: Dictionary = mirrored_eye.get("edges", [])[0]
	var mirrored_start := BezierTopology.point_by_id(mirrored_eye["points"], str(mirrored_edge.get("start_point_id", "")))
	var mirrored_end := BezierTopology.point_by_id(mirrored_eye["points"], str(mirrored_edge.get("end_point_id", "")))
	var mirrored_controls := BezierGeometry.cubic_controls(mirrored_start, mirrored_end)
	var mirrored_world_transform_before := ComponentHierarchy.world_transform(mirrored_asset, "mirrored_eye")
	var mirrored_world_before: Array[Vector2] = []
	for sample_index in range(17):
		mirrored_world_before.append(mirrored_world_transform_before * BezierGeometry.cubic_position(mirrored_controls, float(sample_index) / 16.0))
	var mirrored_analysis := ComponentScaleRebaseService.analyze_asset(mirrored_asset)
	var mirrored_result := ComponentScaleRebaseService.rebase_asset(mirrored_asset)
	var rebased_mirrored_eye := ComponentHierarchy.component_by_id(mirrored_asset, "mirrored_eye")
	var rebased_mirrored_edge: Dictionary = rebased_mirrored_eye.get("edges", [])[0]
	var rebased_mirrored_start := BezierTopology.point_by_id(rebased_mirrored_eye["points"], str(rebased_mirrored_edge.get("start_point_id", "")))
	var rebased_mirrored_end := BezierTopology.point_by_id(rebased_mirrored_eye["points"], str(rebased_mirrored_edge.get("end_point_id", "")))
	var rebased_mirrored_controls := BezierGeometry.cubic_controls(rebased_mirrored_start, rebased_mirrored_end)
	var rebased_mirrored_world_transform := ComponentHierarchy.world_transform(mirrored_asset, "mirrored_eye")
	var mirrored_curve_preserved := true
	var mirrored_max_error := 0.0
	for sample_index in range(17):
		var after := rebased_mirrored_world_transform * BezierGeometry.cubic_position(rebased_mirrored_controls, float(sample_index) / 16.0)
		mirrored_max_error = maxf(mirrored_max_error, after.distance_to(mirrored_world_before[sample_index]))
		mirrored_curve_preserved = mirrored_curve_preserved and mirrored_max_error <= 0.000005
	_expect(bool(mirrored_analysis.get("can_rebase", false)) and bool(mirrored_result.get("valid", false)), "A finite negative axis created by Mirror must be an explicit signed Rebase candidate, not a blocker.")
	_expect(Vector2(rebased_mirrored_eye.get("transform", {}).get("scale", Vector2.ZERO)) == Vector2.ONE and rebased_mirrored_eye.get("transform", {}).get("position") == mirrored_transform_before["position"] and rebased_mirrored_eye.get("transform", {}).get("rotation") == mirrored_transform_before["rotation"] and rebased_mirrored_eye.get("transform", {}).get("pivot") == mirrored_transform_before["pivot"], "Signed Rebase must normalize mirrored Scale without changing Position, Rotation, or Pivot.")
	_expect(mirrored_curve_preserved and str(rebased_mirrored_start.get("handle_source", "")) == "manual", "Signed Rebase must preserve the exact reflected Bézier boundary represented by a 180-degree Rotation and negative Y Scale (max error: %s)." % mirrored_max_error)
	var mirrored_circle := circle.duplicate(true)
	mirrored_circle["id"] = "mirrored_circle"
	mirrored_circle["transform"] = {"position": Vector2.ZERO, "rotation": 180.0, "scale": Vector2(-2.0, 0.5), "pivot": Vector2(1.0, 1.0)}
	var mirrored_primitive_asset := {"id": "mirrored_primitive_rebase", "name": "Mirrored Primitive Rebase", "components": [mirrored_circle], "guides": []}
	var mirrored_primitive_result := ComponentScaleRebaseService.rebase_asset(mirrored_primitive_asset)
	var rebased_mirrored_circle := ComponentHierarchy.component_by_id(mirrored_primitive_asset, "mirrored_circle")
	_expect(bool(mirrored_primitive_result.get("valid", false)) and PrimitiveGeometryService.has_ellipse(rebased_mirrored_circle) and PrimitiveGeometryService.center(rebased_mirrored_circle).is_equal_approx(Vector2(-1.0, 2.0)) and is_equal_approx(float(rebased_mirrored_circle.get("primitive", {}).get("diameter_x_cm", 0.0)), 20.0) and is_equal_approx(float(rebased_mirrored_circle.get("primitive", {}).get("diameter_y_cm", 0.0)), 5.0), "Signed primitive Rebase must reflect the center while keeping analytic Circle/Ellipse diameters positive.")

	var blocked_parent := curved_source.duplicate(true)
	blocked_parent["id"] = "parent"
	blocked_parent["name"] = "Parent"
	blocked_parent["transform"] = {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2(2.0, 2.0), "pivot": Vector2.ZERO}
	var child := curved_source.duplicate(true)
	child["id"] = "child"
	child["name"] = "Child"
	child["parent_component_id"] = "parent"
	child["transform"] = {"position": Vector2.ONE, "rotation": 15.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}
	var negative := curved_source.duplicate(true)
	negative["id"] = "negative"
	negative["name"] = "Negative"
	negative["parent_component_id"] = ""
	negative["transform"] = {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2(-1.0, 1.0), "pivot": Vector2.ZERO}
	var zero_axis := curved_source.duplicate(true)
	zero_axis["id"] = "zero_axis"
	zero_axis["name"] = "Zero Axis"
	zero_axis["parent_component_id"] = ""
	zero_axis["transform"] = {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2(0.0, 1.0), "pivot": Vector2.ZERO}
	var scaled_reference := {"id": "reference", "name": "Reference", "type": "reference", "source_asset_id": "other", "parent_component_id": "", "draw_mode": "closed_loop", "points": [], "edges": [], "chains": [], "transform": {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2(2.0, 1.0), "pivot": Vector2.ZERO}}
	var blocked_asset := {"id": "blocked", "name": "Blocked", "components": [blocked_parent, child, negative, zero_axis, scaled_reference], "guides": []}
	var blocked_snapshot := blocked_asset.duplicate(true)
	var blocked_analysis := ComponentScaleRebaseService.analyze_asset(blocked_asset)
	_expect(not bool(blocked_analysis.get("can_rebase", true)) and blocked_analysis.get("candidates", []).size() == 3 and blocked_analysis.get("blockers", []).size() == 1, "Scale Rebase should include scaled References while retaining zero-axis blockers.")
	_expect(not bool(ComponentScaleRebaseService.rebase_asset(blocked_asset).get("valid", true)) and blocked_asset == blocked_snapshot, "A blocked Asset Rebase must not partially mutate any Component.")

	var child_rebase_asset := {"id": "child_rebase", "name": "Child Rebase", "components": [blocked_parent.duplicate(true), child.duplicate(true)], "guides": []}
	var child_world_before := ComponentHierarchy.world_transform(child_rebase_asset, "child")
	var child_rebase_result := ComponentScaleRebaseService.rebase_asset(child_rebase_asset)
	var child_world_after := ComponentHierarchy.world_transform(child_rebase_asset, "child")
	var rebased_child := ComponentHierarchy.component_by_id(child_rebase_asset, "child")
	var child_world_preserved := child_world_after.origin.is_equal_approx(child_world_before.origin) and child_world_after.basis_xform(Vector2.RIGHT).is_equal_approx(child_world_before.basis_xform(Vector2.RIGHT)) and child_world_after.basis_xform(Vector2.DOWN).is_equal_approx(child_world_before.basis_xform(Vector2.DOWN))
	_expect(bool(child_rebase_result.get("valid", false)) and child_rebase_result.get("rebased_component_ids", []).size() == 1 and Vector2(ComponentHierarchy.component_by_id(child_rebase_asset, "parent").get("transform", {}).get("scale", Vector2.ZERO)) == Vector2.ONE and child_world_preserved and not Vector2(rebased_child.get("transform", {}).get("position", Vector2.ZERO)).is_equal_approx(Vector2.ONE), "Rebasing a scaled Parent must compensate its Child local transform while preserving the Child's visible world transform.")

	var group_parent := curved_source.duplicate(true)
	group_parent["id"] = "group_parent"
	group_parent["name"] = "Group Parent"
	group_parent["parent_component_id"] = ""
	group_parent["group_id"] = ""
	group_parent["transform"] = {"position": Vector2(3.0, -2.0), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}
	var group_member := curved_source.duplicate(true)
	group_member["id"] = "group_member"
	group_member["name"] = "Group Member"
	group_member["parent_component_id"] = "group_parent"
	group_member["group_id"] = "scaled_group"
	group_member["transform"] = {"position": Vector2(2.0, 1.0), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}
	var group_guide := AssetGuide.create("group_guide", "Group Guide", AssetGuide.SAMPLER_SPINE, "")
	group_guide["scope"] = {"kind": "group", "group_id": "scaled_group"}
	BezierTopology.add_point(group_guide, Vector2(1.0, 2.0), "free", Vector2(0.25, -0.5))
	var group_rebase_asset := {
		"id": "group_rebase", "name": "Group Rebase", "components": [group_parent, group_member],
		"groups": [{"id": "scaled_group", "name": "scaled_group", "parent_component_id": "group_parent", "visibility": true, "transform": {"position": Vector2(4.0, 5.0), "rotation": 20.0, "scale": Vector2(1.25, 0.8), "pivot": Vector2(1.0, -1.0)}}],
		"guides": [group_guide]
	}
	var group_member_point_before := ComponentHierarchy.world_transform(group_rebase_asset, "group_member") * Vector2(group_member.get("points", [])[0].get("position", Vector2.ZERO))
	var group_guide_point_before := ComponentHierarchy.group_world_transform(group_rebase_asset, "scaled_group") * Vector2(group_guide.get("points", [])[0].get("position", Vector2.ZERO))
	var group_analysis := ComponentScaleRebaseService.analyze_asset(group_rebase_asset)
	var group_rebase_result := ComponentScaleRebaseService.rebase_asset(group_rebase_asset)
	var rebased_group := ComponentHierarchy.group_by_id(group_rebase_asset, "scaled_group")
	var rebased_group_member := ComponentHierarchy.component_by_id(group_rebase_asset, "group_member")
	var group_member_point_after := ComponentHierarchy.world_transform(group_rebase_asset, "group_member") * Vector2(rebased_group_member.get("points", [])[0].get("position", Vector2.ZERO))
	var rebased_group_guide: Dictionary = group_rebase_asset.get("guides", [])[0]
	var group_guide_point_after := ComponentHierarchy.group_world_transform(group_rebase_asset, "scaled_group") * Vector2(rebased_group_guide.get("points", [])[0].get("position", Vector2.ZERO))
	_expect(bool(group_analysis.get("can_rebase", false)) and group_analysis.get("candidates", []).size() == 2 and bool(group_rebase_result.get("valid", false)) and group_rebase_result.get("rebased_group_ids", []).size() == 1 and Vector2(rebased_group.get("transform", {}).get("scale", Vector2.ZERO)) == Vector2.ONE and Vector2(rebased_group_member.get("transform", {}).get("scale", Vector2.ZERO)) == Vector2.ONE, "Scale Rebase should include a scaled Group and normalize both the Group and its compensated member Component.")
	_expect(group_member_point_after.distance_to(group_member_point_before) <= 0.000001 and group_guide_point_after.distance_to(group_guide_point_before) <= 0.000001 and str(rebased_group_guide.get("points", [])[0].get("handle_source", "")) == "manual", "Group Scale Rebase must preserve member geometry and group-scoped Guide curves in world space.")

	var ui_asset := {"id": "ui_rebase", "name": "UI Rebase", "asset_type": "character", "visibility": true, "asset_pivot": Vector2.ZERO, "components": [curved_source.duplicate(true)], "guides": [], "animation": MotionWorkspace.create_default_animation_document()}
	ui_asset["components"][0]["id"] = "ui_component"
	ui_asset["components"][0]["name"] = "UI Component"
	ui_asset["components"][0]["parent_component_id"] = ""
	ui_asset["components"][0]["transform"] = {"position": Vector2.ZERO, "rotation": 5.0, "scale": Vector2(1.5, 0.75), "pivot": Vector2.ZERO}
	var application = load("res://scripts/main.gd").new()
	application._build_ui()
	var serialized_ellipse: Dictionary = WorldDocumentService.serialize_primitive(rebased_circle.get("primitive", {}))
	var restored_ellipse: Dictionary = WorldDocumentService.deserialize_primitive(serialized_ellipse)
	_expect(serialized_ellipse.get("center", null) is Array and str(restored_ellipse.get("type", "")) == PrimitiveGeometryService.ELLIPSE and is_equal_approx(float(restored_ellipse.get("diameter_x_cm", 0.0)), 20.0), "Schema-42 persistence must round-trip analytic Ellipse parameters without storing a polygon approximation.")
	var ui_assets: Array[Dictionary] = [ui_asset]
	application.assets = ui_assets
	application.selected_asset_id = "ui_rebase"
	application.selected_component_id = ""
	application._render_inspector()
	_expect(is_instance_valid(application.create_inspector_view.asset_scale_rebase_button) and not application.create_inspector_view.asset_scale_rebase_button.disabled and application.create_inspector_view.asset_scale_rebase_button.text.contains("(1)"), "The Asset Inspector should enable Rebase only when its compact candidate list is non-empty and unblocked.")
	application._on_rebase_asset_scales_pressed()
	_expect(Vector2(application._get_component(application._get_asset("ui_rebase"), "ui_component").get("transform", {}).get("scale", Vector2.ZERO)) == Vector2.ONE and application.create_inspector_view.asset_scale_rebase_button.disabled, "The Asset Inspector Rebase action should normalize the candidate and disable itself once no work remains.")
	application.free()


func _test_asset_scale_rebase() -> void:
	var component := _component()
	component.merge({"id": "head", "name": "head", "visibility": true, "parent_component_id": "", "group_id": "hammer_group", "transform": {"position": Vector2(4.0, 3.0), "rotation": 20.0, "scale": Vector2.ONE, "pivot": Vector2(1.0, 2.0)}})
	BezierTopology.add_point(component, Vector2(2.0, 1.0), "free", Vector2(0.5, -0.25))
	var circle := {"id": "pommel", "name": "pommel", "visibility": true, "parent_component_id": "", "group_id": "", "draw_mode": "primitive", "geometry_source": "primitive", "primitive": {"type": "circle", "center": Vector2(1.0, -2.0), "diameter_cm": 5.0}, "points": [], "edges": [], "chains": [], "transform": {"position": Vector2(8.0, 9.0), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}}
	var reference := {"id": "reference", "name": "reference", "type": "reference", "source_asset_id": "source", "visibility": true, "parent_component_id": "", "group_id": "", "reference_instance_scale": Vector2(1.25, 0.75), "transform": {"position": Vector2(-2.0, 6.0), "rotation": 15.0, "scale": Vector2.ONE, "pivot": Vector2(2.0, -1.0)}}
	var spine := AssetGuide.create("spine", "Spine", AssetGuide.SAMPLER_SPINE, "head")
	BezierTopology.add_point(spine, Vector2(0.5, 1.5), "aligned")
	var weapon_frame := AssetGuide.create_weapon_frame("grip", AssetGuide.GRIP_PRIMARY, "group", "hammer_group")
	weapon_frame["transform"]["position"] = Vector2(3.0, 4.0)
	weapon_frame["transform"]["rotation"] = 35.0
	var asset := {
		"id": "root_scale", "name": "Root Scale", "asset_type": "weapon", "visibility": true,
		"asset_pivot": Vector2(5.0, 7.0), "root_position": Vector2(12.0, -8.0), "root_scale": 3.6,
		"groups": [{"id": "hammer_group", "name": "Hammer Group", "visibility": true, "parent_component_id": "", "transform": {"position": Vector2(10.0, 2.0), "rotation": -12.0, "scale": Vector2.ONE, "pivot": Vector2(1.0, 1.0)}}],
		"components": [component, circle, reference], "guides": [spine, weapon_frame],
		"animation": MotionWorkspace.create_default_animation_document()
	}
	var preview := AssetScaleRebaseService.root_transform(asset)
	var component_point_before := ComponentHierarchy.world_transform(asset, "head") * Vector2(component["points"][0]["position"])
	var reference_point_before := ComponentHierarchy.world_transform(asset, "reference") * Vector2(9.0, -4.0)
	var spine_point_before := ComponentHierarchy.world_transform(asset, "head") * Vector2(spine["points"][0]["position"])
	var frame_before := ComponentHierarchy.group_world_transform(asset, "hammer_group") * ComponentHierarchy.local_transform(weapon_frame["transform"])
	var result := AssetScaleRebaseService.rebase_asset(asset)
	var rebased_component := ComponentHierarchy.component_by_id(asset, "head")
	var rebased_circle := ComponentHierarchy.component_by_id(asset, "pommel")
	var rebased_reference := ComponentHierarchy.component_by_id(asset, "reference")
	var component_point_after := ComponentHierarchy.world_transform(asset, "head") * Vector2(rebased_component["points"][0]["position"])
	var reference_point_after := ComponentHierarchy.world_transform(asset, "reference") * Vector2(9.0, -4.0)
	var spine_point_after := ComponentHierarchy.world_transform(asset, "head") * Vector2(asset["guides"][0]["points"][0]["position"])
	var frame_after := ComponentHierarchy.group_world_transform(asset, "hammer_group") * ComponentHierarchy.local_transform(asset["guides"][1]["transform"])
	_expect(bool(result.get("valid", false)) and is_equal_approx(float(asset.get("root_scale", 0.0)), 1.0) and Vector2(asset.get("root_position", Vector2.INF)) == Vector2.ZERO and Vector2(asset.get("asset_pivot", Vector2.ZERO)) == Vector2(5.0, 7.0), "Asset Transform Rebase should succeed atomically, normalize Position and Scale, and preserve the Asset Pivot.")
	_expect(component_point_after.is_equal_approx(preview * component_point_before), "Root Scale Rebase should preserve the previewed world geometry of nested Components.")
	_expect(PrimitiveGeometryService.center(rebased_circle).is_equal_approx(Vector2(3.6, -7.2)) and is_equal_approx(float(rebased_circle.get("primitive", {}).get("diameter_cm", 0.0)), 18.0), "Root Scale Rebase should bake the same uniform factor into analytic primitive centers and diameters.")
	_expect(reference_point_after.is_equal_approx(preview * reference_point_before) and Vector2(rebased_reference.get("reference_instance_scale", Vector2.ZERO)).is_equal_approx(Vector2(4.5, 2.7)) and Vector2(rebased_reference.get("transform", {}).get("pivot", Vector2.ZERO)) == Vector2(2.0, -1.0), "Root Scale Rebase should scale Reference instances without double-scaling their pivots.")
	_expect(spine_point_after.is_equal_approx(preview * spine_point_before) and frame_after.origin.is_equal_approx(preview * frame_before.origin) and is_equal_approx(frame_after.get_rotation(), frame_before.get_rotation()), "Root Scale Rebase should preserve previewed Spine points and oriented Weapon frames.")
	_expect(Vector2(rebased_component.get("transform", {}).get("scale", Vector2.ZERO)) == Vector2.ONE, "Root Scale Rebase should remain independent from Component Scale Rebase.")
	var position_only := asset.duplicate(true)
	position_only["root_position"] = Vector2(-3.0, 4.0)
	var position_only_point_before := ComponentHierarchy.world_transform(position_only, "head") * Vector2(ComponentHierarchy.component_by_id(position_only, "head")["points"][0]["position"])
	var position_only_result := AssetScaleRebaseService.rebase_asset(position_only)
	var position_only_point_after := ComponentHierarchy.world_transform(position_only, "head") * Vector2(ComponentHierarchy.component_by_id(position_only, "head")["points"][0]["position"])
	_expect(bool(position_only_result.get("valid", false)) and Vector2(position_only.get("root_position", Vector2.INF)) == Vector2.ZERO and position_only_point_after.is_equal_approx(position_only_point_before + Vector2(-3.0, 4.0)), "Position-only Asset Transform Rebase should bake translation while Scale is already normalized.")

	var anisotropic_component := _component()
	anisotropic_component.merge({"id": "anisotropic_body", "name": "anisotropic_body", "visibility": true, "parent_component_id": "", "group_id": "", "transform": {"position": Vector2(4.0, -3.0), "rotation": 23.0, "scale": Vector2.ONE, "pivot": Vector2(1.0, 2.0)}})
	BezierTopology.add_point(anisotropic_component, Vector2(2.0, 3.0), "corner")
	var anisotropic_asset := {"id": "anisotropic", "name": "anisotropic", "asset_pivot": Vector2(5.0, 7.0), "root_position": Vector2(1.0, -2.0), "root_scale": Vector2(2.0, 0.5), "components": [anisotropic_component], "groups": [], "guides": [], "animation": MotionWorkspace.create_default_animation_document()}
	var anisotropic_preview := AssetScaleRebaseService.root_transform(anisotropic_asset)
	var anisotropic_point_before := ComponentHierarchy.world_transform(anisotropic_asset, "anisotropic_body") * Vector2(anisotropic_component["points"][0]["position"])
	var anisotropic_result := AssetScaleRebaseService.rebase_asset(anisotropic_asset)
	var anisotropic_point_after := ComponentHierarchy.world_transform(anisotropic_asset, "anisotropic_body") * Vector2(ComponentHierarchy.component_by_id(anisotropic_asset, "anisotropic_body")["points"][0]["position"])
	_expect(bool(anisotropic_result.get("valid", false)) and Vector2(anisotropic_asset.get("root_scale", Vector2.ZERO)).is_equal_approx(Vector2.ONE) and anisotropic_point_after.is_equal_approx(anisotropic_preview * anisotropic_point_before), "Independent Asset-root X/Y Scale should preview and rebase both axes.")

	var blocked := asset.duplicate(true)
	blocked["root_scale"] = 2.0
	blocked["animation"]["states"][0]["cycle_duration"] = 9.0
	var blocked_snapshot := blocked.duplicate(true)
	_expect(not bool(AssetScaleRebaseService.rebase_asset(blocked).get("valid", true)) and blocked == blocked_snapshot, "Non-default authored Motion should block Root Scale Rebase without partially mutating the Asset.")

	var application = load("res://scripts/main.gd").new()
	application._build_ui()
	application.history_coalesce_timer = Timer.new()
	application.add_child(application.history_coalesce_timer)
	var ui_asset := asset.duplicate(true)
	ui_asset["root_position"] = Vector2(0.25, -0.4)
	ui_asset["root_scale"] = Vector2(3.6, 1.8)
	var ui_assets: Array[Dictionary] = [ui_asset]
	application.assets = ui_assets
	application.selected_asset_id = "root_scale"
	application.selected_component_id = ""
	application._render_inspector()
	_expect(is_instance_valid(application.create_inspector_view.asset_root_scale_fields["scale_x"]) and is_instance_valid(application.create_inspector_view.asset_root_scale_fields["scale_y"]) and is_equal_approx(application.create_inspector_view.asset_root_scale_fields["scale_x"].value, 3.6) and is_equal_approx(application.create_inspector_view.asset_root_scale_fields["scale_y"].value, 1.8) and is_equal_approx(application.create_inspector_view.asset_root_position_fields["position_x"].value, 2.5) and is_equal_approx(application.create_inspector_view.asset_root_position_fields["position_y"].value, -4.0) and is_instance_valid(application.create_inspector_view.asset_root_scale_rebase_button) and not application.create_inspector_view.asset_root_scale_rebase_button.disabled, "The Root Asset Inspector should expose independent X/Y Scale fields and enable its shared Rebase action.")
	application._on_rebase_asset_root_scale_pressed()
	_expect(Vector2(application._get_asset("root_scale").get("root_position", Vector2.INF)) == Vector2.ZERO and Vector2(application._get_asset("root_scale").get("root_scale", Vector2.ZERO)).is_equal_approx(Vector2.ONE) and application.create_inspector_view.asset_root_scale_rebase_button.disabled, "The Root Asset Inspector Rebase action should bake Position and both Scale axes and normalize both fields.")
	application._undo()
	_expect(Vector2(application._get_asset("root_scale").get("root_position", Vector2.ZERO)) == Vector2(0.25, -0.4) and Vector2(application._get_asset("root_scale").get("root_scale", Vector2.ZERO)).is_equal_approx(Vector2(3.6, 1.8)), "Undo should restore the complete pre-Rebase Asset Root Transform authoring state.")
	application._redo()
	_expect(Vector2(application._get_asset("root_scale").get("root_position", Vector2.INF)) == Vector2.ZERO and Vector2(application._get_asset("root_scale").get("root_scale", Vector2.ZERO)).is_equal_approx(Vector2.ONE), "Redo should restore the atomically rebased Asset Root Transform state.")
	application.free()


func _test_asset_authored_facing() -> void:
	var serialized_values := ["left", "right", "neutral", "top", "down"]
	for serialized_value in serialized_values:
		var facing := AssetPresentation.deserialize_authored_facing(serialized_value)
		_expect(AssetPresentation.serialize_authored_facing(facing) == serialized_value, "Authored Facing '%s' should round-trip through its typed enum representation." % serialized_value)
	_expect(AssetPresentation.authored_facing({}) == AssetPresentation.AuthoredFacing.NEUTRAL, "An older Asset without authored_facing should load as Neutral.")
	_expect(AssetPresentation.deserialize_authored_facing("unsupported") == AssetPresentation.AuthoredFacing.NEUTRAL, "An invalid legacy authored_facing value should normalize safely to Neutral.")

	var application = load("res://scripts/main.gd").new()
	application._build_ui()
	application.history_coalesce_timer = Timer.new()
	application.add_child(application.history_coalesce_timer)
	var pose_assets: Array[Dictionary] = [{"id": "pose_asset", "name": "Pose Asset", "asset_type": "character", "visibility": true, "asset_pivot": Vector2.ZERO, "components": [], "groups": [], "guides": []}]
	application.assets = pose_assets
	application.selected_asset_id = "pose_asset"
	application._render_inspector()
	var inspector_text := _control_text(application.inspector_content)
	_expect(inspector_text.contains("Initial Pose") and is_instance_valid(application.create_inspector_view.asset_authored_facing_option) and str(application.create_inspector_view.asset_authored_facing_option.get_item_metadata(application.create_inspector_view.asset_authored_facing_option.selected)) == "neutral", "The Asset Inspector should expose Initial Pose and select Neutral for an older Asset.")
	var down_index := AssetPresentation.SERIALIZED_VALUES.find("down")
	application._on_asset_authored_facing_selected(down_index, application.create_inspector_view.asset_authored_facing_option)
	_expect(AssetPresentation.serialize_authored_facing(application._get_asset("pose_asset").get("authored_facing")) == "down" and application.undo_history.size() == 1, "Changing Authored Facing in the Inspector should store the selected value and capture one Undo snapshot.")
	application._undo()
	_expect(AssetPresentation.authored_facing(application._get_asset("pose_asset")) == AssetPresentation.AuthoredFacing.NEUTRAL, "Undo should restore the previous Asset-level Authored Facing.")
	application._redo()
	_expect(AssetPresentation.serialize_authored_facing(application._get_asset("pose_asset").get("authored_facing")) == "down", "Redo should restore the Inspector-authored facing value.")
	application.free()


func _find_named_control(root: Node, target_name: String) -> Control:
	if root is Control and str(root.name) == target_name:
		return root
	for child in root.get_children():
		var found := _find_named_control(child, target_name)
		if is_instance_valid(found):
			return found
	return null


func _test_multi_component_inspector() -> void:
	var first := _component()
	first.merge({"id": "first", "name": "first", "visibility": true, "z_index": 1, "projection_depth_cm": 8.0, "transform": {"position": Vector2(5.0, 10.0), "pivot": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE}})
	var second := _component()
	second.merge({"id": "second", "name": "second", "visibility": false, "z_index": 2, "projection_depth_cm": 12.0, "transform": {"position": Vector2(15.0, 20.0), "pivot": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE}})
	var asset := {"id": "multi_asset", "name": "Multi Asset", "asset_type": "character", "visibility": true, "asset_pivot": Vector2(1.0, 2.0), "components": [first, second], "groups": [], "guides": []}
	var application = load("res://scripts/main.gd").new()
	application._build_ui()
	var multi_assets: Array[Dictionary] = [asset]
	application.assets = multi_assets
	application.selected_asset_id = "multi_asset"
	application.selected_component_id = "first"
	var multi_selection: Array[String] = ["first", "second"]
	application.selected_component_ids = multi_selection
	application._render_inspector()
	var inspector_text := _control_text(application.inspector_content)
	_expect(inspector_text.contains("2 Components") and inspector_text.contains("Multi-Edit") and inspector_text.contains("Mixed"), "Selecting multiple Components should render a dedicated Multi-Edit Inspector with mixed-value hints.")
	var z_field := _find_named_control(application.inspector_content, "MultiZIndex") as LineEdit
	var projection_depth_field := _find_named_control(application.inspector_content, "MultiProjectionDepth") as LineEdit
	var x_field := _find_named_control(application.inspector_content, "MultiPositionX") as LineEdit
	_expect(is_instance_valid(z_field) and z_field.placeholder_text == "Mixed" and is_instance_valid(projection_depth_field) and projection_depth_field.placeholder_text == "Mixed" and is_instance_valid(x_field) and x_field.placeholder_text == "Mixed", "Mixed Z Index, Projection Depth, and asset-relative Position fields should be exposed explicitly.")
	application._on_multi_component_z_index_changed(7.0)
	_expect(int(application._get_component(asset, "first").get("z_index", 0)) == 7 and int(application._get_component(asset, "second").get("z_index", 0)) == 7 and application.undo_history.size() == 1, "A shared Z Index edit should update all selected Components in one undo step.")
	application._on_multi_component_projection_depth_changed(25.0)
	_expect(is_equal_approx(float(application._get_component(asset, "first").get("projection_depth_cm", 0.0)), 25.0) and is_equal_approx(float(application._get_component(asset, "second").get("projection_depth_cm", 0.0)), 25.0) and application.undo_history.size() == 2, "A shared Projection Depth edit should update all selected Components in one undo step.")
	application._on_multi_component_position_changed(30.0, "position_x")
	var first_world := ComponentHierarchy.world_transform_record(asset, "first")
	var second_world := ComponentHierarchy.world_transform_record(asset, "second")
	_expect(is_equal_approx(float(first_world.get("position", Vector2.ZERO).x), 4.0) and is_equal_approx(float(second_world.get("position", Vector2.ZERO).x), 4.0), "A shared Position X edit should use the Asset pivot as the (0, 0) origin.")
	application._on_multi_component_visibility_selected(0)
	_expect(bool(application._get_component(asset, "first").get("visibility", false)) and bool(application._get_component(asset, "second").get("visibility", false)), "A shared Visibility edit should update every selected Component.")
	application.free()


func _test_multi_component_deletion() -> void:
	var parent := _component()
	parent.merge({"id": "parent", "name": "parent", "type": "component", "parent_component_id": "", "visibility": true, "transform": {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}})
	var child := _component()
	child.merge({"id": "child", "name": "child", "type": "component", "parent_component_id": "parent", "visibility": true, "transform": {"position": Vector2.ONE, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}})
	var sibling := _component()
	sibling.merge({"id": "sibling", "name": "sibling", "type": "component", "parent_component_id": "", "visibility": true, "transform": {"position": Vector2(2.0, 0.0), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}})
	var survivor := _component()
	survivor.merge({"id": "survivor", "name": "survivor", "type": "component", "parent_component_id": "", "catch_parent_component_id": "child", "visibility": true, "transform": {"position": Vector2(3.0, 0.0), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}})
	var guides := [
		{"id": "parent_guide", "scope": {"component_id": "parent"}},
		{"id": "child_guide", "scope": {"component_id": "child"}},
		{"id": "sibling_guide", "scope": {"component_id": "sibling"}},
		{"id": "survivor_guide", "scope": {"component_id": "survivor"}}
	]
	var asset := {"id": "asset", "name": "Asset", "asset_type": "character", "visibility": true, "asset_pivot": Vector2.ZERO, "components": [parent, child, sibling, survivor], "groups": [], "guides": guides}
	var application = load("res://scripts/main.gd").new()
	application._build_ui()
	var test_assets: Array[Dictionary] = [asset]
	application.assets = test_assets
	application.active_module = "Create"
	application.active_create_submodule = "Character"
	application.selected_asset_id = "asset"
	application.selected_component_id = "sibling"
	var deletion_selection: Array[String] = ["parent", "child", "sibling"]
	application.selected_component_ids = deletion_selection
	var deletion_roots: Array[String] = application._selected_component_ids_for_group(asset)
	_expect(deletion_roots == ["parent", "sibling"] and application._component_deletion_set(asset, deletion_roots).size() == 3, "Multi-delete should collapse a selected Child into its already selected Parent subtree and count every Component once.")
	application.component_remove_dialog = null
	application._delete_selected_component()
	_expect(asset.get("components", []).size() == 1 and str(asset.get("components", [])[0].get("id", "")) == "survivor", "Confirming multi-delete should remove every selected Component subtree in one operation.")
	_expect(asset.get("guides", []).size() == 1 and str(asset.get("guides", [])[0].get("id", "")) == "survivor_guide", "Multi-delete should remove Guides scoped to any deleted Component.")
	_expect(str(survivor.get("catch_parent_component_id", "")) == "" and application.undo_history.size() == 1, "Multi-delete should clear surviving Catch Parent links and create one Undo step.")
	application.free()


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var delta := end - start
	if delta.length_squared() <= 0.000000000001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return point.distance_to(start + delta * t)


func _outliner_test_component(component_id: String, component_name: String) -> Dictionary:
	var component := _component()
	BezierTopology.add_point(component, Vector2.ZERO, "corner")
	BezierTopology.add_point(component, Vector2(10.0, 0.0), "linear")
	BezierTopology.add_point(component, Vector2(10.0, 10.0), "linear")
	BezierTopology.close_active_chain(component)
	component.merge({"id": component_id, "name": component_name, "visibility": true})
	return component


func _test_outliner_selection_wiring() -> void:
	# Every Outliner row reaches its handler through a signal connection the
	# parser cannot check. These press the rows the Outliner actually builds, so
	# a broken connection fails here instead of only under the mouse.
	var body := _outliner_test_component("component_1", "body")
	var arm := _outliner_test_component("component_2", "arm")
	var guide := {"id": "guide_1", "guide_type": AssetGuide.SAMPLE, "ordinal": 1, "visibility": true,
		"scope": {"kind": "component", "component_id": "component_1"},
		"points": [], "edges": [], "chains": []}
	var group := {"id": "group_1", "name": "torso", "transform": {}, "visibility": true, "parent_component_id": ""}
	var asset := {"id": "asset_1", "name": "Wizard", "visibility": true, "components": [body, arm], "groups": [group], "guides": [guide]}
	var second_asset := {"id": "asset_2", "name": "Rogue", "visibility": true, "components": [], "groups": [], "guides": []}

	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	var test_assets: Array[Dictionary] = [asset, second_asset]
	application.assets = test_assets

	# Create. Expanding an Asset focuses the Outliner on it, so the Asset row of
	# a second Asset is only reachable while nothing is expanded.
	application.active_module = "Create"
	application._render_outliner()
	_expect(_press_outliner_button(application, "Rogue"), "The Create Outliner should offer a row per Asset while nothing is expanded.")
	_expect(application.selected_asset_id == "asset_2" and application.active_module == "Create", "Pressing an Asset row should select that Asset.")

	application._select_asset("asset_1")
	application._set_outliner_asset_expanded("asset_1", true)
	application._render_outliner()
	_expect(_press_outliner_button(application, "arm"), "The Create Outliner should offer a Component row.")
	_expect(application.selected_component_id == "component_2", "Pressing a Component row should select that Component.")
	application._render_outliner()
	_expect(_press_outliner_button(application, "G: torso"), "The Create Outliner should offer a Group row.")
	_expect(application.selected_group_id == "group_1", "Pressing a Group row should select that Group.")
	application._render_outliner()
	_expect(_press_outliner_button(application, AssetGuide.outliner_name(guide, "body")), "The Create Outliner should offer a Guide row.")
	_expect(application.selected_guide_id == "guide_1", "Pressing a Guide row should select that Guide.")

	# Mesh
	application.active_module = "Mesh"
	application.active_geometry_submodule = "Sampling"
	application.selected_asset_id = ""
	application.selected_component_id = ""
	application.expanded_assets.clear()
	application._render_outliner()
	_expect(_press_outliner_button(application, "Wizard"), "The Mesh Outliner should offer an Asset row.")
	_expect(application.selected_asset_id == "asset_1", "Pressing a Mesh Asset row should select that Asset.")
	application._set_outliner_asset_expanded("asset_1", true)
	application._render_outliner()
	_expect(_press_outliner_button(application, "body"), "The Mesh Outliner should offer a Component row.")
	_expect(application.selected_component_id == "component_1" and application.selected_guide_id.is_empty(), "Pressing a Mesh Component row should select that Component.")

	# The Mesh tree renders from a row model, so its rows reach their handlers
	# through their own signals and need the same cover.
	application.active_geometry_submodule = "Seeding"
	application._render_outliner()
	_expect(_press_outliner_button(application, "Outer · body"), "The Seeding tree should offer the Outer input row.")
	# The Outer contour has no input record of its own: its row carries an empty
	# input id and the tree never marks it selected. Pressing it therefore
	# selects no Sampling input. Which rows do is asserted for Hole, Cut and
	# Spine in _test_sampling_input_kind_from_seeding_selection.
	_expect(application.selected_sampling_input_id.is_empty()
		and application.selected_sampling_input_kind.is_empty(),
		"Pressing the Outer row should leave no Sampling input selected.")

	# Style
	application.active_module = "Style"
	application.active_style_submodule = "Weighting"
	application.selected_asset_id = ""
	application.selected_component_id = ""
	application.expanded_assets.clear()
	application._render_outliner()
	_expect(_press_outliner_button(application, "Wizard"), "The Style Outliner should offer an Asset row.")
	_expect(application.selected_asset_id == "asset_1", "Pressing a Style Asset row should select that Asset.")
	application._set_outliner_asset_expanded("asset_1", true)
	application._render_outliner()
	_expect(_press_outliner_button(application, "body ·"), "The Style Outliner should offer a Component row carrying its Mesh state.")
	_expect(application.selected_component_id == "component_1" and application.selected_weighting_style_id.is_empty(), "Pressing a Style Component row should select that Component and clear the Style.")

	application._create_weighting_style("asset_1", "component_1")
	var styles: Array = application._weighting_styles("asset_1", "component_1")
	_expect(styles.size() == 1, "Creating a Weighting Style should record exactly one Style on the Component.")
	application.selected_weighting_style_id = ""
	application._render_outliner()
	var created: Dictionary = styles[0]
	_expect(_press_outliner_button(application, str(created.get("name", "")) + " ·"), "The Style Outliner should offer a Style row.")
	_expect(application.selected_weighting_style_id == str(created.get("id", "")), "Pressing a Style row should select that Style.")

	application.free()


func _test_inspector_field_wiring() -> void:
	# Inspector fields reach the document through signal connections the parser
	# cannot check. These drive the field and assert the document changed, so a
	# field wired to the wrong property fails here rather than under the mouse.
	var body := _outliner_test_component("component_1", "body")
	body["transform"] = {"position": Vector2(3.0, 4.0), "rotation": 15.0, "scale": Vector2(1.5, 2.0), "pivot": Vector2.ZERO}
	body["draw_mode"] = "contour"
	var asset := {"id": "asset_1", "name": "Wizard", "visibility": true, "components": [body], "groups": [], "guides": [],
		"asset_pivot": Vector2(5.0, 6.0), "root_position": Vector2.ZERO, "root_scale": Vector2.ONE}
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	var test_assets: Array[Dictionary] = [asset]
	application.assets = test_assets
	application.selected_asset_id = "asset_1"
	application.active_module = "Create"

	# Asset level: pivot and the authoring-only root transform.
	application.selected_component_id = ""
	application._render_inspector()
	_expect(application.create_inspector_view.asset_pivot_fields.has("pivot_x"), "The Asset Inspector should expose its Pivot fields.")
	_edit_inspector_value(application.create_inspector_view.asset_pivot_fields["pivot_x"], 9.0)
	_expect(is_equal_approx(Vector2(asset["asset_pivot"]).x, application._world_to_editor_units(9.0)), "The Asset Pivot X field should write the Asset pivot.")
	_edit_inspector_value(application.create_inspector_view.asset_root_position_fields["position_y"], 7.0)
	_expect(is_equal_approx(Vector2(AssetScaleRebaseService.root_position(asset)).y, application._world_to_editor_units(7.0)), "The Root Position Y field should write the Asset root position.")
	_edit_inspector_value(application.create_inspector_view.asset_root_scale_fields["scale_x"], 2.5)
	_expect(is_equal_approx(Vector2(AssetScaleRebaseService.root_scale(asset)).x, 2.5), "The Root Scale X field should write the Asset root scale.")
	_expect(is_instance_valid(application.create_inspector_view.asset_name_editor), "The Asset Inspector should expose its name editor.")
	application._rename_selected_asset("Sorcerer")
	_expect(str(asset["name"]) == "Sorcerer", "The Asset name editor should rename the Asset.")

	# Component level: transform, then the properties that reach the document.
	application.selected_component_id = "component_1"
	application._render_inspector()
	for entry in [["position_x", 11.0], ["position_y", 12.0]]:
		_expect(application.create_inspector_view.transform_fields.has(entry[0]), "The Component Inspector should expose %s." % entry[0])
		_edit_inspector_value(application.create_inspector_view.transform_fields[entry[0]], float(entry[1]))
	var moved: Vector2 = body["transform"]["position"]
	_expect(is_equal_approx(moved.x, application._world_to_editor_units(11.0)) and is_equal_approx(moved.y, application._world_to_editor_units(12.0)), "The Component position fields should write the Component transform.")
	_edit_inspector_value(application.create_inspector_view.transform_fields["rotation"], 42.0)
	_expect(is_equal_approx(float(body["transform"]["rotation"]), 42.0), "The Component rotation field should write the Component transform.")
	_edit_inspector_value(application.create_inspector_view.transform_fields["scale_x"], 3.0)
	_expect(is_equal_approx(Vector2(body["transform"]["scale"]).x, 3.0), "The Component scale field should write the Component transform.")

	var depth_field := _inspector_spin(application, "Projection Depth (cm)")
	_expect(depth_field != null, "A visible Component should expose its Projection Depth.")
	_edit_inspector_value(depth_field, 24.0)
	_expect(is_equal_approx(float(body.get("projection_depth_cm", 0.0)), 24.0), "The Projection Depth field should write the Component.")

	var width_field := _inspector_spin(application, "Contour Stroke Width (px)")
	_expect(width_field != null, "A Contour Component should expose its Stroke Width.")
	_edit_inspector_value(width_field, application.world_contour_stroke_width_px + 3.0)
	_expect(is_equal_approx(float(body.get("contour_stroke_width_px", 0.0)), application.world_contour_stroke_width_px + 3.0), "The Contour Stroke Width field should write the Component override.")

	application._rename_selected_component("arm")
	_expect(str(body["name"]) == "arm", "The Component name editor should rename the Component.")

	# Point level: a single selection edits absolute positions, a multi selection
	# offsets every selected Point by the same delta and resets its field.
	application.active_state = "edit"
	application.active_edit_mode = "point"
	var point_ids: Array[String] = []
	for point in body["points"]:
		point_ids.append(str(point["id"]))
	var single_selection: Array[String] = [point_ids[0]]
	application.selected_point_ids = single_selection
	application.selected_point_id = point_ids[0]
	application._render_inspector()
	var point_position_field := _inspector_spin(application, "Position X (cm)")
	_expect(point_position_field != null, "A selected Point should expose its Position X.")
	_edit_inspector_value(point_position_field, 17.0)
	_expect(is_equal_approx(Vector2(BezierTopology.point_by_id(body["points"], point_ids[0])["position"]).x,
		application._world_to_editor_units(17.0)), "The Point Position X field should move the selected Point.")

	var multi_selection: Array[String] = [point_ids[0], point_ids[1]]
	application.selected_point_ids = multi_selection
	application._render_inspector()
	var first_before: Vector2 = BezierTopology.point_by_id(body["points"], point_ids[0])["position"]
	var second_before: Vector2 = BezierTopology.point_by_id(body["points"], point_ids[1])["position"]
	var delta_field := _inspector_spin(application, "Delta X (cm)")
	_expect(delta_field != null, "A multi-Point selection should expose its Delta X.")
	_edit_inspector_value(delta_field, 5.0)
	var expected_delta: float = application._world_to_editor_units(5.0)
	var first_after: Vector2 = BezierTopology.point_by_id(body["points"], point_ids[0])["position"]
	var second_after: Vector2 = BezierTopology.point_by_id(body["points"], point_ids[1])["position"]
	_expect(is_equal_approx(first_after.x - first_before.x, expected_delta)
		and is_equal_approx(second_after.x - second_before.x, expected_delta),
		"The Delta X field should offset every selected Point by the same amount.")
	_expect(is_zero_approx(delta_field.value), "The Delta field should reset itself after applying the offset.")

	# Edge level: one toggle writes every selected Edge.
	application.active_edit_mode = "edge"
	var edge_ids: Array[String] = []
	for edge in body["edges"]:
		edge_ids.append(str(edge["id"]))
	var selected_edges: Array[String] = [edge_ids[0], edge_ids[1]]
	application.selected_edge_ids = selected_edges
	application._render_inspector()
	var outline_toggle := _inspector_toggle(application, "Render Outline")
	_expect(outline_toggle != null, "An Edge selection should expose its Render Outline toggle.")
	_press_inspector_toggle(outline_toggle, false)
	_expect(not bool(application._get_edge(body, edge_ids[0]).get("render_outline", true))
		and not bool(application._get_edge(body, edge_ids[1]).get("render_outline", true)),
		"The Render Outline toggle should write every selected Edge.")

	# Back at Component level: the toggle and the stacked numeric fields.
	application.active_state = "select"
	application.active_edit_mode = ""
	var no_edges: Array[String] = []
	application.selected_edge_ids = no_edges
	# Rendering mirrors the plural selection into the singular id, so both have
	# to be cleared to leave the Edge Inspector.
	application.selected_edge_id = ""
	application._render_inspector()
	var visibility_toggle := _inspector_toggle(application, "Visible")
	_expect(visibility_toggle != null, "A selected Component should expose its Visible toggle.")
	_press_inspector_toggle(visibility_toggle, false)
	_expect(not bool(body.get("visibility", true)), "The Visible toggle should write the Component.")
	var z_order_field := _inspector_spin(application, "Z Order (Asset-local)")
	_expect(z_order_field != null, "A selected Component should expose its Z Order.")
	_edit_inspector_value(z_order_field, 5.0)
	_expect(int(body.get("z_index", 0)) == 5, "The Z Order field should write the Component.")
	application.free()


func _test_geometry_outliner_rows() -> void:
	# The Mesh tree is built as data and rendered generically, so the row model is
	# what has to be right. These pin the strings each row kind produces.
	var body := _outliner_test_component("component_1", "body")
	body["topology_role"] = "outer"
	var hole := {"points": [], "edges": [], "chains": [], "id": "component_2", "name": "eye",
		"visibility": true, "type": "reference", "parent_component_id": "component_1",
		"topology_role": "hole", "source_asset_id": "asset_2"}
	var direct_hole := {"points": [], "edges": [], "chains": [], "id": "component_3", "name": "opening",
		"visibility": true, "type": "component", "draw_mode": "primitive", "parent_component_id": "component_1",
		"topology_role": "hole", "primitive": {"type": "circle", "center": Vector2.ZERO, "diameter_cm": 10.0},
		"transform": WorldDocumentService.default_component_transform()}
	var cut := {"id": "guide_1", "guide_type": AssetGuide.CUT, "ordinal": 1, "visibility": true,
		"scope": {"kind": "component", "component_id": "component_1"}, "points": [], "edges": [], "chains": []}
	var spine := {"id": "guide_2", "guide_type": AssetGuide.SAMPLER_SPINE, "ordinal": 1, "visibility": true,
		"scope": {"kind": "component", "component_id": "component_1"}, "points": [], "edges": [], "chains": []}
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	var test_assets: Array[Dictionary] = [
		{"id": "asset_1", "name": "Wizard", "visibility": true, "components": [body, hole, direct_hole], "groups": [], "guides": [cut, spine]},
		{"id": "asset_2", "name": "Orb", "visibility": true, "components": [], "groups": [], "guides": []}]
	application.assets = test_assets
	application.active_module = "Mesh"
	application.expanded_assets["asset_1"] = true

	application.active_geometry_submodule = "Sampling"
	application._render_outliner()
	var sampling_rows: Array = application.outliner_view.geometry_rows
	_expect(_geometry_row_label(sampling_rows, "asset") == "Wizard", "The Mesh tree should open with a row per visible Asset.")
	_expect(_geometry_row_label(sampling_rows, "component") == "body", "The Mesh tree should list meshable Components.")
	_expect(_geometry_row_label(sampling_rows, "hole").begins_with("Hole · eye ← Orb"), "A Sampling Hole row should name the referenced Asset.")
	var sampling_hole_count := sampling_rows.filter(func(row: Dictionary) -> bool: return str(row.get("kind", "")) == "hole").size()
	_expect(sampling_hole_count == 2, "Sampling should nest both Reference and ordinary Hole constraints beneath their Body.")
	_expect(_geometry_row_label(sampling_rows, "guide").begins_with("Cut · "), "A Sampling Cut row should name its Guide.")

	application.active_geometry_submodule = "Seeding"
	var doc: Dictionary = application._mutable_geometry_document("asset_1", "component_1")
	doc["seeding"]["recipe"]["method"] = GeometrySeedingService.SPINE_FLOW
	doc["seeding"]["recipe"]["parameters"]["spine_inputs"] = [{"guide_id": "guide_2", "enabled": true}]
	application._render_outliner()
	var seeding_rows: Array = application.outliner_view.geometry_rows
	var treatments: Array[String] = []
	for row_data in seeding_rows:
		if str(row_data.get("kind", "")) == "input":
			treatments.append(str(row_data.get("label", "")))
	_expect(treatments.size() == 5, "Seeding should list the Outer, both Holes, Cut and Spine inputs of the Component.")
	_expect(treatments[0].contains("Outer · body") and treatments[0].contains("Clearance"), "The Outer input row should be shown with Clearance.")
	_expect(treatments[1].contains("Hole · eye ← Orb") and treatments[1].contains("Excluded"), "A Hole input row should be shown as Excluded, not as Clearance.")
	_expect(treatments[2].contains("Hole · opening") and treatments[2].contains("Excluded"), "An ordinary Hole Component should use the same excluded treatment as a Hole Reference.")
	_expect(treatments[3].contains("Cut · ") and treatments[3].contains("Barrier"), "A Cut input row should be shown as a Barrier.")
	_expect(treatments[4].contains("Spine · ") and treatments[4].contains("Enabled"), "An enabled Spine input row should be shown as Enabled.")
	doc["seeding"]["recipe"]["parameters"]["spine_inputs"] = [{"guide_id": "guide_2", "enabled": false}]
	application._render_outliner()
	var disabled_rows: Array = application.outliner_view.geometry_rows
	var spine_label := ""
	for row_data in disabled_rows:
		if str(row_data.get("kind", "")) == "input" and str(row_data.get("role", "")) == "spine":
			spine_label = str(row_data.get("label", ""))
	_expect(spine_label.contains("Disabled"), "A disabled Spine input row should be shown as Disabled.")

	application.active_geometry_submodule = "Meshing"
	application._render_outliner()
	var meshing_rows: Array = application.outliner_view.geometry_rows
	var meshing_component_count := meshing_rows.filter(func(row: Dictionary) -> bool: return str(row.get("kind", "")) == "component").size()
	var pipeline: Array[String] = []
	for row_data in meshing_rows:
		if str(row_data.get("kind", "")) == "pipeline":
			pipeline.append(str(row_data.get("label", "")))
	_expect(meshing_component_count == 1 and pipeline.size() == 4, "Meshing should list one Body and its four pipeline rows without presenting an ordinary Hole as its own Body.")
	_expect(pipeline[0].begins_with("Sampling · Adaptive") and pipeline[3].begins_with("Mesh · Constrained Mesh"), "The Meshing pipeline rows should run from Sampling to the Mesh result.")
	var mesh_action := ""
	for row_data in meshing_rows:
		if str(row_data.get("kind", "")) == "pipeline" and str(row_data.get("label", "")).begins_with("Mesh · "):
			mesh_action = str(row_data.get("action_id", ""))
	_expect(mesh_action.is_empty(), "The Mesh result row carries no action, so the view renders it disabled.")
	application.free()


func _geometry_row_label(rows: Array, kind: String) -> String:
	for row_data in rows:
		if str(row_data.get("kind", "")) == kind:
			return str(row_data.get("label", ""))
	return ""


func _test_render_invalidation() -> void:
	var component := _component()
	BezierTopology.add_point(component, Vector2.ZERO, "corner")
	BezierTopology.add_point(component, Vector2(10.0, 0.0), "linear")
	BezierTopology.add_point(component, Vector2(10.0, 10.0), "linear")
	BezierTopology.close_active_chain(component)
	component.merge({"id": "component_1", "name": "body", "visibility": true})
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	var test_assets: Array[Dictionary] = [{"id": "asset_1", "name": "Wizard", "visibility": true, "components": [component], "guides": [], "groups": []}]
	application.assets = test_assets
	application.selected_asset_id = "asset_1"
	application.expanded_assets["asset_1"] = true

	application._invalidate_render(application.RENDER_DOCUMENT)
	_expect(application.pending_renders == 0, "Invalidating must render before it returns, so a caller can consume the result in the next statement.")

	# Several call sites read what the render just built. The Weighting shortcut
	# opens the Context Bar menu that the same render replaces.
	application.active_module = "Style"
	application.active_style_submodule = "Weighting"
	application._set_active_context_command("style.weighting.method")
	application._invalidate_render(application.RENDER_CONTEXT_BAR)
	var opened_menu: MenuButton = application.weighting_method_menu
	_expect(is_instance_valid(opened_menu) and opened_menu.get_parent() == application.context_bar, "The Context Bar menu a shortcut opens must be the one the invalidation just installed, not the previous instance.")
	# Rendering again replaces it; the reference a caller took before the render
	# would be the stale one, which is why the flush cannot be deferred.
	application._invalidate_render(application.RENDER_CONTEXT_BAR)
	_expect(application.weighting_method_menu != opened_menu, "A Context Bar render replaces its menus, so the caller must read them after the render, not before.")

	# A render may invalidate again; that must not re-enter the flush.
	application.rendering = true
	application._invalidate_render(application.RENDER_INFO_BAR)
	_expect(application.pending_renders == application.RENDER_INFO_BAR, "Invalidating during a render should only record the target.")
	application.rendering = false
	application._flush_pending_renders()
	_expect(application.pending_renders == 0, "The recorded target should be rendered by the next flush.")

	_expect(application.RENDER_DOCUMENT == application.RENDER_OUTLINER | application.RENDER_INSPECTOR | application.RENDER_CANVAS_CONTEXT, "RENDER_DOCUMENT should name the Outliner, Inspector, and Canvas combination.")
	application.free()


func _test_atomic_document_writes() -> void:
	var application = load("res://scripts/main.gd").new()
	var root := "user://polytools_atomic_write_test"
	var target := "%s/record.json" % root
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	if FileAccess.file_exists(target):
		DirAccess.remove_absolute(target)

	_expect(WorldDocumentService.write_json(target, {"schema_version": 1, "value": "first"}), "Writing a record to a writable path should report success.")
	_expect(str(WorldDocumentService.read_json(target).get("value", "")) == "first", "A written record should read back with its content.")

	_expect(WorldDocumentService.write_json(target, {"schema_version": 1, "value": "second"}), "Replacing an existing record should report success.")
	_expect(str(WorldDocumentService.read_json(target).get("value", "")) == "second", "Replacing a record should leave the new content in place.")

	var staging := "%s/.record.json.staging" % root
	var backup := "%s/.record.json.backup" % root
	_expect(not FileAccess.file_exists(staging) and not FileAccess.file_exists(backup), "A completed write should leave no staging or backup residue beside the record.")

	# A directory standing where the record belongs makes the swap fail without
	# a crash, which is the failure the caller has to be able to observe.
	var blocked := "%s/blocked.json" % root
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked))
	_expect(not WorldDocumentService.write_json(blocked, {"schema_version": 1}), "A record that cannot be written must report failure instead of reporting success.")
	_expect(not FileAccess.file_exists("%s/.blocked.json.staging" % root), "A failed write should not leave its staging file behind.")

	# An interrupted swap leaves a backup without its target. The next write has
	# to recover that content rather than starting from nothing.
	_expect(WorldDocumentService.write_json(target, {"schema_version": 1, "value": "third"}), "Preparing the interrupted-swap case should succeed.")
	DirAccess.rename_absolute(target, backup)
	_expect(not FileAccess.file_exists(target) and FileAccess.file_exists(backup), "The interrupted-swap case should start with a backup and no target.")
	_expect(WorldDocumentService.write_json(target, {"schema_version": 1, "value": "fourth"}), "A write after an interrupted swap should succeed.")
	_expect(str(WorldDocumentService.read_json(target).get("value", "")) == "fourth", "A write after an interrupted swap should leave the new content in place.")
	_expect(not FileAccess.file_exists(backup), "Recovering from an interrupted swap should consume the backup.")

	_expect(application._incomplete_save_message(["a.json"] as Array[String]).contains("a.json"), "A single unwritten record should be named in the status message.")
	var many: Array[String] = ["a.json", "b.json", "c.json"]
	_expect(application._incomplete_save_message(many).contains("a.json") and application._incomplete_save_message(many).contains("2 more"), "Several unwritten records should name the first and count the rest.")

	DirAccess.remove_absolute(target)
	DirAccess.remove_absolute(blocked)
	DirAccess.remove_absolute(root)
	application.free()


func _test_geometry_document_history_isolation() -> void:
	var component := _component()
	BezierTopology.add_point(component, Vector2.ZERO, "corner")
	BezierTopology.add_point(component, Vector2(10.0, 0.0), "linear")
	BezierTopology.add_point(component, Vector2(10.0, 10.0), "linear")
	BezierTopology.close_active_chain(component)
	component.merge({"id": "component_1", "name": "body", "visibility": true})
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	var test_assets: Array[Dictionary] = [{"id": "asset_1", "name": "Wizard", "visibility": true, "components": [component]}]
	application.assets = test_assets
	application.selected_asset_id = "asset_1"
	application.selected_component_id = "component_1"
	var key: String = application._geometry_document_key("asset_1", "component_1")

	var live: Dictionary = application._mutable_geometry_document("asset_1", "component_1")
	live["sampling"]["recipe"]["parameters"]["feature_detail"] = 0.25

	application._record_direct_change()
	var snapshot: Dictionary = application.undo_history.back().get("geometry_documents", {})
	# is_same, not ==: Dictionary equality compares by value and would pass even
	# if the snapshot had deep-copied the document.
	_expect(is_same(snapshot[key], live), "Recording a change must not copy a geometry document that nothing has mutated yet.")

	var mutable: Dictionary = application._mutable_geometry_document("asset_1", "component_1")
	_expect(is_same(mutable, live), "Write access must keep the live document's identity, so references held across a recorded change stay valid.")
	_expect(not is_same(snapshot[key], live), "Write access must hand the sharing snapshot its own copy of the document.")
	mutable["sampling"]["recipe"]["parameters"]["feature_detail"] = 0.75
	_expect(is_equal_approx(float(snapshot[key]["sampling"]["recipe"]["parameters"]["feature_detail"]), 0.25), "Mutating the live document must not reach into the snapshot that preceded it.")

	application._undo()
	_expect(is_equal_approx(float(application._get_geometry_document("asset_1", "component_1")["sampling"]["recipe"]["parameters"]["feature_detail"]), 0.25), "Undo must restore the geometry document recorded in the snapshot.")
	application._redo()
	_expect(is_equal_approx(float(application._get_geometry_document("asset_1", "component_1")["sampling"]["recipe"]["parameters"]["feature_detail"]), 0.75), "Redo must restore the geometry document captured before the Undo.")

	application._record_direct_change()
	var created: Dictionary = application._mutable_geometry_document("asset_1", "component_2")
	_expect(not created.is_empty() and application.geometry_documents.has(application._geometry_document_key("asset_1", "component_2")), "Requesting write access for an unknown Component should create its geometry document.")
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
	application._build_ui()
	var direct_ancestor := {"id": "direct_ancestor", "name": "bottle", "type": "component", "draw_mode": "primitive", "topology_role": "outer", "parent_component_id": "", "group_id": "tier1", "visibility": true, "primitive": {"type": "circle", "center": Vector2.ZERO, "diameter_cm": 200.0}, "points": [], "edges": [], "chains": [], "transform": WorldDocumentService.default_component_transform()}
	var direct_body := {"id": "direct_body", "name": "body_opening01", "type": "component", "draw_mode": "primitive", "topology_role": "outer", "parent_component_id": "direct_ancestor", "group_id": "tier1", "visibility": true, "primitive": {"type": "circle", "center": Vector2.ZERO, "diameter_cm": 100.0}, "points": [], "edges": [], "chains": [], "transform": WorldDocumentService.default_component_transform()}
	var direct_hole := {"id": "direct_hole", "name": "body_opening_hole01", "type": "component", "draw_mode": "primitive", "topology_role": "hole", "parent_component_id": "direct_body", "group_id": "tier1", "visibility": true, "primitive": {"type": "circle", "center": Vector2.ZERO, "diameter_cm": 20.0}, "points": [], "edges": [], "chains": [], "transform": {"position": Vector2(1.5, -0.5), "rotation": 20.0, "scale": Vector2(1.2, 0.7), "pivot": Vector2.ZERO}}
	var direct_hole_asset := {"id": "direct_hole_asset", "name": "Potion", "visibility": true, "components": [direct_ancestor, direct_body, direct_hole], "groups": [{"id": "tier1", "name": "tier1", "visibility": true, "parent_component_id": "", "transform": {"position": Vector2(4.0, -3.0), "rotation": 12.0, "scale": Vector2(1.25, 0.8), "pivot": Vector2.ONE}}], "guides": []}
	application.assets = [direct_hole_asset] as Array[Dictionary]
	var resolved_direct_holes: Array = application._geometry_sampling_hole_components(direct_hole_asset, "direct_body")
	var resolved_ancestor_holes: Array = application._geometry_sampling_hole_components(direct_hole_asset, "direct_ancestor")
	var direct_hole_sampling: Dictionary = GeometrySamplingService.generate(direct_body, {"parameters": {"spacing": 0.5}}, [], resolved_direct_holes)
	direct_hole_sampling["bake_id"] = "direct_hole_sampling"
	var direct_hole_seeding: Dictionary = GeometrySeedingService.generate(direct_hole_sampling, {"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 1.0, "seed": 7}})
	direct_hole_seeding["bake_id"] = "direct_hole_seeding"
	var direct_hole_mesh: Dictionary = GeometryMeshingService.generate(direct_hole_sampling, direct_hole_seeding, GeometryMeshingService.default_recipe())
	var direct_mesh_positions: Dictionary = {}
	for vertex in direct_hole_mesh.get("vertices", []):
		direct_mesh_positions[str(vertex.get("id", ""))] = Vector2(vertex.get("position", Vector2.ZERO))
	var direct_hole_was_filled := false
	var direct_hole_transform: Transform2D = resolved_direct_holes[0].get("sampling_transform", Transform2D.IDENTITY)
	for triangle in direct_hole_mesh.get("triangles", []):
		var ids: Array = triangle.get("vertex_ids", [])
		var centroid: Vector2 = (direct_mesh_positions.get(str(ids[0]), Vector2.ZERO) + direct_mesh_positions.get(str(ids[1]), Vector2.ZERO) + direct_mesh_positions.get(str(ids[2]), Vector2.ZERO)) / 3.0
		direct_hole_was_filled = direct_hole_was_filled or (direct_hole_transform.affine_inverse() * centroid).length() < 0.95
	application.selected_asset_id = "direct_hole_asset"
	application.selected_component_id = "direct_body"
	var direct_hole_inspector_context: Dictionary = application._geometry_sampling_inspector_context(direct_body)
	application._set_sampling_input("direct_hole_asset", "direct_hole", "component")
	var direct_hole_first_sample := Vector2(direct_hole_sampling.get("chains", [])[1].get("samples", [])[0].get("position", Vector2.INF))
	_expect(resolved_direct_holes.size() == 1 and str(resolved_direct_holes[0].get("sampling_input_id", "")) == "direct_hole" and int(direct_hole_sampling.get("hole_count", 0)) == 1 and str(direct_hole_sampling.get("chains", [])[1].get("topology_role", "")) == "hole" and direct_hole_first_sample.is_equal_approx(direct_hole_transform * Vector2.RIGHT), "A transformed direct non-Reference Primitive Hole should enter exactly its Parent's Sampling domain in Body-local space.")
	_expect(resolved_ancestor_holes.is_empty(), "A direct Primitive Hole should not propagate through its Parent into higher ancestors.")
	_expect(application._geometry_sampling_hole_components(direct_hole_asset, "direct_hole").is_empty(), "A constraint-only Hole should not act as a Body or consume nested Hole children.")
	_expect(bool(direct_hole_mesh.get("valid", false)) and not direct_hole_was_filled, "A direct Primitive Hole should remain empty in its Parent's final constrained Mesh.")
	_expect(direct_hole_inspector_context.get("boundary_rows", []).size() == 1 and str(direct_hole_inspector_context.get("boundary_rows", [])[0].get("input_id", "")) == "direct_hole" and application.selected_sampling_input_kind == "component", "A direct Primitive Hole should appear as a selectable Sampling boundary with its own density override identity.")
	_expect(not application._mesh_update_candidates("direct_hole_asset").has("direct_hole") and int(application._geometry_asset_mesh_overview("direct_hole_asset").get("visible_component_count", 0)) == 2, "A direct Hole Component should remain a constraint and never become its own Fill or Stroke Mesh body.")
	direct_hole["visibility"] = false
	_expect(application._geometry_sampling_hole_components(direct_hole_asset, "direct_body").is_empty(), "Hiding a Hole Component should disable its constraint effect on the Parent.")
	direct_hole["visibility"] = true
	direct_hole["parent_component_id"] = ""
	var orphan_hole_issue := WorldDocumentService.constraint_hole_parent_validation_issue(direct_hole_asset, direct_hole)
	var orphan_hole_attention: PackedStringArray = application._mesh_batch_summary([] as Array[Dictionary]).get("attention", PackedStringArray())
	_expect(orphan_hole_issue.contains("requires a direct outer Parent Body") and not ComponentHierarchy.can_parent(direct_hole_asset, "direct_hole", "") and str(orphan_hole_attention).contains("body_opening_hole01") and str(orphan_hole_attention).contains(orphan_hole_issue), "A visible ordinary Hole without a Parent must be rejected by hierarchy editing and reported in the Mesh batch instead of disappearing silently.")
	direct_hole["parent_component_id"] = "direct_body"
	direct_body["visibility"] = false
	_expect(WorldDocumentService.constraint_hole_parent_validation_issue(direct_hole_asset, direct_hole).contains("must be visible"), "A visible ordinary Hole must report when its direct Parent Body is hidden.")
	direct_body["visibility"] = true
	_expect(not ComponentHierarchy.can_parent(direct_hole_asset, "direct_body", "direct_hole"), "An ordinary Hole must not accept Runtime Component children.")
	var role_option := OptionButton.new()
	role_option.add_item("Outer")
	role_option.set_item_metadata(0, "outer")
	role_option.add_item("Hole")
	role_option.set_item_metadata(1, "hole")
	application.selected_asset_id = "direct_hole_asset"
	application.selected_component_id = "direct_ancestor"
	application._on_component_topology_role_selected(1, role_option)
	_expect(str(direct_ancestor.get("topology_role", "outer")) == "outer", "The Inspector must reject changing a root Component to an ordinary Hole.")
	application.selected_component_id = "direct_body"
	application._on_component_topology_role_selected(1, role_option)
	_expect(str(direct_body.get("topology_role", "outer")) == "outer", "The Inspector must reject changing a Component with children to an ordinary Hole.")
	role_option.free()
	direct_hole["parent_component_id"] = "direct_ancestor"
	_expect(application._get_sampling_input(direct_hole_asset, "direct_body", "direct_hole", "component").is_empty(), "A Hole selection should stop resolving as soon as the Component leaves the selected Parent.")
	direct_hole["parent_component_id"] = "direct_body"
	var incomplete_hole := direct_hole.duplicate(true)
	incomplete_hole["id"] = "incomplete_hole"
	incomplete_hole["name"] = "unfinished_hole"
	incomplete_hole["primitive"] = {}
	direct_hole_asset["components"].append(incomplete_hole)
	var incomplete_holes: Array = application._geometry_sampling_hole_components(direct_hole_asset, "direct_body")
	var incomplete_issues := GeometrySamplingService.validation_issues(direct_body, [], incomplete_holes)
	_expect(incomplete_holes.size() == 2 and "unfinished_hole: Primitive Component needs a Circle or Ellipse." in incomplete_issues, "An unfinished Primitive Hole should remain visible as a named blocking constraint instead of being silently ignored.")
	var invalid_hole_a: Dictionary = application._geometry_sampling_invalid_hole("invalid_hole", "invalid_hole", "Referenced source Asset is missing.")
	var invalid_hole_b: Dictionary = application._geometry_sampling_invalid_hole("invalid_hole", "invalid_hole", "Referenced Asset has no visible closed Loop or Primitive Body.")
	var invalid_recipes := GeometryAutoBuildService.automatic_recipes(direct_body, [], [invalid_hole_a])
	_expect(str(invalid_hole_a.get("topology_role", "")) == "hole" and invalid_hole_a.get("transform", null) is Dictionary and invalid_hole_a.get("sampling_transform", null) is Transform2D, "An invalid Hole placeholder should retain the full Hole contract used by Sampling and provenance.")
	_expect(not GeometryAutoBuildService.signatures_match(GeometryAutoBuildService.source_signature(direct_body, [], [invalid_hole_a], invalid_recipes), GeometryAutoBuildService.source_signature(direct_body, [], [invalid_hole_b], invalid_recipes)), "Changing an invalid Hole's diagnostic must invalidate automatic Mesh provenance.")
	direct_hole_asset["components"].erase(incomplete_hole)
	var bezier_body := direct_body.duplicate(true)
	bezier_body.merge({"id": "bezier_body", "name": "bezier_body", "parent_component_id": "", "group_id": "", "transform": WorldDocumentService.default_component_transform()}, true)
	var bezier_hole := _component()
	bezier_hole.merge({"id": "bezier_hole", "name": "bezier_hole", "parent_component_id": "bezier_body", "group_id": "", "topology_role": "hole", "transform": {"position": Vector2(2.0, -1.0), "rotation": 30.0, "scale": Vector2(1.5, 0.75), "pivot": Vector2.ZERO}}, true)
	for hole_position in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)]:
		BezierTopology.add_point(bezier_hole, hole_position, "linear")
	BezierTopology.close_active_chain(bezier_hole)
	bezier_hole["chains"][0]["topology_role"] = "hole"
	var bezier_hole_asset := {"id": "bezier_hole_asset", "name": "Bezier Hole", "visibility": true, "components": [bezier_body, bezier_hole], "groups": [], "guides": []}
	application.assets.append(bezier_hole_asset)
	var resolved_bezier_holes: Array = application._geometry_sampling_hole_components(bezier_hole_asset, "bezier_body")
	var bezier_overlays: Dictionary = application._geometry_sampling_overlays(bezier_hole_asset, "bezier_body")
	var expected_bezier_position := ComponentHierarchy.local_transform(bezier_hole["transform"]) * Vector2(-1.0, -1.0)
	_expect(resolved_bezier_holes.size() == 1 and Vector2(resolved_bezier_holes[0]["points"][0].get("position", Vector2.INF)).is_equal_approx(expected_bezier_position) and bezier_overlays.get("holes", []).size() == 1, "A transformed direct Bezier Hole should resolve and render its Sampling overlay without changing collection types.")
	var source_circle_a := {"id": "source_circle_a", "name": "circle_a", "type": "component", "draw_mode": "primitive", "topology_role": "outer", "parent_component_id": "", "group_id": "", "visibility": true, "primitive": {"type": "circle", "center": Vector2(-1.0, 0.0), "diameter_cm": 10.0}, "points": [], "edges": [], "chains": [], "transform": WorldDocumentService.default_component_transform()}
	var source_circle_b := source_circle_a.duplicate(true)
	source_circle_b.merge({"id": "source_circle_b", "name": "circle_b", "primitive": {"type": "circle", "center": Vector2(1.0, 0.0), "diameter_cm": 10.0}}, true)
	var source_asset := {"id": "hole_source", "name": "Hole Source", "visibility": true, "components": [source_circle_a, source_circle_b], "groups": [], "guides": []}
	var reference_body := direct_body.duplicate(true)
	reference_body.merge({"id": "reference_body", "name": "reference_body", "parent_component_id": "", "group_id": ""}, true)
	var hole_reference := {"id": "hole_reference", "name": "hole_reference", "type": "reference", "draw_mode": "closed_loop", "topology_role": "hole", "parent_component_id": "reference_body", "group_id": "", "visibility": true, "source_asset_id": "hole_source", "points": [], "edges": [], "chains": [], "transform": WorldDocumentService.default_component_transform()}
	var reference_hole_asset := {"id": "reference_hole_asset", "name": "Reference Hole", "visibility": true, "components": [reference_body, hole_reference], "groups": [], "guides": []}
	application.assets.append_array([source_asset, reference_hole_asset])
	var resolved_reference_holes: Array = application._geometry_sampling_hole_components(reference_hole_asset, "reference_body")
	var sampled_reference_holes := GeometrySamplingService.generate(reference_body, {"parameters": {"spacing": 0.25}}, [], resolved_reference_holes)
	var reference_sample_ids: Dictionary = {}
	var reference_sample_count := 0
	for chain_data in sampled_reference_holes.get("chains", []):
		if str(chain_data.get("topology_role", "outer")) != "hole":
			continue
		for sample in chain_data.get("samples", []):
			reference_sample_count += 1
			reference_sample_ids[str(sample.get("id", ""))] = true
	_expect(resolved_reference_holes.size() == 2 and bool(sampled_reference_holes.get("valid", false)) and reference_sample_ids.size() == reference_sample_count, "A Reference Hole should resolve every visible source body with collision-free analytic Sample IDs.")
	var invalid_reference_primitive := source_circle_a.duplicate(true)
	invalid_reference_primitive["primitive"] = {}
	var invalid_reference_hole: Dictionary = application._geometry_sampling_hole_source(invalid_reference_primitive, "invalid_reference_hole", "hole_reference", "hole_reference", Transform2D.IDENTITY)
	_expect(str(invalid_reference_hole.get("topology_role", "")) == "hole" and not str(invalid_reference_hole.get("sampling_error", "")).is_empty(), "An invalid Primitive resolved through a Hole Reference must still carry Hole topology and a visible diagnostic.")
	hole_reference["source_asset_id"] = "missing_source"
	var missing_reference_holes: Array = application._geometry_sampling_hole_components(reference_hole_asset, "reference_body")
	_expect(missing_reference_holes.size() == 1 and str(missing_reference_holes[0].get("sampling_error", "")) == "Referenced source Asset is missing.", "A Hole Reference with a missing source Asset should remain a named blocking Sampling input.")
	hole_reference["source_asset_id"] = "hole_source"
	source_circle_a["visibility"] = false
	source_circle_b["visibility"] = false
	var hidden_reference_holes: Array = application._geometry_sampling_hole_components(reference_hole_asset, "reference_body")
	_expect(hidden_reference_holes.size() == 1 and str(hidden_reference_holes[0].get("sampling_error", "")).contains("no visible Closed Loop or Primitive boundary"), "A Hole Reference whose source has no visible Body should remain a named blocking Sampling input.")
	source_circle_a["visibility"] = true
	source_circle_b["visibility"] = true
	_expect(WorldDocumentService.has_supported_schema({"schema_version": 62}) and WorldDocumentService.has_supported_schema({"schema_version": 61}) and not WorldDocumentService.has_supported_schema({"schema_version": 63}), "Schema 62 should keep current and older World documents readable and reject unknown future schemas.")
	_expect(WorldDocumentService.normalize_component_draw_mode("ribbon", 39) == "contour" and WorldDocumentService.normalize_component_draw_mode("contour", 42) == "contour", "Schema-42 loading must retain the explicit legacy Ribbon-to-Contour migration boundary.")
	_expect(WorldDocumentService.normalize_component_draw_mode("ribbon", 42) == "ribbon", "Current-schema Ribbon data must remain visibly invalid instead of receiving a silent backward fallback.")
	var arranged_round_trip: Dictionary = WorldDocumentService.normalize_sampling_bake(WorldDocumentService.serialize_sampling_bake(arranged_result))
	_expect(arranged_round_trip.get("cuts", [])[0].get("fragments", []).size() == 2 and arranged_round_trip.get("cuts", [])[0].get("fragments", [])[0].get("samples", [])[0].get("position", null) is Vector2, "Schema 32 should preserve Cut fragment connectivity and restore fragment positions as Vector2 values.")
	var geometry_document: Dictionary = WorldDocumentService.default_geometry_document("asset_1", "component_1")
	geometry_document["sampling"]["recipe"] = {"method": GeometrySamplingService.EVEN_SPACING, "parameters": {"spacing": 2.5, "feature_detail": GeometrySamplingService.DEFAULT_FEATURE_DETAIL}}
	var baked_result := adaptive.duplicate(true)
	baked_result["bake_id"] = "bake_test"
	geometry_document["sampling"]["bakes"][GeometrySamplingService.ADAPTIVE] = baked_result
	var serialized_geometry: Dictionary = WorldDocumentService.serialize_geometry_document(geometry_document)
	_expect(int(serialized_geometry.get("schema_version", 0)) == 62 and serialized_geometry.get("sampling", {}).get("bakes", {}).get(GeometrySamplingService.ADAPTIVE, {}).get("chains", [])[0].get("samples", [])[0].get("position", null) is Array, "Sampling bakes should serialize derived positions as schema-62 JSON arrays.")
	var normalized_geometry: Dictionary = WorldDocumentService.normalize_geometry_document(serialized_geometry, "asset_1", "component_1")
	_expect(normalized_geometry.get("sampling", {}).get("bakes", {}).get(GeometrySamplingService.ADAPTIVE, {}).get("chains", [])[0].get("samples", [])[0].get("position", null) is Vector2, "Sampling bake loading should restore local sample positions as Vector2 values.")
	_expect(normalized_geometry["sampling"]["bakes"].size() == 1, "Sampling should retain one Adaptive Bake.")
	var test_assets: Array[Dictionary] = [{"id": "asset_1", "components": [component]}]
	application.assets = test_assets
	application.geometry_documents["asset_1/component_1"] = normalized_geometry
	_expect(application._geometry_sampling_status("asset_1", "component_1", component) == "Baked", "A bake matching its recipe and source fingerprint should report Baked.")
	BezierTopology.point_by_id(component["points"], curve_id)["position"] += Vector2.ONE
	_expect(application._geometry_sampling_status("asset_1", "component_1", component) == "Ready to Preview", "Changing canonical topology should request a new Preview without rewriting its persisted result.")
	application.free()


func _test_geometry_sampling_corner_balancing() -> void:
	var component := _closed_linear_fixture("corner_balance", "Corner Balance", [
		Vector2(0.0, 0.0), Vector2(0.01, 0.0), Vector2(4.0, 0.0),
		Vector2(4.0, 0.01), Vector2(4.0, 4.0), Vector2(0.0, 4.0)
	])
	var chain: Dictionary = component.get("chains", [])[0]
	var point_ids: Array = chain.get("point_ids", [])
	var edge_ids: Array = chain.get("edge_ids", [])
	var curve_start := BezierTopology.point_by_id(component.get("points", []), str(point_ids[1]))
	var curve_end := BezierTopology.point_by_id(component.get("points", []), str(point_ids[2]))
	curve_start["mode"] = "free"
	curve_start["handle_source"] = "manual"
	curve_start["handle_out"] = Vector2(1.0, 0.5)
	curve_end["mode"] = "free"
	curve_end["handle_source"] = "manual"
	curve_end["handle_in"] = Vector2(-1.0, 0.5)
	var authored_snapshot := component.duplicate(true)
	var recipe := {"parameters": {"spacing": 100.0, "feature_detail": 0.0}}
	var balanced := GeometrySamplingService.generate(component, recipe)
	var repeated := GeometrySamplingService.generate(component, recipe)
	var balanced_samples: Array = balanced.get("chains", [])[0].get("samples", [])
	var internal_edge_id := str(edge_ids[1])
	var closing_edge_id := str(edge_ids.back())
	var has_internal_midpoint := false
	var has_closing_midpoint := false
	var expected_midpoint := BezierGeometry.cubic_position(BezierGeometry.cubic_controls(curve_start, curve_end), 0.5)
	for sample in balanced_samples:
		if str(sample.get("source_point_id", "")).is_empty() and str(sample.get("edge_id", "")) == internal_edge_id and is_equal_approx(float(sample.get("curve_t", -1.0)), 0.5):
			has_internal_midpoint = Vector2(sample.get("position", Vector2.ZERO)).is_equal_approx(expected_midpoint)
		if str(sample.get("source_point_id", "")).is_empty() and str(sample.get("edge_id", "")) == closing_edge_id:
			has_closing_midpoint = true
	_expect(bool(balanced.get("valid", false)) and bool(balanced.get("boundary_refinement_complete", false)) and int(balanced.get("boundary_refinement_count", 0)) > 0, "Single-interval authored edges should complete deterministic corner balancing instead of aborting the Chain.")
	_expect(_maximum_authored_corner_sample_ratio(balanced) <= GeometrySamplingService.MAX_ADJACENT_CORNER_SEGMENT_RATIO + 0.0001, "Corner balancing should meet its ratio target when the per-Chain budget is sufficient.")
	_expect(has_internal_midpoint and has_closing_midpoint, "Corner balancing should resolve both an internal source-to-source interval and the closed Chain's final Edge from explicit Chain topology.")
	_expect(balanced == repeated, "Boundary corner refinement should be deterministic for identical topology and recipes.")
	_expect(component == authored_snapshot, "Boundary corner refinement must not mutate authored Points, handles, Edges, or Chains.")
	var source_sample_count := 0
	for sample in balanced_samples:
		if not str(sample.get("source_point_id", "")).is_empty():
			source_sample_count += 1
	_expect(source_sample_count == component.get("points", []).size() and int(balanced.get("preserve_count", 0)) == 2, "Derived corner samples must not replace authored source samples or change preserve-point accounting.")

	var primitive_body := {"id": "primitive_balance_body", "draw_mode": "primitive", "topology_role": "outer", "primitive": {"type": "circle", "center": Vector2(2.0, 2.0), "diameter_cm": 20.0}}
	var bezier_hole := component.duplicate(true)
	bezier_hole["id"] = "balanced_bezier_hole"
	bezier_hole["sampling_input_id"] = "balanced_bezier_hole"
	bezier_hole["topology_role"] = "hole"
	bezier_hole["chains"][0]["topology_role"] = "hole"
	var primitive_with_hole := GeometrySamplingService.generate(primitive_body, recipe, [], [bezier_hole])
	_expect(bool(primitive_with_hole.get("valid", false)) and bool(primitive_with_hole.get("boundary_refinement_complete", false)) and int(primitive_with_hole.get("boundary_refinement_count", 0)) > 0 and _maximum_authored_corner_sample_ratio(primitive_with_hole, "hole") <= GeometrySamplingService.MAX_ADJACENT_CORNER_SEGMENT_RATIO + 0.0001, "A Primitive Body should propagate completed Bézier-Hole refinement and its exact diagnostics.")

	var guarded_component := _closed_linear_fixture("guarded_balance", "Guarded Balance", [
		Vector2(0.0, 0.0), Vector2(4.0, 0.0), Vector2(4.0, 0.01),
		Vector2(4.0, 4.0), Vector2(0.01, 4.0), Vector2(0.0, 4.0)
	])
	var guarded_chain: Dictionary = guarded_component.get("chains", [])[0]
	var guarded_point_ids: Array = guarded_chain.get("point_ids", [])
	var guarded_edge_ids: Array = guarded_chain.get("edge_ids", [])
	var guarded_start := BezierTopology.point_by_id(guarded_component.get("points", []), str(guarded_point_ids[0]))
	var guarded_end := BezierTopology.point_by_id(guarded_component.get("points", []), str(guarded_point_ids[1]))
	guarded_start["mode"] = "free"
	guarded_start["handle_source"] = "manual"
	guarded_start["handle_out"] = Vector2(-2.0 / 3.0, 0.0)
	guarded_end["mode"] = "free"
	guarded_end["handle_source"] = "manual"
	guarded_end["handle_in"] = Vector2(-14.0 / 3.0, 0.0)
	var authored_samples: Array = []
	for point_index in range(guarded_point_ids.size()):
		var point_id := str(guarded_point_ids[point_index])
		var incoming_edge_id := str(guarded_edge_ids[0]) if point_index == 0 else str(guarded_edge_ids[point_index - 1])
		authored_samples.append({"id": "authored:%s" % point_id, "position": Vector2(BezierTopology.point_by_id(guarded_component.get("points", []), point_id).get("position", Vector2.ZERO)), "edge_id": incoming_edge_id, "curve_t": 0.0 if point_index == 0 else 1.0, "source_point_id": point_id, "preserved": false})
	var guarded_result := GeometrySamplingService._balance_corner_segment_lengths(authored_samples, guarded_component, guarded_chain)
	var guarded_samples: Array = guarded_result.get("samples", [])
	var zero_length_segment := false
	for sample_index in range(guarded_samples.size()):
		zero_length_segment = zero_length_segment or Vector2(guarded_samples[sample_index].get("position", Vector2.ZERO)).distance_to(Vector2(guarded_samples[(sample_index + 1) % guarded_samples.size()].get("position", Vector2.ZERO))) <= GeometrySamplingService.ARRANGEMENT_EPSILON
	_expect(int(guarded_result.get("added_sample_count", 0)) > 0 and not bool(guarded_result.get("complete", true)) and not bool(guarded_result.get("limit_reached", true)), "An unsplittable cubic interval should be skipped while other repairable Corners continue refining.")
	_expect(not zero_length_segment, "Corner balancing must reject a cubic midpoint that would create a zero-length spatial Constraint.")

	var budget_positions: Array = [Vector2.ZERO]
	var budget_x := 0.0
	for _pair_index in range(20):
		budget_x += 0.001
		budget_positions.append(Vector2(budget_x, 0.0))
		budget_x += 1.0
		budget_positions.append(Vector2(budget_x, 0.0))
	budget_positions.append(Vector2(budget_x, 5.0))
	budget_positions.append(Vector2(0.0, 5.0))
	var budget_component := _closed_linear_fixture("budget_balance", "Budget Balance", budget_positions)
	var budget_result := GeometrySamplingService.generate(budget_component, {"parameters": {"spacing": 1000.0, "feature_detail": 0.0}})
	_expect(bool(budget_result.get("valid", false)) and int(budget_result.get("boundary_refinement_count", 0)) == GeometrySamplingService.MAX_CORNER_REFINEMENTS_PER_CHAIN and not bool(budget_result.get("boundary_refinement_complete", true)) and bool(budget_result.get("boundary_refinement_limit_reached", false)) and int(budget_result.get("boundary_refinement_unresolved_corner_count", 0)) > 0, "Corner balancing should remain valid but explicitly diagnose an exhausted per-Chain refinement budget.")
	var budget_round_trip := WorldDocumentService.normalize_sampling_bake(WorldDocumentService.serialize_sampling_bake(budget_result))
	_expect(int(budget_round_trip.get("boundary_refinement_count", -1)) == GeometrySamplingService.MAX_CORNER_REFINEMENTS_PER_CHAIN and not bool(budget_round_trip.get("boundary_refinement_complete", true)) and bool(budget_round_trip.get("boundary_refinement_limit_reached", false)) and int(budget_round_trip.get("boundary_refinement_unresolved_corner_count", 0)) == int(budget_result.get("boundary_refinement_unresolved_corner_count", -1)), "Sampling persistence should preserve Boundary-refinement completion and budget diagnostics.")


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
	var expected_large_boundary_spacing := 0.55 * sqrt(140.0 / 60.0)
	var expected_large_seed_spacing := sqrt(1000.0 / 750.0)
	_expect(is_equal_approx(float(large_recipes.get("sampling", {}).get("parameters", {}).get("spacing", 0.0)), expected_large_boundary_spacing), "Large automatic Components should scale Boundary Spacing from the Barde reference range without coupling it to interior area.")
	_expect(is_equal_approx(float(large_recipes.get("seeding", {}).get("parameters", {}).get("spacing", 0.0)), expected_large_seed_spacing) and expected_large_seed_spacing > expected_large_boundary_spacing, "Large automatic Components should use a separate area-aware Seed Spacing to bound interior density.")
	var tiny_component := component.duplicate(true)
	for point in tiny_component.get("points", []):
		point["position"] = Vector2(point.get("position", Vector2.ZERO)) * 0.1
	var tiny_recipes := GeometryAutoBuildService.automatic_recipes(tiny_component)
	_expect(is_equal_approx(float(tiny_recipes.get("sampling", {}).get("parameters", {}).get("spacing", 0.0)), 0.5) and is_equal_approx(float(tiny_recipes.get("seeding", {}).get("parameters", {}).get("spacing", 0.0)), 0.5), "Small Symbols should retain the existing minimum boundary-sample behavior instead of being coarsened by the large-Component model.")
	_expect(bool(recipes.get("automatic", false)) and int(recipes.get("auto_recipe_version", 0)) == GeometryAutoBuildService.AUTO_RECIPE_VERSION, "Automatic Mesh recipes should identify their versioned calibration model.")
	var seed_retry := GeometryAutoBuildService.automatic_retry_recipes(recipes, 1, "seed")
	_expect(is_equal_approx(float(seed_retry.get("sampling", {}).get("parameters", {}).get("spacing", 0.0)), 0.55) and is_equal_approx(float(seed_retry.get("sampling", {}).get("parameters", {}).get("feature_detail", 0.0)), 0.55) and is_equal_approx(float(seed_retry.get("seeding", {}).get("parameters", {}).get("spacing", 0.0)), 0.55 * 1.25), "An automatic Seed retry must reduce only interior density and preserve the accepted Boundary silhouette recipe.")
	var boundary_retry := GeometryAutoBuildService.automatic_retry_recipes(recipes, 1, "boundary")
	_expect(is_equal_approx(float(boundary_retry.get("sampling", {}).get("parameters", {}).get("spacing", 0.0)), 0.55 * 1.25) and is_equal_approx(float(boundary_retry.get("sampling", {}).get("parameters", {}).get("feature_detail", 0.0)), 0.55 * 1.25) and is_equal_approx(float(boundary_retry.get("seeding", {}).get("parameters", {}).get("spacing", 0.0)), 0.55 * 1.25), "A Boundary retry may coarsen Boundary criteria only after the automatic Boundary budget is the diagnosed limit.")
	var seed_after_boundary_retry := GeometryAutoBuildService.automatic_retry_recipes(recipes, 2, "seed", 1)
	_expect(is_equal_approx(float(seed_after_boundary_retry.get("sampling", {}).get("parameters", {}).get("spacing", 0.0)), 0.55 * 1.25) and is_equal_approx(float(seed_after_boundary_retry.get("seeding", {}).get("parameters", {}).get("spacing", 0.0)), 0.55 * pow(1.25, 2)), "A later Seed retry must retain an already required Boundary relaxation without coarsening that Boundary a second time.")
	var accepted_assessment := GeometryAutoBuildService.automatic_build_assessment(
		{"valid": true, "sample_count": 100},
		{"valid": true, "seed_count": 200},
		{"valid": true, "triangle_count": 500, "constraints_valid": true, "degenerate_triangle_count": 0, "minimum_angle": 12.0, "mean_quality": 0.7, "worst_aspect_ratio": 4.0}
	)
	var seed_limited_assessment := GeometryAutoBuildService.automatic_build_assessment(
		{"valid": true, "sample_count": 100},
		{"valid": true, "seed_count": GeometryAutoBuildService.MAX_AUTOMATIC_SEEDS + 1}
	)
	var boundary_limited_assessment := GeometryAutoBuildService.automatic_build_assessment(
		{"valid": true, "sample_count": GeometryAutoBuildService.MAX_AUTOMATIC_BOUNDARY_SAMPLES + 1}
	)
	var invalid_quality_assessment := GeometryAutoBuildService.automatic_build_assessment(
		{"valid": true, "sample_count": 100},
		{"valid": true, "seed_count": 200},
		{"valid": true, "triangle_count": 500, "constraints_valid": false, "degenerate_triangle_count": 1}
	)
	var warned_quality_assessment := GeometryAutoBuildService.automatic_build_assessment(
		{"valid": true, "sample_count": 30},
		{"valid": true, "seed_count": 0},
		{"valid": true, "triangle_count": 28, "constraints_valid": true, "degenerate_triangle_count": 0, "minimum_angle": 1.0, "mean_quality": 0.4, "worst_aspect_ratio": 60.0}
	)
	_expect(bool(accepted_assessment.get("accepted", false)) and is_equal_approx(float(accepted_assessment.get("minimum_angle", 0.0)), 12.0), "Automatic acceptance should retain fixed complexity and reported quality diagnostics for a valid Build.")
	_expect(not bool(seed_limited_assessment.get("accepted", true)) and str(seed_limited_assessment.get("retry_scope", "")) == "seed", "Excessive automatic interior complexity should request a Seed-only retry.")
	_expect(not bool(boundary_limited_assessment.get("accepted", true)) and str(boundary_limited_assessment.get("retry_scope", "")) == "boundary", "Only excessive Boundary complexity should request a Boundary retry.")
	_expect(not bool(invalid_quality_assessment.get("accepted", true)) and str(invalid_quality_assessment.get("retry_scope", "")) == "seed" and invalid_quality_assessment.get("issues", []).size() == 2, "Automatic acceptance must reject degenerate or Constraint-invalid Mesh quality without relaxing the Boundary first.")
	_expect(bool(warned_quality_assessment.get("accepted", false)) and GeometryMeshingService.quality_warnings(warned_quality_assessment).size() == 2, "Severe but non-degenerate shape-dependent quality should stay accepted while exposing explicit Auto Build warnings.")
	_expect(GeometryMeshingService.quality_warnings({"triangle_count": 0, "minimum_angle": 0.0, "worst_aspect_ratio": 0.0}).is_empty() and GeometryMeshingService.quality_warnings({"minimum_angle": 0.0}).is_empty(), "An empty or incomplete Mesh metric record should not report misleading shape-quality warnings.")
	var baked_signature := GeometryAutoBuildService.source_signature(component, [], [], recipes)
	var previous_auto_model := recipes.duplicate(true)
	previous_auto_model["auto_recipe_version"] = GeometryAutoBuildService.AUTO_RECIPE_VERSION - 1
	_expect(not GeometryAutoBuildService.signatures_match(GeometryAutoBuildService.source_signature(component, [], [], previous_auto_model), baked_signature), "A newer automatic retry policy should invalidate older automatic provenance without forcing manual recipes to change.")
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
	_expect((application._mesh_batch_summary(application._all_mesh_update_candidates()).get("attention", PackedStringArray()) as PackedStringArray).is_empty(), "All Components should be evaluated by Mesh batch attention and candidate collection.")
	other_component["group_id"] = "hidden_group"
	test_assets[1]["groups"] = [{"id": "hidden_group", "name": "hidden_group", "visibility": false, "parent_component_id": "", "transform": WorldDocumentService.default_component_transform()}]
	_expect(application._mesh_update_candidates("auto_symbol").is_empty() and int(application._geometry_asset_mesh_overview("auto_symbol").get("visible_component_count", -1)) == 0, "A Component hidden by its Group must leave both the actionable Mesh batch and the visible Asset overview.")
	test_assets[1]["groups"][0]["visibility"] = true
	var build: Dictionary = application._generate_component_mesh_build("auto_asset", "auto_body")
	_expect(bool(build.get("valid", false)) and int(build.get("meshing", {}).get("triangle_count", 0)) > 0 and int(build.get("contour_stroke", {}).get("triangle_count", 0)) > 0, "The automatic batch runner should atomically complete the Fill pipeline and the independent centered Contour Stroke Bake.")
	application._commit_component_mesh_build("auto_asset", "auto_body", build)
	_expect(application._mesh_update_candidates("auto_asset").is_empty(), "A successfully committed automatic Mesh should become clean without a mutable dirty flag.")
	_expect(application._all_mesh_update_candidates() == [{"asset_id": "auto_symbol", "component_id": "auto_symbol_body"}], "A committed Mesh should leave only dirty Components from other Assets in the global batch.")
	var round_trip: Dictionary = WorldDocumentService.normalize_geometry_document(WorldDocumentService.serialize_geometry_document(application.geometry_documents["auto_asset/auto_body"]), "auto_asset", "auto_body")
	var automatic_provenance: Dictionary = round_trip.get("component_mesh", {}).get("build_provenance", {})
	_expect(not automatic_provenance.get("source_signature", {}).is_empty() and round_trip.get("meshing", {}).get("bakes", {}).has(ContourMeshService.METHOD), "Fill provenance and the separate Contour Stroke Bake should survive Geometry JSON persistence.")
	_expect(str(automatic_provenance.get("recipe_mode", "")) == "automatic" and int(automatic_provenance.get("auto_recipe_version", 0)) == GeometryAutoBuildService.AUTO_RECIPE_VERSION and not str(automatic_provenance.get("pipeline_recipe_hash", "")).is_empty(), "Automatic Mesh provenance should retain recipe ownership so later model versions can migrate safely.")
	var persisted_auto_diagnostics: Dictionary = automatic_provenance.get("automatic_diagnostics", {})
	_expect(int(persisted_auto_diagnostics.get("version", 0)) == 1 and persisted_auto_diagnostics.get("limits", {}) == GeometryAutoBuildService.automatic_complexity_limits() and str(persisted_auto_diagnostics.get("attempts", [])[0].get("outcome", "")) == "accepted", "Successful automatic provenance should persist its attempt history, quality readings, and fixed complexity limits.")
	var automatic_diagnostic_text := "\n".join(application._component_mesh_build_diagnostic_lines("auto_asset", "auto_body"))
	_expect(automatic_diagnostic_text.contains("Recipe Ownership: Automatic · Model v%d" % GeometryAutoBuildService.AUTO_RECIPE_VERSION) and automatic_diagnostic_text.contains("Current Spacing: Boundary 0.550 · Seed 0.550") and automatic_diagnostic_text.contains("Geometry: Area 100.00 · Perimeter 40.00 · Feature 10.00") and automatic_diagnostic_text.contains("Last Build: Samples") and automatic_diagnostic_text.contains("Attempt 1: Initial · Accepted") and automatic_diagnostic_text.contains("Quality: Min"), "Auto Build diagnostics should explain ownership, geometry metrics, effective spacing, budget use, attempts, and quality without changing the Mesh.")
	var stored_automatic_recipes: Dictionary = application._geometry_build_recipes("auto_asset", "auto_body", component, [], [])
	_expect(bool(stored_automatic_recipes.get("automatic", false)), "An unchanged automatically committed recipe should remain owned by the Auto Mesh pipeline.")
	application.geometry_documents["auto_asset/auto_body"]["sampling"]["recipe"]["parameters"]["spacing"] = 0.8
	var manually_edited_recipes: Dictionary = application._geometry_build_recipes("auto_asset", "auto_body", component, [], [])
	_expect(not bool(manually_edited_recipes.get("automatic", true)) and is_equal_approx(float(manually_edited_recipes.get("sampling", {}).get("parameters", {}).get("spacing", 0.0)), 0.8), "Editing an automatic recipe should transfer ownership to the manual settings instead of letting Auto Mesh overwrite it.")
	var manual_diagnostic_text := "\n".join(application._component_mesh_build_diagnostic_lines("auto_asset", "auto_body"))
	_expect(manual_diagnostic_text.contains("Recipe Ownership: Manual · Changed after Auto Build") and manual_diagnostic_text.contains("Auto Budgets: Not applied"), "Inspector diagnostics should immediately explain when a recipe edit transfers ownership from Auto Build to manual settings.")
	var manual_build: Dictionary = application._generate_component_mesh_build("auto_asset", "auto_body")
	_expect(bool(manual_build.get("valid", false)) and str(manual_build.get("recipe_mode", "")) == "manual" and int(manual_build.get("attempts", 0)) == 1 and manual_build.get("auto_build_diagnostics", {}).is_empty(), "A manually owned recipe should run exactly once and remain outside automatic fallback or budget rewriting.")
	var legacy_component := large_component.duplicate(true)
	legacy_component["id"] = "legacy_large"
	application.assets.append({"id": "legacy_asset", "name": "Legacy Asset", "asset_type": "prop", "visibility": true, "components": [legacy_component], "guides": []})
	var legacy_document: Dictionary = WorldDocumentService.default_geometry_document("legacy_asset", "legacy_large")
	legacy_document["sampling"]["recipe"] = GeometrySamplingService.normalize_recipe({"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 0.55, "feature_detail": 0.55, "boundary_refinements": {}}})
	legacy_document["seeding"]["recipe"] = GeometrySeedingService.normalize_recipe({"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 0.55, "constraint_clearance_factor": GeometrySeedingService.DEFAULT_CONSTRAINT_CLEARANCE_FACTOR, "seed": GeometrySeedingService.DEFAULT_SEED}})
	legacy_document["meshing"]["recipe"] = GeometryMeshingService.normalize_recipe({"method": GeometryMeshingService.CONSTRAINED_MESH, "parameters": {"seeding_method": GeometrySeedingService.POISSON_FILL, "mesh_character": GeometryMeshingService.DEFAULT_MESH_CHARACTER, "optimize_mesh": true}})
	legacy_document["component_mesh"]["build_provenance"] = {"source_signature": {"version": 1}}
	application.geometry_documents["legacy_asset/legacy_large"] = legacy_document
	var migrated_legacy_recipes: Dictionary = application._geometry_build_recipes("legacy_asset", "legacy_large", legacy_component, [], [])
	_expect(bool(migrated_legacy_recipes.get("automatic", false)) and is_equal_approx(float(migrated_legacy_recipes.get("sampling", {}).get("parameters", {}).get("spacing", 0.0)), expected_large_boundary_spacing) and is_equal_approx(float(migrated_legacy_recipes.get("seeding", {}).get("parameters", {}).get("spacing", 0.0)), expected_large_seed_spacing), "A legacy default Auto Mesh recipe should migrate to the separated Boundary and Seed calibration.")
	var legacy_default_component := large_component.duplicate(true)
	legacy_default_component["id"] = "legacy_default_large"
	application.assets.append({"id": "legacy_default_asset", "name": "Legacy Default Asset", "asset_type": "prop", "visibility": true, "components": [legacy_default_component], "guides": []})
	var legacy_default_document: Dictionary = WorldDocumentService.default_geometry_document("legacy_default_asset", "legacy_default_large")
	legacy_default_document["component_mesh"]["build_provenance"] = {"source_signature": {"version": 1}}
	application.geometry_documents["legacy_default_asset/legacy_default_large"] = legacy_default_document
	var migrated_default_recipes: Dictionary = application._geometry_build_recipes("legacy_default_asset", "legacy_default_large", legacy_default_component, [], [])
	_expect(bool(migrated_default_recipes.get("automatic", false)) and is_equal_approx(float(migrated_default_recipes.get("sampling", {}).get("parameters", {}).get("spacing", 0.0)), expected_large_boundary_spacing), "An oversized Component with untouched legacy UI defaults should enter the automatic calibration, covering old Tree-like Crown documents.")
	var legacy_default_small := tiny_component.duplicate(true)
	legacy_default_small["id"] = "legacy_default_small"
	application.assets.append({"id": "legacy_default_small_asset", "name": "Legacy Default Small Asset", "asset_type": "symbols", "visibility": true, "components": [legacy_default_small], "guides": []})
	var legacy_default_small_document: Dictionary = WorldDocumentService.default_geometry_document("legacy_default_small_asset", "legacy_default_small")
	legacy_default_small_document["component_mesh"]["build_provenance"] = {"source_signature": {"version": 1}}
	application.geometry_documents["legacy_default_small_asset/legacy_default_small"] = legacy_default_small_document
	var preserved_default_small: Dictionary = application._geometry_build_recipes("legacy_default_small_asset", "legacy_default_small", legacy_default_small, [], [])
	_expect(not bool(preserved_default_small.get("automatic", true)) and is_equal_approx(float(preserved_default_small.get("sampling", {}).get("parameters", {}).get("spacing", 0.0)), GeometrySamplingService.DEFAULT_SPACING), "Legacy default recipes on small Symbols should stay untouched rather than being swept into the large-Component migration.")
	application.free()
	var contour_component := _component()
	contour_component.merge({"id": "auto_arm_line", "name": "Arm Line", "draw_mode": "contour", "visibility": true, "transform": {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}})
	for contour_position in [Vector2.ZERO, Vector2(3.0, 1.0), Vector2(6.0, 0.0)]:
		BezierTopology.add_point(contour_component, contour_position, "linear")
	var contour_application: Control = application_script.new()
	var contour_assets: Array[Dictionary] = [{"id": "contour_asset", "name": "Contour Asset", "asset_type": "character", "visibility": true, "components": [contour_component], "guides": []}]
	contour_application.assets = contour_assets
	_expect(contour_application._mesh_update_candidates("contour_asset") == ["auto_arm_line"], "A valid open Contour should enter Update Meshes without Sampling or Seeding prerequisites.")
	var contour_build: Dictionary = contour_application._generate_component_mesh_build("contour_asset", "auto_arm_line")
	_expect(bool(contour_build.get("valid", false)) and str(contour_build.get("meshing", {}).get("method", "")) == ContourMeshService.METHOD, "Update Meshes should build the authored Contour Stroke directly instead of a legacy strip or Fill Mesh.")
	contour_application._commit_component_mesh_build("contour_asset", "auto_arm_line", contour_build)
	_expect(contour_application._mesh_update_candidates("contour_asset").is_empty(), "A committed current Contour Stroke Mesh should clear its batch candidate.")
	contour_component["edges"][0]["render_outline"] = false
	_expect(contour_application._mesh_update_candidates("contour_asset") == ["auto_arm_line"], "Changing Render Outline must make Contour build provenance actionable again.")
	contour_application.free()


func _test_geometry_auto_build_regression_corpus() -> void:
	var tiny_symbol := _closed_linear_fixture("corpus_tiny", "Tiny Symbol", [Vector2.ZERO, Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
	var barde_body := _closed_linear_fixture("corpus_barde", "Barde Body", [Vector2.ZERO, Vector2(7.8, 0.0), Vector2(7.8, 6.8), Vector2(0.0, 6.8)])
	var tree_trunk := _closed_linear_fixture("corpus_trunk", "Tree Trunk", [Vector2.ZERO, Vector2(22.4, 0.0), Vector2(22.4, 33.6), Vector2(0.0, 33.6)])
	var concave_crown := _closed_linear_fixture("corpus_crown", "Concave Crown", [
		Vector2(0.0, -34.0), Vector2(8.0, -19.0), Vector2(24.0, -24.0), Vector2(19.0, -8.0),
		Vector2(32.0, 0.0), Vector2(19.0, 8.0), Vector2(24.0, 24.0), Vector2(8.0, 19.0),
		Vector2(0.0, 34.0), Vector2(-8.0, 19.0), Vector2(-24.0, 24.0), Vector2(-19.0, 8.0),
		Vector2(-32.0, 0.0), Vector2(-19.0, -8.0), Vector2(-24.0, -24.0), Vector2(-8.0, -19.0)
	])
	var narrow_item := _closed_linear_fixture("corpus_narrow_item", "Narrow Concave Item", [
		Vector2(-0.19, 1.36), Vector2(-0.19, 0.21), Vector2(-0.18, 0.14), Vector2(-0.15, 0.08),
		Vector2(-0.11, 0.03), Vector2(-0.05, 0.0), Vector2(0.0, 0.0), Vector2(0.05, 0.0),
		Vector2(0.11, 0.03), Vector2(0.15, 0.08), Vector2(0.18, 0.14), Vector2(0.19, 0.21),
		Vector2(0.19, 1.36), Vector2(0.184, 1.327), Vector2(0.17, 1.304), Vector2(0.15, 1.29),
		Vector2(0.10, 1.27), Vector2(0.05, 1.25), Vector2(0.0, 1.24), Vector2(-0.05, 1.25),
		Vector2(-0.10, 1.27), Vector2(-0.15, 1.29), Vector2(-0.17, 1.304), Vector2(-0.184, 1.327)
	])
	var half_narrow_item := narrow_item.duplicate(true)
	half_narrow_item["id"] = "corpus_narrow_item_half"
	half_narrow_item["name"] = "Half Narrow Concave Item"
	for point in half_narrow_item.get("points", []):
		point["position"] = Vector2(point.get("position", Vector2.ZERO)) * 0.5
	var tiny_result := _run_auto_mesh_fixture(tiny_symbol)
	var barde_result := _run_auto_mesh_fixture(barde_body)
	var trunk_result := _run_auto_mesh_fixture(tree_trunk)
	var crown_result := _run_auto_mesh_fixture(concave_crown)
	var narrow_result := _run_auto_mesh_fixture(narrow_item)
	var half_narrow_result := _run_auto_mesh_fixture(half_narrow_item)
	for fixture_result in [tiny_result, barde_result, trunk_result, crown_result, narrow_result, half_narrow_result]:
		var fixture_name := str(fixture_result.get("fixture_name", "Fixture"))
		var assessment: Dictionary = fixture_result.get("assessment", {})
		var mesh: Dictionary = fixture_result.get("meshing", {})
		_expect(bool(fixture_result.get("valid", false)) and bool(assessment.get("accepted", false)) and bool(mesh.get("constraints_valid", false)) and int(mesh.get("degenerate_triangle_count", -1)) == 0, "%s should satisfy the same Constraint and non-degenerate quality gates as production Auto Mesh builds." % fixture_name)
		_expect(int(assessment.get("sample_count", 0)) <= GeometryAutoBuildService.MAX_AUTOMATIC_BOUNDARY_SAMPLES and int(assessment.get("seed_count", 0)) <= GeometryAutoBuildService.MAX_AUTOMATIC_SEEDS and int(assessment.get("triangle_count", 0)) <= GeometryAutoBuildService.MAX_AUTOMATIC_TRIANGLES, "%s should remain inside the versioned automatic complexity budgets." % fixture_name)
	_expect(is_equal_approx(float(tiny_result.get("boundary_spacing", 0.0)), 0.5) and is_equal_approx(float(tiny_result.get("seed_spacing", 0.0)), 0.5), "The corpus should lock the existing tiny-Symbol boundary-sample behavior.")
	_expect(is_equal_approx(float(barde_result.get("boundary_spacing", 0.0)), 0.55) and is_equal_approx(float(barde_result.get("seed_spacing", 0.0)), 0.55), "The corpus should lock the Barde-scale 0.55 reference calibration.")
	_expect(float(trunk_result.get("boundary_spacing", 0.0)) > 0.7 and float(trunk_result.get("seed_spacing", 0.0)) > float(trunk_result.get("boundary_spacing", 0.0)) and int(trunk_result.get("meshing", {}).get("triangle_count", 0)) < 2000, "The corpus should keep Tree-Trunk density bounded while retaining a finer Boundary than interior Seed spacing.")
	_expect(float(crown_result.get("boundary_spacing", 0.0)) > 0.9 and float(crown_result.get("seed_spacing", 0.0)) >= float(crown_result.get("boundary_spacing", 0.0)) and int(crown_result.get("meshing", {}).get("triangle_count", 0)) < 5000, "The corpus should keep a large concave Crown valid and within a broad non-fragile Triangle range.")
	var narrow_mesh: Dictionary = narrow_result.get("meshing", {})
	var half_narrow_mesh: Dictionary = half_narrow_result.get("meshing", {})
	var narrow_sampling: Dictionary = narrow_result.get("sampling", {})
	var half_narrow_sampling: Dictionary = half_narrow_result.get("sampling", {})
	_expect(int(narrow_mesh.get("boundary_refinement", {}).get("added_vertex_count", 0)) > 0 and int(half_narrow_mesh.get("boundary_refinement", {}).get("added_vertex_count", 0)) > 0, "Narrow concave Item bodies should receive deterministic local Boundary refinement at both authored scales.")
	_expect(int(narrow_sampling.get("boundary_refinement_count", 0)) == int(narrow_mesh.get("boundary_refinement", {}).get("added_vertex_count", -1)) and int(half_narrow_sampling.get("boundary_refinement_count", 0)) == int(half_narrow_mesh.get("boundary_refinement", {}).get("added_vertex_count", -1)), "Meshing diagnostics should report the exact derived Boundary samples inserted upstream.")
	_expect(int(narrow_mesh.get("vertex_count", 0)) == int(half_narrow_mesh.get("vertex_count", -1)) and int(narrow_mesh.get("triangle_count", 0)) == int(half_narrow_mesh.get("triangle_count", -1)) and is_equal_approx(float(narrow_mesh.get("minimum_angle", 0.0)), float(half_narrow_mesh.get("minimum_angle", -1.0))), "Narrow concave Item refinement should remain scale invariant when the automatic spacing model scales with the complete shape.")
	_expect(float(narrow_mesh.get("minimum_angle", 0.0)) >= GeometryMeshingService.QUALITY_WARNING_MINIMUM_ANGLE and GeometryMeshingService.quality_warnings(narrow_mesh).is_empty(), "Local Boundary refinement should clear the severe-quality warning on the narrow concave Item fixture without turning the warning into a hard validity gate.")
	for sampling_result in [narrow_sampling, half_narrow_sampling]:
		var samples: Array = sampling_result.get("chains", [])[0].get("samples", [])
		for sample_index in range(samples.size()):
			if str(samples[sample_index].get("source_point_id", "")).is_empty():
				continue
			var previous_length := Vector2(samples[sample_index].get("position", Vector2.ZERO)).distance_to(Vector2(samples[posmod(sample_index - 1, samples.size())].get("position", Vector2.ZERO)))
			var next_length := Vector2(samples[sample_index].get("position", Vector2.ZERO)).distance_to(Vector2(samples[(sample_index + 1) % samples.size()].get("position", Vector2.ZERO)))
			_expect(maxf(previous_length, next_length) / minf(previous_length, next_length) <= GeometrySamplingService.MAX_ADJACENT_CORNER_SEGMENT_RATIO + 0.0001, "Derived Boundary refinement should bound the sample-length transition on both sides of every authored corner.")
	var constrained_body := _closed_linear_fixture("corpus_constraints", "Hole and Cut", [Vector2.ZERO, Vector2(20.0, 0.0), Vector2(20.0, 20.0), Vector2(0.0, 20.0)])
	var hole := _closed_linear_fixture("corpus_hole", "Hole", [Vector2(8.0, 8.0), Vector2(8.0, 12.0), Vector2(12.0, 12.0), Vector2(12.0, 8.0)])
	hole["sampling_input_id"] = "corpus_hole_input"
	hole["topology_role"] = "hole"
	hole["chains"][0]["topology_role"] = "hole"
	var cut := AssetGuide.create("corpus_cut", "Cut", AssetGuide.CUT, "corpus_constraints")
	BezierTopology.add_point(cut, Vector2(10.0, 0.0), "linear")
	BezierTopology.add_point(cut, Vector2(10.0, 20.0), "linear")
	var constrained_result := _run_auto_mesh_fixture(constrained_body, [cut], [hole])
	var constrained_sampling: Dictionary = constrained_result.get("sampling", {})
	var constrained_mesh: Dictionary = constrained_result.get("meshing", {})
	_expect(bool(constrained_result.get("valid", false)) and int(constrained_sampling.get("hole_count", 0)) == 1 and constrained_sampling.get("cuts", []).size() == 1 and int(constrained_mesh.get("cut_seam_vertex_count", 0)) > 0 and int(constrained_mesh.get("diagnostics", {}).get("domain", {}).get("final_constraint_issue_count", -1)) == 0, "The synthetic corpus should cover Hole exclusion plus a two-sided Cut seam without relying on mutable World data.")


func _closed_linear_fixture(component_id: String, component_name: String, positions: Array) -> Dictionary:
	var component := _component()
	component.merge({"id": component_id, "name": component_name, "draw_mode": "closed_loop", "visibility": true, "transform": {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}})
	for position in positions:
		BezierTopology.add_point(component, Vector2(position), "linear")
	BezierTopology.close_active_chain(component)
	return component


func _maximum_authored_corner_sample_ratio(sampling: Dictionary, topology_role := "") -> float:
	var maximum_ratio := 0.0
	for chain_data in sampling.get("chains", []):
		if not topology_role.is_empty() and str(chain_data.get("topology_role", "")) != topology_role:
			continue
		var samples: Array = chain_data.get("samples", [])
		for sample_index in range(samples.size()):
			if str(samples[sample_index].get("source_point_id", "")).is_empty():
				continue
			var position := Vector2(samples[sample_index].get("position", Vector2.ZERO))
			var previous_length := position.distance_to(Vector2(samples[posmod(sample_index - 1, samples.size())].get("position", Vector2.ZERO)))
			var next_length := position.distance_to(Vector2(samples[(sample_index + 1) % samples.size()].get("position", Vector2.ZERO)))
			var shorter := minf(previous_length, next_length)
			if shorter > GeometrySamplingService.ARRANGEMENT_EPSILON:
				maximum_ratio = maxf(maximum_ratio, maxf(previous_length, next_length) / shorter)
	return maximum_ratio


func _run_auto_mesh_fixture(component: Dictionary, cut_guides: Array = [], hole_components: Array = []) -> Dictionary:
	var recipes := GeometryAutoBuildService.automatic_recipes(component, cut_guides, hole_components)
	var sampling := GeometrySamplingService.generate(component, recipes.get("sampling", {}), cut_guides, hole_components)
	if not bool(sampling.get("valid", false)):
		return {"valid": false, "fixture_name": str(component.get("name", "Fixture")), "recipes": recipes, "sampling": sampling, "assessment": GeometryAutoBuildService.automatic_build_assessment(sampling)}
	sampling["bake_id"] = "corpus_sampling"
	var seeding := GeometrySeedingService.generate(sampling, recipes.get("seeding", {}))
	if not bool(seeding.get("valid", false)):
		return {"valid": false, "fixture_name": str(component.get("name", "Fixture")), "recipes": recipes, "sampling": sampling, "seeding": seeding, "assessment": GeometryAutoBuildService.automatic_build_assessment(sampling, seeding)}
	seeding["bake_id"] = "corpus_seeding"
	var meshing := GeometryMeshingService.generate(sampling, seeding, recipes.get("meshing", {}))
	var assessment := GeometryAutoBuildService.automatic_build_assessment(sampling, seeding, meshing)
	return {
		"valid": bool(meshing.get("valid", false)) and bool(assessment.get("accepted", false)),
		"fixture_name": str(component.get("name", "Fixture")),
		"boundary_spacing": float(recipes.get("sampling", {}).get("parameters", {}).get("spacing", 0.0)),
		"seed_spacing": float(recipes.get("seeding", {}).get("parameters", {}).get("spacing", 0.0)),
		"recipes": recipes,
		"sampling": sampling,
		"seeding": seeding,
		"meshing": meshing,
		"assessment": assessment
	}


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
	_expect(application.update_meshes_button.get_parent() == application and application.runtime_export_button.get_parent() == application and not application.update_meshes_button.visible and not application.runtime_export_button.visible, "Legacy batch command controls should remain hidden but owned by the application lifecycle.")
	var visible_categories: Array[String] = []
	var every_category_expanded := true
	for module_section in application.module_sections:
		visible_categories.append(module_section.module_name)
		every_category_expanded = every_category_expanded and module_section.expanded
	_expect(visible_categories == ["Create", "Mesh", "Style", "Export"], "The module rail should provide the dedicated Export workspace while omitting deferred categories.")
	_expect(every_category_expanded, "Every visible category should remain expanded.")
	var test_assets: Array[Dictionary] = [{"id": "asset_1", "name": "Wizard", "visibility": true, "components": [component]}]
	application.assets = test_assets
	application.selected_asset_id = "asset_1"
	application.selected_component_id = "component_1"
	application.expanded_assets["asset_1"] = true
	application._render_canvas_context()
	var draw_mode_popup: PopupMenu = application.draw_mode_status.get_popup()
	_expect(not application.draw_mode_status.disabled and application.draw_mode_status.text.contains("Closed Loop") and draw_mode_popup.item_count == 3 and draw_mode_popup.is_item_checked(0), "The toolbar Draw Mode status should be a clickable, checked menu for the selected Create Component.")
	_expect(not draw_mode_popup.is_item_disabled(1) and draw_mode_popup.is_item_disabled(2), "Authored Bezier geometry should switch losslessly to Contour while disabling destructive implicit Primitive conversion.")
	application.active_module = "Mesh"
	application.active_geometry_submodule = "Sampling"
	application._render_outliner()
	application._render_inspector()
	application._render_canvas_context()
	_expect(application.batch_status_snapshot_build_count == 0, "Editing workspaces must not calculate Batch status for detached toolbar controls.")
	application._on_category_pressed("Export")
	_expect(application.runtime_export_view.visible and application.runtime_export_view.summary_label.text.contains("Preflight abgeschlossen") and application.runtime_export_view.log_label.get_parsed_text().contains("Wizard / Body"), "Export should run one preflight on entry and list affected Asset / Component data in its read-only log.")
	_expect(application.runtime_export_view.consumer_sync_label.text.contains("noch nicht ausgeführt") and FileAccess.file_exists(application._consumer_sync_script_path()), "Export should expose persistent downstream Consumer Sync feedback backed by the PolyTools-owned orchestration script.")
	application._present_consumer_sync_result({"success": true, "exit_code": 0, "output": "POLYTOOLS CONSUMER SYNC SUCCESS"})
	_expect(application.runtime_export_view.consumer_sync_label.text.contains("erfolgreich") and application.runtime_export_view.log_label.get_parsed_text().contains("SceneMaker und world01 wurden synchronisiert"), "Successful downstream synchronization should be visible in the Export workspace.")
	application._present_consumer_sync_result({"success": false, "exit_code": 7, "output": "test failure"})
	_expect(application.runtime_export_view.consumer_sync_label.text.contains("fehlgeschlagen") and application.runtime_export_view.log_label.get_parsed_text().contains("Runtime Export bleibt erhalten"), "Consumer Sync failures should remain visible without presenting the Runtime export as rolled back.")
	_expect(not application.runtime_export_view.log_label.get_parsed_text().contains("UV ·") and not application.runtime_export_view.log_label.get_parsed_text().contains("SDF ·"), "Schema-4 Build/Export preflight must not retain legacy UV or SDF stages.")
	_expect(application.export_run_button.visible and application.export_run_button.text == "Build All (1)" and application.export_valid_button.visible and application.export_sync_button.visible and application.export_sync_button.get_index() == application.export_valid_button.get_index() + 1 and application.context_bar_panel.visible == false and application.draw_mode_status.visible == false, "Export should replace Create context controls with Build, valid-only Export, and a separate adjacent Consumer Sync action in the top toolbar.")
	var batch_snapshot_builds: int = application.batch_status_snapshot_build_count
	application._record_direct_change()
	_expect(application.batch_status_snapshot_build_count == batch_snapshot_builds, "A document mutation must only mark Batch status dirty until Export is opened again.")
	application.active_module = "Mesh"
	application._render_canvas_context()
	_expect(application.geometry_sampling_workspace.visible, "Geometry Sampling should own a dedicated visible centre workspace.")
	_expect(application.outliner_view.get_child_count() > 1, "Sampling Outliner should expose the Asset/Component hierarchy.")
	# Rendered here on purpose: the assertion below used to run against whatever
	# the previous module had left in the Inspector.
	application._render_inspector()
	_expect(application.geometry_inspector_view.get_child_count() >= 8, "A selected Component should expose Adaptive parameters, boundary inputs, result, and Bake controls.")
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
	application.geometry_documents["asset_1/component_1"] = WorldDocumentService.default_geometry_document("asset_1", "component_1")
	application._push_undo_snapshot()
	var history_snapshot: Dictionary = application.undo_history.back()
	application._mutable_geometry_document("asset_1", "component_1")["sampling"]["recipe"]["parameters"]["spacing"] = 42.0
	application._restore_history_snapshot(history_snapshot)
	_expect(is_equal_approx(float(application.geometry_documents["asset_1/component_1"]["sampling"]["recipe"]["parameters"]["spacing"]), GeometrySamplingService.DEFAULT_SPACING), "Geometry recipes and bakes should participate in World Undo/Redo snapshots.")
	var create_section: ModuleSection = application._find_section("Create")
	application._select_submodule("Create", "Props", create_section)
	_expect(application.active_module == "Create" and application.active_create_submodule == "Props" and application.canvas_view.visible and not application.geometry_sampling_workspace.visible, "Selecting Create Props should immediately render the shared asset workspace.")
	_expect(application._find_section("Mesh").active_submodule.is_empty() and application._find_section("Style").active_submodule.is_empty(), "Only the selected module should remain highlighted across always-expanded categories.")
	application.asset_name_input.text = "Shield"
	application._confirm_asset_creation()
	_expect(str(application.assets[-1].get("asset_type", "")) == "props", "Create Props should persist the stable props Asset type.")
	application._select_submodule("Create", "Weapons", create_section)
	_expect(application.active_module == "Create" and application.active_create_submodule == "Weapons" and application.canvas_view.visible, "Selecting Create Weapons should immediately render the shared asset workspace.")
	application.asset_name_input.text = "Sword"
	application._confirm_asset_creation()
	_expect(str(application.assets[-1].get("asset_type", "")) == "weapons", "Create Weapons should persist the stable weapons Asset type.")
	application._select_submodule("Create", "Items", create_section)
	_expect(application.active_module == "Create" and application.active_create_submodule == "Items" and application.canvas_view.visible, "Selecting Create Items should immediately render the shared asset workspace.")
	application.asset_name_input.text = "Potion"
	application._confirm_asset_creation()
	_expect(str(application.assets[-1].get("asset_type", "")) == "items", "Create Items should persist the stable items Asset type.")
	_expect(WorldDocumentService.normalize_asset_type("") == "character" and application._asset_type_create_submodule("icon") == "Icon" and application._asset_type_create_submodule("weapons") == "Weapons" and application._asset_type_create_submodule("items") == "Items", "Missing Asset types should normalize to Character while valid types map back to their Create module.")
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
	_expect(application.active_state == "edit" and application.active_edit_mode == "edge" and application.selected_edge_ids.size() == 2 and application.canvas_view.selected_edge_ids.size() == 2, "Changing Render Outline should preserve the active Edge Inspector and its selection.")
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
	var geometry_document: Dictionary = WorldDocumentService.default_geometry_document("asset_1", "component_1")
	geometry_document["sampling"]["recipe"] = {"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 1.0}}
	geometry_document["sampling"]["bakes"][GeometrySamplingService.ADAPTIVE] = sampling
	first["bake_id"] = "seeding_bake_test"
	first["edited"] = true
	first["seeds"][0]["origin"] = "manual_adjusted"
	geometry_document["seeding"]["recipe"] = {"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 2.0, "seed": 17}}
	geometry_document["seeding"]["bakes"][GeometrySeedingService.POISSON_FILL] = first
	var serialized: Dictionary = WorldDocumentService.serialize_geometry_document(geometry_document)
	_expect(serialized.get("seeding", {}).get("bakes", {}).get(GeometrySeedingService.POISSON_FILL, {}).get("seeds", [])[0].get("position", null) is Array, "Seeding method Bake positions should serialize as schema JSON arrays.")
	var normalized: Dictionary = WorldDocumentService.normalize_geometry_document(serialized, "asset_1", "component_1")
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
	_expect(application.geometry_seeding_workspace.visible and application.geometry_inspector_view.get_child_count() >= 10, "Geometry Seeding should expose its dedicated Workspace and compact Poisson Inspector.")
	var seeding_outliner_text := _control_text(application.outliner_view)
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
	var seeding_edit_info_text := _control_text(application.info_bar)
	_expect(seeding_edit_info_text.contains("State: Edit Seeds") and seeding_edit_info_text.contains("1: Select / Move") and not seeding_edit_info_text.contains("Bounds / Planar"), "Edit Seeds should render only its current Seeding controls in the Info Bar.")
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
	_expect(int(cdt.get("algorithm_version", 0)) == GeometryMeshingService.ALGORITHM_VERSION and int(cdt.get("diagnostics", {}).get("domain", {}).get("final_constraint_issue_count", -1)) == 0, "Constrained Mesh must classify final domain faces topologically and report zero final Constraint coverage issues.")
	_expect(cdt == repeated, "Meshing must be deterministic for identical Sampling, Seeding, and recipe inputs.")
	_expect(bool(cdt.get("boundary_refinement", {}).get("enabled", false)) and bool(cdt.get("boundary_refinement", {}).get("complete", false)), "A current Sampling Bake should expose its completed corner-refinement provenance in the Mesh result.")
	_expect(not bool(GeometryMeshingService.boundary_refinement_summary({"algorithm_version": GeometrySamplingService.CORNER_BALANCING_VERSION - 1}).get("enabled", true)), "A legacy Sampling Bake should not claim that Boundary corner refinement was enabled.")
	var mesh_round_trip_source := cdt.duplicate(true)
	mesh_round_trip_source["boundary_refinement"] = {"enabled": true, "added_vertex_count": 64, "complete": false, "unresolved_corner_count": 7, "limit_reached": true}
	var mesh_round_trip := WorldDocumentService.normalize_meshing_bake(WorldDocumentService.serialize_meshing_bake(mesh_round_trip_source))
	_expect(mesh_round_trip.get("boundary_refinement", {}) == mesh_round_trip_source.get("boundary_refinement", {}), "Meshing persistence should preserve Boundary-refinement completion diagnostics.")
	var warning_result := {"vertex_count": 30, "triangle_count": 28, "minimum_angle": 1.0, "worst_aspect_ratio": 60.0, "mean_quality": 0.4, "constraints_valid": true, "cut_seam_vertex_count": 0, "optimization": {}, "boundary_refinement": {"enabled": true, "added_vertex_count": 64, "complete": false, "unresolved_corner_count": 7, "limit_reached": true}}
	var quality_diagnostic_line := "Quality Warning: %s" % GeometryMeshingService.quality_warnings(warning_result)[0]
	var refinement_diagnostic_line := "Boundary Refinement Warning: %s" % GeometryMeshingService.boundary_refinement_warning(warning_result)
	var warning_view := GeometryInspectorView.new()
	warning_view.set_submodule("Meshing", 4.0)
	warning_view.set_meshing_context({
		"component": component,
		"recipe": cdt_recipe,
		"source_issues": [],
		"sampling_bake_is_current": true,
		"seeding_bakes": {},
		"input_is_current": true,
		"meshing_input": {"sampling": sampling},
		"view_options": [],
		"build_diagnostic_lines": [quality_diagnostic_line, refinement_diagnostic_line],
		"status": "Baked",
		"auto_build_error": "",
		"result": warning_result,
		"advanced_relaxation_expanded": false
	})
	warning_view.rebuild()
	var warning_view_text := _control_text(warning_view)
	_expect(warning_view_text.contains("Quality Warning: Minimum angle") and warning_view_text.contains("Quality Warning: Worst aspect ratio") and warning_view_text.contains("Boundary Refinement Warning:"), "The Meshing Inspector should visibly distinguish accepted quality and incomplete-refinement diagnostics from validity failures.")
	_expect(warning_view_text.count(quality_diagnostic_line) == 1 and warning_view_text.count(refinement_diagnostic_line) == 1, "Auto Build and Result sections should not duplicate identical quality or Boundary-refinement warnings.")
	warning_view.free()
	var pslg_diagnostics := GeometryMeshingService._pslg_validation_issues(PackedVector2Array([Vector2.ZERO, Vector2(2.0, 0.0), Vector2(1.0, 0.0)]), [[0, 1]], [{"topology_role": "cut", "chain_id": "cut:test", "fragment_index": 0, "segment_index": 10}])
	_expect(not pslg_diagnostics.is_empty() and str(pslg_diagnostics[0]).contains("Cut fragment 1, segment 11") and str(pslg_diagnostics[0]).contains("shared sampled junction"), "PSLG diagnostics should identify the exact Cut fragment and local segment that passes through an unsplit vertex.")
	var complete_constraint_issues := GeometryMeshingService._final_constraint_issues([[0, 1, 2]], [[0, 1], [1, 2], [2, 0]], [
		{"topology_role": "outer", "chain_id": "outer:test", "segment_index": 0},
		{"topology_role": "outer", "chain_id": "outer:test", "segment_index": 1},
		{"topology_role": "outer", "chain_id": "outer:test", "segment_index": 2}
	])
	var missing_constraint_issues := GeometryMeshingService._final_constraint_issues([[0, 1, 2]], [[0, 3]], [{"topology_role": "outer", "chain_id": "outer:test", "segment_index": 7}])
	var one_sided_cut_issues := GeometryMeshingService._final_constraint_issues([[0, 1, 2]], [[0, 1]], [{"topology_role": "cut", "chain_id": "cut:test", "fragment_index": 1, "segment_index": 2}])
	_expect(complete_constraint_issues.is_empty() and missing_constraint_issues.size() == 1 and str(missing_constraint_issues[0]).contains("Outer segment 8") and str(missing_constraint_issues[0]).contains("0 Triangles"), "Final Mesh validation must reject an Outer Constraint that disappeared during domain classification and identify its exact segment.")
	_expect(one_sided_cut_issues.size() == 1 and str(one_sided_cut_issues[0]).contains("Cut fragment 2, segment 3") and str(one_sided_cut_issues[0]).contains("expected 2"), "Final Mesh validation must reject a Cut Constraint without two-sided Triangle coverage.")
	var concave_positions := PackedVector2Array([Vector2.ZERO, Vector2(4.0, 0.0), Vector2(4.0, 4.0), Vector2(2.0, 2.0), Vector2(0.0, 4.0)])
	var concave_constraints: Array = [[0, 1], [1, 2], [2, 3], [3, 4], [4, 0]]
	var concave_constraint_data: Array = []
	for segment_index in range(concave_constraints.size()):
		concave_constraint_data.append({"topology_role": "outer", "chain_id": "outer:concave", "segment_index": segment_index})
	var concave_domain := GeometryMeshingService._select_domain_triangles([[0, 1, 3], [1, 2, 3], [0, 3, 4], [2, 4, 3]], concave_positions, concave_constraints, concave_constraint_data)
	_expect(bool(concave_domain.get("valid", false)) and concave_domain.get("triangles", []).size() == 3 and int(concave_domain.get("diagnostics", {}).get("final_constraint_issue_count", -1)) == 0, "Topology-based domain classification must retain every interior face of a concave Outer while excluding the convex-hull face outside its Constraint barrier.")
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
	_expect(bool(holed_mesh.get("valid", false)) and bool(holed_mesh.get("constraints_valid", false)) and int(holed_mesh.get("triangle_count", 0)) > 0 and int(holed_mesh.get("diagnostics", {}).get("domain", {}).get("final_constraint_issue_count", -1)) == 0, "Constrained Delaunay should recover every final sampled Constraint around holes.")
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
	var serialized_organic: Dictionary = WorldDocumentService.serialize_meshing_bake(organic)
	var normalized_organic: Dictionary = WorldDocumentService.normalize_meshing_bake(serialized_organic)
	_expect(serialized_organic.get("optimization", {}).get("movements", [])[0].get("from", null) is Array and normalized_organic.get("optimization", {}).get("movements", [])[0].get("from", null) is Vector2, "Meshing persistence should serialize and restore Optimization movement diagnostics for before/after views.")
	var document: Dictionary = WorldDocumentService.default_geometry_document("asset_1", "component_1")
	document["sampling"]["recipe"] = {"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 2.0}}
	document["sampling"]["bakes"][GeometrySamplingService.ADAPTIVE] = sampling
	document["seeding"]["recipe"] = {"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 2.5, "seed": 9}}
	document["seeding"]["bakes"][GeometrySeedingService.POISSON_FILL] = seeding
	document["meshing"]["recipe"] = cdt_recipe
	cdt["bake_id"] = "mesh_cdt_test"
	document["meshing"]["bakes"][GeometryMeshingService.CONSTRAINED_MESH] = cdt
	var serialized: Dictionary = WorldDocumentService.serialize_geometry_document(document)
	_expect(serialized.get("meshing", {}).get("bakes", {}).get(GeometryMeshingService.CONSTRAINED_MESH, {}).get("vertices", [])[0].get("position", null) is Array, "Mesh Bake positions should serialize as JSON arrays.")
	var normalized: Dictionary = WorldDocumentService.normalize_geometry_document(serialized, "asset_1", "component_1")
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
	var migrated_legacy: Dictionary = WorldDocumentService.normalize_geometry_document(legacy_document, "asset_1", "component_1")
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
	_expect(application.geometry_meshing_workspace.visible and application.geometry_inspector_view.get_child_count() >= 10, "Geometry Meshing should expose its dedicated Workspace and compact Inspector.")
	var meshing_inspector_text := _control_text(application.inspector_content)
	var meshing_outliner_text := _control_text(application.outliner_view)
	_expect(meshing_inspector_text.contains("Constrained Mesh · Automatic") and meshing_inspector_text.contains("Mesh Character") and meshing_inspector_text.contains("Optimize Mesh") and meshing_inspector_text.contains("Advanced Optimization") and meshing_inspector_text.contains("Optimization") and meshing_inspector_text.contains("Quality") and meshing_inspector_text.contains("Auto Build Diagnostics") and meshing_inspector_text.contains("Recipe Ownership: Manual · Legacy / unclassified recipe") and not meshing_inspector_text.contains("Use as Component Mesh"), "Meshing should expose one Artistic Constrained Mesh workflow, explicit optimization control, read-only build provenance, and both diagnostic views without a separate Component Mesh action.")
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
	component["transform"] = WorldDocumentService.default_component_transform()
	component["transform"]["position"] = Vector2(17.0, -6.0)
	application.selected_component_id = ""
	application._refresh_geometry_meshing_workspace()
	var asset_overview: Dictionary = application.geometry_meshing_workspace.mesh_result
	var local_mesh_position := Vector2(accepted_mesh.get("vertices", [])[0].get("position", Vector2.ZERO))
	var overview_position := Vector2(asset_overview.get("vertices", [])[0].get("position", Vector2.ZERO))
	_expect(bool(asset_overview.get("valid", false)) and int(asset_overview.get("mesh_component_count", 0)) == 1 and str(asset_overview.get("vertices", [])[0].get("id", "")).begins_with("component_1/") and overview_position.is_equal_approx(local_mesh_position + Vector2(17.0, -6.0)), "Selecting a Meshing root Asset should compose current Component Meshes in the same transformed Asset coordinate space as Create.")
	var component_mesh_round_trip: Dictionary = WorldDocumentService.normalize_geometry_document(WorldDocumentService.serialize_geometry_document(normalized), "asset_1", "component_1")
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


func _test_geometry_uv_mapping_service_and_legacy_records() -> void:
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
	var document: Dictionary = WorldDocumentService.default_geometry_document("asset_1", "component_1")
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
	var serialized: Dictionary = WorldDocumentService.serialize_geometry_document(document)
	_expect(serialized.get("uv_mapping", {}).get("bakes", {}).get(uv_key, {}).get("uvs", [])[0].get("uv", null) is Array, "UV Bake coordinates should serialize as JSON arrays.")
	var normalized: Dictionary = WorldDocumentService.normalize_geometry_document(serialized, "asset_1", "component_1")
	_expect(normalized.get("uv_mapping", {}).get("bakes", {}).get(uv_key, {}).get("uvs", [])[0].get("uv", null) is Vector2, "UV Bake loading should restore normalized coordinates as Vector2 values.")
	# UV Mapping has no authoring surface any more. Schema 37 records stay
	# readable Legacy data, so a load/save round trip must return them unchanged.
	var round_trip: Dictionary = WorldDocumentService.normalize_geometry_document(WorldDocumentService.serialize_geometry_document(normalized), "asset_1", "component_1")
	_expect(JSON.stringify(WorldDocumentService.serialize_geometry_document(round_trip)) == JSON.stringify(serialized), "A legacy UV Bake must survive a load and save round trip unchanged.")
	application.free()


func _test_geometry_sdf_service_and_legacy_records() -> void:
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
	ribbon.merge({"id": "component_sdf", "name": "ArmLine", "draw_mode": "contour", "visibility": true})
	BezierTopology.add_point(ribbon, Vector2.ZERO, "linear")
	BezierTopology.add_point(ribbon, Vector2(0.0, 8.0), "linear")
	var contour_mesh := ContourMeshService.generate(ribbon)
	contour_mesh["bake_id"] = "mesh_contour_sdf_test"
	var contour_uv_recipe := GeometryUVMappingService.default_recipe()
	contour_uv_recipe["parameters"]["mesh_method"] = ContourMeshService.METHOD
	var contour_uv := GeometryUVMappingService.generate(contour_mesh, contour_uv_recipe)
	contour_uv["bake_id"] = "uv_contour_sdf_test"
	var application_script = load("res://scripts/main.gd")
	var application: Control = application_script.new()
	var document: Dictionary = WorldDocumentService.default_geometry_document("asset_sdf", "component_sdf")
	document["meshing"]["bakes"][ContourMeshService.METHOD] = contour_mesh
	document["component_mesh"] = {"bake_id": "mesh_contour_sdf_test", "method": ContourMeshService.METHOD, "mesh_fingerprint": GeometryUVMappingService.mesh_fingerprint(contour_mesh)}
	document["uv_mapping"]["recipe"] = contour_uv_recipe
	document["uv_mapping"]["bakes"][GeometryUVMappingService.bake_key(ContourMeshService.METHOD, GeometryUVMappingService.BOUNDS_PLANAR)] = contour_uv
	document["sdf"]["last_error"] = "Legacy validation failure"
	document["sdf"]["last_failure_fingerprint"] = GeometrySDFService.source_fingerprint(contour_mesh, contour_uv, document["sdf"]["recipe"])
	var assets: Array[Dictionary] = [{"id": "asset_sdf", "name": "Wizard", "visibility": true, "components": [ribbon], "guides": []}]
	application.assets = assets
	application.geometry_documents["asset_sdf/component_sdf"] = document
	# SDF has no authoring surface any more. Schema 37 records stay readable
	# Legacy data, so an accepted Bake must survive load and save unchanged and
	# must not be reinterpreted on the way.
	document["sdf"]["bake"] = {
		"valid": true,
		"bake_id": "sdf_legacy_bake",
		"method": GeometrySDFService.SINGLE_CHANNEL_SDF,
		"algorithm_version": 1,
		"parameters": GeometrySDFService.default_recipe()["parameters"],
		"resolution": [256, 256],
		"image_path": "contour_sdf.png",
		"pixel_hash": "legacyhash",
		"source_fingerprint": GeometrySDFService.source_fingerprint(contour_mesh, contour_uv, document["sdf"]["recipe"]),
		"boundary_value": 0.5,
		"inside_is_high": true
	}
	var serialized: Dictionary = WorldDocumentService.serialize_geometry_document(document)
	_expect(str(serialized.get("sdf", {}).get("bake", {}).get("image_path", "")) == "contour_sdf.png" and not serialized.get("sdf", {}).get("bake", {}).has("image"), "A serialized SDF Bake should keep its relative image reference and carry no pixel data.")
	var round_trip: Dictionary = WorldDocumentService.normalize_geometry_document(serialized, "asset_sdf", "component_sdf")
	_expect(str(round_trip.get("sdf", {}).get("bake", {}).get("pixel_hash", "")) == "legacyhash", "Loading a legacy SDF Bake must preserve its pixel hash.")
	_expect(JSON.stringify(WorldDocumentService.serialize_geometry_document(round_trip)) == JSON.stringify(serialized), "A legacy SDF Bake must survive a load and save round trip unchanged.")
	application.free()


func _test_component_names() -> void:
	var application_script = load("res://scripts/main.gd")
	var application: Control = application_script.new()
	var naming_asset := {"components": []}
	_expect(application._component_name_validation_error("weapon_head_left", naming_asset).is_empty(), "Component names should accept lower_snake_case.")
	_expect(not application._component_name_validation_error("Weapon Head", naming_asset).is_empty(), "Component names should reject spaces and uppercase letters.")
	_expect(not application._component_name_validation_error("_weapon_head", naming_asset).is_empty(), "Component names should reject a leading underscore.")
	var source_component := _component()
	source_component.merge({"id": "component_1", "name": "body", "visibility": true})
	var semantic_asset := {"id": "character", "name": "Character", "asset_type": "character", "visibility": true, "components": [source_component], "guides": []}
	var symbol_asset := {"id": "orb", "name": "Orb", "asset_type": "symbols", "visibility": true, "components": [], "guides": []}
	var semantic_assets: Array[Dictionary] = [semantic_asset, symbol_asset]
	application.assets = semantic_assets
	application._build_ui()
	var context_menu_items: Array[String] = []
	for item_index in application.component_context_menu.item_count:
		context_menu_items.append(application.component_context_menu.get_item_text(item_index))
	_expect(application.component_context_menu.get_item_text(application.component_context_menu.get_item_index(4)) == "Group" and application.component_context_menu.get_item_text(application.component_context_menu.get_item_index(6)) == "Copy Components" and application.component_context_menu.get_item_text(application.component_context_menu.get_item_index(0)) == "Duplicate" and not context_menu_items.has("Guide → Weapon") and not context_menu_items.has("Region"), "The Component context menu should expose Component Clipboard actions above Duplicate with separators and omit Guide → Weapon and Region creation.")
	_expect(not application.component_dialog.dialog_text.is_empty(), "Component creation should use a normal free-name input.")
	application._duplicate_component("character", "component_1")
	_expect(semantic_asset.get("components", []).size() == 2 and str(semantic_asset.get("components", [])[1].get("name", "")) == "body Copy", "Duplicating a Component should generate a unique free name automatically.")
	application.component_dialog.set_meta("asset_id", "character")
	application.component_dialog.set_meta("parent_component_id", "")
	application.component_dialog.set_meta("draw_mode", "reference")
	application.component_dialog.set_meta("source_asset_id", "orb")
	application.component_name_input.text = "reference"
	application._confirm_component_creation()
	var created_reference: Dictionary = semantic_asset.get("components", [])[2]
	_expect(str(created_reference.get("type", "")) == "reference" and str(created_reference.get("name", "")) == "reference" and str(created_reference.get("source_asset_id", "")) == "orb" and created_reference.get("points", []).is_empty(), "Reference creation should retain the source Asset ID without copying its Component geometry.")
	created_reference["parent_component_id"] = "component_1"
	_expect(application.outliner_view._component_tree_name(created_reference) == "R: reference" and WorldDocumentService.component_outliner_name(application.assets, created_reference) == "reference ← Orb" and application.outliner_view._reference_outliner_tooltip(semantic_asset, created_reference) == "Referenced asset: Orb\nAttached to: body", "The Component tree should mark References locally while the References overview names their source Asset and retains the Parent in the tooltip.")
	application._duplicate_component("character", str(created_reference.get("id", "")), "flip_orientation")
	var mirrored_reference: Dictionary = application._get_component(semantic_asset, application.selected_component_id)
	_expect(str(mirrored_reference.get("type", "")) == "reference" and Vector2(mirrored_reference.get("transform", {}).get("scale", Vector2.ZERO)) == Vector2.ONE and Vector2(mirrored_reference.get("reference_instance_scale", Vector2.ONE)).x < 0.0, "Duplicate & Mirror should normalize the Component Scale while preserving the signed Reference instance Scale.")
	application.free()


func _test_component_clipboard() -> void:
	var application: Control = load("res://scripts/main.gd").new()
	var component_transform := {"position": Vector2(2.0, -1.0), "rotation": 12.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}
	var eye_left := {"id": "eye_left", "type": "component", "name": "eye_left", "draw_mode": "closed_loop", "parent_component_id": "", "group_id": "", "points": [], "edges": [], "chains": [], "transform": component_transform.duplicate(true)}
	var eye_right := {"id": "eye_right", "type": "component", "name": "eye_right", "draw_mode": "closed_loop", "parent_component_id": "", "group_id": "", "points": [], "edges": [], "chains": [], "transform": {"position": Vector2(-2.0, -1.0), "rotation": -12.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}}
	var mage := {"id": "mage", "name": "Mage", "asset_type": "character", "visibility": true, "components": [eye_left, eye_right], "guides": [AssetGuide.create("guide_1", "Eye Flow", AssetGuide.FLOW, "eye_left", 1)]}
	var head := {"id": "chantres_head", "type": "component", "name": "head", "draw_mode": "closed_loop", "parent_component_id": "", "group_id": "", "points": [], "edges": [], "chains": [], "transform": {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}}
	var chantres := {"id": "chantres", "name": "Chantres", "asset_type": "character", "visibility": true, "components": [head], "guides": []}
	var clipboard_assets: Array[Dictionary] = [mage, chantres]
	application.assets = clipboard_assets
	application.next_component_id = 100
	application.next_guide_id = 10
	application._build_ui()
	application.selected_asset_id = "mage"
	application.selected_component_id = "eye_right"
	var copied_selection: Array[String] = ["eye_left", "eye_right"]
	application.selected_component_ids = copied_selection
	application._copy_selected_component_subtrees()
	application._paste_component_clipboard("chantres", "chantres_head")
	var pasted_asset: Dictionary = application._get_asset("chantres")
	var pasted_left: Dictionary = application._get_component(pasted_asset, "component_100")
	var pasted_right: Dictionary = application._get_component(pasted_asset, "component_101")
	var pasted_guide: Dictionary = application._get_guide(pasted_asset, "guide_10")
	_expect(pasted_asset.get("components", []).size() == 3 and str(pasted_left.get("parent_component_id", "")) == "chantres_head" and str(pasted_right.get("parent_component_id", "")) == "chantres_head" and str(pasted_left.get("name", "")) == "eye_left" and Vector2(pasted_left.get("transform", {}).get("position", Vector2.ZERO)).is_equal_approx(Vector2(2.0, -1.0)), "Pasting multiple Components onto a target Parent should preserve their local transforms and assign fresh Component IDs.")
	_expect(str(pasted_guide.get("scope", {}).get("component_id", "")) == "component_100" and int(pasted_guide.get("ordinal", 0)) == 1, "Component-scoped Guides must paste with their copied Component and remapped scope ID.")
	application._restore_history_snapshot(application.undo_history.back())
	_expect(application.undo_history.size() == 1 and application._get_asset("chantres").get("components", []).size() == 1 and application._get_asset("chantres").get("guides", []).is_empty(), "Pasting Component Clipboard contents must capture one Undo snapshot.")
	var restored_chantres: Dictionary = application._get_asset("chantres")
	var paste_hole := {"id": "paste_hole", "type": "component", "name": "opening", "draw_mode": "primitive", "topology_role": "hole", "visibility": true, "parent_component_id": "chantres_head", "group_id": "", "transform": WorldDocumentService.default_component_transform(), "primitive": {"type": "circle", "center": Vector2.ZERO, "diameter_cm": 2.0}, "points": [], "edges": [], "chains": []}
	restored_chantres["components"].append(paste_hole)
	var component_count_before_rejected_paste: int = restored_chantres.get("components", []).size()
	var next_component_before_rejected_paste: int = application.next_component_id
	application._paste_component_clipboard("chantres", "paste_hole")
	_expect(restored_chantres.get("components", []).size() == component_count_before_rejected_paste and application.next_component_id == next_component_before_rejected_paste, "Pasting onto an ordinary Hole must be rejected before allocating IDs or mutating the Asset.")
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
	var item_catalog: Dictionary = AssetCatalogService.build_catalog("world01", "World", [{"id": "potion", "name": "Potion", "asset_type": "items", "visibility": true}]).get("catalog", {})
	_expect(str(item_catalog.get("assets", [])[0].get("asset_type", "")) == "items", "The public Asset Catalog should retain the stable Items Asset type.")
	var collision_assets: Array[Dictionary] = assets.duplicate(true)
	collision_assets.append({"id": "internal_4", "name": "Magic-Orb", "asset_type": "props", "visibility": false})
	_expect(not bool(AssetCatalogService.build_catalog("world01", "World", collision_assets).get("valid", true)), "Asset Key collisions should be rejected even when one conflicting Asset is hidden.")
	var application = load("res://scripts/main.gd").new()
	application.assets = assets
	_expect(application._asset_name_validation_error("Magic-Orb") == "Asset Key 'magic_orb' is already used by 'Magic Orb'.", "Asset creation and rename validation should explain the exact derived-key collision.")
	application.free()


func _runtime_export_file_test_manifest(display_name: String) -> Dictionary:
	# A Manifest the contract actually accepts, so write_package really exercises
	# its staged read-back instead of validating a placeholder.
	var mesh := {"valid": true,
		"vertices": [{"id": "v0", "position": Vector2(0.0, 0.0)},
			{"id": "v1", "position": Vector2(10.0, 0.0)},
			{"id": "v2", "position": Vector2(0.0, 10.0)}],
		"triangles": [{"vertex_ids": ["v0", "v1", "v2"]}]}
	var contour_stroke: Dictionary = mesh.duplicate(true)
	contour_stroke.merge({"method": ContourMeshService.METHOD, "has_outline": true,
		"topology_role": "outer",
		"runs": [{"run_id": "boundary:run:0", "edge_ids": ["edge_0"], "closed": true,
			"start_cap": "none", "end_cap": "none", "vertex_offset": 0, "vertex_count": 3,
			"index_offset": 0, "index_count": 3}],
		"parameters": {"reference_pixels_per_meter": 192.0, "stroke_width_px": 4.0,
			"stroke_width_meters": 0.020833333333333332, "join": "miter",
			"miter_limit": 4.0, "cap": "butt"}}, true)
	var body := {"id": "component_1", "name": "body", "visibility": true, "z_index": 0,
		"parent_component_id": "",
		"transform": {"position": Vector2.ZERO, "pivot": Vector2.ZERO, "rotation": 0.0,
			"scale": Vector2.ONE},
		"points": []}
	var asset := {"id": "asset_1", "name": display_name, "asset_type": "character",
		"authored_facing": AssetPresentation.AuthoredFacing.NEUTRAL, "visibility": true,
		"asset_pivot": Vector2.ZERO, "components": [body]}
	var result := RuntimeExportService.build_manifest(asset,
		{"component_1": {"mesh": mesh, "contour_stroke": contour_stroke}})
	_expect(bool(result.get("valid", false)),
		"The Runtime export file fixture should build a valid Manifest; otherwise the file tests prove nothing.")
	return result.get("manifest", {})


func _remove_runtime_export_file_test_tree(path: String) -> void:
	# The test's own cleanup, deliberately not the service under test, so a
	# mutation of remove_tree shows up as a failing assertion rather than as
	# leftover files. It refuses anything outside the one temporary root.
	var allowed_root := ProjectSettings.globalize_path("user://").trim_suffix("/")
	if not path.begins_with(allowed_root + "/polytools_runtime_export_file_test"):
		return
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	# DirAccess skips hidden entries by default; the temporary root may hold the
	# service's dot-prefixed staging directories, so cleanup has to see them.
	directory.include_hidden = true
	for file_name in directory.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	for directory_name in directory.get_directories():
		_remove_runtime_export_file_test_tree(path.path_join(directory_name))
	DirAccess.remove_absolute(path)


func _export_surface_summary(pending: PackedStringArray, attention: PackedStringArray) -> Dictionary:
	return {"pending": pending, "attention": attention}


func _export_surface_stage(candidates: Array, pending: PackedStringArray,
		attention: PackedStringArray) -> Dictionary:
	return {"candidates": candidates, "summary": _export_surface_summary(pending, attention)}


func _export_surface_package(asset_id: String, valid: bool, error: String) -> Dictionary:
	return {"kind": "package", "asset_id": asset_id,
		"build": {"valid": valid, "errors": [] if error.is_empty() else [error], "manifest": {}}}


func _export_surface_mesh_candidate(asset_id: String, component_id: String) -> Dictionary:
	return {"asset_id": asset_id, "component_id": component_id}


func _export_surface_apply(application: Control, preflight: Dictionary, current: bool,
		batch_mesh_candidates: Array, batch_attention: PackedStringArray) -> void:
	application.export_preflight = preflight
	application.batch_status_revision += 1
	application.export_preflight_revision = application.batch_status_revision if current \
		else application.batch_status_revision - 1
	application.batch_status_snapshot = {
		"mesh": _export_surface_stage(batch_mesh_candidates, PackedStringArray(), batch_attention),
		"uv": _export_surface_stage([], PackedStringArray(), PackedStringArray()),
		"sdf": _export_surface_stage([], PackedStringArray(), PackedStringArray()),
		"runtime": _export_surface_stage([], PackedStringArray(), PackedStringArray()),
	}
	application.batch_status_snapshot_revision = application.batch_status_revision
	application._render_export_preflight()
	application._update_meshes_button()


func _export_surface_observation(application: Control) -> String:
	# The same observation the render probe prints, reduced to one comparable
	# string. Two states that produce the same string are the same state.
	var parts: Array[String] = []
	for pair in [["export_workspace", application.runtime_export_view],
			["outliner_panel", application.outliner_panel],
			["inspector_panel", application.inspector_panel],
			["context_bar_panel", application.context_bar_panel],
			["canvas_view", application.canvas_view]]:
		parts.append("%s=%s" % [str(pair[0]), str((pair[1] as Control).visible)])
	parts.append("summary=%s" % str(application.runtime_export_view.summary_label.text))
	parts.append("sync=%s" % str(application.runtime_export_view.consumer_sync_label.text))
	for pair in [["build_all", application.export_run_button],
			["export_all_valid", application.export_valid_button],
			["sync_consumers", application.export_sync_button],
			["update_meshes", application.update_meshes_button]]:
		var button := pair[1] as Button
		parts.append("%s=%s/%s/%s" % [str(pair[0]), str(button.text),
			str(button.visible), str(button.disabled)])
	parts.append("update_meshes_attention=%d" % (application.update_meshes_button as BatchStatusButton).attention_count)
	parts.append("running=%s/%s" % [str(application.export_running), str(application.mesh_batch_running)])
	parts.append("preflight_current=%s" % str(
		application.export_preflight_revision == application.batch_status_revision))
	parts.append("batch_mesh=%d" % (application.batch_status_snapshot.get("mesh", {}).get("candidates", []) as Array).size())
	parts.append("log=%s" % str(application.runtime_export_view.log_label.get_parsed_text()))
	return "|".join(parts)


const RUNTIME_EXPORT_SIGNAL_ROUTES := [
	["build_all_requested", "_on_build_all_pressed"],
	["export_all_valid_requested", "_on_export_all_valid_pressed"],
	["sync_consumers_requested", "_on_sync_consumers_pressed"],
]


func _test_runtime_export_view_wiring() -> void:
	# The two tables the other views carry, for the Runtime Export view. The
	# routing half checks that each of the three signals reaches the handler
	# main.gd names and that the view declares nothing the table misses; the
	# emission half drives a bare view's toolbar Buttons and checks that each
	# signal is reachable and arrives with its declared argument list.
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	var view: RuntimeExportView = application.runtime_export_view

	var routed: Array[String] = []
	for route in RUNTIME_EXPORT_SIGNAL_ROUTES:
		var signal_name := str(route[0])
		var expected_handler := str(route[1])
		routed.append(signal_name)
		var handlers: Array[String] = []
		for connection in view.get_signal_connection_list(signal_name):
			handlers.append(str((connection["callable"] as Callable).get_method()))
		_expect(handlers.size() == 1 and handlers[0] == expected_handler,
			"The Runtime Export view signal %s should reach %s, not %s." % [
				signal_name, expected_handler, str(handlers)])
	var declared_arguments: Dictionary = {}
	for entry in view.get_script().get_script_signal_list():
		var declared := str(entry["name"])
		declared_arguments[declared] = entry["args"]
		if declared in routed:
			continue
		_expect(false, "The Runtime Export view declares %s, which is missing from the routing table." % declared)

	# The Buttons stay in the shared toolbar, so the view is the only thing that
	# may turn a press into an intent. A bare view gets its own Buttons here, so
	# firing them cannot reach the editor's handlers and start a batch.
	view_signals_emitted = {}
	view_signal_argument_failures = [] as Array[String]
	var probe := RuntimeExportView.new()
	var probe_buttons: Array[Button] = [Button.new(), Button.new(), Button.new()]
	probe.set_toolbar_buttons(probe_buttons[0], probe_buttons[1], probe_buttons[2])
	for route in RUNTIME_EXPORT_SIGNAL_ROUTES:
		var signal_name := str(route[0])
		probe.connect(signal_name, _view_signal_recorder(signal_name, declared_arguments.get(signal_name, [])))
	probe.set_context({
		"summary": "Preflight abgeschlossen · 1 ausstehende Arbeitsschritte · 0 Auffälligkeiten",
		"consumer_sync": "",
		"stages": [{"title": "Mesh", "candidate_count": 1,
			"pending": PackedStringArray(["Wizard / body"]), "attention": PackedStringArray()}],
		"all_current": false,
		"toolbar": {
			"build_all": {"visible": true, "text": "Build All (1)", "disabled": false},
			"export_all_valid": {"visible": true, "text": "Export All Valid (1)", "disabled": false},
			"sync_consumers": {"visible": true, "text": "Sync Consumers", "disabled": false},
		},
	})
	probe.rebuild()
	_expect(probe_buttons[0].text == "Build All (1)" and not probe_buttons[0].disabled
		and probe_buttons[2].visible,
		"A bare view should apply the toolbar state it was given before the walk fires the Buttons.")
	var controls: Array = []
	_inspector_controls(probe, controls)
	for button in probe_buttons:
		controls.append(button)
	for control in controls:
		_exercise_control(control)
	var unreachable: Array[String] = []
	for route in RUNTIME_EXPORT_SIGNAL_ROUTES:
		if not view_signals_emitted.has(str(route[0])):
			unreachable.append(str(route[0]))
	_expect(unreachable.is_empty(),
		"Every Runtime Export view signal should be reachable from a control; unreachable: %s" % str(unreachable))
	_expect(view_signal_argument_failures.is_empty(),
		"Runtime Export view signals should arrive with their declared argument types; %s" % str(view_signal_argument_failures))
	for button in probe_buttons:
		button.free()
	probe.free()

	# The view renders from its context alone: it must not read the editor's
	# Preflight, and a context it was handed must survive a later mutation of the
	# Dictionary the caller kept.
	var pushed := {"summary": "first", "consumer_sync": "", "stages": [], "all_current": false,
		"toolbar": {}}
	application.runtime_export_view.set_context(pushed)
	pushed["summary"] = "second"
	application.runtime_export_view.rebuild()
	_expect(application.runtime_export_view.summary_label.text == "first",
		"The Runtime Export view should render the context it was given, not the caller's later edits.")
	application.free()


func _test_runtime_export_surface() -> void:
	# The Export module replaces the central work surface: it hides the Outliner,
	# the Inspector and the Context Bar, and it drives three toolbar Buttons from
	# a Preflight snapshot. tools/runtime_export_render_probe.gd photographs those
	# states; this test asserts that each state really reaches the path it stands
	# for, so a probe snapshot cannot quietly record two identical fixtures.
	#
	# Everything is synthetic. world_name stays empty, so every staleness check
	# resolves to an empty path and the file system is never touched, and no
	# Button is pressed, so no batch, Export, Save or Consumer Sync can start.
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	application.world_name = ""
	application.world_title = ""
	application.assets = [] as Array[Dictionary]
	application.active_module = "Export"
	application.runtime_export_view.visible = true
	application.outliner_panel.visible = false
	application.inspector_panel.visible = false
	application.context_bar_panel.visible = false
	application.canvas_view.visible = false

	var pending_preflight := {
		"mesh": _export_surface_stage([_export_surface_mesh_candidate("asset_1", "component_1"),
			_export_surface_mesh_candidate("asset_1", "component_2")],
			PackedStringArray(["Wizard / body", "Wizard / arm"]), PackedStringArray()),
		"runtime": _export_surface_stage([_export_surface_package("asset_1", true, ""),
			_export_surface_package("asset_2", true, ""),
			{"kind": "catalog", "asset_id": "", "build": {"valid": true, "errors": [], "catalog": {}}}],
			PackedStringArray(["Wizard — package missing or stale"]), PackedStringArray()),
	}
	var blocked_preflight := {
		"mesh": _export_surface_stage([], PackedStringArray(),
			PackedStringArray(["Wizard / body — The Component needs one Chain."])),
		"runtime": _export_surface_stage([], PackedStringArray(),
			PackedStringArray(["Orb — Component name is not unique.",
				"World Catalog — Asset Key 'orb' is already used."])),
	}
	var mixed_preflight := {
		"mesh": _export_surface_stage([_export_surface_mesh_candidate("asset_1", "component_1")],
			PackedStringArray(["Wizard / body"]),
			PackedStringArray(["Wizard / arm — The Component needs one Chain."])),
		"runtime": _export_surface_stage([_export_surface_package("asset_1", true, ""),
			_export_surface_package("asset_2", false, "Component name is not unique.")],
			PackedStringArray(["Wizard — package missing or stale"]),
			PackedStringArray(["Orb — Component name is not unique."])),
	}
	var empty_preflight := {
		"mesh": _export_surface_stage([], PackedStringArray(), PackedStringArray()),
		"runtime": _export_surface_stage([], PackedStringArray(), PackedStringArray()),
	}
	var busy_candidates: Array = [_export_surface_mesh_candidate("asset_1", "component_1"),
		_export_surface_mesh_candidate("asset_1", "component_2")]
	var busy_attention := PackedStringArray(["Wizard / arm — The Component needs one Chain."])
	var observations: Dictionary = {}

	# 1 · A Preflight older than the last document change. The snapshot still
	# holds candidates, but the toolbar must refuse to act on a stale one.
	application.export_running = false
	application.mesh_batch_running = false
	_export_surface_apply(application, pending_preflight, false, [], PackedStringArray())
	_expect((application.export_preflight.get("mesh", {}).get("candidates", []) as Array).size() == 2
		and application._export_build_count() == 2,
		"The stale case should start from a Preflight that does hold candidates.")
	_expect(application.export_run_button.text == "Build All (0)"
		and application.export_run_button.disabled
		and application.export_valid_button.text == "Export All Valid (0)"
		and application.export_valid_button.disabled,
		"A Preflight that is stale against the last change must not offer its candidates.")
	observations["preflight_stale"] = _export_surface_observation(application)

	# 2 · Everything current: no work, no attention, both actions disabled.
	_export_surface_apply(application, empty_preflight, true, [], PackedStringArray())
	_expect(str(application.runtime_export_view.summary_label.text).contains("0 ausstehende Arbeitsschritte")
		and str(application.runtime_export_view.summary_label.text).contains("0 Auffälligkeiten"),
		"A fully current Preflight should summarise no work and no attention.")
	_expect(str(application.runtime_export_view.log_label.get_parsed_text()).contains("Alles ist aktuell und exportbereit."),
		"A fully current Preflight should say so in the log.")
	_expect(application.export_run_button.disabled and application.export_valid_button.disabled
		and application.export_sync_button.disabled,
		"A fully current state must leave every Export action disabled.")
	observations["all_current"] = _export_surface_observation(application)

	# 3 · Valid pending Mesh and Runtime work enables the matching Buttons.
	_export_surface_apply(application, pending_preflight, true, busy_candidates, busy_attention)
	_expect(application.export_run_button.text == "Build All (2)"
		and not application.export_run_button.disabled,
		"Pending Mesh work should enable Build All with its Component count.")
	_expect(application.export_valid_button.text == "Export All Valid (3)"
		and not application.export_valid_button.disabled,
		"Pending valid Runtime work should enable Export All Valid with its candidate count.")
	_expect(application.export_sync_button.disabled,
		"Without a published Catalog the Consumer Sync must stay disabled.")
	_expect(str(application.runtime_export_view.log_label.get_parsed_text()).contains("Wizard — package missing or stale"),
		"The Preflight log should list the pending Runtime entries.")
	_expect(str(application.runtime_export_view.log_label.get_parsed_text()).contains("Mesh · 2 ausstehend · 0 Auffälligkeiten")
		and str(application.runtime_export_view.log_label.get_parsed_text()).contains("Runtime Export · 3 ausstehend · 0 Auffälligkeiten"),
		"Each Preflight stage heading should count its own candidates, not its summary lines.")
	_expect((application.update_meshes_button as BatchStatusButton).attention_count == 1,
		"The persistent Update Meshes Button should carry the attention count of its own snapshot.")
	observations["pending_work"] = _export_surface_observation(application)

	# 4 · Blocked candidates: attention is counted and shown, nothing is offered.
	_export_surface_apply(application, blocked_preflight, true, [], PackedStringArray())
	_expect(application._export_attention_count(blocked_preflight["mesh"]) == 1
		and application._export_attention_count(blocked_preflight["runtime"]) == 2,
		"Attention entries should be counted per stage.")
	_expect(str(application.runtime_export_view.summary_label.text).contains("3 Auffälligkeiten"),
		"The summary should report the combined attention count.")
	_expect(str(application.runtime_export_view.log_label.get_parsed_text()).contains("Orb — Component name is not unique."),
		"The Preflight log should name every blocked entry.")
	_expect(str(application.runtime_export_view.log_label.get_parsed_text()).contains("Mesh · 0 ausstehend · 1 Auffälligkeiten")
		and str(application.runtime_export_view.log_label.get_parsed_text()).contains("Runtime Export · 0 ausstehend · 2 Auffälligkeiten"),
		"Each Preflight stage heading should count its own attention entries.")
	_expect(application.export_run_button.disabled and application.export_valid_button.disabled,
		"Blocked entries alone must not enable an Export action.")
	observations["blocked_only"] = _export_surface_observation(application)

	# 5 · Executable work beside blocked entries: both are visible at once.
	_export_surface_apply(application, mixed_preflight, true, busy_candidates, busy_attention)
	_expect(str(application.runtime_export_view.summary_label.text).contains("3 ausstehende Arbeitsschritte")
		and str(application.runtime_export_view.summary_label.text).contains("2 Auffälligkeiten"),
		"A mixed state should report pending work and attention side by side.")
	_expect(not application.export_run_button.disabled
		and application.export_valid_button.text == "Export All Valid (1)",
		"A mixed state should still offer the work that is executable.")
	observations["mixed"] = _export_surface_observation(application)

	# 6 · A running Export disables every action although candidates exist.
	application.export_running = true
	_export_surface_apply(application, mixed_preflight, true, busy_candidates, busy_attention)
	_expect(application._export_build_count() > 0 and application._export_valid_count() > 0,
		"The running case should start from a state that would otherwise be actionable.")
	_expect(application.export_run_button.disabled and application.export_valid_button.disabled
		and application.export_sync_button.disabled,
		"While an Export runs no Export action may be offered.")
	observations["export_running"] = _export_surface_observation(application)

	# 7 · A running Mesh batch freezes the persistent Update Meshes Button: its
	# snapshot is empty again, but caption and attention point stay as they were.
	application.export_running = false
	application.mesh_batch_running = true
	_export_surface_apply(application, pending_preflight, true, [], PackedStringArray())
	_expect(application.update_meshes_button.text == "Update Meshes (2)"
		and (application.update_meshes_button as BatchStatusButton).attention_count == 1,
		"A running Mesh batch should leave the Update Meshes Button at its previous caption.")
	_expect((application.batch_status_snapshot.get("mesh", {}).get("candidates", []) as Array).is_empty(),
		"The frozen case should be driven by a snapshot that has since become empty.")
	observations["mesh_batch_running"] = _export_surface_observation(application)

	# 8 · A completed Consumer Sync reports itself in its own line.
	application.mesh_batch_running = false
	_export_surface_apply(application, empty_preflight, true, [], PackedStringArray())
	application._present_consumer_sync_result({"success": true, "output": "", "exit_code": 0})
	_expect(str(application.runtime_export_view.consumer_sync_label.text).contains("erfolgreich"),
		"A successful Consumer Sync should be reported beside the summary.")
	observations["consumer_sync_done"] = _export_surface_observation(application)

	# 9 · Leaving the module has to give the ordinary work surfaces back.
	application.active_module = "Create"
	application.active_create_submodule = "Character"
	application._render_canvas_context()
	application._render_context_bar()
	_expect(not application.runtime_export_view.visible,
		"Leaving Export should hide the Export workspace.")
	_expect(application.outliner_panel.visible and application.inspector_panel.visible
		and application.context_bar_panel.visible and application.canvas_view.visible,
		"Leaving Export should show the Outliner, the Inspector, the Context Bar and the Canvas again.")
	_expect(not application.export_run_button.visible and not application.export_valid_button.visible
		and not application.export_sync_button.visible,
		"Leaving Export should hide the Export toolbar Buttons.")
	observations["left_for_create"] = _export_surface_observation(application)

	# 10 · Motion leaves the canvas render before the branch that shows the
	# Outliner and the Inspector unconditionally, so only there is the
	# Export-specific restore the sole reason they come back.
	application.active_module = "Export"
	application._render_canvas_context()
	_expect(not application.outliner_panel.visible and not application.inspector_panel.visible
		and not application.context_bar_panel.visible,
		"Entering Export should hide the Outliner, the Inspector and the Context Bar.")
	application.active_module = "Motion"
	application.active_motion_submodule = "Path"
	application._render_canvas_context()
	application._render_context_bar()
	_expect(not application.runtime_export_view.visible,
		"Leaving Export for Motion should hide the Export workspace.")
	_expect(application.outliner_panel.visible and application.inspector_panel.visible
		and application.context_bar_panel.visible,
		"Leaving Export for Motion should restore the Outliner, the Inspector and the Context Bar.")
	observations["left_for_motion"] = _export_surface_observation(application)

	# No two states may render the same; otherwise the probe photographs one
	# state twice and a missing path stays invisible.
	var seen: Dictionary = {}
	for name in observations:
		var observation := str(observations[name])
		_expect(not seen.has(observation),
			"The Export surface states should all differ; %s renders like %s." % [
				name, str(seen.get(observation, ""))])
		seen[observation] = name
	_expect(seen.size() == 10, "The Export surface test should cover ten distinct states.")
	application.free()


func _test_runtime_export_file_service() -> void:
	# RuntimeExportFileService owns only the file mechanics behind Runtime
	# Export: where the Catalog and the packages live, whether what is on disk
	# still matches what was built, how a package is replaced without losing the
	# previous one, and what may be removed again. It is driven here through its
	# public API against one temporary root under user://, never against worlds/.

	# The thin wrappers in main.gd must keep the existing path semantics.
	var application = load("res://scripts/main.gd").new()
	application.world_name = "world01"
	_expect(application._runtime_export_root() == ProjectSettings.globalize_path("res://worlds/world01/PolyToolsRuntimeExports"),
		"The Runtime export root wrapper should still resolve the World-local PolyToolsRuntimeExports directory.")
	_expect(application._asset_catalog_path() == "res://worlds/world01/catalog.json",
		"The Asset Catalog wrapper should still resolve the World-root catalog.json resource path.")
	application.world_name = ""
	_expect(application._runtime_export_root().is_empty() and application._asset_catalog_path().is_empty(),
		"Without an active World neither the export root nor the Catalog path should resolve.")
	application.free()

	var world_root := "user://polytools_runtime_export_file_test"
	var absolute_world_root := ProjectSettings.globalize_path(world_root)
	_remove_runtime_export_file_test_tree(absolute_world_root)
	DirAccess.make_dir_recursive_absolute(absolute_world_root)
	var export_root := RuntimeExportFileService.export_root(world_root)
	_expect(export_root == absolute_world_root.path_join("PolyToolsRuntimeExports"),
		"The export root should be the absolute PolyToolsRuntimeExports directory below the given World root.")
	_expect(RuntimeExportFileService.export_root("").is_empty() and RuntimeExportFileService.catalog_path("").is_empty(),
		"Without a World root the service should resolve no paths at all.")

	# Catalog: missing, written, unchanged, changed.
	var catalog := {"schema_version": 1, "world_key": "test_world", "world_name": "Test World", "assets": []}
	_expect(RuntimeExportFileService.catalog_is_stale(world_root, catalog),
		"A Catalog that has never been written should be stale.")
	_expect(RuntimeExportFileService.write_catalog(world_root, catalog),
		"Writing the Catalog to a writable World root should report success.")
	_expect(not RuntimeExportFileService.catalog_is_stale(world_root, catalog),
		"A Catalog whose bytes match the build should be current.")
	var changed_catalog: Dictionary = catalog.duplicate(true)
	changed_catalog["assets"] = [{"asset_key": "wizard", "display_name": "Wizard",
		"asset_type": "character", "runtime_package": "PolyToolsRuntimeExports/wizard/manifest.json"}]
	_expect(RuntimeExportFileService.catalog_is_stale(world_root, changed_catalog),
		"A Catalog build that differs from the file on disk should be stale.")
	_expect(not FileAccess.file_exists(absolute_world_root.path_join(".catalog.json.staging"))
		and not FileAccess.file_exists(absolute_world_root.path_join(".catalog.json.backup")),
		"A completed Catalog write should leave no staging or backup residue.")

	# Package: missing, written, unchanged, changed, invalid on disk.
	var manifest := _runtime_export_file_test_manifest("Wizard")
	_expect(RuntimeExportFileService.package_is_stale(export_root, "wizard", manifest),
		"A package that has never been written should be stale.")
	_expect(RuntimeExportFileService.write_package(export_root, "wizard", manifest),
		"Writing a valid package should report success.")
	var package_path := export_root.path_join("wizard")
	_expect(FileAccess.file_exists(package_path.path_join("manifest.json")),
		"A written package should contain its manifest.json.")
	_expect(not DirAccess.dir_exists_absolute(export_root.path_join(".wizard.staging"))
		and not DirAccess.dir_exists_absolute(export_root.path_join(".wizard.backup")),
		"A completed package write should leave no staging or backup directory behind.")
	_expect(not RuntimeExportFileService.package_is_stale(export_root, "wizard", manifest),
		"A package whose manifest bytes match the build should be current.")
	var other_manifest := _runtime_export_file_test_manifest("Orb")
	_expect(RuntimeExportFileService.package_is_stale(export_root, "wizard", other_manifest),
		"A package whose manifest differs from the build should be stale.")

	# Byte-identical is not enough: what is on disk must still be a Manifest the
	# contract accepts, so an obsolete schema stays stale even when it matches.
	var obsolete := {"schema_version": 7, "values": [0, 1.0, 0.25]}
	var obsolete_file := FileAccess.open(package_path.path_join("manifest.json"), FileAccess.WRITE)
	_expect(obsolete_file != null, "Preparing the obsolete-schema case should be able to write the manifest.")
	if obsolete_file != null:
		obsolete_file.store_string(JSON.stringify(obsolete, "\t"))
		obsolete_file.close()
	_expect(RuntimeExportFileService.package_is_stale(export_root, "wizard", obsolete),
		"A package holding an obsolete Manifest schema should be stale even though its bytes match the build.")

	# Replacing a package delivers the new state completely, without merging.
	_expect(RuntimeExportFileService.write_package(export_root, "wizard", manifest),
		"Restoring the package before the replacement case should succeed.")
	var stale_file := FileAccess.open(package_path.path_join("leftover.json"), FileAccess.WRITE)
	if stale_file != null:
		stale_file.store_string("{}")
		stale_file.close()
	_expect(RuntimeExportFileService.write_package(export_root, "wizard", other_manifest),
		"Replacing an existing package should report success.")
	_expect(not RuntimeExportFileService.package_is_stale(export_root, "wizard", other_manifest)
		and RuntimeExportFileService.package_is_stale(export_root, "wizard", manifest),
		"A replaced package should hold exactly the new Manifest.")
	_expect(not FileAccess.file_exists(package_path.path_join("leftover.json")),
		"Replacing a package should not keep a file from the previous package.")

	# A package that cannot be validated after staging must leave the previous
	# one complete rather than half-replaced.
	_expect(not RuntimeExportFileService.write_package(export_root, "wizard", obsolete),
		"A package whose staged Manifest fails validation must report failure.")
	_expect(not RuntimeExportFileService.package_is_stale(export_root, "wizard", other_manifest),
		"A failed package write must leave the previously written package intact.")
	_expect(not DirAccess.dir_exists_absolute(export_root.path_join(".wizard.staging"))
		and not DirAccess.dir_exists_absolute(export_root.path_join(".wizard.backup")),
		"A failed package write must not leave staging or backup residue behind.")
	_expect(not RuntimeExportFileService.write_package(export_root, "", manifest)
		and not RuntimeExportFileService.write_package("", "wizard", manifest),
		"Without an export root or an Asset Key no package may be written.")
	_expect(not RuntimeExportFileService.write_package(export_root, "../escaped", manifest)
		and not RuntimeExportFileService.write_package(export_root, "nested/package", manifest)
		and RuntimeExportFileService.package_path(export_root, "../escaped").is_empty(),
		"An Asset Key must never be interpreted as a relative package path.")
	_expect(not DirAccess.dir_exists_absolute(absolute_world_root.path_join("escaped")),
		"An invalid Asset Key must not create a package outside the export root.")

	# Pruning removes only package directories the caller did not allow.
	_expect(RuntimeExportFileService.write_package(export_root, "orb", other_manifest),
		"Preparing the pruning case should write a second package.")
	_expect(RuntimeExportFileService.write_package(export_root, "ghost", manifest),
		"Preparing the pruning case should write a package that is no longer allowed.")
	var hidden_directory := export_root.path_join(".wizard.staging")
	DirAccess.make_dir_recursive_absolute(hidden_directory)
	var outside_directory := absolute_world_root.path_join("outside_package")
	DirAccess.make_dir_recursive_absolute(outside_directory)
	var sibling_directory := export_root + "_sibling"
	DirAccess.make_dir_recursive_absolute(sibling_directory)
	_expect(RuntimeExportFileService.prune_packages(export_root, {"wizard": true, "orb": true}) == 1,
		"Pruning should remove exactly the one package directory that is not allowed.")
	_expect(DirAccess.dir_exists_absolute(export_root.path_join("wizard"))
		and DirAccess.dir_exists_absolute(export_root.path_join("orb")),
		"Pruning must keep every allowed package, including one whose Asset is currently invalid.")
	_expect(not DirAccess.dir_exists_absolute(export_root.path_join("ghost")),
		"Pruning should remove a package directory that the caller did not allow.")
	_expect(DirAccess.dir_exists_absolute(hidden_directory),
		"Pruning must not treat a staging or backup directory as an ordinary package.")
	_expect(DirAccess.dir_exists_absolute(outside_directory) and DirAccess.dir_exists_absolute(sibling_directory),
		"Pruning must not reach outside the export root.")
	_expect(RuntimeExportFileService.prune_packages(export_root.path_join("missing"), {}) == 0,
		"Pruning a directory that does not exist should do nothing.")

	# The removal bound, stated as its own assertions.
	RuntimeExportFileService.remove_tree(export_root, export_root)
	_expect(DirAccess.dir_exists_absolute(export_root)
		and DirAccess.dir_exists_absolute(export_root.path_join("wizard"))
		and DirAccess.dir_exists_absolute(export_root.path_join("orb")),
		"The export root itself must never be removed, and its packages must survive with it.")
	RuntimeExportFileService.remove_tree(export_root, outside_directory)
	_expect(DirAccess.dir_exists_absolute(outside_directory),
		"A path outside the export root must never be removed.")
	RuntimeExportFileService.remove_tree(export_root, export_root.path_join("../outside_package"))
	_expect(DirAccess.dir_exists_absolute(outside_directory),
		"A path that escapes through parent traversal must never be removed.")
	RuntimeExportFileService.remove_tree(export_root, sibling_directory)
	_expect(DirAccess.dir_exists_absolute(sibling_directory),
		"A sibling directory that merely shares the export root's prefix must never be removed.")
	RuntimeExportFileService.remove_tree("", export_root.path_join("orb"))
	_expect(DirAccess.dir_exists_absolute(export_root.path_join("orb")),
		"Without an export root nothing may be removed.")
	RuntimeExportFileService.remove_tree(export_root, export_root.path_join("orb"))
	_expect(not DirAccess.dir_exists_absolute(export_root.path_join("orb")),
		"A package directory below the export root should be removable.")

	_remove_runtime_export_file_test_tree(absolute_world_root)
	_expect(not DirAccess.dir_exists_absolute(absolute_world_root),
		"The Runtime export file test should leave no temporary directory behind.")


func _test_runtime_export_service() -> void:
	var application = load("res://scripts/main.gd").new()
	application.world_name = "world01"
	application.world_title = "Secrets, Room's & Travels'"
	_expect(application._runtime_export_root() == ProjectSettings.globalize_path("res://worlds/world01/PolyToolsRuntimeExports"), "Runtime packages should be written to the ignored PolyToolsRuntimeExports directory owned by the active World.")
	var numeric_manifest := {"schema_version": 7, "values": [0, 1.0, 0.25]}
	var numeric_manifest_text := JSON.stringify(numeric_manifest, "\t")
	_expect(not application._runtime_manifest_text_matches(numeric_manifest_text, numeric_manifest_text), "Runtime staging must reject a byte-stable Manifest from an obsolete schema.")
	_expect(not application._runtime_manifest_text_matches(numeric_manifest_text, numeric_manifest_text + " "), "Runtime staging should reject Manifest bytes that differ from the expected package.")
	var mesh := {
		"valid": true,
		"vertices": [
			{"id": "v0", "position": Vector2(0.0, 0.0)},
			{"id": "v1", "position": Vector2(10.0, 0.0)},
			{"id": "v2", "position": Vector2(0.0, 10.0)}
		],
		"triangles": [{"vertex_ids": ["v0", "v1", "v2"]}]
	}
	var contour_stroke: Dictionary = mesh.duplicate(true)
	contour_stroke.merge({"method": ContourMeshService.METHOD, "has_outline": true, "topology_role": "outer", "runs": [{"run_id": "boundary:run:0", "edge_ids": ["edge_0"], "closed": true, "start_cap": "none", "end_cap": "none", "vertex_offset": 0, "vertex_count": 3, "index_offset": 0, "index_count": 3}], "parameters": {"reference_pixels_per_meter": 192.0, "stroke_width_px": 4.0, "stroke_width_meters": 0.020833333333333332, "join": "miter", "miter_limit": 4.0, "cap": "butt"}}, true)
	var body := {"id": "component_b", "name": "body", "visibility": true, "z_index": 2, "parent_component_id": "", "transform": {"position": Vector2(10.0, 20.0), "pivot": Vector2(2.0, 3.0), "rotation": 90.0, "scale": Vector2.ONE}, "points": [{"id": "point_corner", "position": Vector2(4.0, 5.0), "mode": "corner"}, {"id": "point_aligned", "position": Vector2(6.0, 7.0), "mode": "aligned"}]}
	var eye := {"id": "component_a", "name": "eye_left", "visibility": true, "z_index": 2, "parent_component_id": "component_b", "transform": {"position": Vector2.ZERO, "pivot": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE}}
	var asset := {"id": "wizard", "name": "Wizard", "asset_type": "character", "authored_facing": AssetPresentation.AuthoredFacing.RIGHT, "visibility": true, "asset_pivot": Vector2(5.0, 6.0), "components": [body, eye]}
	var source := {"mesh": mesh, "contour_stroke": contour_stroke}
	var result := RuntimeExportService.build_manifest(asset, {"component_a": source, "component_b": source})
	var manifest: Dictionary = result.get("manifest", {})
	var components: Array = manifest.get("components", [])
	_expect(bool(result.get("valid", false)) and int(manifest.get("schema_version", 0)) == 16 and str(manifest.get("asset_key", "")) == "wizard" and not manifest.has("asset_id"), "Runtime export schema 16 should identify packages only by the Asset Key derived from their display name.")
	var item_asset: Dictionary = asset.duplicate(true)
	item_asset["asset_type"] = "items"
	var item_manifest: Dictionary = RuntimeExportService.build_manifest(item_asset, {"component_a": source, "component_b": source}).get("manifest", {})
	_expect(str(item_manifest.get("asset_type", "")) == "items", "Runtime export should retain the stable Items Asset type.")
	_expect(str(manifest.get("presentation", {}).get("authored_facing", "")) == "right", "Runtime export schema 16 should publish the selected authored facing under presentation.authored_facing.")
	var neutral_asset: Dictionary = asset.duplicate(true)
	neutral_asset.erase("authored_facing")
	var neutral_manifest: Dictionary = RuntimeExportService.build_manifest(neutral_asset, {"component_a": source, "component_b": source}).get("manifest", {})
	_expect(str(neutral_manifest.get("presentation", {}).get("authored_facing", "")) == "neutral", "Runtime export schema 16 should explicitly publish neutral for an older Asset without authored_facing.")
	var manifest_text := JSON.stringify(manifest, "\t")
	_expect(application._runtime_manifest_text_matches(manifest_text, manifest_text), "Runtime staging should verify exact schema-16 JSON bytes without rejecting numeric JSON round-trip types.")
	_expect(components.size() == 2 and str(components[0].get("component_id", "")) == "component_a" and str(components[1].get("component_id", "")) == "component_b", "Runtime Components should sort globally by ascending z_index and lexicographic Component ID.")
	var constraint_hole := {"id": "component_hole", "name": "body_hole", "type": "component", "draw_mode": "primitive", "topology_role": "hole", "visibility": true, "parent_component_id": "component_b", "transform": WorldDocumentService.default_component_transform(), "primitive": {"type": "circle", "center": Vector2.ZERO, "diameter_cm": 10.0}, "points": [], "edges": [], "chains": []}
	var asset_with_constraint_hole: Dictionary = asset.duplicate(true)
	asset_with_constraint_hole["components"].append(constraint_hole)
	var constraint_hole_result := RuntimeExportService.build_manifest(asset_with_constraint_hole, {"component_a": source, "component_b": source})
	var constraint_hole_components: Array = constraint_hole_result.get("manifest", {}).get("components", [])
	_expect(bool(constraint_hole_result.get("valid", false)) and constraint_hole_components.size() == 2 and not constraint_hole_components.any(func(entry: Dictionary) -> bool: return str(entry.get("component_id", "")) == "component_hole"), "An ordinary Hole should remain an authoring constraint and export neither Fill nor Contour Stroke geometry.")
	var orphan_hole_asset: Dictionary = asset_with_constraint_hole.duplicate(true)
	orphan_hole_asset["components"][2]["parent_component_id"] = ""
	var orphan_hole_result := RuntimeExportService.build_manifest(orphan_hole_asset, {"component_a": source, "component_b": source})
	_expect(not bool(orphan_hole_result.get("valid", true)) and str(orphan_hole_result.get("errors", [])).contains("requires a direct outer Parent Body"), "A visible ordinary Hole without a direct Parent Body must block Runtime export with its own validation issue instead of disappearing silently.")
	var child_of_hole: Dictionary = eye.duplicate(true)
	child_of_hole.merge({"id": "component_hole_child", "name": "hole_child", "parent_component_id": "component_hole"}, true)
	var nested_hole_asset: Dictionary = asset_with_constraint_hole.duplicate(true)
	nested_hole_asset["components"].append(child_of_hole)
	var nested_hole_result := RuntimeExportService.build_manifest(nested_hole_asset, {"component_a": source, "component_b": source, "component_hole_child": source})
	_expect(not bool(nested_hole_result.get("valid", true)) and str(nested_hole_result.get("errors", [])).contains("constraint-only Hole") and str(nested_hole_result.get("errors", [])).contains("body_hole"), "A Runtime Component below an ordinary Hole must fail with a tailored hierarchy error that names the Hole.")
	var socket := AssetGuide.create_weapon_frame("guide_socket", AssetGuide.WEAPON_SOCKET_PRIMARY, "component", "component_b")
	socket["transform"]["position"] = Vector2(3.0, 4.0)
	var reach_limit := AssetGuide.create_weapon_frame("guide_reach_limit", AssetGuide.REACH_LIMIT_PRIMARY, "component", "component_b")
	reach_limit["transform"]["position"] = Vector2(0.0, -2.0)
	var secondary_grip := AssetGuide.create_weapon_frame("guide_secondary_grip", AssetGuide.GRIP_SECONDARY, "component", "component_b")
	secondary_grip["transform"]["position"] = Vector2(0.0, 1.0)
	var combat_asset: Dictionary = asset.duplicate(true)
	combat_asset["guides"] = [socket, secondary_grip, reach_limit]
	var combat_result := RuntimeExportService.build_manifest(combat_asset, {"component_a": source, "component_b": source})
	var combat_manifest: Dictionary = combat_result.get("manifest", {})
	var exported_frame_roles: Array = combat_manifest.get("attachment_frames", []).map(func(frame: Dictionary): return str(frame.get("role", "")))
	_expect(bool(combat_result.get("valid", false)) and int(combat_manifest.get("schema_version", 0)) == 16 and combat_manifest.get("attachment_frames", []).size() == 3 and AssetGuide.WEAPON_SOCKET_PRIMARY in exported_frame_roles and AssetGuide.GRIP_SECONDARY in exported_frame_roles and AssetGuide.REACH_LIMIT_PRIMARY in exported_frame_roles and combat_manifest.has("regions") and combat_manifest.get("regions", []).is_empty(), "Schema 16 should export every oriented Weapon Guide and an optional empty Regions array.")
	var authored_region := {"id": "region_attack", "type": "region", "region_type": "attack", "name": "attack_region", "visibility": true, "parent_component_id": "component_b", "group_id": "", "transform": {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}, "points": [], "edges": [], "chains": [], "draw_mode": "closed_loop"}
	for region_position in [Vector2.ZERO, Vector2(2.0, 0.0), Vector2(1.0, 2.0)]:
		BezierTopology.add_point(authored_region, region_position, "linear")
	BezierTopology.close_active_chain(authored_region)
	var region_asset: Dictionary = combat_asset.duplicate(true)
	region_asset["components"].append(authored_region)
	var region_result := RuntimeExportService.build_manifest(region_asset, {"component_a": source, "component_b": source})
	var exported_authored_region: Dictionary = region_result.get("manifest", {}).get("regions", [])[0] if bool(region_result.get("valid", false)) else {}
	_expect(bool(region_result.get("valid", false)) and region_result.get("manifest", {}).get("regions", []).size() == 1 and exported_authored_region.get("role", "") == "attack" and exported_authored_region.get("geometry_source", "") == "authored" and exported_authored_region.get("source_component_id", "") == "component_b", "Authored Attack Regions should export their retained topology separately from ordinary Components.")
	var inherited_region: Dictionary = authored_region.duplicate(true)
	inherited_region["id"] = "region_hurt"
	inherited_region["name"] = "hurt_region"
	inherited_region["region_type"] = "hurt"
	inherited_region["region_geometry_source"] = WorldDocumentService.REGION_GEOMETRY_COMPONENT
	var inherited_asset: Dictionary = combat_asset.duplicate(true)
	inherited_asset["components"].append(inherited_region)
	var inherited_result := RuntimeExportService.build_manifest(inherited_asset, {"component_a": source, "component_b": source})
	var exported_inherited_region: Dictionary = inherited_result.get("manifest", {}).get("regions", [])[0] if bool(inherited_result.get("valid", false)) else {}
	_expect(bool(inherited_result.get("valid", false)) and exported_inherited_region.get("geometry_source", "") == "component" and exported_inherited_region.get("source_component_id", "") == "component_b" and not exported_inherited_region.has("vertices") and not exported_inherited_region.has("indices"), "Component Geometry Regions should export a live Component binding without duplicating geometry.")
	_expect(components[1].get("mesh", {}).get("vertices", []) == [[-0.2, -0.30000000000000004], [0.8, -0.30000000000000004], [-0.2, 0.7000000000000001]] and components[1].get("mesh", {}).get("indices", []) == [0, 1, 2] and not components[1].has("closed_region_mesh"), "Runtime Meshes should preserve accepted Vertex order, convert Tool units to meters, compact Triangle IDs, and remain unchanged for non-Contour Components.")
	_expect(not components[1].get("mesh", {}).has("uvs") and not components[1].has("contour_carrier") and not components[1].has("contour_mask"), "Schema 5 must remove UV, Carrier, and SDF fields rather than retaining a silent compatibility payload.")
	var exported_stroke: Dictionary = components[1].get("contour_stroke_mesh", {})
	_expect(str(exported_stroke.get("role", "")) == "centered_boundary_stroke" and bool(exported_stroke.get("has_outline", false)) and is_equal_approx(float(exported_stroke.get("stroke_width_px", 0.0)), 4.0) and is_equal_approx(float(exported_stroke.get("inner_offset_meters", 0.0)), 0.010416666666666666) and is_equal_approx(float(exported_stroke.get("outer_offset_meters", 0.0)), 0.010416666666666666), "Schema 6 should export the original Boundary as the centered metric Stroke with symmetric inner and outer offsets.")
	var disabled_stroke: Dictionary = contour_stroke.duplicate(true)
	disabled_stroke["has_outline"] = false
	disabled_stroke["vertices"] = []
	disabled_stroke["triangles"] = []
	disabled_stroke["runs"] = []
	var disabled_result := RuntimeExportService.build_manifest(asset, {"component_a": {"mesh": mesh, "contour_stroke": disabled_stroke}, "component_b": source})
	_expect(bool(disabled_result.get("valid", false)) and not bool(disabled_result.get("manifest", {}).get("components", [])[0].get("contour_stroke_mesh", {}).get("has_outline", true)), "Schema 5 must preserve Render Outline off as an explicit empty Stroke without generating fallback art.")
	_expect(components[1].get("local_transform", {}).get("position", []) == [1.0, 2.0] and is_equal_approx(float(components[1].get("local_transform", {}).get("rotation_radians", 0.0)), PI / 2.0), "Runtime transforms should preserve Y-up coordinates and publish positions in meters and CCW radians.")
	_expect(not components[1].has("display_name") and str(components[1].get("name", "")) == "body" and not components[1].has("semantic_key"), "Runtime Components should expose their free Component name without a redundant display label or Semantic Key.")
	var exported_corners: Array = components[1].get("projection_depth_corners", [])
	_expect(exported_corners == [{"point_id": "point_corner", "position": [0.2, 0.2]}] and components[0].get("projection_depth_corners", []) == [], "Only authored Corner points must export as local-meter projection-depth corners.")
	var missing_corners_manifest: Dictionary = manifest.duplicate(true)
	missing_corners_manifest["components"][1].erase("projection_depth_corners")
	_expect(not RuntimeExportService.manifest_validation_issues(missing_corners_manifest).is_empty(), "Runtime validation must reject an ordinary Component without projection_depth_corners.")
	var duplicate_corners_manifest: Dictionary = manifest.duplicate(true)
	duplicate_corners_manifest["components"][1]["projection_depth_corners"].append({"point_id": "point_corner", "position": [0.0, 0.0]})
	_expect(not RuntimeExportService.manifest_validation_issues(duplicate_corners_manifest).is_empty(), "Runtime validation must reject duplicate projection-depth Corner Point IDs.")
	var scaled_export_asset: Dictionary = asset.duplicate(true)
	scaled_export_asset["components"][0]["transform"]["scale"] = Vector2(2.0, 1.0)
	var scaled_export_result := RuntimeExportService.build_manifest(scaled_export_asset, {"component_a": source, "component_b": source})
	_expect(not bool(scaled_export_result.get("valid", true)) and str(scaled_export_result.get("errors", [])).contains("Component Scale must be rebased to (1, 1) before Runtime Export."), "Runtime export must explicitly reject non-rebased authored Component Scale without a fallback.")
	var root_scaled_export_asset: Dictionary = asset.duplicate(true)
	root_scaled_export_asset["root_scale"] = 3.6
	var root_scaled_export_result := RuntimeExportService.build_manifest(root_scaled_export_asset, {"component_a": source, "component_b": source})
	_expect(not bool(root_scaled_export_result.get("valid", true)) and str(root_scaled_export_result.get("errors", [])).contains("Root Asset Scale must be rebased to 1 before Runtime Export."), "Runtime export must explicitly reject a non-rebased Root Asset Scale without silently changing package dimensions.")
	var root_positioned_export_asset: Dictionary = asset.duplicate(true)
	root_positioned_export_asset["root_position"] = Vector2(3.0, -2.0)
	var root_positioned_export_result := RuntimeExportService.build_manifest(root_positioned_export_asset, {"component_a": source, "component_b": source})
	_expect(not bool(root_positioned_export_result.get("valid", true)) and str(root_positioned_export_result.get("errors", [])).contains("Root Asset Position must be rebased to (0, 0) before Runtime Export."), "Runtime export must explicitly reject a non-rebased Root Asset Position without silently changing package placement.")
	var open_contour_component: Dictionary = body.duplicate(true)
	open_contour_component["draw_mode"] = "contour"
	var open_contour_asset := {"id": "contour_asset", "name": "Contour Asset", "asset_type": "character", "visibility": true, "asset_pivot": Vector2.ZERO, "components": [open_contour_component]}
	var contour_export := RuntimeExportService.build_manifest(open_contour_asset, {"component_b": {"contour_stroke": contour_stroke}})
	var exported_contour: Dictionary = contour_export.get("manifest", {}).get("components", [])[0]
	_expect(bool(contour_export.get("valid", false)) and exported_contour.has("contour_stroke_mesh") and not exported_contour.has("mesh") and not exported_contour.has("closed_region_mesh"), "Schema 8 must export an open Contour exclusively as its typed art Stroke without inventing Fill or closed-region geometry.")
	var wizard_head := {"id": "head", "name": "head", "visibility": true, "parent_component_id": "", "transform": {"position": Vector2(0.0, 8.5), "pivot": Vector2(0.0, 8.5), "rotation": 0.0, "scale": Vector2.ONE}}
	var wizard_eye := {"id": "eye", "name": "eye_left", "visibility": true, "parent_component_id": "head", "transform": {"position": Vector2(-0.3, 8.5), "pivot": Vector2(-0.3, 8.5), "rotation": 0.0, "scale": Vector2.ONE}}
	var head_mesh: Dictionary = mesh.duplicate(true)
	head_mesh["vertices"] = [{"id": "v0", "position": Vector2(0.0, 8.5)}, {"id": "v1", "position": Vector2(1.0, 8.5)}, {"id": "v2", "position": Vector2(0.0, 9.5)}]
	var eye_mesh: Dictionary = mesh.duplicate(true)
	eye_mesh["vertices"] = [{"id": "v0", "position": Vector2(-0.25, 8.5)}, {"id": "v1", "position": Vector2(-0.15, 8.5)}, {"id": "v2", "position": Vector2(-0.25, 8.6)}]
	var nested_asset := {"id": "nested_wizard", "name": "Nested Wizard", "asset_type": "character", "visibility": true, "asset_pivot": Vector2.ZERO, "components": [wizard_head, wizard_eye]}
	var head_stroke: Dictionary = contour_stroke.duplicate(true)
	head_stroke["vertices"] = head_mesh["vertices"].duplicate(true)
	var eye_stroke: Dictionary = contour_stroke.duplicate(true)
	eye_stroke["vertices"] = eye_mesh["vertices"].duplicate(true)
	var nested_result := RuntimeExportService.build_manifest(nested_asset, {"head": {"mesh": head_mesh, "contour_stroke": head_stroke}, "eye": {"mesh": eye_mesh, "contour_stroke": eye_stroke}})
	var nested_by_id: Dictionary = {}
	for exported_component in nested_result.get("manifest", {}).get("components", []):
		nested_by_id[str(exported_component.get("component_id", ""))] = exported_component
	var exported_eye: Dictionary = nested_by_id.get("eye", {})
	var eye_vertex: Array = exported_eye.get("mesh", {}).get("vertices", [])[0]
	var reconstructed_eye := _runtime_export_world_transform(nested_by_id, "eye") * Vector2(float(eye_vertex[0]), float(eye_vertex[1]))
	var eye_local_position: Array = exported_eye.get("local_transform", {}).get("position", [])
	var exported_eye_pivot: Array = exported_eye.get("component_pivot", [])
	_expect(bool(nested_result.get("valid", false)) and exported_eye_pivot.size() == 2 and is_equal_approx(float(exported_eye_pivot[0]), -0.03) and is_equal_approx(float(exported_eye_pivot[1]), 0.85) and is_equal_approx(float(eye_local_position[0]), -0.03) and is_zero_approx(float(eye_local_position[1])) and reconstructed_eye.is_equal_approx(Vector2(-0.025, 0.85)), "Nested Wizard Head → Eye export should publish the global component pivot and reconstruct its intended asset-space world position exactly.")
	var reference := {"id": "component_orb", "type": "reference", "name": "orb_reference", "source_asset_id": "orb", "visibility": true, "z_index": 3, "parent_component_id": "component_b", "transform": {"position": Vector2(3.0, 4.0), "pivot": Vector2.ZERO, "rotation": 0.0, "scale": Vector2(-1.0, 1.0)}}
	reference["topology_role"] = "hole"
	reference["contour_stroke_width_px"] = 3.0
	var referenced_asset: Dictionary = asset.duplicate(true)
	referenced_asset["components"].append(reference)
	var reference_source := {"owner_asset_id": "wizard", "source_asset_exists": true, "source_asset_key": "orb"}
	var referenced_result := RuntimeExportService.build_manifest(referenced_asset, {"component_a": source, "component_b": source, "component_orb": reference_source})
	var referenced_components: Array = referenced_result.get("manifest", {}).get("components", [])
	var exported_reference: Dictionary = referenced_components[2] if referenced_components.size() == 3 else {}
	var exported_reference_scale: Array = exported_reference.get("local_transform", {}).get("scale", [])
	_expect(bool(referenced_result.get("valid", false)) and str(exported_reference.get("kind", "")) == "asset_reference" and str(exported_reference.get("source_asset_key", "")) == "orb" and is_equal_approx(float(exported_reference.get("contour_stroke_width_override_px", 0.0)), 3.0) and not exported_reference.has("source_asset_id") and str(exported_reference.get("name", "")) == "orb_reference" and not exported_reference.has("mesh") and not exported_reference.has("contour_stroke_mesh") and not exported_reference.has("closed_region_mesh") and exported_reference_scale.size() == 2 and float(exported_reference_scale[0]) * float(exported_reference_scale[1]) < 0.0, "A Hole Reference should keep the Barde-style Runtime instance while owning no Fill or Contour Stroke geometry.")
	reference_source["source_asset_exists"] = false
	_expect(not bool(RuntimeExportService.build_manifest(referenced_asset, {"component_a": source, "component_b": source, "component_orb": reference_source}).get("valid", true)), "Runtime export should reject a Reference whose actual source Asset cannot be resolved.")
	var duplicate_role_asset: Dictionary = asset.duplicate(true)
	duplicate_role_asset["components"][1]["name"] = "body"
	_expect(not bool(RuntimeExportService.build_manifest(duplicate_role_asset, {"component_a": source, "component_b": source}).get("valid", true)), "Runtime export should reject duplicate Component Names.")
	var missing_stroke: Dictionary = source.duplicate(true)
	missing_stroke["contour_stroke"] = {}
	_expect(not bool(RuntimeExportService.build_manifest(asset, {"component_a": missing_stroke, "component_b": source}).get("valid", true)), "Runtime export should reject a missing Contour Stroke Bake without fallback.")
	var invalid_name_asset: Dictionary = asset.duplicate(true)
	invalid_name_asset["components"][0]["name"] = "Body"
	_expect(not bool(RuntimeExportService.build_manifest(invalid_name_asset, {"component_a": source, "component_b": source}).get("valid", true)), "Runtime export should reject Component Names outside lower_snake_case.")
	application.free()


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
	var document: Dictionary = WorldDocumentService.default_geometry_document("asset_weighting", "component_weighting")
	document["sampling"]["recipe"] = {"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 2.0}}
	document["sampling"]["bakes"][GeometrySamplingService.ADAPTIVE] = sampling
	document["seeding"]["recipe"] = {"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 2.5, "seed": 5}}
	document["seeding"]["bakes"][GeometrySeedingService.POISSON_FILL] = seeding
	document["meshing"]["recipe"] = {"method": GeometryMeshingService.CONSTRAINED_MESH, "parameters": {"seeding_method": GeometrySeedingService.POISSON_FILL}}
	document["meshing"]["bakes"][GeometryMeshingService.CONSTRAINED_MESH] = mesh
	document["component_mesh"] = {"bake_id": "mesh_weighting", "method": GeometryMeshingService.CONSTRAINED_MESH, "mesh_fingerprint": GeometryUVMappingService.mesh_fingerprint(mesh)}
	document["weighting"]["styles"].append(gradient_style)
	var constraint_hole := {"id": "component_weighting_hole", "name": "opening", "type": "component", "draw_mode": "primitive", "topology_role": "hole", "visibility": true, "parent_component_id": "component_weighting", "transform": WorldDocumentService.default_component_transform(), "primitive": {"type": "circle", "center": Vector2.ZERO, "diameter_cm": 2.0}, "points": [], "edges": [], "chains": []}
	var weighting_assets: Array[Dictionary] = [{"id": "asset_weighting", "name": "Asset", "visibility": true, "components": [component], "groups": [], "guides": []}]
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
	# The Weighting dropdowns are built from item descriptors, so what each entry
	# writes back is only checked here.
	application._render_inspector()
	var weighting_method_option := _inspector_option(application, "Uniform")
	_expect(weighting_method_option != null and str(weighting_method_option.get_item_metadata(weighting_method_option.selected)) == WeightingService.AXIS_GRADIENT,
		"The Weighting Inspector should preselect the Style's own Method.")
	var weighting_direction_option := _inspector_option(application, "Bottom → Top")
	_expect(weighting_direction_option != null, "An Axis Gradient Style should expose its Direction.")
	_choose_option(weighting_direction_option, 3)
	_expect(str(gradient_style.get("parameters", {}).get("direction", "")) == WeightingService.RIGHT_TO_LEFT,
		"The Direction dropdown should write the Style parameters.")
	var weighting_curve_option := _inspector_option(application, "Linear")
	_expect(weighting_curve_option != null, "An Axis Gradient Style should expose its Curve.")
	_choose_option(weighting_curve_option, 2)
	_expect(str(gradient_style.get("parameters", {}).get("curve", "")) == WeightingService.EASE_OUT,
		"The Curve dropdown should write the Style parameters.")
	_choose_option(weighting_method_option, 0)
	_expect(str(gradient_style.get("method", "")) == WeightingService.UNIFORM,
		"The Method dropdown should write the Style.")
	gradient_style["method"] = WeightingService.AXIS_GRADIENT
	gradient_style["parameters"] = WeightingService.default_parameters(WeightingService.AXIS_GRADIENT)

	application._set_active_context_command("style.weighting.method")
	application._render_context_bar()
	var weighting_popup: PopupMenu = application.weighting_method_menu.get_popup()
	weighting_popup.emit_signal("id_pressed", 0)
	_expect(str(gradient_style.get("method", "")) == WeightingService.UNIFORM and application.active_context_command.is_empty(), "Selecting a Weighting Method from CMD+1 must apply the method and clear the transient Context command instead of leaving the menu stuck.")
	application._bake_weighting_preview()
	_expect(application._weighting_status("asset_weighting", "component_weighting", component, gradient_style) == "Baked" and not gradient_style.get("bake", {}).is_empty(), "Weighting Bake should persist one derived result on its Style.")
	# The Inspector's own Result block is not reachable by the render comparison,
	# which has no baked Component Mesh, so the status it prints is pinned here.
	application._render_inspector()
	var weighting_status_label := _inspector_label_starting_with(application, "Status: ")
	_expect(weighting_status_label != null and str(weighting_status_label.text) == "Status: Baked",
		"The Weighting Inspector should print the Style's own status.")
	var weighting_vertices_label := _inspector_label_starting_with(application, "Vertices: ")
	_expect(weighting_vertices_label != null and str(weighting_vertices_label.text) == "Vertices: %d" % int(mesh.get("vertex_count", 0)),
		"The Weighting Inspector should print the Vertex count of the baked result.")
	var round_trip: Dictionary = WorldDocumentService.normalize_geometry_document(WorldDocumentService.serialize_geometry_document(document), "asset_weighting", "component_weighting")
	_expect(round_trip.get("weighting", {}).get("styles", []).size() == 1 and int(round_trip.get("weighting", {}).get("styles", [])[0].get("bake", {}).get("weight_count", 0)) == int(mesh.get("vertex_count", 0)), "Weighting Styles and per-Vertex Bakes should survive Geometry persistence.")
	weighting_assets[0]["components"].append(constraint_hole)
	application.expanded_assets["asset_weighting"] = true
	application._render_outliner()
	_expect(_button_starting_with(application.outliner_view, "opening ·") == null, "Style Weighting must omit ordinary constraint-only Holes from its Component rows.")
	application._select_weighting_component("asset_weighting", "component_weighting_hole")
	_expect(application.selected_component_id == "component_weighting", "Style Weighting must refuse navigation to an ordinary Hole.")
	application.selected_component_id = "component_weighting_hole"
	application.selected_weighting_style_id = ""
	application._update_context_action_button()
	_expect(application.create_action_button.disabled and application._weighting_inspector_context().is_empty(), "An ordinary Hole selection must disable Style creation and expose no Weighting Inspector context.")
	application._create_weighting_style("asset_weighting", "component_weighting_hole")
	_expect(not application.geometry_documents.has("asset_weighting/component_weighting_hole"), "Creating a Weighting Style must not create a Geometry document for an ordinary Hole.")
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
	var group := {
		"id": "group_face",
		"name": "face_details",
		"transform": {"position": Vector2(10.0, 0.0), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2(10.0, 0.0)},
		"visibility": true
	}
	parent["group_id"] = "group_face"
	var flow_1 := AssetGuide.create("guide_1", "Legacy Flow", "body_flow", "component_parent", 1)
	var flow_2 := AssetGuide.create("guide_2", "Legacy Flow 2", "body_flow", "component_parent", 1)
	var sample_1 := AssetGuide.create("guide_3", "Legacy Sample", "sampler_spine", "component_parent", 1)
	var child_sample := AssetGuide.create("guide_4", "Child Sample", "sampler_spine", "component_child", 1)
	var asset := {"components": [parent, child], "groups": [group], "guides": [flow_1, flow_2, sample_1, child_sample]}
	ComponentHierarchy.normalize_asset(asset)
	_expect(ComponentHierarchy.membership_group_id(asset, "component_child") == "group_face", "Child Components should inherit their Parent Component's Group membership.")
	_expect(ComponentHierarchy.group_by_id(asset, "group_face").get("name", "") == "face_details", "Groups should be first-class Asset records with stable names.")
	group["z_index"] = 17
	parent["z_index"] = 4
	ComponentHierarchy.normalize_asset(asset)
	_expect(not ComponentHierarchy.group_by_id(asset, "group_face").has("z_index") and RuntimeExportService._effective_z_index(asset, parent) == 4, "Legacy Group Z Indices should be removed during normalization while grouped Components retain their own Z Index.")
	group["visibility"] = false
	_expect(not RuntimeExportService._effective_visibility(asset, parent), "Group visibility should hide every member from the effective export set.")
	group["visibility"] = true
	_expect(ComponentHierarchy.children(asset, "component_parent").size() == 1 and ComponentHierarchy.descendants(asset, "component_parent").size() == 1, "The internal Component model should expose explicit recursive Parent-Child relationships.")
	_expect(ComponentHierarchy.world_transform(asset, "component_child").origin.is_equal_approx(Vector2(12.0, 0.0)), "Child Component transforms should compose locally through their Parent.")
	group["transform"]["position"] = Vector2(12.0, 0.0)
	_expect(ComponentHierarchy.world_transform(asset, "component_child").origin.is_equal_approx(Vector2(14.0, 0.0)), "Group transforms should compose before the existing Component Parent hierarchy.")
	group["transform"]["position"] = Vector2(10.0, 0.0)
	var child_world_record := ComponentHierarchy.world_transform_record(asset, "component_child")
	_expect(Vector2(child_world_record.get("position", Vector2.ZERO)).is_equal_approx(Vector2(12.0, 0.0)), "The Canvas-facing transform record should expose a Child Component at its composed world position.")
	child["parent_component_id"] = ""
	child["transform"] = ComponentHierarchy.local_transform_from_world_record(asset, "component_child", child_world_record)
	_expect(ComponentHierarchy.world_transform(asset, "component_child").origin.is_equal_approx(Vector2(12.0, 0.0)), "Reparenting a Component to Root should preserve its visible world transform.")
	child["parent_component_id"] = "component_parent"
	child["transform"] = ComponentHierarchy.local_transform_from_world_record(asset, "component_child", child_world_record)
	_expect(ComponentHierarchy.world_transform(asset, "component_child").origin.is_equal_approx(Vector2(12.0, 0.0)), "Reparenting a Component under another Parent should preserve its visible world transform.")
	_expect(ComponentHierarchy.can_parent(asset, "component_parent", "component_child") == false, "Component hierarchy validation should reject cycles.")
	var forehead := {"id": "forehead", "name": "Forehead", "parent_component_id": "", "group_id": "", "transform": {"position": Vector2(20.0, 0.0), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}}
	var head_tip_part := {"id": "head_tip_part", "name": "Head Tip", "parent_component_id": "forehead", "group_id": "head_tip", "transform": {"position": Vector2(3.0, 0.0), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}}
	var head_tip_group := {"id": "head_tip", "name": "head_tip", "parent_component_id": "forehead", "transform": {"position": Vector2(10.0, 0.0), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}, "visibility": true}
	var grouped_asset := {"components": [forehead, head_tip_part], "groups": [head_tip_group], "guides": []}
	ComponentHierarchy.normalize_asset(grouped_asset)
	_expect(ComponentHierarchy.can_parent_group(grouped_asset, "head_tip", "forehead"), "A Group may be parented to a Component that is an ancestor of all of its direct Parts.")
	_expect(ComponentHierarchy.group_world_transform(grouped_asset, "head_tip").origin.is_equal_approx(Vector2(30.0, 0.0)) and ComponentHierarchy.world_transform(grouped_asset, "head_tip_part").origin.is_equal_approx(Vector2(33.0, 0.0)), "A parented Group should compose once after its Component Parent, while its Parts remain ordinary Component children.")
	_expect(not ComponentHierarchy.can_parent_group(grouped_asset, "head_tip", "head_tip_part"), "A Group cannot be parented beneath one of its Parts.")
	_expect(str(flow_1.get("guide_type", "")) == AssetGuide.FLOW and int(flow_1.get("ordinal", 0)) == 1 and int(flow_2.get("ordinal", 0)) == 2, "Legacy Flow Guides should migrate to canonical types with stable per-Component ordinals.")
	_expect(int(sample_1.get("ordinal", 0)) == 1 and int(child_sample.get("ordinal", 0)) == 1, "Guide numbering should be independent for every Component and Guide type.")
	_expect(ComponentHierarchy.next_guide_ordinal(asset, "component_parent", AssetGuide.FLOW) == 3 and AssetGuide.outliner_name(child_sample, "Eyes") == "Eyes → Sample01", "Guide naming data should support stable dynamic Component-based labels.")
	parent["name"] = "Face"
	_expect(AssetGuide.outliner_name(flow_1, str(parent.get("name", ""))) == "Face → Flow01", "Guide labels should immediately follow Component renames without mutating Guide data.")
	_expect(AssetGuide.color(AssetGuide.FLOW) == Color("#4267b2") and AssetGuide.color(AssetGuide.FLOW) != AssetGuide.color(AssetGuide.SAMPLE) and AssetGuide.color(AssetGuide.SAMPLE) != AssetGuide.color(AssetGuide.MOTION), "Flow, Sample, and Motion Guides should retain three distinct semantic colors.")
	parent["parent_component_id"] = "component_child"
	ComponentHierarchy.normalize_asset(asset)
	_expect(str(parent.get("parent_component_id", "")).is_empty(), "Loading cyclic Component data should safely promote one participant to the Asset root.")


func _test_group_outliner_workflows() -> void:
	var eye_left := {"id": "eye_left", "name": "eye_left", "type": "component", "parent_component_id": "", "group_id": "", "visibility": true, "transform": {"position": Vector2(10.0, 0.0), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}}
	var eye_right := {"id": "eye_right", "name": "eye_right", "type": "component", "parent_component_id": "", "group_id": "", "visibility": true, "transform": {"position": Vector2(30.0, 0.0), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}}
	var eyelashes_right := {"id": "eyelashes_right", "name": "eyelashes_right", "type": "component", "parent_component_id": "eye_left", "group_id": "lashes", "visibility": true, "transform": {"position": Vector2(2.0, 0.0), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}}
	var lashes_group := {"id": "lashes", "name": "eyelashes_right", "parent_component_id": "eye_left", "visibility": true, "transform": {"position": Vector2(1.0, 0.0), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}}
	var asset := {"id": "mage", "name": "Mage", "asset_type": "character", "visibility": true, "asset_pivot": Vector2.ZERO, "components": [eye_left, eye_right, eyelashes_right], "groups": [lashes_group], "guides": []}
	ComponentHierarchy.normalize_asset(asset)
	_expect(not ComponentHierarchy.can_parent_group(asset, "lashes", "eye_right") and ComponentHierarchy.can_move_group_to_component(asset, "lashes", "eye_right"), "Moving a Group should allow a sibling Component target by reparenting its direct Parts atomically.")
	_expect(not ComponentHierarchy.can_move_group_to_component(asset, "lashes", "eyelashes_right"), "A Group must not be moved beneath one of its own Parts.")
	var application = load("res://scripts/main.gd").new()
	application._build_ui()
	var test_assets: Array[Dictionary] = [asset]
	application.assets = test_assets
	application.active_module = "Create"
	application.active_create_submodule = "Character"
	application.expanded_assets["mage"] = true
	application._select_group("mage", "lashes")
	var group_button := _button_with_text(application.outliner_view, "G: eyelashes_right")
	var selected_style := group_button.get_theme_stylebox("normal") as StyleBoxFlat if group_button != null else null
	_expect(group_button != null and selected_style != null and selected_style.bg_color == Color("#f2c94c"), "The selected Group row should use the same highlighted Outliner style as selected Components.")
	var world_before := ComponentHierarchy.world_transform(asset, "eyelashes_right")
	var drag_data := {"kind": "group", "asset_id": "mage", "group_id": "lashes"}
	_expect(application.outliner_view.can_drop_data(Vector2.ZERO, drag_data, "mage", "eye_right"), "A Group should be droppable onto a valid sibling Component.")
	application._outliner_drop_data(Vector2.ZERO, drag_data, "mage", "eye_right")
	_expect(ComponentHierarchy.group_parent_id(lashes_group) == "eye_right" and str(eyelashes_right.get("parent_component_id", "")) == "eye_right", "Dropping a Group onto a Component should move both the Group anchor and its direct Parts beneath that Component.")
	_expect(ComponentHierarchy.world_transform(asset, "eyelashes_right").is_equal_approx(world_before), "Moving a Group to another Component must preserve every Part's visible world transform.")
	var world_before_delete := ComponentHierarchy.world_transform(asset, "eyelashes_right")
	application._delete_current_outliner_selection()
	_expect(ComponentHierarchy.group_by_id(asset, "lashes").is_empty() and not ComponentHierarchy.component_by_id(asset, "eyelashes_right").is_empty() and str(eyelashes_right.get("group_id", "")) == "", "Delete on a selected Group should remove only the Group and retain its Components.")
	_expect(ComponentHierarchy.world_transform(asset, "eyelashes_right").is_equal_approx(world_before_delete), "Deleting a Group should keep its former Components visually fixed.")
	application.free()


func _test_asset_guides() -> void:
	var component := _component()
	component.merge({"id": "component_1", "name": "body", "visibility": true, "transform": {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}})
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
	var serialized: Dictionary = WorldDocumentService.serialize_asset_guide(guide)
	_expect(serialized.get("points", [])[0].get("position", null) is Array, "Guide persistence should serialize authored Spine positions as JSON arrays.")
	var restored: Dictionary = WorldDocumentService.deserialize_asset_guide(serialized)
	_expect(restored.get("points", [])[0].get("position", null) is Vector2 and str(restored.get("guide_type", "")) == AssetGuide.BODY_FLOW, "Guide loading should restore Vector2 topology and retain its semantic type.")
	var animation_guide := AssetGuide.create("guide_animation", "Deform Spine", AssetGuide.ANIMATION_SPINE, "component_1")
	BezierTopology.add_point(animation_guide, Vector2(1.0, 2.0), "aligned")
	BezierTopology.add_point(animation_guide, Vector2(4.0, 6.0), "aligned")
	var animation_round_trip: Dictionary = WorldDocumentService.deserialize_asset_guide(WorldDocumentService.serialize_asset_guide(animation_guide))
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
	application.component_dialog.set_meta("draw_mode", "contour")
	application.component_dialog.set_meta("source_asset_id", "")
	application.component_name_input.text = "arm_line"
	application._confirm_component_creation()
	var child_component: Dictionary = application._get_component(application._get_asset("asset_1"), application.selected_component_id)
	_expect(str(child_component.get("parent_component_id", "")) == "component_1" and Vector2(child_component.get("transform", {}).get("pivot", Vector2.ZERO)).is_equal_approx(Vector2(parent_component.get("transform", {}).get("pivot", Vector2.ZERO))), "Child creation should persist a real Parent relationship and inherit the Parent pivot initially.")
	_expect(str(child_component.get("draw_mode", "")) == "contour" and not child_component.has("contour_width_px") and not child_component.has("ribbon_width_px"), "New open Contours should be fill-less typed Components without a Component-local width field.")
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
	var add_menu_labels := PackedStringArray()
	for menu_index in application.component_add_menu.item_count:
		add_menu_labels.append(application.component_add_menu.get_item_text(menu_index))
	_expect(application.component_add_child_menu.item_count == 3 and application.component_add_guide_menu.item_count >= 4 and application.component_add_weapon_guide_menu.item_count == 5 and application.component_add_region_menu.item_count == 3 and add_menu_labels.has("Region"), "Every scoped add menu should expose Child, Guide, and optional Region types.")
	test_asset = application._get_asset("asset_1")
	test_asset["groups"] = [{"id": "group_head", "name": "head", "parent_component_id": "component_1", "transform": {"position": Vector2(2.0, 3.0), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}, "visibility": true}]
	var component_count_before_group_region: int = test_asset.get("components", []).size()
	application._create_region("asset_1", "group", "group_head", "attack")
	_expect(test_asset.get("components", []).size() == component_count_before_group_region, "Regions should only be creatable from a Component + menu, never from a Group or Asset root.")
	application._create_region("asset_1", "component", "component_1", "attack")
	var region: Dictionary = application._get_component(test_asset, application.selected_component_id)
	var geometry_source_option := OptionButton.new()
	geometry_source_option.add_item("Free Draw")
	geometry_source_option.set_item_metadata(0, WorldDocumentService.REGION_GEOMETRY_AUTHORED)
	geometry_source_option.add_item("Component Geometry")
	geometry_source_option.set_item_metadata(1, WorldDocumentService.REGION_GEOMETRY_COMPONENT)
	_expect(WorldDocumentService.region_uses_component_geometry(region) and application.active_state.is_empty() and application.active_draw_tool.is_empty(), "New Regions should default to Component Geometry without entering a drawing state.")
	application._on_region_geometry_source_selected(0, geometry_source_option)
	for region_position in [Vector2.ZERO, Vector2(2.0, 0.0), Vector2(1.0, 2.0)]:
		BezierTopology.add_point(region, region_position, "linear")
	BezierTopology.close_active_chain(region)
	var retained_region_points: Array = region.get("points", []).duplicate(true)
	application._on_region_geometry_source_selected(1, geometry_source_option)
	application._render_context_bar()
	var locked_draw_button := _button_starting_with(application.context_bar, "⌘1  Draw Point")
	var locked_edit_button := _button_starting_with(application.context_bar, "⌘2  Edit Point")
	application._render_canvas_context()
	_expect(WorldDocumentService.region_uses_component_geometry(region) and locked_draw_button != null and locked_draw_button.disabled and locked_edit_button != null and locked_edit_button.disabled, "A Component Geometry Region should visibly disable its Draw and Edit tools.")
	application._render_inspector()
	_expect(application.create_inspector_view.transform_fields.is_empty(),
		"A Component Geometry Region should leave no Transform field references from an earlier render behind.")
	_expect(application.canvas_view.bezier_points.size() == parent_component.get("points", []).size(), "A Component Geometry Region should preview the attached Component geometry 1:1.")
	application._activate_draw_state()
	_expect(application.active_state.is_empty(), "Disabled Region drawing must also be guarded against keyboard or direct command activation.")
	application._on_region_geometry_source_selected(0, geometry_source_option)
	_expect(region.get("points", []) == retained_region_points, "Switching through Component Geometry should retain the inactive Free Draw topology without copying Component geometry into it.")
	# Built with .new() and never given a Scene Tree parent, so nothing else
	# would ever free it; queue_free() does not run in a script test.
	geometry_source_option.free()
	application._create_weapon_guide("asset_1", "component", "component_1", AssetGuide.WEAPON_SOCKET_PRIMARY)
	var socket_guide: Dictionary = application._get_guide(test_asset, application.selected_guide_id)
	_expect(AssetGuide.is_weapon_frame(str(socket_guide.get("guide_type", ""))) and str(socket_guide.get("scope", {}).get("component_id", "")) == "component_1" and application.canvas_view.interaction_state == "transform", "Weapon Socket Primary should be a Component-scoped oriented transform Guide.")
	application._create_weapon_guide("asset_1", "group", "group_head", AssetGuide.ATTACK_POINT_PRIMARY)
	var attack_point_guide: Dictionary = application._get_guide(application._get_asset("asset_1"), application.selected_guide_id)
	_expect(str(attack_point_guide.get("scope", {}).get("kind", "")) == "group" and str(attack_point_guide.get("scope", {}).get("group_id", "")) == "group_head", "Weapon Guides should support direct Group scope from the Group + menu.")
	application._create_weapon_guide("asset_1", "component", "component_1", AssetGuide.REACH_LIMIT_PRIMARY)
	var reach_limit_guide: Dictionary = application._get_guide(application._get_asset("asset_1"), application.selected_guide_id)
	_expect(str(reach_limit_guide.get("guide_type", "")) == AssetGuide.REACH_LIMIT_PRIMARY and AssetGuide.validation_issues(reach_limit_guide).is_empty(), "Reach Limit Primary should be a valid transform-based Weapon Guide.")
	application._create_weapon_guide("asset_1", "component", "component_1", AssetGuide.GRIP_SECONDARY)
	var secondary_grip_guide: Dictionary = application._get_guide(application._get_asset("asset_1"), application.selected_guide_id)
	_expect(str(secondary_grip_guide.get("guide_type", "")) == AssetGuide.GRIP_SECONDARY and AssetGuide.validation_issues(secondary_grip_guide).is_empty(), "Grip Secondary should be a valid transform-based Weapon Guide.")
	parent_component["transform"] = {"position": Vector2(-3.0, 2.0), "rotation": 20.0, "scale": Vector2(1.0, 1.5), "pivot": Vector2.ZERO}
	parent_component["name"] = "eyebrow_left"
	child_component["name"] = "eye_left"
	var duplicate_asset: Dictionary = application._get_asset("asset_1")
	var component_count_before_duplicate: int = duplicate_asset.get("components", []).size()
	var guide_count_before_duplicate: int = duplicate_asset.get("guides", []).size()
	var descendant_count_before_duplicate: int = ComponentHierarchy.descendants(duplicate_asset, "component_1").size()
	application._duplicate_component("asset_1", "component_1")
	var plain_duplicate: Dictionary = application._get_component(application._get_asset("asset_1"), application.selected_component_id)
	var plain_duplicate_children := ComponentHierarchy.children(application._get_asset("asset_1"), str(plain_duplicate.get("id", "")))
	_expect(application._get_asset("asset_1").get("components", []).size() == component_count_before_duplicate + 1 + descendant_count_before_duplicate and application._get_asset("asset_1").get("guides", []).size() == guide_count_before_duplicate and str(plain_duplicate.get("parent_component_id", "")) == str(parent_component.get("parent_component_id", "")) and str(plain_duplicate.get("name", "")) == "eyebrow_left Copy" and plain_duplicate_children.size() == descendant_count_before_duplicate and str(plain_duplicate_children[0].get("name", "")) == "eye_left Copy", "Component Duplicate should copy the complete Component subtree with unique free names.")
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
	var flipped_point_position := Vector2(flipped_duplicate.get("points", [])[0].get("position", Vector2.ZERO))
	var source_point_position := Vector2(parent_component.get("points", [])[0].get("position", Vector2.ZERO))
	_expect(is_equal_approx(float(flipped_duplicate.get("transform", {}).get("rotation", 0.0)), -20.0) and is_equal_approx(Vector2(flipped_duplicate.get("transform", {}).get("scale", Vector2.ONE)).x, 1.0) and is_equal_approx(flipped_point_position.x, -source_point_position.x), "Flip Orientation should mirror the Component geometry and automatically Rebase its negative Scale.")
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
	application.component_name_input.text = "cloak"
	application._confirm_component_creation()
	var pupil_component: Dictionary = application._get_component(application._get_asset("asset_1"), application.selected_component_id)
	_expect(str(pupil_component.get("parent_component_id", "")) == "component_1" and str(pupil_component.get("draw_mode", "")) == "primitive" and pupil_component.get("points", []).is_empty() and pupil_component.get("edges", []).is_empty() and pupil_component.get("chains", []).is_empty() and pupil_component.get("primitive", {}).is_empty(), "Primitive Child creation should create an empty Primitive Component without generated Bézier topology.")
	application._on_primitive_placed(Vector2(0.25, -0.5), 2.5)
	_expect(PrimitiveGeometryService.has_circle(pupil_component) and is_equal_approx(float(pupil_component.get("primitive", {}).get("diameter_cm", 0.0)), 2.5) and PrimitiveGeometryService.center(pupil_component).is_equal_approx(Vector2(0.25, -0.5)), "Circle placement should persist only its parametric center and diameter.")
	application._render_inspector()
	var primitive_topology_option := _inspector_option(application, "Outer")
	_expect(primitive_topology_option != null and primitive_topology_option.item_count == 2, "The Primitive Inspector should expose the Outer/Hole topology selector.")
	_choose_option(primitive_topology_option, 1)
	application._render_inspector()
	_expect(str(pupil_component.get("topology_role", "")) == "hole" and pupil_component.get("chains", []).is_empty(), "Selecting Hole should persist Primitive topology semantics without generating Bezier topology.")
	_expect(_inspector_toggle(application, "Visible") != null and _inspector_spin(application, "Contour Stroke Width (px)") == null and _inspector_spin(application, "Projection Depth (cm)") == null and _inspector_spin(application, "Z Order (Asset-local)") == null, "An ordinary Hole should expose only its constraint visibility, not visual Body properties.")
	var inspector_controls: Array = []
	_inspector_controls(application.inspector_content, inspector_controls)
	var hole_parent_option: OptionButton = null
	for control in inspector_controls:
		if not control is OptionButton:
			continue
		for item_index in control.item_count:
			if str(control.get_item_metadata(item_index)) == "component_1":
				hole_parent_option = control
	var hole_parent_offers_root := false
	if hole_parent_option != null:
		for item_index in hole_parent_option.item_count:
			hole_parent_offers_root = hole_parent_offers_root or str(hole_parent_option.get_item_metadata(item_index)).is_empty()
	_expect(hole_parent_option != null and not hole_parent_offers_root, "The Hole Parent dropdown must not offer the invalid Asset Root target.")
	var valid_hole_parent_id := str(pupil_component.get("parent_component_id", ""))
	pupil_component["parent_component_id"] = ""
	application._render_inspector()
	var invalid_root_option := _inspector_option(application, "⚠ Root (invalid)")
	_expect(invalid_root_option != null and invalid_root_option.selected == 0, "A loaded Hole at Asset Root must show its actual invalid Parent state instead of silently selecting the first valid Body.")
	pupil_component["parent_component_id"] = valid_hole_parent_id
	application._render_inspector()
	application._render_outliner()
	var hole_row_button := _button_starting_with(application.outliner_view, "cloak")
	var hole_row_has_add_button := false
	if hole_row_button != null:
		for sibling in hole_row_button.get_parent().get_children():
			hole_row_has_add_button = hole_row_has_add_button or (sibling is Button and str(sibling.text) == "+")
	_expect(hole_row_button != null and not hole_row_has_add_button, "An ordinary Hole row must not expose the scoped Add menu.")
	var hole_parent_before_detach := str(pupil_component.get("parent_component_id", ""))
	application._detach_component("asset_1", str(pupil_component.get("id", "")))
	_expect(str(pupil_component.get("parent_component_id", "")) == hole_parent_before_detach, "Detaching an ordinary Hole must be rejected when it would promote the Hole to Asset Root.")
	var hole_child_count_before: int = test_asset.get("components", []).size()
	var next_component_before_hole_child: int = application.next_component_id
	application.component_dialog.set_meta("asset_id", "asset_1")
	application.component_dialog.set_meta("parent_component_id", str(pupil_component.get("id", "")))
	application.component_dialog.set_meta("draw_mode", "closed_loop")
	application.component_dialog.set_meta("source_asset_id", "")
	application.component_name_input.text = "invalid_hole_child"
	application._confirm_component_creation()
	application._create_region("asset_1", "component", str(pupil_component.get("id", "")), "attack")
	_expect(test_asset.get("components", []).size() == hole_child_count_before and application.next_component_id == next_component_before_hole_child, "Component and Region creation beneath an ordinary Hole must be rejected before mutating the Asset.")
	_expect(WorldDocumentService.DRAW_MODES == ["closed_loop", "contour", "primitive"], "Components should expose only Closed Loop, Contour, and Primitive draw modes.")
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
	var path_document: Dictionary = WorldDocumentService.default_motion_path("path_7", "Orbit")
	_expect(str(path_document.get("id", "")) == "path_7" and path_document.get("topology", {}).get("points", []).is_empty(), "A Path shell should own a stable ID and independent empty topology.")
	var normalized_path: Dictionary = WorldDocumentService.normalize_motion_path({"id": "path_7", "name": "Orbit", "playback": {"duration": 4.0}}, "fallback")
	_expect(is_equal_approx(float(normalized_path.get("playback", {}).get("duration", 0.0)), 4.0) and bool(normalized_path.get("playback", {}).get("loop", false)), "Path normalization should merge persisted playback fields with stable defaults.")
	var sequence_document: Dictionary = WorldDocumentService.normalize_motion_sequence({"id": "sequence_3", "name": "Arrival", "entries": [{"id": "entry_1", "asset_id": "asset_1", "animation_state_id": "idle", "path_id": "path_7"}]}, "fallback")
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


const MOTION_SIGNAL_ROUTES := [
	["act_direction_changed", "_on_motion_act_direction_changed"],
	["act_easing_selected", "_on_motion_act_easing_selected"],
	["act_enabled_changed", "_on_motion_act_enabled_changed"],
	["act_jump_arc_selected", "_on_motion_act_jump_arc_selected"],
	["act_number_changed", "_on_motion_act_number_changed"],
	["act_remove_requested", "_remove_selected_motion_act"],
	["act_rename_requested", "_rename_motion_act"],
	["contract_parameter_add_requested", "_add_contract_parameter"],
	["contract_parameter_remove_requested", "_remove_contract_parameter"],
	["contract_parameter_rename_requested", "_rename_contract_parameter"],
	["contract_parameter_type_selected", "_on_contract_parameter_type_selected"],
	["marker_event_rename_requested", "_rename_marker_event"],
	["marker_kind_selected", "_on_marker_kind_selected"],
	["marker_phase_changed", "_on_marker_phase_changed"],
	["motion_domain_selected", "_on_motion_domain_selected"],
	["motion_enabled_changed", "_on_motion_enabled_changed"],
	["motion_item_remove_requested", "_request_motion_item_removal"],
	["motion_parameter_changed", "_on_motion_parameter_changed"],
	["motion_phase_offset_changed", "_on_motion_phase_offset_changed"],
	["motion_primitive_selected", "_on_motion_primitive_selected"],
	["motion_remove_requested", "_request_motion_removal"],
	["motion_rename_requested", "_rename_motion"],
	["motion_target_selected", "_on_motion_target_selected"],
	["path_duration_changed", "_on_motion_path_duration_changed"],
	["path_playback_toggled", "_on_motion_path_playback_toggle"],
	["path_preview_asset_selected", "_on_motion_path_preview_asset_selected"],
	["path_rename_requested", "_rename_motion_path"],
	["runtime_bool_changed", "_on_motion_runtime_bool_changed"],
	["runtime_number_changed", "_on_motion_runtime_number_changed"],
	["section_toggled", "_on_inspector_section_toggled"],
	["sequence_asset_selected", "_on_motion_sequence_asset_selected"],
	["sequence_entry_enabled_changed", "_on_motion_sequence_entry_enabled_changed"],
	["sequence_entry_remove_requested", "_remove_motion_sequence_entry"],
	["sequence_entry_rename_requested", "_rename_motion_sequence_entry"],
	["sequence_path_selected", "_on_motion_sequence_path_selected"],
	["sequence_rename_requested", "_rename_motion_sequence"],
	["sequence_state_selected", "_on_motion_sequence_state_selected"],
	["state_cycle_duration_changed", "_on_motion_state_cycle_duration_changed"],
	["state_remove_requested", "_request_motion_state_removal"],
	["state_rename_requested", "_rename_motion_state"],
	["transition_entry_mode_selected", "_on_transition_entry_mode_selected"],
	["transition_exit_policy_selected", "_on_transition_exit_policy_selected"],
	["transition_move_requested", "_move_transition"],
	["transition_number_changed", "_on_transition_number_changed"],
	["transition_rule_add_requested", "_add_transition_rule"],
	["transition_rule_operator_selected", "_on_transition_rule_operator_selected"],
	["transition_rule_parameter_selected", "_on_transition_rule_parameter_selected"],
	["transition_rule_remove_requested", "_remove_transition_rule"],
	["transition_rule_value_changed", "_on_transition_rule_value_changed"],
	["transition_target_selected", "_on_transition_target_selected"],
]

const MOTION_PROBE_CASES := ["asset", "state", "motion", "motion_inner", "transition",
	"transition_seeded", "marker", "act", "act_jump", "act_blink", "path", "sequence",
	"sequence_player"]


func _prepare_motion_case(application: Control, case_name: String) -> String:
	# Puts the editor into one Motion state and returns the submodule to render.
	var asset: Dictionary = application.assets[0]
	application.selected_asset_id = str(asset.get("id", ""))
	application.motion_selection.select_asset(application.selected_asset_id)
	application.motion_workspace.set_asset(application.selected_asset_id, str(asset.get("name", "Asset")),
		asset.get("components", []), application._ensure_asset_animation(asset))
	var states: Array = application.motion_workspace.get_states_for_asset(application.selected_asset_id)
	var first_state_id := str(states[0].get("id", "")) if not states.is_empty() else ""
	match case_name:
		"state":
			application.motion_selection.select_state(application.selected_asset_id, first_state_id)
		"motion":
			application.motion_workspace.add_motion(first_state_id)
		"motion_inner":
			application.motion_workspace.add_motion(first_state_id)
			application.motion_workspace.set_motion_property(first_state_id,
				str(application.motion_selection.item_id), "domain", MotionWorkspace.INNER)
		"transition":
			application.motion_workspace.add_transition(first_state_id)
		"transition_seeded":
			application.motion_selection.select_item(MotionSelection.TRANSITION,
				application.selected_asset_id, first_state_id, "transition_idle_01")
		"marker":
			application.motion_workspace.add_marker(first_state_id)
		"act", "act_jump", "act_blink":
			var acts: Array[Dictionary] = [
				WorldDocumentService.default_motion_act("act_1", "Slide", MotionActEvaluator.SLIDE),
				WorldDocumentService.default_motion_act("act_2", "Jump", MotionActEvaluator.JUMP),
				WorldDocumentService.default_motion_act("act_3", "Blink", MotionActEvaluator.BLINK)]
			application.motion_acts = acts
			# One Act per primitive: the Jump arc and the Blink timing controls only
			# exist on their own primitive.
			application.selected_motion_act_id = "act_2" if case_name == "act_jump" else ("act_3" if case_name == "act_blink" else "act_1")
			return "Act"
		"path":
			var paths: Array[Dictionary] = [WorldDocumentService.default_motion_path("path_1", "Walk Path")]
			application.motion_paths = paths
			application.selected_motion_path_id = "path_1"
			application.motion_path_preview_asset_id = application.selected_asset_id
			return "Path"
		"sequence", "sequence_player":
			var sequence_paths: Array[Dictionary] = [WorldDocumentService.default_motion_path("path_1", "Walk Path")]
			application.motion_paths = sequence_paths
			application.selected_motion_path_id = "path_1"
			var sequences: Array[Dictionary] = [WorldDocumentService.default_motion_sequence("sequence_1", "Walk Cycle")]
			application.motion_sequences = sequences
			application.selected_motion_sequence_id = "sequence_1"
			application._add_motion_sequence_entry()
			application.motion_sequence_view = MotionSequenceWorkspace.VIEW_PLAYER if case_name == "sequence_player" else MotionSequenceWorkspace.VIEW_COMPOSITION
			return "Sequence"
	return "Animation"


func _record_view_signal(signal_name: String, arguments: Array, values: Array) -> void:
	view_signals_emitted[signal_name] = true
	for index in range(arguments.size()):
		var declared_type: int = int(arguments[index].get("type", TYPE_NIL))
		if declared_type == TYPE_NIL or index >= values.size():
			continue
		var value = values[index]
		if declared_type == TYPE_FLOAT and typeof(value) == TYPE_INT:
			continue
		if typeof(value) != declared_type and value != null:
			view_signal_argument_failures.append("%s argument %d is %d, declared %d" % [
				signal_name, index, typeof(value), declared_type])


func _view_signal_recorder(signal_name: String, arguments: Array) -> Callable:
	# A signal can only be connected to a Callable of its own arity, so one
	# recorder per arity. Six covers every view signal in the editor.
	match arguments.size():
		0:
			return func() -> void: _record_view_signal(signal_name, arguments, [])
		1:
			return func(a) -> void: _record_view_signal(signal_name, arguments, [a])
		2:
			return func(a, b) -> void: _record_view_signal(signal_name, arguments, [a, b])
		3:
			return func(a, b, c) -> void: _record_view_signal(signal_name, arguments, [a, b, c])
		4:
			return func(a, b, c, d) -> void: _record_view_signal(signal_name, arguments, [a, b, c, d])
	return func(a, b, c, d, e) -> void: _record_view_signal(signal_name, arguments, [a, b, c, d, e])


func _exercise_control(control: Node) -> void:
	# Fires what a user would fire on this control. Only the signal the view
	# emits in response matters, so the values are the ones already there.
	if control is OptionButton:
		if control.item_count > 0:
			control.item_selected.emit(0)
	elif control is CheckBox or control is CheckButton:
		control.toggled.emit(not control.button_pressed)
	elif control is Button and control.toggle_mode:
		# A toggle-mode Button reports through toggled, not pressed. The Mesh
		# Inspector builds its advanced blocks that way.
		control.toggled.emit(not control.button_pressed)
		control.pressed.emit()
	elif control is SpinBox:
		control.value_changed.emit(control.value)
		control.get_line_edit().text_submitted.emit(str(control.value))
		control.get_line_edit().focus_exited.emit()
	elif control is Slider:
		control.value_changed.emit(control.value)
	elif control is LineEdit:
		control.text_submitted.emit(str(control.text))
		control.focus_exited.emit()
	elif control is Button:
		control.pressed.emit()


const OUTLINER_SIGNAL_ROUTES := [
	["asset_selected", "_select_asset"],
	["component_selected", "_on_outliner_component_selected"],
	["group_selected", "_select_group"],
	["guide_selected", "_select_guide"],
	["region_selected", "_on_outliner_component_selected"],
	["weighting_asset_selected", "_select_weighting_asset"],
	["weighting_component_selected", "_select_weighting_component"],
	["weighting_style_selected", "_select_weighting_style"],
	["weighting_style_add_requested", "_create_weighting_style"],
	["motion_asset_selected", "_select_motion_asset"],
	["motion_path_selected", "_select_motion_path"],
	["motion_sequence_selected", "_select_motion_sequence"],
	["motion_act_preview_asset_selected", "_select_motion_act_preview_asset"],
	["component_add_requested", "_open_component_add_menu"],
	["group_add_requested", "_open_group_add_menu"],
	["component_dialog_requested", "_open_component_dialog"],
	["row_context_menu_requested", "_on_outliner_row_context_menu"],
	["drop_requested", "_outliner_drop_data_from_view"],
	["visibility_toggle_requested", "_on_outliner_visibility_toggled"],
	["geometry_asset_selected", "_select_geometry_asset"],
	["geometry_component_selected", "_select_geometry_component"],
	["geometry_hole_selected", "_select_geometry_sampling_hole"],
	["geometry_input_selected", "_select_geometry_seeding_input"],
	["geometry_pipeline_action", "_on_geometry_pipeline_action"],
]

# Signals the view declares without connecting them. There are none: every
# signal OutlinerView declares is routed. A new entry here needs a reason,
# because the completeness check below otherwise fails on it — which is how
# expansion_toggle_requested was found and removed. Expansion is not an intent
# the Outliner reports: main.gd sets it in _select_asset through
# _set_outliner_asset_expanded and pushes the result back in through
# set_expansion.
const OUTLINER_UNCONNECTED_SIGNALS: Array[String] = []

# Routed and checked as such, but not drivable from a walk: reparenting arrives
# through set_drag_forwarding, and Godot exposes neither the virtuals
# (_can_drop_data, _drop_data) nor public methods for them, so a test cannot
# make a Control run its own drop callbacks. What the drop does is covered by
# the Group reparenting test, which calls the view's can_drop_data helper and
# main.gd's _outliner_drop_data directly; the binding between the two is the
# part no test can reach.
const OUTLINER_UNDRIVABLE_SIGNALS := ["drop_requested"]

const OUTLINER_PROBE_CASES := ["create", "create_expanded", "style", "motion_animation",
	"motion_path", "motion_sequence", "motion_act", "mesh_sampling", "mesh_seeding",
	"mesh_meshing"]


func _outliner_wiring_assets() -> Array[Dictionary]:
	# One Asset carrying every row kind the Create tree can draw, plus a second
	# one so an Asset row is reachable while nothing is expanded.
	var body := _outliner_test_component("component_1", "body")
	body["topology_role"] = "outer"
	var arm := _outliner_test_component("component_2", "arm")
	arm["parent_component_id"] = "component_1"
	var hole := {"points": [], "edges": [], "chains": [], "id": "component_3", "name": "eye",
		"visibility": true, "type": "reference", "parent_component_id": "component_1",
		"topology_role": "hole", "source_asset_id": "asset_2"}
	var region := {"points": [], "edges": [], "chains": [], "id": "component_4", "name": "hitbox",
		"visibility": true, "type": "region", "region_type": "attack",
		"parent_component_id": "component_1"}
	var guide := {"id": "guide_1", "guide_type": AssetGuide.CUT, "ordinal": 1, "visibility": true,
		"scope": {"kind": "component", "component_id": "component_1"},
		"points": [], "edges": [], "chains": []}
	var spine := {"id": "guide_2", "guide_type": AssetGuide.SAMPLER_SPINE, "ordinal": 1,
		"visibility": true, "scope": {"kind": "component", "component_id": "component_1"},
		"points": [], "edges": [], "chains": []}
	var group := {"id": "group_1", "name": "torso", "transform": {}, "visibility": true,
		"parent_component_id": ""}
	return [
		{"id": "asset_1", "name": "Wizard", "visibility": true,
			"components": [body, arm, hole, region], "groups": [group], "guides": [guide, spine]},
		{"id": "asset_2", "name": "Orb", "visibility": true,
			"components": [], "groups": [], "guides": []},
	] as Array[Dictionary]


func _prepare_outliner_case(application: Control, case_name: String) -> void:
	# Puts the editor into one Outliner state. Only what the tree reads is set.
	application.expanded_assets.clear()
	application.selected_asset_id = "asset_1"
	application.selected_component_id = ""
	application.selected_weighting_style_id = ""
	match case_name:
		"create":
			application.active_module = "Create"
			application.active_create_submodule = "Character"
		"create_expanded":
			application.active_module = "Create"
			application.active_create_submodule = "Character"
			application.expanded_assets["asset_1"] = true
		"style":
			application.active_module = "Style"
			application.active_style_submodule = "Weighting"
			application.selected_component_id = "component_1"
			application.expanded_assets["asset_1"] = true
			var document: Dictionary = application._mutable_geometry_document("asset_1", "component_1")
			document["weighting"]["styles"] = [WeightingService.default_style(
				"weight_1", "Uniform", "component_1")]
		"motion_animation", "motion_path", "motion_sequence", "motion_act":
			application.active_module = "Motion"
			application.active_motion_submodule = {
				"motion_animation": "Animation", "motion_path": "Path",
				"motion_sequence": "Sequence", "motion_act": "Act"}[case_name]
			var paths: Array[Dictionary] = [WorldDocumentService.default_motion_path("path_1", "Walk Path")]
			application.motion_paths = paths
			var sequences: Array[Dictionary] = [WorldDocumentService.default_motion_sequence("sequence_1", "Walk Cycle")]
			application.motion_sequences = sequences
		"mesh_sampling", "mesh_seeding", "mesh_meshing":
			application.active_module = "Mesh"
			application.active_geometry_submodule = {
				"mesh_sampling": "Sampling", "mesh_seeding": "Seeding",
				"mesh_meshing": "Meshing"}[case_name]
			application.selected_component_id = "component_1"
			application.expanded_assets["asset_1"] = true
			var seeding_document: Dictionary = application._mutable_geometry_document("asset_1", "component_1")
			seeding_document["seeding"]["recipe"]["method"] = GeometrySeedingService.SPINE_FLOW
			seeding_document["seeding"]["recipe"]["parameters"]["spine_inputs"] = [
				{"guide_id": "guide_2", "enabled": true}]
	# The Mesh rows are resolved by main.gd against its own view, so that view
	# needs the same context before the probe can be given the result.
	application._render_outliner()


func _build_outliner_probe(application: Control) -> OutlinerView:
	# A bare view fed the same context _render_outliner pushes, so the walk can
	# fire rows without the editor's own handlers re-rendering them away.
	var probe := OutlinerView.new()
	probe.set_documents(application.assets, application.motion_paths, application.motion_sequences)
	probe.set_module(application.active_module, application.active_create_submodule,
		application.active_geometry_submodule, application.active_motion_submodule)
	probe.set_selection(application.selected_asset_id, application.selected_component_id,
		application.selected_component_ids, application.selected_group_id,
		application.selected_guide_id, application.selected_motion_path_id,
		application.selected_motion_sequence_id, application.selected_weighting_style_id,
		application.motion_act_preview_asset_id)
	probe.set_filters("", application.outliner_asset_type_filters)
	probe.set_expansion(application.expanded_assets, application._outliner_focus_asset_id())
	probe.set_row_status(application._outliner_row_status())
	probe.set_geometry_rows(application._geometry_outliner_rows())
	return probe


func _exercise_outliner_control(control: Node) -> void:
	# Rows report three further intents that no plain press reaches: the context
	# menu rides on gui_input, visibility on a checkbox, and reparenting on the
	# drag-and-drop forwarding.
	if control is CheckBox or control is CheckButton:
		control.toggled.emit(not control.button_pressed)
		return
	if control is Button:
		control.pressed.emit()
		if control.gui_input.get_connections().size() > 0:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_RIGHT
			click.pressed = true
			control.gui_input.emit(click)


const GEOMETRY_SIGNAL_ROUTES := [
	["meshing_advanced_relaxation_toggled", "_on_geometry_meshing_advanced_relaxation_toggled"],
	["meshing_bake_requested", "_bake_geometry_meshing"],
	["meshing_float_focus_exited", "_on_geometry_meshing_float_focus_exited"],
	["meshing_float_text_submitted", "_on_geometry_meshing_float_text_submitted"],
	["meshing_override_changed", "_on_geometry_meshing_override_changed"],
	["meshing_parameter_changed", "_on_geometry_meshing_parameter_changed"],
	["meshing_seed_source_selected", "_on_geometry_meshing_seed_source_selected"],
	["meshing_view_option_changed", "_on_geometry_meshing_view_option_changed"],
	["sampling_bake_requested", "_bake_geometry_sampling"],
	["sampling_feature_detail_changed", "_on_geometry_sampling_feature_detail_changed"],
	["sampling_parameter_changed", "_on_geometry_sampling_parameter_changed"],
	["sampling_refinement_changed", "_on_geometry_sampling_refinement_changed"],
	["sampling_refinement_toggled", "_on_geometry_sampling_refinement_toggled"],
	["sampling_spacing_focus_exited", "_on_geometry_spacing_focus_exited"],
	["sampling_spacing_text_submitted", "_on_geometry_spacing_text_submitted"],
	["section_toggled", "_on_inspector_section_toggled"],
	["seeding_advanced_pattern_toggled", "_on_geometry_seeding_advanced_pattern_toggled"],
	["seeding_bake_requested", "_bake_geometry_seeding"],
	["seeding_boundary_override_changed", "_on_geometry_seeding_boundary_override_changed"],
	["seeding_fill_gaps_changed", "_on_geometry_seeding_fill_gaps_changed"],
	["seeding_float_focus_exited", "_on_geometry_seeding_float_focus_exited"],
	["seeding_float_text_submitted", "_on_geometry_seeding_float_text_submitted"],
	["seeding_method_selected", "_on_geometry_seeding_method_selected"],
	["seeding_parameter_changed", "_on_geometry_seeding_parameter_changed"],
	["seeding_spine_enabled_changed", "_on_geometry_seeding_spine_enabled"],
	["seeding_stagger_override_changed", "_on_geometry_seeding_stagger_override_changed"],
]

# Connected through an adapter lambda rather than a named handler, because the
# view reports only the id and main.gd binds the current Asset and Component
# around it. get_method() reports "<anonymous lambda>" for those, so the routing
# table cannot name a target; what the adapter does is asserted directly below
# instead, which is the stronger check of the two.
const GEOMETRY_ADAPTER_SIGNALS := ["sampling_hole_selected", "sampling_cut_selected"]

const GEOMETRY_PROBE_CASES := ["sampling", "sampling_refined", "seeding_poisson",
	"seeding_spine", "meshing", "meshing_contour"]


func _geometry_wiring_asset() -> Dictionary:
	# One Component carrying every Sampling input the boundary rows can show,
	# plus a Contour sibling for the Meshing branch that replaces the panel.
	var body := _outliner_test_component("component_1", "body")
	body["topology_role"] = "outer"
	var hole := {"points": [], "edges": [], "chains": [], "id": "component_3", "name": "eye",
		"visibility": true, "type": "reference", "parent_component_id": "component_1",
		"topology_role": "hole", "source_asset_id": "asset_2"}
	var contour := _outliner_test_component("component_9", "outline")
	contour["draw_mode"] = "contour"
	var cut := {"id": "guide_1", "guide_type": AssetGuide.CUT, "ordinal": 1, "visibility": true,
		"scope": {"kind": "component", "component_id": "component_1"},
		"points": [], "edges": [], "chains": []}
	var spine := {"id": "guide_2", "guide_type": AssetGuide.SAMPLER_SPINE, "ordinal": 1,
		"visibility": true, "scope": {"kind": "component", "component_id": "component_1"},
		"points": [], "edges": [], "chains": []}
	return {"id": "asset_1", "name": "Wizard", "visibility": true,
		"components": [body, hole, contour], "groups": [], "guides": [cut, spine]}


func _geometry_wiring_document(application: Control, spine_flow: bool) -> void:
	# Baked results and refined overrides, so the rows that only appear once
	# something is baked or refined are actually built.
	var document: Dictionary = application._mutable_geometry_document("asset_1", "component_1")
	document["sampling"]["recipe"] = {"method": GeometrySamplingService.ADAPTIVE,
		"parameters": {"spacing": 2.0, "feature_detail": 0.4,
			"boundary_refinements": {"guide_1": {"factor": 2.5}}}}
	document["sampling"]["bakes"][GeometrySamplingService.ADAPTIVE] = {"sample_count": 42,
		"constraint_sample_count": 40, "preserve_count": 3, "hole_count": 1, "cuts": [{}],
		"boundary_stats": [{"input_id": "", "role": "outer", "sample_count": 20},
			{"input_id": "guide_1", "role": "cut", "sample_count": 12},
			{"input_id": "component_3", "role": "hole", "sample_count": 10}]}
	var seeding_method := GeometrySeedingService.SPINE_FLOW if spine_flow else GeometrySeedingService.POISSON_FILL
	document["seeding"]["recipe"] = {"method": seeding_method,
		"parameters": {"spacing": 2.5, "flow_stretch": 1.5, "fill_gaps": true,
			"boundary_clearance_override": true, "boundary_clearance": 0.8,
			"stagger_override": true, "stagger": 0.25, "seed": 7,
			"spine_inputs": [{"guide_id": "guide_2", "enabled": true}]}}
	document["seeding"]["bakes"][seeding_method] = {"seed_count": 33, "method": seeding_method,
		"flow_seed_count": 30, "gap_seed_count": 3}
	document["meshing"]["recipe"] = {"method": GeometryMeshingService.CONSTRAINED_MESH,
		"parameters": {"seeding_method": seeding_method, "mesh_character": 0.6,
			"optimize_mesh": true, "relaxation_override": true, "relaxation": 0.4,
			"passes_override": true, "passes": 3}}
	document["meshing"]["bakes"][GeometryMeshingService.CONSTRAINED_MESH] = {"vertex_count": 55,
		"triangle_count": 66, "minimum_angle": 24.5, "constraints_valid": true,
		"cut_seam_vertex_count": 4}


func _prepare_geometry_case(application: Control, case_name: String) -> String:
	application.active_module = "Mesh"
	application.selected_asset_id = "asset_1"
	application.selected_component_id = "component_1"
	application.selected_sampling_input_id = ""
	application.selected_sampling_input_kind = ""
	application.geometry_seeding_advanced_pattern_expanded = false
	application.geometry_meshing_advanced_relaxation_expanded = false
	_geometry_wiring_document(application, case_name == "seeding_spine")
	match case_name:
		"sampling":
			return "Sampling"
		"sampling_refined":
			# The Boundary Density block only exists while an input is selected,
			# and its factor field only while that input carries an override.
			application.selected_sampling_input_id = "guide_1"
			# _get_sampling_input knows "guide" and "component"; selecting a Cut
			# boundary row goes through _select_guide, which sets "guide".
			application.selected_sampling_input_kind = "guide"
			return "Sampling"
		"seeding_poisson":
			return "Seeding"
		"seeding_spine":
			application.geometry_seeding_advanced_pattern_expanded = true
			return "Seeding"
		"meshing":
			application.geometry_meshing_advanced_relaxation_expanded = true
			return "Meshing"
		"meshing_contour":
			application.selected_component_id = "component_9"
			return "Meshing"
	return "Sampling"


func _build_geometry_probe(application: Control, submodule: String) -> GeometryInspectorView:
	# A bare view fed the same contexts the router pushes, so the walk can fire
	# controls without the editor's handlers re-rendering them away.
	var probe := GeometryInspectorView.new()
	probe.set_submodule(submodule, application.world_contour_stroke_width_px)
	var component: Dictionary = WorldDocumentService.component_by_id(
		application._get_asset(application.selected_asset_id), application.selected_component_id)
	if submodule == "Sampling":
		probe.set_sampling_context(application._geometry_sampling_inspector_context(component))
	elif submodule == "Seeding":
		probe.set_seeding_context(application._geometry_seeding_inspector_context(component))
	elif submodule == "Meshing":
		probe.set_meshing_context(application._geometry_meshing_inspector_context(component))
	return probe


func _test_sampling_input_kind_from_seeding_selection() -> void:
	# The Seeding tree names its rows by treatment, the Sampling Inspector looks
	# an input up by what the document holds. Selecting a Seeding input and then
	# switching to Sampling is the path where the two vocabularies meet, so it is
	# driven here end to end: press the real row, switch submodule, render, and
	# look for the Boundary Density block.
	var body := _outliner_test_component("component_1", "body")
	body["topology_role"] = "outer"
	var hole := {"points": [], "edges": [], "chains": [], "id": "component_2", "name": "eye",
		"visibility": true, "type": "reference", "parent_component_id": "component_1",
		"topology_role": "hole", "source_asset_id": "asset_2"}
	var cut := {"id": "guide_1", "guide_type": AssetGuide.CUT, "ordinal": 1, "visibility": true,
		"scope": {"kind": "component", "component_id": "component_1"},
		"points": [], "edges": [], "chains": []}
	var spine := {"id": "guide_2", "guide_type": AssetGuide.SAMPLER_SPINE, "ordinal": 1,
		"visibility": true, "scope": {"kind": "component", "component_id": "component_1"},
		"points": [], "edges": [], "chains": []}
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	var kind_assets: Array[Dictionary] = [
		{"id": "asset_1", "name": "Wizard", "visibility": true, "components": [body, hole],
			"groups": [], "guides": [cut, spine]},
		{"id": "asset_2", "name": "Orb", "visibility": true, "components": [], "groups": [], "guides": []}]
	application.assets = kind_assets
	application.active_module = "Mesh"
	application.expanded_assets["asset_1"] = true
	application.selected_asset_id = "asset_1"
	application.selected_component_id = "component_1"
	var document: Dictionary = application._mutable_geometry_document("asset_1", "component_1")
	document["seeding"]["recipe"]["method"] = GeometrySeedingService.SPINE_FLOW
	document["seeding"]["recipe"]["parameters"]["spine_inputs"] = [{"guide_id": "guide_2", "enabled": true}]
	# A refinement on each Sampling boundary, so the block has something to show.
	document["sampling"]["recipe"]["parameters"]["boundary_refinements"] = {
		"component_2": {"factor": 2.0}, "guide_1": {"factor": 2.5}}

	# sampling_id empty means the row is no Sampling boundary; seeding_id is what
	# the Seeding tree and its Workspace highlight, which every row can be.
	for expectation in [
		{"row": "Outer · ", "sampling_id": "", "kind": "", "seeding_id": "", "block": false},
		{"row": "Hole · ", "sampling_id": "component_2", "kind": "component", "seeding_id": "component_2", "block": true},
		{"row": "Cut · ", "sampling_id": "guide_1", "kind": "guide", "seeding_id": "guide_1", "block": true},
		{"row": "Spine · ", "sampling_id": "", "kind": "", "seeding_id": "guide_2", "block": false},
	]:
		var row_name := str(expectation["row"])
		application.active_geometry_submodule = "Seeding"
		application._render_outliner()
		_expect(_press_outliner_button(application, row_name),
			"The Seeding tree should offer its %srow." % row_name)

		# The invariant: a resolvable id/kind pair, or both empty. Never one of
		# the two on its own.
		_expect(application.selected_sampling_input_id == str(expectation["sampling_id"])
			and application.selected_sampling_input_kind == str(expectation["kind"]),
			"Selecting the %srow should store the Sampling input (%s, %s), not (%s, %s)." % [
				row_name, str(expectation["sampling_id"]), str(expectation["kind"]),
				application.selected_sampling_input_id, application.selected_sampling_input_kind])
		_expect(application.selected_sampling_input_id.is_empty() == application.selected_sampling_input_kind.is_empty(),
			"The Sampling input id and kind should be set together or not at all, after the %srow." % row_name)
		if not application.selected_sampling_input_id.is_empty():
			_expect(not application._get_sampling_input(application._get_asset("asset_1"),
				"component_1", application.selected_sampling_input_id, application.selected_sampling_input_kind).is_empty(),
				"A stored Sampling input should resolve, after the %srow." % row_name)

		# The Seeding selection survives independently, which is what keeps the
		# Spine row and its stroke highlighted.
		_expect(application.selected_seeding_input_id == str(expectation["seeding_id"]),
			"Selecting the %srow should keep it as the Seeding selection (%s), not %s." % [
				row_name, str(expectation["seeding_id"]), application.selected_seeding_input_id])
		application._render_outliner()
		var highlighted := false
		for row_data in application.outliner_view.geometry_rows:
			if str(row_data.get("kind", "")) == "input" and bool(row_data.get("selected", false)):
				highlighted = str(row_data.get("target_id", "")) == str(expectation["seeding_id"])
		_expect(highlighted == not str(expectation["seeding_id"]).is_empty(),
			"The Seeding tree should mark the %srow selected exactly when it carries an input id." % row_name)
		_expect(application.geometry_seeding_workspace.selected_input_id == str(expectation["seeding_id"]),
			"The Seeding Workspace should highlight the same input as the tree, after the %srow." % row_name)

		application.active_geometry_submodule = "Sampling"
		application._render_inspector()
		var block := _button_starting_with(application.geometry_inspector_view, "▾  Boundary Density")
		if bool(expectation["block"]):
			_expect(block != null,
				"After selecting the %srow, Sampling should show its Boundary Density block." % row_name)
		else:
			_expect(block == null,
				"The %srow is not a Sampling boundary, so Sampling should show no Boundary Density block." % row_name)

	# The other way into the same state: selecting a Guide directly. A Cut is a
	# Sampling boundary, a Spine is not, and _select_guide does not distinguish
	# them on its own.
	application.active_geometry_submodule = "Sampling"
	application._select_guide("asset_1", "guide_1")
	_expect(application.selected_sampling_input_id == "guide_1"
		and application.selected_sampling_input_kind == "guide",
		"Selecting a Cut Guide should store it as the Sampling input.")
	application._select_guide("asset_1", "guide_2")
	_expect(application.selected_sampling_input_id.is_empty()
		and application.selected_sampling_input_kind.is_empty(),
		"Selecting a Spine Guide should store no Sampling input, since a Spine is not a Sampling boundary.")
	_expect(application.selected_guide_id == "guide_2",
		"Selecting a Spine Guide should still select the Guide itself.")
	application._render_inspector()
	_expect(_button_starting_with(application.geometry_inspector_view, "▾  Boundary Density") == null,
		"A selected Spine should not produce a Boundary Density block in Sampling.")
	application.selected_component_id = "component_1"
	application.selected_sampling_input_id = "component_2"
	application.selected_sampling_input_kind = "component"
	hole["visibility"] = false
	application._refresh_geometry_sampling_workspace()
	_expect(application.geometry_sampling_workspace.selected_input_id.is_empty(), "The Sampling Workspace must clear a selected Hole highlight as soon as that input becomes hidden.")
	hole["visibility"] = true
	application.selected_sampling_input_id = "guide_1"
	application.selected_sampling_input_kind = "guide"
	cut["scope"]["component_id"] = "other_component"
	application._refresh_geometry_sampling_workspace()
	_expect(application.geometry_sampling_workspace.selected_input_id.is_empty(), "The Sampling Workspace must clear a selected Cut highlight when the Guide no longer belongs to the selected Body.")
	cut["scope"]["component_id"] = "component_1"
	application.free()


const CREATE_SIGNAL_ROUTES := [
	["asset_authored_facing_selected", "_on_asset_authored_facing_selected"],
	["asset_pivot_property_changed", "_on_asset_pivot_property_changed"],
	["asset_rename_requested", "_rename_selected_asset"],
	["asset_root_position_changed", "_on_asset_root_position_changed"],
	["asset_root_scale_changed", "_on_asset_root_scale_changed"],
	["asset_root_scale_rebase_requested", "_on_rebase_asset_root_scale_pressed"],
	["asset_scales_rebase_requested", "_on_rebase_asset_scales_pressed"],
	["circle_primitive_diameter_changed", "_on_circle_primitive_diameter_changed"],
	["component_catch_parent_selected", "_on_component_catch_parent_selected"],
	["component_contour_stroke_width_changed", "_on_component_contour_stroke_width_changed"],
	["component_debug_point_numbers_toggled", "_on_component_debug_point_numbers_toggled"],
	["component_hierarchy_parent_selected", "_on_component_hierarchy_parent_selected"],
	["component_projection_depth_changed", "_on_component_projection_depth_changed"],
	["component_rename_requested", "_rename_selected_component"],
	["region_geometry_source_selected", "_on_region_geometry_source_selected"],
	["component_topology_role_selected", "_on_component_topology_role_selected"],
	["component_visibility_changed", "_on_component_visibility_changed"],
	["component_z_index_changed", "_on_component_z_index_changed"],
	["edge_render_outline_changed", "_on_edge_render_outline_changed"],
	["ellipse_primitive_diameter_changed", "_on_ellipse_primitive_diameter_changed"],
	["global_transform_value_changed", "_on_global_transform_value_changed"],
	["group_hierarchy_parent_selected", "_on_group_hierarchy_parent_selected"],
	["group_rename_requested", "_rename_selected_group"],
	["group_transform_value_changed", "_on_group_transform_value_changed"],
	["group_visibility_changed", "_on_group_visibility_changed"],
	["guide_delete_requested", "_delete_selected_guide"],
	["guide_type_selected", "_on_guide_type_selected"],
	["guide_visibility_changed", "_on_selected_guide_visibility_changed"],
	["multi_component_field_focus_exited", "_on_multi_component_field_focus_exited"],
	["multi_component_field_submitted", "_on_multi_component_field_submitted"],
	["multi_component_visibility_selected", "_on_multi_component_visibility_selected"],
	["point_position_changed", "_on_point_position_changed"],
	["reference_image_clear_requested", "_clear_reference_image"],
	["reference_image_load_requested", "_open_reference_image_dialog"],
	["reference_image_pivot_selected", "_on_reference_image_pivot_selected"],
	["reference_image_property_changed", "_on_reference_image_property_changed"],
	["reference_image_target_height_changed", "_on_reference_image_target_height_changed"],
	["reference_image_visibility_changed", "_on_reference_image_visibility_changed"],
	["section_toggled", "_on_inspector_section_toggled"],
	["selected_points_delta_changed", "_on_selected_points_delta_changed"],
	["selected_points_mode_selected", "_on_selected_points_mode_selected"],
	["selected_points_preserve_changed", "_on_selected_points_preserve_changed"],
	["transform_value_changed", "_on_transform_value_changed"],
	["weapon_frame_value_changed", "_on_weapon_frame_value_changed"],
]

const CREATE_PROBE_CASES := ["asset", "asset_reference", "component", "component_grouped",
	"component_contour", "primitive_circle", "primitive_hole", "primitive_ellipse", "group", "guide",
	"guide_weapon", "region_authored", "region_component", "multi_component", "point_none", "point_one", "point_many",
	"edge_none", "edge_one", "edge_many", "hole_edge_one", "hole_edge_many", "face"]


func _create_wiring_asset() -> Dictionary:
	# One Asset carrying every Create row: a plain Component, a child, a Contour,
	# a circle and an ellipse primitive, a Group, a plain Guide and a weapon
	# frame Guide.
	var body := _outliner_test_component("component_1", "body")
	body["transform"] = {"position": Vector2(3.0, 4.0), "rotation": 15.0,
		"scale": Vector2(1.5, 2.0), "pivot": Vector2(1.0, 1.0)}
	var arm := _outliner_test_component("component_2", "arm")
	arm["parent_component_id"] = "component_1"
	var outline := _outliner_test_component("component_3", "outline")
	outline["draw_mode"] = "contour"
	var circle := _outliner_test_component("component_4", "orb")
	circle["draw_mode"] = "primitive"
	circle["primitive"] = {"type": "circle", "diameter_cm": 4.0}
	var hole := _outliner_test_component("component_8", "opening")
	hole["draw_mode"] = "primitive"
	hole["primitive"] = {"type": "circle", "diameter_cm": 2.0}
	hole["parent_component_id"] = "component_1"
	hole["topology_role"] = "hole"
	var bezier_hole := _outliner_test_component("component_9", "opening_curve")
	bezier_hole["parent_component_id"] = "component_1"
	bezier_hole["topology_role"] = "hole"
	for chain in bezier_hole.get("chains", []):
		chain["topology_role"] = "hole"
	var ellipse := _outliner_test_component("component_5", "egg")
	ellipse["draw_mode"] = "primitive"
	ellipse["primitive"] = {"type": PrimitiveGeometryService.ELLIPSE,
		"diameter_x_cm": 3.0, "diameter_y_cm": 5.0}
	var guide := {"id": "guide_1", "guide_type": AssetGuide.SAMPLE, "ordinal": 1,
		"visibility": true, "scope": {"kind": "component", "component_id": "component_1"},
		"points": [], "edges": [], "chains": []}
	var weapon := {"id": "guide_2", "guide_type": AssetGuide.WEAPON_TYPES[0], "ordinal": 1,
		"visibility": true, "scope": {"kind": "component", "component_id": "component_1"},
		"points": [], "edges": [], "chains": []}
	var group := {"id": "group_1", "name": "torso", "transform": {}, "visibility": true,
		"parent_component_id": ""}
	var authored_region := _outliner_test_component("component_6", "attack_region")
	authored_region.merge({"type": "region", "region_type": "attack", "parent_component_id": "component_1", "region_geometry_source": "authored"}, true)
	var inherited_region := authored_region.duplicate(true)
	inherited_region.merge({"id": "component_7", "name": "hurt_region", "region_type": "hurt", "region_geometry_source": "component"}, true)
	return {"id": "asset_1", "name": "Wizard", "visibility": true,
		"components": [body, arm, outline, circle, ellipse, authored_region, inherited_region, hole, bezier_hole], "groups": [group],
		"guides": [guide, weapon], "asset_pivot": Vector2(5.0, 6.0),
		"root_position": Vector2.ZERO, "root_scale": Vector2.ONE}


func _prepare_create_case(application: Control, case_name: String) -> void:
	var asset: Dictionary = application.assets[0]
	application.active_module = "Create"
	application.selected_asset_id = "asset_1"
	application.selected_component_id = ""
	application.selected_group_id = ""
	application.selected_guide_id = ""
	application.selected_edge_id = ""
	application.selected_edge_ids = [] as Array[String]
	application.selected_point_id = ""
	application.selected_point_ids = [] as Array[String]
	application.selected_component_ids = [] as Array[String]
	application.active_state = ""
	application.active_edit_mode = ""
	asset.erase("reference_image")
	var body: Dictionary = WorldDocumentService.component_by_id(asset, "component_1")
	body.erase("group_id")
	var point_ids: Array[String] = []
	for point in body["points"]:
		point_ids.append(str(point["id"]))
	var edge_ids: Array[String] = []
	for edge in body["edges"]:
		edge_ids.append(str(edge["id"]))
	match case_name:
		"asset":
			pass
		"asset_reference":
			asset["reference_image"] = {"file": "res://ref.png", "target_height_cm": 21.5,
				"pivot_mode": "center", "visible": true, "opacity": 0.35,
				"position": Vector2(2.5, -3.5), "scale": 1.25}
		"component":
			application.selected_component_id = "component_1"
		"component_grouped":
			application.selected_component_id = "component_1"
			body["group_id"] = "group_1"
		"component_contour":
			application.selected_component_id = "component_3"
		"primitive_circle":
			application.selected_component_id = "component_4"
		"primitive_hole":
			application.selected_component_id = "component_8"
		"primitive_ellipse":
			application.selected_component_id = "component_5"
		"group":
			application.selected_group_id = "group_1"
		"guide":
			application.selected_guide_id = "guide_1"
		"guide_weapon":
			application.selected_guide_id = "guide_2"
		"region_authored":
			application.selected_component_id = "component_6"
		"region_component":
			application.selected_component_id = "component_7"
		"multi_component":
			var many: Array[String] = ["component_1", "component_2"]
			application.selected_component_ids = many
			application.selected_component_id = "component_1"
		"point_none", "point_one", "point_many":
			application.selected_component_id = "component_1"
			application.active_state = "edit"
			application.active_edit_mode = "point"
			var chosen: Array[String] = []
			if case_name == "point_one":
				chosen.append(point_ids[0])
			elif case_name == "point_many":
				chosen.append(point_ids[0])
				chosen.append(point_ids[1])
			application.selected_point_ids = chosen
			application.selected_point_id = chosen[0] if not chosen.is_empty() else ""
		"edge_none", "edge_many":
			application.selected_component_id = "component_1"
			application.active_state = "edit"
			application.active_edit_mode = "edge"
			var chosen_edges: Array[String] = []
			if case_name == "edge_many":
				chosen_edges.append(edge_ids[0])
				chosen_edges.append(edge_ids[1])
			application.selected_edge_ids = chosen_edges
		"edge_one":
			# Not the edit mode: a single Edge selected outside it takes its own
			# branch further down rebuild().
			application.selected_component_id = "component_1"
			application.selected_edge_id = edge_ids[0]
		"hole_edge_one", "hole_edge_many":
			var bezier_hole: Dictionary = WorldDocumentService.component_by_id(asset, "component_9")
			var hole_edge_ids: Array[String] = []
			for edge in bezier_hole.get("edges", []):
				hole_edge_ids.append(str(edge.get("id", "")))
			application.selected_component_id = "component_9"
			if case_name == "hole_edge_one":
				application.selected_edge_id = hole_edge_ids[0]
			else:
				application.active_state = "edit"
				application.active_edit_mode = "edge"
				application.selected_edge_ids = [hole_edge_ids[0], hole_edge_ids[1]] as Array[String]
		"face":
			application.selected_component_id = "component_1"
			application.active_state = "edit"
			application.active_edit_mode = "face"


func _build_create_probe(application: Control) -> CreateInspectorView:
	# A bare view fed exactly what the router pushes, so the walk can fire
	# controls without the editor's handlers re-rendering them away.
	var probe := CreateInspectorView.new()
	var asset: Dictionary = application._get_asset(application.selected_asset_id)
	probe.set_document(asset, application.world_contour_stroke_width_px)
	probe.set_selection(application.selected_component_id, application.selected_group_id,
		application.selected_guide_id, application.selected_edge_id,
		application.selected_edge_ids.duplicate())
	probe.set_resolved_selection(application._selected_components_for_inspector(asset),
		application._valid_selected_point_ids(
			WorldDocumentService.component_by_id(asset, application.selected_component_id)))
	probe.set_mode(application.active_state, application.active_edit_mode,
		application.canvas_view.face_selected)
	return probe


func _test_create_inspector_wiring() -> void:
	# The two tables the other views carry, for the Create Inspector. The routing
	# half checks that each of the 43 signals reaches the handler it names; the
	# emission half renders eighteen Create states, fires every control the view
	# builds, and checks that each signal is reachable and arrives with its
	# declared argument types.
	var create_assets: Array[Dictionary] = [_create_wiring_asset()]
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	application.assets = create_assets
	var view: CreateInspectorView = application.create_inspector_view

	var routed: Array[String] = []
	for route in CREATE_SIGNAL_ROUTES:
		var signal_name := str(route[0])
		var expected_handler := str(route[1])
		routed.append(signal_name)
		var handlers: Array[String] = []
		for connection in view.get_signal_connection_list(signal_name):
			handlers.append(str((connection["callable"] as Callable).get_method()))
		_expect(handlers.size() == 1 and handlers[0] == expected_handler,
			"The Create Inspector signal %s should reach %s, not %s." % [signal_name, expected_handler, str(handlers)])
	var declared_arguments: Dictionary = {}
	for entry in view.get_script().get_script_signal_list():
		var declared := str(entry["name"])
		declared_arguments[declared] = entry["args"]
		if declared in routed:
			continue
		_expect(false, "The Create Inspector declares %s, which is missing from the routing table." % declared)

	view_signals_emitted = {}
	view_signal_argument_failures = [] as Array[String]
	for case_name in CREATE_PROBE_CASES:
		_prepare_create_case(application, case_name)
		var probe := _build_create_probe(application)
		for route in CREATE_SIGNAL_ROUTES:
			var signal_name := str(route[0])
			probe.connect(signal_name, _view_signal_recorder(signal_name, declared_arguments.get(signal_name, [])))
		probe.rebuild()
		var controls: Array = []
		_inspector_controls(probe, controls)
		for control in controls:
			_exercise_control(control)
		probe.free()
	var unreachable: Array[String] = []
	for route in CREATE_SIGNAL_ROUTES:
		if not view_signals_emitted.has(str(route[0])):
			unreachable.append(str(route[0]))
	_expect(unreachable.is_empty(),
		"Every Create Inspector signal should be reachable from a control; unreachable: %s" % str(unreachable))
	_expect(view_signal_argument_failures.is_empty(),
		"Create Inspector signals should arrive with their declared argument types; %s" % str(view_signal_argument_failures))
	application.free()


const STYLE_SIGNAL_ROUTES := [
	["bake_requested", "_bake_weighting_preview"],
	["curve_selected", "_on_weighting_curve_selected"],
	["direction_selected", "_on_weighting_direction_selected"],
	["invert_changed", "_on_weighting_invert_changed"],
	["method_selected", "_on_weighting_method_selected"],
	["preview_requested", "_generate_weighting_preview"],
	["section_toggled", "_on_inspector_section_toggled"],
	["strength_changed", "_on_weighting_strength_changed"],
	["style_delete_requested", "_delete_selected_weighting_style"],
	["style_rename_requested", "_rename_weighting_style"],
]

const STYLE_PROBE_CASES := ["no_component", "no_style", "uniform", "gradient",
	"gradient_previewed", "gradient_baked"]


func _weighting_wiring_document(application: Control) -> void:
	# A Component Mesh that really is Ready: the Sampling, Seeding and Meshing
	# bakes come from the services, and component_mesh carries the fingerprint
	# _component_mesh_status compares against. Without that the Inspector never
	# leaves "Missing" and the Result block is never drawn.
	var component: Dictionary = application.assets[0]["components"][0]
	var sampling: Dictionary = GeometrySamplingService.generate(component,
		{"method": GeometrySamplingService.ADAPTIVE, "parameters": {"spacing": 2.0}})
	sampling["bake_id"] = "sampling_style"
	var seeding: Dictionary = GeometrySeedingService.generate(sampling,
		{"method": GeometrySeedingService.POISSON_FILL, "parameters": {"spacing": 2.5, "seed": 5}})
	seeding["bake_id"] = "seeding_style"
	var mesh: Dictionary = GeometryMeshingService.generate(sampling, seeding,
		{"method": GeometryMeshingService.CONSTRAINED_MESH,
			"parameters": {"seeding_method": GeometrySeedingService.POISSON_FILL}})
	mesh["bake_id"] = "mesh_style"
	var document: Dictionary = application._mutable_geometry_document("asset_1", "component_1")
	document["sampling"]["recipe"] = {"method": GeometrySamplingService.ADAPTIVE,
		"parameters": {"spacing": 2.0}}
	document["sampling"]["bakes"][GeometrySamplingService.ADAPTIVE] = sampling
	document["seeding"]["recipe"] = {"method": GeometrySeedingService.POISSON_FILL,
		"parameters": {"spacing": 2.5, "seed": 5}}
	document["seeding"]["bakes"][GeometrySeedingService.POISSON_FILL] = seeding
	document["meshing"]["recipe"] = {"method": GeometryMeshingService.CONSTRAINED_MESH,
		"parameters": {"seeding_method": GeometrySeedingService.POISSON_FILL}}
	document["meshing"]["bakes"][GeometryMeshingService.CONSTRAINED_MESH] = mesh
	document["component_mesh"] = {"bake_id": "mesh_style",
		"method": GeometryMeshingService.CONSTRAINED_MESH,
		"mesh_fingerprint": GeometryUVMappingService.mesh_fingerprint(mesh)}


func _style_wiring_asset() -> Dictionary:
	# A closed Component the meshing services can actually bake.
	var body := _component()
	body.merge({"id": "component_1", "name": "body", "visibility": true})
	for position in [Vector2.ZERO, Vector2(10.0, 0.0), Vector2(10.0, 10.0), Vector2(0.0, 10.0)]:
		BezierTopology.add_point(body, position, "linear")
	BezierTopology.close_active_chain(body)
	return {"id": "asset_1", "name": "Wizard", "visibility": true,
		"components": [body], "groups": [], "guides": []}


func _prepare_style_case(application: Control, case_name: String) -> void:
	application.active_module = "Style"
	application.active_style_submodule = "Weighting"
	application.selected_asset_id = "asset_1"
	application.selected_component_id = "component_1"
	application.selected_weighting_style_id = ""
	application.weighting_preview = {}
	application.weighting_preview_key = ""
	var document: Dictionary = application._mutable_geometry_document("asset_1", "component_1")
	document["weighting"]["styles"] = []
	if case_name == "no_component":
		application.selected_component_id = ""
		return
	if case_name == "no_style":
		return
	var style: Dictionary = WeightingService.default_style("style_1", "Weighting Style 01", "component_1")
	if case_name != "uniform":
		style["method"] = WeightingService.AXIS_GRADIENT
		style["parameters"] = WeightingService.default_parameters(WeightingService.AXIS_GRADIENT)
	document["weighting"]["styles"].append(style)
	application.selected_weighting_style_id = "style_1"
	if case_name == "gradient_previewed":
		# Result rows and an enabled Bake button only exist once a preview that
		# matches the Component Mesh has been generated.
		application._generate_weighting_preview()
	elif case_name == "gradient_baked":
		application._generate_weighting_preview()
		application._bake_weighting_preview()


func _build_style_probe(application: Control) -> StyleInspectorView:
	# A bare view fed exactly what the router pushes, so the walk can fire
	# controls without the editor's handlers re-rendering them away.
	var probe := StyleInspectorView.new()
	probe.set_context(application._weighting_inspector_context())
	return probe


func _test_style_inspector_wiring() -> void:
	# The two tables the other four views carry, for the Style Inspector. The
	# routing half checks that each of the ten signals reaches the handler it
	# names and that the view declares nothing the table misses; the emission
	# half renders six Weighting states, fires every control the view builds,
	# and checks that each signal is reachable and arrives with its declared
	# argument types.
	var style_assets: Array[Dictionary] = [_style_wiring_asset()]
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	application.assets = style_assets
	_weighting_wiring_document(application)
	var view: StyleInspectorView = application.style_inspector_view

	var routed: Array[String] = []
	for route in STYLE_SIGNAL_ROUTES:
		var signal_name := str(route[0])
		var expected_handler := str(route[1])
		routed.append(signal_name)
		var handlers: Array[String] = []
		for connection in view.get_signal_connection_list(signal_name):
			handlers.append(str((connection["callable"] as Callable).get_method()))
		_expect(handlers.size() == 1 and handlers[0] == expected_handler,
			"The Style Inspector signal %s should reach %s, not %s." % [signal_name, expected_handler, str(handlers)])
	var declared_arguments: Dictionary = {}
	for entry in view.get_script().get_script_signal_list():
		var declared := str(entry["name"])
		declared_arguments[declared] = entry["args"]
		if declared in routed:
			continue
		_expect(false, "The Style Inspector declares %s, which is missing from the routing table." % declared)

	# The Component Mesh has to be Ready for the states below to differ at all.
	application.selected_asset_id = "asset_1"
	application.selected_component_id = "component_1"
	_expect(application._component_mesh_status("asset_1", "component_1",
		application.assets[0]["components"][0]) == "Ready",
		"The Weighting wiring fixture should present a Ready Component Mesh.")

	view_signals_emitted = {}
	view_signal_argument_failures = [] as Array[String]
	for case_name in STYLE_PROBE_CASES:
		_prepare_style_case(application, case_name)
		var probe := _build_style_probe(application)
		for route in STYLE_SIGNAL_ROUTES:
			var signal_name := str(route[0])
			probe.connect(signal_name, _view_signal_recorder(signal_name, declared_arguments.get(signal_name, [])))
		probe.rebuild()
		var controls: Array = []
		_inspector_controls(probe, controls)
		for control in controls:
			_exercise_control(control)
		probe.free()
	var unreachable: Array[String] = []
	for route in STYLE_SIGNAL_ROUTES:
		if not view_signals_emitted.has(str(route[0])):
			unreachable.append(str(route[0]))
	_expect(unreachable.is_empty(),
		"Every Style Inspector signal should be reachable from a control; unreachable: %s" % str(unreachable))
	_expect(view_signal_argument_failures.is_empty(),
		"Style Inspector signals should arrive with their declared argument types; %s" % str(view_signal_argument_failures))
	application.free()


func _test_geometry_inspector_wiring() -> void:
	# The two tables the Motion Inspector and the Outliner carry, for the Mesh
	# Inspector. The routing half checks that each signal reaches the handler it
	# names; the emission half renders six Mesh states, fires every control the
	# view builds, and checks that each signal is reachable and arrives with its
	# declared argument types.
	var geometry_assets: Array[Dictionary] = [_geometry_wiring_asset(),
		{"id": "asset_2", "name": "Orb", "visibility": true,
			"components": [], "groups": [], "guides": []}]
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	application.assets = geometry_assets
	var view: GeometryInspectorView = application.geometry_inspector_view

	var routed: Array[String] = []
	for route in GEOMETRY_SIGNAL_ROUTES:
		var signal_name := str(route[0])
		var expected_handler := str(route[1])
		routed.append(signal_name)
		var handlers: Array[String] = []
		for connection in view.get_signal_connection_list(signal_name):
			handlers.append(str((connection["callable"] as Callable).get_method()))
		_expect(handlers.size() == 1 and handlers[0] == expected_handler,
			"The Mesh Inspector signal %s should reach %s, not %s." % [signal_name, expected_handler, str(handlers)])
	for signal_name in GEOMETRY_ADAPTER_SIGNALS:
		var connections: Array = view.get_signal_connection_list(str(signal_name))
		_expect(connections.size() == 1 and (connections[0]["callable"] as Callable).is_custom(),
			"The Mesh Inspector signal %s should be wired through exactly one adapter lambda." % signal_name)
	var declared_arguments: Dictionary = {}
	for entry in view.get_script().get_script_signal_list():
		var declared := str(entry["name"])
		declared_arguments[declared] = entry["args"]
		if declared in routed or declared in GEOMETRY_ADAPTER_SIGNALS:
			continue
		_expect(false, "The Mesh Inspector declares %s, which is in neither the routing table nor the adapter list." % declared)

	# What the two adapters do, since the table cannot name their target.
	application.active_module = "Mesh"
	application.active_geometry_submodule = "Sampling"
	application.selected_asset_id = "asset_1"
	application.selected_component_id = "component_1"
	application.selected_sampling_input_id = ""
	view.sampling_hole_selected.emit("component_3")
	_expect(application.selected_sampling_input_id == "component_3"
		and application.selected_sampling_input_kind == "component",
		"The Hole boundary row should select that Component as the Sampling input.")
	view.sampling_cut_selected.emit("guide_1")
	_expect(application.selected_guide_id == "guide_1",
		"The Cut boundary row should select that Guide.")

	view_signals_emitted = {}
	view_signal_argument_failures = [] as Array[String]
	for case_name in GEOMETRY_PROBE_CASES:
		var submodule := _prepare_geometry_case(application, case_name)
		var probe := _build_geometry_probe(application, submodule)
		for route in GEOMETRY_SIGNAL_ROUTES:
			var signal_name := str(route[0])
			probe.connect(signal_name, _view_signal_recorder(signal_name, declared_arguments.get(signal_name, [])))
		for signal_name in GEOMETRY_ADAPTER_SIGNALS:
			probe.connect(str(signal_name), _view_signal_recorder(str(signal_name), declared_arguments.get(str(signal_name), [])))
		probe.rebuild()
		var controls: Array = []
		_inspector_controls(probe, controls)
		for control in controls:
			_exercise_control(control)
		probe.free()
	var unreachable: Array[String] = []
	for signal_name in routed + GEOMETRY_ADAPTER_SIGNALS:
		if not view_signals_emitted.has(str(signal_name)):
			unreachable.append(str(signal_name))
	_expect(unreachable.is_empty(),
		"Every Mesh Inspector signal should be reachable from a control; unreachable: %s" % str(unreachable))
	_expect(view_signal_argument_failures.is_empty(),
		"Mesh Inspector signals should arrive with their declared argument types; %s" % str(view_signal_argument_failures))
	application.free()


func _test_outliner_wiring() -> void:
	# The same two tables the Motion Inspector carries, for the view that was
	# extracted before the render comparison existed and has had the least
	# verification of the five. The routing half checks that each connected
	# signal reaches the handler it names; the emission half renders ten Outliner
	# states, fires every row the view builds, and checks that each signal is
	# reachable and arrives with its declared argument types.
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	application.assets = _outliner_wiring_assets()
	var view: OutlinerView = application.outliner_view

	for route in OUTLINER_SIGNAL_ROUTES:
		var signal_name := str(route[0])
		var expected_handler := str(route[1])
		var handlers: Array[String] = []
		for connection in view.get_signal_connection_list(signal_name):
			handlers.append(str((connection["callable"] as Callable).get_method()))
		_expect(handlers.size() == 1 and handlers[0] == expected_handler,
			"The Outliner signal %s should reach %s, not %s." % [signal_name, expected_handler, str(handlers)])
	for signal_name in OUTLINER_UNCONNECTED_SIGNALS:
		_expect(view.get_signal_connection_list(str(signal_name)).is_empty(),
			"The Outliner signal %s is documented as unconnected; connecting it should update that list." % signal_name)
	var routed: Array[String] = []
	for route in OUTLINER_SIGNAL_ROUTES:
		routed.append(str(route[0]))
	# The script's own signals only. get_signal_list() also reports what Control
	# and Node bring with them, and those carry engine-internal connections.
	var declared_arguments: Dictionary = {}
	for entry in view.get_script().get_script_signal_list():
		var declared := str(entry["name"])
		declared_arguments[declared] = entry["args"]
		if declared in routed or declared in OUTLINER_UNCONNECTED_SIGNALS:
			continue
		_expect(false, "The Outliner declares %s, which is in neither the routing table nor the unconnected list." % declared)
	view_signals_emitted = {}
	view_signal_argument_failures = [] as Array[String]
	for case_name in OUTLINER_PROBE_CASES:
		_prepare_outliner_case(application, case_name)
		var probe := _build_outliner_probe(application)
		for route in OUTLINER_SIGNAL_ROUTES:
			var signal_name := str(route[0])
			probe.connect(signal_name, _view_signal_recorder(signal_name, declared_arguments.get(signal_name, [])))
		probe.rebuild()
		var controls: Array = []
		_inspector_controls(probe, controls)
		for control in controls:
			_exercise_outliner_control(control)
		probe.free()
	var unreachable: Array[String] = []
	for route in OUTLINER_SIGNAL_ROUTES:
		var signal_name := str(route[0])
		if signal_name in OUTLINER_UNDRIVABLE_SIGNALS:
			_expect(not view_signals_emitted.has(signal_name),
				"%s is listed as undrivable but the walk reached it; move it out of that list." % signal_name)
			continue
		if not view_signals_emitted.has(signal_name):
			unreachable.append(signal_name)
	_expect(unreachable.is_empty(),
		"Every connected Outliner signal should be reachable from a row; unreachable: %s" % str(unreachable))
	_expect(view_signal_argument_failures.is_empty(),
		"Outliner signals should arrive with their declared argument types; %s" % str(view_signal_argument_failures))
	application.free()


func _test_motion_inspector_wiring() -> void:
	# Two tables, two halves of one question. The render comparison in
	# tools/inspector_render_probe.gd proves the Motion Inspector still draws the
	# same controls; it says nothing about where those controls lead. The routing
	# half checks that each of the fifty signals reaches the handler it names.
	# The emission half drives every control the view builds across eleven Motion
	# states and checks that each of those fifty is actually reachable from one,
	# and arrives with the argument types its signature declares.
	var body := _outliner_test_component("component_1", "body")
	var motion_assets: Array[Dictionary] = [{"id": "asset_1", "name": "Wizard", "visibility": true,
		"components": [body], "groups": [], "guides": []}]
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	application.assets = motion_assets
	application.active_module = "Motion"
	var view: MotionInspectorView = application.motion_inspector_view

	for route in MOTION_SIGNAL_ROUTES:
		var signal_name := str(route[0])
		var expected_handler := str(route[1])
		var handlers: Array[String] = []
		for connection in view.get_signal_connection_list(signal_name):
			handlers.append(str((connection["callable"] as Callable).get_method()))
		_expect(handlers.size() == 1 and handlers[0] == expected_handler,
			"The Motion Inspector signal %s should reach %s, not %s." % [signal_name, expected_handler, str(handlers)])

	var declared_arguments: Dictionary = {}
	for entry in view.get_signal_list():
		declared_arguments[str(entry["name"])] = entry["args"]
	view_signals_emitted = {}
	view_signal_argument_failures = [] as Array[String]
	for case_name in MOTION_PROBE_CASES:
		var submodule := _prepare_motion_case(application, case_name)
		application.active_motion_submodule = submodule
		# A bare view, so the editor's own handlers cannot re-render the controls
		# out from under the walk.
		var probe := MotionInspectorView.new()
		for route in MOTION_SIGNAL_ROUTES:
			var signal_name := str(route[0])
			probe.connect(signal_name, _view_signal_recorder(signal_name, declared_arguments.get(signal_name, [])))
		probe.set_models(application.motion_workspace, application.motion_player, application.motion_selection)
		probe.set_context(application._motion_inspector_context())
		probe.rebuild()
		var controls: Array = []
		_inspector_controls(probe, controls)
		for control in controls:
			_exercise_control(control)
		probe.free()
	var unreachable: Array[String] = []
	for route in MOTION_SIGNAL_ROUTES:
		if not view_signals_emitted.has(str(route[0])):
			unreachable.append(str(route[0]))
	_expect(unreachable.is_empty(),
		"Every Motion Inspector signal should be reachable from a control; unreachable: %s" % str(unreachable))
	_expect(view_signal_argument_failures.is_empty(),
		"Motion Inspector signals should arrive with their declared argument types; %s" % str(view_signal_argument_failures))
	application.free()


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
	var normalized: Dictionary = WorldDocumentService.normalize_motion_act({"id": "act_7", "parameters": {"direction": [0.0, 2.0], "distance": 12.0}}, "fallback")
	_expect(Vector2(normalized.get("parameters", {}).get("direction", Vector2.ZERO)) == Vector2(0.0, 2.0), "Persisted Slide direction arrays should normalize back to Vector2 values.")
	var serialized: Dictionary = WorldDocumentService.serialize_motion_act(normalized)
	_expect(serialized.get("parameters", {}).get("direction", null) is Array and int(serialized.get("schema_version", 0)) == 62, "Act persistence should serialize vectors as JSON arrays using schema 62.")
	var normalized_jump: Dictionary = WorldDocumentService.normalize_motion_act({"id": "act_8", "primitive": "jump", "parameters": {"direction": [1.0, 0.0], "distance": 7.0, "height": 2.5, "arc": "snappy"}}, "fallback")
	var serialized_jump: Dictionary = WorldDocumentService.serialize_motion_act(normalized_jump)
	_expect(str(serialized_jump.get("primitive", "")) == MotionActEvaluator.JUMP and is_equal_approx(float(serialized_jump.get("parameters", {}).get("height", 0.0)), 2.5) and str(serialized_jump.get("parameters", {}).get("arc", "")) == MotionActEvaluator.JUMP_ARC_SNAPPY, "Jump-specific parameters should survive normalization and serialization.")
	var normalized_blink: Dictionary = WorldDocumentService.normalize_motion_act({"id": "act_9", "primitive": "blink", "parameters": {"direction": [1.0, 0.0], "distance": 11.0, "anticipation_distance": 1.5, "anticipation_share": 0.22, "minimum_scale": 0.08}}, "fallback")
	var serialized_blink: Dictionary = WorldDocumentService.serialize_motion_act(normalized_blink)
	_expect(str(serialized_blink.get("primitive", "")) == MotionActEvaluator.BLINK and is_equal_approx(float(serialized_blink.get("parameters", {}).get("anticipation_distance", 0.0)), 1.5) and is_equal_approx(float(serialized_blink.get("parameters", {}).get("minimum_scale", 0.0)), 0.08), "Blink-specific anticipation and scale parameters should survive normalization and serialization.")
	var migrated_blink: Dictionary = WorldDocumentService.normalize_motion_act({"schema_version": 18, "id": "act_10", "primitive": "blink", "parameters": {"direction": [1.0, 0.0], "distance": 6.0, "anticipation_distance": 1.0, "anticipation_share": 0.18, "minimum_scale": 0.05}}, "fallback")
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
	create_section.setup("Create", ["Character", "Props", "Weapons", "Terrain", "Items", "Icon", "Symbols"], true)
	var create_separator_count := 0
	for child in create_section.content_list.get_children():
		if child is ColorRect:
			create_separator_count += 1
	_expect(create_separator_count == 0 and create_section.content_list.get_child_count() == 7, "Create should contain Character, Props, Weapons, Terrain, Items, Icon, and Symbols.")
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
