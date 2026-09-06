# The editor shell: Canvas input, Inspector and Outliner behaviour, render
# invalidation, Component naming and clipboard, and the view wiring tests.
extends "res://tests/test_case.gd"


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


func _press_outliner_button(application: Control, prefix: String) -> bool:
	# Presses the row the Outliner actually built, so the test covers the
	# wiring between the row and its handler, not just the handler.
	var button := _outliner_button(application, prefix)
	if button == null:
		return false
	button.pressed.emit()
	return true


func _collect_button_labels(node: Node, labels: Array[String]) -> void:
	# A rebuild clears with queue_free(), and a -s run never ends the frame that
	# would drain the queue, so the previous render's rows are still parented.
	if node.is_queued_for_deletion() or node is CheckBox or node is CheckButton:
		return
	if node is Button and str(node.text) != "Add":
		labels.append(str(node.text))
	for child in node.get_children():
		_collect_button_labels(child, labels)


func _button_with_text(root: Node, expected_text: String) -> Button:
	if root is Button and str(root.text) == expected_text:
		return root
	for child in root.get_children():
		var match := _button_with_text(child, expected_text)
		if match != null:
			return match
	return null


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
	application.active_create_submodule = "Single"
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
	application.active_create_submodule = "Single"
	var test_assets: Array[Dictionary] = [
		{"id": "character_a", "name": "Character A", "asset_type": "character", "visibility": true, "components": [], "guides": []},
		{"id": "character_b", "name": "Character B", "asset_type": "character", "visibility": true, "components": [], "guides": []},
		{"id": "symbol_a", "name": "Symbol A", "asset_type": "symbols", "visibility": true, "components": [], "guides": []}
	]
	application.assets = test_assets
	application._set_outliner_asset_expanded("character_a", true)
	application._set_outliner_asset_expanded("character_b", true)
	_expect(not bool(application.expanded_assets.get("character_a", false)) and bool(application.expanded_assets.get("character_b", false)), "Expanding an Asset should collapse the other Assets of the same Create module.")
	# The expansion scope follows the Create module, not the Asset type: the
	# seven types share the Single view, so a Symbol collapses a Character.
	application._set_outliner_asset_expanded("symbol_a", true)
	_expect(not bool(application.expanded_assets.get("character_b", false)) and bool(application.expanded_assets.get("symbol_a", false)), "The merged Single view should hold one expanded Asset across all seven Asset types.")
	application._render_outliner()
	_expect(application._outliner_focus_asset_id() == "symbol_a" and application.outliner_view.asset_is_visible(application.assets[2]) and not application.outliner_view.asset_is_visible(application.assets[1]), "The Single Outliner should focus its one expanded Asset.")
	application.selected_asset_id = "character_b"
	application.selected_component_id = "component_stale"
	application.selected_guide_id = "guide_stale"
	application._set_create_submodule_context("Single")
	_expect(application.selected_asset_id == "character_b" and application.selected_component_id == "component_stale", "Re-entering the module an Asset already belongs to should leave the selection alone.")
	application.canvas_view.set_camera_state(Vector2(12.0, -3.0), 13.0)
	var camera_before: Dictionary = application.canvas_view.get_camera_state()
	application._set_create_submodule_context("Single")
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
	# Schema 63 merged the seven Create views and let the Asset filter gate
	# Create too. A World saved below the step could hold a type name here and
	# every filter switched off, which would read as an empty module.
	var legacy_state: Dictionary = saved_editor_state.duplicate(true)
	legacy_state["active_create_submodule"] = "Props"
	legacy_state["outliner_asset_type_filters"] = {"character": false, "props": false,
		"weapons": false, "terrain": false, "items": false, "icon": false, "symbols": false}
	application._restore_editor_state(legacy_state, 62)
	_expect(application.active_create_submodule == "Single" and application.outliner_asset_type_filters["character"] and application.outliner_asset_type_filters["symbols"], "A World below schema 63 should open in the Single view with every Asset type filter restored.")
	application._restore_editor_state(legacy_state, 63)
	_expect(application.active_create_submodule == "Single" and not application.outliner_asset_type_filters["character"], "From schema 63 the saved Asset filter is authoritative, in Create as well, and receives no fallback.")
	application.free()


func _create_set_member(application: Control, asset_id: String, member_name: String) -> String:
	# The New Member path: one dialog makes the Asset and the Reference that
	# puts it into the assembly. It asks for no type — the Set already declared
	# the one kind of thing it and its members are.
	application.asset_dialog.set_meta("composition_owner_id", asset_id)
	application.asset_name_input.text = member_name
	# What the dialog suggests while the name is typed, and what the author
	# leaves standing unless they type over it.
	application.asset_role_input.text = AssetCatalogService.asset_key(member_name)
	application._confirm_asset_creation()
	return application.selected_component_id


func _test_retired_asset_ids() -> void:
	# An ID that was handed out once is never handed out again. Derived from
	# what exists, the next ID drops back as soon as the highest Asset is
	# deleted, and a Reference still pointing at it attaches to whatever is
	# created next — silently, because both are called asset_2.
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	var owner_asset := {"id": "asset_1", "name": "Bridge", "asset_type": "props",
		"asset_category": WorldDocumentService.ASSET_CATEGORY_SET, "visibility": true,
		"components": [{"id": "component_1", "type": "reference", "name": "plank", "role": "plank",
			"source_asset_id": "asset_2", "parent_component_id": "", "points": [], "edges": [],
			"chains": [], "visibility": true, "transform": WorldDocumentService.default_component_transform()}],
		"groups": [], "guides": []}
	var member := {"id": "asset_2", "name": "Plank", "asset_type": "props", "visibility": true,
		"components": [], "groups": [], "guides": []}
	var test_assets: Array[Dictionary] = [owner_asset, member]
	application.assets = test_assets
	application._update_next_ids()
	application.selected_asset_id = "asset_2"
	application._delete_selected_asset()
	_expect(application.retired_assets.size() == 1 and str(application.retired_assets[0].get("id", "")) == "asset_2" and str(application.retired_assets[0].get("last_asset_key", "")) == "plank", "Deleting an Asset should retire its ID together with the Key it carried last, but retired %s." % [application.retired_assets])
	_expect(str(owner_asset["components"][0].get("source_asset_id", "")) == "asset_2", "A Reference to a deleted Asset should stay and read as missing rather than being removed behind the author's back.")
	# The counters are derived on load and only ever raised by what was stored,
	# so a reload cannot let the freed ID come back.
	application._update_next_ids()
	_expect(application.next_asset_id == 2, "Derived on its own, the next ID falls back onto the deleted one.")
	application._restore_next_ids(application._serialize_next_ids())
	_expect(application.next_asset_id == 3, "The retired ID should raise the next one past itself.")
	application._restore_next_ids({"asset": 9})
	_expect(application.next_asset_id == 9, "A stored counter should raise the next ID, never lower it.")
	application._restore_next_ids({"asset": 2})
	_expect(application.next_asset_id == 9, "A lower stored counter should be ignored.")
	application.free()


func _test_set_composition() -> void:
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	var plank := {"id": "asset_plank", "name": "Plank", "asset_type": "props", "visibility": true,
		"components": [], "groups": [], "guides": []}
	var post := {"id": "asset_post", "name": "Rope Post", "asset_type": "props", "visibility": true,
		"components": [], "groups": [], "guides": []}
	var test_assets: Array[Dictionary] = [plank, post]
	application.assets = test_assets
	application.next_asset_id = 3
	var create_section: ModuleSection = application._find_section("Create")
	application._select_submodule("Create", "Set", create_section)
	_expect(application.active_create_submodule == "Set" and application.create_action_button.text == "Create Set" and not application.outliner_asset_type_filter_panel.visible, "The Set module should create Sets and hide the seven-type Asset filter, which does not describe them.")
	application.asset_dialog.set_meta("composition_owner_id", "")
	application.new_asset_type = "props"
	application.asset_name_input.text = "Bridge"
	application._confirm_asset_creation()
	var bridge: Dictionary = application.assets[-1]
	var bridge_id := str(bridge.get("id", ""))
	_expect(WorldDocumentService.is_set_asset(bridge) and WorldDocumentService.asset_type(bridge) == "props" and application._asset_create_submodule(bridge) == "Set", "Creating from the Set module should persist the set category while the Asset keeps a type of its own.")
	# The primary path: Add makes a member. The member is an ordinary Asset, and
	# the Reference that carries it into the assembly is named after it.
	var rail_member_id := _create_set_member(application, bridge_id, "Rope Rail")
	var rail_member: Dictionary = application._get_component(bridge, rail_member_id)
	var rail_asset: Dictionary = application._get_asset(str(rail_member.get("source_asset_id", "")))
	_expect(application.selected_asset_id == bridge_id and application._is_reference_component(rail_member) and str(rail_member.get("parent_component_id", "")).is_empty(), "Adding a member should leave the Set selected and put a root-level Reference into it.")
	_expect(str(rail_asset.get("name", "")) == "Rope Rail" and str(rail_asset.get("asset_type", "")) == "props" and str(rail_asset.get("asset_category", "")) == "single" and rail_asset.get("components", []).is_empty(), "A member should be an ordinary Asset of the Set's own type, ready for its Components.")
	_expect(not application._new_asset_dialog_offers_a_type(bridge_id), "A member is never asked for a type, because its Set already declared one.")
	_expect(WorldDocumentService.normalized_component_name(rail_member) == "rope_rail", "The Reference should be named after the member, by the same derivation the Asset Key uses.")
	# A member is reached through its composition, so Single does not offer it
	# a second time.
	_expect(application._composition_owner_by_member_id().has(str(rail_asset.get("id", ""))), "An Asset a Set owns should count as a composition member.")
	application._select_submodule("Create", "Single", create_section)
	# An expanded Asset focuses the Create list on itself, so the list is read
	# with everything collapsed.
	for asset in application.assets:
		application.expanded_assets[str(asset.get("id", ""))] = false
	application._render_outliner()
	var single_labels: Array[String] = []
	_collect_button_labels(application.outliner_view, single_labels)
	_expect(single_labels.has("Plank") and single_labels.has("Rope Post") and not single_labels.has("Rope Rail") and not single_labels.has("Bridge"), "Single should list what is placed on its own and neither members nor compositions, but listed %s." % [single_labels])
	application._select_submodule("Create", "Set", create_section)
	# The Reference name is derived, so it has to survive a name the Set already
	# uses rather than silently duplicating it.
	bridge["components"].append(_outliner_test_component("component_taken", "bridge_post"))
	var post_member_id := _create_set_member(application, bridge_id, "Bridge Post")
	var post_member: Dictionary = application._get_component(bridge, post_member_id)
	_expect(WorldDocumentService.normalized_component_name(post_member) == "bridge_post_02" and WorldDocumentService.reference_role(post_member) == "bridge_post", "A derived Reference name should stay unique inside the Set, and the Role the dialog suggested should be stored as authored.")
	application.selected_asset_id = bridge_id
	application.selected_component_id = post_member_id
	# The Reference name is the member's place in the Set, so the Inspector
	# offers that one name and nothing beside it: no second name for the same
	# thing, and no Parent, because a member always sits at the Set's root.
	application._render_inspector()
	var member_inspector: Array = []
	_inspector_controls(application.inspector_content, member_inspector)
	var member_inspector_texts: Array[String] = []
	for control in member_inspector:
		if "text" in control:
			# A section header draws its collapse arrow into its own text, so it
			# is stripped here: without that, asserting a section is absent
			# succeeds even when it is drawn.
			member_inspector_texts.append(str(control.text).trim_prefix("▾").trim_prefix("▸").strip_edges())
	_expect(member_inspector_texts.has("Member Asset") and member_inspector_texts.has("Bridge Post") and member_inspector_texts.has("Place in Set") and member_inspector_texts.has("bridge_post_02") and member_inspector_texts.has("Role in the Set") and not member_inspector_texts.has("Hierarchy") and not member_inspector_texts.has("Component") and not member_inspector_texts.has("Set Role"), "A member Inspector should name the member Asset and the place it fills, and offer neither a Parent nor a second name for the place, but showed %s." % [member_inspector_texts])
	application._render_outliner()
	# A member row names the member Asset, exactly as a Palette names a variant:
	# the Reference that carries it is derived, so it is read in the tooltip.
	_expect(_button_with_text(application.outliner_view, "Bridge") != null and _button_with_text(application.outliner_view, "Rope Rail") != null and _button_with_text(application.outliner_view, "Bridge Post") != null, "The Set Outliner should list the Set and its members by name.")
	_expect(application.outliner_view._set_member_tooltip(post_member, "Bridge Post") == "Member asset: Bridge Post\nReference: bridge_post_02", "A member tooltip should carry the derived Reference the row does not show.")
	# The row names the member Asset, so this is where that Asset is renamed —
	# through the dialog, because the name derives the Asset Key and the
	# directory the Asset's files live in.
	var post_asset: Dictionary = application._get_asset(str(post_member.get("source_asset_id", "")))
	_expect(is_instance_valid(application.create_inspector_view.set_member_rename_button), "A member Inspector should offer to rename the member Asset.")
	application.create_inspector_view.set_member_rename_button.pressed.emit()
	_expect(str(application.asset_rename_dialog.get_meta("asset_id", "")) == str(post_asset.get("id", "")), "The member rename dialog should open on the member Asset rather than on the Set.")
	application.asset_rename_input.text = "Deck"
	application._confirm_asset_rename()
	_expect(str(post_asset.get("name", "")) == "Deck" and WorldDocumentService.normalized_component_name(post_member) == "deck" and WorldDocumentService.reference_role(post_member) == "bridge_post", "Renaming a member should rename its Asset and carry the derived name along, while the authored Role stays: what a member stands for is not what it is called.")
	application.selected_component_id = post_member_id
	application._on_reference_role_requested("Bridge Post")
	_expect(WorldDocumentService.reference_role(post_member) == "bridge_post", "A Role that is not lower_snake_case should be rejected rather than stored.")
	application._on_reference_role_requested("anchor")
	_expect(WorldDocumentService.reference_role(post_member) == "anchor", "An authored Role should replace the suggested one.")
	# A place the user named answers a different question than which Asset fills
	# it, so it is left alone.
	post_member["name"] = "left_side"
	application.asset_rename_input.text = "Deck Plate"
	application._confirm_asset_rename()
	_expect(str(post_asset.get("name", "")) == "Deck Plate" and WorldDocumentService.normalized_component_name(post_member) == "left_side", "An authored place name should survive a rename of the Asset that fills it.")
	_expect(application._is_derived_reference_name("rope_post", "Rope Post") and application._is_derived_reference_name("rope_post_02", "Rope Post") and not application._is_derived_reference_name("post_left", "Rope Post") and not application._is_derived_reference_name("rope_post_left", "Rope Post"), "A Reference name counts as derived when it is the source Asset's own Key, with or without the duplicate suffix, and not otherwise.")
	# A member is authored where it belongs: its Components are added through
	# the member row and drawn underneath it, without leaving the Set.
	var member_asset_id := str(rail_member.get("source_asset_id", ""))
	application.component_dialog.set_meta("asset_id", member_asset_id)
	application.component_dialog.set_meta("parent_component_id", "")
	application.component_dialog.set_meta("draw_mode", WorldDocumentService.DRAW_MODE_CLOSED_LOOP)
	application.component_dialog.set_meta("source_asset_id", "")
	application.component_dialog.set_meta("group_id", "")
	application.component_name_input.text = "body"
	application._confirm_component_creation()
	var member_component_id: String = application.selected_component_id
	_expect(application.selected_asset_id == member_asset_id and str(application._get_component(rail_asset, member_component_id).get("name", "")) == "body", "A Component added from the member row should belong to the member Asset.")
	_expect(application.active_create_submodule == "Set" and application._outliner_focus_asset_id() == bridge_id, "Authoring inside a member should keep the Set module and keep the Set as the expanded row.")
	application._render_outliner()
	_expect(_button_with_text(application.outliner_view, "body") != null and _button_with_text(application.outliner_view, "Bridge") != null, "The member's Components should be drawn underneath its member row.")
	application._select_component(member_asset_id, member_component_id)
	_expect(application.active_create_submodule == "Set" and application.selected_asset_id == member_asset_id and application._outliner_focus_asset_id() == bridge_id, "Selecting a member's Component should stay in the Set module and leave the Set expanded.")
	# A composition and the Assets it owns are one kind of thing, so changing the
	# type on the Set moves it to every member.
	application.selected_asset_id = bridge_id
	application.selected_component_id = ""
	var terrain_index := -1
	for index in range(application.asset_type_input.item_count):
		if str(application.asset_type_input.get_item_metadata(index)) == "terrain":
			terrain_index = index
	application._on_asset_type_selected(terrain_index, application.asset_type_input)
	_expect(str(bridge.get("asset_type", "")) == "terrain" and str(rail_asset.get("asset_type", "")) == "terrain", "Changing a Set's type should move it to its members rather than leaving the two disagreeing.")
	application._on_asset_type_selected(1, application.asset_type_input)
	_expect(str(bridge.get("asset_type", "")) == "props" and str(rail_asset.get("asset_type", "")) == "props", "The same holds on the way back.")
	# Plank instances Rope Post, so Rope Post may not instance Plank back: the
	# consumer resolves References through the Catalog and would recurse.
	plank["components"].append({"id": "component_cap", "type": "reference", "name": "cap",
		"source_asset_id": "asset_post", "parent_component_id": "", "points": [], "edges": [],
		"chains": [], "visibility": true, "transform": WorldDocumentService.default_component_transform()})
	_expect(application._reference_cycle_issue("asset_plank", "asset_post").is_empty() and not application._reference_cycle_issue("asset_post", "asset_plank").is_empty(), "A Reference that would close a cycle should be rejected where it is authored.")
	_expect(not application._reference_cycle_issue("asset_plank", "asset_plank").is_empty() and not application._reference_cycle_issue("asset_plank", "").is_empty(), "Self-reference and a missing source should be rejected as well.")
	# A Component's Reference places a Symbol inside that Component's frame;
	# assembling ordinary Assets is the Set's job, so the two entry points do
	# not overlap. A Palette variant stays out even when it is a Symbol: a
	# variant is presentation the client chooses on its own, so an authoritative
	# placement must not depend on one.
	var palette := {"id": "asset_runes", "name": "Runes", "asset_type": "symbols",
		"asset_category": WorldDocumentService.ASSET_CATEGORY_PALETTE,
		"palette_variants": ["asset_rune"], "visibility": true,
		"components": [], "groups": [], "guides": []}
	var rune := {"id": "asset_rune", "name": "Rune01", "asset_type": "symbols",
		"visibility": true, "components": [], "groups": [], "guides": []}
	var glyph := {"id": "asset_glyph", "name": "Glyph", "asset_type": "symbols",
		"visibility": true, "components": [], "groups": [], "guides": []}
	var mark := {"id": "asset_mark", "name": "Mark", "asset_type": "symbols", "visibility": true,
		"components": [{"id": "component_mark", "type": "reference", "name": "glyph",
			"source_asset_id": "asset_glyph", "parent_component_id": "", "points": [], "edges": [],
			"chains": [], "visibility": true, "transform": WorldDocumentService.default_component_transform()}],
		"groups": [], "guides": []}
	application.assets.append(palette)
	application.assets.append(rune)
	application.assets.append(glyph)
	application.assets.append(mark)
	var plank_sources: Array[String] = []
	for candidate in application._reference_source_candidates("asset_plank"):
		plank_sources.append(str(candidate.get("name", "")))
	_expect(plank_sources == ["Glyph", "Mark"], "A Component Reference should offer Symbols only, and neither a composition nor a Palette variant, yet offered %s." % [plank_sources])
	var glyph_sources: Array[String] = []
	for candidate in application._reference_source_candidates("asset_glyph"):
		glyph_sources.append(str(candidate.get("name", "")))
	_expect(glyph_sources.is_empty(), "Itself, and a source that already reaches it, should stay out of an Asset's list, but offered %s." % [glyph_sources])
	application.free()


func _create_palette_variant(application: Control, palette_id: String, variant_name: String) -> String:
	# The New Variant path: the Palette already fixed the category, so the
	# dialog only asks for the name.
	application.asset_dialog.set_meta("composition_owner_id", palette_id)
	application.asset_name_input.text = variant_name
	application._confirm_asset_creation()
	return str(application.assets[-1].get("id", ""))


func _test_palette_composition() -> void:
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	var meadow := {"id": "asset_meadow", "name": "Meadow", "asset_type": "terrain", "visibility": true,
		"components": [], "groups": [], "guides": []}
	var test_assets: Array[Dictionary] = [meadow]
	application.assets = test_assets
	application.next_asset_id = 2
	var create_section: ModuleSection = application._find_section("Create")
	application._select_submodule("Create", "Palette", create_section)
	_expect(application.active_create_submodule == "Palette" and application.create_action_button.text == "Create Palette" and not application.outliner_asset_type_filter_panel.visible, "The Palette module should create Palettes and hide the seven-type Asset filter.")
	_expect(application._new_asset_dialog_offers_a_type("") and application._new_asset_dialog_title("") == "New Palette", "A Palette declares the type of its variants where it is named.")
	application.asset_dialog.set_meta("composition_owner_id", "")
	application.new_asset_type = WorldDocumentService.ASSET_TYPE_TERRAIN
	application.asset_name_input.text = "Grass"
	application._confirm_asset_creation()
	var palette: Dictionary = application.assets[-1]
	var palette_id := str(palette.get("id", ""))
	_expect(WorldDocumentService.is_palette_asset(palette) and WorldDocumentService.asset_type(palette) == "terrain" and WorldDocumentService.palette_variants(palette).is_empty(), "A new Palette should carry the type its variants will share and start empty.")
	_expect(not application._new_asset_dialog_offers_a_type(palette_id) and application._new_asset_dialog_title(palette_id) == "New Variant Asset", "A variant is never asked for a type, because its Palette already declared one.")
	var first_variant_id := _create_palette_variant(application, palette_id, "Grass01")
	var second_variant_id := _create_palette_variant(application, palette_id, "Grass02")
	_expect(WorldDocumentService.palette_variants(palette) == [first_variant_id, second_variant_id], "Adding a variant should append its Asset ID to the Palette's list.")
	_expect(str(application._get_asset(first_variant_id).get("asset_type", "")) == "terrain" and str(application._get_asset(first_variant_id).get("asset_category", "")) == "single" and application._get_asset(first_variant_id).get("components", []).is_empty(), "A variant should be an ordinary Asset of the Palette's type, ready for its Components.")
	_expect(application.selected_asset_id == palette_id, "Adding a variant should leave the Palette selected.")
	# A variant carries no Reference, no transform and no order: the list is all
	# there is.
	_expect(palette.get("components", []).is_empty(), "A Palette should own no Components of its own.")
	# The variant Asset is drawn underneath its row and authored there.
	application.component_dialog.set_meta("asset_id", first_variant_id)
	application.component_dialog.set_meta("parent_component_id", "")
	application.component_dialog.set_meta("draw_mode", WorldDocumentService.DRAW_MODE_CLOSED_LOOP)
	application.component_dialog.set_meta("source_asset_id", "")
	application.component_dialog.set_meta("group_id", "")
	application.component_name_input.text = "body"
	application._confirm_component_creation()
	_expect(application.selected_asset_id == first_variant_id and application.active_create_submodule == "Palette" and application._outliner_focus_asset_id() == palette_id, "Authoring inside a variant should keep the Palette module and keep the Palette as the expanded row.")
	application._render_outliner()
	_expect(_button_with_text(application.outliner_view, "Grass") != null and _button_with_text(application.outliner_view, "Grass01") != null and _button_with_text(application.outliner_view, "body") != null, "The Palette Outliner should list the Palette, its variants and each variant's Components.")
	# Single lists what is placed on its own; a variant is reached through its
	# Palette.
	application._select_submodule("Create", "Single", create_section)
	for asset in application.assets:
		application.expanded_assets[str(asset.get("id", ""))] = false
	application._render_outliner()
	var single_labels: Array[String] = []
	_collect_button_labels(application.outliner_view, single_labels)
	_expect(single_labels == ["Meadow"], "Single should list neither the Palette nor its variants, but listed %s." % [single_labels])
	application._select_submodule("Create", "Palette", create_section)
	application.selected_asset_id = palette_id
	application.selected_component_id = ""
	var variant_rows: Array = application._palette_variant_rows(palette)
	_expect(variant_rows.size() == 2 and str(variant_rows[0].get("label", "")) == "Grass01" and not bool(variant_rows[0].get("missing", true)), "The Palette Inspector should receive its variants already labelled.")
	application._on_palette_variant_remove_requested(second_variant_id)
	_expect(WorldDocumentService.palette_variants(palette) == [first_variant_id], "Removing a variant should drop it from the list and leave the Asset alone.")
	_expect(not application._get_asset(second_variant_id).is_empty(), "Removing a variant from a Palette should not delete the Asset it named.")
	# A variant Asset that is gone stays visible as missing rather than
	# vanishing from the list.
	palette["palette_variants"] = [first_variant_id, "asset_gone"]
	var missing_rows: Array = application._palette_variant_rows(palette)
	_expect(missing_rows.size() == 2 and bool(missing_rows[1].get("missing", false)) and str(missing_rows[1].get("label", "")) == "Missing Asset", "A variant whose Asset no longer exists should stay visible as missing.")
	application.free()


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
	application.active_create_submodule = "Single"
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
	# Renaming is confirmed rather than typed in place: the name derives the
	# Asset Key and the directory the Asset's files live in.
	_expect(is_instance_valid(application.create_inspector_view.asset_rename_button), "The Asset Inspector should offer the rename dialog rather than an inline name field.")
	application.create_inspector_view.asset_rename_button.pressed.emit()
	_expect(str(application.asset_rename_dialog.get_meta("asset_id", "")) == application.selected_asset_id and application.asset_rename_input.text == str(asset["name"]) and application.asset_rename_key_label.text == "Asset Key: %s" % AssetCatalogService.asset_key(str(asset["name"])), "The rename dialog should open on the selected Asset with its name and derived Key.")
	application.asset_rename_input.text = "Sorcerer"
	application._update_asset_rename_preview("Sorcerer")
	_expect(application.asset_rename_key_label.text == "Asset Key: sorcerer", "The dialog should show the Key the new name derives while it is typed.")
	application._confirm_asset_rename()
	_expect(str(asset["name"]) == "Sorcerer" and application.world_name.is_empty(), "Confirming the dialog should rename the Asset; a World that was never written has nothing to save.")
	# The Key that was left behind is kept: a consumer whose own files name
	# Assets by Key needs the trail from the outdated name to this Asset.
	_expect(WorldDocumentService.previous_asset_keys(asset) == ["wizard"], "A rename should record the Key it left behind, but recorded %s." % [WorldDocumentService.previous_asset_keys(asset)])
	application.asset_rename_input.text = "Wizard"
	application._confirm_asset_rename()
	_expect(WorldDocumentService.previous_asset_keys(asset) == ["wizard", "sorcerer"], "Renaming back should record that trail too rather than tidying it away.")
	# The Reference Image is named after the Asset too, so a rename can carry it
	# along instead of leaving it under the previous name.
	_expect(application._reference_image_filename_for("Rope Post", "asset_9") == "rope_post_ref.png" and application._reference_image_filename_for("", "asset_9") == "asset_9_ref.png", "The Reference Image filename should derive from the Asset name, with the ID as the fallback.")
	_expect(application._asset_storage_name_for(str(asset["id"]), "Rope Post") == "Rope_Post", "The storage directory should derive from the Asset name the same way the World save derives it.")
	# The Canvas shortcuts are routed ahead of the GUI, so a focused text field
	# cannot defend itself by consuming the key: the shortcuts stand back while
	# one owns the keyboard, or typing a name would place a Pivot at P.
	var focused_field := LineEdit.new()
	var focused_number := SpinBox.new()
	_expect(application._canvas_shortcuts_are_blocked(focused_field)
		and application._canvas_shortcuts_are_blocked(focused_number.get_line_edit())
		and not application._canvas_shortcuts_are_blocked(application.canvas_view)
		and not application._canvas_shortcuts_are_blocked(null),
		"A focused text field should block the Canvas shortcuts, and nothing else should.")
	focused_field.free()
	focused_number.free()
	# One document per ID is an assumption the loader used to make silently: the
	# first directory found wins, so a leftover from an older rename can decide
	# which version of an Asset a World loads.
	_expect(application._duplicate_asset_storage_message({}, {}).is_empty()
		and application._duplicate_asset_storage_message({"asset_20": ["Potion", "PotionT1"]}, {"asset_20": "Potion"}) == "asset_20 lies in 2 directories · loading assets/Potion"
		and application._duplicate_asset_storage_message({"asset_20": ["Potion", "PotionT1"], "asset_7": ["Orb", "Sphere"]}, {"asset_20": "Potion"}).ends_with("· 1 more Assets affected"),
		"A duplicate Asset document should be reported with the copy that is being loaded rather than resolved silently.")
	# An Asset that has never been written has nothing to move, and a name whose
	# directory does not change moves nothing either.
	var unsaved_plan: Dictionary = application._asset_storage_move_plan("res://worlds/none", "", "Deck")
	var unchanged_plan: Dictionary = application._asset_storage_move_plan("res://worlds/none", "Deck", "Deck")
	_expect(unsaved_plan.get("moves", []).is_empty() and str(unsaved_plan.get("blocked", "")).is_empty() and unchanged_plan.get("moves", []).is_empty(), "A rename should plan no move where there is nothing to move.")

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


const RUNTIME_EXPORT_SIGNAL_ROUTES := [
	["build_all_requested", "_on_build_all_pressed"],
	["export_all_valid_requested", "_on_export_all_valid_pressed"],
	["sync_consumers_requested", "_on_sync_consumers_pressed"],
]


func _test_runtime_export_view_wiring() -> void:
	# One state is enough for this view; its three toolbar Buttons live outside
	# the probe's own tree, so they are handed to the walk separately and freed
	# with the probe.
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	var probe_buttons: Array[Button] = []
	var build_probe := func(_case_name: String) -> Node:
		var probe := RuntimeExportView.new()
		probe_buttons.assign([Button.new(), Button.new(), Button.new()])
		probe.set_toolbar_buttons(probe_buttons[0], probe_buttons[1], probe_buttons[2])
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
		return probe
	var after_rebuild := func(_probe: Node) -> void:
		_expect(probe_buttons[0].text == "Build All (1)" and not probe_buttons[0].disabled
			and probe_buttons[2].visible,
			"A bare view should apply the toolbar state it was given before the walk fires the Buttons.")
	var extra_controls := func(_probe: Node) -> Array:
		return Array(probe_buttons)
	var release_probe := func(probe: Node) -> void:
		for button in probe_buttons:
			button.free()
		probe.free()
	_check_view_wiring({
		"label": "Runtime Export view",
		"view": application.runtime_export_view,
		"routes": RUNTIME_EXPORT_SIGNAL_ROUTES,
		"cases": ["pending"],
		"build_probe": build_probe,
		"after_rebuild": after_rebuild,
		"extra_controls": extra_controls,
		"release_probe": release_probe,
	})

	var pushed := {"summary": "first", "consumer_sync": "", "stages": [], "all_current": false,
		"toolbar": {}}
	application.runtime_export_view.set_context(pushed)
	pushed["summary"] = "second"
	application.runtime_export_view.rebuild()
	_expect(application.runtime_export_view.summary_label.text == "first",
		"The Runtime Export view should render the context it was given, not the caller's later edits.")
	application.free()


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
	application.active_create_submodule = "Single"
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
	var opening := {"id": "opening", "name": "body_opening01", "type": "component", "draw_mode": "primitive", "topology_role": "outer", "parent_component_id": "", "group_id": "potion", "visibility": true, "primitive": {"type": "circle", "center": Vector2.ZERO, "diameter_cm": 4.0}, "transform": {"position": Vector2(3.0, 2.0), "rotation": 8.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}}
	var opening_hole := {"id": "opening_hole", "name": "body_opening_hole01", "type": "component", "draw_mode": "primitive", "topology_role": "hole", "parent_component_id": "opening", "group_id": "potion", "visibility": true, "primitive": {"type": "circle", "center": Vector2.ZERO, "diameter_cm": 3.0}, "transform": {"position": Vector2(0.5, 0.25), "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}}
	var potion_group := {"id": "potion", "name": "potion", "parent_component_id": "", "visibility": true, "transform": {"position": Vector2(7.0, -4.0), "rotation": 12.0, "scale": Vector2(1.2, 1.2), "pivot": Vector2.ZERO}}
	var potion_asset := {"id": "potion_asset", "name": "Potion", "asset_type": "items", "visibility": true, "components": [opening, opening_hole], "groups": [potion_group], "guides": []}
	ComponentHierarchy.normalize_asset(potion_asset)
	_expect(str(opening_hole.get("group_id", "")) == "" and ComponentHierarchy.membership_group_id(potion_asset, "opening_hole") == "potion", "A loaded Potion Hole should canonicalize to inherited Group membership like an ordinary Child.")
	var opening_world_before_remove := ComponentHierarchy.world_transform(potion_asset, "opening")
	var hole_world_before_remove := ComponentHierarchy.world_transform(potion_asset, "opening_hole")
	application._set_component_group_preserving_world(potion_asset, "opening", "")
	_expect(ComponentHierarchy.membership_group_id(potion_asset, "opening").is_empty() and ComponentHierarchy.membership_group_id(potion_asset, "opening_hole").is_empty() and str(opening_hole.get("parent_component_id", "")) == "opening", "Removing the Potion Parent from its Group should also remove the inherited Hole subtree while retaining Component parentage.")
	_expect(ComponentHierarchy.world_transform(potion_asset, "opening").is_equal_approx(opening_world_before_remove) and ComponentHierarchy.world_transform(potion_asset, "opening_hole").is_equal_approx(hole_world_before_remove), "Removing a grouped Potion Parent must preserve both Parent and Hole world transforms.")
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
	application.active_create_submodule = "Single"
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


const OUTLINER_PROBE_CASES := ["create", "create_expanded", "create_set", "style", "motion_animation",
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
	# The Set draws its member Asset underneath the Reference, so the member
	# carries the row kinds a member is authored with.
	var member_body := _outliner_test_component("component_5", "body")
	var member_region := {"points": [], "edges": [], "chains": [], "id": "component_6",
		"name": "collision_region", "visibility": true, "type": "region",
		"region_type": "collision", "parent_component_id": "component_5"}
	var member_reference := {"points": [], "edges": [], "chains": [], "id": "component_7",
		"name": "rope_post", "visibility": true, "type": "reference",
		"parent_component_id": "", "source_asset_id": "asset_3", "role": "rope_post"}
	return [
		{"id": "asset_1", "name": "Wizard", "visibility": true,
			"components": [body, arm, hole, region], "groups": [group], "guides": [guide, spine]},
		{"id": "asset_2", "name": "Orb", "visibility": true,
			"components": [], "groups": [], "guides": []},
		{"id": "asset_3", "name": "Rope Post", "visibility": true, "asset_type": "props",
			"components": [member_body, member_region], "groups": [], "guides": []},
		{"id": "asset_4", "name": "Bridge", "visibility": true,
			"asset_type": WorldDocumentService.ASSET_TYPE_PROPS,
			"asset_category": WorldDocumentService.ASSET_CATEGORY_SET,
			"components": [member_reference], "groups": [], "guides": []},
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
			application.active_create_submodule = "Single"
		"create_expanded":
			application.active_module = "Create"
			application.active_create_submodule = "Single"
			application.expanded_assets["asset_1"] = true
		"create_set":
			application.active_module = "Create"
			application.active_create_submodule = "Set"
			application.selected_asset_id = "asset_4"
			application.expanded_assets["asset_4"] = true
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
	["asset_rename_dialog_requested", "_on_asset_rename_dialog_requested"],
	["asset_root_position_changed", "_on_asset_root_position_changed"],
	["asset_root_scale_changed", "_on_asset_root_scale_changed"],
	["asset_root_scale_rebase_requested", "_on_rebase_asset_root_scale_pressed"],
	["asset_scales_rebase_requested", "_on_rebase_asset_scales_pressed"],
	["asset_type_selected", "_on_asset_type_selected"],
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
	["palette_variant_remove_requested", "_on_palette_variant_remove_requested"],
	["point_position_changed", "_on_point_position_changed"],
	["reference_image_clear_requested", "_clear_reference_image"],
	["reference_image_load_requested", "_open_reference_image_dialog"],
	["reference_image_pivot_selected", "_on_reference_image_pivot_selected"],
	["reference_image_property_changed", "_on_reference_image_property_changed"],
	["reference_image_target_height_changed", "_on_reference_image_target_height_changed"],
	["reference_image_visibility_changed", "_on_reference_image_visibility_changed"],
	["reference_role_requested", "_on_reference_role_requested"],
	["section_toggled", "_on_inspector_section_toggled"],
	["selected_points_delta_changed", "_on_selected_points_delta_changed"],
	["selected_points_mode_selected", "_on_selected_points_mode_selected"],
	["selected_points_preserve_changed", "_on_selected_points_preserve_changed"],
	["set_member_rename_dialog_requested", "_on_set_member_rename_dialog_requested"],
	["transform_value_changed", "_on_transform_value_changed"],
	["weapon_frame_value_changed", "_on_weapon_frame_value_changed"],
]


const CREATE_PROBE_CASES := ["asset", "asset_reference", "set_asset", "set_member", "palette_asset", "component", "component_grouped",
	"component_contour", "primitive_circle", "primitive_hole", "primitive_ellipse", "group", "guide",
	"guide_weapon", "region_authored", "region_component", "multi_component", "point_none", "point_one", "point_many",
	"edge_none", "edge_one", "edge_many", "hole_edge_one", "hole_edge_many", "face"]


func _create_wiring_palette() -> Dictionary:
	# A Palette is a list and one category, nothing else. One variant resolves
	# and one no longer exists, so both row forms are drawn.
	return {"id": "asset_10", "name": "Grass", "visibility": true,
		"asset_type": WorldDocumentService.ASSET_TYPE_TERRAIN,
		"asset_category": WorldDocumentService.ASSET_CATEGORY_PALETTE,
		"palette_variants": ["asset_1", "asset_gone"],
		"components": [], "groups": [], "guides": [],
		"asset_pivot": Vector2.ZERO, "root_position": Vector2.ZERO, "root_scale": Vector2.ONE}


func _create_wiring_set() -> Dictionary:
	# A Set carries no geometry: one Reference per member, each with the role it
	# plays in the assembly.
	var member := _outliner_test_component("component_20", "post_left")
	member.merge({"type": "reference", "source_asset_id": "asset_1", "role": "rope_post",
		"points": [], "edges": [], "chains": []}, true)
	return {"id": "asset_9", "name": "Bridge", "visibility": true,
		"asset_type": WorldDocumentService.ASSET_TYPE_PROPS,
		"asset_category": WorldDocumentService.ASSET_CATEGORY_SET,
		"components": [member], "groups": [], "guides": [],
		"asset_pivot": Vector2.ZERO, "root_position": Vector2.ZERO, "root_scale": Vector2.ONE}


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
	application.active_create_submodule = "Single"
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
		"set_asset":
			application.active_create_submodule = "Set"
			application.selected_asset_id = "asset_9"
		"set_member":
			application.active_create_submodule = "Set"
			application.selected_asset_id = "asset_9"
			application.selected_component_id = "component_20"
		"palette_asset":
			application.active_create_submodule = "Palette"
			application.selected_asset_id = "asset_10"
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
	probe.set_palette_variants(application._palette_variant_rows(asset))
	probe.set_mode(application.active_state, application.active_edit_mode,
		application.canvas_view.face_selected)
	return probe


func _test_create_inspector_wiring() -> void:
	var create_assets: Array[Dictionary] = [_create_wiring_asset(), _create_wiring_set(), _create_wiring_palette()]
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	application.assets = create_assets
	var build_probe := func(case_name: String) -> Node:
		_prepare_create_case(application, case_name)
		return _build_create_probe(application)
	_check_view_wiring({
		"label": "Create Inspector",
		"view": application.create_inspector_view,
		"routes": CREATE_SIGNAL_ROUTES,
		"cases": CREATE_PROBE_CASES,
		"build_probe": build_probe,
	})
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
	# Six Weighting states. The Component Mesh has to be Ready for them to
	# differ at all, so that is asserted before the walk.
	var style_assets: Array[Dictionary] = [_style_wiring_asset()]
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	application.assets = style_assets
	_weighting_wiring_document(application)
	application.selected_asset_id = "asset_1"
	application.selected_component_id = "component_1"
	_expect(application._component_mesh_status("asset_1", "component_1",
		application.assets[0]["components"][0]) == "Ready",
		"The Weighting wiring fixture should present a Ready Component Mesh.")
	var build_probe := func(case_name: String) -> Node:
		_prepare_style_case(application, case_name)
		return _build_style_probe(application)
	_check_view_wiring({
		"label": "Style Inspector",
		"view": application.style_inspector_view,
		"routes": STYLE_SIGNAL_ROUTES,
		"cases": STYLE_PROBE_CASES,
		"build_probe": build_probe,
	})
	application.free()


func _test_geometry_inspector_wiring() -> void:
	# The Mesh Inspector. Two of its signals reach main.gd through adapter
	# lambdas rather than named handlers, so those two are checked by what the
	# adapter does before the walk covers them with the rest.
	var geometry_assets: Array[Dictionary] = [_geometry_wiring_asset(),
		{"id": "asset_2", "name": "Orb", "visibility": true,
			"components": [], "groups": [], "guides": []}]
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	application.assets = geometry_assets
	var view: GeometryInspectorView = application.geometry_inspector_view

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

	var build_probe := func(case_name: String) -> Node:
		var submodule := _prepare_geometry_case(application, case_name)
		return _build_geometry_probe(application, submodule)
	_check_view_wiring({
		"label": "Mesh Inspector",
		"view": view,
		"routes": GEOMETRY_SIGNAL_ROUTES,
		"adapters": GEOMETRY_ADAPTER_SIGNALS,
		"cases": GEOMETRY_PROBE_CASES,
		"build_probe": build_probe,
	})
	application.free()


func _test_outliner_wiring() -> void:
	# The view that was extracted before the render comparison existed and has
	# had the least verification of the six. Ten Outliner states; the drop is
	# the one signal a walk cannot fire.
	var application: Control = load("res://scripts/main.gd").new()
	application._build_ui()
	application.assets = _outliner_wiring_assets()
	var build_probe := func(case_name: String) -> Node:
		_prepare_outliner_case(application, case_name)
		return _build_outliner_probe(application)
	_check_view_wiring({
		"label": "Outliner",
		"view": application.outliner_view,
		"routes": OUTLINER_SIGNAL_ROUTES,
		"unconnected": OUTLINER_UNCONNECTED_SIGNALS,
		"undrivable": OUTLINER_UNDRIVABLE_SIGNALS,
		"cases": OUTLINER_PROBE_CASES,
		"build_probe": build_probe,
		"exercise": _exercise_outliner_control,
	})
	application.free()