# Runtime Export render probe.
#
# The Export module is not an Inspector state: it replaces the central work
# surface and hides the Outliner, the Inspector and the Context Bar, so it
# cannot be captured by tools/inspector_render_probe.gd. This probe renders the
# Export surface in ten fixed states and prints one line per observation --
# workspace and panel visibility, the summary line, the Consumer Sync hint, the
# Preflight log, and every toolbar Button with its caption, visibility, disabled
# state and attention count. It asserts nothing on its own. It is run before and
# after a change that is meant to leave the Export surface alone, and the two
# outputs are diffed:
#
#   godot --headless --path . --script tools/runtime_export_render_probe.gd > before.txt
#   ...make the change...
#   godot --headless --path . --script tools/runtime_export_render_probe.gd > after.txt
#   diff before.txt after.txt
#
# Any difference is a rendering change. Watch stderr for SCRIPT ERROR as well:
# a parse error here means the probe rendered nothing and the empty diff means
# nothing.
#
# The states cover: a Preflight that is stale against the last document change;
# everything current; pending Mesh and Runtime work; blocked candidates with
# attention entries; both together; a running Export; a running Mesh batch; a
# completed Consumer Sync; and the switch from Export back into Create and into
# Motion, where the ordinary work surfaces have to come back -- Motion because
# it returns before the branch that shows the Outliner and the Inspector
# unconditionally. When a render path is added, add the state that reaches it.
#
# The fixture is entirely synthetic and the probe only renders. It never reads
# or writes anything under worlds/, never builds a Runtime package or a Catalog,
# never presses a Button, and never starts a batch, an Export, a Save or a
# Consumer Sync. world_name stays empty on purpose: that is what keeps the real
# staleness checks -- which would otherwise stat the export directory -- away
# from the file system.

extends SceneTree


func _flat(text: String) -> String:
	# One observation per line, so a multi-line caption or tooltip cannot break
	# the diff into unrelated lines.
	return text.replace("\n", "\\n")


func _button_line(label: String, button: Button) -> String:
	if not is_instance_valid(button):
		return "B|%s|<missing>" % label
	var attention := -1
	if button is BatchStatusButton:
		attention = (button as BatchStatusButton).attention_count
	return "B|%s|%s|visible=%s|disabled=%s|attention=%d|T:%s" % [
		label, _flat(button.text), str(button.visible), str(button.disabled),
		attention, _flat(button.tooltip_text)]


func _visibility_line(label: String, node) -> String:
	if not is_instance_valid(node):
		return "V|%s|<missing>" % label
	return "V|%s|%s" % [label, str(node.visible)]


func _observe(app: Control) -> Array:
	var out: Array = []
	out.append(_visibility_line("export_workspace", app.runtime_export_view))
	out.append(_visibility_line("outliner_panel", app.outliner_panel))
	out.append(_visibility_line("inspector_panel", app.inspector_panel))
	out.append(_visibility_line("context_bar_panel", app.context_bar_panel))
	out.append(_visibility_line("canvas_view", app.canvas_view))
	out.append("L|summary|%s" % _flat(app.runtime_export_view.summary_label.text))
	out.append("L|consumer_sync|%s" % _flat(app.runtime_export_view.consumer_sync_label.text))
	out.append(_button_line("build_all", app.export_run_button))
	out.append(_button_line("export_all_valid", app.export_valid_button))
	out.append(_button_line("sync_consumers", app.export_sync_button))
	out.append(_button_line("update_meshes", app.update_meshes_button))
	var mesh: Dictionary = app.export_preflight.get("mesh", {})
	var runtime: Dictionary = app.export_preflight.get("runtime", {})
	out.append("N|mesh_candidates|%d" % (mesh.get("candidates", []) as Array).size())
	out.append("N|runtime_candidates|%d" % (runtime.get("candidates", []) as Array).size())
	out.append("N|mesh_attention|%d" % app._export_attention_count(mesh))
	out.append("N|runtime_attention|%d" % app._export_attention_count(runtime))
	out.append("N|build_count|%d" % app._export_build_count())
	out.append("N|valid_count|%d" % app._export_valid_count())
	# The conditions that decide which branch was taken, so a state is never
	# mistaken for another one that happens to render the same.
	out.append("N|export_running|%s" % str(app.export_running))
	out.append("N|mesh_batch_running|%s" % str(app.mesh_batch_running))
	out.append("N|preflight_current|%s" % str(app.export_preflight_revision == app.batch_status_revision))
	out.append("N|batch_mesh_candidates|%d" % (
		app.batch_status_snapshot.get("mesh", {}).get("candidates", []) as Array).size())
	for line in str(app.runtime_export_view.log_label.get_parsed_text()).split("\n"):
		out.append("P|%s" % line)
	return out


func _summary(pending: PackedStringArray, attention: PackedStringArray) -> Dictionary:
	return {"pending": pending, "attention": attention}


func _package_candidate(asset_id: String, valid: bool, error: String) -> Dictionary:
	return {"kind": "package", "asset_id": asset_id,
		"build": {"valid": valid, "errors": [] if error.is_empty() else [error], "manifest": {}}}


func _mesh_candidate(asset_id: String, component_id: String) -> Dictionary:
	return {"asset_id": asset_id, "component_id": component_id}


func _empty_snapshot() -> Dictionary:
	return {
		"mesh": {"candidates": [], "summary": _summary(PackedStringArray(), PackedStringArray())},
		"runtime": {"candidates": [], "summary": _summary(PackedStringArray(), PackedStringArray())},
	}


func _pending_snapshot() -> Dictionary:
	return {
		"mesh": {"candidates": [_mesh_candidate("asset_1", "component_1"),
				_mesh_candidate("asset_1", "component_2")],
			"summary": _summary(PackedStringArray(["Wizard / body", "Wizard / arm"]),
				PackedStringArray())},
		"runtime": {"candidates": [_package_candidate("asset_1", true, ""),
				_package_candidate("asset_2", true, ""),
				{"kind": "catalog", "asset_id": "",
					"build": {"valid": true, "errors": [], "catalog": {}}}],
			"summary": _summary(PackedStringArray(["Wizard — package missing or stale",
				"Orb — package missing or stale",
				"World Catalog — catalog.json missing or stale"]), PackedStringArray())},
	}


func _blocked_snapshot() -> Dictionary:
	return {
		"mesh": {"candidates": [],
			"summary": _summary(PackedStringArray(),
				PackedStringArray(["Wizard / body — The Component needs one Chain."]))},
		"runtime": {"candidates": [],
			"summary": _summary(PackedStringArray(),
				PackedStringArray(["Orb — Component name is not unique.",
					"World Catalog — Asset Key 'orb' is already used."]))},
	}


func _mixed_snapshot() -> Dictionary:
	return {
		"mesh": {"candidates": [_mesh_candidate("asset_1", "component_1")],
			"summary": _summary(PackedStringArray(["Wizard / body"]),
				PackedStringArray(["Wizard / arm — The Component needs one Chain."]))},
		"runtime": {"candidates": [_package_candidate("asset_1", true, ""),
				_package_candidate("asset_2", false, "Component name is not unique.")],
			"summary": _summary(PackedStringArray(["Wizard — package missing or stale"]),
				PackedStringArray(["Orb — Component name is not unique."]))},
	}


func _batch_snapshot(mesh_candidates: Array, attention: PackedStringArray) -> Dictionary:
	# What the persistent toolbar Buttons read. It is deliberately separate from
	# the Export Preflight: the Update Meshes Button keeps its own caption while
	# a batch runs, and that freeze is only visible against a snapshot that has
	# since changed.
	return {
		"mesh": {"candidates": mesh_candidates,
			"summary": _summary(PackedStringArray(), attention)},
		"uv": {"candidates": [], "summary": _summary(PackedStringArray(), PackedStringArray())},
		"sdf": {"candidates": [], "summary": _summary(PackedStringArray(), PackedStringArray())},
		"runtime": {"candidates": [], "summary": _summary(PackedStringArray(), PackedStringArray())},
	}


func _apply(app: Control, snapshot: Dictionary, current: bool, batch: Dictionary) -> void:
	app.export_preflight = snapshot
	app.batch_status_revision += 1
	app.export_preflight_revision = app.batch_status_revision if current else app.batch_status_revision - 1
	app.batch_status_snapshot = batch
	app.batch_status_snapshot_revision = app.batch_status_revision


func _render_export_state(app: Control) -> void:
	# The Export surface renders through the Preflight, exactly as the module
	# does; the Context Bar render is what keeps the ordinary toolbar in step.
	app._render_export_preflight()
	app._update_meshes_button()


func _init() -> void:
	var app: Control = load("res://scripts/main.gd").new()
	app._build_ui()
	# No World: every staleness check resolves to an empty path and returns
	# without touching the file system.
	app.world_name = ""
	app.world_title = ""
	app.assets = [] as Array[Dictionary]
	app.active_module = "Export"
	app.runtime_export_view.visible = true
	app.outliner_panel.visible = false
	app.inspector_panel.visible = false
	app.context_bar_panel.visible = false
	app.canvas_view.visible = false

	var quiet_batch := _batch_snapshot([], PackedStringArray())
	var busy_batch := _batch_snapshot([_mesh_candidate("asset_1", "component_1"),
		_mesh_candidate("asset_1", "component_2")],
		PackedStringArray(["Wizard / arm — The Component needs one Chain."]))
	var states: Array = [
		# A Preflight that is older than the last document change: the snapshot
		# still holds candidates, but the toolbar must not offer to act on them.
		{"name": "preflight_stale", "snapshot": _pending_snapshot(), "current": false,
			"batch": quiet_batch},
		{"name": "all_current", "snapshot": _empty_snapshot(), "current": true,
			"batch": quiet_batch},
		{"name": "pending_work", "snapshot": _pending_snapshot(), "current": true,
			"batch": busy_batch},
		{"name": "blocked_only", "snapshot": _blocked_snapshot(), "current": true,
			"batch": quiet_batch},
		{"name": "mixed", "snapshot": _mixed_snapshot(), "current": true,
			"batch": busy_batch},
		{"name": "export_running", "snapshot": _mixed_snapshot(), "current": true,
			"batch": busy_batch, "export_running": true},
		# The Mesh batch froze the Update Meshes Button: its snapshot is empty
		# again, but the caption and attention point must stay as they were.
		{"name": "mesh_batch_running", "snapshot": _pending_snapshot(), "current": true,
			"batch": quiet_batch, "mesh_batch_running": true},
		{"name": "consumer_sync_done", "snapshot": _empty_snapshot(), "current": true,
			"batch": quiet_batch,
			"sync_result": {"success": true, "output": "", "exit_code": 0}},
	]
	for state in states:
		app.export_running = bool(state.get("export_running", false))
		app.mesh_batch_running = bool(state.get("mesh_batch_running", false))
		app.runtime_export_batch_running = false
		_apply(app, state["snapshot"], bool(state["current"]), state["batch"])
		_render_export_state(app)
		if state.has("sync_result"):
			app._present_consumer_sync_result(state["sync_result"])
		print("### Export/%s" % str(state["name"]))
		for line in _observe(app):
			print(line)

	# Leaving the module has to give the ordinary work surfaces back. This is the
	# only state driven through the real canvas and Context Bar renders.
	app.export_running = false
	app.mesh_batch_running = false
	app.active_module = "Create"
	app.active_create_submodule = "Single"
	app._render_canvas_context()
	app._render_context_bar()
	print("### Export/left_for_create")
	for line in _observe(app):
		print(line)

	# Motion leaves the canvas render before the branch that shows the Outliner
	# and the Inspector unconditionally, so it is the state in which the
	# Export-specific restore is the only thing that can bring them back.
	app.active_module = "Export"
	app._render_canvas_context()
	app.active_module = "Motion"
	app.active_motion_submodule = "Path"
	app._render_canvas_context()
	app._render_context_bar()
	print("### Export/left_for_motion")
	for line in _observe(app):
		print(line)

	app.free()
	quit(0)
