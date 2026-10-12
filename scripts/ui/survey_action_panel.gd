class_name SurveyActionPanel
extends PanelContainer
## 地图边缘的勘探确认框；不挡营地中心，不修改目标或费用。

signal execute_requested
signal closed

var _selected_uid: int = -1

@onready var _close: Button = $Content/Heading/CloseButton
@onready var _execute: Button = $Content/ExecuteButton
@onready var _hint: Label = $Content/Hint
@onready var _costs: CardCostStrip = $Content/Costs


func _ready() -> void:
	_close.pressed.connect(close_panel)
	_execute.pressed.connect(execute_requested.emit)
	hide()


func open_selection(uid: int) -> void:
	_selected_uid = uid
	show()


func close_panel() -> bool:
	if not visible:
		return false
	hide()
	closed.emit()
	return true


func update_view(state: VillageState, uid: int) -> void:
	var card: CardDefinition = state.find_card(uid)
	if not SurvivalRules.is_survey(card) or state.phase != GameTypes.Phase.DAY:
		hide()
		return
	_selected_uid = uid
	var error: String = state.can_play(uid)
	_execute.disabled = not error.is_empty()
	if not error.is_empty():
		_hint.text = error
	else:
		var cell: Vector2i = TerrainGrid.position(state.progress.exploration_target)
		_hint.text = "目标 (%d, %d) · 离营地 %d 格" % [cell.x, cell.y, TerrainGrid.distance(cell)]
	_costs.update_view(card, state)
