# 队友与装备基础闭环 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立主角 + 队友 + 固定槽位装备的 RPG 基础闭环，让队友完整进入战棋，装备属性进入战斗，并随存档恢复。

**Architecture:** `PartyState` 保存队伍长期状态，`EquipmentSystem` 负责穿脱规则，`ActorStatsSystem` 合成角色模板、成员状态和装备加成。战棋创建时从 `party.members` 生成玩家单位，胜负回流时将每名队友 HP/MP 写回 `PartyState.member_status`。

**Tech Stack:** Godot 4.6、GDScript、项目自定义 `tests/run_tests.gd` headless 测试框架、JSON 数据表。

---

## File Structure（先锁边界）

### Create

- `scripts/systems/equipment_system.gd`：装备穿脱、槽位校验、数量占用、装备加成汇总。
- `scripts/systems/actor_stats_system.gd`：角色模板 + 成员状态 + 装备加成合成战斗属性。
- `tests/test_party_state.gd`：队伍装备、成员状态、旧存档兼容。
- `tests/test_equipment_system.gd`：装备规则测试。
- `tests/test_actor_stats_system.gd`：属性合成测试。
- `tests/test_tactical_party_battle.gd`：多人玩家单位入场和装备属性进入战棋。
- `tests/test_save_party_equipment.gd`：队友、装备、成员 HP/MP 存档恢复。
- `scripts/scenes/party_panel.gd`：最小队伍/装备面板。

### Modify

- `scripts/domain/party_state.gd`：新增 `equipment`、`member_status` 和 helper。
- `scripts/domain/item_record.gd`：读取 `equipment` 字段。
- `scripts/domain/actor_state.gd`：读取 `max_mp`、`move_range`、`attack_range`、`charge_speed`、`sprite_tile_id`。
- `scripts/core/game_state.gd`：新游戏初始化主角成员状态；战斗结果回写每名队友 HP/MP。
- `scripts/systems/effect_system.gd`：新增 `add_party_member` 效果。
- `scripts/systems/tactical_combat_system.gd`：从 `party.members` 生成玩家单位；敌人继续来自地图 context。
- `scripts/scenes/hud.gd`：接入队伍面板入口和刷新。
- `data/items.json`：铁剑转为装备，新增布衣、护符。
- `data/actors.json`：补战棋字段，青衫客作为可入队队友。
- `tests/run_tests.gd`：注册新增测试。

### Verification Command

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected on final state: `测试通过：62 个测试套件` or higher and `GodotExit:0` when run through PowerShell with `Write-Output "GodotExit:$LASTEXITCODE"`.

---

### Task 1: PartyState 装备与成员状态

**Files:**

- Create: `tests/test_party_state.gd`
- Modify: `scripts/domain/party_state.gd`
- Modify: `scripts/core/game_state.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 写失败测试 `tests/test_party_state.gd`**

Create the file with this content:

```gdscript
extends RefCounted

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")

func run(assertions) -> void:
    var party = PartyStateScript.new()
    party.add_member("hero_yun")
    party.add_member("hero_yun")
    assertions.assert_eq(party.members.size(), 1, "重复 add_member 不应重复入队")

    party.set_member_status("hero_yun", {"hp": 90, "mp": 7})
    assertions.assert_eq(party.get_member_status("hero_yun").get("hp", 0), 90, "应保存成员 HP")
    assertions.assert_eq(party.get_member_status("hero_yun").get("mp", 0), 7, "应保存成员 MP")

    party.add_item("iron_sword", 1)
    party.set_equipment("hero_yun", "weapon", "iron_sword")
    assertions.assert_eq(party.get_equipped_item("hero_yun", "weapon"), "iron_sword", "应读取装备槽物品")
    assertions.assert_eq(party.count_equipped_item("iron_sword"), 1, "应统计装备占用数量")
    party.clear_equipment("hero_yun", "weapon")
    assertions.assert_eq(party.get_equipped_item("hero_yun", "weapon"), "", "卸下装备后槽位应为空")

    var data = party.to_dictionary()
    var restored = PartyStateScript.new()
    restored.from_dictionary(data)
    assertions.assert_eq(restored.get_member_status("hero_yun").get("hp", 0), 90, "成员状态应可序列化恢复")
    assertions.assert_eq(restored.get_equipped_item("hero_yun", "weapon"), "", "空装备槽不应恢复出旧装备")

    var old_save = PartyStateScript.new()
    old_save.from_dictionary({"members": ["hero_yun"], "inventory": {"herb_small": 1}, "coins": 5})
    assertions.assert_eq(old_save.equipment.size(), 0, "旧存档缺 equipment 时应默认为空")
    assertions.assert_eq(old_save.member_status.size(), 0, "旧存档缺 member_status 时应默认为空")

    var state = GameStateScript.new()
    state.start_new_game()
    assertions.assert_true(state.party.has_member("hero_yun"), "新游戏应包含主角")
    assertions.assert_eq(state.party.get_member_status("hero_yun").get("hp", 0), state.hero_hp, "新游戏应初始化主角成员 HP")
    assertions.assert_eq(state.party.get_member_status("hero_yun").get("mp", 0), state.hero_cur_mp, "新游戏应初始化主角成员 MP")
    state.free()
```

- [ ] **Step 2: 注册测试并运行红灯**

Modify `tests/run_tests.gd`:

```gdscript
const TestPartyStateScript = preload("res://tests/test_party_state.gd")
```

Insert `TestPartyStateScript.new(),` in the `suites` array after `TestDomainModelsScript.new(),`.

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL because `PartyState` does not yet expose `equipment` / `member_status` helpers.

- [ ] **Step 3: 实现 PartyState**

Update `scripts/domain/party_state.gd` by adding fields near existing state:

```gdscript
var equipment: Dictionary = {}
var member_status: Dictionary = {}
```

Add these methods after `has_member`:

```gdscript
func set_member_status(actor_id: String, status: Dictionary) -> void:
    if actor_id.is_empty() or not has_member(actor_id):
        return
    var next_status: Dictionary = {}
    if status.has("hp"):
        next_status["hp"] = max(0, int(status.get("hp", 0)))
    if status.has("mp"):
        next_status["mp"] = max(0, int(status.get("mp", 0)))
    member_status[actor_id] = next_status

func get_member_status(actor_id: String) -> Dictionary:
    if actor_id.is_empty() or typeof(member_status.get(actor_id, {})) != TYPE_DICTIONARY:
        return {}
    return member_status.get(actor_id, {}).duplicate(true)

func set_equipment(actor_id: String, slot: String, item_id: String) -> void:
    if actor_id.is_empty() or slot.is_empty() or item_id.is_empty() or not has_member(actor_id):
        return
    var slots: Dictionary = equipment.get(actor_id, {}).duplicate(true) if typeof(equipment.get(actor_id, {})) == TYPE_DICTIONARY else {}
    slots[slot] = item_id
    equipment[actor_id] = slots

func clear_equipment(actor_id: String, slot: String) -> void:
    if actor_id.is_empty() or slot.is_empty() or typeof(equipment.get(actor_id, {})) != TYPE_DICTIONARY:
        return
    var slots: Dictionary = equipment.get(actor_id, {}).duplicate(true)
    slots.erase(slot)
    if slots.is_empty():
        equipment.erase(actor_id)
    else:
        equipment[actor_id] = slots

func get_equipped_item(actor_id: String, slot: String) -> String:
    if actor_id.is_empty() or slot.is_empty() or typeof(equipment.get(actor_id, {})) != TYPE_DICTIONARY:
        return ""
    return str(equipment.get(actor_id, {}).get(slot, ""))

func count_equipped_item(item_id: String) -> int:
    if item_id.is_empty():
        return 0
    var count := 0
    for actor_id in equipment.keys():
        var slots = equipment.get(actor_id, {})
        if typeof(slots) != TYPE_DICTIONARY:
            continue
        for slot in slots.keys():
            if str(slots[slot]) == item_id:
                count += 1
    return count
```

Extend `to_dictionary()`:

```gdscript
return {
    "members": members.duplicate(),
    "inventory": inventory.duplicate(true),
    "coins": coins,
    "equipment": equipment.duplicate(true),
    "member_status": member_status.duplicate(true),
}
```

Extend `from_dictionary(data)` after inventory loading:

```gdscript
equipment = _read_nested_string_dictionary(data.get("equipment", {}))
member_status = _read_member_status(data.get("member_status", {}))
```

Add helpers at the bottom:

```gdscript
func _read_nested_string_dictionary(value: Variant) -> Dictionary:
    var result: Dictionary = {}
    if typeof(value) != TYPE_DICTIONARY:
        return result
    for actor_id in value.keys():
        var raw_slots = value[actor_id]
        if typeof(raw_slots) != TYPE_DICTIONARY:
            continue
        var slots: Dictionary = {}
        for slot in raw_slots.keys():
            var normalized_slot = str(slot)
            var item_id = str(raw_slots[slot])
            if not normalized_slot.is_empty() and not item_id.is_empty():
                slots[normalized_slot] = item_id
        if not slots.is_empty():
            result[str(actor_id)] = slots
    return result

func _read_member_status(value: Variant) -> Dictionary:
    var result: Dictionary = {}
    if typeof(value) != TYPE_DICTIONARY:
        return result
    for actor_id in value.keys():
        var raw_status = value[actor_id]
        if typeof(raw_status) != TYPE_DICTIONARY:
            continue
        var status: Dictionary = {}
        if raw_status.has("hp"):
            status["hp"] = max(0, int(raw_status.get("hp", 0)))
        if raw_status.has("mp"):
            status["mp"] = max(0, int(raw_status.get("mp", 0)))
        result[str(actor_id)] = status
    return result
```

- [ ] **Step 4: 初始化主角成员状态**

In `scripts/core/game_state.gd`, add this line in `start_new_game()` after `hero_cur_mp = hero_max_mp`:

```gdscript
party.set_member_status("hero_yun", {"hp": hero_hp, "mp": hero_cur_mp})
```

- [ ] **Step 5: 跑测试并提交**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS, suite count increases by 1.

Commit:

```bash
git add scripts/domain/party_state.gd scripts/core/game_state.gd tests/run_tests.gd tests/test_party_state.gd
git commit -m "feat: add party equipment and member status state"
```

---

### Task 2: 装备数据与 EquipmentSystem

**Files:**

- Create: `scripts/systems/equipment_system.gd`
- Create: `tests/test_equipment_system.gd`
- Modify: `scripts/domain/item_record.gd`
- Modify: `data/items.json`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 写失败测试 `tests/test_equipment_system.gd`**

Create the file:

```gdscript
extends RefCounted

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const EquipmentSystemScript = preload("res://scripts/systems/equipment_system.gd")

class RepositoryStub:
    extends RefCounted
    var items: Dictionary = {
        "iron_sword": {"id": "iron_sword", "type": "equipment", "equipment": {"slot": "weapon", "stat_bonus": {"attack": 4}}},
        "cloth_armor": {"id": "cloth_armor", "type": "equipment", "equipment": {"slot": "armor", "stat_bonus": {"defense": 2}}},
        "herb_small": {"id": "herb_small", "type": "consumable", "effects": {"heal_hp": 30}}
    }

    func get_item(item_id: String) -> Dictionary:
        return items.get(item_id, {})

func run(assertions) -> void:
    var party = PartyStateScript.new()
    party.add_member("hero_yun")
    party.add_member("qingshanke")
    party.add_item("iron_sword", 1)
    party.add_item("cloth_armor", 1)
    party.add_item("herb_small", 1)

    var equipment = EquipmentSystemScript.new()
    var repo = RepositoryStub.new()

    var missing_actor = equipment.equip(party, "missing", "iron_sword", repo)
    assertions.assert_true(not bool(missing_actor.get("success", true)), "不能给非队伍成员装备")

    var consumable = equipment.equip(party, "hero_yun", "herb_small", repo)
    assertions.assert_true(not bool(consumable.get("success", true)), "消耗品不能装备")

    var equip_result = equipment.equip(party, "hero_yun", "iron_sword", repo)
    assertions.assert_true(bool(equip_result.get("success", false)), "主角应能装备铁剑")
    assertions.assert_eq(party.get_equipped_item("hero_yun", "weapon"), "iron_sword", "武器槽应记录铁剑")

    var occupied = equipment.equip(party, "qingshanke", "iron_sword", repo)
    assertions.assert_true(not bool(occupied.get("success", true)), "一把铁剑不能同时给两人装备")
    assertions.assert_eq(str(occupied.get("message", "")), "装备数量不足。", "数量不足应返回中文提示")

    var bonus = equipment.get_equipment_bonus(party, "hero_yun", repo)
    assertions.assert_eq(int(bonus.get("attack", 0)), 4, "铁剑应提供 attack +4")

    var armor = equipment.equip(party, "qingshanke", "cloth_armor", repo)
    assertions.assert_true(bool(armor.get("success", false)), "青衫客应能装备布衣")
    assertions.assert_eq(int(equipment.get_equipment_bonus(party, "qingshanke", repo).get("defense", 0)), 2, "布衣应提供 defense +2")

    var unequip = equipment.unequip(party, "hero_yun", "weapon")
    assertions.assert_true(bool(unequip.get("success", false)), "卸下武器应成功")
    assertions.assert_eq(party.get_equipped_item("hero_yun", "weapon"), "", "卸下后武器槽为空")
```

- [ ] **Step 2: 注册测试并运行红灯**

Add to `tests/run_tests.gd`:

```gdscript
const TestEquipmentSystemScript = preload("res://tests/test_equipment_system.gd")
```

Insert `TestEquipmentSystemScript.new(),` after `TestPartyStateScript.new(),`.

Run the verification command. Expected: FAIL because `equipment_system.gd` does not exist.

- [ ] **Step 3: 扩展 ItemRecord 与 items.json**

In `scripts/domain/item_record.gd`, add:

```gdscript
var equipment: Dictionary = {}
```

In `from_dictionary(data)`, add:

```gdscript
item.equipment = data.get("equipment", {}).duplicate(true) if typeof(data.get("equipment", {})) == TYPE_DICTIONARY else {}
```

Update `data/items.json` so `iron_sword` becomes equipment and add two entries:

```json
{
  "id": "iron_sword",
  "name": "铁剑",
  "type": "equipment",
  "description": "寻常江湖人常用的长剑。",
  "value": 120,
  "effects": {},
  "equipment": { "slot": "weapon", "stat_bonus": { "attack": 4 } }
},
{
  "id": "cloth_armor",
  "name": "布衣",
  "type": "equipment",
  "description": "粗布缝成的短衣，聊胜于无。",
  "value": 80,
  "effects": {},
  "equipment": { "slot": "armor", "stat_bonus": { "defense": 2 } }
},
{
  "id": "jade_talisman",
  "name": "青玉护符",
  "type": "equipment",
  "description": "温润青玉雕成的小护符，能略助凝神。",
  "value": 150,
  "effects": {},
  "equipment": { "slot": "accessory", "stat_bonus": { "max_mp": 5 } }
}
```

- [ ] **Step 4: 实现 EquipmentSystem**

Create `scripts/systems/equipment_system.gd`:

```gdscript
extends RefCounted

const VALID_SLOTS := ["weapon", "armor", "accessory"]

func can_equip(party, actor_id: String, item_id: String, repository) -> Dictionary:
    if party == null or not party.has_method("has_member") or not party.has_member(actor_id):
        return _failure("队伍成员不存在。")
    var item = _get_item(repository, item_id)
    if item.is_empty():
        return _failure("装备不存在。")
    var equipment = _equipment_data(item)
    var slot = str(equipment.get("slot", ""))
    if not VALID_SLOTS.has(slot):
        return _failure("物品不能装备。")
    if party.get_item_count(item_id) <= party.count_equipped_item(item_id) and party.get_equipped_item(actor_id, slot) != item_id:
        return _failure("装备数量不足。")
    return {"success": true, "slot": slot, "item_id": item_id}

func equip(party, actor_id: String, item_id: String, repository) -> Dictionary:
    var check = can_equip(party, actor_id, item_id, repository)
    if not bool(check.get("success", false)):
        return check
    party.set_equipment(actor_id, str(check.get("slot", "")), item_id)
    return {"success": true, "message": "装备成功。", "slot": str(check.get("slot", "")), "item_id": item_id}

func unequip(party, actor_id: String, slot: String) -> Dictionary:
    if party == null or not party.has_method("has_member") or not party.has_member(actor_id):
        return _failure("队伍成员不存在。")
    if not VALID_SLOTS.has(slot):
        return _failure("装备槽无效。")
    if party.get_equipped_item(actor_id, slot).is_empty():
        return _failure("装备槽为空。")
    party.clear_equipment(actor_id, slot)
    return {"success": true, "message": "已卸下装备。", "slot": slot}

func get_equipment_bonus(party, actor_id: String, repository) -> Dictionary:
    var result: Dictionary = {}
    if party == null or typeof(party.equipment.get(actor_id, {})) != TYPE_DICTIONARY:
        return result
    var slots: Dictionary = party.equipment.get(actor_id, {})
    for slot in slots.keys():
        var item = _get_item(repository, str(slots[slot]))
        var stat_bonus = _equipment_data(item).get("stat_bonus", {})
        if typeof(stat_bonus) != TYPE_DICTIONARY:
            continue
        for key in stat_bonus.keys():
            var stat = str(key)
            result[stat] = int(result.get(stat, 0)) + int(stat_bonus[key])
    return result

func _get_item(repository, item_id: String) -> Dictionary:
    if item_id.is_empty() or repository == null or not repository.has_method("get_item"):
        return {}
    var item = repository.get_item(item_id)
    return item if typeof(item) == TYPE_DICTIONARY else {}

func _equipment_data(item: Dictionary) -> Dictionary:
    var equipment = item.get("equipment", {})
    return equipment if typeof(equipment) == TYPE_DICTIONARY else {}

func _failure(message: String) -> Dictionary:
    return {"success": false, "message": message}
```

- [ ] **Step 5: 跑测试并提交**

Run the verification command. Expected: PASS.

Commit:

```bash
git add data/items.json scripts/domain/item_record.gd scripts/systems/equipment_system.gd tests/run_tests.gd tests/test_equipment_system.gd
git commit -m "feat: add fixed-slot equipment system"
```

---

### Task 3: ActorStatsSystem 属性合成

**Files:**

- Create: `scripts/systems/actor_stats_system.gd`
- Create: `tests/test_actor_stats_system.gd`
- Modify: `scripts/domain/actor_state.gd`
- Modify: `data/actors.json`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 写失败测试 `tests/test_actor_stats_system.gd`**

Create the file:

```gdscript
extends RefCounted

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const ActorStatsSystemScript = preload("res://scripts/systems/actor_stats_system.gd")

class RepositoryStub:
    extends RefCounted
    func get_actor(actor_id: String) -> Dictionary:
        if actor_id == "hero_yun":
            return {"id": "hero_yun", "name": "云游少侠", "hp": 120, "max_hp": 120, "max_mp": 20, "attack": 18, "defense": 8, "move_range": 3, "attack_range": 1, "charge_speed": 200, "martial_arts": ["basic_sword"], "sprite_tile_id": "tile_hero_yun_hd"}
        return {}

    func get_item(item_id: String) -> Dictionary:
        if item_id == "iron_sword":
            return {"id": "iron_sword", "type": "equipment", "equipment": {"slot": "weapon", "stat_bonus": {"attack": 4, "max_mp": 5}}}
        return {}

func run(assertions) -> void:
    var party = PartyStateScript.new()
    party.add_member("hero_yun")
    party.add_item("iron_sword", 1)
    party.set_member_status("hero_yun", {"hp": 90, "mp": 12})
    party.set_equipment("hero_yun", "weapon", "iron_sword")

    var stats_system = ActorStatsSystemScript.new()
    var stats = stats_system.build_stats(party, "hero_yun", RepositoryStub.new())
    assertions.assert_eq(stats.get("display_name", ""), "云游少侠", "应读取角色名")
    assertions.assert_eq(int(stats.get("hp", 0)), 90, "应读取成员当前 HP")
    assertions.assert_eq(int(stats.get("mp", 0)), 12, "应读取成员当前 MP")
    assertions.assert_eq(int(stats.get("attack", 0)), 22, "攻击应包含铁剑 +4")
    assertions.assert_eq(int(stats.get("max_mp", 0)), 25, "最大内力应包含护持加成 +5")
    assertions.assert_eq(int(stats.get("move_range", 0)), 3, "应读取移动范围")
    assertions.assert_true(stats.get("martial_art_ids", []).has("basic_sword"), "应读取武学列表")

    party.set_member_status("hero_yun", {"hp": 999, "mp": 999})
    var clamped = stats_system.build_stats(party, "hero_yun", RepositoryStub.new())
    assertions.assert_eq(int(clamped.get("hp", 0)), 120, "HP 应 clamp 到 max_hp")
    assertions.assert_eq(int(clamped.get("mp", 0)), 25, "MP 应 clamp 到 max_mp")

    var missing = stats_system.build_stats(party, "missing", RepositoryStub.new())
    assertions.assert_true(missing.is_empty(), "不存在角色应返回空字典")
```

- [ ] **Step 2: 注册测试并运行红灯**

Add to `tests/run_tests.gd`:

```gdscript
const TestActorStatsSystemScript = preload("res://tests/test_actor_stats_system.gd")
```

Insert `TestActorStatsSystemScript.new(),` after `TestEquipmentSystemScript.new(),`.

Run the verification command. Expected: FAIL because `actor_stats_system.gd` does not exist.

- [ ] **Step 3: 扩展 ActorState 与 actors.json**

In `scripts/domain/actor_state.gd`, add fields:

```gdscript
var max_mp: int = 0
var move_range: int = 3
var attack_range: int = 1
var charge_speed: int = 200
var sprite_tile_id: String = ""
```

In `from_dictionary(data)`, add:

```gdscript
actor.max_mp = max(0, int(data.get("max_mp", 0)))
actor.move_range = max(0, int(data.get("move_range", 3)))
actor.attack_range = max(1, int(data.get("attack_range", 1)))
actor.charge_speed = max(1, int(data.get("charge_speed", 200)))
actor.sprite_tile_id = str(data.get("sprite_tile_id", ""))
```

In `to_dictionary()`, add the same keys.

Update `data/actors.json` for `hero_yun` and `qingshanke`:

```json
"max_mp": 20,
"move_range": 3,
"attack_range": 1,
"charge_speed": 200
```

For `qingshanke`, use `"max_mp": 30` and keep current stronger attack/defense so he feels distinct.

- [ ] **Step 4: 实现 ActorStatsSystem**

Create `scripts/systems/actor_stats_system.gd`:

```gdscript
extends RefCounted

const EquipmentSystemScript = preload("res://scripts/systems/equipment_system.gd")

var equipment_system = EquipmentSystemScript.new()

func build_stats(party, actor_id: String, repository) -> Dictionary:
    if actor_id.is_empty() or repository == null or not repository.has_method("get_actor"):
        return {}
    var actor = repository.get_actor(actor_id)
    if typeof(actor) != TYPE_DICTIONARY or actor.is_empty():
        return {}
    var bonus = equipment_system.get_equipment_bonus(party, actor_id, repository)
    var max_hp = max(1, int(actor.get("max_hp", actor.get("hp", 1))) + int(bonus.get("max_hp", 0)))
    var max_mp = max(0, int(actor.get("max_mp", 0)) + int(bonus.get("max_mp", 0)))
    var status = party.get_member_status(actor_id) if party != null and party.has_method("get_member_status") else {}
    var hp = clamp(int(status.get("hp", max_hp)), 0, max_hp)
    var mp = clamp(int(status.get("mp", max_mp)), 0, max_mp)
    return {
        "actor_id": actor_id,
        "unit_id": actor_id,
        "display_name": str(actor.get("name", actor_id)),
        "hp": hp,
        "max_hp": max_hp,
        "mp": mp,
        "max_mp": max_mp,
        "attack": max(1, int(actor.get("attack", 1)) + int(bonus.get("attack", 0))),
        "defense": max(0, int(actor.get("defense", 0)) + int(bonus.get("defense", 0))),
        "move_range": max(0, int(actor.get("move_range", 3)) + int(bonus.get("move_range", 0))),
        "attack_range": max(1, int(actor.get("attack_range", 1)) + int(bonus.get("attack_range", 0))),
        "charge_speed": max(1, int(actor.get("charge_speed", 200)) + int(bonus.get("charge_speed", 0))),
        "martial_art_ids": _to_string_array(actor.get("martial_arts", [])),
        "sprite_tile_id": str(actor.get("sprite_tile_id", "")),
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

- [ ] **Step 5: 跑测试并提交**

Run the verification command. Expected: PASS.

Commit:

```bash
git add data/actors.json scripts/domain/actor_state.gd scripts/systems/actor_stats_system.gd tests/run_tests.gd tests/test_actor_stats_system.gd
git commit -m "feat: add actor stats composition"
```

---

### Task 4: 招募队友与战斗结果回写

**Files:**

- Modify: `scripts/systems/effect_system.gd`
- Modify: `scripts/core/game_state.gd`
- Modify: `tests/test_effect_system.gd`
- Create: `tests/test_save_party_equipment.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 扩展 EffectSystem 失败测试**

In `tests/test_effect_system.gd`, after the martial proficiency assertions, add:

```gdscript
    var recruit_result = effect_system.apply_effects(state, [
        {"type": "add_party_member", "actor_id": "qingshanke"}
    ])
    assertions.assert_true(bool(recruit_result.get("success", false)), "add_party_member 应成功招募青衫客")
    assertions.assert_true(state.party.has_member("qingshanke"), "青衫客应加入队伍")
    assertions.assert_eq(recruit_result.get("party_members", [])[0], "qingshanke", "效果结果应记录入队成员")

    var duplicate_recruit = effect_system.apply_effects(state, [
        {"type": "add_party_member", "actor_id": "qingshanke"}
    ])
    assertions.assert_true(bool(duplicate_recruit.get("success", false)), "重复招募应幂等成功")
    assertions.assert_eq(state.party.members.count("qingshanke"), 1, "重复招募不应重复添加成员")
```

- [ ] **Step 2: 新增存档回写失败测试 `tests/test_save_party_equipment.gd`**

Create the file:

```gdscript
extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")

func run(assertions) -> void:
    var state = GameStateScript.new()
    state.start_new_game()
    state.party.add_member("qingshanke")
    state.party.add_item("iron_sword", 1)
    state.party.set_equipment("hero_yun", "weapon", "iron_sword")
    state.party.set_member_status("qingshanke", {"hp": 160, "mp": 9})

    state.apply_battle_result({
        "victory": true,
        "party_member_results": {
            "hero_yun": {"hp": 88, "mp": 6},
            "qingshanke": {"hp": 120, "mp": 3}
        }
    })
    assertions.assert_eq(state.party.get_member_status("hero_yun").get("hp", 0), 88, "战斗结果应回写主角成员 HP")
    assertions.assert_eq(state.party.get_member_status("qingshanke").get("mp", 0), 3, "战斗结果应回写队友 MP")
    assertions.assert_eq(state.hero_hp, 88, "主角旧字段 hero_hp 应同步")
    assertions.assert_eq(state.hero_cur_mp, 6, "主角旧字段 hero_cur_mp 应同步")

    var data = state.to_dictionary()
    var restored = GameStateScript.new()
    restored.from_dictionary(data)
    assertions.assert_true(restored.party.has_member("qingshanke"), "存档应恢复队友")
    assertions.assert_eq(restored.party.get_equipped_item("hero_yun", "weapon"), "iron_sword", "存档应恢复装备")
    assertions.assert_eq(restored.party.get_member_status("qingshanke").get("hp", 0), 120, "存档应恢复队友 HP")
    state.free()
    restored.free()
```

- [ ] **Step 3: 注册测试并运行红灯**

Add to `tests/run_tests.gd`:

```gdscript
const TestSavePartyEquipmentScript = preload("res://tests/test_save_party_equipment.gd")
```

Insert `TestSavePartyEquipmentScript.new(),` after `TestCombatAndSaveScript.new(),`.

Run the verification command. Expected: FAIL because `add_party_member` and `party_member_results` are not implemented.

- [ ] **Step 4: 实现 add_party_member 效果**

In `scripts/systems/effect_system.gd`, add `"add_party_member"` to the match:

```gdscript
        "add_party_member":
            _apply_add_party_member(result, game_state, effect)
```

Extend `_empty_result()`:

```gdscript
"party_members": [],
```

Add method:

```gdscript
func _apply_add_party_member(result: Dictionary, game_state, effect: Dictionary) -> void:
    var actor_id = str(effect.get("actor_id", ""))
    if actor_id.is_empty():
        _add_error(result, "队友效果缺少角色编号。")
        return
    if game_state.party == null:
        _add_error(result, "队伍状态缺失。")
        return
    if game_state.has_method("actor_exists") and not game_state.actor_exists(actor_id):
        _add_error(result, "角色不存在：%s" % actor_id)
        return
    game_state.party.add_member(actor_id)
    if game_state.has_method("initialize_party_member_status"):
        game_state.initialize_party_member_status(actor_id)
    var members: Array = result["party_members"]
    members.append(actor_id)
    _mark_applied(result, "队友加入：%s" % actor_id)
```

- [ ] **Step 5: 实现 GameState 队友状态初始化与战斗回写**

In `scripts/core/game_state.gd`, add methods after `start_new_game()`:

```gdscript
func actor_exists(actor_id: String) -> bool:
    return not _get_actor_data(actor_id).is_empty()

func initialize_party_member_status(actor_id: String) -> void:
    if party == null or actor_id.is_empty() or not party.has_member(actor_id):
        return
    var actor = _get_actor_data(actor_id)
    if actor.is_empty():
        return
    var max_hp = max(1, int(actor.get("max_hp", actor.get("hp", 1))))
    var max_mp = max(0, int(actor.get("max_mp", 0)))
    party.set_member_status(actor_id, {"hp": max_hp, "mp": max_mp})
    if actor_id == "hero_yun":
        hero_max_hp = max_hp
        hero_hp = max_hp
        hero_max_mp = max_mp if max_mp > 0 else hero_max_mp
        hero_cur_mp = hero_max_mp
```

Add helper near `_get_map_data`:

```gdscript
func _get_actor_data(actor_id: String) -> Dictionary:
    var repository = DataRepositoryScript.new()
    repository.load_all()
    if not repository.has_method("get_actor"):
        return {}
    var actor = repository.get_actor(actor_id)
    return actor if typeof(actor) == TYPE_DICTIONARY else {}
```

In `apply_battle_result(result)`, before victory handling, add:

```gdscript
    _apply_party_member_results(result.get("party_member_results", {}))
```

Add method:

```gdscript
func _apply_party_member_results(value: Variant) -> void:
    if party == null or typeof(value) != TYPE_DICTIONARY:
        return
    for actor_id in value.keys():
        var raw_status = value[actor_id]
        if typeof(raw_status) != TYPE_DICTIONARY:
            continue
        var normalized_id = str(actor_id)
        if not party.has_member(normalized_id):
            continue
        party.set_member_status(normalized_id, {"hp": int(raw_status.get("hp", 0)), "mp": int(raw_status.get("mp", 0))})
        if normalized_id == "hero_yun":
            hero_hp = int(raw_status.get("hp", hero_hp))
            set_hero_cur_mp(int(raw_status.get("mp", hero_cur_mp)))
```

- [ ] **Step 6: 跑测试并提交**

Run the verification command. Expected: PASS.

Commit:

```bash
git add scripts/core/game_state.gd scripts/systems/effect_system.gd tests/run_tests.gd tests/test_effect_system.gd tests/test_save_party_equipment.gd
git commit -m "feat: add recruitable party member state flow"
```

---

### Task 5: 战棋多人玩家单位入场

**Files:**

- Create: `tests/test_tactical_party_battle.gd`
- Modify: `scripts/systems/tactical_combat_system.gd`
- Modify: `scripts/domain/tactical_battle_state.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 写失败测试 `tests/test_tactical_party_battle.gd`**

Create the file:

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
    state.party.add_member("qingshanke")
    state.party.set_member_status("qingshanke", {"hp": 160, "mp": 20})
    state.party.add_item("iron_sword", 1)
    state.party.set_equipment("hero_yun", "weapon", "iron_sword")

    var system = TacticalCombatSystemScript.new()
    system.set_repository(repository)
    var battle = system.create_battle(state, _party_context(), repository)

    assertions.assert_true(battle.get_unit("hero_yun") != null, "主角应以 actor_id 作为玩家单位入场")
    assertions.assert_true(battle.get_unit("qingshanke") != null, "青衫客应作为队友单位入场")
    assertions.assert_eq(battle.get_unit("hero_yun").team, "player", "主角应属于玩家队伍")
    assertions.assert_eq(battle.get_unit("qingshanke").team, "player", "队友应属于玩家队伍")
    assertions.assert_eq(battle.get_unit("hero_yun").cell.get("q", -1), 1, "主角应使用第一个玩家起始格")
    assertions.assert_eq(battle.get_unit("qingshanke").cell.get("q", -1), 1, "队友应使用第二个玩家起始格")
    assertions.assert_eq(battle.get_unit("hero_yun").attack, 22, "主角攻击应包含铁剑加成")
    assertions.assert_eq(battle.get_unit("qingshanke").hp, 160, "队友应读取成员当前 HP")
    assertions.assert_true(battle.has_living_team("player"), "玩家队伍应有存活单位")

    battle.get_unit("hero_yun").hp = 88
    battle.get_unit("hero_yun").mp = 6
    battle.get_unit("qingshanke").hp = 120
    battle.get_unit("qingshanke").mp = 3
    var payload = battle.to_result_dictionary()
    assertions.assert_eq(payload.get("party_member_results", {}).get("hero_yun", {}).get("hp", 0), 88, "结果应包含主角 HP")
    assertions.assert_eq(payload.get("party_member_results", {}).get("qingshanke", {}).get("mp", 0), 3, "结果应包含队友 MP")

    state.free()

func _party_context() -> Dictionary:
    return {
        "source_map_id": "mountain_pass",
        "source_object_id": "enemy_bandit_gate",
        "quest_id": "quest_mountain_trial",
        "battlefield": {"width": 8, "height": 6},
        "player_start_cells": [{"q": 1, "r": 2}, {"q": 1, "r": 3}],
        "units": [
            {"unit_id": "bandit", "actor_id": "bandit_01", "team": "enemy", "start_cell": {"q": 5, "r": 2}, "max_mp": 0}
        ]
    }
```

- [ ] **Step 2: 注册测试并运行红灯**

Add to `tests/run_tests.gd`:

```gdscript
const TestTacticalPartyBattleScript = preload("res://tests/test_tactical_party_battle.gd")
```

Insert `TestTacticalPartyBattleScript.new(),` after `TestTacticalCombatSystemScript.new(),`.

Run the verification command. Expected: FAIL because tactical battle still only creates player units from `context.units`.

- [ ] **Step 3: 让 TacticalBattleState 输出所有玩家结果**

In `scripts/domain/tactical_battle_state.gd`, extend `to_result_dictionary()`:

```gdscript
"party_member_results": _party_member_results(),
```

Add method:

```gdscript
func _party_member_results() -> Dictionary:
    var result: Dictionary = {}
    for unit in units:
        if unit.team != TEAM_PLAYER or unit.actor_id.is_empty():
            continue
        result[unit.actor_id] = {"hp": max(0, int(unit.hp)), "mp": max(0, int(unit.mp))}
    return result
```

- [ ] **Step 4: 接入 ActorStatsSystem 生成玩家单位**

In `scripts/systems/tactical_combat_system.gd`, add preload:

```gdscript
const ActorStatsSystemScript = preload("res://scripts/systems/actor_stats_system.gd")
```

Add field:

```gdscript
var _actor_stats_system = ActorStatsSystemScript.new()
```

In `create_battle()`, after terrain grid setup and before enemy unit loop, add:

```gdscript
var player_start_cells = _player_start_cells(context, raw_units)
_add_party_player_units(battle, game_state, source, player_start_cells)
```

Change the raw unit loop so explicit player entries are not duplicated:

```gdscript
        if str(raw_unit.get("team", "")) == TacticalBattleStateScript.TEAM_PLAYER:
            continue
```

Add helpers near `_build_unit`:

```gdscript
func _add_party_player_units(battle, game_state, source, start_cells: Array) -> void:
    if game_state == null or game_state.party == null:
        return
    var index := 0
    for actor_id in game_state.party.members:
        if index >= start_cells.size():
            _log(battle, "%s无法入场：起始格不足。" % str(actor_id))
            continue
        var stats = _actor_stats_system.build_stats(game_state.party, str(actor_id), source)
        if stats.is_empty():
            _log(battle, "%s无法入场：角色数据缺失。" % str(actor_id))
            continue
        stats["team"] = TacticalBattleStateScript.TEAM_PLAYER
        stats["cell"] = start_cells[index]
        stats["start_cell"] = start_cells[index]
        var unit = TacticalUnitStateScript.new()
        unit.from_dictionary(stats)
        if _is_valid_start_cell(battle, unit.cell) and not _is_cell_occupied(battle, unit.cell):
            battle.add_unit(unit)
            index += 1
        else:
            _log(battle, "%s站位无效。" % unit.display_name)

func _player_start_cells(context: Dictionary, raw_units: Array) -> Array:
    var result: Array = []
    var explicit = context.get("player_start_cells", [])
    if typeof(explicit) == TYPE_ARRAY:
        for cell in explicit:
            if typeof(cell) == TYPE_DICTIONARY:
                result.append(_read_cell(cell))
    if not result.is_empty():
        return result
    for raw_unit in raw_units:
        if typeof(raw_unit) != TYPE_DICTIONARY:
            continue
        if str(raw_unit.get("team", "")) == TacticalBattleStateScript.TEAM_PLAYER:
            result.append(_read_cell(raw_unit.get("start_cell", raw_unit.get("cell", {}))))
    if result.is_empty():
        result.append({"q": 1, "r": 2})
    return result
```

- [ ] **Step 5: 更新旧测试预期**

Existing `tests/test_tactical_combat_system.gd` expects `battle.get_unit("hero")`. Update expectations to `hero_yun` where player unit id is now actor id. Keep enemy ids unchanged.

Examples:

```gdscript
assertions.assert_eq(battle.get_unit("hero_yun").hp, 100, "主角单位应读取当前 GameState 气血")
system.move_unit(battle, "hero_yun", {"q": 4, "r": 2})
var attack_result = system.attack_unit(battle, "hero_yun", "bandit")
```

- [ ] **Step 6: 跑测试并提交**

Run the verification command. Expected: PASS.

Commit:

```bash
git add scripts/domain/tactical_battle_state.gd scripts/systems/tactical_combat_system.gd tests/run_tests.gd tests/test_tactical_combat_system.gd tests/test_tactical_party_battle.gd
git commit -m "feat: spawn party members into tactical battles"
```

---

### Task 6: 队伍/装备 UI 最小版

**Files:**

- Create: `scripts/scenes/party_panel.gd`
- Modify: `scripts/scenes/hud.gd`
- Create: `tests/test_party_panel.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 写失败测试 `tests/test_party_panel.gd`**

Create the file:

```gdscript
extends RefCounted

const PartyPanelScript = preload("res://scripts/scenes/party_panel.gd")
const PartyStateScript = preload("res://scripts/domain/party_state.gd")

class RepositoryStub:
    extends RefCounted
    func get_actor(actor_id: String) -> Dictionary:
        if actor_id == "hero_yun":
            return {"id": "hero_yun", "name": "云游少侠", "hp": 120, "max_hp": 120, "max_mp": 20, "attack": 18, "defense": 8, "martial_arts": ["basic_sword"]}
        return {}

    func get_item(item_id: String) -> Dictionary:
        if item_id == "iron_sword":
            return {"id": "iron_sword", "name": "铁剑", "type": "equipment", "equipment": {"slot": "weapon", "stat_bonus": {"attack": 4}}}
        return {}

func run(assertions) -> void:
    var party = PartyStateScript.new()
    party.add_member("hero_yun")
    party.add_item("iron_sword", 1)
    party.set_member_status("hero_yun", {"hp": 100, "mp": 12})

    var panel = PartyPanelScript.new()
    panel.set_party_context(party, RepositoryStub.new())
    assertions.assert_true(panel.has_method("refresh"), "PartyPanel 应提供 refresh 方法")
    panel.refresh()
    assertions.assert_eq(panel.selected_actor_id, "hero_yun", "刷新后应默认选中第一个队友")
    assertions.assert_true(panel.member_buttons.size() >= 1, "应生成队友按钮")

    var result = panel.equip_selected("iron_sword")
    assertions.assert_true(bool(result.get("success", false)), "面板应能给选中角色装备铁剑")
    assertions.assert_eq(party.get_equipped_item("hero_yun", "weapon"), "iron_sword", "装备结果应写入 PartyState")
    panel.free()
```

- [ ] **Step 2: 注册测试并运行红灯**

Add to `tests/run_tests.gd`:

```gdscript
const TestPartyPanelScript = preload("res://tests/test_party_panel.gd")
```

Insert `TestPartyPanelScript.new(),` near other scene/UI tests after `TestHudInventoryScript.new(),`.

Run the verification command. Expected: FAIL because `party_panel.gd` does not exist.

- [ ] **Step 3: 实现 PartyPanel 最小逻辑**

Create `scripts/scenes/party_panel.gd`:

```gdscript
extends PanelContainer

const EquipmentSystemScript = preload("res://scripts/systems/equipment_system.gd")
const ActorStatsSystemScript = preload("res://scripts/systems/actor_stats_system.gd")

var party = null
var repository = null
var selected_actor_id: String = ""
var member_buttons: Array[Button] = []

var _equipment_system = EquipmentSystemScript.new()
var _stats_system = ActorStatsSystemScript.new()
var _root_box: VBoxContainer
var _member_list: VBoxContainer
var _detail_label: Label

func _ready() -> void:
    _build_ui()

func set_party_context(next_party, next_repository) -> void:
    party = next_party
    repository = next_repository
    refresh()

func refresh() -> void:
    if _root_box == null:
        _build_ui()
    _clear_member_buttons()
    if party == null:
        _detail_label.text = "队伍状态缺失。"
        return
    for actor_id in party.members:
        var button = Button.new()
        button.text = _actor_name(str(actor_id))
        button.pressed.connect(func(): _select_actor(str(actor_id)))
        member_buttons.append(button)
        _member_list.add_child(button)
    if selected_actor_id.is_empty() and not party.members.is_empty():
        selected_actor_id = str(party.members[0])
    _refresh_detail()

func equip_selected(item_id: String) -> Dictionary:
    if selected_actor_id.is_empty():
        return {"success": false, "message": "未选择队友。"}
    var result = _equipment_system.equip(party, selected_actor_id, item_id, repository)
    _refresh_detail()
    return result

func _build_ui() -> void:
    if _root_box != null:
        return
    _root_box = VBoxContainer.new()
    add_child(_root_box)
    _member_list = VBoxContainer.new()
    _root_box.add_child(_member_list)
    _detail_label = Label.new()
    _detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _root_box.add_child(_detail_label)

func _clear_member_buttons() -> void:
    for button in member_buttons:
        if is_instance_valid(button):
            button.queue_free()
    member_buttons.clear()

func _select_actor(actor_id: String) -> void:
    selected_actor_id = actor_id
    _refresh_detail()

func _refresh_detail() -> void:
    if selected_actor_id.is_empty() or _detail_label == null:
        return
    var stats = _stats_system.build_stats(party, selected_actor_id, repository)
    _detail_label.text = "%s\n气血 %d/%d  内力 %d/%d\n攻击 %d  防御 %d\n武器：%s\n衣甲：%s\n饰品：%s" % [
        str(stats.get("display_name", selected_actor_id)),
        int(stats.get("hp", 0)),
        int(stats.get("max_hp", 0)),
        int(stats.get("mp", 0)),
        int(stats.get("max_mp", 0)),
        int(stats.get("attack", 0)),
        int(stats.get("defense", 0)),
        _equipped_name("weapon"),
        _equipped_name("armor"),
        _equipped_name("accessory")
    ]

func _actor_name(actor_id: String) -> String:
    if repository != null and repository.has_method("get_actor"):
        var actor = repository.get_actor(actor_id)
        if typeof(actor) == TYPE_DICTIONARY and not actor.is_empty():
            return str(actor.get("name", actor_id))
    return actor_id

func _equipped_name(slot: String) -> String:
    var item_id = party.get_equipped_item(selected_actor_id, slot) if party != null else ""
    if item_id.is_empty():
        return "无"
    if repository != null and repository.has_method("get_item"):
        var item = repository.get_item(item_id)
        if typeof(item) == TYPE_DICTIONARY and not item.is_empty():
            return str(item.get("name", item_id))
    return item_id
```

- [ ] **Step 4: 接入 HUD**

In `scripts/scenes/hud.gd`, preload and hold panel:

```gdscript
const PartyPanelScript = preload("res://scripts/scenes/party_panel.gd")
var party_panel: PanelContainer
```

Add these methods in `scripts/scenes/hud.gd` after `hide_inventory()`:

```gdscript
func show_party_panel(party, repository) -> void:
    if party_panel == null:
        party_panel = PartyPanelScript.new()
        add_child(party_panel)
    party_panel.visible = true
    party_panel.set_party_context(party, repository)

func hide_party_panel() -> void:
    if party_panel != null:
        party_panel.visible = false

func toggle_party_panel(party, repository) -> void:
    if party_panel != null and party_panel.visible:
        hide_party_panel()
    else:
        show_party_panel(party, repository)

func is_party_panel_open() -> bool:
    return party_panel != null and party_panel.visible
```

In `scripts/scenes/map_screen_base.gd`, update `_unhandled_input(event)` so `P` toggles the party panel next to the existing inventory shortcut:

```gdscript
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
        _toggle_party_panel()
        return
```

Add these helpers near `_toggle_inventory()`:

```gdscript
func _toggle_party_panel() -> void:
    hud.toggle_party_panel(_get_game_state().party, data_repository)

func _refresh_party_panel_if_open() -> void:
    if hud.is_party_panel_open():
        hud.show_party_panel(_get_game_state().party, data_repository)
```

Call `_refresh_party_panel_if_open()` after equipment changes in the UI task and after inventory refresh points that can affect equipment availability.

- [ ] **Step 5: 跑测试并提交**

Run the verification command. Expected: PASS.

Commit:

```bash
git add scripts/scenes/party_panel.gd scripts/scenes/hud.gd scripts/scenes/map_screen_base.gd tests/run_tests.gd tests/test_party_panel.gd
git commit -m "feat: add minimal party equipment panel"
```

---

## Final Verification

- [ ] **Step 1: Run full headless tests**

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
Write-Output "GodotExit:$LASTEXITCODE"
```

Expected: all suites pass and `GodotExit:0`.

- [ ] **Step 2: Check Git status**

```bash
git status --short --branch
```

Expected: clean branch with the six task commits.

- [ ] **Step 3: Manual UAT path**

Use Godot editor or playable run to verify:

1. Start new game.
2. Trigger the data path that applies `add_party_member` for `qingshanke`.
3. Open the party panel.
4. Equip iron sword on the hero.
5. Enter tactical battle.
6. Confirm hero and qingshanke appear as player units.
7. Confirm hero attack reflects iron sword bonus.
8. Finish or retreat battle.
9. Save and reload.
10. Confirm party members, equipment and HP/MP restore.

---

## Self-Review Notes

- Spec coverage: PartyState state, equipment, actor stats, recruitment, tactical party entry, result persistence, UI and tests are covered by Tasks 1-6.
- Scope control: random affixes, quality, enhancement, durability, set bonuses, enemy AI expansion and large character page are excluded from implementation tasks.
- Type consistency: `equipment`, `member_status`, `add_party_member`, `party_member_results`, `build_stats`, `equip`, `unequip` and `get_equipment_bonus` names are consistent across tasks.
