extends RefCounted

const PartyPanelScript = preload("res://scripts/scenes/party_panel.gd")
const PartyStateScript = preload("res://scripts/domain/party_state.gd")

class RepositoryStub:
	extends RefCounted

	func get_actor(actor_id: String) -> Dictionary:
		if actor_id == "hero_yun":
			return {"id": "hero_yun", "name": "云游少侠", "hp": 120, "max_hp": 120, "max_mp": 20, "attack": 18, "defense": 8, "martial_arts": ["basic_sword"]}
		return {}

	func get_item(item_id: String) -> Dictionary:
		if item_id == "iron_sword":
			return {"id": "iron_sword", "name": "铁剑", "type": "equipment", "equipment": {"slot": "weapon", "stat_bonus": {"attack": 4}}}
		return {}

func run(assertions) -> void:
	var party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.add_item("iron_sword", 1)
	party.set_member_status("hero_yun", {"hp": 100, "mp": 12})

	var panel = PartyPanelScript.new()
	panel.set_party_context(party, RepositoryStub.new())
	assertions.assert_true(panel.has_method("refresh"), "PartyPanel 应提供 refresh 方法")
	panel.refresh()
	assertions.assert_eq(panel.selected_actor_id, "hero_yun", "刷新后应默认选中第一个队友")
	assertions.assert_true(panel.member_buttons.size() >= 1, "应生成队友按钮")

	var result = panel.equip_selected("iron_sword")
	assertions.assert_true(bool(result.get("success", false)), "面板应能给选中角色装备铁剑")
	assertions.assert_eq(party.get_equipped_item("hero_yun", "weapon"), "iron_sword", "装备结果应写入 PartyState")
	panel.free()