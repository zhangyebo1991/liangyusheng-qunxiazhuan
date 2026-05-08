class_name ItemRecord
extends RefCounted

var id: String = ""
var name: String = ""
var type: String = ""
var description: String = ""
var value: int = 0

static func from_dictionary(data: Dictionary) -> ItemRecord:
	var item = ItemRecord.new()
	item.id = str(data.get("id", ""))
	item.name = str(data.get("name", ""))
	item.type = str(data.get("type", ""))
	item.description = str(data.get("description", ""))
	item.value = int(data.get("value", 0))
	return item
