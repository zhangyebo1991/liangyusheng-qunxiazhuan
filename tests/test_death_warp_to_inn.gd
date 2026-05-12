extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()

	# 已绑定客栈：失败回流 → 切到客栈所在 map + HP/MP 满
	var bound_state = GameStateScript.new()
	bound_state.start_new_game()
	bound_state.bind_inn("foot_village_inn")
	bound_state.set_current_map("mountain_pass", Vector2(400, 200))
	bound_state.hero_hp = 0
	bound_state.consume_hero_mp(15)
	bound_state.apply_battle_result({"victory": false, "hero_hp": 0})
	assertions.assert_eq(bound_state.map_state.current_map_id, "foot_village", "应切到 foot_village")
	assertions.assert_eq(int(bound_state.map_state.player_position.x), 760, "应放到陆掌柜旁 x")
	assertions.assert_eq(int(bound_state.map_state.player_position.y), 320, "应放到陆掌柜旁 y")
	assertions.assert_eq(bound_state.hero_hp, bound_state.hero_max_hp, "回流后 HP 满")
	assertions.assert_eq(bound_state.hero_cur_mp, bound_state.hero_max_mp, "回流后 MP 满")

	# 未绑定：沿用原地复活逻辑（HP=1, position=Vector2(160, 320)）
	var fresh_state = GameStateScript.new()
	fresh_state.start_new_game()
	fresh_state.set_current_map("mountain_pass", Vector2(400, 200))
	fresh_state.hero_hp = 0
	fresh_state.apply_battle_result({"victory": false, "hero_hp": 0})
	assertions.assert_eq(fresh_state.map_state.current_map_id, "mountain_pass", "未绑定不应切场")
	assertions.assert_eq(fresh_state.hero_hp, 1, "未绑定原地复活 HP=1")

	repository.free()
