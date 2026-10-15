class_name ProgressionEconomy
extends RefCounted
## 地图库存映射、生产与每日生命周期；旧材料兼容地图保持原有含义。


static func start_day(state: VillageState) -> void:
	NightThreat.start_day(state)
	var progress: VillageProgress = state.progress
	progress.frustration = maxi(0, progress.frustration - 1)
	progress.last_labor = GameTypes.Labor.NONE
	progress.streak = 0
	progress.strategies.fill(0)
	progress.chant_uses = 0
	progress.low_mood_used = false
	progress.assigned_today = false
	progress.scouting = false
	# 黎明只重置当日状态；遭遇统一在守夜结束后处理。
	progress.event_id = ""
	progress.event_choice = 1


static func expand_snapshot(stats: VillageStats) -> void:
	if stats == null:
		return
	stats.income.resize(GameTypes.Stock.COUNT)
	stats.upkeep.resize(GameTypes.Stock.COUNT)
	stats.supplies.resize(GameTypes.Stock.COUNT)


static func derive(state: VillageState, stats: VillageStats) -> void:
	stats.modern_combat = state.progress.region != GameTypes.Region.LEGACY
	stats.torch = state.progress.strategies[GameTypes.Strategy.TORCH] > 0
	stats.piercing = state.progress.strategies[GameTypes.Strategy.PIERCING] > 0
	for person: SurvivorRecord in state.progress.survivors:
		stats.roster.append(person.copy_record())
	stats.supplies = state.resources.duplicate()
	if state.progress.region == GameTypes.Region.LEGACY:
		return
	stats.income[GameTypes.Stock.PARTS] += stats.income[GameTypes.Stock.MATERIALS]
	stats.income[GameTypes.Stock.MATERIALS] = 0
	stats.upkeep[GameTypes.Stock.PARTS] += maxi(
		0, stats.upkeep[GameTypes.Stock.MATERIALS] - state.buildings[GameTypes.Building.GENERATOR]
	)
	stats.upkeep[GameTypes.Stock.MATERIALS] = 0
	if state.progress.strategies[GameTypes.Strategy.CANAL] > 0:
		var farm_output: int = (
			state.catalog.buildings[GameTypes.Building.FARM].production.food
			* state.buildings[GameTypes.Building.FARM]
		)
		stats.income[GameTypes.Stock.FOOD] += floori(farm_output * 0.25)
		stats.synergies.append("清理沟渠：今日农田产出 +25%，无需电力")
	var fuel: int = state.buildings[GameTypes.Building.GENERATOR] * 2
	if state.resources[GameTypes.Stock.FUEL] < fuel:
		stats.income[GameTypes.Stock.POWER] = 0
		var generator: ProductionProfile = (
			state.catalog.buildings[GameTypes.Building.GENERATOR].production
		)
		stats.income[GameTypes.Stock.NOISE] -= (
			generator.noise * state.buildings[GameTypes.Building.GENERATOR]
		)
		stats.income[GameTypes.Stock.POLLUTION] -= (
			generator.pollution * state.buildings[GameTypes.Building.GENERATOR]
		)
		stats.synergies.append("柴油机缺燃料：不生产电力")
	else:
		stats.upkeep[GameTypes.Stock.FUEL] += fuel
	if state.progress.strategies[GameTypes.Strategy.TORCH] > 0:
		stats.synergies.append("火把：附近潜伏者显形")


static func effect_delta(
	state: VillageState, card: CardDefinition, effect: CardEffect, deltas: PackedInt32Array
) -> void:
	var key: GameTypes.Stock = effect.key
	var amount: int = int(effect.amount)
	var crew: int = LaborRules.crew_size(state, card)
	if state.progress.region != GameTypes.Region.LEGACY and key == GameTypes.Stock.MATERIALS:
		if (
			card.labor == GameTypes.Labor.SALVAGE
			and card.expedition
			and effect.required_building == null
		):
			deltas[GameTypes.Stock.PARTS] += floori(
				(
					(8 + 5 * (crew - 1))
					* LaborRules.output_multiplier(state, card, GameTypes.Stock.PARTS)
				)
			)
			deltas[GameTypes.Stock.WOOD] += floori(
				(
					(4 + 2 * (crew - 1))
					* LaborRules.output_multiplier(state, card, GameTypes.Stock.WOOD)
				)
			)
			return
		key = (
			GameTypes.Stock.PARTS
			if card.labor == GameTypes.Labor.SALVAGE
			else LaborRules.material_key(state, card)
		)
	if card.expedition and effect.required_building == null:
		if key == GameTypes.Stock.NOISE:
			amount += 3 * (crew - 1)
		elif amount > 0 and key not in [GameTypes.Stock.POLLUTION, GameTypes.Stock.STAMINA]:
			amount += card.crew_output * (crew - 1)
	if (
		amount > 0
		and effect.required_building == null
		and key not in [GameTypes.Stock.NOISE, GameTypes.Stock.POLLUTION, GameTypes.Stock.STAMINA]
	):
		amount = floori(amount * LaborRules.output_multiplier(state, card, key))
	if (
		LaborRules.renewable_fallback(state, card)
		and amount > 0
		and key in [GameTypes.Stock.FOOD, GameTypes.Stock.WATER]
	):
		amount = 2
	deltas[key] += amount


static func output_text(state: VillageState, card: CardDefinition) -> String:
	if state.progress.region == GameTypes.Region.LEGACY or not card.expedition:
		return card.positive
	var deltas: PackedInt32Array = EffectResolver.resource_deltas(state, card, false)
	var outputs: PackedStringArray = []
	for key: int in GameTypes.Stock.COUNT:
		if deltas[key] > 0 and key not in [GameTypes.Stock.NOISE, GameTypes.Stock.POLLUTION]:
			outputs.append("%s +%d" % [GameTypes.STOCK_NAMES[key], deltas[key]])
	return "，".join(outputs)
