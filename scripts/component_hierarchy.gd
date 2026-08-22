class_name ComponentHierarchy
extends RefCounted


static func normalize_asset(asset: Dictionary) -> void:
	var groups: Array = asset.get("groups", []) if asset.get("groups", []) is Array else []
	asset["groups"] = groups
	var known_group_ids: Dictionary = {}
	for group in groups:
		if group is Dictionary:
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
	if candidate_parent_id.is_empty():
		return not component_by_id(asset, component_id).is_empty()
	if component_id == candidate_parent_id or component_by_id(asset, component_id).is_empty() or component_by_id(asset, candidate_parent_id).is_empty():
		return false
	var cursor := candidate_parent_id
	var visited: Dictionary = {}
	while not cursor.is_empty():
		if cursor == component_id or visited.has(cursor):
			return false
		visited[cursor] = true
		cursor = parent_id(component_by_id(asset, cursor))
	return true


static func next_guide_ordinal(asset: Dictionary, component_id: String, guide_type: String) -> int:
	var highest := 0
	for guide in asset.get("guides", []):
		if not guide is Dictionary:
			continue
		if str(guide.get("scope", {}).get("component_id", "")) == component_id and AssetGuide.canonical_type(str(guide.get("guide_type", ""))) == AssetGuide.canonical_type(guide_type):
			highest = maxi(highest, int(guide.get("ordinal", 0)))
	return highest + 1


static func world_transform(asset: Dictionary, component_id: String) -> Transform2D:
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
	var result := Transform2D.IDENTITY
	var effective_group_id := membership_group_id(asset, component_id)
	if not effective_group_id.is_empty():
		result = local_transform(group_by_id(asset, effective_group_id).get("transform", {}))
	for chain_component in chain:
		result = result * local_transform(chain_component.get("transform", {}))
	return result


static func world_transform_record(asset: Dictionary, component_id: String) -> Dictionary:
	var current := component_by_id(asset, component_id)
	if current.is_empty():
		return _default_transform_record()
	return transform_record_from_affine(world_transform(asset, component_id), _vector(current.get("transform", {}).get("pivot", Vector2.ZERO), Vector2.ZERO))


static func local_transform_from_world_record(asset: Dictionary, component_id: String, world_record: Dictionary) -> Dictionary:
	var current := component_by_id(asset, component_id)
	if current.is_empty():
		return _default_transform_record()
	var parent_world := Transform2D.IDENTITY
	var effective_group_id := membership_group_id(asset, component_id)
	if not effective_group_id.is_empty():
		parent_world = local_transform(group_by_id(asset, effective_group_id).get("transform", {}))
	var current_parent_id := parent_id(current)
	if not current_parent_id.is_empty():
		parent_world = world_transform(asset, current_parent_id)
	var local_affine := parent_world.affine_inverse() * local_transform(world_record)
	var pivot := _vector(current.get("transform", {}).get("pivot", Vector2.ZERO), Vector2.ZERO)
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


static func _normalize_guide_ordinals(asset: Dictionary) -> void:
	var guides: Array = asset.get("guides", []) if asset.get("guides", []) is Array else []
	asset["guides"] = guides
	var used_by_scope: Dictionary = {}
	for guide in guides:
		if not guide is Dictionary:
			continue
		var component_id := str(guide.get("scope", {}).get("component_id", ""))
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
