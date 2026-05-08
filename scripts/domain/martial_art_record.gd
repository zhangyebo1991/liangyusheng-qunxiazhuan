class_name MartialArtRecord
extends RefCounted

var id: String = ""
var name: String = ""
var school: String = ""
var power: int = 0
var cost: int = 0
var description: String = ""

static func from_dictionary(data: Dictionary):
	var martial_art = new()
	martial_art.id = str(data.get("id", ""))
	martial_art.name = str(data.get("name", ""))
	martial_art.school = str(data.get("school", ""))
	martial_art.power = int(data.get("power", 0))
	martial_art.cost = int(data.get("cost", 0))
	martial_art.description = str(data.get("description", ""))
	return martial_art
