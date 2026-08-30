class_name RuntimeExportService
extends RefCounted

const MANIFEST_SCHEMA_VERSION := 14
const DEFAULT_PROJECTION_DEPTH_CM := 10.0
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
	var root_scale := AssetScaleRebaseService.root_scale(asset)
	if not AssetScaleRebaseService.is_valid_root_scale(asset) or not root_scale.is_equal_approx(Vector2.ONE):
		errors.append("Root Asset Scale must be rebased to 1 before Runtime Export.")
	var root_position := Vector2(asset.get("root_position", Vector2.ZERO))
	if not root_position.is_finite() or not root_position.is_zero_approx():
		errors.append("Root Asset Position must be rebased to (0, 0) before Runtime Export.")
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
		var built := _build_reference_component(component, source, export_transform, component_pivot) if str(component.get("type", "component")) == "reference" else _build_component_v8(component, source, export_transform, component_pivot)
		errors.append_array(built.get("errors", []))
		if bool(built.get("valid", false)):
			manifest_components.append(built["component"])
	if visible_components.is_empty():
		errors.append("The Asset has no visible Components to export.")
	if not bool(asset.get("visibility", true)):
		errors.append("The Asset is hidden.")
	if not errors.is_empty():
		return {"valid": false, "errors": errors, "manifest": {}}
	var attachment_frames_build := _build_attachment_frames(asset)
	errors.append_array(attachment_frames_build.get("errors", []))
	if not errors.is_empty():
		return {"valid": false, "errors": errors, "manifest": {}}
	var manifest := {
		"schema_version": MANIFEST_SCHEMA_VERSION,
		"asset_key": asset_key,
		"display_name": str(asset.get("name", asset_id)),
		"asset_type": str(asset.get("asset_type", "character")),
		"presentation": {
			"authored_facing": AssetPresentation.serialize_authored_facing(asset.get("authored_facing", AssetPresentation.AuthoredFacing.NEUTRAL))
		},
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
		"components": manifest_components,
		"attachment_frames": attachment_frames_build.get("items", [])
	}
	var manifest_issues := manifest_validation_issues(manifest)
	if not manifest_issues.is_empty():
		return {"valid": false, "errors": manifest_issues, "manifest": {}}
	return {"valid": true, "errors": [], "manifest": manifest}


static func _build_attachment_frames(asset: Dictionary) -> Dictionary:
	var items: Array = []
	var errors: Array[String] = []
	var roles: Dictionary = {}
	for raw_guide in asset.get("guides", []):
		if not raw_guide is Dictionary or not AssetGuide.is_weapon_frame(str(raw_guide.get("guide_type", ""))):
			continue
		var guide := AssetGuide.normalize(raw_guide)
		var role := str(guide.get("guide_type", ""))
		if str(guide.get("id", "")).is_empty():
			errors.append("Attachment Frame role '%s' has no stable ID." % role)
			continue
		if roles.has(role):
			errors.append("Attachment Frame role '%s' is duplicated." % role)
			continue
		roles[role] = true
		var issues := AssetGuide.validation_issues(guide)
		if not issues.is_empty():
			errors.append("%s: %s" % [role, issues[0]])
			continue
		var scope: Dictionary = guide.get("scope", {})
		var is_group_scope := str(scope.get("kind", "component")) == "group"
		var scope_id := str(scope.get("group_id", "")) if is_group_scope else str(scope.get("component_id", ""))
		var scope_exists := not ComponentHierarchy.group_by_id(asset, scope_id).is_empty() if is_group_scope else not ComponentHierarchy.component_by_id(asset, scope_id).is_empty()
		if not scope_exists:
			errors.append("%s: authored scope '%s' does not exist." % [role, scope_id])
			continue
		var scope_world := ComponentHierarchy.group_world_transform(asset, scope_id) if is_group_scope else ComponentHierarchy.world_transform(asset, scope_id)
		var world := scope_world * ComponentHierarchy.local_transform(guide.get("transform", {}))
		items.append({
			"frame_id": str(guide.get("id", "")),
			"role": role,
			"asset_transform": {
				"position": _meters(world.origin),
				"rotation_radians": world.get_rotation()
			}
		})
	items.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("role", "")) < str(right.get("role", "")))
	return {"items": items, "errors": errors}


static func _build_component_v8(component: Dictionary, source: Dictionary, export_transform: Dictionary, component_pivot: Vector2) -> Dictionary:
	var errors: Array[String] = []
	var label := _component_label(component)
	var draw_mode := str(component.get("draw_mode", "closed_loop"))
	var authored_transform = component.get("transform", {})
	if not authored_transform is Dictionary:
		authored_transform = {}
	var authored_pivot := Vector2(authored_transform.get("pivot", Vector2.ZERO))
	var projection_depth_corners := _serialize_projection_depth_corners(component.get("points", []), authored_pivot, label)
	errors.append_array(projection_depth_corners.get("errors", []))
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
	var closed_region_mesh := {}
	var chains: Array = component.get("chains", [])
	var requires_closed_region := draw_mode == "contour" and chains.size() == 1 and bool(chains[0].get("closed", false))
	if requires_closed_region:
		var closed_region = stroke.get("closed_region", {})
		if not closed_region is Dictionary or not bool(closed_region.get("valid", false)) or int(closed_region.get("algorithm_version", 0)) != ClosedRegionMeshService.ALGORITHM_VERSION:
			errors.append("%s: a current accepted Closed Contour Region Mesh is required." % label)
			closed_region = {}
		closed_region_mesh = _serialize_indexed_mesh(closed_region, authored_pivot, false, label, "Closed Contour Region Mesh")
		errors.append_array(closed_region_mesh.get("errors", []))
		errors.append_array(_triangle_geometry_validation_issues(closed_region_mesh.get("vertices", []), closed_region_mesh.get("indices", []), label, "Closed Contour Region Mesh"))
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
		"projection_depth_meters": maxf(0.0, float(component.get("projection_depth_cm", DEFAULT_PROJECTION_DEPTH_CM))) * 0.01,
		"projection_depth_corners": projection_depth_corners.get("items", []),
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
	if requires_closed_region:
		runtime_component["closed_region_mesh"] = {
			"role": "closed_contour_region",
			"vertices": closed_region_mesh.get("vertices", []),
			"indices": closed_region_mesh.get("indices", [])
		}
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


static func _triangle_geometry_validation_issues(vertices: Array, indices: Array, label: String, role: String) -> Array[String]:
	var errors: Array[String] = []
	if indices.is_empty() or indices.size() % 3 != 0:
		errors.append("%s: %s requires a complete non-empty triangle index list." % [label, role])
		return errors
	for offset in range(0, indices.size(), 3):
		var raw_first = indices[offset]
		var raw_second = indices[offset + 1]
		var raw_third = indices[offset + 2]
		if typeof(raw_first) not in [TYPE_INT, TYPE_FLOAT] or typeof(raw_second) not in [TYPE_INT, TYPE_FLOAT] or typeof(raw_third) not in [TYPE_INT, TYPE_FLOAT] \
			or not is_finite(float(raw_first)) or not is_finite(float(raw_second)) or not is_finite(float(raw_third)) \
			or float(raw_first) != floorf(float(raw_first)) or float(raw_second) != floorf(float(raw_second)) or float(raw_third) != floorf(float(raw_third)):
			errors.append("%s: %s contains a non-integer triangle index." % [label, role])
			continue
		var first := int(raw_first)
		var second := int(raw_second)
		var third := int(raw_third)
		if first < 0 or second < 0 or third < 0 or first >= vertices.size() or second >= vertices.size() or third >= vertices.size():
			errors.append("%s: %s contains an out-of-range triangle index." % [label, role])
			continue
		if first == second or second == third or first == third:
			errors.append("%s: %s contains degenerate triangle indices." % [label, role])
			continue
		if not vertices[first] is Array or not vertices[second] is Array or not vertices[third] is Array:
			errors.append("%s: %s triangle coordinates are malformed." % [label, role])
			continue
		var a_data: Array = vertices[first]
		var b_data: Array = vertices[second]
		var c_data: Array = vertices[third]
		if a_data.size() != 2 or b_data.size() != 2 or c_data.size() != 2 \
			or typeof(a_data[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(a_data[1]) not in [TYPE_INT, TYPE_FLOAT] \
			or typeof(b_data[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(b_data[1]) not in [TYPE_INT, TYPE_FLOAT] \
			or typeof(c_data[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(c_data[1]) not in [TYPE_INT, TYPE_FLOAT]:
			errors.append("%s: %s triangle coordinates are malformed." % [label, role])
			continue
		var a := Vector2(float(a_data[0]), float(a_data[1]))
		var b := Vector2(float(b_data[0]), float(b_data[1]))
		var c := Vector2(float(c_data[0]), float(c_data[1]))
		if not a.is_finite() or not b.is_finite() or not c.is_finite() or absf((b - a).cross(c - a)) <= ContourStrokeService.GEOMETRY_EPSILON * ToolUnits.TO_METERS * ToolUnits.TO_METERS:
			errors.append("%s: %s contains a non-finite or degenerate triangle." % [label, role])
	return errors


static func manifest_validation_issues(manifest: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var schema_version = manifest.get("schema_version")
	if typeof(schema_version) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(schema_version)) or float(schema_version) != float(MANIFEST_SCHEMA_VERSION):
		errors.append("Runtime Manifest schema_version must be the integer %d." % MANIFEST_SCHEMA_VERSION)
	if str(manifest.get("asset_key", "")).is_empty() or not manifest.get("components", null) is Array:
		errors.append("Runtime Manifest requires an Asset Key and Component array.")
		return errors
	if not manifest.get("attachment_frames", null) is Array:
		errors.append("Runtime Manifest schema 14 requires an attachment_frames array.")
		return errors
	var presentation = manifest.get("presentation")
	if not presentation is Dictionary or presentation.keys() != ["authored_facing"] \
		or str(presentation.get("authored_facing", "")) not in AssetPresentation.SERIALIZED_VALUES:
		errors.append("Runtime Manifest presentation must contain exactly one valid authored_facing value.")
	for raw_component in manifest.get("components", []):
		if not raw_component is Dictionary:
			errors.append("Runtime Manifest contains an invalid Component record.")
			continue
		var component: Dictionary = raw_component
		var label := str(component.get("name", component.get("component_id", "Component")))
		if str(component.get("kind", "")) == "asset_reference":
			if component.has("mesh") or component.has("contour_stroke_mesh") or component.has("closed_region_mesh") or component.has("projection_depth_corners"):
				errors.append("%s: Asset References must not contain owned geometry meshes." % label)
			continue
		if not component.get("contour_stroke_mesh", null) is Dictionary:
			errors.append("%s: ordinary Runtime Components require contour_stroke_mesh." % label)
		errors.append_array(_projection_depth_corner_validation_issues(component.get("projection_depth_corners", null), label))
		if component.has("closed_region_mesh"):
			var region = component.get("closed_region_mesh")
			if not region is Dictionary:
				errors.append("%s: closed_region_mesh must be an object." % label)
				continue
			var region_keys: Array = region.keys()
			region_keys.sort()
			if region_keys != ["indices", "role", "vertices"]:
				errors.append("%s: closed_region_mesh may contain only role, vertices, and indices." % label)
			if str(region.get("role", "")) != "closed_contour_region":
				errors.append("%s: closed_region_mesh role must be closed_contour_region." % label)
			var vertices = region.get("vertices", null)
			var indices = region.get("indices", null)
			if not vertices is Array or not indices is Array:
				errors.append("%s: closed_region_mesh requires Vertex and index arrays." % label)
			else:
				for vertex in vertices:
					if not vertex is Array or vertex.size() != 2 or typeof(vertex[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(vertex[1]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(vertex[0])) or not is_finite(float(vertex[1])):
						errors.append("%s: closed_region_mesh vertices must be finite two-number arrays." % label)
						break
				for index in indices:
					if typeof(index) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(index)) or float(index) != floorf(float(index)):
						errors.append("%s: closed_region_mesh indices must be integers." % label)
						break
				errors.append_array(_triangle_geometry_validation_issues(vertices, indices, label, "closed_region_mesh"))
	var frame_roles: Dictionary = {}
	for raw_frame in manifest.get("attachment_frames", []):
		if not raw_frame is Dictionary:
			errors.append("Runtime Manifest contains an invalid Attachment Frame record.")
			continue
		var role := str(raw_frame.get("role", ""))
		var frame_keys: Array = raw_frame.keys()
		frame_keys.sort()
		if frame_keys != ["asset_transform", "frame_id", "role"] or role not in AssetGuide.WEAPON_TYPES or frame_roles.has(role):
			errors.append("Attachment Frames require unique known roles and exactly frame_id, role, and asset_transform.")
			continue
		frame_roles[role] = true
		var frame_transform = raw_frame.get("asset_transform")
		if not frame_transform is Dictionary or not frame_transform.get("position", null) is Array or frame_transform.get("position", []).size() != 2 or typeof(frame_transform.get("rotation_radians", null)) not in [TYPE_INT, TYPE_FLOAT]:
			errors.append("Attachment Frame asset_transform is invalid.")
	return errors


static func _serialize_projection_depth_corners(raw_points: Array, authored_pivot: Vector2, label: String) -> Dictionary:
	var items: Array = []
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}
	for raw_point in raw_points:
		if not raw_point is Dictionary or str(raw_point.get("mode", "")) != "corner":
			continue
		var point: Dictionary = raw_point
		var point_id := str(point.get("id", ""))
		var position := Vector2(point.get("position", Vector2.INF))
		if point_id.is_empty() or seen_ids.has(point_id):
			errors.append("%s: projection-depth Corner Point IDs must be unique and non-empty." % label)
			continue
		if not position.is_finite():
			errors.append("%s: projection-depth Corner Point positions must be finite." % label)
			continue
		seen_ids[point_id] = true
		items.append({"point_id": point_id, "position": _meters(position - authored_pivot)})
	return {"items": items, "errors": errors}


static func _projection_depth_corner_validation_issues(raw_corners, label: String) -> Array[String]:
	var errors: Array[String] = []
	if not raw_corners is Array:
		errors.append("%s: ordinary Runtime Components require a projection_depth_corners array." % label)
		return errors
	var ids: Dictionary = {}
	for raw_corner in raw_corners:
		if not raw_corner is Dictionary:
			errors.append("%s: projection_depth_corners contains an invalid Corner Point record." % label)
			continue
		var corner: Dictionary = raw_corner
		var keys: Array = corner.keys()
		keys.sort()
		if keys != ["point_id", "position"]:
			errors.append("%s: every projection-depth Corner Point requires exactly point_id and position." % label)
			continue
		var point_id := str(corner.get("point_id", ""))
		var position = corner.get("position", null)
		if point_id.is_empty() or ids.has(point_id):
			errors.append("%s: projection-depth Corner Point IDs must be unique and non-empty." % label)
			continue
		if not position is Array or position.size() != 2 or typeof(position[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(position[1]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(position[0])) or not is_finite(float(position[1])):
			errors.append("%s: projection-depth Corner Point positions must be finite two-number arrays." % label)
			continue
		ids[point_id] = true
	return errors


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
	var result := {
		"valid": true,
		"errors": [],
		"component": {
			"component_id": str(component.get("id", "")),
			"name": str(component.get("name", "")),
			"kind": "asset_reference",
			"source_asset_key": source_asset_key,
			"parent_component_id": parent_component_id,
			"z_index": int(component.get("z_index", 0)),
			"projection_depth_meters": maxf(0.0, float(component.get("projection_depth_cm", DEFAULT_PROJECTION_DEPTH_CM))) * 0.01,
			"component_pivot": _meters(component_pivot),
			"local_transform": {
				"position": _meters(position),
				"rotation_radians": deg_to_rad(rotation),
				"scale": [scale.x, scale.y]
			}
		}
	}
	if component.has("contour_stroke_width_px"):
		var local_width = component.get("contour_stroke_width_px")
		if typeof(local_width) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(local_width)) or float(local_width) <= 0.0:
			return {"valid": false, "errors": ["%s: Reference Contour Stroke Width must be finite and positive." % label]}
		result["component"]["contour_stroke_width_override_px"] = float(local_width)
	return result


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
	var group_id := ComponentHierarchy.membership_group_id(asset, str(component.get("id", "")))
	if group_id.is_empty():
		return {}
	for group in asset.get("groups", []):
		if group is Dictionary and str(group.get("id", "")) == group_id:
			return group
	return {}


static func _effective_visibility(asset: Dictionary, component: Dictionary) -> bool:
	var group := _effective_group(asset, component)
	if component.is_empty() or not bool(component.get("visibility", true)):
		return false
	if group.is_empty():
		return true
	if not bool(group.get("visibility", true)):
		return false
	var parent_component_id := ComponentHierarchy.group_parent_id(group)
	return parent_component_id.is_empty() or _effective_visibility(asset, ComponentHierarchy.component_by_id(asset, parent_component_id))


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
