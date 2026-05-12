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
	_test_attack_range_simple(assertions, rs)
	_test_skill_directional_range(assertions, rs)
	_test_skill_target_selection_range(assertions, rs)
	_test_skill_target_blast_range(assertions, rs)

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

func _test_attack_range_simple(assertions, rs) -> void:
	# 中心 (3,3) 普攻应有 4 格
	var unit = {"position": Vector2i(3, 3)}
	var atk = rs.get_attack_range_simple(unit)
	assertions.assert_eq(atk.size(), 4, "中心普攻应有 4 格")
	assertions.assert_true(atk.has(Vector2i(4, 3)), "右侧应可攻")
	assertions.assert_true(atk.has(Vector2i(2, 3)), "左侧应可攻")
	assertions.assert_true(atk.has(Vector2i(3, 2)), "上方应可攻")
	assertions.assert_true(atk.has(Vector2i(3, 4)), "下方应可攻")

	# 角落 (0,0) 普攻只剩 2 格
	var unit_corner = {"position": Vector2i(0, 0)}
	var atk_corner = rs.get_attack_range_simple(unit_corner)
	assertions.assert_eq(atk_corner.size(), 2, "角落应只有 2 格")
	assertions.assert_true(atk_corner.has(Vector2i(1, 0)), "角落右侧应可攻")
	assertions.assert_true(atk_corner.has(Vector2i(0, 1)), "角落下方应可攻")

func _test_skill_directional_range(assertions, rs) -> void:
	# 直线剑招往右：(3,3) → (4,3) (5,3)
	var dir_range = rs.get_skill_directional_range({"position": Vector2i(3, 3)}, "straight_sword_thrust", Vector2i(1, 0))
	assertions.assert_eq(dir_range.size(), 2, "直线剑招应 2 格")
	assertions.assert_true(dir_range.has(Vector2i(4, 3)) and dir_range.has(Vector2i(5, 3)), "应是 (4,3) (5,3)")

	# 边界裁剪：(7,3) 往右 = 0 格
	var dir_edge = rs.get_skill_directional_range({"position": Vector2i(7, 3)}, "straight_sword_thrust", Vector2i(1, 0))
	assertions.assert_eq(dir_edge.size(), 0, "边缘往右应 0 格")

	# 往上：(3,3) → (3,2) (3,1)
	var dir_up = rs.get_skill_directional_range({"position": Vector2i(3, 3)}, "straight_sword_thrust", Vector2i(0, -1))
	assertions.assert_eq(dir_up.size(), 2, "往上应 2 格")
	assertions.assert_true(dir_up.has(Vector2i(3, 2)) and dir_up.has(Vector2i(3, 1)), "应是 (3,2) (3,1)")

	# 边缘部分裁剪：(6,3) 往右 = 仅 (7,3) 一格
	var dir_partial = rs.get_skill_directional_range({"position": Vector2i(6, 3)}, "straight_sword_thrust", Vector2i(1, 0))
	assertions.assert_eq(dir_partial.size(), 1, "边缘部分裁剪应 1 格")
	assertions.assert_true(dir_partial.has(Vector2i(7, 3)), "应是 (7,3)")

func _test_skill_target_selection_range(assertions, rs) -> void:
	# 剑气漩可选中心：主角 (3,3)，cast_range=3 → 曼哈顿距离 ≤ 3 但不含自身格
	var centers = rs.get_skill_target_selection_range({"position": Vector2i(3, 3)}, "sword_aura_swirl", 3)
	assertions.assert_false(centers.has(Vector2i(3, 3)), "主角自身格不应在可选中心")
	assertions.assert_true(centers.has(Vector2i(6, 3)), "(6,3) 距离 3 应可选")
	assertions.assert_true(centers.has(Vector2i(3, 0)), "(3,0) 距离 3 应可选")
	assertions.assert_false(centers.has(Vector2i(7, 3)), "(7,3) 距离 4 应不可选")
	assertions.assert_true(centers.has(Vector2i(2, 2)), "(2,2) 距离 2 应可选")

func _test_skill_target_blast_range(assertions, rs) -> void:
	# 十字命中：中心 (4,3) → 中心 + 上下左右 = 5 格
	var blast = rs.get_skill_target_blast_range("sword_aura_swirl", Vector2i(4, 3))
	assertions.assert_eq(blast.size(), 5, "中心十字应有 5 格")
	assertions.assert_true(blast.has(Vector2i(4, 3)), "应包含中心")
	assertions.assert_true(blast.has(Vector2i(4, 2)) and blast.has(Vector2i(4, 4)), "应包含上下相邻")
	assertions.assert_true(blast.has(Vector2i(3, 3)) and blast.has(Vector2i(5, 3)), "应包含左右相邻")

	# 边界裁剪：中心 (0,0) 十字仅剩 (0,0)+(1,0)+(0,1) = 3 格
	var blast_corner = rs.get_skill_target_blast_range("sword_aura_swirl", Vector2i(0, 0))
	assertions.assert_eq(blast_corner.size(), 3, "角落十字应 3 格")
	assertions.assert_true(blast_corner.has(Vector2i(0, 0)) and blast_corner.has(Vector2i(1, 0)) and blast_corner.has(Vector2i(0, 1)), "角落十字应剩中心+右+下")
