extends RefCounted

var _insights: Array = []
var _triggered: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init():
	_load_insights()

func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value

func _load_insights():
	var dir = DirAccess.open("res://data/martial_insights")
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var path = "res://data/martial_insights/" + file_name
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var json = JSON.new()
				var err = json.parse(file.get_as_text())
				if err == OK and json.data is Dictionary:
					_insights.append_array(json.data.get("insights", []))
		file_name = dir.get_next()
	dir.list_dir_end()

func check_triggers(scene: String, context: Dictionary) -> Array:
	var results: Array = []
	for insight in _insights:
		var trigger_scene = insight.get("trigger_scene", "any")
		if trigger_scene != "any" and trigger_scene != scene:
			continue

		if _triggered.has(insight.get("id", "")):
			continue

		if _check_conditions(insight.get("conditions", []), context):
			var id = insight.get("id", "")
			_triggered[id] = true
			var result_data = insight.get("result", {})
			results.append({
				"triggered": true,
				"id": id,
				"unlock": result_data.get("unlock", ""),
				"message": result_data.get("message", "")
			})

	return results

func _check_conditions(conditions: Array, context: Dictionary) -> bool:
	for condition in conditions:
		if not _check_single_condition(condition, context):
			return false
	return true

func _check_single_condition(condition: Dictionary, context: Dictionary) -> bool:
	var type = condition.get("type", "")

	match type:
		"skill_proficiency":
			var skill = condition.get("skill", "")
			var min_val = int(condition.get("min", 0))
			var proficiencies = context.get("skill_proficiency", {})
			return proficiencies.get(skill, 0) >= min_val

		"skill_used_count":
			var skill = condition.get("skill", "")
			var min_val = int(condition.get("min", 0))
			var counts = context.get("skill_used_count", {})
			return counts.get(skill, 0) >= min_val

		"random":
			var chance = float(condition.get("chance", 0))
			return _rng.randf() < chance

		"dialogue":
			var npc = condition.get("npc", "")
			var dialogue_id = condition.get("dialogue_id", "")
			var context_npc = context.get("npc", "")
			var context_dialogue = context.get("dialogue", "")
			return npc == context_npc and dialogue_id == context_dialogue

		"quest_completed":
			var quest = condition.get("quest", "")
			var completed = context.get("completed_quests", [])
			return quest in completed

		"item_used":
			var item = condition.get("item", "")
			return context.get("item", "") == item

		"inner_art_level":
			var min_level = int(condition.get("min", 0))
			var current_level = context.get("inner_art_level", 0)
			return current_level >= min_level

		"level":
			var min_level = int(condition.get("min", 0))
			return context.get("level", 0) >= min_level

	return false
