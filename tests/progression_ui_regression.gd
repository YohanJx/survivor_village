class_name ProgressionUiRegression
extends RefCounted


static func run(tree: SceneTree, game: VillageGame, check: Callable, capture: Callable) -> void:
	var dashboard: VillageDashboard = game.get_node("Dashboard") as VillageDashboard
	var overlay: VillageGameOverlay = dashboard.overlay
	game.state.new_run(65012, GameTypes.Region.RURAL)
	await tree.process_frame
	await tree.process_frame
	check.call(
		not overlay.visible and game.state.actions_used == 0,
		"New map starts directly without dawn modal or action cost"
	)
	SurvivalTestSetup.developed(game.state)
	game.state.changed.emit()
	await CardUiRegression.click(tree, dashboard.get_node("%VillageInfoButton") as Control)
	var info: VillageInfoPanel = overlay.get_node("%VillageInfo") as VillageInfoPanel
	check.call(
		(info.get_node("%VillageInformation") as Label).text.contains("库存"),
		"Village panel shows expanded inventory"
	)
	(info.get_node("%VillageTabs") as TabContainer).current_tab = 0
	await tree.process_frame
	var counts: PackedInt32Array = [0, 1, 0, 0, 1, 3]
	var builder: WorkforceRow = info.get_node("%Job2") as WorkforceRow
	var engineer: WorkforceRow = info.get_node("%Job3") as WorkforceRow
	var guard: WorkforceRow = info.get_node("%Job5") as WorkforceRow
	check.call(
		(builder.get_node("%Increase") as Button).disabled,
		"Allocation cannot add workers when none are available"
	)
	await CardUiRegression.click(tree, builder.get_node("%Decrease") as Control)
	await CardUiRegression.click(tree, engineer.get_node("%Decrease") as Control)
	await CardUiRegression.click(tree, guard.get_node("%Increase") as Control)
	await CardUiRegression.click(tree, guard.get_node("%Increase") as Control)
	check.call(
		game.state.profession_counts == PackedInt32Array([0, 1, 1, 1, 1, 1]),
		"Allocation edits remain a draft until confirmation"
	)
	check.call(
		(
			(guard.get_node("%RoleCount") as Label).text == "3 人"
			and (guard.get_node("%Increase") as Button).disabled
		),
		"Draft shows the new count and stops at available population"
	)
	(info.get_node("%UseArchers") as CheckButton).button_pressed = false
	await CardUiRegression.click(tree, info.get_node("%AssignJobs") as Control)
	check.call(
		game.state.profession_counts == counts and game.state.progress.assigned_today,
		"Real job button commits chosen counts"
	)
	check.call(
		(info.get_node("%AssignJobs") as Button).disabled, "Daily assignment locks after one commit"
	)
	check.call(
		not game.state.progress.survivors[4].archer, "Equipment selection reaches survivor model"
	)
	var crew: OptionButton = info.get_node("%CrewChoice") as OptionButton
	check.call(crew.is_item_disabled(2), "Small population cannot select large crew")
	await capture.call("ui_progression_jobs")
	await _check_small_allocation(tree, info, check, capture)
	await CardUiRegression.click(tree, info.get_node("%VillageClose") as Control)
	var forced: VillageCardButton = _card_view(dashboard, "forced_march")
	var scroll: ScrollContainer = dashboard.hand_panel.get_node("HandScroll") as ScrollContainer
	scroll.ensure_control_visible(forced)
	await tree.process_frame
	await CardUiRegression.click(tree, forced)
	check.call(
		(dashboard.detail.get_node("%Preview") as Label).text.contains("执行后烦躁 0→2"),
		"Card preview shows future mood"
	)
	await capture.call("ui_progression_mood_preview")
	await CardUiRegression.click(tree, dashboard.detail.get_node("%ExecuteButton") as Control)
	check.call(game.state.progress.frustration == 2, "Real confirmation commits frustration")
	check.call(
		(dashboard.get_node("%ProgressLine") as Button).text.contains("烦躁 2/5"),
		"Detailed village summary retains mood"
	)
	await capture.call("ui_progression_mood")
	await CardUiRegression.click(tree, dashboard.get_node("%MenuButton") as Control)
	await CardUiRegression.click(tree, dashboard.get_node("%NewRunButton") as Control)
	var map: OptionButton = overlay.get_node("%MapChoice") as OptionButton
	map.select(2)
	await capture.call("ui_progression_map_choice")
	await CardUiRegression.click(tree, overlay.get_node("%NewRunConfirm") as Control)
	check.call(
		(
			game.state.progress.region == GameTypes.Region.RUINS
			and game.state.progress.event_choice == 1
		),
		"New-run confirmation uses chosen map"
	)
	for region: GameTypes.Region in [
		GameTypes.Region.MOUNTAIN, GameTypes.Region.RURAL, GameTypes.Region.RUINS
	]:
		game.state.new_run(65012, region)
		await tree.process_frame
		await tree.process_frame
		await capture.call("ui_progression_map_%d" % region)
	game.state.new_run(12345)
	SurvivalTestSetup.developed(game.state)
	game.state.changed.emit()


static func _card_view(dashboard: VillageDashboard, id: String) -> VillageCardButton:
	for child: Node in dashboard.hand_panel.get_node("%HandContainer").get_children():
		var view: VillageCardButton = child as VillageCardButton
		if view.card.id == id:
			return view
	return null


static func _check_small_allocation(
	tree: SceneTree, info: VillageInfoPanel, check: Callable, capture: Callable
) -> void:
	var original_size: Vector2i = tree.root.size
	tree.root.size = Vector2i(1024, 768)
	for frame: int in 3:
		await tree.process_frame
	var viewport: Rect2 = Rect2(Vector2.ZERO, Vector2(tree.root.size))
	check.call(viewport.encloses(info.get_global_rect()), "Workforce panel fits the small window")
	check.call(
		(
			viewport.encloses((info.get_node("%AssignJobs") as Control).get_global_rect())
			and viewport.encloses((info.get_node("%VillageClose") as Control).get_global_rect())
		),
		"Workforce confirmation and close remain reachable in a small window"
	)
	await capture.call("ui_workforce_small")
	tree.root.size = original_size
	for frame: int in 3:
		await tree.process_frame
