extends RefCounted

const ActorStateScript = preload("res://scripts/domain/actor_state.gd")
const MartialArtRecordScript = preload("res://scripts/domain/martial_art_record.gd")
const CombatSystemScript = preload("res://scripts/systems/combat_system.gd")
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
	})
	var combat_system = CombatSystemScript.new()
	var result = combat_system.resolve_duel(attacker, defender, martial_art)
	assertions.assert_eq(result.damage, 26, "伤害应由攻击、武学威力和防御确定")
	assertions.assert_eq(result.winner_id, "hero_yun", "足以击败敌人时攻击者应获胜")
	assertions.assert_eq(result.loser_id, "bandit_01", "失败者编号应正确")

	var save_system = SaveSystemScript.new()
	var state = {
		"party": {"members": ["hero_yun"]},
		"quests": {"quest_first_step": "completed"},
	}
	var payload = save_system.serialize_state(state)
	assertions.assert_eq(payload.get("version", 0), 1, "存档应带版本号")
	assertions.assert_eq(save_system.deserialize_state(payload).get("quests", {}).get("quest_first_step", ""), "completed", "存档应可反序列化")
