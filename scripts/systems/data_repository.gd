extends Node

const DATA_FILES := {
	"actors": "res://data/actors.json",
	"items": "res://data/items.json",
	"martial_arts": "res://data/martial_arts.json",
	"quests": "res://data/quests.json",
	"dialogues": "res://data/dialogues.json",
	"maps": "res://data/maps.json",
}

var content: Dictionary = {}

func load_all() -> Dictionary:
	var loaded: Dictionary = {}
	for key in DATA_FILES.keys():
		loaded[key] = _load_json_array(DATA_FILES[key])
	content = loaded
	return content

func get_actor(actor_id: String) -> Dictionary:
	return _find_by_id("actors", actor_id)

func get_item(item_id: String) -> Dictionary:
	return _find_by_id("items", item_id)

func get_martial_art(martial_art_id: String) -> Dictionary:
	return _find_by_id("martial_arts", martial_art_id)

func get_quest(quest_id: String) -> Dictionary:
	return _find_by_id("quests", quest_id)

func get_dialogue(dialogue_id: String) -> Dictionary:
	return _find_by_id("dialogues", dialogue_id)

func get_map(map_id: String) -> Dictionary:
	return _find_by_id("maps", map_id)

func _find_by_id(collection_name: String, record_id: String) -> Dictionary:
	if content.is_empty():
		load_all()

	for record in content.get(collection_name, []):
		if record.get("id", "") == record_id:
			return record

	return {}

func _load_json_array(path: String) -> Array:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法读取数据文件：%s" % path)
		return []

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("数据文件必须是数组：%s" % path)
		return []

	return parsed
