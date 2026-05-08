extends Node

func change_scene(path: String) -> bool:
	var error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("无法切换场景：%s，错误码：%d" % [path, error])
		return false
	return true
