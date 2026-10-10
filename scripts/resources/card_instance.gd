class_name CardInstance
extends Resource

@export_storage var uid: int = 0
@export_storage var definition: CardDefinition


func _init(card: CardDefinition = null, instance_uid: int = 0) -> void:
	definition = card
	uid = instance_uid
