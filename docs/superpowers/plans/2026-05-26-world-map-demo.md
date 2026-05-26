# 世界地图 Demo 实施计划

> **执行者说明：** 建议使用 `subagent-driven-development` 或 `executing-plans` 技能按任务逐项执行。步骤使用复选框 (`- [ ]`) 语法进行跟踪。

**目标：** 实现一个真正有世界感的大地图 Demo，包含五个区域和 13 个核心地标，支持玩家移动、摄像机缩放和地标交互。

**架构：**
- 数据驱动：地标和区域配置存储在 JSON 文件中。
- 继承扩展：基于现有的地图系统 (`map_screen_base.gd`) 进行扩展。
- 视觉分层：背景层、区域层、路线层和地标层。

**技术栈：** Godot 4.x (GDScript)

---

### 任务 1: 准备世界地图配置数据

**文件：**
- 创建：`data/world_map_config.json`

- [ ] **步骤 1: 创建配置文件并填入初始数据**

```json
{
  "regions": [
    {
      "id": "central",
      "name": "中原腹地",
      "color": "#e6d5b8",
      "boundary": [[1500, 1000], [2500, 1000], [2500, 2000], [1500, 2000]]
    },
    {
      "id": "jiangnan",
      "name": "江南/金陵",
      "color": "#b8e6cf",
      "boundary": [[2500, 2000], [3500, 2000], [3500, 3000], [2500, 3000]]
    },
    {
      "id": "north",
      "name": "北地/燕京",
      "color": "#b8cfe6",
      "boundary": [[2500, 0], [3500, 0], [3500, 1000], [2500, 1000]]
    },
    {
      "id": "yanyun",
      "name": "燕云/辽东/塞外",
      "color": "#e6cfb8",
      "boundary": [[3500, 0], [4000, 0], [4000, 1500], [3500, 1500]]
    },
    {
      "id": "western",
      "name": "西域/雪山/边疆",
      "color": "#cfb8e6",
      "boundary": [[0, 0], [1500, 0], [1500, 1500], [0, 1500]]
    }
  ],
  "landmarks": [
    {"id": "changan", "name": "长安", "type": "city", "position": {"x": 1800, "y": 1400}, "target_map_id": "changan_city"},
    {"id": "luoyang", "name": "洛阳", "type": "city", "position": {"x": 2100, "y": 1450}, "target_map_id": "luoyang_city"},
    {"id": "wudang", "name": "武当山", "type": "sect", "position": {"x": 1950, "y": 1700}, "target_map_id": "wudang_mountain"},
    {"id": "shaolin", "name": "少林寺", "type": "sect", "position": {"x": 2150, "y": 1550}, "target_map_id": "shaolin_temple"},
    {"id": "mangshan", "name": "氓山", "type": "sect", "position": {"x": 2200, "y": 1350}, "target_map_id": "mang_mountain"},
    {"id": "jindaozhai", "name": "金刀寨", "type": "fortress", "position": {"x": 2300, "y": 1650}, "target_map_id": "golden_knife_fortress"},
    {"id": "suzhou", "name": "苏州", "type": "city", "position": {"x": 2800, "y": 2300}, "target_map_id": "suzhou_city"},
    {"id": "taihu", "name": "太湖", "type": "lake", "position": {"x": 2700, "y": 2400}, "target_map_id": "tai_lake"},
    {"id": "beijing", "name": "北京/京师", "type": "city", "position": {"x": 2900, "y": 700}, "target_map_id": "beijing_city"},
    {"id": "tumubao", "name": "土木堡", "type": "fortress", "position": {"x": 2750, "y": 650}, "target_map_id": "tumu_fortress"},
    {"id": "liaodong", "name": "辽东", "type": "region", "position": {"x": 3700, "y": 500}, "target_map_id": "liaodong_front"},
    {"id": "tianshan", "name": "天山", "type": "sect", "position": {"x": 500, "y": 500}, "target_map_id": "tianshan_mountain"},
    {"id": "shedao", "name": "蛇岛", "type": "island", "position": {"x": 3800, "y": 1200}, "target_map_id": "snake_island"}
  ],
  "routes": [
    {"from": "changan", "to": "luoyang"},
    {"from": "luoyang", "to": "beijing"},
    {"from": "luoyang", "to": "suzhou"},
    {"from": "beijing", "to": "tumubao"},
    {"from": "beijing", "to": "liaodong"}
  ]
}
```

- [ ] **步骤 2: 提交更改**

```bash
git add data/world_map_config.json
git commit -m "data: 添加世界地图初始配置"
```

---

### 任务 2: 实现地标交互组件

**文件：**
- 创建：`scripts/scenes/world_map_landmark.gd`

- [ ] **步骤 1: 编写地标组件逻辑**

```gdscript
extends "res://scripts/scenes/map_interactable.gd"

func setup(next_record: Dictionary) -> void:
	super.setup(next_record)
	
	# 自定义视觉表现
	var visual = get_node_or_null("Visual")
	if visual:
		visual.queue_free()
	
	var icon = _create_icon(str(record.get("type", "")))
	icon.name = "Visual"
	add_child(icon)
	
	if label:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)

func _create_icon(type: String) -> Node2D:
	var node = Node2D.new()
	var polygon = Polygon2D.new()
	var points = PackedVector2Array()
	var color = Color.WHITE
	
	match type:
		"city":
			points = PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)])
			color = Color("#cc3333") # 红色方块
		"sect":
			points = PackedVector2Array([Vector2(0, -12), Vector2(10, 8), Vector2(-10, 8)])
			color = Color("#3366cc") # 蓝色三角
		"fortress":
			points = PackedVector2Array([Vector2(0, -10), Vector2(10, 0), Vector2(0, 10), Vector2(-10, 0)])
			color = Color("#339933") # 绿色菱形
		"island":
			points = PackedVector2Array([Vector2(-8, -4), Vector2(8, -4), Vector2(12, 4), Vector2(-12, 4)])
			color = Color("#cc9933")
		_:
			points = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
			color = Color("#888888")
			
	polygon.polygon = points
	polygon.color = color
	node.add_child(polygon)
	return node
```

- [ ] **步骤 2: 提交更改**

```bash
git add scripts/scenes/world_map_landmark.gd
git commit -m "feat: 添加世界地图地标组件"
```

---

### 任务 3: 实现世界地图主逻辑

**文件：**
- 创建：`scripts/scenes/world_map_screen.gd`

- [ ] **步骤 1: 编写世界地图屏幕逻辑**

```gdscript
extends "res://scripts/scenes/map_screen_base.gd"

const WorldMapLandmarkScript = preload("res://scripts/scenes/world_map_landmark.gd")
var world_config: Dictionary = {}

func _ready() -> void:
	_load_world_config()
	super._ready()
	_setup_camera_zoom()
	_draw_world_elements()

func _load_world_config() -> void:
	var file = FileAccess.open("res://data/world_map_config.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if typeof(json) == TYPE_DICTIONARY:
			world_config = json
	else:
		push_error("无法加载世界地图配置")

func _create_terrain() -> void:
	# 背景底色
	_add_background(Vector2(4000, 3000))
	var bg_rect = get_node("Background") if has_node("Background") else null
	if bg_rect is ColorRect:
		bg_rect.color = Color("#f4ebd0") # 古朴纸张色

func _setup_camera_zoom() -> void:
	var camera = player.get_node("Camera2D") if player and player.has_node("Camera2D") else null
	if camera:
		camera.zoom = Vector2(0.8, 0.8)
		# 可以在 process 中处理缩放输入，Demo 暂时固定

func _spawn_objects() -> void:
	# 生成世界地标
	var landmarks = world_config.get("landmarks", [])
	for data in landmarks:
		var landmark = WorldMapLandmarkScript.new()
		landmark.setup(data)
		landmark.clicked.connect(_on_interactable_clicked)
		landmark.player_entered.connect(_on_interactable_entered)
		landmark.player_exited.connect(_on_interactable_exited)
		interactables.append(landmark)
		add_child(landmark)

func _draw_world_elements() -> void:
	# 绘制区域边界和路线
	var elements_node = Node2D.new()
	elements_node.name = "WorldElements"
	add_child(elements_node)
	move_child(elements_node, 1) # 放在背景之上，地标之下

	# 绘制区域
	for region in world_config.get("regions", []):
		var poly = Polygon2D.new()
		var points = PackedVector2Array()
		for p in region.get("boundary", []):
			points.append(Vector2(p[0], p[1]))
		poly.polygon = points
		var color = Color(region.get("color", "#ffffff"))
		color.a = 0.1 # 半透明
		poly.color = color
		elements_node.add_child(poly)
		
		# 绘制边界线
		var line = Line2D.new()
		line.points = points
		line.closed = true
		line.width = 2.0
		line.default_color = color.darkened(0.3)
		elements_node.add_child(line)

	# 绘制路线
	for route in world_config.get("routes", []):
		var from_pos = _get_landmark_pos(route.get("from", ""))
		var to_pos = _get_landmark_pos(route.get("to", ""))
		if from_pos != Vector2.ZERO and to_pos != Vector2.ZERO:
			var line = Line2D.new()
			line.points = PackedVector2Array([from_pos, to_pos])
			line.width = 1.5
			line.default_color = Color(0.5, 0.5, 0.5, 0.5)
			elements_node.add_child(line)

func _get_landmark_pos(id: String) -> Vector2:
	for l in world_config.get("landmarks", []):
		if l.get("id") == id:
			var pos = l.get("position", {})
			return Vector2(pos.get("x", 0), pos.get("y", 0))
	return Vector2.ZERO

func _interact_with(interactable) -> void:
	if interactable is WorldMapLandmarkScript:
		_transition_to_exit(interactable.record)

func _read_spawn_position() -> Vector2:
	# 初始位置设在长安附近
	return Vector2(1800, 1500)
```

- [ ] **步骤 2: 提交更改**

```bash
git add scripts/scenes/world_map_screen.gd
git commit -m "feat: 实现世界地图屏幕逻辑"
```

---

### 任务 4: 创建世界地图场景

**文件：**
- 修改：`scenes/world.tscn` (覆盖原有占位符)

- [ ] **步骤 1: 编写场景文件内容**

```tscn
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/scenes/world_map_screen.gd" id="1"]

[node name="World" type="Node2D"]
script = ExtResource("1")
```

- [ ] **步骤 2: 提交更改**

```bash
git add scenes/world.tscn
git commit -m "feat: 配置世界地图场景"
```

---

### 任务 5: 验证与调试

- [ ] **步骤 1: 运行测试确保场景可加载**
由于当前环境无法直接运行 Godot UI，我们将通过检查脚本逻辑和文件完整性来验证。

- [ ] **步骤 2: 检查数据加载路径是否正确**
确保 `res://data/world_map_config.json` 路径在代码中一致。

---

**计划完成并保存至 `docs/superpowers/plans/2026-05-26-world-map-demo.md`。**

可以选择以下执行方式：

**1. 子代理驱动（推荐）** - 我为每个任务分配一个子代理，在任务之间进行审查，迭代速度快。

**2. 内联执行** - 在本会话中使用 `executing-plans` 执行任务，带检查点的批量执行。

**请问您选择哪种方式？**
