class_name VillageDashboard
extends Control
## 固定 HUD 的展示与输入转发；状态与战斗由入口注入。

signal exploration_requested(cell: Vector2i)
signal well_site_requested(cell: Vector2i)

signal card_selected(uid: int)
signal execute_requested
signal skip_requested
signal pause_requested
signal speed_requested
signal save_requested
signal load_requested
signal new_run_requested
signal help_requested

var _category_index: int = 0

var _resource_labels: Array[Label] = []
var _notification_progress: VillageProgress

@onready var detail: VillageDetailPanel = %DetailPanel
@onready var hand_panel: VillageHandPanel = %HandPanel
@onready var overlay: VillageGameOverlay = %GameOverlay

@onready var _survey_action: SurveyActionPanel = %SurveyActionPanel
@onready var _result_notice: ActionResultNotice = %ActionResultNotice

@onready var _header_menu: HudMenu = %HeaderMenu
@onready var _map_hud: MapHudLayout = $Margin/Layout/ActionSplit/CenterRow/MapColumn

@onready var _categories: CardCategoryBar = %CardCategoryBar
@onready var _action_dock: ActionDock = %ActionSplit

@onready var _card_acquisition: CardAcquisitionNotice = %CardAcquisition
@onready var _village_map: VillageMap = %VillageMap
@onready var _day_label: Label = %DayLabel
@onready var _phase_label: Label = %PhaseLabel
@onready var _population_label: Label = %PopulationLabel
@onready var _core_label: Label = %CoreLabel
@onready var _risk_label: Label = %RiskLabel
@onready var _map_title: Label = %MapTitle
@onready var _map_hint: Label = %MapHint
@onready var _status_label: Label = %StatusLabel
@onready var _exploration_clues: Label = %ExplorationClues
@onready var _notification: Label = %Notification
@onready var _pause_button: Button = %PauseButton
@onready var _speed_button: Button = %SpeedButton
@onready var _save_button: Button = %SaveButton
@onready var _background: ColorRect = $Background
@onready var _material_caption: Label = %MaterialsCaption
@onready var _weather_label: Label = %WeatherLabel


func _ready() -> void:
	_survey_action.execute_requested.connect(execute_requested.emit)
	_survey_action.closed.connect(_on_survey_closed)
	(%InventoryButton as Button).pressed.connect(overlay.show_inventory)
	var stock_buttons: Array[Button] = [%Stock0Button, %Stock1Button, %Stock2Button, %Stock3Button, %Stock4Button]
	for key: int in stock_buttons.size():
		stock_buttons[key].pressed.connect(_on_inventory_pressed.bind(key))
	_header_menu.bind_button(%MenuButton)
	_map_hud.bind_toggle(%MapDetailsButton)
	hand_panel.bind_controls(%HandTitle, %KeywordFilter, %SkipButton)
	_action_dock.bind_navigation(_categories)
	_action_dock.set_category(0)
	_categories.category_requested.connect(_on_category_requested)
	_action_dock.expanded_changed.connect(_on_cards_expanded_changed)
	_resource_labels = [%Stock0, %Stock1, %Stock2, %Stock3, %Stock4]
	(%ProgressLine as Button).pressed.connect(overlay.show_village)
	_card_acquisition.inspect_requested.connect(overlay.show_card)
	hand_panel.card_selected.connect(card_selected.emit)
	hand_panel.inspect_requested.connect(overlay.show_card)
	hand_panel.skip_requested.connect(skip_requested.emit)
	detail.execute_requested.connect(execute_requested.emit)
	_pause_button.pressed.connect(pause_requested.emit)
	_speed_button.pressed.connect(speed_requested.emit)
	_save_button.pressed.connect(save_requested.emit)
	(%LoadButton as Button).pressed.connect(load_requested.emit)
	(%NewRunButton as Button).pressed.connect(new_run_requested.emit)
	(%VillageInfoButton as Button).pressed.connect(overlay.show_village)
	(%HelpButton as Button).pressed.connect(help_requested.emit)
	(%MapFocusButton as Button).pressed.connect(_village_map.focus_village)
	(%MapFitButton as Button).pressed.connect(_village_map.fit_world)
	(%MapZoomIn as Button).pressed.connect(_village_map.zoom_in)
	(%MapZoomOut as Button).pressed.connect(_village_map.zoom_out)


func bind(state: VillageState, battle: BattleSimulation) -> void:
	_village_map.bind(state, battle)
	_village_map.exploration_requested.connect(exploration_requested.emit)
	_village_map.well_site_requested.connect(well_site_requested.emit)


func update_view(state: VillageState, battle: BattleSimulation, selected_uid: int) -> void:
	if _notification_progress != state.progress:
		_card_acquisition.clear()
		_result_notice.hide()
		_notification.text = "选择一张卡牌，决定村庄的明天。"
		_survey_action.close_panel()
		_category_index = 0
		_action_dock.set_category(0)
		hand_panel.set_category(0)
		_categories.set_selection(0, _action_dock.is_expanded())
		_notification_progress = state.progress
	_village_map.set_exploration_mode(
		(
			state.phase == GameTypes.Phase.DAY
			and (state.day == 1 or SurvivalRules.is_survey(state.find_card(selected_uid)))
		)
	)
	_background.color = state.catalog.library.weather_rules.background_colors[
		state.environment_period()
	]
	_exploration_clues.visible = _village_map.exploration_mode
	if _exploration_clues.visible:
		_exploration_clues.text = (
			"周边线索\n"
			+ "\n".join(
				state.terrain_grid.direction_clues(
					TerrainGrid.position(state.progress.explored_cells[-1]),
					state.progress.explored_cells
				)
			)
		)
	_village_map.set_well_survey_mode(
		state.phase == GameTypes.Phase.DAY and WellRules.is_survey(state.find_card(selected_uid))
	)
	var event: DailyEvent = LaborRules.event_for(state)
	var event_name: String = (
		event.display_name if event != null else (["自主行动", "营地驻守", "遭遇与结算", "本局结束"][state.phase])
	)
	(%ProgressLine as Button).text = (
		"%s · 烦躁 %d/5 · 今日：%s · 木 %d 石 %d 零件 %d 燃料 %d 箭 %d 药 %d"
		% [
			GameTypes.REGION_NAMES[state.progress.region],
			state.progress.frustration,
			event_name,
			state.resources[7],
			state.resources[8],
			state.resources[9],
			state.resources[10],
			state.resources[11],
			state.resources[12]
		]
	)
	if state.progress.scouting:
		var special_names: PackedStringArray = []
		for kind: int in SpecialEnemies.new().types_for(
			ceili(EffectResolver.derive(state).threat_level * 10), state.progress.region
		):
			special_names.append(GameTypes.ENEMY_NAMES[kind])
		(%ProgressLine as Button).text += (
			" · 侦察：" + ("、".join(special_names) if not special_names.is_empty() else "普通尸群")
		)
	_weather_label.text = "天气：" + state.weather.display_name
	_weather_label.tooltip_text = state.weather.description
	var morning_consequences: bool = (
		state.phase == GameTypes.Phase.DAY_END and state.day_end_settled
	)
	_day_label.text = "第 %02d 日" % (state.day + 1 if morning_consequences else state.day)
	_phase_label.text = (
		"清晨 / 补给后果"
		if morning_consequences
		else (
			"夜末 / 遭遇与结算"
			if state.phase == GameTypes.Phase.DAY_END
			else "今晚压力：%d · 探索 / 发展 / 声光" % state.wave_count()
		)
	)
	_day_label.tooltip_text = _phase_label.text
	_map_title.text = (
		"井位勘探 · 选择已探索的草甸"
		if _village_map.well_survey_mode
		else "月下守望  /  自动防守"
		if state.phase == GameTypes.Phase.NIGHT
		else (
			"勘探地图"
			if _village_map.exploration_mode
			else "营地 / " + GameTypes.REGION_NAMES[state.progress.region]
		)
	)
	match state.phase:
		GameTypes.Phase.DAY:
			_map_hint.text = (
				"%s / %d / 3 时段 · 剩余 %d 次"
				% [
					VillageState.SLOT_NAMES[state.slot],
					state.slot + 1,
					state.actions_per_slot - state.actions_used,
				]
			)
			_status_label.text = (
				(
					"●  防线平静  ·  今晚预计 %d 名感染者%s"
					if state.progress.region == GameTypes.Region.LEGACY
					else "●  今晚威胁预算 %d · 特殊敌人折算%s"
				)
				% [
					state.wave_count(),
					"，可能有首领" if EffectResolver.derive(state).boss_possible else "",
				]
			)
			_status_label.tooltip_text = _status_label.text
			_status_label.text = OpeningRules.next_step(state)
			_status_label.add_theme_color_override("font_color", UiElements.POSITIVE)
		GameTypes.Phase.DAY_END:
			_map_hint.text = "夜末  /  遭遇与结算"
		GameTypes.Phase.GAME_OVER:
			_map_hint.text = "防线失守"
	_save_button.disabled = state.phase == GameTypes.Phase.NIGHT
	_pause_button.visible = state.phase == GameTypes.Phase.NIGHT
	_speed_button.visible = state.phase == GameTypes.Phase.NIGHT
	_pause_button.disabled = state.phase != GameTypes.Phase.NIGHT
	_speed_button.disabled = state.phase != GameTypes.Phase.NIGHT
	update_resources(state, battle)
	_categories.update_view(state, overlay.blocks_simulation())
	hand_panel.update_view(state, selected_uid, overlay.blocks_simulation())
	detail.update_view(state, selected_uid)
	_survey_action.update_view(state, selected_uid)
	_categories.set_selection(_category_index, _action_dock.is_expanded() or _survey_action.visible)
	overlay.update_view(state)


func show_acquired_cards(state: VillageState, uids: PackedInt32Array) -> void:
	_card_acquisition.show_cards(state, uids)


func update_resources(state: VillageState, battle: BattleSimulation) -> void:
	for key: int in range(GameTypes.Stock.MATERIALS + 1):
		_resource_labels[key].text = str(state.resources[key])
	_material_caption.text = "材料与装备"
	var materials: PackedStringArray = []
	if state.progress.region == GameTypes.Region.LEGACY:
		materials.append("材料 %d" % state.resources[GameTypes.Stock.MATERIALS])
	for stock: int in range(GameTypes.Stock.WOOD, GameTypes.Stock.COUNT):
		materials.append("%s %d" % [GameTypes.STOCK_NAMES[stock], state.resources[stock]])
	_resource_labels[GameTypes.Stock.MATERIALS].text = "   ·   ".join(materials)
	var balances: Array[ResourceBalance] = EffectResolver.resource_balances(state)
	for stock: int in [GameTypes.Stock.FOOD, GameTypes.Stock.WATER, GameTypes.Stock.POWER]:
		var label: Label = _resource_labels[stock]
		var capacity: int = SurvivalRules.storage_capacity(state, stock as GameTypes.Stock)
		if stock == GameTypes.Stock.POWER:
			label.text = "%d/%d" % [state.resources[stock], capacity]
		else:
			label.text = "%d(%+d)/%d" % [state.resources[stock], balances[stock].net, capacity]
		label.tooltip_text = "当前库存（当日固定生产−消耗）/跨日容量；点击查看生产、消耗和全部材料。"
	_resource_labels[GameTypes.Stock.STAMINA].text += " / 100"
	_population_label.text = str(battle.guards.size() if battle.active else state.population)
	_core_label.text = (
		"%d / %d"
		% [
			battle.core_health if battle.active else state.core_health,
			state.core_max_health,
		]
	)
	_risk_label.text = (
		"%d / %d"
		% [
			state.resources[GameTypes.Stock.NOISE],
			state.resources[GameTypes.Stock.POLLUTION],
		]
	)
	var environment: VillageStats = (
		state.night_stats if state.phase == GameTypes.Phase.NIGHT else EffectResolver.derive(state)
	)
	_risk_label.tooltip_text = (
		"行动噪声 %d + 设施噪声 %d，均影响当晚；黎明清零。污染 %d / %d，地形每日消退 %d。"
		% [
			state.resources[GameTypes.Stock.NOISE],
			environment.income[GameTypes.Stock.NOISE],
			state.resources[GameTypes.Stock.POLLUTION],
			state.catalog.library.progression_rules.night_threat.pollution_cap,
			(
				state
				. catalog
				. library
				. progression_rules
				. map_for(state.progress.region)
				. pollution_recovery
			)
		]
	)


func update_playback(
	state: VillageState, battle: BattleSimulation, paused: bool, speed: float
) -> void:
	_pause_button.text = "继续" if paused else "暂停"
	_speed_button.text = "%d×" % int(speed)
	if state.phase != GameTypes.Phase.NIGHT:
		return
	_map_hint.text = (
		"%.0f 秒  /  击退 %d / %d"
		% [
			battle.elapsed,
			battle.kills,
			battle.total_to_spawn,
		]
	)
	_status_label.text = (
		"%s  %s  ·  入场 %d / %d  ·  场上敌人 %d"
		% [
			"Ⅱ" if paused else "●",
			"已暂停" if paused else "首领来袭" if battle.boss_spawned else "自动防守中",
			battle.spawned,
			battle.total_to_spawn,
			battle.enemies.size(),
		]
	)
	(
		_status_label
		. add_theme_color_override(
			"font_color",
			UiElements.NEGATIVE if battle.boss_spawned else UiElements.EMPHASIS,
		)
	)


func notify(message: String) -> void:
	_notification.text = message.get_slice("\n", 0)
	_result_notice.show_message(message)


## 由入口统一处理 Esc；一次只关闭最上层 UI，保持游戏和卡牌选择不变。
func dismiss_top_layer() -> bool:
	if overlay.visible:
		overlay.close_modal()
		return true
	if _header_menu.close_panel():
		return true
	if _survey_action.close_panel():
		return true
	if _map_hud.close_details():
		return true
	if _action_dock.is_expanded():
		_action_dock.set_expanded(false)
		return true
	return false


## 卡牌选择只改变展示。勘探使用地图角落的确认框，其他卡使用分类浮层。
func prepare_card_selection(state: VillageState, uid: int) -> void:
	if SurvivalRules.is_map_survey(state.find_card(uid)):
		_survey_action.open_selection(uid)
		_action_dock.set_expanded(false)
	else:
		_survey_action.close_panel()
		_action_dock.set_expanded(true)
	_categories.set_selection(_category_index, true)


func has_visible_confirmation() -> bool:
	return _survey_action.is_visible_in_tree() or detail.is_visible_in_tree()


func _on_inventory_pressed(key: int) -> void:
	overlay.show_inventory(key as GameTypes.Stock)


func _on_survey_closed() -> void:
	_categories.set_selection(_category_index, _action_dock.is_expanded())


func _on_category_requested(index: int) -> void:
	var same_category: bool = index == _category_index
	var collapse: bool = same_category and (_action_dock.is_expanded() or _survey_action.visible)
	_category_index = index
	_survey_action.close_panel()
	_action_dock.set_category(index)
	hand_panel.set_category(index)
	if not same_category:
		card_selected.emit(-1)
	_action_dock.set_expanded(not collapse)
	_categories.set_selection(index, not collapse)


func _on_cards_expanded_changed(expanded: bool) -> void:
	_categories.set_selection(_category_index, expanded or _survey_action.visible)
