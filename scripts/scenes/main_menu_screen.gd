extends Control

const UiTheme = preload("res://scripts/core/ui_theme.gd")

var message_label: Label

func _ready() -> void:
	# 全屏容器
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 80)
	root.add_theme_constant_override("margin_top", 0)
	root.add_theme_constant_override("margin_right", 320)
	root.add_theme_constant_override("margin_bottom", 0)
	add_child(root)

	# 垂直布局：标题 + 按钮 + 消息
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	root.add_child(vbox)

	# 顶部间距
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# 标题
	var title := Label.new()
	title.text = "梁羽生群侠传"
	title.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	title.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE_LARGE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(title)

	# 间隔
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(gap)

	# 开始新游戏
	var start_button := Button.new()
	start_button.text = "开始新游戏"
	start_button.custom_minimum_size = Vector2(200, 44)
	UiTheme.apply_button_theme(start_button)
	start_button.pressed.connect(_start_new_game)
	vbox.add_child(start_button)

	# 继续游戏
	var continue_button := Button.new()
	continue_button.text = "继续游戏"
	continue_button.custom_minimum_size = Vector2(200, 44)
	UiTheme.apply_button_theme(continue_button)
	continue_button.pressed.connect(_continue_game)
	vbox.add_child(continue_button)

	# 消息
	message_label = Label.new()
	message_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_WARM)
	message_label.custom_minimum_size = Vector2(0, 32)
	vbox.add_child(message_label)

	# 底部间距
	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_bottom)

func _start_new_game() -> void:
	GameState.start_new_game()
	SceneLoader.change_scene("res://scenes/mountain_pass.tscn")

func _continue_game() -> void:
	if not GameState.load_from_path("user://save_01.json"):
		message_label.text = "没有可用存档。"
		return
	SceneLoader.change_scene(GameState.get_current_map_scene_path())
