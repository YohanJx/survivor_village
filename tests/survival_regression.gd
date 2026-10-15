class_name SurvivalRegression
extends RefCounted
## 新开局、地形与职业准入、工具井位事务、存储与兼容行为。


static func run(check: Callable) -> void:
	_test_opening(check)
	_test_supply_window(check)
	_test_water_development(check)
	_test_first_night(check)
	_test_professions(check)
	_test_wells(check)
	_test_storage(check)
	_test_save_validation(check)
	_test_configuration(check)


static func _fresh(region: GameTypes.Region = GameTypes.Region.RURAL) -> VillageState:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(65012, region)
	return state


static func _uid(state: VillageState, id: String) -> int:
	for entry: CardInstance in state.hand:
		if entry.definition.id == id:
			return entry.uid
	return -1


static func _win(state: VillageState) -> void:
	var report: BattleReport = BattleReport.new()
	report.core_health = state.core_health
	report.started_survivors = state.population
	report.survivors = state.population
	report.has_identities = true
	report.consumed.resize(GameTypes.Stock.COUNT)
	for person: SurvivorRecord in state.progress.survivors:
		report.survivor_ids.append(person.id)
	state.finish_night(report)
	if state.phase == GameTypes.Phase.DAY_END:
		SurvivalTestSetup.settle_day_end(state)


static func _test_opening(check: Callable) -> void:
	for region: int in GameTypes.Region.COUNT:
		var state: VillageState = _fresh(region as GameTypes.Region)
		check.call(
			state.hand.size() == 1 and _uid(state, "explore") > 0,
			"Day one grants only terrain surveying"
		)
		check.call(
			state.progress.discoveries.is_empty(), "Map resources are unknown before surveying"
		)
		state.add_card(state.catalog.get_card("water"))
		var before: VillageSaveData = state.snapshot()
		check.call(
			not state.play_card(_uid(state, "water")), "Injected water card cannot bypass day one"
		)
		check.call(
			(
				state.resources == before.resources
				and state.rng.state == before.rng_state
				and state.slot == 0
			),
			"Failed prerequisite has no resource, RNG or time effect"
		)
		check.call(_explore(state), "First survey is playable with general villagers")
		check.call(_uid(state, "forage") == -1, "Discoveries do not open work on day one")
		var has_river: bool = state.progress.discoveries.has(GameTypes.Discovery.RIVER)
		check.call(
			state.progress.discoveries.has(GameTypes.Discovery.RIVER) == has_river,
			"Survey reports only generated sources"
		)
		_explore(state)
		_explore(state)
		check.call(
			state.phase == GameTypes.Phase.NIGHT and state.progress.terrain_surveys == 3,
			"Three surveys complete the first day"
		)
		_win(state)
		has_river = state.progress.discoveries.has(GameTypes.Discovery.RIVER)
		check.call(
			state.day == 2 and state.phase == GameTypes.Phase.DAY, "Opening reaches the second day"
		)
		check.call(
			(
				state.resources[GameTypes.Stock.FOOD] > 0
				and state.resources[GameTypes.Stock.WATER] > 0
			),
			"Portable supplies survive the first night"
		)
		check.call(
			(
				SurvivalRules.unlock_error(state, state.catalog.get_card("water")).is_empty()
				== has_river
			),
			"River water stays unavailable on dry maps"
		)
		check.call(
			(
				(
					(_uid(state, "well_tools") > 0)
					== (
						SurvivalRules
						. unlock_error(state, state.catalog.get_card("well_tools"))
						. is_empty()
					)
				)
				and _uid(state, "food_store") > 0
			),
			"Critical survival steps are granted without random rewards"
		)
		check.call(
			_uid(state, "well") == -1 and _uid(state, "well_survey") == -1,
			"Drilling and well surveying stay closed until tools"
		)
	var skipped: VillageState = _fresh()
	skipped.skip_slot()
	skipped.skip_slot()
	skipped.skip_slot()
	_win(skipped)
	check.call(
		skipped.day == 2 and _uid(skipped, "forage") == -1,
		"Skipping all surveys cannot unlock unseen resources or trap an empty reward screen"
	)


static func _test_professions(check: Callable) -> void:
	var state: VillageState = _fresh()
	_explore(state)
	state.begin_night()
	_win(state)
	check.call(
		state.assign_jobs(PackedInt32Array([5, 0, 0, 0, 0, 0])),
		"General workforce assignment accepted"
	)
	var before: VillageSaveData = state.snapshot()
	check.call(
		not state.play_card(_uid(state, "forage")),
		"Losing a required worker locks an existing card"
	)
	check.call(
		state.resources == before.resources and state.slot == before.slot,
		"Missing professional never charges higher stamina to execute"
	)
	for event: DailyEvent in state.catalog.library.progression_rules.day_end_events:
		for card: CardDefinition in event.options:
			check.call(
				card.profession == GameTypes.Profession.GENERAL,
				"Day-end events remain accessible without specialized professions"
			)
	var untrained: VillageState = _fresh()
	untrained.assign_jobs(PackedInt32Array([5, 0, 0, 0, 0, 0]))
	_explore(untrained)
	untrained.begin_night()
	_win(untrained)
	check.call(
		_uid(untrained, "forage") == -1 and _uid(untrained, "well_tools") == -1,
		"Absent professions never receive new specialist cards"
	)
	check.call(
		untrained.assign_jobs(PackedInt32Array([0, 1, 1, 1, 1, 1])),
		"Specialist reassignment accepted before work"
	)
	check.call(
		_uid(untrained, "forage") > 0 and _uid(untrained, "food_store") > 0,
		"Adding a professional grants eligible work once"
	)
	var size: int = untrained.hand.size()
	SurvivalRules.grant_available(untrained)
	check.call(untrained.hand.size() == size, "Repeated unlock refresh does not duplicate cards")


static func _test_wells(check: Callable) -> void:
	var state: VillageState = _fresh(GameTypes.Region.MOUNTAIN)
	SurvivalTestSetup.developed(state)
	state.progress.well_tools = false
	state.progress.well_sites.clear()
	state.progress.well_surveys = 0
	state.progress.well_drill_attempts = 0
	state.progress.completed_cards.erase("well_tools")
	state.progress.completed_cards.erase("well_survey")
	state.progress.completed_cards.erase("well")
	for index: int in range(state.hand.size() - 1, -1, -1):
		if state.hand[index].definition.id in ["well", "well_survey"]:
			state.hand.remove_at(index)
	state.progress.granted_cards.erase("well")
	state.progress.granted_cards.erase("well_survey")
	state.resources[GameTypes.Stock.STAMINA] = 100
	check.call(
		state.play_card(_uid(state, "well_tools")), "Builder makes tools before surveying a well"
	)
	check.call(
		state.progress.well_tools and _uid(state, "well_survey") > 0,
		"Tool completion opens well-site surveying"
	)
	check.call(_uid(state, "well") == -1, "Tools alone do not open drilling")
	var first_cell: Vector2i = SurvivalTestSetup.select_well_candidate(state)
	check.call(state.play_card(_uid(state, "well_survey")), "Gatherer surveys a specific prepared well site")
	check.call(
		state.progress.well_surveys == 1 and _uid(state, "well") > 0,
		"One site survey opens drilling"
	)
	var chance: float = SurvivalRules.well_chance(state)
	var card: CardDefinition = state.catalog.get_card("well")
	var before: VillageSaveData = state.snapshot()
	state.preview_card(card)
	check.call(
		(
			state.rng.state == before.rng_state
			and state.progress.well_surveys == 1
			and state.buildings[GameTypes.Building.WELL] == 0
		),
		"Drill preview consumes neither RNG nor real progress"
	)
	SurvivalTestSetup.force_drill_result(state, false)
	before = state.snapshot()
	var costs: PackedInt32Array = EffectResolver.cost_totals(card, state)
	check.call(state.play_card(_uid(state, "well")), "Failed drilling is a committed paid attempt")
	check.call(state.last_card_result.contains("打井失败"), "Failed drilling preserves the actual outcome for UI feedback")
	check.call(
		(
			state.buildings[GameTypes.Building.WELL] == 0
			and state.find_card(_uid(state, "well")) != null
		),
		"Failure builds nothing and retains retry action"
	)
	check.call(
		(
			state.resources[GameTypes.Stock.STONE]
			== before.resources[GameTypes.Stock.STONE] - costs[GameTypes.Stock.STONE]
		),
		"Failed drilling consumes quoted stone exactly once"
	)
	check.call(
		state.phase == GameTypes.Phase.NIGHT and state.rng.state != before.rng_state,
		"Actual attempt advances time and random sequence"
	)
	check.call(
		not state.progress.completed_cards.has("well"),
		"Failed drilling does not record completed construction"
	)
	check.call(
		state.progress.well_drill_attempts == 1 and not state.can_play(_uid(state, "well")).is_empty(),
		"One site survey funds only one drill attempt"
	)
	_win(state)
	state.resources[GameTypes.Stock.STAMINA] = 100
	state.resources[GameTypes.Stock.STONE] = 100
	check.call(not state.select_well_site(first_cell), "A dry position cannot be selected or surveyed again")
	var second_cell: Vector2i = SurvivalTestSetup.select_well_candidate(state)
	check.call(second_cell != first_cell and second_cell.x >= 0, "Failure requires a different real map position")
	check.call(state.play_card(_uid(state, "well_survey")), "Another position can be surveyed after a dry attempt")
	check.call(is_equal_approx(SurvivalRules.well_chance(state), chance) and chance < 1.0,
		"Surveying different positions does not accumulate a guaranteed water result")
	SurvivalTestSetup.force_drill_result(state, true)
	check.call(
		state.play_card(_uid(state, "well")) and state.buildings[GameTypes.Building.WELL] == 1,
		"A different surveyed position can yield water"
	)
	check.call(state.last_card_result.contains("打井成功"), "Successful drilling preserves the actual outcome for UI feedback")
	check.call(
		_uid(state, "well_water") > 0 and _uid(state, "water") == -1,
		"A dry map opens well collection after successful drilling"
	)
	state.resources[GameTypes.Stock.FOOD] = 10
	check.call(
		state.play_card(_uid(state, "well_water")), "Completed well supplies water during the day"
	)


static func _test_storage(check: Callable) -> void:
	var state: VillageState = _fresh()
	state.resources[GameTypes.Stock.FOOD] = 60
	state.resources[GameTypes.Stock.WATER] = 60
	state.resources[GameTypes.Stock.POWER] = 40
	state.resources[GameTypes.Stock.WOOD] = 30
	state.buildings[GameTypes.Building.FOOD_STORE] = 1
	state.buildings[GameTypes.Building.BATTERY] = 1
	state.begin_night()
	state.night_stats.income.fill(0)
	state.night_stats.upkeep.fill(0)
	_win(state)
	check.call(
		(
			state.resources[GameTypes.Stock.FOOD] == 60
			and state.resources[GameTypes.Stock.POWER] == 24
		),
		"Storage preserves only its matching capacity"
	)
	check.call(
		(
			state.resources[GameTypes.Stock.WATER] == 30
			and state.resources[GameTypes.Stock.WOOD] == 30
		),
		"Backpack caps water while durable materials persist"
	)
	var closed: VillageSaveData = state.snapshot()
	state.advance_dawn()
	check.call(
		state.resources == closed.resources, "Repeated dawn cannot clear or charge stock again"
	)
	var hungry: VillageState = _fresh()
	hungry.resources[GameTypes.Stock.FOOD] = 5
	hungry.resources[GameTypes.Stock.WATER] = 5
	hungry.begin_night()
	hungry.night_stats.income.fill(0)
	_win(hungry)
	check.call(
		(
			hungry.core_health == hungry.core_max_health
			and hungry.resources[GameTypes.Stock.FOOD] == 0
		),
		"Consumption happens before unpreserved stock is discarded"
	)


static func _test_save_validation(check: Callable) -> void:
	var state: VillageState = _fresh(GameTypes.Region.MOUNTAIN)
	SurvivalTestSetup.developed(state)
	var snapshot: VillageSaveData = state.snapshot()
	var restored: VillageState = _fresh()
	check.call(restored.restore(snapshot), "Discovery and well progress roundtrip")
	check.call(
		(
			restored.progress.well_surveys == 1
			and restored.progress.well_drill_attempts == state.progress.well_drill_attempts
			and restored.progress.discoveries == state.progress.discoveries
		),
		"Saved discoveries and specific well position survive restore"
	)
	snapshot.progress.discoveries.append(GameTypes.Discovery.RIVER)
	var before: VillageSaveData = restored.snapshot()
	check.call(
		(
			not restored.restore(snapshot)
			and restored.resources == before.resources
			and restored.rng.state == before.rng_state
		),
		"Fabricated dry-map river is rejected without changing live state"
	)
	snapshot = state.snapshot()
	snapshot.progress.well_drill_attempts = snapshot.progress.well_surveys + 1
	check.call(not restored.restore(snapshot), "A save cannot contain more drill attempts than site surveys")
	snapshot = state.snapshot()
	snapshot.progress.well_tools = false
	check.call(not restored.restore(snapshot), "Well-site knowledge without tools is rejected")
	snapshot = state.snapshot()
	snapshot.progress.granted_cards.append("unknown_card")
	check.call(not restored.restore(snapshot), "Unknown unlock identifiers are rejected")
	snapshot = state.snapshot()
	snapshot.version = 5
	snapshot.buildings.resize(13)
	# 旧版新局必有黎明事件 ID，构造符合旧版本格式的迁移样本。
	snapshot.progress.event_id = "settle"
	snapshot.progress.event_choice = 1
	snapshot.buildings.resize(13)
	check.call(
		restored.restore(snapshot) and restored.buildings.size() == GameTypes.Building.COUNT,
		"Version five migrates added storage slots in memory"
	)
	check.call(
		snapshot.version == 5 and snapshot.buildings.size() == 13,
		"Migration does not rewrite old input"
	)
	check.call(
		restored.restore(restored.snapshot()), "Migrated state passes current save validation"
	)


static func _test_first_night(check: Callable) -> void:
	for region: GameTypes.Region in [
		GameTypes.Region.MOUNTAIN, GameTypes.Region.RURAL, GameTypes.Region.RUINS
	]:
		var state: VillageState = _fresh(region)
		for action: int in 3:
			_explore(state)
		var battle: BattleSimulation = BattleSimulation.new()
		battle.finished.connect(state.finish_night)
		battle.start(state)
		while battle.active:
			battle.step(BattleSimulation.FIXED_STEP_SECONDS)
		check.call(
			state.last_report != null and state.phase == GameTypes.Phase.DAY_END,
			"Exploration-only opening survives a real first night on map %d" % region
		)


static func _test_configuration(check: Callable) -> void:
	var state: VillageState = _fresh()
	var card: CardDefinition = state.catalog.get_card("water").duplicate(false) as CardDefinition
	var keyword: KeywordDefinition = card.keywords.back().duplicate(false) as KeywordDefinition
	keyword.discovery = GameTypes.Discovery.COUNT
	card.keywords = card.keywords.duplicate()
	card.keywords[card.keywords.size() - 1] = keyword
	check.call(
		not ResourceValidation.card_error(card, state.catalog.buildings).is_empty(),
		"Unknown geography prerequisite is rejected"
	)
	card = state.catalog.get_card("explore").duplicate(false) as CardDefinition
	card.profession = GameTypes.Profession.ENGINEER
	check.call(
		not ResourceValidation.card_error(card, state.catalog.buildings).is_empty(),
		"Opening survey cannot require a specialist"
	)
	var library: CardLibrary = state.catalog.library.duplicate(false) as CardLibrary
	library.buildings = state.catalog.library.buildings.duplicate()
	var building: BuildingDefinition = (
		state.catalog.buildings[GameTypes.Building.FOOD_STORE].duplicate(false)
		as BuildingDefinition
	)
	building.storage = PackedInt32Array([-1, 0, 0])
	library.buildings[GameTypes.Building.FOOD_STORE] = building
	check.call(
		not CardCatalog.new(library, false).is_valid,
		"Negative preservation capacity prevents library publication"
	)
	library = state.catalog.library.duplicate(false) as CardLibrary
	library.progression_rules = (
		state.catalog.library.progression_rules.duplicate(false) as ProgressionRules
	)
	library.progression_rules.maps = state.catalog.library.progression_rules.maps.duplicate()
	var map: MapDefinition = library.progression_rules.maps[0].duplicate(false) as MapDefinition
	map.well_survey_gain = NAN
	library.progression_rules.maps[0] = map
	check.call(
		not CardCatalog.new(library, false).is_valid,
		"Non-finite well chance prevents library publication"
	)
	library = state.catalog.library.duplicate(false) as CardLibrary
	library.progression_rules = (
		state.catalog.library.progression_rules.duplicate(false) as ProgressionRules
	)
	library.progression_rules.portable_storage = PackedInt32Array([-1, 30, 0])
	check.call(
		not CardCatalog.new(library, false).is_valid,
		"Negative portable capacity prevents catalog publication"
	)
	library.progression_rules.portable_storage = PackedInt32Array([30, 30])
	check.call(
		not CardCatalog.new(library, false).is_valid,
		"Incomplete portable capacity prevents catalog publication"
	)
	check.call(
		(
			state.catalog.is_valid
			and state.catalog.buildings[GameTypes.Building.FOOD_STORE].storage[0] == 40
		),
		"Validation clones do not modify the live definitions"
	)


static func _explore(state: VillageState) -> bool:
	SurvivalTestSetup.select_frontier(state)
	return state.play_card(_uid(state, "explore"))


static func _test_supply_window(check: Callable) -> void:
	for region: GameTypes.Region in [
		GameTypes.Region.MOUNTAIN, GameTypes.Region.RURAL, GameTypes.Region.RUINS
	]:
		var state: VillageState = _fresh(region)
		for night: int in 3:
			while state.phase == GameTypes.Phase.DAY:
				state.skip_slot()
			_win(state)
			check.call(
				state.progress.hungry_days == 0 and state.progress.thirsty_days == 0,
				"Opening carry supplies cover the first three daily rations"
			)
		check.call(
			state.day == 4 and state.resources[GameTypes.Stock.WATER] > 0,
			"Supplies leave time to develop beyond day three"
		)
		var before: VillageSaveData = state.snapshot()
		OpeningRules.next_step(state)
		check.call(
			state.resources == before.resources and state.rng.state == before.rng_state,
			"Development advice has no resource or random side effects"
		)


static func _test_water_development(check: Callable) -> void:
	for region: GameTypes.Region in [GameTypes.Region.MOUNTAIN, GameTypes.Region.RUINS]:
		var state: VillageState = _fresh(region)
		var target: Vector2i = TerrainGrid.CAMP
		for value: int in TerrainGrid.SIZE.x * TerrainGrid.SIZE.y:
			var cell: Vector2i = TerrainGrid.position(value)
			if (
				cell != TerrainGrid.CAMP
				and TerrainGrid.distance(cell) <= OpeningRules.SUPPLY_RADIUS
				and state.terrain_grid.biome(cell) == TerrainGrid.Biome.PLAIN
			):
				target = cell
				break
		var current: Vector2i = TerrainGrid.CAMP
		while current != target:
			if current.x != target.x:
				current.x += 1 if current.x < target.x else -1
			else:
				current.y += 1 if current.y < target.y else -1
			state.select_exploration(current)
			check.call(
				state.play_card(_uid(state, "explore")),
				"Groundwater candidate is reachable in the opening"
			)
		while state.phase == GameTypes.Phase.DAY:
			state.skip_slot()
		_win(state)
		state.weather = state.catalog.library.weather_rules.for_kind(WeatherDefinition.Kind.CLEAR)
		check.call(
			OpeningRules.next_step(state).contains("集雨棚"),
			"Advice offers a non-well water route after real terrain discovery"
		)
		for id: String in ["well_tools", "well_survey", "well"]:
			if id == "well_survey":
				SurvivalTestSetup.select_well_candidate(state)
			if id == "well":
				SurvivalTestSetup.force_drill_result(state, true)
			check.call(
				state.play_card(_uid(state, id)),
				"Dry-map water route can be paid from opening supplies: " + id
			)
			if state.phase == GameTypes.Phase.NIGHT:
				_win(state)
		check.call(
			state.buildings[GameTypes.Building.WELL] == 1 and state.day <= 4,
			"A water-bearing position can supply a well by day four without injected supplies"
		)
		check.call(
			state.progress.hungry_days == 0 and state.progress.thirsty_days == 0,
			"Water development finishes before carry supplies run out"
		)
		check.call(
			OpeningRules.next_step(state).contains("扩充储水"),
			"Advice advances to storage after water source construction"
		)
