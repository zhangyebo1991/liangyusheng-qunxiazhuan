@tool
extends "res://addons/map_preview/preview_handles/map_preview_handle.gd"

const MapPreviewTypesScript = preload("res://addons/map_preview/map_preview_type_metadata.gd")

func setup_object(object_record: Dictionary, object_layout: Dictionary) -> void:
	var object_id = str(object_record.get("id", ""))
	var object_type = str(object_record.get("type", ""))
	var position_data = object_layout.get("position", object_record.get("position", {}))
	var position_value = Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
	setup(
		"object",
		object_id,
		MapPreviewTypesScript.object_display_name(object_record),
		position_value,
		MapPreviewTypesScript.type_color(object_type),
		MapPreviewTypesScript.type_label(object_type)
	)
	set_radius(float(object_layout.get("radius", object_record.get("radius", 48.0))))
