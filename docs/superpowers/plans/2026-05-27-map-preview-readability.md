# Map Preview Readability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Godot editor map previews readable by showing `名称 / 类型` labels on preview handles and adding a right Dock legend plus object list.

**Architecture:** Add a small preview type metadata helper so type colors, Chinese type labels, fallback names, and object summaries are computed in one place. Extend existing preview handles to store and draw labels without changing JSON data or runtime map behavior. Update the editor plugin Dock from current in-memory `map_data` so the legend and object list refresh with the generated preview.

**Tech Stack:** Godot 4.6, GDScript `@tool` editor plugin scripts, JSON-backed map data, project `tests/run_tests.gd` SceneTree test runner, PowerShell verification commands.

---

## Scope Check

This plan implements one focused subsystem: readability of the existing `addons/map_preview` editor preview. It does not change runtime map rendering, JSON schema, TileMap art, object creation, object deletion, or object-list click navigation.

The current worktree may already contain unrelated local edits:

```text
M assets/kenney_tiny-battle/Tiles/tile_mountain_bridge_hd.png.import
M project.godot
```

Implementation tasks must stage only the files named in each task.

---

## File Structure

- Create `addons/map_preview/map_preview_type_metadata.gd`  
  Central helper for object type normalization, Chinese type labels, colors, readable labels, and object summary rows.

- Create `tests/test_map_preview_type_metadata.gd`  
  Unit tests for type labels, fallback names, colors, and object summary data used by the Dock.

- Modify `tests/run_tests.gd`  
  Register the new metadata test suite.

- Modify `tests/test_map_preview_renderer.gd`  
  Assert that generated object, spawn, and obstacle handles carry readable label state.

- Modify `addons/map_preview/preview_handles/map_preview_handle.gd`  
  Store `type_label`, expose `get_label_text()`, and draw a readable label background, border, and text.

- Modify `addons/map_preview/preview_handles/map_object_handle.gd`  
  Use the metadata helper for object name fallback, type label, and type color.

- Modify `addons/map_preview/preview_handles/spawn_point_handle.gd`  
  Configure spawn handles as `出生点 / <spawn_id>`.

- Modify `addons/map_preview/preview_handles/obstacle_handle.gd`  
  Configure obstacle handles as `障碍 / <obstacle_id>`.

- Modify `addons/map_preview/map_preview_plugin.gd`  
  Add Dock fields for type legend and object list, refresh those fields from `map_data`, and make the manual refresh button reload `data/maps.json` before re-rendering.

- Modify `docs/godot-project-structure.md`  
  Document that the editor preview now shows labels, a type legend, and an object list.

---

### Task 1: Preview Type Metadata Helper

**Files:**
- Create: `addons/map_preview/map_preview_type_metadata.gd`
- Create: `tests/test_map_preview_type_metadata.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write the failing metadata tests**

Create `tests/test_map_preview_type_metadata.gd`:

```gdscript
extends RefCounted

const MapPreviewTypesScript = preload("res://addons/map_preview/map_preview_type_metadata.gd")

func run(assertions) -> void:
	_test_type_labels_and_colors(assertions)
	_test_object_label_fallback(assertions)
	_test_object_summary_rows_and_counts(assertions)

func _test_type_labels_and_colors(assertions) -> void:
	assertions.assert_eq(MapPreviewTypesScript.type_label("npc"), "NPC", "NPC 类型应显示为 NPC")
	assertions.assert_eq(MapPreviewTypesScript.type_label("battle_trigger"), "战斗", "战斗触发点应显示为战斗")
	assertions.assert_eq(MapPreviewTypesScript.type_label("exit"), "出口", "出口类型应显示为出口")
	assertions.assert_eq(MapPreviewTypesScript.type_label("unknown_type"), "对象", "未知类型应显示为对象")
	assertions.assert_eq(MapPreviewTypesScript.type_color("exit").to_html(false), "2f6fdd", "出口颜色应沿用现有蓝色")
	assertions.assert_eq(MapPreviewTypesScript.type_color("unknown_type").to_html(false), "666666", "未知类型应使用默认灰色")

func _test_object_label_fallback(assertions) -> void:
	var named = {"id": "npc_demo", "type": "npc", "name": "演示 NPC"}
	var unnamed = {"id": "exit_demo", "type": "exit"}
	assertions.assert_eq(MapPreviewTypesScript.object_display_name(named), "演示 NPC", "对象名称应优先使用 name")
	assertions.assert_eq(MapPreviewTypesScript.object_display_name(unnamed), "exit_demo", "缺少 name 时应回退 id")
	assertions.assert_eq(MapPreviewTypesScript.object_label(named), "演示 NPC / NPC", "对象标签应包含名称和类型")
	assertions.assert_eq(MapPreviewTypesScript.spawn_label("start"), "出生点 / start", "出生点标签应包含 spawn_id")
	assertions.assert_eq(MapPreviewTypesScript.obstacle_label("wall"), "障碍 / wall", "障碍标签应包含 obstacle_id")

func _test_object_summary_rows_and_counts(assertions) -> void:
	var summary = MapPreviewTypesScript.build_object_summary([
		{"id": "npc_demo", "type": "npc", "name": "演示 NPC"},
		{"id": "exit_demo", "type": "exit", "name": "演示出口"},
		{"id": "enemy_demo", "type": "battle_trigger", "name": "演示战斗"},
		{"id": "unknown_demo", "type": "unknown_type"}
	])
	var counts = summary.get("counts", {})
	var rows = summary.get("rows", [])
	assertions.assert_eq(counts.get("npc", 0), 1, "摘要应统计 NPC 数量")
	assertions.assert_eq(counts.get("exit", 0), 1, "摘要应统计出口数量")
	assertions.assert_eq(counts.get("battle_trigger", 0), 1, "摘要应统计战斗数量")
	assertions.assert_eq(counts.get("object", 0), 1, "未知类型应归入对象数量")
	assertions.assert_eq(rows.size(), 4, "摘要应保留所有合法对象行")
	assertions.assert_eq(rows[0].get("label", ""), "演示 NPC / NPC", "摘要行应包含可读标签")
	assertions.assert_eq(rows[3].get("name", ""), "unknown_demo", "未知类型对象缺少名称时应回退 id")
	assertions.assert_eq(rows[3].get("type_label", ""), "对象", "未知类型对象行应显示对象")
```

- [ ] **Step 2: Register the failing metadata suite**

Modify `tests/run_tests.gd`.

Add this preload after the existing `TestMapPreviewRendererScript` preload:

```gdscript
const TestMapPreviewTypeMetadataScript = preload("res://tests/test_map_preview_type_metadata.gd")
```

Add this suite entry immediately after `TestMapPreviewRendererScript.new(),`:

```gdscript
		TestMapPreviewTypeMetadataScript.new(),
```

- [ ] **Step 3: Run tests to verify the helper is missing**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL during preload because `res://addons/map_preview/map_preview_type_metadata.gd` does not exist.

- [ ] **Step 4: Implement the metadata helper**

Create `addons/map_preview/map_preview_type_metadata.gd`:

```gdscript
@tool
extends RefCounted

const TYPE_ORDER := ["npc", "battle_trigger", "exit", "shop", "pickup", "notice", "object"]
const TYPE_LABELS := {
	"npc": "NPC",
	"battle_trigger": "战斗",
	"exit": "出口",
	"shop": "商店",
	"pickup": "拾取",
	"notice": "提示",
	"object": "对象",
}
const TYPE_COLORS := {
	"npc": "#8d3b7a",
	"battle_trigger": "#8f3b2f",
	"exit": "#2f6fdd",
	"notice": "#c49a2c",
	"shop": "#3d7f5c",
	"pickup": "#7c6f3a",
	"object": "#666666",
}

static func normalize_type(object_type: String) -> String:
	var key = str(object_type).strip_edges()
	if TYPE_LABELS.has(key):
		return key
	return "object"

static func type_label(object_type: String) -> String:
	return str(TYPE_LABELS.get(normalize_type(object_type), "对象"))

static func type_color(object_type: String) -> Color:
	var color_text = str(TYPE_COLORS.get(normalize_type(object_type), "#666666"))
	return Color(color_text)

static func color_html(object_type: String) -> String:
	return type_color(object_type).to_html(false)

static func object_display_name(object_record: Dictionary) -> String:
	var display = str(object_record.get("name", "")).strip_edges()
	if not display.is_empty():
		return display
	return str(object_record.get("id", "")).strip_edges()

static func object_label(object_record: Dictionary) -> String:
	return "%s / %s" % [
		object_display_name(object_record),
		type_label(str(object_record.get("type", ""))),
	]

static func spawn_label(spawn_id: String) -> String:
	return "出生点 / %s" % str(spawn_id)

static func obstacle_label(obstacle_id: String) -> String:
	return "障碍 / %s" % str(obstacle_id)

static func build_object_summary(objects: Array) -> Dictionary:
	var counts := {}
	var rows := []
	for object_record in objects:
		if typeof(object_record) != TYPE_DICTIONARY:
			continue
		var object_id = str(object_record.get("id", "")).strip_edges()
		if object_id.is_empty():
			continue
		var type_key = normalize_type(str(object_record.get("type", "")))
		counts[type_key] = int(counts.get(type_key, 0)) + 1
		rows.append({
			"id": object_id,
			"name": object_display_name(object_record),
			"type": type_key,
			"type_label": type_label(type_key),
			"label": object_label(object_record),
			"color": color_html(type_key),
		})
	return {
		"counts": counts,
		"rows": rows,
	}
```

- [ ] **Step 5: Run tests to verify the helper passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with `测试通过：77 个测试套件`.

- [ ] **Step 6: Commit metadata helper**

Run:

```powershell
git status --short
git add -- addons/map_preview/map_preview_type_metadata.gd tests/test_map_preview_type_metadata.gd tests/run_tests.gd
git commit -m "feat: add map preview type metadata"
```

Expected: commit includes only the helper and tests. Do not stage `project.godot` or asset import files.

---

### Task 2: Readable Labels on Preview Handles

**Files:**
- Modify: `tests/test_map_preview_renderer.gd`
- Modify: `addons/map_preview/preview_handles/map_preview_handle.gd`
- Modify: `addons/map_preview/preview_handles/map_object_handle.gd`
- Modify: `addons/map_preview/preview_handles/spawn_point_handle.gd`
- Modify: `addons/map_preview/preview_handles/obstacle_handle.gd`

- [ ] **Step 1: Extend renderer tests for label state**

Modify `tests/test_map_preview_renderer.gd`.

Replace the `run` function with:

```gdscript
func run(assertions) -> void:
	_test_renderer_builds_preview_tree(assertions)
	_test_renderer_assigns_readable_labels(assertions)
	_test_renderer_clears_only_generated_preview(assertions)
```

Add this test after `_test_renderer_builds_preview_tree`:

```gdscript
func _test_renderer_assigns_readable_labels(assertions) -> void:
	var root = Node2D.new()
	var renderer = MapPreviewRendererScript.new()
	var map_data = {
		"objects": [
			{"id": "npc_demo", "type": "npc", "name": "演示 NPC"},
			{"id": "exit_demo", "type": "exit", "name": "演示出口"},
			{"id": "unknown_demo", "type": "mystery"}
		]
	}
	var layout = _sample_layout()
	layout["objects"]["unknown_demo"] = {"position": {"x": 110, "y": 120}, "radius": 32}
	renderer.render(root, map_data, layout)
	var preview = root.get_node_or_null("GeneratedMapPreview")
	if preview != null:
		var npc_handle = preview.get_node_or_null("Objects/npc_demo")
		var exit_handle = preview.get_node_or_null("Objects/exit_demo")
		var unknown_handle = preview.get_node_or_null("Objects/unknown_demo")
		var spawn_handle = preview.get_node_or_null("Spawns/start")
		var obstacle_handle = preview.get_node_or_null("Obstacles/wall")
		assertions.assert_eq(npc_handle.display_name, "演示 NPC", "NPC handle 应保存显示名称")
		assertions.assert_eq(npc_handle.type_label, "NPC", "NPC handle 应保存中文类型")
		assertions.assert_eq(npc_handle.get_label_text(), "演示 NPC / NPC", "NPC handle 标签应可读")
		assertions.assert_eq(exit_handle.get_label_text(), "演示出口 / 出口", "出口 handle 标签应可读")
		assertions.assert_eq(unknown_handle.get_label_text(), "unknown_demo / 对象", "未知类型 handle 应回退对象标签")
		assertions.assert_eq(spawn_handle.get_label_text(), "出生点 / start", "出生点 handle 标签应可读")
		assertions.assert_eq(obstacle_handle.get_label_text(), "障碍 / wall", "障碍 handle 标签应可读")
	root.free()
```

- [ ] **Step 2: Run tests to verify labels are not implemented**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because handles do not expose `type_label` and `get_label_text()`.

- [ ] **Step 3: Replace the base preview handle with label support**

Replace `addons/map_preview/preview_handles/map_preview_handle.gd` with:

```gdscript
@tool
extends Node2D

signal layout_changed(kind: String, layout_id: String, payload: Dictionary)

const LABEL_FONT_SIZE := 14
const LABEL_PADDING := Vector2(6.0, 4.0)
const LABEL_MAX_WIDTH := 220.0
const LABEL_MAX_CHARS := 28

var handle_kind: String = ""
var layout_id: String = ""
var display_name: String = ""
var type_label: String = ""
var color: Color = Color("#ffffff")
var radius := 16.0
var rect_size := Vector2.ZERO
var suppress_transform_signal := false

func setup(
	next_kind: String,
	next_id: String,
	next_name: String,
	next_position: Vector2,
	next_color: Color,
	next_type_label: String = ""
) -> void:
	suppress_transform_signal = true
	handle_kind = next_kind
	layout_id = next_id
	display_name = next_name
	type_label = next_type_label
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

func get_label_text() -> String:
	if display_name.is_empty() and type_label.is_empty():
		return ""
	if type_label.is_empty():
		return _trim_label(display_name)
	return _trim_label("%s / %s" % [display_name, type_label])

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
	_draw_label()

func _draw_label() -> void:
	var text = get_label_text()
	if text.is_empty():
		return
	var font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, LABEL_MAX_WIDTH, LABEL_FONT_SIZE)
	var label_size = text_size + LABEL_PADDING * 2.0
	var label_position = _label_position(label_size)
	var label_rect = Rect2(label_position, label_size)
	draw_rect(label_rect, Color(1.0, 1.0, 1.0, 0.88), true)
	draw_rect(label_rect, color, false, 1.5)
	draw_string(
		font,
		label_position + Vector2(LABEL_PADDING.x, LABEL_PADDING.y + LABEL_FONT_SIZE),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		LABEL_MAX_WIDTH,
		LABEL_FONT_SIZE,
		Color("#1f241f")
	)

func _label_position(label_size: Vector2) -> Vector2:
	if rect_size != Vector2.ZERO:
		return Vector2(4.0, 4.0)
	return Vector2(12.0, -label_size.y - 10.0)

func _trim_label(text: String) -> String:
	if text.length() <= LABEL_MAX_CHARS:
		return text
	return "%s..." % text.substr(0, LABEL_MAX_CHARS - 3)
```

- [ ] **Step 4: Wire object handles to type metadata**

Replace `addons/map_preview/preview_handles/map_object_handle.gd` with:

```gdscript
@tool
extends "res://addons/map_preview/preview_handles/map_preview_handle.gd"

const MapPreviewTypesScript = preload("res://addons/map_preview/map_preview_type_metadata.gd")

func setup_object(object_record: Dictionary, object_layout: Dictionary) -> void:
	var object_id = str(object_record.get("id", ""))
	var object_type = str(object_record.get("type", ""))
	var position_data = object_layout.get("position", object_record.get("position", {}))
	var position_value = Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
	setup(
		"object",
		object_id,
		MapPreviewTypesScript.object_display_name(object_record),
		position_value,
		MapPreviewTypesScript.type_color(object_type),
		MapPreviewTypesScript.type_label(object_type)
	)
	set_radius(float(object_layout.get("radius", object_record.get("radius", 48.0))))
```

- [ ] **Step 5: Wire spawn and obstacle handles to readable labels**

Replace `addons/map_preview/preview_handles/spawn_point_handle.gd` with:

```gdscript
@tool
extends "res://addons/map_preview/preview_handles/map_preview_handle.gd"

func setup_spawn(spawn_id: String, position_data: Dictionary) -> void:
	var position_value = Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
	setup("spawn", spawn_id, "出生点", position_value, Color("#ffffff"), spawn_id)
	set_radius(20.0)
```

Replace `addons/map_preview/preview_handles/obstacle_handle.gd` with:

```gdscript
@tool
extends "res://addons/map_preview/preview_handles/map_preview_handle.gd"

func setup_obstacle(obstacle: Dictionary) -> void:
	var obstacle_id = str(obstacle.get("id", ""))
	var rect = obstacle.get("rect", {})
	var position_value = Vector2(float(rect.get("x", 0.0)), float(rect.get("y", 0.0)))
	var size_value = Vector2(float(rect.get("w", 0.0)), float(rect.get("h", 0.0)))
	setup("obstacle", obstacle_id, "障碍", position_value, Color("#476f3f"), obstacle_id)
	set_rect_size(size_value)
```

- [ ] **Step 6: Run tests to verify labels pass**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with `测试通过：77 个测试套件`.

- [ ] **Step 7: Commit handle labels**

Run:

```powershell
git status --short
git add -- tests/test_map_preview_renderer.gd addons/map_preview/preview_handles/map_preview_handle.gd addons/map_preview/preview_handles/map_object_handle.gd addons/map_preview/preview_handles/spawn_point_handle.gd addons/map_preview/preview_handles/obstacle_handle.gd
git commit -m "feat: label map preview handles"
```

Expected: commit includes only renderer tests and preview handle scripts.

---

### Task 3: Dock Legend and Object List

**Files:**
- Modify: `addons/map_preview/map_preview_plugin.gd`

- [ ] **Step 1: Add plugin fields and metadata preload**

Modify the top of `addons/map_preview/map_preview_plugin.gd`.

Add this preload after `MapLayoutLoaderScript`:

```gdscript
const MapPreviewTypesScript = preload("res://addons/map_preview/map_preview_type_metadata.gd")
```

Add these vars after `var auto_refresh_check: CheckBox`:

```gdscript
var legend_label: RichTextLabel
var object_list_label: RichTextLabel
```

- [ ] **Step 2: Add Dock UI controls**

In `_build_dock()`, after the `buttons.add_child(reload_button)` line, insert:

```gdscript
	var readability_box = VBoxContainer.new()
	dock.add_child(readability_box)

	var legend_title = Label.new()
	legend_title.text = "类型图例"
	readability_box.add_child(legend_title)

	legend_label = RichTextLabel.new()
	legend_label.bbcode_enabled = true
	legend_label.fit_content = true
	legend_label.custom_minimum_size = Vector2(260, 72)
	readability_box.add_child(legend_label)

	var object_list_title = Label.new()
	object_list_title.text = "对象列表"
	readability_box.add_child(object_list_title)

	object_list_label = RichTextLabel.new()
	object_list_label.bbcode_enabled = true
	object_list_label.fit_content = true
	object_list_label.custom_minimum_size = Vector2(260, 160)
	readability_box.add_child(object_list_label)
```

- [ ] **Step 3: Make the refresh button reload map metadata**

In `_build_dock()`, replace this line:

```gdscript
	refresh_button.pressed.connect(_reload_selected_map)
```

with:

```gdscript
	refresh_button.pressed.connect(_manual_refresh_selected_map)
```

Add this function before `_reload_selected_map()`:

```gdscript
func _manual_refresh_selected_map() -> void:
	var current_map_id = selected_map_id
	_load_map_index()
	if not current_map_id.is_empty() and maps_by_id.has(current_map_id):
		_select_map_id(current_map_id)
	else:
		_refresh_from_current_scene()
```

- [ ] **Step 4: Refresh the readability panel after rendering**

In `_render_selected_map()`, replace the body with:

```gdscript
func _render_selected_map() -> void:
	var scene_root = _edited_scene_root()
	if scene_root == null:
		return
	var map_data = maps_by_id.get(selected_map_id, {})
	renderer.render(scene_root, map_data, document.get_layout())
	_update_validation(map_data, document.get_layout())
	_update_readability_panel(map_data)
```

Add these helper functions before `_update_validation()`:

```gdscript
func _update_readability_panel(map_data: Dictionary) -> void:
	if legend_label == null or object_list_label == null:
		return
	var summary = MapPreviewTypesScript.build_object_summary(map_data.get("objects", []))
	legend_label.text = _build_legend_text(summary.get("counts", {}))
	object_list_label.text = _build_object_list_text(summary.get("rows", []))

func _build_legend_text(counts: Dictionary) -> String:
	var lines := PackedStringArray()
	for type_key in MapPreviewTypesScript.TYPE_ORDER:
		var count = int(counts.get(type_key, 0))
		if count <= 0:
			continue
		lines.append("[color=#%s]■[/color] %s %d" % [
			MapPreviewTypesScript.color_html(type_key),
			MapPreviewTypesScript.type_label(type_key),
			count,
		])
	if lines.is_empty():
		lines.append("无对象")
	return "\n".join(lines)

func _build_object_list_text(rows: Array) -> String:
	var lines := PackedStringArray()
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		lines.append("[color=#%s]■[/color] %s / %s / %s" % [
			str(row.get("color", "666666")),
			_bbcode_escape(str(row.get("name", ""))),
			_bbcode_escape(str(row.get("type_label", ""))),
			_bbcode_escape(str(row.get("id", ""))),
		])
	if lines.is_empty():
		lines.append("无对象")
	return "\n".join(lines)

func _bbcode_escape(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")
```

- [ ] **Step 5: Run project load and full tests**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
Godot project load exits 0
测试通过：77 个测试套件
```

Godot may print existing expected `push_error` lines from negative-path tests. The test runner exit code must be `0`.

- [ ] **Step 6: Commit Dock readability panel**

Run:

```powershell
git status --short
git add -- addons/map_preview/map_preview_plugin.gd
git commit -m "feat: add map preview legend and object list"
```

Expected: commit includes only `addons/map_preview/map_preview_plugin.gd`.

---

### Task 4: Documentation and Final Verification

**Files:**
- Modify: `docs/godot-project-structure.md`

- [ ] **Step 1: Update map preview documentation**

In `docs/godot-project-structure.md`, in the `双向地图预览编辑器` section, add this paragraph after the paragraph that explains `GeneratedMapPreview`:

```markdown
预览节点会显示 `名称 / 类型` 标签，例如 `青衫客 / NPC`、`去山脚村 / 出口`。右侧 `地图预览` Dock 还会显示类型图例和对象列表，方便在不运行游戏的情况下判断每个点、圈和矩形对应的地图内容。
```

- [ ] **Step 2: Run final automated verification**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
& $godot --headless --path . -s tests/run_tests.gd
git status --short
```

Expected:

```text
Godot project load exits 0
测试通过：77 个测试套件
git status shows docs/godot-project-structure.md plus any unrelated pre-existing local edits
```

- [ ] **Step 3: Manual editor verification**

Run the editor:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64.exe"
& $godot --path .
```

Manual checks:

```text
1. Open scenes/mountain_pass.tscn.
2. Confirm GeneratedMapPreview appears under the scene root.
3. Confirm object handles show readable labels such as 青衫客 / NPC and exit labels ending in / 出口.
4. Confirm spawn handles show 出生点 / start or 出生点 / return_from_village.
5. Confirm obstacle rectangles show labels such as 障碍 / rock_north.
6. Confirm the 地图预览 Dock shows 类型图例 with counts.
7. Confirm the 地图预览 Dock shows 对象列表 with name / type / id rows.
8. Modify data/map_layouts/mountain_pass.json outside Godot by moving npc_qingshanke, wait up to 2 seconds, and confirm the label follows the moved handle.
9. Drag npc_qingshanke in the editor, click 保存, and confirm data/map_layouts/mountain_pass.json contains the new coordinates.
```

- [ ] **Step 4: Commit documentation**

Run:

```powershell
git status --short
git add -- docs/godot-project-structure.md
git commit -m "docs: document readable map preview labels"
```

Expected: commit includes only `docs/godot-project-structure.md`.

---

## Self-Review

- Spec coverage: Tasks 1 and 2 cover type labels, fallback names, colors, spawn labels, obstacle labels, and handle labels. Task 3 covers Dock type legend, object list, and manual refresh of `data/maps.json`. Task 4 covers documentation and manual verification.
- Data boundaries: No task changes `data/maps.json`, `data/map_layouts/*.json`, runtime map rendering, or `.tscn` scene contents.
- Test coverage: Type metadata has dedicated tests; renderer tests assert readable handle state; full project tests and project load run after plugin changes.
- Git hygiene: Every commit command stages exact paths and excludes the pre-existing `project.godot` and asset import changes.

