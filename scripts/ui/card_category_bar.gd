class_name CardCategoryBar
extends HBoxContainer
## 常驻底部类别入口；只统计定义类别并发出选择请求，不执行卡牌。

signal category_requested(index: int)

const CATEGORY_NAMES: PackedStringArray = ["全部", "行动", "建造", "科技", "事件"]
const NAVIGATION_TITLES: PackedStringArray = ["全部卡牌", "日常行动", "建造设施", "科技升级", "特殊事件"]

var _buttons: Array[Button] = []
var _captions: Array[Label] = []
var _descriptions: Array[Label] = []
var _active_index: int = 0
var _expanded: bool = false


func _ready() -> void:
	for index: int in get_child_count():
		var column: Node = get_child(index)
		var button: Button = column.get_node("Button") as Button
		_buttons.append(button)
		_captions.append(column.get_node("Caption") as Label)
		_descriptions.append(column.get_node("Description") as Label)
		button.pressed.connect(_on_category_pressed.bind(index))
	_refresh_selection()


func update_view(state: VillageState, blocked: bool) -> void:
	var counts: PackedInt32Array = PackedInt32Array([state.hand.size(), 0, 0, 0, 0])
	for entry: CardInstance in state.hand:
		counts[int(entry.definition.kind) + 1] += 1
	for index: int in _buttons.size():
		_captions[index].text = "%s · %d" % [NAVIGATION_TITLES[index], counts[index]]
		_buttons[index].tooltip_text = "%s：%s（%d 张）\n点击展开卡牌，再次点击收起" % [
			NAVIGATION_TITLES[index], _descriptions[index].text, counts[index]
		]
		_buttons[index].disabled = blocked


func set_selection(index: int, expanded: bool) -> void:
	_active_index = index
	_expanded = expanded
	_refresh_selection()


## 返回游戏视口中的按钮矩形，供共同管理者连接弹出面板位置。
func button_rect(index: int) -> Rect2:
	return _buttons[index].get_global_rect()


func _on_category_pressed(index: int) -> void:
	category_requested.emit(index)


func _refresh_selection() -> void:
	for index: int in _buttons.size():
		_buttons[index].set_pressed_no_signal(_expanded and index == _active_index)
		_captions[index].modulate = (
			UiElements.TEXT_PRIMARY if _expanded and index == _active_index else UiElements.TEXT_SECONDARY
		)
