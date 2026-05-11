extends RefCounted

const InteractionSystemScript = preload("res://scripts/systems/interaction_system.gd")
const MapObjectSpawnerScript = preload("res://scripts/systems/map_object_spawner.gd")
const MapInteractableScript = preload("res://scripts/scenes/map_interactable.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")

func run(assertions) -> void:
	var interaction_system = InteractionSystemScript.new()
	var objects = [
		{"id": "npc_qingshanke", "position": Vector2(100, 100), "radius": 64},
		{"id": "enemy_bandit_gate", "position": Vector2(260, 100), "radius": 48},
	]

	var nearby = interaction_system.find_nearest_in_range(Vector2(120, 100), objects)
	assertions.assert_eq(nearby.get("id", ""), "npc_qingshanke", "应找到范围内最近对象")

	var far = interaction_system.find_nearest_in_range(Vector2(500, 500), objects)
	assertions.assert_eq(far, {}, "远离对象时应返回空字典")

	assertions.assert_true(interaction_system.is_click_in_object(Vector2(110, 100), objects[0]), "鼠标点击对象范围内应命中")
	assertions.assert_true(not interaction_system.is_click_in_object(Vector2(220, 100), objects[0]), "鼠标点击对象范围外不应命中")

	var spawner = MapObjectSpawnerScript.new()
	var records = spawner.get_spawn_records({
		"objects": [
			{"id": "npc_qingshanke", "type": "npc", "position": {"x": 360, "y": 280}},
			{"id": "enemy_bandit_gate", "type": "battle_trigger", "position": {"x": 720, "y": 260}}
		]
	}, ["enemy_bandit_gate"])

	assertions.assert_eq(records.size(), 1, "已解决对象不应进入生成列表")
	assertions.assert_eq(records[0].get("id", ""), "npc_qingshanke", "未解决 NPC 应进入生成列表")

	var conditional_state = GameStateScript.new()
	conditional_state.start_new_game()
	var conditional_records_locked = spawner.get_spawn_records({
		"objects": [
			{
				"id": "pickup_locked_bundle",
				"type": "pickup",
				"required_quest_id": "quest_deliver_letter",
				"required_quest_status": "completed",
				"position": {"x": 620, "y": 340}
			}
		]
	}, [], conditional_state)
	assertions.assert_eq(conditional_records_locked.size(), 0, "任务条件不满足时对象不应生成")

	conditional_state.quest_system.start_quest("quest_deliver_letter")
	conditional_state.quest_system.mark_ready_to_complete("quest_deliver_letter")
	conditional_state.quest_system.complete_quest("quest_deliver_letter")
	var conditional_records_unlocked = spawner.get_spawn_records({
		"objects": [
			{
				"id": "pickup_locked_bundle",
				"type": "pickup",
				"required_quest_id": "quest_deliver_letter",
				"required_quest_status": "completed",
				"position": {"x": 620, "y": 340}
			}
		]
	}, [], conditional_state)
	assertions.assert_eq(conditional_records_unlocked.size(), 1, "任务条件满足时对象应生成")
	conditional_state.free()

	var shop_interactable = MapInteractableScript.new()
	shop_interactable.setup({
		"id": "shop_foot_village_pharmacy",
		"type": "shop",
		"name": "药铺",
		"position": {"x": 980, "y": 320},
		"radius": 72,
	})
	assertions.assert_eq(shop_interactable.get_interaction_text(), "按 E 查看药铺", "药铺应显示查看提示")
	shop_interactable.free()

	var pickup_interactable = MapInteractableScript.new()
	pickup_interactable.setup({
		"id": "pickup_roadside_bundle",
		"type": "pickup",
		"name": "路边包裹",
		"position": {"x": 620, "y": 340},
		"radius": 56,
	})
	assertions.assert_eq(pickup_interactable.get_interaction_text(), "按 E 查看包裹", "包裹应显示查看提示")
	pickup_interactable.free()
