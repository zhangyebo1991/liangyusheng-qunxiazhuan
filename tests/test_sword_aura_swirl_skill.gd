extends RefCounted

# 剑气漩武学数据加载测试。
# 仅校验 martial_arts.json 顶层 shape / mp_cost / cast_range 等字段。
# 命中结算与战棋分支由 test_tactical_combat_system.gd 覆盖。

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repo = DataRepositoryScript.new()
	repo.load_all()

	var swirl = repo.get_martial_art("sword_aura_swirl")
	assertions.assert_eq(str(swirl.get("name", "")), "剑气漩", "剑气漩武学数据应加载")
	assertions.assert_eq(str(swirl.get("shape", "")), "target_cross_1", "剑气漩 shape 应为 target_cross_1")
	assertions.assert_eq(int(swirl.get("mp_cost", 0)), 8, "剑气漩 mp_cost 应为 8")
	assertions.assert_eq(int(swirl.get("cast_range", 0)), 3, "剑气漩 cast_range 应为 3")
	assertions.assert_eq(int(swirl.get("base_damage", 0)), 14, "剑气漩 base_damage 应为 14")
	assertions.assert_eq(str(swirl.get("scale_attr", "")), "atk", "剑气漩 scale_attr 应为 atk")

	var line = repo.get_martial_art("straight_sword_thrust")
	assertions.assert_eq(str(line.get("shape", "")), "line_2", "穿云刺顶层 shape 应为 line_2")

	repo.free()
