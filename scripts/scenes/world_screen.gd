extends Control

const UiTheme = preload("res://scripts/core/ui_theme.gd")
const DialogueSystemScript = preload("res://scripts/systems/dialogue_system.gd")

var dialogue_system = DialogueSystemScript.new()
var output: Label

func _ready() -> void:
	dialogue_system.set_repository(DataRepository)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	root.add_theme_constant_override("margin_left", 32)
	root.add_theme_constant_override("margin_top", 32)
	root.add_theme_constant_override("margin_right", 32)
	root.add_theme_constant_override("margin_bottom", 32)
	add_child(root)

	output = Label.new()
	output.text = "世界地图：山道"
	output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	output.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_WARM)
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(output)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	root.add_child(button_row)

	var dialogue_button := Button.new()
	dialogue_button.text = "请教青衫客"
	dialogue_button.custom_minimum_size = Vector2(120, 40)
	UiTheme.apply_button_theme(dialogue_button)
	dialogue_button.pressed.connect(_show_dialogue)
	button_row.add_child(dialogue_button)

	var battle_button := Button.new()
	battle_button.text = "进入战斗"
	battle_button.custom_minimum_size = Vector2(120, 40)
	UiTheme.apply_button_theme(battle_button)
	battle_button.pressed.connect(_start_battle)
	button_row.add_child(battle_button)

func _show_dialogue() -> void:
	var lines = dialogue_system.get_lines("intro_meet_master")
	var text_lines: Array[String] = ["世界地图：山道"]
	for line in lines:
		text_lines.append("%s：%s" % [line.get("speaker", ""), line.get("text", "")])
	GameState.quest_system.start_quest("quest_first_step")
	output.text = "\n".join(PackedStringArray(text_lines))

func _start_battle() -> void:
	EventBus.battle_started.emit("bandit_01")
	SceneLoader.change_scene("res://scenes/battle.tscn")
