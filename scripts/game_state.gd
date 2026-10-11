class_name VillageState
extends RefCounted

signal changed

signal persistence_failed(message: String)

signal phase_changed(phase: GameTypes.Phase)

const SAVE_PATH: String = "user://village_save.tres"
const SAVE_VERSION: int = VillageSaveData.CURRENT_VERSION
const SLOT_NAMES: PackedStringArray = ["清晨", "午后", "黄昏"]
var terrain_grid: TerrainGrid = TerrainGrid.new()
var progress: VillageProgress = VillageProgress.new()
var catalog: CardCatalog = CardCatalog.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var run_seed: int = 0
var day: int = 1
var weather: WeatherDefinition
var slot: int = 0
var actions_used: int = 0
var actions_per_slot: int = 1
var phase: GameTypes.Phase = GameTypes.Phase.DAY
var resources: PackedInt32Array = []
var profession_counts: PackedInt32Array = []
var population: int = 5:
	set(value):
		population = value
		if catalog.is_valid:
			profession_counts = catalog.library.workforce_rules.resized_roster(
				profession_counts, value
			)
var core_health: float = 240.0
var core_max_health: float = 240.0
var buildings: PackedInt32Array = []
var modifiers: Array[StatModifier] = []
var hand: Array[CardInstance] = []
var rewards: Array[CardDefinition] = []
var history: Array[VillageLogEntry] = []
var wall_damage: Dictionary[Vector2i, float] = {}
var night_stats: VillageStats
var last_report: BattleReport
var next_uid: int = 1
var total_kills: int = 0
var persistence_enabled: bool = true
var save_path: String = SAVE_PATH
var last_error: String = ""
var _publishing_changes: bool = false


func new_run(seed_value: int = 0, region: GameTypes.Region = GameTypes.Region.LEGACY) -> void:
	if _publishing_changes:
		return
	if not catalog.is_valid:
		last_error = catalog.validation_error
		return
	if catalog.library.progression_rules.map_for(region) == null:
		last_error = "地图定义缺失"
		return
	progress = VillageProgress.new()
	progress.region = region
	last_error = ""
	run_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	rng.seed = run_seed
	terrain_grid.generate(run_seed, catalog.library.progression_rules.map_for(region))
	progress.explored_cells = PackedInt32Array([TerrainGrid.index(TerrainGrid.CAMP)])
	day = 1
	weather = catalog.library.weather_rules.for_day(run_seed, day)
	slot = 0
	actions_used = 0
	actions_per_slot = catalog.library.workforce_rules.action_capacity(5)
	profession_counts = catalog.library.workforce_rules.initial_roster.duplicate()
	phase = GameTypes.Phase.DAY
	population = 5
	core_health = core_max_health
	resources = catalog.library.progression_rules.map_for(region).initial_resources.duplicate()
	buildings.resize(GameTypes.Building.COUNT)
	buildings.fill(0)
	modifiers.clear()
	hand.clear()
	rewards.clear()
	history.clear()
	wall_damage.clear()
	night_stats = null
	last_report = null
	next_uid = 1
	total_kills = 0
	SurvivalRules.grant_available(self)
	PopulationRules.reconcile(self)
	ProgressionEconomy.start_day(self)
	log_event("五位幸存者在村庄落脚。第一天只勘探地形，随身补给供今日使用。")
	_publish_changes(true)


func add_card(definition: CardDefinition) -> void:
	if definition != null:
		hand.append(CardInstance.new(definition, next_uid))
		next_uid += 1


func find_card(uid: int) -> CardDefinition:
	for entry: CardInstance in hand:
		if entry.uid == uid:
			return entry.definition
	return null


func can_play(uid: int) -> String:
	if not catalog.is_valid:
		return catalog.validation_error
	if phase != GameTypes.Phase.DAY:
		return "只能在白天使用卡牌"
	if progress.event_choice < 0:
		return "请先确认今日事件"
	var card: CardDefinition = find_card(uid)
	if card == null:
		return "这张卡已不在手牌中"
	var configuration_error: String = ResourceValidation.card_error(card, catalog.buildings)
	if not configuration_error.is_empty():
		return configuration_error
	var unlock_error: String = SurvivalRules.unlock_error(self, card)
	if not unlock_error.is_empty():
		return unlock_error
	if card.building != null and buildings[card.building.id] >= card.building.max_level:
		return "该建筑已达到最高等级"
	if SurvivalRules.is_survey(card):
		var target_error: String = exploration_error()
		if not target_error.is_empty():
			return target_error
	var build_error: String = EffectResolver.construction_error(self, card)
	if not build_error.is_empty():
		return build_error
	var totals: PackedInt32Array = EffectResolver.cost_totals(card, self)
	for key: int in GameTypes.Stock.COUNT:
		if resources[key] < totals[key]:
			return "%s不足：需要 %d，现有 %d" % [GameTypes.STOCK_NAMES[key], totals[key], resources[key]]
	var deltas: PackedInt32Array = EffectResolver.resource_deltas(self, card)
	for key: int in GameTypes.Stock.COUNT:
		if key in [GameTypes.Stock.NOISE, GameTypes.Stock.POLLUTION]:
			continue
		if resources[key] + deltas[key] < 0:
			return "%s不足以支付这张卡的全部效果" % GameTypes.STOCK_NAMES[key]
	return ""


func play_card(uid: int) -> bool:
	if _publishing_changes:
		return false
	if not can_play(uid).is_empty():
		return false
	var card: CardDefinition = find_card(uid)
	var previous_level: int = buildings[card.building.id] if card.building != null else -1
	EffectResolver.apply(self, card, true)
	var completed: bool = card.building == null or buildings[card.building.id] > previous_level
	if completed and not progress.completed_cards.has(card.id):
		progress.completed_cards.append(card.id)
	log_event("%s · %s：%s；%s" % [SLOT_NAMES[slot], card.display_name, card.positive, card.negative])
	if not card.reusable:
		for i: int in hand.size():
			if hand[i].uid == uid:
				hand.remove_at(i)
				break
	SurvivalRules.grant_available(self)
	_advance_slot()
	return true


func skip_slot() -> void:
	if _publishing_changes:
		return
	if phase != GameTypes.Phase.DAY or progress.event_choice < 0:
		return
	progress.frustration = maxi(0, progress.frustration - 1)
	progress.last_labor = GameTypes.Labor.NONE
	progress.streak = 0
	add_resource(GameTypes.Stock.STAMINA, 8)
	log_event("%s · 原地待命，体力 +8。" % SLOT_NAMES[slot])
	_advance_slot()


func begin_night() -> void:
	if _publishing_changes:
		return
	if phase != GameTypes.Phase.DAY or progress.event_choice < 0:
		return
	PopulationRules.reconcile(self)
	slot = 3
	actions_used = 0
	night_stats = EffectResolver.derive(self)
	add_resource(GameTypes.Stock.POWER, -night_stats.upkeep[GameTypes.Stock.POWER])
	phase = GameTypes.Phase.NIGHT
	log_event("夜幕降临%s，幸存者开始自动防守。" % [" · 第七日大尸潮" if day % 7 == 0 else ""])
	_publish_changes(true)


func finish_night(report: BattleReport) -> void:
	if _publishing_changes:
		return
	if not SaveValidation.valid_report(report, core_max_health):
		last_error = "无效战报"
		return
	if phase != GameTypes.Phase.NIGHT:
		return
	if not ProgressionValidation.valid_battle_result(self, report):
		last_error = "战报身份或耗材不属于本次黄昏"
		return
	last_report = report.copy_snapshot()
	core_health = maxf(0.0, report.core_health)
	if report.has_identities:
		PopulationRules.surviving_roster(self, report.survivor_ids)
	else:
		population = report.survivors
		PopulationRules.reconcile(self)
	for key: int in report.consumed.size():
		add_resource(key as GameTypes.Stock, -report.consumed[key])
	wall_damage = report.wall_damage.duplicate()
	total_kills += report.kills
	if core_health <= 0.0 or population <= 0:
		phase = GameTypes.Phase.GAME_OVER
		log_event("防线失守。村庄坚持了 %d 天，击退 %d 名感染者。" % [day, total_kills])
	else:
		phase = GameTypes.Phase.REWARD
		add_resource(
			(
				GameTypes.Stock.MATERIALS
				if progress.region == GameTypes.Region.LEGACY
				else GameTypes.Stock.PARTS
			),
			3 + int(report.kills / 5.0)
		)
		generate_rewards()
		if rewards.is_empty():
			advance_dawn()
			return
		log_event(
			(
				"守住第 %d 夜！击退 %d，幸存 %d / %d。选择一份新的发展机会。"
				% [day, report.kills, population, report.started_survivors]
			)
		)
	_publish_changes(true)
	autosave()


func generate_rewards() -> void:
	rewards.clear()
	var pool: Array[CardDefinition] = []
	for card: CardDefinition in catalog.library.cards:
		if card.reusable or card.guaranteed_unlock:
			continue
		if not SurvivalRules.unlock_error(self, card, day + 1).is_empty():
			continue
		if not card.regions.is_empty() and not card.regions.has(progress.region):
			continue
		if card.building != null and buildings[card.building.id] >= card.building.max_level:
			continue
		pool.append(card)
	while rewards.size() < 3 and not pool.is_empty():
		var index: int = rng.randi_range(0, pool.size() - 1)
		rewards.append(pool[index])
		pool.remove_at(index)


func choose_reward(index: int) -> bool:
	if _publishing_changes:
		return false
	if phase != GameTypes.Phase.REWARD or index < 0 or index >= rewards.size():
		return false
	var definition: CardDefinition = rewards[index]
	add_card(definition)
	log_event("获得卡牌：%s。" % definition.display_name)
	rewards.clear()
	advance_dawn()
	return true


func advance_dawn() -> void:
	if _publishing_changes:
		return
	if phase != GameTypes.Phase.REWARD or not rewards.is_empty():
		return
	EffectResolver.expire_after_night(self)
	var shortage: int = 0
	var daily_upkeep: PackedInt32Array = EffectResolver.daily_upkeep(self)
	for key: int in [
		GameTypes.Stock.FOOD,
		GameTypes.Stock.WATER,
		GameTypes.Stock.MATERIALS,
		GameTypes.Stock.WOOD,
		GameTypes.Stock.STONE,
		GameTypes.Stock.PARTS,
		GameTypes.Stock.FUEL,
		GameTypes.Stock.ARROWS,
		GameTypes.Stock.MEDICINE
	]:
		var upkeep: int = daily_upkeep[key]
		var balance: int = resources[key] + night_stats.income[key] - upkeep
		if balance < 0 and key in [GameTypes.Stock.FOOD, GameTypes.Stock.WATER]:
			shortage -= balance
		resources[key] = clampi(balance, 0, GameTypes.STOCK_LIMITS[key])
	add_resource(GameTypes.Stock.POWER, night_stats.income[GameTypes.Stock.POWER])
	add_resource(GameTypes.Stock.NOISE, night_stats.income[GameTypes.Stock.NOISE] - 3)
	add_resource(GameTypes.Stock.POLLUTION, night_stats.income[GameTypes.Stock.POLLUTION])
	add_resource(GameTypes.Stock.STAMINA, night_stats.stamina_recovery - shortage * 2)
	if night_stats.clinic_active:
		core_health = minf(core_max_health, core_health + 15)
	if shortage > 0:
		core_health = maxf(0, core_health - shortage * 3)
		log_event("补给短缺 %d：村庄耐久 -%d，恢复体力减少。" % [shortage, shortage * 3])
	SurvivalRules.close_day(self)
	day += 1
	weather = catalog.library.weather_rules.for_day(run_seed, day)
	slot = 0
	actions_used = 0
	actions_per_slot = catalog.library.workforce_rules.action_capacity(population)
	phase = GameTypes.Phase.DAY if core_health > 0 else GameTypes.Phase.GAME_OVER
	ProgressionEconomy.start_day(self)
	SurvivalRules.grant_available(self)
	log_event("第 %d 日清晨：结算生产与消耗，体力恢复。" % day)
	log_event("今日天气：%s。%s" % [weather.display_name, weather.description])
	_publish_changes(true)
	autosave()


func add_resource(key: GameTypes.Stock, amount: int) -> void:
	resources[key] = clampi(resources[key] + amount, 0, GameTypes.STOCK_LIMITS[key])


func environment_period() -> int:
	return slot if phase == GameTypes.Phase.DAY else 3


func log_event(message: String) -> void:
	history.push_front(VillageLogEntry.new(day, message))
	if history.size() > 40:
		history.resize(40)


func wave_count() -> int:
	var stats: VillageStats = (
		night_stats if phase == GameTypes.Phase.NIGHT else EffectResolver.derive(self)
	)
	var base: int = 8 + day * 3 + int(resources[GameTypes.Stock.NOISE] / 4.0)
	if day % 7 == 0:
		base = int(base * 1.45)
	return maxi(4, int(base * stats.wave_size))


func preview_card(card: CardDefinition) -> VillageStats:
	var preview_state: VillageState = VillageState.new()
	preview_state.persistence_enabled = false
	if not preview_state.restore(snapshot()):
		return EffectResolver.derive(self)
	EffectResolver.apply(preview_state, card, true, true)
	return EffectResolver.derive(preview_state)


func snapshot() -> VillageSaveData:
	var data: VillageSaveData = VillageSaveData.new()
	data.progress = progress.copy_progress()
	PopulationRules.reconcile_progress(data.progress, population, profession_counts)
	data.version = SAVE_VERSION
	data.run_seed = run_seed
	data.rng_state = rng.state
	data.day = day
	data.weather_kind = weather.kind
	data.slot = slot
	data.actions_used = actions_used
	data.actions_per_slot = actions_per_slot
	data.profession_counts = profession_counts.duplicate()
	data.phase = phase
	data.resources = resources.duplicate()
	data.population = population
	data.core_health = core_health
	data.buildings = buildings.duplicate()
	for modifier: StatModifier in modifiers:
		data.modifiers.append(modifier.copy_runtime())
	for instance: CardInstance in hand:
		data.hand.append(CardInstance.new(instance.definition, instance.uid))
	data.rewards = rewards.duplicate()
	for entry: VillageLogEntry in history:
		data.history.append(VillageLogEntry.new(entry.day, entry.text))
	data.wall_damage = wall_damage.duplicate()
	data.night_stats = night_stats.copy_snapshot() if night_stats != null else null
	data.last_report = last_report.copy_snapshot() if last_report != null else null
	data.next_uid = next_uid
	data.total_kills = total_kills
	return data


func restore(data: VillageSaveData) -> bool:
	if _publishing_changes:
		return false
	if not SaveValidation.is_valid(data, catalog, core_max_health):
		last_error = "存档格式、数据或资源引用不兼容"
		return false
	last_error = ""
	run_seed = data.run_seed
	rng.seed = run_seed
	rng.state = data.rng_state
	day = data.day
	weather = catalog.library.weather_rules.for_kind(
		data.weather_kind if data.version >= 4 else WeatherDefinition.Kind.CLEAR
	)
	slot = data.slot
	actions_used = data.actions_used if data.version >= VillageSaveData.WORKFORCE_VERSION else 0
	actions_per_slot = (
		data.actions_per_slot if data.version >= VillageSaveData.WORKFORCE_VERSION else 1
	)
	phase = data.phase
	resources = data.resources.duplicate()
	resources.resize(GameTypes.Stock.COUNT)
	progress = data.progress.copy_progress() if data.version >= 5 else VillageProgress.new()
	population = data.population
	profession_counts = (
		data.profession_counts.duplicate()
		if data.version >= VillageSaveData.WORKFORCE_VERSION
		else catalog.library.workforce_rules.resized_roster(
			catalog.library.workforce_rules.initial_roster, population
		)
	)
	core_health = data.core_health
	buildings = data.buildings.duplicate()
	buildings.resize(GameTypes.Building.COUNT)
	modifiers.clear()
	for modifier: StatModifier in data.modifiers:
		modifiers.append(modifier.copy_runtime())
	hand.clear()
	for instance: CardInstance in data.hand:
		hand.append(CardInstance.new(catalog.get_card(instance.definition.id), instance.uid))
	rewards.clear()
	for definition: CardDefinition in data.rewards:
		rewards.append(catalog.get_card(definition.id))
	history.clear()
	for entry: VillageLogEntry in data.history:
		history.append(VillageLogEntry.new(entry.day, entry.text))
	wall_damage = data.wall_damage.duplicate()
	night_stats = data.night_stats.copy_snapshot() if data.night_stats != null else null
	last_report = data.last_report.copy_snapshot() if data.last_report != null else null
	next_uid = data.next_uid
	total_kills = data.total_kills
	if data.version < 5:
		progress.event_choice = 1
		PopulationRules.reconcile(self)
	if data.version < 6:
		progress.terrain_surveys = 3
		progress.discoveries = (
			catalog.library.progression_rules.map_for(progress.region).discoveries.duplicate()
		)
		progress.well_tools = buildings[GameTypes.Building.WELL] > 0
		progress.well_surveys = 1 if progress.well_tools else 0
		for entry: CardInstance in hand:
			if not progress.granted_cards.has(entry.definition.id):
				progress.granted_cards.append(entry.definition.id)
	terrain_grid.generate(run_seed, catalog.library.progression_rules.map_for(progress.region))
	if data.version < 7:
		TerrainGrid.migrate_progress(progress, terrain_grid)
		SurvivalRules.migrate_completions(self)
	ProgressionEconomy.expand_snapshot(night_stats)
	_publish_changes(true)
	return true


func choose_daily_event(index: int) -> bool:
	if _publishing_changes or phase != GameTypes.Phase.DAY or progress.event_choice >= 0:
		return false
	var event: DailyEvent = LaborRules.event_for(self)
	if event == null or index < 0 or index >= event.options.size():
		return false
	var card: CardDefinition = event.options[index]
	if not EffectResolver.construction_error(self, card).is_empty():
		return false
	var costs: PackedInt32Array = EffectResolver.cost_totals(card, self)
	var deltas: PackedInt32Array = EffectResolver.resource_deltas(self, card)
	for key: int in GameTypes.Stock.COUNT:
		if resources[key] < costs[key] or resources[key] + deltas[key] < 0:
			return false
	EffectResolver.apply(self, card, true)
	progress.event_choice = index
	progress.scouting = event.id == "scream" and index == 0
	log_event("今日事件：%s · %s" % [event.display_name, card.display_name])
	_publish_changes(false)
	autosave()
	return true


func set_crew(size: int) -> bool:
	if (
		_publishing_changes
		or phase != GameTypes.Phase.DAY
		or size < 0
		or size > mini(4, maxi(1, int(population / 5.0)))
	):
		return false
	progress.crew = size
	_publish_changes(false)
	autosave()
	return true


func assign_jobs(counts: PackedInt32Array, archers: bool = true) -> bool:
	if (
		_publishing_changes
		or phase != GameTypes.Phase.DAY
		or slot != 0
		or actions_used != 0
		or progress.assigned_today
	):
		return false
	if not catalog.library.workforce_rules.valid_roster(counts, population):
		return false
	profession_counts = counts.duplicate()
	PopulationRules.reconcile(self)
	for person: SurvivorRecord in progress.survivors:
		person.archer = archers
	progress.assigned_today = true
	SurvivalRules.grant_available(self)
	_publish_changes(false)
	autosave()
	return true


func save_game(path: String = "") -> bool:
	path = save_path if path.is_empty() else path
	last_error = ""
	var temporary: String = path.get_basename() + ".tmp.tres"
	var write_error: Error = ResourceSaver.save(snapshot(), temporary)
	if write_error != OK:
		last_error = "写入存档失败：" + error_string(write_error)
		return false
	var replace_error: Error = DirAccess.rename_absolute(temporary, path)
	if replace_error != OK:
		last_error = "替换存档失败：" + error_string(replace_error)
		return false
	return true


func load_game(path: String = "") -> bool:
	path = save_path if path.is_empty() else path
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "没有可用存档"
		return false
	var data: VillageSaveData = (
		ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as VillageSaveData
	)
	return restore(data)


func autosave() -> void:
	if persistence_enabled and not save_game():
		persistence_failed.emit(last_error)


func select_exploration(cell: Vector2i) -> bool:
	if _publishing_changes or phase != GameTypes.Phase.DAY:
		return false
	if not TerrainGrid.is_frontier(cell, progress.explored_cells):
		return false
	progress.exploration_target = TerrainGrid.index(cell)
	_publish_changes(false)
	return true


func exploration_error() -> String:
	if progress.explored_cells.size() == TerrainGrid.SIZE.x * TerrainGrid.SIZE.y:
		return "全部区域已探索"
	if progress.exploration_target < 0:
		return "请在地图上选择与已探索区域毗邻的未知格子"
	if not TerrainGrid.is_frontier(
		TerrainGrid.position(progress.exploration_target), progress.explored_cells
	):
		return "目标必须是与已探索区域毗邻的未知格子"
	return ""


func _advance_slot() -> void:
	actions_used += 1
	if actions_used >= actions_per_slot:
		actions_used = 0
		slot += 1
	if slot == 3:
		begin_night()
	else:
		_publish_changes(false)
	autosave()


func _publish_changes(include_phase: bool) -> void:
	_publishing_changes = true
	if include_phase:
		phase_changed.emit(phase)
	changed.emit()
	_publishing_changes = false
