extends Node

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const QuestSystemScript = preload("res://scripts/systems/quest_system.gd")

var party = PartyStateScript.new()
var quest_system = QuestSystemScript.new()
var flags: Dictionary = {}

func start_new_game() -> void:
	party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.add_item("herb_small", 1)
	quest_system = QuestSystemScript.new()
	flags = {"current_map": "world"}
	if has_node("/root/EventBus"):
		EventBus.game_started.emit()

func to_dictionary() -> Dictionary:
	return {
		"party": party.to_dictionary(),
		"quests": quest_system.to_dictionary(),
		"flags": flags.duplicate(true),
	}

func from_dictionary(data: Dictionary) -> void:
	party = PartyStateScript.new()
	party.from_dictionary(data.get("party", {}))
	quest_system = QuestSystemScript.new()
	quest_system.from_dictionary(data.get("quests", {}))
	flags = data.get("flags", {}).duplicate(true)
