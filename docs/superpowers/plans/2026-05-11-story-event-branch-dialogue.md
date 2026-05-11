# 剧情事件与分支对话基础切片 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立轻量条件判断、事件执行和分支对话管线，并用村外官道 `赶路书生` 验证对话选择、条件 gating、效果执行和存档恢复。

**Architecture:** 新增 `ConditionSystem` 判断内容条件，新增 `EventSystem` 在条件满足后委托 `EffectSystem` 执行效果。`DialogueSystem` 负责读取和标注分支选项，`DialogueBox` 负责展示选项并发出选择信号，`MapScreenBase` 负责把玩家选择交给事件系统并刷新 UI。

**Tech Stack:** Godot 4.6, GDScript, JSON 内容数据, project-local headless Godot test runner, PowerShell.

---

## Scope Check

本计划实现 [docs/superpowers/specs/2026-05-11-story-event-branch-dialogue-design.md](../specs/2026-05-11-story-event-branch-dialogue-design.md)。

范围包含：

- 条件判断：任务状态、flag、背包物品、地图对象状态、单条件 `not`。
- 事件执行：条件满足后执行 `effects`，条件失败时不执行。
- 效果扩展：`remove_item`。
- 对话选项：读取、可用性标注、UI 显示、选择后执行事件、跳转后续对白。
- 示例内容：村外官道 `赶路书生`。
- 自动测试、文档和最终验证。

范围不包含：

- 不新增 `data/events.json`。
- 不做 OR 条件、表达式语言或任意脚本调用。
- 不做完整剧情编辑器。
- 不重写全部历史对白。
- 不新增大地图、室内地图或新战斗敌人。

---

## File Structure

```text
data/dialogues.json                              # Add road scholar branch dialogue records and options
data/maps.json                                   # Add road scholar NPC to road_outskirts
docs/godot-project-structure.md                 # Document story event and branch dialogue slice
README.md                                       # Update current project capabilities
scripts/scenes/dialogue_box.gd                  # Display dialogue options and emit option_selected
scripts/scenes/map_screen_base.gd               # Wire branch dialogue selections into EventSystem
scripts/scenes/road_outskirts_screen.gd         # Route npc interaction through shared dialogue flow
scripts/systems/condition_system.gd             # New condition evaluator
scripts/systems/dialogue_system.gd              # Return dialogue records, options, and availability state
scripts/systems/effect_system.gd                # Add remove_item effect and removed_items result field
scripts/systems/event_system.gd                 # New condition-gated effect executor
tests/run_tests.gd                              # Register new test suites
tests/test_condition_system.gd                  # ConditionSystem coverage
tests/test_dialogue_box_options.gd              # DialogueBox option UI coverage
tests/test_dialogue_options.gd                  # DialogueSystem branch option coverage
tests/test_event_system.gd                      # EventSystem coverage
tests/test_story_event_data.gd                  # Road scholar content and save persistence coverage
tests/test_effect_system.gd                     # Extend existing effect coverage for remove_item
tests/test_pickup_map_screen.gd                 # Extend map screen coverage for branch option execution
```

---

### Task 1: ConditionSystem Core

**Files:**
- Create: `scripts/systems/condition_system.gd`
- Create: `tests/test_condition_system.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write failing ConditionSystem tests**

Create `tests/test_condition_system.gd`:

```gdscript
extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const ConditionSystemScript = preload("res://scripts/systems/condition_system.gd")

func run(assertions) -> void:
	var state = GameStateScript.new()
	state.start_new_game()
	var condition_system = ConditionSystemScript.new()

	state.quest_system.set_status("quest_deliver_letter", "completed")
	state.set_flag("clue_road_unrest", true)
	state.party.add_item("herb_small", 2)
	state.resolve_map_object("pickup_roadside_bundle")

	var result = condition_system.are_conditions_met(state, [
		{"type": "quest_status", "quest_id": "quest_deliver_letter", "status": "completed"},
		{"type": "flag_equals", "key": "clue_road_unrest", "value": true},
		{"type": "has_item", "item_id": "herb_small", "amount": 2},
		{"type": "map_object_resolved", "object_id": "pickup_roadside_bundle"},
		{"type": "not", "condition": {"type": "flag_equals", "key": "missing_flag", "value": true}}
	])
	assertions.assert_true(bool(result.get("success", false)), "合法条件判断应成功")
	assertions.assert_true(bool(result.get("met", false)), "全部条件满足时应返回 met")
	assertions.assert_eq(int(result.get("failed_conditions", -1)), 0, "满足条件时失败条件数量应为 0")

	var missing_item = condition_system.are_conditions_met(state, [
		{"type": "has_item", "item_id": "herb_small", "amount": 3}
	])
	assertions.assert_true(bool(missing_item.get("success", false)), "未满足条件不是结构错误")
	assertions.assert_true(not bool(missing_item.get("met", true)), "物品数量不足时条件不满足")
	assertions.assert_eq(int(missing_item.get("failed_conditions", 0)), 1, "物品数量不足应记录失败条件")
	assertions.assert_eq(missing_item.get("messages", [])[0], "缺少物品：herb_small x3", "物品条件失败应返回中文原因")

	var wrong_status = condition_system.is_condition_met(state, {
		"type": "quest_status",
		"quest_id": "quest_deliver_letter",
		"status": "active"
	})
	assertions.assert_true(bool(wrong_status.get("success", false)), "任务状态不匹配不是结构错误")
	assertions.assert_true(not bool(wrong_status.get("met", true)), "任务状态不匹配时条件不满足")

	var bad_list = condition_system.are_conditions_met(state, {"type": "has_item"})
	assertions.assert_true(not bool(bad_list.get("success", true)), "非数组条件列表应失败")
	assertions.assert_eq(bad_list.get("errors", [])[0], "条件列表格式错误。", "非数组条件列表应返回中文错误")

	var unknown = condition_system.is_condition_met(state, {"type": "missing_condition"})
	assertions.assert_true(not bool(unknown.get("success", true)), "未知条件类型应失败")
	assertions.assert_eq(unknown.get("errors", [])[0], "未知条件类型：missing_condition", "未知条件类型应返回中文错误")

	var invalid_not = condition_system.is_condition_met(state, {"type": "not", "condition": []})
	assertions.assert_true(not bool(invalid_not.get("success", true)), "not 条件缺少子条件时应失败")

	state.free()
```

Modify `tests/run_tests.gd`:

```gdscript
const TestConditionSystemScript = preload("res://tests/test_condition_system.gd")
```

Add the suite after `TestEffectDataScript.new()`:

```gdscript
		TestConditionSystemScript.new(),
```

- [ ] **Step 2: Run tests and verify the new suite fails**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `res://scripts/systems/condition_system.gd` does not exist.

- [ ] **Step 3: Implement ConditionSystem**

Create `scripts/systems/condition_system.gd`:

```gdscript
extends RefCounted

func are_conditions_met(game_state, conditions: Variant, context: Dictionary = {}) -> Dictionary:
	var result = _empty_result()
	if game_state == null:
		_add_error(result, "游戏状态缺失。")
		return result
	if typeof(conditions) != TYPE_ARRAY:
		_add_error(result, "条件列表格式错误。")
		return result

	for condition in conditions:
		var condition_result = is_condition_met(game_state, condition, context)
		_merge_result(result, condition_result)

	result["success"] = result.get("errors", []).is_empty()
	result["met"] = bool(result.get("success", false)) and int(result.get("failed_conditions", 0)) == 0
	return result

func is_condition_met(game_state, condition: Variant, context: Dictionary = {}) -> Dictionary:
	var result = _empty_result()
	if game_state == null:
		_add_error(result, "游戏状态缺失。")
		return result
	if typeof(condition) != TYPE_DICTIONARY:
		_add_error(result, "条件格式错误。")
		return result

	var condition_type = str(condition.get("type", ""))
	if condition_type.is_empty():
		_add_error(result, "条件缺少类型。")
		return result

	match condition_type:
		"quest_status":
			_check_quest_status(result, game_state, condition)
		"flag_equals":
			_check_flag_equals(result, game_state, condition)
		"has_item":
			_check_has_item(result, game_state, condition)
		"map_object_resolved":
			_check_map_object_resolved(result, game_state, condition)
		"not":
			_check_not(result, game_state, condition, context)
		_:
			_add_error(result, "未知条件类型：%s" % condition_type)

	result["success"] = result.get("errors", []).is_empty()
	return result

func _check_quest_status(result: Dictionary, game_state, condition: Dictionary) -> void:
	var quest_id = str(condition.get("quest_id", ""))
	var status = str(condition.get("status", ""))
	if quest_id.is_empty():
		_add_error(result, "任务条件缺少任务编号。")
		return
	if status.is_empty():
		_add_error(result, "任务条件缺少状态。")
		return
	if game_state.quest_system == null:
		_add_error(result, "任务系统缺失。")
		return
	if game_state.quest_system.get_status(quest_id) != status:
		_mark_unmet(result, "任务状态不满足：%s" % quest_id)

func _check_flag_equals(result: Dictionary, game_state, condition: Dictionary) -> void:
	var key = str(condition.get("key", ""))
	if key.is_empty():
		_add_error(result, "flag 条件缺少 key。")
		return
	var expected = condition.get("value", true)
	if game_state.flags.get(key, null) != expected:
		_mark_unmet(result, "线索条件不满足：%s" % key)

func _check_has_item(result: Dictionary, game_state, condition: Dictionary) -> void:
	var item_id = str(condition.get("item_id", ""))
	var amount = int(condition.get("amount", 1))
	if item_id.is_empty():
		_add_error(result, "物品条件缺少物品编号。")
		return
	if amount <= 0:
		_add_error(result, "物品条件数量必须大于 0。")
		return
	if game_state.party == null:
		_add_error(result, "队伍状态缺失。")
		return
	if not game_state.party.has_item(item_id, amount):
		_mark_unmet(result, "缺少物品：%s x%d" % [item_id, amount])

func _check_map_object_resolved(result: Dictionary, game_state, condition: Dictionary) -> void:
	var object_id = str(condition.get("object_id", ""))
	if object_id.is_empty():
		_add_error(result, "地图对象条件缺少对象编号。")
		return
	if not game_state.is_map_object_resolved(object_id):
		_mark_unmet(result, "地图对象状态不满足：%s" % object_id)

func _check_not(result: Dictionary, game_state, condition: Dictionary, context: Dictionary) -> void:
	var nested = condition.get("condition", {})
	if typeof(nested) != TYPE_DICTIONARY:
		_add_error(result, "not 条件缺少子条件。")
		return
	var nested_result = is_condition_met(game_state, nested, context)
	if not bool(nested_result.get("success", false)):
		_merge_result(result, nested_result)
		return
	if bool(nested_result.get("met", false)):
		_mark_unmet(result, "反向条件不满足。")

func _empty_result() -> Dictionary:
	return {
		"success": true,
		"met": true,
		"failed_conditions": 0,
		"messages": [],
		"errors": [],
	}

func _mark_unmet(result: Dictionary, message: String) -> void:
	result["met"] = false
	result["failed_conditions"] = int(result.get("failed_conditions", 0)) + 1
	var messages: Array = result["messages"]
	messages.append(message)

func _add_error(result: Dictionary, message: String) -> void:
	result["success"] = false
	result["met"] = false
	var errors: Array = result["errors"]
	errors.append(message)

func _merge_result(target: Dictionary, source: Dictionary) -> void:
	if not bool(source.get("success", false)):
		target["success"] = false
	if not bool(source.get("met", false)):
		target["met"] = false
	target["failed_conditions"] = int(target.get("failed_conditions", 0)) + int(source.get("failed_conditions", 0))
	for key in ["messages", "errors"]:
		var target_values: Array = target[key]
		for value in source.get(key, []):
			target_values.append(value)
```

- [ ] **Step 4: Run tests and verify Task 1 passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with `测试通过：20 个测试套件`.

- [ ] **Step 5: Commit Task 1**

```powershell
git add scripts/systems/condition_system.gd tests/test_condition_system.gd tests/run_tests.gd
git commit -m "feat: add condition system"
```

---

### Task 2: Remove Item Effect

**Files:**
- Modify: `scripts/systems/effect_system.gd`
- Modify: `tests/test_effect_system.gd`

- [ ] **Step 1: Extend failing EffectSystem test**

In `tests/test_effect_system.gd`, after the current `result` assertions for `add_item` and `add_coins`, add:

```gdscript
	var remove_result = effect_system.apply_effects(state, [
		{"type": "remove_item", "item_id": "herb_small", "amount": 1}
	])
	assertions.assert_true(bool(remove_result.get("success", false)), "remove_item 应成功扣除已有物品")
	assertions.assert_eq(state.party.get_item_count("herb_small"), initial_herbs + 1, "remove_item 应扣除指定数量")
	assertions.assert_eq(remove_result.get("removed_items", [])[0].get("id", ""), "herb_small", "结果应记录扣除物品编号")
	assertions.assert_eq(remove_result.get("removed_items", [])[0].get("amount", 0), 1, "结果应记录扣除物品数量")

	var missing_remove = effect_system.apply_effects(state, [
		{"type": "remove_item", "item_id": "herb_small", "amount": 99}
	])
	assertions.assert_true(not bool(missing_remove.get("success", true)), "remove_item 物品不足时应失败")
	assertions.assert_eq(missing_remove.get("errors", [])[0], "背包中没有足够物品：herb_small x99", "remove_item 物品不足应返回中文错误")
```

- [ ] **Step 2: Run tests and verify remove_item fails**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL with unknown effect type `remove_item` or missing `removed_items`.

- [ ] **Step 3: Implement remove_item**

In `scripts/systems/effect_system.gd`, add this match arm inside `apply_effect()`:

```gdscript
		"remove_item":
			_apply_remove_item(result, game_state, effect)
```

Add this method after `_apply_add_item()`:

```gdscript
func _apply_remove_item(result: Dictionary, game_state, effect: Dictionary) -> void:
	var item_id = str(effect.get("item_id", ""))
	var amount = int(effect.get("amount", 1))
	if item_id.is_empty():
		_add_error(result, "扣除物品效果缺少物品编号。")
		return
	if amount <= 0:
		_add_error(result, "扣除物品效果数量必须大于 0。")
		return
	if game_state.party == null:
		_add_error(result, "队伍状态缺失。")
		return
	if not game_state.party.remove_item(item_id, amount):
		_add_error(result, "背包中没有足够物品：%s x%d" % [item_id, amount])
		return
	var removed_items: Array = result["removed_items"]
	removed_items.append({"id": item_id, "amount": amount})
	_mark_applied(result, "失去物品：%s x%d" % [item_id, amount])
```

In `_empty_result()`, add:

```gdscript
		"removed_items": [],
```

In `_merge_result()`, include `removed_items`:

```gdscript
	for key in ["messages", "errors", "items", "removed_items", "flags", "quests", "resolved_objects", "martial_proficiency"]:
```

- [ ] **Step 4: Run tests and verify Task 2 passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with `测试通过：20 个测试套件`.

- [ ] **Step 5: Commit Task 2**

```powershell
git add scripts/systems/effect_system.gd tests/test_effect_system.gd
git commit -m "feat: add remove item effect"
```

---

### Task 3: EventSystem Core

**Files:**
- Create: `scripts/systems/event_system.gd`
- Create: `tests/test_event_system.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write failing EventSystem tests**

Create `tests/test_event_system.gd`:

```gdscript
extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const EventSystemScript = preload("res://scripts/systems/event_system.gd")

func run(assertions) -> void:
	var state = GameStateScript.new()
	state.start_new_game()
	var event_system = EventSystemScript.new()

	var blocked = event_system.apply_event(state, {
		"conditions": [
			{"type": "has_item", "item_id": "herb_small", "amount": 2}
		],
		"effects": [
			{"type": "add_coins", "amount": 30}
		]
	})
	assertions.assert_true(not bool(blocked.get("success", true)), "条件不满足时事件应失败")
	assertions.assert_true(not bool(blocked.get("conditions_met", true)), "条件不满足时应记录 conditions_met=false")
	assertions.assert_eq(state.party.coins, 80, "条件不满足时不应执行效果")
	assertions.assert_eq(blocked.get("messages", [])[0], "缺少物品：herb_small x2", "事件应透传条件失败原因")

	var applied = event_system.apply_event(state, {
		"conditions": [
			{"type": "has_item", "item_id": "herb_small", "amount": 1}
		],
		"effects": [
			{"type": "remove_item", "item_id": "herb_small", "amount": 1},
			{"type": "add_coins", "amount": 30},
			{"type": "set_flag", "key": "helped_road_scholar", "value": true}
		]
	})
	assertions.assert_true(bool(applied.get("success", false)), "条件满足时事件应成功")
	assertions.assert_true(bool(applied.get("conditions_met", false)), "条件满足时应记录 conditions_met=true")
	assertions.assert_eq(state.party.get_item_count("herb_small"), 0, "事件效果应扣除小还丹")
	assertions.assert_eq(state.party.coins, 110, "事件效果应增加铜钱")
	assertions.assert_eq(state.flags.get("helped_road_scholar", false), true, "事件效果应写入 flag")
	assertions.assert_eq(int(applied.get("applied", 0)), 3, "事件应记录执行效果数量")

	var empty_event = event_system.apply_event(state, {"conditions": [], "effects": []})
	assertions.assert_true(bool(empty_event.get("success", false)), "空效果事件应允许作为纯对话跳转")
	assertions.assert_eq(int(empty_event.get("applied", -1)), 0, "空效果事件执行数量应为 0")

	var bad_event = event_system.apply_event(state, [])
	assertions.assert_true(not bool(bad_event.get("success", true)), "非字典事件应失败")
	assertions.assert_eq(bad_event.get("errors", [])[0], "事件格式错误。", "非字典事件应返回中文错误")

	state.free()
```

Modify `tests/run_tests.gd`:

```gdscript
const TestEventSystemScript = preload("res://tests/test_event_system.gd")
```

Add the suite after `TestConditionSystemScript.new()`:

```gdscript
		TestEventSystemScript.new(),
```

- [ ] **Step 2: Run tests and verify EventSystem fails**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `res://scripts/systems/event_system.gd` does not exist.

- [ ] **Step 3: Implement EventSystem**

Create `scripts/systems/event_system.gd`:

```gdscript
extends RefCounted

const ConditionSystemScript = preload("res://scripts/systems/condition_system.gd")
const EffectSystemScript = preload("res://scripts/systems/effect_system.gd")

var condition_system = ConditionSystemScript.new()
var effect_system = EffectSystemScript.new()

func apply_event(game_state, event_data: Variant, context: Dictionary = {}) -> Dictionary:
	var result = _empty_result()
	if game_state == null:
		_add_error(result, "游戏状态缺失。")
		return result
	if typeof(event_data) != TYPE_DICTIONARY:
		_add_error(result, "事件格式错误。")
		return result

	var conditions = event_data.get("conditions", [])
	if typeof(conditions) != TYPE_ARRAY:
		_add_error(result, "事件条件格式错误。")
		return result

	var condition_result = condition_system.are_conditions_met(game_state, conditions, context)
	_append_messages(result, condition_result)
	if not bool(condition_result.get("success", false)):
		_add_errors(result, condition_result.get("errors", []))
		return result
	if not bool(condition_result.get("met", false)):
		result["conditions_met"] = false
		result["success"] = false
		return result

	result["conditions_met"] = true
	var effects = event_data.get("effects", [])
	if typeof(effects) != TYPE_ARRAY:
		_add_error(result, "事件效果格式错误。")
		return result
	if effects.is_empty():
		result["success"] = true
		return result

	var effect_result = effect_system.apply_effects(game_state, effects, context)
	result["effect_result"] = effect_result
	result["applied"] = int(effect_result.get("applied", 0))
	result["failed"] = int(effect_result.get("failed", 0))
	_append_messages(result, effect_result)
	_add_errors(result, effect_result.get("errors", []))
	result["success"] = bool(effect_result.get("success", false))
	return result

func _empty_result() -> Dictionary:
	return {
		"success": false,
		"conditions_met": false,
		"applied": 0,
		"failed": 0,
		"messages": [],
		"errors": [],
		"effect_result": {},
	}

func _append_messages(target: Dictionary, source: Dictionary) -> void:
	var messages: Array = target["messages"]
	for message in source.get("messages", []):
		messages.append(message)

func _add_errors(target: Dictionary, errors: Array) -> void:
	for error in errors:
		_add_error(target, str(error))

func _add_error(target: Dictionary, message: String) -> void:
	target["success"] = false
	target["failed"] = int(target.get("failed", 0)) + 1
	var errors: Array = target["errors"]
	errors.append(message)
```

- [ ] **Step 4: Run tests and verify Task 3 passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with `测试通过：21 个测试套件`.

- [ ] **Step 5: Commit Task 3**

```powershell
git add scripts/systems/event_system.gd tests/test_event_system.gd tests/run_tests.gd
git commit -m "feat: add event system"
```

---

### Task 4: DialogueSystem Options

**Files:**
- Modify: `scripts/systems/dialogue_system.gd`
- Create: `tests/test_dialogue_options.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write failing DialogueSystem option tests**

Create `tests/test_dialogue_options.gd`:

```gdscript
extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const DialogueSystemScript = preload("res://scripts/systems/dialogue_system.gd")

class StubRepository:
	extends Node
	var dialogue: Dictionary = {}
	func get_dialogue(_dialogue_id: String) -> Dictionary:
		return dialogue

func run(assertions) -> void:
	var repository = StubRepository.new()
	repository.dialogue = {
		"id": "branch_test",
		"title": "分支测试",
		"lines": [
			{"speaker": "旁白", "text": "请选择。"}
		],
		"options": [
			{
				"id": "ask",
				"text": "询问",
				"conditions": [],
				"effects": [{"type": "set_flag", "key": "asked_branch", "value": true}],
				"next_dialogue_id": "branch_after"
			},
			{
				"id": "give",
				"text": "赠药",
				"conditions": [{"type": "has_item", "item_id": "herb_small", "amount": 2}],
				"effects": [{"type": "remove_item", "item_id": "herb_small", "amount": 1}],
				"next_dialogue_id": "branch_give",
				"unavailable_text": "背包中没有小还丹。"
			}
		]
	}

	var state = GameStateScript.new()
	state.start_new_game()
	var dialogue_system = DialogueSystemScript.new()
	dialogue_system.set_repository(repository)

	var record = dialogue_system.get_dialogue("branch_test")
	assertions.assert_eq(record.get("id", ""), "branch_test", "应能返回完整对话记录")
	record["id"] = "mutated"
	assertions.assert_eq(repository.dialogue.get("id", ""), "branch_test", "返回记录应为副本")

	var options = dialogue_system.get_options("branch_test")
	assertions.assert_eq(options.size(), 2, "应能读取两个对话选项")
	assertions.assert_eq(options[0].get("text", ""), "询问", "选项文本应正确")

	var dialogue_state = dialogue_system.build_dialogue_state("branch_test", state)
	assertions.assert_eq(dialogue_state.get("title", ""), "分支测试", "对话状态应包含标题")
	assertions.assert_eq(dialogue_state.get("lines", []).size(), 1, "对话状态应包含对白行")
	assertions.assert_eq(dialogue_state.get("options", []).size(), 2, "对话状态应包含选项")
	assertions.assert_true(bool(dialogue_state.get("options", [])[0].get("available", false)), "无条件选项应可用")
	assertions.assert_true(not bool(dialogue_state.get("options", [])[1].get("available", true)), "物品不足选项应不可用")
	assertions.assert_eq(dialogue_state.get("options", [])[1].get("unavailable_reason", ""), "背包中没有小还丹。", "不可用选项应优先使用配置提示")

	state.party.add_item("herb_small", 1)
	var available_state = dialogue_system.build_dialogue_state("branch_test", state)
	assertions.assert_true(bool(available_state.get("options", [])[1].get("available", false)), "物品满足后赠药选项应可用")

	state.free()
	repository.free()
```

Modify `tests/run_tests.gd`:

```gdscript
const TestDialogueOptionsScript = preload("res://tests/test_dialogue_options.gd")
```

Add the suite after `TestQuestAndDialogueScript.new()`:

```gdscript
		TestDialogueOptionsScript.new(),
```

- [ ] **Step 2: Run tests and verify DialogueSystem options fail**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `get_dialogue()`, `get_options()`, and `build_dialogue_state()` are missing.

- [ ] **Step 3: Extend DialogueSystem**

Replace `scripts/systems/dialogue_system.gd` with:

```gdscript
extends RefCounted

const ConditionSystemScript = preload("res://scripts/systems/condition_system.gd")

var repository: Node = null
var condition_system = ConditionSystemScript.new()

func set_repository(next_repository: Node) -> void:
	repository = next_repository

func get_title(dialogue_id: String) -> String:
	var dialogue = _get_dialogue(dialogue_id)
	return str(dialogue.get("title", ""))

func get_lines(dialogue_id: String) -> Array:
	var dialogue = _get_dialogue(dialogue_id)
	return dialogue.get("lines", [])

func get_dialogue(dialogue_id: String) -> Dictionary:
	return _get_dialogue(dialogue_id).duplicate(true)

func get_options(dialogue_id: String) -> Array:
	var options = _get_dialogue(dialogue_id).get("options", [])
	if typeof(options) != TYPE_ARRAY:
		return []
	return options.duplicate(true)

func build_dialogue_state(dialogue_id: String, game_state) -> Dictionary:
	var dialogue = get_dialogue(dialogue_id)
	var lines = dialogue.get("lines", [])
	if typeof(lines) != TYPE_ARRAY:
		lines = []
	return {
		"id": str(dialogue.get("id", dialogue_id)),
		"title": str(dialogue.get("title", "")),
		"lines": lines.duplicate(true),
		"options": _build_options(dialogue, game_state),
	}

func _build_options(dialogue: Dictionary, game_state) -> Array:
	var raw_options = dialogue.get("options", [])
	if typeof(raw_options) != TYPE_ARRAY:
		return []
	var result: Array = []
	for raw_option in raw_options:
		if typeof(raw_option) != TYPE_DICTIONARY:
			continue
		var option = raw_option.duplicate(true)
		var conditions = option.get("conditions", [])
		var condition_result = {"success": true, "met": true, "messages": [], "errors": []}
		if typeof(conditions) == TYPE_ARRAY:
			condition_result = condition_system.are_conditions_met(game_state, conditions)
		else:
			condition_result = {"success": false, "met": false, "messages": [], "errors": ["选项条件格式错误。"]}
		var available = bool(condition_result.get("success", false)) and bool(condition_result.get("met", false))
		option["available"] = available
		option["condition_result"] = condition_result
		if not available:
			option["unavailable_reason"] = _unavailable_reason(option, condition_result)
		else:
			option["unavailable_reason"] = ""
		result.append(option)
	return result

func _unavailable_reason(option: Dictionary, condition_result: Dictionary) -> String:
	var configured = str(option.get("unavailable_text", ""))
	if not configured.is_empty():
		return configured
	var messages = condition_result.get("messages", [])
	if typeof(messages) == TYPE_ARRAY and not messages.is_empty():
		return str(messages[0])
	var errors = condition_result.get("errors", [])
	if typeof(errors) == TYPE_ARRAY and not errors.is_empty():
		return str(errors[0])
	return "条件尚未满足。"

func _get_dialogue(dialogue_id: String) -> Dictionary:
	if repository == null or dialogue_id.is_empty():
		return {}
	if repository.has_method("get_dialogue"):
		return repository.get_dialogue(dialogue_id)
	return {}
```

- [ ] **Step 4: Run tests and verify Task 4 passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with `测试通过：22 个测试套件`.

- [ ] **Step 5: Commit Task 4**

```powershell
git add scripts/systems/dialogue_system.gd tests/test_dialogue_options.gd tests/run_tests.gd
git commit -m "feat: add dialogue option state"
```

---

### Task 5: Dialogue UI And Map Event Wiring

**Files:**
- Modify: `scripts/scenes/dialogue_box.gd`
- Modify: `scripts/scenes/map_screen_base.gd`
- Modify: `scripts/scenes/road_outskirts_screen.gd`
- Create: `tests/test_dialogue_box_options.gd`
- Modify: `tests/test_pickup_map_screen.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write failing DialogueBox option UI tests**

Create `tests/test_dialogue_box_options.gd`:

```gdscript
extends RefCounted

const DialogueBoxScript = preload("res://scripts/scenes/dialogue_box.gd")

func run(assertions) -> void:
	var box = DialogueBoxScript.new()
	box._ready()
	var selected: Array = []
	box.option_selected.connect(func(option: Dictionary): selected.append(option))

	box.open_dialogue_state({
		"lines": [{"speaker": "赶路书生", "text": "少侠留步。"}],
		"options": [
			{"id": "ask", "text": "询问路上异动", "available": true},
			{"id": "give", "text": "赠予小还丹", "available": false, "unavailable_reason": "背包中没有小还丹。"}
		]
	})

	assertions.assert_true(box.visible, "打开分支对话后对话框应可见")
	assertions.assert_eq(box.option_container.get_child_count(), 2, "分支对话应创建两个选项按钮")
	var ask_button = box.option_container.get_child(0)
	var give_button = box.option_container.get_child(1)
	assertions.assert_eq(ask_button.text, "询问路上异动", "可用选项按钮文本应正确")
	assertions.assert_true(not ask_button.disabled, "可用选项按钮不应禁用")
	assertions.assert_true(give_button.disabled, "不可用选项按钮应禁用")
	assertions.assert_eq(give_button.tooltip_text, "背包中没有小还丹。", "不可用选项应带提示")

	ask_button.pressed.emit()
	assertions.assert_eq(selected.size(), 1, "点击可用选项应发出选择信号")
	assertions.assert_eq(selected[0].get("id", ""), "ask", "选择信号应携带选项数据")
	assertions.assert_true(not box.visible, "点击选项后对话框应关闭")

	box.open([{"speaker": "旁白", "text": "线性对白。"}])
	assertions.assert_eq(box.option_container.get_child_count(), 0, "线性对白不应残留选项按钮")

	box.free()
```

Modify `tests/run_tests.gd`:

```gdscript
const TestDialogueBoxOptionsScript = preload("res://tests/test_dialogue_box_options.gd")
```

Add the suite after `TestDialogueOptionsScript.new()`:

```gdscript
		TestDialogueBoxOptionsScript.new(),
```

- [ ] **Step 2: Extend map screen test for option execution**

Append this block before cleanup in `tests/test_pickup_map_screen.gd`:

```gdscript
	screen.dialogue_box = null
	screen.event_system.effect_system = screen.effect_system
	game_state.party.add_item("herb_small", 1)
	var before_branch_coins = game_state.party.coins
	screen._on_dialogue_option_selected({
		"id": "give_medicine",
		"text": "赠予小还丹",
		"available": true,
		"effects": [
			{"type": "remove_item", "item_id": "herb_small", "amount": 1},
			{"type": "add_coins", "amount": 30},
			{"type": "set_flag", "key": "helped_road_scholar", "value": true}
		],
		"next_dialogue_id": ""
	})
	assertions.assert_eq(game_state.party.coins, before_branch_coins + 30, "地图场景分支选项应执行事件铜钱效果")
	assertions.assert_eq(game_state.flags.get("helped_road_scholar", false), true, "地图场景分支选项应写入 flag")
	assertions.assert_eq(screen.hud.message_label.text, "获得：30 文。", "地图场景分支选项应显示效果消息")
```

- [ ] **Step 3: Run tests and verify UI/map wiring fails**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `open_dialogue_state`, `option_selected`, `option_container`, `event_system`, and `_on_dialogue_option_selected()` are missing.

- [ ] **Step 4: Extend DialogueBox**

Modify `scripts/scenes/dialogue_box.gd`:

Add signal and variables near the top:

```gdscript
signal option_selected(option: Dictionary)

var option_container: VBoxContainer
var options: Array = []
```

In `_ready()`, after creating `button`, add:

```gdscript
	option_container = VBoxContainer.new()
	option_container.position = Vector2(24, 104)
	option_container.size = Vector2(840, 48)
	panel.add_child(option_container)
```

Replace `open()` with:

```gdscript
func open(next_lines: Array) -> void:
	open_dialogue_state({"lines": next_lines, "options": []})
```

Add:

```gdscript
func open_dialogue_state(dialogue_state: Dictionary) -> void:
	lines = dialogue_state.get("lines", [])
	options = dialogue_state.get("options", [])
	index = 0
	if lines.is_empty():
		lines = [{"speaker": "旁白", "text": "此人暂时无话可说。"}]
	if typeof(options) != TYPE_ARRAY:
		options = []
	_clear_options()
	_show_line()
	show()
```

Replace `_show_line()` with:

```gdscript
func _show_line() -> void:
	var line = lines[index]
	speaker_label.text = str(line.get("speaker", ""))
	text_label.text = str(line.get("text", ""))
	if index >= lines.size() - 1 and not options.is_empty():
		button.visible = false
		_show_options()
	else:
		button.visible = true
		_clear_options()
```

In `_next_line()`, before `closed.emit()`, add `_clear_options()`:

```gdscript
		_clear_options()
```

Add:

```gdscript
func _show_options() -> void:
	_clear_options()
	for raw_option in options:
		if typeof(raw_option) != TYPE_DICTIONARY:
			continue
		var option = raw_option.duplicate(true)
		var option_button = Button.new()
		option_button.text = str(option.get("text", "选项"))
		option_button.disabled = not bool(option.get("available", true))
		option_button.tooltip_text = str(option.get("unavailable_reason", ""))
		option_button.custom_minimum_size = Vector2(360, 32)
		option_button.pressed.connect(func(): _select_option(option))
		option_container.add_child(option_button)

func _select_option(option: Dictionary) -> void:
	hide()
	_clear_options()
	option_selected.emit(option)

func _clear_options() -> void:
	if option_container == null:
		return
	for child in option_container.get_children():
		option_container.remove_child(child)
		child.queue_free()
```

- [ ] **Step 5: Extend MapScreenBase event wiring**

Modify `scripts/scenes/map_screen_base.gd`:

Add preloads:

```gdscript
const EventSystemScript = preload("res://scripts/systems/event_system.gd")
```

Add member variable after `effect_system`:

```gdscript
var event_system = EventSystemScript.new()
```

In `_create_ui()`, after `dialogue_box = DialogueBoxScript.new()`, add:

```gdscript
	if dialogue_box.has_signal("option_selected"):
		dialogue_box.option_selected.connect(_on_dialogue_option_selected)
```

Replace `_open_dialogue()` with:

```gdscript
func _open_dialogue(dialogue_id: String, fallback_text: String = "此人暂时无话可说。") -> void:
	var dialogue_state = dialogue_system.build_dialogue_state(dialogue_id, _get_game_state())
	if dialogue_state.get("lines", []).is_empty():
		dialogue_state["lines"] = [{"speaker": "旁白", "text": fallback_text}]
	if dialogue_box != null:
		if dialogue_box.has_method("open_dialogue_state"):
			dialogue_box.open_dialogue_state(dialogue_state)
		else:
			dialogue_box.open(dialogue_state.get("lines", []))
```

Add:

```gdscript
func _on_dialogue_option_selected(option: Dictionary) -> void:
	if not bool(option.get("available", true)):
		hud.show_message(str(option.get("unavailable_reason", "条件尚未满足。")))
		return
	var event_data = {
		"conditions": option.get("conditions", []),
		"effects": option.get("effects", []),
	}
	var result = event_system.apply_event(_get_game_state(), event_data, {
		"source": "dialogue_option",
		"option_id": str(option.get("id", "")),
	})
	if not bool(result.get("success", false)):
		hud.show_message(_first_event_failure(result))
		return

	var next_dialogue_id = str(option.get("next_dialogue_id", ""))
	if not next_dialogue_id.is_empty():
		_open_dialogue(next_dialogue_id)
	else:
		var effect_result = result.get("effect_result", {})
		hud.show_message(_build_effect_message(effect_result, "已处理。"))
	_refresh_inventory_if_open()
	_refresh_shop_if_open()
	_update_quest_text()

func _first_event_failure(result: Dictionary) -> String:
	var messages = result.get("messages", [])
	if typeof(messages) == TYPE_ARRAY and not messages.is_empty():
		return str(messages[0])
	var errors = result.get("errors", [])
	if typeof(errors) == TYPE_ARRAY and not errors.is_empty():
		return str(errors[0])
	return "条件尚未满足。"
```

Update `_build_effect_message()` to ignore removed items and keep the current positive reward display. No change is needed for `removed_items` because branch option rewards use `add_coins` for visible feedback.

- [ ] **Step 6: Route road outskirts NPC interaction**

Modify `scripts/scenes/road_outskirts_screen.gd`:

Add an `"npc"` branch to `_interact_with()`:

```gdscript
		"npc":
			_open_dialogue(str(interactable.record.get("dialogue_id", "")))
```

- [ ] **Step 7: Run tests and verify Task 5 passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with `测试通过：23 个测试套件`.

- [ ] **Step 8: Commit Task 5**

```powershell
git add scripts/scenes/dialogue_box.gd scripts/scenes/map_screen_base.gd scripts/scenes/road_outskirts_screen.gd tests/test_dialogue_box_options.gd tests/test_pickup_map_screen.gd tests/run_tests.gd
git commit -m "feat: wire branch dialogue events"
```

---

### Task 6: Road Scholar Content Slice

**Files:**
- Modify: `data/maps.json`
- Modify: `data/dialogues.json`
- Create: `tests/test_story_event_data.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write failing content tests**

Create `tests/test_story_event_data.gd`:

```gdscript
extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const EventSystemScript = preload("res://scripts/systems/event_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()

	var road = repository.get_map("road_outskirts")
	var scholar = _find_object(road, "npc_road_scholar")
	assertions.assert_eq(scholar.get("type", ""), "npc", "村外官道应配置赶路书生 NPC")
	assertions.assert_eq(scholar.get("name", ""), "赶路书生", "赶路书生名称应正确")
	assertions.assert_eq(scholar.get("dialogue_id", ""), "road_scholar_intro", "赶路书生应指向分支对话")

	var intro = repository.get_dialogue("road_scholar_intro")
	var options = intro.get("options", [])
	assertions.assert_eq(options.size(), 2, "赶路书生应包含两个分支选项")
	assertions.assert_eq(_find_option(options, "ask_road_unrest").get("next_dialogue_id", ""), "road_scholar_rumor", "询问选项应跳转传闻对白")
	assertions.assert_eq(_find_option(options, "give_medicine").get("next_dialogue_id", ""), "road_scholar_thanks", "赠药选项应跳转感谢对白")
	assertions.assert_true(not repository.get_dialogue("road_scholar_rumor").is_empty(), "传闻后续对白应存在")
	assertions.assert_true(not repository.get_dialogue("road_scholar_thanks").is_empty(), "感谢后续对白应存在")

	var state = GameStateScript.new()
	state.start_new_game()
	state.quest_system.set_status("quest_deliver_letter", "completed")
	var event_system = EventSystemScript.new()
	var ask_option = _find_option(options, "ask_road_unrest")
	var ask_result = event_system.apply_event(state, ask_option)
	assertions.assert_true(bool(ask_result.get("success", false)), "询问路上异动选项应可执行")
	assertions.assert_eq(state.flags.get("clue_road_unrest", false), true, "询问选项应写入官道线索 flag")

	var before_herbs = state.party.get_item_count("herb_small")
	var before_coins = state.party.coins
	var give_option = _find_option(options, "give_medicine")
	var give_result = event_system.apply_event(state, give_option)
	assertions.assert_true(bool(give_result.get("success", false)), "赠药选项应可执行")
	assertions.assert_eq(state.party.get_item_count("herb_small"), before_herbs - 1, "赠药选项应扣除小还丹")
	assertions.assert_eq(state.party.coins, before_coins + 30, "赠药选项应增加铜钱")
	assertions.assert_eq(state.flags.get("helped_road_scholar", false), true, "赠药选项应写入帮助书生 flag")

	var save_data = state.to_dictionary()
	var loaded = GameStateScript.new()
	loaded.from_dictionary(save_data)
	assertions.assert_eq(loaded.flags.get("clue_road_unrest", false), true, "读档后官道线索 flag 应保持")
	assertions.assert_eq(loaded.flags.get("helped_road_scholar", false), true, "读档后帮助书生 flag 应保持")
	assertions.assert_eq(loaded.party.coins, state.party.coins, "读档后铜钱应保持")
	assertions.assert_eq(loaded.party.get_item_count("herb_small"), state.party.get_item_count("herb_small"), "读档后背包变化应保持")

	state.free()
	loaded.free()
	repository.free()

func _find_object(map_data: Dictionary, object_id: String) -> Dictionary:
	for object in map_data.get("objects", []):
		if str(object.get("id", "")) == object_id:
			return object
	return {}

func _find_option(options: Array, option_id: String) -> Dictionary:
	for option in options:
		if str(option.get("id", "")) == option_id:
			return option
	return {}
```

Modify `tests/run_tests.gd`:

```gdscript
const TestStoryEventDataScript = preload("res://tests/test_story_event_data.gd")
```

Add the suite after `TestEventSystemScript.new()`:

```gdscript
		TestStoryEventDataScript.new(),
```

- [ ] **Step 2: Run tests and verify content fails**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `npc_road_scholar` and `road_scholar_intro` do not exist.

- [ ] **Step 3: Add road scholar map object**

In `data/maps.json`, add this object to `road_outskirts.objects` after `notice_road_outskirts_sign`:

```json
      {
        "id": "npc_road_scholar",
        "type": "npc",
        "name": "赶路书生",
        "position": {"x": 900, "y": 300},
        "radius": 72,
        "dialogue_id": "road_scholar_intro"
      }
```

Keep JSON commas valid.

- [ ] **Step 4: Add branch dialogue records**

In `data/dialogues.json`, add these records before the closing `]`:

```json
  {
    "id": "road_scholar_intro",
    "title": "官道书生",
    "lines": [
      {"speaker": "赶路书生", "text": "少侠若往东去，还请多留意路旁车辙。"}
    ],
    "options": [
      {
        "id": "ask_road_unrest",
        "text": "询问路上异动",
        "conditions": [
          {"type": "quest_status", "quest_id": "quest_deliver_letter", "status": "completed"},
          {"type": "not", "condition": {"type": "flag_equals", "key": "clue_road_unrest", "value": true}}
        ],
        "effects": [
          {"type": "set_flag", "key": "clue_road_unrest", "value": true}
        ],
        "next_dialogue_id": "road_scholar_rumor",
        "unavailable_text": "先处理完村中托信，再来细问。"
      },
      {
        "id": "give_medicine",
        "text": "赠予小还丹",
        "conditions": [
          {"type": "has_item", "item_id": "herb_small", "amount": 1},
          {"type": "not", "condition": {"type": "flag_equals", "key": "helped_road_scholar", "value": true}}
        ],
        "effects": [
          {"type": "remove_item", "item_id": "herb_small", "amount": 1},
          {"type": "add_coins", "amount": 30},
          {"type": "set_flag", "key": "helped_road_scholar", "value": true}
        ],
        "next_dialogue_id": "road_scholar_thanks",
        "unavailable_text": "背包中没有小还丹。"
      }
    ]
  },
  {
    "id": "road_scholar_rumor",
    "title": "车辙传闻",
    "lines": [
      {"speaker": "赶路书生", "text": "昨夜有马队沿官道急行，车辙深处夹着红线，像是飞红巾一脉留下的记号。"}
    ]
  },
  {
    "id": "road_scholar_thanks",
    "title": "赠药相谢",
    "lines": [
      {"speaker": "赶路书生", "text": "多谢少侠相助。这些盘缠请收下，路上也好有个照应。"}
    ]
  }
```

Keep JSON commas valid.

- [ ] **Step 5: Run tests and verify Task 6 passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with `测试通过：24 个测试套件`.

- [ ] **Step 6: Commit Task 6**

```powershell
git add data/maps.json data/dialogues.json tests/test_story_event_data.gd tests/run_tests.gd
git commit -m "feat: add road scholar branch event"
```

---

### Task 7: Documentation And Final Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/godot-project-structure.md`

- [ ] **Step 1: Update README current goals**

In `README.md`, add this bullet after the “任务奖励与效果数据化基础切片” bullet:

```markdown
- 剧情事件与分支对话基础切片：分支对话通过 `ConditionSystem` 判断任务、flag、物品和地图对象条件，再由 `EventSystem` 复用 `EffectSystem` 执行选项效果。
```

- [ ] **Step 2: Update project structure docs**

In `docs/godot-project-structure.md`, add this section after “任务奖励与效果数据化基础切片”:

```markdown
## 剧情事件与分支对话基础切片

剧情事件与分支对话切片使用 `ConditionSystem` 判断内容条件，使用 `EventSystem` 在条件满足后执行 `EffectSystem` 效果。`data/dialogues.json` 的 `options` 描述玩家可选分支、条件、效果和后续对白，`data/maps.json` 只声明 NPC 的 `dialogue_id`。`DialogueBox` 只展示对白和选项，`MapScreenBase` 负责把选项交给系统层执行，不在地图脚本里硬写奖励、flag 或背包变化。
```

- [ ] **Step 3: Run full verification**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：24 个测试套件
```

Run:

```powershell
& $godot --headless --path . --quit
```

Expected: process exits with code `0`.

- [ ] **Step 4: Inspect git status**

Run:

```powershell
git status --short
```

Expected: only unrelated pre-existing `?? .spec-workflow/` may remain untracked.

- [ ] **Step 5: Commit Task 7**

```powershell
git add README.md docs/godot-project-structure.md
git commit -m "docs: document story event branch dialogue slice"
```

---

## Manual Acceptance Checklist

- [ ] Start a new game or continue a save that can complete “送信到客栈”.
- [ ] Complete “送信到客栈”.
- [ ] Enter “村外官道”.
- [ ] Talk to “赶路书生”.
- [ ] Confirm the dialogue box shows branch options.
- [ ] Select “询问路上异动”.
- [ ] Confirm the rumor dialogue appears and `clue_road_unrest` behavior is reflected after save/load.
- [ ] Talk to “赶路书生” again while carrying `小还丹`.
- [ ] Select “赠予小还丹”.
- [ ] Confirm `小还丹` decreases by 1, copper increases by 30, and the thanks dialogue appears.
- [ ] Save, return to menu, continue the save.
- [ ] Confirm flag, coins, and inventory changes remain.

## Final Notes

- The expected Godot error logs for missing maps or missing pickup items come from existing negative tests. Treat the final `测试通过：24 个测试套件` line and process exit code as the pass signal.
- Do not modify `.spec-workflow/`, `.superpowers/`, or `.tools/`.
- Do not merge or delete worktrees until the finishing workflow explicitly asks for the user's integration choice.
