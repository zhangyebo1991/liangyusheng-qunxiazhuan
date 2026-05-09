# 基础回合战斗与武学成长切片 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将山道强人战从一次性结算升级为可多回合操作、可用药、可失败、可记录基础剑法熟练度并能存档恢复的战斗切片。

**Architecture:** 沿用“领域逻辑、系统流程、场景表现”分层。新增 `BattleState` 保存战斗运行时状态，扩展 `CombatSystem` 处理回合行动、敌人反击、用药、暂退和胜负，`battle_screen.gd` 只负责按钮、气血和日志显示。`GameState` 负责战斗结果回流、主角气血和武学熟练度持久化。

**Tech Stack:** Godot 4.6、GDScript、JSON 数据文件、Godot 无头脚本测试、PowerShell 验证命令。

---

## 范围检查

本计划实现 `docs/superpowers/specs/2026-05-09-turn-based-combat-growth-slice-design.md`。范围只包含单主角对单敌人的轻量回合战斗、战斗中小还丹、失败或暂退回流、基础剑法熟练度和存档恢复。不实现多队友、多敌人、内力、状态异常、装备属性、复杂 AI、战斗动画、角色等级或完整角色面板。

本计划不修改 `.spec-workflow/`、`.superpowers/` 或 `.tools/`。

验证命令优先使用项目本地 Godot：

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

## 文件结构

```text
data/actors.json                              # 提高 bandit_01 气血，确保强人战不是一击结束
data/martial_arts.json                       # 为基础剑法增加 proficiency_reward
docs/godot-project-structure.md              # 记录回合战斗和成长切片规则
README.md                                    # 更新当前目标
scripts/core/game_state.gd                   # 增加 martial_proficiency 和战斗结果气血/成长回流
scripts/domain/battle_state.gd               # 新增战斗运行时状态和结果序列化
scripts/domain/martial_art_record.gd         # 读取 proficiency_reward
scripts/scenes/battle_screen.gd              # 多回合战斗界面和按钮接线
scripts/systems/combat_system.gd             # 回合行动、伤害、反击、用药、暂退规则
tests/run_tests.gd                           # 接入新增测试套件
tests/test_battle_state.gd                   # BattleState 序列化测试
tests/test_combat_and_save.gd                # 更新旧战斗兼容和战斗结果回流测试
tests/test_domain_models.gd                  # 覆盖 MartialArtRecord proficiency_reward
tests/test_save_map_state.gd                 # 覆盖 martial_proficiency 存档恢复
tests/test_turn_based_combat_system.gd       # 回合战斗系统测试
```

---

### Task 1: 添加 BattleState 领域对象

**Files:**
- Create: `tests/test_battle_state.gd`
- Modify: `tests/run_tests.gd`
- Create: `scripts/domain/battle_state.gd`

- [ ] **Step 1: 写失败测试 `tests/test_battle_state.gd`**

Create `tests/test_battle_state.gd`:

```gdscript
extends RefCounted

const BattleStateScript = preload("res://scripts/domain/battle_state.gd")

func run(assertions) -> void:
	var battle = BattleStateScript.new()
	battle.hero_id = "hero_yun"
	battle.enemy_id = "bandit_01"
	battle.hero_hp = 90
	battle.hero_max_hp = 120
	battle.enemy_hp = 34
	battle.enemy_max_hp = 60
	battle.round = 2
	battle.source_map_id = "mountain_pass"
	battle.source_object_id = "enemy_bandit_gate"
	battle.quest_id = "quest_mountain_trial"
	battle.reward_martial_art_id = "basic_sword"
	battle.proficiency_reward = 1
	battle.log.append("第1回合：云游少侠使出基础剑法。")

	var serialized = battle.to_dictionary()
	assertions.assert_eq(serialized.get("hero_id", ""), "hero_yun", "战斗状态应保存主角编号")
	assertions.assert_eq(serialized.get("enemy_hp", 0), 34, "战斗状态应保存敌人气血")
	assertions.assert_eq(serialized.get("round", 0), 2, "战斗状态应保存回合数")
	assertions.assert_eq(serialized.get("log", []).size(), 1, "战斗状态应保存日志")

	var restored = BattleStateScript.new()
	restored.from_dictionary(serialized)
	assertions.assert_eq(restored.hero_id, "hero_yun", "战斗状态应恢复主角编号")
	assertions.assert_eq(restored.enemy_id, "bandit_01", "战斗状态应恢复敌人编号")
	assertions.assert_eq(restored.hero_hp, 90, "战斗状态应恢复主角气血")
	assertions.assert_eq(restored.enemy_hp, 34, "战斗状态应恢复敌人气血")
	assertions.assert_eq(restored.source_object_id, "enemy_bandit_gate", "战斗状态应恢复来源对象")
	assertions.assert_eq(restored.reward_martial_art_id, "basic_sword", "战斗状态应恢复奖励武学")

	restored.finish(true)
	var result = restored.to_result_dictionary()
	assertions.assert_true(bool(result.get("victory", false)), "胜利结果应标记 victory")
	assertions.assert_eq(result.get("hero_hp", 0), 90, "战斗结果应带回主角气血")
	assertions.assert_eq(result.get("source_object_id", ""), "enemy_bandit_gate", "战斗结果应带回来源对象")
	assertions.assert_eq(result.get("quest_id", ""), "quest_mountain_trial", "战斗结果应带回任务编号")
	assertions.assert_eq(result.get("martial_art_id", ""), "basic_sword", "战斗结果应带回成长武学")
	assertions.assert_eq(result.get("proficiency_reward", 0), 1, "战斗结果应带回熟练度奖励")
```

- [ ] **Step 2: 接入测试运行器并确认失败**

Replace `tests/run_tests.gd` with:

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
const TestMapTransitionSystemScript = preload("res://tests/test_map_transition_system.gd")
const TestInventorySystemScript = preload("res://tests/test_inventory_system.gd")
const TestHudInventoryScript = preload("res://tests/test_hud_inventory.gd")
const TestBattleStateScript = preload("res://tests/test_battle_state.gd")

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
		TestMapTransitionSystemScript.new(),
		TestInventorySystemScript.new(),
		TestHudInventoryScript.new(),
		TestBattleStateScript.new(),
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

Expected: FAIL，错误原因包含无法加载 `res://scripts/domain/battle_state.gd`。

- [ ] **Step 3: 创建 `BattleState`**

Create `scripts/domain/battle_state.gd`:

```gdscript
class_name BattleState
extends RefCounted

var hero_id: String = ""
var enemy_id: String = ""
var hero_hp: int = 1
var hero_max_hp: int = 1
var enemy_hp: int = 1
var enemy_max_hp: int = 1
var round: int = 1
var is_finished := false
var victory := false
var log: Array[String] = []
var source_map_id: String = "mountain_pass"
var source_object_id: String = ""
var quest_id: String = ""
var reward_martial_art_id: String = ""
var proficiency_reward: int = 0

func append_log(message: String) -> void:
	if message.is_empty():
		return
	log.append(message)

func finish(is_victory: bool) -> void:
	is_finished = true
	victory = is_victory

func to_result_dictionary() -> Dictionary:
	return {
		"victory": victory,
		"hero_hp": max(0, hero_hp),
		"source_map_id": source_map_id,
		"source_object_id": source_object_id,
		"quest_id": quest_id,
		"martial_art_id": reward_martial_art_id,
		"proficiency_reward": max(0, proficiency_reward),
		"log": log.duplicate(),
	}

func to_dictionary() -> Dictionary:
	return {
		"hero_id": hero_id,
		"enemy_id": enemy_id,
		"hero_hp": hero_hp,
		"hero_max_hp": hero_max_hp,
		"enemy_hp": enemy_hp,
		"enemy_max_hp": enemy_max_hp,
		"round": round,
		"is_finished": is_finished,
		"victory": victory,
		"log": log.duplicate(),
		"source_map_id": source_map_id,
		"source_object_id": source_object_id,
		"quest_id": quest_id,
		"reward_martial_art_id": reward_martial_art_id,
		"proficiency_reward": proficiency_reward,
	}

func from_dictionary(data: Dictionary) -> void:
	hero_id = str(data.get("hero_id", ""))
	enemy_id = str(data.get("enemy_id", ""))
	hero_hp = int(data.get("hero_hp", 1))
	hero_max_hp = int(data.get("hero_max_hp", max(1, hero_hp)))
	enemy_hp = int(data.get("enemy_hp", 1))
	enemy_max_hp = int(data.get("enemy_max_hp", max(1, enemy_hp)))
	round = max(1, int(data.get("round", 1)))
	is_finished = bool(data.get("is_finished", false))
	victory = bool(data.get("victory", false))
	log = _to_string_array(data.get("log", []))
	source_map_id = str(data.get("source_map_id", "mountain_pass"))
	source_object_id = str(data.get("source_object_id", ""))
	quest_id = str(data.get("quest_id", ""))
	reward_martial_art_id = str(data.get("reward_martial_art_id", ""))
	proficiency_reward = max(0, int(data.get("proficiency_reward", 0)))

func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
```

- [ ] **Step 4: 运行测试并提交**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：13 个测试套件
```

Commit:

```powershell
git add tests/run_tests.gd tests/test_battle_state.gd scripts/domain/battle_state.gd
git commit -m "feat: 添加战斗状态模型"
```

---

### Task 2: 扩展战斗数据和武学记录

**Files:**
- Modify: `tests/test_domain_models.gd`
- Modify: `tests/test_combat_and_save.gd`
- Modify: `scripts/domain/martial_art_record.gd`
- Modify: `data/actors.json`
- Modify: `data/martial_arts.json`

- [ ] **Step 1: 写失败测试和更新旧战斗期望**

Replace `tests/test_domain_models.gd` with:

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
		"effects": {"heal_hp": 30},
	})
	assertions.assert_eq(item.name, "小还丹", "物品应保存名称")
	assertions.assert_eq(item.effects.get("heal_hp", 0), 30, "物品应读取效果数据")

	var martial_art = MartialArtRecordScript.from_dictionary({
		"id": "basic_sword",
		"name": "基础剑法",
		"school": "江湖",
		"power": 12,
		"cost": 3,
		"description": "入门剑招，胜在稳妥。",
		"proficiency_reward": 1,
	})
	assertions.assert_eq(martial_art.power, 12, "武学应保存威力")
	assertions.assert_eq(martial_art.proficiency_reward, 1, "武学应保存熟练度奖励")

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
	assertions.assert_eq(party.get_item_count("herb_small"), 2, "队伍背包应累计物品数量")
	assertions.assert_true(party.has_item("herb_small", 2), "背包应能判断足够数量")
	assertions.assert_true(party.remove_item("herb_small", 1), "背包应能扣除已有物品")
	assertions.assert_eq(party.get_item_count("herb_small"), 1, "扣除后数量应减少")
	assertions.assert_true(not party.remove_item("herb_small", 2), "数量不足时不应扣除物品")
	assertions.assert_eq(party.get_item_count("herb_small"), 1, "扣除失败后数量应保持")
	assertions.assert_true(party.remove_item("herb_small", 1), "应能扣除最后一个物品")
	assertions.assert_eq(party.get_item_count("herb_small"), 0, "数量归零后查询应为 0")
	assertions.assert_true(not party.inventory.has("herb_small"), "数量归零后应从背包字典移除")
```

Replace `tests/test_combat_and_save.gd` with:

```gdscript
extends RefCounted

const ActorStateScript = preload("res://scripts/domain/actor_state.gd")
const MartialArtRecordScript = preload("res://scripts/domain/martial_art_record.gd")
const CombatSystemScript = preload("res://scripts/systems/combat_system.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
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
		"max_hp": 20,
		"attack": 12,
		"defense": 4,
	})
	var martial_art = MartialArtRecordScript.from_dictionary({
		"id": "basic_sword",
		"name": "基础剑法",
		"power": 12,
		"cost": 3,
		"proficiency_reward": 1,
	})
	var combat_system = CombatSystemScript.new()
	var result = combat_system.resolve_duel(attacker, defender, martial_art)
	assertions.assert_eq(result.damage, 26, "伤害应由攻击、武学威力和防御确定")
	assertions.assert_eq(result.winner_id, "hero_yun", "旧一次性结算在足以击败敌人时攻击者应获胜")
	assertions.assert_eq(result.loser_id, "bandit_01", "失败者编号应正确")

	var repository = DataRepositoryScript.new()
	repository.load_all()
	var configured_attacker = ActorStateScript.from_dictionary(repository.get_actor("hero_yun"))
	var configured_defender = ActorStateScript.from_dictionary(repository.get_actor("bandit_01"))
	var configured_martial_art = MartialArtRecordScript.from_dictionary(repository.get_martial_art("basic_sword"))
	var configured_result = combat_system.resolve_duel(configured_attacker, configured_defender, configured_martial_art)
	assertions.assert_eq(configured_result.damage, 26, "山道试剑配置仍应使用基础伤害公式")
	assertions.assert_eq(configured_result.winner_id, "bandit_01", "山道强人不应再被基础剑法一击击败")
	assertions.assert_eq(configured_martial_art.proficiency_reward, 1, "基础剑法应配置熟练度奖励")

	var game_state = GameStateScript.new()
	game_state.start_new_game()
	game_state.quest_system.start_quest("quest_mountain_trial")
	var payload = result.to_dictionary()
	payload["victory"] = result.winner_id == "hero_yun"
	payload["source_object_id"] = "enemy_bandit_gate"
	payload["quest_id"] = "quest_mountain_trial"
	game_state.apply_battle_result(payload)
	assertions.assert_true(game_state.is_map_object_resolved("enemy_bandit_gate"), "胜利后强人触发点应被标记为已解决")
	assertions.assert_eq(game_state.quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "胜利后山道任务应进入可交付状态")
	repository.free()
	game_state.free()

	var save_system = SaveSystemScript.new()
	var state = {
		"party": {"members": ["hero_yun"]},
		"quests": {"quest_first_step": "completed"},
	}
	var save_payload = save_system.serialize_state(state)
	assertions.assert_eq(save_payload.get("version", 0), 1, "存档应带版本号")
	assertions.assert_eq(save_system.deserialize_state(save_payload).get("quests", {}).get("quest_first_step", ""), "completed", "存档应可反序列化")
```

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL，错误原因包含 `Invalid get index 'proficiency_reward'` 或“山道强人不应再被基础剑法一击击败”。

- [ ] **Step 2: 扩展 `MartialArtRecord`**

Replace `scripts/domain/martial_art_record.gd` with:

```gdscript
class_name MartialArtRecord
extends RefCounted

var id: String = ""
var name: String = ""
var school: String = ""
var power: int = 0
var cost: int = 0
var description: String = ""
var proficiency_reward: int = 1

static func from_dictionary(data: Dictionary):
	var martial_art = new()
	martial_art.id = str(data.get("id", ""))
	martial_art.name = str(data.get("name", ""))
	martial_art.school = str(data.get("school", ""))
	martial_art.power = int(data.get("power", 0))
	martial_art.cost = int(data.get("cost", 0))
	martial_art.description = str(data.get("description", ""))
	martial_art.proficiency_reward = max(0, int(data.get("proficiency_reward", 1)))
	return martial_art
```

- [ ] **Step 3: 更新战斗数据**

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
    "hp": 60,
    "max_hp": 60,
    "attack": 12,
    "defense": 4,
    "martial_arts": ["rough_fist"]
  },
  {
    "id": "innkeeper_lu",
    "name": "陆掌柜",
    "level": 3,
    "hp": 160,
    "max_hp": 160,
    "attack": 14,
    "defense": 10,
    "martial_arts": ["basic_sword"]
  },
  {
    "id": "porter_chen",
    "name": "陈脚夫",
    "level": 2,
    "hp": 130,
    "max_hp": 130,
    "attack": 10,
    "defense": 8,
    "martial_arts": ["rough_fist"]
  }
]
```

Replace `data/martial_arts.json` with:

```json
[
  {
    "id": "basic_sword",
    "name": "基础剑法",
    "school": "江湖",
    "power": 12,
    "cost": 3,
    "description": "入门剑招，胜在稳妥。",
    "proficiency_reward": 1
  },
  {
    "id": "rough_fist",
    "name": "粗浅拳脚",
    "school": "江湖",
    "power": 7,
    "cost": 1,
    "description": "街头斗殴中磨出的拳脚。",
    "proficiency_reward": 0
  }
]
```

- [ ] **Step 4: 运行测试并提交**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：13 个测试套件
```

Commit:

```powershell
git add tests/test_domain_models.gd tests/test_combat_and_save.gd scripts/domain/martial_art_record.gd data/actors.json data/martial_arts.json
git commit -m "feat: 调整战斗数据和武学成长字段"
```

---

### Task 3: 扩展 GameState 战斗结果和熟练度存档

**Files:**
- Modify: `tests/test_combat_and_save.gd`
- Modify: `tests/test_save_map_state.gd`
- Modify: `scripts/core/game_state.gd`

- [ ] **Step 1: 写失败测试**

Replace `tests/test_combat_and_save.gd` with:

```gdscript
extends RefCounted

const ActorStateScript = preload("res://scripts/domain/actor_state.gd")
const MartialArtRecordScript = preload("res://scripts/domain/martial_art_record.gd")
const CombatSystemScript = preload("res://scripts/systems/combat_system.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
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
		"max_hp": 20,
		"attack": 12,
		"defense": 4,
	})
	var martial_art = MartialArtRecordScript.from_dictionary({
		"id": "basic_sword",
		"name": "基础剑法",
		"power": 12,
		"cost": 3,
		"proficiency_reward": 1,
	})
	var combat_system = CombatSystemScript.new()
	var result = combat_system.resolve_duel(attacker, defender, martial_art)
	assertions.assert_eq(result.damage, 26, "伤害应由攻击、武学威力和防御确定")
	assertions.assert_eq(result.winner_id, "hero_yun", "旧一次性结算在足以击败敌人时攻击者应获胜")
	assertions.assert_eq(result.loser_id, "bandit_01", "失败者编号应正确")

	var repository = DataRepositoryScript.new()
	repository.load_all()
	var configured_attacker = ActorStateScript.from_dictionary(repository.get_actor("hero_yun"))
	var configured_defender = ActorStateScript.from_dictionary(repository.get_actor("bandit_01"))
	var configured_martial_art = MartialArtRecordScript.from_dictionary(repository.get_martial_art("basic_sword"))
	var configured_result = combat_system.resolve_duel(configured_attacker, configured_defender, configured_martial_art)
	assertions.assert_eq(configured_result.damage, 26, "山道试剑配置仍应使用基础伤害公式")
	assertions.assert_eq(configured_result.winner_id, "bandit_01", "山道强人不应再被基础剑法一击击败")
	assertions.assert_eq(configured_martial_art.proficiency_reward, 1, "基础剑法应配置熟练度奖励")

	var game_state = GameStateScript.new()
	game_state.start_new_game()
	game_state.quest_system.start_quest("quest_mountain_trial")
	game_state.apply_battle_result({
		"victory": true,
		"hero_hp": 44,
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
		"martial_art_id": "basic_sword",
		"proficiency_reward": 1,
	})
	assertions.assert_true(game_state.is_map_object_resolved("enemy_bandit_gate"), "胜利后强人触发点应被标记为已解决")
	assertions.assert_eq(game_state.quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "胜利后山道任务应进入可交付状态")
	assertions.assert_eq(game_state.hero_hp, 44, "胜利后应保存战斗剩余气血")
	assertions.assert_eq(game_state.get_martial_proficiency("basic_sword"), 1, "胜利后应增加基础剑法熟练度")

	var failure_state = GameStateScript.new()
	failure_state.start_new_game()
	failure_state.quest_system.start_quest("quest_mountain_trial")
	failure_state.apply_battle_result({
		"victory": false,
		"hero_hp": 0,
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
		"martial_art_id": "basic_sword",
		"proficiency_reward": 1,
	})
	assertions.assert_true(not failure_state.is_map_object_resolved("enemy_bandit_gate"), "失败后不应清除强人触发点")
	assertions.assert_eq(failure_state.quest_system.get_status("quest_mountain_trial"), "active", "失败后任务应保持进行中")
	assertions.assert_eq(failure_state.hero_hp, 1, "失败后主角气血应钳制到安全值")
	assertions.assert_eq(failure_state.get_martial_proficiency("basic_sword"), 0, "失败后不应增加熟练度")
	assertions.assert_eq(failure_state.map_state.player_position, Vector2(160, 320), "失败后应回到山道入口")

	repository.free()
	game_state.free()
	failure_state.free()

	var save_system = SaveSystemScript.new()
	var state = {
		"party": {"members": ["hero_yun"]},
		"quests": {"quest_first_step": "completed"},
	}
	var save_payload = save_system.serialize_state(state)
	assertions.assert_eq(save_payload.get("version", 0), 1, "存档应带版本号")
	assertions.assert_eq(save_system.deserialize_state(save_payload).get("quests", {}).get("quest_first_step", ""), "completed", "存档应可反序列化")
```

Replace `tests/test_save_map_state.gd` with:

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
	state.hero_hp = 70
	state.party.add_item("herb_small", 2)
	state.add_martial_proficiency("basic_sword", 3)

	var path = "user://test_mountain_pass_save.json"
	assertions.assert_true(state.save_to_path(path), "游戏状态应可写入存档文件")

	var restored = GameStateScript.new()
	assertions.assert_true(restored.load_from_path(path), "游戏状态应可从存档文件读取")

	assertions.assert_eq(restored.map_state.current_map_id, "mountain_pass", "读档应恢复地图编号")
	assertions.assert_eq(restored.map_state.player_position, Vector2(444, 333), "读档应恢复玩家坐标")
	assertions.assert_true(restored.map_state.is_object_resolved("enemy_bandit_gate"), "读档应恢复已解决敌人对象")
	assertions.assert_eq(restored.quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "读档应恢复任务状态")
	assertions.assert_eq(restored.party.get_item_count("herb_small"), 3, "读档应恢复背包数量")
	assertions.assert_eq(restored.hero_hp, 70, "读档应恢复主角气血")
	assertions.assert_eq(restored.hero_max_hp, 120, "读档应恢复主角最大气血")
	assertions.assert_eq(restored.get_martial_proficiency("basic_sword"), 3, "读档应恢复基础剑法熟练度")

	var old_save_state = GameStateScript.new()
	old_save_state.from_dictionary({
		"party": {"members": ["hero_yun"], "inventory": {"herb_small": 1}},
		"quests": {},
		"map_state": {},
		"flags": {},
	})
	assertions.assert_eq(old_save_state.hero_hp, 120, "旧存档缺少气血时应回退为满气血")
	assertions.assert_eq(old_save_state.hero_max_hp, 120, "旧存档缺少最大气血时应使用默认值")
	assertions.assert_eq(old_save_state.get_martial_proficiency("basic_sword"), 0, "旧存档缺少熟练度时应回退为 0")

	var invalid_hp_state = GameStateScript.new()
	invalid_hp_state.from_dictionary({
		"party": {"members": ["hero_yun"]},
		"quests": {},
		"map_state": {},
		"flags": {},
		"hero_hp": 999,
		"hero_max_hp": 100,
		"martial_proficiency": {"basic_sword": -5}
	})
	assertions.assert_eq(invalid_hp_state.hero_hp, 100, "读档气血大于最大值时应钳制")
	assertions.assert_eq(invalid_hp_state.get_martial_proficiency("basic_sword"), 0, "读档熟练度小于 0 时应钳制")
	assertions.assert_eq(invalid_hp_state.restore_hero_hp(30), 0, "气血已满时恢复量应为 0")
	invalid_hp_state.hero_hp = 40
	assertions.assert_eq(invalid_hp_state.restore_hero_hp(30), 30, "气血未满时应返回实际恢复量")
	assertions.assert_eq(invalid_hp_state.hero_hp, 70, "恢复后气血应增加")

	var village_state = GameStateScript.new()
	village_state.start_new_game()
	village_state.set_current_map("foot_village", Vector2(760, 320))
	village_state.quest_system.start_quest("quest_deliver_letter")
	village_state.quest_system.mark_ready_to_complete("quest_deliver_letter")
	village_state.quest_system.complete_quest("quest_deliver_letter")
	village_state.set_flag("clue_foot_village", "掌柜提到飞红巾踪迹")
	assertions.assert_eq(village_state.get_current_map_scene_path(), "res://scenes/foot_village.tscn", "村镇地图应映射到村镇场景")
	assertions.assert_eq(village_state.get_scene_path_for_map("missing_map"), "res://scenes/mountain_pass.tscn", "未知地图应回退山道场景")

	var village_path = "user://test_foot_village_save.json"
	assertions.assert_true(village_state.save_to_path(village_path), "村镇状态应可写入存档文件")

	var restored_village = GameStateScript.new()
	assertions.assert_true(restored_village.load_from_path(village_path), "村镇状态应可从存档文件读取")
	assertions.assert_eq(restored_village.map_state.current_map_id, "foot_village", "读档应恢复村镇地图")
	assertions.assert_eq(restored_village.map_state.player_position, Vector2(760, 320), "读档应恢复村镇坐标")
	assertions.assert_eq(restored_village.quest_system.get_status("quest_deliver_letter"), "completed", "读档应恢复送信任务状态")
	assertions.assert_eq(restored_village.flags.get("clue_foot_village", ""), "掌柜提到飞红巾踪迹", "读档应恢复线索标记")

	state.free()
	restored.free()
	old_save_state.free()
	invalid_hp_state.free()
	village_state.free()
	restored_village.free()
```

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL，错误原因包含 `Nonexistent function 'add_martial_proficiency'` 或 `Nonexistent function 'get_martial_proficiency'`。

- [ ] **Step 2: 扩展 `GameState`**

Replace `scripts/core/game_state.gd` with:

```gdscript
extends Node

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const QuestSystemScript = preload("res://scripts/systems/quest_system.gd")
const MapStateScript = preload("res://scripts/domain/map_state.gd")
const SaveSystemScript = preload("res://scripts/systems/save_system.gd")

const DEFAULT_HERO_MAX_HP := 120

var party = PartyStateScript.new()
var quest_system = QuestSystemScript.new()
var map_state = MapStateScript.new()
var flags: Dictionary = {}
var battle_context: Dictionary = {}
var hero_hp := DEFAULT_HERO_MAX_HP
var hero_max_hp := DEFAULT_HERO_MAX_HP
var martial_proficiency: Dictionary = {}

func start_new_game() -> void:
	party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.add_item("herb_small", 1)
	quest_system = QuestSystemScript.new()
	map_state = MapStateScript.new()
	hero_max_hp = DEFAULT_HERO_MAX_HP
	hero_hp = hero_max_hp
	martial_proficiency = {}
	set_current_map("mountain_pass", Vector2(160, 320))
	flags = {"current_map": "mountain_pass"}
	battle_context = {}
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").game_started.emit()

func set_player_position(position: Vector2) -> void:
	map_state.set_player_position(position)

func set_current_map(map_id: String, position: Vector2) -> void:
	if map_id.is_empty():
		return
	map_state.current_map_id = map_id
	map_state.set_player_position(position)
	flags["current_map"] = map_id

func get_current_map_scene_path() -> String:
	return get_scene_path_for_map(map_state.current_map_id)

func get_scene_path_for_map(map_id: String) -> String:
	match map_id:
		"mountain_pass":
			return "res://scenes/mountain_pass.tscn"
		"foot_village":
			return "res://scenes/foot_village.tscn"
		_:
			return "res://scenes/mountain_pass.tscn"

func set_flag(flag_id: String, value: Variant = true) -> void:
	if flag_id.is_empty():
		return
	flags[flag_id] = value

func resolve_map_object(object_id: String) -> void:
	map_state.mark_object_resolved(object_id)

func is_map_object_resolved(object_id: String) -> bool:
	return map_state.is_object_resolved(object_id)

func restore_hero_hp(amount: int) -> int:
	if amount <= 0:
		return 0
	_normalize_hero_hp()
	if hero_hp >= hero_max_hp:
		return 0
	var before = hero_hp
	hero_hp = min(hero_max_hp, hero_hp + amount)
	return hero_hp - before

func is_hero_hp_full() -> bool:
	_normalize_hero_hp()
	return hero_hp >= hero_max_hp

func add_martial_proficiency(martial_art_id: String, amount: int) -> int:
	if martial_art_id.is_empty() or amount <= 0:
		return get_martial_proficiency(martial_art_id)
	martial_proficiency[martial_art_id] = get_martial_proficiency(martial_art_id) + amount
	return int(martial_proficiency[martial_art_id])

func get_martial_proficiency(martial_art_id: String) -> int:
	if martial_art_id.is_empty():
		return 0
	return max(0, int(martial_proficiency.get(martial_art_id, 0)))

func set_battle_context(context: Dictionary) -> void:
	battle_context = context.duplicate(true)

func consume_battle_context() -> Dictionary:
	var context = battle_context.duplicate(true)
	battle_context = {}
	return context

func peek_battle_context() -> Dictionary:
	return battle_context.duplicate(true)

func apply_battle_result(result: Dictionary) -> void:
	if result.has("hero_hp"):
		hero_hp = int(result.get("hero_hp", hero_hp))

	if bool(result.get("victory", false)):
		_normalize_hero_hp()
		var object_id = str(result.get("source_object_id", ""))
		if not object_id.is_empty():
			resolve_map_object(object_id)
		var quest_id = str(result.get("quest_id", ""))
		if not quest_id.is_empty():
			quest_system.mark_ready_to_complete(quest_id)
		var martial_art_id = str(result.get("martial_art_id", ""))
		var reward = int(result.get("proficiency_reward", 0))
		if reward > 0:
			add_martial_proficiency(martial_art_id, reward)
	else:
		hero_hp = max(1, hero_hp)
		map_state.player_position = Vector2(160, 320)

func save_to_path(path: String) -> bool:
	return SaveSystemScript.new().save_to_path(path, to_dictionary())

func load_from_path(path: String) -> bool:
	var data = SaveSystemScript.new().load_from_path(path)
	if data.is_empty():
		return false
	from_dictionary(data)
	return true

func to_dictionary() -> Dictionary:
	_normalize_hero_hp()
	return {
		"party": party.to_dictionary(),
		"quests": quest_system.to_dictionary(),
		"map_state": map_state.to_dictionary(),
		"flags": flags.duplicate(true),
		"hero_hp": hero_hp,
		"hero_max_hp": hero_max_hp,
		"martial_proficiency": _normalized_martial_proficiency(),
	}

func from_dictionary(data: Dictionary) -> void:
	party = PartyStateScript.new()
	party.from_dictionary(data.get("party", {}))
	quest_system = QuestSystemScript.new()
	quest_system.from_dictionary(data.get("quests", {}))
	map_state = MapStateScript.new()
	map_state.from_dictionary(data.get("map_state", {}))
	flags = data.get("flags", {}).duplicate(true)
	if not flags.has("current_map"):
		flags["current_map"] = map_state.current_map_id
	hero_max_hp = int(data.get("hero_max_hp", DEFAULT_HERO_MAX_HP))
	if hero_max_hp <= 0:
		hero_max_hp = DEFAULT_HERO_MAX_HP
	hero_hp = int(data.get("hero_hp", hero_max_hp))
	martial_proficiency = _read_martial_proficiency(data.get("martial_proficiency", {}))
	_normalize_hero_hp()
	battle_context = {}

func _normalize_hero_hp() -> void:
	if hero_max_hp <= 0:
		hero_max_hp = DEFAULT_HERO_MAX_HP
	hero_hp = clamp(hero_hp, 0, hero_max_hp)

func _normalized_martial_proficiency() -> Dictionary:
	var result: Dictionary = {}
	for martial_art_id in martial_proficiency.keys():
		var normalized_id = str(martial_art_id)
		if normalized_id.is_empty():
			continue
		var amount = max(0, int(martial_proficiency[martial_art_id]))
		if amount > 0:
			result[normalized_id] = amount
	return result

func _read_martial_proficiency(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for martial_art_id in value.keys():
		var normalized_id = str(martial_art_id)
		if normalized_id.is_empty():
			continue
		var amount = max(0, int(value[martial_art_id]))
		if amount > 0:
			result[normalized_id] = amount
	return result
```

- [ ] **Step 3: 运行测试并提交**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：13 个测试套件
```

Commit:

```powershell
git add tests/test_combat_and_save.gd tests/test_save_map_state.gd scripts/core/game_state.gd
git commit -m "feat: 保存战斗气血和武学熟练度"
```

---

### Task 4: 实现回合战斗系统

**Files:**
- Create: `tests/test_turn_based_combat_system.gd`
- Modify: `tests/run_tests.gd`
- Modify: `scripts/systems/combat_system.gd`

- [ ] **Step 1: 写失败测试 `tests/test_turn_based_combat_system.gd`**

Create `tests/test_turn_based_combat_system.gd`:

```gdscript
extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const CombatSystemScript = preload("res://scripts/systems/combat_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()

	var system = CombatSystemScript.new()
	system.set_repository(repository)

	var state = GameStateScript.new()
	state.start_new_game()
	state.hero_hp = 100
	state.quest_system.start_quest("quest_mountain_trial")

	var battle = system.create_battle(state, {
		"enemy_id": "bandit_01",
		"source_map_id": "mountain_pass",
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
	}, repository)
	assertions.assert_eq(battle.hero_hp, 100, "创建战斗应读取当前主角气血")
	assertions.assert_eq(battle.enemy_hp, 60, "创建战斗应读取敌人气血")
	assertions.assert_eq(battle.source_object_id, "enemy_bandit_gate", "创建战斗应保存来源对象")

	system.resolve_player_attack(battle, state, "basic_sword")
	assertions.assert_eq(battle.enemy_hp, 34, "第一回合基础剑法应扣除敌人气血")
	assertions.assert_eq(battle.hero_hp, 96, "敌人未倒下时应反击并扣主角气血")
	assertions.assert_eq(state.hero_hp, 96, "战斗中主角气血应同步到 GameState")
	assertions.assert_eq(battle.round, 2, "完成双方行动后应进入下一回合")
	assertions.assert_true(not battle.is_finished, "敌人未倒下时战斗不应结束")

	system.resolve_player_attack(battle, state, "basic_sword")
	assertions.assert_eq(battle.enemy_hp, 8, "第二回合基础剑法应继续扣除敌人气血")
	assertions.assert_eq(battle.hero_hp, 92, "第二回合敌人应继续反击")
	assertions.assert_eq(battle.round, 3, "第二回合后应进入第三回合")

	system.resolve_player_attack(battle, state, "basic_sword")
	assertions.assert_eq(battle.enemy_hp, 0, "第三回合应击败敌人")
	assertions.assert_eq(battle.hero_hp, 92, "击败敌人后不应再触发反击")
	assertions.assert_true(battle.is_finished, "敌人倒下后战斗应结束")
	assertions.assert_true(battle.victory, "敌人倒下后应标记胜利")
	assertions.assert_eq(battle.reward_martial_art_id, "basic_sword", "胜利结果应记录成长武学")
	assertions.assert_eq(battle.proficiency_reward, 1, "胜利结果应记录熟练度奖励")

	state.apply_battle_result(battle.to_result_dictionary())
	assertions.assert_true(state.is_map_object_resolved("enemy_bandit_gate"), "胜利回流应清除敌人对象")
	assertions.assert_eq(state.quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "胜利回流应推进任务")
	assertions.assert_eq(state.get_martial_proficiency("basic_sword"), 1, "胜利回流应增加熟练度")

	var item_state = GameStateScript.new()
	item_state.start_new_game()
	item_state.hero_hp = 60
	var item_battle = system.create_battle(item_state, {"enemy_id": "bandit_01"}, repository)
	system.resolve_player_item(item_battle, item_state, "herb_small")
	assertions.assert_eq(item_state.party.get_item_count("herb_small"), 0, "战斗中用药应扣除背包")
	assertions.assert_eq(item_battle.hero_hp, 86, "小还丹先恢复 30 点气血，再承受 4 点反击")
	assertions.assert_eq(item_state.hero_hp, 86, "战斗中用药后 GameState 气血应同步")
	assertions.assert_eq(item_battle.round, 2, "成功用药并被反击后应进入下一回合")

	var full_hp_state = GameStateScript.new()
	full_hp_state.start_new_game()
	var full_hp_battle = system.create_battle(full_hp_state, {"enemy_id": "bandit_01"}, repository)
	system.resolve_player_item(full_hp_battle, full_hp_state, "herb_small")
	assertions.assert_eq(full_hp_state.party.get_item_count("herb_small"), 1, "气血已满时战斗中用药不应扣物品")
	assertions.assert_eq(full_hp_battle.round, 1, "气血已满用药失败不应消耗回合")
	assertions.assert_eq(full_hp_battle.hero_hp, 120, "气血已满用药失败不应触发反击")

	var missing_item_state = GameStateScript.new()
	missing_item_state.start_new_game()
	missing_item_state.hero_hp = 60
	missing_item_state.party.remove_item("herb_small", 1)
	var missing_item_battle = system.create_battle(missing_item_state, {"enemy_id": "bandit_01"}, repository)
	system.resolve_player_item(missing_item_battle, missing_item_state, "herb_small")
	assertions.assert_eq(missing_item_battle.round, 1, "小还丹不足时不应消耗回合")
	assertions.assert_eq(missing_item_battle.hero_hp, 60, "小还丹不足时不应触发反击")
	assertions.assert_true(missing_item_battle.log.has("背包中没有此物。"), "小还丹不足时应记录失败原因")

	var retreat_state = GameStateScript.new()
	retreat_state.start_new_game()
	retreat_state.hero_hp = 77
	retreat_state.quest_system.start_quest("quest_mountain_trial")
	var retreat_battle = system.create_battle(retreat_state, {
		"enemy_id": "bandit_01",
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
	}, repository)
	system.resolve_retreat(retreat_battle)
	retreat_state.apply_battle_result(retreat_battle.to_result_dictionary())
	assertions.assert_true(retreat_battle.is_finished, "暂退应结束战斗")
	assertions.assert_true(not retreat_battle.victory, "暂退不应标记胜利")
	assertions.assert_true(not retreat_state.is_map_object_resolved("enemy_bandit_gate"), "暂退不应清除敌人对象")
	assertions.assert_eq(retreat_state.quest_system.get_status("quest_mountain_trial"), "active", "暂退不应推进任务")

	var defeat_state = GameStateScript.new()
	defeat_state.start_new_game()
	defeat_state.hero_hp = 3
	defeat_state.quest_system.start_quest("quest_mountain_trial")
	var defeat_battle = system.create_battle(defeat_state, {
		"enemy_id": "bandit_01",
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
	}, repository)
	system.resolve_player_attack(defeat_battle, defeat_state, "basic_sword")
	assertions.assert_true(defeat_battle.is_finished, "主角气血归零后战斗应结束")
	assertions.assert_true(not defeat_battle.victory, "主角气血归零后应标记失败")
	defeat_state.apply_battle_result(defeat_battle.to_result_dictionary())
	assertions.assert_eq(defeat_state.hero_hp, 1, "失败回流应把主角气血钳制到安全值")
	assertions.assert_true(not defeat_state.is_map_object_resolved("enemy_bandit_gate"), "失败不应清除敌人对象")

	state.free()
	item_state.free()
	full_hp_state.free()
	missing_item_state.free()
	retreat_state.free()
	defeat_state.free()
	repository.free()
```

- [ ] **Step 2: 接入测试运行器并确认失败**

Replace `tests/run_tests.gd` with:

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
const TestMapTransitionSystemScript = preload("res://tests/test_map_transition_system.gd")
const TestInventorySystemScript = preload("res://tests/test_inventory_system.gd")
const TestHudInventoryScript = preload("res://tests/test_hud_inventory.gd")
const TestBattleStateScript = preload("res://tests/test_battle_state.gd")
const TestTurnBasedCombatSystemScript = preload("res://tests/test_turn_based_combat_system.gd")

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
		TestMapTransitionSystemScript.new(),
		TestInventorySystemScript.new(),
		TestHudInventoryScript.new(),
		TestBattleStateScript.new(),
		TestTurnBasedCombatSystemScript.new(),
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

Expected: FAIL，错误原因包含 `Nonexistent function 'set_repository'` 或 `Nonexistent function 'create_battle'`。

- [ ] **Step 3: 实现回合战斗系统**

Replace `scripts/systems/combat_system.gd` with:

```gdscript
extends RefCounted

const ActorStateScript = preload("res://scripts/domain/actor_state.gd")
const MartialArtRecordScript = preload("res://scripts/domain/martial_art_record.gd")
const BattleStateScript = preload("res://scripts/domain/battle_state.gd")
const CombatResultScript = preload("res://scripts/domain/combat_result.gd")
const InventorySystemScript = preload("res://scripts/systems/inventory_system.gd")

var repository = null
var inventory_system = InventorySystemScript.new()

func set_repository(next_repository) -> void:
	repository = next_repository
	inventory_system.set_repository(next_repository)

func create_battle(game_state, context: Dictionary, data_source = null):
	var source = data_source if data_source != null else _get_repository()
	var battle = BattleStateScript.new()
	battle.hero_id = "hero_yun"
	battle.enemy_id = str(context.get("enemy_id", "bandit_01"))
	if battle.enemy_id.is_empty():
		battle.enemy_id = "bandit_01"
	battle.source_map_id = str(context.get("source_map_id", "mountain_pass"))
	if battle.source_map_id.is_empty():
		battle.source_map_id = "mountain_pass"
	battle.source_object_id = str(context.get("source_object_id", ""))
	battle.quest_id = str(context.get("quest_id", ""))

	if source == null:
		battle.hero_hp = max(1, int(game_state.hero_hp))
		battle.hero_max_hp = max(1, int(game_state.hero_max_hp))
		battle.enemy_hp = 1
		battle.enemy_max_hp = 1
		battle.append_log("敌人资料缺失。")
		return battle

	var hero_data = source.get_actor("hero_yun")
	var enemy_data = source.get_actor(battle.enemy_id)
	battle.hero_max_hp = max(1, int(game_state.hero_max_hp))
	battle.hero_hp = clamp(int(game_state.hero_hp), 0, battle.hero_max_hp)
	if battle.hero_hp <= 0:
		battle.hero_hp = 1
	if enemy_data.is_empty():
		battle.enemy_hp = 1
		battle.enemy_max_hp = 1
		battle.append_log("敌人资料缺失。")
	else:
		battle.enemy_hp = max(1, int(enemy_data.get("hp", 1)))
		battle.enemy_max_hp = max(1, int(enemy_data.get("max_hp", battle.enemy_hp)))
	if hero_data.is_empty():
		battle.append_log("主角资料缺失。")
	return battle

func resolve_player_attack(battle, game_state, martial_art_id: String) -> Dictionary:
	if battle == null:
		return {"success": false, "message": "战斗尚未准备好。"}
	if battle.is_finished:
		return {"success": false, "message": "战斗已经结束。"}

	var source = _get_repository()
	if source == null:
		battle.append_log("武学资料缺失。")
		return {"success": false, "message": "武学资料缺失。"}

	var hero = ActorStateScript.from_dictionary(source.get_actor("hero_yun"))
	var enemy = ActorStateScript.from_dictionary(source.get_actor(battle.enemy_id))
	var martial_art = MartialArtRecordScript.from_dictionary(source.get_martial_art(martial_art_id))
	if hero.id.is_empty():
		battle.append_log("主角资料缺失。")
		return {"success": false, "message": "主角资料缺失。"}
	if enemy.id.is_empty():
		battle.append_log("敌人资料缺失。")
		return {"success": false, "message": "敌人资料缺失。"}
	if martial_art.id.is_empty():
		battle.append_log("武学资料缺失。")
		return {"success": false, "message": "武学资料缺失。"}

	var damage = _calculate_martial_damage(hero, enemy, martial_art)
	battle.enemy_hp = max(0, battle.enemy_hp - damage)
	battle.append_log("第%d回合：%s使出%s，造成%d点伤害。" % [battle.round, hero.name, martial_art.name, damage])

	if battle.enemy_hp <= 0:
		battle.reward_martial_art_id = martial_art.id
		battle.proficiency_reward = max(0, martial_art.proficiency_reward)
		battle.append_log("%s被击败。" % enemy.name)
		if battle.proficiency_reward > 0:
			battle.append_log("%s熟练度提升。" % martial_art.name)
		battle.finish(true)
		_sync_hero_hp(game_state, battle)
		return {"success": true, "message": "战斗胜利。"}

	_enemy_counterattack(battle, game_state, enemy, hero)
	if not battle.is_finished:
		battle.round += 1
	return {"success": true, "message": "已经出招。"}

func resolve_player_item(battle, game_state, item_id: String) -> Dictionary:
	if battle == null:
		return {"success": false, "message": "战斗尚未准备好。"}
	if battle.is_finished:
		return {"success": false, "message": "战斗已经结束。"}

	var source = _get_repository()
	if source == null:
		battle.append_log("此物品资料缺失。")
		return {"success": false, "message": "此物品资料缺失。"}

	inventory_system.set_repository(source)
	game_state.hero_hp = battle.hero_hp
	var result = inventory_system.use_item(game_state, item_id)
	var message = str(result.get("message", "此物暂时不能使用。"))
	battle.append_log(message)
	if not bool(result.get("success", false)):
		return result

	battle.hero_hp = int(game_state.hero_hp)
	var hero = ActorStateScript.from_dictionary(source.get_actor("hero_yun"))
	var enemy = ActorStateScript.from_dictionary(source.get_actor(battle.enemy_id))
	_enemy_counterattack(battle, game_state, enemy, hero)
	if not battle.is_finished:
		battle.round += 1
	return result

func resolve_retreat(battle) -> Dictionary:
	if battle == null:
		return {"success": false, "message": "战斗尚未准备好。"}
	if not battle.is_finished:
		battle.hero_hp = max(1, battle.hero_hp)
		battle.append_log("暂退数步。")
		battle.finish(false)
	return {"success": true, "message": "暂退数步。"}

func resolve_duel(attacker, defender, martial_art):
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

func _enemy_counterattack(battle, game_state, enemy, hero) -> void:
	var damage = _calculate_basic_damage(enemy, hero)
	battle.hero_hp = max(0, battle.hero_hp - damage)
	battle.append_log("%s反击，造成%d点伤害。" % [enemy.name, damage])
	_sync_hero_hp(game_state, battle)
	if battle.hero_hp <= 0:
		battle.append_log("气血不支，暂退数步。")
		battle.finish(false)

func _calculate_martial_damage(attacker, defender, martial_art) -> int:
	return maxi(1, attacker.attack + martial_art.power - defender.defense)

func _calculate_basic_damage(attacker, defender) -> int:
	return maxi(1, attacker.attack - defender.defense)

func _sync_hero_hp(game_state, battle) -> void:
	if game_state != null:
		game_state.hero_hp = battle.hero_hp

func _get_repository():
	if repository != null:
		return repository
	var loop = Engine.get_main_loop()
	if loop == null or loop.root == null:
		return null
	if loop.root.has_node("DataRepository"):
		return loop.root.get_node("DataRepository")
	return null
```

- [ ] **Step 4: 运行测试并提交**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：14 个测试套件
```

Commit:

```powershell
git add tests/run_tests.gd tests/test_turn_based_combat_system.gd scripts/systems/combat_system.gd
git commit -m "feat: 添加回合战斗系统"
```

---

### Task 5: 接入多回合战斗界面

**Files:**
- Modify: `scripts/scenes/battle_screen.gd`

- [ ] **Step 1: 替换战斗场景脚本**

Replace `scripts/scenes/battle_screen.gd` with:

```gdscript
extends Control

const CombatSystemScript = preload("res://scripts/systems/combat_system.gd")

var title_label: Label
var hero_hp_label: Label
var enemy_hp_label: Label
var output: Label
var attack_button: Button
var item_button: Button
var retreat_button: Button
var context: Dictionary = {}
var battle_state = null
var combat_system = CombatSystemScript.new()

func _ready() -> void:
	context = GameState.peek_battle_context()
	combat_system.set_repository(DataRepository)
	battle_state = combat_system.create_battle(GameState, context, DataRepository)
	_create_ui()
	_refresh()

func _create_ui() -> void:
	title_label = Label.new()
	title_label.position = Vector2(32, 24)
	title_label.size = Vector2(720, 32)
	add_child(title_label)

	hero_hp_label = Label.new()
	hero_hp_label.position = Vector2(32, 72)
	hero_hp_label.size = Vector2(320, 32)
	add_child(hero_hp_label)

	enemy_hp_label = Label.new()
	enemy_hp_label.position = Vector2(380, 72)
	enemy_hp_label.size = Vector2(320, 32)
	add_child(enemy_hp_label)

	output = Label.new()
	output.position = Vector2(32, 120)
	output.size = Vector2(900, 220)
	output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(output)

	attack_button = Button.new()
	attack_button.text = "基础剑法"
	attack_button.position = Vector2(32, 372)
	attack_button.size = Vector2(120, 40)
	attack_button.pressed.connect(_on_attack_pressed)
	add_child(attack_button)

	item_button = Button.new()
	item_button.text = "小还丹"
	item_button.position = Vector2(176, 372)
	item_button.size = Vector2(120, 40)
	item_button.pressed.connect(_on_item_pressed)
	add_child(item_button)

	retreat_button = Button.new()
	retreat_button.text = "暂退"
	retreat_button.position = Vector2(320, 372)
	retreat_button.size = Vector2(120, 40)
	retreat_button.pressed.connect(_on_retreat_pressed)
	add_child(retreat_button)

func _on_attack_pressed() -> void:
	combat_system.resolve_player_attack(battle_state, GameState, "basic_sword")
	_refresh()
	_return_if_finished()

func _on_item_pressed() -> void:
	combat_system.resolve_player_item(battle_state, GameState, "herb_small")
	_refresh()
	_return_if_finished()

func _on_retreat_pressed() -> void:
	combat_system.resolve_retreat(battle_state)
	_refresh()
	_return_if_finished()

func _refresh() -> void:
	var enemy_name = DataRepository.get_actor(_enemy_id()).get("name", "山道强人")
	title_label.text = "战斗：%s" % enemy_name
	hero_hp_label.text = "云游少侠 气血：%d / %d" % [battle_state.hero_hp, battle_state.hero_max_hp]
	enemy_hp_label.text = "%s 气血：%d / %d" % [enemy_name, battle_state.enemy_hp, battle_state.enemy_max_hp]
	output.text = "\n".join(PackedStringArray(battle_state.log))

	var finished = battle_state.is_finished
	attack_button.disabled = finished
	item_button.disabled = finished
	retreat_button.disabled = finished

func _return_if_finished() -> void:
	if not battle_state.is_finished:
		return
	var payload = battle_state.to_result_dictionary()
	GameState.apply_battle_result(payload)
	EventBus.battle_finished.emit(payload)
	call_deferred("_return_to_map")

func _return_to_map() -> void:
	var source_map_id = battle_state.source_map_id
	if source_map_id.is_empty():
		source_map_id = str(context.get("source_map_id", GameState.map_state.current_map_id))
	if source_map_id.is_empty():
		source_map_id = "mountain_pass"
	GameState.consume_battle_context()
	SceneLoader.change_scene(GameState.get_scene_path_for_map(source_map_id))

func _enemy_id() -> String:
	var enemy_id = str(context.get("enemy_id", "bandit_01"))
	if enemy_id.is_empty():
		return "bandit_01"
	return enemy_id
```

- [ ] **Step 2: 运行项目加载和逻辑测试**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：14 个测试套件
```

- [ ] **Step 3: 手动验收战斗界面**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64.exe"
& $godot --path .
```

Manual checks:

```text
1. 主菜单点击“开始新游戏”进入山道。
2. 与青衫客交谈接取“山道试剑”。
3. 进入山道强人触发范围后切到战斗场景。
4. 战斗界面显示云游少侠和山道强人的气血。
5. 点击“基础剑法”后，山道强人气血下降，日志显示伤害。
6. 山道强人未倒下时会反击，云游少侠气血下降。
7. 战斗至少可以点击两次行动按钮，不是一击结束。
8. 气血未满且背包有小还丹时，点击“小还丹”会恢复气血并扣除数量。
9. 点击“暂退”会返回山道，强人触发点仍在。
10. 击败山道强人后返回山道，强人触发点消失。
11. 胜利后回青衫客处可以交任务。
```

- [ ] **Step 4: 提交战斗界面**

```powershell
git add scripts/scenes/battle_screen.gd
git commit -m "feat: 接入回合战斗界面"
```

---

### Task 6: 更新文档并最终验证

**Files:**
- Modify: `README.md`
- Modify: `docs/godot-project-structure.md`

- [ ] **Step 1: 更新 `README.md` 当前目标**

Replace the `## 当前目标` section in `README.md` with:

```markdown
## 当前目标

当前阶段包含：

- Godot 4.6 项目配置。
- 数据加载、任务、对话、战斗和存档基础逻辑。
- 启动、主菜单、山道探索、山脚村镇和战斗场景。
- 山道探索垂直切片：WASD 连续移动、NPC 交互、任务、战斗返回和奖励。
- 山脚村镇任务延伸切片：山道和村镇双向切换、送信到客栈任务、线索记录和存档恢复。
- 轻量背包与物品使用切片：地图内背包面板、小还丹使用、气血恢复和存档恢复。
- 基础回合战斗与武学成长切片：多回合山道强人战、战斗中用药、失败回流和基础剑法熟练度。
```

- [ ] **Step 2: 更新项目结构文档**

In `docs/godot-project-structure.md`, add this section after `## 轻量背包切片`:

```markdown
## 回合战斗与武学成长切片

回合战斗切片使用 `BattleState` 保存战斗运行时状态，`CombatSystem` 处理玩家攻击、敌人反击、战斗中用药、暂退和胜负。战斗界面只显示双方气血、按钮和日志，不直接计算伤害或扣除背包。胜利后 `GameState` 负责清除地图对象、推进任务，并记录 `basic_sword` 熟练度。
```

Also update the `scripts/domain/` layer bullet near the top to:

```markdown
- `scripts/domain/`：只放领域数据和规则对象，例如地图状态、战斗状态、队伍、角色、物品和武学记录，不依赖 Godot 场景节点。
```

Also update the `scripts/systems/` layer bullet near the top to:

```markdown
- `scripts/systems/`：放可测试的游戏流程，例如数据、地图对象、地图切换、交互、任务、对话、战斗、背包和存档。
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
测试通过：14 个测试套件
```

`Select-String` and `git diff --check HEAD` should produce no issue output. `git status --short` may show only unrelated pre-existing files, especially untracked `.spec-workflow/`.

- [ ] **Step 4: 提交文档更新**

```powershell
git add README.md docs/godot-project-structure.md
git commit -m "docs: 更新回合战斗成长说明"
```

## 最终验收

完成所有任务后，按以下顺序验收：

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
git log --oneline -n 8
git status --short
```

期望结果：

- 测试输出 `测试通过：14 个测试套件`。
- 项目加载命令退出码为 `0`。
- 最近提交包含本计划中的 6 个提交。
- 工作区没有本切片遗留的未提交修改。
- `.spec-workflow/` 如果仍是未跟踪状态，保持不动。

## 计划自检

- Spec 覆盖：本计划覆盖双方气血显示、基础剑法行动、敌人反击、战斗中小还丹、用药失败不扣除、山道强人不被一击击败、胜利清除触发点、任务推进、失败和暂退回流、主角气血保存、基础剑法熟练度和存档恢复。
- 范围控制：本计划不实现多队友、多敌人、内力、状态异常、装备属性、复杂 AI、战斗动画、角色等级或角色面板。
- 类型一致性：`BattleState.to_result_dictionary()`、`CombatSystem.create_battle()`、`CombatSystem.resolve_player_attack()`、`CombatSystem.resolve_player_item()`、`CombatSystem.resolve_retreat()`、`GameState.add_martial_proficiency()` 和 `GameState.get_martial_proficiency()` 在测试与实现中名称一致。
