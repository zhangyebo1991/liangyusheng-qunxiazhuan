extends RefCounted

func add_exp(party, actor_id: String, amount: int, repository) -> Dictionary:
	if party == null or repository == null or actor_id.is_empty() or amount <= 0:
		return {"success": false, "message": "经验奖励参数无效。"}
	if not party.has_method("has_member") or not party.has_member(actor_id):
		return {"success": false, "message": "队伍中不存在成员：%s" % actor_id}
	var actor = repository.get_actor(actor_id) if repository.has_method("get_actor") else {}
	if typeof(actor) != TYPE_DICTIONARY or actor.is_empty():
		return {"success": false, "message": "角色不存在：%s" % actor_id}

	var status = party.get_member_status(actor_id)
	var old_level = max(1, int(status.get("level", 1)))
	var old_total = max(0, int(status.get("total_exp", 0)))
	var total_exp = old_total + amount
	var new_level = _level_for_total_exp(actor, total_exp)
	var exp_in_level = _exp_in_level(actor, new_level, total_exp)
	var leveled_up = new_level > old_level
	var max_stats = _max_stats_for_level(actor, new_level)
	var hp = int(status.get("hp", max_stats.get("max_hp", 1)))
	var mp = int(status.get("mp", max_stats.get("max_mp", 0)))
	if leveled_up:
		hp = int(max_stats.get("max_hp", hp))
		mp = int(max_stats.get("max_mp", mp))
	else:
		hp = clamp(hp, 0, int(max_stats.get("max_hp", hp)))
		mp = clamp(mp, 0, int(max_stats.get("max_mp", mp)))

	party.set_member_status(actor_id, {
		"level": new_level,
		"exp": exp_in_level,
		"total_exp": total_exp,
		"hp": hp,
		"mp": mp,
	})
	return {
		"success": true,
		"actor_id": actor_id,
		"exp_gained": amount,
		"old_level": old_level,
		"new_level": new_level,
		"leveled_up": leveled_up,
		"exp": exp_in_level,
		"total_exp": total_exp,
		"max_hp": int(max_stats.get("max_hp", 1)),
		"max_mp": int(max_stats.get("max_mp", 0)),
	}

func add_party_exp(party, amount: int, repository) -> Dictionary:
	if party == null or amount <= 0:
		return {"success": false, "members": [], "message": "全队经验参数无效。"}
	var members: Array = []
	for actor_id in party.members:
		var member_result = add_exp(party, str(actor_id), amount, repository)
		if bool(member_result.get("success", false)):
			members.append(member_result)
	return {"success": not members.is_empty(), "members": members}

func get_growth_bonus(actor: Dictionary, level: int) -> Dictionary:
	var result: Dictionary = {}
	var growth = actor.get("growth", {})
	if typeof(growth) != TYPE_DICTIONARY:
		return result
	var per_level = growth.get("per_level", {})
	if typeof(per_level) != TYPE_DICTIONARY:
		return result
	var steps = max(0, level - 1)
	for key in per_level.keys():
		result[str(key)] = int(per_level[key]) * steps
	return result

func next_level_required_exp(actor: Dictionary, level: int) -> int:
	var curve = _exp_curve(actor)
	if level < curve.size():
		return int(curve[level])
	return -1

func _level_for_total_exp(actor: Dictionary, total_exp: int) -> int:
	var curve = _exp_curve(actor)
	var level := 1
	for index in range(curve.size()):
		if total_exp >= int(curve[index]):
			level = index + 1
	return level

func _exp_in_level(actor: Dictionary, level: int, total_exp: int) -> int:
	var curve = _exp_curve(actor)
	var current_index = clamp(level - 1, 0, curve.size() - 1)
	return max(0, total_exp - int(curve[current_index]))

func _max_stats_for_level(actor: Dictionary, level: int) -> Dictionary:
	var bonus = get_growth_bonus(actor, level)
	return {
		"max_hp": max(1, int(actor.get("max_hp", actor.get("hp", 1))) + int(bonus.get("max_hp", 0))),
		"max_mp": max(0, int(actor.get("max_mp", 0)) + int(bonus.get("max_mp", 0))),
	}

func _exp_curve(actor: Dictionary) -> Array:
	var growth = actor.get("growth", {})
	if typeof(growth) != TYPE_DICTIONARY:
		return [0]
	var curve = growth.get("exp_curve", [0])
	if typeof(curve) != TYPE_ARRAY or curve.is_empty():
		return [0]
	return curve