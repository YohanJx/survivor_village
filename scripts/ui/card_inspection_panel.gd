class_name CardInspectionPanel
extends VBoxContainer
## 居中的只读卡牌详解；使用现有费用、收益与前置查询，不执行行动。

signal close_requested

@onready var _face: VillageCardFace = %InspectionFace
@onready var _description: RichTextLabel = %InspectDescription
@onready var _risk: RichTextLabel = %InspectRisk
@onready var _requirement: RichTextLabel = %InspectRequirement
@onready var _status: Label = %InspectStatus
@onready var _labor: Label = %InspectLabor
@onready var _scroll: ScrollContainer = %InspectScroll


func _ready() -> void:
	(%InspectClose as Button).pressed.connect(close_requested.emit)
	(%InspectMore as Button).toggled.connect(_on_more_toggled)


func reset_scroll() -> void:
	_scroll.scroll_vertical = 0
	(%InspectMore as Button).button_pressed = false


func update_view(state: VillageState, uid: int) -> void:
	var card: CardDefinition = state.find_card(uid)
	if card == null:
		return
	_face.update_view(state, card)
	var notes: PackedStringArray = []
	for keyword: KeywordDefinition in card.keywords:
		notes.append(keyword.title + "：" + keyword.description)
	(%InspectKeywordNotes as RichTextLabel).text = KeywordText.format_text("\n\n".join(notes))
	_description.text = KeywordText.format_text(card.description)
	_risk.text = KeywordText.format_text(card.negative)
	if card.effects.any(
		func(effect: CardEffect) -> bool: return effect.type == CardEffect.Type.DRILL
	):
		_risk.text += (
			"\n有水概率 %d%%；此位置仅可打井一次，无水须勘探另一个位置。"
			% roundi(SurvivalRules.well_chance(state) * 100)
		)
	_requirement.text = KeywordText.format_text(state.catalog.requirement_text(card))
	_labor.text = LaborRules.summary(state, card)
	var reason: String = state.can_play(uid)
	_status.text = reason if not reason.is_empty() else "可以执行"
	_status.add_theme_color_override(
		"font_color", UiElements.NEGATIVE if not reason.is_empty() else UiElements.TEXT_SECONDARY
	)


func _on_more_toggled(expanded: bool) -> void:
	_scroll.visible = expanded
