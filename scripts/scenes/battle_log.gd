extends PanelContainer

# Task 16: 右下「战斗日志」面板。
# 监听 EventBus.tactical_log_appended，append 一行 RichTextLabel，自动滚到底部。

const COLOR_PANEL := Color(0.06, 0.08, 0.10, 0.62)
const COLOR_BORDER := Color(0.84, 0.70, 0.36, 0.85)
const COLOR_TEXT_GOLD := Color(0.96, 0.84, 0.46)
const COLOR_TEXT := Color(0.92, 0.94, 0.96)
const MAX_LINES := 80  # 防止战斗冗长后无限增长

var _scroll: ScrollContainer
var _vbox: VBoxContainer
var _line_count: int = 0

func _ready() -> void:
	add_theme_stylebox_override("panel", _make_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var title := Label.new()
	title.text = "战斗日志"
	title.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
	title.add_theme_font_size_override("font_size", 14)
	box.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 200)
	box.add_child(_scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 2)
	_scroll.add_child(_vbox)

func append(line: String) -> void:
	if _vbox == null or line.is_empty():
		return
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("default_color", COLOR_TEXT)
	label.add_theme_font_size_override("normal_font_size", 12)
	label.text = line
	_vbox.add_child(label)
	_line_count += 1
	# 超过上限时丢弃最旧条目，保持滚动区域不无限膨胀。
	while _line_count > MAX_LINES and _vbox.get_child_count() > 0:
		var old = _vbox.get_child(0)
		_vbox.remove_child(old)
		old.queue_free()
		_line_count -= 1
	# 等待下一帧 layout 完成再滚到底部，否则 ScrollBar 还没拿到正确的 max_value。
	call_deferred("_scroll_to_bottom")

func clear() -> void:
	if _vbox == null:
		return
	for c in _vbox.get_children():
		c.queue_free()
	_line_count = 0

func _scroll_to_bottom() -> void:
	if _scroll == null:
		return
	var bar := _scroll.get_v_scroll_bar()
	if bar != null:
		_scroll.scroll_vertical = int(bar.max_value)

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
