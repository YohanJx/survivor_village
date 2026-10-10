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
@onready var _negative: RichTextLabel = %Negative
@onready var _cost: Label = %Cost
@onready var _requirement: Label = %Requirement
@onready var _preview: Label = %Preview
@onready var _reason: Label = %Reason
@onready var _execute: Button = %ExecuteButton


func _ready() -> void:
	_execute.pressed.connect(execute_requested.emit)


func update_view(state: VillageState, selected_uid: int, selection_changed: bool = false) -> void:
	_state = state
	_selected_uid = selected_uid
	if selection_changed:
		(%DetailScroll as ScrollContainer).scroll_vertical = 0
	_refresh_detail()


func _refresh_detail() -> void:
	if _state == null:
		return
	var card: CardDefinition = _state.find_card(_selected_uid)
	_empty_hint.visible = card == null
	_card_detail.visible = card != null
	_execute.visible = card != null
	_cost.visible = card != null
	_negative.visible = card != null
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
	_kind.text = KeywordText.format_text(card.kind_name() + "  /  " + " · ".join(card.tags))
	_title.text = card.display_name
	_description.text = KeywordText.format_text(card.description)
	_positive.text = KeywordText.format_text(ProgressionEconomy.output_text(_state, card))
	_negative.text = KeywordText.format_text("代价与风险  /  " + card.negative)
	_cost.text = "消耗  /  " + _state.catalog.cost_text(card, _state)
	if card.profession != GameTypes.Profession.GENERAL:
		_cost.text += (
			"\n%s %d 人 · 体力 ×%.2f"
			% [
				GameTypes.PROFESSION_NAMES[card.profession],
				_state.profession_counts[card.profession],
				_state.catalog.library.workforce_rules.stamina_multiplier(
					card.profession, _state.profession_counts
				)
			]
		)
	_execute.text = "确认执行 · 剩余 %d 次行动" % (_state.actions_per_slot - _state.actions_used)
	_requirement.text = _state.catalog.requirement_text(card)
	_requirement.visible = not _requirement.text.is_empty()
	_reason.text = _state.can_play(_selected_uid)
	_reason.visible = not _reason.text.is_empty()
	_execute.disabled = _reason.visible
	_preview.text = (
		LaborRules.summary(_state, card) + "\n" + ("" if _reason.visible else _preview_card(card))
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
	return "结算预览  /  " + "；".join(changes) if not changes.is_empty() else ""
