@tool
extends RefCounted

const DEFAULT_DIALOGUES_PATH := "res://data/dialogues.json"
const DEFAULT_QUESTS_PATH := "res://data/quests.json"

var dialogues_path := DEFAULT_DIALOGUES_PATH
var quests_path := DEFAULT_QUESTS_PATH
var dialogues: Array = []
var quests: Array = []
var dialogues_by_id: Dictionary = {}
var quests_by_id: Dictionary = {}
var quests_by_dialogue_id: Dictionary = {}
var dialogues_loaded_hash := 0
var quests_loaded_hash := 0
var dialogues_dirty := false
var quests_dirty := false
var last_error := ""

func load_all(next_dialogues_path: String = DEFAULT_DIALOGUES_PATH, next_quests_path: String = DEFAULT_QUESTS_PATH) -> bool:
	var dialogue_result = _load_array_file(next_dialogues_path, "data/dialogues.json")
	if not dialogue_result.get("ok", false):
		return _fail(str(dialogue_result.get("error", "")))
	var quest_result = _load_array_file(next_quests_path, "data/quests.json")
	if not quest_result.get("ok", false):
		return _fail(str(quest_result.get("error", "")))

	dialogues_path = next_dialogues_path
	quests_path = next_quests_path
	dialogues = dialogue_result.get("data", []).duplicate(true)
	quests = quest_result.get("data", []).duplicate(true)
	dialogues_loaded_hash = int(dialogue_result.get("hash", 0))
	quests_loaded_hash = int(quest_result.get("hash", 0))
	dialogues_dirty = false
	quests_dirty = false
	last_error = ""
	_rebuild_indexes()
	return true

func load_from_texts(dialogues_text: String, quests_text: String, next_dialogues_path: String = DEFAULT_DIALOGUES_PATH, next_quests_path: String = DEFAULT_QUESTS_PATH) -> bool:
	var dialogue_result = _parse_array_text(dialogues_text, "data/dialogues.json")
	if not dialogue_result.get("ok", false):
		return _fail(str(dialogue_result.get("error", "")))
	var quest_result = _parse_array_text(quests_text, "data/quests.json")
	if not quest_result.get("ok", false):
		return _fail(str(quest_result.get("error", "")))

	dialogues_path = next_dialogues_path
	quests_path = next_quests_path
	dialogues = dialogue_result.get("data", []).duplicate(true)
	quests = quest_result.get("data", []).duplicate(true)
	dialogues_loaded_hash = dialogues_text.hash()
	quests_loaded_hash = quests_text.hash()
	dialogues_dirty = false
	quests_dirty = false
	last_error = ""
	_rebuild_indexes()
	return true

func get_dialogue(dialogue_id: String) -> Dictionary:
	var record = _get_dialogue_record(dialogue_id)
	return record.duplicate(true) if not record.is_empty() else {}

func get_quest(quest_id: String) -> Dictionary:
	var record = _get_quest_record(quest_id)
	return record.duplicate(true) if not record.is_empty() else {}

func find_quests_for_dialogue(dialogue_id: String) -> Array:
	var clean_dialogue_id = dialogue_id.strip_edges()
	var refs = quests_by_dialogue_id.get(clean_dialogue_id, [])
	var result: Array = []
	if typeof(refs) != TYPE_ARRAY:
		return result
	for ref in refs:
		if typeof(ref) != TYPE_DICTIONARY:
			continue
		var quest_id = str(ref.get("quest_id", "")).strip_edges()
		var quest = _get_quest_record(quest_id)
		if quest.is_empty():
			continue
		result.append({
			"quest_id": quest_id,
			"field": str(ref.get("field", "")),
			"title": str(quest.get("title", "")),
			"description": str(quest.get("description", "")),
		})
	return result

func update_dialogue_title(dialogue_id: String, title: String) -> Dictionary:
	var dialogue = _get_dialogue_record(dialogue_id)
	if dialogue.is_empty():
		return _error("对白不存在：%s" % dialogue_id.strip_edges())
	dialogue["title"] = title
	_mark_dialogues_dirty()
	return _ok()

func set_dialogue_lines(dialogue_id: String, lines: Array) -> Dictionary:
	var dialogue = _get_dialogue_record(dialogue_id)
	if dialogue.is_empty():
		return _error("对白不存在：%s" % dialogue_id.strip_edges())
	var clean_lines: Array = []
	for line in lines:
		if typeof(line) == TYPE_DICTIONARY:
			clean_lines.append({
				"speaker": str(line.get("speaker", "")),
				"text": str(line.get("text", "")),
			})
		else:
			clean_lines.append({"speaker": "", "text": str(line)})
	dialogue["lines"] = clean_lines
	_mark_dialogues_dirty()
	return _ok()

func create_dialogue_template(dialogue_id: String) -> Dictionary:
	var clean_id = dialogue_id.strip_edges()
	if clean_id.is_empty():
		return _error("对白编号不能为空。")
	if dialogues_by_id.has(clean_id):
		return _error("对白已存在：%s" % clean_id)
	dialogues.append({
		"id": clean_id,
		"title": "新对白",
		"lines": [
			{"speaker": "", "text": ""}
		],
	})
	_rebuild_indexes()
	_mark_dialogues_dirty()
	return _ok()

func save_dialogues() -> bool:
	if dialogues_path.is_empty():
		return _fail("对白保存路径为空。")
	if dialogues_dirty and dialogues_have_external_change():
		return _fail("对白文件已被外部修改，请刷新后再保存。")
	var text = JSON.stringify(dialogues, "\t")
	if not _write_text(dialogues_path, text, "无法写入 data/dialogues.json。"):
		return false
	dialogues_loaded_hash = text.hash()
	dialogues_dirty = false
	last_error = ""
	return true

func update_quest_summary(quest_id: String, title: String, description: String) -> Dictionary:
	var quest = _get_quest_record(quest_id)
	if quest.is_empty():
		return _error("任务不存在：%s" % quest_id.strip_edges())
	quest["title"] = title
	quest["description"] = description
	_mark_quests_dirty()
	return _ok()

func create_quest_template(quest_id: String) -> Dictionary:
	var clean_id = quest_id.strip_edges()
	if clean_id.is_empty():
		return _error("任务编号不能为空。")
	if quests_by_id.has(clean_id):
		return _error("任务已存在：%s" % clean_id)
	quests.append({
		"id": clean_id,
		"title": "新任务",
		"description": "",
	})
	_rebuild_indexes()
	_mark_quests_dirty()
	return _ok()

func save_quests() -> bool:
	if quests_path.is_empty():
		return _fail("任务保存路径为空。")
	if quests_dirty and quests_have_external_change():
		return _fail("任务文件已被外部修改，请刷新后再保存。")
	var text = JSON.stringify(quests, "\t")
	if not _write_text(quests_path, text, "无法写入 data/quests.json。"):
		return false
	quests_loaded_hash = text.hash()
	quests_dirty = false
	last_error = ""
	return true

func dialogues_have_external_change() -> bool:
	return _has_external_change(dialogues_path, dialogues_loaded_hash)

func quests_have_external_change() -> bool:
	return _has_external_change(quests_path, quests_loaded_hash)

func _load_array_file(source_path: String, label: String) -> Dictionary:
	var file = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "无法读取 %s。" % label}
	var text = file.get_as_text()
	var parsed = _parse_array_text(text, label)
	if not parsed.get("ok", false):
		return parsed
	parsed["hash"] = text.hash()
	return parsed

func _parse_array_text(text: String, label: String) -> Dictionary:
	var json = JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "error": "%s 必须是数组。" % label}
	if typeof(json.data) != TYPE_ARRAY:
		return {"ok": false, "error": "%s 必须是数组。" % label}
	return {"ok": true, "data": json.data.duplicate(true)}

func _write_text(path: String, text: String, error_message: String) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _fail(error_message)
	file.store_string(text)
	file.close()
	return true

func _has_external_change(path: String, loaded_hash: int) -> bool:
	if path.is_empty():
		return false
	if not FileAccess.file_exists(path):
		return true
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return true
	return file.get_as_text().hash() != loaded_hash

func _rebuild_indexes() -> void:
	dialogues_by_id = {}
	quests_by_id = {}
	quests_by_dialogue_id = {}

	for dialogue in dialogues:
		if typeof(dialogue) != TYPE_DICTIONARY:
			continue
		var dialogue_id = str(dialogue.get("id", "")).strip_edges()
		if not dialogue_id.is_empty():
			dialogues_by_id[dialogue_id] = dialogue

	for quest in quests:
		if typeof(quest) != TYPE_DICTIONARY:
			continue
		var quest_id = str(quest.get("id", "")).strip_edges()
		if quest_id.is_empty():
			continue
		quests_by_id[quest_id] = quest
		for field in ["start_dialogue", "complete_dialogue"]:
			var dialogue_id = str(quest.get(field, "")).strip_edges()
			if dialogue_id.is_empty():
				continue
			var refs = quests_by_dialogue_id.get(dialogue_id, [])
			if typeof(refs) != TYPE_ARRAY:
				refs = []
			refs.append({"quest_id": quest_id, "field": field})
			quests_by_dialogue_id[dialogue_id] = refs

func _get_dialogue_record(dialogue_id: String) -> Dictionary:
	var clean_id = dialogue_id.strip_edges()
	var record = dialogues_by_id.get(clean_id, {})
	return record if typeof(record) == TYPE_DICTIONARY else {}

func _get_quest_record(quest_id: String) -> Dictionary:
	var clean_id = quest_id.strip_edges()
	var record = quests_by_id.get(clean_id, {})
	return record if typeof(record) == TYPE_DICTIONARY else {}

func _mark_dialogues_dirty() -> void:
	dialogues_dirty = true

func _mark_quests_dirty() -> void:
	quests_dirty = true

func _ok() -> Dictionary:
	last_error = ""
	return {"ok": true, "error": ""}

func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}

func _fail(message: String) -> bool:
	last_error = message
	return false
