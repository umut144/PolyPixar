class_name OutlineService
extends RefCounted

## Render Outline is authored per Edge. `auto` delegates the visible decision
## to the owning Asset/Group resolver; `on` and `off` are explicit overrides.

const AUTO := "auto"
const ON := "on"
const OFF := "off"
const MODES := [AUTO, ON, OFF]


static func normalize_mode(raw_value, default_mode := AUTO) -> String:
	# Schema-44 and older data stored this as a bool. Preserve explicit Off,
	# while migrating the old visible/default state to the new automatic mode.
	if raw_value is bool:
		return AUTO if raw_value else OFF
	var mode := str(raw_value).to_lower()
	return mode if mode in MODES else default_mode


static func is_enabled(edge: Dictionary, auto_enabled := true) -> bool:
	var mode := normalize_mode(edge.get("render_outline", AUTO))
	if mode == ON:
		return true
	if mode == OFF:
		return false
	return auto_enabled


static func display_name(mode: String) -> String:
	match normalize_mode(mode):
		AUTO:
			return "Auto"
		ON:
			return "On"
		OFF:
			return "Off"
	return "Auto"
