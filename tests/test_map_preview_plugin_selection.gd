extends RefCounted

const MapPreviewPluginScript = preload("res://addons/map_preview/map_preview_plugin.gd")
const PLUGIN_PATH := "res://addons/map_preview/map_preview_plugin.gd"

func run(assertions) -> void:
	_test_render_queues_deferred_object_reselect(assertions)

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
