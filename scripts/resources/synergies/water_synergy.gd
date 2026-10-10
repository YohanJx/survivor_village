class_name WaterSynergy
extends BuildingSynergy

@export var pollution_per_loss: int = 4


func apply(
	state: VillageState,
	stats: VillageStats,
	_multipliers: PackedFloat64Array,
	power_budget: int,
) -> int:
	if state.buildings[GameTypes.Building.FILTER] > 0:
		stats.synergies.append("净水器 × 集水井：免受污染减产")
		return power_budget
	var lost: int = mini(
		stats.income[GameTypes.Stock.WATER],
		int(state.resources[GameTypes.Stock.POLLUTION] / float(maxi(1, pollution_per_loss))),
	)
	stats.income[GameTypes.Stock.WATER] -= lost
	if lost > 0:
		stats.synergies.append("污染 × 水井：每日水产量 -%d" % lost)
	return power_budget


func configuration_error() -> String:
	var valid: bool = pollution_per_loss > 0
	return "" if valid else "联动参数非法"
