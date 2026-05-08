extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	var content = repository.load_all()

	assertions.assert_eq(content.get("actors", []).size(), 2, "应加载 2 个示例角色")
	assertions.assert_eq(repository.get_actor("hero_yun").get("name", ""), "云游少侠", "应按编号读取角色")
	assertions.assert_eq(repository.get_martial_art("basic_sword").get("name", ""), "基础剑法", "应按编号读取武学")
	assertions.assert_eq(repository.get_dialogue("intro_meet_master").get("title", ""), "初入江湖", "应按编号读取对话")
	assertions.assert_eq(repository.get_actor("missing_id"), {}, "缺失角色编号应返回空字典")
