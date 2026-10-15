class_name WellSiteRecord
extends Resource
## 一个已勘探井位的独立运行时记录；打井后结果不再改变。

enum Outcome {
	UNTESTED,
	DRY,
	WATER,
	COUNT,
}

@export_storage var cell: int = -1
@export_storage var outcome: Outcome = Outcome.UNTESTED


func copy_record() -> WellSiteRecord:
	var result: WellSiteRecord = WellSiteRecord.new()
	result.cell = cell
	result.outcome = outcome
	return result
