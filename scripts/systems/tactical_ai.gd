class_name TacticalAI
extends RefCounted

const TacticalBattleStateScript = preload("res://scripts/domain/tactical_battle_state.gd")

var repository = null
var combat_system = null

func set_repository(next_repository) -> void:
	repository = next_repository

func set_combat_system(next_combat_system) -> void:
	combat_system = next_combat_system

# 返回单位的最优行动: { "move_to": Dictionary, "use_skill": String, "target": Vector2i }
func evaluate(unit, battle) -> Dictionary:
	if unit == null or battle == null:
		return {"success": false, "message": "无效单位或战斗状态"}
	var enemies = battle.get_living_units_by_team(TacticalBattleStateScript.TEAM_ENEMY)
	if enemies.is_empty():
		return {"success": false, "message": "无敌人"}
	var movable_cells = _get_movable_cells(battle, unit)
	var available_skills = get_available_skills(unit)
	var best_action = {
		"move_to": unit.cell.duplicate(true),
		"use_skill": "",
		"target": Vector2i.ZERO,
		"target_cells": [],
		"targets_hit": 0,
		"damage": 0
	}
	for cell in movable_cells:
		var cell_v = Vector2i(int(cell.get("q", 0)), int(cell.get("r", 0)))
		var attack_plan = _best_target_for_action("attack", cell, cell_v, enemies, battle, unit)
		var attack_targets = int(attack_plan.get("targets_hit", 0))
		var attack_damage = unit.attack
		if attack_targets > best_action.get("targets_hit", 0) or \
			(attack_targets == best_action.get("targets_hit", 0) and attack_damage > best_action.get("damage", 0)):
			best_action = {
				"move_to": cell.duplicate(true),
				"use_skill": "attack",
				"target": attack_plan.get("target", Vector2i.ZERO),
				"target_cells": attack_plan.get("target_cells", []),
				"targets_hit": attack_targets,
				"damage": attack_damage
			}
		for skill_id in available_skills:
			var skill_plan = _best_target_for_action(skill_id, cell, cell_v, enemies, battle, unit)
			var skill_targets = int(skill_plan.get("targets_hit", 0))
			var skill_damage = _calculate_skill_damage(unit, skill_id)
			if skill_targets > best_action.get("targets_hit", 0) or \
				(skill_targets == best_action.get("targets_hit", 0) and skill_damage > best_action.get("damage", 0)):
				best_action = {
					"move_to": cell.duplicate(true),
					"use_skill": skill_id,
					"target": skill_plan.get("target", Vector2i.ZERO),
					"target_cells": skill_plan.get("target_cells", []),
					"targets_hit": skill_targets,
					"damage": skill_damage
				}
	if best_action.get("targets_hit", 0) == 0:
		var nearest_enemy = _find_nearest_enemy(unit, enemies)
		if nearest_enemy != null:
			var best_move = _find_closest_cell(movable_cells, nearest_enemy.cell)
			best_action = {
				"move_to": best_move.duplicate(true),
				"use_skill": "attack",
				"target": Vector2i(int(nearest_enemy.cell.get("q", 0)), int(nearest_enemy.cell.get("r", 0))),
				"target_cells": [Vector2i(int(nearest_enemy.cell.get("q", 0)), int(nearest_enemy.cell.get("r", 0)))],
				"targets_hit": 0,
				"damage": 0
			}
	best_action["success"] = true
	return best_action

# 获取单位可用技能（过滤 MP 不足的）
func get_available_skills(unit) -> Array[String]:
	var result: Array[String] = []
	if unit == null or repository == null:
		return result
	for skill_id in unit.martial_art_ids:
		var skill_data = repository.get_martial_art(skill_id)
		if skill_data.is_empty():
			continue
		var tactical = skill_data.get("tactical", {})
		if typeof(tactical) != TYPE_DICTIONARY:
			continue
		var mp_cost = int(tactical.get("mp_cost", skill_data.get("mp_cost", 0)))
		if unit.mp >= mp_cost:
			result.append(skill_id)
	return result

# 计算某位置下某技能能覆盖的敌人数量
func count_targets_from_position(skill_id: String, position: Vector2i, enemies: Array, battle) -> int:
	if skill_id.is_empty() or enemies.is_empty():
		return 0
	if combat_system != null:
		var position_cell := {"q": position.x, "r": position.y}
		var unit = _find_unit_at_position(battle, position)
		if unit != null:
			var best_plan = _best_target_for_action(skill_id, position_cell, position, enemies, battle, unit)
			return int(best_plan.get("targets_hit", 0))
	return _count_targets_from_position_legacy(skill_id, position, enemies, battle)

func _count_targets_from_position_legacy(skill_id: String, position: Vector2i, enemies: Array, battle) -> int:
	var skill_data = repository.get_martial_art(skill_id) if repository != null else {}
	if skill_data.is_empty():
		return 0
	var tactical = skill_data.get("tactical", {})
	if typeof(tactical) != TYPE_DICTIONARY:
		return 0
	var shape = str(tactical.get("range_shape", ""))
	var range_val = max(1, int(tactical.get("range", 1)))
	var count = 0
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var enemy_cell = Vector2i(int(enemy.cell.get("q", 0)), int(enemy.cell.get("r", 0)))
		var distance = abs(position.x - enemy_cell.x) + abs(position.y - enemy_cell.y)
		if distance <= 0 or distance > range_val:
			continue
		match shape:
			"diamond":
				count += 1
			"line":
				if position.x == enemy_cell.x or position.y == enemy_cell.y:
					count += 1
			"surround":
				if max(abs(position.x - enemy_cell.x), abs(position.y - enemy_cell.y)) == 1:
					count += 1
			"fan":
				for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var delta = enemy_cell - position
					var projection = delta.x * direction.x + delta.y * direction.y
					if projection > 0:
						var cross = abs(delta.x * direction.y - delta.y * direction.x)
						if cross <= projection * 2:
							count += 1
							break
			"ring":
				if distance == range_val:
					count += 1
			"pierce":
				if position.x == enemy_cell.x or position.y == enemy_cell.y:
					count += 1
			"target_cross_1":
				if distance <= 1:
					count += 1
	return count

func _get_movable_cells(battle, unit) -> Array:
	if combat_system != null:
		return combat_system.get_movable_cells(battle, str(unit.unit_id))
	var result: Array = []
	for q in range(battle.battlefield_width):
		for r in range(battle.battlefield_height):
			var cell = {"q": q, "r": r}
			var distance = abs(int(unit.cell.get("q", 0)) - q) + abs(int(unit.cell.get("r", 0)) - r)
			if distance > unit.move_range:
				continue
			if _is_cell_occupied_by_other(battle, cell, unit.unit_id):
				continue
			result.append(cell)
	return result

func _is_cell_occupied_by_other(battle, cell: Dictionary, unit_id: String) -> bool:
	for unit in battle.units:
		if unit.unit_id == unit_id:
			continue
		if unit.is_alive() and int(unit.cell.get("q", 0)) == int(cell.get("q", 0)) and int(unit.cell.get("r", 0)) == int(cell.get("r", 0)):
			return true
	return false

func _count_attack_targets(position: Vector2i, enemies: Array, unit) -> int:
	var count = 0
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var enemy_cell = Vector2i(int(enemy.cell.get("q", 0)), int(enemy.cell.get("r", 0)))
		var distance = abs(position.x - enemy_cell.x) + abs(position.y - enemy_cell.y)
		if distance <= unit.attack_range:
			count += 1
	return count

func _find_best_target(position: Vector2i, enemies: Array, unit) -> Vector2i:
	var best_target = Vector2i.ZERO
	var best_distance = 999999
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var enemy_cell = Vector2i(int(enemy.cell.get("q", 0)), int(enemy.cell.get("r", 0)))
		var distance = abs(position.x - enemy_cell.x) + abs(position.y - enemy_cell.y)
		if distance <= unit.attack_range and distance < best_distance:
			best_target = enemy_cell
			best_distance = distance
	return best_target

func _calculate_skill_damage(unit, skill_id: String) -> int:
	if repository == null:
		return 0
	var skill_data = repository.get_martial_art(skill_id)
	if skill_data.is_empty():
		return 0
	var tactical = skill_data.get("tactical", {})
	var damage_bonus = int(tactical.get("damage_bonus", 0))
	return unit.attack + damage_bonus

func _find_best_skill_target(position: Vector2i, enemies: Array, skill_id: String, battle) -> Vector2i:
	var skill_data = repository.get_martial_art(skill_id) if repository != null else {}
	if skill_data.is_empty():
		return Vector2i.ZERO
	var tactical = skill_data.get("tactical", {})
	var shape = str(tactical.get("range_shape", ""))
	var range_val = max(1, int(tactical.get("range", 1)))
	var best_target = Vector2i.ZERO
	var best_count = 0
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var enemy_cell = Vector2i(int(enemy.cell.get("q", 0)), int(enemy.cell.get("r", 0)))
		var distance = abs(position.x - enemy_cell.x) + abs(position.y - enemy_cell.y)
		if distance > range_val:
			continue
		var count = count_targets_from_position(skill_id, position, enemies, battle)
		if count > best_count:
			best_target = enemy_cell
			best_count = count
	return best_target

func _best_target_for_action(action_id: String, position_cell: Dictionary, position: Vector2i, enemies: Array, battle, unit) -> Dictionary:
	var best_target := Vector2i.ZERO
	var best_cells: Array = []
	var best_count := 0
	var unit_id := str(unit.unit_id) if unit != null else ""
	var attacker_team := str(unit.team) if unit != null else TacticalBattleStateScript.TEAM_PLAYER
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var enemy_cell := Vector2i(int(enemy.cell.get("q", 0)), int(enemy.cell.get("r", 0)))
		var target_cells: Array = []
		var valid := true
		if combat_system != null and not unit_id.is_empty():
			target_cells = combat_system.build_target_cells_for_action_from_cell(battle, position_cell, action_id, enemy_cell)
			valid = combat_system.is_action_target_valid_from_cell(battle, unit_id, position_cell, action_id, target_cells)
		else:
			target_cells = [enemy_cell]
			if action_id == "attack":
				var distance: int = abs(position.x - enemy_cell.x) + abs(position.y - enemy_cell.y)
				valid = unit != null and distance > 0 and distance <= int(unit.attack_range)
			else:
				valid = _count_targets_from_position_legacy(action_id, position, [enemy], battle) > 0
		if not valid:
			continue
		var hit_count := _count_enemy_hits_for_cells(battle, attacker_team, target_cells)
		if hit_count > best_count:
			best_count = hit_count
			best_target = enemy_cell
			best_cells = target_cells
	return {
		"target": best_target,
		"target_cells": best_cells,
		"targets_hit": best_count,
	}

func _count_enemy_hits_for_cells(battle, attacker_team: String, target_cells: Array) -> int:
	if combat_system != null:
		return combat_system.count_enemy_hits_in_cells(battle, attacker_team, target_cells)
	var hits := {}
	for cell_v in target_cells:
		if typeof(cell_v) != TYPE_VECTOR2I:
			continue
		for unit in battle.units:
			if not unit.is_alive() or unit.team == attacker_team:
				continue
			if int(unit.cell.get("q", 0)) == cell_v.x and int(unit.cell.get("r", 0)) == cell_v.y:
				hits[str(unit.unit_id)] = true
	return hits.size()

func _find_unit_at_position(battle, position: Vector2i):
	if battle == null:
		return null
	for unit in battle.units:
		if int(unit.cell.get("q", 0)) == position.x and int(unit.cell.get("r", 0)) == position.y:
			return unit
	return null

func _find_nearest_enemy(unit, enemies: Array):
	var nearest = null
	var nearest_distance = 999999
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var distance = abs(int(unit.cell.get("q", 0)) - int(enemy.cell.get("q", 0))) + abs(int(unit.cell.get("r", 0)) - int(enemy.cell.get("r", 0)))
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest

func _find_closest_cell(cells: Array, target_cell: Dictionary) -> Dictionary:
	if cells.is_empty():
		return {"q": 0, "r": 0}
	var best_cell = cells[0]
	var best_distance = 999999
	for cell in cells:
		var distance = abs(int(cell.get("q", 0)) - int(target_cell.get("q", 0))) + abs(int(cell.get("r", 0)) - int(target_cell.get("r", 0)))
		if distance < best_distance:
			best_cell = cell
			best_distance = distance
	return best_cell
