@tool
extends "res://addons/map_preview/preview_handles/map_preview_handle.gd"

func setup_obstacle(obstacle: Dictionary) -> void:
	var obstacle_id = str(obstacle.get("id", ""))
	var rect = obstacle.get("rect", {})
	var position_value = Vector2(float(rect.get("x", 0.0)), float(rect.get("y", 0.0)))
	var size_value = Vector2(float(rect.get("w", 0.0)), float(rect.get("h", 0.0)))
	setup("obstacle", obstacle_id, "障碍", position_value, Color("#476f3f"), obstacle_id)
	set_rect_size(size_value)
