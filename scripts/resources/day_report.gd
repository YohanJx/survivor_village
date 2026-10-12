class_name DayReport
extends Resource
## 已完成一日的独立结算记录；展示与存档均使用复制后的数值。

@export_storage var day: int = 0
@export_storage var resources_before: PackedInt32Array = []
@export_storage var resources_after: PackedInt32Array = []
@export_storage var population_before: int = 0
@export_storage var population_after: int = 0
@export_storage var core_before: float = 0.0
@export_storage var core_after: float = 0.0
@export_storage var explored_before: int = 0
@export_storage var explored_after: int = 0
@export_storage var kills: int = 0
@export_storage var notes: PackedStringArray = []


func copy_snapshot() -> DayReport:
	var result: DayReport = DayReport.new()
	result.day = day
	result.resources_before = resources_before.duplicate()
	result.resources_after = resources_after.duplicate()
	result.population_before = population_before
	result.population_after = population_after
	result.core_before = core_before
	result.core_after = core_after
	result.explored_before = explored_before
	result.explored_after = explored_after
	result.kills = kills
	result.notes = notes.duplicate()
	return result
