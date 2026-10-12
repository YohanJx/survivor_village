extends SceneTree
## 验证真实规则与存档行为，全部测试关闭玩家自动存档。

const TEST_SAVE_PATH: String = "res://test-results/roundtrip.tres"

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	PlayerFeedbackRegression.run(_check)
	_test_catalog()
	VillagePresentationRegression.run(_check)
	KeywordRegression.run(_check)
	TerrainRegression.run(_check)
	SurvivalRegression.run(_check)
	ValidationRegression.run(_check)
	WorkforceRegression.run(_check)
	WeatherRegression.run(_check)
	TradeoffRegression.run(_check)
	DayEndEventRegression.run(_check)
	ProgressionRegression.run(_check)
	_test_transactions()
	_test_synergies()
	_test_dawn()
	_test_snapshots_and_save()
	_test_navigation()
	BattleDefenseRegression.run(_check)
	NightThreatRegression.run(_check)
	_test_battles()
	print("TEST RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)


func _fresh(seed_value: int = 12345) -> VillageState:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(seed_value)
	SurvivalTestSetup.developed(state)
	return state


func _uid_for(state: VillageState, id: String) -> int:
	for entry: CardInstance in state.hand:
		if entry.definition.id == id:
			return entry.uid
	state.add_card(state.catalog.get_card(id))
	return state.hand.back().uid


func _win_report(state: VillageState) -> BattleReport:
	var report: BattleReport = BattleReport.new()
	report.core_health = state.core_health
	report.survivors = state.population
	report.kills = state.wave_count()
	report.started_survivors = state.population
	report.duration = 50.0
	return report


func _hand_ids(hand: Array[CardInstance]) -> PackedStringArray:
	var result: PackedStringArray = []
	for instance: CardInstance in hand:
		result.append("%d:%s" % [instance.uid, instance.definition.id])
	return result


func _test_catalog() -> void:
	var state: VillageState = _fresh()
	_check(state.catalog.library is CardLibrary, "Native Resource library loaded")
	_check(state.catalog.library.cards.size() == 47, "All 47 authored cards registered")
	_check(
		state.catalog.library.buildings.size() == GameTypes.Building.COUNT,
		"Building enum registration complete"
	)
	for card: CardDefinition in state.catalog.library.cards:
		_check(
			not card.positive.is_empty() and not card.negative.is_empty(),
			"Both sides described: " + card.id
		)
		_check(
			card.resource_path.ends_with(".tres"), "Card is an editable native asset: " + card.id
		)
		for effect: CardEffect in card.effects:
			_check(effect != null, "Effect is a typed Resource")
			if effect.type == CardEffect.Type.BUILD:
				_check(effect.building != null, "Construction effect references a building")
			elif effect.type == CardEffect.Type.MODIFIER:
				_check(
					effect.modifier != null and effect.modifier.duration > 0,
					"Timed modifier configured"
				)


func _test_transactions() -> void:
	var state: VillageState = _fresh()
	state.resources[GameTypes.Stock.MATERIALS] = 0
	var before: VillageSaveData = state.snapshot()
	_check(not state.play_card(_uid_for(state, "wall")), "Insufficient materials rejected")
	_check(
		state.resources == before.resources and state.slot == before.slot,
		"Rejected transaction is atomic"
	)
	state.resources[GameTypes.Stock.MATERIALS] = 30
	var wall_uid: int = _uid_for(state, "wall")
	_check(state.play_card(wall_uid), "Construction accepted")
	_check(
		state.buildings[GameTypes.Building.WALL] == 1 and state.slot == 1,
		"Build and advance exactly one slot"
	)
	_check(not state.play_card(wall_uid), "Consumed instance cannot be replayed")
	var forage_uid: int = _uid_for(state, "forage")
	_check(state.play_card(forage_uid), "Reusable action accepted")
	_check(state.find_card(forage_uid) != null, "Reusable card remains in hand")
	state.skip_slot()
	_check(state.phase == GameTypes.Phase.NIGHT and state.slot == 3, "Third decision starts night")
	_check(not state.play_card(forage_uid), "Day card rejected during night")
	var power_before: int = state.resources[GameTypes.Stock.POWER]
	state.begin_night()
	_check(
		state.resources[GameTypes.Stock.POWER] == power_before, "Repeated night entry is idempotent"
	)
	state.core_health = 220.0
	state.finish_night(_win_report(state))
	_check(
		state.phase == GameTypes.Phase.DAY_END and state.current_day_end_event() != null,
		"Victory opens a day-end event"
	)
	var hand_before: PackedStringArray = _hand_ids(state.hand)
	var kills_before: int = state.total_kills
	state.finish_night(_win_report(state))
	_check(state.total_kills == kills_before, "Duplicate battle completion does not pay twice")
	state.advance_dawn()
	_check(state.day == 2, "Dawn blocked until the day-end event is handled")
	_check(SurvivalTestSetup.settle_day_end(state), "Day-end option chosen")
	_check(
		state.day == 3 and state.slot == 0 and state.phase == GameTypes.Phase.DAY,
		"Day-end event advances to next dawn"
	)
	_check(
		not SurvivalTestSetup.settle_day_end(state) and state.day == 3,
		"Duplicate day-end event rejected"
	)
	state.advance_dawn()
	_check(state.day == 3, "Duplicate dawn rejected")
	_check(_hand_ids(state.hand) == hand_before, "Day-end event never adds its option to the hand")
	var duplicate_cost_card: CardDefinition = CardDefinition.new()
	duplicate_cost_card.id = "duplicate_cost_fixture"
	duplicate_cost_card.display_name = "重复费用夹具"
	duplicate_cost_card.positive = "收益"
	duplicate_cost_card.negative = "风险"
	var fixture_effect: CardEffect = CardEffect.new()
	fixture_effect.amount = 1
	duplicate_cost_card.effects = [fixture_effect]
	var cost: ResourceCost = ResourceCost.new()
	cost.key = GameTypes.Stock.STAMINA
	cost.amount = 6
	duplicate_cost_card.costs = [cost, cost]
	state.add_card(duplicate_cost_card)
	state.resources[GameTypes.Stock.STAMINA] = 10
	_check(
		not state.play_card(state.hand.back().uid),
		"Repeated cost entries aggregate before validation"
	)
	_check(
		state.resources[GameTypes.Stock.STAMINA] == 10,
		"Combined fee failure leaves stock unchanged"
	)

	state.resources[GameTypes.Stock.STAMINA] = 20
	_check(state.play_card(state.hand.back().uid), "Aggregated fee succeeds when affordable")
	_check(state.resources[GameTypes.Stock.STAMINA] == 8, "Repeated fee charges its full total")


func _test_synergies() -> void:
	var state: VillageState = _fresh()
	for building: int in [
		GameTypes.Building.GENERATOR,
		GameTypes.Building.LIGHTS,
		GameTypes.Building.FARM,
		GameTypes.Building.WELL,
		GameTypes.Building.GREENHOUSE
	]:
		state.buildings[building] = 1
	state.resources[GameTypes.Stock.POWER] = 7
	var stats: VillageStats = EffectResolver.derive(state)
	_check(
		(
			stats.lights_active
			and stats.irrigation_active
			and stats.upkeep[GameTypes.Stock.POWER] == 7
		),
		"Both electric synergies active"
	)
	_check(
		stats.income[GameTypes.Stock.FOOD] == 10 and stats.upkeep[GameTypes.Stock.WATER] == 5,
		"Irrigation production and water saving"
	)
	state.resources[GameTypes.Stock.POWER] = 6
	stats = EffectResolver.derive(state)
	_check(stats.lights_active and not stats.irrigation_active, "Deterministic power priority")
	state.resources[GameTypes.Stock.POLLUTION] = 12
	_check(
		EffectResolver.derive(state).income[GameTypes.Stock.WATER] == 5,
		"Pollution reduces well yield"
	)
	state.buildings[GameTypes.Building.FILTER] = 1
	_check(
		EffectResolver.derive(state).income[GameTypes.Stock.WATER] == 8,
		"Filter prevents yield loss"
	)
	state.resources[GameTypes.Stock.POWER] = 10
	var multiply: StatModifier = StatModifier.new()
	multiply.key = GameTypes.Stat.ATTACK
	multiply.operation = StatModifier.Operation.MULTIPLY
	multiply.amount = 1.4
	multiply.remaining = 1
	var addition: StatModifier = StatModifier.new()
	addition.key = GameTypes.Stat.ATTACK
	addition.amount = 5
	addition.remaining = 1
	state.modifiers = [multiply, addition]
	_check(
		is_equal_approx(EffectResolver.derive(state).attack, 14.0 * 1.4 * 1.25),
		"Addition precedes all multipliers"
	)
	state.modifiers.reverse()
	_check(
		is_equal_approx(EffectResolver.derive(state).attack, 14.0 * 1.4 * 1.25),
		"Modifier insertion order does not affect result"
	)
	EffectResolver.apply(state, state.catalog.get_card("quiet"))
	stats = EffectResolver.derive(state)
	_check(
		not stats.lights_active and stats.irrigation_active,
		"Blackout disables lights and frees power"
	)
	EffectResolver.expire_after_night(state)
	_check(state.modifiers.is_empty(), "One-night effects expire")
	_check(not state.can_play(_uid_for(state, "filter")).is_empty(), "Maximum level enforced")
	var empty: VillageState = _fresh()
	_check(
		not empty.can_play(_uid_for(empty, "lights")).is_empty(), "Technology dependency enforced"
	)
	var shared_training: CardDefinition = state.catalog.get_card("training")
	var template: StatModifier = shared_training.effects[0].modifier
	EffectResolver.apply(empty, shared_training)
	_check(
		template.remaining == 0 and template.source.is_empty(),
		"Shared modifier definition never receives runtime state"
	)
	empty.modifiers[0].remaining = 8
	_check(template.duration == 1 and template.remaining == 0, "Runtime modifier owns its lifetime")
	var preview_before: VillageSaveData = empty.snapshot()
	empty.preview_card(shared_training)
	_check(
		(
			empty.resources == preview_before.resources
			and empty.modifiers.size() == preview_before.modifiers.size()
		),
		"Preview is side-effect free"
	)


func _test_dawn() -> void:
	var state: VillageState = _fresh()
	state.resources[GameTypes.Stock.FOOD] = 20
	state.buildings[GameTypes.Building.FOOD_STORE] = 1
	state.buildings[GameTypes.Building.WATER_TANK] = 1
	state.buildings[GameTypes.Building.BATTERY] = 1
	state.resources[GameTypes.Stock.WATER] = 20
	state.resources[GameTypes.Stock.POWER] = 7
	for building: int in [
		GameTypes.Building.GENERATOR,
		GameTypes.Building.LIGHTS,
		GameTypes.Building.FARM,
		GameTypes.Building.WELL,
		GameTypes.Building.GREENHOUSE
	]:
		state.buildings[building] = 1
	state.begin_night()
	_check(state.resources[GameTypes.Stock.POWER] == 0, "Electricity charged once at dusk")
	var loaded: VillageState = _fresh()
	_check(loaded.restore(state.snapshot()), "Night snapshot restores")
	_check(
		loaded.resources[GameTypes.Stock.POWER] == 0 and loaded.night_stats.lights_active,
		"Restore retains power allocation without another payment"
	)
	state.finish_night(_win_report(state))
	SurvivalTestSetup.settle_day_end(state)
	_check(state.resources[GameTypes.Stock.FOOD] == 25, "Dawn uses frozen irrigation yield")
	_check(
		(
			state.resources[GameTypes.Stock.WATER] == 23
			and state.resources[GameTypes.Stock.POWER] == 8
		),
		"Income and upkeep settle together"
	)
	var poor: VillageState = _fresh()
	poor.resources[GameTypes.Stock.FOOD] = 0
	poor.resources[GameTypes.Stock.WATER] = 0
	poor.begin_night()
	poor.finish_night(_win_report(poor))
	SurvivalTestSetup.settle_day_end(poor)
	_check(poor.core_health < 240, "Food and water shortage damages core")
	_check(
		poor.resources[GameTypes.Stock.FOOD] >= 0 and poor.resources[GameTypes.Stock.WATER] >= 0,
		"Inventory never becomes negative"
	)


func _test_snapshots_and_save() -> void:
	var state: VillageState = _fresh()
	state.play_card(_uid_for(state, "wall"))
	state.play_card(_uid_for(state, "bows"))
	state.skip_slot()
	state.finish_night(_win_report(state))
	var snapshot: VillageSaveData = state.snapshot()
	state.resources[GameTypes.Stock.FOOD] += 1
	state.history[0].text = "updated live history"
	state.night_stats.values[GameTypes.Stat.ATTACK] += 1
	_check(snapshot.resources != state.resources, "Stock snapshot isolated")
	_check(snapshot.history[0].text != state.history[0].text, "History snapshot isolated")
	_check(snapshot.night_stats.attack != state.night_stats.attack, "Night stats snapshot isolated")
	DirAccess.make_dir_recursive_absolute("res://test-results")
	_check(state.save_game(TEST_SAVE_PATH), "Native Resource save written atomically")
	var loaded: VillageState = _fresh(888)
	_check(loaded.load_game(TEST_SAVE_PATH), "Native save loaded")
	_check(
		loaded.day == state.day and loaded.day_end_event_id == state.day_end_event_id,
		"Pending day-end event preserved"
	)
	_check(_hand_ids(loaded.hand) == _hand_ids(state.hand), "Hand instance identities preserved")
	_check(loaded.rng.state == state.rng.state, "64-bit RNG state preserved natively")
	_check(
		loaded.hand[0].definition == loaded.catalog.get_card(loaded.hand[0].definition.id),
		"Definitions rebound to current catalog"
	)
	var broken: VillageSaveData = state.snapshot()
	broken.version = 999
	_check(not loaded.restore(broken), "Incompatible version rejected")
	broken = state.snapshot()
	broken.resources.resize(2)
	_check(not loaded.restore(broken), "Incomplete inventory rejected")
	broken = state.snapshot()
	broken.hand[1].uid = broken.hand[0].uid
	_check(not loaded.restore(broken), "Duplicate instance IDs rejected")
	_check(loaded.resources == state.resources, "Failed restore leaves current state intact")
	SurvivalTestSetup.settle_day_end(state)
	_check(
		state.save_game(TEST_SAVE_PATH) and loaded.load_game(TEST_SAVE_PATH),
		"Overwriting a save bypasses stale loader cache"
	)
	_check(loaded.day == 3, "Latest saved state read from disk")
	var first: VillageState = _fresh()
	var second: VillageState = _fresh()
	first.begin_night()
	second.begin_night()
	first.finish_night(_win_report(first))
	second.finish_night(_win_report(second))
	_check(
		first.day_end_event_id == second.day_end_event_id, "Fixed-seed day-end events reproducible"
	)


func _test_navigation() -> void:
	var state: VillageState = _fresh()
	state.buildings[GameTypes.Building.WALL] = 1
	state.begin_night()
	var sim: BattleSimulation = BattleSimulation.new()
	sim.start(state)
	_check(sim.guard_grid.is_point_solid(Vector2i(19, 11)), "Building footprint blocks navigation")
	_check(sim.guard_grid.is_point_solid(Vector2i(14, 6)), "Intact fence blocks guards")
	_check(not sim.enemy_grid.is_point_solid(Vector2i(14, 6)), "Zombies may plan a breach")
	var path: Array[Vector2i] = sim.enemy_grid.get_id_path(Vector2i(0, 12), Vector2i(20, 14))
	_check(not path.is_empty(), "Open approach reaches village")
	for cell: Vector2i in path:
		_check(not sim.enemy_grid.is_point_solid(cell), "Route avoids solid terrain")
	var actor: CombatActor = CombatActor.new()
	actor.pos = WorldLayout.to_point(Vector2i(14, 5))
	actor.path = PackedVector2Array([WorldLayout.to_point(Vector2i(14, 6))])
	actor.repath = 100
	actor.damage = 100
	actor.hp = 1000
	actor.max_hp = 1000
	sim.enemies.append(actor)
	sim.step(BattleSimulation.FIXED_STEP_SECONDS)
	_check(
		(
			sim.walls[Vector2i(14, 6)].hp == 0
			and sim.enemy_grid.get_point_weight_scale(Vector2i(14, 6)) == 1.0
			and sim.guard_grid.is_point_solid(Vector2i(14, 6))
		),
		"Broken fence admits enemies while defenders keep the interior boundary"
	)


func _test_battles() -> void:
	for scenario: int in [1, 7]:
		var state: VillageState = _fresh()
		# 保留战后必须进入事件阶段的断言；夹具明确满足原生争执事件的条件。
		state.progress.frustration = 2
		if scenario == 1:
			state.play_card(_uid_for(state, "wall"))
			state.play_card(_uid_for(state, "bows"))
			state.play_card(_uid_for(state, "forage"))
		else:
			state.day = 7
			state.population = 8
			for building: int in [
				GameTypes.Building.WALL, GameTypes.Building.BOWS, GameTypes.Building.TRAPS
			]:
				state.buildings[building] = 2
			for building: int in [
				GameTypes.Building.LIGHTS, GameTypes.Building.GENERATOR, GameTypes.Building.CLINIC
			]:
				state.buildings[building] = 1
			state.resources[GameTypes.Stock.POWER] = 12
			state.resources[GameTypes.Stock.FOOD] = 100
			state.resources[GameTypes.Stock.WATER] = 100
			state.begin_night()
		_check(
			EventEligibility.matches(
				state, state.catalog.library.progression_rules.day_end_event_for("day_end_dispute")
			),
			"Battle fixture has a real pending dispute condition"
		)
		var sim: BattleSimulation = BattleSimulation.new()
		sim.finished.connect(state.finish_night)
		sim.start(state)
		for tick: int in 5401:
			if not sim.active:
				break
			sim.step(BattleSimulation.FIXED_STEP_SECONDS)
		_check(
			not sim.active and sim.elapsed < 179,
			"Night resolves without a stuck route: day %d" % scenario
		)
		_check(
			state.phase == GameTypes.Phase.DAY_END, "Developed village survives day %d" % scenario
		)
		if scenario == 7:
			_check(
				not sim.boss_spawned or state.last_report.boss_defeated,
				"Any pressure-driven boss that spawns is defeated"
			)
		print(
			(
				"BATTLE DAY %d: %.1f sec, %d/%d kills, %d survivors, %.1f core HP"
				% [
					scenario,
					sim.elapsed,
					sim.kills,
					sim.total_to_spawn,
					state.population,
					state.core_health
				]
			)
		)
