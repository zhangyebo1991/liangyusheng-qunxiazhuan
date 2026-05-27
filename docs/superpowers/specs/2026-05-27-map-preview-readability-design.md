# 地图预览可读性增强设计规格书

## 1. 功能概述

当前 Godot 编辑器中的 `GeneratedMapPreview` 已能显示地图背景、障碍物、出生点、对象位置和交互半径，但对象只表现为点、圈和矩形。使用者无法直接判断某个位置对应 NPC、出口、战斗触发点还是出生点，地图预览仍需要反复对照 `data/maps.json` 和 `data/map_layouts/*.json`。

本阶段目标是让地图预览从“能看到布局”变成“能读懂布局”：打开 `mountain_pass.tscn`、`foot_village.tscn` 等地图场景后，每个预览元素都能显示清晰标签，右侧 Dock 能提供类型图例和对象列表。

## 2. 设计原则

### 2.1 不改变地图数据结构

本阶段只增强编辑器预览表现，不修改 `data/maps.json` 或 `data/map_layouts/*.json` 的字段结构。对象名称继续来自 `data/maps.json` 的 `name` 字段；布局位置、半径、障碍矩形继续来自 `data/map_layouts/<map_id>.json`。

### 2.2 标签优先服务编辑判断

标签默认显示“名称 + 类型”，格式为：

```text
青衫客 / NPC
去山脚村 / 出口
山贼伏击 / 战斗
```

如果对象没有中文名称，则使用对象 `id` 作为名称回退。出生点显示 `出生点 / <spawn_id>`，障碍物显示 `障碍 / <obstacle_id>`。

### 2.3 控制范围，先解决看不懂

本阶段不做素材化地图、不做真实角色图标、不做复杂筛选、不做点击定位，也不新增地图对象创建工具。对象列表先只读，用于识别和核对地图内容；后续阶段再扩展选中、高亮、定位和属性编辑。

## 3. 用户体验

### 3.1 地图标签

每个 `MapPreviewHandle` 在现有点、圈、矩形基础上增加文本标签：

- 对象：`<name 或 id> / <中文类型>`
- 出生点：`出生点 / <spawn_id>`
- 障碍物：`障碍 / <obstacle_id>`

标签放在圆形 handle 的右上方，障碍物标签放在矩形左上角附近。标签使用浅色背景、深色文字和与 handle 类型一致的边框色，保证在绿色地图背景、半透明障碍物和交互半径圈上仍可读。

### 3.2 类型中文化

预览层提供统一类型显示名称：

| 原始类型 | 标签类型 |
| --- | --- |
| `npc` | `NPC` |
| `battle_trigger` | `战斗` |
| `exit` | `出口` |
| `shop` | `商店` |
| `pickup` | `拾取` |
| `notice` | `提示` |
| 其他或缺失 | `对象` |

现有颜色规则继续保留，标签边框使用相同类型颜色，避免引入新的视觉编码。

### 3.3 Dock 图例和对象列表

右侧 `地图预览` Dock 增加两个只读区域：

1. 类型图例：显示每种类型的颜色、中文类型名和当前地图数量，例如 `战斗 2`、`出口 3`。
2. 对象列表：显示当前地图对象的 `名称 / 类型 / id`，包括 NPC、出口、战斗触发点、商店、拾取物和提示对象。

对象列表本阶段不负责编辑，也不写回 JSON。它只帮助使用者在地图和数据之间建立对应关系。

## 4. 架构与组件

### 4.1 `MapPreviewHandle`

`addons/map_preview/preview_handles/map_preview_handle.gd` 继续作为所有预览元素的基础节点。新增职责：

- 保存 `type_label` 或等价显示字段。
- 在 `_draw()` 中绘制标签背景、边框和文本。
- 为圆形 handle 和矩形 handle 使用不同标签偏移。
- 在 `setup()` 或新增配置方法中接收标签文本需要的名称和类型。

标签绘制属于编辑器预览表现，不影响 transform 通知和拖拽回写逻辑。

### 4.2 类型显示工具

类型颜色和中文名目前分散在 `MapObjectHandle` 内。本阶段可以把类型名称和颜色保留在 `MapObjectHandle`，并新增本地 helper；如果实现时出现重复，再提取到一个轻量工具脚本。第一版不强制新增抽象。

### 4.3 `MapPreviewRenderer`

`addons/map_preview/map_preview_renderer.gd` 继续负责生成预览树。对象、出生点、障碍物创建时，需要把可读标签信息传给对应 handle。

渲染器仍只删除带 `map_preview_generated` 元数据的 `GeneratedMapPreview`，不触碰用户手工节点。

### 4.4 `MapPreviewPlugin`

`addons/map_preview/map_preview_plugin.gd` 的 Dock 增加只读图例和对象列表。插件在 `_render_selected_map()` 后根据当前 `map_data` 和 `layout` 重建这两个区域。

图例和对象列表从内存中的 `map_data` 计算，不直接读取文件，不引入新的数据来源。

## 5. 数据流

1. Godot 编辑器打开地图场景。
2. 插件根据场景路径选择 `map_id`，读取 `data/maps.json` 中的玩法对象和 `data/map_layouts/<map_id>.json` 中的布局。
3. 渲染器创建 `GeneratedMapPreview`。
4. 每个 handle 以现有颜色和形状显示自身，并额外绘制名称/类型标签。
5. Dock 使用同一份 `map_data` 生成类型图例和对象列表。
6. AI 修改布局文件后，现有自动刷新机制重建预览，标签和 Dock 内容随之刷新。

如果 AI 修改的是 `data/maps.json` 中的名称或类型，本阶段允许用户点击“刷新”或重开场景更新；自动监听 `data/maps.json` 可作为后续增强。

## 6. 错误处理

- 对象缺少 `name`：标签使用 `id`。
- 对象缺少 `type`：标签类型显示 `对象`，颜色使用默认灰色。
- 布局引用缺失对象：继续由现有校验区域报告错误，不阻断其他对象显示。
- 标签过长：第一版允许单行截断到合理长度，避免超长文字覆盖大半地图。

## 7. 测试策略

自动化测试聚焦结构和数据，不依赖人工看图：

1. `tests/test_map_preview_renderer.gd` 增加断言：对象 handle、出生点 handle、障碍 handle 持有正确的 `display_name` 和类型显示字段。
2. 增加类型中文化测试：`battle_trigger` 应显示 `战斗`，`exit` 应显示 `出口`，未知类型显示 `对象`。
3. Dock 图例和对象列表的生成逻辑如果抽成 helper，则为 helper 增加单元测试；如果保留在插件内，则以手动验证为主。
4. 保留现有测试，确认预览树清理仍只删除 `GeneratedMapPreview`，拖拽回写和文档保存不受影响。

手动验收：

1. 打开 `scenes/mountain_pass.tscn`。
2. 确认地图上能看到 `青衫客 / NPC`、战斗触发点、出口、出生点和障碍物标签。
3. 确认右侧 Dock 显示类型图例和对象列表。
4. 修改 `data/map_layouts/mountain_pass.json` 的对象位置，等待自动刷新，确认标签跟随对象位置移动。
5. 拖拽对象并保存，确认 JSON 回写仍正常。

## 8. 非目标

- 不制作真实地图美术或 TileMap。
- 不把预览节点保存进 `.tscn`。
- 不新增对象创建、删除、复制功能。
- 不实现点击对象列表后自动定位。
- 不改变运行时地图表现。

