extends RefCounted

const MAX_TRACKED_QUESTS := 3
const STATUS_COMPLETED := "completed"

func add_rumor(journal_state, rumor_data: Variant, context: Dictionary = {}) -> Dictionary:
	if journal_state == null:
		return _failure("江湖记事状态缺失。")
	if typeof(rumor_data) != TYPE_DICTIONARY:
		return _failure("传闻格式错误。")
	var record = _normalize_rumor_record(rumor_data, context)
	var rumor_id = str(record.get("id", ""))
	if rumor_id.is_empty():
		return _failure("传闻编号缺失。")
	if str(record.get("text", "")).is_empty():
		return _failure("传闻内容缺失。")
	if journal_state.triggered_rumors.has(rumor_id):
		return _success("传闻已归入已触发列表。", {"duplicate": true, "rumor_id": rumor_id})
	if journal_state.active_rumors.has(rumor_id):
		return _success("传闻已记录。", {"duplicate": true, "rumor_id": rumor_id})
	journal_state.active_rumors[rumor_id] = record
	journal_state.normalize()
	return _success("传闻已记入江湖记事。", {"rumor_id": rumor_id})

func trigger_rumor(journal_state, rumor_id: String) -> Dictionary:
	if journal_state == null:
		return _failure("江湖记事状态缺失。")
	var normalized_id = str(rumor_id)
	if normalized_id.is_empty():
		return _failure("传闻编号缺失。")
	if journal_state.triggered_rumors.has(normalized_id):
		return _success("传闻已归入已触发列表。", {"duplicate": true, "rumor_id": normalized_id})
	if not journal_state.active_rumors.has(normalized_id):
		return _failure("传闻尚未记录：%s" % normalized_id)
	journal_state.triggered_rumors[normalized_id] = journal_state.active_rumors[normalized_id].duplicate(true)
	journal_state.active_rumors.erase(normalized_id)
	journal_state.normalize()
	return _success("传闻已移入已触发列表。", {"rumor_id": normalized_id})

func mark_rumors_triggered_for_quest(journal_state, quest_id: String) -> Dictionary:
	if journal_state == null:
		return _failure("江湖记事状态缺失。")
	var normalized_quest_id = str(quest_id)
	if normalized_quest_id.is_empty():
		return _failure("任务编号缺失。")
	var moved: Array[String] = []
	for rumor_id in journal_state.active_rumors.keys():
		var record = journal_state.active_rumors[rumor_id]
		if str(record.get("related_quest_id", "")) != normalized_quest_id:
			continue
		moved.append(str(rumor_id))
	for rumor_id in moved:
		journal_state.triggered_rumors[rumor_id] = journal_state.active_rumors[rumor_id].duplicate(true)
		journal_state.active_rumors.erase(rumor_id)
	journal_state.normalize()
	if moved.is_empty():
		return _success("没有相关传闻需要归档。", {"moved": moved})
	return _success("相关传闻已移入已触发列表。", {"moved": moved})

func toggle_tracked_quest(journal_state, quest_id: String) -> Dictionary:
	if journal_state == null:
		return _failure("江湖记事状态缺失。")
	var normalized_id = str(quest_id)
	if normalized_id.is_empty():
		return _failure("任务编号缺失。")
	journal_state.normalize()
	if journal_state.tracked_quest_ids.has(normalized_id):
		journal_state.tracked_quest_ids.erase(normalized_id)
		return _success("已取消追踪任务。", {"quest_id": normalized_id, "tracked": false})
	if journal_state.tracked_quest_ids.size() >= MAX_TRACKED_QUESTS:
		return _failure("最多只能追踪 3 个任务。")
	journal_state.tracked_quest_ids.append(normalized_id)
	return _success("已追踪任务。", {"quest_id": normalized_id, "tracked": true})

func is_quest_tracked(journal_state, quest_id: String) -> bool:
	if journal_state == null:
		return false
	return journal_state.tracked_quest_ids.has(str(quest_id))

func prune_completed_tracked_quests(journal_state, game_state) -> Array:
	var removed: Array = []
	if journal_state == null:
		return removed
	for raw_quest_id in journal_state.tracked_quest_ids.duplicate():
		var quest_id = str(raw_quest_id)
		if _get_quest_status(game_state, quest_id) != STATUS_COMPLETED:
			continue
		journal_state.tracked_quest_ids.erase(quest_id)
		removed.append(quest_id)
	journal_state.normalize()
	return removed

func build_task_entries(game_state, repository) -> Array:
	var quest_system = _get_object_property(game_state, "quest_system")
	var journal_state = _get_object_property(game_state, "journal_state")
	var quest_ids: Array[String] = []
	if quest_system != null:
		for raw_quest_id in quest_system.quest_status.keys():
			var quest_id = str(raw_quest_id)
			if not quest_id.is_empty() and not quest_ids.has(quest_id):
				quest_ids.append(quest_id)
	if journal_state != null:
		for raw_quest_id in journal_state.tracked_quest_ids:
			var quest_id = str(raw_quest_id)
			if not quest_id.is_empty() and not quest_ids.has(quest_id):
				quest_ids.append(quest_id)
	var result: Array = []
	for quest_id in quest_ids:
		if _get_quest_status(game_state, quest_id) == STATUS_COMPLETED:
			continue
		result.append(_build_task_entry(game_state, repository, quest_id))
	return result

func build_tracked_task_entries(game_state, repository) -> Array:
	var journal_state = _get_object_property(game_state, "journal_state")
	var result: Array = []
	if journal_state == null:
		return result
	for raw_quest_id in journal_state.tracked_quest_ids:
		var quest_id = str(raw_quest_id)
		if _get_quest_status(game_state, quest_id) == STATUS_COMPLETED:
			continue
		result.append(_build_task_entry(game_state, repository, quest_id))
	return result

func build_rumor_entries(journal_state) -> Dictionary:
	if journal_state == null:
		return {"active": [], "triggered": []}
	journal_state.normalize()
	return {
		"active": _rumor_values(journal_state.active_rumors),
		"triggered": _rumor_values(journal_state.triggered_rumors),
	}

func _build_task_entry(game_state, repository, quest_id: String) -> Dictionary:
	var journal_state = _get_object_property(game_state, "journal_state")
	var quest = repository.get_quest(quest_id) if repository != null and repository.has_method("get_quest") else {}
	var status = _get_quest_status(game_state, quest_id)
	return {
		"id": quest_id,
		"title": str(quest.get("title", quest_id)),
		"description": str(quest.get("description", "")),
		"status": status,
		"status_text": _status_text(status),
		"tracked": journal_state != null and journal_state.tracked_quest_ids.has(quest_id),
	}

func _status_text(status: String) -> String:
	match status:
		"active":
			return "进行中"
		"ready_to_complete":
			return "可交付"
		"completed":
			return "已完成"
		_:
			return "未开始"

func _rumor_values(source: Dictionary) -> Array:
	var result: Array = []
	for rumor_id in source.keys():
		if typeof(source[rumor_id]) == TYPE_DICTIONARY:
			result.append(source[rumor_id].duplicate(true))
	return result

func _normalize_rumor_record(rumor_data: Dictionary, context: Dictionary) -> Dictionary:
	var record: Dictionary = {
		"id": str(rumor_data.get("id", "")),
		"title": str(rumor_data.get("title", "")),
		"text": str(rumor_data.get("text", "")),
		"source": str(rumor_data.get("source", "")),
		"related_quest_id": str(rumor_data.get("related_quest_id", "")),
		"discovered_at_map_id": str(rumor_data.get("discovered_at_map_id", context.get("map_id", ""))),
	}
	if record["title"].is_empty():
		record["title"] = record["id"]
	return record

func _get_object_property(target, property_name: String) -> Variant:
	if target == null:
		return null
	return target.get(property_name)

func _get_quest_status(game_state, quest_id: String) -> String:
	var quest_system = _get_object_property(game_state, "quest_system")
	if quest_system == null or not quest_system.has_method("get_status"):
		return "not_started"
	return str(quest_system.get_status(quest_id))

func _success(message: String, extra: Dictionary = {}) -> Dictionary:
	var result = {
		"success": true,
		"message": message,
		"errors": [],
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result

func _failure(message: String) -> Dictionary:
	return {
		"success": false,
		"message": message,
		"errors": [message],
	}
