# 山道探索垂直切片 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建一段可从主菜单进入、用 WASD 连续移动、与青衫客接任务、触发战斗、回地图交任务并保存恢复进度的山道探索垂直切片。

**Architecture:** 保持现有“领域逻辑、系统流程、场景表现”分层。地图地形使用 Godot 场景中的 `TileMapLayer` 表达，第一版碰撞用明确的 `StaticBody2D` 边界和障碍配合，NPC 与战斗触发对象由 `data/maps.json` 配置生成。`GameState` 保存当前地图、玩家坐标、已解决地图对象和战斗回流上下文，场景脚本只负责装配和显示。

**Tech Stack:** Godot 4.6、GDScript、JSON 数据文件、Godot 无头脚本测试、PowerShell 验证命令。

---

## 文件结构

```text
data/maps.json                                # 山道地图对象配置
data/actors.json                              # 增加青衫客并保留主角、强人
data/dialogues.json                           # 增加山道试剑对白
data/quests.json                              # 增加山道试剑任务
project.godot                                 # 增加 InputMap 动作
scenes/mountain_pass.tscn                     # 山道探索场景
scripts/core/game_state.gd                    # 增加地图状态和战斗回流上下文
scripts/domain/map_state.gd                   # 可序列化地图状态
scripts/scenes/battle_screen.gd               # 根据战斗上下文返回山道
scripts/scenes/dialogue_box.gd                # 对话框 UI
scripts/scenes/hud.gd                         # 任务摘要、交互提示、短消息
scripts/scenes/main_menu_screen.gd            # 开始新游戏进入山道
scripts/scenes/map_interactable.gd            # NPC 和战斗触发对象节点脚本
scripts/scenes/mountain_pass_screen.gd        # 山道场景装配与流程
scripts/scenes/player_controller.gd           # WASD 连续移动、朝向、交互目标
scripts/scenes/simple_sprite_factory.gd       # 原型像素角色动画帧
scripts/systems/data_repository.gd            # 加载 maps 并读取地图
scripts/systems/interaction_system.gd         # 键鼠交互范围判断
scripts/systems/map_object_spawner.gd         # 根据 maps.json 生成交互对象
scripts/systems/quest_system.gd               # 增加可交付状态
tests/run_tests.gd                            # 接入新增测试套件
tests/test_interaction_system.gd              # 交互范围逻辑测试
tests/test_map_data.gd                        # 地图数据读取测试
tests/test_map_state_and_flow.gd              # 地图状态、任务流转和存档测试
```

本计划不修改 `.spec-workflow/`。`.superpowers/` 和 `.tools/` 必须保持不提交。

验证命令优先使用本项目本地 Godot：

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

如果本地 Godot 不存在，先运行：

```powershell
Get-Command godot -ErrorAction SilentlyContinue
```

有 `godot` 命令时改用：

```powershell
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . --quit
```

---

### Task 1: 添加山道地图数据和数据仓库读取能力

**Files:**
- Create: `data/maps.json`
- Modify: `data/actors.json`
- Modify: `data/dialogues.json`
- Modify: `data/quests.json`
- Modify: `scripts/systems/data_repository.gd`
- Create: `tests/test_map_data.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 写失败测试 `tests/test_map_data.gd`**

Create `tests/test_map_data.gd`:

```gdscript
extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	var content = repository.load_all()

	assertions.assert_eq(content.get("maps", []).size(), 1, "应加载 1 张示例地图")

	var map = repository.get_map("mountain_pass")
	assertions.assert_eq(map.get("name", ""), "山道", "应按编号读取山道地图")
	assertions.assert_eq(map.get("spawn_position", {}).get("x", 0), 160, "山道出生点横坐标应正确")
	assertions.assert_eq(map.get("objects", []).size(), 2, "山道应配置 2 个交互对象")
	assertions.assert_eq(repository.get_actor("qingshanke").get("name", ""), "青衫客", "应读取青衫客角色")
	assertions.assert_eq(repository.get_quest("quest_mountain_trial").get("title", ""), "山道试剑", "应读取山道任务")
	assertions.assert_eq(repository.get_dialogue("mountain_pass_intro").get("title", ""), "山道初逢", "应读取山道对白")
	assertions.assert_eq(repository.get_map("missing_map"), {}, "缺失地图编号应返回空字典")

	repository.free()
```

- [ ] **Step 2: 接入测试运行器并确认失败**

Modify `tests/run_tests.gd`:

```gdscript
extends SceneTree

const TestAssertionsScript = preload("res://tests/support/test_assertions.gd")
const TestDataLoaderScript = preload("res://tests/test_data_loader.gd")
const TestDomainModelsScript = preload("res://tests/test_domain_models.gd")
const TestQuestAndDialogueScript = preload("res://tests/test_quest_and_dialogue.gd")
const TestCombatAndSaveScript = preload("res://tests/test_combat_and_save.gd")
const TestMapDataScript = preload("res://tests/test_map_data.gd")

func _initialize() -> void:
	var assertions = TestAssertionsScript.new()
	var suites: Array = [
		TestDataLoaderScript.new(),
		TestDomainModelsScript.new(),
		TestQuestAndDialogueScript.new(),
		TestCombatAndSaveScript.new(),
		TestMapDataScript.new(),
	]

	for suite in suites:
		suite.run(assertions)

	for failure in assertions.failures:
		push_error(failure)

	if assertions.failures.is_empty():
		print("测试通过：%d 个测试套件" % suites.size())
		quit(0)
	else:
		print("测试失败：%d 个问题" % assertions.failures.size())
		quit(1)
```

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 测试失败，错误原因包含无法加载 `res://data/maps.json` 或 `Invalid call. Nonexistent function 'get_map'`。

- [ ] **Step 3: 创建 `data/maps.json`**

Create `data/maps.json`:

```json
[
  {
    "id": "mountain_pass",
    "name": "山道",
    "spawn_position": {"x": 160, "y": 320},
    "objects": [
      {
        "id": "npc_qingshanke",
        "type": "npc",
        "name": "青衫客",
        "actor_id": "qingshanke",
        "position": {"x": 360, "y": 280},
        "radius": 72,
        "dialogue_id": "mountain_pass_intro",
        "quest_id": "quest_mountain_trial"
      },
      {
        "id": "enemy_bandit_gate",
        "type": "battle_trigger",
        "name": "山道强人",
        "actor_id": "bandit_01",
        "position": {"x": 720, "y": 260},
        "radius": 56,
        "quest_id": "quest_mountain_trial"
      }
    ]
  }
]
```

- [ ] **Step 4: 更新内容数据**

Replace `data/actors.json` with:

```json
[
  {
    "id": "hero_yun",
    "name": "云游少侠",
    "level": 1,
    "hp": 120,
    "max_hp": 120,
    "attack": 18,
    "defense": 8,
    "martial_arts": ["basic_sword"]
  },
  {
    "id": "qingshanke",
    "name": "青衫客",
    "level": 8,
    "hp": 260,
    "max_hp": 260,
    "attack": 42,
    "defense": 26,
    "martial_arts": ["basic_sword"]
  },
  {
    "id": "bandit_01",
    "name": "山道强人",
    "level": 1,
    "hp": 70,
    "max_hp": 70,
    "attack": 12,
    "defense": 4,
    "martial_arts": ["rough_fist"]
  }
]
```

Replace `data/dialogues.json` with:

```json
[
  {
    "id": "intro_meet_master",
    "title": "初入江湖",
    "lines": [
      {
        "speaker": "青衫客",
        "text": "江湖路远，先学会保命。"
      },
      {
        "speaker": "云游少侠",
        "text": "晚辈谨记。"
      }
    ]
  },
  {
    "id": "mountain_pass_intro",
    "title": "山道初逢",
    "lines": [
      {
        "speaker": "青衫客",
        "text": "前方有强人拦路，若想继续赶路，先试试你的剑。"
      },
      {
        "speaker": "云游少侠",
        "text": "晚辈愿往前一试。"
      }
    ]
  },
  {
    "id": "mountain_pass_complete",
    "title": "试剑归来",
    "lines": [
      {
        "speaker": "青衫客",
        "text": "出剑不乱，心也不乱。此丹你收下，路上或能救急。"
      }
    ]
  }
]
```

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
    "reward_item_amounts": {"herb_small": 1}
  }
]
```

- [ ] **Step 5: 扩展 `DataRepository`**

Replace `scripts/systems/data_repository.gd` with:

```gdscript
extends Node

const DATA_FILES := {
	"actors": "res://data/actors.json",
	"items": "res://data/items.json",
	"martial_arts": "res://data/martial_arts.json",
	"quests": "res://data/quests.json",
	"dialogues": "res://data/dialogues.json",
	"maps": "res://data/maps.json",
}

var content: Dictionary = {}

func load_all() -> Dictionary:
	var loaded: Dictionary = {}
	for key in DATA_FILES.keys():
		loaded[key] = _load_json_array(DATA_FILES[key])
	content = loaded
	return content

func get_actor(actor_id: String) -> Dictionary:
	return _find_by_id("actors", actor_id)

func get_item(item_id: String) -> Dictionary:
	return _find_by_id("items", item_id)

func get_martial_art(martial_art_id: String) -> Dictionary:
	return _find_by_id("martial_arts", martial_art_id)

func get_quest(quest_id: String) -> Dictionary:
	return _find_by_id("quests", quest_id)

func get_dialogue(dialogue_id: String) -> Dictionary:
	return _find_by_id("dialogues", dialogue_id)

func get_map(map_id: String) -> Dictionary:
	return _find_by_id("maps", map_id)

func _find_by_id(collection_name: String, record_id: String) -> Dictionary:
	if content.is_empty():
		load_all()

	for record in content.get(collection_name, []):
		if record.get("id", "") == record_id:
			return record

	return {}

func _load_json_array(path: String) -> Array:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法读取数据文件：%s" % path)
		return []

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("数据文件必须是数组：%s" % path)
		return []

	return parsed
```

- [ ] **Step 6: 运行测试并提交**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：5 个测试套件
```

Commit:

```powershell
git add data scripts/systems/data_repository.gd tests/run_tests.gd tests/test_map_data.gd
git commit -m "feat: 添加山道地图数据"
```

---

### Task 2: 添加地图状态、任务可交付状态和存档覆盖

**Files:**
- Create: `scripts/domain/map_state.gd`
- Modify: `scripts/core/game_state.gd`
- Modify: `scripts/systems/quest_system.gd`
- Modify: `tests/test_quest_and_dialogue.gd`
- Create: `tests/test_map_state_and_flow.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 写地图状态和流程测试**

Create `tests/test_map_state_and_flow.gd`:

```gdscript
extends RefCounted

const MapStateScript = preload("res://scripts/domain/map_state.gd")
const QuestSystemScript = preload("res://scripts/systems/quest_system.gd")
const SaveSystemScript = preload("res://scripts/systems/save_system.gd")

func run(assertions) -> void:
	var map_state = MapStateScript.new()
	map_state.current_map_id = "mountain_pass"
	map_state.player_position = Vector2(240, 320)
	map_state.mark_object_resolved("enemy_bandit_gate")

	var serialized = map_state.to_dictionary()
	assertions.assert_eq(serialized.get("current_map_id", ""), "mountain_pass", "地图状态应保存当前地图编号")
	assertions.assert_eq(serialized.get("player_position", {}).get("x", 0), 240.0, "地图状态应保存玩家横坐标")
	assertions.assert_true(serialized.get("resolved_objects", []).has("enemy_bandit_gate"), "地图状态应保存已解决对象")

	var restored = MapStateScript.new()
	restored.from_dictionary(serialized)
	assertions.assert_eq(restored.current_map_id, "mountain_pass", "地图状态应恢复当前地图编号")
	assertions.assert_eq(restored.player_position, Vector2(240, 320), "地图状态应恢复玩家坐标")
	assertions.assert_true(restored.is_object_resolved("enemy_bandit_gate"), "地图状态应恢复已解决对象")

	var quest_system = QuestSystemScript.new()
	assertions.assert_true(quest_system.start_quest("quest_mountain_trial"), "山道任务应可开始")
	assertions.assert_true(quest_system.mark_ready_to_complete("quest_mountain_trial"), "山道任务应可标记为可交付")
	assertions.assert_eq(quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "山道任务应进入可交付状态")
	assertions.assert_true(quest_system.complete_quest("quest_mountain_trial"), "可交付任务应可完成")
	assertions.assert_eq(quest_system.get_status("quest_mountain_trial"), "completed", "山道任务应完成")

	var save_system = SaveSystemScript.new()
	var payload = save_system.serialize_state({
		"map_state": map_state.to_dictionary(),
		"quests": quest_system.to_dictionary(),
	})
	var save_data = save_system.deserialize_state(payload)
	assertions.assert_eq(save_data.get("map_state", {}).get("current_map_id", ""), "mountain_pass", "存档应保留地图编号")
	assertions.assert_eq(save_data.get("quests", {}).get("quest_mountain_trial", ""), "completed", "存档应保留任务状态")
```

Modify `tests/run_tests.gd` to include `TestMapStateAndFlowScript`:

```gdscript
extends SceneTree

const TestAssertionsScript = preload("res://tests/support/test_assertions.gd")
const TestDataLoaderScript = preload("res://tests/test_data_loader.gd")
const TestDomainModelsScript = preload("res://tests/test_domain_models.gd")
const TestQuestAndDialogueScript = preload("res://tests/test_quest_and_dialogue.gd")
const TestCombatAndSaveScript = preload("res://tests/test_combat_and_save.gd")
const TestMapDataScript = preload("res://tests/test_map_data.gd")
const TestMapStateAndFlowScript = preload("res://tests/test_map_state_and_flow.gd")

func _initialize() -> void:
	var assertions = TestAssertionsScript.new()
	var suites: Array = [
		TestDataLoaderScript.new(),
		TestDomainModelsScript.new(),
		TestQuestAndDialogueScript.new(),
		TestCombatAndSaveScript.new(),
		TestMapDataScript.new(),
		TestMapStateAndFlowScript.new(),
	]

	for suite in suites:
		suite.run(assertions)

	for failure in assertions.failures:
		push_error(failure)

	if assertions.failures.is_empty():
		print("测试通过：%d 个测试套件" % suites.size())
		quit(0)
	else:
		print("测试失败：%d 个问题" % assertions.failures.size())
		quit(1)
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 测试失败，错误原因包含无法加载 `res://scripts/domain/map_state.gd` 或 `mark_ready_to_complete` 不存在。

- [ ] **Step 3: 创建 `MapState`**

Create `scripts/domain/map_state.gd`:

```gdscript
class_name MapState
extends RefCounted

var current_map_id: String = "mountain_pass"
var player_position: Vector2 = Vector2(160, 320)
var resolved_objects: Array[String] = []
var reward_claims: Dictionary = {}

func set_player_position(next_position: Vector2) -> void:
	player_position = next_position

func mark_object_resolved(object_id: String) -> void:
	if object_id.is_empty():
		return
	if not resolved_objects.has(object_id):
		resolved_objects.append(object_id)

func is_object_resolved(object_id: String) -> bool:
	return resolved_objects.has(object_id)

func mark_reward_claimed(reward_id: String) -> void:
	if reward_id.is_empty():
		return
	reward_claims[reward_id] = true

func is_reward_claimed(reward_id: String) -> bool:
	return bool(reward_claims.get(reward_id, false))

func to_dictionary() -> Dictionary:
	return {
		"current_map_id": current_map_id,
		"player_position": {
			"x": player_position.x,
			"y": player_position.y,
		},
		"resolved_objects": resolved_objects.duplicate(),
		"reward_claims": reward_claims.duplicate(true),
	}

func from_dictionary(data: Dictionary) -> void:
	current_map_id = str(data.get("current_map_id", "mountain_pass"))
	var position = data.get("player_position", {})
	player_position = Vector2(
		float(position.get("x", 160.0)),
		float(position.get("y", 320.0))
	)
	resolved_objects = _to_string_array(data.get("resolved_objects", []))
	reward_claims = data.get("reward_claims", {}).duplicate(true)

func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
```

- [ ] **Step 4: 扩展 `QuestSystem`**

Replace `scripts/systems/quest_system.gd` with:

```gdscript
extends RefCounted

const STATUS_NOT_STARTED := "not_started"
const STATUS_ACTIVE := "active"
const STATUS_READY_TO_COMPLETE := "ready_to_complete"
const STATUS_COMPLETED := "completed"

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

func get_status(quest_id: String) -> String:
	return str(quest_status.get(quest_id, STATUS_NOT_STARTED))

func to_dictionary() -> Dictionary:
	return quest_status.duplicate(true)

func from_dictionary(data: Dictionary) -> void:
	quest_status = data.duplicate(true)
```

- [ ] **Step 5: 更新旧任务测试，锁定兼容行为**

Modify `tests/test_quest_and_dialogue.gd`:

```gdscript
extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const QuestSystemScript = preload("res://scripts/systems/quest_system.gd")
const DialogueSystemScript = preload("res://scripts/systems/dialogue_system.gd")

func run(assertions) -> void:
	var quest_system = QuestSystemScript.new()
	assertions.assert_eq(quest_system.get_status("quest_first_step"), "not_started", "未接任务应返回未开始")
	assertions.assert_true(quest_system.start_quest("quest_first_step"), "开始新任务应返回成功")
	assertions.assert_eq(quest_system.get_status("quest_first_step"), "active", "开始后任务应处于进行中")
	assertions.assert_true(quest_system.complete_quest("quest_first_step"), "完成进行中的任务应返回成功")
	assertions.assert_eq(quest_system.get_status("quest_first_step"), "completed", "完成后任务应处于已完成")
	assertions.assert_true(not quest_system.start_quest("quest_first_step"), "已完成任务不应重新开始")

	var mountain_quest = QuestSystemScript.new()
	assertions.assert_true(mountain_quest.start_quest("quest_mountain_trial"), "山道试剑应可开始")
	assertions.assert_true(mountain_quest.mark_ready_to_complete("quest_mountain_trial"), "山道试剑应可标记为可交付")
	assertions.assert_true(mountain_quest.complete_quest("quest_mountain_trial"), "山道试剑应可完成")

	var repository = DataRepositoryScript.new()
	repository.load_all()
	var dialogue_system = DialogueSystemScript.new()
	dialogue_system.set_repository(repository)
	var lines = dialogue_system.get_lines("intro_meet_master")
	assertions.assert_eq(lines.size(), 2, "对话应返回 2 行文本")
	assertions.assert_eq(lines[0].get("speaker", ""), "青衫客", "第一行说话人应正确")
	assertions.assert_eq(dialogue_system.get_title("missing_dialogue"), "", "缺失对话标题应返回空字符串")
	repository.free()
```

- [ ] **Step 6: 扩展 `GameState`**

Replace `scripts/core/game_state.gd` with:

```gdscript
extends Node

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const QuestSystemScript = preload("res://scripts/systems/quest_system.gd")
const MapStateScript = preload("res://scripts/domain/map_state.gd")

var party = PartyStateScript.new()
var quest_system = QuestSystemScript.new()
var map_state = MapStateScript.new()
var flags: Dictionary = {}
var battle_context: Dictionary = {}

func start_new_game() -> void:
	party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.add_item("herb_small", 1)
	quest_system = QuestSystemScript.new()
	map_state = MapStateScript.new()
	map_state.current_map_id = "mountain_pass"
	map_state.player_position = Vector2(160, 320)
	flags = {"current_map": "mountain_pass"}
	battle_context = {}
	if is_inside_tree() and has_node("/root/EventBus"):
		EventBus.game_started.emit()

func set_player_position(position: Vector2) -> void:
	map_state.set_player_position(position)

func resolve_map_object(object_id: String) -> void:
	map_state.mark_object_resolved(object_id)

func is_map_object_resolved(object_id: String) -> bool:
	return map_state.is_object_resolved(object_id)

func set_battle_context(context: Dictionary) -> void:
	battle_context = context.duplicate(true)

func consume_battle_context() -> Dictionary:
	var context = battle_context.duplicate(true)
	battle_context = {}
	return context

func peek_battle_context() -> Dictionary:
	return battle_context.duplicate(true)

func apply_battle_result(result: Dictionary) -> void:
	if bool(result.get("victory", false)):
		var object_id = str(result.get("source_object_id", ""))
		if not object_id.is_empty():
			resolve_map_object(object_id)
		var quest_id = str(result.get("quest_id", ""))
		if not quest_id.is_empty():
			quest_system.mark_ready_to_complete(quest_id)
	else:
		map_state.player_position = Vector2(160, 320)

func to_dictionary() -> Dictionary:
	return {
		"party": party.to_dictionary(),
		"quests": quest_system.to_dictionary(),
		"map_state": map_state.to_dictionary(),
		"flags": flags.duplicate(true),
	}

func from_dictionary(data: Dictionary) -> void:
	party = PartyStateScript.new()
	party.from_dictionary(data.get("party", {}))
	quest_system = QuestSystemScript.new()
	quest_system.from_dictionary(data.get("quests", {}))
	map_state = MapStateScript.new()
	map_state.from_dictionary(data.get("map_state", {}))
	flags = data.get("flags", {}).duplicate(true)
	battle_context = {}
```

- [ ] **Step 7: 运行测试并提交**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：6 个测试套件
```

Commit:

```powershell
git add scripts/domain/map_state.gd scripts/core/game_state.gd scripts/systems/quest_system.gd tests/run_tests.gd tests/test_quest_and_dialogue.gd tests/test_map_state_and_flow.gd
git commit -m "feat: 添加地图状态和任务流转"
```

---

### Task 3: 添加交互系统和地图对象生成器

**Files:**
- Create: `scripts/systems/interaction_system.gd`
- Create: `scripts/systems/map_object_spawner.gd`
- Create: `tests/test_interaction_system.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 写交互和生成器测试**

Create `tests/test_interaction_system.gd`:

```gdscript
extends RefCounted

const InteractionSystemScript = preload("res://scripts/systems/interaction_system.gd")
const MapObjectSpawnerScript = preload("res://scripts/systems/map_object_spawner.gd")

func run(assertions) -> void:
	var interaction_system = InteractionSystemScript.new()
	var objects = [
		{"id": "npc_qingshanke", "position": Vector2(100, 100), "radius": 64},
		{"id": "enemy_bandit_gate", "position": Vector2(260, 100), "radius": 48},
	]

	var nearby = interaction_system.find_nearest_in_range(Vector2(120, 100), objects)
	assertions.assert_eq(nearby.get("id", ""), "npc_qingshanke", "应找到范围内最近对象")

	var far = interaction_system.find_nearest_in_range(Vector2(500, 500), objects)
	assertions.assert_eq(far, {}, "远离对象时应返回空字典")

	assertions.assert_true(interaction_system.is_click_in_object(Vector2(110, 100), objects[0]), "鼠标点击对象范围内应命中")
	assertions.assert_true(not interaction_system.is_click_in_object(Vector2(220, 100), objects[0]), "鼠标点击对象范围外不应命中")

	var spawner = MapObjectSpawnerScript.new()
	var records = spawner.get_spawn_records({
		"objects": [
			{"id": "npc_qingshanke", "type": "npc", "position": {"x": 360, "y": 280}},
			{"id": "enemy_bandit_gate", "type": "battle_trigger", "position": {"x": 720, "y": 260}}
		]
	}, ["enemy_bandit_gate"])

	assertions.assert_eq(records.size(), 1, "已解决对象不应进入生成列表")
	assertions.assert_eq(records[0].get("id", ""), "npc_qingshanke", "未解决 NPC 应进入生成列表")
```

Modify `tests/run_tests.gd` to include `TestInteractionSystemScript`:

```gdscript
extends SceneTree

const TestAssertionsScript = preload("res://tests/support/test_assertions.gd")
const TestDataLoaderScript = preload("res://tests/test_data_loader.gd")
const TestDomainModelsScript = preload("res://tests/test_domain_models.gd")
const TestQuestAndDialogueScript = preload("res://tests/test_quest_and_dialogue.gd")
const TestCombatAndSaveScript = preload("res://tests/test_combat_and_save.gd")
const TestMapDataScript = preload("res://tests/test_map_data.gd")
const TestMapStateAndFlowScript = preload("res://tests/test_map_state_and_flow.gd")
const TestInteractionSystemScript = preload("res://tests/test_interaction_system.gd")

func _initialize() -> void:
	var assertions = TestAssertionsScript.new()
	var suites: Array = [
		TestDataLoaderScript.new(),
		TestDomainModelsScript.new(),
		TestQuestAndDialogueScript.new(),
		TestCombatAndSaveScript.new(),
		TestMapDataScript.new(),
		TestMapStateAndFlowScript.new(),
		TestInteractionSystemScript.new(),
	]

	for suite in suites:
		suite.run(assertions)

	for failure in assertions.failures:
		push_error(failure)

	if assertions.failures.is_empty():
		print("测试通过：%d 个测试套件" % suites.size())
		quit(0)
	else:
		print("测试失败：%d 个问题" % assertions.failures.size())
		quit(1)
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 测试失败，错误原因包含无法加载 `interaction_system.gd` 或 `map_object_spawner.gd`。

- [ ] **Step 3: 实现交互系统**

Create `scripts/systems/interaction_system.gd`:

```gdscript
extends RefCounted

func find_nearest_in_range(player_position: Vector2, objects: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for object in objects:
		var object_position = _read_position(object.get("position", Vector2.ZERO))
		var radius = float(object.get("radius", 48.0))
		var distance = player_position.distance_to(object_position)
		if distance <= radius and distance < best_distance:
			best = object
			best_distance = distance
	return best

func is_click_in_object(click_position: Vector2, object: Dictionary) -> bool:
	var object_position = _read_position(object.get("position", Vector2.ZERO))
	var radius = float(object.get("radius", 48.0))
	return click_position.distance_to(object_position) <= radius

func find_clicked_object(click_position: Vector2, objects: Array) -> Dictionary:
	for object in objects:
		if is_click_in_object(click_position, object):
			return object
	return {}

func can_interact(player_position: Vector2, object: Dictionary) -> bool:
	var object_position = _read_position(object.get("position", Vector2.ZERO))
	var radius = float(object.get("radius", 48.0))
	return player_position.distance_to(object_position) <= radius

func _read_position(value: Variant) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO
```

- [ ] **Step 4: 实现地图对象生成记录过滤**

Create `scripts/systems/map_object_spawner.gd`:

```gdscript
extends RefCounted

func get_spawn_records(map_data: Dictionary, resolved_objects: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for object in map_data.get("objects", []):
		var object_id = str(object.get("id", ""))
		if object_id.is_empty():
			continue
		if resolved_objects.has(object_id):
			continue
		result.append(object)
	return result

func read_position(object: Dictionary) -> Vector2:
	var position = object.get("position", {})
	if typeof(position) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(position.get("x", 0.0)), float(position.get("y", 0.0)))
```

- [ ] **Step 5: 运行测试并提交**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：7 个测试套件
```

Commit:

```powershell
git add scripts/systems/interaction_system.gd scripts/systems/map_object_spawner.gd tests/run_tests.gd tests/test_interaction_system.gd
git commit -m "feat: 添加地图交互逻辑"
```

---

### Task 4: 添加输入映射、主角控制器和原型像素动画

**Files:**
- Modify: `project.godot`
- Create: `scripts/scenes/simple_sprite_factory.gd`
- Create: `scripts/scenes/player_controller.gd`

- [ ] **Step 1: 修改 `project.godot` 输入动作**

Modify `project.godot` by adding this section after `[display]`:

```ini
[input]

move_up={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":87,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
move_down={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":83,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":65,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":68,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
interact={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":69,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
confirm={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194309,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":32,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
cancel={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194305,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
```

- [ ] **Step 2: 创建原型像素动画工厂**

Create `scripts/scenes/simple_sprite_factory.gd`:

```gdscript
extends RefCounted

static func create_frames(base_color: Color, trim_color: Color) -> SpriteFrames:
	var frames = SpriteFrames.new()
	for animation in ["idle_down", "idle_up", "idle_left", "idle_right", "walk_down", "walk_up", "walk_left", "walk_right"]:
		frames.add_animation(animation)
		frames.set_animation_speed(animation, 4.0)
		frames.set_animation_loop(animation, animation.begins_with("walk"))

	frames.add_frame("idle_down", _make_texture(base_color, trim_color, Vector2i(0, 0)))
	frames.add_frame("idle_up", _make_texture(base_color.darkened(0.15), trim_color, Vector2i(0, 0)))
	frames.add_frame("idle_left", _make_texture(base_color, trim_color.darkened(0.2), Vector2i(-1, 0)))
	frames.add_frame("idle_right", _make_texture(base_color, trim_color.darkened(0.2), Vector2i(1, 0)))

	for animation in ["walk_down", "walk_up", "walk_left", "walk_right"]:
		frames.add_frame(animation, _make_texture(base_color, trim_color, Vector2i(-1, 1)))
		frames.add_frame(animation, _make_texture(base_color.lightened(0.08), trim_color, Vector2i(1, 1)))

	return frames

static func _make_texture(base_color: Color, trim_color: Color, offset: Vector2i) -> Texture2D:
	var image = Image.create(24, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(8, 28):
		for x in range(7, 17):
			image.set_pixel(x, y, base_color)
	for y in range(3, 10):
		for x in range(8, 16):
			image.set_pixel(x + offset.x, y, trim_color)
	for y in range(26, 31):
		image.set_pixel(8 + offset.x, y, trim_color.darkened(0.35))
		image.set_pixel(15 + offset.x, y, trim_color.darkened(0.35))
	return ImageTexture.create_from_image(image)
```

- [ ] **Step 3: 创建主角控制器**

Create `scripts/scenes/player_controller.gd`:

```gdscript
extends CharacterBody2D

signal interact_requested(target)
signal position_changed(position: Vector2)

const SimpleSpriteFactory = preload("res://scripts/scenes/simple_sprite_factory.gd")

@export var speed: float = 160.0

var facing: String = "down"
var current_interactable = null
var sprite: AnimatedSprite2D

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = SimpleSpriteFactory.create_frames(Color("#2f6fdd"), Color("#f1d37b"))
	sprite.animation = "idle_down"
	add_child(sprite)

	var shape = CollisionShape2D.new()
	var capsule = CapsuleShape2D.new()
	capsule.radius = 8
	capsule.height = 22
	shape.shape = capsule
	shape.position = Vector2(0, 4)
	add_child(shape)

func _physics_process(_delta: float) -> void:
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vector * speed
	move_and_slide()
	_update_facing(input_vector)
	_update_animation(input_vector)
	position_changed.emit(global_position)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current_interactable != null:
		interact_requested.emit(current_interactable)

func set_current_interactable(target) -> void:
	current_interactable = target

func _update_facing(input_vector: Vector2) -> void:
	if input_vector == Vector2.ZERO:
		return
	if absf(input_vector.x) > absf(input_vector.y):
		facing = "right" if input_vector.x > 0.0 else "left"
	else:
		facing = "down" if input_vector.y > 0.0 else "up"

func _update_animation(input_vector: Vector2) -> void:
	var prefix = "idle" if input_vector == Vector2.ZERO else "walk"
	var next_animation = "%s_%s" % [prefix, facing]
	if sprite.animation != next_animation:
		sprite.play(next_animation)
```

- [ ] **Step 4: 验证项目加载并提交**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：7 个测试套件
```

Commit:

```powershell
git add project.godot scripts/scenes/simple_sprite_factory.gd scripts/scenes/player_controller.gd
git commit -m "feat: 添加连续移动输入和主角控制"
```

---

### Task 5: 创建山道场景、交互对象和基础 HUD

**Files:**
- Create: `scripts/scenes/map_interactable.gd`
- Create: `scripts/scenes/hud.gd`
- Create: `scripts/scenes/dialogue_box.gd`
- Create: `scripts/scenes/mountain_pass_screen.gd`
- Create: `scenes/mountain_pass.tscn`
- Modify: `scripts/scenes/main_menu_screen.gd`

- [ ] **Step 1: 创建交互对象脚本**

Create `scripts/scenes/map_interactable.gd`:

```gdscript
extends Area2D

signal clicked(interactable)
signal player_entered(interactable)
signal player_exited(interactable)

var record: Dictionary = {}
var label: Label

func setup(next_record: Dictionary) -> void:
	record = next_record.duplicate(true)
	name = str(record.get("id", "MapInteractable"))
	global_position = _read_position(record.get("position", {}))

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = float(record.get("radius", 48.0))
	shape.shape = circle
	add_child(shape)

	var visual = ColorRect.new()
	visual.size = Vector2(24, 24)
	visual.position = Vector2(-12, -12)
	visual.color = Color("#8d3b7a") if record.get("type", "") == "npc" else Color("#8f3b2f")
	add_child(visual)

	label = Label.new()
	label.text = str(record.get("name", ""))
	label.position = Vector2(-32, -36)
	label.size = Vector2(96, 24)
	add_child(label)

	input_event.connect(_on_input_event)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func get_interaction_text() -> String:
	return "按 E 与%s交互" % str(record.get("name", "此人"))

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)

func _on_body_entered(body: Node) -> void:
	if body.has_method("set_current_interactable"):
		player_entered.emit(self)

func _on_body_exited(body: Node) -> void:
	if body.has_method("set_current_interactable"):
		player_exited.emit(self)

func _read_position(value: Variant) -> Vector2:
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO
```

- [ ] **Step 2: 创建 HUD**

Create `scripts/scenes/hud.gd`:

```gdscript
extends CanvasLayer

var quest_label: Label
var prompt_label: Label
var message_label: Label

func _ready() -> void:
	quest_label = Label.new()
	quest_label.position = Vector2(24, 20)
	quest_label.size = Vector2(520, 32)
	add_child(quest_label)

	prompt_label = Label.new()
	prompt_label.position = Vector2(24, 640)
	prompt_label.size = Vector2(520, 32)
	add_child(prompt_label)

	message_label = Label.new()
	message_label.position = Vector2(24, 680)
	message_label.size = Vector2(800, 32)
	add_child(message_label)

	set_quest_text("")
	set_prompt("")
	show_message("")

func set_quest_text(text: String) -> void:
	quest_label.text = text

func set_prompt(text: String) -> void:
	prompt_label.text = text

func show_message(text: String) -> void:
	message_label.text = text
```

- [ ] **Step 3: 创建对话框**

Create `scripts/scenes/dialogue_box.gd`:

```gdscript
extends CanvasLayer

signal closed

var panel: Panel
var speaker_label: Label
var text_label: Label
var button: Button
var lines: Array = []
var index := 0

func _ready() -> void:
	panel = Panel.new()
	panel.position = Vector2(120, 500)
	panel.size = Vector2(1040, 160)
	add_child(panel)

	speaker_label = Label.new()
	speaker_label.position = Vector2(24, 16)
	speaker_label.size = Vector2(240, 28)
	panel.add_child(speaker_label)

	text_label = Label.new()
	text_label.position = Vector2(24, 52)
	text_label.size = Vector2(880, 56)
	panel.add_child(text_label)

	button = Button.new()
	button.text = "继续"
	button.position = Vector2(900, 104)
	button.pressed.connect(_next_line)
	panel.add_child(button)

	hide()

func open(next_lines: Array) -> void:
	lines = next_lines
	index = 0
	if lines.is_empty():
		lines = [{"speaker": "旁白", "text": "此人暂时无话可说。"}]
	_show_line()
	show()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("confirm"):
		_next_line()

func _show_line() -> void:
	var line = lines[index]
	speaker_label.text = str(line.get("speaker", ""))
	text_label.text = str(line.get("text", ""))

func _next_line() -> void:
	index += 1
	if index >= lines.size():
		hide()
		closed.emit()
		return
	_show_line()
```

- [ ] **Step 4: 创建山道场景脚本**

Create `scripts/scenes/mountain_pass_screen.gd`:

```gdscript
extends Node2D

const PlayerControllerScript = preload("res://scripts/scenes/player_controller.gd")
const MapInteractableScript = preload("res://scripts/scenes/map_interactable.gd")
const HudScript = preload("res://scripts/scenes/hud.gd")
const DialogueBoxScript = preload("res://scripts/scenes/dialogue_box.gd")
const DialogueSystemScript = preload("res://scripts/systems/dialogue_system.gd")
const MapObjectSpawnerScript = preload("res://scripts/systems/map_object_spawner.gd")

var player
var hud
var dialogue_box
var dialogue_system = DialogueSystemScript.new()
var spawner = MapObjectSpawnerScript.new()
var map_data: Dictionary = {}
var interactables: Array = []

func _ready() -> void:
	dialogue_system.set_repository(DataRepository)
	map_data = DataRepository.get_map("mountain_pass")
	if map_data.is_empty():
		push_error("无法读取山道地图配置。")
		map_data = {"spawn_position": {"x": 160, "y": 320}, "objects": []}

	_create_terrain()
	_create_player()
	_create_camera()
	_create_ui()
	_spawn_objects()
	_update_quest_text()

func _process(_delta: float) -> void:
	_update_nearest_interactable()

func _create_terrain() -> void:
	var terrain = TileMapLayer.new()
	terrain.name = "Terrain"
	add_child(terrain)

	var background = ColorRect.new()
	background.color = Color("#6f8f55")
	background.size = Vector2(1280, 720)
	background.position = Vector2(0, 0)
	add_child(background)
	move_child(background, 0)

	_add_obstacle(Rect2(0, 0, 1280, 24))
	_add_obstacle(Rect2(0, 696, 1280, 24))
	_add_obstacle(Rect2(0, 0, 24, 720))
	_add_obstacle(Rect2(1256, 0, 24, 720))
	_add_obstacle(Rect2(520, 120, 120, 120))
	_add_obstacle(Rect2(900, 380, 160, 120))

func _add_obstacle(rect: Rect2) -> void:
	var body = StaticBody2D.new()
	body.position = rect.position
	var shape = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.size / 2.0
	body.add_child(shape)
	add_child(body)

	var visual = ColorRect.new()
	visual.color = Color("#476f3f")
	visual.position = rect.position
	visual.size = rect.size
	add_child(visual)

func _create_player() -> void:
	player = PlayerControllerScript.new()
	player.name = "Player"
	player.global_position = _read_spawn_position()
	player.position_changed.connect(_on_player_position_changed)
	player.interact_requested.connect(_interact_with)
	add_child(player)

func _create_camera() -> void:
	var camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.make_current()
	player.add_child(camera)

func _create_ui() -> void:
	hud = HudScript.new()
	add_child(hud)
	dialogue_box = DialogueBoxScript.new()
	add_child(dialogue_box)

func _spawn_objects() -> void:
	var records = spawner.get_spawn_records(map_data, GameState.map_state.resolved_objects)
	for record in records:
		var interactable = MapInteractableScript.new()
		interactable.setup(record)
		interactable.clicked.connect(_on_interactable_clicked)
		interactable.player_entered.connect(_on_interactable_entered)
		interactable.player_exited.connect(_on_interactable_exited)
		interactables.append(interactable)
		add_child(interactable)

func _update_nearest_interactable() -> void:
	var nearest = null
	var best_distance := INF
	for interactable in interactables:
		var distance = player.global_position.distance_to(interactable.global_position)
		var radius = float(interactable.record.get("radius", 48.0))
		if distance <= radius and distance < best_distance:
			nearest = interactable
			best_distance = distance
	player.set_current_interactable(nearest)
	hud.set_prompt(nearest.get_interaction_text() if nearest != null else "")

func _interact_with(interactable) -> void:
	if interactable == null:
		return
	match str(interactable.record.get("type", "")):
		"npc":
			_talk_to_npc(interactable.record)
		"battle_trigger":
			_start_battle(interactable.record)

func _talk_to_npc(record: Dictionary) -> void:
	var quest_id = str(record.get("quest_id", ""))
	var status = GameState.quest_system.get_status(quest_id)
	if status == "not_started":
		GameState.quest_system.start_quest(quest_id)
		dialogue_box.open(dialogue_system.get_lines(str(record.get("dialogue_id", ""))))
		hud.show_message("任务开始：山道试剑")
	elif status == "ready_to_complete":
		GameState.quest_system.complete_quest(quest_id)
		GameState.party.add_item("herb_small", 1)
		GameState.map_state.mark_reward_claimed(quest_id)
		dialogue_box.open(dialogue_system.get_lines("mountain_pass_complete"))
		hud.show_message("获得：小还丹")
	else:
		dialogue_box.open(dialogue_system.get_lines(str(record.get("dialogue_id", ""))))
	_update_quest_text()

func _start_battle(record: Dictionary) -> void:
	var quest_id = str(record.get("quest_id", ""))
	if GameState.quest_system.get_status(quest_id) == "not_started":
		hud.show_message("先与青衫客交谈。")
		return
	GameState.set_battle_context({
		"enemy_id": str(record.get("actor_id", "")),
		"source_map_id": "mountain_pass",
		"source_object_id": str(record.get("id", "")),
		"quest_id": quest_id,
		"return_position": {
			"x": player.global_position.x,
			"y": player.global_position.y,
		},
	})
	SceneLoader.change_scene("res://scenes/battle.tscn")

func _on_interactable_clicked(interactable) -> void:
	var radius = float(interactable.record.get("radius", 48.0))
	if player.global_position.distance_to(interactable.global_position) <= radius:
		_interact_with(interactable)
	else:
		hud.show_message("距离太远。")

func _on_interactable_entered(interactable) -> void:
	hud.set_prompt(interactable.get_interaction_text())

func _on_interactable_exited(_interactable) -> void:
	hud.set_prompt("")

func _on_player_position_changed(position: Vector2) -> void:
	GameState.set_player_position(position)

func _update_quest_text() -> void:
	var status = GameState.quest_system.get_status("quest_mountain_trial")
	if status == "active":
		hud.set_quest_text("山道试剑：击退前方强人")
	elif status == "ready_to_complete":
		hud.set_quest_text("山道试剑：回去向青衫客复命")
	elif status == "completed":
		hud.set_quest_text("山道试剑：已完成")
	else:
		hud.set_quest_text("")

func _read_spawn_position() -> Vector2:
	if GameState.map_state.current_map_id == "mountain_pass":
		return GameState.map_state.player_position
	var spawn = map_data.get("spawn_position", {})
	return Vector2(float(spawn.get("x", 160.0)), float(spawn.get("y", 320.0)))
```

- [ ] **Step 5: 创建山道场景文件**

Create `scenes/mountain_pass.tscn`:

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/scenes/mountain_pass_screen.gd" id="1"]

[node name="MountainPass" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 6: 主菜单进入山道**

Modify `scripts/scenes/main_menu_screen.gd`:

```gdscript
extends Control

func _ready() -> void:
	var title = Label.new()
	title.text = "梁羽生群侠传"
	title.position = Vector2(64, 48)
	add_child(title)

	var start_button = Button.new()
	start_button.text = "开始新游戏"
	start_button.position = Vector2(64, 104)
	start_button.pressed.connect(_start_new_game)
	add_child(start_button)

func _start_new_game() -> void:
	GameState.start_new_game()
	SceneLoader.change_scene("res://scenes/mountain_pass.tscn")
```

- [ ] **Step 7: 验证项目加载并提交**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：7 个测试套件
```

Commit:

```powershell
git add scenes/mountain_pass.tscn scripts/scenes/main_menu_screen.gd scripts/scenes/map_interactable.gd scripts/scenes/hud.gd scripts/scenes/dialogue_box.gd scripts/scenes/mountain_pass_screen.gd
git commit -m "feat: 添加山道探索场景"
```

---

### Task 6: 接入战斗上下文和返回山道

**Files:**
- Modify: `scripts/scenes/battle_screen.gd`
- Modify: `scripts/core/event_bus.gd`

- [ ] **Step 1: 扩展事件总线**

Modify `scripts/core/event_bus.gd`:

```gdscript
extends Node

signal game_started
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal battle_started(enemy_id: String)
signal battle_finished(result: Dictionary)
signal save_completed(success: bool)
signal map_message(message: String)
```

- [ ] **Step 2: 修改战斗场景读取上下文**

Replace `scripts/scenes/battle_screen.gd` with:

```gdscript
extends Control

const ActorStateScript = preload("res://scripts/domain/actor_state.gd")
const MartialArtRecordScript = preload("res://scripts/domain/martial_art_record.gd")
const CombatSystemScript = preload("res://scripts/systems/combat_system.gd")

var output: Label
var context: Dictionary = {}

func _ready() -> void:
	context = GameState.peek_battle_context()

	output = Label.new()
	output.text = "战斗开始：%s" % DataRepository.get_actor(_enemy_id()).get("name", "山道强人")
	output.position = Vector2(32, 32)
	output.size = Vector2(900, 240)
	add_child(output)

	var resolve_button = Button.new()
	resolve_button.text = "基础剑法"
	resolve_button.position = Vector2(32, 300)
	resolve_button.pressed.connect(_resolve_battle)
	add_child(resolve_button)

	var back_button = Button.new()
	back_button.text = "暂退"
	back_button.position = Vector2(180, 300)
	back_button.pressed.connect(_retreat)
	add_child(back_button)

func _resolve_battle() -> void:
	var attacker = ActorStateScript.from_dictionary(DataRepository.get_actor("hero_yun"))
	var defender = ActorStateScript.from_dictionary(DataRepository.get_actor(_enemy_id()))
	var martial_art = MartialArtRecordScript.from_dictionary(DataRepository.get_martial_art("basic_sword"))
	var result = CombatSystemScript.new().resolve_duel(attacker, defender, martial_art)
	output.text = "\n".join(PackedStringArray(result.log))
	var payload = result.to_dictionary()
	payload["victory"] = result.winner_id == "hero_yun"
	payload["source_object_id"] = str(context.get("source_object_id", ""))
	payload["quest_id"] = str(context.get("quest_id", ""))
	GameState.apply_battle_result(payload)
	EventBus.battle_finished.emit(payload)
	call_deferred("_return_to_map")

func _retreat() -> void:
	GameState.apply_battle_result({
		"victory": false,
		"source_object_id": str(context.get("source_object_id", "")),
		"quest_id": str(context.get("quest_id", "")),
	})
	call_deferred("_return_to_map")

func _return_to_map() -> void:
	GameState.consume_battle_context()
	SceneLoader.change_scene("res://scenes/mountain_pass.tscn")

func _enemy_id() -> String:
	var enemy_id = str(context.get("enemy_id", "bandit_01"))
	if enemy_id.is_empty():
		return "bandit_01"
	return enemy_id
```

- [ ] **Step 3: 运行验证并提交**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：7 个测试套件
```

Commit:

```powershell
git add scripts/core/event_bus.gd scripts/scenes/battle_screen.gd
git commit -m "feat: 接入战斗返回山道流程"
```

---

### Task 7: 补充存档入口和读档恢复验证

**Files:**
- Create: `tests/test_save_map_state.gd`
- Modify: `tests/run_tests.gd`
- Modify: `scripts/core/game_state.gd`
- Modify: `scripts/scenes/mountain_pass_screen.gd`

- [ ] **Step 1: 写存档地图状态测试**

Create `tests/test_save_map_state.gd`:

```gdscript
extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")

func run(assertions) -> void:
	var state = GameStateScript.new()
	state.start_new_game()
	state.set_player_position(Vector2(444, 333))
	state.quest_system.start_quest("quest_mountain_trial")
	state.quest_system.mark_ready_to_complete("quest_mountain_trial")
	state.resolve_map_object("enemy_bandit_gate")

	var path = "user://test_mountain_pass_save.json"
	assertions.assert_true(state.save_to_path(path), "游戏状态应可写入存档文件")

	var restored = GameStateScript.new()
	assertions.assert_true(restored.load_from_path(path), "游戏状态应可从存档文件读取")

	assertions.assert_eq(restored.map_state.current_map_id, "mountain_pass", "读档应恢复地图编号")
	assertions.assert_eq(restored.map_state.player_position, Vector2(444, 333), "读档应恢复玩家坐标")
	assertions.assert_true(restored.map_state.is_object_resolved("enemy_bandit_gate"), "读档应恢复已解决敌人对象")
	assertions.assert_eq(restored.quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "读档应恢复任务状态")

	state.free()
	restored.free()
```

Modify `tests/run_tests.gd` to include `TestSaveMapStateScript`:

```gdscript
extends SceneTree

const TestAssertionsScript = preload("res://tests/support/test_assertions.gd")
const TestDataLoaderScript = preload("res://tests/test_data_loader.gd")
const TestDomainModelsScript = preload("res://tests/test_domain_models.gd")
const TestQuestAndDialogueScript = preload("res://tests/test_quest_and_dialogue.gd")
const TestCombatAndSaveScript = preload("res://tests/test_combat_and_save.gd")
const TestMapDataScript = preload("res://tests/test_map_data.gd")
const TestMapStateAndFlowScript = preload("res://tests/test_map_state_and_flow.gd")
const TestInteractionSystemScript = preload("res://tests/test_interaction_system.gd")
const TestSaveMapStateScript = preload("res://tests/test_save_map_state.gd")

func _initialize() -> void:
	var assertions = TestAssertionsScript.new()
	var suites: Array = [
		TestDataLoaderScript.new(),
		TestDomainModelsScript.new(),
		TestQuestAndDialogueScript.new(),
		TestCombatAndSaveScript.new(),
		TestMapDataScript.new(),
		TestMapStateAndFlowScript.new(),
		TestInteractionSystemScript.new(),
		TestSaveMapStateScript.new(),
	]

	for suite in suites:
		suite.run(assertions)

	for failure in assertions.failures:
		push_error(failure)

	if assertions.failures.is_empty():
		print("测试通过：%d 个测试套件" % suites.size())
		quit(0)
	else:
		print("测试失败：%d 个问题" % assertions.failures.size())
		quit(1)
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 测试失败，错误原因包含 `Nonexistent function 'save_to_path'` 或 `Nonexistent function 'load_from_path'`。

- [ ] **Step 3: 在 `GameState` 增加存读档方法**

Modify `scripts/core/game_state.gd` by adding `SaveSystemScript` near the other preload constants:

```gdscript
const SaveSystemScript = preload("res://scripts/systems/save_system.gd")
```

Add these methods before `to_dictionary()`:

```gdscript
func save_to_path(path: String) -> bool:
	return SaveSystemScript.new().save_to_path(path, to_dictionary())

func load_from_path(path: String) -> bool:
	var data = SaveSystemScript.new().load_from_path(path)
	if data.is_empty():
		return false
	from_dictionary(data)
	return true
```

- [ ] **Step 4: 在山道场景增加快捷存档和读档键**

Modify `scripts/scenes/mountain_pass_screen.gd` by adding this method:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		var success = GameState.save_to_path("user://save_01.json")
		hud.show_message("存档成功。" if success else "存档失败。")
```

If `_unhandled_input` already exists in the file during implementation, merge this branch into the existing method instead of creating a duplicate method. The final method must save on `cancel` and must not block `interact` or `confirm`.

- [ ] **Step 5: 运行测试并提交**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

Expected:

```text
测试通过：8 个测试套件
```

Commit:

```powershell
git add tests/run_tests.gd tests/test_save_map_state.gd scripts/core/game_state.gd scripts/scenes/mountain_pass_screen.gd
git commit -m "feat: 保存山道探索状态"
```

---

### Task 8: 最终验证和文档更新

**Files:**
- Modify: `README.md`
- Modify: `docs/godot-project-structure.md`

- [ ] **Step 1: 更新 README**

Replace `README.md` with:

```markdown
# 梁羽生群侠传

这是一个使用 Godot 4.6 和 GDScript 开发的免费单机武侠角色扮演游戏项目。

## 当前目标

当前阶段包含：

- Godot 4.6 项目配置。
- 数据加载、任务、对话、战斗和存档基础逻辑。
- 启动、主菜单、山道探索和战斗场景。
- 山道探索垂直切片：WASD 连续移动、NPC 交互、任务、战斗返回和奖励。

## 运行方式

安装 Godot 4.6 后，用 Godot 打开本仓库根目录。

如果项目本地 Godot 已下载，可运行：

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

如果 `godot` 命令已加入 PATH，可运行：

```powershell
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . --quit
```
```

- [ ] **Step 2: 更新项目结构文档**

Replace `docs/godot-project-structure.md` with:

```markdown
# Godot 项目结构

## 分层规则

- `scripts/domain/`：只放领域数据和规则对象，不依赖 Godot 场景节点。
- `scripts/systems/`：放可测试的游戏流程，例如数据、地图对象、交互、任务、对话、战斗和存档。
- `scripts/core/`：放全局服务，例如事件总线、游戏状态和场景切换。
- `scripts/scenes/`：放场景脚本，只负责展示、输入和连接系统。
- `data/`：放 JSON 内容数据，示例数据也必须使用中文。
- `scenes/`：放 Godot 场景文件。
- `tests/`：放 GDScript 逻辑测试。

## 中文规则

项目文档、界面文本、示例任务、示例对白、注释和提交说明优先使用中文。代码标识符、Godot API、路径、配置键和命令保留英文。

## 山道探索切片

山道探索切片使用 WASD 连续移动，不使用格子移动。地图地形放在 Godot 场景中，NPC 和战斗触发点由 `data/maps.json` 配置生成。鼠标只用于点击 NPC、交互对象和 UI，不支持点击地面自动寻路。

## 验证命令

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

如果本机没有配置项目本地 Godot 或 PATH 中的 `godot` 命令，先使用文件检查确认结构，再在安装 Godot 4.6 后运行测试。
```

- [ ] **Step 3: 运行最终自动验证**

Run:

```powershell
git status --short
Select-String -Path README.md,docs/godot-project-structure.md,data/*.json,scripts/**/*.gd,tests/*.gd -Pattern 'lorem|Hello World' -CaseSensitive:$false
Get-ChildItem data\*.json | ForEach-Object { $null = Get-Content -Raw -Path $_.FullName | ConvertFrom-Json; Write-Output "JSON_OK $($_.Name)" }
git diff --check HEAD
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

Expected:

```text
JSON_OK actors.json
JSON_OK dialogues.json
JSON_OK items.json
JSON_OK maps.json
JSON_OK martial_arts.json
JSON_OK quests.json
测试通过：8 个测试套件
```

`Select-String` and `git diff --check HEAD` should produce no issue output. `git status --short` may show only user-owned untracked `.spec-workflow/`.

- [ ] **Step 4: 人工场景验收**

Run the project in Godot editor or launch:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64.exe"
& $godot --path .
```

Manual checks:

```text
1. 主菜单点击“开始新游戏”进入山道。
2. WASD 可以连续移动，角色不是按格子跳转。
3. 主角碰到边界和障碍时不能穿过去。
4. 摄像机跟随主角。
5. 靠近青衫客显示交互提示。
6. E 键可以打开青衫客对话。
7. 鼠标点击青衫客可以打开对话。
8. 接到“山道试剑”后，任务摘要显示“击退前方强人”。
9. 进入强人触发范围后切到战斗场景。
10. 点击“基础剑法”后返回山道。
11. 返回后强人触发点不再出现。
12. 回到青衫客处可以交任务并获得“小还丹”。
13. 任务摘要显示“山道试剑：已完成”。
14. 按 Esc 显示“存档成功。”。
```

- [ ] **Step 5: Commit**

```powershell
git add README.md docs/godot-project-structure.md
git commit -m "docs: 更新山道探索运行说明"
```

## 自检记录

- Spec 覆盖：本计划覆盖连续移动、`TileMapLayer` 山道场景、NPC 交互、鼠标点击交互、山道试剑任务、独立战斗场景、战斗回流、奖励、地图对象状态和存档恢复。
- 范围控制：本计划不实现点击地面寻路、不实现背包界面、不实现角色面板、不实现多地图、不引入外部插件。
- 类型一致性：地图编号统一使用 `mountain_pass`，任务编号统一使用 `quest_mountain_trial`，NPC 对象编号统一使用 `npc_qingshanke`，敌人触发对象编号统一使用 `enemy_bandit_gate`。
- 测试路径：新增测试全部接入 `tests/run_tests.gd`，最终预期为 8 个测试套件。
