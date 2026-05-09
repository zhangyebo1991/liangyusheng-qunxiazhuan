extends RefCounted

const MESSAGE_INVALID_ITEM := "此商品暂时不能购买。"
const MESSAGE_INSUFFICIENT_COINS := "铜钱不足。"

var repository = null

func set_repository(next_repository) -> void:
	repository = next_repository

func buy_item(game_state, item_id: String, quantity: int = 1) -> Dictionary:
	var normalized_item_id = str(item_id)
	var normalized_quantity = int(quantity)
	if game_state == null or game_state.party == null:
		return _failure(normalized_item_id, MESSAGE_INVALID_ITEM, max(0, normalized_quantity), 0, 0, 0)
	if normalized_item_id.is_empty() or normalized_quantity <= 0:
		return _failure(
			normalized_item_id,
			MESSAGE_INVALID_ITEM,
			max(0, normalized_quantity),
			0,
			game_state.party.coins,
			game_state.party.get_item_count(normalized_item_id)
		)

	var item_repository = _get_repository()
	if item_repository == null:
		return _failure(
			normalized_item_id,
			MESSAGE_INVALID_ITEM,
			normalized_quantity,
			0,
			game_state.party.coins,
			game_state.party.get_item_count(normalized_item_id)
		)
	var item_data = item_repository.get_item(normalized_item_id)
	if item_data.is_empty():
		return _failure(
			normalized_item_id,
			MESSAGE_INVALID_ITEM,
			normalized_quantity,
			0,
			game_state.party.coins,
			game_state.party.get_item_count(normalized_item_id)
		)

	var price = int(item_data.get("value", 0))
	if price <= 0:
		return _failure(
			normalized_item_id,
			MESSAGE_INVALID_ITEM,
			normalized_quantity,
			0,
			game_state.party.coins,
			game_state.party.get_item_count(normalized_item_id)
		)

	var cost = price * normalized_quantity
	if not game_state.party.can_afford(cost):
		return _failure(
			normalized_item_id,
			MESSAGE_INSUFFICIENT_COINS,
			normalized_quantity,
			cost,
			game_state.party.coins,
			game_state.party.get_item_count(normalized_item_id)
		)
	if not game_state.party.spend_coins(cost):
		return _failure(
			normalized_item_id,
			MESSAGE_INSUFFICIENT_COINS,
			normalized_quantity,
			cost,
			game_state.party.coins,
			game_state.party.get_item_count(normalized_item_id)
		)

	game_state.party.add_item(normalized_item_id, normalized_quantity)
	return {
		"success": true,
		"message": "买入%s。" % str(item_data.get("name", "商品")),
		"item_id": normalized_item_id,
		"quantity": normalized_quantity,
		"cost": cost,
		"coins": game_state.party.coins,
		"remaining": game_state.party.get_item_count(normalized_item_id),
	}

func _failure(item_id: String, message: String, quantity: int, cost: int, coins: int, remaining: int) -> Dictionary:
	return {
		"success": false,
		"message": message,
		"item_id": item_id,
		"quantity": quantity,
		"cost": cost,
		"coins": coins,
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
