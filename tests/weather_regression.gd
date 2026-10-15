class_name WeatherRegression
extends RefCounted
## 天气抽取、结算、快照与旧档迁移；磁盘往返使用独立测试路径。


static func run(check: Callable) -> void:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(12345)
	SurvivalTestSetup.developed(state)
	state.buildings[GameTypes.Building.WATER_TANK] = 1
	_test_sequence(state, check)
	_test_effects(state, check)
	_test_save_and_dawn(state, check)
	_test_configuration(state.catalog.library.weather_rules, check)


static func _test_sequence(state: VillageState, check: Callable) -> void:
	var rules: WeatherRules = state.catalog.library.weather_rules
	check.call(rules.validation_error().is_empty(), "Weather resource graph is valid")
	check.call(state.weather.kind == WeatherDefinition.Kind.CLEAR, "First day starts clear")
	var random_state: int = state.rng.state
	var seen: Dictionary[int, bool] = {}
	var reproducible: bool = true
	for day: int in range(2, 200):
		var weather: WeatherDefinition = rules.for_day(state.run_seed, day)
		seen[weather.kind] = true
		reproducible = reproducible and weather == rules.for_day(state.run_seed, day)
	check.call(reproducible, "Weather repeats for seed/day")
	check.call(seen.size() == WeatherDefinition.Kind.COUNT, "Seed sequence includes all weather")
	check.call(state.rng.state == random_state, "Weather does not consume reward RNG")


static func _test_effects(state: VillageState, check: Callable) -> void:
	var rules: WeatherRules = state.catalog.library.weather_rules
	SurvivalTestSetup.complete_well(state)
	var base: VillageStats = EffectResolver.derive(state)
	state.weather = rules.for_kind(WeatherDefinition.Kind.CLOUDY)
	check.call(
		EffectResolver.derive(state).stamina_recovery == base.stamina_recovery + 3,
		"Clouds improve recovery"
	)
	state.weather = rules.for_kind(WeatherDefinition.Kind.RAIN)
	var rain: VillageStats = EffectResolver.derive(state)
	check.call(
		(
			rain.income[GameTypes.Stock.WATER] == 13
			and rain.stamina_recovery == base.stamina_recovery - 2
		),
		"Rain adds water with recovery tradeoff"
	)
	state.weather = rules.for_kind(WeatherDefinition.Kind.FOG)
	var fog: VillageStats = EffectResolver.derive(state)
	check.call(
		is_equal_approx(fog.wave_size, 0.9) and is_equal_approx(fog.attack_range, 75.0),
		"Fog reduces wave size and guard range"
	)
	var range_bonus: StatModifier = StatModifier.new()
	range_bonus.key = GameTypes.Stat.RANGE
	range_bonus.amount = 50.0
	state.modifiers.append(range_bonus)
	check.call(
		is_equal_approx(EffectResolver.derive(state).attack_range, 112.5),
		"Weather multiplies after additive card bonuses"
	)
	state.modifiers.clear()
	state.weather = rules.for_kind(WeatherDefinition.Kind.THUNDERSTORM)
	var storm: VillageStats = EffectResolver.derive(state)
	check.call(storm.income[GameTypes.Stock.WATER] == 16, "Storm water stacks with well")
	check.call(storm.stamina_recovery == base.stamina_recovery - 6, "Storm reduces recovery")
	check.call(
		is_equal_approx(storm.cooldown, base.cooldown / 0.85), "Storm reduces attack cadence"
	)
	check.call(is_equal_approx(storm.attack_range, base.attack_range * 0.85), "Storm reduces range")


static func _test_save_and_dawn(state: VillageState, check: Callable) -> void:
	var rules: WeatherRules = state.catalog.library.weather_rules
	var data: VillageSaveData = state.snapshot()
	var restored: VillageState = VillageState.new()
	restored.persistence_enabled = false
	check.call(restored.restore(data), "Weather save restores")
	check.call(
		restored.weather.kind == state.weather.kind, "Restore retains weather without reroll"
	)
	check.call(restored.rng.state == state.rng.state, "Restore retains reward RNG")
	var path: String = "res://test-results/weather_roundtrip.tres"
	check.call(
		state.save_game(path) and restored.load_game(path), "Storm save survives disk roundtrip"
	)
	check.call(
		restored.weather.kind == WeatherDefinition.Kind.THUNDERSTORM, "Disk load retains storm"
	)
	DirAccess.remove_absolute(path)
	var before: VillageStats = EffectResolver.derive(state)
	state.preview_card(state.catalog.get_card("wall"))
	check.call(state.weather.kind == WeatherDefinition.Kind.THUNDERSTORM, "Preview retains weather")
	check.call(
		EffectResolver.derive(state).income == before.income, "Preview does not mutate income"
	)
	state.begin_night()
	var water: int = state.resources[GameTypes.Stock.WATER]
	state.begin_night()
	check.call(
		state.night_stats.income[GameTypes.Stock.WATER] == 16, "Night freezes weather income"
	)
	var night_data: VillageSaveData = state.snapshot()
	check.call(
		restored.restore(night_data) and restored.night_stats.income[GameTypes.Stock.WATER] == 16,
		"Night restore preserves weather snapshot"
	)
	night_data.version = VillageSaveData.WORKFORCE_VERSION
	night_data.buildings.resize(13)
	check.call(
		(
			restored.restore(night_data)
			and restored.weather.kind == WeatherDefinition.Kind.CLEAR
			and restored.night_stats.income[GameTypes.Stock.WATER] == 16
		),
		"Legacy night keeps stored settlement without recomputing"
	)
	var report: BattleReport = BattleReport.new()
	report.core_health = state.core_health
	report.survivors = state.population
	report.started_survivors = state.population
	report.kills = 11
	report.duration = 30.0
	state.finish_night(report)
	SurvivalTestSetup.settle_day_end(state)
	check.call(
		state.resources[GameTypes.Stock.WATER] == water + 16 - 5, "Dawn settles storm water once"
	)
	var settled: int = state.resources[GameTypes.Stock.WATER]
	state.advance_dawn()
	check.call(
		state.resources[GameTypes.Stock.WATER] == settled,
		"Duplicate dawn cannot repeat rain income"
	)
	check.call(state.weather == rules.for_day(state.run_seed, 3), "Next dawn chooses next weather")
	data = state.snapshot()
	data.actions_per_slot = 2
	data.actions_used = 1
	data.version = VillageSaveData.WORKFORCE_VERSION
	data.buildings.resize(13)
	check.call(restored.restore(data), "Version 3 migrates successfully")
	check.call(restored.weather.kind == WeatherDefinition.Kind.CLEAR, "Old day keeps clear weather")
	check.call(
		restored.actions_per_slot == 2 and restored.actions_used == 1,
		"Version 3 keeps workforce quota and usage"
	)
	data.version = VillageSaveData.CURRENT_VERSION
	data.weather_kind = WeatherDefinition.Kind.COUNT
	var old_day: int = restored.day
	check.call(
		not restored.restore(data) and restored.day == old_day, "Invalid weather restore is atomic"
	)


static func _test_configuration(rules: WeatherRules, check: Callable) -> void:
	var invalid: WeatherRules = rules.duplicate(false) as WeatherRules
	invalid.definitions = rules.definitions.duplicate()
	invalid.definitions.append(rules.definitions[0])
	check.call(not invalid.validation_error().is_empty(), "Duplicate weather rejected")
	invalid.definitions = rules.definitions.duplicate()
	var invalid_weather: WeatherDefinition = (
		rules.definitions[0].duplicate(false) as WeatherDefinition
	)
	invalid_weather.rainfall = NAN
	invalid.definitions[0] = invalid_weather
	check.call(not invalid.validation_error().is_empty(), "Non-finite rainfall rejected")
	check.call(rules.validation_error().is_empty(), "Validation copies leave definitions unchanged")
