extends RefCounted

const VALID_SLOTS := ["weapon", "armor", "accessory"]
const MESSAGE_MISSING_MEMBER := "队伍成员不存在。"
const MESSAGE_MISSING_ITEM := "背包中没有此物。"
const MESSAGE_MISSING_DATA := "装备资料缺失。"
const MESSAGE_UNEQUIPPABLE := "此物不能装备。"
const MESSAGE_INVALID_SLOT := "装备槽位无效。"
const MESSAGE_INSUFFICIENT_COUNT := "装备数量不足。"

func can_equip(party, actor_id: String, item_id: String, repository) -> Dictionary:
	var normalized_actor_id = str(actor_id)
	var normalized_item_id = str(item_id)
	if party == null or not party.has_member(normalized_actor_id):
		return _failure(normalized_actor_id, normalized_item_id, "", MESSAGE_MISSING_MEMBER)
	if normalized_item_id.is_empty() or party.get_item_count(normalized_item_id) <= 0:
		return _failure(normalized_actor_id, normalized_item_id, "", MESSAGE_MISSING_ITEM)

	var item_data = _get_item(repository, normalized_item_id)
	if item_data.is_empty():
		return _failure(normalized_actor_id, normalized_item_id, "", MESSAGE_MISSING_DATA)
	var equipment_data = _equipment_data(item_data)
	if equipment_data.is_empty():
		return _failure(normalized_actor_id, normalized_item_id, "", MESSAGE_UNEQUIPPABLE)

	var slot = str(equipment_data.get("slot", ""))
	if not VALID_SLOTS.has(slot):
		return _failure(normalized_actor_id, normalized_item_id, slot, MESSAGE_INVALID_SLOT)
	if party.get_equipped_item(normalized_actor_id, slot) != normalized_item_id:
		var available_count = party.get_item_count(normalized_item_id) - party.count_equipped_item(normalized_item_id)
		if available_count <= 0:
			return _failure(normalized_actor_id, normalized_item_id, slot, MESSAGE_INSUFFICIENT_COUNT)

	return {
		"success": true,
		"message": "可以装备。",
		"actor_id": normalized_actor_id,
		"item_id": normalized_item_id,
		"slot": slot,
	}

func equip(party, actor_id: String, item_id: String, repository) -> Dictionary:
	var check = can_equip(party, actor_id, item_id, repository)
	if not bool(check.get("success", false)):
		return check
	party.set_equipment(str(check.get("actor_id", "")), str(check.get("slot", "")), str(check.get("item_id", "")))
	return {
		"success": true,
		"message": "装备成功。",
		"actor_id": str(check.get("actor_id", "")),
		"item_id": str(check.get("item_id", "")),
		"slot": str(check.get("slot", "")),
	}

func unequip(party, actor_id: String, slot: String) -> Dictionary:
	var normalized_actor_id = str(actor_id)
	var normalized_slot = str(slot)
	if party == null or not party.has_member(normalized_actor_id):
		return _failure(normalized_actor_id, "", normalized_slot, MESSAGE_MISSING_MEMBER)
	if not VALID_SLOTS.has(normalized_slot):
		return _failure(normalized_actor_id, "", normalized_slot, MESSAGE_INVALID_SLOT)

	var item_id = party.get_equipped_item(normalized_actor_id, normalized_slot)
	party.clear_equipment(normalized_actor_id, normalized_slot)
	return {
		"success": true,
		"message": "卸下成功。",
		"actor_id": normalized_actor_id,
		"item_id": item_id,
		"slot": normalized_slot,
	}

func get_equipment_bonus(party, actor_id: String, repository) -> Dictionary:
	var normalized_actor_id = str(actor_id)
	var bonus: Dictionary = {}
	if party == null or not party.has_member(normalized_actor_id):
		return bonus
	var raw_slots = party.equipment.get(normalized_actor_id, {})
	if typeof(raw_slots) != TYPE_DICTIONARY:
		return bonus

	for slot in raw_slots.keys():
		var item_id = str(raw_slots[slot])
		if item_id.is_empty():
			continue
		var equipment_data = _equipment_data(_get_item(repository, item_id))
		var stat_bonus = equipment_data.get("stat_bonus", {})
		if typeof(stat_bonus) != TYPE_DICTIONARY:
			continue
		for stat in stat_bonus.keys():
			var stat_name = str(stat)
			if stat_name.is_empty():
				continue
			bonus[stat_name] = int(bonus.get(stat_name, 0)) + int(stat_bonus[stat])
	return bonus

func _get_item(repository, item_id: String) -> Dictionary:
	if repository == null or not repository.has_method("get_item"):
		return {}
	var item_data = repository.get_item(item_id)
	return item_data.duplicate(true) if typeof(item_data) == TYPE_DICTIONARY else {}

func _equipment_data(item_data: Dictionary) -> Dictionary:
	if str(item_data.get("type", "")) != "equipment":
		return {}
	var raw_equipment = item_data.get("equipment", {})
	if typeof(raw_equipment) != TYPE_DICTIONARY:
		return {}
	return raw_equipment.duplicate(true)

func _failure(actor_id: String, item_id: String, slot: String, message: String) -> Dictionary:
	return {
		"success": false,
		"message": message,
		"actor_id": actor_id,
		"item_id": item_id,
		"slot": slot,
	}