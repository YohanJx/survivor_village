class_name IrrigationSynergy
extends BuildingSynergy

@export var power_cost: int = 3
@export var water_sources: PackedInt32Array = [GameTypes.Building.WELL]
@export var food_multiplier: float = 1.5
@export var water_saved_per_farm: int = 3


func apply(
	state: VillageState,
	stats: VillageStats,
	_multipliers: PackedFloat64Array,
	power_budget: int,
) -> int:
	var has_source: bool = false
	for source: int in water_sources:
		has_source = has_source or state.buildings[source] > 0
	if state.buildings[GameTypes.Building.FARM] <= 0 or not has_source:
		return power_budget
	if stats.income[GameTypes.Stock.WATER] <= 0:
		stats.synergies.append("灌溉停用：水源未运行")
		return power_budget
	if power_budget < power_cost:
		stats.synergies.append("灌溉停用：余电不足 3，探照灯供电优先")
		return power_budget
	stats.irrigation_active = true
	stats.upkeep[GameTypes.Stock.POWER] += power_cost
	var farm_output: int = (
		state.catalog.buildings[GameTypes.Building.FARM].production.food
		* state.buildings[GameTypes.Building.FARM]
	)
	stats.income[GameTypes.Stock.FOOD] += floori(farm_output * (food_multiplier - 1.0))
	stats.upkeep[GameTypes.Stock.WATER] -= (
		state.buildings[GameTypes.Building.FARM] * water_saved_per_farm
	)
	stats.synergies.append("水源 × 菜圃 × 电力：灌溉生效")
	return power_budget - power_cost


func configuration_error() -> String:
	var valid: bool = (
		power_cost >= 0
		and is_finite(food_multiplier)
		and food_multiplier > 0
		and water_saved_per_farm >= 0
		and water_saved_per_farm <= 3
	)
	for source: int in water_sources:
		valid = valid and source >= 0 and source < GameTypes.Building.COUNT
	valid = valid and not water_sources.is_empty()
	return "" if valid else "联动参数非法"
