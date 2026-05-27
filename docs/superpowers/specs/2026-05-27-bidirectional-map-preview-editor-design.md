# 双向地图预览编辑器设计规格书

## 1. 功能概述

当前探索地图主要由 `data/maps.json` 和地图脚本在运行时生成。Godot 编辑器打开 `mountain_pass.tscn`、`foot_village.tscn`、`road_outskirts.tscn` 时只能看到很薄的 `Node2D` 场景，无法直接查看 AI 修改后的地图内容，也无法在编辑器里微调对象位置。

本功能新增一个 Godot 4.6 编辑器插件，让地图数据在编辑器中可视化、可刷新、可微调，并让 AI 与编辑器共同读写同一套结构化地图布局数据。

目标体验：

1. AI 修改地图布局文件后，Godot 编辑器中的地图预览自动刷新。
2. 用户可以在 Godot 编辑器里拖拽 NPC、出口、拾取物、出生点、障碍物等预览元素。
3. 用户保存微调后，编辑器把修改写回地图布局数据，运行时和后续 AI 修改继续使用同一套数据。

## 2. 设计原则

### 2.1 单一字段真相

地图信息按字段分工，而不是按工具分工：

- `data/maps.json` 继续保存地图编号、场景路径、任务、对白、战斗、商店、奖励等玩法内容。
- `data/map_layouts/<map_id>.json` 保存地图尺寸、背景、出生点、障碍物、装饰物、对象坐标、交互半径等布局内容。
- 运行时加载地图时，把玩法内容和布局内容按 `map_id`、`object_id` 合并成现有 `map_data` 结构，避免上层场景脚本同时理解两套格式。

这样 AI 和 Godot 编辑器都只修改布局字段，玩法字段仍由现有内容数据负责。

### 2.2 预览节点不作为正式场景内容

插件在编辑器中生成 `GeneratedMapPreview` 节点树，只用于预览和编辑辅助。默认不把这些节点保存进 `.tscn`。正式运行仍从数据生成地图内容。

后续可以增加“烘焙到场景”按钮，但第一版不把烘焙作为主流程，避免 JSON 与 `.tscn` 同时成为地图来源。

### 2.3 先支持可靠微调，再支持完整制图

第一版重点解决已经存在的地图内容可见、可拖、可回写。新增剧情对象、复杂多边形绘制、TileSet 绘制、导航网格编辑可以后续扩展。

## 3. 数据结构

### 3.1 布局文件路径

每张地图一个布局文件：

```text
data/map_layouts/mountain_pass.json
data/map_layouts/foot_village.json
data/map_layouts/road_outskirts.json
data/map_layouts/world.json
```

### 3.2 布局文件示例

```json
{
  "map_id": "mountain_pass",
  "size": {"x": 1280, "y": 720},
  "background": {
    "mode": "color",
    "color": "#6f8f55"
  },
  "spawn_points": {
    "start": {"x": 160, "y": 320},
    "return_from_village": {"x": 1110, "y": 320}
  },
  "obstacles": [
    {"id": "border_top", "shape": "rect", "rect": {"x": 0, "y": 0, "w": 1280, "h": 24}},
    {"id": "rock_north", "shape": "rect", "rect": {"x": 520, "y": 120, "w": 120, "h": 120}}
  ],
  "objects": {
    "npc_qingshanke": {"position": {"x": 360, "y": 280}, "radius": 72},
    "enemy_bandit_gate": {"position": {"x": 720, "y": 260}, "radius": 56},
    "exit_to_foot_village": {"position": {"x": 1110, "y": 320}, "radius": 72}
  },
  "decorations": []
}
```

### 3.3 兼容现有数据

迁移阶段从 `data/maps.json` 提取已有对象的 `position`、`radius` 和 `spawn_points`，从地图脚本提取硬编码障碍物，生成首批 `data/map_layouts/*.json`。

迁移后：

- 运行时读取布局文件，把 `objects.<object_id>.position` 和 `radius` 合并回对应地图对象。
- 如果布局文件缺失某个对象布局，则保留 `data/maps.json` 中的原字段作为回退。
- 如果布局文件引用不存在的 `object_id`，校验器报错，但不阻止其他合法对象预览。

## 4. 编辑器插件架构

### 4.1 插件目录

```text
addons/map_preview/
  plugin.cfg
  map_preview_plugin.gd
  map_layout_document.gd
  map_preview_renderer.gd
  preview_handles/
    map_object_handle.gd
    spawn_point_handle.gd
    obstacle_handle.gd
```

### 4.2 `MapPreviewPlugin`

Godot `EditorPlugin` 入口，负责：

- 根据当前打开场景的路径，在 `data/maps.json` 中匹配 `scene_path`，推断当前 `map_id`。
- 在编辑器 Dock 中显示地图选择、刷新、自动刷新、保存、丢弃修改、校验结果。
- 监听布局文件修改时间或内容哈希，发现 AI 外部修改后自动刷新预览。
- 处理编辑器内拖拽和属性修改后的脏状态。
- 在保存时调用 `MapLayoutDocument` 写回布局文件。

### 4.3 `MapLayoutDocument`

编辑器专用的数据文档层，负责：

- 读取和写入 `data/map_layouts/<map_id>.json`。
- 保留未知字段，避免插件破坏未来扩展字段。
- 记录 `loaded_hash`、`current_hash`、`dirty`、`external_changed`。
- 校验对象引用、坐标字段、障碍物尺寸、颜色格式、地图尺寸。
- 提供字段级更新接口，例如更新对象位置、半径、障碍物矩形、出生点坐标。

### 4.4 `MapPreviewRenderer`

只负责把布局数据画成编辑器可见节点：

- 背景：`ColorRect` 或 `Sprite2D`。
- 障碍物：半透明矩形或多边形，附带碰撞边界线。
- 出生点：十字标记和名称标签。
- 地图对象：按类型显示颜色、名称标签、交互半径圆。
- 装饰物：第一版只预览位置和临时图形，后续再支持真实素材。

所有预览节点放在 `GeneratedMapPreview` 下，并带有 `map_preview_generated` 元数据。刷新时只删除和重建这棵预览树，不碰用户手工创建的其他节点。

### 4.5 预览 Handle

Handle 节点用于编辑器交互：

- `MapObjectHandle`：拖拽修改 `objects.<object_id>.position`，属性面板修改 `radius`。
- `SpawnPointHandle`：拖拽修改 `spawn_points.<spawn_id>`。
- `ObstacleHandle`：拖拽修改矩形位置，后续支持缩放修改宽高。

第一版只要求拖拽位置可靠。矩形尺寸、半径、颜色等可以先通过 Dock 的数字输入框修改。

## 5. 数据流

### 5.1 AI 修改后的自动刷新

1. AI 修改 `data/map_layouts/<map_id>.json`。
2. Godot 编辑器插件检测到文件修改时间或内容哈希变化。
3. 如果当前文档没有未保存的编辑器修改，插件重新读取布局文件。
4. `MapPreviewRenderer` 删除旧的 `GeneratedMapPreview` 并生成新的预览节点。
5. Dock 显示刷新时间和校验结果。

### 5.2 编辑器微调后的回写

1. 用户在 Godot 2D 编辑器中拖拽对象、出生点或障碍物。
2. Handle 把新的坐标交给 `MapLayoutDocument`。
3. Dock 显示未保存状态。
4. 用户点击保存。
5. 插件写回对应布局文件。
6. 运行时和 AI 后续继续读取更新后的布局文件。

### 5.3 外部修改冲突

如果插件已有未保存修改，同时 AI 或其他工具修改了同一个布局文件：

- 插件停止自动覆盖当前编辑器状态。
- Dock 显示冲突提示。
- 用户可以选择“重新加载外部版本”或“保存当前编辑器版本”。
- 第一版不做字段级自动合并，避免误覆盖。

## 6. 运行时接入

运行时需要让布局文件真正影响游戏，而不只是编辑器可见。

推荐改动：

1. `DataRepository` 加载 `data/map_layouts/*.json`。
2. `get_map(map_id)` 返回地图数据前，把布局字段合并到地图记录。
3. `MapScreenBase` 增加通用的数据化地形创建逻辑，优先使用 `map_data.layout` 或已合并的 `size`、`background`、`obstacles`。
4. `mountain_pass_screen.gd`、`foot_village_screen.gd`、`road_outskirts_screen.gd` 逐步移除硬编码障碍物，只保留本地图独有交互逻辑。

这样 AI 或编辑器修改布局后，编辑器预览和实际运行会保持一致。

## 7. 第一版范围

第一版支持：

- 自动识别当前场景对应的 `map_id`。
- 从布局文件生成编辑器预览。
- AI 修改布局文件后自动刷新预览。
- 预览 NPC、战斗触发点、出口、告示、商店、拾取物、出生点、矩形障碍物。
- 拖拽修改对象、出生点、矩形障碍物的位置。
- 用 Dock 修改对象半径和矩形障碍物尺寸。
- 保存修改到布局文件。
- 校验缺失对象引用、非法坐标、非法半径、非法矩形尺寸。

第一版不支持：

- 在编辑器中创建新的剧情对象并自动补齐对白、任务、战斗配置。
- TileSet 绘制和 TileMapLayer 原生画刷。
- 复杂导航网格编辑。
- 多人协同或字段级冲突合并。
- 自动把预览节点烘焙为正式 `.tscn` 内容。

## 8. 验收标准

1. 打开 `mountain_pass.tscn` 时，编辑器内能看到背景、障碍物、出生点和地图对象预览。
2. 修改 `data/map_layouts/mountain_pass.json` 中的对象坐标后，Godot 编辑器预览自动刷新。
3. 在 Godot 编辑器中拖动 `npc_qingshanke` 预览点并保存后，布局文件中的坐标同步变化。
4. 重新运行游戏后，主角、NPC、出口、障碍物位置与编辑器预览一致。
5. 当布局文件引用不存在的 `object_id` 时，Dock 显示清晰校验错误，其他合法对象仍能预览。
6. 当外部文件修改与编辑器未保存修改冲突时，插件不会静默覆盖任何一方。

## 9. 测试策略

### 9.1 自动化测试

- 为布局合并逻辑增加 GDScript 测试，确认 `DataRepository.get_map()` 能把布局字段合并到地图对象。
- 为缺失布局文件、缺失对象引用、非法半径、非法矩形尺寸增加校验测试。
- 为地图场景地形生成增加轻量测试，确认障碍物数量和背景尺寸来自布局数据。

### 9.2 编辑器手动验收

- 在 Godot 编辑器打开三张探索地图，确认插件能识别对应 `map_id`。
- 外部修改布局文件，确认自动刷新。
- 拖拽对象、保存、关闭重开场景，确认坐标保留。
- 制造外部修改冲突，确认 Dock 进入冲突状态并要求用户选择处理方式。

## 10. 风险与对策

- JSON 重写造成大 diff：布局独立成每图小文件，避免频繁重写庞大的 `data/maps.json`。
- 编辑器预览污染正式场景：所有预览节点统一放入 `GeneratedMapPreview`，刷新只操作带元数据的生成节点，默认不保存到 `.tscn`。
- 运行时和编辑器表现不一致：预览插件和运行时共用同一套布局字段，验收必须包含实际运行验证。
- Godot 编辑器拖拽 API 复杂：第一版把拖拽限制在点位和矩形位置，尺寸和半径先通过 Dock 输入框修改。
- AI 与编辑器同时修改冲突：第一版采用显式冲突提示和用户选择，不做自动合并。
