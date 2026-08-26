class_name RuntimeExportService
extends RefCounted

const MANIFEST_SCHEMA_VERSION := 6
static func build_manifest(asset: Dictionary, sources: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var asset_id := str(asset.get("id", ""))
	if asset_id.is_empty():
		errors.append("Asset ID is missing.")
	var asset_key := AssetCatalogService.asset_key(str(asset.get("name", "")))
	if asset_key.is_empty():
		errors.append("Asset name does not derive a usable lower_snake_case Asset Key.")
	var asset_pivot := Vector2(asset.get("asset_pivot", Vector2.ZERO))
	if not asset_pivot.is_finite():
		errors.append("Asset pivot is not finite.")
	var visible_components: Array[Dictionary] = []
	var ids: Dictionary = {}
	var names: Dictionary = {}
	for raw_component in asset.get("components", []):
		if not raw_component is Dictionary or not _effective_visibility(asset, raw_component):
			continue
		var component: Dictionary = raw_component.duplicate(true)
		component["z_index"] = _effective_z_index(asset, component)
		var component_id := str(component.get("id", ""))
		var component_name := str(component.get("name", "")).strip_edges()
		if component_id.is_empty():
			errors.append("A visible Component has no stable ID.")
		elif ids.has(component_id):
			errors.append("Component ID '%s' is duplicated." % component_id)
		else:
			ids[component_id] = true
		if component_name.is_empty():
			errors.append("%s: Component Name is missing." % _component_label(component))
		elif not _is_lower_snake_case(component_name):
			errors.append("%s: Component Name must use lower_snake_case." % _component_label(component))
		elif names.has(component_name.to_lower()):
			errors.append("Component Name '%s' is duplicated." % component_name)
		else:
			names[component_name.to_lower()] = true
		visible_components.append(component)
	visible_components.sort_custom(_component_less)
	for component in visible_components:
		var parent_id := str(component.get("parent_component_id", ""))
		if not parent_id.is_empty() and not ids.has(parent_id):
			errors.append("%s: parent '%s' is not part of the visible export set." % [_component_label(component), parent_id])
		var authored_transform = component.get("transform", {})
		var authored_scale := Vector2.ONE
		if authored_transform is Dictionary:
			authored_scale = Vector2(authored_transform.get("scale", Vector2.ONE))
		if str(component.get("type", "component")) != "reference" and (not authored_scale.is_finite() or not authored_scale.is_equal_approx(Vector2.ONE)):
			errors.append("%s: Component Scale must be rebased to (1, 1) before Runtime Export." % _component_label(component))
	errors.append_array(_hierarchy_errors(visible_components))
	var export_transforms := _canonical_export_transforms(asset, visible_components)
	var manifest_components: Array = []
	for component in visible_components:
		var component_id := str(component.get("id", ""))
		var source: Dictionary = sources.get(component_id, {})
		var export_transform: Dictionary = export_transforms.get(component_id, {})
		var component_pivot := _global_component_pivot(asset, component)
		var built := _build_reference_component(component, source, export_transform, component_pivot) if str(component.get("type", "component")) == "reference" else _build_component_v4(component, source, export_transform, component_pivot)
		errors.append_array(built.get("errors", []))
		if bool(built.get("valid", false)):
			manifest_components.append(built["component"])
	if visible_components.is_empty():
		errors.append("The Asset has no visible Components to export.")
	if not bool(asset.get("visibility", true)):
		errors.append("The Asset is hidden.")
	if not errors.is_empty():
		return {"valid": false, "errors": errors, "manifest": {}}
	var manifest := {
		"schema_version": MANIFEST_SCHEMA_VERSION,
		"asset_key": asset_key,
		"display_name": str(asset.get("name", asset_id)),
		"asset_type": str(asset.get("asset_type", "character")),
		"coordinate_system": {
			"dimensions": 2,
			"x_axis": "right",
			"y_axis": "up",
			"unit": "meter",
			"tool_unit_in_meters": ToolUnits.TO_METERS,
			"rotation_unit": "radian",
			"positive_rotation": "counter_clockwise",
			"component_transform": "T(position) * R(rotation) * S(scale) * T(-pivot)"
		},
		"z_order": {
			"scope": "global",
			"back_to_front": "ascending",
			"tie_breaker": "component_id_lexicographic"
		},
		"asset_pivot": _meters(asset_pivot),
		"components": manifest_components
	}
	return {"valid": true, "errors": [], "manifest": manifest}


static func _build_component_v4(component: Dictionary, source: Dictionary, export_transform: Dictionary, component_pivot: Vector2) -> Dictionary:
	var errors: Array[String] = []
	var label := _component_label(component)
	var draw_mode := str(component.get("draw_mode", "closed_loop"))
	var authored_transform = component.get("transform", {})
	if not authored_transform is Dictionary:
		authored_transform = {}
	var authored_pivot := Vector2(authored_transform.get("pivot", Vector2.ZERO))
	var stroke = source.get("contour_stroke", {})
	if not stroke is Dictionary or not bool(stroke.get("valid", false)) or str(stroke.get("method", "")) != ContourMeshService.METHOD:
		errors.append("%s: a current accepted Contour Stroke Mesh is required." % label)
		stroke = {}
	var stroke_has_outline := bool(stroke.get("has_outline", false))
	var stroke_mesh := _serialize_indexed_mesh(stroke, authored_pivot, not stroke_has_outline, label, "Contour Stroke")
	errors.append_array(stroke_mesh.get("errors", []))
	errors.append_array(_stroke_run_validation_issues(stroke.get("runs", []), stroke_has_outline, stroke_mesh.get("vertices", []).size(), stroke_mesh.get("indices", []).size(), label))
	var parameters: Dictionary = stroke.get("parameters", {}) if stroke is Dictionary else {}
	var width_px := float(parameters.get("stroke_width_px", 0.0))
	var width_meters := float(parameters.get("stroke_width_meters", 0.0))
	var reference_density := float(parameters.get("reference_pixels_per_meter", 0.0))
	if not is_finite(width_px) or width_px <= 0.0 or not is_finite(width_meters) or width_meters <= 0.0 \
		or not is_equal_approx(reference_density, ContourStrokeService.REFERENCE_PIXELS_PER_METER) \
		or not is_equal_approx(width_meters, width_px / reference_density):
		errors.append("%s: Contour Stroke width metadata is invalid or non-metric." % label)
	if str(parameters.get("join", "")) != ContourStrokeService.JOIN_TYPE or not is_equal_approx(float(parameters.get("miter_limit", 0.0)), ContourStrokeService.MITER_LIMIT) or str(parameters.get("cap", "")) != ContourStrokeService.CAP_TYPE:
		errors.append("%s: Contour Stroke join/cap metadata does not match the authored contract." % label)
	if str(stroke.get("topology_role", component.get("topology_role", "outer"))) not in ["outer", "hole"]:
		errors.append("%s: Contour Stroke topology role must be outer or hole." % label)
	var fill_mesh := {}
	if draw_mode != "contour":
		var mesh = source.get("mesh", {})
		if not mesh is Dictionary or not bool(mesh.get("valid", false)) or str(mesh.get("method", "")) == ContourMeshService.METHOD:
			errors.append("%s: a current accepted Fill Mesh is required." % label)
			mesh = {}
		fill_mesh = _serialize_indexed_mesh(mesh, authored_pivot, false, label, "Fill Mesh")
		errors.append_array(fill_mesh.get("errors", []))
	var position := Vector2(export_transform.get("position", Vector2.ZERO))
	var scale := Vector2(export_transform.get("scale", Vector2.ONE))
	var rotation := float(export_transform.get("rotation", 0.0))
	if not position.is_finite() or not scale.is_finite() or not is_finite(rotation):
		errors.append("%s: Component transform is not finite." % label)
	if not errors.is_empty():
		return {"valid": false, "errors": errors}
	var parent_component_id: Variant = null
	if not str(component.get("parent_component_id", "")).is_empty():
		parent_component_id = str(component.get("parent_component_id", ""))
	var runtime_component := {
		"component_id": str(component.get("id", "")),
		"name": str(component.get("name", "")).strip_edges(),
		"parent_component_id": parent_component_id,
		"z_index": int(component.get("z_index", 0)),
		"component_pivot": _meters(component_pivot),
		"local_transform": {"position": _meters(position), "rotation_radians": deg_to_rad(rotation), "scale": [scale.x, scale.y]},
		"contour_stroke_mesh": {
			"role": "centered_boundary_stroke",
			"has_outline": stroke_has_outline,
			"vertices": stroke_mesh.get("vertices", []),
			"indices": stroke_mesh.get("indices", []),
			"reference_pixels_per_meter": reference_density,
			"stroke_width_px": width_px,
			"stroke_width_meters": width_meters,
			"centerline": "original_authored_boundary",
			"inner_offset_meters": width_meters * 0.5,
			"outer_offset_meters": width_meters * 0.5,
			"join": {"type": ContourStrokeService.JOIN_TYPE, "miter_limit": ContourStrokeService.MITER_LIMIT, "fallback": "bevel"},
			"cap": ContourStrokeService.CAP_TYPE,
			"topology_role": str(stroke.get("topology_role", component.get("topology_role", "outer"))),
			"runs": _serialize_stroke_runs(stroke.get("runs", []))
		}
	}
	if draw_mode != "contour":
		runtime_component["mesh"] = {"vertices": fill_mesh.get("vertices", []), "indices": fill_mesh.get("indices", [])}
	return {"valid": true, "errors": [], "component": runtime_component}


static func _serialize_indexed_mesh(mesh: Dictionary, authored_pivot: Vector2, allow_empty: bool, label: String, role: String) -> Dictionary:
	var errors: Array[String] = []
	var vertices: Array = []
	var vertex_indices: Dictionary = {}
	for raw_vertex in mesh.get("vertices", []):
		if not raw_vertex is Dictionary:
			errors.append("%s: %s contains an invalid Vertex record." % [label, role])
			continue
		var vertex_id := str(raw_vertex.get("id", ""))
		var position := Vector2(raw_vertex.get("position", Vector2.INF))
		if vertex_id.is_empty() or vertex_indices.has(vertex_id) or not position.is_finite():
			errors.append("%s: %s Vertex IDs and positions must be unique and finite." % [label, role])
			continue
		vertex_indices[vertex_id] = vertices.size()
		vertices.append(_meters(position - authored_pivot))
	var indices: Array[int] = []
	for raw_triangle in mesh.get("triangles", []):
		var ids: Array = raw_triangle.get("vertex_ids", []) if raw_triangle is Dictionary else []
		if ids.size() != 3:
			errors.append("%s: %s Triangle must contain exactly three Vertex IDs." % [label, role])
			continue
		var compact: Array[int] = []
		for raw_id in ids:
			if vertex_indices.has(str(raw_id)):
				compact.append(int(vertex_indices[str(raw_id)]))
			else:
				errors.append("%s: %s Triangle references an unknown Vertex." % [label, role])
		if compact.size() == 3:
			if compact[0] == compact[1] or compact[1] == compact[2] or compact[0] == compact[2]:
				errors.append("%s: %s contains degenerate Triangle indices." % [label, role])
			else:
				indices.append_array(compact)
	if not allow_empty and (vertices.is_empty() or indices.is_empty()):
		errors.append("%s: %s Vertices and Triangles are required." % [label, role])
	if allow_empty and (not vertices.is_empty() or not indices.is_empty()):
		errors.append("%s: disabled Contour Stroke must not contain geometry." % label)
	return {"valid": errors.is_empty(), "errors": errors, "vertices": vertices, "indices": indices}


static func _serialize_stroke_runs(raw_runs: Array) -> Array:
	var runs: Array = []
	for raw_run in raw_runs:
		if not raw_run is Dictionary:
			continue
		runs.append({
			"run_id": str(raw_run.get("run_id", "")),
			"edge_ids": raw_run.get("edge_ids", []).duplicate(),
			"closed": bool(raw_run.get("closed", false)),
			"start_cap": str(raw_run.get("start_cap", "butt")),
			"end_cap": str(raw_run.get("end_cap", "butt")),
			"vertex_offset": int(raw_run.get("vertex_offset", 0)),
			"vertex_count": int(raw_run.get("vertex_count", 0)),
			"index_offset": int(raw_run.get("index_offset", 0)),
			"index_count": int(raw_run.get("index_count", 0))
		})
	return runs


static func _stroke_run_validation_issues(raw_runs: Array, has_outline: bool, vertex_count: int, index_count: int, label: String) -> Array[String]:
	var errors: Array[String] = []
	if has_outline and raw_runs.is_empty():
		errors.append("%s: visible Contour Stroke requires at least one typed run." % label)
	if not has_outline and not raw_runs.is_empty():
		errors.append("%s: disabled Contour Stroke must not contain runs." % label)
	for raw_run in raw_runs:
		if not raw_run is Dictionary:
			errors.append("%s: Contour Stroke contains an invalid run record." % label)
			continue
		var vertex_offset := int(raw_run.get("vertex_offset", -1))
		var run_vertex_count := int(raw_run.get("vertex_count", -1))
		var index_offset := int(raw_run.get("index_offset", -1))
		var run_index_count := int(raw_run.get("index_count", -1))
		if str(raw_run.get("run_id", "")).is_empty() or not raw_run.get("edge_ids", []) is Array:
			errors.append("%s: every Contour Stroke run requires an ID and ordered Edge IDs." % label)
		if vertex_offset < 0 or run_vertex_count <= 0 or vertex_offset + run_vertex_count > vertex_count \
			or index_offset < 0 or run_index_count <= 0 or index_offset + run_index_count > index_count or run_index_count % 3 != 0:
			errors.append("%s: Contour Stroke run ranges must resolve inside the combined Mesh." % label)
		var closed := bool(raw_run.get("closed", false))
		var expected_cap := "none" if closed else ContourStrokeService.CAP_TYPE
		if str(raw_run.get("start_cap", "")) != expected_cap or str(raw_run.get("end_cap", "")) != expected_cap:
			errors.append("%s: Contour Stroke run cap metadata is inconsistent." % label)
	return errors


static func _build_reference_component(component: Dictionary, source: Dictionary, export_transform: Dictionary, component_pivot: Vector2) -> Dictionary:
	var errors: Array[String] = []
	var label := _component_label(component)
	var source_asset_id := str(component.get("source_asset_id", ""))
	if source_asset_id.is_empty() or not bool(source.get("source_asset_exists", false)):
		errors.append("%s: referenced source Asset is missing." % label)
	var source_asset_key := str(source.get("source_asset_key", ""))
	if source_asset_key.is_empty():
		errors.append("%s: referenced source Asset has no usable Asset Key." % label)
	if source_asset_id == str(source.get("owner_asset_id", "")):
		errors.append("%s: an Asset cannot reference itself." % label)
	var position := Vector2(export_transform.get("position", Vector2.ZERO))
	var pivot := Vector2.ZERO
	var scale := Vector2(export_transform.get("scale", Vector2.ONE))
	var rotation := float(export_transform.get("rotation", 0.0))
	if not position.is_finite() or not pivot.is_finite() or not scale.is_finite() or not is_finite(rotation):
		errors.append("%s: Component transform is not finite." % label)
	elif is_zero_approx(scale.x) or is_zero_approx(scale.y):
		errors.append("%s: Reference Scale axes must be non-zero." % label)
	if not errors.is_empty():
		return {"valid": false, "errors": errors}
	var parent_component_id: Variant = null
	if not str(component.get("parent_component_id", "")).is_empty():
		parent_component_id = str(component.get("parent_component_id", ""))
	return {
		"valid": true,
		"errors": [],
		"component": {
			"component_id": str(component.get("id", "")),
			"name": str(component.get("name", "")),
			"kind": "asset_reference",
			"source_asset_key": source_asset_key,
			"parent_component_id": parent_component_id,
			"z_index": int(component.get("z_index", 0)),
			"component_pivot": _meters(component_pivot),
			"local_transform": {
				"position": _meters(position),
				"rotation_radians": deg_to_rad(rotation),
				"scale": [scale.x, scale.y]
			}
		}
	}


static func _canonical_export_transforms(asset: Dictionary, components: Array[Dictionary]) -> Dictionary:
	# Keep the visible world geometry unchanged while changing the coordinate
	# origin of every Component to its local pivot.  Deriving each local affine
	# from its parent's canonical affine is what makes child positions genuinely
	# parent-relative instead of duplicating asset-space coordinates.
	var world_by_id: Dictionary = {}
	for component in components:
		var component_id := str(component.get("id", ""))
		var transform = component.get("transform", {})
		if not transform is Dictionary:
			transform = {}
		var pivot := Vector2(transform.get("pivot", Vector2.ZERO))
		world_by_id[component_id] = ComponentHierarchy.world_transform(asset, component_id) * Transform2D(0.0, pivot)
	var result: Dictionary = {}
	for component in components:
		var component_id := str(component.get("id", ""))
		var parent_id := str(component.get("parent_component_id", ""))
		var parent_world: Transform2D = world_by_id.get(parent_id, Transform2D.IDENTITY)
		var local_affine: Transform2D = parent_world.affine_inverse() * world_by_id.get(component_id, Transform2D.IDENTITY)
		result[component_id] = ComponentHierarchy.transform_record_from_affine(local_affine, Vector2.ZERO)
	return result


static func _global_component_pivot(asset: Dictionary, component: Dictionary) -> Vector2:
	var component_id := str(component.get("id", ""))
	var authored_transform = component.get("transform", {})
	if not authored_transform is Dictionary:
		authored_transform = {}
	var local_pivot := Vector2(authored_transform.get("pivot", Vector2.ZERO))
	var global_position := ComponentHierarchy.world_transform(asset, component_id) * local_pivot
	return global_position - Vector2(asset.get("asset_pivot", Vector2.ZERO))


static func _hierarchy_errors(components: Array[Dictionary]) -> Array[String]:
	var errors: Array[String] = []
	var parent_by_id: Dictionary = {}
	for component in components:
		parent_by_id[str(component.get("id", ""))] = str(component.get("parent_component_id", ""))
	for component_id in parent_by_id:
		var seen: Dictionary = {}
		var cursor := str(component_id)
		while not cursor.is_empty() and parent_by_id.has(cursor):
			if seen.has(cursor):
				errors.append("Component hierarchy contains a cycle at '%s'." % cursor)
				break
			seen[cursor] = true
			cursor = str(parent_by_id[cursor])
	return errors


static func _component_less(a: Dictionary, b: Dictionary) -> bool:
	var z_a := int(a.get("z_index", 0))
	var z_b := int(b.get("z_index", 0))
	return str(a.get("id", "")) < str(b.get("id", "")) if z_a == z_b else z_a < z_b


static func _effective_group(asset: Dictionary, component: Dictionary) -> Dictionary:
	var group_id := str(component.get("group_id", ""))
	if group_id.is_empty():
		return {}
	for group in asset.get("groups", []):
		if group is Dictionary and str(group.get("id", "")) == group_id:
			return group
	return {}


static func _effective_visibility(asset: Dictionary, component: Dictionary) -> bool:
	var group := _effective_group(asset, component)
	return bool(component.get("visibility", true)) and (group.is_empty() or bool(group.get("visibility", true)))


static func _effective_z_index(_asset: Dictionary, component: Dictionary) -> int:
	return int(component.get("z_index", 0))


static func _component_label(component: Dictionary) -> String:
	return "%s (%s)" % [str(component.get("name", "Component")), str(component.get("id", "missing-id"))]


static func _is_lower_snake_case(value: String) -> bool:
	if value.is_empty() or value.begins_with("_") or value.ends_with("_") or value.contains("__"):
		return false
	for character in value:
		var code := character.unicode_at(0)
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			return false
	var first := value.unicode_at(0)
	return first >= 97 and first <= 122


static func _meters(value: Vector2) -> Array:
	return [value.x * ToolUnits.TO_METERS, value.y * ToolUnits.TO_METERS]
