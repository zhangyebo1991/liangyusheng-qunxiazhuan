class_name PartyState
extends RefCounted

var members: Array[String] = []
var inventory: Dictionary = {}
var coins := 0
var equipment: Dictionary = {}
var member_status: Dictionary = {}

func add_member(actor_id: String) -> void:
	if actor_id.is_empty():
		return
	if not members.has(actor_id):
		members.append(actor_id)

func has_member(actor_id: String) -> bool:
	return members.has(actor_id)

func set_member_status(actor_id: String, status: Dictionary) -> void:
	if actor_id.is_empty() or not has_member(actor_id):
		return
	var current = get_member_status(actor_id)
	var next_status: Dictionary = {
		"level": max(1, int(current.get("level", 1))),
		"exp": max(0, int(current.get("exp", 0))),
		"total_exp": max(0, int(current.get("total_exp", 0))),
	}
	if status.has("level"):
		next_status["level"] = max(1, int(status.get("level", 1)))
	if status.has("exp"):
		next_status["exp"] = max(0, int(status.get("exp", 0)))
	if status.has("total_exp"):
		next_status["total_exp"] = max(0, int(status.get("total_exp", 0)))
	if status.has("hp"):
		next_status["hp"] = max(0, int(status.get("hp", 0)))
	elif current.has("hp"):
		next_status["hp"] = max(0, int(current.get("hp", 0)))
	if status.has("mp"):
		next_status["mp"] = max(0, int(status.get("mp", 0)))
	elif current.has("mp"):
		next_status["mp"] = max(0, int(current.get("mp", 0)))
	member_status[actor_id] = next_status

func get_member_status(actor_id: String) -> Dictionary:
	if actor_id.is_empty() or typeof(member_status.get(actor_id, {})) != TYPE_DICTIONARY:
		return {}
	return member_status.get(actor_id, {}).duplicate(true)

func set_equipment(actor_id: String, slot: String, item_id: String) -> void:
	if actor_id.is_empty() or slot.is_empty() or item_id.is_empty() or not has_member(actor_id):
		return
	var raw_slots = equipment.get(actor_id, {})
	var slots: Dictionary = raw_slots.duplicate(true) if typeof(raw_slots) == TYPE_DICTIONARY else {}
	slots[slot] = item_id
	equipment[actor_id] = slots

func clear_equipment(actor_id: String, slot: String) -> void:
	if actor_id.is_empty() or slot.is_empty() or typeof(equipment.get(actor_id, {})) != TYPE_DICTIONARY:
		return
	var slots: Dictionary = equipment.get(actor_id, {}).duplicate(true)
	slots.erase(slot)
	if slots.is_empty():
		equipment.erase(actor_id)
	else:
		equipment[actor_id] = slots

func get_equipped_item(actor_id: String, slot: String) -> String:
	if actor_id.is_empty() or slot.is_empty() or typeof(equipment.get(actor_id, {})) != TYPE_DICTIONARY:
		return ""
	return str(equipment.get(actor_id, {}).get(slot, ""))

func count_equipped_item(item_id: String) -> int:
	if item_id.is_empty():
		return 0
	var count := 0
	for actor_id in equipment.keys():
		var slots = equipment.get(actor_id, {})
		if typeof(slots) != TYPE_DICTIONARY:
			continue
		for slot in slots.keys():
			if str(slots[slot]) == item_id:
				count += 1
	return count

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

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount

func can_afford(amount: int) -> bool:
	if amount <= 0:
		return false
	return coins >= amount

func spend_coins(amount: int) -> bool:
	if not can_afford(amount):
		return false
	coins -= amount
	return true

func to_dictionary() -> Dictionary:
	return {
		"members": members.duplicate(),
		"inventory": inventory.duplicate(true),
		"coins": coins,
		"equipment": equipment.duplicate(true),
		"member_status": member_status.duplicate(true),
	}

func from_dictionary(data: Dictionary) -> void:
	members = _to_string_array(data.get("members", []))
	inventory = {}
	coins = max(0, int(data.get("coins", 0)))
	equipment = _read_nested_string_dictionary(data.get("equipment", {}))
	member_status = _read_member_status(data.get("member_status", {}))
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

func _read_nested_string_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for actor_id in value.keys():
		var raw_slots = value[actor_id]
		if typeof(raw_slots) != TYPE_DICTIONARY:
			continue
		var slots: Dictionary = {}
		for slot in raw_slots.keys():
			var normalized_slot = str(slot)
			var item_id = str(raw_slots[slot])
			if not normalized_slot.is_empty() and not item_id.is_empty():
				slots[normalized_slot] = item_id
		if not slots.is_empty():
			result[str(actor_id)] = slots
	return result

func _read_member_status(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for actor_id in value.keys():
		var raw_status = value[actor_id]
		if typeof(raw_status) != TYPE_DICTIONARY:
			continue
		var status: Dictionary = {
			"level": max(1, int(raw_status.get("level", 1))),
			"exp": max(0, int(raw_status.get("exp", 0))),
			"total_exp": max(0, int(raw_status.get("total_exp", 0))),
		}
		if raw_status.has("hp"):
			status["hp"] = max(0, int(raw_status.get("hp", 0)))
		if raw_status.has("mp"):
			status["mp"] = max(0, int(raw_status.get("mp", 0)))
		result[str(actor_id)] = status
	return result
