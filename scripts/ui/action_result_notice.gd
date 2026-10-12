class_name ActionResultNotice
extends PanelContainer
## 短暂显示实际提交结果；只读文本，不在动画回调执行游戏逻辑。


@onready var _timer: Timer = $Timer
@onready var _message: Label = $Message


func _ready() -> void:
	_timer.timeout.connect(hide)
	hide()


func show_message(message: String) -> void:
	_message.text = message
	show()
	_timer.start()
