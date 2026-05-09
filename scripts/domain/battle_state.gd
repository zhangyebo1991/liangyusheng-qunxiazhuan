class_name BattleState
extends RefCounted

var hero_id: String = ""
var enemy_id: String = ""
var hero_hp: int = 1
var hero_max_hp: int = 1
var enemy_hp: int = 1
var enemy_max_hp: int = 1
var round: int = 1
var is_finished := false
var victory := false
var log: Array[String] = []
var source_map_id: String = "mountain_pass"
var source_object_id: String = ""
var quest_id: String = ""
var reward_martial_art_id: String = ""
var proficiency_reward: int = 0

func append_log(message: String) -> void:
	if message.is_empty():
		return
	log.append(message)

func finish(is_victory: bool) -> void:
	is_finished = true
	victory = is_victory

func to_result_dictionary() -> Dictionary:
	return {
		"victory": victory,
		"hero_hp": max(0, hero_hp),
		"source_map_id": source_map_id,
		"source_object_id": source_object_id,
		"quest_id": quest_id,
		"martial_art_id": reward_martial_art_id,
		"proficiency_reward": max(0, proficiency_reward),
		"log": log.duplicate(),
	}

func to_dictionary() -> Dictionary:
	return {
		"hero_id": hero_id,
		"enemy_id": enemy_id,
		"hero_hp": hero_hp,
		"hero_max_hp": hero_max_hp,
		"enemy_hp": enemy_hp,
		"enemy_max_hp": enemy_max_hp,
		"round": round,
		"is_finished": is_finished,
		"victory": victory,
		"log": log.duplicate(),
		"source_map_id": source_map_id,
		"source_object_id": source_object_id,
		"quest_id": quest_id,
		"reward_martial_art_id": reward_martial_art_id,
		"proficiency_reward": proficiency_reward,
	}

func from_dictionary(data: Dictionary) -> void:
	hero_id = str(data.get("hero_id", ""))
	enemy_id = str(data.get("enemy_id", ""))
	hero_hp = int(data.get("hero_hp", 1))
	hero_max_hp = int(data.get("hero_max_hp", max(1, hero_hp)))
	enemy_hp = int(data.get("enemy_hp", 1))
	enemy_max_hp = int(data.get("enemy_max_hp", max(1, enemy_hp)))
	round = max(1, int(data.get("round", 1)))
	is_finished = bool(data.get("is_finished", false))
	victory = bool(data.get("victory", false))
	log = _to_string_array(data.get("log", []))
	source_map_id = str(data.get("source_map_id", "mountain_pass"))
	source_object_id = str(data.get("source_object_id", ""))
	quest_id = str(data.get("quest_id", ""))
	reward_martial_art_id = str(data.get("reward_martial_art_id", ""))
	proficiency_reward = max(0, int(data.get("proficiency_reward", 0)))

func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
