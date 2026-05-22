extends CanvasLayer

const UiTheme = preload("res://scripts/core/ui_theme.gd")

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
	# 根 Control 使用 anchor 定位到底部
	var root := Control.new()
	root.name = "DialogueRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	panel = Panel.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = UiTheme.SIDE_MARGIN
	panel.offset_right = -UiTheme.SIDE_MARGIN
	panel.offset_top = -180
	panel.offset_bottom = -20
	panel.add_theme_stylebox_override("panel", UiTheme.make_gold_panel(6, 8))
	root.add_child(panel)

	# 内容 VBox
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	var content_margin := MarginContainer.new()
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left", 24)
	content_margin.add_theme_constant_override("margin_right", 24)
	content_margin.add_theme_constant_override("margin_top", 16)
	content_margin.add_theme_constant_override("margin_bottom", 12)
	content_margin.add_child(content)
	panel.add_child(content_margin)

	speaker_label = Label.new()
	speaker_label.custom_minimum_size = Vector2(120, 0)
	speaker_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	speaker_label.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE_NORMAL)
	content.add_child(speaker_label)

	text_label = Label.new()
	text_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_WARM)
	text_label.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE_NORMAL)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(0, 40)
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(text_label)

	# 底部行: 选项容器 + 继续按钮
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	content.add_child(bottom_row)

	option_container = VBoxContainer.new()
	option_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_container.add_theme_constant_override("separation", 4)
	bottom_row.add_child(option_container)

	button = Button.new()
	button.text = "继续"
	button.custom_minimum_size = Vector2(100, 36)
	UiTheme.apply_button_theme(button)
	button.pressed.connect(_next_line)
	bottom_row.add_child(button)

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
		var option_button := Button.new()
		option_button.text = str(option.get("text", "选项"))
		option_button.disabled = not bool(option.get("available", true))
		option_button.tooltip_text = str(option.get("unavailable_reason", ""))
		option_button.custom_minimum_size = Vector2(360, 32)
		UiTheme.apply_button_theme(option_button)
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
