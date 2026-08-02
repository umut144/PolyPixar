class_name MotionPathTopology
extends RefCounted

const VALID_MODES := ["linear", "free"]


static func default_topology() -> Dictionary:
	return {"next_point_index": 1, "next_segment_index": 1, "points": [], "segments": []}


static func normalize(raw_topology) -> Dictionary:
	var source: Dictionary = raw_topology if raw_topology is Dictionary else {}
	var result := default_topology()
	var raw_points = source.get("points", [])
	if raw_points is Array:
		for raw_point in raw_points:
			if not raw_point is Dictionary:
				continue
			var point_id := str(raw_point.get("id", ""))
			if point_id.is_empty() or not point_by_id(result["points"], point_id).is_empty():
				continue
			var mode := str(raw_point.get("mode", "linear"))
			result["points"].append({
				"id": point_id,
				"position": _vector(raw_point.get("position", Vector2.ZERO)),
				"mode": mode if mode in VALID_MODES else "linear",
				"handle_source": "manual" if str(raw_point.get("handle_source", "auto")) == "manual" else "auto",
				"handle_in": _vector(raw_point.get("handle_in", Vector2.ZERO)),
				"handle_out": _vector(raw_point.get("handle_out", Vector2.ZERO))
			})
	var raw_segments = source.get("segments", [])
	if raw_segments is Array:
		for raw_segment in raw_segments:
			if not raw_segment is Dictionary:
				continue
			var start_id := str(raw_segment.get("start_point_id", raw_segment.get("from_point_id", "")))
			var end_id := str(raw_segment.get("end_point_id", raw_segment.get("to_point_id", "")))
			if point_by_id(result["points"], start_id).is_empty() or point_by_id(result["points"], end_id).is_empty():
				continue
			result["segments"].append({"id": str(raw_segment.get("id", "segment_%d" % (result["segments"].size() + 1))), "start_point_id": start_id, "end_point_id": end_id})
	result["next_point_index"] = maxi(int(source.get("next_point_index", 1)), _next_suffix(result["points"], "path_point_") )
	result["next_segment_index"] = maxi(int(source.get("next_segment_index", 1)), _next_suffix(result["segments"], "path_segment_"))
	if not validate(result).is_empty():
		_rebuild_segments(result)
	return result


static func serialize(raw_topology) -> Dictionary:
	var topology := normalize(raw_topology)
	var serialized_points: Array = []
	for point in topology["points"]:
		serialized_points.append({
			"id": str(point["id"]),
			"position": _vector_array(point["position"]),
			"mode": str(point["mode"]),
			"handle_source": str(point["handle_source"]),
			"handle_in": _vector_array(point["handle_in"]),
			"handle_out": _vector_array(point["handle_out"])
		})
	return {
		"next_point_index": int(topology["next_point_index"]),
		"next_segment_index": int(topology["next_segment_index"]),
		"points": serialized_points,
		"segments": topology["segments"].duplicate(true)
	}


static func add_point(topology: Dictionary, position: Vector2) -> String:
	_normalize_in_place(topology)
	var point_id := "path_point_%d" % int(topology["next_point_index"])
	topology["next_point_index"] = int(topology["next_point_index"]) + 1
	var points: Array = topology["points"]
	var previous_id := str(points.back().get("id", "")) if not points.is_empty() else ""
	points.append({"id": point_id, "position": position, "mode": "linear", "handle_source": "auto", "handle_in": Vector2.ZERO, "handle_out": Vector2.ZERO})
	if not previous_id.is_empty():
		var segment_id := "path_segment_%d" % int(topology["next_segment_index"])
		topology["next_segment_index"] = int(topology["next_segment_index"]) + 1
		topology["segments"].append({"id": segment_id, "start_point_id": previous_id, "end_point_id": point_id})
	return point_id


static func move_point(topology: Dictionary, point_id: String, position: Vector2) -> bool:
	var point := point_by_id(topology.get("points", []), point_id)
	if point.is_empty():
		return false
	point["position"] = position
	return true


static func set_handle(topology: Dictionary, point_id: String, side: String, value: Vector2) -> bool:
	var point := point_by_id(topology.get("points", []), point_id)
	if point.is_empty() or side not in ["in", "out"]:
		return false
	point["mode"] = "free"
	point["handle_source"] = "manual"
	point["handle_%s" % side] = value
	return true


static func delete_point(topology: Dictionary, point_id: String) -> bool:
	var points: Array = topology.get("points", [])
	for index in range(points.size()):
		if str(points[index].get("id", "")) == point_id:
			points.remove_at(index)
			_rebuild_segments(topology)
			return true
	return false


static func point_by_id(points: Array, point_id: String) -> Dictionary:
	for point in points:
		if point is Dictionary and str(point.get("id", "")) == point_id:
			return point
	return {}


static func validate(raw_topology) -> Array[String]:
	var issues: Array[String] = []
	if not raw_topology is Dictionary:
		return ["Path topology is missing."]
	var points = raw_topology.get("points", [])
	var segments = raw_topology.get("segments", [])
	if not points is Array or not segments is Array:
		return ["Path points or segments are invalid."]
	var ids: Dictionary = {}
	for point in points:
		var point_id := str(point.get("id", "")) if point is Dictionary else ""
		if point_id.is_empty() or ids.has(point_id):
			issues.append("Path Point IDs must be present and unique.")
		else:
			ids[point_id] = true
	if segments.size() != maxi(0, points.size() - 1):
		issues.append("An open Path needs exactly one Segment between adjacent Points.")
	for index in range(segments.size()):
		var segment: Dictionary = segments[index]
		if index + 1 >= points.size() or str(segment.get("start_point_id", "")) != str(points[index].get("id", "")) or str(segment.get("end_point_id", "")) != str(points[index + 1].get("id", "")):
			issues.append("Path Segments must follow Point order.")
			break
	return issues


static func _normalize_in_place(topology: Dictionary) -> void:
	var normalized := normalize(topology)
	topology.clear()
	topology.merge(normalized, true)


static func _rebuild_segments(topology: Dictionary) -> void:
	var points: Array = topology.get("points", [])
	var segments: Array = []
	var next_index := maxi(1, int(topology.get("next_segment_index", 1)))
	for index in range(maxi(0, points.size() - 1)):
		segments.append({"id": "path_segment_%d" % next_index, "start_point_id": str(points[index].get("id", "")), "end_point_id": str(points[index + 1].get("id", ""))})
		next_index += 1
	topology["segments"] = segments
	topology["next_segment_index"] = next_index


static func _next_suffix(items: Array, prefix: String) -> int:
	var next_value := 1
	for item in items:
		var identifier := str(item.get("id", "")) if item is Dictionary else ""
		if identifier.begins_with(prefix):
			next_value = maxi(next_value, identifier.trim_prefix(prefix).to_int() + 1)
	return next_value


static func _vector(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


static func _vector_array(value) -> Array:
	var vector := _vector(value)
	return [vector.x, vector.y]
