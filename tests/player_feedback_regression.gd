class_name PlayerFeedbackRegression
extends RefCounted
## 原生收支、封闭围墙与无需废墟的早期军备路径。


const SECOND_DAY: PackedStringArray = ["workshop", "bows", "forage"]
const THIRD_DAY: PackedStringArray = ["woodcut", "wall", "arrows"]
const FOURTH_DAY: PackedStringArray = ["well_tools", "well_survey", "well_survey"]
const SIXTH_DAY: PackedStringArray = ["well", "forage", "arrows"]


static func run(check: Callable) -> void:
	_test_balances(check)
	_test_fence(check)
	_test_late_progression(check)
	for region: GameTypes.Region in [GameTypes.Region.RURAL, GameTypes.Region.MOUNTAIN, GameTypes.Region.RUINS]:
		for seed_value: int in [12345, 65012, 99881]:
			_test_six_days(region, seed_value, check)


static func _test_balances(check: Callable) -> void:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(65012, GameTypes.Region.RURAL)
	state.weather = state.catalog.library.weather_rules.for_kind(WeatherDefinition.Kind.CLEAR)
	state.buildings[GameTypes.Building.WELL] = 1
	var before: int = state.rng.state
	var balance: ResourceBalance = EffectResolver.resource_balances(state)[GameTypes.Stock.WATER]
	check.call(balance.income == 8 and balance.upkeep == 5 and balance.net == 3, "Well income is separate from drinking upkeep and updates net flow")
	check.call(state.rng.state == before and state.resources[GameTypes.Stock.WATER] == 35, "Inventory forecast is read-only")


static func _test_fence(check: Callable) -> void:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(65012, GameTypes.Region.RURAL)
	state.buildings[GameTypes.Building.WALL] = 1
	state.begin_night()
	var sim: BattleSimulation = BattleSimulation.new()
	sim.start(state)
	for cell: Vector2i in WorldLayout.gate_cells():
		check.call(sim.walls.has(cell) and sim.walls[cell].hp > 0, "Former gate opening is fenced")
	for guard: CombatActor in sim.guards:
		guard.cooldown = 999.0
	sim.guards[0].pos = Vector2(360, 300)
	var enemy: CombatActor = CombatActor.new()
	enemy.pos = Vector2(335, 300)
	enemy.hp = 999.0
	enemy.speed = 30.0
	enemy.damage = 4.0
	sim.enemies.append(enemy)
	sim.spawned = sim.total_to_spawn
	var hp: float = sim.guards[0].hp
	for tick: int in 30:
		sim.step(BattleSimulation.FIXED_STEP_SECONDS)
	check.call(sim.guards[0].hp == hp, "Enemy cannot strike a defender through an intact fence")
	check.call(sim.walls[Vector2i(14, 12)].hp < sim.walls[Vector2i(14, 12)].max_hp, "Enemy attacks the fence before entering")


static func _test_late_progression(check: Callable) -> void:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(65012, GameTypes.Region.RURAL)
	SurvivalTestSetup.developed(state)
	state.buildings[GameTypes.Building.GENERATOR] = 1
	state.buildings[GameTypes.Building.WELL] = 1
	SurvivalRules.grant_available(state)
	check.call(_uid(state, "lights") >= 0 and _uid(state, "filter") >= 0, "Generator and well lead to later native technology cards")
	check.call(_uid(state, "survivors") >= 0, "Survivor search stays in the reachable card pool")
	var well: CardDefinition = state.catalog.get_card("well")
	check.call(not SurvivalRules.unlock_error(state, well).is_empty(), "A successful well blocks repeated drilling at the same site")
	state.buildings[GameTypes.Building.WELL] = 0
	check.call(SurvivalRules.unlock_error(state, well).is_empty(), "A failed well can be retried after surveying")
	state.progress.last_recruited_day = state.day
	check.call(not SurvivalRules.unlock_error(state, state.catalog.get_card("survivors")).is_empty(), "Survivors can be recruited only once per day")
	state.day += 1
	check.call(SurvivalRules.unlock_error(state, state.catalog.get_card("survivors")).is_empty(), "Survivor search reopens the next day")


static func _test_six_days(region: GameTypes.Region, seed_value: int, check: Callable) -> void:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(seed_value, region)
	for day: int in range(1, 7):
		if state.phase != GameTypes.Phase.DAY:
			check.call(false, "Six-day opening reaches next action phase")
			return
		state.assign_jobs(state.profession_counts.duplicate(), true)
		for slot: int in 3:
			var id: String = _planned_card(day, slot)
			if id == "explore":
				SurvivalTestSetup.select_frontier(state, GameTypes.Discovery.WOODLAND if slot == 0 else GameTypes.Discovery.FORAGE)
			var uid: int = _uid(state, id)
			if uid < 0 or not state.can_play(uid).is_empty():
				print("OPENING PLAN BLOCKED: region=%d seed=%d day=%d card=%s error=%s" % [region, seed_value, day, id, "not granted" if uid < 0 else state.can_play(uid)])
				state.skip_slot()
			else:
				state.play_card(uid)
		var sim: BattleSimulation = BattleSimulation.new()
		sim.finished.connect(state.finish_night)
		sim.start(state)
		while sim.active:
			sim.step(BattleSimulation.FIXED_STEP_SECONDS)
		if state.phase == GameTypes.Phase.DAY_END:
			SurvivalTestSetup.settle_day_end(state)
		if day == 1:
			var report: DayReport = state.last_day_report
			check.call(report != null and state.day_report_pending and report.day == 1, "The first survived night opens a day report")
			if report != null:
				check.call(report.resources_after == state.resources and report.resources_before.size() == GameTypes.Stock.COUNT, "Day report records settled stock values")
				var copy: VillageState = VillageState.new()
				copy.persistence_enabled = false
				check.call(copy.restore(state.snapshot()) and copy.day_report_pending, "Pending report survives a save roundtrip")
				copy.acknowledge_day_report()
				check.call(not copy.day_report_pending and copy.day == state.day, "Closing report does not settle the day twice")
		print("SIX DAY DEVELOPMENT: region=%d seed=%d day=%d population=%d bows=%d well=%d" % [region, seed_value, day, state.population, state.buildings[GameTypes.Building.BOWS], state.buildings[GameTypes.Building.WELL]])
		check.call(state.population >= 3 and state.core_health > 0, "Development plan retains a viable workforce through six nights")
		if day == 2:
			check.call(state.buildings[GameTypes.Building.BOWS] > 0, "Opening materials permit workshop and bows on day two")


static func _planned_card(day: int, slot: int) -> String:
	match day:
		1:
			return "explore"
		2:
			return SECOND_DAY[slot]
		3:
			return THIRD_DAY[slot]
		4:
			return FOURTH_DAY[slot]
		5:
			return "well_survey"
		_:
			return SIXTH_DAY[slot]


static func _uid(state: VillageState, id: String) -> int:
	for entry: CardInstance in state.hand:
		if entry.definition.id == id:
			return entry.uid
	return -1
