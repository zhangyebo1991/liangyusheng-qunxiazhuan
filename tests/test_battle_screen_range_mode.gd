extends RefCounted

# Task 11 退化版测试：仅断言 BattleScreen.RangeMode 枚举常量存在且取值正确。
# 用 load() 而非 preload，规避 autoload 在预载阶段未就绪的编译失败。

const BATTLE_SCREEN_PATH := "res://scripts/scenes/battle_screen.gd"

func run(assertions) -> void:
	var BattleScreenScript = load(BATTLE_SCREEN_PATH)
	assertions.assert_true(BattleScreenScript != null, "应存在战斗界面脚本")
	if BattleScreenScript == null:
		return
	assertions.assert_eq(BattleScreenScript.RangeMode.NONE, 0, "RangeMode.NONE 应为 0")
	assertions.assert_eq(BattleScreenScript.RangeMode.MOVE, 1, "RangeMode.MOVE 应为 1")
	assertions.assert_eq(BattleScreenScript.RangeMode.ATTACK, 2, "RangeMode.ATTACK 应为 2")
	assertions.assert_eq(BattleScreenScript.RangeMode.SKILL_DIR_PREVIEW, 3, "RangeMode.SKILL_DIR_PREVIEW 应为 3")
	assertions.assert_eq(BattleScreenScript.RangeMode.SKILL_TARGET_PREVIEW, 4, "RangeMode.SKILL_TARGET_PREVIEW 应为 4")

