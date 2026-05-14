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
	assertions.assert_eq(battle.get_unit("hero_yun").hp, 100, "主角单位应读取当前 GameState 气血")
	assertions.assert_eq(battle.get_unit("hero_yun").max_mp, 20, "玩家战棋单位应读取 GameState 最大内力")
	assertions.assert_eq(battle.get_unit("hero_yun").mp, 20, "玩家战棋单位开战时内力应回满")
	assertions.assert_true(battle.get_unit("hero_yun").martial_art_ids.has("basic_sword"), "玩家战棋单位应读取基础剑法")
	assertions.assert_true(battle.get_unit("hero_yun").martial_art_ids.has("straight_sword_thrust"), "玩家战棋单位应读取穿云刺")
	assertions.assert_eq(battle.get_unit("bandit").display_name, "山道强人", "敌人单位应读取角色名")
	assertions.assert_eq(battle.source_object_id, "enemy_bandit_gate", "战棋战斗应保存来源对象")

	system.advance_charge(battle, 5.0)
	assertions.assert_eq(battle.current_unit_id, "hero_yun", "主角和喽啰同时满集气时应优先玩家单位")
	assertions.assert_true(battle.is_action_phase, "单位满集气后应进入行动阶段")
	assertions.assert_eq(battle.get_unit("hero_yun").charge, 1000, "集气达到上限后应钳制到 1000")

	var cells = system.get_movable_cells(battle, "hero_yun")
	assertions.assert_true(_has_cell(cells, 1, 2), "可移动格应包含原地")
	assertions.assert_true(_has_cell(cells, 4, 2), "可移动格应包含移动力范围内的格子")
	assertions.assert_true(not _has_cell(cells, 5, 2), "可移动格不应包含敌方占用格")
	assertions.assert_true(not _has_cell(cells, 6, 2), "可移动格不应包含移动力范围外的格子")

	var attackable_before_move = system.get_attackable_units(battle, "hero_yun")
	assertions.assert_eq(attackable_before_move.size(), 0, "主角未接近时不应有可攻击目标")

	system.move_unit(battle, "hero_yun", {"q": 4, "r": 2})
	assertions.assert_eq(battle.get_unit("hero_yun").cell.get("q", -1), 4, "移动后应更新 q 坐标")
	assertions.assert_eq(battle.get_unit("hero_yun").cell.get("r", -1), 2, "移动后应更新 r 坐标")

	var attackable_after_move = system.get_attackable_units(battle, "hero_yun")
	assertions.assert_eq(attackable_after_move.size(), 1, "移动后应能攻击相邻敌人")
	assertions.assert_eq(attackable_after_move[0].unit_id, "bandit", "可攻击目标应为山道强人")

	var attack_result = system.attack_unit(battle, "hero_yun", "bandit")
	assertions.assert_true(bool(attack_result.get("success", false)), "攻击相邻敌人应成功")
	assertions.assert_eq(battle.get_unit("bandit").hp, 46, "普通攻击应按攻击减防御造成伤害")
	assertions.assert_true(battle.log.has("云游少侠攻击山道强人，造成14点伤害。"), "普通攻击应写入战斗日志")

	var skill_battle = system.create_battle(state, _sample_context(), repository)
	skill_battle.get_unit("hero_yun").cell = {"q": 4, "r": 2}
	var skill_result = system.use_martial_art(skill_battle, "hero_yun", "bandit", "basic_sword", repository)
	assertions.assert_true(bool(skill_result.get("success", false)), "内力足够且近身时应能使用基础剑法")
	assertions.assert_eq(skill_result.get("damage", 0), 20, "基础剑法伤害应为攻击加招式加值再减防御")
	assertions.assert_eq(skill_battle.get_unit("bandit").hp, 40, "基础剑法应扣除敌人气血")
	assertions.assert_eq(skill_battle.get_unit("hero_yun").mp, 17, "基础剑法应消耗 3 点内力")
	assertions.assert_true(skill_battle.log.has("云游少侠使出基础剑法攻击山道强人，造成20点伤害。"), "基础剑法应写入战斗日志")

	var line_battle = system.create_battle(state, _sample_context(), repository)
	line_battle.get_unit("hero_yun").cell = {"q": 3, "r": 2}
	var line_targets = system.get_attackable_units_for_martial_art(line_battle, "hero_yun", "straight_sword_thrust", repository)
	assertions.assert_eq(line_targets.size(), 1, "穿云刺应能选中两格直线目标")
	assertions.assert_eq(line_targets[0].unit_id, "bandit", "穿云刺直线目标应为山道强人")
	var line_result = system.use_martial_art(line_battle, "hero_yun", "bandit", "straight_sword_thrust", repository)
	assertions.assert_true(bool(line_result.get("success", false)), "穿云刺应能攻击两格直线目标")
	assertions.assert_eq(line_result.get("damage", 0), 18, "穿云刺伤害应使用战棋伤害加值")
	assertions.assert_eq(line_battle.get_unit("hero_yun").mp, 15, "穿云刺应消耗 5 点内力")

	var diagonal_battle = system.create_battle(state, _sample_context(), repository)
	diagonal_battle.get_unit("hero_yun").cell = {"q": 4, "r": 1}
	var diagonal_result = system.use_martial_art(diagonal_battle, "hero_yun", "bandit", "straight_sword_thrust", repository)
	assertions.assert_true(not bool(diagonal_result.get("success", false)), "穿云刺不能攻击斜向目标")
	assertions.assert_eq(diagonal_battle.get_unit("hero_yun").mp, 20, "招式失败不应扣内力")

	var low_mp_battle = system.create_battle(state, _sample_context(), repository)
	low_mp_battle.get_unit("hero_yun").cell = {"q": 4, "r": 2}
	low_mp_battle.get_unit("hero_yun").mp = 2
	var low_mp_result = system.use_martial_art(low_mp_battle, "hero_yun", "bandit", "basic_sword", repository)
	assertions.assert_true(not bool(low_mp_result.get("success", false)), "内力不足时基础剑法应失败")
	assertions.assert_eq(low_mp_battle.get_unit("hero_yun").mp, 2, "内力不足失败不应扣资源")

	var unknown_skill_result = system.use_martial_art(skill_battle, "hero_yun", "bandit", "rough_fist", repository)
	assertions.assert_true(not bool(unknown_skill_result.get("success", false)), "不能使用未学会的武学")

	system.end_unit_action(battle, "hero_yun")
	assertions.assert_eq(battle.get_unit("hero_yun").charge, 0, "结束行动应清空当前单位集气")
	assertions.assert_true(not battle.is_action_phase, "结束行动后应恢复集气阶段")
	assertions.assert_eq(battle.current_unit_id, "", "结束行动后应清空当前行动单位")

	var enemy_battle = system.create_battle(state, _sample_context(), repository)
	enemy_battle.get_unit("bandit").cell = {"q": 2, "r": 2}
	enemy_battle.get_unit("hero_yun").cell = {"q": 1, "r": 2}
	var ai_result = system.resolve_enemy_action(enemy_battle, "bandit")
	assertions.assert_true(bool(ai_result.get("success", false)), "敌人在攻击范围内应自动行动成功")
	assertions.assert_eq(enemy_battle.get_unit("hero_yun").hp, 96, "敌人普通攻击应扣除主角气血")

	var finish_battle = system.create_battle(state, _sample_context(), repository)
	finish_battle.get_unit("bandit").hp = 1
	finish_battle.get_unit("lackey").hp = 0
	finish_battle.get_unit("hero_yun").cell = {"q": 4, "r": 2}
	system.attack_unit(finish_battle, "hero_yun", "bandit")
	assertions.assert_true(finish_battle.is_finished, "击败全部敌人后战棋应结束")
	assertions.assert_true(finish_battle.victory, "击败全部敌人后应标记胜利")
	var payload = finish_battle.to_result_dictionary()
	assertions.assert_eq(payload.get("source_object_id", ""), "enemy_bandit_gate", "战棋胜利 payload 应包含来源对象")
	assertions.assert_eq(payload.get("quest_id", ""), "quest_mountain_trial", "战棋胜利 payload 应包含任务编号")

	var skill_finish_battle = system.create_battle(state, _sample_context(), repository)
	skill_finish_battle.get_unit("hero_yun").cell = {"q": 4, "r": 2}
	skill_finish_battle.get_unit("bandit").hp = 1
	skill_finish_battle.get_unit("lackey").hp = 0
	system.use_martial_art(skill_finish_battle, "hero_yun", "bandit", "basic_sword", repository)
	assertions.assert_true(skill_finish_battle.is_finished, "武学击败全部敌人后战棋应结束")
	assertions.assert_true(skill_finish_battle.victory, "武学击败全部敌人后应标记胜利")

	var retreat_battle = system.create_battle(state, _sample_context(), repository)
	system.resolve_retreat(retreat_battle)
	assertions.assert_true(retreat_battle.is_finished, "暂退应结束战棋")
	assertions.assert_true(not retreat_battle.victory, "暂退不应标记胜利")

	var defeat_battle = system.create_battle(state, _sample_context(), repository)
	defeat_battle.get_unit("hero_yun").hp = 1
	defeat_battle.get_unit("bandit").cell = {"q": 2, "r": 2}
	defeat_battle.get_unit("hero_yun").cell = {"q": 1, "r": 2}
	system.resolve_enemy_action(defeat_battle, "bandit")
	assertions.assert_true(defeat_battle.is_finished, "主角被击败后战棋应结束")
	assertions.assert_true(not defeat_battle.victory, "主角被击败后不应标记胜利")

	# 剑气漩命中：通过 resolve_action 接受 Vector2i 目标格列表，命中范围内敌人。
	# hero attack=18, swirl base_damage=14, scale_ratio=0.6 → 每格命中伤害 = int(14 + 18*0.6) = 24
	var swirl_battle = system.create_battle(state, _sample_context(), repository)
	swirl_battle.get_unit("hero_yun").cell = {"q": 4, "r": 2}
	swirl_battle.get_unit("bandit").cell = {"q": 5, "r": 2}
	swirl_battle.get_unit("lackey").cell = {"q": 5, "r": 3}
	var swirl_mp_before = swirl_battle.get_unit("hero_yun").mp
	# target_cells: 中心 (5,2) + 上下左右十字
	var swirl_targets: Array = [
		Vector2i(5, 2), Vector2i(4, 2), Vector2i(6, 2), Vector2i(5, 1), Vector2i(5, 3)
	]
	var swirl_result = system.resolve_action(swirl_battle, "hero_yun", "sword_aura_swirl", swirl_targets)
	assertions.assert_true(bool(swirl_result.get("success", false)), "剑气漩应释放成功")
	assertions.assert_eq(int(swirl_result.get("damage", 0)), 24, "剑气漩单格伤害应为 24")
	assertions.assert_eq(swirl_battle.get_unit("hero_yun").mp, swirl_mp_before - 8, "剑气漩应扣 8 点内力")
	assertions.assert_eq(swirl_battle.get_unit("bandit").hp, 60 - 24, "剑气漩应命中山道强人")
	assertions.assert_eq(swirl_battle.get_unit("lackey").hp, 60 - 24, "剑气漩应命中山道喽啰")

	# 内力不足时剑气漩应失败、不扣血
	var swirl_low_mp = system.create_battle(state, _sample_context(), repository)
	swirl_low_mp.get_unit("hero_yun").cell = {"q": 4, "r": 2}
	swirl_low_mp.get_unit("hero_yun").mp = 3
	var swirl_low_result = system.resolve_action(swirl_low_mp, "hero_yun", "sword_aura_swirl", [Vector2i(5, 2)])
	assertions.assert_true(not bool(swirl_low_result.get("success", false)), "内力不足时剑气漩应失败")
	assertions.assert_eq(swirl_low_mp.get_unit("hero_yun").mp, 3, "剑气漩失败不应扣内力")
	assertions.assert_eq(swirl_low_mp.get_unit("bandit").hp, 60, "剑气漩失败不应造成伤害")

	# 新形状武学可通过 resolve_action 结算。
	var fan_battle = system.create_battle(state, _sample_context(), repository)
	fan_battle.get_unit("hero_yun").cell = {"q": 4, "r": 2}
	fan_battle.get_unit("bandit").cell = {"q": 5, "r": 2}
	var fan_mp_before = fan_battle.get_unit("hero_yun").mp
	var fan_result = system.resolve_action(fan_battle, "hero_yun", "sword_willow_sweep", [Vector2i(5, 2)])
	assertions.assert_true(bool(fan_result.get("success", false)), "回风拂柳应释放成功")
	assertions.assert_eq(fan_battle.get_unit("hero_yun").mp, fan_mp_before - 6, "回风拂柳应扣 6 点内力")
	assertions.assert_eq(fan_battle.get_unit("bandit").hp, 60 - (18 + 5 - 4), "回风拂柳伤害 = atk + bonus - def")

	var unlearned_battle = system.create_battle(state, _sample_context(), repository)
	unlearned_battle.get_unit("hero_yun").cell = {"q": 4, "r": 2}
	unlearned_battle.get_unit("hero_yun").martial_art_ids.erase("sword_willow_sweep")
	unlearned_battle.get_unit("bandit").cell = {"q": 5, "r": 2}
	var unlearned_mp_before = unlearned_battle.get_unit("hero_yun").mp
	var unlearned_hp_before = unlearned_battle.get_unit("bandit").hp
	var unlearned_result = system.resolve_action(unlearned_battle, "hero_yun", "sword_willow_sweep", [Vector2i(5, 2)])
	assertions.assert_true(not bool(unlearned_result.get("success", false)), "未学会回风拂柳时 resolve_action 应拒绝释放")
	assertions.assert_eq(unlearned_battle.get_unit("hero_yun").mp, unlearned_mp_before, "未学会招式失败不应扣内力")
	assertions.assert_eq(unlearned_battle.get_unit("bandit").hp, unlearned_hp_before, "未学会招式失败不应造成伤害")

	var invalid_target_battle = system.create_battle(state, _sample_context(), repository)
	invalid_target_battle.get_unit("hero_yun").cell = {"q": 4, "r": 2}
	invalid_target_battle.get_unit("bandit").cell = {"q": 0, "r": 0}
	var invalid_target_mp_before = invalid_target_battle.get_unit("hero_yun").mp
	var invalid_target_hp_before = invalid_target_battle.get_unit("bandit").hp
	var invalid_target_result = system.resolve_action(invalid_target_battle, "hero_yun", "sword_willow_sweep", [Vector2i(0, 0)])
	assertions.assert_true(not bool(invalid_target_result.get("success", false)), "回风拂柳不应命中范围外任意传入格")
	assertions.assert_eq(invalid_target_battle.get_unit("hero_yun").mp, invalid_target_mp_before, "非法目标格失败不应扣内力")
	assertions.assert_eq(invalid_target_battle.get_unit("bandit").hp, invalid_target_hp_before, "非法目标格失败不应造成伤害")

	# 八方风雨多格命中
	var sur_battle = system.create_battle(state, _sample_context(), repository)
	sur_battle.get_unit("hero_yun").cell = {"q": 4, "r": 2}
	sur_battle.get_unit("bandit").cell = {"q": 4, "r": 3}
	sur_battle.get_unit("lackey").cell = {"q": 5, "r": 2}
	var sur_mp_before = sur_battle.get_unit("hero_yun").mp
	var sur_result = system.resolve_action(sur_battle, "hero_yun", "sword_all_directions", [Vector2i(4, 3), Vector2i(5, 2)])
	assertions.assert_true(bool(sur_result.get("success", false)), "八方风雨应释放成功")
	assertions.assert_eq(sur_battle.get_unit("hero_yun").mp, sur_mp_before - 10, "八方风雨应扣 10 内力")

	# 长虹贯日穿透两目标
	var pierce_battle = system.create_battle(state, _sample_context(), repository)
	pierce_battle.get_unit("hero_yun").cell = {"q": 4, "r": 2}
	pierce_battle.get_unit("bandit").cell = {"q": 5, "r": 2}
	pierce_battle.get_unit("lackey").cell = {"q": 6, "r": 2}
	var pierce_result = system.resolve_action(pierce_battle, "hero_yun", "sword_rainbow_pierce", [Vector2i(5, 2), Vector2i(6, 2)])
	assertions.assert_true(bool(pierce_result.get("success", false)), "长虹贯日应穿透两目标")

	# 剑气环身环形命中
	var ring_battle = system.create_battle(state, _sample_context(), repository)
	ring_battle.get_unit("hero_yun").cell = {"q": 3, "r": 3}
	ring_battle.get_unit("bandit").cell = {"q": 5, "r": 3}
	var ring_mp_before = ring_battle.get_unit("hero_yun").mp
	var ring_result = system.resolve_action(ring_battle, "hero_yun", "sword_ring_aura", [Vector2i(5, 3)])
	assertions.assert_true(bool(ring_result.get("success", false)), "剑气环身应释放成功")
	assertions.assert_eq(ring_battle.get_unit("hero_yun").mp, ring_mp_before - 8, "剑气环身应扣 8 内力")

	# 熟练度累加测试
	const ProficiencySystemScript = preload("res://scripts/systems/proficiency_system.gd")
	var prof_sys = ProficiencySystemScript.new()
	system.set_proficiency(prof_sys, state.martial_proficiency)

	var prof_battle = system.create_battle(state, _sample_context(), repository)
	prof_battle.get_unit("hero_yun").cell = {"q": 4, "r": 2}
	prof_battle.get_unit("bandit").cell = {"q": 5, "r": 2}
	system.resolve_action(prof_battle, "hero_yun", "sword_willow_sweep", [Vector2i(5, 2)])
	assertions.assert_eq(state.get_martial_proficiency("sword_willow_sweep"), 1, "首次使用回风拂柳后熟练度应 = 1")
	system.resolve_action(prof_battle, "hero_yun", "sword_willow_sweep", [Vector2i(5, 2)])
	assertions.assert_eq(state.get_martial_proficiency("sword_willow_sweep"), 2, "二次使用回风拂柳后熟练度应 = 2")

	# 熟练度加值验伤：手动设基本剑法 25 次 → 跨过 [10, 25] 两阈值 → bonus = +4
	var bonus_battle = system.create_battle(state, _sample_context(), repository)
	bonus_battle.get_unit("hero_yun").cell = {"q": 4, "r": 2}
	bonus_battle.get_unit("bandit").cell = {"q": 5, "r": 2}
	bonus_battle.get_unit("bandit").hp = 60
	state.martial_proficiency["basic_sword"] = 25
	system.resolve_action(bonus_battle, "hero_yun", "basic_sword", [Vector2i(5, 2)])
	# 基础剑法：atk=18, tactical.damage_bonus=6, def=4 → 18+6-4=20
	# 熟练度 bonus = Lv.2 × 2 = +4 → 总伤害 = 24
	assertions.assert_eq(bonus_battle.get_unit("bandit").hp, 60 - 24, "熟练度 Lv.2 时基础剑法伤害应为 24")

	var swirl_bonus_battle = system.create_battle(state, _sample_context(), repository)
	swirl_bonus_battle.get_unit("hero_yun").cell = {"q": 4, "r": 2}
	swirl_bonus_battle.get_unit("bandit").cell = {"q": 5, "r": 2}
	swirl_bonus_battle.get_unit("bandit").hp = 60
	state.martial_proficiency["sword_aura_swirl"] = 12
	var swirl_bonus_result = system.resolve_action(swirl_bonus_battle, "hero_yun", "sword_aura_swirl", [Vector2i(5, 2)])
	# 剑气漩：base=14 + atk 18*0.6 = 24；熟练度 Lv.1 bonus +2 → 总伤害 26
	assertions.assert_eq(int(swirl_bonus_result.get("damage", 0)), 26, "熟练度 Lv.1 时剑气漩单格伤害应为 26")
	assertions.assert_eq(swirl_bonus_battle.get_unit("bandit").hp, 60 - 26, "剑气漩应应用熟练度伤害加成")

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
			{"unit_id": "hero_yun", "actor_id": "hero_yun", "team": "player", "start_cell": {"q": 1, "r": 2}, "move_range": 3, "attack_range": 1, "charge_speed": 200},
			{"unit_id": "bandit", "actor_id": "bandit_01", "team": "enemy", "start_cell": {"q": 5, "r": 2}, "move_range": 3, "attack_range": 1, "charge_speed": 180},
			{"unit_id": "lackey", "actor_id": "bandit_01", "team": "enemy", "start_cell": {"q": 5, "r": 3}, "move_range": 3, "attack_range": 1, "charge_speed": 200}
		]
	}

func _has_cell(cells: Array, q: int, r: int) -> bool:
	for cell in cells:
		if int(cell.get("q", -1)) == q and int(cell.get("r", -1)) == r:
			return true
	return false
