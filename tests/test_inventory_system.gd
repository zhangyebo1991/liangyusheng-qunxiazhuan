extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const InventorySystemScript = preload("res://scripts/systems/inventory_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()

	var system = InventorySystemScript.new()
	system.set_repository(repository)
	var state = GameStateScript.new()
	state.start_new_game()
	state.hero_hp = 60

	var success = system.use_item(state, "herb_small")
	assertions.assert_true(bool(success.get("success", false)), "气血未满时应能使用小还丹")
	assertions.assert_eq(success.get("message", ""), "服下小还丹，气血恢复。", "成功使用应返回中文提示")
	assertions.assert_eq(state.hero_hp, 90, "小还丹应恢复 30 点气血")
	assertions.assert_eq(state.party.get_item_count("herb_small"), 0, "使用后应扣除 1 个小还丹")
	assertions.assert_eq(success.get("remaining", -1), 0, "结果应返回剩余数量")

	var full_hp_state = GameStateScript.new()
	full_hp_state.start_new_game()
	var full_hp_result = system.use_item(full_hp_state, "herb_small")
	assertions.assert_true(not bool(full_hp_result.get("success", true)), "气血已满时不应使用小还丹")
	assertions.assert_eq(full_hp_result.get("message", ""), "气血已满。", "气血已满应返回提示")
	assertions.assert_eq(full_hp_state.party.get_item_count("herb_small"), 1, "气血已满时不应扣物品")

	var missing_count_state = GameStateScript.new()
	missing_count_state.start_new_game()
	missing_count_state.party.remove_item("herb_small", 1)
	var missing_count = system.use_item(missing_count_state, "herb_small")
	assertions.assert_true(not bool(missing_count.get("success", true)), "数量不足时不应使用物品")
	assertions.assert_eq(missing_count.get("message", ""), "背包中没有此物。", "数量不足应返回提示")

	var missing_data_state = GameStateScript.new()
	missing_data_state.start_new_game()
	missing_data_state.hero_hp = 60
	missing_data_state.party.add_item("missing_item", 1)
	var missing_data = system.use_item(missing_data_state, "missing_item")
	assertions.assert_true(not bool(missing_data.get("success", true)), "资料缺失时不应使用物品")
	assertions.assert_eq(missing_data.get("message", ""), "此物品资料缺失。", "资料缺失应返回提示")
	assertions.assert_eq(missing_data_state.party.get_item_count("missing_item"), 1, "资料缺失时不应扣物品")

	var weapon_state = GameStateScript.new()
	weapon_state.start_new_game()
	weapon_state.hero_hp = 60
	weapon_state.party.add_item("iron_sword", 1)
	var weapon_result = system.use_item(weapon_state, "iron_sword")
	assertions.assert_true(not bool(weapon_result.get("success", true)), "非消耗品不应直接使用")
	assertions.assert_eq(weapon_result.get("message", ""), "此物暂时不能使用。", "非消耗品应返回提示")
	assertions.assert_eq(weapon_state.party.get_item_count("iron_sword"), 1, "非消耗品使用失败时不应扣物品")

	repository.content["items"].append({
		"id": "blank_pill",
		"name": "空丹",
		"type": "consumable",
		"description": "没有效果的丹药。",
		"value": 1,
		"effects": {},
	})
	var blank_state = GameStateScript.new()
	blank_state.start_new_game()
	blank_state.hero_hp = 60
	blank_state.party.add_item("blank_pill", 1)
	var blank_result = system.use_item(blank_state, "blank_pill")
	assertions.assert_true(not bool(blank_result.get("success", true)), "效果缺失时不应使用物品")
	assertions.assert_eq(blank_result.get("message", ""), "此物暂时不能使用。", "效果缺失应返回提示")
	assertions.assert_eq(blank_state.party.get_item_count("blank_pill"), 1, "效果缺失时不应扣物品")

	state.free()
	full_hp_state.free()
	missing_count_state.free()
	missing_data_state.free()
	weapon_state.free()
	blank_state.free()
	repository.free()
