extends RefCounted

func roll_loot(loot_table: Variant, rng = null) -> Dictionary:
	var result: Dictionary = {
		"rolled": false,
		"coins": 0,
		"items": [],
		"errors": [],
	}
	if typeof(loot_table) != TYPE_DICTIONARY:
		return result

	var rolls = max(0, int(loot_table.get("rolls", 0)))
	var entries = loot_table.get("entries", [])
	if rolls <= 0 or typeof(entries) != TYPE_ARRAY or entries.is_empty():
		return result

	var roller = rng
	if roller == null:
		roller = RandomNumberGenerator.new()
		roller.randomize()

	result["rolled"] = true
	for _roll_index in range(rolls):
		for raw_entry in entries:
			if typeof(raw_entry) != TYPE_DICTIONARY:
				_add_error(result, "掉落条目格式错误。")
				continue
			_apply_entry(result, raw_entry, roller)
	return result

func _apply_entry(result: Dictionary, entry: Dictionary, rng) -> void:
	var chance = float(entry.get("chance", 0.0))
	if chance <= 0.0:
		return
	if chance < 1.0 and _randf(rng) > chance:
		return

	var entry_type = str(entry.get("type", ""))
	match entry_type:
		"item":
			_apply_item_entry(result, entry)
		"coins":
			_apply_coin_entry(result, entry, rng)
		_:
			_add_error(result, "未知掉落类型：%s。" % entry_type)

func _apply_item_entry(result: Dictionary, entry: Dictionary) -> void:
	var item_id = str(entry.get("item_id", ""))
	if item_id.is_empty():
		_add_error(result, "物品掉落缺少编号。")
		return
	var items: Array = result["items"]
	items.append({
		"item_id": item_id,
		"amount": _entry_amount(entry, null),
	})

func _apply_coin_entry(result: Dictionary, entry: Dictionary, rng) -> void:
	result["coins"] = int(result.get("coins", 0)) + _entry_amount(entry, rng)

func _entry_amount(entry: Dictionary, rng) -> int:
	if entry.has("amount"):
		return max(1, int(entry.get("amount", 1)))
	var amount_min = max(1, int(entry.get("amount_min", 1)))
	var amount_max = max(1, int(entry.get("amount_max", amount_min)))
	if amount_max < amount_min:
		amount_max = amount_min
	if amount_min == amount_max:
		return amount_min
	return _randi_range(rng, amount_min, amount_max)

func _randf(rng) -> float:
	if rng != null and rng.has_method("randf"):
		return float(rng.randf())
	return randf()

func _randi_range(rng, min_value: int, max_value: int) -> int:
	if rng != null and rng.has_method("randi_range"):
		return int(rng.randi_range(min_value, max_value))
	return randi_range(min_value, max_value)

func _add_error(result: Dictionary, message: String) -> void:
	var errors: Array = result["errors"]
	errors.append(message)
