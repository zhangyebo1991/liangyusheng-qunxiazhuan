extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const MapTransitionSystemScript = preload("res://scripts/systems/map_transition_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var transition_system = MapTransitionSystemScript.new()

	var mountain = repository.get_map("mountain_pass")
	var village = repository.get_map("foot_village")
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

	repository.free()

func _find_object(map_data: Dictionary, object_id: String) -> Dictionary:
	for object in map_data.get("objects", []):
		if object.get("id", "") == object_id:
			return object
	return {}
