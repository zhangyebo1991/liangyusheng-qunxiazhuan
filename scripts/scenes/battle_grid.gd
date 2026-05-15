extends Node2D

# v0.x: TILE_SIZE 80，8×6 棋盘 → 640×480，靠近「铺满」中部可用区。
const TILE_SIZE := 80
const GRID_COLS := 8
const GRID_ROWS := 6
const TILES_DIR := "res://assets/kenney_tiny-battle/Tiles/"

var _terrain_grid: Array = []
var _terrain_system = null
var _tile_sprites: Dictionary = {}  # Vector2i → Sprite2D
var _range_overlays: Array = []  # ColorRect 节点列表，用于范围三态可视化
var _hover_overlays: Array = []  # hover 爆炸预览层，叠加在 range_overlay 之上
var _range_mode: int = 0  # 当前范围模式（NONE=0/MOVE=1/ATTACK=2/SKILL_DIR=3/SKILL_TARGET=4）

func setup(terrain_grid: Array, terrain_system) -> void:
	_terrain_grid = terrain_grid
	_terrain_system = terrain_system
	_build_tiles()

func _build_tiles() -> void:
	for s in _tile_sprites.values():
		if is_instance_valid(s):
			s.queue_free()
	_tile_sprites.clear()
	if _terrain_system == null or typeof(_terrain_grid) != TYPE_ARRAY:
		return
	for r in range(_terrain_grid.size()):
		var row = _terrain_grid[r]
		if typeof(row) != TYPE_ARRAY:
			continue
		for c in range(row.size()):
			var terrain_id: String = str(row[c])
			var tile_id: String = str(_terrain_system.get_tile_id(terrain_id))
			if tile_id.is_empty():
				continue
			var tex_path: String = TILES_DIR + tile_id + ".png"
			if not ResourceLoader.exists(tex_path):
				continue
			var sprite := Sprite2D.new()
			sprite.texture = load(tex_path)
			sprite.scale = _scale_to_tile(sprite.texture)
			sprite.position = Vector2(c * TILE_SIZE + TILE_SIZE / 2, r * TILE_SIZE + TILE_SIZE / 2)
			add_child(sprite)
			_tile_sprites[Vector2i(c, r)] = sprite

func grid_to_pixel(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2, cell.y * TILE_SIZE + TILE_SIZE / 2)

func _scale_to_tile(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ONE
	var tex_size := texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return Vector2.ONE
	return Vector2(TILE_SIZE / float(tex_size.x), TILE_SIZE / float(tex_size.y))

# Task 11: 范围 overlay。mode = 0 清空；其余按颜色绘制半透明覆盖。
# MOVE = 蓝半透；ATTACK / SKILL_DIR / SKILL_TARGET = 红半透。
func set_range_overlay(mode: int, cells: Array) -> void:
	for n in _range_overlays:
		if is_instance_valid(n):
			n.queue_free()
	_range_overlays.clear()
	_range_mode = int(mode)
	if _range_mode == 0:
		return
	var color: Color
	if _range_mode == 1:
		color = Color(0.25, 0.55, 1.0, 0.35)
	else:
		color = Color(1.0, 0.3, 0.3, 0.35)
	for c in cells:
		if typeof(c) != TYPE_VECTOR2I:
			continue
		var rect := ColorRect.new()
		rect.color = color
		rect.size = Vector2(TILE_SIZE, TILE_SIZE)
		rect.position = Vector2(c.x * TILE_SIZE, c.y * TILE_SIZE)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_range_overlays.append(rect)

# hover 爆炸预览层：独立于 range_overlay，红色半透，叠加在最前。
func set_hover_overlay(cells: Array) -> void:
	clear_hover_overlay()
	var color := Color(1.0, 0.25, 0.25, 0.42)
	for c in cells:
		if typeof(c) != TYPE_VECTOR2I:
			continue
		var rect := ColorRect.new()
		rect.color = color
		rect.size = Vector2(TILE_SIZE, TILE_SIZE)
		rect.position = Vector2(c.x * TILE_SIZE, c.y * TILE_SIZE)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_hover_overlays.append(rect)

func clear_hover_overlay() -> void:
	for n in _hover_overlays:
		if is_instance_valid(n):
			n.queue_free()
	_hover_overlays.clear()
