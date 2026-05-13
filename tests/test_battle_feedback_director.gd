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

	director.enqueue({"type": "unknown", "unit_id": "enemy_1"})
	var unknown_commands: Array = director.consume_commands()
	assertions.assert_eq(unknown_commands.size(), 0, "未知类型不应产生命令")

	director.enqueue({"type": "hp_changed", "delta": -9})
	var missing_unit_id_commands: Array = director.consume_commands()
	assertions.assert_eq(missing_unit_id_commands.size(), 0, "缺失 unit_id 的 hp_changed 不应产生命令")

	director.enqueue({"type": "hit_start", "unit_id": "hero"})
	director.enqueue({"type": "hit_start", "unit_id": "hero"})
	director.enqueue({"type": "hit_start", "unit_id": "hero"})
	var capped_hitstop_commands: Array = director.consume_commands()
	assertions.assert_eq(capped_hitstop_commands.size(), 2, "同帧连续 3 次 hit_start 仅应产出 2 条 hitstop")
	assertions.assert_eq(str(capped_hitstop_commands[0].get("cmd", "")), "hitstop", "预算内命令应为 hitstop")
	assertions.assert_eq(str(capped_hitstop_commands[1].get("cmd", "")), "hitstop", "预算内命令应为 hitstop")
	assertions.assert_eq(int(capped_hitstop_commands[0].get("ms", 0)), 60, "第一条 hitstop 时长应精确为 60ms")
	assertions.assert_eq(int(capped_hitstop_commands[1].get("ms", 0)), 60, "第二条 hitstop 时长应精确为 60ms")

	director.enqueue({"type": "hit_start", "unit_id": "hero"})
	director.enqueue({"type": "hit_start", "unit_id": "hero"})
	director.enqueue({"type": "hit_start", "unit_id": "hero"})
	director.enqueue({"type": "hit_start", "unit_id": "hero"})
	var exhausted_budget_commands: Array = director.consume_commands()
	assertions.assert_eq(exhausted_budget_commands.size(), 2, "预算耗尽后 clamped_ms <= 0 的 hit_start 不应入队")
	assertions.assert_eq(int(exhausted_budget_commands[0].get("ms", 0)), 60, "预算耗尽分支前的首条 hitstop 应为 60ms")
	assertions.assert_eq(int(exhausted_budget_commands[1].get("ms", 0)), 60, "预算耗尽分支前的次条 hitstop 应为 60ms")

	director.enqueue({"type": "hit_start", "unit_id": "hero"})
	director.enqueue({"type": "hit_start", "unit_id": "hero"})
	director.enqueue({"type": "hit_start", "unit_id": "hero"})
	var reset_hitstop_commands: Array = director.consume_commands()
	var total_reset_hitstop_ms := 0
	for command in reset_hitstop_commands:
		if str(command.get("cmd", "")) == "hitstop":
			total_reset_hitstop_ms += int(command.get("ms", 0))
	assertions.assert_true(total_reset_hitstop_ms <= 120, "consume 后应重置预算，下一帧仍不超过 120ms")

	director.enqueue({"type": "hit_start", "unit_id": "hero"})
	var commands_after_enqueue: Array = director.consume_commands()
	assertions.assert_eq(commands_after_enqueue.size(), 1, "首次 consume 应返回已入队命令")
	var commands_after_second_consume: Array = director.consume_commands()
	assertions.assert_eq(commands_after_second_consume.size(), 0, "consume 后再次 consume 应为空")