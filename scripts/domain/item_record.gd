class_name ItemRecord
extends RefCounted

var id: String = ""
var name: String = ""
var type: String = ""
var description: String = ""
var value: int = 0
var effects: Dictionary = {}
var equipment: Dictionary = {}

static func from_dictionary(data: Dictionary):
	var item = new()
	item.id = str(data.get("id", ""))
	item.name = str(data.get("name", ""))
	item.type = str(data.get("type", ""))
	item.description = str(data.get("description", ""))
	item.value = int(data.get("value", 0))
	item.effects = data.get("effects", {}).duplicate(true)
	var raw_equipment = data.get("equipment", {})
	item.equipment = raw_equipment.duplicate(true) if typeof(raw_equipment) == TYPE_DICTIONARY else {}
	return item
