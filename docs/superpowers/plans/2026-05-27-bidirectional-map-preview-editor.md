# Bidirectional Map Preview Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Godot editor workflow where AI-edited map layout JSON refreshes in the editor, and editor micro-adjustments write back to the same layout JSON.

**Architecture:** Split map data into gameplay records in `data/maps.json` and layout records in `data/map_layouts/<map_id>.json`. Runtime merges layout data into existing map records through `DataRepository`, while an editor plugin renders non-saved preview handles under `GeneratedMapPreview` and writes handle movement back through a document layer.

**Tech Stack:** Godot 4.6, GDScript, JSON data files, `EditorPlugin`, `@tool` preview scripts, project-local `tests/run_tests.gd` headless test runner, PowerShell commands.

---

## References

- Design spec: `docs/superpowers/specs/2026-05-27-bidirectional-map-preview-editor-design.md`
- Current data loading: `scripts/systems/data_repository.gd`
- Current runtime map flow: `scripts/scenes/map_screen_base.gd`
- Current exploration maps: `scripts/scenes/mountain_pass_screen.gd`, `scripts/scenes/foot_village_screen.gd`, `scripts/scenes/road_outskirts_screen.gd`, `scripts/scenes/world_map_screen.gd`
- Current map data: `data/maps.json`, `data/world_map_config.json`
- Test runner: `tests/run_tests.gd`
- Godot editor plugin API anchors: `EditorPlugin.add_control_to_dock`, `_save_external_data`, and `_forward_canvas_gui_input` are documented in the official Godot 4 EditorPlugin class docs: https://docs.godotengine.org/en/stable/classes/class_editorplugin.html

## File Structure

Create:

- `data/map_layouts/mountain_pass.json` — layout truth for the mountain pass.
- `data/map_layouts/foot_village.json` — layout truth for the village.
- `data/map_layouts/road_outskirts.json` — layout truth for the road map.
- `data/map_layouts/world.json` — layout truth for world map size/background/spawn points.
- `scripts/systems/map_layout_loader.gd` — runtime-safe layout loading, validation, and map-record merging.
- `tests/test_map_layout_loader.gd` — tests for layout loading, merging, fallback, and validation.
- `tests/test_map_screen_layout.gd` — tests for data-driven terrain generation in `MapScreenBase`.
- `addons/map_preview/plugin.cfg` — Godot plugin descriptor.
- `addons/map_preview/map_layout_document.gd` — editor document layer for read/write, dirty state, conflict detection, and field updates.
- `addons/map_preview/map_preview_renderer.gd` — preview tree builder and clearer.
- `addons/map_preview/map_preview_plugin.gd` — `EditorPlugin` entry and Dock UI.
- `addons/map_preview/preview_handles/map_preview_handle.gd` — base `@tool` handle for editor movement notifications.
- `addons/map_preview/preview_handles/map_object_handle.gd` — object point/radius handle.
- `addons/map_preview/preview_handles/spawn_point_handle.gd` — spawn point handle.
- `addons/map_preview/preview_handles/obstacle_handle.gd` — rectangular obstacle handle.
- `tests/test_map_layout_document.gd` — tests for editor document updates and save behavior.
- `tests/test_map_preview_renderer.gd` — tests for preview generation and clearing.

Modify:

- `scripts/systems/data_repository.gd` — load and merge layout records before returning maps.
- `scripts/scenes/map_screen_base.gd` — create background and obstacles from layout data.
- `scripts/scenes/mountain_pass_screen.gd` — delegate terrain creation to base layout flow.
- `scripts/scenes/foot_village_screen.gd` — delegate terrain creation to base layout flow.
- `scripts/scenes/road_outskirts_screen.gd` — delegate terrain creation to base layout flow.
- `scripts/scenes/world_map_screen.gd` — use layout background size/color while keeping world regions/routes.
- `tests/run_tests.gd` — register new test suites.
- `docs/godot-project-structure.md` — document the new layout data and editor plugin workflow.

Do not modify:

- Unrelated Godot `.import` files unless the implementation itself changes imported assets.
- Gameplay fields in `data/maps.json` except to remove duplicated layout fields after runtime merge is proven. In this first implementation, keep existing `position`, `radius`, and `spawn_points` as fallback data.

## Test Commands

PowerShell:

```powershell
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

Generic shell:

```bash
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . --quit
```

Expected passing test output ends with:

```text
测试通过：N 个测试套件
```

`N` will increase as new suites are registered.

---

### Task 1: Layout Data, Loader, and Runtime Merge

**Files:**

- Create: `data/map_layouts/mountain_pass.json`
- Create: `data/map_layouts/foot_village.json`
- Create: `data/map_layouts/road_outskirts.json`
- Create: `data/map_layouts/world.json`
- Create: `scripts/systems/map_layout_loader.gd`
- Create: `tests/test_map_layout_loader.gd`
- Modify: `scripts/systems/data_repository.gd`
- Modify: `tests/test_map_data.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Add layout JSON files**

Create `data/map_layouts/mountain_pass.json`:

```json
{
  "map_id": "mountain_pass",
  "size": {"x": 1280, "y": 720},
  "background": {"mode": "color", "color": "#6f8f55"},
  "spawn_points": {
    "start": {"x": 160, "y": 320},
    "return_from_village": {"x": 1110, "y": 320}
  },
  "obstacles": [
    {"id": "border_top", "shape": "rect", "rect": {"x": 0, "y": 0, "w": 1280, "h": 24}},
    {"id": "border_bottom", "shape": "rect", "rect": {"x": 0, "y": 696, "w": 1280, "h": 24}},
    {"id": "border_left", "shape": "rect", "rect": {"x": 0, "y": 0, "w": 24, "h": 720}},
    {"id": "border_right", "shape": "rect", "rect": {"x": 1256, "y": 0, "w": 24, "h": 720}},
    {"id": "rock_north", "shape": "rect", "rect": {"x": 520, "y": 120, "w": 120, "h": 120}},
    {"id": "rock_southeast", "shape": "rect", "rect": {"x": 900, "y": 380, "w": 160, "h": 120}}
  ],
  "objects": {
    "exit_to_world_map": {"position": {"x": 460, "y": 280}, "radius": 72},
    "npc_qingshanke": {"position": {"x": 360, "y": 280}, "radius": 72},
    "npc_training_dummy": {"position": {"x": 520, "y": 430}, "radius": 64},
    "enemy_roaming_bandit": {"position": {"x": 620, "y": 520}, "radius": 56},
    "enemy_bandit_gate": {"position": {"x": 720, "y": 260}, "radius": 56},
    "exit_to_foot_village": {"position": {"x": 1160, "y": 320}, "radius": 72}
  },
  "decorations": []
}
```

Create `data/map_layouts/foot_village.json`:

```json
{
  "map_id": "foot_village",
  "size": {"x": 1280, "y": 720},
  "background": {"mode": "color", "color": "#7f8f6a"},
  "spawn_points": {
    "village_gate": {"x": 120, "y": 360},
    "return_from_mountain": {"x": 120, "y": 360},
    "main_street": {"x": 640, "y": 340},
    "return_from_world": {"x": 100, "y": 360}
  },
  "obstacles": [
    {"id": "border_top", "shape": "rect", "rect": {"x": 0, "y": 0, "w": 1280, "h": 24}},
    {"id": "border_bottom", "shape": "rect", "rect": {"x": 0, "y": 696, "w": 1280, "h": 24}},
    {"id": "border_left", "shape": "rect", "rect": {"x": 0, "y": 0, "w": 24, "h": 720}},
    {"id": "border_right", "shape": "rect", "rect": {"x": 1256, "y": 0, "w": 24, "h": 720}},
    {"id": "north_house_west", "shape": "rect", "rect": {"x": 420, "y": 120, "w": 180, "h": 110}},
    {"id": "north_house_east", "shape": "rect", "rect": {"x": 690, "y": 110, "w": 240, "h": 130}},
    {"id": "south_house_west", "shape": "rect", "rect": {"x": 360, "y": 500, "w": 180, "h": 100}},
    {"id": "south_house_east", "shape": "rect", "rect": {"x": 820, "y": 500, "w": 220, "h": 100}}
  ],
  "objects": {
    "exit_to_world_map": {"position": {"x": 20, "y": 360}, "radius": 72},
    "exit_to_mountain_pass": {"position": {"x": 64, "y": 360}, "radius": 72},
    "npc_porter_chen": {"position": {"x": 300, "y": 340}, "radius": 72},
    "notice_foot_village": {"position": {"x": 520, "y": 260}, "radius": 56},
    "npc_innkeeper_lu": {"position": {"x": 760, "y": 320}, "radius": 72},
    "shop_foot_village_pharmacy": {"position": {"x": 980, "y": 320}, "radius": 72},
    "exit_to_road_outskirts": {"position": {"x": 1180, "y": 360}, "radius": 72}
  },
  "decorations": []
}
```

Create `data/map_layouts/road_outskirts.json`:

```json
{
  "map_id": "road_outskirts",
  "size": {"x": 1280, "y": 720},
  "background": {"mode": "color", "color": "#6f7658"},
  "spawn_points": {
    "from_foot_village": {"x": 120, "y": 360}
  },
  "obstacles": [
    {"id": "border_top", "shape": "rect", "rect": {"x": 0, "y": 0, "w": 1280, "h": 24}},
    {"id": "border_bottom", "shape": "rect", "rect": {"x": 0, "y": 696, "w": 1280, "h": 24}},
    {"id": "border_left", "shape": "rect", "rect": {"x": 0, "y": 0, "w": 24, "h": 720}},
    {"id": "border_right", "shape": "rect", "rect": {"x": 1256, "y": 0, "w": 24, "h": 720}},
    {"id": "roadside_rocks_west", "shape": "rect", "rect": {"x": 360, "y": 130, "w": 160, "h": 90}},
    {"id": "roadside_rocks_east", "shape": "rect", "rect": {"x": 760, "y": 470, "w": 180, "h": 100}}
  ],
  "objects": {
    "pickup_roadside_bundle": {"position": {"x": 620, "y": 340}, "radius": 56},
    "notice_road_outskirts_sign": {"position": {"x": 260, "y": 300}, "radius": 56},
    "npc_road_scholar": {"position": {"x": 900, "y": 300}, "radius": 72}
  },
  "decorations": []
}
```

Create `data/map_layouts/world.json`:

```json
{
  "map_id": "world",
  "size": {"x": 4000, "y": 3000},
  "background": {"mode": "color", "color": "#f4ebd0"},
  "spawn_points": {
    "from_village": {"x": 1800, "y": 1500}
  },
  "obstacles": [],
  "objects": {},
  "decorations": []
}
```

- [ ] **Step 2: Write failing layout loader tests**

Create `tests/test_map_layout_loader.gd`:

```gdscript
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
```

- [ ] **Step 3: Register the failing test suite**

Modify `tests/run_tests.gd`:

Add the preload near the other `const Test...Script` lines:

```gdscript
const TestMapLayoutLoaderScript = preload("res://tests/test_map_layout_loader.gd")
```

Add the suite immediately after `TestMapDataScript.new()`:

```gdscript
		TestMapLayoutLoaderScript.new(),
```

- [ ] **Step 4: Run tests to verify the new loader test fails**

Run:

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `res://scripts/systems/map_layout_loader.gd` does not exist yet.

- [ ] **Step 5: Implement `MapLayoutLoader`**

Create `scripts/systems/map_layout_loader.gd`:

```gdscript
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
	return value.has("x") and value.has("y") and (typeof(value.get("x")) == TYPE_INT or typeof(value.get("x")) == TYPE_FLOAT) and (typeof(value.get("y")) == TYPE_INT or typeof(value.get("y")) == TYPE_FLOAT)
```

- [ ] **Step 6: Wire `DataRepository` to merge layouts**

Modify `scripts/systems/data_repository.gd`:

Add the preload and member near the top:

```gdscript
const MapLayoutLoaderScript = preload("res://scripts/systems/map_layout_loader.gd")

var layout_loader = MapLayoutLoaderScript.new()
```

Replace `get_map` with:

```gdscript
func get_map(map_id: String) -> Dictionary:
	var map_data = _find_by_id("maps", map_id)
	if map_data.is_empty():
		return {}
	return layout_loader.merge_map_layout(map_data, layout_loader.get_layout(map_id))
```

- [ ] **Step 7: Extend existing map data assertions**

Modify `tests/test_map_data.gd` inside the existing `run(assertions)` function after the `world` assertions:

```gdscript
	var mountain = repository.get_map("mountain_pass")
	assertions.assert_eq(mountain.get("layout", {}).get("obstacles", []).size(), 6, "山道地图应合并布局障碍")
	assertions.assert_eq(_find_object(mountain, "exit_to_foot_village").get("position", {}).get("x", 0), 1160, "山道出口坐标应来自布局合并")
```

If `_find_object` is not already defined in `tests/test_map_data.gd`, add this helper at the bottom:

```gdscript
func _find_object(map_data: Dictionary, object_id: String) -> Dictionary:
	for object in map_data.get("objects", []):
		if str(object.get("id", "")) == object_id:
			return object
	return {}
```

- [ ] **Step 8: Run tests and project import**

Run:

```powershell
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

Expected: PASS. If Godot refreshes `.import` files, inspect them before staging; only include import changes caused by newly added assets, which this task should not create.

- [ ] **Step 9: Commit Task 1**

Run:

```powershell
git add -- data/map_layouts scripts/systems/map_layout_loader.gd scripts/systems/data_repository.gd tests/test_map_layout_loader.gd tests/test_map_data.gd tests/run_tests.gd
git commit -m "feat: add map layout data merge"
```

---

### Task 2: Data-Driven Runtime Terrain

**Files:**

- Create: `tests/test_map_screen_layout.gd`
- Modify: `scripts/scenes/map_screen_base.gd`
- Modify: `scripts/scenes/mountain_pass_screen.gd`
- Modify: `scripts/scenes/foot_village_screen.gd`
- Modify: `scripts/scenes/road_outskirts_screen.gd`
- Modify: `scripts/scenes/world_map_screen.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write failing terrain tests**

Create `tests/test_map_screen_layout.gd`:

```gdscript
extends RefCounted

const MapScreenBaseScript = preload("res://scripts/scenes/map_screen_base.gd")
const MountainPassScreenScript = preload("res://scripts/scenes/mountain_pass_screen.gd")
const FootVillageScreenScript = preload("res://scripts/scenes/foot_village_screen.gd")
const RoadOutskirtsScreenScript = preload("res://scripts/scenes/road_outskirts_screen.gd")

func run(assertions) -> void:
	_test_base_creates_layout_background_and_obstacles(assertions)
	_test_map_scenes_delegate_terrain_to_layout(assertions)

func _test_base_creates_layout_background_and_obstacles(assertions) -> void:
	var screen = MapScreenBaseScript.new()
	screen.map_data = {
		"layout": {
			"size": {"x": 320, "y": 180},
			"background": {"mode": "color", "color": "#123456"},
			"obstacles": [
				{"id": "test_wall", "shape": "rect", "rect": {"x": 10, "y": 20, "w": 30, "h": 40}}
			]
		}
	}
	screen._create_terrain()
	var background = screen.get_node_or_null("Background")
	assertions.assert_true(background is ColorRect, "布局地形应创建 Background 节点")
	assertions.assert_eq(background.size, Vector2(320, 180), "背景尺寸应来自布局")
	assertions.assert_eq(background.color.to_html(false), Color("#123456").to_html(false), "背景颜色应来自布局")
	assertions.assert_eq(_count_static_bodies(screen), 1, "布局地形应创建一个障碍碰撞体")
	screen.free()

func _test_map_scenes_delegate_terrain_to_layout(assertions) -> void:
	var mountain = MountainPassScreenScript.new()
	mountain.map_data = _layout_with_obstacles("#6f8f55", 2)
	mountain._create_terrain()
	assertions.assert_eq(_count_static_bodies(mountain), 2, "山道场景应使用布局障碍")
	mountain.free()

	var village = FootVillageScreenScript.new()
	village.map_data = _layout_with_obstacles("#7f8f6a", 3)
	village._create_terrain()
	assertions.assert_eq(_count_static_bodies(village), 3, "村镇场景应使用布局障碍")
	village.free()

	var road = RoadOutskirtsScreenScript.new()
	road.map_data = _layout_with_obstacles("#6f7658", 1)
	road._create_terrain()
	assertions.assert_eq(_count_static_bodies(road), 1, "官道场景应使用布局障碍")
	road.free()

func _layout_with_obstacles(color: String, count: int) -> Dictionary:
	var obstacles := []
	for index in range(count):
		obstacles.append({"id": "obstacle_%d" % index, "shape": "rect", "rect": {"x": 10 + index * 20, "y": 20, "w": 12, "h": 14}})
	return {
		"layout": {
			"size": {"x": 1280, "y": 720},
			"background": {"mode": "color", "color": color},
			"obstacles": obstacles
		}
	}

func _count_static_bodies(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is StaticBody2D:
			count += 1
	return count
```

- [ ] **Step 2: Register the failing terrain suite**

Modify `tests/run_tests.gd`:

Add preload:

```gdscript
const TestMapScreenLayoutScript = preload("res://tests/test_map_screen_layout.gd")
```

Add suite after `TestMapStateAndFlowScript.new()`:

```gdscript
		TestMapScreenLayoutScript.new(),
```

- [ ] **Step 3: Run tests to verify failure**

Run:

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `Background` is not named and hard-coded map scripts still add fixed obstacles.

- [ ] **Step 4: Update `MapScreenBase` terrain helpers**

Modify `scripts/scenes/map_screen_base.gd`.

Replace `_create_terrain`, `_add_background`, and `_add_obstacle` with:

```gdscript
func _create_terrain() -> void:
	var layout = _get_layout_data()
	var size = _read_size(layout.get("size", {}), Vector2(1280, 720))
	_add_background(size)
	for obstacle in layout.get("obstacles", []):
		if typeof(obstacle) != TYPE_DICTIONARY:
			continue
		if str(obstacle.get("shape", "rect")) != "rect":
			continue
		var rect = _read_rect(obstacle.get("rect", {}))
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		_add_obstacle(rect)

func _add_background(size: Vector2) -> void:
	var terrain = TileMapLayer.new()
	terrain.name = "Terrain"
	add_child(terrain)

	var background = ColorRect.new()
	background.name = "Background"
	background.color = _read_background_color(_get_layout_data().get("background", {}))
	background.size = size
	background.position = Vector2.ZERO
	add_child(background)
	move_child(background, 0)

func _add_obstacle(rect: Rect2) -> void:
	var body = StaticBody2D.new()
	body.name = "ObstacleBody"
	body.position = rect.position
	var shape = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.size / 2.0
	body.add_child(shape)
	add_child(body)

	var visual = ColorRect.new()
	visual.name = "ObstacleVisual"
	visual.color = obstacle_color
	visual.position = rect.position
	visual.size = rect.size
	add_child(visual)
```

Add these helpers below `_add_obstacle`:

```gdscript
func _get_layout_data() -> Dictionary:
	var layout = map_data.get("layout", {})
	if typeof(layout) == TYPE_DICTIONARY:
		return layout
	return {}

func _read_size(value: Variant, fallback: Vector2) -> Vector2:
	if typeof(value) != TYPE_DICTIONARY:
		return fallback
	var width = float(value.get("x", fallback.x))
	var height = float(value.get("y", fallback.y))
	if width <= 0.0 or height <= 0.0:
		return fallback
	return Vector2(width, height)

func _read_rect(value: Variant) -> Rect2:
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	return Rect2(
		float(value.get("x", 0.0)),
		float(value.get("y", 0.0)),
		float(value.get("w", 0.0)),
		float(value.get("h", 0.0))
	)

func _read_background_color(value: Variant) -> Color:
	if typeof(value) != TYPE_DICTIONARY:
		return background_color
	if str(value.get("mode", "color")) != "color":
		return background_color
	var html = str(value.get("color", ""))
	if html.is_empty() or not Color.html_is_valid(html):
		return background_color
	return Color(html)
```

- [ ] **Step 5: Delegate exploration map terrain to base class**

Replace `_create_terrain` in `scripts/scenes/mountain_pass_screen.gd` with:

```gdscript
func _create_terrain() -> void:
	super._create_terrain()
```

Replace `_create_terrain` in `scripts/scenes/foot_village_screen.gd` with:

```gdscript
func _create_terrain() -> void:
	super._create_terrain()
```

Replace `_create_terrain` in `scripts/scenes/road_outskirts_screen.gd` with:

```gdscript
func _create_terrain() -> void:
	super._create_terrain()
```

- [ ] **Step 6: Update world map terrain to use layout**

Modify `_create_terrain` in `scripts/scenes/world_map_screen.gd`:

```gdscript
func _create_terrain() -> void:
	super._create_terrain()
```

Keep `_draw_world_elements` unchanged so region polygons and routes still draw after the base background.

- [ ] **Step 7: Run tests and project import**

Run:

```powershell
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

Expected: PASS. Manually confirm that no runtime map now receives duplicate hard-coded obstacles.

- [ ] **Step 8: Commit Task 2**

Run:

```powershell
git add -- scripts/scenes/map_screen_base.gd scripts/scenes/mountain_pass_screen.gd scripts/scenes/foot_village_screen.gd scripts/scenes/road_outskirts_screen.gd scripts/scenes/world_map_screen.gd tests/test_map_screen_layout.gd tests/run_tests.gd
git commit -m "feat: drive map terrain from layouts"
```

---

### Task 3: Editor Document Layer

**Files:**

- Create: `addons/map_preview/map_layout_document.gd`
- Create: `tests/test_map_layout_document.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write failing document tests**

Create `tests/test_map_layout_document.gd`:

```gdscript
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
	assertions.assert_eq(layout.get("obstacles", [])[0].get("rect", {}).get("w", 0), 3.0, "文档应更新障碍宽度")
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
```

- [ ] **Step 2: Register the failing document suite**

Modify `tests/run_tests.gd`:

Add preload:

```gdscript
const TestMapLayoutDocumentScript = preload("res://tests/test_map_layout_document.gd")
```

Add suite after `TestMapLayoutLoaderScript.new()`:

```gdscript
		TestMapLayoutDocumentScript.new(),
```

- [ ] **Step 3: Run tests to verify failure**

Run:

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `addons/map_preview/map_layout_document.gd` does not exist yet.

- [ ] **Step 4: Implement `MapLayoutDocument`**

Create `addons/map_preview/map_layout_document.gd`:

```gdscript
@tool
extends RefCounted

var map_id: String = ""
var path: String = ""
var layout: Dictionary = {}
var loaded_hash: int = 0
var dirty := false

func load_map(next_map_id: String) -> bool:
	return load_from_path(next_map_id, "res://data/map_layouts/%s.json" % next_map_id)

func load_from_path(next_map_id: String, next_path: String) -> bool:
	var loaded = load_json(next_path)
	if loaded.is_empty():
		return false
	load_from_data(next_map_id, loaded, next_path)
	return true

func load_from_data(next_map_id: String, next_layout: Dictionary, next_path: String) -> void:
	map_id = next_map_id
	path = next_path
	layout = next_layout.duplicate(true)
	loaded_hash = _hash_layout(layout)
	dirty = false

func get_layout() -> Dictionary:
	return layout

func is_dirty() -> bool:
	return dirty

func has_external_change() -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var disk_layout = load_json(path)
	if disk_layout.is_empty():
		return false
	return _hash_layout(disk_layout) != loaded_hash

func update_object_position(object_id: String, position: Vector2) -> void:
	if object_id.is_empty():
		return
	var objects = _ensure_dictionary("objects")
	var object_layout = objects.get(object_id, {})
	if typeof(object_layout) != TYPE_DICTIONARY:
		object_layout = {}
	object_layout["position"] = _vector_to_dictionary(position)
	objects[object_id] = object_layout
	_mark_dirty()

func update_object_radius(object_id: String, radius: float) -> void:
	if object_id.is_empty() or radius <= 0.0:
		return
	var objects = _ensure_dictionary("objects")
	var object_layout = objects.get(object_id, {})
	if typeof(object_layout) != TYPE_DICTIONARY:
		object_layout = {}
	object_layout["radius"] = radius
	objects[object_id] = object_layout
	_mark_dirty()

func update_spawn_position(spawn_id: String, position: Vector2) -> void:
	if spawn_id.is_empty():
		return
	var spawn_points = _ensure_dictionary("spawn_points")
	spawn_points[spawn_id] = _vector_to_dictionary(position)
	_mark_dirty()

func update_obstacle_rect(obstacle_id: String, rect: Rect2) -> void:
	if obstacle_id.is_empty() or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var obstacles = layout.get("obstacles", [])
	if typeof(obstacles) != TYPE_ARRAY:
		obstacles = []
	for index in range(obstacles.size()):
		var obstacle = obstacles[index]
		if typeof(obstacle) == TYPE_DICTIONARY and str(obstacle.get("id", "")) == obstacle_id:
			var copy = obstacle.duplicate(true)
			copy["shape"] = "rect"
			copy["rect"] = _rect_to_dictionary(rect)
			obstacles[index] = copy
			layout["obstacles"] = obstacles
			_mark_dirty()
			return

func save() -> bool:
	if path.is_empty():
		return false
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入布局文件：%s" % path)
		return false
	file.store_string(JSON.stringify(layout, "\t"))
	file.close()
	loaded_hash = _hash_layout(layout)
	dirty = false
	return true

func load_json(source_path: String) -> Dictionary:
	var file = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _ensure_dictionary(key: String) -> Dictionary:
	var value = layout.get(key, {})
	if typeof(value) != TYPE_DICTIONARY:
		value = {}
	layout[key] = value
	return value

func _mark_dirty() -> void:
	dirty = true

func _vector_to_dictionary(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}

func _rect_to_dictionary(value: Rect2) -> Dictionary:
	return {"x": value.position.x, "y": value.position.y, "w": value.size.x, "h": value.size.y}

func _hash_layout(value: Dictionary) -> int:
	return JSON.stringify(value, "\t").hash()
```

- [ ] **Step 5: Run tests**

Run:

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS.

- [ ] **Step 6: Commit Task 3**

Run:

```powershell
git add -- addons/map_preview/map_layout_document.gd tests/test_map_layout_document.gd tests/run_tests.gd
git commit -m "feat: add map layout editor document"
```

---

### Task 4: Preview Renderer and Editor Handles

**Files:**

- Create: `addons/map_preview/map_preview_renderer.gd`
- Create: `addons/map_preview/preview_handles/map_preview_handle.gd`
- Create: `addons/map_preview/preview_handles/map_object_handle.gd`
- Create: `addons/map_preview/preview_handles/spawn_point_handle.gd`
- Create: `addons/map_preview/preview_handles/obstacle_handle.gd`
- Create: `tests/test_map_preview_renderer.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write failing renderer tests**

Create `tests/test_map_preview_renderer.gd`:

```gdscript
extends RefCounted

const MapPreviewRendererScript = preload("res://addons/map_preview/map_preview_renderer.gd")

func run(assertions) -> void:
	_test_renderer_builds_preview_tree(assertions)
	_test_renderer_clears_only_generated_preview(assertions)

func _test_renderer_builds_preview_tree(assertions) -> void:
	var root = Node2D.new()
	var renderer = MapPreviewRendererScript.new()
	var map_data = {
		"objects": [
			{"id": "npc_demo", "type": "npc", "name": "演示 NPC"},
			{"id": "exit_demo", "type": "exit", "name": "演示出口"}
		]
	}
	var layout = _sample_layout()
	renderer.render(root, map_data, layout)
	var preview = root.get_node_or_null("GeneratedMapPreview")
	assertions.assert_true(preview != null, "渲染器应创建 GeneratedMapPreview")
	assertions.assert_true(preview.get_meta("map_preview_generated", false), "预览根节点应带生成标记")
	assertions.assert_true(preview.get_node_or_null("Objects/npc_demo") != null, "渲染器应创建对象 handle")
	assertions.assert_true(preview.get_node_or_null("Spawns/start") != null, "渲染器应创建出生点 handle")
	assertions.assert_true(preview.get_node_or_null("Obstacles/wall") != null, "渲染器应创建障碍 handle")
	root.free()

func _test_renderer_clears_only_generated_preview(assertions) -> void:
	var root = Node2D.new()
	var user_node = Node2D.new()
	user_node.name = "UserNode"
	root.add_child(user_node)
	var renderer = MapPreviewRendererScript.new()
	renderer.render(root, {"objects": []}, _sample_layout())
	renderer.clear(root)
	assertions.assert_true(root.get_node_or_null("UserNode") != null, "清理预览时不应删除用户节点")
	assertions.assert_true(root.get_node_or_null("GeneratedMapPreview") == null, "清理预览时应删除生成预览节点")
	root.free()

func _sample_layout() -> Dictionary:
	return {
		"map_id": "demo",
		"size": {"x": 320, "y": 180},
		"background": {"mode": "color", "color": "#123456"},
		"spawn_points": {"start": {"x": 10, "y": 20}},
		"obstacles": [{"id": "wall", "shape": "rect", "rect": {"x": 30, "y": 40, "w": 50, "h": 60}}],
		"objects": {
			"npc_demo": {"position": {"x": 70, "y": 80}, "radius": 48},
			"exit_demo": {"position": {"x": 90, "y": 100}, "radius": 72}
		},
		"decorations": []
	}
```

- [ ] **Step 2: Register the failing renderer suite**

Modify `tests/run_tests.gd`:

Add preload:

```gdscript
const TestMapPreviewRendererScript = preload("res://tests/test_map_preview_renderer.gd")
```

Add suite after `TestMapLayoutDocumentScript.new()`:

```gdscript
		TestMapPreviewRendererScript.new(),
```

- [ ] **Step 3: Run tests to verify failure**

Run:

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because preview renderer and handles do not exist yet.

- [ ] **Step 4: Implement base preview handle**

Create `addons/map_preview/preview_handles/map_preview_handle.gd`:

```gdscript
@tool
extends Node2D

signal layout_changed(kind: String, layout_id: String, payload: Dictionary)

var handle_kind: String = ""
var layout_id: String = ""
var display_name: String = ""
var color: Color = Color("#ffffff")
var radius := 16.0
var rect_size := Vector2.ZERO
var suppress_transform_signal := false

func setup(next_kind: String, next_id: String, next_name: String, next_position: Vector2, next_color: Color) -> void:
	suppress_transform_signal = true
	handle_kind = next_kind
	layout_id = next_id
	display_name = next_name
	color = next_color
	name = next_id
	position = next_position
	set_meta("map_preview_generated", true)
	set_notify_transform(true)
	suppress_transform_signal = false
	queue_redraw()

func set_radius(next_radius: float) -> void:
	radius = max(next_radius, 1.0)
	queue_redraw()

func set_rect_size(next_size: Vector2) -> void:
	rect_size = next_size
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and not suppress_transform_signal:
		layout_changed.emit(handle_kind, layout_id, {"position": {"x": position.x, "y": position.y}})

func _draw() -> void:
	if rect_size != Vector2.ZERO:
		draw_rect(Rect2(Vector2.ZERO, rect_size), Color(color.r, color.g, color.b, 0.22), true)
		draw_rect(Rect2(Vector2.ZERO, rect_size), color, false, 2.0)
	else:
		draw_circle(Vector2.ZERO, 8.0, color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color.r, color.g, color.b, 0.55), 2.0)
```

- [ ] **Step 5: Implement typed handles**

Create `addons/map_preview/preview_handles/map_object_handle.gd`:

```gdscript
@tool
extends "res://addons/map_preview/preview_handles/map_preview_handle.gd"

func setup_object(object_record: Dictionary, object_layout: Dictionary) -> void:
	var object_id = str(object_record.get("id", ""))
	var position_data = object_layout.get("position", object_record.get("position", {}))
	var position_value = Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
	setup("object", object_id, str(object_record.get("name", object_id)), position_value, _type_color(str(object_record.get("type", ""))))
	set_radius(float(object_layout.get("radius", object_record.get("radius", 48.0))))

func _type_color(object_type: String) -> Color:
	match object_type:
		"npc":
			return Color("#8d3b7a")
		"battle_trigger":
			return Color("#8f3b2f")
		"exit":
			return Color("#2f6fdd")
		"notice":
			return Color("#c49a2c")
		"shop":
			return Color("#3d7f5c")
		"pickup":
			return Color("#7c6f3a")
		_:
			return Color("#666666")
```

Create `addons/map_preview/preview_handles/spawn_point_handle.gd`:

```gdscript
@tool
extends "res://addons/map_preview/preview_handles/map_preview_handle.gd"

func setup_spawn(spawn_id: String, position_data: Dictionary) -> void:
	var position_value = Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
	setup("spawn", spawn_id, spawn_id, position_value, Color("#ffffff"))
	set_radius(20.0)
```

Create `addons/map_preview/preview_handles/obstacle_handle.gd`:

```gdscript
@tool
extends "res://addons/map_preview/preview_handles/map_preview_handle.gd"

func setup_obstacle(obstacle: Dictionary) -> void:
	var rect = obstacle.get("rect", {})
	var position_value = Vector2(float(rect.get("x", 0.0)), float(rect.get("y", 0.0)))
	var size_value = Vector2(float(rect.get("w", 0.0)), float(rect.get("h", 0.0)))
	setup("obstacle", str(obstacle.get("id", "")), str(obstacle.get("id", "")), position_value, Color("#476f3f"))
	set_rect_size(size_value)
```

- [ ] **Step 6: Implement preview renderer**

Create `addons/map_preview/map_preview_renderer.gd`:

```gdscript
@tool
extends RefCounted

const MapObjectHandleScript = preload("res://addons/map_preview/preview_handles/map_object_handle.gd")
const SpawnPointHandleScript = preload("res://addons/map_preview/preview_handles/spawn_point_handle.gd")
const ObstacleHandleScript = preload("res://addons/map_preview/preview_handles/obstacle_handle.gd")

signal handle_changed(kind: String, layout_id: String, payload: Dictionary)

func render(scene_root: Node, map_data: Dictionary, layout: Dictionary) -> Node2D:
	clear(scene_root)
	var preview = Node2D.new()
	preview.name = "GeneratedMapPreview"
	preview.set_meta("map_preview_generated", true)
	scene_root.add_child(preview)

	var background = _create_background(layout)
	preview.add_child(background)

	var obstacles = Node2D.new()
	obstacles.name = "Obstacles"
	preview.add_child(obstacles)
	for obstacle in layout.get("obstacles", []):
		if typeof(obstacle) != TYPE_DICTIONARY:
			continue
		var handle = ObstacleHandleScript.new()
		handle.setup_obstacle(obstacle)
		handle.layout_changed.connect(_on_handle_changed)
		obstacles.add_child(handle)

	var spawns = Node2D.new()
	spawns.name = "Spawns"
	preview.add_child(spawns)
	for spawn_id in layout.get("spawn_points", {}).keys():
		var handle = SpawnPointHandleScript.new()
		handle.setup_spawn(str(spawn_id), layout.get("spawn_points", {}).get(spawn_id, {}))
		handle.layout_changed.connect(_on_handle_changed)
		spawns.add_child(handle)

	var objects = Node2D.new()
	objects.name = "Objects"
	preview.add_child(objects)
	var object_layouts = layout.get("objects", {})
	for object_record in map_data.get("objects", []):
		if typeof(object_record) != TYPE_DICTIONARY:
			continue
		var object_id = str(object_record.get("id", ""))
		if object_id.is_empty():
			continue
		var handle = MapObjectHandleScript.new()
		handle.setup_object(object_record, object_layouts.get(object_id, {}))
		handle.layout_changed.connect(_on_handle_changed)
		objects.add_child(handle)
	return preview

func clear(scene_root: Node) -> void:
	var existing = scene_root.get_node_or_null("GeneratedMapPreview")
	if existing != null and existing.get_meta("map_preview_generated", false):
		scene_root.remove_child(existing)
		existing.free()

func _create_background(layout: Dictionary) -> ColorRect:
	var background = ColorRect.new()
	background.name = "Background"
	var size_data = layout.get("size", {})
	background.size = Vector2(float(size_data.get("x", 1280.0)), float(size_data.get("y", 720.0)))
	var background_data = layout.get("background", {})
	var color = str(background_data.get("color", "#334433"))
	background.color = Color(color) if Color.html_is_valid(color) else Color("#334433")
	return background

func _on_handle_changed(kind: String, layout_id: String, payload: Dictionary) -> void:
	handle_changed.emit(kind, layout_id, payload)
```

- [ ] **Step 7: Run tests**

Run:

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS.

- [ ] **Step 8: Commit Task 4**

Run:

```powershell
git add -- addons/map_preview/map_preview_renderer.gd addons/map_preview/preview_handles tests/test_map_preview_renderer.gd tests/run_tests.gd
git commit -m "feat: render editable map previews"
```

---

### Task 5: Editor Plugin Dock, Refresh, Save, and Conflict Flow

**Files:**

- Create: `addons/map_preview/plugin.cfg`
- Create: `addons/map_preview/map_preview_plugin.gd`
- Modify: `project.godot` if plugin activation is intentionally committed

- [ ] **Step 1: Create plugin descriptor**

Create `addons/map_preview/plugin.cfg`:

```ini
[plugin]

name="Map Preview"
description="Preview and edit data-driven map layouts inside the Godot editor."
author="Project"
version="0.1.0"
script="res://addons/map_preview/map_preview_plugin.gd"
```

- [ ] **Step 2: Implement plugin Dock and preview orchestration**

Create `addons/map_preview/map_preview_plugin.gd`:

```gdscript
@tool
extends EditorPlugin

const MapLayoutDocumentScript = preload("res://addons/map_preview/map_layout_document.gd")
const MapPreviewRendererScript = preload("res://addons/map_preview/map_preview_renderer.gd")
const MapLayoutLoaderScript = preload("res://scripts/systems/map_layout_loader.gd")

var dock: VBoxContainer
var map_selector: OptionButton
var status_label: Label
var validation_label: RichTextLabel
var refresh_button: Button
var save_button: Button
var reload_button: Button
var auto_refresh_check: CheckBox
var object_id_input: LineEdit
var radius_spin: SpinBox
var obstacle_id_input: LineEdit
var obstacle_width_spin: SpinBox
var obstacle_height_spin: SpinBox
var selected_map_id := ""
var document = MapLayoutDocumentScript.new()
var renderer = MapPreviewRendererScript.new()
var layout_loader = MapLayoutLoaderScript.new()
var maps_by_id: Dictionary = {}
var scene_path_to_map_id: Dictionary = {}
var poll_elapsed := 0.0

func _enter_tree() -> void:
	_build_dock()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	renderer.handle_changed.connect(_on_preview_handle_changed)
	_load_map_index()
	set_process(true)
	_refresh_from_current_scene()

func _exit_tree() -> void:
	set_process(false)
	var scene_root = _edited_scene_root()
	if scene_root != null:
		renderer.clear(scene_root)
	if dock != null:
		remove_control_from_docks(dock)
		dock.queue_free()

func _process(delta: float) -> void:
	poll_elapsed += delta
	if poll_elapsed < 1.0:
		return
	poll_elapsed = 0.0
	if auto_refresh_check != null and auto_refresh_check.button_pressed and not selected_map_id.is_empty():
		_check_external_refresh()

func _save_external_data() -> void:
	if document.is_dirty() and not document.has_external_change():
		document.save()
		_update_status("已随项目保存布局。")

func _build_dock() -> void:
	dock = VBoxContainer.new()
	dock.name = "MapPreviewDock"

	var title = Label.new()
	title.text = "地图预览"
	dock.add_child(title)

	map_selector = OptionButton.new()
	map_selector.item_selected.connect(_on_map_selected)
	dock.add_child(map_selector)

	auto_refresh_check = CheckBox.new()
	auto_refresh_check.text = "自动刷新外部修改"
	auto_refresh_check.button_pressed = true
	dock.add_child(auto_refresh_check)

	var buttons = HBoxContainer.new()
	dock.add_child(buttons)

	refresh_button = Button.new()
	refresh_button.text = "刷新"
	refresh_button.pressed.connect(_reload_selected_map)
	buttons.add_child(refresh_button)

	save_button = Button.new()
	save_button.text = "保存"
	save_button.pressed.connect(_save_document)
	buttons.add_child(save_button)

	reload_button = Button.new()
	reload_button.text = "重载外部版本"
	reload_button.pressed.connect(_reload_selected_map)
	buttons.add_child(reload_button)

	var object_box = VBoxContainer.new()
	dock.add_child(object_box)

	var object_title = Label.new()
	object_title.text = "对象半径"
	object_box.add_child(object_title)

	object_id_input = LineEdit.new()
	object_id_input.placeholder_text = "object_id"
	object_box.add_child(object_id_input)

	radius_spin = SpinBox.new()
	radius_spin.min_value = 1.0
	radius_spin.max_value = 512.0
	radius_spin.step = 1.0
	radius_spin.value = 48.0
	object_box.add_child(radius_spin)

	var radius_button = Button.new()
	radius_button.text = "应用半径"
	radius_button.pressed.connect(_apply_object_radius)
	object_box.add_child(radius_button)

	var obstacle_box = VBoxContainer.new()
	dock.add_child(obstacle_box)

	var obstacle_title = Label.new()
	obstacle_title.text = "障碍尺寸"
	obstacle_box.add_child(obstacle_title)

	obstacle_id_input = LineEdit.new()
	obstacle_id_input.placeholder_text = "obstacle_id"
	obstacle_box.add_child(obstacle_id_input)

	obstacle_width_spin = SpinBox.new()
	obstacle_width_spin.min_value = 1.0
	obstacle_width_spin.max_value = 4096.0
	obstacle_width_spin.step = 1.0
	obstacle_width_spin.value = 64.0
	obstacle_box.add_child(obstacle_width_spin)

	obstacle_height_spin = SpinBox.new()
	obstacle_height_spin.min_value = 1.0
	obstacle_height_spin.max_value = 4096.0
	obstacle_height_spin.step = 1.0
	obstacle_height_spin.value = 64.0
	obstacle_box.add_child(obstacle_height_spin)

	var obstacle_button = Button.new()
	obstacle_button.text = "应用尺寸"
	obstacle_button.pressed.connect(_apply_obstacle_size)
	obstacle_box.add_child(obstacle_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = "等待地图场景。"
	dock.add_child(status_label)

	validation_label = RichTextLabel.new()
	validation_label.bbcode_enabled = true
	validation_label.fit_content = true
	validation_label.custom_minimum_size = Vector2(260, 120)
	dock.add_child(validation_label)

func _load_map_index() -> void:
	maps_by_id.clear()
	scene_path_to_map_id.clear()
	map_selector.clear()
	var file = FileAccess.open("res://data/maps.json", FileAccess.READ)
	if file == null:
		_update_status("无法读取 data/maps.json。")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		_update_status("data/maps.json 必须是数组。")
		return
	for map_data in parsed:
		if typeof(map_data) != TYPE_DICTIONARY:
			continue
		var map_id = str(map_data.get("id", ""))
		if map_id.is_empty():
			continue
		maps_by_id[map_id] = map_data
		scene_path_to_map_id[str(map_data.get("scene_path", ""))] = map_id
		map_selector.add_item(map_id)

func _refresh_from_current_scene() -> void:
	var scene_root = _edited_scene_root()
	if scene_root == null:
		_update_status("当前没有打开地图场景。")
		return
	var scene_file_path = scene_root.scene_file_path
	var map_id = str(scene_path_to_map_id.get(scene_file_path, ""))
	if map_id.is_empty():
		_update_status("当前场景未匹配到 data/maps.json 中的地图。")
		return
	_select_map_id(map_id)

func _select_map_id(map_id: String) -> void:
	selected_map_id = map_id
	for index in range(map_selector.get_item_count()):
		if map_selector.get_item_text(index) == map_id:
			map_selector.select(index)
			break
	_reload_selected_map()

func _reload_selected_map() -> void:
	if selected_map_id.is_empty():
		return
	if not document.load_map(selected_map_id):
		_update_status("无法加载布局：%s" % selected_map_id)
		return
	_render_selected_map()
	_update_status("已刷新：%s" % selected_map_id)

func _render_selected_map() -> void:
	var scene_root = _edited_scene_root()
	if scene_root == null:
		return
	var map_data = maps_by_id.get(selected_map_id, {})
	renderer.render(scene_root, map_data, document.get_layout())
	_update_validation(map_data, document.get_layout())

func _check_external_refresh() -> void:
	if not document.has_external_change():
		return
	if document.is_dirty():
		_update_status("布局文件有外部修改，且编辑器内有未保存修改。请选择保存或重载。")
		return
	_reload_selected_map()

func _save_document() -> void:
	if selected_map_id.is_empty():
		return
	if document.has_external_change() and document.is_dirty():
		_update_status("检测到外部修改。请先重载外部版本，或再次确认后手动保存当前版本。")
		return
	if document.save():
		_update_status("已保存布局：%s" % selected_map_id)
	else:
		_update_status("保存失败：%s" % selected_map_id)

func _on_map_selected(index: int) -> void:
	_select_map_id(map_selector.get_item_text(index))

func _on_preview_handle_changed(kind: String, layout_id: String, payload: Dictionary) -> void:
	var position_data = payload.get("position", {})
	var position = Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
	match kind:
		"object":
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

func _apply_object_radius() -> void:
	var object_id = object_id_input.text.strip_edges()
	if object_id.is_empty():
		_update_status("请输入对象编号。")
		return
	document.update_object_radius(object_id, float(radius_spin.value))
	_render_selected_map()
	_update_status("有未保存半径修改：%s" % object_id)

func _apply_obstacle_size() -> void:
	var obstacle_id = obstacle_id_input.text.strip_edges()
	if obstacle_id.is_empty():
		_update_status("请输入障碍编号。")
		return
	var current_rect = _find_obstacle_rect(obstacle_id)
	if current_rect.size == Vector2.ZERO:
		_update_status("找不到障碍：%s" % obstacle_id)
		return
	current_rect.size = Vector2(float(obstacle_width_spin.value), float(obstacle_height_spin.value))
	document.update_obstacle_rect(obstacle_id, current_rect)
	_render_selected_map()
	_update_status("有未保存障碍尺寸修改：%s" % obstacle_id)

func _find_obstacle_rect(obstacle_id: String) -> Rect2:
	for obstacle in document.get_layout().get("obstacles", []):
		if typeof(obstacle) != TYPE_DICTIONARY or str(obstacle.get("id", "")) != obstacle_id:
			continue
		var rect = obstacle.get("rect", {})
		return Rect2(float(rect.get("x", 0.0)), float(rect.get("y", 0.0)), float(rect.get("w", 0.0)), float(rect.get("h", 0.0)))
	return Rect2()

func _update_validation(map_data: Dictionary, layout: Dictionary) -> void:
	var errors = layout_loader.validate_layout(layout, map_data)
	if errors.is_empty():
		validation_label.text = "[color=green]校验通过[/color]"
	else:
		validation_label.text = "[color=red]%s[/color]" % "\n".join(errors)

func _update_status(message: String) -> void:
	if status_label != null:
		status_label.text = message

func _edited_scene_root() -> Node:
	return get_editor_interface().get_edited_scene_root()
```

- [ ] **Step 3: Decide plugin activation policy**

Use the Godot editor to enable the plugin from Project Settings > Plugins.

If enabling the plugin modifies `project.godot`, inspect the diff. Commit the plugin activation only if the team wants every checkout to have the plugin enabled by default.

Expected `project.godot` addition if committed:

```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/map_preview/plugin.cfg")
```

- [ ] **Step 4: Run headless load and tests**

Run:

```powershell
& $godot --headless --path . --quit
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS. Headless project load should not fail because editor plugin scripts are parseable.

- [ ] **Step 5: Manual editor verification for auto refresh**

1. Open Godot editor.
2. Enable `Map Preview` plugin if it is not already enabled.
3. Open `scenes/mountain_pass.tscn`.
4. Confirm the Dock selects `mountain_pass`.
5. Confirm `GeneratedMapPreview` appears under the scene root.
6. Edit `data/map_layouts/mountain_pass.json` outside Godot:

```json
"npc_qingshanke": {"position": {"x": 390, "y": 280}, "radius": 72}
```

7. Wait up to 2 seconds.
8. Confirm the `npc_qingshanke` preview handle moves to x `390`.
9. Revert the value to x `360` and confirm preview refreshes again.

- [ ] **Step 6: Manual editor verification for drag-save**

1. In Godot editor, select `GeneratedMapPreview/Objects/npc_qingshanke`.
2. Move it with the native 2D move tool.
3. Confirm Dock status says there are unsaved changes.
4. Enter `npc_qingshanke` in the object id input, set radius to `80`, and click `应用半径`.
5. Enter `rock_north` in the obstacle id input, set width to `140`, height to `120`, and click `应用尺寸`.
6. Click `保存`.
7. Confirm `data/map_layouts/mountain_pass.json` contains the new coordinate, radius `80`, and `rock_north` width `140`.
8. Reopen `scenes/mountain_pass.tscn` and confirm the coordinate, radius ring, and obstacle rectangle persist.
9. Restore `npc_qingshanke` radius to `72` and `rock_north` width to `120` before committing unless the visual adjustment is intentional.

- [ ] **Step 7: Manual conflict verification**

1. Move `GeneratedMapPreview/Objects/npc_qingshanke` in the editor.
2. Do not save.
3. Modify `data/map_layouts/mountain_pass.json` outside Godot.
4. Wait up to 2 seconds.
5. Confirm Dock reports an external modification conflict and does not silently overwrite the editor movement.
6. Click `重载外部版本` and confirm the preview matches the file.

- [ ] **Step 8: Commit Task 5**

If plugin activation is not committed:

```powershell
git add -- addons/map_preview/plugin.cfg addons/map_preview/map_preview_plugin.gd
git commit -m "feat: add map preview editor plugin"
```

If plugin activation is committed:

```powershell
git add -- addons/map_preview/plugin.cfg addons/map_preview/map_preview_plugin.gd project.godot
git commit -m "feat: add map preview editor plugin"
```

---

### Task 6: Documentation and Final Verification

**Files:**

- Modify: `docs/godot-project-structure.md`

- [ ] **Step 1: Document the map layout workflow**

Add this section to `docs/godot-project-structure.md` after the existing map-slice sections:

```markdown
## 双向地图预览编辑器

探索地图布局使用 `data/map_layouts/<map_id>.json` 保存地图尺寸、背景、出生点、障碍物、对象坐标和交互半径。`data/maps.json` 继续保存任务、对白、战斗、奖励、商店和出口目标等玩法字段。

Godot 编辑器插件位于 `addons/map_preview/`。打开地图场景后，插件会根据 `data/maps.json` 的 `scene_path` 匹配 `map_id`，读取布局文件并在场景根节点下生成 `GeneratedMapPreview`。这些预览节点只用于编辑器预览和微调，默认不作为正式 `.tscn` 内容提交。

AI 修改布局文件后，插件会自动刷新预览。用户在编辑器中拖拽预览 handle 并点击保存后，插件会把新的坐标或尺寸写回同一个布局文件。运行时通过 `DataRepository.get_map()` 合并玩法数据和布局数据，所以编辑器预览与实际运行应保持一致。
```

- [ ] **Step 2: Run full automated verification**

Run:

```powershell
& $godot --headless --path . --quit
& $godot --headless --path . -s tests/run_tests.gd
git status --short
```

Expected:

- Godot project load exits `0`.
- Test runner prints `测试通过：N 个测试套件`.
- `git status --short` shows only intended changes before the final commit.

- [ ] **Step 3: Manual runtime verification**

1. Run the game from Godot.
2. Start or load into `mountain_pass`.
3. Confirm the background and obstacles appear as before.
4. Confirm `npc_qingshanke`, `enemy_bandit_gate`, and `exit_to_foot_village` are positioned according to `data/map_layouts/mountain_pass.json`.
5. Move `npc_qingshanke` by editing the layout JSON, save, rerun the map, and confirm runtime position changes.
6. Restore the original coordinate before committing unless the coordinate change is intentional.

- [ ] **Step 4: Commit Task 6**

Run:

```powershell
git add -- docs/godot-project-structure.md
git commit -m "docs: document map layout editor workflow"
```

- [ ] **Step 5: Final review**

Run:

```powershell
git log --oneline -6
git status --short
```

Expected:

- Recent commits include the Task 1 through Task 6 commits.
- No unrelated files are staged.
- Any remaining dirty files are either known pre-existing Godot import changes or deliberate implementation changes.

## Implementation Notes

- Keep `data/maps.json` layout fields during this implementation as fallback data. Removing duplicate position/radius fields belongs in a separate cleanup after the plugin has been used for a while.
- Editor preview nodes should be generated nodes with `map_preview_generated` metadata and no reliance on saved `.tscn` state.
- The first version uses native Godot 2D node movement for drag editing. The handle scripts listen for transform changes and update the document through the renderer signal.
- Radius and obstacle size editing are exposed through Dock text inputs plus spin boxes. The document tests verify `update_object_radius` and `update_obstacle_rect`; manual editor verification confirms those controls write back to JSON.
- The plugin must never delete nodes unless they are named `GeneratedMapPreview` and have `map_preview_generated == true`.
- If manual editor verification reveals that generated nodes cannot be selected when `owner` is unset, leave `owner` unset and use scene-tree selection. If selection still fails, add a Dock list of handles with numeric x/y controls before adding custom `_forward_canvas_gui_input` drag handling.

## Spec Coverage Self-Review

- AI external edits auto-refresh: Task 5 Steps 2 and 5.
- Editor drag micro-adjustment and JSON save: Task 3 document updates, Task 4 transform handles, Task 5 Steps 2 and 6.
- Single layout data truth: Task 1 layout files and DataRepository merge.
- Runtime/editor consistency: Task 2 terrain runtime and Task 6 runtime verification.
- Conflict handling: Task 3 external-change detection and Task 5 Step 7.
- Validation errors: Task 1 validation tests and Task 5 Dock validation label.
- First-version scope: no TileSet brush, no scene baking, no field-level merge.
