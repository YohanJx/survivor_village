class_name VillageSaveData
extends Resource

const CURRENT_VERSION: int = 10
const THREAT_VERSION: int = 10
const EVENT_QUEUE_VERSION: int = 9
const DAY_END_VERSION: int = 8
const WORKFORCE_VERSION: int = 3
const LEGACY_VERSION: int = 2

@export_storage var progress: VillageProgress
@export_storage var version: int = CURRENT_VERSION
@export_storage var run_seed: int = 0
@export_storage var rng_state: int = 0
@export_storage var day: int = 1
@export_storage var weather_kind: WeatherDefinition.Kind = WeatherDefinition.Kind.CLEAR
@export_storage var slot: int = 0
@export_storage var actions_used: int = 0
@export_storage var actions_per_slot: int = 1
@export_storage var profession_counts: PackedInt32Array = []
@export_storage var phase: GameTypes.Phase = GameTypes.Phase.DAY
@export_storage var resources: PackedInt32Array = []
@export_storage var population: int = 5
@export_storage var core_health: float = 240.0
@export_storage var buildings: PackedInt32Array = []
@export_storage var modifiers: Array[StatModifier] = []
@export_storage var hand: Array[CardInstance] = []
# 旧版 rewards 仅用于校验迁移，新存档不再写入奖励卡。
@export_storage var rewards: Array[CardDefinition] = []
@export_storage var day_end_event_id: String = ""
@export_storage var pending_day_end_events: PackedStringArray = []
@export_storage var day_end_settled: bool = false
@export_storage var day_end_effects_expired: bool = false
@export_storage var history: Array[VillageLogEntry] = []
@export_storage var wall_damage: Dictionary[Vector2i, float] = {}
@export_storage var night_stats: VillageStats
@export_storage var last_report: BattleReport
@export_storage var next_uid: int = 1
@export_storage var total_kills: int = 0
