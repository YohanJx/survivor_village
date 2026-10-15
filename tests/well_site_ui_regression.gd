class_name WellSiteUiRegression
extends RefCounted
## 真实视口验证打井失败后换格勘探，关闭确认框与选格不会消耗额外行动。


static func run(
	tree: SceneTree, viewport: Viewport, game: VillageGame, check: Callable, capture: Callable
) -> void:
	var dashboard: VillageDashboard = game.get_node("Dashboard") as VillageDashboard
	game.state.new_run(65012, GameTypes.Region.MOUNTAIN)
	SurvivalTestSetup.developed(game.state)
	game.state.changed.emit()
	(dashboard.get_node("%CardAcquisition") as CardAcquisitionNotice).clear()
	var first: WellSiteRecord = WellRules.pending_site(game.state.progress)
	var first_cell: Vector2i = TerrainGrid.position(first.cell)
	dashboard.card_selected.emit(_uid(game.state, "well"))
	await tree.process_frame
	await tree.process_frame
	SurvivalTestSetup.force_drill_result(game.state, false)
	await _click(tree, viewport, dashboard.detail.get_node("%ExecuteButton") as Control)
	check.call(
		first.outcome == WellSiteRecord.Outcome.DRY,
		"Real drill confirmation records no water at the current position"
	)
	check.call(
		(dashboard.detail.get_node("%ExecuteButton") as Button).disabled,
		"Failed position immediately disables another drill"
	)
	var message: Label = dashboard.get_node("%ActionResultNotice/Message") as Label
	check.call(
		message.text.contains("无水") and message.text.contains("另一个位置"),
		"Failure feedback explains why the player must change position"
	)
	await capture.call("well_position_dry")
	game.state.resources[GameTypes.Stock.STONE] = 100
	dashboard.card_selected.emit(_uid(game.state, "well_survey"))
	await tree.process_frame
	await tree.process_frame
	var map: VillageMap = dashboard.get_node("%VillageMap") as VillageMap
	var survey: SurveyActionPanel = dashboard.get_node("%SurveyActionPanel") as SurveyActionPanel
	check.call(
		map.well_survey_mode and not map.exploration_mode,
		"Well survey uses known candidate terrain instead of unknown exploration targets"
	)
	check.call(
		survey.visible and (survey.get_node("Content/ExecuteButton") as Button).disabled,
		"New well survey starts with a disabled confirmation until a position is chosen"
	)
	await _click(tree, viewport, survey.get_node("Content/Heading/CloseButton") as Control)
	var before: VillageSaveData = game.state.snapshot()
	await _point(tree, viewport, _cell_point(map, first_cell))
	check.call(
		game.state.progress.well_target == -1,
		"Real click on the dry position cannot reopen its attempt"
	)
	var second_cell: Vector2i = _visible_candidate(game.state, map)
	check.call(second_cell.x >= 0, "Another known candidate is visible and selectable")
	await _point(tree, viewport, _cell_point(map, second_cell))
	check.call(
		game.state.progress.well_target == TerrainGrid.index(second_cell),
		"Real click chooses a different well position"
	)
	check.call(not survey.visible, "Choosing another position keeps a closed well confirmation closed")
	check.call(
		game.state.resources == before.resources and game.state.rng.state == before.rng_state
		and game.state.actions_used == before.actions_used and game.state.slot == before.slot,
		"Map position selection neither charges resources nor advances time or RNG"
	)
	dashboard.card_selected.emit(_uid(game.state, "well_survey"))
	await tree.process_frame
	await tree.process_frame
	await capture.call("well_position_new_survey")
	await _click(tree, viewport, survey.get_node("Content/ExecuteButton") as Control)
	var second: WellSiteRecord = WellRules.pending_site(game.state.progress)
	check.call(
		second != null and second.cell == TerrainGrid.index(second_cell),
		"Real survey confirmation creates one pending record for the chosen position"
	)
	check.call(
		(survey.get_node("Content/ExecuteButton") as Button).disabled,
		"Pending position cannot accumulate more surveys before drilling"
	)
	dashboard.card_selected.emit(_uid(game.state, "well"))
	await tree.process_frame
	await tree.process_frame
	var risk: RichTextLabel = dashboard.detail.get_node("%Negative") as RichTextLabel
	check.call(
		risk.text.contains("40%") and risk.text.contains("仅可打井一次"),
		"New position retains a single uncertain attempt in its visible risk text"
	)
	SurvivalTestSetup.force_drill_result(game.state, true)
	await _click(tree, viewport, dashboard.detail.get_node("%ExecuteButton") as Control)
	check.call(
		game.state.buildings[GameTypes.Building.WELL] == 1 and second.outcome == WellSiteRecord.Outcome.WATER,
		"Another position can yield water through real confirmation"
	)
	check.call(
		first.outcome == WellSiteRecord.Outcome.DRY,
		"Successful new position does not reset the previous dry result"
	)
	await capture.call("well_position_water")


static func _visible_candidate(state: VillageState, map: VillageMap) -> Vector2i:
	for value: int in state.progress.explored_cells:
		var cell: Vector2i = TerrainGrid.position(value)
		if WellRules.candidate_error(state, cell).is_empty():
			if map.get_global_rect().grow(-8).has_point(_cell_point(map, cell)):
				return cell
	return Vector2i(-1, -1)


static func _cell_point(map: VillageMap, cell: Vector2i) -> Vector2:
	return map.get_global_transform_with_canvas() * (
		map.view_camera.get_view_transform(map.size)
		* ((Vector2(cell) + Vector2.ONE * 0.5) * TerrainGrid.CELL)
	)


static func _click(tree: SceneTree, viewport: Viewport, control: Control) -> void:
	await _point(tree, viewport, control.get_global_rect().get_center())


static func _point(tree: SceneTree, viewport: Viewport, point: Vector2) -> void:
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


static func _uid(state: VillageState, id: String) -> int:
	for entry: CardInstance in state.hand:
		if entry.definition.id == id:
			return entry.uid
	return -1
