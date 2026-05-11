# 菱形战棋与集气基础切片 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有山道强人战替换为 `1v2` 菱形格战棋战斗，并引入实时 `0-1000` 集气、行动暂停、移动后攻击、敌人 AI、暂退和现有胜利回流。

**Architecture:** 新增 `TacticalUnitState`、`TacticalBattleState` 和 `TacticalCombatSystem`，保持领域状态、系统规则、场景表现分层。`mountain_pass_screen.gd` 把地图战斗对象配置传入现有 `battle.tscn`，`battle_screen.gd` 按 `battle_mode` 分流普通回合战斗或战棋战斗。战棋胜负仍生成 `GameState.apply_battle_result()` 可处理的 payload，避免把任务、地图对象和熟练度奖励写进战棋系统。

**Tech Stack:** Godot 4.6、GDScript、JSON 内容数据、项目本地 Godot headless 测试运行器、PowerShell。

---

## Scope Check

本计划覆盖一个单一可交付切片：替换山道强人战斗表现与规则。它涉及领域对象、战斗系统、地图数据、战斗 UI 和文档，但都服务同一条玩家流程：山道触发战棋战斗，胜利或暂退后回到地图。

本计划明确不实现战斗中用药、多武学、技能范围、队友控制、地形障碍、战斗存档、独立遭遇数据文件和玩家可切换双模式 UI。当前普通回合战斗代码保留，用于兼容没有声明 `battle_mode = "tactical"` 的战斗上下文。

## File Structure

```text
data/actors.json                                      # 新增山道喽啰 actor 数据
data/maps.json                                        # 为 enemy_bandit_gate 声明战棋配置
docs/godot-project-structure.md                       # 记录战棋集气切片的分层规则
README.md                                             # 更新当前目标列表
scripts/domain/tactical_unit_state.gd                 # 单个战棋单位运行时状态
scripts/domain/tactical_battle_state.gd               # 一场战棋战斗运行时状态和结算 payload
scripts/scenes/battle_screen.gd                       # 按 battle_mode 分流普通战斗和战棋战斗 UI
scripts/scenes/mountain_pass_screen.gd                # 把战斗触发对象配置传入 battle_context
scripts/systems/tactical_combat_system.gd             # 集气、移动、攻击、AI、胜负和暂退规则
tests/run_tests.gd                                    # 接入新增测试套件
tests/test_tactical_unit_state.gd                     # TacticalUnitState 测试
tests/test_tactical_battle_state.gd                   # TacticalBattleState 测试
tests/test_tactical_combat_system.gd                  # TacticalCombatSystem 测试
tests/test_map_data.gd                                # 战棋地图配置和山道喽啰数据测试
tests/test_tactical_battle_screen.gd                  # 战棋战斗场景基础 UI 测试
```

---

### Task 1: 添加 TacticalUnitState 领域对象

**Files:**
- Create: `tests/test_tactical_unit_state.gd`
- Modify: `tests/run_tests.gd`
- Create: `scripts/domain/tactical_unit_state.gd`

- [ ] **Step 1: 写失败测试 `tests/test_tactical_unit_state.gd`**

Create `tests/test_tactical_unit_state.gd`:

```gdscript
extends RefCounted

const TacticalUnitStateScript = preload("res://scripts/domain/tactical_unit_state.gd")

func run(assertions) -> void:
	var unit = TacticalUnitStateScript.new()
	unit.from_dictionary({
		"unit_id": "hero",
		"actor_id": "hero_yun",
		"display_name": "云游少侠",
		"team": "player",
		"hp": 90,
		"max_hp": 120,
		"attack": 18,
		"defense": 8,
		"move_range": 3,
		"attack_range": 1,
		"charge_speed": 240,
		"charge": 700,
		"cell": {"q": 1, "r": 2},
	})

	assertions.assert_eq(unit.unit_id, "hero", "战棋单位应读取单位编号")
	assertions.assert_eq(unit.actor_id, "hero_yun", "战棋单位应读取角色编号")
	assertions.assert_eq(unit.display_name, "云游少侠", "战棋单位应读取显示名")
	assertions.assert_eq(unit.team, "player", "战棋单位应读取阵营")
	assertions.assert_eq(unit.hp, 90, "战棋单位应读取当前气血")
	assertions.assert_eq(unit.max_hp, 120, "战棋单位应读取最大气血")
	assertions.assert_eq(unit.cell.get("q", -1), 1, "战棋单位应读取 q 坐标")
	assertions.assert_eq(unit.cell.get("r", -1), 2, "战棋单位应读取 r 坐标")
	assertions.assert_true(unit.is_alive(), "气血大于 0 的单位应存活")

	unit.reset_charge()
	assertions.assert_eq(unit.charge, 0, "清空集气后 charge 应为 0")

	var serialized = unit.to_dictionary()
	assertions.assert_eq(serialized.get("unit_id", ""), "hero", "单位序列化应保存单位编号")
	assertions.assert_eq(serialized.get("cell", {}).get("q", -1), 1, "单位序列化应保存 q 坐标")
	assertions.assert_eq(serialized.get("charge", -1), 0, "单位序列化应保存当前集气")

	unit.hp = 0
	assertions.assert_true(not unit.is_alive(), "气血为 0 的单位不应存活")
```

- [ ] **Step 2: 将测试加入 `tests/run_tests.gd` 并确认失败**

Add preload near the other test preloads:

```gdscript
const TestTacticalUnitStateScript = preload("res://tests/test_tactical_unit_state.gd")
```

Add the suite before `TestBattleStateScript.new()`:

```gdscript
		TestTacticalUnitStateScript.new(),
```

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `res://scripts/domain/tactical_unit_state.gd` does not exist.

- [ ] **Step 3: 创建 `scripts/domain/tactical_unit_state.gd`**

Create `scripts/domain/tactical_unit_state.gd`:

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
var attack: int = 1
var defense: int = 0
var move_range: int = 3
var attack_range: int = 1
var charge_speed: int = 200
var charge: int = 0
var cell: Dictionary = {"q": 0, "r": 0}

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
		"attack": attack,
		"defense": defense,
		"move_range": move_range,
		"attack_range": attack_range,
		"charge_speed": charge_speed,
		"charge": charge,
		"cell": cell.duplicate(true),
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
	attack = max(1, int(data.get("attack", 1)))
	defense = max(0, int(data.get("defense", 0)))
	move_range = max(0, int(data.get("move_range", 3)))
	attack_range = max(1, int(data.get("attack_range", 1)))
	charge_speed = max(1, int(data.get("charge_speed", 200)))
	charge = max(0, int(data.get("charge", 0)))
	cell = _read_cell(data.get("cell", data.get("start_cell", {})))

func _read_cell(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {"q": 0, "r": 0}
	return {
		"q": int(value.get("q", 0)),
		"r": int(value.get("r", 0)),
	}
```

- [ ] **Step 4: 运行测试并确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS, with suite count increased by 1 from the previous baseline.

- [ ] **Step 5: 提交**

```powershell
git add scripts/domain/tactical_unit_state.gd tests/test_tactical_unit_state.gd tests/run_tests.gd
git commit -m "feat: 添加战棋单位状态"
```

---

### Task 2: 添加 TacticalBattleState 领域对象

**Files:**
- Create: `tests/test_tactical_battle_state.gd`
- Modify: `tests/run_tests.gd`
- Create: `scripts/domain/tactical_battle_state.gd`

- [ ] **Step 1: 写失败测试 `tests/test_tactical_battle_state.gd`**

Create `tests/test_tactical_battle_state.gd`:

```gdscript
extends RefCounted

const TacticalBattleStateScript = preload("res://scripts/domain/tactical_battle_state.gd")
const TacticalUnitStateScript = preload("res://scripts/domain/tactical_unit_state.gd")

func run(assertions) -> void:
	var battle = TacticalBattleStateScript.new()
	battle.source_map_id = "mountain_pass"
	battle.source_object_id = "enemy_bandit_gate"
	battle.quest_id = "quest_mountain_trial"
	battle.reward_martial_art_id = "basic_sword"
	battle.proficiency_reward = 1
	battle.time_mode = "pause_on_action"
	battle.battlefield_width = 7
	battle.battlefield_height = 5

	var hero = TacticalUnitStateScript.new()
	hero.from_dictionary({
		"unit_id": "hero",
		"actor_id": "hero_yun",
		"display_name": "云游少侠",
		"team": "player",
		"hp": 88,
		"max_hp": 120,
		"cell": {"q": 1, "r": 2},
	})
	battle.add_unit(hero)

	var enemy = TacticalUnitStateScript.new()
	enemy.from_dictionary({
		"unit_id": "bandit",
		"actor_id": "bandit_01",
		"display_name": "山道强人",
		"team": "enemy",
		"hp": 60,
		"max_hp": 60,
		"cell": {"q": 5, "r": 2},
	})
	battle.add_unit(enemy)

	assertions.assert_eq(battle.get_unit("hero").display_name, "云游少侠", "战棋战斗应能按单位编号取单位")
	assertions.assert_eq(battle.get_living_units_by_team("enemy").size(), 1, "战棋战斗应能读取存活敌人")
	assertions.assert_true(battle.has_living_team("player"), "玩家阵营有存活单位")
	assertions.assert_true(battle.has_living_team("enemy"), "敌方阵营有存活单位")

	battle.current_unit_id = "hero"
	battle.is_action_phase = true
	battle.append_log("云游少侠蓄势待发。")
	var serialized = battle.to_dictionary()
	assertions.assert_eq(serialized.get("current_unit_id", ""), "hero", "战棋战斗序列化应保存当前行动单位")
	assertions.assert_eq(serialized.get("units", []).size(), 2, "战棋战斗序列化应保存单位列表")
	assertions.assert_eq(serialized.get("log", []).size(), 1, "战棋战斗序列化应保存日志")

	battle.finish(true)
	var payload = battle.to_result_dictionary()
	assertions.assert_true(bool(payload.get("victory", false)), "战棋胜利结果应标记 victory")
	assertions.assert_eq(payload.get("hero_hp", 0), 88, "战棋结果应带回主角气血")
	assertions.assert_eq(payload.get("source_object_id", ""), "enemy_bandit_gate", "战棋结果应带回来源对象")
	assertions.assert_eq(payload.get("quest_id", ""), "quest_mountain_trial", "战棋结果应带回任务编号")
	assertions.assert_eq(payload.get("martial_art_id", ""), "basic_sword", "战棋结果应带回成长武学")
	assertions.assert_eq(payload.get("proficiency_reward", 0), 1, "战棋结果应带回熟练度奖励")
```

- [ ] **Step 2: 将测试加入 `tests/run_tests.gd` 并确认失败**

Add preload:

```gdscript
const TestTacticalBattleStateScript = preload("res://tests/test_tactical_battle_state.gd")
```

Add the suite after `TestTacticalUnitStateScript.new()`:

```gdscript
		TestTacticalBattleStateScript.new(),
```

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `res://scripts/domain/tactical_battle_state.gd` does not exist.

- [ ] **Step 3: 创建 `scripts/domain/tactical_battle_state.gd`**

Create `scripts/domain/tactical_battle_state.gd`:

```gdscript
class_name TacticalBattleState
extends RefCounted

const TacticalUnitStateScript = preload("res://scripts/domain/tactical_unit_state.gd")

const CHARGE_LIMIT := 1000
const TEAM_PLAYER := "player"
const TEAM_ENEMY := "enemy"
const TIME_MODE_PAUSE_ON_ACTION := "pause_on_action"

var battlefield_width: int = 7
var battlefield_height: int = 5
var time_mode: String = TIME_MODE_PAUSE_ON_ACTION
var units: Array = []
var current_unit_id: String = ""
var is_action_phase := false
var is_finished := false
var victory := false
var log: Array[String] = []
var source_map_id: String = "mountain_pass"
var source_object_id: String = ""
var quest_id: String = ""
var reward_martial_art_id: String = "basic_sword"
var proficiency_reward: int = 1

func add_unit(unit) -> void:
	if unit == null:
		return
	units.append(unit)

func get_unit(unit_id: String):
	for unit in units:
		if unit.unit_id == unit_id:
			return unit
	return null

func get_living_units_by_team(team: String) -> Array:
	var result: Array = []
	for unit in units:
		if unit.team == team and unit.is_alive():
			result.append(unit)
	return result

func has_living_team(team: String) -> bool:
	return not get_living_units_by_team(team).is_empty()

func append_log(message: String) -> void:
	if message.is_empty():
		return
	log.append(message)

func finish(is_victory: bool) -> void:
	is_finished = true
	victory = is_victory
	is_action_phase = false
	current_unit_id = ""

func to_result_dictionary() -> Dictionary:
	var hero_hp := 1
	var hero = _first_player_unit()
	if hero != null:
		hero_hp = max(0, hero.hp)
	return {
		"victory": victory,
		"hero_hp": hero_hp,
		"source_map_id": source_map_id,
		"source_object_id": source_object_id,
		"quest_id": quest_id,
		"martial_art_id": reward_martial_art_id,
		"proficiency_reward": max(0, proficiency_reward),
		"log": log.duplicate(),
	}

func to_dictionary() -> Dictionary:
	var serialized_units: Array = []
	for unit in units:
		serialized_units.append(unit.to_dictionary())
	return {
		"battlefield_width": battlefield_width,
		"battlefield_height": battlefield_height,
		"time_mode": time_mode,
		"units": serialized_units,
		"current_unit_id": current_unit_id,
		"is_action_phase": is_action_phase,
		"is_finished": is_finished,
		"victory": victory,
		"log": log.duplicate(),
		"source_map_id": source_map_id,
		"source_object_id": source_object_id,
		"quest_id": quest_id,
		"reward_martial_art_id": reward_martial_art_id,
		"proficiency_reward": proficiency_reward,
	}

func _first_player_unit():
	for unit in units:
		if unit.team == TEAM_PLAYER:
			return unit
	return null
```

- [ ] **Step 4: 运行测试并确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS, with suite count increased by 1 from Task 1.

- [ ] **Step 5: 提交**

```powershell
git add scripts/domain/tactical_battle_state.gd tests/test_tactical_battle_state.gd tests/run_tests.gd
git commit -m "feat: 添加战棋战斗状态"
```

---

### Task 3: 添加战棋系统的创建、集气和范围规则

**Files:**
- Create: `tests/test_tactical_combat_system.gd`
- Modify: `tests/run_tests.gd`
- Create: `scripts/systems/tactical_combat_system.gd`

- [ ] **Step 1: 写失败测试 `tests/test_tactical_combat_system.gd` 的基础规则**

Create `tests/test_tactical_combat_system.gd`:

```gdscript
extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const TacticalCombatSystemScript = preload("res://scripts/systems/tactical_combat_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var state = GameStateScript.new()
	state.start_new_game()
	state.hero_hp = 100

	var system = TacticalCombatSystemScript.new()
	system.set_repository(repository)

	var battle = system.create_battle(state, _sample_context(), repository)
	assertions.assert_eq(battle.units.size(), 3, "战棋战斗应创建 3 个单位")
	assertions.assert_eq(battle.get_unit("hero").hp, 100, "主角单位应读取当前 GameState 气血")
	assertions.assert_eq(battle.get_unit("bandit").display_name, "山道强人", "敌人单位应读取角色名")
	assertions.assert_eq(battle.source_object_id, "enemy_bandit_gate", "战棋战斗应保存来源对象")

	system.advance_charge(battle, 5.0)
	assertions.assert_eq(battle.current_unit_id, "hero", "主角和喽啰同时满集气时应优先玩家单位")
	assertions.assert_true(battle.is_action_phase, "单位满集气后应进入行动阶段")
	assertions.assert_eq(battle.get_unit("hero").charge, 1000, "集气达到上限后应钳制到 1000")

	var cells = system.get_movable_cells(battle, "hero")
	assertions.assert_true(_has_cell(cells, 1, 2), "可移动格应包含原地")
	assertions.assert_true(_has_cell(cells, 4, 2), "可移动格应包含移动力范围内的格子")
	assertions.assert_true(not _has_cell(cells, 5, 2), "可移动格不应包含敌方占用格")
	assertions.assert_true(not _has_cell(cells, 6, 2), "可移动格不应包含移动力范围外的格子")

	var attackable_before_move = system.get_attackable_units(battle, "hero")
	assertions.assert_eq(attackable_before_move.size(), 0, "主角未接近时不应有可攻击目标")

	system.move_unit(battle, "hero", {"q": 4, "r": 2})
	assertions.assert_eq(battle.get_unit("hero").cell.get("q", -1), 4, "移动后应更新 q 坐标")
	assertions.assert_eq(battle.get_unit("hero").cell.get("r", -1), 2, "移动后应更新 r 坐标")

	var attackable_after_move = system.get_attackable_units(battle, "hero")
	assertions.assert_eq(attackable_after_move.size(), 1, "移动后应能攻击相邻敌人")
	assertions.assert_eq(attackable_after_move[0].unit_id, "bandit", "可攻击目标应为山道强人")

	repository.free()
	state.free()

func _sample_context() -> Dictionary:
	return {
		"battle_mode": "tactical",
		"source_map_id": "mountain_pass",
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
		"battlefield": {"width": 7, "height": 5},
		"time_mode": "pause_on_action",
		"units": [
			{"unit_id": "hero", "actor_id": "hero_yun", "team": "player", "start_cell": {"q": 1, "r": 2}, "move_range": 3, "attack_range": 1, "charge_speed": 200},
			{"unit_id": "bandit", "actor_id": "bandit_01", "team": "enemy", "start_cell": {"q": 5, "r": 2}, "move_range": 3, "attack_range": 1, "charge_speed": 180},
			{"unit_id": "lackey", "actor_id": "bandit_01", "team": "enemy", "start_cell": {"q": 5, "r": 3}, "move_range": 3, "attack_range": 1, "charge_speed": 200}
		]
	}

func _has_cell(cells: Array, q: int, r: int) -> bool:
	for cell in cells:
		if int(cell.get("q", -1)) == q and int(cell.get("r", -1)) == r:
			return true
	return false
```

- [ ] **Step 2: 将测试加入 `tests/run_tests.gd` 并确认失败**

Add preload:

```gdscript
const TestTacticalCombatSystemScript = preload("res://tests/test_tactical_combat_system.gd")
```

Add the suite after `TestTacticalBattleStateScript.new()`:

```gdscript
		TestTacticalCombatSystemScript.new(),
```

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `res://scripts/systems/tactical_combat_system.gd` does not exist.

- [ ] **Step 3: 创建 `scripts/systems/tactical_combat_system.gd` 的基础实现**

Create `scripts/systems/tactical_combat_system.gd`:

```gdscript
extends RefCounted

const TacticalBattleStateScript = preload("res://scripts/domain/tactical_battle_state.gd")
const TacticalUnitStateScript = preload("res://scripts/domain/tactical_unit_state.gd")

var repository = null

func set_repository(next_repository) -> void:
	repository = next_repository

func create_battle(game_state, context: Dictionary, data_source = null):
	var source = data_source if data_source != null else repository
	var battle = TacticalBattleStateScript.new()
	battle.source_map_id = str(context.get("source_map_id", "mountain_pass"))
	if battle.source_map_id.is_empty():
		battle.source_map_id = "mountain_pass"
	battle.source_object_id = str(context.get("source_object_id", ""))
	battle.quest_id = str(context.get("quest_id", ""))
	battle.time_mode = str(context.get("time_mode", TacticalBattleStateScript.TIME_MODE_PAUSE_ON_ACTION))
	if battle.time_mode.is_empty():
		battle.time_mode = TacticalBattleStateScript.TIME_MODE_PAUSE_ON_ACTION

	var battlefield = context.get("battlefield", {})
	if typeof(battlefield) == TYPE_DICTIONARY:
		battle.battlefield_width = max(1, int(battlefield.get("width", 7)))
		battle.battlefield_height = max(1, int(battlefield.get("height", 5)))

	var raw_units = context.get("units", [])
	if typeof(raw_units) != TYPE_ARRAY:
		raw_units = []
	for raw_unit in raw_units:
		if typeof(raw_unit) != TYPE_DICTIONARY:
			continue
		var unit = _build_unit(raw_unit, game_state, source)
		if _is_valid_start_cell(battle, unit.cell) and not _is_cell_occupied(battle, unit.cell):
			battle.add_unit(unit)
		else:
			battle.append_log("%s站位无效。" % unit.display_name)

	if not battle.has_living_team(TacticalBattleStateScript.TEAM_PLAYER):
		battle.append_log("玩家单位缺失。")
	if not battle.has_living_team(TacticalBattleStateScript.TEAM_ENEMY):
		battle.append_log("敌方单位缺失。")
		battle.finish(true)
	return battle

func advance_charge(battle, delta: float) -> void:
	if battle == null or battle.is_finished or battle.is_action_phase:
		return
	for unit in battle.units:
		if not unit.is_alive():
			continue
		unit.charge = mini(TacticalBattleStateScript.CHARGE_LIMIT, int(unit.charge + round(unit.charge_speed * delta)))
	var ready = get_ready_unit(battle)
	if ready != null:
		begin_unit_action(battle, ready.unit_id)

func get_ready_unit(battle):
	if battle == null:
		return null
	var ready_players: Array = []
	var ready_enemies: Array = []
	for unit in battle.units:
		if not unit.is_alive() or unit.charge < TacticalBattleStateScript.CHARGE_LIMIT:
			continue
		if unit.team == TacticalBattleStateScript.TEAM_PLAYER:
			ready_players.append(unit)
		else:
			ready_enemies.append(unit)
	if not ready_players.is_empty():
		return ready_players[0]
	if not ready_enemies.is_empty():
		return ready_enemies[0]
	return null

func begin_unit_action(battle, unit_id: String) -> Dictionary:
	var unit = battle.get_unit(unit_id) if battle != null else null
	if unit == null or not unit.is_alive():
		return {"success": false, "message": "行动单位不存在。"}
	battle.current_unit_id = unit_id
	battle.is_action_phase = true
	unit.charge = TacticalBattleStateScript.CHARGE_LIMIT
	battle.append_log("%s可以行动。" % unit.display_name)
	return {"success": true, "message": "%s可以行动。" % unit.display_name}

func get_movable_cells(battle, unit_id: String) -> Array:
	var unit = battle.get_unit(unit_id) if battle != null else null
	if unit == null or not unit.is_alive():
		return []
	var result: Array = []
	for q in range(battle.battlefield_width):
		for r in range(battle.battlefield_height):
			var cell = {"q": q, "r": r}
			if _cell_distance(unit.cell, cell) > unit.move_range:
				continue
			if _is_cell_occupied_by_other(battle, cell, unit.unit_id):
				continue
			result.append(cell)
	return result

func move_unit(battle, unit_id: String, cell: Dictionary) -> Dictionary:
	var unit = battle.get_unit(unit_id) if battle != null else null
	if unit == null or not unit.is_alive():
		return {"success": false, "message": "移动单位不存在。"}
	if not _contains_cell(get_movable_cells(battle, unit_id), cell):
		return {"success": false, "message": "不能移动到此处。"}
	unit.cell = _read_cell(cell)
	battle.append_log("%s移动到%s,%s。" % [unit.display_name, unit.cell.get("q", 0), unit.cell.get("r", 0)])
	return {"success": true, "message": "已经移动。"}

func get_attackable_units(battle, unit_id: String) -> Array:
	var unit = battle.get_unit(unit_id) if battle != null else null
	if unit == null or not unit.is_alive():
		return []
	var result: Array = []
	for target in battle.units:
		if not target.is_alive() or target.team == unit.team:
			continue
		if _cell_distance(unit.cell, target.cell) <= unit.attack_range:
			result.append(target)
	return result

func _build_unit(raw_unit: Dictionary, game_state, source):
	var actor_id = str(raw_unit.get("actor_id", ""))
	var actor = source.get_actor(actor_id) if source != null and source.has_method("get_actor") else {}
	var unit_data = raw_unit.duplicate(true)
	unit_data["display_name"] = str(actor.get("name", actor_id))
	unit_data["hp"] = max(1, int(actor.get("hp", 1)))
	unit_data["max_hp"] = max(1, int(actor.get("max_hp", unit_data["hp"])))
	unit_data["attack"] = max(1, int(actor.get("attack", 1)))
	unit_data["defense"] = max(0, int(actor.get("defense", 0)))
	unit_data["cell"] = raw_unit.get("start_cell", raw_unit.get("cell", {}))
	if str(raw_unit.get("team", "")) == TacticalBattleStateScript.TEAM_PLAYER and game_state != null:
		unit_data["max_hp"] = max(1, int(game_state.hero_max_hp))
		unit_data["hp"] = clamp(int(game_state.hero_hp), 1, int(unit_data["max_hp"]))
	var unit = TacticalUnitStateScript.new()
	unit.from_dictionary(unit_data)
	return unit

func _is_valid_start_cell(battle, cell: Dictionary) -> bool:
	var q = int(cell.get("q", -1))
	var r = int(cell.get("r", -1))
	return q >= 0 and r >= 0 and q < battle.battlefield_width and r < battle.battlefield_height

func _is_cell_occupied(battle, cell: Dictionary) -> bool:
	for unit in battle.units:
		if unit.is_alive() and _same_cell(unit.cell, cell):
			return true
	return false

func _is_cell_occupied_by_other(battle, cell: Dictionary, unit_id: String) -> bool:
	for unit in battle.units:
		if unit.unit_id == unit_id:
			continue
		if unit.is_alive() and _same_cell(unit.cell, cell):
			return true
	return false

func _contains_cell(cells: Array, cell: Dictionary) -> bool:
	for candidate in cells:
		if _same_cell(candidate, cell):
			return true
	return false

func _same_cell(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("q", 0)) == int(b.get("q", 0)) and int(a.get("r", 0)) == int(b.get("r", 0))

func _read_cell(cell: Dictionary) -> Dictionary:
	return {"q": int(cell.get("q", 0)), "r": int(cell.get("r", 0))}

func _cell_distance(a: Dictionary, b: Dictionary) -> int:
	return abs(int(a.get("q", 0)) - int(b.get("q", 0))) + abs(int(a.get("r", 0)) - int(b.get("r", 0)))
```

- [ ] **Step 4: 运行测试并确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS, with suite count increased by 1 from Task 2.

- [ ] **Step 5: 提交**

```powershell
git add scripts/systems/tactical_combat_system.gd tests/test_tactical_combat_system.gd tests/run_tests.gd
git commit -m "feat: 添加战棋集气基础规则"
```

---

### Task 4: 补齐战棋攻击、敌人 AI、胜负和暂退

**Files:**
- Modify: `tests/test_tactical_combat_system.gd`
- Modify: `scripts/systems/tactical_combat_system.gd`

- [ ] **Step 1: 扩展 `tests/test_tactical_combat_system.gd`**

Add these assertions after the existing `attackable_after_move` assertions and before cleanup:

```gdscript
	var attack_result = system.attack_unit(battle, "hero", "bandit")
	assertions.assert_true(bool(attack_result.get("success", false)), "攻击相邻敌人应成功")
	assertions.assert_eq(battle.get_unit("bandit").hp, 46, "普通攻击应按攻击减防御造成伤害")
	assertions.assert_true(battle.log.has("云游少侠攻击山道强人，造成14点伤害。"), "普通攻击应写入战斗日志")

	system.end_unit_action(battle, "hero")
	assertions.assert_eq(battle.get_unit("hero").charge, 0, "结束行动应清空当前单位集气")
	assertions.assert_true(not battle.is_action_phase, "结束行动后应恢复集气阶段")
	assertions.assert_eq(battle.current_unit_id, "", "结束行动后应清空当前行动单位")

	var enemy_battle = system.create_battle(state, _sample_context(), repository)
	enemy_battle.get_unit("bandit").cell = {"q": 2, "r": 2}
	enemy_battle.get_unit("hero").cell = {"q": 1, "r": 2}
	var ai_result = system.resolve_enemy_action(enemy_battle, "bandit")
	assertions.assert_true(bool(ai_result.get("success", false)), "敌人在攻击范围内应自动行动成功")
	assertions.assert_eq(enemy_battle.get_unit("hero").hp, 96, "敌人普通攻击应扣除主角气血")

	var finish_battle = system.create_battle(state, _sample_context(), repository)
	finish_battle.get_unit("bandit").hp = 1
	finish_battle.get_unit("lackey").hp = 0
	finish_battle.get_unit("hero").cell = {"q": 4, "r": 2}
	system.attack_unit(finish_battle, "hero", "bandit")
	assertions.assert_true(finish_battle.is_finished, "击败全部敌人后战棋应结束")
	assertions.assert_true(finish_battle.victory, "击败全部敌人后应标记胜利")
	var payload = finish_battle.to_result_dictionary()
	assertions.assert_eq(payload.get("source_object_id", ""), "enemy_bandit_gate", "战棋胜利 payload 应包含来源对象")
	assertions.assert_eq(payload.get("quest_id", ""), "quest_mountain_trial", "战棋胜利 payload 应包含任务编号")

	var retreat_battle = system.create_battle(state, _sample_context(), repository)
	system.resolve_retreat(retreat_battle)
	assertions.assert_true(retreat_battle.is_finished, "暂退应结束战棋")
	assertions.assert_true(not retreat_battle.victory, "暂退不应标记胜利")
```

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `attack_unit()`、`end_unit_action()`、`resolve_enemy_action()` and `resolve_retreat()` do not exist.

- [ ] **Step 2: 在 `scripts/systems/tactical_combat_system.gd` 添加行动方法**

Add these methods before helper methods:

```gdscript
func attack_unit(battle, attacker_id: String, defender_id: String) -> Dictionary:
	var attacker = battle.get_unit(attacker_id) if battle != null else null
	var defender = battle.get_unit(defender_id) if battle != null else null
	if attacker == null or defender == null:
		return {"success": false, "message": "攻击目标不存在。"}
	if not attacker.is_alive() or not defender.is_alive():
		return {"success": false, "message": "攻击目标已倒下。"}
	if attacker.team == defender.team:
		return {"success": false, "message": "不能攻击同伴。"}
	if _cell_distance(attacker.cell, defender.cell) > attacker.attack_range:
		return {"success": false, "message": "目标不在攻击范围内。"}

	var damage = maxi(1, attacker.attack - defender.defense)
	defender.hp = max(0, defender.hp - damage)
	battle.append_log("%s攻击%s，造成%d点伤害。" % [attacker.display_name, defender.display_name, damage])
	if defender.hp <= 0:
		battle.append_log("%s被击败。" % defender.display_name)
	check_battle_finished(battle)
	return {"success": true, "message": "已经攻击。", "damage": damage}

func end_unit_action(battle, unit_id: String) -> Dictionary:
	var unit = battle.get_unit(unit_id) if battle != null else null
	if unit == null:
		return {"success": false, "message": "行动单位不存在。"}
	unit.reset_charge()
	if battle.current_unit_id == unit_id:
		battle.current_unit_id = ""
	battle.is_action_phase = false
	return {"success": true, "message": "行动结束。"}

func resolve_enemy_action(battle, unit_id: String) -> Dictionary:
	var unit = battle.get_unit(unit_id) if battle != null else null
	if unit == null or not unit.is_alive():
		return {"success": false, "message": "敌人不存在。"}
	var target = _first_living_player(battle)
	if target == null:
		check_battle_finished(battle)
		return {"success": false, "message": "玩家单位不存在。"}

	if _cell_distance(unit.cell, target.cell) > unit.attack_range:
		var best_cell = _best_enemy_move_cell(battle, unit, target)
		move_unit(battle, unit.unit_id, best_cell)
	if unit.is_alive() and target.is_alive() and _cell_distance(unit.cell, target.cell) <= unit.attack_range:
		attack_unit(battle, unit.unit_id, target.unit_id)
	if not battle.is_finished:
		end_unit_action(battle, unit.unit_id)
	return {"success": true, "message": "敌人已经行动。"}

func resolve_retreat(battle) -> Dictionary:
	if battle == null:
		return {"success": false, "message": "战斗尚未准备好。"}
	if not battle.is_finished:
		battle.append_log("暂退数步。")
		battle.finish(false)
	return {"success": true, "message": "暂退数步。"}

func check_battle_finished(battle) -> void:
	if battle == null or battle.is_finished:
		return
	if not battle.has_living_team(TacticalBattleStateScript.TEAM_PLAYER):
		battle.append_log("气血不支，暂退数步。")
		battle.finish(false)
	elif not battle.has_living_team(TacticalBattleStateScript.TEAM_ENEMY):
		battle.append_log("敌人尽数败退。")
		battle.finish(true)
```

Add these helpers near the bottom:

```gdscript
func _first_living_player(battle):
	var players = battle.get_living_units_by_team(TacticalBattleStateScript.TEAM_PLAYER)
	if players.is_empty():
		return null
	return players[0]

func _best_enemy_move_cell(battle, unit, target) -> Dictionary:
	var cells = get_movable_cells(battle, unit.unit_id)
	if cells.is_empty():
		return unit.cell.duplicate(true)
	var best = cells[0]
	var best_distance = _cell_distance(best, target.cell)
	for cell in cells:
		var distance = _cell_distance(cell, target.cell)
		if distance < best_distance:
			best = cell
			best_distance = distance
	return best.duplicate(true)
```

- [ ] **Step 3: 运行测试并确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS.

- [ ] **Step 4: 提交**

```powershell
git add scripts/systems/tactical_combat_system.gd tests/test_tactical_combat_system.gd
git commit -m "feat: 添加战棋攻击和敌人行动"
```

---

### Task 5: 接入山道战棋数据和战斗上下文

**Files:**
- Modify: `data/actors.json`
- Modify: `data/maps.json`
- Modify: `scripts/scenes/mountain_pass_screen.gd`
- Modify: `tests/test_map_data.gd`

- [ ] **Step 1: 扩展地图和角色数据测试**

In `tests/test_map_data.gd`, after the existing `exit_to_foot_village` assertion, add:

```gdscript
	var bandit_gate = _find_object(mountain, "enemy_bandit_gate")
	assertions.assert_eq(bandit_gate.get("battle_mode", ""), "tactical", "山道强人战应声明战棋模式")
	assertions.assert_eq(bandit_gate.get("battlefield", {}).get("width", 0), 7, "山道强人战场宽度应为 7")
	assertions.assert_eq(bandit_gate.get("battlefield", {}).get("height", 0), 5, "山道强人战场高度应为 5")
	assertions.assert_eq(bandit_gate.get("time_mode", ""), "pause_on_action", "山道强人战应使用暂停行动集气模式")
	assertions.assert_eq(bandit_gate.get("units", []).size(), 3, "山道强人战应配置 3 个战棋单位")
	assertions.assert_eq(bandit_gate.get("units", [])[2].get("actor_id", ""), "bandit_lackey_01", "第三个战棋单位应为山道喽啰")
	assertions.assert_true(repository.get_actor("bandit_lackey_01").get("name", "") == "山道喽啰", "应配置山道喽啰角色数据")
```

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because map and actor data do not yet contain the tactical fields.

- [ ] **Step 2: 在 `data/actors.json` 添加山道喽啰**

Insert this object after `bandit_01`:

```json
  {
    "id": "bandit_lackey_01",
    "name": "山道喽啰",
    "level": 1,
    "hp": 38,
    "max_hp": 38,
    "attack": 10,
    "defense": 3,
    "martial_arts": ["rough_fist"]
  },
```

Keep the file as a JSON array and preserve the existing actor entries.

- [ ] **Step 3: 在 `data/maps.json` 扩展 `enemy_bandit_gate`**

Replace the existing `enemy_bandit_gate` object with:

```json
      {
        "id": "enemy_bandit_gate",
        "type": "battle_trigger",
        "name": "山道强人",
        "actor_id": "bandit_01",
        "position": {"x": 720, "y": 260},
        "radius": 56,
        "quest_id": "quest_mountain_trial",
        "battle_mode": "tactical",
        "encounter_id": "mountain_bandit_tutorial",
        "battlefield": {"width": 7, "height": 5},
        "time_mode": "pause_on_action",
        "units": [
          {
            "unit_id": "hero",
            "actor_id": "hero_yun",
            "team": "player",
            "start_cell": {"q": 1, "r": 2},
            "move_range": 3,
            "attack_range": 1,
            "charge_speed": 240
          },
          {
            "unit_id": "bandit",
            "actor_id": "bandit_01",
            "team": "enemy",
            "start_cell": {"q": 5, "r": 2},
            "move_range": 3,
            "attack_range": 1,
            "charge_speed": 220
          },
          {
            "unit_id": "bandit_lackey",
            "actor_id": "bandit_lackey_01",
            "team": "enemy",
            "start_cell": {"q": 5, "r": 3},
            "move_range": 3,
            "attack_range": 1,
            "charge_speed": 260
          }
        ]
      },
```

- [ ] **Step 4: 修改 `scripts/scenes/mountain_pass_screen.gd` 传递完整战斗配置**

Replace `_start_battle(record: Dictionary)` with:

```gdscript
func _start_battle(record: Dictionary) -> void:
	var quest_id = str(record.get("quest_id", ""))
	if GameState.quest_system.get_status(quest_id) == "not_started":
		hud.show_message("先与青衫客交谈。")
		return
	var context = record.duplicate(true)
	context["enemy_id"] = str(record.get("actor_id", ""))
	context["source_map_id"] = "mountain_pass"
	context["source_object_id"] = str(record.get("id", ""))
	context["quest_id"] = quest_id
	context["return_position"] = {
		"x": player.global_position.x,
		"y": player.global_position.y,
	}
	GameState.set_battle_context(context)
	SceneLoader.change_scene("res://scenes/battle.tscn")
```

- [ ] **Step 5: 运行测试并确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS.

- [ ] **Step 6: 提交**

```powershell
git add data/actors.json data/maps.json scripts/scenes/mountain_pass_screen.gd tests/test_map_data.gd
git commit -m "feat: 配置山道战棋遭遇"
```

---

### Task 6: 在 BattleScreen 接入战棋模式

**Files:**
- Create: `tests/test_tactical_battle_screen.gd`
- Modify: `tests/run_tests.gd`
- Modify: `scripts/scenes/battle_screen.gd`

- [ ] **Step 1: 写场景基础测试 `tests/test_tactical_battle_screen.gd`**

Create `tests/test_tactical_battle_screen.gd`:

```gdscript
extends RefCounted

const BattleScreenScript = preload("res://scripts/scenes/battle_screen.gd")

func run(assertions) -> void:
	var root = Engine.get_main_loop().root
	var repository = root.get_node("DataRepository")
	var game_state = root.get_node("GameState")
	repository.load_all()
	game_state.start_new_game()
	game_state.set_battle_context({
		"battle_mode": "tactical",
		"source_map_id": "mountain_pass",
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
		"battlefield": {"width": 7, "height": 5},
		"time_mode": "pause_on_action",
		"units": [
			{"unit_id": "hero", "actor_id": "hero_yun", "team": "player", "start_cell": {"q": 1, "r": 2}, "move_range": 3, "attack_range": 1, "charge_speed": 240},
			{"unit_id": "bandit", "actor_id": "bandit_01", "team": "enemy", "start_cell": {"q": 5, "r": 2}, "move_range": 3, "attack_range": 1, "charge_speed": 220},
			{"unit_id": "bandit_lackey", "actor_id": "bandit_lackey_01", "team": "enemy", "start_cell": {"q": 5, "r": 3}, "move_range": 3, "attack_range": 1, "charge_speed": 260}
		]
	})

	var screen = BattleScreenScript.new()
	screen._ready()

	assertions.assert_true(screen.is_tactical_mode, "battle_mode 为 tactical 时应进入战棋模式")
	assertions.assert_true(screen.tactical_battle_state != null, "战棋模式应创建战棋状态")
	assertions.assert_true(screen.grid_layer != null, "战棋模式应创建格子层")
	assertions.assert_true(screen.status_label != null, "战棋模式应创建状态文本")
	assertions.assert_true(screen.end_action_button != null, "战棋模式应创建结束行动按钮")
	assertions.assert_eq(screen.tactical_battle_state.units.size(), 3, "战棋场景应创建 3 个单位")
	assertions.assert_true(screen.cell_buttons.size() >= 35, "7x5 战场应创建至少 35 个格子按钮")
	assertions.assert_true(screen.item_button == null or not screen.item_button.visible, "战棋模式不应显示小还丹按钮")

	screen.tactical_combat_system.advance_charge(screen.tactical_battle_state, 5.0)
	screen._refresh_tactical()
	assertions.assert_eq(screen.status_label.text, "云游少侠行动", "主角满集气后状态文本应显示主角行动")

	screen.free()
```

- [ ] **Step 2: 将测试加入 `tests/run_tests.gd` 并确认失败**

Add preload:

```gdscript
const TestTacticalBattleScreenScript = preload("res://tests/test_tactical_battle_screen.gd")
```

Add the suite near other scene tests:

```gdscript
		TestTacticalBattleScreenScript.new(),
```

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `battle_screen.gd` does not expose tactical fields.

- [ ] **Step 3: 修改 `scripts/scenes/battle_screen.gd` 的字段和 `_ready()` 分流**

Add preloads and tactical fields near the top:

```gdscript
const TacticalCombatSystemScript = preload("res://scripts/systems/tactical_combat_system.gd")
const TacticalBattleState = preload("res://scripts/domain/tactical_battle_state.gd")

var is_tactical_mode := false
var tactical_battle_state = null
var tactical_combat_system = TacticalCombatSystemScript.new()
var grid_layer: Control
var status_label: Label
var unit_panel: VBoxContainer
var end_action_button: Button
var cell_buttons: Dictionary = {}
var selected_unit_id: String = ""
```

Replace `_ready()` with:

```gdscript
func _ready() -> void:
	context = GameState.peek_battle_context()
	is_tactical_mode = str(context.get("battle_mode", "")) == "tactical"
	if is_tactical_mode:
		tactical_combat_system.set_repository(DataRepository)
		tactical_battle_state = tactical_combat_system.create_battle(GameState, context, DataRepository)
		_create_tactical_ui()
		_refresh_tactical()
	else:
		combat_system.set_repository(DataRepository)
		battle_state = combat_system.create_battle(GameState, context, DataRepository)
		_create_ui()
		_refresh()
```

Add `_process(delta)`:

```gdscript
func _process(delta: float) -> void:
	if not is_tactical_mode or tactical_battle_state == null or tactical_battle_state.is_finished:
		return
	if not tactical_battle_state.is_action_phase:
		tactical_combat_system.advance_charge(tactical_battle_state, delta)
		_refresh_tactical()
	if tactical_battle_state.is_action_phase:
		var unit = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
		if unit != null and unit.team == "enemy":
			tactical_combat_system.resolve_enemy_action(tactical_battle_state, unit.unit_id)
			_refresh_tactical()
			_return_if_tactical_finished()
```

- [ ] **Step 4: 添加战棋 UI 创建和刷新方法**

Add these methods to `scripts/scenes/battle_screen.gd`:

```gdscript
func _create_tactical_ui() -> void:
	title_label = Label.new()
	title_label.text = "战棋：山道试剑"
	title_label.position = Vector2(32, 20)
	title_label.size = Vector2(420, 32)
	add_child(title_label)

	status_label = Label.new()
	status_label.position = Vector2(32, 56)
	status_label.size = Vector2(420, 32)
	add_child(status_label)

	grid_layer = Control.new()
	grid_layer.position = Vector2(120, 110)
	grid_layer.size = Vector2(640, 420)
	add_child(grid_layer)

	unit_panel = VBoxContainer.new()
	unit_panel.position = Vector2(820, 56)
	unit_panel.size = Vector2(360, 300)
	add_child(unit_panel)

	output = Label.new()
	output.position = Vector2(820, 380)
	output.size = Vector2(380, 170)
	output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(output)

	end_action_button = Button.new()
	end_action_button.text = "结束行动"
	end_action_button.position = Vector2(820, 570)
	end_action_button.size = Vector2(120, 40)
	end_action_button.pressed.connect(_on_tactical_end_action_pressed)
	add_child(end_action_button)

	retreat_button = Button.new()
	retreat_button.text = "暂退"
	retreat_button.position = Vector2(960, 570)
	retreat_button.size = Vector2(120, 40)
	retreat_button.pressed.connect(_on_tactical_retreat_pressed)
	add_child(retreat_button)

	_create_tactical_grid()

func _create_tactical_grid() -> void:
	cell_buttons.clear()
	for q in range(tactical_battle_state.battlefield_width):
		for r in range(tactical_battle_state.battlefield_height):
			var button = Button.new()
			button.text = ""
			button.size = Vector2(58, 34)
			button.position = _cell_to_screen({"q": q, "r": r})
			button.pressed.connect(_on_tactical_cell_pressed.bind(q, r))
			grid_layer.add_child(button)
			cell_buttons[_cell_key({"q": q, "r": r})] = button

func _refresh_tactical() -> void:
	if tactical_battle_state == null:
		return
	var current = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
	if tactical_battle_state.is_finished:
		status_label.text = "战斗结束"
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
			TacticalBattleState.CHARGE_LIMIT
		]
		unit_panel.add_child(label)

	var movable = tactical_combat_system.get_movable_cells(tactical_battle_state, tactical_battle_state.current_unit_id)
	var attackable = tactical_combat_system.get_attackable_units(tactical_battle_state, tactical_battle_state.current_unit_id)
	for key in cell_buttons.keys():
		var button = cell_buttons[key]
		button.text = ""
		button.disabled = true
	for unit in tactical_battle_state.units:
		var unit_key = _cell_key(unit.cell)
		if cell_buttons.has(unit_key):
			cell_buttons[unit_key].text = unit.display_name.substr(0, 2)
	for cell in movable:
		var move_key = _cell_key(cell)
		if cell_buttons.has(move_key):
			cell_buttons[move_key].disabled = false
	for target in attackable:
		var target_key = _cell_key(target.cell)
		if cell_buttons.has(target_key):
			cell_buttons[target_key].disabled = false

	output.text = "\n".join(PackedStringArray(tactical_battle_state.log))
	end_action_button.disabled = tactical_battle_state.is_finished or not _is_player_action()
	retreat_button.disabled = tactical_battle_state.is_finished
```

- [ ] **Step 5: 添加战棋点击、结束行动、暂退和回流方法**

Add these methods to `scripts/scenes/battle_screen.gd`:

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
		tactical_combat_system.attack_unit(tactical_battle_state, current_unit.unit_id, target.unit_id)
		if not tactical_battle_state.is_finished:
			tactical_combat_system.end_unit_action(tactical_battle_state, current_unit.unit_id)
	else:
		tactical_combat_system.move_unit(tactical_battle_state, current_unit.unit_id, cell)
	_refresh_tactical()
	_return_if_tactical_finished()

func _on_tactical_end_action_pressed() -> void:
	if not _is_player_action():
		return
	tactical_combat_system.end_unit_action(tactical_battle_state, tactical_battle_state.current_unit_id)
	_refresh_tactical()

func _on_tactical_retreat_pressed() -> void:
	tactical_combat_system.resolve_retreat(tactical_battle_state)
	_refresh_tactical()
	_return_if_tactical_finished()

func _return_if_tactical_finished() -> void:
	if tactical_battle_state == null or not tactical_battle_state.is_finished:
		return
	var payload = tactical_battle_state.to_result_dictionary()
	GameState.apply_battle_result(payload)
	EventBus.battle_finished.emit(payload)
	call_deferred("_return_to_map")

func _is_player_action() -> bool:
	if tactical_battle_state == null or not tactical_battle_state.is_action_phase:
		return false
	var unit = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
	return unit != null and unit.team == "player"

func _unit_at_cell(cell: Dictionary):
	for unit in tactical_battle_state.units:
		if unit.is_alive() and int(unit.cell.get("q", -1)) == int(cell.get("q", -2)) and int(unit.cell.get("r", -1)) == int(cell.get("r", -2)):
			return unit
	return null

func _cell_to_screen(cell: Dictionary) -> Vector2:
	var q = int(cell.get("q", 0))
	var r = int(cell.get("r", 0))
	return Vector2((q - r) * 34 + 240, (q + r) * 22)

func _cell_key(cell: Dictionary) -> String:
	return "%d:%d" % [int(cell.get("q", 0)), int(cell.get("r", 0))]
```

Update `_return_to_map()` so it handles both battle state types:

```gdscript
func _return_to_map() -> void:
	var source_map_id = ""
	if is_tactical_mode and tactical_battle_state != null:
		source_map_id = tactical_battle_state.source_map_id
	elif battle_state != null:
		source_map_id = battle_state.source_map_id
	if source_map_id.is_empty():
		source_map_id = str(context.get("source_map_id", GameState.map_state.current_map_id))
	if source_map_id.is_empty():
		source_map_id = "mountain_pass"
	GameState.consume_battle_context()
	SceneLoader.change_scene(GameState.get_scene_path_for_map(source_map_id))
```

- [ ] **Step 6: 运行测试并确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS, with suite count increased by 1 from Task 5.

- [ ] **Step 7: 提交**

```powershell
git add scripts/scenes/battle_screen.gd tests/test_tactical_battle_screen.gd tests/run_tests.gd
git commit -m "feat: 接入战棋战斗界面"
```

---

### Task 7: 补齐战棋胜利回流和旧战斗兼容测试

**Files:**
- Modify: `tests/test_combat_and_save.gd`
- Modify: `tests/test_tactical_combat_system.gd`
- Modify: `scripts/systems/tactical_combat_system.gd`

- [ ] **Step 1: 增加战棋回流测试**

In `tests/test_combat_and_save.gd`, before `repository.free()`, add:

```gdscript
	var tactical_state = GameStateScript.new()
	tactical_state.start_new_game()
	tactical_state.quest_system.start_quest("quest_mountain_trial")
	tactical_state.apply_battle_result({
		"victory": true,
		"hero_hp": 72,
		"source_map_id": "mountain_pass",
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
		"martial_art_id": "basic_sword",
		"proficiency_reward": 1,
		"log": ["敌人尽数败退。"]
	})
	assertions.assert_true(tactical_state.is_map_object_resolved("enemy_bandit_gate"), "战棋胜利后强人触发点应被标记为已解决")
	assertions.assert_eq(tactical_state.quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "战棋胜利后山道任务应进入可交付状态")
	assertions.assert_eq(tactical_state.hero_hp, 72, "战棋胜利后应保存主角剩余气血")
	assertions.assert_eq(tactical_state.get_martial_proficiency("basic_sword"), 1, "战棋胜利后应增加基础剑法熟练度")
	tactical_state.free()
```

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS. This confirms the new payload shape remains compatible with existing `GameState.apply_battle_result()`.

- [ ] **Step 2: 增加玩家失败战棋测试**

In `tests/test_tactical_combat_system.gd`, after the retreat assertions, add:

```gdscript
	var defeat_battle = system.create_battle(state, _sample_context(), repository)
	defeat_battle.get_unit("hero").hp = 1
	defeat_battle.get_unit("bandit").cell = {"q": 2, "r": 2}
	defeat_battle.get_unit("hero").cell = {"q": 1, "r": 2}
	system.resolve_enemy_action(defeat_battle, "bandit")
	assertions.assert_true(defeat_battle.is_finished, "主角被击败后战棋应结束")
	assertions.assert_true(not defeat_battle.victory, "主角被击败后不应标记胜利")
```

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS because `attack_unit()` calls `check_battle_finished(battle)` immediately after applying damage.

- [ ] **Step 3: 确认旧普通战斗仍兼容**

Run the full suite:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS. Existing `tests/test_turn_based_combat_system.gd` must still pass because `battle_screen.gd` only branches to tactical mode when `battle_mode == "tactical"` and `CombatSystem` remains unchanged.

- [ ] **Step 4: 提交**

```powershell
git add tests/test_combat_and_save.gd tests/test_tactical_combat_system.gd scripts/systems/tactical_combat_system.gd
git commit -m "test: 覆盖战棋胜负回流"
```

---

### Task 8: 更新文档并运行最终验证

**Files:**
- Modify: `README.md`
- Modify: `docs/godot-project-structure.md`

- [ ] **Step 1: 更新 `README.md`**

In the “当前阶段包含” list, add this bullet after “江湖记事基础切片”:

```markdown
- 菱形战棋与集气基础切片：山道强人战升级为 `1v2` 菱形格战棋战斗，单位实时集气到 `1000` 后行动，行动期间暂停集气，胜利和暂退沿用现有地图回流。
```

- [ ] **Step 2: 更新 `docs/godot-project-structure.md`**

Add this section after “江湖记事基础切片”:

```markdown
## 菱形战棋与集气基础切片

菱形战棋切片新增 `TacticalUnitState` 和 `TacticalBattleState` 保存战棋单位与战斗运行时状态，新增 `TacticalCombatSystem` 处理实时集气、行动暂停、移动范围、攻击范围、敌人 AI、胜负和暂退。山道强人触发点通过 `data/maps.json` 声明 `battle_mode = "tactical"`、战场尺寸、单位站位和集气速度；`battle_screen.gd` 根据战斗上下文分流普通回合战斗和战棋战斗。战棋胜利仍生成 `GameState.apply_battle_result()` 可处理的 payload，不直接修改任务、地图对象或熟练度。
```

- [ ] **Step 3: 运行完整自动测试**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS, with the suite count increased by 4 compared with the pre-plan baseline:

```text
测试通过：34 个测试套件
```

- [ ] **Step 4: 验证场景可 headless 加载**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
```

Expected: exits with code 0 and no script parse errors.

- [ ] **Step 5: 查看变更**

Run:

```powershell
git status --short
git diff --check
```

Expected:

```text
git diff --check
```

prints no whitespace errors. `git status --short` should show only files changed by this plan.

- [ ] **Step 6: 提交**

```powershell
git add README.md docs/godot-project-structure.md
git commit -m "docs: 记录战棋集气切片"
```

---

## Final Verification

After all tasks are complete, run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
git status --short
```

Expected:

```text
测试通过：34 个测试套件
```

`git status --short` should be clean after the final documentation commit.

## Self-Review

- Spec coverage: Tasks 1-2 cover战棋领域状态；Tasks 3-4 cover实时集气、暂停行动、移动、攻击、AI、胜负和暂退；Task 5 cover山道触发点、`1v2` 数据和战斗上下文；Task 6 cover战棋 UI 和普通战斗分流；Task 7 cover胜利、失败、暂退和旧战斗兼容；Task 8 cover文档和最终验证。
- Scope control: The plan excludes战斗中用药、多武学、队友、地形、战斗存档、独立 `encounters.json` and player-facing mode switching, matching the approved design.
- Type consistency: `TacticalUnitState`、`TacticalBattleState`、`TacticalCombatSystem`、`battle_mode`、`time_mode = "pause_on_action"`、`source_object_id`、`quest_id`、`martial_art_id` and `proficiency_reward` are named consistently across tests, implementation snippets and data.
