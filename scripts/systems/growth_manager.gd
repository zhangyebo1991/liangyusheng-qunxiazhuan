extends RefCounted

var proficiency_points: int = 0
var skill_trees: RefCounted
var inner_arts: RefCounted
var insights: RefCounted

func _init():
	skill_trees = preload("res://scripts/systems/skill_tree_system.gd").new()
	inner_arts = preload("res://scripts/systems/inner_art_system.gd").new()
	insights = preload("res://scripts/systems/insight_system.gd").new()

func on_battle_end(battle_data: Dictionary):
	var enemies = int(battle_data.get("enemies", 1))
	var difficulty = int(battle_data.get("difficulty", 1))
	proficiency_points += enemies * difficulty

func on_dialogue_event(npc_id: String, dialogue_id: String) -> Array:
	return insights.check_triggers("dialogue", {"npc": npc_id, "dialogue": dialogue_id})

func on_item_used(item_id: String) -> Array:
	return insights.check_triggers("item", {"item": item_id})

func unlock_skill_node(skill_id: String, node_id: String) -> Dictionary:
	var result = skill_trees.unlock_node(skill_id, node_id, proficiency_points)
	if result.get("success", false):
		proficiency_points -= int(result.get("cost", 0))
	return result

func learn_art(art_id: String) -> Dictionary:
	return inner_arts.learn_art(art_id)

func upgrade_art(art_id: String) -> Dictionary:
	var result = inner_arts.upgrade_art(art_id, proficiency_points)
	if result.get("success", false):
		proficiency_points -= int(result.get("cost", 0))
	return result

func switch_active(art_id: String) -> Dictionary:
	return inner_arts.switch_active(art_id)

func get_art_level(art_id: String) -> int:
	return inner_arts.get_art_level(art_id)

func get_active_art() -> String:
	return inner_arts.get_active_art()

func get_active_effects() -> Dictionary:
	return inner_arts.get_active_effects()

func to_dictionary() -> Dictionary:
	return {
		"proficiency_points": proficiency_points,
		"unlocked_nodes": skill_trees._unlocked_nodes.duplicate(true),
		"learned_arts": inner_arts._learned_arts.duplicate(true),
		"active_art": inner_arts.get_active_art(),
		"triggered_insights": insights._triggered.duplicate(true),
	}

func from_dictionary(data: Dictionary) -> void:
	proficiency_points = max(0, int(data.get("proficiency_points", 0)))
	var unlocked = data.get("unlocked_nodes", {})
	if typeof(unlocked) == TYPE_DICTIONARY:
		skill_trees._unlocked_nodes = unlocked.duplicate(true)
	var learned = data.get("learned_arts", {})
	if typeof(learned) == TYPE_DICTIONARY:
		inner_arts._learned_arts = learned.duplicate(true)
	var active = str(data.get("active_art", ""))
	if not active.is_empty() and inner_arts._learned_arts.has(active):
		inner_arts._active_art = active
	var triggered = data.get("triggered_insights", {})
	if typeof(triggered) == TYPE_DICTIONARY:
		insights._triggered = triggered.duplicate(true)
