class_name ProgressionRules
extends Resource
## 发展内容统一入口；使用独立、可复现事件随机序列。

@export var units: Array[UnitDefinition] = []
@export var enemies: Array[EnemyDefinition] = []
@export var maps: Array[MapDefinition] = []
# 旧版黎明定义仅用于存档校验及已接受影响的恢复。
@export var events: Array[DailyEvent] = []
@export var day_end_events: Array[DailyEvent] = []
@export var night_threat: NightThreatRules
@export var combat_balance: CombatBalanceRules
@export var portable_storage: PackedInt32Array = [30, 30, 0]
@export_range(0.0, 1.0) var frustration_cost: float = 0.15
@export_range(1, 10) var max_frustration: int = 5
@export_range(1, 10) var max_crew: int = 4


func map_for(kind: GameTypes.Region) -> MapDefinition:
	for definition: MapDefinition in maps:
		if definition.kind == kind:
			return definition
	return null


func event_for(id: String) -> DailyEvent:
	for definition: DailyEvent in events:
		if definition.id == id:
			return definition
	return null


func day_end_event_for(id: String) -> DailyEvent:
	for definition: DailyEvent in day_end_events:
		if definition.id == id:
			return definition
	return null
