extends Node2D

const TILE_SIZE := 32  # Kenney tile 16x16 放大 2x
const GRID_COLS := 8
const GRID_ROWS := 6
const TILES_DIR := "res://assets/kenney_tiny-battle/Tiles/"

var _terrain_grid: Array = []
var _terrain_system = null
var _tile_sprites: Dictionary = {}  # Vector2i → Sprite2D

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
			sprite.scale = Vector2(2, 2)
			sprite.position = Vector2(c * TILE_SIZE + TILE_SIZE / 2, r * TILE_SIZE + TILE_SIZE / 2)
			add_child(sprite)
			_tile_sprites[Vector2i(c, r)] = sprite

func grid_to_pixel(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2, cell.y * TILE_SIZE + TILE_SIZE / 2)
