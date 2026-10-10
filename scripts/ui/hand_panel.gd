class_name VillageHandPanel
extends VBoxContainer
## 按手牌 UID 复用控件；库存与选中状态变化只刷新现有卡牌。

signal card_selected(uid: int)
signal skip_requested

const CARD_SCENE: PackedScene = preload("res://scenes/ui/card_button.tscn")

var _views: Dictionary[int, VillageCardButton] = {}

@onready var _hand_title: Label = %HandTitle
@onready var _hand_container: HBoxContainer = %HandContainer
@onready var _skip_button: Button = %SkipButton


func _ready() -> void:
	_skip_button.pressed.connect(skip_requested.emit)


func update_view(state: VillageState, selected_uid: int, blocked: bool) -> void:
	_hand_title.text = "发展卡牌  /  %d 张" % state.hand.size()
	(%Hint as Label).text = (
		"本时段剩余 %d / %d 次行动 · %d 人"
		% [state.actions_per_slot - state.actions_used, state.actions_per_slot, state.population]
	)
	_skip_button.disabled = blocked or state.phase != GameTypes.Phase.DAY
	var active_ids: Dictionary[int, bool] = {}
	for entry: CardInstance in state.hand:
		active_ids[entry.uid] = true
	for uid: int in _views.keys():
		if not active_ids.has(uid):
			var obsolete: VillageCardButton = _views[uid]
			_hand_container.remove_child(obsolete)
			obsolete.queue_free()
			_views.erase(uid)
	for index: int in state.hand.size():
		var entry: CardInstance = state.hand[index]
		if not _views.has(entry.uid):
			var card_view: VillageCardButton = CARD_SCENE.instantiate() as VillageCardButton
			card_view.card = entry.definition
			card_view.pressed.connect(card_selected.emit.bind(entry.uid))
			_hand_container.add_child(card_view)
			_views[entry.uid] = card_view
		var view: VillageCardButton = _views[entry.uid]
		view.card = entry.definition
		view.tooltip_text = (
			entry.definition.display_name
			+ "\n收益："
			+ ProgressionEconomy.output_text(state, entry.definition)
			+ "\n风险："
			+ entry.definition.negative
		)
		view.cost = state.catalog.cost_text(entry.definition, state)
		view.is_selected = entry.uid == selected_uid
		view.locked = not state.can_play(entry.uid).is_empty()
		view.reusable = entry.definition.reusable
		view.disabled = blocked
		_hand_container.move_child(view, index)
		view.queue_redraw()
