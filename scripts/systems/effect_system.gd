extends RefCounted

const JournalSystemScript = preload("res://scripts/systems/journal_system.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GrowthSystemScript = preload("res://scripts/systems/growth_system.gd")

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
		"remove_item":
			_apply_remove_item(result, game_state, effect)
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
		"add_party_member":
			_apply_add_party_member(result, game_state, effect)
		"add_party_exp":
			_apply_add_party_exp(result, game_state, effect)
		"restore_mp":
			_apply_restore_mp(result, game_state, effect)
		"rest_at_inn":
			_apply_rest_at_inn(result, game_state, effect)
		"add_rumor":
			_apply_add_rumor(result, game_state, effect, _context)
		"trigger_rumor":
			_apply_trigger_rumor(result, game_state, effect)
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

func _apply_remove_item(result: Dictionary, game_state, effect: Dictionary) -> void:
	var item_id = str(effect.get("item_id", ""))
	var amount = int(effect.get("amount", 1))
	if item_id.is_empty():
		_add_error(result, "扣除物品效果缺少物品编号。")
		return
	if amount <= 0:
		_add_error(result, "扣除物品效果数量必须大于 0。")
		return
	if game_state.party == null:
		_add_error(result, "队伍状态缺失。")
		return
	if not game_state.party.remove_item(item_id, amount):
		_add_error(result, "背包中没有足够物品：%s x%d" % [item_id, amount])
		return
	var removed_items: Array = result["removed_items"]
	removed_items.append({"id": item_id, "amount": amount})
	_mark_applied(result, "失去物品：%s x%d" % [item_id, amount])

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

func _apply_add_party_member(result: Dictionary, game_state, effect: Dictionary) -> void:
	var actor_id = str(effect.get("actor_id", ""))
	if actor_id.is_empty():
		_add_error(result, "队友效果缺少角色编号。")
		return
	if game_state.party == null:
		_add_error(result, "队伍状态缺失。")
		return
	if game_state.has_method("actor_exists") and not game_state.actor_exists(actor_id):
		_add_error(result, "角色不存在：%s" % actor_id)
		return
	game_state.party.add_member(actor_id)
	if game_state.has_method("initialize_party_member_status"):
		game_state.initialize_party_member_status(actor_id)
	var members: Array = result["party_members"]
	members.append(actor_id)
	_mark_applied(result, "队友加入：%s" % actor_id)

func _apply_add_party_exp(result: Dictionary, game_state, effect: Dictionary) -> void:
	var amount = int(effect.get("amount", 0))
	if amount <= 0:
		_add_error(result, "经验效果数量必须大于 0。")
		return
	if game_state.party == null:
		_add_error(result, "队伍状态缺失。")
		return
	var repository = _get_repository(game_state)
	var growth = GrowthSystemScript.new()
	var growth_result = growth.add_party_exp(game_state.party, amount, repository)
	if not bool(growth_result.get("success", false)):
		_add_error(result, "全队经验发放失败。")
		return
	var experience: Array = result["experience"]
	for member_result in growth_result.get("members", []):
		experience.append(member_result)
	if game_state.has_method("apply_growth_results"):
		game_state.apply_growth_results(experience)
	_mark_applied(result, "全队获得经验：%d" % amount)

func _apply_add_rumor(result: Dictionary, game_state, effect: Dictionary, context: Dictionary) -> void:
	var journal_state = _get_journal_state(game_state)
	if journal_state == null:
		_add_error(result, "江湖记事状态缺失。")
		return
	var journal_system = JournalSystemScript.new()
	var rumor_result = journal_system.add_rumor(journal_state, effect.get("rumor", {}), context)
	if not bool(rumor_result.get("success", false)):
		_add_error(result, str(rumor_result.get("message", "传闻记录失败。")))
		return
	var rumor_id = str(rumor_result.get("rumor_id", ""))
	if not rumor_id.is_empty():
		var rumors: Array = result["rumors"]
		rumors.append({"id": rumor_id, "duplicate": bool(rumor_result.get("duplicate", false))})
	_mark_applied(result, str(rumor_result.get("message", "传闻已记入江湖记事。")))

func _apply_trigger_rumor(result: Dictionary, game_state, effect: Dictionary) -> void:
	var journal_state = _get_journal_state(game_state)
	if journal_state == null:
		_add_error(result, "江湖记事状态缺失。")
		return
	var journal_system = JournalSystemScript.new()
	var rumor_result = journal_system.trigger_rumor(journal_state, str(effect.get("rumor_id", "")))
	if not bool(rumor_result.get("success", false)):
		_add_error(result, str(rumor_result.get("message", "传闻归档失败。")))
		return
	var rumor_id = str(rumor_result.get("rumor_id", ""))
	if not rumor_id.is_empty():
		var triggered: Array = result["triggered_rumors"]
		triggered.append(rumor_id)
	_mark_applied(result, str(rumor_result.get("message", "传闻已移入已触发列表。")))

func _apply_restore_mp(result: Dictionary, game_state, effect: Dictionary) -> void:
	var amount = int(effect.get("amount", 0))
	if amount <= 0:
		_add_error(result, "内力恢复数量必须大于 0。")
		return
	if not game_state.has_method("restore_hero_mp"):
		_add_error(result, "游戏状态不支持内力恢复。")
		return
	var restored = game_state.restore_hero_mp(amount)
	_mark_applied(result, "恢复内力：%d" % restored)

func _apply_rest_at_inn(result: Dictionary, game_state, effect: Dictionary) -> void:
	var inn_id = str(effect.get("inn_id", ""))
	if inn_id.is_empty():
		_add_error(result, "客栈休息缺少客栈编号。")
		return
	if game_state.party == null:
		_add_error(result, "队伍状态缺失。")
		return
	# 防御：不允许在战斗中休息
	if typeof(game_state.battle_context) == TYPE_DICTIONARY and not game_state.battle_context.is_empty():
		_add_error(result, "战斗中不能休息。")
		return
	var cost = int(effect.get("cost", 0))
	if cost > 0:
		if int(game_state.party.coins) < cost:
			_add_error(result, "铜钱不足无法支付客栈费用。")
			return
		game_state.party.spend_coins(cost)
		result["coins"] = int(result.get("coins", 0)) - cost

	# 全满恢复
	if game_state.has_method("restore_hero_hp"):
		var hp_missing = max(0, game_state.hero_max_hp - game_state.hero_hp)
		if hp_missing > 0:
			game_state.restore_hero_hp(hp_missing)
	if game_state.has_method("restore_hero_mp"):
		var mp_missing = max(0, game_state.hero_max_mp - game_state.hero_cur_mp)
		if mp_missing > 0:
			game_state.restore_hero_mp(mp_missing)
	# 绑定客栈
	if game_state.has_method("bind_inn"):
		game_state.bind_inn(inn_id)
	# 信号
	if game_state.is_inside_tree() and game_state.has_node("/root/EventBus"):
		game_state.get_node("/root/EventBus").inn_rested.emit(inn_id)
	_mark_applied(result, "在客栈歇息一晚。")

func apply_skill_tree_effects(effects: Dictionary) -> Dictionary:
	var result = _empty_result()
	if typeof(effects) != TYPE_DICTIONARY:
		_add_error(result, "技能树效果格式错误。")
		return result

	for key in effects.keys():
		var value = effects[key]
		match key:
			"damage_bonus":
				_mark_applied(result, "伤害加成 +%d" % int(value))
			"crit_chance":
				_mark_applied(result, "暴击率 +%.0f%%" % (float(value) * 100))
			"accuracy_bonus":
				_mark_applied(result, "精准加成 +%d" % int(value))
			"add_effect":
				_mark_applied(result, "附加效果：%s" % str(value))
			"extra_strike":
				_mark_applied(result, "连击率 +%.0f%%" % (float(value) * 100))
			_:
				_mark_applied(result, "未知技能树效果：%s" % str(key))

	result["success"] = int(result.get("applied", 0)) > 0 and int(result.get("failed", 0)) == 0
	return result

func _get_journal_state(game_state):
	if game_state == null:
		return null
	return game_state.get("journal_state")

func _get_repository(game_state):
	if game_state != null and game_state.is_inside_tree() and game_state.has_node("/root/DataRepository"):
		return game_state.get_node("/root/DataRepository")
	var repository = DataRepositoryScript.new()
	repository.load_all()
	return repository

func _empty_result() -> Dictionary:
	return {
		"success": false,
		"applied": 0,
		"failed": 0,
		"messages": [],
		"errors": [],
		"items": [],
		"removed_items": [],
		"coins": 0,
		"flags": [],
		"quests": [],
		"resolved_objects": [],
		"martial_proficiency": [],
		"party_members": [],
		"experience": [],
		"rumors": [],
		"triggered_rumors": [],
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
	for key in ["messages", "errors", "items", "removed_items", "flags", "quests", "resolved_objects", "martial_proficiency", "party_members", "experience", "rumors", "triggered_rumors"]:
		var target_values: Array = target[key]
		for value in source.get(key, []):
			target_values.append(value)
