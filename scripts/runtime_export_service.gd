class_name RuntimeExportService
extends RefCounted

const MANIFEST_SCHEMA_VERSION := 2
static func build_manifest(asset: Dictionary, sources: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var registry := SemanticRegistry.load_registry()
	if not bool(registry.get("valid", false)):
		errors.append_array(registry.get("errors", []))
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
	var roles: Dictionary = {}
	for raw_component in asset.get("components", []):
		if not raw_component is Dictionary or not bool(raw_component.get("visibility", true)):
			continue
		var component: Dictionary = raw_component
		var component_id := str(component.get("id", ""))
		var role := str(component.get("semantic_key", "")).strip_edges()
		if component_id.is_empty():
			errors.append("A visible Component has no stable ID.")
		elif ids.has(component_id):
			errors.append("Component ID '%s' is duplicated." % component_id)
		else:
			ids[component_id] = true
		if not SemanticRegistry.contains(registry, role):
			errors.append("%s: Semantic Key is missing from the registry." % _component_label(component))
		elif roles.has(role):
			errors.append("Semantic Key '%s' is duplicated." % role)
		else:
			roles[role] = true
		visible_components.append(component)
	visible_components.sort_custom(_component_less)
	for component in visible_components:
		var parent_id := str(component.get("parent_component_id", ""))
		if not parent_id.is_empty() and not ids.has(parent_id):
			errors.append("%s: parent '%s' is not part of the visible export set." % [_component_label(component), parent_id])
	errors.append_array(_hierarchy_errors(visible_components))
	var manifest_components: Array = []
	var masks: Array = []
	for component in visible_components:
		var component_id := str(component.get("id", ""))
		var source: Dictionary = sources.get(component_id, {})
		var built := _build_reference_component(component, source) if str(component.get("type", "component")) == "reference" else _build_component(component, source)
		errors.append_array(built.get("errors", []))
		if bool(built.get("valid", false)):
			manifest_components.append(built["component"])
			if built.has("mask"):
				masks.append(built["mask"])
	if visible_components.is_empty():
		errors.append("The Asset has no visible Components to export.")
	if not bool(asset.get("visibility", true)):
		errors.append("The Asset is hidden.")
	if not errors.is_empty():
		return {"valid": false, "errors": errors, "manifest": {}, "masks": []}
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
	return {"valid": true, "errors": [], "manifest": manifest, "masks": masks}


static func _build_component(component: Dictionary, source: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var label := _component_label(component)
	var mesh = source.get("mesh", {})
	var uv = source.get("uv", {})
	var sdf = source.get("sdf", {})
	if not mesh is Dictionary or not bool(mesh.get("valid", false)):
		errors.append("%s: a current accepted Component Mesh is required." % label)
		mesh = {}
	if not uv is Dictionary or not bool(uv.get("valid", false)):
		errors.append("%s: a current accepted UV Bake is required." % label)
		uv = {}
	if not sdf is Dictionary or not bool(sdf.get("valid", false)):
		errors.append("%s: a current accepted SDF Bake is required." % label)
		sdf = {}
	if not bool(source.get("sdf_resource_valid", false)):
		errors.append("%s: the accepted SDF image is missing or corrupt." % label)
	var vertices: Array = []
	var vertex_indices: Dictionary = {}
	for raw_vertex in mesh.get("vertices", []):
		if not raw_vertex is Dictionary:
			errors.append("%s: Mesh contains an invalid Vertex record." % label)
			continue
		var vertex_id := str(raw_vertex.get("id", ""))
		var position := Vector2(raw_vertex.get("position", Vector2.INF))
		if vertex_id.is_empty() or vertex_indices.has(vertex_id) or not position.is_finite():
			errors.append("%s: Mesh Vertex IDs and positions must be unique and finite." % label)
			continue
		vertex_indices[vertex_id] = vertices.size()
		vertices.append(_meters(position))
	var uv_by_vertex: Dictionary = {}
	for raw_entry in uv.get("uvs", []):
		if not raw_entry is Dictionary:
			continue
		var vertex_id := str(raw_entry.get("vertex_id", ""))
		var coordinate := Vector2(raw_entry.get("uv", Vector2.INF))
		if vertex_id.is_empty() or uv_by_vertex.has(vertex_id) or not coordinate.is_finite() \
			or coordinate.x < 0.0 or coordinate.x > 1.0 or coordinate.y < 0.0 or coordinate.y > 1.0:
			errors.append("%s: UVs must uniquely map every Vertex ID inside [0, 1]." % label)
			continue
		uv_by_vertex[vertex_id] = [coordinate.x, coordinate.y]
	var ordered_uvs: Array = []
	for raw_vertex in mesh.get("vertices", []):
		var vertex_id := str(raw_vertex.get("id", "")) if raw_vertex is Dictionary else ""
		if not uv_by_vertex.has(vertex_id):
			errors.append("%s: UV for Mesh Vertex '%s' is missing." % [label, vertex_id])
		else:
			ordered_uvs.append(uv_by_vertex[vertex_id])
	if uv_by_vertex.size() != vertex_indices.size():
		errors.append("%s: UV count does not match the accepted Mesh Vertex count." % label)
	var indices: Array[int] = []
	for raw_triangle in mesh.get("triangles", []):
		var triangle_ids: Array = raw_triangle.get("vertex_ids", []) if raw_triangle is Dictionary else []
		if triangle_ids.size() != 3:
			errors.append("%s: every Mesh Triangle must contain exactly three Vertex IDs." % label)
			continue
		var triangle_indices: Array[int] = []
		for vertex_id_variant in triangle_ids:
			var vertex_id := str(vertex_id_variant)
			if not vertex_indices.has(vertex_id):
				errors.append("%s: Triangle references unknown Vertex '%s'." % [label, vertex_id])
			else:
				triangle_indices.append(int(vertex_indices[vertex_id]))
		if triangle_indices.size() == 3:
			if triangle_indices[0] == triangle_indices[1] or triangle_indices[1] == triangle_indices[2] or triangle_indices[0] == triangle_indices[2]:
				errors.append("%s: degenerate Triangle indices are not exportable." % label)
			else:
				indices.append_array(triangle_indices)
	if vertices.is_empty() or indices.is_empty():
		errors.append("%s: Mesh Vertices and Triangles are required." % label)
	var resolution: Array = sdf.get("resolution", []) if sdf is Dictionary else []
	if resolution.size() != 2 or int(resolution[0]) <= 0 or int(resolution[1]) <= 0:
		errors.append("%s: SDF resolution metadata is invalid." % label)
	var transform = component.get("transform", {})
	if not transform is Dictionary:
		transform = {}
	var position := Vector2(transform.get("position", Vector2.ZERO))
	var pivot := Vector2(transform.get("pivot", Vector2.ZERO))
	var scale := Vector2(transform.get("scale", Vector2.ONE))
	var rotation := float(transform.get("rotation", 0.0))
	if not position.is_finite() or not pivot.is_finite() or not scale.is_finite() or not is_finite(rotation):
		errors.append("%s: Component transform is not finite." % label)
	if not errors.is_empty():
		return {"valid": false, "errors": errors}
	var component_id := str(component.get("id", ""))
	var relative_mask_path := "masks/%s.sdf.png" % component_id
	var mask := {
		"component_id": component_id,
		"source_path": str(source.get("sdf_source_path", "")),
		"relative_path": relative_mask_path,
		"pixel_hash": str(sdf.get("pixel_hash", ""))
	}
	if mask["source_path"].is_empty() or mask["pixel_hash"].is_empty():
		return {"valid": false, "errors": ["%s: SDF resource path or pixel hash is missing." % label]}
	return {
		"valid": true,
		"errors": [],
		"component": {
			"component_id": component_id,
			"semantic_key": str(component.get("semantic_key", "")).strip_edges(),
			"parent_component_id": null if str(component.get("parent_component_id", "")).is_empty() else str(component.get("parent_component_id", "")),
			"z_index": int(component.get("z_index", 0)),
			"local_pivot": _meters(pivot),
			"local_transform": {
				"position": _meters(position),
				"rotation_radians": deg_to_rad(rotation),
				"scale": [scale.x, scale.y]
			},
			"mesh": {"vertices": vertices, "indices": indices, "uvs": ordered_uvs},
			"contour_mask": {
				"path": relative_mask_path,
				"type": "signed_distance_field",
				"channel": "r",
				"color_space": "linear",
				"resolution": [int(resolution[0]), int(resolution[1])],
				"spread_px": float(sdf.get("spread_px", 0.0)),
				"boundary_value": float(sdf.get("boundary_value", 0.5)),
				"inside_is_greater": bool(sdf.get("inside_is_greater", true)),
				"uv_origin": "bottom_left",
				"image_origin": "top_left",
				"uv_to_pixel": "x=u*width, y=(1-v)*height",
				"pixel_hash": mask["pixel_hash"]
			}
		},
		"mask": mask
	}


static func _build_reference_component(component: Dictionary, source: Dictionary) -> Dictionary:
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
	var transform = component.get("transform", {})
	if not transform is Dictionary:
		transform = {}
	var position := Vector2(transform.get("position", Vector2.ZERO))
	var pivot := Vector2(transform.get("pivot", Vector2.ZERO))
	var scale := Vector2(transform.get("scale", Vector2.ONE))
	var rotation := float(transform.get("rotation", 0.0))
	if not position.is_finite() or not pivot.is_finite() or not scale.is_finite() or not is_finite(rotation):
		errors.append("%s: Component transform is not finite." % label)
	if not errors.is_empty():
		return {"valid": false, "errors": errors}
	return {
		"valid": true,
		"errors": [],
		"component": {
			"component_id": str(component.get("id", "")),
			"semantic_key": str(component.get("semantic_key", "")),
			"kind": "asset_reference",
			"source_asset_key": source_asset_key,
			"parent_component_id": null if str(component.get("parent_component_id", "")).is_empty() else str(component.get("parent_component_id", "")),
			"z_index": int(component.get("z_index", 0)),
			"local_pivot": _meters(pivot),
			"local_transform": {
				"position": _meters(position),
				"rotation_radians": deg_to_rad(rotation),
				"scale": [scale.x, scale.y]
			}
		}
	}


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


static func _component_label(component: Dictionary) -> String:
	return "%s (%s)" % [str(component.get("semantic_key", "missing_semantic")), str(component.get("id", "missing-id"))]


static func _meters(value: Vector2) -> Array:
	return [value.x * ToolUnits.TO_METERS, value.y * ToolUnits.TO_METERS]
