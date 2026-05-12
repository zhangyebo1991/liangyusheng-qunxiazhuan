extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()

	var inn = repository.get_inn("foot_village_inn")
	assertions.assert_false(inn.is_empty(), "应能查到 foot_village_inn")
	assertions.assert_eq(str(inn.get("map_id", "")), "foot_village", "客栈应在 foot_village 地图")
	var spawn = inn.get("spawn_position", {})
	assertions.assert_eq(int(spawn.get("x", -1)), 760, "spawn x 应等于陆掌柜 x 坐标")
	assertions.assert_eq(int(spawn.get("y", -1)), 320, "spawn y 应等于陆掌柜 y 坐标")

	var inn_by_map = repository.get_inn_for_map("foot_village")
	assertions.assert_false(inn_by_map.is_empty(), "应能通过 map_id 反查客栈")
	assertions.assert_eq(str(inn_by_map.get("id", "")), "foot_village_inn", "反查应返回 foot_village_inn")

	var missing = repository.get_inn("not_exist")
	assertions.assert_true(missing.is_empty(), "不存在的客栈应返回空字典")
	var missing_map = repository.get_inn_for_map("mountain_pass")
	assertions.assert_true(missing_map.is_empty(), "mountain_pass 不应有客栈")
