class_name DayEndEventRegression
extends RefCounted
## 日终事件的取舍、原子拒绝、跳过、期限、存档与随机序列回归。


static func run(check: Callable) -> void:
	_test_generation(check)
	_test_payment_and_skip(check)
	_test_effects(check)
	_test_save_and_migration(check)
	_test_configuration(check)


static func _fresh() -> VillageState:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(92817)
	SurvivalTestSetup.developed(state)
	state.weather = state.catalog.library.weather_rules.for_kind(WeatherDefinition.Kind.CLEAR)
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


static func _test_generation(check: Callable) -> void:
	var state: VillageState = _fresh()
	var seen: Dictionary[String, bool] = {}
	for region: int in GameTypes.Region.COUNT:
		state.new_run(92817, region as GameTypes.Region)
		for day: int in range(1, 31):
			state.day = day
			var random_state: int = state.rng.state
			var event: DailyEvent = DayEndEvents.for_day(state)
			check.call(event != null, "Every region has a closing event every day")
			check.call(event == DayEndEvents.for_day(state), "Closing event is reproducible")
			check.call(state.rng.state == random_state, "Closing query leaves gameplay RNG intact")
			check.call(
				not state.progress.recent_day_end_events.has(event.id),
				"Closing event avoids the previous two events"
			)
			seen[event.id] = true
			state.progress.recent_day_end_events.append(event.id)
			if state.progress.recent_day_end_events.size() > 2:
				state.progress.recent_day_end_events.remove_at(0)
	check.call(seen.size() == 6, "All six closing events are reachable")
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
	check.call(not state.skip_day_end_event(), "Ordinary event cannot be skipped")
	check.call(state.resources == before.resources, "Rejected ordinary skip changes no stocks")
	check.call(state.choose_day_end_event(1), "Ordinary event has a route with empty supplies")


static func _test_effects(check: Callable) -> void:
	var state: VillageState = _fresh()
	_finish(state, "day_end_salvage")
	var wood: int = state.resources[GameTypes.Stock.WOOD]
	var noise: int = state.resources[GameTypes.Stock.NOISE]
	var hand_size: int = state.hand.size()
	check.call(state.choose_day_end_event(0), "Wood event commits its tradeoff")
	check.call(
		(
			state.resources[GameTypes.Stock.WOOD] == wood + 6
			and state.resources[GameTypes.Stock.NOISE] == maxi(0, noise + 6 - 3)
		),
		"One event gives wood and adds noise before normal dawn decay"
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
	option.effects = [option.effects[0]]
	check.call(
		not _configuration_error(state, rules).is_empty(), "An event with only benefits is rejected"
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
