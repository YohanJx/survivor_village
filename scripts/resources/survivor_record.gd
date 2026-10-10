class_name SurvivorRecord
extends Resource
## 按局持有的稳定人口身份；职业不生成额外人口。

@export_storage var id: int = 0
@export_storage var profession: GameTypes.Profession = GameTypes.Profession.GENERAL
@export_storage var archer: bool = true


func copy_record() -> SurvivorRecord:
	var record: SurvivorRecord = SurvivorRecord.new()
	record.id = id
	record.profession = profession
	record.archer = archer
	return record
