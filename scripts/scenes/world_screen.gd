extends Control

const DialogueSystemScript = preload("res://scripts/systems/dialogue_system.gd")

var dialogue_system = DialogueSystemScript.new()
var output: Label

func _ready() -> void:
	dialogue_system.set_repository(DataRepository)

	output = Label.new()
	output.text = "世界地图：山道"
	output.position = Vector2(32, 32)
	output.size = Vector2(900, 240)
	add_child(output)

	var dialogue_button = Button.new()
	dialogue_button.text = "请教青衫客"
	dialogue_button.position = Vector2(32, 300)
	dialogue_button.pressed.connect(_show_dialogue)
	add_child(dialogue_button)

	var battle_button = Button.new()
	battle_button.text = "进入战斗"
	battle_button.position = Vector2(180, 300)
	battle_button.pressed.connect(_start_battle)
	add_child(battle_button)

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
