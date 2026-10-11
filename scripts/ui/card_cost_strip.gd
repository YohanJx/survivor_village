class_name CardCostStrip
extends GridContainer
## 展示统一费用的全部资源项；不足标红，不执行扣费或自行计算费用。

const CHIP_SCENE: PackedScene = preload("res://scenes/ui/resource_cost_chip.tscn")

var _labels: Array[Label] = []
var _chips: Array[PanelContainer] = []
var _totals: PackedInt32Array = []


func _ready() -> void:
	for key: int in GameTypes.Stock.COUNT:
		var chip: PanelContainer = CHIP_SCENE.instantiate() as PanelContainer
		add_child(chip)
		_chips.append(chip)
		_labels.append(chip.get_node("Amount") as Label)


func update_view(card: CardDefinition, state: VillageState) -> void:
	_totals = EffectResolver.cost_totals(card, state)
	var count: int = 0
	for key: int in GameTypes.Stock.COUNT:
		_chips[key].visible = _totals[key] > 0
		if _totals[key] <= 0:
			continue
		count += 1
		_labels[key].text = "%s %d" % [GameTypes.STOCK_NAMES[key], _totals[key]]
		var shortage: bool = state != null and state.resources[key] < _totals[key]
		_labels[key].add_theme_color_override(
			"font_color", UiElements.NEGATIVE if shortage else UiElements.TEXT_PRIMARY
		)
		_chips[key].tooltip_text = (
			"需要 %d / 现有 %d" % [_totals[key], state.resources[key]] if state != null else ""
		)
	(%NoCost as Label).visible = count == 0


func displayed_totals() -> PackedInt32Array:
	return _totals.duplicate()
