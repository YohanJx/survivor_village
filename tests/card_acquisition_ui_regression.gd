class_name CardAcquisitionUiRegression
extends RefCounted
## 从真实探索事务验证获取提示、只读查看、去重、取消及详情展开。


static func run(
	tree: SceneTree, game: VillageGame, check: Callable, capture: Callable = Callable()
) -> void:
	var dashboard: VillageDashboard = game.get_node("Dashboard") as VillageDashboard
	var notice: CardAcquisitionNotice = (
		dashboard.get_node("%CardAcquisition") as CardAcquisitionNotice
	)
	var received: Array[int] = []
	var listener: Callable = func(uids: PackedInt32Array) -> void:
		received.append_array(uids)
		check.call(
			not game.state.play_card(game.state.hand[0].uid),
			"Acquisition callback cannot reenter the committed action"
		)
	game.state.cards_acquired.connect(listener)
	game.state.new_run(91273, GameTypes.Region.RURAL)
	check.call(received.is_empty() and not notice.visible, "Initial hand is not a new-card alert")
	game.state.day = 2
	var explore_uid: int = game.state.hand[0].uid
	check.call(not game.state.play_card(explore_uid), "Failed survey produces no cards")
	check.call(received.is_empty() and not notice.visible, "Rejected action shows no acquisition")
	SurvivalTestSetup.select_frontier(game.state)
	check.call(game.state.play_card(explore_uid), "Real exploration grants eligible cards")
	check.call(
		not received.is_empty() and notice.visible and not dashboard.overlay.visible,
		"Exploration shows a non-modal acquisition notice"
	)
	var names: String = (notice.get_node("%AcquiredNames") as RichTextLabel).get_parsed_text()
	for uid: int in received:
		check.call(
			names.contains(game.state.find_card(uid).display_name),
			"Notice names every card from the committed acquisition"
		)
	var count: int = received.size()
	game.state.set_crew(0)
	check.call(received.size() == count, "Refreshing state does not repeat acquisition signals")
	dashboard.notify("已执行决策")
	check.call(notice.visible, "Ordinary status message cannot overwrite acquired-card notice")
	var pointer: InputEventMouseMotion = InputEventMouseMotion.new()
	pointer.position = notice.get_global_rect().get_center()
	pointer.global_position = pointer.position
	tree.root.push_input(pointer, true)
	await tree.process_frame
	check.call((notice.get_node("Timer") as Timer).is_stopped(), "Hovering the click-through notice keeps it visible")
	pointer = InputEventMouseMotion.new()
	pointer.position = Vector2(2.0, 2.0)
	pointer.global_position = pointer.position
	tree.root.push_input(pointer, true)
	await tree.process_frame
	check.call(not (notice.get_node("Timer") as Timer).is_stopped(), "Leaving the notice resumes its expiry")
	await tree.process_frame
	await tree.process_frame
	if capture.is_valid():
		await tree.create_timer(0.25).timeout
		await capture.call("ui_card_acquisition")
		var original_size: Vector2i = tree.root.size
		tree.root.size = Vector2i(1024, 768)
		await tree.process_frame
		await tree.process_frame
		check.call(
			Rect2(Vector2.ZERO, Vector2(tree.root.size)).encloses(notice.get_global_rect()),
			"Acquisition notice fits a small window"
		)
		await capture.call("ui_card_acquisition_small")
		tree.root.size = original_size
		await tree.process_frame
		await tree.process_frame
	var snapshot: VillageSaveData = game.state.snapshot()
	await _click_first_card_name(tree, notice)
	check.call(
		dashboard.overlay.visible and not notice.visible,
		"Acquired-card link opens the read-only card inspection"
	)
	check.call(
		(
			game.state.actions_used == snapshot.actions_used
			and game.state.resources == snapshot.resources
		),
		"Reading an acquired card does not spend an action or supplies"
	)
	dashboard.overlay.close_modal()
	dashboard.show_acquired_cards(game.state, PackedInt32Array(received))
	check.call(game.state.restore(snapshot), "Restore accepts the committed exploration snapshot")
	check.call(
		not notice.visible and received.size() == count,
		"Restoring hand clears stale notice without replaying card acquisition"
	)
	dashboard.show_acquired_cards(game.state, PackedInt32Array(received))
	(notice.get_node("Timer") as Timer).timeout.emit()
	game.state.new_run(91273, GameTypes.Region.RURAL)
	await tree.create_timer(0.5).timeout
	check.call(not notice.visible, "New run cancels notice and its pending fade callback")
	game.state.cards_acquired.disconnect(listener)
	game.state.new_run(12345)
	SurvivalTestSetup.developed(game.state)
	game.state.changed.emit()
	var uid: int = -1
	for entry: CardInstance in game.state.hand:
		if entry.definition.id == "forage":
			uid = entry.uid
			break
	dashboard.card_selected.emit(uid)
	var advanced: Control = dashboard.detail.get_node("%AdvancedDetails") as Control
	check.call(not advanced.visible, "Selected card starts with a concise effect face")
	await tree.process_frame
	await tree.process_frame
	(dashboard.detail.get_node("%DetailScroll") as ScrollContainer).ensure_control_visible(
		dashboard.detail.get_node("%AdvancedToggle") as Control
	)
	await tree.process_frame
	await CardUiRegression.click(tree, dashboard.detail.get_node("%AdvancedToggle") as Control)
	check.call(advanced.visible, "Click reveals prerequisites and settlement preview")
	if capture.is_valid():
		await capture.call("ui_card_detail_expanded")
	dashboard.card_selected.emit(game.state.hand[1].uid)
	check.call(not advanced.visible, "Changing card collapses the previous detailed preview")
	await tree.process_frame
	await tree.process_frame
	var effects: Control = dashboard.detail.get_node("%Positive") as Control
	var detail_scroll: ScrollContainer = (
		dashboard.detail.get_node("%DetailScroll") as ScrollContainer
	)
	check.call(
		(
			dashboard.detail.get_global_rect().encloses(effects.get_global_rect())
			and not detail_scroll.is_ancestor_of(effects)
		),
		"Main card effect is fully visible without scrolling after selection"
	)
	if capture.is_valid():
		await capture.call("ui_card_detail_concise")


static func _click_first_card_name(tree: SceneTree, notice: CardAcquisitionNotice) -> void:
	var names: Control = notice.get_node("%AcquiredNames") as Control
	var point: Vector2 = names.get_global_transform_with_canvas() * Vector2(12, 10)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		tree.root.push_input(event, true)
	await tree.process_frame
