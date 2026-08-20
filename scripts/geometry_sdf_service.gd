class_name GeometrySDFService
extends RefCounted

const SINGLE_CHANNEL_SDF := "single_channel_sdf"
const ALGORITHM_VERSION := 1
const VALIDATION_VERSION := 2
const DEFAULT_RESOLUTION := 256
const DEFAULT_SPREAD_PX := 16.0
const MIN_RESOLUTION := 16
const MAX_RESOLUTION := 2048
const MIN_SPREAD_PX := 1.0
const EPSILON := 0.000001
const UV_RELATIVE_AREA_EPSILON := 0.0000001


static func default_recipe() -> Dictionary:
	return {
		"method": SINGLE_CHANNEL_SDF,
		"parameters": {
			"resolution": DEFAULT_RESOLUTION,
			"spread_px": DEFAULT_SPREAD_PX
		}
	}


static func normalize_recipe(raw_recipe) -> Dictionary:
	var recipe := default_recipe()
	if not raw_recipe is Dictionary:
		return recipe
	var parameters = raw_recipe.get("parameters", {})
	if not parameters is Dictionary:
		return recipe
	recipe["parameters"]["resolution"] = clampi(int(parameters.get("resolution", DEFAULT_RESOLUTION)), MIN_RESOLUTION, MAX_RESOLUTION)
	recipe["parameters"]["spread_px"] = maxf(float(parameters.get("spread_px", DEFAULT_SPREAD_PX)), MIN_SPREAD_PX)
	return recipe


static func generate(mesh_bake: Dictionary, uv_bake: Dictionary, raw_recipe = {}) -> Dictionary:
	var recipe := normalize_recipe(raw_recipe)
	var errors := validation_issues(mesh_bake, uv_bake, recipe)
	if not errors.is_empty():
		return _failed_result(mesh_bake, uv_bake, recipe, errors)
	var resolution := int(recipe["parameters"]["resolution"])
	var spread_px := float(recipe["parameters"]["spread_px"])
	var uv_by_id: Dictionary = {}
	for entry in uv_bake.get("uvs", []):
		uv_by_id[str(entry.get("vertex_id", ""))] = Vector2(entry.get("uv", Vector2.ZERO))
	var triangles: Array = []
	var edge_records: Dictionary = {}
	for triangle in mesh_bake.get("triangles", []):
		var ids: Array = triangle.get("vertex_ids", [])
		var a: Vector2 = uv_by_id[str(ids[0])]
		var b: Vector2 = uv_by_id[str(ids[1])]
		var c: Vector2 = uv_by_id[str(ids[2])]
		triangles.append(PackedVector2Array([a, b, c]))
		_add_edge_record(edge_records, a, b)
		_add_edge_record(edge_records, b, c)
		_add_edge_record(edge_records, c, a)
	var boundary_edges: Array = []
	for key in edge_records:
		var record: Dictionary = edge_records[key]
		if int(record.get("count", 0)) == 1:
			boundary_edges.append(PackedVector2Array([record["a"], record["b"]]))
	var inside := PackedByteArray()
	inside.resize(resolution * resolution)
	for triangle in triangles:
		_rasterize_triangle(inside, resolution, triangle)
	var pixels := PackedByteArray()
	pixels.resize(resolution * resolution)
	for y in range(resolution):
		for x in range(resolution):
			var pixel_position := Vector2(float(x) + 0.5, float(y) + 0.5)
			var minimum_distance := INF
			for edge in boundary_edges:
				var edge_a := _uv_to_pixel(edge[0], resolution)
				var edge_b := _uv_to_pixel(edge[1], resolution)
				minimum_distance = minf(minimum_distance, _distance_to_segment(pixel_position, edge_a, edge_b))
			var signed_distance := minimum_distance if inside[y * resolution + x] > 0 else -minimum_distance
			var encoded := clampf(0.5 + signed_distance / (2.0 * spread_px), 0.0, 1.0)
			pixels[y * resolution + x] = clampi(roundi(encoded * 255.0), 0, 255)
	var image := Image.create_from_data(resolution, resolution, false, Image.FORMAT_L8, pixels)
	var pixel_hash := _bytes_hash(pixels)
	return {
		"valid": true,
		"errors": [],
		"method": SINGLE_CHANNEL_SDF,
		"algorithm_version": ALGORITHM_VERSION,
		"parameters": recipe["parameters"].duplicate(true),
		"mesh_bake_id": str(mesh_bake.get("bake_id", "")),
		"mesh_method": str(mesh_bake.get("method", "")),
		"mesh_fingerprint": GeometryUVMappingService.mesh_fingerprint(mesh_bake),
		"uv_bake_id": str(uv_bake.get("bake_id", "")),
		"uv_fingerprint": uv_fingerprint(uv_bake),
		"source_fingerprint": source_fingerprint(mesh_bake, uv_bake, recipe),
		"image_path": "contour_sdf.png",
		"pixel_hash": pixel_hash,
		"channel": "r",
		"color_space": "linear",
		"resolution": [resolution, resolution],
		"spread_px": spread_px,
		"boundary_value": 0.5,
		"inside_is_greater": true,
		"uv_origin": "bottom_left",
		"image_origin": "top_left",
		"uv_to_pixel": "x=u*width, y=(1-v)*height",
		"image": image
	}


static func validation_issues(mesh_bake: Dictionary, uv_bake: Dictionary, raw_recipe = {}) -> Array[String]:
	var errors: Array[String] = []
	if mesh_bake.is_empty() or not bool(mesh_bake.get("valid", false)):
		errors.append("SDF generation requires a valid accepted Component Mesh.")
		return errors
	if uv_bake.is_empty() or not bool(uv_bake.get("valid", false)):
		errors.append("SDF generation requires a valid accepted UV Bake.")
		return errors
	if str(mesh_bake.get("bake_id", "")).is_empty() or str(uv_bake.get("bake_id", "")).is_empty():
		errors.append("SDF inputs need stable Bake IDs.")
	if not GeometryUVMappingService.result_matches(uv_bake, mesh_bake, {"method": uv_bake.get("method", ""), "parameters": uv_bake.get("parameters", {})}):
		errors.append("The accepted UV Bake no longer matches the accepted Component Mesh.")
		return errors
	var uv_by_id: Dictionary = {}
	for entry in uv_bake.get("uvs", []):
		var vertex_id := str(entry.get("vertex_id", ""))
		var uv := Vector2(entry.get("uv", Vector2.INF))
		if not uv.is_finite() or uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
			errors.append("UV for Vertex '%s' must lie inside normalized UV space." % vertex_id)
		else:
			uv_by_id[vertex_id] = uv
	for triangle in mesh_bake.get("triangles", []):
		if not triangle is Dictionary or not triangle.get("vertex_ids", []) is Array or triangle.get("vertex_ids", []).size() != 3:
			errors.append("Every Component Mesh Triangle must reference exactly three Vertex IDs.")
			continue
		var ids: Array = triangle.get("vertex_ids", [])
		if not uv_by_id.has(str(ids[0])) or not uv_by_id.has(str(ids[1])) or not uv_by_id.has(str(ids[2])):
			errors.append("A Component Mesh Triangle references a Vertex without accepted UVs.")
			continue
		var uv_a: Vector2 = uv_by_id[str(ids[0])]
		var uv_b: Vector2 = uv_by_id[str(ids[1])]
		var uv_c: Vector2 = uv_by_id[str(ids[2])]
		if _uv_triangle_is_collapsed(uv_a, uv_b, uv_c):
			errors.append("The UV Bake contains a numerically collapsed Triangle.")
	var recipe := normalize_recipe(raw_recipe)
	if float(recipe["parameters"]["spread_px"]) * 2.0 >= float(recipe["parameters"]["resolution"]):
		errors.append("SDF Spread must be smaller than half the image resolution.")
	return errors


static func uv_fingerprint(uv_bake: Dictionary) -> String:
	var parts := PackedStringArray([
		str(uv_bake.get("bake_id", "")),
		str(uv_bake.get("method", "")),
		str(uv_bake.get("mesh_bake_id", "")),
		str(uv_bake.get("mesh_fingerprint", ""))
	])
	for entry in uv_bake.get("uvs", []):
		if entry is Dictionary:
			var uv := Vector2(entry.get("uv", Vector2.ZERO))
			parts.append("uv|%s|%.9f|%.9f" % [str(entry.get("vertex_id", "")), uv.x, uv.y])
	return _strings_hash(parts)


static func source_fingerprint(mesh_bake: Dictionary, uv_bake: Dictionary, raw_recipe = {}) -> String:
	var recipe := normalize_recipe(raw_recipe)
	return _strings_hash(PackedStringArray([
		GeometryUVMappingService.mesh_fingerprint(mesh_bake),
		uv_fingerprint(uv_bake),
		str(ALGORITHM_VERSION),
		JSON.stringify(recipe, "", true, true)
	]))


static func failure_fingerprint(mesh_bake: Dictionary, uv_bake: Dictionary, raw_recipe = {}) -> String:
	return _strings_hash(PackedStringArray([
		source_fingerprint(mesh_bake, uv_bake, raw_recipe),
		"validation:%d" % VALIDATION_VERSION
	]))


static func result_matches(result: Dictionary, mesh_bake: Dictionary, uv_bake: Dictionary, raw_recipe = {}) -> bool:
	if result.is_empty() or not bool(result.get("valid", false)):
		return false
	var recipe := normalize_recipe(raw_recipe)
	return int(result.get("algorithm_version", 0)) == ALGORITHM_VERSION \
		and str(result.get("method", "")) == SINGLE_CHANNEL_SDF \
		and result.get("parameters", {}) == recipe.get("parameters", {}) \
		and str(result.get("source_fingerprint", "")) == source_fingerprint(mesh_bake, uv_bake, recipe) \
		and str(result.get("mesh_bake_id", "")) == str(mesh_bake.get("bake_id", "")) \
		and str(result.get("uv_bake_id", "")) == str(uv_bake.get("bake_id", "")) \
		and not str(result.get("pixel_hash", "")).is_empty()


static func image_pixel_hash(image: Image) -> String:
	return "" if image == null or image.is_empty() else _bytes_hash(image.get_data())


static func _add_edge_record(records: Dictionary, a: Vector2, b: Vector2) -> void:
	var a_key := _point_key(a)
	var b_key := _point_key(b)
	var key := "%s|%s" % [a_key, b_key] if a_key < b_key else "%s|%s" % [b_key, a_key]
	if records.has(key):
		records[key]["count"] = int(records[key].get("count", 0)) + 1
	else:
		records[key] = {"a": a, "b": b, "count": 1}


static func _point_key(point: Vector2) -> String:
	return "%.8f,%.8f" % [point.x, point.y]


static func _rasterize_triangle(inside: PackedByteArray, resolution: int, triangle: PackedVector2Array) -> void:
	var a := _uv_to_pixel(triangle[0], resolution)
	var b := _uv_to_pixel(triangle[1], resolution)
	var c := _uv_to_pixel(triangle[2], resolution)
	var minimum_x := clampi(floori(minf(a.x, minf(b.x, c.x))), 0, resolution - 1)
	var maximum_x := clampi(ceili(maxf(a.x, maxf(b.x, c.x))), 0, resolution - 1)
	var minimum_y := clampi(floori(minf(a.y, minf(b.y, c.y))), 0, resolution - 1)
	var maximum_y := clampi(ceili(maxf(a.y, maxf(b.y, c.y))), 0, resolution - 1)
	for y in range(minimum_y, maximum_y + 1):
		for x in range(minimum_x, maximum_x + 1):
			if _point_in_triangle(Vector2(float(x) + 0.5, float(y) + 0.5), a, b, c):
				inside[y * resolution + x] = 1


static func _point_in_triangle(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := _cross(b - a, point - a)
	var d2 := _cross(c - b, point - b)
	var d3 := _cross(a - c, point - c)
	var has_negative := d1 < -EPSILON or d2 < -EPSILON or d3 < -EPSILON
	var has_positive := d1 > EPSILON or d2 > EPSILON or d3 > EPSILON
	return not (has_negative and has_positive)


static func _cross(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x


static func _uv_triangle_is_collapsed(a: Vector2, b: Vector2, c: Vector2) -> bool:
	var ab := b - a
	var bc := c - b
	var ca := a - c
	var edge_scale_squared := maxf(ab.length_squared(), maxf(bc.length_squared(), ca.length_squared()))
	if edge_scale_squared <= 0.0:
		return true
	# UVs are normalized, so a fixed absolute area threshold rejects small but
	# well-shaped triangles. Compare orientation against the triangle's own edge
	# scale instead; this remains stable across Component and UV-island sizes.
	return absf(_cross(ab, c - a)) <= edge_scale_squared * UV_RELATIVE_AREA_EPSILON


static func _uv_to_pixel(uv: Vector2, resolution: int) -> Vector2:
	return Vector2(uv.x * float(resolution), (1.0 - uv.y) * float(resolution))


static func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var edge := b - a
	var length_squared := edge.length_squared()
	if length_squared <= EPSILON:
		return point.distance_to(a)
	var t := clampf((point - a).dot(edge) / length_squared, 0.0, 1.0)
	return point.distance_to(a + edge * t)


static func _strings_hash(parts: PackedStringArray) -> String:
	return _bytes_hash("\n".join(parts).to_utf8_buffer())


static func _bytes_hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


static func _failed_result(mesh_bake: Dictionary, uv_bake: Dictionary, recipe: Dictionary, errors: Array) -> Dictionary:
	return {
		"valid": false,
		"errors": errors.duplicate(),
		"method": SINGLE_CHANNEL_SDF,
		"algorithm_version": ALGORITHM_VERSION,
		"parameters": recipe["parameters"].duplicate(true),
		"mesh_bake_id": str(mesh_bake.get("bake_id", "")),
		"uv_bake_id": str(uv_bake.get("bake_id", "")),
		"source_fingerprint": source_fingerprint(mesh_bake, uv_bake, recipe),
		"image": null
	}
