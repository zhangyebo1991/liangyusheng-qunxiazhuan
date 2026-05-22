extends Control

const UiTheme = preload("res://scripts/core/ui_theme.gd")

func _ready() -> void:
	var label := Label.new()
	label.text = "正在载入江湖..."
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	label.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE_TITLE)
	add_child(label)

	if has_node("/root/DataRepository"):
		DataRepository.load_all()

	call_deferred("_go_to_main_menu")

func _go_to_main_menu() -> void:
	SceneLoader.change_scene("res://scenes/main_menu.tscn")
