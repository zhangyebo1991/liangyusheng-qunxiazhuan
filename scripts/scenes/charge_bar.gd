extends Control

# Task 13: 顶部集气进度条。
# 单位以 dict 提供：{unit_id, team, cur_charge, is_action}
# x 偏移 = cur_charge / 1000 * bar_width；is_action=true 的单位高亮放大。

var bar_width: float = 800.0
var _units: Array = []
var _highlight: Dictionary = {}
var _x_cache: Dictionary = {}

func set_units(units: Array) -> void:
	_units = units
	_highlight.clear()
	_x_cache.clear()
	for u in units:
		var x: float = float(u.get("cur_charge", 0)) / 1000.0 * bar_width
		_x_cache[str(u.get("unit_id", ""))] = int(x)
		if bool(u.get("is_action", false)):
			_highlight[str(u.get("unit_id", ""))] = true
	queue_redraw()

func get_unit_x(uid: String) -> int:
	return int(_x_cache.get(uid, 0))

func is_highlighted(uid: String) -> bool:
	return _highlight.has(uid)

func _draw() -> void:
	# 底条
	draw_rect(Rect2(0, 16, bar_width, 4), Color(0.4, 0.4, 0.4))
	# 单位圆点：玩家蓝、敌方红，行动单位放大。
	for u in _units:
		var uid := str(u.get("unit_id", ""))
		var x := get_unit_x(uid)
		var team := int(u.get("team", 0))
		var color := Color(0.3, 0.6, 1.0) if team == 0 else Color(1.0, 0.4, 0.4)
		var radius := 12 if is_highlighted(uid) else 8
		draw_circle(Vector2(x, 18), radius, color)
