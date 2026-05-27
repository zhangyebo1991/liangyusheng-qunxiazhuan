@tool
extends RefCounted

var map_id: String = ""
var path: String = ""
var layout: Dictionary = {}
var loaded_hash: int = 0
var dirty := false

func load_map(next_map_id: String) -> bool:
	return load_from_path(next_map_id, "res://data/map_layouts/%s.json" % next_map_id)

func load_from_path(next_map_id: String, next_path: String) -> bool:
	var loaded = load_json(next_path)
	if loaded.is_empty():
		return false
	load_from_data(next_map_id, loaded, next_path)
	return true

func load_from_data(next_map_id: String, next_layout: Dictionary, next_path: String) -> void:
	map_id = next_map_id
	path = next_path
	layout = next_layout.duplicate(true)
	loaded_hash = _hash_layout(layout)
	dirty = false

func get_layout() -> Dictionary:
	return layout

func is_dirty() -> bool:
	return dirty

func has_external_change() -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var disk_layout = load_json(path)
	if disk_layout.is_empty():
		return false
	return _hash_layout(disk_layout) != loaded_hash

func update_object_position(object_id: String, position: Vector2) -> void:
	if object_id.is_empty():
		return
	var objects = _ensure_dictionary("objects")
	var object_layout = objects.get(object_id, {})
	if typeof(object_layout) != TYPE_DICTIONARY:
		object_layout = {}
	object_layout["position"] = _vector_to_dictionary(position)
	objects[object_id] = object_layout
	_mark_dirty()

func update_object_radius(object_id: String, radius: float) -> void:
	if object_id.is_empty() or radius <= 0.0:
		return
	var objects = _ensure_dictionary("objects")
	var object_layout = objects.get(object_id, {})
	if typeof(object_layout) != TYPE_DICTIONARY:
		object_layout = {}
	object_layout["radius"] = radius
	objects[object_id] = object_layout
	_mark_dirty()

func update_spawn_position(spawn_id: String, position: Vector2) -> void:
	if spawn_id.is_empty():
		return
	var spawn_points = _ensure_dictionary("spawn_points")
	spawn_points[spawn_id] = _vector_to_dictionary(position)
	_mark_dirty()

func update_obstacle_rect(obstacle_id: String, rect: Rect2) -> void:
	if obstacle_id.is_empty() or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var obstacles = layout.get("obstacles", [])
	if typeof(obstacles) != TYPE_ARRAY:
		obstacles = []
	for index in range(obstacles.size()):
		var obstacle = obstacles[index]
		if typeof(obstacle) == TYPE_DICTIONARY and str(obstacle.get("id", "")) == obstacle_id:
			var copy = obstacle.duplicate(true)
			copy["shape"] = "rect"
			copy["rect"] = _rect_to_dictionary(rect)
			obstacles[index] = copy
			layout["obstacles"] = obstacles
			_mark_dirty()
			return

func add_object_layout(object_id: String, position: Vector2, radius: float) -> Dictionary:
	object_id = object_id.strip_edges()
	if object_id.is_empty():
		return _error("请输入对象编号。")
	if radius <= 0.0:
		return _error("对象半径必须为正数：%s" % object_id)
	var objects = _ensure_dictionary("objects")
	if objects.has(object_id):
		return _error("对象布局已存在：%s" % object_id)
	objects[object_id] = {
		"position": _vector_to_dictionary(position),
		"radius": radius,
	}
	_mark_dirty()
	return _ok()

func add_spawn_point(spawn_id: String, position: Vector2) -> Dictionary:
	spawn_id = spawn_id.strip_edges()
	if spawn_id.is_empty():
		return _error("请输入出生点编号。")
	var spawn_points = _ensure_dictionary("spawn_points")
	if spawn_points.has(spawn_id):
		return _error("出生点已存在：%s" % spawn_id)
	spawn_points[spawn_id] = _vector_to_dictionary(position)
	_mark_dirty()
	return _ok()

func add_rect_obstacle(obstacle_id: String, rect: Rect2) -> Dictionary:
	obstacle_id = obstacle_id.strip_edges()
	if obstacle_id.is_empty():
		return _error("请输入障碍编号。")
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return _error("矩形障碍尺寸必须为正数：%s" % obstacle_id)
	var obstacles = layout.get("obstacles", [])
	if typeof(obstacles) != TYPE_ARRAY:
		obstacles = []
	for obstacle in obstacles:
		if typeof(obstacle) == TYPE_DICTIONARY and str(obstacle.get("id", "")) == obstacle_id:
			return _error("障碍编号已存在：%s" % obstacle_id)
	obstacles.append({
		"id": obstacle_id,
		"shape": "rect",
		"rect": _rect_to_dictionary(rect),
	})
	layout["obstacles"] = obstacles
	_mark_dirty()
	return _ok()

func save() -> bool:
	if path.is_empty():
		return false
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入布局文件：%s" % path)
		return false
	file.store_string(JSON.stringify(layout, "\t"))
	file.close()
	loaded_hash = _hash_layout(layout)
	dirty = false
	return true

func load_json(source_path: String) -> Dictionary:
	var file = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _ensure_dictionary(key: String) -> Dictionary:
	var value = layout.get(key, {})
	if typeof(value) != TYPE_DICTIONARY:
		value = {}
	layout[key] = value
	return value

func _mark_dirty() -> void:
	dirty = true

func _ok() -> Dictionary:
	return {"ok": true, "error": ""}

func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}

func _vector_to_dictionary(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}

func _rect_to_dictionary(value: Rect2) -> Dictionary:
	return {"x": value.position.x, "y": value.position.y, "w": value.size.x, "h": value.size.y}

func _hash_layout(value: Dictionary) -> int:
	return JSON.stringify(value, "\t").hash()
