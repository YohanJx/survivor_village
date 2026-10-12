class_name HudMenu
extends PanelContainer
## 次要操作菜单；入口按钮由共同管理者注入，不改变游戏状态。

var _button: Button


func _ready() -> void:
	hide()
	for child: Node in $Actions.get_children():
		var action: Button = child as Button
		if action != null:
			action.pressed.connect(_on_action_pressed)


func bind_button(button: Button) -> void:
	_button = button
	_button.pressed.connect(_on_menu_pressed)


## 返回是否消费了关闭请求；保留游戏、卡牌和其他窗口状态。
func close_panel() -> bool:
	if not visible:
		return false
	hide()
	return true


func _on_menu_pressed() -> void:
	visible = not visible


func _on_action_pressed() -> void:
	hide()
