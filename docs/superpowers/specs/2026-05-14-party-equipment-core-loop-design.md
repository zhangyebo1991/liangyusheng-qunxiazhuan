# 队友与装备基础闭环设计

日期：2026-05-14  
状态：已确认，待进入计划阶段

## 1. 背景与目标

当前项目已经具备数据加载、任务、对白、事件、效果、背包、客栈、存档、战棋、内力、武学、熟练度和战斗反馈等基础切片，但仍偏向“主角单人推进”。下一个阶段的目标不是继续堆单个玩法点，而是补齐武侠 RPG 的核心骨架：队友、装备、属性合成、多人入场和存档恢复。

本阶段采用“深度闭环”路线：优先完成队友与装备两个基础能力，使游戏从单人切片过渡到可承载队伍养成的 RPG 底盘。

成功判据：

- 队伍里至少能有主角和一名队友。
- 队友能完整进入战棋，拥有独立 HP、MP、集气、移动、普攻和武学行动。
- 装备系统支持固定槽位与固定属性，装备后属性进入战斗结算。
- 队友、装备、背包、铜钱、成员 HP/MP 能随存档恢复。
- 新增队友、装备、战棋入场和存档测试，全量 Godot headless 测试通过。

范围外：

- 随机词条、品质、强化、耐久、套装。
- 复杂角色养成、技能树、阵法。
- 大型角色详情页或完整装备管理 UI。
- 敌人队伍 AI 扩展。

## 2. 总体架构

本阶段延续现有分层规则：`scripts/domain/` 保存领域状态，`scripts/systems/` 保存可测试规则，`scripts/scenes/` 负责展示和输入，`data/` 保存内容数据。

新增或扩展的核心模块：

| 模块 | 类型 | 职责 |
| --- | --- | --- |
| `PartyState` | domain | 保存成员、背包、铜钱、装备分配和成员当前 HP/MP |
| `EquipmentSystem` | system | 装备穿脱、槽位校验、数量占用、装备属性加成 |
| `ActorStatsSystem` | system | 将角色模板、成员状态和装备加成合成为战斗用属性 |
| `EffectSystem` | system | 新增 `add_party_member` 效果，复用现有事件/对白管线招募队友 |
| `TacticalCombatSystem` | system | 从 `party.members` 生成玩家单位，并回写每名队友战斗结果 |
| 队伍/装备面板 | scene | 查看队友、基础属性和装备槽，执行最小穿脱交互 |

核心约束：

- `data/actors.json` 仍是角色模板，不直接作为存档状态。
- 装备加成不写回角色模板，只在属性合成阶段生效。
- 战斗系统不直接读取 UI，只读取合成后的运行时属性。
- 旧存档缺少新字段时必须有默认值。
- 第一版队友和装备系统以稳定闭环为主，不引入复杂养成。

## 3. 领域状态设计

### 3.1 PartyState

当前 `PartyState` 已有：

```gdscript
var members: Array[String] = []
var inventory: Dictionary = {}
var coins := 0
```

本阶段新增：

```gdscript
var equipment: Dictionary = {}
var member_status: Dictionary = {}
```

建议结构：

```json
{
  "members": ["hero_yun", "qingshanke"],
  "inventory": { "iron_sword": 1, "cloth_armor": 1 },
  "coins": 35,
  "equipment": {
    "hero_yun": { "weapon": "iron_sword" },
    "qingshanke": { "armor": "cloth_armor" }
  },
  "member_status": {
    "hero_yun": { "hp": 92, "mp": 10 },
    "qingshanke": { "hp": 160, "mp": 4 }
  }
}
```

兼容策略：

- 旧存档缺 `equipment` 时默认为 `{}`。
- 旧存档缺 `member_status` 时默认为 `{}`。
- 主角旧字段 `hero_hp`、`hero_cur_mp` 暂时保留，并与 `member_status.hero_yun` 双写，避免一次性改穿所有旧流程。
- `add_member(actor_id)` 保持幂等，重复招募不重复写入。

### 3.2 角色模板字段

`data/actors.json` 当前已有 `hp`、`max_hp`、`attack`、`defense`、`martial_arts` 和 `sprite_tile_id`。为了让队友完整进入战棋，建议补充：

```json
{
  "max_mp": 20,
  "move_range": 3,
  "attack_range": 1,
  "charge_speed": 200
}
```

缺失时使用当前战棋默认值，保证旧数据兼容。

## 4. 装备数据与规则

### 4.1 装备数据结构

`data/items.json` 的装备建议统一使用 `type = "equipment"` 和 `equipment` 字段：

```json
{
  "id": "iron_sword",
  "name": "铁剑",
  "type": "equipment",
  "description": "寻常江湖人常用的长剑。",
  "value": 120,
  "equipment": {
    "slot": "weapon",
    "stat_bonus": { "attack": 4 }
  }
}
```

第一版槽位：

- `weapon`：武器，主要加攻击。
- `armor`：衣甲，主要加防御或气血。
- `accessory`：饰品，可加 HP、MP 或少量防御。

第一版最小装备集：

- 铁剑：`weapon`，`attack +4`
- 布衣：`armor`，`defense +2`
- 护符：`accessory`，`max_mp +5`

### 4.2 EquipmentSystem

新增 `scripts/systems/equipment_system.gd`，只负责规则：

```gdscript
func can_equip(party, actor_id: String, item_id: String, repository) -> Dictionary
func equip(party, actor_id: String, item_id: String, repository) -> Dictionary
func unequip(party, actor_id: String, slot: String) -> Dictionary
func get_equipment_bonus(party, actor_id: String, repository) -> Dictionary
```

规则：

- 只能给队伍成员装备。
- 只能装备 `equipment.slot` 合法的物品。
- 同一件装备数量不能被多名成员同时占用。
- 穿装备不从 `inventory` 删除，但会占用该物品数量。
- 卸装备只清空槽位，不改变 `inventory`。

这种模型能保留现有背包数量语义，同时避免“1 把铁剑装备给两个人”的问题。

## 5. 属性合成

新增 `scripts/systems/actor_stats_system.gd`，将模板、成员状态和装备加成合成运行时属性。

输入：

- `repository.get_actor(actor_id)`
- `party.member_status[actor_id]`
- `EquipmentSystem.get_equipment_bonus(...)`

输出示例：

```gdscript
{
  "actor_id": "hero_yun",
  "display_name": "云游少侠",
  "hp": 92,
  "max_hp": 120,
  "mp": 10,
  "max_mp": 25,
  "attack": 22,
  "defense": 8,
  "move_range": 3,
  "attack_range": 1,
  "charge_speed": 200,
  "martial_art_ids": ["basic_sword"],
  "sprite_tile_id": "tile_hero_yun_hd"
}
```

原则：

- 装备加成只影响合成结果。
- 缺成员状态时，HP/MP 从角色模板默认值初始化。
- HP/MP 需要 clamp 到合成后的 `max_hp` / `max_mp`。
- 后续状态效果、阵法、临时 buff 可以接入同一个合成入口。

## 6. 队友招募流程

`EffectSystem` 增加 `add_party_member` 效果。

数据示例：

```json
{
  "type": "add_party_member",
  "actor_id": "qingshanke"
}
```

流程：

```text
对白或任务满足条件
-> EventSystem 执行 effects
-> EffectSystem 处理 add_party_member
-> 校验 actor 存在
-> PartyState.add_member(actor_id)
-> 初始化 member_status
-> UI 显示“青衫客加入队伍”
-> 存档写入 party.members 和 party.member_status
```

重复招募同一角色时不重复添加，返回明确消息。

## 7. 战棋入场与回流

### 7.1 入场生成

当前 `TacticalCombatSystem.create_battle()` 从地图 `context.units` 构造单位。本阶段扩展为：

- 敌人继续来自 `context.units`。
- 玩家单位来自 `game_state.party.members`。
- 地图可新增 `player_start_cells`，声明玩家阵容起始位置。
- 为兼容旧数据，若 `context.units` 已包含 `team = "player"` 的单位，则复用其 `start_cell`。

流程：

```text
create_battle(game_state, context)
-> 读取敌方 raw units
-> 读取 party.members
-> 按 player_start_cells 分配起始格
-> ActorStatsSystem 合成每个成员属性
-> TacticalUnitState.from_dictionary()
-> add_unit()
```

起始格不足时，只生成前 N 名队友，并写入战斗日志。

### 7.2 战斗结果回写

`TacticalBattleState.to_result_dictionary()` 从只回写主角升级为回写每个玩家单位：

```json
{
  "party_member_results": {
    "hero_yun": { "hp": 92, "mp": 10 },
    "qingshanke": { "hp": 160, "mp": 4 }
  }
}
```

`GameState.apply_battle_result()` 将这些结果写回 `PartyState.member_status`。主角结果同时同步到旧字段 `hero_hp`、`hero_cur_mp`。

胜负判定沿用现有 `has_living_team`，只要玩家队伍仍有存活单位即未失败。

## 8. UI 第一版

第一版做最小队伍/装备面板，不追求完整角色页。

建议交互：

- `P` 键打开队伍面板，或从 HUD 图标进入。
- 左侧显示队伍成员列表。
- 右侧显示选中成员的 HP、MP、攻击、防御、武学。
- 显示三个装备槽：武器、衣甲、饰品。
- 点击装备槽后展示可装备物品列表。
- 装备后立即刷新属性。

UI 不直接改 `PartyState`，只调用 `EquipmentSystem`，并根据返回结果刷新。

## 9. 错误处理

- 招募不存在角色：返回失败消息，不修改队伍。
- 重复招募：保持幂等，不重复初始化状态。
- 非队伍成员装备：返回失败消息。
- 槽位不匹配：返回失败消息。
- 装备数量不足或已被占用：返回失败消息。
- 装备数据缺字段：物品不可装备，但仍可作为普通物品显示。
- 起始格越界或被占：跳过该单位并写入战斗日志。
- 队伍全员无法入场：沿用“玩家单位缺失”日志和失败处理。
- 旧存档缺新字段：使用默认值，不报错。

## 10. 测试策略

新增或扩展测试：

| 测试文件 | 覆盖内容 |
| --- | --- |
| `tests/test_party_state.gd` | 装备字典、成员状态、旧存档兼容、重复入队 |
| `tests/test_equipment_system.gd` | 槽位匹配、数量占用、穿脱、装备加成 |
| `tests/test_actor_stats_system.gd` | 模板 + 成员状态 + 装备加成合成属性 |
| `tests/test_effect_system.gd` | `add_party_member` 效果、重复招募幂等 |
| `tests/test_tactical_party_battle.gd` | 主角与队友入场、独立 HP/MP/集气、装备属性进入单位 |
| `tests/test_save_party_equipment.gd` | 队友、装备和成员 HP/MP 存档恢复 |

回归要求：

- 全量 Godot headless 测试通过。
- 旧存档兼容测试覆盖缺 `equipment`、缺 `member_status` 两种情况。
- 战棋测试覆盖玩家起始格不足和起始格冲突。

## 11. 实施顺序

建议拆为 5 个小提交：

1. 队伍状态升级
   - `PartyState.equipment`
   - `PartyState.member_status`
   - 序列化与旧存档兼容测试

2. 装备数据与 EquipmentSystem
   - `items.json` 增装备字段
   - 铁剑、布衣、护符最小装备集
   - 穿脱、数量占用和属性加成测试

3. ActorStatsSystem
   - 角色模板补 `max_mp`、`move_range`、`attack_range`、`charge_speed`
   - 属性合成器
   - 缺字段兼容测试

4. 队友招募与战棋入场
   - `EffectSystem.add_party_member`
   - 青衫客入队示例
   - 战棋从 `party.members` 生成玩家单位
   - 战斗结果回写每名成员状态

5. 队伍/装备 UI 最小版
   - 队伍面板
   - 装备槽查看与穿脱
   - 属性变化展示
   - 全量测试与 UAT

## 12. 结论

采用“队友 + 装备双核心闭环”作为下一阶段主路径。它优先补齐本游戏自己的基础 RPG 能力，而不是提前做扩展者工具。第一版控制在固定队友、固定槽位、固定属性和完整战棋入场，既能显著提升游戏完整度，也为后续更多队友、装备掉落、商店扩展、剧情分支和真正的扩展开发打基础。
