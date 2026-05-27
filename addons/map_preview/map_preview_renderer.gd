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

func _create_background(layout: Dictionary) -> ColorRect:
	var background = ColorRect.new()
	background.name = "Background"
	var size_data = layout.get("size", {})
	background.size = Vector2(float(size_data.get("x", 1280.0)), float(size_data.get("y", 720.0)))
	var background_data = layout.get("background", {})
	var color = str(background_data.get("color", "#334433"))
	background.color = Color(color) if Color.html_is_valid(color) else Color("#334433")
	return background

func _on_handle_changed(kind: String, layout_id: String, payload: Dictionary) -> void:
	handle_changed.emit(kind, layout_id, payload)

func _find_object_record(map_data: Dictionary, object_id: String) -> Dictionary:
	for object_record in map_data.get("objects", []):
		if typeof(object_record) == TYPE_DICTIONARY and str(object_record.get("id", "")) == object_id:
			return object_record
	return {}
