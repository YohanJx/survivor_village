class_name KeywordRegression
extends RefCounted
## 词条对象图、联合前置与真实地貌发现，不依赖展示文字执行规则。


static func run(check: Callable) -> void:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(65012, GameTypes.Region.RURAL)
	state.choose_daily_event(1)
	state.day = 2
	var well: CardDefinition = state.catalog.get_card("well_tools")
	var site: KeywordDefinition = well.keywords.back()
	check.call(
		not KeywordRules.requirement_error(state, site).is_empty(),
		"Camp alone never counts as a groundwater site"
	)
	var plain: int = -1
	var other: int = -1
	for value: int in TerrainGrid.SIZE.x * TerrainGrid.SIZE.y:
		if value == TerrainGrid.index(TerrainGrid.CAMP):
			continue
		if state.terrain_grid.biome(TerrainGrid.position(value)) == TerrainGrid.Biome.PLAIN:
			plain = value
		else:
			other = value
	check.call(plain >= 0 and other >= 0, "Fixture contains candidate and unsuitable terrain")
	state.progress.explored_cells.append(other)
	state.progress.terrain_surveys = 1
	check.call(
		not SurvivalRules.unlock_error(state, well).is_empty(),
		"Explored unsuitable terrain never opens well tools"
	)
	state.progress.explored_cells.append(plain)
	check.call(SurvivalRules.unlock_error(state, well).is_empty(), "Actual candidate opens tools")
	state.progress.well_tools = true
	state.progress.completed_cards.append("well_tools")
	var survey: CardDefinition = state.catalog.get_card("well_survey")
	check.call(SurvivalRules.unlock_error(state, survey).is_empty(), "Prepared survey opens")
	state.profession_counts[GameTypes.Profession.ENGINEER] = 0
	check.call(
		SurvivalRules.unlock_error(state, survey).contains("工程师"),
		"Survey needs an engineer as well as its gathering worker"
	)
	state.add_card(survey)
	var uid: int = state.hand.back().uid
	var before: VillageSaveData = state.snapshot()
	check.call(not state.play_card(uid), "An injected card cannot bypass joint requirements")
	check.call(
		(
			state.resources == before.resources
			and state.rng.state == before.rng_state
			and state.actions_used == before.actions_used
			and state.progress.well_surveys == 0
		),
		"Rejected combined prerequisite has no transaction side effects"
	)
	_test_definitions(state, check)
	_test_daily_upkeep(check)
	_test_event_registration(state, check)


static func _test_definitions(state: VillageState, check: Callable) -> void:
	var library: CardLibrary = state.catalog.library.duplicate(false) as CardLibrary
	library.cards = library.cards.duplicate()
	var card: CardDefinition = library.cards[0].duplicate(false) as CardDefinition
	card.keywords = card.keywords.duplicate()
	library.cards[0] = card
	var keyword: KeywordDefinition = card.keywords[0].duplicate(false) as KeywordDefinition
	card.keywords[0] = keyword
	check.call(
		not CardCatalog.new(library, false).is_valid,
		"Unregistered same-id keyword cannot impersonate canonical resource"
	)
	keyword.category = KeywordDefinition.Category.TERRAIN
	keyword.discovery = GameTypes.Discovery.COUNT
	check.call(not keyword.validation_error().is_empty(), "Invalid discovery selector rejected")
	keyword = (
		state.catalog.get_card("well_tools").keywords.back().duplicate(false) as KeywordDefinition
	)
	keyword.discovery = GameTypes.Discovery.RIVER
	check.call(not keyword.validation_error().is_empty(), "Ambiguous terrain selectors rejected")
	var terms: KeywordLibrary = (
		state.catalog.library.keyword_library.duplicate(false) as KeywordLibrary
	)
	terms.definitions = terms.definitions.duplicate()
	terms.definitions.append(terms.definitions[0])
	check.call(not terms.validation_error().is_empty(), "Duplicate keyword ids rejected")
	card = state.catalog.get_card("well_survey").duplicate(false) as CardDefinition
	card.keywords = card.keywords.duplicate()
	card.keywords.append(card.keywords[0])
	check.call(not KeywordRules.card_error(card).is_empty(), "Duplicate card keywords rejected")
	var before: VillageSaveData = state.snapshot()
	for candidate: CardDefinition in state.catalog.library.cards:
		SurvivalRules.unlock_error(state, candidate)
	check.call(
		state.rng.state == before.rng_state and state.resources == before.resources,
		"All keyword queries preserve RNG and inventory"
	)


static func _test_daily_upkeep(check: Callable) -> void:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(65012)
	state.buildings[GameTypes.Building.WORKSHOP] = 1
	state.buildings[GameTypes.Building.FARM] = 1
	var upkeep: PackedInt32Array = EffectResolver.daily_upkeep(state)
	check.call(
		(
			upkeep[GameTypes.Stock.FOOD] == state.population + 1
			and upkeep[GameTypes.Stock.WATER] == state.population + 3
		),
		"Daily upkeep includes population and facilities without netting income"
	)
	state.night_stats = EffectResolver.derive(state)
	state.phase = GameTypes.Phase.REWARD
	state.last_report = BattleReport.new()
	state.last_report.started_survivors = state.population
	state.population -= 2
	var frozen: PackedInt32Array = state.night_stats.upkeep.duplicate()
	upkeep = EffectResolver.daily_upkeep(state)
	check.call(
		(
			upkeep[GameTypes.Stock.FOOD] == state.population + 1
			and upkeep[GameTypes.Stock.WATER] == state.population + 3
		),
		"Reward-phase daily upkeep adjusts frozen consumption for survivors"
	)
	upkeep.fill(0)
	check.call(state.night_stats.upkeep == frozen, "Upkeep display cannot mutate dusk snapshot")


static func _test_event_registration(state: VillageState, check: Callable) -> void:
	var library: CardLibrary = state.catalog.library.duplicate(false) as CardLibrary
	library.progression_rules = library.progression_rules.duplicate(false) as ProgressionRules
	library.progression_rules.events = library.progression_rules.events.duplicate()
	var event: DailyEvent = library.progression_rules.events[0].duplicate(false) as DailyEvent
	library.progression_rules.events[0] = event
	event.options = event.options.duplicate()
	var option: CardDefinition = event.options[0].duplicate(false) as CardDefinition
	event.options[0] = option
	option.keywords = option.keywords.duplicate()
	option.keywords[0] = option.keywords[0].duplicate(false) as KeywordDefinition
	check.call(
		not CardCatalog.new(library, false).is_valid,
		"Event options cannot reference unregistered keyword objects"
	)
