class_name MotionWorkspace
extends VBoxContainer

signal selection_changed
signal add_state_requested
signal authoring_error(message: String)
signal document_change_requested

const OUTER := "outer"
const INNER := "inner"
const BOB := "bob"
const SPINE_SWAY := "spine_sway"
const LEGACY_PATH_FOLLOW := "path_follow"
const TARGET_ASSET := "asset"
const TARGET_COMPONENT := "component"
const EXIT_ANY_PHASE := "any_phase"
const EXIT_AFTER_PHASE := "after_phase"
const EXIT_LOOP_END := "loop_end"
const ENTRY_RESTART := "restart"
const ENTRY_PRESERVE_PHASE := "preserve_phase"
const MARKER_EVENT := "event"
const MARKER_SFX := "sfx"
const MARKER_VFX := "vfx"
const PARAM_NUMBER := "number"
const PARAM_BOOL := "bool"
const OP_EQUAL := "equal"
const OP_NOT_EQUAL := "not_equal"
const OP_GREATER := "greater"
const OP_GREATER_EQUAL := "greater_equal"
const OP_LESS := "less"
const OP_LESS_EQUAL := "less_equal"
const OP_IS_TRUE := "is_true"
const OP_IS_FALSE := "is_false"

const DEFAULT_STATE_PREVIEWS := [
	{
		"id": "state_idle",
		"name": "IDLE",
		"cycle_duration": 1.0,
		"next_motion_index": 2,
		"next_transition_index": 2,
		"next_marker_index": 2,
		"motions": [
			{"id": "motion_idle_01", "name": "Idle Bob", "enabled": true, "domain": "outer", "primitive": "bob", "target_scope": "asset", "target_component_id": "", "guide_ids": [], "phase_offset": 0.0, "parameters": {"distance": 0.25, "cycles": 1.0}}
		],
		"transitions": [
			{"id": "transition_idle_01", "target_state_id": "state_walk", "exit_policy": "any_phase", "exit_phase": 0.0, "entry_mode": "restart", "blend_duration": 0.15, "next_rule_index": 2, "rules": [{"id": "rule_idle_01", "parameter_id": "parameter_speed", "operator": "greater", "value": 0.1}]}
		],
		"markers": [
			{"id": "marker_idle_01", "event_id": "rustle", "kind": "sfx", "phase": 0.52}
		]
	},
	{
		"id": "state_walk",
		"name": "WALK",
		"cycle_duration": 1.0,
		"next_motion_index": 2,
		"next_transition_index": 3,
		"next_marker_index": 2,
		"motions": [
			{"id": "motion_walk_01", "name": "Walk Bob", "enabled": true, "domain": "outer", "primitive": "bob", "target_scope": "asset", "target_component_id": "", "guide_ids": [], "phase_offset": 0.0, "parameters": {"distance": 0.5, "cycles": 1.0}}
		],
		"transitions": [
			{"id": "transition_walk_01", "target_state_id": "state_idle", "exit_policy": "any_phase", "exit_phase": 0.0, "entry_mode": "restart", "blend_duration": 0.15, "next_rule_index": 2, "rules": [{"id": "rule_walk_idle_01", "parameter_id": "parameter_speed", "operator": "less_equal", "value": 0.1}]},
			{"id": "transition_walk_02", "target_state_id": "state_run", "exit_policy": "any_phase", "exit_phase": 0.0, "entry_mode": "preserve_phase", "blend_duration": 0.15, "next_rule_index": 2, "rules": [{"id": "rule_walk_run_01", "parameter_id": "parameter_speed", "operator": "greater", "value": 0.65}]}
		],
		"markers": [
			{"id": "marker_walk_01", "event_id": "footstep", "kind": "sfx", "phase": 0.25}
		]
	},
	{
		"id": "state_run",
		"name": "RUN",
		"cycle_duration": 1.0,
		"next_motion_index": 3,
		"next_transition_index": 2,
		"next_marker_index": 2,
		"motions": [
			{"id": "motion_run_01", "name": "Run Bob", "enabled": true, "domain": "outer", "primitive": "bob", "target_scope": "asset", "target_component_id": "", "guide_ids": [], "phase_offset": 0.0, "parameters": {"distance": 0.8, "cycles": 1.0}},
			{"id": "motion_run_02", "name": "Run Sway", "enabled": true, "domain": "inner", "primitive": "spine_sway", "target_scope": "component", "target_component_id": "", "guide_ids": [], "phase_offset": 0.0, "parameters": {"strength": 0.5, "cycles": 1.0}}
		],
		"transitions": [
			{"id": "transition_run_01", "target_state_id": "state_walk", "exit_policy": "any_phase", "exit_phase": 0.0, "entry_mode": "preserve_phase", "blend_duration": 0.15, "next_rule_index": 2, "rules": [{"id": "rule_run_01", "parameter_id": "parameter_speed", "operator": "less_equal", "value": 0.65}]}
		],
		"markers": [
			{"id": "marker_run_01", "event_id": "footstep", "kind": "sfx", "phase": 0.18}
		]
	}
]

var selection: MotionSelection
var asset_id := ""
var asset_name := ""
var phase := 0.0
var board: HBoxContainer
var heading: Label
var preview_documents: Dictionary = {}
var asset_components: Array = []
var retired_children_owner: Node


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_rebuild()


func set_selection_model(value: MotionSelection) -> void:
	selection = value
	_rebuild()


func set_asset(value_id: String, value_name: String, components: Array = [], animation_document: Dictionary = {}) -> void:
	asset_id = value_id
	asset_name = value_name
	asset_components = components.duplicate(true)
	if not asset_id.is_empty():
		if animation_document.is_empty():
			_ensure_preview_document(asset_id)
		else:
			preview_documents[asset_id] = normalize_animation_document(animation_document)
	if selection != null and selection.asset_id != asset_id:
		if not asset_id.is_empty():
			selection.select_asset(asset_id)
		else:
			selection.clear()
	elif selection != null and selection.kind != MotionSelection.ASSET and get_selected_preview().is_empty():
		if not asset_id.is_empty():
			selection.select_asset(asset_id)
		else:
			selection.clear()
	_rebuild()


func set_phase(value: float) -> void:
	phase = clampf(value, 0.0, 1.0)
	if is_instance_valid(heading):
		heading.text = _heading_text()


func get_selected_preview() -> Dictionary:
	if selection == null or selection.asset_id != asset_id:
		return {}
	for state in get_states_for_asset(asset_id):
		if str(state["id"]) != selection.state_id:
			continue
		if selection.kind == MotionSelection.STATE:
			return {"kind": selection.kind, "state": state}
		for collection_name in ["motions", "transitions", "markers"]:
			for item in state[collection_name]:
				if str(item["id"]) == selection.item_id:
					return {"kind": selection.kind, "state": state, "item": item}
	return {}


func get_states_for_asset(value_asset_id: String) -> Array:
	if value_asset_id.is_empty():
		return []
	_ensure_preview_document(value_asset_id)
	return preview_documents[value_asset_id]["states"]


func get_animation_document() -> Dictionary:
	return _active_document()


static func create_default_animation_document() -> Dictionary:
	return {
		"next_state_index": 4,
		"simulation_contract": {
			"source": "Asset Animation",
			"next_parameter_index": 1,
			"parameters": [
				{"id": "parameter_speed", "name": "speed", "type": PARAM_NUMBER},
				{"id": "parameter_grounded", "name": "grounded", "type": PARAM_BOOL}
			]
		},
		"states": DEFAULT_STATE_PREVIEWS.duplicate(true)
	}


static func normalize_animation_document(raw_document) -> Dictionary:
	if not raw_document is Dictionary or raw_document.is_empty():
		return create_default_animation_document()
	var document: Dictionary = raw_document
	if not document.get("states", []) is Array:
		document["states"] = []
	document["next_state_index"] = maxi(1, int(document.get("next_state_index", document["states"].size() + 1)))
	var contract = document.get("simulation_contract", {})
	if not contract is Dictionary:
		contract = {}
	contract["source"] = str(contract.get("source", "Persisted Asset"))
	var contract_parameters = contract.get("parameters", [])
	if not contract_parameters is Array:
		contract_parameters = []
	contract["parameters"] = contract_parameters
	contract["next_parameter_index"] = maxi(1, int(contract.get("next_parameter_index", contract["parameters"].size() + 1)))
	document["simulation_contract"] = contract
	var legacy_archive = document.get("legacy_path_follow_motions", [])
	if not legacy_archive is Array:
		legacy_archive = []
	document["legacy_path_follow_motions"] = legacy_archive
	for state in document["states"]:
		if not state is Dictionary:
			continue
		state["cycle_duration"] = maxf(0.01, float(state.get("cycle_duration", 1.0)))
		for collection_name in ["motions", "transitions", "markers"]:
			var collection = state.get(collection_name, [])
			if not collection is Array:
				collection = []
			state[collection_name] = collection
		state["next_motion_index"] = maxi(1, int(state.get("next_motion_index", state["motions"].size() + 1)))
		state["next_transition_index"] = maxi(1, int(state.get("next_transition_index", state["transitions"].size() + 1)))
		state["next_marker_index"] = maxi(1, int(state.get("next_marker_index", state["markers"].size() + 1)))
		var retained_motions: Array = []
		for motion in state["motions"]:
			if not motion is Dictionary:
				continue
			if str(motion.get("primitive", "")) == LEGACY_PATH_FOLLOW:
				var already_archived := false
				for archived in legacy_archive:
					if str(archived.get("state_id", "")) == str(state.get("id", "")) and str(archived.get("motion", {}).get("id", "")) == str(motion.get("id", "")):
						already_archived = true
						break
				if not already_archived:
					legacy_archive.append({"state_id": str(state.get("id", "")), "motion": motion.duplicate(true), "status": "moved_to_motion_path"})
				continue
			var inferred_scope := TARGET_COMPONENT if str(motion.get("domain", OUTER)) == INNER or not str(motion.get("target_component_id", "")).is_empty() else TARGET_ASSET
			motion["target_scope"] = str(motion.get("target_scope", inferred_scope))
			retained_motions.append(motion)
		state["motions"] = retained_motions
		for transition in state["transitions"]:
			if not transition is Dictionary:
				continue
			var transition_rules = transition.get("rules", [])
			if not transition_rules is Array:
				transition_rules = []
			transition["rules"] = transition_rules
			transition["next_rule_index"] = maxi(1, int(transition.get("next_rule_index", transition["rules"].size() + 1)))
	return document


func next_default_state_name() -> String:
	var document := _active_document()
	if document.is_empty():
		return "STATE 01"
	var candidate_index := maxi(1, int(document.get("next_state_index", 1)))
	var candidate := "STATE %02d" % candidate_index
	while _has_state_name(document["states"], candidate):
		candidate_index += 1
		candidate = "STATE %02d" % candidate_index
	return candidate


func add_state(proposed_state_name: String) -> String:
	var document := _active_document()
	var normalized_name := proposed_state_name.strip_edges()
	if document.is_empty():
		return "Select an Asset before adding a State."
	if normalized_name.is_empty():
		normalized_name = next_default_state_name()
	if _has_state_name(document["states"], normalized_name):
		return "State names must be unique within this Animation."
	document_change_requested.emit()
	var next_index := maxi(1, int(document.get("next_state_index", 1)))
	var state_id := "state_%02d" % next_index
	document["next_state_index"] = next_index + 1
	document["states"].append({
		"id": state_id,
		"name": normalized_name,
		"cycle_duration": 1.0,
		"next_motion_index": 1,
		"next_transition_index": 1,
		"next_marker_index": 1,
		"motions": [],
		"transitions": [],
		"markers": []
	})
	selection.select_state(asset_id, state_id)
	_rebuild()
	selection_changed.emit()
	return ""


func rename_state(state_id: String, proposed_state_name: String) -> String:
	var states := get_states_for_asset(asset_id)
	var state := _find_state(states, state_id)
	var normalized_name := proposed_state_name.strip_edges()
	if state.is_empty():
		return "The selected State no longer exists."
	if normalized_name.is_empty():
		return "State name cannot be empty."
	if normalized_name == str(state.get("name", "")):
		return ""
	if _has_state_name(states, normalized_name, state_id):
		return "State names must be unique within this Animation."
	document_change_requested.emit()
	state["name"] = normalized_name
	_rebuild()
	selection_changed.emit()
	return ""


func set_state_cycle_duration(state_id: String, value: float) -> bool:
	var state := _find_state(get_states_for_asset(asset_id), state_id)
	if state.is_empty():
		return false
	document_change_requested.emit()
	state["cycle_duration"] = maxf(0.01, value)
	return true


func remove_state(state_id: String) -> bool:
	var document := _active_document()
	if document.is_empty():
		return false
	var states: Array = document["states"]
	var state_index := -1
	for index in range(states.size()):
		if str(states[index].get("id", "")) == state_id:
			state_index = index
			break
	if state_index < 0:
		return false
	document_change_requested.emit()
	states.remove_at(state_index)
	if states.is_empty():
		selection.select_asset(asset_id)
	else:
		var fallback_index := mini(state_index, states.size() - 1)
		selection.select_state(asset_id, str(states[fallback_index].get("id", "")))
	_rebuild()
	selection_changed.emit()
	return true


func state_name(state_id: String) -> String:
	return str(_find_state(get_states_for_asset(asset_id), state_id).get("name", "State"))


func add_motion(state_id: String) -> String:
	var state := _find_state(get_states_for_asset(asset_id), state_id)
	if state.is_empty():
		return "Select a State before adding a Motion."
	document_change_requested.emit()
	var motion_index := maxi(1, int(state.get("next_motion_index", 1)))
	var motion_id := "motion_%s_%02d" % [state_id.trim_prefix("state_"), motion_index]
	state["next_motion_index"] = motion_index + 1
	state["motions"].append({
		"id": motion_id,
		"name": "Motion %02d" % motion_index,
		"enabled": true,
		"domain": OUTER,
		"primitive": BOB,
		"target_scope": TARGET_ASSET,
		"target_component_id": "",
		"guide_ids": [],
		"phase_offset": 0.0,
		"parameters": {"distance": 0.25, "cycles": 1.0}
	})
	selection.select_item(MotionSelection.MOTION, asset_id, state_id, motion_id)
	_rebuild()
	selection_changed.emit()
	return ""


func remove_motion(state_id: String, motion_id: String) -> bool:
	var state := _find_state(get_states_for_asset(asset_id), state_id)
	if state.is_empty():
		return false
	var motions: Array = state["motions"]
	for index in range(motions.size()):
		if str(motions[index].get("id", "")) == motion_id:
			document_change_requested.emit()
			motions.remove_at(index)
			selection.select_state(asset_id, state_id)
			_rebuild()
			selection_changed.emit()
			return true
	return false


func rename_motion(state_id: String, motion_id: String, motion_name: String) -> String:
	var motion := find_motion(state_id, motion_id)
	var normalized_name := motion_name.strip_edges()
	if motion.is_empty():
		return "The selected Motion no longer exists."
	if normalized_name.is_empty():
		return "Motion name cannot be empty."
	if normalized_name == str(motion.get("name", "")):
		return ""
	document_change_requested.emit()
	motion["name"] = normalized_name
	_rebuild()
	selection_changed.emit()
	return ""


func find_motion(state_id: String, motion_id: String) -> Dictionary:
	var state := _find_state(get_states_for_asset(asset_id), state_id)
	for motion in state.get("motions", []):
		if str(motion.get("id", "")) == motion_id:
			return motion
	return {}


func set_motion_property(state_id: String, motion_id: String, property_name: String, value, rebuild_board := true) -> bool:
	var motion := find_motion(state_id, motion_id)
	if motion.is_empty():
		return false
	document_change_requested.emit()
	motion[property_name] = value
	if property_name == "domain":
		var available := primitive_options(str(value))
		if str(motion.get("primitive", "")) not in available:
			motion["primitive"] = available[0]
			motion["parameters"] = default_parameters(str(available[0]))
		motion["guide_ids"] = []
		motion["target_scope"] = TARGET_COMPONENT if str(value) == INNER else TARGET_ASSET
		motion["target_component_id"] = ""
	if property_name == "primitive":
		motion["parameters"] = default_parameters(str(value))
		motion["guide_ids"] = []
	if rebuild_board:
		_rebuild()
		selection_changed.emit()
	return true


func set_motion_target(state_id: String, motion_id: String, target_scope: String, component_id: String) -> bool:
	var motion := find_motion(state_id, motion_id)
	if motion.is_empty():
		return false
	var domain := str(motion.get("domain", OUTER))
	var normalized_scope := TARGET_COMPONENT if domain == INNER else (TARGET_ASSET if target_scope == TARGET_ASSET else TARGET_COMPONENT)
	document_change_requested.emit()
	motion["target_scope"] = normalized_scope
	motion["target_component_id"] = component_id if normalized_scope == TARGET_COMPONENT else ""
	_rebuild()
	selection_changed.emit()
	return true


func set_motion_parameter(state_id: String, motion_id: String, parameter_name: String, value) -> bool:
	var motion := find_motion(state_id, motion_id)
	if motion.is_empty():
		return false
	document_change_requested.emit()
	var parameters: Dictionary = motion.get("parameters", {})
	parameters[parameter_name] = value
	motion["parameters"] = parameters
	return true


func primitive_options(domain: String) -> Array[String]:
	var options: Array[String] = []
	if domain == INNER:
		options.append(SPINE_SWAY)
	else:
		options.append(BOB)
	return options


func primitive_label(primitive: String) -> String:
	match primitive:
		BOB: return "Bob"
		SPINE_SWAY: return "Spine Sway"
		LEGACY_PATH_FOLLOW: return "Moved to Motion → Path"
		_: return primitive.capitalize()


func default_parameters(primitive: String) -> Dictionary:
	match primitive:
		SPINE_SWAY: return {"strength": 0.5, "cycles": 1.0}
		_: return {"distance": 0.25, "cycles": 1.0}


func add_transition(state_id: String) -> String:
	var state := _find_state(get_states_for_asset(asset_id), state_id)
	if state.is_empty():
		return "Select a State before adding a Transition."
	var target_state_id := ""
	for candidate in get_states_for_asset(asset_id):
		if str(candidate.get("id", "")) != state_id:
			target_state_id = str(candidate.get("id", ""))
			break
	if target_state_id.is_empty():
		return "Add another State before creating a Transition."
	document_change_requested.emit()
	var next_transition_number := maxi(1, int(state.get("next_transition_index", 1)))
	var transition_id := "transition_%s_%02d" % [state_id.trim_prefix("state_"), next_transition_number]
	state["next_transition_index"] = next_transition_number + 1
	state["transitions"].append({
		"id": transition_id,
		"target_state_id": target_state_id,
		"exit_policy": EXIT_ANY_PHASE,
		"exit_phase": 0.0,
		"entry_mode": ENTRY_RESTART,
		"blend_duration": 0.15,
		"next_rule_index": 1,
		"rules": []
	})
	selection.select_item(MotionSelection.TRANSITION, asset_id, state_id, transition_id)
	_rebuild()
	selection_changed.emit()
	return ""


func find_transition(state_id: String, transition_id: String) -> Dictionary:
	var state := _find_state(get_states_for_asset(asset_id), state_id)
	for transition in state.get("transitions", []):
		if str(transition.get("id", "")) == transition_id:
			return transition
	return {}


func set_transition_property(state_id: String, transition_id: String, property_name: String, value, rebuild_board := true) -> bool:
	var transition := find_transition(state_id, transition_id)
	if transition.is_empty():
		return false
	document_change_requested.emit()
	transition[property_name] = value
	if rebuild_board:
		_rebuild()
		selection_changed.emit()
	return true


func get_contract_parameters() -> Array:
	var document := _active_document()
	if document.is_empty():
		return []
	return document.get("simulation_contract", {}).get("parameters", [])


func find_contract_parameter(parameter_id: String) -> Dictionary:
	for parameter in get_contract_parameters():
		if str(parameter.get("id", "")) == parameter_id:
			return parameter
	return {}


func add_contract_parameter() -> String:
	var document := _active_document()
	if document.is_empty():
		return "Select an Asset before adding a Simulation parameter."
	document_change_requested.emit()
	var contract: Dictionary = document["simulation_contract"]
	var parameter_index := maxi(1, int(contract.get("next_parameter_index", 1)))
	contract["next_parameter_index"] = parameter_index + 1
	contract["parameters"].append({"id": "parameter_%02d" % parameter_index, "name": "parameter_%02d" % parameter_index, "type": PARAM_NUMBER})
	selection.select_asset(asset_id)
	selection_changed.emit()
	return ""


func set_contract_parameter_property(parameter_id: String, property_name: String, value) -> String:
	var parameter := find_contract_parameter(parameter_id)
	if parameter.is_empty():
		return "The Simulation parameter no longer exists."
	if property_name == "name":
		var normalized_name := str(value).strip_edges()
		if normalized_name.is_empty():
			return "Simulation parameter name cannot be empty."
		for candidate in get_contract_parameters():
			if str(candidate.get("id", "")) != parameter_id and str(candidate.get("name", "")).to_lower() == normalized_name.to_lower():
				return "Simulation parameter names must be unique."
		document_change_requested.emit()
		parameter["name"] = normalized_name
	else:
		document_change_requested.emit()
		parameter[property_name] = value
		if property_name == "type":
			_normalize_rules_for_parameter(parameter_id)
	selection_changed.emit()
	return ""


func remove_contract_parameter(parameter_id: String) -> String:
	for state in get_states_for_asset(asset_id):
		for transition in state.get("transitions", []):
			for rule in transition.get("rules", []):
				if str(rule.get("parameter_id", "")) == parameter_id:
					return "Remove Transition Rules that reference this parameter first."
	var parameters := get_contract_parameters()
	for index in range(parameters.size()):
		if str(parameters[index].get("id", "")) == parameter_id:
			document_change_requested.emit()
			parameters.remove_at(index)
			selection_changed.emit()
			return ""
	return "The Simulation parameter no longer exists."


func parameter_type_label(parameter_type: String) -> String:
	return "Bool" if parameter_type == PARAM_BOOL else "Number"


func rule_operators(parameter_type: String) -> Array[String]:
	if parameter_type == PARAM_BOOL:
		return [OP_IS_TRUE, OP_IS_FALSE]
	return [OP_EQUAL, OP_NOT_EQUAL, OP_GREATER, OP_GREATER_EQUAL, OP_LESS, OP_LESS_EQUAL]


func rule_operator_label(operator: String) -> String:
	match operator:
		OP_NOT_EQUAL: return "≠"
		OP_GREATER: return ">"
		OP_GREATER_EQUAL: return "≥"
		OP_LESS: return "<"
		OP_LESS_EQUAL: return "≤"
		OP_IS_TRUE: return "is true"
		OP_IS_FALSE: return "is false"
		_: return "="


func add_transition_rule(state_id: String, transition_id: String) -> String:
	var transition := find_transition(state_id, transition_id)
	if transition.is_empty():
		return "The selected Transition no longer exists."
	var parameters := get_contract_parameters()
	if parameters.is_empty():
		return "Add a Simulation Contract parameter before adding a Rule."
	document_change_requested.emit()
	var rule_index := maxi(1, int(transition.get("next_rule_index", 1)))
	transition["next_rule_index"] = rule_index + 1
	var parameter: Dictionary = parameters[0]
	var operators := rule_operators(str(parameter.get("type", PARAM_NUMBER)))
	transition["rules"].append({
		"id": "rule_%s_%02d" % [transition_id.trim_prefix("transition_"), rule_index],
		"parameter_id": str(parameter.get("id", "")),
		"operator": operators[0],
		"value": 0.0
	})
	selection_changed.emit()
	return ""


func set_transition_rule_property(state_id: String, transition_id: String, rule_id: String, property_name: String, value, rebuild_inspector := true) -> bool:
	var rule := find_transition_rule(state_id, transition_id, rule_id)
	if rule.is_empty():
		return false
	document_change_requested.emit()
	rule[property_name] = value
	if property_name == "parameter_id":
		var parameter := find_contract_parameter(str(value))
		var operators := rule_operators(str(parameter.get("type", PARAM_NUMBER)))
		rule["operator"] = operators[0]
		rule["value"] = 0.0
	if rebuild_inspector:
		selection_changed.emit()
	return true


func find_transition_rule(state_id: String, transition_id: String, rule_id: String) -> Dictionary:
	var transition := find_transition(state_id, transition_id)
	for rule in transition.get("rules", []):
		if str(rule.get("id", "")) == rule_id:
			return rule
	return {}


func remove_transition_rule(state_id: String, transition_id: String, rule_id: String) -> bool:
	var transition := find_transition(state_id, transition_id)
	var rules: Array = transition.get("rules", [])
	for index in range(rules.size()):
		if str(rules[index].get("id", "")) == rule_id:
			document_change_requested.emit()
			rules.remove_at(index)
			selection_changed.emit()
			return true
	return false


func transition_rules_valid(transition: Dictionary) -> bool:
	for rule in transition.get("rules", []):
		var parameter := find_contract_parameter(str(rule.get("parameter_id", "")))
		if parameter.is_empty() or str(rule.get("operator", "")) not in rule_operators(str(parameter.get("type", PARAM_NUMBER))):
			return false
	return true


func validation_issues() -> Array[String]:
	var issues: Array[String] = []
	var state_ids: Array[String] = []
	var state_names: Array[String] = []
	var parameter_ids: Array[String] = []
	var parameter_names: Array[String] = []
	var component_ids: Array[String] = []
	for component in asset_components:
		component_ids.append(str(component.get("id", "")))
	for parameter in get_contract_parameters():
		var parameter_id := str(parameter.get("id", ""))
		var parameter_name := str(parameter.get("name", "")).to_lower()
		if parameter_id.is_empty() or parameter_id in parameter_ids:
			issues.append("Simulation Contract contains a missing or duplicate parameter ID.")
		elif parameter_name.is_empty() or parameter_name in parameter_names:
			issues.append("Simulation Contract contains a missing or duplicate parameter name.")
		elif str(parameter.get("type", "")) not in [PARAM_NUMBER, PARAM_BOOL]:
			issues.append("Parameter '%s' has an unsupported type." % parameter.get("name", parameter_id))
		parameter_ids.append(parameter_id)
		parameter_names.append(parameter_name)
	for state in get_states_for_asset(asset_id):
		var state_id := str(state.get("id", ""))
		var state_name_value := str(state.get("name", ""))
		var normalized_state_name := state_name_value.to_lower()
		if state_id.is_empty() or state_id in state_ids:
			issues.append("Animation contains a missing or duplicate State ID.")
		if normalized_state_name.is_empty() or normalized_state_name in state_names:
			issues.append("Animation contains a missing or duplicate State name.")
		state_ids.append(state_id)
		state_names.append(normalized_state_name)
	for state in get_states_for_asset(asset_id):
		var state_label := str(state.get("name", "State"))
		for motion in state.get("motions", []):
			var target_scope := str(motion.get("target_scope", TARGET_COMPONENT))
			var target_component_id := str(motion.get("target_component_id", ""))
			if str(motion.get("domain", OUTER)) == OUTER and target_scope == TARGET_ASSET:
				pass
			elif target_component_id.is_empty():
				issues.append("%s / %s needs a target Component." % [state_label, motion.get("name", "Motion")])
			elif target_component_id not in component_ids:
				issues.append("%s / %s references a missing Component." % [state_label, motion.get("name", "Motion")])
		for transition in state.get("transitions", []):
			if str(transition.get("target_state_id", "")) not in state_ids:
				issues.append("%s contains a Transition to a missing State." % state_label)
			if not transition_rules_valid(transition):
				issues.append("%s contains an invalid typed Transition Rule." % state_label)
		for marker in state.get("markers", []):
			var marker_phase := float(marker.get("phase", -1.0))
			if marker_phase < 0.0 or marker_phase > 1.0:
				issues.append("%s contains a Marker outside normalized phase." % state_label)
	return issues


func _normalize_rules_for_parameter(parameter_id: String) -> void:
	var parameter := find_contract_parameter(parameter_id)
	var operators := rule_operators(str(parameter.get("type", PARAM_NUMBER)))
	for state in get_states_for_asset(asset_id):
		for transition in state.get("transitions", []):
			for rule in transition.get("rules", []):
				if str(rule.get("parameter_id", "")) == parameter_id:
					rule["operator"] = operators[0]
					rule["value"] = 0.0


func transition_index(state_id: String, transition_id: String) -> int:
	var state := _find_state(get_states_for_asset(asset_id), state_id)
	for index in range(state.get("transitions", []).size()):
		if str(state["transitions"][index].get("id", "")) == transition_id:
			return index
	return -1


func move_transition(state_id: String, transition_id: String, direction: int) -> bool:
	var state := _find_state(get_states_for_asset(asset_id), state_id)
	var transitions: Array = state.get("transitions", [])
	var source_index := transition_index(state_id, transition_id)
	var target_index := source_index + signi(direction)
	if source_index < 0 or target_index < 0 or target_index >= transitions.size():
		return false
	document_change_requested.emit()
	var moved_transition = transitions[source_index]
	transitions.remove_at(source_index)
	transitions.insert(target_index, moved_transition)
	state["transitions"] = transitions
	_rebuild()
	selection_changed.emit()
	return true


func remove_transition(state_id: String, transition_id: String) -> bool:
	var state := _find_state(get_states_for_asset(asset_id), state_id)
	var index := transition_index(state_id, transition_id)
	if state.is_empty() or index < 0:
		return false
	document_change_requested.emit()
	state["transitions"].remove_at(index)
	selection.select_state(asset_id, state_id)
	_rebuild()
	selection_changed.emit()
	return true


func add_marker(state_id: String) -> String:
	var state := _find_state(get_states_for_asset(asset_id), state_id)
	if state.is_empty():
		return "Select a State before adding a Marker."
	document_change_requested.emit()
	var marker_index := maxi(1, int(state.get("next_marker_index", 1)))
	var marker_id := "marker_%s_%02d" % [state_id.trim_prefix("state_"), marker_index]
	state["next_marker_index"] = marker_index + 1
	state["markers"].append({
		"id": marker_id,
		"event_id": "event_%02d" % marker_index,
		"kind": MARKER_EVENT,
		"phase": 0.5
	})
	selection.select_item(MotionSelection.MARKER, asset_id, state_id, marker_id)
	_rebuild()
	selection_changed.emit()
	return ""


func find_marker(state_id: String, marker_id: String) -> Dictionary:
	var state := _find_state(get_states_for_asset(asset_id), state_id)
	for marker in state.get("markers", []):
		if str(marker.get("id", "")) == marker_id:
			return marker
	return {}


func set_marker_property(state_id: String, marker_id: String, property_name: String, value, rebuild_board := true) -> String:
	var marker := find_marker(state_id, marker_id)
	if marker.is_empty():
		return "The selected Marker no longer exists."
	if property_name == "event_id" and str(value).strip_edges().is_empty():
		return "Marker Event ID cannot be empty."
	document_change_requested.emit()
	marker[property_name] = str(value).strip_edges() if property_name == "event_id" else value
	if rebuild_board:
		_rebuild()
		selection_changed.emit()
	return ""


func refresh_board() -> void:
	_rebuild()


func remove_marker(state_id: String, marker_id: String) -> bool:
	var state := _find_state(get_states_for_asset(asset_id), state_id)
	if state.is_empty():
		return false
	var markers: Array = state["markers"]
	for index in range(markers.size()):
		if str(markers[index].get("id", "")) == marker_id:
			document_change_requested.emit()
			markers.remove_at(index)
			selection.select_state(asset_id, state_id)
			_rebuild()
			selection_changed.emit()
			return true
	return false


func selected_marker_phases() -> Array:
	if selection == null or selection.state_id.is_empty():
		return []
	return marker_phases_for_state(selection.state_id)


func marker_phases_for_state(state_id: String) -> Array:
	var state := _find_state(get_states_for_asset(asset_id), state_id)
	var phases: Array = []
	for marker in state.get("markers", []):
		phases.append(float(marker.get("phase", 0.0)))
	return phases


func exit_policy_label(policy: String) -> String:
	match policy:
		EXIT_AFTER_PHASE: return "After Phase"
		EXIT_LOOP_END: return "At Loop End"
		_: return "Any Phase"


func entry_mode_label(mode: String) -> String:
	return "Preserve Phase" if mode == ENTRY_PRESERVE_PHASE else "Restart"


func marker_kind_label(kind: String) -> String:
	match kind:
		MARKER_SFX: return "SFX"
		MARKER_VFX: return "VFX"
		_: return "Event"


func item_display_name(kind: String, item: Dictionary) -> String:
	if kind == MotionSelection.MARKER:
		return str(item.get("event_id", "Marker"))
	if kind != MotionSelection.TRANSITION:
		return str(item.get("name", kind.capitalize()))
	var target_state := _find_state(get_states_for_asset(asset_id), str(item.get("target_state_id", "")))
	return "→ %s" % str(target_state.get("name", "Missing State"))


func item_summary(kind: String, item: Dictionary) -> String:
	if kind == MotionSelection.MOTION:
		return _motion_summary(item)
	if kind == MotionSelection.TRANSITION:
		if _find_state(get_states_for_asset(asset_id), str(item.get("target_state_id", ""))).is_empty():
			return "Missing target · Preview invalid"
		var owning_state := _state_for_item("transitions", str(item.get("id", "")))
		var priority := transition_index(str(owning_state.get("id", "")), str(item.get("id", ""))) + 1
		return "#%d · %s · %s · %d Rules" % [priority, exit_policy_label(str(item.get("exit_policy", EXIT_ANY_PHASE))), entry_mode_label(str(item.get("entry_mode", ENTRY_RESTART))), item.get("rules", []).size()]
	if kind == MotionSelection.MARKER:
		return "%s · Phase %.2f" % [marker_kind_label(str(item.get("kind", MARKER_EVENT))), float(item.get("phase", 0.0))]
	return str(item.get("summary", ""))


func _state_for_item(collection_name: String, item_id: String) -> Dictionary:
	for state in get_states_for_asset(asset_id):
		for item in state.get(collection_name, []):
			if str(item.get("id", "")) == item_id:
				return state
	return {}


func _motion_summary(motion: Dictionary) -> String:
	var domain_label := "Inner" if str(motion.get("domain", OUTER)) == INNER else "Outer"
	var target_id := str(motion.get("target_component_id", ""))
	var target_label := "Entire Asset" if str(motion.get("target_scope", TARGET_COMPONENT)) == TARGET_ASSET else "Select Component"
	for component in asset_components:
		if str(component.get("id", "")) == target_id:
			target_label = str(component.get("name", "Component"))
			break
	var guide_required := str(motion.get("domain", OUTER)) == INNER
	var disabled_label := "Disabled · " if not bool(motion.get("enabled", true)) else ""
	return "%s%s · %s%s" % [disabled_label, domain_label, target_label, " · Guide required" if guide_required else ""]


func _ensure_preview_document(value_asset_id: String) -> void:
	if preview_documents.has(value_asset_id):
		return
	preview_documents[value_asset_id] = create_default_animation_document()


func _active_document() -> Dictionary:
	if asset_id.is_empty():
		return {}
	_ensure_preview_document(asset_id)
	return preview_documents[asset_id]


func _find_state(states: Array, state_id: String) -> Dictionary:
	for state in states:
		if str(state.get("id", "")) == state_id:
			return state
	return {}


func _has_state_name(states: Array, candidate_state_name: String, excluded_state_id: String = "") -> bool:
	var normalized_name := candidate_state_name.to_lower()
	for state in states:
		if str(state.get("id", "")) != excluded_state_id and str(state.get("name", "")).to_lower() == normalized_name:
			return true
	return false


func _rebuild() -> void:
	if not is_instance_valid(retired_children_owner):
		retired_children_owner = Node.new()
		retired_children_owner.name = "RetiredChildren"
		add_child(retired_children_owner)
	for child in get_children():
		if child == retired_children_owner:
			continue
		remove_child(child)
		if child is CanvasItem:
			child.hide()
		retired_children_owner.add_child(child)
		child.queue_free()
	heading = Label.new()
	heading.text = _heading_text()
	heading.custom_minimum_size = Vector2(0, 28)
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color("#c0c8d5"))
	add_child(heading)
	if asset_id.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Select an Asset to preview its Animation workspace."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty_label.add_theme_color_override("font_color", Color("#737f91"))
		add_child(empty_label)
		return
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	board = HBoxContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_theme_constant_override("separation", 8)
	scroll.add_child(board)
	for state in get_states_for_asset(asset_id):
		board.add_child(_create_state_column(state))
	board.add_child(_create_add_state_slot())


func _heading_text() -> String:
	if asset_name.is_empty():
		return "Animation"
	return "%s · Animation Preview · Phase %.2f" % [asset_name, phase]


func _create_state_column(state: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var selected := selection != null and selection.state_id == str(state["id"])
	panel.add_theme_stylebox_override("panel", _panel_style(selected))
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	panel.add_child(layout)
	var header := Button.new()
	header.text = str(state["name"])
	header.custom_minimum_size = Vector2(0, 36)
	header.focus_mode = Control.FOCUS_NONE
	header.pressed.connect(_select_state.bind(str(state["id"])))
	layout.add_child(header)
	_add_section(layout, "Motion", MotionSelection.MOTION, state, "motions")
	_add_section(layout, "Transitions", MotionSelection.TRANSITION, state, "transitions")
	_add_section(layout, "Markers", MotionSelection.MARKER, state, "markers")
	return panel


func _create_add_state_slot() -> CenterContainer:
	var slot := CenterContainer.new()
	slot.custom_minimum_size = Vector2(180, 0)
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var button := Button.new()
	button.text = "Add State"
	button.custom_minimum_size = Vector2(120, 38)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: add_state_requested.emit())
	slot.add_child(button)
	return slot


func _add_section(parent: VBoxContainer, title: String, kind: String, state: Dictionary, collection_name: String) -> void:
	var title_row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#7f8a9b"))
	title_row.add_child(label)
	var future_add := Button.new()
	future_add.text = "+"
	var can_add := kind in [MotionSelection.MOTION, MotionSelection.TRANSITION, MotionSelection.MARKER]
	future_add.disabled = not can_add
	future_add.tooltip_text = "Add %s" % title.trim_suffix("s") if can_add else "Authoring follows in a later Motion phase."
	future_add.custom_minimum_size = Vector2(28, 24)
	if kind == MotionSelection.MOTION:
		future_add.pressed.connect(_add_motion.bind(str(state["id"])))
	elif kind == MotionSelection.TRANSITION:
		future_add.pressed.connect(_add_transition.bind(str(state["id"])))
	elif kind == MotionSelection.MARKER:
		future_add.pressed.connect(_add_marker.bind(str(state["id"])))
	title_row.add_child(future_add)
	parent.add_child(title_row)
	for item in state[collection_name]:
		parent.add_child(_create_item_card(kind, str(state["id"]), item))


func _create_item_card(kind: String, state_id: String, item: Dictionary) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [item_display_name(kind, item), item_summary(kind, item)]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 46)
	button.focus_mode = Control.FOCUS_NONE
	var selected := selection != null and selection.matches(kind, state_id, str(item["id"]))
	button.add_theme_stylebox_override("normal", _card_style(selected))
	button.add_theme_stylebox_override("hover", _card_style(true))
	button.add_theme_color_override("font_color", Color("#f2c94c") if selected else Color("#d6dbe4"))
	button.pressed.connect(_select_item.bind(kind, state_id, str(item["id"])))
	return button


func _add_motion(state_id: String) -> void:
	var error := add_motion(state_id)
	if not error.is_empty():
		authoring_error.emit(error)


func _add_transition(state_id: String) -> void:
	var error := add_transition(state_id)
	if not error.is_empty():
		authoring_error.emit(error)


func _add_marker(state_id: String) -> void:
	var error := add_marker(state_id)
	if not error.is_empty():
		authoring_error.emit(error)


func _select_state(state_id: String) -> void:
	if selection == null:
		return
	selection.select_state(asset_id, state_id)
	_rebuild()
	selection_changed.emit()


func _select_item(kind: String, state_id: String, item_id: String) -> void:
	if selection == null:
		return
	selection.select_item(kind, asset_id, state_id, item_id)
	_rebuild()
	selection_changed.emit()


func _panel_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#20242c")
	style.border_color = Color("#f2c94c") if selected else Color("#363d48")
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(7.0)
	return style


func _card_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#303641") if selected else Color("#252a33")
	style.border_color = Color("#f2c94c") if selected else Color("#3a424f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(7.0)
	return style
