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
			check.call(skip.visible == event.skippable, "Only special events display skip")
			check.call(
				(overlay.get_node("%DayEndTitle") as Label).text.contains(event.display_name),
				"Closing window names the actual event"
			)
			for index: int in row.get_child_count():
				var view: DayEndOptionView = row.get_child(index) as DayEndOptionView
				var select: Button = view.get_node("%SelectButton") as Button
				check.call(
					(
						(view.get_node("%Positive") as RichTextLabel).get_parsed_text().contains(
							event.options[index].positive
						)
						and (
							(view.get_node("%Negative") as RichTextLabel)
							. get_parsed_text()
							. contains(event.options[index].negative)
						)
					),
					"Positive and negative event effects are both displayed"
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
	check.call(not dashboard.overlay.visible, "Closing choice ends the modal")
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
	check.call(game.state.day == day + 1, "Actual mouse skip advances an optional event")
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
	game.state.changed.emit()
