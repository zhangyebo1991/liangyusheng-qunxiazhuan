extends PanelContainer

# Task 14: 左下「地形信息」面板。
# 显示当前焦点格的地形名 / tile 图 / 移动消耗 / 闪避加成；底部小字提示。

const COLOR_PANEL := Color(0.06, 0.08, 0.10, 0.62)
const COLOR_BORDER := Color(0.84, 0.70, 0.36, 0.85)
const COLOR_TEXT_GOLD := Color(0.96, 0.84, 0.46)
const COLOR_TEXT := Color(0.92, 0.94, 0.96)
const COLOR_DIM := Color(0.66, 0.70, 0.74)
const TILES_DIR := "res://assets/kenney_tiny-battle/Tiles/"

var _name_label: Label
var _tile_rect: TextureRect
var _evasion_label: Label
var _move_cost_label: Label
var _hint_label: Label

func _ready() -> void:
	add_theme_stylebox_override("panel", _make_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	_name_label = Label.new()
	_name_label.text = "—"
	_name_label.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_name_label)

	_tile_rect = TextureRect.new()
	_tile_rect.custom_minimum_size = Vector2(64, 64)
	_tile_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tile_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box.add_child(_tile_rect)

	_evasion_label = _make_text("闪避 +0%")
	box.add_child(_evasion_label)

	_move_cost_label = _make_text("移动消耗 1")
	box.add_child(_move_cost_label)

	box.add_child(_make_separator())

	_hint_label = Label.new()
	_hint_label.text = "鼠标悬停格子查看地形"
	_hint_label.add_theme_color_override("font_color", COLOR_DIM)
	_hint_label.add_theme_font_size_override("font_size", 11)
	box.add_child(_hint_label)

func set_terrain(terrain_data: Dictionary) -> void:
	if terrain_data.is_empty():
		if _name_label != null:
			_name_label.text = "—"
		if _tile_rect != null:
			_tile_rect.texture = null
		if _evasion_label != null:
			_evasion_label.text = "闪避 +0%"
		if _move_cost_label != null:
			_move_cost_label.text = "移动消耗 1"
		return
	if _name_label != null:
		_name_label.text = str(terrain_data.get("name", "—"))
	if _tile_rect != null:
		var tile_id := str(terrain_data.get("tile_id", ""))
		if tile_id.is_empty():
			_tile_rect.texture = null
		else:
			var tex_path := TILES_DIR + tile_id + ".png"
			if ResourceLoader.exists(tex_path):
				_tile_rect.texture = load(tex_path)
			else:
				_tile_rect.texture = null
	if _evasion_label != null:
		var ev := int(terrain_data.get("evasion_bonus", 0))
		_evasion_label.text = "闪避 %s%d%%" % [("+" if ev >= 0 else ""), ev]
	if _move_cost_label != null:
		_move_cost_label.text = "移动消耗 %d" % int(terrain_data.get("move_cost", 1))

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

func _make_text(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", COLOR_TEXT)
	l.add_theme_font_size_override("font_size", 13)
	return l

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", COLOR_BORDER)
	return sep
