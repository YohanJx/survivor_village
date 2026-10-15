class_name EffectResolver
extends RefCounted


static func derive(state: VillageState) -> VillageStats:
	var stats: VillageStats = VillageStats.new()
	stats.upkeep[GameTypes.Stock.FOOD] = state.population
	stats.upkeep[GameTypes.Stock.WATER] = state.population
	var multipliers: PackedFloat64Array = PackedFloat64Array()
	multipliers.resize(GameTypes.Stat.COUNT)
	multipliers.fill(1.0)
	var synergy_definitions: Array[BuildingDefinition] = []
	for definition: BuildingDefinition in state.catalog.library.buildings:
		var level: int = state.buildings[definition.id]
		if level == 0:
			continue
		for modifier: StatModifier in definition.modifiers:
			_accumulate(stats, multipliers, modifier, level)
		var flow: ProductionProfile = definition.production
		if flow != null and not definition.synergy is SustainableProductionSynergy:
			stats.income[GameTypes.Stock.FOOD] += flow.food * level
			stats.income[GameTypes.Stock.WATER] += flow.water * level
			stats.income[GameTypes.Stock.POWER] += flow.power * level
			stats.income[GameTypes.Stock.MATERIALS] += flow.materials * level
			stats.income[GameTypes.Stock.NOISE] += flow.noise * level
			stats.income[GameTypes.Stock.POLLUTION] += flow.pollution * level
			stats.upkeep[GameTypes.Stock.FOOD] += flow.food_upkeep * level
			stats.upkeep[GameTypes.Stock.WATER] += flow.water_upkeep * level
			stats.upkeep[GameTypes.Stock.MATERIALS] += flow.materials_upkeep * level
		if definition.synergy != null:
			synergy_definitions.append(definition)
	for modifier: StatModifier in state.modifiers:
		_accumulate(stats, multipliers, modifier, 1)
	if state.weather != null:
		stats.income[GameTypes.Stock.WATER] += state.weather.water_income
		stats.values[GameTypes.Stat.STAMINA_RECOVERY] += state.weather.stamina_recovery
		for modifier: StatModifier in state.weather.modifiers:
			_accumulate(stats, multipliers, modifier, 1)
	ProgressionEconomy.derive(state, stats)
	# Rules are Resource subclasses; their ordering is editable in the Inspector.
	synergy_definitions.sort_custom(_compare_synergies)
	var power_budget: int = state.resources[GameTypes.Stock.POWER]
	for definition: BuildingDefinition in synergy_definitions:
		power_budget = definition.synergy.apply(state, stats, multipliers, power_budget)
	# 生产原料先留给黎明结算，夜战维修/治疗只使用剩余耗材，避免双重消费。
	for stock: int in range(GameTypes.Stock.WOOD, GameTypes.Stock.COUNT):
		stats.supplies[stock] = maxi(0, state.resources[stock] - stats.upkeep[stock])
	for key: int in GameTypes.Stat.COUNT:
		stats.values[key] *= multipliers[key]
	stats.values[GameTypes.Stat.ATTACK] = maxf(1.0, stats.attack)
	stats.values[GameTypes.Stat.HEALTH] = maxf(15.0, stats.health)
	stats.values[GameTypes.Stat.SPEED] = maxf(20.0, stats.speed)
	stats.values[GameTypes.Stat.COOLDOWN] = maxf(0.65, stats.cooldown)
	stats.values[GameTypes.Stat.WAVE_SIZE] = clampf(stats.wave_size, 0.35, 3.0)
	NightThreat.derive(state, stats)
	return stats


static func daily_upkeep(state: VillageState) -> PackedInt32Array:
	var stats: VillageStats = (
		state.night_stats
		if state.night_stats != null and state.phase != GameTypes.Phase.DAY
		else derive(state)
	)
	var upkeep: PackedInt32Array = stats.upkeep.duplicate()
	if state.phase == GameTypes.Phase.DAY_END and state.last_report != null:
		for stock: int in [GameTypes.Stock.FOOD, GameTypes.Stock.WATER]:
			upkeep[stock] -= state.last_report.started_survivors - state.population
	return upkeep


## 库存与当日固定收支查询，返回独立记录；夜间读取冻结快照，不改变状态。
static func resource_balances(state: VillageState) -> Array[ResourceBalance]:
	var stats: VillageStats = (
		state.night_stats
		if state.night_stats != null and state.phase != GameTypes.Phase.DAY
		else derive(state)
	)
	var upkeep: PackedInt32Array = daily_upkeep(state)
	var balances: Array[ResourceBalance] = []
	for key: int in GameTypes.Stock.COUNT:
		var balance: ResourceBalance = ResourceBalance.new()
		balance.key = key as GameTypes.Stock
		balance.current = state.resources[key]
		balance.income = stats.income[key]
		balance.upkeep = upkeep[key]
		if key in [GameTypes.Stock.FOOD, GameTypes.Stock.WATER, GameTypes.Stock.POWER]:
			balance.capacity = SurvivalRules.storage_capacity(state, key as GameTypes.Stock)
		if key == GameTypes.Stock.STAMINA:
			balance.income = stats.stamina_recovery
			balance.capacity = 100
		balances.append(balance)
	return balances


static func apply(
	state: VillageState, card: CardDefinition, pay_costs: bool = false, preview: bool = false
) -> void:
	var consumed_mood: int = mini(3, state.progress.frustration) if card.vent else 0
	var deltas: PackedInt32Array = resource_deltas(state, card, pay_costs)
	for key: int in GameTypes.Stock.COUNT:
		state.add_resource(key as GameTypes.Stock, deltas[key])
	var initial_buildings: PackedInt32Array = state.buildings.duplicate()
	for effect: CardEffect in card.effects:
		if effect.required_building != null and initial_buildings[effect.required_building.id] == 0:
			continue
		match effect.type:
			CardEffect.Type.RESOURCE:
				pass
			CardEffect.Type.BUILD:
				state.buildings[effect.building.id] += int(effect.amount)
				if effect.building.id == GameTypes.Building.WALL:
					state.wall_damage.clear()
			CardEffect.Type.MODIFIER:
				var instance: StatModifier = effect.modifier.copy_runtime()
				instance.remaining = instance.duration
				instance.source = card.display_name
				state.modifiers.append(instance)
			CardEffect.Type.HEAL:
				state.core_health = minf(state.core_max_health, state.core_health + effect.amount)
			CardEffect.Type.REPAIR_WALLS:
				state.wall_damage.clear()
			CardEffect.Type.POPULATION:
				state.population += int(effect.amount)
			CardEffect.Type.SURVEY, CardEffect.Type.WELL_TOOLS, CardEffect.Type.WELL_SURVEY, CardEffect.Type.DRILL:
				SurvivalRules.commit(state, effect, preview)
	if consumed_mood > 0:
		var modifier: StatModifier = StatModifier.new()
		modifier.key = GameTypes.Stat.ATTACK
		modifier.operation = StatModifier.Operation.MULTIPLY
		modifier.amount = 1.0 + consumed_mood * 0.08
		modifier.duration = 1
		modifier.remaining = 1
		modifier.source = card.display_name
		state.modifiers.append(modifier)
		state.progress.frustration -= consumed_mood
	LaborRules.commit(state, card)
	if card.conceals:
		state.progress.concealed = true
	PopulationRules.reconcile(state)


static func expire_after_night(state: VillageState) -> void:
	for i: int in range(state.modifiers.size() - 1, -1, -1):
		state.modifiers[i].remaining -= 1
		if state.modifiers[i].remaining <= 0:
			state.modifiers.remove_at(i)


static func cost_totals(card: CardDefinition, state: VillageState = null) -> PackedInt32Array:
	var totals: PackedInt32Array = []
	totals.resize(GameTypes.Stock.COUNT)
	for cost: ResourceCost in card.costs:
		var key: GameTypes.Stock = cost.key
		if state != null and key == GameTypes.Stock.MATERIALS:
			key = LaborRules.material_key(state, card)
		totals[key] += cost.amount
	if state != null:
		if LaborRules.renewable_fallback(state, card):
			totals.fill(0)
			totals[GameTypes.Stock.STAMINA] = 4
		if SurvivalRules.is_survey(card) and state.progress.exploration_target >= 0:
			var distance: int = TerrainGrid.distance(
				TerrainGrid.position(state.progress.exploration_target)
			)
			totals[GameTypes.Stock.STAMINA] += maxi(0, distance - 1) * 2
		var crew: int = LaborRules.crew_size(state, card)
		totals[GameTypes.Stock.STAMINA] += card.crew_stamina * (crew - 1)
		totals[GameTypes.Stock.WATER] += card.crew_water * (crew - 1)
		if (
			state.progress.region != GameTypes.Region.LEGACY
			and card.labor == GameTypes.Labor.TRAIN
			and not card.vent
		):
			var trainees: int = maxi(1, state.profession_counts[GameTypes.Profession.GUARD])
			totals[GameTypes.Stock.FOOD] *= trainees
		if card.mood_delta < 0 and not card.expedition:
			totals[GameTypes.Stock.FOOD] *= maxi(1, int(state.population / 5.0))
			totals[GameTypes.Stock.WATER] *= maxi(1, int(state.population / 5.0))
		var building_scale: float = 1.0
		if card.building != null:
			building_scale += state.buildings[card.building.id] * 0.25
			for key: int in GameTypes.Stock.COUNT:
				if key != GameTypes.Stock.STAMINA:
					totals[key] = ceili(totals[key] * building_scale)
		var multiplier: float = state.catalog.library.workforce_rules.stamina_multiplier(
			card.profession, state.profession_counts
		)
		totals[GameTypes.Stock.STAMINA] = ceili(
			(
				totals[GameTypes.Stock.STAMINA]
				* building_scale
				* multiplier
				* LaborRules.cost_multiplier(state, card)
			)
		)
	return totals


static func resource_deltas(
	state: VillageState,
	card: CardDefinition,
	pay_costs: bool = true,
) -> PackedInt32Array:
	var deltas: PackedInt32Array = []
	deltas.resize(GameTypes.Stock.COUNT)
	if pay_costs:
		var totals: PackedInt32Array = cost_totals(card, state)
		for key: int in GameTypes.Stock.COUNT:
			deltas[key] = -totals[key]
	for effect: CardEffect in card.effects:
		if effect.type != CardEffect.Type.RESOURCE:
			continue
		if effect.required_building != null and state.buildings[effect.required_building.id] == 0:
			continue
		ProgressionEconomy.effect_delta(state, card, effect, deltas)
	return deltas


static func construction_error(state: VillageState, card: CardDefinition) -> String:
	if card.vent and state.progress.frustration == 0:
		return "需要至少 1 层烦躁"
	if not card.regions.is_empty() and not card.regions.has(state.progress.region):
		return "当前地图无法使用这张卡"
	if (
		card.expedition
		and state.progress.region != GameTypes.Region.LEGACY
		and not LaborRules.renewable_fallback(state, card)
	):
		if (
			state.progress.deposits[LaborRules.deposit_index(card)]
			< LaborRules.crew_size(state, card)
		):
			return "资源点余量不足，请缩小队伍或远征交易"
	var levels: PackedInt32Array = state.buildings.duplicate()
	var population: int = state.population
	for effect: CardEffect in card.effects:
		if effect.required_building != null and state.buildings[effect.required_building.id] == 0:
			continue
		if effect.type in [CardEffect.Type.BUILD, CardEffect.Type.DRILL]:
			levels[effect.building.id] += int(effect.amount)
			if levels[effect.building.id] > effect.building.max_level:
				return "该建筑已达到最高等级"
		if effect.type == CardEffect.Type.POPULATION:
			population += int(effect.amount)
	if population <= 0:
		return "卡牌不能移除全部幸存者"
	return ""


static func _accumulate(
	stats: VillageStats, multipliers: PackedFloat64Array, modifier: StatModifier, level: int
) -> void:
	match modifier.operation:
		StatModifier.Operation.ADD:
			stats.values[modifier.key] += modifier.amount * level
		StatModifier.Operation.MULTIPLY:
			multipliers[modifier.key] *= pow(modifier.amount, level)


static func _compare_synergies(a: BuildingDefinition, b: BuildingDefinition) -> bool:
	if a.synergy.priority == b.synergy.priority:
		return a.id < b.id
	return a.synergy.priority < b.synergy.priority
