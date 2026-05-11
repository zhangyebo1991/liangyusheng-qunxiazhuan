extends RefCounted

const HudScript = preload("res://scripts/scenes/hud.gd")
const MapInteractableScript = preload("res://scripts/scenes/map_interactable.gd")
const MapScreenBaseScript = preload("res://scripts/scenes/map_screen_base.gd")

func run(assertions) -> void:
	var root = Engine.get_main_loop().root
	var repository = root.get_node("DataRepository")
	var game_state = root.get_node("GameState")
	repository.load_all()
	game_state.start_new_game()

	var screen = MapScreenBaseScript.new()
	screen.hud = HudScript.new()
	screen.hud._ready()
	screen.map_reward_system.set_repository(repository)

	var pickup_record = {
		"id": "pickup_roadside_bundle",
		"type": "pickup",
		"name": "路边包裹",
		"reward_items": ["herb_small"],
		"reward_item_amounts": {"herb_small": 1},
		"reward_coins": 20
	}
	var interactable = MapInteractableScript.new()
	interactable.setup(pickup_record)
	screen.interactables.append(interactable)

	var initial_herbs = game_state.party.get_item_count("herb_small")
	var initial_coins = game_state.party.coins
	screen._claim_pickup(pickup_record)

	assertions.assert_eq(screen.hud.message_label.text, "获得：小还丹、20 文。", "地图场景拾取后应显示奖励消息")
	assertions.assert_eq(game_state.party.get_item_count("herb_small"), initial_herbs + 1, "地图场景拾取后应增加小还丹")
	assertions.assert_eq(game_state.party.coins, initial_coins + 20, "地图场景拾取后应增加铜钱")
	assertions.assert_true(game_state.is_map_object_resolved("pickup_roadside_bundle"), "地图场景拾取后应标记对象已解决")
	assertions.assert_eq(screen.interactables.size(), 0, "地图场景拾取成功后应移除交互对象")

	screen.hud.free()
	screen.free()
