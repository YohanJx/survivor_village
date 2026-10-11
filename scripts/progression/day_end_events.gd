class_name DayEndEvents
extends RefCounted
## 日终事件抽取与无副作用准入；结算由 VillageState 调用统一效果入口。


static func for_day(state: VillageState) -> DailyEvent:
	var candidates: Array[DailyEvent] = []
	var weight: int = 0
	for event: DailyEvent in state.catalog.library.progression_rules.day_end_events:
		if not event.regions.is_empty() and not event.regions.has(state.progress.region):
			continue
		if state.progress.recent_day_end_events.has(event.id):
			continue
		candidates.append(event)
		weight += event.weight
	if candidates.is_empty():
		return null
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = state.run_seed ^ (state.day * 193939 + 92717)
	var roll: int = generator.randi_range(1, weight)
	for event: DailyEvent in candidates:
		roll -= event.weight
		if roll <= 0:
			return event
	return null


static func option_error(state: VillageState, index: int) -> String:
	var event: DailyEvent = state.current_day_end_event()
	if state.phase != GameTypes.Phase.DAY_END or event == null:
		return "当前没有待处理的日终事件"
	if index < 0 or index >= event.options.size():
		return "事件选项无效"
	var card: CardDefinition = event.options[index]
	var error: String = EffectResolver.construction_error(state, card)
	if not error.is_empty():
		return error
	var costs: PackedInt32Array = EffectResolver.cost_totals(card, state)
	var deltas: PackedInt32Array = EffectResolver.resource_deltas(state, card)
	for key: int in GameTypes.Stock.COUNT:
		if state.resources[key] < costs[key]:
			return (
				"%s不足：需要 %d，现有 %d" % [GameTypes.STOCK_NAMES[key], costs[key], state.resources[key]]
			)
		if key not in [GameTypes.Stock.NOISE, GameTypes.Stock.POLLUTION]:
			if state.resources[key] + deltas[key] < 0:
				return "%s不足以承担事件代价" % GameTypes.STOCK_NAMES[key]
	return ""


static func configuration_error(
	rules: ProgressionRules, buildings: Array[BuildingDefinition], keywords: KeywordLibrary
) -> String:
	var ids: Dictionary[String, bool] = {}
	var counts: PackedInt32Array = []
	counts.resize(GameTypes.Region.COUNT)
	for event: DailyEvent in rules.day_end_events:
		if (
			event == null
			or event.id.is_empty()
			or ids.has(event.id)
			or rules.event_for(event.id) != null
			or event.display_name.is_empty()
			or event.description.is_empty()
			or event.weight < 1
			or event.options.size() != 2
			or event.labor != GameTypes.Labor.NONE
			or not is_equal_approx(event.output_multiplier, 1.0)
			or not is_equal_approx(event.cost_multiplier, 1.0)
			or event.low_mood
			or not event.output_stocks.is_empty()
		):
			return "日终事件缺失、重复或选项不完整"
		ids[event.id] = true
		for region: int in event.regions:
			if region < 0 or region >= GameTypes.Region.COUNT:
				return "日终事件地图条件非法"
		for region: int in GameTypes.Region.COUNT:
			if event.regions.is_empty() or event.regions.has(region):
				counts[region] += 1
		var fallback: bool = event.skippable
		for option: CardDefinition in event.options:
			var error: String = ResourceValidation.card_error(option, buildings)
			if not error.is_empty():
				return error
			error = KeywordRules.registered_error(option, keywords)
			if not error.is_empty():
				return error
			error = _option_configuration_error(option)
			if not error.is_empty():
				return error
			if _is_free_option(option):
				fallback = true
		if not fallback:
			return "不可跳过的日终事件必须有补给耗尽时仍可处理的选项"
	for count: int in counts:
		if count < 3:
			return "每张地图至少需要三个日终事件，避免连续重复后事件池为空"
	return ""


static func _option_configuration_error(option: CardDefinition) -> String:
	if (
		option.kind != CardDefinition.Kind.EVENT
		or option.reusable
		or option.labor != GameTypes.Labor.NONE
		or option.expedition
		or option.profession != GameTypes.Profession.GENERAL
		or option.building != null
		or not option.prerequisites.is_empty()
		or not option.required_cards.is_empty()
		or not option.regions.is_empty()
		or option.strategy != GameTypes.Strategy.NONE
		or option.vent
		or option.positive.is_empty()
		or option.negative.is_empty()
	):
		return "日终选项必须是不依赖白天行动前置的事件定义"
	var positive: bool = option.mood_delta < 0
	var negative: bool = option.mood_delta > 0
	for cost: ResourceCost in option.costs:
		negative = negative or cost.amount > 0
	for effect: CardEffect in option.effects:
		if effect.required_building != null:
			return "日终选项不能隐藏有条件的收益或代价"
		match effect.type:
			CardEffect.Type.RESOURCE:
				var hazard: bool = effect.key in [GameTypes.Stock.NOISE, GameTypes.Stock.POLLUTION]
				positive = positive or (effect.amount < 0 if hazard else effect.amount > 0)
				negative = negative or (effect.amount > 0 if hazard else effect.amount < 0)
			CardEffect.Type.HEAL, CardEffect.Type.POPULATION:
				positive = positive or effect.amount > 0
				negative = negative or effect.amount < 0
			CardEffect.Type.REPAIR_WALLS:
				positive = true
			CardEffect.Type.MODIFIER:
				var neutral: float = (
					1.0 if effect.modifier.operation == StatModifier.Operation.MULTIPLY else 0.0
				)
				if is_equal_approx(effect.modifier.amount, neutral):
					continue
				positive = positive or _modifier_is_positive(effect.modifier)
				negative = negative or not _modifier_is_positive(effect.modifier)
			_:
				return "日终事件不能执行建造或勘探等白天行动"
	return "" if positive and negative else "日终事件选项必须同时有实际正面与负面效果"


static func _modifier_is_positive(modifier: StatModifier) -> bool:
	var amount: float = modifier.amount
	if modifier.operation == StatModifier.Operation.MULTIPLY:
		amount -= 1.0
	return (
		amount < 0
		if modifier.key in [GameTypes.Stat.COOLDOWN, GameTypes.Stat.WAVE_SIZE]
		else amount > 0
	)


static func _is_free_option(option: CardDefinition) -> bool:
	if not option.costs.is_empty():
		return false
	for effect: CardEffect in option.effects:
		if effect.type == CardEffect.Type.POPULATION and effect.amount < 0:
			return false
		if effect.type == CardEffect.Type.RESOURCE and effect.amount < 0:
			if effect.key not in [GameTypes.Stock.NOISE, GameTypes.Stock.POLLUTION]:
				return false
	return true
