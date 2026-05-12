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
var attack: int = 1
var defense: int = 0
var move_range: int = 3
var attack_range: int = 1
var charge_speed: int = 200
var charge: int = 0
var cell: Dictionary = {"q": 0, "r": 0}

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
		"attack": attack,
		"defense": defense,
		"move_range": move_range,
		"attack_range": attack_range,
		"charge_speed": charge_speed,
		"charge": charge,
		"cell": cell.duplicate(true),
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
	attack = max(1, int(data.get("attack", 1)))
	defense = max(0, int(data.get("defense", 0)))
	move_range = max(0, int(data.get("move_range", 3)))
	attack_range = max(1, int(data.get("attack_range", 1)))
	charge_speed = max(1, int(data.get("charge_speed", 200)))
	charge = max(0, int(data.get("charge", 0)))
	cell = _read_cell(data.get("cell", data.get("start_cell", {})))

func _read_cell(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {"q": 0, "r": 0}
	return {
		"q": int(value.get("q", 0)),
		"r": int(value.get("r", 0)),
	}
