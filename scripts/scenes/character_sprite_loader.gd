extends RefCounted

const CHARACTER_ROOT := "res://assets/characters"
const DEFAULT_DIRECTIONS := [
	"down_right",
	"up_right",
	"up_left",
	"down_left",
]
const DEFAULT_FRAME_COUNT := 7
const DEFAULT_FPS := 8.0

static func create_walk_frames(
	character_id: String,
	action: String = "walk",
	directions: Array = [],
	frame_count: int = DEFAULT_FRAME_COUNT,
	fps: float = DEFAULT_FPS
) -> SpriteFrames:
	var resolved_directions: Array = directions
	if resolved_directions.is_empty():
		resolved_directions = DEFAULT_DIRECTIONS.duplicate()

	var missing_paths := _collect_missing_paths(character_id, action, resolved_directions, frame_count)
	if not missing_paths.is_empty():
		for path in missing_paths:
			push_warning("缺少角色动画帧：%s" % path)
		return null

	var frames := SpriteFrames.new()
	for direction in resolved_directions:
		var animation := "%s_%s" % [action, direction]
		frames.add_animation(animation)
		frames.set_animation_speed(animation, fps)
		frames.set_animation_loop(animation, true)
		for frame_index in range(frame_count):
			var frame_path := _build_frame_path(character_id, action, str(direction), frame_index)
			var texture := _load_texture(frame_path)
			if texture == null:
				push_warning("角色动画帧无法读取：%s" % frame_path)
				return null
			frames.add_frame(animation, texture)
	return frames

static func _collect_missing_paths(
	character_id: String,
	action: String,
	directions: Array,
	frame_count: int
) -> Array[String]:
	var missing_paths: Array[String] = []
	for direction in directions:
		for frame_index in range(frame_count):
			var frame_path := _build_frame_path(character_id, action, str(direction), frame_index)
			if not FileAccess.file_exists(frame_path):
				missing_paths.append(frame_path)
	return missing_paths

static func _build_frame_path(character_id: String, action: String, direction: String, frame_index: int) -> String:
	return "%s/%s/%s/%s/%02d.png" % [CHARACTER_ROOT, character_id, action, direction, frame_index]

static func _load_texture(frame_path: String) -> Texture2D:
	if ResourceLoader.exists(frame_path, "Texture2D"):
		return load(frame_path)

	var image := Image.load_from_file(ProjectSettings.globalize_path(frame_path))
	if image == null:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(image)
