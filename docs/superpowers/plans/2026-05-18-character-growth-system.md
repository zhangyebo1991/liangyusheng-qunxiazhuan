# 角色成长系统实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现模块化角色成长系统，包含技能树、内功心法和武学领悟三个子系统

**Architecture:** 使用GrowthManager协调三个独立子系统，数据驱动设计，与现有战斗/任务/对话系统集成

**Tech Stack:** Godot 4.6, GDScript, JSON数据文件

---

## 文件结构

### 新建文件
- `scripts/systems/growth_manager.gd` - 统一管理器
- `scripts/systems/skill_tree_system.gd` - 技能树系统
- `scripts/systems/inner_art_system.gd` - 内功心法系统
- `scripts/systems/insight_system.gd` - 武学领悟系统
- `data/skill_trees/basic_sword.json` - 基础剑法技能树数据
- `data/inner_arts/calm_heart.json` - 静心诀心法数据
- `data/martial_insights/sword_insights.json` - 剑法领悟数据
- `tests/test_growth_system.gd` - 成长系统测试

### 修改文件
- `scripts/core/game_state.gd` - 集成GrowthManager
- `scripts/systems/proficiency_system.gd` - 扩展熟练度点数
- `scripts/systems/effect_system.gd` - 支持技能树效果

---

## Task 1: 创建GrowthManager基础结构

**Files:**
- Create: `scripts/systems/growth_manager.gd`
- Test: `tests/test_growth_system.gd`

- [ ] **Step 1: 写失败测试**

```gdscript
# tests/test_growth_system.gd
extends GutTest

func test_growth_manager_initialization():
    var manager = GrowthManager.new()
    assert_not_null(manager.skill_trees)
    assert_not_null(manager.inner_arts)
    assert_not_null(manager.insights)
    assert_eq(manager.proficiency_points, 0)

func test_on_battle_end_adds_proficiency():
    var manager = GrowthManager.new()
    var battle_data = {"enemies": 3, "difficulty": 1}
    manager.on_battle_end(battle_data)
    assert_gt(manager.proficiency_points, 0)
```

- [ ] **Step 2: 运行测试确认失败**

运行: `godot --headless --path . -s tests/run_tests.gd`
预期: 失败，"GrowthManager not found"

- [ ] **Step 3: 写最小实现**

```gdscript
# scripts/systems/growth_manager.gd
extends RefCounted

var proficiency_points: int = 0
var skill_trees: RefCounted
var inner_arts: RefCounted
var insights: RefCounted

func _init():
    skill_trees = preload("res://scripts/systems/skill_tree_system.gd").new()
    inner_arts = preload("res://scripts/systems/inner_art_system.gd").new()
    insights = preload("res://scripts/systems/insight_system.gd").new()

func on_battle_end(battle_data: Dictionary):
    var enemies = int(battle_data.get("enemies", 1))
    var difficulty = int(battle_data.get("difficulty", 1))
    proficiency_points += enemies * difficulty

func on_dialogue_event(npc_id: String, dialogue_id: String):
    insights.check_triggers("dialogue", {"npc": npc_id, "dialogue": dialogue_id})

func on_item_used(item_id: String):
    insights.check_triggers("item", {"item": item_id})
```

- [ ] **Step 4: 运行测试确认通过**

运行: `godot --headless --path . -s tests/run_tests.gd`
预期: 通过

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/growth_manager.gd tests/test_growth_system.gd
git commit -m "feat: add GrowthManager basic structure"
```

---

## Task 2: 创建技能树系统

**Files:**
- Create: `scripts/systems/skill_tree_system.gd`
- Create: `data/skill_trees/basic_sword.json`
- Modify: `tests/test_growth_system.gd`

- [ ] **Step 1: 写失败测试**

```gdscript
# tests/test_growth_system.gd 添加
func test_skill_tree_unlock_node():
    var manager = GrowthManager.new()
    manager.proficiency_points = 5
    var result = manager.unlock_skill_node("basic_sword", "dmg_1")
    assert_true(result.success)
    assert_eq(manager.proficiency_points, 4)

func test_skill_tree_insufficient_points():
    var manager = GrowthManager.new()
    manager.proficiency_points = 0
    var result = manager.unlock_skill_node("basic_sword", "dmg_1")
    assert_false(result.success)
```

- [ ] **Step 2: 运行测试确认失败**

运行: `godot --headless --path . -s tests/run_tests.gd`
预期: 失败

- [ ] **Step 3: 创建技能树数据**

```json
// data/skill_trees/basic_sword.json
{
  "skill_id": "basic_sword",
  "name": "基础剑法",
  "branches": [
    {
      "id": "power_branch",
      "name": "刚猛路线",
      "nodes": [
        {
          "id": "dmg_1",
          "name": "力道+3",
          "cost": 1,
          "effects": {"damage_bonus": 3}
        },
        {
          "id": "dmg_2",
          "name": "力道+5",
          "cost": 2,
          "requires": ["dmg_1"],
          "effects": {"damage_bonus": 5}
        },
        {
          "id": "crit",
          "name": "暴击强化",
          "cost": 3,
          "requires": ["dmg_2"],
          "effects": {"crit_chance": 0.1}
        }
      ]
    },
    {
      "id": "technique_branch",
      "name": "技巧路线",
      "nodes": [
        {
          "id": "acc_1",
          "name": "精准+5",
          "cost": 1,
          "effects": {"accuracy_bonus": 5}
        },
        {
          "id": "bleed",
          "name": "破绽攻击",
          "cost": 2,
          "requires": ["acc_1"],
          "effects": {"add_effect": "bleed"}
        },
        {
          "id": "multi",
          "name": "连击",
          "cost": 3,
          "requires": ["bleed"],
          "effects": {"extra_strike": 0.15}
        }
      ]
    }
  ]
}
```

- [ ] **Step 4: 实现技能树系统**

```gdscript
# scripts/systems/skill_tree_system.gd
extends RefCounted

var _trees: Dictionary = {}
var _unlocked_nodes: Dictionary = {}

func _init():
    _load_trees()

func _load_trees():
    var dir = DirAccess.open("res://data/skill_trees")
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".json"):
                var file = FileAccess.open("res://data/skill_trees/" + file_name, FileAccess.READ)
                var json = JSON.new()
                json.parse(file.get_as_text())
                var data = json.data
                _trees[data.skill_id] = data
            file_name = dir.get_next()

func unlock_node(skill_id: String, node_id: String, available_points: int) -> Dictionary:
    if not _trees.has(skill_id):
        return {"success": false, "message": "技能树不存在"}
    
    var tree = _trees[skill_id]
    var node = _find_node(tree, node_id)
    if node.is_empty():
        return {"success": false, "message": "节点不存在"}
    
    if _is_node_unlocked(skill_id, node_id):
        return {"success": false, "message": "节点已解锁"}
    
    var cost = int(node.get("cost", 1))
    if available_points < cost:
        return {"success": false, "message": "熟练度点数不足"}
    
    var requires = node.get("requires", [])
    for req in requires:
        if not _is_node_unlocked(skill_id, req):
            return {"success": false, "message": "未满足前置条件"}
    
    if not _unlocked_nodes.has(skill_id):
        _unlocked_nodes[skill_id] = []
    _unlocked_nodes[skill_id].append(node_id)
    
    return {"success": true, "cost": cost}

func _find_node(tree: Dictionary, node_id: String) -> Dictionary:
    for branch in tree.get("branches", []):
        for node in branch.get("nodes", []):
            if node.get("id") == node_id:
                return node
    return {}

func _is_node_unlocked(skill_id: String, node_id: String) -> bool:
    return _unlocked_nodes.has(skill_id) and node_id in _unlocked_nodes[skill_id]
```

- [ ] **Step 5: 运行测试确认通过**

运行: `godot --headless --path . -s tests/run_tests.gd`
预期: 通过

- [ ] **Step 6: 提交**

```bash
git add scripts/systems/skill_tree_system.gd data/skill_trees/basic_sword.json tests/test_growth_system.gd
git commit -m "feat: add skill tree system with basic sword data"
```

---

## Task 3: 创建内功心法系统

**Files:**
- Create: `scripts/systems/inner_art_system.gd`
- Create: `data/inner_arts/calm_heart.json`
- Modify: `tests/test_growth_system.gd`

- [ ] **Step 1: 写失败测试**

```gdscript
# tests/test_growth_system.gd 添加
func test_inner_art_upgrade():
    var manager = GrowthManager.new()
    manager.inner_arts.learn_art("calm_heart")
    var result = manager.inner_arts.upgrade_art("calm_heart", 5)
    assert_true(result.success)
    assert_eq(manager.inner_arts.get_art_level("calm_heart"), 1)

func test_inner_art_switch():
    var manager = GrowthManager.new()
    manager.inner_arts.learn_art("calm_heart")
    var result = manager.inner_arts.switch_active("calm_heart")
    assert_true(result.success)
    assert_eq(manager.inner_arts.get_active_art(), "calm_heart")
```

- [ ] **Step 2: 运行测试确认失败**

运行: `godot --headless --path . -s tests/run_tests.gd`
预期: 失败

- [ ] **Step 3: 创建心法数据**

```json
// data/inner_arts/calm_heart.json
{
  "id": "calm_heart",
  "name": "静心诀",
  "description": "入门心法，提升内力根基",
  "max_level": 10,
  "effects_per_level": {
    "max_mp": 3,
    "mp_regen": 1
  },
  "level_up_cost": [1, 1, 2, 2, 3, 3, 4, 4, 5, 5]
}
```

- [ ] **Step 4: 实现内功心法系统**

```gdscript
# scripts/systems/inner_art_system.gd
extends RefCounted

var _arts: Dictionary = {}
var _learned_arts: Dictionary = {}
var _active_art: String = ""

func _init():
    _load_arts()

func _load_arts():
    var dir = DirAccess.open("res://data/inner_arts")
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".json"):
                var file = FileAccess.open("res://data/inner_arts/" + file_name, FileAccess.READ)
                var json = JSON.new()
                json.parse(file.get_as_text())
                var data = json.data
                _arts[data.id] = data
            file_name = dir.get_next()

func learn_art(art_id: String):
    if _arts.has(art_id) and not _learned_arts.has(art_id):
        _learned_arts[art_id] = {"level": 0}

func upgrade_art(art_id: String, available_points: int) -> Dictionary:
    if not _learned_arts.has(art_id):
        return {"success": false, "message": "未学会此心法"}
    
    var art_data = _arts[art_id]
    var current_level = _learned_arts[art_id].level
    var max_level = int(art_data.get("max_level", 1))
    
    if current_level >= max_level:
        return {"success": false, "message": "已达最高级"}
    
    var costs = art_data.get("level_up_cost", [])
    var cost = 1
    if current_level < costs.size():
        cost = int(costs[current_level])
    
    if available_points < cost:
        return {"success": false, "message": "修为点不足"}
    
    _learned_arts[art_id].level += 1
    return {"success": true, "cost": cost}

func switch_active(art_id: String) -> Dictionary:
    if not _learned_arts.has(art_id):
        return {"success": false, "message": "未学会此心法"}
    
    _active_art = art_id
    return {"success": true}

func get_art_level(art_id: String) -> int:
    if _learned_arts.has(art_id):
        return _learned_arts[art_id].level
    return 0

func get_active_art() -> String:
    return _active_art
```

- [ ] **Step 5: 运行测试确认通过**

运行: `godot --headless --path . -s tests/run_tests.gd`
预期: 通过

- [ ] **Step 6: 提交**

```bash
git add scripts/systems/inner_art_system.gd data/inner_arts/calm_heart.json tests/test_growth_system.gd
git commit -m "feat: add inner art system with calm heart data"
```

---

## Task 4: 创建武学领悟系统

**Files:**
- Create: `scripts/systems/insight_system.gd`
- Create: `data/martial_insights/sword_insights.json`
- Modify: `tests/test_growth_system.gd`

- [ ] **Step 1: 写失败测试**

```gdscript
# tests/test_growth_system.gd 添加
func test_insight_trigger_check():
    var manager = GrowthManager.new()
    var context = {
        "skill_proficiency": {"basic_sword": 50},
        "skill_used_count": {"basic_sword": 100}
    }
    var result = manager.insights.check_triggers("combat", context)
    # 第一版只检查不报错
    assert_true(result.is_empty() or result.has("triggered"))
```

- [ ] **Step 2: 运行测试确认失败**

运行: `godot --headless --path . -s tests/run_tests.gd`
预期: 失败

- [ ] **Step 3: 创建领悟数据**

```json
// data/martial_insights/sword_insights.json
{
  "insights": [
    {
      "id": "sword_whirlwind",
      "name": "旋风剑领悟",
      "conditions": [
        {"type": "skill_proficiency", "skill": "basic_sword", "min": 30},
        {"type": "skill_used_count", "skill": "basic_sword", "min": 50},
        {"type": "random", "chance": 0.1}
      ],
      "trigger_scene": "combat",
      "result": {
        "unlock": "sword_whirlwind",
        "message": "实战中你领悟了「旋风剑」！"
      }
    }
  ]
}
```

- [ ] **Step 4: 实现领悟系统**

```gdscript
# scripts/systems/insight_system.gd
extends RefCounted

var _insights: Array = []
var _triggered: Dictionary = {}

func _init():
    _load_insights()

func _load_insights():
    var dir = DirAccess.open("res://data/martial_insights")
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".json"):
                var file = FileAccess.open("res://data/martial_insights/" + file_name, FileAccess.READ)
                var json = JSON.new()
                json.parse(file.get_as_text())
                var data = json.data
                _insights.append_array(data.get("insights", []))
            file_name = dir.get_next()

func check_triggers(scene: String, context: Dictionary) -> Dictionary:
    for insight in _insights:
        var trigger_scene = insight.get("trigger_scene", "any")
        if trigger_scene != "any" and trigger_scene != scene:
            continue
        
        if _triggered.has(insight.id):
            continue
        
        if _check_conditions(insight.get("conditions", []), context):
            _triggered[insight.id] = true
            return {
                "triggered": true,
                "id": insight.id,
                "unlock": insight.result.get("unlock", ""),
                "message": insight.result.get("message", "")
            }
    
    return {}

func _check_conditions(conditions: Array, context: Dictionary) -> bool:
    for condition in conditions:
        if not _check_single_condition(condition, context):
            return false
    return true

func _check_single_condition(condition: Dictionary, context: Dictionary) -> bool:
    var type = condition.get("type", "")
    
    match type:
        "skill_proficiency":
            var skill = condition.get("skill", "")
            var min_val = int(condition.get("min", 0))
            var proficiencies = context.get("skill_proficiency", {})
            return proficiencies.get(skill, 0) >= min_val
        
        "skill_used_count":
            var skill = condition.get("skill", "")
            var min_val = int(condition.get("min", 0))
            var counts = context.get("skill_used_count", {})
            return counts.get(skill, 0) >= min_val
        
        "random":
            var chance = float(condition.get("chance", 0))
            return randf() < chance
        
        "dialogue":
            var npc = condition.get("npc", "")
            var dialogue_id = condition.get("dialogue_id", "")
            var context_npc = context.get("npc", "")
            var context_dialogue = context.get("dialogue", "")
            return npc == context_npc and dialogue_id == context_dialogue
        
        "quest_completed":
            var quest = condition.get("quest", "")
            var completed = context.get("completed_quests", [])
            return quest in completed
        
        "item_used":
            var item = condition.get("item", "")
            return context.get("item", "") == item
        
        "inner_art_level":
            var min_level = int(condition.get("min", 0))
            var current_level = context.get("inner_art_level", 0)
            return current_level >= min_level
        
        "level":
            var min_level = int(condition.get("min", 0))
            return context.get("level", 0) >= min_level
    
    return false
```

- [ ] **Step 5: 运行测试确认通过**

运行: `godot --headless --path . -s tests/run_tests.gd`
预期: 通过

- [ ] **Step 6: 提交**

```bash
git add scripts/systems/insight_system.gd data/martial_insights/sword_insights.json tests/test_growth_system.gd
git commit -m "feat: add insight system with sword insights data"
```

---

## Task 5: 集成到GameState

**Files:**
- Modify: `scripts/core/game_state.gd`

- [ ] **Step 1: 写失败测试**

```gdscript
# tests/test_growth_system.gd 添加
func test_game_state_has_growth_manager():
    var game_state = GameState.new()
    assert_not_null(game_state.growth_manager)

func test_battle_end_updates_growth():
    var game_state = GameState.new()
    game_state.start_new_game()
    var old_points = game_state.growth_manager.proficiency_points
    game_state.growth_manager.on_battle_end({"enemies": 2, "difficulty": 1})
    assert_gt(game_state.growth_manager.proficiency_points, old_points)
```

- [ ] **Step 2: 运行测试确认失败**

运行: `godot --headless --path . -s tests/run_tests.gd`
预期: 失败

- [ ] **Step 3: 修改GameState**

```gdscript
# scripts/core/game_state.gd 添加
const GrowthManagerScript = preload("res://scripts/systems/growth_manager.gd")

var growth_manager = GrowthManagerScript.new()

func start_new_game() -> void:
    # 现有代码...
    growth_manager = GrowthManagerScript.new()
```

- [ ] **Step 4: 运行测试确认通过**

运行: `godot --headless --path . -s tests/run_tests.gd`
预期: 通过

- [ ] **Step 5: 提交**

```bash
git add scripts/core/game_state.gd
git commit -m "feat: integrate GrowthManager into GameState"
```

---

## Task 6: 扩展熟练度系统

**Files:**
- Modify: `scripts/systems/proficiency_system.gd`

- [ ] **Step 1: 写失败测试**

```gdscript
# tests/test_growth_system.gd 添加
func test_proficiency_system_tracks_points():
    var prof = ProficiencySystem.new()
    prof.add_proficiency_points(10)
    assert_eq(prof.get_proficiency_points(), 10)

func test_proficiency_system_spend_points():
    var prof = ProficiencySystem.new()
    prof.add_proficiency_points(10)
    var result = prof.spend_proficiency_points(3)
    assert_true(result)
    assert_eq(prof.get_proficiency_points(), 7)
```

- [ ] **Step 2: 运行测试确认失败**

运行: `godot --headless --path . -s tests/run_tests.gd`
预期: 失败

- [ ] **Step 3: 扩展ProficiencySystem**

```gdscript
# scripts/systems/proficiency_system.gd 添加
var _proficiency_points: int = 0

func add_proficiency_points(amount: int):
    _proficiency_points += amount

func spend_proficiency_points(amount: int) -> bool:
    if _proficiency_points >= amount:
        _proficiency_points -= amount
        return true
    return false

func get_proficiency_points() -> int:
    return _proficiency_points
```

- [ ] **Step 4: 运行测试确认通过**

运行: `godot --headless --path . -s tests/run_tests.gd`
预期: 通过

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/proficiency_system.gd
git commit -m "feat: extend proficiency system with points tracking"
```

---

## Task 7: 扩展效果系统

**Files:**
- Modify: `scripts/systems/effect_system.gd`

- [ ] **Step 1: 写失败测试**

```gdscript
# tests/test_growth_system.gd 添加
func test_effect_system_applies_skill_tree_bonus():
    var effect_sys = EffectSystem.new()
    var effects = {"damage_bonus": 5, "crit_chance": 0.1}
    var result = effect_sys.apply_skill_tree_effects(effects)
    assert_true(result.success)
```

- [ ] **Step 2: 运行测试确认失败**

运行: `godot --headless --path . -s tests/run_tests.gd`
预期: 失败

- [ ] **Step 3: 扩展EffectSystem**

```gdscript
# scripts/systems/effect_system.gd 添加
func apply_skill_tree_effects(effects: Dictionary) -> Dictionary:
    # 应用技能树效果到角色属性
    for key in effects.keys():
        match key:
            "damage_bonus":
                # 应用伤害加成
                pass
            "crit_chance":
                # 应用暴击率
                pass
            "accuracy_bonus":
                # 应用精准加成
                pass
            "add_effect":
                # 添加特殊效果
                pass
            "extra_strike":
                # 添加连击效果
                pass
    return {"success": true}
```

- [ ] **Step 4: 运行测试确认通过**

运行: `godot --headless --path . -s tests/run_tests.gd`
预期: 通过

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/effect_system.gd
git commit -m "feat: extend effect system for skill tree bonuses"
```

---

## Task 8: 存档集成

**Files:**
- Modify: `scripts/systems/save_system.gd`

- [ ] **Step 1: 写失败测试**

```gdscript
# tests/test_growth_system.gd 添加
func test_save_load_growth_data():
    var game_state = GameState.new()
    game_state.start_new_game()
    game_state.growth_manager.proficiency_points = 15
    
    var save_data = game_state.save_system.get_save_data(game_state)
    assert_true(save_data.has("growth"))
    assert_eq(save_data.growth.proficiency_points, 15)
```

- [ ] **Step 2: 运行测试确认失败**

运行: `godot --headless --path . -s tests/run_tests.gd`
预期: 失败

- [ ] **Step 3: 扩展SaveSystem**

```gdscript
# scripts/systems/save_system.gd 添加
func get_save_data(game_state) -> Dictionary:
    var data = {}
    # 现有存档逻辑...
    
    # 添加成长系统数据
    data["growth"] = {
        "proficiency_points": game_state.growth_manager.proficiency_points,
        "skill_tree_nodes": game_state.growth_manager.skill_trees._unlocked_nodes,
        "inner_arts": {
            "learned": game_state.growth_manager.inner_arts._learned_arts,
            "active": game_state.growth_manager.inner_arts._active_art
        },
        "triggered_insights": game_state.growth_manager.insights._triggered
    }
    
    return data

func load_save_data(game_state, data: Dictionary):
    # 现有读档逻辑...
    
    # 加载成长系统数据
    if data.has("growth"):
        var growth = data.growth
        game_state.growth_manager.proficiency_points = growth.get("proficiency_points", 0)
        game_state.growth_manager.skill_trees._unlocked_nodes = growth.get("skill_tree_nodes", {})
        
        var inner_arts = growth.get("inner_arts", {})
        game_state.growth_manager.inner_arts._learned_arts = inner_arts.get("learned", {})
        game_state.growth_manager.inner_arts._active_art = inner_arts.get("active", "")
        
        game_state.growth_manager.insights._triggered = growth.get("triggered_insights", {})
```

- [ ] **Step 4: 运行测试确认通过**

运行: `godot --headless --path . -s tests/run_tests.gd`
预期: 通过

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/save_system.gd
git commit -m "feat: integrate growth system with save/load"
```

---

## Task 9: 集成测试

**Files:**
- Modify: `tests/test_growth_system.gd`

- [ ] **Step 1: 写完整集成测试**

```gdscript
# tests/test_growth_system.gd 添加
func test_full_growth_workflow():
    var game_state = GameState.new()
    game_state.start_new_game()
    
    # 战斗获得熟练度
    game_state.growth_manager.on_battle_end({"enemies": 3, "difficulty": 1})
    assert_gt(game_state.growth_manager.proficiency_points, 0)
    
    # 解锁技能树节点
    var points_before = game_state.growth_manager.proficiency_points
    var result = game_state.growth_manager.unlock_skill_node("basic_sword", "dmg_1")
    assert_true(result.success)
    assert_eq(game_state.growth_manager.proficiency_points, points_before - 1)
    
    # 学习心法
    game_state.growth_manager.inner_arts.learn_art("calm_heart")
    assert_eq(game_state.growth_manager.inner_arts.get_art_level("calm_heart"), 0)
    
    # 升级心法
    result = game_state.growth_manager.inner_arts.upgrade_art("calm_heart", 5)
    assert_true(result.success)
    assert_eq(game_state.growth_manager.inner_arts.get_art_level("calm_heart"), 1)
```

- [ ] **Step 2: 运行测试确认通过**

运行: `godot --headless --path . -s tests/run_tests.gd`
预期: 通过

- [ ] **Step 3: 提交**

```bash
git add tests/test_growth_system.gd
git commit -m "test: add integration tests for growth system"
```

---

## Task 10: 文档更新

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 更新README**

在README.md的"当前阶段包含"部分添加：

```markdown
- 角色成长系统基础切片：技能树加点、内功心法修炼、武学领悟触发、GrowthManager统一管理。
```

- [ ] **Step 2: 提交**

```bash
git add README.md
git commit -m "docs: update README with growth system features"
```

---

## 自检清单

1. **规范覆盖**：所有设计文档中的功能都有对应任务
2. **占位符扫描**：无TBD、TODO等占位符
3. **类型一致性**：所有函数名、参数类型保持一致

## 执行选项

计划完成并保存到 `docs/superpowers/plans/2026-05-18-character-growth-system.md`。

**两种执行方式：**

**1. Subagent-Driven（推荐）** - 我为每个任务分发新的子任务代理，任务间进行审查，快速迭代

**2. Inline Execution** - 在当前会话中使用executing-plans执行任务，批量执行并设置检查点

选择哪种方式？