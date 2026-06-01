@tool
extends SceneTree

func _init() -> void:
	_generate_all()
	quit()

func _generate_all() -> void:
	var characters := {
		"villager": {"body": Color("#8B7355"), "head": Color("#F5DEB3"), "detail": Color("#654321")},
		"merchant": {"body": Color("#2F4F4F"), "head": Color("#FFE4C4"), "detail": Color("#B8860B")},
		"scholar": {"body": Color("#F5F5F0"), "head": Color("#FFE4C4"), "detail": Color("#2F4F4F")},
	}

	for character_id in characters:
		var colors = characters[character_id]
		print("生成角色素材: %s ..." % character_id)
		var ok = SpriteGenerator.generate_character(character_id, colors["body"], colors["head"], colors["detail"])
		if ok:
			print("  完成")
		else:
			printerr("  失败: %s" % character_id)
