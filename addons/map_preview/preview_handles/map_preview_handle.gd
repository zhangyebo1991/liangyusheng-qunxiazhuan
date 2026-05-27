@tool
extends Node2D

signal layout_changed(kind: String, layout_id: String, payload: Dictionary)

const LABEL_FONT_SIZE := 14
const LABEL_PADDING := Vector2(6.0, 4.0)
const LABEL_MAX_WIDTH := 220.0
const LABEL_MAX_CHARS := 28
const DEFAULT_CENTER_RADIUS := 8.0
const SELECTED_CENTER_RADIUS := 11.0
const DEFAULT_RADIUS_LINE_WIDTH := 2.0
const SELECTED_RADIUS_LINE_WIDTH := 4.0
const DEFAULT_RECT_LINE_WIDTH := 2.0
const SELECTED_RECT_LINE_WIDTH := 4.0
const DEFAULT_LABEL_BORDER_WIDTH := 1.5
const SELECTED_LABEL_BORDER_WIDTH := 3.0
const SELECTED_BORDER_COLOR := Color("#f7d154")

var handle_kind: String = ""
var layout_id: String = ""
var display_name: String = ""
var type_label: String = ""
var color: Color = Color("#ffffff")
var radius := 16.0
var rect_size := Vector2.ZERO
var selected := false
var suppress_transform_signal := false

func setup(
	next_kind: String,
	next_id: String,
	next_name: String,
	next_position: Vector2,
	next_color: Color,
	next_type_label: String = ""
) -> void:
	suppress_transform_signal = true
	handle_kind = next_kind
	layout_id = next_id
	display_name = next_name
	type_label = next_type_label
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

func set_selected(next_selected: bool) -> void:
	if selected == next_selected:
		return
	selected = next_selected
	queue_redraw()

func get_label_text() -> String:
	if display_name.is_empty() and type_label.is_empty():
		return ""
	if type_label.is_empty():
		return _trim_label(display_name)
	return _trim_label("%s / %s" % [display_name, type_label])

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and not suppress_transform_signal:
		layout_changed.emit(handle_kind, layout_id, {"position": {"x": position.x, "y": position.y}})

func _draw() -> void:
	var border_color = SELECTED_BORDER_COLOR if selected else color
	if rect_size != Vector2.ZERO:
		var border_width = SELECTED_RECT_LINE_WIDTH if selected else DEFAULT_RECT_LINE_WIDTH
		draw_rect(Rect2(Vector2.ZERO, rect_size), Color(color.r, color.g, color.b, 0.22), true)
		draw_rect(Rect2(Vector2.ZERO, rect_size), border_color, false, border_width)
	else:
		var center_radius = SELECTED_CENTER_RADIUS if selected else DEFAULT_CENTER_RADIUS
		var radius_line_width = SELECTED_RADIUS_LINE_WIDTH if selected else DEFAULT_RADIUS_LINE_WIDTH
		var radius_alpha = 0.85 if selected else 0.55
		draw_circle(Vector2.ZERO, center_radius, color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color.r, color.g, color.b, radius_alpha), radius_line_width)
	_draw_label()

func _draw_label() -> void:
	var text = get_label_text()
	if text.is_empty():
		return
	var font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, LABEL_MAX_WIDTH, LABEL_FONT_SIZE)
	var label_size = text_size + LABEL_PADDING * 2.0
	var label_position = _label_position(label_size)
	var label_rect = Rect2(label_position, label_size)
	var border_color = SELECTED_BORDER_COLOR if selected else color
	var border_width = SELECTED_LABEL_BORDER_WIDTH if selected else DEFAULT_LABEL_BORDER_WIDTH
	draw_rect(label_rect, Color(1.0, 1.0, 1.0, 0.88), true)
	draw_rect(label_rect, border_color, false, border_width)
	draw_string(
		font,
		label_position + Vector2(LABEL_PADDING.x, LABEL_PADDING.y + LABEL_FONT_SIZE),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		LABEL_MAX_WIDTH,
		LABEL_FONT_SIZE,
		Color("#1f241f")
	)

func _label_position(label_size: Vector2) -> Vector2:
	if rect_size != Vector2.ZERO:
		return Vector2(4.0, 4.0)
	return Vector2(12.0, -label_size.y - 10.0)

func _trim_label(text: String) -> String:
	if text.length() <= LABEL_MAX_CHARS:
		return text
	return "%s..." % text.substr(0, LABEL_MAX_CHARS - 3)
