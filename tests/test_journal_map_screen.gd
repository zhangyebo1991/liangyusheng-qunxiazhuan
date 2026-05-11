extends RefCounted

const HudScript = preload("res://scripts/scenes/hud.gd")
const JournalPanelScript = preload("res://scripts/scenes/journal_panel.gd")
const MapScreenBaseScript = preload("res://scripts/scenes/map_screen_base.gd")

func run(assertions) -> void:
	var root = Engine.get_main_loop().root
	var repository = root.get_node("DataRepository")
	var game_state = root.get_node("GameState")
	repository.load_all()
	game_state.start_new_game()
	game_state.quest_system.start_quest("quest_mountain_trial")
	game_state.quest_system.set_status("quest_deliver_letter", "completed")

	assertions.assert_true(InputMap.has_action("journal"), "项目应配置 journal 输入动作")

	var screen = MapScreenBaseScript.new()
	var required_methods = [
		"_refresh_tracked_tasks",
		"_toggle_tracked_quest",
		"_open_journal",
		"_close_journal",
		"_record_dialogue_rumor",
	]
	var methods_ready := true
	for method_name in required_methods:
		var has_required_method = screen.has_method(str(method_name))
		assertions.assert_true(has_required_method, "地图场景应提供 %s 方法" % method_name)
		methods_ready = methods_ready and has_required_method
	var required_properties = ["journal_panel", "journal_is_open"]
	var properties_ready := true
	for property_name in required_properties:
		var has_required_property = _has_property(screen, str(property_name))
		assertions.assert_true(has_required_property, "地图场景应提供 %s 属性" % property_name)
		properties_ready = properties_ready and has_required_property
	if not methods_ready or not properties_ready:
		screen.free()
		return

	screen.map_id = "road_outskirts"
	screen.hud = HudScript.new()
	screen.hud._ready()
	screen.journal_panel = JournalPanelScript.new()
	screen.journal_panel._ready()

	screen._refresh_tracked_tasks()
	assertions.assert_eq(screen.hud.tracked_task_list.get_child_count(), 0, "没有追踪任务时 HUD 追踪区应为空")

	screen._toggle_tracked_quest("quest_mountain_trial")
	assertions.assert_eq(game_state.journal_state.tracked_quest_ids.size(), 1, "地图场景应能切换任务追踪")
	assertions.assert_eq(screen.hud.tracked_task_list.get_child_count(), 1, "切换追踪后 HUD 应刷新")

	screen._open_journal()
	assertions.assert_true(screen.journal_panel.visible, "打开江湖记事后页面应可见")
	assertions.assert_true(screen.journal_is_open, "地图场景应记录记事页面打开状态")
	screen._close_journal()
	assertions.assert_true(not screen.journal_panel.visible, "关闭江湖记事后页面应隐藏")
	assertions.assert_true(not screen.journal_is_open, "地图场景应记录记事页面关闭状态")

	screen._record_dialogue_rumor({
		"id": "road_scholar_rumor",
		"rumor": {
			"id": "rumor_road_red_thread",
			"title": "官道红线车辙",
			"text": "官道车辙中夹着红线。",
			"source": "赶路书生",
			"related_quest_id": "quest_trace_red_thread"
		}
	})
	assertions.assert_true(game_state.journal_state.active_rumors.has("rumor_road_red_thread"), "对白传闻应自动写入江湖记事")
	assertions.assert_eq(screen.hud.message_label.text, "传闻已记入江湖记事。", "记录新传闻后 HUD 应显示提示")

	screen._record_dialogue_rumor({
		"id": "road_scholar_rumor",
		"rumor": {
			"id": "rumor_road_red_thread",
			"title": "官道红线车辙",
			"text": "重复传闻。",
			"source": "赶路书生"
		}
	})
	assertions.assert_eq(game_state.journal_state.active_rumors.size(), 1, "重复对白传闻不应重复写入")

	screen.event_system.effect_system = screen.effect_system
	screen._on_dialogue_option_selected({
		"id": "trigger_trace_quest",
		"text": "追查红线车辙",
		"available": true,
		"conditions": [],
		"effects": [
			{"type": "set_quest_status", "quest_id": "quest_trace_red_thread", "status": "active"}
		],
		"next_dialogue_id": ""
	})
	assertions.assert_true(not game_state.journal_state.active_rumors.has("rumor_road_red_thread"), "对话触发相关任务后传闻应离开可追查列表")
	assertions.assert_true(game_state.journal_state.triggered_rumors.has("rumor_road_red_thread"), "对话触发相关任务后传闻应进入已触发列表")

	game_state.journal_state.triggered_rumors.erase("rumor_road_red_thread")
	game_state.journal_state.active_rumors["rumor_road_red_thread"] = {
		"id": "rumor_road_red_thread",
		"title": "官道红线车辙",
		"text": "官道车辙中夹着红线。",
		"source": "赶路书生",
		"related_quest_id": "quest_trace_red_thread"
	}
	screen._apply_quest_complete_effects("quest_trace_red_thread")
	assertions.assert_true(not game_state.journal_state.active_rumors.has("rumor_road_red_thread"), "相关任务触发后传闻应离开可追查列表")
	assertions.assert_true(game_state.journal_state.triggered_rumors.has("rumor_road_red_thread"), "相关任务触发后传闻应进入已触发列表")

	screen.hud.free()
	screen.journal_panel.free()
	screen.free()

func _has_property(target, property_name: String) -> bool:
	for property in target.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false
