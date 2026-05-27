extends RefCounted

const MapContentDocumentScript = preload("res://addons/map_preview/map_content_document.gd")

func run(assertions) -> void:
	_test_load_indexes_maps_and_preserves_unknown_fields(assertions)
	_test_add_object_template_marks_dirty_and_updates_index(assertions)
	_test_add_object_rejects_duplicate_id(assertions)
	_test_update_object_fields_preserves_existing_fields(assertions)
	_test_save_preserves_other_maps_and_clears_dirty(assertions)
	_test_detects_external_changes(assertions)

func _test_load_indexes_maps_and_preserves_unknown_fields(assertions) -> void:
	var document = MapContentDocumentScript.new()
	var text = JSON.stringify([
		{
			"id": "mountain_pass",
			"scene_path": "res://scenes/mountain_pass.tscn",
			"custom_field": "保留",
			"objects": [{"id": "npc_demo", "type": "npc", "name": "演示"}]
		},
		{"id": "foot_village", "scene_path": "res://scenes/foot_village.tscn", "objects": []}
	], "\t")

	assertions.assert_true(document.load_from_text(text, "user://map_content_document_load.json"), "内容文档应能加载地图数组")
	assertions.assert_eq(document.maps_by_id.size(), 2, "内容文档应索引地图编号")
	assertions.assert_eq(document.scene_path_to_map_id.get("res://scenes/foot_village.tscn", ""), "foot_village", "内容文档应索引 scene_path")
	assertions.assert_eq(document.maps_by_id.get("mountain_pass", {}).get("custom_field", ""), "保留", "内容文档应保留未知字段")
	assertions.assert_false(document.is_dirty(), "刚加载的内容文档不应为脏状态")

func _test_add_object_template_marks_dirty_and_updates_index(assertions) -> void:
	var document = MapContentDocumentScript.new()
	document.load_from_text(JSON.stringify([_sample_map()], "\t"), "user://map_content_document_add.json")
	var result = document.add_object_to_map("mountain_pass", {
		"id": "npc_new",
		"type": "npc",
		"name": "新人物",
		"dialogue_id": "dialogue_npc_new"
	})

	assertions.assert_true(result.ok, "新增对象模板应成功")
	var object = document.find_object("mountain_pass", "npc_new")
	assertions.assert_eq(object.get("type", ""), "npc", "新增对象应写入类型")
	assertions.assert_eq(object.get("dialogue_id", ""), "dialogue_npc_new", "NPC 模板应写入 dialogue_id")
	assertions.assert_true(document.is_dirty(), "新增对象后内容文档应为脏状态")

func _test_add_object_rejects_duplicate_id(assertions) -> void:
	var document = MapContentDocumentScript.new()
	document.load_from_text(JSON.stringify([_sample_map()], "\t"), "user://map_content_document_duplicate.json")
	var result = document.add_object_to_map("mountain_pass", {"id": "npc_demo", "type": "npc", "name": "重复"})

	assertions.assert_false(result.ok, "重复对象编号应被拒绝")
	assertions.assert_eq(result.error, "对象编号已存在：npc_demo", "重复对象编号应返回明确错误")

func _test_update_object_fields_preserves_existing_fields(assertions) -> void:
	var document = MapContentDocumentScript.new()
	document.load_from_text(JSON.stringify([_sample_map()], "\t"), "user://map_content_document_update.json")
	var result = document.update_object_fields("mountain_pass", "npc_demo", {"name": "改名", "type": "notice"})

	assertions.assert_true(result.ok, "更新对象字段应成功")
	var object = document.find_object("mountain_pass", "npc_demo")
	assertions.assert_eq(object.get("name", ""), "改名", "对象名称应更新")
	assertions.assert_eq(object.get("type", ""), "notice", "对象类型应更新")
	assertions.assert_eq(object.get("dialogue_id", ""), "dialogue_demo", "未修改字段应保留")

func _test_save_preserves_other_maps_and_clears_dirty(assertions) -> void:
	var path = "user://map_content_document_save.json"
	var document = MapContentDocumentScript.new()
	document.load_from_text(JSON.stringify([
		_sample_map(),
		{"id": "foot_village", "scene_path": "res://scenes/foot_village.tscn", "objects": [], "custom": "村镇"}
	], "\t"), path)
	document.add_object_to_map("mountain_pass", {"id": "exit_new", "type": "exit", "name": "新出口"})

	assertions.assert_true(document.save(), "保存内容文档应成功")
	assertions.assert_false(document.is_dirty(), "保存后内容文档不应为脏状态")

	var loaded = JSON.parse_string(FileAccess.get_file_as_string(path))
	assertions.assert_eq(loaded.size(), 2, "保存时应保留其他地图")
	assertions.assert_eq(loaded[1].get("custom", ""), "村镇", "保存时应保留其他地图未知字段")

func _test_detects_external_changes(assertions) -> void:
	var path = "user://map_content_document_external.json"
	var document = MapContentDocumentScript.new()
	document.load_from_text(JSON.stringify([_sample_map()], "\t"), path)
	assertions.assert_true(document.save(), "初始保存应成功")
	assertions.assert_false(document.has_external_change(), "刚保存的内容不应有外部变化")

	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify([{"id": "mountain_pass", "objects": [{"id": "npc_external"}]}], "\t"))
	file.close()
	assertions.assert_true(document.has_external_change(), "外部写入后应检测到变化")

func _sample_map() -> Dictionary:
	return {
		"id": "mountain_pass",
		"scene_path": "res://scenes/mountain_pass.tscn",
		"objects": [
			{"id": "npc_demo", "type": "npc", "name": "演示", "dialogue_id": "dialogue_demo"}
		]
	}
