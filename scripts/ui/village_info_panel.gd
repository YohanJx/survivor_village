class_name VillageInfoPanel
extends VBoxContainer
## 独立村庄信息窗口，展示人口、生产、防守与联动。

signal jobs_requested(counts: PackedInt32Array, archers: bool)
signal crew_requested(size: int)

var _state: VillageState

@onready var _information: Label = %VillageInformation


func update_view(state: VillageState) -> void:
	_state = state
	_refresh_controls()
	var stats: VillageStats = (
		state.night_stats if state.phase == GameTypes.Phase.NIGHT else EffectResolver.derive(state)
	)
	var lines: PackedStringArray = [
		"村庄的发展方向 · " + GameTypes.REGION_NAMES[state.progress.region],
		"烦躁 %d/5 · 劳动体力 +%d%%" % [state.progress.frustration, state.progress.frustration * 15],
		(
			"今日事件：" + LaborRules.event_for(state).display_name
			if LaborRules.event_for(state) != null
			else "兼容存档"
		),
		"今日天气：%s · %s" % [state.weather.display_name, state.weather.description],
		"",
		(
			"参战 %d 人  ·  攻击 %.1f  ·  射程 %d"
			% [
				state.population,
				stats.attack,
				stats.attack_range,
			]
		),
		"生命 %d  ·  攻击间隔 %.2f 秒" % [stats.health, stats.cooldown],
		"",
	]
	var event: DailyEvent = LaborRules.event_for(state)
	if event != null:
		lines.append("今日事件详情：" + event.description)
		if state.progress.event_choice >= 0:
			lines.append("已选择：" + event.options[state.progress.event_choice].description)
	lines.append("每时段 %d 次行动 · 下个黎明按人口更新" % state.actions_per_slot)
	lines.append("\n职业分布")
	for profession: int in GameTypes.Profession.COUNT:
		lines.append(
			(
				"%s：%d 人"
				% [GameTypes.PROFESSION_NAMES[profession], state.profession_counts[profession]]
			)
		)
	lines.append("\n每日生产 / 消耗")
	for key: int in range(GameTypes.Stock.FOOD, GameTypes.Stock.COUNT):
		(
			lines
			. append(
				(
					"%s    库存 %d · +%d / −%d"
					% [
						GameTypes.STOCK_NAMES[key],
						state.resources[key],
						stats.income[key],
						stats.upkeep[key],
					]
				)
			)
		)
	(
		lines
		. append(
			(
				"黎明体力 +%d  ·  噪音 %+d  ·  污染 +%d"
				% [
					stats.stamina_recovery,
					stats.income[GameTypes.Stock.NOISE] - 3,
					stats.income[GameTypes.Stock.POLLUTION],
				]
			)
		)
	)
	lines.append("\n已建造")
	for definition: BuildingDefinition in state.catalog.library.buildings:
		if state.buildings[definition.id] > 0:
			lines.append("%s  ·  Lv.%d" % [definition.display_name, state.buildings[definition.id]])
	lines.append("\n当前联动与临时效果")
	for synergy: String in stats.synergies:
		lines.append("• " + synergy)
	for modifier: StatModifier in state.modifiers:
		(
			lines
			. append(
				(
					"• %s：%s %s%.2f（剩余 %d 夜）"
					% [
						modifier.source,
						GameTypes.STAT_NAMES[modifier.key],
						"×" if modifier.operation == StatModifier.Operation.MULTIPLY else "+",
						modifier.amount,
						modifier.remaining,
					]
				)
			)
		)
	lines.append("\n村庄记事")
	for entry: VillageLogEntry in state.history:
		lines.append("第 %d 日：%s" % [entry.day, entry.text])
	_information.text = "\n".join(lines)


func _ready() -> void:
	(%AssignJobs as Button).pressed.connect(_on_assign_jobs)
	(%CrewChoice as OptionButton).item_selected.connect(crew_requested.emit)


func _on_assign_jobs() -> void:
	var counts: PackedInt32Array = []
	for index: int in GameTypes.Profession.COUNT:
		counts.append(int((get_node("%%Job%d" % index) as SpinBox).value))
	jobs_requested.emit(counts, (%UseArchers as CheckButton).button_pressed)


func _refresh_controls() -> void:
	var editable: bool = (
		_state.phase == GameTypes.Phase.DAY
		and _state.slot == 0
		and _state.actions_used == 0
		and not _state.progress.assigned_today
	)
	for index: int in GameTypes.Profession.COUNT:
		var control: SpinBox = get_node("%%Job%d" % index) as SpinBox
		control.value = _state.profession_counts[index]
		control.editable = editable
	(%AssignJobs as Button).disabled = not editable
	var crew: OptionButton = %CrewChoice
	crew.select(_state.progress.crew)
	crew.disabled = _state.phase != GameTypes.Phase.DAY
	for size: int in range(1, 5):
		crew.set_item_disabled(size, size > mini(4, maxi(1, int(_state.population / 5.0))))
