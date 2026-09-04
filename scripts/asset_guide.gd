class_name AssetGuide
extends RefCounted

const FLOW := "flow"
const SAMPLE := "sample"
const MOTION := "motion"
const CUT := "cut"
const WEAPON_SOCKET_PRIMARY := "weapon_socket_primary"
const GRIP_PRIMARY := "grip_primary"
const GRIP_SECONDARY := "grip_secondary"
const ATTACK_POINT_PRIMARY := "attack_point_primary"
const REACH_LIMIT_PRIMARY := "reach_limit_primary"
const BODY_FLOW := FLOW
const SAMPLER_SPINE := SAMPLE
const ANIMATION_SPINE := MOTION
const WEAPON_TYPES := [WEAPON_SOCKET_PRIMARY, GRIP_PRIMARY, GRIP_SECONDARY, ATTACK_POINT_PRIMARY, REACH_LIMIT_PRIMARY]
const VALID_TYPES := [FLOW, SAMPLE, MOTION, CUT, WEAPON_SOCKET_PRIMARY, GRIP_PRIMARY, GRIP_SECONDARY, ATTACK_POINT_PRIMARY, REACH_LIMIT_PRIMARY]
const FLOW_COLOR := Color("#4267b2")
const SAMPLE_COLOR := Color("#f2c94c")
const MOTION_COLOR := Color("#c084fc")
const SAMPLER_SPINE_COLOR := SAMPLE_COLOR
const ANIMATION_SPINE_COLOR := MOTION_COLOR
const SCOPE_COMPONENT := "component"
const SCOPE_GROUP := "group"


static func create(guide_id: String, guide_name: String, guide_type: String, component_id: String, ordinal := 1) -> Dictionary:
	return {
		"id": guide_id,
		"type": "guide",
		"guide_type": canonical_type(guide_type),
		"name": guide_name,
		"ordinal": maxi(1, ordinal),
		"visibility": true,
		"scope": {"kind": SCOPE_COMPONENT, "component_id": component_id},
		"points": [],
		"edges": [],
		"chains": []
	}


static func create_weapon_frame(guide_id: String, guide_type: String, raw_scope_kind: String, scope_id: String) -> Dictionary:
	var normalized_type := canonical_type(guide_type)
	var scope := {"kind": raw_scope_kind if raw_scope_kind == SCOPE_GROUP else SCOPE_COMPONENT}
	if scope["kind"] == SCOPE_GROUP:
		scope["group_id"] = scope_id
	else:
		scope["component_id"] = scope_id
	return {
		"id": guide_id,
		"type": "guide",
		"guide_type": normalized_type,
		"name": normalized_type,
		"ordinal": 1,
		"visibility": true,
		"scope": scope,
		"transform": {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO},
		"points": [],
		"edges": [],
		"chains": []
	}


# Whether a Guide's scope is a Group rather than a Component. Guides always
# carry one of the two kinds once normalized; SCOPE_COMPONENT is the default
# for a scope that predates the field or was malformed on disk.
static func is_group_scoped(guide: Dictionary) -> bool:
	return scope_kind(guide) == SCOPE_GROUP


static func scope_kind(guide: Dictionary) -> String:
	var scope = guide.get("scope", {})
	if not scope is Dictionary:
		return SCOPE_COMPONENT
	return str(scope.get("kind", SCOPE_COMPONENT))


# The Component a Component-scoped Guide belongs to; empty for Group scope.
static func scope_component_id(guide: Dictionary) -> String:
	var scope = guide.get("scope", {})
	if not scope is Dictionary:
		return ""
	return str(scope.get("component_id", ""))


# The Group a Group-scoped Guide belongs to; empty for Component scope.
static func scope_group_id(guide: Dictionary) -> String:
	var scope = guide.get("scope", {})
	if not scope is Dictionary:
		return ""
	return str(scope.get("group_id", ""))


# The id of whichever record the Guide is scoped to, Component or Group.
static func scope_target_id(guide: Dictionary) -> String:
	return scope_group_id(guide) if is_group_scoped(guide) else scope_component_id(guide)


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
	var raw_scope_kind := str(scope_source.get("kind", SCOPE_COMPONENT))
	if raw_scope_kind not in [SCOPE_COMPONENT, SCOPE_GROUP]:
		raw_scope_kind = SCOPE_COMPONENT
	var normalized_scope := {"kind": raw_scope_kind}
	if raw_scope_kind == SCOPE_GROUP:
		normalized_scope["group_id"] = str(scope_source.get("group_id", ""))
	else:
		normalized_scope["component_id"] = str(scope_source.get("component_id", source.get("component_id", "")))
	var normalized := {
		"id": str(source.get("id", "")),
		"type": "guide",
		"guide_type": guide_type,
		"name": str(source.get("name", display_name(guide_type))),
		"ordinal": maxi(0, int(source.get("ordinal", 0))),
		"visibility": bool(source.get("visibility", true)),
		"scope": normalized_scope,
		"transform": source.get("transform", {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "pivot": Vector2.ZERO}).duplicate(true),
		"points": topology["points"],
		"edges": topology["edges"],
		"chains": topology["chains"]
	}
	if is_weapon_frame(guide_type):
		normalized["transform"]["scale"] = Vector2.ONE
		normalized["transform"]["pivot"] = Vector2.ZERO
		return normalized
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
	if normalized_type == CUT:
		return "Cut"
	if normalized_type == WEAPON_SOCKET_PRIMARY:
		return "Weapon Socket Primary"
	if normalized_type == GRIP_PRIMARY:
		return "Grip Primary"
	if normalized_type == GRIP_SECONDARY:
		return "Grip Secondary"
	if normalized_type == ATTACK_POINT_PRIMARY:
		return "Attack Point Primary"
	if normalized_type == REACH_LIMIT_PRIMARY:
		return "Reach Limit Primary"
	return "Sample"


static func canonical_type(guide_type: String) -> String:
	match guide_type:
		FLOW, "body_flow":
			return FLOW
		MOTION, "animation_spine":
			return MOTION
		CUT:
			return CUT
		WEAPON_SOCKET_PRIMARY, GRIP_PRIMARY, GRIP_SECONDARY, ATTACK_POINT_PRIMARY, REACH_LIMIT_PRIMARY:
			return guide_type
		SAMPLE, "sampler_spine":
			return SAMPLE
	return SAMPLE


static func outliner_name(guide: Dictionary, component_name: String) -> String:
	return "%s → %s%02d" % [component_name, display_name(str(guide.get("guide_type", SAMPLE))), maxi(1, int(guide.get("ordinal", 1)))]


static func color(guide_type: String) -> Color:
	match canonical_type(guide_type):
		FLOW:
			return FLOW_COLOR
		MOTION:
			return MOTION_COLOR
		CUT:
			return Color("#ef6c78")
		WEAPON_SOCKET_PRIMARY, GRIP_PRIMARY, GRIP_SECONDARY, ATTACK_POINT_PRIMARY, REACH_LIMIT_PRIMARY:
			return Color("#f2994a")
	return SAMPLE_COLOR


static func is_weapon_frame(guide_type: String) -> bool:
	return canonical_type(guide_type) in WEAPON_TYPES


static func validation_issues(guide: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(guide.get("guide_type", "")) not in VALID_TYPES:
		errors.append("Unknown Guide type.")
	var scope_id := scope_target_id(guide)
	if scope_id.is_empty():
		errors.append("The Guide needs a target Component or Group.")
	if is_weapon_frame(str(guide.get("guide_type", ""))):
		var transform: Dictionary = guide.get("transform", {})
		var position := Vector2(transform.get("position", Vector2.INF))
		var rotation := float(transform.get("rotation", NAN))
		if not position.is_finite() or not is_finite(rotation):
			errors.append("A Weapon Guide transform must be finite.")
		if not guide.get("points", []).is_empty() or not guide.get("edges", []).is_empty() or not guide.get("chains", []).is_empty():
			errors.append("A Weapon Guide is a transform frame and cannot contain Bezier topology.")
		return errors
	var chains: Array = guide.get("chains", [])
	if chains.size() != 1 or bool(chains[0].get("closed", false)) or chains[0].get("point_ids", []).size() < 2:
		errors.append("A Spine must contain one open Chain with at least two Points.")
	errors.append_array(BezierTopology.validate(guide))
	return errors
