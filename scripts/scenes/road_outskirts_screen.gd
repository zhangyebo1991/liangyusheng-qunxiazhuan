extends "res://scripts/scenes/map_screen_base.gd"

func _ready() -> void:
	configure_map("road_outskirts", Vector2(120, 360), Color("#6f7658"), Color("#4b4f3d"))
	super._ready()

func _create_terrain() -> void:
	_add_background(Vector2(1280, 720))
	_add_obstacle(Rect2(0, 0, 1280, 24))
	_add_obstacle(Rect2(0, 696, 1280, 24))
	_add_obstacle(Rect2(0, 0, 24, 720))
	_add_obstacle(Rect2(1256, 0, 24, 720))
	_add_obstacle(Rect2(360, 130, 160, 90))
	_add_obstacle(Rect2(760, 470, 180, 100))

func _interact_with(interactable) -> void:
	if interactable == null:
		return
	match str(interactable.record.get("type", "")):
		"pickup":
			_claim_pickup(interactable.record)
		"notice":
			_read_notice(interactable.record)
		"exit":
			_transition_to_exit(interactable.record)

func _read_notice(record: Dictionary) -> void:
	var dialogue_id = str(record.get("dialogue_id", ""))
	if dialogue_id.is_empty():
		_open_dialogue("", "官道向东延伸，路旁尘土新起。")
	else:
		_open_dialogue(dialogue_id, "官道向东延伸，路旁尘土新起。")

func _update_quest_text() -> void:
	hud.set_quest_text("村外官道：查看路边动静")
