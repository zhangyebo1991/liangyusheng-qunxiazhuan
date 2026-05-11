# 任务奖励与效果数据化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a unified `EffectSystem` so quest completion, map pickups, and battle victory rewards are declared in data and executed through one tested system.

**Architecture:** Add `scripts/systems/effect_system.gd` as the only generic effect executor. Keep existing trigger ownership in map scenes, `MapRewardSystem`, and battle return flow, but move reward/status/object mutations into reusable `effects` data. Preserve legacy reward fields as compatibility inputs while new data uses `complete_effects`, `effects`, and `victory_effects`.

**Tech Stack:** Godot 4.6, GDScript, JSON data files, project-local headless Godot test runner.

---

## File Structure

```text
data/maps.json                                  # Add pickup effects for roadside bundle while keeping legacy reward fields during transition
data/quests.json                                # Add complete_effects for mountain trial and delivery quest
docs/godot-project-structure.md                # Document the effect dataization slice
README.md                                      # Update current project capabilities
scripts/core/game_state.gd                     # Route battle victory result mutations through EffectSystem
scripts/scenes/foot_village_screen.gd          # Use data-driven completion effects for delivery quest
scripts/scenes/map_screen_base.gd              # Hold EffectSystem and shared quest effect helpers
scripts/scenes/mountain_pass_screen.gd         # Use data-driven completion effects for mountain trial
scripts/systems/effect_system.gd               # New generic effect executor
scripts/systems/map_reward_system.gd           # Convert pickup rewards/effects into EffectSystem calls
scripts/systems/quest_system.gd                # Add set_status() with validation for effect execution
tests/run_tests.gd                             # Register new test suites
tests/test_effect_data.gd                      # Verify effect data exists and can drive quest/pickup results
tests/test_effect_system.gd                    # Verify EffectSystem success and error paths
tests/test_map_reward_system.gd                # Update pickup reward tests for effect-driven and legacy paths
tests/test_combat_and_save.gd                  # Verify battle victory effects and save restoration
```

Run tests with:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected success after the full plan:

```text
测试通过：19 个测试套件
```

---

### Task 1: EffectSystem Core

**Files:**
- Create: `scripts/systems/effect_system.gd`
- Create: `tests/test_effect_system.gd`
- Modify: `scripts/systems/quest_system.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write the failing EffectSystem test**

Create `tests/test_effect_system.gd`:

```gdscript
extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const EffectSystemScript = preload("res://scripts/systems/effect_system.gd")

func run(assertions) -> void:
	var state = GameStateScript.new()
	state.start_new_game()
	var initial_herbs = state.party.get_item_count("herb_small")
	var initial_coins = state.party.coins
	var effect_system = EffectSystemScript.new()

	var result = effect_system.apply_effects(state, [
		{"type": "add_item", "item_id": "herb_small", "amount": 2},
		{"type": "add_coins", "amount": 15},
		{"type": "set_flag", "key": "clue_test", "value": "测试线索"},
		{"type": "set_quest_status", "quest_id": "quest_mountain_trial", "status": "ready_to_complete"},
		{"type": "resolve_map_object", "object_id": "object_test"},
		{"type": "add_martial_proficiency", "martial_art_id": "basic_sword", "amount": 3}
	])
	assertions.assert_true(result.get("success", false), "合法效果列表应执行成功")
	assertions.assert_eq(result.get("applied", 0), 6, "应记录 6 个成功效果")
	assertions.assert_eq(result.get("failed", 0), 0, "合法效果不应产生失败")
	assertions.assert_eq(state.party.get_item_count("herb_small"), initial_herbs + 2, "add_item 应增加背包数量")
	assertions.assert_eq(state.party.coins, initial_coins + 15, "add_coins 应增加铜钱")
	assertions.assert_eq(state.flags.get("clue_test", ""), "测试线索", "set_flag 应写入 flag")
	assertions.assert_eq(state.quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "set_quest_status 应修改任务状态")
	assertions.assert_true(state.is_map_object_resolved("object_test"), "resolve_map_object 应标记地图对象")
	assertions.assert_eq(state.get_martial_proficiency("basic_sword"), 3, "add_martial_proficiency 应增加熟练度")
	assertions.assert_eq(result.get("items", [])[0].get("id", ""), "herb_small", "结果应记录物品编号")
	assertions.assert_eq(result.get("coins", 0), 15, "结果应记录铜钱总数")

	var missing_list = effect_system.apply_effects(state, {"type": "add_coins", "amount": 1})
	assertions.assert_true(not missing_list.get("success", true), "非数组效果列表应失败")
	assertions.assert_eq(missing_list.get("failed", 0), 1, "非数组效果列表应记录一次失败")

	var unknown = effect_system.apply_effects(state, [{"type": "missing_effect"}])
	assertions.assert_true(not unknown.get("success", true), "未知效果类型应失败")
	assertions.assert_eq(unknown.get("errors", [])[0], "未知效果类型：missing_effect", "未知效果应返回中文错误")

	var missing_item_id = effect_system.apply_effects(state, [{"type": "add_item", "amount": 1}])
	assertions.assert_true(not missing_item_id.get("success", true), "缺少物品编号应失败")
	assertions.assert_eq(missing_item_id.get("errors", [])[0], "物品效果缺少物品编号。", "缺少物品编号应返回中文错误")

	var invalid_amount = effect_system.apply_effects(state, [{"type": "add_coins", "amount": 0}])
	assertions.assert_true(not invalid_amount.get("success", true), "非正数铜钱奖励应失败")
	assertions.assert_eq(invalid_amount.get("errors", [])[0], "铜钱效果数量必须大于 0。", "非正数铜钱应返回中文错误")

	var invalid_status = effect_system.apply_effects(state, [{"type": "set_quest_status", "quest_id": "quest_mountain_trial", "status": "done"}])
	assertions.assert_true(not invalid_status.get("success", true), "非法任务状态应失败")
	assertions.assert_eq(invalid_status.get("errors", [])[0], "任务状态无效：done", "非法任务状态应返回中文错误")

	state.free()
```

- [ ] **Step 2: Register the failing test**

Modify `tests/run_tests.gd` by adding the preload near the other test preloads:

```gdscript
const TestEffectSystemScript = preload("res://tests/test_effect_system.gd")
```

Add the suite after `TestQuestAndDialogueScript.new()`:

```gdscript
		TestEffectSystemScript.new(),
```

- [ ] **Step 3: Run the test suite and verify it fails**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `res://scripts/systems/effect_system.gd` does not exist.

- [ ] **Step 4: Add `QuestSystem.set_status()`**

Replace `scripts/systems/quest_system.gd` with:

```gdscript
extends RefCounted

const STATUS_NOT_STARTED := "not_started"
const STATUS_ACTIVE := "active"
const STATUS_READY_TO_COMPLETE := "ready_to_complete"
const STATUS_COMPLETED := "completed"
const VALID_STATUSES := [
	STATUS_NOT_STARTED,
	STATUS_ACTIVE,
	STATUS_READY_TO_COMPLETE,
	STATUS_COMPLETED,
]

var quest_status: Dictionary = {}

func start_quest(quest_id: String) -> bool:
	if quest_id.is_empty():
		return false
	if get_status(quest_id) != STATUS_NOT_STARTED:
		return false
	quest_status[quest_id] = STATUS_ACTIVE
	return true

func mark_ready_to_complete(quest_id: String) -> bool:
	if get_status(quest_id) != STATUS_ACTIVE:
		return false
	quest_status[quest_id] = STATUS_READY_TO_COMPLETE
	return true

func complete_quest(quest_id: String) -> bool:
	var status = get_status(quest_id)
	if status != STATUS_ACTIVE and status != STATUS_READY_TO_COMPLETE:
		return false
	quest_status[quest_id] = STATUS_COMPLETED
	return true

func set_status(quest_id: String, status: String) -> bool:
	if quest_id.is_empty():
		return false
	if not VALID_STATUSES.has(status):
		return false
	quest_status[quest_id] = status
	return true

func is_valid_status(status: String) -> bool:
	return VALID_STATUSES.has(status)

func get_status(quest_id: String) -> String:
	return str(quest_status.get(quest_id, STATUS_NOT_STARTED))

func to_dictionary() -> Dictionary:
	return quest_status.duplicate(true)

func from_dictionary(data: Dictionary) -> void:
	quest_status = data.duplicate(true)
```

- [ ] **Step 5: Implement `EffectSystem`**

Create `scripts/systems/effect_system.gd`:

```gdscript
extends RefCounted

const VALID_QUEST_STATUSES := [
	"not_started",
	"active",
	"ready_to_complete",
	"completed",
]

func apply_effects(game_state, effects: Variant, context: Dictionary = {}) -> Dictionary:
	var result = _empty_result()
	if game_state == null:
		_add_error(result, "游戏状态缺失。")
		return result
	if typeof(effects) != TYPE_ARRAY:
		_add_error(result, "效果列表格式错误。")
		return result

	for effect in effects:
		_merge_result(result, apply_effect(game_state, effect, context))
	result["success"] = int(result.get("applied", 0)) > 0 and int(result.get("failed", 0)) == 0
	return result

func apply_effect(game_state, effect: Variant, _context: Dictionary = {}) -> Dictionary:
	var result = _empty_result()
	if game_state == null:
		_add_error(result, "游戏状态缺失。")
		return result
	if typeof(effect) != TYPE_DICTIONARY:
		_add_error(result, "效果格式错误。")
		return result

	var effect_type = str(effect.get("type", ""))
	if effect_type.is_empty():
		_add_error(result, "效果缺少类型。")
		return result

	match effect_type:
		"add_item":
			_apply_add_item(result, game_state, effect)
		"add_coins":
			_apply_add_coins(result, game_state, effect)
		"set_flag":
			_apply_set_flag(result, game_state, effect)
		"set_quest_status":
			_apply_set_quest_status(result, game_state, effect)
		"resolve_map_object":
			_apply_resolve_map_object(result, game_state, effect)
		"add_martial_proficiency":
			_apply_add_martial_proficiency(result, game_state, effect)
		_:
			_add_error(result, "未知效果类型：%s" % effect_type)
	result["success"] = int(result.get("applied", 0)) > 0 and int(result.get("failed", 0)) == 0
	return result

func _apply_add_item(result: Dictionary, game_state, effect: Dictionary) -> void:
	var item_id = str(effect.get("item_id", ""))
	var amount = int(effect.get("amount", 1))
	if item_id.is_empty():
		_add_error(result, "物品效果缺少物品编号。")
		return
	if amount <= 0:
		_add_error(result, "物品效果数量必须大于 0。")
		return
	if game_state.party == null:
		_add_error(result, "队伍状态缺失。")
		return
	game_state.party.add_item(item_id, amount)
	var items: Array = result["items"]
	items.append({"id": item_id, "amount": amount})
	_mark_applied(result, "获得物品：%s x%d" % [item_id, amount])

func _apply_add_coins(result: Dictionary, game_state, effect: Dictionary) -> void:
	var amount = int(effect.get("amount", 0))
	if amount <= 0:
		_add_error(result, "铜钱效果数量必须大于 0。")
		return
	if game_state.party == null:
		_add_error(result, "队伍状态缺失。")
		return
	game_state.party.add_coins(amount)
	result["coins"] = int(result.get("coins", 0)) + amount
	_mark_applied(result, "获得铜钱：%d" % amount)

func _apply_set_flag(result: Dictionary, game_state, effect: Dictionary) -> void:
	var key = str(effect.get("key", ""))
	if key.is_empty():
		_add_error(result, "flag 效果缺少 key。")
		return
	var value = effect.get("value", true)
	game_state.set_flag(key, value)
	var flags: Array = result["flags"]
	flags.append({"key": key, "value": value})
	_mark_applied(result, "记录线索：%s" % key)

func _apply_set_quest_status(result: Dictionary, game_state, effect: Dictionary) -> void:
	var quest_id = str(effect.get("quest_id", ""))
	var status = str(effect.get("status", ""))
	if quest_id.is_empty():
		_add_error(result, "任务状态效果缺少任务编号。")
		return
	if not VALID_QUEST_STATUSES.has(status):
		_add_error(result, "任务状态无效：%s" % status)
		return
	if game_state.quest_system == null:
		_add_error(result, "任务系统缺失。")
		return
	if not game_state.quest_system.set_status(quest_id, status):
		_add_error(result, "任务状态写入失败：%s" % quest_id)
		return
	var quests: Array = result["quests"]
	quests.append({"id": quest_id, "status": status})
	_mark_applied(result, "任务状态变更：%s -> %s" % [quest_id, status])

func _apply_resolve_map_object(result: Dictionary, game_state, effect: Dictionary) -> void:
	var object_id = str(effect.get("object_id", ""))
	if object_id.is_empty():
		_add_error(result, "地图对象效果缺少对象编号。")
		return
	game_state.resolve_map_object(object_id)
	var resolved_objects: Array = result["resolved_objects"]
	resolved_objects.append(object_id)
	_mark_applied(result, "地图对象已解决：%s" % object_id)

func _apply_add_martial_proficiency(result: Dictionary, game_state, effect: Dictionary) -> void:
	var martial_art_id = str(effect.get("martial_art_id", ""))
	var amount = int(effect.get("amount", 0))
	if martial_art_id.is_empty():
		_add_error(result, "武学熟练度效果缺少武学编号。")
		return
	if amount <= 0:
		_add_error(result, "武学熟练度效果数量必须大于 0。")
		return
	var current = game_state.add_martial_proficiency(martial_art_id, amount)
	var martial: Array = result["martial_proficiency"]
	martial.append({"id": martial_art_id, "amount": amount, "current": current})
	_mark_applied(result, "武学熟练度提升：%s +%d" % [martial_art_id, amount])

func _empty_result() -> Dictionary:
	return {
		"success": false,
		"applied": 0,
		"failed": 0,
		"messages": [],
		"errors": [],
		"items": [],
		"coins": 0,
		"flags": [],
		"quests": [],
		"resolved_objects": [],
		"martial_proficiency": [],
	}

func _mark_applied(result: Dictionary, message: String) -> void:
	result["applied"] = int(result.get("applied", 0)) + 1
	var messages: Array = result["messages"]
	messages.append(message)

func _add_error(result: Dictionary, message: String) -> void:
	result["failed"] = int(result.get("failed", 0)) + 1
	var errors: Array = result["errors"]
	errors.append(message)
	result["success"] = false

func _merge_result(target: Dictionary, source: Dictionary) -> void:
	target["applied"] = int(target.get("applied", 0)) + int(source.get("applied", 0))
	target["failed"] = int(target.get("failed", 0)) + int(source.get("failed", 0))
	target["coins"] = int(target.get("coins", 0)) + int(source.get("coins", 0))
	for key in ["messages", "errors", "items", "flags", "quests", "resolved_objects", "martial_proficiency"]:
		var target_values: Array = target[key]
		for value in source.get(key, []):
			target_values.append(value)
```

- [ ] **Step 6: Run tests and verify Task 1 passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with `测试通过：18 个测试套件`.

- [ ] **Step 7: Commit Task 1**

```powershell
git add scripts/systems/effect_system.gd scripts/systems/quest_system.gd tests/test_effect_system.gd tests/run_tests.gd
git commit -m "feat: add effect system core"
```

---

### Task 2: Effect Data Fields

**Files:**
- Modify: `data/quests.json`
- Modify: `data/maps.json`
- Create: `tests/test_effect_data.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write failing effect data tests**

Create `tests/test_effect_data.gd`:

```gdscript
extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const EffectSystemScript = preload("res://scripts/systems/effect_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var effect_system = EffectSystemScript.new()

	var mountain = repository.get_quest("quest_mountain_trial")
	var mountain_effects = mountain.get("complete_effects", [])
	assertions.assert_eq(mountain_effects.size(), 2, "山道试剑应声明两个完成效果")
	assertions.assert_eq(_count_effect(mountain_effects, "set_quest_status"), 1, "山道试剑完成效果应设置任务完成")
	assertions.assert_eq(_count_effect(mountain_effects, "add_item"), 1, "山道试剑完成效果应发放小还丹")

	var delivery = repository.get_quest("quest_deliver_letter")
	var delivery_effects = delivery.get("complete_effects", [])
	assertions.assert_eq(delivery_effects.size(), 2, "送信任务应声明两个完成效果")
	assertions.assert_eq(_count_effect(delivery_effects, "set_quest_status"), 1, "送信任务完成效果应设置任务完成")
	assertions.assert_eq(_count_effect(delivery_effects, "set_flag"), 1, "送信任务完成效果应写入线索 flag")

	var road = repository.get_map("road_outskirts")
	var bundle = _find_object(road, "pickup_roadside_bundle")
	var pickup_effects = bundle.get("effects", [])
	assertions.assert_eq(pickup_effects.size(), 3, "路边包裹应声明三个拾取效果")
	assertions.assert_eq(_count_effect(pickup_effects, "add_item"), 1, "路边包裹应通过效果发放小还丹")
	assertions.assert_eq(_count_effect(pickup_effects, "add_coins"), 1, "路边包裹应通过效果发放铜钱")
	assertions.assert_eq(_count_effect(pickup_effects, "resolve_map_object"), 1, "路边包裹应通过效果标记已解决")

	var state = GameStateScript.new()
	state.start_new_game()
	state.quest_system.start_quest("quest_deliver_letter")
	var delivery_result = effect_system.apply_effects(state, delivery_effects)
	assertions.assert_true(delivery_result.get("success", false), "送信任务完成效果应可执行")
	assertions.assert_eq(state.quest_system.get_status("quest_deliver_letter"), "completed", "送信任务效果应完成任务")
	assertions.assert_eq(state.flags.get("clue_foot_village", ""), "掌柜提到飞红巾踪迹", "送信任务效果应写入线索")

	state.free()
	repository.free()

func _count_effect(effects: Array, effect_type: String) -> int:
	var count := 0
	for effect in effects:
		if typeof(effect) == TYPE_DICTIONARY and str(effect.get("type", "")) == effect_type:
			count += 1
	return count

func _find_object(map_data: Dictionary, object_id: String) -> Dictionary:
	for object in map_data.get("objects", []):
		if str(object.get("id", "")) == object_id:
			return object
	return {}
```

- [ ] **Step 2: Register the failing data test**

Modify `tests/run_tests.gd` by adding the preload:

```gdscript
const TestEffectDataScript = preload("res://tests/test_effect_data.gd")
```

Add the suite after `TestEffectSystemScript.new()`:

```gdscript
		TestEffectDataScript.new(),
```

- [ ] **Step 3: Run tests and verify data fields are missing**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL with assertions that `complete_effects` and pickup `effects` are missing.

- [ ] **Step 4: Replace quest data with effect fields**

Replace `data/quests.json` with:

```json
[
  {
    "id": "quest_first_step",
    "title": "初入江湖",
    "description": "向青衫客请教江湖规矩。",
    "start_dialogue": "intro_meet_master",
    "reward_items": ["herb_small"]
  },
  {
    "id": "quest_mountain_trial",
    "title": "山道试剑",
    "description": "击退山道前方的强人，再回去向青衫客复命。",
    "start_dialogue": "mountain_pass_intro",
    "complete_dialogue": "mountain_pass_complete",
    "reward_items": ["herb_small"],
    "reward_item_amounts": {"herb_small": 1},
    "complete_effects": [
      {"type": "set_quest_status", "quest_id": "quest_mountain_trial", "status": "completed"},
      {"type": "add_item", "item_id": "herb_small", "amount": 1}
    ]
  },
  {
    "id": "quest_deliver_letter",
    "title": "送信到客栈",
    "description": "替村口脚夫把书信送到客栈陆掌柜手中。",
    "start_dialogue": "foot_village_porter_intro",
    "complete_dialogue": "deliver_letter_complete",
    "reward_flags": {"clue_foot_village": "掌柜提到飞红巾踪迹"},
    "complete_effects": [
      {"type": "set_quest_status", "quest_id": "quest_deliver_letter", "status": "completed"},
      {"type": "set_flag", "key": "clue_foot_village", "value": "掌柜提到飞红巾踪迹"}
    ]
  }
]
```

- [ ] **Step 5: Add pickup effects to map data**

In `data/maps.json`, replace the `pickup_roadside_bundle` object with:

```json
      {
        "id": "pickup_roadside_bundle",
        "type": "pickup",
        "name": "路边包裹",
        "position": {"x": 620, "y": 340},
        "radius": 56,
        "reward_items": ["herb_small"],
        "reward_item_amounts": {"herb_small": 1},
        "reward_coins": 20,
        "effects": [
          {"type": "add_item", "item_id": "herb_small", "amount": 1},
          {"type": "add_coins", "amount": 20},
          {"type": "resolve_map_object", "object_id": "pickup_roadside_bundle"}
        ]
      }
```

- [ ] **Step 6: Run tests and verify Task 2 passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with `测试通过：19 个测试套件`.

- [ ] **Step 7: Commit Task 2**

```powershell
git add data/quests.json data/maps.json tests/test_effect_data.gd tests/run_tests.gd
git commit -m "feat: add data-driven effect fields"
```

---

### Task 3: MapRewardSystem Uses EffectSystem

**Files:**
- Modify: `scripts/systems/map_reward_system.gd`
- Modify: `tests/test_map_reward_system.gd`

- [ ] **Step 1: Replace map reward tests with effect-driven coverage**

Replace `tests/test_map_reward_system.gd` with:

```gdscript
extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const MapObjectSpawnerScript = preload("res://scripts/systems/map_object_spawner.gd")
const MapRewardSystemScript = preload("res://scripts/systems/map_reward_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var reward_system = MapRewardSystemScript.new()
	reward_system.set_repository(repository)

	var state = GameStateScript.new()
	state.start_new_game()
	var initial_coins = state.party.coins
	var initial_herbs = state.party.get_item_count("herb_small")
	var pickup = {
		"id": "pickup_roadside_bundle",
		"type": "pickup",
		"name": "路边包裹",
		"effects": [
			{"type": "add_item", "item_id": "herb_small", "amount": 1},
			{"type": "add_coins", "amount": 20},
			{"type": "resolve_map_object", "object_id": "pickup_roadside_bundle"}
		]
	}
	var result = reward_system.claim_pickup(state, pickup)
	assertions.assert_true(result.get("success", false), "有效包裹应可通过 effects 领取")
	assertions.assert_eq(result.get("message", ""), "获得：小还丹、20 文。", "领取包裹应返回物品和铜钱提示")
	assertions.assert_eq(state.party.get_item_count("herb_small"), initial_herbs + 1, "领取包裹应增加小还丹")
	assertions.assert_eq(state.party.coins, initial_coins + 20, "领取包裹应增加铜钱")
	assertions.assert_true(state.is_map_object_resolved("pickup_roadside_bundle"), "领取包裹后应标记对象已解决")

	var duplicate = reward_system.claim_pickup(state, pickup)
	assertions.assert_true(not duplicate.get("success", true), "已领取包裹不应重复领取")
	assertions.assert_eq(duplicate.get("message", ""), "这里什么也没有。", "重复领取应显示空提示")
	assertions.assert_eq(state.party.get_item_count("herb_small"), initial_herbs + 1, "重复领取不应增加物品")
	assertions.assert_eq(state.party.coins, initial_coins + 20, "重复领取不应增加铜钱")

	var legacy_state = GameStateScript.new()
	legacy_state.start_new_game()
	var legacy = reward_system.claim_pickup(legacy_state, {
		"id": "pickup_legacy_bundle",
		"type": "pickup",
		"name": "旧包裹",
		"reward_items": ["herb_small"],
		"reward_item_amounts": {"herb_small": 2},
		"reward_coins": 12
	})
	assertions.assert_true(legacy.get("success", false), "旧奖励字段应兼容领取")
	assertions.assert_eq(legacy.get("message", ""), "获得：小还丹 x2、12 文。", "旧奖励字段应返回正确提示")
	assertions.assert_eq(legacy_state.party.get_item_count("herb_small"), 3, "旧奖励字段应增加小还丹")
	assertions.assert_eq(legacy_state.party.coins, 92, "旧奖励字段应增加铜钱")
	assertions.assert_true(legacy_state.is_map_object_resolved("pickup_legacy_bundle"), "旧奖励字段领取后应标记对象已解决")

	var invalid_state = GameStateScript.new()
	invalid_state.start_new_game()
	var invalid = reward_system.claim_pickup(invalid_state, {
		"id": "pickup_invalid",
		"type": "pickup",
		"name": "空包裹",
		"effects": [
			{"type": "add_item", "item_id": "missing_item", "amount": 1},
			{"type": "resolve_map_object", "object_id": "pickup_invalid"}
		]
	})
	assertions.assert_true(not invalid.get("success", true), "全部奖励无效时不应成功")
	assertions.assert_eq(invalid.get("message", ""), "这里什么也没有。", "全部奖励无效时应显示空提示")
	assertions.assert_true(not invalid_state.is_map_object_resolved("pickup_invalid"), "全部奖励无效时不应标记对象已解决")

	var no_id = reward_system.claim_pickup(invalid_state, {
		"type": "pickup",
		"effects": [
			{"type": "add_coins", "amount": 10}
		]
	})
	assertions.assert_true(not no_id.get("success", true), "缺少编号的拾取对象不应成功")
	assertions.assert_eq(no_id.get("message", ""), "这里什么也没有。", "缺少编号时应显示空提示")

	var restored = GameStateScript.new()
	restored.from_dictionary(state.to_dictionary())
	var road = repository.get_map("road_outskirts")
	var spawner = MapObjectSpawnerScript.new()
	var records = spawner.get_spawn_records(road, restored.map_state.resolved_objects, restored)
	assertions.assert_eq(_count_object(records, "pickup_roadside_bundle"), 0, "读档后已领取包裹不应再次生成")

	state.free()
	legacy_state.free()
	invalid_state.free()
	restored.free()
	repository.free()

func _count_object(records: Array, object_id: String) -> int:
	var count := 0
	for record in records:
		if str(record.get("id", "")) == object_id:
			count += 1
	return count
```

- [ ] **Step 2: Run tests and verify MapRewardSystem still uses old direct logic**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because current `MapRewardSystem` ignores `effects`.

- [ ] **Step 3: Replace MapRewardSystem implementation**

Replace `scripts/systems/map_reward_system.gd` with:

```gdscript
extends RefCounted

const EffectSystemScript = preload("res://scripts/systems/effect_system.gd")

const MESSAGE_EMPTY := "这里什么也没有。"

var repository = null
var effect_system = EffectSystemScript.new()

func set_repository(next_repository) -> void:
	repository = next_repository

func claim_pickup(game_state, object_record: Dictionary) -> Dictionary:
	var object_id = str(object_record.get("id", ""))
	if game_state == null or game_state.party == null:
		return _failure(object_id)
	if object_id.is_empty():
		push_error("拾取对象缺少编号。")
		return _failure(object_id)
	if game_state.is_map_object_resolved(object_id):
		return _failure(object_id)

	var effects = _build_pickup_effects(object_record)
	if effects.is_empty():
		return _failure(object_id)

	var effect_result = effect_system.apply_effects(game_state, effects, {"source": "pickup", "object_id": object_id})
	var awarded_items = _named_items(effect_result.get("items", []))
	var awarded_coins = int(effect_result.get("coins", 0))
	if not bool(effect_result.get("success", false)) or (awarded_items.is_empty() and awarded_coins <= 0):
		return _failure(object_id)

	return {
		"success": true,
		"message": _build_message(awarded_items, awarded_coins),
		"items": awarded_items,
		"coins": awarded_coins,
		"object_id": object_id,
	}

func _build_pickup_effects(object_record: Dictionary) -> Array:
	var object_id = str(object_record.get("id", ""))
	var raw_effects = object_record.get("effects", [])
	if typeof(raw_effects) == TYPE_ARRAY and not raw_effects.is_empty():
		return _filter_effects(raw_effects, object_id)
	return _legacy_reward_effects(object_record)

func _filter_effects(raw_effects: Array, object_id: String) -> Array:
	var result: Array = []
	var has_reward := false
	var has_resolve := false
	for raw_effect in raw_effects:
		if typeof(raw_effect) != TYPE_DICTIONARY:
			continue
		var effect = raw_effect.duplicate(true)
		match str(effect.get("type", "")):
			"add_item":
				var item_id = str(effect.get("item_id", ""))
				var amount = int(effect.get("amount", 1))
				if item_id.is_empty() or amount <= 0 or not _item_exists(item_id):
					push_error("拾取奖励物品不存在：%s" % item_id)
					continue
				has_reward = true
				result.append(effect)
			"add_coins":
				if int(effect.get("amount", 0)) <= 0:
					continue
				has_reward = true
				result.append(effect)
			"resolve_map_object":
				has_resolve = true
				result.append(effect)
			_:
				result.append(effect)
	if not has_reward:
		return []
	if not has_resolve:
		result.append({"type": "resolve_map_object", "object_id": object_id})
	return result

func _legacy_reward_effects(object_record: Dictionary) -> Array:
	var result: Array = []
	var raw_items = object_record.get("reward_items", [])
	if typeof(raw_items) == TYPE_ARRAY:
		var amounts = object_record.get("reward_item_amounts", {})
		if typeof(amounts) != TYPE_DICTIONARY:
			amounts = {}
		for raw_item_id in raw_items:
			var item_id = str(raw_item_id)
			if item_id.is_empty() or not _item_exists(item_id):
				push_error("拾取奖励物品不存在：%s" % item_id)
				continue
			result.append({
				"type": "add_item",
				"item_id": item_id,
				"amount": max(1, int(amounts.get(item_id, 1))),
			})

	var coins = int(object_record.get("reward_coins", 0))
	if coins > 0:
		result.append({"type": "add_coins", "amount": coins})

	if not result.is_empty():
		result.append({"type": "resolve_map_object", "object_id": str(object_record.get("id", ""))})
	return result

func _named_items(items: Array) -> Array:
	var result: Array = []
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_id = str(item.get("id", ""))
		if item_id.is_empty():
			continue
		var item_data = _get_repository().get_item(item_id) if _get_repository() != null else {}
		result.append({
			"id": item_id,
			"name": str(item_data.get("name", item_id)),
			"amount": int(item.get("amount", 1)),
		})
	return result

func _item_exists(item_id: String) -> bool:
	var item_repository = _get_repository()
	if item_repository == null:
		return true
	return not item_repository.get_item(item_id).is_empty()

func _build_message(items: Array, coins: int) -> String:
	var parts: Array[String] = []
	for item in items:
		var name = str(item.get("name", "物品"))
		var amount = int(item.get("amount", 1))
		if amount > 1:
			parts.append("%s x%d" % [name, amount])
		else:
			parts.append(name)
	if coins > 0:
		parts.append("%d 文" % coins)
	if parts.is_empty():
		return MESSAGE_EMPTY
	return "获得：%s。" % "、".join(parts)

func _failure(object_id: String) -> Dictionary:
	return {
		"success": false,
		"message": MESSAGE_EMPTY,
		"items": [],
		"coins": 0,
		"object_id": object_id,
	}

func _get_repository():
	if repository != null:
		return repository
	var loop = Engine.get_main_loop()
	if loop != null and loop.root != null and loop.root.has_node("DataRepository"):
		return loop.root.get_node("DataRepository")
	return null
```

- [ ] **Step 4: Run tests and verify Task 3 passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with `测试通过：19 个测试套件`.

- [ ] **Step 5: Commit Task 3**

```powershell
git add scripts/systems/map_reward_system.gd tests/test_map_reward_system.gd
git commit -m "feat: route pickup rewards through effects"
```

---

### Task 4: Quest Completion Uses EffectSystem

**Files:**
- Modify: `scripts/scenes/map_screen_base.gd`
- Modify: `scripts/scenes/mountain_pass_screen.gd`
- Modify: `scripts/scenes/foot_village_screen.gd`
- Modify: `tests/test_effect_data.gd`

- [ ] **Step 1: Extend effect data test for quest completion execution**

In `tests/test_effect_data.gd`, after the delivery effect assertions, add:

```gdscript
	var mountain_state = GameStateScript.new()
	mountain_state.start_new_game()
	mountain_state.quest_system.start_quest("quest_mountain_trial")
	mountain_state.quest_system.mark_ready_to_complete("quest_mountain_trial")
	var mountain_initial_herbs = mountain_state.party.get_item_count("herb_small")
	var mountain_result = effect_system.apply_effects(mountain_state, mountain_effects)
	assertions.assert_true(mountain_result.get("success", false), "山道试剑完成效果应可执行")
	assertions.assert_eq(mountain_state.quest_system.get_status("quest_mountain_trial"), "completed", "山道试剑完成效果应完成任务")
	assertions.assert_eq(mountain_state.party.get_item_count("herb_small"), mountain_initial_herbs + 1, "山道试剑完成效果应奖励小还丹")
	mountain_state.free()
```

- [ ] **Step 2: Run tests and verify data effects pass before scene integration**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with `测试通过：19 个测试套件`.

- [ ] **Step 3: Add shared effect helpers to MapScreenBase**

Modify `scripts/scenes/map_screen_base.gd`.

Add this preload below the existing system preloads:

```gdscript
const EffectSystemScript = preload("res://scripts/systems/effect_system.gd")
```

Add this instance variable below `var map_reward_system = MapRewardSystemScript.new()`:

```gdscript
var effect_system = EffectSystemScript.new()
```

Add these helper methods after `_claim_pickup(record: Dictionary) -> void`:

```gdscript
func _apply_quest_complete_effects(quest_id: String) -> Dictionary:
	var game_state = _get_game_state()
	var data_repository = _get_data_repository()
	if game_state == null or data_repository == null or quest_id.is_empty():
		return {
			"success": false,
			"applied": 0,
			"failed": 1,
			"messages": [],
			"errors": ["任务效果无法执行。"],
			"items": [],
			"coins": 0,
			"flags": [],
			"quests": [],
			"resolved_objects": [],
			"martial_proficiency": [],
		}
	var quest = data_repository.get_quest(quest_id)
	var effects = _quest_complete_effects(quest_id, quest)
	return effect_system.apply_effects(game_state, effects, {"source": "quest_complete", "quest_id": quest_id})

func _quest_complete_effects(quest_id: String, quest: Dictionary) -> Array:
	var effects = quest.get("complete_effects", [])
	if typeof(effects) == TYPE_ARRAY and not effects.is_empty():
		return effects

	var result: Array = [
		{"type": "set_quest_status", "quest_id": quest_id, "status": "completed"}
	]
	var reward_items = quest.get("reward_items", [])
	if typeof(reward_items) == TYPE_ARRAY:
		var amounts = quest.get("reward_item_amounts", {})
		if typeof(amounts) != TYPE_DICTIONARY:
			amounts = {}
		for raw_item_id in reward_items:
			var item_id = str(raw_item_id)
			if item_id.is_empty():
				continue
			result.append({
				"type": "add_item",
				"item_id": item_id,
				"amount": max(1, int(amounts.get(item_id, 1))),
			})

	var reward_flags = quest.get("reward_flags", {})
	if typeof(reward_flags) == TYPE_DICTIONARY:
		for raw_key in reward_flags.keys():
			var key = str(raw_key)
			if key.is_empty():
				continue
			result.append({
				"type": "set_flag",
				"key": key,
				"value": reward_flags[raw_key],
			})
	return result

func _build_effect_message(result: Dictionary, fallback_message: String) -> String:
	var item_parts: Array[String] = []
	var data_repository = _get_data_repository()
	for item in result.get("items", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_id = str(item.get("id", ""))
		if item_id.is_empty():
			continue
		var item_data = data_repository.get_item(item_id) if data_repository != null else {}
		var name = str(item_data.get("name", item_id))
		var amount = int(item.get("amount", 1))
		if amount > 1:
			item_parts.append("%s x%d" % [name, amount])
		else:
			item_parts.append(name)
	var coins = int(result.get("coins", 0))
	if coins > 0:
		item_parts.append("%d 文" % coins)
	if item_parts.is_empty():
		return fallback_message
	return "获得：%s。" % "、".join(item_parts)
```

- [ ] **Step 4: Refactor mountain trial completion**

In `scripts/scenes/mountain_pass_screen.gd`, replace the `elif status == "ready_to_complete":` branch in `_talk_to_npc()` with:

```gdscript
	elif status == "ready_to_complete":
		var result = _apply_quest_complete_effects(quest_id)
		_open_dialogue("mountain_pass_complete")
		hud.show_message(_build_effect_message(result, "任务完成：山道试剑"))
```

- [ ] **Step 5: Refactor delivery quest completion**

In `scripts/scenes/foot_village_screen.gd`, replace the `if status == "active":` and `elif status == "ready_to_complete":` branches in `_talk_to_innkeeper()` with one branch:

```gdscript
	if status == "active" or status == "ready_to_complete":
		var result = _apply_quest_complete_effects("quest_deliver_letter")
		_open_dialogue("deliver_letter_complete")
		hud.show_message(_build_effect_message(result, "获得线索：飞红巾踪迹"))
```

The full `_talk_to_innkeeper()` method should become:

```gdscript
func _talk_to_innkeeper(_record: Dictionary) -> void:
	var status = GameState.quest_system.get_status("quest_deliver_letter")
	if status == "not_started":
		_open_dialogue("foot_village_innkeeper_idle")
		return
	if status == "active" or status == "ready_to_complete":
		var result = _apply_quest_complete_effects("quest_deliver_letter")
		_open_dialogue("deliver_letter_complete")
		hud.show_message(_build_effect_message(result, "获得线索：飞红巾踪迹"))
	else:
		_open_dialogue("deliver_letter_after")
	_update_quest_text()
```

- [ ] **Step 6: Run tests and verify quest completion integration compiles**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with `测试通过：19 个测试套件`.

- [ ] **Step 7: Commit Task 4**

```powershell
git add scripts/scenes/map_screen_base.gd scripts/scenes/mountain_pass_screen.gd scripts/scenes/foot_village_screen.gd tests/test_effect_data.gd
git commit -m "feat: use effects for quest completion"
```

---

### Task 5: Battle Victory Uses EffectSystem

**Files:**
- Modify: `scripts/core/game_state.gd`
- Modify: `tests/test_combat_and_save.gd`

- [ ] **Step 1: Add explicit victory_effects regression test**

In `tests/test_combat_and_save.gd`, after the existing victory `apply_battle_result()` assertions, add:

```gdscript
	var effect_state = GameStateScript.new()
	effect_state.start_new_game()
	effect_state.quest_system.start_quest("quest_mountain_trial")
	effect_state.apply_battle_result({
		"victory": true,
		"hero_hp": 50,
		"victory_effects": [
			{"type": "resolve_map_object", "object_id": "enemy_bandit_gate"},
			{"type": "set_quest_status", "quest_id": "quest_mountain_trial", "status": "ready_to_complete"},
			{"type": "add_martial_proficiency", "martial_art_id": "basic_sword", "amount": 2}
		]
	})
	assertions.assert_true(effect_state.is_map_object_resolved("enemy_bandit_gate"), "victory_effects 应标记强人触发点")
	assertions.assert_eq(effect_state.quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "victory_effects 应推进任务状态")
	assertions.assert_eq(effect_state.hero_hp, 50, "victory_effects 不应覆盖胜利后气血")
	assertions.assert_eq(effect_state.get_martial_proficiency("basic_sword"), 2, "victory_effects 应增加武学熟练度")
	effect_state.free()
```

- [ ] **Step 2: Run tests and verify the new victory_effects path fails**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because the current `GameState.apply_battle_result()` ignores `victory_effects` and only reads the legacy battle result fields.

- [ ] **Step 3: Route victory result through EffectSystem**

Modify `scripts/core/game_state.gd`.

Add this preload below the existing preloads:

```gdscript
const EffectSystemScript = preload("res://scripts/systems/effect_system.gd")
```

Replace `apply_battle_result(result: Dictionary) -> void` with:

```gdscript
func apply_battle_result(result: Dictionary) -> void:
	if result.has("hero_hp"):
		hero_hp = int(result.get("hero_hp", hero_hp))

	if bool(result.get("victory", false)):
		_normalize_hero_hp()
		var effect_system = EffectSystemScript.new()
		effect_system.apply_effects(self, _battle_victory_effects(result), result)
	else:
		hero_hp = max(1, hero_hp)
		map_state.player_position = Vector2(160, 320)
```

Add this helper below `apply_battle_result()`:

```gdscript
func _battle_victory_effects(result: Dictionary) -> Array:
	var explicit_effects = result.get("victory_effects", [])
	if typeof(explicit_effects) == TYPE_ARRAY and not explicit_effects.is_empty():
		return explicit_effects

	var effects: Array = []
	var object_id = str(result.get("source_object_id", ""))
	if not object_id.is_empty():
		effects.append({"type": "resolve_map_object", "object_id": object_id})
	var quest_id = str(result.get("quest_id", ""))
	if not quest_id.is_empty():
		effects.append({"type": "set_quest_status", "quest_id": quest_id, "status": "ready_to_complete"})
	var martial_art_id = str(result.get("martial_art_id", ""))
	var reward = int(result.get("proficiency_reward", 0))
	if not martial_art_id.is_empty() and reward > 0:
		effects.append({"type": "add_martial_proficiency", "martial_art_id": martial_art_id, "amount": reward})
	return effects
```

- [ ] **Step 4: Run tests and verify Task 5 passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with `测试通过：19 个测试套件`.

- [ ] **Step 5: Commit Task 5**

```powershell
git add scripts/core/game_state.gd tests/test_combat_and_save.gd
git commit -m "feat: route battle victory through effects"
```

---

### Task 6: Documentation And Final Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/godot-project-structure.md`

- [ ] **Step 1: Update README current goals**

In `README.md`, add this bullet after the “村外官道与地图规则基础切片” bullet:

```markdown
- 任务奖励与效果数据化基础切片：任务完成、地图拾取和战斗胜利回流通过统一 `EffectSystem` 执行物品、铜钱、线索、任务状态、地图对象和武学熟练度效果。
```

- [ ] **Step 2: Update project structure docs**

In `docs/godot-project-structure.md`, add this section after “村外官道与地图规则基础切片”:

```markdown
## 任务奖励与效果数据化基础切片

任务奖励与效果数据化切片使用 `EffectSystem` 统一执行内容数据声明的结果。`data/quests.json` 的 `complete_effects` 描述任务完成效果，`data/maps.json` 的拾取对象 `effects` 描述拾取结果，战斗胜利回流可通过 `victory_effects` 或兼容字段生成效果。`EffectSystem` 支持添加物品、添加铜钱、设置 flag、设置任务状态、标记地图对象已解决和增加武学熟练度。场景脚本只负责触发和展示消息，不直接硬写奖励、线索或任务状态。
```

- [ ] **Step 3: Run full verification**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：19 个测试套件
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

- [ ] **Step 5: Commit Task 6**

```powershell
git add README.md docs/godot-project-structure.md
git commit -m "docs: document effect dataization slice"
```

---

## Manual Acceptance Checklist

- [ ] Start a new game.
- [ ] Talk to 青衫客 and start 山道试剑.
- [ ] Defeat 山道强人.
- [ ] Confirm the enemy trigger disappears and 山道试剑 becomes ready to complete.
- [ ] Return to 青衫客 and complete 山道试剑.
- [ ] Confirm 小还丹 is awarded.
- [ ] Go to 山脚村镇 and start 送信到客栈 with 陈脚夫.
- [ ] Talk to 陆掌柜 and complete 送信到客栈.
- [ ] Confirm the clue flag behavior still unlocks 村外官道.
- [ ] Enter 村外官道.
- [ ] Pick up 路边包裹.
- [ ] Confirm 小还丹 and 20 文 are awarded and the package disappears.
- [ ] Save, return to menu, continue the save.
- [ ] Confirm package remains gone and inventory, coins, quest status, flag, and martial proficiency are restored.
