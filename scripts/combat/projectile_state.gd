class_name ProjectileState
extends RefCounted

var pos: Vector2
var target: CombatActor
var damage: float
var life: float = 2
var bow: bool = false


func _init(
	point: Vector2 = Vector2.ZERO, enemy: CombatActor = null, power: float = 0, is_bow: bool = false
) -> void:
	pos = point
	target = enemy
	damage = power
	bow = is_bow
