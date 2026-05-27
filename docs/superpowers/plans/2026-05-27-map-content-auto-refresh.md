# Map Content Auto Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Godot map preview editor automatically refresh when `data/maps.json` changes, without overwriting unsaved layout edits.

**Architecture:** Add a small `MapIndexDocument` helper that owns `data/maps.json` parsing, hash tracking, scene-path lookup, and preserve-on-invalid behavior. `MapPreviewPlugin` uses that helper during startup, manual refresh, and the existing 1-second editor polling loop, then rerenders the current map from the latest content data and the current in-memory layout. Existing `MapLayoutDocument` continues to own only `data/map_layouts/<map_id>.json` and its external-change conflict handling.

**Tech Stack:** Godot 4.6, GDScript `@tool` editor plugin, JSON data files, existing `tests/run_tests.gd` headless test runner, PowerShell verification commands.

---

## Scope

This plan implements only `data/maps.json` auto-refresh for the editor preview:

- Object name/type changes update labels, colors, legend, and object list.
- Object additions/removals update generated preview handles.
- Current selected object is reapplied when still present and cleared when removed.
- Invalid or temporarily unreadable `data/maps.json` preserves the last valid map index.
- Unsaved layout edits in `MapLayoutDocument` are not overwritten by a content refresh.

This plan does not add object creation UI, spawn/obstacle click selection, runtime map loading changes, automatic layout cleanup, or a diff viewer.

## File Structure

- Create `addons/map_preview/map_index_document.gd`
  Owns `data/maps.json` read/parse/hash state, map lookup dictionaries, and failure messages while preserving the last successful index on invalid input.

- Create `tests/test_map_index_document.gd`
  Covers parsing, hash change detection, preserve-on-invalid behavior, and external file change detection.

- Modify `tests/run_tests.gd`
  Registers the new map index document suite.

- Modify `addons/map_preview/map_preview_plugin.gd`
  Uses `MapIndexDocument` instead of direct `FileAccess.open("res://data/maps.json")`, checks map-index external changes during the existing polling loop, and rerenders current preview without reloading dirty layout data.

- Modify `docs/godot-project-structure.md`
  Documents that both layout JSON and map content JSON can refresh the editor preview.

## Task 1: Map Index Document Helper

**Files:**
- Create: `addons/map_preview/map_index_document.gd`
- Create: `tests/test_map_index_document.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write the failing map index tests**

Create `tests/test_map_index_document.gd`:

```gdscript
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
```

- [ ] **Step 2: Register the failing suite**

Modify `tests/run_tests.gd`.

Add this preload after `TestMapLayoutDocumentScript`:

```gdscript
const TestMapIndexDocumentScript = preload("res://tests/test_map_index_document.gd")
```

Add this suite after `TestMapLayoutDocumentScript.new()`:

```gdscript
		TestMapIndexDocumentScript.new(),
```

- [ ] **Step 3: Run tests to verify the helper is missing**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: exit code `1` or preload failure because `res://addons/map_preview/map_index_document.gd` does not exist yet.

- [ ] **Step 4: Implement `MapIndexDocument`**

Create `addons/map_preview/map_index_document.gd`:

```gdscript
@tool
extends RefCounted

const DEFAULT_PATH := "res://data/maps.json"

var path: String = DEFAULT_PATH
var maps_by_id: Dictionary = {}
var scene_path_to_map_id: Dictionary = {}
var loaded_hash := 0
var last_error := ""

func load_from_path(source_path: String = DEFAULT_PATH) -> bool:
	var file = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		last_error = "无法读取 data/maps.json。"
		return false
	return load_from_text(file.get_as_text(), source_path)

func load_from_text(text: String, source_path: String = DEFAULT_PATH) -> bool:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		last_error = "data/maps.json 必须是数组。"
		return false
	var next_maps_by_id := {}
	var next_scene_path_to_map_id := {}
	for map_data in parsed:
		if typeof(map_data) != TYPE_DICTIONARY:
			continue
		var map_id = str(map_data.get("id", "")).strip_edges()
		if map_id.is_empty():
			continue
		next_maps_by_id[map_id] = map_data
		var scene_path = str(map_data.get("scene_path", "")).strip_edges()
		if not scene_path.is_empty():
			next_scene_path_to_map_id[scene_path] = map_id
	path = source_path
	maps_by_id = next_maps_by_id
	scene_path_to_map_id = next_scene_path_to_map_id
	loaded_hash = _hash_text(text)
	last_error = ""
	return true

func has_text_change(text: String) -> bool:
	return _hash_text(text) != loaded_hash

func has_external_change() -> bool:
	return current_file_hash() != loaded_hash

func current_file_hash(source_path: String = "") -> int:
	var target_path = source_path if not source_path.is_empty() else path
	if target_path.is_empty():
		target_path = DEFAULT_PATH
	var file = FileAccess.open(target_path, FileAccess.READ)
	if file == null:
		return -1
	return _hash_text(file.get_as_text())

func get_maps_by_id() -> Dictionary:
	return maps_by_id.duplicate(true)

func get_scene_path_to_map_id() -> Dictionary:
	return scene_path_to_map_id.duplicate(true)

func _hash_text(text: String) -> int:
	return text.hash()
```

- [ ] **Step 5: Run tests to verify the helper passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: exit code `0` and output ending with `测试通过：78 个测试套件`. Existing negative-path tests may still print `push_error` lines; exit code `0` is the pass signal.

- [ ] **Step 6: Commit the map index helper**

Run:

```powershell
git add -- addons/map_preview/map_index_document.gd tests/test_map_index_document.gd tests/run_tests.gd
git commit -m "feat: add map index document helper"
```

## Task 2: Plugin Map Index Loading

**Files:**
- Modify: `addons/map_preview/map_preview_plugin.gd`

- [ ] **Step 1: Use `MapIndexDocument` for startup and manual refresh**

Modify `addons/map_preview/map_preview_plugin.gd`.

Add this preload after `MapLayoutDocumentScript`:

```gdscript
const MapIndexDocumentScript = preload("res://addons/map_preview/map_index_document.gd")
```

Add this constant after the preload block:

```gdscript
const MAP_INDEX_PATH := "res://data/maps.json"
```

Add `map_index` before `document`:

```gdscript
var selected_map_id := ""
var selected_object_id := ""
var map_index = MapIndexDocumentScript.new()
var document = MapLayoutDocumentScript.new()
```

Replace `_load_map_index` with:

```gdscript
func _load_map_index() -> bool:
	var restore_map_id = selected_map_id
	if not map_index.load_from_path(MAP_INDEX_PATH):
		_update_status(map_index.last_error)
		return false
	maps_by_id = map_index.get_maps_by_id()
	scene_path_to_map_id = map_index.get_scene_path_to_map_id()
	_rebuild_map_selector(restore_map_id)
	return true
```

Add these helpers after `_load_map_index`:

```gdscript
func _rebuild_map_selector(preferred_map_id: String) -> void:
	map_selector.clear()
	for map_id in maps_by_id.keys():
		map_selector.add_item(str(map_id))
	if not preferred_map_id.is_empty():
		_select_map_selector_item(preferred_map_id)

func _select_map_selector_item(map_id: String) -> void:
	for index in range(map_selector.get_item_count()):
		if map_selector.get_item_text(index) == map_id:
			map_selector.select(index)
			return
```

Replace `_select_map_id` with:

```gdscript
func _select_map_id(map_id: String) -> void:
	if selected_map_id != map_id:
		selected_object_id = ""
	selected_map_id = map_id
	_select_map_selector_item(map_id)
	_reload_selected_map()
```

Replace `_manual_refresh_selected_map` with:

```gdscript
func _manual_refresh_selected_map() -> void:
	var current_map_id = selected_map_id
	if not _load_map_index():
		return
	if not current_map_id.is_empty() and maps_by_id.has(current_map_id):
		_select_map_id(current_map_id)
	else:
		_refresh_from_current_scene()
```

- [ ] **Step 2: Run tests and editor-load smoke test**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --editor --quit
```

Expected: both commands exit `0`; test output ends with `测试通过：78 个测试套件`, and editor startup reaches `编辑器布局就绪。`

- [ ] **Step 3: Commit plugin map-index loading**

Run:

```powershell
git add -- addons/map_preview/map_preview_plugin.gd
git commit -m "feat: load map preview index through document"
```

## Task 3: Automatic `data/maps.json` Refresh

**Files:**
- Modify: `addons/map_preview/map_preview_plugin.gd`

- [ ] **Step 1: Check map-index changes in the polling loop**

In `_process`, replace:

```gdscript
	_refresh_if_scene_changed()
	if auto_refresh_check != null and auto_refresh_check.button_pressed and not selected_map_id.is_empty():
		_check_external_refresh()
```

With:

```gdscript
	_refresh_if_scene_changed()
	if auto_refresh_check != null and auto_refresh_check.button_pressed:
		_check_map_index_refresh()
		if not selected_map_id.is_empty():
			_check_external_refresh()
```

- [ ] **Step 2: Add map-index refresh helpers**

Add these functions before `_check_external_refresh`:

```gdscript
func _check_map_index_refresh() -> void:
	if not map_index.has_external_change():
		return
	var previous_map_id = selected_map_id
	var previous_object_id = selected_object_id
	if not _load_map_index():
		return
	_refresh_after_map_index_change(previous_map_id, previous_object_id)

func _refresh_after_map_index_change(previous_map_id: String, previous_object_id: String) -> void:
	var scene_root = _edited_scene_root()
	var scene_map_id := ""
	if scene_root != null:
		active_scene_path = scene_root.scene_file_path
		scene_map_id = str(scene_path_to_map_id.get(scene_root.scene_file_path, ""))
	if not scene_map_id.is_empty():
		if selected_map_id != scene_map_id:
			selected_object_id = ""
		else:
			selected_object_id = previous_object_id
		selected_map_id = scene_map_id
		_select_map_selector_item(scene_map_id)
		if document.map_id != scene_map_id:
			_reload_selected_map()
		else:
			_render_selected_map()
			if selected_object_id == previous_object_id:
				_update_status("地图内容已刷新：%s" % selected_map_id)
		return
	if not previous_map_id.is_empty() and maps_by_id.has(previous_map_id):
		selected_map_id = previous_map_id
		selected_object_id = previous_object_id
		_select_map_selector_item(selected_map_id)
		if document.map_id != selected_map_id:
			_reload_selected_map()
		else:
			_render_selected_map()
			if selected_object_id == previous_object_id:
				_update_status("地图内容已刷新：%s" % selected_map_id)
		return
	selected_map_id = ""
	selected_object_id = ""
	_clear_current_preview()
	_update_status("当前地图已从 data/maps.json 移除：%s" % previous_map_id)

func _clear_current_preview() -> void:
	var scene_root = _edited_scene_root()
	if scene_root != null:
		renderer.clear(scene_root)
	_update_readability_panel({})
	if validation_label != null:
		validation_label.text = ""
```

- [ ] **Step 3: Run tests and editor-load smoke test**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --editor --quit
```

Expected: both commands exit `0`; test output ends with `测试通过：78 个测试套件`, and editor startup reaches `编辑器布局就绪。`

- [ ] **Step 4: Manual editor acceptance for content refresh**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
Start-Process -FilePath $godot -ArgumentList "--path", "."
```

Check:

1. Open `scenes/mountain_pass.tscn`.
2. Confirm `地图预览` has `自动刷新外部修改` enabled.
3. In `data/maps.json`, change `npc_qingshanke.name` from `青衫客` to `青衫剑客`.
4. Wait up to 2 seconds; confirm the map label and object list update to `青衫剑客`.
5. Change `npc_qingshanke.type` from `npc` to `battle`; wait up to 2 seconds; confirm the label type, color, and legend counts update.
6. Add this temporary object to the current map `objects` array:

```json
{
	"id": "tmp_preview_refresh",
	"type": "pickup",
	"name": "预览刷新测试",
	"description": "临时验收对象"
}
```

7. Wait up to 2 seconds; confirm `tmp_preview_refresh` appears in the object list and preview.
8. Select `tmp_preview_refresh`, remove it from `data/maps.json`, then wait up to 2 seconds; confirm the preview node disappears and the status shows `选中对象已不存在：tmp_preview_refresh`.
9. Change `npc_qingshanke.name` back to `青衫客` and `npc_qingshanke.type` back to `npc`.
10. Select `npc_qingshanke` in the object list, drag it slightly, do not save, then change the name again in `data/maps.json`; confirm the label updates and the unsaved dragged position remains in the editor preview.
11. Restore `data/maps.json` and any layout file touched by the drag to their original content before committing.

- [ ] **Step 5: Commit automatic map content refresh**

Run:

```powershell
git status --short
git add -- addons/map_preview/map_preview_plugin.gd
git commit -m "feat: auto refresh map preview content"
```

Expected before `git add`: only `addons/map_preview/map_preview_plugin.gd` is modified. If manual acceptance left `data/maps.json` or layout files modified, restore those manual test edits before committing.

## Task 4: Documentation And Final Verification

**Files:**
- Modify: `docs/godot-project-structure.md`

- [ ] **Step 1: Update map preview documentation**

In `docs/godot-project-structure.md`, replace this paragraph:

```markdown
AI 修改布局文件后，插件会自动刷新预览。用户在编辑器中拖拽预览 handle 并点击保存后，插件会把新的坐标或尺寸写回同一个布局文件。运行时通过 `DataRepository.get_map()` 合并玩法数据和布局数据，所以编辑器预览与实际运行应保持一致。
```

With:

```markdown
AI 修改布局文件后，插件会自动刷新预览；AI 修改 `data/maps.json` 中的对象名称、类型、新增对象或删除对象后，插件也会自动刷新当前地图内容。用户在编辑器中拖拽预览 handle 并点击保存后，插件会把新的坐标或尺寸写回同一个布局文件。运行时通过 `DataRepository.get_map()` 合并玩法数据和布局数据，所以编辑器预览与实际运行应保持一致。
```

- [ ] **Step 2: Run final automated verification**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
& $godot --headless --path . --editor --quit
git status --short
```

Expected:

- Test command exits `0` and prints `测试通过：78 个测试套件`.
- Project load command exits `0`.
- Editor load command exits `0` and reaches `编辑器布局就绪。`
- `git status --short` shows only `docs/godot-project-structure.md` before the docs commit.

- [ ] **Step 3: Commit documentation**

Run:

```powershell
git add -- docs/godot-project-structure.md
git commit -m "docs: document map content auto refresh"
```

## Final Verification

Run:

```powershell
git status --short
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --editor --quit
```

Expected:

- `git status --short` is clean after all implementation commits.
- Test command exits `0` and prints `测试通过：78 个测试套件`.
- Editor-load smoke test exits `0` and reaches `编辑器布局就绪。`
