class_name VillageProgress
extends Resource
## 一局的发展状态；所有可变集合显式复制，定义资源仅保存稳定 ID。

@export_storage var explored_cells: PackedInt32Array = []
@export_storage var exploration_target: int = -1
@export_storage var completed_cards: PackedStringArray = []
@export_storage var discoveries: PackedInt32Array = []
@export_storage var terrain_surveys: int = 0
@export_storage var well_tools: bool = false
@export_storage var well_surveys: int = 0
@export_storage var granted_cards: PackedStringArray = []
@export_storage var region: GameTypes.Region = GameTypes.Region.LEGACY
@export_storage var frustration: int = 0
@export_storage var last_labor: GameTypes.Labor = GameTypes.Labor.NONE
@export_storage var streak: int = 0
@export_storage var crew: int = 0
@export_storage var strategies: PackedInt32Array = [0, 0, 0, 0, 0, 0, 0]
@export_storage var chant_uses: int = 0
@export_storage var event_id: String = ""
@export_storage var event_choice: int = -1
@export_storage var recent_events: PackedStringArray = []
@export_storage var recent_day_end_events: PackedStringArray = []
@export_storage var low_mood_used: bool = false
@export_storage var assigned_today: bool = false
@export_storage var scouting: bool = false
@export_storage var deposits: PackedInt32Array = [400, 400, 400]
@export_storage var survivors: Array[SurvivorRecord] = []
@export_storage var next_person_id: int = 1


func copy_progress() -> VillageProgress:
	var result: VillageProgress = duplicate(false) as VillageProgress
	result.explored_cells = explored_cells.duplicate()
	result.completed_cards = completed_cards.duplicate()
	result.discoveries = discoveries.duplicate()
	result.granted_cards = granted_cards.duplicate()
	result.strategies = strategies.duplicate()
	result.deposits = deposits.duplicate()
	result.recent_events = recent_events.duplicate()
	result.recent_day_end_events = recent_day_end_events.duplicate()
	result.survivors = []
	for person: SurvivorRecord in survivors:
		result.survivors.append(person.copy_record())
	return result
