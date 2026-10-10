class_name ClinicSynergy
extends BuildingSynergy

@export var food_cost: int = 2
@export var water_cost: int = 2
@export var health_bonus: float = 20.0


func apply(
	state: VillageState,
	stats: VillageStats,
	_multipliers: PackedFloat64Array,
	power_budget: int,
) -> int:
	if (
		state.resources[GameTypes.Stock.FOOD] < stats.upkeep[GameTypes.Stock.FOOD] + food_cost
		or state.resources[GameTypes.Stock.WATER] < stats.upkeep[GameTypes.Stock.WATER] + water_cost
	):
		stats.synergies.append("医疗站停用：当前补给不足")
		return power_budget
	stats.clinic_active = true
	stats.values[GameTypes.Stat.HEALTH] += health_bonus
	stats.upkeep[GameTypes.Stock.FOOD] += food_cost
	stats.upkeep[GameTypes.Stock.WATER] += water_cost
	stats.synergies.append("补给 × 医疗站：守卫生命 +20，黎明修复 +15")
	return power_budget


func configuration_error() -> String:
	var valid: bool = (
		food_cost >= 0 and water_cost >= 0 and is_finite(health_bonus) and health_bonus >= 0
	)
	return "" if valid else "联动参数非法"
