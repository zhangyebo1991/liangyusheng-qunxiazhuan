extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const CombatSystemScript = preload("res://scripts/systems/combat_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()

	var system = CombatSystemScript.new()
	system.set_repository(repository)

	var state = GameStateScript.new()
	state.start_new_game()
	state.hero_hp = 100
	state.quest_system.start_quest("quest_mountain_trial")

	var battle = system.create_battle(state, {
		"enemy_id": "bandit_01",
		"source_map_id": "mountain_pass",
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
	}, repository)
	assertions.assert_eq(battle.hero_hp, 100, "创建战斗应读取当前主角气血")
	assertions.assert_eq(battle.enemy_hp, 60, "创建战斗应读取敌人气血")
	assertions.assert_eq(battle.source_object_id, "enemy_bandit_gate", "创建战斗应保存来源对象")

	system.resolve_player_attack(battle, state, "basic_sword")
	assertions.assert_eq(battle.enemy_hp, 34, "第一回合基础剑法应扣除敌人气血")
	assertions.assert_eq(battle.hero_hp, 96, "敌人未倒下时应反击并扣主角气血")
	assertions.assert_eq(state.hero_hp, 96, "战斗中主角气血应同步到 GameState")
	assertions.assert_eq(battle.round, 2, "完成双方行动后应进入下一回合")
	assertions.assert_true(not battle.is_finished, "敌人未倒下时战斗不应结束")

	system.resolve_player_attack(battle, state, "basic_sword")
	assertions.assert_eq(battle.enemy_hp, 8, "第二回合基础剑法应继续扣除敌人气血")
	assertions.assert_eq(battle.hero_hp, 92, "第二回合敌人应继续反击")
	assertions.assert_eq(battle.round, 3, "第二回合后应进入第三回合")

	system.resolve_player_attack(battle, state, "basic_sword")
	assertions.assert_eq(battle.enemy_hp, 0, "第三回合应击败敌人")
	assertions.assert_eq(battle.hero_hp, 92, "击败敌人后不应再触发反击")
	assertions.assert_true(battle.is_finished, "敌人倒下后战斗应结束")
	assertions.assert_true(battle.victory, "敌人倒下后应标记胜利")
	assertions.assert_eq(battle.reward_martial_art_id, "basic_sword", "胜利结果应记录成长武学")
	assertions.assert_eq(battle.proficiency_reward, 1, "胜利结果应记录熟练度奖励")

	state.apply_battle_result(battle.to_result_dictionary())
	assertions.assert_true(state.is_map_object_resolved("enemy_bandit_gate"), "胜利回流应清除敌人对象")
	assertions.assert_eq(state.quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "胜利回流应推进任务")
	assertions.assert_eq(state.get_martial_proficiency("basic_sword"), 1, "胜利回流应增加熟练度")

	var item_state = GameStateScript.new()
	item_state.start_new_game()
	item_state.hero_hp = 60
	var item_battle = system.create_battle(item_state, {"enemy_id": "bandit_01"}, repository)
	system.resolve_player_item(item_battle, item_state, "herb_small")
	assertions.assert_eq(item_state.party.get_item_count("herb_small"), 0, "战斗中用药应扣除背包")
	assertions.assert_eq(item_battle.hero_hp, 86, "小还丹先恢复 30 点气血，再承受 4 点反击")
	assertions.assert_eq(item_state.hero_hp, 86, "战斗中用药后 GameState 气血应同步")
	assertions.assert_eq(item_battle.round, 2, "成功用药并被反击后应进入下一回合")

	var full_hp_state = GameStateScript.new()
	full_hp_state.start_new_game()
	var full_hp_battle = system.create_battle(full_hp_state, {"enemy_id": "bandit_01"}, repository)
	system.resolve_player_item(full_hp_battle, full_hp_state, "herb_small")
	assertions.assert_eq(full_hp_state.party.get_item_count("herb_small"), 1, "气血已满时战斗中用药不应扣物品")
	assertions.assert_eq(full_hp_battle.round, 1, "气血已满用药失败不应消耗回合")
	assertions.assert_eq(full_hp_battle.hero_hp, 120, "气血已满用药失败不应触发反击")

	var missing_item_state = GameStateScript.new()
	missing_item_state.start_new_game()
	missing_item_state.hero_hp = 60
	missing_item_state.party.remove_item("herb_small", 1)
	var missing_item_battle = system.create_battle(missing_item_state, {"enemy_id": "bandit_01"}, repository)
	system.resolve_player_item(missing_item_battle, missing_item_state, "herb_small")
	assertions.assert_eq(missing_item_battle.round, 1, "小还丹不足时不应消耗回合")
	assertions.assert_eq(missing_item_battle.hero_hp, 60, "小还丹不足时不应触发反击")
	assertions.assert_true(missing_item_battle.log.has("背包中没有此物。"), "小还丹不足时应记录失败原因")

	var retreat_state = GameStateScript.new()
	retreat_state.start_new_game()
	retreat_state.hero_hp = 77
	retreat_state.quest_system.start_quest("quest_mountain_trial")
	var retreat_battle = system.create_battle(retreat_state, {
		"enemy_id": "bandit_01",
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
	}, repository)
	system.resolve_retreat(retreat_battle)
	retreat_state.apply_battle_result(retreat_battle.to_result_dictionary())
	assertions.assert_true(retreat_battle.is_finished, "暂退应结束战斗")
	assertions.assert_true(not retreat_battle.victory, "暂退不应标记胜利")
	assertions.assert_true(not retreat_state.is_map_object_resolved("enemy_bandit_gate"), "暂退不应清除敌人对象")
	assertions.assert_eq(retreat_state.quest_system.get_status("quest_mountain_trial"), "active", "暂退不应推进任务")

	var defeat_state = GameStateScript.new()
	defeat_state.start_new_game()
	defeat_state.hero_hp = 3
	defeat_state.quest_system.start_quest("quest_mountain_trial")
	var defeat_battle = system.create_battle(defeat_state, {
		"enemy_id": "bandit_01",
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
	}, repository)
	system.resolve_player_attack(defeat_battle, defeat_state, "basic_sword")
	assertions.assert_true(defeat_battle.is_finished, "主角气血归零后战斗应结束")
	assertions.assert_true(not defeat_battle.victory, "主角气血归零后应标记失败")
	defeat_state.apply_battle_result(defeat_battle.to_result_dictionary())
	assertions.assert_eq(defeat_state.hero_hp, 1, "失败回流应把主角气血钳制到安全值")
	assertions.assert_true(not defeat_state.is_map_object_resolved("enemy_bandit_gate"), "失败不应清除敌人对象")

	state.free()
	item_state.free()
	full_hp_state.free()
	missing_item_state.free()
	retreat_state.free()
	defeat_state.free()
	repository.free()
