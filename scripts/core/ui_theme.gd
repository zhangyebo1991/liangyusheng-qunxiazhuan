class_name UiTheme

# 武侠风 UI 设计语言常量
const COLOR_BG_INK := Color(0.06, 0.05, 0.04, 0.97)
const COLOR_BG_INK_LIGHT := Color(0.12, 0.09, 0.04, 1.0)
const COLOR_BG_INK_MID := Color(0.11, 0.09, 0.06, 1.0)
const COLOR_BG_INK_DARK := Color(0.10, 0.09, 0.07, 1.0)

const COLOR_BORDER_GOLD := Color(0.72, 0.56, 0.18, 1.0)
const COLOR_BORDER_GOLD_DIM := Color(0.45, 0.35, 0.12, 0.7)
const COLOR_BORDER_GOLD_FAINT := Color(0.55, 0.40, 0.12, 1.0)

const COLOR_TEXT_GOLD := Color(0.92, 0.76, 0.30, 1.0)
const COLOR_TEXT_WARM := Color(0.75, 0.70, 0.58, 1.0)
const COLOR_TEXT_DIM := Color(0.55, 0.50, 0.40, 1.0)
const COLOR_TEXT_BLUE := Color(0.6, 0.85, 1.0, 1.0)
const COLOR_TEXT_GREEN := Color(0.70, 0.90, 0.65, 1.0)
const COLOR_TEXT_DISABLED := Color(0.40, 0.38, 0.30, 0.7)

const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.65)

const COLOR_BTN_NORMAL := Color(0.18, 0.10, 0.04, 1.0)
const COLOR_BTN_HOVER := Color(0.32, 0.18, 0.04, 1.0)
const COLOR_BTN_HOVER_BRIGHT := Color(0.38, 0.22, 0.04, 1.0)
const COLOR_BTN_BORDER := Color(0.65, 0.50, 0.15, 0.9)
const COLOR_BTN_BORDER_BRIGHT := Color(0.85, 0.65, 0.22, 1.0)
const COLOR_BTN_BORDER_DIM := Color(0.30, 0.25, 0.10, 0.5)

const COLOR_SEPARATOR := Color(0.72, 0.56, 0.18, 0.55)

const FONT_SIZE_TITLE := 18
const FONT_SIZE_NORMAL := 15
const FONT_SIZE_SMALL := 13
const FONT_SIZE_LARGE := 36

static func make_gold_panel(corner_radius := 6, shadow_size := 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG_INK
	style.border_color = COLOR_BORDER_GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(corner_radius)
	style.shadow_color = COLOR_SHADOW
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(4, 6)
	return style

static func make_panel_style(bg_color: Color, border_color: Color, border_width := 2, corner_radius := 6, shadow_size := 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	if shadow_size > 0:
		style.shadow_color = COLOR_SHADOW
		style.shadow_size = shadow_size
		style.shadow_offset = Vector2(4, 6)
	return style

static func make_button_style() -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_BTN_NORMAL
	normal.border_color = COLOR_BTN_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)

	var hover := StyleBoxFlat.new()
	hover.bg_color = COLOR_BTN_HOVER
	hover.border_color = COLOR_BTN_BORDER_BRIGHT
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)

	return {"normal": normal, "hover": hover}

static func make_close_button_style() -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_BTN_NORMAL
	normal.border_color = COLOR_BTN_BORDER_DIM
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)

	var hover := StyleBoxFlat.new()
	hover.bg_color = COLOR_BTN_HOVER_BRIGHT
	hover.border_color = COLOR_BTN_BORDER_BRIGHT
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)

	return {"normal": normal, "hover": hover}

static func make_disabled_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG_INK_DARK
	style.border_color = COLOR_BTN_BORDER_DIM
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

static func make_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG_INK_MID
	style.border_color = COLOR_BORDER_GOLD_DIM
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func apply_button_theme(button: Button, gold := true) -> void:
	var styles: Dictionary = make_button_style() if gold else make_close_button_style()
	button.add_theme_stylebox_override("normal", styles["normal"])
	button.add_theme_stylebox_override("hover", styles["hover"])
	if gold:
		button.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
	else:
		button.add_theme_color_override("font_color", COLOR_TEXT_GOLD)

static func apply_close_button_theme(button: Button) -> void:
	var styles := make_close_button_style()
	button.add_theme_stylebox_override("normal", styles["normal"])
	button.add_theme_stylebox_override("hover", styles["hover"])
	button.add_theme_color_override("font_color", COLOR_TEXT_GOLD)

static func anchor_full_rect(ctrl: Control) -> void:
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)

static func anchor_center(ctrl: Control) -> void:
	ctrl.set_anchors_preset(Control.PRESET_CENTER)

static func anchor_to_top_left(ctrl: Control, left := 24.0, top := 20.0) -> void:
	ctrl.anchor_left = 0.0
	ctrl.anchor_right = 0.0
	ctrl.anchor_top = 0.0
	ctrl.anchor_bottom = 0.0
	ctrl.offset_left = left
	ctrl.offset_top = top
	ctrl.grow_horizontal = Control.GROW_DIRECTION_END
	ctrl.grow_vertical = Control.GROW_DIRECTION_END

static func anchor_to_top_right(ctrl: Control, right := 24.0, top := 20.0) -> void:
	ctrl.anchor_left = 1.0
	ctrl.anchor_right = 1.0
	ctrl.anchor_top = 0.0
	ctrl.anchor_bottom = 0.0
	ctrl.offset_left = -right - ctrl.size.x
	ctrl.offset_right = -right
	ctrl.offset_top = top
	ctrl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ctrl.grow_vertical = Control.GROW_DIRECTION_END

static func anchor_to_bottom_left(ctrl: Control, left := 24.0, bottom := 24.0) -> void:
	ctrl.anchor_left = 0.0
	ctrl.anchor_right = 0.0
	ctrl.anchor_top = 1.0
	ctrl.anchor_bottom = 1.0
	ctrl.offset_left = left
	ctrl.offset_top = -bottom - ctrl.size.y
	ctrl.offset_bottom = -bottom
	ctrl.grow_horizontal = Control.GROW_DIRECTION_END
	ctrl.grow_vertical = Control.GROW_DIRECTION_BEGIN

static func anchor_to_bottom_full_width(ctrl: Control, left := 120.0, right := 120.0, top_offset := -180.0, bottom_offset := -20.0) -> void:
	ctrl.anchor_left = 0.0
	ctrl.anchor_right = 1.0
	ctrl.anchor_top = 1.0
	ctrl.anchor_bottom = 1.0
	ctrl.offset_left = left
	ctrl.offset_right = -right
	ctrl.offset_top = top_offset
	ctrl.offset_bottom = bottom_offset
