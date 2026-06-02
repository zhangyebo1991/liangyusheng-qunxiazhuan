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


## 装饰物程序纹理

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
	var img := Image.create(160, 160, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# 屋身
	for y in range(48, 160):
		for x in range(16, 144):
			img.set_pixel(x, y, Color(0.55, 0.4, 0.25))
	# 屋顶三角
	for y in range(0, 52):
		for x in range(0, 160):
			var roof_slope: float = abs(float(x - 80) / 80.0)
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
