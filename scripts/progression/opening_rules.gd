class_name OpeningRules
extends RefCounted
## 新局筛选可发展的营地；保存实际种子，恢复不筛选、不改变旧地图。

const MAX_SEED_ATTEMPTS: int = 512
const SEED_STRIDE: int = 7919
const SUPPLY_RADIUS: int = 2


static func viable_seed(requested_seed: int, map: MapDefinition) -> int:
	var grid: TerrainGrid = TerrainGrid.new()
	for attempt: int in MAX_SEED_ATTEMPTS:
		var candidate: int = requested_seed + attempt * SEED_STRIDE
		grid.generate(candidate, map)
		if has_opening_sources(grid):
			return candidate
	return -1


static func has_opening_sources(grid: TerrainGrid) -> bool:
	var groundwater: bool = false
	var food: bool = false
	var wood: bool = false
	for value: int in TerrainGrid.SIZE.x * TerrainGrid.SIZE.y:
		var cell: Vector2i = TerrainGrid.position(value)
		if cell == TerrainGrid.CAMP or TerrainGrid.distance(cell) > SUPPLY_RADIUS:
			continue
		var sources: PackedInt32Array = grid.sources(cell)
		groundwater = groundwater or grid.biome(cell) == TerrainGrid.Biome.PLAIN
		food = food or sources.has(GameTypes.Discovery.FORAGE)
		wood = wood or sources.has(GameTypes.Discovery.WOODLAND)
	return groundwater and food and wood


static func next_step(state: VillageState) -> String:
	if state.day == 1 or state.progress.terrain_surveys == 0:
		return "目标：循线索寻找草甸与林地，先勘探营地周边"
	var upkeep: PackedInt32Array = EffectResolver.daily_upkeep(state)
	if state.resources[GameTypes.Stock.FOOD] < upkeep[GameTypes.Stock.FOOD]:
		return _action_step(state, "forage", "先补足今日食物")
	if state.buildings[GameTypes.Building.WELL] == 0:
		if state.progress.discoveries.has(GameTypes.Discovery.RIVER):
			if state.resources[GameTypes.Stock.WATER] < upkeep[GameTypes.Stock.WATER]:
				return _action_step(state, "water", "先补足今日饮水")
		else:
			if not state.progress.well_tools:
				return _action_step(state, "well_tools", "建立水源：制作挖井工具")
			if SurvivalRules.well_chance(state) < 1.0:
				return _action_step(state, "well_survey", "建立水源：继续勘探井位，稳妥打井")
			return _action_step(state, "well", "建立水源：井位已确认，可以打井")
	if (
		state.buildings[GameTypes.Building.WELL] > 0
		and state.resources[GameTypes.Stock.WATER] < upkeep[GameTypes.Stock.WATER]
	):
		return _action_step(state, "well_water", "先补足今日饮水")
	if state.buildings[GameTypes.Building.WATER_TANK] == 0:
		return _action_step(state, "water_tank", "扩充储水，减少每日取水压力")
	if state.buildings[GameTypes.Building.FOOD_STORE] == 0:
		return _action_step(state, "food_store", "建粮仓，保存更多食物")
	return "目标：发展食物生产、工坊与防线，准备第七夜尸潮"


static func _action_step(state: VillageState, id: String, goal: String) -> String:
	var card: CardDefinition = state.catalog.get_card(id)
	if card == null:
		return "目标：继续勘探营地周边"
	var error: String = SurvivalRules.unlock_error(state, card)
	return "目标：%s" % goal if error.is_empty() else "目标：%s（%s）" % [goal, error]
