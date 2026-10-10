class_name EnemyDefinition
extends Resource

@export_range(1, 10) var threat_cost: int = 1
@export var kind: GameTypes.Enemy = GameTypes.Enemy.WALKER
@export var health_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var armor: float = 0.0
@export var attack_range: float = 25.0
@export var summon_limit: int = 0
@export var summon_interval: float = 10.0
@export var fire_radius: float = 0.0
