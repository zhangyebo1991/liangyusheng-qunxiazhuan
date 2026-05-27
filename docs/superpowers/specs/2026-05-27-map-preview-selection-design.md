# 地图预览对象选中与高亮设计规格书

## 1. 功能概述

当前 `地图预览` Dock 已能显示类型图例和对象列表，地图上的预览 handle 也能显示 `名称 / 类型` 标签。但对象列表仍是只读文本，使用者看到某个对象后，还需要在地图或场景树中手动寻找对应的 `GeneratedMapPreview/Objects/<object_id>` 节点，微调位置时不够顺手。

本阶段目标是把对象列表变成可点击入口：点击对象列表中的一行后，地图上对应对象高亮，同时 Godot 编辑器选中对应预览节点，让用户可以直接在 2D 编辑器里拖拽微调。

## 2. 设计原则

### 2.1 只增强编辑器工作流

本阶段不改变 `data/maps.json`、`data/map_layouts/*.json` 或运行时地图逻辑。点击对象列表只改变编辑器预览的选中状态，以及 Godot 编辑器当前选中的节点。

### 2.2 优先服务对象微调

第一版只支持 `GeneratedMapPreview/Objects/<object_id>` 里的地图对象：NPC、出口、战斗触发点、商店、拾取物和提示对象。出生点与障碍物后续再接入，因为它们的编辑面板、尺寸字段和对象列表语义不同。

### 2.3 刷新后尽量保持选择

插件自动刷新或手动刷新预览后，如果之前选中的 `object_id` 仍存在，则继续高亮并尝试重新选中对应节点。如果对象被 AI 删除或当前地图不存在该对象，则清空选择并在 Dock 状态中提示。

## 3. 用户体验

### 3.1 对象列表点击

右侧 `对象列表` 从纯 `RichTextLabel` 文本改为可点击列表。每一行保持现有信息密度：

```text
■ 青衫客 / NPC / npc_qingshanke
■ 去山脚村 / 出口 / exit_to_foot_village
```

点击某一行后：

- 地图上对应对象进入选中状态。
- Dock 的对象半径区域自动填入该对象的 `object_id`。
- 半径输入框自动显示当前对象半径。
- Godot 编辑器选择 `GeneratedMapPreview/Objects/<object_id>` 节点，用户可以直接在 2D 编辑器中拖动。
- 状态栏显示 `已选中对象：<object_id>`。

### 3.2 地图高亮

选中对象的 handle 在现有颜色基础上增加明显但克制的高亮：

- 中心点略微放大。
- 交互半径线加粗。
- 标签边框加粗并使用亮色描边。

未选中对象保持当前样式。每次只能有一个选中对象。

### 3.3 拖拽联动

用户通过列表选中对象后拖拽 handle，继续沿用现有 `layout_changed` 信号和 `MapLayoutDocument.update_object_position()` 回写流程。拖拽过程中对象仍保持高亮，Dock 保持当前 `object_id`。

## 4. 架构与组件

### 4.1 `MapPreviewHandle`

`addons/map_preview/preview_handles/map_preview_handle.gd` 增加选中状态：

- 新增 `selected: bool`。
- 新增 `set_selected(next_selected: bool)`。
- `_draw()` 根据 `selected` 调整中心点大小、半径线宽和标签边框宽度。

该状态只影响编辑器显示，不写入布局数据。

### 4.2 `MapPreviewRenderer`

`addons/map_preview/map_preview_renderer.gd` 继续负责生成预览节点。它不需要持久保存选中状态，但生成后的对象节点路径必须稳定保持为：

```text
GeneratedMapPreview/Objects/<object_id>
```

插件通过该路径查找、设置高亮和调用编辑器选择接口。

### 4.3 `MapPreviewPlugin`

`addons/map_preview/map_preview_plugin.gd` 新增职责：

- 保存 `selected_object_id`。
- 用按钮或等价可点击控件构建对象列表。
- 点击列表项时查找 `GeneratedMapPreview/Objects/<object_id>`。
- 清除旧 handle 的选中状态，设置新 handle 的选中状态。
- 填入 `object_id_input` 和 `radius_spin`。
- 调用 Godot 编辑器选择接口，让当前对象成为编辑器选中节点。
- 刷新预览后重新应用 `selected_object_id`。

对象列表仍从 `MapPreviewTypes.build_object_summary()` 生成的 rows 构建，不新增数据来源。

## 5. 数据流

1. 插件渲染当前地图，并生成对象列表按钮。
2. 用户点击对象列表中的某个对象。
3. 插件保存 `selected_object_id`。
4. 插件查找当前场景根节点下的 `GeneratedMapPreview/Objects/<object_id>`。
5. 如果找到 handle，插件设置高亮，填充 Dock 编辑字段，并选中该 Godot 节点。
6. 用户拖动该节点，现有 handle transform 通知触发位置更新。
7. 用户点击保存，现有文档层写回 `data/map_layouts/<map_id>.json`。
8. 如果预览刷新，插件重新根据 `selected_object_id` 应用高亮；找不到则清空选择。

## 6. 错误处理

- 对象列表项对应 handle 不存在：状态栏显示 `找不到预览对象：<object_id>`，并清空高亮。
- 当前没有打开地图场景：点击项不执行选择，并显示 `当前没有打开地图场景。`
- 刷新后对象不存在：清空 `selected_object_id`，状态栏显示 `选中对象已不存在：<object_id>`。
- Godot 编辑器选择接口不可用或失败：地图高亮仍生效，状态栏提示对象已高亮；不阻断后续拖拽或保存流程。

## 7. 测试策略

自动化测试：

1. `tests/test_map_preview_renderer.gd` 增加断言：对象 handle 初始未选中，调用 `set_selected(true)` 后 `selected == true` 且 `get_label_text()` 不变。
2. 新增或扩展插件辅助函数测试：对象列表 rows 能生成稳定的对象 id、显示文本和颜色信息。
3. 如果选择逻辑被提取为小 helper，则测试找不到对象时返回明确失败结果。

手动验收：

1. 打开 Godot 编辑器并打开 `scenes/mountain_pass.tscn`。
2. 在右侧 `地图预览` Dock 点击 `青衫客 / NPC / npc_qingshanke`。
3. 确认地图上青衫客 handle 高亮。
4. 确认 Godot 编辑器选中 `GeneratedMapPreview/Objects/npc_qingshanke`。
5. 确认对象半径区域填入 `npc_qingshanke`，半径值显示当前布局半径。
6. 拖拽该节点并点击保存，确认 `data/map_layouts/mountain_pass.json` 写回新坐标。
7. 修改布局文件触发自动刷新，确认仍然高亮同一对象。

## 8. 非目标

- 不实现 2D 视图自动居中或缩放。
- 不支持出生点、障碍物的列表点击定位。
- 不新增对象筛选、搜索、排序。
- 不改变运行时地图表现。
- 不新增对象创建、复制或删除功能。

