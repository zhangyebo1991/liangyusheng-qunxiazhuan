extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const EffectSystemScript = preload("res://scripts/systems/effect_system.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const ConditionSystemScript = preload("res://scripts/systems/condition_system.gd")

func run(assertions) -> void:
	# rest_at_inn 直接调用 EffectSystem
	var game_state = GameStateScript.new()
	game_state.start_new_game()
	game_state.hero_hp = 30
	game_state.consume_hero_mp(10)
	var initial_coins = game_state.party.coins

	var effect_system = EffectSystemScript.new()
	var rest_result = effect_system.apply_effect(game_state, {
		"type": "rest_at_inn",
		"inn_id": "foot_village_inn",
		"cost": 5,
	})
	assertions.assert_true(bool(rest_result.get("success", false)), "rest_at_inn 应成功")
	assertions.assert_eq(game_state.hero_hp, game_state.hero_max_hp, "休息后气血应满")
	assertions.assert_eq(game_state.hero_cur_mp, game_state.hero_max_mp, "休息后内力应满")
	assertions.assert_eq(game_state.last_inn_id, "foot_village_inn", "应绑定 last_inn_id")
	assertions.assert_eq(game_state.party.coins, initial_coins - 5, "应扣 5 文")

	# 铜钱不足：cost = 0 路径（免费分支）
	var poor_state = GameStateScript.new()
	poor_state.start_new_game()
	# 把铜钱花光到 4 文
	poor_state.party.spend_coins(poor_state.party.coins - 4)
	poor_state.hero_hp = 50
	poor_state.consume_hero_mp(8)
	var rest_free = effect_system.apply_effect(poor_state, {
		"type": "rest_at_inn",
		"inn_id": "foot_village_inn",
		"cost": 0,
	})
	assertions.assert_true(bool(rest_free.get("success", false)), "免费 rest_at_inn 应成功")
	assertions.assert_eq(poor_state.party.coins, 4, "免费休息不应扣钱")
	assertions.assert_eq(poor_state.hero_hp, poor_state.hero_max_hp, "免费休息也应回满气血")
	assertions.assert_eq(poor_state.hero_cur_mp, poor_state.hero_max_mp, "免费休息也应回满内力")

	# 缺 inn_id 应失败
	var bad_result = effect_system.apply_effect(game_state, {"type": "rest_at_inn"})
	assertions.assert_false(bool(bad_result.get("success", false)), "缺 inn_id 应失败")

	# cost > coins 应失败（此时玩家未触发免费分支，是 dialogue 层应拦住的情形；EffectSystem 兜底）
	var rich_state = GameStateScript.new()
	rich_state.start_new_game()
	rich_state.party.spend_coins(rich_state.party.coins - 3)
	var insufficient = effect_system.apply_effect(rich_state, {
		"type": "rest_at_inn",
		"inn_id": "foot_village_inn",
		"cost": 5,
	})
	assertions.assert_false(bool(insufficient.get("success", false)), "铜钱不足 + cost=5 应失败")
	assertions.assert_eq(rich_state.party.coins, 3, "失败不应扣钱")

	# dialogue 数据校验：陆掌柜对话应包含两个休息选项
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var dialogue = repository.get_dialogue("foot_village_innkeeper_idle")
	var options = dialogue.get("options", [])
	assertions.assert_true(typeof(options) == TYPE_ARRAY and options.size() >= 2, "陆掌柜对话应含至少 2 个选项")
	var ids: Array = []
	for opt in options:
		ids.append(str(opt.get("id", "")))
	assertions.assert_true(ids.has("rest_5_coins"), "应含 rest_5_coins 选项")
	assertions.assert_true(ids.has("rest_no_coin"), "应含 rest_no_coin 选项")
