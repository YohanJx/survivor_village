class_name CardEffect
extends Resource

enum Type {
	RESOURCE = 0,
	BUILD = 1,
	MODIFIER = 2,
	HEAL = 3,
	REPAIR_WALLS = 4,
	POPULATION = 5,
}

@export var type: Type = Type.RESOURCE
@export var key: GameTypes.Stock = GameTypes.Stock.FOOD
@export var amount: float = 0.0
@export var building: BuildingDefinition
@export var modifier: StatModifier
@export_group("条件加成（可选）")
@export var required_building: BuildingDefinition
