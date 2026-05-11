extends RefCounted

const JournalStateScript = preload("res://scripts/domain/journal_state.gd")

func run(assertions) -> void:
	var state = JournalStateScript.new()
	state.tracked_quest_ids = ["quest_mountain_trial", "quest_deliver_letter", "", "quest_mountain_trial", "quest_trace_red_thread", "quest_extra"]
	state.active_rumors["rumor_road_red_thread"] = {
		"id": "rumor_road_red_thread",
		"title": "官道红线车辙",
		"text": "官道车辙中夹着红线。",
		"source": "赶路书生",
		"related_quest_id": "quest_trace_red_thread",
		"discovered_at_map_id": "road_outskirts",
	}
	state.triggered_rumors["rumor_old"] = {
		"id": "rumor_old",
		"title": "旧传闻",
		"text": "此传闻已经触发任务。",
	}

	var serialized = state.to_dictionary()
	assertions.assert_eq(serialized.get("tracked_quest_ids", []).size(), 3, "追踪任务序列化时应限制为 3 个有效唯一编号")
	assertions.assert_eq(serialized.get("tracked_quest_ids", [])[0], "quest_mountain_trial", "追踪任务应保持原始顺序")
	assertions.assert_true(serialized.get("active_rumors", {}).has("rumor_road_red_thread"), "可追查传闻应进入序列化结果")
	assertions.assert_true(serialized.get("triggered_rumors", {}).has("rumor_old"), "已触发传闻应进入序列化结果")

	var restored = JournalStateScript.new()
	restored.from_dictionary(serialized)
	assertions.assert_eq(restored.tracked_quest_ids.size(), 3, "反序列化应恢复追踪任务")
	assertions.assert_eq(restored.active_rumors.get("rumor_road_red_thread", {}).get("source", ""), "赶路书生", "反序列化应恢复传闻来源")
	assertions.assert_eq(restored.triggered_rumors.get("rumor_old", {}).get("related_quest_id", ""), "", "缺失可选字段应补为空字符串")

	var old_save = JournalStateScript.new()
	old_save.from_dictionary({})
	assertions.assert_eq(old_save.tracked_quest_ids.size(), 0, "旧存档缺少江湖记事时追踪任务应为空")
	assertions.assert_eq(old_save.active_rumors.size(), 0, "旧存档缺少江湖记事时可追查传闻应为空")
	assertions.assert_eq(old_save.triggered_rumors.size(), 0, "旧存档缺少江湖记事时已触发传闻应为空")

	var invalid = JournalStateScript.new()
	invalid.from_dictionary({
		"tracked_quest_ids": "bad",
		"active_rumors": ["bad"],
		"triggered_rumors": {
			123: "bad",
			"rumor_valid": {
				"id": "rumor_valid",
				"title": "有效传闻",
				"text": "有效正文。"
			}
		}
	})
	assertions.assert_eq(invalid.tracked_quest_ids.size(), 0, "坏存档中的追踪任务应安全清空")
	assertions.assert_eq(invalid.active_rumors.size(), 0, "坏存档中的可追查传闻容器应安全清空")
	assertions.assert_true(invalid.triggered_rumors.has("rumor_valid"), "坏存档中有效传闻记录应保留")
	assertions.assert_true(not invalid.triggered_rumors.has("123"), "坏存档中非字典传闻记录应丢弃")
