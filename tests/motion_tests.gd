# Motion: selection context, player, samplers, Path topology, Acts,
# Sequences and the Motion Inspector wiring.
extends "res://tests/test_case.gd"


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


func _test_motion_inspector_wiring() -> void:
	# The Motion Inspector holds references to the session models rather than
	# only a snapshot, so each probe is handed the models before its context.
	var body := _outliner_test_component("component_1", "body")
	var motion_assets: Array[Dictionary] = [{"id": "asset_1", "name": "Wizard", "visibility": true,
		"components": [body], "groups": [], "guides": []}]
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	application.assets = motion_assets
	application.active_module = "Motion"
	var build_probe := func(case_name: String) -> Node:
		var submodule := _prepare_motion_case(application, case_name)
		application.active_motion_submodule = submodule
		var probe := MotionInspectorView.new()
		probe.set_models(application.motion_workspace, application.motion_player, application.motion_selection)
		probe.set_context(application._motion_inspector_context())
		return probe
	_check_view_wiring({
		"label": "Motion Inspector",
		"view": application.motion_inspector_view,
		"routes": MOTION_SIGNAL_ROUTES,
		"cases": MOTION_PROBE_CASES,
		"build_probe": build_probe,
	})
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
	_expect(serialized.get("parameters", {}).get("direction", null) is Array and int(serialized.get("schema_version", 0)) == WorldDocumentService.SCHEMA_VERSION, "Act persistence should serialize vectors as JSON arrays using the current schema.")
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
