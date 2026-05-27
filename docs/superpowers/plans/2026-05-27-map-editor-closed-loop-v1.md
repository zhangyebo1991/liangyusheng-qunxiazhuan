# Map Editor Closed Loop v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first complete Godot map editor loop: richer property editing, template-based element creation, and runtime/editor data consistency checks.

**Architecture:** Add a writable `MapContentDocument` for `data/maps.json`, extend `MapLayoutDocument` with creation helpers, then wire both documents into `MapPreviewPlugin`. Keep map-space editing in the map preview plugin and only create story entry references such as `dialogue_id`, `quest_id`, `battle_id`, and `target_map_id`; story body editing remains for later content tooling.

**Tech Stack:** Godot 4.6, GDScript `@tool` editor plugin, JSON data files, existing `tests/run_tests.gd` headless runner, PowerShell verification commands.

---

## Scope

This plan implements `docs/superpowers/specs/2026-05-27-map-editor-closed-loop-v1-design.md`.

Included:

- Select object/spawn/obstacle and edit fields from the map preview Dock.
- Create NPC, exit, pickup, battle point, spawn point, and rectangle obstacle templates.
- Save gameplay object templates to `data/maps.json`.
- Save layout coordinates, radii, spawn points, and obstacles to `data/map_layouts/<map_id>.json`.
- Add tests proving layout data and runtime `DataRepository.get_map()` remain aligned.

Excluded:

- Dialogue body editing.
- Quest chain editing.
- Full battle editor.
- TileMap, navigation mesh, and polygon editing.
- Field-level merge UI.

## File Structure

- Create `addons/map_preview/map_content_document.gd`
  Writable document for `data/maps.json`; preserves arrays and unknown fields, exposes indexed maps, adds and updates objects, tracks dirty/hash/external-change state.

- Create `tests/test_map_content_document.gd`
  Unit tests for map content load/save, duplicate object rejection, object template insertion, object field updates, hash/external change detection, and unknown field preservation.

- Modify `addons/map_preview/map_layout_document.gd`
  Add creation helpers for object layouts, spawn points, and rectangle obstacles. Keep existing update helpers.

- Modify `tests/test_map_layout_document.gd`
  Cover the new creation helpers and duplicate-id rejection.

- Modify `addons/map_preview/map_preview_plugin.gd`
  Replace read-only map index usage in the plugin with `MapContentDocument`, add selection state for object/spawn/obstacle, add coordinate/property controls, add template creation controls, and save both content and layout documents.

- Modify `tests/run_tests.gd`
  Register `tests/test_map_content_document.gd`.

- Modify `tests/test_map_layout_loader.gd`
  Expand runtime consistency checks so merged map data includes layout background, spawn points, obstacles, object positions, and object radii from `data/map_layouts`.

- Modify `docs/godot-project-structure.md`
  Document the closed-loop v1 responsibilities and clarify that story body editing is a later content workbench.

## Task 1: Writable Map Content Document

**Files:**

- Create: `addons/map_preview/map_content_document.gd`
- Create: `tests/test_map_content_document.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write the failing `MapContentDocument` tests**

Create `tests/test_map_content_document.gd`:

```gdscript
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
```

- [ ] **Step 2: Register the failing suite**

Modify `tests/run_tests.gd`.

Add preload after `TestMapIndexDocumentScript`:

```gdscript
const TestMapContentDocumentScript = preload("res://tests/test_map_content_document.gd")
```

Add the suite after `TestMapIndexDocumentScript.new()`:

```gdscript
		TestMapContentDocumentScript.new(),
```

- [ ] **Step 3: Run tests and verify the expected failure**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: preload failure because `res://addons/map_preview/map_content_document.gd` does not exist yet.

- [ ] **Step 4: Implement `MapContentDocument`**

Create `addons/map_preview/map_content_document.gd`:

```gdscript
@tool
extends RefCounted

const DEFAULT_PATH := "res://data/maps.json"

var path: String = DEFAULT_PATH
var maps: Array = []
var maps_by_id: Dictionary = {}
var scene_path_to_map_id: Dictionary = {}
var loaded_hash := 0
var dirty := false
var last_error := ""

func load_from_path(source_path: String = DEFAULT_PATH) -> bool:
	var file = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		last_error = "无法读取 data/maps.json。"
		return false
	return load_from_text(file.get_as_text(), source_path)

func load_from_text(text: String, source_path: String = DEFAULT_PATH) -> bool:
	var json = JSON.new()
	if json.parse(text) != OK:
		last_error = "data/maps.json 必须是数组。"
		return false
	var parsed = json.data
	if typeof(parsed) != TYPE_ARRAY:
		last_error = "data/maps.json 必须是数组。"
		return false

	var next_maps: Array = []
	for map_data in parsed:
		if typeof(map_data) == TYPE_DICTIONARY:
			next_maps.append(map_data.duplicate(true))
	path = source_path
	maps = next_maps
	_rebuild_indexes()
	loaded_hash = _hash_maps()
	dirty = false
	last_error = ""
	return true

func is_dirty() -> bool:
	return dirty

func get_maps_by_id() -> Dictionary:
	return maps_by_id.duplicate(true)

func get_scene_path_to_map_id() -> Dictionary:
	return scene_path_to_map_id.duplicate(true)

func find_object(map_id: String, object_id: String) -> Dictionary:
	var object_index = _find_object_index(map_id, object_id)
	if object_index.map_index < 0 or object_index.object_index < 0:
		return {}
	return maps[object_index.map_index].get("objects", [])[object_index.object_index].duplicate(true)

func add_object_to_map(map_id: String, object_record: Dictionary) -> Dictionary:
	var object_id = str(object_record.get("id", "")).strip_edges()
	if object_id.is_empty():
		return _error("请输入对象编号。")
	var map_index = _find_map_index(map_id)
	if map_index < 0:
		return _error("地图编号不存在：%s" % map_id)
	if not find_object(map_id, object_id).is_empty():
		return _error("对象编号已存在：%s" % object_id)
	var map_data = maps[map_index].duplicate(true)
	var objects = map_data.get("objects", [])
	if typeof(objects) != TYPE_ARRAY:
		objects = []
	objects.append(object_record.duplicate(true))
	map_data["objects"] = objects
	maps[map_index] = map_data
	_mark_dirty()
	return _ok()

func update_object_fields(map_id: String, object_id: String, fields: Dictionary) -> Dictionary:
	var object_index = _find_object_index(map_id, object_id)
	if object_index.map_index < 0:
		return _error("地图编号不存在：%s" % map_id)
	if object_index.object_index < 0:
		return _error("对象编号不存在：%s" % object_id)
	var map_data = maps[object_index.map_index].duplicate(true)
	var objects = map_data.get("objects", []).duplicate(true)
	var object_record = objects[object_index.object_index].duplicate(true)
	for key in fields.keys():
		object_record[key] = fields[key]
	objects[object_index.object_index] = object_record
	map_data["objects"] = objects
	maps[object_index.map_index] = map_data
	_mark_dirty()
	return _ok()

func has_external_change() -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	return file.get_as_text().hash() != loaded_hash

func save() -> bool:
	if path.is_empty():
		last_error = "无法写入 data/maps.json。"
		return false
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "无法写入 data/maps.json。"
		return false
	file.store_string(JSON.stringify(maps, "\t"))
	file.close()
	loaded_hash = _hash_maps()
	dirty = false
	_rebuild_indexes()
	last_error = ""
	return true

func _find_map_index(map_id: String) -> int:
	for index in range(maps.size()):
		if typeof(maps[index]) == TYPE_DICTIONARY and str(maps[index].get("id", "")) == map_id:
			return index
	return -1

func _find_object_index(map_id: String, object_id: String) -> Dictionary:
	var map_index = _find_map_index(map_id)
	if map_index < 0:
		return {"map_index": -1, "object_index": -1}
	var objects = maps[map_index].get("objects", [])
	if typeof(objects) != TYPE_ARRAY:
		return {"map_index": map_index, "object_index": -1}
	for index in range(objects.size()):
		if typeof(objects[index]) == TYPE_DICTIONARY and str(objects[index].get("id", "")) == object_id:
			return {"map_index": map_index, "object_index": index}
	return {"map_index": map_index, "object_index": -1}

func _rebuild_indexes() -> void:
	maps_by_id = {}
	scene_path_to_map_id = {}
	for map_data in maps:
		if typeof(map_data) != TYPE_DICTIONARY:
			continue
		var map_id = str(map_data.get("id", "")).strip_edges()
		if map_id.is_empty():
			continue
		maps_by_id[map_id] = map_data
		var scene_path = str(map_data.get("scene_path", "")).strip_edges()
		if not scene_path.is_empty():
			scene_path_to_map_id[scene_path] = map_id

func _mark_dirty() -> void:
	dirty = true
	_rebuild_indexes()

func _hash_maps() -> int:
	return JSON.stringify(maps, "\t").hash()

func _ok() -> Dictionary:
	return {"ok": true, "error": ""}

func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}
```

- [ ] **Step 5: Run tests and verify the new document passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: `测试通过：79 个测试套件`. Existing red `missing_map` and `missing_item` `push_error` lines are expected negative-path test noise.

- [ ] **Step 6: Commit Task 1**

Run:

```powershell
git add addons/map_preview/map_content_document.gd tests/test_map_content_document.gd tests/run_tests.gd
git commit -m "feat: add writable map content document"
```

## Task 2: Layout Creation Helpers

**Files:**

- Modify: `addons/map_preview/map_layout_document.gd`
- Modify: `tests/test_map_layout_document.gd`

- [ ] **Step 1: Write failing tests for layout creation helpers**

Modify `tests/test_map_layout_document.gd`.

Add calls in `run` after `_test_document_updates_fields(assertions)`:

```gdscript
	_test_document_adds_layout_elements(assertions)
	_test_document_rejects_duplicate_layout_ids(assertions)
```

Add these test functions before `_test_document_preserves_unknown_fields_on_save`:

```gdscript
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
	assertions.assert_eq(layout.get("obstacles", [])[1].get("rect", {}).get("w", 0), 40.0, "新增障碍应写入宽度")
	assertions.assert_true(document.is_dirty(), "新增布局元素后文档应为脏状态")

func _test_document_rejects_duplicate_layout_ids(assertions) -> void:
	var document = MapLayoutDocumentScript.new()
	document.load_from_data("demo", _sample_layout(), "user://demo_layout_duplicate.json")

	assertions.assert_false(document.add_object_layout("npc_demo", Vector2(1, 2), 48.0).ok, "重复对象布局应被拒绝")
	assertions.assert_false(document.add_spawn_point("start", Vector2(1, 2)).ok, "重复出生点应被拒绝")
	assertions.assert_false(document.add_rect_obstacle("wall", Rect2(1, 2, 3, 4)).ok, "重复障碍应被拒绝")
```

- [ ] **Step 2: Run tests and verify helper methods are missing**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: failure mentioning missing `add_object_layout`, `add_spawn_point`, or `add_rect_obstacle`.

- [ ] **Step 3: Implement layout creation helpers**

Modify `addons/map_preview/map_layout_document.gd`.

Add these methods after `update_obstacle_rect`:

```gdscript
func add_object_layout(object_id: String, position: Vector2, radius: float) -> Dictionary:
	object_id = object_id.strip_edges()
	if object_id.is_empty():
		return _error("请输入对象编号。")
	if radius <= 0.0:
		return _error("对象半径必须为正数：%s" % object_id)
	var objects = _ensure_dictionary("objects")
	if objects.has(object_id):
		return _error("对象布局已存在：%s" % object_id)
	objects[object_id] = {
		"position": _vector_to_dictionary(position),
		"radius": radius,
	}
	_mark_dirty()
	return _ok()

func add_spawn_point(spawn_id: String, position: Vector2) -> Dictionary:
	spawn_id = spawn_id.strip_edges()
	if spawn_id.is_empty():
		return _error("请输入出生点编号。")
	var spawn_points = _ensure_dictionary("spawn_points")
	if spawn_points.has(spawn_id):
		return _error("出生点已存在：%s" % spawn_id)
	spawn_points[spawn_id] = _vector_to_dictionary(position)
	_mark_dirty()
	return _ok()

func add_rect_obstacle(obstacle_id: String, rect: Rect2) -> Dictionary:
	obstacle_id = obstacle_id.strip_edges()
	if obstacle_id.is_empty():
		return _error("请输入障碍编号。")
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return _error("矩形障碍尺寸必须为正数：%s" % obstacle_id)
	var obstacles = layout.get("obstacles", [])
	if typeof(obstacles) != TYPE_ARRAY:
		obstacles = []
	for obstacle in obstacles:
		if typeof(obstacle) == TYPE_DICTIONARY and str(obstacle.get("id", "")) == obstacle_id:
			return _error("障碍编号已存在：%s" % obstacle_id)
	obstacles.append({
		"id": obstacle_id,
		"shape": "rect",
		"rect": _rect_to_dictionary(rect),
	})
	layout["obstacles"] = obstacles
	_mark_dirty()
	return _ok()
```

Add these helpers near `_mark_dirty`:

```gdscript
func _ok() -> Dictionary:
	return {"ok": true, "error": ""}

func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
```

- [ ] **Step 4: Run tests and verify they pass**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: `测试通过：79 个测试套件`.

- [ ] **Step 5: Commit Task 2**

Run:

```powershell
git add addons/map_preview/map_layout_document.gd tests/test_map_layout_document.gd
git commit -m "feat: add map layout creation helpers"
```

## Task 3: Runtime Consistency Coverage

**Files:**

- Modify: `tests/test_map_layout_loader.gd`

- [ ] **Step 1: Strengthen runtime consistency tests**

Modify `_test_loader_merges_layout_into_map` in `tests/test_map_layout_loader.gd` to include these assertions after the existing `qingshanke` assertions:

```gdscript
	var mountain_layout = mountain.get("layout", {})
	assertions.assert_eq(mountain_layout.get("size", {}).get("x", 0), 1280, "运行时地图应包含布局宽度")
	assertions.assert_eq(mountain_layout.get("background", {}).get("mode", ""), "color", "运行时地图应包含背景模式")
	assertions.assert_eq(mountain_layout.get("background", {}).get("color", ""), "#6f8f55", "运行时地图应包含背景颜色")
	assertions.assert_eq(mountain_layout.get("spawn_points", {}).get("start", {}).get("x", 0), 160, "运行时 layout 应包含出生点横坐标")
	assertions.assert_eq(mountain.get("spawn_points", {}).get("start", {}).get("x", 0), 160, "运行时顶层 spawn_points 应来自布局")
	assertions.assert_eq(mountain_layout.get("obstacles", [])[0].get("shape", ""), "rect", "运行时 layout 应包含矩形障碍")
	assertions.assert_eq(mountain_layout.get("objects", {}).get("npc_qingshanke", {}).get("radius", 0), 72, "运行时 layout 应包含对象半径")
	assertions.assert_eq(qingshanke.get("position", {}).get("y", 0), 280, "运行时对象纵坐标应从布局合并")
```

- [ ] **Step 2: Run tests**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: `测试通过：79 个测试套件`.

- [ ] **Step 3: Commit Task 3**

Run:

```powershell
git add tests/test_map_layout_loader.gd
git commit -m "test: cover runtime map layout consistency"
```

## Task 4: Plugin Document Wiring and Save Flow

**Files:**

- Modify: `addons/map_preview/map_preview_plugin.gd`

- [ ] **Step 1: Switch the plugin to the writable content document**

Modify the preload and state near the top of `addons/map_preview/map_preview_plugin.gd`.

Replace:

```gdscript
const MapIndexDocumentScript = preload("res://addons/map_preview/map_index_document.gd")
```

with:

```gdscript
const MapContentDocumentScript = preload("res://addons/map_preview/map_content_document.gd")
```

Replace:

```gdscript
var map_index = MapIndexDocumentScript.new()
```

with:

```gdscript
var content_document = MapContentDocumentScript.new()
```

Replace `_load_map_index` with:

```gdscript
func _load_map_index() -> bool:
	var restore_map_id = selected_map_id
	if not content_document.load_from_path(MAP_INDEX_PATH):
		_update_status(content_document.last_error)
		return false
	maps_by_id = content_document.get_maps_by_id()
	scene_path_to_map_id = content_document.get_scene_path_to_map_id()
	_rebuild_map_selector(restore_map_id)
	return true
```

Replace `_check_map_index_refresh` with:

```gdscript
func _check_map_index_refresh() -> void:
	if not content_document.has_external_change():
		return
	if content_document.is_dirty():
		_update_status("data/maps.json 有外部修改，且编辑器内有未保存内容修改。请选择保存或手动刷新。")
		return
	var previous_map_id = selected_map_id
	var previous_object_id = selected_object_id
	if not _load_map_index():
		return
	_refresh_after_map_index_change(previous_map_id, previous_object_id)
```

- [ ] **Step 2: Update save flow to save both documents**

Replace `_save_document` with:

```gdscript
func _save_document() -> void:
	if selected_map_id.is_empty():
		return
	if document.has_external_change() and document.is_dirty():
		if not save_conflict_confirm_pending:
			save_conflict_confirm_pending = true
			_update_status("检测到布局外部修改。再次点击保存将覆盖外部版本，或点击重载外部版本。")
			return
	if content_document.has_external_change() and content_document.is_dirty():
		if not save_conflict_confirm_pending:
			save_conflict_confirm_pending = true
			_update_status("检测到 data/maps.json 外部修改。再次点击保存将覆盖外部版本，或点击刷新。")
			return

	var content_ok = true
	if content_document.is_dirty():
		content_ok = content_document.save()
	var layout_ok = true
	if document.is_dirty():
		layout_ok = document.save()

	if content_ok and layout_ok:
		save_conflict_confirm_pending = false
		_load_map_index()
		_render_selected_map()
		_update_status("已保存地图编辑：%s" % selected_map_id)
	elif not content_ok:
		_update_status("保存失败：data/maps.json")
	else:
		_update_status("保存失败：%s" % document.path)
```

Replace `_save_external_data` with:

```gdscript
func _save_external_data() -> void:
	var saved_any := false
	if content_document.is_dirty() and not content_document.has_external_change():
		if content_document.save():
			saved_any = true
	if document.is_dirty() and not document.has_external_change():
		if document.save():
			saved_any = true
	if saved_any:
		_update_status("已随项目保存地图编辑。")
```

- [ ] **Step 3: Run tests to catch syntax errors**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: `测试通过：79 个测试套件`.

- [ ] **Step 4: Commit Task 4**

Run:

```powershell
git add addons/map_preview/map_preview_plugin.gd
git commit -m "feat: save map content and layout documents"
```

## Task 5: Property Editing Selection State

**Files:**

- Modify: `addons/map_preview/map_preview_plugin.gd`

- [ ] **Step 1: Add selection and property UI state**

Add variables near the existing Dock controls:

```gdscript
var selected_layout_kind := ""
var selected_layout_id := ""
var selection_label: Label
var position_x_spin: SpinBox
var position_y_spin: SpinBox
var object_name_input: LineEdit
var object_type_input: LineEdit
```

In `_build_dock`, add this block before the existing `object_box`:

```gdscript
	var selection_box = VBoxContainer.new()
	dock.add_child(selection_box)

	var selection_title = Label.new()
	selection_title.text = "当前选择"
	selection_box.add_child(selection_title)

	selection_label = Label.new()
	selection_label.text = "未选择"
	selection_box.add_child(selection_label)

	var position_row = HBoxContainer.new()
	selection_box.add_child(position_row)

	position_x_spin = SpinBox.new()
	position_x_spin.min_value = -4096.0
	position_x_spin.max_value = 4096.0
	position_x_spin.step = 1.0
	position_x_spin.prefix = "x "
	position_row.add_child(position_x_spin)

	position_y_spin = SpinBox.new()
	position_y_spin.min_value = -4096.0
	position_y_spin.max_value = 4096.0
	position_y_spin.step = 1.0
	position_y_spin.prefix = "y "
	position_row.add_child(position_y_spin)

	var position_button = Button.new()
	position_button.text = "应用坐标"
	position_button.pressed.connect(_apply_selected_position)
	selection_box.add_child(position_button)
```

Add this block inside `object_box` after `object_id_input`:

```gdscript
	object_name_input = LineEdit.new()
	object_name_input.placeholder_text = "对象名称"
	object_box.add_child(object_name_input)

	object_type_input = LineEdit.new()
	object_type_input.placeholder_text = "对象类型"
	object_box.add_child(object_type_input)

	var object_fields_button = Button.new()
	object_fields_button.text = "应用对象字段"
	object_fields_button.pressed.connect(_apply_object_fields)
	object_box.add_child(object_fields_button)
```

- [ ] **Step 2: Record selection kind and fill fields**

Update `_select_preview_object` so the successful branch sets both selection fields before `_apply_object_selection`:

```gdscript
	selected_layout_kind = "object"
	selected_layout_id = object_id
```

Add:

```gdscript
func _select_layout_element(kind: String, layout_id: String) -> void:
	selected_layout_kind = kind
	selected_layout_id = layout_id
	if selection_label != null:
		selection_label.text = "%s：%s" % [kind, layout_id]
	match kind:
		"object":
			_fill_object_edit_fields(layout_id)
		"spawn":
			_fill_position_fields(_current_spawn_position(layout_id))
		"obstacle":
			_fill_obstacle_fields(layout_id)

func _fill_position_fields(position: Vector2) -> void:
	if position_x_spin != null:
		position_x_spin.value = position.x
	if position_y_spin != null:
		position_y_spin.value = position.y

func _current_spawn_position(spawn_id: String) -> Vector2:
	var spawn_points = document.get_layout().get("spawn_points", {})
	var position_data = spawn_points.get(spawn_id, {})
	return Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
```

Update `_apply_object_selection` to call the generic selection helper:

```gdscript
func _apply_object_selection(object_id: String, handle: Node) -> void:
	_clear_selected_object_highlight()
	_set_handle_selected(handle, true)
	_select_layout_element("object", object_id)
```

Update `_fill_object_edit_fields`:

```gdscript
func _fill_object_edit_fields(object_id: String) -> void:
	if object_id_input != null:
		object_id_input.text = object_id
	var object_record = _find_map_object(object_id)
	if object_name_input != null:
		object_name_input.text = str(object_record.get("name", ""))
	if object_type_input != null:
		object_type_input.text = str(object_record.get("type", ""))
	if radius_spin != null:
		radius_spin.value = _current_object_radius(object_id)
	if not object_record.is_empty():
		var position_data = document.get_layout().get("objects", {}).get(object_id, {}).get("position", object_record.get("position", {}))
		_fill_position_fields(Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0))))
```

Add obstacle field helper:

```gdscript
func _fill_obstacle_fields(obstacle_id: String) -> void:
	if obstacle_id_input != null:
		obstacle_id_input.text = obstacle_id
	var rect = _find_obstacle_rect(obstacle_id)
	_fill_position_fields(rect.position)
	if obstacle_width_spin != null:
		obstacle_width_spin.value = rect.size.x
	if obstacle_height_spin != null:
		obstacle_height_spin.value = rect.size.y
```

- [ ] **Step 3: Apply selected position and object fields**

Add:

```gdscript
func _apply_selected_position() -> void:
	save_conflict_confirm_pending = false
	if selected_layout_kind.is_empty() or selected_layout_id.is_empty():
		_update_status("请先选择地图元素。")
		return
	var position = Vector2(float(position_x_spin.value), float(position_y_spin.value))
	match selected_layout_kind:
		"object":
			document.update_object_position(selected_layout_id, position)
		"spawn":
			document.update_spawn_position(selected_layout_id, position)
		"obstacle":
			var rect = _find_obstacle_rect(selected_layout_id)
			if rect.size == Vector2.ZERO:
				_update_status("找不到障碍：%s" % selected_layout_id)
				return
			document.update_obstacle_rect(selected_layout_id, Rect2(position, rect.size))
	_render_selected_map()
	_update_status("有未保存坐标修改：%s" % selected_layout_id)

func _apply_object_fields() -> void:
	save_conflict_confirm_pending = false
	var object_id = object_id_input.text.strip_edges()
	if object_id.is_empty():
		_update_status("请输入对象编号。")
		return
	var result = content_document.update_object_fields(selected_map_id, object_id, {
		"name": object_name_input.text.strip_edges(),
		"type": object_type_input.text.strip_edges(),
	})
	if not result.ok:
		_update_status(result.error)
		return
	maps_by_id = content_document.get_maps_by_id()
	scene_path_to_map_id = content_document.get_scene_path_to_map_id()
	_render_selected_map()
	_update_status("有未保存对象字段修改：%s" % object_id)
```

- [ ] **Step 4: Sync Dock fields after dragging any handle**

Update `_on_preview_handle_changed` to select the changed element and fill its new position:

```gdscript
func _on_preview_handle_changed(kind: String, layout_id: String, payload: Dictionary) -> void:
	save_conflict_confirm_pending = false
	var position_data = payload.get("position", {})
	var position = Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
	_select_layout_element(kind, layout_id)
	_fill_position_fields(position)
	match kind:
		"object":
			selected_object_id = layout_id
			object_id_input.text = layout_id
			document.update_object_position(layout_id, position)
		"spawn":
			document.update_spawn_position(layout_id, position)
		"obstacle":
			obstacle_id_input.text = layout_id
			var layout = document.get_layout()
			for obstacle in layout.get("obstacles", []):
				if typeof(obstacle) == TYPE_DICTIONARY and str(obstacle.get("id", "")) == layout_id:
					var rect = obstacle.get("rect", {})
					document.update_obstacle_rect(layout_id, Rect2(position, Vector2(float(rect.get("w", 0.0)), float(rect.get("h", 0.0)))))
					break
	_update_status("有未保存修改：%s" % layout_id)
```

- [ ] **Step 5: Run tests**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: `测试通过：79 个测试套件`.

- [ ] **Step 6: Manual editor smoke test**

In Godot editor:

1. Open `scenes/mountain_pass.tscn`.
2. Click `npc_qingshanke` in the object list.
3. Confirm Dock fills `object_id`, name, type, x/y, and radius.
4. Change `x` by `+10`, click `应用坐标`.
5. Confirm the preview moves and status shows unsaved changes.
6. Click `重载外部版本` to discard the test move if you do not want to keep it.

- [ ] **Step 7: Commit Task 5**

Run:

```powershell
git add addons/map_preview/map_preview_plugin.gd
git commit -m "feat: edit selected map preview properties"
```

## Task 6: Template Creation UI

**Files:**

- Modify: `addons/map_preview/map_preview_plugin.gd`

- [ ] **Step 1: Add template creation controls**

Add variables:

```gdscript
var new_element_type_selector: OptionButton
var new_element_id_input: LineEdit
var new_element_name_input: LineEdit
var new_element_reference_input: LineEdit
var new_element_spawn_input: LineEdit
var new_element_x_spin: SpinBox
var new_element_y_spin: SpinBox
var new_element_radius_spin: SpinBox
var new_element_width_spin: SpinBox
var new_element_height_spin: SpinBox
```

In `_build_dock`, add this block before `status_label`:

```gdscript
	var create_box = VBoxContainer.new()
	dock.add_child(create_box)

	var create_title = Label.new()
	create_title.text = "新增元素"
	create_box.add_child(create_title)

	new_element_type_selector = OptionButton.new()
	for type_label in ["NPC", "出口", "拾取物", "战斗点", "出生点", "矩形障碍"]:
		new_element_type_selector.add_item(type_label)
	create_box.add_child(new_element_type_selector)

	new_element_id_input = LineEdit.new()
	new_element_id_input.placeholder_text = "id"
	create_box.add_child(new_element_id_input)

	new_element_name_input = LineEdit.new()
	new_element_name_input.placeholder_text = "名称"
	create_box.add_child(new_element_name_input)

	new_element_reference_input = LineEdit.new()
	new_element_reference_input.placeholder_text = "引用：dialogue_id / target_map_id / battle_id"
	create_box.add_child(new_element_reference_input)

	new_element_spawn_input = LineEdit.new()
	new_element_spawn_input.placeholder_text = "出口目标 spawn_id"
	create_box.add_child(new_element_spawn_input)

	var create_position_row = HBoxContainer.new()
	create_box.add_child(create_position_row)

	new_element_x_spin = SpinBox.new()
	new_element_x_spin.min_value = -4096.0
	new_element_x_spin.max_value = 4096.0
	new_element_x_spin.step = 1.0
	new_element_x_spin.value = 640.0
	new_element_x_spin.prefix = "x "
	create_position_row.add_child(new_element_x_spin)

	new_element_y_spin = SpinBox.new()
	new_element_y_spin.min_value = -4096.0
	new_element_y_spin.max_value = 4096.0
	new_element_y_spin.step = 1.0
	new_element_y_spin.value = 360.0
	new_element_y_spin.prefix = "y "
	create_position_row.add_child(new_element_y_spin)

	new_element_radius_spin = SpinBox.new()
	new_element_radius_spin.min_value = 1.0
	new_element_radius_spin.max_value = 512.0
	new_element_radius_spin.step = 1.0
	new_element_radius_spin.value = 48.0
	new_element_radius_spin.prefix = "半径 "
	create_box.add_child(new_element_radius_spin)

	var create_size_row = HBoxContainer.new()
	create_box.add_child(create_size_row)

	new_element_width_spin = SpinBox.new()
	new_element_width_spin.min_value = 1.0
	new_element_width_spin.max_value = 4096.0
	new_element_width_spin.step = 1.0
	new_element_width_spin.value = 80.0
	new_element_width_spin.prefix = "w "
	create_size_row.add_child(new_element_width_spin)

	new_element_height_spin = SpinBox.new()
	new_element_height_spin.min_value = 1.0
	new_element_height_spin.max_value = 4096.0
	new_element_height_spin.step = 1.0
	new_element_height_spin.value = 80.0
	new_element_height_spin.prefix = "h "
	create_size_row.add_child(new_element_height_spin)

	var create_button = Button.new()
	create_button.text = "创建模板"
	create_button.pressed.connect(_create_template_element)
	create_box.add_child(create_button)
```

- [ ] **Step 2: Add template creation logic**

Add:

```gdscript
func _create_template_element() -> void:
	save_conflict_confirm_pending = false
	if selected_map_id.is_empty():
		_update_status("请先打开地图场景。")
		return
	var template_label = new_element_type_selector.get_item_text(new_element_type_selector.selected)
	var element_id = new_element_id_input.text.strip_edges()
	var position = Vector2(float(new_element_x_spin.value), float(new_element_y_spin.value))
	match template_label:
		"NPC", "出口", "拾取物", "战斗点":
			_create_object_template(template_label, element_id, position)
		"出生点":
			_create_spawn_template(element_id, position)
		"矩形障碍":
			_create_obstacle_template(element_id, position)

func _create_object_template(template_label: String, object_id: String, position: Vector2) -> void:
	var object_record = _build_object_template(template_label, object_id)
	var content_result = content_document.add_object_to_map(selected_map_id, object_record)
	if not content_result.ok:
		_update_status(content_result.error)
		return
	var layout_result = document.add_object_layout(object_id, position, float(new_element_radius_spin.value))
	if not layout_result.ok:
		_update_status(layout_result.error)
		return
	maps_by_id = content_document.get_maps_by_id()
	scene_path_to_map_id = content_document.get_scene_path_to_map_id()
	selected_object_id = object_id
	_render_selected_map()
	_select_preview_object(object_id)
	_update_status("已创建模板，尚未保存：%s" % object_id)

func _build_object_template(template_label: String, object_id: String) -> Dictionary:
	var object_name = new_element_name_input.text.strip_edges()
	if object_name.is_empty():
		object_name = object_id
	var reference = new_element_reference_input.text.strip_edges()
	match template_label:
		"NPC":
			return {
				"id": object_id,
				"type": "npc",
				"name": object_name,
				"dialogue_id": reference if not reference.is_empty() else "dialogue_%s" % object_id,
			}
		"出口":
			return {
				"id": object_id,
				"type": "exit",
				"name": object_name,
				"target_map_id": reference,
				"target_spawn_id": new_element_spawn_input.text.strip_edges(),
			}
		"拾取物":
			return {
				"id": object_id,
				"type": "pickup",
				"name": object_name,
				"effects": [],
			}
		"战斗点":
			return {
				"id": object_id,
				"type": "battle_trigger",
				"name": object_name,
				"battle_id": reference if not reference.is_empty() else "battle_%s" % object_id,
			}
	return {"id": object_id, "type": "notice", "name": object_name}

func _create_spawn_template(spawn_id: String, position: Vector2) -> void:
	var result = document.add_spawn_point(spawn_id, position)
	if not result.ok:
		_update_status(result.error)
		return
	_render_selected_map()
	_select_layout_element("spawn", spawn_id)
	_update_status("已创建出生点，尚未保存：%s" % spawn_id)

func _create_obstacle_template(obstacle_id: String, position: Vector2) -> void:
	var rect = Rect2(position, Vector2(float(new_element_width_spin.value), float(new_element_height_spin.value)))
	var result = document.add_rect_obstacle(obstacle_id, rect)
	if not result.ok:
		_update_status(result.error)
		return
	_render_selected_map()
	_select_layout_element("obstacle", obstacle_id)
	_update_status("已创建矩形障碍，尚未保存：%s" % obstacle_id)
```

- [ ] **Step 3: Run tests**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: `测试通过：79 个测试套件`.

- [ ] **Step 4: Manual editor smoke test for templates**

In Godot editor:

1. Open `scenes/mountain_pass.tscn`.
2. In `新增元素`, select `NPC`.
3. Enter `id = npc_plan_test`, `名称 = 计划测试人物`, and keep x/y near `640/360`.
4. Click `创建模板`.
5. Confirm the NPC appears and is selected.
6. Click `重载外部版本` if you do not want to keep the test object.

- [ ] **Step 5: Commit Task 6**

Run:

```powershell
git add addons/map_preview/map_preview_plugin.gd
git commit -m "feat: create map element templates"
```

## Task 7: Documentation and Verification

**Files:**

- Modify: `docs/godot-project-structure.md`

- [ ] **Step 1: Document closed-loop v1**

In `docs/godot-project-structure.md`, extend the `双向地图预览编辑器` section with:

```markdown
地图编辑闭环 v1 支持在 Dock 中编辑已选对象、出生点和矩形障碍物的坐标、半径和尺寸。Dock 也可以用模板新增 NPC、出口、拾取物、战斗点、出生点和矩形障碍物。玩法对象模板写入 `data/maps.json`，布局坐标和尺寸写入 `data/map_layouts/<map_id>.json`。

地图编辑器只负责创建剧情入口引用，例如 `dialogue_id`、`target_map_id`、`target_spawn_id` 和 `battle_id`。对白正文、任务链、战斗配置和奖励配置由后续独立剧情内容工作台负责。
```

- [ ] **Step 2: Run full automated verification**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

Expected:

- Test command exits `0`.
- Output includes `测试通过：79 个测试套件`.
- Project load command exits `0`.
- Existing red negative-path `missing_map` / `missing_item` logs can appear during tests.

- [ ] **Step 3: Manual final acceptance**

In Godot editor:

1. Restart Godot so the updated `@tool` plugin reloads.
2. Open `scenes/mountain_pass.tscn`.
3. Confirm preview appears.
4. Select `npc_qingshanke` from the object list.
5. Change x/y through Dock and confirm preview moves.
6. Create a temporary NPC template and confirm it appears selected.
7. Create a temporary spawn point and rectangle obstacle.
8. Save.
9. Inspect `data/maps.json` and `data/map_layouts/mountain_pass.json` to confirm gameplay object fields and layout fields are written to the expected files.
10. Run the game and confirm the temporary object location matches the editor preview.
11. Remove temporary test entries or revert the manual acceptance changes before committing final docs if they should not remain in sample data.

- [ ] **Step 4: Commit Task 7**

Run:

```powershell
git add docs/godot-project-structure.md
git commit -m "docs: document map editor closed loop"
```

## Final Review Checklist

- [ ] `MapContentDocument` has tests for load, add, update, save, duplicate id, and external changes.
- [ ] `MapLayoutDocument` has tests for adding object layouts, spawn points, and obstacles.
- [ ] `MapPreviewPlugin` saves content and layout documents without silently overwriting external changes.
- [ ] Existing auto-refresh still updates `data/maps.json` changes when content document is clean.
- [ ] Object, spawn, and obstacle edits mark the relevant document dirty.
- [ ] Template-created gameplay objects write only gameplay fields to `data/maps.json`.
- [ ] Template-created layout data writes only layout fields to `data/map_layouts/<map_id>.json`.
- [ ] Runtime consistency tests cover background, spawn points, obstacles, object position, and radius.
- [ ] Full test suite passes.
- [ ] Godot editor manual smoke test passes after editor restart.

