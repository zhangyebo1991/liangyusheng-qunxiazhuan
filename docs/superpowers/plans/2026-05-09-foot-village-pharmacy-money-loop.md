# 山脚村镇药铺与铜钱补给切片 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在山脚村镇加入药铺和铜钱消费闭环，让玩家用初始铜钱购买小还丹，并通过存档恢复铜钱和背包数量。

**Architecture:** 沿用现有“领域逻辑、系统流程、场景表现”分层。`PartyState` 保存铜钱，新增 `ShopSystem` 作为购买规则唯一入口，HUD 只展示商店并发出购买意图，`map_screen_base.gd` 负责把地图对象、商店系统、HUD 和背包刷新接起来。第一版商品直接配置在 `data/maps.json` 的药铺对象上，不新增独立商店数据文件。

**Tech Stack:** Godot 4.6、GDScript、JSON 数据文件、Godot 无头脚本测试、PowerShell 验证命令。

---

## 范围检查

本计划实现 `docs/superpowers/specs/2026-05-09-foot-village-pharmacy-money-loop-design.md`。范围只包含铜钱字段、初始铜钱、山脚村镇药铺对象、购买小还丹、商店 HUD 面板、购买结果刷新、铜钱和背包存档恢复。不包含卖出、库存、砍价、装备购买、战斗掉钱、任务铜钱奖励或正式菜单美术。

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

当前测试套件里地图切换负例会打印预期错误日志，只要最终退出码为 `0` 且输出 `测试通过` 即可。

## 文件结构

```text
data/maps.json                                # 在 foot_village.objects 增加药铺对象和商品列表
scripts/core/game_state.gd                    # 新游戏给 80 铜钱，继续通过 party 字段存档
scripts/domain/party_state.gd                 # 增加 coins、加钱、检查余额、扣钱、序列化恢复
scripts/scenes/foot_village_screen.gd         # shop 类型交互转发给通用 _open_shop
scripts/scenes/hud.gd                         # 增加商店面板、铜钱显示、购买按钮和 shop_buy_requested 信号
scripts/scenes/map_interactable.gd            # shop 类型提示和调试颜色
scripts/scenes/map_screen_base.gd             # 持有 ShopSystem，构建商品列表，处理购买和面板刷新
scripts/systems/shop_system.gd                # 新增购买校验、扣钱、加物品和结果字典
tests/run_tests.gd                            # 接入新增 ShopSystem 和地图商店接线测试
tests/test_domain_models.gd                   # 覆盖 PartyState 铜钱规则
tests/test_hud_inventory.gd                   # 覆盖 HUD 商店显示和购买信号
tests/test_interaction_system.gd              # 覆盖 shop 交互提示
tests/test_map_data.gd                        # 覆盖 foot_village 药铺对象和商品列表
tests/test_save_map_state.gd                  # 覆盖新游戏铜钱和存档恢复
tests/test_shop_map_screen.gd                 # 覆盖 MapScreenBase 商品列表和购买接线
tests/test_shop_system.gd                     # 覆盖购买成功、连续购买、余额不足和商品无效
```

---

### Task 1: PartyState 铜钱领域模型

**Files:**
- Modify: `tests/test_domain_models.gd`
- Modify: `scripts/domain/party_state.gd`

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

	assertions.assert_eq(party.coins, 0, "队伍默认铜钱应为 0")
	assertions.assert_true(not party.can_afford(0), "金额为 0 时不应视为可支付")
	assertions.assert_true(not party.can_afford(-1), "负数金额不应视为可支付")
	party.add_coins(80)
	party.add_coins(0)
	party.add_coins(-10)
	assertions.assert_eq(party.coins, 80, "队伍应能增加有效铜钱")
	assertions.assert_true(party.can_afford(30), "余额足够时应可支付")
	assertions.assert_true(party.spend_coins(30), "余额足够时应能扣钱")
	assertions.assert_eq(party.coins, 50, "扣钱后余额应减少")
	assertions.assert_true(not party.spend_coins(100), "余额不足时扣钱应失败")
	assertions.assert_eq(party.coins, 50, "扣钱失败后余额应保持")

	var serialized_party = party.to_dictionary()
	assertions.assert_eq(serialized_party.get("coins", -1), 50, "队伍序列化应保存铜钱")

	var restored_party = PartyStateScript.new()
	restored_party.from_dictionary(serialized_party)
	assertions.assert_eq(restored_party.coins, 50, "队伍反序列化应恢复铜钱")

	var old_save_party = PartyStateScript.new()
	old_save_party.from_dictionary({"members": ["hero_yun"], "inventory": {"herb_small": 1}})
	assertions.assert_eq(old_save_party.coins, 0, "旧存档缺少铜钱时应为 0")

	var invalid_coin_party = PartyStateScript.new()
	invalid_coin_party.from_dictionary({"members": ["hero_yun"], "inventory": {}, "coins": -5})
	assertions.assert_eq(invalid_coin_party.coins, 0, "读档铜钱小于 0 时应钳制")
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL，错误包含 `coins` 属性不存在或铜钱断言失败。

- [ ] **Step 3: 实现 `scripts/domain/party_state.gd`**

Replace `scripts/domain/party_state.gd` with:

```gdscript
class_name PartyState
extends RefCounted

var members: Array[String] = []
var inventory: Dictionary = {}
var coins := 0

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

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount

func can_afford(amount: int) -> bool:
	if amount <= 0:
		return false
	return coins >= amount

func spend_coins(amount: int) -> bool:
	if not can_afford(amount):
		return false
	coins -= amount
	return true

func to_dictionary() -> Dictionary:
	return {
		"members": members.duplicate(),
		"inventory": inventory.duplicate(true),
		"coins": coins,
	}

func from_dictionary(data: Dictionary) -> void:
	members = _to_string_array(data.get("members", []))
	inventory = {}
	coins = max(0, int(data.get("coins", 0)))
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

- [ ] **Step 4: 运行测试确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过`。

- [ ] **Step 5: 提交**

```powershell
git add tests/test_domain_models.gd scripts/domain/party_state.gd
git commit -m "feat: add party coin state"
```

---

### Task 2: 新游戏初始铜钱和存档恢复

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
	assertions.assert_eq(state.party.coins, 80, "新游戏初始铜钱应为 80")
	assertions.assert_true(state.party.spend_coins(30), "测试存档前应能消费铜钱")
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
	assertions.assert_eq(restored.party.coins, 50, "读档应恢复铜钱余额")
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
	assertions.assert_eq(old_save_state.party.coins, 0, "旧存档缺少铜钱时应回退为 0")
	assertions.assert_eq(old_save_state.get_martial_proficiency("basic_sword"), 0, "旧存档缺少熟练度时应回退为 0")

	var invalid_hp_state = GameStateScript.new()
	invalid_hp_state.from_dictionary({
		"party": {"members": ["hero_yun"], "coins": -5},
		"quests": {},
		"map_state": {},
		"flags": {},
		"hero_hp": 999,
		"hero_max_hp": 100,
		"martial_proficiency": {"basic_sword": -5}
	})
	assertions.assert_eq(invalid_hp_state.hero_hp, 100, "读档气血大于最大值时应钳制")
	assertions.assert_eq(invalid_hp_state.party.coins, 0, "读档铜钱小于 0 时应钳制")
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
	assertions.assert_eq(restored_village.party.coins, 80, "村镇存档应恢复新游戏初始铜钱")

	state.free()
	restored.free()
	old_save_state.free()
	invalid_hp_state.free()
	village_state.free()
	restored_village.free()
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL，新游戏初始铜钱仍为 `0`。

- [ ] **Step 3: 实现 `scripts/core/game_state.gd`**

Replace `scripts/core/game_state.gd` with:

```gdscript
extends Node

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const QuestSystemScript = preload("res://scripts/systems/quest_system.gd")
const MapStateScript = preload("res://scripts/domain/map_state.gd")
const SaveSystemScript = preload("res://scripts/systems/save_system.gd")

const DEFAULT_HERO_MAX_HP := 120
const STARTING_COINS := 80

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
	party.add_coins(STARTING_COINS)
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

- [ ] **Step 4: 运行测试确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过`。

- [ ] **Step 5: 提交**

```powershell
git add tests/test_save_map_state.gd scripts/core/game_state.gd
git commit -m "feat: seed starting coins"
```

---

### Task 3: ShopSystem 购买规则

**Files:**
- Create: `tests/test_shop_system.gd`
- Create: `scripts/systems/shop_system.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 写失败测试并接入测试运行器**

Create `tests/test_shop_system.gd` with:

```gdscript
extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const ShopSystemScript = preload("res://scripts/systems/shop_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()

	var system = ShopSystemScript.new()
	system.set_repository(repository)

	var state = GameStateScript.new()
	state.start_new_game()
	var start_count = state.party.get_item_count("herb_small")
	var success = system.buy_item(state, "herb_small")
	assertions.assert_true(bool(success.get("success", false)), "铜钱足够时应能购买小还丹")
	assertions.assert_eq(success.get("message", ""), "买入小还丹。", "购买成功应返回中文提示")
	assertions.assert_eq(success.get("cost", -1), 30, "购买结果应返回花费")
	assertions.assert_eq(success.get("coins", -1), 50, "购买结果应返回剩余铜钱")
	assertions.assert_eq(success.get("remaining", -1), start_count + 1, "购买结果应返回背包剩余数量")
	assertions.assert_eq(state.party.coins, 50, "购买后应扣除铜钱")
	assertions.assert_eq(state.party.get_item_count("herb_small"), start_count + 1, "购买后应增加物品")

	var chain_state = GameStateScript.new()
	chain_state.start_new_game()
	var chain_start_count = chain_state.party.get_item_count("herb_small")
	system.buy_item(chain_state, "herb_small")
	system.buy_item(chain_state, "herb_small")
	assertions.assert_eq(chain_state.party.coins, 20, "连续购买两次后应剩余 20 铜钱")
	assertions.assert_eq(chain_state.party.get_item_count("herb_small"), chain_start_count + 2, "连续购买两次应增加两个小还丹")

	var before_third_count = chain_state.party.get_item_count("herb_small")
	var insufficient = system.buy_item(chain_state, "herb_small")
	assertions.assert_true(not bool(insufficient.get("success", true)), "铜钱不足时购买应失败")
	assertions.assert_eq(insufficient.get("message", ""), "铜钱不足。", "铜钱不足应返回提示")
	assertions.assert_eq(chain_state.party.coins, 20, "铜钱不足时不应扣钱")
	assertions.assert_eq(chain_state.party.get_item_count("herb_small"), before_third_count, "铜钱不足时不应增加物品")

	var missing_state = GameStateScript.new()
	missing_state.start_new_game()
	var missing = system.buy_item(missing_state, "missing_item")
	assertions.assert_true(not bool(missing.get("success", true)), "商品资料缺失时购买应失败")
	assertions.assert_eq(missing.get("message", ""), "此商品暂时不能购买。", "商品资料缺失应返回提示")
	assertions.assert_eq(missing_state.party.coins, 80, "商品资料缺失时不应扣钱")
	assertions.assert_eq(missing_state.party.get_item_count("missing_item"), 0, "商品资料缺失时不应增加物品")

	repository.content["items"].append({
		"id": "invalid_price_pill",
		"name": "无价丹",
		"type": "consumable",
		"description": "价格配置错误的丹药。",
		"value": 0,
		"effects": {"heal_hp": 30},
	})
	var invalid_price_state = GameStateScript.new()
	invalid_price_state.start_new_game()
	var invalid_price = system.buy_item(invalid_price_state, "invalid_price_pill")
	assertions.assert_true(not bool(invalid_price.get("success", true)), "价格无效时购买应失败")
	assertions.assert_eq(invalid_price.get("message", ""), "此商品暂时不能购买。", "价格无效应返回提示")
	assertions.assert_eq(invalid_price_state.party.coins, 80, "价格无效时不应扣钱")
	assertions.assert_eq(invalid_price_state.party.get_item_count("invalid_price_pill"), 0, "价格无效时不应增加物品")

	var invalid_quantity_state = GameStateScript.new()
	invalid_quantity_state.start_new_game()
	var invalid_quantity = system.buy_item(invalid_quantity_state, "herb_small", 0)
	assertions.assert_true(not bool(invalid_quantity.get("success", true)), "数量无效时购买应失败")
	assertions.assert_eq(invalid_quantity.get("message", ""), "此商品暂时不能购买。", "数量无效应返回提示")
	assertions.assert_eq(invalid_quantity_state.party.coins, 80, "数量无效时不应扣钱")

	state.free()
	chain_state.free()
	missing_state.free()
	invalid_price_state.free()
	invalid_quantity_state.free()
	repository.free()
```

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
const TestShopSystemScript = preload("res://tests/test_shop_system.gd")
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
		TestShopSystemScript.new(),
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

- [ ] **Step 2: 运行测试确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL，错误包含 `scripts/systems/shop_system.gd` 无法预加载。

- [ ] **Step 3: 实现 `scripts/systems/shop_system.gd`**

Create `scripts/systems/shop_system.gd` with:

```gdscript
extends RefCounted

const MESSAGE_INVALID_ITEM := "此商品暂时不能购买。"
const MESSAGE_INSUFFICIENT_COINS := "铜钱不足。"

var repository = null

func set_repository(next_repository) -> void:
	repository = next_repository

func buy_item(game_state, item_id: String, quantity: int = 1) -> Dictionary:
	var normalized_item_id = str(item_id)
	var normalized_quantity = int(quantity)
	if game_state == null or game_state.party == null:
		return _failure(normalized_item_id, MESSAGE_INVALID_ITEM, max(0, normalized_quantity), 0, 0, 0)
	if normalized_item_id.is_empty() or normalized_quantity <= 0:
		return _failure(
			normalized_item_id,
			MESSAGE_INVALID_ITEM,
			max(0, normalized_quantity),
			0,
			game_state.party.coins,
			game_state.party.get_item_count(normalized_item_id)
		)

	var item_repository = _get_repository()
	if item_repository == null:
		return _failure(
			normalized_item_id,
			MESSAGE_INVALID_ITEM,
			normalized_quantity,
			0,
			game_state.party.coins,
			game_state.party.get_item_count(normalized_item_id)
		)
	var item_data = item_repository.get_item(normalized_item_id)
	if item_data.is_empty():
		return _failure(
			normalized_item_id,
			MESSAGE_INVALID_ITEM,
			normalized_quantity,
			0,
			game_state.party.coins,
			game_state.party.get_item_count(normalized_item_id)
		)

	var price = int(item_data.get("value", 0))
	if price <= 0:
		return _failure(
			normalized_item_id,
			MESSAGE_INVALID_ITEM,
			normalized_quantity,
			0,
			game_state.party.coins,
			game_state.party.get_item_count(normalized_item_id)
		)

	var cost = price * normalized_quantity
	if not game_state.party.can_afford(cost):
		return _failure(
			normalized_item_id,
			MESSAGE_INSUFFICIENT_COINS,
			normalized_quantity,
			cost,
			game_state.party.coins,
			game_state.party.get_item_count(normalized_item_id)
		)
	if not game_state.party.spend_coins(cost):
		return _failure(
			normalized_item_id,
			MESSAGE_INSUFFICIENT_COINS,
			normalized_quantity,
			cost,
			game_state.party.coins,
			game_state.party.get_item_count(normalized_item_id)
		)

	game_state.party.add_item(normalized_item_id, normalized_quantity)
	return {
		"success": true,
		"message": "买入%s。" % str(item_data.get("name", "商品")),
		"item_id": normalized_item_id,
		"quantity": normalized_quantity,
		"cost": cost,
		"coins": game_state.party.coins,
		"remaining": game_state.party.get_item_count(normalized_item_id),
	}

func _failure(item_id: String, message: String, quantity: int, cost: int, coins: int, remaining: int) -> Dictionary:
	return {
		"success": false,
		"message": message,
		"item_id": item_id,
		"quantity": quantity,
		"cost": cost,
		"coins": coins,
		"remaining": remaining,
	}

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

- [ ] **Step 4: 运行测试确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过：15 个测试套件`。

- [ ] **Step 5: 提交**

```powershell
git add tests/test_shop_system.gd tests/run_tests.gd scripts/systems/shop_system.gd
git commit -m "feat: add shop purchase system"
```

---

### Task 4: 山脚村镇药铺对象和交互提示

**Files:**
- Modify: `tests/test_map_data.gd`
- Modify: `tests/test_interaction_system.gd`
- Modify: `data/maps.json`
- Modify: `scripts/scenes/map_interactable.gd`

- [ ] **Step 1: 写失败测试**

Replace `tests/test_map_data.gd` with:

```gdscript
extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	var content = repository.load_all()

	assertions.assert_eq(content.get("maps", []).size(), 2, "应加载 2 张示例地图")

	var mountain = repository.get_map("mountain_pass")
	assertions.assert_eq(mountain.get("name", ""), "山道", "应按编号读取山道地图")
	assertions.assert_eq(mountain.get("spawn_position", {}).get("x", 0), 160, "山道出生点横坐标应正确")
	assertions.assert_true(mountain.get("spawn_points", {}).has("return_from_village"), "山道应包含村镇返回出生点")
	assertions.assert_eq(_find_object(mountain, "exit_to_foot_village").get("target_map_id", ""), "foot_village", "山道出口应指向山脚村镇")

	var village = repository.get_map("foot_village")
	assertions.assert_eq(village.get("name", ""), "山脚村镇", "应按编号读取山脚村镇")
	assertions.assert_eq(village.get("spawn_position", {}).get("x", 0), 120, "村镇默认出生点横坐标应正确")
	assertions.assert_true(village.get("spawn_points", {}).has("village_gate"), "村镇应包含村口出生点")
	assertions.assert_eq(_find_object(village, "npc_innkeeper_lu").get("actor_id", ""), "innkeeper_lu", "村镇应配置客栈掌柜")
	assertions.assert_eq(_find_object(village, "npc_porter_chen").get("actor_id", ""), "porter_chen", "村镇应配置村口脚夫")
	assertions.assert_eq(_find_object(village, "notice_foot_village").get("type", ""), "notice", "村镇应配置告示牌")
	assertions.assert_eq(_find_object(village, "exit_to_mountain_pass").get("target_map_id", ""), "mountain_pass", "村镇应能返回山道")

	var pharmacy = _find_object(village, "shop_foot_village_pharmacy")
	assertions.assert_eq(pharmacy.get("type", ""), "shop", "村镇应配置药铺对象")
	assertions.assert_eq(pharmacy.get("name", ""), "药铺", "药铺对象应显示中文名称")
	assertions.assert_eq(pharmacy.get("shop_id", ""), "foot_village_pharmacy", "药铺对象应保存商店编号")
	assertions.assert_eq(pharmacy.get("items", []).size(), 1, "药铺第一版只应配置一个商品")
	assertions.assert_eq(pharmacy.get("items", [])[0], "herb_small", "药铺第一版应出售小还丹")

	assertions.assert_eq(_find_object(village, "exit_to_open_road").get("locked_message", ""), "前路尚未开放。", "未开放出口应有提示")
	assertions.assert_eq(repository.get_quest("quest_deliver_letter").get("title", ""), "送信到客栈", "应读取送信任务")
	assertions.assert_eq(repository.get_dialogue("deliver_letter_complete").get("title", ""), "书信送达", "应读取送信完成对白")
	assertions.assert_eq(repository.get_map("missing_map"), {}, "缺失地图编号应返回空字典")

	repository.free()

func _find_object(map_data: Dictionary, object_id: String) -> Dictionary:
	for object in map_data.get("objects", []):
		if object.get("id", "") == object_id:
			return object
	return {}
```

Replace `tests/test_interaction_system.gd` with:

```gdscript
extends RefCounted

const InteractionSystemScript = preload("res://scripts/systems/interaction_system.gd")
const MapObjectSpawnerScript = preload("res://scripts/systems/map_object_spawner.gd")
const MapInteractableScript = preload("res://scripts/scenes/map_interactable.gd")

func run(assertions) -> void:
	var interaction_system = InteractionSystemScript.new()
	var objects = [
		{"id": "npc_qingshanke", "position": Vector2(100, 100), "radius": 64},
		{"id": "enemy_bandit_gate", "position": Vector2(260, 100), "radius": 48},
	]

	var nearby = interaction_system.find_nearest_in_range(Vector2(120, 100), objects)
	assertions.assert_eq(nearby.get("id", ""), "npc_qingshanke", "应找到范围内最近对象")

	var far = interaction_system.find_nearest_in_range(Vector2(500, 500), objects)
	assertions.assert_eq(far, {}, "远离对象时应返回空字典")

	assertions.assert_true(interaction_system.is_click_in_object(Vector2(110, 100), objects[0]), "鼠标点击对象范围内应命中")
	assertions.assert_true(not interaction_system.is_click_in_object(Vector2(220, 100), objects[0]), "鼠标点击对象范围外不应命中")

	var spawner = MapObjectSpawnerScript.new()
	var records = spawner.get_spawn_records({
		"objects": [
			{"id": "npc_qingshanke", "type": "npc", "position": {"x": 360, "y": 280}},
			{"id": "enemy_bandit_gate", "type": "battle_trigger", "position": {"x": 720, "y": 260}}
		]
	}, ["enemy_bandit_gate"])

	assertions.assert_eq(records.size(), 1, "已解决对象不应进入生成列表")
	assertions.assert_eq(records[0].get("id", ""), "npc_qingshanke", "未解决 NPC 应进入生成列表")

	var shop_interactable = MapInteractableScript.new()
	shop_interactable.setup({
		"id": "shop_foot_village_pharmacy",
		"type": "shop",
		"name": "药铺",
		"position": {"x": 980, "y": 320},
		"radius": 72,
	})
	assertions.assert_eq(shop_interactable.get_interaction_text(), "按 E 查看药铺", "药铺应显示查看提示")
	shop_interactable.free()
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL，药铺对象缺失，或 `shop` 类型提示仍为通用交互文本。

- [ ] **Step 3: 更新地图数据和交互对象**

Replace `data/maps.json` with:

```json
[
  {
    "id": "mountain_pass",
    "name": "山道",
    "spawn_position": {"x": 160, "y": 320},
    "spawn_points": {
      "start": {"x": 160, "y": 320},
      "return_from_village": {"x": 1110, "y": 320}
    },
    "objects": [
      {
        "id": "npc_qingshanke",
        "type": "npc",
        "name": "青衫客",
        "actor_id": "qingshanke",
        "position": {"x": 360, "y": 280},
        "radius": 72,
        "dialogue_id": "mountain_pass_intro",
        "quest_id": "quest_mountain_trial"
      },
      {
        "id": "enemy_bandit_gate",
        "type": "battle_trigger",
        "name": "山道强人",
        "actor_id": "bandit_01",
        "position": {"x": 720, "y": 260},
        "radius": 56,
        "quest_id": "quest_mountain_trial"
      },
      {
        "id": "exit_to_foot_village",
        "type": "exit",
        "name": "山脚村镇",
        "position": {"x": 1160, "y": 320},
        "radius": 72,
        "target_map_id": "foot_village",
        "target_spawn_id": "village_gate",
        "locked_message": "前路尚未开放。"
      }
    ]
  },
  {
    "id": "foot_village",
    "name": "山脚村镇",
    "spawn_position": {"x": 120, "y": 360},
    "spawn_points": {
      "village_gate": {"x": 120, "y": 360},
      "return_from_mountain": {"x": 120, "y": 360},
      "main_street": {"x": 640, "y": 340}
    },
    "objects": [
      {
        "id": "exit_to_mountain_pass",
        "type": "exit",
        "name": "山道",
        "position": {"x": 64, "y": 360},
        "radius": 72,
        "target_map_id": "mountain_pass",
        "target_spawn_id": "return_from_village",
        "locked_message": "前路尚未开放。"
      },
      {
        "id": "npc_porter_chen",
        "type": "npc",
        "name": "陈脚夫",
        "actor_id": "porter_chen",
        "position": {"x": 300, "y": 340},
        "radius": 72,
        "dialogue_id": "foot_village_porter_intro",
        "quest_id": "quest_deliver_letter"
      },
      {
        "id": "notice_foot_village",
        "type": "notice",
        "name": "村口告示",
        "position": {"x": 520, "y": 260},
        "radius": 56,
        "dialogue_id": "foot_village_notice"
      },
      {
        "id": "npc_innkeeper_lu",
        "type": "npc",
        "name": "陆掌柜",
        "actor_id": "innkeeper_lu",
        "position": {"x": 760, "y": 320},
        "radius": 72,
        "dialogue_id": "foot_village_innkeeper_idle",
        "quest_id": "quest_deliver_letter"
      },
      {
        "id": "shop_foot_village_pharmacy",
        "type": "shop",
        "name": "药铺",
        "position": {"x": 980, "y": 320},
        "radius": 72,
        "shop_id": "foot_village_pharmacy",
        "items": ["herb_small"]
      },
      {
        "id": "exit_to_open_road",
        "type": "exit",
        "name": "村外官道",
        "position": {"x": 1180, "y": 360},
        "radius": 72,
        "target_map_id": "",
        "target_spawn_id": "",
        "locked_message": "前路尚未开放。"
      }
    ]
  }
]
```

Replace `scripts/scenes/map_interactable.gd` with:

```gdscript
extends Area2D

signal clicked(interactable)
signal player_entered(interactable)
signal player_exited(interactable)

var record: Dictionary = {}
var label: Label

func setup(next_record: Dictionary) -> void:
	record = next_record.duplicate(true)
	name = str(record.get("id", "MapInteractable"))
	global_position = _read_position(record.get("position", {}))

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = float(record.get("radius", 48.0))
	shape.shape = circle
	add_child(shape)

	var visual = ColorRect.new()
	visual.size = Vector2(24, 24)
	visual.position = Vector2(-12, -12)
	visual.color = _read_color()
	add_child(visual)

	label = Label.new()
	label.text = str(record.get("name", ""))
	label.position = Vector2(-32, -36)
	label.size = Vector2(96, 24)
	add_child(label)

	input_event.connect(_on_input_event)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func get_interaction_text() -> String:
	var display_name = str(record.get("name", "此处"))
	match str(record.get("type", "")):
		"npc":
			return "按 E 与%s交谈" % display_name
		"battle_trigger":
			return "按 E 挑战%s" % display_name
		"exit":
			return "按 E 前往%s" % display_name
		"notice":
			return "按 E 查看%s" % display_name
		"shop":
			return "按 E 查看%s" % display_name
		_:
			return "按 E 与%s交互" % display_name

func _read_color() -> Color:
	match str(record.get("type", "")):
		"npc":
			return Color("#8d3b7a")
		"battle_trigger":
			return Color("#8f3b2f")
		"exit":
			return Color("#2f6fdd")
		"notice":
			return Color("#c49a2c")
		"shop":
			return Color("#3d7f5c")
		_:
			return Color("#666666")

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)

func _on_body_entered(body: Node) -> void:
	if body.has_method("set_current_interactable"):
		player_entered.emit(self)

func _on_body_exited(body: Node) -> void:
	if body.has_method("set_current_interactable"):
		player_exited.emit(self)

func _read_position(value: Variant) -> Vector2:
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO
```

- [ ] **Step 4: 运行测试确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过：15 个测试套件`。

- [ ] **Step 5: 提交**

```powershell
git add tests/test_map_data.gd tests/test_interaction_system.gd data/maps.json scripts/scenes/map_interactable.gd
git commit -m "feat: add foot village pharmacy object"
```

---

### Task 5: HUD 商店面板

**Files:**
- Modify: `tests/test_hud_inventory.gd`
- Modify: `scripts/scenes/hud.gd`

- [ ] **Step 1: 写失败测试 `tests/test_hud_inventory.gd`**

Replace `tests/test_hud_inventory.gd` with:

```gdscript
extends RefCounted

const HudScript = preload("res://scripts/scenes/hud.gd")

func run(assertions) -> void:
	var hud = HudScript.new()
	hud._ready()

	hud.show_inventory([{
		"id": "herb_small",
		"name": "小还丹",
		"type": "consumable",
		"description": "少量恢复气血。",
		"quantity": 1,
		"usable": true,
	}])

	var inventory_row = hud.inventory_list.get_child(0)
	var inventory_header = inventory_row.get_child(0)
	assertions.assert_eq(inventory_header.text, "小还丹 x1", "背包物品标题不应显示内部类型")

	var requested_items: Array[String] = []
	hud.shop_buy_requested.connect(func(item_id: String): requested_items.append(item_id))
	hud.show_shop("药铺", 80, [{
		"id": "herb_small",
		"name": "小还丹",
		"description": "恢复少量气血。",
		"price": 30,
		"can_buy": true,
	}])

	assertions.assert_true(hud.is_shop_open(), "调用 show_shop 后商店面板应打开")
	assertions.assert_eq(hud.shop_title_label.text, "药铺", "商店标题应显示传入名称")
	assertions.assert_eq(hud.shop_coins_label.text, "铜钱：80", "商店应显示当前铜钱")

	var shop_row = hud.shop_list.get_child(0)
	var shop_header = shop_row.get_child(0)
	assertions.assert_eq(shop_header.text, "小还丹 30 文", "商品标题应显示名称和价格")

	var buy_button = shop_row.get_child(2)
	assertions.assert_eq(buy_button.text, "购买", "商品行应包含购买按钮")
	buy_button.pressed.emit()
	assertions.assert_eq(requested_items.size(), 1, "点击购买应发出购买信号")
	assertions.assert_eq(requested_items[0], "herb_small", "购买信号应携带商品编号")

	hud.refresh_shop(50, [])
	assertions.assert_eq(hud.shop_coins_label.text, "铜钱：50", "刷新商店应更新铜钱")
	assertions.assert_true(hud.shop_empty_label.visible, "空商品列表应显示空药铺提示")

	hud.hide_shop()
	assertions.assert_true(not hud.is_shop_open(), "调用 hide_shop 后商店面板应关闭")

	hud.free()
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL，HUD 缺少 `shop_buy_requested`、`show_shop` 或商店控件字段。

- [ ] **Step 3: 实现 `scripts/scenes/hud.gd`**

Replace `scripts/scenes/hud.gd` with:

```gdscript
extends CanvasLayer

signal item_use_requested(item_id: String)
signal shop_buy_requested(item_id: String)

var quest_label: Label
var prompt_label: Label
var message_label: Label
var inventory_panel: Panel
var inventory_list: VBoxContainer
var inventory_empty_label: Label
var inventory_is_open := false
var shop_panel: Panel
var shop_title_label: Label
var shop_coins_label: Label
var shop_list: VBoxContainer
var shop_empty_label: Label
var shop_is_open := false

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
	_create_shop_panel()

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

func show_shop(title: String, coins: int, items: Array) -> void:
	shop_is_open = true
	shop_panel.visible = true
	shop_title_label.text = title
	refresh_shop(coins, items)

func hide_shop() -> void:
	shop_is_open = false
	shop_panel.visible = false

func refresh_shop(coins: int, items: Array) -> void:
	shop_coins_label.text = "铜钱：%d" % coins
	for child in shop_list.get_children():
		child.queue_free()

	shop_empty_label.visible = items.is_empty()
	if items.is_empty():
		return

	for item in items:
		_add_shop_row(item)

func is_shop_open() -> bool:
	return shop_is_open

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

func _create_shop_panel() -> void:
	shop_panel = Panel.new()
	shop_panel.position = Vector2(260, 72)
	shop_panel.size = Vector2(460, 520)
	shop_panel.visible = false
	add_child(shop_panel)

	shop_title_label = Label.new()
	shop_title_label.text = "药铺"
	shop_title_label.position = Vector2(16, 14)
	shop_title_label.size = Vector2(160, 32)
	shop_panel.add_child(shop_title_label)

	var close_button = Button.new()
	close_button.text = "关闭"
	close_button.position = Vector2(368, 12)
	close_button.size = Vector2(72, 36)
	close_button.pressed.connect(hide_shop)
	shop_panel.add_child(close_button)

	shop_coins_label = Label.new()
	shop_coins_label.text = "铜钱：0"
	shop_coins_label.position = Vector2(16, 52)
	shop_coins_label.size = Vector2(220, 32)
	shop_panel.add_child(shop_coins_label)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(16, 96)
	scroll.size = Vector2(428, 386)
	shop_panel.add_child(scroll)

	shop_list = VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(shop_list)

	shop_empty_label = Label.new()
	shop_empty_label.text = "药铺暂时没有可买之物。"
	shop_empty_label.position = Vector2(32, 122)
	shop_empty_label.size = Vector2(360, 32)
	shop_empty_label.visible = false
	shop_panel.add_child(shop_empty_label)

func _add_inventory_row(item: Dictionary) -> void:
	var row = VBoxContainer.new()
	row.custom_minimum_size = Vector2(400, 104)
	inventory_list.add_child(row)

	var name = str(item.get("name", "未知物品"))
	var quantity = int(item.get("quantity", 0))

	var header = Label.new()
	header.text = "%s x%d" % [name, quantity]
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

func _add_shop_row(item: Dictionary) -> void:
	var row = VBoxContainer.new()
	row.custom_minimum_size = Vector2(400, 120)
	shop_list.add_child(row)

	var name = str(item.get("name", "未知商品"))
	var price = int(item.get("price", 0))

	var header = Label.new()
	header.text = "%s %d 文" % [name, price]
	header.size = Vector2(400, 24)
	row.add_child(header)

	var description = Label.new()
	description.text = str(item.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(400, 44)
	row.add_child(description)

	var buy_button = Button.new()
	buy_button.text = "购买"
	buy_button.disabled = not bool(item.get("can_buy", false))
	buy_button.custom_minimum_size = Vector2(72, 32)
	var item_id = str(item.get("id", ""))
	buy_button.pressed.connect(func(): shop_buy_requested.emit(item_id))
	row.add_child(buy_button)
```

- [ ] **Step 4: 运行测试确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过：15 个测试套件`。

- [ ] **Step 5: 提交**

```powershell
git add tests/test_hud_inventory.gd scripts/scenes/hud.gd
git commit -m "feat: add pharmacy shop hud"
```

---

### Task 6: 地图场景商店接线

**Files:**
- Create: `tests/test_shop_map_screen.gd`
- Modify: `tests/run_tests.gd`
- Modify: `scripts/scenes/map_screen_base.gd`
- Modify: `scripts/scenes/foot_village_screen.gd`

- [ ] **Step 1: 写失败测试并接入测试运行器**

Create `tests/test_shop_map_screen.gd` with:

```gdscript
extends RefCounted

const MapScreenBaseScript = preload("res://scripts/scenes/map_screen_base.gd")
const HudScript = preload("res://scripts/scenes/hud.gd")

func run(assertions) -> void:
	DataRepository.load_all()
	GameState.start_new_game()

	var screen = MapScreenBaseScript.new()
	var shop_record = {
		"id": "shop_foot_village_pharmacy",
		"type": "shop",
		"name": "药铺",
		"items": ["herb_small"]
	}
	var items = screen._build_shop_items(shop_record)
	assertions.assert_eq(items.size(), 1, "地图场景应能根据药铺对象构建商品列表")
	assertions.assert_eq(items[0].get("id", ""), "herb_small", "商品列表应保留物品编号")
	assertions.assert_eq(items[0].get("name", ""), "小还丹", "商品列表应显示物品名称")
	assertions.assert_eq(items[0].get("price", -1), 30, "商品列表应读取物品价格")
	assertions.assert_true(bool(items[0].get("can_buy", false)), "价格有效的商品应允许点击购买")

	var empty_items = screen._build_shop_items({"items": []})
	assertions.assert_eq(empty_items.size(), 0, "空药铺对象应返回空商品列表")

	var missing_items = screen._build_shop_items({"items": ["missing_item"]})
	assertions.assert_eq(missing_items.size(), 1, "缺失商品仍应返回不可购买行")
	assertions.assert_eq(missing_items[0].get("description", ""), "此商品暂时不能购买。", "缺失商品应显示不可购买说明")
	assertions.assert_true(not bool(missing_items[0].get("can_buy", true)), "缺失商品不应允许购买")

	screen.hud = HudScript.new()
	screen.hud._ready()
	screen.shop_system.set_repository(DataRepository)
	screen.current_shop_record = shop_record.duplicate(true)
	screen.hud.show_shop("药铺", GameState.party.coins, screen._build_shop_items(screen.current_shop_record))
	screen._on_shop_buy_requested("herb_small")
	assertions.assert_eq(GameState.party.coins, 50, "地图场景处理购买后应扣铜钱")
	assertions.assert_eq(GameState.party.get_item_count("herb_small"), 2, "地图场景处理购买后应加物品")
	assertions.assert_eq(screen.hud.message_label.text, "买入小还丹。", "地图场景购买后应显示系统返回消息")
	assertions.assert_eq(screen.hud.shop_coins_label.text, "铜钱：50", "地图场景购买后应刷新商店铜钱")

	screen.hud.free()
	screen.free()
```

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
const TestShopSystemScript = preload("res://tests/test_shop_system.gd")
const TestHudInventoryScript = preload("res://tests/test_hud_inventory.gd")
const TestShopMapScreenScript = preload("res://tests/test_shop_map_screen.gd")
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
		TestShopSystemScript.new(),
		TestHudInventoryScript.new(),
		TestShopMapScreenScript.new(),
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

- [ ] **Step 2: 运行测试确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL，`MapScreenBase` 缺少 `_build_shop_items`、`shop_system` 或商店购买处理方法。

- [ ] **Step 3: 实现 `scripts/scenes/map_screen_base.gd` 和 `scripts/scenes/foot_village_screen.gd`**

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
const ShopSystemScript = preload("res://scripts/systems/shop_system.gd")

var player
var hud
var dialogue_box
var dialogue_system = DialogueSystemScript.new()
var spawner = MapObjectSpawnerScript.new()
var transition_system = MapTransitionSystemScript.new()
var inventory_system = InventorySystemScript.new()
var shop_system = ShopSystemScript.new()
var current_shop_record: Dictionary = {}
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
	hud.shop_buy_requested.connect(_on_shop_buy_requested)
	add_child(hud)
	inventory_system.set_repository(DataRepository)
	shop_system.set_repository(DataRepository)
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

func _open_shop(record: Dictionary) -> void:
	current_shop_record = record.duplicate(true)
	var items = _build_shop_items(current_shop_record)
	hud.show_shop(str(current_shop_record.get("name", "药铺")), GameState.party.coins, items)
	if items.is_empty():
		hud.show_message("药铺暂时没有可买之物。")

func _build_shop_items(record: Dictionary) -> Array:
	var items: Array = []
	var raw_items = record.get("items", [])
	if typeof(raw_items) != TYPE_ARRAY:
		return items

	for raw_item_id in raw_items:
		var item_id = str(raw_item_id)
		if item_id.is_empty():
			continue
		var item_data = DataRepository.get_item(item_id)
		if item_data.is_empty():
			items.append({
				"id": item_id,
				"name": "未知商品",
				"description": "此商品暂时不能购买。",
				"price": 0,
				"can_buy": false,
			})
			continue

		var price = int(item_data.get("value", 0))
		items.append({
			"id": item_id,
			"name": str(item_data.get("name", "未知商品")),
			"description": str(item_data.get("description", "")),
			"price": price,
			"can_buy": price > 0,
		})
	return items

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

func _refresh_shop_if_open() -> void:
	if hud.is_shop_open():
		hud.refresh_shop(GameState.party.coins, _build_shop_items(current_shop_record))

func _on_item_use_requested(item_id: String) -> void:
	var result = inventory_system.use_item(GameState, item_id)
	hud.show_message(str(result.get("message", "此物暂时不能使用。")))
	_refresh_inventory_if_open()

func _on_shop_buy_requested(item_id: String) -> void:
	var result = shop_system.buy_item(GameState, item_id)
	hud.show_message(str(result.get("message", "此商品暂时不能购买。")))
	_refresh_shop_if_open()
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

Replace `scripts/scenes/foot_village_screen.gd` with:

```gdscript
extends "res://scripts/scenes/map_screen_base.gd"

func _ready() -> void:
	configure_map("foot_village", Vector2(120, 360), Color("#7f8f6a"), Color("#5f6246"))
	super._ready()

func _create_terrain() -> void:
	_add_background(Vector2(1280, 720))
	_add_obstacle(Rect2(0, 0, 1280, 24))
	_add_obstacle(Rect2(0, 696, 1280, 24))
	_add_obstacle(Rect2(0, 0, 24, 720))
	_add_obstacle(Rect2(1256, 0, 24, 720))
	_add_obstacle(Rect2(420, 120, 180, 110))
	_add_obstacle(Rect2(690, 110, 240, 130))
	_add_obstacle(Rect2(360, 500, 180, 100))
	_add_obstacle(Rect2(820, 500, 220, 100))

func _interact_with(interactable) -> void:
	if interactable == null:
		return
	match str(interactable.record.get("type", "")):
		"npc":
			_talk_to_npc(interactable.record)
		"notice":
			_read_notice(interactable.record)
		"exit":
			_transition_to_exit(interactable.record)
		"shop":
			_open_shop(interactable.record)

func _talk_to_npc(record: Dictionary) -> void:
	match str(record.get("actor_id", "")):
		"porter_chen":
			_talk_to_porter(record)
		"innkeeper_lu":
			_talk_to_innkeeper(record)
		_:
			_open_dialogue(str(record.get("dialogue_id", "")))

func _talk_to_porter(_record: Dictionary) -> void:
	var status = GameState.quest_system.get_status("quest_deliver_letter")
	if status == "not_started":
		GameState.quest_system.start_quest("quest_deliver_letter")
		_open_dialogue("foot_village_porter_intro")
		hud.show_message("任务开始：送信到客栈")
	elif status == "completed":
		_open_dialogue("foot_village_porter_after")
	else:
		_open_dialogue("foot_village_porter_reminder")
	_update_quest_text()

func _talk_to_innkeeper(_record: Dictionary) -> void:
	var status = GameState.quest_system.get_status("quest_deliver_letter")
	if status == "not_started":
		_open_dialogue("foot_village_innkeeper_idle")
		return
	if status == "active":
		GameState.quest_system.mark_ready_to_complete("quest_deliver_letter")
		GameState.quest_system.complete_quest("quest_deliver_letter")
		GameState.set_flag("clue_foot_village", "掌柜提到飞红巾踪迹")
		GameState.map_state.mark_reward_claimed("quest_deliver_letter")
		_open_dialogue("deliver_letter_complete")
		hud.show_message("获得线索：飞红巾踪迹")
	elif status == "ready_to_complete":
		GameState.quest_system.complete_quest("quest_deliver_letter")
		GameState.set_flag("clue_foot_village", "掌柜提到飞红巾踪迹")
		GameState.map_state.mark_reward_claimed("quest_deliver_letter")
		_open_dialogue("deliver_letter_complete")
		hud.show_message("获得线索：飞红巾踪迹")
	else:
		_open_dialogue("deliver_letter_after")
	_update_quest_text()

func _read_notice(record: Dictionary) -> void:
	_open_dialogue(str(record.get("dialogue_id", "")), "告示字迹模糊，暂时看不清。")

func _update_quest_text() -> void:
	var status = GameState.quest_system.get_status("quest_deliver_letter")
	if status == "active":
		hud.set_quest_text("送信到客栈：将书信交给客栈掌柜")
	elif status == "ready_to_complete":
		hud.set_quest_text("送信到客栈：与掌柜确认回信")
	elif status == "completed":
		hud.set_quest_text("送信到客栈：已完成")
	else:
		hud.set_quest_text("")
```

- [ ] **Step 4: 运行测试确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过：16 个测试套件`。

- [ ] **Step 5: 提交**

```powershell
git add tests/test_shop_map_screen.gd tests/run_tests.gd scripts/scenes/map_screen_base.gd scripts/scenes/foot_village_screen.gd
git commit -m "feat: wire pharmacy shop into map screen"
```

---

### Task 7: 完整验证和人工验收

**Files:**
- Verify: full project test suite
- Verify: Godot project load
- Verify: manual pharmacy flow

- [ ] **Step 1: 运行完整测试套件**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过：16 个测试套件`，进程退出码为 `0`。

- [ ] **Step 2: 验证项目可无头加载**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
```

Expected: PASS，无脚本解析错误，进程退出码为 `0`。

- [ ] **Step 3: 人工验收药铺流程**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --path .
```

Manual checks:

```text
1. 从主菜单开始新游戏。
2. 从山道进入山脚村镇。
3. 靠近药铺对象，提示显示“按 E 查看药铺”。
4. 按 E 打开药铺面板。
5. 面板显示标题“药铺”、铜钱“铜钱：80”、商品“小还丹 30 文”。
6. 点击“购买”，消息显示“买入小还丹。”，铜钱变为 50。
7. 再点击一次“购买”，铜钱变为 20。
8. 第三次点击“购买”，消息显示“铜钱不足。”，铜钱保持 20。
9. 按 I 打开背包，小还丹数量比新游戏初始数量多 2。
10. 按 Esc 存档，回主菜单继续游戏，铜钱 20 和小还丹数量保持。
```

- [ ] **Step 4: 检查工作区**

Run:

```powershell
git status --short
```

Expected: 只允许出现既有未跟踪目录 `.spec-workflow/`。如果还存在本切片代码改动，先确认对应任务是否已经提交。

## Self-Review

- Spec coverage: 计划覆盖 `PartyState.coins`、新游戏 `80` 铜钱、药铺地图对象、`ShopSystem`、HUD 商店面板、`MapScreenBase` 接线、`FootVillageScreen` shop 分支、`MapInteractable` 提示、存档恢复、成功购买、连续购买、余额不足、无效商品和人工验收流程。
- Placeholder scan: 未使用待填内容或空泛实现描述；每个代码修改步骤都给出完整目标内容。
- Type consistency: `coins`、`add_coins`、`can_afford`、`spend_coins`、`buy_item`、`show_shop`、`refresh_shop`、`is_shop_open`、`shop_buy_requested`、`_build_shop_items`、`_open_shop` 的名称在测试、实现和接线步骤中保持一致。
