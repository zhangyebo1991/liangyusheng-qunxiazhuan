class_name CombatResult
extends RefCounted

var winner_id: String = ""
var loser_id: String = ""
var damage: int = 0
var rounds: int = 1
var log: Array[String] = []

func to_dictionary() -> Dictionary:
	return {
		"winner_id": winner_id,
		"loser_id": loser_id,
		"damage": damage,
		"rounds": rounds,
		"log": log.duplicate(),
	}
