extends RefCounted

var _arts: Dictionary = {}
var _learned_arts: Dictionary = {}
var _active_art: String = ""

func _init():
	_load_arts()

func _load_arts():
	var dir = DirAccess.open("res://data/inner_arts")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var file = FileAccess.open("res://data/inner_arts/" + file_name, FileAccess.READ)
				if file:
					var json = JSON.new()
					var error = json.parse(file.get_as_text())
					if error == OK and json.data is Dictionary:
						var data = json.data
						if data.has("id"):
							_arts[data.id] = data
			file_name = dir.get_next()

func learn_art(art_id: String):
	if _arts.has(art_id) and not _learned_arts.has(art_id):
		_learned_arts[art_id] = {"level": 0}

func upgrade_art(art_id: String, available_points: int) -> Dictionary:
	if not _learned_arts.has(art_id):
		return {"success": false, "message": "未学会此心法"}

	var art_data = _arts[art_id]
	var current_level = _learned_arts[art_id].level
	var max_level = int(art_data.get("max_level", 1))

	if current_level >= max_level:
		return {"success": false, "message": "已达最高级"}

	var costs = art_data.get("level_up_cost", [])
	var cost = 1
	if current_level < costs.size():
		cost = int(costs[current_level])

	if available_points < cost:
		return {"success": false, "message": "修为点不足"}

	_learned_arts[art_id].level += 1
	return {"success": true, "cost": cost}

func switch_active(art_id: String) -> Dictionary:
	if not _learned_arts.has(art_id):
		return {"success": false, "message": "未学会此心法"}

	_active_art = art_id
	return {"success": true}

func get_art_level(art_id: String) -> int:
	if _learned_arts.has(art_id):
		return _learned_arts[art_id].level
	return 0

func get_active_art() -> String:
	return _active_art

func check_triggers(_scene: String, _context: Dictionary) -> Dictionary:
	return {}
