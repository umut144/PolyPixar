# Bézier topology, handles, snapping, Contour Stroke and region meshes,
# Scale Rebase and the Component hierarchy model.
extends "res://tests/test_case.gd"


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


func _test_mirror_axis_orientation_commands() -> void:
	var canvas := ComponentCanvas.new()
	canvas.size = Vector2(400.0, 400.0)
	canvas.set_camera_state(Vector2.ZERO, 20.0)
	canvas.set_component_transform({"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO})
	canvas.snap_enabled = false
	_expect(not canvas.start_mirror_command(ComponentCanvas.MIRROR_AXIS_VERTICAL), "The Mirror command must not start without a Point selection.")
	var source := _component()
	source["draw_mode"] = "closed_loop"
	var source_ids: Array[String] = []
	for point_position in [Vector2(0.0, 0.0), Vector2(-1.0, 1.0), Vector2(0.0, 4.0)]:
		source_ids.append(BezierTopology.add_point(source, point_position, "linear"))
	canvas.set_bezier_geometry(source.get("points", []), source.get("edges", []), source.get("chains", []))
	canvas.set_selected_point_ids(source_ids)
	_expect(canvas.selected_point_ids.size() == source_ids.size(), "The Mirror axis test needs the authored source run selected on the Canvas.")
	var reported_stages: Array = []
	canvas.mirror_axis_stage_changed.connect(func(stage: String) -> void: reported_stages.append(stage))
	var confirmed_directions: Array = []
	canvas.mirror_axis_confirmed.connect(func(axis_start: Vector2, axis_end: Vector2) -> void: confirmed_directions.append(axis_end - axis_start))
	_expect(not canvas.start_mirror_command("diagonal"), "An unknown axis orientation must not start the Mirror command.")
	_expect(canvas.start_mirror_command(ComponentCanvas.MIRROR_AXIS_VERTICAL) and reported_stages == ["axis"], "Mirror Y should enter one axis stage because its orientation is already fixed.")
	canvas._set_mirror_axis_from_screen(Vector2(240.0, 160.0))
	_expect((canvas.mirror_axis_end - canvas.mirror_axis_start).is_equal_approx(Vector2(0.0, 1.0)), "Mirror Y must derive a vertical axis from the single placed axis position.")
	canvas._confirm_mirror_axis()
	_expect(confirmed_directions.size() == 1 and confirmed_directions[0].is_equal_approx(Vector2(0.0, 1.0)) and canvas.mirror_command_stage.is_empty(), "Confirming Mirror Y should emit the vertical axis once and end the command.")
	_expect(canvas.start_mirror_command(ComponentCanvas.MIRROR_AXIS_HORIZONTAL), "Mirror X should start from the same selection state as Mirror Y.")
	canvas._set_mirror_axis_from_screen(Vector2(240.0, 160.0))
	_expect((canvas.mirror_axis_end - canvas.mirror_axis_start).is_equal_approx(Vector2(1.0, 0.0)), "Mirror X must derive a horizontal axis from the single placed axis position.")
	var axis_endpoints := canvas._mirror_axis_screen_endpoints()
	_expect(axis_endpoints.size() == 2 and is_equal_approx(axis_endpoints[0].y, axis_endpoints[1].y) and axis_endpoints[0].x < 0.0 and axis_endpoints[1].x > canvas.size.x, "A fixed Mirror axis must be drawn past both visible Canvas borders.")
	canvas.cancel_mirror_command(false)
	_expect(canvas.mirror_command_stage.is_empty() and not canvas.mirror_axis_candidate_visible, "Cancelling the Mirror command must clear its axis candidate.")
	canvas.free()


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
	_expect(bool(export_result.get("valid", false)) and int(export_result.get("manifest", {}).get("schema_version", 0)) == RuntimeExportService.MANIFEST_SCHEMA_VERSION and str(exported_region.get("role", "")) == "closed_contour_region" and not exported_region.get("indices", []).is_empty(), "The current schema must export a non-empty closed_region_mesh for a valid closed Contour.")
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


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var delta := end - start
	if delta.length_squared() <= 0.000000000001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return point.distance_to(start + delta * t)


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
	child["group_id"] = "group_face"
	var parent_world_before_canonicalization := ComponentHierarchy.world_transform(asset, "component_parent")
	var child_world_before_canonicalization := ComponentHierarchy.world_transform(asset, "component_child")
	ComponentHierarchy.normalize_asset(asset)
	_expect(str(child.get("group_id", "")) == "" and ComponentHierarchy.membership_group_id(asset, "component_child") == "group_face", "A Child should inherit its Parent's effective Group membership instead of storing the same Group ID redundantly.")
	_expect(ComponentHierarchy.world_transform(asset, "component_parent").is_equal_approx(parent_world_before_canonicalization) and ComponentHierarchy.world_transform(asset, "component_child").is_equal_approx(child_world_before_canonicalization), "Canonicalizing redundant Child Group membership must preserve the Parent and Child world transforms.")
	var independent_group := {"id": "group_independent", "name": "independent", "visibility": true, "parent_component_id": "", "transform": WorldDocumentService.default_component_transform()}
	asset["groups"].append(independent_group)
	child["group_id"] = "group_independent"
	ComponentHierarchy.normalize_asset(asset)
	_expect(str(child.get("group_id", "")) == "group_independent", "Canonicalization must retain a Child's explicit membership when it differs from its Parent's effective Group.")
	child["group_id"] = ""
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
