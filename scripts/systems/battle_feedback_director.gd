extends RefCounted

var _queue: Array = []

func enqueue(event: Dictionary) -> void:
	var event_type := str(event.get("type", ""))
	if event_type == "hit_start":
		_queue.append({"cmd": "hitstop", "ms": 60})
		return
	if event_type == "hp_changed":
		var unit_id := str(event.get("unit_id", "")).strip_edges()
		if unit_id == "":
			return
		var delta := int(event.get("delta", 0))
		_queue.append({"cmd": "flash_unit", "unit_id": unit_id})
		_queue.append({"cmd": "pop_text", "unit_id": unit_id, "delta": delta})

func consume_commands() -> Array:
	var output := _queue.duplicate(true)
	_queue.clear()
	return output