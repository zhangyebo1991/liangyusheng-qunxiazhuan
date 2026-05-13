extends RefCounted

# Task 13 测试：charge_bar 数据驱动布局（不依赖 _draw）。
# 验证 x 偏移计算与 is_action 高亮标记。
# Task 5 回归：next 行动者预测与 tactical_combat_system 调度规则对齐。

const ChargeBarScript = preload("res://scripts/scenes/charge_bar.gd")
const BATTLE_SCREEN_PATH := "res://scripts/scenes/battle_screen.gd"
const TACTICAL_COMBAT_SYSTEM_PATH := "res://scripts/systems/tactical_combat_system.gd"
const TacticalBattleStateScript = preload("res://scripts/domain/tactical_battle_state.gd")

class UnitStub:
	extends RefCounted
	var unit_id: String = ""
	var team: String = TacticalBattleStateScript.TEAM_ENEMY
	var charge: int = 0
	var charge_speed: int = 1
	var hp: int = 1

	func _init(new_unit_id: String, new_team: String, new_charge: int, new_charge_speed: int) -> void:
		unit_id = new_unit_id
		team = new_team
		charge = new_charge
		charge_speed = new_charge_speed

	func is_alive() -> bool:
		return hp > 0

class TacticalBattleStateStub:
	extends RefCounted
	var units: Array = []

func run(assertions) -> void:
	var bar = ChargeBarScript.new()
	bar.bar_width = 1000
	var units = [
		{"unit_id": "hero", "team": 0, "cur_charge": 250, "is_action": false},
		{"unit_id": "e1", "team": 1, "cur_charge": 500, "is_action": false},
		{"unit_id": "e2", "team": 1, "cur_charge": 1000, "is_action": true},
		{"unit_id": "e3", "team": 1, "cur_charge": 750, "is_action": false, "is_next_action": true},
	]
	bar.set_units(units)
	assertions.assert_eq(bar.get_unit_x("hero"), 250, "250/1000 * 1000 = 250")
	assertions.assert_eq(bar.get_unit_x("e1"), 500, "500/1000 * 1000 = 500")
	assertions.assert_eq(bar.get_unit_x("e2"), 1000, "1000/1000 * 1000 = 1000")
	assertions.assert_eq(bar.get_unit_x("e3"), 750, "750/1000 * 1000 = 750")
	assertions.assert_true(bar.is_highlighted("e2"), "e2 应被高亮")
	assertions.assert_true(bar.is_secondary_highlighted("e3"), "e3 应为即将行动次高亮")
	assertions.assert_false(bar.is_secondary_highlighted("e2"), "当前行动单位不应标记为次高亮")
	assertions.assert_false(bar.is_highlighted("hero"), "hero 不应被高亮")
	assertions.assert_false(bar.is_highlighted("e1"), "e1 不应被高亮")
	assertions.assert_false(bar.is_secondary_highlighted("hero"), "hero 不应被次高亮")
	_run_task5_next_action_prediction_regression(assertions)
	bar.free()

func _run_task5_next_action_prediction_regression(assertions) -> void:
	var BattleScreenScript = load(BATTLE_SCREEN_PATH)
	assertions.assert_true(BattleScreenScript != null, "应存在战斗界面脚本")
	if BattleScreenScript == null:
		return
	var TacticalCombatSystemScript = load(TACTICAL_COMBAT_SYSTEM_PATH)
	assertions.assert_true(TacticalCombatSystemScript != null, "应存在战棋战斗系统脚本")
	if TacticalCombatSystemScript == null:
		return
	var battle_screen = BattleScreenScript.new()
	var tactical_system = TacticalCombatSystemScript.new()
	var charge_limit := TacticalBattleStateScript.CHARGE_LIMIT

	var eta_state = TacticalBattleStateStub.new()
	eta_state.units = [
		UnitStub.new("slow_player", TacticalBattleStateScript.TEAM_PLAYER, 900, 10),
		UnitStub.new("swift_enemy", TacticalBattleStateScript.TEAM_ENEMY, 100, 200),
	]
	battle_screen.tactical_battle_state = eta_state
	assertions.assert_eq(
		battle_screen._predict_next_charge_actor_id(""),
		"swift_enemy",
		"低 charge 但高 speed 的单位应因 eta 更小被预测为 next"
	)

	var ready_state = TacticalBattleStateStub.new()
	ready_state.units = [
		UnitStub.new("enemy_ready", TacticalBattleStateScript.TEAM_ENEMY, charge_limit, 120),
		UnitStub.new("player_ready_1", TacticalBattleStateScript.TEAM_PLAYER, charge_limit, 90),
		UnitStub.new("player_ready_2", TacticalBattleStateScript.TEAM_PLAYER, charge_limit, 80),
	]
	battle_screen.tactical_battle_state = ready_state
	var expected_ready = tactical_system.get_ready_unit(ready_state)
	assertions.assert_true(expected_ready != null, "ready 状态下调度器应返回行动单位")
	assertions.assert_eq(str(expected_ready.unit_id), "player_ready_1", "get_ready_unit 应先选玩家，再按 units 顺序")
	assertions.assert_eq(
		battle_screen._predict_next_charge_actor_id(""),
		str(expected_ready.unit_id),
		"battle_screen 的 ready 预测应与 get_ready_unit 规则一致"
	)
	assertions.assert_eq(
		battle_screen._predict_next_charge_actor_id("player_ready_1"),
		"player_ready_2",
		"排除当前行动者后，ready 顺序应继续遵循玩家优先与 units 顺序"
	)

	var eta_tie_state = TacticalBattleStateStub.new()
	eta_tie_state.units = [
		UnitStub.new("enemy_same_eta", TacticalBattleStateScript.TEAM_ENEMY, 800, 100),
		UnitStub.new("player_same_eta", TacticalBattleStateScript.TEAM_PLAYER, 600, 200),
	]
	battle_screen.tactical_battle_state = eta_tie_state
	assertions.assert_eq(
		battle_screen._predict_next_charge_actor_id(""),
		"player_same_eta",
		"eta 并列时应稳定按玩家优先，避免与调度器最终 ready 顺序漂移"
	)

	battle_screen.free()
