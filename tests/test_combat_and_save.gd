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
	repository.free()
	game_state.free()
	failure_state.free()

	var save_system = SaveSystemScript.new()
	var state = {
		"party": {"members": ["hero_yun"]},
		"quests": {"quest_first_step": "completed"},
	}
	var save_payload = save_system.serialize_state(state)
	assertions.assert_eq(save_payload.get("version", 0), 1, "存档应带版本号")
	assertions.assert_eq(save_system.deserialize_state(save_payload).get("quests", {}).get("quest_first_step", ""), "completed", "存档应可反序列化")
