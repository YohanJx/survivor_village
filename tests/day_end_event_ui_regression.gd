class_name DayEndEventUiRegression
extends RefCounted
## 实际事件窗口、鼠标选择、跳过与小窗口布局；测试不写玩家存档。


static func run(tree: SceneTree, game: VillageGame, check: Callable, capture: Callable) -> void:
	var dashboard: VillageDashboard = game.get_node("Dashboard") as VillageDashboard
	game.set_process(false)
	for size: Vector2i in [Vector2i(1440, 960), Vector2i(1024, 768)]:
		tree.root.size = size
		for event: DailyEvent in game.state.catalog.library.progression_rules.day_end_events:
			_present(game, event.id)
			await tree.process_frame
			await tree.process_frame
			var overlay: VillageGameOverlay = dashboard.overlay
			var row: HBoxContainer = overlay.get_node("%DayEndRow") as HBoxContainer
			var skip: Button = overlay.get_node("%DayEndSkip") as Button
			check.call(
				overlay.visible and row.get_child_count() == 2, "Closing event renders two choices"
			)
			check.call(skip.visible == event.skippable, "Only optional encounters display ignore")
			check.call(
				(overlay.get_node("%DayEndTitle") as Label).text.contains(event.display_name),
				"Closing window names the actual event"
			)
			for index: int in row.get_child_count():
				var view: DayEndOptionView = row.get_child(index) as DayEndOptionView
				var select: Button = view.get_node("%SelectButton") as Button
				var benefit_text: String = (
					(view.get_node("%Positive") as RichTextLabel).get_parsed_text()
				)
				var risk_text: String = (
					(view.get_node("%Negative") as RichTextLabel).get_parsed_text()
				)
				check.call(
					(
						(view.get_node("%Positive") as RichTextLabel).is_visible_in_tree()
						== (not event.options[index].positive.is_empty())
					),
					"Pure consequences hide an absent benefit instead of inventing one"
				)
				check.call(
					(
						(
							benefit_text.is_empty()
							if event.options[index].positive.is_empty()
							else benefit_text.contains(event.options[index].positive)
						)
						and (
							risk_text.is_empty()
							if event.options[index].negative.is_empty()
							else risk_text.contains(event.options[index].negative)
						)
					),
					"Actual event effects are displayed and absent effects remain empty"
				)
				check.call(
					(
						select.disabled
						== (not DayEndEvents.option_error(game.state, index).is_empty())
					),
					"Displayed event availability shares the state query"
				)
				check.call(
					(
						select.get_global_rect().end.y <= game.size.y
						and select.get_global_rect().end.x <= game.size.x
					),
					"Event choice buttons fit the window"
				)
			check.call(
				(overlay.get_node("Center/Panel") as Control).get_global_rect().position.y >= 0,
				"Closing panel remains inside the top window edge"
			)
			await capture.call("ui_day_end_%s_%d" % [event.id, size.x])
	_present(game, "day_end_salvage")
	await tree.process_frame
	var row: HBoxContainer = dashboard.overlay.get_node("%DayEndRow") as HBoxContainer
	var view: DayEndOptionView = row.get_child(0) as DayEndOptionView
	var day: int = game.state.day
	var hand_size: int = game.state.hand.size()
	var wood: int = game.state.resources[GameTypes.Stock.WOOD]
	await CardUiRegression.click(tree, view.get_node("%SelectButton") as Button)
	check.call(
		(
			game.state.day == day + 1
			and game.state.resources[GameTypes.Stock.WOOD] == wood + 6
			and game.state.hand.size() == hand_size
		),
		"Actual mouse choice immediately resolves effects without a hand reward"
	)
	check.call(
		game.state.day_report_pending and dashboard.overlay.get_node("%DayReportPanel").is_visible_in_tree(),
		"Closing choice shows the settled day report"
	)
	(dashboard.overlay.get_node("%DayReportPanel/ContinueButton") as Button).pressed.emit()
	check.call(not dashboard.overlay.visible, "Confirming the report ends the modal")
	_present(game, "day_end_trader")
	game.state.resources[GameTypes.Stock.FOOD] = 0
	game.state.resources[GameTypes.Stock.WATER] = 0
	game.state.resources[GameTypes.Stock.PARTS] = 0
	game.state.changed.emit()
	await tree.process_frame
	row = dashboard.overlay.get_node("%DayEndRow") as HBoxContainer
	for child: Node in row.get_children():
		check.call(
			(child.get_node("%SelectButton") as Button).disabled, "Unaffordable trade is disabled"
		)
	await capture.call("ui_day_end_unaffordable_skip")
	day = game.state.day
	await CardUiRegression.click(tree, dashboard.overlay.get_node("%DayEndSkip") as Button)
	check.call(
		game.state.day == day and game.state.day_end_settled,
		"Mouse skip retains mandatory morning shortages"
	)
	for step: int in 2:
		await tree.process_frame
		row = dashboard.overlay.get_node("%DayEndRow") as HBoxContainer
		await CardUiRegression.click(tree, row.get_child(1).get_node("%SelectButton") as Button)
	check.call(game.state.day == day + 1, "Both shortage choices must resolve before the next day")
	check.call(
		game.state.resources[GameTypes.Stock.PARTS] == 0, "Mouse skip grants no trader parts"
	)
	_present(game, "day_end_repair")
	var pending: String = game.state.day_end_event_id
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await tree.process_frame
	key = key.duplicate() as InputEventKey
	key.pressed = false
	Input.parse_input_event(key)
	await tree.process_frame
	check.call(
		dashboard.overlay.visible and game.state.day_end_event_id == pending,
		"Esc cannot silently bypass a compulsory closing event"
	)
	tree.root.size = Vector2i(1440, 960)
	game.state.new_run(12345)
	SurvivalTestSetup.developed(game.state)
	game.state.changed.emit()
	game.set_process(true)


static func _present(game: VillageGame, event_id: String) -> void:
	game.state.new_run(12345)
	SurvivalTestSetup.developed(game.state)
	game.state.core_health = 180.0
	game.state.resources[GameTypes.Stock.WOOD] = 20
	game.state.resources[GameTypes.Stock.MEDICINE] = 5
	game.state.resources[GameTypes.Stock.PARTS] = 20
	game.state.begin_night()
	var report: BattleReport = BattleReport.new()
	report.core_health = game.state.core_health
	report.started_survivors = game.state.population
	report.survivors = game.state.population
	game.state.finish_night(report)
	game.state.day_end_event_id = event_id
	game.state.pending_day_end_events.clear()
	var event: DailyEvent = game.state.current_day_end_event()
	if event.trigger != DailyEvent.Trigger.AMBIENT:
		game.state.day_end_settled = true
		game.state.day_end_effects_expired = true
		game.state.progress.hungry_days = (
			event.min_deprivation_days if event.trigger == DailyEvent.Trigger.HUNGER else 0
		)
		game.state.progress.thirsty_days = (
			event.min_deprivation_days if event.trigger == DailyEvent.Trigger.THIRST else 0
		)
	game.state.changed.emit()
