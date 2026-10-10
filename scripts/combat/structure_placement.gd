class_name StructurePlacement
extends RefCounted

var definition: BuildingDefinition
var rect: Rect2i
var key: GameTypes.Building:
	get:
		return definition.id
var display_name: String:
	get:
		return definition.display_name


func _init(building: BuildingDefinition = null, footprint: Rect2i = Rect2i()) -> void:
	definition = building
	rect = footprint
