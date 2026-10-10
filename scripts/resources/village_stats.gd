class_name VillageStats
extends Resource

@export_storage
var values: PackedFloat64Array = [9.0, 100.0, 1.15, 66.0, 65.0, 1.0, 0.0, 55.0, 0.0, 30.0]
@export_storage var income: PackedInt32Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
@export_storage var upkeep: PackedInt32Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
@export_storage var lights_active: bool = false
@export_storage var irrigation_active: bool = false
@export_storage var clinic_active: bool = false
@export_storage var synergies: PackedStringArray = []

@export_storage var roster: Array[SurvivorRecord] = []
@export_storage var modern_combat: bool = false
@export_storage var torch: bool = false
@export_storage var piercing: bool = false
@export_storage var supplies: PackedInt32Array = []

var attack: float:
	get:
		return values[GameTypes.Stat.ATTACK]
var attack_range: float:
	get:
		return values[GameTypes.Stat.RANGE]
var cooldown: float:
	get:
		return values[GameTypes.Stat.COOLDOWN]
var speed: float:
	get:
		return values[GameTypes.Stat.SPEED]
var health: float:
	get:
		return values[GameTypes.Stat.HEALTH]
var wave_size: float:
	get:
		return values[GameTypes.Stat.WAVE_SIZE]
var wall_health: float:
	get:
		return values[GameTypes.Stat.WALL_HEALTH]
var trap_damage: float:
	get:
		return values[GameTypes.Stat.TRAP_DAMAGE]
var stamina_recovery: int:
	get:
		return int(values[GameTypes.Stat.STAMINA_RECOVERY])


func copy_snapshot() -> VillageStats:
	var snapshot: VillageStats = VillageStats.new()
	snapshot.modern_combat = modern_combat
	snapshot.torch = torch
	snapshot.piercing = piercing
	for person: SurvivorRecord in roster:
		snapshot.roster.append(person.copy_record())
	snapshot.supplies = supplies.duplicate()
	snapshot.values = values.duplicate()
	snapshot.income = income.duplicate()
	snapshot.upkeep = upkeep.duplicate()
	snapshot.lights_active = lights_active
	snapshot.irrigation_active = irrigation_active
	snapshot.clinic_active = clinic_active
	snapshot.synergies = synergies.duplicate()
	return snapshot
