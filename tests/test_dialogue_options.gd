extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")
const DialogueSystemScript = preload("res://scripts/systems/dialogue_system.gd")

class StubRepository:
	extends Node
	var dialogue: Dictionary = {}
	func get_dialogue(_dialogue_id: String) -> Dictionary:
		return dialogue

func run(assertions) -> void:
	var repository = StubRepository.new()
	repository.dialogue = {
		"id": "branch_test",
		"title": "分支测试",
		"lines": [
			{"speaker": "旁白", "text": "请选择。"}
		],
		"options": [
			{
				"id": "ask",
				"text": "询问",
				"conditions": [],
				"effects": [{"type": "set_flag", "key": "asked_branch", "value": true}],
				"next_dialogue_id": "branch_after"
			},
			{
				"id": "give",
				"text": "赠药",
				"conditions": [{"type": "has_item", "item_id": "herb_small", "amount": 2}],
				"effects": [{"type": "remove_item", "item_id": "herb_small", "amount": 1}],
				"next_dialogue_id": "branch_give",
				"unavailable_text": "背包中没有小还丹。"
			}
		],
		"rumor": {
			"id": "rumor_branch_test",
			"title": "分支测试传闻",
			"text": "这是分支测试传闻。",
			"source": "测试者",
			"related_quest_id": "quest_branch_test"
		}
	}

	var state = GameStateScript.new()
	state.start_new_game()
	var dialogue_system = DialogueSystemScript.new()
	dialogue_system.set_repository(repository)

	var record = dialogue_system.get_dialogue("branch_test")
	assertions.assert_eq(record.get("id", ""), "branch_test", "应能返回完整对话记录")
	record["id"] = "mutated"
	assertions.assert_eq(repository.dialogue.get("id", ""), "branch_test", "返回记录应为副本")

	var options = dialogue_system.get_options("branch_test")
	assertions.assert_eq(options.size(), 2, "应能读取两个对话选项")
	assertions.assert_eq(options[0].get("text", ""), "询问", "选项文本应正确")

	var dialogue_state = dialogue_system.build_dialogue_state("branch_test", state)
	assertions.assert_eq(dialogue_state.get("title", ""), "分支测试", "对话状态应包含标题")
	assertions.assert_eq(dialogue_state.get("rumor", {}).get("id", ""), "rumor_branch_test", "对话状态应包含传闻数据")
	assertions.assert_eq(dialogue_state.get("lines", []).size(), 1, "对话状态应包含对白行")
	assertions.assert_eq(dialogue_state.get("options", []).size(), 2, "对话状态应包含选项")
	assertions.assert_true(bool(dialogue_state.get("options", [])[0].get("available", false)), "无条件选项应可用")
	assertions.assert_true(not bool(dialogue_state.get("options", [])[1].get("available", true)), "物品不足选项应不可用")
	assertions.assert_eq(dialogue_state.get("options", [])[1].get("unavailable_reason", ""), "背包中没有小还丹。", "不可用选项应优先使用配置提示")

	state.party.add_item("herb_small", 1)
	var available_state = dialogue_system.build_dialogue_state("branch_test", state)
	assertions.assert_true(bool(available_state.get("options", [])[1].get("available", false)), "物品满足后赠药选项应可用")

	state.free()
	repository.free()
