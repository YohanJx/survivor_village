class_name DayEndEventRegression
extends RefCounted
## 日终事件的取舍、原子拒绝、跳过、期限、存档与随机序列回归。


static func run(check: Callable) -> void:
	_test_generation(check)
	_test_payment_and_skip(check)
	_test_effects(check)
	_test_save_and_migration(check)
	_test_configuration(check)
	_test_context_and_deprivation(check)
	_test_queue_migrations(check)


static func _fresh() -> VillageState:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(92817)
	SurvivalTestSetup.developed(state)
	state.weather = state.catalog.library.weather_rules.for_kind(WeatherDefinition.Kind.CLEAR)
	state.core_health = 230.0
	state.resources[GameTypes.Stock.FOOD] = 30
	state.resources[GameTypes.Stock.WATER] = 30
	state.resources[GameTypes.Stock.WOOD] = 20
	state.resources[GameTypes.Stock.PARTS] = 20
	state.resources[GameTypes.Stock.MEDICINE] = 5
	return state


static func _finish(state: VillageState, event_id: String = "") -> void:
	state.begin_night()
	var report: BattleReport = BattleReport.new()
	report.core_health = state.core_health
	report.started_survivors = state.population
	report.survivors = state.population
	state.finish_night(report)
	if not event_id.is_empty():
		state.day_end_event_id = event_id
		state.pending_day_end_events.clear()


static func _test_generation(check: Callable) -> void:
	var state: VillageState = _fresh()
	for region: int in GameTypes.Region.COUNT:
		state.new_run(92817, region as GameTypes.Region)
		for day: int in range(1, 31):
			state.day = day
			var random_state: int = state.rng.state
			var event: DailyEvent = DayEndEvents.for_day(state)
			check.call(
				event == DayEndEvents.for_day(state),
				"Closing event is reproducible, including an empty pool"
			)
			check.call(state.rng.state == random_state, "Closing query leaves gameplay RNG intact")
			if event != null:
				check.call(
					EventEligibility.matches(state, event),
					"Generated event meets actual village context"
				)
				check.call(
					not state.progress.recent_day_end_events.has(event.id),
					"Closing event avoids the previous two events"
				)
				state.progress.recent_day_end_events.append(event.id)
				if state.progress.recent_day_end_events.size() > 2:
					state.progress.recent_day_end_events.remove_at(0)
	state = _fresh()
	var hand_size: int = state.hand.size()
	_finish(state)
	check.call(
		state.phase == GameTypes.Phase.DAY_END and state.hand.size() == hand_size,
		"Victory presents an event without granting reward cards"
	)
	var data: VillageSaveData = state.snapshot()
	for index: int in state.current_day_end_event().options.size():
		DayEndEvents.option_error(state, index)
	check.call(
		state.resources == data.resources and state.history.size() == data.history.size(),
		"Event option queries are side-effect free"
	)
	state.advance_dawn()
	check.call(state.day == data.day, "Unresolved event blocks dawn")


static func _test_payment_and_skip(check: Callable) -> void:
	var state: VillageState = _fresh()
	_finish(state, "day_end_trader")
	state.resources[GameTypes.Stock.FOOD] = 0
	state.resources[GameTypes.Stock.WATER] = 0
	state.resources[GameTypes.Stock.PARTS] = 0
	var before: VillageSaveData = state.snapshot()
	var signals: PackedInt32Array = [0]
	state.changed.connect(func() -> void: signals[0] += 1)
	check.call(not DayEndEvents.option_error(state, 0).is_empty(), "Trade previews missing costs")
	check.call(not state.choose_day_end_event(0), "Trade cannot partially spend missing supplies")
	check.call(not state.choose_day_end_event(1), "Other paid trade also rejects missing supplies")
	check.call(not state.choose_day_end_event(-1), "Negative option index is rejected")
	check.call(not state.choose_day_end_event(2), "Unknown option index is rejected")
	check.call(
		(
			state.resources == before.resources
			and state.modifiers.is_empty()
			and state.day == before.day
			and state.day_end_event_id == before.day_end_event_id
			and state.history.size() == before.history.size()
			and signals[0] == 0
		),
		"Rejected choices preserve inventory, event, date, effects and signals"
	)
	check.call(state.skip_day_end_event(), "Optional event remains skippable without supplies")
	check.call(
		state.day == before.day and state.day_end_settled,
		"Empty supplies create mandatory morning consequences"
	)
	check.call(
		SurvivalTestSetup.settle_day_end(state),
		"All morning consequences can resolve with no supplies"
	)
	check.call(
		(
			state.day == before.day + 1
			and state.resources[GameTypes.Stock.PARTS] == 0
			and state.resources[GameTypes.Stock.FUEL] == before.resources[GameTypes.Stock.FUEL]
			and (
				state.resources[GameTypes.Stock.MEDICINE]
				== before.resources[GameTypes.Stock.MEDICINE]
			)
		),
		"Skipping grants no goods and only settles the usual dawn"
	)
	check.call(not state.skip_day_end_event(), "Repeated skip cannot settle another dawn")
	state = _fresh()
	_finish(state, "day_end_repair")
	state.resources.fill(0)
	before = state.snapshot()
	check.call(state.skip_day_end_event(), "Ordinary encounter can be ignored")
	check.call(
		state.core_health <= before.core_health,
		"Ignoring does not repair damage or create supplies"
	)
	check.call(state.day_end_settled, "Ignored encounter still settles rations exactly once")


static func _test_effects(check: Callable) -> void:
	var state: VillageState = _fresh()
	_finish(state, "day_end_salvage")
	var wood: int = state.resources[GameTypes.Stock.WOOD]
	var hand_size: int = state.hand.size()
	check.call(state.choose_day_end_event(0), "Wood event commits its tradeoff")
	check.call(
		(
			state.resources[GameTypes.Stock.WOOD] == wood + 6
			and state.resources[GameTypes.Stock.NOISE] == 0
		),
		"One event gives wood while noise is reset at dawn"
	)
	check.call(state.hand.size() == hand_size, "Event option never becomes a hand card")
	check.call(state.actions_used == 0 and state.slot == 0, "Event spends no next-day action")
	check.call(not state.choose_day_end_event(0), "Repeated event commit is rejected")
	state = _fresh()
	var old_modifier: StatModifier = StatModifier.new()
	old_modifier.key = GameTypes.Stat.ATTACK
	old_modifier.amount = 3.0
	old_modifier.duration = 1
	old_modifier.remaining = 1
	old_modifier.source = "上一夜的效果"
	state.modifiers.append(old_modifier)
	_finish(state, "day_end_salvage")
	var frozen: PackedFloat64Array = state.night_stats.values.duplicate()
	check.call(state.choose_day_end_event(1), "Parts event adds a temporary health penalty")
	check.call(
		state.modifiers.size() == 1 and state.modifiers[0].remaining == 1,
		"Old effects expire while newly granted event effects retain a full next night"
	)
	check.call(state.night_stats.values == frozen, "Event does not rewrite the previous dusk")
	state.begin_night()
	check.call(state.night_stats.health == 58.5, "Next night uses the event health penalty")
	var option: CardDefinition = (
		state.catalog.library.progression_rules.day_end_events[0].options[1]
	)
	check.call(
		option.effects.back().modifier.remaining == 0, "Shared event modifiers remain immutable"
	)
	state = _fresh()
	state.population = 9
	_finish(state, "day_end_traveler")
	var food: int = state.resources[GameTypes.Stock.FOOD]
	state.buildings[GameTypes.Building.FOOD_STORE] = 1
	check.call(state.choose_day_end_event(0), "Traveler joins directly without entering the hand")
	check.call(
		(
			state.population == 10
			and state.progress.survivors.size() == 10
			and state.actions_per_slot == 2
		),
		"Recruitment reconciles identities, professions and next-day action quota"
	)
	check.call(
		state.resources[GameTypes.Stock.FOOD] == food - 3 - 10, "Newcomer also consumes food"
	)


static func _test_save_and_migration(check: Callable) -> void:
	var state: VillageState = _fresh()
	_finish(state, "day_end_salvage")
	var data: VillageSaveData = state.snapshot()
	var restored: VillageState = _fresh()
	check.call(restored.restore(data), "Pending event snapshot restores")
	check.call(restored.day_end_event_id == data.day_end_event_id, "Restore keeps the exact event")
	check.call(restored.choose_day_end_event(0), "Restored event can resolve exactly once")
	check.call(not restored.choose_day_end_event(0), "Restored event cannot resolve twice")
	data = state.snapshot()
	data.day_end_event_id = "unknown"
	var before: VillageSaveData = restored.snapshot()
	check.call(not restored.restore(data), "Unknown event rejects the whole save")
	check.call(
		restored.resources == before.resources and restored.day == before.day,
		"Failed restore is atomic"
	)
	data = state.snapshot()
	data.day_end_event_id = ""
	check.call(not restored.restore(data), "Day-end save must have a pending event")
	data = state.snapshot()
	data.progress.recent_day_end_events = PackedStringArray([data.day_end_event_id])
	check.call(not restored.restore(data), "An already resolved event cannot be pending again")
	data = state.snapshot()
	data.version = 7
	data.day_end_event_id = ""
	data.rewards = [state.catalog.get_card("forced_march")]
	check.call(restored.restore(data), "Version seven reward save migrates to a closing event")
	check.call(
		(
			restored.current_day_end_event() != null
			and restored.snapshot().rewards.is_empty()
			and data.rewards.size() == 1
			and data.day_end_event_id.is_empty()
		),
		"Migration drops pending reward offers without mutating their source save"
	)
	check.call(SurvivalTestSetup.settle_day_end(restored), "Migrated event settles safely")
	data = restored.snapshot()
	data.day_end_event_id = "day_end_salvage"
	check.call(not restored.restore(data), "Day phase cannot contain an unresolved closing event")


static func _test_configuration(check: Callable) -> void:
	var state: VillageState = _fresh()
	var original: ProgressionRules = state.catalog.library.progression_rules
	var rules: ProgressionRules = original.duplicate(false) as ProgressionRules
	rules.day_end_events = original.day_end_events.duplicate()
	rules.day_end_events.append(rules.day_end_events[0])
	check.call(
		not _configuration_error(state, rules).is_empty(),
		"Duplicate closing event IDs reject initialization"
	)
	rules.day_end_events = original.day_end_events.duplicate()
	var event: DailyEvent = rules.day_end_events[0].duplicate(false) as DailyEvent
	rules.day_end_events[0] = event
	event.options = event.options.duplicate()
	var option: CardDefinition = event.options[0].duplicate(false) as CardDefinition
	event.options[0] = option
	option.effects = []
	check.call(
		not _configuration_error(state, rules).is_empty(),
		"An event with no actual effect is rejected"
	)
	option.effects = [original.day_end_events[0].options[0].effects[0]]
	option.negative = ""
	check.call(
		_configuration_error(state, rules).is_empty(),
		"A real benefit does not require an invented penalty"
	)
	option.effects = [original.day_end_events[0].options[0].effects[1]]
	option.positive = ""
	option.negative = "Noise +6"
	check.call(
		_configuration_error(state, rules).is_empty(),
		"A real consequence does not require an invented benefit"
	)
	rules.day_end_events = [original.day_end_events[4]]
	check.call(
		not _configuration_error(state, rules).is_empty(), "Insufficient regional pool is rejected"
	)
	rules.day_end_events = original.day_end_events.duplicate()
	event = original.day_end_events[4].duplicate(false) as DailyEvent
	event.skippable = false
	rules.day_end_events[4] = event
	check.call(
		not _configuration_error(state, rules).is_empty(), "Forced paid events need a free fallback"
	)
	check.call(
		_configuration_error(state, original).is_empty(),
		"Original shared event graph remains valid"
	)


static func _configuration_error(state: VillageState, rules: ProgressionRules) -> String:
	return DayEndEvents.configuration_error(
		rules, state.catalog.buildings, state.catalog.library.keyword_library
	)


static func _test_context_and_deprivation(check: Callable) -> void:
	var state: VillageState = _fresh()
	var rules: ProgressionRules = state.catalog.library.progression_rules
	var ration: DailyEvent = rules.day_end_event_for("day_end_ration")
	state.progress.explored_cells = PackedInt32Array([TerrainGrid.index(TerrainGrid.CAMP)])
	check.call(EventEligibility.matches(state, ration), "Early rest event is eligible near camp")
	state.day = 30
	check.call(
		not EventEligibility.matches(state, ration),
		"Mature village excludes early camp ration events"
	)
	var salvage: DailyEvent = rules.day_end_event_for("day_end_salvage")
	state.day = 2
	state.progress.discoveries.clear()
	check.call(
		not EventEligibility.matches(state, salvage), "Salvage cannot invent an undiscovered ruin"
	)
	state.progress.discoveries.append(GameTypes.Discovery.RUINS)
	check.call(EventEligibility.matches(state, salvage), "Known ruins allow early salvage")
	state = _fresh()
	state.day = 12
	state.progress.frustration = 3
	state.buildings[GameTypes.Building.GENERATOR] = 1
	state.resources[GameTypes.Stock.FUEL] = 10
	var queue: PackedStringArray = DayEndEvents.queue_for_day(state)
	check.call(
		queue.size() == 2 and queue[0] != queue[1],
		"Developed village can have multiple distinct encounters"
	)
	check.call(queue == DayEndEvents.queue_for_day(state), "Encounter queue is deterministic")
	_finish(state)
	var before: VillageSaveData = state.snapshot()
	check.call(state.pending_day_end_events.size() == 1, "Second encounter remains queued")
	check.call(state.choose_day_end_event(1), "First encounter resolves")
	check.call(
		state.day == before.day and state.phase == GameTypes.Phase.DAY_END,
		"First encounter does not advance date past second"
	)
	var restored: VillageState = _fresh()
	check.call(
		restored.restore(state.snapshot()), "Save between encounters restores partial processing"
	)
	check.call(
		(
			restored.pending_day_end_events == state.pending_day_end_events
			and restored.day_end_effects_expired
		),
		"Queue and one-time expiration survive restore"
	)
	var invalid: VillageSaveData = before
	invalid.pending_day_end_events = PackedStringArray([invalid.day_end_event_id])
	check.call(not restored.restore(invalid), "Duplicate queued encounter rejects save atomically")
	state = _fresh()
	_finish(state, "day_end_ration")
	state.resources[GameTypes.Stock.FOOD] = 0
	check.call(
		not state.choose_day_end_event(0), "Hot meal requires real food rather than creating it"
	)
	state.resources[GameTypes.Stock.WATER] = 0
	check.call(state.choose_day_end_event(1), "Resting leads into actual ration settlement")
	check.call(
		state.progress.hungry_days == 1 and state.progress.thirsty_days == 1,
		"Both actual shortages start independent streaks"
	)
	check.call(
		(
			state.current_day_end_event().trigger == DailyEvent.Trigger.HUNGER
			and state.pending_day_end_events.size() == 1
		),
		"Hunger and thirst are both mandatory consequences"
	)
	check.call(not state.skip_day_end_event(), "Supply consequences cannot be dismissed")
	var supplies: PackedInt32Array = state.resources.duplicate()
	var health: float = state.core_health
	restored = _fresh()
	check.call(
		restored.restore(state.snapshot()),
		"Morning consequence save restores after one-time consumption"
	)
	check.call(restored.choose_day_end_event(1), "Hunger consequence resolves without medicine")
	check.call(
		restored.resources == supplies and restored.core_health == health,
		"Moving to thirst does not consume daily supplies twice"
	)
	check.call(restored.choose_day_end_event(1), "Thirst consequence resolves without medicine")
	check.call(
		restored.day == state.day + 1 and restored.modifiers.size() == 2,
		"Both penalties survive until next night"
	)
	check.call(
		EffectResolver.derive(restored).health < EffectResolver.derive(_fresh()).health,
		"Hunger reduces actual defenders' health"
	)
	check.call(
		EffectResolver.derive(restored).attack < EffectResolver.derive(_fresh()).attack,
		"Thirst reduces actual defenders' attack"
	)
	restored.weather = restored.catalog.library.weather_rules.for_kind(WeatherDefinition.Kind.CLEAR)
	_finish(restored, "day_end_repair")
	restored.resources[GameTypes.Stock.FOOD] = 0
	restored.resources[GameTypes.Stock.WATER] = 0
	check.call(restored.choose_day_end_event(1), "Second day's shortage settles")
	check.call(
		(
			restored.current_day_end_event().id == "day_end_hunger_severe"
			and restored.progress.hungry_days == 2
		),
		"Repeated hunger escalates, rather than staying generic"
	)
	check.call(
		restored.pending_day_end_events == PackedStringArray(["day_end_thirst_severe"]),
		"Repeated thirst escalates independently"
	)
	check.call(SurvivalTestSetup.settle_day_end(restored), "Severe crisis has a free fallback")
	restored.weather = restored.catalog.library.weather_rules.for_kind(WeatherDefinition.Kind.CLEAR)
	_finish(restored, "day_end_repair")
	restored.resources[GameTypes.Stock.FOOD] = EffectResolver.daily_upkeep(restored)[
		GameTypes.Stock.FOOD
	]
	restored.resources[GameTypes.Stock.WATER] = EffectResolver.daily_upkeep(restored)[
		GameTypes.Stock.WATER
	]
	check.call(restored.choose_day_end_event(1), "Sufficient daily intake resolves without crises")
	check.call(
		restored.progress.hungry_days == 0 and restored.progress.thirsty_days == 0,
		"Intake resets streaks even if storage discards leftovers"
	)
	check.call(
		restored.resources[GameTypes.Stock.FOOD] == 0,
		"Zero stored food after full intake is not starvation"
	)


static func _test_queue_migrations(check: Callable) -> void:
	var state: VillageState = _fresh()
	state.day = 30
	state.core_health = state.core_max_health
	state.progress.recent_day_end_events = PackedStringArray(["day_end_trader", "day_end_traveler"])
	state.progress.frustration = 0
	var day: int = state.day
	_finish(state)
	check.call(
		state.phase == GameTypes.Phase.DAY and state.day == day + 1,
		"No matching encounter allows normal dawn without a fabricated event"
	)
	state = _fresh()
	_finish(state, "day_end_trader")
	var old: VillageSaveData = state.snapshot()
	old.version = 8
	var restored: VillageState = _fresh()
	check.call(restored.restore(old), "Version eight single-event save migrates")
	check.call(
		(
			restored.day_end_event_id == old.day_end_event_id
			and restored.resources == old.resources
			and not restored.day_end_settled
		),
		"Single-event migration preserves pending choice and inventory"
	)
	old = state.snapshot()
	old.version = 7
	old.day = 30
	old.core_health = 240.0
	old.last_report.core_health = 240.0
	old.day_end_event_id = ""
	old.rewards = [state.catalog.get_card("forced_march")]
	check.call(
		restored.restore(old),
		"Old reward save with no eligible modern encounter preserves its pending stage"
	)
	check.call(
		(
			restored.phase == GameTypes.Phase.DAY_END
			and restored.day == old.day
			and restored.resources == old.resources
		),
		"Legacy fallback never settles supplies during restore"
	)
	state = _fresh()
	state.new_run(92817, GameTypes.Region.RURAL)
	SurvivalTestSetup.developed(state)
	state.core_health = 200.0
	state.resources[GameTypes.Stock.FOOD] = 30
	state.resources[GameTypes.Stock.WATER] = 30
	state.begin_night()
	var report: BattleReport = BattleReport.new()
	report.core_health = state.core_health
	report.started_survivors = state.population
	report.survivors = state.population
	report.has_identities = true
	report.consumed.resize(GameTypes.Stock.COUNT)
	for person: SurvivorRecord in state.progress.survivors:
		report.survivor_ids.append(person.id)
	state.finish_night(report)
	state.day_end_event_id = "day_end_traveler"
	state.pending_day_end_events = PackedStringArray(["day_end_repair"])
	check.call(state.choose_day_end_event(0), "Recruitment can precede another encounter")
	restored = _fresh()
	check.call(
		restored.restore(state.snapshot()),
		"Modern identity roster restores after recruitment between events"
	)
	check.call(
		restored.population == 6 and restored.current_day_end_event().id == "day_end_repair",
		"Restored population and remaining encounter agree"
	)
	var rules: ProgressionRules = (
		state.catalog.library.progression_rules.duplicate(false) as ProgressionRules
	)
	rules.day_end_events = rules.day_end_events.duplicate()
	var crisis: DailyEvent = (
		rules.day_end_event_for("day_end_hunger").duplicate(false) as DailyEvent
	)
	var index: int = rules.day_end_events.find(rules.day_end_event_for("day_end_hunger"))
	rules.day_end_events[index] = crisis
	crisis.max_deprivation_days = 3
	check.call(
		not _configuration_error(state, rules).is_empty(),
		"Overlapping crisis stages reject initialization"
	)
	crisis.max_deprivation_days = 1
	crisis.min_population = 20
	check.call(
		not _configuration_error(state, rules).is_empty(),
		"Crisis cannot be hidden from a small village"
	)
