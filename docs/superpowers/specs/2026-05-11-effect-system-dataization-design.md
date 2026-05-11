# 任务奖励与效果数据化基础切片设计

日期：2026-05-11
项目：liangyusheng-qunxiazhuan
目标引擎：Godot 4.6

## 目标

下一阶段创建“任务奖励与效果数据化基础切片”，把任务完成、地图拾取和战斗胜利回流中的结果处理收敛到统一的效果执行入口。

当前项目已经具备地图、任务、背包、商店、战斗、武学熟练度和存档基础能力。后续继续增加内容时，如果奖励、线索、任务状态和地图对象状态继续散落在场景脚本中，扩展成本会快速上升。本阶段的重点是补齐框架能力，让内容数据能声明“发生了什么结果”，由系统层统一执行。

核心验证点：

- 任务完成奖励可以通过数据声明并执行。
- 地图拾取奖励可以通过同一套效果结构执行。
- 战斗胜利后的任务推进、地图对象解决和武学熟练度奖励可以接入效果系统。
- 效果执行结果可测试，并能通过存档和读档保持。
- 现有玩家流程体验不变。

## 范围

本阶段包含：

- 新增 `scripts/systems/effect_system.gd`。
- 支持 `effects` 数组数据结构。
- 支持基础效果类型：`add_item`、`add_coins`、`set_flag`、`set_quest_status`、`resolve_map_object`、`add_martial_proficiency`。
- `quests.json` 新增 `complete_effects`，优先用于任务完成结果。
- `maps.json` 的拾取对象支持 `effects`，逐步替代拾取专用奖励字段。
- 山道试剑完成、送信到客栈完成、官道路边包裹拾取接入效果系统。
- 山道强人战胜利回流中的清对象、推进任务和武学熟练度奖励接入效果系统。
- 保留旧奖励字段的兼容读取，避免一次性迁移造成行为回退。
- 增加效果系统单测和已有流程回归测试。
- 更新 `README.md` 和 `docs/godot-project-structure.md`。

本阶段不做：

- 不做完整剧情事件编辑器。
- 不做复杂条件表达式。
- 不做对话选择 UI。
- 不重写整个任务系统。
- 不新增大型剧情内容。
- 不做随机事件系统。
- 不把所有历史字段一次性删除。

## 推荐方案

采用“统一 `EffectSystem` + 小步集成”方案。

只做任务奖励数据化改动最小，但无法解决地图拾取、战斗胜利和对象状态逻辑分散的问题。直接做完整事件管线又会把范围扩大到条件系统、事件触发器和剧情编辑结构。本阶段只建立效果执行层，让已有触发点继续由现有系统判断，触发后的结果统一交给 `EffectSystem`。

这样可以在不改变玩家体验的前提下，把框架能力向前推进一步，并为后续对话分支、遭遇配置和剧情事件系统留下清晰接口。

## 架构

项目继续保持“领域逻辑、系统流程、场景表现”分层。

- `data/quests.json` 保存任务静态数据和任务完成效果。
- `data/maps.json` 保存地图对象和拾取对象效果。
- `scripts/core/game_state.gd` 保存队伍、铜钱、任务状态、地图状态、线索 flag、武学熟练度和存档数据。
- `scripts/systems/effect_system.gd` 统一执行数据声明的效果。
- `scripts/systems/quest_system.gd` 继续保存和修改任务状态。
- `scripts/systems/map_reward_system.gd` 继续作为拾取奖励入口，但内部委托 `EffectSystem`。
- `scripts/systems/combat_system.gd` 继续处理战斗回合规则，不负责发放外部奖励。
- `scripts/scenes/map_screen_base.gd`、`mountain_pass_screen.gd` 和 `foot_village_screen.gd` 只负责交互触发和展示消息。
- `scripts/scenes/battle_screen.gd` 或战斗回流入口负责在胜利时执行胜利效果。
- `tests/` 保存效果执行、错误路径、任务完成、拾取、战斗胜利和存档回归测试。

`EffectSystem` 只负责“执行结果”，不判断“玩家是否满足触发条件”。任务是否可交付、出口是否解锁、战斗是否胜利，仍由现有系统和场景流程判断。

## 数据设计

### 通用效果数组

效果统一使用数组结构：

```json
"effects": [
  {"type": "add_item", "item_id": "herb_small", "amount": 1},
  {"type": "add_coins", "amount": 20},
  {"type": "set_flag", "key": "clue_foot_village", "value": "掌柜提到飞红巾踪迹"},
  {"type": "set_quest_status", "quest_id": "quest_deliver_letter", "status": "completed"},
  {"type": "resolve_map_object", "object_id": "pickup_roadside_bundle"},
  {"type": "add_martial_proficiency", "martial_art_id": "basic_sword", "amount": 1}
]
```

字段规则：

- `type` 是必填字段。
- 数量字段 `amount` 必须为正整数。
- 文本、任务编号、物品编号、对象编号和武学编号必须为非空字符串。
- `set_quest_status.status` 只能使用现有任务状态。

### 任务完成效果

任务数据增加 `complete_effects`：

```json
{
  "id": "quest_deliver_letter",
  "title": "送信到客栈",
  "description": "替村口脚夫把书信送到客栈陆掌柜手中。",
  "start_dialogue": "foot_village_porter_intro",
  "complete_dialogue": "deliver_letter_complete",
  "complete_effects": [
    {"type": "set_quest_status", "quest_id": "quest_deliver_letter", "status": "completed"},
    {"type": "set_flag", "key": "clue_foot_village", "value": "掌柜提到飞红巾踪迹"}
  ]
}
```

旧字段 `reward_items`、`reward_item_amounts` 和 `reward_flags` 暂时保留兼容。实现时应优先读取 `complete_effects`；缺少新字段时，再走旧字段转换或旧逻辑。

### 地图拾取效果

拾取对象增加 `effects`：

```json
{
  "id": "pickup_roadside_bundle",
  "type": "pickup",
  "name": "路边包裹",
  "position": {"x": 620, "y": 340},
  "radius": 56,
  "effects": [
    {"type": "add_item", "item_id": "herb_small", "amount": 1},
    {"type": "add_coins", "amount": 20},
    {"type": "resolve_map_object", "object_id": "pickup_roadside_bundle"}
  ]
}
```

拾取对象是否已经领取仍由 `MapState.resolved_objects` 判断。`EffectSystem` 不做全局幂等，避免把触发条件和结果执行混在一起。

### 战斗胜利效果

山道强人战胜利效果可以先由战斗上下文或地图对象数据提供：

```json
"victory_effects": [
  {"type": "set_quest_status", "quest_id": "quest_mountain_trial", "status": "ready_to_complete"},
  {"type": "resolve_map_object", "object_id": "enemy_bandit_gate"},
  {"type": "add_martial_proficiency", "martial_art_id": "basic_sword", "amount": 1}
]
```

本阶段不要求完整战斗遭遇数据化，只把现有胜利结果改为效果系统执行。后续做“战斗遭遇数据化”时，可以直接复用 `victory_effects`。

## 关键组件

### EffectSystem

新增 `scripts/systems/effect_system.gd`。

主要接口：

- `apply_effects(game_state, effects, context = {})`
- `apply_effect(game_state, effect, context = {})`

返回结果建议为字典：

- `success`：是否至少有一个效果成功执行，且没有阻断性错误。
- `applied`：成功执行的效果数量。
- `failed`：失败的效果数量。
- `messages`：中文结果消息数组。
- `errors`：中文错误消息数组。

第一版支持：

- `add_item`：调用 `game_state.party.add_item(item_id, amount)`。
- `add_coins`：调用 `game_state.party.add_coins(amount)`。
- `set_flag`：调用 `game_state.set_flag(key, value)`。
- `set_quest_status`：根据状态调用或扩展 `QuestSystem`。
- `resolve_map_object`：调用 `game_state.resolve_map_object(object_id)`。
- `add_martial_proficiency`：调用 `game_state.add_martial_proficiency(martial_art_id, amount)`。

`EffectSystem` 不直接访问 UI，不切换场景，不播放动画，不判断任务是否可交付。

### QuestSystem

`QuestSystem` 继续保留现有状态常量和方法。

为支持 `set_quest_status`，可以新增一个受控方法：

- `set_status(quest_id, status)`

规则：

- `quest_id` 为空时失败。
- `status` 必须是 `not_started`、`active`、`ready_to_complete`、`completed` 之一。
- 成功时写入 `quest_status`。

现有 `start_quest()`、`mark_ready_to_complete()` 和 `complete_quest()` 保留，用于流程语义清晰的地方。

### MapRewardSystem

`MapRewardSystem` 保持拾取入口职责：

- 判断 `game_state` 和对象是否有效。
- 判断对象是否已经在 `resolved_objects` 中。
- 读取拾取对象 `effects`。
- 调用 `EffectSystem.apply_effects()`。
- 返回适合 HUD 展示的中文消息。

兼容策略：

- 对象存在 `effects` 时，使用 `effects`。
- 对象缺少 `effects` 但存在旧奖励字段时，将旧字段转换成效果数组执行。
- 奖励全部无效时不标记对象已解决。

### GameState

`GameState` 已保存 `party`、`quest_system`、`map_state`、`flags` 和 `martial_proficiency`。

本阶段需要保证这些能力可供 `EffectSystem` 调用：

- 添加物品。
- 添加铜钱。
- 设置 flag。
- 修改任务状态。
- 标记地图对象已解决。
- 增加武学熟练度。

这些结果必须继续进入 `to_dictionary()` 和 `from_dictionary()`，保证存档恢复。

### 场景脚本

场景脚本只保留触发职责：

- 山道 NPC 交付任务时，读取任务 `complete_effects` 并执行。
- 村镇掌柜完成送信时，读取任务 `complete_effects` 并执行。
- 地图拾取时，调用 `MapRewardSystem.claim_pickup()`。
- 战斗胜利返回地图时，执行胜利效果。

场景脚本可以负责显示系统返回的消息，但不应直接发放奖励或硬写 flag。

## 玩家流程

### 山道试剑

1. 玩家接到“山道试剑”任务。
2. 玩家击败山道强人。
3. 胜利效果执行：强人触发点解决，任务变为可交付，基础剑法熟练度增加。
4. 玩家回到青衫客处交付。
5. 任务完成效果执行：任务完成，小还丹奖励发放。

### 送信到客栈

1. 玩家从脚夫处接到“送信到客栈”。
2. 玩家到客栈找陆掌柜。
3. 任务完成效果执行：任务完成，写入村镇线索 flag。
4. 玩家再到官道出口时，出口条件读取任务完成状态并允许进入。

### 官道路边包裹

1. 玩家进入村外官道。
2. 玩家查看路边包裹。
3. 拾取效果执行：小还丹增加，铜钱增加，包裹对象进入已解决列表。
4. 玩家存档并读档。
5. 包裹不再生成，奖励结果保持。

## 错误处理

错误处理规则：

- `effects` 不是数组时，返回失败，不修改状态。
- 单个效果不是字典时，跳过该效果并记录错误。
- 缺少 `type` 时，跳过该效果并记录错误。
- 未知 `type` 时，跳过该效果并记录错误。
- `add_item` 缺少 `item_id` 或 `amount` 非正数时失败。
- `add_coins` 的 `amount` 非正数时失败。
- `set_flag` 缺少 `key` 时失败。
- `set_quest_status` 缺少 `quest_id` 或状态非法时失败。
- `resolve_map_object` 缺少 `object_id` 时失败。
- `add_martial_proficiency` 缺少 `martial_art_id` 或 `amount` 非正数时失败。
- 执行多个效果时，单个效果失败不回滚已成功效果。
- 系统返回中文错误消息，便于测试和临时 HUD 展示。

不做事务回滚是刻意选择。当前效果都作用于本地单机状态，失败路径应通过数据测试提前发现；引入事务会显著增加复杂度。

## 测试

逻辑测试继续使用 Godot 无头脚本运行。

需要覆盖：

- `EffectSystem` 可以添加物品。
- `EffectSystem` 可以添加铜钱。
- `EffectSystem` 可以设置 flag。
- `EffectSystem` 可以设置任务状态。
- `EffectSystem` 可以标记地图对象已解决。
- `EffectSystem` 可以增加武学熟练度。
- 未知效果类型返回错误且不崩溃。
- 缺少必要字段返回错误。
- 非法数量返回错误。
- 非法任务状态返回错误。
- `quests.json` 的任务完成效果数据可读取。
- 山道试剑胜利后任务变为可交付，强人对象解决，基础剑法熟练度增加。
- 山道试剑交付后通过效果获得小还丹。
- 送信到客栈完成后通过效果写入线索 flag。
- 官道路边包裹通过效果获得小还丹和铜钱。
- 官道路边包裹领取后进入已解决对象列表。
- 读档后背包、铜钱、flag、任务状态、武学熟练度和已解决对象保持。
- 缺少 `effects` 的旧奖励字段仍能兼容执行。

人工验收：

1. 新开游戏，完成山道强人战。
2. 确认强人不重复出现，山道试剑可交付，基础剑法熟练度增加。
3. 交付山道试剑，确认获得小还丹。
4. 完成送信到客栈，确认官道出口解锁。
5. 进入村外官道，拾取路边包裹。
6. 确认小还丹和铜钱增加，包裹消失。
7. 存档并读档，确认上述状态保持。

## 验收标准

本阶段完成后，任务完成、地图拾取和战斗胜利的核心结果应能通过统一 `effects` 数据结构声明，并由 `EffectSystem` 执行。

现有三条闭环必须保持可玩：

- 山道试剑：战斗胜利、任务交付、物品奖励、武学熟练度。
- 送信到客栈：任务完成、线索 flag、官道出口解锁。
- 官道路边包裹：物品奖励、铜钱奖励、对象消失、读档不重复。

## 实现约束

- 所有玩家可见文本必须使用中文。
- 代码标识符、Godot API、路径和配置键保留英文。
- 不引入外部插件。
- 不提交 Godot 引擎二进制。
- 逻辑优先写测试，再实现。
- `EffectSystem` 是数据化效果执行的唯一入口。
- `EffectSystem` 不负责触发条件判断。
- `MapRewardSystem` 仍是拾取交互入口，但奖励发放委托 `EffectSystem`。
- 场景脚本不直接硬写新增奖励、flag、任务状态和地图对象解决逻辑。
- 本阶段不修改 `.spec-workflow/`、`.superpowers/` 或 `.tools/`。
