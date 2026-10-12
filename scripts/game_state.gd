class_name VillageState
extends RefCounted

signal changed

## 完整事务提交后发送新增手牌 UID；新局初始手牌与读档不作为获取。
signal cards_acquired(uids: PackedInt32Array)

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
var day_end_event_id: String = ""
var pending_day_end_events: PackedStringArray = []
var day_end_settled: bool = false
var day_end_effects_expired: bool = false
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
var _pending_card_uids: PackedInt32Array = []


func new_run(seed_value: int = 0, region: GameTypes.Region = GameTypes.Region.LEGACY) -> void:
	if _publishing_changes:
		return
	if not catalog.is_valid:
		last_error = catalog.validation_error
		return
	if catalog.library.progression_rules.map_for(region) == null:
		last_error = "地图定义缺失"
		return
	var requested_seed: int = (
		seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	)
	var selected_seed: int = OpeningRules.viable_seed(
		requested_seed, catalog.library.progression_rules.map_for(region)
	)
	if selected_seed == -1:
		last_error = "未找到可发展的营地，请更换种子或地图"
		return
	progress = VillageProgress.new()
	progress.region = region
	last_error = ""
	run_seed = selected_seed
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
	_pending_card_uids.clear()
	day_end_event_id = ""
	pending_day_end_events.clear()
	day_end_settled = false
	day_end_effects_expired = false
	history.clear()
	wall_damage.clear()
	night_stats = null
	last_report = null
	next_uid = 1
	total_kills = 0
	SurvivalRules.grant_available(self)
	PopulationRules.reconcile(self)
	ProgressionEconomy.start_day(self)
	_pending_card_uids.clear()
	log_event(
		(
			"五位幸存者在村庄落脚。携带食物 %d、水 %d；随身容量各 %d/%d。第一天寻找草甸与林地。"
			% [
				resources[GameTypes.Stock.FOOD],
				resources[GameTypes.Stock.WATER],
				SurvivalRules.storage_capacity(self, GameTypes.Stock.FOOD),
				SurvivalRules.storage_capacity(self, GameTypes.Stock.WATER)
			]
		)
	)
	_publish_changes(true)


## 规则提交阶段加入手牌，获取通知延后到下一次完整状态发布。
func add_card(definition: CardDefinition) -> void:
	if definition != null and not _publishing_changes:
		hand.append(CardInstance.new(definition, next_uid))
		_pending_card_uids.append(next_uid)
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
	if phase != GameTypes.Phase.DAY:
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
	if phase != GameTypes.Phase.DAY:
		return
	PopulationRules.reconcile(self)
	slot = 3
	actions_used = 0
	night_stats = EffectResolver.derive(self)
	add_resource(GameTypes.Stock.POWER, -night_stats.upkeep[GameTypes.Stock.POWER])
	phase = GameTypes.Phase.NIGHT
	log_event("夜幕降临：预计威胁 %d，幸存者在营地岗位驻守。" % wave_count())
	if night_stats.concealed and night_stats.threat_budget == 0:
		log_event("营地熄火隐蔽，今夜未被感染者发现；仍照常结算生产与口粮。")
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
		phase = GameTypes.Phase.DAY_END
		add_resource(
			(
				GameTypes.Stock.MATERIALS
				if progress.region == GameTypes.Region.LEGACY
				else GameTypes.Stock.PARTS
			),
			3 + int(report.kills / 5.0)
		)
		pending_day_end_events = DayEndEvents.queue_for_day(self)
		day_end_settled = false
		day_end_effects_expired = false
		_take_next_day_end_event()
		log_event(
			(
				"守住第 %d 夜！击退 %d，幸存 %d / %d。处理当夜遭遇与补给结算。"
				% [day, report.kills, population, report.started_survivors]
			)
		)
	if phase == GameTypes.Phase.DAY_END and day_end_event_id.is_empty():
		advance_dawn()
	else:
		_publish_changes(true)
		autosave()


## 返回当前待处理的只读原生定义；无事件时返回 null，查询不修改状态。
func current_day_end_event() -> DailyEvent:
	return catalog.library.progression_rules.day_end_event_for(day_end_event_id)


## 仅在日终阶段处理一次；准入失败不扣费、不推进日期或发信号。
## 成功提交当前选项后展示下一事件，队列结束才推进黎明；发 changed/phase_changed 并自动保存。
func choose_day_end_event(index: int) -> bool:
	if _publishing_changes:
		return false
	last_error = DayEndEvents.option_error(self, index)
	if not last_error.is_empty():
		return false
	_settle_day_end(current_day_end_event().options[index])
	return true


## 特殊事件可跳过；普通事件拒绝跳过，无游戏状态副作用。
func skip_day_end_event() -> bool:
	if _publishing_changes or phase != GameTypes.Phase.DAY_END:
		return false
	var event: DailyEvent = current_day_end_event()
	if event == null or not event.skippable:
		return false
	_settle_day_end(null)
	return true


func advance_dawn() -> void:
	if _publishing_changes:
		return
	if phase != GameTypes.Phase.DAY_END or not day_end_event_id.is_empty():
		return
	if not day_end_effects_expired:
		EffectResolver.expire_after_night(self)
		day_end_effects_expired = true
	if not day_end_settled:
		_settle_daily_supplies()
		if core_health <= 0 or population <= 0:
			phase = GameTypes.Phase.GAME_OVER
			day_end_settled = false
			day_end_effects_expired = false
			_publish_changes(true)
			autosave()
			return
		pending_day_end_events = DayEndEvents.queue_for_day(self, true)
		_take_next_day_end_event()
		if not day_end_event_id.is_empty():
			_publish_changes(true)
			autosave()
			return
	day_end_settled = false
	day_end_effects_expired = false
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
	var limit: int = (
		catalog.library.progression_rules.night_threat.pollution_cap
		if key == GameTypes.Stock.POLLUTION
		else GameTypes.STOCK_LIMITS[key]
	)
	resources[key] = clampi(resources[key] + amount, 0, limit)


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
	return stats.threat_budget


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
	data.day_end_event_id = day_end_event_id
	data.pending_day_end_events = pending_day_end_events.duplicate()
	data.day_end_settled = day_end_settled
	data.day_end_effects_expired = day_end_effects_expired
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
	if data.version < VillageSaveData.DAY_END_VERSION:
		progress.recent_day_end_events.clear()
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
	_pending_card_uids.clear()
	for instance: CardInstance in data.hand:
		hand.append(CardInstance.new(catalog.get_card(instance.definition.id), instance.uid))
	day_end_event_id = (
		data.day_end_event_id if data.version >= VillageSaveData.DAY_END_VERSION else ""
	)
	pending_day_end_events = (
		data.pending_day_end_events.duplicate()
		if data.version >= VillageSaveData.EVENT_QUEUE_VERSION
		else PackedStringArray()
	)
	day_end_settled = (
		data.day_end_settled if data.version >= VillageSaveData.EVENT_QUEUE_VERSION else false
	)
	day_end_effects_expired = (
		data.day_end_effects_expired
		if data.version >= VillageSaveData.EVENT_QUEUE_VERSION
		else false
	)
	if data.version < VillageSaveData.EVENT_QUEUE_VERSION:
		progress.hungry_days = 0
		progress.thirsty_days = 0
	history.clear()
	for entry: VillageLogEntry in data.history:
		history.append(VillageLogEntry.new(entry.day, entry.text))
	wall_damage = data.wall_damage.duplicate()
	night_stats = data.night_stats.copy_snapshot() if data.night_stats != null else null
	if data.version < VillageSaveData.THREAT_VERSION and night_stats != null:
		# 旧档当夜规模保持，下一次黄昏才采用新威胁规则。
		var old_budget: int = 8 + day * 3 + int(resources[GameTypes.Stock.NOISE] / 4.0)
		if day % 7 == 0:
			old_budget = int(old_budget * 1.45)
		night_stats.threat_budget = maxi(4, int(old_budget * night_stats.wave_size))
		night_stats.threat_level = clampf(day / 20.0, 0.0, 1.0)
		night_stats.boss_possible = day % 7 == 0
	last_report = data.last_report.copy_snapshot() if data.last_report != null else null
	next_uid = data.next_uid
	total_kills = data.total_kills
	# 旧版尚未选择的黎明事件按原计划继续；已选择的当天效果保持。
	if progress.event_choice < 0:
		progress.event_id = ""
		progress.event_choice = 1
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
	if data.version < VillageSaveData.DAY_END_VERSION and phase == GameTypes.Phase.DAY_END:
		pending_day_end_events = DayEndEvents.queue_for_day(self)
		_take_next_day_end_event()
		if day_end_event_id.is_empty():
			# 旧奖励界面已有待处理机会；保留阶段，读档不结算口粮或写盘。
			day_end_event_id = DayEndEvents.for_legacy_save(self).id
	_publish_changes(true)
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


func _settle_daily_supplies() -> void:
	var shortage: int = 0
	var food_shortage: bool = false
	var water_shortage: bool = false
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
			food_shortage = food_shortage or key == GameTypes.Stock.FOOD
			water_shortage = water_shortage or key == GameTypes.Stock.WATER
		resources[key] = clampi(balance, 0, GameTypes.STOCK_LIMITS[key])
	add_resource(GameTypes.Stock.POWER, night_stats.income[GameTypes.Stock.POWER])
	add_resource(GameTypes.Stock.POLLUTION, night_stats.income[GameTypes.Stock.POLLUTION])
	add_resource(GameTypes.Stock.STAMINA, night_stats.stamina_recovery - shortage * 2)
	if night_stats.clinic_active:
		core_health = minf(core_max_health, core_health + 15)
	if shortage > 0:
		core_health = maxf(0, core_health - shortage * 3)
		log_event("补给短缺 %d：村庄耐久 -%d，恢复体力减少。" % [shortage, shortage * 3])
	SurvivalRules.close_day(self)
	progress.hungry_days = progress.hungry_days + 1 if food_shortage else 0
	progress.thirsty_days = progress.thirsty_days + 1 if water_shortage else 0
	day_end_settled = true


func _settle_day_end(option: CardDefinition) -> void:
	last_error = ""
	var event: DailyEvent = current_day_end_event()
	day_end_event_id = ""
	if event.trigger == DailyEvent.Trigger.AMBIENT:
		progress.recent_day_end_events.append(event.id)
		if progress.recent_day_end_events.size() > 2:
			progress.recent_day_end_events.remove_at(0)
	# 先结束已完成夜晚的临时效果，再施加新事件，保留其下一夜期限。
	if not day_end_effects_expired:
		EffectResolver.expire_after_night(self)
		day_end_effects_expired = true
	if option != null:
		EffectResolver.apply(self, option, true)
		log_event(
			(
				"日终事件：%s · %s；%s；%s"
				% [event.display_name, option.display_name, option.positive, option.negative]
			)
		)
	else:
		log_event("跳过日终事件：%s，没有取得收益或承担代价。" % event.display_name)
	_take_next_day_end_event()
	if day_end_event_id.is_empty():
		advance_dawn()
	else:
		_publish_changes(true)
		autosave()


func _take_next_day_end_event() -> void:
	day_end_event_id = "" if pending_day_end_events.is_empty() else pending_day_end_events[0]
	if not pending_day_end_events.is_empty():
		pending_day_end_events.remove_at(0)


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
	var acquired: PackedInt32Array = _pending_card_uids.duplicate()
	_pending_card_uids.clear()
	_publishing_changes = true
	if include_phase:
		phase_changed.emit(phase)
	changed.emit()
	if not acquired.is_empty():
		cards_acquired.emit(acquired)
	_publishing_changes = false
