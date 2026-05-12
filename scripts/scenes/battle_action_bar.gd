extends Control

# Task 12: 底部 7 图标行动栏。
# 7 个动作：移动 / 普攻 / 技能 / 道具 / 待机 / 查看 / 系统
# 选中后 emit action_selected(id)。set_enabled_actions 控制按钮 disabled 态。

signal action_selected(action_id: String)

const ACTIONS := [
	{"id": "move", "label": "移动"},
	{"id": "attack", "label": "普攻"},
	{"id": "skill", "label": "技能"},
	{"id": "item", "label": "道具"},
	{"id": "wait", "label": "待机"},
	{"id": "view", "label": "查看"},
	{"id": "system", "label": "系统"},
]

var _buttons: Dictionary = {}
var _enabled_ids: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(700, 80)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	add_child(hbox)
	for a in ACTIONS:
		var btn := Button.new()
		btn.text = str(a.label)
		btn.custom_minimum_size = Vector2(80, 60)
		btn.pressed.connect(_on_btn.bind(str(a.id)))
		hbox.add_child(btn)
		_buttons[str(a.id)] = btn

func set_enabled_actions(ids: Array) -> void:
	_enabled_ids = {}
	for i in ids:
		_enabled_ids[str(i)] = true
	for k in _buttons.keys():
		_buttons[k].disabled = not _enabled_ids.has(k)

func get_button(id: String) -> Button:
	return _buttons.get(id, null)

func _on_btn(id: String) -> void:
	action_selected.emit(id)
