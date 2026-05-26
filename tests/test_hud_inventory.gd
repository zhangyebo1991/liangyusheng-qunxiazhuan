extends RefCounted

const HudScript = preload("res://scripts/scenes/hud.gd")

func run(assertions) -> void:
	var hud = HudScript.new()
	hud._ready()

	assertions.assert_true(hud.has_signal("journal_requested"), "HUD 应提供记事请求信号")
	assertions.assert_true(hud.has_method("set_tracked_tasks"), "HUD 应提供追踪任务刷新方法")
	if not hud.has_signal("journal_requested") or not hud.has_method("set_tracked_tasks"):
		hud.free()
		return

	var journal_requests: Array[int] = []
	hud.journal_requested.connect(func(): journal_requests.append(1))
	assertions.assert_eq(hud.journal_button.text, "记事", "HUD 应显示记事按钮")
	hud.journal_button.pressed.emit()
	assertions.assert_eq(journal_requests.size(), 1, "点击记事按钮应发出请求信号")

	hud.set_tracked_tasks([
		{"title": "山道试剑", "status_text": "进行中"},
		{"title": "送信到客栈", "status_text": "已完成"},
		{"title": "追查红线车辙", "status_text": "未开始"},
		{"title": "第四任务", "status_text": "未开始"}
	])
	assertions.assert_eq(hud.tracked_task_list.get_child_count(), 3, "HUD 最多显示 3 个追踪任务")
	assertions.assert_eq(hud.tracked_task_list.get_child(0).text, "山道试剑：进行中", "追踪任务应显示标题和状态")

	hud.set_tracked_tasks([])
	assertions.assert_eq(hud.tracked_task_list.get_child_count(), 0, "空追踪任务应清空 HUD 追踪区")

	hud.show_inventory([{
		"id": "herb_small",
		"name": "小还丹",
		"type": "consumable",
		"description": "少量恢复气血。",
		"quantity": 1,
		"usable": true,
	}])

	var row = hud.inventory_list.get_child(0)
	var inner = row.get_child(0)
	var text_col = inner.get_child(0)
	var name_row = text_col.get_child(0)
	var item_name_label = name_row.get_child(0)
	var quantity_label = name_row.get_child(1)
	assertions.assert_eq(item_name_label.text, "小还丹", "背包物品名称不应显示内部类型")
	assertions.assert_eq(quantity_label.text, "×1", "背包物品数量应显示为中文界面数量")

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
	assertions.assert_eq(shop_header.get_child(0).text, "小还丹", "商品标题应显示名称")
	assertions.assert_eq(shop_header.get_child(1).text, "30 文", "商品标题应显示价格")

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
