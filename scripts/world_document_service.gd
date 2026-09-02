class_name WorldDocumentService
extends RefCounted

# The on-disk World document format: normalization on load, serialization on
# save, and the atomic file replacement both sides use. Split out of main.gd,
# which keeps the orchestration — which records exist, when they are read and
# written, and what the editor does with them.
#
# Everything here is static and free of editor state. The two persistence
# functions that do read editor state, _serialize_editor_state and
# _serialize_world_settings, stay in main.gd for that reason.

const SCHEMA_VERSION := 61
const REGION_GEOMETRY_AUTHORED := "authored"
const REGION_GEOMETRY_COMPONENT := "component"
const REGION_GEOMETRY_SOURCES := [REGION_GEOMETRY_AUTHORED, REGION_GEOMETRY_COMPONENT]
const DEFAULT_PROJECTION_DEPTH_CM := 10.0
const DRAW_MODES := ["closed_loop", "contour", "primitive"]


static func serialize_bezier_points(points: Array) -> Array:
	var serialized: Array = []
	for point_data in points:
		if not point_data is Dictionary:
			continue
		var point: Vector2 = point_data.get("position", Vector2.ZERO)
		var handle_in: Vector2 = point_data.get("handle_in", Vector2.ZERO)
		var handle_out: Vector2 = point_data.get("handle_out", Vector2.ZERO)
		serialized.append({
			"id": str(point_data.get("id", "")),
			"position": serialize_vector(point),
			"mode": str(point_data.get("mode", "linear")),
			"preserve_point": bool(point_data.get("preserve_point", false)),
			"handle_source": str(point_data.get("handle_source", "auto")),
			"handle_in": serialize_vector(handle_in),
			"handle_out": serialize_vector(handle_out)
		})
	return serialized

static func serialize_edges(edges: Array) -> Array:
	var serialized: Array = []
	for edge_data in edges:
		if not edge_data is Dictionary:
			continue
		serialized.append({
			"id": str(edge_data.get("id", "")),
			"start_point_id": str(edge_data.get("start_point_id", "")),
			"end_point_id": str(edge_data.get("end_point_id", "")),
			"render_outline": bool(edge_data.get("render_outline", true))
		})
	return serialized

static func serialize_chains(chains: Array) -> Array:
	var serialized: Array = []
	for chain_data in chains:
		if not chain_data is Dictionary:
			continue
		serialized.append({
			"id": str(chain_data.get("id", "")),
			"point_ids": chain_data.get("point_ids", []).duplicate(),
			"edge_ids": chain_data.get("edge_ids", []).duplicate(),
			"closed": bool(chain_data.get("closed", false)),
			"topology_role": str(chain_data.get("topology_role", "outer"))
		})
	return serialized

static func deserialize_component_topology(component_data: Dictionary) -> Dictionary:
	var raw_points = component_data.get("points", [])
	var raw_edges = component_data.get("edges", [])
	var raw_chains = component_data.get("chains", [])
	if not raw_points is Array or not raw_edges is Array or not raw_chains is Array:
		return {"points": [], "edges": [], "chains": []}
	var points: Array[Dictionary] = []
	var known_point_ids: Dictionary = {}
	for raw_point in raw_points:
		if not raw_point is Dictionary:
			continue
		var point_id := str(raw_point.get("id", ""))
		if point_id.is_empty() or known_point_ids.has(point_id):
			continue
		var point_mode := str(raw_point.get("mode", "linear"))
		if point_mode not in BezierTopology.VALID_POINT_MODES:
			point_mode = "linear"
		points.append({
			"id": point_id,
			"position": deserialize_vector(raw_point.get("position", [0.0, 0.0]), Vector2.ZERO),
			"mode": point_mode,
			"preserve_point": bool(raw_point.get("preserve_point", point_mode == "corner")),
			"handle_source": "manual" if str(raw_point.get("handle_source", "auto")) == "manual" else "auto",
			"handle_in": deserialize_vector(raw_point.get("handle_in", [0.0, 0.0]), Vector2.ZERO),
			"handle_out": deserialize_vector(raw_point.get("handle_out", [0.0, 0.0]), Vector2.ZERO)
		})
		known_point_ids[point_id] = true
	var edges: Array[Dictionary] = []
	var known_edge_ids: Dictionary = {}
	for raw_edge in raw_edges:
		if not raw_edge is Dictionary:
			continue
		var edge_id := str(raw_edge.get("id", ""))
		var start_point_id := str(raw_edge.get("start_point_id", ""))
		var end_point_id := str(raw_edge.get("end_point_id", ""))
		if edge_id.is_empty() or known_edge_ids.has(edge_id) or not known_point_ids.has(start_point_id) or not known_point_ids.has(end_point_id) or start_point_id == end_point_id:
			continue
		edges.append({
			"id": edge_id,
			"start_point_id": start_point_id,
			"end_point_id": end_point_id,
			"render_outline": bool(raw_edge.get("render_outline", true))
		})
		known_edge_ids[edge_id] = true
	var chains: Array[Dictionary] = []
	for raw_chain in raw_chains:
		if not raw_chain is Dictionary:
			continue
		var point_ids: Array = []
		for point_id_value in raw_chain.get("point_ids", []):
			var point_id := str(point_id_value)
			if known_point_ids.has(point_id):
				point_ids.append(point_id)
		if point_ids.is_empty():
			continue
		var edge_ids: Array = []
		for edge_id_value in raw_chain.get("edge_ids", []):
			var edge_id := str(edge_id_value)
			if known_edge_ids.has(edge_id):
				edge_ids.append(edge_id)
		var topology_role := str(raw_chain.get("topology_role", "outer"))
		if topology_role not in BezierTopology.VALID_TOPOLOGY_ROLES:
			topology_role = "outer"
		chains.append({
			"id": str(raw_chain.get("id", "chain_%d" % (chains.size() + 1))),
			"point_ids": point_ids,
			"edge_ids": edge_ids,
			"closed": bool(raw_chain.get("closed", false)) and point_ids.size() >= 3,
			"topology_role": topology_role
		})
	BezierGeometry.resolve_auto_handles(points, chains)
	return {"points": points, "edges": edges, "chains": chains}

static func default_component_transform() -> Dictionary:
	return {
		"position": Vector2.ZERO,
		"rotation": 0.0,
		"scale": Vector2.ONE,
		"pivot": Vector2.ZERO
	}

static func deserialize_asset_root_scale(value) -> Vector2:
	# Scalar values are the schema-53 uniform representation and remain
	# readable as equal X/Y axes.
	if value is Array and value.size() >= 2:
		var vector_value := Vector2(float(value[0]), float(value[1]))
		return vector_value if vector_value.is_finite() and vector_value.x > AssetScaleRebaseService.SCALE_EPSILON and vector_value.y > AssetScaleRebaseService.SCALE_EPSILON else Vector2.ONE
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		var scalar := float(value)
		return Vector2(scalar, scalar) if is_finite(scalar) and scalar > AssetScaleRebaseService.SCALE_EPSILON else Vector2.ONE
	return Vector2.ONE

static func serialize_transform(transform: Dictionary) -> Dictionary:
	var normalized := deserialize_transform(transform)
	return {
		"position": serialize_vector(normalized["position"]),
		"rotation": float(normalized["rotation"]),
		"scale": serialize_vector(normalized["scale"]),
		"pivot": serialize_vector(normalized["pivot"])
	}

static func default_reference_image() -> Dictionary:
	return {
		"file": "",
		"visible": true,
		"opacity": 0.5,
		"position": Vector2.ZERO,
		"scale": 1.0,
		"target_height_cm": 13.0,
		"pivot_mode": "bottom_center"
	}

static func normalize_reference_image(raw_reference) -> Dictionary:
	var result := default_reference_image()
	if not raw_reference is Dictionary:
		return result
	result["file"] = str(raw_reference.get("file", "")).get_file()
	result["visible"] = bool(raw_reference.get("visible", true))
	result["opacity"] = clampf(float(raw_reference.get("opacity", 0.5)), 0.0, 1.0)
	result["position"] = deserialize_vector(raw_reference.get("position", [0.0, 0.0]), Vector2.ZERO)
	result["scale"] = maxf(float(raw_reference.get("scale", 1.0)), 0.01)
	result["target_height_cm"] = maxf(float(raw_reference.get("target_height_cm", 13.0)), 0.01)
	result["pivot_mode"] = "center" if str(raw_reference.get("pivot_mode", "bottom_center")) == "center" else "bottom_center"
	return result

static func serialize_reference_image(raw_reference) -> Dictionary:
	var normalized := normalize_reference_image(raw_reference)
	return {
		"file": str(normalized["file"]),
		"visible": bool(normalized["visible"]),
		"opacity": float(normalized["opacity"]),
		"position": serialize_vector(normalized["position"]),
		"scale": float(normalized["scale"]),
		"target_height_cm": float(normalized["target_height_cm"]),
		"pivot_mode": str(normalized["pivot_mode"])
	}

static func deserialize_transform(transform) -> Dictionary:
	var result := default_component_transform()
	if not transform is Dictionary:
		return result
	result["position"] = deserialize_vector(transform.get("position", [0.0, 0.0]), Vector2.ZERO)
	result["rotation"] = float(transform.get("rotation", 0.0))
	result["scale"] = deserialize_vector(transform.get("scale", [1.0, 1.0]), Vector2.ONE)
	result["pivot"] = deserialize_vector(transform.get("pivot", [0.0, 0.0]), Vector2.ZERO)
	return result

static func serialize_vector(value: Vector2) -> Array:
	return [value.x, value.y]

static func serialize_color(value) -> Array:
	var color := Color.WHITE
	if value is Color:
		color = value
	return [color.r, color.g, color.b, color.a]

static func deserialize_color(value, fallback: Color) -> Color:
	if value is Array and value.size() >= 3:
		return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]) if value.size() >= 4 else 1.0)
	return fallback

static func deserialize_vector(value, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback

static func serialize_primitive(raw_primitive) -> Dictionary:
	if not raw_primitive is Dictionary:
		return {}
	var primitive_type := str(raw_primitive.get("type", ""))
	var result := {"type": primitive_type, "center": serialize_vector(PrimitiveGeometryService.center({"draw_mode": "primitive", "primitive": raw_primitive}))}
	if primitive_type == "circle":
		result["diameter_cm"] = maxf(float(raw_primitive.get("diameter_cm", 1.0)), 0.001)
		return result
	if primitive_type == PrimitiveGeometryService.ELLIPSE:
		result["diameter_x_cm"] = maxf(float(raw_primitive.get("diameter_x_cm", 1.0)), 0.001)
		result["diameter_y_cm"] = maxf(float(raw_primitive.get("diameter_y_cm", 1.0)), 0.001)
		return result
	return {}

static func deserialize_primitive(raw_primitive) -> Dictionary:
	if not raw_primitive is Dictionary:
		return {}
	var primitive_type := str(raw_primitive.get("type", ""))
	var result := {"type": primitive_type, "center": deserialize_vector(raw_primitive.get("center", [0.0, 0.0]), Vector2.ZERO)}
	if primitive_type == "circle":
		result["diameter_cm"] = maxf(float(raw_primitive.get("diameter_cm", 1.0)), 0.001)
		return result
	if primitive_type == PrimitiveGeometryService.ELLIPSE:
		result["diameter_x_cm"] = maxf(float(raw_primitive.get("diameter_x_cm", 1.0)), 0.001)
		result["diameter_y_cm"] = maxf(float(raw_primitive.get("diameter_y_cm", 1.0)), 0.001)
		return result
	return {}

static func serialize_asset_guide(raw_guide: Dictionary) -> Dictionary:
	var guide := AssetGuide.normalize(raw_guide)
	var serialized := {
		"id": str(guide.get("id", "")),
		"type": "guide",
		"guide_type": str(guide.get("guide_type", AssetGuide.SAMPLER_SPINE)),
		"name": str(guide.get("name", "Guide")),
		"ordinal": int(guide.get("ordinal", 1)),
		"visibility": bool(guide.get("visibility", true)),
		"scope": guide.get("scope", {}).duplicate(true),
		"points": serialize_bezier_points(guide.get("points", [])),
		"edges": serialize_edges(guide.get("edges", [])),
		"chains": serialize_chains(guide.get("chains", []))
	}
	if AssetGuide.is_weapon_frame(str(guide.get("guide_type", ""))):
		serialized["transform"] = serialize_transform(guide.get("transform", default_component_transform()))
	return serialized

static func deserialize_asset_guide(raw_guide: Dictionary) -> Dictionary:
	var topology := deserialize_component_topology(raw_guide)
	var guide: Dictionary = raw_guide.duplicate(true)
	guide["points"] = topology["points"]
	guide["edges"] = topology["edges"]
	guide["chains"] = topology["chains"]
	if AssetGuide.is_weapon_frame(str(guide.get("guide_type", ""))):
		guide["transform"] = deserialize_transform(raw_guide.get("transform", {}))
	return AssetGuide.normalize(guide)

static func default_geometry_document(asset_id: String, component_id: String) -> Dictionary:
	return {
		"asset_id": asset_id,
		"component_id": component_id,
		"component_mesh": {
			"bake_id": "",
			"method": "",
			"mesh_fingerprint": "",
			"build_provenance": {},
			"last_error": "",
			"last_failure_signature": {}
		},
		"sampling": {
			"recipe": GeometrySamplingService.default_recipe(),
			"bakes": {}
		},
		"seeding": {
			"recipe": GeometrySeedingService.default_recipe(),
			"bakes": {}
		},
		"meshing": {
			"recipe": GeometryMeshingService.default_recipe(),
			"bakes": {}
		},
		"uv_mapping": {
			"recipe": GeometryUVMappingService.default_recipe(),
			"bakes": {},
			"last_error": "",
			"last_failure_fingerprint": ""
		},
		"sdf": {
			"recipe": GeometrySDFService.default_recipe(),
			"bake": {},
			"last_error": "",
			"last_failure_fingerprint": ""
		},
		"weighting": {
			"next_style_index": 1,
			"styles": []
		}
	}

static func normalize_geometry_document(raw_document, asset_id: String, component_id: String) -> Dictionary:
	var source: Dictionary = raw_document if raw_document is Dictionary else {}
	var sampling_source = source.get("sampling", {})
	if not sampling_source is Dictionary:
		sampling_source = {}
	var document := default_geometry_document(asset_id, component_id)
	var component_mesh_source = source.get("component_mesh", {})
	if component_mesh_source is Dictionary:
		document["component_mesh"] = {
			"bake_id": str(component_mesh_source.get("bake_id", "")),
			"method": str(component_mesh_source.get("method", "")),
			"mesh_fingerprint": str(component_mesh_source.get("mesh_fingerprint", "")),
			"build_provenance": component_mesh_source.get("build_provenance", {}).duplicate(true) if component_mesh_source.get("build_provenance", {}) is Dictionary else {},
			"last_error": str(component_mesh_source.get("last_error", "")),
			"last_failure_signature": component_mesh_source.get("last_failure_signature", {}).duplicate(true) if component_mesh_source.get("last_failure_signature", {}) is Dictionary else {}
		}
	document["sampling"]["recipe"] = GeometrySamplingService.normalize_recipe(sampling_source.get("recipe", {}))
	var raw_sampling_bakes: Dictionary = sampling_source.get("bakes", {}) if sampling_source.get("bakes", {}) is Dictionary else {}
	if raw_sampling_bakes.is_empty() and sampling_source.get("bake", {}) is Dictionary:
		var legacy_sampling_bake: Dictionary = sampling_source.get("bake", {})
		if bool(legacy_sampling_bake.get("valid", false)):
			raw_sampling_bakes[str(legacy_sampling_bake.get("method", GeometrySamplingService.ADAPTIVE))] = legacy_sampling_bake
	for raw_method in raw_sampling_bakes:
		var raw_sampling_bake = raw_sampling_bakes[raw_method]
		if str(raw_method) == GeometrySamplingService.EVEN_SPACING or (raw_sampling_bake is Dictionary and str(raw_sampling_bake.get("method", "")) == GeometrySamplingService.EVEN_SPACING):
			continue
		var sampling_bake := normalize_sampling_bake(raw_sampling_bake)
		if not sampling_bake.is_empty():
			document["sampling"]["bakes"][str(sampling_bake.get("method", raw_method))] = sampling_bake
	var seeding_source = source.get("seeding", {})
	if not seeding_source is Dictionary:
		seeding_source = {}
	document["seeding"]["recipe"] = GeometrySeedingService.normalize_recipe(seeding_source.get("recipe", {}))
	var raw_seeding_bakes: Dictionary = seeding_source.get("bakes", {}) if seeding_source.get("bakes", {}) is Dictionary else {}
	if raw_seeding_bakes.is_empty() and seeding_source.get("bake", {}) is Dictionary:
		var legacy_seeding_bake: Dictionary = seeding_source.get("bake", {})
		if bool(legacy_seeding_bake.get("valid", false)):
			raw_seeding_bakes[str(legacy_seeding_bake.get("method", GeometrySeedingService.POISSON_FILL))] = legacy_seeding_bake
	for raw_method in raw_seeding_bakes:
		var seeding_bake := normalize_seeding_bake(raw_seeding_bakes[raw_method])
		if not seeding_bake.is_empty():
			document["seeding"]["bakes"][str(seeding_bake.get("method", raw_method))] = seeding_bake
	var meshing_source = source.get("meshing", {})
	if not meshing_source is Dictionary:
		meshing_source = {}
	var raw_meshing_recipe: Dictionary = meshing_source.get("recipe", {}) if meshing_source.get("recipe", {}) is Dictionary else {}
	document["meshing"]["recipe"] = GeometryMeshingService.normalize_recipe(raw_meshing_recipe)
	var raw_meshing_bakes: Dictionary = meshing_source.get("bakes", {}) if meshing_source.get("bakes", {}) is Dictionary else {}
	var preferred_mesh_method := str(component_mesh_source.get("method", raw_meshing_recipe.get("method", GeometryMeshingService.CONSTRAINED_MESH))) if component_mesh_source is Dictionary else str(raw_meshing_recipe.get("method", GeometryMeshingService.CONSTRAINED_MESH))
	var chosen_raw_bake: Dictionary = {}
	if raw_meshing_bakes.get(preferred_mesh_method, {}) is Dictionary:
		chosen_raw_bake = raw_meshing_bakes.get(preferred_mesh_method, {})
	if chosen_raw_bake.is_empty():
		for fallback_method in [GeometryMeshingService.CONSTRAINED_MESH, GeometryMeshingService.ORGANIC_RELAXED, GeometryMeshingService.CONSTRAINED_DELAUNAY, GeometryMeshingService.RIBBON_STRIP, ContourMeshService.METHOD]:
			if raw_meshing_bakes.get(fallback_method, {}) is Dictionary and not raw_meshing_bakes.get(fallback_method, {}).is_empty():
				chosen_raw_bake = raw_meshing_bakes[fallback_method]
				break
	if not chosen_raw_bake.is_empty():
		var meshing_bake := normalize_meshing_bake(chosen_raw_bake)
		if not meshing_bake.is_empty():
			document["meshing"]["bakes"][str(meshing_bake.get("method", GeometryMeshingService.CONSTRAINED_MESH))] = meshing_bake
			if preferred_mesh_method in [GeometryMeshingService.CONSTRAINED_DELAUNAY, GeometryMeshingService.ORGANIC_RELAXED]:
				document["meshing"]["recipe"] = GeometryMeshingService.normalize_recipe({"method": preferred_mesh_method, "parameters": chosen_raw_bake.get("parameters", {})})
			if str(document["component_mesh"].get("bake_id", "")) == str(meshing_bake.get("bake_id", "")):
				document["component_mesh"]["method"] = str(meshing_bake.get("method", GeometryMeshingService.CONSTRAINED_MESH))
	# Schema 4 Runtime needs the centered Stroke beside, rather than instead of,
	# a closed Component's selected Fill Mesh. Legacy normalization previously
	# retained only the selected Meshing Bake.
	if preferred_mesh_method != ContourMeshService.METHOD and raw_meshing_bakes.get(ContourMeshService.METHOD, {}) is Dictionary:
		var contour_stroke_bake := normalize_meshing_bake(raw_meshing_bakes.get(ContourMeshService.METHOD, {}))
		if not contour_stroke_bake.is_empty():
			document["meshing"]["bakes"][ContourMeshService.METHOD] = contour_stroke_bake
	var uv_mapping_source = source.get("uv_mapping", {})
	if not uv_mapping_source is Dictionary:
		uv_mapping_source = {}
	document["uv_mapping"]["recipe"] = GeometryUVMappingService.normalize_recipe(uv_mapping_source.get("recipe", {}))
	document["uv_mapping"]["last_error"] = str(uv_mapping_source.get("last_error", ""))
	document["uv_mapping"]["last_failure_fingerprint"] = str(uv_mapping_source.get("last_failure_fingerprint", ""))
	var raw_uv_bakes: Dictionary = uv_mapping_source.get("bakes", {}) if uv_mapping_source.get("bakes", {}) is Dictionary else {}
	var uv_bake_scores: Dictionary = {}
	var chosen_mesh_bake_id := str(chosen_raw_bake.get("bake_id", ""))
	for raw_key in raw_uv_bakes:
		var uv_bake := normalize_uv_mapping_bake(raw_uv_bakes[raw_key])
		if not uv_bake.is_empty():
			var bake_key := GeometryUVMappingService.bake_key(str(uv_bake.get("mesh_method", "")), str(uv_bake.get("method", "")))
			var raw_uv_bake: Dictionary = raw_uv_bakes[raw_key]
			var score := 0
			if not chosen_mesh_bake_id.is_empty() and str(raw_uv_bake.get("mesh_bake_id", "")) == chosen_mesh_bake_id:
				score = 2
			elif str(raw_uv_bake.get("mesh_method", "")) == preferred_mesh_method:
				score = 1
			if not document["uv_mapping"]["bakes"].has(bake_key) or score > int(uv_bake_scores.get(bake_key, -1)):
				document["uv_mapping"]["bakes"][bake_key] = uv_bake
				uv_bake_scores[bake_key] = score
	var sdf_source = source.get("sdf", {})
	if sdf_source is Dictionary:
		document["sdf"]["recipe"] = GeometrySDFService.normalize_recipe(sdf_source.get("recipe", {}))
		document["sdf"]["bake"] = normalize_sdf_bake(sdf_source.get("bake", {}))
		document["sdf"]["last_error"] = str(sdf_source.get("last_error", ""))
		document["sdf"]["last_failure_fingerprint"] = str(sdf_source.get("last_failure_fingerprint", ""))
	var weighting_source = source.get("weighting", {})
	if weighting_source is Dictionary:
		document["weighting"]["next_style_index"] = maxi(1, int(weighting_source.get("next_style_index", 1)))
		for raw_style in weighting_source.get("styles", []):
			var style := WeightingService.normalize_style(raw_style)
			if not str(style.get("id", "")).is_empty():
				document["weighting"]["styles"].append(style)
	return document

static func normalize_sampling_bake(raw_bake) -> Dictionary:
	if not raw_bake is Dictionary or not bool(raw_bake.get("valid", false)):
		return {}
	var bake: Dictionary = raw_bake.duplicate(true)
	var normalized_chains: Array = []
	for raw_chain in raw_bake.get("chains", []):
		if not raw_chain is Dictionary:
			continue
		var samples: Array = []
		for raw_sample in raw_chain.get("samples", []):
			if raw_sample is Dictionary:
				samples.append({"id": str(raw_sample.get("id", "")), "position": deserialize_vector(raw_sample.get("position", [0.0, 0.0]), Vector2.ZERO), "edge_id": str(raw_sample.get("edge_id", "")), "curve_t": clampf(float(raw_sample.get("curve_t", 0.0)), 0.0, 1.0), "source_point_id": str(raw_sample.get("source_point_id", "")), "preserved": bool(raw_sample.get("preserved", false))})
		normalized_chains.append({"chain_id": str(raw_chain.get("chain_id", "")), "input_id": str(raw_chain.get("input_id", "")), "topology_role": str(raw_chain.get("topology_role", "outer")), "closed": bool(raw_chain.get("closed", false)), "effective_spacing": maxf(float(raw_chain.get("effective_spacing", raw_bake.get("parameters", {}).get("spacing", GeometrySamplingService.DEFAULT_SPACING))), GeometrySamplingService.MIN_SPACING), "samples": samples})
	bake["method"] = GeometrySamplingService.ADAPTIVE
	bake["algorithm_version"] = int(raw_bake.get("algorithm_version", 0))
	bake["parameters"] = GeometrySamplingService.normalize_recipe({"method": bake["method"], "parameters": raw_bake.get("parameters", {})})["parameters"]
	bake["chains"] = normalized_chains
	var normalized_cuts: Array = []
	for raw_cut in raw_bake.get("cuts", []):
		if not raw_cut is Dictionary:
			continue
		var cut_samples: Array = []
		for raw_sample in raw_cut.get("samples", []):
			if raw_sample is Dictionary:
				cut_samples.append({"id": str(raw_sample.get("id", "")), "position": deserialize_vector(raw_sample.get("position", [0.0, 0.0]), Vector2.ZERO), "edge_id": str(raw_sample.get("edge_id", "")), "curve_t": clampf(float(raw_sample.get("curve_t", 0.0)), 0.0, 1.0), "source_point_id": str(raw_sample.get("source_point_id", "")), "preserved": bool(raw_sample.get("preserved", false)), "guide_id": str(raw_sample.get("guide_id", raw_cut.get("guide_id", "")))})
		var normalized_fragments: Array = []
		for raw_fragment in raw_cut.get("fragments", []):
			if not raw_fragment is Dictionary:
				continue
			var fragment_samples: Array = []
			for raw_sample in raw_fragment.get("samples", []):
				if raw_sample is Dictionary:
					fragment_samples.append({"id": str(raw_sample.get("id", "")), "position": deserialize_vector(raw_sample.get("position", [0.0, 0.0]), Vector2.ZERO), "edge_id": str(raw_sample.get("edge_id", "")), "curve_t": clampf(float(raw_sample.get("curve_t", 0.0)), 0.0, 1.0), "source_point_id": str(raw_sample.get("source_point_id", "")), "preserved": bool(raw_sample.get("preserved", false)), "guide_id": str(raw_sample.get("guide_id", raw_cut.get("guide_id", "")))})
			if fragment_samples.size() >= 2:
				normalized_fragments.append({"id": str(raw_fragment.get("id", "cut:%s:fragment:%d" % [str(raw_cut.get("guide_id", "")), normalized_fragments.size()])), "samples": fragment_samples})
		if normalized_fragments.is_empty() and cut_samples.size() >= 2:
			normalized_fragments.append({"id": "cut:%s:fragment:0" % str(raw_cut.get("guide_id", "")), "samples": cut_samples.duplicate(true)})
		normalized_cuts.append({"valid": bool(raw_cut.get("valid", true)), "errors": raw_cut.get("errors", []).duplicate(), "guide_id": str(raw_cut.get("guide_id", "")), "input_id": str(raw_cut.get("input_id", raw_cut.get("guide_id", ""))), "effective_spacing": maxf(float(raw_cut.get("effective_spacing", raw_bake.get("parameters", {}).get("spacing", GeometrySamplingService.DEFAULT_SPACING))), GeometrySamplingService.MIN_SPACING), "samples": cut_samples, "fragments": normalized_fragments})
	bake["cuts"] = normalized_cuts
	bake["sample_count"] = int(raw_bake.get("sample_count", 0))
	bake["preserve_count"] = int(raw_bake.get("preserve_count", 0))
	bake["hole_count"] = normalized_chains.filter(func(chain: Dictionary) -> bool: return str(chain.get("topology_role", "outer")) == "hole").size()
	var constraint_count := 0
	for chain_data in normalized_chains:
		constraint_count += chain_data.get("samples", []).size()
	for cut_data in normalized_cuts:
		constraint_count += cut_data.get("samples", []).size()
	bake["constraint_sample_count"] = constraint_count
	var boundary_stats: Array = []
	for chain_data in normalized_chains:
		boundary_stats.append({"input_id": str(chain_data.get("input_id", "")), "role": str(chain_data.get("topology_role", "outer")), "effective_spacing": float(chain_data.get("effective_spacing", GeometrySamplingService.DEFAULT_SPACING)), "sample_count": chain_data.get("samples", []).size()})
	for cut_data in normalized_cuts:
		boundary_stats.append({"input_id": str(cut_data.get("input_id", cut_data.get("guide_id", ""))), "role": "cut", "effective_spacing": float(cut_data.get("effective_spacing", GeometrySamplingService.DEFAULT_SPACING)), "sample_count": cut_data.get("samples", []).size()})
	bake["boundary_stats"] = boundary_stats
	return bake

static func normalize_seeding_bake(raw_bake) -> Dictionary:
	if not raw_bake is Dictionary or not bool(raw_bake.get("valid", false)):
		return {}
	var bake: Dictionary = raw_bake.duplicate(true)
	var normalized_seeds: Array = []
	for raw_seed in raw_bake.get("seeds", []):
		if raw_seed is Dictionary:
			normalized_seeds.append({"id": str(raw_seed.get("id", "")), "position": deserialize_vector(raw_seed.get("position", [0.0, 0.0]), Vector2.ZERO), "origin": str(raw_seed.get("origin", "generated")), "method": str(raw_seed.get("method", GeometrySeedingService.POISSON_FILL)), "provenance": raw_seed.get("provenance", {}).duplicate(true) if raw_seed.get("provenance", {}) is Dictionary else {}})
	bake["method"] = str(raw_bake.get("method", GeometrySeedingService.POISSON_FILL))
	bake["parameters"] = GeometrySeedingService.normalize_recipe({"method": bake["method"], "parameters": raw_bake.get("parameters", {})})["parameters"]
	bake["seeds"] = normalized_seeds
	bake["seed_count"] = normalized_seeds.size()
	bake["edited"] = bool(raw_bake.get("edited", false))
	return bake

static func normalize_meshing_bake(raw_bake) -> Dictionary:
	if not raw_bake is Dictionary or not bool(raw_bake.get("valid", false)):
		return {}
	var bake: Dictionary = raw_bake.duplicate(true)
	var normalized_vertices: Array = []
	for raw_vertex in raw_bake.get("vertices", []):
		if raw_vertex is Dictionary:
			var normalized_vertex := {
				"id": str(raw_vertex.get("id", "")),
				"position": deserialize_vector(raw_vertex.get("position", [0.0, 0.0]), Vector2.ZERO),
				"origin": str(raw_vertex.get("origin", "seed")),
				"source_id": str(raw_vertex.get("source_id", "")),
				"preserved": bool(raw_vertex.get("preserved", false))
			}
			if raw_vertex.has("edge_id"):
				normalized_vertex["edge_id"] = str(raw_vertex.get("edge_id", ""))
			if raw_vertex.has("curve_t"):
				normalized_vertex["curve_t"] = float(raw_vertex.get("curve_t", 0.0))
			normalized_vertices.append(normalized_vertex)
	var normalized_triangles: Array = []
	for raw_triangle in raw_bake.get("triangles", []):
		if raw_triangle is Dictionary and raw_triangle.get("vertex_ids", []) is Array:
			var normalized_triangle := {"vertex_ids": raw_triangle.get("vertex_ids", []).duplicate()}
			if raw_triangle.has("id"):
				normalized_triangle["id"] = str(raw_triangle.get("id", ""))
			normalized_triangles.append(normalized_triangle)
	var raw_method := str(raw_bake.get("method", GeometryMeshingService.CONSTRAINED_MESH))
	if raw_method == GeometryMeshingService.RIBBON_STRIP:
		bake["method"] = raw_method
		bake["parameters"] = raw_bake.get("parameters", {}).duplicate(true) if raw_bake.get("parameters", {}) is Dictionary else {}
	else:
		var normalized_recipe := GeometryMeshingService.normalize_recipe({"method": raw_method, "parameters": raw_bake.get("parameters", {})})
		bake["method"] = str(normalized_recipe.get("method", GeometryMeshingService.CONSTRAINED_MESH))
		bake["parameters"] = normalized_recipe["parameters"]
	bake["algorithm_version"] = int(raw_bake.get("algorithm_version", 0))
	bake["vertices"] = normalized_vertices
	bake["triangles"] = normalized_triangles
	var normalized_runs: Array = []
	for raw_run in raw_bake.get("runs", []):
		if not raw_run is Dictionary:
			continue
		var normalized_run: Dictionary = raw_run.duplicate(true)
		var normalized_centerline: Array = []
		for raw_sample in raw_run.get("centerline", []):
			if not raw_sample is Dictionary:
				continue
			var normalized_sample: Dictionary = raw_sample.duplicate(true)
			normalized_sample["position"] = deserialize_vector(raw_sample.get("position", [0.0, 0.0]), Vector2.ZERO)
			normalized_centerline.append(normalized_sample)
		normalized_run["centerline"] = normalized_centerline
		normalized_runs.append(normalized_run)
	bake["runs"] = normalized_runs
	var raw_closed_region = raw_bake.get("closed_region", {})
	if raw_closed_region is Dictionary and not raw_closed_region.is_empty():
		var normalized_closed_region: Dictionary = raw_closed_region.duplicate(true)
		var normalized_region_vertices: Array = []
		for raw_vertex in raw_closed_region.get("vertices", []):
			if not raw_vertex is Dictionary:
				continue
			var normalized_vertex: Dictionary = raw_vertex.duplicate(true)
			normalized_vertex["id"] = str(raw_vertex.get("id", ""))
			normalized_vertex["position"] = deserialize_vector(raw_vertex.get("position", [0.0, 0.0]), Vector2.ZERO)
			normalized_vertex["edge_id"] = str(raw_vertex.get("edge_id", ""))
			normalized_vertex["curve_t"] = float(raw_vertex.get("curve_t", 0.0))
			normalized_region_vertices.append(normalized_vertex)
		var normalized_region_triangles: Array = []
		for raw_triangle in raw_closed_region.get("triangles", []):
			if raw_triangle is Dictionary and raw_triangle.get("vertex_ids", []) is Array:
				normalized_region_triangles.append({"id": str(raw_triangle.get("id", "")), "vertex_ids": raw_triangle.get("vertex_ids", []).duplicate()})
		normalized_closed_region["vertices"] = normalized_region_vertices
		normalized_closed_region["triangles"] = normalized_region_triangles
		normalized_closed_region["vertex_count"] = normalized_region_vertices.size()
		normalized_closed_region["triangle_count"] = normalized_region_triangles.size()
		bake["closed_region"] = normalized_closed_region
	else:
		bake.erase("closed_region")
	bake["boundary_constraints"] = raw_bake.get("boundary_constraints", []).duplicate(true)
	bake["vertex_count"] = normalized_vertices.size()
	bake["triangle_count"] = normalized_triangles.size()
	bake["minimum_angle"] = maxf(float(raw_bake.get("minimum_angle", 0.0)), 0.0)
	bake["worst_aspect_ratio"] = maxf(float(raw_bake.get("worst_aspect_ratio", 0.0)), 0.0)
	bake["mean_quality"] = clampf(float(raw_bake.get("mean_quality", 0.0)), 0.0, 1.0)
	var raw_optimization = raw_bake.get("optimization", {})
	var optimization: Dictionary = raw_optimization.duplicate(true) if raw_optimization is Dictionary else {}
	var normalized_movements: Array = []
	for raw_movement in optimization.get("movements", []):
		if raw_movement is Dictionary:
			normalized_movements.append({
				"vertex_id": str(raw_movement.get("vertex_id", "")),
				"from": deserialize_vector(raw_movement.get("from", [0.0, 0.0]), Vector2.ZERO),
				"to": deserialize_vector(raw_movement.get("to", [0.0, 0.0]), Vector2.ZERO),
				"distance": maxf(float(raw_movement.get("distance", 0.0)), 0.0)
			})
	optimization["movements"] = normalized_movements
	var normalized_baseline_triangles: Array = []
	for raw_triangle in optimization.get("baseline_triangles", []):
		if raw_triangle is Dictionary and raw_triangle.get("vertex_ids", []) is Array:
			normalized_baseline_triangles.append({"vertex_ids": raw_triangle.get("vertex_ids", []).duplicate()})
	optimization["baseline_triangles"] = normalized_baseline_triangles
	bake["optimization"] = optimization
	return bake

static func normalize_uv_mapping_bake(raw_bake) -> Dictionary:
	if not raw_bake is Dictionary or not bool(raw_bake.get("valid", false)):
		return {}
	var bake: Dictionary = raw_bake.duplicate(true)
	var normalized_uvs: Array = []
	for raw_entry in raw_bake.get("uvs", []):
		if raw_entry is Dictionary:
			normalized_uvs.append({
				"vertex_id": str(raw_entry.get("vertex_id", "")),
				"uv": deserialize_vector(raw_entry.get("uv", [0.0, 0.0]), Vector2.ZERO)
			})
	bake["method"] = str(raw_bake.get("method", GeometryUVMappingService.BOUNDS_PLANAR))
	var raw_mesh_method := str(raw_bake.get("mesh_method", GeometryMeshingService.CONSTRAINED_MESH))
	bake["mesh_method"] = GeometryMeshingService.CONSTRAINED_MESH if raw_mesh_method in [GeometryMeshingService.CONSTRAINED_DELAUNAY, GeometryMeshingService.ORGANIC_RELAXED] else raw_mesh_method
	var raw_parameters: Dictionary = raw_bake.get("parameters", {}).duplicate(true) if raw_bake.get("parameters", {}) is Dictionary else {}
	# Pre-schema-36 UVs touched the normalized bounds. Preserve that exact
	# meaning so the new padded default marks them stale instead of relabeling
	# their old coordinates as padded.
	if not raw_parameters.has("padding"):
		raw_parameters["padding"] = 0.0
	bake["parameters"] = GeometryUVMappingService.normalize_recipe({"method": bake["method"], "parameters": raw_parameters})["parameters"]
	bake["uvs"] = normalized_uvs
	bake["uv_count"] = normalized_uvs.size()
	return bake

static func serialize_sampling_bake(bake: Dictionary) -> Dictionary:
	var serialized_bake := bake.duplicate(true)
	var serialized_chains: Array = []
	for chain_data in bake.get("chains", []):
		var serialized_samples: Array = []
		for sample in chain_data.get("samples", []):
			serialized_samples.append({"id": str(sample.get("id", "")), "position": serialize_vector(Vector2(sample.get("position", Vector2.ZERO))), "edge_id": str(sample.get("edge_id", "")), "curve_t": float(sample.get("curve_t", 0.0)), "source_point_id": str(sample.get("source_point_id", "")), "preserved": bool(sample.get("preserved", false))})
		serialized_chains.append({"chain_id": str(chain_data.get("chain_id", "")), "input_id": str(chain_data.get("input_id", "")), "topology_role": str(chain_data.get("topology_role", "outer")), "closed": bool(chain_data.get("closed", false)), "effective_spacing": float(chain_data.get("effective_spacing", GeometrySamplingService.DEFAULT_SPACING)), "samples": serialized_samples})
	serialized_bake["chains"] = serialized_chains
	var serialized_cuts: Array = []
	for cut_data in bake.get("cuts", []):
		var serialized_samples: Array = []
		for sample in cut_data.get("samples", []):
			serialized_samples.append({"id": str(sample.get("id", "")), "position": serialize_vector(Vector2(sample.get("position", Vector2.ZERO))), "edge_id": str(sample.get("edge_id", "")), "curve_t": float(sample.get("curve_t", 0.0)), "source_point_id": str(sample.get("source_point_id", "")), "preserved": bool(sample.get("preserved", false)), "guide_id": str(sample.get("guide_id", cut_data.get("guide_id", "")))})
		var serialized_fragments: Array = []
		for fragment in GeometrySamplingService.cut_fragments(cut_data):
			var fragment_samples: Array = []
			for sample in fragment.get("samples", []):
				fragment_samples.append({"id": str(sample.get("id", "")), "position": serialize_vector(Vector2(sample.get("position", Vector2.ZERO))), "edge_id": str(sample.get("edge_id", "")), "curve_t": float(sample.get("curve_t", 0.0)), "source_point_id": str(sample.get("source_point_id", "")), "preserved": bool(sample.get("preserved", false)), "guide_id": str(sample.get("guide_id", cut_data.get("guide_id", "")))})
			serialized_fragments.append({"id": str(fragment.get("id", "")), "samples": fragment_samples})
		serialized_cuts.append({"valid": bool(cut_data.get("valid", true)), "errors": cut_data.get("errors", []).duplicate(), "guide_id": str(cut_data.get("guide_id", "")), "input_id": str(cut_data.get("input_id", cut_data.get("guide_id", ""))), "effective_spacing": float(cut_data.get("effective_spacing", GeometrySamplingService.DEFAULT_SPACING)), "samples": serialized_samples, "fragments": serialized_fragments})
	serialized_bake["cuts"] = serialized_cuts
	serialized_bake["hole_count"] = serialized_chains.filter(func(chain: Dictionary) -> bool: return str(chain.get("topology_role", "outer")) == "hole").size()
	return serialized_bake

static func serialize_seeding_bake(bake: Dictionary) -> Dictionary:
	var serialized_bake := bake.duplicate(true)
	var serialized_seeds: Array = []
	for seed_data in bake.get("seeds", []):
		serialized_seeds.append({"id": str(seed_data.get("id", "")), "position": serialize_vector(Vector2(seed_data.get("position", Vector2.ZERO))), "origin": str(seed_data.get("origin", "generated")), "method": str(seed_data.get("method", GeometrySeedingService.POISSON_FILL)), "provenance": seed_data.get("provenance", {}).duplicate(true) if seed_data.get("provenance", {}) is Dictionary else {}})
	serialized_bake["seeds"] = serialized_seeds
	return serialized_bake

static func serialize_meshing_bake(bake: Dictionary) -> Dictionary:
	var serialized_bake := bake.duplicate(true)
	var serialized_vertices: Array = []
	for vertex in bake.get("vertices", []):
		var serialized_vertex := {
			"id": str(vertex.get("id", "")),
			"position": serialize_vector(Vector2(vertex.get("position", Vector2.ZERO))),
			"origin": str(vertex.get("origin", "seed")),
			"source_id": str(vertex.get("source_id", "")),
			"preserved": bool(vertex.get("preserved", false))
		}
		if vertex.has("edge_id"):
			serialized_vertex["edge_id"] = str(vertex.get("edge_id", ""))
		if vertex.has("curve_t"):
			serialized_vertex["curve_t"] = float(vertex.get("curve_t", 0.0))
		serialized_vertices.append(serialized_vertex)
	serialized_bake["vertices"] = serialized_vertices
	var serialized_runs: Array = []
	for run_data in bake.get("runs", []):
		if not run_data is Dictionary:
			continue
		var serialized_run: Dictionary = run_data.duplicate(true)
		var serialized_centerline: Array = []
		for sample in run_data.get("centerline", []):
			if not sample is Dictionary:
				continue
			var serialized_sample: Dictionary = sample.duplicate(true)
			serialized_sample["position"] = serialize_vector(Vector2(sample.get("position", Vector2.ZERO)))
			serialized_centerline.append(serialized_sample)
		serialized_run["centerline"] = serialized_centerline
		serialized_runs.append(serialized_run)
	serialized_bake["runs"] = serialized_runs
	var raw_closed_region = bake.get("closed_region", {})
	if raw_closed_region is Dictionary and not raw_closed_region.is_empty():
		var serialized_closed_region: Dictionary = raw_closed_region.duplicate(true)
		var serialized_region_vertices: Array = []
		for vertex in raw_closed_region.get("vertices", []):
			if not vertex is Dictionary:
				continue
			var serialized_vertex: Dictionary = vertex.duplicate(true)
			serialized_vertex["position"] = serialize_vector(Vector2(vertex.get("position", Vector2.ZERO)))
			serialized_region_vertices.append(serialized_vertex)
		serialized_closed_region["vertices"] = serialized_region_vertices
		serialized_bake["closed_region"] = serialized_closed_region
	else:
		serialized_bake.erase("closed_region")
	var raw_optimization = bake.get("optimization", {})
	if raw_optimization is Dictionary:
		var optimization: Dictionary = raw_optimization.duplicate(true)
		var serialized_movements: Array = []
		for movement in optimization.get("movements", []):
			if movement is Dictionary:
				serialized_movements.append({
					"vertex_id": str(movement.get("vertex_id", "")),
					"from": serialize_vector(deserialize_vector(movement.get("from", Vector2.ZERO), Vector2.ZERO)),
					"to": serialize_vector(deserialize_vector(movement.get("to", Vector2.ZERO), Vector2.ZERO)),
					"distance": maxf(float(movement.get("distance", 0.0)), 0.0)
				})
		optimization["movements"] = serialized_movements
		serialized_bake["optimization"] = optimization
	return serialized_bake

static func serialize_uv_mapping_bake(bake: Dictionary) -> Dictionary:
	var serialized_bake := bake.duplicate(true)
	var serialized_uvs: Array = []
	for entry in bake.get("uvs", []):
		serialized_uvs.append({
			"vertex_id": str(entry.get("vertex_id", "")),
			"uv": serialize_vector(Vector2(entry.get("uv", Vector2.ZERO)))
		})
	serialized_bake["uvs"] = serialized_uvs
	return serialized_bake

static func normalize_sdf_bake(raw_bake) -> Dictionary:
	if not raw_bake is Dictionary or not bool(raw_bake.get("valid", false)):
		return {}
	var bake: Dictionary = raw_bake.duplicate(true)
	bake.erase("image")
	bake["method"] = str(raw_bake.get("method", GeometrySDFService.SINGLE_CHANNEL_SDF))
	bake["algorithm_version"] = int(raw_bake.get("algorithm_version", 0))
	bake["parameters"] = GeometrySDFService.normalize_recipe({"method": bake["method"], "parameters": raw_bake.get("parameters", {})})["parameters"]
	bake["resolution"] = raw_bake.get("resolution", [GeometrySDFService.DEFAULT_RESOLUTION, GeometrySDFService.DEFAULT_RESOLUTION]).duplicate()
	bake["image_path"] = str(raw_bake.get("image_path", "contour_sdf.png"))
	return bake

static func serialize_sdf_bake(bake: Dictionary) -> Dictionary:
	var serialized := bake.duplicate(true)
	serialized.erase("image")
	return serialized

static func serialize_geometry_document(document: Dictionary) -> Dictionary:
	var normalized := normalize_geometry_document(document, str(document.get("asset_id", "")), str(document.get("component_id", "")))
	var serialized_sampling_bakes: Dictionary = {}
	for method in normalized.get("sampling", {}).get("bakes", {}):
		serialized_sampling_bakes[str(method)] = serialize_sampling_bake(normalized["sampling"]["bakes"][method])
	var serialized_seeding_bakes: Dictionary = {}
	for method in normalized.get("seeding", {}).get("bakes", {}):
		serialized_seeding_bakes[str(method)] = serialize_seeding_bake(normalized["seeding"]["bakes"][method])
	var serialized_meshing_bakes: Dictionary = {}
	for method in normalized.get("meshing", {}).get("bakes", {}):
		serialized_meshing_bakes[str(method)] = serialize_meshing_bake(normalized["meshing"]["bakes"][method])
	var serialized_uv_mapping_bakes: Dictionary = {}
	for bake_key in normalized.get("uv_mapping", {}).get("bakes", {}):
		serialized_uv_mapping_bakes[str(bake_key)] = serialize_uv_mapping_bake(normalized["uv_mapping"]["bakes"][bake_key])
	return {
		"schema_version": SCHEMA_VERSION,
		"asset_id": str(normalized.get("asset_id", "")),
		"component_id": str(normalized.get("component_id", "")),
		"component_mesh": normalized.get("component_mesh", {}).duplicate(true),
		"sampling": {
			"recipe": normalized.get("sampling", {}).get("recipe", {}).duplicate(true),
			"bakes": serialized_sampling_bakes
		},
		"seeding": {
			"recipe": normalized.get("seeding", {}).get("recipe", {}).duplicate(true),
			"bakes": serialized_seeding_bakes
		},
		"meshing": {
			"recipe": normalized.get("meshing", {}).get("recipe", {}).duplicate(true),
			"bakes": serialized_meshing_bakes
		},
		"uv_mapping": {
			"recipe": normalized.get("uv_mapping", {}).get("recipe", {}).duplicate(true),
			"bakes": serialized_uv_mapping_bakes,
			"last_error": str(normalized.get("uv_mapping", {}).get("last_error", "")),
			"last_failure_fingerprint": str(normalized.get("uv_mapping", {}).get("last_failure_fingerprint", ""))
		},
		"sdf": {
			"recipe": normalized.get("sdf", {}).get("recipe", {}).duplicate(true),
			"bake": serialize_sdf_bake(normalized.get("sdf", {}).get("bake", {})),
			"last_error": str(normalized.get("sdf", {}).get("last_error", "")),
			"last_failure_fingerprint": str(normalized.get("sdf", {}).get("last_failure_fingerprint", ""))
		},
		"weighting": {
			"next_style_index": int(normalized.get("weighting", {}).get("next_style_index", 1)),
			"styles": normalized.get("weighting", {}).get("styles", []).duplicate(true)
		}
	}

static func deserialize_projection_depth_cm(value: Variant) -> float:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) < 0.0:
		return DEFAULT_PROJECTION_DEPTH_CM
	return float(value)

static func write_json(path: String, data: Dictionary) -> bool:
	return write_text_atomically(path, JSON.stringify(data, "\t"))

static func write_text_atomically(path: String, text: String) -> bool:
	# Authored World data is replaced, never truncated in place: the new content
	# is staged beside the target, read back, and only then swapped in. A failure
	# at any step leaves the previous file intact. The Asset Catalog and the
	# Runtime Export packages use the same contract.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var staging := "%s/.%s.staging" % [path.get_base_dir(), path.get_file()]
	var backup := "%s/.%s.backup" % [path.get_base_dir(), path.get_file()]
	if FileAccess.file_exists(staging):
		DirAccess.remove_absolute(staging)
	if FileAccess.file_exists(backup):
		# A backup without its target is the residue of an interrupted swap.
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(backup)
		else:
			DirAccess.rename_absolute(backup, path)
	var file := FileAccess.open(staging, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	if FileAccess.get_file_as_string(staging) != text:
		DirAccess.remove_absolute(staging)
		return false
	if FileAccess.file_exists(path) and DirAccess.rename_absolute(path, backup) != OK:
		DirAccess.remove_absolute(staging)
		return false
	if DirAccess.rename_absolute(staging, path) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, path)
		DirAccess.remove_absolute(staging)
		return false
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	return true

# Document queries. Small enough to have lived in main.gd, but the Outliner
# view needs them too, and one home beats two copies.

static func guide_display_name(asset: Dictionary, guide: Dictionary) -> String:
	var scope: Dictionary = guide.get("scope", {})
	var scope_record := ComponentHierarchy.group_by_id(asset, str(scope.get("group_id", ""))) if str(scope.get("kind", "component")) == "group" else WorldDocumentService.component_by_id(asset, str(scope.get("component_id", "")))
	var scope_name := str(scope_record.get("name", "Unassigned"))
	if AssetGuide.is_weapon_frame(str(guide.get("guide_type", ""))):
		return "%s → %s" % [scope_name, str(guide.get("guide_type", ""))]
	return AssetGuide.outliner_name(guide, scope_name)


static func component_outliner_name(assets: Array, component: Dictionary) -> String:
	var component_name := normalized_component_name(component)
	if not is_reference_component(component):
		return component_name
	var source_asset := asset_by_id(assets, str(component.get("source_asset_id", "")))
	var source_name := str(source_asset.get("name", "Missing asset"))
	return "%s ← %s" % [component_name, source_name]


static func asset_by_id(assets: Array, asset_id: String) -> Dictionary:
	for asset in assets:
		if str(asset.get("id", "")) == asset_id:
			return asset
	return {}


static func edge_by_id(component: Dictionary, edge_id: String) -> Dictionary:
	if component.is_empty():
		return {}
	for edge in component.get("edges", []):
		if str(edge.get("id", "")) == edge_id:
			return edge
	return {}


static func guide_by_id(asset: Dictionary, guide_id: String) -> Dictionary:
	if asset.is_empty():
		return {}
	for guide in asset.get("guides", []):
		if str(guide.get("id", "")) == guide_id:
			return guide
	return {}


static func asset_pivot(asset: Dictionary) -> Vector2:
	return deserialize_vector(asset.get("asset_pivot", [0.0, 0.0]), Vector2.ZERO)


static func projection_depth_cm(component: Dictionary) -> float:
	return deserialize_projection_depth_cm(component.get("projection_depth_cm", DEFAULT_PROJECTION_DEPTH_CM))


static func draw_mode_display_name(draw_mode: String) -> String:
	if draw_mode == "contour":
		return "Contour"
	if draw_mode == "primitive":
		return "Primitive"
	return "Closed Loop"


static func has_contour_stroke_width_override(component: Dictionary, world_default: float) -> bool:
	# An override only counts when the stored width is a usable positive number
	# and actually differs from the world default.
	if not component.has("contour_stroke_width_px"):
		return false
	var width: Variant = component.get("contour_stroke_width_px")
	if not typeof(width) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(width)) or float(width) <= 0.0:
		return false
	return not is_equal_approx(float(width), world_default)


static func effective_contour_stroke_width_px(component: Dictionary, world_default: float) -> float:
	return float(component["contour_stroke_width_px"]) if has_contour_stroke_width_override(component, world_default) else world_default


static func component_by_id(asset: Dictionary, component_id: String) -> Dictionary:
	if asset.is_empty():
		return {}
	for component in asset.get("components", []):
		if str(component.get("type", "component")) != "guide" and str(component.get("id", "")) == component_id:
			return component
	return {}


static func motion_path_by_id(motion_paths: Array, path_id: String) -> Dictionary:
	for path_document in motion_paths:
		if str(path_document.get("id", "")) == path_id:
			return path_document
	return {}


static func asset_type(asset: Dictionary) -> String:
	return normalize_asset_type(asset.get("asset_type", "character"))


static func is_region(component: Dictionary) -> bool:
	return str(component.get("type", "component")) == "region"


static func normalize_region_geometry_source(value) -> String:
	var source := str(value)
	return source if source in REGION_GEOMETRY_SOURCES else REGION_GEOMETRY_AUTHORED


static func region_uses_component_geometry(component: Dictionary) -> bool:
	return is_region(component) and normalize_region_geometry_source(component.get("region_geometry_source", REGION_GEOMETRY_AUTHORED)) == REGION_GEOMETRY_COMPONENT


static func is_reference_component(component: Dictionary) -> bool:
	return str(component.get("type", "component")) == "reference"


static func normalized_component_name(component: Dictionary) -> String:
	var normalized_name := str(component.get("name", "")).strip_edges()
	return normalized_name if not normalized_name.is_empty() else "Component"


static func sort_named_documents(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()


static func read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())

static func has_supported_schema(data) -> bool:
	if not data is Dictionary:
		return false
	var version := int(data.get("schema_version", data.get("format_version", 0)))
	return version > 0 and version <= SCHEMA_VERSION

static func normalize_component_draw_mode(raw_mode, source_schema_version: int) -> String:
	var draw_mode := str(raw_mode)
	if draw_mode == "ribbon" and source_schema_version < 40:
		return "contour"
	if draw_mode == "ribbon":
		return draw_mode
	return draw_mode if draw_mode in DRAW_MODES else "closed_loop"

static func normalize_asset_type(value) -> String:
	var normalized := str(value).strip_edges().to_lower()
	return normalized if normalized in ["character", "props", "weapons", "terrain", "icon", "symbols"] else "character"

static func default_motion_path(path_id: String, path_name: String) -> Dictionary:
	return {
		"id": path_id,
		"name": path_name,
		"visibility": true,
		"topology": MotionPathTopology.default_topology(),
		"playback": {"duration": 2.0, "loop": true, "orient_along_path": false}
	}

static func normalize_motion_path(raw_path, fallback_id: String) -> Dictionary:
	var source: Dictionary = raw_path if raw_path is Dictionary else {}
	var result := default_motion_path(str(source.get("id", fallback_id)), str(source.get("name", fallback_id)))
	result["visibility"] = bool(source.get("visibility", true))
	result["topology"] = MotionPathTopology.normalize(source.get("topology", {}))
	if source.get("playback", {}) is Dictionary:
		result["playback"].merge(source.get("playback", {}), true)
	return result

static func default_motion_act(act_id: String, act_name: String, primitive := MotionActEvaluator.SLIDE) -> Dictionary:
	var resolved_primitive: String = primitive if primitive in MotionActEvaluator.PRIMITIVES else MotionActEvaluator.SLIDE
	return {
		"id": act_id,
		"name": act_name,
		"kind": MotionActEvaluator.KIND_PRIMITIVE,
		"primitive": resolved_primitive,
		"enabled": true,
		"timing": {"duration": MotionActEvaluator.default_duration(resolved_primitive), "easing": MotionActEvaluator.EASE_IN_OUT},
		"parameters": MotionActEvaluator.default_parameters(resolved_primitive)
	}

static func normalize_motion_act(raw_act, fallback_id: String) -> Dictionary:
	var source: Dictionary = raw_act if raw_act is Dictionary else {}
	var primitive := str(source.get("primitive", MotionActEvaluator.SLIDE))
	if primitive not in MotionActEvaluator.PRIMITIVES:
		primitive = MotionActEvaluator.SLIDE
	var result := default_motion_act(str(source.get("id", fallback_id)), str(source.get("name", MotionActEvaluator.primitive_label(primitive))), primitive)
	result["enabled"] = bool(source.get("enabled", true))
	var timing = source.get("timing", {})
	if timing is Dictionary:
		result["timing"]["duration"] = maxf(0.01, float(timing.get("duration", MotionActEvaluator.default_duration(primitive))))
		var easing := str(timing.get("easing", MotionActEvaluator.EASE_IN_OUT))
		result["timing"]["easing"] = easing if easing in MotionActEvaluator.EASING_OPTIONS else MotionActEvaluator.EASE_IN_OUT
	var parameters = source.get("parameters", {})
	if parameters is Dictionary:
		if parameters.has("direction"):
			result["parameters"]["direction"] = MotionActEvaluator._vector(parameters.get("direction"))
		result["parameters"]["distance"] = maxf(0.0, float(parameters.get("distance", 4.0)))
		if primitive == MotionActEvaluator.JUMP:
			result["parameters"]["height"] = maxf(0.0, float(parameters.get("height", 3.0)))
			var arc := str(parameters.get("arc", MotionActEvaluator.JUMP_ARC_SMOOTH))
			result["parameters"]["arc"] = arc if arc in MotionActEvaluator.JUMP_ARC_OPTIONS else MotionActEvaluator.JUMP_ARC_SMOOTH
		elif primitive == MotionActEvaluator.BLINK:
			result["parameters"]["anticipation_distance"] = maxf(0.0, float(parameters.get("anticipation_distance", 1.0)))
			var anticipation_share := float(parameters.get("anticipation_share", 0.5))
			if int(source.get("schema_version", 0)) in range(1, 19) and is_equal_approx(anticipation_share, 0.18):
				anticipation_share = 0.5
			result["parameters"]["anticipation_share"] = clampf(anticipation_share, 0.01, 0.89)
			result["parameters"]["minimum_scale"] = clampf(float(parameters.get("minimum_scale", 0.05)), 0.01, 1.0)
	return result

static func serialize_motion_act(act: Dictionary) -> Dictionary:
	var normalized := normalize_motion_act(act, str(act.get("id", "act")))
	return {
		"schema_version": SCHEMA_VERSION,
		"id": str(normalized.get("id", "")),
		"name": str(normalized.get("name", MotionActEvaluator.primitive_label(str(normalized.get("primitive", MotionActEvaluator.SLIDE))))),
		"kind": MotionActEvaluator.KIND_PRIMITIVE,
		"primitive": str(normalized.get("primitive", MotionActEvaluator.SLIDE)),
		"enabled": bool(normalized.get("enabled", true)),
		"timing": normalized.get("timing", {}).duplicate(true),
		"parameters": serialize_motion_act_parameters(normalized)
	}

static func serialize_motion_act_parameters(act: Dictionary) -> Dictionary:
	var parameters: Dictionary = act.get("parameters", {})
	var serialized := {
		"direction": serialize_vector(parameters.get("direction", Vector2.RIGHT)),
		"distance": float(parameters.get("distance", 4.0))
	}
	if str(act.get("primitive", MotionActEvaluator.SLIDE)) == MotionActEvaluator.JUMP:
		serialized["height"] = float(parameters.get("height", 3.0))
		serialized["arc"] = str(parameters.get("arc", MotionActEvaluator.JUMP_ARC_SMOOTH))
	elif str(act.get("primitive", MotionActEvaluator.SLIDE)) == MotionActEvaluator.BLINK:
		serialized["anticipation_distance"] = float(parameters.get("anticipation_distance", 1.0))
		serialized["anticipation_share"] = float(parameters.get("anticipation_share", 0.5))
		serialized["minimum_scale"] = float(parameters.get("minimum_scale", 0.05))
	return serialized

static func default_motion_sequence(sequence_id: String, sequence_name: String) -> Dictionary:
	return {"id": sequence_id, "name": sequence_name, "visibility": true, "next_entry_index": 1, "entries": []}

static func normalize_motion_sequence(raw_sequence, fallback_id: String) -> Dictionary:
	var source: Dictionary = raw_sequence if raw_sequence is Dictionary else {}
	var result := default_motion_sequence(str(source.get("id", fallback_id)), str(source.get("name", fallback_id)))
	result["visibility"] = bool(source.get("visibility", true))
	var normalized_entries: Array = []
	var raw_entries = source.get("entries", [])
	if raw_entries is Array:
		for raw_entry in raw_entries:
			if not raw_entry is Dictionary:
				continue
			var entry_id := str(raw_entry.get("id", ""))
			if entry_id.is_empty():
				continue
			normalized_entries.append({
				"id": entry_id,
				"name": str(raw_entry.get("name", "Composition Entry")),
				"enabled": bool(raw_entry.get("enabled", true)),
				"asset_id": str(raw_entry.get("asset_id", "")),
				"animation_state_id": str(raw_entry.get("animation_state_id", "")),
				"path_id": str(raw_entry.get("path_id", ""))
			})
	result["entries"] = normalized_entries
	var inferred_next_entry_index := 1
	for entry in normalized_entries:
		var entry_id := str(entry.get("id", ""))
		if entry_id.begins_with("entry_"):
			inferred_next_entry_index = maxi(inferred_next_entry_index, entry_id.trim_prefix("entry_").to_int() + 1)
	result["next_entry_index"] = maxi(inferred_next_entry_index, int(source.get("next_entry_index", inferred_next_entry_index)))
	return result
