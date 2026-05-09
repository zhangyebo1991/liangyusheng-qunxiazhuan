extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")

func run(assertions) -> void:
	var state = GameStateScript.new()
	state.start_new_game()
	state.set_player_position(Vector2(444, 333))
	state.quest_system.start_quest("quest_mountain_trial")
	state.quest_system.mark_ready_to_complete("quest_mountain_trial")
	state.resolve_map_object("enemy_bandit_gate")

	var path = "user://test_mountain_pass_save.json"
	assertions.assert_true(state.save_to_path(path), "游戏状态应可写入存档文件")

	var restored = GameStateScript.new()
	assertions.assert_true(restored.load_from_path(path), "游戏状态应可从存档文件读取")

	assertions.assert_eq(restored.map_state.current_map_id, "mountain_pass", "读档应恢复地图编号")
	assertions.assert_eq(restored.map_state.player_position, Vector2(444, 333), "读档应恢复玩家坐标")
	assertions.assert_true(restored.map_state.is_object_resolved("enemy_bandit_gate"), "读档应恢复已解决敌人对象")
	assertions.assert_eq(restored.quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "读档应恢复任务状态")

	state.free()
	restored.free()
