extends SceneTree


func _initialize() -> void:
	if not ClassDB.class_exists(&"PolyToolsCDT"):
		_fail("PolyToolsCDT GDExtension class was not loaded.")
		return
	var cdt: Object = ClassDB.instantiate(&"PolyToolsCDT")
	var vertices := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(2.0, 0.0),
		Vector2(2.0, 2.0),
		Vector2(0.0, 2.0),
	])
	var constraints := PackedInt32Array([0, 1, 1, 2, 2, 3, 3, 0, 0, 2])
	var first: Dictionary = cdt.triangulate(vertices, constraints)
	var second: Dictionary = cdt.triangulate(vertices, constraints)
	if not bool(first.get("valid", false)):
		_fail("Native CDT rejected valid input: %s" % [first.get("errors", [])])
		return
	if first.get("triangles") != second.get("triangles"):
		_fail("Native CDT output is not deterministic.")
		return
	var triangles: PackedInt32Array = first.get("triangles", PackedInt32Array())
	if triangles.size() != 6:
		_fail("Expected two triangles, got %d indices." % triangles.size())
		return
	var bad: Dictionary = cdt.triangulate(vertices, PackedInt32Array([0, 9]))
	if bool(bad.get("valid", true)):
		_fail("Native CDT accepted an invalid constraint index.")
		return
	print("Native CDT smoke test passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
