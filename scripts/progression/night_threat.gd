class_name NightThreat
extends RefCounted
## 统一黄昏威胁与环境生命周期；查询只读，生产噪声计入当晚，不留到翌日。


static func derive(state: VillageState, stats: VillageStats) -> void:
	var rules: NightThreatRules = state.catalog.library.progression_rules.night_threat
	var explored: int = maxi(0, state.progress.explored_cells.size() - 1)
	var development: int = development_score(state)
	var noise: int = state.resources[GameTypes.Stock.NOISE] + stats.income[GameTypes.Stock.NOISE]
	var pollution: int = mini(rules.pollution_cap, state.resources[GameTypes.Stock.POLLUTION])
	var pressure: float = (
		rules.base_budget
		+ _contribution(explored, rules.exploration_half, rules.exploration_weight)
		+ _contribution(development, rules.development_half, rules.development_weight)
		+ _contribution(noise, rules.noise_half, rules.noise_weight)
		+ _contribution(pollution, rules.pollution_half, rules.pollution_weight)
	)
	var exposure: float = pressure
	stats.concealed = state.progress.concealed and not stats.torch and not stats.lights_active
	if stats.concealed:
		if (
			noise <= rules.conceal_noise_limit
			and explored <= rules.conceal_exploration_limit
			and development <= rules.conceal_development_limit
			and pollution <= rules.conceal_noise_limit
		):
			pressure = 0
		else:
			pressure *= rules.conceal_multiplier
	stats.threat_budget = maxi(0, roundi(pressure * stats.wave_size))
	stats.threat_level = clampf(
		(
			pressure
			/ float(
				maxi(
					1,
					(
						rules.base_budget
						+ rules.exploration_weight
						+ rules.development_weight
						+ rules.noise_weight
						+ rules.pollution_weight
					)
				)
			)
		),
		0.0,
		1.0
	)
	stats.boss_possible = (
		exposure >= rules.boss_budget and development >= rules.boss_development and explored >= 12
	)


static func development_score(state: VillageState) -> int:
	var score: int = 0
	for key: int in GameTypes.Building.COUNT:
		if key not in [GameTypes.Building.CORE, GameTypes.Building.HUT]:
			score += state.buildings[key]
	return score


static func start_day(state: VillageState) -> void:
	state.resources[GameTypes.Stock.NOISE] = 0
	var rules: NightThreatRules = state.catalog.library.progression_rules.night_threat
	var map: MapDefinition = state.catalog.library.progression_rules.map_for(state.progress.region)
	state.resources[GameTypes.Stock.POLLUTION] = clampi(
		state.resources[GameTypes.Stock.POLLUTION] - map.pollution_recovery, 0, rules.pollution_cap
	)
	state.progress.concealed = false


static func valid_rules(rules: NightThreatRules) -> bool:
	if rules == null or rules.base_budget < 0 or rules.base_budget > 30:
		return false
	for value: int in [
		rules.exploration_weight,
		rules.development_weight,
		rules.noise_weight,
		rules.pollution_weight,
		rules.exploration_half,
		rules.development_half,
		rules.noise_half,
		rules.pollution_half
	]:
		if value < 1 or value > 100:
			return false
	return (
		rules.pollution_cap >= 1
		and rules.pollution_cap <= GameTypes.STOCK_LIMITS[GameTypes.Stock.POLLUTION]
		and rules.conceal_noise_limit >= 0
		and rules.conceal_noise_limit <= 30
		and rules.conceal_exploration_limit >= 0
		and rules.conceal_exploration_limit <= 30
		and rules.conceal_development_limit >= 0
		and rules.conceal_development_limit <= 30
		and is_finite(rules.conceal_multiplier)
		and rules.conceal_multiplier >= 0.1
		and rules.conceal_multiplier <= 1.0
		and rules.boss_budget >= 1
		and rules.boss_budget <= 200
		and rules.boss_development >= 1
		and rules.boss_development <= 100
		and is_finite(rules.boss_chance)
		and rules.boss_chance >= 0
		and rules.boss_chance <= 1
	)


static func _contribution(amount: int, half: int, weight: int) -> float:
	return weight * float(maxi(0, amount)) / (maxi(0, amount) + float(half))
