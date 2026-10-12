class_name VillageCardFace
extends PanelContainer
## 村庄行动方案卡：全部资源费用、收益与风险，和游戏共用低饱和主题。

const SURVEY_ART: Texture2D = preload("res://assets/cards/survey.png")
const GATHER_ART: Texture2D = preload("res://assets/cards/gather.png")
const BUILD_ART: Texture2D = preload("res://assets/cards/build.png")

@export var compact: bool = false

var _number_pattern: RegEx = RegEx.new()
var _frame_style: StyleBoxFlat


func _ready() -> void:
	_frame_style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	add_theme_stylebox_override("panel", _frame_style)
	_number_pattern.compile("[+-]?[0-9]+(?:\\.[0-9]+)?%?")
	(%KeywordSlot as Control).visible = compact
	(%FaceArt as TextureRect).visible = true
	(%FaceKind as Label).visible = not compact
	(%FaceSummary as Label).visible = compact
	var summary: Label = %FaceSummary
	summary.custom_minimum_size.y = (
		ceili(
			(
				(
					summary.get_theme_font("font").get_height(
						summary.get_theme_font_size("font_size")
					)
					* 2.0
				)
				+ summary.get_theme_constant("line_spacing")
			)
		)
		if compact
		else 0
	)
	var risk_summary: Label = %FaceRiskSummary
	risk_summary.custom_minimum_size.y = (
		ceili(
			risk_summary.get_theme_font("font").get_height(
				risk_summary.get_theme_font_size("font_size")
			)
		)
		+ 4
	)
	(%FaceRules as RichTextLabel).visible = not compact
	(%FaceArt as TextureRect).custom_minimum_size.y = 110 if compact else 184
	(%FaceTitle as Label).add_theme_font_size_override("font_size", 17 if compact else 24)
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
	(%FaceSummary as Label).text = effect.replace("，", "\n").replace("；", "\n")
	(%FaceSummary as Label).tooltip_text = effect
	(%FaceRules as RichTextLabel).text = _emphasize_numbers(effect.replace("，", "\n"))
	(%FaceRisk as RichTextLabel).text = KeywordText.format_text(card.negative)
	(%FaceRisk as RichTextLabel).visible = not compact and not card.negative.is_empty()
	(%FaceRiskSummary as Label).text = card.negative
	(%FaceRiskSummary as Label).visible = compact and not card.negative.is_empty()


static func art_for(card: CardDefinition) -> Texture2D:
	if card.illustration != null:
		return card.illustration
	if SurvivalRules.is_survey(card):
		return SURVEY_ART
	return BUILD_ART if card.kind == CardDefinition.Kind.BUILDING else GATHER_ART


func set_selected(selected: bool) -> void:
	_frame_style.bg_color = Color("292b25") if selected else Color("1c211f")
	_frame_style.border_color = UiElements.ACCENT if selected else Color("51574d")
	_frame_style.set_border_width_all(2 if selected else 1)


func _emphasize_numbers(text: String) -> String:
	var escaped: String = text.replace("[", "[lb]")
	var result: String = ""
	var cursor: int = 0
	for found: RegExMatch in _number_pattern.search_all(escaped):
		result += escaped.substr(cursor, found.get_start() - cursor)
		result += "[b][color=#c0bb98]%s[/color][/b]" % found.get_string()
		cursor = found.get_end()
	return result + escaped.substr(cursor)
