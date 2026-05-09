extends RefCounted

const ActorStateScript = preload("res://scripts/domain/actor_state.gd")
const ItemRecordScript = preload("res://scripts/domain/item_record.gd")
const MartialArtRecordScript = preload("res://scripts/domain/martial_art_record.gd")
const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const QuestRecordScript = preload("res://scripts/domain/quest_record.gd")

func run(assertions) -> void:
	var actor = ActorStateScript.from_dictionary({
		"id": "hero_yun",
		"name": "云游少侠",
		"level": 2,
		"hp": 80,
		"max_hp": 120,
		"attack": 18,
		"defense": 8,
		"martial_arts": ["basic_sword"],
	})
	assertions.assert_eq(actor.id, "hero_yun", "角色应保存编号")
	assertions.assert_true(actor.is_alive(), "气血大于 0 时角色应存活")
	assertions.assert_eq(actor.to_dictionary().get("name", ""), "云游少侠", "角色应能序列化")

	var item = ItemRecordScript.from_dictionary({
		"id": "herb_small",
		"name": "小还丹",
		"type": "consumable",
		"description": "恢复少量气血。",
		"value": 30,
		"effects": {"heal_hp": 30},
	})
	assertions.assert_eq(item.name, "小还丹", "物品应保存名称")
	assertions.assert_eq(item.effects.get("heal_hp", 0), 30, "物品应读取效果数据")

	var martial_art = MartialArtRecordScript.from_dictionary({
		"id": "basic_sword",
		"name": "基础剑法",
		"school": "江湖",
		"power": 12,
		"cost": 3,
		"description": "入门剑招，胜在稳妥。",
	})
	assertions.assert_eq(martial_art.power, 12, "武学应保存威力")

	var quest = QuestRecordScript.from_dictionary({
		"id": "quest_first_step",
		"title": "初入江湖",
		"description": "向青衫客请教江湖规矩。",
		"start_dialogue": "intro_meet_master",
		"reward_items": ["herb_small"],
	})
	assertions.assert_eq(quest.reward_items[0], "herb_small", "任务应保存奖励物品")

	var party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.add_member("hero_yun")
	party.add_item("herb_small", 2)
	assertions.assert_eq(party.members.size(), 1, "队伍不应重复加入同一角色")
	assertions.assert_eq(party.get_item_count("herb_small"), 2, "队伍背包应累计物品数量")
	assertions.assert_true(party.has_item("herb_small", 2), "背包应能判断足够数量")
	assertions.assert_true(party.remove_item("herb_small", 1), "背包应能扣除已有物品")
	assertions.assert_eq(party.get_item_count("herb_small"), 1, "扣除后数量应减少")
	assertions.assert_true(not party.remove_item("herb_small", 2), "数量不足时不应扣除物品")
	assertions.assert_eq(party.get_item_count("herb_small"), 1, "扣除失败后数量应保持")
	assertions.assert_true(party.remove_item("herb_small", 1), "应能扣除最后一个物品")
	assertions.assert_eq(party.get_item_count("herb_small"), 0, "数量归零后查询应为 0")
	assertions.assert_true(not party.inventory.has("herb_small"), "数量归零后应从背包字典移除")
