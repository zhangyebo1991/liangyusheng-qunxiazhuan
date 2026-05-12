extends RefCounted

const MESSAGE_MISSING_ITEM := "背包中没有此物。"
const MESSAGE_MISSING_DATA := "此物品资料缺失。"
const MESSAGE_UNUSABLE := "此物暂时不能使用。"
const MESSAGE_FULL_HP := "气血已满。"
const MESSAGE_FULL_MP := "内力已满。"

var repository = null

func set_repository(next_repository) -> void:
	repository = next_repository

func use_item(game_state, item_id: String) -> Dictionary:
	var normalized_item_id = str(item_id)
	if normalized_item_id.is_empty():
		return _failure(normalized_item_id, MESSAGE_MISSING_DATA, 0)
	if game_state == null or game_state.party == null:
		return _failure(normalized_item_id, MESSAGE_MISSING_ITEM, 0)

	var count = game_state.party.get_item_count(normalized_item_id)
	if count <= 0:
		return _failure(normalized_item_id, MESSAGE_MISSING_ITEM, 0)

	var item_repository = _get_repository()
	if item_repository == null:
		return _failure(normalized_item_id, MESSAGE_MISSING_DATA, count)
	var item_data = item_repository.get_item(normalized_item_id)
	if item_data.is_empty():
		return _failure(normalized_item_id, MESSAGE_MISSING_DATA, count)
	if str(item_data.get("type", "")) != "consumable":
		return _failure(normalized_item_id, MESSAGE_UNUSABLE, count)

	var effects = item_data.get("effects", {})
	if typeof(effects) != TYPE_DICTIONARY:
		return _failure(normalized_item_id, MESSAGE_UNUSABLE, count)

	var heal_hp = int(effects.get("heal_hp", 0))
	var restore_mp = int(effects.get("restore_mp", 0))

	# 校验：必须至少有一种可处理的效果
	if heal_hp <= 0 and restore_mp <= 0:
		return _failure(normalized_item_id, MESSAGE_UNUSABLE, count)

	# heal_hp 路径：完全沿用原逻辑
	if heal_hp > 0:
		if game_state.is_hero_hp_full():
			return _failure(normalized_item_id, MESSAGE_FULL_HP, count)
		if not game_state.party.remove_item(normalized_item_id, 1):
			return _failure(normalized_item_id, MESSAGE_MISSING_ITEM, game_state.party.get_item_count(normalized_item_id))
		var restored = game_state.restore_hero_hp(heal_hp)
		if restored <= 0:
			game_state.party.add_item(normalized_item_id, 1)
			return _failure(normalized_item_id, MESSAGE_FULL_HP, game_state.party.get_item_count(normalized_item_id))
		return {
			"success": true,
			"message": "服下%s，气血恢复。" % str(item_data.get("name", "物品")),
			"item_id": normalized_item_id,
			"remaining": game_state.party.get_item_count(normalized_item_id),
			"recovered_hp": restored,
		}

	# restore_mp 路径：与 heal_hp 对位
	if game_state.is_hero_mp_full():
		return _failure(normalized_item_id, MESSAGE_FULL_MP, count)
	if not game_state.party.remove_item(normalized_item_id, 1):
		return _failure(normalized_item_id, MESSAGE_MISSING_ITEM, game_state.party.get_item_count(normalized_item_id))
	var recovered_mp = game_state.restore_hero_mp(restore_mp)
	if recovered_mp <= 0:
		game_state.party.add_item(normalized_item_id, 1)
		return _failure(normalized_item_id, MESSAGE_FULL_MP, game_state.party.get_item_count(normalized_item_id))
	return {
		"success": true,
		"message": "服下%s，内力恢复。" % str(item_data.get("name", "物品")),
		"item_id": normalized_item_id,
		"remaining": game_state.party.get_item_count(normalized_item_id),
		"recovered_mp": recovered_mp,
	}

func _failure(item_id: String, message: String, remaining: int) -> Dictionary:
	return {
		"success": false,
		"message": message,
		"item_id": item_id,
		"remaining": remaining,
	}

func _get_repository():
	if repository != null:
		return repository
	var loop = Engine.get_main_loop()
	if loop == null or loop.root == null:
		return null
	if loop.root.has_node("DataRepository"):
		return loop.root.get_node("DataRepository")
	return null
