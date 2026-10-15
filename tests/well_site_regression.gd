class_name WellSiteRegression
extends RefCounted
## 具体井位的排除、无副作用拒绝、快照隔离与版本迁移。

const SAVE_PATH: String = "res://test-results/well_site_roundtrip.tres"


static func run(check: Callable) -> void:
	var state: VillageState = _fresh()
	var first: WellSiteRecord = WellRules.pending_site(state.progress)
	var first_cell: Vector2i = TerrainGrid.position(first.cell)
	SurvivalTestSetup.force_drill_result(state, false)
	check.call(state.play_card(_uid(state, "well")), "A concrete surveyed well can be attempted")
	check.call(first.outcome == WellSiteRecord.Outcome.DRY, "No water permanently marks this exact position dry")
	var before: VillageSaveData = state.snapshot()
	check.call(not state.play_card(_uid(state, "well")), "Repeated drilling at a dry position is rejected")
	check.call(not state.select_well_site(first_cell), "Dry position cannot be surveyed again")
	check.call(not state.play_card(_uid(state, "well_survey")), "Survey needs another explicit map target")
	check.call(
		state.resources == before.resources and state.rng.state == before.rng_state
		and state.slot == before.slot and state.actions_used == before.actions_used
		and state.history.size() == before.history.size(),
		"Rejected retries charge no materials, actions, RNG or history"
	)
	check.call(state.save_game(SAVE_PATH), "Dry position can be saved to an isolated test file")
	var restored: VillageState = _fresh()
	check.call(restored.load_game(SAVE_PATH), "Dry position survives an actual disk roundtrip")
	check.call(
		not restored.select_well_site(first_cell) and not restored.play_card(_uid(restored, "well")),
		"Reloading cannot reopen a failed position or replenish drill attempts"
	)
	check.call(before.progress.well_sites[0] != first, "Snapshot owns its nested well record")
	before.progress.well_sites[0].outcome = WellSiteRecord.Outcome.UNTESTED
	check.call(first.outcome == WellSiteRecord.Outcome.DRY, "Changing snapshot record cannot change live result")
	restored.resources[GameTypes.Stock.STONE] = 100
	var second_cell: Vector2i = SurvivalTestSetup.select_well_candidate(restored)
	check.call(second_cell != first_cell and second_cell.x >= 0, "Another position must be explicitly selected")
	check.call(restored.play_card(_uid(restored, "well_survey")), "New position accepts one site survey")
	var second: WellSiteRecord = WellRules.pending_site(restored.progress)
	check.call(second.cell == TerrainGrid.index(second_cell), "Survey records the selected map position")
	before = restored.snapshot()
	check.call(not restored.play_card(_uid(restored, "well_survey")), "Pending site cannot accumulate extra surveys")
	check.call(not restored.select_well_site(first_cell), "Another selection cannot overwrite the pending drill")
	restored.preview_card(restored.catalog.get_card("well"))
	check.call(
		restored.rng.state == before.rng_state and restored.resources == before.resources
		and second.outcome == WellSiteRecord.Outcome.UNTESTED,
		"Water-success preview leaves RNG, payments and hidden outcome untouched"
	)
	check.call(
		is_equal_approx(WellRules.chance(restored), WellRules.chance(state))
		and WellRules.chance(restored) < 1.0,
		"Previous positions never add chance or guarantee water at this position"
	)
	SurvivalTestSetup.force_drill_result(restored, true)
	var twin: VillageState = _fresh()
	check.call(twin.restore(restored.snapshot()), "Pending position and random state survive restore")
	check.call(restored.play_card(_uid(restored, "well")), "New position can produce a water-bearing well")
	check.call(twin.play_card(_uid(twin, "well")), "Restored pending position can commit its same attempt")
	check.call(
		second.outcome == WellSiteRecord.Outcome.WATER
		and twin.progress.well_sites[1].outcome == second.outcome
		and twin.rng.state == restored.rng.state,
		"Same saved attempt resolves reproducibly to the same water result"
	)
	check.call(
		WellRules.site_at(restored.progress, first.cell).outcome == WellSiteRecord.Outcome.DRY
		and restored.progress.well_surveys == 2 and restored.progress.well_drill_attempts == 2,
		"Building another well keeps the old dry position excluded"
	)
	_test_invalid_saves(state, check)
	_test_legacy(state, restored, check)
	DirAccess.remove_absolute(SAVE_PATH)


static func _test_invalid_saves(state: VillageState, check: Callable) -> void:
	var restored: VillageState = _fresh()
	var before: VillageSaveData = restored.snapshot()
	var save: VillageSaveData = state.snapshot()
	save.progress.well_sites.append(save.progress.well_sites[0].copy_record())
	save.progress.well_surveys += 1
	save.progress.well_drill_attempts += 1
	check.call(not restored.restore(save), "A duplicated position cannot fabricate another attempt")
	save = state.snapshot()
	save.progress.well_sites[0].cell = TerrainGrid.index(TerrainGrid.CAMP)
	check.call(not restored.restore(save), "Camp cannot impersonate a surveyed well position")
	save = state.snapshot()
	save.progress.well_sites[0].outcome = WellSiteRecord.Outcome.COUNT
	check.call(not restored.restore(save), "Invalid water outcome is rejected")
	save = state.snapshot()
	save.progress.well_sites[0] = null
	check.call(not restored.restore(save), "Null nested well record is rejected before restore")
	save = state.snapshot()
	save.progress.well_target = state.progress.well_sites[0].cell
	check.call(not restored.restore(save), "Save cannot reselect a spent dry position")
	check.call(
		restored.resources == before.resources and restored.rng.state == before.rng_state
		and restored.progress.well_sites[0].outcome == before.progress.well_sites[0].outcome,
		"Invalid well saves leave the entire live state intact"
	)


static func _test_legacy(dry: VillageState, water: VillageState, check: Callable) -> void:
	var save: VillageSaveData = dry.snapshot()
	save.version = 11
	save.buildings.resize(VillageSaveData.PREVIOUS_BUILDING_COUNT)
	save.progress.well_sites.clear()
	save.progress.well_surveys = 5
	var restored: VillageState = _fresh()
	check.call(restored.restore(save), "Version 11 with accumulated survey credits still loads")
	check.call(
		restored.progress.well_sites.is_empty() and restored.progress.well_surveys == 0
		and WellRules.pending_site(restored.progress) == null
		and not restored.can_play(_uid(restored, "well")).is_empty(),
		"Legacy accumulated credits cannot manufacture a concrete position or guaranteed water"
	)
	check.call(save.progress.well_surveys == 5, "Migration leaves the source save unchanged")
	check.call(restored.restore(restored.snapshot()), "Migrated unbuilt well passes current save validation")
	save = water.snapshot()
	save.version = 11
	save.buildings.resize(VillageSaveData.PREVIOUS_BUILDING_COUNT)
	save.progress.well_sites.clear()
	check.call(restored.restore(save), "Version 11 successful water source remains compatible")
	check.call(
		restored.buildings[GameTypes.Building.WELL] == 1 and restored.progress.legacy_well
		and not SurvivalRules.unlock_error(restored, restored.catalog.get_card("well")).is_empty(),
		"Legacy water source is preserved and cannot be drilled again"
	)
	check.call(restored.restore(restored.snapshot()), "Migrated built well passes current save validation")


static func _fresh() -> VillageState:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(65012, GameTypes.Region.MOUNTAIN)
	SurvivalTestSetup.developed(state)
	return state


static func _uid(state: VillageState, id: String) -> int:
	for entry: CardInstance in state.hand:
		if entry.definition.id == id:
			return entry.uid
	return -1
