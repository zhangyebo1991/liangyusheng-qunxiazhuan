extends CanvasLayer

var quest_label: Label
var prompt_label: Label
var message_label: Label

func _ready() -> void:
	quest_label = Label.new()
	quest_label.position = Vector2(24, 20)
	quest_label.size = Vector2(520, 32)
	add_child(quest_label)

	prompt_label = Label.new()
	prompt_label.position = Vector2(24, 640)
	prompt_label.size = Vector2(520, 32)
	add_child(prompt_label)

	message_label = Label.new()
	message_label.position = Vector2(24, 680)
	message_label.size = Vector2(800, 32)
	add_child(message_label)

	set_quest_text("")
	set_prompt("")
	show_message("")

func set_quest_text(text: String) -> void:
	quest_label.text = text

func set_prompt(text: String) -> void:
	prompt_label.text = text

func show_message(text: String) -> void:
	message_label.text = text
