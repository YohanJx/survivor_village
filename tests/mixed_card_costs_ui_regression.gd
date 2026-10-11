class_name MixedCardCostsUiRegression
extends RefCounted
## 多资源费用的真实显示、缺口标色与近距离确认；不改变共享卡牌定义。


static func run(tree: SceneTree, game: VillageGame, check: Callable) -> void:
	var dashboard: VillageDashboard = game.get_node("Dashboard") as VillageDashboard
	for child: Node in dashboard.hand_panel.get_node("%HandContainer").get_children():
		var hand_card: VillageCardButton = child as VillageCardButton
		var art: TextureRect = hand_card.get_node("%CardFace/%FaceArt") as TextureRect
		check.call(
			art.is_visible_in_tree() and art.size.y >= 90.0 and art.texture != null,
			"Hand shows prominent illustration: " + hand_card.card.id
		)
		var summary: Label = hand_card.get_node("%CardFace/%FaceSummary") as Label
		check.call(
			not summary.text.is_empty() and summary.size.y >= 30.0,
			"Hand effect has readable space: " + hand_card.card.id
		)
	var face: VillageCardFace = (
		dashboard.overlay.get_node("%CardInspection/%InspectionFace") as VillageCardFace
	)
	var card: CardDefinition = CardDefinition.new()
	card.display_name = "多资源费用检查"
	card.positive = "加固设施"
	card.negative = "施工噪音增加"
	for key: int in [
		GameTypes.Stock.STAMINA,
		GameTypes.Stock.WOOD,
		GameTypes.Stock.PARTS,
		GameTypes.Stock.FUEL,
		GameTypes.Stock.FOOD
	]:
		var cost: ResourceCost = ResourceCost.new()
		cost.key = key as GameTypes.Stock
		cost.amount = 4
		card.costs.append(cost)
	var repeated: ResourceCost = ResourceCost.new()
	repeated.key = GameTypes.Stock.WOOD
	repeated.amount = 6
	card.costs.append(repeated)
	var original: PackedInt32Array = game.state.resources.duplicate()
	game.state.resources[GameTypes.Stock.WOOD] = 0
	face.update_view(game.state, card)
	await tree.process_frame
	var risk: RichTextLabel = face.get_node("%FaceRisk") as RichTextLabel
	check.call(
		risk.visible and risk.get_parsed_text() == card.negative,
		"Expanded card displays its complete risk"
	)
	var strip: CardCostStrip = face.get_node("%FaceCosts") as CardCostStrip
	var count: int = 0
	for child: Node in strip.get_children():
		if not child is PanelContainer or not (child as Control).visible:
			continue
		count += 1
		var label: Label = child.get_node("Amount") as Label
		if label.text.begins_with("木材"):
			check.call(
				label.text == "木材 10", "Duplicate wood costs display as one merged resource item"
			)
			check.call(
				label.get_theme_color("font_color") == UiElements.NEGATIVE,
				"Insufficient resource is marked on its own cost chip"
			)
	check.call(count == 5, "All five resource costs appear together")
	check.call(
		(
			strip.displayed_totals()[GameTypes.Stock.PARTS] == 4
			and strip.displayed_totals()[GameTypes.Stock.FUEL] == 4
		),
		"Secondary crafting resources remain visible"
	)
	game.state.resources = original
	game.state.changed.emit()
	if not game.state.hand.is_empty():
		dashboard.card_selected.emit(game.state.hand[0].uid)
	await tree.process_frame
	await tree.process_frame
	var costs: Control = dashboard.detail.get_node("%SelectedCosts") as Control
	var execute: Control = dashboard.detail.get_node("%ExecuteButton") as Control
	check.call(
		execute.get_parent() == costs.get_parent(),
		"Costs and confirmation belong to the same action plan"
	)
	check.call(
		execute.get_global_rect().position.y - costs.get_global_rect().end.y <= 100.0,
		"Confirmation stays directly beside the selected action costs"
	)
	check.call(
		dashboard.detail.get_parent() == dashboard.hand_panel.get_parent(),
		"Hand and selected action share the bottom operation tray"
	)
