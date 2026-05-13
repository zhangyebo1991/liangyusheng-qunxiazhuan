extends RefCounted

const HITSTOP_MAX_PER_EVENT_MS := 60
const HITSTOP_FRAME_BUDGET_MS := 120

var _queue: Array = []
var _remaining_hitstop_budget_ms: int = HITSTOP_FRAME_BUDGET_MS

func enqueue(event: Dictionary) -> void:
	var event_type := str(event.get("type", ""))
	if event_type == "hit_start":
		var clamped_ms: int = mini(HITSTOP_MAX_PER_EVENT_MS, _remaining_hitstop_budget_ms)
		if clamped_ms <= 0:
			return
		_queue.append({"cmd": "hitstop", "ms": clamped_ms})
		_remaining_hitstop_budget_ms -= clamped_ms
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
	_remaining_hitstop_budget_ms = HITSTOP_FRAME_BUDGET_MS
	return output