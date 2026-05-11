extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const MapTransitionSystemScript = preload("res://scripts/systems/map_transition_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var transition_system = MapTransitionSystemScript.new()

	var mountain = repository.get_map("mountain_pass")
	var village = repository.get_map("foot_village")
	var road = repository.get_map("road_outskirts")
	var mountain_exit = _find_object(mountain, "exit_to_foot_village")
	var result = transition_system.resolve_transition(mountain_exit, village)
	assertions.assert_true(result.get("success", false), "山道出口应能切到村镇")
	assertions.assert_eq(result.get("map_id", ""), "foot_village", "切换结果应包含目标地图")
	assertions.assert_eq(result.get("position", Vector2.ZERO), Vector2(120, 360), "切换结果应使用村口出生点")

	var village_exit = _find_object(village, "exit_to_mountain_pass")
	var back = transition_system.resolve_transition(village_exit, mountain)
	assertions.assert_true(back.get("success", false), "村镇出口应能切回山道")
	assertions.assert_eq(back.get("map_id", ""), "mountain_pass", "返回结果应包含山道地图")
	assertions.assert_eq(back.get("position", Vector2.ZERO), Vector2(1110, 320), "返回结果应使用山道返回点")

	var road_exit = _find_object(village, "exit_to_road_outskirts")
	var locked_state = GameStateScript.new()
	locked_state.start_new_game()
	var locked_road = transition_system.resolve_transition(road_exit, road, locked_state)
	assertions.assert_true(not locked_road.get("success", true), "送信任务未完成时官道出口应锁定")
	assertions.assert_eq(locked_road.get("message", ""), "脚夫说前路不太平，先把书信送到客栈再说。", "官道锁定时应返回配置提示")

	var unlocked_state = GameStateScript.new()
	unlocked_state.start_new_game()
	unlocked_state.quest_system.start_quest("quest_deliver_letter")
	unlocked_state.quest_system.mark_ready_to_complete("quest_deliver_letter")
	unlocked_state.quest_system.complete_quest("quest_deliver_letter")
	var unlocked_road = transition_system.resolve_transition(road_exit, road, unlocked_state)
	assertions.assert_true(unlocked_road.get("success", false), "送信任务完成后官道出口应开放")
	assertions.assert_eq(unlocked_road.get("map_id", ""), "road_outskirts", "官道出口应切换到村外官道")
	assertions.assert_eq(unlocked_road.get("position", Vector2.ZERO), Vector2(120, 360), "官道出口应使用村口进入出生点")

	var missing_spawn = transition_system.resolve_transition({
		"target_map_id": "foot_village",
		"target_spawn_id": "missing_spawn"
	}, village)
	assertions.assert_true(missing_spawn.get("success", false), "缺失出生点时仍应允许切换")
	assertions.assert_eq(missing_spawn.get("position", Vector2.ZERO), Vector2(120, 360), "缺失出生点应回退默认出生点")

	var missing_target = transition_system.resolve_transition({
		"target_map_id": "missing_map",
		"target_spawn_id": "start",
		"locked_message": "前路尚未开放。"
	}, {})
	assertions.assert_true(not missing_target.get("success", true), "缺失目标地图应返回失败")
	assertions.assert_eq(missing_target.get("message", ""), "前路尚未开放。", "缺失目标地图应返回提示")

	var locked = transition_system.resolve_transition({
		"target_map_id": "",
		"target_spawn_id": "",
		"locked_message": "前路尚未开放。"
	}, village)
	assertions.assert_true(not locked.get("success", true), "空目标地图应返回失败")
	assertions.assert_eq(locked.get("message", ""), "前路尚未开放。", "空目标地图应返回锁定提示")

	locked_state.free()
	unlocked_state.free()
	repository.free()

func _find_object(map_data: Dictionary, object_id: String) -> Dictionary:
	for object in map_data.get("objects", []):
		if object.get("id", "") == object_id:
			return object
	return {}
