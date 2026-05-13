extends RefCounted

const TacticalRangeSystemScript = preload("res://scripts/systems/tactical_range_system.gd")

func run(assertions) -> void:
	var rs = TacticalRangeSystemScript.new()

	var sur = rs.get_surround_range({"position": Vector2i(3, 3)})
	assertions.assert_eq(sur.size(), 8, "中心周身应有 8 格")
	assertions.assert_true(sur.has(Vector2i(2, 2)), "左上应命中")
	assertions.assert_true(sur.has(Vector2i(3, 2)), "上应命中")
	assertions.assert_true(sur.has(Vector2i(4, 2)), "右上应命中")
	assertions.assert_true(sur.has(Vector2i(2, 3)), "左应命中")
	assertions.assert_true(sur.has(Vector2i(4, 3)), "右应命中")
	assertions.assert_true(sur.has(Vector2i(2, 4)), "左下应命中")
	assertions.assert_true(sur.has(Vector2i(3, 4)), "下应命中")
	assertions.assert_true(sur.has(Vector2i(4, 4)), "右下应命中")
	assertions.assert_false(sur.has(Vector2i(3, 3)), "自身不应在范围")

	var sur_corner = rs.get_surround_range({"position": Vector2i(0, 0)})
	assertions.assert_eq(sur_corner.size(), 3, "角落周身应 3 格")
	assertions.assert_true(sur_corner.has(Vector2i(1, 0)), "右")
	assertions.assert_true(sur_corner.has(Vector2i(0, 1)), "下")
	assertions.assert_true(sur_corner.has(Vector2i(1, 1)), "右下")
