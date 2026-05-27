extends RefCounted

const MapLayoutDocumentScript = preload("res://addons/map_preview/map_layout_document.gd")

func run(assertions) -> void:
	_test_document_updates_fields(assertions)
	_test_document_adds_layout_elements(assertions)
	_test_document_rejects_duplicate_layout_ids(assertions)
	_test_document_rejects_invalid_layout_creates_without_mutation(assertions)
	_test_document_preserves_unknown_fields_on_save(assertions)
	_test_document_detects_external_changes(assertions)

func _test_document_updates_fields(assertions) -> void:
	var document = MapLayoutDocumentScript.new()
	document.load_from_data("demo", _sample_layout(), "user://demo_layout.json")
	document.update_object_position("npc_demo", Vector2(40, 50))
	document.update_object_radius("npc_demo", 88.0)
	document.update_spawn_position("start", Vector2(11, 22))
	document.update_obstacle_rect("wall", Rect2(1, 2, 3, 4))

	var layout = document.get_layout()
	assertions.assert_eq(layout.get("objects", {}).get("npc_demo", {}).get("position", {}).get("x", 0), 40.0, "文档应更新对象横坐标")
	assertions.assert_eq(layout.get("objects", {}).get("npc_demo", {}).get("radius", 0), 88.0, "文档应更新对象半径")
	assertions.assert_eq(layout.get("spawn_points", {}).get("start", {}).get("y", 0), 22.0, "文档应更新出生点坐标")
	var obstacles = layout.get("obstacles", [])
	if obstacles.size() > 0:
		assertions.assert_eq(obstacles[0].get("rect", {}).get("w", 0), 3.0, "文档应更新障碍宽度")
	else:
		assertions.assert_true(false, "文档应保留障碍列表")
	assertions.assert_true(document.is_dirty(), "字段修改后文档应为脏状态")

func _test_document_adds_layout_elements(assertions) -> void:
	var document = MapLayoutDocumentScript.new()
	document.load_from_data("demo", _sample_layout(), "user://demo_layout_add.json")

	var object_result = document.add_object_layout("npc_new", Vector2(70, 80), 64.0)
	var spawn_result = document.add_spawn_point("return", Vector2(12, 34))
	var obstacle_result = document.add_rect_obstacle("rock_new", Rect2(5, 6, 40, 50))

	assertions.assert_true(object_result.ok, "新增对象布局应成功")
	assertions.assert_true(spawn_result.ok, "新增出生点应成功")
	assertions.assert_true(obstacle_result.ok, "新增矩形障碍应成功")

	var layout = document.get_layout()
	assertions.assert_eq(layout.get("objects", {}).get("npc_new", {}).get("position", {}).get("x", 0), 70.0, "新增对象布局应写入横坐标")
	assertions.assert_eq(layout.get("objects", {}).get("npc_new", {}).get("radius", 0), 64.0, "新增对象布局应写入半径")
	assertions.assert_eq(layout.get("spawn_points", {}).get("return", {}).get("y", 0), 34.0, "新增出生点应写入坐标")
	var added_obstacle = _find_obstacle(layout, "rock_new")
	assertions.assert_eq(added_obstacle.get("rect", {}).get("w", 0), 40.0, "新增障碍应写入宽度")
	assertions.assert_true(document.is_dirty(), "新增布局元素后文档应为脏状态")

func _test_document_rejects_duplicate_layout_ids(assertions) -> void:
	var document = MapLayoutDocumentScript.new()
	document.load_from_data("demo", _sample_layout(), "user://demo_layout_duplicate.json")
	var before_counts = _layout_counts(document.get_layout())

	var object_result = document.add_object_layout("npc_demo", Vector2(1, 2), 48.0)
	var spawn_result = document.add_spawn_point("start", Vector2(1, 2))
	var obstacle_result = document.add_rect_obstacle("wall", Rect2(1, 2, 3, 4))

	assertions.assert_false(object_result.ok, "重复对象布局应被拒绝")
	assertions.assert_eq(object_result.error, "对象布局已存在：npc_demo", "重复对象布局应返回明确错误")
	assertions.assert_false(spawn_result.ok, "重复出生点应被拒绝")
	assertions.assert_eq(spawn_result.error, "出生点已存在：start", "重复出生点应返回明确错误")
	assertions.assert_false(obstacle_result.ok, "重复障碍应被拒绝")
	assertions.assert_eq(obstacle_result.error, "障碍编号已存在：wall", "重复障碍应返回明确错误")
	assertions.assert_eq(_layout_counts(document.get_layout()), before_counts, "重复新增不应改变布局数量")
	assertions.assert_false(document.is_dirty(), "重复新增不应标记文档为脏")

func _test_document_rejects_invalid_layout_creates_without_mutation(assertions) -> void:
	var document = MapLayoutDocumentScript.new()
	document.load_from_data("demo", _sample_layout(), "user://demo_layout_invalid.json")
	var before_counts = _layout_counts(document.get_layout())

	var empty_object = document.add_object_layout("", Vector2(1, 2), 48.0)
	var bad_radius = document.add_object_layout("npc_bad_radius", Vector2(1, 2), 0.0)
	var empty_spawn = document.add_spawn_point("", Vector2(1, 2))
	var empty_obstacle = document.add_rect_obstacle("", Rect2(1, 2, 3, 4))
	var bad_obstacle = document.add_rect_obstacle("bad_rect", Rect2(1, 2, 0, 4))

	assertions.assert_false(empty_object.ok, "空对象编号应被拒绝")
	assertions.assert_eq(empty_object.error, "请输入对象编号。", "空对象编号应返回明确错误")
	assertions.assert_false(bad_radius.ok, "非法对象半径应被拒绝")
	assertions.assert_eq(bad_radius.error, "对象半径必须为正数：npc_bad_radius", "非法对象半径应返回明确错误")
	assertions.assert_false(empty_spawn.ok, "空出生点编号应被拒绝")
	assertions.assert_eq(empty_spawn.error, "请输入出生点编号。", "空出生点编号应返回明确错误")
	assertions.assert_false(empty_obstacle.ok, "空障碍编号应被拒绝")
	assertions.assert_eq(empty_obstacle.error, "请输入障碍编号。", "空障碍编号应返回明确错误")
	assertions.assert_false(bad_obstacle.ok, "非法障碍尺寸应被拒绝")
	assertions.assert_eq(bad_obstacle.error, "矩形障碍尺寸必须为正数：bad_rect", "非法障碍尺寸应返回明确错误")
	assertions.assert_eq(_layout_counts(document.get_layout()), before_counts, "非法新增不应改变布局数量")
	assertions.assert_false(document.is_dirty(), "非法新增不应标记文档为脏")

func _test_document_preserves_unknown_fields_on_save(assertions) -> void:
	var path = "user://map_layout_document_save_test.json"
	var document = MapLayoutDocumentScript.new()
	var layout = _sample_layout()
	layout["custom_note"] = "保留此字段"
	document.load_from_data("demo", layout, path)
	document.update_object_position("npc_demo", Vector2(60, 70))
	assertions.assert_true(document.save(), "文档保存应成功")

	var loaded = document.load_json(path)
	assertions.assert_eq(loaded.get("custom_note", ""), "保留此字段", "保存时应保留未知字段")
	assertions.assert_eq(loaded.get("objects", {}).get("npc_demo", {}).get("position", {}).get("x", 0), 60.0, "保存文件应包含新坐标")
	assertions.assert_false(document.is_dirty(), "保存后文档不应为脏状态")

func _test_document_detects_external_changes(assertions) -> void:
	var path = "user://map_layout_document_conflict_test.json"
	var document = MapLayoutDocumentScript.new()
	document.load_from_data("demo", _sample_layout(), path)
	assertions.assert_true(document.save(), "初始保存应成功")
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"map_id": "demo", "external": true}, "\t"))
	file.close()
	assertions.assert_true(document.has_external_change(), "文件被外部改写后应检测到变化")

func _find_obstacle(layout: Dictionary, obstacle_id: String) -> Dictionary:
	for obstacle in layout.get("obstacles", []):
		if typeof(obstacle) == TYPE_DICTIONARY and str(obstacle.get("id", "")) == obstacle_id:
			return obstacle
	return {}

func _layout_counts(layout: Dictionary) -> Dictionary:
	return {
		"objects": layout.get("objects", {}).size(),
		"spawns": layout.get("spawn_points", {}).size(),
		"obstacles": layout.get("obstacles", []).size(),
	}

func _sample_layout() -> Dictionary:
	return {
		"map_id": "demo",
		"size": {"x": 100, "y": 100},
		"background": {"mode": "color", "color": "#ffffff"},
		"spawn_points": {"start": {"x": 1, "y": 2}},
		"obstacles": [{"id": "wall", "shape": "rect", "rect": {"x": 0, "y": 0, "w": 10, "h": 20}}],
		"objects": {"npc_demo": {"position": {"x": 3, "y": 4}, "radius": 48}},
		"decorations": []
	}
