# 战棋武学与内力基础切片 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有方格战棋从普通攻击推进到玩家可选择基础剑法和穿云刺，并用每场战斗回满的简化内力模型支撑招式消耗。

**Architecture:** 保持现有“领域状态、系统规则、场景表现、核心回流”分层。武学资料只提供战棋参数，`TacticalCombatSystem` 负责招式范围、内力扣除和伤害，`BattleScreen` 负责按钮、选中动作和格子高亮，`GameState` 只保存主角长期最大内力。

**Tech Stack:** Godot 4.6、GDScript、JSON 内容数据、项目本地 Godot headless 测试运行器、PowerShell。

---

## Scope Check

本计划实现一个单一切片：玩家侧战棋武学和简化内力。它不实现敌人招式 AI、长期当前内力、内力恢复道具、角色面板、状态异常、AOE、地形遮挡或独立遭遇数据文件。每个任务都能独立测试，并以小提交收束。

## File Structure

```text
data/martial_arts.json                              # 为基础剑法增加 tactical 字段，并新增穿云刺
data/actors.json                                    # 让 hero_yun 学会穿云刺
docs/godot-project-structure.md                     # 记录战棋武学与内力切片规则
README.md                                           # 更新当前目标列表
scripts/domain/martial_art_record.gd                # 读取并规范化 tactical 武学字段
scripts/core/game_state.gd                          # 保存 hero_max_mp，旧存档默认 20
scripts/domain/tactical_unit_state.gd               # 保存战棋单位 mp/max_mp/martial_art_ids
scripts/systems/tactical_combat_system.gd           # 武学攻击、范围判断、扣内力、伤害和高亮查询
scripts/scenes/battle_screen.gd                     # 战棋动作按钮、内力显示、招式选择和攻击接线
tests/test_data_loader.gd                           # 验证新增武学与角色数据
tests/test_domain_models.gd                         # 验证 MartialArtRecord tactical 字段
tests/test_combat_and_save.gd                       # 验证 hero_max_mp 新游戏、存档和旧存档兼容
tests/test_tactical_unit_state.gd                   # 验证战棋单位内力与武学序列化
tests/test_tactical_combat_system.gd                # 验证战棋武学规则
tests/test_tactical_battle_screen.gd                # 验证战棋 UI 新控件和选中动作
```

Baseline verification before implementation:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected baseline:

```text
测试通过：32 个测试套件
```

Godot also prints existing expected error-path diagnostics from map and pickup tests; the process exit code must be `0`.

---

### Task 1: 武学数据和 MartialArtRecord

**Files:**
- Modify: `data/martial_arts.json`
- Modify: `data/actors.json`
- Modify: `scripts/domain/martial_art_record.gd`
- Modify: `tests/test_domain_models.gd`
- Modify: `tests/test_data_loader.gd`

- [ ] **Step 1: Write the failing domain and data tests**

In `tests/test_domain_models.gd`, replace the `martial_art` fixture and its assertions with:

```gdscript
	var martial_art = MartialArtRecordScript.from_dictionary({
		"id": "basic_sword",
		"name": "基础剑法",
		"school": "江湖",
		"power": 12,
		"cost": 3,
		"description": "入门剑招，胜在稳妥。",
		"proficiency_reward": 1,
		"tactical": {
			"damage_bonus": 6,
			"range": 1,
			"range_shape": "diamond",
			"mp_cost": 3,
		},
	})
	assertions.assert_eq(martial_art.power, 12, "武学应保存威力")
	assertions.assert_eq(martial_art.proficiency_reward, 1, "武学应保存熟练度奖励")
	assertions.assert_true(martial_art.has_tactical_config(), "武学应识别战棋配置")
	assertions.assert_eq(martial_art.tactical_damage_bonus, 6, "武学应读取战棋伤害加值")
	assertions.assert_eq(martial_art.tactical_range, 1, "武学应读取战棋范围")
	assertions.assert_eq(martial_art.tactical_range_shape, "diamond", "武学应读取战棋范围形状")
	assertions.assert_eq(martial_art.tactical_mp_cost, 3, "武学应读取战棋内力消耗")

	var fallback_cost_art = MartialArtRecordScript.from_dictionary({
		"id": "fallback_cost",
		"name": "旧式招式",
		"cost": 4,
		"tactical": {"damage_bonus": 2, "range": 1, "range_shape": "diamond"},
	})
	assertions.assert_eq(fallback_cost_art.tactical_mp_cost, 4, "缺少 mp_cost 时应回退到 cost")

	var plain_art = MartialArtRecordScript.from_dictionary({
		"id": "plain_art",
		"name": "普通武学",
		"cost": 2,
	})
	assertions.assert_true(not plain_art.has_tactical_config(), "缺少 tactical 时不应视为战棋招式")
```

In `tests/test_data_loader.gd`, insert these assertions after the existing `basic_sword` assertion:

```gdscript
	assertions.assert_eq(repository.get_martial_art("straight_sword_thrust").get("name", ""), "穿云刺", "应按编号读取穿云刺")
	assertions.assert_eq(repository.get_martial_art("basic_sword").get("tactical", {}).get("range_shape", ""), "diamond", "基础剑法应声明战棋范围")
	assertions.assert_eq(repository.get_martial_art("straight_sword_thrust").get("tactical", {}).get("range_shape", ""), "line", "穿云刺应声明直线范围")
	assertions.assert_true(repository.get_actor("hero_yun").get("martial_arts", []).has("straight_sword_thrust"), "主角应学会穿云刺")
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL with messages about missing `has_tactical_config`, missing tactical properties, or missing `straight_sword_thrust`.

- [ ] **Step 3: Replace `scripts/domain/martial_art_record.gd`**

Replace the file with:

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
var tactical: Dictionary = {}
var tactical_damage_bonus: int = 0
var tactical_range: int = 0
var tactical_range_shape: String = ""
var tactical_mp_cost: int = 0

static func from_dictionary(data: Dictionary):
	var martial_art = new()
	martial_art.id = str(data.get("id", ""))
	martial_art.name = str(data.get("name", ""))
	martial_art.school = str(data.get("school", ""))
	martial_art.power = int(data.get("power", 0))
	martial_art.cost = int(data.get("cost", 0))
	martial_art.description = str(data.get("description", ""))
	martial_art.proficiency_reward = max(0, int(data.get("proficiency_reward", 1)))
	martial_art.tactical = _read_tactical_config(data.get("tactical", {}), martial_art.cost)
	martial_art.tactical_damage_bonus = int(martial_art.tactical.get("damage_bonus", 0))
	martial_art.tactical_range = int(martial_art.tactical.get("range", 0))
	martial_art.tactical_range_shape = str(martial_art.tactical.get("range_shape", ""))
	martial_art.tactical_mp_cost = int(martial_art.tactical.get("mp_cost", 0))
	return martial_art

func has_tactical_config() -> bool:
	return not tactical.is_empty() and tactical_range > 0 and not tactical_range_shape.is_empty()

static func _read_tactical_config(value: Variant, fallback_cost: int) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var range_shape = str(value.get("range_shape", ""))
	var attack_range = max(1, int(value.get("range", 1)))
	if range_shape.is_empty():
		return {}
	return {
		"damage_bonus": int(value.get("damage_bonus", 0)),
		"range": attack_range,
		"range_shape": range_shape,
		"mp_cost": max(0, int(value.get("mp_cost", fallback_cost))),
	}
```

- [ ] **Step 4: Replace `data/martial_arts.json`**

Replace the file with:

```json
[
  {
    "id": "basic_sword",
    "name": "基础剑法",
    "school": "江湖",
    "power": 12,
    "cost": 3,
    "description": "入门剑招，胜在稳妥。",
    "proficiency_reward": 1,
    "tactical": {
      "damage_bonus": 6,
      "range": 1,
      "range_shape": "diamond",
      "mp_cost": 3
    }
  },
  {
    "id": "straight_sword_thrust",
    "name": "穿云刺",
    "school": "江湖",
    "power": 10,
    "cost": 5,
    "description": "挺剑直进，可隔一身位刺敌。",
    "proficiency_reward": 0,
    "tactical": {
      "damage_bonus": 4,
      "range": 2,
      "range_shape": "line",
      "mp_cost": 5
    }
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

- [ ] **Step 5: Update `data/actors.json` hero martial arts**

In the `hero_yun` record, replace:

```json
    "martial_arts": ["basic_sword"]
```

with:

```json
    "martial_arts": ["basic_sword", "straight_sword_thrust"]
```

- [ ] **Step 6: Run tests to verify Task 1 passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with:

```text
测试通过：32 个测试套件
```

- [ ] **Step 7: Commit Task 1**

```powershell
git add data/martial_arts.json data/actors.json scripts/domain/martial_art_record.gd tests/test_domain_models.gd tests/test_data_loader.gd
git commit -m "feat: add tactical martial art data"
```

---

### Task 2: 主角最大内力与存档兼容

**Files:**
- Modify: `scripts/core/game_state.gd`
- Modify: `tests/test_combat_and_save.gd`

- [ ] **Step 1: Write failing GameState MP persistence tests**

In `tests/test_combat_and_save.gd`, insert this block after `game_state.start_new_game()` in the existing save/combat test:

```gdscript
	assertions.assert_eq(game_state.hero_max_mp, 20, "新游戏主角最大内力应为 20")
```

Near the existing save/restore assertions in the same file, add:

```gdscript
	var serialized_with_mp = game_state.to_dictionary()
	assertions.assert_eq(serialized_with_mp.get("hero_max_mp", 0), 20, "存档应保存主角最大内力")

	var restored_with_mp = GameStateScript.new()
	restored_with_mp.from_dictionary(serialized_with_mp)
	assertions.assert_eq(restored_with_mp.hero_max_mp, 20, "读档应恢复主角最大内力")

	var old_save_state = GameStateScript.new()
	old_save_state.from_dictionary({
		"party": game_state.party.to_dictionary(),
		"quests": game_state.quest_system.to_dictionary(),
		"map_state": game_state.map_state.to_dictionary(),
		"journal_state": game_state.journal_state.to_dictionary(),
		"flags": game_state.flags.duplicate(true),
		"hero_hp": 90,
		"hero_max_hp": 120,
		"martial_proficiency": {},
	})
	assertions.assert_eq(old_save_state.hero_max_mp, 20, "旧存档缺少最大内力时应使用默认值")
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL with `Invalid get index 'hero_max_mp'` or assertion failure for missing `hero_max_mp`.

- [ ] **Step 3: Update `scripts/core/game_state.gd` constants and fields**

Add after `const DEFAULT_HERO_MAX_HP := 120`:

```gdscript
const DEFAULT_HERO_MAX_MP := 20
```

Add after `var hero_max_hp := DEFAULT_HERO_MAX_HP`:

```gdscript
var hero_max_mp := DEFAULT_HERO_MAX_MP
```

- [ ] **Step 4: Initialize and serialize `hero_max_mp`**

In `start_new_game()`, add after `hero_max_hp = DEFAULT_HERO_MAX_HP`:

```gdscript
	hero_max_mp = DEFAULT_HERO_MAX_MP
```

In `to_dictionary()`, add after `"hero_max_hp": hero_max_hp,`:

```gdscript
		"hero_max_mp": hero_max_mp,
```

In `from_dictionary(data)`, add after the `hero_max_hp` fallback block:

```gdscript
	hero_max_mp = int(data.get("hero_max_mp", DEFAULT_HERO_MAX_MP))
	if hero_max_mp <= 0:
		hero_max_mp = DEFAULT_HERO_MAX_MP
```

- [ ] **Step 5: Run tests to verify Task 2 passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with:

```text
测试通过：32 个测试套件
```

- [ ] **Step 6: Commit Task 2**

```powershell
git add scripts/core/game_state.gd tests/test_combat_and_save.gd
git commit -m "feat: save hero max mp"
```

---

### Task 3: TacticalUnitState 内力与武学列表

**Files:**
- Modify: `scripts/domain/tactical_unit_state.gd`
- Modify: `tests/test_tactical_unit_state.gd`

- [ ] **Step 1: Write failing unit-state tests**

In `tests/test_tactical_unit_state.gd`, add these fields to the `unit.from_dictionary({...})` fixture:

```gdscript
		"mp": 12,
		"max_mp": 20,
		"martial_art_ids": ["basic_sword", "straight_sword_thrust"],
```

Add these assertions after the existing `charge`/cell assertions:

```gdscript
	assertions.assert_eq(unit.mp, 12, "战棋单位应读取当前内力")
	assertions.assert_eq(unit.max_mp, 20, "战棋单位应读取最大内力")
	assertions.assert_eq(unit.martial_art_ids.size(), 2, "战棋单位应读取可用武学列表")
	assertions.assert_true(unit.martial_art_ids.has("straight_sword_thrust"), "战棋单位应保存穿云刺编号")
```

Add these serialization assertions after `var serialized = unit.to_dictionary()`:

```gdscript
	assertions.assert_eq(serialized.get("mp", -1), 12, "单位序列化应保存当前内力")
	assertions.assert_eq(serialized.get("max_mp", -1), 20, "单位序列化应保存最大内力")
	assertions.assert_true(serialized.get("martial_art_ids", []).has("basic_sword"), "单位序列化应保存武学列表")
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL with missing `mp`, `max_mp`, or `martial_art_ids` properties.

- [ ] **Step 3: Replace `scripts/domain/tactical_unit_state.gd`**

Replace the file with:

```gdscript
class_name TacticalUnitState
extends RefCounted

const TEAM_PLAYER := "player"
const TEAM_ENEMY := "enemy"

var unit_id: String = ""
var actor_id: String = ""
var display_name: String = ""
var team: String = TEAM_ENEMY
var hp: int = 1
var max_hp: int = 1
var mp: int = 0
var max_mp: int = 0
var attack: int = 1
var defense: int = 0
var move_range: int = 3
var attack_range: int = 1
var charge_speed: int = 200
var charge: int = 0
var cell: Dictionary = {"q": 0, "r": 0}
var martial_art_ids: Array[String] = []

func is_alive() -> bool:
	return hp > 0

func reset_charge() -> void:
	charge = 0

func to_dictionary() -> Dictionary:
	return {
		"unit_id": unit_id,
		"actor_id": actor_id,
		"display_name": display_name,
		"team": team,
		"hp": hp,
		"max_hp": max_hp,
		"mp": mp,
		"max_mp": max_mp,
		"attack": attack,
		"defense": defense,
		"move_range": move_range,
		"attack_range": attack_range,
		"charge_speed": charge_speed,
		"charge": charge,
		"cell": cell.duplicate(true),
		"martial_art_ids": martial_art_ids.duplicate(),
	}

func from_dictionary(data: Dictionary) -> void:
	unit_id = str(data.get("unit_id", ""))
	actor_id = str(data.get("actor_id", ""))
	display_name = str(data.get("display_name", actor_id))
	team = str(data.get("team", TEAM_ENEMY))
	if team.is_empty():
		team = TEAM_ENEMY
	max_hp = max(1, int(data.get("max_hp", data.get("hp", 1))))
	hp = clamp(int(data.get("hp", max_hp)), 0, max_hp)
	max_mp = max(0, int(data.get("max_mp", 0)))
	mp = clamp(int(data.get("mp", max_mp)), 0, max_mp)
	attack = max(1, int(data.get("attack", 1)))
	defense = max(0, int(data.get("defense", 0)))
	move_range = max(0, int(data.get("move_range", 3)))
	attack_range = max(1, int(data.get("attack_range", 1)))
	charge_speed = max(1, int(data.get("charge_speed", 200)))
	charge = max(0, int(data.get("charge", 0)))
	cell = _read_cell(data.get("cell", data.get("start_cell", {})))
	martial_art_ids = _to_string_array(data.get("martial_art_ids", []))

func _read_cell(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {"q": 0, "r": 0}
	return {
		"q": int(value.get("q", 0)),
		"r": int(value.get("r", 0)),
	}

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		var normalized = str(item)
		if not normalized.is_empty():
			result.append(normalized)
	return result
```

- [ ] **Step 4: Run tests to verify Task 3 passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with:

```text
测试通过：32 个测试套件
```

- [ ] **Step 5: Commit Task 3**

```powershell
git add scripts/domain/tactical_unit_state.gd tests/test_tactical_unit_state.gd
git commit -m "feat: track tactical unit mp"
```

---

### Task 4: TacticalCombatSystem 武学攻击规则

**Files:**
- Modify: `scripts/systems/tactical_combat_system.gd`
- Modify: `tests/test_tactical_combat_system.gd`

- [ ] **Step 1: Write failing combat-system tests**

In `tests/test_tactical_combat_system.gd`, after the existing assertions that inspect the created hero unit, add:

```gdscript
	assertions.assert_eq(battle.get_unit("hero").max_mp, 20, "玩家战棋单位应读取 GameState 最大内力")
	assertions.assert_eq(battle.get_unit("hero").mp, 20, "玩家战棋单位开战时内力应回满")
	assertions.assert_true(battle.get_unit("hero").martial_art_ids.has("basic_sword"), "玩家战棋单位应读取基础剑法")
	assertions.assert_true(battle.get_unit("hero").martial_art_ids.has("straight_sword_thrust"), "玩家战棋单位应读取穿云刺")
```

After the existing normal attack assertions, add:

```gdscript
	var skill_battle = system.create_battle(state, _sample_context(), repository)
	skill_battle.get_unit("hero").cell = {"q": 4, "r": 2}
	var skill_result = system.use_martial_art(skill_battle, "hero", "bandit", "basic_sword", repository)
	assertions.assert_true(bool(skill_result.get("success", false)), "内力足够且近身时应能使用基础剑法")
	assertions.assert_eq(skill_result.get("damage", 0), 20, "基础剑法伤害应为攻击加招式加值再减防御")
	assertions.assert_eq(skill_battle.get_unit("bandit").hp, 40, "基础剑法应扣除敌人气血")
	assertions.assert_eq(skill_battle.get_unit("hero").mp, 17, "基础剑法应消耗 3 点内力")
	assertions.assert_true(skill_battle.log.has("云游少侠使出基础剑法攻击山道强人，造成20点伤害。"), "基础剑法应写入战斗日志")

	var line_battle = system.create_battle(state, _sample_context(), repository)
	line_battle.get_unit("hero").cell = {"q": 3, "r": 2}
	var line_targets = system.get_attackable_units_for_martial_art(line_battle, "hero", "straight_sword_thrust", repository)
	assertions.assert_eq(line_targets.size(), 1, "穿云刺应能选中两格直线目标")
	assertions.assert_eq(line_targets[0].unit_id, "bandit", "穿云刺直线目标应为山道强人")
	var line_result = system.use_martial_art(line_battle, "hero", "bandit", "straight_sword_thrust", repository)
	assertions.assert_true(bool(line_result.get("success", false)), "穿云刺应能攻击两格直线目标")
	assertions.assert_eq(line_result.get("damage", 0), 18, "穿云刺伤害应使用战棋伤害加值")
	assertions.assert_eq(line_battle.get_unit("hero").mp, 15, "穿云刺应消耗 5 点内力")

	var diagonal_battle = system.create_battle(state, _sample_context(), repository)
	diagonal_battle.get_unit("hero").cell = {"q": 4, "r": 1}
	var diagonal_result = system.use_martial_art(diagonal_battle, "hero", "bandit", "straight_sword_thrust", repository)
	assertions.assert_true(not bool(diagonal_result.get("success", false)), "穿云刺不能攻击斜向目标")
	assertions.assert_eq(diagonal_battle.get_unit("hero").mp, 20, "招式失败不应扣内力")

	var low_mp_battle = system.create_battle(state, _sample_context(), repository)
	low_mp_battle.get_unit("hero").cell = {"q": 4, "r": 2}
	low_mp_battle.get_unit("hero").mp = 2
	var low_mp_result = system.use_martial_art(low_mp_battle, "hero", "bandit", "basic_sword", repository)
	assertions.assert_true(not bool(low_mp_result.get("success", false)), "内力不足时基础剑法应失败")
	assertions.assert_eq(low_mp_battle.get_unit("hero").mp, 2, "内力不足失败不应扣资源")

	var unknown_skill_result = system.use_martial_art(skill_battle, "hero", "bandit", "rough_fist", repository)
	assertions.assert_true(not bool(unknown_skill_result.get("success", false)), "不能使用未学会的武学")
```

In the existing `finish_battle` block, after normal-attack finish assertions, add:

```gdscript
	var skill_finish_battle = system.create_battle(state, _sample_context(), repository)
	skill_finish_battle.get_unit("hero").cell = {"q": 4, "r": 2}
	skill_finish_battle.get_unit("bandit").hp = 1
	skill_finish_battle.get_unit("lackey").hp = 0
	system.use_martial_art(skill_finish_battle, "hero", "bandit", "basic_sword", repository)
	assertions.assert_true(skill_finish_battle.is_finished, "武学击败全部敌人后战棋应结束")
	assertions.assert_true(skill_finish_battle.victory, "武学击败全部敌人后应标记胜利")
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `use_martial_art`, `get_attackable_units_for_martial_art`, unit MP, or unit martial art IDs are not wired into battle creation yet.

- [ ] **Step 3: Add MartialArtRecord preload**

At the top of `scripts/systems/tactical_combat_system.gd`, add after existing preloads:

```gdscript
const MartialArtRecordScript = preload("res://scripts/domain/martial_art_record.gd")
```

- [ ] **Step 4: Add public martial-art query and attack methods**

Add these methods after `get_attackable_units(battle, unit_id: String) -> Array`:

```gdscript
func get_attackable_units_for_martial_art(battle, unit_id: String, martial_art_id: String, data_source = null) -> Array:
	var unit = battle.get_unit(unit_id) if battle != null else null
	if unit == null or not unit.is_alive():
		return []
	var martial_art = _get_tactical_martial_art(martial_art_id, data_source)
	if martial_art == null:
		return []
	if not unit.martial_art_ids.has(martial_art.id):
		return []
	if unit.mp < martial_art.tactical_mp_cost:
		return []
	var result: Array = []
	for target in battle.units:
		if not target.is_alive() or target.team == unit.team:
			continue
		if _is_target_in_martial_range(unit.cell, target.cell, martial_art):
			result.append(target)
	return result

func use_martial_art(battle, attacker_id: String, defender_id: String, martial_art_id: String, data_source = null) -> Dictionary:
	var attacker = battle.get_unit(attacker_id) if battle != null else null
	var defender = battle.get_unit(defender_id) if battle != null else null
	if attacker == null or defender == null:
		return {"success": false, "message": "武学目标不存在。"}
	if not attacker.is_alive() or not defender.is_alive():
		return {"success": false, "message": "武学目标已倒下。"}
	if attacker.team == defender.team:
		return {"success": false, "message": "不能攻击同伴。"}
	if not attacker.martial_art_ids.has(martial_art_id):
		return {"success": false, "message": "不能使用未学会的武学。"}
	var martial_art = _get_tactical_martial_art(martial_art_id, data_source)
	if martial_art == null:
		return {"success": false, "message": "此武学不能用于战棋。"}
	if attacker.mp < martial_art.tactical_mp_cost:
		return {"success": false, "message": "内力不足。"}
	if not _is_target_in_martial_range(attacker.cell, defender.cell, martial_art):
		return {"success": false, "message": "目标不在招式范围内。"}

	var damage = maxi(1, attacker.attack + martial_art.tactical_damage_bonus - defender.defense)
	attacker.mp = max(0, attacker.mp - martial_art.tactical_mp_cost)
	defender.hp = max(0, defender.hp - damage)
	battle.append_log("%s使出%s攻击%s，造成%d点伤害。" % [attacker.display_name, martial_art.name, defender.display_name, damage])
	if defender.hp <= 0:
		battle.append_log("%s被击败。" % defender.display_name)
	check_battle_finished(battle)
	return {"success": true, "message": "已经出招。", "damage": damage}
```

- [ ] **Step 5: Update `_build_unit()` to attach MP and martial arts**

In `_build_unit(raw_unit, game_state, source)`, add after defense assignment:

```gdscript
	unit_data["martial_art_ids"] = actor.get("martial_arts", [])
	unit_data["max_mp"] = max(0, int(raw_unit.get("max_mp", 0)))
	unit_data["mp"] = clamp(int(raw_unit.get("mp", unit_data["max_mp"])), 0, int(unit_data["max_mp"]))
```

Inside the existing player branch, add after the HP assignments:

```gdscript
		unit_data["max_mp"] = max(0, int(game_state.hero_max_mp))
		unit_data["mp"] = int(unit_data["max_mp"])
```

- [ ] **Step 6: Add private martial-art helpers**

Add these helper methods before `_first_living_player(battle)`:

```gdscript
func _get_tactical_martial_art(martial_art_id: String, data_source = null):
	if martial_art_id.is_empty():
		return null
	var source = data_source if data_source != null else repository
	if source == null or not source.has_method("get_martial_art"):
		return null
	var martial_art_data = source.get_martial_art(martial_art_id)
	if martial_art_data.is_empty():
		return null
	var martial_art = MartialArtRecordScript.from_dictionary(martial_art_data)
	if not martial_art.has_tactical_config():
		return null
	if not ["diamond", "line"].has(martial_art.tactical_range_shape):
		return null
	return martial_art

func _is_target_in_martial_range(attacker_cell: Dictionary, defender_cell: Dictionary, martial_art) -> bool:
	var distance = _cell_distance(attacker_cell, defender_cell)
	if distance <= 0 or distance > martial_art.tactical_range:
		return false
	match martial_art.tactical_range_shape:
		"diamond":
			return true
		"line":
			return int(attacker_cell.get("q", 0)) == int(defender_cell.get("q", 0)) or int(attacker_cell.get("r", 0)) == int(defender_cell.get("r", 0))
		_:
			return false
```

- [ ] **Step 7: Run tests to verify Task 4 passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with:

```text
测试通过：32 个测试套件
```

- [ ] **Step 8: Commit Task 4**

```powershell
git add scripts/systems/tactical_combat_system.gd tests/test_tactical_combat_system.gd
git commit -m "feat: add tactical martial art attacks"
```

---

### Task 5: BattleScreen 战棋招式 UI

**Files:**
- Modify: `scripts/scenes/battle_screen.gd`
- Modify: `tests/test_tactical_battle_screen.gd`

- [ ] **Step 1: Write failing battle-screen UI tests**

In `tests/test_tactical_battle_screen.gd`, after the existing property checks for `tactical_combat_system`, add:

```gdscript
	assertions.assert_true(_has_property(screen, "normal_attack_button"), "战斗界面应暴露普通攻击按钮")
	assertions.assert_true(_has_property(screen, "tactical_art_buttons"), "战斗界面应暴露招式按钮字典")
	assertions.assert_true(_has_property(screen, "selected_tactical_action_id"), "战斗界面应暴露当前战棋动作")
```

After the existing assertions that inspect `end_action_button`, add:

```gdscript
	assertions.assert_true(screen.normal_attack_button != null, "战棋模式应创建普通攻击按钮")
	assertions.assert_true(screen.tactical_art_buttons.has("basic_sword"), "战棋模式应创建基础剑法按钮")
	assertions.assert_true(screen.tactical_art_buttons.has("straight_sword_thrust"), "战棋模式应创建穿云刺按钮")
	assertions.assert_eq(screen.selected_tactical_action_id, "attack", "战棋默认动作应为普通攻击")
```

After the existing `status_label` assertion for `"云游少侠行动"`, add:

```gdscript
	assertions.assert_true(screen.status_label.text.contains("内力 20/20"), "玩家行动时状态文本应显示内力")
	assertions.assert_true(not screen.normal_attack_button.disabled, "玩家行动时普通攻击按钮应可用")
	assertions.assert_true(not screen.tactical_art_buttons.get("basic_sword").disabled, "内力足够时基础剑法按钮应可用")
	screen.tactical_battle_state.get_unit("hero").cell = {"q": 3, "r": 2}
	screen.tactical_battle_state.get_unit("bandit").hp = screen.tactical_battle_state.get_unit("bandit").max_hp
	screen._on_tactical_action_selected("straight_sword_thrust")
	assertions.assert_eq(screen.selected_tactical_action_id, "straight_sword_thrust", "点击穿云刺按钮应切换当前动作")
	screen._refresh_tactical()
	assertions.assert_true(not screen.cell_buttons.get("5:2").disabled, "选中穿云刺时两格直线敌人应可点击")
	screen.tactical_battle_state.get_unit("hero").mp = 2
	screen._refresh_tactical()
	assertions.assert_true(screen.tactical_art_buttons.get("basic_sword").disabled, "内力不足时基础剑法按钮应禁用")
	assertions.assert_true(screen.tactical_art_buttons.get("straight_sword_thrust").disabled, "内力不足时穿云刺按钮应禁用")
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because battle screen has no tactical action buttons or selected action state.

- [ ] **Step 3: Add BattleScreen tactical action variables**

In `scripts/scenes/battle_screen.gd`, add after `var end_action_button: Button`:

```gdscript
var normal_attack_button: Button
var tactical_art_buttons: Dictionary = {}
var selected_tactical_action_id: String = "attack"
```

- [ ] **Step 4: Create tactical action buttons**

In `_create_tactical_ui()`, replace the current end action and retreat button positioning block with:

```gdscript
	normal_attack_button = Button.new()
	normal_attack_button.text = "普通攻击"
	normal_attack_button.position = Vector2(820, 560)
	normal_attack_button.size = Vector2(112, 36)
	normal_attack_button.pressed.connect(_on_tactical_action_selected.bind("attack"))
	add_child(normal_attack_button)

	_create_tactical_art_button("basic_sword", Vector2(940, 560))
	_create_tactical_art_button("straight_sword_thrust", Vector2(1060, 560))

	end_action_button = Button.new()
	end_action_button.text = "结束行动"
	end_action_button.position = Vector2(820, 610)
	end_action_button.size = Vector2(120, 40)
	end_action_button.pressed.connect(_on_tactical_end_action_pressed)
	add_child(end_action_button)

	retreat_button = Button.new()
	retreat_button.text = "暂退"
	retreat_button.position = Vector2(960, 610)
	retreat_button.size = Vector2(120, 40)
	retreat_button.pressed.connect(_on_tactical_retreat_pressed)
	add_child(retreat_button)
```

Add this helper method after `_create_tactical_grid()`:

```gdscript
func _create_tactical_art_button(martial_art_id: String, button_position: Vector2) -> void:
	var martial_art = DataRepository.get_martial_art(martial_art_id)
	if martial_art.is_empty() or typeof(martial_art.get("tactical", {})) != TYPE_DICTIONARY:
		return
	var button = Button.new()
	button.text = str(martial_art.get("name", martial_art_id))
	button.position = button_position
	button.size = Vector2(112, 36)
	button.pressed.connect(_on_tactical_action_selected.bind(martial_art_id))
	add_child(button)
	tactical_art_buttons[martial_art_id] = button
```

- [ ] **Step 5: Replace `_refresh_tactical()`**

Replace the current `_refresh_tactical()` method with:

```gdscript
func _refresh_tactical() -> void:
	if tactical_battle_state == null:
		return
	var current = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
	if tactical_battle_state.is_finished:
		status_label.text = "战斗结束"
	elif current != null and current.team == TacticalBattleStateScript.TEAM_PLAYER:
		status_label.text = "%s行动 内力 %d/%d" % [current.display_name, current.mp, current.max_mp]
	elif current != null:
		status_label.text = "%s行动" % current.display_name
	else:
		status_label.text = "等待集气"

	for child in unit_panel.get_children():
		child.queue_free()
	for unit in tactical_battle_state.units:
		var label = Label.new()
		label.text = "%s 气血:%d/%d 集气:%d/%d" % [
			unit.display_name,
			unit.hp,
			unit.max_hp,
			unit.charge,
			TacticalBattleStateScript.CHARGE_LIMIT,
		]
		unit_panel.add_child(label)

	var movable: Array = []
	var attackable: Array = []
	if _is_player_action():
		movable = tactical_combat_system.get_movable_cells(tactical_battle_state, tactical_battle_state.current_unit_id)
		attackable = _get_attackable_units_for_selected_action()
	for key in cell_buttons.keys():
		var button = cell_buttons[key]
		button.text = ""
		button.disabled = true
		if cell_visuals.has(key):
			_apply_tactical_cell_visual_style(cell_visuals[key], "idle")
	for unit in tactical_battle_state.units:
		if not unit.is_alive():
			continue
		var unit_key = _cell_key(unit.cell)
		if cell_buttons.has(unit_key):
			cell_buttons[unit_key].text = unit.display_name.substr(0, 2)
	for cell in movable:
		var move_key = _cell_key(cell)
		if cell_buttons.has(move_key):
			cell_buttons[move_key].disabled = false
		if cell_visuals.has(move_key):
			_apply_tactical_cell_visual_style(cell_visuals[move_key], "move")
	for target in attackable:
		var target_key = _cell_key(target.cell)
		if cell_buttons.has(target_key):
			cell_buttons[target_key].disabled = false
		if cell_visuals.has(target_key):
			_apply_tactical_cell_visual_style(cell_visuals[target_key], "attack")

	output.text = "\n".join(PackedStringArray(tactical_battle_state.log))
	_refresh_tactical_action_buttons(current)
	end_action_button.disabled = tactical_battle_state.is_finished or not _is_player_action()
	retreat_button.disabled = tactical_battle_state.is_finished
```

- [ ] **Step 6: Replace tactical cell click handling**

Replace `_on_tactical_cell_pressed(q: int, r: int)` with:

```gdscript
func _on_tactical_cell_pressed(q: int, r: int) -> void:
	if not _is_player_action():
		return
	var current_unit = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
	if current_unit == null:
		return
	var cell = {"q": q, "r": r}
	var target = _unit_at_cell(cell)
	if target != null and target.team != current_unit.team:
		var result: Dictionary
		if selected_tactical_action_id == "attack":
			result = tactical_combat_system.attack_unit(tactical_battle_state, current_unit.unit_id, target.unit_id)
		else:
			result = tactical_combat_system.use_martial_art(tactical_battle_state, current_unit.unit_id, target.unit_id, selected_tactical_action_id, DataRepository)
		if bool(result.get("success", false)) and not tactical_battle_state.is_finished:
			tactical_combat_system.end_unit_action(tactical_battle_state, current_unit.unit_id)
	else:
		tactical_combat_system.move_unit(tactical_battle_state, current_unit.unit_id, cell)
	_refresh_tactical()
	_return_if_tactical_finished()
```

- [ ] **Step 7: Add tactical action helpers**

Add these methods before `_on_tactical_end_action_pressed()`:

```gdscript
func _on_tactical_action_selected(action_id: String) -> void:
	if action_id.is_empty():
		return
	selected_tactical_action_id = action_id
	_refresh_tactical()

func _get_attackable_units_for_selected_action() -> Array:
	if selected_tactical_action_id == "attack":
		return tactical_combat_system.get_attackable_units(tactical_battle_state, tactical_battle_state.current_unit_id)
	return tactical_combat_system.get_attackable_units_for_martial_art(tactical_battle_state, tactical_battle_state.current_unit_id, selected_tactical_action_id, DataRepository)

func _refresh_tactical_action_buttons(current_unit) -> void:
	var can_act = _is_player_action() and current_unit != null
	if normal_attack_button != null:
		normal_attack_button.disabled = not can_act
	for martial_art_id in tactical_art_buttons.keys():
		var button = tactical_art_buttons[martial_art_id]
		button.disabled = not can_act or not _can_current_unit_use_tactical_art(current_unit, str(martial_art_id))
	if selected_tactical_action_id != "attack":
		var selected_button = tactical_art_buttons.get(selected_tactical_action_id)
		if selected_button == null or selected_button.disabled:
			selected_tactical_action_id = "attack"

func _can_current_unit_use_tactical_art(current_unit, martial_art_id: String) -> bool:
	if current_unit == null or not current_unit.martial_art_ids.has(martial_art_id):
		return false
	var martial_art = DataRepository.get_martial_art(martial_art_id)
	if martial_art.is_empty():
		return false
	var tactical = martial_art.get("tactical", {})
	if typeof(tactical) != TYPE_DICTIONARY:
		return false
	var mp_cost = max(0, int(tactical.get("mp_cost", martial_art.get("cost", 0))))
	return current_unit.mp >= mp_cost
```

- [ ] **Step 8: Run tests to verify Task 5 passes**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with:

```text
测试通过：32 个测试套件
```

- [ ] **Step 9: Commit Task 5**

```powershell
git add scripts/scenes/battle_screen.gd tests/test_tactical_battle_screen.gd
git commit -m "feat: add tactical martial art controls"
```

---

### Task 6: Documentation and Final Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/godot-project-structure.md`

- [ ] **Step 1: Update README current target list**

In `README.md`, add this bullet after the existing方格战棋与集气基础切片 bullet:

```markdown
- 战棋武学与内力基础切片：主角战棋开局按最大内力回满，可在普通攻击、基础剑法和两格直线剑招之间选择，武学消耗内力并通过 `TacticalCombatSystem` 统一结算范围、伤害和胜负。
```

- [ ] **Step 2: Update project structure documentation**

In `docs/godot-project-structure.md`, add this section after the方格战棋与集气基础切片 section:

```markdown
## 战棋武学与内力基础切片

战棋武学切片使用 `data/martial_arts.json` 的 `tactical` 字段声明战棋伤害加值、内力消耗、范围和范围形状。`GameState` 只保存主角长期最大内力；战棋单位的当前内力保存在 `TacticalUnitState`，每场战斗开局回满。`TacticalCombatSystem` 是普通攻击和武学攻击的统一规则入口，负责校验武学归属、内力、范围、伤害和胜负；`BattleScreen` 只负责动作按钮、内力显示、格子高亮和点击接线。
```

- [ ] **Step 3: Run full automated test suite**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：32 个测试套件
```

The existing expected error-path diagnostics may still print; the command exit code must be `0`.

- [ ] **Step 4: Verify working tree only contains intended changes**

Run:

```powershell
git status --short
```

Expected:

```text
 M README.md
 M docs/godot-project-structure.md
```

If earlier tasks were committed as instructed, only the two documentation files should remain modified before the final documentation commit.

- [ ] **Step 5: Commit Task 6**

```powershell
git add README.md docs/godot-project-structure.md
git commit -m "docs: record tactical martial arts slice"
```

- [ ] **Step 6: Final status check**

Run:

```powershell
git status --short
```

Expected: no output.

---

## Plan Self-Review

- Spec coverage: Task 1 covers martial art data and tactical record parsing; Task 2 covers long-term max MP and save compatibility; Task 3 covers tactical unit MP and learned martial arts; Task 4 covers martial art legality, range, MP, damage and victory; Task 5 covers UI display, buttons, selected action and highlighters; Task 6 covers documentation and final verification.
- Scope control: The plan excludes enemy martial art AI, long-term current MP, recovery systems, character panels, terrain, AOE, status effects and encounter extraction.
- Type consistency: The plan uses `hero_max_mp`, `mp`, `max_mp`, `martial_art_ids`, `tactical_damage_bonus`, `tactical_range`, `tactical_range_shape`, `tactical_mp_cost`, `use_martial_art()` and `get_attackable_units_for_martial_art()` consistently across tests, data and implementation steps.
- Verification: Every task has a failing test step, an implementation step, a passing test step and a commit step. The final suite count remains `32` because all tests extend existing suites.
