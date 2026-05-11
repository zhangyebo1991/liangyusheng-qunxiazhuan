extends Node2D

const PlayerControllerScript = preload("res://scripts/scenes/player_controller.gd")
const MapInteractableScript = preload("res://scripts/scenes/map_interactable.gd")
const HudScript = preload("res://scripts/scenes/hud.gd")
const DialogueBoxScript = preload("res://scripts/scenes/dialogue_box.gd")
const DialogueSystemScript = preload("res://scripts/systems/dialogue_system.gd")
const MapObjectSpawnerScript = preload("res://scripts/systems/map_object_spawner.gd")
const MapTransitionSystemScript = preload("res://scripts/systems/map_transition_system.gd")
const InventorySystemScript = preload("res://scripts/systems/inventory_system.gd")
const ShopSystemScript = preload("res://scripts/systems/shop_system.gd")
const MapRewardSystemScript = preload("res://scripts/systems/map_reward_system.gd")

var player
var hud
var dialogue_box
var dialogue_system = DialogueSystemScript.new()
var spawner = MapObjectSpawnerScript.new()
var transition_system = MapTransitionSystemScript.new()
var inventory_system = InventorySystemScript.new()
var shop_system = ShopSystemScript.new()
var map_reward_system = MapRewardSystemScript.new()
var current_shop_record: Dictionary = {}
var map_data: Dictionary = {}
var interactables: Array = []
var map_id: String = ""
var fallback_spawn: Vector2 = Vector2(160, 320)
var background_color: Color = Color("#6f8f55")
var obstacle_color: Color = Color("#476f3f")

func configure_map(next_map_id: String, next_fallback_spawn: Vector2, next_background_color: Color, next_obstacle_color: Color) -> void:
	map_id = next_map_id
	fallback_spawn = next_fallback_spawn
	background_color = next_background_color
	obstacle_color = next_obstacle_color

func _ready() -> void:
	dialogue_system.set_repository(_get_data_repository())
	_load_map_data()
	_create_terrain()
	_create_player()
	_create_camera()
	_create_ui()
	_spawn_objects()
	_update_quest_text()

func _process(_delta: float) -> void:
	_update_nearest_interactable()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		_toggle_inventory()
	elif event.is_action_pressed("cancel"):
		var game_state = _get_game_state()
		var success = game_state != null and game_state.save_to_path("user://save_01.json")
		hud.show_message("存档成功。" if success else "存档失败。")

func _load_map_data() -> void:
	var data_repository = _get_data_repository()
	map_data = data_repository.get_map(map_id) if data_repository != null else {}
	if map_data.is_empty():
		push_error("无法读取地图配置：%s" % map_id)
		map_data = {
			"id": map_id,
			"spawn_position": {"x": fallback_spawn.x, "y": fallback_spawn.y},
			"objects": [],
		}

func _create_terrain() -> void:
	_add_background(Vector2(1280, 720))

func _add_background(size: Vector2) -> void:
	var terrain = TileMapLayer.new()
	terrain.name = "Terrain"
	add_child(terrain)

	var background = ColorRect.new()
	background.color = background_color
	background.size = size
	background.position = Vector2.ZERO
	add_child(background)
	move_child(background, 0)

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
	visual.color = obstacle_color
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
	hud.item_use_requested.connect(_on_item_use_requested)
	hud.shop_buy_requested.connect(_on_shop_buy_requested)
	add_child(hud)
	var data_repository = _get_data_repository()
	inventory_system.set_repository(data_repository)
	shop_system.set_repository(data_repository)
	map_reward_system.set_repository(data_repository)
	dialogue_box = DialogueBoxScript.new()
	add_child(dialogue_box)

func _spawn_objects() -> void:
	var game_state = _get_game_state()
	var resolved_objects = game_state.map_state.resolved_objects if game_state != null else []
	var records = spawner.get_spawn_records(map_data, resolved_objects, game_state)
	for record in records:
		var interactable = MapInteractableScript.new()
		interactable.setup(record)
		interactable.clicked.connect(_on_interactable_clicked)
		interactable.player_entered.connect(_on_interactable_entered)
		interactable.player_exited.connect(_on_interactable_exited)
		interactables.append(interactable)
		add_child(interactable)

func _update_nearest_interactable() -> void:
	if player == null or hud == null:
		return
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

func _interact_with(_interactable) -> void:
	pass

func _transition_to_exit(record: Dictionary) -> void:
	var target_map_id = str(record.get("target_map_id", ""))
	var data_repository = _get_data_repository()
	var target_map = data_repository.get_map(target_map_id) if data_repository != null else {}
	var game_state = _get_game_state()
	var result = transition_system.resolve_transition(record, target_map, game_state)
	if not bool(result.get("success", false)):
		hud.show_message(str(result.get("message", "前路尚未开放。")))
		return

	if game_state == null:
		hud.show_message("前路尚未开放。")
		return
	game_state.set_current_map(str(result.get("map_id", "")), result.get("position", fallback_spawn))
	var scene_loader = _get_scene_loader()
	if scene_loader != null:
		scene_loader.change_scene(game_state.get_current_map_scene_path())

func _open_dialogue(dialogue_id: String, fallback_text: String = "此人暂时无话可说。") -> void:
	var lines = dialogue_system.get_lines(dialogue_id)
	if lines.is_empty():
		lines = [{"speaker": "旁白", "text": fallback_text}]
	if dialogue_box != null:
		dialogue_box.open(lines)

func _open_shop(record: Dictionary) -> void:
	current_shop_record = record.duplicate(true)
	var game_state = _get_game_state()
	var coins = game_state.party.coins if game_state != null else 0
	var items = _build_shop_items(current_shop_record)
	hud.show_shop(str(current_shop_record.get("name", "药铺")), coins, items)
	if items.is_empty():
		hud.show_message("药铺暂时没有可买之物。")

func _claim_pickup(record: Dictionary) -> void:
	var result = map_reward_system.claim_pickup(_get_game_state(), record)
	hud.show_message(str(result.get("message", "这里什么也没有。")))
	if bool(result.get("success", false)):
		_remove_interactable_by_id(str(record.get("id", "")))
		_refresh_inventory_if_open()
		_refresh_shop_if_open()

func _remove_interactable_by_id(object_id: String) -> void:
	if object_id.is_empty():
		return
	for index in range(interactables.size() - 1, -1, -1):
		var interactable = interactables[index]
		if str(interactable.record.get("id", "")) != object_id:
			continue
		interactables.remove_at(index)
		if player != null and player.current_interactable == interactable:
			player.set_current_interactable(null)
		if interactable.get_parent() != null:
			interactable.get_parent().remove_child(interactable)
		interactable.queue_free()

func _build_shop_items(record: Dictionary) -> Array:
	var items: Array = []
	var raw_items = record.get("items", [])
	if typeof(raw_items) != TYPE_ARRAY:
		return items

	var data_repository = _get_data_repository()
	for raw_item_id in raw_items:
		var item_id = str(raw_item_id)
		if item_id.is_empty():
			continue
		var item_data = data_repository.get_item(item_id) if data_repository != null else {}
		if item_data.is_empty():
			items.append({
				"id": item_id,
				"name": "未知商品",
				"description": "此商品暂时不能购买。",
				"price": 0,
				"can_buy": false,
			})
			continue

		var price = int(item_data.get("value", 0))
		items.append({
			"id": item_id,
			"name": str(item_data.get("name", "未知商品")),
			"description": str(item_data.get("description", "")),
			"price": price,
			"can_buy": price > 0,
		})
	return items

func _toggle_inventory() -> void:
	hud.toggle_inventory(_build_inventory_items())

func _build_inventory_items() -> Array:
	var game_state = _get_game_state()
	if game_state == null:
		return []

	var data_repository = _get_data_repository()
	var items: Array = []
	for raw_item_id in game_state.party.inventory.keys():
		var item_id = str(raw_item_id)
		var quantity = game_state.party.get_item_count(item_id)
		if quantity <= 0:
			continue
		var item_data = data_repository.get_item(item_id) if data_repository != null else {}
		if item_data.is_empty():
			items.append({
				"id": item_id,
				"name": "未知物品",
				"type": "unknown",
				"description": "此物品资料缺失。",
				"quantity": quantity,
				"usable": false,
			})
		else:
			items.append({
				"id": item_id,
				"name": str(item_data.get("name", "未知物品")),
				"type": str(item_data.get("type", "unknown")),
				"description": str(item_data.get("description", "")),
				"quantity": quantity,
				"usable": str(item_data.get("type", "")) == "consumable",
			})
	return items

func _refresh_inventory_if_open() -> void:
	if hud.is_inventory_open():
		hud.refresh_inventory(_build_inventory_items())

func _refresh_shop_if_open() -> void:
	if hud.is_shop_open():
		var game_state = _get_game_state()
		var coins = game_state.party.coins if game_state != null else 0
		hud.refresh_shop(coins, _build_shop_items(current_shop_record))

func _on_item_use_requested(item_id: String) -> void:
	var result = inventory_system.use_item(_get_game_state(), item_id)
	hud.show_message(str(result.get("message", "此物暂时不能使用。")))
	_refresh_inventory_if_open()

func _on_shop_buy_requested(item_id: String) -> void:
	var result = shop_system.buy_item(_get_game_state(), item_id)
	hud.show_message(str(result.get("message", "此商品暂时不能购买。")))
	_refresh_shop_if_open()
	_refresh_inventory_if_open()

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
	var game_state = _get_game_state()
	if game_state != null:
		game_state.set_player_position(position)

func _update_quest_text() -> void:
	pass

func _read_spawn_position() -> Vector2:
	var game_state = _get_game_state()
	if game_state != null and game_state.map_state.current_map_id == map_id:
		return game_state.map_state.player_position
	return fallback_spawn

func _get_data_repository():
	return _get_autoload("DataRepository")

func _get_game_state():
	return _get_autoload("GameState")

func _get_scene_loader():
	return _get_autoload("SceneLoader")

func _get_autoload(node_name: String):
	var loop = Engine.get_main_loop()
	if loop == null or loop.root == null:
		return null
	if loop.root.has_node(node_name):
		return loop.root.get_node(node_name)
	return null
