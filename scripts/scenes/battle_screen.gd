extends Control

const CombatSystemScript = preload("res://scripts/systems/combat_system.gd")
const TacticalCombatSystemScript = preload("res://scripts/systems/tactical_combat_system.gd")
const TacticalBattleStateScript = preload("res://scripts/domain/tactical_battle_state.gd")
const TACTICAL_CELL_SIZE := 64
const TACTICAL_GRID_OFFSET := Vector2(64, 48)

var title_label: Label
var hero_hp_label: Label
var enemy_hp_label: Label
var output: Label
var attack_button: Button
var item_button: Button
var retreat_button: Button
var context: Dictionary = {}
var battle_state = null
var combat_system = CombatSystemScript.new()
var is_tactical_mode := false
var tactical_battle_state = null
var tactical_combat_system = TacticalCombatSystemScript.new()
var grid_layer: Control
var status_label: Label
var unit_panel: VBoxContainer
var end_action_button: Button
var cell_buttons: Dictionary = {}
var selected_unit_id: String = ""

func _ready() -> void:
	context = GameState.peek_battle_context()
	is_tactical_mode = str(context.get("battle_mode", "")) == "tactical"
	if is_tactical_mode:
		tactical_combat_system.set_repository(DataRepository)
		tactical_battle_state = tactical_combat_system.create_battle(GameState, context, DataRepository)
		_create_tactical_ui()
		_refresh_tactical()
	else:
		combat_system.set_repository(DataRepository)
		battle_state = combat_system.create_battle(GameState, context, DataRepository)
		_create_ui()
		_refresh()

func _process(delta: float) -> void:
	if not is_tactical_mode or tactical_battle_state == null or tactical_battle_state.is_finished:
		return
	if not tactical_battle_state.is_action_phase:
		tactical_combat_system.advance_charge(tactical_battle_state, delta)
		_refresh_tactical()
	if tactical_battle_state.is_action_phase:
		var unit = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
		if unit != null and unit.team == TacticalBattleStateScript.TEAM_ENEMY:
			tactical_combat_system.resolve_enemy_action(tactical_battle_state, unit.unit_id)
			_refresh_tactical()
			_return_if_tactical_finished()

func _create_ui() -> void:
	title_label = Label.new()
	title_label.position = Vector2(32, 24)
	title_label.size = Vector2(720, 32)
	add_child(title_label)

	hero_hp_label = Label.new()
	hero_hp_label.position = Vector2(32, 72)
	hero_hp_label.size = Vector2(320, 32)
	add_child(hero_hp_label)

	enemy_hp_label = Label.new()
	enemy_hp_label.position = Vector2(380, 72)
	enemy_hp_label.size = Vector2(320, 32)
	add_child(enemy_hp_label)

	output = Label.new()
	output.position = Vector2(32, 120)
	output.size = Vector2(900, 220)
	output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(output)

	attack_button = Button.new()
	attack_button.text = "基础剑法"
	attack_button.position = Vector2(32, 372)
	attack_button.size = Vector2(120, 40)
	attack_button.pressed.connect(_on_attack_pressed)
	add_child(attack_button)

	item_button = Button.new()
	item_button.text = "小还丹"
	item_button.position = Vector2(176, 372)
	item_button.size = Vector2(120, 40)
	item_button.pressed.connect(_on_item_pressed)
	add_child(item_button)

	retreat_button = Button.new()
	retreat_button.text = "暂退"
	retreat_button.position = Vector2(320, 372)
	retreat_button.size = Vector2(120, 40)
	retreat_button.pressed.connect(_on_retreat_pressed)
	add_child(retreat_button)

func _create_tactical_ui() -> void:
	title_label = Label.new()
	title_label.text = "战棋：山道试剑"
	title_label.position = Vector2(32, 20)
	title_label.size = Vector2(420, 32)
	add_child(title_label)

	status_label = Label.new()
	status_label.position = Vector2(32, 56)
	status_label.size = Vector2(420, 32)
	add_child(status_label)

	grid_layer = Control.new()
	grid_layer.position = Vector2(120, 110)
	grid_layer.size = Vector2(640, 420)
	add_child(grid_layer)

	unit_panel = VBoxContainer.new()
	unit_panel.position = Vector2(820, 56)
	unit_panel.size = Vector2(360, 300)
	add_child(unit_panel)

	output = Label.new()
	output.position = Vector2(820, 380)
	output.size = Vector2(380, 170)
	output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(output)

	end_action_button = Button.new()
	end_action_button.text = "结束行动"
	end_action_button.position = Vector2(820, 570)
	end_action_button.size = Vector2(120, 40)
	end_action_button.pressed.connect(_on_tactical_end_action_pressed)
	add_child(end_action_button)

	retreat_button = Button.new()
	retreat_button.text = "暂退"
	retreat_button.position = Vector2(960, 570)
	retreat_button.size = Vector2(120, 40)
	retreat_button.pressed.connect(_on_tactical_retreat_pressed)
	add_child(retreat_button)

	_create_tactical_grid()

func _create_tactical_grid() -> void:
	cell_buttons.clear()
	for q in range(tactical_battle_state.battlefield_width):
		for r in range(tactical_battle_state.battlefield_height):
			var button = Button.new()
			button.text = ""
			button.size = Vector2(TACTICAL_CELL_SIZE, TACTICAL_CELL_SIZE)
			button.position = _cell_to_screen({"q": q, "r": r})
			button.flat = true
			button.focus_mode = Control.FOCUS_NONE
			_apply_tactical_cell_style(button)
			button.pressed.connect(_on_tactical_cell_pressed.bind(q, r))
			grid_layer.add_child(button)
			cell_buttons[_cell_key({"q": q, "r": r})] = button

func _refresh_tactical() -> void:
	if tactical_battle_state == null:
		return
	var current = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
	if tactical_battle_state.is_finished:
		status_label.text = "战斗结束"
	elif current != null:
		status_label.text = "%s行动" % current.display_name
	else:
		status_label.text = "等待集气"

	for child in unit_panel.get_children():
		child.queue_free()
	for unit in tactical_battle_state.units:
		var label = Label.new()
		label.text = "%s 气血:%d/%d 集气:%d/%d" % [
			unit.display_name,
			unit.hp,
			unit.max_hp,
			unit.charge,
			TacticalBattleStateScript.CHARGE_LIMIT,
		]
		unit_panel.add_child(label)

	var movable = tactical_combat_system.get_movable_cells(tactical_battle_state, tactical_battle_state.current_unit_id)
	var attackable = tactical_combat_system.get_attackable_units(tactical_battle_state, tactical_battle_state.current_unit_id)
	for key in cell_buttons.keys():
		var button = cell_buttons[key]
		button.text = ""
		button.disabled = true
	for unit in tactical_battle_state.units:
		var unit_key = _cell_key(unit.cell)
		if cell_buttons.has(unit_key):
			cell_buttons[unit_key].text = unit.display_name.substr(0, 2)
	for cell in movable:
		var move_key = _cell_key(cell)
		if cell_buttons.has(move_key):
			cell_buttons[move_key].disabled = false
	for target in attackable:
		var target_key = _cell_key(target.cell)
		if cell_buttons.has(target_key):
			cell_buttons[target_key].disabled = false

	output.text = "\n".join(PackedStringArray(tactical_battle_state.log))
	end_action_button.disabled = tactical_battle_state.is_finished or not _is_player_action()
	retreat_button.disabled = tactical_battle_state.is_finished

func _on_attack_pressed() -> void:
	combat_system.resolve_player_attack(battle_state, GameState, "basic_sword")
	_refresh()
	_return_if_finished()

func _on_item_pressed() -> void:
	combat_system.resolve_player_item(battle_state, GameState, "herb_small")
	_refresh()
	_return_if_finished()

func _on_retreat_pressed() -> void:
	combat_system.resolve_retreat(battle_state)
	_refresh()
	_return_if_finished()

func _refresh() -> void:
	var enemy_name = DataRepository.get_actor(_enemy_id()).get("name", "山道强人")
	title_label.text = "战斗：%s" % enemy_name
	hero_hp_label.text = "云游少侠 气血：%d / %d" % [battle_state.hero_hp, battle_state.hero_max_hp]
	enemy_hp_label.text = "%s 气血：%d / %d" % [enemy_name, battle_state.enemy_hp, battle_state.enemy_max_hp]
	output.text = "\n".join(PackedStringArray(battle_state.log))

	var finished = battle_state.is_finished
	attack_button.disabled = finished
	item_button.disabled = finished
	retreat_button.disabled = finished

func _on_tactical_cell_pressed(q: int, r: int) -> void:
	if not _is_player_action():
		return
	var current_unit = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
	if current_unit == null:
		return
	var cell = {"q": q, "r": r}
	var target = _unit_at_cell(cell)
	if target != null and target.team != current_unit.team:
		tactical_combat_system.attack_unit(tactical_battle_state, current_unit.unit_id, target.unit_id)
		if not tactical_battle_state.is_finished:
			tactical_combat_system.end_unit_action(tactical_battle_state, current_unit.unit_id)
	else:
		tactical_combat_system.move_unit(tactical_battle_state, current_unit.unit_id, cell)
	_refresh_tactical()
	_return_if_tactical_finished()

func _on_tactical_end_action_pressed() -> void:
	if not _is_player_action():
		return
	tactical_combat_system.end_unit_action(tactical_battle_state, tactical_battle_state.current_unit_id)
	_refresh_tactical()

func _on_tactical_retreat_pressed() -> void:
	tactical_combat_system.resolve_retreat(tactical_battle_state)
	_refresh_tactical()
	_return_if_tactical_finished()

func _return_if_tactical_finished() -> void:
	if tactical_battle_state == null or not tactical_battle_state.is_finished:
		return
	var payload = tactical_battle_state.to_result_dictionary()
	GameState.apply_battle_result(payload)
	EventBus.battle_finished.emit(payload)
	call_deferred("_return_to_map")

func _return_if_finished() -> void:
	if not battle_state.is_finished:
		return
	var payload = battle_state.to_result_dictionary()
	GameState.apply_battle_result(payload)
	EventBus.battle_finished.emit(payload)
	call_deferred("_return_to_map")

func _return_to_map() -> void:
	var source_map_id = ""
	if is_tactical_mode and tactical_battle_state != null:
		source_map_id = tactical_battle_state.source_map_id
	elif battle_state != null:
		source_map_id = battle_state.source_map_id
	if source_map_id.is_empty():
		source_map_id = str(context.get("source_map_id", GameState.map_state.current_map_id))
	if source_map_id.is_empty():
		source_map_id = "mountain_pass"
	GameState.consume_battle_context()
	SceneLoader.change_scene(GameState.get_scene_path_for_map(source_map_id))

func _is_player_action() -> bool:
	if tactical_battle_state == null or not tactical_battle_state.is_action_phase:
		return false
	var unit = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
	return unit != null and unit.team == TacticalBattleStateScript.TEAM_PLAYER

func _unit_at_cell(cell: Dictionary):
	for unit in tactical_battle_state.units:
		if unit.is_alive() and int(unit.cell.get("q", -1)) == int(cell.get("q", -2)) and int(unit.cell.get("r", -1)) == int(cell.get("r", -2)):
			return unit
	return null

func _apply_tactical_cell_style(button: Button) -> void:
	var idle = _make_tactical_cell_style(Color(0.18, 0.24, 0.18, 0.10), Color(0.72, 0.84, 0.62, 0.25))
	var active = _make_tactical_cell_style(Color(0.22, 0.48, 0.74, 0.24), Color(0.36, 0.66, 0.95, 0.70))
	var pressed = _make_tactical_cell_style(Color(0.28, 0.58, 0.84, 0.36), Color(0.62, 0.82, 1.0, 0.85))
	button.add_theme_stylebox_override("normal", active)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", idle)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.88))

func _make_tactical_cell_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_right = 0
	style.corner_radius_bottom_left = 0
	return style

func _cell_to_screen(cell: Dictionary) -> Vector2:
	var q = int(cell.get("q", 0))
	var r = int(cell.get("r", 0))
	return TACTICAL_GRID_OFFSET + Vector2(q * TACTICAL_CELL_SIZE, r * TACTICAL_CELL_SIZE)

func _cell_key(cell: Dictionary) -> String:
	return "%d:%d" % [int(cell.get("q", 0)), int(cell.get("r", 0))]

func _enemy_id() -> String:
	var enemy_id = str(context.get("enemy_id", "bandit_01"))
	if enemy_id.is_empty():
		return "bandit_01"
	return enemy_id
