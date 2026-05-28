extends RefCounted

const ContentReferenceValidatorScript = preload("res://addons/map_preview/content_reference_validator.gd")

func run(assertions) -> void:
	_test_valid_current_map_references(assertions)
	_test_missing_basic_references(assertions)
	_test_exit_reference_errors(assertions)
	_test_battle_trigger_references_and_battle_id_warning(assertions)
	_test_effect_reference_errors(assertions)
	_test_malformed_sources_and_fields_report_errors(assertions)

func _test_valid_current_map_references(assertions) -> void:
	var paths = _write_fixture("valid")
	var validator = ContentReferenceValidatorScript.new()
	validator.set_paths(paths.get("data_paths", {}), str(paths.get("layouts_dir", "")))

	var issues = validator.validate_map({
		"id": "demo_map",
		"objects": [
			{
				"id": "npc_valid",
				"type": "npc",
				"dialogue_id": "dialogue_valid",
				"quest_id": "quest_valid",
				"actor_id": "actor_valid"
			},
			{
				"id": "exit_valid",
				"type": "exit",
				"target_map_id": "target_map",
				"target_spawn_id": "arrival"
			},
			{
				"id": "battle_valid",
				"type": "battle_trigger",
				"actor_id": "enemy_valid",
				"units": [
					{"unit_id": "enemy_valid", "actor_id": "enemy_valid", "team": "enemy"}
				],
				"victory_rewards": {
					"loot_table": {
						"entries": [
							{"type": "item", "item_id": "item_valid", "chance": 1.0},
							{"type": "coins", "amount_min": 1, "amount_max": 2}
						]
					}
				}
			},
			{
				"id": "pickup_valid",
				"type": "pickup",
				"effects": [
					{"type": "add_item", "item_id": "item_valid", "amount": 1},
					{"type": "set_quest_status", "quest_id": "quest_valid", "status": "completed"},
					{"type": "resolve_map_object", "object_id": "pickup_valid"},
					{"type": "add_party_member", "actor_id": "actor_valid"}
				]
			}
		]
	})

	assertions.assert_eq(_count_severity(issues, "error"), 0, "合法当前地图引用不应产生 error")
	assertions.assert_eq(_count_severity(issues, "warning"), 0, "合法当前地图引用不应产生 warning")

func _test_missing_basic_references(assertions) -> void:
	var paths = _write_fixture("basic_missing")
	var validator = ContentReferenceValidatorScript.new()
	validator.set_paths(paths.get("data_paths", {}), str(paths.get("layouts_dir", "")))

	var issues = validator.validate_map({
		"id": "demo_map",
		"objects": [
			{
				"id": "npc_missing",
				"type": "npc",
				"dialogue_id": "dialogue_missing",
				"quest_id": "quest_missing",
				"required_quest_id": "required_quest_missing",
				"actor_id": "actor_missing"
			}
		]
	})

	assertions.assert_true(_has_issue(issues, "error", "npc_missing", "dialogue_id", "dialogue_missing"), "缺失对白应产生对象字段 error")
	assertions.assert_true(_has_issue(issues, "error", "npc_missing", "quest_id", "quest_missing"), "缺失 quest_id 应产生对象字段 error")
	assertions.assert_true(_has_issue(issues, "error", "npc_missing", "required_quest_id", "required_quest_missing"), "缺失 required_quest_id 应产生对象字段 error")
	assertions.assert_true(_has_issue(issues, "error", "npc_missing", "actor_id", "actor_missing"), "缺失 actor_id 应产生对象字段 error")

func _test_exit_reference_errors(assertions) -> void:
	var paths = _write_fixture("exit_missing")
	var validator = ContentReferenceValidatorScript.new()
	validator.set_paths(paths.get("data_paths", {}), str(paths.get("layouts_dir", "")))

	var issues = validator.validate_map({
		"id": "demo_map",
		"objects": [
			{"id": "exit_no_target", "type": "exit", "target_map_id": "", "target_spawn_id": "arrival"},
			{"id": "exit_bad_map", "type": "exit", "target_map_id": "missing_map", "target_spawn_id": "arrival"},
			{"id": "exit_bad_spawn", "type": "exit", "target_map_id": "target_map", "target_spawn_id": "missing_spawn"}
		]
	})

	assertions.assert_true(_has_issue(issues, "error", "exit_no_target", "target_map_id", "出口缺少目标地图"), "空 target_map_id 应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "exit_bad_map", "target_map_id", "missing_map"), "不存在 target_map_id 应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "exit_bad_spawn", "target_spawn_id", "missing_spawn"), "不存在 target_spawn_id 应产生 error")
	assertions.assert_false(_has_issue(issues, "error", "exit_bad_map", "target_spawn_id", "arrival"), "目标地图不存在时不应重复报告 target_spawn_id")

func _test_battle_trigger_references_and_battle_id_warning(assertions) -> void:
	var paths = _write_fixture("battle_missing")
	var validator = ContentReferenceValidatorScript.new()
	validator.set_paths(paths.get("data_paths", {}), str(paths.get("layouts_dir", "")))

	var issues = validator.validate_map({
		"id": "demo_map",
		"objects": [
			{
				"id": "battle_missing",
				"type": "battle_trigger",
				"actor_id": "enemy_missing",
				"battle_id": "battle_placeholder",
				"encounter_id": "label_only",
				"units": [
					{"unit_id": "enemy_missing", "actor_id": "enemy_missing", "team": "enemy"}
				],
				"victory_rewards": {
					"loot_table": {
						"entries": [
							{"type": "item", "item_id": "item_missing", "chance": 1.0}
						]
					}
				}
			}
		]
	})

	assertions.assert_true(_has_issue(issues, "error", "battle_missing", "actor_id", "enemy_missing"), "战斗触发点顶层 actor_id 缺失应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "battle_missing", "units[0].actor_id", "enemy_missing"), "战斗单位 actor_id 缺失应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "battle_missing", "victory_rewards.loot_table.entries[0].item_id", "item_missing"), "掉落表物品缺失应产生 error")
	assertions.assert_true(_has_issue(issues, "warning", "battle_missing", "battle_id", "暂不校验"), "battle_id 应产生 warning")
	assertions.assert_false(_has_issue(issues, "error", "battle_missing", "battle_id", "battle_placeholder"), "battle_id 不应产生 error")
	assertions.assert_false(_has_issue(issues, "error", "battle_missing", "encounter_id", "label_only"), "encounter_id 第一版只作标签")

func _test_effect_reference_errors(assertions) -> void:
	var paths = _write_fixture("effect_missing")
	var validator = ContentReferenceValidatorScript.new()
	validator.set_paths(paths.get("data_paths", {}), str(paths.get("layouts_dir", "")))

	var issues = validator.validate_map({
		"id": "demo_map",
		"objects": [
			{
				"id": "pickup_missing",
				"type": "pickup",
				"effects": [
					{"type": "add_item", "item_id": "item_missing", "amount": 1},
					{"type": "remove_item", "item_id": "item_missing_2", "amount": 1},
					{"type": "set_quest_status", "quest_id": "quest_missing", "status": "completed"},
					{"type": "resolve_map_object", "object_id": "object_missing"},
					{"type": "add_party_member", "actor_id": "actor_missing"}
				]
			}
		]
	})

	assertions.assert_true(_has_issue(issues, "error", "pickup_missing", "effects[0].item_id", "item_missing"), "add_item 缺失 item_id 应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "pickup_missing", "effects[1].item_id", "item_missing_2"), "remove_item 缺失 item_id 应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "pickup_missing", "effects[2].quest_id", "quest_missing"), "set_quest_status 缺失 quest_id 应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "pickup_missing", "effects[3].object_id", "object_missing"), "resolve_map_object 缺失 object_id 应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "pickup_missing", "effects[4].actor_id", "actor_missing"), "add_party_member 缺失 actor_id 应产生 error")

func _test_malformed_sources_and_fields_report_errors(assertions) -> void:
	var paths = _write_fixture("malformed")
	var data_paths = paths.get("data_paths", {}).duplicate(true)
	_write_json(str(data_paths.get("dialogues", "")), {"bad": "root"})

	var validator = ContentReferenceValidatorScript.new()
	validator.set_paths(data_paths, str(paths.get("layouts_dir", "")))
	var issues = validator.validate_map({"id": "demo_map", "objects": "bad"})

	assertions.assert_true(_has_issue(issues, "error", "", "dialogues", "必须是数组"), "格式错误的数据源应产生 error")
	assertions.assert_true(_has_issue(issues, "error", "", "objects", "对象列表格式错误"), "objects 不是数组应产生 error")

	var field_issues = validator.validate_map({
		"id": "demo_map",
		"objects": [
			{"id": "bad_fields", "type": "battle_trigger", "units": "bad", "effects": "bad", "victory_rewards": {"loot_table": {"entries": "bad"}}}
		]
	})
	assertions.assert_true(_has_issue(field_issues, "error", "bad_fields", "units", "必须是数组"), "units 格式错误应产生 error")
	assertions.assert_true(_has_issue(field_issues, "error", "bad_fields", "effects", "必须是数组"), "effects 格式错误应产生 error")
	assertions.assert_true(_has_issue(field_issues, "error", "bad_fields", "victory_rewards.loot_table.entries", "必须是数组"), "掉落表 entries 格式错误应产生 error")

func _write_fixture(name: String) -> Dictionary:
	var base = "user://content_reference_validator_%s" % name
	var layouts_dir = "%s_layouts" % base
	var layouts_absolute = ProjectSettings.globalize_path(layouts_dir)
	DirAccess.make_dir_recursive_absolute(layouts_absolute)

	var data_paths = {
		"actors": "%s_actors.json" % base,
		"items": "%s_items.json" % base,
		"quests": "%s_quests.json" % base,
		"dialogues": "%s_dialogues.json" % base,
		"maps": "%s_maps.json" % base
	}
	_write_json(data_paths["actors"], [
		{"id": "actor_valid", "name": "有效角色"},
		{"id": "enemy_valid", "name": "有效敌人"}
	])
	_write_json(data_paths["items"], [
		{"id": "item_valid", "name": "有效物品"}
	])
	_write_json(data_paths["quests"], [
		{"id": "quest_valid", "title": "有效任务"}
	])
	_write_json(data_paths["dialogues"], [
		{"id": "dialogue_valid", "title": "有效对白", "lines": []}
	])
	_write_json(data_paths["maps"], [
		{"id": "demo_map", "name": "演示地图", "objects": []},
		{"id": "target_map", "name": "目标地图", "objects": []}
	])
	_write_json("%s/target_map.json" % layouts_dir, {
		"map_id": "target_map",
		"spawn_points": {"arrival": {"x": 1, "y": 2}}
	})

	return {"data_paths": data_paths, "layouts_dir": layouts_dir}

func _write_json(path: String, value: Variant) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入测试 JSON：%s" % path)
		return
	file.store_string(JSON.stringify(value, "\t"))
	file.close()

func _has_issue(issues: Array, severity: String, object_id: String, field: String, message_part: String) -> bool:
	for issue in issues:
		if typeof(issue) != TYPE_DICTIONARY:
			continue
		if str(issue.get("severity", "")) != severity:
			continue
		if str(issue.get("object_id", "")) != object_id:
			continue
		if str(issue.get("field", "")) != field:
			continue
		if str(issue.get("message", "")).find(message_part) < 0:
			continue
		return true
	return false

func _count_severity(issues: Array, severity: String) -> int:
	var count := 0
	for issue in issues:
		if typeof(issue) == TYPE_DICTIONARY and str(issue.get("severity", "")) == severity:
			count += 1
	return count
