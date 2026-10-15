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
	if not SurvivalRules.is_map_survey(card) or state.phase != GameTypes.Phase.DAY:
		hide()
		return
	_selected_uid = uid
	var well_survey: bool = WellRules.is_survey(card)
	($Content/Heading/Title as Label).text = (
		"井位勘探 · 选择已探索草甸" if well_survey else "勘探 · 在地图选择目标"
	)
	_execute.text = "确认井位勘探" if well_survey else "确认勘探"
	var error: String = state.can_play(uid)
	_execute.disabled = not error.is_empty()
	if not error.is_empty():
		_hint.text = error
	else:
		var target: int = state.progress.well_target if well_survey else state.progress.exploration_target
		var cell: Vector2i = TerrainGrid.position(target)
		_hint.text = "目标 (%d, %d) · 离营地 %d 格" % [cell.x, cell.y, TerrainGrid.distance(cell)]
	if well_survey and error.is_empty():
		_hint.text += "\n尚未确认有水；此位置仅可打井一次。"
	_costs.update_view(card, state)
