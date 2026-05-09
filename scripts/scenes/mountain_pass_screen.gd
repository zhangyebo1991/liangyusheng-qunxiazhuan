extends Node2D

const PlayerControllerScript = preload("res://scripts/scenes/player_controller.gd")
const MapInteractableScript = preload("res://scripts/scenes/map_interactable.gd")
const HudScript = preload("res://scripts/scenes/hud.gd")
const DialogueBoxScript = preload("res://scripts/scenes/dialogue_box.gd")
const DialogueSystemScript = preload("res://scripts/systems/dialogue_system.gd")
const MapObjectSpawnerScript = preload("res://scripts/systems/map_object_spawner.gd")

var player
var hud
var dialogue_box
var dialogue_system = DialogueSystemScript.new()
var spawner = MapObjectSpawnerScript.new()
var map_data: Dictionary = {}
var interactables: Array = []

func _ready() -> void:
	dialogue_system.set_repository(DataRepository)
	map_data = DataRepository.get_map("mountain_pass")
	if map_data.is_empty():
		push_error("无法读取山道地图配置。")
		map_data = {"spawn_position": {"x": 160, "y": 320}, "objects": []}

	_create_terrain()
	_create_player()
	_create_camera()
	_create_ui()
	_spawn_objects()
	_update_quest_text()

func _process(_delta: float) -> void:
	_update_nearest_interactable()

func _create_terrain() -> void:
	var terrain = TileMapLayer.new()
	terrain.name = "Terrain"
	add_child(terrain)

	var background = ColorRect.new()
	background.color = Color("#6f8f55")
	background.size = Vector2(1280, 720)
	background.position = Vector2(0, 0)
	add_child(background)
	move_child(background, 0)

	_add_obstacle(Rect2(0, 0, 1280, 24))
	_add_obstacle(Rect2(0, 696, 1280, 24))
	_add_obstacle(Rect2(0, 0, 24, 720))
	_add_obstacle(Rect2(1256, 0, 24, 720))
	_add_obstacle(Rect2(520, 120, 120, 120))
	_add_obstacle(Rect2(900, 380, 160, 120))

func _add_obstacle(rect: Rect2) -> void:
	var body = StaticBody2D.new()
	body.position = rect.position
	var shape = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.size / 2.0
	body.add_child(shape)
	add_child(body)

	var visual = ColorRect.new()
	visual.color = Color("#476f3f")
	visual.position = rect.position
	visual.size = rect.size
	add_child(visual)

func _create_player() -> void:
	player = PlayerControllerScript.new()
	player.name = "Player"
	player.global_position = _read_spawn_position()
	player.position_changed.connect(_on_player_position_changed)
	player.interact_requested.connect(_interact_with)
	add_child(player)

func _create_camera() -> void:
	var camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	player.add_child(camera)
	camera.make_current()

func _create_ui() -> void:
	hud = HudScript.new()
	add_child(hud)
	dialogue_box = DialogueBoxScript.new()
	add_child(dialogue_box)

func _spawn_objects() -> void:
	var records = spawner.get_spawn_records(map_data, GameState.map_state.resolved_objects)
	for record in records:
		var interactable = MapInteractableScript.new()
		interactable.setup(record)
		interactable.clicked.connect(_on_interactable_clicked)
		interactable.player_entered.connect(_on_interactable_entered)
		interactable.player_exited.connect(_on_interactable_exited)
		interactables.append(interactable)
		add_child(interactable)

func _update_nearest_interactable() -> void:
	var nearest = null
	var best_distance := INF
	for interactable in interactables:
		var distance = player.global_position.distance_to(interactable.global_position)
		var radius = float(interactable.record.get("radius", 48.0))
		if distance <= radius and distance < best_distance:
			nearest = interactable
			best_distance = distance
	player.set_current_interactable(nearest)
	hud.set_prompt(nearest.get_interaction_text() if nearest != null else "")

func _interact_with(interactable) -> void:
	if interactable == null:
		return
	match str(interactable.record.get("type", "")):
		"npc":
			_talk_to_npc(interactable.record)
		"battle_trigger":
			_start_battle(interactable.record)

func _talk_to_npc(record: Dictionary) -> void:
	var quest_id = str(record.get("quest_id", ""))
	var status = GameState.quest_system.get_status(quest_id)
	if status == "not_started":
		GameState.quest_system.start_quest(quest_id)
		dialogue_box.open(dialogue_system.get_lines(str(record.get("dialogue_id", ""))))
		hud.show_message("任务开始：山道试剑")
	elif status == "ready_to_complete":
		GameState.quest_system.complete_quest(quest_id)
		GameState.party.add_item("herb_small", 1)
		GameState.map_state.mark_reward_claimed(quest_id)
		dialogue_box.open(dialogue_system.get_lines("mountain_pass_complete"))
		hud.show_message("获得：小还丹")
	else:
		dialogue_box.open(dialogue_system.get_lines(str(record.get("dialogue_id", ""))))
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

func _on_interactable_clicked(interactable) -> void:
	var radius = float(interactable.record.get("radius", 48.0))
	if player.global_position.distance_to(interactable.global_position) <= radius:
		_interact_with(interactable)
	else:
		hud.show_message("距离太远。")

func _on_interactable_entered(interactable) -> void:
	hud.set_prompt(interactable.get_interaction_text())

func _on_interactable_exited(_interactable) -> void:
	hud.set_prompt("")

func _on_player_position_changed(position: Vector2) -> void:
	GameState.set_player_position(position)

func _update_quest_text() -> void:
	var status = GameState.quest_system.get_status("quest_mountain_trial")
	if status == "active":
		hud.set_quest_text("山道试剑：击退前方强人")
	elif status == "ready_to_complete":
		hud.set_quest_text("山道试剑：回去向青衫客复命")
	elif status == "completed":
		hud.set_quest_text("山道试剑：已完成")
	else:
		hud.set_quest_text("")

func _read_spawn_position() -> Vector2:
	if GameState.map_state.current_map_id == "mountain_pass":
		return GameState.map_state.player_position
	var spawn = map_data.get("spawn_position", {})
	return Vector2(float(spawn.get("x", 160.0)), float(spawn.get("y", 320.0)))
