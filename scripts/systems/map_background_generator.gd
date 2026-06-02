@tool
extends RefCounted

## 程序生成地图底图，包含草地 + 道路 + 水域的基本格局。
## 用于在 Godot 编辑器中运行，或通过独立 SceneTree 脚本调用。

static func generate_town_background(output_path: String, width: int, height: int) -> bool:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)

	# 基础草地（带噪声变化）
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
