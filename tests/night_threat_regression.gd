class_name NightThreatRegression
extends RefCounted
## 威胁软上限、驻守、隐蔽与版本化快照的真实规则边界。


static func run(check: Callable) -> void:
	_test_pressure(check)
	_test_environment(check)
	_test_concealment(check)
	_test_snapshot(check)
	_test_bosses(check)


static func _fresh(region: GameTypes.Region = GameTypes.Region.RURAL) -> VillageState:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(65012, region)
	return state


static func _test_pressure(check: Callable) -> void:
	var state: VillageState = _fresh()
	var initial: int = state.wave_count()
	state.day = 99
	check.call(state.wave_count() == initial, "Calendar alone does not increase a wave")
	state.resources[GameTypes.Stock.NOISE] = 100
	check.call(state.wave_count() > initial, "Today's noise raises tonight's pressure")
	check.call(not EffectResolver.derive(state).boss_possible, "Noise alone cannot unlock a boss")
	var noisy: int = state.wave_count()
	SurvivalTestSetup.developed(state)
	check.call(state.wave_count() > noisy, "Real explored territory adds bounded pressure")
	var explored: int = state.wave_count()
	state.buildings[GameTypes.Building.WALL] = 1
	state.buildings[GameTypes.Building.WORKSHOP] = 1
	check.call(state.wave_count() > explored, "Built facilities add development pressure")
	state.add_resource(GameTypes.Stock.POLLUTION, 99999)
	check.call(
		state.resources[GameTypes.Stock.POLLUTION] == 100, "Pollution cannot grow without bound"
	)
	check.call(state.wave_count() < 60, "Combined contributions remain below configured ceiling")
	var rules: NightThreatRules = (
		state.catalog.library.progression_rules.night_threat.duplicate() as NightThreatRules
	)
	rules.noise_half = 0
	check.call(not NightThreat.valid_rules(rules), "Zero saturation denominator is rejected")
	rules.noise_half = 24
	rules.boss_chance = NAN
	check.call(not NightThreat.valid_rules(rules), "Invalid elite probability is rejected")


static func _test_environment(check: Callable) -> void:
	for region: GameTypes.Region in [
		GameTypes.Region.MOUNTAIN, GameTypes.Region.RURAL, GameTypes.Region.RUINS
	]:
		var state: VillageState = _fresh(region)
		state.resources[GameTypes.Stock.NOISE] = 80
		state.resources[GameTypes.Stock.POLLUTION] = 8
		var recovery: int = (
			state.catalog.library.progression_rules.map_for(region).pollution_recovery
		)
		ProgressionEconomy.start_day(state)
		check.call(state.resources[GameTypes.Stock.NOISE] == 0, "Dawn clears only daily noise")
		check.call(
			state.resources[GameTypes.Stock.POLLUTION] == 8 - recovery,
			"Terrain recovers its authored pollution amount"
		)
		state.resources[GameTypes.Stock.POLLUTION] = 0
		ProgressionEconomy.start_day(state)
		check.call(
			state.resources[GameTypes.Stock.POLLUTION] == 0,
			"Ecology never makes negative pollution"
		)
	var industrial: VillageState = _fresh()
	industrial.buildings[GameTypes.Building.GENERATOR] = 1
	industrial.resources[GameTypes.Stock.FUEL] = 20
	var stats: VillageStats = EffectResolver.derive(industrial)
	check.call(stats.income[GameTypes.Stock.NOISE] > 0, "Facilities have automatic daily noise")
	var noisy_budget: int = stats.threat_budget
	var copy: VillageStats = stats.copy_snapshot()
	copy.income[GameTypes.Stock.NOISE] = 0
	NightThreat.derive(industrial, copy)
	check.call(noisy_budget > copy.threat_budget, "Production noise affects the same night")


static func _test_concealment(check: Callable) -> void:
	var state: VillageState = _fresh()
	SurvivalTestSetup.select_frontier(state)
	state.play_card(state.hand[0].uid)
	state.day = 2
	SurvivalRules.grant_available(state)
	var quiet: CardDefinition = state.catalog.get_card("quiet")
	var uid: int = -1
	for entry: CardInstance in state.hand:
		if entry.definition == quiet:
			uid = entry.uid
	check.call(uid >= 0 and quiet.reusable, "Concealment is available after day one and reusable")
	var stock: PackedInt32Array = state.resources.duplicate()
	var rng_state: int = state.rng.state
	var preview: VillageStats = state.preview_card(quiet)
	check.call(
		preview.threat_budget == 0 and preview.attack < EffectResolver.derive(state).attack,
		"Quiet small camp can avoid detection at a combat penalty"
	)
	check.call(
		state.resources == stock and state.rng.state == rng_state and not state.progress.concealed,
		"Concealment preview has no effects or random rolls"
	)
	check.call(state.play_card(uid), "Actual concealment card commits through normal costs")
	state.begin_night()
	var battle: BattleSimulation = BattleSimulation.new()
	battle.finished.connect(state.finish_night)
	battle.start(state)
	battle.step(BattleSimulation.FIXED_STEP_SECONDS)
	check.call(
		not battle.active and battle.spawned == 0 and state.last_report != null,
		"Undetected night resolves normally with no zombies"
	)
	SurvivalTestSetup.settle_day_end(state)
	check.call(
		not state.progress.concealed and state.resources[GameTypes.Stock.NOISE] == 0,
		"Concealment ends at the next dawn"
	)
	SurvivalTestSetup.developed(state)
	state.progress.concealed = true
	check.call(
		EffectResolver.derive(state).threat_budget > 0,
		"Explored settlement cannot permanently hide from every wave"
	)


static func _test_snapshot(check: Callable) -> void:
	var state: VillageState = _fresh()
	state.resources[GameTypes.Stock.NOISE] = 50
	state.begin_night()
	var budget: int = state.wave_count()
	state.resources[GameTypes.Stock.NOISE] = 0
	check.call(
		state.wave_count() == budget, "Frozen night budget does not follow later inventory changes"
	)
	var save: VillageSaveData = state.snapshot()
	var restored: VillageState = _fresh()
	check.call(
		restored.restore(save) and restored.wave_count() == budget,
		"Version 10 restores frozen pressure"
	)
	save.night_stats.threat_budget = -1
	check.call(
		not restored.restore(save) and restored.wave_count() == budget,
		"Invalid threat snapshot is atomically rejected"
	)
	save = state.snapshot()
	save.version = 9
	check.call(
		restored.restore(save) and restored.wave_count() == 11,
		"Version 9 night retains its legacy wave on migration"
	)
	check.call(restored.snapshot().version == 10, "Legacy snapshot upgrades when saved")


static func _test_bosses(check: Callable) -> void:
	var spawned: int = 0
	var quiet_nights: int = 0
	for seed_value: int in range(24):
		var state: VillageState = _fresh()
		SurvivalTestSetup.developed(state)
		state.run_seed = seed_value
		state.resources[GameTypes.Stock.NOISE] = 100
		state.resources[GameTypes.Stock.POLLUTION] = 100
		for definition: BuildingDefinition in state.catalog.library.buildings:
			state.buildings[definition.id] = definition.max_level
		state.begin_night()
		check.call(state.night_stats.boss_possible, "Combined mature pressure enables elite chance")
		var battle: BattleSimulation = BattleSimulation.new()
		battle.start(state)
		for tick: int in 1200:
			if not battle.active:
				break
			battle.step(BattleSimulation.FIXED_STEP_SECONDS)
		if battle.boss_spawned:
			spawned += 1
		else:
			quiet_nights += 1
	print("MATURE PRESSURE: 24 seeds, %d bosses, %d without bosses" % [spawned, quiet_nights])
	check.call(
		spawned > 0 and quiet_nights > 0, "Mature high noise does not force a boss every night"
	)
