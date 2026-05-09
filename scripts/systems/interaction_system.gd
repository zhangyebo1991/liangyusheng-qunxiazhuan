extends RefCounted

func find_nearest_in_range(player_position: Vector2, objects: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for object in objects:
		var object_position = _read_position(object.get("position", Vector2.ZERO))
		var radius = float(object.get("radius", 48.0))
		var distance = player_position.distance_to(object_position)
		if distance <= radius and distance < best_distance:
			best = object
			best_distance = distance
	return best

func is_click_in_object(click_position: Vector2, object: Dictionary) -> bool:
	var object_position = _read_position(object.get("position", Vector2.ZERO))
	var radius = float(object.get("radius", 48.0))
	return click_position.distance_to(object_position) <= radius

func _read_position(value: Variant) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO
