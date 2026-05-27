extends RefCounted

const MapPreviewRendererScript = preload("res://addons/map_preview/map_preview_renderer.gd")

func run(assertions) -> void:
	_test_renderer_builds_preview_tree(assertions)
	_test_renderer_assigns_readable_labels(assertions)
	_test_renderer_clears_only_generated_preview(assertions)

func _test_renderer_builds_preview_tree(assertions) -> void:
	var root = Node2D.new()
	var renderer = MapPreviewRendererScript.new()
	var map_data = {
		"objects": [
			{"id": "npc_demo", "type": "npc", "name": "演示 NPC"},
			{"id": "exit_demo", "type": "exit", "name": "演示出口"}
		]
	}
	var layout = _sample_layout()
	renderer.render(root, map_data, layout)
	var preview = root.get_node_or_null("GeneratedMapPreview")
	assertions.assert_true(preview != null, "渲染器应创建 GeneratedMapPreview")
	if preview != null:
		assertions.assert_true(preview.get_meta("map_preview_generated", false), "预览根节点应带生成标记")
		assertions.assert_true(preview.get_node_or_null("Objects/npc_demo") != null, "渲染器应创建对象 handle")
		assertions.assert_true(preview.get_node_or_null("Spawns/start") != null, "渲染器应创建出生点 handle")
		assertions.assert_true(preview.get_node_or_null("Obstacles/wall") != null, "渲染器应创建障碍 handle")
	root.free()

func _test_renderer_assigns_readable_labels(assertions) -> void:
	var root = Node2D.new()
	var renderer = MapPreviewRendererScript.new()
	var map_data = {
		"objects": [
			{"id": "npc_demo", "type": "npc", "name": "演示 NPC"},
			{"id": "exit_demo", "type": "exit", "name": "演示出口"},
			{"id": "unknown_demo", "type": "mystery"}
		]
	}
	var layout = _sample_layout()
	layout["objects"]["unknown_demo"] = {"position": {"x": 110, "y": 120}, "radius": 32}
	renderer.render(root, map_data, layout)
	var preview = root.get_node_or_null("GeneratedMapPreview")
	if preview != null:
		var npc_handle = preview.get_node_or_null("Objects/npc_demo")
		var exit_handle = preview.get_node_or_null("Objects/exit_demo")
		var unknown_handle = preview.get_node_or_null("Objects/unknown_demo")
		var spawn_handle = preview.get_node_or_null("Spawns/start")
		var obstacle_handle = preview.get_node_or_null("Obstacles/wall")
		assertions.assert_eq(npc_handle.display_name, "演示 NPC", "NPC handle 应保存显示名称")
		assertions.assert_eq(npc_handle.type_label, "NPC", "NPC handle 应保存中文类型")
		assertions.assert_eq(npc_handle.get_label_text(), "演示 NPC / NPC", "NPC handle 标签应可读")
		assertions.assert_eq(exit_handle.get_label_text(), "演示出口 / 出口", "出口 handle 标签应可读")
		assertions.assert_eq(unknown_handle.get_label_text(), "unknown_demo / 对象", "未知类型 handle 应回退对象标签")
		assertions.assert_eq(spawn_handle.get_label_text(), "出生点 / start", "出生点 handle 标签应可读")
		assertions.assert_eq(obstacle_handle.get_label_text(), "障碍 / wall", "障碍 handle 标签应可读")
	root.free()

func _test_renderer_clears_only_generated_preview(assertions) -> void:
	var root = Node2D.new()
	var user_node = Node2D.new()
	user_node.name = "UserNode"
	root.add_child(user_node)
	var renderer = MapPreviewRendererScript.new()
	renderer.render(root, {"objects": []}, _sample_layout())
	renderer.clear(root)
	assertions.assert_true(root.get_node_or_null("UserNode") != null, "清理预览时不应删除用户节点")
	assertions.assert_true(root.get_node_or_null("GeneratedMapPreview") == null, "清理预览时应删除生成预览节点")
	root.free()

func _sample_layout() -> Dictionary:
	return {
		"map_id": "demo",
		"size": {"x": 320, "y": 180},
		"background": {"mode": "color", "color": "#123456"},
		"spawn_points": {"start": {"x": 10, "y": 20}},
		"obstacles": [{"id": "wall", "shape": "rect", "rect": {"x": 30, "y": 40, "w": 50, "h": 60}}],
		"objects": {
			"npc_demo": {"position": {"x": 70, "y": 80}, "radius": 48},
			"exit_demo": {"position": {"x": 90, "y": 100}, "radius": 72}
		},
		"decorations": []
	}
