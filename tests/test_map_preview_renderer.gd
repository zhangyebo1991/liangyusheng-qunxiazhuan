extends RefCounted

const MapPreviewRendererScript = preload("res://addons/map_preview/map_preview_renderer.gd")

func run(assertions) -> void:
	_test_renderer_builds_preview_tree(assertions)
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
