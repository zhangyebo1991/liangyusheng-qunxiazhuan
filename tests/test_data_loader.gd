extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	var content = repository.load_all()

	assertions.assert_eq(content.get("actors", []).size(), 6, "应加载 6 个示例角色")
	assertions.assert_eq(repository.get_actor("hero_yun").get("name", ""), "云游少侠", "应按编号读取角色")
	assertions.assert_eq(repository.get_actor("innkeeper_lu").get("name", ""), "陆掌柜", "应读取客栈掌柜角色")
	assertions.assert_eq(repository.get_actor("porter_chen").get("name", ""), "陈脚夫", "应读取村口脚夫角色")
	assertions.assert_eq(repository.get_actor("bandit_lackey_01").get("name", ""), "山道喽啰", "应读取山道喽啰角色")
	assertions.assert_eq(repository.get_martial_art("basic_sword").get("name", ""), "基础剑法", "应按编号读取武学")
	assertions.assert_eq(repository.get_martial_art("straight_sword_thrust").get("name", ""), "穿云刺", "应按编号读取穿云刺")
	assertions.assert_eq(repository.get_martial_art("basic_sword").get("tactical", {}).get("range_shape", ""), "diamond", "基础剑法应声明战棋范围")
	assertions.assert_eq(repository.get_martial_art("straight_sword_thrust").get("tactical", {}).get("range_shape", ""), "line", "穿云刺应声明直线范围")
	assertions.assert_true(repository.get_actor("hero_yun").get("martial_arts", []).has("straight_sword_thrust"), "主角应学会穿云刺")
	assertions.assert_eq(repository.get_dialogue("intro_meet_master").get("title", ""), "初入江湖", "应按编号读取对话")
	assertions.assert_eq(repository.get_actor("missing_id"), {}, "缺失角色编号应返回空字典")
	assertions.assert_true(repository.terrains.size() >= 4, "应加载至少 4 种地形")
	assertions.assert_true(repository.get_terrain("grass").has("name"), "草地应有 name 字段")
	assertions.assert_eq(repository.get_martial_art("sword_aura_swirl").get("name", ""), "剑气漩", "应按编号读取剑气漩")
	assertions.assert_eq(int(repository.get_martial_art("sword_aura_swirl").get("mp_cost", 0)), 8, "剑气漩应消耗 8 点内力")
	repository.free()
