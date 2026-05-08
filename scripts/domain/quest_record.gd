class_name QuestRecord
extends RefCounted

var id: String = ""
var title: String = ""
var description: String = ""
var start_dialogue: String = ""
var reward_items: Array[String] = []

static func from_dictionary(data: Dictionary) -> QuestRecord:
	var quest = QuestRecord.new()
	quest.id = str(data.get("id", ""))
	quest.title = str(data.get("title", ""))
	quest.description = str(data.get("description", ""))
	quest.start_dialogue = str(data.get("start_dialogue", ""))
	quest.reward_items = _to_string_array(data.get("reward_items", []))
	return quest

static func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
