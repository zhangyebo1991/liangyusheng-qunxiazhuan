extends Control

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

func _start_new_game() -> void:
	GameState.start_new_game()
	SceneLoader.change_scene("res://scenes/world.tscn")
