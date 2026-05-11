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
const EffectSystemScript = preload("res://scripts/systems/effect_system.gd")
const EventSystemScript = preload("res://scripts/systems/event_system.gd")
const JournalSystemScript = preload("res://scripts/systems/journal_system.gd")
const JournalPanelScript = preload("res://scripts/scenes/journal_panel.gd")

var player
var hud
var dialogue_box
var dialogue_system = DialogueSystemScript.new()
var spawner = MapObjectSpawnerScript.new()
var transition_system = MapTransitionSystemScript.new()
var inventory_system = InventorySystemScript.new()
var shop_system = ShopSystemScript.new()
var map_reward_system = MapRewardSystemScript.new()
var effect_system = EffectSystemScript.new()
var event_system = EventSystemScript.new()
var journal_system = JournalSystemScript.new()
var journal_panel
var journal_is_open := false
var active_dialogue_state: Dictionary = {}
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
	if event.is_action_pressed("journal"):
		if journal_is_open:
			_close_journal()
		else:
			_open_journal()
		return
	if journal_is_open:
		return
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
	hud.journal_requested.connect(_open_journal)
	add_child(hud)
	var data_repository = _get_data_repository()
	inventory_system.set_repository(data_repository)
	shop_system.set_repository(data_repository)
	map_reward_system.set_repository(data_repository)
	dialogue_box = DialogueBoxScript.new()
	if dialogue_box.has_signal("option_selected"):
		dialogue_box.option_selected.connect(_on_dialogue_option_selected)
	if dialogue_box.has_signal("closed"):
		dialogue_box.closed.connect(_on_dialogue_closed)
	add_child(dialogue_box)
	journal_panel = JournalPanelScript.new()
	journal_panel.quest_tracking_toggled.connect(_toggle_tracked_quest)
	journal_panel.closed.connect(_on_journal_closed)
	add_child(journal_panel)
	_refresh_tracked_tasks()

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
	var dialogue_state = dialogue_system.build_dialogue_state(dialogue_id, _get_game_state())
	if dialogue_state.get("lines", []).is_empty():
		dialogue_state["lines"] = [{"speaker": "旁白", "text": fallback_text}]
	active_dialogue_state = dialogue_state.duplicate(true)
	if dialogue_box != null:
		if dialogue_box.has_method("open_dialogue_state"):
			dialogue_box.open_dialogue_state(dialogue_state)
		else:
			dialogue_box.open(dialogue_state.get("lines", []))

func _on_dialogue_option_selected(option: Dictionary) -> void:
	if not bool(option.get("available", true)):
		hud.show_message(str(option.get("unavailable_reason", "条件尚未满足。")))
		return
	var event_data = {
		"conditions": option.get("conditions", []),
		"effects": option.get("effects", []),
	}
	var result = event_system.apply_event(_get_game_state(), event_data, {
		"source": "dialogue_option",
		"option_id": str(option.get("id", "")),
	})
	if not bool(result.get("success", false)):
		hud.show_message(_first_event_failure(result))
		return

	var effect_result = result.get("effect_result", {})
	_mark_triggered_rumors_from_effect_result(effect_result)
	var next_dialogue_id = str(option.get("next_dialogue_id", ""))
	if not next_dialogue_id.is_empty():
		_open_dialogue(next_dialogue_id)
	else:
		hud.show_message(_build_effect_message(effect_result, "已处理。"))
	_refresh_inventory_if_open()
	_refresh_shop_if_open()
	_update_quest_text()
	_refresh_tracked_tasks()

func _on_dialogue_closed() -> void:
	_record_dialogue_rumor(active_dialogue_state)
	active_dialogue_state = {}

func _record_dialogue_rumor(dialogue_state: Dictionary) -> void:
	var rumor = dialogue_state.get("rumor", {})
	if typeof(rumor) != TYPE_DICTIONARY or rumor.is_empty():
		return
	var game_state = _get_game_state()
	if game_state == null:
		return
	var result = journal_system.add_rumor(game_state.journal_state, rumor, {"map_id": map_id})
	if hud != null and bool(result.get("success", false)) and not bool(result.get("duplicate", false)):
		hud.show_message(str(result.get("message", "传闻已记入江湖记事。")))

func _open_journal() -> void:
	if journal_panel == null:
		return
	journal_is_open = true
	journal_panel.open(_build_journal_view_model())

func _close_journal() -> void:
	if journal_panel == null:
		return
	journal_is_open = false
	journal_panel.close()

func _on_journal_closed() -> void:
	journal_is_open = false

func _toggle_tracked_quest(quest_id: String) -> void:
	var game_state = _get_game_state()
	if game_state == null:
		return
	if _get_quest_status(quest_id) == "completed":
		game_state.journal_state.tracked_quest_ids.erase(quest_id)
		var message = "已完成任务不能追踪。"
		if journal_panel != null:
			journal_panel.open(_build_journal_view_model())
			journal_panel.show_message(message)
		if hud != null:
			hud.show_message(message)
		_refresh_tracked_tasks()
		return
	var result = journal_system.toggle_tracked_quest(game_state.journal_state, quest_id)
	if journal_panel != null:
		journal_panel.open(_build_journal_view_model())
		journal_panel.show_message(str(result.get("message", "")))
	if hud != null and not bool(result.get("success", false)):
		hud.show_message(str(result.get("message", "任务追踪失败。")))
	_refresh_tracked_tasks()

func _build_journal_view_model() -> Dictionary:
	var game_state = _get_game_state()
	var data_repository = _get_data_repository()
	if game_state == null:
		return {"tasks": [], "active_rumors": [], "triggered_rumors": []}
	journal_system.prune_completed_tracked_quests(game_state.journal_state, game_state)
	var rumors = journal_system.build_rumor_entries(game_state.journal_state)
	return {
		"tasks": journal_system.build_task_entries(game_state, data_repository),
		"active_rumors": rumors.get("active", []),
		"triggered_rumors": rumors.get("triggered", []),
	}

func _refresh_tracked_tasks() -> void:
	if hud == null:
		return
	var game_state = _get_game_state()
	var data_repository = _get_data_repository()
	if game_state == null:
		hud.set_tracked_tasks([])
		return
	journal_system.prune_completed_tracked_quests(game_state.journal_state, game_state)
	hud.set_tracked_tasks(journal_system.build_tracked_task_entries(game_state, data_repository))

func _mark_triggered_rumors_from_effect_result(effect_result: Dictionary) -> void:
	if not bool(effect_result.get("success", false)):
		return
	var game_state = _get_game_state()
	if game_state == null or game_state.journal_state == null:
		return
	for quest in effect_result.get("quests", []):
		if typeof(quest) != TYPE_DICTIONARY:
			continue
		var quest_id = str(quest.get("id", ""))
		var status = str(quest.get("status", ""))
		if quest_id.is_empty() or status == "not_started":
			continue
		journal_system.mark_rumors_triggered_for_quest(game_state.journal_state, quest_id)

func _first_event_failure(result: Dictionary) -> String:
	var messages = result.get("messages", [])
	if typeof(messages) == TYPE_ARRAY and not messages.is_empty():
		return str(messages[0])
	var errors = result.get("errors", [])
	if typeof(errors) == TYPE_ARRAY and not errors.is_empty():
		return str(errors[0])
	return "条件尚未满足。"

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
		_refresh_tracked_tasks()

func _apply_quest_complete_effects(quest_id: String) -> Dictionary:
	var game_state = _get_game_state()
	var data_repository = _get_data_repository()
	if game_state == null or data_repository == null or quest_id.is_empty():
		return {
			"success": false,
			"applied": 0,
			"failed": 1,
			"messages": [],
			"errors": ["任务效果无法执行。"],
			"items": [],
			"coins": 0,
			"flags": [],
			"quests": [],
			"resolved_objects": [],
			"martial_proficiency": [],
		}
	var quest = data_repository.get_quest(quest_id)
	var effects = _quest_complete_effects(quest_id, quest)
	var result = effect_system.apply_effects(game_state, effects, {"source": "quest_complete", "quest_id": quest_id})
	_mark_triggered_rumors_from_effect_result(result)
	_refresh_tracked_tasks()
	return result

func _quest_complete_effects(quest_id: String, quest: Dictionary) -> Array:
	var effects = quest.get("complete_effects", [])
	if typeof(effects) == TYPE_ARRAY and not effects.is_empty():
		return effects

	var result: Array = [
		{"type": "set_quest_status", "quest_id": quest_id, "status": "completed"}
	]
	var reward_items = quest.get("reward_items", [])
	if typeof(reward_items) == TYPE_ARRAY:
		var amounts = quest.get("reward_item_amounts", {})
		if typeof(amounts) != TYPE_DICTIONARY:
			amounts = {}
		for raw_item_id in reward_items:
			var item_id = str(raw_item_id)
			if item_id.is_empty():
				continue
			result.append({
				"type": "add_item",
				"item_id": item_id,
				"amount": max(1, int(amounts.get(item_id, 1))),
			})

	var reward_flags = quest.get("reward_flags", {})
	if typeof(reward_flags) == TYPE_DICTIONARY:
		for raw_key in reward_flags.keys():
			var key = str(raw_key)
			if key.is_empty():
				continue
			result.append({
				"type": "set_flag",
				"key": key,
				"value": reward_flags[raw_key],
			})
	return result

func _build_effect_message(result: Dictionary, fallback_message: String) -> String:
	var item_parts: Array[String] = []
	var data_repository = _get_data_repository()
	for item in result.get("items", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_id = str(item.get("id", ""))
		if item_id.is_empty():
			continue
		var item_data = data_repository.get_item(item_id) if data_repository != null else {}
		var name = str(item_data.get("name", item_id))
		var amount = int(item.get("amount", 1))
		if amount > 1:
			item_parts.append("%s x%d" % [name, amount])
		else:
			item_parts.append(name)
	var coins = int(result.get("coins", 0))
	if coins > 0:
		item_parts.append("%d 文" % coins)
	if item_parts.is_empty():
		return fallback_message
	return "获得：%s。" % "、".join(item_parts)

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

func _get_quest_status(quest_id: String) -> String:
	var game_state = _get_game_state()
	if game_state == null or game_state.quest_system == null:
		return "not_started"
	return str(game_state.quest_system.get_status(quest_id))

func _get_autoload(node_name: String):
	var loop = Engine.get_main_loop()
	if loop == null or loop.root == null:
		return null
	if loop.root.has_node(node_name):
		return loop.root.get_node(node_name)
	return null
