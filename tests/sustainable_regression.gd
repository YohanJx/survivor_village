class_name SustainableRegression
extends RefCounted
## 替代水源、整批生产、共享原料预算、冻结结算及历史建筑数组迁移。


static func run(check: Callable) -> void:
	_test_water(check)
	_test_construction(check)
	_test_materials(check)
	_test_reservations(check)
	_test_frozen_settlement(check)
	_test_validation(check)
	_test_migration(check)


static func _test_water(check: Callable) -> void:
	var state: VillageState = _fresh()
	state.buildings[GameTypes.Building.RIVER_WINDMILL] = 1
	check.call(EffectResolver.derive(state).income[GameTypes.Stock.WATER] == 10, "River windmill supplies water without a well")
	check.call(state.buildings[GameTypes.Building.WELL] == 0, "River route never constructs a hidden well")
	check.call(SurvivalRules.unlock_error(state, state.catalog.get_card("filter")).is_empty(), "River intake can unlock filtration without groundwater")
	state.resources[GameTypes.Stock.POLLUTION] = 12
	check.call(EffectResolver.derive(state).income[GameTypes.Stock.WATER] == 7, "River intake suffers actual pollution loss")
	state.buildings[GameTypes.Building.FILTER] = 1
	check.call(EffectResolver.derive(state).income[GameTypes.Stock.WATER] == 10, "Filtration protects the river route")
	state.buildings[GameTypes.Building.RIVER_WINDMILL] = 0
	state.resources[GameTypes.Stock.POLLUTION] = 0
	state.buildings[GameTypes.Building.RAIN_COLLECTOR] = 1
	state.buildings[GameTypes.Building.SOLAR_STILL] = 1
	check.call(EffectResolver.derive(state).income[GameTypes.Stock.WATER] == 7, "Condensation and solar collection sustain five people on a dry clear map")
	var before: VillageSaveData = state.snapshot()
	check.call(OpeningRules.next_step(state).contains("扩充储水"), "Adequate alternative supply stops the guide from demanding drilling")
	check.call(state.rng.state == before.rng_state and state.resources == before.resources, "Production and development queries are read-only")
	state.weather = state.catalog.library.weather_rules.for_kind(WeatherDefinition.Kind.RAIN)
	check.call(EffectResolver.derive(state).income[GameTypes.Stock.WATER] == 13 + state.weather.water_income, "Rain adds the collector's own weather bonus to existing weather income")
	state.weather = state.catalog.library.weather_rules.for_kind(WeatherDefinition.Kind.CLEAR)
	SurvivalTestSetup.complete_well(state)
	state.buildings[GameTypes.Building.WELL_WINDPUMP] = 1
	check.call(EffectResolver.derive(state).income[GameTypes.Stock.WATER] == 21, "Wind lifting adds six water to the real well and other sources")
	state = _fresh()
	state.buildings[GameTypes.Building.RAIN_COLLECTOR] = 1
	state.buildings[GameTypes.Building.SOLAR_STILL] = 1
	state.buildings[GameTypes.Building.FARM] = 1
	state.buildings[GameTypes.Building.FORAGING_CAMP] = 1
	state.buildings[GameTypes.Building.GREENHOUSE] = 1
	state.resources[GameTypes.Stock.POWER] = 3
	var stats: VillageStats = EffectResolver.derive(state)
	check.call(stats.irrigation_active and stats.income[GameTypes.Stock.FOOD] == 15, "Alternative-source irrigation boosts the farm rather than every food industry")
	check.call(SurvivalRules.unlock_error(state, state.catalog.get_card("greenhouse")).is_empty(), "Irrigation accepts a non-well source without requiring a diesel generator")
	state.buildings[GameTypes.Building.RAIN_COLLECTOR] = 0
	state.buildings[GameTypes.Building.RIVER_WINDMILL] = 1
	state.profession_counts[GameTypes.Profession.ENGINEER] = 0
	check.call(not EffectResolver.derive(state).irrigation_active, "Stopped water sources cannot operate irrigation")
	state = _fresh()
	state.buildings[GameTypes.Building.FARM] = 1
	state.buildings[GameTypes.Building.FORAGING_CAMP] = 1
	state.progress.strategies[GameTypes.Strategy.CANAL] = 1
	check.call(EffectResolver.derive(state).income[GameTypes.Stock.FOOD] == 13, "Field canals boost farm output without multiplying foraging production")


static func _test_construction(check: Callable) -> void:
	var state: VillageState = _fresh()
	var uid: int = _uid(state, "river_windmill")
	check.call(state.can_play(uid).is_empty() and state.play_card(uid), "Discovered river permits actual windmill construction with starter resources")
	check.call(state.buildings[GameTypes.Building.RIVER_WINDMILL] == 1 and state.progress.completed_cards.has("river_windmill"), "River card commits a real facility and completion record")
	check.call(state.progress.well_drill_attempts == 0 and state.buildings[GameTypes.Building.WELL] == 0, "River construction never surveys or drills groundwater")
	check.call(state.play_card(_uid(state, "quarry")), "River upgrade obtains its additional stone through actual collection")
	check.call(state.play_card(_uid(state, "woodcut")), "River upgrade collects wood for the region's construction costs")
	_settle(state)
	uid = _uid(state, "water_channel")
	check.call(state.can_play(uid).is_empty() and state.play_card(uid), "Native water-channel technology upgrades the real river intake: " + state.can_play(uid))
	check.call(EffectResolver.derive(state).income[GameTypes.Stock.WATER] == 20, "Upgraded river intake actually doubles automatic supply")
	state = _fresh()
	state.progress.discoveries.erase(GameTypes.Discovery.RIVER)
	check.call(not SurvivalRules.unlock_error(state, state.catalog.get_card("river_windmill")).is_empty(), "An undiscovered river cannot unlock windmill construction")


static func _test_materials(check: Callable) -> void:
	var state: VillageState = _fresh()
	for building: GameTypes.Building in [GameTypes.Building.SAWMILL, GameTypes.Building.QUARRY,
		GameTypes.Building.SALVAGE_YARD, GameTypes.Building.FLETCHER, GameTypes.Building.HERB_GARDEN]:
		state.buildings[building] = 1
	var stats: VillageStats = EffectResolver.derive(state)
	check.call(stats.income[GameTypes.Stock.WOOD] == 6 and stats.income[GameTypes.Stock.STONE] == 4, "Lumber, quarry and recycling produce actual raw materials every day")
	check.call(stats.income[GameTypes.Stock.PARTS] == 2 and stats.income[GameTypes.Stock.ARROWS] == 8 and stats.income[GameTypes.Stock.MEDICINE] == 1, "Automatic parts, arrows and medicine use actual stock types")
	check.call(stats.upkeep[GameTypes.Stock.WOOD] == 2 and stats.upkeep[GameTypes.Stock.WATER] == 6, "Processing inputs are included in the common daily balance")
	state.resources[GameTypes.Stock.WOOD] = 0
	stats = EffectResolver.derive(state)
	check.call(stats.income[GameTypes.Stock.ARROWS] == 0 and stats.upkeep[GameTypes.Stock.WOOD] == 0, "A workshop cannot consume the wood that will only arrive next dawn")
	check.call(stats.synergies.has("箭矢工房停产：木材不足，整批停产"), "Material shortage has an explicit production explanation")
	state.profession_counts[GameTypes.Profession.GATHERER] = 0
	stats = EffectResolver.derive(state)
	check.call(stats.income[GameTypes.Stock.WOOD] == 0 and stats.income[GameTypes.Stock.PARTS] == 0, "Losing the required operator pauses existing production facilities")
	state = _fresh()
	state.buildings[GameTypes.Building.BIOFUEL_WORKSHOP] = 1
	state.buildings[GameTypes.Building.WIND_GENERATOR] = 1
	stats = EffectResolver.derive(state)
	check.call(stats.income[GameTypes.Stock.FUEL] == 2 and stats.income[GameTypes.Stock.POWER] == 4, "Biofuel and wind generation provide alternatives to oil collection")
	state.resources[GameTypes.Stock.WATER] = 5
	stats = EffectResolver.derive(state)
	check.call(stats.income[GameTypes.Stock.FUEL] == 0 and stats.upkeep[GameTypes.Stock.FOOD] == 5, "Insufficient processing water pauses the entire fuel batch without charging food")
	state = _fresh()
	state.buildings[GameTypes.Building.SPEAR_RACK] = 1
	check.call(SurvivalRules.unlock_error(state, state.catalog.get_card("training")).is_empty(), "Spears unlock training without forcing an archery route")


static func _test_reservations(check: Callable) -> void:
	var state: VillageState = _fresh()
	state.resources[GameTypes.Stock.WOOD] = 4
	state.buildings[GameTypes.Building.FLETCHER] = 1
	state.buildings[GameTypes.Building.BARTER_POST] = 1
	var stats: VillageStats = EffectResolver.derive(state)
	check.call(stats.income[GameTypes.Stock.ARROWS] == 8 and stats.income[GameTypes.Stock.PARTS] == 0, "Two facilities cannot both spend the same wood")
	check.call(stats.upkeep[GameTypes.Stock.WOOD] == 2 and stats.income[GameTypes.Stock.NOISE] == 1, "A stopped trade batch consumes no wood and creates no running noise")
	var library: CardLibrary = state.catalog.library.duplicate(false) as CardLibrary
	library.buildings = state.catalog.library.buildings.duplicate()
	library.buildings.reverse()
	state.catalog = CardCatalog.new(library, false)
	var reordered: VillageStats = EffectResolver.derive(state)
	check.call(stats.income == reordered.income and stats.upkeep == reordered.upkeep, "Production allocation follows explicit priority and stable IDs rather than library order")


static func _test_frozen_settlement(check: Callable) -> void:
	var state: VillageState = _fresh()
	state.resources[GameTypes.Stock.WOOD] = 2
	state.buildings[GameTypes.Building.SAWMILL] = 1
	state.buildings[GameTypes.Building.FLETCHER] = 1
	var before: PackedInt32Array = state.resources.duplicate()
	state.begin_night()
	var support: CombatSupport = CombatSupport.new()
	support.initialize(state.night_stats)
	check.call(not support.spend(GameTypes.Stock.WOOD), "Night repairs cannot steal wood reserved for daily arrow production")
	var restored: VillageState = _fresh()
	check.call(restored.restore(state.snapshot()), "Automatic production survives a real night snapshot")
	check.call(restored.night_stats.upkeep[GameTypes.Stock.WOOD] == 2, "Restore retains the exact reserved processing input")
	_settle(state)
	_settle(restored)
	check.call(state.resources[GameTypes.Stock.WOOD] == before[GameTypes.Stock.WOOD] + 2, "Dawn adds lumber and charges its arrow input exactly once")
	check.call(state.resources[GameTypes.Stock.ARROWS] == before[GameTypes.Stock.ARROWS] + 8, "Dawn grants the frozen arrow batch without another card")
	check.call(state.resources == restored.resources, "Restored night settles the same batch and costs")
	before = state.resources.duplicate()
	state.advance_dawn()
	check.call(state.resources == before, "Repeated dawn cannot duplicate automatic output")


static func _test_validation(check: Callable) -> void:
	var state: VillageState = _fresh()
	var source: ProductionProfile = state.catalog.buildings[GameTypes.Building.SAWMILL].production
	var invalid: ProductionProfile = source.duplicate(false) as ProductionProfile
	invalid.outputs = source.outputs.duplicate()
	invalid.outputs.append(source.outputs[0])
	check.call(not invalid.validation_error().is_empty(), "Duplicate production output types are rejected")
	invalid.outputs = [null]
	check.call(not invalid.validation_error().is_empty(), "Null production records are rejected")
	invalid = source.duplicate(false) as ProductionProfile
	invalid.rain_water_bonus = 4
	check.call(not invalid.validation_error().is_empty(), "Rain bonus cannot attach to a wood-only profile")
	var card: CardDefinition = state.catalog.get_card("filter").duplicate(false) as CardDefinition
	var requirement: BuildingRequirement = BuildingRequirement.new()
	requirement.building = state.catalog.buildings[GameTypes.Building.RIVER_WINDMILL].duplicate(false) as BuildingDefinition
	card.any_prerequisites = [requirement]
	check.call(not ResourceValidation.card_error(card, state.catalog.buildings).is_empty(), "Alternative source must reference the registered native building")
	var combat: CombatBalanceRules = state.catalog.library.progression_rules.combat_balance.duplicate(false) as CombatBalanceRules
	combat.enemy_damage = NAN
	check.call(not combat.validation_error().is_empty(), "Non-finite battle balance parameters are rejected")
	check.call(source.outputs.size() == 1 and source.rain_water_bonus == 0, "Invalid clones leave the live production definition untouched")


static func _test_migration(check: Callable) -> void:
	var state: VillageState = _fresh()
	var data: VillageSaveData = state.snapshot()
	data.version = 12
	data.buildings.resize(VillageSaveData.PREVIOUS_BUILDING_COUNT)
	var restored: VillageState = _fresh()
	check.call(restored.restore(data), "Version 12 loads with its actual historical building array")
	check.call(restored.buildings.size() == GameTypes.Building.COUNT and restored.resources == data.resources, "Migration appends empty facility slots without giving away resources")
	for building: int in range(VillageSaveData.PREVIOUS_BUILDING_COUNT, GameTypes.Building.COUNT):
		check.call(restored.buildings[building] == 0, "Migrating an old save never constructs a new facility")
	check.call(data.buildings.size() == VillageSaveData.PREVIOUS_BUILDING_COUNT, "Restoring leaves the old input resource unchanged")
	check.call(restored.restore(restored.snapshot()), "Expanded save passes current validation")
	data = restored.snapshot()
	data.buildings.resize(VillageSaveData.PREVIOUS_BUILDING_COUNT)
	var before: PackedInt32Array = restored.resources.duplicate()
	check.call(not restored.restore(data) and restored.resources == before, "A truncated version 13 save is rejected atomically")


static func _fresh() -> VillageState:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(65012, GameTypes.Region.RURAL)
	SurvivalTestSetup.developed(state)
	state.weather = state.catalog.library.weather_rules.for_kind(WeatherDefinition.Kind.CLEAR)
	return state


static func _settle(state: VillageState) -> void:
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


static func _uid(state: VillageState, id: String) -> int:
	for entry: CardInstance in state.hand:
		if entry.definition.id == id:
			return entry.uid
	return -1
