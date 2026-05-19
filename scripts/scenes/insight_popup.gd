extends PanelContainer

signal popup_dismissed

var message_label: Label
var unlock_label: Label
var dismiss_button: Button
var auto_hide_timer: Timer

func _init() -> void:
	custom_minimum_size = Vector2(400, 200)
	visible = false
	anchors_preset = Control.PRESET_CENTER

func _ready() -> void:
	_build_ui()

	auto_hide_timer = Timer.new()
	auto_hide_timer.wait_time = 5.0
	auto_hide_timer.one_shot = true
	auto_hide_timer.timeout.connect(_on_auto_hide)
	add_child(auto_hide_timer)

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

	var title = Label.new()
	title.text = "领悟成功！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var separator = HSeparator.new()
	vbox.add_child(separator)

	message_label = Label.new()
	message_label.text = ""
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(message_label)

	unlock_label = Label.new()
	unlock_label.text = ""
	unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlock_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(unlock_label)

	dismiss_button = Button.new()
	dismiss_button.text = "确定"
	dismiss_button.custom_minimum_size = Vector2(120, 40)
	dismiss_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dismiss_button.pressed.connect(_on_dismiss_pressed)
	vbox.add_child(dismiss_button)

func show_insight(message: String, unlock_name: String = "") -> void:
	message_label.text = message

	if unlock_name.is_empty():
		unlock_label.text = ""
		unlock_label.visible = false
	else:
		unlock_label.text = "解锁：" + unlock_name
		unlock_label.visible = true

	visible = true
	auto_hide_timer.start()

func _on_dismiss_pressed() -> void:
	hide()
	popup_dismissed.emit()

func _on_auto_hide() -> void:
	hide()
	popup_dismissed.emit()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		if event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			_on_dismiss_pressed()
			get_viewport().set_input_as_handled()
