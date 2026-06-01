# 地图表现层 v2 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在数据驱动地图管线上补齐画面表现层——大图底图、TileMap 图块、Y-sort 遮挡、碰撞增强、NPC 素材化、植被装饰、粒子氛围

**Architecture:** 改造 `map_screen_base.gd` 运行时管道，按 layout JSON 的 `mode` 字段分派（big_image / tile_map / 默认纯色），新增 WorldLayer/OverlayLayer/ParticleLayer 节点树，编辑器插件同步适配新数据格式

**Tech Stack:** Godot 4.x (GDScript), JSON 数据驱动, Kenney tiny-battle tileset

---

## 文件结构

| 文件 | 操作 | 职责 |
|------|------|------|
| `scripts/scenes/map_screen_base.gd` | 修改 | 核心运行时管道改造 |
| `scripts/scenes/map_interactable.gd` | 修改 | NPC 类型升级为 AnimatedSprite2D |
| `scripts/core/event_bus.gd` | 修改 | 新增 debug_toggled 信号 |
| `scripts/systems/sprite_generator.gd` | 新建 | 程序生成 NPC/装饰物占位纹理 |
| `scripts/scenes/npc_sprite_loader.gd` | 新建 | NPC 角色精灵加载辅助 |
| `addons/map_preview/map_preview_renderer.gd` | 修改 | 编辑器预览适配 image/tile_map 模式 |
| `addons/map_preview/content_reference_validator.gd` | 修改 | 新增校验规则 |
| `addons/map_preview/map_layout_document.gd` | 修改 | 支持 decorations/particles 布局编辑 |
| `scenes/jiangnan_town.tscn` | 新建 | 大图底图测试场景 |
| `scenes/wilderness_trail.tscn` | 新建 | TileMap 测试场景 |
| `data/map_layouts/jiangnan_town.json` | 新建 | 大图底图完整配置 |
| `data/map_layouts/wilderness_trail.json` | 新建 | TileMap 分层配置 |
| `data/maps.json` | 修改 | 追加两条地图条目 |

---

### Task 1: 底图加载 — `_create_image_background()`

**Files:**
- Modify: `scripts/scenes/map_screen_base.gd`

**目标：** 当 layout `mode` 为 `"big_image"` 且 `background.mode` 为 `"image"` 时，用 Sprite2D 加载底图替代 ColorRect。

- [ ] **Step 1: 改造 `_create_terrain()` 方法，增加 mode 分派**

将 `_create_terrain()` 改为按 `mode` 分派：

```gdscript
func _create_terrain() -> void:
    var layout = _get_layout_data()
    var mode = str(layout.get("mode", ""))
    match mode:
        "big_image":
            _create_image_background(layout)
        "tile_map":
            _create_tile_map_background(layout)
        _:
            _create_color_background(layout)
```

- [ ] **Step 2: 实现 `_create_image_background()`**

```gdscript
func _create_image_background(layout: Dictionary) -> void:
    var bg = layout.get("background", {})
    var image_path = str(bg.get("path", ""))
    if image_path.is_empty():
        push_error("大图底图模式缺少 background.path")
        _create_color_background(layout)
        return

    var texture: Texture2D = null
    if ResourceLoader.exists(image_path, "Texture2D"):
        texture = load(image_path)
    else:
        var image = Image.load_from_file(ProjectSettings.globalize_path(image_path))
        if image != null:
            image.convert(Image.FORMAT_RGBA8)
            texture = ImageTexture.create_from_image(image)

    if texture == null:
        push_warning("无法加载底图: %s，回退到纯色背景" % image_path)
        _create_color_background(layout)
        return

    var sprite = Sprite2D.new()
    sprite.name = "Background"
    sprite.texture = texture
    sprite.centered = false
    sprite.position = Vector2.ZERO
    sprite.z_index = -100
    add_child(sprite)

    # 若 size 未指定，从 texture 推导
    var size = _read_size(layout.get("size", {}), Vector2.ZERO)
    if size == Vector2.ZERO:
        size = Vector2(float(texture.get_width()), float(texture.get_height()))
    if size != Vector2.ZERO:
        _apply_map_bounds(size)

    # 创建底图下的纯色填充（防止透明区域露底）
    var fill = ColorRect.new()
    fill.name = "BackgroundFill"
    fill.color = background_color
    fill.size = size
    fill.position = Vector2.ZERO
    add_child(fill)
    move_child(fill, 0)
```

- [ ] **Step 3: 实现 `_apply_map_bounds()` 辅助方法**

```gdscript
var _map_size := Vector2(1280, 720)

func _apply_map_bounds(size: Vector2) -> void:
    _map_size = size
```

- [ ] **Step 4: 将现有背景创建逻辑抽到 `_create_color_background()`**

```gdscript
func _create_color_background(layout: Dictionary) -> void:
    var size = _read_size(layout.get("size", {}), Vector2(1280, 720))
    _apply_map_bounds(size)
    _add_background(size)
    for obstacle in layout.get("obstacles", []):
        if typeof(obstacle) != TYPE_DICTIONARY:
            continue
        if str(obstacle.get("shape", "rect")) != "rect":
            continue
        var rect = _read_rect(obstacle.get("rect", {}))
        if rect.size.x <= 0.0 or rect.size.y <= 0.0:
            continue
        _add_obstacle(rect)
```

- [ ] **Step 5: 在 Godot 编辑器中运行游戏，确认现有场景不报错**

打开 `foot_village.tscn` 运行，确认纯色背景模式无回归。

- [ ] **Step 6: Commit**

```bash
git add scripts/scenes/map_screen_base.gd
git commit -m "✨ feat(map): 大图底图加载 — _create_image_background()

map_screen_base._create_terrain() 支持按 mode 分派：
big_image → Sprite2D 加载底图；tile_map → 预留；默认 → 原逻辑
"
```

---

### Task 2: tileset JSON 格式定义 + terrain_map

**Files:**
- Create: `data/tilesets/kenney_tiny_battle.json`

**目标：** 为 Kenney tile 素材定义 tileset 配置文件，建立 terrain_id 到 tile 索引和通行属性的映射。

- [ ] **Step 1: 创建 tileset 配置**

`data/tilesets/kenney_tiny_battle.json`:

```json
{
  "id": "kenney_tiny_battle",
  "name": "Kenney Tiny Battle",
  "path": "res://assets/kenney_tiny-battle/Tilemap/tilemap.png",
  "tile_size": {"x": 128, "y": 128},
  "columns": 16,
  "rows": 16,
  "terrain_map": {
    "grass": {"tile_index": 0, "name": "草地", "passable": true, "move_cost": 1},
    "water": {"tile_index": 1, "name": "水域", "passable": false, "move_cost": 99},
    "path": {"tile_index": 2, "name": "山路", "passable": true, "move_cost": 1},
    "mountain": {"tile_index": 3, "name": "山壁", "passable": false, "move_cost": 99},
    "bridge": {"tile_index": 4, "name": "桥", "passable": true, "move_cost": 1},
    "steps": {"tile_index": 5, "name": "石阶", "passable": true, "move_cost": 1},
    "tree": {"tile_index": 6, "name": "树丛", "passable": false, "move_cost": 99}
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add data/tilesets/kenney_tiny_battle.json
git commit -m "✨ feat(map): Kenney tileset 配置 — terrain_map 映射

定义 tile 索引到地形属性的映射：grass/water/path/mountain/bridge/steps/tree"
```

---

### Task 3: NPC 程序素材生成

**Files:**
- Create: `scripts/systems/sprite_generator.gd`
- Create: `assets/characters/villager/walk/` (多个 .png)
- Create: `assets/characters/merchant/walk/` (多个 .png)
- Create: `assets/characters/scholar/walk/` (多个 .png)

**目标：** 程序生成 3 套 NPC 占位精灵帧（村民、掌柜、书生），目录结构与 `hero_yun` 一致。

- [ ] **Step 1: 创建 `sprite_generator.gd`**

```gdscript
@tool
extends RefCounted

## 程序生成角色占位精灵帧，保存为 PNG。
## 目录结构: assets/characters/<character_id>/walk/<direction>/<frame>.png

const CHARACTER_ROOT := "res://assets/characters"
const FRAME_COUNT := 7
const SPRITE_W := 32
const SPRITE_H := 32

static func generate_character(character_id: String, body_color: Color, head_color: Color, detail_color: Color) -> bool:
    var base_dir := "%s/%s/walk" % [CHARACTER_ROOT, character_id]
    var directions := ["down_left", "down_right", "up_left", "up_right"]

    for direction in directions:
        var dir_path := "%s/%s" % [base_dir, direction]
        if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
            continue  # 已有素材，跳过
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

        for frame_index in range(FRAME_COUNT):
            var image := _draw_character_frame(body_color, head_color, detail_color, direction, frame_index)
            var file_path := "%s/%02d.png" % [dir_path, frame_index]
            var absolute := ProjectSettings.globalize_path(file_path)
            var err = image.save_png(absolute)
            if err != OK:
                push_error("无法保存角色帧: %s (err=%d)" % [absolute, err])
                return false
    return true

static func _draw_character_frame(body_color: Color, head_color: Color, detail_color: Color, direction: String, frame_index: int) -> Image:
    var image := Image.create(SPRITE_W, SPRITE_H, false, Image.FORMAT_RGBA8)
    image.fill(Color(0, 0, 0, 0))

    var bob := int(sin(float(frame_index) / float(FRAME_COUNT) * PI * 2.0) * 1.5)
    var leg_swing := int(sin(float(frame_index) / float(FRAME_COUNT) * PI * 2.0) * 2.0)

    # 身体 (矩形 10x12)
    _fill_rect(image, 11, 10 + bob, 10, 12, body_color)

    # 头部 (圆近似 8x8)
    _fill_rect(image, 12, 2 + bob, 8, 8, head_color)
    # 头部高光
    _fill_rect(image, 13, 3 + bob, 3, 2, head_color.lightened(0.3))

    # 腿部
    var left_leg_x := 13 + leg_swing
    var right_leg_x := 17 - leg_swing
    _fill_rect(image, left_leg_x, 22 + bob, 3, 6, body_color.darkened(0.2))
    _fill_rect(image, right_leg_x, 22 + bob, 3, 6, body_color.darkened(0.2))

    # 装饰（腰带/衣领）
    _fill_rect(image, 12, 10 + bob, 8, 2, detail_color)

    # 根据方向做左右镜像
    if direction.contains("left"):
        image.flip_x()

    return image

static func _fill_rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
    for py in range(max(0, y), min(image.get_height(), y + h)):
        for px in range(max(0, x), min(image.get_width(), x + w)):
            image.set_pixel(px, py, color)
```

- [ ] **Step 2: 创建批量生成脚本 `generate_npc_sprites.gd`**

```gdscript
@tool
extends SceneTree

func _init() -> void:
    _generate_all()
    quit()

func _generate_all() -> void:
    var characters := {
        "villager": {"body": Color("#8B7355"), "head": Color("#F5DEB3"), "detail": Color("#654321")},
        "merchant": {"body": Color("#2F4F4F"), "head": Color("#FFE4C4"), "detail": Color("#B8860B")},
        "scholar": {"body": Color("#F5F5F0"), "head": Color("#FFE4C4"), "detail": Color("#2F4F4F")},
    }

    for character_id in characters:
        var colors = characters[character_id]
        print("生成角色素材: %s ..." % character_id)
        var ok = SpriteGenerator.generate_character(character_id, colors["body"], colors["head"], colors["detail"])
        if ok:
            print("  完成")
        else:
            printerr("  失败: %s" % character_id)
```

> **执行方式：** 在 Godot 编辑器命令行运行：
> `godot --headless --script scripts/generate_npc_sprites.gd`

- [ ] **Step 3: 运行生成脚本**

```bash
godot --headless --script scripts/generate_npc_sprites.gd
```

确认 `assets/characters/villager/`、`merchant/`、`scholar/` 下有 4 方向 × 7 帧 PNG。

- [ ] **Step 4: Commit**

```bash
git add scripts/systems/sprite_generator.gd scripts/generate_npc_sprites.gd assets/characters/villager/ assets/characters/merchant/ assets/characters/scholar/
git commit -m "✨ feat(npc): 程序生成 3 套 NPC 占位角色素材

村民(villager)、掌柜(merchant)、书生(scholar)，
4 斜方向 × 7 帧 walk 动画，目录结构对齐 hero_yun"
```

---

### Task 4: WorldLayer + OverlayLayer 搭建

**Files:**
- Modify: `scripts/scenes/map_screen_base.gd`

**目标：** 在场景树中创建分层节点结构，Player 和 NPC 移入 WorldLayer 参与 y-sort。

- [ ] **Step 1: 在 `_ready()` 中加入 `_create_world_layer()` 调用**

在 `_ready()` 中 `_create_terrain()` 之后插入：

```gdscript
func _ready() -> void:
    dialogue_system.set_repository(_get_data_repository())
    _load_map_data()
    _create_terrain()
    _create_layers()          # ← 新增
    _create_player()
    _create_camera()
    _create_ui()
    _spawn_objects()
    _update_quest_text()
```

- [ ] **Step 2: 实现 `_create_layers()`**

```gdscript
var world_layer: Node2D
var overlay_layer: Node2D
var particle_layer: Node2D

func _create_layers() -> void:
    # WorldLayer — 核心遮挡排序层
    world_layer = Node2D.new()
    world_layer.name = "WorldLayer"
    world_layer.y_sort_enabled = true
    add_child(world_layer)

    # OverlayLayer — 始终在角色上方
    overlay_layer = Node2D.new()
    overlay_layer.name = "OverlayLayer"
    overlay_layer.z_index = 50
    add_child(overlay_layer)

    # ParticleLayer — 粒子氛围
    particle_layer = Node2D.new()
    particle_layer.name = "ParticleLayer"
    particle_layer.z_index = 25
    add_child(particle_layer)
```

- [ ] **Step 3: 修改 `_create_player()`，player 加入 WorldLayer**

将 `add_child(player)` 改为 `world_layer.add_child(player)`：

```gdscript
func _create_player() -> void:
    player = PlayerControllerScript.new()
    player.name = "Player"
    player.global_position = _read_spawn_position()
    player.position_changed.connect(_on_player_position_changed)
    player.interact_requested.connect(_interact_with)
    world_layer.add_child(player)  # ← 改为 world_layer
```

- [ ] **Step 4: 修改 `_spawn_objects()`，interactable 加入 WorldLayer**

将 `add_child(interactable)` 改为 `world_layer.add_child(interactable)`：

```gdscript
func _spawn_objects() -> void:
    var game_state = _get_game_state()
    var resolved_objects = game_state.map_state.resolved_objects if game_state != null else []
    var records = spawner.get_spawn_records(map_data, resolved_objects, game_state)
    for record in records:
        var interactable = MapInteractableScript.new()
        interactable.setup(record)
        interactable.clicked.connect(_on_interactable_clicked)
        interactable.player_entered.connect(_on_interactable_entered)
        interactable.player_exited.connect(_on_interactable_exited)
        interactables.append(interactable)
        world_layer.add_child(interactable)  # ← 改为 world_layer
```

- [ ] **Step 5: 修改 `_add_obstacle()` 的视觉引用**

确保 `_add_obstacle()` 创建的 visual ColorRect 也加入 world_layer（或保持 add_child，后续装饰物阶段统一调整）。

- [ ] **Step 6: 运行验证**

启动 `foot_village` 场景，确认玩家、NPC 正常显示和交互无回归。

- [ ] **Step 7: Commit**

```bash
git add scripts/scenes/map_screen_base.gd
git commit -m "✨ feat(map): WorldLayer + OverlayLayer 分层节点树

y_sort_enabled 遮挡排序层就位，Player/NPC 移入 WorldLayer"
```

---

### Task 5: 程序生成 jiangnan_town 底图

**Files:**
- Create: `scripts/systems/map_background_generator.gd`
- Create: `assets/maps/jiangnan_town/` (目录)

**目标：** 程序生成一张 2560×1920 的占位底图，包含草地、土路、水域的基本格局。

- [ ] **Step 1: 创建 `map_background_generator.gd`**

```gdscript
@tool
extends RefCounted

## 程序生成地图底图，包含草地 + 道路 + 水域的基本格局。

static func generate_town_background(output_path: String, width: int, height: int) -> bool:
    var image := Image.create(width, height, false, Image.FORMAT_RGBA8)

    # 基础草地
    for y in range(height):
        for x in range(width):
            var noise := float((sin(float(x) * 0.03) * cos(float(y) * 0.03) + 1.0) / 2.0)
            var green := int(130 + noise * 40)
            var red := int(80 + noise * 30)
            image.set_pixel(x, y, Color(red / 255.0, green / 255.0, 55 / 255.0))

    # 水平主路
    var road_y_center := int(height * 0.42)
    for y in range(road_y_center - 24, road_y_center + 24):
        for x in range(0, width):
            image.set_pixel(x, y, Color(0.82, 0.75, 0.60))

    # 垂直路（右侧）
    var road_x_center := int(width * 0.75)
    for x in range(road_x_center - 20, road_x_center + 20):
        for y in range(0, road_y_center):
            image.set_pixel(x, y, Color(0.82, 0.75, 0.60))

    # 水域（左下）
    for y in range(int(height * 0.65), height):
        for x in range(0, int(width * 0.35)):
            image.set_pixel(x, y, Color(0.25, 0.45, 0.70))

    # 水域波纹
    for y in range(int(height * 0.65), height):
        for x in range(0, int(width * 0.35)):
            var ripple := sin(float(x) * 0.2 + float(y) * 0.1) * 0.05
            var pixel := image.get_pixel(x, y)
            image.set_pixel(x, y, pixel.lightened(ripple))

    var dir_path := output_path.get_base_dir()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

    var err = image.save_png(ProjectSettings.globalize_path(output_path))
    if err != OK:
        push_error("无法保存底图: %s" % output_path)
        return false
    return true
```

- [ ] **Step 2: 运行生成**

在 Godot 中临时创建一个脚本调用 `MapBackgroundGenerator.generate_town_background("res://assets/maps/jiangnan_town/background.png", 2560, 1920)`，或直接在编辑器的脚本编辑器中运行。

- [ ] **Step 3: 验证文件**

确认 `assets/maps/jiangnan_town/background.png` 存在且尺寸为 2560×1920。

- [ ] **Step 4: Commit**

```bash
git add scripts/systems/map_background_generator.gd assets/maps/jiangnan_town/background.png
git commit -m "✨ feat(map): 程序生成 jiangnan_town 占位底图

2560×1920，包含草地+土路+水域格局"
```

---

### Task 6: TileMap 运行时加载 — `_create_tile_map_background()`

**Files:**
- Modify: `scripts/scenes/map_screen_base.gd`

**目标：** 实现 `_create_tile_map_background()`，从 JSON 的 `layers` 数据动态写入 TileMapLayer。

- [ ] **Step 1: 实现 `_create_tile_map_background()`**

```gdscript
func _create_tile_map_background(layout: Dictionary) -> void:
    var tileset_config_path = str(layout.get("tileset", {}).get("config", "res://data/tilesets/kenney_tiny_battle.json"))
    var tileset_config := _load_tileset_config(tileset_config_path)
    if tileset_config.is_empty():
        _create_color_background(layout)
        return

    var tile_size := Vector2i(
        int(tileset_config.get("tile_size", {}).get("x", 128)),
        int(tileset_config.get("tile_size", {}).get("y", 128))
    )
    var terrain_map: Dictionary = tileset_config.get("terrain_map", {})

    var layers: Dictionary = layout.get("layers", {})

    # ground / decoration / overlay 按顺序创建
    var layer_order := ["ground", "decoration", "overlay"]
    var terrain_layer_index := 0

    for layer_name in layer_order:
        var grid: Array = layers.get(layer_name, [])
        if grid.is_empty():
            continue

        var tile_map_layer := TileMapLayer.new()
        tile_map_layer.name = layer_name.capitalize()
        tile_map_layer.tile_set = _build_tileset(tileset_config_path, tile_size, terrain_map)
        tile_map_layer.z_index = terrain_layer_index
        terrain_layer_index += 1
        add_child(tile_map_layer)

        for row_idx in range(grid.size()):
            var row = grid[row_idx]
            if typeof(row) != TYPE_ARRAY:
                continue
            for col_idx in range(row.size()):
                var terrain_id = str(row[col_idx])
                if terrain_id.is_empty() or terrain_id == "null":
                    continue
                var terrain = terrain_map.get(terrain_id, {})
                if terrain.is_empty():
                    continue
                var tile_coord := Vector2i(
                    int(terrain.get("tile_index", 0)) % int(tileset_config.get("columns", 16)),
                    int(terrain.get("tile_index", 0)) / int(tileset_config.get("columns", 16))
                )
                tile_map_layer.set_cell(Vector2i(col_idx, row_idx), 0, tile_coord)

        # 非 ground 层始终在 WorldLayer 上方
        if layer_name in ["decoration", "overlay"]:
            tile_map_layer.z_index = 10 if layer_name == "decoration" else 60

    var size := _read_size(layout.get("size", {}), Vector2(2560, 1920))
    _apply_map_bounds(size)
```

- [ ] **Step 2: 实现辅助方法 `_load_tileset_config()` 和 `_build_tileset()`**

```gdscript
func _load_tileset_config(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("tileset 配置不存在: %s" % path)
        return {}
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    return parsed

func _build_tileset(config_path: String, tile_size: Vector2i, terrain_map: Dictionary) -> TileSet:
    var tileset := TileSet.new()
    tileset.tile_size = tile_size

    var image_path = str(_load_tileset_config(config_path).get("path", ""))
    if image_path.is_empty():
        return tileset

    var texture: Texture2D = null
    if ResourceLoader.exists(image_path, "Texture2D"):
        texture = load(image_path)
    if texture == null:
        return tileset

    var source := TileSetAtlasSource.new()
    source.texture = texture
    source.texture_region_size = tile_size
    var source_id := tileset.add_source(source)

    # 为每个 terrain 注册 tile
    for terrain_id in terrain_map:
        var terrain = terrain_map[terrain_id]
        var tile_index := int(terrain.get("tile_index", -1))
        if tile_index < 0:
            continue
        var columns := int(texture.get_width() / tile_size.x)
        var atlas_coords := Vector2i(tile_index % columns, tile_index / columns)
        source.create_tile(atlas_coords)

    return tileset
```

- [ ] **Step 3: 运行验证**

暂无完整 TileMap 配置，先用简单测试数据在代码中临时验证 `_create_tile_map_background` 可被调用且不报错。

- [ ] **Step 4: Commit**

```bash
git add scripts/scenes/map_screen_base.gd
git commit -m "✨ feat(map): TileMap 运行时加载 — _create_tile_map_background()

从 layers JSON 数据动态 set_cell 到 TileMapLayer，
支持 ground/decoration/overlay 三层"
```

---

### Task 7: MapInteractable NPC 升级 — AnimatedSprite2D

**Files:**
- Modify: `scripts/scenes/map_interactable.gd`
- Create: `scripts/scenes/npc_sprite_loader.gd`

**目标：** NPC 类型 MapInteractable 从 actor 配置加载角色精灵，播放动画，替代纯色方块。

- [ ] **Step 1: 创建 `npc_sprite_loader.gd`**

```gdscript
extends RefCounted

const CharacterSpriteLoader = preload("res://scripts/scenes/character_sprite_loader.gd")
const SimpleSpriteFactory = preload("res://scripts/scenes/simple_sprite_factory.gd")

static func create_npc_sprite(record: Dictionary) -> Node2D:
    var container := Node2D.new()
    var character_id := str(record.get("character_id", ""))
    var actor_id := str(record.get("actor_id", ""))

    # 尝试加载角色精灵帧
    var frames: SpriteFrames = null
    if not character_id.is_empty():
        frames = CharacterSpriteLoader.create_walk_frames(character_id, "walk")
    elif not actor_id.is_empty():
        # 从 DataRepository 查找 actor 配置
        frames = _load_actor_frames(actor_id)

    var sprite: Node2D
    if frames != null:
        var animated := AnimatedSprite2D.new()
        animated.sprite_frames = frames
        animated.animation = frames.get_animation_names()[0] if frames.get_animation_names().size() > 0 else ""
        animated.play()
        animated.frame = randi() % frames.get_frame_count(animated.animation)
        sprite = animated
    else:
        # 回退到程序生成精灵
        var static_sprite := Sprite2D.new()
        static_sprite.texture = _make_npc_fallback_texture(record)
        sprite = static_sprite

    container.add_child(sprite)
    return container

static func _load_actor_frames(actor_id: String) -> SpriteFrames:
    var repo = _get_repository()
    if repo == null:
        return null
    var actor = repo.get_actor(actor_id)
    if actor.is_empty():
        return null
    var character_id = str(actor.get("character_id", ""))
    if character_id.is_empty():
        return null
    return CharacterSpriteLoader.create_walk_frames(character_id, "walk")

static func _make_npc_fallback_texture(record: Dictionary) -> Texture2D:
    var image := Image.create(24, 32, false, Image.FORMAT_RGBA8)
    image.fill(Color(0, 0, 0, 0))
    var color := Color("#8d3b7a")  # NPC 默认色
    for y in range(8, 28):
        for x in range(7, 17):
            image.set_pixel(x, y, color)
    for y in range(3, 10):
        for x in range(8, 16):
            image.set_pixel(x, y, color.lightened(0.3))
    return ImageTexture.create_from_image(image)

static func _get_repository():
    var loop = Engine.get_main_loop()
    if loop == null or loop.root == null:
        return null
    if loop.root.has_node("DataRepository"):
        return loop.root.get_node("DataRepository")
    return null
```

- [ ] **Step 2: 修改 `map_interactable.gd` 的 `setup()` 方法**

将 NPC 类型的视觉从 ColorRect 改为 AnimatedSprite2D：

```gdscript
const NPCSpriteLoader = preload("res://scripts/scenes/npc_sprite_loader.gd")

var npc_visual: Node2D

func setup(next_record: Dictionary) -> void:
    record = next_record.duplicate(true)
    name = str(record.get("id", "MapInteractable"))
    global_position = _read_position(record.get("position", {}))

    var shape = CollisionShape2D.new()
    var circle = CircleShape2D.new()
    circle.radius = float(record.get("radius", 48.0))
    shape.shape = circle
    add_child(shape)

    var object_type = str(record.get("type", ""))

    if object_type == "npc":
        # NPC 使用 AnimatedSprite2D 或回退精灵
        npc_visual = NPCSpriteLoader.create_npc_sprite(record)
        add_child(npc_visual)
    else:
        # 非 NPC 保持 ColorRect 视觉
        var visual = ColorRect.new()
        visual.size = Vector2(24, 24)
        visual.position = Vector2(-12, -12)
        visual.color = _read_color()
        add_child(visual)

    label = Label.new()
    label.text = str(record.get("name", ""))
    if object_type == "npc":
        label.position = Vector2(-32, -44)  # NPC 精灵更高，标签上移
    else:
        label.position = Vector2(-32, -36)
    label.size = Vector2(96, 24)
    add_child(label)

    input_event.connect(_on_input_event)
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
```

- [ ] **Step 3: 验证**

启动 `foot_village`，确认 NPC（陈脚夫、陆掌柜等）现在使用从 actor 配置加载的精灵，或回退精灵（因为现有 actor 可能没有 `character_id` 字段）。

- [ ] **Step 4: Commit**

```bash
git add scripts/scenes/map_interactable.gd scripts/scenes/npc_sprite_loader.gd
git commit -m "✨ feat(npc): MapInteractable NPC 升级为 AnimatedSprite2D

NPC 类型从 actor 配置加载角色精灵帧，播放动画；
无素材时回退程序生成纹理"
```

---

### Task 8: 多边形碰撞 + F3 调试显示

**Files:**
- Modify: `scripts/scenes/map_screen_base.gd`
- Modify: `scripts/core/event_bus.gd`

**目标：** 支持 `shape: "polygon"` 障碍物，F3 键切换显示碰撞区/交互区/传送区。

- [ ] **Step 1: EventBus 新增 debug 信号**

在 `scripts/core/event_bus.gd` 追加：

```gdscript
signal debug_toggled(visible: bool)
```

- [ ] **Step 2: 改造 `_add_obstacle()` 支持多边形**

```gdscript
func _add_obstacle(obstacle: Dictionary) -> void:
    var body = StaticBody2D.new()
    var shape_type = str(obstacle.get("shape", "rect"))

    match shape_type:
        "polygon":
            var points = obstacle.get("points", [])
            if typeof(points) != TYPE_ARRAY or points.size() < 3:
                push_warning("多边形碰撞缺少顶点: %s" % str(obstacle.get("id", "")))
                return
            var polygon = CollisionPolygon2D.new()
            var vertex_array := PackedVector2Array()
            for point in points:
                if typeof(point) == TYPE_DICTIONARY:
                    vertex_array.append(Vector2(float(point.get("x", 0.0)), float(point.get("y", 0.0))))
            polygon.polygon = vertex_array
            body.add_child(polygon)
        _:
            var rect = _read_rect(obstacle.get("rect", {}))
            if rect.size.x <= 0.0 or rect.size.y <= 0.0:
                return
            body.position = rect.position
            var shape = CollisionShape2D.new()
            var rectangle = RectangleShape2D.new()
            rectangle.size = rect.size
            shape.shape = rectangle
            shape.position = rect.size / 2.0
            body.add_child(shape)

    body.name = str(obstacle.get("id", "Obstacle"))
    add_child(body)
```

- [ ] **Step 3: 改造 `_create_color_background()` 中的障碍物循环**

将原有逐个 `_add_obstacle(rect)` 调用统一改为遍历 obstacles 数组并调用新的 `_add_obstacle(obstacle_dict)`。

- [ ] **Step 4: 实现 `_create_debug_overlay()`**

```gdscript
var debug_layer: CanvasLayer
var debug_visible := false

func _create_debug_overlay() -> void:
    debug_layer = CanvasLayer.new()
    debug_layer.name = "DebugLayer"
    debug_layer.layer = 100
    debug_layer.visible = false
    add_child(debug_layer)

    var draw_node := Node2D.new()
    draw_node.name = "DebugDraw"
    debug_layer.add_child(draw_node)
```

- [ ] **Step 5: 实现 F3 输入处理和 EventBus 信号**

在 `_unhandled_input()` 中添加：

```gdscript
if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
    debug_visible = not debug_visible
    if debug_layer != null:
        debug_layer.visible = debug_visible
    var bus = _get_autoload("EventBus")
    if bus != null:
        bus.debug_toggled.emit(debug_visible)
    return
```

- [ ] **Step 6: 实现 `_draw_debug()` 在 DebugLayer 上绘制**

在 map_screen_base 的 `_ready()` 末尾调用 `_create_debug_overlay()`，并实现简单的 debug 绘制逻辑（为每个碰撞体添加半透明矩形子节点、为每个 interactable 添加蓝色圆形、为 exit 添加黄色圆形）。

> 注：完整 debug 绘制逻辑需监听 `debug_toggled` 信号并动态创建/销毁可视化节点。此处提供骨架，具体绘制在后续步骤细化。

- [ ] **Step 7: 运行验证**

启动 foot_village，按 F3 确认 debug 层切换，确认现有矩形碰撞无回归。

- [ ] **Step 8: Commit**

```bash
git add scripts/scenes/map_screen_base.gd scripts/core/event_bus.gd
git commit -m "✨ feat(map): 多边形碰撞 + F3 调试显示

CollisionPolygon2D 支持，EventBus.debug_toggled 信号，F3 切换"
```

---

### Task 9: 相机边界 + 缩放配置

**Files:**
- Modify: `scripts/scenes/map_screen_base.gd`

**目标：** 从 layout JSON 读取 camera 配置，设置 Camera2D 的 limit 和 zoom。

- [ ] **Step 1: 修改 `_create_camera()`**

```gdscript
func _create_camera() -> void:
    var camera = Camera2D.new()
    camera.position_smoothing_enabled = true
    player.add_child(camera)
    camera.make_current()

    # 读取 camera 配置
    var layout = _get_layout_data()
    var camera_config = layout.get("camera", {})
    if typeof(camera_config) == TYPE_DICTIONARY:
        var zoom_value = float(camera_config.get("zoom", 1.0))
        if zoom_value > 0.0:
            camera.zoom = Vector2(zoom_value, zoom_value)

        var bounds = camera_config.get("bounds", {})
        if typeof(bounds) == TYPE_DICTIONARY:
            camera.limit_left = int(bounds.get("x", -10000000))
            camera.limit_top = int(bounds.get("y", -10000000))
            camera.limit_right = int(bounds.get("x", 0)) + int(bounds.get("w", 10000000))
            camera.limit_bottom = int(bounds.get("y", 0)) + int(bounds.get("h", 10000000))
        elif _map_size != Vector2.ZERO:
            # 无显式 bounds 时用 map size
            camera.limit_left = 0
            camera.limit_top = 0
            camera.limit_right = int(_map_size.x)
            camera.limit_bottom = int(_map_size.y)
```

- [ ] **Step 2: 运行验证**

启动 foot_village，确认相机跟踪正常，移动到边界时不露出空白。

- [ ] **Step 3: Commit**

```bash
git add scripts/scenes/map_screen_base.gd
git commit -m "✨ feat(map): 相机边界限制 + 缩放配置

读取 layout.camera.{zoom,bounds}，设置 Camera2D.limit"
```

---

### Task 10: 装饰物系统 + 程序纹理

**Files:**
- Modify: `scripts/scenes/map_screen_base.gd`
- Modify: `scripts/systems/sprite_generator.gd`

**目标：** 实现 `_spawn_decorations()`，7 种装饰物类型的程序纹理生成 + 碰撞/遮挡分派。

- [ ] **Step 1: 在 `sprite_generator.gd` 中新增装饰物纹理生成**

```gdscript
static func generate_decoration_texture(deco_type: String) -> Texture2D:
    var image: Image
    match deco_type:
        "tree":
            image = _make_tree_texture()
        "bush":
            image = _make_bush_texture()
        "rock":
            image = _make_rock_texture()
        "signpost":
            image = _make_signpost_texture()
        "lantern":
            image = _make_lantern_texture()
        "building":
            image = _make_building_texture()
        "bridge":
            image = _make_bridge_texture()
        _:
            image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
            image.fill(Color.GRAY)
    return ImageTexture.create_from_image(image)

static func _make_tree_texture() -> Image:
    var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    # 树干 (棕色矩形)
    for y in range(48, 96):
        for x in range(26, 38):
            img.set_pixel(x, y, Color(0.55, 0.35, 0.15))
    # 树冠 (绿色椭圆)
    for y in range(0, 56):
        for x in range(4, 60):
            var dx := float(x - 32) / 28.0
            var dy := float(y - 28) / 28.0
            if dx * dx + dy * dy <= 1.0:
                img.set_pixel(x, y, Color(0.2, 0.55, 0.15))
    return img

static func _make_bush_texture() -> Image:
    var img := Image.create(32, 20, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    for y in range(0, 20):
        for x in range(0, 32):
            var dx := float(x - 16) / 16.0
            var dy := float(y - 10) / 10.0
            if dx * dx + dy * dy * 1.5 <= 1.0:
                img.set_pixel(x, y, Color(0.15, 0.5, 0.1))
    return img

static func _make_rock_texture() -> Image:
    var img := Image.create(40, 24, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    for y in range(0, 24):
        for x in range(0, 40):
            var dx := float(x - 20) / 20.0
            var dy := float(y - 12) / 12.0
            if dx * dx + dy * dy * 0.7 <= 1.0:
                img.set_pixel(x, y, Color(0.45, 0.42, 0.38))
    return img

static func _make_signpost_texture() -> Image:
    var img := Image.create(12, 40, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    for y in range(0, 40):
        for x in range(4, 8):
            img.set_pixel(x, y, Color(0.5, 0.35, 0.15))
    for y in range(4, 14):
        for x in range(0, 12):
            img.set_pixel(x, y, Color(0.6, 0.45, 0.25))
    return img

static func _make_lantern_texture() -> Image:
    var img := Image.create(16, 32, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    for y in range(0, 20):
        for x in range(7, 9):
            img.set_pixel(x, y, Color(0.4, 0.3, 0.2))
    for y in range(20, 32):
        for x in range(3, 13):
            var dx := float(x - 8) / 5.0
            var dy := float(y - 26) / 6.0
            if dx * dx + dy * dy <= 1.0:
                img.set_pixel(x, y, Color(0.9, 0.2, 0.1))
    return img

static func _make_building_texture() -> Image:
    # 屋身 + 屋檐拆分：调用方分别取上半和下半
    var img := Image.create(160, 160, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    # 屋身
    for y in range(48, 160):
        for x in range(16, 144):
            img.set_pixel(x, y, Color(0.55, 0.4, 0.25))
    # 屋顶三角
    for y in range(0, 52):
        for x in range(0, 160):
            var roof_slope := abs(float(x - 80) / 80.0)
            if roof_slope < float(y) / 52.0:
                img.set_pixel(x, y, Color(0.35, 0.25, 0.15))
    return img

static func _make_bridge_texture() -> Image:
    var img := Image.create(128, 32, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    for y in range(8, 24):
        for x in range(4, 124):
            img.set_pixel(x, y, Color(0.55, 0.4, 0.2))
    # 栏杆柱
    for i in range(0, 5):
        var cx := 16 + i * 24
        for y in range(0, 32):
            for x in range(cx - 2, cx + 2):
                img.set_pixel(x, y, Color(0.45, 0.3, 0.15))
    return img
```

- [ ] **Step 2: 实现 `_spawn_decorations()` 在 map_screen_base.gd**

```gdscript
func _spawn_decorations() -> void:
    var layout = _get_layout_data()
    var decorations = layout.get("decorations", [])
    if typeof(decorations) != TYPE_ARRAY:
        return

    for deco in decorations:
        if typeof(deco) != TYPE_DICTIONARY:
            continue
        var deco_type = str(deco.get("type", ""))
        var position = Vector2(
            float(deco.get("position", {}).get("x", 0.0)),
            float(deco.get("position", {}).get("y", 0.0))
        )
        var has_overlay = bool(deco.get("has_overlay", false))
        var has_collision = bool(deco.get("has_collision", false))

        if has_overlay and deco_type in ["tree", "building"]:
            # 拆分：下半进 WorldLayer，上半进 OverlayLayer
            _spawn_split_decoration(deco_type, position, has_collision)
        else:
            var sprite = Sprite2D.new()
            sprite.texture = SpriteGenerator.generate_decoration_texture(deco_type)
            sprite.position = position
            if has_overlay:
                overlay_layer.add_child(sprite)
            else:
                world_layer.add_child(sprite)

            if has_collision:
                var body = StaticBody2D.new()
                body.position = position
                var shape = CollisionShape2D.new()
                var rect = RectangleShape2D.new()
                rect.size = Vector2(32, 16)
                shape.shape = rect
                body.add_child(shape)
                add_child(body)

func _spawn_split_decoration(deco_type: String, position: Vector2, has_collision: bool) -> void:
    var full_texture = SpriteGenerator.generate_decoration_texture(deco_type)
    var tex_height := float(full_texture.get_height())
    var split_y := tex_height * 0.5  # 一半高度处拆分

    # 下半 — WorldLayer
    var lower = Sprite2D.new()
    lower.texture = full_texture
    lower.position = position
    lower.region_enabled = true
    lower.region_rect = Rect2(0, split_y, full_texture.get_width(), tex_height - split_y)
    lower.offset = Vector2(0, -split_y)
    world_layer.add_child(lower)

    # 上半 — OverlayLayer
    var upper = Sprite2D.new()
    upper.texture = full_texture
    upper.position = position
    upper.region_enabled = true
    upper.region_rect = Rect2(0, 0, full_texture.get_width(), split_y)
    overlay_layer.add_child(upper)

    if has_collision:
        var body = StaticBody2D.new()
        body.position = position + Vector2(0, tex_height * 0.5)
        var shape = CollisionShape2D.new()
        var rect = RectangleShape2D.new()
        rect.size = Vector2(full_texture.get_width() * 0.5, tex_height * 0.3)
        shape.shape = rect
        shape.position = Vector2(0, tex_height * 0.15)
        body.add_child(shape)
        add_child(body)
```

- [ ] **Step 3: 在 `_ready()` 中添加调用**

在 `_create_ui()` 之前插入 `_spawn_decorations()`。

- [ ] **Step 4: Commit**

```bash
git add scripts/scenes/map_screen_base.gd scripts/systems/sprite_generator.gd
git commit -m "✨ feat(map): 装饰物系统 — 7 种类型程序纹理 + 碰撞/遮挡分派

tree/bush/rock/signpost/lantern/building/bridge，
支持上半 OverlayLayer + 下半 WorldLayer 拆分"
```

---

### Task 11: 粒子效果系统

**Files:**
- Modify: `scripts/scenes/map_screen_base.gd`

**目标：** 实现 `_spawn_particles()`，支持 cloud/fog/leaves/water/snow 五种粒子。

- [ ] **Step 1: 实现 `_spawn_particles()`**

```gdscript
func _spawn_particles() -> void:
    var layout = _get_layout_data()
    var particles = layout.get("particles", [])
    if typeof(particles) != TYPE_ARRAY:
        return

    for particle_cfg in particles:
        if typeof(particle_cfg) != TYPE_DICTIONARY:
            continue
        var particle_type = str(particle_cfg.get("type", ""))
        match particle_type:
            "cloud":
                _spawn_cloud_particles(particle_cfg)
            "fog":
                _spawn_fog_particles(particle_cfg)
            "leaves":
                _spawn_leaves_particles(particle_cfg)
            "water":
                _spawn_water_animation(particle_cfg)
            "snow":
                _spawn_snow_particles(particle_cfg)

func _spawn_cloud_particles(cfg: Dictionary) -> void:
    var particles = GPUParticles2D.new()
    particles.name = str(cfg.get("id", "clouds"))
    particles.amount = 8
    particles.lifetime = 30.0
    particles.one_shot = false
    particles.explosiveness = 0.0

    var region = cfg.get("region", {})
    var rx := float(region.get("x", 0.0))
    var ry := float(region.get("y", 0.0))
    var rw := float(region.get("w", 2560.0))
    var rh := float(region.get("h", 200.0))

    var process_material = ParticleProcessMaterial.new()
    process_material.spread = 90.0
    process_material.direction = Vector3(1, 0, 0)
    process_material.initial_velocity_min = 15.0
    process_material.initial_velocity_max = 30.0
    process_material.scale_min = 3.0
    process_material.scale_max = 6.0
    process_material.color = Color(1.0, 1.0, 1.0, 0.25)
    particles.process_material = process_material

    particles.position = Vector2(rx + rw / 2.0, ry)
    particles.emitting = true
    particle_layer.add_child(particles)

    # 用简单白色圆形作为粒子纹理
    var tex := Image.create(16, 8, false, Image.FORMAT_RGBA8)
    tex.fill(Color(1, 1, 1, 1))
    particles.texture = ImageTexture.create_from_image(tex)

func _spawn_fog_particles(cfg: Dictionary) -> void:
    var particles = GPUParticles2D.new()
    particles.name = str(cfg.get("id", "fog"))
    particles.amount = 20
    particles.lifetime = 20.0
    particles.one_shot = false
    particles.explosiveness = 0.0

    var process_material = ParticleProcessMaterial.new()
    process_material.spread = 180.0
    process_material.direction = Vector3(0.5, 0, 0)
    process_material.initial_velocity_min = 5.0
    process_material.initial_velocity_max = 15.0
    process_material.scale_min = 5.0
    process_material.scale_max = 10.0
    process_material.color = Color(1.0, 1.0, 1.0, 0.12)
    particles.process_material = process_material

    var layout = _get_layout_data()
    var size = _read_size(layout.get("size", {}), Vector2(1280, 720))
    particles.position = Vector2(size.x / 2.0, size.y / 2.0)
    particles.emitting = true
    particle_layer.add_child(particles)

    var tex := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    tex.fill(Color(1, 1, 1, 1))
    particles.texture = ImageTexture.create_from_image(tex)

func _spawn_leaves_particles(cfg: Dictionary) -> void:
    var particles = CPUParticles2D.new()
    particles.name = str(cfg.get("id", "leaves"))
    particles.amount = 15
    particles.lifetime = 4.0
    particles.one_shot = false
    particles.explosiveness = 0.3
    particles.spread = 60.0
    particles.direction = Vector2(0.5, 1.0)
    particles.initial_velocity_min = 20.0
    particles.initial_velocity_max = 60.0
    particles.gravity = Vector2(0, 30)
    particles.scale_min = 0.5
    particles.scale_max = 1.2
    particles.color = Color(0.9, 0.5, 0.15, 0.7)

    var position_data = cfg.get("position", {})
    particles.position = Vector2(float(position_data.get("x", 640.0)), float(position_data.get("y", 100.0)))
    particles.emitting = true
    particle_layer.add_child(particles)

    var tex := Image.create(4, 4, false, Image.FORMAT_RGBA8)
    tex.fill(Color(1, 1, 1, 1))
    particles.texture = ImageTexture.create_from_image(tex)

func _spawn_water_animation(cfg: Dictionary) -> void:
    # 水面用 AnimatedSprite2D 循环帧
    var sprite = AnimatedSprite2D.new()
    sprite.name = str(cfg.get("id", "water"))
    var position_data = cfg.get("position", {})
    sprite.position = Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))

    var frames = SpriteFrames.new()
    frames.add_animation("ripple")
    frames.set_animation_speed("ripple", 3.0)
    frames.set_animation_loop("ripple", true)
    for i in range(4):
        var img := Image.create(320, 80, false, Image.FORMAT_RGBA8)
        img.fill(Color(0, 0, 0, 0))
        for y in range(0, 80):
            for x in range(0, 320):
                var wave := sin(float(x) * 0.05 + float(i) * PI / 2.0) * 0.08
                var alpha := 0.15 + wave
                img.set_pixel(x, y, Color(0.3, 0.55, 0.85, alpha))
        frames.add_frame("ripple", ImageTexture.create_from_image(img))
    sprite.sprite_frames = frames
    sprite.play("ripple")
    sprite.z_index = -5
    add_child(sprite)

func _spawn_snow_particles(_cfg: Dictionary) -> void:
    # 第一版预留：创建但不默认开启
    pass
```

- [ ] **Step 2: 在 `_ready()` 中添加调用**

在 `_spawn_decorations()` 之后插入 `_spawn_particles()`。

- [ ] **Step 3: Commit**

```bash
git add scripts/scenes/map_screen_base.gd
git commit -m "✨ feat(map): 粒子氛围系统 — cloud/fog/leaves/water

GPUParticles2D 云朵/薄雾，CPUParticles2D 落叶，
AnimatedSprite2D 水面波纹，snow 预留"
```

---

### Task 12: 编辑器预览适配 — 底图 + TileMap + 装饰物

**Files:**
- Modify: `addons/map_preview/map_preview_renderer.gd`
- Modify: `addons/map_preview/map_layout_document.gd`

**目标：** 编辑器预览支持大图底图加载、TileMap 数据预览、装饰物对象渲染。

- [ ] **Step 1: 改造 `_create_background()` 支持两种模式**

```gdscript
func _create_background(layout: Dictionary) -> Node2D:
    var mode = str(layout.get("mode", ""))
    var background_data = layout.get("background", {})

    match mode:
        "big_image":
            return _create_image_preview(background_data, layout)
        "tile_map":
            return _create_tile_preview(layout)
        _:
            return _create_color_preview(layout)

func _create_image_preview(background_data: Dictionary, layout: Dictionary) -> Node2D:
    var container = Node2D.new()
    container.name = "Background"

    var image_path = str(background_data.get("path", ""))
    if not image_path.is_empty() and ResourceLoader.exists(image_path, "Texture2D"):
        var sprite = Sprite2D.new()
        sprite.texture = load(image_path)
        sprite.centered = false
        container.add_child(sprite)

    return container

func _create_tile_preview(layout: Dictionary) -> Node2D:
    # 编辑器内简单预览：对每层创建 ColorRect 网格表示 tile
    var container = Node2D.new()
    container.name = "Background"
    var layers = layout.get("layers", {})
    var tileset_config = layout.get("tileset", {})
    var tile_size = Vector2(
        float(tileset_config.get("tile_size", {}).get("x", 128.0)),
        float(tileset_config.get("tile_size", {}).get("y", 128.0))
    )
    var terrain_map = tileset_config.get("terrain_map", {})
    var layer_colors := {"ground": Color.GREEN, "decoration": Color.ORANGE, "overlay": Color.RED}

    for layer_name in ["ground", "decoration", "overlay"]:
        var grid = layers.get(layer_name, [])
        if typeof(grid) != TYPE_ARRAY or grid.is_empty():
            continue
        for row_idx in range(grid.size()):
            var row = grid[row_idx]
            if typeof(row) != TYPE_ARRAY:
                continue
            for col_idx in range(row.size()):
                var terrain_id = str(row[col_idx])
                if terrain_id.is_empty() or terrain_id == "null":
                    continue
                var cell = ColorRect.new()
                cell.size = tile_size
                cell.position = Vector2(col_idx * tile_size.x, row_idx * tile_size.y)
                var tint = layer_colors.get(layer_name, Color.GRAY)
                cell.color = tint.darkened(0.5)
                cell.color.a = 0.4
                container.add_child(cell)

    return container

func _create_color_preview(layout: Dictionary) -> ColorRect:
    var background = ColorRect.new()
    background.name = "Background"
    var size_data = layout.get("size", {})
    background.size = Vector2(float(size_data.get("x", 1280.0)), float(size_data.get("y", 720.0)))
    var background_data = layout.get("background", {})
    var color = str(background_data.get("color", "#334433"))
    background.color = Color(color) if Color.html_is_valid(color) else Color("#334433")
    return background
```

- [ ] **Step 2: 在 renderer 中为 decorations 创建预览节点**

在 `render()` 方法中 `_create_background` 之后加入：

```gdscript
var decorations_container = Node2D.new()
decorations_container.name = "Decorations"
preview.add_child(decorations_container)
for deco in layout.get("decorations", []):
    if typeof(deco) != TYPE_DICTIONARY:
        continue
    var deco_node = ColorRect.new()
    deco_node.name = str(deco.get("id", ""))
    var pos = deco.get("position", {})
    deco_node.position = Vector2(float(pos.get("x", 0)), float(pos.get("y", 0)))
    deco_node.size = Vector2(32, 32)
    deco_node.color = _deco_color(str(deco.get("type", "")))
    decorations_container.add_child(deco_node)

func _deco_color(deco_type: String) -> Color:
    match deco_type:
        "tree": return Color.GREEN
        "bush": return Color.DARK_GREEN
        "rock": return Color.GRAY
        "signpost": return Color.BROWN
        "lantern": return Color.RED
        "building": return Color.SADDLE_BROWN
        "bridge": return Color.TAN
        _: return Color.MAGENTA
```

- [ ] **Step 3: Commit**

```bash
git add addons/map_preview/map_preview_renderer.gd addons/map_preview/map_layout_document.gd
git commit -m "✨ feat(editor): 编辑器预览适配大图底图 + TileMap + 装饰物

_create_background() 按 mode 分派，新增 image/tile 两种预览模式"
```

---

### Task 13: 校验扩展

**Files:**
- Modify: `addons/map_preview/content_reference_validator.gd`

**目标：** 新增检查底图路径、tileset 配置路径、decoration type 合法性、particle type 合法性。

- [ ] **Step 1: 扩展 `validate_map()` 方法**

在现有校验后追加：

```gdscript
# 校验 layout 文件中的字段
var layout = _load_layout(map_id)
if not layout.is_empty():
    _validate_layout(issues, layout)
```

- [ ] **Step 2: 实现 `_validate_layout()`**

```gdscript
const VALID_DECO_TYPES := ["tree", "bush", "rock", "signpost", "lantern", "building", "bridge"]
const VALID_PARTICLE_TYPES := ["cloud", "fog", "leaves", "water", "snow"]

func _validate_layout(issues: Array[Dictionary], layout: Dictionary) -> void:
    var mode = str(layout.get("mode", ""))

    # 大图底图模式
    if mode == "big_image":
        var bg_path = str(layout.get("background", {}).get("path", ""))
        if not bg_path.is_empty() and not FileAccess.file_exists(bg_path):
            issues.append(_issue(SEVERITY_WARNING, "", "background.path", "底图文件不存在：%s" % bg_path))

    # TileMap 模式
    if mode == "tile_map":
        var tileset_config = str(layout.get("tileset", {}).get("config", ""))
        if tileset_config.is_empty():
            issues.append(_issue(SEVERITY_ERROR, "", "tileset.config", "TileMap 模式缺少 tileset 配置路径"))
        elif not FileAccess.file_exists(tileset_config):
            issues.append(_issue(SEVERITY_ERROR, "", "tileset.config", "tileset 配置文件不存在：%s" % tileset_config))
        _validate_tile_layers(issues, layout.get("layers", {}))

    # 装饰物校验
    var decorations = layout.get("decorations", [])
    if typeof(decorations) == TYPE_ARRAY:
        for deco in decorations:
            if typeof(deco) != TYPE_DICTIONARY:
                continue
            var deco_type = str(deco.get("type", ""))
            var deco_id = str(deco.get("id", ""))
            if deco_type.is_empty():
                issues.append(_issue(SEVERITY_WARNING, deco_id, "type", "装饰物缺少类型"))
            elif not VALID_DECO_TYPES.has(deco_type):
                issues.append(_issue(SEVERITY_WARNING, deco_id, "type", "未知装饰物类型：%s" % deco_type))

    # 粒子校验
    var particles = layout.get("particles", [])
    if typeof(particles) == TYPE_ARRAY:
        for p in particles:
            if typeof(p) != TYPE_DICTIONARY:
                continue
            var ptype = str(p.get("type", ""))
            var pid = str(p.get("id", ""))
            if not VALID_PARTICLE_TYPES.has(ptype):
                issues.append(_issue(SEVERITY_WARNING, pid, "type", "未知粒子类型：%s" % ptype))

func _validate_tile_layers(issues: Array[Dictionary], layers: Dictionary) -> void:
    for layer_name in layers:
        var grid = layers[layer_name]
        if typeof(grid) != TYPE_ARRAY:
            issues.append(_issue(SEVERITY_ERROR, "", "layers.%s" % layer_name, "tile 层必须是二维数组"))
            continue
        var row_count = grid.size()
        var col_count := -1
        for row_idx in range(grid.size()):
            var row = grid[row_idx]
            if typeof(row) != TYPE_ARRAY:
                issues.append(_issue(SEVERITY_ERROR, "", "layers.%s[%d]" % [layer_name, row_idx], "行必须是数组"))
                continue
            if col_count < 0:
                col_count = row.size()
            elif row.size() != col_count:
                issues.append(_issue(SEVERITY_WARNING, "", "layers.%s[%d]" % [layer_name, row_idx], "行宽度不一致"))
```

- [ ] **Step 3: Commit**

```bash
git add addons/map_preview/content_reference_validator.gd
git commit -m "✨ feat(editor): 校验扩展 — 底图/tileset/decoration/particle 路径和类型检查"
```

---

### Task 14: jiangnan_town 完整数据配置

**Files:**
- Create: `data/map_layouts/jiangnan_town.json`
- Create: `scenes/jiangnan_town.tscn`

- [ ] **Step 1: 创建 `jiangnan_town.tscn`**

在 Godot 编辑器中创建新场景 → Node2D 根节点 → 保存为 `scenes/jiangnan_town.tscn`。
挂载脚本：创建一个 `scripts/scenes/jiangnan_town_screen.gd` 继承 `map_screen_base.gd`：

```gdscript
extends "res://scripts/scenes/map_screen_base.gd"

func _ready() -> void:
    configure_map("jiangnan_town", Vector2(200, 960), Color("#7f8f6a"), Color("#476f3f"))
    super._ready()
```

- [ ] **Step 2: 创建 `data/map_layouts/jiangnan_town.json`**

完整的江南小镇布局配置，包含：
- mode: "big_image"，底图指向程序生成的 background.png
- camera: zoom=1.0, bounds=2560×1920
- obstacles: 河流（多边形）、围墙（矩形）、建筑碰撞
- objects: NPC 村民、NPC 掌柜、两个出口、一个拾取物
- decorations: 大树×3、灌木×5、石头×4、路牌×2、灯笼×3、建筑×3（客栈+药铺+民居）
- particles: 云朵 + 薄雾 + 水面动画

（完整 JSON 约 150 行，按规格书中的格式写入）

- [ ] **Step 3: 在 `data/maps.json` 中追加 jiangnan_town 条目**

```json
{
  "id": "jiangnan_town",
  "name": "江南小镇",
  "scene_path": "res://scenes/jiangnan_town.tscn",
  "spawn_position": {"x": 200, "y": 960},
  "spawn_points": {
    "start": {"x": 200, "y": 960}
  },
  "objects": [
    {"id": "npc_villager_wang", "type": "npc", "name": "王村民", "actor_id": "villager_01", "position": {"x": 500, "y": 400}, "radius": 72, "dialogue_id": ""},
    {"id": "npc_merchant_li", "type": "npc", "name": "李掌柜", "actor_id": "merchant_01", "position": {"x": 1000, "y": 600}, "radius": 72, "dialogue_id": ""},
    {"id": "exit_to_world", "type": "exit", "name": "世界大地图", "position": {"x": 200, "y": 960}, "radius": 72, "target_map_id": "world", "target_spawn_id": "from_village"},
    {"id": "exit_to_wilderness", "type": "exit", "name": "野外山道", "position": {"x": 2400, "y": 960}, "radius": 72, "target_map_id": "wilderness_trail", "target_spawn_id": "from_town"},
    {"id": "pickup_herb_town", "type": "pickup", "name": "遗落的药草", "position": {"x": 1800, "y": 700}, "radius": 56, "reward_items": ["herb_small"], "reward_item_amounts": {"herb_small": 1}, "reward_coins": 0}
  ]
}
```

- [ ] **Step 4: 运行验证**

在 Godot 中打开 `jiangnan_town.tscn`，运行游戏。确认底图加载、角色移动、NPC 精灵显示、碰撞阻挡、粒子效果。

- [ ] **Step 5: Commit**

```bash
git add scenes/jiangnan_town.tscn scripts/scenes/jiangnan_town_screen.gd data/map_layouts/jiangnan_town.json data/maps.json
git commit -m "✨ feat(map): 江南小镇测试场景完整配置

大图底图模式，含建筑/树木/装饰物/NPC/出口/拾取物/粒子"
```

---

### Task 15: wilderness_trail 完整数据配置

**Files:**
- Create: `data/map_layouts/wilderness_trail.json`
- Create: `scenes/wilderness_trail.tscn`

- [ ] **Step 1: 创建 `wilderness_trail.tscn` + 场景脚本**

`scripts/scenes/wilderness_trail_screen.gd`:

```gdscript
extends "res://scripts/scenes/map_screen_base.gd"

func _ready() -> void:
    configure_map("wilderness_trail", Vector2(160, 960), Color("#6f8f55"), Color("#476f3f"))
    super._ready()
```

- [ ] **Step 2: 创建 `data/map_layouts/wilderness_trail.json`**

完整的 TileMap 野外山道配置，包含：
- mode: "tile_map"
- tileset: 指向 Kenney 配置
- layers: ground (20×15 grid 草/水/路/山/桥/阶)、decoration (树/石)、overlay (树冠)
- obstacles: 地图边界、特殊碰撞
- objects: NPC 书生、NPC 山贼、两个出口、一个拾取物
- decorations: 野外风格的树、石头、路牌
- particles: 落叶 + 薄雾

- [ ] **Step 3: 在 `data/maps.json` 中追加 wilderness_trail 条目**

```json
{
  "id": "wilderness_trail",
  "name": "野外山道",
  "scene_path": "res://scenes/wilderness_trail.tscn",
  "spawn_position": {"x": 160, "y": 960},
  "spawn_points": {
    "from_town": {"x": 160, "y": 960},
    "from_mountain": {"x": 2400, "y": 960}
  },
  "objects": [
    {"id": "npc_scholar_zhang", "type": "npc", "name": "张书生", "actor_id": "scholar_01", "position": {"x": 800, "y": 600}, "radius": 72, "dialogue_id": ""},
    {"id": "npc_bandit_scout", "type": "npc", "name": "山寨探子", "actor_id": "villager_01", "position": {"x": 1600, "y": 800}, "radius": 72, "dialogue_id": ""},
    {"id": "exit_to_town", "type": "exit", "name": "江南小镇", "position": {"x": 80, "y": 960}, "radius": 72, "target_map_id": "jiangnan_town", "target_spawn_id": "start"},
    {"id": "exit_to_mountain", "type": "exit", "name": "山道", "position": {"x": 2480, "y": 960}, "radius": 72, "target_map_id": "mountain_pass", "target_spawn_id": "return_from_village"},
    {"id": "pickup_coins_trail", "type": "pickup", "name": "行人遗落的钱袋", "position": {"x": 1200, "y": 500}, "radius": 56, "reward_coins": 50}
  ]
}
```

- [ ] **Step 4: 运行验证**

打开 `wilderness_trail.tscn`，确认 TileMap 正确渲染、角色在 tile 地图上移动、地形阻挡正确。

- [ ] **Step 5: Commit**

```bash
git add scenes/wilderness_trail.tscn scripts/scenes/wilderness_trail_screen.gd data/map_layouts/wilderness_trail.json data/maps.json
git commit -m "✨ feat(map): 野外山道 TileMap 测试场景完整配置

Kenney tile 分层渲染，含地面/装饰/遮挡三层和地形属性"
```

---

### Task 16: NPC actor 配置 + 集成测试

**Files:**
- Modify: `data/actors.json`

**目标：** 为测试场景中的 3 个 NPC（王村民、李掌柜、张书生）补充 actor 配置，使其包含 `character_id` 字段。

- [ ] **Step 1: 追加 actor 条目到 `data/actors.json`**

```json
{"id": "villager_01", "name": "村民", "character_id": "villager", "sprite_set": "res://assets/characters/villager/", "directions": ["down_left","down_right","up_left","up_right"], "animations": ["walk"], "collision_size": {"w": 16, "h": 24}, "interaction_radius": 48},
{"id": "merchant_01", "name": "掌柜", "character_id": "merchant", "sprite_set": "res://assets/characters/merchant/", "directions": ["down_left","down_right","up_left","up_right"], "animations": ["walk"], "collision_size": {"w": 16, "h": 24}, "interaction_radius": 48},
{"id": "scholar_01", "name": "书生", "character_id": "scholar", "sprite_set": "res://assets/characters/scholar/", "directions": ["down_left","down_right","up_left","up_right"], "animations": ["walk"], "collision_size": {"w": 16, "h": 24}, "interaction_radius": 48}
```

- [ ] **Step 2: 集成测试 — 在两个新场景间切换**

从 foot_village 出发，确认可以：
1. 通过 village_gate → world → 地标进入 jiangnan_town (需在 world_map_config 中加地标)
2. jiangnan_town → wilderness_trail → mountain_pass → foot_village 形成闭环

- [ ] **Step 3: 用 F3 验证调试显示**

在 jiangnan_town 和 wilderness_trail 中按 F3，确认碰撞区（红色）、交互区（蓝色）、传送区（黄色）均正确显示。

- [ ] **Step 4: Commit**

```bash
git add data/actors.json
git commit -m "✨ feat(npc): 追加 3 个 NPC actor 配置 + character_id 绑定

villager_01/merchant_01/scholar_01 指向对应的角色素材目录"
```

---

### Task 17: 端到端验证 + 收尾

**目标：** 完整走一遍从编辑器预览 → 运行时加载 → 两个场景互通的流程，修复发现的问题。

- [ ] **Step 1: 编辑器预览验证**

打开 Godot 编辑器，分别打开 `jiangnan_town.tscn` 和 `wilderness_trail.tscn`，确认 map_preview 面板正确显示底图/tile 预览、对象列表、校验结果。

- [ ] **Step 2: 运行时全流程验证**

```
boot → main_menu → foot_village → world → jiangnan_town → wilderness_trail → mountain_pass
```

确认：底图渲染正确、y-sort 遮挡生效、碰撞阻挡正确、NPC 精灵动画正常、F3 调试可用、粒子效果可见。

- [ ] **Step 3: 向后兼容验证**

确认 foot_village、mountain_pass、road_outskirts、world 四个现有场景无任何回归。

- [ ] **Step 4: Commit 修复**

如有任何问题，修复后提交。

- [ ] **Step 5: 最终 Commit**

```bash
git add -A
git commit -m "✅ test(map): 双场景端到端验证通过 + 向后兼容确认

jiangnan_town ↔ wilderness_trail ↔ 现有 4 场景互通，
大图底图 + TileMap 双模式均正常工作"
```

---

## 实施建议

1. **Task 1-3 可并行开工**（起点层无依赖），推荐顺序是先做 Task 1（底图加载）和 Task 4（WorldLayer），因为它们为后续所有视觉层提供基础结构
2. **Task 5（程序底图）依赖 Task 1+4**，做完后可以立刻在编辑器中看到大图效果
3. **Task 7（NPC 素材化）** 做完后所有场景的 NPC 视觉立即改善，反馈感最强
4. **编辑器适配任务（Task 12-13）** 可在运行时管线稳定后再做，不阻塞玩法验证
5. **Task 14-16** 是配置数据填充，可以边写代码边同步完成，不必等到最后
