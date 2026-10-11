class_name WorldLayout
extends RefCounted

const GRID: Vector2i = Vector2i(40, 24)
const CELL: float = 24.0
const WORLD: Vector2 = Vector2(960, 576)
const EXTRA_HUT: Rect2i = Rect2i(23, 13, 2, 2)
const CENTER: Vector2 = Vector2(492, 300)
const CAMP_PADDING: float = 18.0
const FIRE_CLEARING: Rect2 = Rect2(468, 324, 48, 48)


static func to_cell(point: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(point.x / CELL), 0, GRID.x - 1), clampi(int(point.y / CELL), 0, GRID.y - 1)
	)


static func to_point(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


static func terrain(grid: TerrainGrid) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x: int in range(2, GRID.x - 2):
		for y: int in range(2, GRID.y - 2):
			if Rect2i(12, 4, 17, 17).has_point(Vector2i(x, y)):
				continue
			if x in [19, 20, 21] or y in [11, 12, 13]:
				continue
			var coarse: Vector2i = Vector2i(int(x / 4.0), int(y / 4.0))
			if grid.biome(coarse) != TerrainGrid.Biome.PLAIN and (x + y) % 3 == 0:
				cells.append(Vector2i(x, y))
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


## 已建设施周围的清理地面；只描述现有建设，不授予地形发现或可建设资格。
static func camp_areas(structures: Array[StructurePlacement]) -> Array[Rect2]:
	var areas: Array[Rect2] = [FIRE_CLEARING]
	for structure: StructurePlacement in structures:
		var footprint: Rect2 = Rect2(
			Vector2(structure.rect.position) * CELL, Vector2(structure.rect.size) * CELL
		)
		areas.append(footprint.grow(CAMP_PADDING))
	return areas


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
