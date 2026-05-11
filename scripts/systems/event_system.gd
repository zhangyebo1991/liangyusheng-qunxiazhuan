extends RefCounted

const ConditionSystemScript = preload("res://scripts/systems/condition_system.gd")
const EffectSystemScript = preload("res://scripts/systems/effect_system.gd")

var condition_system = ConditionSystemScript.new()
var effect_system = EffectSystemScript.new()

func apply_event(game_state, event_data: Variant, context: Dictionary = {}) -> Dictionary:
	var result = _empty_result()
	if game_state == null:
		_add_error(result, "游戏状态缺失。")
		return result
	if typeof(event_data) != TYPE_DICTIONARY:
		_add_error(result, "事件格式错误。")
		return result

	var conditions = event_data.get("conditions", [])
	if typeof(conditions) != TYPE_ARRAY:
		_add_error(result, "事件条件格式错误。")
		return result

	var condition_result = condition_system.are_conditions_met(game_state, conditions, context)
	_append_messages(result, condition_result)
	if not bool(condition_result.get("success", false)):
		_add_errors(result, condition_result.get("errors", []))
		return result
	if not bool(condition_result.get("met", false)):
		result["conditions_met"] = false
		result["success"] = false
		return result

	result["conditions_met"] = true
	var effects = event_data.get("effects", [])
	if typeof(effects) != TYPE_ARRAY:
		_add_error(result, "事件效果格式错误。")
		return result
	if effects.is_empty():
		result["success"] = true
		return result

	var effect_result = effect_system.apply_effects(game_state, effects, context)
	result["effect_result"] = effect_result
	result["applied"] = int(effect_result.get("applied", 0))
	result["failed"] = int(effect_result.get("failed", 0))
	_append_messages(result, effect_result)
	_add_errors(result, effect_result.get("errors", []))
	result["success"] = bool(effect_result.get("success", false))
	return result

func _empty_result() -> Dictionary:
	return {
		"success": false,
		"conditions_met": false,
		"applied": 0,
		"failed": 0,
		"messages": [],
		"errors": [],
		"effect_result": {},
	}

func _append_messages(target: Dictionary, source: Dictionary) -> void:
	var messages: Array = target["messages"]
	for message in source.get("messages", []):
		messages.append(message)

func _add_errors(target: Dictionary, errors: Array) -> void:
	for error in errors:
		_add_error(target, str(error))

func _add_error(target: Dictionary, message: String) -> void:
	target["success"] = false
	target["failed"] = int(target.get("failed", 0)) + 1
	var errors: Array = target["errors"]
	errors.append(message)
