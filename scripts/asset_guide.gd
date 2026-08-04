class_name AssetGuide
extends RefCounted

const BODY_FLOW := "body_flow"
const SAMPLER_SPINE := "sampler_spine"
const ANIMATION_SPINE := "animation_spine"
const VALID_TYPES := [BODY_FLOW, SAMPLER_SPINE, ANIMATION_SPINE]


static func create(guide_id: String, guide_name: String, guide_type: String, component_id: String) -> Dictionary:
	return {
		"id": guide_id,
		"type": "guide",
		"guide_type": guide_type if guide_type in VALID_TYPES else SAMPLER_SPINE,
		"name": guide_name,
		"visibility": true,
		"scope": {"kind": "component", "component_id": component_id},
		"points": [],
		"edges": [],
		"chains": []
	}


static func normalize(raw_guide) -> Dictionary:
	var source: Dictionary = raw_guide if raw_guide is Dictionary else {}
	var guide_type := str(source.get("guide_type", SAMPLER_SPINE))
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
		"guide_type": guide_type if guide_type in VALID_TYPES else SAMPLER_SPINE,
		"name": str(source.get("name", display_name(guide_type))),
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
	if guide_type == BODY_FLOW:
		return "Body Flow"
	if guide_type == ANIMATION_SPINE:
		return "Animation Spine"
	return "Sampler Spine"


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
