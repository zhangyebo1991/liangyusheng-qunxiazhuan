extends RefCounted

# Task 18 测试：目标型技能选中心格交互。
# 1) 验 tactical_range_system.get_skill_target_blast_range 对 sword_aura_swirl 中心 (3,3) 返回十字 5 格。
# 2) 验 BattleScreen 含 _resolve_skill_action 方法 + _pending_skill_id / range_mode 字段。
# 3) 验 RangeMode.SKILL_TARGET_PREVIEW = 4 与 spec 一致。

const BATTLE_SCREEN_PATH := "res://scripts/scenes/battle_screen.gd"
const TacticalRangeSystemScript = preload("res://scripts/systems/tactical_range_system.gd")

func run(assertions) -> void:
	# ── 1) 范围算法
	var rs = TacticalRangeSystemScript.new()
	var blast: Array = rs.get_skill_target_blast_range("sword_aura_swirl", Vector2i(3, 3))
	assertions.assert_eq(blast.size(), 5, "十字爆炸应返回 5 格（中心 + 上下左右）")
	var as_set: Dictionary = {}
	for c in blast:
		as_set[c] = true
	for expected in [Vector2i(3, 3), Vector2i(2, 3), Vector2i(4, 3), Vector2i(3, 2), Vector2i(3, 4)]:
		assertions.assert_true(as_set.has(expected), "应包含格 %s" % expected)
	# ── 2) BattleScreen 字段/方法/枚举
	var BattleScreenScript = load(BATTLE_SCREEN_PATH)
	assertions.assert_true(BattleScreenScript != null, "应存在战斗界面脚本")
	if BattleScreenScript == null:
		return
	assertions.assert_eq(BattleScreenScript.RangeMode.SKILL_TARGET_PREVIEW, 4, "RangeMode.SKILL_TARGET_PREVIEW 应为 4")
	var method_names := _collect_method_names(BattleScreenScript)
	assertions.assert_true(method_names.has("_resolve_skill_action"), "BattleScreen 应含 _resolve_skill_action")
	var prop_names := _collect_property_names(BattleScreenScript)
	assertions.assert_true(prop_names.has("_pending_skill_id"), "BattleScreen 应含字段 _pending_skill_id")

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
