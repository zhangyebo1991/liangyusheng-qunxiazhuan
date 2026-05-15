# 战术 AI 与自动战斗 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现自动战斗模式，AI 自动控制所有玩家单位（含主角），选择最优移动位置和技能。

**Architecture:** 新增 TacticalAI 系统评估位置和技能，AutoBattleMode 记录手动/自动状态，集成到 TacticalCombatSystem 行动流程。

**Tech Stack:** GDScript, Godot 4.6

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `scripts/systems/tactical_ai.gd` | AI 决策核心，评估位置和技能 |
| `scripts/domain/auto_battle_mode.gd` | 记录手动/自动模式状态 |
| `tests/test_tactical_ai.gd` | AI 决策逻辑测试 |
| `tests/test_auto_battle_mode.gd` | 模式切换测试 |
| `scripts/domain/tactical_battle_state.gd` | 修改：集成 auto_battle_mode |
| `scripts/systems/tactical_combat_system.gd` | 修改：集成 AI 决策流程 |

---

### Task 1: AutoBattleMode 数据层

**Files:**
- Create: `scripts/domain/auto_battle_mode.gd`
- Modify: `scripts/domain/tactical_battle_state.gd`
- Test: `tests/test_auto_battle_mode.gd`

- [ ] **Step 1: 创建 AutoBattleMode 类**

```gdscript
# scripts/domain/auto_battle_mode.gd
class_name AutoBattleMode
extends RefCounted

var is_auto: bool = false

func toggle() -> void:
	is_auto = not is_auto

func set_auto(value: bool) -> void:
	is_auto = value

func to_dictionary() -> Dictionary:
	return {
		"is_auto": is_auto
	}

func from_dictionary(data: Dictionary) -> void:
	is_auto = bool(data.get("is_auto", false))
```

- [ ] **Step 2: 修改 TacticalBattleState 集成 AutoBattleMode**

在 `scripts/domain/tactical_battle_state.gd` 中添加：

```gdscript
var auto_battle_mode: AutoBattleMode = AutoBattleMode.new()
```

在 `to_dictionary()` 中添加：

```gdscript
"auto_battle_mode": auto_battle_mode.to_dictionary()
```

在 `to_result_dictionary()` 中添加：

```gdscript
"auto_battle_mode": auto_battle_mode.to_dictionary()
```

添加新方法：

```gdscript
func load_from_dictionary(data: Dictionary) -> void:
	# 现有字段加载
	battlefield_width = int(data.get("battlefield_width", 7))
	battlefield_height = int(data.get("battlefield_height", 5))
	time_mode = str(data.get("time_mode", TIME_MODE_PAUSE_ON_ACTION))
	terrain_grid = data.get("terrain_grid", [])
	current_unit_id = str(data.get("current_unit_id", ""))
	is_action_phase = bool(data.get("is_action_phase", false))
	is_finished = bool(data.get("is_finished", false))
	victory = bool(data.get("victory", false))
	log.clear()
	var log_data = data.get("log", [])
	if typeof(log_data) == TYPE_ARRAY:
		for item in log_data:
			log.append(str(item))
	source_map_id = str(data.get("source_map_id", "mountain_pass"))
	source_object_id = str(data.get("source_object_id", ""))
	quest_id = str(data.get("quest_id", ""))
	reward_martial_art_id = str(data.get("reward_martial_art_id", "basic_sword"))
	proficiency_reward = int(data.get("proficiency_reward", 1))
	victory_rewards = data.get("victory_rewards", {})
	# 新增：加载 auto_battle_mode
	var auto_data = data.get("auto_battle_mode", {})
	if typeof(auto_data) == TYPE_DICTIONARY:
		auto_battle_mode.from_dictionary(auto_data)
```

- [ ] **Step 3: 编写测试**

```gdscript
# tests/test_auto_battle_mode.gd
extends "res://tests/test_base.gd"

func test_default_is_manual_mode() -> void:
	var mode = AutoBattleMode.new()
	assert_false(mode.is_auto, "默认应为手动模式")

func test_toggle_switches_mode() -> void:
	var mode = AutoBattleMode.new()
	mode.toggle()
	assert_true(mode.is_auto, "切换后应为自动模式")
	mode.toggle()
	assert_false(mode.is_auto, "再次切换应为手动模式")

func test_set_auto() -> void:
	var mode = AutoBattleMode.new()
	mode.set_auto(true)
	assert_true(mode.is_auto, "set_auto(true) 应设为自动模式")
	mode.set_auto(false)
	assert_false(mode.is_auto, "set_auto(false) 应设为手动模式")

func test_to_dictionary() -> void:
	var mode = AutoBattleMode.new()
	mode.set_auto(true)
	var dict = mode.to_dictionary()
	assert_true(dict.get("is_auto", false), "序列化应包含 is_auto")

func test_from_dictionary() -> void:
	var mode = AutoBattleMode.new()
	mode.from_dictionary({"is_auto": true})
	assert_true(mode.is_auto, "反序列化应恢复 is_auto")

func test_from_dictionary_missing_field() -> void:
	var mode = AutoBattleMode.new()
	mode.from_dictionary({})
	assert_false(mode.is_auto, "缺少字段时应默认为手动模式")

func test_battle_state_has_auto_mode() -> void:
	var battle = TacticalBattleState.new()
	assert_not_null(battle.auto_battle_mode, "战斗状态应包含 auto_battle_mode")
	assert_false(battle.auto_battle_mode.is_auto, "默认应为手动模式")

func test_battle_state_serialization() -> void:
	var battle = TacticalBattleState.new()
	battle.auto_battle_mode.set_auto(true)
	var dict = battle.to_dictionary()
	assert_true(dict.get("auto_battle_mode", {}).get("is_auto", false), "序列化应包含 auto_battle_mode")

func test_battle_state_load_from_dictionary() -> void:
	var battle = TacticalBattleState.new()
	battle.load_from_dictionary({
		"auto_battle_mode": {"is_auto": true}
	})
	assert_true(battle.auto_battle_mode.is_auto, "反序列化应恢复 auto_battle_mode")

func test_battle_state_load_missing_auto_mode() -> void:
	var battle = TacticalBattleState.new()
	battle.load_from_dictionary({})
	assert_false(battle.auto_battle_mode.is_auto, "缺少字段时应默认为手动模式")
```

- [ ] **Step 4: 运行测试**

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 所有测试通过

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/auto_battle_mode.gd scripts/domain/tactical_battle_state.gd tests/test_auto_battle_mode.gd
git commit -m "feat: add AutoBattleMode data layer"
```

---

### Task 2: TacticalAI 核心逻辑

**Files:**
- Create: `scripts/systems/tactical_ai.gd`
- Test: `tests/test_tactical_ai.gd`

- [ ] **Step 1: 创建 TacticalAI 类骨架**

```gdscript
# scripts/systems/tactical_ai.gd
class_name TacticalAI
extends RefCounted

const TacticalBattleStateScript = preload("res://scripts/domain/tactical_battle_state.gd")

var repository = null

func set_repository(next_repository) -> void:
	repository = next_repository

# 返回单位的最优行动
func evaluate(unit, battle) -> Dictionary:
	# TODO: 实现
	return {}

# 计算某位置下某技能能覆盖的敌人数量
func count_targets_from_position(skill_id: String, position: Vector2i, enemies: Array, battle) -> int:
	# TODO: 实现
	return 0

# 获取单位可用技能（过滤 MP 不足的）
func get_available_skills(unit) -> Array[String]:
	# TODO: 实现
	return []
```

- [ ] **Step 2: 实现 get_available_skills 方法**

```gdscript
func get_available_skills(unit) -> Array[String]:
	var result: Array[String] = []
	if unit == null or repository == null:
		return result
	for skill_id in unit.martial_art_ids:
		var skill_data = repository.get_martial_art(skill_id)
		if skill_data.is_empty():
			continue
		var tactical = skill_data.get("tactical", {})
		if typeof(tactical) != TYPE_DICTIONARY:
			continue
		var mp_cost = int(tactical.get("mp_cost", skill_data.get("mp_cost", 0)))
		if unit.mp >= mp_cost:
			result.append(skill_id)
	return result
```

- [ ] **Step 3: 实现 count_targets_from_position 方法**

```gdscript
func count_targets_from_position(skill_id: String, position: Vector2i, enemies: Array, battle) -> int:
	if skill_id.is_empty() or enemies.is_empty():
		return 0
	var skill_data = repository.get_martial_art(skill_id) if repository != null else {}
	if skill_data.is_empty():
		return 0
	var tactical = skill_data.get("tactical", {})
	if typeof(tactical) != TYPE_DICTIONARY:
		return 0
	var shape = str(tactical.get("range_shape", ""))
	var range_val = max(1, int(tactical.get("range", 1)))
	var count = 0
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var enemy_cell = Vector2i(int(enemy.cell.get("q", 0)), int(enemy.cell.get("r", 0)))
		var distance = abs(position.x - enemy_cell.x) + abs(position.y - enemy_cell.y)
		if distance <= 0 or distance > range_val:
			continue
		match shape:
			"diamond":
				count += 1
			"line":
				if position.x == enemy_cell.x or position.y == enemy_cell.y:
					count += 1
			"surround":
				if max(abs(position.x - enemy_cell.x), abs(position.y - enemy_cell.y)) == 1:
					count += 1
			"fan":
				# 简化：检查四个方向
				for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var delta = enemy_cell - position
					var projection = delta.x * direction.x + delta.y * direction.y
					if projection > 0:
						var cross = abs(delta.x * direction.y - delta.y * direction.x)
						if cross <= projection * 2:
							count += 1
							break
			"ring":
				if distance == range_val:
					count += 1
			"pierce":
				if position.x == enemy_cell.x or position.y == enemy_cell.y:
					count += 1
			"target_cross_1":
				# 简化：检查十字范围
				if distance <= 1:
					count += 1
	return count
```

- [ ] **Step 4: 实现 evaluate 方法**

```gdscript
func evaluate(unit, battle) -> Dictionary:
	if unit == null or battle == null:
		return {"success": false, "message": "无效单位或战斗状态"}
	var enemies = battle.get_living_units_by_team(TacticalBattleStateScript.TEAM_ENEMY)
	if enemies.is_empty():
		return {"success": false, "message": "无敌人"}
	var movable_cells = _get_movable_cells(battle, unit)
	var available_skills = get_available_skills(unit)
	var best_action = {"move_to": unit.cell, "use_skill": "", "target": Vector2i.ZERO, "targets_hit": 0, "damage": 0}
	for cell in movable_cells:
		var cell_v = Vector2i(int(cell.get("q", 0)), int(cell.get("r", 0)))
		# 评估普攻
		var attack_targets = _count_attack_targets(cell_v, enemies, unit)
		if attack_targets > best_action.get("targets_hit", 0) or (attack_targets == best_action.get("targets_hit", 0) and _calculate_attack_damage(unit) > best_action.get("damage", 0)):
			best_action = {"move_to": cell, "use_skill": "attack", "target": _find_best_target(cell_v, enemies, unit), "targets_hit": attack_targets, "damage": _calculate_attack_damage(unit)}
		# 评估技能
		for skill_id in available_skills:
			var skill_targets = count_targets_from_position(skill_id, cell_v, enemies, battle)
			var skill_damage = _calculate_skill_damage(unit, skill_id)
			if skill_targets > best_action.get("targets_hit", 0) or (skill_targets == best_action.get("targets_hit", 0) and skill_damage > best_action.get("damage", 0)):
				best_action = {"move_to": cell, "use_skill": skill_id, "target": _find_best_skill_target(cell_v, enemies, unit, skill_id, battle), "targets_hit": skill_targets, "damage": skill_damage}
	if best_action.get("targets_hit", 0) == 0:
		var nearest_enemy = _find_nearest_enemy(unit, enemies)
		if nearest_enemy != null:
			var best_move = _find_closest_cell(movable_cells, nearest_enemy.cell)
			best_action = {"move_to": best_move, "use_skill": "attack", "target": nearest_enemy.cell, "targets_hit": 0, "damage": 0}
	return best_action

func _get_movable_cells(battle, unit) -> Array:
	var result: Array = []
	for q in range(battle.battlefield_width):
		for r in range(battle.battlefield_height):
			var cell = {"q": q, "r": r}
			var distance = abs(int(unit.cell.get("q", 0)) - q) + abs(int(unit.cell.get("r", 0)) - r)
			if distance > unit.move_range:
				continue
			if _is_cell_occupied_by_other(battle, cell, unit.unit_id):
				continue
			result.append(cell)
	return result

func _is_cell_occupied_by_other(battle, cell: Dictionary, unit_id: String) -> bool:
	for unit in battle.units:
		if unit.unit_id == unit_id:
			continue
		if unit.is_alive() and int(unit.cell.get("q", 0)) == int(cell.get("q", 0)) and int(unit.cell.get("r", 0)) == int(cell.get("r", 0)):
			return true
	return false

func _count_attack_targets(position: Vector2i, enemies: Array, unit) -> int:
	var count = 0
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var enemy_cell = Vector2i(int(enemy.cell.get("q", 0)), int(enemy.cell.get("r", 0)))
		var distance = abs(position.x - enemy_cell.x) + abs(position.y - enemy_cell.y)
		if distance <= unit.attack_range:
			count += 1
	return count

func _calculate_attack_damage(unit) -> int:
	return unit.attack

func _find_best_target(position: Vector2i, enemies: Array, unit) -> Vector2i:
	var best_target = Vector2i.ZERO
	var best_distance = 999999
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var enemy_cell = Vector2i(int(enemy.cell.get("q", 0)), int(enemy.cell.get("r", 0)))
		var distance = abs(position.x - enemy_cell.x) + abs(position.y - enemy_cell.y)
		if distance <= unit.attack_range and distance < best_distance:
			best_target = enemy_cell
			best_distance = distance
	return best_target

func _calculate_skill_damage(unit, skill_id: String) -> int:
	if repository == null:
		return 0
	var skill_data = repository.get_martial_art(skill_id)
	if skill_data.is_empty():
		return 0
	var tactical = skill_data.get("tactical", {})
	var damage_bonus = int(tactical.get("damage_bonus", 0))
	return unit.attack + damage_bonus

func _find_best_skill_target(position: Vector2i, enemies: Array, unit, skill_id: String, battle) -> Vector2i:
	var skill_data = repository.get_martial_art(skill_id) if repository != null else {}
	if skill_data.is_empty():
		return Vector2i.ZERO
	var tactical = skill_data.get("tactical", {})
	var shape = str(tactical.get("range_shape", ""))
	var range_val = max(1, int(tactical.get("range", 1)))
	var best_target = Vector2i.ZERO
	var best_count = 0
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var enemy_cell = Vector2i(int(enemy.cell.get("q", 0)), int(enemy.cell.get("r", 0)))
		var distance = abs(position.x - enemy_cell.x) + abs(position.y - enemy_cell.y)
		if distance > range_val:
			continue
		var count = 0
		match shape:
			"diamond":
				count = _count_enemies_in_diamond(position, enemies, range_val)
			"line":
				count = _count_enemies_in_line(position, enemies, range_val)
			"surround":
				count = _count_enemies_in_surround(position, enemies)
			"fan":
				count = _count_enemies_in_fan(position, enemies, range_val)
			"ring":
				count = _count_enemies_in_ring(position, enemies, range_val)
			"pierce":
				count = _count_enemies_in_pierce(position, enemies, range_val)
			"target_cross_1":
				count = _count_enemies_in_cross(position, enemies)
		if count > best_count:
			best_target = enemy_cell
			best_count = count
	return best_target

func _find_nearest_enemy(unit, enemies: Array):
	var nearest = null
	var nearest_distance = 999999
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var distance = abs(int(unit.cell.get("q", 0)) - int(enemy.cell.get("q", 0))) + abs(int(unit.cell.get("r", 0)) - int(enemy.cell.get("r", 0)))
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest

func _find_closest_cell(cells: Array, target_cell: Dictionary) -> Dictionary:
	if cells.is_empty():
		return {"q": 0, "r": 0}
	var best_cell = cells[0]
	var best_distance = 999999
	for cell in cells:
		var distance = abs(int(cell.get("q", 0)) - int(target_cell.get("q", 0))) + abs(int(cell.get("r", 0)) - int(target_cell.get("r", 0)))
		if distance < best_distance:
			best_cell = cell
			best_distance = distance
	return best_cell

func _count_enemies_in_diamond(position: Vector2i, enemies: Array, range_val: int) -> int:
	var count = 0
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var enemy_cell = Vector2i(int(enemy.cell.get("q", 0)), int(enemy.cell.get("r", 0)))
		var distance = abs(position.x - enemy_cell.x) + abs(position.y - enemy_cell.y)
		if distance > 0 and distance <= range_val:
			count += 1
	return count

func _count_enemies_in_line(position: Vector2i, enemies: Array, range_val: int) -> int:
	var count = 0
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var enemy_cell = Vector2i(int(enemy.cell.get("q", 0)), int(enemy.cell.get("r", 0)))
		var distance = abs(position.x - enemy_cell.x) + abs(position.y - enemy_cell.y)
		if distance > 0 and distance <= range_val and (position.x == enemy_cell.x or position.y == enemy_cell.y):
			count += 1
	return count

func _count_enemies_in_surround(position: Vector2i, enemies: Array) -> int:
	var count = 0
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var enemy_cell = Vector2i(int(enemy.cell.get("q", 0)), int(enemy.cell.get("r", 0)))
		if max(abs(position.x - enemy_cell.x), abs(position.y - enemy_cell.y)) == 1:
			count += 1
	return count

func _count_enemies_in_fan(position: Vector2i, enemies: Array, range_val: int) -> int:
	var count = 0
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var enemy_cell = Vector2i(int(enemy.cell.get("q", 0)), int(enemy.cell.get("r", 0)))
		var distance = abs(position.x - enemy_cell.x) + abs(position.y - enemy_cell.y)
		if distance > 0 and distance <= range_val:
			for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var delta = enemy_cell - position
				var projection = delta.x * direction.x + delta.y * direction.y
				if projection > 0:
					var cross = abs(delta.x * direction.y - delta.y * direction.x)
					if cross <= projection * 2:
						count += 1
						break
	return count

func _count_enemies_in_ring(position: Vector2i, enemies: Array, range_val: int) -> int:
	var count = 0
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var enemy_cell = Vector2i(int(enemy.cell.get("q", 0)), int(enemy.cell.get("r", 0)))
		var distance = abs(position.x - enemy_cell.x) + abs(position.y - enemy_cell.y)
		if distance == range_val:
			count += 1
	return count

func _count_enemies_in_pierce(position: Vector2i, enemies: Array, range_val: int) -> int:
	var count = 0
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var enemy_cell = Vector2i(int(enemy.cell.get("q", 0)), int(enemy.cell.get("r", 0)))
		var distance = abs(position.x - enemy_cell.x) + abs(position.y - enemy_cell.y)
		if distance > 0 and distance <= range_val and (position.x == enemy_cell.x or position.y == enemy_cell.y):
			count += 1
	return count

func _count_enemies_in_cross(position: Vector2i, enemies: Array) -> int:
	var count = 0
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var enemy_cell = Vector2i(int(enemy.cell.get("q", 0)), int(enemy.cell.get("r", 0)))
		var distance = abs(position.x - enemy_cell.x) + abs(position.y - enemy_cell.y)
		if distance <= 1:
			count += 1
	return count
```

- [ ] **Step 5: 编写测试**

```gdscript
# tests/test_tactical_ai.gd
extends "res://tests/test_base.gd"

var _ai: TacticalAI
var _battle: TacticalBattleState
var _mock_repository: MockRepository

class MockRepository extends RefCounted:
	var martial_arts: Dictionary = {}

	func get_martial_art(id: String) -> Dictionary:
		return martial_arts.get(id, {})

	func add_martial_art(id: String, data: Dictionary) -> void:
		martial_arts[id] = data

func before_each() -> void:
	_ai = TacticalAI.new()
	_battle = TacticalBattleState.new()
	_mock_repository = MockRepository.new()
	_ai.set_repository(_mock_repository)
	_mock_repository.add_martial_art("basic_sword", {
		"id": "basic_sword",
		"name": "基础剑法",
		"tactical": {
			"damage_bonus": 6,
			"range": 1,
			"range_shape": "diamond",
			"mp_cost": 3
		}
	})
	_mock_repository.add_martial_art("straight_sword_thrust", {
		"id": "straight_sword_thrust",
		"name": "穿云刺",
		"tactical": {
			"damage_bonus": 4,
			"range": 2,
			"range_shape": "line",
			"mp_cost": 5
		}
	})

func test_get_available_skills_with_enough_mp() -> void:
	var unit = TacticalUnitState.new()
	unit.martial_art_ids = ["basic_sword", "straight_sword_thrust"]
	unit.mp = 10
	var skills = _ai.get_available_skills(unit)
	assert_eq(skills.size(), 2, "MP 充足时应返回所有技能")

func test_get_available_skills_with_low_mp() -> void:
	var unit = TacticalUnitState.new()
	unit.martial_art_ids = ["basic_sword", "straight_sword_thrust"]
	unit.mp = 4
	var skills = _ai.get_available_skills(unit)
	assert_eq(skills.size(), 1, "MP 不足时应过滤高消耗技能")
	assert_true(skills.has("basic_sword"), "应保留低消耗技能")

func test_get_available_skills_empty() -> void:
	var unit = TacticalUnitState.new()
	unit.martial_art_ids = []
	unit.mp = 10
	var skills = _ai.get_available_skills(unit)
	assert_eq(skills.size(), 0, "无技能时应返回空数组")

func test_count_targets_from_position_diamond() -> void:
	_battle.battlefield_width = 5
	_battle.battlefield_height = 5
	var enemy1 = TacticalUnitState.new()
	enemy1.unit_id = "enemy1"
	enemy1.team = "enemy"
	enemy1.cell = {"q": 3, "r": 2}
	enemy1.hp = 10
	var enemy2 = TacticalUnitState.new()
	enemy2.unit_id = "enemy2"
	enemy2.team = "enemy"
	enemy2.cell = {"q": 2, "r": 3}
	enemy2.hp = 10
	_battle.add_unit(enemy1)
	_battle.add_unit(enemy2)
	var enemies = _battle.get_living_units_by_team("enemy")
	var count = _ai.count_targets_from_position("basic_sword", Vector2i(2, 2), enemies, _battle)
	assert_eq(count, 2, "应计算范围内敌人数量")

func test_count_targets_from_position_line() -> void:
	_battle.battlefield_width = 5
	_battle.battlefield_height = 5
	var enemy1 = TacticalUnitState.new()
	enemy1.unit_id = "enemy1"
	enemy1.team = "enemy"
	enemy1.cell = {"q": 2, "r": 4}
	enemy1.hp = 10
	var enemy2 = TacticalUnitState.new()
	enemy2.unit_id = "enemy2"
	enemy2.team = "enemy"
	enemy2.cell = {"q": 2, "r": 3}
	enemy2.hp = 10
	_battle.add_unit(enemy1)
	_battle.add_unit(enemy2)
	var enemies = _battle.get_living_units_by_team("enemy")
	var count = _ai.count_targets_from_position("straight_sword_thrust", Vector2i(2, 2), enemies, _battle)
	assert_eq(count, 2, "直线范围应计算同列敌人")

func test_evaluate_selects_skill_with_most_targets() -> void:
	_battle.battlefield_width = 5
	_battle.battlefield_height = 5
	var player = TacticalUnitState.new()
	player.unit_id = "player"
	player.team = "player"
	player.cell = {"q": 2, "r": 2}
	player.hp = 100
	player.mp = 10
	player.attack = 10
	player.move_range = 1
	player.attack_range = 1
	player.martial_art_ids = ["basic_sword"]
	_battle.add_unit(player)
	var enemy1 = TacticalUnitState.new()
	enemy1.unit_id = "enemy1"
	enemy1.team = "enemy"
	enemy1.cell = {"q": 3, "r": 2}
	enemy1.hp = 10
	var enemy2 = TacticalUnitState.new()
	enemy2.unit_id = "enemy2"
	enemy2.team = "enemy"
	enemy2.cell = {"q": 2, "r": 3}
	enemy2.hp = 10
	_battle.add_unit(enemy1)
	_battle.add_unit(enemy2)
	var result = _ai.evaluate(player, _battle)
	assert_true(result.get("success", true), "评估应成功")
	assert_eq(result.get("use_skill", ""), "basic_sword", "应选择能打到最多敌人的技能")

func test_evaluate_falls_back_to_attack_when_no_mp() -> void:
	_battle.battlefield_width = 5
	_battle.battlefield_height = 5
	var player = TacticalUnitState.new()
	player.unit_id = "player"
	player.team = "player"
	player.cell = {"q": 2, "r": 2}
	player.hp = 100
	player.mp = 0
	player.attack = 10
	player.move_range = 1
	player.attack_range = 1
	player.martial_art_ids = ["basic_sword"]
	_battle.add_unit(player)
	var enemy = TacticalUnitState.new()
	enemy.unit_id = "enemy"
	enemy.team = "enemy"
	enemy.cell = {"q": 3, "r": 2}
	enemy.hp = 10
	_battle.add_unit(enemy)
	var result = _ai.evaluate(player, _battle)
	assert_eq(result.get("use_skill", ""), "attack", "MP 不足时应使用普攻")

func test_evaluate_moves_toward_nearest_enemy_when_no_targets() -> void:
	_battle.battlefield_width = 5
	_battle.battlefield_height = 5
	var player = TacticalUnitState.new()
	player.unit_id = "player"
	player.team = "player"
	player.cell = {"q": 0, "r": 0}
	player.hp = 100
	player.mp = 10
	player.attack = 10
	player.move_range = 2
	player.attack_range = 1
	player.martial_art_ids = ["basic_sword"]
	_battle.add_unit(player)
	var enemy = TacticalUnitState.new()
	enemy.unit_id = "enemy"
	enemy.team = "enemy"
	enemy.cell = {"q": 4, "r": 4}
	enemy.hp = 10
	_battle.add_unit(enemy)
	var result = _ai.evaluate(player, _battle)
	var move_to = result.get("move_to", {})
	assert_true(int(move_to.get("q", 0)) > 0 or int(move_to.get("r", 0)) > 0, "应向敌人方向移动")

func test_evaluate_avoids_occupied_cells() -> void:
	_battle.battlefield_width = 5
	_battle.battlefield_height = 5
	var player = TacticalUnitState.new()
	player.unit_id = "player"
	player.team = "player"
	player.cell = {"q": 2, "r": 2}
	player.hp = 100
	player.mp = 10
	player.attack = 10
	player.move_range = 1
	player.attack_range = 1
	player.martial_art_ids = ["basic_sword"]
	_battle.add_unit(player)
	var ally = TacticalUnitState.new()
	ally.unit_id = "ally"
	ally.team = "player"
	ally.cell = {"q": 3, "r": 2}
	ally.hp = 100
	_battle.add_unit(ally)
	var enemy = TacticalUnitState.new()
	enemy.unit_id = "enemy"
	enemy.team = "enemy"
	enemy.cell = {"q": 3, "r": 2}
	enemy.hp = 10
	_battle.add_unit(enemy)
	var result = _ai.evaluate(player, _battle)
	var move_to = result.get("move_to", {})
	assert_false(int(move_to.get("q", 0)) == 3 and int(move_to.get("r", 0)) == 2, "不应移动到友军位置")
```

- [ ] **Step 6: 运行测试**

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 所有测试通过

- [ ] **Step 7: Commit**

```bash
git add scripts/systems/tactical_ai.gd tests/test_tactical_ai.gd
git commit -m "feat: add TacticalAI core logic"
```

---

### Task 3: 战斗流程集成

**Files:**
- Modify: `scripts/systems/tactical_combat_system.gd`

- [ ] **Step 1: 添加 TacticalAI 依赖**

在 `scripts/systems/tactical_combat_system.gd` 顶部添加：

```gdscript
const TacticalAIScript = preload("res://scripts/systems/tactical_ai.gd")

var _tactical_ai = null
```

添加初始化方法：

```gdscript
func set_tactical_ai(tactical_ai) -> void:
	_tactical_ai = tactical_ai
```

- [ ] **Step 2: 修改 advance_charge 方法**

在 `advance_charge` 方法中，当单位集气满时检查自动模式：

```gdscript
func advance_charge(battle, delta: float) -> void:
	if battle == null or battle.is_finished or battle.is_action_phase:
		return
	for unit in battle.units:
		if not unit.is_alive():
			continue
		unit.charge = min(TacticalBattleStateScript.CHARGE_LIMIT, int(unit.charge + round(unit.charge_speed * delta)))
	var ready = get_ready_unit(battle)
	if ready != null:
		begin_unit_action(battle, ready.unit_id)
		if battle.auto_battle_mode.is_auto and ready.team == TacticalBattleStateScript.TEAM_PLAYER:
			_resolve_auto_action(battle, ready)
```

- [ ] **Step 3: 添加自动行动处理方法**

```gdscript
func _resolve_auto_action(battle, unit) -> void:
	if _tactical_ai == null:
		_log(battle, "AI 系统未初始化。")
		end_unit_action(battle, unit.unit_id)
		return
	var action = _tactical_ai.evaluate(unit, battle)
	if not action.get("success", true):
		_log(battle, "AI 决策失败：%s" % str(action.get("message", "未知错误")))
		end_unit_action(battle, unit.unit_id)
		return
	var move_to = action.get("move_to", unit.cell)
	var use_skill = str(action.get("use_skill", "attack"))
	var target = action.get("target", Vector2i.ZERO)
	move_unit(battle, unit.unit_id, move_to)
	var target_cells = [target]
	var result = resolve_action(battle, unit.unit_id, use_skill, target_cells)
	if result.get("success", false):
		_log(battle, "%s 自动行动完成。" % unit.display_name)
	else:
		_log(battle, "%s 自动行动失败：%s" % [unit.display_name, str(result.get("message", "未知错误"))])
	end_unit_action(battle, unit.unit_id)
```

- [ ] **Step 4: 修改 create_battle 方法初始化 AI**

在 `create_battle` 方法末尾添加：

```gdscript
if _tactical_ai != null:
	_tactical_ai.set_repository(source)
```

- [ ] **Step 5: 运行测试**

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 所有测试通过

- [ ] **Step 6: Commit**

```bash
git add scripts/systems/tactical_combat_system.gd
git commit -m "feat: integrate TacticalAI into combat flow"
```

---

### Task 4: UI 与交互

**Files:**
- Modify: `scenes/battle.tscn` 或相关 UI 脚本

- [ ] **Step 1: 添加模式切换按键处理**

在战斗场景的输入处理中添加：

```gdscript
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_A:
			_toggle_auto_mode()

func _toggle_auto_mode() -> void:
	if _battle_state == null:
		return
	_battle_state.auto_battle_mode.toggle()
	var mode_text = "自动" if _battle_state.auto_battle_mode.is_auto else "手动"
	_log("切换到%s战斗模式" % mode_text)
	_update_mode_ui()
```

- [ ] **Step 2: 添加模式显示 UI**

在战斗 UI 中添加标签显示当前模式：

```gdscript
@onready var mode_label: Label = $UI/ModeLabel

func _update_mode_ui() -> void:
	if mode_label == null or _battle_state == null:
		return
	var mode_text = "自动" if _battle_state.auto_battle_mode.is_auto else "手动"
	mode_label.text = "模式: %s [按 A 切换]" % mode_text
```

- [ ] **Step 3: 初始化 UI**

在战斗开始时调用：

```gdscript
func _ready() -> void:
	_update_mode_ui()
```

- [ ] **Step 4: 运行游戏测试**

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --path .
```

Expected: 战斗中按 A 键可切换模式，UI 显示当前模式

- [ ] **Step 5: Commit**

```bash
git add scenes/battle.tscn
git commit -m "feat: add auto battle mode toggle UI"
```

---

### Task 5: 集成测试与验收

**Files:**
- Test: 全量测试

- [ ] **Step 1: 运行全量测试**

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 所有测试通过

- [ ] **Step 2: 手动验收**

1. 进入战棋战斗
2. 按 A 切换到自动模式
3. 观察所有玩家单位自动行动
4. 查看战斗日志，确认 AI 决策合理
5. 按 A 切回手动模式
6. 确认当前单位等待操作

- [ ] **Step 3: Commit 验收结果**

```bash
git add .
git commit -m "test: verify auto battle mode functionality"
```

---

## 风险与缓解

| 风险 | 缓解措施 |
|------|----------|
| AI 决策过于简单 | 采用"最大化覆盖"策略，比随机行动更有策略性 |
| 模式切换打断战斗 | 即时切换，不中断动画 |
| AI 行动动画时间过长 | 复用现有动画系统 |
| 旧存档缺少 auto_battle_mode | 默认为手动模式 |
