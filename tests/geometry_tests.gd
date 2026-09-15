# The derived Mesh pipeline: Sampling, Seeding, Meshing, automatic builds,
# the Legacy UV and SDF records, and Weighting.
extends "res://tests/test_case.gd"


func _context_menu(application: Control, prefix: String) -> MenuButton:
	for child in application.context_bar.get_children():
		if child is MenuButton and str(child.text).begins_with(prefix):
			return child
	return null


func _inspector_label_starting_with(application: Control, prefix: String) -> Label:
	var controls: Array = []
	_inspector_controls(application.inspector_content, controls)
	for control in controls:
		if control is Label and str(control.text).begins_with(prefix):
			return control
	return null


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
	_expect(application._mesh_update_candidates("direct_hole_asset").has("direct_hole") and int(application._geometry_asset_mesh_overview("direct_hole_asset").get("visible_component_count", 0)) == 3, "A Hole owns the Stroke on the edge it cut, so it is a Mesh candidate of its own while still constraining its Parent.")
	var direct_hole_build: Dictionary = application._generate_component_mesh_build("direct_hole_asset", "direct_hole")
	_expect(bool(direct_hole_build.get("valid", false)) and direct_hole_build.get("recipes", {}).is_empty() and str(direct_hole_build.get("meshing", {}).get("method", "")) == ContourMeshService.METHOD, "A Hole builds the Stroke a Contour builds and never enters the Fill pipeline.")
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
	_expect(incomplete_holes.size() == 2 and "unfinished_hole: Primitive Component needs a Circle, Ellipse, Rectangle, or Triangle." in incomplete_issues, "An unfinished Primitive Hole should remain visible as a named blocking constraint instead of being silently ignored.")
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
	_expect(WorldDocumentService.has_supported_schema({"schema_version": WorldDocumentService.SCHEMA_VERSION}) and WorldDocumentService.has_supported_schema({"schema_version": WorldDocumentService.SCHEMA_VERSION - 1}) and not WorldDocumentService.has_supported_schema({"schema_version": WorldDocumentService.SCHEMA_VERSION + 1}), "The current World schema should keep current and older documents readable and reject unknown future schemas.")
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
	_expect(int(serialized_geometry.get("schema_version", 0)) == WorldDocumentService.SCHEMA_VERSION and serialized_geometry.get("sampling", {}).get("bakes", {}).get(GeometrySamplingService.ADAPTIVE, {}).get("chains", [])[0].get("samples", [])[0].get("position", null) is Array, "Sampling bakes should serialize derived positions as current-schema JSON arrays.")
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


func _create_asset_of_type(application: Control, asset_name: String, asset_type: String) -> String:
	# Drives the New Asset dialog the way a user does: the type is chosen there,
	# because the one Create view no longer implies one.
	application._sync_new_asset_type_input()
	for index in range(application.asset_type_input.item_count):
		if str(application.asset_type_input.get_item_metadata(index)) == asset_type:
			application.asset_type_input.select(index)
			application.asset_type_input.item_selected.emit(index)
			break
	application.asset_name_input.text = asset_name
	application._confirm_asset_creation()
	return str(application.assets[-1].get("asset_type", ""))


func _outliner_asset_labels(application: Control) -> Array[String]:
	# The Create Outliner as a reader sees it: the group label plus one row per
	# listed Asset. The visibility checkbox and the row's Add button are chrome.
	application._render_outliner()
	var labels: Array[String] = []
	_collect_outliner_asset_labels(application.outliner_view, labels)
	return labels


func _collect_outliner_asset_labels(node: Node, labels: Array[String]) -> void:
	# A rebuild clears with queue_free(), and a -s run never ends the frame that
	# would drain the queue, so the previous render's rows are still parented.
	if node.is_queued_for_deletion() or node is CheckBox or node is CheckButton:
		return
	if node is Label:
		labels.append(str(node.text))
	elif node is Button and str(node.text) != "Add":
		labels.append(str(node.text))
	for child in node.get_children():
		_collect_outliner_asset_labels(child, labels)


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
	_expect(application.runtime_export_view.consumer_sync_label.text.contains("noch nicht ausgeführt") and application._consumer_sync_script_paths().size() == 2 and Array(application._consumer_sync_script_paths()).all(func(path: String) -> bool: return FileAccess.file_exists(path)), "Export should expose persistent downstream Consumer Sync feedback backed by the PolyTools-owned orchestration script.")
	application._present_consumer_sync_result({"success": true, "exit_code": 0, "output": "POLYTOOLS CONSUMER SYNC SUCCESS"})
	_expect(application.runtime_export_view.consumer_sync_label.text.contains("erfolgreich") and application.runtime_export_view.log_label.get_parsed_text().contains("Consumer Sync: Success"), "A steps-less successful Consumer Sync should still present exactly one coloured Success line.")
	application._present_consumer_sync_result({"success": false, "exit_code": 7, "output": "test failure"})
	_expect(application.runtime_export_view.consumer_sync_label.text.contains("fehlgeschlagen") and application.runtime_export_view.log_label.get_parsed_text().contains("Consumer Sync: FAILED — test failure"), "A steps-less failing Consumer Sync should present one coloured FAILED line carrying its output as the reason.")
	var parsed_steps: Array = application._parse_consumer_sync_steps(PackedStringArray(["STEP|1|4|applied|PolyTools -> world01 content|", "some unrelated diagnostic line", "STEP|2|4|failed|PolyTools -> SceneMaker|ERROR: something broke", "STEP|3|4|blocked|SceneMaker scene export|wartet auf Schritt 2: PolyTools -> SceneMaker"]))
	_expect(parsed_steps.size() == 3 and parsed_steps[0].get("status") == "applied" and parsed_steps[1].get("status") == "failed" and parsed_steps[1].get("reason") == "ERROR: something broke" and parsed_steps[2].get("status") == "blocked", "Consumer Sync STEP lines should parse status and reason per step, ignoring unrelated output.")
	# OS.execute documents its whole captured output as a single String
	# element, not one element per line - so the parser must cope with every
	# STEP| line arriving glued into one PackedStringArray entry, not just
	# with one already handed a clean array of separate lines.
	var blobbed_steps: Array = application._parse_consumer_sync_steps(PackedStringArray(["STEP|1|4|applied|PolyTools -> world01 content|\nSTEP|2|4|failed|PolyTools -> SceneMaker|ERROR: something broke\nCONSUMER SYNC INCOMPLETE"]))
	_expect(blobbed_steps.size() == 2 and blobbed_steps[0].get("status") == "applied" and blobbed_steps[1].get("status") == "failed" and blobbed_steps[1].get("reason") == "ERROR: something broke", "Consumer Sync STEP lines must still parse when OS.execute hands back the whole output as one glued-together element instead of one per line.")
	application._present_consumer_sync_result({"success": false, "exit_code": 1, "output": "STEP|1|4|applied|PolyTools -> world01 content|\nSTEP|2|4|failed|PolyTools -> SceneMaker|ERROR: something broke\nSTEP|3|4|blocked|SceneMaker scene export|wartet auf Schritt 2: PolyTools -> SceneMaker\nCONSUMER SYNC INCOMPLETE", "steps": parsed_steps})
	var sync_log_text: String = application.runtime_export_view.log_label.get_parsed_text()
	_expect(sync_log_text.contains("PolyTools -> world01 content: Success") and sync_log_text.contains("PolyTools -> SceneMaker: FAILED — ERROR: something broke") and sync_log_text.contains("SceneMaker scene export: WARNING — wartet auf Schritt 2") and not sync_log_text.contains("STEP|") and not sync_log_text.contains("CONSUMER SYNC INCOMPLETE"), "A failing Consumer Sync should present one minimal Success/FAILED/WARNING line per step with its reason, and never leak the raw STEP lines or command output into the log.")
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
	application._select_submodule("Create", "Single", create_section)
	_expect(application.active_module == "Create" and application.active_create_submodule == "Single" and application.canvas_view.visible and not application.geometry_sampling_workspace.visible, "Selecting Create Single should immediately render the shared asset workspace.")
	_expect(application._find_section("Mesh").active_submodule.is_empty() and application._find_section("Style").active_submodule.is_empty(), "Only the selected module should remain highlighted across always-expanded categories.")
	_expect(create_section.content_list.get_child_count() == 3 and application.create_action_button.text == "Create Asset", "Create should expose one view per composition instead of one module per Asset type.")
	_expect(_create_asset_of_type(application, "Shield", "props") == "props", "The New Asset dialog should persist the stable props Asset type.")
	_expect(_create_asset_of_type(application, "Sword", "weapons") == "weapons", "The New Asset dialog should persist the stable weapons Asset type.")
	_expect(_create_asset_of_type(application, "Potion Flask", "items") == "items", "The New Asset dialog should persist the stable items Asset type.")
	application._sync_new_asset_type_input()
	_expect(application.new_asset_type == "items" and str(application.asset_type_input.get_item_metadata(application.asset_type_input.selected)) == "items", "The chosen Asset type should stay the offered default for the next Asset.")
	application.selected_asset_id = str(application.assets[-1].get("id", ""))
	application.selected_component_id = ""
	application._on_asset_type_selected(0, application.asset_type_input)
	_expect(str(application.assets[-1].get("asset_type", "")) == "character", "The Asset root Inspector should be able to correct an Asset type after creation.")
	var single_modules := true
	for asset_type in WorldDocumentService.ASSET_TYPES:
		single_modules = single_modules and application._asset_create_submodule({"asset_type": asset_type}) == "Single"
	_expect(WorldDocumentService.normalize_asset_type("") == "character" and single_modules and application._asset_create_submodule({"asset_type": "props", "asset_category": WorldDocumentService.ASSET_CATEGORY_SET}) == "Set" and application._normalized_create_submodule("Props") == "Single", "The Asset type should say what a thing is while the category says how it is composed, and only the category selects a module.")
	for asset in application.assets:
		application.expanded_assets[str(asset.get("id", ""))] = false
	var single_view_labels := _outliner_asset_labels(application)
	_expect(single_view_labels == ["Assets", "Potion Flask", "Shield", "Sword", "Wizard"], "The Single view should list every Asset type at once, not %s." % [single_view_labels])
	application._on_outliner_asset_type_filter_toggled(false, "character")
	_expect(not application.outliner_asset_type_filters["character"] and application.outliner_asset_type_filters["props"], "Create, Mesh and Style filters should support independent Asset type checkboxes.")
	_expect(application.outliner_asset_type_filter_panel.visible, "Create should show the shared Asset filter, because it now selects among the seven types.")
	var filtered_view_labels := _outliner_asset_labels(application)
	_expect(filtered_view_labels == ["Assets", "Shield", "Sword"], "An Asset type switched off in the filter should leave the Create Outliner, leaving %s." % [filtered_view_labels])
	# A list that is empty says why, because hidden and absent look the same.
	application._toggle_all_outliner_asset_type_filters()
	application._toggle_all_outliner_asset_type_filters()
	var empty_view_labels := _outliner_asset_labels(application)
	_expect(empty_view_labels == ["Assets", "No Asset matches the Asset filter."] and application.outliner_view._empty_create_list_reason(0) == "No Asset yet.", "An empty Create list should name its cause rather than showing nothing, but showed %s." % [empty_view_labels])
	application._toggle_all_outliner_asset_type_filters()
	application._on_outliner_asset_type_filter_toggled(false, "character")
	application.active_module = "Style"
	application._render_outliner()
	application._toggle_all_outliner_asset_type_filters()
	_expect(application.outliner_asset_type_filters["character"] and application.outliner_asset_type_filter_panel.visible and application.outliner_asset_type_filter_all_button.text == "None", "Style should show the shared Asset filter and restore all types with All, which then offers the opposite move.")
	# With everything shown the button has nothing left to add, so it clears —
	# which is how a single type is picked without unticking the other six.
	application._toggle_all_outliner_asset_type_filters()
	_expect(not application.outliner_asset_type_filters["character"] and not application.outliner_asset_type_filters["props"] and application.outliner_asset_type_filter_all_button.text == "All", "Pressing it again with every type shown should clear the filter.")
	application._on_outliner_asset_type_filter_toggled(true, "props")
	_expect(application.outliner_asset_type_filters["props"] and not application.outliner_asset_type_filters["character"] and application.outliner_asset_type_filter_all_button.text == "All", "Ticking one type back on should leave the button offering to show all.")
	application._toggle_all_outliner_asset_type_filters()
	application._select_submodule("Create", "Single", create_section)
	_expect(application.active_create_submodule == "Single" and application.canvas_view.visible, "Returning to Create Single should immediately render the shared asset workspace.")
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
	var measure_menu := _context_menu(application, "Measure")
	_expect(measure_menu != null and not measure_menu.disabled, "Measure should offer its Ruler in the Create context bar for every Component.")
	# The Primitive branch returns before the Bezier context bar is built, so it
	# needs its own call rather than inheriting one further down.
	var primitive_asset: Dictionary = {"id": "asset_primitive", "name": "Bomb", "asset_type": "props", "visibility": true, "groups": [], "guides": [],
		"components": [{"id": "component_primitive", "name": "shell", "type": "component",
			"draw_mode": WorldDocumentService.DRAW_MODE_PRIMITIVE, "topology_role": WorldDocumentService.ROLE_OUTER,
			"primitive": {"type": "circle", "center": Vector2.ZERO, "diameter_cm": 4.0},
			"points": [], "edges": [], "chains": [], "visibility": true,
			"transform": WorldDocumentService.default_component_transform()}]}
	application.assets.append(primitive_asset)
	application.selected_asset_id = "asset_primitive"
	application.selected_component_id = "component_primitive"
	application._render_context_bar()
	_expect(_context_menu(application, "Measure") != null, "A Primitive's context bar should offer Measure as well; measuring changes no geometry.")
	application.assets.erase(primitive_asset)
	application.selected_asset_id = "asset_1"
	application.selected_component_id = "component_1"
	application._render_context_bar()
	application._toggle_measure_ruler()
	application._render_context_bar()
	var active_measure_menu := _context_menu(application, "Measure")
	_expect(application.active_context_command == "asset.measure" and application.canvas_view.is_measure_placing() and active_measure_menu != null and active_measure_menu.button_pressed and active_measure_menu.get_popup().is_item_checked(0), "Switching Ruler on should hold the Measure command, arm placing and report the toggle as on.")
	application._activate_edit_point_state()
	application._render_context_bar()
	var running_measure_menu := _context_menu(application, "Measure")
	_expect(application.active_context_command == "asset.edit_point" and application.canvas_view.is_measure_ruler_enabled() and not application.canvas_view.is_measure_placing() and running_measure_menu != null and running_measure_menu.button_pressed, "Editing Points should take the clicks without switching the Ruler off, so a measurement keeps updating while its Points move.")
	application._toggle_measure_ruler()
	_expect(application.active_context_command == "asset.measure" and application.canvas_view.is_measure_placing() and application.canvas_view.is_measure_ruler_enabled(), "Picking Ruler from another command should resume placing instead of switching it off.")
	application._toggle_measure_ruler()
	_expect(not application.canvas_view.is_measure_ruler_enabled() and application.active_context_command == "asset.edit_point", "Picking Ruler while it already owns the Canvas should switch it off.")
	var nudge_component: Dictionary = application._get_component(application._get_asset("asset_1"), "component_1")
	var nudge_ids: Array = [str(nudge_component.get("points", [])[0].get("id", "")), str(nudge_component.get("points", [])[1].get("id", ""))]
	var nudge_before: Array[Vector2] = [Vector2(nudge_component.get("points", [])[0].get("position", Vector2.ZERO)), Vector2(nudge_component.get("points", [])[1].get("position", Vector2.ZERO))]
	application.canvas_view.set_selected_point_ids(nudge_ids)
	application._nudge_selected_point(Vector2.RIGHT)
	var nudge_after: Array[Vector2] = [Vector2(nudge_component.get("points", [])[0].get("position", Vector2.ZERO)), Vector2(nudge_component.get("points", [])[1].get("position", Vector2.ZERO))]
	var nudge_step: float = application.snap_grid_step if application.snap_enabled else application.world_grid_size
	_expect(nudge_after[0].x == nudge_before[0].x + nudge_step and nudge_after[1].x == nudge_before[1].x + nudge_step, "Arrow nudging should move every selected point by one snap step.")
	application.free()


func _test_consumer_sync_runs_every_orchestrator() -> void:
	# The Sync Consumers button runs each orchestrator as its own process. One
	# that fails before printing any STEP| line, or that is missing, must not
	# keep the next from running, and each still shows up as a red line.
	var directory := "user://consumer_sync_test"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var broken_path := directory + "/broken.sh"
	var working_path := directory + "/working.sh"
	var broken := FileAccess.open(broken_path, FileAccess.WRITE)
	broken.store_string("#!/usr/bin/env bash\necho 'Consumer Sync 1/1: first'\necho 'ERROR: first broke' >&2\nexit 3\n")
	broken.close()
	var working := FileAccess.open(working_path, FileAccess.WRITE)
	working.store_string("#!/usr/bin/env bash\necho 'STEP|1|1|applied|PolyTools -> game04 assets|'\nexit 0\n")
	working.close()
	var application_script = load("res://scripts/main.gd")
	var application: Control = application_script.new()
	var result: Dictionary = application._run_consumer_sync_scripts([
		{"label": "first group", "path": broken_path},
		{"label": "missing group", "path": directory + "/missing.sh"},
		{"label": "game04", "path": working_path},
	])
	var steps: Array = result.get("steps", [])
	_expect(steps.size() == 3, "Every orchestrator should contribute its lines, whatever the ones before it did.")
	_expect(steps.size() == 3 and steps[0].get("title") == "first group" and steps[0].get("status") == "failed" and str(steps[0].get("reason")).contains("first broke"), "An orchestrator that stops before its STEP| lines should still show one red line with its last output line as the reason.")
	_expect(steps.size() == 3 and steps[1].get("title") == "missing group" and steps[1].get("status") == "failed" and str(steps[1].get("reason")).begins_with("Sync script not found"), "A missing orchestrator should show one red line and not stop the run.")
	_expect(steps.size() == 3 and steps[2].get("title") == "PolyTools -> game04 assets" and steps[2].get("status") == "applied", "The orchestrator after a failed and a missing one should still run.")
	_expect(not bool(result.get("success", true)) and int(result.get("exit_code", 0)) == 3, "One failed orchestrator should fail the whole run with the first non-zero exit code.")
	application.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(broken_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(working_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))


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


func _test_mesh_workspace_zoom_range() -> void:
	# A Stone chip measures well under one tool unit; at 128 pixels per unit it
	# stayed under a hundred pixels wide, which is not a view you can judge a
	# triangle in.
	var workspaces: Array[Control] = [GeometrySamplingWorkspace.new(), GeometrySeedingWorkspace.new(), GeometryMeshingWorkspace.new()]
	for workspace in workspaces:
		workspace.camera_zoom = 100.0
		workspace._zoom_by(2.0)
		_expect(is_equal_approx(workspace.camera_zoom, 200.0), "%s should zoom past the old ceiling of 128." % workspace.get_class())
		for _step in range(64):
			workspace._zoom_by(1.12)
		_expect(is_equal_approx(workspace.camera_zoom, 1280.0), "Zooming in must stop at the shared ceiling instead of running away.")
		for _step in range(400):
			workspace._zoom_by(1.0 / 1.12)
		_expect(is_equal_approx(workspace.camera_zoom, 0.05), "The floor is unchanged; only coming closer was ever the problem.")
		var smallest_stone_extent := 0.3182
		_expect(smallest_stone_extent * workspace.MAX_CAMERA_ZOOM > 400.0, "The ceiling has to carry the smallest authored Component to a size worth inspecting.")
		workspace.free()
