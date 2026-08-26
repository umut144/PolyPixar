class_name WorldSettingsService
extends RefCounted

## Authored art settings shared by every Asset in one World. Editor-only grid
## and camera preferences remain separate in editor_state.

const INTRODUCED_WORLD_SCHEMA := 41
const REFERENCE_DENSITY_SCHEMA := 46
const DEFAULT_CONTOUR_STROKE_WIDTH_PX := 4.0


static func default_settings() -> Dictionary:
	return {
		"reference_pixels_per_meter": ContourStrokeService.REFERENCE_PIXELS_PER_METER,
		"contour_stroke_width_px": DEFAULT_CONTOUR_STROKE_WIDTH_PX
	}


static func decode(raw_settings, world_schema: int) -> Dictionary:
	if world_schema < INTRODUCED_WORLD_SCHEMA:
		return {
			"valid": true,
			"errors": [],
			"migrated": true,
			"migration": "schema_%d_world_contour_default" % world_schema,
			"settings": default_settings()
		}
	if world_schema < REFERENCE_DENSITY_SCHEMA:
		if not raw_settings is Dictionary:
			return _failed("World schema %d requires a typed world_settings record." % world_schema)
		var legacy_width = raw_settings.get("contour_stroke_width_px", null)
		if typeof(legacy_width) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(legacy_width)) or float(legacy_width) <= 0.0:
			return _failed("World contour_stroke_width_px must be a finite positive authored pixel value.")
		var migrated_settings := default_settings()
		migrated_settings["contour_stroke_width_px"] = float(legacy_width)
		return {
			"valid": true,
			"errors": [],
			"migrated": true,
			"migration": "schema_%d_reference_density_192" % world_schema,
			"settings": migrated_settings
		}
	if not raw_settings is Dictionary:
		return _failed("World schema %d requires a typed world_settings record." % world_schema)
	var errors: Array[String] = []
	if not raw_settings.has("reference_pixels_per_meter"):
		errors.append("World Settings require reference_pixels_per_meter.")
	elif typeof(raw_settings.get("reference_pixels_per_meter")) not in [TYPE_INT, TYPE_FLOAT]:
		errors.append("World reference_pixels_per_meter must be numeric.")
	if not raw_settings.has("contour_stroke_width_px"):
		errors.append("World Settings require contour_stroke_width_px.")
	elif typeof(raw_settings.get("contour_stroke_width_px")) not in [TYPE_INT, TYPE_FLOAT]:
		errors.append("World contour_stroke_width_px must be numeric.")
	if not errors.is_empty():
		return {"valid": false, "errors": errors, "migrated": false, "migration": "", "settings": {}}
	var reference_density := float(raw_settings.get("reference_pixels_per_meter", 0.0))
	var stroke_width_px := float(raw_settings.get("contour_stroke_width_px", 0.0))
	if not is_finite(reference_density) or not is_equal_approx(reference_density, ContourStrokeService.REFERENCE_PIXELS_PER_METER):
		errors.append("World reference density must be exactly 192 px/m.")
	if not is_finite(stroke_width_px) or stroke_width_px <= 0.0:
		errors.append("World Contour stroke width must be a finite positive authored pixel value.")
	if not errors.is_empty():
		return {"valid": false, "errors": errors, "migrated": false, "migration": "", "settings": {}}
	return {
		"valid": true,
		"errors": [],
		"migrated": false,
		"migration": "",
		"settings": {
			"reference_pixels_per_meter": reference_density,
			"contour_stroke_width_px": stroke_width_px
		}
	}


static func encode(stroke_width_px: float) -> Dictionary:
	var decoded := decode({
		"reference_pixels_per_meter": ContourStrokeService.REFERENCE_PIXELS_PER_METER,
		"contour_stroke_width_px": stroke_width_px
	}, INTRODUCED_WORLD_SCHEMA)
	return decoded.get("settings", {}).duplicate(true) if bool(decoded.get("valid", false)) else {}


static func _failed(error: String) -> Dictionary:
	return {"valid": false, "errors": [error], "migrated": false, "migration": "", "settings": {}}
