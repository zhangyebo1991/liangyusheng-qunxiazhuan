extends RefCounted

const DirectorScript = preload("res://scripts/systems/battle_feedback_director.gd")

func run(assertions) -> void:
	var director = DirectorScript.new()

	director.enqueue({"type": "hit_start", "unit_id": "hero"})
	var hit_commands: Array = director.consume_commands()
	assertions.assert_eq(hit_commands.size(), 1, "命中起手应产出一个反馈命令")
	assertions.assert_eq(str(hit_commands[0].get("cmd", "")), "hitstop", "hit_start 应产出 hitstop")

	director.enqueue({"type": "hp_changed", "unit_id": "enemy_1", "delta": -18})
	var hp_commands: Array = director.consume_commands()
	assertions.assert_eq(hp_commands.size(), 2, "气血变化应产出两条反馈命令")
	assertions.assert_eq(str(hp_commands[0].get("cmd", "")), "flash_unit", "hp_changed 第一条应为 flash_unit")
	assertions.assert_eq(str(hp_commands[0].get("unit_id", "")), "enemy_1", "flash_unit 应绑定受击单位")
	assertions.assert_eq(str(hp_commands[1].get("cmd", "")), "pop_text", "hp_changed 第二条应为 pop_text")
	assertions.assert_eq(int(hp_commands[1].get("delta", 0)), -18, "pop_text 应携带气血变化值")