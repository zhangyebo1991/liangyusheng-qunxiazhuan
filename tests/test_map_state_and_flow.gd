extends RefCounted

const MapStateScript = preload("res://scripts/domain/map_state.gd")
const QuestSystemScript = preload("res://scripts/systems/quest_system.gd")
const SaveSystemScript = preload("res://scripts/systems/save_system.gd")

func run(assertions) -> void:
	var map_state = MapStateScript.new()
	map_state.current_map_id = "mountain_pass"
	map_state.player_position = Vector2(240, 320)
	map_state.mark_object_resolved("enemy_bandit_gate")

	var serialized = map_state.to_dictionary()
	assertions.assert_eq(serialized.get("current_map_id", ""), "mountain_pass", "地图状态应保存当前地图编号")
	assertions.assert_eq(serialized.get("player_position", {}).get("x", 0), 240.0, "地图状态应保存玩家横坐标")
	assertions.assert_true(serialized.get("resolved_objects", []).has("enemy_bandit_gate"), "地图状态应保存已解决对象")

	var restored = MapStateScript.new()
	restored.from_dictionary(serialized)
	assertions.assert_eq(restored.current_map_id, "mountain_pass", "地图状态应恢复当前地图编号")
	assertions.assert_eq(restored.player_position, Vector2(240, 320), "地图状态应恢复玩家坐标")
	assertions.assert_true(restored.is_object_resolved("enemy_bandit_gate"), "地图状态应恢复已解决对象")

	var quest_system = QuestSystemScript.new()
	assertions.assert_true(quest_system.start_quest("quest_mountain_trial"), "山道任务应可开始")
	assertions.assert_true(quest_system.mark_ready_to_complete("quest_mountain_trial"), "山道任务应可标记为可交付")
	assertions.assert_eq(quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "山道任务应进入可交付状态")
	assertions.assert_true(quest_system.complete_quest("quest_mountain_trial"), "可交付任务应可完成")
	assertions.assert_eq(quest_system.get_status("quest_mountain_trial"), "completed", "山道任务应完成")

	var save_system = SaveSystemScript.new()
	var payload = save_system.serialize_state({
		"map_state": map_state.to_dictionary(),
		"quests": quest_system.to_dictionary(),
	})
	var save_data = save_system.deserialize_state(payload)
	assertions.assert_eq(save_data.get("map_state", {}).get("current_map_id", ""), "mountain_pass", "存档应保留地图编号")
	assertions.assert_eq(save_data.get("quests", {}).get("quest_mountain_trial", ""), "completed", "存档应保留任务状态")
