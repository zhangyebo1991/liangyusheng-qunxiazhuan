extends RefCounted

const MapLayoutDocumentScript = preload("res://addons/map_preview/map_layout_document.gd")

func run(assertions) -> void:
	_test_document_updates_fields(assertions)
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
