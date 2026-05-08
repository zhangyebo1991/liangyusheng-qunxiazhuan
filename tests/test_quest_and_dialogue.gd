extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const QuestSystemScript = preload("res://scripts/systems/quest_system.gd")
const DialogueSystemScript = preload("res://scripts/systems/dialogue_system.gd")

func run(assertions) -> void:
	var quest_system = QuestSystemScript.new()
	assertions.assert_eq(quest_system.get_status("quest_first_step"), "not_started", "未接任务应返回未开始")
	assertions.assert_true(quest_system.start_quest("quest_first_step"), "开始新任务应返回成功")
	assertions.assert_eq(quest_system.get_status("quest_first_step"), "active", "开始后任务应处于进行中")
	assertions.assert_true(quest_system.complete_quest("quest_first_step"), "完成进行中的任务应返回成功")
	assertions.assert_eq(quest_system.get_status("quest_first_step"), "completed", "完成后任务应处于已完成")
	assertions.assert_true(not quest_system.start_quest("quest_first_step"), "已完成任务不应重新开始")

	var repository = DataRepositoryScript.new()
	repository.load_all()
	var dialogue_system = DialogueSystemScript.new()
	dialogue_system.set_repository(repository)
	var lines = dialogue_system.get_lines("intro_meet_master")
	assertions.assert_eq(lines.size(), 2, "对话应返回 2 行文本")
	assertions.assert_eq(lines[0].get("speaker", ""), "青衫客", "第一行说话人应正确")
	assertions.assert_eq(dialogue_system.get_title("missing_dialogue"), "", "缺失对话标题应返回空字符串")
	repository.free()
