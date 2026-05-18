extends RefCounted

func get_level(use_count: int, thresholds: Array) -> int:
	var level := 0
	for t in thresholds:
		if use_count >= int(t):
			level += 1
	return level

func get_bonus(use_count: int, thresholds: Array) -> int:
	return get_level(use_count, thresholds) * 2

func add_use(map: Dictionary, martial_id: String) -> void:
	if martial_id.is_empty():
		return
	map[martial_id] = int(map.get(martial_id, 0)) + 1
