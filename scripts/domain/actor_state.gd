class_name ActorState
extends RefCounted

var id: String = ""
var name: String = ""
var level: int = 1
var hp: int = 1
var max_hp: int = 1
var attack: int = 1
var defense: int = 0
var martial_arts: Array[String] = []

static func from_dictionary(data: Dictionary):
	var actor = new()
	actor.id = str(data.get("id", ""))
	actor.name = str(data.get("name", ""))
	actor.level = int(data.get("level", 1))
	actor.hp = int(data.get("hp", 1))
	actor.max_hp = int(data.get("max_hp", actor.hp))
	actor.attack = int(data.get("attack", 1))
	actor.defense = int(data.get("defense", 0))
	actor.martial_arts = _to_string_array(data.get("martial_arts", []))
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
		"attack": attack,
		"defense": defense,
		"martial_arts": martial_arts.duplicate(),
	}

static func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
