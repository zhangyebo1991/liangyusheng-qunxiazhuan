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
	state.party.set_formation_order(["hero_yun", "qingshanke"])
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

	var limited_battle = system.create_battle(state, _party_context_with_deploy(1, [{"q": 2, "r": 2}, {"q": 2, "r": 3}]), repository)
	assertions.assert_true(limited_battle.get_unit("hero_yun") != null, "出战上限为 1 时主角仍应入场")
	assertions.assert_true(limited_battle.get_unit("qingshanke") == null, "出战上限为 1 时队友不应入场")

	var short_cell_battle = system.create_battle(state, _party_context_with_deploy(2, [{"q": 3, "r": 2}]), repository)
	assertions.assert_true(short_cell_battle.get_unit("hero_yun") != null, "起始格不足时主角应优先入场")
	assertions.assert_true(short_cell_battle.get_unit("qingshanke") == null, "起始格不足时队友不应入场")
	assertions.assert_true(_log_has(short_cell_battle, "青衫客无法入场：本场出战位置不足。"), "起始格不足时应写入中文日志")

	var legacy_battle = system.create_battle(state, _legacy_party_context(), repository)
	assertions.assert_true(legacy_battle.get_unit("qingshanke") != null, "旧 player_start_cells 配置仍应支持队友入场")
	assertions.assert_eq(legacy_battle.get_unit("qingshanke").cell.get("r", -1), 3, "旧配置应保留第二个玩家起始格")

	var gate = _map_object(repository, "mountain_pass", "enemy_bandit_gate")
	var gate_deploy = gate.get("player_deploy", {})
	assertions.assert_true(typeof(gate_deploy) == TYPE_DICTIONARY, "山道强人战应配置玩家出战位")
	assertions.assert_true(int(gate_deploy.get("max_members", 0)) >= 2, "山道强人战至少允许 2 名玩家单位出战")
	assertions.assert_true(gate_deploy.get("start_cells", []).size() >= 2, "山道强人战至少应配置 2 个玩家起始格")
	var gate_battle = system.create_battle(state, gate, repository)
	assertions.assert_true(gate_battle.get_unit("hero_yun") != null, "真实山道强人战应生成主角")
	assertions.assert_true(gate_battle.get_unit("qingshanke") != null, "真实山道强人战应生成已入队的青衫客")

	var hard_dummy_context = _dialogue_option_battle_context(repository, "training_dummy_intro", "training_dummy_hard")
	assertions.assert_eq(hard_dummy_context.get("battle_mode", ""), "tactical", "高档木桩应提供战棋上下文")
	var hard_dummy_state = GameStateScript.new()
	hard_dummy_state.start_new_game()
	var hard_dummy_battle = system.create_battle(hard_dummy_state, hard_dummy_context, repository)
	var hard_dummy = hard_dummy_battle.get_unit("training_dummy_hard")
	assertions.assert_true(hard_dummy != null, "高档木桩战应生成木桩敌人")
	assertions.assert_eq(hard_dummy_battle.proficiency_reward, 0, "木桩训练胜利不应发放武学熟练度")
	if hard_dummy != null:
		assertions.assert_true(hard_dummy.attack >= 900, "高档木桩攻击应足以秒杀测试")
		system.attack_unit(hard_dummy_battle, "training_dummy_hard", "hero_yun")
		assertions.assert_true(hard_dummy_battle.is_finished, "高档木桩击倒主角后战斗应失败结束")
		hard_dummy_state.apply_battle_result(hard_dummy_battle.to_result_dictionary())
		assertions.assert_eq(hard_dummy_state.party.get_member_status("hero_yun").get("hp", 0), 1, "高档木桩击倒主角后回到队伍状态应保留 1 点气血")

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

	var loot_state = GameStateScript.new()
	loot_state.start_new_game()
	var loot_battle = system.create_battle(loot_state, _loot_context(), repository)
	loot_battle.finish(true)
	loot_state.apply_battle_result(loot_battle.to_result_dictionary())
	assertions.assert_eq(loot_state.party.coins, GameStateScript.STARTING_COINS + 13, "固定铜钱和随机铜钱应合并发放")
	assertions.assert_eq(loot_state.party.get_item_count("herb_focus"), 1, "随机消耗品应进入背包")
	assertions.assert_eq(loot_state.party.get_item_count("iron_sword"), 1, "随机装备应进入背包")
	assertions.assert_eq(int(loot_state.last_reward_result.get("coins", 0)), 13, "奖励摘要应记录总铜钱")
	var loot_items = loot_state.last_reward_result.get("items", [])
	assertions.assert_eq(loot_items.size(), 2, "奖励摘要应记录随机掉落物品")
	if not loot_items.is_empty():
		assertions.assert_eq(loot_items[0].get("source", ""), "loot", "随机物品来源应标记为 loot")
	assertions.assert_true(bool(loot_state.last_reward_result.get("loot", {}).get("rolled", false)), "奖励摘要应记录本场已掷掉落表")

	var missing_loot_state = GameStateScript.new()
	missing_loot_state.start_new_game()
	var missing_loot_battle = system.create_battle(missing_loot_state, _missing_loot_context(), repository)
	missing_loot_battle.finish(true)
	missing_loot_state.apply_battle_result(missing_loot_battle.to_result_dictionary())
	assertions.assert_eq(missing_loot_state.party.get_item_count("missing_item"), 0, "缺失物品资料不应进入背包")
	assertions.assert_true(missing_loot_state.last_reward_result.get("loot", {}).get("errors", []).size() >= 1, "缺失物品资料应记录错误")

	var failed_loot_state = GameStateScript.new()
	failed_loot_state.start_new_game()
	var failed_loot_battle = system.create_battle(failed_loot_state, _loot_context(), repository)
	failed_loot_battle.finish(false)
	failed_loot_state.apply_battle_result(failed_loot_battle.to_result_dictionary())
	assertions.assert_eq(failed_loot_state.party.coins, GameStateScript.STARTING_COINS, "战斗失败不应掷掉落表")
	assertions.assert_eq(failed_loot_state.party.get_item_count("herb_focus"), 0, "战斗失败不应发随机物品")

	var fail_state = GameStateScript.new()
	fail_state.start_new_game()
	var fail_battle = system.create_battle(fail_state, _party_context(), repository)
	fail_battle.finish(false)
	fail_state.apply_battle_result(fail_battle.to_result_dictionary())
	assertions.assert_eq(fail_state.party.get_member_status("hero_yun").get("level", 0), 1, "战斗失败不应发经验")
	assertions.assert_eq(fail_state.party.coins, GameStateScript.STARTING_COINS, "战斗失败不应发铜钱")
	assertions.assert_true(fail_state.last_reward_result.is_empty(), "战斗失败不应保留奖励结果")

	var downed_victory_state = _state_with_ally()
	downed_victory_state.apply_battle_result(_downed_result(true))
	assertions.assert_eq(downed_victory_state.party.get_member_status("hero_yun").get("hp", 0), 1, "胜利后倒下主角成员状态应保留 1 点气血")
	assertions.assert_eq(downed_victory_state.party.get_member_status("qingshanke").get("hp", 0), 1, "胜利后倒下队友应保留 1 点气血")
	assertions.assert_eq(downed_victory_state.hero_hp, 1, "胜利后主角旧 HP 字段应同步为 1")
	var restored_down = GameStateScript.new()
	restored_down.from_dictionary(downed_victory_state.to_dictionary())
	assertions.assert_eq(restored_down.party.get_member_status("qingshanke").get("hp", 0), 1, "倒下队友 1 血状态应可存档恢复")

	var downed_failure_state = _state_with_ally()
	downed_failure_state.apply_battle_result(_downed_result(false))
	assertions.assert_eq(downed_failure_state.party.get_member_status("hero_yun").get("hp", 0), 1, "失败后倒下主角成员状态应保留 1 点气血")
	assertions.assert_eq(downed_failure_state.party.get_member_status("qingshanke").get("hp", 0), 1, "失败后倒下队友应保留 1 点气血")

	repository.free()
	hard_dummy_state.free()
	reward_state.free()
	loot_state.free()
	missing_loot_state.free()
	failed_loot_state.free()
	fail_state.free()
	downed_victory_state.free()
	restored_down.free()
	downed_failure_state.free()
	state.free()

func _party_context() -> Dictionary:
	return _party_context_with_deploy(2, [{"q": 1, "r": 2}, {"q": 1, "r": 3}])

func _party_context_with_deploy(max_members: int, start_cells: Array) -> Dictionary:
	return {
		"source_map_id": "mountain_pass",
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
		"battlefield": {"width": 8, "height": 6},
		"player_deploy": {"max_members": max_members, "start_cells": start_cells},
		"victory_rewards": {
			"exp": 35,
			"coins": 12,
			"items": [{"item_id": "herb_small", "amount": 1}]
		},
		"units": [
			{"unit_id": "bandit", "actor_id": "bandit_01", "team": "enemy", "start_cell": {"q": 5, "r": 2}, "max_mp": 0}
		]
	}

func _loot_context() -> Dictionary:
	return {
		"source_map_id": "mountain_pass",
		"source_object_id": "enemy_roaming_bandit",
		"battlefield": {"width": 8, "height": 6},
		"player_deploy": {"max_members": 1, "start_cells": [{"q": 1, "r": 2}]},
		"victory_rewards": {
			"exp": 0,
			"coins": 5,
			"loot_table": {
				"rolls": 1,
				"entries": [
					{"type": "coins", "chance": 1.0, "amount": 8},
					{"type": "item", "item_id": "herb_focus", "chance": 1.0, "amount": 1},
					{"type": "item", "item_id": "iron_sword", "chance": 1.0, "amount": 1}
				]
			}
		},
		"units": [
			{"unit_id": "roaming_bandit", "actor_id": "bandit_lackey_01", "team": "enemy", "start_cell": {"q": 5, "r": 2}, "move_range": 3, "attack_range": 1, "max_mp": 0}
		]
	}

func _missing_loot_context() -> Dictionary:
	var context = _loot_context()
	context["victory_rewards"] = {
		"exp": 0,
		"coins": 0,
		"loot_table": {
			"rolls": 1,
			"entries": [
				{"type": "item", "item_id": "missing_item", "chance": 1.0, "amount": 1}
			]
		}
	}
	return context

func _legacy_party_context() -> Dictionary:
	var context = _party_context_with_deploy(2, [{"q": 1, "r": 2}, {"q": 1, "r": 3}])
	context.erase("player_deploy")
	context["player_start_cells"] = [{"q": 1, "r": 2}, {"q": 1, "r": 3}]
	return context

func _log_has(battle, expected: String) -> bool:
	for line in battle.log:
		if str(line) == expected:
			return true
	return false

func _map_object(repository, map_id: String, object_id: String) -> Dictionary:
	var map_data = repository.get_map(map_id)
	var objects = map_data.get("objects", [])
	if typeof(objects) != TYPE_ARRAY:
		return {}
	for object in objects:
		if typeof(object) == TYPE_DICTIONARY and str(object.get("id", "")) == object_id:
			return object
	return {}

func _dialogue_option_battle_context(repository, dialogue_id: String, option_id: String) -> Dictionary:
	var dialogue = repository.get_dialogue(dialogue_id)
	var options = dialogue.get("options", [])
	if typeof(options) != TYPE_ARRAY:
		return {}
	for option in options:
		if typeof(option) != TYPE_DICTIONARY or str(option.get("id", "")) != option_id:
			continue
		var context = option.get("battle_context", {})
		return context if typeof(context) == TYPE_DICTIONARY else {}
	return {}

func _state_with_ally():
	var state = GameStateScript.new()
	state.start_new_game()
	state.party.add_member("qingshanke")
	state.party.set_member_status("qingshanke", {"hp": 120, "mp": 8})
	return state

func _downed_result(is_victory: bool) -> Dictionary:
	return {
		"victory": is_victory,
		"hero_hp": 0,
		"hero_final_mp": 3,
		"party_member_results": {
			"hero_yun": {"hp": 0, "mp": 3},
			"qingshanke": {"hp": 0, "mp": 1}
		},
		"participating_party_members": ["hero_yun", "qingshanke"]
	}
