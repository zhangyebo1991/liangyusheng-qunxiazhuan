extends RefCounted

# 验证山道战斗触发节点带 terrain_grid，且 create_battle 能把它写进 battle.terrain_grid。
# 以现有源码为准：context 即 maps.json 战斗触发对象的副本，create_battle 从 context["terrain_grid"] 读。

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const TacticalCombatSystemScript = preload("res://scripts/systems/tactical_combat_system.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()

	# 1. 山道战斗触发节点应含 terrain_grid 字段
	var mountain = repository.get_map("mountain_pass")
	var bandit_gate = _find_object(mountain, "enemy_bandit_gate")
	assertions.assert_true(bandit_gate.has("terrain_grid"), "山道战斗触发节点应含 terrain_grid 字段")
	var raw_grid = bandit_gate.get("terrain_grid", [])
	assertions.assert_eq(raw_grid.size(), 6, "terrain_grid 应有 6 行")
	if raw_grid.size() >= 1:
		assertions.assert_eq(raw_grid[0].size(), 8, "terrain_grid 每行应有 8 列")

	# 2. create_battle 应把 terrain_grid 写到 battle 状态
	var system = TacticalCombatSystemScript.new()
	system.set_repository(repository)
	var state = _make_fake_game_state()

	var context = bandit_gate.duplicate(true)
	context["source_map_id"] = "mountain_pass"
	context["source_object_id"] = "enemy_bandit_gate"
	context["quest_id"] = "quest_mountain_trial"

	var battle = system.create_battle(state, context, repository)
	assertions.assert_true(battle != null, "战斗对象应被创建")
	assertions.assert_true(battle.terrain_grid != null, "battle.terrain_grid 应非 null")
	assertions.assert_eq(battle.terrain_grid.size(), 6, "battle.terrain_grid 应有 6 行")
	if battle.terrain_grid.size() >= 1:
		assertions.assert_eq(battle.terrain_grid[0].size(), 8, "battle.terrain_grid 每行应有 8 列")

	# 至少包含 1 块 grass
	var has_grass := false
	for row in battle.terrain_grid:
		for cell in row:
			if str(cell) == "grass":
				has_grass = true
				break
		if has_grass:
			break
	assertions.assert_true(has_grass, "terrain_grid 中应至少含 1 块草地")

	# 3. context 缺 terrain_grid 时，create_battle 应给出默认全 grass 6×8 兜底
	var bare_context = bandit_gate.duplicate(true)
	bare_context.erase("terrain_grid")
	bare_context["source_map_id"] = "mountain_pass"
	var bare_battle = system.create_battle(state, bare_context, repository)
	assertions.assert_eq(bare_battle.terrain_grid.size(), 6, "缺 terrain_grid 时应有 6 行默认")
	if bare_battle.terrain_grid.size() >= 1:
		assertions.assert_eq(bare_battle.terrain_grid[0].size(), 8, "缺 terrain_grid 时每行 8 列默认")
		assertions.assert_eq(str(bare_battle.terrain_grid[0][0]), "grass", "默认地形应为 grass")

	repository.free()
	state.free()

func _find_object(map_data: Dictionary, object_id: String) -> Dictionary:
	for obj in map_data.get("objects", []):
		if str(obj.get("id", "")) == object_id:
			return obj
	return {}

func _make_fake_game_state():
	var gs = GameStateScript.new()
	gs.start_new_game()
	return gs
