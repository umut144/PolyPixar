class_name OutlineService
extends RefCounted

## Render Outline is authored per Edge. Visibility is always a manual choice;
## overlap analysis is diagnostic only and never changes this decision.

const ON := "on"
const OFF := "off"
const MODES := [ON, OFF]


static func normalize_mode(raw_value, default_mode := ON) -> String:
	# Older data stored this as a bool. Earlier experimental Auto values are
	# intentionally normalized back to visible On now that resolution is manual.
	if raw_value is bool:
		return ON if raw_value else OFF
	var mode := str(raw_value).to_lower()
	if mode == "auto":
		return ON
	return mode if mode in MODES else default_mode


static func is_enabled(edge: Dictionary, auto_enabled := true) -> bool:
	var mode := normalize_mode(edge.get("render_outline", ON))
	if mode == ON:
		return true
	if mode == OFF:
		return false
	return auto_enabled


static func display_name(mode: String) -> String:
	match normalize_mode(mode):
		ON:
			return "On"
		OFF:
			return "Off"
	return "On"
