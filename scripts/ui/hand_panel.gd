class_name VillageHandPanel
extends VBoxContainer
## 按手牌 UID 复用控件；库存与选中状态变化只刷新现有卡牌。

signal card_selected(uid: int)
signal inspect_requested(uid: int)
signal visible_cards_changed
signal skip_requested

const CARD_SCENE: PackedScene = preload("res://scenes/ui/card_button.tscn")

var _category_index: int = 0
var _visible_count: int = 0
var _selected_uid: int = -1

var _views: Dictionary[int, VillageCardButton] = {}
var _filter_ids: PackedStringArray = [""]
var _filter_keywords: Array[KeywordDefinition] = []
var _filtered_keyword: String = ""

var _hand_title: Label
var _skip_button: Button
var _keyword_filter: OptionButton

@onready var _hand_container: HBoxContainer = %HandContainer


## 由共同管理者注入面板工具栏；手牌只管理筛选与请求，不执行游戏规则。
func bind_controls(title: Label, filter: OptionButton, skip: Button) -> void:
	_hand_title = title
	_keyword_filter = filter
	_skip_button = skip
	_skip_button.pressed.connect(skip_requested.emit)
	_keyword_filter.item_selected.connect(_on_keyword_filter_selected)


func update_view(state: VillageState, selected_uid: int, blocked: bool) -> void:
	_selected_uid = selected_uid
	_update_filter(state)
	_hand_title.text = "行动卡 · %d 张" % state.hand.size()
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
			card_view.inspect_requested.connect(inspect_requested.emit.bind(entry.uid))
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
			+ "\n消耗："
			+ state.catalog.cost_text(entry.definition, state)
		)
		view.is_selected = entry.uid == selected_uid
		view.disabled = blocked
		_hand_container.move_child(view, index)
		view.update_face(state)
		view.queue_redraw()
	_apply_filter()


## 0 表示全部，其余索引对应原生 CardDefinition.Kind；切换时清除关键词筛选。
func set_category(index: int) -> void:
	_category_index = index
	_filtered_keyword = ""
	if _keyword_filter.item_count > 0:
		_keyword_filter.select(0)
	($HandScroll as ScrollContainer).scroll_horizontal = 0
	_apply_filter()


## 无副作用查询当前可见卡牌数量，供浮动面板选择紧凑展示尺寸。
func visible_card_count() -> int:
	var count: int = 0
	for view: VillageCardButton in _views.values():
		if view.visible:
			count += 1
	return count


## 面板布局变化后保持当前卡牌在滚动视口内；不改变选择或游戏状态。
func reveal_selected() -> void:
	if not _views.has(_selected_uid) or not is_visible_in_tree():
		return
	var selected: VillageCardButton = _views[_selected_uid]
	if selected.visible:
		($HandScroll as ScrollContainer).ensure_control_visible(selected)


func _update_filter(state: VillageState) -> void:
	if _filter_keywords == state.catalog.library.keyword_library.definitions:
		return
	_filter_keywords = state.catalog.library.keyword_library.definitions.duplicate()
	_filter_ids = PackedStringArray([""])
	_filtered_keyword = ""
	_keyword_filter.clear()
	_keyword_filter.add_item("全部关键词")
	for category: int in [
		KeywordDefinition.Category.TERRAIN,
		KeywordDefinition.Category.PROFESSION,
		KeywordDefinition.Category.TOPIC
	]:
		for keyword: KeywordDefinition in _filter_keywords:
			if keyword.category != category:
				continue
			_filter_ids.append(keyword.id)
			_keyword_filter.add_item(
				"%s：%s" % [KeywordDefinition.CATEGORY_NAMES[category], keyword.title]
			)


func _on_keyword_filter_selected(index: int) -> void:
	_filtered_keyword = _filter_ids[index]
	_apply_filter()


func _apply_filter() -> void:
	var count: int = 0
	for view: VillageCardButton in _views.values():
		view.visible = (
			(_category_index == 0 or int(view.card.kind) + 1 == _category_index)
			and (
				_filtered_keyword.is_empty()
				or view.card.keywords.any(
					func(keyword: KeywordDefinition) -> bool: return keyword.id == _filtered_keyword
				)
			)
		)
		if view.visible:
			count += 1
	(%EmptyCategory as Label).visible = count == 0
	_hand_title.text = "%d / %d 张" % [count, _views.size()]
	if _visible_count != count:
		_visible_count = count
		visible_cards_changed.emit()
