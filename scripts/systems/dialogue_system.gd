extends RefCounted

var repository: Node = null

func set_repository(next_repository: Node) -> void:
	repository = next_repository

func get_title(dialogue_id: String) -> String:
	var dialogue = _get_dialogue(dialogue_id)
	return str(dialogue.get("title", ""))

func get_lines(dialogue_id: String) -> Array:
	var dialogue = _get_dialogue(dialogue_id)
	return dialogue.get("lines", [])

func _get_dialogue(dialogue_id: String) -> Dictionary:
	if repository == null or dialogue_id.is_empty():
		return {}
	if repository.has_method("get_dialogue"):
		return repository.get_dialogue(dialogue_id)
	return {}
