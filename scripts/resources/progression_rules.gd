class_name ProgressionRules
extends Resource
## 发展内容统一入口；使用独立、可复现事件随机序列。

@export var units: Array[UnitDefinition] = []
@export var enemies: Array[EnemyDefinition] = []
@export var maps: Array[MapDefinition] = []
@export var events: Array[DailyEvent] = []
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


func for_day(state: VillageState) -> DailyEvent:
	if state.day == 1:
		return events[0]
	var candidates: Array[DailyEvent] = []
	var weight: int = 0
	for event: DailyEvent in events:
		if event == events[0] or state.progress.recent_events.has(event.id):
			continue
		if not event.regions.is_empty() and not event.regions.has(state.progress.region):
			continue
		candidates.append(event)
		weight += event.weight
	if candidates.is_empty():
		return events[0]
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = state.run_seed ^ (state.day * 130363 + 81799)
	var roll: int = generator.randi_range(1, weight)
	for event: DailyEvent in candidates:
		roll -= event.weight
		if roll <= 0:
			return event
	return events[0]
