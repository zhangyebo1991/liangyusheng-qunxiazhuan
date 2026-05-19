extends PanelContainer

signal art_upgraded(art_id: String)
signal art_switched(art_id: String)
signal panel_closed

var growth_manager: RefCounted = null
var art_list: VBoxContainer
var detail_panel: VBoxContainer
var effects_label: Label
var current_art_id: String = ""

func _init() -> void:
	custom_minimum_size = Vector2(700, 500)
	visible = false

func _ready() -> void:
	_build_ui()

func set_growth_manager(manager: RefCounted) -> void:
	growth_manager = manager
	_refresh_art_list()

func _build_ui() -> void:
	var main_split = HSplitContainer.new()
	main_split.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_split.split_offset = 220
	add_child(main_split)

	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(220, 0)
	main_split.add_child(left_panel)

	var art_title = Label.new()
	art_title.text = "内功心法"
	art_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(art_title)

	var art_scroll = ScrollContainer.new()
	art_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(art_scroll)

	art_list = VBoxContainer.new()
	art_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_scroll.add_child(art_list)

	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_split.add_child(right_panel)

	var header = HBoxContainer.new()
	right_panel.add_child(header)

	var detail_title = Label.new()
	detail_title.text = "心法详情"
	detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(detail_title)

	var close_button = Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	detail_panel = VBoxContainer.new()
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(detail_panel)

	effects_label = Label.new()
	effects_label.text = "当前效果：无"
	effects_label.custom_minimum_size = Vector2(0, 80)
	right_panel.add_child(effects_label)

func _refresh_art_list() -> void:
	for child in art_list.get_children():
		child.queue_free()

	if growth_manager == null:
		return

	var learned_arts = growth_manager.inner_arts._learned_arts
	var all_arts = growth_manager.inner_arts._arts

	for art_id in all_arts.keys():
		var art_data = all_arts[art_id]
		var is_learned = learned_arts.has(art_id)
		var is_active = growth_manager.inner_arts._active_art == art_id

		var button = Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if is_active:
			button.text = "★ " + str(art_data.get("name", art_id)) + " (激活)"
		elif is_learned:
			button.text = str(art_data.get("name", art_id))
		else:
			button.text = str(art_data.get("name", art_id)) + " (未学)"

		button.pressed.connect(_on_art_selected.bind(art_id))
		art_list.add_child(button)

func _on_art_selected(art_id: String) -> void:
	current_art_id = art_id
	_display_art_detail(art_id)

func _display_art_detail(art_id: String) -> void:
	for child in detail_panel.get_children():
		child.queue_free()

	if growth_manager == null:
		return

	var art_data = growth_manager.inner_arts._arts.get(art_id, {})
	if art_data.is_empty():
		return

	var is_learned = growth_manager.inner_arts._learned_arts.has(art_id)
	var level = growth_manager.inner_arts.get_art_level(art_id)
	var max_level = int(art_data.get("max_level", 1))
	var is_active = growth_manager.inner_arts._active_art == art_id

	var name_label = Label.new()
	name_label.text = str(art_data.get("name", ""))
	detail_panel.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = str(art_data.get("description", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(desc_label)

	var level_label = Label.new()
	if is_learned:
		level_label.text = "等级：" + str(level) + "/" + str(max_level)
	else:
		level_label.text = "状态：未学习"
	detail_panel.add_child(level_label)

	if is_learned:
		var effects = growth_manager.inner_arts.get_active_effects()
		if not effects.is_empty():
			var effects_text = "当前效果："
			for key in effects.keys():
				effects_text += "\n  " + _format_effect(key, effects[key])
			effects_label.text = effects_text
		else:
			effects_label.text = "当前效果：无（心法未激活）"

		var button_row = HBoxContainer.new()
		detail_panel.add_child(button_row)

		if level < max_level:
			var costs = art_data.get("level_up_cost", [])
			var cost = 1
			if level < costs.size():
				cost = int(costs[level])

			var upgrade_button = Button.new()
			upgrade_button.text = "升级 (消耗" + str(cost) + "点)"
			upgrade_button.disabled = growth_manager.proficiency_points < cost
			upgrade_button.pressed.connect(_on_upgrade_pressed.bind(art_id))
			button_row.add_child(upgrade_button)

		if not is_active:
			var switch_button = Button.new()
			switch_button.text = "激活"
			switch_button.pressed.connect(_on_switch_pressed.bind(art_id))
			button_row.add_child(switch_button)
	else:
		var learn_button = Button.new()
		learn_button.text = "学习"
		learn_button.pressed.connect(_on_learn_pressed.bind(art_id))
		detail_panel.add_child(learn_button)
		effects_label.text = "当前效果：无（未学习）"

func _on_learn_pressed(art_id: String) -> void:
	if growth_manager == null:
		return

	var result = growth_manager.learn_art(art_id)
	if result.get("success", false):
		_display_art_detail(art_id)
		_refresh_art_list()

func _on_upgrade_pressed(art_id: String) -> void:
	if growth_manager == null:
		return

	var result = growth_manager.upgrade_art(art_id)
	if result.get("success", false):
		art_upgraded.emit(art_id)
		_display_art_detail(art_id)
		_refresh_art_list()

func _on_switch_pressed(art_id: String) -> void:
	if growth_manager == null:
		return

	var result = growth_manager.switch_active(art_id)
	if result.get("success", false):
		art_switched.emit(art_id)
		_display_art_detail(art_id)
		_refresh_art_list()

func _format_effect(key: String, value) -> String:
	match key:
		"max_mp":
			return "内力上限 +" + str(value)
		"mp_regen":
			return "内力回复 +" + str(value)
		"defense":
			return "防御 +" + str(value)
		"attack":
			return "攻击 +" + str(value)
		_:
			return str(key) + " +" + str(value)

func _on_close_pressed() -> void:
	visible = false
	panel_closed.emit()

func open() -> void:
	_refresh_art_list()
	visible = true

func close() -> void:
	visible = false
