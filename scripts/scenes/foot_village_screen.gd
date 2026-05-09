extends "res://scripts/scenes/map_screen_base.gd"

func _ready() -> void:
	configure_map("foot_village", Vector2(120, 360), Color("#7f8f6a"), Color("#5f6246"))
	super._ready()

func _create_terrain() -> void:
	_add_background(Vector2(1280, 720))
	_add_obstacle(Rect2(0, 0, 1280, 24))
	_add_obstacle(Rect2(0, 696, 1280, 24))
	_add_obstacle(Rect2(0, 0, 24, 720))
	_add_obstacle(Rect2(1256, 0, 24, 720))
	_add_obstacle(Rect2(420, 120, 180, 110))
	_add_obstacle(Rect2(690, 110, 240, 130))
	_add_obstacle(Rect2(360, 500, 180, 100))
	_add_obstacle(Rect2(820, 500, 220, 100))

func _interact_with(interactable) -> void:
	if interactable == null:
		return
	match str(interactable.record.get("type", "")):
		"npc":
			_talk_to_npc(interactable.record)
		"notice":
			_read_notice(interactable.record)
		"exit":
			_transition_to_exit(interactable.record)
		"shop":
			_open_shop(interactable.record)

func _talk_to_npc(record: Dictionary) -> void:
	match str(record.get("actor_id", "")):
		"porter_chen":
			_talk_to_porter(record)
		"innkeeper_lu":
			_talk_to_innkeeper(record)
		_:
			_open_dialogue(str(record.get("dialogue_id", "")))

func _talk_to_porter(_record: Dictionary) -> void:
	var status = GameState.quest_system.get_status("quest_deliver_letter")
	if status == "not_started":
		GameState.quest_system.start_quest("quest_deliver_letter")
		_open_dialogue("foot_village_porter_intro")
		hud.show_message("任务开始：送信到客栈")
	elif status == "completed":
		_open_dialogue("foot_village_porter_after")
	else:
		_open_dialogue("foot_village_porter_reminder")
	_update_quest_text()

func _talk_to_innkeeper(_record: Dictionary) -> void:
	var status = GameState.quest_system.get_status("quest_deliver_letter")
	if status == "not_started":
		_open_dialogue("foot_village_innkeeper_idle")
		return
	if status == "active":
		GameState.quest_system.mark_ready_to_complete("quest_deliver_letter")
		GameState.quest_system.complete_quest("quest_deliver_letter")
		GameState.set_flag("clue_foot_village", "掌柜提到飞红巾踪迹")
		GameState.map_state.mark_reward_claimed("quest_deliver_letter")
		_open_dialogue("deliver_letter_complete")
		hud.show_message("获得线索：飞红巾踪迹")
	elif status == "ready_to_complete":
		GameState.quest_system.complete_quest("quest_deliver_letter")
		GameState.set_flag("clue_foot_village", "掌柜提到飞红巾踪迹")
		GameState.map_state.mark_reward_claimed("quest_deliver_letter")
		_open_dialogue("deliver_letter_complete")
		hud.show_message("获得线索：飞红巾踪迹")
	else:
		_open_dialogue("deliver_letter_after")
	_update_quest_text()

func _read_notice(record: Dictionary) -> void:
	_open_dialogue(str(record.get("dialogue_id", "")), "告示字迹模糊，暂时看不清。")

func _update_quest_text() -> void:
	var status = GameState.quest_system.get_status("quest_deliver_letter")
	if status == "active":
		hud.set_quest_text("送信到客栈：将书信交给客栈掌柜")
	elif status == "ready_to_complete":
		hud.set_quest_text("送信到客栈：与掌柜确认回信")
	elif status == "completed":
		hud.set_quest_text("送信到客栈：已完成")
	else:
		hud.set_quest_text("")
