@tool
extends EditorPlugin

const MapLayoutDocumentScript = preload("res://addons/map_preview/map_layout_document.gd")
const MapContentDocumentScript = preload("res://addons/map_preview/map_content_document.gd")
const MapPreviewRendererScript = preload("res://addons/map_preview/map_preview_renderer.gd")
const MapLayoutLoaderScript = preload("res://scripts/systems/map_layout_loader.gd")
const MapPreviewTypesScript = preload("res://addons/map_preview/map_preview_type_metadata.gd")

const MAP_INDEX_PATH := "res://data/maps.json"

var dock: VBoxContainer
var map_selector: OptionButton
var status_label: Label
var validation_label: RichTextLabel
var refresh_button: Button
var save_button: Button
var reload_button: Button
var auto_refresh_check: CheckBox
var legend_label: RichTextLabel
var object_list_container: VBoxContainer
var object_id_input: LineEdit
var selected_layout_kind := ""
var selected_layout_id := ""
var selection_label: Label
var position_x_spin: SpinBox
var position_y_spin: SpinBox
var object_name_input: LineEdit
var object_type_input: LineEdit
var radius_spin: SpinBox
var obstacle_id_input: LineEdit
var obstacle_width_spin: SpinBox
var obstacle_height_spin: SpinBox
var new_element_type_selector: OptionButton
var new_element_id_input: LineEdit
var new_element_name_input: LineEdit
var new_element_reference_input: LineEdit
var new_element_spawn_input: LineEdit
var new_element_x_spin: SpinBox
var new_element_y_spin: SpinBox
var new_element_radius_spin: SpinBox
var new_element_width_spin: SpinBox
var new_element_height_spin: SpinBox
var selected_map_id := ""
var selected_object_id := ""
var content_document = MapContentDocumentScript.new()
var document = MapLayoutDocumentScript.new()
var renderer = MapPreviewRendererScript.new()
var layout_loader = MapLayoutLoaderScript.new()
var maps_by_id: Dictionary = {}
var scene_path_to_map_id: Dictionary = {}
var poll_elapsed := 0.0
var layout_save_conflict_confirm_pending := false
var content_save_conflict_confirm_pending := false
var manual_content_refresh_confirm_pending := false
var active_scene_path := ""

func _enter_tree() -> void:
	_build_dock()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	renderer.handle_changed.connect(_on_preview_handle_changed)
	if not scene_changed.is_connected(_on_scene_changed):
		scene_changed.connect(_on_scene_changed)
	_load_map_index()
	set_process(true)
	call_deferred("_refresh_from_current_scene")

func _exit_tree() -> void:
	set_process(false)
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	var scene_root = _edited_scene_root()
	if scene_root != null:
		renderer.clear(scene_root)
	if dock != null:
		remove_control_from_docks(dock)
		dock.queue_free()

func _process(delta: float) -> void:
	poll_elapsed += delta
	if poll_elapsed < 1.0:
		return
	poll_elapsed = 0.0
	_refresh_if_scene_changed()
	if auto_refresh_check != null and auto_refresh_check.button_pressed:
		_check_map_index_refresh()
		if not selected_map_id.is_empty():
			_check_external_refresh()

func _save_external_data() -> void:
	var saved_any := false
	var blocked_content := false
	var blocked_layout := false
	if content_document.is_dirty():
		if content_document.has_external_change():
			blocked_content = true
		elif content_document.save():
			saved_any = true
	if document.is_dirty():
		if document.has_external_change():
			blocked_layout = true
		elif document.save():
			saved_any = true
	if blocked_content or blocked_layout:
		var blocked_files := PackedStringArray()
		if blocked_content:
			blocked_files.append("data/maps.json")
		if blocked_layout:
			blocked_files.append("布局文件")
		_update_status("项目保存未覆盖外部修改：%s。" % "、".join(blocked_files))
	elif saved_any:
		_update_status("已随项目保存地图编辑。")

func _build_dock() -> void:
	dock = VBoxContainer.new()
	dock.name = "地图预览"

	var title = Label.new()
	title.text = "地图预览"
	dock.add_child(title)

	map_selector = OptionButton.new()
	map_selector.item_selected.connect(_on_map_selected)
	dock.add_child(map_selector)

	auto_refresh_check = CheckBox.new()
	auto_refresh_check.text = "自动刷新外部修改"
	auto_refresh_check.button_pressed = true
	dock.add_child(auto_refresh_check)

	var buttons = HBoxContainer.new()
	dock.add_child(buttons)

	refresh_button = Button.new()
	refresh_button.text = "刷新"
	refresh_button.pressed.connect(_manual_refresh_selected_map)
	buttons.add_child(refresh_button)

	save_button = Button.new()
	save_button.text = "保存"
	save_button.pressed.connect(_save_document)
	buttons.add_child(save_button)

	reload_button = Button.new()
	reload_button.text = "重载外部版本"
	reload_button.pressed.connect(_reload_selected_map)
	buttons.add_child(reload_button)

	var readability_box = VBoxContainer.new()
	dock.add_child(readability_box)

	var legend_title = Label.new()
	legend_title.text = "类型图例"
	readability_box.add_child(legend_title)

	legend_label = RichTextLabel.new()
	legend_label.bbcode_enabled = true
	legend_label.fit_content = true
	legend_label.custom_minimum_size = Vector2(260, 72)
	readability_box.add_child(legend_label)

	var object_list_title = Label.new()
	object_list_title.text = "对象列表"
	readability_box.add_child(object_list_title)

	var object_list_scroll = ScrollContainer.new()
	object_list_scroll.custom_minimum_size = Vector2(260, 180)
	readability_box.add_child(object_list_scroll)

	object_list_container = VBoxContainer.new()
	object_list_scroll.add_child(object_list_container)

	var selection_box = VBoxContainer.new()
	dock.add_child(selection_box)

	var selection_title = Label.new()
	selection_title.text = "当前选择"
	selection_box.add_child(selection_title)

	selection_label = Label.new()
	selection_label.text = "未选择"
	selection_box.add_child(selection_label)

	var position_row = HBoxContainer.new()
	selection_box.add_child(position_row)

	position_x_spin = SpinBox.new()
	position_x_spin.min_value = -4096.0
	position_x_spin.max_value = 4096.0
	position_x_spin.step = 1.0
	position_x_spin.prefix = "x "
	position_row.add_child(position_x_spin)

	position_y_spin = SpinBox.new()
	position_y_spin.min_value = -4096.0
	position_y_spin.max_value = 4096.0
	position_y_spin.step = 1.0
	position_y_spin.prefix = "y "
	position_row.add_child(position_y_spin)

	var position_button = Button.new()
	position_button.text = "应用坐标"
	position_button.pressed.connect(_apply_selected_position)
	selection_box.add_child(position_button)

	var object_box = VBoxContainer.new()
	dock.add_child(object_box)

	var object_title = Label.new()
	object_title.text = "对象半径"
	object_box.add_child(object_title)

	object_id_input = LineEdit.new()
	object_id_input.placeholder_text = "object_id"
	object_box.add_child(object_id_input)

	object_name_input = LineEdit.new()
	object_name_input.placeholder_text = "对象名称"
	object_box.add_child(object_name_input)

	object_type_input = LineEdit.new()
	object_type_input.placeholder_text = "对象类型"
	object_box.add_child(object_type_input)

	var object_fields_button = Button.new()
	object_fields_button.text = "应用对象字段"
	object_fields_button.pressed.connect(_apply_object_fields)
	object_box.add_child(object_fields_button)

	radius_spin = SpinBox.new()
	radius_spin.min_value = 1.0
	radius_spin.max_value = 512.0
	radius_spin.step = 1.0
	radius_spin.value = 48.0
	object_box.add_child(radius_spin)

	var radius_button = Button.new()
	radius_button.text = "应用半径"
	radius_button.pressed.connect(_apply_object_radius)
	object_box.add_child(radius_button)

	var obstacle_box = VBoxContainer.new()
	dock.add_child(obstacle_box)

	var obstacle_title = Label.new()
	obstacle_title.text = "障碍尺寸"
	obstacle_box.add_child(obstacle_title)

	obstacle_id_input = LineEdit.new()
	obstacle_id_input.placeholder_text = "obstacle_id"
	obstacle_box.add_child(obstacle_id_input)

	obstacle_width_spin = SpinBox.new()
	obstacle_width_spin.min_value = 1.0
	obstacle_width_spin.max_value = 4096.0
	obstacle_width_spin.step = 1.0
	obstacle_width_spin.value = 64.0
	obstacle_box.add_child(obstacle_width_spin)

	obstacle_height_spin = SpinBox.new()
	obstacle_height_spin.min_value = 1.0
	obstacle_height_spin.max_value = 4096.0
	obstacle_height_spin.step = 1.0
	obstacle_height_spin.value = 64.0
	obstacle_box.add_child(obstacle_height_spin)

	var obstacle_button = Button.new()
	obstacle_button.text = "应用尺寸"
	obstacle_button.pressed.connect(_apply_obstacle_size)
	obstacle_box.add_child(obstacle_button)

	var create_box = VBoxContainer.new()
	dock.add_child(create_box)

	var create_title = Label.new()
	create_title.text = "新增元素"
	create_box.add_child(create_title)

	new_element_type_selector = OptionButton.new()
	for type_label in ["NPC", "出口", "拾取物", "战斗点", "出生点", "矩形障碍"]:
		new_element_type_selector.add_item(type_label)
	create_box.add_child(new_element_type_selector)

	new_element_id_input = LineEdit.new()
	new_element_id_input.placeholder_text = "id"
	create_box.add_child(new_element_id_input)

	new_element_name_input = LineEdit.new()
	new_element_name_input.placeholder_text = "名称"
	create_box.add_child(new_element_name_input)

	new_element_reference_input = LineEdit.new()
	new_element_reference_input.placeholder_text = "引用：dialogue_id / target_map_id / battle_id"
	create_box.add_child(new_element_reference_input)

	new_element_spawn_input = LineEdit.new()
	new_element_spawn_input.placeholder_text = "出口目标 spawn_id"
	create_box.add_child(new_element_spawn_input)

	var create_position_row = HBoxContainer.new()
	create_box.add_child(create_position_row)

	new_element_x_spin = SpinBox.new()
	new_element_x_spin.min_value = -4096.0
	new_element_x_spin.max_value = 4096.0
	new_element_x_spin.step = 1.0
	new_element_x_spin.value = 640.0
	new_element_x_spin.prefix = "x "
	create_position_row.add_child(new_element_x_spin)

	new_element_y_spin = SpinBox.new()
	new_element_y_spin.min_value = -4096.0
	new_element_y_spin.max_value = 4096.0
	new_element_y_spin.step = 1.0
	new_element_y_spin.value = 360.0
	new_element_y_spin.prefix = "y "
	create_position_row.add_child(new_element_y_spin)

	new_element_radius_spin = SpinBox.new()
	new_element_radius_spin.min_value = 1.0
	new_element_radius_spin.max_value = 512.0
	new_element_radius_spin.step = 1.0
	new_element_radius_spin.value = 48.0
	new_element_radius_spin.prefix = "半径 "
	create_box.add_child(new_element_radius_spin)

	var create_size_row = HBoxContainer.new()
	create_box.add_child(create_size_row)

	new_element_width_spin = SpinBox.new()
	new_element_width_spin.min_value = 1.0
	new_element_width_spin.max_value = 4096.0
	new_element_width_spin.step = 1.0
	new_element_width_spin.value = 80.0
	new_element_width_spin.prefix = "w "
	create_size_row.add_child(new_element_width_spin)

	new_element_height_spin = SpinBox.new()
	new_element_height_spin.min_value = 1.0
	new_element_height_spin.max_value = 4096.0
	new_element_height_spin.step = 1.0
	new_element_height_spin.value = 80.0
	new_element_height_spin.prefix = "h "
	create_size_row.add_child(new_element_height_spin)

	var create_button = Button.new()
	create_button.text = "创建模板"
	create_button.pressed.connect(_create_template_element)
	create_box.add_child(create_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = "等待地图场景。"
	dock.add_child(status_label)

	validation_label = RichTextLabel.new()
	validation_label.bbcode_enabled = true
	validation_label.fit_content = true
	validation_label.custom_minimum_size = Vector2(260, 120)
	dock.add_child(validation_label)

func _load_map_index() -> bool:
	var restore_map_id = selected_map_id
	if not content_document.load_from_path(MAP_INDEX_PATH):
		_update_status(content_document.last_error)
		return false
	maps_by_id = content_document.get_maps_by_id()
	scene_path_to_map_id = content_document.get_scene_path_to_map_id()
	_rebuild_map_selector(restore_map_id)
	if not content_document.is_dirty():
		manual_content_refresh_confirm_pending = false
	return true

func _rebuild_map_selector(preferred_map_id: String) -> void:
	map_selector.clear()
	for map_id in maps_by_id.keys():
		map_selector.add_item(str(map_id))
	if not preferred_map_id.is_empty():
		_select_map_selector_item(preferred_map_id)

func _select_map_selector_item(map_id: String) -> void:
	for index in range(map_selector.get_item_count()):
		if map_selector.get_item_text(index) == map_id:
			map_selector.select(index)
			return

func _refresh_from_current_scene() -> void:
	var scene_root = _edited_scene_root()
	if scene_root == null:
		_update_status("当前没有打开地图场景。")
		return
	var scene_file_path = scene_root.scene_file_path
	active_scene_path = scene_file_path
	var map_id = str(scene_path_to_map_id.get(scene_file_path, ""))
	if map_id.is_empty():
		_update_status("当前场景未匹配到 data/maps.json 中的地图。")
		return
	_select_map_id(map_id)

func _refresh_if_scene_changed() -> void:
	var scene_root = _edited_scene_root()
	if scene_root == null:
		return
	var scene_file_path = scene_root.scene_file_path
	if scene_file_path == active_scene_path:
		return
	_refresh_from_current_scene()

func _on_scene_changed(_scene_root: Node) -> void:
	call_deferred("_refresh_from_current_scene")

func _select_map_id(map_id: String) -> void:
	if selected_map_id != map_id:
		_clear_selected_layout_element()
	selected_map_id = map_id
	_select_map_selector_item(map_id)
	_reload_selected_map()

func _manual_refresh_selected_map() -> void:
	if content_document.is_dirty() and not manual_content_refresh_confirm_pending:
		manual_content_refresh_confirm_pending = true
		_update_status("data/maps.json 有未保存内容修改。再次点击刷新将丢弃这些内容修改。")
		return
	manual_content_refresh_confirm_pending = false
	var current_map_id = selected_map_id
	if not _load_map_index():
		return
	if not current_map_id.is_empty() and maps_by_id.has(current_map_id):
		_select_map_id(current_map_id)
	else:
		_refresh_from_current_scene()

func _reload_selected_map() -> void:
	if selected_map_id.is_empty():
		return
	if not document.load_map(selected_map_id):
		_update_status("无法加载布局：%s" % selected_map_id)
		return
	_reset_save_conflict_confirmations()
	var previous_selected_object_id = selected_object_id
	_render_selected_map()
	if previous_selected_object_id.is_empty() or selected_object_id == previous_selected_object_id:
		_update_status("已刷新：%s" % selected_map_id)

func _render_selected_map() -> void:
	var scene_root = _edited_scene_root()
	if scene_root == null:
		return
	var map_data = maps_by_id.get(selected_map_id, {})
	renderer.render(scene_root, map_data, document.get_layout())
	_update_validation(map_data, document.get_layout())
	_update_readability_panel(map_data)
	_reapply_selected_object()
	_reapply_selected_layout_element()

func _check_map_index_refresh() -> void:
	if not content_document.has_external_change():
		return
	if content_document.is_dirty():
		_update_status("data/maps.json 有外部修改，且编辑器内有未保存内容修改。请选择保存或手动刷新。")
		return
	var previous_map_id = selected_map_id
	var previous_object_id = selected_object_id
	if not _load_map_index():
		return
	_refresh_after_map_index_change(previous_map_id, previous_object_id)

func _refresh_after_map_index_change(previous_map_id: String, previous_object_id: String) -> void:
	var scene_root = _edited_scene_root()
	var scene_map_id := ""
	if scene_root != null:
		active_scene_path = scene_root.scene_file_path
		scene_map_id = str(scene_path_to_map_id.get(scene_root.scene_file_path, ""))
	if not scene_map_id.is_empty():
		if selected_map_id != scene_map_id:
			_clear_selected_layout_element()
		else:
			selected_object_id = previous_object_id
		selected_map_id = scene_map_id
		_select_map_selector_item(scene_map_id)
		if document.map_id != scene_map_id:
			_reload_selected_map()
		else:
			_render_selected_map()
			if selected_object_id == previous_object_id:
				_update_status("地图内容已刷新：%s" % selected_map_id)
		return
	if not previous_map_id.is_empty() and maps_by_id.has(previous_map_id):
		selected_map_id = previous_map_id
		selected_object_id = previous_object_id
		_select_map_selector_item(selected_map_id)
		if document.map_id != selected_map_id:
			_reload_selected_map()
		else:
			_render_selected_map()
			if selected_object_id == previous_object_id:
				_update_status("地图内容已刷新：%s" % selected_map_id)
		return
	selected_map_id = ""
	_clear_current_preview()
	_update_status("当前地图已从 data/maps.json 移除：%s" % previous_map_id)

func _clear_current_preview() -> void:
	var scene_root = _edited_scene_root()
	if scene_root != null:
		renderer.clear(scene_root)
	_update_readability_panel({})
	if validation_label != null:
		validation_label.text = ""
	_clear_selected_layout_element()

func _check_external_refresh() -> void:
	if not document.has_external_change():
		return
	if document.is_dirty():
		_update_status("布局文件有外部修改，且编辑器内有未保存修改。请选择保存或重载。")
		return
	_reload_selected_map()

func _save_document() -> void:
	if selected_map_id.is_empty():
		return
	var layout_conflicted = document.is_dirty() and document.has_external_change()
	var content_conflicted = content_document.is_dirty() and content_document.has_external_change()
	if layout_conflicted:
		if not layout_save_conflict_confirm_pending:
			layout_save_conflict_confirm_pending = true
			_update_status("检测到布局外部修改。再次点击保存将覆盖外部版本，或点击重载外部版本。")
			return
	else:
		layout_save_conflict_confirm_pending = false
	if content_conflicted:
		if not content_save_conflict_confirm_pending:
			content_save_conflict_confirm_pending = true
			_update_status("检测到 data/maps.json 外部修改。再次点击保存将覆盖外部版本，或点击刷新。")
			return
	else:
		content_save_conflict_confirm_pending = false

	var content_ok = true
	if content_document.is_dirty():
		content_ok = content_document.save()
		if content_ok:
			content_save_conflict_confirm_pending = false
	var layout_ok = true
	if document.is_dirty():
		layout_ok = document.save()
		if layout_ok:
			layout_save_conflict_confirm_pending = false

	if content_ok and layout_ok:
		layout_save_conflict_confirm_pending = false
		content_save_conflict_confirm_pending = false
		manual_content_refresh_confirm_pending = false
		_load_map_index()
		_render_selected_map()
		_update_status("已保存地图编辑：%s" % selected_map_id)
	elif not content_ok:
		_update_status("保存失败：data/maps.json")
	else:
		_update_status("保存失败：%s" % document.path)

func _on_map_selected(index: int) -> void:
	_select_map_id(map_selector.get_item_text(index))

func _on_preview_handle_changed(kind: String, layout_id: String, payload: Dictionary) -> void:
	_reset_save_conflict_confirmations()
	var position_data = payload.get("position", {})
	var position = Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
	_select_layout_element(kind, layout_id)
	_fill_position_fields(position)
	match kind:
		"object":
			selected_object_id = layout_id
			object_id_input.text = layout_id
			document.update_object_position(layout_id, position)
		"spawn":
			document.update_spawn_position(layout_id, position)
		"obstacle":
			obstacle_id_input.text = layout_id
			var layout = document.get_layout()
			for obstacle in layout.get("obstacles", []):
				if typeof(obstacle) == TYPE_DICTIONARY and str(obstacle.get("id", "")) == layout_id:
					var rect = obstacle.get("rect", {})
					document.update_obstacle_rect(layout_id, Rect2(position, Vector2(float(rect.get("w", 0.0)), float(rect.get("h", 0.0)))))
					break
	_update_status("有未保存修改：%s" % layout_id)

func _apply_object_radius() -> void:
	_reset_save_conflict_confirmations()
	var object_id = object_id_input.text.strip_edges()
	if object_id.is_empty():
		_update_status("请输入对象编号。")
		return
	document.update_object_radius(object_id, float(radius_spin.value))
	_render_selected_map()
	_update_status("有未保存半径修改：%s" % object_id)

func _apply_obstacle_size() -> void:
	_reset_save_conflict_confirmations()
	var obstacle_id = obstacle_id_input.text.strip_edges()
	if obstacle_id.is_empty():
		_update_status("请输入障碍编号。")
		return
	var current_rect = _find_obstacle_rect(obstacle_id)
	if current_rect.size == Vector2.ZERO:
		_update_status("找不到障碍：%s" % obstacle_id)
		return
	current_rect.size = Vector2(float(obstacle_width_spin.value), float(obstacle_height_spin.value))
	document.update_obstacle_rect(obstacle_id, current_rect)
	_render_selected_map()
	_update_status("有未保存障碍尺寸修改：%s" % obstacle_id)

func _reset_save_conflict_confirmations() -> void:
	layout_save_conflict_confirm_pending = false
	content_save_conflict_confirm_pending = false

func _apply_selected_position() -> void:
	_reset_save_conflict_confirmations()
	if selected_layout_kind.is_empty() or selected_layout_id.is_empty():
		_update_status("请先选择地图元素。")
		return
	var position = Vector2(float(position_x_spin.value), float(position_y_spin.value))
	match selected_layout_kind:
		"object":
			document.update_object_position(selected_layout_id, position)
		"spawn":
			if not document.get_layout().get("spawn_points", {}).has(selected_layout_id):
				var missing_id = selected_layout_id
				_clear_selected_layout_element()
				_update_status("选中出生点已不存在：%s" % missing_id)
				return
			document.update_spawn_position(selected_layout_id, position)
		"obstacle":
			var rect = _find_obstacle_rect(selected_layout_id)
			if rect.size == Vector2.ZERO:
				var missing_id = selected_layout_id
				_clear_selected_layout_element()
				_update_status("选中障碍已不存在：%s" % missing_id)
				return
			document.update_obstacle_rect(selected_layout_id, Rect2(position, rect.size))
	_render_selected_map()
	_update_status("有未保存坐标修改：%s" % selected_layout_id)

func _apply_object_fields() -> void:
	_reset_save_conflict_confirmations()
	manual_content_refresh_confirm_pending = false
	var object_id = object_id_input.text.strip_edges()
	if object_id.is_empty():
		_update_status("请输入对象编号。")
		return
	if selected_layout_kind != "object" or object_id != selected_object_id:
		_update_status("请先从对象列表选择要编辑的对象。")
		return
	var result = content_document.update_object_fields(selected_map_id, object_id, {
		"name": object_name_input.text.strip_edges(),
		"type": object_type_input.text.strip_edges(),
	})
	if not result.ok:
		_update_status(result.error)
		return
	maps_by_id = content_document.get_maps_by_id()
	scene_path_to_map_id = content_document.get_scene_path_to_map_id()
	_render_selected_map()
	_update_status("有未保存对象字段修改：%s" % object_id)

func _create_template_element() -> void:
	_reset_save_conflict_confirmations()
	manual_content_refresh_confirm_pending = false
	if selected_map_id.is_empty():
		_update_status("请先打开地图场景。")
		return
	var template_label = new_element_type_selector.get_item_text(new_element_type_selector.selected)
	var element_id = new_element_id_input.text.strip_edges()
	var position = Vector2(float(new_element_x_spin.value), float(new_element_y_spin.value))
	match template_label:
		"NPC", "出口", "拾取物", "战斗点":
			_create_object_template(template_label, element_id, position)
		"出生点":
			_create_spawn_template(element_id, position)
		"矩形障碍":
			_create_obstacle_template(element_id, position)

func _create_object_template(template_label: String, object_id: String, position: Vector2) -> void:
	if object_id.is_empty():
		_update_status("请输入对象编号。")
		return
	if not maps_by_id.has(selected_map_id):
		_update_status("地图编号不存在：%s" % selected_map_id)
		return
	if not _find_map_object(object_id).is_empty():
		_update_status("对象编号已存在：%s" % object_id)
		return
	var layout_objects = document.get_layout().get("objects", {})
	if typeof(layout_objects) != TYPE_DICTIONARY:
		_update_status("对象布局必须是字典：%s" % object_id)
		return
	if layout_objects.has(object_id):
		_update_status("对象布局已存在：%s" % object_id)
		return
	var radius = float(new_element_radius_spin.value)
	if radius <= 0.0:
		_update_status("对象半径必须为正数：%s" % object_id)
		return
	var object_record = _build_object_template(template_label, object_id)
	var layout_was_dirty = document.is_dirty()
	var layout_result = document.add_object_layout(object_id, position, radius)
	if not layout_result.ok:
		_update_status(layout_result.error)
		return
	var content_result = content_document.add_object_to_map(selected_map_id, object_record)
	if not content_result.ok:
		layout_objects = document.get_layout().get("objects", {})
		if typeof(layout_objects) == TYPE_DICTIONARY and layout_objects.has(object_id):
			layout_objects.erase(object_id)
		document.dirty = layout_was_dirty
		_update_status(content_result.error)
		return
	maps_by_id = content_document.get_maps_by_id()
	scene_path_to_map_id = content_document.get_scene_path_to_map_id()
	selected_object_id = object_id
	_render_selected_map()
	_select_preview_object(object_id)
	_update_status("已创建模板，尚未保存：%s" % object_id)

func _build_object_template(template_label: String, object_id: String) -> Dictionary:
	var object_name = new_element_name_input.text.strip_edges()
	if object_name.is_empty():
		object_name = object_id
	var reference = new_element_reference_input.text.strip_edges()
	match template_label:
		"NPC":
			return {
				"id": object_id,
				"type": "npc",
				"name": object_name,
				"dialogue_id": reference if not reference.is_empty() else "dialogue_%s" % object_id,
			}
		"出口":
			return {
				"id": object_id,
				"type": "exit",
				"name": object_name,
				"target_map_id": reference,
				"target_spawn_id": new_element_spawn_input.text.strip_edges(),
			}
		"拾取物":
			return {
				"id": object_id,
				"type": "pickup",
				"name": object_name,
				"effects": [],
			}
		"战斗点":
			return {
				"id": object_id,
				"type": "battle_trigger",
				"name": object_name,
				"battle_id": reference if not reference.is_empty() else "battle_%s" % object_id,
			}
	return {"id": object_id, "type": "notice", "name": object_name}

func _create_spawn_template(spawn_id: String, position: Vector2) -> void:
	var result = document.add_spawn_point(spawn_id, position)
	if not result.ok:
		_update_status(result.error)
		return
	_render_selected_map()
	_select_layout_element("spawn", spawn_id)
	_update_status("已创建出生点，尚未保存：%s" % spawn_id)

func _create_obstacle_template(obstacle_id: String, position: Vector2) -> void:
	var rect = Rect2(position, Vector2(float(new_element_width_spin.value), float(new_element_height_spin.value)))
	var result = document.add_rect_obstacle(obstacle_id, rect)
	if not result.ok:
		_update_status(result.error)
		return
	_render_selected_map()
	_select_layout_element("obstacle", obstacle_id)
	_update_status("已创建矩形障碍，尚未保存：%s" % obstacle_id)

func _find_obstacle_rect(obstacle_id: String) -> Rect2:
	for obstacle in document.get_layout().get("obstacles", []):
		if typeof(obstacle) != TYPE_DICTIONARY or str(obstacle.get("id", "")) != obstacle_id:
			continue
		var rect = obstacle.get("rect", {})
		return Rect2(float(rect.get("x", 0.0)), float(rect.get("y", 0.0)), float(rect.get("w", 0.0)), float(rect.get("h", 0.0)))
	return Rect2()

func _select_preview_object(object_id: String) -> void:
	if object_id.is_empty():
		return
	var scene_root = _edited_scene_root()
	if scene_root == null:
		_update_status("当前没有打开地图场景。")
		return
	var handle = _find_object_handle(object_id)
	if handle == null:
		_clear_selected_object_highlight()
		selected_object_id = ""
		_refresh_object_list_selection_state()
		_update_status("找不到预览对象：%s" % object_id)
		return
	selected_object_id = object_id
	selected_layout_kind = "object"
	selected_layout_id = object_id
	_apply_object_selection(object_id, handle)
	_refresh_object_list_selection_state()
	if _select_editor_node(handle):
		_update_status("已选中对象：%s" % object_id)
	else:
		_update_status("已高亮对象：%s（编辑器选择不可用）" % object_id)

func _reapply_selected_object() -> void:
	if selected_object_id.is_empty():
		return
	var object_id = selected_object_id
	var handle = _find_object_handle(object_id)
	if handle == null:
		_clear_selected_layout_element()
		_update_status("选中对象已不存在：%s" % object_id)
		return
	_apply_object_selection(object_id, handle)
	_select_editor_node(handle)

func _reapply_selected_layout_element() -> void:
	if selected_layout_kind.is_empty() or selected_layout_kind == "object":
		return
	match selected_layout_kind:
		"spawn":
			if not document.get_layout().get("spawn_points", {}).has(selected_layout_id):
				var missing_id = selected_layout_id
				_clear_selected_layout_element()
				_update_status("选中出生点已不存在：%s" % missing_id)
		"obstacle":
			if _find_obstacle_rect(selected_layout_id).size == Vector2.ZERO:
				var missing_id = selected_layout_id
				_clear_selected_layout_element()
				_update_status("选中障碍已不存在：%s" % missing_id)

func _apply_object_selection(object_id: String, handle: Node) -> void:
	_clear_selected_object_highlight()
	_set_handle_selected(handle, true)
	_select_layout_element("object", object_id)

func _clear_selected_object_highlight() -> void:
	var scene_root = _edited_scene_root()
	if scene_root == null:
		return
	var objects_root = scene_root.get_node_or_null("GeneratedMapPreview/Objects")
	if objects_root == null:
		return
	for child in objects_root.get_children():
		_set_handle_selected(child, false)

func _clear_selected_layout_element() -> void:
	_clear_selected_object_highlight()
	selected_object_id = ""
	selected_layout_kind = ""
	selected_layout_id = ""
	if selection_label != null:
		selection_label.text = "未选择"
	if position_x_spin != null:
		position_x_spin.value = 0.0
	if position_y_spin != null:
		position_y_spin.value = 0.0
	if object_id_input != null:
		object_id_input.text = ""
	if object_name_input != null:
		object_name_input.text = ""
	if object_type_input != null:
		object_type_input.text = ""
	if radius_spin != null:
		radius_spin.value = 48.0
	if obstacle_id_input != null:
		obstacle_id_input.text = ""
	if obstacle_width_spin != null:
		obstacle_width_spin.value = 64.0
	if obstacle_height_spin != null:
		obstacle_height_spin.value = 64.0

func _set_handle_selected(handle: Node, is_selected: bool) -> void:
	if handle != null and handle.has_method("set_selected"):
		handle.call("set_selected", is_selected)

func _find_object_handle(object_id: String) -> Node:
	var scene_root = _edited_scene_root()
	if scene_root == null:
		return null
	return scene_root.get_node_or_null("GeneratedMapPreview/Objects/%s" % object_id)

func _fill_object_edit_fields(object_id: String) -> void:
	if object_id_input != null:
		object_id_input.text = object_id
	var object_record = _find_map_object(object_id)
	if object_name_input != null:
		object_name_input.text = str(object_record.get("name", ""))
	if object_type_input != null:
		object_type_input.text = str(object_record.get("type", ""))
	if radius_spin != null:
		radius_spin.value = _current_object_radius(object_id)
	if not object_record.is_empty():
		var position_data = document.get_layout().get("objects", {}).get(object_id, {}).get("position", object_record.get("position", {}))
		_fill_position_fields(Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0))))

func _select_layout_element(kind: String, layout_id: String) -> void:
	selected_layout_kind = kind
	selected_layout_id = layout_id
	if kind != "object" and not selected_object_id.is_empty():
		_clear_selected_object_highlight()
		selected_object_id = ""
		_refresh_object_list_selection_state()
	if selection_label != null:
		selection_label.text = "%s：%s" % [kind, layout_id]
	match kind:
		"object":
			_fill_object_edit_fields(layout_id)
		"spawn":
			_fill_position_fields(_current_spawn_position(layout_id))
		"obstacle":
			_fill_obstacle_fields(layout_id)

func _fill_position_fields(position: Vector2) -> void:
	if position_x_spin != null:
		position_x_spin.value = position.x
	if position_y_spin != null:
		position_y_spin.value = position.y

func _current_spawn_position(spawn_id: String) -> Vector2:
	var spawn_points = document.get_layout().get("spawn_points", {})
	var position_data = spawn_points.get(spawn_id, {})
	return Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))

func _fill_obstacle_fields(obstacle_id: String) -> void:
	if obstacle_id_input != null:
		obstacle_id_input.text = obstacle_id
	var rect = _find_obstacle_rect(obstacle_id)
	_fill_position_fields(rect.position)
	if obstacle_width_spin != null:
		obstacle_width_spin.value = rect.size.x
	if obstacle_height_spin != null:
		obstacle_height_spin.value = rect.size.y

func _current_object_radius(object_id: String) -> float:
	var layout_objects = document.get_layout().get("objects", {})
	if typeof(layout_objects) == TYPE_DICTIONARY and layout_objects.has(object_id):
		var object_layout = layout_objects.get(object_id, {})
		if typeof(object_layout) == TYPE_DICTIONARY:
			return float(object_layout.get("radius", 48.0))
	var object_record = _find_map_object(object_id)
	if not object_record.is_empty():
		return float(object_record.get("radius", 48.0))
	return float(radius_spin.value) if radius_spin != null else 48.0

func _find_map_object(object_id: String) -> Dictionary:
	var map_data = maps_by_id.get(selected_map_id, {})
	for object_record in map_data.get("objects", []):
		if typeof(object_record) == TYPE_DICTIONARY and str(object_record.get("id", "")) == object_id:
			return object_record
	return {}

func _select_editor_node(node: Node) -> bool:
	var editor_interface = get_editor_interface()
	if editor_interface == null:
		return false
	var selection = editor_interface.get_selection()
	if selection == null:
		return false
	selection.clear()
	selection.add_node(node)
	return true

func _update_readability_panel(map_data: Dictionary) -> void:
	if legend_label == null or object_list_container == null:
		return
	var summary = MapPreviewTypesScript.build_object_summary(map_data.get("objects", []))
	legend_label.text = _build_legend_text(summary.get("counts", {}))
	_rebuild_object_list(summary.get("rows", []))

func _build_legend_text(counts: Dictionary) -> String:
	var lines := PackedStringArray()
	for type_key in MapPreviewTypesScript.TYPE_ORDER:
		var count = int(counts.get(type_key, 0))
		if count <= 0:
			continue
		lines.append("[color=#%s]■[/color] %s %d" % [
			MapPreviewTypesScript.color_html(type_key),
			MapPreviewTypesScript.type_label(type_key),
			count,
		])
	if lines.is_empty():
		lines.append("无对象")
	return "\n".join(lines)

func _rebuild_object_list(rows: Array) -> void:
	for child in object_list_container.get_children():
		object_list_container.remove_child(child)
		child.queue_free()
	if rows.is_empty():
		var empty_label = Label.new()
		empty_label.text = "无对象"
		object_list_container.add_child(empty_label)
		return
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		object_list_container.add_child(_build_object_list_button(row))

func _build_object_list_button(row: Dictionary) -> Button:
	var object_id = str(row.get("id", ""))
	var button = Button.new()
	button.text = MapPreviewTypesScript.object_list_button_text(row, selected_object_id)
	button.tooltip_text = object_id
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(260, 28)
	button.pressed.connect(_on_object_list_item_pressed.bind(object_id))
	return button

func _on_object_list_item_pressed(object_id: String) -> void:
	_select_preview_object(object_id)

func _refresh_object_list_selection_state() -> void:
	if selected_map_id.is_empty():
		return
	_update_readability_panel(maps_by_id.get(selected_map_id, {}))

func _update_validation(map_data: Dictionary, layout: Dictionary) -> void:
	var errors = layout_loader.validate_layout(layout, map_data)
	if errors.is_empty():
		validation_label.text = "[color=green]校验通过[/color]"
	else:
		validation_label.text = "[color=red]%s[/color]" % "\n".join(PackedStringArray(errors))

func _update_status(message: String) -> void:
	if status_label != null:
		status_label.text = message

func _edited_scene_root() -> Node:
	return get_editor_interface().get_edited_scene_root()
