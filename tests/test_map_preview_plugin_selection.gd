extends RefCounted

const MapPreviewPluginScript = preload("res://addons/map_preview/map_preview_plugin.gd")
const PLUGIN_PATH := "res://addons/map_preview/map_preview_plugin.gd"

func run(assertions) -> void:
	_test_render_queues_deferred_object_reselect(assertions)
	_test_validation_aggregates_layout_and_content_references(assertions)
	_test_story_workbench_is_wired_into_map_preview_dock(assertions)

func _test_render_queues_deferred_object_reselect(assertions) -> void:
	var source = _read_plugin_source()
	var render_body = _function_body(source, "_render_selected_map")
	var apply_fields_body = _function_body(source, "_apply_object_fields")
	assertions.assert_true(
		_script_has_method(MapPreviewPluginScript, "_reselect_selected_object_after_render"),
		"地图预览插件应提供重建后延迟重选当前对象的 helper"
	)
	assertions.assert_true(
		render_body.contains("_queue_editor_reselect_after_render()"),
		"地图预览重建后应排队延迟重选当前对象"
	)
	assertions.assert_true(
		source.contains("func _queue_editor_reselect_after_render()"),
		"地图预览插件应封装延迟重选排队逻辑"
	)
	assertions.assert_true(
		_script_has_method(MapPreviewPluginScript, "_refresh_selected_object_handle_fields"),
		"地图预览插件应提供原地刷新选中对象字段的 helper"
	)
	assertions.assert_true(
		apply_fields_body.contains("_refresh_selected_object_handle_fields(object_id)"),
		"应用对象字段后应原地刷新当前对象 handle，避免重建预览导致丢选中"
	)

func _test_validation_aggregates_layout_and_content_references(assertions) -> void:
	var source = _read_plugin_source()
	var validation_body = _function_body(source, "_update_validation")
	assertions.assert_true(
		source.contains("ContentReferenceValidatorScript"),
		"地图预览插件应 preload 内容引用校验器"
	)
	assertions.assert_true(
		source.contains("content_reference_validator = ContentReferenceValidatorScript.new()"),
		"地图预览插件应持有内容引用校验器实例"
	)
	assertions.assert_true(
		validation_body.contains("layout_loader.validate_layout(layout, map_data)"),
		"Dock 校验应保留布局校验"
	)
	assertions.assert_true(
		validation_body.contains("content_reference_validator.validate_map(map_data)"),
		"Dock 校验应合并内容引用校验"
	)
	assertions.assert_true(
		source.contains("func _format_validation_issues"),
		"地图预览插件应封装校验结果格式化"
	)
	assertions.assert_true(
		source.contains("[color=red]") and source.contains("[color=yellow]") and source.contains("[color=green]校验通过[/color]"),
		"校验结果应覆盖 error、warning 和通过三种颜色状态"
	)

func _test_story_workbench_is_wired_into_map_preview_dock(assertions) -> void:
	var source = _read_plugin_source()
	var build_body = _function_body(source, "_build_dock")
	var select_body = _function_body(source, "_select_layout_element")
	var clear_body = _function_body(source, "_clear_selected_layout_element")
	var save_body = _function_body(source, "_save_document")
	assertions.assert_true(
		source.contains("StoryContentDocumentScript"),
		"地图预览插件应 preload 剧情内容文档"
	)
	assertions.assert_true(
		source.contains("story_content_document = StoryContentDocumentScript.new()"),
		"地图预览插件应持有剧情内容文档实例"
	)
	assertions.assert_true(
		build_body.contains("_build_story_workbench_panel()"),
		"Dock 构建时应创建剧情内容面板"
	)
	assertions.assert_true(
		select_body.contains("_update_story_workbench_for_selection(layout_id)"),
		"选中地图对象时应刷新剧情内容面板"
	)
	assertions.assert_true(
		clear_body.contains("_render_story_empty"),
		"清空选择时应清空剧情内容面板"
	)
	assertions.assert_true(
		source.contains("func _save_selected_dialogue"),
		"剧情内容面板应提供保存对白入口"
	)
	assertions.assert_true(
		source.contains("func _save_selected_quest"),
		"剧情内容面板应提供保存任务入口"
	)
	assertions.assert_true(
		source.contains("func _create_missing_dialogue_template"),
		"剧情内容面板应提供创建缺失对白模板入口"
	)
	assertions.assert_true(
		source.contains("func _create_missing_quest_template"),
		"剧情内容面板应提供创建缺失任务模板入口"
	)
	assertions.assert_false(
		save_body.contains("save_dialogues") or save_body.contains("save_quests"),
		"地图主保存按钮不应保存对白或任务"
	)

func _read_plugin_source() -> String:
	var file = FileAccess.open(PLUGIN_PATH, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()

func _function_body(source: String, method_name: String) -> String:
	var start = source.find("func %s" % method_name)
	if start < 0:
		return ""
	var next = source.find("\nfunc ", start + 1)
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)

func _script_has_method(script: Script, method_name: String) -> bool:
	for method in script.get_script_method_list():
		if str(method.get("name", "")) == method_name:
			return true
	return false
