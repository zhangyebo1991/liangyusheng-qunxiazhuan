extends Control

func _ready() -> void:
	var label = Label.new()
	label.text = "正在载入江湖..."
	label.position = Vector2(32, 32)
	add_child(label)

	if has_node("/root/DataRepository"):
		DataRepository.load_all()

	call_deferred("_go_to_main_menu")

func _go_to_main_menu() -> void:
	SceneLoader.change_scene("res://scenes/main_menu.tscn")
