@tool
extends RefCounted

const MapObjectHandleScript = preload("res://addons/map_preview/preview_handles/map_object_handle.gd")
const SpawnPointHandleScript = preload("res://addons/map_preview/preview_handles/spawn_point_handle.gd")
const ObstacleHandleScript = preload("res://addons/map_preview/preview_handles/obstacle_handle.gd")

signal handle_changed(kind: String, layout_id: String, payload: Dictionary)

func render(scene_root: Node, map_data: Dictionary, layout: Dictionary) -> Node2D:
	clear(scene_root)
	var preview = Node2D.new()
	preview.name = "GeneratedMapPreview"
	preview.set_meta("map_preview_generated", true)
	scene_root.add_child(preview)

	var background = _create_background(layout)
	preview.add_child(background)

	var obstacles = Node2D.new()
	obstacles.name = "Obstacles"
	preview.add_child(obstacles)
	for obstacle in layout.get("obstacles", []):
		if typeof(obstacle) != TYPE_DICTIONARY:
			continue
		var handle = ObstacleHandleScript.new()
		handle.setup_obstacle(obstacle)
		handle.layout_changed.connect(_on_handle_changed)
		obstacles.add_child(handle)

	var spawns = Node2D.new()
	spawns.name = "Spawns"
	preview.add_child(spawns)
	for spawn_id in layout.get("spawn_points", {}).keys():
		var handle = SpawnPointHandleScript.new()
		handle.setup_spawn(str(spawn_id), layout.get("spawn_points", {}).get(spawn_id, {}))
		handle.layout_changed.connect(_on_handle_changed)
		spawns.add_child(handle)

	var decorations_container = Node2D.new()
	decorations_container.name = "Decorations"
	preview.add_child(decorations_container)
	for deco in layout.get("decorations", []):
		if typeof(deco) != TYPE_DICTIONARY:
			continue
		var deco_node = ColorRect.new()
		deco_node.name = str(deco.get("id", ""))
		var pos = deco.get("position", {})
		deco_node.position = Vector2(float(pos.get("x", 0)), float(pos.get("y", 0)))
		deco_node.size = Vector2(32, 32)
		deco_node.color = _deco_preview_color(str(deco.get("type", "")))
		decorations_container.add_child(deco_node)

	var objects = Node2D.new()
	objects.name = "Objects"
	preview.add_child(objects)
	var object_layouts = layout.get("objects", {})
	for object_record in map_data.get("objects", []):
		if typeof(object_record) != TYPE_DICTIONARY:
			continue
		var object_id = str(object_record.get("id", ""))
		if object_id.is_empty():
			continue
		var handle = MapObjectHandleScript.new()
		handle.setup_object(object_record, object_layouts.get(object_id, {}))
		handle.layout_changed.connect(_on_handle_changed)
		objects.add_child(handle)
	return preview

func update_object_handle(scene_root: Node, map_data: Dictionary, layout: Dictionary, object_id: String) -> bool:
	var handle = scene_root.get_node_or_null("GeneratedMapPreview/Objects/%s" % object_id)
	if handle == null or not handle.has_method("setup_object"):
		return false
	var object_record = _find_object_record(map_data, object_id)
	if object_record.is_empty():
		return false
	var object_layouts = layout.get("objects", {})
	var object_layout = {}
	if typeof(object_layouts) == TYPE_DICTIONARY:
		object_layout = object_layouts.get(object_id, {})
	handle.setup_object(object_record, object_layout)
	return true

func clear(scene_root: Node) -> void:
	var existing = scene_root.get_node_or_null("GeneratedMapPreview")
	if existing != null and existing.get_meta("map_preview_generated", false):
		scene_root.remove_child(existing)
		existing.free()

func _create_background(layout: Dictionary) -> Node2D:
	var mode = str(layout.get("mode", ""))
	var background_data = layout.get("background", {})

	match mode:
		"big_image":
			return _create_image_preview(background_data, layout)
		"tile_map":
			return _create_tile_preview(layout)
		_:
			return _create_color_preview(layout)


func _create_image_preview(background_data: Dictionary, _layout: Dictionary) -> Node2D:
	var container = Node2D.new()
	container.name = "Background"

	var image_path = str(background_data.get("path", ""))
	if not image_path.is_empty() and ResourceLoader.exists(image_path, "Texture2D"):
		var sprite = Sprite2D.new()
		sprite.texture = load(image_path)
		sprite.centered = false
		container.add_child(sprite)

	return container


func _create_tile_preview(layout: Dictionary) -> Node2D:
	var container = Node2D.new()
	container.name = "Background"
	var layers = layout.get("layers", {})
	var tileset_data = layout.get("tileset", {})
	var tile_size = Vector2(
		float(tileset_data.get("tile_size", {}).get("x", 128.0)),
		float(tileset_data.get("tile_size", {}).get("y", 128.0))
	)
	var layer_colors: Dictionary = {"ground": Color.GREEN.darkened(0.6), "decoration": Color.ORANGE.darkened(0.6), "overlay": Color.RED.darkened(0.6)}

	for layer_name in ["ground", "decoration", "overlay"]:
		var grid = layers.get(layer_name, [])
		if typeof(grid) != TYPE_ARRAY or grid.is_empty():
			continue
		for row_idx in range(grid.size()):
			var row = grid[row_idx]
			if typeof(row) != TYPE_ARRAY:
				continue
			for col_idx in range(row.size()):
				var terrain_id = str(row[col_idx])
				if terrain_id.is_empty() or terrain_id == "null":
					continue
				var cell = ColorRect.new()
				cell.size = tile_size
				cell.position = Vector2(col_idx * tile_size.x, row_idx * tile_size.y)
				var tint = layer_colors.get(layer_name, Color.GRAY)
				tint.a = 0.4
				cell.color = tint
				container.add_child(cell)

	return container


func _create_color_preview(layout: Dictionary) -> Node2D:
	var background = ColorRect.new()
	background.name = "Background"
	var size_data = layout.get("size", {})
	background.size = Vector2(float(size_data.get("x", 1280.0)), float(size_data.get("y", 720.0)))
	var background_data = layout.get("background", {})
	var color = str(background_data.get("color", "#334433"))
	background.color = Color(color) if Color.html_is_valid(color) else Color("#334433")
	return background


func _deco_preview_color(deco_type: String) -> Color:
	match deco_type:
		"tree": return Color.GREEN
		"bush": return Color.DARK_GREEN
		"rock": return Color.GRAY
		"signpost": return Color.BROWN
		"lantern": return Color.RED
		"building": return Color.SADDLE_BROWN
		"bridge": return Color.TAN
		_: return Color.MAGENTA


func _on_handle_changed(kind: String, layout_id: String, payload: Dictionary) -> void:
	handle_changed.emit(kind, layout_id, payload)


func _find_object_record(map_data: Dictionary, object_id: String) -> Dictionary:
	for object_record in map_data.get("objects", []):
		if typeof(object_record) == TYPE_DICTIONARY and str(object_record.get("id", "")) == object_id:
			return object_record
	return {}
