extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	var content = repository.load_all()

	assertions.assert_eq(content.get("maps", []).size(), 2, "应加载 2 张示例地图")

	var mountain = repository.get_map("mountain_pass")
	assertions.assert_eq(mountain.get("name", ""), "山道", "应按编号读取山道地图")
	assertions.assert_eq(mountain.get("spawn_position", {}).get("x", 0), 160, "山道出生点横坐标应正确")
	assertions.assert_true(mountain.get("spawn_points", {}).has("return_from_village"), "山道应包含村镇返回出生点")
	assertions.assert_eq(_find_object(mountain, "exit_to_foot_village").get("target_map_id", ""), "foot_village", "山道出口应指向山脚村镇")

	var village = repository.get_map("foot_village")
	assertions.assert_eq(village.get("name", ""), "山脚村镇", "应按编号读取山脚村镇")
	assertions.assert_eq(village.get("spawn_position", {}).get("x", 0), 120, "村镇默认出生点横坐标应正确")
	assertions.assert_true(village.get("spawn_points", {}).has("village_gate"), "村镇应包含村口出生点")
	assertions.assert_eq(_find_object(village, "npc_innkeeper_lu").get("actor_id", ""), "innkeeper_lu", "村镇应配置客栈掌柜")
	assertions.assert_eq(_find_object(village, "npc_porter_chen").get("actor_id", ""), "porter_chen", "村镇应配置村口脚夫")
	assertions.assert_eq(_find_object(village, "notice_foot_village").get("type", ""), "notice", "村镇应配置告示牌")
	assertions.assert_eq(_find_object(village, "exit_to_mountain_pass").get("target_map_id", ""), "mountain_pass", "村镇应能返回山道")

	var pharmacy = _find_object(village, "shop_foot_village_pharmacy")
	assertions.assert_eq(pharmacy.get("type", ""), "shop", "村镇应配置药铺对象")
	assertions.assert_eq(pharmacy.get("name", ""), "药铺", "药铺对象应显示中文名称")
	assertions.assert_eq(pharmacy.get("shop_id", ""), "foot_village_pharmacy", "药铺对象应保存商店编号")
	var pharmacy_items = pharmacy.get("items", [])
	assertions.assert_eq(pharmacy_items.size(), 1, "药铺第一版只应配置一个商品")
	if pharmacy_items.size() > 0:
		assertions.assert_eq(pharmacy_items[0], "herb_small", "药铺第一版应出售小还丹")
	else:
		assertions.assert_true(false, "药铺第一版应出售小还丹")

	assertions.assert_eq(_find_object(village, "exit_to_open_road").get("locked_message", ""), "前路尚未开放。", "未开放出口应有提示")

	assertions.assert_eq(repository.get_quest("quest_deliver_letter").get("title", ""), "送信到客栈", "应读取送信任务")
	assertions.assert_eq(repository.get_dialogue("deliver_letter_complete").get("title", ""), "书信送达", "应读取送信完成对白")
	assertions.assert_eq(repository.get_map("missing_map"), {}, "缺失地图编号应返回空字典")

	repository.free()

func _find_object(map_data: Dictionary, object_id: String) -> Dictionary:
	for object in map_data.get("objects", []):
		if object.get("id", "") == object_id:
			return object
	return {}
