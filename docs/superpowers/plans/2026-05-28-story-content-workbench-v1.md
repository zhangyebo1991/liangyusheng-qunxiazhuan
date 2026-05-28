# Story Content Workbench v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a first-pass story content workbench inside the existing Godot map preview Dock so selected map objects can view, lightly edit, save, and create missing dialogue/quest template content for existing IDs.

**Architecture:** Add a focused `StoryContentDocument` under `addons/map_preview/` to own `data/dialogues.json` and `data/quests.json` loading, indexing, editing, dirty tracking, saves, template creation, and dialogue-to-quest reverse lookup. Keep `MapPreviewPlugin` as the UI aggregator: it embeds a story panel in the existing Dock, refreshes that panel when selected objects change, and delegates all story JSON mutations to the document layer. Tests follow the existing headless GDScript runner and use source-level plugin wiring checks for EditorPlugin UI integration.

**Tech Stack:** Godot 4.6, GDScript `@tool` editor plugin code, JSON files under `data/`, existing `tests/run_tests.gd` runner, PowerShell verification commands.

---

## Scope

This plan implements [docs/superpowers/specs/2026-05-28-story-content-workbench-v1-design.md](../specs/2026-05-28-story-content-workbench-v1-design.md).

Included:

- Embed a story content panel in the existing `地图预览` Dock.
- Show selected object story entry fields: `id`, `name`, `type`, `dialogue_id`, `quest_id`, `required_quest_id`.
- Edit existing dialogue `title` and `lines[].speaker` / `lines[].text`.
- Edit existing quest `title` and `description`.
- Create missing dialogue/quest templates only when the selected object already has a non-empty ID field.
- Show quests that directly belong to the object and quests whose `start_dialogue` or `complete_dialogue` references the selected dialogue.
- Keep dialogue and quest saves separate from the map/layout save button.
- Reject dirty story saves when the corresponding JSON file changed on disk.

Excluded:

- Editing map object reference IDs from the story panel.
- Generating IDs for empty fields or writing back to `data/maps.json`.
- Editing dialogue `options`, `conditions`, `effects`, rewards, `battle_context`, or battle data.
- Building an independent story Dock.
- Field-level merge for external modifications.
- Full project-wide story graph visualization.

The current suite count before this plan is `测试通过：81 个测试套件`. After registering `tests/test_story_content_document.gd`, the passing count should become `测试通过：82 个测试套件`.

Every verification step uses:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Existing negative-path `push_error` lines for missing maps/items may still print during unrelated tests.

## File Structure

- Create `addons/map_preview/story_content_document.gd`
  Editor-only document layer for `data/dialogues.json` and `data/quests.json`. It preserves array shape and unknown fields, indexes records by ID, tracks separate dirty/hash state, saves each file independently, creates minimal templates, and reports errors through `last_error`.

- Create `tests/test_story_content_document.gd`
  Unit tests for load/index, dialogue edits, quest edits, template creation, reverse lookup, JSON array saves, duplicate/empty IDs, and external-change save rejection.

- Modify `tests/run_tests.gd`
  Register `TestStoryContentDocumentScript` near the existing map preview/data document suites.

- Modify `tests/test_map_preview_plugin_selection.gd`
  Extend existing source-level tests to verify the workbench is wired into `MapPreviewPlugin`, object selection refreshes the story panel, save/template handlers exist, and the map save button does not save story content.

- Modify `addons/map_preview/map_preview_plugin.gd`
  Preload and instantiate `StoryContentDocument`, build the story panel, refresh it on object selection/clear, render dialogue and quest sections, and add handlers for dialogue save, quest save, and missing template creation.

- Modify `docs/godot-project-structure.md`
  Document that the map preview Dock now includes a lightweight story content workbench for selected object dialogue and quest entry content.

---

### Task 1: Add Failing `StoryContentDocument` Tests

**Files:**

- Create: `tests/test_story_content_document.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Create the document test suite**

Create `tests/test_story_content_document.gd`:

```gdscript
extends RefCounted

const StoryContentDocumentScript = preload("res://addons/map_preview/story_content_document.gd")

func run(assertions) -> void:
	_test_loads_and_indexes_dialogues_and_quests(assertions)
	_test_updates_dialogue_and_saves_array(assertions)
	_test_updates_quest_and_saves_array(assertions)
	_test_creates_missing_dialogue_and_quest_templates(assertions)
	_test_rejects_dirty_save_after_external_change(assertions)
	_test_invalid_template_ids_and_duplicates_report_errors(assertions)

func _test_loads_and_indexes_dialogues_and_quests(assertions) -> void:
	var paths = _write_fixture("load")
	var document = StoryContentDocumentScript.new()
	assertions.assert_true(document.load_all(paths["dialogues_path"], paths["quests_path"]), "剧情内容文档应能加载对白和任务")

	var dialogue = document.get_dialogue("dialogue_intro")
	assertions.assert_eq(dialogue.get("title", ""), "初见", "应能按 id 找到对白")
	assertions.assert_eq(dialogue.get("lines", []).size(), 1, "对白行应保留")

	var quest = document.get_quest("quest_intro")
	assertions.assert_eq(quest.get("title", ""), "入门任务", "应能按 id 找到任务")

	var refs = document.find_quests_for_dialogue("dialogue_intro")
	assertions.assert_eq(refs.size(), 2, "应反查 start_dialogue 和 complete_dialogue 引用")
	assertions.assert_true(_has_quest_ref(refs, "quest_intro", "start_dialogue"), "应包含 start_dialogue 引用")
	assertions.assert_true(_has_quest_ref(refs, "quest_finish", "complete_dialogue"), "应包含 complete_dialogue 引用")
	assertions.assert_true(document.get_dialogue("missing_dialogue").is_empty(), "缺失对白应返回空字典")
	assertions.assert_true(document.get_quest("missing_quest").is_empty(), "缺失任务应返回空字典")

func _test_updates_dialogue_and_saves_array(assertions) -> void:
	var paths = _write_fixture("dialogue_save")
	var document = StoryContentDocumentScript.new()
	document.load_all(paths["dialogues_path"], paths["quests_path"])

	var title_result = document.update_dialogue_title("dialogue_intro", "改后标题")
	assertions.assert_true(title_result.get("ok", false), "更新对白标题应成功")
	var lines_result = document.set_dialogue_lines("dialogue_intro", [
		{"speaker": "青衫客", "text": "新对白。"},
		{"speaker": "云游少侠", "text": "晚辈记下了。"}
	])
	assertions.assert_true(lines_result.get("ok", false), "更新对白行应成功")
	assertions.assert_true(document.dialogues_dirty, "更新对白后应标记对白 dirty")
	assertions.assert_true(document.save_dialogues(), "保存对白应成功")
	assertions.assert_false(document.dialogues_dirty, "保存对白后 dirty 应清除")

	var saved = _read_json(paths["dialogues_path"])
	assertions.assert_eq(typeof(saved), TYPE_ARRAY, "保存后的 dialogues.json 仍应是数组")
	assertions.assert_eq(saved[0].get("title", ""), "改后标题", "保存后的对白标题应更新")
	assertions.assert_eq(saved[0].get("lines", []).size(), 2, "保存后的对白行数量应更新")
	assertions.assert_eq(saved[0].get("lines", [])[1].get("text", ""), "晚辈记下了。", "保存后的对白行文本应更新")

func _test_updates_quest_and_saves_array(assertions) -> void:
	var paths = _write_fixture("quest_save")
	var document = StoryContentDocumentScript.new()
	document.load_all(paths["dialogues_path"], paths["quests_path"])

	var result = document.update_quest_summary("quest_intro", "改后任务", "新的任务描述。")
	assertions.assert_true(result.get("ok", false), "更新任务摘要应成功")
	assertions.assert_true(document.quests_dirty, "更新任务后应标记任务 dirty")
	assertions.assert_true(document.save_quests(), "保存任务应成功")
	assertions.assert_false(document.quests_dirty, "保存任务后 dirty 应清除")

	var saved = _read_json(paths["quests_path"])
	assertions.assert_eq(typeof(saved), TYPE_ARRAY, "保存后的 quests.json 仍应是数组")
	assertions.assert_eq(saved[0].get("title", ""), "改后任务", "保存后的任务标题应更新")
	assertions.assert_eq(saved[0].get("description", ""), "新的任务描述。", "保存后的任务描述应更新")

func _test_creates_missing_dialogue_and_quest_templates(assertions) -> void:
	var paths = _write_fixture("templates")
	var document = StoryContentDocumentScript.new()
	document.load_all(paths["dialogues_path"], paths["quests_path"])

	var dialogue_result = document.create_dialogue_template("dialogue_missing_template")
	assertions.assert_true(dialogue_result.get("ok", false), "创建缺失对白模板应成功")
	var dialogue = document.get_dialogue("dialogue_missing_template")
	assertions.assert_eq(dialogue.get("title", ""), "新对白", "对白模板标题应使用固定初始值")
	assertions.assert_eq(dialogue.get("lines", []).size(), 1, "对白模板应包含一行空对白")
	assertions.assert_true(document.dialogues_dirty, "创建对白模板后应标记对白 dirty")

	var quest_result = document.create_quest_template("quest_missing_template")
	assertions.assert_true(quest_result.get("ok", false), "创建缺失任务模板应成功")
	var quest = document.get_quest("quest_missing_template")
	assertions.assert_eq(quest.get("title", ""), "新任务", "任务模板标题应使用固定初始值")
	assertions.assert_eq(quest.get("description", ""), "", "任务模板描述应为空字符串")
	assertions.assert_true(document.quests_dirty, "创建任务模板后应标记任务 dirty")

func _test_rejects_dirty_save_after_external_change(assertions) -> void:
	var paths = _write_fixture("external_change")
	var document = StoryContentDocumentScript.new()
	document.load_all(paths["dialogues_path"], paths["quests_path"])

	document.update_dialogue_title("dialogue_intro", "本地对白标题")
	_write_json(paths["dialogues_path"], [
		{"id": "dialogue_intro", "title": "外部对白标题", "lines": []}
	])
	assertions.assert_false(document.save_dialogues(), "对白 dirty 且磁盘已变化时应拒绝保存")
	assertions.assert_true(document.last_error.find("对白文件已被外部修改") >= 0, "对白保存冲突应说明外部修改")

	document.load_all(paths["dialogues_path"], paths["quests_path"])
	document.update_quest_summary("quest_intro", "本地任务标题", "本地任务描述")
	_write_json(paths["quests_path"], [
		{"id": "quest_intro", "title": "外部任务标题", "description": "外部任务描述"}
	])
	assertions.assert_false(document.save_quests(), "任务 dirty 且磁盘已变化时应拒绝保存")
	assertions.assert_true(document.last_error.find("任务文件已被外部修改") >= 0, "任务保存冲突应说明外部修改")

func _test_invalid_template_ids_and_duplicates_report_errors(assertions) -> void:
	var paths = _write_fixture("invalid_templates")
	var document = StoryContentDocumentScript.new()
	document.load_all(paths["dialogues_path"], paths["quests_path"])

	var empty_dialogue_result = document.create_dialogue_template("  ")
	assertions.assert_false(empty_dialogue_result.get("ok", true), "空对白 id 不应创建模板")
	assertions.assert_true(str(empty_dialogue_result.get("error", "")).find("对白编号不能为空") >= 0, "空对白 id 应返回明确错误")

	var duplicate_dialogue_result = document.create_dialogue_template("dialogue_intro")
	assertions.assert_false(duplicate_dialogue_result.get("ok", true), "重复对白 id 不应创建模板")
	assertions.assert_true(str(duplicate_dialogue_result.get("error", "")).find("对白已存在") >= 0, "重复对白 id 应返回明确错误")

	var empty_quest_result = document.create_quest_template("")
	assertions.assert_false(empty_quest_result.get("ok", true), "空任务 id 不应创建模板")
	assertions.assert_true(str(empty_quest_result.get("error", "")).find("任务编号不能为空") >= 0, "空任务 id 应返回明确错误")

	var duplicate_quest_result = document.create_quest_template("quest_intro")
	assertions.assert_false(duplicate_quest_result.get("ok", true), "重复任务 id 不应创建模板")
	assertions.assert_true(str(duplicate_quest_result.get("error", "")).find("任务已存在") >= 0, "重复任务 id 应返回明确错误")

func _write_fixture(name: String) -> Dictionary:
	var base = "user://story_content_document_%s" % name
	var dialogues_path = "%s_dialogues.json" % base
	var quests_path = "%s_quests.json" % base
	_write_json(dialogues_path, [
		{
			"id": "dialogue_intro",
			"title": "初见",
			"lines": [
				{"speaker": "青衫客", "text": "江湖路远。"}
			],
			"options": [
				{"id": "option_demo", "text": "告辞", "next_dialogue_id": "dialogue_finish"}
			]
		},
		{
			"id": "dialogue_finish",
			"title": "收束",
			"lines": []
		}
	])
	_write_json(quests_path, [
		{
			"id": "quest_intro",
			"title": "入门任务",
			"description": "向青衫客请教。",
			"start_dialogue": "dialogue_intro",
			"reward_items": ["herb_small"]
		},
		{
			"id": "quest_finish",
			"title": "收束任务",
			"description": "回报青衫客。",
			"complete_dialogue": "dialogue_intro",
			"complete_effects": [
				{"type": "set_quest_status", "quest_id": "quest_finish", "status": "completed"}
			]
		}
	])
	return {"dialogues_path": dialogues_path, "quests_path": quests_path}

func _write_json(path: String, value: Variant) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入测试 JSON：%s" % path)
		return
	file.store_string(JSON.stringify(value, "\t"))
	file.close()

func _read_json(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())

func _has_quest_ref(refs: Array, quest_id: String, field: String) -> bool:
	for ref in refs:
		if typeof(ref) != TYPE_DICTIONARY:
			continue
		if str(ref.get("quest_id", "")) == quest_id and str(ref.get("field", "")) == field:
			return true
	return false
```

- [ ] **Step 2: Register the failing suite**

In `tests/run_tests.gd`, add this preload after `TestContentReferenceValidatorScript`:

```gdscript
const TestStoryContentDocumentScript = preload("res://tests/test_story_content_document.gd")
```

In the `suites` array, add this entry after `TestContentReferenceValidatorScript.new()`:

```gdscript
		TestStoryContentDocumentScript.new(),
```

- [ ] **Step 3: Run tests and verify the expected failure**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL before implementation because `res://addons/map_preview/story_content_document.gd` does not exist.

- [ ] **Step 4: Commit the failing tests**

```powershell
git add tests/test_story_content_document.gd tests/run_tests.gd
git commit -m "test: add story content document coverage"
```

---

### Task 2: Implement `StoryContentDocument`

**Files:**

- Create: `addons/map_preview/story_content_document.gd`
- Test: `tests/test_story_content_document.gd`

- [ ] **Step 1: Implement the story content document**

Create `addons/map_preview/story_content_document.gd`:

```gdscript
@tool
extends RefCounted

const DEFAULT_DIALOGUES_PATH := "res://data/dialogues.json"
const DEFAULT_QUESTS_PATH := "res://data/quests.json"

var dialogues_path := DEFAULT_DIALOGUES_PATH
var quests_path := DEFAULT_QUESTS_PATH
var dialogues: Array = []
var quests: Array = []
var dialogues_by_id: Dictionary = {}
var quests_by_id: Dictionary = {}
var quests_by_dialogue_id: Dictionary = {}
var dialogues_loaded_hash := 0
var quests_loaded_hash := 0
var dialogues_dirty := false
var quests_dirty := false
var last_error := ""

func load_all(next_dialogues_path: String = DEFAULT_DIALOGUES_PATH, next_quests_path: String = DEFAULT_QUESTS_PATH) -> bool:
	var dialogue_result = _load_array_file(next_dialogues_path, "data/dialogues.json")
	if not dialogue_result.get("ok", false):
		return _fail(str(dialogue_result.get("error", "")))
	var quest_result = _load_array_file(next_quests_path, "data/quests.json")
	if not quest_result.get("ok", false):
		return _fail(str(quest_result.get("error", "")))

	dialogues_path = next_dialogues_path
	quests_path = next_quests_path
	dialogues = dialogue_result.get("data", []).duplicate(true)
	quests = quest_result.get("data", []).duplicate(true)
	dialogues_loaded_hash = int(dialogue_result.get("hash", 0))
	quests_loaded_hash = int(quest_result.get("hash", 0))
	dialogues_dirty = false
	quests_dirty = false
	last_error = ""
	_rebuild_indexes()
	return true

func load_from_texts(dialogues_text: String, quests_text: String, next_dialogues_path: String = DEFAULT_DIALOGUES_PATH, next_quests_path: String = DEFAULT_QUESTS_PATH) -> bool:
	var dialogue_result = _parse_array_text(dialogues_text, "data/dialogues.json")
	if not dialogue_result.get("ok", false):
		return _fail(str(dialogue_result.get("error", "")))
	var quest_result = _parse_array_text(quests_text, "data/quests.json")
	if not quest_result.get("ok", false):
		return _fail(str(quest_result.get("error", "")))

	dialogues_path = next_dialogues_path
	quests_path = next_quests_path
	dialogues = dialogue_result.get("data", []).duplicate(true)
	quests = quest_result.get("data", []).duplicate(true)
	dialogues_loaded_hash = dialogues_text.hash()
	quests_loaded_hash = quests_text.hash()
	dialogues_dirty = false
	quests_dirty = false
	last_error = ""
	_rebuild_indexes()
	return true

func get_dialogue(dialogue_id: String) -> Dictionary:
	var record = _get_dialogue_record(dialogue_id)
	return record.duplicate(true) if not record.is_empty() else {}

func get_quest(quest_id: String) -> Dictionary:
	var record = _get_quest_record(quest_id)
	return record.duplicate(true) if not record.is_empty() else {}

func find_quests_for_dialogue(dialogue_id: String) -> Array:
	var clean_dialogue_id = dialogue_id.strip_edges()
	var refs = quests_by_dialogue_id.get(clean_dialogue_id, [])
	var result: Array = []
	if typeof(refs) != TYPE_ARRAY:
		return result
	for ref in refs:
		if typeof(ref) != TYPE_DICTIONARY:
			continue
		var quest_id = str(ref.get("quest_id", "")).strip_edges()
		var quest = _get_quest_record(quest_id)
		if quest.is_empty():
			continue
		result.append({
			"quest_id": quest_id,
			"field": str(ref.get("field", "")),
			"title": str(quest.get("title", "")),
			"description": str(quest.get("description", "")),
		})
	return result

func update_dialogue_title(dialogue_id: String, title: String) -> Dictionary:
	var dialogue = _get_dialogue_record(dialogue_id)
	if dialogue.is_empty():
		return _error("对白不存在：%s" % dialogue_id.strip_edges())
	dialogue["title"] = title
	_mark_dialogues_dirty()
	return _ok()

func set_dialogue_lines(dialogue_id: String, lines: Array) -> Dictionary:
	var dialogue = _get_dialogue_record(dialogue_id)
	if dialogue.is_empty():
		return _error("对白不存在：%s" % dialogue_id.strip_edges())
	var clean_lines: Array = []
	for line in lines:
		if typeof(line) == TYPE_DICTIONARY:
			clean_lines.append({
				"speaker": str(line.get("speaker", "")),
				"text": str(line.get("text", "")),
			})
		else:
			clean_lines.append({"speaker": "", "text": str(line)})
	dialogue["lines"] = clean_lines
	_mark_dialogues_dirty()
	return _ok()

func create_dialogue_template(dialogue_id: String) -> Dictionary:
	var clean_id = dialogue_id.strip_edges()
	if clean_id.is_empty():
		return _error("对白编号不能为空。")
	if dialogues_by_id.has(clean_id):
		return _error("对白已存在：%s" % clean_id)
	dialogues.append({
		"id": clean_id,
		"title": "新对白",
		"lines": [
			{"speaker": "", "text": ""}
		],
	})
	_rebuild_indexes()
	_mark_dialogues_dirty()
	return _ok()

func save_dialogues() -> bool:
	if dialogues_path.is_empty():
		return _fail("对白保存路径为空。")
	if dialogues_dirty and dialogues_have_external_change():
		return _fail("对白文件已被外部修改，请刷新后再保存。")
	var text = JSON.stringify(dialogues, "\t")
	if not _write_text(dialogues_path, text, "无法写入 data/dialogues.json。"):
		return false
	dialogues_loaded_hash = text.hash()
	dialogues_dirty = false
	last_error = ""
	return true

func update_quest_summary(quest_id: String, title: String, description: String) -> Dictionary:
	var quest = _get_quest_record(quest_id)
	if quest.is_empty():
		return _error("任务不存在：%s" % quest_id.strip_edges())
	quest["title"] = title
	quest["description"] = description
	_mark_quests_dirty()
	return _ok()

func create_quest_template(quest_id: String) -> Dictionary:
	var clean_id = quest_id.strip_edges()
	if clean_id.is_empty():
		return _error("任务编号不能为空。")
	if quests_by_id.has(clean_id):
		return _error("任务已存在：%s" % clean_id)
	quests.append({
		"id": clean_id,
		"title": "新任务",
		"description": "",
	})
	_rebuild_indexes()
	_mark_quests_dirty()
	return _ok()

func save_quests() -> bool:
	if quests_path.is_empty():
		return _fail("任务保存路径为空。")
	if quests_dirty and quests_have_external_change():
		return _fail("任务文件已被外部修改，请刷新后再保存。")
	var text = JSON.stringify(quests, "\t")
	if not _write_text(quests_path, text, "无法写入 data/quests.json。"):
		return false
	quests_loaded_hash = text.hash()
	quests_dirty = false
	last_error = ""
	return true

func dialogues_have_external_change() -> bool:
	return _has_external_change(dialogues_path, dialogues_loaded_hash)

func quests_have_external_change() -> bool:
	return _has_external_change(quests_path, quests_loaded_hash)

func _load_array_file(source_path: String, label: String) -> Dictionary:
	var file = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "无法读取 %s。" % label}
	var text = file.get_as_text()
	var parsed = _parse_array_text(text, label)
	if not parsed.get("ok", false):
		return parsed
	parsed["hash"] = text.hash()
	return parsed

func _parse_array_text(text: String, label: String) -> Dictionary:
	var json = JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "error": "%s 必须是数组。" % label}
	if typeof(json.data) != TYPE_ARRAY:
		return {"ok": false, "error": "%s 必须是数组。" % label}
	return {"ok": true, "data": json.data.duplicate(true)}

func _write_text(path: String, text: String, error_message: String) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _fail(error_message)
	file.store_string(text)
	file.close()
	return true

func _has_external_change(path: String, loaded_hash: int) -> bool:
	if path.is_empty():
		return false
	if not FileAccess.file_exists(path):
		return true
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return true
	return file.get_as_text().hash() != loaded_hash

func _rebuild_indexes() -> void:
	dialogues_by_id = {}
	quests_by_id = {}
	quests_by_dialogue_id = {}

	for dialogue in dialogues:
		if typeof(dialogue) != TYPE_DICTIONARY:
			continue
		var dialogue_id = str(dialogue.get("id", "")).strip_edges()
		if not dialogue_id.is_empty():
			dialogues_by_id[dialogue_id] = dialogue

	for quest in quests:
		if typeof(quest) != TYPE_DICTIONARY:
			continue
		var quest_id = str(quest.get("id", "")).strip_edges()
		if quest_id.is_empty():
			continue
		quests_by_id[quest_id] = quest
		for field in ["start_dialogue", "complete_dialogue"]:
			var dialogue_id = str(quest.get(field, "")).strip_edges()
			if dialogue_id.is_empty():
				continue
			var refs = quests_by_dialogue_id.get(dialogue_id, [])
			if typeof(refs) != TYPE_ARRAY:
				refs = []
			refs.append({"quest_id": quest_id, "field": field})
			quests_by_dialogue_id[dialogue_id] = refs

func _get_dialogue_record(dialogue_id: String) -> Dictionary:
	var clean_id = dialogue_id.strip_edges()
	var record = dialogues_by_id.get(clean_id, {})
	return record if typeof(record) == TYPE_DICTIONARY else {}

func _get_quest_record(quest_id: String) -> Dictionary:
	var clean_id = quest_id.strip_edges()
	var record = quests_by_id.get(clean_id, {})
	return record if typeof(record) == TYPE_DICTIONARY else {}

func _mark_dialogues_dirty() -> void:
	dialogues_dirty = true

func _mark_quests_dirty() -> void:
	quests_dirty = true

func _ok() -> Dictionary:
	last_error = ""
	return {"ok": true, "error": ""}

func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}

func _fail(message: String) -> bool:
	last_error = message
	return false
```

- [ ] **Step 2: Run tests and verify the document passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: `测试通过：82 个测试套件`.

- [ ] **Step 3: Commit the document implementation**

```powershell
git add addons/map_preview/story_content_document.gd tests/test_story_content_document.gd tests/run_tests.gd
git commit -m "feat: add story content document"
```

---

### Task 3: Add Failing Map Preview Story Workbench Wiring Tests

**Files:**

- Modify: `tests/test_map_preview_plugin_selection.gd`

- [ ] **Step 1: Extend the plugin source test**

Modify `tests/test_map_preview_plugin_selection.gd` so `run()` calls the new test:

```gdscript
func run(assertions) -> void:
	_test_render_queues_deferred_object_reselect(assertions)
	_test_validation_aggregates_layout_and_content_references(assertions)
	_test_story_workbench_is_wired_into_map_preview_dock(assertions)
```

Add this test function after `_test_validation_aggregates_layout_and_content_references`:

```gdscript
func _test_story_workbench_is_wired_into_map_preview_dock(assertions) -> void:
	var source = _read_plugin_source()
	var build_body = _function_body(source, "_build_dock")
	var select_body = _function_body(source, "_select_layout_element")
	var clear_body = _function_body(source, "_clear_selected_layout_element")
	var save_body = _function_body(source, "_save_document")
	assertions.assert_true(
		source.contains("StoryContentDocumentScript"),
		"地图预览插件应 preload 剧情内容文档"
	)
	assertions.assert_true(
		source.contains("story_content_document = StoryContentDocumentScript.new()"),
		"地图预览插件应持有剧情内容文档实例"
	)
	assertions.assert_true(
		build_body.contains("_build_story_workbench_panel()"),
		"Dock 构建时应创建剧情内容面板"
	)
	assertions.assert_true(
		select_body.contains("_update_story_workbench_for_selection(layout_id)"),
		"选中地图对象时应刷新剧情内容面板"
	)
	assertions.assert_true(
		clear_body.contains("_render_story_empty"),
		"清空选择时应清空剧情内容面板"
	)
	assertions.assert_true(
		source.contains("func _save_selected_dialogue"),
		"剧情内容面板应提供保存对白入口"
	)
	assertions.assert_true(
		source.contains("func _save_selected_quest"),
		"剧情内容面板应提供保存任务入口"
	)
	assertions.assert_true(
		source.contains("func _create_missing_dialogue_template"),
		"剧情内容面板应提供创建缺失对白模板入口"
	)
	assertions.assert_true(
		source.contains("func _create_missing_quest_template"),
		"剧情内容面板应提供创建缺失任务模板入口"
	)
	assertions.assert_false(
		save_body.contains("save_dialogues") or save_body.contains("save_quests"),
		"地图主保存按钮不应保存对白或任务"
	)
```

- [ ] **Step 2: Run tests and verify the expected failure**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL with assertions from `test_map_preview_plugin_selection.gd` because `MapPreviewPlugin` has not wired `StoryContentDocumentScript` or the story workbench methods yet.

- [ ] **Step 3: Commit the failing plugin wiring tests**

```powershell
git add tests/test_map_preview_plugin_selection.gd
git commit -m "test: require story workbench dock wiring"
```

---

### Task 4: Embed the Story Workbench in the Map Preview Dock

**Files:**

- Modify: `addons/map_preview/map_preview_plugin.gd`
- Test: `tests/test_map_preview_plugin_selection.gd`

- [ ] **Step 1: Add the document preload and instance**

In `addons/map_preview/map_preview_plugin.gd`, add this preload after `ContentReferenceValidatorScript`:

```gdscript
const StoryContentDocumentScript = preload("res://addons/map_preview/story_content_document.gd")
```

Add this instance after `var content_reference_validator = ContentReferenceValidatorScript.new()`:

```gdscript
var story_content_document = StoryContentDocumentScript.new()
```

- [ ] **Step 2: Add story workbench state variables**

Add these variables after `var object_type_input: LineEdit`:

```gdscript
var story_panel: VBoxContainer
var story_entry_label: RichTextLabel
var story_dialogue_status_label: RichTextLabel
var story_dialogue_title_input: LineEdit
var story_dialogue_lines_container: VBoxContainer
var story_add_dialogue_line_button: Button
var story_save_dialogue_button: Button
var story_create_dialogue_template_button: Button
var story_quest_list_container: VBoxContainer
var selected_story_dialogue_id := ""
var missing_story_dialogue_id := ""
var missing_story_quest_id := ""
var story_quest_controls: Dictionary = {}
```

- [ ] **Step 3: Load story content when the plugin enters the tree**

In `_enter_tree()`, add `story_content_document.load_all()` after `_load_map_index()`:

```gdscript
	_load_map_index()
	story_content_document.load_all()
	set_process(true)
```

If `story_content_document.load_all()` fails, the panel will show the error when a selection is rendered; do not block map preview startup.

- [ ] **Step 4: Build the story panel inside `_build_dock()`**

In `_build_dock()`, add `_build_story_workbench_panel()` immediately before `status_label = Label.new()`:

```gdscript
	_build_story_workbench_panel()

	status_label = Label.new()
```

Add this function after `_build_dock()`:

```gdscript
func _build_story_workbench_panel() -> void:
	story_panel = VBoxContainer.new()
	story_panel.name = "剧情内容"
	dock.add_child(story_panel)

	var title = Label.new()
	title.text = "剧情内容"
	story_panel.add_child(title)

	story_entry_label = RichTextLabel.new()
	story_entry_label.bbcode_enabled = true
	story_entry_label.fit_content = true
	story_entry_label.custom_minimum_size = Vector2(260, 72)
	story_panel.add_child(story_entry_label)

	var dialogue_title = Label.new()
	dialogue_title.text = "对白"
	story_panel.add_child(dialogue_title)

	story_dialogue_status_label = RichTextLabel.new()
	story_dialogue_status_label.bbcode_enabled = true
	story_dialogue_status_label.fit_content = true
	story_dialogue_status_label.custom_minimum_size = Vector2(260, 48)
	story_panel.add_child(story_dialogue_status_label)

	story_dialogue_title_input = LineEdit.new()
	story_dialogue_title_input.placeholder_text = "对白标题"
	story_panel.add_child(story_dialogue_title_input)

	story_dialogue_lines_container = VBoxContainer.new()
	story_panel.add_child(story_dialogue_lines_container)

	var dialogue_buttons = HBoxContainer.new()
	story_panel.add_child(dialogue_buttons)

	story_add_dialogue_line_button = Button.new()
	story_add_dialogue_line_button.text = "添加对白行"
	story_add_dialogue_line_button.pressed.connect(_add_empty_dialogue_line_row)
	dialogue_buttons.add_child(story_add_dialogue_line_button)

	story_save_dialogue_button = Button.new()
	story_save_dialogue_button.text = "保存对白"
	story_save_dialogue_button.pressed.connect(_save_selected_dialogue)
	dialogue_buttons.add_child(story_save_dialogue_button)

	story_create_dialogue_template_button = Button.new()
	story_create_dialogue_template_button.text = "创建对白模板"
	story_create_dialogue_template_button.pressed.connect(_create_missing_dialogue_template)
	story_panel.add_child(story_create_dialogue_template_button)

	var quest_title = Label.new()
	quest_title.text = "任务"
	story_panel.add_child(quest_title)

	story_quest_list_container = VBoxContainer.new()
	story_panel.add_child(story_quest_list_container)

	_render_story_empty("未选中剧情对象")
```

- [ ] **Step 5: Refresh the story panel when selection changes**

In `_select_layout_element(kind, layout_id)`, update the `match kind` block to call the workbench for objects and clear it for non-objects:

```gdscript
	match kind:
		"object":
			_fill_object_edit_fields(layout_id)
			_update_story_workbench_for_selection(layout_id)
		"spawn":
			_fill_position_fields(_current_spawn_position(layout_id))
			_render_story_empty("未选中剧情对象")
		"obstacle":
			_fill_obstacle_fields(layout_id)
			_render_story_empty("未选中剧情对象")
```

In `_clear_selected_layout_element()`, add this call before the function returns:

```gdscript
	_render_story_empty("未选中剧情对象")
```

In `_refresh_selected_object_handle_fields(object_id)`, after `_update_readability_panel(map_data)`, add:

```gdscript
		_update_story_workbench_for_selection(object_id)
```

- [ ] **Step 6: Add story panel rendering helpers**

Add these functions before `_update_validation()`:

```gdscript
func _update_story_workbench_for_selection(object_id: String = "") -> void:
	if story_panel == null:
		return
	_refresh_story_document_if_clean()
	var target_object_id = object_id.strip_edges()
	if target_object_id.is_empty():
		target_object_id = selected_object_id
	if target_object_id.is_empty():
		_render_story_empty("未选中剧情对象")
		return
	var object_record = _find_map_object(target_object_id)
	if object_record.is_empty():
		_render_story_empty("未选中剧情对象")
		return
	_render_story_workbench(object_record)

func _refresh_story_document_if_clean() -> void:
	if story_content_document.dialogues_dirty or story_content_document.quests_dirty:
		return
	if story_content_document.dialogues_have_external_change() or story_content_document.quests_have_external_change():
		story_content_document.load_all()

func _render_story_empty(message: String) -> void:
	selected_story_dialogue_id = ""
	missing_story_dialogue_id = ""
	missing_story_quest_id = ""
	story_quest_controls = {}
	if story_entry_label != null:
		story_entry_label.text = "[color=gray]%s[/color]" % message
	if story_dialogue_status_label != null:
		story_dialogue_status_label.text = ""
	if story_dialogue_title_input != null:
		story_dialogue_title_input.text = ""
		story_dialogue_title_input.editable = false
	if story_dialogue_lines_container != null:
		_clear_container(story_dialogue_lines_container)
	if story_add_dialogue_line_button != null:
		story_add_dialogue_line_button.disabled = true
	if story_save_dialogue_button != null:
		story_save_dialogue_button.disabled = true
	if story_create_dialogue_template_button != null:
		story_create_dialogue_template_button.visible = false
	if story_quest_list_container != null:
		_clear_container(story_quest_list_container)

func _render_story_workbench(object_record: Dictionary) -> void:
	var dialogue_id = str(object_record.get("dialogue_id", "")).strip_edges()
	selected_story_dialogue_id = dialogue_id
	missing_story_dialogue_id = ""
	missing_story_quest_id = ""
	story_quest_controls = {}
	if story_entry_label != null:
		story_entry_label.text = _story_entry_text(object_record)
	_render_dialogue_section(dialogue_id)
	_render_quest_section(object_record, dialogue_id)

func _story_entry_text(object_record: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("对象：%s / %s / %s" % [
		str(object_record.get("id", "")),
		str(object_record.get("name", "")),
		str(object_record.get("type", "")),
	])
	lines.append("对白：%s" % str(object_record.get("dialogue_id", "")))
	lines.append("任务：%s" % str(object_record.get("quest_id", "")))
	lines.append("前置任务：%s" % str(object_record.get("required_quest_id", "")))
	return "\n".join(lines)

func _render_dialogue_section(dialogue_id: String) -> void:
	if story_dialogue_lines_container != null:
		_clear_container(story_dialogue_lines_container)
	if story_create_dialogue_template_button != null:
		story_create_dialogue_template_button.visible = false
	if story_dialogue_title_input != null:
		story_dialogue_title_input.text = ""
		story_dialogue_title_input.editable = false
	if story_add_dialogue_line_button != null:
		story_add_dialogue_line_button.disabled = true
	if story_save_dialogue_button != null:
		story_save_dialogue_button.disabled = true

	if dialogue_id.is_empty():
		story_dialogue_status_label.text = "[color=gray]当前对象没有对白入口[/color]"
		return

	var dialogue = story_content_document.get_dialogue(dialogue_id)
	if dialogue.is_empty():
		missing_story_dialogue_id = dialogue_id
		story_dialogue_status_label.text = "[color=red]对白不存在：%s[/color]" % dialogue_id
		if story_create_dialogue_template_button != null:
			story_create_dialogue_template_button.visible = true
		return

	story_dialogue_status_label.text = _dialogue_status_text(dialogue)
	story_dialogue_title_input.editable = true
	story_dialogue_title_input.text = str(dialogue.get("title", ""))
	var lines = dialogue.get("lines", [])
	if typeof(lines) != TYPE_ARRAY:
		lines = []
	for line in lines:
		if typeof(line) == TYPE_DICTIONARY:
			_add_dialogue_line_row(str(line.get("speaker", "")), str(line.get("text", "")))
	if story_add_dialogue_line_button != null:
		story_add_dialogue_line_button.disabled = false
	if story_save_dialogue_button != null:
		story_save_dialogue_button.disabled = false

func _dialogue_status_text(dialogue: Dictionary) -> String:
	var options = dialogue.get("options", [])
	if typeof(options) == TYPE_ARRAY and options.size() > 0:
		return "[color=yellow]包含 %d 个选项，v1 暂不编辑[/color]" % options.size()
	return "[color=green]对白可编辑[/color]"

func _render_quest_section(object_record: Dictionary, dialogue_id: String) -> void:
	if story_quest_list_container == null:
		return
	_clear_container(story_quest_list_container)
	var refs = _collect_story_quest_refs(object_record, dialogue_id)
	if refs.is_empty():
		var empty_label = Label.new()
		empty_label.text = "当前对象没有任务入口"
		story_quest_list_container.add_child(empty_label)
		return
	for ref in refs:
		_add_story_quest_row(ref)

func _collect_story_quest_refs(object_record: Dictionary, dialogue_id: String) -> Array:
	var refs: Array = []
	var seen := {}
	for field in ["quest_id", "required_quest_id"]:
		var quest_id = str(object_record.get(field, "")).strip_edges()
		if quest_id.is_empty():
			continue
		refs.append({"quest_id": quest_id, "source": "对象 %s" % field, "can_create": true})
		seen["%s|%s" % [quest_id, field]] = true
	if not dialogue_id.is_empty():
		for quest_ref in story_content_document.find_quests_for_dialogue(dialogue_id):
			var quest_id = str(quest_ref.get("quest_id", "")).strip_edges()
			var source_field = str(quest_ref.get("field", "")).strip_edges()
			var key = "%s|%s" % [quest_id, source_field]
			if seen.has(key):
				continue
			refs.append({"quest_id": quest_id, "source": "%s 引用当前对白" % source_field, "can_create": false})
			seen[key] = true
	return refs

func _add_story_quest_row(ref: Dictionary) -> void:
	var quest_id = str(ref.get("quest_id", "")).strip_edges()
	var source = str(ref.get("source", ""))
	var can_create = bool(ref.get("can_create", false))
	var quest = story_content_document.get_quest(quest_id)

	var box = VBoxContainer.new()
	story_quest_list_container.add_child(box)

	var label = Label.new()
	label.text = "%s（%s）" % [quest_id, source]
	box.add_child(label)

	if quest.is_empty():
		var missing = RichTextLabel.new()
		missing.bbcode_enabled = true
		missing.fit_content = true
		missing.text = "[color=red]任务不存在：%s[/color]" % quest_id
		box.add_child(missing)
		if can_create:
			var create_button = Button.new()
			create_button.text = "创建任务模板"
			create_button.pressed.connect(_create_missing_quest_template.bind(quest_id))
			box.add_child(create_button)
		return

	var title_input = LineEdit.new()
	title_input.text = str(quest.get("title", ""))
	box.add_child(title_input)

	var description_input = TextEdit.new()
	description_input.text = str(quest.get("description", ""))
	description_input.custom_minimum_size = Vector2(260, 72)
	box.add_child(description_input)

	var summary = _quest_complex_summary(quest)
	if not summary.is_empty():
		var summary_label = Label.new()
		summary_label.text = summary
		box.add_child(summary_label)

	var save_button = Button.new()
	save_button.text = "保存任务"
	save_button.pressed.connect(_save_selected_quest.bind(quest_id))
	box.add_child(save_button)

	story_quest_controls[quest_id] = {
		"title": title_input,
		"description": description_input,
	}

func _quest_complex_summary(quest: Dictionary) -> String:
	var parts := PackedStringArray()
	for field in ["complete_effects", "reward_items", "reward_item_amounts", "reward_coins", "reward_flags"]:
		if quest.has(field):
			parts.append("%s 暂不编辑" % field)
	return "；".join(parts)
```

- [ ] **Step 7: Add dialogue row helpers**

Add these functions after the rendering helpers:

```gdscript
func _add_empty_dialogue_line_row() -> void:
	_add_dialogue_line_row("", "")

func _add_dialogue_line_row(speaker: String, text: String) -> void:
	if story_dialogue_lines_container == null:
		return
	var row = HBoxContainer.new()
	story_dialogue_lines_container.add_child(row)

	var speaker_input = LineEdit.new()
	speaker_input.text = speaker
	speaker_input.placeholder_text = "说话人"
	speaker_input.custom_minimum_size = Vector2(88, 0)
	row.add_child(speaker_input)

	var text_input = LineEdit.new()
	text_input.text = text
	text_input.placeholder_text = "对白文本"
	text_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_input)

	var delete_button = Button.new()
	delete_button.text = "删除"
	delete_button.pressed.connect(_remove_dialogue_line_row.bind(row))
	row.add_child(delete_button)

func _remove_dialogue_line_row(row: Control) -> void:
	if row == null:
		return
	row.queue_free()

func _collect_dialogue_lines_from_panel() -> Array:
	var result: Array = []
	if story_dialogue_lines_container == null:
		return result
	for row in story_dialogue_lines_container.get_children():
		if not (row is HBoxContainer):
			continue
		var speaker := ""
		var text := ""
		var line_edits: Array = []
		for child in row.get_children():
			if child is LineEdit:
				line_edits.append(child)
		if line_edits.size() > 0:
			speaker = str(line_edits[0].text)
		if line_edits.size() > 1:
			text = str(line_edits[1].text)
		result.append({"speaker": speaker, "text": text})
	return result

func _clear_container(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
```

- [ ] **Step 8: Add save and template button handlers**

Add these functions after the dialogue row helpers:

```gdscript
func _save_selected_dialogue() -> void:
	if selected_story_dialogue_id.is_empty():
		_update_status("当前没有可保存的对白。")
		return
	var title_result = story_content_document.update_dialogue_title(selected_story_dialogue_id, story_dialogue_title_input.text)
	if not title_result.get("ok", false):
		_update_status(str(title_result.get("error", "")))
		return
	var lines_result = story_content_document.set_dialogue_lines(selected_story_dialogue_id, _collect_dialogue_lines_from_panel())
	if not lines_result.get("ok", false):
		_update_status(str(lines_result.get("error", "")))
		return
	if story_content_document.save_dialogues():
		story_content_document.load_all()
		_update_story_workbench_for_selection()
		_update_status("对白已保存：%s" % selected_story_dialogue_id)
	else:
		_update_status(story_content_document.last_error)

func _save_selected_quest(quest_id: String) -> void:
	var controls = story_quest_controls.get(quest_id, {})
	if typeof(controls) != TYPE_DICTIONARY or controls.is_empty():
		_update_status("当前没有可保存的任务：%s" % quest_id)
		return
	var title_input = controls.get("title", null)
	var description_input = controls.get("description", null)
	var title = title_input.text if title_input is LineEdit else ""
	var description = description_input.text if description_input is TextEdit else ""
	var result = story_content_document.update_quest_summary(quest_id, title, description)
	if not result.get("ok", false):
		_update_status(str(result.get("error", "")))
		return
	if story_content_document.save_quests():
		story_content_document.load_all()
		_update_story_workbench_for_selection()
		_update_status("任务已保存：%s" % quest_id)
	else:
		_update_status(story_content_document.last_error)

func _create_missing_dialogue_template() -> void:
	if missing_story_dialogue_id.is_empty():
		_update_status("当前没有可创建的对白模板。")
		return
	var result = story_content_document.create_dialogue_template(missing_story_dialogue_id)
	if not result.get("ok", false):
		_update_status(str(result.get("error", "")))
		return
	_update_story_workbench_for_selection()
	_update_status("已创建对白模板，尚未保存：%s" % missing_story_dialogue_id)

func _create_missing_quest_template(quest_id: String = "") -> void:
	var target_quest_id = quest_id.strip_edges()
	if target_quest_id.is_empty():
		target_quest_id = missing_story_quest_id
	if target_quest_id.is_empty():
		_update_status("当前没有可创建的任务模板。")
		return
	var result = story_content_document.create_quest_template(target_quest_id)
	if not result.get("ok", false):
		_update_status(str(result.get("error", "")))
		return
	_update_story_workbench_for_selection()
	_update_status("已创建任务模板，尚未保存：%s" % target_quest_id)
```

- [ ] **Step 9: Run tests and verify Dock wiring passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: `测试通过：82 个测试套件`.

- [ ] **Step 10: Commit Dock integration**

```powershell
git add addons/map_preview/map_preview_plugin.gd tests/test_map_preview_plugin_selection.gd
git commit -m "feat: embed story content workbench in map dock"
```

---

### Task 5: Document the Workbench and Run Final Verification

**Files:**

- Modify: `docs/godot-project-structure.md`

- [ ] **Step 1: Document the story content workbench**

In `docs/godot-project-structure.md`, extend the `双向地图预览编辑器` section after the paragraph about the content reference validator with:

```markdown
剧情内容工作台 v1 嵌入地图预览 Dock。选中地图对象后，Dock 会显示该对象的 `dialogue_id`、`quest_id` 和 `required_quest_id`，并可查看和轻量编辑对应对白标题、对白行、任务标题和任务描述。对象已有占位 ID 但对白或任务缺失时，可以创建最小模板。对白和任务使用独立保存按钮写回 `data/dialogues.json` 和 `data/quests.json`，不会被地图主保存按钮一起保存。v1 只处理对白与任务入口闭环，`options`、`conditions`、`effects`、奖励和战斗上下文仍只显示摘要，不在 Dock 中编辑。
```

- [ ] **Step 2: Run the full automated suite**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

Expected:

- First command exits 0 and prints `测试通过：82 个测试套件`.
- Existing negative-path `push_error` noise for missing maps/items may print during the test run.
- Second command exits 0.

- [ ] **Step 3: Manual editor smoke test**

Open Godot editor manually and verify:

1. Open `scenes/mountain_pass.tscn`.
2. Select `npc_qingshanke` from the map preview object list.
3. Confirm the story content panel shows the selected object entry fields.
4. Confirm the dialogue section shows the current dialogue title and dialogue lines.
5. Temporarily edit one dialogue line and click `保存对白`.
6. Confirm `data/dialogues.json` contains the edited line.
7. Revert the line in the Dock and save again.
8. Select an object with a non-empty missing `dialogue_id` or temporarily create one in `data/maps.json`.
9. Confirm the panel shows `创建对白模板`.
10. Revert any temporary JSON edits immediately.

- [ ] **Step 4: Commit docs and final state**

```powershell
git add docs/godot-project-structure.md
git commit -m "docs: document story content workbench"
```

- [ ] **Step 5: Final status check**

Run:

```powershell
git status --short
git log --oneline -5
```

Expected: `git status --short` prints nothing. The last commits should include:

```text
docs: document story content workbench
feat: embed story content workbench in map dock
test: require story workbench dock wiring
feat: add story content document
test: add story content document coverage
```

---

## Acceptance Checklist

- [ ] `StoryContentDocument` loads and indexes `data/dialogues.json` and `data/quests.json`.
- [ ] `StoryContentDocument` edits dialogue `title` and `lines`.
- [ ] `StoryContentDocument` edits quest `title` and `description`.
- [ ] `StoryContentDocument` creates minimal dialogue and quest templates only for non-empty IDs.
- [ ] `StoryContentDocument.find_quests_for_dialogue()` reports quests referencing the selected dialogue through `start_dialogue` and `complete_dialogue`.
- [ ] Dirty dialogue saves are rejected when `data/dialogues.json` changed externally.
- [ ] Dirty quest saves are rejected when `data/quests.json` changed externally.
- [ ] `MapPreviewPlugin` embeds a story panel in the existing map preview Dock.
- [ ] Selecting a map object refreshes the story panel.
- [ ] Selecting a spawn point or obstacle clears the story panel to an empty state.
- [ ] The story panel can save dialogue independently from map save.
- [ ] The story panel can save quests independently from map save.
- [ ] The map main save button does not call `save_dialogues()` or `save_quests()`.
- [ ] The panel only summarizes `options`, `conditions`, `effects`, rewards, and battle context.
- [ ] Full Godot headless test suite passes with `测试通过：82 个测试套件`.
- [ ] `docs/godot-project-structure.md` documents the v1 boundary.

## Self-Review Notes

Spec coverage:

- Object entry display is covered by Task 4 rendering helpers and plugin source tests.
- Dialogue editing, saving, template creation, and external-change rejection are covered by Task 1 and Task 2.
- Quest editing, saving, template creation, and reverse lookup are covered by Task 1 and Task 2.
- Dock wiring, selection refresh, empty state, and map-save separation are covered by Task 3 and Task 4.
- Documentation and final verification are covered by Task 5.

Scope boundaries:

- No task edits dialogue `options`, `conditions`, `effects`, rewards, or `battle_context`.
- No task edits `dialogue_id`, `quest_id`, or `required_quest_id` from the story panel.
- No task creates an independent story Dock.
- No task implements field-level merge.

Type consistency:

- Document method names in tests match the implementation in Task 2.
- Plugin source tests in Task 3 reference methods added in Task 4.
- The suite count changes from 81 to 82 only when `TestStoryContentDocumentScript` is registered.
