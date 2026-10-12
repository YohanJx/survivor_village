class_name VillagePresentationRegression
extends RefCounted
## 营地地面依据实际建筑扩展，探索不赠建筑或改写资源发现。


static func run(check: Callable) -> void:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(65012)
	_test_art_validation(state, check)
	var base: Array[Rect2] = WorldLayout.camp_areas(WorldLayout.active_structures(state))
	var before: Rect2 = _bounds(base)
	var snapshot: VillageSaveData = state.snapshot()
	SurvivalTestSetup.developed(state)
	var explored: Array[Rect2] = WorldLayout.camp_areas(WorldLayout.active_structures(state))
	check.call(base == explored, "Exploration alone never expands built camp clearings")
	state.buildings[GameTypes.Building.FOOD_STORE] = 1
	var constructed: Array[Rect2] = WorldLayout.camp_areas(WorldLayout.active_structures(state))
	check.call(
		constructed.size() > base.size() and _bounds(constructed).get_area() > before.get_area(),
		"New visible storage construction expands cleared camp footprint"
	)
	check.call(
		state.resources == snapshot.resources,
		"Presentation footprint queries do not alter resource inventory"
	)
	var discoveries: PackedInt32Array = state.progress.discoveries.duplicate()
	WorldLayout.camp_areas(WorldLayout.active_structures(state))
	check.call(
		state.progress.discoveries == discoveries, "Camp presentation grants no hidden discoveries"
	)


static func _bounds(areas: Array[Rect2]) -> Rect2:
	var result: Rect2 = areas[0]
	for area: Rect2 in areas:
		result = result.merge(area)
	return result


static func _test_art_validation(state: VillageState, check: Callable) -> void:
	var paths: Dictionary[String, bool] = {}
	for card: CardDefinition in state.catalog.library.cards:
		check.call(
			card.illustration != null, "Every registered development card has art: " + card.id
		)
		if card.illustration == null:
			continue
		check.call(
			not paths.has(card.illustration.resource_path),
			"Development cards do not share artwork: " + card.id
		)
		paths[card.illustration.resource_path] = true
	var library: CardLibrary = state.catalog.library.duplicate(false) as CardLibrary
	library.cards = state.catalog.library.cards.duplicate()
	var clone: CardDefinition = library.cards[0].duplicate(false) as CardDefinition
	clone.illustration = null
	library.cards[0] = clone
	var rejected: CardCatalog = CardCatalog.new(library, false)
	check.call(
		not rejected.is_valid and rejected.validation_error.contains("插画"),
		"Missing registered card art rejects library without publishing partial definitions"
	)
	check.call(
		state.catalog.library.cards[0].illustration != null,
		"Invalid artwork clone leaves shared live art intact"
	)
