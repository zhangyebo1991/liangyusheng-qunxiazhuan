extends RefCounted

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")

func run(assertions) -> void:
	var party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.add_member("hero_yun")
	assertions.assert_eq(party.members.size(), 1, "重复 add_member 不应重复入队")

	party.set_member_status("hero_yun", {"hp": 90, "mp": 7})
	assertions.assert_eq(party.get_member_status("hero_yun").get("hp", 0), 90, "应保存成员 HP")
	assertions.assert_eq(party.get_member_status("hero_yun").get("mp", 0), 7, "应保存成员 MP")

	party.add_item("iron_sword", 1)
	party.set_equipment("hero_yun", "weapon", "iron_sword")
	assertions.assert_eq(party.get_equipped_item("hero_yun", "weapon"), "iron_sword", "应读取装备槽物品")
	assertions.assert_eq(party.count_equipped_item("iron_sword"), 1, "应统计装备占用数量")
	party.clear_equipment("hero_yun", "weapon")
	assertions.assert_eq(party.get_equipped_item("hero_yun", "weapon"), "", "卸下装备后槽位应为空")

	var data = party.to_dictionary()
	var restored = PartyStateScript.new()
	restored.from_dictionary(data)
	assertions.assert_eq(restored.get_member_status("hero_yun").get("hp", 0), 90, "成员状态应可序列化恢复")
	assertions.assert_eq(restored.get_equipped_item("hero_yun", "weapon"), "", "空装备槽不应恢复出旧装备")

	var old_save = PartyStateScript.new()
	old_save.from_dictionary({"members": ["hero_yun"], "inventory": {"herb_small": 1}, "coins": 5})
	assertions.assert_eq(old_save.equipment.size(), 0, "旧存档缺 equipment 时应默认为空")
	assertions.assert_eq(old_save.member_status.size(), 0, "旧存档缺 member_status 时应默认为空")

	var state = GameStateScript.new()
	state.start_new_game()
	assertions.assert_true(state.party.has_member("hero_yun"), "新游戏应包含主角")
	assertions.assert_eq(state.party.get_member_status("hero_yun").get("hp", 0), state.hero_hp, "新游戏应初始化主角成员 HP")
	assertions.assert_eq(state.party.get_member_status("hero_yun").get("mp", 0), state.hero_cur_mp, "新游戏应初始化主角成员 MP")
	state.free()