class_name SustainableProgressionRegression
extends RefCounted
## 实际出牌与夜战验证无河、无井的持续发展路线；不注入库存、设施或人口。

const PLAN: PackedStringArray = [
	"foraging_camp", "rain_collector", "workshop", "woodcut", "sawmill",
	"solar_still", "forest_rotation"
]


static func run(check: Callable) -> void:
	for region: GameTypes.Region in [GameTypes.Region.MOUNTAIN, GameTypes.Region.RURAL, GameTypes.Region.RUINS]:
		for seed_value: int in [12345, 65012, 99881]:
			_run_opening(region, seed_value, check)


static func _run_opening(region: GameTypes.Region, seed_value: int, check: Callable) -> void:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(seed_value, region)
	var step: int = 0
	var completed: bool = false
	var produced_without_card: bool = false
	for day: int in range(1, 9):
		if state.phase != GameTypes.Phase.DAY:
			check.call(false, "Sustainable opening reaches the next action phase")
			return
		state.acknowledge_day_report()
		for action: int in 3:
			if state.day == 1:
				_explore_for(state, _needed_discovery(state))
			elif step < PLAN.size():
				if _planned_action(state, PLAN[step]):
					step += 1
			else:
				state.skip_slot()
		var ready: bool = step == PLAN.size()
		var wood_before: int = state.resources[GameTypes.Stock.WOOD]
		var simulation: BattleSimulation = BattleSimulation.new()
		simulation.finished.connect(state.finish_night)
		simulation.start(state)
		while simulation.active:
			simulation.step(BattleSimulation.FIXED_STEP_SECONDS)
		if state.phase == GameTypes.Phase.DAY_END:
			SurvivalTestSetup.settle_day_end(state)
		if completed:
			produced_without_card = produced_without_card or state.resources[GameTypes.Stock.WOOD] > wood_before
		completed = completed or ready
		check.call(state.population >= 4 and state.core_health > 0, "Economic opening retains at least four survivors through eight real nights")
		check.call(state.progress.hungry_days == 0 and state.progress.thirsty_days == 0, "Automatic food and water avoid repeated shortage during construction")
	check.call(step == PLAN.size(), "Starter resources can reach condensation, solar water, forestry and cultivated food")
	check.call(produced_without_card, "Developed camp actually produces materials on days spent resting")
	check.call(state.buildings[GameTypes.Building.WELL] == 0 and state.buildings[GameTypes.Building.RIVER_WINDMILL] == 0, "Sustainable opening requires neither river infrastructure nor a lucky well")
	check.call(state.progress.well_drill_attempts == 0, "Sustainable opening never rolls or retries groundwater")
	var stats: VillageStats = EffectResolver.derive(state)
	check.call(stats.income[GameTypes.Stock.FOOD] >= stats.upkeep[GameTypes.Stock.FOOD], "Cultivated forage covers the camp and its workshop's food upkeep")
	check.call(stats.income[GameTypes.Stock.WATER] >= stats.upkeep[GameTypes.Stock.WATER], "Independent water production covers daily drinking")
	print("SUSTAINABLE OPENING region=%d seed=%d completed=%d/%d population=%d wood=%d food=%d water=%d" % [region, seed_value, step, PLAN.size(), state.population, state.resources[GameTypes.Stock.WOOD], state.resources[GameTypes.Stock.FOOD], state.resources[GameTypes.Stock.WATER]])


## 返回是否完成计划中的卡；勘探、补料和待命只是准备，不跨过制作前置。
static func _planned_action(state: VillageState, id: String) -> bool:
	if id == "foraging_camp" and not state.progress.discoveries.has(GameTypes.Discovery.FORAGE):
		_explore_for(state, GameTypes.Discovery.FORAGE)
		return false
	if id in ["woodcut", "sawmill"] and not state.progress.discoveries.has(GameTypes.Discovery.WOODLAND):
		_explore_for(state, GameTypes.Discovery.WOODLAND)
		return false
	var uid: int = _uid(state, id)
	if uid >= 0 and state.can_play(uid).is_empty():
		return state.play_card(uid)
	var costs: PackedInt32Array = EffectResolver.cost_totals(state.catalog.get_card(id), state)
	if state.resources[GameTypes.Stock.WOOD] < costs[GameTypes.Stock.WOOD]:
		var wood: int = _uid(state, "woodcut")
		if wood >= 0 and state.can_play(wood).is_empty():
			state.play_card(wood)
			return false
	state.skip_slot()
	return false


static func _needed_discovery(state: VillageState) -> GameTypes.Discovery:
	return (
		GameTypes.Discovery.WOODLAND if state.progress.discoveries.has(GameTypes.Discovery.FORAGE)
		else GameTypes.Discovery.FORAGE
	)


## 测试用固定地图样本选择合法的最短探索前沿；生产规则与 UI 不读取未知资源。
static func _explore_for(state: VillageState, discovery: GameTypes.Discovery) -> void:
	var target: Vector2i = Vector2i(-1, -1)
	var origin: Vector2i = TerrainGrid.CAMP
	var best: int = 999
	for value: int in TerrainGrid.SIZE.x * TerrainGrid.SIZE.y:
		var cell: Vector2i = TerrainGrid.position(value)
		if state.progress.explored_cells.has(value) or not state.terrain_grid.sources(cell).has(discovery):
			continue
		for visited: int in state.progress.explored_cells:
			var start: Vector2i = TerrainGrid.position(visited)
			var distance: int = absi(cell.x - start.x) + absi(cell.y - start.y)
			if distance < best:
				best = distance
				origin = start
				target = cell
	if target.x < 0:
		state.skip_slot()
		return
	var next: Vector2i = origin
	if next.x != target.x:
		next.x += 1 if next.x < target.x else -1
	else:
		next.y += 1 if next.y < target.y else -1
	if state.select_exploration(next) and state.can_play(_uid(state, "explore")).is_empty():
		state.play_card(_uid(state, "explore"))
	else:
		state.skip_slot()


static func _uid(state: VillageState, id: String) -> int:
	for entry: CardInstance in state.hand:
		if entry.definition.id == id:
			return entry.uid
	return -1
