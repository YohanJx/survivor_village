class_name WorkforceRow
extends PanelContainer
## 单个职业的展示与加减请求，没有自由数字输入或状态写入。

signal adjustment_requested(delta: int)

@onready var _name: Label = %RoleName
@onready var _count: Label = %RoleCount
@onready var _hint: Label = %RoleHint
@onready var _decrease: Button = %Decrease
@onready var _increase: Button = %Increase


func _ready() -> void:
	_decrease.pressed.connect(adjustment_requested.emit.bind(-1))
	_increase.pressed.connect(adjustment_requested.emit.bind(1))


func configure(
	role_name: String,
	count: int,
	hint: String,
	can_decrease: bool,
	can_increase: bool,
	show_actions: bool = true
) -> void:
	_name.text = role_name
	_count.text = "%d 人" % count
	_hint.text = hint
	_decrease.visible = show_actions
	_increase.visible = show_actions
	_decrease.disabled = not can_decrease
	_increase.disabled = not can_increase
