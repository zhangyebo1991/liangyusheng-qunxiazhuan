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
const COLOR_HEALTH_LOW := Color(1.0, 0.35, 0.30, 1.0)

const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.65)

const COLOR_BTN_NORMAL := Color(0.18, 0.10, 0.04, 1.0)
const COLOR_BTN_HOVER := Color(0.32, 0.18, 0.04, 1.0)
const COLOR_BTN_HOVER_BRIGHT := Color(0.38, 0.22, 0.04, 1.0)
const COLOR_BTN_BORDER := Color(0.65, 0.50, 0.15, 0.9)
const COLOR_BTN_BORDER_BRIGHT := Color(0.85, 0.65, 0.22, 1.0)
const COLOR_BTN_BORDER_DIM := Color(0.30, 0.25, 0.10, 0.5)

const COLOR_SEPARATOR := Color(0.72, 0.56, 0.18, 0.55)

# 战术格子指示色
const COLOR_GRID_IDLE_FILL := Color(0.18, 0.24, 0.18, 0.10)
const COLOR_GRID_IDLE_BORDER := Color(0.72, 0.84, 0.62, 0.25)
const COLOR_GRID_ACTIVE_FILL := Color(0.22, 0.48, 0.74, 0.24)
const COLOR_GRID_ACTIVE_BORDER := Color(0.36, 0.66, 0.95, 0.70)
const COLOR_GRID_PRESSED_FILL := Color(0.28, 0.58, 0.84, 0.36)
const COLOR_GRID_PRESSED_BORDER := Color(0.62, 0.82, 1.0, 0.85)
const COLOR_GRID_FOCUS_BORDER := Color(0.92, 0.76, 0.30, 0.90)

# 布局常量
const SIDE_MARGIN := 120.0
const PANEL_SIDE_WIDTH := 200
const PANEL_SIDE_OBJECTIVE_HEIGHT := 180
const PANEL_SIDE_LOG_HEIGHT := 230
const PANEL_SIDE_ACTOR_HEIGHT := 240

# Z-index 层级
const Z_LAYER_BG := -1
const Z_LAYER_UI_BASE := 0
const Z_LAYER_UI_POPUP := 200
const Z_LAYER_UI_FEEDBACK := 2600

# 字体大小
const FONT_SIZE_TITLE := 18
const FONT_SIZE_NORMAL := 15
const FONT_SIZE_SMALL := 13
const FONT_SIZE_LARGE := 36

# 缓存（首次调用时创建，后续复用）
static var _cached_gold_panel: StyleBoxFlat = null
static var _cached_button_styles: Dictionary = {}
static var _cached_close_button_styles: Dictionary = {}
static var _cached_disabled_style: StyleBoxFlat = null
static var _cached_card_style: StyleBoxFlat = null

static func make_gold_panel(corner_radius := 6, shadow_size := 10) -> StyleBoxFlat:
	if _cached_gold_panel == null and corner_radius == 6 and shadow_size == 10:
		_cached_gold_panel = _create_gold_panel(corner_radius, shadow_size)
		return _cached_gold_panel
	if corner_radius == 6 and shadow_size == 10 and _cached_gold_panel != null:
		return _cached_gold_panel
	return _create_gold_panel(corner_radius, shadow_size)

static func _create_gold_panel(corner_radius: int, shadow_size: int) -> StyleBoxFlat:
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
	if _cached_button_styles.is_empty():
		_cached_button_styles = _create_button_style(COLOR_BTN_NORMAL, COLOR_BTN_BORDER, COLOR_BTN_HOVER, COLOR_BTN_BORDER_BRIGHT)
	return _cached_button_styles

static func make_close_button_style() -> Dictionary:
	if _cached_close_button_styles.is_empty():
		_cached_close_button_styles = _create_button_style(COLOR_BTN_NORMAL, COLOR_BTN_BORDER_DIM, COLOR_BTN_HOVER_BRIGHT, COLOR_BTN_BORDER_BRIGHT)
	return _cached_close_button_styles

static func _create_button_style(normal_bg: Color, normal_border: Color, hover_bg: Color, hover_border: Color) -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = normal_bg
	normal.border_color = normal_border
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)

	var hover := StyleBoxFlat.new()
	hover.bg_color = hover_bg
	hover.border_color = hover_border
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)

	return {"normal": normal, "hover": hover}

static func make_disabled_button_style() -> StyleBoxFlat:
	if _cached_disabled_style == null:
		_cached_disabled_style = StyleBoxFlat.new()
		_cached_disabled_style.bg_color = COLOR_BG_INK_DARK
		_cached_disabled_style.border_color = COLOR_BTN_BORDER_DIM
		_cached_disabled_style.set_border_width_all(1)
		_cached_disabled_style.set_corner_radius_all(4)
	return _cached_disabled_style

static func make_card_style() -> StyleBoxFlat:
	if _cached_card_style == null:
		_cached_card_style = StyleBoxFlat.new()
		_cached_card_style.bg_color = COLOR_BG_INK_MID
		_cached_card_style.border_color = COLOR_BORDER_GOLD_DIM
		_cached_card_style.set_border_width_all(1)
		_cached_card_style.set_corner_radius_all(4)
		_cached_card_style.content_margin_left = 10
		_cached_card_style.content_margin_right = 10
		_cached_card_style.content_margin_top = 8
		_cached_card_style.content_margin_bottom = 8
	return _cached_card_style

static func apply_button_theme(button: Button, gold := true) -> void:
	var styles: Dictionary = make_button_style() if gold else make_close_button_style()
	button.add_theme_stylebox_override("normal", styles["normal"])
	button.add_theme_stylebox_override("hover", styles["hover"])
	button.add_theme_color_override("font_color", COLOR_TEXT_GOLD)

static func apply_close_button_theme(button: Button) -> void:
	var styles := make_close_button_style()
	button.add_theme_stylebox_override("normal", styles["normal"])
	button.add_theme_stylebox_override("hover", styles["hover"])
	button.add_theme_color_override("font_color", COLOR_TEXT_GOLD)

static func make_grid_focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = COLOR_GRID_FOCUS_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	return style

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
