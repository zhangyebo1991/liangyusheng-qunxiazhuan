class_name TacticalUnitState
extends RefCounted

const TEAM_PLAYER := "player"
const TEAM_ENEMY := "enemy"

var unit_id: String = ""
var actor_id: String = ""
var display_name: String = ""
var team: String = TEAM_ENEMY
var hp: int = 1
var max_hp: int = 1
var mp: int = 0
var max_mp: int = 0
var attack: int = 1
var defense: int = 0
var move_range: int = 3
var attack_range: int = 1
var charge_speed: int = 200
var charge: int = 0
var cell: Dictionary = {"q": 0, "r": 0}
var martial_art_ids: Array[String] = []

func is_alive() -> bool:
	return hp > 0

func reset_charge() -> void:
	charge = 0

func to_dictionary() -> Dictionary:
	return {
		"unit_id": unit_id,
		"actor_id": actor_id,
		"display_name": display_name,
		"team": team,
		"hp": hp,
		"max_hp": max_hp,
		"mp": mp,
		"max_mp": max_mp,
		"attack": attack,
		"defense": defense,
		"move_range": move_range,
		"attack_range": attack_range,
		"charge_speed": charge_speed,
		"charge": charge,
		"cell": cell.duplicate(true),
		"martial_art_ids": martial_art_ids.duplicate(),
	}

func from_dictionary(data: Dictionary) -> void:
	unit_id = str(data.get("unit_id", ""))
	actor_id = str(data.get("actor_id", ""))
	display_name = str(data.get("display_name", actor_id))
	team = str(data.get("team", TEAM_ENEMY))
	if team.is_empty():
		team = TEAM_ENEMY
	max_hp = max(1, int(data.get("max_hp", data.get("hp", 1))))
	hp = clamp(int(data.get("hp", max_hp)), 0, max_hp)
	max_mp = max(0, int(data.get("max_mp", 0)))
	mp = clamp(int(data.get("mp", max_mp)), 0, max_mp)
	attack = max(1, int(data.get("attack", 1)))
	defense = max(0, int(data.get("defense", 0)))
	move_range = max(0, int(data.get("move_range", 3)))
	attack_range = max(1, int(data.get("attack_range", 1)))
	charge_speed = max(1, int(data.get("charge_speed", 200)))
	charge = max(0, int(data.get("charge", 0)))
	cell = _read_cell(data.get("cell", data.get("start_cell", {})))
	martial_art_ids = _to_string_array(data.get("martial_art_ids", []))

func _read_cell(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {"q": 0, "r": 0}
	return {
		"q": int(value.get("q", 0)),
		"r": int(value.get("r", 0)),
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
