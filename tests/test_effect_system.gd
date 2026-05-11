extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const EffectSystemScript = preload("res://scripts/systems/effect_system.gd")

func run(assertions) -> void:
	var state = GameStateScript.new()
	state.start_new_game()
	var initial_herbs = state.party.get_item_count("herb_small")
	var initial_coins = state.party.coins
	var effect_system = EffectSystemScript.new()
	assertions.assert_true(effect_system.has_method("apply_effects"), "EffectSystem 应提供 apply_effects 方法")
	if not effect_system.has_method("apply_effects"):
		state.free()
		return

	var result = effect_system.apply_effects(state, [
		{"type": "add_item", "item_id": "herb_small", "amount": 2},
		{"type": "add_coins", "amount": 15},
		{"type": "set_flag", "key": "clue_test", "value": "测试线索"},
		{"type": "set_quest_status", "quest_id": "quest_mountain_trial", "status": "ready_to_complete"},
		{"type": "resolve_map_object", "object_id": "object_test"},
		{"type": "add_martial_proficiency", "martial_art_id": "basic_sword", "amount": 3}
	])
	assertions.assert_true(result.get("success", false), "合法效果列表应执行成功")
	assertions.assert_eq(result.get("applied", 0), 6, "应记录 6 个成功效果")
	assertions.assert_eq(result.get("failed", 0), 0, "合法效果不应产生失败")
	assertions.assert_eq(state.party.get_item_count("herb_small"), initial_herbs + 2, "add_item 应增加背包数量")
	assertions.assert_eq(state.party.coins, initial_coins + 15, "add_coins 应增加铜钱")
	assertions.assert_eq(state.flags.get("clue_test", ""), "测试线索", "set_flag 应写入 flag")
	assertions.assert_eq(state.quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "set_quest_status 应修改任务状态")
	assertions.assert_true(state.is_map_object_resolved("object_test"), "resolve_map_object 应标记地图对象")
	assertions.assert_eq(state.get_martial_proficiency("basic_sword"), 3, "add_martial_proficiency 应增加熟练度")
	assertions.assert_eq(result.get("items", [])[0].get("id", ""), "herb_small", "结果应记录物品编号")
	assertions.assert_eq(result.get("coins", 0), 15, "结果应记录铜钱总数")

	var missing_list = effect_system.apply_effects(state, {"type": "add_coins", "amount": 1})
	assertions.assert_true(not missing_list.get("success", true), "非数组效果列表应失败")
	assertions.assert_eq(missing_list.get("failed", 0), 1, "非数组效果列表应记录一次失败")

	var unknown = effect_system.apply_effects(state, [{"type": "missing_effect"}])
	assertions.assert_true(not unknown.get("success", true), "未知效果类型应失败")
	assertions.assert_eq(unknown.get("errors", [])[0], "未知效果类型：missing_effect", "未知效果应返回中文错误")

	var missing_item_id = effect_system.apply_effects(state, [{"type": "add_item", "amount": 1}])
	assertions.assert_true(not missing_item_id.get("success", true), "缺少物品编号应失败")
	assertions.assert_eq(missing_item_id.get("errors", [])[0], "物品效果缺少物品编号。", "缺少物品编号应返回中文错误")

	var invalid_amount = effect_system.apply_effects(state, [{"type": "add_coins", "amount": 0}])
	assertions.assert_true(not invalid_amount.get("success", true), "非正数铜钱奖励应失败")
	assertions.assert_eq(invalid_amount.get("errors", [])[0], "铜钱效果数量必须大于 0。", "非正数铜钱应返回中文错误")

	var invalid_status = effect_system.apply_effects(state, [{"type": "set_quest_status", "quest_id": "quest_mountain_trial", "status": "done"}])
	assertions.assert_true(not invalid_status.get("success", true), "非法任务状态应失败")
	assertions.assert_eq(invalid_status.get("errors", [])[0], "任务状态无效：done", "非法任务状态应返回中文错误")

	state.free()
