class_name ProductionProfile
extends Resource
## 旧设施固定收支与可持续设施的类型化产出、原料和运行条件。

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

@export_group("自动生产")
@export var outputs: Array[ResourceCost] = []
@export var inputs: Array[ResourceCost] = []
@export var operator: GameTypes.Profession = GameTypes.Profession.GENERAL
@export_range(0, 99) var rain_water_bonus: int = 0
@export var pollution_sensitive: bool = false


func validation_error() -> String:
	for value: int in [food, water, power, materials, food_upkeep, water_upkeep,
		materials_upkeep, noise, pollution, rain_water_bonus]:
		if value < 0 or value > 99:
			return "生产数值非法"
	if operator < 0 or operator >= GameTypes.Profession.COUNT:
		return "生产岗位非法"
	for flows: Array[ResourceCost] in [outputs, inputs]:
		var seen: PackedInt32Array = []
		for flow: ResourceCost in flows:
			if flow == null or flow.key <= GameTypes.Stock.STAMINA or flow.key >= GameTypes.Stock.COUNT:
				return "生产资源非法"
			if flow.key in [GameTypes.Stock.MATERIALS, GameTypes.Stock.NOISE, GameTypes.Stock.POLLUTION]:
				return "自动生产使用实际材料，噪声污染使用独立字段"
			if flow.amount <= 0 or flow.amount > 99 or seen.has(flow.key):
				return "生产数量非法或同类资源重复"
			seen.append(flow.key)
	var has_water: bool = outputs.any(
		func(output: ResourceCost) -> bool: return output.key == GameTypes.Stock.WATER
	)
	if (rain_water_bonus > 0 or pollution_sensitive) and not has_water:
		return "集雨或水污染参数必须关联水产出"
	return ""
