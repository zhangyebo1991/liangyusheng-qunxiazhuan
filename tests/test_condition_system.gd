extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const ConditionSystemScript = preload("res://scripts/systems/condition_system.gd")

func run(assertions) -> void:
	var state = GameStateScript.new()
	state.start_new_game()
	var condition_system = ConditionSystemScript.new()

	state.quest_system.set_status("quest_deliver_letter", "completed")
	state.set_flag("clue_road_unrest", true)
	state.party.add_item("herb_small", 2)
	state.resolve_map_object("pickup_roadside_bundle")

	var result = condition_system.are_conditions_met(state, [
		{"type": "quest_status", "quest_id": "quest_deliver_letter", "status": "completed"},
		{"type": "flag_equals", "key": "clue_road_unrest", "value": true},
		{"type": "has_item", "item_id": "herb_small", "amount": 2},
		{"type": "map_object_resolved", "object_id": "pickup_roadside_bundle"},
		{"type": "not", "condition": {"type": "flag_equals", "key": "missing_flag", "value": true}}
	])
	assertions.assert_true(bool(result.get("success", false)), "合法条件判断应成功")
	assertions.assert_true(bool(result.get("met", false)), "全部条件满足时应返回 met")
	assertions.assert_eq(int(result.get("failed_conditions", -1)), 0, "满足条件时失败条件数量应为 0")

	var missing_item = condition_system.are_conditions_met(state, [
		{"type": "has_item", "item_id": "herb_small", "amount": 4}
	])
	assertions.assert_true(bool(missing_item.get("success", false)), "未满足条件不是结构错误")
	assertions.assert_true(not bool(missing_item.get("met", true)), "物品数量不足时条件不满足")
	assertions.assert_eq(int(missing_item.get("failed_conditions", 0)), 1, "物品数量不足应记录失败条件")
	assertions.assert_eq(missing_item.get("messages", [])[0], "缺少物品：herb_small x4", "物品条件失败应返回中文原因")

	var wrong_status = condition_system.is_condition_met(state, {
		"type": "quest_status",
		"quest_id": "quest_deliver_letter",
		"status": "active"
	})
	assertions.assert_true(bool(wrong_status.get("success", false)), "任务状态不匹配不是结构错误")
	assertions.assert_true(not bool(wrong_status.get("met", true)), "任务状态不匹配时条件不满足")

	var bad_list = condition_system.are_conditions_met(state, {"type": "has_item"})
	assertions.assert_true(not bool(bad_list.get("success", true)), "非数组条件列表应失败")
	assertions.assert_eq(bad_list.get("errors", [])[0], "条件列表格式错误。", "非数组条件列表应返回中文错误")

	var unknown = condition_system.is_condition_met(state, {"type": "missing_condition"})
	assertions.assert_true(not bool(unknown.get("success", true)), "未知条件类型应失败")
	assertions.assert_eq(unknown.get("errors", [])[0], "未知条件类型：missing_condition", "未知条件类型应返回中文错误")

	var invalid_not = condition_system.is_condition_met(state, {"type": "not", "condition": []})
	assertions.assert_true(not bool(invalid_not.get("success", true)), "not 条件缺少子条件时应失败")

	state.free()
