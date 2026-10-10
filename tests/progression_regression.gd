class_name ProgressionRegression
extends RefCounted


static func run(check: Callable) -> void:
	_test_mood(check)
	_test_events(check)
	_test_growth(check)
	_test_combat(check)
	_test_migration(check)
	_test_special_effects(check)
	_test_later_days(check)


static func _fresh(region: GameTypes.Region = GameTypes.Region.RURAL) -> VillageState:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(59172, region)
	state.choose_daily_event(1)
	state.actions_per_slot = 4
	return state


static func _uid(state: VillageState, id: String) -> int:
	for entry: CardInstance in state.hand:
		if entry.definition.id == id:
			return entry.uid
	return -1


static func _play(state: VillageState, id: String) -> bool:
	var uid: int = _uid(state, id)
	if uid < 0:
		var card: CardInstance = CardInstance.new()
		card.definition = state.catalog.cards[id]
		card.uid = state.next_uid
		state.next_uid += 1
		state.hand.append(card)
		uid = card.uid
	return state.play_card(uid)


static func _test_mood(check: Callable) -> void:
	var state: VillageState = _fresh()
	check.call(
		_play(state, "forage") and state.progress.frustration == 0, "First labor has no frustration"
	)
	check.call(
		_play(state, "forage") and state.progress.frustration == 1, "Second labor creates one mood"
	)
	var card: CardDefinition = state.catalog.cards["forage"]
	check.call(
		EffectResolver.cost_totals(card, state)[0] == 14,
		"Mood raises subsequent cost with one rounding"
	)
	var saved: VillageSaveData = state.snapshot()
	state.preview_card(card)
	state.preview_card(card)
	check.call(
		state.progress.streak == saved.progress.streak and state.progress.frustration == 1,
		"Preview cannot add mood or labor"
	)
	state.resources[0] = 0
	check.call(
		not _play(state, "forage") and state.progress.streak == 2,
		"Failed labor cannot increment streak"
	)
	state.resources[0] = 100
	check.call(
		_play(state, "water") and state.progress.frustration == 1 and state.progress.streak == 1,
		"Changing work preserves existing mood"
	)
	state.skip_slot()
	check.call(
		state.progress.frustration == 0 and state.progress.last_labor == GameTypes.Labor.NONE,
		"Standby always resolves negative feedback"
	)
	state = _fresh()
	state.progress.frustration = 3
	var expected: int = EffectResolver.cost_totals(state.catalog.cards["vent"], state)[0]
	var stamina: int = state.resources[0]
	check.call(_play(state, "vent"), "Frustration can be spent on defense")
	check.call(
		state.resources[0] == stamina - expected and state.progress.frustration == 0,
		"Vent pays pre-consumption mood cost"
	)
	check.call(
		is_equal_approx(EffectResolver.derive(state).attack, 9.0 * 1.24),
		"Three mood becomes 24 percent attack"
	)
	check.call(not _play(state, "vent"), "Zero mood cannot produce free defense")
	state = _fresh()
	check.call(_play(state, "chant"), "Chant strategy activates")
	check.call(_play(state, "forage") and _play(state, "forage"), "Chant labor chain commits")
	check.call(
		state.progress.chant_uses == 1 and state.resources[0] == 49,
		"Chant refunds only actual labor mood"
	)
	state.progress.frustration = 5
	check.call(
		_play(state, "forage") and state.progress.chant_uses == 1,
		"Mood overflow cannot trigger refund"
	)
	state = _fresh()
	check.call(
		_play(state, "practice") and _play(state, "forage"), "Practice activates before labor"
	)
	var normal: int = EffectResolver.resource_deltas(state, state.catalog.cards["forage"])[1]
	check.call(
		normal == floori(12 * 1.25 * 1.25), "Practice applies to repeated positive base output"
	)
	state = _fresh()
	check.call(_play(state, "rotation") and _play(state, "forage"), "Rotation activates")
	check.call(
		(
			EffectResolver.resource_deltas(state, state.catalog.cards["water"])[2]
			== floori(13 * 1.2 * 1.25)
		),
		"Rotation applies on changing labor"
	)


static func _test_events(check: Callable) -> void:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(98, GameTypes.Region.MOUNTAIN)
	check.call(
		state.progress.event_id == "settle" and state.progress.event_choice == -1,
		"First day has fixed pending event"
	)
	check.call(not _play(state, "forage"), "Pending event blocks labor")
	state.skip_slot()
	state.begin_night()
	check.call(
		state.phase == GameTypes.Phase.DAY and state.slot == 0,
		"Pending event blocks standby and dusk bypass"
	)
	var restored: VillageState = _fresh()
	check.call(
		restored.restore(state.snapshot()) and restored.progress.event_choice == -1,
		"Pending event survives save"
	)
	var rng_before: int = state.rng.state
	check.call(state.choose_daily_event(0), "Event choice commits without action")
	check.call(
		not state.choose_daily_event(1) and state.actions_used == 0,
		"Event commits exactly once without consuming action"
	)
	check.call(state.rng.state == rng_before, "Event does not consume reward RNG")
	for day: int in range(2, 20):
		state.day = day
		var first: DailyEvent = state.catalog.library.progression_rules.for_day(state)
		var second: DailyEvent = state.catalog.library.progression_rules.for_day(state)
		check.call(
			first.id == second.id and not state.progress.recent_events.has(first.id),
			"Event is reproducible and respects cooldown"
		)
		check.call(
			first.regions.is_empty() or first.regions.has(GameTypes.Region.MOUNTAIN),
			"Event respects map"
		)
		ProgressionEconomy.start_day(state)
	state.progress.region = GameTypes.Region.RUINS
	state.progress.event_id = "convoy"
	state.progress.event_choice = -1
	state.resources[1] = 0
	var before: PackedInt32Array = state.resources.duplicate()
	check.call(
		(
			not state.choose_daily_event(0)
			and state.resources == before
			and state.progress.event_choice == -1
		),
		"Unpayable event preserves transaction"
	)
	check.call(state.choose_daily_event(1), "Event always has free fallback")
	state = _fresh()
	state.progress.event_id = "low_mood"
	state.progress.event_choice = 0
	check.call(
		_play(state, "forage") and _play(state, "forage") and state.progress.frustration == 2,
		"Low mood affects first repeat"
	)
	check.call(
		_play(state, "forage") and state.progress.frustration == 3,
		"Low mood extra penalty happens once"
	)


static func _test_growth(check: Callable) -> void:
	var state: VillageState = _fresh(GameTypes.Region.RUINS)
	state.population = 20
	state.profession_counts = [15, 1, 1, 1, 1, 1]
	PopulationRules.reconcile(state)
	state.resources[0] = 100
	state.resources[2] = 100
	var card: CardDefinition = state.catalog.cards["salvage"]
	var costs: PackedInt32Array = EffectResolver.cost_totals(card, state)
	var deltas: PackedInt32Array = EffectResolver.resource_deltas(state, card)
	check.call(costs[0] == 34 and costs[2] == 8, "Four-person labor costs grow additively")
	check.call(
		deltas[9] == floori(23 * 1.3) and deltas[7] == 10 and deltas[5] == 16,
		"Four-person salvage output respects map"
	)
	var before: PackedInt32Array = state.resources.duplicate()
	check.call(_play(state, "salvage"), "Large crew can commit")
	for key: int in GameTypes.Stock.COUNT:
		check.call(
			(
				state.resources[key]
				== clampi(before[key] + deltas[key], 0, GameTypes.STOCK_LIMITS[key])
			),
			"Preview and commit use identical stock deltas"
		)
	check.call(
		state.progress.deposits[2] == 396 and state.progress.streak == 1,
		"Large crew consumes deposit but counts one labor"
	)
	check.call(
		state.set_crew(1) and LaborRules.crew_size(state, card) == 1, "Player can choose small crew"
	)
	state.progress.deposits[2] = 0
	check.call(not _play(state, "salvage"), "Empty deposit rejects extraction")
	state.progress.deposits[0] = 0
	check.call(
		EffectResolver.resource_deltas(state, state.catalog.cards["forage"])[1] == 2,
		"Exhausted forage retains low-yield fallback"
	)
	state = _fresh()
	var ids: PackedInt32Array = []
	for person: SurvivorRecord in state.progress.survivors:
		ids.append(person.id)
	check.call(
		not state.assign_jobs(PackedInt32Array([0, 0, 0, 0, 0, 4])), "Invalid roster rejected"
	)
	check.call(
		state.assign_jobs(PackedInt32Array([0, 0, 0, 0, 1, 4]), false), "Dawn jobs can be assigned"
	)
	check.call(
		not state.assign_jobs(PackedInt32Array([0, 1, 1, 1, 1, 1])),
		"Jobs cannot be reassigned repeatedly"
	)
	check.call(
		state.progress.survivors[4].id == ids[4] and not state.progress.survivors[4].archer,
		"Job changes preserve stable identity and equipment"
	)
	check.call(
		EffectResolver.cost_totals(state.catalog.cards["generator"], state)[9] > 0,
		"Industrial construction consumes parts"
	)
	check.call(
		EffectResolver.cost_totals(state.catalog.cards["wall"], state)[7] > 0,
		"Wood defense consumes wood"
	)
	state.buildings[GameTypes.Building.GENERATOR] = 1
	state.resources[10] = 0
	check.call(EffectResolver.derive(state).income[3] == 0, "Generator cannot produce without fuel")
	state.resources[10] = 2
	check.call(EffectResolver.derive(state).upkeep[10] == 2, "Generator has explicit fuel upkeep")


static func _test_combat(check: Callable) -> void:
	for region: GameTypes.Region in [
		GameTypes.Region.MOUNTAIN, GameTypes.Region.RURAL, GameTypes.Region.RUINS
	]:
		var state: VillageState = _fresh(region)
		state.population = 8
		PopulationRules.reconcile(state)
		state.buildings[GameTypes.Building.BOWS] = 1
		state.buildings[GameTypes.Building.WALL] = 1
		state.resources[11] = 4
		state.begin_night()
		var battle: BattleSimulation = BattleSimulation.new()
		battle.start(state)
		var archer_count: int = 0
		for guard: CombatActor in battle.guards:
			if guard.unit == GameTypes.Unit.ARCHER:
				archer_count += 1
		check.call(
			archer_count == state.profession_counts[GameTypes.Profession.GUARD],
			"Only equipped guards are archers"
		)
		battle.finished.connect(state.finish_night)
		while battle.active:
			battle.step(BattleSimulation.FIXED_STEP_SECONDS)
		check.call(
			state.last_report != null and state.phase != GameTypes.Phase.NIGHT,
			"Every map completes real battle"
		)
		check.call(
			(
				state.last_report.has_identities
				and state.last_report.survivor_ids.size() == state.population
			),
			"Battle reports actual survivor identities"
		)
		check.call(
			(
				state.last_report.consumed[11] <= 4
				and state.resources[11] == 4 - state.last_report.consumed[11]
			),
			"Arrows never exceed reservation and settle once"
		)
		check.call(state.restore(state.snapshot()), "Modern post-battle snapshot roundtrips")
	var state: VillageState = _fresh()
	state.begin_night()
	var invalid: BattleReport = BattleReport.new()
	invalid.core_health = state.core_health
	invalid.survivors = 1
	invalid.started_survivors = state.population
	invalid.has_identities = true
	invalid.survivor_ids = [9999]
	state.finish_night(invalid)
	check.call(
		state.phase == GameTypes.Phase.NIGHT and state.population == 5,
		"Foreign survivor identity rejected atomically"
	)
	var battle: BattleSimulation = BattleSimulation.new()
	battle.start(state)
	var medic: CombatActor = battle.guards[3]
	var wounded: CombatActor = battle.guards[0]
	wounded.pos = medic.pos
	wounded.hp = 10
	battle.support.update(battle, 1.0)
	check.call(
		wounded.hp == 32 and battle.support.consumed[12] == 1,
		"Medic consumes finite medicine for real healing"
	)
	var screamer: CombatActor = CombatActor.new()
	screamer.kind = GameTypes.Enemy.SCREAMER
	battle.enemies.append(screamer)
	var budget: int = battle.total_to_spawn
	for iteration: int in 20:
		battle.special.update(battle, 10.0)
	check.call(
		battle.total_to_spawn == budget + 2,
		"Screamer adds finite reinforcements to completion budget"
	)
	var hidden: CombatActor = CombatActor.new()
	hidden.kind = GameTypes.Enemy.LURKER
	hidden.pos = WorldLayout.CENTER + Vector2(150, 0)
	var observer: CombatActor = CombatActor.new()
	observer.pos = hidden.pos - Vector2(80, 0)
	check.call(
		not battle.support.visible(hidden, observer, battle),
		"Lurker hides outside ordinary detection"
	)
	observer.unit = GameTypes.Unit.SCOUT
	check.call(
		battle.support.visible(hidden, observer, battle), "Scout reveals lurker without electricity"
	)
	state = _fresh()
	state.buildings[GameTypes.Building.LIGHTS] = 1
	state.resources[3] = 20
	check.call(
		(
			EffectResolver.derive(state).attack == 9.0
			and EffectResolver.derive(state).attack_range == 100.0
		),
		"Modern electric lights do not enhance physical attack"
	)


static func _test_migration(check: Callable) -> void:
	var state: VillageState = _fresh()
	var saved: VillageSaveData = state.snapshot()
	saved.version = 4
	saved.resources = [70, 24, 24, 0, 18, 0, 0]
	saved.progress = null
	check.call(state.restore(saved), "Version four seven-stock save migrates")
	check.call(
		(
			state.progress.region == GameTypes.Region.LEGACY
			and state.resources[4] == 18
			and state.resources.size() == 13
		),
		"Migration preserves material meaning in compatibility map"
	)
	check.call(state.restore(state.snapshot()), "Migrated save can roundtrip as current version")
	var invalid: VillageSaveData = state.snapshot()
	invalid.progress.survivors[0].id = invalid.progress.survivors[1].id
	check.call(
		not state.restore(invalid) and state.resources[4] == 18,
		"Duplicate identities cannot partially restore"
	)


static func _test_special_effects(check: Callable) -> void:
	var state: VillageState = _fresh()
	state.buildings[GameTypes.Building.WALL] = 1
	state.begin_night()
	var battle: BattleSimulation = BattleSimulation.new()
	battle.start(state)
	var builder: CombatActor = battle.guards[1]
	var cell: Vector2i = WorldLayout.wall_cells()[0]
	builder.pos = WorldLayout.to_point(cell)
	battle.walls[cell].hp -= 40
	var old_hp: float = battle.walls[cell].hp
	battle.support.update(battle, 0.1)
	check.call(
		battle.walls[cell].hp == old_hp + 18 and battle.support.consumed[7] == 1,
		"Builder repairs damaged wall with actual wood"
	)
	var engineer: CombatActor = battle.guards[2]
	engineer.pos = WorldLayout.CENTER
	engineer.support_timer = 0
	battle.core_health = 200
	battle.support.update(battle, 0.1)
	check.call(
		battle.core_health == 208 and battle.support.consumed[9] == 1,
		"Engineer repairs village with actual parts"
	)
	var armored: CombatActor = CombatActor.new()
	armored.kind = GameTypes.Enemy.ARMORED
	armored.hp = 100
	armored.pos = WorldLayout.CENTER
	battle.enemies = [armored]
	battle.projectiles = [ProjectileState.new(armored.pos, armored, 3, true)]
	battle._update_projectiles(0.1)
	check.call(armored.hp == 99, "Armor has safe minimum damage")
	battle.stats.piercing = true
	battle.projectiles = [ProjectileState.new(armored.pos, armored, 3, true)]
	battle._update_projectiles(0.1)
	check.call(armored.hp == 96, "Piercing arrows bypass armor")
	var guard: CombatActor = battle.guards[0]
	guard.pos = WorldLayout.CENTER
	battle.guards = [guard]
	var acid: CombatActor = CombatActor.new()
	acid.kind = GameTypes.Enemy.SPITTER
	acid.pos = guard.pos + Vector2(75, 0)
	battle.enemies = [acid]
	battle._update_enemies(0.1)
	check.call(battle.special.hazards.size() == 1, "Spitter attacks remotely and creates corrosion")
	acid.cooldown = 0
	acid.pos = WorldLayout.to_point(Vector2i(3, 4))
	guard.pos = WorldLayout.to_point(Vector2i(8, 4))
	battle.state.progress.region = GameTypes.Region.RUINS
	battle.start(battle.state)
	check.call(battle.enemy_grid.is_point_solid(Vector2i(5, 4)), "Ruins block navigation")
	var fire: CombatActor = CombatActor.new()
	fire.kind = GameTypes.Enemy.BURNER
	fire.hp = 0
	fire.pos = battle.guards[0].pos
	battle.enemies = [fire]
	battle.step(BattleSimulation.FIXED_STEP_SECONDS)
	check.call(not battle.special.hazards.is_empty(), "Burner death creates finite fire")
	battle.enemies.clear()
	battle.spawned = battle.total_to_spawn
	battle.step(BattleSimulation.FIXED_STEP_SECONDS)
	check.call(battle.active, "Remaining fire cannot be skipped by early victory")
	for frame: int in 130:
		battle.step(BattleSimulation.FIXED_STEP_SECONDS)
	check.call(
		not battle.active and battle.special.hazards.is_empty(),
		"Fire expires and battle can finish"
	)
	state = _fresh()
	state.begin_night()
	var saved: VillageSaveData = state.snapshot()
	saved.night_stats.roster.clear()
	check.call(
		not state.restore(saved) and state.phase == GameTypes.Phase.NIGHT,
		"Missing frozen identity roster rejects restore"
	)
	var frozen: VillageSaveData = state.snapshot()
	var restored: VillageState = _fresh()
	check.call(restored.restore(frozen), "Modern dusk snapshot restores")
	var first: BattleSimulation = BattleSimulation.new()
	var second: BattleSimulation = BattleSimulation.new()
	first.start(state)
	second.start(restored)
	for frame: int in 240:
		first.step(BattleSimulation.FIXED_STEP_SECONDS)
		second.step(BattleSimulation.FIXED_STEP_SECONDS)
	check.call(
		(
			first.kills == second.kills
			and first.spawned == second.spawned
			and first.support.consumed == second.support.consumed
		),
		"Night restart reproduces attacks and consumables"
	)
	check.call(
		first.guards[0].pos.is_equal_approx(second.guards[0].pos),
		"Night restart reproduces navigation"
	)


static func _test_later_days(check: Callable) -> void:
	for day: int in [5, 8]:
		var state: VillageState = _fresh(GameTypes.Region.RUINS)
		state.day = day
		state.population = 20
		PopulationRules.reconcile(state)
		state.buildings[GameTypes.Building.WALL] = 2
		state.buildings[GameTypes.Building.BOWS] = 1
		state.buildings[GameTypes.Building.TRAPS] = 1
		state.resources[11] = 300
		state.begin_night()
		var budget: int = state.wave_count()
		var battle: BattleSimulation = BattleSimulation.new()
		battle.finished.connect(state.finish_night)
		battle.start(state)
		while battle.active:
			battle.step(BattleSimulation.FIXED_STEP_SECONDS)
		check.call(
			state.last_report != null and state.phase == GameTypes.Phase.REWARD,
			"Developed village survives real special wave"
		)
		check.call(
			battle.total_to_spawn < budget + 4, "Elite threats replace multiple ordinary enemies"
		)
		check.call(state.restore(state.snapshot()), "Late special battle report roundtrips")
		var malformed: VillageSaveData = state.snapshot()
		malformed.night_stats.roster[0].id = malformed.progress.next_person_id + 100
		check.call(
			not state.restore(malformed), "Reward restoration rejects a foreign frozen identity"
		)
		check.call(state.choose_reward(0), "Special wave reaches next dawn")
		state.choose_daily_event(1)
		state.population += 2
		PopulationRules.reconcile(state)
		check.call(
			state.restore(state.snapshot()), "Day growth does not invalidate historical dusk roster"
		)
		var identities: PackedInt32Array = []
		for person: SurvivorRecord in state.progress.survivors:
			identities.append(person.id)
		state.resources[GameTypes.Stock.FOOD] = 100
		state.resources[GameTypes.Stock.WATER] = 100
		check.call(_play(state, "rest"), "Growing village can still preview and commit recovery")
		check.call(
			state.progress.survivors[0].id == identities[0],
			"Ordinary cards do not reshuffle stable identities"
		)
