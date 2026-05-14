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
	assertions.assert_true(payload.get("participating_party_members", []).has("hero_yun"), "结果应包含参战主角")
	assertions.assert_eq(payload.get("victory_rewards", {}).get("exp", 0), 35, "结果应包含固定胜利经验")

	var reward_state = GameStateScript.new()
	reward_state.start_new_game()
	reward_state.party.add_member("qingshanke")
	reward_state.initialize_party_member_status("qingshanke")
	var reward_battle = system.create_battle(reward_state, _party_context(), repository)
	reward_battle.finish(true)
	reward_state.apply_battle_result(reward_battle.to_result_dictionary())
	assertions.assert_eq(reward_state.party.get_member_status("hero_yun").get("level", 0), 2, "战斗经验应让主角升级")
	assertions.assert_eq(reward_state.party.get_member_status("qingshanke").get("level", 0), 2, "战斗经验应让参战队友升级")
	assertions.assert_eq(reward_state.hero_hp, 128, "战斗经验升级后主角旧 HP 字段应同步")
	assertions.assert_eq(reward_state.party.coins, GameStateScript.STARTING_COINS + 12, "战斗胜利应发放铜钱")
	assertions.assert_eq(reward_state.party.get_item_count("herb_small"), 2, "战斗胜利应发放物品")
	assertions.assert_true(not reward_state.last_reward_result.is_empty(), "GameState 应保存最近奖励结果供 UI 展示")

	var fail_state = GameStateScript.new()
	fail_state.start_new_game()
	var fail_battle = system.create_battle(fail_state, _party_context(), repository)
	fail_battle.finish(false)
	fail_state.apply_battle_result(fail_battle.to_result_dictionary())
	assertions.assert_eq(fail_state.party.get_member_status("hero_yun").get("level", 0), 1, "战斗失败不应发经验")
	assertions.assert_eq(fail_state.party.coins, GameStateScript.STARTING_COINS, "战斗失败不应发铜钱")
	assertions.assert_true(fail_state.last_reward_result.is_empty(), "战斗失败不应保留奖励结果")

	repository.free()
	reward_state.free()
	fail_state.free()
	state.free()

func _party_context() -> Dictionary:
	return {
		"source_map_id": "mountain_pass",
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
		"battlefield": {"width": 8, "height": 6},
		"player_start_cells": [{"q": 1, "r": 2}, {"q": 1, "r": 3}],
		"victory_rewards": {
			"exp": 35,
			"coins": 12,
			"items": [{"item_id": "herb_small", "amount": 1}]
		},
		"units": [
			{"unit_id": "bandit", "actor_id": "bandit_01", "team": "enemy", "start_cell": {"q": 5, "r": 2}, "max_mp": 0}
		]
	}