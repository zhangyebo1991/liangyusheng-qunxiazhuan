extends RefCounted

const HudScript = preload("res://scripts/scenes/hud.gd")

func run(assertions) -> void:
	var hud = HudScript.new()
	hud._ready()

	hud.show_inventory([{
		"id": "herb_small",
		"name": "小还丹",
		"type": "consumable",
		"description": "少量恢复气血。",
		"quantity": 1,
		"usable": true,
	}])

	var row = hud.inventory_list.get_child(0)
	var header = row.get_child(0)
	assertions.assert_eq(header.text, "小还丹 x1", "背包物品标题不应显示内部类型")

	hud.free()
