class_name ToolUnits
extends RefCounted

## Stored editor coordinates remain unchanged. One Tool unit represents 10 cm.
const TO_CENTIMETERS := 10.0
const TO_METERS := TO_CENTIMETERS / 100.0

static func to_centimeters(value: float) -> float:
	return value * TO_CENTIMETERS

static func from_centimeters(value: float) -> float:
	return value / TO_CENTIMETERS
