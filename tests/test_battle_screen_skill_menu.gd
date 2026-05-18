extends RefCounted

# Task 17 退化版测试：仅断言 BattleScreen 含有招式菜单 + 方向箭头相关方法。
# 完整 UI 路径需要 SceneTree 实例化，留待手动 UAT 覆盖。

const BATTLE_SCREEN_PATH := "res://scripts/scenes/battle_screen.gd"
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const ProficiencySystemScript = preload("res://scripts/systems/proficiency_system.gd")
const TacticalBattleStateScript = preload("res://scripts/domain/tactical_battle_state.gd")

func run(assertions) -> void:
	var BattleScreenScript = load(BATTLE_SCREEN_PATH)
	assertions.assert_true(BattleScreenScript != null, "应存在战斗界面脚本")
	if BattleScreenScript == null:
		return
	var method_names := _collect_method_names(BattleScreenScript)
	for name in [
		"_open_skill_menu",
		"_skill_shape_for_data",
		"_connect_tactical_proficiency",
		"_on_skill_chosen",
		"_show_direction_arrows",
		"_clear_direction_arrows",
		"_on_direction_chosen",
		"_resolve_skill_action",
		"_cancel_pending_auto_action_for_manual_mode",
	]:
		assertions.assert_true(method_names.has(name), "BattleScreen 应含方法 %s" % name)

	var repo = DataRepositoryScript.new()
	repo.load_all()
	var battle_screen = BattleScreenScript.new()
	assertions.assert_eq(battle_screen._skill_shape_for_data(repo.get_martial_art("basic_sword")), "diamond", "技能菜单应从 tactical.range_shape 识别基础剑法")
	assertions.assert_eq(battle_screen._skill_shape_for_data(repo.get_martial_art("sword_willow_sweep")), "fan", "技能菜单应优先识别顶层 shape")

	var game_state = _get_game_state_autoload()
	assertions.assert_true(game_state != null, "测试应能取得 GameState autoload")
	if game_state == null:
		battle_screen.free()
		repo.free()
		return
	var original_proficiency: Dictionary = game_state.martial_proficiency.duplicate(true)
	game_state.martial_proficiency = {}
	battle_screen._proficiency_system = ProficiencySystemScript.new()
	battle_screen._connect_tactical_proficiency()
	battle_screen.tactical_combat_system._proficiency_system.add_use(battle_screen.tactical_combat_system._proficiency_map, "basic_sword")
	assertions.assert_eq(int(game_state.martial_proficiency.get("basic_sword", 0)), 1, "BattleScreen 应把 GameState.martial_proficiency 注入战棋结算系统")
	game_state.martial_proficiency = original_proficiency
	_assert_auto_mode_status_and_cancel(assertions, BattleScreenScript)
	battle_screen.free()
	repo.free()

func _assert_auto_mode_status_and_cancel(assertions, BattleScreenScript) -> void:
	var battle_screen = BattleScreenScript.new()
	var state = TacticalBattleStateScript.new()
	battle_screen.tactical_battle_state = state
	battle_screen.status_label = Label.new()
	state.auto_battle_mode.set_auto(false)
	battle_screen._update_mode_ui()
	assertions.assert_true(str(battle_screen.status_label.text).contains("手动"), "模式状态应显示手动")
	state.auto_battle_mode.set_auto(true)
	battle_screen._update_mode_ui()
	assertions.assert_true(str(battle_screen.status_label.text).contains("自动"), "模式状态应显示自动")
	battle_screen._pending_auto_unit_id = "hero_yun"
	battle_screen._auto_action_step = 2
	battle_screen._auto_action_data = {"unit_id": "hero_yun"}
	battle_screen._cancel_pending_auto_action_for_manual_mode()
	assertions.assert_eq(battle_screen._pending_auto_unit_id, "", "切回手动应清除待执行自动行动")
	assertions.assert_eq(battle_screen._auto_action_step, 0, "切回手动应清除自动行动步骤")
	battle_screen.free()

func _get_game_state_autoload():
	var loop = Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null("GameState")

func _collect_method_names(script) -> Dictionary:
	var result: Dictionary = {}
	for m in script.get_script_method_list():
		result[str(m.get("name", ""))] = true
	return result
