class_name JournalState
extends RefCounted

const MAX_TRACKED_QUESTS := 3
const RUMOR_FIELDS := [
	"id",
	"title",
	"text",
	"source",
	"related_quest_id",
	"discovered_at_map_id",
]

var tracked_quest_ids: Array = []
var active_rumors: Dictionary = {}
var triggered_rumors: Dictionary = {}

func to_dictionary() -> Dictionary:
	normalize()
	return {
		"tracked_quest_ids": tracked_quest_ids.duplicate(),
		"active_rumors": active_rumors.duplicate(true),
		"triggered_rumors": triggered_rumors.duplicate(true),
	}

func from_dictionary(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		tracked_quest_ids = []
		active_rumors = {}
		triggered_rumors = {}
		return
	tracked_quest_ids = _to_tracked_ids(data.get("tracked_quest_ids", []))
	active_rumors = _to_rumor_dictionary(data.get("active_rumors", {}))
	triggered_rumors = _to_rumor_dictionary(data.get("triggered_rumors", {}))
	normalize()

func normalize() -> void:
	tracked_quest_ids = _to_tracked_ids(tracked_quest_ids)
	active_rumors = _to_rumor_dictionary(active_rumors)
	triggered_rumors = _to_rumor_dictionary(triggered_rumors)
	for rumor_id in triggered_rumors.keys():
		active_rumors.erase(rumor_id)

func _to_tracked_ids(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for raw_id in value:
		var quest_id = str(raw_id)
		if quest_id.is_empty() or result.has(quest_id):
			continue
		result.append(quest_id)
		if result.size() >= MAX_TRACKED_QUESTS:
			break
	return result

func _to_rumor_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for raw_key in value.keys():
		var record_value = value[raw_key]
		if typeof(record_value) != TYPE_DICTIONARY:
			continue
		var record = _normalize_rumor_record(record_value)
		var rumor_id = str(record.get("id", ""))
		if rumor_id.is_empty():
			rumor_id = str(raw_key)
			record["id"] = rumor_id
		if rumor_id.is_empty():
			continue
		result[rumor_id] = record
	return result

func _normalize_rumor_record(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field in RUMOR_FIELDS:
		result[field] = str(value.get(field, ""))
	return result
