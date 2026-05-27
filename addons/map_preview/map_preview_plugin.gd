@tool
extends EditorPlugin

const MapLayoutDocumentScript = preload("res://addons/map_preview/map_layout_document.gd")
const MapPreviewRendererScript = preload("res://addons/map_preview/map_preview_renderer.gd")
const MapLayoutLoaderScript = preload("res://scripts/systems/map_layout_loader.gd")

var dock: VBoxContainer
var map_selector: OptionButton
var status_label: Label
var validation_label: RichTextLabel
var refresh_button: Button
var save_button: Button
var reload_button: Button
var auto_refresh_check: CheckBox
var object_id_input: LineEdit
var radius_spin: SpinBox
var obstacle_id_input: LineEdit
var obstacle_width_spin: SpinBox
var obstacle_height_spin: SpinBox
var selected_map_id := ""
var document = MapLayoutDocumentScript.new()
var renderer = MapPreviewRendererScript.new()
var layout_loader = MapLayoutLoaderScript.new()
var maps_by_id: Dictionary = {}
var scene_path_to_map_id: Dictionary = {}
var poll_elapsed := 0.0
var save_conflict_confirm_pending := false
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
	if auto_refresh_check != null and auto_refresh_check.button_pressed and not selected_map_id.is_empty():
		_check_external_refresh()

func _save_external_data() -> void:
	if document.is_dirty() and not document.has_external_change():
		document.save()
		_update_status("已随项目保存布局。")

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
	refresh_button.pressed.connect(_reload_selected_map)
	buttons.add_child(refresh_button)

	save_button = Button.new()
	save_button.text = "保存"
	save_button.pressed.connect(_save_document)
	buttons.add_child(save_button)

	reload_button = Button.new()
	reload_button.text = "重载外部版本"
	reload_button.pressed.connect(_reload_selected_map)
	buttons.add_child(reload_button)

	var object_box = VBoxContainer.new()
	dock.add_child(object_box)

	var object_title = Label.new()
	object_title.text = "对象半径"
	object_box.add_child(object_title)

	object_id_input = LineEdit.new()
	object_id_input.placeholder_text = "object_id"
	object_box.add_child(object_id_input)

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

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = "等待地图场景。"
	dock.add_child(status_label)

	validation_label = RichTextLabel.new()
	validation_label.bbcode_enabled = true
	validation_label.fit_content = true
	validation_label.custom_minimum_size = Vector2(260, 120)
	dock.add_child(validation_label)

func _load_map_index() -> void:
	maps_by_id.clear()
	scene_path_to_map_id.clear()
	map_selector.clear()
	var file = FileAccess.open("res://data/maps.json", FileAccess.READ)
	if file == null:
		_update_status("无法读取 data/maps.json。")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		_update_status("data/maps.json 必须是数组。")
		return
	for map_data in parsed:
		if typeof(map_data) != TYPE_DICTIONARY:
			continue
		var map_id = str(map_data.get("id", ""))
		if map_id.is_empty():
			continue
		maps_by_id[map_id] = map_data
		scene_path_to_map_id[str(map_data.get("scene_path", ""))] = map_id
		map_selector.add_item(map_id)

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
	selected_map_id = map_id
	for index in range(map_selector.get_item_count()):
		if map_selector.get_item_text(index) == map_id:
			map_selector.select(index)
			break
	_reload_selected_map()

func _reload_selected_map() -> void:
	if selected_map_id.is_empty():
		return
	if not document.load_map(selected_map_id):
		_update_status("无法加载布局：%s" % selected_map_id)
		return
	save_conflict_confirm_pending = false
	_render_selected_map()
	_update_status("已刷新：%s" % selected_map_id)

func _render_selected_map() -> void:
	var scene_root = _edited_scene_root()
	if scene_root == null:
		return
	var map_data = maps_by_id.get(selected_map_id, {})
	renderer.render(scene_root, map_data, document.get_layout())
	_update_validation(map_data, document.get_layout())

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
	if document.has_external_change() and document.is_dirty():
		if not save_conflict_confirm_pending:
			save_conflict_confirm_pending = true
			_update_status("检测到外部修改。再次点击保存将覆盖外部版本，或点击重载外部版本。")
			return
	if document.save():
		save_conflict_confirm_pending = false
		_update_status("已保存布局：%s" % selected_map_id)
	else:
		_update_status("保存失败：%s" % selected_map_id)

func _on_map_selected(index: int) -> void:
	_select_map_id(map_selector.get_item_text(index))

func _on_preview_handle_changed(kind: String, layout_id: String, payload: Dictionary) -> void:
	save_conflict_confirm_pending = false
	var position_data = payload.get("position", {})
	var position = Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
	match kind:
		"object":
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
	save_conflict_confirm_pending = false
	var object_id = object_id_input.text.strip_edges()
	if object_id.is_empty():
		_update_status("请输入对象编号。")
		return
	document.update_object_radius(object_id, float(radius_spin.value))
	_render_selected_map()
	_update_status("有未保存半径修改：%s" % object_id)

func _apply_obstacle_size() -> void:
	save_conflict_confirm_pending = false
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

func _find_obstacle_rect(obstacle_id: String) -> Rect2:
	for obstacle in document.get_layout().get("obstacles", []):
		if typeof(obstacle) != TYPE_DICTIONARY or str(obstacle.get("id", "")) != obstacle_id:
			continue
		var rect = obstacle.get("rect", {})
		return Rect2(float(rect.get("x", 0.0)), float(rect.get("y", 0.0)), float(rect.get("w", 0.0)), float(rect.get("h", 0.0)))
	return Rect2()

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
