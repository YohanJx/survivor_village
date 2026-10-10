class_name LightSynergy
extends BuildingSynergy

@export var power_cost: int = 4
@export var attack_multiplier: float = 1.25
@export var range_bonus: float = 25.0


func apply(
	state: VillageState,
	stats: VillageStats,
	multipliers: PackedFloat64Array,
	power_budget: int,
) -> int:
	if power_budget < power_cost or stats.values[GameTypes.Stat.BLACKOUT] > 0:
		stats.synergies.append("探照灯停用：缺电或执行熄灯隐蔽")
		return power_budget
	stats.lights_active = true
	stats.upkeep[GameTypes.Stock.POWER] += power_cost
	if state.progress.region != GameTypes.Region.LEGACY:
		stats.synergies.append("探照灯：扩大潜伏者发现范围，不增强弓箭伤害")
		return power_budget - power_cost
	multipliers[GameTypes.Stat.ATTACK] *= attack_multiplier
	stats.values[GameTypes.Stat.RANGE] += range_bonus
	stats.synergies.append("电力 × 探照灯：攻击 +25%，射程 +25")
	return power_budget - power_cost


func configuration_error() -> String:
	var valid: bool = (
		power_cost >= 0
		and is_finite(attack_multiplier)
		and attack_multiplier > 0
		and is_finite(range_bonus)
		and range_bonus >= 0
	)
	return "" if valid else "联动参数非法"
