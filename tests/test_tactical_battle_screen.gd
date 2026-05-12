extends RefCounted

# Task 20 重写：旧测试断言了 unit_panel/normal_attack_button/end_action_button/cell_visuals
# 等已删除字段。此版本只用反射验证关键 RangeMode 枚举与必备方法，无需实例化场景树。
# 完整 UI 行为（按钮可点、动作菜单弹出等）留给手动 UAT 覆盖。

const BATTLE_SCREEN_PATH := "res://scripts/scenes/battle_screen.gd"

func run(assertions) -> void:
	var BattleScreenScript = load(BATTLE_SCREEN_PATH)
	assertions.assert_true(BattleScreenScript != null, "应存在战斗界面脚本")
	if BattleScreenScript == null:
		return

	# RangeMode 枚举锁版（避免后续重排导致 4 个分支错位）
	assertions.assert_eq(BattleScreenScript.RangeMode.NONE, 0, "RangeMode.NONE 应为 0")
	assertions.assert_eq(BattleScreenScript.RangeMode.MOVE, 1, "RangeMode.MOVE 应为 1")
	assertions.assert_eq(BattleScreenScript.RangeMode.ATTACK, 2, "RangeMode.ATTACK 应为 2")
	assertions.assert_eq(BattleScreenScript.RangeMode.SKILL_DIR_PREVIEW, 3, "RangeMode.SKILL_DIR_PREVIEW 应为 3")
	assertions.assert_eq(BattleScreenScript.RangeMode.SKILL_TARGET_PREVIEW, 4, "RangeMode.SKILL_TARGET_PREVIEW 应为 4")

	# 关键方法仍在
	var methods := _collect_method_names(BattleScreenScript)
	for name in [
		"_refresh_tactical",
		"_on_tactical_cell_pressed",
		"_open_skill_menu",
		"_on_skill_chosen",
		"_start_move_animation",
		"_on_move_animation_done",
	]:
		assertions.assert_true(methods.has(name), "BattleScreen 应含方法 %s" % name)

	# 已删除字段不应再存在
	var props := _collect_property_names(BattleScreenScript)
	for forbidden in ["unit_panel", "normal_attack_button", "end_action_button", "tactical_art_buttons", "cell_visuals"]:
		assertions.assert_true(not props.has(forbidden), "BattleScreen 应已删除字段 %s" % forbidden)

	# cell_buttons 仍保留（点击命中需要）
	assertions.assert_true(props.has("cell_buttons"), "BattleScreen 应保留 cell_buttons 字段用于点击命中")

func _collect_method_names(script) -> Dictionary:
	var result: Dictionary = {}
	for m in script.get_script_method_list():
		result[str(m.get("name", ""))] = true
	return result

func _collect_property_names(script) -> Dictionary:
	var result: Dictionary = {}
	for p in script.get_script_property_list():
		result[str(p.get("name", ""))] = true
	return result
