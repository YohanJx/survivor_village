class_name ProgressionUiRegression
extends RefCounted


static func run(tree: SceneTree, game: VillageGame, check: Callable, capture: Callable) -> void:
	var dashboard: VillageDashboard = game.get_node("Dashboard") as VillageDashboard
	var overlay: VillageGameOverlay = dashboard.overlay
	game.state.new_run(65012, GameTypes.Region.RURAL)
	await tree.process_frame
	await tree.process_frame
	check.call(
		overlay.visible and (overlay.get_node("%EventContent") as Control).visible,
		"New map opens fixed first-day event"
	)
	await capture.call("ui_progression_event")
	await CardUiRegression.click(tree, overlay.get_node("%EventAccept") as Control)
	check.call(
		(
			game.state.progress.event_choice == 0
			and not overlay.visible
			and game.state.actions_used == 0
		),
		"Real event button unlocks day without spending action"
	)
	await CardUiRegression.click(tree, dashboard.get_node("%VillageInfoButton") as Control)
	var info: VillageInfoPanel = overlay.get_node("%VillageInfo") as VillageInfoPanel
	check.call(
		(info.get_node("%VillageInformation") as Label).text.contains("库存"),
		"Village panel shows expanded inventory"
	)
	var counts: PackedInt32Array = [0, 1, 0, 0, 1, 3]
	for index: int in GameTypes.Profession.COUNT:
		(info.get_node("%%Job%d" % index) as SpinBox).value = counts[index]
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
		"Mood remains visible in day HUD"
	)
	await capture.call("ui_progression_mood")
	await CardUiRegression.click(tree, dashboard.get_node("%NewRunButton") as Control)
	var map: OptionButton = overlay.get_node("%MapChoice") as OptionButton
	map.select(2)
	await capture.call("ui_progression_map_choice")
	await CardUiRegression.click(tree, overlay.get_node("%NewRunConfirm") as Control)
	check.call(
		(
			game.state.progress.region == GameTypes.Region.RUINS
			and game.state.progress.event_choice == -1
		),
		"New-run confirmation uses chosen map"
	)
	await CardUiRegression.click(tree, overlay.get_node("%EventDecline") as Control)
	game.state.progress.event_id = "convoy"
	game.state.progress.event_choice = -1
	game.state.resources[GameTypes.Stock.FOOD] = 0
	game.state.changed.emit()
	check.call(
		(overlay.get_node("%EventAccept") as Button).disabled,
		"Unaffordable event option is visibly disabled"
	)
	check.call(
		not (overlay.get_node("%EventDecline") as Button).disabled,
		"Free event option remains reachable"
	)
	await capture.call("ui_progression_event_choice")
	await CardUiRegression.click(tree, overlay.get_node("%EventDecline") as Control)
	check.call(
		game.state.progress.event_choice == 1 and game.state.resources[GameTypes.Stock.FOOD] == 0,
		"Real free event choice preserves insufficient supplies"
	)
	for region: GameTypes.Region in [
		GameTypes.Region.MOUNTAIN, GameTypes.Region.RURAL, GameTypes.Region.RUINS
	]:
		game.state.new_run(65012, region)
		game.state.choose_daily_event(1)
		await tree.process_frame
		await tree.process_frame
		await capture.call("ui_progression_map_%d" % region)
	game.state.new_run(12345)


static func _card_view(dashboard: VillageDashboard, id: String) -> VillageCardButton:
	for child: Node in dashboard.hand_panel.get_node("%HandContainer").get_children():
		var view: VillageCardButton = child as VillageCardButton
		if view.card.id == id:
			return view
	return null
