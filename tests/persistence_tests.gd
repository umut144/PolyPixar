# Document persistence, history isolation, the Asset Catalog and Runtime
# Export.
extends "res://tests/test_case.gd"


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


func _test_asset_deserialization_migrations() -> void:
	# One legacy Asset document below schema 40, holding every load-time
	# migration deserialize_asset performs, so a change to any of them is
	# caught without a World on disk.
	var legacy := {
		"schema_version": 39,
		"id": "asset_legacy",
		"name": "Relic",
		"root_scale": 2.0,
		"groups": [{"id": "group_1", "name": "Arm", "z_index": 4, "transform": {}}],
		"components": [
			{"id": "component_1", "semantic_key": "body", "draw_mode": "ribbon", "points": [], "edges": [], "chains": []},
			{"id": "component_2", "name": "", "semantic_key": "Body", "draw_mode": "closed_loop", "points": [], "edges": [], "chains": []},
			{"id": "component_3", "name": "missing_semantic_1", "missing_semantic_source": "eye", "points": [], "edges": [], "chains": []},
			{"id": "component_4", "points": [], "edges": [], "chains": []},
			{"id": "component_5", "name": "lid", "type": "region", "region_type": "spikes", "points": [], "edges": [], "chains": []},
			{"id": "component_6", "name": "hem", "draw_mode": "contour", "contour_stroke_width_px": 0.0, "points": [], "edges": [], "chains": []},
			{"id": "component_7", "name": "seam", "draw_mode": "contour", "contour_stroke_width_px": 6, "points": [], "edges": [], "chains": []},
			{"id": "guide_legacy", "type": "guide", "guide_type": "cut", "name": "Split", "scope": {"kind": "component", "component_id": "component_1"}, "points": [], "edges": [], "chains": []},
		],
	}
	var asset := WorldDocumentService.deserialize_asset(legacy, "fallback_id")
	_expect(str(asset.get("id", "")) == "asset_legacy" and str(asset.get("asset_type", "")) == "character"
		and int(asset.get("authored_facing", -1)) == AssetPresentation.AuthoredFacing.NEUTRAL,
		"A legacy Asset without asset_type or authored_facing should load as a neutral character.")
	_expect(Vector2(asset.get("root_scale", Vector2.ZERO)).is_equal_approx(Vector2(2.0, 2.0)),
		"A scalar root_scale should load as equal X/Y axes.")
	var components: Array = asset.get("components", [])
	var guides: Array = asset.get("guides", [])
	_expect(components.size() == 7 and guides.size() == 1 and str(guides[0].get("id", "")) == "guide_legacy"
		and str(guides[0].get("guide_type", "")) == AssetGuide.CUT,
		"A Guide stored among the Components should load as a Guide, not as a Component.")
	var names: Array[String] = []
	for component in components:
		names.append(str(component.get("name", "")))
	_expect(names == ["body", "Body 2", "eye", "Component", "lid", "hem", "seam"],
		"Names should come from the Semantic Key fields where the name is missing, with numbered suffixes on case-insensitive collisions, not %s." % str(names))
	_expect(str(components[0].get("draw_mode", "")) == "contour",
		"A Ribbon below schema 40 should load as a Contour.")
	_expect(str(components[4].get("region_type", "")) == "attack"
		and str(components[4].get("region_geometry_source", "")) == WorldDocumentService.REGION_GEOMETRY_AUTHORED,
		"An unknown Region type should fall back to attack with authored geometry.")
	_expect(not components[5].has("contour_stroke_width_px") and is_equal_approx(float(components[6].get("contour_stroke_width_px", 0.0)), 6.0),
		"Only a finite positive Contour width should survive as a Component override.")
	var groups: Array = asset.get("groups", [])
	_expect(groups.size() == 1 and not groups[0].has("z_index"),
		"Schema 48 removed Group z_index; a legacy value must not be loaded.")

	var current := {"schema_version": WorldDocumentService.SCHEMA_VERSION, "id": "asset_current",
		"components": [
			{"id": "component_1", "name": "body", "draw_mode": "ribbon", "points": [], "edges": [], "chains": []},
			{"id": "component_2", "name": "", "semantic_key": "stale_key", "points": [], "edges": [], "chains": []},
		]}
	var current_components: Array = WorldDocumentService.deserialize_asset(current, "asset_current").get("components", [])
	_expect(str(current_components[0].get("draw_mode", "")) == "ribbon",
		"A Ribbon at the current schema is invalid and must not be silently converted.")
	_expect(str(current_components[1].get("name", "")) == "Component",
		"From schema 43 on, a missing name is not recovered from a leftover Semantic Key.")

	# Schema 64 is additive: a Reference without a role loads with none, which
	# Runtime Export reads as the member's own Asset Key.
	var references := {"schema_version": WorldDocumentService.SCHEMA_VERSION, "id": "asset_set",
		"asset_category": WorldDocumentService.ASSET_CATEGORY_SET,
		"components": [
			{"id": "component_1", "name": "post_left", "type": "reference",
				"source_asset_id": "asset_post", "role": "rope_post", "points": [], "edges": [], "chains": []},
			{"id": "component_2", "name": "plank_01", "type": "reference",
				"source_asset_id": "asset_plank", "points": [], "edges": [], "chains": []},
		]}
	var reference_asset: Dictionary = WorldDocumentService.deserialize_asset(references, "asset_set")
	var reference_components: Array = reference_asset.get("components", [])
	_expect(WorldDocumentService.is_set_asset(reference_asset)
		and WorldDocumentService.normalized_component_name(reference_components[0]) == "post_left"
		and not reference_components[0].has("role")
		and WorldDocumentService.normalized_component_name(reference_components[1]) == "plank_01",
		"A Set should load with its category and its member names, and a schema 64 role should be dropped rather than carried along.")

	# Schema 65 is additive too: a Palette is a list plus the one category its
	# variants share, and an Asset that is neither loads with neither.
	var palette := {"schema_version": WorldDocumentService.SCHEMA_VERSION, "id": "asset_grass",
		"asset_type": "terrain",
		"asset_category": WorldDocumentService.ASSET_CATEGORY_PALETTE,
		"palette_variants": ["asset_1", " asset_2 ", "asset_1", ""],
		"components": []}
	var palette_asset: Dictionary = WorldDocumentService.deserialize_asset(palette, "asset_grass")
	_expect(WorldDocumentService.is_palette_asset(palette_asset)
		and WorldDocumentService.asset_type(palette_asset) == "terrain"
		and WorldDocumentService.palette_variants(palette_asset) == ["asset_1", "asset_2"],
		"A Palette should load with its category and a variant list without blanks or repeats.")
	var invalid_palette: Dictionary = WorldDocumentService.deserialize_asset(
		{"schema_version": WorldDocumentService.SCHEMA_VERSION, "id": "asset_odd",
			"asset_category": WorldDocumentService.ASSET_CATEGORY_PALETTE,
			"asset_type": "set", "components": []}, "asset_odd")
	_expect(WorldDocumentService.asset_type(invalid_palette) == "character"
		and WorldDocumentService.palette_variants(invalid_palette).is_empty(),
		"A composition name is not an Asset type, so it falls back like any other invalid one, and a missing variant list loads empty.")

	# Schema 66 separated the two fields. Below it the composition sat in
	# asset_type and displaced the category, which cannot be recovered.
	var legacy_set: Dictionary = WorldDocumentService.deserialize_asset(
		{"schema_version": 65, "id": "asset_bridge", "asset_type": "set", "components": []}, "asset_bridge")
	_expect(WorldDocumentService.is_set_asset(legacy_set) and WorldDocumentService.asset_type(legacy_set) == "character",
		"A Set written below schema 66 should load as a Set whose displaced type falls back to Character.")
	var current_set: Dictionary = WorldDocumentService.deserialize_asset(
		{"schema_version": WorldDocumentService.SCHEMA_VERSION, "id": "asset_bridge", "asset_type": "set",
			"asset_category": WorldDocumentService.ASSET_CATEGORY_SET, "components": []}, "asset_bridge")
	_expect(WorldDocumentService.is_set_asset(current_set) and WorldDocumentService.asset_type(current_set) == "character",
		"From schema 66 on the category comes from its own field and an invalid type is not read as one.")
	var current_single: Dictionary = WorldDocumentService.deserialize_asset(
		{"schema_version": WorldDocumentService.SCHEMA_VERSION, "id": "asset_plank", "asset_type": "props", "components": []}, "asset_plank")
	_expect(WorldDocumentService.asset_category(current_single) == "single" and WorldDocumentService.asset_type(current_single) == "props",
		"An Asset that never was a composition keeps its type and reads single.")

	var blink := {"schema_version": 18, "id": "act_1", "primitive": MotionActEvaluator.BLINK,
		"parameters": {"anticipation_share": 0.18}}
	var migrated_blink := WorldDocumentService.normalize_motion_act(blink, "act_1")
	_expect(is_equal_approx(float(migrated_blink.get("parameters", {}).get("anticipation_share", 0.0)), 0.5),
		"The schema 1–18 Blink default of 0.18 should migrate to the later default of 0.5.")
	blink["schema_version"] = 19
	var kept_blink := WorldDocumentService.normalize_motion_act(blink, "act_1")
	_expect(is_equal_approx(float(kept_blink.get("parameters", {}).get("anticipation_share", 0.0)), 0.18),
		"From schema 19 on, an authored anticipation_share of 0.18 is kept.")


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
	_expect(bool(build.get("valid", false)) and int(catalog.get("schema_version", 0)) == AssetCatalogService.CATALOG_SCHEMA_VERSION and str(catalog.get("world_key", "")) == "world01", "Every World should derive an independently versioned Asset Catalog.")
	_expect(entries.size() == 3 and str(entries[0].get("asset_key", "")) == "ancient_orb" and str(entries[2].get("asset_key", "")) == "orb", "Catalog entries should be sorted alphabetically by Asset Key.")
	_expect(not JSON.stringify(catalog).contains("asset_id") and str(entries[1].get("runtime_package", "")) == "PolyToolsRuntimeExports/magic_orb/manifest.json", "The public Asset Catalog should expose key-based package paths without internal Asset IDs.")
	var item_catalog: Dictionary = AssetCatalogService.build_catalog("world01", "World", [{"id": "potion", "name": "Potion", "asset_type": "items", "visibility": true}]).get("catalog", {})
	_expect(str(item_catalog.get("assets", [])[0].get("asset_type", "")) == "items" and str(item_catalog.get("assets", [])[0].get("asset_category", "")) == "single", "The public Asset Catalog should retain the stable Items Asset type and say how the Asset is composed.")
	var palette_catalog: Dictionary = AssetCatalogService.build_catalog("world01", "World", [{"id": "grass", "name": "Grass", "asset_type": "terrain", "asset_category": "palette", "visibility": true}]).get("catalog", {})
	_expect(str(palette_catalog.get("assets", [])[0].get("asset_type", "")) == "terrain" and str(palette_catalog.get("assets", [])[0].get("asset_category", "")) == "palette", "A Palette should be recognisable from the Catalog alone, without opening its package.")
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
	application.active_create_submodule = "Single"
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
	var catalog := {"schema_version": AssetCatalogService.CATALOG_SCHEMA_VERSION, "world_key": "test_world", "world_name": "Test World", "assets": []}
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
	_expect(bool(result.get("valid", false)) and int(manifest.get("schema_version", 0)) == RuntimeExportService.MANIFEST_SCHEMA_VERSION and str(manifest.get("asset_key", "")) == "wizard" and not manifest.has("asset_id"), "The current Runtime export schema should identify packages only by the Asset Key derived from their display name.")
	var item_asset: Dictionary = asset.duplicate(true)
	item_asset["asset_type"] = "items"
	var item_manifest: Dictionary = RuntimeExportService.build_manifest(item_asset, {"component_a": source, "component_b": source}).get("manifest", {})
	_expect(str(item_manifest.get("asset_type", "")) == "items", "Runtime export should retain the stable Items Asset type.")
	_expect(str(manifest.get("presentation", {}).get("authored_facing", "")) == "right", "Runtime export should publish the selected authored facing under presentation.authored_facing.")
	var neutral_asset: Dictionary = asset.duplicate(true)
	neutral_asset.erase("authored_facing")
	var neutral_manifest: Dictionary = RuntimeExportService.build_manifest(neutral_asset, {"component_a": source, "component_b": source}).get("manifest", {})
	_expect(str(neutral_manifest.get("presentation", {}).get("authored_facing", "")) == "neutral", "Runtime export should explicitly publish neutral for an older Asset without authored_facing.")
	var manifest_text := JSON.stringify(manifest, "\t")
	_expect(application._runtime_manifest_text_matches(manifest_text, manifest_text), "Runtime staging should verify exact current-schema JSON bytes without rejecting numeric JSON round-trip types.")
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
	_expect(bool(combat_result.get("valid", false)) and int(combat_manifest.get("schema_version", 0)) == RuntimeExportService.MANIFEST_SCHEMA_VERSION and combat_manifest.get("attachment_frames", []).size() == 3 and AssetGuide.WEAPON_SOCKET_PRIMARY in exported_frame_roles and AssetGuide.GRIP_SECONDARY in exported_frame_roles and AssetGuide.REACH_LIMIT_PRIMARY in exported_frame_roles and combat_manifest.has("regions") and combat_manifest.get("regions", []).is_empty(), "The current schema should export every oriented Weapon Guide and an optional empty Regions array.")
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
	_expect(not exported_reference.has("role"), "A Reference names its place through `name` and its source through `source_asset_key`; a third name for the same thing should not cross the boundary.")
	reference_source["source_asset_exists"] = false
	_expect(not bool(RuntimeExportService.build_manifest(referenced_asset, {"component_a": source, "component_b": source, "component_orb": reference_source}).get("valid", true)), "Runtime export should reject a Reference whose actual source Asset cannot be resolved.")

	# A Palette publishes the Keys that substitute for one another and nothing
	# else; a variant that carries gameplay data invalidates the Palette rather
	# than itself.
	var palette_asset := {"id": "grass", "name": "Grass", "visibility": true,
		"asset_type": WorldDocumentService.ASSET_TYPE_TERRAIN,
		"asset_category": WorldDocumentService.ASSET_CATEGORY_PALETTE,
		"palette_variants": ["asset_1", "asset_2"], "components": []}
	var variant_records: Array = [
		{"asset_id": "asset_2", "display_name": "Grass02", "exists": true, "visible": true,
			"asset_key": "grass02", "asset_type": "terrain", "region_count": 0, "attachment_frame_count": 0},
		{"asset_id": "asset_1", "display_name": "Grass01", "exists": true, "visible": true,
			"asset_key": "grass01", "asset_type": "terrain", "region_count": 0, "attachment_frame_count": 0},
	]
	var palette_result := RuntimeExportService.build_manifest(palette_asset, {}, variant_records)
	var palette_manifest: Dictionary = palette_result.get("manifest", {})
	_expect(bool(palette_result.get("valid", false)) and palette_manifest.get("variants", []) == ["grass01", "grass02"] and str(palette_manifest.get("asset_type", "")) == "terrain" and str(palette_manifest.get("asset_category", "")) == "palette" and palette_manifest.get("components", []).is_empty() and palette_manifest.get("regions", []).is_empty(), "A Palette should publish sorted variant Keys and one category, with no geometry of its own.")
	_expect(int(palette_manifest.get("schema_version", 0)) == RuntimeExportService.MANIFEST_SCHEMA_VERSION and palette_manifest.has("asset_pivot") and palette_manifest.has("coordinate_system") and palette_manifest.has("presentation") and palette_manifest.get("attachment_frames", []).is_empty(), "A Palette Manifest should keep the shape every other Manifest has, minus the geometry it does not own.")
	var gameplay_variants: Array = variant_records.duplicate(true)
	gameplay_variants[0]["region_count"] = 1
	_expect(not bool(RuntimeExportService.build_manifest(palette_asset, {}, gameplay_variants).get("valid", true)), "A variant carrying gameplay Regions should invalidate its Palette, because the client chooses variants on its own.")
	var framed_variants: Array = variant_records.duplicate(true)
	framed_variants[1]["attachment_frame_count"] = 1
	_expect(not bool(RuntimeExportService.build_manifest(palette_asset, {}, framed_variants).get("valid", true)), "A variant carrying Attachment Frames should invalidate its Palette for the same reason.")
	var mistyped_variants: Array = variant_records.duplicate(true)
	mistyped_variants[0]["asset_type"] = "props"
	_expect(not bool(RuntimeExportService.build_manifest(palette_asset, {}, mistyped_variants).get("valid", true)), "Every variant shares the Palette's one category; another type should be rejected.")
	var missing_variants: Array = variant_records.duplicate(true)
	missing_variants[1]["exists"] = false
	_expect(not bool(RuntimeExportService.build_manifest(palette_asset, {}, missing_variants).get("valid", true)), "A Palette advertising a Key no consumer can resolve should be rejected.")
	_expect(not bool(RuntimeExportService.build_manifest(palette_asset, {}, []).get("valid", true)), "An empty Palette has nothing to publish.")

	# A Set is its members and nothing else, and it is one kind of thing with
	# them. Both are checked at export rather than assumed.
	var set_member := {"id": "component_post", "name": "rope_post", "type": "reference",
		"source_asset_id": "asset_post", "visibility": true, "z_index": 0,
		"parent_component_id": "", "transform": WorldDocumentService.default_component_transform(),
		"points": [], "edges": [], "chains": []}
	var set_asset := {"id": "bridge", "name": "Bridge", "asset_type": "props",
		"asset_category": WorldDocumentService.ASSET_CATEGORY_SET, "visibility": true,
		"asset_pivot": Vector2.ZERO, "components": [set_member]}
	var member_source := {"owner_asset_id": "bridge", "source_asset_exists": true,
		"source_asset_key": "rope_post", "source_asset_type": "props"}
	var set_result := RuntimeExportService.build_manifest(set_asset, {"component_post": member_source})
	var set_manifest: Dictionary = set_result.get("manifest", {})
	_expect(bool(set_result.get("valid", false)) and str(set_manifest.get("asset_category", "")) == "set" and str(set_manifest.get("asset_type", "")) == "props" and str(set_manifest.get("components", [])[0].get("name", "")) == "rope_post" and str(set_manifest.get("components", [])[0].get("source_asset_key", "")) == "rope_post", "A Set should export as an ordinary Manifest of its own type whose Components are member References, each naming its place and its source.")
	var nested_set: Dictionary = set_asset.duplicate(true)
	nested_set["components"][0]["parent_component_id"] = "component_other"
	var nested_errors: Array = RuntimeExportService.build_manifest(nested_set, {"component_post": member_source}).get("errors", [])
	_expect(nested_errors.any(func(error: String) -> bool: return error.contains("sits at the Set's root")), "A member hung under something else should be rejected as such: a Set is a flat assembly, not a tree of members, yet reported %s." % [nested_errors])
	var mistyped_member := member_source.duplicate(true)
	mistyped_member["source_asset_type"] = "terrain"
	_expect(not bool(RuntimeExportService.build_manifest(set_asset, {"component_post": mistyped_member}).get("valid", true)), "A member of another type should be rejected: a Set and its members are one kind of thing.")
	var mixed_set: Dictionary = set_asset.duplicate(true)
	mixed_set["components"].append(body.duplicate(true))
	_expect(not bool(RuntimeExportService.build_manifest(mixed_set, {"component_post": member_source, "component_b": source}).get("valid", true)), "A Set holding geometry of its own should be rejected; it is its members and nothing else.")
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
