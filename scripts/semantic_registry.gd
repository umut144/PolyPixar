class_name SemanticRegistry
extends RefCounted

const REGISTRY_SCHEMA_VERSION := 1
const REGISTRY_PATH := "res://configs/semantic_keys.json"
const KEY_PATTERN := "^[a-z][a-z0-9_]*$"
const MIRROR_PAIRS := {
	"eye_left": "eye_right",
	"eye_right": "eye_left",
	"eyebrow_left": "eyebrow_right",
	"eyebrow_right": "eyebrow_left"
}
const LEGACY_ALIASES := {
	"armline": "arm_line",
	"belly": "belly",
	"body": "body",
	"cloak": "cloak",
	"eyebrowl": "eyebrow_left",
	"eyebrowr": "eyebrow_right",
	"eyel": "eye_left",
	"eyer": "eye_right",
	"hat": "hat",
	"hatback": "hat_back",
	"hattip": "hat_tip",
	"head": "head",
	"headtip": "head_tip",
	"trapez": "feet",
	"trunk": "body"
}


static func load_registry(path := REGISTRY_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"valid": false, "errors": ["Semantic Registry is missing."], "semantics": []}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
	return validate_registry(parsed)


static func validate_registry(raw) -> Dictionary:
	var errors: Array[String] = []
	if not raw is Dictionary:
		return {"valid": false, "errors": ["Semantic Registry must be a JSON object."], "semantics": []}
	if int(raw.get("schema_version", 0)) != REGISTRY_SCHEMA_VERSION:
		errors.append("Unsupported Semantic Registry schema version.")
	var semantics: Array[String] = []
	var seen: Dictionary = {}
	for value in raw.get("semantics", []):
		var key := str(value)
		if not key_is_valid(key):
			errors.append("Invalid Semantic Key '%s'." % key)
		elif seen.has(key):
			errors.append("Semantic Key '%s' is duplicated." % key)
		else:
			seen[key] = true
			semantics.append(key)
	var sorted := semantics.duplicate()
	sorted.sort()
	if semantics != sorted:
		errors.append("Semantic Keys must be sorted alphabetically.")
	if semantics.is_empty():
		errors.append("Semantic Registry must contain at least one key.")
	return {"valid": errors.is_empty(), "errors": errors, "schema_version": int(raw.get("schema_version", 0)), "semantics": semantics}


static func key_is_valid(key: String) -> bool:
	var regex := RegEx.new()
	return regex.compile(KEY_PATTERN) == OK and regex.search(key) != null


static func contains(registry: Dictionary, key: String) -> bool:
	return key in registry.get("semantics", [])


static func component_display_name(component: Dictionary, registry: Dictionary) -> String:
	var key := str(component.get("semantic_key", ""))
	var missing_source := str(component.get("missing_semantic_source", "unassigned"))
	return key if contains(registry, key) else "missing_semantic (%s)" % (key if not key.is_empty() else missing_source)


static func migrate_legacy_key(asset_name: String, component: Dictionary, registry: Dictionary) -> String:
	var persisted_role := str(component.get("semantic_role", "")).strip_edges().to_lower()
	if contains(registry, persisted_role):
		return persisted_role
	var legacy_name := str(component.get("name", "")).strip_edges()
	var normalized := legacy_name.to_lower().replace("_", "").replace(" ", "").replace("-", "")
	var resolved := ""
	if normalized == "heart" or normalized == "orb" and asset_name.to_lower() == "orb":
		resolved = "body"
	elif normalized == "orb" and asset_name.to_lower() == "barde":
		resolved = "belly"
	else:
		resolved = str(LEGACY_ALIASES.get(normalized, ""))
	return resolved if contains(registry, resolved) else ""


static func mirror_key(key: String) -> String:
	return str(MIRROR_PAIRS.get(key, ""))


static func key_used_by_other(asset: Dictionary, key: String, excluded_component_id := "") -> bool:
	if key.is_empty():
		return false
	for component in asset.get("components", []):
		if component is Dictionary and str(component.get("id", "")) != excluded_component_id and str(component.get("semantic_key", "")) == key:
			return true
	return false
