# Map Preview Object Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Godot map preview object list clickable so selecting a row highlights the generated object handle, fills the object edit fields, and selects the matching Godot editor node.

**Architecture:** Keep `data/maps.json` and `data/map_layouts/*.json` unchanged. `MapPreviewHandle` owns transient visual selection state, `MapPreviewPlugin` owns the currently selected `object_id`, rebuilds the Dock object list as buttons, and reapplies the selected object after every preview render. `MapPreviewRenderer` keeps producing stable paths such as `GeneratedMapPreview/Objects/<object_id>`.

**Tech Stack:** Godot 4.6, GDScript `@tool` editor plugin, existing headless GDScript test runner, existing map preview addon under `addons/map_preview/`.

---

## Scope

Build only first-version object selection:

- Supports clicking rows for `GeneratedMapPreview/Objects/<object_id>`.
- Keeps map data schemas and runtime map behavior unchanged.
- Does not center or zoom the 2D editor viewport.
- Does not make spawn points or obstacles clickable from the object list.
- Preserves the selected object after refresh when the object still exists.
- Clears the selection and shows `选中对象已不存在：<object_id>` when refresh removes the object.

## File Structure

- Modify `tests/test_map_preview_renderer.gd`
  Adds coverage for the new `selected` state on generated object handles.

- Modify `addons/map_preview/preview_handles/map_preview_handle.gd`
  Adds transient `selected` state, `set_selected()`, and selected drawing widths.

- Modify `addons/map_preview/map_preview_plugin.gd`
  Replaces the read-only `object_list_label` with a clickable `object_list_container`, stores `selected_object_id`, applies handle highlight, fills object edit controls, selects the Godot node, and reapplies selection after render.

- Modify `docs/godot-project-structure.md`
  Documents that the object list can select and highlight generated preview objects.

## Task 1: Handle Selected State

**Files:**
- Modify: `tests/test_map_preview_renderer.gd`
- Modify: `addons/map_preview/preview_handles/map_preview_handle.gd`

- [ ] **Step 1: Write the failing renderer test**

Modify `tests/test_map_preview_renderer.gd`.

Replace the `run` function with:

```gdscript
func run(assertions) -> void:
	_test_renderer_builds_preview_tree(assertions)
	_test_renderer_assigns_readable_labels(assertions)
	_test_renderer_handle_selection_state(assertions)
	_test_renderer_clears_only_generated_preview(assertions)
```

Add this function after `_test_renderer_assigns_readable_labels`:

```gdscript
func _test_renderer_handle_selection_state(assertions) -> void:
	var root = Node2D.new()
	var renderer = MapPreviewRendererScript.new()
	var map_data = {
		"objects": [
			{"id": "npc_demo", "type": "npc", "name": "演示 NPC"}
		]
	}
	var layout = _sample_layout()
	renderer.render(root, map_data, layout)
	var preview = root.get_node_or_null("GeneratedMapPreview")
	if preview != null:
		var npc_handle = preview.get_node_or_null("Objects/npc_demo")
		assertions.assert_true(npc_handle != null, "渲染器应创建可选中的对象 handle")
		if npc_handle != null:
			assertions.assert_false(npc_handle.selected, "对象 handle 初始不应处于选中状态")
			assertions.assert_eq(npc_handle.get_label_text(), "演示 NPC / NPC", "选中前标签文本应保持可读")
			npc_handle.set_selected(true)
			assertions.assert_true(npc_handle.selected, "set_selected(true) 应设置选中状态")
			assertions.assert_eq(npc_handle.get_label_text(), "演示 NPC / NPC", "选中状态不应改变标签文本")
			npc_handle.set_selected(false)
			assertions.assert_false(npc_handle.selected, "set_selected(false) 应清除选中状态")
	root.free()
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: exit code `1` with a failure or parse error because `MapPreviewHandle` does not yet expose `selected` and `set_selected()`.

- [ ] **Step 3: Implement selected state and selected drawing**

Modify `addons/map_preview/preview_handles/map_preview_handle.gd`.

Replace the constant block at the top with:

```gdscript
const LABEL_FONT_SIZE := 14
const LABEL_PADDING := Vector2(6.0, 4.0)
const LABEL_MAX_WIDTH := 220.0
const LABEL_MAX_CHARS := 28
const DEFAULT_CENTER_RADIUS := 8.0
const SELECTED_CENTER_RADIUS := 11.0
const DEFAULT_RADIUS_LINE_WIDTH := 2.0
const SELECTED_RADIUS_LINE_WIDTH := 4.0
const DEFAULT_RECT_LINE_WIDTH := 2.0
const SELECTED_RECT_LINE_WIDTH := 4.0
const DEFAULT_LABEL_BORDER_WIDTH := 1.5
const SELECTED_LABEL_BORDER_WIDTH := 3.0
const SELECTED_BORDER_COLOR := Color("#f7d154")
```

Add `selected` next to the other state variables:

```gdscript
var handle_kind: String = ""
var layout_id: String = ""
var display_name: String = ""
var type_label: String = ""
var color: Color = Color("#ffffff")
var radius := 16.0
var rect_size := Vector2.ZERO
var selected := false
var suppress_transform_signal := false
```

Add this function after `set_rect_size`:

```gdscript
func set_selected(next_selected: bool) -> void:
	if selected == next_selected:
		return
	selected = next_selected
	queue_redraw()
```

Replace `_draw` with:

```gdscript
func _draw() -> void:
	var border_color = SELECTED_BORDER_COLOR if selected else color
	if rect_size != Vector2.ZERO:
		var border_width = SELECTED_RECT_LINE_WIDTH if selected else DEFAULT_RECT_LINE_WIDTH
		draw_rect(Rect2(Vector2.ZERO, rect_size), Color(color.r, color.g, color.b, 0.22), true)
		draw_rect(Rect2(Vector2.ZERO, rect_size), border_color, false, border_width)
	else:
		var center_radius = SELECTED_CENTER_RADIUS if selected else DEFAULT_CENTER_RADIUS
		var radius_line_width = SELECTED_RADIUS_LINE_WIDTH if selected else DEFAULT_RADIUS_LINE_WIDTH
		var radius_alpha = 0.85 if selected else 0.55
		draw_circle(Vector2.ZERO, center_radius, color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color.r, color.g, color.b, radius_alpha), radius_line_width)
	_draw_label()
```

Replace `_draw_label` with:

```gdscript
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
	var border_color = SELECTED_BORDER_COLOR if selected else color
	var border_width = SELECTED_LABEL_BORDER_WIDTH if selected else DEFAULT_LABEL_BORDER_WIDTH
	draw_rect(label_rect, Color(1.0, 1.0, 1.0, 0.88), true)
	draw_rect(label_rect, border_color, false, border_width)
	draw_string(
		font,
		label_position + Vector2(LABEL_PADDING.x, LABEL_PADDING.y + LABEL_FONT_SIZE),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		LABEL_MAX_WIDTH,
		LABEL_FONT_SIZE,
		Color("#1f241f")
	)
```

- [ ] **Step 4: Run the test and verify it passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: exit code `0` and output ending with `测试通过：77 个测试套件`.

- [ ] **Step 5: Commit handle selected state**

Run:

```powershell
git add -- tests/test_map_preview_renderer.gd addons/map_preview/preview_handles/map_preview_handle.gd
git commit -m "feat: add map preview handle selection state"
```

## Task 2: Clickable Object List UI

**Files:**
- Modify: `addons/map_preview/map_preview_plugin.gd`

- [ ] **Step 1: Replace object list storage variables**

Modify the Dock variable section in `addons/map_preview/map_preview_plugin.gd`.

Replace:

```gdscript
var legend_label: RichTextLabel
var object_list_label: RichTextLabel
var object_id_input: LineEdit
```

With:

```gdscript
var legend_label: RichTextLabel
var object_list_container: VBoxContainer
var object_id_input: LineEdit
```

- [ ] **Step 2: Replace the read-only object list control**

In `_build_dock`, replace this block:

```gdscript
	object_list_label = RichTextLabel.new()
	object_list_label.bbcode_enabled = true
	object_list_label.fit_content = true
	object_list_label.custom_minimum_size = Vector2(260, 160)
	readability_box.add_child(object_list_label)
```

With:

```gdscript
	var object_list_scroll = ScrollContainer.new()
	object_list_scroll.custom_minimum_size = Vector2(260, 180)
	readability_box.add_child(object_list_scroll)

	object_list_container = VBoxContainer.new()
	object_list_scroll.add_child(object_list_container)
```

- [ ] **Step 3: Rebuild the object list as buttons**

Replace `_update_readability_panel` with:

```gdscript
func _update_readability_panel(map_data: Dictionary) -> void:
	if legend_label == null or object_list_container == null:
		return
	var summary = MapPreviewTypesScript.build_object_summary(map_data.get("objects", []))
	legend_label.text = _build_legend_text(summary.get("counts", {}))
	_rebuild_object_list(summary.get("rows", []))
```

Delete `_build_object_list_text` and `_bbcode_escape`.

Add these functions after `_build_legend_text`:

```gdscript
func _rebuild_object_list(rows: Array) -> void:
	for child in object_list_container.get_children():
		object_list_container.remove_child(child)
		child.queue_free()
	if rows.is_empty():
		var empty_label = Label.new()
		empty_label.text = "无对象"
		object_list_container.add_child(empty_label)
		return
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		object_list_container.add_child(_build_object_list_button(row))

func _build_object_list_button(row: Dictionary) -> Button:
	var object_id = str(row.get("id", ""))
	var button = Button.new()
	button.text = _object_list_button_text(row)
	button.tooltip_text = object_id
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(260, 28)
	button.pressed.connect(_on_object_list_item_pressed.bind(object_id))
	return button

func _object_list_button_text(row: Dictionary) -> String:
	var object_id = str(row.get("id", ""))
	var marker = ">" if object_id == selected_object_id else " "
	return "%s ■ %s / %s / %s" % [
		marker,
		str(row.get("name", "")),
		str(row.get("type_label", "")),
		object_id,
	]

func _on_object_list_item_pressed(object_id: String) -> void:
	_select_preview_object(object_id)

func _refresh_object_list_selection_state() -> void:
	if selected_map_id.is_empty():
		return
	_update_readability_panel(maps_by_id.get(selected_map_id, {}))
```

- [ ] **Step 4: Run the test suite to catch syntax and preload errors**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: exit code `1` with a parse error because `_select_preview_object` and `selected_object_id` are referenced by the new UI code but are not implemented yet. This confirms the UI code is wired to the selection flow that Task 3 will add.

- [ ] **Step 5: Leave the task uncommitted**

Do not commit after Task 2. Commit the object list UI together with Task 3, because the UI intentionally references selection functions that are added in the next task.

## Task 3: Object Selection Logic

**Files:**
- Modify: `addons/map_preview/map_preview_plugin.gd`

- [ ] **Step 1: Add selected object state**

In the state variable section, add `selected_object_id` after `selected_map_id`:

```gdscript
var selected_map_id := ""
var selected_object_id := ""
var document = MapLayoutDocumentScript.new()
```

- [ ] **Step 2: Clear selection only when switching to a different map**

Replace `_select_map_id` with:

```gdscript
func _select_map_id(map_id: String) -> void:
	if selected_map_id != map_id:
		selected_object_id = ""
	selected_map_id = map_id
	for index in range(map_selector.get_item_count()):
		if map_selector.get_item_text(index) == map_id:
			map_selector.select(index)
			break
	_reload_selected_map()
```

- [ ] **Step 3: Preserve refresh status when selected object disappears**

Replace `_reload_selected_map` with:

```gdscript
func _reload_selected_map() -> void:
	if selected_map_id.is_empty():
		return
	if not document.load_map(selected_map_id):
		_update_status("无法加载布局：%s" % selected_map_id)
		return
	save_conflict_confirm_pending = false
	var previous_selected_object_id = selected_object_id
	_render_selected_map()
	if previous_selected_object_id.is_empty() or selected_object_id == previous_selected_object_id:
		_update_status("已刷新：%s" % selected_map_id)
```

Replace `_render_selected_map` with:

```gdscript
func _render_selected_map() -> void:
	var scene_root = _edited_scene_root()
	if scene_root == null:
		return
	var map_data = maps_by_id.get(selected_map_id, {})
	renderer.render(scene_root, map_data, document.get_layout())
	_update_validation(map_data, document.get_layout())
	_update_readability_panel(map_data)
	_reapply_selected_object()
```

- [ ] **Step 4: Add selection helpers**

Add these functions after `_find_obstacle_rect`:

```gdscript
func _select_preview_object(object_id: String) -> void:
	if object_id.is_empty():
		return
	var scene_root = _edited_scene_root()
	if scene_root == null:
		_update_status("当前没有打开地图场景。")
		return
	var handle = _find_object_handle(object_id)
	if handle == null:
		_clear_selected_object_highlight()
		selected_object_id = ""
		_refresh_object_list_selection_state()
		_update_status("找不到预览对象：%s" % object_id)
		return
	selected_object_id = object_id
	_apply_object_selection(object_id, handle)
	_refresh_object_list_selection_state()
	if _select_editor_node(handle):
		_update_status("已选中对象：%s" % object_id)
	else:
		_update_status("已高亮对象：%s（编辑器选择不可用）" % object_id)

func _reapply_selected_object() -> void:
	if selected_object_id.is_empty():
		return
	var object_id = selected_object_id
	var handle = _find_object_handle(object_id)
	if handle == null:
		_clear_selected_object_highlight()
		selected_object_id = ""
		_update_status("选中对象已不存在：%s" % object_id)
		return
	_apply_object_selection(object_id, handle)
	_select_editor_node(handle)

func _apply_object_selection(object_id: String, handle: Node) -> void:
	_clear_selected_object_highlight()
	_set_handle_selected(handle, true)
	_fill_object_edit_fields(object_id)

func _clear_selected_object_highlight() -> void:
	var scene_root = _edited_scene_root()
	if scene_root == null:
		return
	var objects_root = scene_root.get_node_or_null("GeneratedMapPreview/Objects")
	if objects_root == null:
		return
	for child in objects_root.get_children():
		_set_handle_selected(child, false)

func _set_handle_selected(handle: Node, is_selected: bool) -> void:
	if handle != null and handle.has_method("set_selected"):
		handle.call("set_selected", is_selected)

func _find_object_handle(object_id: String) -> Node:
	var scene_root = _edited_scene_root()
	if scene_root == null:
		return null
	return scene_root.get_node_or_null("GeneratedMapPreview/Objects/%s" % object_id)

func _fill_object_edit_fields(object_id: String) -> void:
	if object_id_input != null:
		object_id_input.text = object_id
	if radius_spin != null:
		radius_spin.value = _current_object_radius(object_id)

func _current_object_radius(object_id: String) -> float:
	var layout_objects = document.get_layout().get("objects", {})
	if typeof(layout_objects) == TYPE_DICTIONARY and layout_objects.has(object_id):
		var object_layout = layout_objects.get(object_id, {})
		if typeof(object_layout) == TYPE_DICTIONARY:
			return float(object_layout.get("radius", 48.0))
	var object_record = _find_map_object(object_id)
	if not object_record.is_empty():
		return float(object_record.get("radius", 48.0))
	return float(radius_spin.value) if radius_spin != null else 48.0

func _find_map_object(object_id: String) -> Dictionary:
	var map_data = maps_by_id.get(selected_map_id, {})
	for object_record in map_data.get("objects", []):
		if typeof(object_record) == TYPE_DICTIONARY and str(object_record.get("id", "")) == object_id:
			return object_record
	return {}

func _select_editor_node(node: Node) -> bool:
	var editor_interface = get_editor_interface()
	if editor_interface == null:
		return false
	var selection = editor_interface.get_selection()
	if selection == null:
		return false
	selection.clear()
	selection.add_node(node)
	return true
```

- [ ] **Step 5: Run the test suite**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: exit code `0` and output ending with `测试通过：77 个测试套件`.

- [ ] **Step 6: Commit clickable selection**

Run:

```powershell
git add -- addons/map_preview/map_preview_plugin.gd
git commit -m "feat: select map preview objects from list"
```

## Task 4: Documentation And Verification

**Files:**
- Modify: `docs/godot-project-structure.md`

- [ ] **Step 1: Update project structure documentation**

In `docs/godot-project-structure.md`, replace:

```markdown
预览节点会显示 `名称 / 类型` 标签，例如 `青衫客 / NPC`、`去山脚村 / 出口`。右侧 `地图预览` Dock 还会显示类型图例和对象列表，方便在不运行游戏的情况下判断每个点、圈和矩形对应的地图内容。
```

With:

```markdown
预览节点会显示 `名称 / 类型` 标签，例如 `青衫客 / NPC`、`去山脚村 / 出口`。右侧 `地图预览` Dock 还会显示类型图例和可点击对象列表；点击对象行后，对应的 `GeneratedMapPreview/Objects/<object_id>` 节点会高亮并成为 Godot 编辑器当前选中节点，同时对象半径面板会填入该对象编号和半径。
```

- [ ] **Step 2: Run the full automated suite**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: exit code `0` and output ending with `测试通过：77 个测试套件`.

- [ ] **Step 3: Run editor load smoke test**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
```

Expected: exit code `0`, no addon parse errors, and the project quits normally.

- [ ] **Step 4: Manual Godot editor check**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
Start-Process -FilePath $godot -ArgumentList "--path", "."
```

Check these editor behaviors:

1. Open `scenes/mountain_pass.tscn`.
2. In the `地图预览` Dock, click the row containing `npc_qingshanke`.
3. Confirm the map handle for `npc_qingshanke` has a larger center dot, thicker radius ring, and brighter label border.
4. Confirm the Scene dock or Inspector selection points at `GeneratedMapPreview/Objects/npc_qingshanke`.
5. Confirm the object radius section shows `npc_qingshanke` and the current radius from `data/map_layouts/mountain_pass.json`.
6. Click `刷新`; confirm the same object remains highlighted.
7. Temporarily rename `npc_qingshanke` in `data/maps.json`, let auto-refresh run, and confirm the Dock status shows `选中对象已不存在：npc_qingshanke`. Restore the id immediately after this check.

- [ ] **Step 5: Confirm no data schema or scene content changed**

Run:

```powershell
git status --short
```

Expected: only intended source and documentation files are modified before the documentation commit. No `data/maps.json`, `data/map_layouts/*.json`, or `scenes/*.tscn` changes should remain from manual checks.

- [ ] **Step 6: Commit documentation**

Run:

```powershell
git add -- docs/godot-project-structure.md
git commit -m "docs: document map preview object selection"
```

## Final Verification

Run:

```powershell
git status --short
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

Expected:

- `git status --short` is clean after the implementation commits.
- Test command exits `0` and prints `测试通过：77 个测试套件`.
- Editor load command exits `0` without addon parse errors.
