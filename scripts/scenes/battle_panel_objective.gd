extends PanelContainer

# Task 14: 左上「战斗目标 + 战场信息」面板。
# 顶部金色标题「战斗目标」+ 目标文本；分隔线；底部「战场信息」子标题 + 当前悬停地形动态文本。

const COLOR_PANEL := Color(0.06, 0.08, 0.10, 0.62)
const COLOR_BORDER := Color(0.84, 0.70, 0.36, 0.85)
const COLOR_TEXT_GOLD := Color(0.96, 0.84, 0.46)
const COLOR_TEXT := Color(0.92, 0.94, 0.96)
const COLOR_DIM := Color(0.78, 0.82, 0.86)

var _objective_label: Label
var _terrain_name_label: Label
var _terrain_effect_label: Label

func _ready() -> void:
	add_theme_stylebox_override("panel", _make_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	box.add_child(_make_title("战斗目标"))
	_objective_label = _make_text("击败所有敌人")
	box.add_child(_objective_label)

	box.add_child(_make_separator())

	box.add_child(_make_title("战场信息"))
	_terrain_name_label = _make_text("地形：—")
	box.add_child(_terrain_name_label)
	_terrain_effect_label = _make_text("效果：无")
	box.add_child(_terrain_effect_label)

func set_objective(text: String) -> void:
	if _objective_label != null:
		_objective_label.text = text

func set_hovered_terrain(terrain_name: String, effect_text: String) -> void:
	if _terrain_name_label != null:
		_terrain_name_label.text = "地形：%s" % (terrain_name if not terrain_name.is_empty() else "—")
	if _terrain_effect_label != null:
		_terrain_effect_label.text = "效果：%s" % (effect_text if not effect_text.is_empty() else "无")

func _make_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_BORDER
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _make_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
	l.add_theme_font_size_override("font_size", 16)
	return l

func _make_text(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", COLOR_TEXT)
	l.add_theme_font_size_override("font_size", 13)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", COLOR_BORDER)
	return sep
