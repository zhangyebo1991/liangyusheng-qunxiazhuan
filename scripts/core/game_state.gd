extends Node

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const QuestSystemScript = preload("res://scripts/systems/quest_system.gd")
const MapStateScript = preload("res://scripts/domain/map_state.gd")
const JournalStateScript = preload("res://scripts/domain/journal_state.gd")
const SaveSystemScript = preload("res://scripts/systems/save_system.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const EffectSystemScript = preload("res://scripts/systems/effect_system.gd")
const GrowthSystemScript = preload("res://scripts/systems/growth_system.gd")
const LootSystemScript = preload("res://scripts/systems/loot_system.gd")

const DEFAULT_HERO_MAX_HP := 120
const DEFAULT_HERO_MAX_MP := 20
const STARTING_COINS := 80
const DEFAULT_MAP_SCENE_PATH := "res://scenes/mountain_pass.tscn"

var party = PartyStateScript.new()
var quest_system = QuestSystemScript.new()
var map_state = MapStateScript.new()
var journal_state = JournalStateScript.new()
var flags: Dictionary = {}
var battle_context: Dictionary = {}
var hero_hp := DEFAULT_HERO_MAX_HP
var hero_max_hp := DEFAULT_HERO_MAX_HP
var hero_max_mp := DEFAULT_HERO_MAX_MP
var hero_cur_mp := DEFAULT_HERO_MAX_MP
var last_inn_id: String = ""
var martial_proficiency: Dictionary = {}
var last_reward_result: Dictionary = {}

func start_new_game() -> void:
	party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.add_item("herb_small", 1)
	party.add_coins(STARTING_COINS)
	quest_system = QuestSystemScript.new()
	map_state = MapStateScript.new()
	journal_state = JournalStateScript.new()
	hero_max_hp = DEFAULT_HERO_MAX_HP
	hero_max_mp = DEFAULT_HERO_MAX_MP
	hero_hp = hero_max_hp
	hero_cur_mp = hero_max_mp
	party.set_member_status("hero_yun", {"hp": hero_hp, "mp": hero_cur_mp})
	last_inn_id = ""
	martial_proficiency = {}
	last_reward_result = {}
	set_current_map("mountain_pass", Vector2(160, 320))
	flags = {"current_map": "mountain_pass"}
	battle_context = {}
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").game_started.emit()

func actor_exists(actor_id: String) -> bool:
	return not _get_actor_data(actor_id).is_empty()

func initialize_party_member_status(actor_id: String) -> void:
	if party == null or actor_id.is_empty() or not party.has_member(actor_id):
		return
	if not party.get_member_status(actor_id).is_empty():
		return
	var actor = _get_actor_data(actor_id)
	if actor.is_empty():
		return
	var max_hp = max(1, int(actor.get("max_hp", actor.get("hp", 1))))
	var max_mp = max(0, int(actor.get("max_mp", 0)))
	party.set_member_status(actor_id, {"hp": max_hp, "mp": max_mp})
	if actor_id == "hero_yun":
		hero_max_hp = max_hp
		hero_hp = max_hp
		if max_mp > 0:
			hero_max_mp = max_mp
		hero_cur_mp = hero_max_mp

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
	var map_data = _get_map_data(map_id)
	if map_data.is_empty():
		push_error("地图编号不存在：%s" % map_id)
		return DEFAULT_MAP_SCENE_PATH
	var scene_path = str(map_data.get("scene_path", ""))
	if scene_path.is_empty():
		push_error("地图缺少场景路径：%s" % map_id)
		return DEFAULT_MAP_SCENE_PATH
	return scene_path

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
		_sync_hero_member_status()
		return 0
	var before = hero_hp
	hero_hp = min(hero_max_hp, hero_hp + amount)
	_sync_hero_member_status()
	return hero_hp - before

func is_hero_hp_full() -> bool:
	_normalize_hero_hp()
	return hero_hp >= hero_max_hp

func restore_hero_mp(amount: int) -> int:
	if amount <= 0:
		return 0
	_normalize_hero_mp()
	if hero_cur_mp >= hero_max_mp:
		_sync_hero_member_status()
		return 0
	var before = hero_cur_mp
	hero_cur_mp = min(hero_max_mp, hero_cur_mp + amount)
	var delta = hero_cur_mp - before
	_sync_hero_member_status()
	if delta > 0 and is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").hero_mp_changed.emit(hero_cur_mp, hero_max_mp)
	return delta

func consume_hero_mp(amount: int) -> bool:
	if amount <= 0:
		return true
	_normalize_hero_mp()
	if hero_cur_mp < amount:
		return false
	hero_cur_mp -= amount
	_sync_hero_member_status()
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").hero_mp_changed.emit(hero_cur_mp, hero_max_mp)
	return true

func set_hero_cur_mp(value: int) -> void:
	_normalize_hero_mp()
	var clamped = clamp(value, 0, hero_max_mp)
	if clamped == hero_cur_mp:
		_sync_hero_member_status()
		return
	hero_cur_mp = clamped
	_sync_hero_member_status()
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").hero_mp_changed.emit(hero_cur_mp, hero_max_mp)

func is_hero_mp_full() -> bool:
	_normalize_hero_mp()
	return hero_cur_mp >= hero_max_mp

func bind_inn(inn_id: String) -> void:
	if inn_id.is_empty():
		return
	last_inn_id = inn_id

func has_bound_inn() -> bool:
	return not last_inn_id.is_empty()

func _normalize_hero_mp() -> void:
	if hero_max_mp <= 0:
		hero_max_mp = DEFAULT_HERO_MAX_MP
	hero_cur_mp = clamp(hero_cur_mp, 0, hero_max_mp)

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
	if result.has("hero_final_mp"):
		var final_mp = int(result.get("hero_final_mp", -1))
		if final_mp >= 0:
			set_hero_cur_mp(final_mp)
	if result.has("hero_hp"):
		hero_hp = _protected_battle_hp(int(result.get("hero_hp", hero_hp)))
		_sync_hero_member_status()
	_apply_party_member_results(result.get("party_member_results", {}))

	if bool(result.get("victory", false)):
		_normalize_hero_hp()
		var effect_system = EffectSystemScript.new()
		effect_system.apply_effects(self, _battle_victory_effects(result), result)
		last_reward_result = _apply_victory_rewards(result)
	else:
		last_reward_result = {}
		if has_bound_inn():
			var inn = _resolve_bound_inn()
			if not inn.is_empty():
				var inn_map_id = str(inn.get("map_id", ""))
				var spawn = inn.get("spawn_position", {})
				var spawn_pos = Vector2(int(spawn.get("x", 160)), int(spawn.get("y", 320)))
				if not inn_map_id.is_empty():
					set_current_map(inn_map_id, spawn_pos)
				hero_hp = hero_max_hp
				hero_cur_mp = hero_max_mp
				_normalize_hero_hp()
				_normalize_hero_mp()
				_sync_hero_member_status()
				if is_inside_tree() and has_node("/root/EventBus"):
					get_node("/root/EventBus").hero_mp_changed.emit(hero_cur_mp, hero_max_mp)
				return
		# 未绑定客栈：沿用原地复活
		hero_hp = max(1, hero_hp)
		_sync_hero_member_status()
		map_state.player_position = Vector2(160, 320)

func _battle_victory_effects(result: Dictionary) -> Array:
	var explicit_effects = result.get("victory_effects", [])
	if typeof(explicit_effects) == TYPE_ARRAY and not explicit_effects.is_empty():
		return explicit_effects

	var effects: Array = []
	var object_id = str(result.get("source_object_id", ""))
	if not object_id.is_empty():
		effects.append({"type": "resolve_map_object", "object_id": object_id})
	var quest_id = str(result.get("quest_id", ""))
	if not quest_id.is_empty():
		effects.append({"type": "set_quest_status", "quest_id": quest_id, "status": "ready_to_complete"})
	var martial_art_id = str(result.get("martial_art_id", ""))
	var reward = int(result.get("proficiency_reward", 0))
	if not martial_art_id.is_empty() and reward > 0:
		effects.append({"type": "add_martial_proficiency", "martial_art_id": martial_art_id, "amount": reward})
	return effects

func apply_growth_results(experience: Array) -> void:
	_apply_growth_results_to_hero(experience)

func _apply_victory_rewards(result: Dictionary) -> Dictionary:
	var rewards = result.get("victory_rewards", {})
	if typeof(rewards) != TYPE_DICTIONARY or rewards.is_empty():
		return {}
	var summary: Dictionary = {"experience": [], "coins": 0, "items": []}
	var repository = _get_data_repository_for_rewards()
	var exp_amount = int(rewards.get("exp", 0))
	if exp_amount > 0 and repository != null:
		var growth = GrowthSystemScript.new()
		var participants = result.get("participating_party_members", [])
		if typeof(participants) == TYPE_ARRAY:
			for actor_id in participants:
				var growth_result = growth.add_exp(party, str(actor_id), exp_amount, repository)
				if bool(growth_result.get("success", false)):
					summary["experience"].append(growth_result)
	var fixed_coins = int(rewards.get("coins", 0))
	if fixed_coins > 0:
		party.add_coins(fixed_coins)
		summary["coins"] = int(summary.get("coins", 0)) + fixed_coins
	var items = rewards.get("items", [])
	if typeof(items) == TYPE_ARRAY:
		for item in items:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var item_id = str(item.get("item_id", ""))
			var amount = max(1, int(item.get("amount", 1)))
			if item_id.is_empty():
				continue
			party.add_item(item_id, amount)
			summary["items"].append({"item_id": item_id, "id": item_id, "amount": amount, "source": "fixed"})
	var loot_table = rewards.get("loot_table", {})
	if typeof(loot_table) == TYPE_DICTIONARY and not loot_table.is_empty():
		var loot_result = LootSystemScript.new().roll_loot(loot_table)
		_apply_loot_result(summary, loot_result, repository)
	_apply_growth_results_to_hero(summary["experience"])
	return summary

func _apply_loot_result(summary: Dictionary, loot_result: Dictionary, repository) -> void:
	var loot_summary = {
		"rolled": bool(loot_result.get("rolled", false)),
		"coins": max(0, int(loot_result.get("coins", 0))),
		"items": [],
		"errors": [],
	}
	var raw_errors = loot_result.get("errors", [])
	if typeof(raw_errors) == TYPE_ARRAY:
		for error in raw_errors:
			loot_summary["errors"].append(str(error))

	var loot_coins = int(loot_summary.get("coins", 0))
	if loot_coins > 0:
		party.add_coins(loot_coins)
		summary["coins"] = int(summary.get("coins", 0)) + loot_coins

	var loot_items = loot_result.get("items", [])
	if typeof(loot_items) == TYPE_ARRAY:
		for item in loot_items:
			if typeof(item) != TYPE_DICTIONARY:
				loot_summary["errors"].append("掉落物品格式错误。")
				continue
			var item_id = str(item.get("item_id", ""))
			var amount = max(1, int(item.get("amount", 1)))
			if item_id.is_empty():
				loot_summary["errors"].append("掉落物品编号缺失。")
				continue
			if repository == null or not repository.has_method("get_item") or repository.get_item(item_id).is_empty():
				loot_summary["errors"].append("掉落物品资料缺失：%s。" % item_id)
				continue
			party.add_item(item_id, amount)
			var record = {"item_id": item_id, "id": item_id, "amount": amount}
			loot_summary["items"].append(record)
			summary["items"].append({"item_id": item_id, "id": item_id, "amount": amount, "source": "loot"})
	summary["loot"] = loot_summary

func _apply_growth_results_to_hero(experience: Array) -> void:
	if party == null or not party.has_member("hero_yun"):
		return
	var changed := false
	for member_result in experience:
		if typeof(member_result) != TYPE_DICTIONARY or str(member_result.get("actor_id", "")) != "hero_yun":
			continue
		var next_max_hp = max(1, int(member_result.get("max_hp", hero_max_hp)))
		var next_max_mp = max(0, int(member_result.get("max_mp", hero_max_mp)))
		changed = changed or next_max_hp != hero_max_hp or next_max_mp != hero_max_mp
		hero_max_hp = next_max_hp
		hero_max_mp = next_max_mp
	var status = party.get_member_status("hero_yun")
	if status.is_empty():
		return
	var next_hp = clamp(int(status.get("hp", hero_hp)), 0, hero_max_hp)
	var next_mp = clamp(int(status.get("mp", hero_cur_mp)), 0, hero_max_mp)
	changed = changed or next_hp != hero_hp or next_mp != hero_cur_mp
	hero_hp = next_hp
	hero_cur_mp = next_mp
	_sync_hero_member_status()
	if changed and is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").hero_mp_changed.emit(hero_cur_mp, hero_max_mp)

func _get_data_repository_for_rewards():
	if is_inside_tree() and has_node("/root/DataRepository"):
		return get_node("/root/DataRepository")
	var repository = DataRepositoryScript.new()
	repository.load_all()
	return repository

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
		"journal_state": journal_state.to_dictionary(),
		"flags": flags.duplicate(true),
		"hero_hp": hero_hp,
		"hero_max_hp": hero_max_hp,
		"hero_max_mp": hero_max_mp,
		"hero_cur_mp": hero_cur_mp,
		"last_inn_id": last_inn_id,
		"martial_proficiency": _normalized_martial_proficiency(),
	}

func from_dictionary(data: Dictionary) -> void:
	party = PartyStateScript.new()
	party.from_dictionary(data.get("party", {}))
	quest_system = QuestSystemScript.new()
	quest_system.from_dictionary(data.get("quests", {}))
	map_state = MapStateScript.new()
	map_state.from_dictionary(data.get("map_state", {}))
	journal_state = JournalStateScript.new()
	journal_state.from_dictionary(data.get("journal_state", {}))
	flags = data.get("flags", {}).duplicate(true)
	if not flags.has("current_map"):
		flags["current_map"] = map_state.current_map_id
	hero_max_hp = int(data.get("hero_max_hp", DEFAULT_HERO_MAX_HP))
	if hero_max_hp <= 0:
		hero_max_hp = DEFAULT_HERO_MAX_HP
	hero_max_mp = int(data.get("hero_max_mp", DEFAULT_HERO_MAX_MP))
	if hero_max_mp <= 0:
		hero_max_mp = DEFAULT_HERO_MAX_MP
	hero_cur_mp = int(data.get("hero_cur_mp", hero_max_mp))
	last_inn_id = str(data.get("last_inn_id", ""))
	hero_hp = int(data.get("hero_hp", hero_max_hp))
	martial_proficiency = _read_martial_proficiency(data.get("martial_proficiency", {}))
	last_reward_result = {}
	_normalize_hero_hp()
	_normalize_hero_mp()
	_sync_hero_member_status()
	battle_context = {}

func _normalize_hero_hp() -> void:
	if hero_max_hp <= 0:
		hero_max_hp = DEFAULT_HERO_MAX_HP
	hero_hp = clamp(hero_hp, 0, hero_max_hp)

func _protected_battle_hp(value: int) -> int:
	if value <= 0:
		return 1
	return value

func _sync_hero_member_status() -> void:
	if party == null or not party.has_member("hero_yun"):
		return
	party.set_member_status("hero_yun", {"hp": hero_hp, "mp": hero_cur_mp})

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

func _apply_party_member_results(value: Variant) -> void:
	if party == null or typeof(value) != TYPE_DICTIONARY:
		return
	for actor_id in value.keys():
		var raw_status = value[actor_id]
		if typeof(raw_status) != TYPE_DICTIONARY:
			continue
		var normalized_id = str(actor_id)
		if not party.has_member(normalized_id):
			continue
		var next_hp = _protected_battle_hp(int(raw_status.get("hp", 0)))
		var next_mp = max(0, int(raw_status.get("mp", 0)))
		party.set_member_status(normalized_id, {"hp": next_hp, "mp": next_mp})
		if normalized_id == "hero_yun":
			hero_hp = next_hp
			set_hero_cur_mp(next_mp)

func _get_actor_data(actor_id: String) -> Dictionary:
	if actor_id.is_empty():
		return {}
	if is_inside_tree() and has_node("/root/DataRepository"):
		return get_node("/root/DataRepository").get_actor(actor_id)
	var repository = DataRepositoryScript.new()
	var actor = repository.get_actor(actor_id)
	repository.free()
	return actor if typeof(actor) == TYPE_DICTIONARY else {}

func _get_map_data(map_id: String) -> Dictionary:
	if map_id.is_empty():
		return {}
	if is_inside_tree() and has_node("/root/DataRepository"):
		return get_node("/root/DataRepository").get_map(map_id)
	var repository = DataRepositoryScript.new()
	var map_data = repository.get_map(map_id)
	repository.free()
	return map_data

func _resolve_bound_inn() -> Dictionary:
	if last_inn_id.is_empty():
		return {}
	if is_inside_tree() and has_node("/root/DataRepository"):
		return get_node("/root/DataRepository").get_inn(last_inn_id)
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var inn = repository.get_inn(last_inn_id)
	repository.free()
	return inn
