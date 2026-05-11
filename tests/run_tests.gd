extends SceneTree

const TestAssertionsScript = preload("res://tests/support/test_assertions.gd")
const TestDataLoaderScript = preload("res://tests/test_data_loader.gd")
const TestDomainModelsScript = preload("res://tests/test_domain_models.gd")
const TestQuestAndDialogueScript = preload("res://tests/test_quest_and_dialogue.gd")
const TestCombatAndSaveScript = preload("res://tests/test_combat_and_save.gd")
const TestMapDataScript = preload("res://tests/test_map_data.gd")
const TestMapStateAndFlowScript = preload("res://tests/test_map_state_and_flow.gd")
const TestInteractionSystemScript = preload("res://tests/test_interaction_system.gd")
const TestSaveMapStateScript = preload("res://tests/test_save_map_state.gd")
const TestMapTransitionSystemScript = preload("res://tests/test_map_transition_system.gd")
const TestInventorySystemScript = preload("res://tests/test_inventory_system.gd")
const TestShopSystemScript = preload("res://tests/test_shop_system.gd")
const TestMapRewardSystemScript = preload("res://tests/test_map_reward_system.gd")
const TestHudInventoryScript = preload("res://tests/test_hud_inventory.gd")
const TestShopMapScreenScript = preload("res://tests/test_shop_map_screen.gd")
const TestBattleStateScript = preload("res://tests/test_battle_state.gd")
const TestTurnBasedCombatSystemScript = preload("res://tests/test_turn_based_combat_system.gd")

func _initialize() -> void:
	var assertions = TestAssertionsScript.new()
	var suites: Array = [
		TestDataLoaderScript.new(),
		TestDomainModelsScript.new(),
		TestQuestAndDialogueScript.new(),
		TestCombatAndSaveScript.new(),
		TestMapDataScript.new(),
		TestMapStateAndFlowScript.new(),
		TestInteractionSystemScript.new(),
		TestSaveMapStateScript.new(),
		TestMapTransitionSystemScript.new(),
		TestInventorySystemScript.new(),
		TestShopSystemScript.new(),
		TestMapRewardSystemScript.new(),
		TestHudInventoryScript.new(),
		TestShopMapScreenScript.new(),
		TestBattleStateScript.new(),
		TestTurnBasedCombatSystemScript.new(),
	]

	for suite in suites:
		suite.run(assertions)

	for failure in assertions.failures:
		push_error(failure)

	if assertions.failures.is_empty():
		print("测试通过：%d 个测试套件" % suites.size())
		quit(0)
	else:
		print("测试失败：%d 个问题" % assertions.failures.size())
		quit(1)
