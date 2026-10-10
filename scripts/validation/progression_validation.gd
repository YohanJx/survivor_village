class_name ProgressionValidation
extends RefCounted
## 扩展资源与存档对象图校验，不修改被检验对象。


static func rules_error(rules: ProgressionRules, buildings: Array[BuildingDefinition]) -> String:
	if rules == null or not is_finite(rules.frustration_cost) or rules.frustration_cost < 0:
		return "发展规则缺失或费用非法"
	if rules.max_frustration != 5 or rules.max_crew != 4:
		return "发展上限与规则不一致"
	var combat: String = combat_error(rules)
	if not combat.is_empty():
		return combat
	var maps: Dictionary[int, bool] = {}
	for definition: MapDefinition in rules.maps:
		if (
			definition == null
			or definition.kind < 0
			or definition.kind >= GameTypes.Region.COUNT
			or maps.has(definition.kind)
		):
			return "地图定义缺失或重复"
		maps[definition.kind] = true
		if (
			definition.display_name.is_empty()
			or definition.initial_resources.size() != GameTypes.Stock.COUNT
			or definition.abundance.size() != GameTypes.Stock.COUNT
		):
			return "地图库存或丰度不完整"
		for key: int in GameTypes.Stock.COUNT:
			if (
				definition.initial_resources[key] < 0
				or definition.initial_resources[key] > GameTypes.STOCK_LIMITS[key]
			):
				return "地图库存非法"
			if not is_finite(definition.abundance[key]) or definition.abundance[key] <= 0:
				return "地图丰度非法"
		for area: Rect2i in definition.barriers:
			if (
				area.size.x <= 0
				or area.size.y <= 0
				or not Rect2i(Vector2i.ZERO, WorldLayout.GRID).encloses(area)
			):
				return "地图障碍越界"
			if area.intersects(Rect2i(12, 4, 17, 17)):
				return "地图障碍侵入村庄设施区域"
	if maps.size() != GameTypes.Region.COUNT:
		return "地图注册不完整"
	var ids: Dictionary[String, bool] = {}
	for event: DailyEvent in rules.events:
		if (
			event == null
			or event.id.is_empty()
			or ids.has(event.id)
			or event.display_name.is_empty()
			or event.weight < 1
		):
			return "每日事件缺失或重复"
		ids[event.id] = true
		if event.options.size() != 2 or event.labor < 0 or event.labor >= GameTypes.Labor.COUNT:
			return "每日事件选项或劳动非法"
		if (
			not is_finite(event.output_multiplier)
			or event.output_multiplier <= 0
			or not is_finite(event.cost_multiplier)
			or event.cost_multiplier <= 0
		):
			return "每日事件倍率非法"
		for region: int in event.regions:
			if region < 0 or region >= GameTypes.Region.COUNT:
				return "事件地图条件非法"
		for stock: int in event.output_stocks:
			if stock < 0 or stock >= GameTypes.Stock.COUNT:
				return "事件产出类型非法"
		for option: CardDefinition in event.options:
			var error: String = ResourceValidation.card_error(option, buildings)
			if not error.is_empty():
				return error
		if not event.options[1].costs.is_empty():
			return "每日事件必须有无费用退路"
	return "" if not rules.events.is_empty() else "每日事件池为空"


static func valid_progress(data: VillageSaveData, catalog: CardCatalog) -> bool:
	var progress: VillageProgress = data.progress
	if progress == null or catalog.library.progression_rules.map_for(progress.region) == null:
		return false
	if (
		progress.frustration < 0
		or progress.frustration > 5
		or progress.last_labor < 0
		or progress.last_labor >= GameTypes.Labor.COUNT
	):
		return false
	if (
		progress.streak < 0
		or progress.crew < 0
		or progress.crew > 4
		or progress.chant_uses < 0
		or progress.chant_uses > 2
	):
		return false
	if (progress.last_labor == GameTypes.Labor.NONE) != (progress.streak == 0):
		return false
	if progress.strategies.size() != GameTypes.Strategy.COUNT or progress.deposits.size() != 3:
		return false
	for flag: int in progress.strategies:
		if flag not in [0, 1]:
			return false
	for amount: int in progress.deposits:
		if amount < 0 or amount > 400:
			return false
	var event: DailyEvent = catalog.library.progression_rules.event_for(progress.event_id)
	if (
		progress.event_id.is_empty()
		and (progress.region != GameTypes.Region.LEGACY or progress.event_choice != 1)
	):
		return false
	if not progress.event_id.is_empty() and event == null:
		return false
	if progress.event_choice < -1 or progress.event_choice > 1 or progress.recent_events.size() > 2:
		return false
	for id: String in progress.recent_events:
		if catalog.library.progression_rules.event_for(id) == null:
			return false
	if event != null and not event.regions.is_empty() and not event.regions.has(progress.region):
		return false
	if data.phase != GameTypes.Phase.DAY and progress.event_choice < 0:
		return false
	if progress.survivors.size() != data.population or progress.next_person_id < 1:
		return false
	var ids: Dictionary[int, bool] = {}
	var counts: PackedInt32Array = []
	counts.resize(GameTypes.Profession.COUNT)
	for person: SurvivorRecord in progress.survivors:
		if (
			person == null
			or person.id < 1
			or person.id >= progress.next_person_id
			or ids.has(person.id)
		):
			return false
		if person.profession < 0 or person.profession >= GameTypes.Profession.COUNT:
			return false
		ids[person.id] = true
		counts[person.profession] += 1
	return counts == data.profession_counts


static func valid_battle_result(state: VillageState, report: BattleReport) -> bool:
	if report.started_survivors != state.population:
		return false
	if (
		state.night_stats != null
		and state.night_stats.modern_combat
		and report.consumed.size() != GameTypes.Stock.COUNT
	):
		return false
	if report.consumed.size() not in [0, GameTypes.Stock.COUNT]:
		return false
	for key: int in report.consumed.size():
		if report.consumed[key] < 0 or report.consumed[key] > state.resources[key]:
			return false
	if not report.has_identities:
		return state.night_stats == null or not state.night_stats.modern_combat
	if report.survivor_ids.size() != report.survivors:
		return false
	var available: Dictionary[int, bool] = {}
	for person: SurvivorRecord in state.progress.survivors:
		available[person.id] = true
	for id: int in report.survivor_ids:
		if not available.has(id):
			return false
		available.erase(id)
	return true


static func combat_error(rules: ProgressionRules) -> String:
	if rules.units.size() != GameTypes.Unit.COUNT or rules.enemies.size() != GameTypes.Enemy.COUNT:
		return "单位定义注册不完整"
	for index: int in rules.units.size():
		var unit: UnitDefinition = rules.units[index]
		if unit == null or unit.kind != index:
			return "职业单位定义不完整"
		for value: float in [
			unit.attack_multiplier,
			unit.health_multiplier,
			unit.speed_multiplier,
			unit.range_multiplier,
			unit.range_limit,
			unit.support_interval
		]:
			if not is_finite(value) or value <= 0:
				return "职业单位参数非法"
	for index: int in rules.enemies.size():
		var enemy: EnemyDefinition = rules.enemies[index]
		if enemy == null or enemy.kind != index or enemy.threat_cost < 1 or enemy.threat_cost > 10:
			return "敌人定义不完整"
		for value: float in [
			enemy.health_multiplier,
			enemy.speed_multiplier,
			enemy.damage_multiplier,
			enemy.attack_range,
			enemy.summon_interval
		]:
			if not is_finite(value) or value <= 0:
				return "敌人参数非法"
		if (
			not is_finite(enemy.armor)
			or enemy.armor < 0
			or not is_finite(enemy.fire_radius)
			or enemy.fire_radius < 0
			or enemy.summon_limit < 0
			or enemy.summon_limit > 4
		):
			return "敌人特殊参数非法"
	return ""


static func valid_frozen_roster(data: VillageSaveData) -> bool:
	if (
		data.night_stats == null
		or data.phase not in [GameTypes.Phase.NIGHT, GameTypes.Phase.REWARD]
	):
		return true
	var stats: VillageStats = data.night_stats
	if stats.modern_combat != (data.progress.region != GameTypes.Region.LEGACY):
		return false
	if not stats.modern_combat:
		return true
	if stats.supplies.size() != GameTypes.Stock.COUNT or stats.roster.size() < data.population:
		return false
	if data.phase == GameTypes.Phase.NIGHT:
		if stats.roster.size() != data.population:
			return false
		for index: int in stats.roster.size():
			var frozen: SurvivorRecord = stats.roster[index]
			var current: SurvivorRecord = data.progress.survivors[index]
			if (
				frozen.id != current.id
				or frozen.profession != current.profession
				or frozen.archer != current.archer
			):
				return false
	if data.phase == GameTypes.Phase.REWARD:
		var report: BattleReport = data.last_report
		if (
			report == null
			or not report.has_identities
			or stats.roster.size() != report.started_survivors
		):
			return false
		if report.consumed.size() != GameTypes.Stock.COUNT:
			return false
		for key: int in GameTypes.Stock.COUNT:
			if report.consumed[key] > stats.supplies[key]:
				return false
		var originals: Dictionary[int, SurvivorRecord] = {}
		for person: SurvivorRecord in stats.roster:
			if person.id >= data.progress.next_person_id:
				return false
			originals[person.id] = person
		for person: SurvivorRecord in data.progress.survivors:
			if not report.survivor_ids.has(person.id) or not originals.has(person.id):
				return false
			var original: SurvivorRecord = originals[person.id]
			if original.profession != person.profession or original.archer != person.archer:
				return false

	return true
