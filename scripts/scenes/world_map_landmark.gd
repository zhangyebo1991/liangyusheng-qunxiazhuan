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
