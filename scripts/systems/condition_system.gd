extends RefCounted

func are_conditions_met(game_state, conditions: Variant, context: Dictionary = {}) -> Dictionary:
	var result = _empty_result()
	if game_state == null:
		_add_error(result, "游戏状态缺失。")
		return result
	if typeof(conditions) != TYPE_ARRAY:
		_add_error(result, "条件列表格式错误。")
		return result

	for condition in conditions:
		var condition_result = is_condition_met(game_state, condition, context)
		_merge_result(result, condition_result)

	result["success"] = result.get("errors", []).is_empty()
	result["met"] = bool(result.get("success", false)) and int(result.get("failed_conditions", 0)) == 0
	return result

func is_condition_met(game_state, condition: Variant, context: Dictionary = {}) -> Dictionary:
	var result = _empty_result()
	if game_state == null:
		_add_error(result, "游戏状态缺失。")
		return result
	if typeof(condition) != TYPE_DICTIONARY:
		_add_error(result, "条件格式错误。")
		return result

	var condition_type = str(condition.get("type", ""))
	if condition_type.is_empty():
		_add_error(result, "条件缺少类型。")
		return result

	match condition_type:
		"quest_status":
			_check_quest_status(result, game_state, condition)
		"flag_equals":
			_check_flag_equals(result, game_state, condition)
		"has_item":
			_check_has_item(result, game_state, condition)
		"map_object_resolved":
			_check_map_object_resolved(result, game_state, condition)
		"coins_at_least":
			_check_coins_at_least(result, game_state, condition)
		"not":
			_check_not(result, game_state, condition, context)
		_:
			_add_error(result, "未知条件类型：%s" % condition_type)

	result["success"] = result.get("errors", []).is_empty()
	return result

func _check_quest_status(result: Dictionary, game_state, condition: Dictionary) -> void:
	var quest_id = str(condition.get("quest_id", ""))
	var status = str(condition.get("status", ""))
	if quest_id.is_empty():
		_add_error(result, "任务条件缺少任务编号。")
		return
	if status.is_empty():
		_add_error(result, "任务条件缺少状态。")
		return
	if game_state.quest_system == null:
		_add_error(result, "任务系统缺失。")
		return
	if game_state.quest_system.get_status(quest_id) != status:
		_mark_unmet(result, "任务状态不满足：%s" % quest_id)

func _check_flag_equals(result: Dictionary, game_state, condition: Dictionary) -> void:
	var key = str(condition.get("key", ""))
	if key.is_empty():
		_add_error(result, "flag 条件缺少 key。")
		return
	var expected = condition.get("value", true)
	if game_state.flags.get(key, null) != expected:
		_mark_unmet(result, "线索条件不满足：%s" % key)

func _check_has_item(result: Dictionary, game_state, condition: Dictionary) -> void:
	var item_id = str(condition.get("item_id", ""))
	var amount = int(condition.get("amount", 1))
	if item_id.is_empty():
		_add_error(result, "物品条件缺少物品编号。")
		return
	if amount <= 0:
		_add_error(result, "物品条件数量必须大于 0。")
		return
	if game_state.party == null:
		_add_error(result, "队伍状态缺失。")
		return
	if not game_state.party.has_item(item_id, amount):
		_mark_unmet(result, "缺少物品：%s x%d" % [item_id, amount])

func _check_map_object_resolved(result: Dictionary, game_state, condition: Dictionary) -> void:
	var object_id = str(condition.get("object_id", ""))
	if object_id.is_empty():
		_add_error(result, "地图对象条件缺少对象编号。")
		return
	if not game_state.is_map_object_resolved(object_id):
		_mark_unmet(result, "地图对象状态不满足：%s" % object_id)

func _check_coins_at_least(result: Dictionary, game_state, condition: Dictionary) -> void:
	var amount = int(condition.get("amount", 0))
	if amount <= 0:
		_add_error(result, "铜钱条件数量必须大于 0。")
		return
	if game_state.party == null:
		_add_error(result, "队伍状态缺失。")
		return
	if int(game_state.party.coins) < amount:
		_mark_unmet(result, "铜钱不足：需要 %d 文。" % amount)

func _check_not(result: Dictionary, game_state, condition: Dictionary, context: Dictionary) -> void:
	var nested = condition.get("condition", {})
	if typeof(nested) != TYPE_DICTIONARY:
		_add_error(result, "not 条件缺少子条件。")
		return
	var nested_result = is_condition_met(game_state, nested, context)
	if not bool(nested_result.get("success", false)):
		_merge_result(result, nested_result)
		return
	if bool(nested_result.get("met", false)):
		_mark_unmet(result, "反向条件不满足。")

func _empty_result() -> Dictionary:
	return {
		"success": true,
		"met": true,
		"failed_conditions": 0,
		"messages": [],
		"errors": [],
	}

func _mark_unmet(result: Dictionary, message: String) -> void:
	result["met"] = false
	result["failed_conditions"] = int(result.get("failed_conditions", 0)) + 1
	var messages: Array = result["messages"]
	messages.append(message)

func _add_error(result: Dictionary, message: String) -> void:
	result["success"] = false
	result["met"] = false
	var errors: Array = result["errors"]
	errors.append(message)

func _merge_result(target: Dictionary, source: Dictionary) -> void:
	if not bool(source.get("success", false)):
		target["success"] = false
	if not bool(source.get("met", false)):
		target["met"] = false
	target["failed_conditions"] = int(target.get("failed_conditions", 0)) + int(source.get("failed_conditions", 0))
	for key in ["messages", "errors"]:
		var target_values: Array = target[key]
		for value in source.get(key, []):
			target_values.append(value)
