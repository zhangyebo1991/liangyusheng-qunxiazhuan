extends RefCounted

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GrowthSystemScript = preload("res://scripts/systems/growth_system.gd")
const ProficiencySystemScript = preload("res://scripts/systems/proficiency_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.set_member_status("hero_yun", {"hp": 1, "mp": 1, "level": 1, "exp": 0, "total_exp": 0})

	var growth = GrowthSystemScript.new()
	var result = growth.add_exp(party, "hero_yun", 35, repository)
	assertions.assert_true(bool(result.get("success", false)), "加经验应成功")
	assertions.assert_eq(result.get("actor_id", ""), "hero_yun", "结果应记录角色编号")
	assertions.assert_eq(int(result.get("old_level", 0)), 1, "应记录旧等级")
	assertions.assert_eq(int(result.get("new_level", 0)), 2, "35 经验应升到 2 级")
	assertions.assert_true(bool(result.get("leveled_up", false)), "应标记升级")
	assertions.assert_eq(party.get_member_status("hero_yun").get("level", 0), 2, "成员等级应更新")
	assertions.assert_eq(party.get_member_status("hero_yun").get("total_exp", 0), 35, "累计经验应更新")
	assertions.assert_eq(party.get_member_status("hero_yun").get("exp", -1), 5, "当前等级经验应为超过 2 级门槛后的剩余值")
	assertions.assert_eq(party.get_member_status("hero_yun").get("hp", 0), int(result.get("max_hp", 0)), "升级后气血应回满")
	assertions.assert_eq(party.get_member_status("hero_yun").get("mp", 0), int(result.get("max_mp", 0)), "升级后内力应回满")

	var bonus = growth.get_growth_bonus(repository.get_actor("hero_yun"), 2)
	assertions.assert_eq(int(bonus.get("max_hp", 0)), 8, "2 级应获得 1 次气血成长")
	assertions.assert_eq(int(bonus.get("attack", 0)), 1, "2 级应获得 1 次攻击成长")
	assertions.assert_eq(growth.next_level_required_exp(repository.get_actor("hero_yun"), 2), 80, "2 级下一级累计经验应为 80")

	var party_result = growth.add_party_exp(party, 10, repository)
	assertions.assert_true(bool(party_result.get("success", false)), "全队经验应成功")
	assertions.assert_eq(party_result.get("members", []).size(), 1, "全队经验应返回成员结果")

	var invalid = growth.add_exp(party, "missing_actor", 10, repository)
	assertions.assert_false(bool(invalid.get("success", true)), "不存在角色不应获得经验")

	repository.free()

	run_skill_tree_tests(assertions)
	run_inner_art_tests(assertions)
	run_proficiency_points_tests(assertions)
	run_effect_system_skill_tree_bonus_tests(assertions)

func run_skill_tree_tests(assertions) -> void:
	var GrowthManagerScript = preload("res://scripts/systems/growth_manager.gd")

	var manager = GrowthManagerScript.new()
	manager.proficiency_points = 5
	var result = manager.unlock_skill_node("basic_sword", "dmg_1")
	assertions.assert_true(bool(result.get("success", false)), "解锁节点应成功")
	assertions.assert_eq(manager.proficiency_points, 4, "消耗 1 点后剩余 4")

	var manager2 = GrowthManagerScript.new()
	manager2.proficiency_points = 0
	var result2 = manager2.unlock_skill_node("basic_sword", "dmg_1")
	assertions.assert_false(bool(result2.get("success", true)), "点数不足应失败")

func run_inner_art_tests(assertions) -> void:
	var GrowthManagerScript = preload("res://scripts/systems/growth_manager.gd")

	var manager = GrowthManagerScript.new()
	manager.learn_art("calm_heart")
	var result = manager.upgrade_art("calm_heart")
	assertions.assert_true(bool(result.get("success", false)), "升级心法应成功")
	assertions.assert_eq(manager.get_art_level("calm_heart"), 1, "心法等级应为 1")

	var manager2 = GrowthManagerScript.new()
	manager2.learn_art("calm_heart")
	var result2 = manager2.switch_active("calm_heart")
	assertions.assert_true(bool(result2.get("success", false)), "切换心法应成功")
	assertions.assert_eq(manager2.get_active_art(), "calm_heart", "当前心法应为 calm_heart")

	var effects = manager2.get_active_effects()
	assertions.assert_eq(int(effects.get("max_mp", 0)), 3, "1级静心诀应增加3内力上限")
	assertions.assert_eq(int(effects.get("mp_regen", 0)), 1, "1级静心诀应增加1内力回复")

	run_insight_tests(assertions)
	run_game_state_integration_tests(assertions)

func run_game_state_integration_tests(assertions) -> void:
	var GameStateScript = preload("res://scripts/core/game_state.gd")
	var game_state = GameStateScript.new()
	assertions.assert_true(game_state.growth_manager != null, "GameState 应有 growth_manager")

	var game_state2 = GameStateScript.new()
	game_state2.start_new_game()
	var old_points = game_state2.growth_manager.proficiency_points
	game_state2.growth_manager.on_battle_end({"enemies": 2, "difficulty": 1})
	assertions.assert_true(game_state2.growth_manager.proficiency_points > old_points, "战斗结束后熟练度点数应增加")

func run_proficiency_points_tests(assertions) -> void:
	var ps = ProficiencySystemScript.new()
	ps.add_proficiency_points(10)
	assertions.assert_eq(ps.get_proficiency_points(), 10, "添加 10 点后应为 10")

	var ps2 = ProficiencySystemScript.new()
	ps2.add_proficiency_points(10)
	var result = ps2.spend_proficiency_points(3)
	assertions.assert_true(result, "消耗 3 点应成功")
	assertions.assert_eq(ps2.get_proficiency_points(), 7, "消耗 3 点后剩余 7")

	var ps3 = ProficiencySystemScript.new()
	ps3.add_proficiency_points(2)
	var result2 = ps3.spend_proficiency_points(5)
	assertions.assert_false(result2, "点数不足应失败")
	assertions.assert_eq(ps3.get_proficiency_points(), 2, "失败后点数不变")

func run_insight_tests(assertions) -> void:
	var GrowthManagerScript = preload("res://scripts/systems/growth_manager.gd")

	var manager = GrowthManagerScript.new()
	var context = {
		"skill_proficiency": {"basic_sword": 50},
		"skill_used_count": {"basic_sword": 100}
	}
	manager.insights.set_seed(0)
	var result = manager.insights.check_triggers("combat", context)
	assertions.assert_true(result is Array, "领悟触发检查应返回数组")
	assertions.assert_false(result.is_empty(), "proficiency=50 + used_count=100 + seed=0 应触发领悟")
	if not result.is_empty():
		assertions.assert_true(result[0].has("triggered"), "触发结果应包含 triggered 字段")

func run_effect_system_skill_tree_bonus_tests(assertions) -> void:
	var EffectSystemScript = preload("res://scripts/systems/effect_system.gd")

	var effect_sys = EffectSystemScript.new()
	var effects = {"damage_bonus": 5, "crit_chance": 0.1}
	var result = effect_sys.apply_skill_tree_effects(effects)
	assertions.assert_true(bool(result.get("success", false)), "apply_skill_tree_effects 应成功应用技能树效果")