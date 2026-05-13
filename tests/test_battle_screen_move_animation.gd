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
		assertions.assert_true(sprite_methods.has("play_hit_feedback"), "TacticalUnitSprite 应含 play_hit_feedback")
		var sprite_signals := _collect_signal_names(SpriteScript)
		assertions.assert_true(sprite_signals.has("animation_finished"), "TacticalUnitSprite 应含 animation_finished 信号")
		_assert_hit_feedback_usable(assertions, SpriteScript)

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

func _assert_hit_feedback_usable(assertions, SpriteScript) -> void:
	var root = Engine.get_main_loop().root

	var sprite = SpriteScript.new()
	root.add_child(sprite)
	sprite.setup("test_unit", "", 20, false)

	var inner_sprite = sprite.get("_sprite")
	assertions.assert_true(inner_sprite != null, "受击反馈测试应能拿到内部 Sprite2D")
	if inner_sprite == null:
		sprite.queue_free()
		return

	var base_unit_pos: Vector2 = sprite.position
	var base_local_pos: Vector2 = inner_sprite.position
	var base_modulate: Color = inner_sprite.modulate

	# flash_sec=0 走同步归位分支：验证接口可调用且关键状态能回到基准值。
	sprite.play_hit_feedback(0.0, 6.0)
	assertions.assert_eq(sprite.position, base_unit_pos, "受击反馈不应改写单位锚点 position")
	assertions.assert_eq(inner_sprite.position, base_local_pos, "受击反馈结束后局部位置应归位")
	assertions.assert_eq(inner_sprite.modulate, base_modulate, "受击反馈结束后颜色应归位")

	# 非零时长分支：通过 custom_step 推进若干帧，覆盖 tween 主路径与方向分支。
	var enemy_sprite = SpriteScript.new()
	root.add_child(enemy_sprite)
	enemy_sprite.setup("enemy_unit", "", 20, true)
	var enemy_inner = enemy_sprite.get("_sprite")
	assertions.assert_true(enemy_inner != null, "敌方受击反馈测试应能拿到内部 Sprite2D")
	if enemy_inner == null:
		enemy_sprite.queue_free()
		sprite.queue_free()
		return
	var enemy_base_pos: Vector2 = enemy_inner.position
	var enemy_base_modulate: Color = enemy_inner.modulate

	sprite.play_hit_feedback(0.08, 6.0)
	enemy_sprite.play_hit_feedback(0.08, 6.0)
	var player_tween: Tween = sprite.get("_hit_feedback_tween")
	var enemy_tween: Tween = enemy_sprite.get("_hit_feedback_tween")
	assertions.assert_true(player_tween != null, "玩家受击反馈应创建 tween")
	assertions.assert_true(enemy_tween != null, "敌方受击反馈应创建 tween")

	if player_tween != null and enemy_tween != null:
		_step_tween_frames(player_tween, 2, 0.016)
		_step_tween_frames(enemy_tween, 2, 0.016)

	assertions.assert_true(inner_sprite.position.x < base_local_pos.x, "玩家受击应向左回弹")
	assertions.assert_true(enemy_inner.position.x > enemy_base_pos.x, "敌方受击应向右回弹")
	assertions.assert_eq(inner_sprite.position.y, base_local_pos.y, "玩家受击回弹仅应改变 X 方向")
	assertions.assert_eq(enemy_inner.position.y, enemy_base_pos.y, "敌方受击回弹仅应改变 X 方向")

	if player_tween != null and enemy_tween != null:
		_step_tween_frames(player_tween, 8, 0.016)
		_step_tween_frames(enemy_tween, 8, 0.016)

	assertions.assert_eq(sprite.position, base_unit_pos, "受击反馈 tween 完成后不应改写单位锚点")
	assertions.assert_eq(inner_sprite.position, base_local_pos, "玩家受击反馈 tween 完成后局部位置应归位")
	assertions.assert_eq(enemy_inner.position, enemy_base_pos, "敌方受击反馈 tween 完成后局部位置应归位")
	assertions.assert_eq(inner_sprite.modulate, base_modulate, "玩家受击反馈 tween 完成后颜色应归位")
	assertions.assert_eq(enemy_inner.modulate, enemy_base_modulate, "敌方受击反馈 tween 完成后颜色应归位")

	enemy_sprite.queue_free()
	sprite.queue_free()

func _step_tween_frames(tween: Tween, frame_count: int, delta: float) -> void:
	for _i in range(max(0, frame_count)):
		tween.custom_step(max(0.001, delta))

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
