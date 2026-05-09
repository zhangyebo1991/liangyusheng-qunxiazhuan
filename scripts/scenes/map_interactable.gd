extends Area2D

signal clicked(interactable)
signal player_entered(interactable)
signal player_exited(interactable)

var record: Dictionary = {}
var label: Label

func setup(next_record: Dictionary) -> void:
	record = next_record.duplicate(true)
	name = str(record.get("id", "MapInteractable"))
	global_position = _read_position(record.get("position", {}))

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = float(record.get("radius", 48.0))
	shape.shape = circle
	add_child(shape)

	var visual = ColorRect.new()
	visual.size = Vector2(24, 24)
	visual.position = Vector2(-12, -12)
	visual.color = _read_color()
	add_child(visual)

	label = Label.new()
	label.text = str(record.get("name", ""))
	label.position = Vector2(-32, -36)
	label.size = Vector2(96, 24)
	add_child(label)

	input_event.connect(_on_input_event)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func get_interaction_text() -> String:
	var display_name = str(record.get("name", "此处"))
	match str(record.get("type", "")):
		"npc":
			return "按 E 与%s交谈" % display_name
		"battle_trigger":
			return "按 E 挑战%s" % display_name
		"exit":
			return "按 E 前往%s" % display_name
		"notice":
			return "按 E 查看%s" % display_name
		_:
			return "按 E 与%s交互" % display_name

func _read_color() -> Color:
	match str(record.get("type", "")):
		"npc":
			return Color("#8d3b7a")
		"battle_trigger":
			return Color("#8f3b2f")
		"exit":
			return Color("#2f6fdd")
		"notice":
			return Color("#c49a2c")
		_:
			return Color("#666666")

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)

func _on_body_entered(body: Node) -> void:
	if body.has_method("set_current_interactable"):
		player_entered.emit(self)

func _on_body_exited(body: Node) -> void:
	if body.has_method("set_current_interactable"):
		player_exited.emit(self)

func _read_position(value: Variant) -> Vector2:
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO
