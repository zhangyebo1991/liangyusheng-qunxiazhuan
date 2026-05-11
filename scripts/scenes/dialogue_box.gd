extends CanvasLayer

signal closed
signal option_selected(option: Dictionary)

var panel: Panel
var speaker_label: Label
var text_label: Label
var button: Button
var option_container: VBoxContainer
var lines: Array = []
var options: Array = []
var index := 0

func _ready() -> void:
	panel = Panel.new()
	panel.position = Vector2(120, 500)
	panel.size = Vector2(1040, 160)
	add_child(panel)

	speaker_label = Label.new()
	speaker_label.position = Vector2(24, 16)
	speaker_label.size = Vector2(240, 28)
	panel.add_child(speaker_label)

	text_label = Label.new()
	text_label.position = Vector2(24, 52)
	text_label.size = Vector2(880, 56)
	panel.add_child(text_label)

	button = Button.new()
	button.text = "继续"
	button.position = Vector2(900, 104)
	button.pressed.connect(_next_line)
	panel.add_child(button)

	option_container = VBoxContainer.new()
	option_container.position = Vector2(24, 104)
	option_container.size = Vector2(840, 48)
	panel.add_child(option_container)

	hide()

func open(next_lines: Array) -> void:
	open_dialogue_state({"lines": next_lines, "options": []})

func open_dialogue_state(dialogue_state: Dictionary) -> void:
	lines = dialogue_state.get("lines", [])
	options = dialogue_state.get("options", [])
	index = 0
	if lines.is_empty():
		lines = [{"speaker": "旁白", "text": "此人暂时无话可说。"}]
	if typeof(options) != TYPE_ARRAY:
		options = []
	_clear_options()
	_show_line()
	show()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("confirm"):
		if index >= lines.size() - 1 and not options.is_empty():
			return
		_next_line()

func _show_line() -> void:
	var line = lines[index]
	speaker_label.text = str(line.get("speaker", ""))
	text_label.text = str(line.get("text", ""))
	if index >= lines.size() - 1 and not options.is_empty():
		button.visible = false
		_show_options()
	else:
		button.visible = true
		_clear_options()

func _next_line() -> void:
	index += 1
	if index >= lines.size():
		hide()
		_clear_options()
		closed.emit()
		return
	_show_line()

func _show_options() -> void:
	_clear_options()
	for raw_option in options:
		if typeof(raw_option) != TYPE_DICTIONARY:
			continue
		var option = raw_option.duplicate(true)
		var option_button = Button.new()
		option_button.text = str(option.get("text", "选项"))
		option_button.disabled = not bool(option.get("available", true))
		option_button.tooltip_text = str(option.get("unavailable_reason", ""))
		option_button.custom_minimum_size = Vector2(360, 32)
		option_button.pressed.connect(func(): _select_option(option))
		option_container.add_child(option_button)

func _select_option(option: Dictionary) -> void:
	hide()
	_clear_options()
	option_selected.emit(option)

func _clear_options() -> void:
	if option_container == null:
		return
	for child in option_container.get_children():
		option_container.remove_child(child)
		child.queue_free()
