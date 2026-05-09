extends Control

var message_label: Label

func _ready() -> void:
	var title = Label.new()
	title.text = "梁羽生群侠传"
	title.position = Vector2(64, 48)
	add_child(title)

	var start_button = Button.new()
	start_button.text = "开始新游戏"
	start_button.position = Vector2(64, 104)
	start_button.pressed.connect(_start_new_game)
	add_child(start_button)

	var continue_button = Button.new()
	continue_button.text = "继续游戏"
	continue_button.position = Vector2(64, 152)
	continue_button.pressed.connect(_continue_game)
	add_child(continue_button)

	message_label = Label.new()
	message_label.position = Vector2(64, 208)
	message_label.size = Vector2(600, 32)
	add_child(message_label)

func _start_new_game() -> void:
	GameState.start_new_game()
	SceneLoader.change_scene("res://scenes/mountain_pass.tscn")

func _continue_game() -> void:
	if not GameState.load_from_path("user://save_01.json"):
		message_label.text = "没有可用存档。"
		return
	SceneLoader.change_scene(GameState.get_current_map_scene_path())
