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
	assertions.assert_eq(battle.get_unit("hero").max_mp, 20, "玩家战棋单位应读取 GameState 最大内力")
	assertions.assert_eq(battle.get_unit("hero").mp, 20, "玩家战棋单位开战时内力应回满")
	assertions.assert_true(battle.get_unit("hero").martial_art_ids.has("basic_sword"), "玩家战棋单位应读取基础剑法")
	assertions.assert_true(battle.get_unit("hero").martial_art_ids.has("straight_sword_thrust"), "玩家战棋单位应读取穿云刺")
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

	var skill_battle = system.create_battle(state, _sample_context(), repository)
	skill_battle.get_unit("hero").cell = {"q": 4, "r": 2}
	var skill_result = system.use_martial_art(skill_battle, "hero", "bandit", "basic_sword", repository)
	assertions.assert_true(bool(skill_result.get("success", false)), "内力足够且近身时应能使用基础剑法")
	assertions.assert_eq(skill_result.get("damage", 0), 20, "基础剑法伤害应为攻击加招式加值再减防御")
	assertions.assert_eq(skill_battle.get_unit("bandit").hp, 40, "基础剑法应扣除敌人气血")
	assertions.assert_eq(skill_battle.get_unit("hero").mp, 17, "基础剑法应消耗 3 点内力")
	assertions.assert_true(skill_battle.log.has("云游少侠使出基础剑法攻击山道强人，造成20点伤害。"), "基础剑法应写入战斗日志")

	var line_battle = system.create_battle(state, _sample_context(), repository)
	line_battle.get_unit("hero").cell = {"q": 3, "r": 2}
	var line_targets = system.get_attackable_units_for_martial_art(line_battle, "hero", "straight_sword_thrust", repository)
	assertions.assert_eq(line_targets.size(), 1, "穿云刺应能选中两格直线目标")
	assertions.assert_eq(line_targets[0].unit_id, "bandit", "穿云刺直线目标应为山道强人")
	var line_result = system.use_martial_art(line_battle, "hero", "bandit", "straight_sword_thrust", repository)
	assertions.assert_true(bool(line_result.get("success", false)), "穿云刺应能攻击两格直线目标")
	assertions.assert_eq(line_result.get("damage", 0), 18, "穿云刺伤害应使用战棋伤害加值")
	assertions.assert_eq(line_battle.get_unit("hero").mp, 15, "穿云刺应消耗 5 点内力")

	var diagonal_battle = system.create_battle(state, _sample_context(), repository)
	diagonal_battle.get_unit("hero").cell = {"q": 4, "r": 1}
	var diagonal_result = system.use_martial_art(diagonal_battle, "hero", "bandit", "straight_sword_thrust", repository)
	assertions.assert_true(not bool(diagonal_result.get("success", false)), "穿云刺不能攻击斜向目标")
	assertions.assert_eq(diagonal_battle.get_unit("hero").mp, 20, "招式失败不应扣内力")

	var low_mp_battle = system.create_battle(state, _sample_context(), repository)
	low_mp_battle.get_unit("hero").cell = {"q": 4, "r": 2}
	low_mp_battle.get_unit("hero").mp = 2
	var low_mp_result = system.use_martial_art(low_mp_battle, "hero", "bandit", "basic_sword", repository)
	assertions.assert_true(not bool(low_mp_result.get("success", false)), "内力不足时基础剑法应失败")
	assertions.assert_eq(low_mp_battle.get_unit("hero").mp, 2, "内力不足失败不应扣资源")

	var unknown_skill_result = system.use_martial_art(skill_battle, "hero", "bandit", "rough_fist", repository)
	assertions.assert_true(not bool(unknown_skill_result.get("success", false)), "不能使用未学会的武学")

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

	var skill_finish_battle = system.create_battle(state, _sample_context(), repository)
	skill_finish_battle.get_unit("hero").cell = {"q": 4, "r": 2}
	skill_finish_battle.get_unit("bandit").hp = 1
	skill_finish_battle.get_unit("lackey").hp = 0
	system.use_martial_art(skill_finish_battle, "hero", "bandit", "basic_sword", repository)
	assertions.assert_true(skill_finish_battle.is_finished, "武学击败全部敌人后战棋应结束")
	assertions.assert_true(skill_finish_battle.victory, "武学击败全部敌人后应标记胜利")

	var retreat_battle = system.create_battle(state, _sample_context(), repository)
	system.resolve_retreat(retreat_battle)
	assertions.assert_true(retreat_battle.is_finished, "暂退应结束战棋")
	assertions.assert_true(not retreat_battle.victory, "暂退不应标记胜利")

	var defeat_battle = system.create_battle(state, _sample_context(), repository)
	defeat_battle.get_unit("hero").hp = 1
	defeat_battle.get_unit("bandit").cell = {"q": 2, "r": 2}
	defeat_battle.get_unit("hero").cell = {"q": 1, "r": 2}
	system.resolve_enemy_action(defeat_battle, "bandit")
	assertions.assert_true(defeat_battle.is_finished, "主角被击败后战棋应结束")
	assertions.assert_true(not defeat_battle.victory, "主角被击败后不应标记胜利")

	# 剑气漩命中：通过 resolve_action 接受 Vector2i 目标格列表，命中范围内敌人。
	# hero attack=18, swirl base_damage=14, scale_ratio=0.6 → 每格命中伤害 = int(14 + 18*0.6) = 24
	var swirl_battle = system.create_battle(state, _sample_context(), repository)
	swirl_battle.get_unit("hero").cell = {"q": 4, "r": 2}
	swirl_battle.get_unit("bandit").cell = {"q": 5, "r": 2}
	swirl_battle.get_unit("lackey").cell = {"q": 5, "r": 3}
	var swirl_mp_before = swirl_battle.get_unit("hero").mp
	# target_cells: 中心 (5,2) + 上下左右十字
	var swirl_targets: Array = [
		Vector2i(5, 2), Vector2i(4, 2), Vector2i(6, 2), Vector2i(5, 1), Vector2i(5, 3)
	]
	var swirl_result = system.resolve_action(swirl_battle, "hero", "sword_aura_swirl", swirl_targets)
	assertions.assert_true(bool(swirl_result.get("success", false)), "剑气漩应释放成功")
	assertions.assert_eq(int(swirl_result.get("damage", 0)), 24, "剑气漩单格伤害应为 24")
	assertions.assert_eq(swirl_battle.get_unit("hero").mp, swirl_mp_before - 8, "剑气漩应扣 8 点内力")
	assertions.assert_eq(swirl_battle.get_unit("bandit").hp, 60 - 24, "剑气漩应命中山道强人")
	assertions.assert_eq(swirl_battle.get_unit("lackey").hp, 60 - 24, "剑气漩应命中山道喽啰")

	# 内力不足时剑气漩应失败、不扣血
	var swirl_low_mp = system.create_battle(state, _sample_context(), repository)
	swirl_low_mp.get_unit("hero").cell = {"q": 4, "r": 2}
	swirl_low_mp.get_unit("hero").mp = 3
	var swirl_low_result = system.resolve_action(swirl_low_mp, "hero", "sword_aura_swirl", [Vector2i(5, 2)])
	assertions.assert_true(not bool(swirl_low_result.get("success", false)), "内力不足时剑气漩应失败")
	assertions.assert_eq(swirl_low_mp.get_unit("hero").mp, 3, "剑气漩失败不应扣内力")
	assertions.assert_eq(swirl_low_mp.get_unit("bandit").hp, 60, "剑气漩失败不应造成伤害")

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
