class_name InventoryPanel
extends VBoxContainer
## 完整库存与当日固定收支展示；数值只读取 EffectResolver 的独立查询记录。

signal close_requested

const STOCK_COUNT: int = GameTypes.Stock.COUNT

var _labels: Array[Label] = []
var _selected_stock: GameTypes.Stock = GameTypes.Stock.FOOD

@onready var _close: Button = $Heading/CloseButton
@onready var _title: Label = $Heading/Title
@onready var _table: GridContainer = $Scroll/ContentMargin/Body/Table
@onready var _header: GridContainer = $HeaderMargin/Header
@onready var _note: Label = $Note
@onready var _effects: Label = $Scroll/ContentMargin/Body/Effects


func _ready() -> void:
	_close.pressed.connect(close_requested.emit)
	_table.resized.connect(_on_table_resized)
	for key: int in STOCK_COUNT:
		for column: int in 6:
			var label: Label = Label.new()
			label.add_theme_font_size_override("font_size", 15)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if column == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			_table.add_child(label)
			_labels.append(label)


func select_stock(stock: GameTypes.Stock) -> void:
	_selected_stock = stock


## 返回当前界面字段供交互验证；不读取或修改模型。
func displayed_text(stock: GameTypes.Stock, column: int) -> String:
	if column < 0 or column >= 6:
		return ""
	return _labels[int(stock) * 6 + column].text


func update_view(state: VillageState) -> void:
	var selected: GameTypes.Stock = _selected_stock
	if selected == GameTypes.Stock.MATERIALS and state.progress.region != GameTypes.Region.LEGACY:
		selected = GameTypes.Stock.WOOD
	_title.text = "库存与每日收支"
	var balances: Array[ResourceBalance] = EffectResolver.resource_balances(state)
	for key: int in STOCK_COUNT:
		var balance: ResourceBalance = balances[key]
		var values: PackedStringArray = [
			GameTypes.STOCK_NAMES[key], str(balance.current), "+%d" % balance.income,
			"−%d" % balance.upkeep, "%+d" % balance.net,
			str(balance.capacity) if balance.capacity >= 0 else "—"
		]
		for column: int in 6:
			var label: Label = _labels[key * 6 + column]
			label.visible = key != GameTypes.Stock.MATERIALS or state.progress.region == GameTypes.Region.LEGACY
			label.text = values[column]
			label.add_theme_color_override("font_color", UiElements.EMPHASIS if key == selected else UiElements.TEXT_PRIMARY)
	_note.text = "当日固定生产 − 消耗 = 净变化；白天出牌费用和夜战箭矢等耗材另行扣除。\n粮水超过跨日容量的余量会丢弃；电力只在有容量时保留。噪声黎明清零，污染另按地形恢复。"
	var stats: VillageStats = (
		state.night_stats if state.phase != GameTypes.Phase.DAY and state.night_stats != null
		else EffectResolver.derive(state)
	)
	_effects.text = (
		"自动设施：保持对应岗位与原料即可生产；同夜的新产物从次日才能加工。\n"
		+ "装备路线：长矛架或工坊 → 弓箭 / 箭矢；守卫装备在村庄信息的分工页设置。\n"
		+ "\n".join(stats.synergies)
	)


func _on_table_resized() -> void:
	# 所有列等宽；表头右侧留出实际滚动条与内容边距，避免滚动后错列。
	var width: float = maxf(0.0, floorf((_table.size.x - 90.0) / 6.0))
	for column: int in 6:
		(_header.get_child(column) as Control).custom_minimum_size.x = width
	for label: Label in _labels:
		label.custom_minimum_size.x = width
	var gutter: float = size.x - _table.size.x
	($HeaderMargin as MarginContainer).add_theme_constant_override("margin_right", roundi(gutter))
