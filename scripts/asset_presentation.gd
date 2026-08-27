class_name AssetPresentation
extends RefCounted

enum AuthoredFacing {
	LEFT,
	RIGHT,
	NEUTRAL,
	TOP,
	DOWN,
}

const SERIALIZED_VALUES: Array[String] = ["left", "right", "neutral", "top", "down"]
const DISPLAY_NAMES: Array[String] = ["Left", "Right", "Neutral", "Top", "Down"]


static func deserialize_authored_facing(value) -> AuthoredFacing:
	var normalized := str(value).strip_edges().to_lower()
	var index := SERIALIZED_VALUES.find(normalized)
	return index as AuthoredFacing if index >= 0 else AuthoredFacing.NEUTRAL


static func serialize_authored_facing(value) -> String:
	var facing := normalize_authored_facing(value)
	return SERIALIZED_VALUES[int(facing)]


static func normalize_authored_facing(value) -> AuthoredFacing:
	if typeof(value) == TYPE_INT and int(value) >= 0 and int(value) < SERIALIZED_VALUES.size():
		return int(value) as AuthoredFacing
	return deserialize_authored_facing(value)


static func authored_facing(asset: Dictionary) -> AuthoredFacing:
	return normalize_authored_facing(asset.get("authored_facing", AuthoredFacing.NEUTRAL))


static func display_name(value) -> String:
	return DISPLAY_NAMES[int(normalize_authored_facing(value))]
