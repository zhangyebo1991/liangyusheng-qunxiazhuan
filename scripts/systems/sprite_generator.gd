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
