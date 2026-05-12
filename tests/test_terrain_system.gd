extends RefCounted

const TerrainSystemScript = preload("res://scripts/systems/terrain_system.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repo = DataRepositoryScript.new()
	repo.load_all()
	var ts = TerrainSystemScript.new()
	ts.set_repository(repo)

	var grass = ts.get_terrain("grass")
	assertions.assert_eq(grass.get("name", ""), "草地", "草地名称应为「草地」")
	assertions.assert_true(ts.is_passable("grass"), "草地应可通行")
	assertions.assert_eq(ts.get_move_cost("grass"), 1, "草地移动消耗应为 1")

	assertions.assert_false(ts.is_passable("tree"), "树丛应不可通行")
	assertions.assert_eq(ts.get_move_cost("tree"), 99, "树丛移动消耗应为 99")
	assertions.assert_eq(ts.get_evasion_bonus("water"), -10, "浅水闪避加成应为 -10")
	assertions.assert_eq(ts.get_move_cost("bridge"), 1, "桥移动消耗应为 1")

	# 异常 ID 兜底
	assertions.assert_false(ts.is_passable("nonexistent"), "未知地形应不可通行（保守）")
	assertions.assert_eq(ts.get_move_cost("nonexistent"), 99, "未知地形移动消耗保守为 99")

	repo.free()
