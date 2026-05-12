extends Control

const CombatSystemScript = preload("res://scripts/systems/combat_system.gd")
const TacticalCombatSystemScript = preload("res://scripts/systems/tactical_combat_system.gd")
const TacticalBattleStateScript = preload("res://scripts/domain/tactical_battle_state.gd")
const BattleGridScript = preload("res://scripts/scenes/battle_grid.gd")
const TerrainSystemScript = preload("res://scripts/systems/terrain_system.gd")
const TacticalUnitSpriteScript = preload("res://scripts/scenes/tactical_unit_sprite.gd")
const TacticalRangeSystemScript = preload("res://scripts/systems/tactical_range_system.gd")
const BattleActionBarScript = preload("res://scripts/scenes/battle_action_bar.gd")
const ChargeBarScript = preload("res://scripts/scenes/charge_bar.gd")
const BattlePanelObjectiveScript = preload("res://scripts/scenes/battle_panel_objective.gd")
const BattlePanelTerrainScript = preload("res://scripts/scenes/battle_panel_terrain.gd")
const BattlePanelActorScript = preload("res://scripts/scenes/battle_panel_actor.gd")
const BattleLogScript = preload("res://scripts/scenes/battle_log.gd")
const TACTICAL_CELL_SIZE := 64
const TACTICAL_GRID_OFFSET := Vector2(64, 48)

enum RangeMode { NONE = 0, MOVE = 1, ATTACK = 2, SKILL_DIR_PREVIEW = 3, SKILL_TARGET_PREVIEW = 4 }

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
var battle_grid: Node2D
var status_label: Label
var unit_panel: VBoxContainer
var end_action_button: Button
var normal_attack_button: Button
var tactical_art_buttons: Dictionary = {}
var selected_tactical_action_id: String = "attack"
var cell_buttons: Dictionary = {}
var cell_visuals: Dictionary = {}
var selected_unit_id: String = ""
var _unit_sprites: Dictionary = {}  # unit_id → TacticalUnitSpriteScript 实例（挂在 battle_grid 下）
var tactical_range_system = TacticalRangeSystemScript.new()
var range_mode: int = RangeMode.NONE
var range_cells: Array = []  # Array[Vector2i]
var action_bar = null  # Task 12 底部行动栏（BattleActionBarScript 实例）
var charge_bar = null  # Task 13 顶部集气进度条（ChargeBarScript 实例）
var panel_objective = null  # Task 14 左上「战斗目标 + 战场信息」
var panel_terrain = null  # Task 14 左下「地形信息」
var panel_actor = null  # Task 15 右上「主角信息卡」
var battle_log = null  # Task 16 右下「战斗日志」
var _terrain_system = null  # Task 14 共享给 hover/Tab 切换查地形数据
var _last_hover_cell: Vector2i = Vector2i(-1, -1)  # Task 14 鼠标 hover 去重
# Task 17: 技能菜单/方向箭头/目标范围状态
var _pending_skill_id: String = ""  # 当前 SKILL_DIR_PREVIEW / SKILL_TARGET_PREVIEW 模式锁定的招式 id
var _direction_buttons: Array = []  # 4 方向箭头 Button 列表（释放后清空）
var _skill_menu = null  # 当前打开的招式 PopupMenu（多次点击避免重叠）
# Task 19: 移动滑动动画锁
var is_animating := false
var _move_anim_target_cell: Dictionary = {}  # 动画结束后 commit_move 用的目标格

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
	# Task 19: 动画期间冻结集气推进与敌方 AI，避免动画未完角色已"被攻击/被切换"。
	if is_animating:
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
	_refresh_charge_bar()
	_poll_terrain_hover()

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

	# Task 9: 在 grid_layer 之下加 battle_grid 像素地形层（旧 ColorRect 仍然可见可点击）
	battle_grid = BattleGridScript.new()
	battle_grid.position = Vector2(120, 110)
	add_child(battle_grid)
	move_child(battle_grid, grid_layer.get_index())
	var terrain_system = TerrainSystemScript.new()
	terrain_system.set_repository(DataRepository)
	if tactical_battle_state != null:
		battle_grid.setup(tactical_battle_state.terrain_grid, terrain_system)
	tactical_range_system.set_terrain_system(terrain_system)
	_terrain_system = terrain_system

	unit_panel = VBoxContainer.new()
	unit_panel.position = Vector2(820, 56)
	unit_panel.size = Vector2(360, 300)
	add_child(unit_panel)

	output = Label.new()
	output.position = Vector2(820, 380)
	output.size = Vector2(380, 170)
	output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(output)

	normal_attack_button = Button.new()
	normal_attack_button.text = "普通攻击"
	normal_attack_button.position = Vector2(820, 560)
	normal_attack_button.size = Vector2(112, 36)
	normal_attack_button.pressed.connect(_on_tactical_action_selected.bind("attack"))
	add_child(normal_attack_button)

	_create_tactical_art_button("basic_sword", Vector2(940, 560))
	_create_tactical_art_button("straight_sword_thrust", Vector2(1060, 560))

	end_action_button = Button.new()
	end_action_button.text = "结束行动"
	end_action_button.position = Vector2(820, 610)
	end_action_button.size = Vector2(120, 40)
	end_action_button.pressed.connect(_on_tactical_end_action_pressed)
	add_child(end_action_button)

	retreat_button = Button.new()
	retreat_button.text = "暂退"
	retreat_button.position = Vector2(960, 610)
	retreat_button.size = Vector2(120, 40)
	retreat_button.pressed.connect(_on_tactical_retreat_pressed)
	add_child(retreat_button)

	_create_tactical_grid()
	_build_unit_sprites()
	# Task 12: 底部 7 图标行动栏（与旧按钮并存，旧按钮 Task 20 再清）。
	action_bar = BattleActionBarScript.new()
	action_bar.position = Vector2(180, 660)
	add_child(action_bar)
	action_bar.action_selected.connect(_on_action_bar_selected)
	# Task 13: 顶部集气进度条（800 宽，置于标题下方）。
	charge_bar = ChargeBarScript.new()
	charge_bar.position = Vector2(120, 88)
	charge_bar.size = Vector2(800, 32)
	charge_bar.bar_width = 800
	add_child(charge_bar)
	_refresh_charge_bar()
	# Task 14: 左上战斗目标 + 战场信息；左下地形信息。
	panel_objective = BattlePanelObjectiveScript.new()
	panel_objective.position = Vector2(8, 8)
	panel_objective.size = Vector2(200, 180)
	panel_objective.custom_minimum_size = Vector2(200, 180)
	add_child(panel_objective)
	panel_terrain = BattlePanelTerrainScript.new()
	panel_terrain.position = Vector2(8, 460)
	panel_terrain.size = Vector2(200, 252)
	panel_terrain.custom_minimum_size = Vector2(200, 252)
	add_child(panel_terrain)
	# Task 15: 右上主角信息卡。
	panel_actor = BattlePanelActorScript.new()
	panel_actor.position = Vector2(1072, 8)
	panel_actor.size = Vector2(200, 240)
	panel_actor.custom_minimum_size = Vector2(200, 240)
	add_child(panel_actor)
	EventBus.hero_mp_changed.connect(_on_hero_mp_changed_for_actor_panel)
	# Task 16: 右下战斗日志面板。
	battle_log = BattleLogScript.new()
	battle_log.position = Vector2(1072, 460)
	battle_log.size = Vector2(200, 252)
	battle_log.custom_minimum_size = Vector2(200, 252)
	add_child(battle_log)
	EventBus.tactical_log_appended.connect(_on_tactical_log_appended)
	_refresh_terrain_panels_for_current_actor()
	_refresh_actor_panel()

func _build_unit_sprites() -> void:
	# 为 tactical_battle_state.units 中每个单位创建一个 TacticalUnitSprite，
	# 挂在 battle_grid 下使其与地形 tile 共享坐标系。
	for s in _unit_sprites.values():
		if is_instance_valid(s):
			s.queue_free()
	_unit_sprites.clear()
	if battle_grid == null or tactical_battle_state == null:
		return
	for unit in tactical_battle_state.units:
		var sprite = TacticalUnitSpriteScript.new()
		battle_grid.add_child(sprite)
		sprite.setup(str(unit.unit_id), str(unit.sprite_tile_id), int(unit.max_hp))
		sprite.position = battle_grid.grid_to_pixel(Vector2i(int(unit.cell.get("q", 0)), int(unit.cell.get("r", 0))))
		_unit_sprites[str(unit.unit_id)] = sprite

func _create_tactical_grid() -> void:
	cell_buttons.clear()
	cell_visuals.clear()
	for q in range(tactical_battle_state.battlefield_width):
		for r in range(tactical_battle_state.battlefield_height):
			var cell = {"q": q, "r": r}
			var cell_key = _cell_key(cell)
			var visual = Panel.new()
			visual.size = Vector2(TACTICAL_CELL_SIZE, TACTICAL_CELL_SIZE)
			visual.position = _cell_to_screen(cell)
			visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_apply_tactical_cell_visual_style(visual, "idle")
			grid_layer.add_child(visual)
			cell_visuals[cell_key] = visual

			var button = Button.new()
			button.text = ""
			button.size = Vector2(TACTICAL_CELL_SIZE, TACTICAL_CELL_SIZE)
			button.position = _cell_to_screen(cell)
			button.flat = true
			button.focus_mode = Control.FOCUS_NONE
			_apply_tactical_cell_style(button)
			button.pressed.connect(_on_tactical_cell_pressed.bind(q, r))
			grid_layer.add_child(button)
			cell_buttons[cell_key] = button

func _create_tactical_art_button(martial_art_id: String, button_position: Vector2) -> void:
	var martial_art = DataRepository.get_martial_art(martial_art_id)
	if martial_art.is_empty() or typeof(martial_art.get("tactical", {})) != TYPE_DICTIONARY:
		return
	var button = Button.new()
	button.text = str(martial_art.get("name", martial_art_id))
	button.position = button_position
	button.size = Vector2(112, 36)
	button.pressed.connect(_on_tactical_action_selected.bind(martial_art_id))
	add_child(button)
	tactical_art_buttons[martial_art_id] = button

func _refresh_tactical() -> void:
	if tactical_battle_state == null:
		return
	var current = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
	if tactical_battle_state.is_finished:
		status_label.text = "战斗结束"
	elif current != null and current.team == TacticalBattleStateScript.TEAM_PLAYER:
		status_label.text = "%s行动 内力 %d/%d" % [current.display_name, current.mp, current.max_mp]
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

	var movable: Array = []
	var attackable: Array = []
	if _is_player_action():
		movable = tactical_combat_system.get_movable_cells(tactical_battle_state, tactical_battle_state.current_unit_id)
		attackable = _get_attackable_units_for_selected_action()
	for key in cell_buttons.keys():
		var button = cell_buttons[key]
		button.text = ""
		button.disabled = true
		if cell_visuals.has(key):
			_apply_tactical_cell_visual_style(cell_visuals[key], "idle")
	for unit in tactical_battle_state.units:
		if not unit.is_alive():
			continue
		var unit_key = _cell_key(unit.cell)
		if cell_buttons.has(unit_key):
			cell_buttons[unit_key].text = unit.display_name.substr(0, 2)
	for cell in movable:
		var move_key = _cell_key(cell)
		if cell_buttons.has(move_key):
			cell_buttons[move_key].disabled = false
		if cell_visuals.has(move_key):
			_apply_tactical_cell_visual_style(cell_visuals[move_key], "move")
	for target in attackable:
		var target_key = _cell_key(target.cell)
		if cell_buttons.has(target_key):
			cell_buttons[target_key].disabled = false
		if cell_visuals.has(target_key):
			_apply_tactical_cell_visual_style(cell_visuals[target_key], "attack")

	output.text = "\n".join(PackedStringArray(tactical_battle_state.log))
	_refresh_tactical_action_buttons(current)
	end_action_button.disabled = tactical_battle_state.is_finished or not _is_player_action()
	retreat_button.disabled = tactical_battle_state.is_finished
	_sync_unit_sprites()
	_refresh_actor_panel()

func _sync_unit_sprites() -> void:
	if battle_grid == null or tactical_battle_state == null:
		return
	var current_id := str(tactical_battle_state.current_unit_id)
	var alive_ids := {}
	for unit in tactical_battle_state.units:
		var uid := str(unit.unit_id)
		var sprite = _unit_sprites.get(uid)
		if sprite == null or not is_instance_valid(sprite):
			sprite = TacticalUnitSpriteScript.new()
			battle_grid.add_child(sprite)
			sprite.setup(uid, str(unit.sprite_tile_id), int(unit.max_hp))
			_unit_sprites[uid] = sprite
		sprite.position = battle_grid.grid_to_pixel(Vector2i(int(unit.cell.get("q", 0)), int(unit.cell.get("r", 0))))
		sprite.set_hp(int(unit.hp), int(unit.max_hp))
		sprite.set_current_actor(uid == current_id and not tactical_battle_state.is_finished)
		sprite.set_selected(uid == selected_unit_id)
		sprite.visible = unit.is_alive()
		alive_ids[uid] = true
	# 清理已不存在的单位精灵
	for k in _unit_sprites.keys():
		if not alive_ids.has(k):
			var s = _unit_sprites[k]
			if is_instance_valid(s):
				s.queue_free()
			_unit_sprites.erase(k)

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
	# Task 19: 动画期间禁用任何点击，避免「移动中又点了攻击」状态错乱。
	if is_animating:
		return
	if not _is_player_action():
		return
	var current_unit = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
	if current_unit == null:
		return
	# Task 18: SKILL_TARGET_PREVIEW 模式下点中心格 → 计算十字爆炸 → resolve_action。
	if range_mode == RangeMode.SKILL_TARGET_PREVIEW and not _pending_skill_id.is_empty():
		var clicked := Vector2i(q, r)
		var hit := false
		for c in range_cells:
			if typeof(c) == TYPE_VECTOR2I and Vector2i(c) == clicked:
				hit = true
				break
		if not hit:
			return
		var blast: Array = tactical_range_system.get_skill_target_blast_range(_pending_skill_id, clicked)
		_resolve_skill_action(_pending_skill_id, blast)
		return
	var cell = {"q": q, "r": r}
	var target = _unit_at_cell(cell)
	if target != null and target.team != current_unit.team:
		var result: Dictionary
		if selected_tactical_action_id == "attack":
			result = tactical_combat_system.attack_unit(tactical_battle_state, current_unit.unit_id, target.unit_id)
		else:
			result = tactical_combat_system.use_martial_art(tactical_battle_state, current_unit.unit_id, target.unit_id, selected_tactical_action_id, DataRepository)
		if bool(result.get("success", false)) and not tactical_battle_state.is_finished:
			tactical_combat_system.end_unit_action(tactical_battle_state, current_unit.unit_id)
		_refresh_tactical()
		_return_if_tactical_finished()
		return
	# Task 19: 走移动 → 改为先播滑动动画，动画结束才 commit_move。
	if _start_move_animation(current_unit, cell):
		return
	# 不可移动则原地刷新（兜底，几乎不会触发）。
	_refresh_tactical()

func _on_tactical_action_selected(action_id: String) -> void:
	if action_id.is_empty():
		return
	selected_tactical_action_id = action_id
	_refresh_tactical()

func _get_attackable_units_for_selected_action() -> Array:
	if selected_tactical_action_id == "attack":
		return tactical_combat_system.get_attackable_units(tactical_battle_state, tactical_battle_state.current_unit_id)
	return tactical_combat_system.get_attackable_units_for_martial_art(tactical_battle_state, tactical_battle_state.current_unit_id, selected_tactical_action_id, DataRepository)

func _refresh_tactical_action_buttons(current_unit) -> void:
	var can_act = _is_player_action() and current_unit != null
	if normal_attack_button != null:
		normal_attack_button.disabled = not can_act
	for martial_art_id in tactical_art_buttons.keys():
		var button = tactical_art_buttons[martial_art_id]
		button.disabled = not can_act or not _can_current_unit_use_tactical_art(current_unit, str(martial_art_id))
	if selected_tactical_action_id != "attack":
		var selected_button = tactical_art_buttons.get(selected_tactical_action_id)
		if selected_button == null or selected_button.disabled:
			selected_tactical_action_id = "attack"

func _can_current_unit_use_tactical_art(current_unit, martial_art_id: String) -> bool:
	if current_unit == null or not current_unit.martial_art_ids.has(martial_art_id):
		return false
	var martial_art = DataRepository.get_martial_art(martial_art_id)
	if martial_art.is_empty():
		return false
	var tactical = martial_art.get("tactical", {})
	if typeof(tactical) != TYPE_DICTIONARY:
		return false
	var mp_cost = max(0, int(tactical.get("mp_cost", martial_art.get("cost", 0))))
	return current_unit.mp >= mp_cost

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
	# 失败回流可能已经切了 current_map_id，优先使用它
	var target_map_id = GameState.map_state.current_map_id
	if target_map_id.is_empty():
		target_map_id = source_map_id
	SceneLoader.change_scene(GameState.get_scene_path_for_map(target_map_id))

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

func _apply_tactical_cell_visual_style(panel: Panel, state: String) -> void:
	var fill = Color(0.20, 0.26, 0.20, 0.22)
	var border = Color(0.82, 0.90, 0.72, 0.38)
	match state:
		"move":
			fill = Color(0.20, 0.48, 0.74, 0.28)
			border = Color(0.42, 0.70, 1.00, 0.75)
		"attack":
			fill = Color(0.72, 0.24, 0.20, 0.30)
			border = Color(1.00, 0.42, 0.36, 0.82)
	panel.add_theme_stylebox_override("panel", _make_tactical_cell_style(fill, border))

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

# Task 11: 切换范围模式（NONE/MOVE/ATTACK/SKILL_DIR_PREVIEW/SKILL_TARGET_PREVIEW），
# 同步给 battle_grid 绘制 overlay 并广播事件。
func _set_range_mode(mode: int, cells: Array = []) -> void:
	range_mode = mode
	range_cells = cells
	if battle_grid != null:
		battle_grid.set_range_overlay(mode, cells)
	EventBus.tactical_range_mode_changed.emit(mode)

# Task 11/12: 收集所有存活敌方单位的 Vector2i 坐标，给 tactical_range_system 用。
func _enemy_positions() -> Array:
	var arr: Array = []
	if tactical_battle_state == null:
		return arr
	for unit in tactical_battle_state.units:
		if not unit.is_alive():
			continue
		if unit.team != TacticalBattleStateScript.TEAM_PLAYER:
			arr.append(Vector2i(int(unit.cell.get("q", 0)), int(unit.cell.get("r", 0))))
	return arr

# Task 11/12: 把 unit.cell 字典转 Dictionary→Vector2i 与 unit.position 兼容，
# 为 range_system 提供调用所需的 unit 视图。
func _unit_view_for_range(unit) -> Dictionary:
	if unit == null:
		return {}
	var pos := Vector2i(int(unit.cell.get("q", 0)), int(unit.cell.get("r", 0)))
	return {
		"position": pos,
		"move": int(unit.move_range),
	}

# Task 12: 行动栏 7 图标按钮派发：
# move/attack 切 range_mode 高亮；skill/item/wait/view/system 走简易降级回退。
func _on_action_bar_selected(action_id: String) -> void:
	if tactical_battle_state == null:
		return
	var unit = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
	if unit == null:
		return
	var view := _unit_view_for_range(unit)
	match action_id:
		"move":
			var cells := tactical_range_system.get_move_range(view, tactical_battle_state.terrain_grid, _enemy_positions())
			_set_range_mode(RangeMode.MOVE, cells)
		"attack":
			var cells := tactical_range_system.get_attack_range_simple(view)
			_set_range_mode(RangeMode.ATTACK, cells)
		"skill":
			# Task 17: 弹出当前主角已学的 tactical 武学菜单，按 shape 走方向/目标交互。
			_clear_direction_arrows()
			_pending_skill_id = ""
			_set_range_mode(RangeMode.NONE, [])
			_open_skill_menu()
		"item", "view", "system":
			_set_range_mode(RangeMode.NONE, [])
		"wait":
			# 待机 = 立即结束当前角色行动（与旧"结束行动"按钮等价的简化版）。
			_set_range_mode(RangeMode.NONE, [])
			if tactical_battle_state.is_action_phase:
				tactical_combat_system.end_unit_action(tactical_battle_state, tactical_battle_state.current_unit_id)
				_refresh_tactical()
				_return_if_tactical_finished()

# Task 13: 把 tactical_battle_state.units 转成 charge_bar 期望的 dict 列表。
# cur_charge 字段映射自 unit.charge；is_action 表示当前正在行动相位的角色。
func _refresh_charge_bar() -> void:
	if charge_bar == null or tactical_battle_state == null:
		return
	var current_id := str(tactical_battle_state.current_unit_id)
	var dicts: Array = []
	for unit in tactical_battle_state.units:
		if not unit.is_alive():
			continue
		var team := 0 if unit.team == TacticalBattleStateScript.TEAM_PLAYER else 1
		dicts.append({
			"unit_id": str(unit.unit_id),
			"team": team,
			"cur_charge": int(unit.charge),
			"is_action": tactical_battle_state.is_action_phase and str(unit.unit_id) == current_id,
		})
	charge_bar.set_units(dicts)

# Task 14: 鼠标悬停某战棋格 → 刷新左下地形面板 + 左上战场信息面板。
# 通过 Engine 输入位置反推 grid cell，去重避免每帧重复刷新。
func _poll_terrain_hover() -> void:
	if battle_grid == null or _terrain_system == null or panel_terrain == null:
		return
	if tactical_battle_state == null or typeof(tactical_battle_state.terrain_grid) != TYPE_ARRAY:
		return
	var cell := _mouse_to_grid_cell()
	if cell == _last_hover_cell:
		return
	_last_hover_cell = cell
	if cell.x < 0:
		_refresh_terrain_panels_for_current_actor()
		return
	_show_terrain_at(cell)

func _mouse_to_grid_cell() -> Vector2i:
	# battle_grid 是 Node2D，position 是其全局原点；TILE_SIZE = 32（见 battle_grid.gd）。
	var local: Vector2 = get_global_mouse_position() - battle_grid.global_position
	var tile_size := 32
	var c := int(floor(local.x / tile_size))
	var r := int(floor(local.y / tile_size))
	var rows: int = tactical_battle_state.terrain_grid.size()
	var cols := 0
	if rows > 0 and typeof(tactical_battle_state.terrain_grid[0]) == TYPE_ARRAY:
		cols = tactical_battle_state.terrain_grid[0].size()
	if r < 0 or r >= rows or c < 0 or c >= cols:
		return Vector2i(-1, -1)
	return Vector2i(c, r)

func _show_terrain_at(cell: Vector2i) -> void:
	var terrain_id := _terrain_at(cell)
	var data: Dictionary = _terrain_system.get_terrain(terrain_id)
	if panel_terrain != null:
		panel_terrain.set_terrain(data)
	if panel_objective != null:
		var fallback := terrain_id if not terrain_id.is_empty() else "—"
		var name_text := str(data.get("name", fallback))
		var ev := int(data.get("evasion_bonus", 0))
		var mc := int(data.get("move_cost", 1))
		var sign_str := "+" if ev >= 0 else ""
		var effect := "闪避 %s%d%% / 移动消耗 %d" % [sign_str, ev, mc]
		panel_objective.set_hovered_terrain(name_text, effect)

func _terrain_at(cell: Vector2i) -> String:
	if tactical_battle_state == null:
		return ""
	var grid: Array = tactical_battle_state.terrain_grid
	if cell.y < 0 or cell.y >= grid.size():
		return ""
	var row = grid[cell.y]
	if typeof(row) != TYPE_ARRAY or cell.x < 0 or cell.x >= row.size():
		return ""
	return str(row[cell.x])

# Task 14: 当无 hover 时回退到「当前 actor 所在格地形」。
func _refresh_terrain_panels_for_current_actor() -> void:
	if tactical_battle_state == null or _terrain_system == null:
		return
	var unit = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
	if unit == null:
		return
	var cell := Vector2i(int(unit.cell.get("q", 0)), int(unit.cell.get("r", 0)))
	_show_terrain_at(cell)

# Task 14: Tab 键 = 在地图上跳到下一个不同地形格作为聚焦光标（用 hover 同样的展示路径）。
func _input(event: InputEvent) -> void:
	if not is_tactical_mode:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_focus_next_distinct_terrain()
		accept_event()

func _focus_next_distinct_terrain() -> void:
	if tactical_battle_state == null:
		return
	var grid: Array = tactical_battle_state.terrain_grid
	if grid.is_empty():
		return
	var cur_terrain := ""
	if _last_hover_cell.x >= 0:
		cur_terrain = _terrain_at(_last_hover_cell)
	var rows: int = grid.size()
	var cols: int = 0
	if typeof(grid[0]) == TYPE_ARRAY:
		cols = grid[0].size()
	if rows == 0 or cols == 0:
		return
	var start_idx := 0
	if _last_hover_cell.x >= 0:
		start_idx = _last_hover_cell.y * cols + _last_hover_cell.x + 1
	for i in range(rows * cols):
		var idx := (start_idx + i) % (rows * cols)
		var c := idx % cols
		var r := idx / cols
		var t := str(grid[r][c])
		if t != cur_terrain and not t.is_empty():
			_last_hover_cell = Vector2i(c, r)
			_show_terrain_at(_last_hover_cell)
			return

# Task 15: 在右上主角信息卡上同步显示「当前正在行动的角色」状态；
# 若无行动单位则回退到首位玩家单位（一般是主角云游少侠）。
func _refresh_actor_panel() -> void:
	if panel_actor == null or tactical_battle_state == null:
		return
	var unit = _pick_actor_panel_unit()
	panel_actor.set_actor(unit)

func _pick_actor_panel_unit():
	var current = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
	if current != null and current.team == TacticalBattleStateScript.TEAM_PLAYER:
		return current
	for unit in tactical_battle_state.units:
		if unit.team == TacticalBattleStateScript.TEAM_PLAYER and unit.is_alive():
			return unit
	# 全队覆灭兜底：返回 current 或 null。
	return current

func _on_hero_mp_changed_for_actor_panel(_cur_mp: int, _max_mp: int) -> void:
	_refresh_actor_panel()

# Task 16: tactical_combat_system._log 触发的事件，转发到右下战斗日志面板。
func _on_tactical_log_appended(line: String) -> void:
	if battle_log != null:
		battle_log.append(line)

# ─── Task 17: 招式菜单 + 方向箭头 ──────────────────────────────────────────────

# 弹出 PopupMenu，列出当前主角已学且 mp 够 + 含 shape 字段的 tactical 武学；
# 点击某项后走 _on_skill_chosen。无可用招式时静默关闭。
func _open_skill_menu() -> void:
	if not _is_player_action() or tactical_battle_state == null:
		return
	var unit = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
	if unit == null:
		return
	if _skill_menu != null and is_instance_valid(_skill_menu):
		_skill_menu.queue_free()
	var menu := PopupMenu.new()
	var skill_ids: Array = []
	for sid in unit.martial_art_ids:
		var sid_s := str(sid)
		var data: Dictionary = DataRepository.get_martial_art(sid_s)
		if data.is_empty():
			continue
		var shape := str(data.get("shape", ""))
		if shape.is_empty():
			continue  # 仅展示方向/目标型招式（基础剑法等近身招式仍走旧攻击按钮）
		if not _can_current_unit_use_tactical_art(unit, sid_s):
			menu.add_item("%s（内力不足）" % str(data.get("name", sid_s)))
			menu.set_item_disabled(menu.get_item_count() - 1, true)
		else:
			menu.add_item(str(data.get("name", sid_s)))
		skill_ids.append(sid_s)
	if skill_ids.is_empty():
		menu.queue_free()
		return
	add_child(menu)
	_skill_menu = menu
	menu.id_pressed.connect(func(idx: int) -> void:
		if idx >= 0 and idx < skill_ids.size():
			_on_skill_chosen(skill_ids[idx])
		menu.queue_free()
	)
	menu.popup_hide.connect(func() -> void:
		if is_instance_valid(menu):
			menu.queue_free()
	)
	var mouse_pos := get_viewport().get_mouse_position()
	menu.position = Vector2i(int(mouse_pos.x), int(mouse_pos.y))
	menu.popup()

# 根据招式 shape 切换到 SKILL_DIR_PREVIEW（方向箭头）或 SKILL_TARGET_PREVIEW（中心格）。
func _on_skill_chosen(skill_id: String) -> void:
	_pending_skill_id = skill_id
	var data: Dictionary = DataRepository.get_martial_art(skill_id)
	var shape := str(data.get("shape", ""))
	if shape.begins_with("line_"):
		_set_range_mode(RangeMode.SKILL_DIR_PREVIEW, [])
		_show_direction_arrows(skill_id)
	elif shape.begins_with("target_"):
		var unit = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
		var view := _unit_view_for_range(unit)
		var cast_range: int = int(data.get("cast_range", int(data.get("tactical", {}).get("range", 1))))
		var centers: Array = tactical_range_system.get_skill_target_selection_range(view, skill_id, cast_range)
		_set_range_mode(RangeMode.SKILL_TARGET_PREVIEW, centers)
	else:
		_pending_skill_id = ""
		_set_range_mode(RangeMode.NONE, [])

# 在主角四向相邻格放 4 个箭头按钮。边界外的方向不显示。
# 简化版：用 Button + 文本箭头（→/←/↑/↓），后续可换 Kenney TextureButton 资源。
func _show_direction_arrows(skill_id: String) -> void:
	_clear_direction_arrows()
	if tactical_battle_state == null or battle_grid == null:
		return
	var unit = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
	if unit == null:
		return
	var src := Vector2i(int(unit.cell.get("q", 0)), int(unit.cell.get("r", 0)))
	var dirs := [
		{"d": Vector2i(0, -1), "label": "↑"},
		{"d": Vector2i(0, 1), "label": "↓"},
		{"d": Vector2i(-1, 0), "label": "←"},
		{"d": Vector2i(1, 0), "label": "→"},
	]
	for entry in dirs:
		var d: Vector2i = entry["d"]
		var nb := src + d
		if nb.x < 0 or nb.x >= 8 or nb.y < 0 or nb.y >= 6:
			continue
		var btn := Button.new()
		btn.text = str(entry["label"])
		btn.size = Vector2(32, 32)
		btn.position = battle_grid.position + battle_grid.grid_to_pixel(nb) - Vector2(16, 16)
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Color(1, 0.92, 0.45))
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_direction_chosen.bind(skill_id, d))
		add_child(btn)
		_direction_buttons.append(btn)

# 清空当前 4 方向箭头按钮（释放招式或切换模式时调用）。
func _clear_direction_arrows() -> void:
	for b in _direction_buttons:
		if is_instance_valid(b):
			b.queue_free()
	_direction_buttons.clear()

# 玩家点了某方向 → 计算线性范围 → 走通用 resolve_action 路径释放。
func _on_direction_chosen(skill_id: String, direction: Vector2i) -> void:
	_clear_direction_arrows()
	if tactical_battle_state == null:
		_pending_skill_id = ""
		_set_range_mode(RangeMode.NONE, [])
		return
	var unit = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
	if unit == null:
		_pending_skill_id = ""
		_set_range_mode(RangeMode.NONE, [])
		return
	var view := _unit_view_for_range(unit)
	var cells: Array = tactical_range_system.get_skill_directional_range(view, skill_id, direction)
	_resolve_skill_action(skill_id, cells)

# Task 17/18 共用：执行招式 → 行动结束 → 刷新 UI → 检查战斗结算。
func _resolve_skill_action(skill_id: String, target_cells: Array) -> void:
	_pending_skill_id = ""
	_clear_direction_arrows()
	_set_range_mode(RangeMode.NONE, [])
	if tactical_battle_state == null:
		return
	var current_id := str(tactical_battle_state.current_unit_id)
	var result: Dictionary = tactical_combat_system.resolve_action(tactical_battle_state, current_id, skill_id, target_cells)
	# 招式失败（内力不足等）保留行动相位让玩家重选；成功才结束行动。
	if bool(result.get("success", false)) and not tactical_battle_state.is_finished:
		tactical_combat_system.end_unit_action(tactical_battle_state, current_id)
	_refresh_tactical()
	_return_if_tactical_finished()

# ─── Task 19: 移动滑动动画 ───────────────────────────────────────────────────

# 检查 target_cell 是否在 movable_cells 内 → 是则播 sprite.animate_to 滑动；
# 动画结束才落地 move_unit + emit tactical_unit_moved。
# 返回 true = 动画已启动；false = 不可移动（caller 自行兜底）。
func _start_move_animation(unit, target_cell: Dictionary) -> bool:
	if unit == null or tactical_battle_state == null or battle_grid == null:
		return false
	if not _cell_in_list(target_cell, tactical_combat_system.get_movable_cells(tactical_battle_state, str(unit.unit_id))):
		return false
	var sprite = _unit_sprites.get(str(unit.unit_id))
	var src_q: int = int(unit.cell.get("q", 0))
	var src_r: int = int(unit.cell.get("r", 0))
	var dst := Vector2i(int(target_cell.get("q", 0)), int(target_cell.get("r", 0)))
	# sprite 不存在的兜底（理论不会发生）：直接同步 commit。
	if sprite == null or not is_instance_valid(sprite):
		tactical_combat_system.move_unit(tactical_battle_state, str(unit.unit_id), target_cell)
		EventBus.tactical_unit_moved.emit(str(unit.unit_id), Vector2i(src_q, src_r), dst)
		_refresh_tactical()
		return true
	var distance: int = abs(dst.x - src_q) + abs(dst.y - src_r)
	var duration: float = 0.18 * float(max(1, distance))
	is_animating = true
	_move_anim_target_cell = target_cell.duplicate()
	sprite.animation_finished.connect(_on_move_animation_done.bind(str(unit.unit_id), src_q, src_r), CONNECT_ONE_SHOT)
	sprite.animate_to(battle_grid.grid_to_pixel(dst), duration)
	return true

# 滑动动画完成 → 落地 move_unit → 广播 → 刷新。
func _on_move_animation_done(unit_id: String, from_q: int, from_r: int) -> void:
	is_animating = false
	if tactical_battle_state == null:
		_move_anim_target_cell = {}
		return
	var target_cell: Dictionary = _move_anim_target_cell.duplicate()
	_move_anim_target_cell = {}
	if target_cell.is_empty():
		_refresh_tactical()
		return
	var result: Dictionary = tactical_combat_system.move_unit(tactical_battle_state, unit_id, target_cell)
	if bool(result.get("success", false)):
		var to_cell := Vector2i(int(target_cell.get("q", 0)), int(target_cell.get("r", 0)))
		EventBus.tactical_unit_moved.emit(unit_id, Vector2i(from_q, from_r), to_cell)
	_refresh_tactical()
	_return_if_tactical_finished()

# 工具：在 movable_cells 列表里查 target_cell（{q,r} dict 形式）是否存在。
func _cell_in_list(target_cell: Dictionary, list: Array) -> bool:
	var tq: int = int(target_cell.get("q", -999))
	var tr: int = int(target_cell.get("r", -999))
	for c in list:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		if int(c.get("q", -1000)) == tq and int(c.get("r", -1000)) == tr:
			return true
	return false
