extends RefCounted

# Task 17 退化版测试：仅断言 BattleScreen 含有招式菜单 + 方向箭头相关方法。
# 完整 UI 路径需要 SceneTree 实例化，留待手动 UAT 覆盖。

const BATTLE_SCREEN_PATH := "res://scripts/scenes/battle_screen.gd"

func run(assertions) -> void:
	var BattleScreenScript = load(BATTLE_SCREEN_PATH)
	assertions.assert_true(BattleScreenScript != null, "应存在战斗界面脚本")
	if BattleScreenScript == null:
		return
	var method_names := _collect_method_names(BattleScreenScript)
	for name in [
		"_open_skill_menu",
		"_on_skill_chosen",
		"_show_direction_arrows",
		"_clear_direction_arrows",
		"_on_direction_chosen",
		"_resolve_skill_action",
	]:
		assertions.assert_true(method_names.has(name), "BattleScreen 应含方法 %s" % name)

func _collect_method_names(script) -> Dictionary:
	var result: Dictionary = {}
	for m in script.get_script_method_list():
		result[str(m.get("name", ""))] = true
	return result
