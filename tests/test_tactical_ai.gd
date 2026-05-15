extends RefCounted

class MockRepository extends RefCounted:
	var martial_arts: Dictionary = {}

	func get_martial_art(id: String) -> Dictionary:
		return martial_arts.get(id, {})

	func add_martial_art(id: String, data: Dictionary) -> void:
		martial_arts[id] = data

func run(assertions) -> void:
	var ai = TacticalAI.new()
	var battle = TacticalBattleState.new()
	var mock_repo = MockRepository.new()
	ai.set_repository(mock_repo)

	mock_repo.add_martial_art("basic_sword", {
		"id": "basic_sword",
		"name": "基础剑法",
		"tactical": {
			"damage_bonus": 6,
			"range": 1,
			"range_shape": "diamond",
			"mp_cost": 3
		}
	})
	mock_repo.add_martial_art("straight_sword_thrust", {
		"id": "straight_sword_thrust",
		"name": "穿云刺",
		"tactical": {
			"damage_bonus": 4,
			"range": 2,
			"range_shape": "line",
			"mp_cost": 5
		}
	})

	# get_available_skills 测试
	var unit = TacticalUnitState.new()
	var skills_list: Array[String] = ["basic_sword", "straight_sword_thrust"]
	unit.martial_art_ids = skills_list

	unit.mp = 10
	var skills = ai.get_available_skills(unit)
	assertions.assert_eq(skills.size(), 2, "MP 充足时应返回所有技能")

	unit.mp = 4
	skills = ai.get_available_skills(unit)
	assertions.assert_eq(skills.size(), 1, "MP 不足时应过滤高消耗技能")
	assertions.assert_true(skills.has("basic_sword"), "应保留低消耗技能")

	var empty_skills: Array[String] = []
	unit.martial_art_ids = empty_skills
	unit.mp = 10
	skills = ai.get_available_skills(unit)
	assertions.assert_eq(skills.size(), 0, "无技能时应返回空数组")

	# count_targets_from_position 测试 - diamond
	battle = TacticalBattleState.new()
	battle.battlefield_width = 5
	battle.battlefield_height = 5
	var enemy1 = TacticalUnitState.new()
	enemy1.unit_id = "enemy1"
	enemy1.team = "enemy"
	enemy1.cell = {"q": 3, "r": 2}
	enemy1.hp = 10
	var enemy2 = TacticalUnitState.new()
	enemy2.unit_id = "enemy2"
	enemy2.team = "enemy"
	enemy2.cell = {"q": 2, "r": 3}
	enemy2.hp = 10
	battle.add_unit(enemy1)
	battle.add_unit(enemy2)
	var enemies = battle.get_living_units_by_team("enemy")
	var count = ai.count_targets_from_position("basic_sword", Vector2i(2, 2), enemies, battle)
	assertions.assert_eq(count, 2, "应计算范围内敌人数量")

	# count_targets_from_position 测试 - line
	battle = TacticalBattleState.new()
	battle.battlefield_width = 5
	battle.battlefield_height = 5
	enemy1 = TacticalUnitState.new()
	enemy1.unit_id = "enemy1"
	enemy1.team = "enemy"
	enemy1.cell = {"q": 2, "r": 4}
	enemy1.hp = 10
	enemy2 = TacticalUnitState.new()
	enemy2.unit_id = "enemy2"
	enemy2.team = "enemy"
	enemy2.cell = {"q": 2, "r": 3}
	enemy2.hp = 10
	battle.add_unit(enemy1)
	battle.add_unit(enemy2)
	enemies = battle.get_living_units_by_team("enemy")
	count = ai.count_targets_from_position("straight_sword_thrust", Vector2i(2, 2), enemies, battle)
	assertions.assert_eq(count, 2, "直线范围应计算同列敌人")

	# evaluate 测试 - 选择能打到最多敌人的技能
	battle = TacticalBattleState.new()
	battle.battlefield_width = 5
	battle.battlefield_height = 5
	var player = TacticalUnitState.new()
	player.unit_id = "player"
	player.team = "player"
	player.cell = {"q": 2, "r": 2}
	player.hp = 100
	player.mp = 10
	player.attack = 10
	player.move_range = 1
	player.attack_range = 1
	var player_skills: Array[String] = ["basic_sword"]
	player.martial_art_ids = player_skills
	battle.add_unit(player)
	enemy1 = TacticalUnitState.new()
	enemy1.unit_id = "enemy1"
	enemy1.team = "enemy"
	enemy1.cell = {"q": 3, "r": 2}
	enemy1.hp = 10
	enemy2 = TacticalUnitState.new()
	enemy2.unit_id = "enemy2"
	enemy2.team = "enemy"
	enemy2.cell = {"q": 2, "r": 3}
	enemy2.hp = 10
	battle.add_unit(enemy1)
	battle.add_unit(enemy2)
	var result = ai.evaluate(player, battle)
	assertions.assert_true(result.get("success", false), "评估应成功")
	assertions.assert_eq(result.get("use_skill", ""), "basic_sword", "应选择能打到最多敌人的技能")

	# evaluate 测试 - MP 不足时使用普攻
	battle = TacticalBattleState.new()
	battle.battlefield_width = 5
	battle.battlefield_height = 5
	player = TacticalUnitState.new()
	player.unit_id = "player"
	player.team = "player"
	player.cell = {"q": 2, "r": 2}
	player.hp = 100
	player.mp = 0
	player.attack = 10
	player.move_range = 1
	player.attack_range = 1
	player_skills = ["basic_sword"]
	player.martial_art_ids = player_skills
	battle.add_unit(player)
	var enemy = TacticalUnitState.new()
	enemy.unit_id = "enemy"
	enemy.team = "enemy"
	enemy.cell = {"q": 3, "r": 2}
	enemy.hp = 10
	battle.add_unit(enemy)
	result = ai.evaluate(player, battle)
	assertions.assert_eq(result.get("use_skill", ""), "attack", "MP 不足时应使用普攻")

	# evaluate 测试 - 无目标时向敌人移动
	battle = TacticalBattleState.new()
	battle.battlefield_width = 5
	battle.battlefield_height = 5
	player = TacticalUnitState.new()
	player.unit_id = "player"
	player.team = "player"
	player.cell = {"q": 0, "r": 0}
	player.hp = 100
	player.mp = 10
	player.attack = 10
	player.move_range = 2
	player.attack_range = 1
	player_skills = ["basic_sword"]
	player.martial_art_ids = player_skills
	battle.add_unit(player)
	enemy = TacticalUnitState.new()
	enemy.unit_id = "enemy"
	enemy.team = "enemy"
	enemy.cell = {"q": 4, "r": 4}
	enemy.hp = 10
	battle.add_unit(enemy)
	result = ai.evaluate(player, battle)
	var move_to = result.get("move_to", {})
	assertions.assert_true(
		int(move_to.get("q", 0)) > 0 or int(move_to.get("r", 0)) > 0,
		"应向敌人方向移动"
	)

	# evaluate 测试 - 避开友军位置
	battle = TacticalBattleState.new()
	battle.battlefield_width = 5
	battle.battlefield_height = 5
	player = TacticalUnitState.new()
	player.unit_id = "player"
	player.team = "player"
	player.cell = {"q": 2, "r": 2}
	player.hp = 100
	player.mp = 10
	player.attack = 10
	player.move_range = 1
	player.attack_range = 1
	player_skills = ["basic_sword"]
	player.martial_art_ids = player_skills
	battle.add_unit(player)
	var ally = TacticalUnitState.new()
	ally.unit_id = "ally"
	ally.team = "player"
	ally.cell = {"q": 3, "r": 2}
	ally.hp = 100
	battle.add_unit(ally)
	enemy = TacticalUnitState.new()
	enemy.unit_id = "enemy"
	enemy.team = "enemy"
	enemy.cell = {"q": 3, "r": 2}
	enemy.hp = 10
	battle.add_unit(enemy)
	result = ai.evaluate(player, battle)
	move_to = result.get("move_to", {})
	assertions.assert_false(
		int(move_to.get("q", 0)) == 3 and int(move_to.get("r", 0)) == 2,
		"不应移动到友军位置"
	)
