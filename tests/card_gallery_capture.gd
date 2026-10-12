class_name CardGalleryCapture
extends RefCounted
## 离屏逐页检查所有真实卡面；不修改卡牌定义、库存、阶段或玩家存档。

const GALLERY_SCENE: PackedScene = preload("res://tests/fixtures/card_gallery.tscn")
const CARD_SCENE: PackedScene = preload("res://scenes/ui/card_button.tscn")
const PAGE_SIZE: int = 18


static func run(
	viewport: SubViewport, state: VillageState, check: Callable, capture: Callable
) -> void:
	var previous_size: Vector2i = viewport.size
	var previous_override: Vector2i = viewport.size_2d_override
	viewport.size = Vector2i(1440, 1120)
	viewport.size_2d_override = viewport.size
	var paths: Dictionary[String, bool] = {}
	for card: CardDefinition in state.catalog.library.cards:
		check.call(card.illustration != null, "Registered card has individual art: " + card.id)
		if card.illustration != null:
			check.call(
				not paths.has(card.illustration.resource_path), "Art is distinct: " + card.id
			)
			paths[card.illustration.resource_path] = true
	var page_count: int = ceili(state.catalog.library.cards.size() / float(PAGE_SIZE))
	for page: int in page_count:
		var gallery: PanelContainer = GALLERY_SCENE.instantiate() as PanelContainer
		viewport.add_child(gallery)
		var heading: Label = gallery.get_node("%Heading") as Label
		heading.text = "余烬村庄 · 独立卡牌插画 · %d / %d" % [page + 1, page_count]
		var grid: GridContainer = gallery.get_node("%Cards") as GridContainer
		var views: Array[VillageCardButton] = []
		for index: int in range(
			page * PAGE_SIZE, mini((page + 1) * PAGE_SIZE, state.catalog.library.cards.size())
		):
			var view: VillageCardButton = CARD_SCENE.instantiate() as VillageCardButton
			view.card = state.catalog.library.cards[index]
			grid.add_child(view)
			view.update_face(state)
			views.append(view)
		await capture.call("individual_cards_gallery_%d" % (page + 1))
		_check_layout(views, Rect2(Vector2.ZERO, viewport.size), check)
		viewport.remove_child(gallery)
		gallery.queue_free()
	viewport.size = previous_size
	viewport.size_2d_override = previous_override


static func _check_layout(
	views: Array[VillageCardButton], viewport_rect: Rect2, check: Callable
) -> void:
	for view: VillageCardButton in views:
		check.call(
			viewport_rect.encloses(view.get_global_rect()),
			"Complete gallery card fits viewport: " + view.card.id
		)
		var face: VillageCardFace = view.get_node("%CardFace") as VillageCardFace
		var risk: Label = face.get_node("%FaceRiskSummary") as Label
		if not view.card.negative.is_empty():
			check.call(
				risk.get_visible_line_count() > 0,
				"Compact card actually renders its risk: " + view.card.id
			)
		var costs: Control = face.get_node("%FaceCosts") as Control
		check.call(
			view.get_global_rect().encloses(costs.get_global_rect()),
			"All fees stay within the compact card: " + view.card.id
		)
		check.call(
			view.get_global_rect().encloses(
				(view.get_node("%Keywords") as Control).get_global_rect()
			),
			"Keyword interaction stays within its card: " + view.card.id
		)
