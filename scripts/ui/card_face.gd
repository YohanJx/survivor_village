class_name VillageCardFace
extends PanelContainer
## 村庄行动方案卡：全部资源费用、收益与风险，和游戏共用低饱和主题。

const SURVEY_ART: Texture2D = preload("res://assets/cards/survey.png")
const GATHER_ART: Texture2D = preload("res://assets/cards/gather.png")
const BUILD_ART: Texture2D = preload("res://assets/cards/build.png")

@export var compact: bool = false

var _number_pattern: RegEx = RegEx.new()
var _frame_style: StyleBoxTexture


func _ready() -> void:
	_frame_style = get_theme_stylebox("panel").duplicate() as StyleBoxTexture
	add_theme_stylebox_override("panel", _frame_style)
	_number_pattern.compile("[+-]?[0-9]+(?:\\.[0-9]+)?%?")
	(%FaceArt as TextureRect).visible = true
	(%FaceKind as Label).visible = true
	(%FaceSummary as Label).visible = compact
	(%FaceSummary as Label).custom_minimum_size.y = 36 if compact else 0
	(%FaceRiskSummary as Label).custom_minimum_size.y = 18
	(%FaceRules as RichTextLabel).visible = not compact
	(%FaceArt as TextureRect).custom_minimum_size.y = 92 if compact else 184
	(%FaceTitle as Label).add_theme_font_size_override("font_size", 18 if compact else 24)
	(%FaceRisk as RichTextLabel).visible = not compact
	(%FaceRiskSummary as Label).visible = compact


func update_view(state: VillageState, card: CardDefinition) -> void:
	(%FaceTitle as Label).text = card.display_name
	(%FaceKind as Label).text = card.kind_name() + (" · 常驻" if card.reusable else " · 单次")
	(%FaceArt as TextureRect).texture = art_for(card)
	(%FaceCosts as CardCostStrip).update_view(card, state)
	var effect: String = ProgressionEconomy.output_text(state, card)
	if SurvivalRules.is_survey(card):
		effect = "探索相邻区域，发现地形、资源与线索。"
	(%FaceSummary as Label).text = effect
	(%FaceRules as RichTextLabel).text = _emphasize_numbers(effect.replace("，", "\n"))
	(%FaceRisk as RichTextLabel).text = KeywordText.format_text(card.negative)
	(%FaceRisk as RichTextLabel).visible = not compact and not card.negative.is_empty()
	(%FaceRiskSummary as Label).text = card.negative
	(%FaceRiskSummary as Label).visible = compact and not card.negative.is_empty()


static func art_for(card: CardDefinition) -> Texture2D:
	if SurvivalRules.is_survey(card):
		return SURVEY_ART
	return BUILD_ART if card.kind == CardDefinition.Kind.BUILDING else GATHER_ART


func set_selected(selected: bool) -> void:
	_frame_style.modulate_color = Color(1.0, 0.94, 0.84) if selected else Color(0.8, 0.8, 0.8)


func _emphasize_numbers(text: String) -> String:
	var escaped: String = text.replace("[", "[lb]")
	var result: String = ""
	var cursor: int = 0
	for found: RegExMatch in _number_pattern.search_all(escaped):
		result += escaped.substr(cursor, found.get_start() - cursor)
		result += "[b][color=#c0bb98]%s[/color][/b]" % found.get_string()
		cursor = found.get_end()
	return result + escaped.substr(cursor)
