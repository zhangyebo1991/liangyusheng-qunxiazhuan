extends RefCounted

const PartyPanelScript = preload("res://scripts/scenes/party_panel.gd")
const PartyStateScript = preload("res://scripts/domain/party_state.gd")

class RepositoryStub:
	extends RefCounted

	func get_actor(actor_id: String) -> Dictionary:
		if actor_id == "hero_yun":
			return {"id": "hero_yun", "name": "云游少侠", "hp": 120, "max_hp": 120, "max_mp": 20, "attack": 18, "defense": 8, "martial_arts": ["basic_sword"], "growth": {"exp_curve": [0, 30, 80], "per_level": {"max_hp": 8, "max_mp": 2, "attack": 1, "defense": 1}}}
		if actor_id == "qingshanke":
			return {"id": "qingshanke", "name": "青衫客", "hp": 150, "max_hp": 150, "max_mp": 18, "attack": 16, "defense": 10, "martial_arts": ["basic_sword"]}
		if actor_id == "porter_chen":
			return {"id": "porter_chen", "name": "陈脚夫", "hp": 100, "max_hp": 100, "max_mp": 10, "attack": 10, "defense": 6, "martial_arts": []}
		return {}

	func get_item(item_id: String) -> Dictionary:
		if item_id == "iron_sword":
			return {"id": "iron_sword", "name": "铁剑", "type": "equipment", "equipment": {"slot": "weapon", "stat_bonus": {"attack": 4}}}
		return {}

func run(assertions) -> void:
	var party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.add_member("qingshanke")
	party.add_member("porter_chen")
	party.set_formation_order(["hero_yun", "qingshanke", "porter_chen"])
	party.add_item("iron_sword", 1)
	party.set_member_status("hero_yun", {"hp": 100, "mp": 12, "level": 2, "exp": 5, "total_exp": 35})

	var panel = PartyPanelScript.new()
	panel.set_party_context(party, RepositoryStub.new())
	assertions.assert_true(panel.has_method("refresh"), "PartyPanel 应提供 refresh 方法")
	panel.refresh()
	assertions.assert_eq(panel.selected_actor_id, "hero_yun", "刷新后应默认选中第一个队友")
	assertions.assert_true(panel.member_buttons.size() >= 1, "应生成队友按钮")
	assertions.assert_true(panel._formation_list != null, "应生成默认出战顺序列表")
	assertions.assert_true(_node_text_has(panel._formation_list, "默认出战顺序"), "队伍面板应显示默认出战顺序标题")
	assertions.assert_true(_node_text_has(panel._formation_list, "云游少侠"), "编队列表应显示主角中文名")
	assertions.assert_true(_node_text_has(panel._formation_list, "必出战"), "主角行应标记必出战")
	assertions.assert_true(_node_text_has(panel._formation_list, "青衫客"), "编队列表应显示队友中文名")
	assertions.assert_false(_node_text_has(panel._formation_list, "qingshanke"), "编队列表不应显示内部角色编号")
	var qing_buttons = _formation_buttons_for_name(panel._formation_list, "青衫客")
	assertions.assert_eq(qing_buttons.size(), 2, "青衫客行应生成上移和下移按钮")
	assertions.assert_true(qing_buttons[0].disabled, "紧挨主角的队友上移按钮应禁用")
	assertions.assert_false(qing_buttons[1].disabled, "非队尾队友下移按钮应可用")
	var porter_buttons = _formation_buttons_for_name(panel._formation_list, "陈脚夫")
	assertions.assert_eq(porter_buttons.size(), 2, "队尾队友行应生成上移和下移按钮")
	assertions.assert_false(porter_buttons[0].disabled, "队尾队友上移按钮应可用")
	assertions.assert_true(porter_buttons[1].disabled, "队尾队友下移按钮应禁用")
	panel._move_formation_member("porter_chen", -1)
	assertions.assert_eq(party.get_formation_order(), ["hero_yun", "porter_chen", "qingshanke"], "点击上移后应调整默认出战顺序")
	panel._move_formation_member("porter_chen", -1)
	assertions.assert_eq(party.get_formation_order(), ["hero_yun", "porter_chen", "qingshanke"], "队友不应移动到主角之前")
	assertions.assert_true(panel._equipment_list.get_child_count() >= 1, "应生成可装备物品行")
	assertions.assert_true(panel._detail_label.text.find("等级 2") >= 0, "队伍面板应显示等级")
	assertions.assert_true(panel._detail_label.text.find("本级经验 5/50") >= 0, "队伍面板应显示本级经验进度")
	assertions.assert_true(panel._detail_label.text.find("累计 35") >= 0, "队伍面板应显示累计经验")

	var equipment_row = panel._equipment_list.get_child(0)
	var equip_button = equipment_row.get_child(1)
	equip_button.pressed.emit()
	assertions.assert_eq(party.get_equipped_item("hero_yun", "weapon"), "iron_sword", "点击装备按钮应写入 PartyState")

	party.clear_equipment("hero_yun", "weapon")
	var result = panel.equip_selected("iron_sword")
	assertions.assert_true(bool(result.get("success", false)), "面板应能给选中角色装备铁剑")
	assertions.assert_eq(party.get_equipped_item("hero_yun", "weapon"), "iron_sword", "装备结果应写入 PartyState")
	assertions.assert_true(panel._detail_label.text.find("等级 2") >= 0, "装备刷新后仍应显示等级")
	panel.free()

func _node_text_has(node, expected: String) -> bool:
	if node == null:
		return false
	if node is Label and (node as Label).text.find(expected) >= 0:
		return true
	if node is Button and (node as Button).text.find(expected) >= 0:
		return true
	for child in node.get_children():
		if _node_text_has(child, expected):
			return true
	return false

func _formation_buttons_for_name(list, actor_name: String) -> Array:
	for child in list.get_children():
		if not (child is HBoxContainer) or child.get_child_count() < 3:
			continue
		var name_label = child.get_child(0)
		if name_label is Label and name_label.text == actor_name:
			return [child.get_child(1), child.get_child(2)]
	return []