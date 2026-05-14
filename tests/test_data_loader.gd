extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	var content = repository.load_all()

	assertions.assert_eq(content.get("actors", []).size(), 9, "应加载 9 个示例角色")
	assertions.assert_eq(content.get("martial_arts", []).size(), 8, "应加载 8 门武学（含 4 门新）")
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
	assertions.assert_true(repository.get_martial_art("basic_sword").get("proficiency_thresholds", []) is Array, "基础剑法应有 proficiency_thresholds 数组")
	assertions.assert_eq(int(repository.get_martial_art("basic_sword").get("proficiency_thresholds", [10,25,50])[0]), 10, "基础剑法首阈值应为 10")
	assertions.assert_eq(int(repository.get_martial_art("basic_sword").get("proficiency_thresholds", [10,25,50])[2]), 50, "基础剑法末阈值应为 50")
	assertions.assert_eq(int(repository.get_martial_art("sword_aura_swirl").get("proficiency_thresholds", [12,30,60])[0]), 12, "剑气漩首阈值应为 12")

	var mountain_trial = repository.get_quest("quest_mountain_trial")
	var trial_effects: Array = mountain_trial.get("complete_effects", [])
	assertions.assert_true(_has_effect(trial_effects, "add_party_member", "actor_id", "qingshanke"), "山道试剑完成后应让青衫客入队")
	assertions.assert_true(_has_effect(trial_effects, "add_item", "item_id", "iron_sword"), "山道试剑完成后应奖励铁剑")
	assertions.assert_true(_has_effect(trial_effects, "add_coins", "amount", 160), "山道试剑完成后应奖励足够铜钱购买衣甲与饰品")

	var foot_village = repository.get_map("foot_village")
	var pharmacy_items: Array = _map_object_items(foot_village, "shop_foot_village_pharmacy")
	assertions.assert_true(pharmacy_items.has("cloth_armor"), "山脚药铺应售卖布衣以测试衣甲槽")
	assertions.assert_true(pharmacy_items.has("jade_talisman"), "山脚药铺应售卖青玉坠以测试饰品槽")
	repository.free()

func _has_effect(effects: Array, effect_type: String, key: String, expected_value: Variant) -> bool:
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if str(effect.get("type", "")) != effect_type:
			continue
		if effect.get(key) == expected_value:
			return true
	return false

func _map_object_items(map_data: Dictionary, object_id: String) -> Array:
	var objects = map_data.get("objects", [])
	if typeof(objects) != TYPE_ARRAY:
		return []
	for object in objects:
		if typeof(object) != TYPE_DICTIONARY:
			continue
		if str(object.get("id", "")) != object_id:
			continue
		var items = object.get("items", [])
		return items if typeof(items) == TYPE_ARRAY else []
	return []
