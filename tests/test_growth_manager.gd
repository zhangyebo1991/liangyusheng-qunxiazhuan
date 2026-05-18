extends RefCounted

const GrowthManagerScript = preload("res://scripts/systems/growth_manager.gd")

func run(assertions) -> void:
	var manager = GrowthManagerScript.new()
	assertions.assert_true(manager.skill_trees != null, "skill_trees 应初始化")
	assertions.assert_true(manager.inner_arts != null, "inner_arts 应初始化")
	assertions.assert_true(manager.insights != null, "insights 应初始化")
	assertions.assert_eq(manager.proficiency_points, 0, "初始熟练点应为 0")

	var battle_data = {"enemies": 3, "difficulty": 1}
	manager.on_battle_end(battle_data)
	assertions.assert_true(manager.proficiency_points > 0, "战斗后应获得熟练点")
	assertions.assert_eq(manager.proficiency_points, 3, "3 敌人 * 难度 1 = 3 熟练点")

	var manager2 = GrowthManagerScript.new()
	manager2.on_battle_end({"enemies": 2, "difficulty": 5})
	assertions.assert_eq(manager2.proficiency_points, 10, "2 敌人 * 难度 5 = 10 熟练点")
