class_name AssetGuide
extends RefCounted

const FLOW := "flow"
const SAMPLE := "sample"
const MOTION := "motion"
const BODY_FLOW := FLOW
const SAMPLER_SPINE := SAMPLE
const ANIMATION_SPINE := MOTION
const VALID_TYPES := [FLOW, SAMPLE, MOTION]
const SAMPLER_SPINE_COLOR := Color("#f2c94c")
const ANIMATION_SPINE_COLOR := Color("#c084fc")


static func create(guide_id: String, guide_name: String, guide_type: String, component_id: String, ordinal := 1) -> Dictionary:
	return {
		"id": guide_id,
		"type": "guide",
		"guide_type": canonical_type(guide_type),
		"name": guide_name,
		"ordinal": maxi(1, ordinal),
		"visibility": true,
		"scope": {"kind": "component", "component_id": component_id},
		"points": [],
		"edges": [],
		"chains": []
	}


static func normalize(raw_guide) -> Dictionary:
	var source: Dictionary = raw_guide if raw_guide is Dictionary else {}
	var guide_type := canonical_type(str(source.get("guide_type", SAMPLER_SPINE)))
	var scope_source = source.get("scope", {})
	if not scope_source is Dictionary:
		scope_source = {}
	var topology := {
		"points": source.get("points", []).duplicate(true) if source.get("points", []) is Array else [],
		"edges": source.get("edges", []).duplicate(true) if source.get("edges", []) is Array else [],
		"chains": source.get("chains", []).duplicate(true) if source.get("chains", []) is Array else []
	}
	var normalized := {
		"id": str(source.get("id", "")),
		"type": "guide",
		"guide_type": guide_type,
		"name": str(source.get("name", display_name(guide_type))),
		"ordinal": maxi(0, int(source.get("ordinal", 0))),
		"visibility": bool(source.get("visibility", true)),
		"scope": {"kind": "component", "component_id": str(scope_source.get("component_id", source.get("component_id", "")))},
		"points": topology["points"],
		"edges": topology["edges"],
		"chains": topology["chains"]
	}
	for point_data in normalized["points"]:
		if point_data is Dictionary:
			point_data["mode"] = "aligned"
			point_data["handle_source"] = "auto"
	BezierGeometry.resolve_auto_handles(normalized["points"], normalized["chains"])
	return normalized


static func display_name(guide_type: String) -> String:
	var normalized_type := canonical_type(guide_type)
	if normalized_type == FLOW:
		return "Flow"
	if normalized_type == MOTION:
		return "Motion"
	return "Sample"


static func canonical_type(guide_type: String) -> String:
	match guide_type:
		FLOW, "body_flow":
			return FLOW
		MOTION, "animation_spine":
			return MOTION
		SAMPLE, "sampler_spine":
			return SAMPLE
	return SAMPLE


static func outliner_name(guide: Dictionary, component_name: String) -> String:
	return "%s → %s%02d" % [component_name, display_name(str(guide.get("guide_type", SAMPLE))), maxi(1, int(guide.get("ordinal", 1)))]


static func color(guide_type: String) -> Color:
	return ANIMATION_SPINE_COLOR if guide_type == ANIMATION_SPINE else SAMPLER_SPINE_COLOR


static func validation_issues(guide: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(guide.get("guide_type", "")) not in VALID_TYPES:
		errors.append("Unknown Guide type.")
	if str(guide.get("scope", {}).get("component_id", "")).is_empty():
		errors.append("The Guide needs a target Component.")
	var chains: Array = guide.get("chains", [])
	if chains.size() != 1 or bool(chains[0].get("closed", false)) or chains[0].get("point_ids", []).size() < 2:
		errors.append("A Spine must contain one open Chain with at least two Points.")
	errors.append_array(BezierTopology.validate(guide))
	return errors
