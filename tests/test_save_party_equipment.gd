extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")

func run(assertions) -> void:
	var state = GameStateScript.new()
	state.start_new_game()
	state.party.add_member("qingshanke")
	state.party.add_item("iron_sword", 1)
	state.party.set_equipment("hero_yun", "weapon", "iron_sword")
	state.party.set_member_status("qingshanke", {"hp": 160, "mp": 9})

	state.apply_battle_result({
		"victory": true,
		"party_member_results": {
			"hero_yun": {"hp": 88, "mp": 6},
			"qingshanke": {"hp": 120, "mp": 3},
		}
	})
	assertions.assert_eq(state.party.get_member_status("hero_yun").get("hp", 0), 88, "战斗结果应回写主角成员 HP")
	assertions.assert_eq(state.party.get_member_status("qingshanke").get("mp", 0), 3, "战斗结果应回写队友 MP")
	assertions.assert_eq(state.hero_hp, 88, "主角旧字段 hero_hp 应同步")
	assertions.assert_eq(state.hero_cur_mp, 6, "主角旧字段 hero_cur_mp 应同步")

	var data = state.to_dictionary()
	var restored = GameStateScript.new()
	restored.from_dictionary(data)
	assertions.assert_true(restored.party.has_member("qingshanke"), "存档应恢复队友")
	assertions.assert_eq(restored.party.get_equipped_item("hero_yun", "weapon"), "iron_sword", "存档应恢复装备")
	assertions.assert_eq(restored.party.get_member_status("qingshanke").get("hp", 0), 120, "存档应恢复队友 HP")
	state.free()
	restored.free()