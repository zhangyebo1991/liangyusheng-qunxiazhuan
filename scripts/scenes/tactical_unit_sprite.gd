extends Node2D

# 战棋单位精灵：像素 sprite + 头顶 HP 条 + 选中下方括号 + 当前行动倒三角
# 由 battle_screen 在 battle_grid 节点下创建，position 由 battle_grid.grid_to_pixel(cell) 决定。

# Task 19: 滑动动画完成后 emit；battle_screen 用 CONNECT_ONE_SHOT 接它再 commit move。
signal animation_finished

# v0.x: 战棋格显示尺寸固定为 80px，单位贴图按实际分辨率自适应缩放到该显示盒内。
const HP_BAR_WIDTH := 70
const HP_BAR_HEIGHT := 7
const SPRITE_DISPLAY_SIZE := Vector2(80, 80)
const TILES_DIR := "res://assets/kenney_tiny-battle/Tiles/"
const OVERLAY_Z_INDEX := 2000
const UNIT_BASE_Z_INDEX := 20
const FOOT_BASELINE_Y := 9.0
const SPRITE_OFFSET_X := - 5.0
const SHADOW_OFFSET_X := 0.0
const SHADOW_OFFSET_Y := - 1.0
const SHADOW_RADIUS_X := 20.0
const SHADOW_RADIUS_Y := 7.0
const SHADOW_ALPHA := 0.32

var unit_id: String = ""
var _sprite: Sprite2D
var _shadow: Polygon2D
var _is_selected := false
var _is_current := false
var _is_enemy := false
var _cur_hp := 0
var _max_hp := 1
var _target_hp := 0
var _display_hp := 0.0
var _hp_tween: Tween
var _hit_feedback_tween: Tween
var _opaque_bounds: Rect2i = Rect2i(0, 0, 16, 16)

func setup(uid: String, sprite_tile_id: String, max_hp: int, is_enemy: bool = false) -> void:
	unit_id = uid
	_is_enemy = is_enemy
	_max_hp = max(1, max_hp)
	_cur_hp = _max_hp
	_target_hp = _max_hp
	_display_hp = float(_max_hp)
	z_as_relative = false
	z_index = OVERLAY_Z_INDEX
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.z_as_relative = false
		add_child(_sprite)
	_ensure_shadow()
	var tex_path := TILES_DIR + sprite_tile_id + ".png"
	if sprite_tile_id != "" and ResourceLoader.exists(tex_path):
		_sprite.texture = load(tex_path)
	else:
		_sprite.texture = null
	_opaque_bounds = _compute_opaque_bounds(_sprite.texture)
	_sprite.scale = _scale_to_display_box(_sprite.texture)
	_sprite.z_index = UNIT_BASE_Z_INDEX
	_apply_sprite_layout()
	_update_shadow_layout()
	_update_shadow_z(_sprite.z_index)
	queue_redraw()

func set_world_sprite_z(z_value: int) -> void:
	if _sprite == null:
		return
	_sprite.z_as_relative = false
	_sprite.z_index = z_value
	_update_shadow_z(z_value)

func set_hp(cur: int, mx: int) -> void:
	var safe_max: int = max(1, mx)
	var new_hp: int = clamp(cur, 0, safe_max)
	var prev_target: int = _target_hp
	var hp_changed := new_hp != _target_hp
	var max_changed := safe_max != _max_hp
	_cur_hp = new_hp
	_max_hp = safe_max
	if not hp_changed and not max_changed:
		return
	_target_hp = new_hp
	if _hp_tween != null and _hp_tween.is_running():
		_hp_tween.kill()
	if hp_changed:
		if new_hp < prev_target:
			_spawn_damage_number(prev_target - new_hp)
		_hp_tween = create_tween()
		_hp_tween.tween_method(_set_display_hp, _display_hp, float(new_hp), 0.22)
	else:
		_display_hp = clamp(_display_hp, 0.0, float(_max_hp))
		queue_redraw()

func set_selected(s: bool) -> void:
	if _is_selected == s:
		return
	_is_selected = s
	queue_redraw()

func set_current_actor(c: bool) -> void:
	if _is_current == c:
		return
	_is_current = c
	queue_redraw()

func _draw() -> void:
	# HP 条：置于贴图顶部之上。角色脚底锚在格子中心后，贴图顶部会超出当前格。
	var sprite_top := _get_sprite_top_y()
	var bar_y := sprite_top - HP_BAR_HEIGHT - 4.0
	var bg_rect := Rect2(Vector2(-HP_BAR_WIDTH / 2.0, bar_y), Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT))
	draw_rect(bg_rect, Color(0.12, 0.12, 0.12, 0.92))
	var ratio: float = _display_hp / float(max(1, _max_hp))
	ratio = clamp(ratio, 0.0, 1.0)
	var fill_color := _pick_hp_fill_color(ratio)
	var fill_rect := Rect2(Vector2(-HP_BAR_WIDTH / 2.0, bar_y), Vector2(HP_BAR_WIDTH * ratio, HP_BAR_HEIGHT))
	draw_rect(fill_rect, fill_color)
	# HP 条边框
	draw_rect(bg_rect, Color(0, 0, 0, 0.85), false, 1.0)

	# 选中括号：脚下白色方括号
	if _is_selected:
		var col := Color(1, 1, 1, 0.95)
		var w := 3.0
		var bracket_bottom := _get_visual_foot_y()
		var bracket_top := bracket_bottom - 14.0
		# 左括号 ⌊
		draw_line(Vector2(-40, bracket_top), Vector2(-40, bracket_bottom), col, w)
		draw_line(Vector2(-40, bracket_bottom), Vector2(-26, bracket_bottom), col, w)
		# 右括号 ⌋
		draw_line(Vector2(40, bracket_top), Vector2(40, bracket_bottom), col, w)
		draw_line(Vector2(40, bracket_bottom), Vector2(26, bracket_bottom), col, w)

	# 倒三角：HP 条之上，表示当前行动单位
	if _is_current:
		var tri_top := bar_y - 18.0
		var tri := PackedVector2Array([
			Vector2(-12, tri_top),
			Vector2(12, tri_top),
			Vector2(0, tri_top + 12),
		])
		draw_colored_polygon(tri, Color(1, 0.88, 0.28))
		draw_polyline(PackedVector2Array([
			Vector2(-12, tri_top),
			Vector2(12, tri_top),
			Vector2(0, tri_top + 12),
			Vector2(-12, tri_top),
		]), Color(0.45, 0.32, 0.05), 1.5)

# Task 19: 用 Tween 平滑滑到目标 position；动画完毕 emit animation_finished。
# duration 至少 0.01s，避免 0 时长 Tween 被 Godot 视为非法。
func animate_to(target_position: Vector2, duration: float) -> void:
	var dur: float = max(0.01, duration)
	var tween := create_tween()
	tween.tween_property(self, "position", target_position, dur)
	tween.tween_callback(func() -> void: animation_finished.emit())

# v0.x: 按路径逐格滑动，避免从 A 直线跳到 B。
# points: Array[Vector2]（已转为像素坐标，不含起点）。任一点走完后 emit animation_finished。
func animate_along_path(points: Array, per_step_duration: float) -> void:
	if points.is_empty():
		animation_finished.emit()
		return
	var dur: float = max(0.01, per_step_duration)
	var tween := create_tween()
	for p in points:
		if typeof(p) == TYPE_VECTOR2:
			tween.tween_property(self, "position", p, dur)
	tween.tween_callback(func() -> void: animation_finished.emit())

# Task4: 受击反馈接口。短暂闪白并轻微回弹后归位。
# 约定：flash_sec<=0 时走同步归位分支，便于无帧推进的单测稳定验证。
func play_hit_feedback(flash_sec: float = 0.10, recoil_px: float = 6.0) -> void:
	if _sprite == null:
		return
	if _hit_feedback_tween != null and _hit_feedback_tween.is_running():
		_hit_feedback_tween.kill()

	_apply_sprite_layout()
	var base_pos: Vector2 = _sprite.position
	var base_modulate: Color = _sprite.modulate
	var safe_flash: float = max(0.0, flash_sec)
	var safe_recoil: float = max(0.0, recoil_px)

	if safe_flash <= 0.0 or get_tree() == null:
		_sprite.position = base_pos
		_sprite.modulate = base_modulate
		return

	var recoil_dir := -1.0
	if _is_enemy:
		recoil_dir = 1.0
	var recoil_pos: Vector2 = base_pos + Vector2(recoil_dir * safe_recoil, 0.0)
	var total_flash: float = max(0.02, safe_flash)
	var recoil_out: float = max(0.01, total_flash * 0.35)
	var recoil_back: float = max(0.01, total_flash - recoil_out)

	_sprite.modulate = Color(1.0, 1.0, 1.0, base_modulate.a)
	_hit_feedback_tween = create_tween()
	if safe_recoil > 0.0:
		_hit_feedback_tween.tween_property(_sprite, "position", recoil_pos, recoil_out)
		_hit_feedback_tween.tween_property(_sprite, "position", base_pos, recoil_back)
	else:
		_hit_feedback_tween.tween_interval(total_flash)
	_hit_feedback_tween.parallel().tween_property(_sprite, "modulate", base_modulate, total_flash)
	_hit_feedback_tween.tween_callback(func() -> void:
		if not is_instance_valid(_sprite):
			return
		_sprite.position = base_pos
		_sprite.modulate = base_modulate
	)

func _scale_to_display_box(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ONE
	var tex_size := texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return Vector2.ONE
	var scale_ratio: float = float(min(
		SPRITE_DISPLAY_SIZE.x / float(tex_size.x),
		SPRITE_DISPLAY_SIZE.y / float(tex_size.y)
	))
	return Vector2.ONE * scale_ratio

func _get_displayed_sprite_size() -> Vector2:
	if _sprite == null or _sprite.texture == null:
		return SPRITE_DISPLAY_SIZE
	var tex_size := _sprite.texture.get_size()
	return Vector2(tex_size.x * _sprite.scale.x, tex_size.y * _sprite.scale.y)

func _apply_sprite_layout() -> void:
	if _sprite == null:
		return
	var displayed: Vector2 = _get_displayed_sprite_size()
	var tex_h: float = 16.0
	if _sprite.texture != null:
		tex_h = float(_sprite.texture.get_size().y)
	var scale_y: float = displayed.y / float(max(1.0, tex_h))
	var opaque_bottom_px: float = float(_opaque_bounds.position.y + _opaque_bounds.size.y - 1)
	var local_bottom_y: float = (opaque_bottom_px - tex_h * 0.5) * scale_y
	# 用不透明像素底边对齐脚底基线，避免因透明留白造成浮空感。
	_sprite.position = Vector2(SPRITE_OFFSET_X, _get_visual_foot_y() - local_bottom_y)

func _ensure_shadow() -> void:
	if _shadow != null:
		return
	_shadow = Polygon2D.new()
	_shadow.z_as_relative = false
	_shadow.color = Color(0, 0, 0, SHADOW_ALPHA)
	_shadow.polygon = _build_ellipse_polygon(SHADOW_RADIUS_X, SHADOW_RADIUS_Y, 24)
	add_child(_shadow)

func _update_shadow_layout() -> void:
	if _shadow == null:
		return
	_shadow.position = Vector2(SHADOW_OFFSET_X, _get_visual_foot_y() + SHADOW_OFFSET_Y)

func _update_shadow_z(sprite_z: int) -> void:
	if _shadow == null:
		return
	_shadow.z_as_relative = false
	_shadow.z_index = sprite_z - 1

func _build_ellipse_polygon(rx: float, ry: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(max(8, steps)):
		var t := TAU * float(i) / float(max(8, steps))
		pts.append(Vector2(cos(t) * rx, sin(t) * ry))
	return pts

func _compute_opaque_bounds(texture: Texture2D) -> Rect2i:
	if texture == null:
		return Rect2i(0, 0, 16, 16)
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Rect2i(0, 0, int(texture.get_width()), int(texture.get_height()))
	var w := image.get_width()
	var h := image.get_height()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in range(h):
		for x in range(w):
			if image.get_pixel(x, y).a > 0.05:
				min_x = min(min_x, x)
				min_y = min(min_y, y)
				max_x = max(max_x, x)
				max_y = max(max_y, y)
	if max_x < 0 or max_y < 0:
		return Rect2i(0, 0, w, h)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _get_visual_foot_y() -> float:
	return FOOT_BASELINE_Y

func _set_display_hp(v: float) -> void:
	_display_hp = clamp(v, 0.0, float(_max_hp))
	queue_redraw()

func _pick_hp_fill_color(ratio: float) -> Color:
	if _is_enemy:
		if ratio < 0.3:
			return Color(0.70, 0.16, 0.16)
		if ratio < 0.6:
			return Color(0.82, 0.20, 0.20)
		return Color(0.92, 0.30, 0.30)
	if ratio < 0.3:
		return Color(0.9, 0.35, 0.35)
	if ratio < 0.6:
		return Color(0.95, 0.8, 0.35)
	return Color(0.45, 0.85, 0.45)

func _spawn_damage_number(damage: int) -> void:
	if damage <= 0:
		return
	var label := Label.new()
	label.text = "-%d" % damage
	label.add_theme_color_override("font_color", Color(1.0, 0.28, 0.24, 1.0))
	label.add_theme_font_size_override("font_size", 20)
	label.z_as_relative = false
	label.z_index = OVERLAY_Z_INDEX + 10
	label.position = Vector2(SPRITE_OFFSET_X - 16.0, _get_sprite_top_y() - 28.0)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -24), 0.42)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.42)
	tween.tween_callback(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)

func _get_sprite_top_y() -> float:
	var sprite_size := _get_displayed_sprite_size()
	if _sprite == null:
		return -sprite_size.y
	return _sprite.position.y - sprite_size.y * 0.5
