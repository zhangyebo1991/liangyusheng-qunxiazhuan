extends RefCounted

const STORY_CONTENT_DOCUMENT_PATH = "res://addons/map_preview/story_content_document.gd"

func run(assertions) -> void:
	_test_loads_and_indexes_dialogues_and_quests(assertions)
	_test_updates_dialogue_and_saves_array(assertions)
	_test_updates_quest_and_saves_array(assertions)
	_test_creates_missing_dialogue_and_quest_templates(assertions)
	_test_rejects_dirty_save_after_external_change(assertions)
	_test_invalid_template_ids_and_duplicates_report_errors(assertions)

func _test_loads_and_indexes_dialogues_and_quests(assertions) -> void:
	var paths = _write_fixture("load")
	var document = _new_document(assertions)
	if document == null:
		return
	assertions.assert_true(document.load_all(paths["dialogues_path"], paths["quests_path"]), "剧情内容文档应能加载对白和任务")

	var dialogue = document.get_dialogue("dialogue_intro")
	assertions.assert_eq(dialogue.get("title", ""), "初见", "应能按 id 找到对白")
	assertions.assert_eq(dialogue.get("lines", []).size(), 1, "对白行应保留")

	var quest = document.get_quest("quest_intro")
	assertions.assert_eq(quest.get("title", ""), "入门任务", "应能按 id 找到任务")

	var refs = document.find_quests_for_dialogue("dialogue_intro")
	assertions.assert_eq(refs.size(), 2, "应反查 start_dialogue 和 complete_dialogue 引用")
	assertions.assert_true(_has_quest_ref(refs, "quest_intro", "start_dialogue"), "应包含 start_dialogue 引用")
	assertions.assert_true(_has_quest_ref(refs, "quest_finish", "complete_dialogue"), "应包含 complete_dialogue 引用")
	assertions.assert_true(document.get_dialogue("missing_dialogue").is_empty(), "缺失对白应返回空字典")
	assertions.assert_true(document.get_quest("missing_quest").is_empty(), "缺失任务应返回空字典")

func _test_updates_dialogue_and_saves_array(assertions) -> void:
	var paths = _write_fixture("dialogue_save")
	var document = _new_document(assertions)
	if document == null:
		return
	document.load_all(paths["dialogues_path"], paths["quests_path"])

	var title_result = document.update_dialogue_title("dialogue_intro", "改后标题")
	assertions.assert_true(title_result.get("ok", false), "更新对白标题应成功")
	var lines_result = document.set_dialogue_lines("dialogue_intro", [
		{"speaker": "青衫客", "text": "新对白。"},
		{"speaker": "云游少侠", "text": "晚辈记下了。"}
	])
	assertions.assert_true(lines_result.get("ok", false), "更新对白行应成功")
	assertions.assert_true(document.dialogues_dirty, "更新对白后应标记对白 dirty")
	assertions.assert_true(document.save_dialogues(), "保存对白应成功")
	assertions.assert_false(document.dialogues_dirty, "保存对白后 dirty 应清除")

	var saved = _read_json(paths["dialogues_path"])
	assertions.assert_eq(typeof(saved), TYPE_ARRAY, "保存后的 dialogues.json 仍应是数组")
	assertions.assert_eq(saved[0].get("title", ""), "改后标题", "保存后的对白标题应更新")
	assertions.assert_eq(saved[0].get("lines", []).size(), 2, "保存后的对白行数量应更新")
	assertions.assert_eq(saved[0].get("lines", [])[1].get("text", ""), "晚辈记下了。", "保存后的对白行文本应更新")

func _test_updates_quest_and_saves_array(assertions) -> void:
	var paths = _write_fixture("quest_save")
	var document = _new_document(assertions)
	if document == null:
		return
	document.load_all(paths["dialogues_path"], paths["quests_path"])

	var result = document.update_quest_summary("quest_intro", "改后任务", "新的任务描述。")
	assertions.assert_true(result.get("ok", false), "更新任务摘要应成功")
	assertions.assert_true(document.quests_dirty, "更新任务后应标记任务 dirty")
	assertions.assert_true(document.save_quests(), "保存任务应成功")
	assertions.assert_false(document.quests_dirty, "保存任务后 dirty 应清除")

	var saved = _read_json(paths["quests_path"])
	assertions.assert_eq(typeof(saved), TYPE_ARRAY, "保存后的 quests.json 仍应是数组")
	assertions.assert_eq(saved[0].get("title", ""), "改后任务", "保存后的任务标题应更新")
	assertions.assert_eq(saved[0].get("description", ""), "新的任务描述。", "保存后的任务描述应更新")

func _test_creates_missing_dialogue_and_quest_templates(assertions) -> void:
	var paths = _write_fixture("templates")
	var document = _new_document(assertions)
	if document == null:
		return
	document.load_all(paths["dialogues_path"], paths["quests_path"])

	var dialogue_result = document.create_dialogue_template("dialogue_missing_template")
	assertions.assert_true(dialogue_result.get("ok", false), "创建缺失对白模板应成功")
	var dialogue = document.get_dialogue("dialogue_missing_template")
	assertions.assert_eq(dialogue.get("title", ""), "新对白", "对白模板标题应使用固定初始值")
	assertions.assert_eq(dialogue.get("lines", []).size(), 1, "对白模板应包含一行空对白")
	assertions.assert_true(document.dialogues_dirty, "创建对白模板后应标记对白 dirty")

	var quest_result = document.create_quest_template("quest_missing_template")
	assertions.assert_true(quest_result.get("ok", false), "创建缺失任务模板应成功")
	var quest = document.get_quest("quest_missing_template")
	assertions.assert_eq(quest.get("title", ""), "新任务", "任务模板标题应使用固定初始值")
	assertions.assert_eq(quest.get("description", ""), "", "任务模板描述应为空字符串")
	assertions.assert_true(document.quests_dirty, "创建任务模板后应标记任务 dirty")

func _test_rejects_dirty_save_after_external_change(assertions) -> void:
	var paths = _write_fixture("external_change")
	var document = _new_document(assertions)
	if document == null:
		return
	document.load_all(paths["dialogues_path"], paths["quests_path"])

	document.update_dialogue_title("dialogue_intro", "本地对白标题")
	_write_json(paths["dialogues_path"], [
		{"id": "dialogue_intro", "title": "外部对白标题", "lines": []}
	])
	assertions.assert_false(document.save_dialogues(), "对白 dirty 且磁盘已变化时应拒绝保存")
	assertions.assert_true(document.last_error.find("对白文件已被外部修改") >= 0, "对白保存冲突应说明外部修改")

	document.load_all(paths["dialogues_path"], paths["quests_path"])
	document.update_quest_summary("quest_intro", "本地任务标题", "本地任务描述")
	_write_json(paths["quests_path"], [
		{"id": "quest_intro", "title": "外部任务标题", "description": "外部任务描述"}
	])
	assertions.assert_false(document.save_quests(), "任务 dirty 且磁盘已变化时应拒绝保存")
	assertions.assert_true(document.last_error.find("任务文件已被外部修改") >= 0, "任务保存冲突应说明外部修改")

func _test_invalid_template_ids_and_duplicates_report_errors(assertions) -> void:
	var paths = _write_fixture("invalid_templates")
	var document = _new_document(assertions)
	if document == null:
		return
	document.load_all(paths["dialogues_path"], paths["quests_path"])

	var empty_dialogue_result = document.create_dialogue_template("  ")
	assertions.assert_false(empty_dialogue_result.get("ok", true), "空对白 id 不应创建模板")
	assertions.assert_true(str(empty_dialogue_result.get("error", "")).find("对白编号不能为空") >= 0, "空对白 id 应返回明确错误")

	var duplicate_dialogue_result = document.create_dialogue_template("dialogue_intro")
	assertions.assert_false(duplicate_dialogue_result.get("ok", true), "重复对白 id 不应创建模板")
	assertions.assert_true(str(duplicate_dialogue_result.get("error", "")).find("对白已存在") >= 0, "重复对白 id 应返回明确错误")

	var empty_quest_result = document.create_quest_template("")
	assertions.assert_false(empty_quest_result.get("ok", true), "空任务 id 不应创建模板")
	assertions.assert_true(str(empty_quest_result.get("error", "")).find("任务编号不能为空") >= 0, "空任务 id 应返回明确错误")

	var duplicate_quest_result = document.create_quest_template("quest_intro")
	assertions.assert_false(duplicate_quest_result.get("ok", true), "重复任务 id 不应创建模板")
	assertions.assert_true(str(duplicate_quest_result.get("error", "")).find("任务已存在") >= 0, "重复任务 id 应返回明确错误")

func _write_fixture(name: String) -> Dictionary:
	var base = "user://story_content_document_%s" % name
	var dialogues_path = "%s_dialogues.json" % base
	var quests_path = "%s_quests.json" % base
	_write_json(dialogues_path, [
		{
			"id": "dialogue_intro",
			"title": "初见",
			"lines": [
				{"speaker": "青衫客", "text": "江湖路远。"}
			],
			"options": [
				{"id": "option_demo", "text": "告辞", "next_dialogue_id": "dialogue_finish"}
			]
		},
		{
			"id": "dialogue_finish",
			"title": "收束",
			"lines": []
		}
	])
	_write_json(quests_path, [
		{
			"id": "quest_intro",
			"title": "入门任务",
			"description": "向青衫客请教。",
			"start_dialogue": "dialogue_intro",
			"reward_items": ["herb_small"]
		},
		{
			"id": "quest_finish",
			"title": "收束任务",
			"description": "回报青衫客。",
			"complete_dialogue": "dialogue_intro",
			"complete_effects": [
				{"type": "set_quest_status", "quest_id": "quest_finish", "status": "completed"}
			]
		}
	])
	return {"dialogues_path": dialogues_path, "quests_path": quests_path}

func _write_json(path: String, value: Variant) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入测试 JSON：%s" % path)
		return
	file.store_string(JSON.stringify(value, "\t"))
	file.close()

func _read_json(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())

func _has_quest_ref(refs: Array, quest_id: String, field: String) -> bool:
	for ref in refs:
		if typeof(ref) != TYPE_DICTIONARY:
			continue
		if str(ref.get("quest_id", "")) == quest_id and str(ref.get("field", "")) == field:
			return true
	return false

func _new_document(assertions) -> Variant:
	var script = load(STORY_CONTENT_DOCUMENT_PATH)
	assertions.assert_true(script != null, "应存在剧情内容文档脚本：%s" % STORY_CONTENT_DOCUMENT_PATH)
	if script == null:
		return null
	return script.new()
