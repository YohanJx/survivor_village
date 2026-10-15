class_name SurvivalRules
extends RefCounted
## 地形发现、专业准入、井位与跨日存储。查询无副作用，提交由状态事务调用。


static func unlock_error(state: VillageState, card: CardDefinition, target_day: int = 0) -> String:
	var current_day: int = state.day if target_day == 0 else target_day
	if card.effects.any(_is_terrain_survey):
		return ""
	if current_day == 1:
		return "第一天只能勘探地形"
	if not card.regions.is_empty() and not card.regions.has(state.progress.region):
		return "当前地图无法解锁这张卡"
	if state.progress.terrain_surveys == 0:
		return "需要先勘探地形"
	if card.id in ["well", "well_survey"] and state.buildings[GameTypes.Building.WELL] >= 1:
		return "已建成水井，不能继续勘探井位或重复打井"
	if card.id == "survivors":
		if state.progress.last_recruited_day == current_day:
			return "今日已接纳幸存者，请明日再搜寻"
		if state.population + 2 > state.catalog.library.workforce_rules.max_recruited_population:
			return "营地人口即将超过接纳上限"
	for keyword: KeywordDefinition in card.keywords:
		var error: String = KeywordRules.requirement_error(state, keyword)
		if not error.is_empty():
			return error
	for id: String in card.required_cards:
		if not state.progress.completed_cards.has(id):
			var required: CardDefinition = state.catalog.get_card(id)
			return "卡牌前置未注册" if required == null else "需要先完成：%s" % required.display_name
	for requirement: BuildingRequirement in card.prerequisites:
		if state.buildings[requirement.building.id] < requirement.level:
			return "需要 %s Lv.%d" % [requirement.building.display_name, requirement.level]
	if not card.any_prerequisites.is_empty():
		var available: bool = false
		var alternatives: PackedStringArray = []
		for requirement: BuildingRequirement in card.any_prerequisites:
			available = available or state.buildings[requirement.building.id] >= requirement.level
			alternatives.append(requirement.building.display_name)
		if not available:
			return "需要其中一种设施：" + " / ".join(alternatives)
	for effect: CardEffect in card.effects:
		if effect.type in [CardEffect.Type.WELL_SURVEY, CardEffect.Type.DRILL]:
			if not state.progress.well_tools:
				return "需要先制作挖井工具"
		if effect.type == CardEffect.Type.WELL_SURVEY:
			var survey_error: String = WellRules.availability_error(state)
			if not survey_error.is_empty():
				return survey_error
		if effect.type == CardEffect.Type.DRILL:
			var drill_error: String = WellRules.drill_error(state)
			if not drill_error.is_empty():
				return drill_error
	return ""


static func grant_available(state: VillageState) -> void:
	for card: CardDefinition in state.catalog.library.starting_cards:
		if not unlock_error(state, card).is_empty():
			continue
		if state.progress.granted_cards.has(card.id):
			# 旧档中已使用的一次性招募卡现在可再次出现；保留原 UID 与完成记录。
			if card.id == "survivors" and not state.hand.any(
				func(entry: CardInstance) -> bool: return entry.definition.id == card.id
			):
				state.add_card(card)
			continue
		state.progress.granted_cards.append(card.id)
		state.add_card(card)
		state.log_event("解锁：%s。" % card.display_name)


static func well_chance(state: VillageState) -> float:
	return WellRules.chance(state)


static func commit(state: VillageState, effect: CardEffect, preview: bool = false) -> void:
	match effect.type:
		CardEffect.Type.SURVEY:
			if not state.exploration_error().is_empty():
				return
			var cell: Vector2i = TerrainGrid.position(state.progress.exploration_target)
			state.progress.explored_cells.append(state.progress.exploration_target)
			state.progress.exploration_target = -1
			state.progress.terrain_surveys = state.progress.explored_cells.size() - 1
			state.progress.discoveries = TerrainGrid.discoveries_for(
				state.terrain_grid, state.progress.explored_cells
			)
			state.last_card_result = "勘探完成。" + state.terrain_grid.report_short(cell, state.progress.explored_cells)
			state.log_event(state.terrain_grid.report(cell, state.progress.explored_cells))
		CardEffect.Type.WELL_TOOLS:
			state.progress.well_tools = true
			state.log_event("挖井工具已备齐，可以开始勘探井位。")
		CardEffect.Type.WELL_SURVEY:
			WellRules.survey(state)
		CardEffect.Type.DRILL:
			WellRules.drill(state, effect, preview)


static func storage_capacity(state: VillageState, stock: GameTypes.Stock) -> int:
	var index: int = stock - GameTypes.Stock.FOOD
	if index < 0 or index > 2:
		return GameTypes.STOCK_LIMITS[stock]
	var capacity: int = state.catalog.library.progression_rules.portable_storage[index]
	for building: BuildingDefinition in state.catalog.library.buildings:
		capacity += building.storage[index] * state.buildings[building.id]
	return mini(capacity, GameTypes.STOCK_LIMITS[stock])


static func close_day(state: VillageState) -> void:
	for stock: int in [GameTypes.Stock.FOOD, GameTypes.Stock.WATER, GameTypes.Stock.POWER]:
		var capacity: int = storage_capacity(state, stock as GameTypes.Stock)
		var discarded: int = maxi(0, state.resources[stock] - capacity)
		state.resources[stock] = mini(state.resources[stock], capacity)
		if discarded > 0:
			state.log_event(
				"%s超出跨日存储容量 %d，丢弃 %d。" % [GameTypes.STOCK_NAMES[stock], capacity, discarded]
			)


static func summary(state: VillageState) -> String:
	var names: PackedStringArray = []
	for discovery: int in state.progress.discoveries:
		names.append(GameTypes.DISCOVERY_NAMES[discovery])
	var terrain: String = (
		"尚未勘探"
		if state.progress.terrain_surveys == 0
		else "、".join(names) if not names.is_empty() else "暂无可利用资源"
	)
	var result: String = "地形：%s\n按已发现地形与人物解锁对应行动。" % terrain
	result += "\n" + OpeningRules.next_step(state)
	var well: CardDefinition = state.catalog.get_card("well")
	if well == null:
		return result
	for keyword: KeywordDefinition in well.keywords:
		if keyword.category == KeywordDefinition.Category.TERRAIN:
			if not KeywordRules.requirement_error(state, keyword).is_empty():
				return result
	result += "\n" + WellRules.summary(state)
	return result


static func is_survey(card: CardDefinition) -> bool:
	return card != null and card.effects.any(_is_terrain_survey)


static func is_map_survey(card: CardDefinition) -> bool:
	return is_survey(card) or WellRules.is_survey(card)


static func exploration_summary(state: VillageState) -> String:
	var lines: PackedStringArray = [
		OpeningRules.next_step(state),
		(
			"已探索 %d / %d 区域；亮边未知格可选。"
			% [state.progress.explored_cells.size(), TerrainGrid.SIZE.x * TerrainGrid.SIZE.y]
		)
	]
	if state.progress.exploration_target >= 0:
		var cell: Vector2i = TerrainGrid.position(state.progress.exploration_target)
		lines.append(
			(
				"目标 (%d, %d) · 离营地 %d 格 · 路程额外体力 %d"
				% [
					cell.x,
					cell.y,
					TerrainGrid.distance(cell),
					maxi(0, TerrainGrid.distance(cell) - 1) * 2
				]
			)
		)
	else:
		lines.append("先选格，再确认勘探；每远一格额外消耗 2 体力。")
	if state.progress.explored_cells.size() == 1:
		lines.append(state.terrain_grid.report(TerrainGrid.CAMP, state.progress.explored_cells))
	if state.progress.explored_cells.size() > 1:
		lines.append(
			state.terrain_grid.report(
				TerrainGrid.position(state.progress.explored_cells[-1]),
				state.progress.explored_cells
			)
		)
	return "\n".join(lines)


static func migrate_completions(state: VillageState) -> void:
	if state.progress.well_tools and not state.progress.completed_cards.has("well_tools"):
		state.progress.completed_cards.append("well_tools")
	if state.progress.well_surveys > 0 and not state.progress.completed_cards.has("well_survey"):
		state.progress.completed_cards.append("well_survey")
	if state.progress.terrain_surveys > 0 and not state.progress.completed_cards.has("explore"):
		state.progress.completed_cards.append("explore")
	for card: CardDefinition in state.catalog.library.cards:
		if card.building == null or state.buildings[card.building.id] == 0:
			continue
		if not state.progress.completed_cards.has(card.id):
			state.progress.completed_cards.append(card.id)


static func _is_terrain_survey(effect: CardEffect) -> bool:
	return effect.type == CardEffect.Type.SURVEY
