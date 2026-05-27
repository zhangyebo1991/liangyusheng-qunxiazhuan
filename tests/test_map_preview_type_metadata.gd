extends RefCounted

const MapPreviewTypesScript = preload("res://addons/map_preview/map_preview_type_metadata.gd")

func run(assertions) -> void:
	_test_type_labels_and_colors(assertions)
	_test_object_label_fallback(assertions)
	_test_object_summary_rows_and_counts(assertions)
	_test_object_list_button_text(assertions)

func _test_type_labels_and_colors(assertions) -> void:
	assertions.assert_eq(MapPreviewTypesScript.type_label("npc"), "NPC", "NPC 类型应显示为 NPC")
	assertions.assert_eq(MapPreviewTypesScript.type_label("battle_trigger"), "战斗", "战斗触发点应显示为战斗")
	assertions.assert_eq(MapPreviewTypesScript.type_label("exit"), "出口", "出口类型应显示为出口")
	assertions.assert_eq(MapPreviewTypesScript.type_label("unknown_type"), "对象", "未知类型应显示为对象")
	assertions.assert_eq(MapPreviewTypesScript.type_color("exit").to_html(false), "2f6fdd", "出口颜色应沿用现有蓝色")
	assertions.assert_eq(MapPreviewTypesScript.type_color("unknown_type").to_html(false), "666666", "未知类型应使用默认灰色")

func _test_object_label_fallback(assertions) -> void:
	var named = {"id": "npc_demo", "type": "npc", "name": "演示 NPC"}
	var unnamed = {"id": "exit_demo", "type": "exit"}
	assertions.assert_eq(MapPreviewTypesScript.object_display_name(named), "演示 NPC", "对象名称应优先使用 name")
	assertions.assert_eq(MapPreviewTypesScript.object_display_name(unnamed), "exit_demo", "缺少 name 时应回退 id")
	assertions.assert_eq(MapPreviewTypesScript.object_label(named), "演示 NPC / NPC", "对象标签应包含名称和类型")
	assertions.assert_eq(MapPreviewTypesScript.spawn_label("start"), "出生点 / start", "出生点标签应包含 spawn_id")
	assertions.assert_eq(MapPreviewTypesScript.obstacle_label("wall"), "障碍 / wall", "障碍标签应包含 obstacle_id")

func _test_object_summary_rows_and_counts(assertions) -> void:
	var summary = MapPreviewTypesScript.build_object_summary([
		{"id": "npc_demo", "type": "npc", "name": "演示 NPC"},
		{"id": "exit_demo", "type": "exit", "name": "演示出口"},
		{"id": "enemy_demo", "type": "battle_trigger", "name": "演示战斗"},
		{"id": "unknown_demo", "type": "unknown_type"}
	])
	var counts = summary.get("counts", {})
	var rows = summary.get("rows", [])
	assertions.assert_eq(counts.get("npc", 0), 1, "摘要应统计 NPC 数量")
	assertions.assert_eq(counts.get("exit", 0), 1, "摘要应统计出口数量")
	assertions.assert_eq(counts.get("battle_trigger", 0), 1, "摘要应统计战斗数量")
	assertions.assert_eq(counts.get("object", 0), 1, "未知类型应归入对象数量")
	assertions.assert_eq(rows.size(), 4, "摘要应保留所有合法对象行")
	assertions.assert_eq(rows[0].get("label", ""), "演示 NPC / NPC", "摘要行应包含可读标签")
	assertions.assert_eq(rows[3].get("name", ""), "unknown_demo", "未知类型对象缺少名称时应回退 id")
	assertions.assert_eq(rows[3].get("type_label", ""), "对象", "未知类型对象行应显示对象")

func _test_object_list_button_text(assertions) -> void:
	var row = {
		"id": "npc_demo",
		"name": "演示 NPC",
		"type_label": "NPC",
	}
	var has_helper = _script_has_method(MapPreviewTypesScript, "object_list_button_text")
	assertions.assert_true(has_helper, "类型元数据应提供对象列表按钮文本 helper")
	if not has_helper:
		return
	assertions.assert_eq(
		MapPreviewTypesScript.object_list_button_text(row, ""),
		"  ■ 演示 NPC / NPC / npc_demo",
		"未选中对象列表行应显示名称、类型和编号"
	)
	assertions.assert_eq(
		MapPreviewTypesScript.object_list_button_text(row, "npc_demo"),
		"> ■ 演示 NPC / NPC / npc_demo",
		"选中对象列表行应显示选中标记"
	)

func _script_has_method(script: Script, method_name: String) -> bool:
	for method in script.get_script_method_list():
		if str(method.get("name", "")) == method_name:
			return true
	return false
