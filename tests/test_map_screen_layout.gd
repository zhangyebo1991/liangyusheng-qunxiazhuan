extends RefCounted

const MapScreenBaseScript = preload("res://scripts/scenes/map_screen_base.gd")

func run(assertions) -> void:
	_test_base_creates_layout_background_and_obstacles(assertions)
	_test_base_creates_multiple_layout_obstacles(assertions)

func _test_base_creates_layout_background_and_obstacles(assertions) -> void:
	var screen = MapScreenBaseScript.new()
	screen.map_data = {
		"layout": {
			"size": {"x": 320, "y": 180},
			"background": {"mode": "color", "color": "#123456"},
			"obstacles": [
				{"id": "test_wall", "shape": "rect", "rect": {"x": 10, "y": 20, "w": 30, "h": 40}}
			]
		}
	}
	screen._create_terrain()
	var background = screen.get_node_or_null("Background")
	assertions.assert_true(background is ColorRect, "布局地形应创建 Background 节点")
	assertions.assert_eq(background.size, Vector2(320, 180), "背景尺寸应来自布局")
	assertions.assert_eq(background.color.to_html(false), Color("#123456").to_html(false), "背景颜色应来自布局")
	assertions.assert_eq(_count_static_bodies(screen), 1, "布局地形应创建一个障碍碰撞体")
	screen.free()

func _test_base_creates_multiple_layout_obstacles(assertions) -> void:
	var screen = MapScreenBaseScript.new()
	screen.map_data = _layout_with_obstacles("#6f8f55", 3)
	screen._create_terrain()
	assertions.assert_eq(_count_static_bodies(screen), 3, "通用地图场景应使用布局障碍数量")
	screen.free()

func _layout_with_obstacles(color: String, count: int) -> Dictionary:
	var obstacles := []
	for index in range(count):
		obstacles.append({"id": "obstacle_%d" % index, "shape": "rect", "rect": {"x": 10 + index * 20, "y": 20, "w": 12, "h": 14}})
	return {
		"layout": {
			"size": {"x": 1280, "y": 720},
			"background": {"mode": "color", "color": color},
			"obstacles": obstacles
		}
	}

func _count_static_bodies(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is StaticBody2D:
			count += 1
	return count
