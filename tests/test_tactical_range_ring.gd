extends RefCounted

const TacticalRangeSystemScript = preload("res://scripts/systems/tactical_range_system.gd")

func run(assertions) -> void:
	var rs = TacticalRangeSystemScript.new()

	var ring = rs.get_ring_range({"position": Vector2i(3, 3)}, 2)
	assertions.assert_eq(ring.size(), 8, "距 2 环形应有 8 格")
	assertions.assert_true(ring.has(Vector2i(1, 3)), "距离 2 左")
	assertions.assert_true(ring.has(Vector2i(5, 3)), "距离 2 右")
	assertions.assert_true(ring.has(Vector2i(3, 1)), "距离 2 上")
	assertions.assert_true(ring.has(Vector2i(3, 5)), "距离 2 下")
	assertions.assert_true(ring.has(Vector2i(2, 2)), "距离 2 左上")
	assertions.assert_true(ring.has(Vector2i(4, 2)), "距离 2 右上")
	assertions.assert_true(ring.has(Vector2i(2, 4)), "距离 2 左下")
	assertions.assert_true(ring.has(Vector2i(4, 4)), "距离 2 右下")
	assertions.assert_false(ring.has(Vector2i(3, 3)), "自身不应在环形")
	assertions.assert_false(ring.has(Vector2i(2, 3)), "距离 1 不应在距 2 环形")

	var ring_1 = rs.get_ring_range({"position": Vector2i(0, 0)}, 1)
	assertions.assert_eq(ring_1.size(), 2, "角落距 1 环形应 2 格")
