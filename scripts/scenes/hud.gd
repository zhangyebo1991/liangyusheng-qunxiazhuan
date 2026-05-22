extends CanvasLayer

const UiTheme = preload("res://scripts/core/ui_theme.gd")
const PartyPanelScript = preload("res://scripts/scenes/party_panel.gd")
const SkillTreePanelScript = preload("res://scripts/scenes/skill_tree_panel.gd")
const InnerArtPanelScript = preload("res://scripts/scenes/inner_art_panel.gd")
const InsightPopupScript = preload("res://scripts/scenes/insight_popup.gd")

signal item_use_requested(item_id: String)
signal shop_buy_requested(item_id: String)
signal journal_requested

var quest_label: Label
var prompt_label: Label
var message_label: Label
var journal_button: Button
var tracked_task_list: VBoxContainer
var inventory_panel: Panel
var inventory_list: VBoxContainer
var inventory_empty_label: Label
var inventory_is_open := false
var party_panel: PanelContainer
var shop_panel: Panel
var shop_title_label: Label
var shop_coins_label: Label
var shop_list: VBoxContainer
var shop_empty_label: Label
var shop_is_open := false
var mp_label: Label = null

var skill_tree_panel: PanelContainer
var inner_art_panel: PanelContainer
var insight_popup: PanelContainer
var growth_buttons: HBoxContainer

var _hud_root: Control
var _center_overlay: CenterContainer

func _ready() -> void:
	_hud_root = Control.new()
	_hud_root.name = "HudRoot"
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_hud_root)

	_build_top_left()
	_build_top_right()
	_build_bottom_left()
	_build_center_overlay()
	_create_inventory_panel()
	_create_shop_panel()
	_create_growth_panels()

	set_quest_text("")
	set_prompt("")
	show_message("")

	if is_inside_tree() and has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		if bus.has_signal("hero_mp_changed") and not bus.hero_mp_changed.is_connected(_on_hero_mp_changed):
			bus.hero_mp_changed.connect(_on_hero_mp_changed)

	if is_inside_tree() and has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		var cur_mp = int(gs.get("hero_cur_mp")) if gs.get("hero_cur_mp") != null else 0
		var max_mp = int(gs.get("hero_max_mp")) if gs.get("hero_max_mp") != null else 0
		refresh_mp_display(cur_mp, max_mp)
	else:
		refresh_mp_display(0, 0)

func _build_top_left() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "TopLeft"
	vbox.anchor_left = 0.0
	vbox.anchor_right = 0.4
	vbox.anchor_top = 0.0
	vbox.anchor_bottom = 0.0
	vbox.offset_left = 24
	vbox.offset_top = 20
	vbox.offset_right = -12
	vbox.add_theme_constant_override("separation", 4)
	_hud_root.add_child(vbox)

	quest_label = Label.new()
	quest_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	quest_label.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE_NORMAL)
	vbox.add_child(quest_label)

	tracked_task_list = VBoxContainer.new()
	tracked_task_list.add_theme_constant_override("separation", 2)
	vbox.add_child(tracked_task_list)

func _build_top_right() -> void:
	growth_buttons = HBoxContainer.new()
	growth_buttons.name = "TopRight"
	growth_buttons.anchor_left = 1.0
	growth_buttons.anchor_right = 1.0
	growth_buttons.anchor_top = 0.0
	growth_buttons.anchor_bottom = 0.0
	growth_buttons.offset_left = -310
	growth_buttons.offset_right = -24
	growth_buttons.offset_top = 20
	growth_buttons.add_theme_constant_override("separation", 8)
	growth_buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hud_root.add_child(growth_buttons)

	journal_button = Button.new()
	journal_button.text = "记事"
	journal_button.custom_minimum_size = Vector2(96, 36)
	UiTheme.apply_button_theme(journal_button)
	journal_button.pressed.connect(func(): journal_requested.emit())
	growth_buttons.add_child(journal_button)

func _build_bottom_left() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "BottomLeft"
	vbox.anchor_left = 0.0
	vbox.anchor_right = 0.45
	vbox.anchor_top = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 24
	vbox.offset_top = -100
	vbox.offset_right = -12
	vbox.offset_bottom = -24
	vbox.add_theme_constant_override("separation", 2)
	vbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud_root.add_child(vbox)

	mp_label = Label.new()
	mp_label.name = "MpLabel"
	mp_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_BLUE)
	vbox.add_child(mp_label)

	prompt_label = Label.new()
	prompt_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_WARM)
	vbox.add_child(prompt_label)

	message_label = Label.new()
	message_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	vbox.add_child(message_label)

func _build_center_overlay() -> void:
	_center_overlay = CenterContainer.new()
	_center_overlay.name = "CenterOverlay"
	_center_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_center_overlay)

func set_quest_text(text: String) -> void:
	quest_label.text = text

func set_prompt(text: String) -> void:
	prompt_label.text = text

func show_message(text: String) -> void:
	message_label.text = text

func refresh_mp_display(cur_mp: int, max_mp: int) -> void:
	if mp_label != null:
		mp_label.text = "内力 %d/%d" % [cur_mp, max_mp]

func _on_hero_mp_changed(cur_mp: int, max_mp: int) -> void:
	refresh_mp_display(cur_mp, max_mp)

func set_tracked_tasks(tasks: Array) -> void:
	for child in tracked_task_list.get_children():
		tracked_task_list.remove_child(child)
		child.queue_free()
	var count = min(tasks.size(), 3)
	for index in range(count):
		var task = tasks[index]
		if typeof(task) != TYPE_DICTIONARY:
			continue
		var label := Label.new()
		label.text = "%s：%s" % [str(task.get("title", "未知任务")), str(task.get("status_text", ""))]
		label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_WARM)
		tracked_task_list.add_child(label)

func show_inventory(items: Array) -> void:
	inventory_is_open = true
	inventory_panel.visible = true
	refresh_inventory(items)

func hide_inventory() -> void:
	inventory_is_open = false
	inventory_panel.visible = false

func show_party_panel(party, repository) -> void:
	if party_panel == null:
		party_panel = PartyPanelScript.new()
		_center_overlay.add_child(party_panel)
	party_panel.visible = true
	party_panel.set_party_context(party, repository)

func hide_party_panel() -> void:
	if party_panel != null:
		party_panel.visible = false

func toggle_party_panel(party, repository) -> void:
	if party_panel != null and party_panel.visible:
		hide_party_panel()
	else:
		show_party_panel(party, repository)

func is_party_panel_open() -> bool:
	return party_panel != null and party_panel.visible

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
	inventory_panel.set_anchors_preset(Control.PRESET_CENTER)
	inventory_panel.custom_minimum_size = Vector2(480, 560)
	inventory_panel.visible = false
	inventory_panel.add_theme_stylebox_override("panel", UiTheme.make_gold_panel())
	_center_overlay.add_child(inventory_panel)

	# 内容 VBox
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 0)
	inventory_panel.add_child(content)

	# 标题栏
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 54)
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)

	# 标题栏背景
	var header_bg := ColorRect.new()
	header_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	header_bg.color = UiTheme.COLOR_BG_INK_LIGHT
	header_bg.z_index = UiTheme.Z_LAYER_BG
	header.add_child(header_bg)

	# 装饰竖线
	var deco := ColorRect.new()
	deco.custom_minimum_size = Vector2(3, 34)
	deco.color = UiTheme.COLOR_BORDER_GOLD
	var deco_margin := MarginContainer.new()
	deco_margin.add_theme_constant_override("margin_left", 14)
	deco_margin.add_theme_constant_override("margin_top", 10)
	deco_margin.add_theme_constant_override("margin_bottom", 10)
	deco_margin.add_child(deco)
	header.add_child(deco_margin)

	# 标题
	var title := Label.new()
	title.text = "囊 中 之 物"
	title.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	title.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE_TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	# 关闭按钮
	var close_button := Button.new()
	close_button.text = "✕ 关闭"
	close_button.custom_minimum_size = Vector2(82, 32)
	UiTheme.apply_close_button_theme(close_button)
	close_button.pressed.connect(hide_inventory)
	var close_margin := MarginContainer.new()
	close_margin.add_theme_constant_override("margin_right", 12)
	close_margin.add_theme_constant_override("margin_top", 11)
	close_margin.add_child(close_button)
	header.add_child(close_margin)

	# 金线分隔
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = UiTheme.COLOR_SEPARATOR
	content.add_child(sep)

	# 滚动内容区
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll_margin := MarginContainer.new()
	scroll_margin.add_theme_constant_override("margin_left", 12)
	scroll_margin.add_theme_constant_override("margin_right", 12)
	scroll_margin.add_theme_constant_override("margin_top", 8)
	scroll_margin.add_theme_constant_override("margin_bottom", 8)
	scroll_margin.add_child(scroll)
	content.add_child(scroll_margin)

	inventory_list = VBoxContainer.new()
	inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_list.add_theme_constant_override("separation", 6)
	scroll.add_child(inventory_list)

	inventory_empty_label = Label.new()
	inventory_empty_label.text = "　　囊中空空，一无所有。"
	inventory_empty_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_DIM)
	inventory_empty_label.visible = false
	content.add_child(inventory_empty_label)

func _create_shop_panel() -> void:
	shop_panel = Panel.new()
	shop_panel.set_anchors_preset(Control.PRESET_CENTER)
	shop_panel.custom_minimum_size = Vector2(460, 520)
	shop_panel.visible = false
	shop_panel.add_theme_stylebox_override("panel", UiTheme.make_gold_panel())
	_center_overlay.add_child(shop_panel)

	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 4)
	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 16)
	content_margin.add_theme_constant_override("margin_right", 16)
	content_margin.add_theme_constant_override("margin_top", 14)
	content_margin.add_theme_constant_override("margin_bottom", 14)
	content_margin.add_child(content)
	shop_panel.add_child(content_margin)

	# 标题行
	var header := HBoxContainer.new()
	content.add_child(header)

	shop_title_label = Label.new()
	shop_title_label.text = "药铺"
	shop_title_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	shop_title_label.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE_TITLE)
	shop_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(shop_title_label)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(72, 36)
	UiTheme.apply_close_button_theme(close_button)
	close_button.pressed.connect(hide_shop)
	header.add_child(close_button)

	shop_coins_label = Label.new()
	shop_coins_label.text = "铜钱：0"
	shop_coins_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	content.add_child(shop_coins_label)

	# 滚动列表
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	shop_list = VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_list.add_theme_constant_override("separation", 4)
	scroll.add_child(shop_list)

	shop_empty_label = Label.new()
	shop_empty_label.text = "药铺暂时没有可买之物。"
	shop_empty_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_DIM)
	shop_empty_label.visible = false
	content.add_child(shop_empty_label)

func _add_inventory_row(item: Dictionary) -> void:
	var item_name = str(item.get("name", "未知物品"))
	var quantity = int(item.get("quantity", 0))
	var desc_text = str(item.get("description", ""))
	var is_usable = bool(item.get("usable", false))
	var item_id = str(item.get("id", ""))

	# 卡片容器
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(440, 0)
	card.add_theme_stylebox_override("panel", UiTheme.make_card_style())
	inventory_list.add_child(card)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	card.add_child(inner)

	# 左侧文字区
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 3)
	inner.add_child(text_col)

	# 名称行
	var name_row := HBoxContainer.new()
	text_col.add_child(name_row)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	name_label.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE_NORMAL)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_label)

	var qty_label := Label.new()
	qty_label.text = "×%d" % quantity
	qty_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GREEN)
	qty_label.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE_SMALL)
	name_row.add_child(qty_label)

	# 描述
	if not desc_text.is_empty():
		var desc_label := Label.new()
		desc_label.text = desc_text
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(0, 32)
		desc_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_WARM)
		desc_label.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE_SMALL)
		text_col.add_child(desc_label)

	# 使用按钮
	var use_button := Button.new()
	use_button.text = "使　用" if is_usable else "——"
	use_button.disabled = not is_usable
	use_button.custom_minimum_size = Vector2(68, 40)
	if is_usable:
		var btn_styles := UiTheme.make_button_style()
		use_button.add_theme_stylebox_override("normal", btn_styles["normal"])
		use_button.add_theme_stylebox_override("hover", btn_styles["hover"])
		use_button.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
		use_button.pressed.connect(func(): item_use_requested.emit(item_id))
	else:
		use_button.add_theme_stylebox_override("disabled", UiTheme.make_disabled_button_style())
		use_button.add_theme_color_override("font_color_disabled", UiTheme.COLOR_TEXT_DISABLED)
	inner.add_child(use_button)

func _add_shop_row(item: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.custom_minimum_size = Vector2(400, 0)
	row.add_theme_constant_override("separation", 2)
	shop_list.add_child(row)

	var item_name = str(item.get("name", "未知商品"))
	var price = int(item.get("price", 0))

	var header := HBoxContainer.new()
	row.add_child(header)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var price_label := Label.new()
	price_label.text = "%d 文" % price
	price_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GREEN)
	header.add_child(price_label)

	var description := Label.new()
	description.text = str(item.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_WARM)
	row.add_child(description)

	var buy_button := Button.new()
	buy_button.text = "购买"
	buy_button.disabled = not bool(item.get("can_buy", false))
	buy_button.custom_minimum_size = Vector2(72, 32)
	UiTheme.apply_button_theme(buy_button)
	var item_id = str(item.get("id", ""))
	buy_button.pressed.connect(func(): shop_buy_requested.emit(item_id))
	row.add_child(buy_button)

func _create_growth_panels() -> void:
	# 技能树按钮
	var skill_tree_button := Button.new()
	skill_tree_button.text = "技能树"
	skill_tree_button.custom_minimum_size = Vector2(90, 36)
	UiTheme.apply_button_theme(skill_tree_button)
	skill_tree_button.pressed.connect(toggle_skill_tree)
	growth_buttons.add_child(skill_tree_button)

	# 心法按钮
	var inner_art_button := Button.new()
	inner_art_button.text = "心法"
	inner_art_button.custom_minimum_size = Vector2(90, 36)
	UiTheme.apply_button_theme(inner_art_button)
	inner_art_button.pressed.connect(toggle_inner_art)
	growth_buttons.add_child(inner_art_button)

	skill_tree_panel = SkillTreePanelScript.new()
	skill_tree_panel.set_anchors_preset(Control.PRESET_CENTER)
	_center_overlay.add_child(skill_tree_panel)

	inner_art_panel = InnerArtPanelScript.new()
	inner_art_panel.set_anchors_preset(Control.PRESET_CENTER)
	_center_overlay.add_child(inner_art_panel)

	insight_popup = InsightPopupScript.new()
	insight_popup.set_anchors_preset(Control.PRESET_CENTER)
	_center_overlay.add_child(insight_popup)

func set_growth_manager(manager: RefCounted) -> void:
	if skill_tree_panel != null:
		skill_tree_panel.set_growth_manager(manager)
	if inner_art_panel != null:
		inner_art_panel.set_growth_manager(manager)

func toggle_skill_tree() -> void:
	if skill_tree_panel == null:
		return
	if skill_tree_panel.visible:
		skill_tree_panel.close()
	else:
		hide_inventory()
		hide_shop()
		hide_party_panel()
		skill_tree_panel.open()

func toggle_inner_art() -> void:
	if inner_art_panel == null:
		return
	if inner_art_panel.visible:
		inner_art_panel.close()
	else:
		hide_inventory()
		hide_shop()
		hide_party_panel()
		inner_art_panel.open()

func show_insight(message: String, unlock_name: String = "") -> void:
	if insight_popup != null:
		insight_popup.show_insight(message, unlock_name)

func is_growth_panel_open() -> bool:
	return (skill_tree_panel != null and skill_tree_panel.visible) or \
		   (inner_art_panel != null and inner_art_panel.visible)

func hide_all_growth_panels() -> void:
	if skill_tree_panel != null:
		skill_tree_panel.close()
	if inner_art_panel != null:
		inner_art_panel.close()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_K:
				toggle_skill_tree()
			KEY_J:
				toggle_inner_art()
			KEY_ESCAPE:
				if is_growth_panel_open():
					hide_all_growth_panels()
					get_viewport().set_input_as_handled()
