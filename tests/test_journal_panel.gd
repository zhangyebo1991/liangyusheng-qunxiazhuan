extends RefCounted

const JOURNAL_PANEL_PATH := "res://scripts/scenes/journal_panel.gd"

func run(assertions) -> void:
	var JournalPanelScript = load(JOURNAL_PANEL_PATH)
	assertions.assert_true(JournalPanelScript != null, "应存在江湖记事页面脚本")
	if JournalPanelScript == null:
		return

	var panel = JournalPanelScript.new()
	panel._ready()

	assertions.assert_true(panel.has_signal("quest_tracking_toggled"), "江湖记事页面应提供追踪切换信号")
	assertions.assert_true(panel.has_method("open"), "江湖记事页面应提供打开方法")
	assertions.assert_true(panel.has_method("close"), "江湖记事页面应提供关闭方法")
	assertions.assert_true(panel.has_method("show_message"), "江湖记事页面应提供提示方法")
	if not panel.has_signal("quest_tracking_toggled") or not panel.has_method("open") or not panel.has_method("close") or not panel.has_method("show_message"):
		panel.free()
		return

	var toggled: Array[String] = []
	panel.quest_tracking_toggled.connect(func(quest_id: String): toggled.append(quest_id))

	panel.open({
		"tasks": [
			{"id": "quest_mountain_trial", "title": "山道试剑", "status_text": "进行中", "tracked": true},
			{"id": "quest_deliver_letter", "title": "送信到客栈", "status_text": "已完成", "tracked": false}
		],
		"active_rumors": [
			{"id": "rumor_road_red_thread", "title": "官道红线车辙", "source": "赶路书生", "text": "官道车辙中夹着红线。"}
		],
		"triggered_rumors": [
			{"id": "rumor_old", "title": "旧传闻", "source": "青衫客", "text": "旧传闻已触发任务。"}
		]
	})

	assertions.assert_true(panel.visible, "打开江湖记事页面后应可见")
	assertions.assert_eq(panel.title_label.text, "江湖记事", "页面标题应正确")
	assertions.assert_eq(panel.task_list.get_child_count(), 2, "任务列表应显示任务条目")
	assertions.assert_eq(panel.active_rumor_list.get_child_count(), 1, "可追查传闻列表应显示传闻")
	assertions.assert_eq(panel.triggered_rumor_list.get_child_count(), 1, "已触发传闻列表应显示传闻")

	var first_task_row = panel.task_list.get_child(0)
	var first_checkbox = first_task_row.get_child(0)
	assertions.assert_true(first_checkbox.button_pressed, "已追踪任务的勾选框应选中")

	var second_task_row = panel.task_list.get_child(1)
	var second_checkbox = second_task_row.get_child(0)
	second_checkbox.pressed.emit()
	assertions.assert_eq(toggled.size(), 1, "点击追踪勾选应发出任务编号")
	assertions.assert_eq(toggled[0], "quest_deliver_letter", "追踪信号应携带任务编号")

	panel.show_message("最多只能追踪 3 个任务。")
	assertions.assert_eq(panel.message_label.text, "最多只能追踪 3 个任务。", "页面应显示操作提示")

	panel.close()
	assertions.assert_true(not panel.visible, "关闭江湖记事页面后应隐藏")

	panel.free()
