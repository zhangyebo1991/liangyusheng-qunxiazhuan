extends RefCounted

const EquipmentSystemScript = preload("res://scripts/systems/equipment_system.gd")
const GrowthSystemScript = preload("res://scripts/systems/growth_system.gd")

var equipment_system = EquipmentSystemScript.new()
var growth_system = GrowthSystemScript.new()

func build_stats(party, actor_id: String, repository) -> Dictionary:
	var normalized_actor_id = str(actor_id)
	if normalized_actor_id.is_empty() or repository == null or not repository.has_method("get_actor"):
		return {}
	var actor = repository.get_actor(normalized_actor_id)
	if typeof(actor) != TYPE_DICTIONARY or actor.is_empty():
		return {}

	var bonus = equipment_system.get_equipment_bonus(party, normalized_actor_id, repository)
	var status = party.get_member_status(normalized_actor_id) if party != null and party.has_method("get_member_status") else {}
	var level = max(1, int(status.get("level", 1)))
	var growth_bonus = growth_system.get_growth_bonus(actor, level)
	var max_hp = max(1, int(actor.get("max_hp", actor.get("hp", 1))) + int(growth_bonus.get("max_hp", 0)) + int(bonus.get("max_hp", 0)))
	var max_mp = max(0, int(actor.get("max_mp", 0)) + int(growth_bonus.get("max_mp", 0)) + int(bonus.get("max_mp", 0)))
	var hp = clamp(int(status.get("hp", max_hp)), 0, max_hp)
	var mp = clamp(int(status.get("mp", max_mp)), 0, max_mp)

	return {
		"actor_id": normalized_actor_id,
		"unit_id": normalized_actor_id,
		"display_name": str(actor.get("name", normalized_actor_id)),
		"level": level,
		"exp": max(0, int(status.get("exp", 0))),
		"total_exp": max(0, int(status.get("total_exp", 0))),
		"next_level_exp": growth_system.next_level_required_exp(actor, level),
		"hp": hp,
		"max_hp": max_hp,
		"mp": mp,
		"max_mp": max_mp,
		"attack": max(1, int(actor.get("attack", 1)) + int(growth_bonus.get("attack", 0)) + int(bonus.get("attack", 0))),
		"defense": max(0, int(actor.get("defense", 0)) + int(growth_bonus.get("defense", 0)) + int(bonus.get("defense", 0))),
		"move_range": max(0, int(actor.get("move_range", 3)) + int(growth_bonus.get("move_range", 0)) + int(bonus.get("move_range", 0))),
		"attack_range": max(1, int(actor.get("attack_range", 1)) + int(growth_bonus.get("attack_range", 0)) + int(bonus.get("attack_range", 0))),
		"charge_speed": max(1, int(actor.get("charge_speed", 200)) + int(growth_bonus.get("charge_speed", 0)) + int(bonus.get("charge_speed", 0))),
		"martial_art_ids": _to_string_array(actor.get("martial_arts", [])),
		"sprite_tile_id": str(actor.get("sprite_tile_id", "")),
	}

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		var normalized = str(item)
		if not normalized.is_empty():
			result.append(normalized)
	return result