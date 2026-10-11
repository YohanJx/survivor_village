class_name VillageGameOverlay
extends ColorRect
## 弹窗的固定布局来自场景，奖励选项按数据实例化；写入操作由上层执行。

signal reward_requested(index: int)
signal event_requested(index: int)
signal restart_requested
signal modal_changed

enum Mode {
	NONE,
	HELP,
	NEW_RUN,
	VILLAGE,
	CARD,
}

const REWARD_CARD_SCENE: PackedScene = preload("res://scenes/ui/reward_card.tscn")

var _state: VillageState
var _mode: Mode = Mode.NONE
var _offers: Array[CardDefinition] = []
var _inspection_uid: int = -1
var _inspection_progress: VillageProgress

@onready var _event: VBoxContainer = %EventContent
@onready var _panel: PanelContainer = $Center/Panel
@onready var _inspection: CardInspectionPanel = %CardInspection

@onready var _village_info: VillageInfoPanel = %VillageInfo
@onready var _help: VBoxContainer = %HelpContent
@onready var _new_run: VBoxContainer = %NewRunContent
@onready var _reward: VBoxContainer = %RewardContent
@onready var _game_over: VBoxContainer = %GameOverContent
@onready var _summary: Label = %RewardSummary
@onready var _game_over_summary: Label = %GameOverSummary
@onready var _reward_row: HBoxContainer = %RewardRow


func _ready() -> void:
	(%EventAccept as Button).pressed.connect(_on_event_accept)
	(%EventDecline as Button).pressed.connect(_on_event_decline)
	(_village_info.get_node("%VillageClose") as Button).pressed.connect(close_modal)
	(%HelpClose as Button).pressed.connect(close_modal)
	(%NewRunCancel as Button).pressed.connect(close_modal)
	(%NewRunConfirm as Button).pressed.connect(_on_restart_pressed)
	(%GameOverRestart as Button).pressed.connect(_on_restart_pressed)
	_inspection.close_requested.connect(close_modal)


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


func _on_restart_pressed() -> void:
	close_modal()
	restart_requested.emit()


func _on_reward_selected(index: int) -> void:
	reward_requested.emit(index)


func _refresh_overlay() -> void:
	if _state == null:
		return
	_inspection.visible = _mode == Mode.CARD
	if _inspection.visible:
		_inspection.update_view(_state, _inspection_uid)
	_village_info.visible = _mode == Mode.VILLAGE
	if _village_info.visible:
		_village_info.update_view(_state)
	_help.visible = _mode == Mode.HELP
	_new_run.visible = _mode == Mode.NEW_RUN
	_reward.visible = _mode == Mode.NONE and _state.phase == GameTypes.Phase.REWARD
	_game_over.visible = _mode == Mode.NONE and _state.phase == GameTypes.Phase.GAME_OVER
	_event.visible = (
		_mode == Mode.NONE
		and _state.phase == GameTypes.Phase.DAY
		and _state.progress.event_choice < 0
	)
	if _event.visible:
		_refresh_event()
	visible = (
		_event.visible
		or _inspection.visible
		or _village_info.visible
		or _help.visible
		or _new_run.visible
		or _reward.visible
		or _game_over.visible
	)
	if _reward.visible:
		_summary.text = (
			"守住第 %d 夜  /  击退 %d  /  幸存 %d 人  /  村庄耐久 %d"
			% [
				_state.day,
				_state.last_report.kills,
				_state.population,
				_state.core_health,
			]
		)
		_refresh_rewards()
	if _game_over.visible:
		_game_over_summary.text = (
			"生存 %d 天  ·  总击退 %d  ·  种子 %d"
			% [
				_state.day,
				_state.total_kills,
				_state.run_seed,
			]
		)


func _refresh_rewards() -> void:
	if _offers == _state.rewards:
		return
	for child: Node in _reward_row.get_children():
		_reward_row.remove_child(child)
		child.queue_free()
	_offers = _state.rewards.duplicate()
	for index: int in _offers.size():
		var view: VillageRewardCard = REWARD_CARD_SCENE.instantiate() as VillageRewardCard
		_reward_row.add_child(view)
		view.update_view(_offers[index], _state, index)
		view.selected.connect(_on_reward_selected)


func selected_region() -> GameTypes.Region:
	return (%MapChoice as OptionButton).get_selected_id() as GameTypes.Region


func _on_event_accept() -> void:
	event_requested.emit(0)


func _on_event_decline() -> void:
	event_requested.emit(1)


func _refresh_event() -> void:
	var event: DailyEvent = LaborRules.event_for(_state)
	(%EventTitle as Label).text = "第 %d 日 · %s" % [_state.day, event.display_name]
	(%EventText as Label).text = (
		event.description
		+ "\n\n① "
		+ event.options[0].description
		+ "\n\n② "
		+ event.options[1].description
	)
	for index: int in 2:
		var button: Button = %EventAccept if index == 0 else %EventDecline
		var option: CardDefinition = event.options[index]
		button.text = option.display_name + " · " + _state.catalog.cost_text(option, _state)
		var costs: PackedInt32Array = EffectResolver.cost_totals(option, _state)
		var deltas: PackedInt32Array = EffectResolver.resource_deltas(_state, option)
		button.disabled = false
		for key: int in GameTypes.Stock.COUNT:
			if _state.resources[key] < costs[key] or _state.resources[key] + deltas[key] < 0:
				button.disabled = true
		if button.disabled:
			button.text += "（补给不足）"
