extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const EventSystemScript = preload("res://scripts/systems/event_system.gd")

func run(assertions) -> void:
	var state = GameStateScript.new()
	state.start_new_game()
	var event_system = EventSystemScript.new()

	var blocked = event_system.apply_event(state, {
		"conditions": [
			{"type": "has_item", "item_id": "herb_small", "amount": 2}
		],
		"effects": [
			{"type": "add_coins", "amount": 30}
		]
	})
	assertions.assert_true(not bool(blocked.get("success", true)), "条件不满足时事件应失败")
	assertions.assert_true(not bool(blocked.get("conditions_met", true)), "条件不满足时应记录 conditions_met=false")
	assertions.assert_eq(state.party.coins, 80, "条件不满足时不应执行效果")
	assertions.assert_eq(blocked.get("messages", [])[0], "缺少物品：herb_small x2", "事件应透传条件失败原因")

	var applied = event_system.apply_event(state, {
		"conditions": [
			{"type": "has_item", "item_id": "herb_small", "amount": 1}
		],
		"effects": [
			{"type": "remove_item", "item_id": "herb_small", "amount": 1},
			{"type": "add_coins", "amount": 30},
			{"type": "set_flag", "key": "helped_road_scholar", "value": true}
		]
	})
	assertions.assert_true(bool(applied.get("success", false)), "条件满足时事件应成功")
	assertions.assert_true(bool(applied.get("conditions_met", false)), "条件满足时应记录 conditions_met=true")
	assertions.assert_eq(state.party.get_item_count("herb_small"), 0, "事件效果应扣除小还丹")
	assertions.assert_eq(state.party.coins, 110, "事件效果应增加铜钱")
	assertions.assert_eq(state.flags.get("helped_road_scholar", false), true, "事件效果应写入 flag")
	assertions.assert_eq(int(applied.get("applied", 0)), 3, "事件应记录执行效果数量")

	var empty_event = event_system.apply_event(state, {"conditions": [], "effects": []})
	assertions.assert_true(bool(empty_event.get("success", false)), "空效果事件应允许作为纯对话跳转")
	assertions.assert_eq(int(empty_event.get("applied", -1)), 0, "空效果事件执行数量应为 0")

	var bad_event = event_system.apply_event(state, [])
	assertions.assert_true(not bool(bad_event.get("success", true)), "非字典事件应失败")
	assertions.assert_eq(bad_event.get("errors", [])[0], "事件格式错误。", "非字典事件应返回中文错误")

	state.free()
