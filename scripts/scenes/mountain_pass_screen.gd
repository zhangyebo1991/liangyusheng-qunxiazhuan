extends "res://scripts/scenes/map_screen_base.gd"

func _ready() -> void:
	configure_map("mountain_pass", Vector2(160, 320), Color("#6f8f55"), Color("#476f3f"))
	super._ready()

func _create_terrain() -> void:
	_add_background(Vector2(1280, 720))
	_add_obstacle(Rect2(0, 0, 1280, 24))
	_add_obstacle(Rect2(0, 696, 1280, 24))
	_add_obstacle(Rect2(0, 0, 24, 720))
	_add_obstacle(Rect2(1256, 0, 24, 720))
	_add_obstacle(Rect2(520, 120, 120, 120))
	_add_obstacle(Rect2(900, 380, 160, 120))

func _interact_with(interactable) -> void:
	if interactable == null:
		return
	match str(interactable.record.get("type", "")):
		"npc":
			_talk_to_npc(interactable.record)
		"battle_trigger":
			_start_battle(interactable.record)
		"exit":
			_transition_to_exit(interactable.record)

func _talk_to_npc(record: Dictionary) -> void:
	var quest_id = str(record.get("quest_id", ""))
	var status = GameState.quest_system.get_status(quest_id)
	if status == "not_started":
		GameState.quest_system.start_quest(quest_id)
		_open_dialogue(str(record.get("dialogue_id", "")))
		hud.show_message("任务开始：山道试剑")
	elif status == "ready_to_complete":
		GameState.quest_system.complete_quest(quest_id)
		if not GameState.map_state.is_reward_claimed(quest_id):
			GameState.party.add_item("herb_small", 1)
			GameState.map_state.mark_reward_claimed(quest_id)
			hud.show_message("获得：小还丹")
		_open_dialogue("mountain_pass_complete")
	else:
		_open_dialogue(str(record.get("dialogue_id", "")))
	_update_quest_text()

func _start_battle(record: Dictionary) -> void:
	var quest_id = str(record.get("quest_id", ""))
	if GameState.quest_system.get_status(quest_id) == "not_started":
		hud.show_message("先与青衫客交谈。")
		return
	GameState.set_battle_context({
		"enemy_id": str(record.get("actor_id", "")),
		"source_map_id": "mountain_pass",
		"source_object_id": str(record.get("id", "")),
		"quest_id": quest_id,
		"return_position": {
			"x": player.global_position.x,
			"y": player.global_position.y,
		},
	})
	SceneLoader.change_scene("res://scenes/battle.tscn")

func _update_quest_text() -> void:
	var mountain_status = GameState.quest_system.get_status("quest_mountain_trial")
	if mountain_status == "active":
		hud.set_quest_text("山道试剑：击退前方强人")
		return
	if mountain_status == "ready_to_complete":
		hud.set_quest_text("山道试剑：回去向青衫客复命")
		return
	if mountain_status == "completed":
		var delivery_status = GameState.quest_system.get_status("quest_deliver_letter")
		if delivery_status == "active":
			hud.set_quest_text("送信到客栈：将书信交给客栈掌柜")
		elif delivery_status == "ready_to_complete":
			hud.set_quest_text("送信到客栈：与掌柜确认回信")
		elif delivery_status == "completed":
			hud.set_quest_text("送信到客栈：已完成")
		else:
			hud.set_quest_text("山道试剑：已完成")
		return
	hud.set_quest_text("")
