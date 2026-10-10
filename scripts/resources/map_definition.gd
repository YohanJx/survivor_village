class_name MapDefinition
extends Resource
## 地图地形、初始库存和资源丰度；与运行时资源点余量分离。

@export var kind: GameTypes.Region = GameTypes.Region.LEGACY
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var initial_resources: PackedInt32Array = []
@export var abundance: PackedFloat64Array = []
@export var barriers: Array[Rect2i] = []
@export var ground_tint: Color = Color.WHITE
