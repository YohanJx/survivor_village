class_name CombatActor
extends RefCounted

var id: int = 0
var pos: Vector2 = Vector2.ZERO
var hp: float = 65
var max_hp: float = 65
var speed: float = 24
var damage: float = 4
var kind: GameTypes.Enemy = GameTypes.Enemy.WALKER
var cooldown: float = 0
var path: PackedVector2Array = []
var repath: float = 0
var facing: Vector2 = Vector2.RIGHT
var flash: float = 0
var person_id: int = 0
var unit: GameTypes.Unit = GameTypes.Unit.VILLAGER
var attack_range: float = 100.0
var attack_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var support_timer: float = 0.0
var summons: int = 0
