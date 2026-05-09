extends RefCounted

const ActorStateScript = preload("res://scripts/domain/actor_state.gd")
const MartialArtRecordScript = preload("res://scripts/domain/martial_art_record.gd")
const BattleStateScript = preload("res://scripts/domain/battle_state.gd")
const CombatResultScript = preload("res://scripts/domain/combat_result.gd")
const InventorySystemScript = preload("res://scripts/systems/inventory_system.gd")

var repository = null
var inventory_system = InventorySystemScript.new()

func set_repository(next_repository) -> void:
	repository = next_repository
	inventory_system.set_repository(next_repository)

func create_battle(game_state, context: Dictionary, data_source = null):
	var source = data_source if data_source != null else _get_repository()
	var battle = BattleStateScript.new()
	battle.hero_id = "hero_yun"
	battle.enemy_id = str(context.get("enemy_id", "bandit_01"))
	if battle.enemy_id.is_empty():
		battle.enemy_id = "bandit_01"
	battle.source_map_id = str(context.get("source_map_id", "mountain_pass"))
	if battle.source_map_id.is_empty():
		battle.source_map_id = "mountain_pass"
	battle.source_object_id = str(context.get("source_object_id", ""))
	battle.quest_id = str(context.get("quest_id", ""))

	if source == null:
		battle.hero_hp = max(1, int(game_state.hero_hp))
		battle.hero_max_hp = max(1, int(game_state.hero_max_hp))
		battle.enemy_hp = 1
		battle.enemy_max_hp = 1
		battle.append_log("敌人资料缺失。")
		return battle

	var hero_data = source.get_actor("hero_yun")
	var enemy_data = source.get_actor(battle.enemy_id)
	battle.hero_max_hp = max(1, int(game_state.hero_max_hp))
	battle.hero_hp = clamp(int(game_state.hero_hp), 0, battle.hero_max_hp)
	if battle.hero_hp <= 0:
		battle.hero_hp = 1
	if enemy_data.is_empty():
		battle.enemy_hp = 1
		battle.enemy_max_hp = 1
		battle.append_log("敌人资料缺失。")
	else:
		battle.enemy_hp = max(1, int(enemy_data.get("hp", 1)))
		battle.enemy_max_hp = max(1, int(enemy_data.get("max_hp", battle.enemy_hp)))
	if hero_data.is_empty():
		battle.append_log("主角资料缺失。")
	return battle

func resolve_player_attack(battle, game_state, martial_art_id: String) -> Dictionary:
	if battle == null:
		return {"success": false, "message": "战斗尚未准备好。"}
	if battle.is_finished:
		return {"success": false, "message": "战斗已经结束。"}

	var source = _get_repository()
	if source == null:
		battle.append_log("武学资料缺失。")
		return {"success": false, "message": "武学资料缺失。"}

	var hero = ActorStateScript.from_dictionary(source.get_actor("hero_yun"))
	var enemy = ActorStateScript.from_dictionary(source.get_actor(battle.enemy_id))
	var martial_art = MartialArtRecordScript.from_dictionary(source.get_martial_art(martial_art_id))
	if hero.id.is_empty():
		battle.append_log("主角资料缺失。")
		return {"success": false, "message": "主角资料缺失。"}
	if enemy.id.is_empty():
		battle.append_log("敌人资料缺失。")
		return {"success": false, "message": "敌人资料缺失。"}
	if martial_art.id.is_empty():
		battle.append_log("武学资料缺失。")
		return {"success": false, "message": "武学资料缺失。"}

	var damage = _calculate_martial_damage(hero, enemy, martial_art)
	battle.enemy_hp = max(0, battle.enemy_hp - damage)
	battle.append_log("第%d回合：%s使出%s，造成%d点伤害。" % [battle.round, hero.name, martial_art.name, damage])

	if battle.enemy_hp <= 0:
		battle.reward_martial_art_id = martial_art.id
		battle.proficiency_reward = max(0, martial_art.proficiency_reward)
		battle.append_log("%s被击败。" % enemy.name)
		if battle.proficiency_reward > 0:
			battle.append_log("%s熟练度提升。" % martial_art.name)
		battle.finish(true)
		_sync_hero_hp(game_state, battle)
		return {"success": true, "message": "战斗胜利。"}

	_enemy_counterattack(battle, game_state, enemy, hero)
	if not battle.is_finished:
		battle.round += 1
	return {"success": true, "message": "已经出招。"}

func resolve_player_item(battle, game_state, item_id: String) -> Dictionary:
	if battle == null:
		return {"success": false, "message": "战斗尚未准备好。"}
	if battle.is_finished:
		return {"success": false, "message": "战斗已经结束。"}

	var source = _get_repository()
	if source == null:
		battle.append_log("此物品资料缺失。")
		return {"success": false, "message": "此物品资料缺失。"}

	inventory_system.set_repository(source)
	game_state.hero_hp = battle.hero_hp
	var result = inventory_system.use_item(game_state, item_id)
	var message = str(result.get("message", "此物暂时不能使用。"))
	battle.append_log(message)
	if not bool(result.get("success", false)):
		return result

	battle.hero_hp = int(game_state.hero_hp)
	var hero = ActorStateScript.from_dictionary(source.get_actor("hero_yun"))
	var enemy = ActorStateScript.from_dictionary(source.get_actor(battle.enemy_id))
	_enemy_counterattack(battle, game_state, enemy, hero)
	if not battle.is_finished:
		battle.round += 1
	return result

func resolve_retreat(battle) -> Dictionary:
	if battle == null:
		return {"success": false, "message": "战斗尚未准备好。"}
	if not battle.is_finished:
		battle.hero_hp = max(1, battle.hero_hp)
		battle.append_log("暂退数步。")
		battle.finish(false)
	return {"success": true, "message": "暂退数步。"}

func resolve_duel(attacker, defender, martial_art):
	var result = CombatResultScript.new()
	var raw_damage = attacker.attack + martial_art.power - defender.defense
	result.damage = maxi(1, raw_damage)
	result.rounds = 1

	if result.damage >= defender.hp:
		result.winner_id = attacker.id
		result.loser_id = defender.id
		result.log.append("%s 使出%s，击败了%s。" % [attacker.name, martial_art.name, defender.name])
	else:
		result.winner_id = defender.id
		result.loser_id = attacker.id
		result.log.append("%s 使出%s，未能击败%s。" % [attacker.name, martial_art.name, defender.name])

	return result

func _enemy_counterattack(battle, game_state, enemy, hero) -> void:
	var damage = _calculate_basic_damage(enemy, hero)
	battle.hero_hp = max(0, battle.hero_hp - damage)
	battle.append_log("%s反击，造成%d点伤害。" % [enemy.name, damage])
	_sync_hero_hp(game_state, battle)
	if battle.hero_hp <= 0:
		battle.append_log("气血不支，暂退数步。")
		battle.finish(false)

func _calculate_martial_damage(attacker, defender, martial_art) -> int:
	return maxi(1, attacker.attack + martial_art.power - defender.defense)

func _calculate_basic_damage(attacker, defender) -> int:
	return maxi(1, attacker.attack - defender.defense)

func _sync_hero_hp(game_state, battle) -> void:
	if game_state != null:
		game_state.hero_hp = battle.hero_hp

func _get_repository():
	if repository != null:
		return repository
	var loop = Engine.get_main_loop()
	if loop == null or loop.root == null:
		return null
	if loop.root.has_node("DataRepository"):
		return loop.root.get_node("DataRepository")
	return null
