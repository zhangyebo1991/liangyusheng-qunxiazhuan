extends RefCounted

const EffectSystemScript = preload("res://scripts/systems/effect_system.gd")

const MESSAGE_EMPTY := "这里什么也没有。"

var repository = null
var effect_system = EffectSystemScript.new()

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

	var effects = _build_pickup_effects(object_record)
	if effects.is_empty():
		return _failure(object_id)

	var effect_result = effect_system.apply_effects(game_state, effects, {"source": "pickup", "object_id": object_id})
	var awarded_items = _named_items(effect_result.get("items", []))
	var awarded_coins = int(effect_result.get("coins", 0))
	if not bool(effect_result.get("success", false)) or (awarded_items.is_empty() and awarded_coins <= 0):
		return _failure(object_id)

	return {
		"success": true,
		"message": _build_message(awarded_items, awarded_coins),
		"items": awarded_items,
		"coins": awarded_coins,
		"object_id": object_id,
	}

func _build_pickup_effects(object_record: Dictionary) -> Array:
	var object_id = str(object_record.get("id", ""))
	var raw_effects = object_record.get("effects", [])
	if typeof(raw_effects) == TYPE_ARRAY and not raw_effects.is_empty():
		return _filter_effects(raw_effects, object_id)
	return _legacy_reward_effects(object_record)

func _filter_effects(raw_effects: Array, object_id: String) -> Array:
	var result: Array = []
	var has_reward := false
	var has_resolve := false
	for raw_effect in raw_effects:
		if typeof(raw_effect) != TYPE_DICTIONARY:
			continue
		var effect = raw_effect.duplicate(true)
		match str(effect.get("type", "")):
			"add_item":
				var item_id = str(effect.get("item_id", ""))
				var amount = int(effect.get("amount", 1))
				if item_id.is_empty() or amount <= 0 or not _item_exists(item_id):
					push_error("拾取奖励物品不存在：%s" % item_id)
					continue
				has_reward = true
				result.append(effect)
			"add_coins":
				if int(effect.get("amount", 0)) <= 0:
					continue
				has_reward = true
				result.append(effect)
			"resolve_map_object":
				has_resolve = true
				result.append(effect)
			_:
				result.append(effect)
	if not has_reward:
		return []
	if not has_resolve:
		result.append({"type": "resolve_map_object", "object_id": object_id})
	return result

func _legacy_reward_effects(object_record: Dictionary) -> Array:
	var result: Array = []
	var raw_items = object_record.get("reward_items", [])
	if typeof(raw_items) == TYPE_ARRAY:
		var amounts = object_record.get("reward_item_amounts", {})
		if typeof(amounts) != TYPE_DICTIONARY:
			amounts = {}
		for raw_item_id in raw_items:
			var item_id = str(raw_item_id)
			if item_id.is_empty() or not _item_exists(item_id):
				push_error("拾取奖励物品不存在：%s" % item_id)
				continue
			result.append({
				"type": "add_item",
				"item_id": item_id,
				"amount": max(1, int(amounts.get(item_id, 1))),
			})

	var coins = int(object_record.get("reward_coins", 0))
	if coins > 0:
		result.append({"type": "add_coins", "amount": coins})

	if not result.is_empty():
		result.append({"type": "resolve_map_object", "object_id": str(object_record.get("id", ""))})
	return result

func _named_items(items: Array) -> Array:
	var result: Array = []
	var item_repository = _get_repository()
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_id = str(item.get("id", ""))
		if item_id.is_empty():
			continue
		var item_data = item_repository.get_item(item_id) if item_repository != null else {}
		result.append({
			"id": item_id,
			"name": str(item_data.get("name", item_id)),
			"amount": int(item.get("amount", 1)),
		})
	return result

func _item_exists(item_id: String) -> bool:
	var item_repository = _get_repository()
	if item_repository == null:
		return true
	return not item_repository.get_item(item_id).is_empty()

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
