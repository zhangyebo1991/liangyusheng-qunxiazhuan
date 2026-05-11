# 江湖记事基础切片设计

日期：2026-05-11
项目：liangyusheng-qunxiazhuan
目标引擎：Godot 4.6

## 目标

下一阶段创建“江湖记事基础切片”，把任务追踪和传闻记录从零散 flag 推进到可保存、可展示、可扩展的系统能力。

当前项目已经具备地图、任务、对话、分支事件、背包、商店、战斗、效果系统和存档基础。继续扩展剧情时，玩家需要稳定入口查看“当前有哪些任务”“江湖上听到了哪些传闻”“哪些传闻已经转成明确任务”。本阶段目标是在不做完整百科和导航系统的前提下，建立 `JournalState`、`JournalSystem` 和一个独立弹出的“江湖记事”页面。

核心验证点：

- 玩家可以通过 `J` 键或 HUD“记事”按钮打开独立页面。
- 页面可以查看任务列表、可追查传闻和已触发传闻。
- 任务列表最多允许勾选 3 个任务用于 HUD 追踪。
- 传闻可以由普通对白自动记录，也可以由事件效果显式记录。
- 传闻第一版只作为玩家可读信息，不直接参与剧情条件判断。
- 当相关任务触发后，对应传闻从“可追查传闻”移到“已触发传闻”。
- 任务追踪和传闻状态可以存档和读档恢复。

## 范围

本阶段包含：

- 新增 `scripts/domain/journal_state.gd`。
- 新增 `scripts/systems/journal_system.gd`。
- 扩展 `scripts/core/game_state.gd`，持有并序列化江湖记事状态。
- 扩展 `scripts/systems/effect_system.gd`，支持 `add_rumor` 和 `trigger_rumor` 效果。
- 扩展 `scripts/systems/dialogue_system.gd` 或地图对话接线，支持对白数据中的自动传闻记录字段。
- 扩展 `scripts/scenes/hud.gd`，增加“记事”按钮和最多 3 个追踪任务显示。
- 新增或扩展一个记事页面场景脚本，用于展示任务、传闻和追踪勾选。
- 扩展输入动作，地图中按 `J` 打开或关闭江湖记事。
- 扩展 `data/dialogues.json`，让官道书生传闻写入江湖记事。
- 增加系统层、UI 接线和存档回归测试。
- 更新 `README.md` 和 `docs/godot-project-structure.md`。

本阶段不做：

- 不显示未听到的传闻占位。
- 不做地图导航箭头、自动寻路或地点坐标提示。
- 不做传闻搜索、筛选、复杂分类或完整百科。
- 不把传闻作为 `ConditionSystem` 的条件类型。
- 不做完整任务详情富文本。
- 不做正式 UI 美术重做。
- 不新增大型地图或完整新剧情章节。
- 不引入独立 `data/journal.json`；第一版传闻文案先随对白或效果数据声明。

## 推荐方案

采用“独立江湖记事系统 + 轻量弹窗 UI”的方案。

只用 `GameState.flags` 保存传闻实现最快，但会继续让任务、线索和传闻语义混在一起，后续内容越多越难维护。完全引入 `data/journal.json` 又会过早扩大内容管线。本阶段先新增 `JournalState` 和 `JournalSystem`，把“玩家已经知道什么”和“玩家正在追踪什么”明确建模，同时保留以后集中数据化传闻资料的空间。

任务仍由 `QuestSystem` 管理真实状态。江湖记事不取代任务系统，只负责展示任务状态和保存玩家选择的追踪任务。传闻也不取代剧情条件；第一版传闻是玩家可读的江湖信息，相关任务触发后被归档到“已触发传闻”。

## 架构

项目继续保持“领域逻辑、系统流程、场景表现”分层。

- `scripts/domain/journal_state.gd` 保存可序列化的追踪任务、可追查传闻和已触发传闻。
- `scripts/systems/journal_system.gd` 处理添加传闻、归档传闻、切换任务追踪和生成 UI 数据。
- `scripts/core/game_state.gd` 持有 `journal_state`，随新游戏、存档和读档生命周期初始化。
- `scripts/systems/effect_system.gd` 继续作为状态修改效果的唯一通用入口，并新增传闻相关效果。
- `scripts/systems/dialogue_system.gd` 继续读取对白数据，可把对白记录中的传闻字段交给场景层处理。
- `scripts/scenes/map_screen_base.gd` 在对白结束或选项事件完成后，把自动传闻记录交给 `JournalSystem`。
- `scripts/scenes/hud.gd` 显示“记事”按钮、短消息和追踪任务摘要，不直接修改记事状态。
- 新的记事页面脚本显示任务和传闻，玩家点击追踪勾选时调用 `JournalSystem`。
- `tests/` 保存记事状态、系统规则、效果接入、对话自动记录、UI 接线和存档测试。

江湖记事状态属于玩家进度，不属于静态内容资料。任务状态仍由 `QuestSystem` 判断；传闻状态由 `JournalSystem` 判断；效果执行仍由 `EffectSystem` 统一入口完成。

## 数据设计

### JournalState

新增 `scripts/domain/journal_state.gd`。

保存字段：

- `tracked_quest_ids: Array[String]`：当前 HUD 追踪任务，最多 3 个。
- `active_rumors: Dictionary`：可追查传闻，key 为 `rumor_id`。
- `triggered_rumors: Dictionary`：已触发相关任务的传闻，key 为 `rumor_id`。

传闻记录建议结构：

```json
{
  "id": "rumor_road_red_thread",
  "title": "官道红线车辙",
  "text": "赶路书生说，官道车辙中夹着红线，疑似飞红巾一脉留下的记号。",
  "source": "赶路书生",
  "related_quest_id": "quest_trace_red_thread",
  "discovered_at_map_id": "road_outskirts"
}
```

读档兼容规则：

- 旧存档没有 `journal_state` 时初始化为空状态。
- `tracked_quest_ids` 不是数组时初始化为空数组。
- 传闻容器不是字典时初始化为空字典。
- 传闻记录缺少可选字段时用空字符串补齐。
- 追踪任务数量超过 3 个时只保留前 3 个有效字符串。

### 传闻记录数据

第一版不新增 `data/journal.json`。传闻可以直接写在对白或效果数据中。

对白自动记录示例：

```json
{
  "id": "road_scholar_rumor",
  "title": "车辙传闻",
  "lines": [
    {"speaker": "赶路书生", "text": "昨夜有马队沿官道急行，车辙深处夹着红线，像是飞红巾一脉留下的记号。"}
  ],
  "rumor": {
    "id": "rumor_road_red_thread",
    "title": "官道红线车辙",
    "text": "官道车辙中夹着红线，疑似飞红巾一脉留下的记号。",
    "source": "赶路书生",
    "related_quest_id": "quest_trace_red_thread"
  }
}
```

事件效果记录示例：

```json
{
  "type": "add_rumor",
  "rumor": {
    "id": "rumor_road_red_thread",
    "title": "官道红线车辙",
    "text": "官道车辙中夹着红线，疑似飞红巾一脉留下的记号。",
    "source": "赶路书生",
    "related_quest_id": "quest_trace_red_thread"
  }
}
```

普通对白适合用 `rumor` 自动记录。分支选择、告示、拾取和特殊事件适合用 `add_rumor` 效果显式记录。

### 传闻归档

传闻归档表示“这条传闻已经触发了相关任务”，不是删除历史。

支持两种入口：

- `JournalSystem.mark_rumors_triggered_for_quest(quest_id)`：根据 `related_quest_id` 批量归档。
- `EffectSystem` 的 `trigger_rumor` 效果：显式归档单条传闻。

效果示例：

```json
{"type": "trigger_rumor", "rumor_id": "rumor_road_red_thread"}
```

当后续实现任务启动效果或任务状态变为 `active` 时，应调用 `JournalSystem.mark_rumors_triggered_for_quest()`，让相关传闻自动从“可追查传闻”移动到“已触发传闻”。

## 关键组件

### JournalState

`JournalState` 只保存数据和序列化规则，不读任务数据，不访问场景节点。

主要接口：

- `to_dictionary()`
- `from_dictionary(data)`
- `normalize()`

它负责防御坏存档，但不负责业务判断。追踪上限、去重和传闻迁移规则放在 `JournalSystem`。

### JournalSystem

新增 `scripts/systems/journal_system.gd`。

主要接口：

- `add_rumor(journal_state, rumor_data, context = {})`
- `trigger_rumor(journal_state, rumor_id)`
- `mark_rumors_triggered_for_quest(journal_state, quest_id)`
- `toggle_tracked_quest(journal_state, quest_id)`
- `is_quest_tracked(journal_state, quest_id)`
- `build_task_entries(game_state, repository)`
- `build_tracked_task_entries(game_state, repository)`
- `build_rumor_entries(journal_state)`

规则：

- 空 `rumor_id` 失败。
- 空传闻正文失败。
- 重复添加同一传闻不重复写入。
- 添加已触发过的传闻时不把它移回可追查列表。
- 触发不存在的传闻时失败但不崩溃。
- 勾选第 4 个追踪任务时失败，保留原有 3 个。
- 取消追踪任务永远允许。
- 任务条目来自 `QuestSystem` 当前状态和 `data/quests.json` 静态资料。

返回结果使用字典，包含 `success`、`message`、`errors` 和必要的条目数据，便于 HUD 显示中文反馈和测试断言。

### GameState

扩展 `scripts/core/game_state.gd`。

新增职责：

- `start_new_game()` 初始化空 `JournalState`。
- `to_dictionary()` 写入 `journal_state`。
- `from_dictionary()` 读取并规范化 `journal_state`。

`GameState` 不直接实现传闻和追踪规则，只持有状态。

### EffectSystem

扩展 `scripts/systems/effect_system.gd`。

新增效果类型：

```json
{"type": "add_rumor", "rumor": {...}}
{"type": "trigger_rumor", "rumor_id": "rumor_road_red_thread"}
```

规则：

- `add_rumor` 委托 `JournalSystem.add_rumor()`。
- `trigger_rumor` 委托 `JournalSystem.trigger_rumor()`。
- 结果消息使用中文，例如“传闻已记入江湖记事。”。
- 既有效果类型保持兼容。

传闻本身不进入 `ConditionSystem`。如果后续需要“听过某传闻才能触发对话”，应另开设计讨论，避免本阶段扩大成情报条件系统。

### DialogueSystem 和 MapScreenBase

`DialogueSystem` 负责安全读取对白记录里的 `rumor` 字段。它不直接写入 `GameState`。

`MapScreenBase` 在以下时机处理自动传闻记录：

- 线性对白正常结束后。
- 分支选项跳转到后续对白并播放完成后。

处理流程：

1. 获取当前对白记录的 `rumor` 字段。
2. 如果存在，调用 `JournalSystem.add_rumor()`。
3. HUD 显示简短中文提示。
4. 重复传闻不重复显示强提示，避免玩家刷对话时被打扰。

### HUD

扩展 `scripts/scenes/hud.gd`。

新增能力：

- 显示“记事”按钮。
- 发出 `journal_requested` 信号。
- 显示最多 3 个追踪任务标题和简短状态。
- 在任务追踪变化、任务状态变化或读档后刷新追踪区。

HUD 只展示数据和发出请求，不直接修改 `JournalState`。

### 江湖记事页面

新增独立弹出页面，场景脚本可以命名为 `scripts/scenes/journal_panel.gd`，具体场景文件可在计划阶段确定。

页面结构：

- 顶部标题：`江湖记事`。
- 左侧：任务列表。
- 右侧上半：可追查传闻。
- 右侧下半：已触发传闻。
- 关闭按钮或 `Esc` 返回地图。

任务列表每行显示：

- 任务标题。
- 当前状态。
- 追踪勾选框。

传闻列表每条显示：

- 传闻标题。
- 来源。
- 正文。

交互规则：

- 按 `J` 打开或关闭页面。
- 点击 HUD“记事”按钮打开页面。
- 页面打开时，地图移动输入暂停或被忽略。
- 勾选任务时调用 `JournalSystem.toggle_tracked_quest()`。
- 勾选超过 3 个时保持原状态并显示中文提示。

## 示例玩法流程

1. 玩家完成“送信到客栈”。
2. 玩家进入村外官道。
3. 玩家与 `赶路书生` 对话并选择“询问路上异动”。
4. 后续对白 `road_scholar_rumor` 播放完成。
5. 系统自动把 `rumor_road_red_thread` 写入“可追查传闻”。
6. 玩家按 `J` 打开“江湖记事”，看到这条传闻。
7. 玩家在任务列表中勾选最多 3 个任务，HUD 显示追踪任务。
8. 后续任务 `quest_trace_red_thread` 触发时，系统把相关传闻移动到“已触发传闻”。
9. 玩家存档并读档后，追踪任务、可追查传闻和已触发传闻保持。

## 存档设计

`GameState.to_dictionary()` 新增顶层字段：

```json
{
  "journal_state": {
    "tracked_quest_ids": ["quest_mountain_trial", "quest_deliver_letter"],
    "active_rumors": {
      "rumor_road_red_thread": {
        "id": "rumor_road_red_thread",
        "title": "官道红线车辙",
        "text": "官道车辙中夹着红线，疑似飞红巾一脉留下的记号。",
        "source": "赶路书生",
        "related_quest_id": "quest_trace_red_thread",
        "discovered_at_map_id": "road_outskirts"
      }
    },
    "triggered_rumors": {}
  }
}
```

读档后 UI 不保存展开状态或选中行，只从 `JournalState` 和当前任务状态重新生成页面。

## 错误处理

- 添加空 `rumor_id` 返回失败，不写入状态。
- 添加空传闻正文返回失败，不写入状态。
- 重复添加同一传闻不重复记录。
- 触发不存在的传闻返回失败消息，不崩溃。
- 勾选第 4 个追踪任务返回失败，保留原有 3 个追踪任务。
- 旧存档没有 `journal_state` 时初始化为空。
- 坏存档中追踪任务和传闻结构异常时安全兜底。
- 记事页面缺少数据源时显示空状态，不阻断地图操作。
- 传闻自动记录失败时显示短消息或静默记录错误，但不打断对白流程。

## 测试计划

逻辑测试继续使用 Godot 无头脚本运行。

需要新增或扩展测试：

- `JournalState` 可以序列化追踪任务、可追查传闻和已触发传闻。
- `JournalState` 可以从旧存档空数据初始化。
- `JournalState` 可以防御坏存档类型。
- `JournalSystem.add_rumor()` 可以添加传闻。
- `JournalSystem.add_rumor()` 对重复传闻去重。
- `JournalSystem.add_rumor()` 拒绝空编号或空正文。
- `JournalSystem.trigger_rumor()` 可以把传闻从可追查列表移到已触发列表。
- `JournalSystem.trigger_rumor()` 对不存在传闻安全失败。
- `JournalSystem.mark_rumors_triggered_for_quest()` 可以按 `related_quest_id` 归档传闻。
- `JournalSystem.toggle_tracked_quest()` 可以追踪和取消追踪任务。
- 第 4 个追踪任务被拒绝，原有追踪列表不变。
- `EffectSystem.add_rumor` 可以写入江湖记事。
- `EffectSystem.trigger_rumor` 可以归档传闻。
- 对白 `rumor` 字段可以在播放完成后自动记录。
- HUD 可以显示最多 3 个追踪任务。
- 江湖记事页面可以显示任务、可追查传闻和已触发传闻。
- 存档读档后追踪任务和传闻状态保持。
- 现有任务、对话、战斗、商店、地图、分支事件测试继续通过。

人工验收：

1. 新开或继续游戏，完成“送信到客栈”。
2. 进入村外官道。
3. 与 `赶路书生` 对话并获得官道红线传闻。
4. 按 `J` 打开“江湖记事”。
5. 确认可追查传闻中显示官道红线传闻。
6. 在任务列表勾选 3 个以内任务。
7. 确认 HUD 显示追踪任务。
8. 尝试勾选第 4 个任务，确认中文提示且追踪列表不变。
9. 触发相关任务后，确认传闻移动到“已触发传闻”。
10. 存档，回主菜单，继续游戏。
11. 确认追踪任务和传闻状态保持。

## 验收标准

本阶段完成后，项目应具备可复用的江湖记事基础能力：任务可以被玩家有限追踪，传闻可以从对白或效果进入记事页面，传闻在相关任务触发后可以归档，所有状态可随存档恢复。

验收不是完整任务日志系统，也不是完整线索推理系统，而是证明后续剧情内容可以稳定复用“任务追踪 + 传闻记录 + 传闻归档”的底层能力。

## 实现约束

- 所有玩家可见文本必须使用中文。
- 代码标识符、Godot API、路径和配置键可以保留英文。
- 不引入外部插件。
- 不提交 Godot 引擎二进制。
- 逻辑优先写测试，再实现。
- `JournalState` 不依赖 Godot 场景节点。
- `JournalSystem` 是传闻和任务追踪规则的唯一通用入口。
- `EffectSystem` 是传闻写入和传闻归档效果的唯一通用入口。
- `HUD` 和记事页面不直接修改记事状态。
- 传闻第一版不作为剧情条件。
- 本阶段不修改 `.spec-workflow/`、`.superpowers/` 或 `.tools/`。
