@tool
extends RefCounted

const SEVERITY_ERROR := "error"
const SEVERITY_WARNING := "warning"
const DEFAULT_LAYOUTS_DIR := "res://data/map_layouts"
const VALID_DECO_TYPES := ["tree", "bush", "rock", "signpost", "lantern", "building", "bridge"]
const VALID_PARTICLE_TYPES := ["cloud", "fog", "leaves", "water", "snow"]

const DEFAULT_DATA_PATHS := {
	"actors": "res://data/actors.json",
	"items": "res://data/items.json",
	"quests": "res://data/quests.json",
	"dialogues": "res://data/dialogues.json",
	"maps": "res://data/maps.json",
}

var data_paths: Dictionary = DEFAULT_DATA_PATHS.duplicate()
var layouts_dir := DEFAULT_LAYOUTS_DIR
var indexes: Dictionary = {}
var layouts_by_map_id: Dictionary = {}

func set_paths(next_data_paths: Dictionary, next_layouts_dir: String = "") -> void:
	data_paths = DEFAULT_DATA_PATHS.duplicate()
	for key in next_data_paths.keys():
		data_paths[str(key)] = str(next_data_paths[key])
	if not next_layouts_dir.strip_edges().is_empty():
		layouts_dir = next_layouts_dir.strip_edges()
	layouts_by_map_id = {}

func validate_map(map_data: Dictionary) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	_refresh_indexes(issues)

	var objects = map_data.get("objects", [])
	if typeof(objects) != TYPE_ARRAY:
		issues.append(_issue(SEVERITY_ERROR, "", "objects", "当前地图对象列表格式错误：objects 必须是数组。"))
		return issues

	var object_ids = _collect_object_ids(objects)
	for object_data in objects:
		if typeof(object_data) != TYPE_DICTIONARY:
			issues.append(_issue(SEVERITY_ERROR, "", "objects", "地图对象必须是字典。"))
			continue
		_validate_object(issues, object_data, object_ids)

	# 校验 layout 文件中的字段
	var map_id = str(map_data.get("id", "")).strip_edges()
	if not map_id.is_empty():
		var layout = _load_layout(map_id)
		if not layout.is_empty():
			_validate_layout_fields(issues, layout)

	return issues

func _refresh_indexes(issues: Array[Dictionary]) -> void:
	indexes = {}
	layouts_by_map_id = {}
	for collection in ["actors", "items", "quests", "dialogues", "maps"]:
		indexes[collection] = _load_index(collection, str(data_paths.get(collection, "")), issues)

func _load_index(collection: String, path: String, issues: Array[Dictionary]) -> Dictionary:
	var index := {}
	if path.is_empty() or not FileAccess.file_exists(path):
		issues.append(_issue(SEVERITY_ERROR, "", collection, "数据源不存在：%s" % path))
		return index

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		issues.append(_issue(SEVERITY_ERROR, "", collection, "无法读取数据源：%s" % path))
		return index

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		issues.append(_issue(SEVERITY_ERROR, "", collection, "%s 必须是数组。" % path.get_file()))
		return index

	for record in parsed:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var record_id = str(record.get("id", "")).strip_edges()
		if record_id.is_empty():
			continue
		index[record_id] = record
	return index

func _collect_object_ids(objects: Array) -> Dictionary:
	var result := {}
	for object_data in objects:
		if typeof(object_data) != TYPE_DICTIONARY:
			continue
		var object_id = str(object_data.get("id", "")).strip_edges()
		if not object_id.is_empty():
			result[object_id] = true
	return result

func _validate_object(issues: Array[Dictionary], object_data: Dictionary, object_ids: Dictionary) -> void:
	var object_id = str(object_data.get("id", "")).strip_edges()
	_validate_optional_reference(issues, object_id, "dialogue_id", object_data, "dialogues", "对白不存在")
	_validate_optional_reference(issues, object_id, "quest_id", object_data, "quests", "任务不存在")
	_validate_optional_reference(issues, object_id, "required_quest_id", object_data, "quests", "任务不存在")
	_validate_optional_reference(issues, object_id, "actor_id", object_data, "actors", "角色不存在")

	match str(object_data.get("type", "")):
		"exit":
			_validate_exit(issues, object_id, object_data)
		"battle_trigger":
			_validate_battle_trigger(issues, object_id, object_data)

	if object_data.has("effects"):
		_validate_effects(issues, object_id, object_data.get("effects", []), object_ids)

func _validate_exit(issues: Array[Dictionary], object_id: String, object_data: Dictionary) -> void:
	var target_map_id = str(object_data.get("target_map_id", "")).strip_edges()
	var target_spawn_id = str(object_data.get("target_spawn_id", "")).strip_edges()
	if target_map_id.is_empty():
		issues.append(_issue(SEVERITY_ERROR, object_id, "target_map_id", "出口缺少目标地图。"))
		return
	if not _has_id("maps", target_map_id):
		issues.append(_issue(SEVERITY_ERROR, object_id, "target_map_id", "目标地图不存在：%s" % target_map_id))
		return
	if not target_spawn_id.is_empty() and not _target_spawn_exists(target_map_id, target_spawn_id):
		issues.append(_issue(SEVERITY_ERROR, object_id, "target_spawn_id", "目标出生点不存在：%s/%s" % [target_map_id, target_spawn_id]))

func _validate_battle_trigger(issues: Array[Dictionary], object_id: String, object_data: Dictionary) -> void:
	if object_data.has("battle_id") and not str(object_data.get("battle_id", "")).strip_edges().is_empty():
		issues.append(_issue(SEVERITY_WARNING, object_id, "battle_id", "当前项目没有独立 battle 数据源，暂不校验：%s" % str(object_data.get("battle_id", ""))))

	if object_data.has("units"):
		var units = object_data.get("units", [])
		if typeof(units) != TYPE_ARRAY:
			issues.append(_issue(SEVERITY_ERROR, object_id, "units", "战斗单位列表格式错误：units 必须是数组。"))
		else:
			for index in range(units.size()):
				var unit = units[index]
				if typeof(unit) != TYPE_DICTIONARY:
					issues.append(_issue(SEVERITY_ERROR, object_id, "units[%d]" % index, "战斗单位必须是字典。"))
					continue
				_validate_optional_nested_reference(issues, object_id, "units[%d].actor_id" % index, unit, "actor_id", "actors", "角色不存在")

	_validate_victory_rewards(issues, object_id, object_data.get("victory_rewards", {}))

func _validate_victory_rewards(issues: Array[Dictionary], object_id: String, rewards: Variant) -> void:
	if typeof(rewards) != TYPE_DICTIONARY:
		if rewards != null:
			issues.append(_issue(SEVERITY_ERROR, object_id, "victory_rewards", "胜利奖励格式错误：victory_rewards 必须是字典。"))
		return
	var loot_table = rewards.get("loot_table", {})
	if typeof(loot_table) != TYPE_DICTIONARY:
		if loot_table != null:
			issues.append(_issue(SEVERITY_ERROR, object_id, "victory_rewards.loot_table", "掉落表格式错误：loot_table 必须是字典。"))
		return
	var entries = loot_table.get("entries", [])
	if typeof(entries) != TYPE_ARRAY:
		issues.append(_issue(SEVERITY_ERROR, object_id, "victory_rewards.loot_table.entries", "掉落表条目格式错误：entries 必须是数组。"))
		return
	for index in range(entries.size()):
		var entry = entries[index]
		if typeof(entry) != TYPE_DICTIONARY:
			issues.append(_issue(SEVERITY_ERROR, object_id, "victory_rewards.loot_table.entries[%d]" % index, "掉落表条目必须是字典。"))
			continue
		_validate_optional_nested_reference(issues, object_id, "victory_rewards.loot_table.entries[%d].item_id" % index, entry, "item_id", "items", "物品不存在")

func _validate_effects(issues: Array[Dictionary], object_id: String, effects: Variant, object_ids: Dictionary) -> void:
	if typeof(effects) != TYPE_ARRAY:
		issues.append(_issue(SEVERITY_ERROR, object_id, "effects", "效果列表格式错误：effects 必须是数组。"))
		return
	for index in range(effects.size()):
		var effect = effects[index]
		if typeof(effect) != TYPE_DICTIONARY:
			issues.append(_issue(SEVERITY_ERROR, object_id, "effects[%d]" % index, "效果必须是字典。"))
			continue
		match str(effect.get("type", "")):
			"add_item", "remove_item":
				_validate_required_nested_reference(issues, object_id, "effects[%d].item_id" % index, effect, "item_id", "items", "物品不存在")
			"set_quest_status":
				_validate_required_nested_reference(issues, object_id, "effects[%d].quest_id" % index, effect, "quest_id", "quests", "任务不存在")
			"resolve_map_object":
				var target_object_id = str(effect.get("object_id", "")).strip_edges()
				if target_object_id.is_empty():
					issues.append(_issue(SEVERITY_ERROR, object_id, "effects[%d].object_id" % index, "效果缺少地图对象编号。"))
				elif not object_ids.has(target_object_id):
					issues.append(_issue(SEVERITY_ERROR, object_id, "effects[%d].object_id" % index, "地图对象不存在：%s" % target_object_id))
			"add_party_member":
				_validate_required_nested_reference(issues, object_id, "effects[%d].actor_id" % index, effect, "actor_id", "actors", "角色不存在")

func _validate_optional_reference(issues: Array[Dictionary], object_id: String, field: String, data: Dictionary, collection: String, label: String) -> void:
	var reference_id = str(data.get(field, "")).strip_edges()
	if reference_id.is_empty():
		return
	if not _has_id(collection, reference_id):
		issues.append(_issue(SEVERITY_ERROR, object_id, field, "%s：%s" % [label, reference_id]))

func _validate_optional_nested_reference(issues: Array[Dictionary], object_id: String, field: String, data: Dictionary, key: String, collection: String, label: String) -> void:
	var reference_id = str(data.get(key, "")).strip_edges()
	if reference_id.is_empty():
		return
	if not _has_id(collection, reference_id):
		issues.append(_issue(SEVERITY_ERROR, object_id, field, "%s：%s" % [label, reference_id]))

func _validate_required_nested_reference(issues: Array[Dictionary], object_id: String, field: String, data: Dictionary, key: String, collection: String, label: String) -> void:
	var reference_id = str(data.get(key, "")).strip_edges()
	if reference_id.is_empty():
		issues.append(_issue(SEVERITY_ERROR, object_id, field, "引用缺失：%s" % key))
		return
	if not _has_id(collection, reference_id):
		issues.append(_issue(SEVERITY_ERROR, object_id, field, "%s：%s" % [label, reference_id]))

func _has_id(collection: String, record_id: String) -> bool:
	var index = indexes.get(collection, {})
	return typeof(index) == TYPE_DICTIONARY and index.has(record_id)

func _target_spawn_exists(map_id: String, spawn_id: String) -> bool:
	var layout = _load_layout(map_id)
	var spawn_points = layout.get("spawn_points", {})
	return typeof(spawn_points) == TYPE_DICTIONARY and spawn_points.has(spawn_id)

func _load_layout(map_id: String) -> Dictionary:
	if layouts_by_map_id.has(map_id):
		return layouts_by_map_id[map_id]
	var path = "%s/%s.json" % [layouts_dir.trim_suffix("/"), map_id]
	var layout := {}
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				layout = parsed
	layouts_by_map_id[map_id] = layout
	return layout

func _validate_layout_fields(issues: Array[Dictionary], layout: Dictionary) -> void:
	var mode = str(layout.get("mode", ""))

	# 大图底图模式
	if mode == "big_image":
		var bg_path = str(layout.get("background", {}).get("path", ""))
		if not bg_path.is_empty() and not FileAccess.file_exists(bg_path):
			issues.append(_issue(SEVERITY_WARNING, "", "background.path", "底图文件不存在：%s" % bg_path))

	# TileMap 模式
	if mode == "tile_map":
		var tileset_config = str(layout.get("tileset", {}).get("config", ""))
		if tileset_config.is_empty():
			issues.append(_issue(SEVERITY_ERROR, "", "tileset.config", "TileMap 模式缺少 tileset 配置路径"))
		elif not FileAccess.file_exists(tileset_config):
			issues.append(_issue(SEVERITY_ERROR, "", "tileset.config", "tileset 配置文件不存在：%s" % tileset_config))
		_validate_tile_layers(issues, layout.get("layers", {}))

	# 装饰物校验
	var decorations = layout.get("decorations", [])
	if typeof(decorations) == TYPE_ARRAY:
		for deco in decorations:
			if typeof(deco) != TYPE_DICTIONARY:
				continue
			var deco_type = str(deco.get("type", ""))
			var deco_id = str(deco.get("id", ""))
			if deco_type.is_empty():
				issues.append(_issue(SEVERITY_WARNING, deco_id, "type", "装饰物缺少类型"))
			elif not VALID_DECO_TYPES.has(deco_type):
				issues.append(_issue(SEVERITY_WARNING, deco_id, "type", "未知装饰物类型：%s" % deco_type))

	# 粒子校验
	var particles = layout.get("particles", [])
	if typeof(particles) == TYPE_ARRAY:
		for p in particles:
			if typeof(p) != TYPE_DICTIONARY:
				continue
			var ptype = str(p.get("type", ""))
			var pid = str(p.get("id", ""))
			if not VALID_PARTICLE_TYPES.has(ptype):
				issues.append(_issue(SEVERITY_WARNING, pid, "type", "未知粒子类型：%s" % ptype))

func _validate_tile_layers(issues: Array[Dictionary], layers: Dictionary) -> void:
	for layer_name in layers:
		var grid = layers[layer_name]
		if typeof(grid) != TYPE_ARRAY:
			issues.append(_issue(SEVERITY_ERROR, "", "layers.%s" % layer_name, "tile 层必须是二维数组"))
			continue
		var col_count := -1
		for row_idx in range(grid.size()):
			var row = grid[row_idx]
			if typeof(row) != TYPE_ARRAY:
				issues.append(_issue(SEVERITY_ERROR, "", "layers.%s[%d]" % [layer_name, row_idx], "行必须是数组"))
				continue
			if col_count < 0:
				col_count = row.size()
			elif row.size() != col_count:
				issues.append(_issue(SEVERITY_WARNING, "", "layers.%s[%d]" % [layer_name, row_idx], "行宽度不一致"))

func _issue(severity: String, object_id: String, field: String, message: String) -> Dictionary:
	return {
		"severity": severity,
		"object_id": object_id,
		"field": field,
		"message": message,
	}
