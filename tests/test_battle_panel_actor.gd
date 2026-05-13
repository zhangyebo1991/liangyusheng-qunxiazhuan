extends RefCounted

const BATTLE_PANEL_ACTOR_PATH := "res://scripts/scenes/battle_panel_actor.gd"

func run(assertions) -> void:
	var BattlePanelActorScript = load(BATTLE_PANEL_ACTOR_PATH)
	assertions.assert_true(BattlePanelActorScript != null, "应存在战斗角色状态卡脚本")
	if BattlePanelActorScript == null:
		return

	var panel = BattlePanelActorScript.new()
	panel._ready()
	assertions.assert_true(panel._avatar_rect != null, "角色状态卡应创建头像容器")
	if panel._avatar_rect != null:
		assertions.assert_eq(
			panel._avatar_rect.expand_mode,
			TextureRect.EXPAND_IGNORE_SIZE,
			"高清头像容器应忽略贴图原始尺寸，避免把状态卡撑爆"
		)
	panel.free()
