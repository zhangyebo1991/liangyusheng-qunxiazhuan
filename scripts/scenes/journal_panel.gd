extends CanvasLayer

signal closed
signal quest_tracking_toggled(quest_id: String)

var panel: Panel
var title_label: Label
var task_list: VBoxContainer
var active_rumor_list: VBoxContainer
var triggered_rumor_list: VBoxContainer
var message_label: Label

func _ready() -> void:
	panel = Panel.new()
	panel.position = Vector2(120, 64)
	panel.size = Vector2(1040, 592)
	add_child(panel)

	title_label = Label.new()
	title_label.text = "江湖记事"
	title_label.position = Vector2(24, 16)
	title_label.size = Vector2(220, 32)
	panel.add_child(title_label)

	var close_button = Button.new()
	close_button.text = "关闭"
	close_button.position = Vector2(944, 14)
	close_button.size = Vector2(72, 36)
	close_button.pressed.connect(close)
	panel.add_child(close_button)

	var task_title = Label.new()
	task_title.text = "任务"
	task_title.position = Vector2(24, 64)
	task_title.size = Vector2(160, 28)
	panel.add_child(task_title)

	var task_scroll = ScrollContainer.new()
	task_scroll.position = Vector2(24, 96)
	task_scroll.size = Vector2(420, 420)
	panel.add_child(task_scroll)

	task_list = VBoxContainer.new()
	task_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_scroll.add_child(task_list)

	var active_title = Label.new()
	active_title.text = "可追查传闻"
	active_title.position = Vector2(480, 64)
	active_title.size = Vector2(220, 28)
	panel.add_child(active_title)

	var active_scroll = ScrollContainer.new()
	active_scroll.position = Vector2(480, 96)
	active_scroll.size = Vector2(520, 198)
	panel.add_child(active_scroll)

	active_rumor_list = VBoxContainer.new()
	active_rumor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_scroll.add_child(active_rumor_list)

	var triggered_title = Label.new()
	triggered_title.text = "已触发传闻"
	triggered_title.position = Vector2(480, 316)
	triggered_title.size = Vector2(220, 28)
	panel.add_child(triggered_title)

	var triggered_scroll = ScrollContainer.new()
	triggered_scroll.position = Vector2(480, 348)
	triggered_scroll.size = Vector2(520, 168)
	panel.add_child(triggered_scroll)

	triggered_rumor_list = VBoxContainer.new()
	triggered_rumor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	triggered_scroll.add_child(triggered_rumor_list)

	message_label = Label.new()
	message_label.position = Vector2(24, 536)
	message_label.size = Vector2(800, 32)
	panel.add_child(message_label)

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
		var empty = Label.new()
		empty.text = "暂无任务。"
		task_list.add_child(empty)
		return
	for task in tasks:
		if typeof(task) != TYPE_DICTIONARY:
			continue
		_add_task_row(task)

func _add_task_row(task: Dictionary) -> void:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(390, 44)
	task_list.add_child(row)

	var checkbox = CheckBox.new()
	checkbox.button_pressed = bool(task.get("tracked", false))
	var quest_id = str(task.get("id", ""))
	checkbox.pressed.connect(func(): quest_tracking_toggled.emit(quest_id))
	row.add_child(checkbox)

	var label = Label.new()
	label.text = "%s：%s" % [str(task.get("title", "未知任务")), str(task.get("status_text", ""))]
	label.custom_minimum_size = Vector2(320, 36)
	row.add_child(label)

func _refresh_rumors(container: VBoxContainer, rumors: Array, empty_text: String) -> void:
	_clear_children(container)
	if rumors.is_empty():
		var empty = Label.new()
		empty.text = empty_text
		container.add_child(empty)
		return
	for rumor in rumors:
		if typeof(rumor) != TYPE_DICTIONARY:
			continue
		_add_rumor_row(container, rumor)

func _add_rumor_row(container: VBoxContainer, rumor: Dictionary) -> void:
	var row = VBoxContainer.new()
	row.custom_minimum_size = Vector2(480, 92)
	container.add_child(row)

	var title = Label.new()
	var source = str(rumor.get("source", ""))
	title.text = "%s%s" % [str(rumor.get("title", "未知传闻")), " · %s" % source if not source.is_empty() else ""]
	title.custom_minimum_size = Vector2(480, 24)
	row.add_child(title)

	var text = Label.new()
	text.text = str(rumor.get("text", ""))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(480, 58)
	row.add_child(text)

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
