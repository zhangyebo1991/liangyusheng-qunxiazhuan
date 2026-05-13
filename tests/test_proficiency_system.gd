extends RefCounted

const ProficiencySystemScript = preload("res://scripts/systems/proficiency_system.gd")

func run(assertions) -> void:
	var ps = ProficiencySystemScript.new()

	# 0 次使用：等级 0，加值 0
	assertions.assert_eq(ps.get_level(0, [10, 25, 50]), 0, "0 次应 Lv.0")
	assertions.assert_eq(ps.get_bonus(0, [10, 25, 50]), 0, "0 次 bonus = 0")

	# 9 次：未跨过第一个阈值
	assertions.assert_eq(ps.get_level(9, [10, 25, 50]), 0, "9 次应 Lv.0")
	assertions.assert_eq(ps.get_bonus(9, [10, 25, 50]), 0, "9 次 bonus = 0")

	# 10 次：跨过第 1 个阈值 → Lv.1 → bonus +2
	assertions.assert_eq(ps.get_level(10, [10, 25, 50]), 1, "10 次应 Lv.1")
	assertions.assert_eq(ps.get_bonus(10, [10, 25, 50]), 2, "10 次 bonus = 2")

	# 25 次：跨过 2 个阈值 → Lv.2 → bonus +4
	assertions.assert_eq(ps.get_level(25, [10, 25, 50]), 2, "25 次应 Lv.2")
	assertions.assert_eq(ps.get_bonus(25, [10, 25, 50]), 4, "25 次 bonus = 4")

	# 50 次：跨过 3 个阈值 → Lv.3 → bonus +6
	assertions.assert_eq(ps.get_level(50, [10, 25, 50]), 3, "50 次应 Lv.3")
	assertions.assert_eq(ps.get_bonus(50, [10, 25, 50]), 6, "50 次 bonus = 6")

	# 空阈值的武学（无 proficiency_thresholds）
	assertions.assert_eq(ps.get_level(100, []), 0, "空阈值应 Lv.0")
	assertions.assert_eq(ps.get_bonus(100, []), 0, "空阈值 bonus = 0")

	# add_use 跨映射
	var map: Dictionary = {}
	ps.add_use(map, "basic_sword")
	assertions.assert_eq(int(map.get("basic_sword", 0)), 1, "add_use 应累加 1")
	ps.add_use(map, "basic_sword")
	assertions.assert_eq(int(map.get("basic_sword", 0)), 2, "二次 add_use 应累加到 2")
	ps.add_use(map, "sword_willow_sweep")
	assertions.assert_eq(int(map.get("sword_willow_sweep", 0)), 1, "其他武学应独立计数")
