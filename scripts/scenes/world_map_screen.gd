extends "res://scripts/scenes/map_screen_base.gd"

const WorldMapLandmarkScript = preload("res://scripts/scenes/world_map_landmark.gd")
var world_config: Dictionary = {}

func _ready() -> void:
	map_id = "world"
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
	super._create_terrain()

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
