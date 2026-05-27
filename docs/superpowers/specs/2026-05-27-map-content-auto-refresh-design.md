# 地图内容自动刷新设计规格书

## 1. 功能概述

当前双向地图预览编辑器已经能监听 `data/map_layouts/<map_id>.json` 的外部变化。AI 修改对象坐标、交互半径、出生点、障碍物位置后，Godot 编辑器会自动重建 `GeneratedMapPreview`，用户也可以在编辑器里拖拽并保存回同一份布局 JSON。

但 `data/maps.json` 仍然主要依赖手动刷新或重开场景。AI 如果修改对象名称、类型、新增对象、删除对象，编辑器预览中的标签、类型颜色、图例和对象列表不会稳定地自动同步。

本阶段目标是让插件同时监听 `data/maps.json`：AI 修改地图内容后，当前地图预览能在 1 秒左右自动刷新，并保留现有布局编辑状态。

## 2. 设计原则

### 2.1 继续保持数据分工

- `data/maps.json` 保存地图对象、名称、类型、任务、对白、战斗、出口目标、奖励等玩法内容。
- `data/map_layouts/<map_id>.json` 保存地图尺寸、背景、出生点、障碍物、对象坐标和交互半径。

本阶段只让编辑器自动感知 `data/maps.json` 的内容变化，不把玩法字段写入布局文件，也不让插件创建完整剧情对象。

### 2.2 内容刷新不覆盖未保存布局

如果 `data/maps.json` 变化，但当前 `MapLayoutDocument` 有未保存布局修改，插件仍然可以刷新玩法内容和预览标签，因为它不需要重新读取布局文件来覆盖当前内存布局。

如果布局文件本身也有外部变化，并且当前编辑器有未保存布局修改，继续沿用现有冲突提示，不自动覆盖任何一方。

### 2.3 保持当前编辑焦点

刷新 `data/maps.json` 后：

- 当前 `selected_map_id` 仍存在时，继续显示当前地图。
- 当前 `selected_object_id` 仍存在时，重新高亮并选中对应预览节点。
- 当前选中对象被删除时，清空选择并提示 `选中对象已不存在：<object_id>`。
- 当前地图被删除或 `scene_path` 不再匹配时，清空当前预览并提示用户。

## 3. 用户体验

### 3.1 名称和类型自动同步

AI 修改对象名称或类型后，Godot 编辑器无需重开：

- 地图上对象标签更新。
- 类型颜色更新。
- 类型图例计数更新。
- 对象列表文本更新。

例如把 `青衫客` 改成 `青衫剑客`，预览标签和对象列表都应自动显示新名字。

### 3.2 新增对象自动出现

AI 在 `data/maps.json` 当前地图的 `objects` 数组中新增对象后：

- 如果布局文件里已有同 id 的 `objects.<object_id>` 坐标，则按布局坐标显示。
- 如果布局文件没有该对象坐标，但对象自身带有兼容旧字段 `position` 或 `radius`，继续使用现有 fallback。
- 如果两边都缺坐标，渲染器按现有默认位置显示，校验区域负责提示缺失布局引用或坐标问题。

本阶段不自动为新增对象生成布局坐标，避免 AI 内容编辑和编辑器布局编辑互相猜测。

### 3.3 删除对象自动消失

AI 从 `data/maps.json` 删除对象后：

- 对应预览节点从 `GeneratedMapPreview/Objects` 消失。
- 对象列表移除该行。
- 如果该对象原本被选中，状态栏显示 `选中对象已不存在：<object_id>`。
- 布局文件里残留的 `objects.<object_id>` 不立即删除，继续由校验区域提示“布局引用不存在对象”，避免插件擅自清理 AI 或用户暂存数据。

### 3.4 地图索引变化同步

AI 修改 `map_id`、新增地图、删除地图或修改 `scene_path` 后：

- 地图选择器重新构建。
- 当前场景路径仍能匹配地图时，继续选择匹配地图。
- 当前 `selected_map_id` 仍存在但场景路径变化时，优先保持当前选择。
- 当前地图不存在时，清空预览并显示 `当前地图已从 data/maps.json 移除：<map_id>`。

## 4. 架构设计

### 4.1 `MapPreviewPlugin`

`addons/map_preview/map_preview_plugin.gd` 继续作为 EditorPlugin 入口，新增 `data/maps.json` 快照状态：

- `map_index_hash`：最近一次成功读取的 `data/maps.json` 内容哈希。
- `map_index_path`：固定为 `res://data/maps.json`。

插件 `_process()` 每秒执行已有轮询时，同时检查：

1. 当前场景是否切换。
2. `data/maps.json` 是否变化。
3. 当前布局文件是否变化。

建议顺序是先处理 `data/maps.json`，再处理布局文件。这样当 AI 同时新增对象和布局坐标时，地图对象数据先进入 `maps_by_id`，后续布局刷新能正确校验和渲染。

### 4.2 地图索引加载

现有 `_load_map_index()` 负责读取 `data/maps.json`、重建 `maps_by_id`、`scene_path_to_map_id` 和 `map_selector`。

本阶段将它拆成更明确的行为：

- 成功读取时更新 `map_index_hash`。
- 读取失败时保留旧 `maps_by_id`，避免编辑器因为半写入 JSON 瞬间清空预览。
- JSON 格式非法时显示 `data/maps.json 必须是数组。`，并保留旧数据。
- 重新构建 `map_selector` 后尽量恢复当前 `selected_map_id` 的选项选中状态。

### 4.3 内容刷新入口

新增内容刷新入口，例如 `_check_map_index_refresh()`：

1. 读取 `data/maps.json` 当前哈希。
2. 如果哈希未变，直接返回。
3. 记录刷新前的 `selected_map_id` 和 `selected_object_id`。
4. 调用 `_load_map_index()`。
5. 如果当前场景路径匹配到新地图，选择该地图。
6. 如果当前场景无法匹配，但旧 `selected_map_id` 仍存在，继续渲染旧选择。
7. 如果旧地图不存在，清空预览并显示移除提示。
8. 调用 `_render_selected_map()`，让已有 `_reapply_selected_object()` 处理对象选择保留或清空。

### 4.4 与布局冲突机制的关系

`MapLayoutDocument.has_external_change()` 继续只负责当前布局文件。

`data/maps.json` 变化不是布局写回冲突，因为插件当前不保存玩法字段。因此：

- `document.is_dirty() == false`：内容变化后可直接刷新内容与布局。
- `document.is_dirty() == true`：内容变化后用内存中的 `document.get_layout()` 渲染，不调用 `document.load_map()`，不覆盖未保存布局。
- 如果此时布局文件也有外部变化，沿用现有 `布局文件有外部修改，且编辑器内有未保存修改。请选择保存或重载。`

## 5. 数据流

### 5.1 AI 修改对象名称

1. AI 修改 `data/maps.json` 中当前地图对象的 `name`。
2. 插件轮询发现 `map_index_hash` 变化。
3. 插件重新读取 `maps_by_id`。
4. 插件用当前内存布局重新渲染。
5. 标签、对象列表和图例更新。

### 5.2 AI 新增对象

1. AI 在 `data/maps.json` 的当前地图 `objects` 中新增对象。
2. 插件重读地图索引。
3. 渲染器根据新的 `map_data.objects` 创建新的 object handle。
4. 如果布局缺失坐标，校验区域显示对应错误或 fallback 状态。

### 5.3 AI 删除当前选中对象

1. 用户已选中 `npc_qingshanke`。
2. AI 从 `data/maps.json` 删除该对象。
3. 插件重读地图索引并重建预览。
4. `_reapply_selected_object()` 找不到 `GeneratedMapPreview/Objects/npc_qingshanke`。
5. 插件清空选择并显示 `选中对象已不存在：npc_qingshanke`。

## 6. 错误处理

- `data/maps.json` 读取失败：保留旧地图索引，状态栏显示 `无法读取 data/maps.json。`
- `data/maps.json` JSON 非数组：保留旧地图索引，状态栏显示 `data/maps.json 必须是数组。`
- 当前地图被删除：清空当前预览，状态栏显示 `当前地图已从 data/maps.json 移除：<map_id>`
- 当前场景不再匹配任何地图：状态栏显示 `当前场景未匹配到 data/maps.json 中的地图。`
- 当前选中对象被删除：清空选择，状态栏显示 `选中对象已不存在：<object_id>`
- `maps.json` 与布局文件同时变化且布局有未保存修改：内容刷新可以进行，但布局外部变化仍显示现有冲突提示。

## 7. 测试策略

### 7.1 自动化测试

新增或扩展 GDScript 测试，优先覆盖纯数据逻辑：

- 地图索引哈希变化检测：相同内容不触发刷新，变化内容触发刷新。
- 地图索引读取失败时保留旧 `maps_by_id`。
- 地图选择器重建后仍能恢复当前 `selected_map_id`。
- 当前选中对象删除后，选择状态清空。

如果插件函数难以在 headless 测试中直接实例化，允许先把哈希计算、索引解析、刷新决策提取成轻量 helper，再用测试覆盖 helper。

### 7.2 编辑器手动验收

1. 打开 Godot 编辑器和 `scenes/mountain_pass.tscn`。
2. 修改 `data/maps.json` 中 `npc_qingshanke.name`，等待 1 秒，确认地图标签和对象列表更新。
3. 修改 `npc_qingshanke.type`，确认颜色、类型文本和图例更新。
4. 新增一个带 `id`、`type`、`name` 的对象，确认对象列表和地图预览出现新对象。
5. 删除当前选中的对象，确认预览节点消失并显示 `选中对象已不存在：<object_id>`。
6. 在编辑器拖动对象但不保存，再修改 `data/maps.json` 名称，确认对象名称刷新且未保存坐标不被覆盖。

## 8. 非目标

- 不在编辑器里创建完整玩法对象。
- 不自动补齐对白、战斗、任务、奖励或商店配置。
- 不自动删除布局文件中残留的对象坐标。
- 不实现字段级差异视图。
- 不改变运行时地图加载逻辑。
- 不新增出生点或障碍物列表点击选择。

## 9. 验收标准

1. AI 修改当前地图对象名称后，编辑器预览在自动刷新开启时无需手动刷新即可显示新名称。
2. AI 修改对象类型后，颜色、中文类型和图例计数自动更新。
3. AI 新增对象后，对象列表和预览树自动包含该对象。
4. AI 删除对象后，对象列表和预览树自动移除该对象。
5. 当前布局有未保存修改时，`data/maps.json` 内容刷新不覆盖内存中的布局坐标。
6. `data/maps.json` 临时写坏时，插件保留上一份可用地图索引，不清空当前预览。

