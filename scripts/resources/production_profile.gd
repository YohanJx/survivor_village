class_name ProductionProfile
extends Resource

@export_group("每日产出")
@export_range(0, 99) var food: int = 0
@export_range(0, 99) var water: int = 0
@export_range(0, 99) var power: int = 0
@export_range(0, 99) var materials: int = 0
@export_group("每日消耗")
@export_range(0, 99) var food_upkeep: int = 0
@export_range(0, 99) var water_upkeep: int = 0
@export_range(0, 99) var materials_upkeep: int = 0
@export_group("副作用")
@export_range(0, 99) var noise: int = 0
@export_range(0, 99) var pollution: int = 0
