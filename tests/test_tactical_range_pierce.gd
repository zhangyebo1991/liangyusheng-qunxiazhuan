extends RefCounted

const TacticalRangeSystemScript = preload("res://scripts/systems/tactical_range_system.gd")

func run(assertions) -> void:
	var rs = TacticalRangeSystemScript.new()

	var pierce_right = rs.get_pierce_range({"position": Vector2i(3, 3)}, Vector2i(1, 0), 3)
	assertions.assert_eq(pierce_right.size(), 3, "右穿透应 3 格")
	assertions.assert_true(pierce_right.has(Vector2i(4, 3)), "第一格应命中")
	assertions.assert_true(pierce_right.has(Vector2i(5, 3)), "第二格应命中")
	assertions.assert_true(pierce_right.has(Vector2i(6, 3)), "第三格应命中")

	var pierce_edge = rs.get_pierce_range({"position": Vector2i(6, 3)}, Vector2i(1, 0), 3)
	assertions.assert_eq(pierce_edge.size(), 1, "边缘往右应 1 格")
	assertions.assert_true(pierce_edge.has(Vector2i(7, 3)), "应仅 (7,3)")

	var pierce_up = rs.get_pierce_range({"position": Vector2i(3, 3)}, Vector2i(0, -1), 3)
	assertions.assert_eq(pierce_up.size(), 3, "上穿透应 3 格")
	assertions.assert_true(pierce_up.has(Vector2i(3, 0)), "最远应到 (3,0)")
