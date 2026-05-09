extends CanvasLayer

signal closed

var panel: Panel
var speaker_label: Label
var text_label: Label
var button: Button
var lines: Array = []
var index := 0

func _ready() -> void:
	panel = Panel.new()
	panel.position = Vector2(120, 500)
	panel.size = Vector2(1040, 160)
	add_child(panel)

	speaker_label = Label.new()
	speaker_label.position = Vector2(24, 16)
	speaker_label.size = Vector2(240, 28)
	panel.add_child(speaker_label)

	text_label = Label.new()
	text_label.position = Vector2(24, 52)
	text_label.size = Vector2(880, 56)
	panel.add_child(text_label)

	button = Button.new()
	button.text = "继续"
	button.position = Vector2(900, 104)
	button.pressed.connect(_next_line)
	panel.add_child(button)

	hide()

func open(next_lines: Array) -> void:
	lines = next_lines
	index = 0
	if lines.is_empty():
		lines = [{"speaker": "旁白", "text": "此人暂时无话可说。"}]
	_show_line()
	show()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("confirm"):
		_next_line()

func _show_line() -> void:
	var line = lines[index]
	speaker_label.text = str(line.get("speaker", ""))
	text_label.text = str(line.get("text", ""))

func _next_line() -> void:
	index += 1
	if index >= lines.size():
		hide()
		closed.emit()
		return
	_show_line()
