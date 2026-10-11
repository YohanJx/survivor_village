class_name SaveValidation
extends RefCounted
## 恢复前校验整个对象图，任何失败都不会提交到当前局。


static func is_valid(data: VillageSaveData, catalog: CardCatalog, max_health: float) -> bool:
	if not catalog.is_valid or data == null:
		return false
	if (
		data.version
		not in [
			VillageSaveData.CURRENT_VERSION,
			6,
			5,
			4,
			VillageSaveData.WORKFORCE_VERSION,
			VillageSaveData.LEGACY_VERSION,
		]
	):
		return false
	if data.version >= 4:
		if (
			data.weather_kind < WeatherDefinition.Kind.CLEAR
			or data.weather_kind >= WeatherDefinition.Kind.COUNT
		):
			return false
	if data.version >= VillageSaveData.WORKFORCE_VERSION:
		var rules: WorkforceRules = catalog.library.workforce_rules
		if not rules.valid_roster(data.profession_counts, data.population):
			return false
		if data.actions_per_slot < 1 or data.actions_per_slot > rules.max_actions_per_slot:
			return false
		if data.actions_used < 0 or data.actions_used >= data.actions_per_slot:
			return false
		if data.phase != GameTypes.Phase.DAY and data.actions_used != 0:
			return false
	if data.version >= 5 and not ProgressionValidation.valid_progress(data, catalog):
		return false
	if data.phase < GameTypes.Phase.DAY or data.phase > GameTypes.Phase.GAME_OVER:
		return false
	if data.day < 1 or data.slot < 0 or data.slot > 3 or data.population < 0:
		return false
	if not is_finite(data.core_health) or data.core_health < 0 or data.core_health > max_health:
		return false
	if data.next_uid < 1 or data.total_kills < 0:
		return false
	if data.phase == GameTypes.Phase.DAY and data.slot == 3:
		return false
	if data.phase in [GameTypes.Phase.NIGHT, GameTypes.Phase.REWARD] and data.slot != 3:
		return false
	if data.phase != GameTypes.Phase.GAME_OVER and (data.core_health <= 0 or data.population <= 0):
		return false
	if data.phase == GameTypes.Phase.GAME_OVER and data.core_health > 0 and data.population > 0:
		return false
	if not _valid_inventory(data, catalog) or not _valid_cards(data, catalog):
		return false
	for modifier: StatModifier in data.modifiers:
		if not ResourceValidation.modifier_error(modifier, true).is_empty():
			return false
	if data.history.size() > 40:
		return false
	for entry: VillageLogEntry in data.history:
		if entry == null or entry.day < 1 or entry.day > data.day or entry.text.is_empty():
			return false
	if not valid_walls(data.wall_damage):
		return false
	if data.night_stats != null and not valid_stats(data.night_stats):
		return false
	if data.version >= 5 and not ProgressionValidation.valid_frozen_roster(data):
		return false
	if data.phase in [GameTypes.Phase.NIGHT, GameTypes.Phase.REWARD]:
		if not valid_stats(data.night_stats):
			return false
	if data.last_report != null and not valid_report(data.last_report, max_health):
		return false
	if data.phase == GameTypes.Phase.REWARD:
		if data.last_report == null or data.rewards.is_empty():
			return false
		if data.last_report.survivors != data.population:
			return false
		if not is_equal_approx(data.last_report.core_health, data.core_health):
			return false
	return true


static func valid_stats(stats: VillageStats) -> bool:
	if stats == null or stats.values.size() != GameTypes.Stat.COUNT:
		return false
	if (
		stats.income.size() not in [7, GameTypes.Stock.COUNT]
		or stats.upkeep.size() != stats.income.size()
	):
		return false
	if stats.supplies.size() not in [0, GameTypes.Stock.COUNT]:
		return false
	for key: int in stats.supplies.size():
		if stats.supplies[key] < 0 or stats.supplies[key] > GameTypes.STOCK_LIMITS[key]:
			return false
	var ids: Dictionary[int, bool] = {}
	for person: SurvivorRecord in stats.roster:
		if (
			person == null
			or person.id < 1
			or ids.has(person.id)
			or person.profession < 0
			or person.profession >= GameTypes.Profession.COUNT
		):
			return false
		ids[person.id] = true
	for value: float in stats.values:
		if not is_finite(value):
			return false
	for key: int in [
		GameTypes.Stat.ATTACK,
		GameTypes.Stat.RANGE,
		GameTypes.Stat.COOLDOWN,
		GameTypes.Stat.SPEED,
		GameTypes.Stat.HEALTH,
		GameTypes.Stat.WAVE_SIZE,
	]:
		if stats.values[key] <= 0:
			return false
	for key: int in [
		GameTypes.Stat.BLACKOUT, GameTypes.Stat.WALL_HEALTH, GameTypes.Stat.TRAP_DAMAGE
	]:
		if stats.values[key] < 0:
			return false
	for key: int in stats.income.size():
		if stats.income[key] < 0 or stats.upkeep[key] < 0:
			return false
	return true


static func valid_report(report: BattleReport, max_health: float) -> bool:
	if report == null or report.consumed.size() not in [0, GameTypes.Stock.COUNT]:
		return false
	for amount: int in report.consumed:
		if amount < 0:
			return false
	if report.has_identities:
		if report.survivor_ids.size() != report.survivors:
			return false
		var ids: Dictionary[int, bool] = {}
		for id: int in report.survivor_ids:
			if id < 1 or ids.has(id):
				return false
			ids[id] = true
	return (
		report != null
		and is_finite(report.core_health)
		and report.core_health >= 0
		and report.core_health <= max_health
		and report.survivors >= 0
		and report.started_survivors >= report.survivors
		and report.kills >= 0
		and is_finite(report.duration)
		and report.duration >= 0
		and valid_walls(report.wall_damage)
	)


static func valid_walls(damage: Dictionary[Vector2i, float]) -> bool:
	var wall_cells: Array[Vector2i] = WorldLayout.wall_cells()
	for cell: Vector2i in damage:
		if not wall_cells.has(cell) or not is_finite(damage[cell]) or damage[cell] < 0:
			return false
	return true


static func _valid_inventory(data: VillageSaveData, catalog: CardCatalog) -> bool:
	if (
		data.resources.size() != GameTypes.Stock.COUNT
		and (data.version >= 5 or data.resources.size() != 7)
	):
		return false
	if (
		data.buildings.size() != GameTypes.Building.COUNT
		and (data.version >= 6 or data.buildings.size() != 13)
	):
		return false
	for key: int in data.resources.size():
		if data.resources[key] < 0 or data.resources[key] > GameTypes.STOCK_LIMITS[key]:
			return false
	for building: BuildingDefinition in catalog.buildings:
		if building.id >= data.buildings.size():
			continue
		if data.buildings[building.id] < 0 or data.buildings[building.id] > building.max_level:
			return false
	return true


static func _valid_cards(data: VillageSaveData, catalog: CardCatalog) -> bool:
	var instance_ids: Dictionary[int, bool] = {}
	for entry: CardInstance in data.hand:
		if entry == null or entry.definition == null or not catalog.cards.has(entry.definition.id):
			return false
		if entry.uid <= 0 or instance_ids.has(entry.uid) or data.next_uid <= entry.uid:
			return false
		instance_ids[entry.uid] = true
	if data.rewards.size() > 3:
		return false
	var reward_ids: Dictionary[String, bool] = {}
	for card: CardDefinition in data.rewards:
		if card == null or not catalog.cards.has(card.id) or reward_ids.has(card.id):
			return false
		reward_ids[card.id] = true
	if data.phase != GameTypes.Phase.REWARD and not data.rewards.is_empty():
		return false
	return true
