class_name CardCategoryUiRegression
extends RefCounted
## 驱动真实视口输入，检查分类、收起、空类别与只读状态。


static func run(tree: SceneTree, viewport: Viewport, game: VillageGame, check: Callable) -> void:
	var dashboard: VillageDashboard = game.get_node("Dashboard") as VillageDashboard
	var bar: CardCategoryBar = dashboard.get_node("%CardCategoryBar") as CardCategoryBar
	var dock: ActionDock = dashboard.get_node("%ActionSplit") as ActionDock
	var row: HBoxContainer = dashboard.hand_panel.get_node("%HandContainer") as HBoxContainer
	check.call(bar.get_parent() == dashboard, "Category navigation remains independent of card popup layout")
	check.call(bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Navigation container does not intercept button input")
	dashboard.card_selected.emit(-1)
	await tree.process_frame
	await tree.process_frame
	var map: VillageMap = dashboard.get_node("%VillageMap") as VillageMap
	var map_rect: Rect2 = map.get_global_rect()
	check.call(not map_rect.intersects(bar.get_global_rect()), "Map viewport never extends beneath action navigation")
	var before: int = game.state.actions_used
	var resources: PackedInt32Array = game.state.resources.duplicate()
	for index: int in 5:
		var button: Button = bar.get_child(index).get_node("Button") as Button
		# 当前类别已展开时先收起，下一次点击必须展开。
		if button.button_pressed:
			await _click(tree, viewport, button)
		await _click(tree, viewport, button)
		check.call(dock.is_expanded(), "Category click expands the cards: %d" % index)
		check.call(map.get_global_rect().is_equal_approx(map_rect), "Popup preserves map dimensions")
		var connector: Polygon2D = dock.get_node("Connector") as Polygon2D
		check.call(
			absf(connector.polygon[2].x + dock.global_position.x - button.get_global_rect().get_center().x) < 1.0,
			"Popup pointer follows the active category button"
		)
		check.call(
			(dashboard.get_node("%CategoryTitle") as Label).text.begins_with(CardCategoryBar.NAVIGATION_TITLES[index]),
			"Popup title identifies the selected category"
		)
		var shown: int = 0
		for child: Node in row.get_children():
			var card: VillageCardButton = child as VillageCardButton
			var matches: bool = index == 0 or int(card.card.kind) + 1 == index
			check.call(card.visible == matches, "Category uses native card kind")
			if card.visible:
				shown += 1
		check.call(
			(dashboard.hand_panel.get_node("%EmptyCategory") as Label).visible == (shown == 0),
			"Empty category shows a clear explanation"
		)
		check.call(button.button_pressed, "Expanded category has an active highlight")
		await _click(tree, viewport, button)
		check.call(not dock.is_expanded(), "Repeated category click collapses the tray")
		check.call(bar.is_visible_in_tree(), "Category bar remains accessible while collapsed")
		var enter: InputEventKey = InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.pressed = true
		viewport.push_input(enter, true)
		await tree.process_frame
	check.call(game.state.actions_used == before, "Category input consumes no actions")
	check.call(game.state.resources == resources, "Category input consumes no resources")
	await _click(tree, viewport, bar.get_node("All/Button") as Button)
	check.call(
		(dashboard.detail.get_node("%EmptyHint") as Label).visible,
		"Switching categories clears the previous confirmation"
	)


static func _click(tree: SceneTree, viewport: Viewport, button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	await tree.process_frame
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		viewport.push_input(event, true)
	await tree.process_frame
	await tree.process_frame
