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
		"proficiency_reward": 1,
		"tactical": {
			"damage_bonus": 6,
			"range": 1,
			"range_shape": "diamond",
			"mp_cost": 3,
		},
	})
	assertions.assert_eq(martial_art.power, 12, "武学应保存威力")
	assertions.assert_eq(martial_art.proficiency_reward, 1, "武学应保存熟练度奖励")
	assertions.assert_true(martial_art.has_tactical_config(), "武学应识别战棋配置")
	assertions.assert_eq(martial_art.tactical_damage_bonus, 6, "武学应读取战棋伤害加值")
	assertions.assert_eq(martial_art.tactical_range, 1, "武学应读取战棋范围")
	assertions.assert_eq(martial_art.tactical_range_shape, "diamond", "武学应读取战棋范围形状")
	assertions.assert_eq(martial_art.tactical_mp_cost, 3, "武学应读取战棋内力消耗")

	var fallback_cost_art = MartialArtRecordScript.from_dictionary({
		"id": "fallback_cost",
		"name": "旧式招式",
		"cost": 4,
		"tactical": {"damage_bonus": 2, "range": 1, "range_shape": "diamond"},
	})
	assertions.assert_eq(fallback_cost_art.tactical_mp_cost, 4, "缺少 mp_cost 时应回退到 cost")

	var plain_art = MartialArtRecordScript.from_dictionary({
		"id": "plain_art",
		"name": "普通武学",
		"cost": 2,
	})
	assertions.assert_true(not plain_art.has_tactical_config(), "缺少 tactical 时不应视为战棋招式")

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

	assertions.assert_eq(party.coins, 0, "队伍默认铜钱应为 0")
	assertions.assert_true(not party.can_afford(0), "金额为 0 时不应视为可支付")
	assertions.assert_true(not party.can_afford(-1), "负数金额不应视为可支付")
	party.add_coins(80)
	party.add_coins(0)
	party.add_coins(-10)
	assertions.assert_eq(party.coins, 80, "队伍应能增加有效铜钱")
	assertions.assert_true(party.can_afford(30), "余额足够时应可支付")
	assertions.assert_true(party.spend_coins(30), "余额足够时应能扣钱")
	assertions.assert_eq(party.coins, 50, "扣钱后余额应减少")
	assertions.assert_true(not party.spend_coins(100), "余额不足时扣钱应失败")
	assertions.assert_eq(party.coins, 50, "扣钱失败后余额应保持")

	var serialized_party = party.to_dictionary()
	assertions.assert_eq(serialized_party.get("coins", -1), 50, "队伍序列化应保存铜钱")

	var restored_party = PartyStateScript.new()
	restored_party.from_dictionary(serialized_party)
	assertions.assert_eq(restored_party.coins, 50, "队伍反序列化应恢复铜钱")

	var old_save_party = PartyStateScript.new()
	old_save_party.from_dictionary({"members": ["hero_yun"], "inventory": {"herb_small": 1}})
	assertions.assert_eq(old_save_party.coins, 0, "旧存档缺少铜钱时应为 0")

	var invalid_coin_party = PartyStateScript.new()
	invalid_coin_party.from_dictionary({"members": ["hero_yun"], "inventory": {}, "coins": -5})
	assertions.assert_eq(invalid_coin_party.coins, 0, "读档铜钱小于 0 时应钳制")
