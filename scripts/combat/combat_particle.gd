class_name CombatParticle
extends RefCounted

var pos: Vector2
var life: float
var color: Color
var text: String


func _init(
	point: Vector2 = Vector2.ZERO,
	duration: float = 1,
	tint: Color = Color.WHITE,
	caption: String = ""
) -> void:
	pos = point
	life = duration
	color = tint
	text = caption
