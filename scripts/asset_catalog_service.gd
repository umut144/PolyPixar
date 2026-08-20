class_name AssetCatalogService
extends RefCounted

const CATALOG_SCHEMA_VERSION := 1


static func asset_key(display_name: String) -> String:
	var lowered := display_name.strip_edges().to_lower()
	var result := ""
	var separator_pending := false
	for index in range(lowered.length()):
		var codepoint := lowered.unicode_at(index)
		var is_ascii_letter := codepoint >= 97 and codepoint <= 122
		var is_digit := codepoint >= 48 and codepoint <= 57
		if is_ascii_letter or is_digit:
			if separator_pending and not result.is_empty():
				result += "_"
			result += lowered.substr(index, 1)
			separator_pending = false
		elif not result.is_empty():
			separator_pending = true
	return result


static func validation_errors(assets: Array) -> Array[String]:
	var errors: Array[String] = []
	var owner_by_key: Dictionary = {}
	for raw_asset in assets:
		if not raw_asset is Dictionary:
			errors.append("The World contains an invalid Asset record.")
			continue
		var display_name := str(raw_asset.get("name", "")).strip_edges()
		var key := asset_key(display_name)
		if key.is_empty():
			errors.append("Asset '%s' does not derive a usable lower_snake_case Asset Key." % display_name)
			continue
		if owner_by_key.has(key):
			errors.append("Assets '%s' and '%s' both derive Asset Key '%s'." % [str(owner_by_key[key]), display_name, key])
		else:
			owner_by_key[key] = display_name
	return errors


static func build_catalog(world_key: String, world_name: String, assets: Array) -> Dictionary:
	var errors := validation_errors(assets)
	if world_key.strip_edges().is_empty():
		errors.append("World key is missing.")
	if not errors.is_empty():
		return {"valid": false, "errors": errors, "catalog": {}}
	var entries: Array[Dictionary] = []
	for raw_asset in assets:
		if not raw_asset is Dictionary or not bool(raw_asset.get("visibility", true)):
			continue
		var key := asset_key(str(raw_asset.get("name", "")))
		entries.append({
			"asset_key": key,
			"display_name": str(raw_asset.get("name", "")),
			"asset_type": str(raw_asset.get("asset_type", "character")),
			"runtime_package": "PolyToolsRuntimeExports/%s/manifest.json" % key
		})
	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("asset_key", "")) < str(right.get("asset_key", ""))
	)
	return {
		"valid": true,
		"errors": [],
		"catalog": {
			"schema_version": CATALOG_SCHEMA_VERSION,
			"world_key": world_key,
			"world_name": world_name if not world_name.is_empty() else world_key,
			"assets": entries
		}
	}
