class_name ActionDock
extends Control
## 卡牌弹出面板覆盖地图；按类别按钮定位连接标记，展示状态不进入存档。

signal expanded_changed(expanded: bool)

const EDGE_MARGIN: float = 16.0
const BUTTON_GAP: float = 18.0

@export var popup_width: float = 1000.0
@export var popup_height: float = 420.0

var _navigation: CardCategoryBar
var _category_index: int = 0

@onready var _tray: PanelContainer = $ActionTray
@onready var _connector: Polygon2D = $Connector
@onready var _hand: VillageHandPanel = %HandPanel
@onready var _detail: VillageDetailPanel = %DetailPanel
@onready var _title: Label = %CategoryTitle
@onready var _toggle: Button = $CenterRow/MapColumn/BattleControls/ToggleCards


func _ready() -> void:
	_hand.visible_cards_changed.connect(_on_layout_changed)
	_tray.minimum_size_changed.connect(_on_layout_changed)
	resized.connect(_on_layout_changed)
	_toggle.pressed.connect(_on_toggle_pressed)
	(%CloseCards as Button).pressed.connect(_on_toggle_pressed)
	set_expanded(false)


## 由共同管理者注入导航；只读取按钮位置，不查找父节点或游戏状态。
func bind_navigation(navigation: CardCategoryBar) -> void:
	_navigation = navigation
	_navigation.resized.connect(_on_layout_changed)
	_on_layout_changed()


func refresh_layout() -> void:
	_on_layout_changed()


func set_category(index: int) -> void:
	_category_index = index
	_title.text = CardCategoryBar.NAVIGATION_TITLES[index]
	_on_layout_changed()


## 仅改变展示；收起不改变地图尺寸、卡牌选择或游戏状态。
func set_expanded(expanded: bool) -> void:
	if _tray.visible == expanded:
		return
	_tray.visible = expanded
	_connector.visible = expanded
	_toggle.text = "收起卡牌 ▾" if expanded else "展开卡牌 ▴"
	_toggle.tooltip_text = "卡牌面板浮动在类别按钮上方；勘探时可收起面板选择地图目标"
	_on_layout_changed()
	expanded_changed.emit(expanded)


func is_expanded() -> bool:
	return _tray.visible


func _on_toggle_pressed() -> void:
	set_expanded(not _tray.visible)


func _on_layout_changed() -> void:
	call_deferred("_position_popup")


func _position_popup() -> void:
	if not is_instance_valid(_navigation) or not is_node_ready():
		return
	var button: Rect2 = _navigation.button_rect(_category_index)
	var button_center: Vector2 = button.get_center() - global_position
	var bottom: float = button.position.y - global_position.y - BUTTON_GAP
	var content_width: float = popup_width
	if _hand.visible_card_count() <= 1:
		content_width = 760.0 if _detail.visible else 580.0
	var width: float = minf(content_width, size.x - EDGE_MARGIN * 2.0)
	var content_height: float = 140.0 if _hand.visible_card_count() == 0 else popup_height
	var height: float = minf(content_height, bottom - EDGE_MARGIN)
	width = maxf(width, _tray.get_combined_minimum_size().x)
	height = maxf(height, _tray.get_combined_minimum_size().y)
	var left: float = clampf(
		button_center.x - width * 0.5, EDGE_MARGIN, maxf(EDGE_MARGIN, size.x - width - EDGE_MARGIN)
	)
	_tray.position = Vector2(left, bottom - height)
	_tray.size = Vector2(width, height)
	_hand.call_deferred("reveal_selected")
	_connector.polygon = PackedVector2Array([
		Vector2(button_center.x - 12.0, bottom - 1.0),
		Vector2(button_center.x + 12.0, bottom - 1.0),
		Vector2(button_center.x, bottom + 14.0)
	])
