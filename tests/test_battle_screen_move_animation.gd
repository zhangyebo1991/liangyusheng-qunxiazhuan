extends RefCounted

# Task 19 测试：移动滑动动画 + is_animating 锁。
# 1) TacticalUnitSprite 必须含 animate_to 方法 + animation_finished 信号。
# 2) BattleScreen 必须含 is_animating 字段、_start_move_animation、_on_move_animation_done 方法。
# 3) EventBus 必须含 tactical_unit_moved 信号。

const BATTLE_SCREEN_PATH := "res://scripts/scenes/battle_screen.gd"
const SPRITE_PATH := "res://scripts/scenes/tactical_unit_sprite.gd"
const EVENT_BUS_PATH := "res://scripts/core/event_bus.gd"

class UnitStub:
	extends RefCounted
	var unit_id: String
	var team: String
	var cell: Dictionary
	var hp: int
	var attack_range: int

	func _init(new_unit_id: String, new_team: String, q: int, r: int, new_hp: int, new_attack_range: int) -> void:
		unit_id = new_unit_id
		team = new_team
		cell = {"q": q, "r": r}
		hp = new_hp
		attack_range = new_attack_range

	func is_alive() -> bool:
		return hp > 0

class TacticalBattleStateStub:
	extends RefCounted
	var units: Array = []
	var is_finished := false
	var is_action_phase := true
	var current_unit_id: String = ""

	func add_unit(unit) -> void:
		units.append(unit)

	func get_unit(unit_id: String):
		for unit in units:
			if str(unit.unit_id) == unit_id:
				return unit
		return null

class TacticalCombatSystemStub:
	extends RefCounted
	var attack_calls := 0
	var end_action_calls := 0

	func attack_unit(battle, _attacker_id: String, defender_id: String) -> Dictionary:
		attack_calls += 1
		var defender = battle.get_unit(defender_id)
		if defender == null or not defender.is_alive():
			return {"success": false}
		defender.hp = max(0, int(defender.hp) - 7)
		return {"success": true, "damage": 7}

	func end_unit_action(battle, _unit_id: String) -> Dictionary:
		end_action_calls += 1
		battle.is_action_phase = false
		return {"success": true}

class FeedbackDirectorStub:
	extends RefCounted
	var enqueue_count := 0
	var consume_history: Array = []
	var _queue: Array = []

	func enqueue(event: Dictionary) -> void:
		enqueue_count += 1
		var event_type := str(event.get("type", ""))
		if event_type == "hit_start":
			_queue.append({"cmd": "hitstop", "ms": 20})
			return
		if event_type == "hp_changed":
			var unit_id := str(event.get("unit_id", ""))
			var delta := int(event.get("delta", 0))
			_queue.append({"cmd": "flash_unit", "unit_id": unit_id})
			_queue.append({"cmd": "pop_text", "unit_id": unit_id, "delta": delta})

	func consume_commands() -> Array:
		var output := _queue.duplicate(true)
		_queue.clear()
		consume_history.append(output.duplicate(true))
		return output

func run(assertions) -> void:
	var SpriteScript = load(SPRITE_PATH)
	assertions.assert_true(SpriteScript != null, "应存在 tactical_unit_sprite.gd")
	if SpriteScript != null:
		var sprite_methods := _collect_method_names(SpriteScript)
		assertions.assert_true(sprite_methods.has("animate_to"), "TacticalUnitSprite 应含 animate_to")
		var sprite_signals := _collect_signal_names(SpriteScript)
		assertions.assert_true(sprite_signals.has("animation_finished"), "TacticalUnitSprite 应含 animation_finished 信号")

	var BattleScreenScript = load(BATTLE_SCREEN_PATH)
	assertions.assert_true(BattleScreenScript != null, "应存在 battle_screen.gd")
	if BattleScreenScript != null:
		var bs_methods := _collect_method_names(BattleScreenScript)
		for name in ["_start_move_animation", "_on_move_animation_done", "_cell_in_list", "_emit_feedback_event", "_apply_feedback_commands"]:
			assertions.assert_true(bs_methods.has(name), "BattleScreen 应含方法 %s" % name)
		var bs_props := _collect_property_names(BattleScreenScript)
		assertions.assert_true(bs_props.has("is_animating"), "BattleScreen 应含字段 is_animating")
		assertions.assert_true(bs_props.has("_feedback_director"), "BattleScreen 应含字段 _feedback_director")
		_assert_feedback_does_not_break_enemy_followup(assertions, BattleScreenScript)

	var EventBusScript = load(EVENT_BUS_PATH)
	assertions.assert_true(EventBusScript != null, "应存在 event_bus.gd")
	if EventBusScript != null:
		var bus_signals := _collect_signal_names(EventBusScript)
		assertions.assert_true(bus_signals.has("tactical_unit_moved"), "EventBus 应含 tactical_unit_moved 信号")

func _assert_feedback_does_not_break_enemy_followup(assertions, BattleScreenScript) -> void:
	var battle_screen = BattleScreenScript.new()
	var state_stub = TacticalBattleStateStub.new()
	var enemy_unit = UnitStub.new("enemy_1", "enemy", 0, 0, 30, 1)
	var hero_unit = UnitStub.new("hero_1", "player", 1, 0, 40, 1)
	state_stub.add_unit(enemy_unit)
	state_stub.add_unit(hero_unit)

	var combat_stub = TacticalCombatSystemStub.new()
	var feedback_stub = FeedbackDirectorStub.new()
	battle_screen.tactical_battle_state = state_stub
	battle_screen.tactical_combat_system = combat_stub
	battle_screen._feedback_director = feedback_stub
	state_stub.current_unit_id = "enemy_1"

	battle_screen._resolve_enemy_post_move("enemy_1")

	assertions.assert_eq(combat_stub.attack_calls, 1, "敌方后续结算应触发一次攻击")
	assertions.assert_eq(combat_stub.end_action_calls, 1, "反馈执行后仍应结束敌方行动")
	assertions.assert_true(not state_stub.is_action_phase, "反馈执行后仍应推进到行动结束状态")
	assertions.assert_eq(int(hero_unit.hp), 33, "敌方命中后应完成扣血结算")
	assertions.assert_eq(feedback_stub.enqueue_count, 2, "敌方命中应发出 hit_start 与 hp_changed 两个反馈事件")
	assertions.assert_eq(feedback_stub.consume_history.size(), 1, "同一动作反馈应在单次 consume 内完成")
	var consumed_batch: Array = feedback_stub.consume_history[0]
	assertions.assert_eq(consumed_batch.size(), 3, "单次 consume 应输出 hitstop/flash/pop_text 三条命令")
	assertions.assert_eq(str(consumed_batch[0].get("cmd", "")), "hitstop", "第一条命令应为 hitstop")
	assertions.assert_eq(str(consumed_batch[1].get("cmd", "")), "flash_unit", "第二条命令应为 flash_unit")
	assertions.assert_eq(str(consumed_batch[2].get("cmd", "")), "pop_text", "第三条命令应为 pop_text")
	assertions.assert_eq(str(consumed_batch[1].get("unit_id", "")), "hero_1", "flash_unit 目标应为受击单位")
	assertions.assert_eq(str(consumed_batch[2].get("unit_id", "")), "hero_1", "pop_text 目标应为受击单位")
	assertions.assert_eq(int(consumed_batch[2].get("delta", 0)), -7, "pop_text 应携带本次扣血 delta")
	assertions.assert_eq(int(battle_screen.range_mode), int(BattleScreenScript.RangeMode.NONE), "反馈执行后不应破坏范围模式收敛")
	battle_screen.free()

func _collect_method_names(script) -> Dictionary:
	var result: Dictionary = {}
	for m in script.get_script_method_list():
		result[str(m.get("name", ""))] = true
	return result

func _collect_signal_names(script) -> Dictionary:
	var result: Dictionary = {}
	for s in script.get_script_signal_list():
		result[str(s.get("name", ""))] = true
	return result

func _collect_property_names(script) -> Dictionary:
	var result: Dictionary = {}
	for p in script.get_script_property_list():
		result[str(p.get("name", ""))] = true
	return result
