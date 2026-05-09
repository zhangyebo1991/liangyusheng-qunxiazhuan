extends Node

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const QuestSystemScript = preload("res://scripts/systems/quest_system.gd")
const MapStateScript = preload("res://scripts/domain/map_state.gd")
const SaveSystemScript = preload("res://scripts/systems/save_system.gd")

const DEFAULT_HERO_MAX_HP := 120
const STARTING_COINS := 80

var party = PartyStateScript.new()
var quest_system = QuestSystemScript.new()
var map_state = MapStateScript.new()
var flags: Dictionary = {}
var battle_context: Dictionary = {}
var hero_hp := DEFAULT_HERO_MAX_HP
var hero_max_hp := DEFAULT_HERO_MAX_HP
var martial_proficiency: Dictionary = {}

func start_new_game() -> void:
	party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.add_item("herb_small", 1)
	party.add_coins(STARTING_COINS)
	quest_system = QuestSystemScript.new()
	map_state = MapStateScript.new()
	hero_max_hp = DEFAULT_HERO_MAX_HP
	hero_hp = hero_max_hp
	martial_proficiency = {}
	set_current_map("mountain_pass", Vector2(160, 320))
	flags = {"current_map": "mountain_pass"}
	battle_context = {}
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").game_started.emit()

func set_player_position(position: Vector2) -> void:
	map_state.set_player_position(position)

func set_current_map(map_id: String, position: Vector2) -> void:
	if map_id.is_empty():
		return
	map_state.current_map_id = map_id
	map_state.set_player_position(position)
	flags["current_map"] = map_id

func get_current_map_scene_path() -> String:
	return get_scene_path_for_map(map_state.current_map_id)

func get_scene_path_for_map(map_id: String) -> String:
	match map_id:
		"mountain_pass":
			return "res://scenes/mountain_pass.tscn"
		"foot_village":
			return "res://scenes/foot_village.tscn"
		_:
			return "res://scenes/mountain_pass.tscn"

func set_flag(flag_id: String, value: Variant = true) -> void:
	if flag_id.is_empty():
		return
	flags[flag_id] = value

func resolve_map_object(object_id: String) -> void:
	map_state.mark_object_resolved(object_id)

func is_map_object_resolved(object_id: String) -> bool:
	return map_state.is_object_resolved(object_id)

func restore_hero_hp(amount: int) -> int:
	if amount <= 0:
		return 0
	_normalize_hero_hp()
	if hero_hp >= hero_max_hp:
		return 0
	var before = hero_hp
	hero_hp = min(hero_max_hp, hero_hp + amount)
	return hero_hp - before

func is_hero_hp_full() -> bool:
	_normalize_hero_hp()
	return hero_hp >= hero_max_hp

func add_martial_proficiency(martial_art_id: String, amount: int) -> int:
	if martial_art_id.is_empty() or amount <= 0:
		return get_martial_proficiency(martial_art_id)
	martial_proficiency[martial_art_id] = get_martial_proficiency(martial_art_id) + amount
	return int(martial_proficiency[martial_art_id])

func get_martial_proficiency(martial_art_id: String) -> int:
	if martial_art_id.is_empty():
		return 0
	return max(0, int(martial_proficiency.get(martial_art_id, 0)))

func set_battle_context(context: Dictionary) -> void:
	battle_context = context.duplicate(true)

func consume_battle_context() -> Dictionary:
	var context = battle_context.duplicate(true)
	battle_context = {}
	return context

func peek_battle_context() -> Dictionary:
	return battle_context.duplicate(true)

func apply_battle_result(result: Dictionary) -> void:
	if result.has("hero_hp"):
		hero_hp = int(result.get("hero_hp", hero_hp))

	if bool(result.get("victory", false)):
		_normalize_hero_hp()
		var object_id = str(result.get("source_object_id", ""))
		if not object_id.is_empty():
			resolve_map_object(object_id)
		var quest_id = str(result.get("quest_id", ""))
		if not quest_id.is_empty():
			quest_system.mark_ready_to_complete(quest_id)
		var martial_art_id = str(result.get("martial_art_id", ""))
		var reward = int(result.get("proficiency_reward", 0))
		if reward > 0:
			add_martial_proficiency(martial_art_id, reward)
	else:
		hero_hp = max(1, hero_hp)
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
	_normalize_hero_hp()
	return {
		"party": party.to_dictionary(),
		"quests": quest_system.to_dictionary(),
		"map_state": map_state.to_dictionary(),
		"flags": flags.duplicate(true),
		"hero_hp": hero_hp,
		"hero_max_hp": hero_max_hp,
		"martial_proficiency": _normalized_martial_proficiency(),
	}

func from_dictionary(data: Dictionary) -> void:
	party = PartyStateScript.new()
	party.from_dictionary(data.get("party", {}))
	quest_system = QuestSystemScript.new()
	quest_system.from_dictionary(data.get("quests", {}))
	map_state = MapStateScript.new()
	map_state.from_dictionary(data.get("map_state", {}))
	flags = data.get("flags", {}).duplicate(true)
	if not flags.has("current_map"):
		flags["current_map"] = map_state.current_map_id
	hero_max_hp = int(data.get("hero_max_hp", DEFAULT_HERO_MAX_HP))
	if hero_max_hp <= 0:
		hero_max_hp = DEFAULT_HERO_MAX_HP
	hero_hp = int(data.get("hero_hp", hero_max_hp))
	martial_proficiency = _read_martial_proficiency(data.get("martial_proficiency", {}))
	_normalize_hero_hp()
	battle_context = {}

func _normalize_hero_hp() -> void:
	if hero_max_hp <= 0:
		hero_max_hp = DEFAULT_HERO_MAX_HP
	hero_hp = clamp(hero_hp, 0, hero_max_hp)

func _normalized_martial_proficiency() -> Dictionary:
	var result: Dictionary = {}
	for martial_art_id in martial_proficiency.keys():
		var normalized_id = str(martial_art_id)
		if normalized_id.is_empty():
			continue
		var amount = max(0, int(martial_proficiency[martial_art_id]))
		if amount > 0:
			result[normalized_id] = amount
	return result

func _read_martial_proficiency(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for martial_art_id in value.keys():
		var normalized_id = str(martial_art_id)
		if normalized_id.is_empty():
			continue
		var amount = max(0, int(value[martial_art_id]))
		if amount > 0:
			result[normalized_id] = amount
	return result
