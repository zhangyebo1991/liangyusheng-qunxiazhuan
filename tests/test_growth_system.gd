extends RefCounted

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GrowthSystemScript = preload("res://scripts/systems/growth_system.gd")

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