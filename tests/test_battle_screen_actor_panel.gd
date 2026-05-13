extends RefCounted

const BATTLE_SCREEN_PATH := "res://scripts/scenes/battle_screen.gd"

class PanelActorStub:
	extends RefCounted
	var visible := true
	var last_actor = null

	func set_actor(actor) -> void:
		last_actor = actor

class UnitStub:
	extends RefCounted
	var unit_id: String
	var team: int

	func _init(new_unit_id: String, new_team: int) -> void:
		unit_id = new_unit_id
		team = new_team

class TacticalBattleStateStub:
	extends RefCounted
	var current_unit_id: String = ""
	var _units: Dictionary = {}

	func add_unit(unit) -> void:
		_units[unit.unit_id] = unit

	func get_unit(unit_id: String):
		return _units.get(unit_id, null)

func run(assertions) -> void:
	var BattleScreenScript = load(BATTLE_SCREEN_PATH)
	assertions.assert_true(BattleScreenScript != null, "应存在战斗界面脚本")
	if BattleScreenScript == null:
		return

	var battle_screen = BattleScreenScript.new()
	var panel_stub = PanelActorStub.new()
	var state_stub = TacticalBattleStateStub.new()
	var enemy_unit = UnitStub.new("bandit", 1)
	state_stub.add_unit(enemy_unit)
	battle_screen.panel_actor = panel_stub
	battle_screen.tactical_battle_state = state_stub

	state_stub.current_unit_id = "bandit"
	battle_screen._refresh_actor_panel()
	assertions.assert_true(panel_stub.visible, "有当前行动角色时状态卡应显示")
	assertions.assert_eq(panel_stub.last_actor, enemy_unit, "状态卡应显示当前行动角色，而不是固定回退到主角")

	state_stub.current_unit_id = ""
	panel_stub.visible = true
	panel_stub.last_actor = enemy_unit
	battle_screen._refresh_actor_panel()
	assertions.assert_true(not panel_stub.visible, "无人行动时状态卡应隐藏")
	assertions.assert_eq(panel_stub.last_actor, null, "无人行动时状态卡应清空角色数据")
	battle_screen.free()
