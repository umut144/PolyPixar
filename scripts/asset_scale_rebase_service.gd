class_name AssetScaleRebaseService
extends RefCounted

## Bakes the Asset-root Position and two positive Scale axes into canonical
## authoring data. Legacy scalar root_scale values are interpreted as the same
## value on both axes.

const SCALE_EPSILON := 0.000001


static func root_scale(asset: Dictionary) -> Vector2:
	var value := _root_scale_value(asset.get("root_scale", Vector2.ONE))
	return value if _is_valid_scale(value) else Vector2.ONE


static func is_valid_root_scale(asset: Dictionary) -> bool:
	return _is_valid_scale(_root_scale_value(asset.get("root_scale", Vector2.ONE)))


static func root_position(asset: Dictionary) -> Vector2:
	var value := Vector2(asset.get("root_position", Vector2.ZERO))
	return value if value.is_finite() else Vector2.ZERO


static func root_transform(asset: Dictionary) -> Transform2D:
	var scale := root_scale(asset)
	var pivot := Vector2(asset.get("asset_pivot", Vector2.ZERO))
	var position := root_position(asset)
	var affine := Transform2D(0.0, scale, 0.0, pivot)
	affine.origin = position + pivot - affine.basis_xform(pivot)
	return affine


static func analyze_asset(asset: Dictionary) -> Dictionary:
	var raw_scale := _root_scale_value(asset.get("root_scale", Vector2.ONE))
	var raw_position := Vector2(asset.get("root_position", Vector2.ZERO))
	var blockers: Array[String] = []
	if not _is_valid_scale(raw_scale):
		blockers.append("Root Scale X and Y must be finite and greater than zero.")
	if not raw_position.is_finite():
		blockers.append("Root Position must be finite.")
	if not _motion_is_default(asset):
		blockers.append("Authored Motion data must be removed or converted before Asset Transform Rebase.")
	var scale_required := _is_valid_scale(raw_scale) and not raw_scale.is_equal_approx(Vector2.ONE)
	var position_required := raw_position.is_finite() and not raw_position.is_zero_approx()
	var required := scale_required or position_required
	return {
		"valid": blockers.is_empty(),
		"required": required,
		"can_rebase": required and blockers.is_empty(),
		"scale": raw_scale,
		"position": raw_position,
		"blockers": blockers
	}


static func rebase_asset(asset: Dictionary) -> Dictionary:
	var analysis := analyze_asset(asset)
	if not bool(analysis.get("can_rebase", false)):
		var errors: Array = analysis.get("blockers", []).duplicate()
		if errors.is_empty():
			errors.append("Asset Root Transform is already normalized.")
		return {"valid": false, "errors": errors, "analysis": analysis}
	var working := asset.duplicate(true)
	var scale := Vector2(analysis.get("scale", Vector2.ONE))
	var root_offset := Vector2(analysis.get("position", Vector2.ZERO))
	var asset_pivot := Vector2(working.get("asset_pivot", Vector2.ZERO))

	for group in working.get("groups", []):
		if not group is Dictionary:
			continue
		var root_scope := str(group.get("parent_component_id", "")).is_empty()
		group["transform"] = _rebased_transform(group.get("transform", {}), scale, root_offset, asset_pivot, root_scope)

	for component in working.get("components", []):
		if not component is Dictionary or str(component.get("type", "component")) == "guide":
			continue
		var component_id := str(component.get("id", ""))
		var root_scope := str(component.get("parent_component_id", "")).is_empty() and ComponentHierarchy.membership_group_id(working, component_id).is_empty()
		var is_reference := str(component.get("type", "component")) == "reference"
		component["transform"] = _rebased_transform(component.get("transform", {}), scale, root_offset, asset_pivot, root_scope, not is_reference)
		if is_reference or WorldDocumentService.is_primitive(component):
			_scale_component_source(component, scale)

	# Anisotropic root scaling does not commute with a rotated Component
	# transform. Bake the exact affine into Bézier source coordinates after all
	# hierarchy placements have been rebased; uniform scaling naturally reduces
	# to the legacy component-wise multiplication.
	for component in working.get("components", []):
		if not component is Dictionary or str(component.get("type", "component")) == "guide" or str(component.get("type", "component")) == "reference" or WorldDocumentService.is_primitive(component):
			continue
		var component_id := str(component.get("id", ""))
		var old_world := ComponentHierarchy.world_transform(asset, component_id)
		var new_world := ComponentHierarchy.world_transform(working, component_id)
		_affine_transform_component_source(component, new_world.affine_inverse() * root_transform(asset) * old_world)

	for guide in working.get("guides", []):
		if guide is Dictionary:
			_rebase_guide(guide, scale, root_offset, asset_pivot)
			_affine_transform_guide_points(asset, working, guide)

	if typeof(asset.get("root_scale", Vector2.ONE)) in [TYPE_INT, TYPE_FLOAT]:
		working["root_scale"] = 1.0
	else:
		working["root_scale"] = Vector2.ONE
	working["root_position"] = Vector2.ZERO
	asset.clear()
	asset.merge(working, true)
	return {"valid": true, "errors": [], "analysis": analysis}


static func _rebased_transform(raw_transform, scale: Vector2, root_offset: Vector2, asset_pivot: Vector2, root_scope: bool, scale_pivot := true) -> Dictionary:
	var transform: Dictionary = raw_transform.duplicate(true) if raw_transform is Dictionary else {}
	var position := Vector2(transform.get("position", Vector2.ZERO))
	var pivot := Vector2(transform.get("pivot", Vector2.ZERO))
	transform["position"] = root_offset + asset_pivot + (position - asset_pivot) * scale if root_scope else position * scale
	transform["pivot"] = pivot * scale if scale_pivot else pivot
	transform["rotation"] = float(transform.get("rotation", 0.0))
	transform["scale"] = Vector2(transform.get("scale", Vector2.ONE))
	return transform


static func _scale_component_source(component: Dictionary, scale: Vector2) -> void:
	if str(component.get("type", "component")) == "reference":
		component["reference_instance_scale"] = Vector2(component.get("reference_instance_scale", Vector2.ONE)) * scale
		return
	for point in component.get("points", []):
		if not point is Dictionary:
			continue
		point["position"] = Vector2(point.get("position", Vector2.ZERO)) * scale
		point["handle_in"] = Vector2(point.get("handle_in", Vector2.ZERO)) * scale
		point["handle_out"] = Vector2(point.get("handle_out", Vector2.ZERO)) * scale
	var primitive: Dictionary = component.get("primitive", {})
	if PrimitiveGeometryService.has_circle(component):
		primitive["center"] = PrimitiveGeometryService.center(component) * scale
		var diameter := float(primitive.get("diameter_cm", 1.0))
		if is_equal_approx(scale.x, scale.y):
			primitive["diameter_cm"] = diameter * scale.x
		else:
			primitive["type"] = PrimitiveGeometryService.ELLIPSE
			primitive.erase("diameter_cm")
			primitive["diameter_x_cm"] = diameter * scale.x
			primitive["diameter_y_cm"] = diameter * scale.y
		component["primitive"] = primitive
	elif PrimitiveGeometryService.has_ellipse(component):
		primitive["center"] = PrimitiveGeometryService.center(component) * scale
		primitive["diameter_x_cm"] = float(primitive.get("diameter_x_cm", 1.0)) * scale.x
		primitive["diameter_y_cm"] = float(primitive.get("diameter_y_cm", 1.0)) * scale.y
		component["primitive"] = primitive


static func _affine_transform_component_source(component: Dictionary, affine: Transform2D) -> void:
	for point in component.get("points", []):
		if not point is Dictionary:
			continue
		point["position"] = affine * Vector2(point.get("position", Vector2.ZERO))
		point["handle_in"] = affine.basis_xform(Vector2(point.get("handle_in", Vector2.ZERO)))
		point["handle_out"] = affine.basis_xform(Vector2(point.get("handle_out", Vector2.ZERO)))


static func _rebase_guide(guide: Dictionary, scale: Vector2, root_offset: Vector2, asset_pivot: Vector2) -> void:
	var scope: Dictionary = guide.get("scope", {})
	var scoped := str(scope.get("kind", "component")) in ["component", "group"]
	if AssetGuide.is_weapon_frame(str(guide.get("guide_type", ""))):
		guide["transform"] = _rebased_transform(guide.get("transform", {}), scale, root_offset, asset_pivot, not scoped)


static func _affine_transform_guide_points(old_asset: Dictionary, new_asset: Dictionary, guide: Dictionary) -> void:
	var scope: Dictionary = guide.get("scope", {})
	var scope_kind := str(scope.get("kind", "component"))
	var old_scope := _guide_scope_world_transform(old_asset, scope_kind, scope)
	var new_scope := _guide_scope_world_transform(new_asset, scope_kind, scope)
	var affine := new_scope.affine_inverse() * root_transform(old_asset) * old_scope if scope_kind in ["component", "group"] else root_transform(old_asset)
	for point in guide.get("points", []):
		if not point is Dictionary:
			continue
		point["position"] = affine * Vector2(point.get("position", Vector2.ZERO))
		point["handle_in"] = affine.basis_xform(Vector2(point.get("handle_in", Vector2.ZERO)))
		point["handle_out"] = affine.basis_xform(Vector2(point.get("handle_out", Vector2.ZERO)))


static func _guide_scope_world_transform(asset: Dictionary, scope_kind: String, scope: Dictionary) -> Transform2D:
	if scope_kind == "group":
		return ComponentHierarchy.group_world_transform(asset, str(scope.get("group_id", "")))
	if scope_kind == "component":
		return ComponentHierarchy.world_transform(asset, str(scope.get("component_id", "")))
	return Transform2D.IDENTITY


static func _motion_is_default(asset: Dictionary) -> bool:
	var current = asset.get("animation", {}).duplicate(true) if asset.get("animation", {}) is Dictionary else {}
	var default_document := MotionWorkspace.create_default_animation_document()
	return MotionWorkspace.normalize_animation_document(current) == MotionWorkspace.normalize_animation_document(default_document)


static func _root_scale_value(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		var scalar := float(value)
		return Vector2(scalar, scalar)
	return Vector2(INF, INF)


static func _is_valid_scale(value: Vector2) -> bool:
	return value.is_finite() and value.x > SCALE_EPSILON and value.y > SCALE_EPSILON
