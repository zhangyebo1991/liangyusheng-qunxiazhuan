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
signal tactical_action_resolved(unit_id: String, action_id: String, target_cells: Array)
signal tactical_range_mode_changed(mode: int)
signal tactical_log_appended(line: String)
# Task 19: 战棋单位移动动画结束、move_unit 已落地后广播；
# from_cell / to_cell 用 Vector2i(x=q, y=r) 与 tactical_range_system 坐标系一致。
signal tactical_unit_moved(unit_id: String, from_cell: Vector2i, to_cell: Vector2i)
