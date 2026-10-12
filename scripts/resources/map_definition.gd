class_name MapDefinition
extends Resource
## 地图地形、初始库存和资源丰度；与运行时资源点余量分离。

@export var kind: GameTypes.Region = GameTypes.Region.LEGACY
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var initial_resources: PackedInt32Array = []
@export var abundance: PackedFloat64Array = []
@export var barriers: Array[Rect2i] = []
@export var discoveries: PackedInt32Array = []
@export_range(0.0, 1.0) var well_base_chance: float = 0.25
@export_range(0.01, 1.0) var well_survey_gain: float = 0.15
@export_range(0.01, 1.0) var noise_frequency: float = 0.19
@export_range(0.01, 0.3) var river_width: float = 0.085
@export var ground_tint: Color = Color.WHITE
@export_range(0, 20) var pollution_recovery: int = 2
