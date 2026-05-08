extends RefCounted

const STATUS_NOT_STARTED := "not_started"
const STATUS_ACTIVE := "active"
const STATUS_COMPLETED := "completed"

var quest_status: Dictionary = {}

func start_quest(quest_id: String) -> bool:
	if quest_id.is_empty():
		return false
	if get_status(quest_id) != STATUS_NOT_STARTED:
		return false
	quest_status[quest_id] = STATUS_ACTIVE
	return true

func complete_quest(quest_id: String) -> bool:
	if get_status(quest_id) != STATUS_ACTIVE:
		return false
	quest_status[quest_id] = STATUS_COMPLETED
	return true

func get_status(quest_id: String) -> String:
	return str(quest_status.get(quest_id, STATUS_NOT_STARTED))

func to_dictionary() -> Dictionary:
	return quest_status.duplicate(true)

func from_dictionary(data: Dictionary) -> void:
	quest_status = data.duplicate(true)
