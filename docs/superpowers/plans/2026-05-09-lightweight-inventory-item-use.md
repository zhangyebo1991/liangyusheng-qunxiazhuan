# 轻量背包与物品使用切片 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有山道和山脚村镇地图中加入轻量背包面板，让玩家能查看小还丹等奖励、使用消耗品恢复气血，并通过存档恢复背包和气血状态。

**Architecture:** 沿用现有“领域逻辑、系统流程、场景表现”分层。`PartyState` 管理背包数量，`ItemRecord` 读取物品效果，新增 `InventorySystem` 处理使用规则，`GameState` 保存主角气血，`hud.gd` 只负责背包面板显示，`map_screen_base.gd` 负责输入和系统接线。山道和村镇继续继承同一个地图基础脚本，因此背包行为只实现一次。

**Tech Stack:** Godot 4.6、GDScript、JSON 数据文件、Godot 无头脚本测试、PowerShell 验证命令。

---

## 范围检查

本计划实现 `docs/superpowers/specs/2026-05-09-lightweight-inventory-item-use-design.md`。范围只包含地图内背包面板、物品资料效果、消耗品使用、主角气血、背包数量和存档恢复。不实现装备界面、商店买卖、物品排序分类、拖拽、多角色用药、战斗中使用物品或复杂角色属性面板。

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
data/items.json                               # 增加 consumable effects，保留 iron_sword 作为不可使用物品
docs/godot-project-structure.md               # 记录轻量背包切片规则
README.md                                     # 更新当前目标
project.godot                                 # 新增 inventory 输入动作，I 键
scripts/core/game_state.gd                    # 增加 hero_hp / hero_max_hp 和气血恢复、存档字段
scripts/domain/item_record.gd                 # 增加 effects 字段
scripts/domain/party_state.gd                 # 增加背包查询和扣除方法
scripts/scenes/hud.gd                         # 增加背包面板、物品列表、使用按钮和信号
scripts/scenes/map_screen_base.gd             # 接入 I 键、背包显示、InventorySystem 调用和刷新
scripts/systems/inventory_system.gd           # 新增物品使用规则
tests/run_tests.gd                            # 接入新增 inventory 测试套件
tests/test_domain_models.gd                   # 覆盖 ItemRecord effects 和 PartyState 背包方法
tests/test_inventory_system.gd                # 覆盖小还丹使用和失败场景
tests/test_save_map_state.gd                  # 覆盖背包、气血、旧存档和异常气血读档
```

---

### Task 1: 扩展领域模型和物品数据

**Files:**
- Modify: `tests/test_domain_models.gd`
- Modify: `scripts/domain/party_state.gd`
- Modify: `scripts/domain/item_record.gd`
- Modify: `data/items.json`

- [ ] **Step 1: 写失败测试 `tests/test_domain_models.gd`**

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

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL，报错应包含 `Invalid get index 'effects'`、`Invalid call. Nonexistent function 'get_item_count'` 或等价的缺失字段/方法错误。

- [ ] **Step 3: 实现 `PartyState` 背包查询和扣除**

Replace `scripts/domain/party_state.gd` with:

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
	inventory[item_id] = get_item_count(item_id) + amount

func get_item_count(item_id: String) -> int:
	if item_id.is_empty():
		return 0
	return max(0, int(inventory.get(item_id, 0)))

func has_item(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false
	return get_item_count(item_id) >= amount

func remove_item(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false
	var current = get_item_count(item_id)
	if current < amount:
		return false
	var remaining = current - amount
	if remaining <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = remaining
	return true

func to_dictionary() -> Dictionary:
	return {
		"members": members.duplicate(),
		"inventory": inventory.duplicate(true),
	}

func from_dictionary(data: Dictionary) -> void:
	members = _to_string_array(data.get("members", []))
	inventory = {}
	var raw_inventory = data.get("inventory", {})
	if typeof(raw_inventory) != TYPE_DICTIONARY:
		return
	for item_id in raw_inventory.keys():
		var amount = int(raw_inventory[item_id])
		if amount > 0:
			inventory[str(item_id)] = amount

func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
```

- [ ] **Step 4: 实现 `ItemRecord.effects`**

Replace `scripts/domain/item_record.gd` with:

```gdscript
class_name ItemRecord
extends RefCounted

var id: String = ""
var name: String = ""
var type: String = ""
var description: String = ""
var value: int = 0
var effects: Dictionary = {}

static func from_dictionary(data: Dictionary):
	var item = new()
	item.id = str(data.get("id", ""))
	item.name = str(data.get("name", ""))
	item.type = str(data.get("type", ""))
	item.description = str(data.get("description", ""))
	item.value = int(data.get("value", 0))
	item.effects = data.get("effects", {}).duplicate(true)
	return item
```

- [ ] **Step 5: 扩展 `data/items.json`**

Replace `data/items.json` with:

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
  }
]
```

- [ ] **Step 6: 运行测试并确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过：9 个测试套件`。

- [ ] **Step 7: 提交领域模型和物品数据**

```powershell
git add tests/test_domain_models.gd scripts/domain/party_state.gd scripts/domain/item_record.gd data/items.json
git commit -m "feat: 扩展背包领域模型"
```

---

### Task 2: 增加主角气血和存档恢复

**Files:**
- Modify: `tests/test_save_map_state.gd`
- Modify: `scripts/core/game_state.gd`

- [ ] **Step 1: 写失败测试 `tests/test_save_map_state.gd`**

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

	var old_save_state = GameStateScript.new()
	old_save_state.from_dictionary({
		"party": {"members": ["hero_yun"], "inventory": {"herb_small": 1}},
		"quests": {},
		"map_state": {},
		"flags": {},
	})
	assertions.assert_eq(old_save_state.hero_hp, 120, "旧存档缺少气血时应回退为满气血")
	assertions.assert_eq(old_save_state.hero_max_hp, 120, "旧存档缺少最大气血时应使用默认值")

	var invalid_hp_state = GameStateScript.new()
	invalid_hp_state.from_dictionary({
		"party": {"members": ["hero_yun"]},
		"quests": {},
		"map_state": {},
		"flags": {},
		"hero_hp": 999,
		"hero_max_hp": 100,
	})
	assertions.assert_eq(invalid_hp_state.hero_hp, 100, "读档气血大于最大值时应钳制")
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

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL，报错应包含 `Invalid set index 'hero_hp'`、`Invalid get index 'hero_max_hp'` 或 `Nonexistent function 'restore_hero_hp'`。

- [ ] **Step 3: 实现 `GameState` 气血和存档字段**

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

func start_new_game() -> void:
	party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.add_item("herb_small", 1)
	quest_system = QuestSystemScript.new()
	map_state = MapStateScript.new()
	hero_max_hp = DEFAULT_HERO_MAX_HP
	hero_hp = hero_max_hp
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
	_normalize_hero_hp()
	battle_context = {}

func _normalize_hero_hp() -> void:
	if hero_max_hp <= 0:
		hero_max_hp = DEFAULT_HERO_MAX_HP
	hero_hp = clamp(hero_hp, 0, hero_max_hp)
```

- [ ] **Step 4: 运行测试并确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过：9 个测试套件`。

- [ ] **Step 5: 提交气血存档**

```powershell
git add tests/test_save_map_state.gd scripts/core/game_state.gd
git commit -m "feat: 保存主角气血状态"
```

---

### Task 3: 新增 InventorySystem 和使用规则测试

**Files:**
- Create: `tests/test_inventory_system.gd`
- Modify: `tests/run_tests.gd`
- Create: `scripts/systems/inventory_system.gd`

- [ ] **Step 1: 写失败测试 `tests/test_inventory_system.gd`**

Create `tests/test_inventory_system.gd`:

```gdscript
extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const InventorySystemScript = preload("res://scripts/systems/inventory_system.gd")

func run(assertions) -> void:
	DataRepository.load_all()

	var system = InventorySystemScript.new()
	var state = GameStateScript.new()
	state.start_new_game()
	state.hero_hp = 60

	var success = system.use_item(state, "herb_small")
	assertions.assert_true(bool(success.get("success", false)), "气血未满时应能使用小还丹")
	assertions.assert_eq(success.get("message", ""), "服下小还丹，气血恢复。", "成功使用应返回中文提示")
	assertions.assert_eq(state.hero_hp, 90, "小还丹应恢复 30 点气血")
	assertions.assert_eq(state.party.get_item_count("herb_small"), 0, "使用后应扣除 1 个小还丹")
	assertions.assert_eq(success.get("remaining", -1), 0, "结果应返回剩余数量")

	var full_hp_state = GameStateScript.new()
	full_hp_state.start_new_game()
	var full_hp_result = system.use_item(full_hp_state, "herb_small")
	assertions.assert_true(not bool(full_hp_result.get("success", true)), "气血已满时不应使用小还丹")
	assertions.assert_eq(full_hp_result.get("message", ""), "气血已满。", "气血已满应返回提示")
	assertions.assert_eq(full_hp_state.party.get_item_count("herb_small"), 1, "气血已满时不应扣物品")

	var missing_count_state = GameStateScript.new()
	missing_count_state.start_new_game()
	missing_count_state.party.remove_item("herb_small", 1)
	var missing_count = system.use_item(missing_count_state, "herb_small")
	assertions.assert_true(not bool(missing_count.get("success", true)), "数量不足时不应使用物品")
	assertions.assert_eq(missing_count.get("message", ""), "背包中没有此物。", "数量不足应返回提示")

	var missing_data_state = GameStateScript.new()
	missing_data_state.start_new_game()
	missing_data_state.hero_hp = 60
	missing_data_state.party.add_item("missing_item", 1)
	var missing_data = system.use_item(missing_data_state, "missing_item")
	assertions.assert_true(not bool(missing_data.get("success", true)), "资料缺失时不应使用物品")
	assertions.assert_eq(missing_data.get("message", ""), "此物品资料缺失。", "资料缺失应返回提示")
	assertions.assert_eq(missing_data_state.party.get_item_count("missing_item"), 1, "资料缺失时不应扣物品")

	var weapon_state = GameStateScript.new()
	weapon_state.start_new_game()
	weapon_state.hero_hp = 60
	weapon_state.party.add_item("iron_sword", 1)
	var weapon_result = system.use_item(weapon_state, "iron_sword")
	assertions.assert_true(not bool(weapon_result.get("success", true)), "非消耗品不应直接使用")
	assertions.assert_eq(weapon_result.get("message", ""), "此物暂时不能使用。", "非消耗品应返回提示")
	assertions.assert_eq(weapon_state.party.get_item_count("iron_sword"), 1, "非消耗品使用失败时不应扣物品")

	DataRepository.content["items"].append({
		"id": "blank_pill",
		"name": "空丹",
		"type": "consumable",
		"description": "没有效果的丹药。",
		"value": 1,
		"effects": {},
	})
	var blank_state = GameStateScript.new()
	blank_state.start_new_game()
	blank_state.hero_hp = 60
	blank_state.party.add_item("blank_pill", 1)
	var blank_result = system.use_item(blank_state, "blank_pill")
	assertions.assert_true(not bool(blank_result.get("success", true)), "效果缺失时不应使用物品")
	assertions.assert_eq(blank_result.get("message", ""), "此物暂时不能使用。", "效果缺失应返回提示")
	assertions.assert_eq(blank_state.party.get_item_count("blank_pill"), 1, "效果缺失时不应扣物品")

	state.free()
	full_hp_state.free()
	missing_count_state.free()
	missing_data_state.free()
	weapon_state.free()
	blank_state.free()
```

- [ ] **Step 2: 接入测试运行器**

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

- [ ] **Step 3: 运行测试并确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL，报错应包含无法加载 `res://scripts/systems/inventory_system.gd`。

- [ ] **Step 4: 实现 `InventorySystem`**

Create `scripts/systems/inventory_system.gd`:

```gdscript
extends RefCounted

const MESSAGE_MISSING_ITEM := "背包中没有此物。"
const MESSAGE_MISSING_DATA := "此物品资料缺失。"
const MESSAGE_UNUSABLE := "此物暂时不能使用。"
const MESSAGE_FULL_HP := "气血已满。"

func use_item(game_state, item_id: String) -> Dictionary:
	var normalized_item_id = str(item_id)
	if normalized_item_id.is_empty():
		return _failure(normalized_item_id, MESSAGE_MISSING_DATA, 0)
	if game_state == null or game_state.party == null:
		return _failure(normalized_item_id, MESSAGE_MISSING_ITEM, 0)

	var count = game_state.party.get_item_count(normalized_item_id)
	if count <= 0:
		return _failure(normalized_item_id, MESSAGE_MISSING_ITEM, 0)

	var item_data = DataRepository.get_item(normalized_item_id)
	if item_data.is_empty():
		return _failure(normalized_item_id, MESSAGE_MISSING_DATA, count)
	if str(item_data.get("type", "")) != "consumable":
		return _failure(normalized_item_id, MESSAGE_UNUSABLE, count)

	var effects = item_data.get("effects", {})
	if typeof(effects) != TYPE_DICTIONARY:
		return _failure(normalized_item_id, MESSAGE_UNUSABLE, count)

	var heal_hp = int(effects.get("heal_hp", 0))
	if heal_hp <= 0:
		return _failure(normalized_item_id, MESSAGE_UNUSABLE, count)
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

func _failure(item_id: String, message: String, remaining: int) -> Dictionary:
	return {
		"success": false,
		"message": message,
		"item_id": item_id,
		"remaining": remaining,
	}
```

- [ ] **Step 5: 运行测试并确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过：10 个测试套件`。

- [ ] **Step 6: 提交物品使用系统**

```powershell
git add tests/test_inventory_system.gd tests/run_tests.gd scripts/systems/inventory_system.gd
git commit -m "feat: 添加物品使用系统"
```

---

### Task 4: 增加背包输入和 HUD 面板

**Files:**
- Modify: `project.godot`
- Modify: `scripts/scenes/hud.gd`

- [ ] **Step 1: 修改 `project.godot` 增加 `inventory` 输入动作**

In `project.godot`, under `[input]`, add this block after the `cancel` action:

```ini
inventory={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":73,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
```

- [ ] **Step 2: 实现 HUD 背包面板**

Replace `scripts/scenes/hud.gd` with:

```gdscript
extends CanvasLayer

signal item_use_requested(item_id: String)

var quest_label: Label
var prompt_label: Label
var message_label: Label
var inventory_panel: Panel
var inventory_list: VBoxContainer
var inventory_empty_label: Label
var inventory_is_open := false

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

	_create_inventory_panel()

	set_quest_text("")
	set_prompt("")
	show_message("")

func set_quest_text(text: String) -> void:
	quest_label.text = text

func set_prompt(text: String) -> void:
	prompt_label.text = text

func show_message(text: String) -> void:
	message_label.text = text

func show_inventory(items: Array) -> void:
	inventory_is_open = true
	inventory_panel.visible = true
	refresh_inventory(items)

func hide_inventory() -> void:
	inventory_is_open = false
	inventory_panel.visible = false

func toggle_inventory(items: Array) -> void:
	if inventory_is_open:
		hide_inventory()
	else:
		show_inventory(items)

func refresh_inventory(items: Array) -> void:
	for child in inventory_list.get_children():
		child.queue_free()

	inventory_empty_label.visible = items.is_empty()
	if items.is_empty():
		return

	for item in items:
		_add_inventory_row(item)

func is_inventory_open() -> bool:
	return inventory_is_open

func _create_inventory_panel() -> void:
	inventory_panel = Panel.new()
	inventory_panel.position = Vector2(760, 72)
	inventory_panel.size = Vector2(460, 520)
	inventory_panel.visible = false
	add_child(inventory_panel)

	var title = Label.new()
	title.text = "背包"
	title.position = Vector2(16, 14)
	title.size = Vector2(160, 32)
	inventory_panel.add_child(title)

	var close_button = Button.new()
	close_button.text = "关闭"
	close_button.position = Vector2(368, 12)
	close_button.size = Vector2(72, 36)
	close_button.pressed.connect(hide_inventory)
	inventory_panel.add_child(close_button)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(16, 64)
	scroll.size = Vector2(428, 438)
	inventory_panel.add_child(scroll)

	inventory_list = VBoxContainer.new()
	inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inventory_list)

	inventory_empty_label = Label.new()
	inventory_empty_label.text = "背包空空如也。"
	inventory_empty_label.position = Vector2(32, 86)
	inventory_empty_label.size = Vector2(360, 32)
	inventory_empty_label.visible = false
	inventory_panel.add_child(inventory_empty_label)

func _add_inventory_row(item: Dictionary) -> void:
	var row = VBoxContainer.new()
	row.custom_minimum_size = Vector2(400, 104)
	inventory_list.add_child(row)

	var name = str(item.get("name", "未知物品"))
	var quantity = int(item.get("quantity", 0))
	var type_text = str(item.get("type", "unknown"))

	var header = Label.new()
	header.text = "%s x%d [%s]" % [name, quantity, type_text]
	header.size = Vector2(400, 24)
	row.add_child(header)

	var description = Label.new()
	description.text = str(item.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(400, 44)
	row.add_child(description)

	var use_button = Button.new()
	use_button.text = "使用"
	use_button.disabled = not bool(item.get("usable", false))
	use_button.custom_minimum_size = Vector2(72, 32)
	var item_id = str(item.get("id", ""))
	use_button.pressed.connect(func(): item_use_requested.emit(item_id))
	row.add_child(use_button)
```

- [ ] **Step 3: 运行项目加载测试**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
```

Expected: PASS，无解析错误，进程退出码为 `0`。

- [ ] **Step 4: 运行逻辑测试**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过：10 个测试套件`。

- [ ] **Step 5: 提交 HUD 背包面板**

```powershell
git add project.godot scripts/scenes/hud.gd
git commit -m "feat: 添加背包界面"
```

---

### Task 5: 在地图基础场景中接入背包使用

**Files:**
- Modify: `scripts/scenes/map_screen_base.gd`

- [ ] **Step 1: 接入 InventorySystem、I 键和 HUD 信号**

Replace `scripts/scenes/map_screen_base.gd` with:

```gdscript
extends Node2D

const PlayerControllerScript = preload("res://scripts/scenes/player_controller.gd")
const MapInteractableScript = preload("res://scripts/scenes/map_interactable.gd")
const HudScript = preload("res://scripts/scenes/hud.gd")
const DialogueBoxScript = preload("res://scripts/scenes/dialogue_box.gd")
const DialogueSystemScript = preload("res://scripts/systems/dialogue_system.gd")
const MapObjectSpawnerScript = preload("res://scripts/systems/map_object_spawner.gd")
const MapTransitionSystemScript = preload("res://scripts/systems/map_transition_system.gd")
const InventorySystemScript = preload("res://scripts/systems/inventory_system.gd")

var player
var hud
var dialogue_box
var dialogue_system = DialogueSystemScript.new()
var spawner = MapObjectSpawnerScript.new()
var transition_system = MapTransitionSystemScript.new()
var inventory_system = InventorySystemScript.new()
var map_data: Dictionary = {}
var interactables: Array = []
var map_id: String = ""
var fallback_spawn: Vector2 = Vector2(160, 320)
var background_color: Color = Color("#6f8f55")
var obstacle_color: Color = Color("#476f3f")

func configure_map(next_map_id: String, next_fallback_spawn: Vector2, next_background_color: Color, next_obstacle_color: Color) -> void:
	map_id = next_map_id
	fallback_spawn = next_fallback_spawn
	background_color = next_background_color
	obstacle_color = next_obstacle_color

func _ready() -> void:
	dialogue_system.set_repository(DataRepository)
	_load_map_data()
	_create_terrain()
	_create_player()
	_create_camera()
	_create_ui()
	_spawn_objects()
	_update_quest_text()

func _process(_delta: float) -> void:
	_update_nearest_interactable()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		_toggle_inventory()
	elif event.is_action_pressed("cancel"):
		var success = GameState.save_to_path("user://save_01.json")
		hud.show_message("存档成功。" if success else "存档失败。")

func _load_map_data() -> void:
	map_data = DataRepository.get_map(map_id)
	if map_data.is_empty():
		push_error("无法读取地图配置：%s" % map_id)
		map_data = {
			"id": map_id,
			"spawn_position": {"x": fallback_spawn.x, "y": fallback_spawn.y},
			"objects": [],
		}

func _create_terrain() -> void:
	_add_background(Vector2(1280, 720))

func _add_background(size: Vector2) -> void:
	var terrain = TileMapLayer.new()
	terrain.name = "Terrain"
	add_child(terrain)

	var background = ColorRect.new()
	background.color = background_color
	background.size = size
	background.position = Vector2.ZERO
	add_child(background)
	move_child(background, 0)

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
	visual.color = obstacle_color
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
	player.add_child(camera)
	camera.make_current()

func _create_ui() -> void:
	hud = HudScript.new()
	hud.item_use_requested.connect(_on_item_use_requested)
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

func _interact_with(_interactable) -> void:
	pass

func _transition_to_exit(record: Dictionary) -> void:
	var target_map_id = str(record.get("target_map_id", ""))
	var target_map = DataRepository.get_map(target_map_id)
	var result = transition_system.resolve_transition(record, target_map)
	if not bool(result.get("success", false)):
		hud.show_message(str(result.get("message", "前路尚未开放。")))
		return

	GameState.set_current_map(str(result.get("map_id", "")), result.get("position", fallback_spawn))
	SceneLoader.change_scene(GameState.get_current_map_scene_path())

func _open_dialogue(dialogue_id: String, fallback_text: String = "此人暂时无话可说。") -> void:
	var lines = dialogue_system.get_lines(dialogue_id)
	if lines.is_empty():
		lines = [{"speaker": "旁白", "text": fallback_text}]
	dialogue_box.open(lines)

func _toggle_inventory() -> void:
	hud.toggle_inventory(_build_inventory_items())

func _build_inventory_items() -> Array:
	var items: Array = []
	for raw_item_id in GameState.party.inventory.keys():
		var item_id = str(raw_item_id)
		var quantity = GameState.party.get_item_count(item_id)
		if quantity <= 0:
			continue
		var item_data = DataRepository.get_item(item_id)
		if item_data.is_empty():
			items.append({
				"id": item_id,
				"name": "未知物品",
				"type": "unknown",
				"description": "此物品资料缺失。",
				"quantity": quantity,
				"usable": false,
			})
		else:
			items.append({
				"id": item_id,
				"name": str(item_data.get("name", "未知物品")),
				"type": str(item_data.get("type", "unknown")),
				"description": str(item_data.get("description", "")),
				"quantity": quantity,
				"usable": str(item_data.get("type", "")) == "consumable",
			})
	return items

func _refresh_inventory_if_open() -> void:
	if hud.is_inventory_open():
		hud.refresh_inventory(_build_inventory_items())

func _on_item_use_requested(item_id: String) -> void:
	var result = inventory_system.use_item(GameState, item_id)
	hud.show_message(str(result.get("message", "此物暂时不能使用。")))
	_refresh_inventory_if_open()

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
	pass

func _read_spawn_position() -> Vector2:
	if GameState.map_state.current_map_id == map_id:
		return GameState.map_state.player_position
	return fallback_spawn
```

- [ ] **Step 2: 运行项目加载测试**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
```

Expected: PASS，无解析错误，进程退出码为 `0`。

- [ ] **Step 3: 运行逻辑测试**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过：10 个测试套件`。

- [ ] **Step 4: 手动验收地图背包**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --path .
```

Manual checks:

```text
1. 从主菜单开始新游戏。
2. 进入山道后按 I，背包面板打开。
3. 背包显示“小还丹 x1 [consumable]”和描述。
4. 再按 I，背包面板关闭。
5. 气血满时点击“小还丹”的使用按钮，消息显示“气血已满。”，数量仍为 1。
6. 完成山道试剑后获得额外小还丹，背包显示数量增加。
7. 进入山脚村镇后按 I，同一背包面板可打开。
```

- [ ] **Step 5: 提交地图背包接线**

```powershell
git add scripts/scenes/map_screen_base.gd
git commit -m "feat: 接入地图背包使用"
```

---

### Task 6: 更新文档并做最终验证

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
```

- [ ] **Step 2: 更新 `docs/godot-project-structure.md`**

In `docs/godot-project-structure.md`, add this section after `## 山脚村镇切片`:

```markdown
## 轻量背包切片

轻量背包切片使用 `I` 键在地图中打开背包面板。背包数量保存在 `GameState.party.inventory`，物品资料来自 `data/items.json`，物品使用规则由 `InventorySystem` 处理。HUD 只负责显示背包列表和发出使用请求，不直接修改背包数量或气血。
```

Also update the `scripts/systems/` layer bullet near the top to:

```markdown
- `scripts/systems/`：放可测试的游戏流程，例如数据、地图对象、地图切换、交互、任务、对话、战斗、背包和存档。
```

- [ ] **Step 3: 运行最终逻辑测试**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过：10 个测试套件`。

- [ ] **Step 4: 运行项目加载验证**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
```

Expected: PASS，无解析错误，进程退出码为 `0`。

- [ ] **Step 5: 提交文档更新**

```powershell
git add README.md docs/godot-project-structure.md
git commit -m "docs: 更新轻量背包说明"
```

- [ ] **Step 6: 检查 git 状态**

Run:

```powershell
git status --short
```

Expected: only unrelated pre-existing files may remain, especially untracked `.spec-workflow/`. There should be no unstaged changes from this inventory slice after the final commit.

## 最终验收

完成所有任务后，按以下顺序验收：

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
git log --oneline -n 6
git status --short
```

期望结果：

- 测试输出 `测试通过：10 个测试套件`。
- 项目加载命令退出码为 `0`。
- 最近提交包含本计划中的 6 个提交。
- 工作区没有本切片遗留的未提交修改。
- `.spec-workflow/` 如果仍是未跟踪状态，保持不动。

## 计划自检

- Spec 覆盖：本计划覆盖 `I` 键背包、物品显示、消耗品使用、小还丹效果、数量扣除、气血恢复、存档读档、未知物品、非消耗品、气血已满、空背包提示和文档更新。
- 范围控制：本计划不实现装备、商店、排序分类、拖拽、多角色选择、战斗中使用物品或复杂角色面板。
- 类型一致性：`PartyState.get_item_count()`、`PartyState.has_item()`、`PartyState.remove_item()`、`GameState.restore_hero_hp()`、`GameState.is_hero_hp_full()`、`InventorySystem.use_item()`、`Hud.item_use_requested` 和 `MapScreenBase._build_inventory_items()` 在定义和调用中名称一致。
