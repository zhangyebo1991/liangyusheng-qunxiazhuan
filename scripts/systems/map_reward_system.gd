extends RefCounted

const MESSAGE_EMPTY := "这里什么也没有。"

var repository = null

func set_repository(next_repository) -> void:
	repository = next_repository

func claim_pickup(game_state, object_record: Dictionary) -> Dictionary:
	var object_id = str(object_record.get("id", ""))
	if game_state == null or game_state.party == null:
		return _failure(object_id)
	if object_id.is_empty():
		push_error("拾取对象缺少编号。")
		return _failure(object_id)
	if game_state.is_map_object_resolved(object_id):
		return _failure(object_id)

	var awarded_items = _award_items(game_state, object_record)
	var awarded_coins = _award_coins(game_state, object_record)
	if awarded_items.is_empty() and awarded_coins <= 0:
		return _failure(object_id)

	game_state.resolve_map_object(object_id)
	return {
		"success": true,
		"message": _build_message(awarded_items, awarded_coins),
		"items": awarded_items,
		"coins": awarded_coins,
		"object_id": object_id,
	}

func _award_items(game_state, object_record: Dictionary) -> Array:
	var awarded: Array = []
	var item_repository = _get_repository()
	var raw_items = object_record.get("reward_items", [])
	if typeof(raw_items) != TYPE_ARRAY:
		return awarded
	var amounts = object_record.get("reward_item_amounts", {})
	if typeof(amounts) != TYPE_DICTIONARY:
		amounts = {}

	for raw_item_id in raw_items:
		var item_id = str(raw_item_id)
		if item_id.is_empty():
			continue
		var item_data = item_repository.get_item(item_id) if item_repository != null else {}
		if item_data.is_empty():
			push_error("拾取奖励物品不存在：%s" % item_id)
			continue
		var amount = max(1, int(amounts.get(item_id, 1)))
		game_state.party.add_item(item_id, amount)
		awarded.append({
			"id": item_id,
			"name": str(item_data.get("name", item_id)),
			"amount": amount,
		})
	return awarded

func _award_coins(game_state, object_record: Dictionary) -> int:
	var coins = int(object_record.get("reward_coins", 0))
	if coins <= 0:
		return 0
	game_state.party.add_coins(coins)
	return coins

func _build_message(items: Array, coins: int) -> String:
	var parts: Array[String] = []
	for item in items:
		var name = str(item.get("name", "物品"))
		var amount = int(item.get("amount", 1))
		if amount > 1:
			parts.append("%s x%d" % [name, amount])
		else:
			parts.append(name)
	if coins > 0:
		parts.append("%d 文" % coins)
	if parts.is_empty():
		return MESSAGE_EMPTY
	return "获得：%s。" % "、".join(parts)

func _failure(object_id: String) -> Dictionary:
	return {
		"success": false,
		"message": MESSAGE_EMPTY,
		"items": [],
		"coins": 0,
		"object_id": object_id,
	}

func _get_repository():
	if repository != null:
		return repository
	var loop = Engine.get_main_loop()
	if loop != null and loop.root != null and loop.root.has_node("DataRepository"):
		return loop.root.get_node("DataRepository")
	return null
