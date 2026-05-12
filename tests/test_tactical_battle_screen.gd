extends RefCounted

const BATTLE_SCREEN_PATH := "res://scripts/scenes/battle_screen.gd"

func run(assertions) -> void:
	var BattleScreenScript = load(BATTLE_SCREEN_PATH)
	assertions.assert_true(BattleScreenScript != null, "应存在战斗界面脚本")
	if BattleScreenScript == null:
		return
	assertions.assert_true(BattleScreenScript.can_instantiate(), "战斗界面脚本应可实例化")
	if not BattleScreenScript.can_instantiate():
		return

	var root = Engine.get_main_loop().root
	var repository = root.get_node("DataRepository")
	var game_state = root.get_node("GameState")
	repository.load_all()
	game_state.start_new_game()
	game_state.set_battle_context({
		"battle_mode": "tactical",
		"source_map_id": "mountain_pass",
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
		"battlefield": {"width": 7, "height": 5},
		"time_mode": "pause_on_action",
		"units": [
			{"unit_id": "hero", "actor_id": "hero_yun", "team": "player", "start_cell": {"q": 1, "r": 2}, "move_range": 3, "attack_range": 1, "charge_speed": 240},
			{"unit_id": "bandit", "actor_id": "bandit_01", "team": "enemy", "start_cell": {"q": 5, "r": 2}, "move_range": 3, "attack_range": 1, "charge_speed": 220},
			{"unit_id": "bandit_lackey", "actor_id": "bandit_lackey_01", "team": "enemy", "start_cell": {"q": 5, "r": 3}, "move_range": 3, "attack_range": 1, "charge_speed": 260}
		]
	})

	var screen = BattleScreenScript.new()
	screen._ready()

	assertions.assert_true(_has_property(screen, "is_tactical_mode"), "战斗界面应暴露战棋模式标记")
	assertions.assert_true(_has_property(screen, "tactical_battle_state"), "战斗界面应暴露战棋状态")
	assertions.assert_true(_has_property(screen, "grid_layer"), "战斗界面应暴露战棋格子层")
	assertions.assert_true(_has_property(screen, "status_label"), "战斗界面应暴露战棋状态文本")
	assertions.assert_true(_has_property(screen, "end_action_button"), "战斗界面应暴露结束行动按钮")
	assertions.assert_true(_has_property(screen, "cell_buttons"), "战斗界面应暴露格子按钮字典")
	assertions.assert_true(_has_property(screen, "tactical_combat_system"), "战斗界面应暴露战棋系统")
	assertions.assert_true(screen.has_method("_refresh_tactical"), "战斗界面应提供战棋刷新方法")
	if not _has_property(screen, "is_tactical_mode") or not screen.has_method("_refresh_tactical"):
		screen.free()
		return

	assertions.assert_true(screen.is_tactical_mode, "battle_mode 为 tactical 时应进入战棋模式")
	assertions.assert_true(screen.tactical_battle_state != null, "战棋模式应创建战棋状态")
	assertions.assert_true(screen.grid_layer != null, "战棋模式应创建格子层")
	assertions.assert_true(screen.status_label != null, "战棋模式应创建状态文本")
	assertions.assert_true(screen.end_action_button != null, "战棋模式应创建结束行动按钮")
	assertions.assert_eq(screen.tactical_battle_state.units.size(), 3, "战棋场景应创建 3 个单位")
	assertions.assert_true(screen.cell_buttons.size() >= 35, "7x5 战场应创建至少 35 个格子按钮")
	assertions.assert_true(screen.item_button == null or not screen.item_button.visible, "战棋模式不应显示小还丹按钮")
	assertions.assert_eq(screen.cell_buttons.get("0:0").size, Vector2(64, 64), "战棋格子应使用 64x64 方格按钮")
	assertions.assert_true(screen.cell_buttons.get("0:0").flat, "战棋格子按钮应使用扁平样式避免默认黑块")
	var origin_cell = screen._cell_to_screen({"q": 0, "r": 0})
	assertions.assert_eq(screen._cell_to_screen({"q": 1, "r": 0}) - origin_cell, Vector2(64, 0), "方格战棋 q 轴应水平递增")
	assertions.assert_eq(screen._cell_to_screen({"q": 0, "r": 1}) - origin_cell, Vector2(0, 64), "方格战棋 r 轴应垂直递增")

	screen.tactical_combat_system.advance_charge(screen.tactical_battle_state, 5.0)
	screen._refresh_tactical()
	assertions.assert_eq(screen.status_label.text, "云游少侠行动", "主角满集气后状态文本应显示主角行动")

	screen.free()

func _has_property(target, property_name: String) -> bool:
	for property in target.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false
