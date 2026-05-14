extends RefCounted

const BATTLE_SCREEN_PATH := "res://scripts/scenes/battle_screen.gd"

func run(assertions) -> void:
	var BattleScreenScript = load(BATTLE_SCREEN_PATH)
	assertions.assert_true(BattleScreenScript != null, "应存在战斗界面脚本")
	if BattleScreenScript == null:
		return
	var methods := _collect_method_names(BattleScreenScript)
	for name in ["_show_reward_panel", "_reward_text", "_on_reward_return_pressed"]:
		assertions.assert_true(methods.has(name), "BattleScreen 应含奖励面板方法 %s" % name)
	var props := _collect_property_names(BattleScreenScript)
	for name in ["reward_panel", "reward_label", "reward_return_button"]:
		assertions.assert_true(props.has(name), "BattleScreen 应含奖励面板字段 %s" % name)

	var screen = BattleScreenScript.new()
	var text = screen._reward_text({
		"experience": [
			{"actor_id": "hero_yun", "exp_gained": 20, "old_level": 1, "new_level": 2, "leveled_up": true}
		],
		"coins": 15,
		"items": [{"item_id": "herb_small", "amount": 1}]
	})
	assertions.assert_true(text.find("云游少侠 +20 经验") >= 0, "奖励文本应显示中文角色名和经验")
	assertions.assert_true(text.find("升至 2 级") >= 0, "奖励文本应显示升级")
	assertions.assert_true(text.find("气血内力已回满") >= 0, "奖励文本应显示升级回满")
	assertions.assert_true(text.find("15 文") >= 0, "奖励文本应显示铜钱")
	assertions.assert_true(text.find("小还丹 x1") >= 0, "奖励文本应显示中文物品名和掉落明细")
	screen.free()

func _collect_method_names(script) -> Dictionary:
	var result: Dictionary = {}
	for method in script.get_script_method_list():
		result[str(method.get("name", ""))] = true
	return result

func _collect_property_names(script) -> Dictionary:
	var result: Dictionary = {}
	for property in script.get_script_property_list():
		result[str(property.get("name", ""))] = true
	return result