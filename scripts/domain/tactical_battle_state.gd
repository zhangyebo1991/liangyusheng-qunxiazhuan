class_name TacticalBattleState
extends RefCounted

const CHARGE_LIMIT := 1000
const TEAM_PLAYER := "player"
const TEAM_ENEMY := "enemy"
const TIME_MODE_PAUSE_ON_ACTION := "pause_on_action"

var battlefield_width: int = 7
var battlefield_height: int = 5
var time_mode: String = TIME_MODE_PAUSE_ON_ACTION
# 战场地形矩阵：6 行 × 8 列字符串地形编号（grass / water / tree / bridge ……），
# 由 maps.json 战斗触发节点提供，缺省时由 tactical_combat_system 兜底全 grass。
var terrain_grid: Array = []
var units: Array = []
var current_unit_id: String = ""
var is_action_phase := false
var is_finished := false
var victory := false
var log: Array[String] = []
var source_map_id: String = "mountain_pass"
var source_object_id: String = ""
var quest_id: String = ""
var reward_martial_art_id: String = "basic_sword"
var proficiency_reward: int = 1
var victory_rewards: Dictionary = {}

func add_unit(unit) -> void:
	if unit == null:
		return
	units.append(unit)

func get_unit(unit_id: String):
	for unit in units:
		if unit.unit_id == unit_id:
			return unit
	return null

func get_living_units_by_team(team: String) -> Array:
	var result: Array = []
	for unit in units:
		if unit.team == team and unit.is_alive():
			result.append(unit)
	return result

func has_living_team(team: String) -> bool:
	return not get_living_units_by_team(team).is_empty()

func append_log(message: String) -> void:
	if message.is_empty():
		return
	log.append(message)

func finish(is_victory: bool) -> void:
	is_finished = true
	victory = is_victory
	is_action_phase = false
	current_unit_id = ""

func to_result_dictionary() -> Dictionary:
	var hero_hp := 1
	var hero = _first_player_unit()
	if hero != null:
		hero_hp = max(0, hero.hp)
	return {
		"victory": victory,
		"hero_hp": hero_hp,
		"hero_final_mp": _get_hero_final_mp(),
		"party_member_results": _party_member_results(),
		"participating_party_members": _participating_party_members(),
		"source_map_id": source_map_id,
		"source_object_id": source_object_id,
		"quest_id": quest_id,
		"victory_rewards": victory_rewards.duplicate(true),
		"martial_art_id": reward_martial_art_id,
		"proficiency_reward": max(0, proficiency_reward),
		"log": log.duplicate(),
	}

func _get_hero_final_mp() -> int:
	for unit in units:
		if unit.team == TEAM_PLAYER and unit.actor_id == "hero_yun":
			return int(unit.mp)
	return -1

func _party_member_results() -> Dictionary:
	var result: Dictionary = {}
	for unit in units:
		if unit.team != TEAM_PLAYER or unit.actor_id.is_empty():
			continue
		result[unit.actor_id] = {"hp": max(0, int(unit.hp)), "mp": max(0, int(unit.mp))}
	return result

func _participating_party_members() -> Array:
	var result: Array = []
	for unit in units:
		if unit.team != TEAM_PLAYER or unit.actor_id.is_empty():
			continue
		if not result.has(unit.actor_id):
			result.append(unit.actor_id)
	return result

func to_dictionary() -> Dictionary:
	var serialized_units: Array = []
	for unit in units:
		serialized_units.append(unit.to_dictionary())
	return {
		"battlefield_width": battlefield_width,
		"battlefield_height": battlefield_height,
		"time_mode": time_mode,
		"terrain_grid": terrain_grid.duplicate(true),
		"units": serialized_units,
		"current_unit_id": current_unit_id,
		"is_action_phase": is_action_phase,
		"is_finished": is_finished,
		"victory": victory,
		"log": log.duplicate(),
		"source_map_id": source_map_id,
		"source_object_id": source_object_id,
		"quest_id": quest_id,
		"victory_rewards": victory_rewards.duplicate(true),
		"reward_martial_art_id": reward_martial_art_id,
		"proficiency_reward": proficiency_reward,
	}

func _first_player_unit():
	for unit in units:
		if unit.team == TEAM_PLAYER:
			return unit
	return null
