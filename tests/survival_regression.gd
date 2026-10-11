class_name SurvivalRegression
extends RefCounted
## 新开局、地形与职业准入、工具井位事务、存储与兼容行为。


static func run(check: Callable) -> void:
	_test_opening(check)
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
	state.choose_daily_event(1)
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
	if state.phase == GameTypes.Phase.REWARD:
		state.choose_reward(0)
	state.choose_daily_event(1)


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
				state.resources[GameTypes.Stock.FOOD] == 0
				and state.resources[GameTypes.Stock.WATER] == 0
			),
			"Opening provisions cannot carry over without storage"
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
	state.generate_rewards()
	for card: CardDefinition in state.rewards:
		check.call(
			card.profession == GameTypes.Profession.GENERAL, "Rewards exclude absent professions"
		)
	state.rewards.clear()
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
	_explore(state)
	state.begin_night()
	_win(state)
	state.resources[GameTypes.Stock.STAMINA] = 100
	check.call(
		state.play_card(_uid(state, "well_tools")), "Builder makes tools before surveying a well"
	)
	check.call(
		state.progress.well_tools and _uid(state, "well_survey") > 0,
		"Tool completion opens well-site surveying"
	)
	check.call(_uid(state, "well") == -1, "Tools alone do not open drilling")
	check.call(state.play_card(_uid(state, "well_survey")), "Gatherer surveys a prepared well site")
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
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	for seed_value: int in range(1, 100):
		generator.seed = seed_value
		if generator.randf() >= chance:
			state.rng.seed = seed_value
			break
	before = state.snapshot()
	var costs: PackedInt32Array = EffectResolver.cost_totals(card, state)
	check.call(state.play_card(_uid(state, "well")), "Failed drilling is a committed paid attempt")
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
	_win(state)
	state.resources[GameTypes.Stock.STAMINA] = 100
	state.resources[GameTypes.Stock.STONE] = 100
	state.progress.well_surveys = 5
	check.call(
		(
			SurvivalRules.well_chance(state) > chance
			and is_equal_approx(SurvivalRules.well_chance(state), 1.0)
		),
		"More surveying raises chance to a bounded guarantee"
	)
	check.call(
		state.play_card(_uid(state, "well")) and state.buildings[GameTypes.Building.WELL] == 1,
		"Fully surveyed site builds a well"
	)
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
			state.resources[GameTypes.Stock.FOOD] == 40
			and state.resources[GameTypes.Stock.POWER] == 24
		),
		"Storage preserves only its matching capacity"
	)
	check.call(
		state.resources[GameTypes.Stock.WATER] == 0 and state.resources[GameTypes.Stock.WOOD] == 30,
		"Missing water storage clears water while durable materials persist"
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
			restored.progress.well_surveys == 5
			and restored.progress.discoveries == state.progress.discoveries
		),
		"Saved discoveries and chance survive restore"
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
	snapshot.progress.well_tools = false
	check.call(not restored.restore(snapshot), "Well-site knowledge without tools is rejected")
	snapshot = state.snapshot()
	snapshot.progress.granted_cards.append("unknown_card")
	check.call(not restored.restore(snapshot), "Unknown unlock identifiers are rejected")
	snapshot = state.snapshot()
	snapshot.version = 5
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
			state.last_report != null and state.phase == GameTypes.Phase.REWARD,
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
