extends RefCounted

# Task 13 测试：charge_bar 数据驱动布局（不依赖 _draw）。
# 验证 x 偏移计算与 is_action 高亮标记。

const ChargeBarScript = preload("res://scripts/scenes/charge_bar.gd")

func run(assertions) -> void:
	var bar = ChargeBarScript.new()
	bar.bar_width = 1000
	var units = [
		{"unit_id": "hero", "team": 0, "cur_charge": 250, "is_action": false},
		{"unit_id": "e1", "team": 1, "cur_charge": 500, "is_action": false},
		{"unit_id": "e2", "team": 1, "cur_charge": 1000, "is_action": true},
		{"unit_id": "e3", "team": 1, "cur_charge": 750, "is_action": false},
	]
	bar.set_units(units)
	assertions.assert_eq(bar.get_unit_x("hero"), 250, "250/1000 * 1000 = 250")
	assertions.assert_eq(bar.get_unit_x("e1"), 500, "500/1000 * 1000 = 500")
	assertions.assert_eq(bar.get_unit_x("e2"), 1000, "1000/1000 * 1000 = 1000")
	assertions.assert_eq(bar.get_unit_x("e3"), 750, "750/1000 * 1000 = 750")
	assertions.assert_true(bar.is_highlighted("e2"), "e2 应被高亮")
	assertions.assert_false(bar.is_highlighted("hero"), "hero 不应被高亮")
	assertions.assert_false(bar.is_highlighted("e1"), "e1 不应被高亮")
	bar.free()
