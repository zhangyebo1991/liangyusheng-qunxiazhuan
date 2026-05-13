extends PanelContainer

# Task 15: 右上「当前行动角色状态卡」面板。
# 显示当前 actor 的头像、名字、HP/MP 进度条、攻防移动等基础属性。

const COLOR_PANEL := Color(0.06, 0.08, 0.10, 0.62)
const COLOR_BORDER := Color(0.84, 0.70, 0.36, 0.85)
const COLOR_TEXT_GOLD := Color(0.96, 0.84, 0.46)
const COLOR_TEXT := Color(0.92, 0.94, 0.96)
const COLOR_HP := Color(0.74, 0.32, 0.30)
const COLOR_MP := Color(0.30, 0.56, 0.86)
const COLOR_CHARGE := Color(0.86, 0.78, 0.36)
const TILES_DIR := "res://assets/kenney_tiny-battle/Tiles/"
const CHARGE_LIMIT := 1000
const AVATAR_BOX_SIZE := Vector2(96, 96)

var _avatar_rect: TextureRect
var _name_label: Label
var _hp_label: Label
var _hp_bar: ProgressBar
var _mp_label: Label
var _mp_bar: ProgressBar
var _charge_label: Label
var _charge_bar: ProgressBar
var _stats_label: Label

func _ready() -> void:
	add_theme_stylebox_override("panel", _make_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)

	_avatar_rect = TextureRect.new()
	_avatar_rect.custom_minimum_size = AVATAR_BOX_SIZE
	_avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.add_child(_avatar_rect)

	_name_label = Label.new()
	_name_label.text = "—"
	_name_label.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_name_label)

	_hp_label = _make_text("生命 0/0")
	box.add_child(_hp_label)
	_hp_bar = _make_bar(COLOR_HP)
	box.add_child(_hp_bar)

	_mp_label = _make_text("内力 0/0")
	box.add_child(_mp_label)
	_mp_bar = _make_bar(COLOR_MP)
	box.add_child(_mp_bar)

	_charge_label = _make_text("集气 0/%d" % CHARGE_LIMIT)
	box.add_child(_charge_label)
	_charge_bar = _make_bar(COLOR_CHARGE)
	box.add_child(_charge_bar)

	box.add_child(_make_separator())
	_stats_label = _make_text("攻 0  防 0  动 0")
	box.add_child(_stats_label)

func set_actor(actor_state: Object) -> void:
	if _name_label == null:
		return  # _ready 还没跑完（典型场景：测试中尚未 add_child）
	if actor_state == null:
		_name_label.text = "—"
		_avatar_rect.texture = null
		_hp_label.text = "生命 0/0"
		_hp_bar.value = 0
		_mp_label.text = "内力 0/0"
		_mp_bar.value = 0
		_charge_label.text = "集气 0/%d" % CHARGE_LIMIT
		_charge_bar.value = 0
		_stats_label.text = "攻 0  防 0  动 0"
		return
	_name_label.text = str(actor_state.display_name)
	var tile_id := str(actor_state.sprite_tile_id)
	if tile_id.is_empty():
		_avatar_rect.texture = null
	else:
		var tex_path := TILES_DIR + tile_id + ".png"
		if ResourceLoader.exists(tex_path):
			_avatar_rect.texture = load(tex_path)
		else:
			_avatar_rect.texture = null
	var hp := int(actor_state.hp)
	var max_hp := int(max(1, int(actor_state.max_hp)))
	_hp_label.text = "生命 %d/%d" % [hp, max_hp]
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	var mp := int(actor_state.mp)
	var max_mp := int(max(0, int(actor_state.max_mp)))
	_mp_label.text = "内力 %d/%d" % [mp, max_mp]
	_mp_bar.max_value = max(1, max_mp)
	_mp_bar.value = mp
	var charge := int(actor_state.charge)
	_charge_label.text = "集气 %d/%d" % [charge, CHARGE_LIMIT]
	_charge_bar.max_value = CHARGE_LIMIT
	_charge_bar.value = charge
	_stats_label.text = "攻 %d  防 %d  动 %d" % [int(actor_state.attack), int(actor_state.defense), int(actor_state.move_range)]

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

func _make_bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 10)
	b.max_value = 100
	b.value = 0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.12, 0.14, 0.85)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.30, 0.34, 0.38, 0.7)
	bg.corner_radius_top_left = 2
	bg.corner_radius_top_right = 2
	bg.corner_radius_bottom_right = 2
	bg.corner_radius_bottom_left = 2
	b.add_theme_stylebox_override("background", bg)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.corner_radius_top_left = 2
	fg.corner_radius_top_right = 2
	fg.corner_radius_bottom_right = 2
	fg.corner_radius_bottom_left = 2
	b.add_theme_stylebox_override("fill", fg)
	return b

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", COLOR_BORDER)
	return sep
