# Godot 基础框架 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建一个 Godot 4.6 / GDScript / 2D 单机武侠角色扮演游戏基础框架，支持数据加载、任务、对话、战斗、存档和最小场景流转。

**Architecture:** 项目采用“领域逻辑、系统流程、场景表现”分层。`scripts/domain/` 只保存规则数据结构，`scripts/systems/` 负责可测试流程，`scripts/core/` 负责全局状态和 Godot 接线，`scenes/` 只承担画面入口。

**Tech Stack:** Godot 4.6、GDScript、JSON 数据文件、Godot 无头脚本测试、PowerShell 验证命令。

---

## 范围检查

本计划只实现基础框架，不制作最终美术、完整地图、完整战斗规则或正式剧情内容。所有用户可见文本、示例剧情、示例对白、文档和注释优先使用中文；代码标识符、Godot API、路径和配置键保留英文。

## 文件结构

```text
project.godot                       # Godot 项目配置
.gitignore                          # Godot 与本地生成物忽略规则
README.md                           # 中文项目入口说明
data/actors.json                    # 示例角色数据
data/items.json                     # 示例物品数据
data/martial_arts.json              # 示例武学数据
data/quests.json                    # 示例任务数据
data/dialogues.json                 # 示例对话数据
docs/godot-project-structure.md     # 中文开发结构说明
scenes/boot.tscn                    # 启动场景
scenes/main_menu.tscn               # 主菜单场景
scenes/world.tscn                   # 世界地图演示场景
scenes/battle.tscn                  # 战斗演示场景
scripts/core/event_bus.gd           # 全局事件总线
scripts/core/game_state.gd          # 全局游戏状态
scripts/core/scene_loader.gd        # 场景切换服务
scripts/domain/actor_state.gd       # 角色状态
scripts/domain/combat_result.gd     # 战斗结果
scripts/domain/item_record.gd       # 物品记录
scripts/domain/martial_art_record.gd # 武学记录
scripts/domain/party_state.gd       # 队伍状态
scripts/domain/quest_record.gd      # 任务记录
scripts/scenes/battle_screen.gd     # 战斗场景脚本
scripts/scenes/boot_screen.gd       # 启动场景脚本
scripts/scenes/main_menu_screen.gd  # 主菜单脚本
scripts/scenes/world_screen.gd      # 世界地图脚本
scripts/systems/combat_system.gd    # 战斗流程
scripts/systems/data_repository.gd  # JSON 数据仓库
scripts/systems/dialogue_system.gd  # 对话流程
scripts/systems/quest_system.gd     # 任务流程
scripts/systems/save_system.gd      # 存档流程
tests/run_tests.gd                  # 测试运行器
tests/support/test_assertions.gd    # 测试断言工具
tests/test_combat_and_save.gd       # 战斗与存档测试
tests/test_data_loader.gd           # 数据加载测试
tests/test_domain_models.gd         # 领域模型测试
tests/test_quest_and_dialogue.gd    # 任务与对话测试
```

---

### Task 1: 创建 Godot 项目外壳

**Files:**
- Create: `.gitignore`
- Create: `README.md`
- Create: `project.godot`
- Create directories: `data/`, `docs/`, `scenes/`, `scripts/core/`, `scripts/domain/`, `scripts/scenes/`, `scripts/systems/`, `tests/support/`

- [ ] **Step 1: 验证项目外壳尚未存在**

Run:

```powershell
Test-Path project.godot
Test-Path scenes
Test-Path scripts
```

Expected:

```text
False
False
False
```

- [ ] **Step 2: 创建目录**

Run:

```powershell
New-Item -ItemType Directory -Force -Path data,docs,scenes,scripts/core,scripts/domain,scripts/scenes,scripts/systems,tests/support
```

Expected: 命令退出码为 `0`，上述目录存在。

- [ ] **Step 3: 创建 `.gitignore`**

Create `.gitignore`:

```gitignore
.godot/
.import/
export.cfg
export_presets.cfg
*.translation
*.tmp
*.log
user://
```

- [ ] **Step 4: 创建 `project.godot`**

Create `project.godot`:

```ini
; Engine configuration file.
; Godot 4.6 项目配置。

config_version=5

[application]

config/name="梁羽生群侠传"
config/features=PackedStringArray("4.6")

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

- [ ] **Step 5: 创建 `README.md`**

Create `README.md`:

```markdown
# 梁羽生群侠传

这是一个使用 Godot 4.6 和 GDScript 开发的免费单机武侠角色扮演游戏项目。

## 当前目标

第一阶段只创建基础框架：

- 项目配置
- 数据加载
- 任务、对话、战斗、存档的最小逻辑
- 启动、主菜单、世界地图、战斗的最小场景流转

## 运行方式

安装 Godot 4.6 后，用 Godot 打开本仓库根目录。

如果 `godot` 命令已加入 PATH，可运行：

```powershell
godot --headless --path . -s tests/run_tests.gd
```
```

- [ ] **Step 6: 验证项目外壳**

Run:

```powershell
Test-Path project.godot
Test-Path README.md
Test-Path data
Test-Path scripts/systems
```

Expected:

```text
True
True
True
True
```

- [ ] **Step 7: Commit**

```powershell
git add .gitignore README.md project.godot data docs scenes scripts tests
git commit -m "feat: 创建 Godot 项目外壳"
```

---

### Task 2: 用测试驱动数据加载系统

**Files:**
- Create: `tests/support/test_assertions.gd`
- Create: `tests/run_tests.gd`
- Create: `tests/test_data_loader.gd`
- Create: `data/actors.json`
- Create: `data/items.json`
- Create: `data/martial_arts.json`
- Create: `data/quests.json`
- Create: `data/dialogues.json`
- Create: `scripts/systems/data_repository.gd`

- [ ] **Step 1: 写失败测试和测试运行器**

Create `tests/support/test_assertions.gd`:

```gdscript
extends RefCounted

var failures: Array[String] = []

func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s。期望：%s，实际：%s" % [message, str(expected), str(actual)])

func assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
```

Create `tests/run_tests.gd`:

```gdscript
extends SceneTree

const TestAssertionsScript = preload("res://tests/support/test_assertions.gd")
const TestDataLoaderScript = preload("res://tests/test_data_loader.gd")

func _init() -> void:
	var assertions = TestAssertionsScript.new()
	var suites: Array = [
		TestDataLoaderScript.new(),
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

Create `tests/test_data_loader.gd`:

```gdscript
extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	var content = repository.load_all()

	assertions.assert_eq(content.get("actors", []).size(), 2, "应加载 2 个示例角色")
	assertions.assert_eq(repository.get_actor("hero_yun").get("name", ""), "云游少侠", "应按编号读取角色")
	assertions.assert_eq(repository.get_martial_art("basic_sword").get("name", ""), "基础剑法", "应按编号读取武学")
	assertions.assert_eq(repository.get_dialogue("intro_meet_master").get("title", ""), "初入江湖", "应按编号读取对话")
	assertions.assert_eq(repository.get_actor("missing_id"), {}, "缺失角色编号应返回空字典")
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
godot --headless --path . -s tests/run_tests.gd
```

Expected: 命令退出码非 `0`，错误原因包含无法加载 `res://scripts/systems/data_repository.gd`。

If Godot 命令不可用，Run:

```powershell
Get-Command godot -ErrorAction SilentlyContinue
```

Expected: 没有输出时记录“本机未配置 Godot 命令”，继续完成文件实现，最终再做静态验证。

- [ ] **Step 3: 创建示例 JSON 数据**

Create `data/actors.json`:

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

Create `data/items.json`:

```json
[
  {
    "id": "herb_small",
    "name": "小还丹",
    "type": "consumable",
    "description": "恢复少量气血。",
    "value": 30
  },
  {
    "id": "iron_sword",
    "name": "铁剑",
    "type": "weapon",
    "description": "寻常江湖人常用的长剑。",
    "value": 120
  }
]
```

Create `data/martial_arts.json`:

```json
[
  {
    "id": "basic_sword",
    "name": "基础剑法",
    "school": "江湖",
    "power": 12,
    "cost": 3,
    "description": "入门剑招，胜在稳妥。"
  },
  {
    "id": "rough_fist",
    "name": "粗浅拳脚",
    "school": "江湖",
    "power": 7,
    "cost": 1,
    "description": "街头斗殴中磨出的拳脚。"
  }
]
```

Create `data/quests.json`:

```json
[
  {
    "id": "quest_first_step",
    "title": "初入江湖",
    "description": "向青衫客请教江湖规矩。",
    "start_dialogue": "intro_meet_master",
    "reward_items": ["herb_small"]
  }
]
```

Create `data/dialogues.json`:

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
  }
]
```

- [ ] **Step 4: 实现数据仓库**

Create `scripts/systems/data_repository.gd`:

```gdscript
extends Node

const DATA_FILES := {
	"actors": "res://data/actors.json",
	"items": "res://data/items.json",
	"martial_arts": "res://data/martial_arts.json",
	"quests": "res://data/quests.json",
	"dialogues": "res://data/dialogues.json",
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

- [ ] **Step 5: 运行测试并确认通过**

Run:

```powershell
godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：1 个测试套件
```

- [ ] **Step 6: Commit**

```powershell
git add data scripts/systems/data_repository.gd tests
git commit -m "feat: 添加数据加载系统"
```

---

### Task 3: 用测试驱动领域模型

**Files:**
- Modify: `tests/run_tests.gd`
- Create: `tests/test_domain_models.gd`
- Create: `scripts/domain/actor_state.gd`
- Create: `scripts/domain/combat_result.gd`
- Create: `scripts/domain/item_record.gd`
- Create: `scripts/domain/martial_art_record.gd`
- Create: `scripts/domain/party_state.gd`
- Create: `scripts/domain/quest_record.gd`

- [ ] **Step 1: 写失败测试并接入运行器**

Modify `tests/run_tests.gd`:

```gdscript
extends SceneTree

const TestAssertionsScript = preload("res://tests/support/test_assertions.gd")
const TestDataLoaderScript = preload("res://tests/test_data_loader.gd")
const TestDomainModelsScript = preload("res://tests/test_domain_models.gd")

func _init() -> void:
	var assertions = TestAssertionsScript.new()
	var suites: Array = [
		TestDataLoaderScript.new(),
		TestDomainModelsScript.new(),
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

Create `tests/test_domain_models.gd`:

```gdscript
extends RefCounted

const ActorStateScript = preload("res://scripts/domain/actor_state.gd")
const ItemRecordScript = preload("res://scripts/domain/item_record.gd")
const MartialArtRecordScript = preload("res://scripts/domain/martial_art_record.gd")
const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const QuestRecordScript = preload("res://scripts/domain/quest_record.gd")

func run(assertions) -> void:
	var actor = ActorStateScript.from_dictionary({
		"id": "hero_yun",
		"name": "云游少侠",
		"level": 2,
		"hp": 80,
		"max_hp": 120,
		"attack": 18,
		"defense": 8,
		"martial_arts": ["basic_sword"],
	})
	assertions.assert_eq(actor.id, "hero_yun", "角色应保存编号")
	assertions.assert_true(actor.is_alive(), "气血大于 0 时角色应存活")
	assertions.assert_eq(actor.to_dictionary().get("name", ""), "云游少侠", "角色应能序列化")

	var item = ItemRecordScript.from_dictionary({
		"id": "herb_small",
		"name": "小还丹",
		"type": "consumable",
		"description": "恢复少量气血。",
		"value": 30,
	})
	assertions.assert_eq(item.name, "小还丹", "物品应保存名称")

	var martial_art = MartialArtRecordScript.from_dictionary({
		"id": "basic_sword",
		"name": "基础剑法",
		"school": "江湖",
		"power": 12,
		"cost": 3,
		"description": "入门剑招，胜在稳妥。",
	})
	assertions.assert_eq(martial_art.power, 12, "武学应保存威力")

	var quest = QuestRecordScript.from_dictionary({
		"id": "quest_first_step",
		"title": "初入江湖",
		"description": "向青衫客请教江湖规矩。",
		"start_dialogue": "intro_meet_master",
		"reward_items": ["herb_small"],
	})
	assertions.assert_eq(quest.reward_items[0], "herb_small", "任务应保存奖励物品")

	var party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.add_member("hero_yun")
	party.add_item("herb_small", 2)
	assertions.assert_eq(party.members.size(), 1, "队伍不应重复加入同一角色")
	assertions.assert_eq(party.inventory.get("herb_small", 0), 2, "队伍背包应累计物品数量")
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
godot --headless --path . -s tests/run_tests.gd
```

Expected: 命令退出码非 `0`，错误原因包含无法加载 `scripts/domain/actor_state.gd`。

- [ ] **Step 3: 实现领域模型**

Create `scripts/domain/actor_state.gd`:

```gdscript
class_name ActorState
extends RefCounted

var id: String = ""
var name: String = ""
var level: int = 1
var hp: int = 1
var max_hp: int = 1
var attack: int = 1
var defense: int = 0
var martial_arts: Array[String] = []

static func from_dictionary(data: Dictionary) -> ActorState:
	var actor = ActorState.new()
	actor.id = str(data.get("id", ""))
	actor.name = str(data.get("name", ""))
	actor.level = int(data.get("level", 1))
	actor.hp = int(data.get("hp", 1))
	actor.max_hp = int(data.get("max_hp", actor.hp))
	actor.attack = int(data.get("attack", 1))
	actor.defense = int(data.get("defense", 0))
	actor.martial_arts.assign(data.get("martial_arts", []))
	return actor

func is_alive() -> bool:
	return hp > 0

func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"level": level,
		"hp": hp,
		"max_hp": max_hp,
		"attack": attack,
		"defense": defense,
		"martial_arts": martial_arts.duplicate(),
	}
```

Create `scripts/domain/item_record.gd`:

```gdscript
class_name ItemRecord
extends RefCounted

var id: String = ""
var name: String = ""
var type: String = ""
var description: String = ""
var value: int = 0

static func from_dictionary(data: Dictionary) -> ItemRecord:
	var item = ItemRecord.new()
	item.id = str(data.get("id", ""))
	item.name = str(data.get("name", ""))
	item.type = str(data.get("type", ""))
	item.description = str(data.get("description", ""))
	item.value = int(data.get("value", 0))
	return item
```

Create `scripts/domain/martial_art_record.gd`:

```gdscript
class_name MartialArtRecord
extends RefCounted

var id: String = ""
var name: String = ""
var school: String = ""
var power: int = 0
var cost: int = 0
var description: String = ""

static func from_dictionary(data: Dictionary) -> MartialArtRecord:
	var martial_art = MartialArtRecord.new()
	martial_art.id = str(data.get("id", ""))
	martial_art.name = str(data.get("name", ""))
	martial_art.school = str(data.get("school", ""))
	martial_art.power = int(data.get("power", 0))
	martial_art.cost = int(data.get("cost", 0))
	martial_art.description = str(data.get("description", ""))
	return martial_art
```

Create `scripts/domain/quest_record.gd`:

```gdscript
class_name QuestRecord
extends RefCounted

var id: String = ""
var title: String = ""
var description: String = ""
var start_dialogue: String = ""
var reward_items: Array[String] = []

static func from_dictionary(data: Dictionary) -> QuestRecord:
	var quest = QuestRecord.new()
	quest.id = str(data.get("id", ""))
	quest.title = str(data.get("title", ""))
	quest.description = str(data.get("description", ""))
	quest.start_dialogue = str(data.get("start_dialogue", ""))
	quest.reward_items.assign(data.get("reward_items", []))
	return quest
```

Create `scripts/domain/party_state.gd`:

```gdscript
class_name PartyState
extends RefCounted

var members: Array[String] = []
var inventory: Dictionary = {}

func add_member(actor_id: String) -> void:
	if actor_id.is_empty():
		return
	if not members.has(actor_id):
		members.append(actor_id)

func has_member(actor_id: String) -> bool:
	return members.has(actor_id)

func add_item(item_id: String, amount: int = 1) -> void:
	if item_id.is_empty() or amount <= 0:
		return
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount

func to_dictionary() -> Dictionary:
	return {
		"members": members.duplicate(),
		"inventory": inventory.duplicate(true),
	}

func from_dictionary(data: Dictionary) -> void:
	members.assign(data.get("members", []))
	inventory = data.get("inventory", {}).duplicate(true)
```

Create `scripts/domain/combat_result.gd`:

```gdscript
class_name CombatResult
extends RefCounted

var winner_id: String = ""
var loser_id: String = ""
var damage: int = 0
var rounds: int = 1
var log: Array[String] = []

func to_dictionary() -> Dictionary:
	return {
		"winner_id": winner_id,
		"loser_id": loser_id,
		"damage": damage,
		"rounds": rounds,
		"log": log.duplicate(),
	}
```

- [ ] **Step 4: 运行测试并确认通过**

Run:

```powershell
godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：2 个测试套件
```

- [ ] **Step 5: Commit**

```powershell
git add scripts/domain tests/run_tests.gd tests/test_domain_models.gd
git commit -m "feat: 添加领域模型"
```

---

### Task 4: 用测试驱动任务和对话系统

**Files:**
- Modify: `tests/run_tests.gd`
- Create: `tests/test_quest_and_dialogue.gd`
- Create: `scripts/systems/quest_system.gd`
- Create: `scripts/systems/dialogue_system.gd`

- [ ] **Step 1: 写失败测试并接入运行器**

Modify `tests/run_tests.gd`:

```gdscript
extends SceneTree

const TestAssertionsScript = preload("res://tests/support/test_assertions.gd")
const TestDataLoaderScript = preload("res://tests/test_data_loader.gd")
const TestDomainModelsScript = preload("res://tests/test_domain_models.gd")
const TestQuestAndDialogueScript = preload("res://tests/test_quest_and_dialogue.gd")

func _init() -> void:
	var assertions = TestAssertionsScript.new()
	var suites: Array = [
		TestDataLoaderScript.new(),
		TestDomainModelsScript.new(),
		TestQuestAndDialogueScript.new(),
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

Create `tests/test_quest_and_dialogue.gd`:

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

	var repository = DataRepositoryScript.new()
	repository.load_all()
	var dialogue_system = DialogueSystemScript.new()
	dialogue_system.set_repository(repository)
	var lines = dialogue_system.get_lines("intro_meet_master")
	assertions.assert_eq(lines.size(), 2, "对话应返回 2 行文本")
	assertions.assert_eq(lines[0].get("speaker", ""), "青衫客", "第一行说话人应正确")
	assertions.assert_eq(dialogue_system.get_title("missing_dialogue"), "", "缺失对话标题应返回空字符串")
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
godot --headless --path . -s tests/run_tests.gd
```

Expected: 命令退出码非 `0`，错误原因包含无法加载 `scripts/systems/quest_system.gd`。

- [ ] **Step 3: 实现任务系统**

Create `scripts/systems/quest_system.gd`:

```gdscript
extends RefCounted

const STATUS_NOT_STARTED := "not_started"
const STATUS_ACTIVE := "active"
const STATUS_COMPLETED := "completed"

var quest_status: Dictionary = {}

func start_quest(quest_id: String) -> bool:
	if quest_id.is_empty():
		return false
	if get_status(quest_id) != STATUS_NOT_STARTED:
		return false
	quest_status[quest_id] = STATUS_ACTIVE
	return true

func complete_quest(quest_id: String) -> bool:
	if get_status(quest_id) != STATUS_ACTIVE:
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

- [ ] **Step 4: 实现对话系统**

Create `scripts/systems/dialogue_system.gd`:

```gdscript
extends RefCounted

var repository: Node = null

func set_repository(next_repository: Node) -> void:
	repository = next_repository

func get_title(dialogue_id: String) -> String:
	var dialogue = _get_dialogue(dialogue_id)
	return str(dialogue.get("title", ""))

func get_lines(dialogue_id: String) -> Array:
	var dialogue = _get_dialogue(dialogue_id)
	return dialogue.get("lines", [])

func _get_dialogue(dialogue_id: String) -> Dictionary:
	if repository == null or dialogue_id.is_empty():
		return {}
	if repository.has_method("get_dialogue"):
		return repository.get_dialogue(dialogue_id)
	return {}
```

- [ ] **Step 5: 运行测试并确认通过**

Run:

```powershell
godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：3 个测试套件
```

- [ ] **Step 6: Commit**

```powershell
git add scripts/systems/quest_system.gd scripts/systems/dialogue_system.gd tests/run_tests.gd tests/test_quest_and_dialogue.gd
git commit -m "feat: 添加任务和对话系统"
```

---

### Task 5: 用测试驱动战斗和存档系统

**Files:**
- Modify: `tests/run_tests.gd`
- Create: `tests/test_combat_and_save.gd`
- Create: `scripts/systems/combat_system.gd`
- Create: `scripts/systems/save_system.gd`

- [ ] **Step 1: 写失败测试并接入运行器**

Modify `tests/run_tests.gd`:

```gdscript
extends SceneTree

const TestAssertionsScript = preload("res://tests/support/test_assertions.gd")
const TestDataLoaderScript = preload("res://tests/test_data_loader.gd")
const TestDomainModelsScript = preload("res://tests/test_domain_models.gd")
const TestQuestAndDialogueScript = preload("res://tests/test_quest_and_dialogue.gd")
const TestCombatAndSaveScript = preload("res://tests/test_combat_and_save.gd")

func _init() -> void:
	var assertions = TestAssertionsScript.new()
	var suites: Array = [
		TestDataLoaderScript.new(),
		TestDomainModelsScript.new(),
		TestQuestAndDialogueScript.new(),
		TestCombatAndSaveScript.new(),
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

Create `tests/test_combat_and_save.gd`:

```gdscript
extends RefCounted

const ActorStateScript = preload("res://scripts/domain/actor_state.gd")
const MartialArtRecordScript = preload("res://scripts/domain/martial_art_record.gd")
const CombatSystemScript = preload("res://scripts/systems/combat_system.gd")
const SaveSystemScript = preload("res://scripts/systems/save_system.gd")

func run(assertions) -> void:
	var attacker = ActorStateScript.from_dictionary({
		"id": "hero_yun",
		"name": "云游少侠",
		"hp": 120,
		"max_hp": 120,
		"attack": 18,
		"defense": 8,
	})
	var defender = ActorStateScript.from_dictionary({
		"id": "bandit_01",
		"name": "山道强人",
		"hp": 20,
		"max_hp": 70,
		"attack": 12,
		"defense": 4,
	})
	var martial_art = MartialArtRecordScript.from_dictionary({
		"id": "basic_sword",
		"name": "基础剑法",
		"power": 12,
		"cost": 3,
	})
	var combat_system = CombatSystemScript.new()
	var result = combat_system.resolve_duel(attacker, defender, martial_art)
	assertions.assert_eq(result.damage, 26, "伤害应由攻击、武学威力和防御确定")
	assertions.assert_eq(result.winner_id, "hero_yun", "足以击败敌人时攻击者应获胜")
	assertions.assert_eq(result.loser_id, "bandit_01", "失败者编号应正确")

	var save_system = SaveSystemScript.new()
	var state = {
		"party": {"members": ["hero_yun"]},
		"quests": {"quest_first_step": "completed"},
	}
	var payload = save_system.serialize_state(state)
	assertions.assert_eq(payload.get("version", 0), 1, "存档应带版本号")
	assertions.assert_eq(save_system.deserialize_state(payload).get("quests", {}).get("quest_first_step", ""), "completed", "存档应可反序列化")
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
godot --headless --path . -s tests/run_tests.gd
```

Expected: 命令退出码非 `0`，错误原因包含无法加载 `scripts/systems/combat_system.gd`。

- [ ] **Step 3: 实现战斗系统**

Create `scripts/systems/combat_system.gd`:

```gdscript
extends RefCounted

const CombatResultScript = preload("res://scripts/domain/combat_result.gd")

func resolve_duel(attacker: ActorState, defender: ActorState, martial_art: MartialArtRecord):
	var result = CombatResultScript.new()
	var raw_damage = attacker.attack + martial_art.power - defender.defense
	result.damage = maxi(1, raw_damage)
	result.rounds = 1

	if result.damage >= defender.hp:
		result.winner_id = attacker.id
		result.loser_id = defender.id
		result.log.append("%s 使出%s，击败了%s。" % [attacker.name, martial_art.name, defender.name])
	else:
		result.winner_id = defender.id
		result.loser_id = attacker.id
		result.log.append("%s 使出%s，未能击败%s。" % [attacker.name, martial_art.name, defender.name])

	return result
```

- [ ] **Step 4: 实现存档系统**

Create `scripts/systems/save_system.gd`:

```gdscript
extends RefCounted

const SAVE_VERSION := 1

func serialize_state(state: Dictionary) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"state": state.duplicate(true),
	}

func deserialize_state(payload: Variant) -> Dictionary:
	var parsed = payload
	if typeof(payload) == TYPE_STRING:
		parsed = JSON.parse_string(payload)

	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if int(parsed.get("version", 0)) != SAVE_VERSION:
		return {}

	return parsed.get("state", {}).duplicate(true)

func save_to_path(path: String, state: Dictionary) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入存档：%s" % path)
		return false
	file.store_string(JSON.stringify(serialize_state(state), "\t"))
	return true

func load_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法读取存档：%s" % path)
		return {}
	return deserialize_state(file.get_as_text())
```

- [ ] **Step 5: 运行测试并确认通过**

Run:

```powershell
godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：4 个测试套件
```

- [ ] **Step 6: Commit**

```powershell
git add scripts/systems/combat_system.gd scripts/systems/save_system.gd tests/run_tests.gd tests/test_combat_and_save.gd
git commit -m "feat: 添加战斗和存档系统"
```

---

### Task 6: 接入全局服务、场景和开发文档

**Files:**
- Modify: `project.godot`
- Create: `scripts/core/event_bus.gd`
- Create: `scripts/core/game_state.gd`
- Create: `scripts/core/scene_loader.gd`
- Create: `scripts/scenes/boot_screen.gd`
- Create: `scripts/scenes/main_menu_screen.gd`
- Create: `scripts/scenes/world_screen.gd`
- Create: `scripts/scenes/battle_screen.gd`
- Create: `scenes/boot.tscn`
- Create: `scenes/main_menu.tscn`
- Create: `scenes/world.tscn`
- Create: `scenes/battle.tscn`
- Create: `docs/godot-project-structure.md`

- [ ] **Step 1: 写文件检查并确认失败**

Run:

```powershell
Test-Path scenes/boot.tscn
Test-Path scripts/core/game_state.gd
Select-String -Path project.godot -Pattern 'run/main_scene'
```

Expected:

```text
False
False
```

第三条命令没有匹配结果。

- [ ] **Step 2: 修改 `project.godot`**

Modify `project.godot`:

```ini
; Engine configuration file.
; Godot 4.6 项目配置。

config_version=5

[application]

config/name="梁羽生群侠传"
run/main_scene="res://scenes/boot.tscn"
config/features=PackedStringArray("4.6")

[autoload]

EventBus="*res://scripts/core/event_bus.gd"
GameState="*res://scripts/core/game_state.gd"
DataRepository="*res://scripts/systems/data_repository.gd"
SceneLoader="*res://scripts/core/scene_loader.gd"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

- [ ] **Step 3: 创建核心服务**

Create `scripts/core/event_bus.gd`:

```gdscript
extends Node

signal game_started
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal battle_started(enemy_id: String)
signal battle_finished(result: Dictionary)
signal save_completed(success: bool)
```

Create `scripts/core/game_state.gd`:

```gdscript
extends Node

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const QuestSystemScript = preload("res://scripts/systems/quest_system.gd")

var party = PartyStateScript.new()
var quest_system = QuestSystemScript.new()
var flags: Dictionary = {}

func start_new_game() -> void:
	party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.add_item("herb_small", 1)
	quest_system = QuestSystemScript.new()
	flags = {"current_map": "world"}
	if has_node("/root/EventBus"):
		EventBus.game_started.emit()

func to_dictionary() -> Dictionary:
	return {
		"party": party.to_dictionary(),
		"quests": quest_system.to_dictionary(),
		"flags": flags.duplicate(true),
	}

func from_dictionary(data: Dictionary) -> void:
	party = PartyStateScript.new()
	party.from_dictionary(data.get("party", {}))
	quest_system = QuestSystemScript.new()
	quest_system.from_dictionary(data.get("quests", {}))
	flags = data.get("flags", {}).duplicate(true)
```

Create `scripts/core/scene_loader.gd`:

```gdscript
extends Node

func change_scene(path: String) -> bool:
	var error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("无法切换场景：%s，错误码：%d" % [path, error])
		return false
	return true
```

- [ ] **Step 4: 创建场景脚本**

Create `scripts/scenes/boot_screen.gd`:

```gdscript
extends Control

func _ready() -> void:
	var label = Label.new()
	label.text = "正在载入江湖..."
	label.position = Vector2(32, 32)
	add_child(label)

	if has_node("/root/DataRepository"):
		DataRepository.load_all()

	call_deferred("_go_to_main_menu")

func _go_to_main_menu() -> void:
	SceneLoader.change_scene("res://scenes/main_menu.tscn")
```

Create `scripts/scenes/main_menu_screen.gd`:

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
	SceneLoader.change_scene("res://scenes/world.tscn")
```

Create `scripts/scenes/world_screen.gd`:

```gdscript
extends Control

const DialogueSystemScript = preload("res://scripts/systems/dialogue_system.gd")

var dialogue_system = DialogueSystemScript.new()
var output: Label

func _ready() -> void:
	dialogue_system.set_repository(DataRepository)

	output = Label.new()
	output.text = "世界地图：山道"
	output.position = Vector2(32, 32)
	output.size = Vector2(900, 240)
	add_child(output)

	var dialogue_button = Button.new()
	dialogue_button.text = "请教青衫客"
	dialogue_button.position = Vector2(32, 300)
	dialogue_button.pressed.connect(_show_dialogue)
	add_child(dialogue_button)

	var battle_button = Button.new()
	battle_button.text = "进入战斗"
	battle_button.position = Vector2(180, 300)
	battle_button.pressed.connect(_start_battle)
	add_child(battle_button)

func _show_dialogue() -> void:
	var lines = dialogue_system.get_lines("intro_meet_master")
	var text_lines: Array[String] = ["世界地图：山道"]
	for line in lines:
		text_lines.append("%s：%s" % [line.get("speaker", ""), line.get("text", "")])
	GameState.quest_system.start_quest("quest_first_step")
	output.text = "\n".join(text_lines)

func _start_battle() -> void:
	EventBus.battle_started.emit("bandit_01")
	SceneLoader.change_scene("res://scenes/battle.tscn")
```

Create `scripts/scenes/battle_screen.gd`:

```gdscript
extends Control

const ActorStateScript = preload("res://scripts/domain/actor_state.gd")
const MartialArtRecordScript = preload("res://scripts/domain/martial_art_record.gd")
const CombatSystemScript = preload("res://scripts/systems/combat_system.gd")

var output: Label

func _ready() -> void:
	output = Label.new()
	output.text = "战斗开始"
	output.position = Vector2(32, 32)
	output.size = Vector2(900, 240)
	add_child(output)

	var resolve_button = Button.new()
	resolve_button.text = "结算战斗"
	resolve_button.position = Vector2(32, 300)
	resolve_button.pressed.connect(_resolve_battle)
	add_child(resolve_button)

	var back_button = Button.new()
	back_button.text = "返回山道"
	back_button.position = Vector2(180, 300)
	back_button.pressed.connect(func(): SceneLoader.change_scene("res://scenes/world.tscn"))
	add_child(back_button)

func _resolve_battle() -> void:
	var attacker = ActorStateScript.from_dictionary(DataRepository.get_actor("hero_yun"))
	var defender = ActorStateScript.from_dictionary(DataRepository.get_actor("bandit_01"))
	var martial_art = MartialArtRecordScript.from_dictionary(DataRepository.get_martial_art("basic_sword"))
	var result = CombatSystemScript.new().resolve_duel(attacker, defender, martial_art)
	output.text = "\n".join(result.log)
	EventBus.battle_finished.emit(result.to_dictionary())
```

- [ ] **Step 5: 创建 Godot 场景文件**

Create `scenes/boot.tscn`:

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/scenes/boot_screen.gd" id="1"]

[node name="Boot" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

Create `scenes/main_menu.tscn`:

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/scenes/main_menu_screen.gd" id="1"]

[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

Create `scenes/world.tscn`:

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/scenes/world_screen.gd" id="1"]

[node name="World" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

Create `scenes/battle.tscn`:

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/scenes/battle_screen.gd" id="1"]

[node name="Battle" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

- [ ] **Step 6: 创建结构文档**

Create `docs/godot-project-structure.md`:

```markdown
# Godot 项目结构

## 分层规则

- `scripts/domain/`：只放领域数据和规则对象，不依赖 Godot 场景节点。
- `scripts/systems/`：放可测试的游戏流程，例如数据、任务、对话、战斗和存档。
- `scripts/core/`：放全局服务，例如事件总线、游戏状态和场景切换。
- `scripts/scenes/`：放场景脚本，只负责展示和用户输入。
- `data/`：放 JSON 内容数据，示例数据也必须使用中文。
- `tests/`：放 GDScript 逻辑测试。

## 中文规则

项目文档、界面文本、示例任务、示例对白、注释和提交说明优先使用中文。代码标识符、Godot API、路径、配置键和命令保留英文。

## 验证命令

```powershell
godot --headless --path . -s tests/run_tests.gd
```

如果本机没有配置 `godot` 命令，先使用文件检查确认结构，再在安装 Godot 4.6 后运行测试。
```

- [ ] **Step 7: 验证场景和全局接线**

Run:

```powershell
Test-Path scenes/boot.tscn
Test-Path scenes/main_menu.tscn
Test-Path scenes/world.tscn
Test-Path scenes/battle.tscn
Select-String -Path project.godot -Pattern 'run/main_scene="res://scenes/boot.tscn"'
Select-String -Path project.godot -Pattern 'GameState="\\*res://scripts/core/game_state.gd"'
```

Expected:

```text
True
True
True
True
```

两个 `Select-String` 命令都应输出匹配行。

- [ ] **Step 8: 运行完整测试**

Run:

```powershell
godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：4 个测试套件
```

- [ ] **Step 9: 验证项目可无头加载**

Run:

```powershell
godot --headless --path . --quit
```

Expected: 命令退出码为 `0`，输出中没有脚本解析错误。

- [ ] **Step 10: Commit**

```powershell
git add project.godot scenes scripts/core scripts/scenes docs/godot-project-structure.md
git commit -m "feat: 接入 Godot 场景和全局服务"
```

---

## 最终验证

- [ ] **Step 1: 检查工作区**

Run:

```powershell
git status --short
```

Expected: 只允许出现用户已有的未跟踪 `.spec-workflow/`，不应有本计划创建文件的未提交改动。

- [ ] **Step 2: 检查中文规则**

Run:

```powershell
Select-String -Path README.md,docs/godot-project-structure.md,data/*.json,scripts/**/*.gd -Pattern '待办|占位文本|lorem|Hello World' -CaseSensitive:$false
```

Expected: 没有匹配结果。

- [ ] **Step 3: 运行测试**

Run:

```powershell
godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：4 个测试套件
```

- [ ] **Step 4: 验证 Godot 项目加载**

Run:

```powershell
godot --headless --path . --quit
```

Expected: 命令退出码为 `0`。

如果 `godot` 不在 PATH 中，最终报告必须明确写出：未能运行 Godot 无头测试和项目加载验证；已完成文件结构检查和静态内容检查。

## 自检记录

- 规格覆盖：项目配置、启动场景、核心服务、领域类、系统类、示例 JSON、测试、开发文档均有对应任务。
- 类型一致性：测试使用的 `load_all`、`get_actor`、`from_dictionary`、`to_dictionary`、`start_quest`、`complete_quest`、`resolve_duel`、`serialize_state` 和 `deserialize_state` 均在计划中定义。
- 执行边界：本计划不修改 `.spec-workflow/`，不引入外部插件，不制作正式内容。
