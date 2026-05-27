@tool
extends "res://addons/map_preview/preview_handles/map_preview_handle.gd"

func setup_spawn(spawn_id: String, position_data: Dictionary) -> void:
	var position_value = Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
	setup("spawn", spawn_id, "出生点", position_value, Color("#ffffff"), spawn_id)
	set_radius(20.0)
