extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const MapObjectSpawnerScript = preload("res://scripts/systems/map_object_spawner.gd")
const MapRewardSystemScript = preload("res://scripts/systems/map_reward_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var reward_system = MapRewardSystemScript.new()
	reward_system.set_repository(repository)

	var state = GameStateScript.new()
	state.start_new_game()
	var initial_coins = state.party.coins
	var initial_herbs = state.party.get_item_count("herb_small")
	var pickup = {
		"id": "pickup_roadside_bundle",
		"type": "pickup",
		"name": "路边包裹",
		"reward_items": ["herb_small"],
		"reward_item_amounts": {"herb_small": 1},
		"reward_coins": 20
	}
	var result = reward_system.claim_pickup(state, pickup)
	assertions.assert_true(result.get("success", false), "有效包裹应可领取")
	assertions.assert_eq(result.get("message", ""), "获得：小还丹、20 文。", "领取包裹应返回物品和铜钱提示")
	assertions.assert_eq(state.party.get_item_count("herb_small"), initial_herbs + 1, "领取包裹应增加小还丹")
	assertions.assert_eq(state.party.coins, initial_coins + 20, "领取包裹应增加铜钱")
	assertions.assert_true(state.is_map_object_resolved("pickup_roadside_bundle"), "领取包裹后应标记对象已解决")

	var duplicate = reward_system.claim_pickup(state, pickup)
	assertions.assert_true(not duplicate.get("success", true), "已领取包裹不应重复领取")
	assertions.assert_eq(duplicate.get("message", ""), "这里什么也没有。", "重复领取应显示空提示")
	assertions.assert_eq(state.party.get_item_count("herb_small"), initial_herbs + 1, "重复领取不应增加物品")
	assertions.assert_eq(state.party.coins, initial_coins + 20, "重复领取不应增加铜钱")

	var coin_only_state = GameStateScript.new()
	coin_only_state.start_new_game()
	var coin_only = reward_system.claim_pickup(coin_only_state, {
		"id": "pickup_coin_pouch",
		"type": "pickup",
		"name": "钱袋",
		"reward_coins": 12
	})
	assertions.assert_true(coin_only.get("success", false), "纯铜钱奖励应可领取")
	assertions.assert_eq(coin_only.get("message", ""), "获得：12 文。", "纯铜钱奖励应返回铜钱提示")
	assertions.assert_eq(coin_only_state.party.coins, 92, "纯铜钱奖励应增加余额")

	var invalid_state = GameStateScript.new()
	invalid_state.start_new_game()
	var invalid = reward_system.claim_pickup(invalid_state, {
		"id": "pickup_invalid",
		"type": "pickup",
		"name": "空包裹",
		"reward_items": ["missing_item"],
		"reward_item_amounts": {"missing_item": 1},
		"reward_coins": 0
	})
	assertions.assert_true(not invalid.get("success", true), "全部奖励无效时不应成功")
	assertions.assert_eq(invalid.get("message", ""), "这里什么也没有。", "全部奖励无效时应显示空提示")
	assertions.assert_true(not invalid_state.is_map_object_resolved("pickup_invalid"), "全部奖励无效时不应标记对象已解决")

	var no_id = reward_system.claim_pickup(invalid_state, {
		"type": "pickup",
		"reward_coins": 10
	})
	assertions.assert_true(not no_id.get("success", true), "缺少编号的拾取对象不应成功")
	assertions.assert_eq(no_id.get("message", ""), "这里什么也没有。", "缺少编号时应显示空提示")

	var restored = GameStateScript.new()
	restored.from_dictionary(state.to_dictionary())
	var road = repository.get_map("road_outskirts")
	var spawner = MapObjectSpawnerScript.new()
	var records = spawner.get_spawn_records(road, restored.map_state.resolved_objects, restored)
	assertions.assert_eq(_count_object(records, "pickup_roadside_bundle"), 0, "读档后已领取包裹不应再次生成")

	state.free()
	coin_only_state.free()
	invalid_state.free()
	restored.free()
	repository.free()

func _count_object(records: Array, object_id: String) -> int:
	var count := 0
	for record in records:
		if str(record.get("id", "")) == object_id:
			count += 1
	return count
