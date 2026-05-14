extends SceneTree

const TestAssertionsScript = preload("res://tests/support/test_assertions.gd")
const TestDataLoaderScript = preload("res://tests/test_data_loader.gd")
const TestDomainModelsScript = preload("res://tests/test_domain_models.gd")
const TestPartyStateScript = preload("res://tests/test_party_state.gd")
const TestEquipmentSystemScript = preload("res://tests/test_equipment_system.gd")
const TestActorStatsSystemScript = preload("res://tests/test_actor_stats_system.gd")
const TestJournalStateScript = preload("res://tests/test_journal_state.gd")
const TestJournalSystemScript = preload("res://tests/test_journal_system.gd")
const TestQuestAndDialogueScript = preload("res://tests/test_quest_and_dialogue.gd")
const TestDialogueOptionsScript = preload("res://tests/test_dialogue_options.gd")
const TestDialogueBoxOptionsScript = preload("res://tests/test_dialogue_box_options.gd")
const TestEffectSystemScript = preload("res://tests/test_effect_system.gd")
const TestEffectDataScript = preload("res://tests/test_effect_data.gd")
const TestConditionSystemScript = preload("res://tests/test_condition_system.gd")
const TestEventSystemScript = preload("res://tests/test_event_system.gd")
const TestStoryEventDataScript = preload("res://tests/test_story_event_data.gd")
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
const TestJournalPanelScript = preload("res://tests/test_journal_panel.gd")
const TestShopMapScreenScript = preload("res://tests/test_shop_map_screen.gd")
const TestPickupMapScreenScript = preload("res://tests/test_pickup_map_screen.gd")
const TestJournalMapScreenScript = preload("res://tests/test_journal_map_screen.gd")
const TestTacticalUnitStateScript = preload("res://tests/test_tactical_unit_state.gd")
const TestTacticalBattleStateScript = preload("res://tests/test_tactical_battle_state.gd")
const TestTacticalCombatSystemScript = preload("res://tests/test_tactical_combat_system.gd")
const TestTacticalBattleScreenScript = preload("res://tests/test_tactical_battle_screen.gd")
const TestBattleStateScript = preload("res://tests/test_battle_state.gd")
const TestTurnBasedCombatSystemScript = preload("res://tests/test_turn_based_combat_system.gd")
const TestLongTermMpSaveScript = preload("res://tests/test_long_term_mp_save.gd")
const TestMpPotionScript = preload("res://tests/test_mp_potion.gd")
const TestInnDataScript = preload("res://tests/test_inn_data.gd")
const TestInnRestLoopScript = preload("res://tests/test_inn_rest_loop.gd")
const TestDeathWarpToInnScript = preload("res://tests/test_death_warp_to_inn.gd")
const TestHudMpDisplayScript = preload("res://tests/test_hud_mp_display.gd")
const TestTerrainSystemScript = preload("res://tests/test_terrain_system.gd")
const TestTacticalBattleTerrainGridScript = preload("res://tests/test_tactical_battle_terrain_grid.gd")
const TestTacticalRangeSystemScript = preload("res://tests/test_tactical_range_system.gd")
const TestSwordAuraSwirlSkillScript = preload("res://tests/test_sword_aura_swirl_skill.gd")
const TestBattleActionEmptyCastScript = preload("res://tests/test_battle_action_empty_cast.gd")
const TestBattleScreenRangeModeScript = preload("res://tests/test_battle_screen_range_mode.gd")
const TestChargeBarLayoutScript = preload("res://tests/test_charge_bar_layout.gd")
const TestBattleScreenSkillMenuScript = preload("res://tests/test_battle_screen_skill_menu.gd")
const TestBattleScreenTargetSkillScript = preload("res://tests/test_battle_screen_target_skill.gd")
const TestBattleScreenMoveAnimationScript = preload("res://tests/test_battle_screen_move_animation.gd")
const TestBattlePanelActorScript = preload("res://tests/test_battle_panel_actor.gd")
const TestBattleScreenActorPanelScript = preload("res://tests/test_battle_screen_actor_panel.gd")
const TestBattleFeedbackDirectorScript = preload("res://tests/test_battle_feedback_director.gd")
const TestProficiencySystemScript = preload("res://tests/test_proficiency_system.gd")
const TestTacticalRangeFanScript = preload("res://tests/test_tactical_range_fan.gd")
const TestTacticalRangeSurroundScript = preload("res://tests/test_tactical_range_surround.gd")
const TestTacticalRangePierceScript = preload("res://tests/test_tactical_range_pierce.gd")
const TestTacticalRangeRingScript = preload("res://tests/test_tactical_range_ring.gd")
const TestNewMartialArtsDataScript = preload("res://tests/test_new_martial_arts_data.gd")

func _initialize() -> void:
	# _initialize 阶段 root 尚未进入树；deferred 后执行可让依赖 SceneTree 的测试稳定运行。
	call_deferred("_run_all_suites")

func _run_all_suites() -> void:
	var assertions = TestAssertionsScript.new()
	var suites: Array = [
		TestDataLoaderScript.new(),
		TestDomainModelsScript.new(),
		TestPartyStateScript.new(),
		TestEquipmentSystemScript.new(),
		TestActorStatsSystemScript.new(),
		TestJournalStateScript.new(),
		TestJournalSystemScript.new(),
		TestQuestAndDialogueScript.new(),
		TestDialogueOptionsScript.new(),
		TestDialogueBoxOptionsScript.new(),
		TestEffectSystemScript.new(),
		TestEffectDataScript.new(),
		TestConditionSystemScript.new(),
		TestEventSystemScript.new(),
		TestStoryEventDataScript.new(),
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
		TestJournalPanelScript.new(),
		TestShopMapScreenScript.new(),
		TestPickupMapScreenScript.new(),
		TestJournalMapScreenScript.new(),
		TestTacticalUnitStateScript.new(),
		TestTacticalBattleStateScript.new(),
		TestTacticalCombatSystemScript.new(),
		TestTacticalBattleScreenScript.new(),
		TestBattleStateScript.new(),
		TestTurnBasedCombatSystemScript.new(),
		TestLongTermMpSaveScript.new(),
		TestMpPotionScript.new(),
		TestInnDataScript.new(),
		TestInnRestLoopScript.new(),
		TestDeathWarpToInnScript.new(),
		TestHudMpDisplayScript.new(),
		TestTerrainSystemScript.new(),
		TestTacticalBattleTerrainGridScript.new(),
		TestTacticalRangeSystemScript.new(),
		TestSwordAuraSwirlSkillScript.new(),
		TestBattleActionEmptyCastScript.new(),
		TestBattleScreenRangeModeScript.new(),
		TestChargeBarLayoutScript.new(),
		TestBattleScreenSkillMenuScript.new(),
		TestBattleScreenTargetSkillScript.new(),
		TestBattleScreenMoveAnimationScript.new(),
		TestBattlePanelActorScript.new(),
		TestBattleScreenActorPanelScript.new(),
		TestBattleFeedbackDirectorScript.new(),
		TestProficiencySystemScript.new(),
		TestTacticalRangeFanScript.new(),
		TestTacticalRangeSurroundScript.new(),
		TestTacticalRangePierceScript.new(),
		TestTacticalRangeRingScript.new(),
		TestNewMartialArtsDataScript.new(),
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
