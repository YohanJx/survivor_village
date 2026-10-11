class_name CardInspectionPanel
extends VBoxContainer
## 居中的只读卡牌详解；使用现有费用、收益与前置查询，不执行行动。

signal close_requested

@onready var _title: Label = %InspectTitle
@onready var _kind: RichTextLabel = %InspectKind
@onready var _description: RichTextLabel = %InspectDescription
@onready var _benefit: RichTextLabel = %InspectBenefit
@onready var _risk: RichTextLabel = %InspectRisk
@onready var _requirement: RichTextLabel = %InspectRequirement
@onready var _cost: Label = %InspectCost
@onready var _status: Label = %InspectStatus
@onready var _labor: Label = %InspectLabor
@onready var _scroll: ScrollContainer = %InspectScroll


func _ready() -> void:
	(%InspectClose as Button).pressed.connect(close_requested.emit)


func reset_scroll() -> void:
	_scroll.scroll_vertical = 0


func update_view(state: VillageState, uid: int) -> void:
	var card: CardDefinition = state.find_card(uid)
	if card == null:
		return
	_title.text = card.display_name
	_kind.text = KeywordText.format_text(
		(
			card.kind_name()
			+ (" / 常驻" if card.reusable else " / 单次")
			+ " · "
			+ " · ".join(card.keyword_names())
		)
	)
	_kind.add_theme_color_override("default_color", UiElements.CARD_COLORS[card.color])
	(%InspectAccent as ColorRect).color = UiElements.CARD_COLORS[card.color]
	_description.text = KeywordText.format_text(card.description)
	_benefit.text = KeywordText.format_text(ProgressionEconomy.output_text(state, card))
	_risk.text = KeywordText.format_text(card.negative)
	if card.effects.any(
		func(effect: CardEffect) -> bool: return effect.type == CardEffect.Type.DRILL
	):
		_risk.text += "\n打井成功率 %d%%；失败仍扣费并消耗行动。" % roundi(SurvivalRules.well_chance(state) * 100)
	_requirement.text = KeywordText.format_text(state.catalog.requirement_text(card))
	_labor.text = LaborRules.summary(state, card)
	_cost.text = "当前消耗 / " + state.catalog.cost_text(card, state)
	var reason: String = state.can_play(uid)
	_status.text = reason if not reason.is_empty() else "可执行 · 关闭详情后，左键选牌并确认行动。"
	_status.add_theme_color_override(
		"font_color", UiElements.NEGATIVE if not reason.is_empty() else UiElements.TEXT_SECONDARY
	)
