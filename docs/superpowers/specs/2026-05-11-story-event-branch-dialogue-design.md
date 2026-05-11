# 剧情事件与分支对话基础切片设计

日期：2026-05-11
项目：liangyusheng-qunxiazhuan
目标引擎：Godot 4.6

## 目标

下一阶段创建“剧情事件与分支对话基础切片”，把当前线性对白推进到可配置的分支对话，并补齐剧情触发时的条件判断与事件执行入口。

当前项目已经具备地图、任务、背包、药铺、战斗、存档、官道拾取和 `EffectSystem`。`EffectSystem` 已经能统一执行“发生什么结果”，但项目还缺少统一回答“什么时候允许发生”和“玩家选择哪个分支后发生”的基础能力。本阶段目标是在不做大型剧情编辑器的前提下，建立轻量 `ConditionSystem`、`EventSystem` 和对话选项结构，让后续剧情、支线、NPC 状态变化和地图事件可以继续按数据扩展。

核心验证点：

- 对话可以显示多个玩家选项。
- 选项可以通过条件控制是否可用。
- 条件可以检查任务状态、flag、物品数量和地图对象状态。
- 选项触发后通过 `EventSystem` 调用 `EffectSystem` 执行结果。
- 对话选项可以跳转到指定后续对白。
- 示例 NPC 能验证“对话选择 -> 条件判断 -> 执行效果 -> 状态存档”的闭环。

## 范围

本阶段包含：

- 新增 `scripts/systems/condition_system.gd`。
- 新增 `scripts/systems/event_system.gd`。
- 扩展 `scripts/systems/effect_system.gd`，增加 `remove_item` 效果。
- 扩展 `scripts/systems/dialogue_system.gd`，读取对话选项和后续对白。
- 扩展 `scripts/scenes/dialogue_box.gd`，支持显示选项按钮并发出选项选择信号。
- 扩展 `scripts/scenes/map_screen_base.gd`，接收对话选项并执行事件效果。
- 扩展 `data/dialogues.json`，为示例 NPC 增加分支对白。
- 扩展 `data/maps.json`，在村外官道增加 `赶路书生` NPC。
- 增加系统层测试和示例数据测试。
- 更新 `README.md` 和 `docs/godot-project-structure.md`。

本阶段不做：

- 不做完整剧情编辑器。
- 不做复杂脚本语言。
- 不做多层嵌套条件表达式。
- 不做大段新剧情章节。
- 不做正式 UI 美术重做。
- 不做全量历史对白迁移，只迁移一个示例闭环验证能力。
- 不做事件事务回滚；内容数据应避免把可能失败的效果放在已产生副作用的效果之后。
- 不新增新的大地图、室内地图或新战斗敌人。

## 推荐方案

采用“轻量条件系统 + 事件执行器 + 对话选项复用事件效果”的方案。

只做分支对话会让条件判断和效果执行继续散落在场景脚本中；只做事件系统又缺少玩家可感知的玩法验证。当前 `EffectSystem` 已经稳定，下一步应该让分支对话把条件与效果都交给系统层处理：`DialogueBox` 只负责展示和发出选择，`DialogueSystem` 只负责读取对话数据，`EventSystem` 负责条件校验和效果执行，`EffectSystem` 继续负责实际状态修改。

示例内容放在村外官道。玩家完成“送信到客栈”后进入官道，与 `赶路书生` 对话：

- 选择“询问路上异动”，写入一条官道线索 flag。
- 选择“赠予小还丹”，如果背包有 `小还丹`，扣除 1 个并获得铜钱或线索。
- 如果没有 `小还丹`，该选项不可用或返回中文不可用原因。

这样一个小闭环可以同时验证分支对话、任务条件、物品条件、效果执行、flag/铜钱/背包变化和存档恢复。

## 架构

项目继续保持“领域逻辑、系统流程、场景表现”分层。

- `data/dialogues.json` 保存对白行、选项、选项条件、选项效果和后续对白编号。
- `data/maps.json` 保存村外官道中的 `赶路书生` NPC 对象。
- `scripts/core/game_state.gd` 继续保存任务、flag、背包、铜钱、地图对象状态和存档数据。
- `scripts/systems/condition_system.gd` 统一判断事件和对话选项条件。
- `scripts/systems/effect_system.gd` 继续统一执行状态修改，并新增扣除物品效果。
- `scripts/systems/event_system.gd` 先判断条件，再执行效果。
- `scripts/systems/dialogue_system.gd` 从数据读取对白行、选项和后续对白。
- `scripts/scenes/dialogue_box.gd` 显示对白和选项按钮，不直接修改游戏状态。
- `scripts/scenes/map_screen_base.gd` 连接对话选项信号，调用 `EventSystem`，刷新 HUD/背包/消息。
- `tests/` 保存条件、事件、对话选项、示例内容和现有流程回归测试。

`ConditionSystem` 只负责判断“是否满足条件”。`EventSystem` 只负责“条件满足后执行效果”。`EffectSystem` 只负责“修改结果”。场景脚本只负责“玩家触发和展示反馈”。

## 数据设计

### 条件数组

条件统一使用数组结构，数组内为 AND 语义：

```json
"conditions": [
  {"type": "quest_status", "quest_id": "quest_deliver_letter", "status": "completed"},
  {"type": "has_item", "item_id": "herb_small", "amount": 1},
  {"type": "not", "condition": {"type": "flag_equals", "key": "helped_road_scholar", "value": true}}
]
```

第一版支持：

- `quest_status`：检查任务状态。
- `flag_equals`：检查 `GameState` flag 值。
- `has_item`：检查背包物品数量。
- `map_object_resolved`：检查地图对象是否已解决。
- `not`：对单个条件取反。

不支持 OR、任意表达式、脚本函数调用或多层复杂嵌套。需要 OR 时，内容数据可以拆成多个选项或多个事件。

### 事件结构

事件可以内联在对话选项或地图对象中。第一版不单独新增 `data/events.json`，避免过早引入事件库管理。

```json
{
  "conditions": [
    {"type": "has_item", "item_id": "herb_small", "amount": 1}
  ],
  "effects": [
    {"type": "remove_item", "item_id": "herb_small", "amount": 1},
    {"type": "add_coins", "amount": 30},
    {"type": "set_flag", "key": "helped_road_scholar", "value": true}
  ]
}
```

条件缺失或为空时视为满足。效果缺失或为空时事件可以成功但不产生状态修改，用于纯跳转对白。

### 对话选项

对话记录保留现有 `lines` 字段，并增加 `options`：

```json
{
  "id": "road_scholar_intro",
  "title": "官道书生",
  "lines": [
    {"speaker": "赶路书生", "text": "少侠若往东去，还请多留意路旁车辙。"}
  ],
  "options": [
    {
      "id": "ask_road_unrest",
      "text": "询问路上异动",
      "conditions": [
        {"type": "quest_status", "quest_id": "quest_deliver_letter", "status": "completed"},
        {"type": "not", "condition": {"type": "flag_equals", "key": "clue_road_unrest", "value": true}}
      ],
      "effects": [
        {"type": "set_flag", "key": "clue_road_unrest", "value": true}
      ],
      "next_dialogue_id": "road_scholar_rumor",
      "unavailable_text": "先处理完村中托信，再来细问。"
    },
    {
      "id": "give_medicine",
      "text": "赠予小还丹",
      "conditions": [
        {"type": "has_item", "item_id": "herb_small", "amount": 1},
        {"type": "not", "condition": {"type": "flag_equals", "key": "helped_road_scholar", "value": true}}
      ],
      "effects": [
        {"type": "remove_item", "item_id": "herb_small", "amount": 1},
        {"type": "add_coins", "amount": 30},
        {"type": "set_flag", "key": "helped_road_scholar", "value": true}
      ],
      "next_dialogue_id": "road_scholar_thanks",
      "unavailable_text": "背包中没有小还丹。"
    }
  ]
}
```

`DialogueSystem` 负责返回选项数据和条件可用性。`DialogueBox` 显示所有选项；条件不满足的选项第一版可以禁用，并保留不可用原因供 HUD 消息或测试读取。

### 地图对象

村外官道新增 NPC 对象：

```json
{
  "id": "npc_road_scholar",
  "type": "npc",
  "name": "赶路书生",
  "position": {"x": 620, "y": 300},
  "dialogue_id": "road_scholar_intro"
}
```

该对象不承担特殊场景脚本逻辑，只通过 `dialogue_id` 打开分支对话。

## 关键组件

### ConditionSystem

新增 `scripts/systems/condition_system.gd`。

主要接口：

- `are_conditions_met(game_state, conditions, context = {})`
- `is_condition_met(game_state, condition, context = {})`

返回结果建议为字典：

- `success`：条件结构是否可正常判断。
- `met`：条件是否满足。
- `failed_conditions`：未满足条件数量。
- `errors`：中文错误消息数组。
- `messages`：中文不可用原因数组。

错误处理：

- 非数组 `conditions` 返回错误。
- 未知条件类型返回错误。
- 缺少必要字段返回错误。
- `amount <= 0` 的物品条件返回错误。
- 缺少 `game_state` 返回错误。

### EventSystem

新增 `scripts/systems/event_system.gd`。

主要接口：

- `apply_event(game_state, event_data, context = {})`

流程：

1. 读取 `conditions`。
2. 调用 `ConditionSystem` 判断。
3. 条件不满足时返回 `success = false`、`applied = 0`，不执行任何效果。
4. 条件满足时读取 `effects`。
5. 调用 `EffectSystem.apply_effects()`。
6. 合并条件消息、效果消息和错误，返回给场景层。

`EventSystem` 不直接修改背包、任务、flag 或地图对象状态。

### EffectSystem

扩展 `scripts/systems/effect_system.gd`。

新增效果类型：

```json
{"type": "remove_item", "item_id": "herb_small", "amount": 1}
```

规则：

- `item_id` 不能为空。
- `amount` 必须大于 0。
- 背包数量不足时失败并返回中文错误。
- 成功后扣除物品，并在结果中记录扣除项，便于 HUD 显示。

既有效果类型保持兼容。

### DialogueSystem

扩展 `scripts/systems/dialogue_system.gd`。

新增能力：

- `get_dialogue(dialogue_id)` 返回完整对话记录的安全副本。
- `get_options(dialogue_id)` 返回原始选项数组。
- `build_dialogue_state(dialogue_id, game_state)` 返回 `lines`、`options`、可用性和不可用原因。

`DialogueSystem` 不执行效果，只准备 UI 和系统层需要的数据。

### DialogueBox

扩展 `scripts/scenes/dialogue_box.gd`。

新增能力：

- 显示当前对白的选项按钮。
- 选项存在时，隐藏或弱化原“继续”按钮的结束行为。
- 条件不满足的选项显示为禁用状态。
- 玩家点击可用选项时发出 `option_selected(option_data)` 信号。
- 没有选项时保持现有线性对白行为。

第一版选项数量控制在 2 到 4 个，避免 UI 重排复杂化。

### MapScreenBase

扩展 `scripts/scenes/map_screen_base.gd`。

新增能力：

- 持有 `ConditionSystem` 和 `EventSystem` 实例。
- 打开对话时传入 `game_state` 构造对话状态。
- 接收 `DialogueBox.option_selected`。
- 执行选项事件效果。
- 根据 `next_dialogue_id` 打开后续对白。
- 根据结果刷新 HUD、背包、铜钱和短消息。

地图个性化脚本不硬写 `赶路书生` 的奖励和条件。

## 示例玩法流程

1. 玩家完成“送信到客栈”。
2. 玩家从山脚村镇进入村外官道。
3. 玩家与 `赶路书生` 交互。
4. 对话框显示对白和两个选项。
5. 玩家选择“询问路上异动”。
6. 系统检查 `quest_deliver_letter = completed` 且尚未记录官道线索。
7. 条件满足时写入 `clue_road_unrest` flag，并跳转到传闻对白。
8. 玩家选择“赠予小还丹”。
9. 系统检查背包有 `herb_small` 且尚未帮助过书生。
10. 条件满足时扣除 1 个 `小还丹`，增加 30 文铜钱，写入 `helped_road_scholar` flag，并跳转感谢对白。
11. 存档并读档后，线索、铜钱、背包和 flag 保持。

## 存档设计

本阶段不新增新的存档顶层结构。新增结果复用已有存档字段：

- `GameState.flags` 保存 `clue_road_unrest` 和 `helped_road_scholar`。
- 队伍背包保存 `herb_small` 数量变化。
- 队伍铜钱保存奖励变化。
- 任务状态和地图对象状态沿用已有结构。

读档后对话选项可用性应由当前存档状态重新计算，而不是保存 UI 状态。

## 错误处理

- 缺失对话编号时仍显示现有 fallback 文本。
- 缺失选项编号不应崩溃，但测试应覆盖并要求返回中文错误。
- 条件不满足时不执行效果。
- 条件结构错误时不执行效果。
- 效果执行失败时返回中文错误并显示安全短消息。
- 后续对白编号缺失时，关闭对话并显示安全提示，不阻断地图操作。

## 测试计划

逻辑测试继续使用 Godot 无头脚本运行。

需要新增或扩展测试：

- `ConditionSystem` 可以判断任务状态。
- `ConditionSystem` 可以判断 flag 值。
- `ConditionSystem` 可以判断背包物品数量。
- `ConditionSystem` 可以判断地图对象已解决状态。
- `ConditionSystem` 支持 `not`。
- 未知条件类型返回错误且不崩溃。
- `EventSystem` 条件不满足时不执行效果。
- `EventSystem` 条件满足时执行 `EffectSystem`。
- `EffectSystem.remove_item` 可以扣除物品。
- `EffectSystem.remove_item` 在物品不足时失败。
- `DialogueSystem` 能读取对话选项。
- `DialogueSystem` 能返回选项可用性和不可用原因。
- `DialogueBox` 没有选项时保持线性对白行为。
- 示例 `赶路书生` 对话数据存在且包含两个选项。
- 示例选项可以写入线索 flag。
- 示例赠药选项可以扣除小还丹并增加铜钱。
- 存档读档后 flag、铜钱和背包变化保持。
- 现有山道试剑、送信任务、药铺、官道包裹、战斗胜利回流测试继续通过。

人工验收：

1. 新开或继续游戏，完成“送信到客栈”。
2. 进入村外官道。
3. 与 `赶路书生` 对话。
4. 确认对话框显示分支选项。
5. 选择“询问路上异动”，确认显示传闻对白并写入线索。
6. 背包有 `小还丹` 时选择“赠予小还丹”，确认小还丹减少 1 个，铜钱增加，显示感谢对白。
7. 背包没有 `小还丹` 时，确认赠药选项不可用或显示中文不可用原因。
8. 存档，回主菜单，继续游戏。
9. 确认线索、铜钱和背包变化保持。

## 验收标准

本阶段完成后，项目应具备最小剧情事件管线：内容数据可以声明条件、对话选项和效果，玩家在对话中选择分支后，系统层统一判断条件并执行效果。

验收不是完整剧情编辑器，而是证明当前 RPG 框架已经具备可扩展的剧情触发、分支选择、条件 gating 和事件结果执行能力。

## 实现约束

- 所有玩家可见文本必须使用中文。
- 代码标识符、Godot API、路径和配置键可以保留英文。
- 不引入外部插件。
- 不提交 Godot 引擎二进制。
- 逻辑优先写测试，再实现。
- `ConditionSystem` 是条件判断的唯一通用入口。
- `EventSystem` 是条件事件执行的唯一通用入口。
- `EffectSystem` 是状态修改效果的唯一通用入口。
- `DialogueBox` 不直接修改游戏状态。
- `MapScreenBase` 不硬写示例 NPC 的奖励、任务状态或 flag。
- 本阶段不修改 `.spec-workflow/`、`.superpowers/` 或 `.tools/`。
