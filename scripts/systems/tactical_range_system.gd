extends RefCounted

# 战棋范围系统：移动范围（Dijkstra）/ 普攻范围 / 方向型技能范围。
# 约定：position = Vector2i(x, y)，terrain_grid[y][x]，棋盘 8 列 × 6 行。
# 调用前先 set_terrain_system 注入 TerrainSystem。

const GRID_COLS := 8
const GRID_ROWS := 6

var _terrain_system = null

func set_terrain_system(ts) -> void:
	_terrain_system = ts

# 移动范围：返回 Array[Vector2i]，从 unit.position 出发、累计移动消耗 ≤ unit.move 的所有可达格。
# 不含起点；树丛等不可通行地形与敌方占据格剔除。
func get_move_range(unit: Dictionary, terrain_grid: Array, enemy_positions: Array) -> Array:
	var src: Vector2i = unit.get("position", Vector2i(0, 0))
	var budget: int = int(unit.get("move", 0))
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
			if nb.x < 0 or nb.x >= GRID_COLS or nb.y < 0 or nb.y >= GRID_ROWS:
				continue
			if enemy_set.has(nb):
				continue
			var terrain_id: String = String(terrain_grid[nb.y][nb.x])
			if _terrain_system == null or not _terrain_system.is_passable(terrain_id):
				continue
			var step_cost: int = _terrain_system.get_move_cost(terrain_id)
			var new_d: int = cur_d + step_cost
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
func get_attack_range_simple(unit: Dictionary) -> Array:
	var src: Vector2i = unit.get("position", Vector2i(0, 0))
	var result: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nb: Vector2i = src + d
		if nb.x >= 0 and nb.x < GRID_COLS and nb.y >= 0 and nb.y < GRID_ROWS:
			result.append(nb)
	return result

# 方向型技能范围：从 unit.position 沿 direction 延伸 length 格。
# 当前仅 straight_sword_thrust（line_2，长度 2）；后续读招式数据扩展。
# 边界外的格被裁剪（不延伸到棋盘外，遇边界即停）。
func get_skill_directional_range(unit: Dictionary, skill_id: String, direction: Vector2i) -> Array:
	var length: int = _get_skill_line_length(skill_id)
	var src: Vector2i = unit.get("position", Vector2i(0, 0))
	var result: Array = []
	for i in range(1, length + 1):
		var nb: Vector2i = src + direction * i
		if nb.x < 0 or nb.x >= GRID_COLS or nb.y < 0 or nb.y >= GRID_ROWS:
			break
		result.append(nb)
	return result

func _get_skill_line_length(skill_id: String) -> int:
	# 当前硬编码 straight_sword_thrust = 2；Task 5 读 martial_arts.json 后改为按 shape 解析。
	if skill_id == "straight_sword_thrust":
		return 2
	return 1
