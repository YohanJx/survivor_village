class_name CardInspectionUiRegression
extends RefCounted
## 实际右键（含词条区域）、只读模态、关闭路径与夜战暂停验证。


static func run(tree: SceneTree, game: VillageGame, check: Callable, capture: Callable) -> void:
	var dashboard: VillageDashboard = game.get_node("Dashboard") as VillageDashboard
	var overlay: VillageGameOverlay = dashboard.overlay
	var card: VillageCardButton = _card(dashboard, "forage")
	var scroll: ScrollContainer = dashboard.hand_panel.get_node("HandScroll") as ScrollContainer
	scroll.ensure_control_visible(card)
	await tree.process_frame
	check.call(
		card.get_global_rect().encloses((card.get_node("%CardFace") as Control).get_global_rect()),
		"Hand artwork fits its interactive card"
	)
	var resources: PackedInt32Array = game.state.resources.duplicate()
	var actions: int = game.state.actions_used
	var selected: String = (dashboard.detail.get_node("%CardTitle") as Label).text
	await _right_click(tree, card.get_node("%Keywords") as Control)
	var inspection: CardInspectionPanel = overlay.get_node("%CardInspection") as CardInspectionPanel
	check.call(
		overlay.visible and inspection.visible, "Right-clicking a keyword opens card inspection"
	)
	check.call(
		(
			(
				(inspection.get_node("%InspectionFace/%FaceTitle") as Label).text
				== card.card.display_name
			)
			and (
				(inspection.get_node("%InspectDescription") as RichTextLabel)
				. get_parsed_text()
				. contains(card.card.description)
			)
		),
		"Centered inspection shows the chosen card and complete description"
	)
	check.call(
		(dashboard.detail.get_node("%CardTitle") as Label).text == selected,
		"Right-click inspection preserves the left-click selection"
	)
	await _key(tree, KEY_ENTER)
	check.call(
		game.state.resources == resources and game.state.actions_used == actions,
		"Enter inside read-only inspection cannot spend resources or an action"
	)
	await capture.call("ui_card_inspection")
	var original_size: Vector2i = tree.root.size
	tree.root.size = Vector2i(1024, 768)
	for frame: int in 3:
		await tree.process_frame
	check.call(
		tree.root.get_visible_rect().encloses(inspection.get_global_rect()),
		"Card inspection fits a small window"
	)
	await capture.call("ui_card_inspection_small")
	check.call(
		not (inspection.get_node("%InspectScroll") as Control).visible,
		"Additional card notes start collapsed"
	)
	await CardUiRegression.click(tree, inspection.get_node("%InspectMore") as Control)
	check.call(
		(inspection.get_node("%InspectScroll") as Control).visible,
		"More information exposes complete card notes"
	)
	await tree.process_frame
	check.call(
		tree.root.get_visible_rect().encloses(inspection.get_global_rect()),
		"Expanded notes fit the small viewport"
	)
	await capture.call("ui_card_inspection_notes")
	await CardUiRegression.click(tree, inspection.get_node("%InspectMore") as Control)
	await _check_faces(tree, game.state, inspection, check)
	await _key(tree, KEY_ESCAPE)
	check.call(not overlay.visible, "Esc closes inspection")
	tree.root.size = original_size
	for frame: int in 3:
		await tree.process_frame
	await _right_click(tree, card)
	await CardUiRegression.click(tree, inspection.get_node("%InspectClose") as Control)
	check.call(not overlay.visible, "Inspection close button returns to the game")
	await _right_click(tree, card)
	await _background_click(tree)
	check.call(not overlay.visible, "Clicking the dark background closes inspection")
	await _right_click(tree, card)
	game.state.new_run(98765, GameTypes.Region.RURAL)
	check.call(
		not inspection.visible and not overlay.visible,
		"Replacing the run closes inspection and starts the day directly"
	)
	game.state.new_run(12345)
	SurvivalTestSetup.developed(game.state)
	game.state.changed.emit()
	await _check_night(tree, game, dashboard, check)


static func _check_night(
	tree: SceneTree, game: VillageGame, dashboard: VillageDashboard, check: Callable
) -> void:
	game.state.begin_night()
	var card: VillageCardButton = _card(dashboard, "forage")
	await _right_click(tree, card)
	var elapsed: float = game.battle.elapsed
	await tree.create_timer(0.15).timeout
	check.call(
		dashboard.overlay.visible and is_equal_approx(game.battle.elapsed, elapsed),
		"Locked night card can be inspected and inspection pauses battle"
	)
	dashboard.overlay.close_modal()
	await tree.create_timer(0.15).timeout
	check.call(game.battle.elapsed > elapsed, "Closing inspection resumes battle")
	game.state.new_run(12345)
	SurvivalTestSetup.developed(game.state)
	game.state.changed.emit()


static func _card(dashboard: VillageDashboard, id: String) -> VillageCardButton:
	for child: Node in dashboard.hand_panel.get_node("%HandContainer").get_children():
		var card: VillageCardButton = child as VillageCardButton
		if card.card.id == id:
			return card
	return null


static func _right_click(tree: SceneTree, control: Control) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * Vector2(8, 8)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		tree.root.push_input(event, true)
	await tree.process_frame


static func _background_click(tree: SceneTree) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = Vector2(8, 8)
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		tree.root.push_input(event, true)
	await tree.process_frame


static func _key(tree: SceneTree, key: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		tree.root.push_input(event, true)
	await tree.process_frame


static func _check_faces(
	tree: SceneTree, state: VillageState, inspection: CardInspectionPanel, check: Callable
) -> void:
	var face: VillageCardFace = inspection.get_node("%InspectionFace") as VillageCardFace
	var rules: RichTextLabel = face.get_node("%FaceRules") as RichTextLabel
	for definition: CardDefinition in state.catalog.library.cards:
		face.update_view(state, definition)
		await tree.process_frame
		await tree.process_frame
		check.call(
			rules.get_content_height() <= rules.size.y,
			"Complete effect fits card: " + definition.id
		)
		check.call(
			(
				(face.get_node("%FaceCosts") as CardCostStrip).displayed_totals()
				== EffectResolver.cost_totals(definition, state)
			),
			"Every card resource cost follows shared query: " + definition.id
		)
