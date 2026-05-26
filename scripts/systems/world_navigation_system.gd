extends RefCounted

# 大地图寻路系统
# 使用 AStar2D 实现基于网格的寻路

var astar = AStar2D.new()
var grid_step: int = 40
var map_size: Vector2 = Vector2.ZERO
var grid_width: int = 0
var grid_height: int = 0

# 初始化网格
func setup_grid(size: Vector2, step: int) -> void:
	map_size = size
	grid_step = step
	grid_width = int(size.x / step) + 1
	grid_height = int(size.y / step) + 1
	
	astar.clear()
	
	# 添加所有网格点
	for y in range(grid_height):
		for x in range(grid_width):
			var id = _get_id(x, y)
			var pos = Vector2(x * grid_step, y * grid_step)
			astar.add_point(id, pos)
	
	# 连接相邻网格点（8方向）
	for y in range(grid_height):
		for x in range(grid_width):
			var id = _get_id(x, y)
			
			# 右，下，右下，左下
			var neighbors = [
				Vector2i(x + 1, y),
				Vector2i(x, y + 1),
				Vector2i(x + 1, y + 1),
				Vector2i(x - 1, y + 1)
			]
			
			for n in neighbors:
				if n.x >= 0 and n.x < grid_width and n.y >= 0 and n.y < grid_height:
					var nid = _get_id(n.x, n.y)
					astar.connect_points(id, nid)

# 设置点是否可用（阻挡逻辑）
func set_point_disabled(world_pos: Vector2, disabled: bool) -> void:
	var coords = _world_to_grid(world_pos)
	if _is_in_bounds(coords.x, coords.y):
		var id = _get_id(coords.x, coords.y)
		astar.set_point_disabled(id, disabled)

# 获取寻路路径
func get_path_to_point(from: Vector2, to: Vector2) -> Array[Vector2]:
	var from_coords = _world_to_grid(from)
	var to_coords = _world_to_grid(to)
	
	if not _is_in_bounds(from_coords.x, from_coords.y) or not _is_in_bounds(to_coords.x, to_coords.y):
		return []
		
	var from_id = _get_id(from_coords.x, from_coords.y)
	var to_id = _get_id(to_coords.x, to_coords.y)
	
	var path_points = astar.get_point_path(from_id, to_id)
	var result: Array[Vector2] = []
	for p in path_points:
		result.append(p)
	return result

# 辅助方法
func _get_id(x: int, y: int) -> int:
	return y * grid_width + x

func _world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(round(world_pos.x / grid_step)),
		int(round(world_pos.y / grid_step))
	)

func _is_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < grid_width and y >= 0 and y < grid_height
