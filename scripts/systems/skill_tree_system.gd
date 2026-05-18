extends RefCounted

var _trees: Dictionary = {}
var _unlocked_nodes: Dictionary = {}

func _init():
	_load_trees()

func _load_trees():
	var dir = DirAccess.open("res://data/skill_trees")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var file = FileAccess.open("res://data/skill_trees/" + file_name, FileAccess.READ)
				if file:
					var json = JSON.new()
					var error = json.parse(file.get_as_text())
					if error == OK and json.data:
						var data = json.data
						if data.has("skill_id"):
							_trees[data.skill_id] = data
						else:
							push_error("技能树文件缺少 skill_id: " + file_name)
					else:
						push_error("JSON 解析失败: " + file_name)
				else:
					push_error("无法打开文件: " + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("无法打开技能树目录: res://data/skill_trees")

func unlock_node(skill_id: String, node_id: String, available_points: int) -> Dictionary:
	if not _trees.has(skill_id):
		return {"success": false, "message": "技能树不存在"}

	var tree = _trees[skill_id]
	var node = _find_node(tree, node_id)
	if node.is_empty():
		return {"success": false, "message": "节点不存在"}

	if _is_node_unlocked(skill_id, node_id):
		return {"success": false, "message": "节点已解锁"}

	var cost = int(node.get("cost", 1))
	if available_points < cost:
		return {"success": false, "message": "熟练度点数不足"}

	var requires = node.get("requires", [])
	for req in requires:
		if not _is_node_unlocked(skill_id, req):
			return {"success": false, "message": "未满足前置条件"}

	if not _unlocked_nodes.has(skill_id):
		_unlocked_nodes[skill_id] = []
	_unlocked_nodes[skill_id].append(node_id)

	return {"success": true, "cost": cost}

func _find_node(tree: Dictionary, node_id: String) -> Dictionary:
	for branch in tree.get("branches", []):
		for node in branch.get("nodes", []):
			if node.get("id") == node_id:
				return node
	return {}

func _is_node_unlocked(skill_id: String, node_id: String) -> bool:
	return _unlocked_nodes.has(skill_id) and node_id in _unlocked_nodes[skill_id]

func check_triggers(_scene: String, _context: Dictionary) -> Dictionary:
	return {}
