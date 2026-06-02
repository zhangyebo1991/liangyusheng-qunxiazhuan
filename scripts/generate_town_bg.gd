@tool
extends SceneTree

## 独立运行脚本 — 生成 jiangnan_town 底图。
## 用法: godot --headless --script scripts/generate_town_bg.gd

func _init() -> void:
	var ok = MapBackgroundGenerator.generate_town_background(
		"res://assets/maps/jiangnan_town/background.png",
		2560,
		1920
	)
	if ok:
		print("底图已生成: assets/maps/jiangnan_town/background.png")
	else:
		printerr("底图生成失败")
	quit()
