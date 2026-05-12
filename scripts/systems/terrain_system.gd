extends RefCounted

# 地形系统：根据地形 ID 查询通行性 / 移动消耗 / 闪避加成 / 显示名 / tile 编号。
# 数据源由 DataRepository 提供，set_repository 后即可用。
# 未知地形 ID 一律返回保守默认值（不可通行 / 移动消耗 99 / 闪避 0）。

var _repo = null

func set_repository(repo) -> void:
	_repo = repo

func get_terrain(terrain_id: String) -> Dictionary:
	if _repo == null:
		return {}
	return _repo.get_terrain(terrain_id)

func get_move_cost(terrain_id: String) -> int:
	var t = get_terrain(terrain_id)
	return int(t.get("move_cost", 99))

func get_evasion_bonus(terrain_id: String) -> int:
	var t = get_terrain(terrain_id)
	return int(t.get("evasion_bonus", 0))

func is_passable(terrain_id: String) -> bool:
	var t = get_terrain(terrain_id)
	return bool(t.get("passable", false))

func get_name(terrain_id: String) -> String:
	var t = get_terrain(terrain_id)
	return String(t.get("name", "未知"))

func get_tile_id(terrain_id: String) -> String:
	var t = get_terrain(terrain_id)
	return String(t.get("tile_id", ""))
