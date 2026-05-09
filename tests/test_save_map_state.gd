extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")

func run(assertions) -> void:
	var state = GameStateScript.new()
	state.start_new_game()
	assertions.assert_eq(state.party.coins, 80, "新游戏初始铜钱应为 80")
	assertions.assert_true(state.party.spend_coins(30), "测试存档前应能消费铜钱")
	state.set_player_position(Vector2(444, 333))
	state.quest_system.start_quest("quest_mountain_trial")
	state.quest_system.mark_ready_to_complete("quest_mountain_trial")
	state.resolve_map_object("enemy_bandit_gate")
	state.hero_hp = 70
	state.party.add_item("herb_small", 2)
	state.add_martial_proficiency("basic_sword", 3)

	var path = "user://test_mountain_pass_save.json"
	assertions.assert_true(state.save_to_path(path), "游戏状态应可写入存档文件")

	var restored = GameStateScript.new()
	assertions.assert_true(restored.load_from_path(path), "游戏状态应可从存档文件读取")

	assertions.assert_eq(restored.map_state.current_map_id, "mountain_pass", "读档应恢复地图编号")
	assertions.assert_eq(restored.map_state.player_position, Vector2(444, 333), "读档应恢复玩家坐标")
	assertions.assert_true(restored.map_state.is_object_resolved("enemy_bandit_gate"), "读档应恢复已解决敌人对象")
	assertions.assert_eq(restored.quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "读档应恢复任务状态")
	assertions.assert_eq(restored.party.get_item_count("herb_small"), 3, "读档应恢复背包数量")
	assertions.assert_eq(restored.party.coins, 50, "读档应恢复铜钱余额")
	assertions.assert_eq(restored.hero_hp, 70, "读档应恢复主角气血")
	assertions.assert_eq(restored.hero_max_hp, 120, "读档应恢复主角最大气血")
	assertions.assert_eq(restored.get_martial_proficiency("basic_sword"), 3, "读档应恢复基础剑法熟练度")

	var old_save_state = GameStateScript.new()
	old_save_state.from_dictionary({
		"party": {"members": ["hero_yun"], "inventory": {"herb_small": 1}},
		"quests": {},
		"map_state": {},
		"flags": {},
	})
	assertions.assert_eq(old_save_state.hero_hp, 120, "旧存档缺少气血时应回退为满气血")
	assertions.assert_eq(old_save_state.hero_max_hp, 120, "旧存档缺少最大气血时应使用默认值")
	assertions.assert_eq(old_save_state.party.coins, 0, "旧存档缺少铜钱时应回退为 0")
	assertions.assert_eq(old_save_state.get_martial_proficiency("basic_sword"), 0, "旧存档缺少熟练度时应回退为 0")

	var invalid_hp_state = GameStateScript.new()
	invalid_hp_state.from_dictionary({
		"party": {"members": ["hero_yun"], "coins": -5},
		"quests": {},
		"map_state": {},
		"flags": {},
		"hero_hp": 999,
		"hero_max_hp": 100,
		"martial_proficiency": {"basic_sword": -5}
	})
	assertions.assert_eq(invalid_hp_state.hero_hp, 100, "读档气血大于最大值时应钳制")
	assertions.assert_eq(invalid_hp_state.party.coins, 0, "读档铜钱小于 0 时应钳制")
	assertions.assert_eq(invalid_hp_state.get_martial_proficiency("basic_sword"), 0, "读档熟练度小于 0 时应钳制")
	assertions.assert_eq(invalid_hp_state.restore_hero_hp(30), 0, "气血已满时恢复量应为 0")
	invalid_hp_state.hero_hp = 40
	assertions.assert_eq(invalid_hp_state.restore_hero_hp(30), 30, "气血未满时应返回实际恢复量")
	assertions.assert_eq(invalid_hp_state.hero_hp, 70, "恢复后气血应增加")

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
	assertions.assert_eq(restored_village.party.coins, 80, "村镇存档应恢复新游戏初始铜钱")

	state.free()
	restored.free()
	old_save_state.free()
	invalid_hp_state.free()
	village_state.free()
	restored_village.free()
