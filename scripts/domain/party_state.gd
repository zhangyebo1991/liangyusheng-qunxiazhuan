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
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount

func to_dictionary() -> Dictionary:
	return {
		"members": members.duplicate(),
		"inventory": inventory.duplicate(true),
	}

func from_dictionary(data: Dictionary) -> void:
	members = _to_string_array(data.get("members", []))
	inventory = data.get("inventory", {}).duplicate(true)

func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
