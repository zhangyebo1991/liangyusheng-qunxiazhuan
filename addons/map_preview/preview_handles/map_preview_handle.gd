@tool
extends Node2D

signal layout_changed(kind: String, layout_id: String, payload: Dictionary)

var handle_kind: String = ""
var layout_id: String = ""
var display_name: String = ""
var color: Color = Color("#ffffff")
var radius := 16.0
var rect_size := Vector2.ZERO
var suppress_transform_signal := false

func setup(next_kind: String, next_id: String, next_name: String, next_position: Vector2, next_color: Color) -> void:
	suppress_transform_signal = true
	handle_kind = next_kind
	layout_id = next_id
	display_name = next_name
	color = next_color
	name = next_id
	position = next_position
	set_meta("map_preview_generated", true)
	set_notify_transform(true)
	suppress_transform_signal = false
	queue_redraw()

func set_radius(next_radius: float) -> void:
	radius = max(next_radius, 1.0)
	queue_redraw()

func set_rect_size(next_size: Vector2) -> void:
	rect_size = next_size
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and not suppress_transform_signal:
		layout_changed.emit(handle_kind, layout_id, {"position": {"x": position.x, "y": position.y}})

func _draw() -> void:
	if rect_size != Vector2.ZERO:
		draw_rect(Rect2(Vector2.ZERO, rect_size), Color(color.r, color.g, color.b, 0.22), true)
		draw_rect(Rect2(Vector2.ZERO, rect_size), color, false, 2.0)
	else:
		draw_circle(Vector2.ZERO, 8.0, color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color.r, color.g, color.b, 0.55), 2.0)
