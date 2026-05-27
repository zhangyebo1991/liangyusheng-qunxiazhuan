@tool
extends "res://addons/map_preview/preview_handles/map_preview_handle.gd"

func setup_object(object_record: Dictionary, object_layout: Dictionary) -> void:
	var object_id = str(object_record.get("id", ""))
	var position_data = object_layout.get("position", object_record.get("position", {}))
	var position_value = Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
	setup("object", object_id, str(object_record.get("name", object_id)), position_value, _type_color(str(object_record.get("type", ""))))
	set_radius(float(object_layout.get("radius", object_record.get("radius", 48.0))))

func _type_color(object_type: String) -> Color:
	match object_type:
		"npc":
			return Color("#8d3b7a")
		"battle_trigger":
			return Color("#8f3b2f")
		"exit":
			return Color("#2f6fdd")
		"notice":
			return Color("#c49a2c")
		"shop":
			return Color("#3d7f5c")
		"pickup":
			return Color("#7c6f3a")
		_:
			return Color("#666666")
