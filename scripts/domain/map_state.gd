class_name MapState
extends RefCounted

var current_map_id: String = "mountain_pass"
var player_position: Vector2 = Vector2(160, 320)
var resolved_objects: Array[String] = []
var reward_claims: Dictionary = {}

func set_player_position(next_position: Vector2) -> void:
	player_position = next_position

func mark_object_resolved(object_id: String) -> void:
	if object_id.is_empty():
		return
	if not resolved_objects.has(object_id):
		resolved_objects.append(object_id)

func is_object_resolved(object_id: String) -> bool:
	return resolved_objects.has(object_id)

func mark_reward_claimed(reward_id: String) -> void:
	if reward_id.is_empty():
		return
	reward_claims[reward_id] = true

func is_reward_claimed(reward_id: String) -> bool:
	return bool(reward_claims.get(reward_id, false))

func to_dictionary() -> Dictionary:
	return {
		"current_map_id": current_map_id,
		"player_position": {
			"x": player_position.x,
			"y": player_position.y,
		},
		"resolved_objects": resolved_objects.duplicate(),
		"reward_claims": reward_claims.duplicate(true),
	}

func from_dictionary(data: Dictionary) -> void:
	current_map_id = str(data.get("current_map_id", "mountain_pass"))
	var position = data.get("player_position", {})
	player_position = Vector2(
		float(position.get("x", 160.0)),
		float(position.get("y", 320.0))
	)
	resolved_objects = _to_string_array(data.get("resolved_objects", []))
	reward_claims = data.get("reward_claims", {}).duplicate(true)

func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
