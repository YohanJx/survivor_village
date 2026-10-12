class_name VillageGame
extends Control
## 当局入口：注入依赖、协调用户请求和固定步长战斗。布局及展示由 UI 场景负责。

const HUD_INTERVAL_SECONDS: float = 0.2
const MAX_STEPS_PER_FRAME: int = 12

var state: VillageState = VillageState.new()
var battle: BattleSimulation = BattleSimulation.new()
var _selected_uid: int = -1
var _speed: float = 1.0
var _paused: bool = false
var _accumulator: float = 0.0
var _hud_timer: float = 0.0

@onready var _dashboard: VillageDashboard = $Dashboard


func _ready() -> void:
	if not state.catalog.is_valid:
		_dashboard.notify("无法开始游戏：" + state.catalog.validation_error)
		set_process(false)
		return
	_dashboard.bind(state, battle)
	_dashboard.exploration_requested.connect(_on_exploration_requested)
	_dashboard.card_selected.connect(_on_card_selected)
	_dashboard.execute_requested.connect(_on_execute_pressed)
	_dashboard.skip_requested.connect(_on_skip_pressed)
	_dashboard.pause_requested.connect(_on_pause_pressed)
	_dashboard.speed_requested.connect(_on_speed_pressed)
	_dashboard.save_requested.connect(_on_save_pressed)
	_dashboard.load_requested.connect(_on_load_pressed)
	_dashboard.new_run_requested.connect(_dashboard.overlay.request_new_run)
	_dashboard.help_requested.connect(_dashboard.overlay.show_help)
	_dashboard.overlay.day_end_requested.connect(_on_day_end_selected)
	_dashboard.overlay.day_end_skip_requested.connect(_on_day_end_skip_requested)
	_dashboard.overlay.day_report_continue_requested.connect(state.acknowledge_day_report)
	_dashboard.overlay.restart_requested.connect(_on_restart_pressed)
	_dashboard.overlay.modal_changed.connect(_on_modal_changed)
	(_dashboard.overlay.get_node("%VillageInfo") as VillageInfoPanel).jobs_requested.connect(
		_on_jobs_requested
	)
	(_dashboard.overlay.get_node("%VillageInfo") as VillageInfoPanel).crew_requested.connect(
		_on_crew_requested
	)
	state.changed.connect(_on_state_changed)
	state.cards_acquired.connect(_on_cards_acquired)
	state.phase_changed.connect(_on_phase_changed)
	state.persistence_failed.connect(_on_persistence_failed)
	battle.finished.connect(state.finish_night)
	# 启动展示新局不会自动覆盖旧存档。
	state.new_run(0, GameTypes.Region.RURAL)


func _process(delta: float) -> void:
	if battle.active and not _paused and not _dashboard.overlay.blocks_simulation():
		_accumulator += minf(delta, 0.1) * _speed
		var steps: int = 0
		while _accumulator >= BattleSimulation.FIXED_STEP_SECONDS and battle.active:
			battle.step(BattleSimulation.FIXED_STEP_SECONDS)
			_accumulator -= BattleSimulation.FIXED_STEP_SECONDS
			steps += 1
			if steps >= MAX_STEPS_PER_FRAME:
				# 丢弃慢帧积压，不放大模拟步长或无限追赶。
				_accumulator = 0.0
				break
	if state.phase == GameTypes.Phase.NIGHT:
		_hud_timer += delta
		if _hud_timer >= HUD_INTERVAL_SECONDS:
			_hud_timer = 0.0
			_dashboard.update_resources(state, battle)
			_dashboard.update_playback(state, battle, _paused, _speed)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not state.catalog.is_valid:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if event.is_action(&"ui_cancel"):
		# 原生筛选菜单优先消费 Esc，不同时关闭背后的面板。
		if focused is OptionButton and (focused as OptionButton).get_popup().visible:
			return
		if event.is_echo():
			get_viewport().set_input_as_handled()
		elif event.is_pressed() and _dashboard.dismiss_top_layer():
			get_viewport().set_input_as_handled()
		return
	if _dashboard.overlay.visible or focused is OptionButton:
		return
	if event.is_action(&"execute_card"):
		get_viewport().set_input_as_handled()
		if event.is_action_pressed(&"execute_card") and not event.is_echo():
			_on_execute_pressed()
	elif event.is_action(&"pause_battle"):
		get_viewport().set_input_as_handled()
		if event.is_action_pressed(&"pause_battle") and not event.is_echo():
			_on_pause_pressed()


func _on_state_changed() -> void:
	if state.find_card(_selected_uid) == null:
		_selected_uid = -1
	_dashboard.update_view(state, battle, _selected_uid)
	_dashboard.update_playback(state, battle, _paused, _speed)


func _on_phase_changed(phase: GameTypes.Phase) -> void:
	_paused = false
	_accumulator = 0.0
	if phase == GameTypes.Phase.NIGHT:
		battle.start(state)
	else:
		battle.active = false


func _on_card_selected(uid: int) -> void:
	if _dashboard.overlay.visible:
		return
	_selected_uid = uid
	if uid >= 0:
		_dashboard.prepare_card_selection(state, uid)
	_dashboard.hand_panel.update_view(state, uid, false)
	_dashboard.update_view(state, battle, uid)
	_dashboard.detail.update_view(state, uid, true)


func _on_execute_pressed() -> void:
	if not _dashboard.has_visible_confirmation():
		return
	if _dashboard.overlay.visible or state.phase != GameTypes.Phase.DAY or _selected_uid < 0:
		return
	if state.play_card(_selected_uid):
		_notify_result(state.last_card_result)
	else:
		_dashboard.notify(state.can_play(_selected_uid))


func _on_skip_pressed() -> void:
	if _dashboard.overlay.visible or state.phase != GameTypes.Phase.DAY:
		return
	state.skip_slot()
	_notify_result("待命恢复体力，消耗一次行动。")


func _on_pause_pressed() -> void:
	if state.phase != GameTypes.Phase.NIGHT or _dashboard.overlay.blocks_simulation():
		return
	_paused = not _paused
	_dashboard.update_playback(state, battle, _paused, _speed)


func _on_speed_pressed() -> void:
	_speed = 2.0 if _speed == 1.0 else 4.0 if _speed == 2.0 else 1.0
	_dashboard.update_playback(state, battle, _paused, _speed)


func _on_modal_changed() -> void:
	if not state.catalog.is_valid:
		return
	_dashboard.hand_panel.update_view(state, _selected_uid, _dashboard.overlay.blocks_simulation())


func _on_day_end_selected(index: int) -> void:
	if state.choose_day_end_event(index):
		_selected_uid = -1
	else:
		_dashboard.notify(state.last_error)


func _on_day_end_skip_requested() -> void:
	if state.skip_day_end_event():
		_selected_uid = -1


func _on_restart_pressed() -> void:
	_selected_uid = -1
	_speed = 1.0
	state.new_run(0, _dashboard.overlay.selected_region())
	state.autosave()
	_notify_result("新的火光亮起。选择村庄的第一步。")


func _on_save_pressed() -> void:
	if state.phase == GameTypes.Phase.NIGHT:
		return
	if state.save_game():
		_dashboard.notify("进度已保存。")
	else:
		_dashboard.notify(state.last_error)


func _on_load_pressed() -> void:
	# 失败时保留原来的选中状态、弹窗和战斗。
	if state.load_game():
		_selected_uid = -1
		_dashboard.overlay.close_modal()
		_on_state_changed()
		_dashboard.notify("已恢复进度。" + ("夜战从黄昏重新开始。" if state.phase == GameTypes.Phase.NIGHT else ""))
	else:
		_dashboard.notify(state.last_error)


func _on_persistence_failed(message: String) -> void:
	_dashboard.notify("自动保存失败：" + message)


func _notify_result(message: String) -> void:
	var result: String = message
	if not state.last_error.is_empty():
		result += "\n自动保存失败：" + state.last_error
	_dashboard.notify(result)


func _on_jobs_requested(counts: PackedInt32Array, archers: bool) -> void:
	if not state.assign_jobs(counts, archers):
		_dashboard.notify("分工总数必须等于人口，且仅能在每日第一次行动前调整一次。")


func _on_crew_requested(size: int) -> void:
	state.set_crew(size)


func _on_exploration_requested(cell: Vector2i) -> void:
	if _dashboard.overlay.visible:
		return
	if not state.select_exploration(cell):
		return
	for entry: CardInstance in state.hand:
		if SurvivalRules.is_survey(entry.definition):
			_selected_uid = entry.uid
			_on_state_changed()
			break


func _on_cards_acquired(uids: PackedInt32Array) -> void:
	_dashboard.show_acquired_cards(state, uids)
