class_name WellRules
extends RefCounted
## 井位准入、单次打井与存档校验。查询无副作用，提交只由统一卡牌事务调用。


static func is_survey(card: CardDefinition) -> bool:
	return card != null and card.effects.any(
		func(effect: CardEffect) -> bool: return effect.type == CardEffect.Type.WELL_SURVEY
	)


static func site_at(progress: VillageProgress, cell: int) -> WellSiteRecord:
	for site: WellSiteRecord in progress.well_sites:
		if site.cell == cell:
			return site
	return null


static func pending_site(progress: VillageProgress) -> WellSiteRecord:
	if progress.well_sites.is_empty():
		return null
	var site: WellSiteRecord = progress.well_sites.back()
	return site if site.outcome == WellSiteRecord.Outcome.UNTESTED else null


static func candidate_error(state: VillageState, cell: Vector2i) -> String:
	if state.buildings[GameTypes.Building.WELL] > 0:
		return "已建成水井，无需继续勘探井位"
	if pending_site(state.progress) != null:
		return "已有待打井的位置，请先完成这次打井"
	if not TerrainGrid.contains(cell):
		return "井位不在地图内"
	var value: int = TerrainGrid.index(cell)
	if cell == TerrainGrid.CAMP or not state.progress.explored_cells.has(value):
		return "请选择已探索的营地外草甸"
	if state.terrain_grid.biome(cell) != TerrainGrid.Biome.PLAIN:
		return "只有已发现的草甸可作为地下水候选地"
	if site_at(state.progress, value) != null:
		return "此位置已打井且无水，请勘探另一个位置"
	return ""


static func availability_error(state: VillageState) -> String:
	if pending_site(state.progress) != null:
		return "已有待打井的位置，请先完成这次打井"
	for value: int in state.progress.explored_cells:
		if candidate_error(state, TerrainGrid.position(value)).is_empty():
			return ""
	return "没有未尝试的地下水候选地，请先探索另一片草甸"


static func survey_error(state: VillageState) -> String:
	if state.progress.well_target < 0:
		return "请在地图上选择另一处未尝试的已探索草甸"
	return candidate_error(state, TerrainGrid.position(state.progress.well_target))


static func drill_error(state: VillageState) -> String:
	return "" if pending_site(state.progress) != null else "此井位已尝试或尚未勘探，请勘探另一个位置"


static func chance(state: VillageState) -> float:
	var map: MapDefinition = state.catalog.library.progression_rules.map_for(state.progress.region)
	# 一处井位只勘探一次，增益属于这次勘探，不按历史次数叠加。
	return clampf(map.well_base_chance + map.well_survey_gain, 0.0, 1.0)


static func survey(state: VillageState) -> void:
	if not survey_error(state).is_empty():
		return
	var site: WellSiteRecord = WellSiteRecord.new()
	site.cell = state.progress.well_target
	state.progress.well_sites.append(site)
	state.progress.well_target = -1
	state.progress.well_surveys += 1
	var cell: Vector2i = TerrainGrid.position(site.cell)
	state.last_card_result = "井位 (%d, %d) 勘探完成，尚未确认有水；只能打井一次。" % [cell.x, cell.y]
	state.log_event(state.last_card_result)


static func drill(state: VillageState, effect: CardEffect, preview: bool) -> void:
	if preview:
		state.buildings[effect.building.id] += int(effect.amount)
		return
	var site: WellSiteRecord = pending_site(state.progress)
	if site == null:
		return
	state.progress.well_drill_attempts += 1
	var cell: Vector2i = TerrainGrid.position(site.cell)
	if state.rng.randf() < chance(state):
		site.outcome = WellSiteRecord.Outcome.WATER
		state.buildings[effect.building.id] += int(effect.amount)
		state.last_card_result = "打井成功：井位 (%d, %d) 有水，已建立地下水源。" % [cell.x, cell.y]
	else:
		site.outcome = WellSiteRecord.Outcome.DRY
		state.last_card_result = (
			"打井失败：井位 (%d, %d) 无水，材料与行动已消耗。此位置不能重试，请勘探另一个位置。"
			% [cell.x, cell.y]
		)
	state.log_event(state.last_card_result)


static func summary(state: VillageState) -> String:
	var site: WellSiteRecord = pending_site(state.progress)
	var lines: PackedStringArray = [
		"挖井工具：%s · 已勘探 %d 处，已打井 %d 处" % [
			"已备齐" if state.progress.well_tools else "未制作",
			state.progress.well_sites.size(), state.progress.well_drill_attempts
		]
	]
	if site != null:
		var cell: Vector2i = TerrainGrid.position(site.cell)
		lines.append("待打井位置 (%d, %d) · 有水概率 %d%% · 仅可尝试一次" % [
			cell.x, cell.y, roundi(chance(state) * 100)
		])
	elif state.buildings[GameTypes.Building.WELL] > 0:
		lines.append("水井已建成，地下水源可用。")
	else:
		lines.append("在地图选择未尝试的已探索草甸；无水的井位永久排除。")
	return "\n".join(lines)


## 旧档没有井位坐标，保留成井；未成井的累计次数不转换成新位置或额外尝试。
static func migrate(state: VillageState) -> void:
	state.progress.well_sites.clear()
	state.progress.well_target = -1
	state.progress.legacy_well = state.buildings[GameTypes.Building.WELL] > 0
	state.progress.well_surveys = 1 if state.progress.legacy_well else 0
	state.progress.well_drill_attempts = state.progress.well_surveys
	state.log_event("井位记录已升级：已建水井保留；未建井时，请在已探索草甸重新选择具体井位。")


static func valid_progress(data: VillageSaveData, grid: TerrainGrid) -> bool:
	var progress: VillageProgress = data.progress
	if data.buildings.size() <= GameTypes.Building.WELL:
		return false
	if progress.legacy_well:
		return (
			data.buildings[GameTypes.Building.WELL] > 0 and progress.well_tools
			and progress.well_sites.is_empty() and progress.well_target == -1
			and progress.well_surveys == 1 and progress.well_drill_attempts == 1
		)
	var visited: PackedInt32Array = []
	var attempts: int = 0
	var water: int = 0
	for site: WellSiteRecord in progress.well_sites:
		if site == null or not _valid_cell(progress, grid, site.cell) or visited.has(site.cell):
			return false
		if site.outcome < WellSiteRecord.Outcome.UNTESTED or site.outcome >= WellSiteRecord.Outcome.COUNT:
			return false
		if site.outcome == WellSiteRecord.Outcome.UNTESTED:
			if site != progress.well_sites.back():
				return false
		else:
			attempts += 1
		if site.outcome == WellSiteRecord.Outcome.WATER:
			water += 1
			if site != progress.well_sites.back():
				return false
		visited.append(site.cell)
	if progress.well_surveys != visited.size() or progress.well_drill_attempts != attempts:
		return false
	if water != data.buildings[GameTypes.Building.WELL] or water > 1:
		return false
	if progress.well_target != -1:
		if (
			not _valid_cell(progress, grid, progress.well_target)
			or visited.has(progress.well_target)
			or pending_site(progress) != null
			or water > 0
		):
			return false
	return progress.well_tools or (visited.is_empty() and progress.well_target == -1)


static func _valid_cell(progress: VillageProgress, grid: TerrainGrid, cell: int) -> bool:
	return (
		cell >= 0 and cell < TerrainGrid.SIZE.x * TerrainGrid.SIZE.y
		and cell != TerrainGrid.index(TerrainGrid.CAMP) and progress.explored_cells.has(cell)
		and grid.biome(TerrainGrid.position(cell)) == TerrainGrid.Biome.PLAIN
	)
