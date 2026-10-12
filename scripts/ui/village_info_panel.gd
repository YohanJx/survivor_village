class_name VillageInfoPanel
extends VBoxContainer
## 独立村庄信息窗口，展示人口、生产、防守与联动。

signal jobs_requested(counts: PackedInt32Array, archers: bool)
signal crew_requested(size: int)

const ROLE_HINTS: PackedStringArray = ["可执行通用行动", "采集与探索", "建造与修补", "勘探与机械", "药品与治疗", "训练与守夜"]

var _state: VillageState
var _draft: PackedInt32Array = []
var _source_roster: PackedInt32Array = []
var _source_day: int = -1
var _source_progress: VillageProgress
var _rows: Array[WorkforceRow] = []

@onready var _information: Label = %VillageInformation


func _ready() -> void:
	var tabs: TabContainer = %VillageTabs
	tabs.set_tab_title(0, "分工与队伍")
	tabs.set_tab_title(1, "村庄概况")
	for index: int in GameTypes.Profession.COUNT:
		var row: WorkforceRow = get_node("%%Job%d" % index) as WorkforceRow
		_rows.append(row)
		row.adjustment_requested.connect(_on_allocation_adjusted.bind(index))
	(%AssignJobs as Button).pressed.connect(_on_assign_jobs)
	(%CrewChoice as OptionButton).item_selected.connect(crew_requested.emit)


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
			"旧存档当日影响：" + LaborRules.event_for(state).display_name
			if LaborRules.event_for(state) != null
			else "日终事件：守夜结束后处理"
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
		lines.append("旧存档影响详情：" + event.description)
		if state.progress.event_choice >= 0:
			lines.append("已选择：" + event.options[state.progress.event_choice].description)
	lines.append("每时段 %d 次行动 · 下个黎明按人口更新" % state.actions_per_slot)
	lines.append("\n" + SurvivalRules.summary(state))
	lines.append("\n跨日存储容量（当日消耗后保留，超出丢弃）")
	for stock: int in [GameTypes.Stock.FOOD, GameTypes.Stock.WATER, GameTypes.Stock.POWER]:
		lines.append(
			(
				"%s：%d"
				% [
					GameTypes.STOCK_NAMES[stock],
					SurvivalRules.storage_capacity(state, stock as GameTypes.Stock)
				]
			)
		)
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
				"黎明体力 +%d · 噪声清零 · 生产污染 +%d / 生态恢复 %d"
				% [
					stats.stamina_recovery,
					stats.income[GameTypes.Stock.POLLUTION],
					(
						state
						. catalog
						. library
						. progression_rules
						. map_for(state.progress.region)
						. pollution_recovery
					),
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


func _on_assign_jobs() -> void:
	jobs_requested.emit(_draft.duplicate(), (%UseArchers as CheckButton).button_pressed)


func _on_allocation_adjusted(delta: int, profession: int) -> void:
	if not _can_edit():
		return
	_draft = _state.catalog.library.workforce_rules.adjusted_allocation(
		_draft, _state.population, profession as GameTypes.Profession, delta
	)
	_refresh_allocation()


func _can_edit() -> bool:
	return (
		_state != null
		and _state.phase == GameTypes.Phase.DAY
		and _state.slot == 0
		and _state.actions_used == 0
		and not _state.progress.assigned_today
	)


func _refresh_controls() -> void:
	if (
		_source_progress != _state.progress
		or _source_day != _state.day
		or _source_roster != _state.profession_counts
	):
		_source_day = _state.day
		_source_progress = _state.progress
		_source_roster = _state.profession_counts.duplicate()
		_draft = _source_roster.duplicate()
		(%UseArchers as CheckButton).button_pressed = _state.progress.survivors.any(
			func(person: SurvivorRecord) -> bool: return person.archer
		)
	_refresh_allocation()
	var crew: OptionButton = %CrewChoice
	crew.select(_state.progress.crew)
	crew.disabled = _state.phase != GameTypes.Phase.DAY
	for size: int in range(1, 5):
		crew.set_item_disabled(size, size > mini(4, maxi(1, int(_state.population / 5.0))))


func _refresh_allocation() -> void:
	var editable: bool = _can_edit()
	var available: int = _draft[GameTypes.Profession.GENERAL]
	(%AllocationSummary as Label).text = "幸存者 %d 人  ·  待分配 %d 人" % [_state.population, available]
	(%AllocationHint as Label).text = (
		"用 − 释放人员，再用 + 分配到其他岗位。调整后确认，今日只可确认一次。" if editable else "今日分工已锁定，下个黎明可重新安排。"
	)
	for index: int in GameTypes.Profession.COUNT:
		_rows[index].configure(
			"待分配" if index == GameTypes.Profession.GENERAL else GameTypes.PROFESSION_NAMES[index],
			_draft[index],
			ROLE_HINTS[index],
			editable and index > 0 and _draft[index] > 0,
			editable and index > 0 and available > 0,
			index > 0
		)
	(%AssignJobs as Button).disabled = not editable
	(%UseArchers as CheckButton).disabled = not editable
