extends RefCounted

const TacticalRangeSystemScript = preload("res://scripts/systems/tactical_range_system.gd")

func run(assertions) -> void:
	var rs = TacticalRangeSystemScript.new()

	# 主角在 (3,3)，方向右 (1,0)，range=2 → 扇形右方
	var fan_right = rs.get_fan_range({"position": Vector2i(3, 3)}, Vector2i(1, 0), 2)
	assertions.assert_true(fan_right.has(Vector2i(4, 3)), "正右方 1 格应命中")
	assertions.assert_true(fan_right.has(Vector2i(5, 3)), "正右方 2 格应命中")
	assertions.assert_true(fan_right.has(Vector2i(4, 2)), "右上方 1 格应命中")
	assertions.assert_true(fan_right.has(Vector2i(4, 4)), "右下方 1 格应命中")
	assertions.assert_false(fan_right.has(Vector2i(4, 1)), "太远上方应不命中")
	assertions.assert_false(fan_right.has(Vector2i(2, 3)), "左方应全不命中")
	assertions.assert_false(fan_right.has(Vector2i(3, 3)), "自身格不应在结果")

	# 主角在 (3,3)，方向上 (0,-1)，range=2
	var fan_up = rs.get_fan_range({"position": Vector2i(3, 3)}, Vector2i(0, -1), 2)
	assertions.assert_true(fan_up.has(Vector2i(3, 2)), "正上方 1 格应命中")
	assertions.assert_true(fan_up.has(Vector2i(3, 1)), "正上方 2 格应命中")
	assertions.assert_false(fan_up.has(Vector2i(3, 4)), "下方应不命中")

	# 主角在 (0,0)，方向右 (1,0)，range=2 → 只右侧格
	var fan_corner = rs.get_fan_range({"position": Vector2i(0, 0)}, Vector2i(1, 0), 2)
	assertions.assert_true(fan_corner.has(Vector2i(1, 0)), "角落右 1 格应命中")
	assertions.assert_true(fan_corner.has(Vector2i(2, 0)), "角落右 2 格应命中")
	assertions.assert_true(fan_corner.has(Vector2i(1, 1)), "角落右下应命中")
