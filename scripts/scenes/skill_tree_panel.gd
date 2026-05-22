extends PanelContainer

const UiTheme = preload("res://scripts/core/ui_theme.gd")

signal node_unlocked(skill_id: String, node_id: String)
signal panel_closed

var growth_manager: RefCounted = null
var current_skill_id: String = ""
var skill_list: VBoxContainer
var tree_container: Control
var info_panel: VBoxContainer
var points_label: Label
var node_buttons: Dictionary = {}

var _cached_tree_size := Vector2.ZERO

func _init() -> void:
	custom_minimum_size = Vector2(900, 600)
	visible = false

func _ready() -> void:
	_build_ui()

func set_growth_manager(manager: RefCounted) -> void:
	growth_manager = manager
	_refresh_skill_list()
	_update_points_display()

func _build_ui() -> void:
	add_theme_stylebox_override("panel", UiTheme.make_gold_panel())

	var main_split := HSplitContainer.new()
	main_split.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_split.split_offset = 200
	add_child(main_split)

	var left_panel := VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(200, 0)
	left_panel.add_theme_constant_override("separation", 4)
	main_split.add_child(left_panel)

	var skill_title := Label.new()
	skill_title.text = "武学技能"
	skill_title.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	skill_title.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE_TITLE)
	skill_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(skill_title)

	var skill_scroll := ScrollContainer.new()
	skill_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(skill_scroll)

	skill_list = VBoxContainer.new()
	skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_list.add_theme_constant_override("separation", 4)
	skill_scroll.add_child(skill_list)

	var right_panel := VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_constant_override("separation", 4)
	main_split.add_child(right_panel)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	right_panel.add_child(header)

	var tree_title := Label.new()
	tree_title.text = "技能树"
	tree_title.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	tree_title.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE_TITLE)
	tree_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(tree_title)

	points_label = Label.new()
	points_label.text = "熟练度：0"
	points_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	header.add_child(points_label)

	var close_button := Button.new()
	close_button.text = "关闭"
	UiTheme.apply_close_button_theme(close_button)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	tree_container = Control.new()
	tree_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_container.resized.connect(_on_tree_resized)
	right_panel.add_child(tree_container)

	info_panel = VBoxContainer.new()
	info_panel.custom_minimum_size = Vector2(0, 120)
	info_panel.add_theme_constant_override("separation", 4)
	right_panel.add_child(info_panel)

func _on_tree_resized() -> void:
	var new_size = tree_container.size
	if new_size != _cached_tree_size and not current_skill_id.is_empty():
		_cached_tree_size = new_size
		_display_skill_tree(current_skill_id)

func _refresh_skill_list() -> void:
	for child in skill_list.get_children():
		child.queue_free()

	if growth_manager == null:
		return

	var skill_trees = growth_manager.skill_trees._trees
	for skill_id in skill_trees.keys():
		var tree = skill_trees[skill_id]
		var button := Button.new()
		button.text = str(tree.get("name", skill_id))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTheme.apply_button_theme(button)
		button.pressed.connect(_on_skill_selected.bind(skill_id))
		skill_list.add_child(button)

func _on_skill_selected(skill_id: String) -> void:
	current_skill_id = skill_id
	_display_skill_tree(skill_id)

func _display_skill_tree(skill_id: String) -> void:
	for child in tree_container.get_children():
		child.queue_free()
	node_buttons.clear()

	if growth_manager == null:
		return

	var tree = growth_manager.skill_trees._trees.get(skill_id, {})
	if tree.is_empty():
		return

	var container_size = tree_container.size
	if container_size.x < 100 or container_size.y < 100:
		container_size = Vector2(650, 400)

	var branches = tree.get("branches", [])
	if branches.is_empty():
		return

	var branch_width = container_size.x / max(branches.size(), 1)
	var node_height = 60.0
	var start_x = 20.0
	var start_y = 20.0

	for branch_index in range(branches.size()):
		var branch = branches[branch_index]
		var branch_x = start_x + branch_index * branch_width

		var branch_label := Label.new()
		branch_label.text = str(branch.get("name", ""))
		branch_label.position = Vector2(branch_x, start_y)
		branch_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
		tree_container.add_child(branch_label)

		var nodes = branch.get("nodes", [])
		for node_index in range(nodes.size()):
			var node = nodes[node_index]
			var node_y = start_y + 40 + node_index * node_height
			_create_node_button(skill_id, node, Vector2(branch_x, node_y))

func _create_node_button(skill_id: String, node: Dictionary, pos: Vector2) -> void:
	var node_id = str(node.get("id", ""))
	var is_unlocked = growth_manager.skill_trees._is_node_unlocked(skill_id, node_id)
	var can_unlock = _can_unlock_node(skill_id, node)

	var button := Button.new()
	button.position = pos
	button.custom_minimum_size = Vector2(220, 50)
	UiTheme.apply_button_theme(button)

	if is_unlocked:
		button.text = "✓ " + str(node.get("name", ""))
		button.disabled = true
		button.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GREEN)
	elif can_unlock:
		button.text = str(node.get("name", "")) + " (" + str(node.get("cost", 1)) + "点)"
		button.pressed.connect(_on_unlock_pressed.bind(skill_id, node_id))
	else:
		button.text = str(node.get("name", "")) + " (锁定)"
		button.disabled = true
		button.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_DIM)

	tree_container.add_child(button)
	node_buttons[node_id] = button

func _can_unlock_node(skill_id: String, node: Dictionary) -> bool:
	if growth_manager == null:
		return false

	var node_id = str(node.get("id", ""))
	if growth_manager.skill_trees._is_node_unlocked(skill_id, node_id):
		return false

	var cost = int(node.get("cost", 1))
	if growth_manager.proficiency_points < cost:
		return false

	var requires = node.get("requires", [])
	for req in requires:
		if not growth_manager.skill_trees._is_node_unlocked(skill_id, str(req)):
			return false

	return true

func _on_unlock_pressed(skill_id: String, node_id: String) -> void:
	if growth_manager == null:
		return

	var result = growth_manager.unlock_skill_node(skill_id, node_id)
	if result.get("success", false):
		node_unlocked.emit(skill_id, node_id)
		_display_skill_tree(skill_id)
		_update_points_display()
		_show_node_info(skill_id, node_id)

func _show_node_info(skill_id: String, node_id: String) -> void:
	for child in info_panel.get_children():
		child.queue_free()

	var tree = growth_manager.skill_trees._trees.get(skill_id, {})
	var node = _find_node(tree, node_id)
	if node.is_empty():
		return

	var name_label := Label.new()
	name_label.text = str(node.get("name", ""))
	name_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_GOLD)
	info_panel.add_child(name_label)

	var effects = node.get("effects", {})
	for key in effects.keys():
		var effect_label := Label.new()
		effect_label.text = _format_effect(key, effects[key])
		effect_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_WARM)
		info_panel.add_child(effect_label)

func _find_node(tree: Dictionary, node_id: String) -> Dictionary:
	for branch in tree.get("branches", []):
		for node in branch.get("nodes", []):
			if str(node.get("id", "")) == node_id:
				return node
	return {}

func _format_effect(key: String, value) -> String:
	match key:
		"damage_bonus":
			return "伤害 +" + str(value)
		"crit_chance":
			return "暴击率 +" + str(int(float(value) * 100)) + "%"
		"accuracy_bonus":
			return "精准 +" + str(value)
		"add_effect":
			return "附加效果：" + str(value)
		"extra_strike":
			return "连击率 " + str(int(float(value) * 100)) + "%"
		_:
			return str(key) + "：" + str(value)

func _update_points_display() -> void:
	if growth_manager != null:
		points_label.text = "熟练度：" + str(growth_manager.proficiency_points)

func _on_close_pressed() -> void:
	visible = false
	panel_closed.emit()

func open() -> void:
	_refresh_skill_list()
	_update_points_display()
	visible = true
	# 延迟刷新布局，等待容器尺寸就绪
	if not current_skill_id.is_empty():
		_cached_tree_size = Vector2.ZERO
		call_deferred("_display_skill_tree", current_skill_id)

func close() -> void:
	visible = false
