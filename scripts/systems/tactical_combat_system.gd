extends RefCounted

const TacticalBattleStateScript = preload("res://scripts/domain/tactical_battle_state.gd")
const TacticalUnitStateScript = preload("res://scripts/domain/tactical_unit_state.gd")

var repository = null

func set_repository(next_repository) -> void:
	repository = next_repository

func create_battle(game_state, context: Dictionary, data_source = null):
	var source = data_source if data_source != null else repository
	var battle = TacticalBattleStateScript.new()
	battle.source_map_id = str(context.get("source_map_id", "mountain_pass"))
	if battle.source_map_id.is_empty():
		battle.source_map_id = "mountain_pass"
	battle.source_object_id = str(context.get("source_object_id", ""))
	battle.quest_id = str(context.get("quest_id", ""))
	battle.time_mode = str(context.get("time_mode", TacticalBattleStateScript.TIME_MODE_PAUSE_ON_ACTION))
	if battle.time_mode.is_empty():
		battle.time_mode = TacticalBattleStateScript.TIME_MODE_PAUSE_ON_ACTION

	var battlefield = context.get("battlefield", {})
	if typeof(battlefield) == TYPE_DICTIONARY:
		battle.battlefield_width = max(1, int(battlefield.get("width", 7)))
		battle.battlefield_height = max(1, int(battlefield.get("height", 5)))

	var raw_units = context.get("units", [])
	if typeof(raw_units) != TYPE_ARRAY:
		raw_units = []
	for raw_unit in raw_units:
		if typeof(raw_unit) != TYPE_DICTIONARY:
			continue
		var unit = _build_unit(raw_unit, game_state, source)
		if _is_valid_start_cell(battle, unit.cell) and not _is_cell_occupied(battle, unit.cell):
			battle.add_unit(unit)
		else:
			battle.append_log("%s站位无效。" % unit.display_name)

	if not battle.has_living_team(TacticalBattleStateScript.TEAM_PLAYER):
		battle.append_log("玩家单位缺失。")
	if not battle.has_living_team(TacticalBattleStateScript.TEAM_ENEMY):
		battle.append_log("敌方单位缺失。")
		battle.finish(true)
	return battle

func advance_charge(battle, delta: float) -> void:
	if battle == null or battle.is_finished or battle.is_action_phase:
		return
	for unit in battle.units:
		if not unit.is_alive():
			continue
		unit.charge = min(TacticalBattleStateScript.CHARGE_LIMIT, int(unit.charge + round(unit.charge_speed * delta)))
	var ready = get_ready_unit(battle)
	if ready != null:
		begin_unit_action(battle, ready.unit_id)

func get_ready_unit(battle):
	if battle == null:
		return null
	var ready_players: Array = []
	var ready_enemies: Array = []
	for unit in battle.units:
		if not unit.is_alive() or unit.charge < TacticalBattleStateScript.CHARGE_LIMIT:
			continue
		if unit.team == TacticalBattleStateScript.TEAM_PLAYER:
			ready_players.append(unit)
		else:
			ready_enemies.append(unit)
	if not ready_players.is_empty():
		return ready_players[0]
	if not ready_enemies.is_empty():
		return ready_enemies[0]
	return null

func begin_unit_action(battle, unit_id: String) -> Dictionary:
	var unit = battle.get_unit(unit_id) if battle != null else null
	if unit == null or not unit.is_alive():
		return {"success": false, "message": "行动单位不存在。"}
	battle.current_unit_id = unit_id
	battle.is_action_phase = true
	unit.charge = TacticalBattleStateScript.CHARGE_LIMIT
	battle.append_log("%s可以行动。" % unit.display_name)
	return {"success": true, "message": "%s可以行动。" % unit.display_name}

func get_movable_cells(battle, unit_id: String) -> Array:
	var unit = battle.get_unit(unit_id) if battle != null else null
	if unit == null or not unit.is_alive():
		return []
	var result: Array = []
	for q in range(battle.battlefield_width):
		for r in range(battle.battlefield_height):
			var cell = {"q": q, "r": r}
			if _cell_distance(unit.cell, cell) > unit.move_range:
				continue
			if _is_cell_occupied_by_other(battle, cell, unit.unit_id):
				continue
			result.append(cell)
	return result

func move_unit(battle, unit_id: String, cell: Dictionary) -> Dictionary:
	var unit = battle.get_unit(unit_id) if battle != null else null
	if unit == null or not unit.is_alive():
		return {"success": false, "message": "移动单位不存在。"}
	if not _contains_cell(get_movable_cells(battle, unit_id), cell):
		return {"success": false, "message": "不能移动到此处。"}
	unit.cell = _read_cell(cell)
	battle.append_log("%s移动到%s,%s。" % [unit.display_name, unit.cell.get("q", 0), unit.cell.get("r", 0)])
	return {"success": true, "message": "已经移动。"}

func get_attackable_units(battle, unit_id: String) -> Array:
	var unit = battle.get_unit(unit_id) if battle != null else null
	if unit == null or not unit.is_alive():
		return []
	var result: Array = []
	for target in battle.units:
		if not target.is_alive() or target.team == unit.team:
			continue
		if _cell_distance(unit.cell, target.cell) <= unit.attack_range:
			result.append(target)
	return result

func attack_unit(battle, attacker_id: String, defender_id: String) -> Dictionary:
	var attacker = battle.get_unit(attacker_id) if battle != null else null
	var defender = battle.get_unit(defender_id) if battle != null else null
	if attacker == null or defender == null:
		return {"success": false, "message": "攻击目标不存在。"}
	if not attacker.is_alive() or not defender.is_alive():
		return {"success": false, "message": "攻击目标已倒下。"}
	if attacker.team == defender.team:
		return {"success": false, "message": "不能攻击同伴。"}
	if _cell_distance(attacker.cell, defender.cell) > attacker.attack_range:
		return {"success": false, "message": "目标不在攻击范围内。"}

	var damage = maxi(1, attacker.attack - defender.defense)
	defender.hp = max(0, defender.hp - damage)
	battle.append_log("%s攻击%s，造成%d点伤害。" % [attacker.display_name, defender.display_name, damage])
	if defender.hp <= 0:
		battle.append_log("%s被击败。" % defender.display_name)
	check_battle_finished(battle)
	return {"success": true, "message": "已经攻击。", "damage": damage}

func end_unit_action(battle, unit_id: String) -> Dictionary:
	var unit = battle.get_unit(unit_id) if battle != null else null
	if unit == null:
		return {"success": false, "message": "行动单位不存在。"}
	unit.reset_charge()
	if battle.current_unit_id == unit_id:
		battle.current_unit_id = ""
	battle.is_action_phase = false
	return {"success": true, "message": "行动结束。"}

func resolve_enemy_action(battle, unit_id: String) -> Dictionary:
	var unit = battle.get_unit(unit_id) if battle != null else null
	if unit == null or not unit.is_alive():
		return {"success": false, "message": "敌人不存在。"}
	var target = _first_living_player(battle)
	if target == null:
		check_battle_finished(battle)
		return {"success": false, "message": "玩家单位不存在。"}

	if _cell_distance(unit.cell, target.cell) > unit.attack_range:
		var best_cell = _best_enemy_move_cell(battle, unit, target)
		move_unit(battle, unit.unit_id, best_cell)
	if unit.is_alive() and target.is_alive() and _cell_distance(unit.cell, target.cell) <= unit.attack_range:
		attack_unit(battle, unit.unit_id, target.unit_id)
	if not battle.is_finished:
		end_unit_action(battle, unit.unit_id)
	return {"success": true, "message": "敌人已经行动。"}

func resolve_retreat(battle) -> Dictionary:
	if battle == null:
		return {"success": false, "message": "战斗尚未准备好。"}
	if not battle.is_finished:
		battle.append_log("暂退数步。")
		battle.finish(false)
	return {"success": true, "message": "暂退数步。"}

func check_battle_finished(battle) -> void:
	if battle == null or battle.is_finished:
		return
	if not battle.has_living_team(TacticalBattleStateScript.TEAM_PLAYER):
		battle.append_log("气血不支，暂退数步。")
		battle.finish(false)
	elif not battle.has_living_team(TacticalBattleStateScript.TEAM_ENEMY):
		battle.append_log("敌人尽数败退。")
		battle.finish(true)

func _build_unit(raw_unit: Dictionary, game_state, source):
	var actor_id = str(raw_unit.get("actor_id", ""))
	var actor = source.get_actor(actor_id) if source != null and source.has_method("get_actor") else {}
	var unit_data = raw_unit.duplicate(true)
	unit_data["display_name"] = str(actor.get("name", actor_id))
	unit_data["hp"] = max(1, int(actor.get("hp", 1)))
	unit_data["max_hp"] = max(1, int(actor.get("max_hp", unit_data["hp"])))
	unit_data["attack"] = max(1, int(actor.get("attack", 1)))
	unit_data["defense"] = max(0, int(actor.get("defense", 0)))
	unit_data["cell"] = raw_unit.get("start_cell", raw_unit.get("cell", {}))
	if str(raw_unit.get("team", "")) == TacticalBattleStateScript.TEAM_PLAYER and game_state != null:
		unit_data["max_hp"] = max(1, int(game_state.hero_max_hp))
		unit_data["hp"] = clamp(int(game_state.hero_hp), 1, int(unit_data["max_hp"]))
	var unit = TacticalUnitStateScript.new()
	unit.from_dictionary(unit_data)
	return unit

func _is_valid_start_cell(battle, cell: Dictionary) -> bool:
	var q = int(cell.get("q", -1))
	var r = int(cell.get("r", -1))
	return q >= 0 and r >= 0 and q < battle.battlefield_width and r < battle.battlefield_height

func _is_cell_occupied(battle, cell: Dictionary) -> bool:
	for unit in battle.units:
		if unit.is_alive() and _same_cell(unit.cell, cell):
			return true
	return false

func _is_cell_occupied_by_other(battle, cell: Dictionary, unit_id: String) -> bool:
	for unit in battle.units:
		if unit.unit_id == unit_id:
			continue
		if unit.is_alive() and _same_cell(unit.cell, cell):
			return true
	return false

func _contains_cell(cells: Array, cell: Dictionary) -> bool:
	for candidate in cells:
		if _same_cell(candidate, cell):
			return true
	return false

func _same_cell(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("q", 0)) == int(b.get("q", 0)) and int(a.get("r", 0)) == int(b.get("r", 0))

func _read_cell(cell: Dictionary) -> Dictionary:
	return {"q": int(cell.get("q", 0)), "r": int(cell.get("r", 0))}

func _cell_distance(a: Dictionary, b: Dictionary) -> int:
	return abs(int(a.get("q", 0)) - int(b.get("q", 0))) + abs(int(a.get("r", 0)) - int(b.get("r", 0)))

func _first_living_player(battle):
	var players = battle.get_living_units_by_team(TacticalBattleStateScript.TEAM_PLAYER)
	if players.is_empty():
		return null
	return players[0]

func _best_enemy_move_cell(battle, unit, target) -> Dictionary:
	var cells = get_movable_cells(battle, unit.unit_id)
	if cells.is_empty():
		return unit.cell.duplicate(true)
	var best = cells[0]
	var best_distance = _cell_distance(best, target.cell)
	for cell in cells:
		var distance = _cell_distance(cell, target.cell)
		if distance < best_distance:
			best = cell
			best_distance = distance
	return best.duplicate(true)
