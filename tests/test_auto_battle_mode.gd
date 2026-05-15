extends RefCounted

func run(assertions) -> void:
	# --- AutoBattleMode 基础测试 ---
	var mode = AutoBattleMode.new()
	assertions.assert_false(mode.is_auto, "默认应为手动模式")

	# toggle 切换
	mode.toggle()
	assertions.assert_true(mode.is_auto, "切换后应为自动模式")
	mode.toggle()
	assertions.assert_false(mode.is_auto, "再次切换应为手动模式")

	# set_auto
	mode.set_auto(true)
	assertions.assert_true(mode.is_auto, "set_auto(true) 应设为自动模式")
	mode.set_auto(false)
	assertions.assert_false(mode.is_auto, "set_auto(false) 应设为手动模式")

	# to_dictionary
	mode.set_auto(true)
	var dict = mode.to_dictionary()
	assertions.assert_true(dict.get("is_auto", false), "序列化应包含 is_auto")

	# from_dictionary
	var mode2 = AutoBattleMode.new()
	mode2.from_dictionary({"is_auto": true})
	assertions.assert_true(mode2.is_auto, "反序列化应恢复 is_auto")

	# from_dictionary 缺少字段
	var mode3 = AutoBattleMode.new()
	mode3.from_dictionary({})
	assertions.assert_false(mode3.is_auto, "缺少字段时应默认为手动模式")

	# --- TacticalBattleState 集成测试 ---
	var battle = TacticalBattleState.new()
	assertions.assert_true(battle.auto_battle_mode != null, "战斗状态应包含 auto_battle_mode")
	assertions.assert_false(battle.auto_battle_mode.is_auto, "默认应为手动模式")

	# 序列化
	battle.auto_battle_mode.set_auto(true)
	var battle_dict = battle.to_dictionary()
	assertions.assert_true(
		battle_dict.get("auto_battle_mode", {}).get("is_auto", false),
		"序列化应包含 auto_battle_mode"
	)

	# to_result_dictionary 也应包含 auto_battle_mode
	var result_dict = battle.to_result_dictionary()
	assertions.assert_true(
		result_dict.get("auto_battle_mode", {}).get("is_auto", false),
		"结果序列化应包含 auto_battle_mode"
	)

	# load_from_dictionary
	var battle2 = TacticalBattleState.new()
	battle2.load_from_dictionary({
		"auto_battle_mode": {"is_auto": true}
	})
	assertions.assert_true(battle2.auto_battle_mode.is_auto, "反序列化应恢复 auto_battle_mode")

	# load_from_dictionary 缺少 auto_battle_mode
	var battle3 = TacticalBattleState.new()
	battle3.load_from_dictionary({})
	assertions.assert_false(battle3.auto_battle_mode.is_auto, "缺少字段时应默认为手动模式")
