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
	for effect: CardEffect in card.effects:
		if effect.type in [CardEffect.Type.WELL_SURVEY, CardEffect.Type.DRILL]:
			if not state.progress.well_tools:
				return "需要先制作挖井工具"
		if effect.type == CardEffect.Type.DRILL and state.progress.well_surveys == 0:
			return "需要先勘探井位"
	return ""


static func grant_available(state: VillageState) -> void:
	for card: CardDefinition in state.catalog.library.starting_cards:
		if state.progress.granted_cards.has(card.id) or not unlock_error(state, card).is_empty():
			continue
		state.progress.granted_cards.append(card.id)
		state.add_card(card)
		state.log_event("解锁：%s。" % card.display_name)


static func well_chance(state: VillageState) -> float:
	var map: MapDefinition = state.catalog.library.progression_rules.map_for(state.progress.region)
	return clampf(
		map.well_base_chance + map.well_survey_gain * state.progress.well_surveys, 0.0, 1.0
	)


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
			state.log_event(state.terrain_grid.report(cell, state.progress.explored_cells))
		CardEffect.Type.WELL_TOOLS:
			state.progress.well_tools = true
			state.log_event("挖井工具已备齐，可以开始勘探井位。")
		CardEffect.Type.WELL_SURVEY:
			state.progress.well_surveys = mini(999, state.progress.well_surveys + 1)
			state.log_event(
				(
					"井位勘探 %d 次，打井成功率 %d%%。"
					% [state.progress.well_surveys, roundi(well_chance(state) * 100)]
				)
			)
		CardEffect.Type.DRILL:
			if preview or state.rng.randf() < well_chance(state):
				state.buildings[effect.building.id] += int(effect.amount)
				state.log_event("打井成功，已建立地下水源。")
			else:
				state.log_event("打井失败，材料与行动已消耗；可继续勘探后再试。")


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
	result += (
		"\n挖井工具：%s · 井位勘探 %d 次 · 成功率 %d%%"
		% [
			"已备齐" if state.progress.well_tools else "未制作",
			state.progress.well_surveys,
			roundi(well_chance(state) * 100)
		]
	)
	return result


static func is_survey(card: CardDefinition) -> bool:
	return card != null and card.effects.any(_is_terrain_survey)


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
