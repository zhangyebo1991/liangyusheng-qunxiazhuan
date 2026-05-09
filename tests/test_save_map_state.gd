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

	var village_state = GameStateScript.new()
	village_state.start_new_game()
	village_state.set_current_map("foot_village", Vector2(760, 320))
	village_state.quest_system.start_quest("quest_deliver_letter")
	village_state.quest_system.mark_ready_to_complete("quest_deliver_letter")
	village_state.quest_system.complete_quest("quest_deliver_letter")
	village_state.set_flag("clue_foot_village", "掌柜提到飞红巾踪迹")
	assertions.assert_eq(village_state.get_current_map_scene_path(), "res://scenes/foot_village.tscn", "村镇地图应映射到村镇场景")
	assertions.assert_eq(village_state.get_scene_path_for_map("missing_map"), "res://scenes/mountain_pass.tscn", "未知地图应回退山道场景")

	var village_path = "user://test_foot_village_save.json"
	assertions.assert_true(village_state.save_to_path(village_path), "村镇状态应可写入存档文件")

	var restored_village = GameStateScript.new()
	assertions.assert_true(restored_village.load_from_path(village_path), "村镇状态应可从存档文件读取")
	assertions.assert_eq(restored_village.map_state.current_map_id, "foot_village", "读档应恢复村镇地图")
	assertions.assert_eq(restored_village.map_state.player_position, Vector2(760, 320), "读档应恢复村镇坐标")
	assertions.assert_eq(restored_village.quest_system.get_status("quest_deliver_letter"), "completed", "读档应恢复送信任务状态")
	assertions.assert_eq(restored_village.flags.get("clue_foot_village", ""), "掌柜提到飞红巾踪迹", "读档应恢复线索标记")

	state.free()
	restored.free()
	village_state.free()
	restored_village.free()
