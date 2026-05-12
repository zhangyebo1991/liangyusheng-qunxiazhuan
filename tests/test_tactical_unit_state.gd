extends RefCounted

const TACTICAL_UNIT_STATE_PATH := "res://scripts/domain/tactical_unit_state.gd"

func run(assertions) -> void:
	var TacticalUnitStateScript = load(TACTICAL_UNIT_STATE_PATH)
	assertions.assert_true(TacticalUnitStateScript != null, "应存在战棋单位状态脚本")
	if TacticalUnitStateScript == null:
		return

	var unit = TacticalUnitStateScript.new()
	unit.from_dictionary({
		"unit_id": "hero",
		"actor_id": "hero_yun",
		"display_name": "云游少侠",
		"team": "player",
		"hp": 90,
		"max_hp": 120,
		"attack": 18,
		"defense": 8,
		"move_range": 3,
		"attack_range": 1,
		"charge_speed": 240,
		"charge": 700,
		"cell": {"q": 1, "r": 2},
	})

	assertions.assert_eq(unit.unit_id, "hero", "战棋单位应读取单位编号")
	assertions.assert_eq(unit.actor_id, "hero_yun", "战棋单位应读取角色编号")
	assertions.assert_eq(unit.display_name, "云游少侠", "战棋单位应读取显示名")
	assertions.assert_eq(unit.team, "player", "战棋单位应读取阵营")
	assertions.assert_eq(unit.hp, 90, "战棋单位应读取当前气血")
	assertions.assert_eq(unit.max_hp, 120, "战棋单位应读取最大气血")
	assertions.assert_eq(unit.cell.get("q", -1), 1, "战棋单位应读取 q 坐标")
	assertions.assert_eq(unit.cell.get("r", -1), 2, "战棋单位应读取 r 坐标")
	assertions.assert_true(unit.is_alive(), "气血大于 0 的单位应存活")

	unit.reset_charge()
	assertions.assert_eq(unit.charge, 0, "清空集气后 charge 应为 0")

	var serialized = unit.to_dictionary()
	assertions.assert_eq(serialized.get("unit_id", ""), "hero", "单位序列化应保存单位编号")
	assertions.assert_eq(serialized.get("cell", {}).get("q", -1), 1, "单位序列化应保存 q 坐标")
	assertions.assert_eq(serialized.get("charge", -1), 0, "单位序列化应保存当前集气")

	unit.hp = 0
	assertions.assert_true(not unit.is_alive(), "气血为 0 的单位不应存活")
