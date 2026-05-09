extends RefCounted

const BattleStateScript = preload("res://scripts/domain/battle_state.gd")

func run(assertions) -> void:
	var battle = BattleStateScript.new()
	battle.hero_id = "hero_yun"
	battle.enemy_id = "bandit_01"
	battle.hero_hp = 90
	battle.hero_max_hp = 120
	battle.enemy_hp = 34
	battle.enemy_max_hp = 60
	battle.round = 2
	battle.source_map_id = "mountain_pass"
	battle.source_object_id = "enemy_bandit_gate"
	battle.quest_id = "quest_mountain_trial"
	battle.reward_martial_art_id = "basic_sword"
	battle.proficiency_reward = 1
	battle.log.append("第1回合：云游少侠使出基础剑法。")

	var serialized = battle.to_dictionary()
	assertions.assert_eq(serialized.get("hero_id", ""), "hero_yun", "战斗状态应保存主角编号")
	assertions.assert_eq(serialized.get("enemy_hp", 0), 34, "战斗状态应保存敌人气血")
	assertions.assert_eq(serialized.get("round", 0), 2, "战斗状态应保存回合数")
	assertions.assert_eq(serialized.get("log", []).size(), 1, "战斗状态应保存日志")

	var restored = BattleStateScript.new()
	restored.from_dictionary(serialized)
	assertions.assert_eq(restored.hero_id, "hero_yun", "战斗状态应恢复主角编号")
	assertions.assert_eq(restored.enemy_id, "bandit_01", "战斗状态应恢复敌人编号")
	assertions.assert_eq(restored.hero_hp, 90, "战斗状态应恢复主角气血")
	assertions.assert_eq(restored.enemy_hp, 34, "战斗状态应恢复敌人气血")
	assertions.assert_eq(restored.source_object_id, "enemy_bandit_gate", "战斗状态应恢复来源对象")
	assertions.assert_eq(restored.reward_martial_art_id, "basic_sword", "战斗状态应恢复奖励武学")

	restored.finish(true)
	var result = restored.to_result_dictionary()
	assertions.assert_true(bool(result.get("victory", false)), "胜利结果应标记 victory")
	assertions.assert_eq(result.get("hero_hp", 0), 90, "战斗结果应带回主角气血")
	assertions.assert_eq(result.get("source_object_id", ""), "enemy_bandit_gate", "战斗结果应带回来源对象")
	assertions.assert_eq(result.get("quest_id", ""), "quest_mountain_trial", "战斗结果应带回任务编号")
	assertions.assert_eq(result.get("martial_art_id", ""), "basic_sword", "战斗结果应带回成长武学")
	assertions.assert_eq(result.get("proficiency_reward", 0), 1, "战斗结果应带回熟练度奖励")
