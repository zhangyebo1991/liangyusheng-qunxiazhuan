extends RefCounted

const LOADER_PATH := "res://scripts/scenes/character_sprite_loader.gd"
const EXPECTED_DIRECTIONS := [
	"down_right",
	"up_right",
	"up_left",
	"down_left",
]

func run(assertions) -> void:
	var LoaderScript = load(LOADER_PATH)
	assertions.assert_true(LoaderScript != null, "应存在 character_sprite_loader.gd")
	if LoaderScript == null:
		return

	var frames: SpriteFrames = LoaderScript.create_walk_frames("hero_yun")
	assertions.assert_true(frames != null, "角色动画加载器应为 hero_yun 创建 SpriteFrames")
	if frames == null:
		return

	for direction in EXPECTED_DIRECTIONS:
		var animation := "walk_%s" % direction
		assertions.assert_true(frames.has_animation(animation), "应存在动画 %s" % animation)
		if frames.has_animation(animation):
			assertions.assert_eq(frames.get_frame_count(animation), 7, "%s 应有 7 帧" % animation)
			assertions.assert_true(frames.get_animation_loop(animation), "%s 应循环播放" % animation)
