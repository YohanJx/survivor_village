class_name DayEndOptionView
extends PanelContainer
## 单个日终选项的收益、代价与准入提示；只向上发送选择索引。

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
	_kind.text = KeywordText.format_text("日终事件")
	_title.text = card.display_name
	_positive.text = KeywordText.format_text("＋ " + ProgressionEconomy.output_text(state, card))
	_negative.text = KeywordText.format_text("－ " + card.negative)
	var error: String = DayEndEvents.option_error(state, index)
	var cost_text: String = state.catalog.cost_text(card, state)
	_cost.text = ("库存消耗：无（仍有上方代价）" if cost_text == "无资源消耗" else "库存消耗：" + cost_text)
	_select.disabled = not error.is_empty()
	_select.text = "处理事件 →" if error.is_empty() else error


func _on_select_pressed() -> void:
	selected.emit(_index)
