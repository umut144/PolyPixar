class_name RuntimeExportService
extends RefCounted

const MANIFEST_SCHEMA_VERSION := 3
const GAME00_REFERENCE_VERTICAL_METERS := 9.375
const GAME00_REFERENCE_WINDOW_HEIGHT_PX := 800.0
const MIN_OUTER_CONTOUR_PADDING_SCREEN_PX := 16.0
const MIN_OUTER_CONTOUR_PADDING_METERS := GAME00_REFERENCE_VERTICAL_METERS / GAME00_REFERENCE_WINDOW_HEIGHT_PX * MIN_OUTER_CONTOUR_PADDING_SCREEN_PX
const AFFINE_EPSILON := 0.000001
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
	var export_transforms := _canonical_export_transforms(asset, visible_components)
	var manifest_components: Array = []
	var masks: Array = []
	for component in visible_components:
		var component_id := str(component.get("id", ""))
		var source: Dictionary = sources.get(component_id, {})
		var export_transform: Dictionary = export_transforms.get(component_id, {})
		var built := _build_reference_component(component, source, export_transform) if str(component.get("type", "component")) == "reference" else _build_component(component, source, export_transform)
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


static func _build_component(component: Dictionary, source: Dictionary, export_transform: Dictionary) -> Dictionary:
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
	var authored_transform = component.get("transform", {})
	if not authored_transform is Dictionary:
		authored_transform = {}
	var authored_pivot := Vector2(authored_transform.get("pivot", Vector2.ZERO))
	var vertices: Array = []
	var vertex_indices: Dictionary = {}
	for raw_vertex in mesh.get("vertices", []):
		if not raw_vertex is Dictionary:
			errors.append("%s: Mesh contains an invalid Vertex record." % label)
			continue
		var vertex_id := str(raw_vertex.get("id", ""))
		var vertex_position := Vector2(raw_vertex.get("position", Vector2.INF))
		if vertex_id.is_empty() or vertex_indices.has(vertex_id) or not vertex_position.is_finite():
			errors.append("%s: Mesh Vertex IDs and positions must be unique and finite." % label)
			continue
		vertex_indices[vertex_id] = vertices.size()
		# Editor mesh coordinates are authored around the Component pivot.  Schema 3
		# instead requires mesh data in Component-local space, so move that pivot to
		# the local origin before serializing it.
		vertices.append(_meters(vertex_position - authored_pivot))
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
	var contour_layout := _contour_layout(vertices, ordered_uvs, [int(resolution[0]), int(resolution[1])]) if resolution.size() == 2 else {"valid": false, "error": "Contour SDF domain requires a valid resolution."}
	if not bool(contour_layout.get("valid", false)):
		errors.append("%s: %s" % [label, str(contour_layout.get("error", "Contour SDF domain is invalid."))])
	else:
		var padding_meters: Dictionary = contour_layout["outer_padding_meters"]
		var padding_px: Dictionary = contour_layout["outer_padding_sdf_px"]
		var domain_size: Array = contour_layout["contour_domain"].get("size", [])
		if domain_size.size() != 2 or not is_equal_approx(float(domain_size[0]) / float(resolution[0]), float(domain_size[1]) / float(resolution[1])):
			errors.append("%s: Contour SDF domain must use equal local meters per SDF pixel." % label)
		var smallest_padding := minf(minf(float(padding_meters["left"]), float(padding_meters["right"])), minf(float(padding_meters["bottom"]), float(padding_meters["top"])))
		if smallest_padding + AFFINE_EPSILON < MIN_OUTER_CONTOUR_PADDING_METERS:
			errors.append("%s: Contour SDF outside padding must be at least %.6f m (16 Game00 reference pixels)." % [label, MIN_OUTER_CONTOUR_PADDING_METERS])
		var required_spread_px := maxf(maxf(float(padding_px["left"]), float(padding_px["right"])), maxf(float(padding_px["bottom"]), float(padding_px["top"])))
		if float(sdf.get("spread_px", 0.0)) + AFFINE_EPSILON < required_spread_px:
			errors.append("%s: SDF spread must cover its declared outside padding." % label)
	var position := Vector2(export_transform.get("position", Vector2.ZERO))
	var pivot := Vector2.ZERO
	var scale := Vector2(export_transform.get("scale", Vector2.ONE))
	var rotation := float(export_transform.get("rotation", 0.0))
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
	var parent_component_id: Variant = null
	if not str(component.get("parent_component_id", "")).is_empty():
		parent_component_id = str(component.get("parent_component_id", ""))
	return {
		"valid": true,
		"errors": [],
		"component": {
			"component_id": component_id,
			"semantic_key": str(component.get("semantic_key", "")).strip_edges(),
			"parent_component_id": parent_component_id,
			"z_index": int(component.get("z_index", 0)),
			"local_pivot": _meters(pivot),
			"local_transform": {
				"position": _meters(position),
				"rotation_radians": deg_to_rad(rotation),
				"scale": [scale.x, scale.y]
			},
			"mesh": {"vertices": vertices, "indices": indices, "uvs": ordered_uvs},
			"contour_carrier": contour_layout["carrier"],
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
				"contour_domain": contour_layout["contour_domain"],
				"content_bounds_uv": contour_layout["content_bounds_uv"],
				"outer_padding_sdf_px": contour_layout["outer_padding_sdf_px"],
				"outer_padding_meters": contour_layout["outer_padding_meters"],
				"pixel_hash": mask["pixel_hash"]
			}
		},
		"mask": mask
	}


static func _build_reference_component(component: Dictionary, source: Dictionary, export_transform: Dictionary) -> Dictionary:
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
			"semantic_key": str(component.get("semantic_key", "")),
			"kind": "asset_reference",
			"source_asset_key": source_asset_key,
			"parent_component_id": parent_component_id,
			"z_index": int(component.get("z_index", 0)),
			"local_pivot": _meters(pivot),
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


static func _contour_layout(vertices: Array, uvs: Array, resolution: Array) -> Dictionary:
	if vertices.size() < 3 or vertices.size() != uvs.size() or resolution.size() != 2:
		return {"valid": false, "error": "Contour SDF domain requires aligned Mesh positions, UVs, and a resolution."}
	var local_bounds := Rect2(_vector2(vertices[0]), Vector2.ZERO)
	var content_min := Vector2(INF, INF)
	var content_max := Vector2(-INF, -INF)
	for index in range(vertices.size()):
		local_bounds = local_bounds.expand(_vector2(vertices[index]))
		var coordinate := _vector2(uvs[index])
		content_min = content_min.min(coordinate)
		content_max = content_max.max(coordinate)
	var content_size := content_max - content_min
	if content_size.x <= AFFINE_EPSILON or content_size.y <= AFFINE_EPSILON or local_bounds.size.x <= AFFINE_EPSILON or local_bounds.size.y <= AFFINE_EPSILON:
		return {"valid": false, "error": "Contour SDF UV and local content bounds must both have positive area."}
	# Bounds / Planar UVs map the actual local bounds into content_bounds_uv.
	# Deriving the full UV domain from those two rectangles avoids selecting an
	# arbitrary triangle (many boundary vertices are collinear) and remains
	# stable across the accepted deterministic mesh order.
	var meters_per_uv := Vector2(local_bounds.size.x / content_size.x, local_bounds.size.y / content_size.y)
	if not is_equal_approx(meters_per_uv.x, meters_per_uv.y):
		return {"valid": false, "error": "Contour SDF domain must use equal local meters per SDF pixel."}
	var domain_min := local_bounds.position - meters_per_uv * content_min
	var domain_size := meters_per_uv
	var width := float(resolution[0])
	var height := float(resolution[1])
	var padding_px := {"left": content_min.x * width, "right": (1.0 - content_max.x) * width, "bottom": content_min.y * height, "top": (1.0 - content_max.y) * height}
	var padding_meters := {"left": content_min.x * domain_size.x, "right": (1.0 - content_max.x) * domain_size.x, "bottom": content_min.y * domain_size.y, "top": (1.0 - content_max.y) * domain_size.y}
	var domain := {"min": [domain_min.x, domain_min.y], "size": [domain_size.x, domain_size.y]}
	return {"valid": true, "contour_domain": domain, "content_bounds_uv": {"min": [content_min.x, content_min.y], "max": [content_max.x, content_max.y]}, "outer_padding_sdf_px": padding_px, "outer_padding_meters": padding_meters, "carrier": {"role": "contour_sdf_carrier", "primitive": "rectangle", "local_rect": domain, "vertices": [[domain_min.x, domain_min.y], [domain_min.x + domain_size.x, domain_min.y], [domain_min.x + domain_size.x, domain_min.y + domain_size.y], [domain_min.x, domain_min.y + domain_size.y]], "indices": [0, 1, 2, 0, 2, 3], "uvs": [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]]}}


static func _vector2(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.INF
