extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const EventSystemScript = preload("res://scripts/systems/event_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()

	var road = repository.get_map("road_outskirts")
	var scholar = _find_object(road, "npc_road_scholar")
	assertions.assert_eq(scholar.get("type", ""), "npc", "村外官道应配置赶路书生 NPC")
	assertions.assert_eq(scholar.get("name", ""), "赶路书生", "赶路书生名称应正确")
	assertions.assert_eq(scholar.get("dialogue_id", ""), "road_scholar_intro", "赶路书生应指向分支对话")

	var intro = repository.get_dialogue("road_scholar_intro")
	var options = intro.get("options", [])
	assertions.assert_eq(options.size(), 2, "赶路书生应包含两个分支选项")
	assertions.assert_eq(_find_option(options, "ask_road_unrest").get("next_dialogue_id", ""), "road_scholar_rumor", "询问选项应跳转传闻对白")
	assertions.assert_eq(_find_option(options, "give_medicine").get("next_dialogue_id", ""), "road_scholar_thanks", "赠药选项应跳转感谢对白")
	assertions.assert_true(not repository.get_dialogue("road_scholar_rumor").is_empty(), "传闻后续对白应存在")
	assertions.assert_true(not repository.get_dialogue("road_scholar_thanks").is_empty(), "感谢后续对白应存在")
	var rumor_dialogue = repository.get_dialogue("road_scholar_rumor")
	var rumor = rumor_dialogue.get("rumor", {})
	assertions.assert_eq(rumor.get("id", ""), "rumor_road_red_thread", "官道传闻对白应配置传闻编号")
	assertions.assert_eq(rumor.get("related_quest_id", ""), "quest_trace_red_thread", "官道传闻应声明相关任务编号")
	assertions.assert_true(not str(rumor.get("text", "")).is_empty(), "官道传闻应配置正文")

	var state = GameStateScript.new()
	state.start_new_game()
	state.quest_system.set_status("quest_deliver_letter", "completed")
	var event_system = EventSystemScript.new()
	var ask_option = _find_option(options, "ask_road_unrest")
	var ask_result = event_system.apply_event(state, ask_option)
	assertions.assert_true(bool(ask_result.get("success", false)), "询问路上异动选项应可执行")
	assertions.assert_eq(state.flags.get("clue_road_unrest", false), true, "询问选项应写入官道线索 flag")

	var before_herbs = state.party.get_item_count("herb_small")
	var before_coins = state.party.coins
	var give_option = _find_option(options, "give_medicine")
	var give_result = event_system.apply_event(state, give_option)
	assertions.assert_true(bool(give_result.get("success", false)), "赠药选项应可执行")
	assertions.assert_eq(state.party.get_item_count("herb_small"), before_herbs - 1, "赠药选项应扣除小还丹")
	assertions.assert_eq(state.party.coins, before_coins + 30, "赠药选项应增加铜钱")
	assertions.assert_eq(state.flags.get("helped_road_scholar", false), true, "赠药选项应写入帮助书生 flag")

	var save_data = state.to_dictionary()
	var loaded = GameStateScript.new()
	loaded.from_dictionary(save_data)
	assertions.assert_eq(loaded.flags.get("clue_road_unrest", false), true, "读档后官道线索 flag 应保持")
	assertions.assert_eq(loaded.flags.get("helped_road_scholar", false), true, "读档后帮助书生 flag 应保持")
	assertions.assert_eq(loaded.party.coins, state.party.coins, "读档后铜钱应保持")
	assertions.assert_eq(loaded.party.get_item_count("herb_small"), state.party.get_item_count("herb_small"), "读档后背包变化应保持")

	state.free()
	loaded.free()
	repository.free()

func _find_object(map_data: Dictionary, object_id: String) -> Dictionary:
	for object in map_data.get("objects", []):
		if str(object.get("id", "")) == object_id:
			return object
	return {}

func _find_option(options: Array, option_id: String) -> Dictionary:
	for option in options:
		if str(option.get("id", "")) == option_id:
			return option
	return {}
