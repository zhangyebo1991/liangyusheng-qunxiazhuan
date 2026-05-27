extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const MapLayoutLoaderScript = preload("res://scripts/systems/map_layout_loader.gd")

func run(assertions) -> void:
	_test_loader_reads_layout(assertions)
	_test_loader_merges_layout_into_map(assertions)
	_test_loader_preserves_missing_layout_fallback(assertions)
	_test_loader_reports_invalid_references(assertions)

func _test_loader_reads_layout(assertions) -> void:
	var loader = MapLayoutLoaderScript.new()
	var layout = loader.get_layout("mountain_pass")
	assertions.assert_eq(layout.get("map_id", ""), "mountain_pass", "布局加载器应读取山道布局")
	assertions.assert_eq(layout.get("size", {}).get("x", 0), 1280, "山道布局宽度应来自布局文件")
	assertions.assert_eq(layout.get("obstacles", []).size(), 6, "山道布局应包含 6 个矩形障碍")

func _test_loader_merges_layout_into_map(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var mountain = repository.get_map("mountain_pass")
	var qingshanke = _find_object(mountain, "npc_qingshanke")
	assertions.assert_eq(mountain.get("layout", {}).get("background", {}).get("color", ""), "#6f8f55", "地图记录应包含布局背景色")
	assertions.assert_eq(mountain.get("layout", {}).get("obstacles", []).size(), 6, "地图记录应包含布局障碍")
	assertions.assert_eq(qingshanke.get("position", {}).get("x", 0), 360, "对象横坐标应从布局合并")
	assertions.assert_eq(qingshanke.get("radius", 0), 72, "对象半径应从布局合并")

	var village = repository.get_map("foot_village")
	assertions.assert_eq(village.get("spawn_points", {}).get("return_from_world", {}).get("x", 0), 100, "出生点应从布局合并")

func _test_loader_preserves_missing_layout_fallback(assertions) -> void:
	var loader = MapLayoutLoaderScript.new()
	var source = {
		"id": "demo",
		"spawn_position": {"x": 10, "y": 20},
		"spawn_points": {"start": {"x": 10, "y": 20}},
		"objects": [
			{"id": "npc_demo", "type": "npc", "position": {"x": 30, "y": 40}, "radius": 55}
		]
	}
	var merged = loader.merge_map_layout(source, {})
	var npc = _find_object(merged, "npc_demo")
	assertions.assert_eq(npc.get("position", {}).get("x", 0), 30, "缺失布局时应保留原对象坐标")
	assertions.assert_eq(npc.get("radius", 0), 55, "缺失布局时应保留原对象半径")
	assertions.assert_eq(merged.get("layout", {}).get("obstacles", []).size(), 0, "缺失布局时应提供空障碍列表")

func _test_loader_reports_invalid_references(assertions) -> void:
	var loader = MapLayoutLoaderScript.new()
	var map_data = {"id": "demo", "objects": [{"id": "npc_demo", "type": "npc"}]}
	var layout = {
		"map_id": "demo",
		"size": {"x": 1280, "y": 720},
		"background": {"mode": "color", "color": "#ffffff"},
		"spawn_points": {},
		"obstacles": [
			{"id": "bad_obstacle", "shape": "rect", "rect": {"x": 0, "y": 0, "w": -1, "h": 20}}
		],
		"objects": {
			"missing_object": {"position": {"x": 1, "y": 2}, "radius": 48},
			"npc_demo": {"position": {"x": 1, "y": 2}, "radius": -3}
		}
	}
	var errors = loader.validate_layout(layout, map_data)
	assertions.assert_true(_has_error(errors, "missing_object"), "校验应报告不存在的对象编号")
	assertions.assert_true(_has_error(errors, "bad_obstacle"), "校验应报告非法障碍尺寸")
	assertions.assert_true(_has_error(errors, "npc_demo"), "校验应报告非法交互半径")

func _find_object(map_data: Dictionary, object_id: String) -> Dictionary:
	for object in map_data.get("objects", []):
		if str(object.get("id", "")) == object_id:
			return object
	return {}

func _has_error(errors: Array, needle: String) -> bool:
	for error in errors:
		if str(error).find(needle) >= 0:
			return true
	return false
