extends RefCounted

const TACTICAL_BATTLE_STATE_PATH := "res://scripts/domain/tactical_battle_state.gd"
const TacticalUnitStateScript = preload("res://scripts/domain/tactical_unit_state.gd")

func run(assertions) -> void:
	var TacticalBattleStateScript = load(TACTICAL_BATTLE_STATE_PATH)
	assertions.assert_true(TacticalBattleStateScript != null, "应存在战棋战斗状态脚本")
	if TacticalBattleStateScript == null:
		return

	var battle = TacticalBattleStateScript.new()
	battle.source_map_id = "mountain_pass"
	battle.source_object_id = "enemy_bandit_gate"
	battle.quest_id = "quest_mountain_trial"
	battle.reward_martial_art_id = "basic_sword"
	battle.proficiency_reward = 1
	battle.time_mode = "pause_on_action"
	battle.battlefield_width = 7
	battle.battlefield_height = 5

	# 新建战棋状态应有 terrain_grid 字段（默认空数组），便于战斗系统赋值
	assertions.assert_true(battle.terrain_grid != null, "新建战棋状态应有 terrain_grid 字段")
	assertions.assert_eq(battle.terrain_grid.size(), 0, "默认 terrain_grid 应为空数组")

	var hero = TacticalUnitStateScript.new()
	hero.from_dictionary({
		"unit_id": "hero",
		"actor_id": "hero_yun",
		"display_name": "云游少侠",
		"team": "player",
		"hp": 88,
		"max_hp": 120,
		"cell": {"q": 1, "r": 2},
	})
	battle.add_unit(hero)

	var enemy = TacticalUnitStateScript.new()
	enemy.from_dictionary({
		"unit_id": "bandit",
		"actor_id": "bandit_01",
		"display_name": "山道强人",
		"team": "enemy",
		"hp": 60,
		"max_hp": 60,
		"cell": {"q": 5, "r": 2},
	})
	battle.add_unit(enemy)

	assertions.assert_eq(battle.get_unit("hero").display_name, "云游少侠", "战棋战斗应能按单位编号取单位")
	assertions.assert_eq(battle.get_living_units_by_team("enemy").size(), 1, "战棋战斗应能读取存活敌人")
	assertions.assert_true(battle.has_living_team("player"), "玩家阵营有存活单位")
	assertions.assert_true(battle.has_living_team("enemy"), "敌方阵营有存活单位")

	battle.current_unit_id = "hero"
	battle.is_action_phase = true
	battle.append_log("云游少侠蓄势待发。")
	var serialized = battle.to_dictionary()
	assertions.assert_eq(serialized.get("current_unit_id", ""), "hero", "战棋战斗序列化应保存当前行动单位")
	assertions.assert_eq(serialized.get("units", []).size(), 2, "战棋战斗序列化应保存单位列表")
	assertions.assert_eq(serialized.get("log", []).size(), 1, "战棋战斗序列化应保存日志")

	battle.finish(true)
	var payload = battle.to_result_dictionary()
	assertions.assert_true(bool(payload.get("victory", false)), "战棋胜利结果应标记 victory")
	assertions.assert_eq(payload.get("hero_hp", 0), 88, "战棋结果应带回主角气血")
	assertions.assert_eq(payload.get("source_object_id", ""), "enemy_bandit_gate", "战棋结果应带回来源对象")
	assertions.assert_eq(payload.get("quest_id", ""), "quest_mountain_trial", "战棋结果应带回任务编号")
	assertions.assert_eq(payload.get("martial_art_id", ""), "basic_sword", "战棋结果应带回成长武学")
	assertions.assert_eq(payload.get("proficiency_reward", 0), 1, "战棋结果应带回熟练度奖励")
