class_name WorldLayout
extends RefCounted

const GRID: Vector2i = Vector2i(40, 24)
const CELL: float = 24.0
const WORLD: Vector2 = Vector2(960, 576)
const EXTRA_HUT: Rect2i = Rect2i(23, 13, 2, 2)
const CENTER: Vector2 = Vector2(492, 300)


static func to_cell(point: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(point.x / CELL), 0, GRID.x - 1), clampi(int(point.y / CELL), 0, GRID.y - 1)
	)


static func to_point(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


static func terrain(
	seed_value: int, region: GameTypes.Region = GameTypes.Region.LEGACY
) -> Array[Vector2i]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value + 7187
	var cells: Array[Vector2i] = []
	for i: int in 110:
		var cell: Vector2i = Vector2i(rng.randi_range(2, 37), rng.randi_range(2, 21))
		if cell.x >= 12 and cell.x <= 28 and cell.y >= 4 and cell.y <= 20:
			continue
		# Four open approach roads keep every spawn region connected.
		if cell.x in [19, 20, 21] or cell.y in [11, 12, 13]:
			continue
		if not cells.has(cell):
			cells.append(cell)
	var map: MapDefinition = (
		(preload("res://data/progression_rules.tres") as ProgressionRules).map_for(region)
	)
	for barrier: Rect2i in map.barriers:
		for x: int in range(barrier.position.x, barrier.end.x):
			for y: int in range(barrier.position.y, barrier.end.y):
				var cell: Vector2i = Vector2i(x, y)
				if not cells.has(cell):
					cells.append(cell)
	return cells


static func active_structures(state: VillageState) -> Array[StructurePlacement]:
	var result: Array[StructurePlacement] = []
	for definition: BuildingDefinition in state.catalog.library.buildings:
		if not definition.visible_on_map:
			continue
		if (
			definition.id == GameTypes.Building.CORE
			or definition.id == GameTypes.Building.HUT
			or state.buildings[definition.id] > 0
		):
			result.append(StructurePlacement.new(definition, definition.footprint))
	result.append(
		StructurePlacement.new(state.catalog.buildings[GameTypes.Building.HUT], EXTRA_HUT)
	)
	return result


static func wall_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x: int in range(14, 27):
		if x not in [20, 21]:
			result.append(Vector2i(x, 6))
			result.append(Vector2i(x, 18))
	for y: int in range(7, 18):
		if y not in [11, 12]:
			result.append(Vector2i(14, y))
			result.append(Vector2i(26, y))
	return result


static func gate_cells() -> Array[Vector2i]:
	return [
		Vector2i(20, 6),
		Vector2i(21, 6),
		Vector2i(20, 18),
		Vector2i(21, 18),
		Vector2i(14, 11),
		Vector2i(14, 12),
		Vector2i(26, 11),
		Vector2i(26, 12),
	]
