extends RefCounted

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const ActorStatsSystemScript = preload("res://scripts/systems/actor_stats_system.gd")

class RepositoryStub:
	extends RefCounted

	func get_actor(actor_id: String) -> Dictionary:
		if actor_id == "hero_yun":
			return {"id": "hero_yun", "name": "云游少侠", "hp": 120, "max_hp": 120, "max_mp": 20, "attack": 18, "defense": 8, "move_range": 3, "attack_range": 1, "charge_speed": 200, "martial_arts": ["basic_sword"], "growth": {"exp_curve": [0, 30, 80, 150], "per_level": {"max_hp": 8, "max_mp": 2, "attack": 1, "defense": 1}}, "sprite_tile_id": "tile_hero_yun_hd"}
		return {}

	func get_item(item_id: String) -> Dictionary:
		if item_id == "iron_sword":
			return {"id": "iron_sword", "type": "equipment", "equipment": {"slot": "weapon", "stat_bonus": {"attack": 4, "max_mp": 5}}}
		return {}

func run(assertions) -> void:
	var party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.add_item("iron_sword", 1)
	party.set_member_status("hero_yun", {"hp": 90, "mp": 12})
	party.set_equipment("hero_yun", "weapon", "iron_sword")

	var stats_system = ActorStatsSystemScript.new()
	var stats = stats_system.build_stats(party, "hero_yun", RepositoryStub.new())
	assertions.assert_eq(stats.get("display_name", ""), "云游少侠", "应读取角色名")
	assertions.assert_eq(int(stats.get("hp", 0)), 90, "应读取成员当前 HP")
	assertions.assert_eq(int(stats.get("mp", 0)), 12, "应读取成员当前 MP")
	assertions.assert_eq(int(stats.get("attack", 0)), 22, "攻击应包含铁剑 +4")
	assertions.assert_eq(int(stats.get("max_mp", 0)), 25, "最大内力应包含护持加成 +5")
	assertions.assert_eq(int(stats.get("move_range", 0)), 3, "应读取移动范围")
	assertions.assert_true(stats.get("martial_art_ids", []).has("basic_sword"), "应读取武学列表")

	party.set_member_status("hero_yun", {"hp": 999, "mp": 999})
	var clamped = stats_system.build_stats(party, "hero_yun", RepositoryStub.new())
	assertions.assert_eq(int(clamped.get("hp", 0)), 120, "HP 应 clamp 到 max_hp")
	assertions.assert_eq(int(clamped.get("mp", 0)), 25, "MP 应 clamp 到 max_mp")

	party.set_member_status("hero_yun", {"hp": 999, "mp": 999, "level": 3, "exp": 0, "total_exp": 80})
	var growth_stats = stats_system.build_stats(party, "hero_yun", RepositoryStub.new())
	assertions.assert_eq(int(growth_stats.get("level", 0)), 3, "属性合成应返回角色等级")
	assertions.assert_eq(int(growth_stats.get("next_level_exp", 0)), 150, "属性合成应返回下一级累计经验门槛")
	assertions.assert_eq(int(growth_stats.get("max_hp", 0)), 136, "3 级主角应获得两次气血成长")
	assertions.assert_eq(int(growth_stats.get("max_mp", 0)), 29, "3 级主角应获得成长内力与装备内力")
	assertions.assert_eq(int(growth_stats.get("attack", 0)), 24, "3 级主角攻击应包含成长与铁剑")
	assertions.assert_eq(int(growth_stats.get("defense", 0)), 10, "3 级主角防御应包含成长")
	assertions.assert_eq(int(growth_stats.get("hp", 0)), 136, "当前气血应 clamp 到成长后的上限")
	assertions.assert_eq(int(growth_stats.get("mp", 0)), 29, "当前内力应 clamp 到成长和装备后的上限")

	var missing = stats_system.build_stats(party, "missing", RepositoryStub.new())
	assertions.assert_true(missing.is_empty(), "不存在角色应返回空字典")