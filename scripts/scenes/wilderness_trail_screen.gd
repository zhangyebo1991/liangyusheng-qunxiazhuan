extends "res://scripts/scenes/map_screen_base.gd"

func _ready() -> void:
    configure_map("wilderness_trail", Vector2(160, 960), Color("#6f8f55"), Color("#476f3f"))
    super._ready()
