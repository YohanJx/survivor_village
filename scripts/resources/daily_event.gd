class_name DailyEvent
extends Resource
## 每日事件的只读配置；选择沿用 CardDefinition 的费用和效果。

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
