extends CanvasLayer

signal item_use_requested(item_id: String)
signal shop_buy_requested(item_id: String)

var quest_label: Label
var prompt_label: Label
var message_label: Label
var inventory_panel: Panel
var inventory_list: VBoxContainer
var inventory_empty_label: Label
var inventory_is_open := false
var shop_panel: Panel
var shop_title_label: Label
var shop_coins_label: Label
var shop_list: VBoxContainer
var shop_empty_label: Label
var shop_is_open := false

func _ready() -> void:
	quest_label = Label.new()
	quest_label.position = Vector2(24, 20)
	quest_label.size = Vector2(520, 32)
	add_child(quest_label)

	prompt_label = Label.new()
	prompt_label.position = Vector2(24, 640)
	prompt_label.size = Vector2(520, 32)
	add_child(prompt_label)

	message_label = Label.new()
	message_label.position = Vector2(24, 680)
	message_label.size = Vector2(800, 32)
	add_child(message_label)

	_create_inventory_panel()
	_create_shop_panel()

	set_quest_text("")
	set_prompt("")
	show_message("")

func set_quest_text(text: String) -> void:
	quest_label.text = text

func set_prompt(text: String) -> void:
	prompt_label.text = text

func show_message(text: String) -> void:
	message_label.text = text

func show_inventory(items: Array) -> void:
	inventory_is_open = true
	inventory_panel.visible = true
	refresh_inventory(items)

func hide_inventory() -> void:
	inventory_is_open = false
	inventory_panel.visible = false

func toggle_inventory(items: Array) -> void:
	if inventory_is_open:
		hide_inventory()
	else:
		show_inventory(items)

func refresh_inventory(items: Array) -> void:
	for child in inventory_list.get_children():
		child.queue_free()

	inventory_empty_label.visible = items.is_empty()
	if items.is_empty():
		return

	for item in items:
		_add_inventory_row(item)

func is_inventory_open() -> bool:
	return inventory_is_open

func show_shop(title: String, coins: int, items: Array) -> void:
	shop_is_open = true
	shop_panel.visible = true
	shop_title_label.text = title
	refresh_shop(coins, items)

func hide_shop() -> void:
	shop_is_open = false
	shop_panel.visible = false

func refresh_shop(coins: int, items: Array) -> void:
	shop_coins_label.text = "铜钱：%d" % coins
	for child in shop_list.get_children():
		child.queue_free()

	shop_empty_label.visible = items.is_empty()
	if items.is_empty():
		return

	for item in items:
		_add_shop_row(item)

func is_shop_open() -> bool:
	return shop_is_open

func _create_inventory_panel() -> void:
	inventory_panel = Panel.new()
	inventory_panel.position = Vector2(760, 72)
	inventory_panel.size = Vector2(460, 520)
	inventory_panel.visible = false
	add_child(inventory_panel)

	var title = Label.new()
	title.text = "背包"
	title.position = Vector2(16, 14)
	title.size = Vector2(160, 32)
	inventory_panel.add_child(title)

	var close_button = Button.new()
	close_button.text = "关闭"
	close_button.position = Vector2(368, 12)
	close_button.size = Vector2(72, 36)
	close_button.pressed.connect(hide_inventory)
	inventory_panel.add_child(close_button)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(16, 64)
	scroll.size = Vector2(428, 438)
	inventory_panel.add_child(scroll)

	inventory_list = VBoxContainer.new()
	inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inventory_list)

	inventory_empty_label = Label.new()
	inventory_empty_label.text = "背包空空如也。"
	inventory_empty_label.position = Vector2(32, 86)
	inventory_empty_label.size = Vector2(360, 32)
	inventory_empty_label.visible = false
	inventory_panel.add_child(inventory_empty_label)

func _create_shop_panel() -> void:
	shop_panel = Panel.new()
	shop_panel.position = Vector2(260, 72)
	shop_panel.size = Vector2(460, 520)
	shop_panel.visible = false
	add_child(shop_panel)

	shop_title_label = Label.new()
	shop_title_label.text = "药铺"
	shop_title_label.position = Vector2(16, 14)
	shop_title_label.size = Vector2(160, 32)
	shop_panel.add_child(shop_title_label)

	var close_button = Button.new()
	close_button.text = "关闭"
	close_button.position = Vector2(368, 12)
	close_button.size = Vector2(72, 36)
	close_button.pressed.connect(hide_shop)
	shop_panel.add_child(close_button)

	shop_coins_label = Label.new()
	shop_coins_label.text = "铜钱：0"
	shop_coins_label.position = Vector2(16, 52)
	shop_coins_label.size = Vector2(220, 32)
	shop_panel.add_child(shop_coins_label)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(16, 96)
	scroll.size = Vector2(428, 386)
	shop_panel.add_child(scroll)

	shop_list = VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(shop_list)

	shop_empty_label = Label.new()
	shop_empty_label.text = "药铺暂时没有可买之物。"
	shop_empty_label.position = Vector2(32, 122)
	shop_empty_label.size = Vector2(360, 32)
	shop_empty_label.visible = false
	shop_panel.add_child(shop_empty_label)

func _add_inventory_row(item: Dictionary) -> void:
	var row = VBoxContainer.new()
	row.custom_minimum_size = Vector2(400, 104)
	inventory_list.add_child(row)

	var name = str(item.get("name", "未知物品"))
	var quantity = int(item.get("quantity", 0))

	var header = Label.new()
	header.text = "%s x%d" % [name, quantity]
	header.size = Vector2(400, 24)
	row.add_child(header)

	var description = Label.new()
	description.text = str(item.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(400, 44)
	row.add_child(description)

	var use_button = Button.new()
	use_button.text = "使用"
	use_button.disabled = not bool(item.get("usable", false))
	use_button.custom_minimum_size = Vector2(72, 32)
	var item_id = str(item.get("id", ""))
	use_button.pressed.connect(func(): item_use_requested.emit(item_id))
	row.add_child(use_button)

func _add_shop_row(item: Dictionary) -> void:
	var row = VBoxContainer.new()
	row.custom_minimum_size = Vector2(400, 120)
	shop_list.add_child(row)

	var item_name = str(item.get("name", "未知商品"))
	var price = int(item.get("price", 0))

	var header = Label.new()
	header.text = "%s %d 文" % [item_name, price]
	header.size = Vector2(400, 24)
	row.add_child(header)

	var description = Label.new()
	description.text = str(item.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(400, 44)
	row.add_child(description)

	var buy_button = Button.new()
	buy_button.text = "购买"
	buy_button.disabled = not bool(item.get("can_buy", false))
	buy_button.custom_minimum_size = Vector2(72, 32)
	var item_id = str(item.get("id", ""))
	buy_button.pressed.connect(func(): shop_buy_requested.emit(item_id))
	row.add_child(buy_button)
