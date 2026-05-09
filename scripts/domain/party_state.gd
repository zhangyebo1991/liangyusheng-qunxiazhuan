class_name PartyState
extends RefCounted

var members: Array[String] = []
var inventory: Dictionary = {}

func add_member(actor_id: String) -> void:
	if actor_id.is_empty():
		return
	if not members.has(actor_id):
		members.append(actor_id)

func has_member(actor_id: String) -> bool:
	return members.has(actor_id)

func add_item(item_id: String, amount: int = 1) -> void:
	if item_id.is_empty() or amount <= 0:
		return
	inventory[item_id] = get_item_count(item_id) + amount

func get_item_count(item_id: String) -> int:
	if item_id.is_empty():
		return 0
	return max(0, int(inventory.get(item_id, 0)))

func has_item(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false
	return get_item_count(item_id) >= amount

func remove_item(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false
	var current = get_item_count(item_id)
	if current < amount:
		return false
	var remaining = current - amount
	if remaining <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = remaining
	return true

func to_dictionary() -> Dictionary:
	return {
		"members": members.duplicate(),
		"inventory": inventory.duplicate(true),
	}

func from_dictionary(data: Dictionary) -> void:
	members = _to_string_array(data.get("members", []))
	inventory = {}
	var raw_inventory = data.get("inventory", {})
	if typeof(raw_inventory) != TYPE_DICTIONARY:
		return
	for item_id in raw_inventory.keys():
		var amount = int(raw_inventory[item_id])
		if amount > 0:
			inventory[str(item_id)] = amount

func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
