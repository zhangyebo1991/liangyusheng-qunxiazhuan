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

func on_dialogue_event(npc_id: String, dialogue_id: String):
	insights.check_triggers("dialogue", {"npc": npc_id, "dialogue": dialogue_id})

func on_item_used(item_id: String):
	insights.check_triggers("item", {"item": item_id})
