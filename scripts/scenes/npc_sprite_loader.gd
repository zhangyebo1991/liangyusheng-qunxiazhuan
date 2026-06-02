extends RefCounted

const CharacterSpriteLoader = preload("res://scripts/scenes/character_sprite_loader.gd")

static func create_npc_sprite(record: Dictionary) -> Node2D:
	var container := Node2D.new()
	var character_id := str(record.get("character_id", ""))
	var actor_id := str(record.get("actor_id", ""))

	# 尝试加载角色精灵帧
	var frames: SpriteFrames = null
	if not character_id.is_empty():
		frames = CharacterSpriteLoader.create_walk_frames(character_id, "walk")
	elif not actor_id.is_empty():
		# 从 DataRepository 查找 actor 配置
		frames = _load_actor_frames(actor_id)

	var sprite: Node2D
	if frames != null:
		var animated := AnimatedSprite2D.new()
		animated.sprite_frames = frames
		var anim_names = frames.get_animation_names()
		animated.animation = anim_names[0] if anim_names.size() > 0 else ""
		animated.play()
		if not animated.animation.is_empty():
			animated.frame = randi() % frames.get_frame_count(animated.animation)
		sprite = animated
	else:
		# 回退到程序生成精灵
		var static_sprite := Sprite2D.new()
		static_sprite.texture = _make_npc_fallback_texture(record)
		sprite = static_sprite

	container.add_child(sprite)
	return container

static func _load_actor_frames(actor_id: String) -> SpriteFrames:
	var repo = _get_repository()
	if repo == null:
		return null
	var actor = repo.get_actor(actor_id)
	if actor.is_empty():
		return null
	var character_id = str(actor.get("character_id", ""))
	if character_id.is_empty():
		return null
	return CharacterSpriteLoader.create_walk_frames(character_id, "walk")

static func _make_npc_fallback_texture(_record: Dictionary) -> Texture2D:
	var image := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var color := Color("#8d3b7a")  # NPC 默认色
	for y in range(8, 28):
		for x in range(7, 17):
			image.set_pixel(x, y, color)
	for y in range(3, 10):
		for x in range(8, 16):
			image.set_pixel(x, y, color.lightened(0.3))
	return ImageTexture.create_from_image(image)

static func _get_repository():
	var loop = Engine.get_main_loop()
	if loop == null or loop.root == null:
		return null
	if loop.root.has_node("DataRepository"):
		return loop.root.get_node("DataRepository")
	return null
