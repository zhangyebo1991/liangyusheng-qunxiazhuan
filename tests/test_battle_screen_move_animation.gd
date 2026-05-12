extends RefCounted

# Task 19 测试：移动滑动动画 + is_animating 锁。
# 1) TacticalUnitSprite 必须含 animate_to 方法 + animation_finished 信号。
# 2) BattleScreen 必须含 is_animating 字段、_start_move_animation、_on_move_animation_done 方法。
# 3) EventBus 必须含 tactical_unit_moved 信号。

const BATTLE_SCREEN_PATH := "res://scripts/scenes/battle_screen.gd"
const SPRITE_PATH := "res://scripts/scenes/tactical_unit_sprite.gd"
const EVENT_BUS_PATH := "res://scripts/core/event_bus.gd"

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
		for name in ["_start_move_animation", "_on_move_animation_done", "_cell_in_list"]:
			assertions.assert_true(bs_methods.has(name), "BattleScreen 应含方法 %s" % name)
		var bs_props := _collect_property_names(BattleScreenScript)
		assertions.assert_true(bs_props.has("is_animating"), "BattleScreen 应含字段 is_animating")

	var EventBusScript = load(EVENT_BUS_PATH)
	assertions.assert_true(EventBusScript != null, "应存在 event_bus.gd")
	if EventBusScript != null:
		var bus_signals := _collect_signal_names(EventBusScript)
		assertions.assert_true(bus_signals.has("tactical_unit_moved"), "EventBus 应含 tactical_unit_moved 信号")

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
