class_name ActorState
extends RefCounted

var id: String = ""
var name: String = ""
var level: int = 1
var hp: int = 1
var max_hp: int = 1
var max_mp: int = 0
var attack: int = 1
var defense: int = 0
var move_range: int = 3
var attack_range: int = 1
var charge_speed: int = 200
var martial_arts: Array[String] = []
var sprite_tile_id: String = ""

static func from_dictionary(data: Dictionary):
	var actor = new()
	actor.id = str(data.get("id", ""))
	actor.name = str(data.get("name", ""))
	actor.level = int(data.get("level", 1))
	actor.hp = int(data.get("hp", 1))
	actor.max_hp = int(data.get("max_hp", actor.hp))
	actor.max_mp = max(0, int(data.get("max_mp", 0)))
	actor.attack = int(data.get("attack", 1))
	actor.defense = int(data.get("defense", 0))
	actor.move_range = max(0, int(data.get("move_range", 3)))
	actor.attack_range = max(1, int(data.get("attack_range", 1)))
	actor.charge_speed = max(1, int(data.get("charge_speed", 200)))
	actor.martial_arts = _to_string_array(data.get("martial_arts", []))
	actor.sprite_tile_id = str(data.get("sprite_tile_id", ""))
	return actor

func is_alive() -> bool:
	return hp > 0

func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"level": level,
		"hp": hp,
		"max_hp": max_hp,
		"max_mp": max_mp,
		"attack": attack,
		"defense": defense,
		"move_range": move_range,
		"attack_range": attack_range,
		"charge_speed": charge_speed,
		"martial_arts": martial_arts.duplicate(),
		"sprite_tile_id": sprite_tile_id,
	}

static func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
