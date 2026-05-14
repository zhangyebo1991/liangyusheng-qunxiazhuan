extends PanelContainer

const EquipmentSystemScript = preload("res://scripts/systems/equipment_system.gd")
const ActorStatsSystemScript = preload("res://scripts/systems/actor_stats_system.gd")

var party = null
var repository = null
var selected_actor_id: String = ""
var member_buttons: Array[Button] = []

var _equipment_system = EquipmentSystemScript.new()
var _stats_system = ActorStatsSystemScript.new()
var _root_box: VBoxContainer
var _member_list: VBoxContainer
var _detail_label: Label
var _equipment_list: VBoxContainer

func _ready() -> void:
	_build_ui()

func set_party_context(next_party, next_repository) -> void:
	party = next_party
	repository = next_repository
	refresh()

func refresh() -> void:
	if _root_box == null:
		_build_ui()
	_clear_member_buttons()
	_clear_equipment_rows()
	if party == null:
		_detail_label.text = "队伍状态缺失。"
		return
	for actor_id in party.members:
		var button = Button.new()
		button.text = _actor_name(str(actor_id))
		button.custom_minimum_size = Vector2(120, 32)
		button.pressed.connect(func(): _select_actor(str(actor_id)))
		member_buttons.append(button)
		_member_list.add_child(button)
	if selected_actor_id.is_empty() and not party.members.is_empty():
		selected_actor_id = str(party.members[0])
	_refresh_detail()
	_refresh_equipment_rows()

func equip_selected(item_id: String) -> Dictionary:
	if selected_actor_id.is_empty():
		return {"success": false, "message": "未选择队友。"}
	var result = _equipment_system.equip(party, selected_actor_id, item_id, repository)
	_refresh_detail()
	_refresh_equipment_rows()
	return result

func _build_ui() -> void:
	if _root_box != null:
		return
	name = "PartyPanel"
	position = Vector2(220, 72)
	size = Vector2(520, 520)
	custom_minimum_size = Vector2(520, 520)

	_root_box = VBoxContainer.new()
	_root_box.position = Vector2(16, 16)
	_root_box.size = Vector2(488, 488)
	add_child(_root_box)

	var title = Label.new()
	title.text = "队伍"
	title.custom_minimum_size = Vector2(460, 28)
	_root_box.add_child(title)

	_member_list = VBoxContainer.new()
	_member_list.custom_minimum_size = Vector2(460, 96)
	_root_box.add_child(_member_list)

	_detail_label = Label.new()
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size = Vector2(460, 160)
	_root_box.add_child(_detail_label)

	var equipment_title = Label.new()
	equipment_title.text = "可装备物品"
	equipment_title.custom_minimum_size = Vector2(460, 28)
	_root_box.add_child(equipment_title)

	_equipment_list = VBoxContainer.new()
	_equipment_list.custom_minimum_size = Vector2(460, 160)
	_root_box.add_child(_equipment_list)

func _clear_member_buttons() -> void:
	for button in member_buttons:
		if is_instance_valid(button):
			if button.get_parent() != null:
				button.get_parent().remove_child(button)
			button.queue_free()
	member_buttons.clear()

func _clear_equipment_rows() -> void:
	if _equipment_list == null:
		return
	for child in _equipment_list.get_children():
		_equipment_list.remove_child(child)
		child.queue_free()

func _select_actor(actor_id: String) -> void:
	selected_actor_id = actor_id
	_refresh_detail()
	_refresh_equipment_rows()

func _refresh_detail() -> void:
	if _detail_label == null:
		return
	if selected_actor_id.is_empty():
		_detail_label.text = "未选择队友。"
		return
	var stats = _stats_system.build_stats(party, selected_actor_id, repository)
	_detail_label.text = "%s\n气血 %d/%d  内力 %d/%d\n攻击 %d  防御 %d\n武器：%s\n衣甲：%s\n饰品：%s" % [
		str(stats.get("display_name", selected_actor_id)),
		int(stats.get("hp", 0)),
		int(stats.get("max_hp", 0)),
		int(stats.get("mp", 0)),
		int(stats.get("max_mp", 0)),
		int(stats.get("attack", 0)),
		int(stats.get("defense", 0)),
		_equipped_name("weapon"),
		_equipped_name("armor"),
		_equipped_name("accessory"),
	]

func _refresh_equipment_rows() -> void:
	_clear_equipment_rows()
	if party == null or _equipment_list == null:
		return
	var has_equipment := false
	for raw_item_id in party.inventory.keys():
		var item_id = str(raw_item_id)
		var item = repository.get_item(item_id) if repository != null and repository.has_method("get_item") else {}
		if typeof(item) != TYPE_DICTIONARY or str(item.get("type", "")) != "equipment":
			continue
		has_equipment = true
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(460, 36)
		_equipment_list.add_child(row)

		var label = Label.new()
		label.text = "%s x%d" % [str(item.get("name", item_id)), party.get_item_count(item_id)]
		label.custom_minimum_size = Vector2(300, 32)
		row.add_child(label)

		var button = Button.new()
		button.text = "装备"
		button.custom_minimum_size = Vector2(72, 32)
		button.pressed.connect(func(): equip_selected(item_id))
		row.add_child(button)
	if not has_equipment:
		var empty = Label.new()
		empty.text = "暂无可装备物品。"
		empty.custom_minimum_size = Vector2(460, 32)
		_equipment_list.add_child(empty)

func _actor_name(actor_id: String) -> String:
	if repository != null and repository.has_method("get_actor"):
		var actor = repository.get_actor(actor_id)
		if typeof(actor) == TYPE_DICTIONARY and not actor.is_empty():
			return str(actor.get("name", actor_id))
	return actor_id

func _equipped_name(slot: String) -> String:
	var item_id = party.get_equipped_item(selected_actor_id, slot) if party != null else ""
	if item_id.is_empty():
		return "无"
	if repository != null and repository.has_method("get_item"):
		var item = repository.get_item(item_id)
		if typeof(item) == TYPE_DICTIONARY and not item.is_empty():
			return str(item.get("name", item_id))
	return item_id