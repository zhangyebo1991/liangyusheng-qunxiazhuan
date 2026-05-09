extends RefCounted

const DEFAULT_LOCKED_MESSAGE := "前路尚未开放。"

func resolve_transition(exit_object: Dictionary, target_map: Dictionary) -> Dictionary:
	var target_map_id = str(exit_object.get("target_map_id", ""))
	if target_map_id.is_empty():
		push_error("出口缺少目标地图。")
		return {
			"success": false,
			"message": str(exit_object.get("locked_message", DEFAULT_LOCKED_MESSAGE)),
		}

	if target_map.is_empty() or str(target_map.get("id", "")) != target_map_id:
		push_error("目标地图不存在：%s" % target_map_id)
		return {
			"success": false,
			"message": str(exit_object.get("locked_message", DEFAULT_LOCKED_MESSAGE)),
		}

	var spawn_id = str(exit_object.get("target_spawn_id", ""))
	return {
		"success": true,
		"map_id": target_map_id,
		"position": read_spawn_position(target_map, spawn_id),
	}

func read_spawn_position(map_data: Dictionary, spawn_id: String) -> Vector2:
	var fallback = _read_position(map_data.get("spawn_position", {}), Vector2.ZERO)
	var spawn_points = map_data.get("spawn_points", {})
	if typeof(spawn_points) == TYPE_DICTIONARY and not spawn_id.is_empty() and spawn_points.has(spawn_id):
		return _read_position(spawn_points.get(spawn_id, {}), fallback)
	return fallback

func _read_position(value: Variant, fallback: Vector2) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))
	return fallback
