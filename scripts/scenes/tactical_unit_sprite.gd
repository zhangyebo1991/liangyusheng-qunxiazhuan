extends Node2D

# 战棋单位精灵：像素 sprite + 头顶 HP 条 + 选中下方括号 + 当前行动倒三角
# 由 battle_screen 在 battle_grid 节点下创建，position 由 battle_grid.grid_to_pixel(cell) 决定。

# Task 19: 滑动动画完成后 emit；battle_screen 用 CONNECT_ONE_SHOT 接它再 commit move。
signal animation_finished

const HP_BAR_WIDTH := 28
const HP_BAR_HEIGHT := 4
const TILES_DIR := "res://assets/kenney_tiny-battle/Tiles/"

var unit_id: String = ""
var _sprite: Sprite2D
var _is_selected := false
var _is_current := false
var _cur_hp := 0
var _max_hp := 1

func setup(uid: String, sprite_tile_id: String, max_hp: int) -> void:
	unit_id = uid
	_max_hp = max(1, max_hp)
	_cur_hp = _max_hp
	if _sprite == null:
		_sprite = Sprite2D.new()
		add_child(_sprite)
	var tex_path := TILES_DIR + sprite_tile_id + ".png"
	if sprite_tile_id != "" and ResourceLoader.exists(tex_path):
		_sprite.texture = load(tex_path)
	_sprite.scale = Vector2(2, 2)
	queue_redraw()

func set_hp(cur: int, mx: int) -> void:
	_cur_hp = max(0, cur)
	_max_hp = max(1, mx)
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
	# HP 条：sprite 上方
	var bar_y := -22.0
	var bg_rect := Rect2(Vector2(-HP_BAR_WIDTH / 2.0, bar_y), Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT))
	draw_rect(bg_rect, Color(0.12, 0.12, 0.12, 0.92))
	var ratio: float = float(_cur_hp) / float(max(1, _max_hp))
	ratio = clamp(ratio, 0.0, 1.0)
	var fill_color := Color(0.45, 0.85, 0.45)
	if ratio < 0.3:
		fill_color = Color(0.9, 0.35, 0.35)
	elif ratio < 0.6:
		fill_color = Color(0.95, 0.8, 0.35)
	var fill_rect := Rect2(Vector2(-HP_BAR_WIDTH / 2.0, bar_y), Vector2(HP_BAR_WIDTH * ratio, HP_BAR_HEIGHT))
	draw_rect(fill_rect, fill_color)
	# HP 条边框
	draw_rect(bg_rect, Color(0, 0, 0, 0.85), false, 1.0)

	# 选中括号：脚下白色方括号
	if _is_selected:
		var col := Color(1, 1, 1, 0.95)
		var w := 2.0
		# 左括号 ⌊
		draw_line(Vector2(-16, 12), Vector2(-16, 18), col, w)
		draw_line(Vector2(-16, 18), Vector2(-10, 18), col, w)
		# 右括号 ⌋
		draw_line(Vector2(16, 12), Vector2(16, 18), col, w)
		draw_line(Vector2(16, 18), Vector2(10, 18), col, w)

	# 倒三角：sprite 上方（在 HP 条之上），表示当前行动单位
	if _is_current:
		var tri := PackedVector2Array([
			Vector2(-6, -34),
			Vector2(6, -34),
			Vector2(0, -26),
		])
		draw_colored_polygon(tri, Color(1, 0.88, 0.28))
		draw_polyline(PackedVector2Array([
			Vector2(-6, -34),
			Vector2(6, -34),
			Vector2(0, -26),
			Vector2(-6, -34),
		]), Color(0.45, 0.32, 0.05), 1.0)

# Task 19: 用 Tween 平滑滑到目标 position；动画完毕 emit animation_finished。
# duration 至少 0.01s，避免 0 时长 Tween 被 Godot 视为非法。
func animate_to(target_position: Vector2, duration: float) -> void:
	var dur: float = max(0.01, duration)
	var tween := create_tween()
	tween.tween_property(self, "position", target_position, dur)
	tween.tween_callback(func() -> void: animation_finished.emit())
