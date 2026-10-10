class_name BattleReport
extends Resource

@export_storage var has_identities: bool = false
@export_storage var survivor_ids: PackedInt32Array = []
@export_storage var consumed: PackedInt32Array = []

@export_storage var core_health: float = 0
@export_storage var survivors: int = 0
@export_storage var kills: int = 0
@export_storage var started_survivors: int = 0
@export_storage var wall_damage: Dictionary[Vector2i, float] = {}
@export_storage var duration: float = 0
@export_storage var boss_defeated: bool = false


func copy_snapshot() -> BattleReport:
	var report: BattleReport = BattleReport.new()
	report.has_identities = has_identities
	report.survivor_ids = survivor_ids.duplicate()
	report.consumed = consumed.duplicate()
	report.core_health = core_health
	report.survivors = survivors
	report.kills = kills
	report.started_survivors = started_survivors
	report.wall_damage = wall_damage.duplicate()
	report.duration = duration
	report.boss_defeated = boss_defeated
	return report
