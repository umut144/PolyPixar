class_name MotionSelection
extends RefCounted

const NONE := "none"
const ASSET := "asset"
const STATE := "state"
const MOTION := "motion"
const TRANSITION := "transition"
const MARKER := "marker"

var kind := NONE
var asset_id := ""
var state_id := ""
var item_id := ""


func select_asset(value: String) -> void:
	kind = ASSET
	asset_id = value
	state_id = ""
	item_id = ""


func select_state(value_asset_id: String, value_state_id: String) -> void:
	kind = STATE
	asset_id = value_asset_id
	state_id = value_state_id
	item_id = ""


func select_item(value_kind: String, value_asset_id: String, value_state_id: String, value_item_id: String) -> void:
	if value_kind not in [MOTION, TRANSITION, MARKER]:
		clear()
		return
	kind = value_kind
	asset_id = value_asset_id
	state_id = value_state_id
	item_id = value_item_id


func clear() -> void:
	kind = NONE
	asset_id = ""
	state_id = ""
	item_id = ""


func matches(value_kind: String, value_state_id: String = "", value_item_id: String = "") -> bool:
	return kind == value_kind and state_id == value_state_id and item_id == value_item_id
