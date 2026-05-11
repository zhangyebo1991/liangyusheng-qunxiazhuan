extends RefCounted

const ConditionSystemScript = preload("res://scripts/systems/condition_system.gd")

var repository: Node = null
var condition_system = ConditionSystemScript.new()

func set_repository(next_repository: Node) -> void:
	repository = next_repository

func get_title(dialogue_id: String) -> String:
	var dialogue = _get_dialogue(dialogue_id)
	return str(dialogue.get("title", ""))

func get_lines(dialogue_id: String) -> Array:
	var dialogue = _get_dialogue(dialogue_id)
	return dialogue.get("lines", [])

func get_dialogue(dialogue_id: String) -> Dictionary:
	return _get_dialogue(dialogue_id).duplicate(true)

func get_options(dialogue_id: String) -> Array:
	var options = _get_dialogue(dialogue_id).get("options", [])
	if typeof(options) != TYPE_ARRAY:
		return []
	return options.duplicate(true)

func build_dialogue_state(dialogue_id: String, game_state) -> Dictionary:
	var dialogue = get_dialogue(dialogue_id)
	var lines = dialogue.get("lines", [])
	if typeof(lines) != TYPE_ARRAY:
		lines = []
	return {
		"id": str(dialogue.get("id", dialogue_id)),
		"title": str(dialogue.get("title", "")),
		"lines": lines.duplicate(true),
		"options": _build_options(dialogue, game_state),
	}

func _build_options(dialogue: Dictionary, game_state) -> Array:
	var raw_options = dialogue.get("options", [])
	if typeof(raw_options) != TYPE_ARRAY:
		return []
	var result: Array = []
	for raw_option in raw_options:
		if typeof(raw_option) != TYPE_DICTIONARY:
			continue
		var option = raw_option.duplicate(true)
		var conditions = option.get("conditions", [])
		var condition_result = {"success": true, "met": true, "messages": [], "errors": []}
		if typeof(conditions) == TYPE_ARRAY:
			condition_result = condition_system.are_conditions_met(game_state, conditions)
		else:
			condition_result = {"success": false, "met": false, "messages": [], "errors": ["选项条件格式错误。"]}
		var available = bool(condition_result.get("success", false)) and bool(condition_result.get("met", false))
		option["available"] = available
		option["condition_result"] = condition_result
		if available:
			option["unavailable_reason"] = ""
		else:
			option["unavailable_reason"] = _unavailable_reason(option, condition_result)
		result.append(option)
	return result

func _unavailable_reason(option: Dictionary, condition_result: Dictionary) -> String:
	var configured = str(option.get("unavailable_text", ""))
	if not configured.is_empty():
		return configured
	var messages = condition_result.get("messages", [])
	if typeof(messages) == TYPE_ARRAY and not messages.is_empty():
		return str(messages[0])
	var errors = condition_result.get("errors", [])
	if typeof(errors) == TYPE_ARRAY and not errors.is_empty():
		return str(errors[0])
	return "条件尚未满足。"

func _get_dialogue(dialogue_id: String) -> Dictionary:
	if repository == null or dialogue_id.is_empty():
		return {}
	if repository.has_method("get_dialogue"):
		return repository.get_dialogue(dialogue_id)
	return {}
