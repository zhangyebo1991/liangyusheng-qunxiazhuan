extends CanvasLayer

const UiTheme = preload("res://scripts/core/ui_theme.gd")

signal closed
signal quest_tracking_toggled(quest_id: String)

var panel: Panel
var title_label: Label
var task_list: VBoxContainer
var active_rumor_list: VBoxContainer
var triggered_rumor_list: VBoxContainer
var message_label: Label

func _ready() -> void:
	var root := Control.new()
	root.name = "JournalRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	panel = Panel.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = UiTheme.SIDE_MARGIN
	panel.offset_right = -UiTheme.SIDE_MARGIN
	panel.offset_top = 64
	panel.offset_bottom = -64
	panel.add_theme_stylebox_override("panel", UiTheme.make_gold_panel(6, 10))
	root.add_child(panel)

	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 8)
	var content_margin := MarginContainer.new()
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left", 24)
	content_margin.add_theme_constant_override("margin_right", 24)
	content_margin.add_theme_constant_override("margin_top", 16)
	content_margin.add_theme_constant_override("margin_bottom", 16)
	content_margin.add_child(content)
	panel.add_child(content_margin)

	# 标题栏
	var header := HBoxContainer.new()
	content.add_child(header)

	title_label = Label.new()
	title_label.text = "江湖记事"
	title_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	title_label.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE_TITLE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(72, 36)
	UiTheme.apply_close_button_theme(close_button)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	# 金线分隔
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = UiTheme.COLOR_SEPARATOR
	content.add_child(sep)

	# 主体：左右分栏
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	content.add_child(body)

	# 左栏：任务
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 4)
	body.add_child(left_col)

	var task_title := Label.new()
	task_title.text = "任务"
	task_title.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	left_col.add_child(task_title)

	var task_scroll := ScrollContainer.new()
	task_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	task_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_child(task_scroll)

	task_list = VBoxContainer.new()
	task_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_list.add_theme_constant_override("separation", 4)
	task_scroll.add_child(task_list)

	# 右栏：传闻
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 8)
	body.add_child(right_col)

	# 可追查传闻
	var active_title := Label.new()
	active_title.text = "可追查传闻"
	active_title.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	right_col.add_child(active_title)

	var active_scroll := ScrollContainer.new()
	active_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_child(active_scroll)

	active_rumor_list = VBoxContainer.new()
	active_rumor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_rumor_list.add_theme_constant_override("separation", 4)
	active_scroll.add_child(active_rumor_list)

	# 已触发传闻
	var triggered_title := Label.new()
	triggered_title.text = "已触发传闻"
	triggered_title.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	right_col.add_child(triggered_title)

	var triggered_scroll := ScrollContainer.new()
	triggered_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	triggered_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_child(triggered_scroll)

	triggered_rumor_list = VBoxContainer.new()
	triggered_rumor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	triggered_rumor_list.add_theme_constant_override("separation", 4)
	triggered_scroll.add_child(triggered_rumor_list)

	# 底部消息
	message_label = Label.new()
	message_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_WARM)
	message_label.custom_minimum_size = Vector2(0, 28)
	content.add_child(message_label)

	hide()

func open(view_model: Dictionary) -> void:
	_refresh_tasks(view_model.get("tasks", []))
	_refresh_rumors(active_rumor_list, view_model.get("active_rumors", []), "暂无可追查传闻。")
	_refresh_rumors(triggered_rumor_list, view_model.get("triggered_rumors", []), "暂无已触发传闻。")
	show_message("")
	show()

func close() -> void:
	hide()
	closed.emit()

func show_message(text: String) -> void:
	message_label.text = text

func _refresh_tasks(tasks: Array) -> void:
	_clear_children(task_list)
	if tasks.is_empty():
		var empty := Label.new()
		empty.text = "暂无任务。"
		empty.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_DIM)
		task_list.add_child(empty)
		return
	for task in tasks:
		if typeof(task) != TYPE_DICTIONARY:
			continue
		_add_task_row(task)

func _add_task_row(task: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 44)
	row.add_theme_constant_override("separation", 8)
	task_list.add_child(row)

	var checkbox := CheckBox.new()
	checkbox.button_pressed = bool(task.get("tracked", false))
	var quest_id = str(task.get("id", ""))
	checkbox.pressed.connect(func(): quest_tracking_toggled.emit(quest_id))
	row.add_child(checkbox)

	var label := Label.new()
	label.text = "%s：%s" % [str(task.get("title", "未知任务")), str(task.get("status_text", ""))]
	label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_WARM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

func _refresh_rumors(container: VBoxContainer, rumors: Array, empty_text: String) -> void:
	_clear_children(container)
	if rumors.is_empty():
		var empty := Label.new()
		empty.text = empty_text
		empty.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_DIM)
		container.add_child(empty)
		return
	for rumor in rumors:
		if typeof(rumor) != TYPE_DICTIONARY:
			continue
		_add_rumor_row(container, rumor)

func _add_rumor_row(container: VBoxContainer, rumor: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	container.add_child(row)

	var title := Label.new()
	var source = str(rumor.get("source", ""))
	title.text = "%s%s" % [str(rumor.get("title", "未知传闻")), " · %s" % source if not source.is_empty() else ""]
	title.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	row.add_child(title)

	var text := Label.new()
	text.text = str(rumor.get("text", ""))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_WARM)
	row.add_child(text)

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
