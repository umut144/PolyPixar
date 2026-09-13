class_name ComponentHierarchy
extends RefCounted


static func normalize_asset(asset: Dictionary) -> void:
	var groups: Array = asset.get("groups", []) if asset.get("groups", []) is Array else []
	asset["groups"] = groups
	var known_group_ids: Dictionary = {}
	for group in groups:
		if group is Dictionary:
			group["name"] = str(group.get("name", "Group"))
			group["visibility"] = bool(group.get("visibility", true))
			group.erase("z_index") # Schema 48: Z order belongs exclusively to Components.
			if not group.get("transform", {}) is Dictionary:
				group["transform"] = {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}
			var candidate_group_id := str(group.get("id", ""))
			if not candidate_group_id.is_empty():
				known_group_ids[candidate_group_id] = true
	var components: Array = asset.get("components", []) if asset.get("components", []) is Array else []
	asset["components"] = components
	var known_ids: Dictionary = {}
	for component_data in components:
		if component_data is Dictionary and str(component_data.get("type", "component")) != "guide":
			var component_id := str(component_data.get("id", ""))
			if not component_id.is_empty():
				known_ids[component_id] = true
	for component_data in components:
		if not component_data is Dictionary or str(component_data.get("type", "component")) == "guide":
			continue
		var component_id := str(component_data.get("id", ""))
		var parent_component_id := str(component_data.get("parent_component_id", ""))
		if parent_component_id == component_id or not parent_component_id.is_empty() and not known_ids.has(parent_component_id):
			parent_component_id = ""
		component_data["parent_component_id"] = parent_component_id
		var component_group_id := str(component_data.get("group_id", ""))
		component_data["group_id"] = component_group_id if known_group_ids.has(component_group_id) else ""
	_break_cycles(components)
	canonicalize_redundant_group_membership(asset)
	_normalize_group_parents(asset, known_ids)
	_normalize_guide_ordinals(asset)


static func parent_id(component_data: Dictionary) -> String:
	return str(component_data.get("parent_component_id", ""))


static func component_by_id(asset: Dictionary, component_id: String) -> Dictionary:
	for candidate in asset.get("components", []):
		if candidate is Dictionary and str(candidate.get("type", "component")) != "guide" and str(candidate.get("id", "")) == component_id:
			return candidate
	return {}


static func group_by_id(asset: Dictionary, group_id: String) -> Dictionary:
	for group in asset.get("groups", []):
		if group is Dictionary and str(group.get("id", "")) == group_id:
			return group
	return {}


static func group_parent_id(group: Dictionary) -> String:
	return str(group.get("parent_component_id", ""))


static func group_members(asset: Dictionary, group_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate in asset.get("components", []):
		if candidate is Dictionary and str(candidate.get("type", "component")) != "guide" and str(candidate.get("group_id", "")) == group_id:
			result.append(candidate)
	return result


static func direct_group_members(asset: Dictionary, group_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate in group_members(asset, group_id):
		var parent_component_id := parent_id(candidate)
		if parent_component_id.is_empty() or membership_group_id(asset, parent_component_id) != group_id:
			result.append(candidate)
	return result


static func membership_group_id(asset: Dictionary, component_id: String) -> String:
	var cursor := component_by_id(asset, component_id)
	var visited: Dictionary = {}
	while not cursor.is_empty():
		var cursor_id := str(cursor.get("id", ""))
		if visited.has(cursor_id):
			return ""
		visited[cursor_id] = true
		var own_group_id := str(cursor.get("group_id", ""))
		if not own_group_id.is_empty() and not group_by_id(asset, own_group_id).is_empty():
			return own_group_id
		cursor = component_by_id(asset, parent_id(cursor))
	return ""


static func canonicalize_redundant_group_membership(asset: Dictionary) -> void:
	var components: Array = asset.get("components", []) if asset.get("components", []) is Array else []
	var ordered: Array[Dictionary] = []
	for candidate in components:
		if candidate is Dictionary and str(candidate.get("type", "component")) != "guide":
			ordered.append(candidate)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return component_depth(asset, str(left.get("id", ""))) < component_depth(asset, str(right.get("id", "")))
	)
	for component in ordered:
		var own_group_id := str(component.get("group_id", ""))
		var parent_component_id := parent_id(component)
		if own_group_id.is_empty() or parent_component_id.is_empty():
			continue
		if membership_group_id(asset, parent_component_id) == own_group_id:
			component["group_id"] = ""


static func children(asset: Dictionary, parent_component_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate in asset.get("components", []):
		if candidate is Dictionary and str(candidate.get("type", "component")) != "guide" and parent_id(candidate) == parent_component_id:
			result.append(candidate)
	return result


static func descendants(asset: Dictionary, parent_component_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pending: Array[String] = [parent_component_id]
	while not pending.is_empty():
		var current_id: String = pending.pop_front()
		for child in children(asset, current_id):
			result.append(child)
			pending.append(str(child.get("id", "")))
	return result


static func can_parent(asset: Dictionary, component_id: String, candidate_parent_id: String) -> bool:
	var component := component_by_id(asset, component_id)
	if component.is_empty():
		return false
	if candidate_parent_id.is_empty():
		return not _is_hole_component(component)
	var candidate_parent := component_by_id(asset, candidate_parent_id)
	if component_id == candidate_parent_id or candidate_parent.is_empty() or _is_hole_component(candidate_parent):
		return false
	if _is_hole_component(component) and not WorldDocumentService.is_outer_body(candidate_parent):
		return false
	var cursor := candidate_parent_id
	var visited: Dictionary = {}
	while not cursor.is_empty():
		if cursor == component_id or visited.has(cursor):
			return false
		visited[cursor] = true
		cursor = parent_id(component_by_id(asset, cursor))
	return true


static func _is_hole_component(component: Dictionary) -> bool:
	return str(component.get("type", "component")) not in ["reference", "region"] \
		and WorldDocumentService.topology_role(component) == WorldDocumentService.ROLE_HOLE


static func can_parent_group(asset: Dictionary, group_id: String, candidate_parent_id: String) -> bool:
	var group := group_by_id(asset, group_id)
	if group.is_empty():
		return false
	if candidate_parent_id.is_empty():
		return true
	if component_by_id(asset, candidate_parent_id).is_empty() or not membership_group_id(asset, candidate_parent_id).is_empty():
		return false
	var members := group_members(asset, group_id)
	if members.is_empty():
		return false
	for member in members:
		if not _component_chain_contains(asset, str(member.get("id", "")), candidate_parent_id):
			return false
	return true


static func can_move_group_to_component(asset: Dictionary, group_id: String, candidate_parent_id: String) -> bool:
	if group_by_id(asset, group_id).is_empty():
		return false
	# An empty candidate_parent_id means moving the Group's direct Parts to
	# Asset Root, mirroring an ordinary Component's own Detach from Parent.
	if not candidate_parent_id.is_empty():
		if component_by_id(asset, candidate_parent_id).is_empty():
			return false
		# Nesting one Group through a Component owned by another Group would apply
		# two unrelated Group transforms to the same Component chain.
		if not membership_group_id(asset, candidate_parent_id).is_empty():
			return false
	var members := direct_group_members(asset, group_id)
	if members.is_empty():
		return false
	for member in members:
		if not can_parent(asset, str(member.get("id", "")), candidate_parent_id):
			return false
	return true


static func component_depth(asset: Dictionary, component_id: String) -> int:
	return maxi(_component_chain(asset, component_id).size() - 1, 0)


static func next_guide_ordinal(asset: Dictionary, component_id: String, guide_type: String) -> int:
	var highest := 0
	for guide in asset.get("guides", []):
		if not guide is Dictionary:
			continue
		if AssetGuide.scope_component_id(guide) == component_id and AssetGuide.canonical_type(str(guide.get("guide_type", ""))) == AssetGuide.canonical_type(guide_type):
			highest = maxi(highest, int(guide.get("ordinal", 0)))
	return highest + 1


static func world_transform(asset: Dictionary, component_id: String) -> Transform2D:
	return _world_transform_for_chain(asset, _component_chain(asset, component_id), membership_group_id(asset, component_id))


static func group_world_transform(asset: Dictionary, group_id: String) -> Transform2D:
	var group := group_by_id(asset, group_id)
	if group.is_empty():
		return Transform2D.IDENTITY
	var parent_component_id := group_parent_id(group)
	var parent_world := world_transform(asset, parent_component_id) if not parent_component_id.is_empty() else Transform2D.IDENTITY
	return parent_world * local_transform(group.get("transform", {}))


static func group_world_transform_record(asset: Dictionary, group_id: String) -> Dictionary:
	var group := group_by_id(asset, group_id)
	if group.is_empty():
		return _default_transform_record()
	return transform_record_from_affine(group_world_transform(asset, group_id), _vector(group.get("transform", {}).get("pivot", Vector2.ZERO), Vector2.ZERO))


# The world Transform of whichever record a Guide is scoped to, Component or
# Group. The one home for what every Guide-scope caller used to compute by
# hand from guide.scope.
static func guide_world_transform(asset: Dictionary, guide: Dictionary) -> Transform2D:
	if AssetGuide.is_group_scoped(guide):
		return group_world_transform(asset, AssetGuide.scope_group_id(guide))
	return world_transform(asset, AssetGuide.scope_component_id(guide))


static func world_transform_record(asset: Dictionary, component_id: String) -> Dictionary:
	var current := component_by_id(asset, component_id)
	if current.is_empty():
		return _default_transform_record()
	return transform_record_from_affine(world_transform(asset, component_id), _vector(current.get("transform", {}).get("pivot", Vector2.ZERO), Vector2.ZERO))


static func local_transform_from_world_record(asset: Dictionary, component_id: String, world_record: Dictionary) -> Dictionary:
	var current := component_by_id(asset, component_id)
	if current.is_empty():
		return _default_transform_record()
	var chain := _component_chain(asset, component_id)
	if not chain.is_empty():
		chain.pop_back()
	var parent_world := _world_transform_for_chain(asset, chain, membership_group_id(asset, component_id))
	var local_affine := parent_world.affine_inverse() * local_transform(world_record)
	var pivot := _vector(current.get("transform", {}).get("pivot", Vector2.ZERO), Vector2.ZERO)
	var record := transform_record_from_affine(local_affine, pivot)
	if str(current.get("type", "component")) == "reference":
		var instance_scale := _vector(current.get("reference_instance_scale", Vector2.ONE), Vector2.ONE)
		if not is_zero_approx(instance_scale.x) and not is_zero_approx(instance_scale.y):
			record["scale"] = Vector2(record.get("scale", Vector2.ONE)) / instance_scale
	return record


static func group_local_transform_from_world_record(asset: Dictionary, group_id: String, world_record: Dictionary) -> Dictionary:
	var group := group_by_id(asset, group_id)
	if group.is_empty():
		return _default_transform_record()
	var parent_component_id := group_parent_id(group)
	var parent_world := world_transform(asset, parent_component_id) if not parent_component_id.is_empty() else Transform2D.IDENTITY
	var local_affine := parent_world.affine_inverse() * local_transform(world_record)
	var pivot := _vector(group.get("transform", {}).get("pivot", Vector2.ZERO), Vector2.ZERO)
	return transform_record_from_affine(local_affine, pivot)


static func transform_record_from_affine(affine: Transform2D, pivot: Vector2) -> Dictionary:
	return {
		"position": affine * pivot,
		"rotation": rad_to_deg(affine.get_rotation()),
		"scale": affine.get_scale(),
		"pivot": pivot
	}


static func local_transform(raw_transform) -> Transform2D:
	var data: Dictionary = raw_transform if raw_transform is Dictionary else {}
	var position := _vector(data.get("position", Vector2.ZERO), Vector2.ZERO)
	var pivot := _vector(data.get("pivot", Vector2.ZERO), Vector2.ZERO)
	var scale := _vector(data.get("scale", Vector2.ONE), Vector2.ONE)
	var basis := Transform2D(deg_to_rad(float(data.get("rotation", 0.0))), scale, 0.0, Vector2.ZERO)
	basis.origin = position - basis.basis_xform(pivot)
	return basis


static func component_local_transform(component: Dictionary) -> Transform2D:
	var transform: Dictionary = component.get("transform", {}) if component.get("transform", {}) is Dictionary else {}
	if str(component.get("type", "component")) != "reference":
		return local_transform(transform)
	var effective_transform := transform.duplicate(true)
	effective_transform["scale"] = _vector(transform.get("scale", Vector2.ONE), Vector2.ONE) * _vector(component.get("reference_instance_scale", Vector2.ONE), Vector2.ONE)
	return local_transform(effective_transform)


static func _break_cycles(components: Array) -> void:
	var by_id: Dictionary = {}
	for candidate in components:
		if candidate is Dictionary:
			by_id[str(candidate.get("id", ""))] = candidate
	for candidate in components:
		if not candidate is Dictionary:
			continue
		var cursor := str(candidate.get("id", ""))
		var visited: Dictionary = {}
		while not cursor.is_empty() and by_id.has(cursor):
			if visited.has(cursor):
				candidate["parent_component_id"] = ""
				break
			visited[cursor] = true
			cursor = str(by_id[cursor].get("parent_component_id", ""))


static func _normalize_group_parents(asset: Dictionary, known_component_ids: Dictionary) -> void:
	for group in asset.get("groups", []):
		if not group is Dictionary:
			continue
		var group_id := str(group.get("id", ""))
		var candidate_parent_id := group_parent_id(group)
		if candidate_parent_id.is_empty():
			group["parent_component_id"] = ""
			continue
		if not known_component_ids.has(candidate_parent_id) or not can_parent_group(asset, group_id, candidate_parent_id):
			group["parent_component_id"] = ""


static func _component_chain(asset: Dictionary, component_id: String) -> Array[Dictionary]:
	var chain: Array[Dictionary] = []
	var cursor := component_by_id(asset, component_id)
	var visited: Dictionary = {}
	while not cursor.is_empty():
		var cursor_id := str(cursor.get("id", ""))
		if visited.has(cursor_id):
			break
		visited[cursor_id] = true
		chain.push_front(cursor)
		cursor = component_by_id(asset, parent_id(cursor))
	return chain


static func _world_transform_for_chain(asset: Dictionary, chain: Array[Dictionary], effective_group_id: String) -> Transform2D:
	var group := group_by_id(asset, effective_group_id)
	var group_parent_component_id := group_parent_id(group) if not group.is_empty() else ""
	var group_transform := local_transform(group.get("transform", {})) if not group.is_empty() else Transform2D.IDENTITY
	var result := group_transform if not group.is_empty() and group_parent_component_id.is_empty() else Transform2D.IDENTITY
	for chain_component in chain:
		result = result * component_local_transform(chain_component)
		if not group.is_empty() and str(chain_component.get("id", "")) == group_parent_component_id:
			result = result * group_transform
	return result


static func _component_chain_contains(asset: Dictionary, component_id: String, ancestor_id: String) -> bool:
	for chain_component in _component_chain(asset, component_id):
		if str(chain_component.get("id", "")) == ancestor_id:
			return true
	return false


static func _normalize_guide_ordinals(asset: Dictionary) -> void:
	var guides: Array = asset.get("guides", []) if asset.get("guides", []) is Array else []
	asset["guides"] = guides
	var used_by_scope: Dictionary = {}
	for guide in guides:
		if not guide is Dictionary:
			continue
		var component_id := AssetGuide.scope_component_id(guide)
		var guide_type := AssetGuide.canonical_type(str(guide.get("guide_type", "")))
		guide["guide_type"] = guide_type
		var key := "%s\u001f%s" % [component_id, guide_type]
		if not used_by_scope.has(key):
			used_by_scope[key] = {}
		var used: Dictionary = used_by_scope[key]
		var ordinal := int(guide.get("ordinal", 0))
		if ordinal < 1 or used.has(ordinal):
			ordinal = 1
			while used.has(ordinal):
				ordinal += 1
		guide["ordinal"] = ordinal
		used[ordinal] = true


static func _vector(value, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


static func _default_transform_record() -> Dictionary:
	return {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}
