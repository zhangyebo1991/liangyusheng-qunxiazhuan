extends RefCounted

const SAVE_VERSION := 1

func serialize_state(state: Dictionary) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"state": state.duplicate(true),
	}

func deserialize_state(payload: Variant) -> Dictionary:
	var parsed = payload
	if typeof(payload) == TYPE_STRING:
		parsed = JSON.parse_string(payload)

	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if int(parsed.get("version", 0)) != SAVE_VERSION:
		return {}

	return parsed.get("state", {}).duplicate(true)

func save_to_path(path: String, state: Dictionary) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入存档：%s" % path)
		return false
	file.store_string(JSON.stringify(serialize_state(state), "\t"))
	return true

func load_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法读取存档：%s" % path)
		return {}
	return deserialize_state(file.get_as_text())
