class_name VillageRewardCard
extends PanelContainer
## 单个奖励选项，只把选择索引传给上层。

signal selected(index: int)

var _index: int = 0

@onready var _kind: RichTextLabel = %Kind
@onready var _title: Label = %Title
@onready var _positive: RichTextLabel = %Positive
@onready var _negative: RichTextLabel = %Negative
@onready var _cost: Label = %Cost
@onready var _select: Button = %SelectButton


func _ready() -> void:
	_select.pressed.connect(_on_select_pressed)


func update_view(card: CardDefinition, state: VillageState, index: int) -> void:
	_index = index
	_kind.add_theme_color_override("default_color", UiElements.CARD_COLORS[card.color])
	_kind.text = KeywordText.format_text(card.kind_name() + " / " + " · ".join(card.tags))
	_title.text = card.display_name
	_positive.text = KeywordText.format_text("＋ " + ProgressionEconomy.output_text(state, card))
	_negative.text = KeywordText.format_text("－ " + card.negative)
	_cost.text = "按当前职业使用消耗：" + state.catalog.cost_text(card, state)


func _on_select_pressed() -> void:
	selected.emit(_index)
