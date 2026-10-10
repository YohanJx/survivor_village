class_name BuildingSynergy
extends Resource

@export var priority: int = 0

# Subclasses own their rule; the resolver calls this polymorphically.


func apply(
	_state: VillageState,
	_stats: VillageStats,
	_multipliers: PackedFloat64Array,
	power_budget: int,
) -> int:
	return power_budget


func configuration_error() -> String:
	return "未实现的设施联动规则"
