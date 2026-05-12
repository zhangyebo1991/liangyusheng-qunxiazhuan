# 客栈休整与内力闭环切片实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Godot 4.6 项目中加入「客栈休息 + 凝神丹 + 长期内力 + 死亡回流」最小经营闭环，让玩家在战斗内外都能消耗与恢复内力。

**Architecture:** 在现有「领域状态 / 系统规则 / 场景表现 / 核心回流」分层上扩展。`hero_cur_mp` 和 `last_inn_id` 进入 `GameState` 与存档；`EffectSystem` 与 `ConditionSystem` 各加 1 个新 type；`InventorySystem.use_item` 扩展支持 `restore_mp`；战棋 MP 改造为「BattleScreen 持 working copy，结算时统一回写 GameState」；`apply_battle_result` 失败分支按 `last_inn_id` 决定原地复活或切场回客栈。

**Tech Stack:** Godot 4.6 / GDScript / 自制 SceneTree-based 测试框架（不是 GUT）/ JSON 数据文件 / 无外部依赖。

**关键工程契约（所有 Task 共享）：**
- 所有数据 .json / .tres 改动后 commit 前必须 `godot --headless --path . --quit` 刷新一次（依据项目 godot.md 沉淀）。
- SaveSlot 新字段一律提供合理默认 → **不升 SAVE_VERSION**（依据项目 v0.11 沉淀）。
- 测试运行命令：`godot --headless --path . -s tests/run_tests.gd`，期望末尾输出 `所有断言通过` 且无 `push_error` 红字。
- 新测试文件**必须**在 `tests/run_tests.gd` 顶部 `preload` 并加入 `suites` 数组，否则不会被执行（这是项目易踩坑点）。
- Godot 可执行路径：项目根 `.tools/godot/4.6-stable/windows-x86_64/Godot_v4.6-stable_win64_console.exe`。Step 命令统一用 PowerShell 变量 `$godot` 引用：
  ```powershell
  $godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
  ```
- 每个 commit 信息使用项目惯例：`feat:` / `fix:` / `test:` / `docs:` 前缀 + 中文短描述。

**Spec 与本 Plan 的偏差说明：**
- Spec 第 3 节写「物品使用统一通过 `EffectSystem.apply_effects(item.effects)` 路径」。**实际现状**：`InventorySystem.use_item` 直接调 `game_state.restore_hero_hp`，未经 `EffectSystem`。本 Plan 采用对称扩展（加 `restore_mp` 分支与 `heal_hp` 对位），不引入 EffectSystem 适配层（YAGNI）。EffectSystem 仍新增 `restore_mp` type 给 `rest_at_inn` 与未来对话/任务效果使用。
- Spec 中 dialogue 选项使用 `add_coins amount: -5` 扣钱。**实际现状**：`_apply_add_coins` 拒绝非正数。本 Plan 改为 **`rest_at_inn` 自带 `cost` 字段，内部扣钱**，更内聚。

---

## 文件结构与改动清单

### 新建（11 个文件）

- `tests/test_long_term_mp_save.gd` — 长期内力存档/读档/老存档兼容
- `tests/test_inn_data.gd` — `data_repository.get_inn` / `inns[]` 数据校验
- `tests/test_mp_potion.gd` — 凝神丹背包外使用 + 满 MP 边界
- `tests/test_inn_rest_loop.gd` — 陆掌柜对话休息分支 + EventBus.inn_rested 信号
- `tests/test_death_warp_to_inn.gd` — 失败回流 / 未绑定回退
- `tests/test_hud_mp_display.gd` — HUD 显示 + hero_mp_changed 驱动刷新

### 修改（共 11 个文件）

- `scripts/core/game_state.gd` — Task 1, 7
- `scripts/core/event_bus.gd` — Task 1
- `scripts/systems/effect_system.gd` — Task 2, 5
- `scripts/systems/condition_system.gd` — Task 3
- `scripts/systems/inventory_system.gd` — Task 2
- `scripts/systems/data_repository.gd` — Task 4
- `scripts/systems/tactical_combat_system.gd` — Task 7
- `scripts/scenes/battle_screen.gd` — Task 7
- `scripts/scenes/hud.gd` — Task 8
- `tests/run_tests.gd` — Task 1, 2, 4, 5, 7, 8（每次新增测试都要注册）
- `tests/test_combat_and_save.gd` — Task 1（hero_cur_mp 存档断言扩展）
- `tests/test_condition_system.gd` — Task 3
- `tests/test_data_loader.gd` — Task 2（凝神丹加载断言）

### 数据文件（3 个）

- `data/items.json` — Task 2（追加凝神丹）
- `data/dialogues.json` — Task 5（扩展陆掌柜对话）
- `data/maps.json` — Task 4（foot_village 加 inns[]）, Task 6（药铺商品列表追加）

---

## Task 1: GameState 加 `hero_cur_mp` / `last_inn_id` + 信号

**Files:**
- Modify: `scripts/core/game_state.gd`（加字段、helper、to/from_dictionary、API）
- Modify: `scripts/core/event_bus.gd`（新增 2 个信号）
- Create: `tests/test_long_term_mp_save.gd`
- Modify: `tests/run_tests.gd`（注册新测试）
- Modify: `tests/test_combat_and_save.gd`（追加 hero_cur_mp 断言，可选）

- [ ] **Step 1.1: 写失败测试 `tests/test_long_term_mp_save.gd`**

```gdscript
extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")

func run(assertions) -> void:
	# 新游戏：hero_cur_mp 应等于 hero_max_mp
	var game_state = GameStateScript.new()
	game_state.start_new_game()
	assertions.assert_eq(game_state.hero_cur_mp, game_state.hero_max_mp, "新游戏当前内力应等于最大内力")
	assertions.assert_eq(game_state.last_inn_id, "", "新游戏未绑定客栈")
	assertions.assert_false(game_state.has_bound_inn(), "新游戏 has_bound_inn 应为 false")

	# consume_hero_mp 扣减成功 + clamp 到 0
	var ok = game_state.consume_hero_mp(5)
	assertions.assert_true(ok, "扣 5 内力应成功")
	assertions.assert_eq(game_state.hero_cur_mp, game_state.hero_max_mp - 5, "扣后当前内力应减 5")
	var ok2 = game_state.consume_hero_mp(9999)
	assertions.assert_false(ok2, "内力不足应返回 false")
	assertions.assert_eq(game_state.hero_cur_mp, game_state.hero_max_mp - 5, "失败的扣减不应改变当前内力")

	# restore_hero_mp 恢复并 clamp 到 max
	var restored = game_state.restore_hero_mp(2)
	assertions.assert_eq(restored, 2, "实际恢复量应为 2")
	assertions.assert_eq(game_state.hero_cur_mp, game_state.hero_max_mp - 3, "恢复后当前内力应为 max - 3")
	var restored_overflow = game_state.restore_hero_mp(9999)
	assertions.assert_eq(restored_overflow, 3, "溢出恢复应只补到满")
	assertions.assert_eq(game_state.hero_cur_mp, game_state.hero_max_mp, "应被 clamp 到 max")

	# bind_inn / has_bound_inn
	game_state.bind_inn("foot_village_inn")
	assertions.assert_true(game_state.has_bound_inn(), "绑定后 has_bound_inn 应为 true")
	assertions.assert_eq(game_state.last_inn_id, "foot_village_inn", "last_inn_id 应被设置")

	# 存档/读档
	game_state.consume_hero_mp(7)
	var serialized = game_state.to_dictionary()
	assertions.assert_eq(serialized.get("hero_cur_mp", -1), game_state.hero_max_mp - 7, "to_dictionary 应包含 hero_cur_mp")
	assertions.assert_eq(serialized.get("last_inn_id", ""), "foot_village_inn", "to_dictionary 应包含 last_inn_id")

	var restored_state = GameStateScript.new()
	restored_state.from_dictionary(serialized)
	assertions.assert_eq(restored_state.hero_cur_mp, game_state.hero_max_mp - 7, "读档应恢复 hero_cur_mp")
	assertions.assert_eq(restored_state.last_inn_id, "foot_village_inn", "读档应恢复 last_inn_id")

	# 老存档兼容（无 hero_cur_mp / last_inn_id 字段）
	var old_state = GameStateScript.new()
	old_state.from_dictionary({
		"party": game_state.party.to_dictionary(),
		"quests": game_state.quest_system.to_dictionary(),
		"map_state": game_state.map_state.to_dictionary(),
		"journal_state": game_state.journal_state.to_dictionary(),
		"flags": game_state.flags.duplicate(true),
		"hero_hp": 80,
		"hero_max_hp": 120,
		"hero_max_mp": 20,
		"martial_proficiency": {},
	})
	assertions.assert_eq(old_state.hero_cur_mp, 20, "老存档无 hero_cur_mp 应兜底为 hero_max_mp")
	assertions.assert_eq(old_state.last_inn_id, "", "老存档无 last_inn_id 应兜底为空串")
```

- [ ] **Step 1.2: 在 `tests/run_tests.gd` 注册新测试**

在文件顶部 `const TestEventSystemScript = ...` 附近追加一行：

```gdscript
const TestLongTermMpSaveScript = preload("res://tests/test_long_term_mp_save.gd")
```

在 `suites: Array = [...]` 数组末尾（`TestTurnBasedCombatSystemScript.new(),` 之后或之前都可）追加：

```gdscript
		TestLongTermMpSaveScript.new(),
```

- [ ] **Step 1.3: 跑测试确认失败**

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

期望：测试失败，控制台 `push_error` 红字提示「Invalid get index 'hero_cur_mp'」或类似（因 GameState 还没加字段）。

- [ ] **Step 1.4: 改 `scripts/core/game_state.gd` 加字段**

在 `var hero_max_mp := DEFAULT_HERO_MAX_MP` 一行后追加：

```gdscript
var hero_cur_mp := DEFAULT_HERO_MAX_MP
var last_inn_id: String = ""
```

- [ ] **Step 1.5: 在 `start_new_game()` 中初始化**

找到 `start_new_game()` 中现有 `hero_max_mp = DEFAULT_HERO_MAX_MP` 一行，**紧随其后**追加：

```gdscript
	hero_cur_mp = hero_max_mp
	last_inn_id = ""
```

- [ ] **Step 1.6: 加 helper 方法**

在 `restore_hero_hp` / `is_hero_hp_full` 之后追加（位置无强制要求，与 HP helper 邻近便于维护）：

```gdscript
func restore_hero_mp(amount: int) -> int:
	if amount <= 0:
		return 0
	_normalize_hero_mp()
	if hero_cur_mp >= hero_max_mp:
		return 0
	var before = hero_cur_mp
	hero_cur_mp = min(hero_max_mp, hero_cur_mp + amount)
	var delta = hero_cur_mp - before
	if delta > 0 and is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").hero_mp_changed.emit(hero_cur_mp, hero_max_mp)
	return delta

func consume_hero_mp(amount: int) -> bool:
	if amount <= 0:
		return true
	_normalize_hero_mp()
	if hero_cur_mp < amount:
		return false
	hero_cur_mp -= amount
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").hero_mp_changed.emit(hero_cur_mp, hero_max_mp)
	return true

func set_hero_cur_mp(value: int) -> void:
	_normalize_hero_mp()
	var clamped = clamp(value, 0, hero_max_mp)
	if clamped == hero_cur_mp:
		return
	hero_cur_mp = clamped
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").hero_mp_changed.emit(hero_cur_mp, hero_max_mp)

func is_hero_mp_full() -> bool:
	_normalize_hero_mp()
	return hero_cur_mp >= hero_max_mp

func bind_inn(inn_id: String) -> void:
	if inn_id.is_empty():
		return
	last_inn_id = inn_id

func has_bound_inn() -> bool:
	return not last_inn_id.is_empty()

func _normalize_hero_mp() -> void:
	if hero_max_mp <= 0:
		hero_max_mp = DEFAULT_HERO_MAX_MP
	hero_cur_mp = clamp(hero_cur_mp, 0, hero_max_mp)
```

- [ ] **Step 1.7: 改 `to_dictionary()` 加字段**

在现有 `to_dictionary()` return 字典中、`"hero_max_mp": hero_max_mp,` 一行后追加：

```gdscript
		"hero_cur_mp": hero_cur_mp,
		"last_inn_id": last_inn_id,
```

- [ ] **Step 1.8: 改 `from_dictionary()` 加兼容字段**

在 `from_dictionary` 中找到 `hero_max_mp = int(data.get("hero_max_mp", DEFAULT_HERO_MAX_MP))` 紧后那段，追加：

```gdscript
	hero_cur_mp = int(data.get("hero_cur_mp", hero_max_mp))
	last_inn_id = str(data.get("last_inn_id", ""))
```

并在 `_normalize_hero_hp()` 调用后追加：

```gdscript
	_normalize_hero_mp()
```

- [ ] **Step 1.9: 改 `scripts/core/event_bus.gd` 新增信号**

在文件末尾 `signal map_message(message: String)` 之后追加：

```gdscript
signal hero_mp_changed(cur_mp: int, max_mp: int)
signal inn_rested(inn_id: String)
```

- [ ] **Step 1.10: 跑测试确认通过**

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

期望：所有断言通过，控制台无 `push_error` 红字，并出现新测试套件的输出。

- [ ] **Step 1.11: 提交**

```powershell
git add scripts/core/game_state.gd scripts/core/event_bus.gd tests/test_long_term_mp_save.gd tests/run_tests.gd
git commit -m "feat: 加入主角长期当前内力与客栈绑定字段"
```

---

## Task 2: 凝神丹物品 + InventorySystem 支持 restore_mp

**Files:**
- Modify: `data/items.json`（追加 herb_focus）
- Modify: `scripts/systems/inventory_system.gd`（扩展 `use_item` 支持 restore_mp）
- Modify: `scripts/systems/effect_system.gd`（新增 `restore_mp` type，给 dialogue/event 使用，与未来效果数据一致）
- Create: `tests/test_mp_potion.gd`
- Modify: `tests/run_tests.gd`（注册新测试）
- Modify: `tests/test_data_loader.gd`（追加凝神丹加载断言，可选）

- [ ] **Step 2.1: 写失败测试 `tests/test_mp_potion.gd`**

```gdscript
extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const InventorySystemScript = preload("res://scripts/systems/inventory_system.gd")
const EffectSystemScript = preload("res://scripts/systems/effect_system.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()

	# 凝神丹数据存在
	var item = repository.get_item("herb_focus")
	assertions.assert_false(item.is_empty(), "凝神丹应在 items.json 中存在")
	assertions.assert_eq(str(item.get("name", "")), "凝神丹", "凝神丹名称应正确")
	assertions.assert_eq(int(item.get("value", 0)), 12, "凝神丹售价应为 12 文")
	assertions.assert_eq(int(item.get("effects", {}).get("restore_mp", 0)), 10, "凝神丹应恢复 10 内力")

	# 战斗外使用凝神丹
	var game_state = GameStateScript.new()
	game_state.start_new_game()
	game_state.party.add_item("herb_focus", 2)
	game_state.consume_hero_mp(7)
	var inventory = InventorySystemScript.new()
	inventory.set_repository(repository)
	var result = inventory.use_item(game_state, "herb_focus")
	assertions.assert_true(bool(result.get("success", false)), "战斗外使用凝神丹应成功")
	assertions.assert_eq(int(result.get("recovered_mp", 0)), 7, "应只恢复缺口 7 点")
	assertions.assert_eq(game_state.hero_cur_mp, game_state.hero_max_mp, "使用后内力应满")
	assertions.assert_eq(game_state.party.get_item_count("herb_focus"), 1, "应消耗 1 颗")

	# 满内力时使用应失败且不消耗
	var result_full = inventory.use_item(game_state, "herb_focus")
	assertions.assert_false(bool(result_full.get("success", false)), "满内力使用应失败")
	assertions.assert_eq(game_state.party.get_item_count("herb_focus"), 1, "失败不应消耗物品")

	# EffectSystem 直接执行 restore_mp（给对话/事件用）
	game_state.consume_hero_mp(5)
	var effect_system = EffectSystemScript.new()
	var effect_result = effect_system.apply_effect(game_state, {"type": "restore_mp", "amount": 3})
	assertions.assert_true(bool(effect_result.get("success", false)), "EffectSystem.restore_mp 应成功")
	assertions.assert_eq(game_state.hero_cur_mp, game_state.hero_max_mp - 2, "应实际恢复 3 点")
```

- [ ] **Step 2.2: 在 `tests/run_tests.gd` 注册**

在 const 区追加：

```gdscript
const TestMpPotionScript = preload("res://tests/test_mp_potion.gd")
```

`suites` 数组末尾追加：

```gdscript
		TestMpPotionScript.new(),
```

- [ ] **Step 2.3: 跑测试确认失败**

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

期望：「凝神丹应在 items.json 中存在」断言失败。

- [ ] **Step 2.4: 改 `data/items.json` 追加凝神丹**

整个文件改为：

```json
[
  {
    "id": "herb_small",
    "name": "小还丹",
    "type": "consumable",
    "description": "恢复少量气血。",
    "value": 30,
    "effects": {
      "heal_hp": 30
    }
  },
  {
    "id": "iron_sword",
    "name": "铁剑",
    "type": "weapon",
    "description": "寻常江湖人常用的长剑。",
    "value": 120,
    "effects": {}
  },
  {
    "id": "herb_focus",
    "name": "凝神丹",
    "type": "consumable",
    "description": "服后心神归一，恢复内力。",
    "value": 12,
    "effects": {
      "restore_mp": 10
    }
  }
]
```

- [ ] **Step 2.5: 改 `scripts/systems/inventory_system.gd` 扩展 `use_item`**

在文件常量区追加：

```gdscript
const MESSAGE_FULL_MP := "内力已满。"
```

将 `use_item` 方法中现有的 `var heal_hp = int(effects.get("heal_hp", 0))` 至 return 成功结果之间整段，**替换**为以下新逻辑：

```gdscript
	var heal_hp = int(effects.get("heal_hp", 0))
	var restore_mp = int(effects.get("restore_mp", 0))

	# 校验：必须至少有一种可处理的效果
	if heal_hp <= 0 and restore_mp <= 0:
		return _failure(normalized_item_id, MESSAGE_UNUSABLE, count)

	# heal_hp 路径：完全沿用原逻辑
	if heal_hp > 0:
		if game_state.is_hero_hp_full():
			return _failure(normalized_item_id, MESSAGE_FULL_HP, count)
		if not game_state.party.remove_item(normalized_item_id, 1):
			return _failure(normalized_item_id, MESSAGE_MISSING_ITEM, game_state.party.get_item_count(normalized_item_id))
		var restored = game_state.restore_hero_hp(heal_hp)
		if restored <= 0:
			game_state.party.add_item(normalized_item_id, 1)
			return _failure(normalized_item_id, MESSAGE_FULL_HP, game_state.party.get_item_count(normalized_item_id))
		return {
			"success": true,
			"message": "服下%s，气血恢复。" % str(item_data.get("name", "物品")),
			"item_id": normalized_item_id,
			"remaining": game_state.party.get_item_count(normalized_item_id),
			"recovered_hp": restored,
		}

	# restore_mp 路径：与 heal_hp 对位
	if game_state.is_hero_mp_full():
		return _failure(normalized_item_id, MESSAGE_FULL_MP, count)
	if not game_state.party.remove_item(normalized_item_id, 1):
		return _failure(normalized_item_id, MESSAGE_MISSING_ITEM, game_state.party.get_item_count(normalized_item_id))
	var recovered_mp = game_state.restore_hero_mp(restore_mp)
	if recovered_mp <= 0:
		game_state.party.add_item(normalized_item_id, 1)
		return _failure(normalized_item_id, MESSAGE_FULL_MP, game_state.party.get_item_count(normalized_item_id))
	return {
		"success": true,
		"message": "服下%s，内力恢复。" % str(item_data.get("name", "物品")),
		"item_id": normalized_item_id,
		"remaining": game_state.party.get_item_count(normalized_item_id),
		"recovered_mp": recovered_mp,
	}
```

- [ ] **Step 2.6: 改 `scripts/systems/effect_system.gd` 新增 restore_mp**

在 `apply_effect` 的 `match effect_type:` 块中，`"add_martial_proficiency":` 分支之后、`"add_rumor":` 之前追加：

```gdscript
		"restore_mp":
			_apply_restore_mp(result, game_state, effect)
```

在文件末尾（`_apply_trigger_rumor` 之后、`_get_journal_state` 之前）追加方法实现：

```gdscript
func _apply_restore_mp(result: Dictionary, game_state, effect: Dictionary) -> void:
	var amount = int(effect.get("amount", 0))
	if amount <= 0:
		_add_error(result, "内力恢复数量必须大于 0。")
		return
	if not game_state.has_method("restore_hero_mp"):
		_add_error(result, "游戏状态不支持内力恢复。")
		return
	var restored = game_state.restore_hero_mp(amount)
	_mark_applied(result, "恢复内力：%d" % restored)
```

- [ ] **Step 2.7: 跑测试确认通过**

```powershell
& $godot --headless --path . --quit
& $godot --headless --path . -s tests/run_tests.gd
```

第一条命令刷新 .uid 缓存；期望测试全部通过。

- [ ] **Step 2.8: 提交**

```powershell
git add data/items.json scripts/systems/inventory_system.gd scripts/systems/effect_system.gd tests/test_mp_potion.gd tests/run_tests.gd
git commit -m "feat: 加入凝神丹与内力恢复效果"
```

---

## Task 3: ConditionSystem 加 `coins_at_least`

**Files:**
- Modify: `scripts/systems/condition_system.gd`
- Modify: `tests/test_condition_system.gd`

- [ ] **Step 3.1: 在 `tests/test_condition_system.gd` 末尾追加新断言**

先打开 `tests/test_condition_system.gd` 找到 `func run(assertions) -> void:` 末尾，在 return 前追加：

```gdscript
	# coins_at_least
	var coin_state = GameStateScript.new()
	coin_state.start_new_game()
	var condition_system = ConditionSystemScript.new()
	# 新游戏起始 80 文（来自 STARTING_COINS），> 5 应满足
	var ok = condition_system.is_condition_met(coin_state, {"type": "coins_at_least", "amount": 5})
	assertions.assert_true(bool(ok.get("met", false)), "80 文应满足 >= 5 文条件")
	# 扣到 4 文
	coin_state.party.spend_coins(76)
	assertions.assert_eq(coin_state.party.coins, 4, "扣后应为 4 文")
	var fail = condition_system.is_condition_met(coin_state, {"type": "coins_at_least", "amount": 5})
	assertions.assert_false(bool(fail.get("met", false)), "4 文应不满足 >= 5 文条件")
	# amount 缺失或非正
	var bad = condition_system.is_condition_met(coin_state, {"type": "coins_at_least", "amount": 0})
	assertions.assert_false(bool(bad.get("success", true)), "amount=0 应返回 error")
```

注意：如果 `tests/test_condition_system.gd` 顶部没有 `const GameStateScript`，先在 const 区追加 `const GameStateScript = preload("res://scripts/core/game_state.gd")`。如果 `party.spend_coins` 不存在（实施时确认实际方法名），改为对应的扣钱方法（项目中可能是 `add_coins(-N)` 或 `spend_coins(N)` —— 先 `Select-String "spend_coins\|coins =" scripts/domain/party_state.gd` 查一次）。

- [ ] **Step 3.2: 跑测试确认失败**

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

期望：「80 文应满足 >= 5 文条件」断言失败（coins_at_least 未实现，会进入 ConditionSystem 的「未知条件类型」错误分支）。

- [ ] **Step 3.3: 改 `scripts/systems/condition_system.gd` 添加 dispatch + 检查方法**

在 `match condition_type:` 中 `"map_object_resolved":` 分支后、`"not":` 之前追加：

```gdscript
		"coins_at_least":
			_check_coins_at_least(result, game_state, condition)
```

在 `_check_map_object_resolved` 之后、`_check_not` 之前追加方法：

```gdscript
func _check_coins_at_least(result: Dictionary, game_state, condition: Dictionary) -> void:
	var amount = int(condition.get("amount", 0))
	if amount <= 0:
		_add_error(result, "铜钱条件数量必须大于 0。")
		return
	if game_state.party == null:
		_add_error(result, "队伍状态缺失。")
		return
	if int(game_state.party.coins) < amount:
		_mark_unmet(result, "铜钱不足：需要 %d 文。" % amount)
```

- [ ] **Step 3.4: 跑测试确认通过**

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

- [ ] **Step 3.5: 提交**

```powershell
git add scripts/systems/condition_system.gd tests/test_condition_system.gd
git commit -m "feat: 加入铜钱数量条件 coins_at_least"
```

---

## Task 4: data_repository 加 inn 反查 + maps.json 加 inns[]

**Files:**
- Modify: `data/maps.json`（foot_village 节点追加 `inns[]`）
- Modify: `scripts/systems/data_repository.gd`（新增 `get_inn` / `get_inn_for_map`）
- Create: `tests/test_inn_data.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 4.1: 写失败测试 `tests/test_inn_data.gd`**

```gdscript
extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()

	var inn = repository.get_inn("foot_village_inn")
	assertions.assert_false(inn.is_empty(), "应能查到 foot_village_inn")
	assertions.assert_eq(str(inn.get("map_id", "")), "foot_village", "客栈应在 foot_village 地图")
	var spawn = inn.get("spawn_position", {})
	assertions.assert_eq(int(spawn.get("x", -1)), 760, "spawn x 应等于陆掌柜 x 坐标")
	assertions.assert_eq(int(spawn.get("y", -1)), 320, "spawn y 应等于陆掌柜 y 坐标")

	var inn_by_map = repository.get_inn_for_map("foot_village")
	assertions.assert_false(inn_by_map.is_empty(), "应能通过 map_id 反查客栈")
	assertions.assert_eq(str(inn_by_map.get("id", "")), "foot_village_inn", "反查应返回 foot_village_inn")

	var missing = repository.get_inn("not_exist")
	assertions.assert_true(missing.is_empty(), "不存在的客栈应返回空字典")
	var missing_map = repository.get_inn_for_map("mountain_pass")
	assertions.assert_true(missing_map.is_empty(), "mountain_pass 不应有客栈")
```

- [ ] **Step 4.2: 在 `tests/run_tests.gd` 注册**

```gdscript
const TestInnDataScript = preload("res://tests/test_inn_data.gd")
```

`suites` 末尾追加 `TestInnDataScript.new(),`。

- [ ] **Step 4.3: 跑测试确认失败**

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

期望：「应能查到 foot_village_inn」失败。

- [ ] **Step 4.4: 改 `data/maps.json` 在 foot_village 节点追加 `inns[]`**

定位到 foot_village map 节点（包含 `"id": "foot_village"`），在该 map 节点的最后一个属性（`objects` 数组）**之后**追加：

```json
,
    "inns": [
      {
        "id": "foot_village_inn",
        "map_id": "foot_village",
        "spawn_position": {"x": 760, "y": 320}
      }
    ]
```

注意：JSON 不允许尾逗号。位置应保证 `objects: [...]` 后跟 `,` 再跟 `inns: [...]`。`spawn_position` 用陆掌柜的真实坐标 `{x: 760, y: 320}`（已从 maps.json 现有数据读出）。

- [ ] **Step 4.5: 改 `scripts/systems/data_repository.gd` 加 inn API**

先 `Select-String "get_map\b" scripts/systems/data_repository.gd` 找到 `get_map` 方法实现位置（用于参考已有数据访问风格）。在 `get_map` 之后追加两个方法：

```gdscript
func get_inn(inn_id: String) -> Dictionary:
	if inn_id.is_empty():
		return {}
	for map_data in _maps:
		var inns = map_data.get("inns", [])
		if typeof(inns) != TYPE_ARRAY:
			continue
		for inn in inns:
			if typeof(inn) != TYPE_DICTIONARY:
				continue
			if str(inn.get("id", "")) == inn_id:
				var copy = inn.duplicate(true)
				if not copy.has("map_id"):
					copy["map_id"] = str(map_data.get("id", ""))
				return copy
	return {}

func get_inn_for_map(map_id: String) -> Dictionary:
	if map_id.is_empty():
		return {}
	var map_data = get_map(map_id)
	if map_data.is_empty():
		return {}
	var inns = map_data.get("inns", [])
	if typeof(inns) != TYPE_ARRAY or inns.is_empty():
		return {}
	for inn in inns:
		if typeof(inn) == TYPE_DICTIONARY:
			var copy = inn.duplicate(true)
			if not copy.has("map_id"):
				copy["map_id"] = map_id
			return copy
	return {}
```

注意：上面的 `_maps` 引用必须匹配 data_repository 实际的内部存储字段名。实施前 `Select-String "var _maps\|_maps =" scripts/systems/data_repository.gd` 确认。如果实际是别的名字（如 `var maps_data` 或 `_maps_by_id`），调整为对应名字。如果 maps 是 dict（key=id），改写遍历方式：`for key in _maps_by_id.keys(): var map_data = _maps_by_id[key]; ...`。

- [ ] **Step 4.6: 跑测试确认通过**

```powershell
& $godot --headless --path . --quit
& $godot --headless --path . -s tests/run_tests.gd
```

- [ ] **Step 4.7: 提交**

```powershell
git add data/maps.json scripts/systems/data_repository.gd tests/test_inn_data.gd tests/run_tests.gd
git commit -m "feat: 加入客栈数据与反查接口"
```

---

## Task 5: EffectSystem 加 rest_at_inn + 扩展陆掌柜对话

**Files:**
- Modify: `scripts/systems/effect_system.gd`（新增 `rest_at_inn` type）
- Modify: `data/dialogues.json`（扩展 `foot_village_innkeeper_idle` 加休息分支）
- Create: `tests/test_inn_rest_loop.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 5.1: 写失败测试 `tests/test_inn_rest_loop.gd`**

```gdscript
extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const EffectSystemScript = preload("res://scripts/systems/effect_system.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const ConditionSystemScript = preload("res://scripts/systems/condition_system.gd")

func run(assertions) -> void:
	# rest_at_inn 直接调用 EffectSystem
	var game_state = GameStateScript.new()
	game_state.start_new_game()
	game_state.hero_hp = 30
	game_state.consume_hero_mp(10)
	var initial_coins = game_state.party.coins

	var effect_system = EffectSystemScript.new()
	var rest_result = effect_system.apply_effect(game_state, {
		"type": "rest_at_inn",
		"inn_id": "foot_village_inn",
		"cost": 5,
	})
	assertions.assert_true(bool(rest_result.get("success", false)), "rest_at_inn 应成功")
	assertions.assert_eq(game_state.hero_hp, game_state.hero_max_hp, "休息后气血应满")
	assertions.assert_eq(game_state.hero_cur_mp, game_state.hero_max_mp, "休息后内力应满")
	assertions.assert_eq(game_state.last_inn_id, "foot_village_inn", "应绑定 last_inn_id")
	assertions.assert_eq(game_state.party.coins, initial_coins - 5, "应扣 5 文")

	# 铜钱不足：cost = 0 路径（免费分支）
	var poor_state = GameStateScript.new()
	poor_state.start_new_game()
	# 把铜钱花光到 4 文
	poor_state.party.spend_coins(poor_state.party.coins - 4)
	poor_state.hero_hp = 50
	poor_state.consume_hero_mp(8)
	var rest_free = effect_system.apply_effect(poor_state, {
		"type": "rest_at_inn",
		"inn_id": "foot_village_inn",
		"cost": 0,
	})
	assertions.assert_true(bool(rest_free.get("success", false)), "免费 rest_at_inn 应成功")
	assertions.assert_eq(poor_state.party.coins, 4, "免费休息不应扣钱")
	assertions.assert_eq(poor_state.hero_hp, poor_state.hero_max_hp, "免费休息也应回满气血")
	assertions.assert_eq(poor_state.hero_cur_mp, poor_state.hero_max_mp, "免费休息也应回满内力")

	# 缺 inn_id 应失败
	var bad_result = effect_system.apply_effect(game_state, {"type": "rest_at_inn"})
	assertions.assert_false(bool(bad_result.get("success", false)), "缺 inn_id 应失败")

	# cost > coins 应失败（此时玩家未触发免费分支，是 dialogue 层应拦住的情形；EffectSystem 兜底）
	var rich_state = GameStateScript.new()
	rich_state.start_new_game()
	rich_state.party.spend_coins(rich_state.party.coins - 3)
	var insufficient = effect_system.apply_effect(rich_state, {
		"type": "rest_at_inn",
		"inn_id": "foot_village_inn",
		"cost": 5,
	})
	assertions.assert_false(bool(insufficient.get("success", false)), "铜钱不足 + cost=5 应失败")
	assertions.assert_eq(rich_state.party.coins, 3, "失败不应扣钱")

	# dialogue 数据校验：陆掌柜对话应包含两个休息选项
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var dialogue = repository.get_dialogue("foot_village_innkeeper_idle")
	var options = dialogue.get("options", [])
	assertions.assert_true(typeof(options) == TYPE_ARRAY and options.size() >= 2, "陆掌柜对话应含至少 2 个选项")
	var ids: Array = []
	for opt in options:
		ids.append(str(opt.get("id", "")))
	assertions.assert_true(ids.has("rest_5_coins"), "应含 rest_5_coins 选项")
	assertions.assert_true(ids.has("rest_no_coin"), "应含 rest_no_coin 选项")
```

- [ ] **Step 5.2: 在 `tests/run_tests.gd` 注册**

```gdscript
const TestInnRestLoopScript = preload("res://tests/test_inn_rest_loop.gd")
```

`suites` 追加 `TestInnRestLoopScript.new(),`。

- [ ] **Step 5.3: 跑测试确认失败**

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

期望：rest_at_inn 未实现，「rest_at_inn 应成功」失败。

- [ ] **Step 5.4: 改 `scripts/systems/effect_system.gd` 加 dispatch + 实现**

在 `apply_effect` 的 `match` 块中 `"restore_mp":` 之后追加：

```gdscript
		"rest_at_inn":
			_apply_rest_at_inn(result, game_state, effect)
```

文件末尾（位于 `_apply_restore_mp` 之后）追加方法：

```gdscript
func _apply_rest_at_inn(result: Dictionary, game_state, effect: Dictionary) -> void:
	var inn_id = str(effect.get("inn_id", ""))
	if inn_id.is_empty():
		_add_error(result, "客栈休息缺少客栈编号。")
		return
	if game_state.party == null:
		_add_error(result, "队伍状态缺失。")
		return
	# 防御：不允许在战斗中休息
	if typeof(game_state.battle_context) == TYPE_DICTIONARY and not game_state.battle_context.is_empty():
		_add_error(result, "战斗中不能休息。")
		return
	var cost = int(effect.get("cost", 0))
	if cost > 0:
		if int(game_state.party.coins) < cost:
			_add_error(result, "铜钱不足无法支付客栈费用。")
			return
		game_state.party.spend_coins(cost)
		result["coins"] = int(result.get("coins", 0)) - cost

	# 全满恢复
	if game_state.has_method("restore_hero_hp"):
		var hp_missing = max(0, game_state.hero_max_hp - game_state.hero_hp)
		if hp_missing > 0:
			game_state.restore_hero_hp(hp_missing)
	if game_state.has_method("restore_hero_mp"):
		var mp_missing = max(0, game_state.hero_max_mp - game_state.hero_cur_mp)
		if mp_missing > 0:
			game_state.restore_hero_mp(mp_missing)
	# 绑定客栈
	if game_state.has_method("bind_inn"):
		game_state.bind_inn(inn_id)
	# 信号
	if game_state.is_inside_tree() and game_state.has_node("/root/EventBus"):
		game_state.get_node("/root/EventBus").inn_rested.emit(inn_id)
	_mark_applied(result, "在客栈歇息一晚。")
```

注意：`game_state.party.spend_coins(cost)` 假定方法名是 `spend_coins`。**实施前先确认**（Task 3 已经查过；如果是 `add_coins(-cost)` 则相应替换；但本项目 `add_coins` 拒绝负数，因此 `spend_coins` 应当存在；若没有，需要在 `party_state.gd` 加一个 `func spend_coins(n: int) -> bool: ...` 简单实现并在本 Task 一并提交）。

- [ ] **Step 5.5: 改 `data/dialogues.json` 扩展陆掌柜对话**

将现有 `foot_village_innkeeper_idle` 节点完整替换为：

```json
  {
    "id": "foot_village_innkeeper_idle",
    "title": "客栈门前",
    "lines": [
      {"speaker": "陆掌柜", "text": "客房已满，若是打听消息，先问问村口脚夫。"},
      {"speaker": "陆掌柜", "text": "少侠若内力不济，街中药铺有凝神丹可备。"}
    ],
    "options": [
      {
        "id": "rest_5_coins",
        "text": "歇息一晚（5 文）",
        "conditions": [
          {"type": "coins_at_least", "amount": 5}
        ],
        "effects": [
          {"type": "rest_at_inn", "inn_id": "foot_village_inn", "cost": 5}
        ],
        "unavailable_text": "盘缠不够 5 文。"
      },
      {
        "id": "rest_no_coin",
        "text": "盘缠不足，将就一晚",
        "conditions": [
          {"type": "not", "condition": {"type": "coins_at_least", "amount": 5}}
        ],
        "effects": [
          {"type": "rest_at_inn", "inn_id": "foot_village_inn", "cost": 0}
        ],
        "unavailable_text": "已经凑够店钱，请改选付费休息。"
      }
    ]
  },
```

注意：保留原有 `lines` 结构（dialogue_box 渲染机制依赖它），只追加 1 条提示药铺的话；`options` 是新追加字段。其他原 dialogue 节点保持不变。

- [ ] **Step 5.6: 跑测试确认通过**

```powershell
& $godot --headless --path . --quit
& $godot --headless --path . -s tests/run_tests.gd
```

- [ ] **Step 5.7: 提交**

```powershell
git add scripts/systems/effect_system.gd data/dialogues.json tests/test_inn_rest_loop.gd tests/run_tests.gd
git commit -m "feat: 加入客栈休息效果与陆掌柜对话分支"
```

---

## Task 6: 药铺商品列表追加凝神丹

**Files:**
- Modify: `data/maps.json`（foot_village 药铺 NPC 节点的 `items` 数组）
- Modify: `tests/test_shop_map_screen.gd` 或 `tests/test_shop_system.gd`（追加凝神丹商品断言）

- [ ] **Step 6.1: 先看现有药铺商店测试结构**

```powershell
Select-String -Path tests\test_shop_*.gd -Pattern "herb_small|foot_village_pharmacy|shop_id" | Select-Object -First 20
```

找到当前对药铺商品列表做断言的测试文件（很可能是 `test_shop_map_screen.gd` 或 `test_shop_system.gd`），决定在哪个文件追加凝神丹断言。

- [ ] **Step 6.2: 写失败断言**

在选中的测试文件的 `func run(assertions)` 末尾追加：

```gdscript
	# 药铺应出售凝神丹
	var pharmacy_objects = repository.get_map("foot_village").get("objects", [])
	var pharmacy_items: Array = []
	for obj in pharmacy_objects:
		if str(obj.get("id", "")) == "shop_foot_village_pharmacy":
			pharmacy_items = obj.get("items", [])
			break
	assertions.assert_true(pharmacy_items.has("herb_focus"), "药铺商品应包含凝神丹")
```

如果选中的文件没有 `repository` 局部变量，先 `var repository = DataRepositoryScript.new(); repository.load_all()` 并确保顶部 `const DataRepositoryScript = preload(...)`。

- [ ] **Step 6.3: 跑测试确认失败**

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

期望：「药铺商品应包含凝神丹」失败。

- [ ] **Step 6.4: 改 `data/maps.json`**

定位 foot_village 节点 → `objects` → `shop_foot_village_pharmacy` 对象 → `items` 数组，将：

```json
"items": ["herb_small"]
```

改为：

```json
"items": ["herb_small", "herb_focus"]
```

- [ ] **Step 6.5: 跑测试确认通过**

```powershell
& $godot --headless --path . --quit
& $godot --headless --path . -s tests/run_tests.gd
```

- [ ] **Step 6.6: 提交**

```powershell
git add data/maps.json tests/test_shop_map_screen.gd
git commit -m "feat: 药铺加售凝神丹"
```

（实际 `git add` 的测试文件名以 Step 6.1 选中的为准。）

---

## Task 7: 战棋 MP working copy + 死亡回流 + apply_battle_result 改造

> **本 Task 是切片中复杂度最高的一步**，分两个独立 commit：(7A) MP working copy 改造，(7B) 死亡回流。

**Files:**
- Modify: `scripts/core/game_state.gd`（apply_battle_result 失败分支改造、可能新增 helper）
- Modify: `scripts/scenes/battle_screen.gd`（创建战斗时把 unit.mp 来自 hero_cur_mp、结算时回写、回流时调 SceneLoader）
- Modify: `scripts/systems/tactical_combat_system.gd`（如有需要：在 `create_battle._build_unit` 内对玩家单位的 `mp/max_mp` 优先用 game_state.hero_cur_mp / hero_max_mp）
- Create: `tests/test_death_warp_to_inn.gd`
- Modify: `tests/run_tests.gd`

### Task 7A: MP working copy 与统一回写

- [ ] **Step 7A.1: 先确认现有玩家单位 MP 来源**

```powershell
Select-String -Path scripts\systems\tactical_combat_system.gd -Pattern "_build_unit|hero_max_mp|hero_yun" | Select-Object -First 30
Select-String -Path scripts\scenes\battle_screen.gd -Pattern "create_battle|hero_max_mp|hero_yun" | Select-Object -First 30
```

定位玩家单位创建逻辑中 `mp` / `max_mp` 字段的来源（通常是从 actor 数据 + game_state.hero_max_mp 推算）。

- [ ] **Step 7A.2: 在 `tactical_combat_system.gd._build_unit`（或 BattleScreen 构造 context.units 处）**

把玩家单位的 `mp` 从「等于 max_mp」改为「等于 game_state.hero_cur_mp」（仅当 actor_id == "hero_yun" 或 team == "player" 时）。具体改法：

定位 `_build_unit` 方法，在生成 unit 后、`return unit` 之前追加：

```gdscript
	if game_state != null and unit.team == TacticalUnitStateScript.TEAM_PLAYER and unit.actor_id == "hero_yun":
		unit.max_mp = game_state.hero_max_mp
		unit.mp = clamp(game_state.hero_cur_mp, 0, unit.max_mp)
```

如果 `_build_unit` 没有 `game_state` 参数，需要从 `create_battle` 传入：把 `_build_unit(raw_unit, game_state, source)` 中的 game_state 沿用现有签名（已有）。

- [ ] **Step 7A.3: 让 `tactical_battle_state.to_result_dictionary()` 携带 `hero_final_mp`**

打开 `scripts/domain/tactical_battle_state.gd` 找到 `to_result_dictionary` 方法，在返回字典中追加：

```gdscript
		"hero_final_mp": _get_hero_final_mp(),
```

并在 to_result_dictionary 之后追加 helper：

```gdscript
func _get_hero_final_mp() -> int:
	for unit in units:
		if unit.team == "player" and unit.actor_id == "hero_yun":
			return int(unit.mp)
	return -1  # 无主角单位（不应发生）
```

- [ ] **Step 7A.4: 改 `apply_battle_result` 回写 hero_cur_mp**

在 `scripts/core/game_state.gd` 的 `apply_battle_result` 方法**最开头**（在现有 `if result.has("hero_hp"):` 之前）追加：

```gdscript
	if result.has("hero_final_mp"):
		var final_mp = int(result.get("hero_final_mp", -1))
		if final_mp >= 0:
			set_hero_cur_mp(final_mp)
```

注意：失败回流分支会在 Task 7B 把 MP 重置为满，所以这里写完后失败/胜利都先正确回写战斗结束时的 MP，胜利时 MP 已扣为最终值，失败时下一段 7B 改造会覆盖回满。

- [ ] **Step 7A.5: 在 `tests/test_combat_and_save.gd` 末尾追加 working copy 断言**

```gdscript
	# 战斗结束携带 hero_final_mp 应回写到 hero_cur_mp
	var battle_end_state = GameStateScript.new()
	battle_end_state.start_new_game()
	battle_end_state.apply_battle_result({
		"victory": true,
		"hero_hp": 80,
		"hero_final_mp": 12,
	})
	assertions.assert_eq(battle_end_state.hero_cur_mp, 12, "胜利后 hero_cur_mp 应被回写为 12")
```

- [ ] **Step 7A.6: 跑测试确认通过**

```powershell
& $godot --headless --path . --quit
& $godot --headless --path . -s tests/run_tests.gd
```

- [ ] **Step 7A.7: 提交**

```powershell
git add scripts/systems/tactical_combat_system.gd scripts/domain/tactical_battle_state.gd scripts/core/game_state.gd tests/test_combat_and_save.gd
git commit -m "feat: 战棋内力以 game_state.hero_cur_mp 为准"
```

### Task 7B: 死亡回流到客栈

- [ ] **Step 7B.1: 写失败测试 `tests/test_death_warp_to_inn.gd`**

```gdscript
extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()

	# 已绑定客栈：失败回流 → 切到客栈所在 map + HP/MP 满
	var bound_state = GameStateScript.new()
	bound_state.start_new_game()
	bound_state.bind_inn("foot_village_inn")
	bound_state.set_current_map("mountain_pass", Vector2(400, 200))
	bound_state.hero_hp = 0
	bound_state.consume_hero_mp(15)
	bound_state.apply_battle_result({"victory": false, "hero_hp": 0})
	assertions.assert_eq(bound_state.map_state.current_map_id, "foot_village", "应切到 foot_village")
	assertions.assert_eq(int(bound_state.map_state.player_position.x), 760, "应放到陆掌柜旁 x")
	assertions.assert_eq(int(bound_state.map_state.player_position.y), 320, "应放到陆掌柜旁 y")
	assertions.assert_eq(bound_state.hero_hp, bound_state.hero_max_hp, "回流后 HP 满")
	assertions.assert_eq(bound_state.hero_cur_mp, bound_state.hero_max_mp, "回流后 MP 满")

	# 未绑定：沿用原地复活逻辑（HP=1, position=Vector2(160, 320)）
	var fresh_state = GameStateScript.new()
	fresh_state.start_new_game()
	fresh_state.set_current_map("mountain_pass", Vector2(400, 200))
	fresh_state.hero_hp = 0
	fresh_state.apply_battle_result({"victory": false, "hero_hp": 0})
	assertions.assert_eq(fresh_state.map_state.current_map_id, "mountain_pass", "未绑定不应切场")
	assertions.assert_eq(fresh_state.hero_hp, 1, "未绑定原地复活 HP=1")
```

- [ ] **Step 7B.2: 在 `tests/run_tests.gd` 注册**

```gdscript
const TestDeathWarpToInnScript = preload("res://tests/test_death_warp_to_inn.gd")
```

`suites` 追加 `TestDeathWarpToInnScript.new(),`。

- [ ] **Step 7B.3: 跑测试确认失败**

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

- [ ] **Step 7B.4: 改 `apply_battle_result` 失败分支**

将 `apply_battle_result` 中 `else:` 分支（现行 `hero_hp = max(1, hero_hp); map_state.player_position = Vector2(160, 320)`）整段替换为：

```gdscript
	else:
		if has_bound_inn():
			var inn = _resolve_bound_inn()
			if not inn.is_empty():
				var inn_map_id = str(inn.get("map_id", ""))
				var spawn = inn.get("spawn_position", {})
				var spawn_pos = Vector2(int(spawn.get("x", 160)), int(spawn.get("y", 320)))
				if not inn_map_id.is_empty():
					set_current_map(inn_map_id, spawn_pos)
				hero_hp = hero_max_hp
				hero_cur_mp = hero_max_mp
				_normalize_hero_hp()
				_normalize_hero_mp()
				if is_inside_tree() and has_node("/root/EventBus"):
					get_node("/root/EventBus").hero_mp_changed.emit(hero_cur_mp, hero_max_mp)
				return
		# 未绑定客栈：沿用原地复活
		hero_hp = max(1, hero_hp)
		map_state.player_position = Vector2(160, 320)
```

并在 game_state.gd 末尾追加 helper：

```gdscript
func _resolve_bound_inn() -> Dictionary:
	if last_inn_id.is_empty():
		return {}
	if is_inside_tree() and has_node("/root/DataRepository"):
		return get_node("/root/DataRepository").get_inn(last_inn_id)
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var inn = repository.get_inn(last_inn_id)
	repository.free()
	return inn
```

- [ ] **Step 7B.5: 跑测试确认通过**

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

- [ ] **Step 7B.6: 改 `scripts/scenes/battle_screen.gd` 在战斗结束时切场**

定位 `_return_if_finished` 与 `_return_if_tactical_finished` 中调用 `apply_battle_result` 之后的 `_return_to_map`。`_return_to_map` 当前用 `source_map_id` 决定回到哪张图，但 `apply_battle_result` 现在已经在失败 + 已绑定情形下**直接修改了 `map_state.current_map_id`**，所以场景切换目标应改用 `GameState.map_state.current_map_id`：

将 `_return_to_map` 中：

```gdscript
	if source_map_id.is_empty():
		source_map_id = "mountain_pass"
	GameState.consume_battle_context()
	SceneLoader.change_scene(GameState.get_scene_path_for_map(source_map_id))
```

改为：

```gdscript
	if source_map_id.is_empty():
		source_map_id = "mountain_pass"
	GameState.consume_battle_context()
	# 失败回流可能已经切了 current_map_id，优先使用它
	var target_map_id = GameState.map_state.current_map_id
	if target_map_id.is_empty():
		target_map_id = source_map_id
	SceneLoader.change_scene(GameState.get_scene_path_for_map(target_map_id))
```

- [ ] **Step 7B.7: 跑测试再次确认**

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

- [ ] **Step 7B.8: 提交**

```powershell
git add scripts/core/game_state.gd scripts/scenes/battle_screen.gd tests/test_death_warp_to_inn.gd tests/run_tests.gd
git commit -m "feat: 战棋失败时回流到已绑定客栈"
```

---

## Task 8: HUD 显示当前/最大内力

**Files:**
- Modify: `scripts/scenes/hud.gd`（追加 MP Label 引用、监听 `hero_mp_changed`）
- 可能修改 HUD 的 .tscn 节点结构（若 HUD 用代码动态创建则不需要；若用 .tscn 静态节点则需要在编辑器加 Label 节点）
- Create: `tests/test_hud_mp_display.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 8.1: 先看 HUD 现状**

```powershell
Get-Content scripts\scenes\hud.gd -TotalCount 80
```

确认 HUD 是用动态构建（`_ready` 中 `add_child`）还是静态 .tscn。若动态构建：在代码中追加 MP Label 即可，无需改 .tscn。

- [ ] **Step 8.2: 写失败测试 `tests/test_hud_mp_display.gd`**

```gdscript
extends RefCounted

const HudScript = preload("res://scripts/scenes/hud.gd")

func run(assertions) -> void:
	# 可重入加载：实例化 HUD 节点，伪造 GameState 与 EventBus
	var hud = HudScript.new()
	hud._ready_for_tests() if hud.has_method("_ready_for_tests") else hud._enter_tree()
	# 直接调用刷新方法，验证 MP 文本显示
	hud.refresh_mp_display(7, 20)
	assertions.assert_true(hud.has_method("refresh_mp_display"), "HUD 应暴露 refresh_mp_display 方法")
	# 数字格式："内力 7/20"（具体格式可调，下面断言用 contains 容错）
	var label = hud.get("mp_label") if hud.get("mp_label") != null else null
	assertions.assert_true(label != null, "HUD 应有 mp_label 字段")
	if label != null:
		var text = str(label.text)
		assertions.assert_true(text.find("7") >= 0 and text.find("20") >= 0, "MP 文本应包含 7 和 20")
	hud.queue_free()
```

注意：HUD 可能依赖 `/root/GameState` autoload，单测环境无 autoload。本测试采取「直接调用 refresh_mp_display(cur, max)」绕开 autoload，保证测试可独立运行。如果直接 instantiate HUD 失败（比如 `_ready` 强依赖 EventBus），改为更轻量的接口断言：

```gdscript
	# 退化版：仅断言 HUD 类有 refresh_mp_display 与 mp_label 成员
	var hud_obj = HudScript.new()
	assertions.assert_true(hud_obj.has_method("refresh_mp_display"), "HUD 应有 refresh_mp_display 方法")
```

- [ ] **Step 8.3: 在 `tests/run_tests.gd` 注册**

```gdscript
const TestHudMpDisplayScript = preload("res://tests/test_hud_mp_display.gd")
```

`suites` 追加 `TestHudMpDisplayScript.new(),`。

- [ ] **Step 8.4: 跑测试确认失败**

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

- [ ] **Step 8.5: 改 `scripts/scenes/hud.gd`**

参考现有 HP Label 的添加方式，做平行扩展：

1. 在类成员变量区追加：
```gdscript
var mp_label: Label = null
```

2. 在 `_ready()` 或现有创建 HP Label 的地方之后，追加 MP Label 创建：
```gdscript
	mp_label = Label.new()
	mp_label.name = "MpLabel"
	mp_label.modulate = Color(0.6, 0.85, 1.0, 1.0)  # 蓝色调与气血红色区分
	add_child(mp_label)
	# 位置：紧贴 HP Label 之下，根据现有 HP Label 位置 +24 像素
```
具体 add_child / position / anchor 写法**对齐现有 HP Label 同样的代码模式**（实施时复制 HP Label 的 4-6 行作为模板）。

3. 在现有连接 EventBus 信号处（搜索 `hero_hp` 或 `EventBus.` 信号连接）后追加：
```gdscript
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").hero_mp_changed.connect(_on_hero_mp_changed)
```

4. 类末尾追加方法：
```gdscript
func refresh_mp_display(cur_mp: int, max_mp: int) -> void:
	if mp_label != null:
		mp_label.text = "内力 %d/%d" % [cur_mp, max_mp]

func _on_hero_mp_changed(cur_mp: int, max_mp: int) -> void:
	refresh_mp_display(cur_mp, max_mp)
```

5. 在 `_ready()` 末尾追加初始刷新：
```gdscript
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		refresh_mp_display(gs.hero_cur_mp, gs.hero_max_mp)
```

- [ ] **Step 8.6: 跑测试确认通过**

```powershell
& $godot --headless --path . -s tests/run_tests.gd
```

- [ ] **Step 8.7: 提交**

```powershell
git add scripts/scenes/hud.gd tests/test_hud_mp_display.gd tests/run_tests.gd
git commit -m "feat: HUD 显示主角当前与最大内力"
```

---

## Task 9: UAT 跑通三循环 + 文档更新

**Files:**
- Modify: `README.md`（在「当前目标」列表末尾追加本切片描述）

- [ ] **Step 9.1: 全套自动化测试通过**

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
& $godot --headless --path . -s tests/run_tests.gd
```

期望：所有测试通过，控制台无 `push_error` 红字。

- [ ] **Step 9.2: 手动 UAT 循环 1 — 胜利循环**

启动游戏：
```powershell
& $godot --path .
```

操作流程：
1. 主菜单 → 新游戏
2. 走到山道遭遇强人 → 进入战棋
3. 用基础剑法消耗 3 内力击败敌人
4. 胜利返回山道地图，HUD 显示「内力 17/20」
5. 走回村镇 → 与陆掌柜对话 → 选「歇息一晚（5 文）」
6. 检查：HUD 显示「气血 120/120 内力 20/20」、铜钱 -5
7. 关闭游戏

**预期：UAT 通过即可。如发现问题，回到对应 Task 修复。**

- [ ] **Step 9.3: 手动 UAT 循环 2 — 失败回流循环**

1. 新游戏 → 直接出门去山道（**不绑定客栈**）
2. 故意被强人击败 → HP=0
3. 检查：原地复活 HP=1 + position 回 mountain_pass 出生点（与上一切片行为一致 = 老存档兼容）
4. 回村镇 → 对话陆掌柜 → 休息 → 绑定
5. 再去山道 → 故意被击败
6. 检查：自动切场到 foot_village，玩家定位到陆掌柜旁，HP/MP 全满

- [ ] **Step 9.4: 手动 UAT 循环 3 — 嗑药循环**

1. 新游戏 → 进药铺 → 买 1 颗凝神丹（-12 文）
2. 出门进战棋 → 用穿云刺消耗 5 内力 → 战斗中打开背包用凝神丹 → 内力 +10
3. 胜利返回 → HUD 显示恢复后的 MP 值
4. 检查：背包凝神丹 -1

- [ ] **Step 9.5: 更新 README.md**

打开 `README.md`，在「当前目标」列表末尾追加一行（参考已有切片描述风格）：

```markdown
- 客栈休整与内力闭环切片：村镇陆掌柜可付 5 文休息恢复气血与内力并绑定回流点，药铺出售凝神丹可在战斗内外恢复 10 内力，战棋失败后若已绑定客栈则切场回客栈。
```

- [ ] **Step 9.6: 最终 commit + merge**

```powershell
git add README.md
git commit -m "docs: 记录客栈休整与内力闭环切片"
& $godot --headless --path . -s tests/run_tests.gd
# 期望 PASS
git log --oneline -15
```

按项目惯例，可在主线确认无误后做 merge commit：

```powershell
git checkout main
git merge --no-ff <feature-branch> -m "merge: inn rest mp loop"
```

（如果实施时所有 Task 都直接在 main 上推进，跳过 merge 步骤。本项目历史显示既有 feature branch 也有直推 main 的混合实践，按当时上下文判断。）

---

## Self-Review

### 1. Spec coverage

| Spec 条目 | 对应 Task |
|---|---|
| `hero_cur_mp` 字段 + 默认值 | Task 1 |
| 陆掌柜对话休息分支 | Task 5 |
| 5 文价 + 免费兜底 | Task 5（dialogue 选项 `coins_at_least` 条件 + `cost: 0` 分支） |
| `last_inn_id` 字段绑定 | Task 1（字段）+ Task 5（rest_at_inn 内置 bind） |
| 凝神丹 `herb_focus` | Task 2 |
| 战内外都可用 | Task 2（InventorySystem 改造 + 测试覆盖战外）+ 战内通过现有「战斗内背包面板」自动支持（Task 7 不破坏该路径） |
| +10 内力 | Task 2（数据） |
| 药铺出售 | Task 6 |
| 失败回流（已绑定 → 切场） | Task 7B |
| 失败回流（未绑定 → 沿用） | Task 7B（else 分支保留原逻辑） |
| HUD 显示内力 | Task 8 |
| 不升 SAVE_VERSION | Task 1（`from_dictionary` 用 `data.get(..., default)`） |
| EventBus 信号 hero_mp_changed / inn_rested | Task 1（声明）+ Task 5（emit inn_rested）+ Task 7（emit hero_mp_changed） |
| `coins_at_least` 条件 | Task 3 |
| `restore_mp` / `rest_at_inn` 效果 | Task 2 / Task 5 |
| 战棋 MP working copy 改造 | Task 7A |

**覆盖完整。**

### 2. Placeholder scan

- ✅ 无 TBD / TODO / 「实现 X」「适当处理 Y」等模糊指令。
- ✅ 每段代码块都给出可粘贴的真实实现，不是范例。
- ⚠️ Step 4.5 / Step 5.4 / Step 6.1 / Step 7A.1 / Step 7B.6 / Step 8.1 / Step 8.5 中标注了 **「实施前先 Select-String 确认」** 的几处，是因为以下实际原因：
  - data_repository 的内部存储字段名（`_maps` vs `maps_data`）需在改之前查证一次
  - party_state 的扣钱方法名（`spend_coins` vs `add_coins(-N)`）需查证一次
  - HUD 现有 HP Label 创建方式（动态 vs 静态）需查证一次以模仿
  
  这些不是 placeholder，是显式风险标注 + 1 行 PowerShell 命令立即可解，与「TBD」性质不同。

### 3. Type consistency

- 内力字段：`hero_cur_mp` / `hero_max_mp` 在所有 Task / 测试 / 方法签名中一致使用。
- 客栈字段：`last_inn_id` / `inn_id`（参数）/ `foot_village_inn`（具体值）一致。
- 信号签名：`hero_mp_changed(cur_mp: int, max_mp: int)` / `inn_rested(inn_id: String)` 一致。
- effect type 字符串：`restore_mp` / `rest_at_inn` 一致。
- condition type 字符串：`coins_at_least` 一致。
- BattleResult 字段：`hero_final_mp` 一致。

**类型一致。**

---

## 附录：执行注意事项

1. **逐 Task 验证可单独跑通**：每个 commit 前都跑一次完整 `tests/run_tests.gd`，避免后面 Task 才发现前面 Task 的回归。
2. **数据 .json 改完一定 `--quit` 一次**：刷新 .uid 缓存（项目 godot.md 沉淀）。
3. **EventBus / GameState 是 autoload，单测中可能未启动**：测试代码不能假定 `/root/EventBus` 存在；GameState 内部已经用 `if is_inside_tree() and has_node("/root/EventBus"):` 防御。
4. **战棋测试与场景测试不同**：domain（如 `tactical_battle_state`）测试可纯逻辑；scene（battle_screen）测试需 SceneTree，本切片选择**只测 `apply_battle_result` 的回流逻辑**，不引入 battle_screen 的 SceneTree 测试，避免复杂度爆炸。
5. **失败回流的 spawn 坐标**：当前以陆掌柜在 maps.json 中的 (760, 320) 为 spawn。若未来想让玩家出现在客栈门口而非 NPC 重叠，调 `inns[].spawn_position`。
