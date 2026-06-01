# 地图表现层 v2 设计规格书

## 概述

本阶段目标：在已跑通的数据驱动地图管线基础上，补齐画面表现层能力，让项目从"纯色块测试场"升级为"能承载正常 RPG 场景的地图系统"。

### 与 v1 设计的关系

`2026-06-01-map-presentation-layer-design.md` 规划了 4 个底座能力（大图底图、Y-sort 遮挡、碰撞增强、相机比例）。本设计在此基础上扩展：

- 增加 TileMap 图块拼接模式（方案 B），与底座能力并行推进
- 增加 NPC 素材化升级（从像素块到正常角色）
- 增加植被装饰 + 粒子氛围系统
- 增加编辑器插件对新数据格式的适配

### 核心目标

1. 大图底图模式：支持加载图片作为场景背景，替代纯色 ColorRect
2. TileMap 图块模式：分层 JSON 数据驱动，运行时动态写入 TileMapLayer
3. Y-sort 遮挡排序：建筑/树木/角色按 Y 坐标正确遮挡
4. 碰撞增强：支持多边形碰撞 + F3 调试显示
5. 相机系统：边界限制 + 可配置缩放
6. NPC 素材化：2-3 套程序生成占位角色，替代像素块
7. 植被装饰 + 粒子氛围：让场景具备正常 RPG 画面感

### 不在范围内

- 真实美术资源制作（本阶段用程序占位素材跑通管线）
- 动态事件、时间流逝、势力行为等上层系统
- 性能优化、流式地图加载
- 现有 4 个剧情场景的改造（新建独立场景验证）

---

## 第一节：整体架构

### 场景节点树

```
MapScreen (Node2D)
├── BackgroundLayer (Sprite2D / ColorRect) — 大图底图，z_index 最低
├── TileMapLayer (Godot TileMapLayer) — 图块拼接场景背景
├── WorldLayer (Node2D, y_sort_enabled=true) — 核心遮挡排序层
│   ├── 建筑精灵 (Sprite2D)
│   ├── 树木精灵 (Sprite2D)
│   ├── 装饰物精灵 (Sprite2D)
│   ├── NPC 精灵 (AnimatedSprite2D / Sprite2D)
│   └── Player (CharacterBody2D + AnimatedSprite2D)
├── OverlayLayer (Node2D) — 始终在角色上方
│   ├── 树冠 (Sprite2D)
│   ├── 屋檐 (Sprite2D)
│   └── 牌楼顶部 (Sprite2D)
├── ParticleLayer (Node2D) — 粒子氛围效果
├── CollisionLayer (Node2D) — 碰撞体集合
├── InteractableLayer (Node2D) — Area2D 交互区
├── DebugLayer (CanvasLayer) — F3 调试绘制
└── UILayer (CanvasLayer) — HUD/对话/背包
```

### 数据流

```
data/maps.json + data/map_layouts/<map_id>.json
  → DataRepository 合并
  → map_screen_base.gd 运行时创建节点
  → 编辑器 map_preview 插件同步预览
```

### 三条工作线

| 线 | 名称 | 核心产出 | 依赖 |
|----|------|---------|------|
| 1 | 城镇大图 | jiangnan_town 大图底图场景 | 无 |
| 2 | 野外 TileMap | wilderness_trail 图块拼接场景 | 无 |
| 3 | 通用表现层 | NPC 素材 / 植被装饰 / 粒子氛围 | 线 1 + 线 2 的基础结构 |

---

## 第二节：数据格式

### 大图底图模式 (mode: "big_image")

`data/map_layouts/jiangnan_town.json`:

```json
{
  "map_id": "jiangnan_town",
  "mode": "big_image",
  "size": {"x": 2560, "y": 1920},
  "background": {
    "mode": "image",
    "path": "res://assets/maps/jiangnan_town/background.png"
  },
  "camera": {
    "zoom": 1.0,
    "bounds": {"x": 0, "y": 0, "w": 2560, "h": 1920}
  },
  "obstacles": [
    {"id": "river", "shape": "polygon", "points": [
      {"x": 200, "y": 600}, {"x": 500, "y": 580}, {"x": 520, "y": 660}, {"x": 220, "y": 680}
    ]},
    {"id": "house_inn", "shape": "rect", "rect": {"x": 400, "y": 300, "w": 200, "h": 150}}
  ],
  "objects": {
    "npc_innkeeper": {"position": {"x": 500, "y": 380}, "radius": 72},
    "exit_to_wild": {"position": {"x": 2400, "y": 960}, "radius": 72}
  },
  "decorations": [
    {"id": "tree_01", "type": "tree", "position": {"x": 300, "y": 400}, "has_collision": true, "has_overlay": true},
    {"id": "rock_01", "type": "rock", "position": {"x": 600, "y": 500}, "has_collision": true, "has_overlay": false}
  ],
  "particles": [
    {"id": "clouds", "type": "cloud", "region": {"x": 0, "y": 0, "w": 2560, "h": 400}},
    {"id": "river_surface", "type": "water", "position": {"x": 200, "y": 600}}
  ]
}
```

### TileMap 图块模式 (mode: "tile_map")

`data/map_layouts/wilderness_trail.json`:

```json
{
  "map_id": "wilderness_trail",
  "mode": "tile_map",
  "size": {"x": 2560, "y": 1920},
  "tileset": {
    "path": "res://assets/kenney_tiny-battle/tilemap.png",
    "tile_size": {"x": 128, "y": 128},
    "terrain_map": {
      "grass": {"tile_index": 0, "passable": true},
      "water": {"tile_index": 1, "passable": false},
      "path": {"tile_index": 2, "passable": true},
      "mountain": {"tile_index": 3, "passable": false}
    }
  },
  "layers": {
    "ground": [
      ["grass", "grass", "path", "water", "water"],
      ["grass", "mountain", "path", "water", "water"]
    ],
    "decoration": [
      [null, "tree_01", null, null, null],
      [null, null, "rock_01", null, null]
    ],
    "overlay": [
      [null, "canopy_01", null, null, null]
    ]
  },
  "obstacles": [...],
  "objects": {...},
  "decorations": [...],
  "particles": [...]
}
```

### 向后兼容

- 无 `mode` 字段 → 默认走现有纯色模式（ColorRect + obstacles）
- `shape == "rect"` → 保持现有 RectangleShape2D 逻辑
- `decorations` 和 `particles` 为空数组时 → 不创建对应层
- 不影响 foot_village、mountain_pass、road_outskirts、world 四个现有场景

---

## 第三节：运行时加载管道

### map_screen_base.gd 改造

`_ready()` 新流程：

```
_load_map_data()
  ↓
_create_terrain()
  ├─ mode="image"    → _create_image_background()
  ├─ mode="tile_map" → _create_tile_map()
  └─ 默认           → 现有 ColorRect + obstacles 逻辑
  ↓
_create_world_layer()    [新增] WorldLayer / OverlayLayer / ParticleLayer
  ↓
_create_player()          [改动] player 移入 WorldLayer
_create_camera()          [改动] 读取 camera.bounds → limit_left/right/top/bottom
_spawn_objects()          [改动] interactable 移入 WorldLayer
  ↓
_spawn_decorations()     [新增] 遍历 decorations[]
_spawn_particles()       [新增] 遍历 particles[]
  ↓
_create_ui()
_create_debug_overlay()  [新增] F3 切换碰撞/交互/传送区显示
```

### 关键方法

**_create_image_background():**
1. 读取 `background.path`
2. `ResourceLoader.load()` 加载 Texture2D
3. 创建 Sprite2D，`centered=false`，`z_index=-100`
4. 若 `size` 未指定，从 texture 尺寸推导

**_create_tile_map():**
1. 加载 tileset 图集 → TileSet resource
2. 为每个 terrain 注册 tile 源区域
3. 对 ground / decoration / overlay 三层各创建 TileMapLayer
4. 遍历 `layers[layer_name][y][x]`，若非 null 则 `set_cell(x, y, tile_id)`
5. 各层 z_index 递增（0, 1, 2）

**_spawn_decorations():**
1. 遍历 `layout.decorations[]`
2. 创建 Sprite2D，加载程序占位纹理
3. `has_overlay=true` → OverlayLayer，否则 → WorldLayer
4. `has_collision=true` → 附加 StaticBody2D + CollisionShape2D
5. z_index 按 `position.y` 设置（在 WorldLayer 内参与 y-sort）

**_create_debug_overlay():**
1. 创建独立 CanvasLayer（不受相机缩放影响）
2. 对应碰撞体绘制半透明红色矩形/多边形
3. 对应交互区绘制半透明蓝色圆形
4. 对应传送区绘制半透明黄色圆形
5. 监听 EventBus 的 `debug_toggled` 信号，F3 切换显示/隐藏

---

## 第四节：NPC 素材化

### 角色配置格式（actors.json 扩展）

```json
{
  "actor_id": "villager_01",
  "display_name": "村民",
  "character_id": "villager",
  "sprite_set": "res://assets/characters/villager/",
  "directions": ["down_left", "down_right", "up_left", "up_right"],
  "animations": ["idle", "walk"],
  "collision_size": {"w": 16, "h": 24},
  "interaction_radius": 48,
  "scale": 1.0
}
```

### 3 套 NPC 占位素材

| ID | 角色 | 生成方式 | 方向 | 帧数 |
|----|------|---------|------|------|
| `villager` | 村民（男） | 程序生成 → PNG | 4 斜方向 | walk: 7f, idle: 1f |
| `merchant` | 掌柜/商人 | 程序生成 → PNG | 4 斜方向 | walk: 7f, idle: 1f |
| `scholar` | 书生/文士 | 程序生成 → PNG | 4 斜方向 | walk: 7f, idle: 1f |

目录结构与 `hero_yun` 一致：`assets/characters/<id>/walk/<direction>/<frame>.png`

### MapInteractable 升级

NPC 类型的 MapInteractable：
1. 根据 `actor_id` 查找 actor 配置的 `character_id`
2. 调用 `CharacterSpriteLoader.create_walk_frames()` 加载 SpriteFrames
3. 创建 AnimatedSprite2D 子节点，播放 idle 动画
4. 无素材时回退 `SimpleSpriteFactory`（保持现有兼容）
5. 后续预留：简单随机巡逻移动（用 tween 微调位置）

---

## 第五节：植被装饰 & 粒子氛围

### 装饰物类型

| 类型 | 占位纹理 | 碰撞 | 遮挡 | 动画 |
|------|---------|------|------|------|
| `tree` | 棕色矩形 + 绿圆冠 | ✅ 树干 | ✅ 树冠→Overlay | — |
| `bush` | 深绿小椭圆 | — | — | 轻微摇摆 |
| `rock` | 灰色椭圆 | ✅ | ✅ | — |
| `signpost` | 棕色细条 | — | — | — |
| `lantern` | 红色小圆+线 | — | — | 轻微摇摆 |
| `building` | 棕色矩形+灰三角顶 | ✅ 屋身 | ✅ 屋檐→Overlay | — |
| `bridge` | 棕色弧形/矩形 | ✅ 桥面 | ✅ | — |

### 建筑/树拆分模型

```
屋檐 / 树冠 → OverlayLayer (z_index 高，始终盖住角色)
屋身 / 树干 → WorldLayer   (参与 y-sort)
碰撞体      → StaticBody2D  (阻挡角色)
```

### 粒子效果

| 类型 | 实现 | 参数 |
|------|------|------|
| `cloud` | GPUParticles2D | 大区域顶部，慢速横向漂移，白色半透明 |
| `fog` | GPUParticles2D | 全屏/区域，大颗粒缓慢漂，白色低不透明度 |
| `leaves` | CPUParticles2D | 树区域周边，下落+摇摆，橙/棕色小点 |
| `water` | AnimatedSprite2D | 河流/池塘区域，波纹循环帧，蓝色半透明 |
| `snow` | GPUParticles2D | 全屏白色小点下落（第一版预留配置） |

---

## 第六节：测试场景

### 场景 A：江南小镇 (jiangnan_town)

- 模式：big_image
- 尺寸：2560 × 1920
- 底图：程序生成（草地 + 土路 + 水域格局）
- 对象：客栈、药铺、民居×2、大树×3、灌木×5、石头×4、路牌×2、灯笼×3、河流、桥、围墙
- 角色：主角（hero_yun）、NPC 村民（villager）、NPC 掌柜（merchant）
- 交互：出口×2（world / wilderness_trail）、可拾取物×1
- 粒子：云朵 + 薄雾 + 水面动画
- 调试：F3 全开

### 场景 B：野外山道 (wilderness_trail)

- 模式：tile_map
- 尺寸：2560 × 1920
- Tileset：Kenney tiny-battle（128×128 tile）
- 层：ground（草地/山路/石阶/水域）、decoration（树丛/石头/路牌）、overlay（树冠/山门牌楼顶）
- 地形属性：山壁不可走、水域不可走、桥可通行、台阶可通行
- 角色：主角、NPC 书生（scholar）、NPC 山贼（villager 变体）
- 交互：入口←jiangnan_town、出口→mountain_pass、可拾取物×1
- 粒子：落叶 + 薄雾
- 调试：F3 全开

### 新增文件清单

| 文件 | 作用 |
|------|------|
| `scenes/jiangnan_town.tscn` | 空壳场景，挂 map_screen_base.gd |
| `scenes/wilderness_trail.tscn` | 空壳场景，挂 map_screen_base.gd |
| `data/map_layouts/jiangnan_town.json` | 大图底图完整配置 |
| `data/map_layouts/wilderness_trail.json` | TileMap 分层配置 |
| `data/maps.json` | 追加两条地图条目 + 对象定义 |
| `assets/characters/villager/` | 村民 NPC 占位素材 |
| `assets/characters/merchant/` | 掌柜 NPC 占位素材 |
| `assets/characters/scholar/` | 书生 NPC 占位素材 |

---

## 第七节：编辑器插件适配

map_preview 插件（`addons/map_preview/`）适配改动：

1. **底图预览**：`mode="image"` 时加载底图纹理作为编辑器背景
2. **TileMap 预览**：`mode="tile_map"` 时按 layers 数据创建临时 TileMapLayer
3. **Y-sort 预览**：预览节点按 Y 坐标排序渲染，标注 WorldLayer/OverlayLayer 分界
4. **校验扩展**：`content_reference_validator` 新增检查底图路径、tileset 路径、character_id、decoration type、particle type

---

## 第八节：实施顺序

按依赖关系排列：

### 起点（无依赖，可并行）

- 1.1 底图加载（`_create_image_background`）
- 2.1 tileset JSON 格式 + terrain_map 定义
- 3.1 NPC 程序素材生成（3 套）

### 第二层

- 1.2 生成 jiangnan_town 程序底图 → 依赖 1.1
- 1.3 WorldLayer + OverlayLayer 搭建 → 依赖 1.1
- 2.2 `_create_tile_map()` 运行时加载 → 依赖 2.1
- 3.2 MapInteractable AnimatedSprite2D 升级 → 依赖 3.1

### 第三层

- 1.4 多边形碰撞 + F3 调试显示 → 依赖 1.3
- 1.5 相机边界 + 比例配置 → 依赖 1.2
- 2.3 编辑器 TileMap 预览 → 依赖 2.2
- 3.3 装饰物系统 + 程序纹理 → 依赖 1.3 + 2.2
- E.1 编辑器底图预览适配 → 依赖 1.1
- E.2 编辑器 Y-sort 预览标注 → 依赖 1.3
- E.3 校验扩展（底图/tileset/character/decoration/particle） → 依赖 1.1 + 2.1

### 汇合层

- 2.4 wilderness_trail 配置数据 → 依赖 2.3 + 3.3
- 3.4 粒子效果 → 依赖 1.3 + 2.2
- 3.5 两场景植被+粒子全面布置 → 依赖 3.3 + 3.4

---

## 技术风险和注意事项

1. **Y-sort 与碰撞体对齐**：y-sort 依赖 `position.y`，障碍物精灵锚点必须与碰撞体底部对齐，否则遮挡错乱
2. **TileMapLayer 动态 set_cell**：Godot 4.x 的 TileMapLayer 支持运行时 set_cell，但需要确认 tile 坐标映射正确
3. **大图内存**：2560×1920 占位图（约 600KB PNG）没问题，但后续替换真实底图时需关注
4. **多边形碰撞**：CollisionPolygon2D 要求顶点按顺序排列且不自交叉，校验脚本需检查
5. **程序素材兼容**：所有程序生成素材的目录结构和命名规范必须与 hero_yun 一致，确保后续替换无痛
