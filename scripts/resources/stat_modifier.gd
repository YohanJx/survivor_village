class_name StatModifier
extends Resource

enum Operation {
	ADD = 0,
	MULTIPLY = 1,
}

@export var key: GameTypes.Stat = GameTypes.Stat.ATTACK
@export var operation: Operation = Operation.ADD
@export var amount: float = 0.0
@export_range(0, 99) var duration: int = 0
# Runtime copies own these fields. Authored resources are never mutated.
@export_storage var remaining: int = 0
@export_storage var source: String = ""


func copy_runtime() -> StatModifier:
	var instance: StatModifier = StatModifier.new()
	instance.key = key
	instance.operation = operation
	instance.amount = amount
	instance.duration = duration
	instance.remaining = remaining
	instance.source = source
	return instance
