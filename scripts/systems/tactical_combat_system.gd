extends RefCounted

const TacticalBattleStateScript = preload("res://scripts/domain/tactical_battle_state.gd")
const TacticalUnitStateScript = preload("res://scripts/domain/tactical_unit_state.gd")
const MartialArtRecordScript = preload("res://scripts/domain/martial_art_record.gd")
const ProficiencySystemScript = preload("res://scripts/systems/proficiency_system.gd")
const ActorStatsSystemScript = preload("res://scripts/systems/actor_stats_system.gd")
const TacticalAIScript = preload("res://scripts/systems/tactical_ai.gd")

var repository = null
var _proficiency_system = null
var _proficiency_map: Dictionary = {}
var _actor_stats_system = ActorStatsSystemScript.new()
var _tactical_ai = null

func set_repository(next_repository) -> void:
	repository = next_repository

func set_proficiency(proficiency_system, proficiency_map: Dictionary) -> void:
	_proficiency_system = proficiency_system
	_proficiency_map = proficiency_map

func set_tactical_ai(tactical_ai) -> void:
	_tactical_ai = tactical_ai
	if _tactical_ai != null and _tactical_ai.has_method("set_combat_system"):
		_tactical_ai.set_combat_system(self)

func create_battle(game_state, context: Dictionary, data_source = null):
	var source = data_source if data_source != null else repository
	var battle = TacticalBattleStateScript.new()
	battle.source_map_id = str(context.get("source_map_id", "mountain_pass"))
	if battle.source_map_id.is_empty():
		battle.source_map_id = "mountain_pass"
	battle.source_object_id = str(context.get("source_object_id", ""))
	battle.quest_id = str(context.get("quest_id", ""))
	battle.repeatable = bool(context.get("repeatable", false))
	var rewards = context.get("victory_rewards", {})
	if typeof(rewards) == TYPE_DICTIONARY:
		battle.victory_rewards = rewards.duplicate(true)
	battle.reward_martial_art_id = str(context.get("martial_art_id", battle.reward_martial_art_id))
	battle.proficiency_reward = max(0, int(context.get("proficiency_reward", battle.proficiency_reward)))
	battle.time_mode = str(context.get("time_mode", TacticalBattleStateScript.TIME_MODE_PAUSE_ON_ACTION))
	if battle.time_mode.is_empty():
		battle.time_mode = TacticalBattleStateScript.TIME_MODE_PAUSE_ON_ACTION

	var battlefield = context.get("battlefield", {})
	if typeof(battlefield) == TYPE_DICTIONARY:
		battle.battlefield_width = max(1, int(battlefield.get("width", 7)))
		battle.battlefield_height = max(1, int(battlefield.get("height", 5)))

	# 写入战场地形矩阵：优先取 context.terrain_grid；缺失或非法时兜底全 grass 6×8。
	var raw_grid = context.get("terrain_grid", null)
	battle.terrain_grid = _normalize_terrain_grid(raw_grid)
	if battle.terrain_grid.size() > 0 and typeof(battle.terrain_grid[0]) == TYPE_ARRAY:
		battle.battlefield_height = battle.terrain_grid.size()
		battle.battlefield_width = battle.terrain_grid[0].size()

	var raw_units = context.get("units", [])
	if typeof(raw_units) != TYPE_ARRAY:
		raw_units = []
	var player_start_cells = _player_start_cells(context, raw_units)
	var player_max_members = _player_max_members(context, player_start_cells.size())
	_add_party_player_units(battle, game_state, source, player_start_cells, player_max_members)
	for raw_unit in raw_units:
		if typeof(raw_unit) != TYPE_DICTIONARY:
			continue
		if str(raw_unit.get("team", "")) == TacticalBattleStateScript.TEAM_PLAYER:
			continue
		var unit = _build_unit(raw_unit, game_state, source)
		if _is_valid_start_cell(battle, unit.cell) and not _is_cell_occupied(battle, unit.cell):
			battle.add_unit(unit)
		else:
			_log(battle, "%s站位无效。" % unit.display_name)

	if not battle.has_living_team(TacticalBattleStateScript.TEAM_PLAYER):
		_log(battle, "玩家单位缺失。")
	if not battle.has_living_team(TacticalBattleStateScript.TEAM_ENEMY):
		_log(battle, "敌方单位缺失。")
		battle.finish(true)
	if _tactical_ai != null:
		_tactical_ai.set_repository(source)
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
	return get_ready_unit_excluding(battle, "")

func get_ready_unit_excluding(battle, excluded_unit_id: String):
	if battle == null:
		return null
	var ready_players: Array = []
	var ready_enemies: Array = []
	for unit in battle.units:
		if str(unit.unit_id) == excluded_unit_id:
			continue
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
	_log(battle, "%s可以行动。" % unit.display_name)
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
	_log(battle, "%s移动到%s,%s。" % [unit.display_name, unit.cell.get("q", 0), unit.cell.get("r", 0)])
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
	_log(battle, "%s使出%s攻击%s，造成%d点伤害。" % [attacker.display_name, martial_art.name, defender.display_name, damage])
	if defender.hp <= 0:
		_log(battle, "%s被击败。" % defender.display_name)
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
	_log(battle, "%s攻击%s，造成%d点伤害。" % [attacker.display_name, defender.display_name, damage])
	if defender.hp <= 0:
		_log(battle, "%s被击败。" % defender.display_name)
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
# action_id 取自招式编号（如 "sword_aura_swirl"）；普攻约定为 "attack"。
# target_cells 为 Array[Vector2i]，由 tactical_range_system 的范围算法生成；
# Task 7 起允许空数组（空放）：行动仍被接受、招式仍扣 MP，行动结束后通过
# EventBus.tactical_action_resolved(unit_id, action_id, target_cells) 通知 UI。
func resolve_action(battle, unit_id: String, action_id: String, target_cells: Array) -> Dictionary:
	if battle == null:
		return {"success": false, "message": "战斗尚未准备好。"}
	var unit = battle.get_unit(unit_id)
	if unit == null or not unit.is_alive():
		return {"success": false, "message": "行动单位不存在。"}
	if action_id != "attack" and not unit.martial_art_ids.has(action_id):
		return {"success": false, "message": "不能使用未学会的武学。"}
	var result: Dictionary = {}
	if action_id == "sword_aura_swirl":
		result = _resolve_sword_aura_swirl(battle, unit, target_cells)
	elif action_id == "attack":
		result = _resolve_basic_attack(battle, unit, target_cells)
	else:
		# Task 17 fallback：未单独写 handler 的 tactical 武学（如方向型「穿云刺」）
		# 走通用结算：扣 mp_cost，对 target_cells 列表逐格命中扣血。
		var skill_data: Dictionary = {}
		if repository != null:
			skill_data = repository.get_martial_art(action_id)
		if skill_data.is_empty() or typeof(skill_data.get("tactical", {})) != TYPE_DICTIONARY:
			return {"success": false, "message": "未知行动。"}
		result = _resolve_generic_skill(battle, unit, action_id, target_cells, skill_data)
	if bool(result.get("success", false)):
		_emit_action_resolved(unit_id, action_id, target_cells)
		if action_id != "attack" and _proficiency_system != null:
			_proficiency_system.add_use(_proficiency_map, action_id)
	return result

func build_target_cells_for_action(battle, unit_id: String, action_id: String, target_cell: Vector2i) -> Array:
	var unit = battle.get_unit(unit_id) if battle != null else null
	if unit == null:
		return []
	return build_target_cells_for_action_from_cell(battle, unit.cell, action_id, target_cell)

func build_target_cells_for_action_from_cell(battle, attacker_cell: Dictionary, action_id: String, target_cell: Vector2i) -> Array:
	if battle == null:
		return []
	if action_id == "attack":
		return [target_cell]
	var skill_data: Dictionary = {}
	if repository != null:
		skill_data = repository.get_martial_art(action_id)
	if skill_data.is_empty() or typeof(skill_data.get("tactical", {})) != TYPE_DICTIONARY:
		return [target_cell]
	var tactical: Dictionary = skill_data.get("tactical", {})
	var shape := _skill_shape(skill_data)
	var range_val: int = max(1, int(tactical.get("range", skill_data.get("cast_range", 1))))
	if shape == "target_cross_1":
		return _target_cross_cells(battle, target_cell)
	if shape.begins_with("line_") or shape == "line" or shape == "pierce":
		var line_direction := _line_direction_to_target(attacker_cell, target_cell)
		if line_direction == Vector2i.ZERO:
			return [target_cell]
		return _ray_cells_from_cell(battle, attacker_cell, line_direction, range_val)
	if shape == "fan":
		var fan_direction := _dominant_direction_to_target(attacker_cell, target_cell)
		if fan_direction == Vector2i.ZERO:
			return [target_cell]
		return _fan_cells_from_cell(battle, attacker_cell, fan_direction, range_val)
	if shape == "surround":
		return _surround_cells_from_cell(battle, attacker_cell)
	if shape == "ring":
		return _ring_cells_from_cell(battle, attacker_cell, range_val)
	return [target_cell]

func is_action_target_valid_from_cell(battle, unit_id: String, attacker_cell: Dictionary, action_id: String, target_cells: Array) -> bool:
	var unit = battle.get_unit(unit_id) if battle != null else null
	if unit == null or not unit.is_alive():
		return false
	var previous_cell: Dictionary = unit.cell.duplicate(true)
	unit.cell = _read_cell(attacker_cell)
	var valid := false
	if action_id == "attack":
		valid = target_cells.size() == 1 and _is_valid_target_cell(battle, target_cells[0]) and _cell_distance_to_vector(unit.cell, target_cells[0]) > 0 and _cell_distance_to_vector(unit.cell, target_cells[0]) <= int(unit.attack_range)
	elif unit.martial_art_ids.has(action_id):
		var skill_data: Dictionary = repository.get_martial_art(action_id) if repository != null else {}
		if not skill_data.is_empty():
			valid = _are_target_cells_valid_for_skill(battle, unit, target_cells, skill_data)
	unit.cell = previous_cell
	return valid

func count_enemy_hits_in_cells(battle, attacker_team: String, target_cells: Array) -> int:
	if battle == null:
		return 0
	var hits := {}
	for cell_v in target_cells:
		var defender = _find_unit_at_cell_v(battle, cell_v)
		if defender == null or not defender.is_alive() or defender.team == attacker_team:
			continue
		hits[str(defender.unit_id)] = true
	return hits.size()

# Task 17: 通用方向型/范围型招式结算。
# - 扣除 tactical.mp_cost；mp 不足直接失败。
# - 对 target_cells 内每个敌方占据格结算 max(1, attacker.attack + damage_bonus - defender.defense)。
# - 空中（无敌人或全是己方）走"挥击落空"日志。
func _resolve_generic_skill(battle, attacker, action_id: String, target_cells: Array, skill_data: Dictionary) -> Dictionary:
	var tactical = skill_data.get("tactical", {})
	var mp_cost: int = int(tactical.get("mp_cost", skill_data.get("mp_cost", 0)))
	var damage_bonus: int = int(tactical.get("damage_bonus", 0)) + _proficiency_bonus(action_id, skill_data)
	if not _are_target_cells_valid_for_skill(battle, attacker, target_cells, skill_data):
		return {"success": false, "message": "目标格不在招式范围内。"}
	if attacker.mp < mp_cost:
		return {"success": false, "message": "内力不足。"}
	attacker.mp = max(0, attacker.mp - mp_cost)
	var skill_name: String = str(skill_data.get("name", action_id))
	var hits: Array = []
	for cell_v in target_cells:
		var defender = _find_unit_at_cell_v(battle, cell_v)
		if defender == null or defender.team == attacker.team or not defender.is_alive():
			continue
		var damage: int = maxi(1, attacker.attack + damage_bonus - defender.defense)
		defender.hp = max(0, defender.hp - damage)
		hits.append(defender.unit_id)
		_log(battle, "%s使出%s攻击%s，造成%d点伤害。" % [attacker.display_name, skill_name, defender.display_name, damage])
		if defender.hp <= 0:
			_log(battle, "%s被击败。" % defender.display_name)
	if hits.is_empty():
		_log(battle, "%s%s落空。" % [attacker.display_name, skill_name])
	check_battle_finished(battle)
	return {"success": true, "message": "已经出招。", "hits": hits}

func _resolve_sword_aura_swirl(battle, attacker, target_cells: Array) -> Dictionary:
	var skill_data = repository.get_martial_art("sword_aura_swirl") if repository != null else {}
	if skill_data.is_empty():
		return {"success": false, "message": "剑气漩数据缺失。"}
	var mp_cost = int(skill_data.get("mp_cost", 8))
	var base_damage = int(skill_data.get("base_damage", 0))
	var scale_ratio = float(skill_data.get("scale_ratio", 0.0))
	if not _are_target_cells_valid_for_skill(battle, attacker, target_cells, skill_data):
		return {"success": false, "message": "目标格不在招式范围内。"}
	if attacker.mp < mp_cost:
		return {"success": false, "message": "内力不足。"}
	var damage_each = int(base_damage + attacker.attack * scale_ratio) + _proficiency_bonus("sword_aura_swirl", skill_data)
	if damage_each < 1:
		damage_each = 1
	var hits: Array = []
	for cell_v in target_cells:
		var defender = _find_unit_at_cell_v(battle, cell_v)
		if defender == null or defender.team == attacker.team or not defender.is_alive():
			continue
		defender.hp = max(0, defender.hp - damage_each)
		hits.append(defender.unit_id)
		_log(battle, "%s使出剑气漩袭击%s，造成%d点伤害。" % [attacker.display_name, defender.display_name, damage_each])
		if defender.hp <= 0:
			_log(battle, "%s被击败。" % defender.display_name)
	attacker.mp = max(0, attacker.mp - mp_cost)
	if hits.is_empty():
		_log(battle, "%s剑气漩起，未击中目标。" % attacker.display_name)
	check_battle_finished(battle)
	return {"success": true, "message": "剑气漩已发动。", "damage": damage_each, "hits": hits}

func _proficiency_bonus(action_id: String, skill_data: Dictionary) -> int:
	if _proficiency_system == null:
		return 0
	var thresholds: Array = skill_data.get("proficiency_thresholds", [])
	if typeof(thresholds) != TYPE_ARRAY or thresholds.is_empty():
		return 0
	return _proficiency_system.get_bonus(int(_proficiency_map.get(action_id, 0)), thresholds)

func _are_target_cells_valid_for_skill(battle, attacker, target_cells: Array, skill_data: Dictionary) -> bool:
	if target_cells.is_empty():
		return true
	var tactical = skill_data.get("tactical", {})
	if typeof(tactical) != TYPE_DICTIONARY:
		return false
	var shape := _skill_shape(skill_data)
	var range_val: int = max(1, int(tactical.get("range", skill_data.get("cast_range", 1))))
	if shape.begins_with("line_") or shape == "line" or shape == "pierce":
		return _target_cells_fit_line(battle, attacker, target_cells, range_val)
	if shape == "fan":
		return _target_cells_fit_fan(battle, attacker, target_cells, range_val)
	if shape == "surround":
		return _target_cells_fit_surround(battle, attacker, target_cells)
	if shape == "ring":
		return _target_cells_fit_ring(battle, attacker, target_cells, range_val)
	if shape == "target_cross_1":
		var cast_range: int = max(1, int(skill_data.get("cast_range", range_val)))
		return _target_cells_fit_target_cross(battle, attacker, target_cells, cast_range)
	if shape == "diamond":
		return _target_cells_fit_diamond(battle, attacker, target_cells, range_val)
	return false

func _skill_shape(skill_data: Dictionary) -> String:
	var shape := str(skill_data.get("shape", ""))
	if not shape.is_empty():
		return shape
	var tactical: Variant = skill_data.get("tactical", {})
	if typeof(tactical) == TYPE_DICTIONARY:
		return str(tactical.get("range_shape", ""))
	return ""

func _target_cells_fit_diamond(battle, attacker, target_cells: Array, range_val: int) -> bool:
	for target_cell_value in target_cells:
		if not _is_valid_target_cell(battle, target_cell_value):
			return false
		var target_cell: Vector2i = target_cell_value
		var distance: int = _cell_distance_to_vector(attacker.cell, target_cell)
		if distance <= 0 or distance > range_val:
			return false
	return true

func _target_cells_fit_line(battle, attacker, target_cells: Array, range_val: int) -> bool:
	var expected_direction := Vector2i.ZERO
	for target_cell_value in target_cells:
		if not _is_valid_target_cell(battle, target_cell_value):
			return false
		var target_cell: Vector2i = target_cell_value
		var delta: Vector2i = _cell_delta_to_vector(attacker.cell, target_cell)
		var distance: int = abs(delta.x) + abs(delta.y)
		if distance <= 0 or distance > range_val:
			return false
		if delta.x != 0 and delta.y != 0:
			return false
		var direction := Vector2i(_axis_sign(delta.x), _axis_sign(delta.y))
		if expected_direction == Vector2i.ZERO:
			expected_direction = direction
		elif expected_direction != direction:
			return false
	return true

func _target_cells_fit_fan(battle, attacker, target_cells: Array, range_val: int) -> bool:
	for direction_value in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var direction: Vector2i = direction_value
		var all_fit := true
		for target_cell_value in target_cells:
			if not _is_valid_target_cell(battle, target_cell_value):
				all_fit = false
				break
			var target_cell: Vector2i = target_cell_value
			if not _cell_in_fan(attacker.cell, target_cell, direction, range_val):
				all_fit = false
				break
		if all_fit:
			return true
	return false

func _target_cells_fit_surround(battle, attacker, target_cells: Array) -> bool:
	for target_cell_value in target_cells:
		if not _is_valid_target_cell(battle, target_cell_value):
			return false
		var target_cell: Vector2i = target_cell_value
		var delta: Vector2i = _cell_delta_to_vector(attacker.cell, target_cell)
		if max(abs(delta.x), abs(delta.y)) != 1:
			return false
	return true

func _target_cells_fit_ring(battle, attacker, target_cells: Array, range_val: int) -> bool:
	for target_cell_value in target_cells:
		if not _is_valid_target_cell(battle, target_cell_value):
			return false
		var target_cell: Vector2i = target_cell_value
		if _cell_distance_to_vector(attacker.cell, target_cell) != range_val:
			return false
	return true

func _target_cells_fit_target_cross(battle, attacker, target_cells: Array, cast_range: int) -> bool:
	var centers := _target_cross_centers(battle, attacker, cast_range)
	for center in centers:
		var allowed: Dictionary = {}
		for blast_cell in _target_cross_cells(battle, center):
			allowed[blast_cell] = true
		var all_fit := true
		for target_cell_value in target_cells:
			if not _is_valid_target_cell(battle, target_cell_value):
				all_fit = false
				break
			var target_cell: Vector2i = target_cell_value
			if not allowed.has(target_cell):
				all_fit = false
				break
		if all_fit:
			return true
	return false

func _target_cross_centers(battle, attacker, cast_range: int) -> Array:
	var centers: Array = []
	for row_index in range(battle.battlefield_height):
		for col_index in range(battle.battlefield_width):
			var center := Vector2i(col_index, row_index)
			var distance: int = _cell_distance_to_vector(attacker.cell, center)
			if distance > 0 and distance <= cast_range:
				centers.append(center)
	return centers

func _target_cross_cells(battle, center: Vector2i) -> Array:
	var cells: Array = [center]
	for direction_value in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var direction: Vector2i = direction_value
		var target_cell: Vector2i = center + direction
		if _is_valid_target_cell(battle, target_cell):
			cells.append(target_cell)
	return cells

func _line_direction_to_target(attacker_cell: Dictionary, target_cell: Vector2i) -> Vector2i:
	var delta: Vector2i = _cell_delta_to_vector(attacker_cell, target_cell)
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	if delta.x != 0 and delta.y != 0:
		return Vector2i.ZERO
	return Vector2i(_axis_sign(delta.x), _axis_sign(delta.y))

func _dominant_direction_to_target(attacker_cell: Dictionary, target_cell: Vector2i) -> Vector2i:
	var delta: Vector2i = _cell_delta_to_vector(attacker_cell, target_cell)
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	if abs(delta.x) >= abs(delta.y):
		return Vector2i(_axis_sign(delta.x), 0)
	return Vector2i(0, _axis_sign(delta.y))

func _ray_cells_from_cell(battle, attacker_cell: Dictionary, direction: Vector2i, range_val: int) -> Array:
	var result: Array = []
	var src := Vector2i(int(attacker_cell.get("q", 0)), int(attacker_cell.get("r", 0)))
	for i in range(1, range_val + 1):
		var target_cell := src + direction * i
		if not _is_valid_target_cell(battle, target_cell):
			break
		result.append(target_cell)
	return result

func _fan_cells_from_cell(battle, attacker_cell: Dictionary, direction: Vector2i, range_val: int) -> Array:
	var result: Array = []
	for row_index in range(battle.battlefield_height):
		for col_index in range(battle.battlefield_width):
			var target_cell := Vector2i(col_index, row_index)
			if _cell_in_fan(attacker_cell, target_cell, direction, range_val):
				result.append(target_cell)
	return result

func _surround_cells_from_cell(battle, attacker_cell: Dictionary) -> Array:
	var result: Array = []
	var src := Vector2i(int(attacker_cell.get("q", 0)), int(attacker_cell.get("r", 0)))
	for row_delta in [-1, 0, 1]:
		for col_delta in [-1, 0, 1]:
			if row_delta == 0 and col_delta == 0:
				continue
			var target_cell := Vector2i(src.x + col_delta, src.y + row_delta)
			if _is_valid_target_cell(battle, target_cell):
				result.append(target_cell)
	return result

func _ring_cells_from_cell(battle, attacker_cell: Dictionary, range_val: int) -> Array:
	var result: Array = []
	var src := Vector2i(int(attacker_cell.get("q", 0)), int(attacker_cell.get("r", 0)))
	for row_index in range(battle.battlefield_height):
		for col_index in range(battle.battlefield_width):
			var target_cell := Vector2i(col_index, row_index)
			if target_cell == src:
				continue
			if abs(target_cell.x - src.x) + abs(target_cell.y - src.y) == range_val:
				result.append(target_cell)
	return result

func _cell_in_fan(attacker_cell: Dictionary, target_cell: Vector2i, direction: Vector2i, range_val: int) -> bool:
	var delta: Vector2i = _cell_delta_to_vector(attacker_cell, target_cell)
	var distance: int = abs(delta.x) + abs(delta.y)
	if distance <= 0 or distance > range_val:
		return false
	var projection: int = delta.x * direction.x + delta.y * direction.y
	if projection <= 0:
		return false
	var cross: int = abs(delta.x * direction.y - delta.y * direction.x)
	return cross <= projection * 2

func _is_valid_target_cell(battle, target_cell) -> bool:
	if typeof(target_cell) != TYPE_VECTOR2I:
		return false
	return target_cell.x >= 0 and target_cell.x < battle.battlefield_width and target_cell.y >= 0 and target_cell.y < battle.battlefield_height

func _cell_delta_to_vector(attacker_cell: Dictionary, target_cell: Vector2i) -> Vector2i:
	return Vector2i(target_cell.x - int(attacker_cell.get("q", 0)), target_cell.y - int(attacker_cell.get("r", 0)))

func _cell_distance_to_vector(attacker_cell: Dictionary, target_cell: Vector2i) -> int:
	var delta: Vector2i = _cell_delta_to_vector(attacker_cell, target_cell)
	return abs(delta.x) + abs(delta.y)

func _axis_sign(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0

# 普攻：单格选中。target_cells 为 1 格则尝试命中该格敌人；为空（空放）也接受，
# 不扣资源、不造成伤害，仅推进行动结束。
func _resolve_basic_attack(battle, attacker, target_cells: Array) -> Dictionary:
	var hits: Array = []
	for cell_v in target_cells:
		# 范围验证：目标格必须在攻击距离内（曼哈顿距离 ≤ attack_range）。
		if typeof(cell_v) == TYPE_VECTOR2I:
			var dist := _cell_distance_to_vector(attacker.cell, cell_v)
			if dist <= 0 or dist > int(attacker.attack_range):
				continue
		var defender = _find_unit_at_cell_v(battle, cell_v)
		if defender == null or defender.team == attacker.team or not defender.is_alive():
			continue
		var damage = maxi(1, attacker.attack - defender.defense)
		defender.hp = max(0, defender.hp - damage)
		hits.append(defender.unit_id)
		_log(battle, "%s攻击%s，造成%d点伤害。" % [attacker.display_name, defender.display_name, damage])
		if defender.hp <= 0:
			_log(battle, "%s被击败。" % defender.display_name)
	if target_cells.is_empty():
		_log(battle, "%s挥剑落空。" % attacker.display_name)
	check_battle_finished(battle)
	return {"success": true, "message": "普攻已结算。", "hits": hits}

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

# 通知 UI 行动已结算（驱动飞字、动画、行动栏复位等）。
# 单元测试中 SceneTree 自动加载 EventBus；离线工具脚本里若无 autoload 则静默跳过。
func _emit_action_resolved(unit_id: String, action_id: String, target_cells: Array) -> void:
	var loop = Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return
	var bus = (loop as SceneTree).root.get_node_or_null("EventBus")
	if bus == null:
		return
	bus.tactical_action_resolved.emit(unit_id, action_id, target_cells)

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

func _resolve_auto_action(battle, unit) -> void:
	if _tactical_ai == null:
		_log(battle, "AI 系统未初始化。")
		end_unit_action(battle, unit.unit_id)
		return
	var action = _tactical_ai.evaluate(unit, battle)
	if not action.get("success", false):
		_log(battle, "AI 决策失败：%s" % str(action.get("message", "未知错误")))
		end_unit_action(battle, unit.unit_id)
		return
	var move_to = action.get("move_to", unit.cell)
	var use_skill = str(action.get("use_skill", "attack"))
	var target = action.get("target", Vector2i.ZERO)
	move_unit(battle, unit.unit_id, move_to)
	var target_cells = [target]
	var result = resolve_action(battle, unit.unit_id, use_skill, target_cells)
	if result.get("success", false):
		_log(battle, "%s 自动行动完成。" % unit.display_name)
	else:
		_log(battle, "%s 自动行动失败：%s" % [unit.display_name, str(result.get("message", "未知错误"))])
	end_unit_action(battle, unit.unit_id)

func resolve_retreat(battle) -> Dictionary:
	if battle == null:
		return {"success": false, "message": "战斗尚未准备好。"}
	if not battle.is_finished:
		_log(battle, "暂退数步。")
		battle.finish(false)
	return {"success": true, "message": "暂退数步。"}

func check_battle_finished(battle) -> void:
	if battle == null or battle.is_finished:
		return
	if not battle.has_living_team(TacticalBattleStateScript.TEAM_PLAYER):
		_log(battle, "气血不支，暂退数步。")
		battle.finish(false)
	elif not battle.has_living_team(TacticalBattleStateScript.TEAM_ENEMY):
		_log(battle, "敌人尽数败退。")
		battle.finish(true)

# 兜底地形矩阵：传入合法任意矩形字符串数组则原样深拷贝；
# 否则回退默认全 grass 的 6×8 矩阵。
func _normalize_terrain_grid(raw_grid) -> Array:
	var fallback: Array = []
	for _r in range(6):
		var row: Array = []
		for _c in range(8):
			row.append("grass")
		fallback.append(row)
	if typeof(raw_grid) != TYPE_ARRAY or raw_grid.is_empty():
		return fallback
	var expected_cols := -1
	var normalized: Array = []
	for row in raw_grid:
		if typeof(row) != TYPE_ARRAY or row.is_empty():
			return fallback
		if expected_cols < 0:
			expected_cols = row.size()
		elif row.size() != expected_cols:
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
	unit_data["sprite_tile_id"] = str(actor.get("sprite_tile_id", ""))
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

func _add_party_player_units(battle, game_state, source, start_cells: Array, max_members: int) -> void:
	if game_state == null or game_state.party == null:
		return
	_sync_hero_member_status_for_battle(game_state)
	var index := 0
	var actor_ids: Array = game_state.party.get_deployable_members(max_members) if game_state.party.has_method("get_deployable_members") else game_state.party.members
	for actor_id in actor_ids:
		if index >= start_cells.size():
			_log(battle, "%s无法入场：本场出战位置不足。" % _actor_display_name(source, str(actor_id)))
			continue
		var stats = _actor_stats_system.build_stats(game_state.party, str(actor_id), source)
		if stats.is_empty():
			_log(battle, "%s无法入场：角色数据缺失。" % _actor_display_name(source, str(actor_id)))
			continue
		stats["team"] = TacticalBattleStateScript.TEAM_PLAYER
		stats["cell"] = start_cells[index].duplicate(true)
		stats["start_cell"] = start_cells[index].duplicate(true)
		var unit = TacticalUnitStateScript.new()
		unit.from_dictionary(stats)
		if _is_valid_start_cell(battle, unit.cell) and not _is_cell_occupied(battle, unit.cell):
			battle.add_unit(unit)
			index += 1
		else:
			_log(battle, "%s站位无效。" % unit.display_name)

func _sync_hero_member_status_for_battle(game_state) -> void:
	if game_state == null or game_state.party == null or not game_state.party.has_member("hero_yun"):
		return
	game_state.party.set_member_status("hero_yun", {"hp": int(game_state.hero_hp), "mp": int(game_state.hero_cur_mp)})

func _player_start_cells(context: Dictionary, raw_units: Array) -> Array:
	var result: Array = []
	var deploy = context.get("player_deploy", {})
	if typeof(deploy) == TYPE_DICTIONARY:
		var deploy_cells = deploy.get("start_cells", [])
		if typeof(deploy_cells) == TYPE_ARRAY:
			for cell in deploy_cells:
				if typeof(cell) == TYPE_DICTIONARY:
					result.append(_read_cell(cell))
	if not result.is_empty():
		return result
	var explicit = context.get("player_start_cells", [])
	if typeof(explicit) == TYPE_ARRAY:
		for cell in explicit:
			if typeof(cell) == TYPE_DICTIONARY:
				result.append(_read_cell(cell))
	if not result.is_empty():
		return result
	for raw_unit in raw_units:
		if typeof(raw_unit) != TYPE_DICTIONARY:
			continue
		if str(raw_unit.get("team", "")) == TacticalBattleStateScript.TEAM_PLAYER:
			result.append(_read_cell(raw_unit.get("start_cell", raw_unit.get("cell", {}))))
	if result.is_empty():
		result.append({"q": 1, "r": 2})
	return result

func _player_max_members(context: Dictionary, start_cell_count: int) -> int:
	var deploy = context.get("player_deploy", {})
	if typeof(deploy) == TYPE_DICTIONARY and deploy.has("max_members"):
		return max(0, int(deploy.get("max_members", 0)))
	return max(0, start_cell_count)

func _actor_display_name(source, actor_id: String) -> String:
	if actor_id.is_empty():
		return "未知侠客"
	if source != null and source.has_method("get_actor"):
		var actor = source.get_actor(actor_id)
		if typeof(actor) == TYPE_DICTIONARY and not actor.is_empty():
			return str(actor.get("name", actor_id))
	return actor_id

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
	if not ["diamond", "line", "fan", "surround", "pierce", "ring", "target_cross_1"].has(martial_art.tactical_range_shape):
		return null
	return martial_art

func _is_target_in_martial_range(attacker_cell: Dictionary, defender_cell: Dictionary, martial_art) -> bool:
	var distance = _cell_distance(attacker_cell, defender_cell)
	if distance <= 0 or distance > martial_art.tactical_range:
		return false
	match martial_art.tactical_range_shape:
		"diamond":
			return true
		"line", "pierce":
			return int(attacker_cell.get("q", 0)) == int(defender_cell.get("q", 0)) or int(attacker_cell.get("r", 0)) == int(defender_cell.get("r", 0))
		"fan":
			return true
		"surround":
			return max(abs(int(attacker_cell.get("q", 0)) - int(defender_cell.get("q", 0))), abs(int(attacker_cell.get("r", 0)) - int(defender_cell.get("r", 0)))) == 1
		"ring":
			return distance == martial_art.tactical_range
		"target_cross_1":
			return true
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

# Task 16: 写入 battle.log 的同时通过 EventBus 推送给 UI 战斗日志面板。
# 与 _emit_action_resolved 相同：通过 SceneTree.root 取 EventBus 节点，
# 离线工具脚本无 autoload 时静默跳过。
func _log(battle, msg: String) -> void:
	if battle != null:
		battle.append_log(msg)
	var loop = Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return
	var bus = (loop as SceneTree).root.get_node_or_null("EventBus")
	if bus == null:
		return
	bus.tactical_log_appended.emit(msg)
