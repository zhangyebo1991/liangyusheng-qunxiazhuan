extends Node

signal game_started
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal battle_started(enemy_id: String)
signal battle_finished(result: Dictionary)
signal save_completed(success: bool)
signal map_message(message: String)
signal hero_mp_changed(cur_mp: int, max_mp: int)
signal inn_rested(inn_id: String)
