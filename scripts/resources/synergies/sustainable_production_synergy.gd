class_name SustainableProductionSynergy
extends BuildingSynergy
## 以黄昏库存与已预留费用运行整批生产；不使用同夜产物，不改运行时状态。

@export var building: GameTypes.Building = GameTypes.Building.CORE


func apply(
	state: VillageState,
	stats: VillageStats,
	_multipliers: PackedFloat64Array,
	power_budget: int,
) -> int:
	var definition: BuildingDefinition = state.catalog.buildings[building]
	var flow: ProductionProfile = definition.production
	var level: int = state.buildings[building]
	var error: String = _operating_error(state, stats, flow, power_budget)
	if not error.is_empty():
		stats.synergies.append("%s停产：%s" % [definition.display_name, error])
		return power_budget
	for input: ResourceCost in flow.inputs:
		var amount: int = input.amount * level
		stats.upkeep[input.key] += amount
		if input.key == GameTypes.Stock.POWER:
			power_budget -= amount
	for output: ResourceCost in flow.outputs:
		var amount: int = output.amount * level
		if output.key == GameTypes.Stock.WATER:
			if state.weather.rainfall > 0.0:
				amount += flow.rain_water_bonus * level
			if flow.pollution_sensitive and state.buildings[GameTypes.Building.FILTER] == 0:
				amount = maxi(0, amount - floori(state.resources[GameTypes.Stock.POLLUTION] / 4.0))
		stats.income[output.key] += amount
	stats.income[GameTypes.Stock.NOISE] += flow.noise * level
	stats.income[GameTypes.Stock.POLLUTION] += flow.pollution * level
	stats.synergies.append("%s：自动生产中，无需每日出牌" % definition.display_name)
	return power_budget


func configuration_error() -> String:
	return "" if building >= 0 and building < GameTypes.Building.COUNT else "自动生产设施非法"


func _operating_error(
	state: VillageState, stats: VillageStats, flow: ProductionProfile, power_budget: int
) -> String:
	var level: int = state.buildings[building]
	if flow.operator != GameTypes.Profession.GENERAL and state.profession_counts[flow.operator] == 0:
		return "缺少" + GameTypes.PROFESSION_NAMES[flow.operator]
	for input: ResourceCost in flow.inputs:
		var available: int = (
			power_budget if input.key == GameTypes.Stock.POWER
			else state.resources[input.key] - stats.upkeep[input.key]
		)
		if available < input.amount * level:
			return GameTypes.STOCK_NAMES[input.key] + "不足，整批停产"
	return ""
