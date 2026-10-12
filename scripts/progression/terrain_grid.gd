class_name TerrainGrid
extends RefCounted
## 当局只读地形；局部战场与勘探网格使用同一份噪声分类。

enum Biome { PLAIN, FOREST, RIDGE, RIVER, RUINS, FUEL, COUNT }

const SIZE: Vector2i = Vector2i(10, 6)
const CAMP: Vector2i = Vector2i(5, 3)
const CELL: float = 96.0
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const DIRECTION_NAMES: PackedStringArray = ["北", "东", "南", "西"]
const NAMES: PackedStringArray = ["草甸", "林地", "岩地", "河流", "废墟", "油料遗址"]
const COLORS: Array[Color] = [
	Color("747963"),
	Color("455446"),
	Color("777367"),
	Color("506d70"),
	Color("626963"),
	Color("806c50")
]
const CLUES: PackedStringArray = ["低矮植被与鸟鸣", "树冠与落叶", "裸岩与抬升的山脊", "水汽与流水声", "人工轮廓与碎砖", "金属残骸与油料气味"]

var _biomes: PackedInt32Array = []
var _discoveries: Array[PackedInt32Array] = []


func generate(seed_value: int, map: MapDefinition) -> void:
	var elevation: FastNoiseLite = _noise(seed_value, map.noise_frequency)
	var moisture: FastNoiseLite = _noise(seed_value + 9137, map.noise_frequency)
	var settlement: FastNoiseLite = _noise(seed_value + 2719, map.noise_frequency * 1.7)
	_biomes.clear()
	_discoveries.clear()
	for y: int in SIZE.y:
		for x: int in SIZE.x:
			var height: float = elevation.get_noise_2d(x + 63, y + 47)
			var wet: float = moisture.get_noise_2d(x + 63, y + 47)
			var built: float = settlement.get_noise_2d(x + 63, y + 47)
			var kind: Biome = _classify(height, wet, built, map)
			_biomes.append(kind)
			_discoveries.append(_sources(kind, map))
	# 营地是已确认的安全驻地，不自动赠送周边资源发现。
	_biomes[index(CAMP)] = Biome.PLAIN
	_discoveries[index(CAMP)] = PackedInt32Array()


func biome(cell: Vector2i) -> Biome:
	return _biomes[index(cell)] as Biome


func sources(cell: Vector2i) -> PackedInt32Array:
	return _discoveries[index(cell)].duplicate()


func report(cell: Vector2i, explored: PackedInt32Array) -> String:
	var names: PackedStringArray = []
	for source: int in sources(cell):
		names.append(GameTypes.DISCOVERY_NAMES[source])
	var lines: PackedStringArray = [
		(
			"勘探 (%d, %d)：%s；发现：%s。"
			% [
				cell.x,
				cell.y,
				NAMES[biome(cell)],
				"、".join(names) if not names.is_empty() else "暂无可利用资源"
			]
		)
	]
	for direction: int in DIRECTIONS.size():
		var neighbor: Vector2i = cell + DIRECTIONS[direction]
		if contains(neighbor) and not explored.has(index(neighbor)):
			lines.append(
				"%s侧线索：%s（尚未勘探，不能据此取用资源）。" % [DIRECTION_NAMES[direction], CLUES[biome(neighbor)]]
			)
	return "\n".join(lines)


func report_short(cell: Vector2i, explored: PackedInt32Array) -> String:
	var title: String = (
		"营地四周线索" if cell == CAMP else "勘探报告 · (%d, %d) %s" % [cell.x, cell.y, NAMES[biome(cell)]]
	)
	var lines: PackedStringArray = [title]
	var names: PackedStringArray = []
	for source: int in sources(cell):
		names.append(GameTypes.DISCOVERY_NAMES[source])
	lines.append("发现：" + ("、".join(names) if not names.is_empty() else "暂无资源"))
	lines.append_array(direction_clues(cell, explored))
	return "\n".join(lines)


func direction_clues(cell: Vector2i, explored: PackedInt32Array) -> PackedStringArray:
	var lines: PackedStringArray = []
	for direction: int in DIRECTIONS.size():
		var neighbor: Vector2i = cell + DIRECTIONS[direction]
		if contains(neighbor) and not explored.has(index(neighbor)):
			lines.append("%s：%s" % [DIRECTION_NAMES[direction], CLUES[biome(neighbor)]])
	return lines


static func contains(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, SIZE).has_point(cell)


static func index(cell: Vector2i) -> int:
	return cell.y * SIZE.x + cell.x


static func position(value: int) -> Vector2i:
	return Vector2i(value % SIZE.x, int(value / float(SIZE.x)))


static func is_frontier(cell: Vector2i, explored: PackedInt32Array) -> bool:
	if not contains(cell) or explored.has(index(cell)):
		return false
	for direction: Vector2i in DIRECTIONS:
		var neighbor: Vector2i = cell + direction
		if contains(neighbor) and explored.has(index(neighbor)):
			return true
	return false


static func distance(cell: Vector2i) -> int:
	return absi(cell.x - CAMP.x) + absi(cell.y - CAMP.y)


static func discoveries_for(grid: TerrainGrid, explored: PackedInt32Array) -> PackedInt32Array:
	var result: PackedInt32Array = []
	for value: int in explored:
		for source: int in grid.sources(position(value)):
			if not result.has(source):
				result.append(source)
	result.sort()
	return result


static func migrate_progress(progress: VillageProgress, grid: TerrainGrid) -> void:
	progress.completed_cards.clear()
	var previous: PackedInt32Array = progress.discoveries.duplicate()
	progress.explored_cells = PackedInt32Array([index(CAMP)])
	if progress.terrain_surveys > 0:
		for step: int in SIZE.x * SIZE.y - 1:
			progress.explored_cells.append(first_frontier(progress.explored_cells))
			var found: PackedInt32Array = discoveries_for(grid, progress.explored_cells)
			if _includes_sources(found, previous):
				break
	progress.discoveries = discoveries_for(grid, progress.explored_cells)
	progress.terrain_surveys = progress.explored_cells.size() - 1
	progress.exploration_target = -1


static func first_frontier(explored: PackedInt32Array) -> int:
	for value: int in SIZE.x * SIZE.y:
		if is_frontier(position(value), explored):
			return value
	return -1


static func _includes_sources(found: PackedInt32Array, expected: PackedInt32Array) -> bool:
	for source: int in expected:
		if not found.has(source):
			return false
	return true


static func _noise(seed_value: int, frequency: float) -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = int(seed_value % 2147483647)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = 3
	return noise


static func _classify(height: float, wet: float, built: float, map: MapDefinition) -> Biome:
	if map.discoveries.has(GameTypes.Discovery.RIVER) and absf(wet) < map.river_width:
		return Biome.RIVER
	if map.discoveries.has(GameTypes.Discovery.FUEL) and built > 0.25:
		return Biome.FUEL
	if built > (0.0 if map.kind == GameTypes.Region.RUINS else 0.25):
		return Biome.RUINS
	if height > (-0.1 if map.kind == GameTypes.Region.MOUNTAIN else 0.25):
		return Biome.RIDGE
	return Biome.FOREST if wet > 0.0 else Biome.PLAIN


static func _sources(kind: Biome, map: MapDefinition) -> PackedInt32Array:
	var result: PackedInt32Array = []
	match kind:
		Biome.PLAIN:
			result = [GameTypes.Discovery.FORAGE, GameTypes.Discovery.FARMLAND]
		Biome.FOREST:
			result = [GameTypes.Discovery.FORAGE, GameTypes.Discovery.WOODLAND]
		Biome.RIDGE:
			result = [GameTypes.Discovery.STONE]
		Biome.RIVER:
			result = [GameTypes.Discovery.RIVER]
		Biome.RUINS:
			result = [GameTypes.Discovery.RUINS, GameTypes.Discovery.STONE]
		Biome.FUEL:
			result = [GameTypes.Discovery.RUINS, GameTypes.Discovery.FUEL]
	var allowed: PackedInt32Array = []
	for source: int in result:
		if map.discoveries.has(source):
			allowed.append(source)
	return allowed
