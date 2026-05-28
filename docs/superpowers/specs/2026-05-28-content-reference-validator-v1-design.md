# 内容引用校验器 v1 设计规格书

## 1. 阶段定位

地图编辑闭环 v1 已经能在 Godot 编辑器 Dock 中新增和编辑地图对象模板。新增对象只创建入口引用，例如 `dialogue_id`、`quest_id`、`target_map_id`、`target_spawn_id`、`actor_id`、`battle_id` 和 `effects`，不展开编辑对白、任务或战斗正文。

本阶段目标是补上“引用是否还连得上”的反馈：当 AI 或用户修改 JSON 后，地图预览 Dock 能立即指出当前地图对象引用了不存在的内容。v1 只服务当前打开地图的空间编辑闭环，不做全项目剧情体检。

## 2. 范围

### 2.1 本阶段支持

- 校验当前地图 `objects` 中的直接引用。
- 在现有地图预览 Dock 的校验区域合并显示布局错误和内容引用错误。
- 输出结构化问题记录，保留 `object_id`、`field`、`severity` 和 `message`，为后续点击定位对象留接口。
- 使用当前项目真实数据口径：地图对象和对白选项里的战斗上下文直接进入战斗系统；项目目前没有独立 `battle_id` 数据表。

### 2.2 本阶段不支持

- 不追进对白树校验 `next_dialogue_id`。
- 不扫描所有对白选项的 `conditions`、`effects` 和 `battle_context`。
- 不扫描任务 `complete_effects`。
- 不创建缺失对白、任务或战斗模板。
- 不做点击错误定位。
- 不新增独立战斗/遭遇数据表。
- 不把 warnings 当成保存阻断。

## 3. 用户体验

Dock 继续使用现有“校验结果”区域。

显示规则：

1. 先显示布局校验错误，例如布局引用不存在的对象、非法半径、非法障碍尺寸。
2. 再显示内容引用错误，例如对象引用不存在的对白、任务、角色、物品或目标地图。
3. 最后显示 warning，例如 `battle_id` 当前没有可校验的数据源。
4. 有 error 时整体红字显示；只有 warning 时黄字显示；没有问题时显示绿色 `校验通过`。

问题文案要能让用户直接修 JSON，例如：

```text
[npc_qingshanke.dialogue_id] 对白不存在：missing_dialogue
[exit_to_road.target_spawn_id] 目标出生点不存在：road_outskirts/missing_spawn
[enemy_gate.units[1].actor_id] 角色不存在：bandit_missing
```

## 4. 架构设计

### 4.1 `ContentReferenceValidator`

新增 `addons/map_preview/content_reference_validator.gd`。

职责：

- 读取并索引 `data/actors.json`、`data/items.json`、`data/quests.json`、`data/dialogues.json` 和 `data/maps.json`。
- 按需读取 `data/map_layouts/<map_id>.json`，用于校验 `target_spawn_id`。
- 校验当前地图对象的直接引用。
- 返回结构化问题数组，不直接操作 Dock UI。

核心接口：

```gdscript
func validate_map(map_data: Dictionary) -> Array[Dictionary]
```

返回项格式：

```gdscript
{
    "severity": "error",
    "object_id": "npc_qingshanke",
    "field": "dialogue_id",
    "message": "对白不存在：missing_dialogue"
}
```

`severity` 第一版只使用 `error` 和 `warning`。

### 4.2 数据索引

校验器内部维护以下索引：

- `actors_by_id`
- `items_by_id`
- `quests_by_id`
- `dialogues_by_id`
- `maps_by_id`
- `layouts_by_map_id`

索引每次执行校验前从磁盘刷新，保证 AI 修改 JSON 后 Dock 下次刷新能看到最新引用状态。数据文件解析失败时返回 error，例如 `dialogues.json 格式错误`，并继续报告其他能校验的数据。

目标出生点校验使用 `data/map_layouts/<target_map_id>.json` 的 `spawn_points`。如果目标地图存在但布局文件不存在或没有 `spawn_points`，非空 `target_spawn_id` 报 error。

### 4.3 `MapPreviewPlugin` 集成

`MapPreviewPlugin._update_validation(map_data, layout)` 保持为 Dock 聚合入口：

1. 调用 `layout_loader.validate_layout(layout, map_data)` 得到布局错误字符串。
2. 调用 `content_reference_validator.validate_map(map_data)` 得到结构化引用问题。
3. 把布局错误转换为 error 文案，与引用问题合并。
4. 根据最高严重级别选择颜色并写入 `validation_label.text`。

`MapPreviewPlugin` 不直接读取 actors/items/quests/dialogues，不理解每种引用规则，只负责显示结果。

## 5. v1 校验规则

### 5.1 地图对象基础引用

对当前地图 `objects` 中每个字典对象：

- `dialogue_id` 非空时必须存在于 `data/dialogues.json`。
- `quest_id` 非空时必须存在于 `data/quests.json`。
- `required_quest_id` 非空时必须存在于 `data/quests.json`。
- `actor_id` 非空时必须存在于 `data/actors.json`。

空字符串表示未绑定引用，不报错。

### 5.2 出口引用

当对象 `type == "exit"`：

- `target_map_id` 为空时报 error。
- `target_map_id` 非空时必须存在于 `data/maps.json`。
- `target_spawn_id` 非空时必须存在于目标地图布局的 `spawn_points`。
- 如果目标地图不存在，不重复报告 `target_spawn_id` 缺失，避免噪声。

### 5.3 战斗触发点

当对象 `type == "battle_trigger"`：

- 顶层 `actor_id` 非空时必须存在于 `data/actors.json`。
- `units[].actor_id` 非空时必须存在于 `data/actors.json`。
- `quest_id` 和 `required_quest_id` 按普通任务引用校验。
- `victory_rewards.loot_table.entries[].item_id` 非空时必须存在于 `data/items.json`。
- `battle_id` 非空时产生 warning：当前项目没有独立 battle 数据源，暂不校验 `battle_id`。
- `encounter_id` 第一版视作标签，不报错。

### 5.4 效果引用

对地图对象直接声明的 `effects` 数组：

- `add_item`、`remove_item` 的 `item_id` 必须存在于 `data/items.json`。
- `set_quest_status` 的 `quest_id` 必须存在于 `data/quests.json`。
- `resolve_map_object` 的 `object_id` 必须存在于当前地图对象 id 集合。
- `add_party_member` 的 `actor_id` 必须存在于 `data/actors.json`。
- `add_martial_proficiency` 的 `martial_art_id` 暂不校验，因为本阶段不索引武学数据；后续可扩展。
- 未知效果类型不在本阶段报错，继续由运行时 `EffectSystem` 负责执行语义错误。

## 6. 错误处理

- JSON 文件不存在：对应索引为空，并报一条数据源错误。
- JSON 根节点不是数组：报数据源格式错误。
- 单个记录不是字典或缺少 `id`：跳过该记录，不阻断其他记录索引。
- `objects` 不是数组：报当前地图对象列表格式错误。
- `effects`、`units` 或 `loot_table.entries` 字段类型不对：报对应对象的字段格式错误。
- 校验器不得修改任何 JSON 文件。

## 7. 测试策略

新增 `tests/test_content_reference_validator.gd`，聚焦纯数据校验：

1. 合法地图对象不产生 error。
2. 缺失 `dialogue_id`、`quest_id`、`required_quest_id`、`actor_id` 会产生带 `object_id` 和 `field` 的 error。
3. 出口引用不存在的 `target_map_id` 或 `target_spawn_id` 会产生 error。
4. 战斗触发点 `units[].actor_id` 和掉落表 `item_id` 缺失会产生 error。
5. 地图对象 `effects` 中的 `item_id`、`quest_id`、`object_id`、`actor_id` 缺失会产生 error。
6. 非空 `battle_id` 只产生 warning，不产生 error。
7. 格式错误的数据源或字段返回清晰错误，不导致校验崩溃。

更新 `tests/run_tests.gd` 注册新测试。

为 `MapPreviewPlugin` 增加轻量源码测试或方法测试，确认 `_update_validation()` 会聚合布局错误和引用问题，并按 error/warning/green 三种状态输出颜色。

## 8. 验收标准

1. 当前地图对象引用不存在的对白、任务、角色、物品或目标地图时，Dock 显示红字错误。
2. 出口 `target_spawn_id` 指向不存在的目标出生点时，Dock 显示红字错误。
3. 战斗触发点里的敌方单位 `actor_id` 缺失时，Dock 显示红字错误。
4. 非空 `battle_id` 在没有独立 battle 数据源时只显示黄字 warning，不影响其他 error 显示。
5. 合法地图显示绿色 `校验通过`。
6. 校验器有自动化测试覆盖主要引用类型和错误格式。
7. 完整 Godot headless 测试通过。

## 9. 后续阶段

### 9.1 引用校验器 v1.5

- 扫描对白树中的 `next_dialogue_id`。
- 校验对白选项的 `conditions` 和 `effects`。
- 校验任务 `complete_effects`。
- 增加错误点击定位对象。

### 9.2 剧情内容工作台

- 从地图对象跳转到对应对白或任务。
- 创建缺失对白和任务模板。
- 展示对白树、任务阶段和引用反查。
- 后续再处理完整战斗配置、奖励配置和复杂条件编辑。
