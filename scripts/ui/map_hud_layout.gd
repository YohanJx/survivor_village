class_name MapHudLayout
extends Control
## 紧凑地图工具条与按需展开的目标/线索；不占地图布局空间。

@onready var _details: PanelContainer = $MapDetails
var _toggle: Button


func _ready() -> void:
	_details.hide()


func bind_toggle(toggle: Button) -> void:
	_toggle = toggle
	_toggle.toggled.connect(_on_details_toggled)


## 返回是否关闭了详情；不改变勘探目标、视角或卡牌选择。
func close_details() -> bool:
	if not _details.visible:
		return false
	_toggle.button_pressed = false
	return true


func _on_details_toggled(expanded: bool) -> void:
	_details.visible = expanded
	_toggle.text = "目标·线索 ▴" if expanded else "目标·线索 ▾"
