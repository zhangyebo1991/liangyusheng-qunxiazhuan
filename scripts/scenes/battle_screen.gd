extends Control

const ActorStateScript = preload("res://scripts/domain/actor_state.gd")
const MartialArtRecordScript = preload("res://scripts/domain/martial_art_record.gd")
const CombatSystemScript = preload("res://scripts/systems/combat_system.gd")

var output: Label

func _ready() -> void:
	output = Label.new()
	output.text = "战斗开始"
	output.position = Vector2(32, 32)
	output.size = Vector2(900, 240)
	add_child(output)

	var resolve_button = Button.new()
	resolve_button.text = "结算战斗"
	resolve_button.position = Vector2(32, 300)
	resolve_button.pressed.connect(_resolve_battle)
	add_child(resolve_button)

	var back_button = Button.new()
	back_button.text = "返回山道"
	back_button.position = Vector2(180, 300)
	back_button.pressed.connect(func(): SceneLoader.change_scene("res://scenes/world.tscn"))
	add_child(back_button)

func _resolve_battle() -> void:
	var attacker = ActorStateScript.from_dictionary(DataRepository.get_actor("hero_yun"))
	var defender = ActorStateScript.from_dictionary(DataRepository.get_actor("bandit_01"))
	var martial_art = MartialArtRecordScript.from_dictionary(DataRepository.get_martial_art("basic_sword"))
	var result = CombatSystemScript.new().resolve_duel(attacker, defender, martial_art)
	output.text = "\n".join(PackedStringArray(result.log))
	EventBus.battle_finished.emit(result.to_dictionary())
