class_name AssetScaleRebaseService
extends RefCounted

## Bakes one positive uniform Asset-root Scale into canonical authoring data.
## Uniform scaling commutes with every local rotation and scale, so scaling all
## local coordinates once preserves nested Component/Group hierarchy exactly.

const SCALE_EPSILON := 0.000001


static func root_scale(asset: Dictionary) -> float:
	var value := float(asset.get("root_scale", 1.0))
	return value if is_finite(value) and value > SCALE_EPSILON else 1.0


static func root_transform(asset: Dictionary) -> Transform2D:
	var scale := root_scale(asset)
	var pivot := Vector2(asset.get("asset_pivot", Vector2.ZERO))
	var affine := Transform2D(0.0, Vector2(scale, scale), 0.0, pivot)
	affine.origin = pivot - affine.basis_xform(pivot)
	return affine


static func analyze_asset(asset: Dictionary) -> Dictionary:
	var raw_scale := float(asset.get("root_scale", 1.0))
	var blockers: Array[String] = []
	if not is_finite(raw_scale) or raw_scale <= SCALE_EPSILON:
		blockers.append("Root Scale must be finite and greater than zero.")
	if not _motion_is_default(asset):
		blockers.append("Authored Motion data must be removed or converted before Root Scale Rebase.")
	var required := is_finite(raw_scale) and absf(raw_scale - 1.0) > SCALE_EPSILON
	return {
		"valid": blockers.is_empty(),
		"required": required,
		"can_rebase": required and blockers.is_empty(),
		"scale": raw_scale,
		"blockers": blockers
	}


static func rebase_asset(asset: Dictionary) -> Dictionary:
	var analysis := analyze_asset(asset)
	if not bool(analysis.get("can_rebase", false)):
		var errors: Array = analysis.get("blockers", []).duplicate()
		if errors.is_empty():
			errors.append("Root Scale is already normalized to 1.")
		return {"valid": false, "errors": errors, "analysis": analysis}
	var working := asset.duplicate(true)
	var scale := float(analysis.get("scale", 1.0))
	var asset_pivot := Vector2(working.get("asset_pivot", Vector2.ZERO))

	for group in working.get("groups", []):
		if not group is Dictionary:
			continue
		var root_scope := str(group.get("parent_component_id", "")).is_empty()
		group["transform"] = _scaled_transform(group.get("transform", {}), scale, asset_pivot, root_scope)

	for component in working.get("components", []):
		if not component is Dictionary or str(component.get("type", "component")) == "guide":
			continue
		var component_id := str(component.get("id", ""))
		var root_scope := str(component.get("parent_component_id", "")).is_empty() and ComponentHierarchy.membership_group_id(working, component_id).is_empty()
		var is_reference := str(component.get("type", "component")) == "reference"
		component["transform"] = _scaled_transform(component.get("transform", {}), scale, asset_pivot, root_scope, not is_reference)
		_scale_component_source(component, scale)

	for guide in working.get("guides", []):
		if guide is Dictionary:
			_scale_guide(guide, scale, asset_pivot)

	working["root_scale"] = 1.0
	asset.clear()
	asset.merge(working, true)
	return {"valid": true, "errors": [], "analysis": analysis}


static func _scaled_transform(raw_transform, scale: float, asset_pivot: Vector2, root_scope: bool, scale_pivot := true) -> Dictionary:
	var transform: Dictionary = raw_transform.duplicate(true) if raw_transform is Dictionary else {}
	var position := Vector2(transform.get("position", Vector2.ZERO))
	var pivot := Vector2(transform.get("pivot", Vector2.ZERO))
	transform["position"] = asset_pivot + (position - asset_pivot) * scale if root_scope else position * scale
	transform["pivot"] = pivot * scale if scale_pivot else pivot
	transform["rotation"] = float(transform.get("rotation", 0.0))
	transform["scale"] = Vector2(transform.get("scale", Vector2.ONE))
	return transform


static func _scale_component_source(component: Dictionary, scale: float) -> void:
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
		primitive["diameter_cm"] = float(primitive.get("diameter_cm", 1.0)) * scale
		component["primitive"] = primitive
	elif PrimitiveGeometryService.has_ellipse(component):
		primitive["center"] = PrimitiveGeometryService.center(component) * scale
		primitive["diameter_x_cm"] = float(primitive.get("diameter_x_cm", 1.0)) * scale
		primitive["diameter_y_cm"] = float(primitive.get("diameter_y_cm", 1.0)) * scale
		component["primitive"] = primitive


static func _scale_guide(guide: Dictionary, scale: float, asset_pivot: Vector2) -> void:
	var scope: Dictionary = guide.get("scope", {})
	var scoped := str(scope.get("kind", "component")) in ["component", "group"]
	for point in guide.get("points", []):
		if not point is Dictionary:
			continue
		var position := Vector2(point.get("position", Vector2.ZERO))
		point["position"] = position * scale if scoped else asset_pivot + (position - asset_pivot) * scale
		point["handle_in"] = Vector2(point.get("handle_in", Vector2.ZERO)) * scale
		point["handle_out"] = Vector2(point.get("handle_out", Vector2.ZERO)) * scale
	if AssetGuide.is_weapon_frame(str(guide.get("guide_type", ""))):
		guide["transform"] = _scaled_transform(guide.get("transform", {}), scale, asset_pivot, not scoped)


static func _motion_is_default(asset: Dictionary) -> bool:
	var current = asset.get("animation", {}).duplicate(true) if asset.get("animation", {}) is Dictionary else {}
	var default_document := MotionWorkspace.create_default_animation_document()
	return MotionWorkspace.normalize_animation_document(current) == MotionWorkspace.normalize_animation_document(default_document)
