extends SceneTree
## 实例化真实主场景，驱动按钮和引擎输入；隔离全部自动及手动存档。

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const UI_SAVE_PATH: String = "res://test-results/ui_roundtrip.tres"

var _game: VillageGame
var _dashboard: VillageDashboard
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 960)
	_game = MAIN_SCENE.instantiate() as VillageGame
	_game.state.persistence_enabled = false
	_game.state.save_path = UI_SAVE_PATH
	root.add_child(_game)
	_dashboard = _game.get_node("Dashboard") as VillageDashboard
	await PlayerFeedbackUiRegression.run(self, root, _game, _check)
	_test_font_settings()
	await SurvivalUiRegression.run(self, _game, _check, _capture)
	await ProgressionUiRegression.run(self, _game, _check, _capture)
	_game.state.new_run(12345)
	SurvivalTestSetup.developed(_game.state)
	_game.state.changed.emit()
	await WeatherUiRegression.run(self, _game, _check, _capture)
	await _test_tradeoffs()
	_game.state.new_run(12345)
	SurvivalTestSetup.developed(_game.state)
	_game.state.changed.emit()
	await _test_window_layouts()
	root.size = Vector2i(1440, 960)
	await process_frame
	await process_frame
	await _capture("ui_day")
	var map_tests: MapInteractionTests = MapInteractionTests.new()
	await map_tests.run(self, _dashboard, _check, _capture)
	await CompactHudUiRegression.run(self, root, _game, _check)
	await CardCategoryUiRegression.run(self, root, _game, _check)
	await CardUiRegression.run(self, _dashboard, _check, _capture)
	await CardInspectionUiRegression.run(self, _game, _check, _capture)
	await CardAcquisitionUiRegression.run(self, _game, _check)
	await MixedCardCostsUiRegression.run(self, _game, _check)
	_check(_game.state.phase == GameTypes.Phase.DAY, "Main scene starts in day phase")
	_check(
		(
			_dashboard.hand_panel.get_node("%HandContainer").get_child_count()
			== _game.state.hand.size()
		),
		"Starting hand shown"
	)
	var card_view: VillageCardButton = _card_view("wall")
	card_view.pressed.emit()
	_check(
		(_dashboard.detail.get_node("%CardTitle") as Label).text == "木栅栏图纸",
		"Mouse selection updates detail"
	)
	var preserved_id: int = card_view.get_instance_id()
	_game.state.add_resource(GameTypes.Stock.FOOD, 1)
	_game.state.changed.emit()
	_check(_card_view("wall").get_instance_id() == preserved_id, "Stock update retains card nodes")
	await _capture("ui_card_detail")
	await _key(KEY_ENTER)
	_check(
		_game.state.slot == 1 and _game.state.buildings[GameTypes.Building.WALL] == 1,
		"Enter executes selected card"
	)
	_check(
		(_dashboard.detail.get_node("%EmptyHint") as Label).visible,
		"Consumed selection clears detail"
	)
	(_dashboard.get_node("%SaveButton") as Button).pressed.emit()
	_check(FileAccess.file_exists(UI_SAVE_PATH), "Manual save uses isolated test destination")
	_dashboard.skip_requested.emit()
	_check(_game.state.slot == 2, "Skip advances one slot")
	(_dashboard.get_node("%LoadButton") as Button).pressed.emit()
	_check(_game.state.slot == 1, "Load restores displayed slot")
	(_dashboard.get_node("%VillageInfoButton") as Button).pressed.emit()
	_check(
		(
			_dashboard.overlay.visible
			and (_dashboard.overlay.get_node("%VillageInfo") as Control).visible
		),
		"Independent village window displays derivations"
	)
	await _capture("ui_village_information")
	_dashboard.overlay.close_modal()
	await _key(KEY_ENTER, true)
	_check(_game.state.slot == 1, "Repeated key echoes cannot execute another decision")
	_game.state.resources[GameTypes.Stock.MATERIALS] = 0
	_game.state.changed.emit()
	_card_view("bows").pressed.emit()
	_check(
		(_dashboard.detail.get_node("%ExecuteButton") as Button).disabled,
		"Unaffordable card disables execute"
	)
	await _key(KEY_ENTER)
	_check(_game.state.slot == 1, "Disabled keyboard action does not advance the day")
	_game.state.resources[GameTypes.Stock.MATERIALS] = 30
	_game.state.changed.emit()
	await CardUiRegression.click(self, _dashboard.detail.get_node("%ExecuteButton") as Button)
	_card_view("forage").pressed.emit()
	# 驻守改善后可能无伤且无普通事件；显式满足争执条件以验证事件交互。
	_game.state.progress.frustration = 2
	await _key(KEY_ENTER)
	_check(
		_game.state.phase == GameTypes.Phase.NIGHT and _game.battle.active,
		"Third decision starts automatic battle"
	)
	(_dashboard.get_node("%SpeedButton") as Button).grab_focus()
	await _key(KEY_SPACE)
	var paused_at: float = _game.battle.elapsed
	await create_timer(0.1).timeout
	_check(is_equal_approx(_game.battle.elapsed, paused_at), "Space pauses the simulation")
	await _key(KEY_SPACE, true)
	_check(is_equal_approx(_game.battle.elapsed, paused_at), "Repeated Space cannot resume focused-button playback")
	_dashboard.speed_requested.emit()
	_check(
		(_dashboard.get_node("%SpeedButton") as Button).text == "2×", "Speed control cycles to 2x"
	)
	_dashboard.speed_requested.emit()
	_check(
		(_dashboard.get_node("%SpeedButton") as Button).text == "4×", "Speed control cycles to 4x"
	)
	await _key(KEY_SPACE)
	_dashboard.help_requested.emit()
	_check(
		_dashboard.overlay.visible and _dashboard.overlay.blocks_simulation(),
		"Help modal blocks simulation"
	)
	var help_at: float = _game.battle.elapsed
	await create_timer(0.1).timeout
	_check(is_equal_approx(_game.battle.elapsed, help_at), "Help does not advance combat")
	await _capture("ui_help")
	await _key(KEY_ESCAPE)
	_check(not _dashboard.overlay.visible, "Esc closes the help modal")
	await _capture("ui_night")
	await _key(KEY_SPACE)
	_check(
		(_dashboard.get_node("%PauseButton") as Button).text == "继续",
		"Space pauses after help closes"
	)
	await _key(KEY_SPACE)
	_check((_dashboard.get_node("%PauseButton") as Button).text == "暂停", "Space resumes combat")
	_game.set_process(false)
	for tick: int in 5401:
		if not _game.battle.active:
			break
		_game.battle.step(BattleSimulation.FIXED_STEP_SECONDS)
	await process_frame
	_check(
		_game.state.phase == GameTypes.Phase.DAY_END and _dashboard.overlay.visible,
		"Victory opens day-end event modal"
	)
	var row: HBoxContainer = _dashboard.overlay.get_node("%DayEndRow") as HBoxContainer
	_check(row.get_child_count() == 2, "Two tradeoff event options rendered")
	await _capture("ui_day_end_event")
	var hand_size: int = _game.state.hand.size()
	var event_button: Button
	for child: Node in row.get_children():
		var button: Button = child.get_node("%SelectButton") as Button
		if not button.disabled:
			event_button = button
			break
	_check(event_button != null, "Ordinary closing event has an available choice")
	if event_button != null:
		await CardUiRegression.click(self, event_button)
	_check(
		_game.state.day == 3 and _game.state.hand.size() == hand_size,
		"Event click settles dawn without adding a card"
	)
	_check(
		_dashboard.overlay.visible and _game.state.day_report_pending,
		"Dawn shows the completed day report after the event closes"
	)
	(_dashboard.overlay.get_node("%DayReportPanel/ContinueButton") as Button).pressed.emit()
	_check(not _dashboard.overlay.visible, "Day report confirmation returns to the map")
	_dashboard.new_run_requested.emit()
	_check(_dashboard.overlay.visible, "New village asks through its modal")
	(_dashboard.overlay.get_node("%NewRunCancel") as Button).pressed.emit()
	_check(_game.state.day == 3 and not _dashboard.overlay.visible, "Cancel keeps current progress")
	root.size = Vector2i(1100, 760)
	await process_frame
	await _capture("ui_small_window")
	_check(
		_dashboard.hand_panel.get_global_rect().end.y <= _game.size.y, "Hand fits smaller viewport"
	)
	_check(
		_dashboard.detail.get_global_rect().end.x <= _game.size.x, "Detail fits smaller viewport"
	)
	_game.set_process(true)
	await DayEndEventUiRegression.run(self, _game, _check, _capture)
	print(
		(
			"UI TEST RESULT: %d checks, %d failures; renderer=%s"
			% [
				_checks,
				_failures,
				DisplayServer.get_name(),
			]
		)
	)
	if "--keep-open" not in OS.get_cmdline_user_args():
		_game.queue_free()
		await process_frame
		quit(0 if _failures == 0 else 1)


func _key(code: Key, is_echo: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = is_echo
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _test_tradeoffs() -> void:
	var scroll: ScrollContainer = _dashboard.hand_panel.get_node("HandScroll") as ScrollContainer
	var preview: Label = _dashboard.detail.get_node("%Preview") as Label
	var negative: RichTextLabel = _dashboard.detail.get_node("%Negative") as RichTextLabel
	var execute: Button = _dashboard.detail.get_node("%ExecuteButton") as Button
	for id: String in ["forced_march", "emergency_rations"]:
		var card: VillageCardButton = _card_view(id)
		scroll.ensure_control_visible(card)
		await process_frame
		await CardUiRegression.click(self, card)
		_check(negative.text.contains("2"), "Tradeoff duration visible before confirmation: " + id)
		_check(
			preview.text.contains("烦躁" if id == "forced_march" else "生命"),
			"Tradeoff negative stat appears in preview: " + id
		)
		_check(not execute.disabled, "Starting tradeoff can be confirmed: " + id)
		_check(
			(
				negative.get_parent() != _dashboard.detail.get_node("%CardDetail")
				and negative.get_global_rect().end.y <= execute.get_global_rect().position.y
			),
			"Tradeoff risk remains fixed above confirmation: " + id
		)
		await _capture("ui_tradeoff_" + id)
	var water_before: int = _game.state.resources[GameTypes.Stock.WATER]
	await CardUiRegression.click(self, execute)
	_check(
		(
			_game.state.resources[GameTypes.Stock.WATER] == water_before - 6
			and _game.state.modifiers.size() == 1
		),
		"Mouse confirmation applies rations cost and penalty"
	)
	_game.state.add_card(_game.state.catalog.get_card("lure"))
	_game.state.changed.emit()
	_card_view("lure").pressed.emit()
	_check(preview.text.contains("尸群规模"), "Larger wave shown in decision preview")
	await _capture("ui_tradeoff_lure")
	scroll.scroll_horizontal = 0
	await process_frame


func _card_view(id: String) -> VillageCardButton:
	var container: HBoxContainer = _dashboard.hand_panel.get_node("%HandContainer") as HBoxContainer
	for view: VillageCardButton in container.get_children():
		if view.card.id == id:
			return view
	return null


func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	# macOS 遮挡窗口时不发 frame_post_draw；强制真实渲染避免截图永久等待。
	await process_frame
	RenderingServer.force_draw()
	var screenshot: Image = root.get_texture().get_image()
	var error: Error = screenshot.save_png("res://test-results/" + name + ".png")
	_check(error == OK, "Rendered capture saved: " + name)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("UI FAIL: " + message)


func _test_font_settings() -> void:
	var font: Font = _dashboard.get_theme_default_font()
	var server: TextServer = TextServerManager.get_primary_interface()
	var weight_tag: int = server.name_to_tag("wght")
	_check(font is FontVariation, "Theme uses an explicit variable font instance")
	# TextServer 返回引擎字典；在边界读取轴值，直接检查实际字体缓存而非资源文本。
	var weight: float = float(
		server.font_get_variation_coordinates(font.get_rids()[0]).get(weight_tag, 0.0)
	)
	_check(is_equal_approx(weight, 400.0), "Rendered font cache uses regular weight 400")


func _test_window_layouts() -> void:
	_check(
		root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND,
		"Window expands content without aspect-ratio black bars"
	)
	var sizes: Array[Vector2i] = [
		Vector2i(1320, 880),
		Vector2i(1440, 900),
		Vector2i(1600, 900),
		Vector2i(1920, 820),
		Vector2i(1024, 768),
	]
	var background: ColorRect = _dashboard.get_node("Background") as ColorRect
	var header: Control = _dashboard.get_node("Margin/Layout/Header") as Control
	var footer: Control = _dashboard.get_node("Margin/Layout/Footer") as Control
	for window_size: Vector2i in sizes:
		root.size = window_size
		# Container 的最小尺寸与换行布局需要跨帧完成重排。
		await process_frame
		await process_frame
		await process_frame
		var label: String = "%d×%d" % [window_size.x, window_size.y]
		_check(
			background.get_global_rect().is_equal_approx(_game.get_global_rect()),
			"Background fills root: " + label
		)
		_check(
			_dashboard.overlay.get_global_rect().is_equal_approx(_game.get_global_rect()),
			"Modal anchors fill root: " + label
		)
		_check(
			(
				header.get_global_rect().position.y >= 0.0
				and footer.get_global_rect().end.y <= _game.size.y + 1.0
			),
			"Header and footer remain inside viewport: " + label
		)
		_check(
			_dashboard.detail.get_global_rect().end.x <= _game.size.x + 1.0,
			"Detail remains inside viewport: " + label
		)
		await _capture("ui_layout_%dx%d" % [window_size.x, window_size.y])
