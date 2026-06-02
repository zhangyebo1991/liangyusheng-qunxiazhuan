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
const SpriteGeneratorScript = preload("res://scripts/systems/sprite_generator.gd")

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
var debug_visible := false
var _map_size := Vector2(1280, 720)
var world_layer: Node2D
var overlay_layer: Node2D
var particle_layer: Node2D
var world_map_ui = null

func configure_map(next_map_id: String, next_fallback_spawn: Vector2, next_background_color: Color, next_obstacle_color: Color) -> void:
	map_id = next_map_id
	fallback_spawn = next_fallback_spawn
	background_color = next_background_color
	obstacle_color = next_obstacle_color

func _ready() -> void:
	dialogue_system.set_repository(_get_data_repository())
	_load_map_data()
	_create_terrain()
	_create_layers()
	_create_player()
	_create_camera()
	_spawn_decorations()
	_create_ui()
	_spawn_objects()
	_update_quest_text()

func _process(_delta: float) -> void:
	_update_nearest_interactable()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		_toggle_world_map()
		return
	if event.is_action_pressed("cancel"):
		if world_map_ui != null:
			_close_world_map()
			return
		if journal_is_open:
			_close_journal()
			return
		return
	if event.is_action_pressed("save"):
		var game_state = _get_game_state()
		var success = game_state != null and game_state.save_to_path("user://save_01.json")
		hud.show_message("存档成功。" if success else "存档失败。")
		return
	if event.is_action_pressed("journal"):
		if journal_is_open:
			_close_journal()
		else:
			_open_journal()
		return
	if journal_is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_toggle_party_panel()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		debug_visible = not debug_visible
		var bus = _get_autoload("EventBus")
		if bus != null:
			bus.debug_toggled.emit(debug_visible)
		_update_debug_display()
		return
	if event.is_action_pressed("inventory"):
		_toggle_inventory()

func _toggle_world_map() -> void:
	if world_map_ui == null:
		var WorldMapUIScript = load("res://scripts/scenes/world_map_ui_screen.gd")
		world_map_ui = WorldMapUIScript.new()
		world_map_ui.setup(player)
		world_map_ui.close_requested.connect(_close_world_map)
		add_child(world_map_ui)
	else:
		_close_world_map()

func _close_world_map() -> void:
	if world_map_ui != null:
		world_map_ui.queue_free()
		world_map_ui = null

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
	var layout = _get_layout_data()
	var mode = str(layout.get("mode", ""))
	match mode:
		"big_image":
			_create_image_background(layout)
		"tile_map":
			_create_tile_map_background(layout)
		_:
			_create_color_background(layout)

func _create_color_background(layout: Dictionary) -> void:
	var size = _read_size(layout.get("size", {}), Vector2(1280, 720))
	_apply_map_bounds(size)
	_add_background(size)
	for obstacle in layout.get("obstacles", []):
		if typeof(obstacle) != TYPE_DICTIONARY:
			continue
		_add_obstacle(obstacle)

func _create_image_background(layout: Dictionary) -> void:
	var bg = layout.get("background", {})
	var image_path = str(bg.get("path", ""))
	if image_path.is_empty():
		push_error("大图底图模式缺少 background.path")
		_create_color_background(layout)
		return

	var texture: Texture2D = null
	if ResourceLoader.exists(image_path, "Texture2D"):
		texture = load(image_path)
	else:
		var image = Image.load_from_file(ProjectSettings.globalize_path(image_path))
		if image != null:
			image.convert(Image.FORMAT_RGBA8)
			texture = ImageTexture.create_from_image(image)

	if texture == null:
		push_warning("无法加载底图: %s，回退到纯色背景" % image_path)
		_create_color_background(layout)
		return

	var sprite = Sprite2D.new()
	sprite.name = "Background"
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.z_index = -100
	add_child(sprite)

	# 若 size 未指定，从 texture 推导
	var size = _read_size(layout.get("size", {}), Vector2.ZERO)
	if size == Vector2.ZERO:
		size = Vector2(float(texture.get_width()), float(texture.get_height()))
	if size != Vector2.ZERO:
		_apply_map_bounds(size)

	# 创建底图下的纯色填充（防止透明区域露底）
	var fill = ColorRect.new()
	fill.name = "BackgroundFill"
	fill.color = background_color
	fill.size = size
	fill.position = Vector2.ZERO
	add_child(fill)
	move_child(fill, 0)

func _create_tile_map_background(layout: Dictionary) -> void:
	var tileset_config_path = str(layout.get("tileset", {}).get("config", "res://data/tilesets/kenney_tiny_battle.json"))
	var tileset_config := _load_tileset_config(tileset_config_path)
	if tileset_config.is_empty():
		_create_color_background(layout)
		return

	var tile_size := Vector2i(
		int(tileset_config.get("tile_size", {}).get("x", 128)),
		int(tileset_config.get("tile_size", {}).get("y", 128))
	)
	var terrain_map: Dictionary = tileset_config.get("terrain_map", {})

	var layers: Dictionary = layout.get("layers", {})

	# ground / decoration / overlay 按顺序创建
	var layer_order := ["ground", "decoration", "overlay"]
	var terrain_layer_index := 0

	for layer_name in layer_order:
		var grid: Array = layers.get(layer_name, [])
		if grid.is_empty():
			continue

		var tile_map_layer := TileMapLayer.new()
		tile_map_layer.name = layer_name.capitalize()
		tile_map_layer.tile_set = _build_tileset(tileset_config_path, tile_size, terrain_map)
		tile_map_layer.z_index = terrain_layer_index
		terrain_layer_index += 1
		add_child(tile_map_layer)

		for row_idx in range(grid.size()):
			var row = grid[row_idx]
			if typeof(row) != TYPE_ARRAY:
				continue
			for col_idx in range(row.size()):
				var terrain_id = str(row[col_idx])
				if terrain_id.is_empty() or terrain_id == "null":
					continue
				var terrain = terrain_map.get(terrain_id, {})
				if terrain.is_empty():
					continue
				var tile_index := int(terrain.get("tile_index", 0))
				var columns := int(tileset_config.get("columns", 16))
				var tile_coord := Vector2i(tile_index % columns, tile_index / columns)
				tile_map_layer.set_cell(Vector2i(col_idx, row_idx), 0, tile_coord)

		# 非 ground 层 z_index 提升
		if layer_name == "decoration":
			tile_map_layer.z_index = 10
		elif layer_name == "overlay":
			tile_map_layer.z_index = 60

	var size := _read_size(layout.get("size", {}), Vector2(2560, 1920))
	_apply_map_bounds(size)


func _load_tileset_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("tileset 配置不存在: %s" % path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _build_tileset(config_path: String, tile_size: Vector2i, terrain_map: Dictionary) -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = tile_size

	var image_path = str(_load_tileset_config(config_path).get("path", ""))
	if image_path.is_empty():
		return tileset

	var texture: Texture2D = null
	if ResourceLoader.exists(image_path, "Texture2D"):
		texture = load(image_path)
	if texture == null:
		return tileset

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = tile_size
	var source_id := tileset.add_source(source)

	# 为每个 terrain 注册 tile
	for terrain_id in terrain_map:
		var terrain = terrain_map[terrain_id]
		var tile_index := int(terrain.get("tile_index", -1))
		if tile_index < 0:
			continue
		var columns := int(texture.get_width() / tile_size.x)
		var atlas_coords := Vector2i(tile_index % columns, tile_index / columns)
		source.create_tile(atlas_coords)

	return tileset

func _apply_map_bounds(size: Vector2) -> void:
	_map_size = size

func _add_background(size: Vector2) -> void:
	var terrain = TileMapLayer.new()
	terrain.name = "Terrain"
	add_child(terrain)

	var background = ColorRect.new()
	background.name = "Background"
	background.color = _read_background_color(_get_layout_data().get("background", {}))
	background.size = size
	background.position = Vector2.ZERO
	add_child(background)
	move_child(background, 0)

func _add_obstacle(obstacle: Dictionary) -> void:
	var body = StaticBody2D.new()
	body.name = str(obstacle.get("id", "Obstacle"))
	var shape_type = str(obstacle.get("shape", "rect"))

	match shape_type:
		"polygon":
			var points = obstacle.get("points", [])
			if typeof(points) != TYPE_ARRAY or points.size() < 3:
				push_warning("多边形碰撞缺少顶点: %s" % str(obstacle.get("id", "")))
				return
			var polygon = CollisionPolygon2D.new()
			var vertex_array := PackedVector2Array()
			for point in points:
				if typeof(point) == TYPE_DICTIONARY:
					vertex_array.append(Vector2(float(point.get("x", 0.0)), float(point.get("y", 0.0))))
			polygon.polygon = vertex_array
			body.add_child(polygon)
		_:
			var rect = _read_rect(obstacle.get("rect", {}))
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				return
			body.position = rect.position
			var shape = CollisionShape2D.new()
			var rectangle = RectangleShape2D.new()
			rectangle.size = rect.size
			shape.shape = rectangle
			shape.position = rect.size / 2.0
			body.add_child(shape)

	add_child(body)

	# Visual for the obstacle
	var visual = ColorRect.new()
	visual.name = "ObstacleVisual"
	visual.color = obstacle_color
	if shape_type == "polygon":
		# For polygons, place the visual at the first vertex with a rough size
		var first = Vector2(float(obstacle.get("points", [{}])[0].get("x", 0)), float(obstacle.get("points", [{}])[0].get("y", 0)))
		visual.position = first
		visual.size = Vector2(48, 48)  # rough default for polygon visual
	else:
		var rect = _read_rect(obstacle.get("rect", {}))
		visual.position = rect.position
		visual.size = rect.size
	add_child(visual)

func _get_layout_data() -> Dictionary:
	var layout = map_data.get("layout", {})
	if typeof(layout) == TYPE_DICTIONARY:
		return layout
	return {}

func _read_size(value: Variant, fallback: Vector2) -> Vector2:
	if typeof(value) != TYPE_DICTIONARY:
		return fallback
	var width = float(value.get("x", fallback.x))
	var height = float(value.get("y", fallback.y))
	if width <= 0.0 or height <= 0.0:
		return fallback
	return Vector2(width, height)

func _read_rect(value: Variant) -> Rect2:
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	return Rect2(
		float(value.get("x", 0.0)),
		float(value.get("y", 0.0)),
		float(value.get("w", 0.0)),
		float(value.get("h", 0.0))
	)

func _read_background_color(value: Variant) -> Color:
	if typeof(value) != TYPE_DICTIONARY:
		return background_color
	if str(value.get("mode", "color")) != "color":
		return background_color
	var html = str(value.get("color", ""))
	if html.is_empty() or not Color.html_is_valid(html):
		return background_color
	return Color(html)

func _create_layers() -> void:
	# WorldLayer — 核心遮挡排序层
	world_layer = Node2D.new()
	world_layer.name = "WorldLayer"
	world_layer.y_sort_enabled = true
	add_child(world_layer)

	# OverlayLayer — 始终在角色上方
	overlay_layer = Node2D.new()
	overlay_layer.name = "OverlayLayer"
	overlay_layer.z_index = 50
	add_child(overlay_layer)

	# ParticleLayer — 粒子氛围
	particle_layer = Node2D.new()
	particle_layer.name = "ParticleLayer"
	particle_layer.z_index = 25
	add_child(particle_layer)

func _create_player() -> void:
	player = PlayerControllerScript.new()
	player.name = "Player"
	player.global_position = _read_spawn_position()
	player.position_changed.connect(_on_player_position_changed)
	player.interact_requested.connect(_interact_with)
	world_layer.add_child(player)

func _create_camera() -> void:
	var camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	player.add_child(camera)
	camera.make_current()

	# 读取 camera 配置
	var layout = _get_layout_data()
	var camera_config = layout.get("camera", {})
	if typeof(camera_config) == TYPE_DICTIONARY:
		var zoom_value = float(camera_config.get("zoom", 1.0))
		if zoom_value > 0.0:
			camera.zoom = Vector2(zoom_value, zoom_value)

		var bounds = camera_config.get("bounds", {})
		if typeof(bounds) == TYPE_DICTIONARY:
			camera.limit_left = int(bounds.get("x", -10000000))
			camera.limit_top = int(bounds.get("y", -10000000))
			camera.limit_right = int(bounds.get("x", 0)) + int(bounds.get("w", 10000000))
			camera.limit_bottom = int(bounds.get("y", 0)) + int(bounds.get("h", 10000000))
		elif _map_size != Vector2.ZERO:
			# 无显式 bounds 时用 map size
			camera.limit_left = 0
			camera.limit_top = 0
			camera.limit_right = int(_map_size.x)
			camera.limit_bottom = int(_map_size.y)

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
		world_layer.add_child(interactable)


func _spawn_decorations() -> void:
	var layout = _get_layout_data()
	var decorations = layout.get("decorations", [])
	if typeof(decorations) != TYPE_ARRAY:
		return

	for deco in decorations:
		if typeof(deco) != TYPE_DICTIONARY:
			continue
		var deco_type = str(deco.get("type", ""))
		var position = Vector2(
			float(deco.get("position", {}).get("x", 0.0)),
			float(deco.get("position", {}).get("y", 0.0))
		)
		var has_overlay = bool(deco.get("has_overlay", false))
		var has_collision = bool(deco.get("has_collision", false))

		if has_overlay and deco_type in ["tree", "building"]:
			# 拆分：下半进 WorldLayer，上半进 OverlayLayer
			_spawn_split_decoration(deco_type, position, has_collision)
		else:
			var sprite = Sprite2D.new()
			sprite.texture = SpriteGeneratorScript.generate_decoration_texture(deco_type)
			sprite.position = position
			if has_overlay:
				overlay_layer.add_child(sprite)
			else:
				world_layer.add_child(sprite)

			if has_collision:
				var body = StaticBody2D.new()
				body.position = position
				var shape = CollisionShape2D.new()
				var rect = RectangleShape2D.new()
				rect.size = Vector2(32, 16)
				shape.shape = rect
				body.add_child(shape)
				add_child(body)


func _spawn_split_decoration(deco_type: String, position: Vector2, has_collision: bool) -> void:
	var full_texture = SpriteGeneratorScript.generate_decoration_texture(deco_type)
	var tex_height := float(full_texture.get_height())
	var split_y := tex_height * 0.5

	# 下半 — WorldLayer
	var lower = Sprite2D.new()
	lower.texture = full_texture
	lower.position = position
	lower.region_enabled = true
	lower.region_rect = Rect2(0, split_y, full_texture.get_width(), tex_height - split_y)
	lower.offset = Vector2(0, -split_y)
	world_layer.add_child(lower)

	# 上半 — OverlayLayer
	var upper = Sprite2D.new()
	upper.texture = full_texture
	upper.position = position
	upper.region_enabled = true
	upper.region_rect = Rect2(0, 0, full_texture.get_width(), split_y)
	overlay_layer.add_child(upper)

	if has_collision:
		var body = StaticBody2D.new()
		body.position = position + Vector2(0, tex_height * 0.5)
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(full_texture.get_width() * 0.5, tex_height * 0.3)
		shape.shape = rect
		shape.position = Vector2(0, tex_height * 0.15)
		body.add_child(shape)
		add_child(body)

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
	var battle_context = option.get("battle_context", {})
	if typeof(battle_context) == TYPE_DICTIONARY and not battle_context.is_empty():
		_start_dialogue_battle(battle_context)
		return
	var next_dialogue_id = str(option.get("next_dialogue_id", ""))
	if not next_dialogue_id.is_empty():
		_open_dialogue(next_dialogue_id)
	else:
		hud.show_message(_build_effect_message(effect_result, "已处理。"))
	_refresh_inventory_if_open()
	_refresh_shop_if_open()
	_refresh_party_panel_if_open()
	_update_quest_text()
	_refresh_tracked_tasks()

func _start_dialogue_battle(raw_context: Dictionary) -> void:
	var game_state = _get_game_state()
	var scene_loader = _get_scene_loader()
	if game_state == null or scene_loader == null:
		return
	var context = raw_context.duplicate(true)
	if str(context.get("source_map_id", "")).is_empty():
		context["source_map_id"] = map_id
	context["return_position"] = {
		"x": player.global_position.x,
		"y": player.global_position.y,
	}
	game_state.set_battle_context(context)
	scene_loader.change_scene("res://scenes/battle.tscn")

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
		_refresh_party_panel_if_open()
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
	_refresh_party_panel_if_open()
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
		var name = str(item_data.get("name", "未知物品"))
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

func _toggle_party_panel() -> void:
	var game_state = _get_game_state()
	if game_state == null:
		return
	hud.toggle_party_panel(game_state.party, _get_data_repository())

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

func _refresh_party_panel_if_open() -> void:
	if hud.is_party_panel_open():
		var game_state = _get_game_state()
		if game_state != null:
			hud.show_party_panel(game_state.party, _get_data_repository())

func _refresh_shop_if_open() -> void:
	if hud.is_shop_open():
		var game_state = _get_game_state()
		var coins = game_state.party.coins if game_state != null else 0
		hud.refresh_shop(coins, _build_shop_items(current_shop_record))

func _on_item_use_requested(item_id: String) -> void:
	var result = inventory_system.use_item(_get_game_state(), item_id)
	hud.show_message(str(result.get("message", "此物暂时不能使用。")))
	_refresh_inventory_if_open()
	_refresh_party_panel_if_open()

func _on_shop_buy_requested(item_id: String) -> void:
	var result = shop_system.buy_item(_get_game_state(), item_id)
	hud.show_message(str(result.get("message", "此商品暂时不能购买。")))
	_refresh_shop_if_open()
	_refresh_inventory_if_open()
	_refresh_party_panel_if_open()

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

func _update_debug_display() -> void:
	# Simple toggle: change obstacle visual alpha to show/hide collision zones
	for child in get_children():
		if child is ColorRect and child.name == "ObstacleVisual":
			child.visible = debug_visible
			child.modulate.a = 0.3 if debug_visible else 1.0
	# Also toggle interactable radius visualization
	for interactable in interactables:
		if interactable.has_node("CollisionShape2D"):
			var shape = interactable.get_node("CollisionShape2D")
			shape.visible = debug_visible

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
