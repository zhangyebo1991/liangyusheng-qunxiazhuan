extends RefCounted

const PlayerControllerScript = preload("res://scripts/scenes/player_controller.gd")

func run(assertions) -> void:
	var methods := _collect_method_names(PlayerControllerScript)
	for method_name in ["get_facing_direction", "get_walk_animation_name", "_update_facing", "_update_animation"]:
		assertions.assert_true(methods.has(method_name), "PlayerController 应含方法 %s" % method_name)

	if not methods.has("get_facing_direction") or not methods.has("get_walk_animation_name"):
		return

	_assert_direction_state(assertions)
	_assert_diagonal_animation_stop(assertions)

func _assert_direction_state(assertions) -> void:
	var player = PlayerControllerScript.new()
	assertions.assert_eq(player.get_facing_direction(), "down_right", "主角默认应面向右下")
	assertions.assert_eq(player.get_walk_animation_name(), "walk_down_right", "默认行走动画应为右下")

	player._update_facing(Vector2(0, -1))
	assertions.assert_eq(player.get_facing_direction(), "up_right", "默认右下时按上应变为右上")
	assertions.assert_eq(player.get_walk_animation_name(), "walk_up_right", "按上后行走动画应为右上")

	player._update_facing(Vector2(-1, 0))
	assertions.assert_eq(player.get_facing_direction(), "up_left", "右上后按左应变为左上")
	assertions.assert_eq(player.get_walk_animation_name(), "walk_up_left", "按左后行走动画应为左上")

	player._update_facing(Vector2(1, 1))
	assertions.assert_eq(player.get_facing_direction(), "down_right", "输入右下应回到右下")
	assertions.assert_eq(player.get_walk_animation_name(), "walk_down_right", "右下输入后行走动画应为右下")
	player.free()

func _assert_diagonal_animation_stop(assertions) -> void:
	var player = PlayerControllerScript.new()
	player.sprite = AnimatedSprite2D.new()
	player.sprite.sprite_frames = _make_test_frames()
	player._uses_diagonal_character_frames = true

	player._update_facing(Vector2(0, -1))
	player._update_animation(Vector2(0, -1))
	assertions.assert_eq(player.sprite.animation, "walk_up_right", "移动时应播放当前斜方向动画")
	assertions.assert_true(player.sprite.is_playing(), "移动时斜方向动画应播放")

	player._update_animation(Vector2.ZERO)
	assertions.assert_eq(player.sprite.animation, "walk_up_right", "静止时应保持当前斜方向动画")
	assertions.assert_eq(player.sprite.frame, 0, "静止时应停在第 0 帧")
	assertions.assert_false(player.sprite.is_playing(), "静止时斜方向动画应停止")
	player.sprite.free()
	player.free()

func _make_test_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	var texture := _make_texture()
	for direction in ["down_right", "up_right", "up_left", "down_left"]:
		var animation := "walk_%s" % direction
		frames.add_animation(animation)
		frames.set_animation_loop(animation, true)
		for _i in range(7):
			frames.add_frame(animation, texture)
	return frames

func _make_texture() -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)

func _collect_method_names(script: Script) -> Array[String]:
	var names: Array[String] = []
	for method in script.get_script_method_list():
		names.append(str(method.get("name", "")))
	return names
