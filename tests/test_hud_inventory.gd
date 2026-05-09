extends RefCounted

const HudScript = preload("res://scripts/scenes/hud.gd")

func run(assertions) -> void:
	var hud = HudScript.new()
	hud._ready()

	hud.show_inventory([{
		"id": "herb_small",
		"name": "小还丹",
		"type": "consumable",
		"description": "少量恢复气血。",
		"quantity": 1,
		"usable": true,
	}])

	var row = hud.inventory_list.get_child(0)
	var header = row.get_child(0)
	assertions.assert_eq(header.text, "小还丹 x1", "背包物品标题不应显示内部类型")

	var requested_items: Array[String] = []
	hud.shop_buy_requested.connect(func(item_id: String): requested_items.append(item_id))
	hud.show_shop("药铺", 80, [{
		"id": "herb_small",
		"name": "小还丹",
		"description": "恢复少量气血。",
		"price": 30,
		"can_buy": true,
	}])

	assertions.assert_true(hud.is_shop_open(), "调用 show_shop 后商店面板应打开")
	assertions.assert_eq(hud.shop_title_label.text, "药铺", "商店标题应显示传入名称")
	assertions.assert_eq(hud.shop_coins_label.text, "铜钱：80", "商店应显示当前铜钱")

	var shop_row = hud.shop_list.get_child(0)
	var shop_header = shop_row.get_child(0)
	assertions.assert_eq(shop_header.text, "小还丹 30 文", "商品标题应显示名称和价格")

	var buy_button = shop_row.get_child(2)
	assertions.assert_eq(buy_button.text, "购买", "商品行应包含购买按钮")
	buy_button.pressed.emit()
	assertions.assert_eq(requested_items.size(), 1, "点击购买应发出购买信号")
	assertions.assert_eq(requested_items[0], "herb_small", "购买信号应携带商品编号")

	hud.refresh_shop(50, [])
	assertions.assert_eq(hud.shop_coins_label.text, "铜钱：50", "刷新商店应更新铜钱")
	assertions.assert_true(hud.shop_empty_label.visible, "空商品列表应显示空药铺提示")

	hud.hide_shop()
	assertions.assert_true(not hud.is_shop_open(), "调用 hide_shop 后商店面板应关闭")

	hud.free()
