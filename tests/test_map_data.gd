extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	var content = repository.load_all()

	assertions.assert_eq(content.get("maps", []).size(), 1, "应加载 1 张示例地图")

	var map = repository.get_map("mountain_pass")
	assertions.assert_eq(map.get("name", ""), "山道", "应按编号读取山道地图")
	assertions.assert_eq(map.get("spawn_position", {}).get("x", 0), 160, "山道出生点横坐标应正确")
	assertions.assert_eq(map.get("objects", []).size(), 2, "山道应配置 2 个交互对象")
	assertions.assert_eq(repository.get_actor("qingshanke").get("name", ""), "青衫客", "应读取青衫客角色")
	assertions.assert_eq(repository.get_quest("quest_mountain_trial").get("title", ""), "山道试剑", "应读取山道任务")
	assertions.assert_eq(repository.get_dialogue("mountain_pass_intro").get("title", ""), "山道初逢", "应读取山道对白")
	assertions.assert_eq(repository.get_map("missing_map"), {}, "缺失地图编号应返回空字典")

	repository.free()
