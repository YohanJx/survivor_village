class_name BattleDefenseRegression
extends RefCounted
## 驻守边界与连续前三夜使用真实新局、行动、战斗和日终结算。


static func run(check: Callable) -> void:
	_test_boundary(check)
	for region: GameTypes.Region in [
		GameTypes.Region.MOUNTAIN, GameTypes.Region.RURAL, GameTypes.Region.RUINS
	]:
		for seed_value: int in [12345, 65012, 99881]:
			_test_opening(region, seed_value, check)


static func _test_boundary(check: Callable) -> void:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(12345)
	state.begin_night()
	var sim: BattleSimulation = BattleSimulation.new()
	sim.start(state)
	var enemy: CombatActor = CombatActor.new()
	enemy.pos = Vector2(12, 300)
	sim.enemies.append(enemy)
	check.call(
		sim.support.target_for(sim.guards[0], sim) == null,
		"Far enemies do not lure defenders out of camp"
	)
	enemy.pos = sim.guards[0].pos + Vector2(10, 0)
	check.call(sim.support.target_for(sim.guards[0], sim) == enemy, "A village intruder is engaged")
	enemy.pos = Vector2(12, 300)
	var initial_position: Vector2 = sim.guards[0].pos

	for tick: int in 30:
		sim.step(BattleSimulation.FIXED_STEP_SECONDS)
	check.call(
		sim.guards[0].pos == initial_position, "Defender holds its post without any wandering"
	)
	for x: int in WorldLayout.GRID.x:
		for y: int in WorldLayout.GRID.y:
			var cell: Vector2i = Vector2i(x, y)
			if not WorldLayout.DEFENSE_CELLS.has_point(cell):
				check.call(
					sim.guard_grid.is_point_solid(cell),
					"Guard route cannot exit village: %s" % cell
				)


static func _test_opening(region: GameTypes.Region, seed_value: int, check: Callable) -> void:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(seed_value, region)
	for day: int in range(1, 4):
		while state.phase == GameTypes.Phase.DAY:
			SurvivalTestSetup.select_frontier(state)
			var uid: int = -1
			for card: CardInstance in state.hand:
				if card.definition.id == "explore":
					uid = card.uid
					break
			if not state.play_card(uid):
				check.call(false, "Opening exploration can be paid")
				return
		var sim: BattleSimulation = BattleSimulation.new()
		sim.finished.connect(state.finish_night)
		sim.start(state)
		var stayed_inside: bool = true
		var stayed_at_post: bool = true
		while sim.active:
			sim.step(BattleSimulation.FIXED_STEP_SECONDS)
			for guard: CombatActor in sim.guards:
				stayed_at_post = stayed_at_post and guard.pos == guard.home_pos
				stayed_inside = (
					stayed_inside
					and WorldLayout.DEFENSE_CELLS.has_point(WorldLayout.to_cell(guard.pos))
				)
		check.call(stayed_inside, "All guard movement stays inside camp")
		check.call(
			stayed_at_post, "All guards stay at exactly their initial post throughout the night"
		)
		print(
			(
				"OPENING DEFENSE: region=%d seed=%d night=%d survivors=%d core=%.1f duration=%.1f"
				% [region, seed_value, day, sim.guards.size(), sim.core_health, sim.elapsed]
			)
		)
		check.call(
			(
				state.phase in [GameTypes.Phase.DAY_END, GameTypes.Phase.DAY]
				and sim.elapsed < 179
				and sim.core_health > 0
				and not sim.guards.is_empty()
			),
			"Real opening survives night %d: region=%d seed=%d" % [day, region, seed_value]
		)
		if state.phase not in [GameTypes.Phase.DAY_END, GameTypes.Phase.DAY]:
			return
		if state.phase == GameTypes.Phase.DAY_END:
			check.call(
				SurvivalTestSetup.settle_day_end(state),
				"Real opening settles actual encounters and rations"
			)
		check.call(state.day == day + 1, "Battle and rations advance exactly one day")
