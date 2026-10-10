class_name IrrigationSynergy
extends BuildingSynergy

@export var power_cost: int = 3
@export var food_multiplier: float = 1.5
@export var water_saved_per_farm: int = 3


func apply(
	state: VillageState,
	stats: VillageStats,
	_multipliers: PackedFloat64Array,
	power_budget: int,
) -> int:
	if (
		state.buildings[GameTypes.Building.FARM] <= 0
		or state.buildings[GameTypes.Building.WELL] <= 0
	):
		return power_budget
	if power_budget < power_cost:
		stats.synergies.append("灌溉停用：余电不足 3，探照灯供电优先")
		return power_budget
	stats.irrigation_active = true
	stats.upkeep[GameTypes.Stock.POWER] += power_cost
	stats.income[GameTypes.Stock.FOOD] = int(stats.income[GameTypes.Stock.FOOD] * food_multiplier)
	stats.upkeep[GameTypes.Stock.WATER] -= (
		state.buildings[GameTypes.Building.FARM] * water_saved_per_farm
	)
	stats.synergies.append("水井 × 菜圃 × 电力：灌溉生效")
	return power_budget - power_cost


func configuration_error() -> String:
	var valid: bool = (
		power_cost >= 0
		and is_finite(food_multiplier)
		and food_multiplier > 0
		and water_saved_per_farm >= 0
		and water_saved_per_farm <= 3
	)
	return "" if valid else "联动参数非法"
