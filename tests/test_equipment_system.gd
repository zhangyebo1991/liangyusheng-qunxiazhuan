extends RefCounted

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const EquipmentSystemScript = preload("res://scripts/systems/equipment_system.gd")

class RepositoryStub:
	extends RefCounted
	var items: Dictionary = {
		"iron_sword": {"id": "iron_sword", "type": "equipment", "equipment": {"slot": "weapon", "stat_bonus": {"attack": 4}}},
		"cloth_armor": {"id": "cloth_armor", "type": "equipment", "equipment": {"slot": "armor", "stat_bonus": {"defense": 2}}},
		"herb_small": {"id": "herb_small", "type": "consumable", "effects": {"heal_hp": 30}}
	}

	func get_item(item_id: String) -> Dictionary:
		return items.get(item_id, {})

func run(assertions) -> void:
	var party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.add_member("qingshanke")
	party.add_item("iron_sword", 1)
	party.add_item("cloth_armor", 1)
	party.add_item("herb_small", 1)

	var equipment = EquipmentSystemScript.new()
	var repo = RepositoryStub.new()

	var missing_actor = equipment.equip(party, "missing", "iron_sword", repo)
	assertions.assert_true(not bool(missing_actor.get("success", true)), "不能给非队伍成员装备")

	var consumable = equipment.equip(party, "hero_yun", "herb_small", repo)
	assertions.assert_true(not bool(consumable.get("success", true)), "消耗品不能装备")

	var equip_result = equipment.equip(party, "hero_yun", "iron_sword", repo)
	assertions.assert_true(bool(equip_result.get("success", false)), "主角应能装备铁剑")
	assertions.assert_eq(party.get_equipped_item("hero_yun", "weapon"), "iron_sword", "武器槽应记录铁剑")

	var occupied = equipment.equip(party, "qingshanke", "iron_sword", repo)
	assertions.assert_true(not bool(occupied.get("success", true)), "一把铁剑不能同时给两人装备")
	assertions.assert_eq(str(occupied.get("message", "")), "装备数量不足。", "数量不足应返回中文提示")

	var bonus = equipment.get_equipment_bonus(party, "hero_yun", repo)
	assertions.assert_eq(int(bonus.get("attack", 0)), 4, "铁剑应提供 attack +4")

	var armor = equipment.equip(party, "qingshanke", "cloth_armor", repo)
	assertions.assert_true(bool(armor.get("success", false)), "青衫客应能装备布衣")
	assertions.assert_eq(int(equipment.get_equipment_bonus(party, "qingshanke", repo).get("defense", 0)), 2, "布衣应提供 defense +2")

	var unequip = equipment.unequip(party, "hero_yun", "weapon")
	assertions.assert_true(bool(unequip.get("success", false)), "卸下武器应成功")
	assertions.assert_eq(party.get_equipped_item("hero_yun", "weapon"), "", "卸下后武器槽为空")