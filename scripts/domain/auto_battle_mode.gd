class_name AutoBattleMode
extends RefCounted

var is_auto: bool = false

func toggle() -> void:
	is_auto = not is_auto

func set_auto(value: bool) -> void:
	is_auto = value

func to_dictionary() -> Dictionary:
	return {
		"is_auto": is_auto
	}

func from_dictionary(data: Dictionary) -> void:
	is_auto = bool(data.get("is_auto", false))
