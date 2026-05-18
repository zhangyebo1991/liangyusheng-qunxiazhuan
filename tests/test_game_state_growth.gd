extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")

func run(assertions) -> void:
	var state = GameStateScript.new()
	assertions.assert_true(state.growth_manager != null, "GameState.new() 应初始化 growth_manager")
	assertions.assert_eq(state.growth_manager.proficiency_points, 0, "新 growth_manager 熟练点应为 0")

	state.start_new_game()
	assertions.assert_true(state.growth_manager != null, "start_new_game() 后 growth_manager 不应为空")
	assertions.assert_eq(state.growth_manager.proficiency_points, 0, "start_new_game() 应重置熟练点为 0")

	state.growth_manager.proficiency_points = 15
	state.growth_manager.on_battle_end({"enemies": 2, "difficulty": 3})
	assertions.assert_eq(state.growth_manager.proficiency_points, 21, "战斗后熟练点应累加")

	var path = "user://test_game_state_growth.json"
	assertions.assert_true(state.save_to_path(path), "含成长数据的游戏状态应可存档")

	var restored = GameStateScript.new()
	assertions.assert_true(restored.load_from_path(path), "应可读取含成长数据的存档")
	assertions.assert_true(restored.growth_manager != null, "读档后 growth_manager 不应为空")
	assertions.assert_eq(restored.growth_manager.proficiency_points, 21, "读档应恢复熟练点")

	var old_data = {
		"party": {"members": ["hero_yun"]},
		"quests": {},
		"map_state": {},
		"flags": {},
	}
	var old_state = GameStateScript.new()
	old_state.from_dictionary(old_data)
	assertions.assert_true(old_state.growth_manager != null, "旧存档 growth_manager 不应为空")
	assertions.assert_eq(old_state.growth_manager.proficiency_points, 0, "旧存档缺少成长数据时熟练点应为 0")

	state.free()
	restored.free()
	old_state.free()
