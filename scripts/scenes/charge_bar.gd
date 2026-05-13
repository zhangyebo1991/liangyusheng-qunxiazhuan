extends Control

# Task 13: 顶部集气进度条。
# 单位以 dict 提供：{unit_id, team, cur_charge, is_action, sprite_tile_id}
# x 偏移 = cur_charge / 1000 * bar_width；is_action=true 的单位高亮放大。

const TILES_DIR := "res://assets/kenney_tiny-battle/Tiles/"
const AVATAR_STEPS := 24

var bar_width: float = 800.0
var _units: Array = []
var _highlight: Dictionary = {}
var _secondary: Dictionary = {}
var _x_cache: Dictionary = {}
var _icon_cache: Dictionary = {}

func set_units(units: Array) -> void:
	_units = units
	_highlight.clear()
	_secondary.clear()
	_x_cache.clear()
	for u in units:
		var uid := str(u.get("unit_id", ""))
		var x: float = float(u.get("cur_charge", 0)) / 1000.0 * bar_width
		_x_cache[uid] = int(x)
		if bool(u.get("is_action", false)):
			_highlight[uid] = true
		elif bool(u.get("is_next_action", u.get("is_secondary", false))):
			_secondary[uid] = true
	queue_redraw()

func get_unit_x(uid: String) -> int:
	return int(_x_cache.get(uid, 0))

func is_highlighted(uid: String) -> bool:
	return _highlight.has(uid)

func is_secondary_highlighted(uid: String) -> bool:
	return _secondary.has(uid)

func _draw() -> void:
	# 底条
	draw_rect(Rect2(0, 16, bar_width, 4), Color(0.4, 0.4, 0.4))
	# 单位圆形徽章：优先绘制角色缩略图，没有贴图时回退颜色圆点。
	# 绘制顺序：先普通，再次高亮，最后当前行动主高亮，确保主高亮置顶。
	for u in _units:
		var uid := str(u.get("unit_id", ""))
		if is_highlighted(uid) or is_secondary_highlighted(uid):
			continue
		_draw_unit_badge(u)
	for u in _units:
		if not is_secondary_highlighted(str(u.get("unit_id", ""))):
			continue
		_draw_unit_badge(u)
	for u in _units:
		if not is_highlighted(str(u.get("unit_id", ""))):
			continue
		_draw_unit_badge(u)

func _draw_unit_badge(u: Dictionary) -> void:
	var uid := str(u.get("unit_id", ""))
	var x := get_unit_x(uid)
	var team := int(u.get("team", 0))
	var is_primary := is_highlighted(uid)
	var is_secondary := is_secondary_highlighted(uid) and not is_primary
	var ring_color := Color(0.28, 0.62, 1.0) if team == 0 else Color(1.0, 0.38, 0.38)
	var radius := 12.5 if is_primary else 9.5
	var center := Vector2(x, 18)

	draw_circle(center, radius + 1.8, ring_color)
	draw_circle(center, radius, Color(0.10, 0.10, 0.12, 0.95))

	var tile_id := str(u.get("sprite_tile_id", ""))
	var icon := _resolve_icon(tile_id)
	if icon != null:
		_draw_avatar_circle(center, radius * 0.90, icon)
	else:
		draw_circle(center, radius * 0.62, ring_color)

	if is_secondary:
		draw_circle(center, radius + 2.2, Color(0.88, 0.93, 1.0, 0.26), false, 1.4)

	if is_primary:
		draw_circle(center, radius + 3.0, Color(1.0, 0.93, 0.45, 0.35), false, 2.0)

func _resolve_icon(tile_id: String) -> Texture2D:
	if tile_id.is_empty():
		return null
	if _icon_cache.has(tile_id):
		return _icon_cache[tile_id]
	var tex_path := TILES_DIR + tile_id + ".png"
	if not ResourceLoader.exists(tex_path):
		_icon_cache[tile_id] = null
		return null
	var tex: Texture2D = load(tex_path)
	_icon_cache[tile_id] = tex
	return tex

func _draw_avatar_circle(center: Vector2, radius: float, texture: Texture2D) -> void:
	if texture == null or radius <= 0.0:
		return
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var crop_radius: float = 0.5
	var uv_center: Vector2 = Vector2(0.5, 0.5)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	for i in range(AVATAR_STEPS):
		var t := TAU * float(i) / float(AVATAR_STEPS)
		var dir := Vector2(cos(t), sin(t))
		pts.append(center + dir * radius)
		cols.append(Color(1, 1, 1, 1))
		uvs.append(uv_center + dir * crop_radius)
	draw_polygon(pts, cols, uvs, texture)
