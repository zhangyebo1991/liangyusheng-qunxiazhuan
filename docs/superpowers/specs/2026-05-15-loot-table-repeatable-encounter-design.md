# 战利品掉落与可重复遭遇设计

日期：2026-05-15
项目：liangyusheng-qunxiazhuan
目标引擎：Godot 4.6
状态：已确认

## 背景

当前游戏已经具备固定战斗奖励、等级成长、装备属性、背包、商店、客栈补给和胜利奖励面板。战斗胜利可以发放固定经验、铜钱和物品，但奖励仍是一次性配置，无法支撑长期刷取、装备来源和资源循环。

本阶段创建“战利品掉落与可重复遭遇”基础切片，让战斗成为稳定的经济来源。玩家可以通过一个可重复小型战斗获得少量铜钱、药品和低概率基础装备，并在胜利结算和背包中看到中文物品名。

## 目标

- 保留现有 `victory_rewards.exp`、`victory_rewards.coins` 和 `victory_rewards.items` 固定奖励。
- 在 `victory_rewards` 下新增嵌入式 `loot_table`，支持概率掉落。
- 概率掉落支持铜钱、消耗品和少量装备。
- 新增一个可重复挑战遭遇，胜利后不写入 `resolved_objects`。
- 胜利结算面板合并显示固定奖励和随机掉落。
- 玩家可见的掉落、背包、奖励面板、商店和物品展示必须使用中文物品名。
- 掉落逻辑可测试，并能通过可控随机源覆盖概率边界。

## 非目标

- 不新增独立 `data/loot_tables.json`。
- 不做稀有度、保底、权重池、掉落动画或评分结算。
- 不做装备自动穿戴、装备出售、装备强化或库存限制。
- 不做秘籍学习、秘籍残页合成或武学学习 UI。
- 不做可重复遭遇冷却、每日刷新、次数限制或动态难度。
- 不重做现有商店、背包、装备和成长系统。

## 核心规则

战斗胜利奖励分为固定奖励和随机掉落两部分。固定奖励继续使用现有 `victory_rewards` 字段。随机掉落由同一个 `victory_rewards` 内的 `loot_table` 声明，系统在胜利结算时掷骰并把结果写入队伍状态。

随机掉落只在胜利时结算。战斗失败、暂退或异常退出不发放固定奖励，也不掷掉落表。

可重复遭遇通过地图对象字段 `repeatable = true` 声明。可重复战斗胜利后仍发放奖励，但不自动把来源地图对象写入 `resolved_objects`，因此返回地图后仍可再次挑战。未声明 `repeatable` 的战斗保持现有一次性规则，胜利后仍默认标记来源对象已解决。

第一版可重复遭遇新增为“流窜山贼”，放在山道练功木桩附近。它比练功木桩更适合作为战利品来源，因为掉落药品和基础装备在语义上更自然。

## 数据设计

地图战斗对象继续放在 `data/maps.json`。第一版优先使用嵌入式掉落表，避免在内容量很小时新增独立数据文件。

示例：

```json
{
  "id": "enemy_roaming_bandit",
  "type": "battle_trigger",
  "name": "流窜山贼",
  "battle_mode": "tactical",
  "repeatable": true,
  "victory_rewards": {
    "exp": 12,
    "coins": 8,
    "items": [
      {"item_id": "herb_small", "amount": 1}
    ],
    "loot_table": {
      "rolls": 2,
      "entries": [
        {"type": "item", "item_id": "herb_focus", "chance": 0.35, "amount": 1},
        {"type": "item", "item_id": "iron_sword", "chance": 0.10, "amount": 1},
        {"type": "item", "item_id": "cloth_armor", "chance": 0.08, "amount": 1},
        {"type": "coins", "chance": 0.50, "amount_min": 3, "amount_max": 8}
      ]
    }
  }
}
```

字段规则：

- `repeatable`：可选布尔值。缺省为 `false`。
- `loot_table.rolls`：掷骰次数。小于等于 `0` 时不产生随机掉落。
- `loot_table.entries`：掉落候选列表。缺失或不是数组时视为空掉落表。
- `entry.type = "item"`：发放物品或装备，必须提供 `item_id`。
- `entry.type = "coins"`：发放铜钱，使用 `amount` 或 `amount_min` / `amount_max`。
- `entry.chance`：掉落概率，范围按 `0.0` 到 `1.0` 解释。小于等于 `0` 跳过，大于等于 `1` 必定掉落。
- `entry.amount`：固定数量。缺失时默认为 `1`。
- `entry.amount_min` / `entry.amount_max`：数量区间。若 `amount_min > amount_max`，按较小风险归一为 `amount_min`。

每次 roll 独立遍历 entries。第一版不做“从池中只选一个”的权重逻辑，因此同一场战斗可能从不同 entry 中获得多个奖励。装备也是普通 `item` 掉落，进入背包后继续复用现有装备系统。

## 系统设计

### LootSystem

新增 `scripts/systems/loot_system.gd`，作为随机掉落的单一规则入口。

职责：

- 读取 `loot_table`。
- 根据 `rolls`、`entries`、`chance` 和数量字段生成掉落结果。
- 支持注入可控随机源，便于测试概率边界。
- 返回结构化结果，不直接修改 `GameState`、背包或 UI。

不负责：

- 发放物品和铜钱。
- 校验物品是否存在。
- 显示中文物品名。
- 判断战斗胜负。

建议返回结构：

```gdscript
{
  "rolled": true,
  "coins": 6,
  "items": [
    {"item_id": "iron_sword", "amount": 1}
  ],
  "errors": []
}
```

### GameState

`GameState.apply_battle_result()` 继续作为战斗结算入口。胜利时仍先处理战斗胜利效果，再调用 `_apply_victory_rewards()`。

`_apply_victory_rewards()` 扩展为：

- 发放固定经验。
- 发放固定铜钱。
- 发放固定物品。
- 调用 `LootSystem` 生成随机掉落。
- 校验随机掉落中的物品是否存在。
- 把有效物品写入 `PartyState.inventory`，把铜钱写入 `PartyState.coins`。
- 把固定奖励和随机掉落合并到 `last_reward_result`。

建议 `last_reward_result` 结构：

```gdscript
{
  "experience": [],
  "coins": 21,
  "items": [
    {"item_id": "herb_small", "amount": 1, "source": "fixed"},
    {"item_id": "iron_sword", "amount": 1, "source": "loot"}
  ],
  "loot": {
    "rolled": true,
    "coins": 6,
    "items": [
      {"item_id": "iron_sword", "amount": 1}
    ],
    "errors": []
  }
}
```

`coins` 表示本场胜利总铜钱，包含固定铜钱和随机铜钱。`items` 表示本场胜利实际进入背包的全部物品。`source` 只供测试和后续 UI 分组使用，第一版奖励面板可以不显示来源。

### 可重复遭遇

战斗上下文或战斗结果需要携带 `repeatable`。`GameState._battle_victory_effects()` 在没有显式 `victory_effects` 时，根据 `repeatable` 决定是否生成默认 `resolve_map_object` 效果。

- `repeatable = true`：不自动生成 `resolve_map_object`。
- `repeatable = false` 或缺失：沿用现有默认行为。
- 如果数据显式声明 `victory_effects`，则继续以显式效果为准。可重复遭遇的数据不应显式加入 `resolve_map_object`，否则会变成一次性遭遇。

`MapObjectSpawner` 继续只根据 `resolved_objects` 过滤对象，不需要理解掉落表。这样可重复遭遇的长期存在仍由现有地图对象生成机制自然支持。

### BattleScreen

奖励面板继续从 `GameState.last_reward_result` 读取展示内容。它不计算掉落，不直接改背包。

玩家可见文本要求：

- 物品必须通过 `DataRepository.get_item(item_id).name` 显示中文名。
- 奖励面板、背包、商店和物品相关提示不得直接显示 `item_id`。
- 缺失物品资料时显示中文兜底“未知物品”，并记录错误或测试可见错误结果。
- 示例显示应为“小还丹 x1”“铁剑 x1”，不能显示 `herb_small`、`iron_sword`。

当前 `_item_display_name()` 缺失资料时会回退到 `item_id`。本阶段需要改为中文兜底，避免把内部编号暴露给玩家。

## 错误处理

- `loot_table` 缺失：只发固定奖励。
- `loot_table.entries` 为空或格式错误：视为空掉落表，不影响固定奖励。
- `chance <= 0`：跳过该 entry。
- `chance >= 1`：该 entry 必定掉落。
- `rolls <= 0`：不掷随机掉落。
- `item_id` 为空：跳过该物品，记录中文错误。
- `item_id` 不存在：不进入背包，奖励面板显示中文兜底或错误摘要，流程不崩溃。
- 数量小于等于 `0`：归一为 `1`，并在测试中覆盖该兼容行为。
- 战斗失败：不发固定奖励，不掷掉落表，`last_reward_result` 清空。

## 测试计划

- `test_loot_system.gd`：覆盖 `chance = 0`、`chance = 1`、空表、`rolls <= 0`、数量区间和可控随机源。
- `test_loot_system.gd`：覆盖铜钱掉落、物品掉落、多 roll 聚合和无掉落结果。
- `test_tactical_party_battle.gd` 或新增结算测试：覆盖固定奖励与随机掉落合并进入 `last_reward_result`。
- `test_tactical_party_battle.gd`：覆盖随机掉落铜钱进入 `PartyState.coins`，物品进入 `PartyState.inventory`。
- `test_tactical_party_battle.gd`：覆盖缺失物品不进入背包，且流程不崩溃。
- `test_map_object_spawner.gd` 或现有地图流测试：覆盖 `repeatable = true` 胜利后不写入 `resolved_objects`。
- 现有战斗回归测试：覆盖非 repeatable 战斗胜利后仍写入 `resolved_objects`。
- `test_battle_screen_reward_panel.gd`：覆盖奖励面板显示中文物品名，不显示 `item_id`。
- `test_hud_inventory.gd` 或背包相关测试：覆盖背包展示掉落装备时显示中文名。
- 全量 `tests/run_tests.gd` 保持通过。

## 手动验收

1. 新游戏进入山道。
2. 触发“流窜山贼”可重复战斗。
3. 胜利后奖励面板显示经验、铜钱和可能的掉落。
4. 奖励面板中的物品显示为“小还丹”“凝神丹”“铁剑”“布衣”等中文名。
5. 返回地图后，“流窜山贼”入口仍存在。
6. 多次挑战可以看到不同掉落结果。
7. 打开背包或队伍面板，掉落装备可见且显示中文名。
8. 原山道强人一次性战斗胜利后仍会消失。
9. 战斗失败或暂退不发放掉落。

## 风险与取舍

最大风险是随机掉落使测试不稳定。应通过 `LootSystem` 注入可控随机源，把随机行为压到可重复测试内。场景手动验收只验证体验，不承担概率精确性。

第二个风险是早期经济失控。第一版可重复遭遇奖励必须偏低：少量经验、少量铜钱、低概率基础装备。装备掉落只验证系统能力，不作为正式数值平衡。

第三个风险是显示层暴露内部编号。这个阶段把“玩家可见物品必须显示中文名”列为硬性约束，并用奖励面板与背包测试覆盖。

第四个风险是可重复遭遇破坏现有一次性战斗回流。设计上只让 `repeatable = true` 抑制默认 `resolve_map_object`，未声明字段的旧数据继续走原逻辑。

## 实现约束

- 遵守现有分层：领域数据、系统流程、场景展示分离。
- 随机掉落规则集中在 `LootSystem`。
- `BattleScreen` 不直接掷骰，不直接发放奖励。
- `MapObjectSpawner` 不理解掉落表，只根据 `resolved_objects` 过滤对象。
- 玩家可见文本必须使用中文。
- `item_id` 只能作为代码和数据关联，不能直接展示给玩家。
- 不修改 `.spec-workflow/`、`.superpowers/` 或 `.tools/`。
