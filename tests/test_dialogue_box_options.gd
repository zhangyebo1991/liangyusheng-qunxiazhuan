extends RefCounted

const DialogueBoxScript = preload("res://scripts/scenes/dialogue_box.gd")

func run(assertions) -> void:
	var box = DialogueBoxScript.new()
	box._ready()
	var selected: Array = []
	box.option_selected.connect(func(option: Dictionary): selected.append(option))

	box.open_dialogue_state({
		"lines": [{"speaker": "赶路书生", "text": "少侠留步。"}],
		"options": [
			{"id": "ask", "text": "询问路上异动", "available": true},
			{"id": "give", "text": "赠予小还丹", "available": false, "unavailable_reason": "背包中没有小还丹。"}
		]
	})

	assertions.assert_true(box.visible, "打开分支对话后对话框应可见")
	assertions.assert_eq(box.option_container.get_child_count(), 2, "分支对话应创建两个选项按钮")
	var ask_button = box.option_container.get_child(0)
	var give_button = box.option_container.get_child(1)
	assertions.assert_eq(ask_button.text, "询问路上异动", "可用选项按钮文本应正确")
	assertions.assert_true(not ask_button.disabled, "可用选项按钮不应禁用")
	assertions.assert_true(give_button.disabled, "不可用选项按钮应禁用")
	assertions.assert_eq(give_button.tooltip_text, "背包中没有小还丹。", "不可用选项应带提示")

	ask_button.pressed.emit()
	assertions.assert_eq(selected.size(), 1, "点击可用选项应发出选择信号")
	assertions.assert_eq(selected[0].get("id", ""), "ask", "选择信号应携带选项数据")
	assertions.assert_true(not box.visible, "点击选项后对话框应关闭")

	box.open([{"speaker": "旁白", "text": "线性对白。"}])
	assertions.assert_eq(box.option_container.get_child_count(), 0, "线性对白不应残留选项按钮")

	box.free()
