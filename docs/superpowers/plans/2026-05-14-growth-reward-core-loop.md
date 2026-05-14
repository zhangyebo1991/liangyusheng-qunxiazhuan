# 成长与奖励闭环 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立第一版完整 RPG 成长闭环：战斗和任务奖励给每个队友经验，队友按成长表升级，胜利奖励可见，队伍 UI 同步反映结果。

**Architecture:** `PartyState` 保存成员成长状态，`GrowthSystem` 统一处理经验和升级规则，`ActorStatsSystem` 继续作为最终战斗属性单一来源。战斗和任务只调用成长/奖励 API，并把结构化奖励结果传给 UI，不在局部重复计算成长。

**Tech Stack:** Godot 4.6、GDScript、JSON 数据表、现有自定义 `tests/run_tests.gd` 测试入口。

---

## 文件结构

- 创建 `scripts/systems/growth_system.gd`：处理经验、升级、成长加成和奖励结果。
- 创建 `tests/test_growth_system.gd`：覆盖成长系统直接行为。
- 修改 `scripts/domain/party_state.gd`：序列化并规范化每个成员的 `level`、`exp`、`total_exp`、`hp`、`mp`。
- 修改 `scripts/systems/actor_stats_system.gd`：把等级成长纳入最终属性。
- 修改 `scripts/systems/effect_system.gd`：新增 `add_party_exp` 效果。
- 修改 `scripts/core/game_state.gd`：处理战斗 `victory_rewards`，保存最近奖励结果，并在成长后同步主角/成员状态。
- 修改 `scripts/domain/tactical_battle_state.gd`：战斗结果包含 `victory_rewards` 和参战玩家成员。
- 修改 `scripts/systems/tactical_combat_system.gd`：从战斗上下文复制 `victory_rewards` 到战斗状态。
- 修改 `scripts/scenes/battle_screen.gd`：返回地图前显示轻量胜利奖励面板。
- 修改 `scripts/scenes/party_panel.gd`：显示等级和下一级经验进度。
- 修改 `data/actors.json`：给可玩角色添加成长表。
- 修改 `data/maps.json`：给山道强人战斗添加固定 `victory_rewards`。
- 修改 `data/quests.json`：给现有任务完成效果添加 `add_party_exp`。
- 修改 `tests/run_tests.gd`：注册新增测试。
- 修改现有 party state、actor stats、effect system、tactical party battle、battle screen、party panel 测试。

每个验证步骤都使用这个命令：

```powershell
$godotExe = "D:/Projects/games/liangyusheng-qunxiazhuan/.tools/godot/4.6-stable/windows-x86_64/Godot_v4.6-stable_win64_console.exe"
& $godotExe --headless --path "." -s "res://tests/run_tests.gd"
Write-Output "GodotExit:$LASTEXITCODE"
```

Task 2 注册新增测试套件后，通过输出应包含 `测试通过：64 个测试套件`。前面的红灯步骤应因对应缺失行为失败。

---

### Task 1: Extend PartyState Member Progression

**Files:**
- Modify: `scripts/domain/party_state.gd`
- Modify: `tests/test_party_state.gd`

- [ ] **Step 1: Write the failing test**

Add this block to `tests/test_party_state.gd` after the existing member status assertions:

```gdscript
party.set_member_status("hero_yun", {"hp": 90, "mp": 7, "level": 3, "exp": 12, "total_exp": 92})
var hero_status = party.get_member_status("hero_yun")
assertions.assert_eq(hero_status.get("level", 0), 3, "应保存成员等级")
assertions.assert_eq(hero_status.get("exp", -1), 12, "应保存当前等级经验")
assertions.assert_eq(hero_status.get("total_exp", -1), 92, "应保存累计经验")
```

Add these assertions after the existing serialization restore assertions:

```gdscript
assertions.assert_eq(restored.get_member_status("hero_yun").get("level", 0), 3, "成员等级应可序列化恢复")
assertions.assert_eq(restored.get_member_status("hero_yun").get("exp", -1), 12, "成员当前等级经验应可序列化恢复")
assertions.assert_eq(restored.get_member_status("hero_yun").get("total_exp", -1), 92, "成员累计经验应可序列化恢复")
```

Update the old-save assertion block to expect default progression fields:

```gdscript
old_save.add_member("hero_yun")
old_save.set_member_status("hero_yun", {"hp": 50, "mp": 4})
var old_status = old_save.get_member_status("hero_yun")
assertions.assert_eq(old_status.get("level", 0), 1, "旧成员状态缺等级时应默认为 1 级")
assertions.assert_eq(old_status.get("exp", -1), 0, "旧成员状态缺经验时应默认为 0")
assertions.assert_eq(old_status.get("total_exp", -1), 0, "旧成员状态缺累计经验时应默认为 0")
```

- [ ] **Step 2: Run test to verify it fails**

Run the full test command.

Expected: FAIL because `PartyState.set_member_status()` currently drops `level`, `exp`, and `total_exp`.

- [ ] **Step 3: Implement status normalization**

Replace `set_member_status()` in `scripts/domain/party_state.gd` with:

```gdscript
func set_member_status(actor_id: String, status: Dictionary) -> void:
	if actor_id.is_empty() or not has_member(actor_id):
		return
	var current = get_member_status(actor_id)
	var next_status: Dictionary = {
		"level": max(1, int(current.get("level", 1))),
		"exp": max(0, int(current.get("exp", 0))),
		"total_exp": max(0, int(current.get("total_exp", 0))),
	}
	if status.has("level"):
		next_status["level"] = max(1, int(status.get("level", 1)))
	if status.has("exp"):
		next_status["exp"] = max(0, int(status.get("exp", 0)))
	if status.has("total_exp"):
		next_status["total_exp"] = max(0, int(status.get("total_exp", 0)))
	if status.has("hp"):
		next_status["hp"] = max(0, int(status.get("hp", 0)))
	elif current.has("hp"):
		next_status["hp"] = max(0, int(current.get("hp", 0)))
	if status.has("mp"):
		next_status["mp"] = max(0, int(status.get("mp", 0)))
	elif current.has("mp"):
		next_status["mp"] = max(0, int(current.get("mp", 0)))
	member_status[actor_id] = next_status
```

Replace `_read_member_status()` status construction with:

```gdscript
		var status: Dictionary = {
			"level": max(1, int(raw_status.get("level", 1))),
			"exp": max(0, int(raw_status.get("exp", 0))),
			"total_exp": max(0, int(raw_status.get("total_exp", 0))),
		}
		if raw_status.has("hp"):
			status["hp"] = max(0, int(raw_status.get("hp", 0)))
		if raw_status.has("mp"):
			status["mp"] = max(0, int(raw_status.get("mp", 0)))
```

- [ ] **Step 4: Run tests to verify pass**

Run the full test command.

Expected: all existing suites pass.

- [ ] **Step 5: Commit**

```powershell
git add scripts/domain/party_state.gd tests/test_party_state.gd
git commit -m "feat: 扩展队友成长状态" --no-gpg-sign
```

---

### Task 2: Add GrowthSystem and Actor Growth Data

**Files:**
- Create: `scripts/systems/growth_system.gd`
- Create: `tests/test_growth_system.gd`
- Modify: `tests/run_tests.gd`
- Modify: `data/actors.json`

- [ ] **Step 1: Write the failing test**

Create `tests/test_growth_system.gd`:

```gdscript
extends RefCounted

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GrowthSystemScript = preload("res://scripts/systems/growth_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.set_member_status("hero_yun", {"hp": 1, "mp": 1, "level": 1, "exp": 0, "total_exp": 0})

	var growth = GrowthSystemScript.new()
	var result = growth.add_exp(party, "hero_yun", 35, repository)
	assertions.assert_true(bool(result.get("success", false)), "加经验应成功")
	assertions.assert_eq(result.get("actor_id", ""), "hero_yun", "结果应记录角色编号")
	assertions.assert_eq(int(result.get("old_level", 0)), 1, "应记录旧等级")
	assertions.assert_eq(int(result.get("new_level", 0)), 2, "35 经验应升到 2 级")
	assertions.assert_true(bool(result.get("leveled_up", false)), "应标记升级")
	assertions.assert_eq(party.get_member_status("hero_yun").get("level", 0), 2, "成员等级应更新")
	assertions.assert_eq(party.get_member_status("hero_yun").get("total_exp", 0), 35, "累计经验应更新")
	assertions.assert_eq(party.get_member_status("hero_yun").get("exp", -1), 5, "当前等级经验应为超过 2 级门槛后的剩余值")
	assertions.assert_eq(party.get_member_status("hero_yun").get("hp", 0), int(result.get("max_hp", 0)), "升级后气血应回满")
	assertions.assert_eq(party.get_member_status("hero_yun").get("mp", 0), int(result.get("max_mp", 0)), "升级后内力应回满")

	var bonus = growth.get_growth_bonus(repository.get_actor("hero_yun"), 2)
	assertions.assert_eq(int(bonus.get("max_hp", 0)), 8, "2 级应获得 1 次气血成长")
	assertions.assert_eq(int(bonus.get("attack", 0)), 1, "2 级应获得 1 次攻击成长")

	var party_result = growth.add_party_exp(party, 10, repository)
	assertions.assert_true(bool(party_result.get("success", false)), "全队经验应成功")
	assertions.assert_eq(party_result.get("members", []).size(), 1, "全队经验应返回成员结果")

	var invalid = growth.add_exp(party, "missing_actor", 10, repository)
	assertions.assert_false(bool(invalid.get("success", true)), "不存在角色不应获得经验")

	repository.free()
```

Register the suite in `tests/run_tests.gd`:

```gdscript
const TestGrowthSystemScript = preload("res://tests/test_growth_system.gd")
```

Add `TestGrowthSystemScript.new(),` after `TestActorStatsSystemScript.new(),`.

- [ ] **Step 2: Run test to verify it fails**

Run the full test command.

Expected: FAIL because `res://scripts/systems/growth_system.gd` does not exist.

- [ ] **Step 3: Add growth data**

Add this `growth` object to `hero_yun` and `qingshanke` in `data/actors.json`:

```json
"growth": {
  "exp_curve": [0, 30, 80, 150, 240],
  "per_level": {
    "max_hp": 8,
    "max_mp": 2,
    "attack": 1,
    "defense": 1
  }
}
```

For `qingshanke`, use stronger HP and defense growth:

```json
"growth": {
  "exp_curve": [0, 30, 80, 150, 240],
  "per_level": {
    "max_hp": 10,
    "max_mp": 2,
    "attack": 1,
    "defense": 2
  }
}
```

- [ ] **Step 4: Implement GrowthSystem**

Create `scripts/systems/growth_system.gd`:

```gdscript
extends RefCounted

func add_exp(party, actor_id: String, amount: int, repository) -> Dictionary:
	if party == null or repository == null or actor_id.is_empty() or amount <= 0:
		return {"success": false, "message": "经验奖励参数无效。"}
	if not party.has_member(actor_id):
		return {"success": false, "message": "队伍中不存在成员：%s" % actor_id}
	var actor = repository.get_actor(actor_id) if repository.has_method("get_actor") else {}
	if typeof(actor) != TYPE_DICTIONARY or actor.is_empty():
		return {"success": false, "message": "角色不存在：%s" % actor_id}

	var status = party.get_member_status(actor_id)
	var old_level = max(1, int(status.get("level", 1)))
	var old_total = max(0, int(status.get("total_exp", 0)))
	var total_exp = old_total + amount
	var new_level = _level_for_total_exp(actor, total_exp)
	var exp_in_level = _exp_in_level(actor, new_level, total_exp)
	var leveled_up = new_level > old_level
	var max_stats = _max_stats_for_level(actor, new_level)
	var hp = int(status.get("hp", max_stats.get("max_hp", 1)))
	var mp = int(status.get("mp", max_stats.get("max_mp", 0)))
	if leveled_up:
		hp = int(max_stats.get("max_hp", hp))
		mp = int(max_stats.get("max_mp", mp))
	else:
		hp = clamp(hp, 0, int(max_stats.get("max_hp", hp)))
		mp = clamp(mp, 0, int(max_stats.get("max_mp", mp)))

	party.set_member_status(actor_id, {
		"level": new_level,
		"exp": exp_in_level,
		"total_exp": total_exp,
		"hp": hp,
		"mp": mp,
	})
	return {
		"success": true,
		"actor_id": actor_id,
		"exp_gained": amount,
		"old_level": old_level,
		"new_level": new_level,
		"leveled_up": leveled_up,
		"exp": exp_in_level,
		"total_exp": total_exp,
		"max_hp": int(max_stats.get("max_hp", 1)),
		"max_mp": int(max_stats.get("max_mp", 0)),
	}

func add_party_exp(party, amount: int, repository) -> Dictionary:
	if party == null or amount <= 0:
		return {"success": false, "members": [], "message": "全队经验参数无效。"}
	var members: Array = []
	for actor_id in party.members:
		var member_result = add_exp(party, str(actor_id), amount, repository)
		if bool(member_result.get("success", false)):
			members.append(member_result)
	return {"success": not members.is_empty(), "members": members}

func get_growth_bonus(actor: Dictionary, level: int) -> Dictionary:
	var result: Dictionary = {}
	var growth = actor.get("growth", {})
	if typeof(growth) != TYPE_DICTIONARY:
		return result
	var per_level = growth.get("per_level", {})
	if typeof(per_level) != TYPE_DICTIONARY:
		return result
	var steps = max(0, level - 1)
	for key in per_level.keys():
		result[str(key)] = int(per_level[key]) * steps
	return result

func next_level_required_exp(actor: Dictionary, level: int) -> int:
	var curve = _exp_curve(actor)
	var next_index = clamp(level, 0, curve.size() - 1)
	return int(curve[next_index]) if level < curve.size() else -1

func _level_for_total_exp(actor: Dictionary, total_exp: int) -> int:
	var curve = _exp_curve(actor)
	var level := 1
	for index in range(curve.size()):
		if total_exp >= int(curve[index]):
			level = index + 1
	return level

func _exp_in_level(actor: Dictionary, level: int, total_exp: int) -> int:
	var curve = _exp_curve(actor)
	var current_index = clamp(level - 1, 0, curve.size() - 1)
	return max(0, total_exp - int(curve[current_index]))

func _max_stats_for_level(actor: Dictionary, level: int) -> Dictionary:
	var bonus = get_growth_bonus(actor, level)
	return {
		"max_hp": max(1, int(actor.get("max_hp", actor.get("hp", 1))) + int(bonus.get("max_hp", 0))),
		"max_mp": max(0, int(actor.get("max_mp", 0)) + int(bonus.get("max_mp", 0))),
	}

func _exp_curve(actor: Dictionary) -> Array:
	var growth = actor.get("growth", {})
	if typeof(growth) != TYPE_DICTIONARY:
		return [0]
	var curve = growth.get("exp_curve", [0])
	if typeof(curve) != TYPE_ARRAY or curve.is_empty():
		return [0]
	return curve
```

- [ ] **Step 5: Run tests to verify pass**

Run the full test command.

Expected: `测试通过：64 个测试套件` and `GodotExit:0`.

- [ ] **Step 6: Commit**

```powershell
git add data/actors.json scripts/systems/growth_system.gd tests/test_growth_system.gd tests/run_tests.gd
git commit -m "feat: 增加角色经验成长系统" --no-gpg-sign
```

---

### Task 3: Apply Growth to Final Actor Stats

**Files:**
- Modify: `scripts/systems/actor_stats_system.gd`
- Modify: `tests/test_actor_stats_system.gd`

- [ ] **Step 1: Write the failing test**

In `tests/test_actor_stats_system.gd`, add a case after the existing equipment-stat case:

```gdscript
party.set_member_status("hero_yun", {"hp": 999, "mp": 999, "level": 3, "exp": 0, "total_exp": 80})
var growth_stats = stats_system.build_stats(party, "hero_yun", repository)
assertions.assert_eq(int(growth_stats.get("level", 0)), 3, "属性合成应返回角色等级")
assertions.assert_eq(int(growth_stats.get("max_hp", 0)), 136, "3 级主角应获得两次气血成长")
assertions.assert_eq(int(growth_stats.get("max_mp", 0)), 24, "3 级主角应获得两次内力成长")
assertions.assert_eq(int(growth_stats.get("attack", 0)), 12, "3 级主角应获得两次攻击成长")
assertions.assert_eq(int(growth_stats.get("defense", 0)), 5, "3 级主角应获得两次防御成长")
assertions.assert_eq(int(growth_stats.get("hp", 0)), 136, "当前气血应 clamp 到成长后的上限")
assertions.assert_eq(int(growth_stats.get("mp", 0)), 24, "当前内力应 clamp 到成长后的上限")
```

Use the actual base values from `hero_yun`; if the file differs, calculate expected values as base plus two growth steps.

- [ ] **Step 2: Run test to verify it fails**

Run the full test command.

Expected: FAIL because `ActorStatsSystem` does not include growth bonuses or `level`.

- [ ] **Step 3: Implement growth bonus in ActorStatsSystem**

Add preload and instance:

```gdscript
const GrowthSystemScript = preload("res://scripts/systems/growth_system.gd")

var growth_system = GrowthSystemScript.new()
```

Inside `build_stats()`, after reading `status`, add:

```gdscript
	var level = max(1, int(status.get("level", 1)))
	var growth_bonus = growth_system.get_growth_bonus(actor, level)
```

Replace stat calculations with growth-aware versions:

```gdscript
	var max_hp = max(1, int(actor.get("max_hp", actor.get("hp", 1))) + int(growth_bonus.get("max_hp", 0)) + int(bonus.get("max_hp", 0)))
	var max_mp = max(0, int(actor.get("max_mp", 0)) + int(growth_bonus.get("max_mp", 0)) + int(bonus.get("max_mp", 0)))
```

In the returned dictionary, add:

```gdscript
		"level": level,
		"exp": max(0, int(status.get("exp", 0))),
		"total_exp": max(0, int(status.get("total_exp", 0))),
		"next_level_exp": growth_system.next_level_required_exp(actor, level),
```

Update attack and defense return values:

```gdscript
		"attack": max(1, int(actor.get("attack", 1)) + int(growth_bonus.get("attack", 0)) + int(bonus.get("attack", 0))),
		"defense": max(0, int(actor.get("defense", 0)) + int(growth_bonus.get("defense", 0)) + int(bonus.get("defense", 0))),
```

Also apply growth to `move_range`, `attack_range`, and `charge_speed` with the same pattern, defaulting missing growth keys to 0.

- [ ] **Step 4: Run tests to verify pass**

Run the full test command.

Expected: all suites pass.

- [ ] **Step 5: Commit**

```powershell
git add scripts/systems/actor_stats_system.gd tests/test_actor_stats_system.gd
git commit -m "feat: 将等级成长纳入属性合成" --no-gpg-sign
```

---

### Task 4: Add Quest Experience Effect

**Files:**
- Modify: `scripts/systems/effect_system.gd`
- Modify: `data/quests.json`
- Modify: `tests/test_effect_system.gd`
- Modify: `tests/test_effect_data.gd`

- [ ] **Step 1: Write the failing tests**

In `tests/test_effect_system.gd`, add this after the direct `add_party_member` test:

```gdscript
var party_exp_result = effect_system.apply_effects(state, [
	{"type": "add_party_exp", "amount": 35}
])
var exp_members: Array = party_exp_result.get("experience", [])
assertions.assert_true(bool(party_exp_result.get("success", false)), "add_party_exp 应给全队经验")
assertions.assert_true(not exp_members.is_empty(), "经验结果应记录成员")
assertions.assert_eq(state.party.get_member_status("hero_yun").get("level", 0), 2, "主角应因任务经验升到 2 级")
assertions.assert_eq(state.party.get_member_status("hero_yun").get("hp", 0), 128, "升级后主角气血应回满到成长后上限")
```

In `tests/test_effect_data.gd`, assert an existing quest includes task experience:

```gdscript
assertions.assert_eq(_count_effect(mountain_effects, "add_party_exp"), 1, "山道试剑完成效果应发放全队经验")
```

- [ ] **Step 2: Run test to verify it fails**

Run the full test command.

Expected: FAIL because `add_party_exp` is unknown and the quest data lacks the effect.

- [ ] **Step 3: Implement add_party_exp**

In `scripts/systems/effect_system.gd`, add preload:

```gdscript
const GrowthSystemScript = preload("res://scripts/systems/growth_system.gd")
```

Add `"add_party_exp"` to the match:

```gdscript
		"add_party_exp":
			_apply_add_party_exp(result, game_state, effect)
```

Add `experience` to `_empty_result()`:

```gdscript
		"experience": [],
```

Add merge handling in `_merge_result()`:

```gdscript
	_append_array(target, source, "experience")
```

Add this method:

```gdscript
func _apply_add_party_exp(result: Dictionary, game_state, effect: Dictionary) -> void:
	var amount = int(effect.get("amount", 0))
	if amount <= 0:
		_add_error(result, "经验效果数量必须大于 0。")
		return
	if game_state.party == null:
		_add_error(result, "队伍状态缺失。")
		return
	var repository = _get_repository(game_state)
	if repository == null:
		_add_error(result, "数据仓库缺失。")
		return
	var growth = GrowthSystemScript.new()
	var growth_result = growth.add_party_exp(game_state.party, amount, repository)
	if not bool(growth_result.get("success", false)):
		_add_error(result, "全队经验发放失败。")
		return
	var experience: Array = result["experience"]
	for member_result in growth_result.get("members", []):
		experience.append(member_result)
	_mark_applied(result, "全队获得经验：%d" % amount)
```

Add `_get_repository()` helper:

```gdscript
func _get_repository(game_state):
	if game_state != null and game_state.is_inside_tree() and game_state.has_node("/root/DataRepository"):
		return game_state.get_node("/root/DataRepository")
	var DataRepositoryScript = load("res://scripts/systems/data_repository.gd")
	var repository = DataRepositoryScript.new()
	repository.load_all()
	return repository
```

- [ ] **Step 4: Add quest data**

In `data/quests.json`, add to `quest_mountain_trial.complete_effects`:

```json
{"type": "add_party_exp", "amount": 35}
```

Add to `quest_deliver_letter.complete_effects`:

```json
{"type": "add_party_exp", "amount": 15}
```

- [ ] **Step 5: Run tests to verify pass**

Run the full test command.

Expected: all suites pass.

- [ ] **Step 6: Commit**

```powershell
git add scripts/systems/effect_system.gd data/quests.json tests/test_effect_system.gd tests/test_effect_data.gd
git commit -m "feat: 增加任务全队经验效果" --no-gpg-sign
```

---

### Task 5: Add Battle Victory Rewards

**Files:**
- Modify: `scripts/domain/tactical_battle_state.gd`
- Modify: `scripts/systems/tactical_combat_system.gd`
- Modify: `scripts/core/game_state.gd`
- Modify: `data/maps.json`
- Modify: `tests/test_tactical_party_battle.gd`
- Modify: `tests/test_save_party_equipment.gd`

- [ ] **Step 1: Write failing battle reward test**

In `tests/test_tactical_party_battle.gd`, add a test after the existing party battle result test:

```gdscript
var reward_state = GameStateScript.new()
reward_state.start_new_game()
reward_state.party.add_member("qingshanke")
reward_state.initialize_party_member_status("qingshanke")
var reward_context = {
	"source_map_id": "mountain_pass",
	"source_object_id": "enemy_bandit_gate",
	"quest_id": "quest_mountain_trial",
	"player_start_cells": [{"q": 1, "r": 2}, {"q": 1, "r": 3}],
	"victory_rewards": {
		"exp": 35,
		"coins": 12,
		"items": [{"item_id": "herb_small", "amount": 1}]
	},
	"units": [
		{"unit_id": "bandit", "actor_id": "bandit_01", "team": "enemy", "start_cell": {"q": 3, "r": 2}}
	]
}
var reward_battle = combat.create_battle(reward_state, reward_context, repository)
reward_battle.finish(true)
var reward_result = reward_battle.to_result_dictionary()
reward_state.apply_battle_result(reward_result)
assertions.assert_eq(reward_state.party.get_member_status("hero_yun").get("level", 0), 2, "战斗经验应让主角升级")
assertions.assert_eq(reward_state.party.get_member_status("qingshanke").get("level", 0), 2, "战斗经验应让参战队友升级")
assertions.assert_eq(reward_state.party.coins, GameStateScript.STARTING_COINS + 12, "战斗胜利应发放铜钱")
assertions.assert_eq(reward_state.party.get_item_count("herb_small"), 2, "战斗胜利应发放物品")
assertions.assert_true(not reward_state.last_reward_result.is_empty(), "GameState 应保存最近奖励结果供 UI 展示")
```

Add a failure case:

```gdscript
var fail_state = GameStateScript.new()
fail_state.start_new_game()
var fail_battle = combat.create_battle(fail_state, reward_context, repository)
fail_battle.finish(false)
fail_state.apply_battle_result(fail_battle.to_result_dictionary())
assertions.assert_eq(fail_state.party.get_member_status("hero_yun").get("level", 0), 1, "战斗失败不应发经验")
assertions.assert_eq(fail_state.party.coins, GameStateScript.STARTING_COINS, "战斗失败不应发铜钱")
```

- [ ] **Step 2: Run test to verify it fails**

Run the full test command.

Expected: FAIL because battle state does not carry `victory_rewards` and `GameState` has no `last_reward_result`.

- [ ] **Step 3: Extend TacticalBattleState**

Add fields:

```gdscript
var victory_rewards: Dictionary = {}
```

In `to_result_dictionary()`, add:

```gdscript
		"victory_rewards": victory_rewards.duplicate(true),
		"participating_party_members": _participating_party_members(),
```

Add helper:

```gdscript
func _participating_party_members() -> Array:
	var result: Array = []
	for unit in units:
		if unit.team == TEAM_PLAYER and not unit.actor_id.is_empty():
			result.append(unit.actor_id)
	return result
```

Include `victory_rewards` in `to_dictionary()`.

- [ ] **Step 4: Copy rewards from battle context**

In `scripts/systems/tactical_combat_system.gd`, inside `create_battle()`, after `quest_id` assignment:

```gdscript
	var rewards = context.get("victory_rewards", {})
	if typeof(rewards) == TYPE_DICTIONARY:
		battle.victory_rewards = rewards.duplicate(true)
```

- [ ] **Step 5: Process rewards in GameState**

Add preload:

```gdscript
const GrowthSystemScript = preload("res://scripts/systems/growth_system.gd")
```

Add field:

```gdscript
var last_reward_result: Dictionary = {}
```

Reset it in `start_new_game()` and `from_dictionary()`:

```gdscript
	last_reward_result = {}
```

In `apply_battle_result()`, inside victory branch after existing effects:

```gdscript
		last_reward_result = _apply_victory_rewards(result)
```

In the non-victory branch before failure handling:

```gdscript
		last_reward_result = {}
```

Add helper:

```gdscript
func _apply_victory_rewards(result: Dictionary) -> Dictionary:
	var rewards = result.get("victory_rewards", {})
	if typeof(rewards) != TYPE_DICTIONARY or rewards.is_empty():
		return {}
	var summary: Dictionary = {"experience": [], "coins": 0, "items": []}
	var repository = _get_data_repository_for_rewards()
	var exp_amount = int(rewards.get("exp", 0))
	if exp_amount > 0 and repository != null:
		var growth = GrowthSystemScript.new()
		var participants = result.get("participating_party_members", [])
		if typeof(participants) == TYPE_ARRAY:
			for actor_id in participants:
				var growth_result = growth.add_exp(party, str(actor_id), exp_amount, repository)
				if bool(growth_result.get("success", false)):
					summary["experience"].append(growth_result)
	var coins = int(rewards.get("coins", 0))
	if coins > 0:
		party.add_coins(coins)
		summary["coins"] = coins
	var items = rewards.get("items", [])
	if typeof(items) == TYPE_ARRAY:
		for item in items:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var item_id = str(item.get("item_id", ""))
			var amount = max(1, int(item.get("amount", 1)))
			if item_id.is_empty():
				continue
			party.add_item(item_id, amount)
			summary["items"].append({"item_id": item_id, "amount": amount})
	return summary

func _get_data_repository_for_rewards():
	if is_inside_tree() and has_node("/root/DataRepository"):
		return get_node("/root/DataRepository")
	var repository = DataRepositoryScript.new()
	repository.load_all()
	return repository
```

- [ ] **Step 6: Add battle data**

In `data/maps.json`, add to `enemy_bandit_gate`:

```json
"victory_rewards": {
  "exp": 20,
  "coins": 15,
  "items": [
    {"item_id": "herb_small", "amount": 1}
  ]
}
```

- [ ] **Step 7: Run tests to verify pass**

Run the full test command.

Expected: all suites pass.

- [ ] **Step 8: Commit**

```powershell
git add scripts/domain/tactical_battle_state.gd scripts/systems/tactical_combat_system.gd scripts/core/game_state.gd data/maps.json tests/test_tactical_party_battle.gd tests/test_save_party_equipment.gd
git commit -m "feat: 增加战斗胜利成长奖励" --no-gpg-sign
```

---

### Task 6: Add Victory Reward Panel

**Files:**
- Modify: `scripts/scenes/battle_screen.gd`
- Create: `tests/test_battle_screen_reward_panel.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/test_battle_screen_reward_panel.gd`:

```gdscript
extends RefCounted

const BattleScreenScript = preload("res://scripts/scenes/battle_screen.gd")

func run(assertions) -> void:
	var screen = BattleScreenScript.new()
	assertions.assert_true(screen.has_method("_show_reward_panel"), "BattleScreen 应提供胜利奖励面板方法")
	if not screen.has_method("_show_reward_panel"):
		screen.free()
		return
	screen._ready()
	screen._show_reward_panel({
		"experience": [
			{"actor_id": "hero_yun", "exp_gained": 20, "old_level": 1, "new_level": 2, "leveled_up": true}
		],
		"coins": 15,
		"items": [{"item_id": "herb_small", "amount": 1}]
	})
	assertions.assert_true(screen.reward_panel != null, "应创建胜利奖励面板")
	assertions.assert_true(screen.reward_panel.visible, "胜利奖励面板应可见")
	var text = screen.reward_label.text
	assertions.assert_true(text.find("hero_yun +20 经验") >= 0, "面板应显示经验奖励")
	assertions.assert_true(text.find("升至 2 级") >= 0, "面板应显示升级提示")
	assertions.assert_true(text.find("15 文") >= 0, "面板应显示铜钱")
	assertions.assert_true(text.find("herb_small x1") >= 0, "面板应显示物品")
	screen.free()
```

Register the suite in `tests/run_tests.gd`:

```gdscript
const TestBattleScreenRewardPanelScript = preload("res://tests/test_battle_screen_reward_panel.gd")
```

Add it after `TestTacticalBattleScreenScript.new(),`.

- [ ] **Step 2: Run test to verify it fails**

Run the full test command.

Expected: FAIL because reward panel members and `_show_reward_panel()` do not exist.

- [ ] **Step 3: Implement reward panel members**

In `scripts/scenes/battle_screen.gd`, add fields near other UI fields:

```gdscript
var reward_panel: PanelContainer
var reward_label: Label
var reward_return_button: Button
```

Add method:

```gdscript
func _show_reward_panel(reward_result: Dictionary) -> void:
	if reward_panel == null:
		reward_panel = PanelContainer.new()
		reward_panel.name = "RewardPanel"
		reward_panel.position = Vector2(260, 120)
		reward_panel.custom_minimum_size = Vector2(420, 280)
		add_child(reward_panel)
		var box = VBoxContainer.new()
		box.custom_minimum_size = Vector2(400, 260)
		reward_panel.add_child(box)
		var title = Label.new()
		title.text = "胜利奖励"
		box.add_child(title)
		reward_label = Label.new()
		reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reward_label.custom_minimum_size = Vector2(380, 180)
		box.add_child(reward_label)
		reward_return_button = Button.new()
		reward_return_button.text = "返回地图"
		reward_return_button.pressed.connect(_on_reward_return_pressed)
		box.add_child(reward_return_button)
	reward_label.text = _reward_text(reward_result)
	reward_panel.visible = true

func _reward_text(reward_result: Dictionary) -> String:
	var lines: Array[String] = []
	for item in reward_result.get("experience", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var actor_id = str(item.get("actor_id", ""))
		var gained = int(item.get("exp_gained", 0))
		var line = "%s +%d 经验" % [actor_id, gained]
		if bool(item.get("leveled_up", false)):
			line += "，升至 %d 级，气血内力已回满" % int(item.get("new_level", 0))
		lines.append(line)
	var coins = int(reward_result.get("coins", 0))
	if coins > 0:
		lines.append("获得 %d 文" % coins)
	for drop in reward_result.get("items", []):
		if typeof(drop) != TYPE_DICTIONARY:
			continue
		lines.append("获得 %s x%d" % [str(drop.get("item_id", "")), int(drop.get("amount", 1))])
	return "\n".join(lines) if not lines.is_empty() else "没有额外奖励。"

func _on_reward_return_pressed() -> void:
	if reward_panel != null:
		reward_panel.visible = false
	_return_to_map()
```

If the existing map return method has a different name, wire `_on_reward_return_pressed()` to that exact method. If map return currently happens inline when battle finishes, extract that inline block into `_return_to_map()` in this same task.

- [ ] **Step 4: Wire battle completion to panel**

Find the place in `battle_screen.gd` where a finished victory battle applies `GameState.apply_battle_result()` and returns to map. Replace immediate return with:

```gdscript
var reward_result = GameState.last_reward_result if GameState != null else {}
if typeof(reward_result) == TYPE_DICTIONARY and not reward_result.is_empty():
	_show_reward_panel(reward_result)
	return
_return_to_map()
```

Failure flow should continue returning immediately without a reward panel.

- [ ] **Step 5: Run tests to verify pass**

Run the full test command.

Expected: all suites pass.

- [ ] **Step 6: Commit**

```powershell
git add scripts/scenes/battle_screen.gd tests/test_battle_screen_reward_panel.gd tests/run_tests.gd
git commit -m "feat: 增加战斗胜利奖励面板" --no-gpg-sign
```

---

### Task 7: Show Growth in PartyPanel

**Files:**
- Modify: `scripts/scenes/party_panel.gd`
- Modify: `tests/test_party_panel.gd`

- [ ] **Step 1: Write the failing test**

In `tests/test_party_panel.gd`, set the hero status to include progression:

```gdscript
party.set_member_status("hero_yun", {"hp": 100, "mp": 12, "level": 2, "exp": 5, "total_exp": 35})
```

Add assertions after `panel.refresh()`:

```gdscript
assertions.assert_true(panel._detail_label.text.find("等级 2") >= 0, "队伍面板应显示等级")
assertions.assert_true(panel._detail_label.text.find("经验 5/50") >= 0, "队伍面板应显示到下一级经验进度")
```

Expected next-level progress is `5/50` because level 2 starts at total 30 and level 3 requires total 80.

- [ ] **Step 2: Run test to verify it fails**

Run the full test command.

Expected: FAIL because PartyPanel does not display level or experience.

- [ ] **Step 3: Update PartyPanel detail text**

In `_refresh_detail()`, read stats:

```gdscript
	var level = int(stats.get("level", 1))
	var exp = int(stats.get("exp", 0))
	var next_total = int(stats.get("next_level_exp", -1))
	var total_exp = int(stats.get("total_exp", 0))
	var exp_line = "经验 已满"
	if next_total >= 0:
		var current_level_start = total_exp - exp
		exp_line = "经验 %d/%d" % [exp, max(0, next_total - current_level_start)]
```

Change the detail format to include level and exp line:

```gdscript
	_detail_label.text = "%s\n等级 %d  %s\n气血 %d/%d  内力 %d/%d\n攻击 %d  防御 %d\n武器：%s\n衣甲：%s\n饰品：%s" % [
		str(stats.get("display_name", selected_actor_id)),
		level,
		exp_line,
		int(stats.get("hp", 0)),
		int(stats.get("max_hp", 0)),
		int(stats.get("mp", 0)),
		int(stats.get("max_mp", 0)),
		int(stats.get("attack", 0)),
		int(stats.get("defense", 0)),
		_equipped_name("weapon"),
		_equipped_name("armor"),
		_equipped_name("accessory"),
	]
```

- [ ] **Step 4: Run tests to verify pass**

Run the full test command.

Expected: all suites pass.

- [ ] **Step 5: Commit**

```powershell
git add scripts/scenes/party_panel.gd tests/test_party_panel.gd
git commit -m "feat: 队伍面板显示成长进度" --no-gpg-sign
```

---

### Task 8: Final Verification and Documentation Sync

**Files:**
- Modify: `docs/godot-project-structure.md` if it has a systems summary that should mention growth rewards.
- Inspect: all changed files.

- [ ] **Step 1: Run full tests**

Run the full test command.

Expected: `测试通过：65 个测试套件` if Task 6 added a battle reward panel suite in addition to Task 2 growth suite. Expected `GodotExit:0`.

- [ ] **Step 2: Run language service checks**

Use VS Code diagnostics on these files:

- `scripts/domain/party_state.gd`
- `scripts/systems/growth_system.gd`
- `scripts/systems/actor_stats_system.gd`
- `scripts/systems/effect_system.gd`
- `scripts/core/game_state.gd`
- `scripts/domain/tactical_battle_state.gd`
- `scripts/systems/tactical_combat_system.gd`
- `scripts/scenes/battle_screen.gd`
- `scripts/scenes/party_panel.gd`
- all new or modified tests

Expected: no diagnostics.

- [ ] **Step 3: Run quality gates**

```powershell
node C:/Users/74543/.claude/skills/ccg/run_skill.js verify-change --mode unstaged
node C:/Users/74543/.claude/skills/ccg/run_skill.js verify-quality scripts tests
```

Expected: no Critical or High findings.

- [ ] **Step 4: Check Godot UID files**

```powershell
git status --short --untracked-files=all -- "*.gd.uid"
```

If Godot generated `growth_system.gd.uid`, `test_growth_system.gd.uid`, or `test_battle_screen_reward_panel.gd.uid`, include them in the final commit.

- [ ] **Step 5: Final status**

```powershell
git status --short --branch
```

Expected: clean working tree on the implementation branch.

- [ ] **Step 6: Commit final metadata or docs**

If only UID files changed:

```powershell
git add scripts/systems/growth_system.gd.uid tests/test_growth_system.gd.uid tests/test_battle_screen_reward_panel.gd.uid
git commit -m "chore: 纳入成长系统脚本 uid" --no-gpg-sign
```

If docs changed:

```powershell
git add docs/godot-project-structure.md
git commit -m "docs: 更新成长奖励系统说明" --no-gpg-sign
```

---

## Spec 覆盖自审

- 每个成员独立等级和经验：Task 1、Task 2。
- 战斗和任务经验奖励：Task 4、Task 5。
- 按成长表升级并回满 HP/MP：Task 2、Task 3。
- 模板、成长、装备共同合成最终属性：Task 3。
- 胜利结算面板展示经验、升级、铜钱和物品掉落：Task 6。
- `PartyPanel` 显示等级和经验：Task 7。
- 旧成员状态存档兼容：Task 1。
- 固定战斗奖励而非随机掉落：Task 5。
- 全量验证、诊断、质量关卡和 UID 处理：Task 8。

开始实施前，应先切到专用功能分支或 worktree。