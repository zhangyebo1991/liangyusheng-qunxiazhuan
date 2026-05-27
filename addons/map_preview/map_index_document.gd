@tool
extends RefCounted

const DEFAULT_PATH := "res://data/maps.json"

var path: String = DEFAULT_PATH
var maps_by_id: Dictionary = {}
var scene_path_to_map_id: Dictionary = {}
var loaded_hash := 0
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
	var next_maps_by_id := {}
	var next_scene_path_to_map_id := {}
	for map_data in parsed:
		if typeof(map_data) != TYPE_DICTIONARY:
			continue
		var map_id = str(map_data.get("id", "")).strip_edges()
		if map_id.is_empty():
			continue
		next_maps_by_id[map_id] = map_data
		var scene_path = str(map_data.get("scene_path", "")).strip_edges()
		if not scene_path.is_empty():
			next_scene_path_to_map_id[scene_path] = map_id
	path = source_path
	maps_by_id = next_maps_by_id
	scene_path_to_map_id = next_scene_path_to_map_id
	loaded_hash = _hash_text(text)
	last_error = ""
	return true

func has_text_change(text: String) -> bool:
	return _hash_text(text) != loaded_hash

func has_external_change() -> bool:
	return current_file_hash() != loaded_hash

func current_file_hash(source_path: String = "") -> int:
	var target_path = source_path if not source_path.is_empty() else path
	if target_path.is_empty():
		target_path = DEFAULT_PATH
	var file = FileAccess.open(target_path, FileAccess.READ)
	if file == null:
		return -1
	return _hash_text(file.get_as_text())

func get_maps_by_id() -> Dictionary:
	return maps_by_id.duplicate(true)

func get_scene_path_to_map_id() -> Dictionary:
	return scene_path_to_map_id.duplicate(true)

func _hash_text(text: String) -> int:
	return text.hash()
