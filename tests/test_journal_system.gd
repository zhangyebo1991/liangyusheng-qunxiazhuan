extends RefCounted

const JournalStateScript = preload("res://scripts/domain/journal_state.gd")
const JournalSystemScript = preload("res://scripts/systems/journal_system.gd")
const QuestSystemScript = preload("res://scripts/systems/quest_system.gd")

class StubRepository:
	extends Node
	var quests: Dictionary = {
		"quest_mountain_trial": {"id": "quest_mountain_trial", "title": "山道试剑", "description": "击退山道强人。"},
		"quest_deliver_letter": {"id": "quest_deliver_letter", "title": "送信到客栈", "description": "替脚夫送信。"},
		"quest_trace_red_thread": {"id": "quest_trace_red_thread", "title": "追查红线车辙", "description": "查明红线记号。"},
		"quest_extra": {"id": "quest_extra", "title": "额外任务", "description": "第四个任务。"},
	}
	func get_quest(quest_id: String) -> Dictionary:
		return quests.get(quest_id, {})

class StubGameState:
	extends RefCounted
	var quest_system = QuestSystemScript.new()
	var journal_state

func run(assertions) -> void:
	var journal = JournalStateScript.new()
	var system = JournalSystemScript.new()

	var add_result = system.add_rumor(journal, {
		"id": "rumor_road_red_thread",
		"title": "官道红线车辙",
		"text": "官道车辙中夹着红线。",
		"source": "赶路书生",
		"related_quest_id": "quest_trace_red_thread",
	}, {"map_id": "road_outskirts"})
	assertions.assert_true(bool(add_result.get("success", false)), "合法传闻应添加成功")
	assertions.assert_true(journal.active_rumors.has("rumor_road_red_thread"), "传闻应进入可追查列表")
	assertions.assert_eq(journal.active_rumors.get("rumor_road_red_thread", {}).get("discovered_at_map_id", ""), "road_outskirts", "缺省发现地图应来自上下文")

	var duplicate = system.add_rumor(journal, {
		"id": "rumor_road_red_thread",
		"title": "官道红线车辙",
		"text": "重复正文。",
	})
	assertions.assert_true(bool(duplicate.get("success", false)), "重复传闻应作为安全成功处理")
	assertions.assert_eq(journal.active_rumors.size(), 1, "重复传闻不应重复记录")
	assertions.assert_true(bool(duplicate.get("duplicate", false)), "重复传闻结果应标记 duplicate")

	var missing_id = system.add_rumor(journal, {"title": "无编号", "text": "无编号正文。"})
	assertions.assert_true(not bool(missing_id.get("success", true)), "空传闻编号应失败")
	assertions.assert_eq(missing_id.get("message", ""), "传闻编号缺失。", "空传闻编号应返回中文提示")

	var missing_text = system.add_rumor(journal, {"id": "rumor_empty", "title": "空正文", "text": ""})
	assertions.assert_true(not bool(missing_text.get("success", true)), "空传闻正文应失败")
	assertions.assert_eq(missing_text.get("message", ""), "传闻内容缺失。", "空传闻正文应返回中文提示")

	var trigger_result = system.trigger_rumor(journal, "rumor_road_red_thread")
	assertions.assert_true(bool(trigger_result.get("success", false)), "已有传闻应可归档为已触发")
	assertions.assert_true(not journal.active_rumors.has("rumor_road_red_thread"), "归档后传闻不应留在可追查列表")
	assertions.assert_true(journal.triggered_rumors.has("rumor_road_red_thread"), "归档后传闻应进入已触发列表")

	var missing_trigger = system.trigger_rumor(journal, "missing_rumor")
	assertions.assert_true(not bool(missing_trigger.get("success", true)), "触发不存在传闻应失败")
	assertions.assert_eq(missing_trigger.get("message", ""), "传闻尚未记录：missing_rumor", "触发不存在传闻应返回中文提示")

	system.add_rumor(journal, {
		"id": "rumor_for_quest",
		"title": "任务传闻",
		"text": "这条传闻对应任务。",
		"related_quest_id": "quest_trace_red_thread",
	})
	var quest_trigger = system.mark_rumors_triggered_for_quest(journal, "quest_trace_red_thread")
	assertions.assert_true(bool(quest_trigger.get("success", false)), "按任务归档相关传闻应成功")
	assertions.assert_true(journal.triggered_rumors.has("rumor_for_quest"), "相关任务传闻应进入已触发列表")

	assertions.assert_true(bool(system.toggle_tracked_quest(journal, "quest_mountain_trial").get("success", false)), "第一个任务应可追踪")
	assertions.assert_true(bool(system.toggle_tracked_quest(journal, "quest_deliver_letter").get("success", false)), "第二个任务应可追踪")
	assertions.assert_true(bool(system.toggle_tracked_quest(journal, "quest_trace_red_thread").get("success", false)), "第三个任务应可追踪")
	var fourth = system.toggle_tracked_quest(journal, "quest_extra")
	assertions.assert_true(not bool(fourth.get("success", true)), "第四个追踪任务应被拒绝")
	assertions.assert_eq(fourth.get("message", ""), "最多只能追踪 3 个任务。", "超过追踪上限应返回中文提示")
	assertions.assert_eq(journal.tracked_quest_ids.size(), 3, "超过上限后原追踪列表不应改变")
	assertions.assert_true(bool(system.toggle_tracked_quest(journal, "quest_deliver_letter").get("success", false)), "已追踪任务应可取消追踪")
	assertions.assert_true(not system.is_quest_tracked(journal, "quest_deliver_letter"), "取消后任务不应继续追踪")

	var state = StubGameState.new()
	state.journal_state = journal
	state.quest_system.start_quest("quest_mountain_trial")
	state.quest_system.set_status("quest_deliver_letter", "completed")
	journal.tracked_quest_ids = ["quest_mountain_trial", "quest_trace_red_thread"]
	var repository = StubRepository.new()
	var tasks = system.build_task_entries(state, repository)
	assertions.assert_eq(tasks.size(), 3, "任务条目应包含已有状态任务和追踪任务")
	assertions.assert_eq(tasks[0].get("title", ""), "山道试剑", "任务条目应读取任务标题")
	assertions.assert_true(bool(tasks[0].get("tracked", false)), "任务条目应标记追踪状态")
	var tracked = system.build_tracked_task_entries(state, repository)
	assertions.assert_eq(tracked.size(), 2, "追踪任务条目应按追踪列表生成")
	assertions.assert_eq(tracked[0].get("status_text", ""), "进行中", "任务状态应转成中文")

	var rumor_entries = system.build_rumor_entries(journal)
	assertions.assert_true(rumor_entries.get("active", []).is_empty(), "已全部归档时可追查传闻列表应为空")
	assertions.assert_true(rumor_entries.get("triggered", []).size() >= 2, "已触发传闻列表应包含归档传闻")

	repository.free()
