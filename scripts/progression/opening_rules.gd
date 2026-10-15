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
	var balances: Array[ResourceBalance] = EffectResolver.resource_balances(state)
	if balances[GameTypes.Stock.FOOD].current + balances[GameTypes.Stock.FOOD].net < 0:
		return _action_step(state, "forage", "先补足今日食物；采集营地、渔场与菜圃可持续供粮")
	if balances[GameTypes.Stock.WATER].net < 0:
		if state.buildings[GameTypes.Building.WELL] > 0:
			return _action_step(state, "well_windpump", "井上风力提水，增加自动供水")
		if state.progress.discoveries.has(GameTypes.Discovery.RIVER):
			return _action_step(state, "river_windmill", "河岸风车引水；也可选择集雨或地下水路线")
		if state.buildings[GameTypes.Building.RAIN_COLLECTOR] == 0:
			return _action_step(state, "rain_collector", "先建集雨棚；也可选择河岸引水或勘探地下水")
		if state.buildings[GameTypes.Building.SOLAR_STILL] == 0:
			return _action_step(state, "solar_still", "集雨棚配集水器形成无井供水；也可寻找新水源")
		if WellRules.pending_site(state.progress) != null:
			return _action_step(state, "well", "当前井位可打井补足供水；无水需换位置")
		return _action_step(state, "well_tools", "继续寻找河流或地下水，补足每日供水")
	if state.buildings[GameTypes.Building.WATER_TANK] == 0:
		return _action_step(state, "water_tank", "扩充储水，减少每日取水压力")
	if state.buildings[GameTypes.Building.FOOD_STORE] == 0:
		return _action_step(state, "food_store", "建粮仓，保存更多食物")
	return "目标：发展食物生产、工坊与防线，维持补给并加强防线"


static func _action_step(state: VillageState, id: String, goal: String) -> String:
	var card: CardDefinition = state.catalog.get_card(id)
	if card == null:
		return "目标：继续勘探营地周边"
	var error: String = SurvivalRules.unlock_error(state, card)
	return "目标：%s" % goal if error.is_empty() else "目标：%s（%s）" % [goal, error]
