extends RefCounted

# 战棋范围系统测试：移动范围算法
# 约定：position = Vector2i(x, y)，terrain_grid[y][x]

const TacticalRangeSystemScript = preload("res://scripts/systems/tactical_range_system.gd")
const TerrainSystemScript = preload("res://scripts/systems/terrain_system.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repo = DataRepositoryScript.new()
	repo.load_all()
	var ts = TerrainSystemScript.new()
	ts.set_repository(repo)
	var rs = TacticalRangeSystemScript.new()
	rs.set_terrain_system(ts)

	_test_move_range_basic(assertions, rs)
	_test_move_range_tree_block(assertions, rs)
	_test_move_range_water_cost(assertions, rs)
	_test_move_range_enemy_block(assertions, rs)

func _make_grass_grid() -> Array:
	var grid: Array = []
	for r in range(6):
		var row: Array = []
		for c in range(8):
			row.append("grass")
		grid.append(row)
	return grid

func _test_move_range_basic(assertions, rs) -> void:
	var grid = _make_grass_grid()
	var unit = {"position": Vector2i(3, 3), "move": 3, "team": 0}
	var enemies: Array = [Vector2i(0, 0)]  # 远处敌人不阻挡
	var range_cells = rs.get_move_range(unit, grid, enemies)
	assertions.assert_true(range_cells.has(Vector2i(3, 4)), "(3,4) 距离 1 应可达")
	assertions.assert_true(range_cells.has(Vector2i(6, 3)), "(6,3) 距离 3 应可达")
	assertions.assert_false(range_cells.has(Vector2i(7, 3)), "(7,3) 距离 4 应不可达")
	assertions.assert_false(range_cells.has(Vector2i(3, 3)), "起点不应在结果中")

func _test_move_range_tree_block(assertions, rs) -> void:
	var grid = _make_grass_grid()
	grid[3][4] = "tree"  # Vector2i(4,3) 是树丛
	var unit = {"position": Vector2i(3, 3), "move": 3, "team": 0}
	var enemies: Array = []
	var range_cells = rs.get_move_range(unit, grid, enemies)
	assertions.assert_false(range_cells.has(Vector2i(4, 3)), "树丛格应被剔除")

func _test_move_range_water_cost(assertions, rs) -> void:
	var grid = _make_grass_grid()
	grid[3][4] = "water"  # Vector2i(4,3) 浅水，cost=2
	var unit = {"position": Vector2i(3, 3), "move": 3, "team": 0}
	var enemies: Array = []
	var range_cells = rs.get_move_range(unit, grid, enemies)
	assertions.assert_true(range_cells.has(Vector2i(4, 3)), "浅水可通过")
	assertions.assert_true(range_cells.has(Vector2i(5, 3)), "浅水后再走 1 步应可达")
	assertions.assert_false(range_cells.has(Vector2i(6, 3)), "浅水路径下 (6,3) 应不可达（cost 2+1+1=4>3）")

func _test_move_range_enemy_block(assertions, rs) -> void:
	var grid = _make_grass_grid()
	var unit = {"position": Vector2i(3, 3), "move": 3, "team": 0}
	var enemies: Array = [Vector2i(4, 3)]
	var range_cells = rs.get_move_range(unit, grid, enemies)
	assertions.assert_false(range_cells.has(Vector2i(4, 3)), "敌方格不可进入")
	# 敌方阻挡只挡那一格，不阻挡绕路
	assertions.assert_true(range_cells.has(Vector2i(2, 3)), "左侧不应受影响")
