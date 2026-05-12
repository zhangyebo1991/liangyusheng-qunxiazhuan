extends RefCounted

const TacticalBattleStateScript = preload("res://scripts/domain/tactical_battle_state.gd")
const TacticalUnitStateScript = preload("res://scripts/domain/tactical_unit_state.gd")
const MartialArtRecordScript = preload("res://scripts/domain/martial_art_record.gd")

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

	# 写入战场地形矩阵：优先取 context.terrain_grid，缺失或非法时兜底全 grass 6×8。
	var raw_grid = context.get("terrain_grid", null)
	battle.terrain_grid = _normalize_terrain_grid(raw_grid)

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

func get_attackable_units_for_martial_art(battle, unit_id: String, martial_art_id: String, data_source = null) -> Array:
	var unit = battle.get_unit(unit_id) if battle != null else null
	if unit == null or not unit.is_alive():
		return []
	var martial_art = _get_tactical_martial_art(martial_art_id, data_source)
	if martial_art == null:
		return []
	if not unit.martial_art_ids.has(martial_art.id):
		return []
	if unit.mp < martial_art.tactical_mp_cost:
		return []
	var result: Array = []
	for target in battle.units:
		if not target.is_alive() or target.team == unit.team:
			continue
		if _is_target_in_martial_range(unit.cell, target.cell, martial_art):
			result.append(target)
	return result

func use_martial_art(battle, attacker_id: String, defender_id: String, martial_art_id: String, data_source = null) -> Dictionary:
	var attacker = battle.get_unit(attacker_id) if battle != null else null
	var defender = battle.get_unit(defender_id) if battle != null else null
	if attacker == null or defender == null:
		return {"success": false, "message": "武学目标不存在。"}
	if not attacker.is_alive() or not defender.is_alive():
		return {"success": false, "message": "武学目标已倒下。"}
	if attacker.team == defender.team:
		return {"success": false, "message": "不能攻击同伴。"}
	if not attacker.martial_art_ids.has(martial_art_id):
		return {"success": false, "message": "不能使用未学会的武学。"}
	var martial_art = _get_tactical_martial_art(martial_art_id, data_source)
	if martial_art == null:
		return {"success": false, "message": "此武学不能用于战棋。"}
	if attacker.mp < martial_art.tactical_mp_cost:
		return {"success": false, "message": "内力不足。"}
	if not _is_target_in_martial_range(attacker.cell, defender.cell, martial_art):
		return {"success": false, "message": "目标不在招式范围内。"}

	var damage = maxi(1, attacker.attack + martial_art.tactical_damage_bonus - defender.defense)
	attacker.mp = max(0, attacker.mp - martial_art.tactical_mp_cost)
	defender.hp = max(0, defender.hp - damage)
	battle.append_log("%s使出%s攻击%s，造成%d点伤害。" % [attacker.display_name, martial_art.name, defender.display_name, damage])
	if defender.hp <= 0:
		battle.append_log("%s被击败。" % defender.display_name)
	check_battle_finished(battle)
	return {"success": true, "message": "已经出招。", "damage": damage}

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

# 战棋行动统一入口（Task 5 起逐步替代直接调 attack_unit / use_martial_art 的 UI 路径）。
# action_id 取自招式编号（如 "sword_aura_swirl"）；target_cells 为 Array[Vector2i]，
# 由 tactical_range_system 的范围算法生成。
# 当前仅实现剑气漩分支；其他 action_id（普攻 attack 等）由后续 Task 7 扩展。
func resolve_action(battle, unit_id: String, action_id: String, target_cells: Array) -> Dictionary:
	if battle == null:
		return {"success": false, "message": "战斗尚未准备好。"}
	var unit = battle.get_unit(unit_id)
	if unit == null or not unit.is_alive():
		return {"success": false, "message": "行动单位不存在。"}
	if action_id == "sword_aura_swirl":
		return _resolve_sword_aura_swirl(battle, unit, target_cells)
	return {"success": false, "message": "未知行动。"}

func _resolve_sword_aura_swirl(battle, attacker, target_cells: Array) -> Dictionary:
	var skill_data = repository.get_martial_art("sword_aura_swirl") if repository != null else {}
	if skill_data.is_empty():
		return {"success": false, "message": "剑气漩数据缺失。"}
	var mp_cost = int(skill_data.get("mp_cost", 8))
	var base_damage = int(skill_data.get("base_damage", 0))
	var scale_ratio = float(skill_data.get("scale_ratio", 0.0))
	if attacker.mp < mp_cost:
		return {"success": false, "message": "内力不足。"}
	var damage_each = int(base_damage + attacker.attack * scale_ratio)
	if damage_each < 1:
		damage_each = 1
	var hits: Array = []
	for cell_v in target_cells:
		var defender = _find_unit_at_cell_v(battle, cell_v)
		if defender == null or defender.team == attacker.team or not defender.is_alive():
			continue
		defender.hp = max(0, defender.hp - damage_each)
		hits.append(defender.unit_id)
		battle.append_log("%s使出剑气漩袭击%s，造成%d点伤害。" % [attacker.display_name, defender.display_name, damage_each])
		if defender.hp <= 0:
			battle.append_log("%s被击败。" % defender.display_name)
	attacker.mp = max(0, attacker.mp - mp_cost)
	if hits.is_empty():
		battle.append_log("%s剑气漩起，未击中目标。" % attacker.display_name)
	check_battle_finished(battle)
	return {"success": true, "message": "剑气漩已发动。", "damage": damage_each, "hits": hits}

# target_cells 元素为 Vector2i(x=q, y=r)；与 unit.cell {q,r} 对齐查找。
func _find_unit_at_cell_v(battle, cell_v):
	if typeof(cell_v) != TYPE_VECTOR2I:
		return null
	var q = int(cell_v.x)
	var r = int(cell_v.y)
	for unit in battle.units:
		if not unit.is_alive():
			continue
		if int(unit.cell.get("q", 0)) == q and int(unit.cell.get("r", 0)) == r:
			return unit
	return null

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

# 兜底地形矩阵：传入合法 6 行 × 8 列字符串数组则原样深拷贝；
# 否则回退默认全 grass 的 6×8 矩阵。
func _normalize_terrain_grid(raw_grid) -> Array:
	var fallback: Array = []
	for _r in range(6):
		var row: Array = []
		for _c in range(8):
			row.append("grass")
		fallback.append(row)
	if typeof(raw_grid) != TYPE_ARRAY or raw_grid.size() != 6:
		return fallback
	var normalized: Array = []
	for row in raw_grid:
		if typeof(row) != TYPE_ARRAY or row.size() != 8:
			return fallback
		var clean_row: Array = []
		for cell in row:
			clean_row.append(str(cell))
		normalized.append(clean_row)
	return normalized

func _build_unit(raw_unit: Dictionary, game_state, source):
	var actor_id = str(raw_unit.get("actor_id", ""))
	var actor = source.get_actor(actor_id) if source != null and source.has_method("get_actor") else {}
	var unit_data = raw_unit.duplicate(true)
	unit_data["display_name"] = str(actor.get("name", actor_id))
	unit_data["hp"] = max(1, int(actor.get("hp", 1)))
	unit_data["max_hp"] = max(1, int(actor.get("max_hp", unit_data["hp"])))
	unit_data["attack"] = max(1, int(actor.get("attack", 1)))
	unit_data["defense"] = max(0, int(actor.get("defense", 0)))
	unit_data["martial_art_ids"] = actor.get("martial_arts", [])
	unit_data["max_mp"] = max(0, int(raw_unit.get("max_mp", 0)))
	unit_data["mp"] = clamp(int(raw_unit.get("mp", unit_data["max_mp"])), 0, int(unit_data["max_mp"]))
	unit_data["cell"] = raw_unit.get("start_cell", raw_unit.get("cell", {}))
	if str(raw_unit.get("team", "")) == TacticalBattleStateScript.TEAM_PLAYER and game_state != null:
		unit_data["max_hp"] = max(1, int(game_state.hero_max_hp))
		unit_data["hp"] = clamp(int(game_state.hero_hp), 1, int(unit_data["max_hp"]))
		unit_data["max_mp"] = max(0, int(game_state.hero_max_mp))
		if actor_id == "hero_yun":
			unit_data["mp"] = clamp(int(game_state.hero_cur_mp), 0, int(unit_data["max_mp"]))
		else:
			unit_data["mp"] = int(unit_data["max_mp"])
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

func _get_tactical_martial_art(martial_art_id: String, data_source = null):
	if martial_art_id.is_empty():
		return null
	var source = data_source if data_source != null else repository
	if source == null or not source.has_method("get_martial_art"):
		return null
	var martial_art_data = source.get_martial_art(martial_art_id)
	if martial_art_data.is_empty():
		return null
	var martial_art = MartialArtRecordScript.from_dictionary(martial_art_data)
	if not martial_art.has_tactical_config():
		return null
	if not ["diamond", "line"].has(martial_art.tactical_range_shape):
		return null
	return martial_art

func _is_target_in_martial_range(attacker_cell: Dictionary, defender_cell: Dictionary, martial_art) -> bool:
	var distance = _cell_distance(attacker_cell, defender_cell)
	if distance <= 0 or distance > martial_art.tactical_range:
		return false
	match martial_art.tactical_range_shape:
		"diamond":
			return true
		"line":
			return int(attacker_cell.get("q", 0)) == int(defender_cell.get("q", 0)) or int(attacker_cell.get("r", 0)) == int(defender_cell.get("r", 0))
		_:
			return false

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
