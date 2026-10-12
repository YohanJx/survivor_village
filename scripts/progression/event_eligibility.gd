class_name EventEligibility
extends RefCounted
## 原生事件情境准入；只读取真实发现、设施及连续短缺，不揭示未知地形。


static func matches(state: VillageState, event: DailyEvent) -> bool:
	if not event.regions.is_empty() and not event.regions.has(state.progress.region):
		return false
	if state.day < event.min_day or (event.max_day > 0 and state.day > event.max_day):
		return false
	var explored: int = state.progress.explored_cells.size()
	if explored < event.min_explored or (event.max_explored > 0 and explored > event.max_explored):
		return false
	if (
		state.population < event.min_population
		or state.progress.frustration < event.min_frustration
	):
		return false
	for discovery: int in event.required_discoveries:
		if not state.progress.discoveries.has(discovery):
			return false
	if event.required_building != GameTypes.Building.COUNT:
		if state.buildings[event.required_building] <= 0:
			return false
	if (
		event.required_stock != GameTypes.Stock.COUNT
		and state.resources[event.required_stock] < event.min_stock
	):
		return false
	if (
		event.requires_damage
		and state.core_health >= state.core_max_health
		and not _has_wall_damage(state.wall_damage)
	):
		return false
	if event.trigger == DailyEvent.Trigger.AMBIENT:
		return not state.progress.recent_day_end_events.has(event.id)
	var days: int = (
		state.progress.hungry_days
		if event.trigger == DailyEvent.Trigger.HUNGER
		else state.progress.thirsty_days
	)
	return (
		days >= event.min_deprivation_days
		and (event.max_deprivation_days == 0 or days <= event.max_deprivation_days)
	)


static func configuration_error(event: DailyEvent) -> String:
	if event.trigger < DailyEvent.Trigger.AMBIENT or event.trigger > DailyEvent.Trigger.THIRST:
		return "事件触发类型非法"
	if (
		event.min_day < 1
		or event.max_day < 0
		or (event.max_day > 0 and event.max_day < event.min_day)
	):
		return "事件日期条件非法"
	if (
		event.min_explored < 0
		or event.max_explored < 0
		or (event.max_explored > 0 and event.max_explored < event.min_explored)
	):
		return "事件探索条件非法"
	if event.min_population < 0 or event.min_frustration < 0:
		return "事件人口或情绪条件非法"
	if event.required_building < 0 or event.required_building > GameTypes.Building.COUNT:
		return "事件设施条件非法"
	if (
		event.required_stock < 0
		or event.required_stock > GameTypes.Stock.COUNT
		or event.min_stock < 1
	):
		return "事件库存条件非法"
	for discovery: int in event.required_discoveries:
		if discovery < 0 or discovery >= GameTypes.Discovery.COUNT:
			return "事件发现条件非法"
	if (
		event.min_deprivation_days < 1
		or event.max_deprivation_days < 0
		or (
			event.max_deprivation_days > 0
			and event.max_deprivation_days < event.min_deprivation_days
		)
	):
		return "事件连续短缺条件非法"
	if event.trigger != DailyEvent.Trigger.AMBIENT and event.skippable:
		return "饥渴后果不能跳过"
	return ""


static func crisis_coverage_error(events: Array[DailyEvent]) -> String:
	for trigger: DailyEvent.Trigger in [DailyEvent.Trigger.HUNGER, DailyEvent.Trigger.THIRST]:
		var stages: Array[DailyEvent] = []
		for event: DailyEvent in events:
			if event.trigger != trigger:
				continue
			if (
				not event.regions.is_empty()
				or event.min_day != 1
				or event.max_day != 0
				or event.min_explored != 0
				or event.max_explored != 0
				or event.min_population != 0
				or event.min_frustration != 0
				or not event.required_discoveries.is_empty()
				or event.requires_damage
				or event.required_building != GameTypes.Building.COUNT
				or event.required_stock != GameTypes.Stock.COUNT
			):
				return "饥渴后果不能受地图、发展或情绪条件屏蔽"
			stages.append(event)
		stages.sort_custom(
			func(first: DailyEvent, second: DailyEvent) -> bool:
				return first.min_deprivation_days < second.min_deprivation_days
		)
		var next_day: int = 1
		for event: DailyEvent in stages:
			if next_day == 0 or event.min_deprivation_days != next_day:
				return "饥渴严重度阶段不能缺失或重叠"
			next_day = 0 if event.max_deprivation_days == 0 else event.max_deprivation_days + 1
		if next_day != 0:
			return "每种饥渴后果必须覆盖从首日到长期短缺"
	return ""


static func _has_wall_damage(damage: Dictionary[Vector2i, float]) -> bool:
	for value: float in damage.values():
		if value > 0.0:
			return true
	return false
