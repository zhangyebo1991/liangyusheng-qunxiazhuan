extends "res://scripts/scenes/map_screen_base.gd"

func _ready() -> void:
	configure_map("road_outskirts", Vector2(120, 360), Color("#6f7658"), Color("#4b4f3d"))
	super._ready()

func _create_terrain() -> void:
	super._create_terrain()

func _interact_with(interactable) -> void:
	if interactable == null:
		return
	match str(interactable.record.get("type", "")):
		"npc":
			_open_dialogue(str(interactable.record.get("dialogue_id", "")))
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
