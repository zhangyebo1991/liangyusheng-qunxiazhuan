extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const TacticalCombatSystemScript = preload("res://scripts/systems/tactical_combat_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var state = GameStateScript.new()
	state.start_new_game()
	state.party.add_member("qingshanke")
	state.party.set_member_status("qingshanke", {"hp": 160, "mp": 20})
	state.party.add_item("iron_sword", 1)
	state.party.set_equipment("hero_yun", "weapon", "iron_sword")

	var system = TacticalCombatSystemScript.new()
	system.set_repository(repository)
	var battle = system.create_battle(state, _party_context(), repository)
	var hero = battle.get_unit("hero_yun")
	var ally = battle.get_unit("qingshanke")

	assertions.assert_true(hero != null, "主角应以 actor_id 作为玩家单位入场")
	assertions.assert_true(ally != null, "青衫客应作为队友单位入场")
	if hero == null or ally == null:
		repository.free()
		state.free()
		return
	assertions.assert_eq(hero.team, "player", "主角应属于玩家队伍")
	assertions.assert_eq(ally.team, "player", "队友应属于玩家队伍")
	assertions.assert_eq(hero.cell.get("q", -1), 1, "主角应使用第一个玩家起始格")
	assertions.assert_eq(ally.cell.get("q", -1), 1, "队友应使用第二个玩家起始格")
	assertions.assert_eq(hero.attack, 22, "主角攻击应包含铁剑加成")
	assertions.assert_eq(ally.hp, 160, "队友应读取成员当前 HP")
	assertions.assert_true(battle.has_living_team("player"), "玩家队伍应有存活单位")

	battle.get_unit("hero_yun").hp = 88
	battle.get_unit("hero_yun").mp = 6
	battle.get_unit("qingshanke").hp = 120
	battle.get_unit("qingshanke").mp = 3
	var payload = battle.to_result_dictionary()
	assertions.assert_eq(payload.get("party_member_results", {}).get("hero_yun", {}).get("hp", 0), 88, "结果应包含主角 HP")
	assertions.assert_eq(payload.get("party_member_results", {}).get("qingshanke", {}).get("mp", 0), 3, "结果应包含队友 MP")

	repository.free()
	state.free()

func _party_context() -> Dictionary:
	return {
		"source_map_id": "mountain_pass",
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
		"battlefield": {"width": 8, "height": 6},
		"player_start_cells": [{"q": 1, "r": 2}, {"q": 1, "r": 3}],
		"units": [
			{"unit_id": "bandit", "actor_id": "bandit_01", "team": "enemy", "start_cell": {"q": 5, "r": 2}, "max_mp": 0}
		]
	}