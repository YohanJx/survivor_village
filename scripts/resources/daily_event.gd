class_name DailyEvent
extends Resource
## 每日事件的只读配置；选择沿用 CardDefinition 的费用和效果。

enum Trigger { AMBIENT, HUNGER, THIRST }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var weight: int = 10
@export var regions: PackedInt32Array = []
@export var options: Array[CardDefinition] = []
@export var labor: GameTypes.Labor = GameTypes.Labor.NONE
@export var output_stocks: PackedInt32Array = []
@export var output_multiplier: float = 1.0
@export var cost_multiplier: float = 1.0
@export var low_mood: bool = false
@export var skippable: bool = false

@export_group("情境条件")
@export var trigger: Trigger = Trigger.AMBIENT
@export var min_day: int = 1
@export var max_day: int = 0
@export var min_explored: int = 0
@export var max_explored: int = 0
@export var min_population: int = 0
@export var min_frustration: int = 0
@export var required_discoveries: PackedInt32Array = []
@export var required_building: GameTypes.Building = GameTypes.Building.COUNT
@export var required_stock: GameTypes.Stock = GameTypes.Stock.COUNT
@export var min_stock: int = 1
@export var requires_damage: bool = false
@export var min_deprivation_days: int = 1
@export var max_deprivation_days: int = 0
