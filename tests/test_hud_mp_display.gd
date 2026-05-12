extends RefCounted

const HudScript = preload("res://scripts/scenes/hud.gd")

func run(assertions) -> void:
	var hud = HudScript.new()
	hud._ready()

	assertions.assert_true(hud.has_method("refresh_mp_display"), "HUD 应暴露 refresh_mp_display 方法")
	assertions.assert_true(hud.has_method("_on_hero_mp_changed"), "HUD 应暴露 _on_hero_mp_changed 回调")

	if not hud.has_method("refresh_mp_display"):
		hud.free()
		return

	hud.refresh_mp_display(7, 20)
	var mp_label = hud.get("mp_label")
	assertions.assert_true(mp_label != null, "HUD 应有 mp_label 字段")
	if mp_label != null:
		var text = str(mp_label.text)
		assertions.assert_true(text.find("7") >= 0 and text.find("20") >= 0, "MP 文本应包含当前 7 和最大 20")

	# 通过 _on_hero_mp_changed 也应触发刷新
	hud._on_hero_mp_changed(12, 25)
	if mp_label != null:
		var text2 = str(mp_label.text)
		assertions.assert_true(text2.find("12") >= 0 and text2.find("25") >= 0, "信号回调应同步刷新 MP 显示")

	hud.free()
