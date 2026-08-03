class_name GeometryUVMappingService
extends RefCounted

const BOUNDS_PLANAR := "bounds_planar"
const VALID_METHODS := [BOUNDS_PLANAR]
const DEFAULT_SCALE := 1.0
const DEFAULT_ROTATION := 0.0
const DEFAULT_OFFSET_U := 0.0
const DEFAULT_OFFSET_V := 0.0
const DEFAULT_PRESERVE_ASPECT := true
const MIN_SCALE := 0.01


static func default_recipe() -> Dictionary:
	return {
		"method": BOUNDS_PLANAR,
		"parameters": {
			"mesh_method": GeometryMeshingService.CONSTRAINED_DELAUNAY,
			"scale": DEFAULT_SCALE,
			"rotation": DEFAULT_ROTATION,
			"offset_u": DEFAULT_OFFSET_U,
			"offset_v": DEFAULT_OFFSET_V,
			"preserve_aspect": DEFAULT_PRESERVE_ASPECT
		}
	}


static func normalize_recipe(raw_recipe) -> Dictionary:
	var recipe := default_recipe()
	if not raw_recipe is Dictionary:
		return recipe
	var method := str(raw_recipe.get("method", BOUNDS_PLANAR))
	recipe["method"] = method if method in VALID_METHODS else BOUNDS_PLANAR
	var parameters = raw_recipe.get("parameters", {})
	if not parameters is Dictionary:
		return recipe
	var mesh_method := str(parameters.get("mesh_method", GeometryMeshingService.CONSTRAINED_DELAUNAY))
	recipe["parameters"]["mesh_method"] = mesh_method if mesh_method in GeometryMeshingService.VALID_METHODS else GeometryMeshingService.CONSTRAINED_DELAUNAY
	recipe["parameters"]["scale"] = maxf(float(parameters.get("scale", DEFAULT_SCALE)), MIN_SCALE)
	recipe["parameters"]["rotation"] = wrapf(float(parameters.get("rotation", DEFAULT_ROTATION)), -180.0, 180.0)
	recipe["parameters"]["offset_u"] = float(parameters.get("offset_u", DEFAULT_OFFSET_U))
	recipe["parameters"]["offset_v"] = float(parameters.get("offset_v", DEFAULT_OFFSET_V))
	recipe["parameters"]["preserve_aspect"] = bool(parameters.get("preserve_aspect", DEFAULT_PRESERVE_ASPECT))
	return recipe


static func generate(mesh_bake: Dictionary, raw_recipe = {}) -> Dictionary:
	var recipe := normalize_recipe(raw_recipe)
	var errors := validation_issues(mesh_bake, recipe)
	if not errors.is_empty():
		return _failed_result(mesh_bake, recipe, errors)
	var vertices: Array = mesh_bake.get("vertices", [])
	var first_position := Vector2(vertices[0].get("position", Vector2.ZERO))
	var bounds := Rect2(first_position, Vector2.ZERO)
	for vertex in vertices:
		bounds = bounds.expand(Vector2(vertex.get("position", Vector2.ZERO)))
	var extent := Vector2(maxf(bounds.size.x, 0.000001), maxf(bounds.size.y, 0.000001))
	var preserve_aspect := bool(recipe["parameters"]["preserve_aspect"])
	var uniform_extent := maxf(extent.x, extent.y)
	var radians := deg_to_rad(float(recipe["parameters"]["rotation"]))
	var scale := float(recipe["parameters"]["scale"])
	var offset := Vector2(float(recipe["parameters"]["offset_u"]), float(recipe["parameters"]["offset_v"]))
	var uv_entries: Array = []
	for vertex in vertices:
		var position := Vector2(vertex.get("position", Vector2.ZERO))
		var uv := Vector2.ZERO
		if preserve_aspect:
			var padded := (Vector2(uniform_extent, uniform_extent) - extent) * 0.5
			uv = (position - bounds.position + padded) / uniform_extent
		else:
			uv = (position - bounds.position) / extent
		uv = Vector2(0.5, 0.5) + (uv - Vector2(0.5, 0.5)).rotated(radians) * scale + offset
		uv_entries.append({"vertex_id": str(vertex.get("id", "")), "uv": uv})
	return {
		"valid": true,
		"errors": [],
		"method": recipe["method"],
		"parameters": recipe["parameters"].duplicate(true),
		"mesh_bake_id": str(mesh_bake.get("bake_id", "")),
		"mesh_method": str(mesh_bake.get("method", "")),
		"mesh_fingerprint": mesh_fingerprint(mesh_bake),
		"uvs": uv_entries,
		"uv_count": uv_entries.size()
	}


static func validation_issues(mesh_bake: Dictionary, recipe: Dictionary = {}) -> Array[String]:
	var errors: Array[String] = []
	if mesh_bake.is_empty() or not bool(mesh_bake.get("valid", false)):
		errors.append("UV Mapping requires a valid Mesh Bake.")
		return errors
	if str(mesh_bake.get("bake_id", "")).is_empty():
		errors.append("The Mesh Bake has no stable Bake ID.")
	if mesh_bake.get("vertices", []).is_empty() or mesh_bake.get("triangles", []).is_empty():
		errors.append("UV Mapping requires Mesh Vertices and Triangles.")
	var normalized := normalize_recipe(recipe)
	if str(mesh_bake.get("method", "")) != str(normalized.get("parameters", {}).get("mesh_method", "")):
		errors.append("The selected Mesh source is unavailable.")
	return errors


static func mesh_fingerprint(mesh_bake: Dictionary) -> String:
	var parts := PackedStringArray([
		str(mesh_bake.get("bake_id", "")),
		str(mesh_bake.get("method", "")),
		str(mesh_bake.get("sampling_bake_id", "")),
		str(mesh_bake.get("seeding_bake_id", ""))
	])
	for vertex in mesh_bake.get("vertices", []):
		if vertex is Dictionary:
			var position := Vector2(vertex.get("position", Vector2.ZERO))
			parts.append("v|%s|%.9f|%.9f" % [str(vertex.get("id", "")), position.x, position.y])
	for triangle in mesh_bake.get("triangles", []):
		if triangle is Dictionary:
			parts.append("t|%s" % ",".join(triangle.get("vertex_ids", [])))
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update("\n".join(parts).to_utf8_buffer())
	return context.finish().hex_encode()


static func bake_key(mesh_method: String, uv_method: String) -> String:
	return "%s/%s" % [mesh_method, uv_method]


static func _failed_result(mesh_bake: Dictionary, recipe: Dictionary, errors: Array) -> Dictionary:
	return {
		"valid": false,
		"errors": errors,
		"method": recipe["method"],
		"parameters": recipe["parameters"].duplicate(true),
		"mesh_bake_id": str(mesh_bake.get("bake_id", "")),
		"mesh_method": str(mesh_bake.get("method", "")),
		"mesh_fingerprint": mesh_fingerprint(mesh_bake),
		"uvs": [],
		"uv_count": 0
	}
