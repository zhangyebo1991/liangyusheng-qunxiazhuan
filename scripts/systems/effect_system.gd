extends RefCounted

const VALID_QUEST_STATUSES := [
	"not_started",
	"active",
	"ready_to_complete",
	"completed",
]

func apply_effects(game_state, effects: Variant, context: Dictionary = {}) -> Dictionary:
	var result = _empty_result()
	if game_state == null:
		_add_error(result, "游戏状态缺失。")
		return result
	if typeof(effects) != TYPE_ARRAY:
		_add_error(result, "效果列表格式错误。")
		return result

	for effect in effects:
		_merge_result(result, apply_effect(game_state, effect, context))
	result["success"] = int(result.get("applied", 0)) > 0 and int(result.get("failed", 0)) == 0
	return result

func apply_effect(game_state, effect: Variant, _context: Dictionary = {}) -> Dictionary:
	var result = _empty_result()
	if game_state == null:
		_add_error(result, "游戏状态缺失。")
		return result
	if typeof(effect) != TYPE_DICTIONARY:
		_add_error(result, "效果格式错误。")
		return result

	var effect_type = str(effect.get("type", ""))
	if effect_type.is_empty():
		_add_error(result, "效果缺少类型。")
		return result

	match effect_type:
		"add_item":
			_apply_add_item(result, game_state, effect)
		"add_coins":
			_apply_add_coins(result, game_state, effect)
		"set_flag":
			_apply_set_flag(result, game_state, effect)
		"set_quest_status":
			_apply_set_quest_status(result, game_state, effect)
		"resolve_map_object":
			_apply_resolve_map_object(result, game_state, effect)
		"add_martial_proficiency":
			_apply_add_martial_proficiency(result, game_state, effect)
		_:
			_add_error(result, "未知效果类型：%s" % effect_type)
	result["success"] = int(result.get("applied", 0)) > 0 and int(result.get("failed", 0)) == 0
	return result

func _apply_add_item(result: Dictionary, game_state, effect: Dictionary) -> void:
	var item_id = str(effect.get("item_id", ""))
	var amount = int(effect.get("amount", 1))
	if item_id.is_empty():
		_add_error(result, "物品效果缺少物品编号。")
		return
	if amount <= 0:
		_add_error(result, "物品效果数量必须大于 0。")
		return
	if game_state.party == null:
		_add_error(result, "队伍状态缺失。")
		return
	game_state.party.add_item(item_id, amount)
	var items: Array = result["items"]
	items.append({"id": item_id, "amount": amount})
	_mark_applied(result, "获得物品：%s x%d" % [item_id, amount])

func _apply_add_coins(result: Dictionary, game_state, effect: Dictionary) -> void:
	var amount = int(effect.get("amount", 0))
	if amount <= 0:
		_add_error(result, "铜钱效果数量必须大于 0。")
		return
	if game_state.party == null:
		_add_error(result, "队伍状态缺失。")
		return
	game_state.party.add_coins(amount)
	result["coins"] = int(result.get("coins", 0)) + amount
	_mark_applied(result, "获得铜钱：%d" % amount)

func _apply_set_flag(result: Dictionary, game_state, effect: Dictionary) -> void:
	var key = str(effect.get("key", ""))
	if key.is_empty():
		_add_error(result, "flag 效果缺少 key。")
		return
	var value = effect.get("value", true)
	game_state.set_flag(key, value)
	var flags: Array = result["flags"]
	flags.append({"key": key, "value": value})
	_mark_applied(result, "记录线索：%s" % key)

func _apply_set_quest_status(result: Dictionary, game_state, effect: Dictionary) -> void:
	var quest_id = str(effect.get("quest_id", ""))
	var status = str(effect.get("status", ""))
	if quest_id.is_empty():
		_add_error(result, "任务状态效果缺少任务编号。")
		return
	if not VALID_QUEST_STATUSES.has(status):
		_add_error(result, "任务状态无效：%s" % status)
		return
	if game_state.quest_system == null:
		_add_error(result, "任务系统缺失。")
		return
	if not game_state.quest_system.set_status(quest_id, status):
		_add_error(result, "任务状态写入失败：%s" % quest_id)
		return
	var quests: Array = result["quests"]
	quests.append({"id": quest_id, "status": status})
	_mark_applied(result, "任务状态变更：%s -> %s" % [quest_id, status])

func _apply_resolve_map_object(result: Dictionary, game_state, effect: Dictionary) -> void:
	var object_id = str(effect.get("object_id", ""))
	if object_id.is_empty():
		_add_error(result, "地图对象效果缺少对象编号。")
		return
	game_state.resolve_map_object(object_id)
	var resolved_objects: Array = result["resolved_objects"]
	resolved_objects.append(object_id)
	_mark_applied(result, "地图对象已解决：%s" % object_id)

func _apply_add_martial_proficiency(result: Dictionary, game_state, effect: Dictionary) -> void:
	var martial_art_id = str(effect.get("martial_art_id", ""))
	var amount = int(effect.get("amount", 0))
	if martial_art_id.is_empty():
		_add_error(result, "武学熟练度效果缺少武学编号。")
		return
	if amount <= 0:
		_add_error(result, "武学熟练度效果数量必须大于 0。")
		return
	var current = game_state.add_martial_proficiency(martial_art_id, amount)
	var martial: Array = result["martial_proficiency"]
	martial.append({"id": martial_art_id, "amount": amount, "current": current})
	_mark_applied(result, "武学熟练度提升：%s +%d" % [martial_art_id, amount])

func _empty_result() -> Dictionary:
	return {
		"success": false,
		"applied": 0,
		"failed": 0,
		"messages": [],
		"errors": [],
		"items": [],
		"coins": 0,
		"flags": [],
		"quests": [],
		"resolved_objects": [],
		"martial_proficiency": [],
	}

func _mark_applied(result: Dictionary, message: String) -> void:
	result["applied"] = int(result.get("applied", 0)) + 1
	var messages: Array = result["messages"]
	messages.append(message)

func _add_error(result: Dictionary, message: String) -> void:
	result["failed"] = int(result.get("failed", 0)) + 1
	var errors: Array = result["errors"]
	errors.append(message)
	result["success"] = false

func _merge_result(target: Dictionary, source: Dictionary) -> void:
	target["applied"] = int(target.get("applied", 0)) + int(source.get("applied", 0))
	target["failed"] = int(target.get("failed", 0)) + int(source.get("failed", 0))
	target["coins"] = int(target.get("coins", 0)) + int(source.get("coins", 0))
	for key in ["messages", "errors", "items", "flags", "quests", "resolved_objects", "martial_proficiency"]:
		var target_values: Array = target[key]
		for value in source.get(key, []):
			target_values.append(value)
