# 客栈休整与内力闭环切片设计

日期：2026-05-12
项目：liangyusheng-qunxiazhuan
目标引擎：Godot 4.6

## 目标

让玩家**第一次拥有「长期内力」作为存档资源**，并通过「客栈休息（5 文，绑定回流点）+ 药铺凝神丹（+10 内力）」形成「出门 → 战斗 → 消耗 → 回流 → 补给」的最小经营闭环。

上一切片「战棋武学与内力基础切片」把内力作为新资源接入战棋，但战斗外完全摸不到：没消耗、没恢复、没决策。本切片补完闭环，把过去几片积累的「铜钱、物品、效果系统、地图对象、村镇 NPC」全部串成一条玩家循环。

## 范围

本阶段包含：

- 主角拥有**长期当前内力 `hero_cur_mp`**（存档新字段，默认等于 `hero_max_mp`），战棋中招式消耗直接扣减它。
- 复用村镇广场已有 NPC「**陆掌柜**（`innkeeper_lu`）」：扩展现有对话 `foot_village_innkeeper_idle`，新增「休息一晚（5 文）」和「盘缠不足，将就一晚（免费兜底）」两个分支。
- 休息效果：恢复主角**当前气血到满 + 当前长期内力到满**，并**绑定 `last_inn_id` 存档字段**作为死亡回流点。
- 新道具「**凝神丹**」（`herb_focus`）：战斗内外均可用，固定恢复 +10 内力（不超过最大值）；通过村镇药铺常售获取，价格 12 文。
- **战棋失败回流改造**：失败时若 `last_inn_id` 已绑定 → 切场回该客栈所在地图、玩家定位到 NPC 旁、HP/MP 归满；若未绑定 → 沿用现行「原地复活」逻辑，**完全向后兼容老存档**。
- HUD 显示主角当前/最大长期内力（与气血并列）。

本阶段不包含：

- 任何「游戏内时间」概念（白天/黑夜、休息时长）。
- 客栈剧情、夜话、秘闻（留给未来「客栈夜话」独立切片）。
- 多个客栈联网（本切片只有 1 个客栈，`last_inn_id` 字段为未来扩展预留）。
- 内力高级药、秘药、内力溢出、上限突破。
- 死亡惩罚（铜钱、任务、装备、熟练度等）。
- 敌人内力机制、敌人招式 AI。
- 修改任何现有任务/对话奖励数据（凝神丹仅通过新商店条目获取）。

## 玩家循环

```
新游戏 → 村镇广场 → 与陆掌柜对话「休息一晚（5 文）」→ 绑定客栈
  ↓
出村 → 山道 → 打强人
  ↓ 赢 → 消耗 5-10 内力 → 回村休整
  ↓ 输 → 切场回村镇陆掌柜旁，HP/MP 满
  ↓
中途内力低 → 提前去药铺买凝神丹 → 战斗中或战斗外 +10 内力
```

## 推荐方案

采用「单一长期内力 + 复用现有 NPC + 显式绑定回流点 + 数据化效果」方案。

### 关键决策

1. **战斗 MP 与长期 MP 合并为单一字段**。替代方案是保留两套 MP（战斗内临时 + 战斗外长期），但会让玩家看到两个内力数字、产生认知负担。合并后玩家只看到一个数字「当前/最大」，连打内力压力直接体现在出门前的补给决策上。
2. **复用陆掌柜，扩展对话**。村镇广场已有 NPC `innkeeper_lu` 挂在客栈门前，对应对话 `foot_village_innkeeper_idle`，连「送信任务」就是把信送给他。新建「钱伯」会与现有数据重复，破坏 single source of truth。复用 = 零新 actor、零新 NPC 节点、纯数据扩展。
3. **死亡回流要求显式绑定**。`last_inn_id` 默认空串，未绑定则失败沿用「原地复活」旧逻辑。这让老存档**零迁移**即可继续，新玩家也只在主动休息一次后才解锁「死亡传送」机制。
4. **凝神丹仅药铺出售**。不污染任务奖励数据，不破坏可重复获取性。客栈对话台词中提示「想恢复内力可去药铺找凝神丹」，玩家发现成本为零。

## 架构

项目继续保持「领域状态、系统规则、场景表现、核心回流」分层。

- `data/items.json` 增加凝神丹条目；`data/dialogues.json` 扩展陆掌柜对话；`data/maps.json` 在 foot_village 节点下追加 `inns[]` 数组与药铺商品列表。
- `scripts/core/game_state.gd` 持久化 `hero_cur_mp` 与 `last_inn_id`，提供薄方法 `restore_hero_mp` / `consume_hero_mp` / `bind_inn` / `has_bound_inn` / `get_inn_spawn`。
- `scripts/systems/effect_system.gd` 新增 `restore_mp` 与 `rest_at_inn` 两种 effect type。
- `scripts/systems/condition_system.gd` 新增 `coins_at_least` 条件 type。
- `scripts/systems/data_repository.gd` 新增 `get_inn(inn_id)` / `get_inn_for_map(map_id)` 反查接口。
- `scripts/systems/inventory_system.gd` 物品使用统一通过 `EffectSystem.apply_effects(item.effects)` 路径，自动支持 `restore_mp`。
- `scripts/systems/tactical_combat_system.gd` 与 `combat_system.gd` 在 BattleResult 中携带 `mp_consumed`，由 `apply_battle_result` 统一回写到 `hero_cur_mp`。
- `scripts/scenes/battle_screen.gd` 持有 MP working copy，战斗中物品使用与招式消耗改 working copy 并发 `EventBus.hero_mp_changed`，结算时由 BattleResult 统一同步回 GameState。
- `scripts/scenes/hud.gd` 显示 `cur_mp / max_mp`，监听 `hero_mp_changed`。
- `scripts/scenes/dialogue_box.gd` 选项过滤复用现有 ConditionSystem 路径，自动支持 `coins_at_least`。
- `scripts/core/event_bus.gd` 新增信号 `hero_mp_changed(cur, max)` 与 `inn_rested(inn_id)`。

`EffectSystem` 与 `ConditionSystem` 仍是数据驱动效果与条件的唯一入口。任何场景脚本都不直接扣 MP、不直接绑定客栈，避免后续做敌人 MP、新客栈、自动测试时出现两套规则。

## 数据设计

### `data/items.json` 新增条目

```json
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
```

`InventorySystem` 现在统一通过 `EffectSystem.apply_effects(item.effects)` 路径处理物品使用，所以仅需保证 `effects` 字典格式与现有 `heal_hp` 风格一致即可。

### `data/dialogues.json` 扩展 `foot_village_innkeeper_idle`

在原有 idle 对话末尾追加两个分支选项（`condition` / `effects` 字段名以现有 dialogue schema 为准）：

```json
{
  "id": "rest_5_coins",
  "text": "休息一晚（5 文）",
  "conditions": [
    { "type": "coins_at_least", "amount": 5 }
  ],
  "effects": [
    { "type": "add_coins", "amount": -5 },
    { "type": "rest_at_inn", "inn_id": "foot_village_inn" }
  ]
},
{
  "id": "rest_no_coin",
  "text": "盘缠不足，将就一晚",
  "conditions": [
    { "type": "not", "condition": { "type": "coins_at_least", "amount": 5 } }
  ],
  "effects": [
    { "type": "rest_at_inn", "inn_id": "foot_village_inn" }
  ]
}
```

陆掌柜的台词中加一句提示：「少侠若内力不济，街中药铺有凝神丹可备。」

### `data/maps.json` foot_village 节点新增 `inns[]`

```json
"inns": [
  {
    "id": "foot_village_inn",
    "map_id": "foot_village",
    "spawn_position": [X, Y]
  }
]
```

`spawn_position` 在实施时定位到陆掌柜旁的格子（实现阶段读取现有 NPC 坐标确定）。

### `data/maps.json` foot_village 药铺商品列表追加

在现有药铺 NPC 关联的 shop 数据节点的商品数组中追加 `herb_focus`，价格 12 文（具体字段格式以现有 shop schema 为准，实施阶段会先查证 `data/maps.json` 中药铺 shop 节点的真实结构再落实）。

### `data/martial_arts.json`

**无改动**。本切片不动招式数据，只是战斗系统从「扣战斗内临时 MP」改为「BattleResult 携带 mp_consumed → apply_battle_result 统一扣 game_state.hero_cur_mp」。

## 领域状态与存档

### `scripts/core/game_state.gd` 新增字段

```gdscript
var hero_cur_mp := DEFAULT_HERO_MAX_MP
var last_inn_id: String = ""
```

### 新增 API

```gdscript
func restore_hero_mp(amount: int) -> int        # 同 restore_hero_hp 风格，返回实际恢复量
func consume_hero_mp(amount: int) -> bool       # 战斗结算时调用，不足则返回 false
func bind_inn(inn_id: String) -> void           # rest_at_inn 调用
func has_bound_inn() -> bool
func get_bound_inn_map_id() -> String           # 通过 data_repository.get_inn 反查 map_id
func get_bound_inn_spawn() -> Vector2           # 通过 data_repository.get_inn 反查 spawn
```

### 存档兼容（沿用项目「SaveSlot 字段升级模式」）

两个新字段都有合理默认 → **不升 SAVE_VERSION**：

- `from_dict`：`hero_cur_mp = d.get("hero_cur_mp", hero_max_mp)`（老存档默认满）
- `from_dict`：`last_inn_id = d.get("last_inn_id", "")`（老存档默认未绑定，对应「未休息则原地复活」）

## 关键边界与契约

### 1. 战斗中 MP 改造（最复杂的一处）

战棋开局：`battle_screen` 创建 working copy `cur_mp_in_battle = game_state.hero_cur_mp`。

招式按钮可用态：`tactical_combat_system._validate_action` 已存在，将「战斗内 MP」参数从场景持有的临时变量改为 working copy。**禁止**场景脚本自行复算「招式 cost vs 当前 MP」公式。

战斗中嗑凝神丹：通过现有「战斗内背包面板 → InventorySystem → EffectSystem」路径走，`restore_mp` 改 working copy 并发 `hero_mp_changed`。这避免「战斗暂退时长期 MP 状态不一致」陷阱。

战斗结算（胜/败/暂退）：BattleResult 携带 `mp_consumed = max_mp - cur_mp_in_battle`（亦可直接传 working copy 的最终值），`apply_battle_result` 统一回写到 `game_state.hero_cur_mp` 并发 `hero_mp_changed`。

### 2. 死亡回流分支

`apply_battle_result` 在 `victory == false` 分支：

- `last_inn_id == ""` → 沿用现行「原地复活」逻辑，**完全不变**。
- `last_inn_id != ""` → 通过 `data_repository.get_inn(id)` 取 map_id + spawn → 返回值携带 `{should_warp_to_inn: true, target_map: ..., spawn: ...}`，HP/MP 直接归满（`hero_hp = hero_max_hp`、`hero_cur_mp = hero_max_mp`），由 `battle_screen` 调 SceneLoader 切场。

### 3. `rest_at_inn` 防御

理论上客栈对话不会在战斗中发生，但为防御 EffectSystem 被滥用，`_apply_rest_at_inn` 内做检查：若 `game_state.battle_context` 非空则返回 failed。

### 4. 跨 UI 数值一致性

MP 在「HUD」与「战棋招式按钮」两处出现 → 严格走 `game_state.hero_cur_mp / hero_max_mp`，禁止任何 UI 旁路计算。

## 测试覆盖

按项目「信号契约必端到端测」沉淀，新增 5 个测试文件：

- `tests/test_long_term_mp_save.gd`：战斗扣 MP 后存档；读档恢复；老存档（无 hero_cur_mp 字段）反序列化兜底为 max。
- `tests/test_mp_potion.gd`：凝神丹战斗外用 +10；满 MP 时使用返回 0；effect type `restore_mp` 走 EffectSystem 而非旁路。
- `tests/test_inn_rest_loop.gd`：与陆掌柜对话付 5 文 → HP/MP 满 + last_inn_id 绑定；铜钱不足 → 走免费分支；触发 `EventBus.inn_rested`。
- `tests/test_death_warp_to_inn.gd`：已绑定 → 失败回流到客栈所在 map 指定出生点；未绑定 → 沿用原地复活；回流时 HP/MP 都满。
- `tests/test_hud_mp_display.gd`：HUD 显示 cur/max；`hero_mp_changed` 信号驱动刷新。

现有测试扩展：

- `tests/test_condition_system.gd`：新增 `coins_at_least` 用例。
- `tests/test_data_loader.gd`：自动覆盖凝神丹（已断言全数据加载）。
- `tests/test_map_data.gd`：扩展校验 foot_village 的 `inns[]` 节点。
- `tests/test_shop_map_screen.gd` 或 `tests/test_shop_system.gd`：扩展验证药铺出售凝神丹。

## 实施顺序

每步可独立 commit、可独立 `--headless` 跑测试：

1. `game_state` 加字段 + 4 helper + 老存档兼容 + 信号声明 + `test_long_term_mp_save.gd`。
2. `EffectSystem` 加 `restore_mp` + `data/items.json` 加凝神丹 + `test_mp_potion.gd`。
3. `ConditionSystem` 加 `coins_at_least` + `test_condition_system.gd` 扩展。
4. `data_repository` 加 `get_inn` / `get_inn_for_map` + `data/maps.json` 加 `inns[]` + `test_map_data.gd` 扩展。
5. `EffectSystem` 加 `rest_at_inn` + `data/dialogues.json` 扩展陆掌柜 + `test_inn_rest_loop.gd`。
6. `data/maps.json` 药铺商品列表追加凝神丹 + 商店测试扩展。
7. `apply_battle_result` 死亡回流分支 + `battle_screen` 接线 + 战棋/回合战斗系统 MP working copy 改造 + `test_death_warp_to_inn.gd`。
8. HUD 改造 + `test_hud_mp_display.gd`。
9. 全套 `--headless` 跑通 + 手动 UAT 三循环：胜利循环、失败回流循环、嗑药循环。

## 与项目沉淀对齐

- 所有数据 .json 改动后 `--headless --import` 刷新缓存。
- SaveSlot 新字段有默认 → 不升 VERSION。
- 信号契约端到端测：`test_inn_rest_loop` 必须断言「对话选项触发 → `EventBus.inn_rested` 真发出」。
- MP 显示一律走 `game_state.hero_cur_mp / hero_max_mp` 单一来源。
- 物品使用统一通过 `EffectSystem`，不绕开。
- 测试目录与玩家存档物理隔离（沿用现有 GUT 测试沙盒约定）。
