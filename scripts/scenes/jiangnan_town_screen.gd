extends "res://scripts/scenes/map_screen_base.gd"

func _ready() -> void:
    configure_map("jiangnan_town", Vector2(200, 960), Color("#7f8f6a"), Color("#476f3f"))
    super._ready()
