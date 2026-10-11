class_name CardUiRegression
extends RefCounted
## 检查固定确认区、词条真实悬停与独立村庄窗口。


static func run(
	tree: SceneTree, dashboard: VillageDashboard, check: Callable, capture: Callable
) -> void:
	if DisplayServer.get_name() != "headless":
		tree.root.grab_focus()
		# 原生窗口的焦点申请异步完成；取得焦点后再移动系统光标。
		for attempt: int in 20:
			if tree.root.has_focus():
				break
			await tree.create_timer(0.05).timeout
	await tree.process_frame
	var row: HBoxContainer = dashboard.hand_panel.get_node("%HandContainer") as HBoxContainer
	var card: VillageCardButton
	for child: Node in row.get_children():
		var candidate: VillageCardButton = child as VillageCardButton
		if candidate.card.id == "forage":
			card = candidate
			break
	var hand_scroll: ScrollContainer = row.get_parent() as ScrollContainer
	hand_scroll.ensure_control_visible(card)
	await tree.process_frame
	await tree.process_frame
	var keywords: RichTextLabel = card.get_node("%Keywords") as RichTextLabel
	var point: Vector2 = keywords.get_global_transform_with_canvas() * Vector2(8, 8)
	var away: InputEventMouseMotion = InputEventMouseMotion.new()
	away.position = Vector2(5, 5)
	away.global_position = away.position
	if DisplayServer.get_name() != "headless":
		tree.root.warp_mouse(away.position)
	tree.root.push_input(away, true)
	await tree.process_frame
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	if DisplayServer.get_name() != "headless":
		tree.root.warp_mouse(point)
	tree.root.push_input(motion, true)
	var explanation: KeywordDefinition = KeywordText.definition("采集")
	check.call(
		keywords.get_tooltip(Vector2(8, 8)).contains(explanation.description),
		"Hovered word resolves the configured explanation"
	)
	for attempt: int in 8:
		if _has_tooltip(tree.root, explanation.description):
			break
		# 保持光标静止；重复移动会重启原生提示的悬停计时。
		await tree.create_timer(0.25).timeout
	check.call(
		_has_tooltip(tree.root, explanation.description),
		"Keyword hover creates the actual explanation tooltip"
	)
	await capture.call("ui_keyword_tooltip")
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	tree.root.push_input(event, true)
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	tree.root.push_input(event, true)
	await tree.process_frame
	check.call(
		(dashboard.detail.get_node("%CardTitle") as Label).text == card.card.display_name,
		"Clicking keyword still selects its card"
	)
	var button: Button = dashboard.detail.get_node("%ExecuteButton") as Button
	var scroll: ScrollContainer = dashboard.detail.get_node("%DetailScroll") as ScrollContainer
	check.call(
		button.visible and not button.disabled and button.get_parent() != scroll,
		"Selected card has a visible fixed confirmation button"
	)
	var risk: RichTextLabel = dashboard.detail.get_node("%Negative") as RichTextLabel
	var risk_before: Rect2 = risk.get_global_rect()
	var before: Rect2 = button.get_global_rect()
	scroll.scroll_vertical = 10000
	await tree.process_frame
	check.call(
		button.get_global_rect().is_equal_approx(before),
		"Scrolling effects does not move confirmation button"
	)
	check.call(
		risk.visible and risk.get_global_rect().is_equal_approx(risk_before),
		"Scrolling effects does not hide or move fixed risk"
	)
	check.call(
		(dashboard.detail.get_node("%SelectedCosts") as CardCostStrip).is_visible_in_tree(),
		"Adjusted fees remain visible outside scrolling effects"
	)
	var original_size: Vector2i = tree.root.size
	tree.root.size = Vector2i(1100, 760)
	await tree.process_frame
	await tree.process_frame
	check.call(
		button.get_global_rect().end.y <= dashboard.size.y,
		"Confirmation button fits a small window after selection"
	)
	check.call(
		(
			risk.get_global_rect().position.y >= dashboard.detail.get_global_rect().position.y
			and risk.get_global_rect().end.y <= button.get_global_rect().position.y
		),
		"Fixed risk fits a small window above confirmation"
	)
	tree.root.size = original_size
	await tree.process_frame
	scroll.scroll_vertical = 0
	check.call(
		KeywordText.format_text("水源").count("[hint=") == 1,
		"Longest keyword wins without nested tooltip markup"
	)
	check.call(
		KeywordText.format_text("[img]食物").begins_with("[lb]img]"),
		"Untrusted BBCode brackets are escaped"
	)


static func click(tree: SceneTree, control: Control) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	tree.root.push_input(event, true)
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	tree.root.push_input(event, true)
	await tree.process_frame


static func _has_tooltip(node: Node, explanation: String) -> bool:
	if node is Label and (node as Label).text.contains(explanation):
		return true
	for child: Node in node.get_children(true):
		if _has_tooltip(child, explanation):
			return true
	return false
