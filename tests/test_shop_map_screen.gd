extends RefCounted

const MapScreenBaseScript = preload("res://scripts/scenes/map_screen_base.gd")
const HudScript = preload("res://scripts/scenes/hud.gd")

func run(assertions) -> void:
	var root = Engine.get_main_loop().root
	var repository = root.get_node("DataRepository")
	var game_state = root.get_node("GameState")
	repository.load_all()
	game_state.start_new_game()

	var screen = MapScreenBaseScript.new()
	var shop_record = {
		"id": "shop_foot_village_pharmacy",
		"type": "shop",
		"name": "药铺",
		"items": ["herb_small"]
	}
	var items = screen._build_shop_items(shop_record)
	assertions.assert_eq(items.size(), 1, "地图场景应能根据药铺对象构建商品列表")
	assertions.assert_eq(items[0].get("id", ""), "herb_small", "商品列表应保留物品编号")
	assertions.assert_eq(items[0].get("name", ""), "小还丹", "商品列表应显示物品名称")
	assertions.assert_eq(items[0].get("price", -1), 30, "商品列表应读取物品价格")
	assertions.assert_true(bool(items[0].get("can_buy", false)), "价格有效的商品应允许点击购买")

	var empty_items = screen._build_shop_items({"items": []})
	assertions.assert_eq(empty_items.size(), 0, "空药铺对象应返回空商品列表")

	var missing_items = screen._build_shop_items({"items": ["missing_item"]})
	assertions.assert_eq(missing_items.size(), 1, "缺失商品仍应返回不可购买行")
	assertions.assert_eq(missing_items[0].get("description", ""), "此商品暂时不能购买。", "缺失商品应显示不可购买说明")
	assertions.assert_true(not bool(missing_items[0].get("can_buy", true)), "缺失商品不应允许购买")

	screen.hud = HudScript.new()
	screen.hud._ready()
	screen.shop_system.set_repository(repository)
	screen.current_shop_record = shop_record.duplicate(true)
	screen.hud.show_shop("药铺", game_state.party.coins, screen._build_shop_items(screen.current_shop_record))
	screen._on_shop_buy_requested("herb_small")
	assertions.assert_eq(game_state.party.coins, 50, "地图场景处理购买后应扣铜钱")
	assertions.assert_eq(game_state.party.get_item_count("herb_small"), 2, "地图场景处理购买后应加物品")
	assertions.assert_eq(screen.hud.message_label.text, "买入小还丹。", "地图场景购买后应显示系统返回消息")
	assertions.assert_eq(screen.hud.shop_coins_label.text, "铜钱：50", "地图场景购买后应刷新商店铜钱")

	screen.hud.free()
	screen.free()
