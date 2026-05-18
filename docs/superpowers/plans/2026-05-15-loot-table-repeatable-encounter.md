# 战利品掉落与可重复遭遇 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立战斗概率掉落、低概率装备来源和山道可重复挑战遭遇，让长期养成与经济循环有稳定资源入口。

**Architecture:** 新增 `LootSystem` 作为随机掉落的唯一规则入口，`GameState` 继续负责战斗胜利后发放奖励和写入 `last_reward_result`。地图对象通过 `repeatable` 标记可重复遭遇，战斗结果把该标记带回 `GameState`，从而保留现有一次性战斗回流逻辑。

**Tech Stack:** Godot 4.6、GDScript、JSON 内容数据、现有 `tests/run_tests.gd` 无头测试入口。

---

## 范围检查

实现 [docs/superpowers/specs/2026-05-15-loot-table-repeatable-encounter-design.md](../specs/2026-05-15-loot-table-repeatable-encounter-design.md)。

本计划只做嵌入式 `victory_rewards.loot_table`、可重复山道遭遇和中文物品显示兜底。不新增 `data/loot_tables.json`，不做稀有度、保底、装备出售、装备自动穿戴或秘籍学习。

## 文件结构

- Create `scripts/systems/loot_system.gd`：解析 `loot_table`，按可控随机源生成铜钱和物品掉落结果，不修改游戏状态。
- Create `tests/test_loot_system.gd`：覆盖掉落概率、roll 次数、数量范围、无效数量、空表和多结果聚合。
- Modify `tests/run_tests.gd`：注册 `test_loot_system.gd`。
- Modify `scripts/core/game_state.gd`：调用 `LootSystem`，合并固定奖励和随机掉落，校验随机物品存在，支持 `repeatable` 抑制默认对象解决。
- Modify `tests/test_tactical_party_battle.gd`：覆盖胜利掉落发放、缺失物品过滤、失败不掉落、repeatable 不写入 `resolved_objects`。
- Modify `scripts/domain/tactical_battle_state.gd`：保存并输出 `repeatable`。
- Modify `tests/test_tactical_battle_state.gd`：覆盖 `repeatable` 序列化和战斗结果。
- Modify `scripts/systems/tactical_combat_system.gd`：从战斗上下文复制 `repeatable` 到战斗状态。
- Modify `scripts/scenes/mountain_pass_screen.gd`：允许无 `quest_id` 的战斗入口启动，避免可重复山贼被山道试剑任务门槛误挡。
- Modify `data/actors.json`：新增 `roaming_bandit` 敌人。
- Modify `data/maps.json`：新增山道“流窜山贼”可重复战斗触发点。
- Modify `tests/test_map_data.gd`：覆盖新敌人、新地图对象、`repeatable`、解锁条件和掉落表配置。
- Modify `scripts/scenes/battle_screen.gd`：缺失物品资料时显示“未知物品”，不显示 `item_id`。
- Modify `scripts/scenes/map_screen_base.gd`：奖励消息缺失物品资料时显示“未知物品”，不显示 `item_id`。
- Modify `tests/test_battle_screen_reward_panel.gd`：覆盖奖励面板不暴露 `item_id`。
- Modify `README.md` and `docs/godot-project-structure.md`：记录新切片规则。

## 验证命令

Use the local Godot binary:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

If the local binary is missing, use PATH Godot:

```powershell
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . --quit
```

---

### Task 1: LootSystem 纯逻辑

**Files:**
- Create: `scripts/systems/loot_system.gd`
- Create: `tests/test_loot_system.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write the failing LootSystem test**

Create `tests/test_loot_system.gd`:

```gdscript
extends RefCounted

const LootSystemScript = preload("res://scripts/systems/loot_system.gd")

class FixedRng:
	extends RefCounted

	var float_values: Array = []
	var int_values: Array = []

	func _init(next_float_values: Array = [], next_int_values: Array = []) -> void:
		float_values = next_float_values.duplicate()
		int_values = next_int_values.duplicate()

	func randf() -> float:
		if float_values.is_empty():
			return 0.0
		return float(float_values.pop_front())

	func randi_range(min_value: int, max_value: int) -> int:
		if int_values.is_empty():
			return min_value
		return clampi(int(int_values.pop_front()), min_value, max_value)

func run(assertions) -> void:
	var system = LootSystemScript.new()

	var empty = system.roll_loot({}, FixedRng.new())
	assertions.assert_false(bool(empty.get("rolled", true)), "空掉落表不应掷骰")
	assertions.assert_eq(int(empty.get("coins", -1)), 0, "空掉落表不应产生铜钱")
	assertions.assert_eq(empty.get("items", []).size(), 0, "空掉落表不应产生物品")

	var no_rolls = system.roll_loot({
		"rolls": 0,
		"entries": [{"type": "item", "item_id": "herb_small", "chance": 1.0, "amount": 1}]
	}, FixedRng.new())
	assertions.assert_false(bool(no_rolls.get("rolled", true)), "rolls 为 0 时不应掷骰")

	var chance_edges = system.roll_loot({
		"rolls": 1,
		"entries": [
			{"type": "item", "item_id": "never_drop", "chance": 0.0, "amount": 1},
			{"type": "item", "item_id": "always_drop", "chance": 1.0, "amount": 2}
		]
	}, FixedRng.new())
	assertions.assert_true(bool(chance_edges.get("rolled", false)), "有效 rolls 应标记已掷骰")
	assertions.assert_eq(chance_edges.get("items", []).size(), 1, "chance 0 应跳过，chance 1 应掉落")
	assertions.assert_eq(chance_edges.get("items", [])[0].get("item_id", ""), "always_drop", "必掉物品编号应保留")
	assertions.assert_eq(chance_edges.get("items", [])[0].get("amount", 0), 2, "必掉物品数量应保留")

	var random_result = system.roll_loot({
		"rolls": 2,
		"entries": [
			{"type": "item", "item_id": "herb_focus", "chance": 0.50, "amount": 1},
			{"type": "coins", "chance": 0.50, "amount_min": 3, "amount_max": 8}
		]
	}, FixedRng.new([0.40, 0.20, 0.70, 0.10], [6, 4]))
	assertions.assert_eq(random_result.get("items", []).size(), 1, "第一轮物品命中、第二轮物品未命中")
	assertions.assert_eq(random_result.get("items", [])[0].get("item_id", ""), "herb_focus", "命中物品应进入结果")
	assertions.assert_eq(int(random_result.get("coins", 0)), 10, "两次铜钱命中应聚合数量")

	var normalized_amount = system.roll_loot({
		"rolls": 1,
		"entries": [
			{"type": "item", "item_id": "cloth_armor", "chance": 1.0, "amount": 0},
			{"type": "coins", "chance": 1.0, "amount_min": 9, "amount_max": 3}
		]
	}, FixedRng.new([], [5]))
	assertions.assert_eq(normalized_amount.get("items", [])[0].get("amount", 0), 1, "物品数量小于等于 0 应归一为 1")
	assertions.assert_eq(int(normalized_amount.get("coins", 0)), 9, "数量区间反转时应使用 amount_min")

	var invalid_entries = system.roll_loot({
		"rolls": 1,
		"entries": [
			{"type": "item", "item_id": "", "chance": 1.0, "amount": 1},
			{"type": "coins", "chance": 1.0, "amount": -5},
			{"type": "unknown", "chance": 1.0}
		]
	}, FixedRng.new())
	assertions.assert_eq(int(invalid_entries.get("coins", 0)), 1, "无效铜钱数量应归一为 1")
	assertions.assert_eq(invalid_entries.get("items", []).size(), 0, "空 item_id 不应进入物品结果")
	assertions.assert_true(invalid_entries.get("errors", []).size() >= 2, "无效 entry 应记录错误")
```

- [ ] **Step 2: Register the failing test suite**

In `tests/run_tests.gd`, add this preload after `TestGrowthSystemScript`:

```gdscript
const TestLootSystemScript = preload("res://tests/test_loot_system.gd")
```

In the `suites` array, add this entry after `TestGrowthSystemScript.new()`:

```gdscript
		TestLootSystemScript.new(),
```

- [ ] **Step 3: Run tests and verify failure**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `res://scripts/systems/loot_system.gd` does not exist.

- [ ] **Step 4: Implement LootSystem**

Create `scripts/systems/loot_system.gd`:

```gdscript
extends RefCounted

func roll_loot(loot_table: Variant, rng = null) -> Dictionary:
	var result: Dictionary = {
		"rolled": false,
		"coins": 0,
		"items": [],
		"errors": [],
	}
	if typeof(loot_table) != TYPE_DICTIONARY:
		return result

	var rolls = max(0, int(loot_table.get("rolls", 0)))
	var entries = loot_table.get("entries", [])
	if rolls <= 0 or typeof(entries) != TYPE_ARRAY or entries.is_empty():
		return result

	var roller = rng
	if roller == null:
		roller = RandomNumberGenerator.new()
		roller.randomize()

	result["rolled"] = true
	for _roll_index in range(rolls):
		for raw_entry in entries:
			if typeof(raw_entry) != TYPE_DICTIONARY:
				_add_error(result, "掉落条目格式错误。")
				continue
			_apply_entry(result, raw_entry, roller)
	return result

func _apply_entry(result: Dictionary, entry: Dictionary, rng) -> void:
	var chance = float(entry.get("chance", 0.0))
	if chance <= 0.0:
		return
	if chance < 1.0 and _randf(rng) > chance:
		return

	var entry_type = str(entry.get("type", ""))
	match entry_type:
		"item":
			_apply_item_entry(result, entry)
		"coins":
			_apply_coin_entry(result, entry, rng)
		_:
			_add_error(result, "未知掉落类型：%s。" % entry_type)

func _apply_item_entry(result: Dictionary, entry: Dictionary) -> void:
	var item_id = str(entry.get("item_id", ""))
	if item_id.is_empty():
		_add_error(result, "物品掉落缺少编号。")
		return
	var items: Array = result["items"]
	items.append({
		"item_id": item_id,
		"amount": _entry_amount(entry, null),
	})

func _apply_coin_entry(result: Dictionary, entry: Dictionary, rng) -> void:
	result["coins"] = int(result.get("coins", 0)) + _entry_amount(entry, rng)

func _entry_amount(entry: Dictionary, rng) -> int:
	if entry.has("amount"):
		return max(1, int(entry.get("amount", 1)))
	var amount_min = max(1, int(entry.get("amount_min", 1)))
	var amount_max = max(1, int(entry.get("amount_max", amount_min)))
	if amount_max < amount_min:
		amount_max = amount_min
	if amount_min == amount_max:
		return amount_min
	return _randi_range(rng, amount_min, amount_max)

func _randf(rng) -> float:
	if rng != null and rng.has_method("randf"):
		return float(rng.randf())
	return randf()

func _randi_range(rng, min_value: int, max_value: int) -> int:
	if rng != null and rng.has_method("randi_range"):
		return int(rng.randi_range(min_value, max_value))
	return randi_range(min_value, max_value)

func _add_error(result: Dictionary, message: String) -> void:
	var errors: Array = result["errors"]
	errors.append(message)
```

- [ ] **Step 5: Run tests and verify pass**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS or only failures unrelated to `test_loot_system.gd`.

- [ ] **Step 6: Commit Task 1**

```powershell
git add -- scripts/systems/loot_system.gd tests/test_loot_system.gd tests/run_tests.gd
git commit -m "feat: add loot rolling system"
```

---

### Task 2: Integrate LootSystem Into Victory Rewards

**Files:**
- Modify: `scripts/core/game_state.gd`
- Modify: `tests/test_tactical_party_battle.gd`

- [ ] **Step 1: Add failing GameState reward tests**

In `tests/test_tactical_party_battle.gd`, after the existing assertions for `reward_state.last_reward_result`, add:

```gdscript
	var loot_state = GameStateScript.new()
	loot_state.start_new_game()
	var loot_battle = system.create_battle(loot_state, _loot_context(), repository)
	loot_battle.finish(true)
	loot_state.apply_battle_result(loot_battle.to_result_dictionary())
	assertions.assert_eq(loot_state.party.coins, GameStateScript.STARTING_COINS + 13, "固定铜钱和随机铜钱应合并发放")
	assertions.assert_eq(loot_state.party.get_item_count("herb_focus"), 1, "随机消耗品应进入背包")
	assertions.assert_eq(loot_state.party.get_item_count("iron_sword"), 1, "随机装备应进入背包")
	assertions.assert_eq(int(loot_state.last_reward_result.get("coins", 0)), 13, "奖励摘要应记录总铜钱")
	assertions.assert_eq(loot_state.last_reward_result.get("items", []).size(), 2, "奖励摘要应记录随机掉落物品")
	assertions.assert_eq(loot_state.last_reward_result.get("items", [])[0].get("source", ""), "loot", "随机物品来源应标记为 loot")
	assertions.assert_true(bool(loot_state.last_reward_result.get("loot", {}).get("rolled", false)), "奖励摘要应记录本场已掷掉落表")

	var missing_loot_state = GameStateScript.new()
	missing_loot_state.start_new_game()
	var missing_loot_battle = system.create_battle(missing_loot_state, _missing_loot_context(), repository)
	missing_loot_battle.finish(true)
	missing_loot_state.apply_battle_result(missing_loot_battle.to_result_dictionary())
	assertions.assert_eq(missing_loot_state.party.get_item_count("missing_item"), 0, "缺失物品资料不应进入背包")
	assertions.assert_true(missing_loot_state.last_reward_result.get("loot", {}).get("errors", []).size() >= 1, "缺失物品资料应记录错误")

	var failed_loot_state = GameStateScript.new()
	failed_loot_state.start_new_game()
	var failed_loot_battle = system.create_battle(failed_loot_state, _loot_context(), repository)
	failed_loot_battle.finish(false)
	failed_loot_state.apply_battle_result(failed_loot_battle.to_result_dictionary())
	assertions.assert_eq(failed_loot_state.party.coins, GameStateScript.STARTING_COINS, "战斗失败不应掷掉落表")
	assertions.assert_eq(failed_loot_state.party.get_item_count("herb_focus"), 0, "战斗失败不应发随机物品")
```

Before the final `state.free()` block in the same file, add:

```gdscript
	loot_state.free()
	missing_loot_state.free()
	failed_loot_state.free()
```

Add these helper functions near `_party_context_with_deploy()`:

```gdscript
func _loot_context() -> Dictionary:
	return {
		"source_map_id": "mountain_pass",
		"source_object_id": "enemy_roaming_bandit",
		"battlefield": {"width": 8, "height": 6},
		"player_deploy": {"max_members": 1, "start_cells": [{"q": 1, "r": 2}]},
		"victory_rewards": {
			"exp": 0,
			"coins": 5,
			"loot_table": {
				"rolls": 1,
				"entries": [
					{"type": "coins", "chance": 1.0, "amount": 8},
					{"type": "item", "item_id": "herb_focus", "chance": 1.0, "amount": 1},
					{"type": "item", "item_id": "iron_sword", "chance": 1.0, "amount": 1}
				]
			}
		},
		"units": [
			{"unit_id": "roaming_bandit", "actor_id": "bandit_lackey_01", "team": "enemy", "start_cell": {"q": 5, "r": 2}, "move_range": 3, "attack_range": 1, "max_mp": 0}
		]
	}

func _missing_loot_context() -> Dictionary:
	var context = _loot_context()
	context["victory_rewards"] = {
		"exp": 0,
		"coins": 0,
		"loot_table": {
			"rolls": 1,
			"entries": [
				{"type": "item", "item_id": "missing_item", "chance": 1.0, "amount": 1}
			]
		}
	}
	return context
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `_apply_victory_rewards()` ignores `loot_table`.

- [ ] **Step 3: Preload LootSystem**

In `scripts/core/game_state.gd`, add this preload after `GrowthSystemScript`:

```gdscript
const LootSystemScript = preload("res://scripts/systems/loot_system.gd")
```

- [ ] **Step 4: Replace `_apply_victory_rewards()`**

Replace the full `_apply_victory_rewards(result: Dictionary) -> Dictionary` function in `scripts/core/game_state.gd` with:

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

	var fixed_coins = int(rewards.get("coins", 0))
	if fixed_coins > 0:
		party.add_coins(fixed_coins)
		summary["coins"] = int(summary.get("coins", 0)) + fixed_coins

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
			summary["items"].append({"item_id": item_id, "id": item_id, "amount": amount, "source": "fixed"})

	var loot_table = rewards.get("loot_table", {})
	if typeof(loot_table) == TYPE_DICTIONARY and not loot_table.is_empty():
		var loot_result = LootSystemScript.new().roll_loot(loot_table)
		_apply_loot_result(summary, loot_result, repository)

	_apply_growth_results_to_hero(summary["experience"])
	return summary
```

- [ ] **Step 5: Add `_apply_loot_result()` helper**

In `scripts/core/game_state.gd`, add this helper directly below `_apply_victory_rewards()`:

```gdscript
func _apply_loot_result(summary: Dictionary, loot_result: Dictionary, repository) -> void:
	var loot_summary = {
		"rolled": bool(loot_result.get("rolled", false)),
		"coins": max(0, int(loot_result.get("coins", 0))),
		"items": [],
		"errors": [],
	}
	var raw_errors = loot_result.get("errors", [])
	if typeof(raw_errors) == TYPE_ARRAY:
		for error in raw_errors:
			loot_summary["errors"].append(str(error))

	var loot_coins = int(loot_summary.get("coins", 0))
	if loot_coins > 0:
		party.add_coins(loot_coins)
		summary["coins"] = int(summary.get("coins", 0)) + loot_coins

	var loot_items = loot_result.get("items", [])
	if typeof(loot_items) == TYPE_ARRAY:
		for item in loot_items:
			if typeof(item) != TYPE_DICTIONARY:
				loot_summary["errors"].append("掉落物品格式错误。")
				continue
			var item_id = str(item.get("item_id", ""))
			var amount = max(1, int(item.get("amount", 1)))
			if item_id.is_empty():
				loot_summary["errors"].append("掉落物品编号缺失。")
				continue
			if repository == null or not repository.has_method("get_item") or repository.get_item(item_id).is_empty():
				loot_summary["errors"].append("掉落物品资料缺失：%s。" % item_id)
				continue
			party.add_item(item_id, amount)
			var record = {"item_id": item_id, "id": item_id, "amount": amount}
			loot_summary["items"].append(record)
			summary["items"].append({"item_id": item_id, "id": item_id, "amount": amount, "source": "loot"})
	summary["loot"] = loot_summary
```

- [ ] **Step 6: Run tests and verify pass**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS or only failures unrelated to reward application.

- [ ] **Step 7: Commit Task 2**

```powershell
git add -- scripts/core/game_state.gd tests/test_tactical_party_battle.gd
git commit -m "feat: apply random battle loot rewards"
```

---

### Task 3: Repeatable Encounter Result Flow

**Files:**
- Modify: `scripts/domain/tactical_battle_state.gd`
- Modify: `tests/test_tactical_battle_state.gd`
- Modify: `scripts/systems/tactical_combat_system.gd`
- Modify: `scripts/core/game_state.gd`
- Modify: `scripts/scenes/mountain_pass_screen.gd`
- Modify: `tests/test_tactical_party_battle.gd`

- [ ] **Step 1: Add failing TacticalBattleState repeatable assertions**

In `tests/test_tactical_battle_state.gd`, after `battle.proficiency_reward = 1`, add:

```gdscript
	battle.repeatable = true
```

After `assertions.assert_eq(serialized.get("log", []).size(), 1, "战棋战斗序列化应保存日志")`, add:

```gdscript
	assertions.assert_true(bool(serialized.get("repeatable", false)), "战棋战斗序列化应保存 repeatable")
	var restored = TacticalBattleStateScript.new()
	restored.from_dictionary(serialized)
	assertions.assert_true(restored.repeatable, "战棋战斗反序列化应恢复 repeatable")
```

After the existing payload assertions, add:

```gdscript
	assertions.assert_true(bool(payload.get("repeatable", false)), "战棋结果应带回 repeatable")
```

- [ ] **Step 2: Add failing repeatable GameState assertions**

In `tests/test_tactical_party_battle.gd`, after the failed loot assertions from Task 2, add:

```gdscript
	var repeatable_state = GameStateScript.new()
	repeatable_state.start_new_game()
	var repeatable_battle = system.create_battle(repeatable_state, _repeatable_context(), repository)
	repeatable_battle.finish(true)
	repeatable_state.apply_battle_result(repeatable_battle.to_result_dictionary())
	assertions.assert_false(repeatable_state.is_map_object_resolved("enemy_roaming_bandit"), "repeatable 战斗胜利后不应标记来源对象已解决")

	var one_shot_state = GameStateScript.new()
	one_shot_state.start_new_game()
	var one_shot_battle = system.create_battle(one_shot_state, _party_context(), repository)
	one_shot_battle.finish(true)
	one_shot_state.apply_battle_result(one_shot_battle.to_result_dictionary())
	assertions.assert_true(one_shot_state.is_map_object_resolved("enemy_bandit_gate"), "非 repeatable 战斗胜利后仍应标记来源对象已解决")
```

Before the final `state.free()` block, add:

```gdscript
	repeatable_state.free()
	one_shot_state.free()
```

Add this helper near `_loot_context()`:

```gdscript
func _repeatable_context() -> Dictionary:
	var context = _loot_context()
	context["repeatable"] = true
	context["source_object_id"] = "enemy_roaming_bandit"
	return context
```

- [ ] **Step 3: Run tests and verify failure**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `TacticalBattleState` has no `repeatable` field and `GameState._battle_victory_effects()` always resolves `source_object_id`.

- [ ] **Step 4: Extend TacticalBattleState**

In `scripts/domain/tactical_battle_state.gd`, add this field after `var victory_rewards: Dictionary = {}`:

```gdscript
var repeatable := false
```

In `to_result_dictionary()`, add this entry after `"victory_rewards": victory_rewards.duplicate(true),`:

```gdscript
		"repeatable": repeatable,
```

In `to_dictionary()`, add this entry after `"victory_rewards": victory_rewards.duplicate(true),`:

```gdscript
		"repeatable": repeatable,
```

In `from_dictionary(data: Dictionary)`, add this line after `victory_rewards = data.get("victory_rewards", {})`:

```gdscript
	repeatable = bool(data.get("repeatable", false))
```

- [ ] **Step 5: Copy repeatable from tactical battle context**

In `scripts/systems/tactical_combat_system.gd`, inside `create_battle()`, add this line after `battle.quest_id = str(context.get("quest_id", ""))`:

```gdscript
	battle.repeatable = bool(context.get("repeatable", false))
```

- [ ] **Step 6: Suppress default resolve_map_object for repeatable results**

In `scripts/core/game_state.gd`, replace the object resolve block in `_battle_victory_effects(result: Dictionary) -> Array`:

```gdscript
	var object_id = str(result.get("source_object_id", ""))
	if not object_id.is_empty():
		effects.append({"type": "resolve_map_object", "object_id": object_id})
```

with:

```gdscript
	var object_id = str(result.get("source_object_id", ""))
	if not object_id.is_empty() and not bool(result.get("repeatable", false)):
		effects.append({"type": "resolve_map_object", "object_id": object_id})
```

- [ ] **Step 7: Allow questless mountain battle triggers**

In `scripts/scenes/mountain_pass_screen.gd`, replace this block in `_start_battle(record: Dictionary) -> void`:

```gdscript
	var quest_id = str(record.get("quest_id", ""))
	if GameState.quest_system.get_status(quest_id) == "not_started":
		hud.show_message("先与青衫客交谈。")
		return
```

with:

```gdscript
	var quest_id = str(record.get("quest_id", ""))
	if not quest_id.is_empty() and GameState.quest_system.get_status(quest_id) == "not_started":
		hud.show_message("先与青衫客交谈。")
		return
```

- [ ] **Step 8: Run tests and verify pass**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS or only failures unrelated to repeatable battle result flow.

- [ ] **Step 9: Commit Task 3**

```powershell
git add -- scripts/domain/tactical_battle_state.gd tests/test_tactical_battle_state.gd scripts/systems/tactical_combat_system.gd scripts/core/game_state.gd scripts/scenes/mountain_pass_screen.gd tests/test_tactical_party_battle.gd
git commit -m "feat: support repeatable battle encounters"
```

---

### Task 4: Add Roaming Bandit Data Slice

**Files:**
- Modify: `data/actors.json`
- Modify: `data/maps.json`
- Modify: `tests/test_map_data.gd`

- [ ] **Step 1: Add failing data assertions**

In `tests/test_map_data.gd`, after the existing `bandit_gate` assertions and before `var training_dummy = _find_object(mountain, "npc_training_dummy")`, add:

```gdscript
	var roaming_bandit = _find_object(mountain, "enemy_roaming_bandit")
	assertions.assert_eq(roaming_bandit.get("type", ""), "battle_trigger", "山道应配置流窜山贼战斗入口")
	assertions.assert_eq(roaming_bandit.get("name", ""), "流窜山贼", "流窜山贼入口应使用中文名称")
	assertions.assert_true(bool(roaming_bandit.get("repeatable", false)), "流窜山贼应是可重复遭遇")
	assertions.assert_eq(roaming_bandit.get("required_quest_id", ""), "quest_mountain_trial", "流窜山贼应在山道试剑后开放")
	assertions.assert_eq(roaming_bandit.get("required_quest_status", ""), "completed", "流窜山贼应要求山道试剑完成")
	var roaming_rewards = roaming_bandit.get("victory_rewards", {})
	assertions.assert_eq(int(roaming_rewards.get("exp", 0)), 12, "流窜山贼应提供少量经验")
	assertions.assert_eq(int(roaming_rewards.get("coins", 0)), 8, "流窜山贼应提供少量固定铜钱")
	var loot_table = roaming_rewards.get("loot_table", {})
	assertions.assert_eq(int(loot_table.get("rolls", 0)), 2, "流窜山贼应配置 2 次掉落掷骰")
	var loot_entries = loot_table.get("entries", [])
	assertions.assert_eq(loot_entries.size(), 4, "流窜山贼应配置丹药、装备和铜钱掉落")
	assertions.assert_eq(repository.get_actor("roaming_bandit").get("name", ""), "流窜山贼", "应读取流窜山贼角色")
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `enemy_roaming_bandit` and `roaming_bandit` do not exist.

- [ ] **Step 3: Add roaming bandit actor**

In `data/actors.json`, insert this object after `bandit_lackey_01`:

```json
  {
    "id": "roaming_bandit",
    "name": "流窜山贼",
    "level": 2,
    "hp": 45,
    "max_hp": 45,
    "attack": 11,
    "defense": 3,
    "move_range": 3,
    "attack_range": 1,
    "charge_speed": 230,
    "martial_arts": ["rough_fist"],
    "sprite_tile_id": "tile_bandit_lackey_hd"
  },
```

- [ ] **Step 4: Add mountain repeatable battle object**

In `data/maps.json`, insert this object in `mountain_pass.objects` after `npc_training_dummy`:

```json
      {
        "id": "enemy_roaming_bandit",
        "type": "battle_trigger",
        "name": "流窜山贼",
        "actor_id": "roaming_bandit",
        "position": {"x": 620, "y": 520},
        "radius": 56,
        "required_quest_id": "quest_mountain_trial",
        "required_quest_status": "completed",
        "battle_mode": "tactical",
        "repeatable": true,
        "encounter_id": "mountain_roaming_bandit",
        "battlefield": {"width": 16, "height": 9},
        "player_deploy": {
          "max_members": 2,
          "start_cells": [
            {"q": 5, "r": 5},
            {"q": 5, "r": 6}
          ]
        },
        "victory_rewards": {
          "exp": 12,
          "coins": 8,
          "items": [],
          "loot_table": {
            "rolls": 2,
            "entries": [
              {"type": "item", "item_id": "herb_focus", "chance": 0.35, "amount": 1},
              {"type": "item", "item_id": "iron_sword", "chance": 0.10, "amount": 1},
              {"type": "item", "item_id": "cloth_armor", "chance": 0.08, "amount": 1},
              {"type": "coins", "chance": 0.50, "amount_min": 3, "amount_max": 8}
            ]
          }
        },
        "time_mode": "pause_on_action",
        "units": [
          {
            "unit_id": "roaming_bandit",
            "actor_id": "roaming_bandit",
            "team": "enemy",
            "start_cell": {"q": 9, "r": 5},
            "move_range": 3,
            "attack_range": 1,
            "charge_speed": 230
          },
          {
            "unit_id": "roaming_bandit_lackey",
            "actor_id": "bandit_lackey_01",
            "team": "enemy",
            "start_cell": {"q": 10, "r": 5},
            "move_range": 3,
            "attack_range": 1,
            "charge_speed": 240
          }
        ]
      },
```

- [ ] **Step 5: Run tests and verify pass**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS or only failures unrelated to map data.

- [ ] **Step 6: Commit Task 4**

```powershell
git add -- data/actors.json data/maps.json tests/test_map_data.gd
git commit -m "data: add repeatable roaming bandit encounter"
```

---

### Task 5: Enforce Chinese Item Display Fallbacks

**Files:**
- Modify: `scripts/scenes/battle_screen.gd`
- Modify: `scripts/scenes/map_screen_base.gd`
- Modify: `tests/test_battle_screen_reward_panel.gd`

- [ ] **Step 1: Add failing reward panel assertions**

In `tests/test_battle_screen_reward_panel.gd`, after the existing `"小还丹 x1"` assertion, add:

```gdscript
	var missing_text = screen._reward_text({
		"items": [{"item_id": "missing_item", "amount": 2}]
	})
	assertions.assert_true(missing_text.find("未知物品 x2") >= 0, "缺失物品资料时奖励面板应显示中文兜底")
	assertions.assert_eq(missing_text.find("missing_item"), -1, "奖励面板不应暴露 item_id")
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `BattleScreen._item_display_name()` returns `item_id` when item data is missing.

- [ ] **Step 3: Fix BattleScreen item fallback**

In `scripts/scenes/battle_screen.gd`, replace `_item_display_name(item_id: String) -> String` with:

```gdscript
func _item_display_name(item_id: String) -> String:
	if item_id.is_empty():
		return "未知物品"
	if DataRepository != null and DataRepository.has_method("get_item"):
		var item = DataRepository.get_item(item_id)
		if typeof(item) == TYPE_DICTIONARY and not item.is_empty():
			return str(item.get("name", "未知物品"))
	return "未知物品"
```

- [ ] **Step 4: Fix map reward message fallback**

In `scripts/scenes/map_screen_base.gd`, inside `_build_effect_message(result: Dictionary, fallback_message: String) -> String`, replace:

```gdscript
		var name = str(item_data.get("name", item_id))
```

with:

```gdscript
		var name = str(item_data.get("name", "未知物品"))
```

- [ ] **Step 5: Run tests and verify pass**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS or only failures unrelated to Chinese item display.

- [ ] **Step 6: Commit Task 5**

```powershell
git add -- scripts/scenes/battle_screen.gd scripts/scenes/map_screen_base.gd tests/test_battle_screen_reward_panel.gd
git commit -m "fix: hide item ids from player reward text"
```

---

### Task 6: Documentation And Full Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/godot-project-structure.md`

- [ ] **Step 1: Update README current goals**

In `README.md`, under `## 当前目标`, add this bullet after the existing battle UI bullet:

```markdown
- 战利品掉落与可重复遭遇切片：战斗胜利支持固定奖励和嵌入式概率掉落表，山道新增可重复“流窜山贼”挑战，用于验证铜钱、丹药和基础装备掉落；所有玩家可见物品名必须显示中文。
```

- [ ] **Step 2: Update project structure doc**

In `docs/godot-project-structure.md`, add this section after `## 战棋武学与内力基础切片`:

```markdown
## 战利品掉落与可重复遭遇切片

战利品掉落切片在 `victory_rewards` 中增加嵌入式 `loot_table`。`LootSystem` 只负责按概率生成结构化掉落结果，不直接修改背包、铜钱或 UI。`GameState` 在战斗胜利时继续统一发放固定奖励和随机掉落，并把结果写入 `last_reward_result` 供奖励面板展示。

可重复战斗对象使用 `repeatable = true`。这类战斗胜利后不写入 `MapState.resolved_objects`，返回地图后仍可再次挑战；未声明该字段的战斗保持一次性逻辑。奖励面板、背包、商店和地图奖励消息必须通过物品资料显示中文名，不能把 `item_id` 直接展示给玩家。
```

- [ ] **Step 3: Run full test suite**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS with output like:

```text
测试通过：69 个测试套件
```

- [ ] **Step 4: Run headless project load**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
```

Expected: command exits with code `0`.

- [ ] **Step 5: Check changed files**

Run:

```powershell
git status --short
```

Expected: only files from this implementation are modified or newly created:

```text
 M README.md
 M data/actors.json
 M data/maps.json
 M docs/godot-project-structure.md
 M scripts/core/game_state.gd
 M scripts/domain/tactical_battle_state.gd
 M scripts/scenes/battle_screen.gd
 M scripts/scenes/map_screen_base.gd
 M scripts/scenes/mountain_pass_screen.gd
 M scripts/systems/tactical_combat_system.gd
 M tests/run_tests.gd
 M tests/test_battle_screen_reward_panel.gd
 M tests/test_map_data.gd
 M tests/test_tactical_battle_state.gd
 M tests/test_tactical_party_battle.gd
?? scripts/systems/loot_system.gd
?? tests/test_loot_system.gd
```

The current branch already has unrelated local edits before this plan starts. Do not stage or revert unrelated files.

- [ ] **Step 6: Commit Task 6**

```powershell
git add -- README.md docs/godot-project-structure.md
git commit -m "docs: document loot table encounter slice"
```

---

## Manual Acceptance

- [ ] Start a new game and complete `山道试剑`.
- [ ] Return to `山道` and confirm `流窜山贼` appears near the training dummy.
- [ ] Win the `流窜山贼` battle and confirm the reward panel uses Chinese item names such as `凝神丹 x1`, `铁剑 x1`, or `布衣 x1`.
- [ ] Confirm the reward panel never shows `herb_focus`, `iron_sword`, or `cloth_armor`.
- [ ] Return to the map and confirm `流窜山贼` is still present.
- [ ] Lose or retreat from the repeatable battle and confirm no random loot is awarded.
- [ ] Win the original `山道强人` battle and confirm it still disappears after victory.

## Final Implementation Check

- [ ] `LootSystem` owns random loot rolling and is directly tested.
- [ ] `GameState` owns reward application and validates random item data before adding inventory.
- [ ] `repeatable = true` suppresses only the default `resolve_map_object` effect.
- [ ] Existing non-repeatable battle behavior is preserved.
- [ ] Player-facing item display uses Chinese names or `未知物品`.
- [ ] `item_id` remains internal and is not displayed to players.
- [ ] Full tests pass.
