extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	var content = repository.load_all()

	assertions.assert_eq(content.get("maps", []).size(), 4, "应加载 4 张示例地图")

	var mountain = repository.get_map("mountain_pass")
	assertions.assert_eq(mountain.get("name", ""), "山道", "应按编号读取山道地图")
	assertions.assert_eq(mountain.get("scene_path", ""), "res://scenes/mountain_pass.tscn", "山道应声明场景路径")
	assertions.assert_eq(mountain.get("spawn_position", {}).get("x", 0), 160, "山道出生点横坐标应正确")
	assertions.assert_true(mountain.get("spawn_points", {}).has("return_from_village"), "山道应包含村镇返回出生点")
	assertions.assert_eq(_find_object(mountain, "exit_to_foot_village").get("target_map_id", ""), "foot_village", "山道出口应指向山脚村镇")
	var bandit_gate = _find_object(mountain, "enemy_bandit_gate")
	assertions.assert_eq(bandit_gate.get("battle_mode", ""), "tactical", "山道强人应配置战棋战斗模式")
	assertions.assert_eq(bandit_gate.get("battlefield", {}).get("width", 0), 16, "山道战棋战场宽度应为 16")
	assertions.assert_eq(bandit_gate.get("battlefield", {}).get("height", 0), 9, "山道战棋战场高度应为 9")
	assertions.assert_eq(bandit_gate.get("time_mode", ""), "pause_on_action", "山道战棋应配置行动暂停集气")
	# 山道战棋触发节点应配置 9 行 × 16 列地形矩阵
	var bandit_terrain = bandit_gate.get("terrain_grid", [])
	assertions.assert_eq(bandit_terrain.size(), 9, "山道战棋应配置 9 行地形")
	if bandit_terrain.size() >= 1:
		assertions.assert_eq(bandit_terrain[0].size(), 16, "山道战棋地形每行应有 16 列")
	var bandit_units = bandit_gate.get("units", [])
	assertions.assert_eq(bandit_units.size(), 3, "山道战棋应配置主角与 2 名敌人")
	if bandit_units.size() >= 3:
		assertions.assert_eq(bandit_units[2].get("actor_id", ""), "bandit_lackey_01", "第三个战棋单位应为山道喽啰")
	else:
		assertions.assert_true(false, "山道战棋应包含山道喽啰单位")
	assertions.assert_eq(repository.get_actor("bandit_lackey_01").get("name", ""), "山道喽啰", "应读取山道喽啰角色")

	var roaming_bandit = _find_object(mountain, "enemy_roaming_bandit")
	assertions.assert_eq(roaming_bandit.get("type", ""), "battle_trigger", "山道应配置流窜山贼战斗入口")
	assertions.assert_eq(roaming_bandit.get("name", ""), "流窜山贼", "流窜山贼入口应使用中文名称")
	assertions.assert_true(bool(roaming_bandit.get("repeatable", false)), "流窜山贼应是可重复遭遇")
	assertions.assert_eq(roaming_bandit.get("required_quest_id", ""), "quest_mountain_trial", "流窜山贼应在山道试剑后开放")
	assertions.assert_eq(roaming_bandit.get("required_quest_status", ""), "completed", "流窜山贼应要求山道试剑完成")
	var roaming_rewards = roaming_bandit.get("victory_rewards", {})
	assertions.assert_eq(int(roaming_rewards.get("exp", 0)), 12, "流窜山贼应提供少量经验")
	assertions.assert_eq(int(roaming_rewards.get("coins", 0)), 8, "流窜山贼应提供少量固定铜钱")
	var loot_table = roaming_rewards.get("loot_table", {})
	assertions.assert_eq(int(loot_table.get("rolls", 0)), 2, "流窜山贼应配置 2 次掉落掷骰")
	var loot_entries = loot_table.get("entries", [])
	assertions.assert_eq(loot_entries.size(), 4, "流窜山贼应配置丹药、装备和铜钱掉落")
	assertions.assert_eq(repository.get_actor("roaming_bandit").get("name", ""), "流窜山贼", "应读取流窜山贼角色")

	var training_dummy = _find_object(mountain, "npc_training_dummy")
	assertions.assert_eq(training_dummy.get("type", ""), "npc", "山道应配置练功木桩交互点")
	assertions.assert_eq(training_dummy.get("name", ""), "练功木桩", "练功木桩应显示中文名称")
	assertions.assert_eq(training_dummy.get("dialogue_id", ""), "training_dummy_intro", "练功木桩应绑定训练对白")
	var dummy_dialogue = repository.get_dialogue("training_dummy_intro")
	var dummy_options = dummy_dialogue.get("options", [])
	assertions.assert_eq(dummy_options.size(), 3, "练功木桩应提供初中高三档")
	var hard_option = _find_option(dummy_options, "training_dummy_hard")
	assertions.assert_eq(hard_option.get("text", ""), "高档木桩", "高档木桩选项应使用中文文本")
	assertions.assert_true(typeof(hard_option.get("battle_context", {})) == TYPE_DICTIONARY, "高档木桩选项应携带战斗上下文")
	assertions.assert_eq(hard_option.get("battle_context", {}).get("battle_mode", ""), "tactical", "高档木桩应进入战棋战斗")
	assertions.assert_true(repository.get_actor("training_dummy_hard").get("attack", 0) >= 900, "高档木桩攻击应足够高，便于测试倒下回流")

	var village = repository.get_map("foot_village")
	assertions.assert_eq(village.get("name", ""), "山脚村镇", "应按编号读取山脚村镇")
	assertions.assert_eq(village.get("scene_path", ""), "res://scenes/foot_village.tscn", "村镇应声明场景路径")
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
	assertions.assert_eq(pharmacy_items.size(), 4, "药铺应配置丹药与基础装备商品")
	assertions.assert_true(pharmacy_items.has("herb_small"), "药铺应出售小还丹")
	assertions.assert_true(pharmacy_items.has("herb_focus"), "药铺应出售凝神丹")
	assertions.assert_true(pharmacy_items.has("cloth_armor"), "药铺应出售布衣")
	assertions.assert_true(pharmacy_items.has("jade_talisman"), "药铺应出售青玉坠")

	var road_exit = _find_object(village, "exit_to_road_outskirts")
	assertions.assert_eq(road_exit.get("type", ""), "exit", "村镇应配置官道出口")
	assertions.assert_eq(road_exit.get("target_map_id", ""), "road_outskirts", "官道出口应指向村外官道")
	assertions.assert_eq(road_exit.get("target_spawn_id", ""), "from_foot_village", "官道出口应指向官道村口出生点")
	assertions.assert_eq(road_exit.get("required_quest_id", ""), "quest_deliver_letter", "官道出口应要求送信任务")
	assertions.assert_eq(road_exit.get("required_quest_status", ""), "completed", "官道出口应要求送信任务完成")
	assertions.assert_eq(road_exit.get("locked_message", ""), "脚夫说前路不太平，先把书信送到客栈再说。", "官道出口应有条件锁定提示")

	var road = repository.get_map("road_outskirts")
	assertions.assert_eq(road.get("name", ""), "村外官道", "应按编号读取村外官道")
	assertions.assert_eq(road.get("scene_path", ""), "res://scenes/road_outskirts.tscn", "官道应声明场景路径")
	assertions.assert_true(road.get("spawn_points", {}).has("from_foot_village"), "官道应包含村镇进入出生点")
	var bundle = _find_object(road, "pickup_roadside_bundle")
	assertions.assert_eq(bundle.get("type", ""), "pickup", "官道应配置路边包裹")
	assertions.assert_eq(bundle.get("name", ""), "路边包裹", "包裹应显示中文名称")
	assertions.assert_eq(bundle.get("reward_coins", 0), 20, "包裹应奖励 20 文")
	assertions.assert_eq(bundle.get("reward_item_amounts", {}).get("herb_small", 0), 1, "包裹应奖励 1 个小还丹")

	assertions.assert_eq(repository.get_quest("quest_deliver_letter").get("title", ""), "送信到客栈", "应读取送信任务")
	assertions.assert_eq(repository.get_dialogue("deliver_letter_complete").get("title", ""), "书信送达", "应读取送信完成对白")

	var world = repository.get_map("world")
	assertions.assert_eq(world.get("name", ""), "世界大地图", "应按编号读取世界大地图")
	assertions.assert_eq(world.get("scene_path", ""), "res://scenes/world.tscn", "世界大地图应声明场景路径")
	assertions.assert_true(world.get("spawn_points", {}).has("from_village"), "世界大地图应包含村镇进入出生点")

	assertions.assert_eq(mountain.get("layout", {}).get("obstacles", []).size(), 6, "山道地图应合并布局障碍")
	assertions.assert_eq(_find_object(mountain, "exit_to_foot_village").get("position", {}).get("x", 0), 1160, "山道出口坐标应来自布局合并")

	assertions.assert_eq(repository.get_map("missing_map"), {}, "缺失地图编号应返回空字典")

	repository.free()

func _find_object(map_data: Dictionary, object_id: String) -> Dictionary:
	for object in map_data.get("objects", []):
		if object.get("id", "") == object_id:
			return object
	return {}

func _find_option(options: Array, option_id: String) -> Dictionary:
	for option in options:
		if typeof(option) == TYPE_DICTIONARY and str(option.get("id", "")) == option_id:
			return option
	return {}
