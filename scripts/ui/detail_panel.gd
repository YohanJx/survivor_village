class_name VillageDetailPanel
extends PanelContainer
## 卡牌详情与固定确认区；规则预览从状态模型查询。

signal execute_requested

var _state: VillageState
var _selected_uid: int = -1

@onready var _empty_hint: Label = %EmptyHint
@onready var _card_detail: VBoxContainer = %CardDetail
@onready var _kind: RichTextLabel = %CardKind
@onready var _title: Label = %CardTitle
@onready var _description: RichTextLabel = %Description
@onready var _positive: RichTextLabel = %Positive
@onready var _survey_report: Label = %SurveyReport
@onready var _negative: RichTextLabel = %Negative
@onready var _cost: Label = %Cost
@onready var _requirement: RichTextLabel = %Requirement
@onready var _preview: Label = %Preview
@onready var _reason: Label = %Reason
@onready var _execute: Button = %ExecuteButton


func _ready() -> void:
	resized.connect(_on_detail_resized)
	_execute.pressed.connect(execute_requested.emit)
	(%AdvancedToggle as Button).toggled.connect(_on_advanced_toggled)


func update_view(state: VillageState, selected_uid: int, selection_changed: bool = false) -> void:
	var changed_card: bool = selection_changed or _selected_uid != selected_uid
	_state = state
	_selected_uid = selected_uid
	if changed_card:
		(%AdvancedToggle as Button).button_pressed = false
		(%DetailScroll as ScrollContainer).scroll_vertical = 0
	_refresh_detail()


func _on_detail_resized() -> void:
	# 工作台缩小时先让出插画空间，保持名称、收益、风险和费用可读。
	(%ActionArt as Control).visible = size.y >= 380.0
	_kind.visible = size.y >= 380.0


func _refresh_detail() -> void:
	if _state == null:
		return
	var card: CardDefinition = _state.find_card(_selected_uid)
	_empty_hint.visible = card == null
	visible = card != null
	_card_detail.visible = card != null
	_positive.visible = card != null
	(%CardHeader as Control).visible = card != null
	_execute.visible = card != null
	_cost.visible = false
	(%SelectedCosts as Control).visible = card != null
	_negative.visible = card != null and not SurvivalRules.is_survey(card)
	_survey_report.visible = SurvivalRules.is_survey(card)
	_reason.visible = false
	if card == null:
		_refresh_empty_hint()
	else:
		_refresh_card(card)


func _refresh_empty_hint() -> void:
	var lines: PackedStringArray = [
		"让每一天都有方向",
		"",
		"从下方选择卡牌，查看收益、代价和联动。",
		"",
	]
	for i: int in 3:
		var marker: String = "✓" if i < _state.slot else "●" if i == _state.slot else "○"
		lines.append("%s  %s" % [marker, VillageState.SLOT_NAMES[i]])
	lines.append("\n夜里无需操作小人。守卫会自动寻路和攻击，敌人会绕开障碍或破墙。")
	_empty_hint.text = "\n".join(lines)


func _refresh_card(card: CardDefinition) -> void:
	_kind.add_theme_color_override("default_color", UiElements.CARD_COLORS[card.color])
	_kind.text = KeywordText.format_text(card.kind_name() + (" / 常驻" if card.reusable else " / 单次"))
	(%CardKeywords as RichTextLabel).text = KeywordText.format_text(
		" · ".join(card.keyword_names())
	)
	_title.text = card.display_name
	(%ActionArt as TextureRect).texture = VillageCardFace.art_for(card)
	_description.text = KeywordText.format_text(card.description)
	_positive.text = KeywordText.format_text(ProgressionEconomy.output_text(_state, card))
	(%PositiveHeading as Label).visible = false
	_negative.text = KeywordText.format_text("代价与风险  /  " + card.negative)
	if card.effects.any(
		func(effect: CardEffect) -> bool: return effect.type == CardEffect.Type.DRILL
	):
		_negative.text += (
			"\n打井成功率 %d%%；失败仍扣费并消耗行动" % roundi(SurvivalRules.well_chance(_state) * 100)
		)
	_cost.text = "行动消耗"
	(%SelectedCosts as CardCostStrip).update_view(card, _state)
	_execute.text = "确认执行 · 剩余 %d 次行动" % (_state.actions_per_slot - _state.actions_used)
	_requirement.text = KeywordText.format_text(_state.catalog.requirement_text(card))
	_requirement.visible = not _requirement.text.is_empty()
	_reason.text = _state.can_play(_selected_uid)
	_reason.visible = not _reason.text.is_empty()
	_execute.disabled = _reason.visible
	if SurvivalRules.is_survey(card):
		_survey_report.text = _state.terrain_grid.report_short(
			TerrainGrid.position(_state.progress.explored_cells[-1]), _state.progress.explored_cells
		)
		_positive.text = "探索相邻区域，发现地形、资源与线索。"
	_preview.text = (
		(
			SurvivalRules.exploration_summary(_state)
			if SurvivalRules.is_survey(card)
			else SurvivalRules.summary(_state)
		)
		+ "\n"
		+ LaborRules.summary(_state, card)
		+ "\n"
		+ ("" if _reason.visible else _preview_card(card))
	)
	var deltas: PackedInt32Array = EffectResolver.resource_deltas(_state, card)
	for key: int in GameTypes.Stock.COUNT:
		if deltas[key] != 0:
			_preview.text += "\n%s %+d" % [GameTypes.STOCK_NAMES[key], deltas[key]]
	_preview.visible = not _preview.text.is_empty()


func _preview_card(card: CardDefinition) -> String:
	var before: VillageStats = EffectResolver.derive(_state)
	var after: VillageStats = _state.preview_card(card)
	var changes: PackedStringArray = []
	for key: int in GameTypes.Stat.COUNT:
		if key == GameTypes.Stat.BLACKOUT:
			continue
		if not is_equal_approx(before.values[key], after.values[key]):
			changes.append(
				"%s %.2f→%.2f" % [GameTypes.STAT_NAMES[key], before.values[key], after.values[key]]
			)
	for key: int in GameTypes.Stock.COUNT:
		if before.income[key] != after.income[key]:
			changes.append(
				"每日%s产出 %d→%d" % [GameTypes.STOCK_NAMES[key], before.income[key], after.income[key]]
			)
		if before.upkeep[key] != after.upkeep[key]:
			changes.append(
				"每日%s消耗 %d→%d" % [GameTypes.STOCK_NAMES[key], before.upkeep[key], after.upkeep[key]]
			)
	for synergy: String in after.synergies:
		if not before.synergies.has(synergy):
			changes.append(synergy)
	var label: String = (
		"成功时预览"
		if card.effects.any(
			func(effect: CardEffect) -> bool: return effect.type == CardEffect.Type.DRILL
		)
		else "结算预览"
	)
	return label + "  /  " + "；".join(changes) if not changes.is_empty() else ""


func _on_advanced_toggled(expanded: bool) -> void:
	(%AdvancedDetails as VBoxContainer).visible = expanded
	(%AdvancedToggle as Button).text = ("收起前置与结算预览 ▾" if expanded else "查看前置与结算预览 ▸")
