class_name MartialArtRecord
extends RefCounted

var id: String = ""
var name: String = ""
var school: String = ""
var power: int = 0
var cost: int = 0
var description: String = ""
var proficiency_reward: int = 1
var tactical: Dictionary = {}
var tactical_damage_bonus: int = 0
var tactical_range: int = 0
var tactical_range_shape: String = ""
var proficiency_thresholds: Array = []
var tactical_mp_cost: int = 0

static func from_dictionary(data: Dictionary):
	var martial_art = new()
	martial_art.id = str(data.get("id", ""))
	martial_art.name = str(data.get("name", ""))
	martial_art.school = str(data.get("school", ""))
	martial_art.power = int(data.get("power", 0))
	martial_art.cost = int(data.get("cost", 0))
	martial_art.description = str(data.get("description", ""))
	martial_art.proficiency_reward = max(0, int(data.get("proficiency_reward", 1)))
	martial_art.proficiency_thresholds = _read_int_array(data.get("proficiency_thresholds", []))
	martial_art.tactical = _read_tactical_config(data.get("tactical", {}), martial_art.cost)
	martial_art.tactical_damage_bonus = int(martial_art.tactical.get("damage_bonus", 0))
	martial_art.tactical_range = int(martial_art.tactical.get("range", 0))
	martial_art.tactical_range_shape = str(martial_art.tactical.get("range_shape", ""))
	martial_art.tactical_mp_cost = int(martial_art.tactical.get("mp_cost", 0))
	return martial_art

func has_tactical_config() -> bool:
	return not tactical.is_empty() and tactical_range > 0 and not tactical_range_shape.is_empty()

static func _read_tactical_config(value: Variant, fallback_cost: int) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var range_shape = str(value.get("range_shape", ""))
	var attack_range = max(1, int(value.get("range", 1)))
	if range_shape.is_empty():
		return {}
	return {
		"damage_bonus": int(value.get("damage_bonus", 0)),
		"range": attack_range,
		"range_shape": range_shape,
		"mp_cost": max(0, int(value.get("mp_cost", fallback_cost))),
	}

static func _read_int_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var result: Array = []
	for v in value:
		result.append(max(0, int(v)))
	return result
