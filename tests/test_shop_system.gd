extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const ShopSystemScript = preload("res://scripts/systems/shop_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()

	var system = ShopSystemScript.new()
	system.set_repository(repository)

	var state = GameStateScript.new()
	state.start_new_game()
	var start_count = state.party.get_item_count("herb_small")
	var success = system.buy_item(state, "herb_small")
	assertions.assert_true(bool(success.get("success", false)), "铜钱足够时应能购买小还丹")
	assertions.assert_eq(success.get("message", ""), "买入小还丹。", "购买成功应返回中文提示")
	assertions.assert_eq(success.get("cost", -1), 30, "购买结果应返回花费")
	assertions.assert_eq(success.get("coins", -1), 50, "购买结果应返回剩余铜钱")
	assertions.assert_eq(success.get("remaining", -1), start_count + 1, "购买结果应返回背包剩余数量")
	assertions.assert_eq(state.party.coins, 50, "购买后应扣除铜钱")
	assertions.assert_eq(state.party.get_item_count("herb_small"), start_count + 1, "购买后应增加物品")

	var chain_state = GameStateScript.new()
	chain_state.start_new_game()
	var chain_start_count = chain_state.party.get_item_count("herb_small")
	system.buy_item(chain_state, "herb_small")
	system.buy_item(chain_state, "herb_small")
	assertions.assert_eq(chain_state.party.coins, 20, "连续购买两次后应剩余 20 铜钱")
	assertions.assert_eq(chain_state.party.get_item_count("herb_small"), chain_start_count + 2, "连续购买两次应增加两个小还丹")

	var before_third_count = chain_state.party.get_item_count("herb_small")
	var insufficient = system.buy_item(chain_state, "herb_small")
	assertions.assert_true(not bool(insufficient.get("success", true)), "铜钱不足时购买应失败")
	assertions.assert_eq(insufficient.get("message", ""), "铜钱不足。", "铜钱不足应返回提示")
	assertions.assert_eq(chain_state.party.coins, 20, "铜钱不足时不应扣钱")
	assertions.assert_eq(chain_state.party.get_item_count("herb_small"), before_third_count, "铜钱不足时不应增加物品")

	var missing_state = GameStateScript.new()
	missing_state.start_new_game()
	var missing = system.buy_item(missing_state, "missing_item")
	assertions.assert_true(not bool(missing.get("success", true)), "商品资料缺失时购买应失败")
	assertions.assert_eq(missing.get("message", ""), "此商品暂时不能购买。", "商品资料缺失应返回提示")
	assertions.assert_eq(missing_state.party.coins, 80, "商品资料缺失时不应扣钱")
	assertions.assert_eq(missing_state.party.get_item_count("missing_item"), 0, "商品资料缺失时不应增加物品")

	repository.content["items"].append({
		"id": "invalid_price_pill",
		"name": "无价丹",
		"type": "consumable",
		"description": "价格配置错误的丹药。",
		"value": 0,
		"effects": {"heal_hp": 30},
	})
	var invalid_price_state = GameStateScript.new()
	invalid_price_state.start_new_game()
	var invalid_price = system.buy_item(invalid_price_state, "invalid_price_pill")
	assertions.assert_true(not bool(invalid_price.get("success", true)), "价格无效时购买应失败")
	assertions.assert_eq(invalid_price.get("message", ""), "此商品暂时不能购买。", "价格无效应返回提示")
	assertions.assert_eq(invalid_price_state.party.coins, 80, "价格无效时不应扣钱")
	assertions.assert_eq(invalid_price_state.party.get_item_count("invalid_price_pill"), 0, "价格无效时不应增加物品")

	var invalid_quantity_state = GameStateScript.new()
	invalid_quantity_state.start_new_game()
	var invalid_quantity = system.buy_item(invalid_quantity_state, "herb_small", 0)
	assertions.assert_true(not bool(invalid_quantity.get("success", true)), "数量无效时购买应失败")
	assertions.assert_eq(invalid_quantity.get("message", ""), "此商品暂时不能购买。", "数量无效应返回提示")
	assertions.assert_eq(invalid_quantity_state.party.coins, 80, "数量无效时不应扣钱")

	state.free()
	chain_state.free()
	missing_state.free()
	invalid_price_state.free()
	invalid_quantity_state.free()
	repository.free()
