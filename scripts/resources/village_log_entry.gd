class_name VillageLogEntry
extends Resource

@export_storage var day: int = 1
@export_storage var text: String = ""


func _init(day_number: int = 1, message: String = "") -> void:
	day = day_number
	text = message
