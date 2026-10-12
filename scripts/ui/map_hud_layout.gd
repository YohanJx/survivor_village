class_name MapHudLayout
extends Control
## 地图顶端信息浮层：只按线索显隐排列提示与工具栏，不占地图布局空间。

@onready var _clues: Label = $ExplorationClues
@onready var _controls: HBoxContainer = $BattleControls
@onready var _background: ColorRect = $MapHudBackground


func _ready() -> void:
	_clues.visibility_changed.connect(_on_clues_visibility_changed)
	_on_clues_visibility_changed()


func _on_clues_visibility_changed() -> void:
	_controls.offset_top = 75.0 if _clues.visible else 43.0
	_controls.offset_bottom = 112.0 if _clues.visible else 80.0
	_background.offset_bottom = 120.0 if _clues.visible else 88.0
