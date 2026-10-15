class_name SustainableUiRegression
extends RefCounted
## 实际按钮验证替代供水、自动收支、停产说明和大量设施下的固定库存表头。


static func run(
	tree: SceneTree, viewport: Viewport, game: VillageGame, check: Callable, capture: Callable
) -> void:
	var dashboard: VillageDashboard = game.get_node("Dashboard") as VillageDashboard
	game.state.new_run(65012, GameTypes.Region.RURAL)
	SurvivalTestSetup.developed(game.state)
	game.state.weather = game.state.catalog.library.weather_rules.for_kind(WeatherDefinition.Kind.CLEAR)
	game.state.changed.emit()
	(dashboard.get_node("%CardAcquisition") as CardAcquisitionNotice).clear()
	(dashboard.get_node("%ActionSplit") as ActionDock).set_expanded(true)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	await _select(tree, viewport, dashboard, "rain_collector")
	await capture.call("sustainable_rain_collector")
	await _click(tree, viewport, dashboard.detail.get_node("%ExecuteButton") as Control)
	check.call(game.state.buildings[GameTypes.Building.RAIN_COLLECTOR] == 1, "Actual card confirmation constructs a condensation collector")
	(dashboard.get_node("%CardAcquisition") as CardAcquisitionNotice).clear()
	await _select(tree, viewport, dashboard, "solar_still")
	await capture.call("sustainable_solar_water")
	await _click(tree, viewport, dashboard.detail.get_node("%ExecuteButton") as Control)
	check.call(game.state.buildings[GameTypes.Building.SOLAR_STILL] == 1 and game.state.buildings[GameTypes.Building.WELL] == 0, "Actual collector route never requires constructing a well")
	await _click(tree, viewport, dashboard.get_node("%InventoryButton") as Control)
	var inventory: InventoryPanel = dashboard.overlay.get_node("%InventoryPanel") as InventoryPanel
	check.call(inventory.displayed_text(GameTypes.Stock.WATER, 2) == "+7", "Inventory displays both actual automatic water sources")
	check.call(inventory.displayed_text(GameTypes.Stock.WATER, 4) == "+2", "Alternative supply visibly exceeds five people's daily drinking")
	await capture.call("sustainable_water_inventory")
	dashboard.overlay.close_modal()
	game.state.new_run(65012, GameTypes.Region.RURAL)
	SurvivalTestSetup.developed(game.state)
	game.state.weather = game.state.catalog.library.weather_rules.for_kind(WeatherDefinition.Kind.CLEAR)
	for building: int in range(GameTypes.Building.RIVER_WINDMILL, GameTypes.Building.COUNT):
		if building != GameTypes.Building.WELL_WINDPUMP:
			game.state.buildings[building] = 1
	game.state.resources[GameTypes.Stock.WOOD] = 5
	game.state.assign_jobs(PackedInt32Array([1, 1, 1, 0, 1, 1]))
	game.state.changed.emit()
	(dashboard.get_node("%CardAcquisition") as CardAcquisitionNotice).clear()
	await _click(tree, viewport, dashboard.get_node("%InventoryButton") as Control)
	await tree.process_frame
	await tree.process_frame
	check.call(inventory.displayed_text(GameTypes.Stock.WOOD, 2) == "+6", "Inventory shows sustainable forestry plus recycling")
	check.call(inventory.displayed_text(GameTypes.Stock.WOOD, 3) == "−2", "Inventory separates the reserved arrow-production wood")
	var effects: Label = inventory.get_node("Scroll/ContentMargin/Body/Effects") as Label
	check.call(effects.text.contains("缺少工程师") and effects.text.contains("整批停产"), "Actual production status explains both missing staff and material contention")
	check.call(Rect2(Vector2.ZERO, game.size).encloses(inventory.get_global_rect()), "Many production statuses cannot push inventory outside the game viewport")
	await capture.call("sustainable_material_inventory")
	var scroll: ScrollContainer = inventory.get_node("Scroll") as ScrollContainer
	var header: Control = inventory.get_node("HeaderMargin/Header") as Control
	var before: Rect2 = header.get_global_rect()
	scroll.scroll_vertical = 10000
	await tree.process_frame
	await tree.process_frame
	check.call(header.get_global_rect().is_equal_approx(before), "Inventory column navigation stays fixed while production statuses scroll")
	check.call(effects.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1.0, "Last production status is actually reachable in the scrolling body")
	await capture.call("sustainable_production_status")
	await _click(tree, viewport, inventory.get_node("Heading/CloseButton") as Control)
	check.call(not dashboard.overlay.visible, "Inventory close stays accessible after scrolling production")
	(dashboard.get_node("%ActionSplit") as ActionDock).set_expanded(false)
	await capture.call("sustainable_facilities")
	await _capture_facilities(tree, game, capture)


static func _capture_facilities(tree: SceneTree, game: VillageGame, capture: Callable) -> void:
	var dashboard: VillageDashboard = game.get_node("Dashboard") as VillageDashboard
	var map: VillageMap = dashboard.get_node("%VillageMap") as VillageMap
	SurvivalTestSetup.complete_well(game.state)
	game.state.buildings[GameTypes.Building.WELL_WINDPUMP] = 1
	game.state.changed.emit()
	(dashboard.get_node("%CardAcquisition") as CardAcquisitionNotice).clear()
	map.focus_village()
	var scale_value: Vector2 = map.view_camera.get_view_transform(map.size).get_scale()
	map.view_camera.pan_by((WorldLayout.CENTER - Vector2(420, 220)) * scale_value, map.size)
	map.queue_redraw()
	await tree.process_frame
	await capture.call("map_facilities_close")
	map.focus_village()
	map.view_camera.zoom_by(0.5, map.size * 0.5, map.size)
	map.queue_redraw()
	await tree.process_frame
	await capture.call("map_facilities_day")
	game.state.begin_night()
	map.view_camera.zoom_by(0.5, map.size * 0.5, map.size)
	map.queue_redraw()
	await tree.process_frame
	await capture.call("map_facilities_night")


static func _select(
	tree: SceneTree, viewport: Viewport, dashboard: VillageDashboard, id: String
) -> void:
	var row: HBoxContainer = dashboard.hand_panel.get_node("%HandContainer") as HBoxContainer
	var scroll: ScrollContainer = dashboard.hand_panel.get_node("HandScroll") as ScrollContainer
	for child: Node in row.get_children():
		var card: VillageCardButton = child as VillageCardButton
		if card.card.id == id:
			scroll.ensure_control_visible(card)
			await tree.process_frame
			await tree.process_frame
			await _click(tree, viewport, card)
			return


static func _click(tree: SceneTree, viewport: Viewport, control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	await tree.process_frame
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event, true)
	await tree.process_frame
	await tree.process_frame
