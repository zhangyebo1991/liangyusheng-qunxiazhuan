extends RefCounted

const ActorStateScript = preload("res://scripts/domain/actor_state.gd")
const MartialArtRecordScript = preload("res://scripts/domain/martial_art_record.gd")
const CombatSystemScript = preload("res://scripts/systems/combat_system.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const SaveSystemScript = preload("res://scripts/systems/save_system.gd")

func run(assertions) -> void:
	var attacker = ActorStateScript.from_dictionary({
		"id": "hero_yun",
		"name": "云游少侠",
		"hp": 120,
		"max_hp": 120,
		"attack": 18,
		"defense": 8,
	})
	var defender = ActorStateScript.from_dictionary({
		"id": "bandit_01",
		"name": "山道强人",
		"hp": 20,
		"max_hp": 70,
		"attack": 12,
		"defense": 4,
	})
	var martial_art = MartialArtRecordScript.from_dictionary({
		"id": "basic_sword",
		"name": "基础剑法",
		"power": 12,
		"cost": 3,
		"proficiency_reward": 1,
	})
	var combat_system = CombatSystemScript.new()
	var result = combat_system.resolve_duel(attacker, defender, martial_art)
	assertions.assert_eq(result.damage, 26, "伤害应由攻击、武学威力和防御确定")
	assertions.assert_eq(result.winner_id, "hero_yun", "旧一次性结算在足以击败敌人时攻击者应获胜")
	assertions.assert_eq(result.loser_id, "bandit_01", "失败者编号应正确")

	var repository = DataRepositoryScript.new()
	repository.load_all()
	var configured_attacker = ActorStateScript.from_dictionary(repository.get_actor("hero_yun"))
	var configured_defender = ActorStateScript.from_dictionary(repository.get_actor("bandit_01"))
	var configured_martial_art = MartialArtRecordScript.from_dictionary(repository.get_martial_art("basic_sword"))
	var configured_result = combat_system.resolve_duel(configured_attacker, configured_defender, configured_martial_art)
	assertions.assert_eq(configured_result.damage, 26, "山道试剑配置仍应使用基础伤害公式")
	assertions.assert_eq(configured_result.winner_id, "bandit_01", "山道强人不应再被基础剑法一击击败")
	assertions.assert_eq(configured_martial_art.proficiency_reward, 1, "基础剑法应配置熟练度奖励")

	var game_state = GameStateScript.new()
	game_state.start_new_game()
	assertions.assert_eq(game_state.hero_max_mp, 20, "新游戏主角最大内力应为 20")
	game_state.quest_system.start_quest("quest_mountain_trial")
	game_state.apply_battle_result({
		"victory": true,
		"hero_hp": 44,
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
		"martial_art_id": "basic_sword",
		"proficiency_reward": 1,
	})
	assertions.assert_true(game_state.is_map_object_resolved("enemy_bandit_gate"), "胜利后强人触发点应被标记为已解决")
	assertions.assert_eq(game_state.quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "胜利后山道任务应进入可交付状态")
	assertions.assert_eq(game_state.hero_hp, 44, "胜利后应保存战斗剩余气血")
	assertions.assert_eq(game_state.get_martial_proficiency("basic_sword"), 1, "胜利后应增加基础剑法熟练度")

	var serialized_with_mp = game_state.to_dictionary()
	assertions.assert_eq(serialized_with_mp.get("hero_max_mp", 0), 20, "存档应保存主角最大内力")

	var restored_with_mp = GameStateScript.new()
	restored_with_mp.from_dictionary(serialized_with_mp)
	assertions.assert_eq(restored_with_mp.hero_max_mp, 20, "读档应恢复主角最大内力")

	var old_save_state = GameStateScript.new()
	old_save_state.from_dictionary({
		"party": game_state.party.to_dictionary(),
		"quests": game_state.quest_system.to_dictionary(),
		"map_state": game_state.map_state.to_dictionary(),
		"journal_state": game_state.journal_state.to_dictionary(),
		"flags": game_state.flags.duplicate(true),
		"hero_hp": 90,
		"hero_max_hp": 120,
		"martial_proficiency": {},
	})
	assertions.assert_eq(old_save_state.hero_max_mp, 20, "旧存档缺少最大内力时应使用默认值")
	restored_with_mp.free()
	old_save_state.free()

	var effect_state = GameStateScript.new()
	effect_state.start_new_game()
	effect_state.quest_system.start_quest("quest_mountain_trial")
	effect_state.apply_battle_result({
		"victory": true,
		"hero_hp": 50,
		"victory_effects": [
			{"type": "resolve_map_object", "object_id": "enemy_bandit_gate"},
			{"type": "set_quest_status", "quest_id": "quest_mountain_trial", "status": "ready_to_complete"},
			{"type": "add_martial_proficiency", "martial_art_id": "basic_sword", "amount": 2}
		]
	})
	assertions.assert_true(effect_state.is_map_object_resolved("enemy_bandit_gate"), "victory_effects 应标记强人触发点")
	assertions.assert_eq(effect_state.quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "victory_effects 应推进任务状态")
	assertions.assert_eq(effect_state.hero_hp, 50, "victory_effects 不应覆盖胜利后气血")
	assertions.assert_eq(effect_state.get_martial_proficiency("basic_sword"), 2, "victory_effects 应增加武学熟练度")
	effect_state.free()

	var failure_state = GameStateScript.new()
	failure_state.start_new_game()
	failure_state.quest_system.start_quest("quest_mountain_trial")
	failure_state.apply_battle_result({
		"victory": false,
		"hero_hp": 0,
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
		"martial_art_id": "basic_sword",
		"proficiency_reward": 1,
	})
	assertions.assert_true(not failure_state.is_map_object_resolved("enemy_bandit_gate"), "失败后不应清除强人触发点")
	assertions.assert_eq(failure_state.quest_system.get_status("quest_mountain_trial"), "active", "失败后任务应保持进行中")
	assertions.assert_eq(failure_state.hero_hp, 1, "失败后主角气血应钳制到安全值")
	assertions.assert_eq(failure_state.get_martial_proficiency("basic_sword"), 0, "失败后不应增加熟练度")
	assertions.assert_eq(failure_state.map_state.player_position, Vector2(160, 320), "失败后应回到山道入口")

	var tactical_state = GameStateScript.new()
	tactical_state.start_new_game()
	tactical_state.quest_system.start_quest("quest_mountain_trial")
	tactical_state.apply_battle_result({
		"victory": true,
		"hero_hp": 72,
		"source_map_id": "mountain_pass",
		"source_object_id": "enemy_bandit_gate",
		"quest_id": "quest_mountain_trial",
		"martial_art_id": "basic_sword",
		"proficiency_reward": 1,
		"log": ["敌人尽数败退。"]
	})
	assertions.assert_true(tactical_state.is_map_object_resolved("enemy_bandit_gate"), "战棋胜利后强人触发点应被标记为已解决")
	assertions.assert_eq(tactical_state.quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "战棋胜利后山道任务应进入可交付状态")
	assertions.assert_eq(tactical_state.hero_hp, 72, "战棋胜利后应保存主角剩余气血")
	assertions.assert_eq(tactical_state.get_martial_proficiency("basic_sword"), 1, "战棋胜利后应增加基础剑法熟练度")

	# 战斗结束携带 hero_final_mp 应回写到 hero_cur_mp
	var battle_end_state = GameStateScript.new()
	battle_end_state.start_new_game()
	battle_end_state.apply_battle_result({
		"victory": true,
		"hero_hp": 80,
		"hero_final_mp": 12,
	})
	assertions.assert_eq(battle_end_state.hero_cur_mp, 12, "胜利后 hero_cur_mp 应被回写为 12")
	battle_end_state.free()

	repository.free()
	game_state.free()
	failure_state.free()
	tactical_state.free()

	var save_system = SaveSystemScript.new()
	var state = {
		"party": {"members": ["hero_yun"]},
		"quests": {"quest_first_step": "completed"},
	}
	var save_payload = save_system.serialize_state(state)
	assertions.assert_eq(save_payload.get("version", 0), 1, "存档应带版本号")
	assertions.assert_eq(save_system.deserialize_state(save_payload).get("quests", {}).get("quest_first_step", ""), "completed", "存档应可反序列化")
