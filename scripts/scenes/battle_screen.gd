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
const ProficiencySystemScript = preload("res://scripts/systems/proficiency_system.gd")
const BattleFeedbackDirectorScript = preload("res://scripts/systems/battle_feedback_director.gd")
const TACTICAL_CELL_SIZE := 80  # 与 battle_grid TILE_SIZE 一致
const TACTICAL_GRID_OFFSET := Vector2.ZERO
# v0.x: 16×9 棋盘 × 80px = 1280×720，铺满战斗视口。
const TACTICAL_GRID_ORIGIN := Vector2.ZERO

enum RangeMode { NONE = 0, MOVE = 1, ATTACK = 2, SKILL_DIR_PREVIEW = 3, SKILL_TARGET_PREVIEW = 4, SKILL_AIM = 5 }

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
# Task 20: 删除 unit_panel/normal_attack_button/end_action_button/tactical_art_buttons/cell_visuals。
# cell_buttons 仍保留：当前点击命中仍依赖每格 Button.pressed 信号；视觉高亮已迁至 battle_grid.set_range_overlay。
var selected_tactical_action_id: String = "attack"
var cell_buttons: Dictionary = {}
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
var _proficiency_system = null
# Task 19: 移动滑动动画锁
var is_animating := false
var _move_anim_target_cell: Dictionary = {}  # 动画结束后 commit_move 用的目标格
# v0.x: 本回合「已移动一次」锁 + ESC 撤销。
# 一次行动只允许移动一次；未提交「攻击/技能/待机」前可按 ESC 回到移动前位置。
var _has_moved_this_action := false
var _pre_move_cell: Dictionary = {}
var _last_action_unit_id: String = ""
var _pending_enemy_move_unit_id: String = ""
var _feedback_director = null
var _feedback_hitstop_sec := 0.0

func _ready() -> void:
	_feedback_director = BattleFeedbackDirectorScript.new()
	_proficiency_system = ProficiencySystemScript.new()
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
	if _feedback_hitstop_sec > 0.0:
		_feedback_hitstop_sec = max(0.0, _feedback_hitstop_sec - delta)
		_refresh_charge_bar()
		_poll_terrain_hover()
		return
	if not tactical_battle_state.is_action_phase:
		tactical_combat_system.advance_charge(tactical_battle_state, delta)
		_refresh_tactical()
	if tactical_battle_state.is_action_phase:
		var unit = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
		if unit != null and unit.team == TacticalBattleStateScript.TEAM_ENEMY:
			if _pending_enemy_move_unit_id.is_empty():
				_run_enemy_action_with_animation(unit)
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
	# v0.x 修复：删除 title_label/status_label/output/retreat_button/grid_layer 5 个旧节点。
	# 旧节点职能已被以下面板/控件接管：
	#   - title/status → panel_actor + charge_bar
	#   - output       → battle_log
	#   - retreat      → action_bar 的 system 图标（待后续接入）
	#   - grid_layer   → cell_buttons 直接挂到 battle_grid 下，与 32px tile 共坐标系
	battle_grid = BattleGridScript.new()
	battle_grid.position = TACTICAL_GRID_ORIGIN
	add_child(battle_grid)
	var terrain_system = TerrainSystemScript.new()
	terrain_system.set_repository(DataRepository)
	if tactical_battle_state != null:
		battle_grid.setup(tactical_battle_state.terrain_grid, terrain_system)
	tactical_range_system.set_terrain_system(terrain_system)
	_terrain_system = terrain_system

	_create_tactical_grid()
	_build_unit_sprites()
	# Task 12: 底部 7 图标行动栏（与旧按钮并存，旧按钮 Task 20 再清）。
	action_bar = BattleActionBarScript.new()
	action_bar.position = Vector2(290, 620)  # v0.x: 与 80px tile grid 底边 (580) 保持 40px 间隙
	add_child(action_bar)
	action_bar.action_selected.connect(_on_action_bar_selected)
	# Task 13: 顶部集气进度条（800 宽，置于左右面板之间空隙）。
	charge_bar = ChargeBarScript.new()
	charge_bar.position = Vector2(240, 24)  # v0.x: 上移到 grid (y=100) 上方 70px 间隙，避免遮挡第一行 HP 条
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
	panel_terrain.position = Vector2(8, 360)  # v0.x: 上提，避免与新 action_bar/grid 底部重叠
	panel_terrain.size = Vector2(200, 230)
	panel_terrain.custom_minimum_size = Vector2(200, 230)
	add_child(panel_terrain)
	# Task 15: 右上当前行动角色状态卡。
	panel_actor = BattlePanelActorScript.new()
	panel_actor.position = Vector2(1072, 8)
	panel_actor.size = Vector2(200, 240)
	panel_actor.custom_minimum_size = Vector2(200, 240)
	add_child(panel_actor)
	EventBus.hero_mp_changed.connect(_on_hero_mp_changed_for_actor_panel)
	# Task 16: 右下战斗日志面板。
	battle_log = BattleLogScript.new()
	battle_log.position = Vector2(1072, 360)  # v0.x: 上提与 panel_terrain 对齐
	battle_log.size = Vector2(200, 230)
	battle_log.custom_minimum_size = Vector2(200, 230)
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
		var is_enemy_unit := str(unit.team) == TacticalBattleStateScript.TEAM_ENEMY
		sprite.setup(str(unit.unit_id), str(unit.sprite_tile_id), int(unit.max_hp), is_enemy_unit)
		sprite.position = battle_grid.grid_to_pixel(Vector2i(int(unit.cell.get("q", 0)), int(unit.cell.get("r", 0))))
		_unit_sprites[str(unit.unit_id)] = sprite

func _create_tactical_grid() -> void:
	cell_buttons.clear()
	for q in range(tactical_battle_state.battlefield_width):
		for r in range(tactical_battle_state.battlefield_height):
			var cell = {"q": q, "r": r}
			var cell_key = _cell_key(cell)
			var button = Button.new()
			button.text = ""
			button.size = Vector2(TACTICAL_CELL_SIZE, TACTICAL_CELL_SIZE)
			button.position = _cell_to_screen(cell)
			button.flat = true
			button.focus_mode = Control.FOCUS_NONE
			_apply_tactical_cell_style(button)
			button.pressed.connect(_on_tactical_cell_pressed.bind(q, r))
			battle_grid.add_child(button)  # 与地形 tile 共坐标系
			cell_buttons[cell_key] = button

func _create_tactical_art_button(_martial_art_id: String, _button_position: Vector2) -> void:
	# Task 20: 旧接口保留为空壳，防止外部调用者报错；期间不创建任何节点。
	pass

func _refresh_tactical() -> void:
	if tactical_battle_state == null:
		return
	# v0.x: 检测行动单位切换 → 重置「已移动」锁与撤销点。
	var cur_id := str(tactical_battle_state.current_unit_id)
	if cur_id != _last_action_unit_id:
		_last_action_unit_id = cur_id
		_has_moved_this_action = false
		_pre_move_cell = {}
	# status_label / output / retreat_button 已删除；行动者/HP/MP 由 panel_actor 显示，日志由 battle_log 显示。
	var movable: Array = []
	var attackable: Array = []
	if _is_player_action():
		# v0.x: 统一用 range_system.get_move_range，包含地形可通行性 + 敌方占据过滤，
		# 与「移动」按钮高亮所用逻辑一致，避免「高亮 4 格但实际可点别处」 bug。
		var current_unit2 = tactical_battle_state.get_unit(cur_id)
		if current_unit2 != null:
			var view2 := _unit_view_for_range(current_unit2)
			var move_cells_v2i: Array = tactical_range_system.get_move_range(view2, tactical_battle_state.terrain_grid, _enemy_positions())
			for v in move_cells_v2i:
				movable.append({"q": int(v.x), "r": int(v.y)})
		attackable = _get_attackable_units_for_selected_action()
	for key in cell_buttons.keys():
		var button = cell_buttons[key]
		button.text = ""  # 名字由像素 sprite 表达，cell button 不再显示文字
		button.disabled = true
	for unit in tactical_battle_state.units:
		if not unit.is_alive():
			continue
		# 旧 cell_buttons 文字标签删除：单位名/位置由 sprite 与 panel_actor 体现。
	# v0.x: 只在有对应「动作模式」时才启用格子点击：
	#  - MOVE: 启用可移动格
	#  - ATTACK: 启用可攻击敌方格
	#  - SKILL_TARGET_PREVIEW: 启用中心选择格
	#  - 其它（NONE / SKILL_DIR_PREVIEW）：所有格保持 disabled
	if range_mode == RangeMode.MOVE:
		for cell in movable:
			var move_key = _cell_key(cell)
			if cell_buttons.has(move_key):
				cell_buttons[move_key].disabled = false
	elif range_mode == RangeMode.ATTACK:
		for target in attackable:
			var target_key = _cell_key(target.cell)
			if cell_buttons.has(target_key):
				cell_buttons[target_key].disabled = false
	elif range_mode == RangeMode.SKILL_TARGET_PREVIEW or range_mode == RangeMode.SKILL_AIM:
		for v in range_cells:
			if typeof(v) != TYPE_VECTOR2I:
				continue
			var k := "%d:%d" % [int(v.x), int(v.y)]
			if cell_buttons.has(k):
				cell_buttons[k].disabled = false

	# 日志由 battle_log（EventBus.tactical_log_appended）写入；retreat 已并入 action_bar.system。
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
			var is_enemy_unit := str(unit.team) == TacticalBattleStateScript.TEAM_ENEMY
			sprite.setup(uid, str(unit.sprite_tile_id), int(unit.max_hp), is_enemy_unit)
			_unit_sprites[uid] = sprite
		sprite.position = battle_grid.grid_to_pixel(Vector2i(int(unit.cell.get("q", 0)), int(unit.cell.get("r", 0))))
		sprite.set_hp(int(unit.hp), int(unit.max_hp))
		sprite.set_current_actor(uid == current_id and not tactical_battle_state.is_finished)
		sprite.set_selected(uid == selected_unit_id)
		sprite.visible = unit.is_alive()
		# 贴图层按 r 排序；HP 条与标记在 TacticalUnitSprite 内部固定为更高全局层。
		sprite.set_world_sprite_z(int(unit.cell.get("r", 0)) * 2 + 20)
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
	# SKILL_AIM 模式：范围内点击确认释放，范围外点击取消。
	if range_mode == RangeMode.SKILL_AIM and not _pending_skill_id.is_empty():
		var clicked := Vector2i(q, r)
		var hit := false
		for c in range_cells:
			if typeof(c) == TYPE_VECTOR2I and Vector2i(c) == clicked:
				hit = true
				break
		if hit:
			_resolve_skill_action(_pending_skill_id, range_cells)
		else:
			_pending_skill_id = ""
			_clear_direction_arrows()
			_set_range_mode(RangeMode.NONE, [])
			_refresh_tactical()
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
		var blast: Array = tactical_range_system.get_skill_target_blast_range(_pending_skill_id, clicked, tactical_battle_state.terrain_grid)
		_resolve_skill_action(_pending_skill_id, blast)
		return
	var cell = {"q": q, "r": r}
	var target = _unit_at_cell(cell)
	# v0.x: 攻击必须先选「普攻」或「技能」；MOVE 模式下点敌人不生效。
	if target != null and target.team != current_unit.team:
		if range_mode != RangeMode.ATTACK:
			return
		var target_hp_before := int(target.hp)
		var result: Dictionary
		if selected_tactical_action_id == "attack":
			result = tactical_combat_system.attack_unit(tactical_battle_state, current_unit.unit_id, target.unit_id)
		else:
			result = tactical_combat_system.use_martial_art(tactical_battle_state, current_unit.unit_id, target.unit_id, selected_tactical_action_id, DataRepository)
		if bool(result.get("success", false)):
			_emit_damage_feedback(str(target.unit_id), target_hp_before, int(target.hp))
			if not tactical_battle_state.is_finished:
				tactical_combat_system.end_unit_action(tactical_battle_state, current_unit.unit_id)
		_set_range_mode(RangeMode.NONE, [])
		_refresh_tactical()
		_return_if_tactical_finished()
		return
	# v0.x: 移动必须先点底部「移动」按钮进入 MOVE 模式，避免误操作。
	if range_mode != RangeMode.MOVE:
		return
	# Task 19 / v0.x: 走移动 → BFS 路径 → 逐格滑动动画 → 动画结束才 commit_move。
	if _start_move_animation(current_unit, cell):
		return
	# 不可移动则原地刷新（兜底，几乎不会触发）。
	_refresh_tactical()

func _get_attackable_units_for_selected_action() -> Array:
	if selected_tactical_action_id == "attack":
		return tactical_combat_system.get_attackable_units(tactical_battle_state, tactical_battle_state.current_unit_id)
	return tactical_combat_system.get_attackable_units_for_martial_art(tactical_battle_state, tactical_battle_state.current_unit_id, selected_tactical_action_id, DataRepository)

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

func _enqueue_feedback_event(event: Dictionary) -> void:
	if _feedback_director == null:
		return
	_feedback_director.enqueue(event)

func _consume_feedback_events() -> void:
	if _feedback_director == null:
		return
	_apply_feedback_commands(_feedback_director.consume_commands())

func _emit_feedback_event(event: Dictionary) -> void:
	_enqueue_feedback_event(event)
	_consume_feedback_events()

func _apply_feedback_commands(commands: Array) -> void:
	if commands.is_empty():
		return
	for command in commands:
		if typeof(command) != TYPE_DICTIONARY:
			continue
		var cmd := str(command.get("cmd", ""))
		match cmd:
			"hitstop":
				var ms: int = max(0, int(command.get("ms", 0)))
				if ms > 0:
					_feedback_hitstop_sec = max(_feedback_hitstop_sec, float(ms) / 1000.0)
			"flash_unit":
				_flash_feedback_unit(str(command.get("unit_id", "")))
			"pop_text":
				# TacticalUnitSprite.set_hp 已自带受击数字，避免双飘字。
				continue
			_:
				continue

func _enqueue_damage_feedback(unit_id: String, hp_before: int, hp_after: int) -> bool:
	if unit_id.is_empty():
		return false
	var delta := int(hp_after - hp_before)
	if delta == 0:
		return false
	_enqueue_feedback_event({"type": "hit_start", "unit_id": unit_id})
	_enqueue_feedback_event({"type": "hp_changed", "unit_id": unit_id, "delta": delta})
	return true

func _emit_damage_feedback(unit_id: String, hp_before: int, hp_after: int) -> void:
	if _enqueue_damage_feedback(unit_id, hp_before, hp_after):
		_consume_feedback_events()

func _collect_hp_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	if tactical_battle_state == null:
		return snapshot
	for unit in tactical_battle_state.units:
		snapshot[str(unit.unit_id)] = int(unit.hp)
	return snapshot

func _emit_multi_hit_feedback(hits: Array, hp_before: Dictionary) -> void:
	if tactical_battle_state == null:
		return
	var has_feedback := false
	for hit in hits:
		var unit_id := str(hit)
		if unit_id.is_empty() or not hp_before.has(unit_id):
			continue
		var unit: Variant = tactical_battle_state.get_unit(unit_id)
		if unit == null:
			continue
		if _enqueue_damage_feedback(unit_id, int(hp_before.get(unit_id, int(unit.hp))), int(unit.hp)):
			has_feedback = true
	if has_feedback:
		_consume_feedback_events()

func _flash_feedback_unit(unit_id: String) -> void:
	if unit_id.is_empty():
		return
	var sprite: Node2D = _unit_sprites.get(unit_id)
	if sprite == null or not is_instance_valid(sprite):
		return
	if sprite.has_method("play_hit_feedback"):
		sprite.call("play_hit_feedback", 0.10, 6.0)
		return
	if get_tree() == null:
		return
	var base_modulate: Color = sprite.modulate
	sprite.modulate = Color(1.0, 0.72, 0.72, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", base_modulate, 0.12)

func _spawn_feedback_pop_text(unit_id: String, delta: int) -> void:
	if unit_id.is_empty() or delta == 0:
		return
	var sprite: Node2D = _unit_sprites.get(unit_id)
	if sprite == null or not is_instance_valid(sprite):
		return
	if get_tree() == null:
		return
	var label: Label = Label.new()
	var abs_delta: int = abs(delta)
	var prefix: String = "+"
	var color: Color = Color(0.50, 0.88, 0.50)
	if delta < 0:
		prefix = "-"
		color = Color(1.0, 0.35, 0.30)
	label.text = "%s%d" % [prefix, abs_delta]
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.z_as_relative = false
	label.z_index = 2600
	var start_pos: Vector2 = (sprite.global_position - global_position) + Vector2(-18, -64)
	label.position = start_pos
	add_child(label)
	var tween: Tween = create_tween()
	tween.tween_property(label, "position", start_pos + Vector2(0, -20), 0.24)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.24)
	tween.tween_callback(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)

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
			# v0.x: 本回合已移动一次 → 拒绝再进 MOVE 模式（需先按 ESC 撤销。顶部提示后续可加）。
			if _has_moved_this_action:
				return
			var cells := tactical_range_system.get_move_range(view, tactical_battle_state.terrain_grid, _enemy_positions())
			_set_range_mode(RangeMode.MOVE, cells)
			_refresh_tactical()
		"attack":
			var cells := tactical_range_system.get_attack_range_simple(view, tactical_battle_state.terrain_grid)
			_set_range_mode(RangeMode.ATTACK, cells)
			_refresh_tactical()
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
# v0.x: 额外传 sprite_tile_id，用于集气条绘制角色缩略徽章。
func _refresh_charge_bar() -> void:
	if charge_bar == null or tactical_battle_state == null:
		return
	var current_id := str(tactical_battle_state.current_unit_id)
	var next_id := _predict_next_charge_actor_id(current_id)
	var dicts: Array = []
	for unit in tactical_battle_state.units:
		if not unit.is_alive():
			continue
		var uid := str(unit.unit_id)
		var team := 0 if unit.team == TacticalBattleStateScript.TEAM_PLAYER else 1
		dicts.append({
			"unit_id": uid,
			"team": team,
			"cur_charge": int(unit.charge),
			"sprite_tile_id": str(unit.sprite_tile_id),
			"is_action": tactical_battle_state.is_action_phase and uid == current_id,
			"is_next_action": uid == next_id,
		})
	charge_bar.set_units(dicts)

func _predict_next_charge_actor_id(current_id: String) -> String:
	if tactical_battle_state == null:
		return ""
	var ready: Variant = tactical_combat_system.get_ready_unit_excluding(tactical_battle_state, current_id)
	if ready != null:
		return str(ready.unit_id)
	var best_uid: String = ""
	var best_eta: float = INF
	var best_team_priority: int = 2
	for unit in tactical_battle_state.units:
		if not unit.is_alive():
			continue
		var uid := str(unit.unit_id)
		if uid == current_id:
			continue
		var speed: int = int(unit.charge_speed)
		if speed <= 0:
			continue
		var remain: int = maxi(0, TacticalBattleStateScript.CHARGE_LIMIT - int(unit.charge))
		var eta: float = float(remain) / float(speed)
		var team_priority: int = 0 if unit.team == TacticalBattleStateScript.TEAM_PLAYER else 1
		if eta < best_eta:
			best_eta = eta
			best_team_priority = team_priority
			best_uid = uid
		elif is_equal_approx(eta, best_eta):
			if team_priority < best_team_priority:
				best_team_priority = team_priority
				best_uid = uid
	return best_uid

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
	# battle_grid 是 Node2D，position 是其全局原点；TILE_SIZE 与 BattleGrid.TILE_SIZE 一致。
	var local: Vector2 = get_global_mouse_position() - battle_grid.global_position
	var tile_size := TACTICAL_CELL_SIZE
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
		var sign_str := "+" if ev >= 0 else ""
		# v0.x: 本作不采用「移动消耗」设定，只展示闪避加成。
		var effect := "闪避 %s%d%%" % [sign_str, ev]
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
		return
	# v0.x: 未提交「攻击/技能/待机」前按 ESC 可撤销本回合的移动，回到移动前位置。
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _try_undo_move():
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

# Task 15: 右上状态卡只显示「当前正在行动的角色」；
# 若无行动单位（例如尚未轮到任何人 / 战斗结束），则隐藏状态卡。
func _refresh_actor_panel() -> void:
	if panel_actor == null or tactical_battle_state == null:
		return
	var unit = _pick_actor_panel_unit()
	panel_actor.visible = unit != null
	panel_actor.set_actor(unit)

func _pick_actor_panel_unit():
	if tactical_battle_state == null:
		return null
	var current_id := str(tactical_battle_state.current_unit_id)
	if current_id.is_empty():
		return null
	return tactical_battle_state.get_unit(current_id)

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
			var skill_name: String = str(data.get("name", sid_s))
			var thresholds: Array = data.get("proficiency_thresholds", [])
			var use_count := int(GameState.martial_proficiency.get(sid_s, 0))
			var level := 0
			if _proficiency_system != null:
				level = _proficiency_system.get_level(use_count, thresholds)
			var label := skill_name
			if level > 0:
				label = "%s Lv.%d" % [skill_name, level]
			menu.add_item("%s（内力不足）" % label)
			menu.set_item_disabled(menu.get_item_count() - 1, true)
		else:
			var skill_name: String = str(data.get("name", sid_s))
			var thresholds: Array = data.get("proficiency_thresholds", [])
			var use_count := int(GameState.martial_proficiency.get(sid_s, 0))
			var level := 0
			if _proficiency_system != null:
				level = _proficiency_system.get_level(use_count, thresholds)
			var label := skill_name
			if level > 0:
				label = "%s Lv.%d" % [skill_name, level]
			menu.add_item(label)
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

# 根据招式 shape 切换到 SKILL_DIR_PREVIEW（方向箭头）或 SKILL_TARGET_PREVIEW（中心格），
# 或 surround/ring 为自身中心释放直接执行。
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
		var centers: Array = tactical_range_system.get_skill_target_selection_range(view, skill_id, cast_range, tactical_battle_state.terrain_grid)
		_set_range_mode(RangeMode.SKILL_TARGET_PREVIEW, centers)
	elif shape == "fan" or shape == "pierce":
		_set_range_mode(RangeMode.SKILL_DIR_PREVIEW, [])
		_show_direction_arrows(skill_id)
	elif shape == "surround" or shape == "ring":
		var unit = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
		var view := _unit_view_for_range(unit)
		var cells: Array
		if shape == "surround":
			cells = tactical_range_system.get_surround_range(view, tactical_battle_state.terrain_grid)
		else:
			var range_val: int = int(data.get("tactical", {}).get("range", 2))
			cells = tactical_range_system.get_ring_range(view, range_val, tactical_battle_state.terrain_grid)
		_set_range_mode(RangeMode.SKILL_AIM, cells)
		_refresh_tactical()
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
	var view := _unit_view_for_range(unit)
	var data: Dictionary = DataRepository.get_martial_art(skill_id)
	var shape := str(data.get("shape", ""))
	var tactical_range: int = int(data.get("tactical", {}).get("range", 2))
	var dirs := [
		{"d": Vector2i(0, -1), "label": "↑"},
		{"d": Vector2i(0, 1), "label": "↓"},
		{"d": Vector2i(-1, 0), "label": "←"},
		{"d": Vector2i(1, 0), "label": "→"},
	]
	for entry in dirs:
		var d: Vector2i = entry["d"]
		var nb := src + d
		var dims := _battlefield_dims()
		if nb.x < 0 or nb.x >= dims.x or nb.y < 0 or nb.y >= dims.y:
			continue
		var btn := Button.new()
		btn.text = str(entry["label"])
		btn.size = Vector2(TACTICAL_CELL_SIZE, TACTICAL_CELL_SIZE)
		btn.position = battle_grid.position + battle_grid.grid_to_pixel(nb) - Vector2(TACTICAL_CELL_SIZE / 2.0, TACTICAL_CELL_SIZE / 2.0)
		btn.add_theme_font_size_override("font_size", 32)
		btn.add_theme_color_override("font_color", Color(1, 0.92, 0.45))
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_entered.connect(_on_direction_hovered.bind(skill_id, shape, tactical_range, d))
		btn.mouse_exited.connect(_on_direction_unhovered)
		btn.pressed.connect(_on_direction_chosen.bind(skill_id, d))
		add_child(btn)
		_direction_buttons.append(btn)

func _on_direction_hovered(skill_id: String, shape: String, tactical_range: int, direction: Vector2i) -> void:
	if tactical_battle_state == null:
		return
	var unit = tactical_battle_state.get_unit(tactical_battle_state.current_unit_id)
	if unit == null:
		return
	var view := _unit_view_for_range(unit)
	var cells: Array
	if shape == "fan":
		cells = tactical_range_system.get_fan_range(view, direction, tactical_range, tactical_battle_state.terrain_grid)
	elif shape == "pierce":
		cells = tactical_range_system.get_pierce_range(view, direction, tactical_range, tactical_battle_state.terrain_grid)
	else:
		cells = tactical_range_system.get_skill_directional_range(view, skill_id, direction, tactical_battle_state.terrain_grid)
	if battle_grid != null:
		battle_grid.set_range_overlay(RangeMode.SKILL_AIM, cells)

func _on_direction_unhovered() -> void:
	if battle_grid != null and range_mode == RangeMode.SKILL_DIR_PREVIEW:
		battle_grid.set_range_overlay(RangeMode.SKILL_DIR_PREVIEW, [])

# 清空当前 4 方向箭头按钮（释放招式或切换模式时调用）。
func _clear_direction_arrows() -> void:
	for b in _direction_buttons:
		if is_instance_valid(b):
			b.queue_free()
	_direction_buttons.clear()

# 玩家点了某方向 → 根据招式 shape 调用对应范围算法 → 进入 SKILL_AIM 确认。
func _on_direction_chosen(skill_id: String, direction: Vector2i) -> void:
	# 隐藏箭头立即，deferred 释放避免同帧鼠标捕获干扰 cell button 点击
	for b in _direction_buttons:
		if is_instance_valid(b):
			b.visible = false
	call_deferred("_clear_direction_arrows")
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
	var data: Dictionary = DataRepository.get_martial_art(skill_id)
	var shape := str(data.get("shape", ""))
	var tactical_range: int = int(data.get("tactical", {}).get("range", 2))
	var cells: Array
	if shape == "fan":
		cells = tactical_range_system.get_fan_range(view, direction, tactical_range, tactical_battle_state.terrain_grid)
	elif shape == "pierce":
		cells = tactical_range_system.get_pierce_range(view, direction, tactical_range, tactical_battle_state.terrain_grid)
	else:
		cells = tactical_range_system.get_skill_directional_range(view, skill_id, direction, tactical_battle_state.terrain_grid)
	_set_range_mode(RangeMode.SKILL_AIM, cells)
	_refresh_tactical()

# Task 17/18 共用：执行招式 → 行动结束 → 刷新 UI → 检查战斗结算。
func _resolve_skill_action(skill_id: String, target_cells: Array) -> void:
	_pending_skill_id = ""
	_clear_direction_arrows()
	_set_range_mode(RangeMode.NONE, [])
	if tactical_battle_state == null:
		return
	var current_id := str(tactical_battle_state.current_unit_id)
	var hp_before := _collect_hp_snapshot()
	var result: Dictionary = tactical_combat_system.resolve_action(tactical_battle_state, current_id, skill_id, target_cells)
	# 招式失败（内力不足等）保留行动相位让玩家重选；成功才结束行动。
	if bool(result.get("success", false)) and not tactical_battle_state.is_finished:
		_emit_multi_hit_feedback(result.get("hits", []), hp_before)
		tactical_combat_system.end_unit_action(tactical_battle_state, current_id)
	elif bool(result.get("success", false)):
		_emit_multi_hit_feedback(result.get("hits", []), hp_before)
	_refresh_tactical()
	_return_if_tactical_finished()

# ─── Task 19: 移动滑动动画 ───────────────────────────────────────────────────

# 检查 target_cell 是否在 movable_cells 内 → 是则 BFS 求路径，按格逐步滑动。
# 动画结束才落地 move_unit + emit tactical_unit_moved。
# 返回 true = 动画已启动；false = 不可移动（caller 自行兜底）。
func _start_move_animation(unit, target_cell: Dictionary) -> bool:
	if unit == null or tactical_battle_state == null or battle_grid == null:
		return false
	var movable: Array = tactical_combat_system.get_movable_cells(tactical_battle_state, str(unit.unit_id))
	if not _cell_in_list(target_cell, movable):
		return false
	var sprite = _unit_sprites.get(str(unit.unit_id))
	var src_q: int = int(unit.cell.get("q", 0))
	var src_r: int = int(unit.cell.get("r", 0))
	var dst := Vector2i(int(target_cell.get("q", 0)), int(target_cell.get("r", 0)))
	# sprite 不存在的兜底（理论不会发生）：直接同步 commit。
	if sprite == null or not is_instance_valid(sprite):
		tactical_combat_system.move_unit(tactical_battle_state, str(unit.unit_id), target_cell)
		EventBus.tactical_unit_moved.emit(str(unit.unit_id), Vector2i(src_q, src_r), dst)
		_set_range_mode(RangeMode.NONE, [])
		_refresh_tactical()
		return true
	# v0.x: BFS 求最短曼哈顿路径（仅穿过 movable 格 + 起点），让精灵走格而非斜线穿场。
	var path_cells: Array = _compute_move_path(Vector2i(src_q, src_r), dst, movable)
	var pixel_points: Array = []
	for pc in path_cells:
		pixel_points.append(battle_grid.grid_to_pixel(pc))
	var per_step: float = 0.12  # 每格 120ms，比旧总时长 0.18s/格 略快、单步更清晰
	is_animating = true
	_move_anim_target_cell = target_cell.duplicate()
	sprite.animation_finished.connect(_on_move_animation_done.bind(str(unit.unit_id), src_q, src_r), CONNECT_ONE_SHOT)
	if pixel_points.is_empty():
		# 兜底：BFS 没找到路径（理论不会发生，因为 dst 在 movable 内），直接一步到位。
		sprite.animate_to(battle_grid.grid_to_pixel(dst), 0.18)
	else:
		sprite.animate_along_path(pixel_points, per_step)
	return true

# v0.x: BFS 在 movable + 起点 集合内求 src→dst 4 邻最短路径，返回 Array[Vector2i]，不含起点、含终点。
# 若不可达返回空数组，由 caller 兜底。
func _compute_move_path(src: Vector2i, dst: Vector2i, movable: Array) -> Array:
	if src == dst:
		return []
	var allowed: Dictionary = {src: true}
	for c in movable:
		if typeof(c) == TYPE_DICTIONARY:
			allowed[Vector2i(int(c.get("q", 0)), int(c.get("r", 0)))] = true
	if not allowed.has(dst):
		return []
	var parent: Dictionary = {}
	var visited: Dictionary = {src: true}
	var queue: Array = [src]
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()
		if cur == dst:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + d
			if visited.has(nb) or not allowed.has(nb):
				continue
			visited[nb] = true
			parent[nb] = cur
			queue.append(nb)
	if not parent.has(dst):
		return []
	var rev: Array = [dst]
	var cur2: Vector2i = dst
	while parent.has(cur2):
		cur2 = parent[cur2]
		if cur2 == src:
			break
		rev.append(cur2)
	rev.reverse()
	return rev

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
	# v0.x: 记录本回合移动前位置，供 ESC 撤销使用；并锁定「本回合不能再移动」。
	var result: Dictionary = tactical_combat_system.move_unit(tactical_battle_state, unit_id, target_cell)
	if bool(result.get("success", false)):
		var to_cell := Vector2i(int(target_cell.get("q", 0)), int(target_cell.get("r", 0)))
		EventBus.tactical_unit_moved.emit(unit_id, Vector2i(from_q, from_r), to_cell)
		_has_moved_this_action = true
		_pre_move_cell = {"q": from_q, "r": from_r}
	if unit_id == _pending_enemy_move_unit_id:
		_pending_enemy_move_unit_id = ""
		_resolve_enemy_post_move(unit_id)
		return
	# v0.x: 移动落地后清 range_mode，避免高亮残留、避免玩家连点又动。
	_set_range_mode(RangeMode.NONE, [])
	_refresh_tactical()
	_return_if_tactical_finished()

# v0.x: ESC 撤销本回合移动。仅在：
#  - 当前是玩家行动相
#  - 本回合已移动 且 记录了移动前位置
#  - 未进行攻击/技能提交（该状态下 current_unit_id 未变 + 未 finished）
# 返回 true = 已撤销；false = 不满足条件。
func _try_undo_move() -> bool:
	if tactical_battle_state == null or is_animating:
		return false
	if not _is_player_action():
		return false
	if not _has_moved_this_action or _pre_move_cell.is_empty():
		return false
	var unit_id := str(tactical_battle_state.current_unit_id)
	var unit = tactical_battle_state.get_unit(unit_id)
	if unit == null:
		return false
	var from_cell := Vector2i(int(unit.cell.get("q", 0)), int(unit.cell.get("r", 0)))
	unit.cell = {"q": int(_pre_move_cell.get("q", 0)), "r": int(_pre_move_cell.get("r", 0))}
	var to_cell := Vector2i(int(unit.cell.get("q", 0)), int(unit.cell.get("r", 0)))
	EventBus.tactical_unit_moved.emit(unit_id, from_cell, to_cell)
	_has_moved_this_action = false
	_pre_move_cell = {}
	_set_range_mode(RangeMode.NONE, [])
	_refresh_tactical()
	return true

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

func _run_enemy_action_with_animation(unit) -> void:
	if unit == null or tactical_battle_state == null:
		return
	var enemy_id := str(unit.unit_id)
	var target = _pick_enemy_target(unit)
	if target == null:
		if not tactical_battle_state.is_finished:
			tactical_combat_system.end_unit_action(tactical_battle_state, enemy_id)
		_refresh_tactical()
		_return_if_tactical_finished()
		return
	if _cell_distance_dict(unit.cell, target.cell) <= int(unit.attack_range):
		var target_hp_before := int(target.hp)
		var attack_result := tactical_combat_system.attack_unit(tactical_battle_state, enemy_id, str(target.unit_id))
		if bool(attack_result.get("success", false)):
			_emit_damage_feedback(str(target.unit_id), target_hp_before, int(target.hp))
		if not tactical_battle_state.is_finished:
			tactical_combat_system.end_unit_action(tactical_battle_state, enemy_id)
		_refresh_tactical()
		_return_if_tactical_finished()
		return
	var movable_cells: Array = tactical_combat_system.get_movable_cells(tactical_battle_state, enemy_id)
	var move_overlay: Array = []
	for c in movable_cells:
		if typeof(c) == TYPE_DICTIONARY:
			move_overlay.append(Vector2i(int(c.get("q", 0)), int(c.get("r", 0))))
	_set_range_mode(RangeMode.MOVE, move_overlay)
	_refresh_tactical()
	var best_cell: Dictionary = tactical_combat_system._best_enemy_move_cell(tactical_battle_state, unit, target)
	_pending_enemy_move_unit_id = enemy_id
	var timer := get_tree().create_timer(0.18)
	timer.timeout.connect(func() -> void:
		if tactical_battle_state == null:
			_pending_enemy_move_unit_id = ""
			return
		var cur = tactical_battle_state.get_unit(enemy_id)
		if cur == null or not cur.is_alive():
			_pending_enemy_move_unit_id = ""
			_set_range_mode(RangeMode.NONE, [])
			_refresh_tactical()
			return
		var started := _start_move_animation(cur, best_cell)
		if not started:
			_pending_enemy_move_unit_id = ""
			_resolve_enemy_post_move(enemy_id)
	, CONNECT_ONE_SHOT)

func _resolve_enemy_post_move(enemy_id: String) -> void:
	if tactical_battle_state == null:
		return
	var unit = tactical_battle_state.get_unit(enemy_id)
	if unit == null or not unit.is_alive():
		_set_range_mode(RangeMode.NONE, [])
		_refresh_tactical()
		_return_if_tactical_finished()
		return
	var target = _pick_enemy_target(unit)
	if target != null and _cell_distance_dict(unit.cell, target.cell) <= int(unit.attack_range):
		var target_hp_before := int(target.hp)
		var attack_result := tactical_combat_system.attack_unit(tactical_battle_state, enemy_id, str(target.unit_id))
		if bool(attack_result.get("success", false)):
			_emit_damage_feedback(str(target.unit_id), target_hp_before, int(target.hp))
	if not tactical_battle_state.is_finished:
		tactical_combat_system.end_unit_action(tactical_battle_state, enemy_id)
	_set_range_mode(RangeMode.NONE, [])
	_refresh_tactical()
	_return_if_tactical_finished()

func _pick_enemy_target(enemy_unit):
	if tactical_battle_state == null or enemy_unit == null:
		return null
	var best = null
	var best_dist := 1_000_000
	for u in tactical_battle_state.units:
		if str(u.team) != TacticalBattleStateScript.TEAM_PLAYER or not u.is_alive():
			continue
		var d := _cell_distance_dict(enemy_unit.cell, u.cell)
		if d < best_dist:
			best_dist = d
			best = u
	return best

func _cell_distance_dict(a: Dictionary, b: Dictionary) -> int:
	return abs(int(a.get("q", 0)) - int(b.get("q", 0))) + abs(int(a.get("r", 0)) - int(b.get("r", 0)))

func _battlefield_dims() -> Vector2i:
	if tactical_battle_state != null and typeof(tactical_battle_state.terrain_grid) == TYPE_ARRAY and tactical_battle_state.terrain_grid.size() > 0 and typeof(tactical_battle_state.terrain_grid[0]) == TYPE_ARRAY:
		return Vector2i(int(tactical_battle_state.terrain_grid[0].size()), int(tactical_battle_state.terrain_grid.size()))
	if tactical_battle_state != null:
		return Vector2i(int(tactical_battle_state.battlefield_width), int(tactical_battle_state.battlefield_height))
	return Vector2i(8, 6)
