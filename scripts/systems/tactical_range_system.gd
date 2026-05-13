extends RefCounted

# 战棋范围系统：移动范围（Dijkstra）/ 普攻范围 / 方向型技能范围。
# 约定：position = Vector2i(x, y)，terrain_grid[y][x]，棋盘 8 列 × 6 行。
# 调用前先 set_terrain_system 注入 TerrainSystem。

const DEFAULT_GRID_COLS := 8
const DEFAULT_GRID_ROWS := 6

var _terrain_system = null

func set_terrain_system(ts) -> void:
	_terrain_system = ts

# 移动范围：返回 Array[Vector2i]，从 unit.position 出发、曼哈顿步数 ≤ unit.move 的所有可达格。
# 不含起点；树丛等不可通行地形与敌方占据格剔除。
# v0.x: 本作不采用「地形移动消耗」设定，所有可通行格 step_cost 拍死为 1。
func get_move_range(unit: Dictionary, terrain_grid: Array, enemy_positions: Array) -> Array:
	var src: Vector2i = unit.get("position", Vector2i(0, 0))
	var budget: int = int(unit.get("move", 0))
	var dims := _grid_dims(terrain_grid)
	var cols: int = dims.x
	var rows: int = dims.y
	var enemy_set: Dictionary = {}
	for p in enemy_positions:
		enemy_set[p] = true

	var dist: Dictionary = {src: 0}
	var frontier: Array = [src]
	while frontier.size() > 0:
		var cur: Vector2i = frontier.pop_front()
		var cur_d: int = int(dist[cur])
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + d
			if nb.x < 0 or nb.x >= cols or nb.y < 0 or nb.y >= rows:
				continue
			if enemy_set.has(nb):
				continue
			var terrain_id: String = String(terrain_grid[nb.y][nb.x])
			if _terrain_system == null or not _terrain_system.is_passable(terrain_id):
				continue
			var new_d: int = cur_d + 1  # v0.x: 拍死 1，不再读 _terrain_system.get_move_cost
			if new_d > budget:
				continue
			if dist.has(nb) and int(dist[nb]) <= new_d:
				continue
			dist[nb] = new_d
			frontier.append(nb)

	var result: Array = []
	for k in dist.keys():
		if k != src:
			result.append(k)
	return result

# 普攻范围：四向相邻 1 格，不考虑地形/敌我（命中判定在 combat_system 做）。
# 仅做棋盘边界裁剪。
func get_attack_range_simple(unit: Dictionary, terrain_grid: Array = []) -> Array:
	var src: Vector2i = unit.get("position", Vector2i(0, 0))
	var dims := _grid_dims(terrain_grid)
	var cols: int = dims.x
	var rows: int = dims.y
	var result: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nb: Vector2i = src + d
		if nb.x >= 0 and nb.x < cols and nb.y >= 0 and nb.y < rows:
			result.append(nb)
	return result

# 方向型技能范围：从 unit.position 沿 direction 延伸 length 格。
# 当前仅 straight_sword_thrust（line_2，长度 2）；后续读招式数据扩展。
# 边界外的格被裁剪（不延伸到棋盘外，遇边界即停）。
func get_skill_directional_range(unit: Dictionary, skill_id: String, direction: Vector2i, terrain_grid: Array = []) -> Array:
	var length: int = _get_skill_line_length(skill_id)
	var src: Vector2i = unit.get("position", Vector2i(0, 0))
	var dims := _grid_dims(terrain_grid)
	var cols: int = dims.x
	var rows: int = dims.y
	var result: Array = []
	for i in range(1, length + 1):
		var nb: Vector2i = src + direction * i
		if nb.x < 0 or nb.x >= cols or nb.y < 0 or nb.y >= rows:
			break
		result.append(nb)
	return result

func _get_skill_line_length(skill_id: String) -> int:
	# 当前硬编码 straight_sword_thrust = 2；Task 5 读 martial_arts.json 后改为按 shape 解析。
	if skill_id == "straight_sword_thrust":
		return 2
	return 1

# 目标型技能可选中心范围：返回 Array[Vector2i]，所有曼哈顿距离 ≤ cast_range 且
# 不含主角自身格、未越棋盘边界的格子。
# 当前不剔除盟友/敌方占据格（由 UI 层在选中时再行二次校验）。
func get_skill_target_selection_range(unit: Dictionary, skill_id: String, cast_range: int, terrain_grid: Array = []) -> Array:
	var src: Vector2i = unit.get("position", Vector2i(0, 0))
	var dims := _grid_dims(terrain_grid)
	var cols: int = dims.x
	var rows: int = dims.y
	var result: Array = []
	for r in range(rows):
		for c in range(cols):
			var p := Vector2i(c, r)
			if p == src:
				continue
			var dist: int = abs(p.x - src.x) + abs(p.y - src.y)
			if dist <= cast_range:
				result.append(p)
	return result

# 目标型技能命中范围（爆炸/扩散）：当前仅 target_cross_1 = 中心 + 上下左右四向 1 格。
# 边界外的格被裁剪。返回 Array[Vector2i]。
func get_skill_target_blast_range(skill_id: String, center: Vector2i, terrain_grid: Array = []) -> Array:
	var dims := _grid_dims(terrain_grid)
	var cols: int = dims.x
	var rows: int = dims.y
	var result: Array = []
	if center.x >= 0 and center.x < cols and center.y >= 0 and center.y < rows:
		result.append(center)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var p: Vector2i = center + d
		if p.x >= 0 and p.x < cols and p.y >= 0 and p.y < rows:
			result.append(p)
	return result

func _grid_dims(terrain_grid: Array) -> Vector2i:
	if typeof(terrain_grid) == TYPE_ARRAY and terrain_grid.size() > 0 and typeof(terrain_grid[0]) == TYPE_ARRAY and terrain_grid[0].size() > 0:
		return Vector2i(int(terrain_grid[0].size()), int(terrain_grid.size()))
	return Vector2i(DEFAULT_GRID_COLS, DEFAULT_GRID_ROWS)

# 扇形范围：从 unit.position 沿 direction 方向，夹角 ≤ 60 度（锥宽 120 度），
# 曼哈顿距离 ≤ range 的格子。不含自身格。棋盘边界裁剪。
func get_fan_range(unit: Dictionary, direction: Vector2i, range: int, terrain_grid: Array = []) -> Array:
	var src: Vector2i = unit.get("position", Vector2i(0, 0))
	var dims := _grid_dims(terrain_grid)
	var cols: int = dims.x
	var rows: int = dims.y
	var result: Array = []
	for r in range(rows):
		for c in range(cols):
			var p := Vector2i(c, r)
			if p == src:
				continue
			var dq: int = p.x - src.x
			var dr: int = p.y - src.y
			var dist: int = abs(dq) + abs(dr)
			if dist > range or dist <= 0:
				continue
			var proj: int = dq * direction.x + dr * direction.y
			if proj <= 0:
				continue
			var cross: int = abs(dq * direction.y - dr * direction.x)
			if cross > proj * 2:
				continue
			result.append(p)
	return result
