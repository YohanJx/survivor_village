class_name VillageGameOverlay
extends ColorRect
## 弹窗固定布局来自场景，事件选项按定义实例化；写入操作由上层执行。

signal day_end_requested(index: int)
signal day_end_skip_requested
signal restart_requested
signal modal_changed

enum Mode {
	NONE,
	HELP,
	NEW_RUN,
	VILLAGE,
	CARD,
}

const DAY_END_OPTION_SCENE: PackedScene = preload("res://scenes/ui/day_end_option.tscn")

var _normal_panel_style: StyleBox
var _card_panel_style: StyleBoxEmpty = StyleBoxEmpty.new()

var _state: VillageState
var _mode: Mode = Mode.NONE
var _day_end_id: String = ""
var _inspection_uid: int = -1
var _inspection_progress: VillageProgress

@onready var _panel: PanelContainer = $Center/Panel
@onready var _inspection: CardInspectionPanel = %CardInspection

@onready var _village_info: VillageInfoPanel = %VillageInfo
@onready var _help: VBoxContainer = %HelpContent
@onready var _new_run: VBoxContainer = %NewRunContent
@onready var _day_end: VBoxContainer = %DayEndContent
@onready var _game_over: VBoxContainer = %GameOverContent
@onready var _summary: Label = %DayEndSummary
@onready var _game_over_summary: Label = %GameOverSummary
@onready var _day_end_row: HBoxContainer = %DayEndRow
@onready var _day_end_skip: Button = %DayEndSkip


func _ready() -> void:
	_normal_panel_style = _panel.get_theme_stylebox("panel")
	(_village_info.get_node("%VillageClose") as Button).pressed.connect(close_modal)
	(%HelpClose as Button).pressed.connect(close_modal)
	(%NewRunCancel as Button).pressed.connect(close_modal)
	(%NewRunConfirm as Button).pressed.connect(_on_restart_pressed)
	(%GameOverRestart as Button).pressed.connect(_on_restart_pressed)
	_inspection.close_requested.connect(close_modal)
	_day_end_skip.pressed.connect(day_end_skip_requested.emit)


func _gui_input(event: InputEvent) -> void:
	if _mode != Mode.CARD or not event is InputEventMouseButton:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	var point: Vector2 = get_global_transform_with_canvas() * mouse.position
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		if not _panel.get_global_rect().has_point(point):
			accept_event()
			close_modal()


func update_view(state: VillageState) -> void:
	_state = state
	if (
		_mode == Mode.CARD
		and (_inspection_progress != state.progress or state.find_card(_inspection_uid) == null)
	):
		close_modal()
		return
	_refresh_overlay()


func show_card(uid: int) -> void:
	if visible or _state == null or _state.find_card(uid) == null:
		return
	_inspection_uid = uid
	_inspection_progress = _state.progress
	_mode = Mode.CARD
	_inspection.reset_scroll()
	_refresh_overlay()
	modal_changed.emit()


func show_help() -> void:
	_mode = Mode.HELP
	_refresh_overlay()
	modal_changed.emit()


func show_village() -> void:
	_mode = Mode.VILLAGE
	_refresh_overlay()
	modal_changed.emit()


func request_new_run() -> void:
	_mode = Mode.NEW_RUN
	_refresh_overlay()
	modal_changed.emit()


func close_modal() -> void:
	_mode = Mode.NONE
	_inspection_uid = -1
	_inspection_progress = null
	_refresh_overlay()
	modal_changed.emit()


func blocks_simulation() -> bool:
	return _mode != Mode.NONE


func selected_region() -> GameTypes.Region:
	return (%MapChoice as OptionButton).get_selected_id() as GameTypes.Region


func _on_restart_pressed() -> void:
	close_modal()
	restart_requested.emit()


func _on_day_end_selected(index: int) -> void:
	day_end_requested.emit(index)


func _refresh_overlay() -> void:
	if _state == null:
		return
	_panel.custom_minimum_size.x = 320 if _mode == Mode.CARD else 790
	_panel.add_theme_stylebox_override(
		"panel", _card_panel_style if _mode == Mode.CARD else _normal_panel_style
	)
	_inspection.visible = _mode == Mode.CARD
	if _inspection.visible:
		_inspection.update_view(_state, _inspection_uid)
	_village_info.visible = _mode == Mode.VILLAGE
	if _village_info.visible:
		_village_info.update_view(_state)
	_help.visible = _mode == Mode.HELP
	_new_run.visible = _mode == Mode.NEW_RUN
	_day_end.visible = _mode == Mode.NONE and _state.phase == GameTypes.Phase.DAY_END
	_game_over.visible = _mode == Mode.NONE and _state.phase == GameTypes.Phase.GAME_OVER
	visible = (
		_inspection.visible
		or _village_info.visible
		or _help.visible
		or _new_run.visible
		or _day_end.visible
		or _game_over.visible
	)
	if _day_end.visible:
		_summary.text = (
			"守住第 %d 夜  /  击退 %d  /  幸存 %d 人  /  村庄耐久 %d"
			% [
				_state.day,
				_state.last_report.kills,
				_state.population,
				_state.core_health,
			]
		)
		_refresh_day_end()
	if _game_over.visible:
		_game_over_summary.text = (
			"生存 %d 天  ·  总击退 %d  ·  种子 %d"
			% [
				_state.day,
				_state.total_kills,
				_state.run_seed,
			]
		)


func _refresh_day_end() -> void:
	var event: DailyEvent = _state.current_day_end_event()
	if event == null:
		return
	var period: String = (
		"第 %d 日清晨" % (_state.day + 1) if _state.day_end_settled else "第 %d 夜之后" % _state.day
	)
	(%DayEndTitle as Label).text = (
		"%s · %s · 剩余 %d 项" % [period, event.display_name, _state.pending_day_end_events.size() + 1]
	)
	(%DayEndHint as Label).text = event.description
	(%DawnHint as Label).text = (
		"口粮已结算。处理剩余后果后开始今日行动；恢复稳定供应才能结束连续短缺。药品只能缓解症状。"
		if _state.day_end_settled
		else "选择或忽略遭遇后统一结算当日产出与口粮；补给不足将继续处理清晨后果。新效果从下一夜生效。"
	)
	_day_end_skip.visible = event.skippable
	if _day_end_id != event.id:
		for child: Node in _day_end_row.get_children():
			_day_end_row.remove_child(child)
			child.queue_free()
		_day_end_id = event.id
		for index: int in event.options.size():
			var view: DayEndOptionView = DAY_END_OPTION_SCENE.instantiate() as DayEndOptionView
			_day_end_row.add_child(view)
			view.selected.connect(_on_day_end_selected)
	for index: int in event.options.size():
		var view: DayEndOptionView = _day_end_row.get_child(index) as DayEndOptionView
		view.update_view(event.options[index], _state, index)
