extends Node

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const QuestSystemScript = preload("res://scripts/systems/quest_system.gd")
const MapStateScript = preload("res://scripts/domain/map_state.gd")
const SaveSystemScript = preload("res://scripts/systems/save_system.gd")

var party = PartyStateScript.new()
var quest_system = QuestSystemScript.new()
var map_state = MapStateScript.new()
var flags: Dictionary = {}
var battle_context: Dictionary = {}

func start_new_game() -> void:
	party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.add_item("herb_small", 1)
	quest_system = QuestSystemScript.new()
	map_state = MapStateScript.new()
	map_state.current_map_id = "mountain_pass"
	map_state.player_position = Vector2(160, 320)
	flags = {"current_map": "mountain_pass"}
	battle_context = {}
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").game_started.emit()

func set_player_position(position: Vector2) -> void:
	map_state.set_player_position(position)

func resolve_map_object(object_id: String) -> void:
	map_state.mark_object_resolved(object_id)

func is_map_object_resolved(object_id: String) -> bool:
	return map_state.is_object_resolved(object_id)

func set_battle_context(context: Dictionary) -> void:
	battle_context = context.duplicate(true)

func consume_battle_context() -> Dictionary:
	var context = battle_context.duplicate(true)
	battle_context = {}
	return context

func peek_battle_context() -> Dictionary:
	return battle_context.duplicate(true)

func apply_battle_result(result: Dictionary) -> void:
	if bool(result.get("victory", false)):
		var object_id = str(result.get("source_object_id", ""))
		if not object_id.is_empty():
			resolve_map_object(object_id)
		var quest_id = str(result.get("quest_id", ""))
		if not quest_id.is_empty():
			quest_system.mark_ready_to_complete(quest_id)
	else:
		map_state.player_position = Vector2(160, 320)

func save_to_path(path: String) -> bool:
	return SaveSystemScript.new().save_to_path(path, to_dictionary())

func load_from_path(path: String) -> bool:
	var data = SaveSystemScript.new().load_from_path(path)
	if data.is_empty():
		return false
	from_dictionary(data)
	return true

func to_dictionary() -> Dictionary:
	return {
		"party": party.to_dictionary(),
		"quests": quest_system.to_dictionary(),
		"map_state": map_state.to_dictionary(),
		"flags": flags.duplicate(true),
	}

func from_dictionary(data: Dictionary) -> void:
	party = PartyStateScript.new()
	party.from_dictionary(data.get("party", {}))
	quest_system = QuestSystemScript.new()
	quest_system.from_dictionary(data.get("quests", {}))
	map_state = MapStateScript.new()
	map_state.from_dictionary(data.get("map_state", {}))
	flags = data.get("flags", {}).duplicate(true)
	battle_context = {}
