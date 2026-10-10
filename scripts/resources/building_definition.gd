class_name BuildingDefinition
extends Resource

@export var id: GameTypes.Building = GameTypes.Building.CORE
@export var display_name: String = ""
@export_range(1, 10) var max_level: int = 1
@export var footprint: Rect2i = Rect2i()
@export var visible_on_map: bool = true
@export var modifiers: Array[StatModifier] = []
@export var production: ProductionProfile
@export var synergy: BuildingSynergy
