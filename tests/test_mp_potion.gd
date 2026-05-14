extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const InventorySystemScript = preload("res://scripts/systems/inventory_system.gd")
const EffectSystemScript = preload("res://scripts/systems/effect_system.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()

	# 凝神丹数据存在
	var item = repository.get_item("herb_focus")
	assertions.assert_false(item.is_empty(), "凝神丹应在 items.json 中存在")
	assertions.assert_eq(str(item.get("name", "")), "凝神丹", "凝神丹名称应正确")
	assertions.assert_eq(int(item.get("value", 0)), 12, "凝神丹售价应为 12 文")
	assertions.assert_eq(int(item.get("effects", {}).get("restore_mp", 0)), 10, "凝神丹应恢复 10 内力")

	# 战斗外使用凝神丹
	var game_state = GameStateScript.new()
	game_state.start_new_game()
	game_state.party.add_item("herb_focus", 2)
	game_state.consume_hero_mp(7)
	var inventory = InventorySystemScript.new()
	inventory.set_repository(repository)
	var result = inventory.use_item(game_state, "herb_focus")
	assertions.assert_true(bool(result.get("success", false)), "战斗外使用凝神丹应成功")
	assertions.assert_eq(int(result.get("recovered_mp", 0)), 7, "应只恢复缺口 7 点")
	assertions.assert_eq(game_state.hero_cur_mp, game_state.hero_max_mp, "使用后内力应满")
	assertions.assert_eq(game_state.party.get_item_count("herb_focus"), 1, "应消耗 1 颗")

	# 队伍面板读取 PartyState.member_status，吃药后必须与 HUD 使用的 hero_cur_mp 同步。
	var panel_source_state = GameStateScript.new()
	panel_source_state.start_new_game()
	panel_source_state.set_hero_cur_mp(1)
	panel_source_state.party.set_member_status("hero_yun", {"hp": panel_source_state.hero_hp, "mp": 1})
	panel_source_state.party.add_item("herb_focus", 1)
	var panel_sync_result = inventory.use_item(panel_source_state, "herb_focus")
	assertions.assert_true(bool(panel_sync_result.get("success", false)), "低内力时使用凝神丹应成功")
	assertions.assert_eq(panel_source_state.hero_cur_mp, 11, "HUD 源值应恢复到 11/20")
	assertions.assert_eq(panel_source_state.party.get_member_status("hero_yun").get("mp", 0), 11, "队伍面板源值也应恢复到 11/20")

	# 满内力时使用应失败且不消耗
	var result_full = inventory.use_item(game_state, "herb_focus")
	assertions.assert_false(bool(result_full.get("success", false)), "满内力使用应失败")
	assertions.assert_eq(game_state.party.get_item_count("herb_focus"), 1, "失败不应消耗物品")

	# EffectSystem 直接执行 restore_mp（给对话/事件用）
	game_state.consume_hero_mp(5)
	var effect_system = EffectSystemScript.new()
	var effect_result = effect_system.apply_effect(game_state, {"type": "restore_mp", "amount": 3})
	assertions.assert_true(bool(effect_result.get("success", false)), "EffectSystem.restore_mp 应成功")
	assertions.assert_eq(game_state.hero_cur_mp, game_state.hero_max_mp - 2, "应实际恢复 3 点")
