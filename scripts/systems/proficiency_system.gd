extends RefCounted

var _proficiency_points: int = 0

func add_proficiency_points(amount: int) -> void:
	_proficiency_points += amount

func spend_proficiency_points(amount: int) -> bool:
	if _proficiency_points >= amount:
		_proficiency_points -= amount
		return true
	return false

func get_proficiency_points() -> int:
	return _proficiency_points

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
