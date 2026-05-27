extends RefCounted

const MAP_LAYOUTS_DIR := "res://data/map_layouts"

func get_layout(map_id: String) -> Dictionary:
	if map_id.is_empty():
		return {}
	return _load_json_dictionary("%s/%s.json" % [MAP_LAYOUTS_DIR, map_id])

func merge_map_layout(map_data: Dictionary, layout: Dictionary) -> Dictionary:
	var merged = map_data.duplicate(true)
	var normalized_layout = _normalized_layout(layout)
	merged["layout"] = normalized_layout
	if not normalized_layout.is_empty():
		if normalized_layout.has("spawn_points"):
			merged["spawn_points"] = normalized_layout.get("spawn_points", {}).duplicate(true)
		_merge_object_layouts(merged, normalized_layout.get("objects", {}))
	return merged

func validate_layout(layout: Dictionary, map_data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var map_id = str(map_data.get("id", ""))
	var layout_map_id = str(layout.get("map_id", ""))
	if not map_id.is_empty() and not layout_map_id.is_empty() and map_id != layout_map_id:
		errors.append("布局 map_id 与地图编号不一致：%s != %s" % [layout_map_id, map_id])

	var size = layout.get("size", {})
	if typeof(size) != TYPE_DICTIONARY or float(size.get("x", 0.0)) <= 0.0 or float(size.get("y", 0.0)) <= 0.0:
		errors.append("布局尺寸必须包含正数 x/y：%s" % layout_map_id)

	var background = layout.get("background", {})
	if typeof(background) == TYPE_DICTIONARY and str(background.get("mode", "color")) == "color":
		var color = str(background.get("color", ""))
		if color.is_empty() or not Color.html_is_valid(color):
			errors.append("背景颜色格式非法：%s" % color)

	var valid_object_ids := {}
	for object in map_data.get("objects", []):
		if typeof(object) == TYPE_DICTIONARY:
			valid_object_ids[str(object.get("id", ""))] = true

	var object_layouts = layout.get("objects", {})
	if typeof(object_layouts) == TYPE_DICTIONARY:
		for object_id in object_layouts.keys():
			if not valid_object_ids.has(str(object_id)):
				errors.append("布局引用了不存在的对象：%s" % object_id)
			var object_layout = object_layouts[object_id]
			if typeof(object_layout) != TYPE_DICTIONARY:
				errors.append("对象布局必须是字典：%s" % object_id)
				continue
			if object_layout.has("radius") and float(object_layout.get("radius", 0.0)) <= 0.0:
				errors.append("对象半径必须为正数：%s" % object_id)
			if object_layout.has("position") and not _is_valid_position(object_layout.get("position", {})):
				errors.append("对象坐标必须包含数字 x/y：%s" % object_id)

	for obstacle in layout.get("obstacles", []):
		if typeof(obstacle) != TYPE_DICTIONARY:
			errors.append("障碍物必须是字典")
			continue
		var obstacle_id = str(obstacle.get("id", ""))
		if str(obstacle.get("shape", "rect")) != "rect":
			errors.append("第一版只支持 rect 障碍物：%s" % obstacle_id)
			continue
		var rect = obstacle.get("rect", {})
		if typeof(rect) != TYPE_DICTIONARY or float(rect.get("w", 0.0)) <= 0.0 or float(rect.get("h", 0.0)) <= 0.0:
			errors.append("矩形障碍尺寸必须为正数：%s" % obstacle_id)
	return errors

func _merge_object_layouts(map_data: Dictionary, object_layouts: Dictionary) -> void:
	if object_layouts.is_empty():
		return
	var objects = map_data.get("objects", [])
	if typeof(objects) != TYPE_ARRAY:
		return
	for index in range(objects.size()):
		var object = objects[index]
		if typeof(object) != TYPE_DICTIONARY:
			continue
		var object_id = str(object.get("id", ""))
		if object_id.is_empty() or not object_layouts.has(object_id):
			continue
		var object_layout = object_layouts[object_id]
		if typeof(object_layout) != TYPE_DICTIONARY:
			continue
		var copy = object.duplicate(true)
		if object_layout.has("position"):
			copy["position"] = object_layout.get("position", {}).duplicate(true)
		if object_layout.has("radius"):
			copy["radius"] = float(object_layout.get("radius", copy.get("radius", 48.0)))
		objects[index] = copy
	map_data["objects"] = objects

func _normalized_layout(layout: Dictionary) -> Dictionary:
	if layout.is_empty():
		return {
			"size": {"x": 1280, "y": 720},
			"background": {"mode": "color", "color": "#6f8f55"},
			"spawn_points": {},
			"obstacles": [],
			"objects": {},
			"decorations": [],
		}
	var copy = layout.duplicate(true)
	if not copy.has("spawn_points"):
		copy["spawn_points"] = {}
	if not copy.has("obstacles"):
		copy["obstacles"] = []
	if not copy.has("objects"):
		copy["objects"] = {}
	if not copy.has("decorations"):
		copy["decorations"] = []
	return copy

func _load_json_dictionary(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("布局文件必须是字典：%s" % path)
		return {}
	return parsed

func _is_valid_position(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var x = value.get("x")
	var y = value.get("y")
	var x_is_number = typeof(x) == TYPE_INT or typeof(x) == TYPE_FLOAT
	var y_is_number = typeof(y) == TYPE_INT or typeof(y) == TYPE_FLOAT
	return x_is_number and y_is_number
