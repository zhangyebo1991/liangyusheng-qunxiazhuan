# 江湖记事基础切片 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立可存档的江湖记事能力，让玩家通过独立页面查看任务、传闻，并最多追踪 3 个任务到 HUD。

**Architecture:** 新增 `JournalState` 保存玩家记事状态，新增 `JournalSystem` 统一处理传闻、归档和任务追踪规则。`GameState` 只持有并序列化状态，`EffectSystem` 只通过新效果委托记事系统，HUD 和记事页面只展示数据并发出请求。

**Tech Stack:** Godot 4.6、GDScript、JSON 内容数据、项目本地 Godot headless 测试运行器、PowerShell。

---

## Scope Check

本计划覆盖一个集成切片：江湖记事状态、规则、存档、效果、对白自动记录、HUD 入口、弹出页面和文档更新。虽然涉及多个层次，但它们共同服务同一个玩家能力，且每个任务都可以单独测试和提交。

## File Structure

- Create: `scripts/domain/journal_state.gd`  
  保存 `tracked_quest_ids`、`active_rumors`、`triggered_rumors`，只负责数据规范化和序列化。
- Create: `scripts/systems/journal_system.gd`  
  统一处理添加传闻、传闻归档、任务追踪上限和 UI 数据生成。
- Create: `scripts/scenes/journal_panel.gd`  
  弹出式“江湖记事”页面，展示任务、可追查传闻、已触发传闻和追踪勾选。
- Modify: `scripts/core/game_state.gd`  
  持有 `journal_state`，在新游戏、存档、读档时维护它。
- Modify: `scripts/systems/effect_system.gd`  
  增加 `add_rumor`、`trigger_rumor` 效果，委托 `JournalSystem`。
- Modify: `scripts/systems/dialogue_system.gd`  
  在 `build_dialogue_state()` 中返回对白 `rumor` 字段。
- Modify: `scripts/scenes/hud.gd`  
  增加“记事”按钮、追踪任务区域和相关信号。
- Modify: `scripts/scenes/map_screen_base.gd`  
  接入记事页面、`J` 输入、对白完成自动记录传闻、追踪任务刷新。
- Modify: `project.godot`  
  新增 `journal` 输入动作，按键为 `J`。
- Modify: `data/dialogues.json`  
  给 `road_scholar_rumor` 增加传闻记录数据。
- Modify: `tests/run_tests.gd`  
  注册新增测试套件。
- Create: `tests/test_journal_state.gd`
- Create: `tests/test_journal_system.gd`
- Create: `tests/test_journal_panel.gd`
- Create: `tests/test_journal_map_screen.gd`
- Modify: `tests/test_effect_system.gd`
- Modify: `tests/test_dialogue_options.gd`
- Modify: `tests/test_hud_inventory.gd`
- Modify: `tests/test_save_map_state.gd`
- Modify: `README.md`
- Modify: `docs/godot-project-structure.md`

## Verification Commands

Use the project-local Godot binary when available:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

Expected full-suite success line:

```text
测试通过：28 个测试套件
```

The suite count is 24 before this plan. It becomes 28 after registering four new test files.

---

### Task 1: JournalState Domain Model

**Files:**
- Create: `scripts/domain/journal_state.gd`
- Create: `tests/test_journal_state.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write the failing JournalState test**

Create `tests/test_journal_state.gd`:

```gdscript
extends RefCounted

const JournalStateScript = preload("res://scripts/domain/journal_state.gd")

func run(assertions) -> void:
	var state = JournalStateScript.new()
	state.tracked_quest_ids = ["quest_mountain_trial", "quest_deliver_letter", "", "quest_mountain_trial", "quest_trace_red_thread", "quest_extra"]
	state.active_rumors["rumor_road_red_thread"] = {
		"id": "rumor_road_red_thread",
		"title": "官道红线车辙",
		"text": "官道车辙中夹着红线。",
		"source": "赶路书生",
		"related_quest_id": "quest_trace_red_thread",
		"discovered_at_map_id": "road_outskirts",
	}
	state.triggered_rumors["rumor_old"] = {
		"id": "rumor_old",
		"title": "旧传闻",
		"text": "此传闻已经触发任务。",
	}

	var serialized = state.to_dictionary()
	assertions.assert_eq(serialized.get("tracked_quest_ids", []).size(), 3, "追踪任务序列化时应限制为 3 个有效唯一编号")
	assertions.assert_eq(serialized.get("tracked_quest_ids", [])[0], "quest_mountain_trial", "追踪任务应保持原始顺序")
	assertions.assert_true(serialized.get("active_rumors", {}).has("rumor_road_red_thread"), "可追查传闻应进入序列化结果")
	assertions.assert_true(serialized.get("triggered_rumors", {}).has("rumor_old"), "已触发传闻应进入序列化结果")

	var restored = JournalStateScript.new()
	restored.from_dictionary(serialized)
	assertions.assert_eq(restored.tracked_quest_ids.size(), 3, "反序列化应恢复追踪任务")
	assertions.assert_eq(restored.active_rumors.get("rumor_road_red_thread", {}).get("source", ""), "赶路书生", "反序列化应恢复传闻来源")
	assertions.assert_eq(restored.triggered_rumors.get("rumor_old", {}).get("related_quest_id", ""), "", "缺失可选字段应补为空字符串")

	var old_save = JournalStateScript.new()
	old_save.from_dictionary({})
	assertions.assert_eq(old_save.tracked_quest_ids.size(), 0, "旧存档缺少江湖记事时追踪任务应为空")
	assertions.assert_eq(old_save.active_rumors.size(), 0, "旧存档缺少江湖记事时可追查传闻应为空")
	assertions.assert_eq(old_save.triggered_rumors.size(), 0, "旧存档缺少江湖记事时已触发传闻应为空")

	var invalid = JournalStateScript.new()
	invalid.from_dictionary({
		"tracked_quest_ids": "bad",
		"active_rumors": ["bad"],
		"triggered_rumors": {
			123: "bad",
			"rumor_valid": {
				"id": "rumor_valid",
				"title": "有效传闻",
				"text": "有效正文。"
			}
		}
	})
	assertions.assert_eq(invalid.tracked_quest_ids.size(), 0, "坏存档中的追踪任务应安全清空")
	assertions.assert_eq(invalid.active_rumors.size(), 0, "坏存档中的可追查传闻容器应安全清空")
	assertions.assert_true(invalid.triggered_rumors.has("rumor_valid"), "坏存档中有效传闻记录应保留")
	assertions.assert_true(not invalid.triggered_rumors.has("123"), "坏存档中非字典传闻记录应丢弃")
```

In `tests/run_tests.gd`, add this preload near the other domain/system tests:

```gdscript
const TestJournalStateScript = preload("res://tests/test_journal_state.gd")
```

Add the suite after `TestDomainModelsScript.new()`:

```gdscript
TestJournalStateScript.new(),
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL during preload because `res://scripts/domain/journal_state.gd` does not exist.

- [ ] **Step 3: Implement JournalState**

Create `scripts/domain/journal_state.gd`:

```gdscript
class_name JournalState
extends RefCounted

const MAX_TRACKED_QUESTS := 3
const RUMOR_FIELDS := [
	"id",
	"title",
	"text",
	"source",
	"related_quest_id",
	"discovered_at_map_id",
]

var tracked_quest_ids: Array[String] = []
var active_rumors: Dictionary = {}
var triggered_rumors: Dictionary = {}

func to_dictionary() -> Dictionary:
	normalize()
	return {
		"tracked_quest_ids": tracked_quest_ids.duplicate(),
		"active_rumors": active_rumors.duplicate(true),
		"triggered_rumors": triggered_rumors.duplicate(true),
	}

func from_dictionary(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		tracked_quest_ids = []
		active_rumors = {}
		triggered_rumors = {}
		return
	tracked_quest_ids = _to_tracked_ids(data.get("tracked_quest_ids", []))
	active_rumors = _to_rumor_dictionary(data.get("active_rumors", {}))
	triggered_rumors = _to_rumor_dictionary(data.get("triggered_rumors", {}))
	normalize()

func normalize() -> void:
	tracked_quest_ids = _to_tracked_ids(tracked_quest_ids)
	active_rumors = _to_rumor_dictionary(active_rumors)
	triggered_rumors = _to_rumor_dictionary(triggered_rumors)
	for rumor_id in triggered_rumors.keys():
		active_rumors.erase(rumor_id)

func _to_tracked_ids(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for raw_id in value:
		var quest_id = str(raw_id)
		if quest_id.is_empty() or result.has(quest_id):
			continue
		result.append(quest_id)
		if result.size() >= MAX_TRACKED_QUESTS:
			break
	return result

func _to_rumor_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for raw_key in value.keys():
		var record_value = value[raw_key]
		if typeof(record_value) != TYPE_DICTIONARY:
			continue
		var record = _normalize_rumor_record(record_value)
		var rumor_id = str(record.get("id", ""))
		if rumor_id.is_empty():
			rumor_id = str(raw_key)
			record["id"] = rumor_id
		if rumor_id.is_empty():
			continue
		result[rumor_id] = record
	return result

func _normalize_rumor_record(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field in RUMOR_FIELDS:
		result[field] = str(value.get(field, ""))
	return result
```

- [ ] **Step 4: Run the focused test and verify it passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS for the newly added `JournalState` assertions and all previously registered suites.

- [ ] **Step 5: Commit**

```powershell
git add scripts/domain/journal_state.gd tests/test_journal_state.gd tests/run_tests.gd
git commit -m "feat: 添加江湖记事状态"
```

---

### Task 2: JournalSystem Rules

**Files:**
- Create: `scripts/systems/journal_system.gd`
- Create: `tests/test_journal_system.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write the failing JournalSystem test**

Create `tests/test_journal_system.gd`:

```gdscript
extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const JournalStateScript = preload("res://scripts/domain/journal_state.gd")
const JournalSystemScript = preload("res://scripts/systems/journal_system.gd")

class StubRepository:
	extends Node
	var quests: Dictionary = {
		"quest_mountain_trial": {"id": "quest_mountain_trial", "title": "山道试剑", "description": "击退山道强人。"},
		"quest_deliver_letter": {"id": "quest_deliver_letter", "title": "送信到客栈", "description": "替脚夫送信。"},
		"quest_trace_red_thread": {"id": "quest_trace_red_thread", "title": "追查红线车辙", "description": "查明红线记号。"},
		"quest_extra": {"id": "quest_extra", "title": "额外任务", "description": "第四个任务。"},
	}
	func get_quest(quest_id: String) -> Dictionary:
		return quests.get(quest_id, {})

func run(assertions) -> void:
	var journal = JournalStateScript.new()
	var system = JournalSystemScript.new()

	var add_result = system.add_rumor(journal, {
		"id": "rumor_road_red_thread",
		"title": "官道红线车辙",
		"text": "官道车辙中夹着红线。",
		"source": "赶路书生",
		"related_quest_id": "quest_trace_red_thread",
	}, {"map_id": "road_outskirts"})
	assertions.assert_true(bool(add_result.get("success", false)), "合法传闻应添加成功")
	assertions.assert_true(journal.active_rumors.has("rumor_road_red_thread"), "传闻应进入可追查列表")
	assertions.assert_eq(journal.active_rumors.get("rumor_road_red_thread", {}).get("discovered_at_map_id", ""), "road_outskirts", "缺省发现地图应来自上下文")

	var duplicate = system.add_rumor(journal, {
		"id": "rumor_road_red_thread",
		"title": "官道红线车辙",
		"text": "重复正文。",
	})
	assertions.assert_true(bool(duplicate.get("success", false)), "重复传闻应作为安全成功处理")
	assertions.assert_eq(journal.active_rumors.size(), 1, "重复传闻不应重复记录")
	assertions.assert_true(bool(duplicate.get("duplicate", false)), "重复传闻结果应标记 duplicate")

	var missing_id = system.add_rumor(journal, {"title": "无编号", "text": "无编号正文。"})
	assertions.assert_true(not bool(missing_id.get("success", true)), "空传闻编号应失败")
	assertions.assert_eq(missing_id.get("message", ""), "传闻编号缺失。", "空传闻编号应返回中文提示")

	var missing_text = system.add_rumor(journal, {"id": "rumor_empty", "title": "空正文", "text": ""})
	assertions.assert_true(not bool(missing_text.get("success", true)), "空传闻正文应失败")
	assertions.assert_eq(missing_text.get("message", ""), "传闻内容缺失。", "空传闻正文应返回中文提示")

	var trigger_result = system.trigger_rumor(journal, "rumor_road_red_thread")
	assertions.assert_true(bool(trigger_result.get("success", false)), "已有传闻应可归档为已触发")
	assertions.assert_true(not journal.active_rumors.has("rumor_road_red_thread"), "归档后传闻不应留在可追查列表")
	assertions.assert_true(journal.triggered_rumors.has("rumor_road_red_thread"), "归档后传闻应进入已触发列表")

	var missing_trigger = system.trigger_rumor(journal, "missing_rumor")
	assertions.assert_true(not bool(missing_trigger.get("success", true)), "触发不存在传闻应失败")
	assertions.assert_eq(missing_trigger.get("message", ""), "传闻尚未记录：missing_rumor", "触发不存在传闻应返回中文提示")

	system.add_rumor(journal, {
		"id": "rumor_for_quest",
		"title": "任务传闻",
		"text": "这条传闻对应任务。",
		"related_quest_id": "quest_trace_red_thread",
	})
	var quest_trigger = system.mark_rumors_triggered_for_quest(journal, "quest_trace_red_thread")
	assertions.assert_true(bool(quest_trigger.get("success", false)), "按任务归档相关传闻应成功")
	assertions.assert_true(journal.triggered_rumors.has("rumor_for_quest"), "相关任务传闻应进入已触发列表")

	assertions.assert_true(bool(system.toggle_tracked_quest(journal, "quest_mountain_trial").get("success", false)), "第一个任务应可追踪")
	assertions.assert_true(bool(system.toggle_tracked_quest(journal, "quest_deliver_letter").get("success", false)), "第二个任务应可追踪")
	assertions.assert_true(bool(system.toggle_tracked_quest(journal, "quest_trace_red_thread").get("success", false)), "第三个任务应可追踪")
	var fourth = system.toggle_tracked_quest(journal, "quest_extra")
	assertions.assert_true(not bool(fourth.get("success", true)), "第四个追踪任务应被拒绝")
	assertions.assert_eq(fourth.get("message", ""), "最多只能追踪 3 个任务。", "超过追踪上限应返回中文提示")
	assertions.assert_eq(journal.tracked_quest_ids.size(), 3, "超过上限后原追踪列表不应改变")
	assertions.assert_true(bool(system.toggle_tracked_quest(journal, "quest_deliver_letter").get("success", false)), "已追踪任务应可取消追踪")
	assertions.assert_true(not system.is_quest_tracked(journal, "quest_deliver_letter"), "取消后任务不应继续追踪")

	var state = GameStateScript.new()
	state.start_new_game()
	state.quest_system.start_quest("quest_mountain_trial")
	state.quest_system.set_status("quest_deliver_letter", "completed")
	journal.tracked_quest_ids = ["quest_mountain_trial", "quest_trace_red_thread"]
	var repository = StubRepository.new()
	var tasks = system.build_task_entries(state, repository)
	assertions.assert_eq(tasks.size(), 3, "任务条目应包含已有状态任务和追踪任务")
	assertions.assert_eq(tasks[0].get("title", ""), "山道试剑", "任务条目应读取任务标题")
	assertions.assert_true(bool(tasks[0].get("tracked", false)), "任务条目应标记追踪状态")
	var tracked = system.build_tracked_task_entries(state, repository)
	assertions.assert_eq(tracked.size(), 2, "追踪任务条目应按追踪列表生成")
	assertions.assert_eq(tracked[0].get("status_text", ""), "进行中", "任务状态应转成中文")

	var rumor_entries = system.build_rumor_entries(journal)
	assertions.assert_true(rumor_entries.get("active", []).is_empty(), "已全部归档时可追查传闻列表应为空")
	assertions.assert_true(rumor_entries.get("triggered", []).size() >= 2, "已触发传闻列表应包含归档传闻")

	state.free()
	repository.free()
```

In `tests/run_tests.gd`, add:

```gdscript
const TestJournalSystemScript = preload("res://tests/test_journal_system.gd")
```

Add the suite after `TestJournalStateScript.new()`:

```gdscript
TestJournalSystemScript.new(),
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL during preload because `res://scripts/systems/journal_system.gd` does not exist.

- [ ] **Step 3: Implement JournalSystem**

Create `scripts/systems/journal_system.gd`:

```gdscript
extends RefCounted

const JournalStateScript = preload("res://scripts/domain/journal_state.gd")
const MAX_TRACKED_QUESTS := 3

func add_rumor(journal_state, rumor_data: Variant, context: Dictionary = {}) -> Dictionary:
	if journal_state == null:
		return _failure("江湖记事状态缺失。")
	if typeof(rumor_data) != TYPE_DICTIONARY:
		return _failure("传闻格式错误。")
	var record = _normalize_rumor_record(rumor_data, context)
	var rumor_id = str(record.get("id", ""))
	if rumor_id.is_empty():
		return _failure("传闻编号缺失。")
	if str(record.get("text", "")).is_empty():
		return _failure("传闻内容缺失。")
	if journal_state.triggered_rumors.has(rumor_id):
		return _success("传闻已归入已触发列表。", {"duplicate": true, "rumor_id": rumor_id})
	if journal_state.active_rumors.has(rumor_id):
		return _success("传闻已记录。", {"duplicate": true, "rumor_id": rumor_id})
	journal_state.active_rumors[rumor_id] = record
	journal_state.normalize()
	return _success("传闻已记入江湖记事。", {"rumor_id": rumor_id})

func trigger_rumor(journal_state, rumor_id: String) -> Dictionary:
	if journal_state == null:
		return _failure("江湖记事状态缺失。")
	var normalized_id = str(rumor_id)
	if normalized_id.is_empty():
		return _failure("传闻编号缺失。")
	if journal_state.triggered_rumors.has(normalized_id):
		return _success("传闻已归入已触发列表。", {"duplicate": true, "rumor_id": normalized_id})
	if not journal_state.active_rumors.has(normalized_id):
		return _failure("传闻尚未记录：%s" % normalized_id)
	journal_state.triggered_rumors[normalized_id] = journal_state.active_rumors[normalized_id].duplicate(true)
	journal_state.active_rumors.erase(normalized_id)
	journal_state.normalize()
	return _success("传闻已移入已触发列表。", {"rumor_id": normalized_id})

func mark_rumors_triggered_for_quest(journal_state, quest_id: String) -> Dictionary:
	if journal_state == null:
		return _failure("江湖记事状态缺失。")
	var normalized_quest_id = str(quest_id)
	if normalized_quest_id.is_empty():
		return _failure("任务编号缺失。")
	var moved: Array[String] = []
	for rumor_id in journal_state.active_rumors.keys():
		var record = journal_state.active_rumors[rumor_id]
		if str(record.get("related_quest_id", "")) != normalized_quest_id:
			continue
		moved.append(str(rumor_id))
	for rumor_id in moved:
		journal_state.triggered_rumors[rumor_id] = journal_state.active_rumors[rumor_id].duplicate(true)
		journal_state.active_rumors.erase(rumor_id)
	journal_state.normalize()
	if moved.is_empty():
		return _success("没有相关传闻需要归档。", {"moved": moved})
	return _success("相关传闻已移入已触发列表。", {"moved": moved})

func toggle_tracked_quest(journal_state, quest_id: String) -> Dictionary:
	if journal_state == null:
		return _failure("江湖记事状态缺失。")
	var normalized_id = str(quest_id)
	if normalized_id.is_empty():
		return _failure("任务编号缺失。")
	journal_state.normalize()
	if journal_state.tracked_quest_ids.has(normalized_id):
		journal_state.tracked_quest_ids.erase(normalized_id)
		return _success("已取消追踪任务。", {"quest_id": normalized_id, "tracked": false})
	if journal_state.tracked_quest_ids.size() >= MAX_TRACKED_QUESTS:
		return _failure("最多只能追踪 3 个任务。")
	journal_state.tracked_quest_ids.append(normalized_id)
	return _success("已追踪任务。", {"quest_id": normalized_id, "tracked": true})

func is_quest_tracked(journal_state, quest_id: String) -> bool:
	if journal_state == null:
		return false
	return journal_state.tracked_quest_ids.has(str(quest_id))

func build_task_entries(game_state, repository) -> Array:
	var quest_ids: Array[String] = []
	if game_state != null and game_state.quest_system != null:
		for raw_quest_id in game_state.quest_system.quest_status.keys():
			var quest_id = str(raw_quest_id)
			if not quest_id.is_empty() and not quest_ids.has(quest_id):
				quest_ids.append(quest_id)
	if game_state != null and game_state.journal_state != null:
		for quest_id in game_state.journal_state.tracked_quest_ids:
			if not quest_id.is_empty() and not quest_ids.has(quest_id):
				quest_ids.append(quest_id)
	var result: Array = []
	for quest_id in quest_ids:
		result.append(_build_task_entry(game_state, repository, quest_id))
	return result

func build_tracked_task_entries(game_state, repository) -> Array:
	var result: Array = []
	if game_state == null or game_state.journal_state == null:
		return result
	for quest_id in game_state.journal_state.tracked_quest_ids:
		result.append(_build_task_entry(game_state, repository, quest_id))
	return result

func build_rumor_entries(journal_state) -> Dictionary:
	if journal_state == null:
		return {"active": [], "triggered": []}
	journal_state.normalize()
	return {
		"active": _rumor_values(journal_state.active_rumors),
		"triggered": _rumor_values(journal_state.triggered_rumors),
	}

func _build_task_entry(game_state, repository, quest_id: String) -> Dictionary:
	var quest = repository.get_quest(quest_id) if repository != null and repository.has_method("get_quest") else {}
	var status = game_state.quest_system.get_status(quest_id) if game_state != null and game_state.quest_system != null else "not_started"
	return {
		"id": quest_id,
		"title": str(quest.get("title", quest_id)),
		"description": str(quest.get("description", "")),
		"status": status,
		"status_text": _status_text(status),
		"tracked": game_state != null and game_state.journal_state != null and game_state.journal_state.tracked_quest_ids.has(quest_id),
	}

func _status_text(status: String) -> String:
	match status:
		"active":
			return "进行中"
		"ready_to_complete":
			return "可交付"
		"completed":
			return "已完成"
		_:
			return "未开始"

func _rumor_values(source: Dictionary) -> Array:
	var result: Array = []
	for rumor_id in source.keys():
		if typeof(source[rumor_id]) == TYPE_DICTIONARY:
			result.append(source[rumor_id].duplicate(true))
	return result

func _normalize_rumor_record(rumor_data: Dictionary, context: Dictionary) -> Dictionary:
	var record: Dictionary = {
		"id": str(rumor_data.get("id", "")),
		"title": str(rumor_data.get("title", "")),
		"text": str(rumor_data.get("text", "")),
		"source": str(rumor_data.get("source", "")),
		"related_quest_id": str(rumor_data.get("related_quest_id", "")),
		"discovered_at_map_id": str(rumor_data.get("discovered_at_map_id", context.get("map_id", ""))),
	}
	if record["title"].is_empty():
		record["title"] = record["id"]
	return record

func _success(message: String, extra: Dictionary = {}) -> Dictionary:
	var result = {
		"success": true,
		"message": message,
		"errors": [],
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result

func _failure(message: String) -> Dictionary:
	return {
		"success": false,
		"message": message,
		"errors": [message],
	}
```

- [ ] **Step 4: Run the focused test and verify it passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS for `JournalSystem` assertions.

- [ ] **Step 5: Commit**

```powershell
git add scripts/systems/journal_system.gd tests/test_journal_system.gd tests/run_tests.gd
git commit -m "feat: 添加江湖记事规则系统"
```

---

### Task 3: GameState Persistence

**Files:**
- Modify: `scripts/core/game_state.gd`
- Modify: `tests/test_save_map_state.gd`

- [ ] **Step 1: Extend the failing save/load test**

In `tests/test_save_map_state.gd`, after `state.add_martial_proficiency("basic_sword", 3)`, add:

```gdscript
	state.journal_state.tracked_quest_ids = ["quest_mountain_trial"]
	state.journal_state.active_rumors["rumor_road_red_thread"] = {
		"id": "rumor_road_red_thread",
		"title": "官道红线车辙",
		"text": "官道车辙中夹着红线。",
		"source": "赶路书生",
		"related_quest_id": "quest_trace_red_thread",
		"discovered_at_map_id": "road_outskirts",
	}
```

After the existing assertion for `restored.get_martial_proficiency("basic_sword")`, add:

```gdscript
	assertions.assert_eq(restored.journal_state.tracked_quest_ids.size(), 1, "读档应恢复追踪任务数量")
	assertions.assert_eq(restored.journal_state.tracked_quest_ids[0], "quest_mountain_trial", "读档应恢复追踪任务编号")
	assertions.assert_true(restored.journal_state.active_rumors.has("rumor_road_red_thread"), "读档应恢复可追查传闻")
	assertions.assert_eq(restored.journal_state.active_rumors.get("rumor_road_red_thread", {}).get("source", ""), "赶路书生", "读档应恢复传闻来源")
```

After the old save assertions for missing proficiency fallback, add:

```gdscript
	assertions.assert_eq(old_save_state.journal_state.tracked_quest_ids.size(), 0, "旧存档缺少江湖记事时追踪任务应为空")
	assertions.assert_eq(old_save_state.journal_state.active_rumors.size(), 0, "旧存档缺少江湖记事时可追查传闻应为空")
```

After the invalid save proficiency assertion, add:

```gdscript
	assertions.assert_eq(invalid_hp_state.journal_state.tracked_quest_ids.size(), 0, "坏存档缺少江湖记事时应安全初始化")
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `GameState` has no `journal_state` property.

- [ ] **Step 3: Wire JournalState into GameState**

In `scripts/core/game_state.gd`, add this preload after `MapStateScript`:

```gdscript
const JournalStateScript = preload("res://scripts/domain/journal_state.gd")
```

Add this property after `var map_state = MapStateScript.new()`:

```gdscript
var journal_state = JournalStateScript.new()
```

In `start_new_game()`, after `map_state = MapStateScript.new()`, add:

```gdscript
	journal_state = JournalStateScript.new()
```

In `to_dictionary()`, add `"journal_state"` after `"map_state"`:

```gdscript
		"journal_state": journal_state.to_dictionary(),
```

In `from_dictionary(data)`, after `map_state.from_dictionary(data.get("map_state", {}))`, add:

```gdscript
	journal_state = JournalStateScript.new()
	journal_state.from_dictionary(data.get("journal_state", {}))
```

- [ ] **Step 4: Run the focused test and verify it passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS for save/load journal assertions and previous save assertions.

- [ ] **Step 5: Commit**

```powershell
git add scripts/core/game_state.gd tests/test_save_map_state.gd
git commit -m "feat: 持久化江湖记事状态"
```

---

### Task 4: Rumor Effects

**Files:**
- Modify: `scripts/systems/effect_system.gd`
- Modify: `tests/test_effect_system.gd`

- [ ] **Step 1: Write failing effect assertions**

In `tests/test_effect_system.gd`, add the following block after the `remove_item` success assertions:

```gdscript
	var rumor_result = effect_system.apply_effects(state, [
		{
			"type": "add_rumor",
			"rumor": {
				"id": "rumor_road_red_thread",
				"title": "官道红线车辙",
				"text": "官道车辙中夹着红线。",
				"source": "赶路书生",
				"related_quest_id": "quest_trace_red_thread"
			}
		}
	])
	assertions.assert_true(bool(rumor_result.get("success", false)), "add_rumor 应写入江湖记事")
	assertions.assert_true(state.journal_state.active_rumors.has("rumor_road_red_thread"), "add_rumor 应加入可追查传闻")
	assertions.assert_eq(rumor_result.get("rumors", [])[0].get("id", ""), "rumor_road_red_thread", "效果结果应记录传闻编号")

	var trigger_rumor = effect_system.apply_effects(state, [
		{"type": "trigger_rumor", "rumor_id": "rumor_road_red_thread"}
	])
	assertions.assert_true(bool(trigger_rumor.get("success", false)), "trigger_rumor 应归档已有传闻")
	assertions.assert_true(not state.journal_state.active_rumors.has("rumor_road_red_thread"), "trigger_rumor 后传闻不应留在可追查列表")
	assertions.assert_true(state.journal_state.triggered_rumors.has("rumor_road_red_thread"), "trigger_rumor 后传闻应进入已触发列表")
	assertions.assert_eq(trigger_rumor.get("triggered_rumors", [])[0], "rumor_road_red_thread", "效果结果应记录归档传闻编号")
```

Before `state.free()`, add:

```gdscript
	var invalid_rumor = effect_system.apply_effects(state, [{"type": "add_rumor", "rumor": {"id": "", "text": "无编号。"}}])
	assertions.assert_true(not invalid_rumor.get("success", true), "add_rumor 缺少编号时应失败")
	assertions.assert_eq(invalid_rumor.get("errors", [])[0], "传闻编号缺失。", "add_rumor 缺少编号应返回中文错误")

	var missing_rumor_trigger = effect_system.apply_effects(state, [{"type": "trigger_rumor", "rumor_id": "missing_rumor"}])
	assertions.assert_true(not missing_rumor_trigger.get("success", true), "trigger_rumor 不存在传闻时应失败")
	assertions.assert_eq(missing_rumor_trigger.get("errors", [])[0], "传闻尚未记录：missing_rumor", "trigger_rumor 不存在传闻应返回中文错误")
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL with unknown effect type `add_rumor`.

- [ ] **Step 3: Implement rumor effects**

In `scripts/systems/effect_system.gd`, add this preload below the existing constants:

```gdscript
const JournalSystemScript = preload("res://scripts/systems/journal_system.gd")
```

In `apply_effect()`, add match cases before `_:`:

```gdscript
		"add_rumor":
			_apply_add_rumor(result, game_state, effect, _context)
		"trigger_rumor":
			_apply_trigger_rumor(result, game_state, effect)
```

Add these functions after `_apply_add_martial_proficiency()`:

```gdscript
func _apply_add_rumor(result: Dictionary, game_state, effect: Dictionary, context: Dictionary) -> void:
	if not _has_journal_state(game_state):
		_add_error(result, "江湖记事状态缺失。")
		return
	var journal_system = JournalSystemScript.new()
	var rumor_result = journal_system.add_rumor(game_state.journal_state, effect.get("rumor", {}), context)
	if not bool(rumor_result.get("success", false)):
		_add_error(result, str(rumor_result.get("message", "传闻记录失败。")))
		return
	var rumor_id = str(rumor_result.get("rumor_id", ""))
	if not rumor_id.is_empty():
		var rumors: Array = result["rumors"]
		rumors.append({"id": rumor_id, "duplicate": bool(rumor_result.get("duplicate", false))})
	_mark_applied(result, str(rumor_result.get("message", "传闻已记入江湖记事。")))

func _apply_trigger_rumor(result: Dictionary, game_state, effect: Dictionary) -> void:
	if not _has_journal_state(game_state):
		_add_error(result, "江湖记事状态缺失。")
		return
	var journal_system = JournalSystemScript.new()
	var rumor_result = journal_system.trigger_rumor(game_state.journal_state, str(effect.get("rumor_id", "")))
	if not bool(rumor_result.get("success", false)):
		_add_error(result, str(rumor_result.get("message", "传闻归档失败。")))
		return
	var rumor_id = str(rumor_result.get("rumor_id", ""))
	if not rumor_id.is_empty():
		var triggered: Array = result["triggered_rumors"]
		triggered.append(rumor_id)
	_mark_applied(result, str(rumor_result.get("message", "传闻已移入已触发列表。")))

func _has_journal_state(game_state) -> bool:
	return game_state != null and "journal_state" in game_state and game_state.journal_state != null
```

In `_empty_result()`, add these arrays:

```gdscript
		"rumors": [],
		"triggered_rumors": [],
```

In `_merge_result()`, include the new keys in the array merge list:

```gdscript
	for key in ["messages", "errors", "items", "removed_items", "flags", "quests", "resolved_objects", "martial_proficiency", "rumors", "triggered_rumors"]:
```

- [ ] **Step 4: Run the focused test and verify it passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS for `EffectSystem` rumor effect assertions and existing effects.

- [ ] **Step 5: Commit**

```powershell
git add scripts/systems/effect_system.gd tests/test_effect_system.gd
git commit -m "feat: 添加传闻效果"
```

---

### Task 5: Dialogue Rumor Metadata and Content

**Files:**
- Modify: `scripts/systems/dialogue_system.gd`
- Modify: `data/dialogues.json`
- Modify: `tests/test_dialogue_options.gd`
- Modify: `tests/test_story_event_data.gd`

- [ ] **Step 1: Write failing dialogue rumor assertions**

In `tests/test_dialogue_options.gd`, add `rumor` to the stub `repository.dialogue` after `options`:

```gdscript
		"rumor": {
			"id": "rumor_branch_test",
			"title": "分支测试传闻",
			"text": "这是分支测试传闻。",
			"source": "测试者",
			"related_quest_id": "quest_branch_test"
		}
```

After the title assertion for `dialogue_state`, add:

```gdscript
	assertions.assert_eq(dialogue_state.get("rumor", {}).get("id", ""), "rumor_branch_test", "对话状态应包含传闻数据")
```

In `tests/test_story_event_data.gd`, add assertions after the existing `road_scholar_rumor` lookup:

```gdscript
	var rumor_dialogue = repository.get_dialogue("road_scholar_rumor")
	var rumor = rumor_dialogue.get("rumor", {})
	assertions.assert_eq(rumor.get("id", ""), "rumor_road_red_thread", "官道传闻对白应配置传闻编号")
	assertions.assert_eq(rumor.get("related_quest_id", ""), "quest_trace_red_thread", "官道传闻应声明相关任务编号")
	assertions.assert_true(not str(rumor.get("text", "")).is_empty(), "官道传闻应配置正文")
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `build_dialogue_state()` does not include `rumor`, and `data/dialogues.json` has no `rumor` field.

- [ ] **Step 3: Return rumor data from DialogueSystem**

In `scripts/systems/dialogue_system.gd`, change the return dictionary in `build_dialogue_state()` to include `rumor`:

```gdscript
	return {
		"id": str(dialogue.get("id", dialogue_id)),
		"title": str(dialogue.get("title", "")),
		"lines": lines.duplicate(true),
		"options": _build_options(dialogue, game_state),
		"rumor": _build_rumor(dialogue),
	}
```

Add this helper before `_build_options()`:

```gdscript
func _build_rumor(dialogue: Dictionary) -> Dictionary:
	var rumor = dialogue.get("rumor", {})
	if typeof(rumor) != TYPE_DICTIONARY:
		return {}
	return rumor.duplicate(true)
```

- [ ] **Step 4: Add the官道书生 rumor content**

In `data/dialogues.json`, update the `road_scholar_rumor` record to include:

```json
    "rumor": {
      "id": "rumor_road_red_thread",
      "title": "官道红线车辙",
      "text": "官道车辙中夹着红线，疑似飞红巾一脉留下的记号。",
      "source": "赶路书生",
      "related_quest_id": "quest_trace_red_thread"
    }
```

The full record should become:

```json
  {
    "id": "road_scholar_rumor",
    "title": "车辙传闻",
    "lines": [
      {"speaker": "赶路书生", "text": "昨夜有马队沿官道急行，车辙深处夹着红线，像是飞红巾一脉留下的记号。"}
    ],
    "rumor": {
      "id": "rumor_road_red_thread",
      "title": "官道红线车辙",
      "text": "官道车辙中夹着红线，疑似飞红巾一脉留下的记号。",
      "source": "赶路书生",
      "related_quest_id": "quest_trace_red_thread"
    }
  }
```

- [ ] **Step 5: Run the focused test and verify it passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS for dialogue rumor assertions and story event data assertions.

- [ ] **Step 6: Commit**

```powershell
git add scripts/systems/dialogue_system.gd data/dialogues.json tests/test_dialogue_options.gd tests/test_story_event_data.gd
git commit -m "feat: 为对白添加传闻数据"
```

---

### Task 6: HUD Journal Entry and Tracked Task Display

**Files:**
- Modify: `scripts/scenes/hud.gd`
- Modify: `tests/test_hud_inventory.gd`

- [ ] **Step 1: Write failing HUD assertions**

In `tests/test_hud_inventory.gd`, after `hud._ready()`, add:

```gdscript
	var journal_requests: Array[int] = []
	hud.journal_requested.connect(func(): journal_requests.append(1))
	assertions.assert_eq(hud.journal_button.text, "记事", "HUD 应显示记事按钮")
	hud.journal_button.pressed.emit()
	assertions.assert_eq(journal_requests.size(), 1, "点击记事按钮应发出请求信号")

	hud.set_tracked_tasks([
		{"title": "山道试剑", "status_text": "进行中"},
		{"title": "送信到客栈", "status_text": "已完成"},
		{"title": "追查红线车辙", "status_text": "未开始"},
		{"title": "第四任务", "status_text": "未开始"}
	])
	assertions.assert_eq(hud.tracked_task_list.get_child_count(), 3, "HUD 最多显示 3 个追踪任务")
	assertions.assert_eq(hud.tracked_task_list.get_child(0).text, "山道试剑：进行中", "追踪任务应显示标题和状态")

	hud.set_tracked_tasks([])
	assertions.assert_eq(hud.tracked_task_list.get_child_count(), 0, "空追踪任务应清空 HUD 追踪区")
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `hud.gd` has no `journal_requested`, `journal_button`, or `tracked_task_list`.

- [ ] **Step 3: Implement HUD journal controls**

In `scripts/scenes/hud.gd`, add this signal after existing signals:

```gdscript
signal journal_requested
```

Add these properties after `var message_label: Label`:

```gdscript
var journal_button: Button
var tracked_task_list: VBoxContainer
```

In `_ready()`, after `message_label` is added, add:

```gdscript
	journal_button = Button.new()
	journal_button.text = "记事"
	journal_button.position = Vector2(1120, 20)
	journal_button.size = Vector2(96, 36)
	journal_button.pressed.connect(func(): journal_requested.emit())
	add_child(journal_button)

	tracked_task_list = VBoxContainer.new()
	tracked_task_list.position = Vector2(24, 56)
	tracked_task_list.size = Vector2(520, 96)
	add_child(tracked_task_list)
```

Add this public method after `show_message()`:

```gdscript
func set_tracked_tasks(tasks: Array) -> void:
	for child in tracked_task_list.get_children():
		tracked_task_list.remove_child(child)
		child.queue_free()
	var count = min(tasks.size(), 3)
	for index in range(count):
		var task = tasks[index]
		if typeof(task) != TYPE_DICTIONARY:
			continue
		var label = Label.new()
		label.text = "%s：%s" % [str(task.get("title", "未知任务")), str(task.get("status_text", ""))]
		label.size = Vector2(520, 28)
		tracked_task_list.add_child(label)
```

- [ ] **Step 4: Run the focused test and verify it passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS for HUD journal controls and existing inventory/shop assertions.

- [ ] **Step 5: Commit**

```powershell
git add scripts/scenes/hud.gd tests/test_hud_inventory.gd
git commit -m "feat: 添加江湖记事 HUD 入口"
```

---

### Task 7: Journal Panel UI

**Files:**
- Create: `scripts/scenes/journal_panel.gd`
- Create: `tests/test_journal_panel.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write the failing JournalPanel test**

Create `tests/test_journal_panel.gd`:

```gdscript
extends RefCounted

const JournalPanelScript = preload("res://scripts/scenes/journal_panel.gd")

func run(assertions) -> void:
	var panel = JournalPanelScript.new()
	panel._ready()

	var toggled: Array[String] = []
	panel.quest_tracking_toggled.connect(func(quest_id: String): toggled.append(quest_id))

	panel.open({
		"tasks": [
			{"id": "quest_mountain_trial", "title": "山道试剑", "status_text": "进行中", "tracked": true},
			{"id": "quest_deliver_letter", "title": "送信到客栈", "status_text": "已完成", "tracked": false}
		],
		"active_rumors": [
			{"id": "rumor_road_red_thread", "title": "官道红线车辙", "source": "赶路书生", "text": "官道车辙中夹着红线。"}
		],
		"triggered_rumors": [
			{"id": "rumor_old", "title": "旧传闻", "source": "青衫客", "text": "旧传闻已触发任务。"}
		]
	})

	assertions.assert_true(panel.visible, "打开江湖记事页面后应可见")
	assertions.assert_eq(panel.title_label.text, "江湖记事", "页面标题应正确")
	assertions.assert_eq(panel.task_list.get_child_count(), 2, "任务列表应显示任务条目")
	assertions.assert_eq(panel.active_rumor_list.get_child_count(), 1, "可追查传闻列表应显示传闻")
	assertions.assert_eq(panel.triggered_rumor_list.get_child_count(), 1, "已触发传闻列表应显示传闻")

	var first_task_row = panel.task_list.get_child(0)
	var first_checkbox = first_task_row.get_child(0)
	assertions.assert_true(first_checkbox.button_pressed, "已追踪任务的勾选框应选中")

	var second_task_row = panel.task_list.get_child(1)
	var second_checkbox = second_task_row.get_child(0)
	second_checkbox.pressed.emit()
	assertions.assert_eq(toggled.size(), 1, "点击追踪勾选应发出任务编号")
	assertions.assert_eq(toggled[0], "quest_deliver_letter", "追踪信号应携带任务编号")

	panel.show_message("最多只能追踪 3 个任务。")
	assertions.assert_eq(panel.message_label.text, "最多只能追踪 3 个任务。", "页面应显示操作提示")

	panel.close()
	assertions.assert_true(not panel.visible, "关闭江湖记事页面后应隐藏")

	panel.free()
```

In `tests/run_tests.gd`, add:

```gdscript
const TestJournalPanelScript = preload("res://tests/test_journal_panel.gd")
```

Add the suite after `TestHudInventoryScript.new()`:

```gdscript
TestJournalPanelScript.new(),
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL during preload because `journal_panel.gd` does not exist.

- [ ] **Step 3: Implement JournalPanel**

Create `scripts/scenes/journal_panel.gd`:

```gdscript
extends CanvasLayer

signal closed
signal quest_tracking_toggled(quest_id: String)

var panel: Panel
var title_label: Label
var task_list: VBoxContainer
var active_rumor_list: VBoxContainer
var triggered_rumor_list: VBoxContainer
var message_label: Label

func _ready() -> void:
	panel = Panel.new()
	panel.position = Vector2(120, 64)
	panel.size = Vector2(1040, 592)
	add_child(panel)

	title_label = Label.new()
	title_label.text = "江湖记事"
	title_label.position = Vector2(24, 16)
	title_label.size = Vector2(220, 32)
	panel.add_child(title_label)

	var close_button = Button.new()
	close_button.text = "关闭"
	close_button.position = Vector2(944, 14)
	close_button.size = Vector2(72, 36)
	close_button.pressed.connect(close)
	panel.add_child(close_button)

	var task_title = Label.new()
	task_title.text = "任务"
	task_title.position = Vector2(24, 64)
	task_title.size = Vector2(160, 28)
	panel.add_child(task_title)

	var task_scroll = ScrollContainer.new()
	task_scroll.position = Vector2(24, 96)
	task_scroll.size = Vector2(420, 420)
	panel.add_child(task_scroll)

	task_list = VBoxContainer.new()
	task_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_scroll.add_child(task_list)

	var active_title = Label.new()
	active_title.text = "可追查传闻"
	active_title.position = Vector2(480, 64)
	active_title.size = Vector2(220, 28)
	panel.add_child(active_title)

	var active_scroll = ScrollContainer.new()
	active_scroll.position = Vector2(480, 96)
	active_scroll.size = Vector2(520, 198)
	panel.add_child(active_scroll)

	active_rumor_list = VBoxContainer.new()
	active_rumor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_scroll.add_child(active_rumor_list)

	var triggered_title = Label.new()
	triggered_title.text = "已触发传闻"
	triggered_title.position = Vector2(480, 316)
	triggered_title.size = Vector2(220, 28)
	panel.add_child(triggered_title)

	var triggered_scroll = ScrollContainer.new()
	triggered_scroll.position = Vector2(480, 348)
	triggered_scroll.size = Vector2(520, 168)
	panel.add_child(triggered_scroll)

	triggered_rumor_list = VBoxContainer.new()
	triggered_rumor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	triggered_scroll.add_child(triggered_rumor_list)

	message_label = Label.new()
	message_label.position = Vector2(24, 536)
	message_label.size = Vector2(800, 32)
	panel.add_child(message_label)

	hide()

func open(view_model: Dictionary) -> void:
	_refresh_tasks(view_model.get("tasks", []))
	_refresh_rumors(active_rumor_list, view_model.get("active_rumors", []), "暂无可追查传闻。")
	_refresh_rumors(triggered_rumor_list, view_model.get("triggered_rumors", []), "暂无已触发传闻。")
	show_message("")
	show()

func close() -> void:
	hide()
	closed.emit()

func show_message(text: String) -> void:
	message_label.text = text

func _refresh_tasks(tasks: Array) -> void:
	_clear_children(task_list)
	if tasks.is_empty():
		var empty = Label.new()
		empty.text = "暂无任务。"
		task_list.add_child(empty)
		return
	for task in tasks:
		if typeof(task) != TYPE_DICTIONARY:
			continue
		_add_task_row(task)

func _add_task_row(task: Dictionary) -> void:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(390, 44)
	task_list.add_child(row)

	var checkbox = CheckBox.new()
	checkbox.button_pressed = bool(task.get("tracked", false))
	var quest_id = str(task.get("id", ""))
	checkbox.pressed.connect(func(): quest_tracking_toggled.emit(quest_id))
	row.add_child(checkbox)

	var label = Label.new()
	label.text = "%s：%s" % [str(task.get("title", "未知任务")), str(task.get("status_text", ""))]
	label.custom_minimum_size = Vector2(320, 36)
	row.add_child(label)

func _refresh_rumors(container: VBoxContainer, rumors: Array, empty_text: String) -> void:
	_clear_children(container)
	if rumors.is_empty():
		var empty = Label.new()
		empty.text = empty_text
		container.add_child(empty)
		return
	for rumor in rumors:
		if typeof(rumor) != TYPE_DICTIONARY:
			continue
		_add_rumor_row(container, rumor)

func _add_rumor_row(container: VBoxContainer, rumor: Dictionary) -> void:
	var row = VBoxContainer.new()
	row.custom_minimum_size = Vector2(480, 92)
	container.add_child(row)

	var title = Label.new()
	var source = str(rumor.get("source", ""))
	title.text = "%s%s" % [str(rumor.get("title", "未知传闻")), " · %s" % source if not source.is_empty() else ""]
	title.custom_minimum_size = Vector2(480, 24)
	row.add_child(title)

	var text = Label.new()
	text.text = str(rumor.get("text", ""))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(480, 58)
	row.add_child(text)

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
```

- [ ] **Step 4: Run the focused test and verify it passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS for `JournalPanel` assertions.

- [ ] **Step 5: Commit**

```powershell
git add scripts/scenes/journal_panel.gd tests/test_journal_panel.gd tests/run_tests.gd
git commit -m "feat: 添加江湖记事页面"
```

---

### Task 8: MapScreen Journal Integration and Input

**Files:**
- Modify: `scripts/scenes/map_screen_base.gd`
- Modify: `project.godot`
- Create: `tests/test_journal_map_screen.gd`
- Modify: `tests/test_pickup_map_screen.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write failing map screen integration test**

Create `tests/test_journal_map_screen.gd`:

```gdscript
extends RefCounted

const HudScript = preload("res://scripts/scenes/hud.gd")
const JournalPanelScript = preload("res://scripts/scenes/journal_panel.gd")
const MapScreenBaseScript = preload("res://scripts/scenes/map_screen_base.gd")

func run(assertions) -> void:
	var root = Engine.get_main_loop().root
	var repository = root.get_node("DataRepository")
	var game_state = root.get_node("GameState")
	repository.load_all()
	game_state.start_new_game()
	game_state.quest_system.start_quest("quest_mountain_trial")
	game_state.quest_system.set_status("quest_deliver_letter", "completed")

	var screen = MapScreenBaseScript.new()
	screen.map_id = "road_outskirts"
	screen.hud = HudScript.new()
	screen.hud._ready()
	screen.journal_panel = JournalPanelScript.new()
	screen.journal_panel._ready()

	screen._refresh_tracked_tasks()
	assertions.assert_eq(screen.hud.tracked_task_list.get_child_count(), 0, "没有追踪任务时 HUD 追踪区应为空")

	screen._toggle_tracked_quest("quest_mountain_trial")
	assertions.assert_eq(game_state.journal_state.tracked_quest_ids.size(), 1, "地图场景应能切换任务追踪")
	assertions.assert_eq(screen.hud.tracked_task_list.get_child_count(), 1, "切换追踪后 HUD 应刷新")

	screen._open_journal()
	assertions.assert_true(screen.journal_panel.visible, "打开江湖记事后页面应可见")
	assertions.assert_true(screen.journal_is_open, "地图场景应记录记事页面打开状态")
	screen._close_journal()
	assertions.assert_true(not screen.journal_panel.visible, "关闭江湖记事后页面应隐藏")
	assertions.assert_true(not screen.journal_is_open, "地图场景应记录记事页面关闭状态")

	screen._record_dialogue_rumor({
		"id": "road_scholar_rumor",
		"rumor": {
			"id": "rumor_road_red_thread",
			"title": "官道红线车辙",
			"text": "官道车辙中夹着红线。",
			"source": "赶路书生",
			"related_quest_id": "quest_trace_red_thread"
		}
	})
	assertions.assert_true(game_state.journal_state.active_rumors.has("rumor_road_red_thread"), "对白传闻应自动写入江湖记事")
	assertions.assert_eq(screen.hud.message_label.text, "传闻已记入江湖记事。", "记录新传闻后 HUD 应显示提示")

	screen._record_dialogue_rumor({
		"id": "road_scholar_rumor",
		"rumor": {
			"id": "rumor_road_red_thread",
			"title": "官道红线车辙",
			"text": "重复传闻。",
			"source": "赶路书生"
		}
	})
	assertions.assert_eq(game_state.journal_state.active_rumors.size(), 1, "重复对白传闻不应重复写入")

	screen.free()
```

In `tests/run_tests.gd`, add:

```gdscript
const TestJournalMapScreenScript = preload("res://tests/test_journal_map_screen.gd")
```

Add the suite after `TestPickupMapScreenScript.new()`:

```gdscript
TestJournalMapScreenScript.new(),
```

- [ ] **Step 2: Update existing pickup map test expectations**

In `tests/test_pickup_map_screen.gd`, after `screen.hud = HudScript.new()` and `screen.hud._ready()`, add:

```gdscript
	screen.journal_panel = null
```

This keeps the existing test focused on pickup and branch option effects without constructing the full journal page.

- [ ] **Step 3: Run the focused test and verify it fails**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `MapScreenBase` has no journal fields or methods.

- [ ] **Step 4: Add journal input action**

In `project.godot`, add this block after the existing `inventory` input block:

```ini
journal={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":74,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
```

- [ ] **Step 5: Implement MapScreenBase journal wiring**

In `scripts/scenes/map_screen_base.gd`, add preloads:

```gdscript
const JournalSystemScript = preload("res://scripts/systems/journal_system.gd")
const JournalPanelScript = preload("res://scripts/scenes/journal_panel.gd")
```

Add properties after `var event_system = EventSystemScript.new()`:

```gdscript
var journal_system = JournalSystemScript.new()
var journal_panel
var journal_is_open := false
var active_dialogue_state: Dictionary = {}
```

In `_create_ui()`, after HUD signal connections, add:

```gdscript
	hud.journal_requested.connect(_open_journal)
```

After adding `dialogue_box`, connect closed signal and create the journal panel:

```gdscript
	if dialogue_box.has_signal("closed"):
		dialogue_box.closed.connect(_on_dialogue_closed)
	journal_panel = JournalPanelScript.new()
	journal_panel.quest_tracking_toggled.connect(_toggle_tracked_quest)
	journal_panel.closed.connect(_on_journal_closed)
	add_child(journal_panel)
	_refresh_tracked_tasks()
```

Change `_unhandled_input(event)` to:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		if journal_is_open:
			_close_journal()
		else:
			_open_journal()
		return
	if journal_is_open:
		return
	if event.is_action_pressed("inventory"):
		_toggle_inventory()
	elif event.is_action_pressed("cancel"):
		var game_state = _get_game_state()
		var success = game_state != null and game_state.save_to_path("user://save_01.json")
		hud.show_message("存档成功。" if success else "存档失败。")
```

In `_open_dialogue()`, after `dialogue_state` fallback handling and before opening the dialogue box, add:

```gdscript
	active_dialogue_state = dialogue_state.duplicate(true)
```

Add these methods after `_on_dialogue_option_selected()`:

```gdscript
func _on_dialogue_closed() -> void:
	_record_dialogue_rumor(active_dialogue_state)
	active_dialogue_state = {}

func _record_dialogue_rumor(dialogue_state: Dictionary) -> void:
	var rumor = dialogue_state.get("rumor", {})
	if typeof(rumor) != TYPE_DICTIONARY or rumor.is_empty():
		return
	var game_state = _get_game_state()
	if game_state == null:
		return
	var result = journal_system.add_rumor(game_state.journal_state, rumor, {"map_id": map_id})
	if bool(result.get("success", false)) and not bool(result.get("duplicate", false)):
		hud.show_message(str(result.get("message", "传闻已记入江湖记事。")))

func _open_journal() -> void:
	if journal_panel == null:
		return
	journal_is_open = true
	journal_panel.open(_build_journal_view_model())

func _close_journal() -> void:
	if journal_panel == null:
		return
	journal_is_open = false
	journal_panel.close()

func _on_journal_closed() -> void:
	journal_is_open = false

func _toggle_tracked_quest(quest_id: String) -> void:
	var game_state = _get_game_state()
	if game_state == null:
		return
	var result = journal_system.toggle_tracked_quest(game_state.journal_state, quest_id)
	if journal_panel != null:
		journal_panel.show_message(str(result.get("message", "")))
		journal_panel.open(_build_journal_view_model())
	if hud != null and not bool(result.get("success", false)):
		hud.show_message(str(result.get("message", "任务追踪失败。")))
	_refresh_tracked_tasks()

func _build_journal_view_model() -> Dictionary:
	var game_state = _get_game_state()
	var data_repository = _get_data_repository()
	if game_state == null:
		return {"tasks": [], "active_rumors": [], "triggered_rumors": []}
	var rumors = journal_system.build_rumor_entries(game_state.journal_state)
	return {
		"tasks": journal_system.build_task_entries(game_state, data_repository),
		"active_rumors": rumors.get("active", []),
		"triggered_rumors": rumors.get("triggered", []),
	}

func _refresh_tracked_tasks() -> void:
	if hud == null:
		return
	var game_state = _get_game_state()
	var data_repository = _get_data_repository()
	if game_state == null:
		hud.set_tracked_tasks([])
		return
	hud.set_tracked_tasks(journal_system.build_tracked_task_entries(game_state, data_repository))
```

In `_apply_quest_complete_effects()`, after `var effects = _quest_complete_effects(quest_id, quest)`, store and process result:

```gdscript
	var result = effect_system.apply_effects(game_state, effects, {"source": "quest_complete", "quest_id": quest_id})
	if game_state.journal_state != null:
		journal_system.mark_rumors_triggered_for_quest(game_state.journal_state, quest_id)
	_refresh_tracked_tasks()
	return result
```

Replace the old single-line return in that method:

```gdscript
	return effect_system.apply_effects(game_state, effects, {"source": "quest_complete", "quest_id": quest_id})
```

with the block above.

In `_on_dialogue_option_selected()`, after `_update_quest_text()`, add:

```gdscript
	_refresh_tracked_tasks()
```

In `_claim_pickup()`, after `_refresh_shop_if_open()`, add:

```gdscript
		_refresh_tracked_tasks()
```

- [ ] **Step 6: Run the focused test and verify it passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS for map screen journal integration assertions and existing pickup assertions.

- [ ] **Step 7: Commit**

```powershell
git add scripts/scenes/map_screen_base.gd project.godot tests/test_journal_map_screen.gd tests/test_pickup_map_screen.gd tests/run_tests.gd
git commit -m "feat: 接入江湖记事地图入口"
```

---

### Task 9: Documentation and Full Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/godot-project-structure.md`

- [ ] **Step 1: Update README**

In `README.md`, add this bullet after the “剧情事件与分支对话基础切片” bullet:

```markdown
- 江湖记事基础切片：任务列表、最多 3 个任务 HUD 追踪、可追查传闻、已触发传闻、对白自动记录传闻和存档恢复。
```

- [ ] **Step 2: Update project structure docs**

In `docs/godot-project-structure.md`, add this section after “剧情事件与分支对话基础切片”:

```markdown
## 江湖记事基础切片

江湖记事切片使用 `JournalState` 保存追踪任务、可追查传闻和已触发传闻，使用 `JournalSystem` 统一处理传闻记录、传闻归档和任务追踪上限。地图中按 `J` 或点击 HUD“记事”按钮打开独立页面。HUD 只显示最多 3 个追踪任务，记事页面负责展示任务列表和传闻列表，不直接修改任务、传闻或存档状态。
```

- [ ] **Step 3: Run full test suite**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：28 个测试套件
```

- [ ] **Step 4: Verify scenes load headlessly**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
```

Expected: exit code 0 with no fatal scene preload errors.

- [ ] **Step 5: Inspect git diff**

Run:

```powershell
git diff --stat
git diff --check
```

Expected: `git diff --stat` lists only the files changed in this implementation, and `git diff --check` produces no output.

- [ ] **Step 6: Commit docs and final wiring**

```powershell
git add README.md docs/godot-project-structure.md
git commit -m "docs: 记录江湖记事切片"
```

---

## Manual Acceptance Checklist

- [ ] 新开或继续游戏，完成“送信到客栈”。
- [ ] 进入村外官道。
- [ ] 与 `赶路书生` 对话并选择“询问路上异动”。
- [ ] 播放“车辙传闻”后看到“传闻已记入江湖记事。”提示。
- [ ] 按 `J` 打开“江湖记事”。
- [ ] 确认可追查传闻中显示“官道红线车辙”。
- [ ] 在任务列表勾选 3 个以内任务。
- [ ] 确认 HUD 显示追踪任务。
- [ ] 尝试勾选第 4 个任务，确认中文提示且追踪列表不变。
- [ ] 触发相关任务后，确认传闻移动到“已触发传闻”。
- [ ] 存档，回主菜单，继续游戏。
- [ ] 确认追踪任务和传闻状态保持。

## Self-Review

- Spec coverage: Tasks 1-3 cover `JournalState`、`JournalSystem` and persistence. Task 4 covers `add_rumor` and `trigger_rumor`. Task 5 covers dialogue data and automatic rumor metadata. Tasks 6-8 cover HUD, journal panel, `J` input, map integration, task tracking, and automatic rumor recording. Task 9 covers docs and full verification.
- Placeholder scan: Checked for forbidden placeholder markers, missing code snippets, and references to undefined planned symbols; none remain.
- Type consistency: `journal_state`, `JournalSystem.add_rumor()`, `trigger_rumor()`, `toggle_tracked_quest()`, `build_task_entries()`, `build_tracked_task_entries()`, `build_rumor_entries()`, `journal_requested`, and `quest_tracking_toggled` use consistent names across tasks.
