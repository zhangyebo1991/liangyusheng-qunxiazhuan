# Content Reference Validator v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a current-map content reference validator for the Godot map preview Dock so broken map object references show as red/yellow validation messages.

**Architecture:** Add a focused `ContentReferenceValidator` under `addons/map_preview/` that owns content indexing and direct map-object reference rules. `MapPreviewPlugin` remains the UI aggregator: it combines existing layout validation strings with structured reference issues and formats the Dock label. Tests stay data-driven and run through the existing headless Godot suite.

**Tech Stack:** Godot 4.6, GDScript `@tool` editor plugin code, JSON files under `data/`, existing `tests/run_tests.gd` runner, PowerShell verification commands.

---

## Scope

This plan implements [docs/superpowers/specs/2026-05-28-content-reference-validator-v1-design.md](../specs/2026-05-28-content-reference-validator-v1-design.md).

Included:

- Validate direct references from the currently selected map's `objects`.
- Show reference validation results in the existing map preview Dock validation label.
- Treat `battle_id` as a warning because there is no independent battle data source yet.
- Keep dialogue-tree, task-effect, template creation, and click-to-error-location work out of v1.

Excluded:

- Full project-wide story reference scans.
- `next_dialogue_id` validation.
- Dialogue option `conditions` and `effects` validation.
- Quest `complete_effects` validation.
- Missing content template creation.
- New battle or encounter data files.

## File Structure

- Create `addons/map_preview/content_reference_validator.gd`
  Pure validator and content indexer. It reads JSON arrays, indexes records by `id`, reads target map layouts for spawn checks, and returns structured issues.

- Create `tests/test_content_reference_validator.gd`
  Data-driven tests for valid references, missing basic references, exits, battle triggers, effects, warnings, and malformed inputs.

- Modify `tests/run_tests.gd`
  Register `TestContentReferenceValidatorScript` immediately after `TestMapContentDocumentScript` and add the suite next to the other map preview/data suites.

- Modify `addons/map_preview/map_preview_plugin.gd`
  Preload and instantiate the validator. Replace `_update_validation()` with aggregation and formatting helpers that combine layout errors and reference issues.

- Modify `tests/test_map_preview_plugin_selection.gd`
  Extend the existing source-level plugin test to confirm the validator is wired into `_update_validation()` and the three color states are present.

- Modify `docs/godot-project-structure.md`
  Document that the map preview Dock now validates current-map direct content references.

Every verification step uses:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

The current suite count before this plan is `测试通过：80 个测试套件`. After registering `tests/test_content_reference_validator.gd`, the passing count should become `测试通过：81 个测试套件`.

---

### Task 1: Add Failing Validator Tests

**Files:**

- Create: `tests/test_content_reference_validator.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Create the validator test suite**

Create `tests/test_content_reference_validator.gd`:

```gdscript
extends RefCounted

const ContentReferenceValidatorScript = preload("res://addons/map_preview/content_reference_validator.gd")

func run(assertions) -> void:
	_test_valid_current_map_references(assertions)
	_test_missing_basic_references(assertions)
	_test_exit_reference_errors(assertions)
	_test_battle_trigger_references_and_battle_id_warning(assertions)
	_test_effect_reference_errors(assertions)
	_test_malformed_sources_and_fields_report_errors(assertions)

func _test_valid_current_map_references(assertions) -> void:
	var paths = _write_fixture("valid")
	var validator = ContentReferenceValidatorScript.new()
	validator.set_paths(paths.get("data_paths", {}), str(paths.get("layouts_dir", "")))

	var issues = validator.validate_map({
		"id": "demo_map",
		"objects": [
			{
				"id": "npc_valid",
				"type": "npc",
				"dialogue_id": "dialogue_valid",
				"quest_id": "quest_valid",
				"actor_id": "actor_valid"
			},
			{
				"id": "exit_valid",
				"type": "exit",
				"target_map_id": "target_map",
				"target_spawn_id": "arrival"
			},
			{
				"id": "battle_valid",
				"type": "battle_trigger",
				"actor_id": "enemy_valid",
				"units": [
					{"unit_id": "enemy_valid", "actor_id": "enemy_valid", "team": "enemy"}
				],
				"victory_rewards": {
					"loot_table": {
						"entries": [
							{"type": "item", "item_id": "item_valid", "chance": 1.0},
							{"type": "coins", "amount_min": 1, "amount_max": 2}
						]
					}
				}
			},
			{
				"id": "pickup_valid",
				"type": "pickup",
				"effects": [
					{"type": "add_item", "item_id": "item_valid", "amount": 1},
					{"type": "set_quest_status", "quest_id": "quest_valid", "status": "completed"},
					{"type": "resolve_map_object", "object_id": "pickup_valid"},
					{"type": "add_party_member", "actor_id": "actor_valid"}
				]
			}
		]
	})

	assertions.assert_eq(_count_severity(issues, "error"), 0, "合法当前地图引用不应产生 error")
	assertions.assert_eq(_count_severity(issues, "warning"), 0, "合法当前地图引用不应产生 warning")

func _test_missing_basic_references(assertions) -> void:
	var paths = _write_fixture("basic_missing")
	var validator = ContentReferenceValidatorScript.new()
	validator.set_paths(paths.get("data_paths", {}), str(paths.get("layouts_dir", "")))

	var issues = validator.validate_map({
		"id": "demo_map",
		"objects": [
			{
				"id": "npc_missing",
				"type": "npc",
				"dialogue_id": "dialogue_missing",
				"quest_id": "quest_missing",
				"required_quest_id": "required_quest_missing",
				"actor_id": "actor_missing"
			}
		]
	})

	assertions.assert_true(_has_issue(issues, "error", "npc_missing", "dialogue_id", "dialogue_missing"), "缺失对白应产生对象字段 error")
	assertions.assert_true(_has_issue(issues, "error", "npc_missing", "quest_id", "quest_missing"), "缺失 quest_id 应产生对象字段 error")
	assertions.assert_true(_has_issue(issues, "error", "npc_missing", "required_quest_id", "required_quest_missing"), "缺失 required_quest_id 应产生对象字段 error")
	assertions.assert_true(_has_issue(issues, "error", "npc_missing", "actor_id", "actor_missing"), "缺失 actor_id 应产生对象字段 error")

func _test_exit_reference_errors(assertions) -> void:
	var paths = _write_fixture("exit_missing")
	var validator = ContentReferenceValidatorScript.new()
	validator.set_paths(paths.get("data_paths", {}), str(paths.get("layouts_dir", "")))

	var issues = validator.validate_map({
		"id": "demo_map",
		"objects": [
			{"id": "exit_no_target", "type": "exit", "target_map_id": "", "target_spawn_id": "arrival"},
			{"id": "exit_bad_map", "type": "exit", "target_map_id": "missing_map", "target_spawn_id": "arrival"},
			{"id": "exit_bad_spawn", "type": "exit", "target_map_id": "target_map", "target_spawn_id": "missing_spawn"}
		]
	})

	assertions.assert_true(_has_issue(issues, "error", "exit_no_target", "target_map_id", "出口缺少目标地图"), "空 target_map_id 应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "exit_bad_map", "target_map_id", "missing_map"), "不存在 target_map_id 应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "exit_bad_spawn", "target_spawn_id", "missing_spawn"), "不存在 target_spawn_id 应产生 error")
	assertions.assert_false(_has_issue(issues, "error", "exit_bad_map", "target_spawn_id", "arrival"), "目标地图不存在时不应重复报告 target_spawn_id")

func _test_battle_trigger_references_and_battle_id_warning(assertions) -> void:
	var paths = _write_fixture("battle_missing")
	var validator = ContentReferenceValidatorScript.new()
	validator.set_paths(paths.get("data_paths", {}), str(paths.get("layouts_dir", "")))

	var issues = validator.validate_map({
		"id": "demo_map",
		"objects": [
			{
				"id": "battle_missing",
				"type": "battle_trigger",
				"actor_id": "enemy_missing",
				"battle_id": "battle_placeholder",
				"encounter_id": "label_only",
				"units": [
					{"unit_id": "enemy_missing", "actor_id": "enemy_missing", "team": "enemy"}
				],
				"victory_rewards": {
					"loot_table": {
						"entries": [
							{"type": "item", "item_id": "item_missing", "chance": 1.0}
						]
					}
				}
			}
		]
	})

	assertions.assert_true(_has_issue(issues, "error", "battle_missing", "actor_id", "enemy_missing"), "战斗触发点顶层 actor_id 缺失应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "battle_missing", "units[0].actor_id", "enemy_missing"), "战斗单位 actor_id 缺失应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "battle_missing", "victory_rewards.loot_table.entries[0].item_id", "item_missing"), "掉落表物品缺失应产生 error")
	assertions.assert_true(_has_issue(issues, "warning", "battle_missing", "battle_id", "暂不校验"), "battle_id 应产生 warning")
	assertions.assert_false(_has_issue(issues, "error", "battle_missing", "battle_id", "battle_placeholder"), "battle_id 不应产生 error")
	assertions.assert_false(_has_issue(issues, "error", "battle_missing", "encounter_id", "label_only"), "encounter_id 第一版只作标签")

func _test_effect_reference_errors(assertions) -> void:
	var paths = _write_fixture("effect_missing")
	var validator = ContentReferenceValidatorScript.new()
	validator.set_paths(paths.get("data_paths", {}), str(paths.get("layouts_dir", "")))

	var issues = validator.validate_map({
		"id": "demo_map",
		"objects": [
			{
				"id": "pickup_missing",
				"type": "pickup",
				"effects": [
					{"type": "add_item", "item_id": "item_missing", "amount": 1},
					{"type": "remove_item", "item_id": "item_missing_2", "amount": 1},
					{"type": "set_quest_status", "quest_id": "quest_missing", "status": "completed"},
					{"type": "resolve_map_object", "object_id": "object_missing"},
					{"type": "add_party_member", "actor_id": "actor_missing"}
				]
			}
		]
	})

	assertions.assert_true(_has_issue(issues, "error", "pickup_missing", "effects[0].item_id", "item_missing"), "add_item 缺失 item_id 应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "pickup_missing", "effects[1].item_id", "item_missing_2"), "remove_item 缺失 item_id 应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "pickup_missing", "effects[2].quest_id", "quest_missing"), "set_quest_status 缺失 quest_id 应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "pickup_missing", "effects[3].object_id", "object_missing"), "resolve_map_object 缺失 object_id 应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "pickup_missing", "effects[4].actor_id", "actor_missing"), "add_party_member 缺失 actor_id 应产生 error")

func _test_malformed_sources_and_fields_report_errors(assertions) -> void:
	var paths = _write_fixture("malformed")
	var data_paths = paths.get("data_paths", {}).duplicate(true)
	_write_json(str(data_paths.get("dialogues", "")), {"bad": "root"})

	var validator = ContentReferenceValidatorScript.new()
	validator.set_paths(data_paths, str(paths.get("layouts_dir", "")))
	var issues = validator.validate_map({"id": "demo_map", "objects": "bad"})

	assertions.assert_true(_has_issue(issues, "error", "", "dialogues", "必须是数组"), "格式错误的数据源应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "", "objects", "对象列表格式错误"), "objects 不是数组应产生 error")

	var field_issues = validator.validate_map({
		"id": "demo_map",
		"objects": [
			{"id": "bad_fields", "type": "battle_trigger", "units": "bad", "effects": "bad", "victory_rewards": {"loot_table": {"entries": "bad"}}}
		]
	})
	assertions.assert_true(_has_issue(field_issues, "error", "bad_fields", "units", "必须是数组"), "units 格式错误应产生 error")
	assertions.assert_true(_has_issue(field_issues, "error", "bad_fields", "effects", "必须是数组"), "effects 格式错误应产生 error")
	assertions.assert_true(_has_issue(field_issues, "error", "bad_fields", "victory_rewards.loot_table.entries", "必须是数组"), "掉落表 entries 格式错误应产生 error")

func _write_fixture(name: String) -> Dictionary:
	var base = "user://content_reference_validator_%s" % name
	var layouts_dir = "%s_layouts" % base
	var layouts_absolute = ProjectSettings.globalize_path(layouts_dir)
	DirAccess.make_dir_recursive_absolute(layouts_absolute)

	var data_paths = {
		"actors": "%s_actors.json" % base,
		"items": "%s_items.json" % base,
		"quests": "%s_quests.json" % base,
		"dialogues": "%s_dialogues.json" % base,
		"maps": "%s_maps.json" % base
	}
	_write_json(data_paths["actors"], [
		{"id": "actor_valid", "name": "有效角色"},
		{"id": "enemy_valid", "name": "有效敌人"}
	])
	_write_json(data_paths["items"], [
		{"id": "item_valid", "name": "有效物品"}
	])
	_write_json(data_paths["quests"], [
		{"id": "quest_valid", "title": "有效任务"}
	])
	_write_json(data_paths["dialogues"], [
		{"id": "dialogue_valid", "title": "有效对白", "lines": []}
	])
	_write_json(data_paths["maps"], [
		{"id": "demo_map", "name": "演示地图", "objects": []},
		{"id": "target_map", "name": "目标地图", "objects": []}
	])
	_write_json("%s/target_map.json" % layouts_dir, {
		"map_id": "target_map",
		"spawn_points": {"arrival": {"x": 1, "y": 2}}
	})

	return {"data_paths": data_paths, "layouts_dir": layouts_dir}

func _write_json(path: String, value: Variant) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入测试 JSON：%s" % path)
		return
	file.store_string(JSON.stringify(value, "\t"))
	file.close()

func _has_issue(issues: Array, severity: String, object_id: String, field: String, message_part: String) -> bool:
	for issue in issues:
		if typeof(issue) != TYPE_DICTIONARY:
			continue
		if str(issue.get("severity", "")) != severity:
			continue
		if str(issue.get("object_id", "")) != object_id:
			continue
		if str(issue.get("field", "")) != field:
			continue
		if str(issue.get("message", "")).find(message_part) < 0:
			continue
		return true
	return false

func _count_severity(issues: Array, severity: String) -> int:
	var count := 0
	for issue in issues:
		if typeof(issue) == TYPE_DICTIONARY and str(issue.get("severity", "")) == severity:
			count += 1
	return count
```

- [ ] **Step 2: Register the failing suite**

In `tests/run_tests.gd`, add this preload after `TestMapContentDocumentScript`:

```gdscript
const TestContentReferenceValidatorScript = preload("res://tests/test_content_reference_validator.gd")
```

In the `suites` array, add this entry after `TestMapContentDocumentScript.new()`:

```gdscript
		TestContentReferenceValidatorScript.new(),
```

- [ ] **Step 3: Run tests and verify the expected failure**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL before implementation because `res://addons/map_preview/content_reference_validator.gd` does not exist.

- [ ] **Step 4: Commit the failing tests**

```powershell
git add tests/test_content_reference_validator.gd tests/run_tests.gd
git commit -m "test: add content reference validator coverage"
```

---

### Task 2: Implement `ContentReferenceValidator`

**Files:**

- Create: `addons/map_preview/content_reference_validator.gd`
- Test: `tests/test_content_reference_validator.gd`

- [ ] **Step 1: Implement the validator**

Create `addons/map_preview/content_reference_validator.gd`:

```gdscript
@tool
extends RefCounted

const SEVERITY_ERROR := "error"
const SEVERITY_WARNING := "warning"
const DEFAULT_LAYOUTS_DIR := "res://data/map_layouts"
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

func _issue(severity: String, object_id: String, field: String, message: String) -> Dictionary:
	return {
		"severity": severity,
		"object_id": object_id,
		"field": field,
		"message": message,
	}
```

- [ ] **Step 2: Run tests and verify the validator passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: `测试通过：81 个测试套件`. Existing negative-path `push_error` lines for missing maps/items may still print during unrelated tests.

- [ ] **Step 3: Commit the validator**

```powershell
git add addons/map_preview/content_reference_validator.gd tests/test_content_reference_validator.gd tests/run_tests.gd
git commit -m "feat: validate map content references"
```

---

### Task 3: Wire Validator Results Into the Dock

**Files:**

- Modify: `addons/map_preview/map_preview_plugin.gd`
- Modify: `tests/test_map_preview_plugin_selection.gd`

- [ ] **Step 1: Extend the plugin source test**

Modify `tests/test_map_preview_plugin_selection.gd` so `run()` calls the new validation wiring test:

```gdscript
func run(assertions) -> void:
	_test_render_queues_deferred_object_reselect(assertions)
	_test_validation_aggregates_layout_and_content_references(assertions)
```

Add this test function after `_test_render_queues_deferred_object_reselect`:

```gdscript
func _test_validation_aggregates_layout_and_content_references(assertions) -> void:
	var source = _read_plugin_source()
	var validation_body = _function_body(source, "_update_validation")
	assertions.assert_true(
		source.contains("ContentReferenceValidatorScript"),
		"地图预览插件应 preload 内容引用校验器"
	)
	assertions.assert_true(
		source.contains("content_reference_validator = ContentReferenceValidatorScript.new()"),
		"地图预览插件应持有内容引用校验器实例"
	)
	assertions.assert_true(
		validation_body.contains("layout_loader.validate_layout(layout, map_data)"),
		"Dock 校验应保留布局校验"
	)
	assertions.assert_true(
		validation_body.contains("content_reference_validator.validate_map(map_data)"),
		"Dock 校验应合并内容引用校验"
	)
	assertions.assert_true(
		source.contains("func _format_validation_issues"),
		"地图预览插件应封装校验结果格式化"
	)
	assertions.assert_true(
		source.contains("[color=red]") and source.contains("[color=yellow]") and source.contains("[color=green]校验通过[/color]"),
		"校验结果应覆盖 error、warning 和通过三种颜色状态"
	)
```

- [ ] **Step 2: Run tests and verify the expected failure**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL with assertions from `test_map_preview_plugin_selection.gd` because `MapPreviewPlugin` has not wired `ContentReferenceValidatorScript` yet.

- [ ] **Step 3: Add the validator preload and instance**

In `addons/map_preview/map_preview_plugin.gd`, add this preload after `MapLayoutLoaderScript`:

```gdscript
const ContentReferenceValidatorScript = preload("res://addons/map_preview/content_reference_validator.gd")
```

Add this instance after `var layout_loader = MapLayoutLoaderScript.new()`:

```gdscript
var content_reference_validator = ContentReferenceValidatorScript.new()
```

- [ ] **Step 4: Replace `_update_validation()` and add formatting helpers**

Replace the current `_update_validation()` in `addons/map_preview/map_preview_plugin.gd` with this code, then place the helper functions directly below it and above `_update_status()`:

```gdscript
func _update_validation(map_data: Dictionary, layout: Dictionary) -> void:
	var issues: Array[Dictionary] = []
	for layout_error in layout_loader.validate_layout(layout, map_data):
		issues.append({
			"severity": "error",
			"object_id": "",
			"field": "layout",
			"message": str(layout_error),
		})
	for reference_issue in content_reference_validator.validate_map(map_data):
		if typeof(reference_issue) == TYPE_DICTIONARY:
			issues.append(reference_issue)
	validation_label.text = _format_validation_issues(issues)

func _format_validation_issues(issues: Array) -> String:
	var errors := PackedStringArray()
	var warnings := PackedStringArray()
	for issue in issues:
		if typeof(issue) != TYPE_DICTIONARY:
			continue
		var line = _validation_issue_text(issue)
		if str(issue.get("severity", "error")) == "warning":
			warnings.append(line)
		else:
			errors.append(line)
	if not errors.is_empty():
		var lines := PackedStringArray()
		for error in errors:
			lines.append(error)
		for warning in warnings:
			lines.append(warning)
		return "[color=red]%s[/color]" % "\n".join(lines)
	if not warnings.is_empty():
		return "[color=yellow]%s[/color]" % "\n".join(warnings)
	return "[color=green]校验通过[/color]"

func _validation_issue_text(issue: Dictionary) -> String:
	var object_id = str(issue.get("object_id", "")).strip_edges()
	var field = str(issue.get("field", "")).strip_edges()
	var message = str(issue.get("message", "")).strip_edges()
	var prefix := ""
	if not object_id.is_empty() and not field.is_empty():
		prefix = "[%s.%s] " % [object_id, field]
	elif not field.is_empty():
		prefix = "[%s] " % field
	return "%s%s" % [prefix, message]
```

- [ ] **Step 5: Run tests and verify Dock wiring passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: `测试通过：81 个测试套件`.

- [ ] **Step 6: Commit Dock integration**

```powershell
git add addons/map_preview/map_preview_plugin.gd tests/test_map_preview_plugin_selection.gd
git commit -m "feat: show content reference validation in map dock"
```

---

### Task 4: Document the Validator and Run Final Verification

**Files:**

- Modify: `docs/godot-project-structure.md`

- [ ] **Step 1: Document current-map content reference validation**

In `docs/godot-project-structure.md`, extend the `双向地图预览编辑器` section after the existing paragraph about story entry references with:

```markdown
内容引用校验器 v1 会在地图预览 Dock 中校验当前地图对象的直接引用，包括 `dialogue_id`、`quest_id`、`required_quest_id`、`target_map_id`、`target_spawn_id`、`actor_id`、战斗触发点单位角色、地图对象直接 `effects` 和掉落表物品。校验器只报告当前地图入口是否连得上已有内容，不追进对白树、任务完成效果或完整战斗配置。当前项目还没有独立 battle 数据源，因此非空 `battle_id` 只显示 warning。
```

- [ ] **Step 2: Run the full automated suite**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

Expected:

- First command exits 0 and prints `测试通过：81 个测试套件`.
- Existing negative-path `push_error` noise for missing maps/items may print during the test run.
- Second command exits 0.

- [ ] **Step 3: Manual editor smoke test**

Open Godot editor manually and verify:

1. Open `scenes/mountain_pass.tscn`.
2. Confirm the map preview Dock shows `校验通过` or only legitimate warnings for the current data.
3. Temporarily edit `data/maps.json` outside Godot so `npc_qingshanke.dialogue_id` points to `missing_dialogue_for_smoke`.
4. Let the plugin refresh or click `刷新`.
5. Confirm the Dock shows a red message containing `[npc_qingshanke.dialogue_id]` and `missing_dialogue_for_smoke`.
6. Revert the temporary JSON edit immediately.
7. Refresh again and confirm the red message clears.

- [ ] **Step 4: Commit docs and final state**

```powershell
git add docs/godot-project-structure.md
git commit -m "docs: document content reference validation"
```

- [ ] **Step 5: Final status check**

Run:

```powershell
git status --short
git log --oneline -4
```

Expected: `git status --short` prints nothing. The last commits should include:

```text
docs: document content reference validation
feat: show content reference validation in map dock
feat: validate map content references
test: add content reference validator coverage
```

---

## Acceptance Checklist

- [ ] `ContentReferenceValidator.validate_map(map_data)` returns structured issues with `severity`, `object_id`, `field`, and `message`.
- [ ] Current-map object references validate `dialogue_id`, `quest_id`, `required_quest_id`, `actor_id`, exits, battle trigger unit actors, direct object effects, and loot table item ids.
- [ ] Empty optional object-level references do not produce errors.
- [ ] Non-empty `battle_id` produces `warning`, not `error`.
- [ ] `encounter_id` does not produce an error in v1.
- [ ] `MapPreviewPlugin._update_validation()` combines layout errors with reference validation.
- [ ] Dock output uses red for errors, yellow for warning-only state, and green for no issues.
- [ ] `tests/run_tests.gd` registers the new validator suite.
- [ ] Full Godot headless test suite passes with `测试通过：81 个测试套件`.
- [ ] `docs/godot-project-structure.md` documents the v1 boundary.

## Self-Review Notes

Spec coverage:

- Current-map direct references are covered by Task 1 and Task 2.
- Dock aggregation and color states are covered by Task 3.
- `battle_id` warning behavior is covered by Task 1 and Task 2.
- Scope exclusions are preserved: no task touches dialogue tree traversal, quest `complete_effects`, template creation, or battle data extraction.
- Documentation and final verification are covered by Task 4.

Type consistency:

- Planned validator method is `validate_map(map_data: Dictionary) -> Array[Dictionary]`.
- Test helper uses `set_paths(next_data_paths, next_layouts_dir)`; Task 2 defines that method.
- Plugin helper names are `_format_validation_issues()` and `_validation_issue_text()`; Task 3 tests and implementation use the same names.
