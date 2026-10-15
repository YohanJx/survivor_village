class_name PlayerFeedbackUiRegression
extends RefCounted
## 实际视口输入验证勘探关闭、打井结果及库存入口。


static func run(tree: SceneTree, viewport: Viewport, game: VillageGame, check: Callable) -> void:
	var dashboard: VillageDashboard = game.get_node("Dashboard") as VillageDashboard
	game.state.new_run(65012, GameTypes.Region.RURAL)
	dashboard.card_selected.emit(game.state.hand[0].uid)
	await tree.process_frame
	await tree.process_frame
	var survey: SurveyActionPanel = dashboard.get_node("%SurveyActionPanel") as SurveyActionPanel
	var map: VillageMap = dashboard.get_node("%VillageMap") as VillageMap
	check.call(survey.is_visible_in_tree(), "Survey uses its compact map confirmation frame")
	check.call(not survey.get_global_rect().has_point(map.get_global_rect().get_center()), "Survey frame leaves the map center selectable")
	await _click(tree, viewport, survey.get_node("Content/Heading/CloseButton") as Button)
	check.call(not survey.visible, "Survey close button actually hides the frame")
	var cell: Vector2i = TerrainGrid.CAMP + Vector2i.UP
	var point: Vector2 = map.get_global_transform_with_canvas() * (map.view_camera.get_view_transform(map.size) * ((Vector2(cell) + Vector2.ONE * 0.5) * TerrainGrid.CELL))
	await _point(tree, viewport, point)
	check.call(game.state.progress.exploration_target == TerrainGrid.index(cell), "Closed survey still accepts a real map target")
	check.call(not survey.visible and not dashboard.has_visible_confirmation(), "Map click cannot forcibly reopen a closed survey")
	SurvivalTestSetup.developed(game.state)
	game.state.weather = game.state.catalog.library.weather_rules.for_kind(WeatherDefinition.Kind.CLEAR)
	game.state.changed.emit()
	for entry: CardInstance in game.state.hand:
		if entry.definition.id == "well":
			dashboard.card_selected.emit(entry.uid)
			break
	await tree.process_frame
	await tree.process_frame
	SurvivalTestSetup.force_drill_result(game.state, true)
	await _click(tree, viewport, dashboard.detail.get_node("%ExecuteButton") as Button)
	check.call(game.state.buildings[GameTypes.Building.WELL] == 1, "Actual confirmation successfully constructs a surveyed well")
	var notice: ActionResultNotice = dashboard.get_node("%ActionResultNotice") as ActionResultNotice
	check.call(notice.visible and (notice.get_node("Message") as Label).text.contains("打井成功"), "Drill outcome is visibly reported rather than overwritten")
	var balance: ResourceBalance = EffectResolver.resource_balances(game.state)[GameTypes.Stock.WATER]
	check.call((dashboard.get_node("%Stock2") as Label).text.contains("(%+d)" % balance.net), "Water HUD reflects production minus upkeep after drilling")
	var before: int = game.state.actions_used
	await _click(tree, viewport, dashboard.get_node("%Stock2Button") as Button)
	var inventory: InventoryPanel = dashboard.overlay.get_node("%InventoryPanel") as InventoryPanel
	check.call(inventory.is_visible_in_tree(), "Clicking the water reserve opens the inventory statistics")
	check.call(inventory.displayed_text(GameTypes.Stock.WATER, 2) == "+8", "Inventory displays the well's actual daily water production")
	check.call(inventory.displayed_text(GameTypes.Stock.WATER, 3) == "−5", "Inventory separately shows daily drinking consumption")
	check.call(inventory.displayed_text(GameTypes.Stock.PARTS, 1) == str(game.state.resources[GameTypes.Stock.PARTS]), "Hidden top-bar materials remain available in the full inventory")
	var scroll: ScrollContainer = inventory.get_node("Scroll") as ScrollContainer
	var header: Control = inventory.get_node("HeaderMargin/Header") as Control
	var header_rect: Rect2 = header.get_global_rect()
	scroll.scroll_vertical = 180
	await tree.process_frame
	await tree.process_frame
	check.call(scroll.scroll_vertical > 0, "Inventory body actually scrolls")
	check.call(header.get_global_rect().is_equal_approx(header_rect), "Inventory headings remain fixed while rows scroll")
	var table: GridContainer = inventory.get_node("Scroll/ContentMargin/Body/Table") as GridContainer
	for column: int in 6:
		var heading: Control = header.get_child(column) as Control
		var value: Control = table.get_child(column) as Control
		check.call(absf(heading.get_global_rect().end.x - value.get_global_rect().end.x) <= 1.0, "Inventory header and value columns align")
	scroll.scroll_vertical = 0
	dashboard.overlay.close_modal()
	await _click(tree, viewport, dashboard.get_node("%InventoryButton") as Button)
	check.call(inventory.is_visible_in_tree(), "Independent inventory button opens all resources")
	check.call(game.state.actions_used == before, "Opening inventory consumes no action")
	dashboard.overlay.close_modal()


static func _click(tree: SceneTree, viewport: Viewport, button: Button) -> void:
	await _point(tree, viewport, button.get_global_transform_with_canvas() * (button.size * 0.5))


static func _point(tree: SceneTree, viewport: Viewport, point: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	await tree.process_frame
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		viewport.push_input(event, true)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
