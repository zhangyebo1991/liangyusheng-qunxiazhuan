extends CanvasLayer

# 全屏大地图 UI 场景 - 终极艺术重构版 (稳定对齐版)
# 目标：还原画轴质感，解决坐标偏移，提升审美上限

const UiTheme = preload("res://scripts/core/ui_theme.gd")
const NavigationSystemScript = preload("res://scripts/systems/world_navigation_system.gd")

signal close_requested

var nav_system = NavigationSystemScript.new()
var world_config: Dictionary = {}
var player_node = null

# 布局常量
var map_scale: float = 0.2
var map_offset: Vector2 = Vector2.ZERO

# UI 节点
var map_container: Control
var scroll_body: Panel
var map_texture_rect: TextureRect
var ink_layer: Node2D
var landmarks_node: Control
var player_marker: Control

func _ready() -> void:
	_load_world_config()
	_setup_ui()
	_initialize_navigation()
	_draw_world()
	_play_open_animation()

func setup(player) -> void:
	player_node = player

func _load_world_config() -> void:
	var file = FileAccess.open("res://data/world_map_config.json", FileAccess.READ)
	if file:
		world_config = JSON.parse_string(file.get_as_text())
	else:
		push_error("无法加载世界地图配置")

func _setup_ui() -> void:
	# 根容器
	map_container = Control.new()
	map_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(map_container)
	
	# 遮罩层 (深黑)
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 1.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_container.add_child(overlay)
	
	# --- 地图图片容器 (占满全屏) ---
	map_texture_rect = TextureRect.new()
	map_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_container.add_child(map_texture_rect)

	# --- 顶部大标题 (在地图之后添加，确保在顶层) ---
	var title_container = Control.new()
	title_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_container.offset_top = 5 # <-- 修改这里调整标题垂直位置
	title_container.offset_left = -230
	map_container.add_child(title_container)
	
	var title_label = Label.new()
	title_label.text = "江 湖 地 图"
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color("#f4ebd0"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_label.add_theme_constant_override("shadow_outline_size", 6)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title_container.add_child(title_label)
	
	var map_path = "res://assets/world_map_bg.png"
	var map_tex = null
	if FileAccess.file_exists(map_path):
		if ResourceLoader.exists(map_path, "Texture2D"):
			map_tex = load(map_path)
		if not map_tex:
			var img = Image.load_from_file(ProjectSettings.globalize_path(map_path))
			if img:
				img.convert(Image.FORMAT_RGBA8)
				map_tex = ImageTexture.create_from_image(img)
	
	if map_tex:
		map_texture_rect.texture = map_tex
	
	# 初始化缩放与偏移
	_calculate_scaling()
	
	# 内容层
	ink_layer = Node2D.new()
	map_texture_rect.add_child(ink_layer)
	
	landmarks_node = Control.new()
	landmarks_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_texture_rect.add_child(landmarks_node)
	
	# 底部提示
	var hint = Label.new()
	hint.text = "【 鼠标点击寻路 · WASD 中断移动 · M/ESC 关闭地图 】"
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_bottom = -20
	hint.add_theme_color_override("font_color", Color("#d7ccc8"))
	map_container.add_child(hint)

func _calculate_scaling() -> void:
	var world_size = Vector2(4000, 3000)
	var view_size = get_viewport().get_visible_rect().size
	
	# 现在占满全屏，无需 Margin
	var s_x = view_size.x / world_size.x
	var s_y = view_size.y / world_size.y
	map_scale = min(s_x, s_y)
	
	map_offset = (view_size / 2.0) - (world_size / 2.0 * map_scale)

func _initialize_navigation() -> void:
	nav_system.setup_grid(Vector2(4000, 3000), 40)

func _draw_world() -> void:
	# 1. 区域边界
	for region in world_config.get("regions", []):
		var poly = Polygon2D.new()
		var points = PackedVector2Array()
		for p in region.get("boundary", []):
			points.append(_world_to_screen(Vector2(p[0], p[1])))
		poly.polygon = points
		var c = Color(region.get("color", "#000000"))
		c.a = 0.06
		poly.color = c
		ink_layer.add_child(poly)

	# 2. 地标
	for l in world_config.get("landmarks", []):
		var pos = l.get("position", {"x":0, "y":0})
		var screen_pos = _world_to_screen(Vector2(pos.x, pos.y))
		
		var container = Control.new()
		container.position = screen_pos
		landmarks_node.add_child(container)
		
		var dot = ColorRect.new()
		dot.size = Vector2(6, 6)
		dot.position = Vector2(-3, -3)
		dot.color = Color("#3e2723")
		container.add_child(dot)
		
		var btn = Button.new()
		btn.text = l.get("name", "")
		btn.flat = true
		btn.add_theme_color_override("font_color", Color("#3e2723"))
		btn.add_theme_font_size_override("font_size", 16)
		btn.position = Vector2(8, -12)
		btn.pressed.connect(_on_landmark_clicked.bind(Vector2(pos.x, pos.y)))
		container.add_child(btn)
	
	_draw_player_marker()

func _draw_player_marker() -> void:
	if player_node == null: return
	var screen_pos = _world_to_screen(player_node.global_position)
	player_marker = Control.new()
	player_marker.position = screen_pos
	landmarks_node.add_child(player_marker)
	
	var pulse = Control.new()
	pulse.script = GDScript.new()
	pulse.set_script(_get_pulse_script())
	player_marker.add_child(pulse)
	
	var icon = ColorRect.new()
	icon.size = Vector2(12, 12)
	icon.position = Vector2(-6, -6)
	icon.color = Color("#ff1744")
	player_marker.add_child(icon)
	
	var label = Label.new()
	label.text = "少 侠"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#ff1744"))
	label.position = Vector2(-15, -28)
	player_marker.add_child(label)

func _get_pulse_script() -> GDScript:
	var s = GDScript.new()
	s.source_code = "extends Control\nvar t=0.0\nfunc _process(d):\n\tt+=d*3.0\n\tqueue_redraw()\nfunc _draw():\n\tvar s=(sin(t)+1.0)/2.0\n\tdraw_circle(Vector2.ZERO,10.0+s*15.0,Color(1,0,0,(1.0-s)*0.6))"
	s.reload()
	return s

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var global_v = world_pos * map_scale + map_offset
	return map_texture_rect.make_canvas_position_local(global_v)

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var global_v = map_texture_rect.get_screen_transform() * screen_pos
	return (global_v - map_offset) / map_scale

func _on_landmark_clicked(world_pos: Vector2) -> void:
	_start_auto_move_to(world_pos)

func _start_auto_move_to(world_pos: Vector2) -> void:
	if player_node:
		var path = nav_system.get_path_to_point(player_node.global_position, world_pos)
		if not path.is_empty():
			player_node.start_auto_move(path)
			close_requested.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos = _screen_to_world(event.position)
		_create_ink_ripple(event.position)
		_start_auto_move_to(world_pos)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("map") or event.is_action_pressed("cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()

func _create_ink_ripple(pos: Vector2) -> void:
	var ripple = Node2D.new()
	ripple.position = map_texture_rect.make_canvas_position_local(pos)
	var s = GDScript.new()
	s.source_code = "extends Node2D\nvar r=0.0\nvar a=0.8\nfunc _process(d):\n\tr+=150*d\n\ta-=1.8*d\n\tqueue_redraw()\n\tif a<=0:queue_free()\nfunc _draw():\n\tdraw_circle(Vector2.ZERO,r,Color(0,0,0,a*0.3))\n\tdraw_arc(Vector2.ZERO,r,0,TAU,32,Color(0,0,0,a),1.5)"
	s.reload()
	ripple.set_script(s)
	ink_layer.add_child(ripple)

func _play_open_animation() -> void:
	map_container.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(map_container, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	
	# 对整个地图纹理进行缩放进入动画
	map_texture_rect.scale = Vector2(0.95, 0.95)
	map_texture_rect.pivot_offset = map_texture_rect.size / 2.0
	var tween_map = create_tween()
	tween_map.tween_property(map_texture_rect, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
