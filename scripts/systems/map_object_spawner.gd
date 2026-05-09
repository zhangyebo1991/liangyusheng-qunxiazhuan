extends RefCounted

func get_spawn_records(map_data: Dictionary, resolved_objects: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for object in map_data.get("objects", []):
		var object_id = str(object.get("id", ""))
		if object_id.is_empty():
			continue
		if resolved_objects.has(object_id):
			continue
		result.append(object)
	return result

func read_position(object: Dictionary) -> Vector2:
	var position = object.get("position", {})
	if typeof(position) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(position.get("x", 0.0)), float(position.get("y", 0.0)))
