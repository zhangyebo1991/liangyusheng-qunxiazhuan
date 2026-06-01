# 地图表现层底座设计

## 概述

本阶段聚焦地图表现层的底座能力验证，目标是让项目从"纯色块测试场"升级为"能承载正常 RPG 场景的地图系统"。

### 核心目标

- 地图背景支持加载真实底图图片，不再只是纯色 ColorRect
- 角色和建筑/树木支持基于 Y 坐标的遮挡排序
- 碰撞系统支持多边形形状，并有调试可视化
- 定义角色/场景比例关系，相机边界限制

### 不在范围内

- TileMap 图块拼接模式（后续阶段）
- 动态事件、时间流逝、势力行为等上层系统
- 编辑器插件的 polygon 编辑能力（后续再补）
- 流式地图加载、性能优化（后续阶段）
- 真实美术资源替换（本阶段用占位资源跑通管线）

### Demo 场景

新建"江南小镇"场景，用于验证所有底座能力。场景包含：
- 一张大图底图（占位图）
- 主角（已有 hero_yun 8 方向素材）
- 2-3 个 NPC（程序占位精灵）
- 建筑（客栈、药铺、民居）
- 树木
- 河流（多边形碰撞）
- 一座桥
- 出口传送点

---

## 第一节：大图底图加载

### 数据格式扩展

`data/map_layouts/*.json` 的 `background` 字段扩展为支持图片模式：

```json
// 现有：纯色模式（保持兼容）
{"mode": "color", "color": "#6f8f55"}

// 新增：图片模式
{"mode": "image", "path": "res://assets/maps/jiangnan_town/background.png"}
```

### 地图尺寸

大图模式下，`size` 字段可从图片尺寸自动推导，也可在 layout 中显式指定：

```json
{
  "map_id": "jiangnan_town",
  "size": {"x": 2560, "y": 1920},
  "background": {"mode": "image", "path": "res://assets/maps/jiangnan_town/background.png"}
}
```

当 `mode == "image"` 且 `size` 未指定时，运行时从加载的图片纹理获取尺寸。

### 运行时改动

文件：`scripts/scenes/map_screen_base.gd`

`_create_terrain()` 方法改动：
- `mode == "color"` → 保持现有 ColorRect 逻辑
- `mode == "image"` → 创建 `Sprite2D` 节点，加载指定路径的图片纹理
  - Sprite2D 作为背景层，`z_index` 设为最低
  - 图片锚点居中，position 设为 size/2 使底图对齐场景

### 资源目录结构

```
assets/
└── maps/
    └── jiangnan_town/
        └── background.png    # 底图占位图
```

### 验证标准

- 江南小镇场景能显示底图图片
- 角色能在底图上移动
- 相机不露出底图外的空白

---

## 第二节：Y-sort 遮挡排序

### 场景节点树结构

在 map_screen_base 中引入分层节点结构：

```
MapScreen (Node2D)
├── Background (Sprite2D 或 ColorRect) — 底图，永远在最下面
├── Terrain (TileMapLayer) — 预留，当前为空
├── WorldLayer (Node2D, y_sort_enabled = true) — 核心排序层
│   ├── 障碍物精灵 (Sprite2D) — 建筑、树木等
│   ├── NPC 精灵 (Sprite2D)
│   └── Player (CharacterBody2D)
├── OverlayLayer (Node2D) — 始终在角色上方的效果（树冠、屋檐等）
└── UI (CanvasLayer) — HUD，不受相机影响
```

### Y-sort 机制

- `WorldLayer` 设置 `y_sort_enabled = true`
- 所有子节点按 `position.y` 自动排序，y 值大的（更靠下）渲染在前
- 角色（Player、NPC）和障碍物精灵都放入 WorldLayer，自然参与排序

### 障碍物视觉升级

当前 `_add_obstacle()` 创建 ColorRect 作为视觉。改为：
- 创建 `Sprite2D` 替代 ColorRect
- 占位阶段：用程序生成的带颜色纹理（区分建筑/树木/岩石等类型）
- Sprite2D 的 `offset` 需调整，使图片底部对齐碰撞体底部（y 排序正确）

### OverlayLayer 用途

需要"始终在角色上方"的元素放入 OverlayLayer：
- 大树树冠上半部分
- 高层建筑的屋檐
- 牌楼顶部

第一版可以先不拆分，所有障碍物都放 WorldLayer。后续需要时再将遮挡部分提取到 OverlayLayer。

### 验证标准

- 角色走到建筑/树木后方时被遮挡（依赖 y-sort，障碍物精灵的 position.y 需合理设置）
- 角色走到建筑/树木前方时显示在前面
- 遮挡关系随角色 y 坐标实时变化
- 注意：第一版不拆分 OverlayLayer，遮挡效果完全依赖 WorldLayer 的 y-sort

---

## 第三节：碰撞系统增强

### 多边形碰撞支持

扩展 layout JSON obstacles 格式：

```json
// 现有：矩形（保持兼容）
{"id": "rock", "shape": "rect", "rect": {"x": 520, "y": 120, "w": 120, "h": 120}}

// 新增：多边形
{"id": "river_bank", "shape": "polygon", "points": [
  {"x": 100, "y": 400}, {"x": 300, "y": 380},
  {"x": 320, "y": 450}, {"x": 120, "y": 460}
]}
```

### 运行时改动

`_add_obstacle()` 方法改动：
- `shape == "rect"` → 保持现有 RectangleShape2D 逻辑
- `shape == "polygon"` → 创建 `CollisionPolygon2D`，传入顶点数组

### 调试显示模式

新增全局调试开关，可通过键盘快捷键（F3）切换显示：

| 调试层 | 颜色 | 显示内容 |
|--------|------|---------|
| 碰撞区 | 半透明红色 | 所有 StaticBody2D 的碰撞形状 |
| 交互区 | 半透明蓝色 | 所有 MapInteractable 的 Area2D 范围 |
| 传送区 | 半透明黄色 | type=exit 的对象 |

实现方式：
- 在 map_screen_base 中新增 `_create_debug_overlay()` 方法
- 使用独立的 CanvasLayer + 自定义绘制节点
- 调试开关状态可通过 GameState 或 EventBus 管理
- F3 切换时通过 EventBus 发信号，调试绘制节点监听并重绘

### 编辑器侧（后续）

map_preview 插件目前只支持矩形障碍物编辑。polygon 编辑需要可拖拽的多边形顶点 handle，复杂度较高，后续阶段再补。

### 验证标准

- 江南小镇的河流/岸边用多边形碰撞，角色不能穿过
- 按 F3 能看到碰撞区（红色）、交互区（蓝色）、传送区（黄色）
- 矩形和多边形碰撞都能正常阻挡角色移动

---

## 第四节：比例和相机

### 比例基准定义

在 layout JSON 中新增 camera 配置：

```json
{
  "map_id": "jiangnan_town",
  "size": {"x": 2560, "y": 1920},
  "camera": {
    "zoom": 1.0,
    "bounds": {"x": 0, "y": 0, "w": 2560, "h": 1920}
  }
}
```

- `zoom` 控制相机缩放，1.0 = 原始像素大小
- `bounds` 限制相机移动范围，不超出底图边界

### 相机边界限制

`_create_camera()` 方法改动：
- 从 layout 读取 camera 配置
- 设置 Camera2D 的 `limit_left`、`limit_right`、`limit_top`、`limit_bottom`
- 当 camera 配置不存在时，使用 map size 作为默认边界

### 占位比例参考

| 元素 | 参考尺寸 | 说明 |
|------|---------|------|
| 主角精灵高度 | 32-48px | 基准单位 |
| 房屋高度 | 96-128px | 主角的 2-3 倍 |
| 道路宽度 | 64-96px | 可容纳 1-2 个角色并排 |
| 树木高度 | 80-120px | 略高于房屋 |
| 场景总尺寸 | 2560×1920 | 比当前 1280×720 大一倍 |

这些数值在实际放图时可调整，先有参考框架。

### UI 隔离

- HUD、对话框、背包、日志面板已在 CanvasLayer 中，不受 zoom 影响
- 调试显示（F3）在独立 CanvasLayer 中
- 确认所有 UI 元素不随相机缩放

### 验证标准

- 相机跟随主角平滑移动
- 移动到底图边缘时相机停住，不露空白
- 可通过 layout JSON 调整缩放比例
- UI 始终固定在屏幕上

---

## 技术风险和注意事项

1. **Sprite2D 与碰撞体对齐**：y-sort 依赖 position.y，障碍物精灵的锚点和偏移需要仔细对齐，否则遮挡关系会错乱
2. **大图内存**：占位图不需要担心，但后续替换真实底图时需要关注图片尺寸和内存占用
3. **polygon 碰撞精度**：CollisionPolygon2D 要求顶点按顺序排列且不能自交叉，需要在编辑器或校验脚本中检查
4. **向后兼容**：所有扩展都是新增字段，现有纯色模式和矩形碰撞保持不变，不影响已有地图

---

## 实现顺序

按依赖关系排序：

1. **大图底图加载** — 无依赖，先做
2. **Y-sort 遮挡排序** — 依赖底图加载（需要有视觉内容才能验证遮挡）
3. **碰撞增强** — 与遮挡排序可并行，但建议在遮挡之后（障碍物视觉升级时一并处理）
4. **比例和相机** — 依赖底图加载（需要知道场景尺寸）

每个步骤完成后在江南小镇场景上验证，确认效果再进入下一步。
