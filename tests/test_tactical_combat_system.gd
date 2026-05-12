extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const TACTICAL_COMBAT_SYSTEM_PATH := "res://scripts/systems/tactical_combat_system.gd"

func run(assertions) -> void:
	var TacticalCombatSystemScript = load(TACTICAL_COMBAT_SYSTEM_PATH)
	assertions.assert_true(TacticalCombatSystemScript != null, "应存在战棋战斗系统脚本")
	if TacticalCombatSystemScript == null:
		return

	var repository = DataRepositoryScript.new()
	repository.load_all()
	var state = GameStateScript.new()
	state.start_new_game()
	state.hero_hp = 100

	var system = TacticalCombatSystemScript.new()
	system.set_repository(repository)

	var battle = system.create_battle(state, _sample_context(), repository)
	assertions.assert_eq(battle.units.size(), 3, "战棋战斗应创建 3 个单位")
	assertions.assert_eq(battle.get_unit("hero").hp, 100, "主角单位应读取当前 GameState 气血")
	assertions.assert_eq(battle.get_unit("bandit").display_name, "山道强人", "敌人单位应读取角色名")
	assertions.assert_eq(battle.source_object_id, "enemy_bandit_gate", "战棋战斗应保存来源对象")

	system.advance_charge(battle, 5.0)
	assertions.assert_eq(battle.current_unit_id, "hero", "主角和喽啰同时满集气时应优先玩家单位")
	assertions.assert_true(battle.is_action_phase, "单位满集气后应进入行动阶段")
	assertions.assert_eq(battle.get_unit("hero").charge, 1000, "集气达到上限后应钳制到 1000")

	var cells = system.get_movable_cells(battle, "hero")
	assertions.assert_true(_has_cell(cells, 1, 2), "可移动格应包含原地")
	assertions.assert_true(_has_cell(cells, 4, 2), "可移动格应包含移动力范围内的格子")
	assertions.assert_true(not _has_cell(cells, 5, 2), "可移动格不应包含敌方占用格")
	assertions.assert_true(not _has_cell(cells, 6, 2), "可移动格不应包含移动力范围外的格子")

	var attackable_before_move = system.get_attackable_units(battle, "hero")
	assertions.assert_eq(attackable_before_move.size(), 0, "主角未接近时不应有可攻击目标")

	system.move_unit(battle, "hero", {"q": 4, "r": 2})
	assertions.assert_eq(battle.get_unit("hero").cell.get("q", -1), 4, "移动后应更新 q 坐标")
	assertions.assert_eq(battle.get_unit("hero").cell.get("r", -1), 2, "移动后应更新 r 坐标")

	var attackable_after_move = system.get_attackable_units(battle, "hero")
	assertions.assert_eq(attackable_after_move.size(), 1, "移动后应能攻击相邻敌人")
	assertions.assert_eq(attackable_after_move[0].unit_id, "bandit", "可攻击目标应为山道强人")

	var attack_result = system.attack_unit(battle, "hero", "bandit")
	assertions.assert_true(bool(attack_result.get("success", false)), "攻击相邻敌人应成功")
	assertions.assert_eq(battle.get_unit("bandit").hp, 46, "普通攻击应按攻击减防御造成伤害")
	assertions.assert_true(battle.log.has("云游少侠攻击山道强人，造成14点伤害。"), "普通攻击应写入战斗日志")

	system.end_unit_action(battle, "hero")
	assertions.assert_eq(battle.get_unit("hero").charge, 0, "结束行动应清空当前单位集气")
	assertions.assert_true(not battle.is_action_phase, "结束行动后应恢复集气阶段")
	assertions.assert_eq(battle.current_unit_id, "", "结束行动后应清空当前行动单位")

	var enemy_battle = system.create_battle(state, _sample_context(), repository)
	enemy_battle.get_unit("bandit").cell = {"q": 2, "r": 2}
	enemy_battle.get_unit("hero").cell = {"q": 1, "r": 2}
	var ai_result = system.resolve_enemy_action(enemy_battle, "bandit")
	assertions.assert_true(bool(ai_result.get("success", false)), "敌人在攻击范围内应自动行动成功")
	assertions.assert_eq(enemy_battle.get_unit("hero").hp, 96, "敌人普通攻击应扣除主角气血")

	var finish_battle = system.create_battle(state, _sample_context(), repository)
	finish_battle.get_unit("bandit").hp = 1
	finish_battle.get_unit("lackey").hp = 0
	finish_battle.get_unit("hero").cell = {"q": 4, "r": 2}
	system.attack_unit(finish_battle, "hero", "bandit")
	assertions.assert_true(finish_battle.is_finished, "击败全部敌人后战棋应结束")
	assertions.assert_true(finish_battle.victory, "击败全部敌人后应标记胜利")
	var payload = finish_battle.to_result_dictionary()
	assertions.assert_eq(payload.get("source_object_id", ""), "enemy_bandit_gate", "战棋胜利 payload 应包含来源对象")
	assertions.assert_eq(payload.get("quest_id", ""), "quest_mountain_trial", "战棋胜利 payload 应包含任务编号")

	var retreat_battle = system.create_battle(state, _sample_context(), repository)
	system.resolve_retreat(retreat_battle)
	assertions.assert_true(retreat_battle.is_finished, "暂退应结束战棋")
	assertions.assert_true(not retreat_battle.victory, "暂退不应标记胜利")

	repository.free()
	state.free()

func _sample_context() -> Dictionary:
	return {
		"battle_mode": "tactical",
		"source_map_id": "mountain_pass",
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
		"battlefield": {"width": 7, "height": 5},
		"time_mode": "pause_on_action",
		"units": [
			{"unit_id": "hero", "actor_id": "hero_yun", "team": "player", "start_cell": {"q": 1, "r": 2}, "move_range": 3, "attack_range": 1, "charge_speed": 200},
			{"unit_id": "bandit", "actor_id": "bandit_01", "team": "enemy", "start_cell": {"q": 5, "r": 2}, "move_range": 3, "attack_range": 1, "charge_speed": 180},
			{"unit_id": "lackey", "actor_id": "bandit_01", "team": "enemy", "start_cell": {"q": 5, "r": 3}, "move_range": 3, "attack_range": 1, "charge_speed": 200}
		]
	}

func _has_cell(cells: Array, q: int, r: int) -> bool:
	for cell in cells:
		if int(cell.get("q", -1)) == q and int(cell.get("r", -1)) == r:
			return true
	return false
