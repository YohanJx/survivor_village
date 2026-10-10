class_name WallSegment
extends RefCounted

var cell: Vector2i
var hp: float
var max_hp: float


func _init(wall_cell: Vector2i = Vector2i.ZERO, health: float = 0, maximum: float = 0) -> void:
	cell = wall_cell
	hp = health
	max_hp = maximum
