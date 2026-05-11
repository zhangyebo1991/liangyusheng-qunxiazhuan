extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const EffectSystemScript = preload("res://scripts/systems/effect_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var effect_system = EffectSystemScript.new()

	var mountain = repository.get_quest("quest_mountain_trial")
	var mountain_effects = mountain.get("complete_effects", [])
	assertions.assert_eq(mountain_effects.size(), 2, "山道试剑应声明两个完成效果")
	assertions.assert_eq(_count_effect(mountain_effects, "set_quest_status"), 1, "山道试剑完成效果应设置任务完成")
	assertions.assert_eq(_count_effect(mountain_effects, "add_item"), 1, "山道试剑完成效果应发放小还丹")

	var delivery = repository.get_quest("quest_deliver_letter")
	var delivery_effects = delivery.get("complete_effects", [])
	assertions.assert_eq(delivery_effects.size(), 2, "送信任务应声明两个完成效果")
	assertions.assert_eq(_count_effect(delivery_effects, "set_quest_status"), 1, "送信任务完成效果应设置任务完成")
	assertions.assert_eq(_count_effect(delivery_effects, "set_flag"), 1, "送信任务完成效果应写入线索 flag")

	var road = repository.get_map("road_outskirts")
	var bundle = _find_object(road, "pickup_roadside_bundle")
	var pickup_effects = bundle.get("effects", [])
	assertions.assert_eq(pickup_effects.size(), 3, "路边包裹应声明三个拾取效果")
	assertions.assert_eq(_count_effect(pickup_effects, "add_item"), 1, "路边包裹应通过效果发放小还丹")
	assertions.assert_eq(_count_effect(pickup_effects, "add_coins"), 1, "路边包裹应通过效果发放铜钱")
	assertions.assert_eq(_count_effect(pickup_effects, "resolve_map_object"), 1, "路边包裹应通过效果标记已解决")

	var state = GameStateScript.new()
	state.start_new_game()
	state.quest_system.start_quest("quest_deliver_letter")
	var delivery_result = effect_system.apply_effects(state, delivery_effects)
	assertions.assert_true(delivery_result.get("success", false), "送信任务完成效果应可执行")
	assertions.assert_eq(state.quest_system.get_status("quest_deliver_letter"), "completed", "送信任务效果应完成任务")
	assertions.assert_eq(state.flags.get("clue_foot_village", ""), "掌柜提到飞红巾踪迹", "送信任务效果应写入线索")

	state.free()
	repository.free()

func _count_effect(effects: Array, effect_type: String) -> int:
	var count := 0
	for effect in effects:
		if typeof(effect) == TYPE_DICTIONARY and str(effect.get("type", "")) == effect_type:
			count += 1
	return count

func _find_object(map_data: Dictionary, object_id: String) -> Dictionary:
	for object in map_data.get("objects", []):
		if str(object.get("id", "")) == object_id:
			return object
	return {}
