class_name ValidationRegression
extends RefCounted
## 故障配置、存档与事务的回归检查，全部使用独立测试状态和文件。

const OLD_SAVE: String = "res://test-results/old_version.tres"


static func run(check: Callable) -> void:
	_test_catalog_failures(check)
	_test_snapshot_failures(check)
	_test_transaction_edges(check)
	_test_signal_reentry(check)


static func _fresh() -> VillageState:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(4242)
	SurvivalTestSetup.developed(state)
	return state


static func _library() -> CardLibrary:
	var source: CardLibrary = load("res://data/card_library.tres") as CardLibrary
	var library: CardLibrary = CardLibrary.new()
	library.keyword_library = source.keyword_library
	library.progression_rules = source.progression_rules
	library.workforce_rules = source.workforce_rules
	library.weather_rules = source.weather_rules
	library.cards = source.cards.duplicate()
	library.buildings = source.buildings.duplicate()
	library.starting_cards = source.starting_cards.duplicate()
	return library


static func _reject_library(library: CardLibrary, check: Callable, message: String) -> void:
	var catalog: CardCatalog = CardCatalog.new(library, false)
	check.call(not catalog.is_valid and not catalog.validation_error.is_empty(), message)
	check.call(
		catalog.library == null and catalog.cards.is_empty(),
		"Invalid catalog publishes no partial cards"
	)
	check.call(catalog.buildings.is_empty(), "Invalid catalog publishes no partial buildings")
	var state: VillageState = _fresh()
	var previous_seed: int = state.run_seed
	state.catalog = catalog
	state.new_run(999)
	check.call(
		state.run_seed == previous_seed,
		"Invalid catalog prevents a new run without changing current state"
	)


static func _test_catalog_failures(check: Callable) -> void:
	_reject_library(null, check, "Missing library rejected")
	var library: CardLibrary = _library()
	library.cards.append(library.cards[0])
	_reject_library(library, check, "Duplicate card ID rejected")
	library = _library()
	library.cards.append(null)
	_reject_library(library, check, "Null card rejected")
	library = _library()
	library.buildings.remove_at(0)
	_reject_library(library, check, "Incomplete building registration rejected")
	library = _library()
	library.buildings.append(library.buildings[0])
	_reject_library(library, check, "Duplicate building rejected")
	var card: CardDefinition = _library().cards[0].duplicate(false) as CardDefinition
	card.costs = [null]
	library = _library()
	library.cards.append(card)
	_reject_library(library, check, "Null nested cost rejected before index publication")
	card = _library().cards[0].duplicate(false) as CardDefinition
	var effect: CardEffect = CardEffect.new()
	effect.type = CardEffect.Type.BUILD
	card.effects = [effect]
	library = _library()
	library.cards.append(card)
	_reject_library(library, check, "Build effect without a building rejected")
	card = _library().cards[0].duplicate(false) as CardDefinition
	var invalid_cost: ResourceCost = ResourceCost.new()
	invalid_cost.key = 99 as GameTypes.Stock
	card.costs = [invalid_cost]
	library = _library()
	library.cards.append(card)
	_reject_library(library, check, "Invalid resource enum rejected")
	card = _library().cards[0].duplicate(false) as CardDefinition
	effect = CardEffect.new()
	effect.amount = INF
	card.effects = [effect]
	library = _library()
	library.cards.append(card)
	_reject_library(library, check, "Infinite configured effect rejected")
	var modifier: StatModifier = StatModifier.new()
	modifier.operation = 99 as StatModifier.Operation
	check.call(
		not ResourceValidation.modifier_error(modifier).is_empty(),
		"Invalid modifier operation rejected"
	)
	modifier.operation = StatModifier.Operation.ADD
	modifier.amount = NAN
	check.call(not ResourceValidation.modifier_error(modifier).is_empty(), "NaN modifier rejected")
	var detached: BuildingDefinition = (
		_library().buildings[0].duplicate(false) as BuildingDefinition
	)
	detached.footprint = Rect2i(100, 100, 2, 2)
	library = _library()
	library.buildings[0] = detached
	_reject_library(library, check, "Out of map footprint rejected")
	detached = _library().buildings[0].duplicate(false) as BuildingDefinition
	detached.footprint = WorldLayout.EXTRA_HUT
	library = _library()
	library.buildings[0] = detached
	_reject_library(library, check, "Overlapping footprint rejected")
	library = _library()
	var generator: CardDefinition = (
		(
			library
			. cards
			. filter(func(candidate: CardDefinition) -> bool: return candidate.id == "generator")[0]
			. duplicate(false)
		)
		as CardDefinition
	)
	var requirement: BuildingRequirement = BuildingRequirement.new()
	requirement.building = generator.building
	generator.prerequisites = [requirement]
	for index: int in library.cards.size():
		if library.cards[index].id == generator.id:
			library.cards[index] = generator
	_reject_library(library, check, "Unreachable self-dependent technology rejected")
	var water: WaterSynergy = WaterSynergy.new()
	water.pollution_per_loss = 0
	check.call(not water.configuration_error().is_empty(), "Invalid synergy divisor rejected")


static func _reject_snapshot(
	state: VillageState, data: VillageSaveData, check: Callable, message: String
) -> void:
	var before: VillageSaveData = state.snapshot()
	var signal_count: PackedInt32Array = [0]
	var callback: Callable = func() -> void: signal_count[0] += 1
	state.changed.connect(callback)
	check.call(not state.restore(data), message)
	state.changed.disconnect(callback)
	(
		check
		. call(
			(
				state.resources == before.resources
				and state.rng.state == before.rng_state
				and state.phase == before.phase
				and state.day == before.day
				and state.slot == before.slot
				and state.history[0].text == before.history[0].text
				and state.hand[0].uid == before.hand[0].uid
				and signal_count[0] == 0
			),
			"Failed restore does not change the current run or emit changed",
		)
	)


static func _test_snapshot_failures(check: Callable) -> void:
	var state: VillageState = _fresh()
	check.call(
		VillageSaveData.new().version == VillageState.SAVE_VERSION,
		"Default save version uses the authority"
	)
	state.core_health = 220.0
	state.begin_night()
	var report: BattleReport = BattleReport.new()
	report.core_health = state.core_health
	report.started_survivors = state.population
	report.survivors = state.population
	state.finish_night(report)
	var data: VillageSaveData = state.snapshot()
	data.night_stats = null
	_reject_snapshot(state, data, check, "Reward without dusk stats rejected")
	data = state.snapshot()
	data.history.append(null)
	_reject_snapshot(state, data, check, "Null history entry rejected")
	for invalid: float in [NAN, INF, -INF]:
		data = state.snapshot()
		data.core_health = invalid
		_reject_snapshot(state, data, check, "Nonfinite core health rejected")
		data = state.snapshot()
		data.night_stats.values[GameTypes.Stat.ATTACK] = invalid
		_reject_snapshot(state, data, check, "Nonfinite stats rejected")
		data = state.snapshot()
		data.last_report.duration = invalid
		_reject_snapshot(state, data, check, "Nonfinite report duration rejected")
	var modifier: StatModifier = StatModifier.new()
	modifier.duration = 1
	modifier.remaining = 1
	modifier.operation = 99 as StatModifier.Operation
	data = state.snapshot()
	data.modifiers = [modifier]
	_reject_snapshot(state, data, check, "Invalid runtime operation rejected")
	modifier.operation = StatModifier.Operation.ADD
	modifier.amount = INF
	data = state.snapshot()
	data.modifiers = [modifier]
	_reject_snapshot(state, data, check, "Nonfinite runtime modifier rejected")
	data = state.snapshot()
	data.wall_damage[Vector2i.ZERO] = 1.0
	_reject_snapshot(state, data, check, "Damage outside wall coordinates rejected")
	data = state.snapshot()
	data.wall_damage[WorldLayout.wall_cells()[0]] = NAN
	_reject_snapshot(state, data, check, "Nonfinite wall damage rejected")
	data = state.snapshot()
	data.last_report.survivors = data.last_report.started_survivors + 1
	_reject_snapshot(state, data, check, "Impossible report population rejected")
	data = state.snapshot()
	data.version = 1
	check.call(ResourceSaver.save(data, OLD_SAVE) == OK, "Old save fixture written")
	var bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(OLD_SAVE)
	check.call(not state.load_game(OLD_SAVE), "Old version rejected without migration")
	check.call(
		FileAccess.get_file_as_bytes(OLD_SAVE) == bytes_before, "Rejected old save file preserved"
	)
	data = state.snapshot()
	data.version = VillageSaveData.CURRENT_VERSION
	check.call(state.restore(data), "Valid reward roundtrip accepted")
	SurvivalTestSetup.settle_day_end(state)
	check.call(state.day == 3, "Restored reward can safely settle dawn")


static func _test_transaction_edges(check: Callable) -> void:
	var state: VillageState = _fresh()
	var card: CardDefinition = state.catalog.get_card("wall").duplicate(false) as CardDefinition
	card.id = "multi_build_fixture"
	card.building = null
	card.costs = []
	card.effects = [card.effects[0], card.effects[0]]
	state.buildings[GameTypes.Building.WALL] = 2
	state.add_card(card)
	var before: VillageSaveData = state.snapshot()
	check.call(
		not state.play_card(state.hand.back().uid), "Cumulative effect building level rejected"
	)
	check.call(
		state.buildings == before.buildings and state.slot == 0,
		"Overlevel transaction remains atomic"
	)
	state = _fresh()
	card = state.catalog.get_card("wall").duplicate(false) as CardDefinition
	card.id = "condition_fixture"
	card.costs = []
	var conditional: CardEffect = CardEffect.new()
	conditional.type = CardEffect.Type.POPULATION
	conditional.amount = 2
	conditional.required_building = card.building
	card.effects = [card.effects[0], conditional]
	state.add_card(card)
	check.call(state.play_card(state.hand.back().uid), "Build with a conditional effect accepted")
	check.call(state.population == 5, "Later effect reads state before the transaction")
	var reversed: VillageState = _fresh()
	card = card.duplicate(false) as CardDefinition
	card.effects.reverse()
	reversed.add_card(card)
	check.call(
		reversed.play_card(reversed.hand.back().uid), "Reordered conditional transaction accepted"
	)
	check.call(reversed.population == state.population, "Condition is independent of effect order")
	var destination: String = "res://test-results/preserved.tres"
	check.call(state.save_game(destination), "Valid save created before forced replacement failure")
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(destination)
	var blocker: String = "res://test-results/preserved.tmp.tres"
	check.call(DirAccess.make_dir_absolute(blocker) == OK, "Temporary-file obstruction installed")
	# 引擎预期报告一次无法写入；明确捕获失败，原存档不能被触碰。
	print("EXPECTED SAVE FAILURE BEGIN: obstructed temporary file")
	check.call(not state.save_game(destination), "Write failure reported")
	print("EXPECTED SAVE FAILURE END")
	check.call(
		FileAccess.get_file_as_bytes(destination) == saved,
		"Write failure preserves the previous save"
	)
	DirAccess.remove_absolute(blocker)


static func _test_signal_reentry(check: Callable) -> void:
	var state: VillageState = _fresh()
	var uid: int = -1
	for entry: CardInstance in state.hand:
		if entry.definition.id == "forage":
			uid = entry.uid
			break
	var attempted: PackedInt32Array = [0]
	var callback: Callable = func() -> void:
		attempted[0] += 1
		check.call(not state.play_card(uid), "Changed callback cannot reenter card execution")
		state.skip_slot()
	state.changed.connect(callback)
	check.call(state.play_card(uid), "Initial action commits normally")
	state.changed.disconnect(callback)
	check.call(state.slot == 1 and attempted[0] == 1, "Notification cannot spend another slot")
