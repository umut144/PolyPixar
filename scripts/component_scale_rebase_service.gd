class_name ComponentScaleRebaseService
extends RefCounted

## Explicitly bakes finite, non-zero signed local Component scale into owned source geometry.
## Parent Rebase compensates direct Child transforms to preserve Child world transforms.

const ALGORITHM_VERSION := 3
const SCALE_EPSILON := 0.000001


static func analyze_asset(asset: Dictionary) -> Dictionary:
	var candidates: Array = []
	var blockers: Array = []
	for component in asset.get("components", []):
		if not component is Dictionary or str(component.get("type", "component")) == "guide":
			continue
		var scale := _component_scale(component)
		if _is_unit_scale(scale):
			continue
		var entry := {
			"component_id": str(component.get("id", "")),
			"name": str(component.get("name", "Component")),
			"scale": scale
		}
		var reason := "" if str(component.get("type", "component")) == "reference" else _blocking_reason(asset, component, scale)
		if reason.is_empty():
			entry["result_primitive_type"] = _result_primitive_type(component, scale)
			candidates.append(entry)
		else:
			entry["reason"] = reason
			blockers.append(entry)
	return {
		"valid": true,
		"errors": [],
		"algorithm_version": ALGORITHM_VERSION,
		"required": not candidates.is_empty() or not blockers.is_empty(),
		"can_rebase": not candidates.is_empty() and blockers.is_empty(),
		"candidates": candidates,
		"blockers": blockers
	}


static func rebase_asset(asset: Dictionary) -> Dictionary:
	var analysis := analyze_asset(asset)
	if not bool(analysis.get("can_rebase", false)):
		var errors: Array = []
		if not analysis.get("blockers", []).is_empty():
			for blocker in analysis.get("blockers", []):
				errors.append("%s: %s" % [str(blocker.get("name", "Component")), str(blocker.get("reason", "Scale cannot be rebased."))])
		else:
			errors.append("No Component scale requires Rebase.")
		return {"valid": false, "errors": errors, "analysis": analysis, "rebased_component_ids": []}
	var candidate_ids: Array[String] = []
	for candidate in analysis.get("candidates", []):
		candidate_ids.append(str(candidate.get("component_id", "")))
	var working_asset := asset.duplicate(true)
	var result := rebase_components(working_asset, candidate_ids)
	if not bool(result.get("valid", false)):
		return {"valid": false, "errors": result.get("errors", []), "analysis": analysis, "rebased_component_ids": []}
	asset.clear()
	asset.merge(working_asset, true)
	return {"valid": true, "errors": [], "analysis": analysis, "rebased_component_ids": result.get("rebased_component_ids", [])}


static func rebase_components(asset: Dictionary, component_ids: Array) -> Dictionary:
	var requested_ids: Dictionary = {}
	for component_id_value in component_ids:
		var component_id := str(component_id_value)
		if not ComponentHierarchy.component_by_id(asset, component_id).is_empty():
			requested_ids[component_id] = true
	var candidates: Array[Dictionary] = []
	var blockers: Array[String] = []
	for component_id in requested_ids:
		var component := ComponentHierarchy.component_by_id(asset, component_id)
		var scale := _component_scale(component)
		if _is_unit_scale(scale):
			continue
		var reason := "" if str(component.get("type", "component")) == "reference" else _target_blocking_reason(component, scale)
		if reason.is_empty():
			candidates.append({"component_id": component_id, "scale": scale})
		else:
			blockers.append("%s: %s" % [str(component.get("name", "Component")), reason])
	if not blockers.is_empty():
		return {"valid": false, "errors": blockers, "rebased_component_ids": []}
	if candidates.is_empty():
		return {"valid": true, "errors": [], "rebased_component_ids": []}
	var working_asset := asset.duplicate(true)
	var world_records: Dictionary = {}
	for component in asset.get("components", []):
		if component is Dictionary and str(component.get("type", "component")) != "guide":
			world_records[str(component.get("id", ""))] = ComponentHierarchy.world_transform_record(asset, str(component.get("id", "")))
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _component_depth(working_asset, str(left.get("component_id", ""))) < _component_depth(working_asset, str(right.get("component_id", "")))
	)
	var rebased_ids: Array[String] = []
	for candidate in candidates:
		var component_id := str(candidate.get("component_id", ""))
		var component := ComponentHierarchy.component_by_id(working_asset, component_id)
		var scale := _component_scale(component)
		if str(component.get("type", "component")) == "reference":
			component["reference_instance_scale"] = Vector2(component.get("reference_instance_scale", Vector2.ONE)) * scale
			var reference_transform: Dictionary = component.get("transform", {}).duplicate(true)
			reference_transform["scale"] = Vector2.ONE
			component["transform"] = reference_transform
			rebased_ids.append(component_id)
			continue
		var pivot := Vector2(component.get("transform", {}).get("pivot", Vector2.ZERO))
		_bake_component_geometry(component, pivot, scale)
		_bake_component_guides(working_asset, component_id, pivot, scale)
		var transform: Dictionary = component.get("transform", {}).duplicate(true)
		transform["scale"] = Vector2.ONE
		component["transform"] = transform
		for child in ComponentHierarchy.children(working_asset, component_id):
			var child_id := str(child.get("id", ""))
			if world_records.has(child_id):
				child["transform"] = ComponentHierarchy.local_transform_from_world_record(working_asset, child_id, world_records[child_id])
		rebased_ids.append(component_id)
	asset.clear()
	asset.merge(working_asset, true)
	return {"valid": true, "errors": [], "rebased_component_ids": rebased_ids}


static func _blocking_reason(_asset: Dictionary, component: Dictionary, scale: Vector2) -> String:
	if not scale.is_finite() or absf(scale.x) <= SCALE_EPSILON or absf(scale.y) <= SCALE_EPSILON:
		return "Scale axes must be finite and non-zero."
	var draw_mode := str(component.get("draw_mode", "closed_loop"))
	if draw_mode in ["closed_loop", "contour"]:
		return "" if not component.get("points", []).is_empty() else "Component has no geometry that can absorb Scale."
	if draw_mode == "primitive":
		return "" if PrimitiveGeometryService.has_analytic_shape(component) else "Primitive must be a complete Circle or Ellipse."
	return "Draw Mode '%s' does not own rebaseable geometry." % draw_mode


static func _target_blocking_reason(component: Dictionary, scale: Vector2) -> String:
	if not scale.is_finite() or absf(scale.x) <= SCALE_EPSILON or absf(scale.y) <= SCALE_EPSILON:
		return "Scale axes must be finite and non-zero."
	var draw_mode := str(component.get("draw_mode", "closed_loop"))
	if draw_mode in ["closed_loop", "contour"]:
		return "" if not component.get("points", []).is_empty() else "Component has no geometry that can absorb Scale."
	if draw_mode == "primitive":
		return "" if PrimitiveGeometryService.has_analytic_shape(component) else "Primitive must be a complete Circle or Ellipse."
	return "Draw Mode '%s' does not own rebaseable geometry." % draw_mode


static func _component_depth(asset: Dictionary, component_id: String) -> int:
	var depth := 0
	var component := ComponentHierarchy.component_by_id(asset, component_id)
	var visited: Dictionary = {}
	while not component.is_empty():
		var current_id := str(component.get("id", ""))
		if visited.has(current_id):
			break
		visited[current_id] = true
		var parent_id := str(component.get("parent_component_id", ""))
		if parent_id.is_empty():
			break
		depth += 1
		component = ComponentHierarchy.component_by_id(asset, parent_id)
	return depth


static func _bake_component_geometry(component: Dictionary, pivot: Vector2, scale: Vector2) -> void:
	if str(component.get("draw_mode", "closed_loop")) in ["closed_loop", "contour"]:
		BezierGeometry.resolve_auto_handles(component.get("points", []), component.get("chains", []))
		for point in component.get("points", []):
			if not point is Dictionary:
				continue
			point["position"] = pivot + (Vector2(point.get("position", Vector2.ZERO)) - pivot) * scale
			point["handle_in"] = Vector2(point.get("handle_in", Vector2.ZERO)) * scale
			point["handle_out"] = Vector2(point.get("handle_out", Vector2.ZERO)) * scale
			# An anisotropic affine bake is exact only if the currently resolved
			# cubic handles are retained instead of being regenerated afterwards.
			point["handle_source"] = "manual"
		return
	var primitive: Dictionary = component.get("primitive", {})
	primitive["center"] = pivot + (PrimitiveGeometryService.center(component) - pivot) * scale
	var diameters_cm: Vector2
	if PrimitiveGeometryService.has_circle(component):
		var diameter := float(primitive.get("diameter_cm", 1.0))
		diameters_cm = Vector2(diameter * absf(scale.x), diameter * absf(scale.y))
	else:
		diameters_cm = Vector2(float(primitive.get("diameter_x_cm", 1.0)) * absf(scale.x), float(primitive.get("diameter_y_cm", 1.0)) * absf(scale.y))
	if is_equal_approx(diameters_cm.x, diameters_cm.y):
		component["primitive"] = {"type": "circle", "center": primitive["center"], "diameter_cm": diameters_cm.x}
	else:
		component["primitive"] = {"type": PrimitiveGeometryService.ELLIPSE, "center": primitive["center"], "diameter_x_cm": diameters_cm.x, "diameter_y_cm": diameters_cm.y}


static func _bake_component_guides(asset: Dictionary, component_id: String, pivot: Vector2, scale: Vector2) -> void:
	for guide in asset.get("guides", []):
		if not guide is Dictionary or str(guide.get("scope", {}).get("component_id", "")) != component_id:
			continue
		BezierGeometry.resolve_auto_handles(guide.get("points", []), guide.get("chains", []))
		for point in guide.get("points", []):
			if not point is Dictionary:
				continue
			point["position"] = pivot + (Vector2(point.get("position", Vector2.ZERO)) - pivot) * scale
			point["handle_in"] = Vector2(point.get("handle_in", Vector2.ZERO)) * scale
			point["handle_out"] = Vector2(point.get("handle_out", Vector2.ZERO)) * scale
			point["handle_source"] = "manual"


static func _result_primitive_type(component: Dictionary, scale: Vector2) -> String:
	if not PrimitiveGeometryService.has_analytic_shape(component):
		return ""
	var diameters := PrimitiveGeometryService.diameters_tool_units(component) * Vector2(absf(scale.x), absf(scale.y))
	return "circle" if is_equal_approx(diameters.x, diameters.y) else PrimitiveGeometryService.ELLIPSE


static func _component_scale(component: Dictionary) -> Vector2:
	return Vector2(component.get("transform", {}).get("scale", Vector2.ONE))


static func _is_unit_scale(scale: Vector2) -> bool:
	return absf(scale.x - 1.0) <= SCALE_EPSILON and absf(scale.y - 1.0) <= SCALE_EPSILON
