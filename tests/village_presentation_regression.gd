class_name VillagePresentationRegression
extends RefCounted
## 营地地面依据实际建筑扩展，探索不赠建筑或改写资源发现。


static func run(check: Callable) -> void:
	var state: VillageState = VillageState.new()
	state.persistence_enabled = false
	state.new_run(65012)
	var base: Array[Rect2] = WorldLayout.camp_areas(WorldLayout.active_structures(state))
	var before: Rect2 = _bounds(base)
	var snapshot: VillageSaveData = state.snapshot()
	SurvivalTestSetup.developed(state)
	var explored: Array[Rect2] = WorldLayout.camp_areas(WorldLayout.active_structures(state))
	check.call(base == explored, "Exploration alone never expands built camp clearings")
	state.buildings[GameTypes.Building.FOOD_STORE] = 1
	var constructed: Array[Rect2] = WorldLayout.camp_areas(WorldLayout.active_structures(state))
	check.call(
		constructed.size() > base.size() and _bounds(constructed).get_area() > before.get_area(),
		"New visible storage construction expands cleared camp footprint"
	)
	check.call(
		state.resources == snapshot.resources,
		"Presentation footprint queries do not alter resource inventory"
	)
	var discoveries: PackedInt32Array = state.progress.discoveries.duplicate()
	WorldLayout.camp_areas(WorldLayout.active_structures(state))
	check.call(
		state.progress.discoveries == discoveries, "Camp presentation grants no hidden discoveries"
	)


static func _bounds(areas: Array[Rect2]) -> Rect2:
	var result: Rect2 = areas[0]
	for area: Rect2 in areas:
		result = result.merge(area)
	return result
