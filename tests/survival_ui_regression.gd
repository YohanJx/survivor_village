class_name SurvivalUiRegression
extends RefCounted
## 真实窗口验证新开局、地形提示、专业锁定和存储说明。


static func run(tree: SceneTree, game: VillageGame, check: Callable, capture: Callable) -> void:
	var dashboard: VillageDashboard = game.get_node("Dashboard") as VillageDashboard
	game.state.new_run(65012, GameTypes.Region.MOUNTAIN)
	(dashboard.get_node("%ActionSplit") as ActionDock).set_expanded(false)
	(dashboard.get_node("%CardCategoryBar/All/Button") as Button).pressed.emit()
	await tree.process_frame
	var row: HBoxContainer = dashboard.hand_panel.get_node("%HandContainer") as HBoxContainer
	check.call(row.get_child_count() == 1, "Opening shows only one exploration card")
	await CardUiRegression.click(tree, row.get_child(0) as Control)
	check.call(
		(dashboard.detail.get_node("%CardTitle") as Label).text == "勘探地形",
		"Opening card selects terrain survey"
	)
	check.call(
		(dashboard.get_node("%SurveyActionPanel/Content/ExecuteButton") as Button).disabled,
		"Exploration requires an explicit map target"
	)
	await CardUiRegression.click(tree, dashboard.get_node("%SurveyActionPanel/Content/Heading/CloseButton") as Button)
	var map_view: VillageMap = dashboard.get_node("%VillageMap") as VillageMap
	var cell: Vector2i = TerrainGrid.CAMP + Vector2i.UP
	var local_point: Vector2 = (
		map_view.view_camera.get_view_transform(map_view.size)
		* ((Vector2(cell) + Vector2(0.5, 0.5)) * TerrainGrid.CELL)
	)
	var global_point: Vector2 = map_view.get_global_transform_with_canvas() * local_point
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = global_point
	tree.root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.position = global_point
		click.global_position = global_point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		tree.root.push_input(click, true)
	await tree.process_frame
	check.call(
		game.state.progress.exploration_target == TerrainGrid.index(cell),
		"Real map click selects an adjacent unknown cell"
	)
	check.call(
		not (dashboard.get_node("%SurveyActionPanel/Content/ExecuteButton") as Button).disabled,
		"Target selection enables confirmation"
	)
	check.call(not (dashboard.get_node("%SurveyActionPanel") as SurveyActionPanel).visible, "Map target does not reopen a closed survey frame")
	await CardUiRegression.click(tree, dashboard.get_node("%CardCategoryBar/All/Button") as Button)
	await CardUiRegression.click(tree, row.get_child(0) as Control)
	await capture.call("ui_survival_opening")
	await CardUiRegression.click(tree, dashboard.get_node("%SurveyActionPanel/Content/ExecuteButton") as Control)
	await capture.call("ui_terrain_report")
	await _check_report_layout(tree, game, dashboard, check, capture)
	check.call(
		game.state.progress.terrain_surveys == 1 and game.state.slot == 1,
		"Real mouse confirmation commits discovery and one action"
	)
	map_view.set_exploration_mode(false)
	await tree.process_frame
	var village_button: Control = dashboard.get_node("%VillageInfoButton") as Control

	check.call(
		Rect2(Vector2.ZERO, game.size).encloses(village_button.get_global_rect()),
		"Complete survey report keeps top village information control inside the viewport"
	)
	await capture.call("ui_camp_explored")
	await CardUiRegression.click(tree, dashboard.get_node("%VillageInfoButton") as Control)
	var info: VillageInfoPanel = dashboard.overlay.get_node("%VillageInfo") as VillageInfoPanel
	var text: String = (info.get_node("%VillageInformation") as Label).text
	check.call(
		text.contains("按已发现地形") and text.contains("跨日存储容量"),
		"Village window explains dry-map route and preservation"
	)
	await capture.call("ui_survival_dry_map")
	await CardUiRegression.click(tree, info.get_node("%VillageClose") as Control)
	game.state.new_run(65012, GameTypes.Region.RURAL)
	SurvivalTestSetup.developed(game.state)
	game.state.changed.emit()
	(dashboard.get_node("%ActionSplit") as ActionDock).set_expanded(true)
	game.state.assign_jobs(PackedInt32Array([5, 0, 0, 0, 0, 0]))
	var forage: VillageCardButton
	for child: Node in row.get_children():
		var view: VillageCardButton = child as VillageCardButton
		if view.card.id == "forage":
			forage = view
	var scroll: ScrollContainer = dashboard.hand_panel.get_node("HandScroll") as ScrollContainer
	scroll.ensure_control_visible(forage)
	await tree.process_frame
	await CardUiRegression.click(tree, forage)
	check.call(
		(
			(dashboard.detail.get_node("%ExecuteButton") as Button).disabled
			and (dashboard.detail.get_node("%Reason") as Label).text.contains("采集者")
		),
		"Missing profession shows a concrete disabled reason"
	)
	await capture.call("ui_survival_profession_locked")
	game.state.new_run(65012, GameTypes.Region.MOUNTAIN)
	SurvivalTestSetup.developed(game.state)
	game.state.changed.emit()
	await tree.process_frame
	await tree.process_frame
	var well: VillageCardButton
	for child: Node in row.get_children():
		var view: VillageCardButton = child as VillageCardButton
		if view.card.id == "emergency_rations":
			check.call(
				(view.get_node("%Keywords") as RichTextLabel).text.contains("补给"),
				"Reused UID refreshes keywords when map changes card definition"
			)
		if view.card.id == "well":
			well = view
	scroll.ensure_control_visible(well)
	await tree.process_frame
	await CardUiRegression.click(tree, well)
	var preview: Label = dashboard.detail.get_node("%Preview") as Label
	check.call(
		preview.text.contains("40%") and preview.text.contains("成功时预览"),
		"Drill decision shows chance and conditional preview"
	)
	check.call(
		(dashboard.detail.get_node("%Negative") as RichTextLabel).text.contains("40%"),
		"Drill chance is fixed above confirmation without scrolling"
	)
	SurvivalTestSetup.force_drill_result(game.state, true)
	await capture.call("ui_survival_drill")
	await CardUiRegression.click(tree, dashboard.detail.get_node("%ExecuteButton") as Control)
	check.call(
		game.state.buildings[GameTypes.Building.WELL] == 1,
		"Real drill confirmation constructs a water-bearing surveyed well"
	)
	await CardUiRegression.click(tree, dashboard.get_node("%VillageInfoButton") as Control)
	(info.get_node("%VillageTabs") as TabContainer).current_tab = 1
	var info_scroll: ScrollContainer = info.get_node("%Scroll") as ScrollContainer
	info_scroll.scroll_vertical = 300
	await tree.process_frame
	await capture.call("ui_survival_storage")
	await CardUiRegression.click(tree, info.get_node("%VillageClose") as Control)

	for region: GameTypes.Region in [
		GameTypes.Region.MOUNTAIN, GameTypes.Region.RURAL, GameTypes.Region.RUINS
	]:
		game.state.new_run(65012, region)
		SurvivalTestSetup.developed(game.state)
		game.state.changed.emit()
		for child: Node in row.get_children():
			var view: VillageCardButton = child as VillageCardButton
			if view.card.id == "explore":
				view.pressed.emit()
				break
		await tree.process_frame
		await tree.process_frame
		check.call(
			map_view.exploration_mode and game.state.progress.explored_cells.size() == 60,
			"Developed region renders the generated survey grid"
		)
		await capture.call("ui_terrain_generated_%d" % region)

	await _check_resource_and_filter(tree, game, dashboard, check, capture)
	await _check_camp_view(tree, game, map_view, check, capture)


static func _check_camp_view(
	tree: SceneTree, game: VillageGame, map_view: VillageMap, check: Callable, capture: Callable
) -> void:
	map_view.set_exploration_mode(false)
	map_view.focus_village()
	await capture.call("ui_camp_built")
	map_view.fit_world()
	var full_scale: float = map_view.view_camera.get_view_transform(map_view.size).get_scale().x
	game.state.begin_night()
	await tree.process_frame
	check.call(
		map_view.view_camera.get_view_transform(map_view.size).get_scale().x > full_scale * 2.0,
		"Night entry restores a close camp view after full-map exploration"
	)
	check.call(
		map_view.view_camera.view_to_world(map_view.size * 0.5, map_view.size).is_equal_approx(
			WorldLayout.CENTER
		),
		"Night camera centers on the camp"
	)
	await capture.call("ui_camp_built_night")
	game.state.new_run(65012, GameTypes.Region.RURAL)
	SurvivalTestSetup.developed(game.state)
	game.state.changed.emit()


static func _check_report_layout(
	tree: SceneTree,
	game: VillageGame,
	dashboard: VillageDashboard,
	check: Callable,
	capture: Callable
) -> void:
	tree.root.size = Vector2i(1024, 768)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	var report: Label = dashboard.get_node("%ActionResultNotice/Message") as Label
	var footer: Control = dashboard.get_node("Margin/Layout/Footer") as Control
	check.call(report.is_visible_in_tree() and report.text.contains("北："), "Actual exploration result displays directional clues")
	check.call(footer.get_global_rect().end.y <= game.size.y + 1.0, "Survey result does not push footer outside the window")
	check.call(
		Rect2(Vector2.ZERO, game.size).encloses((dashboard.get_node("%SurveyActionPanel/Content/ExecuteButton") as Button).get_global_rect()),
		"Compact survey confirmation fits the small viewport"
	)
	await capture.call("ui_terrain_report_small")
	tree.root.size = Vector2i(1440, 960)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame


static func _check_resource_and_filter(
	tree: SceneTree,
	game: VillageGame,
	dashboard: VillageDashboard,
	check: Callable,
	capture: Callable
) -> void:
	(dashboard.get_node("%ActionSplit") as ActionDock).set_expanded(true)
	game.state.resources[GameTypes.Stock.FOOD] = 100
	game.state.resources[GameTypes.Stock.WATER] = 100
	game.state.resources[GameTypes.Stock.POWER] = 10
	game.state.buildings[GameTypes.Building.FOOD_STORE] = 1
	game.state.buildings[GameTypes.Building.WATER_TANK] = 1
	game.state.population = 20
	game.state.buildings[GameTypes.Building.WORKSHOP] = 1
	game.state.buildings[GameTypes.Building.FARM] = 1
	game.state.changed.emit()
	await tree.process_frame
	var stats: VillageStats = EffectResolver.derive(game.state)
	check.call(
		(
			(dashboard.get_node("%Stock1") as Label).text
			== "100(%+d)/70" % (stats.income[GameTypes.Stock.FOOD] - stats.upkeep[GameTypes.Stock.FOOD])
		),
		"Food shows gross daily consumption and its own storage capacity"
	)
	check.call(
		(
			(dashboard.get_node("%Stock2") as Label).text
			== "100(%+d)/70" % (stats.income[GameTypes.Stock.WATER] - stats.upkeep[GameTypes.Stock.WATER])
		),
		"Water uses the unified daily upkeep calculation"
	)
	check.call((dashboard.get_node("%Stock3") as Label).text == "10/0", "Power shows zero capacity")
	var filter: OptionButton = dashboard.get_node("%KeywordFilter") as OptionButton
	var index: int = -1
	for item: int in filter.item_count:
		if filter.get_item_text(item) == "人物：工程师":
			index = item
	check.call(index > 0, "Filter groups actual keywords by terrain, people and topics")
	filter.select(0)
	filter.item_selected.emit(0)
	if DisplayServer.get_name() != "headless":
		tree.root.grab_focus()
		tree.root.warp_mouse(Vector2(5, 5))
		# 等待 macOS 异步焦点与光标事件完成，再向嵌入式菜单发送按键。
		await tree.create_timer(0.15).timeout
	filter.grab_focus()
	var before: int = game.state.actions_used
	await _filter_key(tree, KEY_ENTER)
	check.call(filter.get_popup().visible, "Keyboard opens the real keyword popup")
	check.call(filter.get_popup().get_focused_item() == 0, "Popup starts with the selected filter")
	for step: int in index:
		await _filter_key(tree, KEY_DOWN)
	await _filter_key(tree, KEY_ENTER)
	check.call(filter.selected == index, "Native popup keyboard confirms the intended keyword")
	check.call(game.state.actions_used == before, "Filter confirmation never executes a card")
	await tree.process_frame
	var row: HBoxContainer = dashboard.hand_panel.get_node("%HandContainer") as HBoxContainer
	var shown: int = 0
	for child: Node in row.get_children():
		var view: VillageCardButton = child as VillageCardButton
		var engineer: bool = view.card.keywords.any(
			func(keyword: KeywordDefinition) -> bool: return keyword.id == "engineer"
		)
		check.call(view.visible == engineer, "Real dropdown input filters specialist cards")
		if view.visible:
			shown += 1
	check.call(
		shown > 0 and shown < row.get_child_count(), "Filter changes the displayed collection"
	)
	tree.root.size = Vector2i(1024, 768)
	await tree.process_frame
	await tree.process_frame
	check.call(
		(
			(dashboard.get_node("Margin/Layout/Resources") as Control).get_global_rect().end.x
			<= game.size.x
		),
		"Long stock values fit inside the small window"
	)
	await capture.call("ui_keywords_and_capacity_small")
	filter.select(0)
	filter.item_selected.emit(0)
	tree.root.size = Vector2i(1440, 960)
	await tree.process_frame
	await tree.process_frame


static func _filter_key(tree: SceneTree, key: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		tree.root.push_input(event, true)
	await tree.process_frame
