extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")

func run(assertions) -> void:
	# 新游戏：hero_cur_mp 应等于 hero_max_mp
	var game_state = GameStateScript.new()
	game_state.start_new_game()
	assertions.assert_eq(game_state.hero_cur_mp, game_state.hero_max_mp, "新游戏当前内力应等于最大内力")
	assertions.assert_eq(game_state.last_inn_id, "", "新游戏未绑定客栈")
	assertions.assert_false(game_state.has_bound_inn(), "新游戏 has_bound_inn 应为 false")

	# consume_hero_mp 扣减成功 + clamp 到 0
	var ok = game_state.consume_hero_mp(5)
	assertions.assert_true(ok, "扣 5 内力应成功")
	assertions.assert_eq(game_state.hero_cur_mp, game_state.hero_max_mp - 5, "扣后当前内力应减 5")
	var ok2 = game_state.consume_hero_mp(9999)
	assertions.assert_false(ok2, "内力不足应返回 false")
	assertions.assert_eq(game_state.hero_cur_mp, game_state.hero_max_mp - 5, "失败的扣减不应改变当前内力")

	# restore_hero_mp 恢复并 clamp 到 max
	var restored = game_state.restore_hero_mp(2)
	assertions.assert_eq(restored, 2, "实际恢复量应为 2")
	assertions.assert_eq(game_state.hero_cur_mp, game_state.hero_max_mp - 3, "恢复后当前内力应为 max - 3")
	var restored_overflow = game_state.restore_hero_mp(9999)
	assertions.assert_eq(restored_overflow, 3, "溢出恢复应只补到满")
	assertions.assert_eq(game_state.hero_cur_mp, game_state.hero_max_mp, "应被 clamp 到 max")

	# bind_inn / has_bound_inn
	game_state.bind_inn("foot_village_inn")
	assertions.assert_true(game_state.has_bound_inn(), "绑定后 has_bound_inn 应为 true")
	assertions.assert_eq(game_state.last_inn_id, "foot_village_inn", "last_inn_id 应被设置")

	# 存档/读档
	game_state.consume_hero_mp(7)
	var serialized = game_state.to_dictionary()
	assertions.assert_eq(serialized.get("hero_cur_mp", -1), game_state.hero_max_mp - 7, "to_dictionary 应包含 hero_cur_mp")
	assertions.assert_eq(serialized.get("last_inn_id", ""), "foot_village_inn", "to_dictionary 应包含 last_inn_id")

	var restored_state = GameStateScript.new()
	restored_state.from_dictionary(serialized)
	assertions.assert_eq(restored_state.hero_cur_mp, game_state.hero_max_mp - 7, "读档应恢复 hero_cur_mp")
	assertions.assert_eq(restored_state.last_inn_id, "foot_village_inn", "读档应恢复 last_inn_id")

	# 老存档兼容（无 hero_cur_mp / last_inn_id 字段）
	var old_state = GameStateScript.new()
	old_state.from_dictionary({
		"party": game_state.party.to_dictionary(),
		"quests": game_state.quest_system.to_dictionary(),
		"map_state": game_state.map_state.to_dictionary(),
		"journal_state": game_state.journal_state.to_dictionary(),
		"flags": game_state.flags.duplicate(true),
		"hero_hp": 80,
		"hero_max_hp": 120,
		"hero_max_mp": 20,
		"martial_proficiency": {},
	})
	assertions.assert_eq(old_state.hero_cur_mp, 20, "老存档无 hero_cur_mp 应兜底为 hero_max_mp")
	assertions.assert_eq(old_state.last_inn_id, "", "老存档无 last_inn_id 应兜底为空串")
