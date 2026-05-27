@tool
extends "res://addons/map_preview/preview_handles/map_preview_handle.gd"

func setup_obstacle(obstacle: Dictionary) -> void:
	var rect = obstacle.get("rect", {})
	var position_value = Vector2(float(rect.get("x", 0.0)), float(rect.get("y", 0.0)))
	var size_value = Vector2(float(rect.get("w", 0.0)), float(rect.get("h", 0.0)))
	setup("obstacle", str(obstacle.get("id", "")), str(obstacle.get("id", "")), position_value, Color("#476f3f"))
	set_rect_size(size_value)
