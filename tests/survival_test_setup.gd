class_name SurvivalTestSetup
extends RefCounted
## 既有规则测试的已开发场景；逐格探索行为由独立回归验证。


static func developed(state: VillageState) -> void:
	state.day = 2
	state.progress.explored_cells = PackedInt32Array([TerrainGrid.index(TerrainGrid.CAMP)])
	for step: int in TerrainGrid.SIZE.x * TerrainGrid.SIZE.y:
		for value: int in TerrainGrid.SIZE.x * TerrainGrid.SIZE.y:
			if TerrainGrid.is_frontier(TerrainGrid.position(value), state.progress.explored_cells):
				state.progress.explored_cells.append(value)
				break
	state.progress.terrain_surveys = state.progress.explored_cells.size() - 1
	state.progress.discoveries = TerrainGrid.discoveries_for(
		state.terrain_grid, state.progress.explored_cells
	)
	state.progress.well_tools = true
	state.progress.well_sites.clear()
	state.progress.well_target = -1
	state.progress.legacy_well = false
	state.progress.well_surveys = 0
	state.progress.well_drill_attempts = 0
	select_well_candidate(state)
	if state.progress.well_target >= 0:
		WellRules.survey(state)
	state.progress.completed_cards.clear()
	for card: CardDefinition in state.catalog.library.cards:
		state.progress.completed_cards.append(card.id)
	SurvivalRules.grant_available(state)


static func select_well_candidate(state: VillageState) -> Vector2i:
	for value: int in state.progress.explored_cells:
		var cell: Vector2i = TerrainGrid.position(value)
		if WellRules.candidate_error(state, cell).is_empty():
			state.select_well_site(cell)
			return cell
	return Vector2i(-1, -1)


static func force_drill_result(state: VillageState, has_water: bool) -> void:
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	for seed_value: int in range(1, 1000):
		generator.seed = seed_value
		if (generator.randf() < WellRules.chance(state)) == has_water:
			state.rng.seed = seed_value
			return


## 非井位专项通过此入口准备真实成井记录，避免仅改设施造成无效测试存档。
static func complete_well(state: VillageState) -> void:
	var site: WellSiteRecord = WellRules.pending_site(state.progress)
	if site != null:
		site.outcome = WellSiteRecord.Outcome.WATER
		state.progress.well_drill_attempts += 1
	state.buildings[GameTypes.Building.WELL] = 1


static func select_frontier(
	state: VillageState, preferred: GameTypes.Discovery = GameTypes.Discovery.FORAGE
) -> Vector2i:
	var fallback: Vector2i = Vector2i(-1, -1)
	for value: int in TerrainGrid.SIZE.x * TerrainGrid.SIZE.y:
		var cell: Vector2i = TerrainGrid.position(value)
		if TerrainGrid.is_frontier(cell, state.progress.explored_cells):
			fallback = cell
			if state.terrain_grid.sources(cell).has(preferred):
				break
	state.select_exploration(fallback)
	return fallback


## 原有非事件回归使用跳过或无费用选项，日终的具体效果由专门回归覆盖。
static func settle_day_end(state: VillageState) -> bool:
	if state.phase != GameTypes.Phase.DAY_END:
		return false
	for step: int in 8:
		if state.phase != GameTypes.Phase.DAY_END:
			return true
		var event: DailyEvent = state.current_day_end_event()
		if event == null:
			return false
		if event.skippable:
			state.skip_day_end_event()
			continue
		var settled: bool = false
		for index: int in range(event.options.size() - 1, -1, -1):
			if DayEndEvents.option_error(state, index).is_empty():
				settled = state.choose_day_end_event(index)
				break
		if not settled:
			return false
	return false
