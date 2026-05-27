extends RefCounted

const MapIndexDocumentScript = preload("res://addons/map_preview/map_index_document.gd")

func run(assertions) -> void:
	_test_index_loads_maps_scene_paths_and_hash(assertions)
	_test_index_preserves_previous_data_when_text_invalid(assertions)
	_test_index_detects_external_file_changes(assertions)

func _test_index_loads_maps_scene_paths_and_hash(assertions) -> void:
	var document = MapIndexDocumentScript.new()
	var initial_text = JSON.stringify([
		{"id": "mountain_pass", "scene_path": "res://scenes/mountain_pass.tscn", "objects": [{"id": "npc_demo", "name": "演示 NPC"}]},
		{"id": "foot_village", "scene_path": "res://scenes/foot_village.tscn", "objects": []}
	], "\t")
	var changed_text = JSON.stringify([
		{"id": "mountain_pass", "scene_path": "res://scenes/mountain_pass.tscn", "objects": [{"id": "npc_demo", "name": "改名 NPC"}]},
		{"id": "foot_village", "scene_path": "res://scenes/foot_village.tscn", "objects": []}
	], "\t")

	assertions.assert_true(document.load_from_text(initial_text, "user://maps_index_test.json"), "地图索引应能从 JSON 数组文本加载")
	assertions.assert_eq(document.maps_by_id.size(), 2, "地图索引应保存两个地图")
	assertions.assert_eq(document.maps_by_id.get("mountain_pass", {}).get("scene_path", ""), "res://scenes/mountain_pass.tscn", "地图索引应按 map_id 保存地图")
	assertions.assert_eq(document.scene_path_to_map_id.get("res://scenes/foot_village.tscn", ""), "foot_village", "地图索引应保存 scene_path 到 map_id 的映射")
	assertions.assert_false(document.has_text_change(initial_text), "相同 data/maps.json 内容不应触发刷新")
	assertions.assert_true(document.has_text_change(changed_text), "内容变化应触发刷新")

func _test_index_preserves_previous_data_when_text_invalid(assertions) -> void:
	var document = MapIndexDocumentScript.new()
	var initial_text = JSON.stringify([
		{"id": "mountain_pass", "scene_path": "res://scenes/mountain_pass.tscn", "objects": []}
	], "\t")

	assertions.assert_true(document.load_from_text(initial_text, "user://maps_index_invalid_test.json"), "初始地图索引应加载成功")
	assertions.assert_false(document.load_from_text("{bad json", "user://maps_index_invalid_test.json"), "非法 JSON 不应加载成功")
	assertions.assert_eq(document.maps_by_id.size(), 1, "非法 JSON 时应保留上一份可用地图索引")
	assertions.assert_true(document.maps_by_id.has("mountain_pass"), "非法 JSON 时不应清空已有地图")
	assertions.assert_eq(document.last_error, "data/maps.json 必须是数组。", "非法 JSON 应记录可展示错误")

func _test_index_detects_external_file_changes(assertions) -> void:
	var path = "user://map_index_document_refresh_test.json"
	var initial_text = JSON.stringify([
		{"id": "mountain_pass", "scene_path": "res://scenes/mountain_pass.tscn", "objects": []}
	], "\t")
	var changed_text = JSON.stringify([
		{"id": "mountain_pass", "scene_path": "res://scenes/mountain_pass.tscn", "objects": [{"id": "npc_demo", "name": "演示 NPC"}]}
	], "\t")

	_write_text(path, initial_text)
	var document = MapIndexDocumentScript.new()
	assertions.assert_true(document.load_from_path(path), "地图索引应能从文件加载")
	assertions.assert_false(document.has_external_change(), "刚加载的文件不应报告外部变化")
	_write_text(path, changed_text)
	assertions.assert_true(document.has_external_change(), "文件内容变化后应报告外部变化")

func _write_text(path: String, text: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
