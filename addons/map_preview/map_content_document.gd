@tool
extends RefCounted

const DEFAULT_PATH := "res://data/maps.json"

var path: String = DEFAULT_PATH
var maps: Array = []
var maps_by_id: Dictionary = {}
var scene_path_to_map_id: Dictionary = {}
var loaded_hash := 0
var dirty := false
var last_error := ""

func load_from_path(source_path: String = DEFAULT_PATH) -> bool:
	var file = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		last_error = "无法读取 data/maps.json。"
		return false
	return load_from_text(file.get_as_text(), source_path)

func load_from_text(text: String, source_path: String = DEFAULT_PATH) -> bool:
	var json = JSON.new()
	if json.parse(text) != OK:
		last_error = "data/maps.json 必须是数组。"
		return false
	var parsed = json.data
	if typeof(parsed) != TYPE_ARRAY:
		last_error = "data/maps.json 必须是数组。"
		return false

	path = source_path
	maps = parsed.duplicate(true)
	_rebuild_indexes()
	loaded_hash = _hash_text(text)
	dirty = false
	last_error = ""
	return true

func is_dirty() -> bool:
	return dirty

func get_maps_by_id() -> Dictionary:
	return maps_by_id.duplicate(true)

func get_scene_path_to_map_id() -> Dictionary:
	return scene_path_to_map_id.duplicate(true)

func find_object(map_id: String, object_id: String) -> Dictionary:
	var map_data = maps_by_id.get(map_id, {})
	if typeof(map_data) != TYPE_DICTIONARY:
		return {}
	var objects = map_data.get("objects", [])
	if typeof(objects) != TYPE_ARRAY:
		return {}
	for object_data in objects:
		if typeof(object_data) == TYPE_DICTIONARY and str(object_data.get("id", "")).strip_edges() == object_id:
			return object_data
	return {}

func add_object_to_map(map_id: String, object_record: Dictionary) -> Dictionary:
	var clean_map_id = map_id.strip_edges()
	if not maps_by_id.has(clean_map_id):
		return _error("地图编号不存在：%s" % clean_map_id)
	var object_id = str(object_record.get("id", "")).strip_edges()
	if object_id.is_empty():
		return _error("对象编号不能为空。")
	if not find_object(clean_map_id, object_id).is_empty():
		return _error("对象编号已存在：%s" % object_id)

	var map_data = maps_by_id[clean_map_id]
	var objects = map_data.get("objects", [])
	if typeof(objects) != TYPE_ARRAY:
		objects = []
		map_data["objects"] = objects
	var next_object = object_record.duplicate(true)
	next_object["id"] = object_id
	objects.append(next_object)
	_mark_dirty()
	return _ok()

func update_object_fields(map_id: String, object_id: String, fields: Dictionary) -> Dictionary:
	var clean_map_id = map_id.strip_edges()
	if not maps_by_id.has(clean_map_id):
		return _error("地图编号不存在：%s" % clean_map_id)
	var clean_object_id = object_id.strip_edges()
	if clean_object_id.is_empty():
		return _error("对象编号不能为空。")

	var object_data = find_object(clean_map_id, clean_object_id)
	if object_data.is_empty():
		return _error("对象编号不存在：%s" % clean_object_id)
	for key in fields.keys():
		object_data[key] = fields[key]
	_mark_dirty()
	return _ok()

func has_external_change() -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	return _hash_text(file.get_as_text()) != loaded_hash

func save() -> bool:
	if path.is_empty():
		last_error = "保存路径为空。"
		return false
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "无法写入 data/maps.json。"
		push_error("无法写入地图内容文件：%s" % path)
		return false
	var text = JSON.stringify(maps, "\t")
	file.store_string(text)
	file.close()
	loaded_hash = _hash_text(text)
	dirty = false
	last_error = ""
	return true

func _rebuild_indexes() -> void:
	maps_by_id = {}
	scene_path_to_map_id = {}
	for map_data in maps:
		if typeof(map_data) != TYPE_DICTIONARY:
			continue
		var map_id = str(map_data.get("id", "")).strip_edges()
		if map_id.is_empty():
			continue
		maps_by_id[map_id] = map_data
		var scene_path = str(map_data.get("scene_path", "")).strip_edges()
		if not scene_path.is_empty():
			scene_path_to_map_id[scene_path] = map_id

func _mark_dirty() -> void:
	dirty = true

func _ok() -> Dictionary:
	last_error = ""
	return {"ok": true, "error": ""}

func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}

func _hash_text(text: String) -> int:
	return text.hash()
