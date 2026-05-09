extends Control

const ActorStateScript = preload("res://scripts/domain/actor_state.gd")
const MartialArtRecordScript = preload("res://scripts/domain/martial_art_record.gd")
const CombatSystemScript = preload("res://scripts/systems/combat_system.gd")

var output: Label
var context: Dictionary = {}

func _ready() -> void:
	context = GameState.peek_battle_context()

	output = Label.new()
	output.text = "战斗开始：%s" % DataRepository.get_actor(_enemy_id()).get("name", "山道强人")
	output.position = Vector2(32, 32)
	output.size = Vector2(900, 240)
	add_child(output)

	var resolve_button = Button.new()
	resolve_button.text = "基础剑法"
	resolve_button.position = Vector2(32, 300)
	resolve_button.pressed.connect(_resolve_battle)
	add_child(resolve_button)

	var back_button = Button.new()
	back_button.text = "暂退"
	back_button.position = Vector2(180, 300)
	back_button.pressed.connect(_retreat)
	add_child(back_button)

func _resolve_battle() -> void:
	var attacker = ActorStateScript.from_dictionary(DataRepository.get_actor("hero_yun"))
	var defender = ActorStateScript.from_dictionary(DataRepository.get_actor(_enemy_id()))
	var martial_art = MartialArtRecordScript.from_dictionary(DataRepository.get_martial_art("basic_sword"))
	var result = CombatSystemScript.new().resolve_duel(attacker, defender, martial_art)
	output.text = "\n".join(PackedStringArray(result.log))
	var payload = result.to_dictionary()
	payload["victory"] = result.winner_id == "hero_yun"
	payload["source_object_id"] = str(context.get("source_object_id", ""))
	payload["quest_id"] = str(context.get("quest_id", ""))
	GameState.apply_battle_result(payload)
	EventBus.battle_finished.emit(payload)
	call_deferred("_return_to_map")

func _retreat() -> void:
	GameState.apply_battle_result({
		"victory": false,
		"source_object_id": str(context.get("source_object_id", "")),
		"quest_id": str(context.get("quest_id", "")),
	})
	call_deferred("_return_to_map")

func _return_to_map() -> void:
	GameState.consume_battle_context()
	SceneLoader.change_scene("res://scenes/mountain_pass.tscn")

func _enemy_id() -> String:
	var enemy_id = str(context.get("enemy_id", "bandit_01"))
	if enemy_id.is_empty():
		return "bandit_01"
	return enemy_id
