extends RefCounted

const LootSystemScript = preload("res://scripts/systems/loot_system.gd")

class FixedRng:
	extends RefCounted

	var float_values: Array = []
	var int_values: Array = []

	func _init(next_float_values: Array = [], next_int_values: Array = []) -> void:
		float_values = next_float_values.duplicate()
		int_values = next_int_values.duplicate()

	func randf() -> float:
		if float_values.is_empty():
			return 0.0
		return float(float_values.pop_front())

	func randi_range(min_value: int, max_value: int) -> int:
		if int_values.is_empty():
			return min_value
		return clampi(int(int_values.pop_front()), min_value, max_value)

func run(assertions) -> void:
	var system = LootSystemScript.new()

	var empty = system.roll_loot({}, FixedRng.new())
	assertions.assert_false(bool(empty.get("rolled", true)), "空掉落表不应掷骰")
	assertions.assert_eq(int(empty.get("coins", -1)), 0, "空掉落表不应产生铜钱")
	assertions.assert_eq(empty.get("items", []).size(), 0, "空掉落表不应产生物品")

	var no_rolls = system.roll_loot({
		"rolls": 0,
		"entries": [{"type": "item", "item_id": "herb_small", "chance": 1.0, "amount": 1}]
	}, FixedRng.new())
	assertions.assert_false(bool(no_rolls.get("rolled", true)), "rolls 为 0 时不应掷骰")

	var chance_edges = system.roll_loot({
		"rolls": 1,
		"entries": [
			{"type": "item", "item_id": "never_drop", "chance": 0.0, "amount": 1},
			{"type": "item", "item_id": "always_drop", "chance": 1.0, "amount": 2}
		]
	}, FixedRng.new())
	assertions.assert_true(bool(chance_edges.get("rolled", false)), "有效 rolls 应标记已掷骰")
	assertions.assert_eq(chance_edges.get("items", []).size(), 1, "chance 0 应跳过，chance 1 应掉落")
	assertions.assert_eq(chance_edges.get("items", [])[0].get("item_id", ""), "always_drop", "必掉物品编号应保留")
	assertions.assert_eq(chance_edges.get("items", [])[0].get("amount", 0), 2, "必掉物品数量应保留")

	var random_result = system.roll_loot({
		"rolls": 2,
		"entries": [
			{"type": "item", "item_id": "herb_focus", "chance": 0.50, "amount": 1},
			{"type": "coins", "chance": 0.50, "amount_min": 3, "amount_max": 8}
		]
	}, FixedRng.new([0.40, 0.20, 0.70, 0.10], [6, 4]))
	assertions.assert_eq(random_result.get("items", []).size(), 1, "第一轮物品命中、第二轮物品未命中")
	assertions.assert_eq(random_result.get("items", [])[0].get("item_id", ""), "herb_focus", "命中物品应进入结果")
	assertions.assert_eq(int(random_result.get("coins", 0)), 10, "两次铜钱命中应聚合数量")

	var normalized_amount = system.roll_loot({
		"rolls": 1,
		"entries": [
			{"type": "item", "item_id": "cloth_armor", "chance": 1.0, "amount": 0},
			{"type": "coins", "chance": 1.0, "amount_min": 9, "amount_max": 3}
		]
	}, FixedRng.new([], [5]))
	assertions.assert_eq(normalized_amount.get("items", [])[0].get("amount", 0), 1, "物品数量小于等于 0 应归一为 1")
	assertions.assert_eq(int(normalized_amount.get("coins", 0)), 9, "数量区间反转时应使用 amount_min")

	var invalid_entries = system.roll_loot({
		"rolls": 1,
		"entries": [
			{"type": "item", "item_id": "", "chance": 1.0, "amount": 1},
			{"type": "coins", "chance": 1.0, "amount": -5},
			{"type": "unknown", "chance": 1.0}
		]
	}, FixedRng.new())
	assertions.assert_eq(int(invalid_entries.get("coins", 0)), 1, "无效铜钱数量应归一为 1")
	assertions.assert_eq(invalid_entries.get("items", []).size(), 0, "空 item_id 不应进入物品结果")
	assertions.assert_true(invalid_entries.get("errors", []).size() >= 2, "无效 entry 应记录错误")
