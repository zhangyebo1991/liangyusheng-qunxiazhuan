extends RefCounted

func get_spawn_records(map_data: Dictionary, resolved_objects: Array, game_state = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for object in map_data.get("objects", []):
		var object_id = str(object.get("id", ""))
		if object_id.is_empty():
			continue
		if resolved_objects.has(object_id):
			continue
		if not _meets_required_quest(object, game_state):
			continue
		result.append(object)
	return result

func read_position(object: Dictionary) -> Vector2:
	var position = object.get("position", {})
	if typeof(position) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(position.get("x", 0.0)), float(position.get("y", 0.0)))

func _meets_required_quest(record: Dictionary, game_state) -> bool:
	if str(record.get("type", "")) == "exit":
		return true
	var quest_id = str(record.get("required_quest_id", ""))
	var required_status = str(record.get("required_quest_status", ""))
	if quest_id.is_empty() and required_status.is_empty():
		return true
	if quest_id.is_empty() or required_status.is_empty():
		return false
	if game_state == null or game_state.quest_system == null:
		return false
	return game_state.quest_system.get_status(quest_id) == required_status
