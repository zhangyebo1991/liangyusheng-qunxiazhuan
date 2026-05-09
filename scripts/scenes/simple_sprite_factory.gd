extends RefCounted

static func create_frames(base_color: Color, trim_color: Color) -> SpriteFrames:
	var frames = SpriteFrames.new()
	for animation in ["idle_down", "idle_up", "idle_left", "idle_right", "walk_down", "walk_up", "walk_left", "walk_right"]:
		frames.add_animation(animation)
		frames.set_animation_speed(animation, 4.0)
		frames.set_animation_loop(animation, animation.begins_with("walk"))

	frames.add_frame("idle_down", _make_texture(base_color, trim_color, Vector2i(0, 0)))
	frames.add_frame("idle_up", _make_texture(base_color.darkened(0.15), trim_color, Vector2i(0, 0)))
	frames.add_frame("idle_left", _make_texture(base_color, trim_color.darkened(0.2), Vector2i(-1, 0)))
	frames.add_frame("idle_right", _make_texture(base_color, trim_color.darkened(0.2), Vector2i(1, 0)))

	for animation in ["walk_down", "walk_up", "walk_left", "walk_right"]:
		frames.add_frame(animation, _make_texture(base_color, trim_color, Vector2i(-1, 1)))
		frames.add_frame(animation, _make_texture(base_color.lightened(0.08), trim_color, Vector2i(1, 1)))

	return frames

static func _make_texture(base_color: Color, trim_color: Color, offset: Vector2i) -> Texture2D:
	var image = Image.create(24, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(8, 28):
		for x in range(7, 17):
			image.set_pixel(x, y, base_color)
	for y in range(3, 10):
		for x in range(8, 16):
			image.set_pixel(x + offset.x, y, trim_color)
	for y in range(26, 31):
		image.set_pixel(8 + offset.x, y, trim_color.darkened(0.35))
		image.set_pixel(15 + offset.x, y, trim_color.darkened(0.35))
	return ImageTexture.create_from_image(image)
